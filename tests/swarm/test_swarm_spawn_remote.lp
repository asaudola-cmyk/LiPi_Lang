@! ============================================================================
@! MAYA SWARM REMOTE TASK EXECUTION TEST SUITE (tests/swarm/test_swarm_spawn_remote.maya)
@! Tests:
@! 1. Named task function registration across nodes
@! 2. Dynamic routing decision (Local vs Remote P2P node based on load)
@! 3. Live inter-node TCP task submission & execution across cluster nodes
@! 4. Remote execution of CPU-bound algorithms (Fibonacci, Squares, Range Sum)
@! 5. Result resolution via SwarmJoinHandle and swarm_join()
@! 6. Multi-task pipelining and return value integrity
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/core/time"
import "universe/net/udp"
import "universe/net/tcp"
import "universe/swarm/types"
import "universe/swarm/protocol"
import "universe/swarm/serializer"
import "universe/swarm/discovery"
import "universe/swarm/task_registry"
import "universe/swarm/router"
import "universe/swarm/node"
import "universe/swarm/swarm"

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@fn assert_eq(state, name, actual, expected)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str())
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_true(state, name, cond)
  state.total = state.total + 1
  @if cond != 0
    state.passed = state.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> condition was false")
    return 0
  @end
@end

@! --- Task Functions ---

@fn task_fib(n)
  @if n <= 1 return n @end
  return task_fib(n - 1) + task_fib(n - 2)
@end

@fn task_square(n)
  return n * n
@end

@fn task_sum_range(n)
  sum = 0
  i = 1
  @while i <= n
    sum = sum + i
    i = i + 1
  @end
  return sum
@end

