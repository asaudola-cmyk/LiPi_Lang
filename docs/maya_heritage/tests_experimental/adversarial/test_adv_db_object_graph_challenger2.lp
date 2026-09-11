@! ============================================================================
@! ADVERSARIAL CHALLENGE SUITE: MAYA NATIVE OBJECT-GRAPH DATABASE ENGINE
@! Challenger: Challenger 2 (Milestone 1)
@! Target: universe/db/object_graph.maya
@! Stress Dimensions:
@!   1. Raft Consensus Edge Cases & Distributed Faults
@!   2. Transaction Atomicity, Isolation & Rollback Invariants
@!   3. Snapshot Corruption Resilience & Round-Trip Fidelity
@!   4. Property Index Synchronization under Rapid Interleaved Mutations
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/db/object_graph"

@struct AdvTracker
  total: i64
  passed: i64
  failed: i64
@end

@fn tracker_new() -> AdvTracker
  return { total: 0, passed: 0, failed: 0 }
@end

@fn ch_assert_eq(t: AdvTracker, actual: i64, expected: i64, name: string) -> bool
  t.total = t.total + 1
  @if actual == expected
    println("  [PASS] " + name)
    t.passed = t.passed + 1
    return true
  @else
    println("  [FAIL] " + name + " - Expected: " + int_to_str(expected) + ", Got: " + int_to_str(actual))
    t.failed = t.failed + 1
    return false
  @end
@end

@fn ch_assert_str_eq(t: AdvTracker, actual: string, expected: string, name: string) -> bool
  t.total = t.total + 1
  @if actual == expected
    println("  [PASS] " + name)
    t.passed = t.passed + 1
    return true
  @else
    println("  [FAIL] " + name + " - Expected: '" + expected + "', Got: '" + actual + "'")
    t.failed = t.failed + 1
    return false
  @end
@end

@fn ch_assert_true(t: AdvTracker, cond: bool, name: string) -> bool
  t.total = t.total + 1
  @if cond
    println("  [PASS] " + name)
    t.passed = t.passed + 1
    return true
  @else
    println("  [FAIL] " + name + " - Condition was false, expected true")
    t.failed = t.failed + 1
    return false
  @end
@end

@fn ch_assert_false(t: AdvTracker, cond: bool, name: string) -> bool
  return ch_assert_true(t, !cond, name)
@end

@! ============================================================================
@! CATEGORY 1: Raft Consensus Edge Cases & Distributed Faults
@! ============================================================================

@fn challenge_raft_stale_terms_and_step_up(t: AdvTracker)
  println("\n--- [Challenge A.1] Raft Stale Terms & Term Step-Up ---")
  let node = raft_node_new("n1", ["c1", "c2"])
  node.term = 5
  node.state = "LEADER"
  node.voted_for = "n1"

  @! Candidate with term 4 (stale) requests vote -> must reject
  let vote1 = raft_request_vote(node, 4, "c1", 0, 0)
  ch_assert_eq(t, vote1, 0, "A.1.1: Stale term RequestVote rejected")
  ch_assert_eq(t, node.term, 5, "A.1.1: Term unchanged on stale request")
  ch_assert_str_eq(t, node.state, "LEADER", "A.1.1: State remains LEADER")

  @! Candidate with term 6 (higher) requests vote -> node must step down to FOLLOWER and grant vote
  let vote2 = raft_request_vote(node, 6, "c2", 0, 0)
  ch_assert_eq(t, vote2, 1, "A.1.2: Higher term RequestVote granted")
  ch_assert_eq(t, node.term, 6, "A.1.2: Node term stepped up to 6")
  ch_assert_str_eq(t, node.state, "FOLLOWER", "A.1.2: Node stepped down to FOLLOWER")
  ch_assert_str_eq(t, node.voted_for, "c2", "A.1.2: Voted_for recorded c2")

  @! Another candidate in term 6 requests vote -> must reject (already voted for c2)
  let vote3 = raft_request_vote(node, 6, "c1", 0, 0)
  ch_assert_eq(t, vote3, 0, "A.1.3: Second vote in same term rejected")
