@! ============================================================================
@! ADVERSARIAL CHALLENGER 2 STRESS TEST SUITE: NATIVE AI NEURAL SWARM
@! Milestone M3: FlashAttention, KV-Cache, Sampling, Multi-Agent Swarm & DAG
@! 100% Pure Maya Architecture — Zero External / Foreign Code Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/ai/tensor"
import "universe/ai/transformer/gpt"
import "universe/ai/swarm"

@struct AdvTestState
  passed: i64
  failed: i64
  total: i64
@end

@fn adv_assert_eq_i64(state: AdvTestState, actual: i64, expected: i64, test_name: string) -> AdvTestState
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  ✓ [PASS] " + test_name + " (Got " + actual.to_str() + ")")
  @else
    state.failed = state.failed + 1
    println("  ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ")")
  @end
  return state
@end

@fn adv_assert_true(state: AdvTestState, cond: i64, test_name: string) -> AdvTestState
  state.total = state.total + 1
  @if cond
    state.passed = state.passed + 1
    println("  ✓ [PASS] " + test_name)
  @else
    state.failed = state.failed + 1
    println("  ✗ [FAIL] " + test_name + " (Condition was false)")
  @end
  return state
@end

@fn adv_assert_near_i64(state: AdvTestState, actual: i64, expected: i64, tol: i64, test_name: string) -> AdvTestState
  state.total = state.total + 1
  diff = actual - expected
  @if diff < 0
    diff = 0 - diff
  @end
  @if diff <= tol
    state.passed = state.passed + 1
    println("  ✓ [PASS] " + test_name + " (Got " + actual.to_str() + ", Expected " + expected.to_str() + ")")
  @else
    state.failed = state.failed + 1
    println("  ✗ [FAIL] " + test_name + " (Expected " + expected.to_str() + ", Got " + actual.to_str() + ", Diff " + diff.to_str() + ")")
  @end
  return state
@end

@fn adv_assert_str_eq(state: AdvTestState, actual: string, expected: string, test_name: string) -> AdvTestState
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  ✓ [PASS] " + test_name + " ('" + actual + "')")
  @else
    state.failed = state.failed + 1
    println("  ✗ [FAIL] " + test_name + " (Expected '" + expected + "', Got '" + actual + "')")
  @end
  return state
@end

@! ============================================================================
@! 1. FLASHATTENTION ONLINE SOFTMAX & ATTENTION EDGE CASES
@! ============================================================================

