@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — DOM-BYPASS WEB FRONTEND ENGINE
@! Module: universe/web/frontend/dom_bypass/input_dispatcher.maya
@! Milestone: M6 — DOM-Bypass Host Runtime & Full E2E Integration
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features:
@! - High-level DOM Event Router & Translator
@! - Converts Pointer, Keyboard, Wheel, Touch & Gesture events to typed InputEventMessage
@! - Hit-testing with z-index ordering against local & @remote interactive regions
@! - Focus, Hover & Active Drag Session tracking
@! - Dynamic routing to Layout Worker (Worker Pool) or @remote WebRTC DataChannel
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"
import "universe/web/frontend/concurrency/message_protocol"
import "universe/web/frontend/concurrency/worker_pool"
import "universe/web/frontend/remote/mod"

@! ============================================================================
@! 1. GESTURE & DOM EVENT CONSTANTS
@! ============================================================================

@fn GESTURE_TYPE_NONE() return 0 @end
@fn GESTURE_TYPE_PINCH() return 1 @end
@fn GESTURE_TYPE_PAN() return 2 @end
@fn GESTURE_TYPE_DOUBLE_TAP() return 3 @end

@fn EVENT_MODIFIER_NONE() return 0 @end
@fn EVENT_MODIFIER_SHIFT() return 1 @end
@fn EVENT_MODIFIER_CTRL() return 2 @end
@fn EVENT_MODIFIER_ALT() return 4 @end
@fn EVENT_MODIFIER_META() return 8 @end

@! ============================================================================
@! 2. DATA STRUCTURES
@! ============================================================================

@struct RawDomEvent
  raw_event_type: string
  raw_client_x: i64
  raw_client_y: i64
  raw_button: i64
  raw_buttons: i64
  raw_key_code: i64
  raw_key_char: string
  raw_modifiers: i64
  raw_delta_x: i64
  raw_delta_y: i64
  raw_delta_z: i64
  raw_pointer_id: i64
  raw_pointer_type: string
  raw_pressure: f64
  raw_touches_count: i64
  raw_touch_distance: f64
  raw_timestamp: i64
@end

@fn raw_dom_event_new(event_type, client_x, client_y)
  return {
    raw_event_type: event_type,
    raw_client_x: client_x,
    raw_client_y: client_y,
    raw_button: 0,
    raw_buttons: 0,
    raw_key_code: 0,
    raw_key_char: "",
    raw_modifiers: 0,
    raw_delta_x: 0,
    raw_delta_y: 0,
    raw_delta_z: 0,
    raw_pointer_id: 1,
    raw_pointer_type: "mouse",
    raw_pressure: 1.0,
    raw_touches_count: 1,
    raw_touch_distance: 0.0,
    raw_timestamp: 0
  }
@end

@fn raw_dom_pointer_event(event_type, client_x, client_y, button, pointer_id, modifiers, timestamp)
  return {
    raw_event_type: event_type,
    raw_client_x: client_x,
    raw_client_y: client_y,
    raw_button: button,
    raw_buttons: 1,
    raw_key_code: 0,
    raw_key_char: "",
    raw_modifiers: modifiers,
    raw_delta_x: 0,
    raw_delta_y: 0,
    raw_delta_z: 0,
    raw_pointer_id: pointer_id,
    raw_pointer_type: "pointer",
    raw_pressure: 1.0,
    raw_touches_count: 1,
    raw_touch_distance: 0.0,
    raw_timestamp: timestamp
  }
@end

@fn raw_dom_key_event(event_type, key_code, key_char, modifiers, timestamp)
  return {
    raw_event_type: event_type,
    raw_client_x: 0,
    raw_client_y: 0,
    raw_button: 0,
    raw_buttons: 0,
    raw_key_code: key_code,
    raw_key_char: key_char,
    raw_modifiers: modifiers,
    raw_delta_x: 0,
    raw_delta_y: 0,
    raw_delta_z: 0,
    raw_pointer_id: 0,
    raw_pointer_type: "keyboard",
    raw_pressure: 0.0,
    raw_touches_count: 0,
    raw_touch_distance: 0.0,
    raw_timestamp: timestamp
  }
@end

@fn raw_dom_wheel_event(client_x, client_y, delta_x, delta_y, timestamp)
  return {
    raw_event_type: "wheel",
    raw_client_x: client_x,
    raw_client_y: client_y,
    raw_button: 0,
    raw_buttons: 0,
    raw_key_code: 0,
    raw_key_char: "",
    raw_modifiers: 0,
    raw_delta_x: delta_x,
    raw_delta_y: delta_y,
    raw_delta_z: 0,
    raw_pointer_id: 1,
    raw_pointer_type: "mouse",
    raw_pressure: 0.0,
    raw_touches_count: 0,
    raw_touch_distance: 0.0,
    raw_timestamp: timestamp
  }
