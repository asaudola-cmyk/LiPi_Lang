@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: AUTONOMOUS TASK ROUTING (F19)
@! File: tests/e2e/tier1_features/ai/test_f19_router.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/swarm/types"
import "universe/swarm/discovery"
import "universe/swarm/task_registry"
import "universe/swarm/router"
import "universe/swarm/swarm"

@fn task_square(x)
  return x * x
@end

@fn task_double(x)
  return x * 2
@end

@fn task_cube(x)
  return x * x * x
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature 19: Autonomous Task Routing Coverage")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! TC-F19-01: Load Monitor Initialization & Metric Calculation
  @! --------------------------------------------------------------------------
  total = total + 1
  mon = load_monitor_new(4)

  mon_ok = (mon.active_threads == 0) && (mon.pending_tasks == 0) && (mon.load_threshold == 4)
  load0 = load_monitor_get_load(mon)
  load0_ok = (load0 == 0)

  @if mon_ok != 0 && load0_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F19-01: Load monitor initialization and baseline load metric (load = 0, threshold = 4)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F19-01: Load monitor initialization")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F19-02: Active & Pending Task Counters Tracking
  @! --------------------------------------------------------------------------
  total = total + 1
  load_monitor_inc_active(mon)
  load_monitor_inc_active(mon)
  load_after_act = load_monitor_get_load(mon) @! 2

  load_monitor_inc_pending(mon)
  load_monitor_inc_pending(mon)
  load_monitor_inc_pending(mon)
  load_after_pend = load_monitor_get_load(mon) @! 5

  load_monitor_dec_active(mon)
  load_after_dec_act = load_monitor_get_load(mon) @! 4

  load_monitor_dec_pending(mon)
  load_after_dec_pend = load_monitor_get_load(mon) @! 3

  counters_ok = (load_after_act == 2) && (load_after_pend == 5) && (load_after_dec_act == 4) && (load_after_dec_pend == 3)

  @if counters_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F19-02: Dynamic active/pending task counter tracking (load sequence: 2 -> 5 -> 4 -> 3)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F19-02: Task counters tracking")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F19-03: Task Routing Decision Engine (Local vs Remote vs Auto)
  @! --------------------------------------------------------------------------
  total = total + 1
  peers = peer_table_new()
  peer_info = {
    node_id: "node_beta",
    host: "127.0.0.1",
    tcp_port: 9001,
    udp_port: 9002,
    cluster_name: "maya-swarm",
    capabilities: ["gemm", "cpu"]
  }
  peer_table_upsert(peers, peer_info, 1, 100) @! Remote peer load is 1

  @! Case A: Policy "LOCAL" -> always local
  dec_local = router_decide("LOCAL", 10, peers, 2)
  dec_loc_ok = (dec_local.destination == "LOCAL") && (dec_local.should_route_remote == 0)

  @! Case B: Policy "AUTO" with local load (1) < threshold (4) -> local
  dec_under = router_decide("AUTO", 1, peers, 4)
  dec_under_ok = (dec_under.destination == "LOCAL") && (dec_under.should_route_remote == 0)

  @! Case C: Policy "AUTO" with local load (5) >= threshold (2) and peer load (1) < 5 -> remote
  dec_over = router_decide("AUTO", 5, peers, 2)
  dec_over_ok = (dec_over.destination == "REMOTE") && (dec_over.should_route_remote == 1) && (dec_over.target_node.info.node_id == "node_beta")

  @! Case D: Policy "REMOTE" -> forces remote
  dec_rem = router_decide("REMOTE", 0, peers, 10)
  dec_rem_ok = (dec_rem.destination == "REMOTE") && (dec_rem.should_route_remote == 1)

  dec_all_ok = (dec_loc_ok != 0) && (dec_under_ok != 0) && (dec_over_ok != 0) && (dec_rem_ok != 0)

  @if dec_all_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F19-03: Task router decisions (LOCAL, AUTO under-threshold, AUTO over-threshold, REMOTE)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F19-03: Routing decision engine")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F19-04: Task Registry & Decentralized Worker Distribution
  @! --------------------------------------------------------------------------
  total = total + 1
  reg = task_registry_new()
  task_registry_register(reg, "square", task_square)
  task_registry_register(reg, "double", task_double)
  task_registry_register(reg, "cube", task_cube)

  reg_count_ok = (reg.tasks.len() == 3)
  res_sq = task_registry_invoke(reg, "square", 8)   @! 64
  res_db = task_registry_invoke(reg, "double", 15)  @! 30
  res_cb = task_registry_invoke(reg, "cube", 3)     @! 27

  invoke_ok = (res_sq == 64) && (res_db == 30) && (res_cb == 27)

  @if reg_count_ok != 0 && invoke_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F19-04: Task registry registration and invocation (square, double, cube)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F19-04: Task registry")
  @end

  @! --------------------------------------------------------------------------
  @! TC-F19-05: Task Result Aggregation & Join Handle Lifecycle
  @! --------------------------------------------------------------------------
  total = total + 1
  h1 = swarm_join_handle_new(101, 0, 0, "node_alpha", 0)
  h1.completed = 1
  h1.result = task_registry_invoke(reg, "square", 10) @! 100

  h2 = swarm_join_handle_new(102, 0, 0, "node_alpha", 0)
  h2.completed = 1
  h2.result = task_registry_invoke(reg, "double", 50) @! 100

  h3 = swarm_join_handle_new(103, 0, 0, "node_alpha", 0)
  h3.completed = 1
  h3.result = task_registry_invoke(reg, "cube", 5)    @! 125

  r1 = swarm_join(h1)
  r2 = swarm_join(h2)
  r3 = swarm_join(h3)
  agg_sum = r1 + r2 + r3 @! 100 + 100 + 125 = 325

  agg_ok = (r1 == 100) && (r2 == 100) && (r3 == 125) && (agg_sum == 325)

  @if agg_ok != 0
    passed = passed + 1
    println("  [PASS] TC-F19-05: Swarm join handle aggregation across 3 distributed tasks (sum = 325)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-F19-05: Task result aggregation")
  @end

  println("=================================================================")
  println("📊 Feature 19 Summary: " + passed.to_str() + "/" + total.to_str() + " tests passed")
  println("=================================================================")

  @if failed > 0
    return 1
  @end
  return 0
@end
