@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — DOM-BYPASS WEB FRONTEND ENGINE
@! Module: universe/web/frontend/concurrency/worker_pool.lp
@! Milestone: M3 — Lock-Free WASM Concurrency Engine
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features: 3-Worker Multi-Threaded WASM Architecture (Layout Worker, Network
@! Worker, Render Thread), Inter-Worker Lock-Free Ring Channels, Work Routing,
@! Lifecycle Management, Event Dispatching & Diagnostics Telemetry
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/web/frontend/concurrency/message_protocol"
import "universe/web/frontend/concurrency/ring_buffer"

@! ============================================================================
@! 1. WORKER IDS & LIFECYCLE STATES
@! ============================================================================

@fn WORKER_ID_RENDER() return 0 @end   @! Main Render Thread (Canvas owner, GPU submitter)
@fn WORKER_ID_LAYOUT() return 1 @end   @! Layout & UI Worker (Flexbox, component state)
@fn WORKER_ID_NETWORK() return 2 @end  @! Network & Streaming Worker (WebSockets, WebRTC)

@fn WORKER_STATE_UNINITIALIZED() return 0 @end
@fn WORKER_STATE_IDLE() return 1 @end
@fn WORKER_STATE_RUNNING() return 2 @end
@fn WORKER_STATE_PAUSED() return 3 @end
@fn WORKER_STATE_TERMINATED() return 4 @end

@! ============================================================================
@! 2. DATA STRUCTURES
@! ============================================================================

@struct WorkerContext
  worker_state: i64
  worker_id: i64
  worker_name: string
  tick_count: i64
  tasks_processed: i64
  tasks_failed: i64
  last_active_ts: i64
  frames_rendered: i64
  draw_calls_issued: i64
  events_handled: i64
  network_packets_in: i64
  network_packets_out: i64
@end

@struct WorkerPoolStats
  total_dispatched: i64
  total_completed: i64
  render_tasks: i64
  layout_tasks: i64
  network_tasks: i64
  dropped_tasks: i64
  active_workers: i64
  saturation_pct: i64
@end

@struct FrontendWorkerPool
  is_running: bool
  workers: array
  ring_layout_to_render: FrontendRingBuffer
  ring_network_to_render: FrontendRingBuffer
  ring_render_to_layout: FrontendRingBuffer
  ring_network_to_layout: FrontendRingBuffer
  ring_layout_to_network: FrontendRingBuffer
  active_threads_count: i64
  total_dispatched: i64
  total_completed: i64
  shared_buffer_size: i64
  queue_capacity: i64
@end

@! ============================================================================
@! 3. WORKER CONTEXT HELPERS
@! ============================================================================

@fn worker_context_new(id, name)
  return {
    worker_state: WORKER_STATE_IDLE(),
    worker_id: id,
    worker_name: name,
    tick_count: 0,
    tasks_processed: 0,
    tasks_failed: 0,
    last_active_ts: 0,
    frames_rendered: 0,
    draw_calls_issued: 0,
    events_handled: 0,
    network_packets_in: 0,
    network_packets_out: 0
  }
@end

@! ============================================================================
@! 4. WORKER POOL INITIALIZATION
@! ============================================================================

@fn worker_pool_init(queue_capacity)
  cap = queue_capacity
  @if cap < 16 cap = 16 @end

  @! Initialize the 3 Workers
  w_render = worker_context_new(WORKER_ID_RENDER(), "Render Thread (Main)")
  w_layout = worker_context_new(WORKER_ID_LAYOUT(), "Layout Worker")
  w_net = worker_context_new(WORKER_ID_NETWORK(), "Network Worker")
  
  worker_list = [w_render, w_layout, w_net]

  @! Initialize the 5 Ring Buffers
  r_l2r = ring_buffer_new_mode(cap, QUEUE_MODE_SPSC())
  r_n2r = ring_buffer_new_mode(cap, QUEUE_MODE_SPSC())
  r_r2l = ring_buffer_new_mode(cap, QUEUE_MODE_SPSC())
  r_n2l = ring_buffer_new_mode(cap, QUEUE_MODE_SPSC())
  r_l2n = ring_buffer_new_mode(cap, QUEUE_MODE_SPSC())

  @! Estimated SharedArrayBuffer size = 5 rings * 64KB + buffers = ~512KB
  shm_size = 5 * cap * 64 + 65536

  return {
    is_running: false,
    workers: worker_list,
    ring_layout_to_render: r_l2r,
    ring_network_to_render: r_n2r,
    ring_render_to_layout: r_r2l,
    ring_network_to_layout: r_n2l,
    ring_layout_to_network: r_l2n,
    active_threads_count: 3,
    total_dispatched: 0,
    total_completed: 0,
    shared_buffer_size: shm_size,
    queue_capacity: cap
  }