@end

@fn challenge_raft_log_conflict_deep_truncation(t: AdvTracker)
  println("\n--- [Challenge A.2] Raft Deep Log Conflict Overwrite & Truncation ---")
  let follower = raft_node_new("f1", ["leader"])
  follower.term = 2
  @! Follower has 5 entries from term 1 and term 2
  follower.log.push({ term: 1, index: 1, command_type: "ADD_NODE", payload: "n1:Node" })
  follower.log.push({ term: 1, index: 2, command_type: "ADD_NODE", payload: "n2:Node" })
  follower.log.push({ term: 2, index: 3, command_type: "ADD_NODE", payload: "stale3:Bad" })
  follower.log.push({ term: 2, index: 4, command_type: "ADD_NODE", payload: "stale4:Bad" })
  follower.log.push({ term: 2, index: 5, command_type: "ADD_NODE", payload: "stale5:Bad" })

  @! New Leader at Term 3 sends entries starting at index 3 (prev_log_index=2, prev_log_term=1)
  let leader_entries = [
    { term: 3, index: 3, command_type: "ADD_NODE", payload: "auth3:Good" },
    { term: 3, index: 4, command_type: "ADD_NODE", payload: "auth4:Good" }
  ]

  let ok = raft_append_entries(follower, 3, "leader", 2, 1, leader_entries, 4)
  ch_assert_eq(t, ok, 1, "A.2.1: Leader successfully appends overwriting entries")
  ch_assert_eq(t, follower.log.len(), 4, "A.2.1: Log length truncated from 5 to 4")
  ch_assert_eq(t, follower.commit_index, 4, "A.2.1: Commit index advanced to 4")

  let e3: RaftLogEntry = follower.log[2]
  let e4: RaftLogEntry = follower.log[3]
  ch_assert_str_eq(t, e3.payload, "auth3:Good", "A.2.2: Log index 3 overwritten with authoritative entry")
  ch_assert_str_eq(t, e4.payload, "auth4:Good", "A.2.2: Log index 4 overwritten with authoritative entry")
  ch_assert_eq(t, e3.term, 3, "A.2.2: Overwritten entry has term 3")
@end

@fn challenge_raft_mismatched_prefix_rejections(t: AdvTracker)
  println("\n--- [Challenge A.3] Raft Out-of-Order & Mismatched Prefix Rejections ---")
  let follower = raft_node_new("f1", ["leader"])
  follower.term = 2
  follower.log.push({ term: 1, index: 1, command_type: "ADD_NODE", payload: "n1:Node" })
  follower.log.push({ term: 2, index: 2, command_type: "ADD_NODE", payload: "n2:Node" })

  @! Case 1: prev_log_index beyond follower log len (gap)
  let entries_gap = [{ term: 2, index: 5, command_type: "ADD_NODE", payload: "n5:Node" }]
  let res_gap = raft_append_entries(follower, 2, "leader", 4, 2, entries_gap, 2)
  ch_assert_eq(t, res_gap, 0, "A.3.1: Gapped prev_log_index rejected")

  @! Case 2: prev_log_index matches length but prev_log_term doesn't match
  let entries_term_mismatch = [{ term: 3, index: 3, command_type: "ADD_NODE", payload: "n3:Node" }]
  let res_mismatch = raft_append_entries(follower, 2, "leader", 2, 99, entries_term_mismatch, 2)
  ch_assert_eq(t, res_mismatch, 0, "A.3.2: Mismatched prev_log_term rejected")

  @! Case 3: Stale term leader
  let res_stale_leader = raft_append_entries(follower, 1, "old_leader", 2, 2, entries_term_mismatch, 2)
  ch_assert_eq(t, res_stale_leader, 0, "A.3.3: AppendEntries from stale term rejected")
@end