@fn test_adv_flash_attention_edge_cases(state: AdvTestState) -> AdvTestState
  println("-----------------------------------------------------------------")
  println("▶ [SUITE 1: FlashAttention Online Softmax & Attention Edge Cases]")
  println("-----------------------------------------------------------------")

  @! 1.1 T = 1 (Single Token Edge Case)
  @! For T=1, FlashAttention MUST output exactly the V vector regardless of Q and K
  q_t1 = [42, 17, 88, 9]
  k_t1 = [100, 200, 300, 400]
  v_t1 = [55, 66, 77, 88]
  head_out_t1 = flash_attention_forward_head(q_t1, k_t1, v_t1, 1, 4)
  state = adv_assert_eq_i64(state, head_out_t1.len(), 4, "T=1 FlashAttention output length == 4")
  state = adv_assert_eq_i64(state, head_out_t1[0], 55, "T=1 FlashAttention out[0] == v[0] (55)")
  state = adv_assert_eq_i64(state, head_out_t1[1], 66, "T=1 FlashAttention out[1] == v[1] (66)")
  state = adv_assert_eq_i64(state, head_out_t1[2], 77, "T=1 FlashAttention out[2] == v[2] (77)")
  state = adv_assert_eq_i64(state, head_out_t1[3], 88, "T=1 FlashAttention out[3] == v[3] (88)")

  @! 1.2 All-Zero Logits / All-Zero Inputs (Uniform Attention Weights)
  @! When Q is all zeros, scores are identical (0), so attention weights are uniform 1/T
  q_zero = [0, 0, 0, 0]
  k_zeros = [1, 2, 3, 4, 5, 6, 7, 8] @! 2 tokens, head_dim=4
  v_uniform = [10, 20, 30, 40, 30, 40, 50, 60] @! V0=[10,20,30,40], V1=[30,40,50,60]
  head_out_zero = flash_attention_forward_head(q_zero, k_zeros, v_uniform, 2, 4)
  @! Expected average: (V0 + V1) / 2 = [20, 30, 40, 50]
  state = adv_assert_eq_i64(state, head_out_zero[0], 20, "All-zero Q -> Uniform weights out[0] == 20")
  state = adv_assert_eq_i64(state, head_out_zero[1], 30, "All-zero Q -> Uniform weights out[1] == 30")
  state = adv_assert_eq_i64(state, head_out_zero[2], 40, "All-zero Q -> Uniform weights out[2] == 40")
  state = adv_assert_eq_i64(state, head_out_zero[3], 50, "All-zero Q -> Uniform weights out[3] == 50")

  @! 1.3 Extreme Temperatures / Scale Differences (Sharp Peaked Attention)
  @! Q heavily aligns with token 0, completely unaligned with token 1
  q_sharp = [100, 100, 100, 100]
  k_sharp = [100, 100, 100, 100, 0, 0, 0, 0] @! K0 matches Q, K1 orthogonal
  v_sharp = [1000, 2000, 3000, 4000, 10, 20, 30, 40]
  head_out_sharp = flash_attention_forward_head(q_sharp, k_sharp, v_sharp, 2, 4)
  @! Token 0 dot = 40000 / 8 = 5000 -> e_val = 5100; Token 1 dot = 0 -> e_val = 100
  @! Out[0] = (5100*1000 + 100*10) / 5200 = 5101000 / 5200 = 980
  state = adv_assert_near_i64(state, head_out_sharp[0], 980, 5, "Sharp peaked attention out[0] concentrates on V0")
  state = adv_assert_near_i64(state, head_out_sharp[1], 1961, 5, "Sharp peaked attention out[1] concentrates on V0")

  @! 1.4 Large Sequence Length Context (T = 32 tokens stress)
  seq_len_large = 32
  head_dim_large = 4
  k_large = []
  v_large = []
  i_tok = 0
  @while i_tok < seq_len_large
    k_large = k_large.push(i_tok)
    k_large = k_large.push(i_tok)
    k_large = k_large.push(i_tok)
    k_large = k_large.push(i_tok)
    v_large = v_large.push(10)
    v_large = v_large.push(20)
    v_large = v_large.push(30)
    v_large = v_large.push(40)
    i_tok = i_tok + 1
  @end
  q_large = [1, 1, 1, 1]
  head_out_large = flash_attention_forward_head(q_large, k_large, v_large, seq_len_large, head_dim_large)
  state = adv_assert_eq_i64(state, head_out_large.len(), 4, "T=32 FlashAttention output length == 4")
  state = adv_assert_eq_i64(state, head_out_large[0], 10, "T=32 FlashAttention homogeneous V out[0] == 10")
  state = adv_assert_eq_i64(state, head_out_large[1], 20, "T=32 FlashAttention homogeneous V out[1] == 20")
  state = adv_assert_eq_i64(state, head_out_large[2], 30, "T=32 FlashAttention homogeneous V out[2] == 30")
  state = adv_assert_eq_i64(state, head_out_large[3], 40, "T=32 FlashAttention homogeneous V out[3] == 40")

  return state
@end

@! ============================================================================
@! 2. KV-CACHE RING BUFFER CAPACITY, OVERFLOW & WRAPS
@! ============================================================================