@end

@! ============================================================================
@! 5. WORKER LIFECYCLE MANAGEMENT
@! ============================================================================

@fn worker_pool_start(pool)
  pool.is_running = true
  w0 = pool.workers[0]
  w0.worker_state = WORKER_STATE_RUNNING()
  w1 = pool.workers[1]
  w1.worker_state = WORKER_STATE_RUNNING()
  w2 = pool.workers[2]
  w2.worker_state = WORKER_STATE_RUNNING()
  pool.workers = [w0, w1, w2]
  return pool
@end

@fn worker_pool_pause(pool)
  pool.is_running = false
  w0 = pool.workers[0]
  w0.worker_state = WORKER_STATE_PAUSED()
  w1 = pool.workers[1]
  w1.worker_state = WORKER_STATE_PAUSED()
  w2 = pool.workers[2]
  w2.worker_state = WORKER_STATE_PAUSED()
  pool.workers = [w0, w1, w2]
  return pool
@end

@fn worker_pool_resume(pool)
  pool.is_running = true
  w0 = pool.workers[0]
  w0.worker_state = WORKER_STATE_RUNNING()
  w1 = pool.workers[1]
  w1.worker_state = WORKER_STATE_RUNNING()
  w2 = pool.workers[2]
  w2.worker_state = WORKER_STATE_RUNNING()
  pool.workers = [w0, w1, w2]
  return pool
@end

@fn worker_pool_shutdown(pool)
  pool.is_running = false
  w0 = pool.workers[0]
  w0.worker_state = WORKER_STATE_TERMINATED()
  w1 = pool.workers[1]
  w1.worker_state = WORKER_STATE_TERMINATED()
  w2 = pool.workers[2]
  w2.worker_state = WORKER_STATE_TERMINATED()
  pool.workers = [w0, w1, w2]
  return pool
@end

@! ============================================================================
@! 6. EVENT & COMMAND DISPATCHING
@! ============================================================================

@fn worker_pool_dispatch(pool, target_worker_id, sqe)
  pool.total_dispatched = pool.total_dispatched + 1
  
  @! Route based on opcode and target
  @if target_worker_id == WORKER_ID_RENDER()
    @if sqe.opcode == OP_WEBRTC_FRAME()
      return ring_buffer_push_sqe_entry(pool.ring_network_to_render, sqe)
    @else
      return ring_buffer_push_sqe_entry(pool.ring_layout_to_render, sqe)
    @end
  @end

  @if target_worker_id == WORKER_ID_LAYOUT()
    @if sqe.opcode == OP_INPUT_EVENT()
      return ring_buffer_push_sqe_entry(pool.ring_render_to_layout, sqe)
    @else
      return ring_buffer_push_sqe_entry(pool.ring_network_to_layout, sqe)
    @end
  @end

  @if target_worker_id == WORKER_ID_NETWORK()
    return ring_buffer_push_sqe_entry(pool.ring_layout_to_network, sqe)
  @end

  return 0 @! Unknown worker target
@end

@! Convenience helpers for worker dispatching
@fn worker_pool_send_input(pool, input_msg, tag)
  sqe = msg_input_event_to_sqe(input_msg, tag)
  return worker_pool_dispatch(pool, WORKER_ID_LAYOUT(), sqe)
@end