@fn challenge_raft_uncommitted_vs_committed_isolation(t: AdvTracker)
  println("\n--- [Challenge A.4] Raft State Machine Commit Boundary Isolation ---")
  let engine = og_engine_new()
  let node = raft_node_new("n1", [])
  node.term = 1
  node.log.push({ term: 1, index: 1, command_type: "ADD_NODE", payload: "c1:Committed" })
  node.log.push({ term: 1, index: 2, command_type: "ADD_NODE", payload: "c2:Committed" })
  node.log.push({ term: 1, index: 3, command_type: "ADD_NODE", payload: "u3:Uncommitted" })
  node.log.push({ term: 1, index: 4, command_type: "ADD_NODE", payload: "u4:Uncommitted" })

  @! Commit index is only 2
  node.commit_index = 2

  let applied1 = raft_apply_to_graph(node, engine)
  ch_assert_eq(t, applied1, 2, "A.4.1: Exactly 2 committed entries applied")
  ch_assert_eq(t, engine.node_count, 2, "A.4.1: State machine node count is 2")
  ch_assert_true(t, og_node_is_valid(og_get_node(engine, "c1")), "A.4.1: c1 exists in engine")
  ch_assert_true(t, og_node_is_valid(og_get_node(engine, "c2")), "A.4.1: c2 exists in engine")
  ch_assert_false(t, og_node_is_valid(og_get_node(engine, "u3")), "A.4.1: Uncommitted u3 NOT in engine")
  ch_assert_false(t, og_node_is_valid(og_get_node(engine, "u4")), "A.4.1: Uncommitted u4 NOT in engine")

  @! Idempotent call: no new commits -> 0 applied
  let applied_noop = raft_apply_to_graph(node, engine)
  ch_assert_eq(t, applied_noop, 0, "A.4.2: Idempotent apply returns 0")

  @! Advance commit index to 4
  node.commit_index = 4
  let applied2 = raft_apply_to_graph(node, engine)
  ch_assert_eq(t, applied2, 2, "A.4.3: Remaining 2 entries now applied")
  ch_assert_eq(t, engine.node_count, 4, "A.4.3: State machine now has 4 nodes")
  ch_assert_true(t, og_node_is_valid(og_get_node(engine, "u3")), "A.4.3: u3 now exists in engine")
  ch_assert_true(t, og_node_is_valid(og_get_node(engine, "u4")), "A.4.3: u4 now exists in engine")
@end