@fn test_adv_kv_cache_ring_buffer(state: AdvTestState) -> AdvTestState
  println("-----------------------------------------------------------------")
  println("▶ [SUITE 2: KV-Cache Ring Buffer Capacity, Overflow & Appends]")
  println("-----------------------------------------------------------------")

  @! 2.1 Initialization & Empty Cache Invariants
  kv = kv_cache_new(8, 4, 1) @! max_context=8, hidden_dim=4, 1 head
  state = adv_assert_eq_i64(state, kv.max_context_len, 8, "KV-Cache max_context_len == 8")
  state = adv_assert_eq_i64(state, kv.hidden_dim, 4, "KV-Cache hidden_dim == 4")
  state = adv_assert_eq_i64(state, kv.current_pos, 0, "KV-Cache initial pos == 0")
  state = adv_assert_eq_i64(state, kv.k_cache_flat.len(), 0, "KV-Cache initial k length == 0")

  @! 2.2 Sequential Appends up to Capacity
  step = 0
  @while step < 8
    k_vec = [step * 10, step * 10 + 1, step * 10 + 2, step * 10 + 3]
    v_vec = [step * 100, step * 100 + 10, step * 100 + 20, step * 100 + 30]
    kv = kv_cache_append(kv, k_vec, v_vec)
    step = step + 1
  @end

  state = adv_assert_eq_i64(state, kv.current_pos, 8, "KV-Cache pos at capacity == 8")
  state = adv_assert_eq_i64(state, kv.k_cache_flat.len(), 32, "KV-Cache flat elements == 8 * 4 = 32")
  @! Verify token 0 and token 7 values
  state = adv_assert_eq_i64(state, kv.k_cache_flat[0], 0, "Token 0 K[0] == 0")
  state = adv_assert_eq_i64(state, kv.k_cache_flat[28], 70, "Token 7 K[0] == 70")
  state = adv_assert_eq_i64(state, kv.v_cache_flat[31], 730, "Token 7 V[3] == 730")

  @! 2.3 Appending Past Capacity (Context Growth / Overflow Monitoring)
  k_overflow = [80, 81, 82, 83]
  v_overflow = [800, 810, 820, 830]
  kv = kv_cache_append(kv, k_overflow, v_overflow)
  state = adv_assert_eq_i64(state, kv.current_pos, 9, "KV-Cache pos after overflow == 9")
  state = adv_assert_eq_i64(state, kv.k_cache_flat.len(), 36, "KV-Cache flat elements == 9 * 4 = 36")
  state = adv_assert_eq_i64(state, kv.k_cache_flat[32], 80, "Appended Token 8 K[0] == 80")

  @! 2.4 Multi-Step Rapid Burst Stress (16 successive appends)
  burst_i = 0
  @while burst_i < 16
    kv = kv_cache_append(kv, [1, 2, 3, 4], [10, 20, 30, 40])
    burst_i = burst_i + 1
  @end
  state = adv_assert_eq_i64(state, kv.current_pos, 25, "KV-Cache pos after burst == 25")
  state = adv_assert_eq_i64(state, kv.k_cache_flat.len(), 100, "KV-Cache flat elements == 25 * 4 = 100")

  return state
@end

@! ============================================================================
@! 3. TOP-K AND TOP-P NUCLEUS SAMPLING BOUNDARY CONDITIONS
@! ============================================================================