@end

@fn raw_dom_touch_event(event_type, client_x, client_y, touches_count, touch_dist, timestamp)
  return {
    raw_event_type: event_type,
    raw_client_x: client_x,
    raw_client_y: client_y,
    raw_button: 0,
    raw_buttons: 1,
    raw_key_code: 0,
    raw_key_char: "",
    raw_modifiers: 0,
    raw_delta_x: 0,
    raw_delta_y: 0,
    raw_delta_z: 0,
    raw_pointer_id: 1,
    raw_pointer_type: "touch",
    raw_pressure: 1.0,
    raw_touches_count: touches_count,
    raw_touch_distance: touch_dist,
    raw_timestamp: timestamp
  }
@end

@struct GestureTracker
  gesture_active: bool
  gesture_kind: i64
  gesture_start_x: i64
  gesture_start_y: i64
  gesture_cur_x: i64
  gesture_cur_y: i64
  gesture_delta_x: i64
  gesture_delta_y: i64
  gesture_init_dist: f64
  gesture_cur_scale: f64
  gesture_start_ts: i64
@end

@fn gesture_tracker_new()
  return {
    gesture_active: false,
    gesture_kind: GESTURE_TYPE_NONE(),
    gesture_start_x: 0,
    gesture_start_y: 0,
    gesture_cur_x: 0,
    gesture_cur_y: 0,
    gesture_delta_x: 0,
    gesture_delta_y: 0,
    gesture_init_dist: 0.0,
    gesture_cur_scale: 1.0,
    gesture_start_ts: 0
  }
@end

@struct InteractiveRegion
  region_x: i64
  region_y: i64
  region_w: i64
  region_h: i64
  region_node_id: i64
  region_z_index: i64
  region_is_remote: bool
  region_session_id: string
  region_clickable: bool
  region_draggable: bool
  region_focusable: bool
@end

@fn interactive_region_new(node_id, x, y, w, h, z_index, is_remote, session_id)
  return {
    region_x: x,
    region_y: y,
    region_w: w,
    region_h: h,
    region_node_id: node_id,
    region_z_index: z_index,
    region_is_remote: is_remote,
    region_session_id: session_id,
    region_clickable: true,
    region_draggable: is_remote,
    region_focusable: true
  }
@end

@struct DispatchResult
  dispatch_success: bool
  dispatch_target_id: i64
  dispatch_is_remote: bool
  dispatch_route_target: string
  dispatch_msg: InputEventMessage
@end

@struct InputDispatcher
  disp_dpr: f64
  disp_canvas_w: i64
  disp_canvas_h: i64
  disp_focused_node: i64
  disp_hovered_node: i64
  disp_active_pointer: i64
  disp_pointer_down: bool
  disp_last_pointer_x: i64
  disp_last_pointer_y: i64
  disp_last_click_ts: i64
  disp_last_click_x: i64
  disp_last_click_y: i64
  disp_gesture: GestureTracker
  disp_regions: array
  disp_total_received: i64
  disp_routed_local: i64
  disp_routed_remote: i64
  disp_dropped: i64
@end

@! ============================================================================
@! 3. INPUT DISPATCHER INITIALIZATION & REGION MANAGEMENT
@! ============================================================================

@fn input_dispatcher_new(canvas_w, canvas_h, dpr)
  @if canvas_w <= 0 canvas_w = 800 @end
  @if canvas_h <= 0 canvas_h = 600 @end
  @if dpr <= 0.0 dpr = 1.0 @end

  return {
    disp_dpr: dpr,
    disp_canvas_w: canvas_w,
    disp_canvas_h: canvas_h,
    disp_focused_node: -1,
    disp_hovered_node: -1,
    disp_active_pointer: -1,
    disp_pointer_down: false,
    disp_last_pointer_x: 0,
    disp_last_pointer_y: 0,
    disp_last_click_ts: 0,
    disp_last_click_x: 0,
    disp_last_click_y: 0,
    disp_gesture: gesture_tracker_new(),
    disp_regions: [],
    disp_total_received: 0,
    disp_routed_local: 0,
    disp_routed_remote: 0,
    disp_dropped: 0
  }
@end

@fn input_dispatcher_set_dpr(disp, dpr)
  @if dpr <= 0.0 dpr = 1.0 @end
  disp.disp_dpr = dpr
  return disp
@end

@fn input_dispatcher_register_region(disp, region)
  disp.disp_regions = disp.disp_regions.push(region)
  return disp
@end