@fn challenge_raft_cluster_partition_heal_reconciliation(t: AdvTracker)
  println("\n--- [Challenge A.5] Raft Partition, Re-election & State Convergence ---")
  let eng_a = og_engine_new()
  let eng_b = og_engine_new()
  let eng_c = og_engine_new()

  let node_a = raft_node_new("node_a", ["node_b", "node_c"])
  let node_b = raft_node_new("node_b", ["node_a", "node_c"])
  let node_c = raft_node_new("node_c", ["node_a", "node_b"])

  @! Initial state: node_a elected leader at term 1
  raft_elect_leader(node_a)
  raft_replicate_command(node_a, "ADD_NODE", "init1:Node")
  raft_append_entries(node_b, node_a.term, node_a.node_id, 0, 0, node_a.log, node_a.commit_index)
  raft_append_entries(node_c, node_a.term, node_a.node_id, 0, 0, node_a.log, node_a.commit_index)

  raft_apply_to_graph(node_a, eng_a)
  raft_apply_to_graph(node_b, eng_b)
  raft_apply_to_graph(node_c, eng_c)

  @! Partition occurs: node_a is partitioned away.
  @! Minority partition: node_a writes an uncommitted command
  raft_replicate_command(node_a, "ADD_NODE", "stale_minority:Node")

  @! Majority partition: node_b starts election for term 2 and is granted vote by node_c
  node_b.term = 2
  node_b.state = "CANDIDATE"
  node_b.voted_for = "node_b"
  let vote_c = raft_request_vote(node_c, 2, "node_b", node_c.log.len(), 1)
  ch_assert_eq(t, vote_c, 1, "A.5.1: Node C votes for Node B at term 2")
  node_b.state = "LEADER"

  @! Node B replicates 2 new commands to Node C
  raft_replicate_command(node_b, "ADD_NODE", "auth2:Node")
  raft_replicate_command(node_b, "ADD_EDGE", "e12:init1:auth2:LINK:5")
  raft_append_entries(node_c, node_b.term, node_b.node_id, 1, 1, [node_b.log[1], node_b.log[2]], node_b.commit_index)

  raft_apply_to_graph(node_b, eng_b)
  raft_apply_to_graph(node_c, eng_c)

  ch_assert_eq(t, eng_b.node_count, 2, "A.5.2: Majority node B has 2 nodes")
  ch_assert_eq(t, eng_c.node_count, 2, "A.5.2: Majority node C has 2 nodes")
  ch_assert_eq(t, eng_b.edge_count, 1, "A.5.2: Majority node B has 1 edge")

  @! Partition heals: Node B replicates term 2 entries to Node A, overwriting stale uncommitted entry
  let heal_ok = raft_append_entries(node_a, node_b.term, node_b.node_id, 1, 1, [node_b.log[1], node_b.log[2]], node_b.commit_index)
  ch_assert_eq(t, heal_ok, 1, "A.5.3: Partition healed, Node A accepts Node B's log")
  ch_assert_eq(t, node_a.log.len(), 3, "A.5.3: Node A log length reconciled to 3")
  ch_assert_str_eq(t, node_a.state, "FOLLOWER", "A.5.3: Node A stepped down to FOLLOWER")

  @! Reset engine A from snapshot of term 1 baseline or apply authoritative state
  let eng_a_reconstructed = og_engine_new()
  node_a.last_applied = 0
  raft_apply_to_graph(node_a, eng_a_reconstructed)

  ch_assert_eq(t, eng_a_reconstructed.node_count, 2, "A.5.4: Node A state machine converged to 2 nodes")
  ch_assert_eq(t, eng_a_reconstructed.edge_count, 1, "A.5.4: Node A state machine converged to 1 edge")
  ch_assert_false(t, og_node_is_valid(og_get_node(eng_a_reconstructed, "stale_minority")), "A.5.4: Stale minority node eliminated")
@end

@! ============================================================================
@! CATEGORY 2: Transaction Atomicity, Isolation & Rollback Invariants
@! ============================================================================

@fn challenge_tx_nested_rejection(t: AdvTracker)
  println("\n--- [Challenge B.1] Transaction Nested / Concurrent Start Rejection ---")
  let engine = og_engine_new()
  let tx1 = og_begin_tx(engine)
  ch_assert_str_eq(t, tx1.state, "ACTIVE", "B.1.1: First transaction successfully activated")
  ch_assert_true(t, engine.in_tx, "B.1.1: Engine in_tx flag is true")

  let tx2 = og_begin_tx(engine)
  ch_assert_str_eq(t, tx2.state, "ABORTED", "B.1.2: Nested transaction attempt returns ABORTED handle")
  ch_assert_eq(t, tx2.tx_id, 0, "B.1.2: Nested transaction tx_id is 0")

  og_commit_transaction(tx1)
  ch_assert_false(t, engine.in_tx, "B.1.3: Engine in_tx false after commit")
@end