@fn test_adv_sampling_boundary_conditions(state: AdvTestState) -> AdvTestState
  println("-----------------------------------------------------------------")
  println("▶ [SUITE 3: Top-K and Top-P Nucleus Sampling Boundary Conditions]")
  println("-----------------------------------------------------------------")

  logits = [10, 50, 20, 80, 5] @! Vocab size = 5, order: idx 3 (80), idx 1 (50), idx 2 (20), idx 0 (10), idx 4 (5)

  @! 3.1 Top-K Boundary: k = 1 (Strict Greedy / Argmax)
  filtered_k1 = gpt_top_k_filter(logits, 1)
  state = adv_assert_eq_i64(state, filtered_k1[3], 80, "Top-K (k=1) preserves maximum logit 80 at idx 3")
  state = adv_assert_true(state, filtered_k1[0] < 0, "Top-K (k=1) masks idx 0")
  state = adv_assert_true(state, filtered_k1[1] < 0, "Top-K (k=1) masks idx 1")
  state = adv_assert_true(state, filtered_k1[2] < 0, "Top-K (k=1) masks idx 2")
  state = adv_assert_true(state, filtered_k1[4] < 0, "Top-K (k=1) masks idx 4")

  @! 3.2 Top-K Boundary: k = vocab_size (5) -> Full Passthrough
  filtered_k5 = gpt_top_k_filter(logits, 5)
  state = adv_assert_eq_i64(state, filtered_k5[0], 10, "Top-K (k=vocab) retains idx 0")
  state = adv_assert_eq_i64(state, filtered_k5[1], 50, "Top-K (k=vocab) retains idx 1")
  state = adv_assert_eq_i64(state, filtered_k5[2], 20, "Top-K (k=vocab) retains idx 2")
  state = adv_assert_eq_i64(state, filtered_k5[3], 80, "Top-K (k=vocab) retains idx 3")
  state = adv_assert_eq_i64(state, filtered_k5[4], 5, "Top-K (k=vocab) retains idx 4")

  @! 3.3 Top-K Invalid Boundaries: k <= 0 and k > vocab_size
  filtered_k0 = gpt_top_k_filter(logits, 0)
  state = adv_assert_eq_i64(state, filtered_k0[3], 80, "Top-K (k=0) safely returns unmasked logits")
  filtered_k_neg = gpt_top_k_filter(logits, 0 - 5)
  state = adv_assert_eq_i64(state, filtered_k_neg[3], 80, "Top-K (k < 0) safely returns unmasked logits")
  filtered_k_overflow = gpt_top_k_filter(logits, 100)
  state = adv_assert_eq_i64(state, filtered_k_overflow[3], 80, "Top-K (k > vocab) safely returns unmasked logits")

  @! 3.4 Top-P Boundary: p = 0 and p = 100
  filtered_p0 = gpt_top_p_filter(logits, 0)
  state = adv_assert_eq_i64(state, filtered_p0[3], 80, "Top-P (p=0) safely returns unmasked logits")
  filtered_p100 = gpt_top_p_filter(logits, 100)
  state = adv_assert_eq_i64(state, filtered_p100[3], 80, "Top-P (p=100) safely returns unmasked logits")

  @! 3.5 Temperature Scaling Boundaries (Cold vs Hot Sampling)
  @! Cold temperature: 10 (0.1x) -> strongly amplifies differences
  cfg_cold = { temperature: 10, top_k: 2, top_p: 90 }
  tok_cold = gpt_sample_token_advanced(logits, cfg_cold)
  state = adv_assert_eq_i64(state, tok_cold, 3, "Cold temperature (T=0.1) selects highest logit idx 3")

  @! Neutral temperature: 100 (1.0x)
  cfg_neutral = { temperature: 100, top_k: 2, top_p: 90 }
  tok_neutral = gpt_sample_token_advanced(logits, cfg_neutral)
  state = adv_assert_eq_i64(state, tok_neutral, 3, "Neutral temperature (T=1.0) selects highest logit idx 3")

  @! 3.6 Tied Logits Robustness
  tied_logits = [50, 50, 50, 50]
  tied_k2 = gpt_top_k_filter(tied_logits, 2)
  @! Threshold is 50, all elements are >= 50, so none are masked to -999999
  state = adv_assert_eq_i64(state, tied_k2[0], 50, "Tied logits Top-K(2) preserves tied element 0")
  state = adv_assert_eq_i64(state, tied_k2[1], 50, "Tied logits Top-K(2) preserves tied element 1")

  @! 3.7 Negative Logits Array
  neg_logits = [0 - 100, 0 - 50, 0 - 20, 0 - 80] @! Max is -20 (idx 2), 2nd is -50 (idx 1)
  cfg_neg = { temperature: 100, top_k: 1, top_p: 90 }
  tok_neg = gpt_sample_token_advanced(neg_logits, cfg_neg)
  state = adv_assert_eq_i64(state, tok_neg, 2, "All-negative logits selects highest (least negative) idx 2")

  return state
@end

