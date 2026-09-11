@! ============================================================================
@! MAYA UNIVERSE TEST SUITE — AUTONOMOUS MULTI-AGENT SWARM & TASK ROUTING
@! Module: tests/universe/test_ai_swarm.maya
@! Features: F18 Multi-Agent Cognitive Roles, State Machines, Async Mailboxes,
@! F19 Pub/Sub Event Bus, Dynamic Task Routing, Multi-Stage DAG Pipelines & Reflection Loops.
@! 100% Pure Maya Implementation — Zero Foreign Code Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/ai/swarm"


@fn assert_eq_int(actual: i64, expected: i64, test_name: string) -> i64
  @if actual == expected
    println("    ✓ [PASS] ")
    println(test_name)
    return 1
  @else
    println("    ✗ [FAIL] ")
    println(test_name)
    println("Expected:")
    print_int(expected)
    println("Actual:")
    print_int(actual)
    exit(1)
  @end
  return 0
@end
@fn assert_true(cond: i64, test_name: string) -> i64
  @if cond
    println("    ✓ [PASS] ")
    println(test_name)
    return 1
  @else
    println("    ✗ [FAIL] ")
    println(test_name)
    exit(1)
  @end
  return 0
@end

@! ============================================================================
@! Tier 1: Agent Roles, Spawning & State Machine Transitions
@! ============================================================================

@fn run_tier1_agent_lifecycle_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 1: Agent Roles, Spawning & State Machine Lifecycle Tests]")
  println("-----------------------------------------------------------------")

  cluster = ai_cluster_new("m3_test_cluster")
  assert_eq_int(cluster.agents.len(), 0, "Initial cluster agents count == 0")

  planner = ai_agent_spawn(cluster, role_planner(), "MasterPlanner", "Decompose milestones", 3)
  coder = ai_agent_spawn(cluster, role_coder(), "MayaCoder", "Generate Maya code", 3)
  critic = ai_agent_spawn(cluster, role_critic(), "StrictCritic", "Enforce purity and tests", 3)
  synth = ai_agent_spawn(cluster, role_synthesizer(), "Synthesizer", "Merge and release", 3)

  assert_eq_int(cluster.agents.len(), 4, "Cluster contains 4 spawned agents")
  assert_eq_int(planner.state, state_idle(), "Planner initial state == IDLE (0)")
  assert_eq_int(coder.state, state_idle(), "Coder initial state == IDLE (0)")
  assert_eq_int(critic.state, state_idle(), "Critic initial state == IDLE (0)")
  assert_eq_int(synth.state, state_idle(), "Synthesizer initial state == IDLE (0)")

  @! Test State Transitions
  ai_agent_transition_state(planner, state_thinking())
  assert_eq_int(planner.state, state_thinking(), "Planner transitioned to THINKING (1)")
  assert_eq_int(planner.previous_state, state_idle(), "Planner previous state was IDLE (0)")

  ai_agent_transition_state(planner, state_executing())
  assert_eq_int(planner.state, state_executing(), "Planner transitioned to EXECUTING (2)")

  ai_agent_transition_state(planner, state_reviewing())
  assert_eq_int(planner.state, state_reviewing(), "Planner transitioned to REVIEWING (3)")

  ai_agent_transition_state(planner, state_completed())
  assert_eq_int(planner.state, state_completed(), "Planner transitioned to COMPLETED (4)")

  @! Pause and Resume
  ai_agent_pause(coder)
  assert_eq_int(coder.state, state_paused(), "Coder transitioned to PAUSED (6)")

  ai_agent_resume(coder)
  assert_eq_int(coder.state, state_idle(), "Coder resumed to previous state IDLE (0)")

  @! Terminate
  ai_agent_terminate(synth)
  assert_eq_int(synth.state, state_terminated(), "Synthesizer terminated (7)")

  println("    ✓ [PASS] Agent Lifecycle & State Machine Transitions verified!")
  return 1
@end

@! ============================================================================
@! Tier 2: Priority Mailboxes & Control Message Dispatch
@! ============================================================================