@fn challenge_tx_heavy_mutation_rollback(t: AdvTracker)
  println("\n--- [Challenge B.2] Heavy Multi-Entity Transaction Full Rollback ---")
  let engine = og_engine_new()

  @! Baseline graph: 3 nodes, 2 edges, properties
  og_add_node(engine, "base_1", "Base")
  og_add_node(engine, "base_2", "Base")
  og_add_node(engine, "base_3", "Base")
  og_set_node_prop(engine, "base_1", "env", "prod", 0, false)
  og_set_node_prop(engine, "base_1", "port", "", 8080, true)
  og_add_edge(engine, "e_b1", "base_1", "base_2", "CONNECTS", 10)
  og_add_edge_undirected(engine, "e_b2", "base_2", "base_3", "PEER", 5)

  let snap_before = og_export_snapshot(engine)

  @! Begin transaction
  let tx = og_begin_tx(engine)

  @! Heavy mutations: add 5 new nodes, add 6 edges, delete base_2, modify base_1 properties
  let k = 1
  @while k <= 5
    let new_id = "tx_node_" + int_to_str(k)
    og_add_node(engine, new_id, "Staged")
    og_set_node_prop(engine, new_id, "idx", "", k, true)
    og_add_edge(engine, "tx_edge_" + int_to_str(k), "base_1", new_id, "CHILD", k)
    k = k + 1
  @end

  og_delete_node(engine, "base_2")
  og_set_node_prop(engine, "base_1", "env", "mutated_tx", 0, false)

  ch_assert_eq(t, engine.node_count, 7, "B.2.1: Node count during transaction is 7")
  ch_assert_false(t, og_node_is_valid(og_get_node(engine, "base_2")), "B.2.1: base_2 deleted inside tx")

  @! Rollback
  let rb = og_rollback_tx(engine)
  ch_assert_true(t, rb, "B.2.2: Rollback returned true")
  ch_assert_false(t, engine.in_tx, "B.2.2: Engine exited tx state")

  @! Invariant verification
  ch_assert_eq(t, engine.node_count, 3, "B.2.3: Restored node count is 3")
  ch_assert_eq(t, engine.edge_count, 2, "B.2.3: Restored edge count is 2")
  ch_assert_true(t, og_node_is_valid(og_get_node(engine, "base_2")), "B.2.3: base_2 restored")
  ch_assert_true(t, og_edge_is_valid(og_get_edge(engine, "e_b1")), "B.2.3: e_b1 edge restored")
  ch_assert_true(t, og_edge_is_valid(og_get_edge(engine, "e_b2")), "B.2.3: e_b2 edge restored")

  let env_val = og_get_node_prop_str(engine, "base_1", "env")
  let port_val = og_get_node_prop_num(engine, "base_1", "port")
  ch_assert_str_eq(t, env_val, "prod", "B.2.4: Property 'env' restored to 'prod'")
  ch_assert_eq(t, port_val, 8080, "B.2.4: Property 'port' restored to 8080")

  let staged_lookup = og_find_nodes_by_label(engine, "Staged")
  ch_assert_eq(t, staged_lookup.len(), 0, "B.2.5: Staged label index completely clean")

  let snap_after = og_export_snapshot(engine)
  ch_assert_str_eq(t, snap_after, snap_before, "B.2.6: Snapshot string exactly identical after rollback")
@end

@fn challenge_tx_sequential_chains(t: AdvTracker)
  println("\n--- [Challenge B.3] Sequential Transactions (Commit -> Abort -> Commit) ---")
  let engine = og_engine_new()
  og_add_node(engine, "root", "System")

  @! Tx 1: Commit node A
  let tx1 = og_begin_tx(engine)
  og_add_node(engine, "node_A", "App")
  og_commit_transaction(tx1)
  ch_assert_eq(t, engine.node_count, 2, "B.3.1: Tx 1 committed, node count is 2")

  @! Tx 2: Abort node B
  let tx2 = og_begin_tx(engine)
  og_add_node(engine, "node_B", "App")
  og_rollback_transaction(tx2)
  ch_assert_eq(t, engine.node_count, 2, "B.3.2: Tx 2 aborted, node count remains 2")
  ch_assert_false(t, og_node_is_valid(og_get_node(engine, "node_B")), "B.3.2: node_B is absent")

  @! Tx 3: Commit node C
  let tx3 = og_begin_tx(engine)
  og_add_node(engine, "node_C", "App")
  og_commit_transaction(tx3)
  ch_assert_eq(t, engine.node_count, 3, "B.3.3: Tx 3 committed, node count is 3")
  ch_assert_true(t, og_node_is_valid(og_get_node(engine, "node_A")), "B.3.3: node_A present")
  ch_assert_true(t, og_node_is_valid(og_get_node(engine, "node_C")), "B.3.3: node_C present")
@end

@! ============================================================================
@! CATEGORY 3: Snapshot Corruption Resilience & Round-Trip Fidelity
@! ============================================================================