@! ============================================================================
@! 4. MULTI-AGENT STATE MACHINE & INVALID TRANSITION INVARIANTS
@! ============================================================================

@fn test_adv_swarm_state_machine(state: AdvTestState) -> AdvTestState
  println("-----------------------------------------------------------------")
  println("▶ [SUITE 4: Cognitive Agent Deterministic State Machine]")
  println("-----------------------------------------------------------------")

  ag = ai_agent_new("agent_test_1", role_coder(), "CoderPrime", "Implement pure Maya code", 3)

  @! 4.1 Initial State Invariants
  state = adv_assert_eq_i64(state, ag.state, state_idle(), "Initial state == IDLE (0)")
  state = adv_assert_eq_i64(state, ag.metrics.tasks_completed, 0, "Initial tasks_completed == 0")
  state = adv_assert_eq_i64(state, ag.metrics.reflection_loops, 0, "Initial reflection_loops == 0")

  @! 4.2 State Progression: IDLE -> THINKING -> EXECUTING -> REVIEWING -> COMPLETED -> IDLE
  ai_agent_transition_state(ag, state_thinking())
  state = adv_assert_eq_i64(state, ag.state, state_thinking(), "Transition to THINKING (1)")
  state = adv_assert_eq_i64(state, ag.previous_state, state_idle(), "Previous state recorded as IDLE (0)")

  ai_agent_transition_state(ag, state_executing())
  state = adv_assert_eq_i64(state, ag.state, state_executing(), "Transition to EXECUTING (2)")

  ai_agent_transition_state(ag, state_reviewing())
  state = adv_assert_eq_i64(state, ag.state, state_reviewing(), "Transition to REVIEWING (3)")

  ai_agent_transition_state(ag, state_completed())
  state = adv_assert_eq_i64(state, ag.state, state_completed(), "Transition to COMPLETED (4)")

  ai_agent_transition_state(ag, state_idle())
  state = adv_assert_eq_i64(state, ag.state, state_idle(), "Transition back to IDLE (0)")

  @! 4.3 Pause & Resume Reversibility
  ai_agent_transition_state(ag, state_executing())
  ai_agent_pause(ag)
  state = adv_assert_eq_i64(state, ag.state, state_paused(), "Agent paused -> state == PAUSED (6)")
  state = adv_assert_eq_i64(state, ag.previous_state, state_executing(), "Previous state preserved as EXECUTING (2)")

  ai_agent_resume(ag)
  state = adv_assert_eq_i64(state, ag.state, state_executing(), "Agent resumed -> state restored to EXECUTING (2)")

  @! 4.4 Termination Finality (Terminal Sink State)
  ai_agent_terminate(ag)
  state = adv_assert_eq_i64(state, ag.state, state_terminated(), "Agent terminated -> state == TERMINATED (7)")

  @! Attempt to pause a terminated agent must fail
  pause_res = ai_agent_pause(ag)
  state = adv_assert_eq_i64(state, pause_res, 0, "Cannot pause a TERMINATED agent (returns 0)")
  state = adv_assert_eq_i64(state, ag.state, state_terminated(), "State remains TERMINATED (7)")

  @! Stepping a terminated agent produces 0 active steps
  cluster_dummy = ai_cluster_new("dummy")
  step_res = ai_agent_step(ag, cluster_dummy)
  state = adv_assert_eq_i64(state, step_res, 0, "Stepping a TERMINATED agent yields 0 work")

  return state
@end

@! ============================================================================
@! 5. PRIORITY MAILBOX DUAL-QUEUE & STARVATION FREEDOM UNDER HEAVY LOAD
@! ============================================================================