@fn run_tier2_mailbox_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 2: Priority Mailbox & Control Queue Tests]")
  println("-----------------------------------------------------------------")

  cluster = ai_cluster_new("mailbox_test_cluster")
  worker = ai_agent_spawn(cluster, role_coder(), "WorkerAgent", "Execute code", 3)

  @! Send normal data message
  task_msg = {
    msg_id: 101,
    sender_id: "ORCHESTRATOR",
    recipient_id: worker.agent_id,
    msg_type: "TASK_PAYLOAD",
    payload: "Implement Tensor Squeeze",
    priority: priority_normal(),
    timestamp: 0
  }
  ai_agent_send_message(worker, task_msg)
  assert_eq_int(worker.mailbox.task_queue.len(), 1, "Task queue received 1 message")
  assert_eq_int(worker.mailbox.control_queue.len(), 0, "Control queue is empty")

  @! Send high-priority control message
  ctrl_msg = {
    msg_id: 102,
    sender_id: "SUPERVISOR",
    recipient_id: worker.agent_id,
    msg_type: "CONTROL_PAUSE",
    payload: "Pause immediately",
    priority: priority_urgent(),
    timestamp: 0
  }
  ai_agent_send_message(worker, ctrl_msg)
  assert_eq_int(worker.mailbox.control_queue.len(), 1, "Control queue received 1 urgent message")

  @! Step worker: Control message should be processed first!
  ai_agent_step(worker, cluster)
  assert_eq_int(worker.state, state_paused(), "Worker paused immediately due to control message")
  assert_eq_int(worker.mailbox.control_queue.len(), 0, "Control queue consumed")
  assert_eq_int(worker.mailbox.task_queue.len(), 1, "Task queue message retained while paused")

  @! Resume worker
  ai_agent_resume(worker)
  assert_eq_int(worker.state, state_idle(), "Worker resumed to IDLE")

  @! Step worker: Now task queue is processed!
  ai_agent_step(worker, cluster)
  assert_eq_int(worker.state, state_thinking(), "Worker stepped from IDLE to THINKING on task message")
  assert_eq_int(worker.mailbox.task_queue.len(), 0, "Task queue message consumed")

  println("    ✓ [PASS] Priority Mailbox & Control Queue Dispatch verified!")
  return 1
@end

@! ============================================================================
@! Tier 3: Topic Pub/Sub Message Bus
@! ============================================================================

@fn run_tier3_pubsub_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 3: Topic Pub/Sub Event Bus Tests]")
  println("-----------------------------------------------------------------")

  cluster = ai_cluster_new("pubsub_test_cluster")
  bus = cluster.bus

  planner = ai_agent_spawn(cluster, role_planner(), "Planner", "", 3)
  coder1 = ai_agent_spawn(cluster, role_coder(), "Coder1", "", 3)
  coder2 = ai_agent_spawn(cluster, role_coder(), "Coder2", "", 3)
  critic = ai_agent_spawn(cluster, role_critic(), "Critic", "", 3)

  @! Subscribe agents to topics
  pubsub_subscribe(bus, "code/proposals", critic.agent_id)
  pubsub_subscribe(bus, "planning/goals", coder1.agent_id)
  pubsub_subscribe(bus, "planning/goals", coder2.agent_id)

  assert_eq_int(bus.subscriptions.len(), 3, "Total active subscriptions == 3")

  @! Publish to "planning/goals" -> Coder1 and Coder2 should receive it
  delivered = pubsub_publish(bus, cluster, "planning/goals", planner.agent_id, "Build M3 AI Core")
  assert_eq_int(delivered, 2, "Broadcast delivered to 2 subscribers")
  assert_eq_int(coder1.mailbox.task_queue.len(), 1, "Coder1 received pubsub message")
  assert_eq_int(coder2.mailbox.task_queue.len(), 1, "Coder2 received pubsub message")
  assert_eq_int(critic.mailbox.task_queue.len(), 0, "Critic did not receive unrelated topic")

  @! Unsubscribe Coder2
  pubsub_unsubscribe(bus, "planning/goals", coder2.agent_id)
  assert_eq_int(bus.subscriptions.len(), 2, "Subscriptions count after unsubscribe == 2")

  delivered2 = pubsub_publish(bus, cluster, "planning/goals", planner.agent_id, "Updated Goal")
  assert_eq_int(delivered2, 1, "Broadcast delivered to 1 remaining subscriber")
  assert_eq_int(coder1.mailbox.task_queue.len(), 2, "Coder1 received second message")
  assert_eq_int(coder2.mailbox.task_queue.len(), 1, "Coder2 did not receive message after unsubscribe")

  println("    ✓ [PASS] Topic Pub/Sub Event Bus verified!")
  return 1
@end

@! ============================================================================
@! Tier 4: Dynamic Task Routing & Load Balancing
@! ============================================================================