@fn challenge_snapshot_corruption_resilience(t: AdvTracker)
  println("\n--- [Challenge C.1] Malformed & Corrupted Snapshot Resilience ---")
  
  @! 1. Empty string
  let e1 = og_import_snapshot("")
  ch_assert_eq(t, e1.node_count, 0, "C.1.1: Empty snapshot string returns empty engine")

  @! 2. Truncated header without pipes
  let e2 = og_import_snapshot("CORRUPTED_DATA_WITHOUT_PIPES")
  ch_assert_eq(t, e2.node_count, 0, "C.1.2: Header without pipes returns empty engine")

  @! 3. Missing edges section
  let e3 = og_import_snapshot("OG_SNAPSHOT_V1|NODES:n1,Node")
  ch_assert_eq(t, e3.node_count, 0, "C.1.3: Insufficient sections returns empty engine")

  @! 4. Malformed node records (missing label, corrupt properties)
  let e4 = og_import_snapshot("OG_SNAPSHOT_V1|NODES:only_one_field;valid_n,ValidLabel|EDGES:")
  ch_assert_eq(t, e4.node_count, 1, "C.1.4: Skips malformed node record, imports valid one")
  ch_assert_true(t, og_node_is_valid(og_get_node(e4, "valid_n")), "C.1.4: valid_n imported successfully")

  @! 5. Malformed edge records (missing fields)
  let e5 = og_import_snapshot("OG_SNAPSHOT_V1|NODES:n1,N;n2,N|EDGES:bad_edge,n1,n2;valid_e,n1,n2,LINK,10,1")
  ch_assert_eq(t, e5.node_count, 2, "C.1.5: Nodes imported")
  ch_assert_eq(t, e5.edge_count, 1, "C.1.5: Skips malformed edge record, imports valid edge")
  ch_assert_true(t, og_edge_is_valid(og_get_edge(e5, "valid_e")), "C.1.5: valid_e imported successfully")
@end

@fn challenge_snapshot_dense_graph_roundtrip(t: AdvTracker)
  println("\n--- [Challenge C.2] High-Density Graph Snapshot Round-Trip ---")
  let engine = og_engine_new()

  @! Build 20 nodes with mixed properties
  let i = 0
  @while i < 20
    let nid = "node_" + int_to_str(i)
    let label = "ClusterA"
    @if i >= 10
      label = "ClusterB"
    @end
    og_add_node(engine, nid, label)
    og_set_node_prop(engine, nid, "score", "", i * 10, true)
    og_set_node_prop(engine, nid, "name", "Item_" + int_to_str(i), 0, false)
    i = i + 1
  @end

  @! Build 30 edges (directed and undirected)
  let j = 0
  @while j < 19
    let eid = "edge_" + int_to_str(j)
    let src = "node_" + int_to_str(j)
    let tgt = "node_" + int_to_str(j + 1)
    @if j % 2 == 0
      og_add_edge(engine, eid, src, tgt, "DIR_LINK", j + 1)
    @else
      og_add_edge_undirected(engine, eid, src, tgt, "UNDIR_LINK", j + 1)
    @end
    og_set_edge_prop(engine, eid, "latency", "", (j + 1) * 2, true)
    j = j + 1
  @end

  let snap_str = og_export_snapshot(engine)
  let imported = og_import_snapshot(snap_str)

  ch_assert_eq(t, imported.node_count, 20, "C.2.1: Imported node count is 20")
  ch_assert_eq(t, imported.edge_count, 19, "C.2.1: Imported edge count is 19")

  @! Verify label queries on imported graph
  let cluster_a = og_find_nodes_by_label(imported, "ClusterA")
  let cluster_b = og_find_nodes_by_label(imported, "ClusterB")
  ch_assert_eq(t, cluster_a.len(), 10, "C.2.2: ClusterA label count is 10")
  ch_assert_eq(t, cluster_b.len(), 10, "C.2.2: ClusterB label count is 10")

  @! Verify property lookups
  let score_100_nodes = og_find_nodes_by_prop_num(imported, "score", 100)
  ch_assert_eq(t, score_100_nodes.len(), 1, "C.2.3: Node with score 100 found")
  ch_assert_str_eq(t, score_100_nodes[0], "node_10", "C.2.3: score 100 matches node_10")

  @! Verify graph traversal on imported engine
  let path = og_dijkstra_shortest_path(imported, "node_0", "node_5")
  ch_assert_eq(t, path.len(), 6, "C.2.4: Shortest path across 6 hops verified on imported engine")
  ch_assert_str_eq(t, path[0], "node_0", "C.2.4: Path start node_0")
  ch_assert_str_eq(t, path[5], "node_5", "C.2.4: Path target node_5")