@fn test_adv_priority_mailbox_starvation(state: AdvTestState) -> AdvTestState
  println("-----------------------------------------------------------------")
  println("▶ [SUITE 5: Priority Mailbox Starvation Freedom & Queue Interception]")
  println("-----------------------------------------------------------------")

  cluster = ai_cluster_new("mailbox_stress_cluster")
  ag = ai_agent_spawn(cluster, role_coder(), "Worker1", "Code prompt", 5)

  @! 5.1 Enqueue 50 Normal Priority Data Tasks
  load_count = 50
  t_i = 0
  @while t_i < load_count
    msg_task = {
      msg_id: t_i + 1,
      sender_id: "ROUTER",
      recipient_id: ag.agent_id,
      msg_type: "DATA_TASK",
      payload: "Task payload #" + t_i.to_str(),
      priority: priority_normal(),
      timestamp: 0
    }
    ai_agent_send_message(ag, msg_task)
    t_i = t_i + 1
  @end

  state = adv_assert_eq_i64(state, ag.mailbox.task_queue.len(), 50, "Task queue holds 50 messages")
  state = adv_assert_eq_i64(state, ag.mailbox.control_queue.len(), 0, "Control queue is initially empty")

  @! 5.2 Inject 1 Urgent Control Message (CONTROL_PAUSE)
  ctrl_msg = {
    msg_id: 999,
    sender_id: "ORCHESTRATOR",
    recipient_id: ag.agent_id,
    msg_type: "CONTROL_PAUSE",
    payload: "Emergency Pause",
    priority: priority_urgent(),
    timestamp: 0
  }
  ai_agent_send_message(ag, ctrl_msg)
  state = adv_assert_eq_i64(state, ag.mailbox.control_queue.len(), 1, "Control queue receives urgent message")

  @! 5.3 Step Agent: Control message MUST preempt all 50 task queue items immediately
  ai_agent_step(ag, cluster)
  state = adv_assert_eq_i64(state, ag.state, state_paused(), "Agent paused immediately on step 1 (preempting data tasks)")
  state = adv_assert_eq_i64(state, ag.mailbox.control_queue.len(), 0, "Control queue drained")
  state = adv_assert_eq_i64(state, ag.mailbox.task_queue.len(), 50, "All 50 data tasks remain intact in task queue")

  @! 5.4 Send CONTROL_RESUME and step
  resume_msg = {
    msg_id: 1000,
    sender_id: "ORCHESTRATOR",
    recipient_id: ag.agent_id,
    msg_type: "CONTROL_RESUME",
    payload: "Resume Execution",
    priority: priority_urgent(),
    timestamp: 0
  }
  ai_agent_send_message(ag, resume_msg)
  ai_agent_step(ag, cluster)
  state = adv_assert_eq_i64(state, ag.state, state_idle(), "Agent resumed to IDLE on step 2")

  @! 5.5 Step again: Now picks up first task from task queue
  ai_agent_step(ag, cluster)
  state = adv_assert_eq_i64(state, ag.state, state_thinking(), "Agent transitions to THINKING on picking task 0")
  state = adv_assert_eq_i64(state, ag.mailbox.task_queue.len(), 49, "Task queue decremented to 49")
  state = adv_assert_str_eq(state, ag.current_task_payload, "Task payload #0", "Current payload is task #0")

  return state
@end

@! ============================================================================
@! 6. PUBSUB BUS TOPIC ROUTING, SUBSCRIPTIONS & EVENT BROADCASTING
@! ============================================================================