@fn worker_pool_send_draw_rect(pool, rect_msg, tag)
  sqe = msg_draw_rect_to_sqe(rect_msg, tag)
  return worker_pool_dispatch(pool, WORKER_ID_RENDER(), sqe)
@end

@fn worker_pool_send_draw_text(pool, text_msg, tag)
  sqe = msg_draw_text_to_sqe(text_msg, tag)
  return worker_pool_dispatch(pool, WORKER_ID_RENDER(), sqe)
@end

@fn worker_pool_send_draw_image(pool, img_msg, tag)
  sqe = msg_draw_image_to_sqe(img_msg, tag)
  return worker_pool_dispatch(pool, WORKER_ID_RENDER(), sqe)
@end

@fn worker_pool_send_webrtc_frame(pool, frame_msg, tag)
  sqe = msg_webrtc_frame_to_sqe(frame_msg, tag)
  return worker_pool_dispatch(pool, WORKER_ID_RENDER(), sqe)
@end

@fn worker_pool_send_compute_layout(pool, layout_msg, tag)
  sqe = msg_compute_layout_to_sqe(layout_msg, tag)
  return worker_pool_dispatch(pool, WORKER_ID_LAYOUT(), sqe)
@end

@! ============================================================================
@! 7. WORKER WORKLOAD PROCESSING (TICKS)
@! ============================================================================

@! Tick Worker 0: Render Thread
@fn worker_pool_tick_render(pool)
  w = pool.workers[WORKER_ID_RENDER()]
  @if w.worker_state != WORKER_STATE_RUNNING() return 0 @end

  w.tick_count = w.tick_count + 1
  processed = 0

  @! 1. Process Layout -> Render Ring (Draw commands)
  @while ring_buffer_is_sq_empty(pool.ring_layout_to_render) == 0
    sqe = ring_buffer_pop_sqe(pool.ring_layout_to_render)
    @if sqe == 0 break @end
    
    @! Simulated GPU draw execution
    w.draw_calls_issued = w.draw_calls_issued + 1
    w.tasks_processed = w.tasks_processed + 1
    processed = processed + 1
    
    @if sqe.opcode == OP_PRESENT()
      w.frames_rendered = w.frames_rendered + 1
    @end

    @! Emit CQE
    ring_buffer_push_cqe(pool.ring_layout_to_render, sqe.user_data, 0, 0)
  @end

  @! 2. Process Network -> Render Ring (WebRTC video frames)
  @while ring_buffer_is_sq_empty(pool.ring_network_to_render) == 0
    sqe = ring_buffer_pop_sqe(pool.ring_network_to_render)
    @if sqe == 0 break @end
    
    w.draw_calls_issued = w.draw_calls_issued + 1
    w.tasks_processed = w.tasks_processed + 1
    processed = processed + 1
    
    @! Pixel frame blitted
    ring_buffer_push_cqe(pool.ring_network_to_render, sqe.user_data, sqe.arg2 * sqe.arg3, 0)
  @end

  pool.workers[WORKER_ID_RENDER()] = w
  pool.total_completed = pool.total_completed + processed
  return processed
@end

@! Tick Worker 1: Layout Worker
@fn worker_pool_tick_layout(pool)
  w = pool.workers[WORKER_ID_LAYOUT()]
  @if w.worker_state != WORKER_STATE_RUNNING() return 0 @end

  w.tick_count = w.tick_count + 1
  processed = 0

  @! 1. Process Render -> Layout Ring (User Input Events)
  @while ring_buffer_is_sq_empty(pool.ring_render_to_layout) == 0
    sqe = ring_buffer_pop_sqe(pool.ring_render_to_layout)
    @if sqe == 0 break @end
    
    w.events_handled = w.events_handled + 1
    w.tasks_processed = w.tasks_processed + 1
    processed = processed + 1
    
    @! Acknowledge input event via CQE
    ring_buffer_push_cqe(pool.ring_render_to_layout, sqe.user_data, sqe.arg0, 0)
  @end

  @! 2. Process Network -> Layout Ring (Server State Updates)
  @while ring_buffer_is_sq_empty(pool.ring_network_to_layout) == 0
    sqe = ring_buffer_pop_sqe(pool.ring_network_to_layout)
    @if sqe == 0 break @end
    
    w.tasks_processed = w.tasks_processed + 1
    processed = processed + 1
    
    ring_buffer_push_cqe(pool.ring_network_to_layout, sqe.user_data, 0, 0)
  @end

  pool.workers[WORKER_ID_LAYOUT()] = w
  pool.total_completed = pool.total_completed + processed
  return processed