@end

@! ============================================================================
@! CATEGORY 4: Property Index Synchronization under Rapid Interleaved Mutations
@! ============================================================================

@fn challenge_property_index_type_flip_stress(t: AdvTracker)
  println("\n--- [Challenge D.1] Rapid Property Type-Flip Stress ---")
  let engine = og_engine_new()
  og_add_node(engine, "item_1", "Item")

  @! Alternate 10 times between string and numeric property on the same key "state"
  let iter = 0
  @while iter < 10
    @! Set to string
    og_set_node_prop(engine, "item_1", "state", "ACTIVE_" + int_to_str(iter), 0, false)
    let s_res = og_find_nodes_by_prop_str(engine, "state", "ACTIVE_" + int_to_str(iter))
    let n_stale = og_find_nodes_by_prop_num(engine, "state", iter)
    ch_assert_eq(t, s_res.len(), 1, "D.1: String index active at iter " + int_to_str(iter))
    ch_assert_eq(t, n_stale.len(), 0, "D.1: Num index empty at iter " + int_to_str(iter))

    @! Flip to number
    og_set_node_prop(engine, "item_1", "state", "", iter + 100, true)
    let n_res = og_find_nodes_by_prop_num(engine, "state", iter + 100)
    let s_stale = og_find_nodes_by_prop_str(engine, "state", "ACTIVE_" + int_to_str(iter))
    ch_assert_eq(t, n_res.len(), 1, "D.1: Num index active at iter " + int_to_str(iter))
    ch_assert_eq(t, s_stale.len(), 0, "D.1: String index pruned at iter " + int_to_str(iter))

    iter = iter + 1
  @end
@end

@fn challenge_property_index_shared_pruning_and_cascades(t: AdvTracker)
  println("\n--- [Challenge D.2] Shared Property Index Buckets & Cascade Pruning ---")
  let engine = og_engine_new()

  @! Create 10 nodes with same label and property "role = worker"
  let i = 0
  @while i < 10
    let nid = "w_" + int_to_str(i)
    og_add_node(engine, nid, "Worker")
    og_set_node_prop(engine, nid, "role", "worker", 0, false)
    i = i + 1
  @end

  let initial_workers = og_find_nodes_by_prop_str(engine, "role", "worker")
  ch_assert_eq(t, initial_workers.len(), 10, "D.2.1: 10 nodes sharing role=worker")

  @! Promote w_0, w_1, w_2 to "manager"
  og_set_node_prop(engine, "w_0", "role", "manager", 0, false)
  og_set_node_prop(engine, "w_1", "role", "manager", 0, false)
  og_set_node_prop(engine, "w_2", "role", "manager", 0, false)

  let workers_after_promote = og_find_nodes_by_prop_str(engine, "role", "worker")
  let managers = og_find_nodes_by_prop_str(engine, "role", "manager")
  ch_assert_eq(t, workers_after_promote.len(), 7, "D.2.2: Remaining worker bucket has 7 nodes")
  ch_assert_eq(t, managers.len(), 3, "D.2.2: Manager bucket has 3 nodes")

  @! Delete w_3 and w_4
  og_delete_node(engine, "w_3")
  og_delete_node(engine, "w_4")

  let workers_after_del = og_find_nodes_by_prop_str(engine, "role", "worker")
  ch_assert_eq(t, workers_after_del.len(), 5, "D.2.3: Deletion cascaded property index pruning to 5 nodes")
  ch_assert_eq(t, array_contains_str(workers_after_del, "w_3"), 0, "D.2.3: Deleted w_3 absent from index")
  ch_assert_eq(t, array_contains_str(workers_after_del, "w_4"), 0, "D.2.3: Deleted w_4 absent from index")

  @! Also verify label index pruning
  let all_workers_label = og_find_nodes_by_label(engine, "Worker")
  ch_assert_eq(t, all_workers_label.len(), 8, "D.2.4: Label index pruned to 8 active nodes (10 - 2 deleted)")
