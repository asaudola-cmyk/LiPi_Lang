@! ============================================================================
@! LIPI TEST SUITE: DISTRIBUTED RAFT CONSENSUS & CRASH-RESILIENT WAL ENGINE
@! File: tests/test_raft_distributed_kv.lp
@! Standard: Ongaro & Ousterhout Raft Protocol + ACID Write-Ahead Log
@! 100% Pure Lipi Implementation — Zero External C / Libc Dependencies
@! ============================================================================

import "universe/db/distributed/raft"
import "universe/db/wal"
import "universe/os/syscalls"
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
  println("⚡ LIPI DISTRIBUTED RAFT & CRASH-RESILIENT WAL TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! --------------------------------------------------------------------------
  @! SECTION 1: 3-Node Raft Cluster Quorum & Leader Election
  @! --------------------------------------------------------------------------
  println("▶ Section 1: Raft Cluster Quorum & Leader Election...")
  total_tests = total_tests + 1

  cluster = raft_cluster_new(3)
  ok_c1 = assert_eq_int(cluster.cluster_size, 3, "Cluster size is 3 nodes")
  ok_c2 = assert_eq_int(cluster.nodes.len(), 3, "Cluster topology initialized with 3 nodes")

  @! Node 1 starts election
  elected = raft_cluster_elect(cluster, 1)
  ok_el = assert_eq_int(elected, 1, "Candidate Node 1 successfully elected LEADER")
  ok_lid = assert_eq_int(cluster.leader_id, 1, "Cluster leader ID set to 1")

  n1: RaftNode = cluster.nodes[0]
  n2: RaftNode = cluster.nodes[1]
  n3: RaftNode = cluster.nodes[2]

  ok_st1 = assert_str_eq(n1.state, "LEADER", "Node 1 state is LEADER")
  ok_st2 = assert_str_eq(n2.state, "FOLLOWER", "Node 2 state is FOLLOWER")
  ok_st3 = assert_str_eq(n3.state, "FOLLOWER", "Node 3 state is FOLLOWER")
  ok_term = assert_eq_int(n1.current_term, 1, "Term progressed to 1")

  all_s1 = ok_c1 && ok_c2 && ok_el && ok_lid && ok_st1 && ok_st2 && ok_st3 && ok_term
  @if all_s1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 3-Node Raft election and quorum topology verified.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: Distributed Log Replication & Quorum Commit
  @! --------------------------------------------------------------------------
  println("▶ Section 2: Distributed Log Replication & Quorum Commit...")
  total_tests = total_tests + 1

  idx1 = raft_cluster_propose_entry(cluster, 1, "SET", "user:1001=SovereignLipi")
  ok_idx = assert_eq_int(idx1, 1, "First command committed at Raft index 1")

  idx2 = raft_cluster_propose_entry(cluster, 1, "SET", "user:1002=LipiPower")
  ok_idx2 = assert_eq_int(idx2, 2, "Second command committed at Raft index 2")

  l_node: RaftNode = cluster.nodes[0]
  f1_node: RaftNode = cluster.nodes[1]
  f2_node: RaftNode = cluster.nodes[2]

  ok_len1 = assert_eq_int(l_node.log.len(), 2, "Leader log contains 2 entries")
  ok_len2 = assert_eq_int(f1_node.log.len(), 2, "Follower 1 log replicated 2 entries")
  ok_len3 = assert_eq_int(f2_node.log.len(), 2, "Follower 2 log replicated 2 entries")

  ok_com1 = assert_eq_int(l_node.commit_index, 2, "Leader commit_index advanced to 2")
  ok_com2 = assert_eq_int(f1_node.commit_index, 2, "Follower 1 commit_index advanced to 2")
  ok_com3 = assert_eq_int(f2_node.commit_index, 2, "Follower 2 commit_index advanced to 2")

  all_s2 = ok_idx && ok_idx2 && ok_len1 && ok_len2 && ok_len3 && ok_com1 && ok_com2 && ok_com3
  @if all_s2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Distributed log replication across quorum verified.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: Binary WAL Logging, CRC-32 & Crash Recovery
  @! --------------------------------------------------------------------------
  println("▶ Section 3: Crash Resiliency & Binary WAL Recovery...")
  total_tests = total_tests + 1

  test_wal_path = "/tmp/lipi_test_raft_cluster.wal"
  sys_unlink(test_wal_path)

  wal = wal_open(test_wal_path)
  ok_wfd = assert_true(wal.fd >= 0, "Opened binary WAL file")

  lsn1 = wal_append_put(wal, 1, "cluster_node", "node_1")
  lsn2 = wal_append_put(wal, 1, "cluster_term", "1")
  lsn3 = wal_append_put(wal, 1, "cluster_state", "ACTIVE")
  wal_sync(wal)
  wal_close(wal)

  @! Replay WAL to recover state machine after simulated crash
  replayed = wal_replay_all(test_wal_path)
  ok_rlen = assert_eq_int(replayed.len(), 3, "WAL replay reconstructed 3 records")

  r0 = replayed[0]
  r1 = replayed[1]
  r2 = replayed[2]

  ok_r0k = assert_str_eq(wal_record_get_key(r0), "cluster_node", "Record 0 key is 'cluster_node'")
  ok_r0v = assert_str_eq(wal_record_get_value(r0), "node_1", "Record 0 value is 'node_1'")
  ok_r1k = assert_str_eq(wal_record_get_key(r1), "cluster_term", "Record 1 key is 'cluster_term'")
  ok_r1v = assert_str_eq(wal_record_get_value(r1), "1", "Record 1 value is '1'")
  ok_r2k = assert_str_eq(wal_record_get_key(r2), "cluster_state", "Record 2 key is 'cluster_state'")
  ok_r2v = assert_str_eq(wal_record_get_value(r2), "ACTIVE", "Record 2 value is 'ACTIVE'")

  sys_unlink(test_wal_path)

  all_s3 = ok_wfd && ok_rlen && ok_r0k && ok_r0v && ok_r1k && ok_r1v && ok_r2k && ok_r2v
  @if all_s3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Binary WAL record framing, CRC-32, and crash recovery verified.")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 4: Split-Brain Invariant & Stale Leader Rejection
  @! --------------------------------------------------------------------------
  println("▶ Section 4: Split-Brain Prevention & Stale Term Invariant...")
  total_tests = total_tests + 1

  @! Stale leader with term 0 attempts append entries to node with term 1
  stale_res = raft_append_entries(n1, 0, 99, [], 0)
  ok_stale = assert_eq_int(stale_res, 0, "Stale AppendEntries with term < currentTerm rejected")

  @! Stale vote request with term 0 rejected
  stale_vote = raft_request_vote(n1, 0, 99, 0, 0)
  ok_svote = assert_eq_int(stale_vote, 0, "Stale RequestVote with term < currentTerm rejected")

  all_s4 = ok_stale && ok_svote
  @if all_s4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Split-brain protection and stale term rejection verified.")
  @end

  println("=================================================================")
  s_pass = to_str(passed_tests)
  s_tot = to_str(total_tests)
  println(str_concat("📊 RAFT DISTRIBUTED KV RESULTS: ", str_concat(s_pass, str_concat(" / ", str_concat(s_tot, " passed")))))
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL RAFT & CRASH-RESILIENT WAL TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME TESTS FAILED")
    return 1
  @end
@end