@fn input_dispatcher_clear_regions(disp)
  disp.disp_regions = []
  return disp
@end

@! ============================================================================
@! 4. HIT TESTING ENGINE (Z-INDEX AWARE)
@! ============================================================================

@fn input_dispatcher_hit_test(disp, x, y)
  best_region = 0
  highest_z = -999999
  
  i = 0
  @while i < disp.disp_regions.len()
    reg = disp.disp_regions[i]
    @if x >= reg.region_x && x < (reg.region_x + reg.region_w) && y >= reg.region_y && y < (reg.region_y + reg.region_h)
      @if reg.region_z_index >= highest_z
        highest_z = reg.region_z_index
        best_region = reg
      @end
    @end
    i = i + 1
  @end

  return best_region
@end

@! ============================================================================
@! 5. EVENT TRANSLATION TO TYPED InputEventMessage
@! ============================================================================

@fn input_dispatcher_convert_event(disp, raw_event)
  ev_type_str = raw_event.raw_event_type
  opcode_type = INPUT_EVENT_POINTER_MOVE()

  @if ev_type_str == "pointerdown" || ev_type_str == "mousedown" || ev_type_str == "touchstart"
    opcode_type = INPUT_EVENT_POINTER_DOWN()
  @else
    @if ev_type_str == "pointerup" || ev_type_str == "mouseup" || ev_type_str == "touchend"
      opcode_type = INPUT_EVENT_POINTER_UP()
    @else
      @if ev_type_str == "pointermove" || ev_type_str == "mousemove" || ev_type_str == "touchmove"
        opcode_type = INPUT_EVENT_POINTER_MOVE()
      @else
        @if ev_type_str == "keydown" || ev_type_str == "keypress"
          opcode_type = INPUT_EVENT_KEY_DOWN()
        @else
          @if ev_type_str == "keyup"
            opcode_type = INPUT_EVENT_KEY_UP()
          @else
            @if ev_type_str == "wheel" || ev_type_str == "scroll"
              opcode_type = INPUT_EVENT_WHEEL()
            @else
              @if ev_type_str == "resize"
                opcode_type = INPUT_EVENT_RESIZE()
              @end
            @end
          @end
        @end
      @end
    @end
  @end

  return {
    event_type: opcode_type,
    target_x: raw_event.raw_client_x,
    target_y: raw_event.raw_client_y,
    key_code: raw_event.raw_key_code,
    modifiers: raw_event.raw_modifiers,
    timestamp: raw_event.raw_timestamp,
    pointer_id: raw_event.raw_pointer_id,
    button: raw_event.raw_button
  }
@end

@! ============================================================================
@! 6. GESTURE RECOGNITION (PINCH, PAN, DOUBLE TAP)
@! ============================================================================

@fn input_dispatcher_update_gestures(disp, raw_event)
  gt = disp.disp_gesture

  @if raw_event.raw_event_type == "touchstart" || raw_event.raw_event_type == "pointerdown"
    gt.gesture_active = true
    gt.gesture_start_x = raw_event.raw_client_x
    gt.gesture_start_y = raw_event.raw_client_y
    gt.gesture_cur_x = raw_event.raw_client_x
    gt.gesture_cur_y = raw_event.raw_client_y
    gt.gesture_delta_x = 0
    gt.gesture_delta_y = 0
    gt.gesture_start_ts = raw_event.raw_timestamp

    @if raw_event.raw_touches_count >= 2 && raw_event.raw_touch_distance > 0.0
      gt.gesture_kind = GESTURE_TYPE_PINCH()
      gt.gesture_init_dist = raw_event.raw_touch_distance
      gt.gesture_cur_scale = 1.0
    @else
      gt.gesture_kind = GESTURE_TYPE_PAN()
      gt.gesture_init_dist = 0.0
      gt.gesture_cur_scale = 1.0
    @end
    disp.disp_gesture = gt
    return gt
  @end

  @if raw_event.raw_event_type == "touchmove" || raw_event.raw_event_type == "pointermove"
    @if gt.gesture_active
      gt.gesture_cur_x = raw_event.raw_client_x
      gt.gesture_cur_y = raw_event.raw_client_y
      gt.gesture_delta_x = raw_event.raw_client_x - gt.gesture_start_x
      gt.gesture_delta_y = raw_event.raw_client_y - gt.gesture_start_y

      @if gt.gesture_kind == GESTURE_TYPE_PINCH() && gt.gesture_init_dist > 0.0 && raw_event.raw_touch_distance > 0.0
        gt.gesture_cur_scale = raw_event.raw_touch_distance / gt.gesture_init_dist
      @end
    @end
    disp.disp_gesture = gt
    return gt
  @end

  @if raw_event.raw_event_type == "touchend" || raw_event.raw_event_type == "pointerup"
    gt.gesture_active = false
    gt.gesture_kind = GESTURE_TYPE_NONE()
    disp.disp_gesture = gt
    return gt
  @end

  return gt