@end

@fn challenge_rapid_interleaved_fuzz_loop(t: AdvTracker)
  println("\n--- [Challenge D.3] Deterministic Interleaved Mutation Fuzz Loop (50 ops) ---")
  let engine = og_engine_new()

  @! Create 10 vertices
  let v = 0
  @while v < 10
    og_add_node(engine, "v" + int_to_str(v), "Vertex")
    v = v + 1
  @end

  @! Deterministic interleaved loop: add edges, set props, mutate props, delete edges
  let op = 0
  @while op < 50
    let src_idx = op % 10
    let tgt_idx = (op + 3) % 10
    let src_id = "v" + int_to_str(src_idx)
    let tgt_id = "v" + int_to_str(tgt_idx)

    @if src_idx != tgt_idx
      let edge_id = "e_" + int_to_str(op)
      og_add_edge(engine, edge_id, src_id, tgt_id, "STEP", op)
      og_set_edge_prop(engine, edge_id, "step_val", "", op, true)
    @end

    let prop_val = "val_" + int_to_str(op % 5)
    og_set_node_prop(engine, src_id, "color", prop_val, 0, false)

    op = op + 1
  @end

  ch_assert_eq(t, engine.node_count, 10, "D.3.1: Node count invariant holds")
  ch_assert_true(t, engine.edge_count > 30, "D.3.1: Edge count populated")

  @! Verify that property color lookups return nodes correctly
  let color0 = og_find_nodes_by_prop_str(engine, "color", "val_0")
  let color4 = og_find_nodes_by_prop_str(engine, "color", "val_4")
  ch_assert_true(t, color0.len() > 0 || color4.len() > 0, "D.3.2: Property index populated and queryable")

  @! Verify BFS runs without getting stuck in infinite loops on dense cyclic topology
  let bfs_result = og_bfs_traverse(engine, "v0")
  ch_assert_true(t, bfs_result.len() <= 10, "D.3.3: BFS terminates cleanly on dense cyclic graph")
@end

@! ============================================================================
@! Main Adversarial Runner
@! ============================================================================

@fn main()
  println("=================================================================")
  println("⚔️  ADVERSARIAL CHALLENGER 2: OBJECT-GRAPH & RAFT ENGINE SUITE")
  println("=================================================================")

  let t = tracker_new()

  @! Category 1: Raft Consensus
  challenge_raft_stale_terms_and_step_up(t)
  challenge_raft_log_conflict_deep_truncation(t)
  challenge_raft_mismatched_prefix_rejections(t)
  challenge_raft_uncommitted_vs_committed_isolation(t)
  challenge_raft_cluster_partition_heal_reconciliation(t)

  @! Category 2: Transaction Atomicity & Isolation
  challenge_tx_nested_rejection(t)
  challenge_tx_heavy_mutation_rollback(t)
  challenge_tx_sequential_chains(t)

  @! Category 3: Snapshot Corruption Resilience
  challenge_snapshot_corruption_resilience(t)
  challenge_snapshot_dense_graph_roundtrip(t)

  @! Category 4: Property Index Synchronization
  challenge_property_index_type_flip_stress(t)
  challenge_property_index_shared_pruning_and_cascades(t)
  challenge_rapid_interleaved_fuzz_loop(t)

  println("\n=================================================================")
  println("📊 ADVERSARIAL CHALLENGE SUMMARY: " + int_to_str(t.passed) + " / " + int_to_str(t.total) + " PASSED (" + int_to_str(t.failed) + " FAILED)")
  println("=================================================================")

  @if t.failed > 0
    return 1
  @end
  return 0
@end