@fn run_tier4_task_routing_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 4: Dynamic Task Routing & Load Balancing Tests]")
  println("-----------------------------------------------------------------")

  cluster = ai_cluster_new("routing_test_cluster")
  coder1 = ai_agent_spawn(cluster, role_coder(), "CoderA", "", 3)
  coder2 = ai_agent_spawn(cluster, role_coder(), "CoderB", "", 3)

  task1 = task_new(1, "Task 1", role_coder(), priority_high(), "Implement AdamW", [])
    task2 = task_new(2, "Task 2", role_coder(), priority_high(), "Implement RoPE", [])

  @! Dispatch Task 1 -> Assigns to Coder1 (IDLE)
  dispatched1 = task_router_dispatch(cluster, task1)
  assert_eq_int(dispatched1, 1, "Task 1 dispatched successfully")
  assert_eq_int(string_eq(task1.status, "ASSIGNED"), 1, "Task 1 marked ASSIGNED")
  assert_eq_int(coder1.state, state_thinking(), "Coder1 transitioned to THINKING")

  @! Dispatch Task 2 -> Assigns to Coder2 (IDLE, least loaded)
  dispatched2 = task_router_dispatch(cluster, task2)
  assert_eq_int(dispatched2, 1, "Task 2 dispatched successfully")
  assert_eq_int(string_eq(task2.assigned_agent_id, coder2.agent_id), 1, "Task 2 load-balanced to Coder2")

  println("    ✓ [PASS] Dynamic Task Routing & Load Balancing verified!")
  return 1
@end

@! ============================================================================
@! Tier 5: Multi-Stage DAG Workflow Execution & Reflection Loop
@! ============================================================================

@fn run_tier5_dag_pipeline_tests() -> i64
  println("-----------------------------------------------------------------")
  println("▶ [TIER 5: Multi-Stage DAG Pipeline & Reflection Loop Tests]")
  println("-----------------------------------------------------------------")

  cluster = ai_cluster_new("pipeline_cluster")
  planner = ai_agent_spawn(cluster, role_planner(), "Planner", "", 3)
  coder = ai_agent_spawn(cluster, role_coder(), "Coder", "", 3)
  critic = ai_agent_spawn(cluster, role_critic(), "Critic", "", 3)
  synth = ai_agent_spawn(cluster, role_synthesizer(), "Synth", "", 3)

  pipeline = pipeline_new("pl_1", "Autonomous AI Development Pipeline", 3)
  s1 = pipeline_stage_new("s1_plan", "Architecture Planning", role_planner(), "Design Tensor Squeeze", [])
  s2 = pipeline_stage_new("s2_code", "Code Implementation", role_coder(), "Implement tensor_squeeze", ["s1_plan"])
  s3 = pipeline_stage_new("s3_critique", "Quality Audit", role_critic(), "Verify tensor_squeeze purity", ["s2_code"])
  s4 = pipeline_stage_new("s4_synth", "Release Packaging", role_synthesizer(), "Package tensor_squeeze module", ["s3_critique"])

  pipeline = pipeline_add_stage(pipeline, s1)
  pipeline = pipeline_add_stage(pipeline, s2)
  pipeline = pipeline_add_stage(pipeline, s3)
  pipeline = pipeline_add_stage(pipeline, s4)

  assert_eq_int(pipeline.stages.len(), 4, "Pipeline configured with 4 DAG stages")

  @! Step through the pipeline until completion
  step_count = 0
  @while pipeline.status != "COMPLETED" && pipeline.status != "FAILED" && step_count < 30
    pipeline = pipeline_run_step(pipeline, cluster)
    ai_cluster_step_all(cluster)
    step_count = step_count + 1
  @end

  assert_eq_int(string_eq(pipeline.status, "COMPLETED"), 1, "Pipeline reached COMPLETED status")
  assert_true(pipeline.final_output.len() > 0, "Pipeline produced non-empty final release artifact")

  println("    ✓ [PASS] Multi-Stage DAG Pipeline with Reflection Loops verified!")
  return 1
@end

@! ============================================================================
@! Master Test Runner
@! ============================================================================

@fn main() -> i64
  println("=================================================================")
  println("🐝 MAYA UNIVERSE AUTONOMOUS MULTI-AGENT SWARM (F18/F19) TEST SUITE")
  println("=================================================================")

  t1 = run_tier1_agent_lifecycle_tests()
  t2 = run_tier2_mailbox_tests()
  t3 = run_tier3_pubsub_tests()
  t4 = run_tier4_task_routing_tests()
  t5 = run_tier5_dag_pipeline_tests()

  total = t1 + t2 + t3 + t4 + t5
  println("=================================================================")
  println("🎉 ALL SWARM SUITE TESTS PASSED SUCCESSFULLY (")
  print_int(total)
  println("/5 TIERS)")
  println("=================================================================")
  return 0
@end