@fn test_adv_pubsub_bus_routing(state: AdvTestState) -> AdvTestState
  println("-----------------------------------------------------------------")
  println("▶ [SUITE 6: Pub/Sub Bus Topic Routing & Idempotency]")
  println("-----------------------------------------------------------------")

  cluster = ai_cluster_new("pubsub_cluster")
  ag1 = ai_agent_spawn(cluster, role_planner(), "PlannerAgent", "Planner", 3)
  ag2 = ai_agent_spawn(cluster, role_coder(), "CoderAgent", "Coder", 3)
  ag3 = ai_agent_spawn(cluster, role_critic(), "CriticAgent", "Critic", 3)

  bus = cluster.bus

  @! 6.1 Subscriptions
  s1 = pubsub_subscribe(bus, "TELEMETRY", ag1.agent_id)
  s2 = pubsub_subscribe(bus, "TELEMETRY", ag2.agent_id)
  s3 = pubsub_subscribe(bus, "SECURITY_ALERTS", ag3.agent_id)
  state = adv_assert_eq_i64(state, s1, 1, "Agent 1 subscribed to TELEMETRY")
  state = adv_assert_eq_i64(state, s2, 1, "Agent 2 subscribed to TELEMETRY")
  state = adv_assert_eq_i64(state, s3, 1, "Agent 3 subscribed to SECURITY_ALERTS")
  state = adv_assert_eq_i64(state, bus.subscriptions.len(), 3, "Total subscriptions == 3")

  @! 6.2 Idempotency: Duplicate subscription ignored
  dup_s = pubsub_subscribe(bus, "TELEMETRY", ag1.agent_id)
  state = adv_assert_eq_i64(state, dup_s, 0, "Duplicate subscription returns 0")
  state = adv_assert_eq_i64(state, bus.subscriptions.len(), 3, "Subscription count remains 3")

  @! 6.3 Publish to Topic with 2 Subscribers
  d_count = pubsub_publish(bus, cluster, "TELEMETRY", "SENSOR_1", "CPU_LOAD: 45%")
  state = adv_assert_eq_i64(state, d_count, 2, "TELEMETRY broadcast delivered to 2 subscribers")
  state = adv_assert_eq_i64(state, ag1.mailbox.task_queue.len(), 1, "Agent 1 received broadcast message")
  state = adv_assert_eq_i64(state, ag2.mailbox.task_queue.len(), 1, "Agent 2 received broadcast message")
  state = adv_assert_eq_i64(state, ag3.mailbox.task_queue.len(), 0, "Agent 3 did NOT receive TELEMETRY message")

  @! 6.4 Unsubscribe
  unsub_res = pubsub_unsubscribe(bus, "TELEMETRY", ag2.agent_id)
  state = adv_assert_eq_i64(state, unsub_res, 1, "Agent 2 successfully unsubscribed from TELEMETRY")
  state = adv_assert_eq_i64(state, bus.subscriptions.len(), 2, "Subscriptions reduced to 2")

  @! Publish again: only Agent 1 should receive
  d_count2 = pubsub_publish(bus, cluster, "TELEMETRY", "SENSOR_2", "MEMORY: 78%")
  state = adv_assert_eq_i64(state, d_count2, 1, "TELEMETRY broadcast delivered to 1 subscriber after unsub")
  state = adv_assert_eq_i64(state, ag1.mailbox.task_queue.len(), 2, "Agent 1 received 2nd message")
  state = adv_assert_eq_i64(state, ag2.mailbox.task_queue.len(), 1, "Agent 2 message count remains 1")

  return state
@end

@! ============================================================================
@! 7. MULTI-STAGE DAG PIPELINE & CONTINUOUS CRITIC REJECTION TERMINATION
@! ============================================================================

