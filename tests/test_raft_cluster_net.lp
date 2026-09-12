// ==============================================================================
// 🧪 LIPI TEST SUITE: MULTI-NODE DISTRIBUTED RAFT CLUSTER ENGINE
// File: tests/test_raft_cluster_net.lp
// Standard: Ongaro & Ousterhout Raft Consensus Protocol with Socket Transport
// 100% Pure Lipi Implementation — Zero External C / Libc Dependencies
// ==============================================================================

import "universe/db/distributed/raft_cluster_net"
import "universe/core/string"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn assert_str_eq(actual, expected, msg)
  @if str_eq(actual, expected) != 1
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected '", str_concat(expected, str_concat("', got '", str_concat(actual, "'"))))))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ LIPI MULTI-NODE DISTRIBUTED RAFT CLUSTER TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: 3-Node Topology & Strict Quorum Calculation ────────────────
  println("▶ Section 1: 3-Node Topology & Quorum Invariants...")
  total_tests = total_tests + 1

  cluster = raft_net_cluster_new(3)
  ok1 = assert_eq_int(cluster.cluster_size, 3, "Cluster has 3 nodes")
  ok2 = assert_eq_int(cluster.quorum_size, 2, "Strict Quorum Q = floor(3/2)+1 = 2")
  ok3 = assert_eq_int(cluster.nodes.len(), 3, "Node list length is 3")

  if ok1 == 1 && ok2 == 1 && ok3 == 1
    println("  ✔ [PASS] 3-Node cluster topology initialized with Quorum = 2")
    passed_tests = passed_tests + 1
  end

  // ── Section 2: Quorum Leader Election ─────────────────────────────────────
  println("▶ Section 2: Term Progression & Leader Election...")
  total_tests = total_tests + 1

  // Node 1 triggers election
  elect_ok = raft_net_trigger_election(cluster, 1)
  ok_el1 = assert_eq_int(elect_ok, 1, "Node 1 election succeeded with quorum votes")
  
  node1 = cluster.nodes[0]
  ok_el2 = assert_eq_int(node1.state, RAFT_STATE_LEADER(), "Node 1 state is LEADER")
  ok_el3 = assert_eq_int(node1.current_term, 1, "Node 1 term advanced to 1")

  if ok_el1 == 1 && ok_el2 == 1 && ok_el3 == 1
    println("  ✔ [PASS] Leader elected under majority quorum (Votes: " + to_str(node1.votes_granted) + ")")
    passed_tests = passed_tests + 1
  end

  // ── Section 3: Consensus Write & State Machine Commit ─────────────────────
  println("▶ Section 3: Log Replication & State Machine Application...")
  total_tests = total_tests + 1

  write_res = raft_net_client_write(cluster, "cluster_domain", "lipi.mesh")
  ok_w1 = assert_eq_int(write_res, 1, "Client write committed by quorum")
  ok_w2 = assert_eq_int(cluster.committed_writes, 1, "Committed writes counter incremented")
  
  node2 = cluster.nodes[1]
  val_n1 = raft_net_get(node1, "cluster_domain")
  val_n2 = raft_net_get(node2, "cluster_domain")
  ok_w3 = assert_str_eq(val_n1, "lipi.mesh", "Leader KV store updated")
  ok_w4 = assert_str_eq(val_n2, "lipi.mesh", "Replicated peer KV store updated")

  if ok_w1 == 1 && ok_w2 == 1 && ok_w3 == 1 && ok_w4 == 1
    println("  ✔ [PASS] Write replicated and committed to distributed state machines")
    passed_tests = passed_tests + 1
  end

  // ── Section 4: Split-Brain & Partition Defense ────────────────────────────
  println("▶ Section 4: Asymmetric Network Partition & Quorum Re-election...")
  total_tests = total_tests + 1

  // Simulate network split: Isolate Node 1 (cut connection)
  raft_net_partition_isolate(cluster, 1)
  ok_p1 = assert_eq_int(node1.is_isolated, 1, "Node 1 is isolated from cluster")
  ok_p2 = assert_eq_int(node1.state, RAFT_STATE_FOLLOWER(), "Node 1 deposed from leadership")

  // Node 2 triggers election among reachable nodes (Node 2 and Node 3 = 2 votes = Quorum!)
  elect2_ok = raft_net_trigger_election(cluster, 2)
  ok_p3 = assert_eq_int(elect2_ok, 1, "Node 2 elected new leader by majority partition")
  ok_p4 = assert_eq_int(node2.state, RAFT_STATE_LEADER(), "Node 2 state is now LEADER")

  // Write new key to surviving partition
  write_res2 = raft_net_client_write(cluster, "resilience", "bulletproof")
  ok_p5 = assert_eq_int(write_res2, 1, "Partition write successfully committed")

  // Heal partition
  raft_net_partition_heal(cluster, 1)
  ok_p6 = assert_eq_int(node1.is_isolated, 0, "Node 1 network link restored")

  if ok_p1 == 1 && ok_p2 == 1 && ok_p3 == 1 && ok_p4 == 1 && ok_p5 == 1 && ok_p6 == 1
    println("  ✔ [PASS] Split-brain prevented & quorum failover verified")
    passed_tests = passed_tests + 1
  end

  println("=================================================================")
  if passed_tests == total_tests
    println("🎉 ALL MULTI-NODE RAFT CLUSTER TESTS PASSED (4/4) ✔")
    return 0
  else
    println("❌ SOME RAFT CLUSTER TESTS FAILED!")
    return 1
  end
@end

main()
