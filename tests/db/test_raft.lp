@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — DISTRIBUTED RAFT CONSENSUS TEST SUITE
@! File: tests/db/test_raft.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/db/distributed/raft"

@fn assert_true(cond, msg)
  @if cond == 1
    println(str_concat("  [PASS] ", msg))
    return 1
  @else
    println(str_concat("  [FAIL] ", msg))
    return 0
  @end
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual == expected
    println(str_concat("  [PASS] ", msg))
    return 1
  @else
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> expected ", str_concat(to_str(expected), str_concat(", got ", to_str(actual)))))))
    return 0
  @end
@end

@fn assert_eq_str(actual, expected, msg)
  @if str_eq(actual, expected) == 1
    println(str_concat("  [PASS] ", msg))
    return 1
  @else
    println(str_concat("  [FAIL] ", msg))
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🌐 MAYA DISTRIBUTED RAFT CONSENSUS VERIFICATION SUITE 🌐")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! --------------------------------------------------------------------------
  @! SECTION 1: 3-Node Cluster Initialization
  @! --------------------------------------------------------------------------
  println("▶ Section 1: Cluster Node Topology Initialization...")
  n1 = raft_node_new(1)
  n2 = raft_node_new(2)
  n3 = raft_node_new(3)

  total_tests = total_tests + 1
  ok1 = assert_eq_int(n1.node_id, 1, "Node 1 ID initialized")
  ok2 = assert_eq_int(n1.current_term, 0, "Node 1 initial term is 0")
  ok3 = assert_eq_str(n1.state, "FOLLOWER", "Node 1 initial state is FOLLOWER")
  ok4 = assert_eq_int(n1.cluster_size, 3, "Node 1 cluster quorum size is 3")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: Election Timeout & Candidate Transition
  @! --------------------------------------------------------------------------
  println("▶ Section 2: Election Timeout & Candidate Self-Vote...")
  total_tests = total_tests + 1
  n1 = raft_start_election(n1)
  ok1 = assert_eq_int(n1.current_term, 1, "Term incremented to 1 on election timeout")
  ok2 = assert_eq_str(n1.state, "CANDIDATE", "State transitioned to CANDIDATE")
  ok3 = assert_eq_int(n1.voted_for, 1, "Candidate voted for itself")
  ok4 = assert_eq_int(n1.votes_received, 1, "Initial vote count is 1")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: RequestVote RPC & Quorum Leader Election
  @! --------------------------------------------------------------------------
  println("▶ Section 3: RequestVote RPC & Quorum Election...")
  total_tests = total_tests + 1
  @! Node 1 requests vote from Node 2
  vote_from_n2 = raft_request_vote(n2, 1, 1, 0, 0)
  ok1 = assert_eq_int(vote_from_n2, 1, "Node 2 grants vote to Candidate 1")
  n1 = raft_record_vote(n1, vote_from_n2)

  @! Majority of 3 is (3/2)+1 = 2 votes. Node 1 now has 2 votes!
  ok2 = assert_eq_int(n1.votes_received, 2, "Candidate 1 received 2/3 votes")
  ok3 = assert_eq_str(n1.state, "LEADER", "Candidate 1 attained Quorum and elected LEADER")
  ok4 = assert_eq_int(n1.is_leader, 1, "Leader flag set to 1")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 4: Vote Invariants (Stale Term & Duplicate Rejection)...
  @! --------------------------------------------------------------------------
  println("▶ Section 4: Vote Invariants (Stale Term & Duplicate Rejection)...")
  total_tests = total_tests + 1
  @! Node 2 already voted for Node 1 in term 1. Node 3 cannot get Node 2's vote in term 1!
  dup_vote = raft_request_vote(n2, 1, 3, 0, 0)
  ok1 = assert_eq_int(dup_vote, 0, "Node 2 rejects duplicate vote for Node 3 in same term")
  
  @! Node with higher term (term 2) rejects incoming vote request with stale term 1
  stale_node = raft_node_new(4)
  stale_node.current_term = 2
  stale_vote = raft_request_vote(stale_node, 1, 1, 0, 0)
  ok2 = assert_eq_int(stale_vote, 0, "Stale term RPC rejected")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 5: AppendEntries Heartbeat & Log Replication
  @! --------------------------------------------------------------------------
  println("▶ Section 5: AppendEntries Heartbeat & Log Replication...")
  total_tests = total_tests + 1
  e1 = raft_entry_new(1, 1, "SET", "x=100")
  e2 = raft_entry_new(1, 2, "SET", "y=200")
  entries = [e1, e2]

  @! Leader 1 sends AppendEntries to Follower 3
  append_ok = raft_append_entries(n3, 1, 1, entries, 2)
  ok1 = assert_eq_int(append_ok, 1, "Follower 3 accepts AppendEntries from Leader 1")
  ok2 = assert_eq_int(n3.log.len(), 2, "Follower 3 replicated 2 entries")
  ok3 = assert_eq_int(n3.commit_index, 2, "Follower 3 updated commitIndex to 2")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 6: State Machine Application
  @! --------------------------------------------------------------------------
  println("▶ Section 6: Deterministic State Machine Commit Application...")
  total_tests = total_tests + 1
  ok1 = assert_eq_int(n3.last_applied, 0, "Initial last_applied is 0")
  n3 = raft_apply_committed_entries(n3)
  ok2 = assert_eq_int(n3.last_applied, 2, "Committed entries applied to state machine (last_applied == 2)")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
  @end

  println("=================================================================")
  println(str_concat("📊 RAFT CONSENSUS TEST RESULTS: ", str_concat(to_str(passed_tests), str_concat(" / ", str_concat(to_str(total_tests), " sections passed")))))
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 6 DISTRIBUTED RAFT CONSENSUS TESTS PASSED WITH 100% SUCCESS! 🎉")
    return 0
  @else
    println("❌ SOME RAFT TESTS FAILED")
    return 1
  @end
@end