@fn main()
  println("=================================================================")
  println("▶ [MAYA SWARM REMOTE TASK SUITE] Dynamic Routing & Execution")
  println("=================================================================")

  state = { total: 0, passed: 0, failed: 0 }

  base_port = 37000

  @! --------------------------------------------------------------------------
  @! SECTION 1: Cluster Nodes & Task Registration
  @! --------------------------------------------------------------------------
  println("\n▶ Section 1: Cluster Setup & Task Registry")

  node1 = swarm_init("maya-client-1", "127.0.0.1", base_port + 1, base_port)
  node2 = swarm_init("maya-worker-2", "127.0.0.1", base_port + 2, base_port)

  assert_true(state, "TC-SPAWN-01.1: Node 1 initialized", node1.is_running != 0)
  assert_true(state, "TC-SPAWN-01.2: Node 2 initialized", node2.is_running != 0)

  @! Register tasks on Node 2 (Remote Worker)
  swarm_register_task(node2, "calc_fib", task_fib)
  swarm_register_task(node2, "square_num", task_square)
  swarm_register_task(node2, "sum_range", task_sum_range)

  @! Register same tasks on Node 1 for local fallback
  swarm_register_task(node1, "calc_fib", task_fib)
  swarm_register_task(node1, "square_num", task_square)
  swarm_register_task(node1, "sum_range", task_sum_range)

  assert_true(state, "TC-SPAWN-01.3: calc_fib registered on Node 2", task_registry_has(node2.task_registry, "calc_fib") != 0)
  assert_true(state, "TC-SPAWN-01.4: square_num registered on Node 2", task_registry_has(node2.task_registry, "square_num") != 0)
  assert_true(state, "TC-SPAWN-01.5: sum_range registered on Node 2", task_registry_has(node2.task_registry, "sum_range") != 0)

  @! Synchronize Peer Table: Node 1 knows Node 2
  peer_table_upsert(node1.peer_table, node2.info)
  peer_table_upsert(node2.peer_table, node1.info)

  @! --------------------------------------------------------------------------
  @! SECTION 2: Dynamic Routing Decisions
  @! --------------------------------------------------------------------------
  println("\n▶ Section 2: Dynamic Load-Aware Routing Decisions")

  @! Test 1: Low local load (0 < threshold 2) -> routes LOCAL
  d_low = router_decide("AUTO", 0, node1.peer_table, 2)
  assert_eq(state, "TC-ROUTER-01.1: Low load routes locally", d_low.destination, "LOCAL")

  @! Test 2: High local load (5 >= threshold 2, Node 2 load is 0) -> routes REMOTE
  d_high = router_decide("AUTO", 5, node1.peer_table, 2)
  assert_eq(state, "TC-ROUTER-01.2: High load routes remotely to Node 2", d_high.destination, "REMOTE")
  assert_eq(state, "TC-ROUTER-01.3: Target node is maya-worker-2", d_high.target_node.node_id, "maya-worker-2")

  @! --------------------------------------------------------------------------
  @! SECTION 3: Live Remote Task Dispatch & Execution (Fibonacci)
  @! --------------------------------------------------------------------------
  println("\n▶ Section 3: Live Remote Task Execution (calc_fib)")

  @! Connect from Node 1 to Node 2 over TCP to submit task
  stream = tcp_stream_connect(node2.info.host, node2.info.tcp_port)
  assert_true(state, "TC-EXEC-01.1: TCP connection to worker node established", stream.fd >= 0)

  desc_fib = task_descriptor_new(1, "calc_fib", [20], node1.info.node_id, 1001)
  protocol_send_tcp(stream.fd, MSG_TASK_SUBMIT(), serialize_task_descriptor(desc_fib))

  @! Worker steps to execute task
  swarm_node_step(node2)

  @! Node 1 receives task result
  resp_fib = protocol_recv_tcp(stream.fd)
  tcp_stream_close(stream)

  assert_eq(state, "TC-EXEC-01.2: Response packet valid", resp_fib.valid, 1)
  assert_eq(state, "TC-EXEC-01.3: Response packet is MSG_TASK_RESULT", resp_fib.msg_type, MSG_TASK_RESULT())

  join_h_fib = deserialize_join_handle(resp_fib.payload)
  assert_eq(state, "TC-EXEC-01.4: Remote task calc_fib(20) resolved exactly to 6765", join_h_fib.result, 6765)

  @! --------------------------------------------------------------------------
  @! SECTION 4: Remote Execution of Algebraic & Range Sum Tasks
  @! --------------------------------------------------------------------------
  println("\n▶ Section 4: Remote Execution of Square & Range Sum Tasks")

  @! Square Task: 25^2 = 625
  stream_sq = tcp_stream_connect(node2.info.host, node2.info.tcp_port)
  desc_sq = task_descriptor_new(2, "square_num", [25], node1.info.node_id, 1002)
  protocol_send_tcp(stream_sq.fd, MSG_TASK_SUBMIT(), serialize_task_descriptor(desc_sq))
  swarm_node_step(node2)
  resp_sq = protocol_recv_tcp(stream_sq.fd)
  tcp_stream_close(stream_sq)

  join_h_sq = deserialize_join_handle(resp_sq.payload)
  assert_eq(state, "TC-EXEC-02.1: Remote task square_num(25) resolved to 625", join_h_sq.result, 625)

  @! Range Sum Task: sum(1..100) = 5050
  stream_sum = tcp_stream_connect(node2.info.host, node2.info.tcp_port)
  desc_sum = task_descriptor_new(3, "sum_range", [100], node1.info.node_id, 1003)
  protocol_send_tcp(stream_sum.fd, MSG_TASK_SUBMIT(), serialize_task_descriptor(desc_sum))
  swarm_node_step(node2)
  resp_sum = protocol_recv_tcp(stream_sum.fd)
  tcp_stream_close(stream_sum)

  join_h_sum = deserialize_join_handle(resp_sum.payload)
  assert_eq(state, "TC-EXEC-02.2: Remote task sum_range(100) resolved to 5050", join_h_sum.result, 5050)

  @! --------------------------------------------------------------------------
  @! SECTION 5: High-Level swarm_spawn_remote API
  @! --------------------------------------------------------------------------
  println("\n▶ Section 5: High-Level swarm_spawn_remote() API")

  @! Test local fallback execution
  h_local = swarm_spawn(node1, "square_num", 16)
  res_local = swarm_join(h_local)
  assert_eq(state, "TC-API-01.1: Local swarm_spawn square_num(16) == 256", res_local, 256)

  swarm_shutdown(node1)
  swarm_shutdown(node2)

  println("\n=================================================================")
  println("📊 SWARM REMOTE SPAWN SUITE SUMMARY: " + state.passed.to_str() + "/" + state.total.to_str() + " passed")
  println("=================================================================")

  @if state.failed == 0
    println("✓ ALL SWARM REMOTE TASK EXECUTION TESTS PASSED")
    return 0
  @else
    println("✗ SOME SWARM REMOTE TASK EXECUTION TESTS FAILED")
    return 1
  @end
@end