@fn test_adv_pipeline_reflection_termination(state: AdvTestState) -> AdvTestState
  println("-----------------------------------------------------------------")
  println("▶ [SUITE 7: Multi-Stage DAG Pipeline & Reflection Termination]")
  println("-----------------------------------------------------------------")

  @! 7.1 Happy Path DAG Pipeline: Planner -> Coder -> Critic -> Synthesizer
  cluster = ai_cluster_new("e2e_swarm_cluster")
  ag_planner = ai_agent_spawn(cluster, role_planner(), "P1", "Planner", 3)
  ag_coder = ai_agent_spawn(cluster, role_coder(), "C1", "Coder", 3)
  ag_critic = ai_agent_spawn(cluster, role_critic(), "R1", "Critic", 3)
  ag_synth = ai_agent_spawn(cluster, role_synthesizer(), "S1", "Synthesizer", 3)

  p = pipeline_new("pipe_happy", "Build Clean Maya Subsystem", 3)
  s1 = pipeline_stage_new("s1", "Plan Architecture", role_planner(), "Design Module Architecture", [])
  s2 = pipeline_stage_new("s2", "Code Implementation", role_coder(), "Implement Pure Maya Code", ["s1"])
  s3 = pipeline_stage_new("s3", "Review Code", role_critic(), "Verify Code Purity", ["s2"])
  s4 = pipeline_stage_new("s4", "Synthesize Release", role_synthesizer(), "Package Distribution", ["s3"])

  p = pipeline_add_stage(p, s1)
  p = pipeline_add_stage(p, s2)
  p = pipeline_add_stage(p, s3)
  p = pipeline_add_stage(p, s4)

  state = adv_assert_eq_i64(state, p.stages.len(), 4, "Pipeline initialized with 4 DAG stages")

  @! Execute pipeline across ticks until completion
  tick = 0
  @while tick < 30 && p.status != "COMPLETED" && p.status != "FAILED"
    p = pipeline_run_step(p, cluster)
    ai_cluster_step_all(cluster)
    tick = tick + 1
  @end

  state = adv_assert_str_eq(state, p.status, "COMPLETED", "Happy path DAG pipeline completed successfully")
  state = adv_assert_true(state, string_starts_with(p.final_output, "[SYNTHESIS]"), "Final output generated by Synthesizer")

  @! 7.2 Adversarial Pipeline: Continuous Critic Rejection & Bounded Termination
  @! Create defective payload containing '#' character which triggers Critic rejection
  cluster_adv = ai_cluster_new("rejection_cluster")
  ag_p2 = ai_agent_spawn(cluster_adv, role_planner(), "P2", "Planner", 2)
  ag_c2 = ai_agent_spawn(cluster_adv, role_coder(), "C2", "Coder", 2)
  ag_r2 = ai_agent_spawn(cluster_adv, role_critic(), "R2", "Critic", 2)

  p_bad = pipeline_new("pipe_bad", "Defective Code Pipeline", 2) @! Max 2 reflections
  s_bad1 = pipeline_stage_new("sb1", "Bad Code Stage", role_critic(), "Payload with defect #illegal_foreign_c_syntax", [])
  p_bad = pipeline_add_stage(p_bad, s_bad1)

  tick_bad = 0
  @while tick_bad < 20 && p_bad.status != "FAILED" && p_bad.status != "COMPLETED"
    p_bad = pipeline_run_step(p_bad, cluster_adv)
    ai_cluster_step_all(cluster_adv)
    tick_bad = tick_bad + 1
  @end

  state = adv_assert_true(state, p_bad.reflection_count >= 1, "Critic rejection triggered at least 1 reflection loop")
  state = adv_assert_true(state, p_bad.status == "FAILED" || p_bad.status == "COMPLETED", "Defective pipeline terminated deterministically (no infinite loop)")

  return state
@end

@! ============================================================================
@! MASTER ADVERSARIAL RUNNER
@! ============================================================================

@fn main() -> i64
  println("=================================================================")
  println("🔱 MAYA M3 ADVERSARIAL CHALLENGER 2 STRESS HARNESS 🔱")
  println("Subsystems: FlashAttention, KV-Cache, Sampling, Multi-Agent Swarm")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  state = test_adv_flash_attention_edge_cases(state)
  state = test_adv_kv_cache_ring_buffer(state)
  state = test_adv_sampling_boundary_conditions(state)
  state = test_adv_swarm_state_machine(state)
  state = test_adv_priority_mailbox_starvation(state)
  state = test_adv_pubsub_bus_routing(state)
  state = test_adv_pipeline_reflection_termination(state)

  println("=================================================================")
  println("📊 CHALLENGER 2 TEST EXECUTION SUMMARY:")
  println("   Total Stress Tests : " + state.total.to_str())
  println("   Passed Assertions  : " + state.passed.to_str())
  println("   Failed Assertions  : " + state.failed.to_str())
  println("=================================================================")

  @if state.failed > 0
    println("❌ CHALLENGER 2 ADVERSARIAL STRESS DETECTED FAILURES!")
    return 1
  @end

  println("🎉 ALL CHALLENGER 2 ADVERSARIAL STRESS TESTS PASSED WITH 0 FAILURES!")
  return 0
@end