@end

@! Tick Worker 2: Network Worker
@fn worker_pool_tick_network(pool)
  w = pool.workers[WORKER_ID_NETWORK()]
  @if w.worker_state != WORKER_STATE_RUNNING() return 0 @end

  w.tick_count = w.tick_count + 1
  processed = 0

  @! 1. Process Layout -> Network Ring (Outgoing API/Signaling requests)
  @while ring_buffer_is_sq_empty(pool.ring_layout_to_network) == 0
    sqe = ring_buffer_pop_sqe(pool.ring_layout_to_network)
    @if sqe == 0 break @end
    
    w.network_packets_out = w.network_packets_out + 1
    w.tasks_processed = w.tasks_processed + 1
    processed = processed + 1
    
    @! Acknowledge network send via CQE
    ring_buffer_push_cqe(pool.ring_layout_to_network, sqe.user_data, 200, 0)
  @end

  pool.workers[WORKER_ID_NETWORK()] = w
  pool.total_completed = pool.total_completed + processed
  return processed
@end

@! Coordinated Tick of all 3 workers in pipeline order
@fn worker_pool_tick_all(pool)
  p_layout = worker_pool_tick_layout(pool)
  p_net = worker_pool_tick_network(pool)
  p_render = worker_pool_tick_render(pool)
  return p_layout + p_net + p_render
@end

@! Run pool for N iterations
@fn worker_pool_run_cycles(pool, count)
  c = 0
  tot = 0
  @while c < count
    tot = tot + worker_pool_tick_all(pool)
    c = c + 1
  @end
  return tot
@end

@! ============================================================================
@! 8. TELEMETRY & STATS
@! ============================================================================

@fn worker_pool_get_stats(pool)
  w_r = pool.workers[WORKER_ID_RENDER()]
  w_l = pool.workers[WORKER_ID_LAYOUT()]
  w_n = pool.workers[WORKER_ID_NETWORK()]

  d1 = pool.ring_layout_to_render.dropped_sqes + pool.ring_network_to_render.dropped_sqes
  d2 = pool.ring_render_to_layout.dropped_sqes + pool.ring_network_to_layout.dropped_sqes
  total_dropped = d1 + d2 + pool.ring_layout_to_network.dropped_sqes

  p1 = ring_buffer_pending_sqe_count(pool.ring_layout_to_render) + ring_buffer_pending_sqe_count(pool.ring_network_to_render)
  p2 = ring_buffer_pending_sqe_count(pool.ring_render_to_layout) + ring_buffer_pending_sqe_count(pool.ring_network_to_layout)
  pending = p1 + p2 + ring_buffer_pending_sqe_count(pool.ring_layout_to_network)

  total_cap = pool.queue_capacity * 5
  sat_pct = 0
  @if total_cap > 0
    sat_pct = (pending * 100) / total_cap
  @end

  active_count = 0
  @if w_r.worker_state == WORKER_STATE_RUNNING() active_count = active_count + 1 @end
  @if w_l.worker_state == WORKER_STATE_RUNNING() active_count = active_count + 1 @end
  @if w_n.worker_state == WORKER_STATE_RUNNING() active_count = active_count + 1 @end

  return {
    total_dispatched: pool.total_dispatched,
    total_completed: pool.total_completed,
    render_tasks: w_r.tasks_processed,
    layout_tasks: w_l.tasks_processed,
    network_tasks: w_n.tasks_processed,
    dropped_tasks: total_dropped,
    active_workers: active_count,
    saturation_pct: sat_pct
  }
@end