@end

@! ============================================================================
@! 7. DISPATCH & ROUTE EVENT (LOCAL WORKER POOL VS REMOTE WEBRTC)
@! ============================================================================

@fn input_dispatcher_dispatch(disp, raw_event, worker_pool, remote_pipelines)
  disp.disp_total_received = disp.disp_total_received + 1

  @! Update gesture tracking
  input_dispatcher_update_gestures(disp, raw_event)

  @! Hit-test target region
  target_region = input_dispatcher_hit_test(disp, raw_event.raw_client_x, raw_event.raw_client_y)

  target_id = -1
  is_remote = false
  session_id = ""

  @if target_region != 0
    target_id = target_region.region_node_id
    is_remote = target_region.region_is_remote
    session_id = target_region.region_session_id
  @end

  @! Update hover & focus states
  disp.disp_hovered_node = target_id
  @if raw_event.raw_event_type == "pointerdown" || raw_event.raw_event_type == "mousedown" || raw_event.raw_event_type == "touchstart"
    disp.disp_pointer_down = true
    disp.disp_active_pointer = raw_event.raw_pointer_id
    disp.disp_focused_node = target_id
    disp.disp_last_pointer_x = raw_event.raw_client_x
    disp.disp_last_pointer_y = raw_event.raw_client_y

    @! Double click check (< 300ms & < 5px movement)
    time_diff = raw_event.raw_timestamp - disp.disp_last_click_ts
    dist_x = raw_event.raw_client_x - disp.disp_last_click_x
    @if dist_x < 0 dist_x = 0 - dist_x @end
    dist_y = raw_event.raw_client_y - disp.disp_last_click_y
    @if dist_y < 0 dist_y = 0 - dist_y @end

    @if time_diff > 0 && time_diff <= 300 && dist_x <= 5 && dist_y <= 5
      disp.disp_gesture.gesture_kind = GESTURE_TYPE_DOUBLE_TAP()
    @end

    disp.disp_last_click_ts = raw_event.raw_timestamp
    disp.disp_last_click_x = raw_event.raw_client_x
    disp.disp_last_click_y = raw_event.raw_client_y
  @end

  @if raw_event.raw_event_type == "pointerup" || raw_event.raw_event_type == "mouseup" || raw_event.raw_event_type == "touchend"
    disp.disp_pointer_down = false
    disp.disp_active_pointer = -1
  @end

  @! Convert event to message packet
  typed_msg = input_dispatcher_convert_event(disp, raw_event)

  @! ROUTE DECISION: Remote WebRTC Stream vs Local WASM Layout Worker
  @if is_remote && session_id != ""
    route_target = string_concat("REMOTE_DATACHANNEL:", session_id)

    @if remote_pipelines.len() > 0
      i = 0
      @while i < remote_pipelines.len()
        pipe = remote_pipelines[i]
        @if pipe.session_id == session_id
          remote_pipeline_send_input(pipe, typed_msg.event_type, typed_msg.target_x, typed_msg.target_y, typed_msg.key_code, typed_msg.modifiers)
          break
        @end
        i = i + 1
      @end
    @end

    disp.disp_routed_remote = disp.disp_routed_remote + 1
    return {
      dispatch_success: true,
      dispatch_target_id: target_id,
      dispatch_is_remote: true,
      dispatch_route_target: route_target,
      dispatch_msg: typed_msg
    }
  @else
    route_target = "WORKER_POOL:LAYOUT"
    @if worker_pool != 0
      tag = disp.disp_total_received
      worker_pool_send_input(worker_pool, typed_msg, tag)
    @end

    disp.disp_routed_local = disp.disp_routed_local + 1
    return {
      dispatch_success: true,
      dispatch_target_id: target_id,
      dispatch_is_remote: false,
      dispatch_route_target: route_target,
      dispatch_msg: typed_msg
    }
  @end
@end

@fn input_dispatcher_get_stats(disp)
  return {
    total_received: disp.disp_total_received,
    routed_local: disp.disp_routed_local,
    routed_remote: disp.disp_routed_remote,
    dropped: disp.disp_dropped,
    focused_node: disp.disp_focused_node,
    hovered_node: disp.disp_hovered_node,
    is_pointer_down: disp.disp_pointer_down,
    active_regions: disp.disp_regions.len(),
    gesture_type: disp.disp_gesture.gesture_kind,
    gesture_scale: disp.disp_gesture.gesture_cur_scale
  }
@end
