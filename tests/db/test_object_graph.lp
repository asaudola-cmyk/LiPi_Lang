@! ============================================================================
@! MAYA UNIVERSE OBJECT-GRAPH DATABASE COMPREHENSIVE TEST SUITE
@! Test Target: tests/db/test_object_graph.maya
@! 4-Tier Verification Matrix (T1 Feature, T2 Boundary, T3 Raft, T4 Scenarios)
@! 100% Written in Pure Maya Language - Zero External C Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/db/object_graph"

@! ----------------------------------------------------------------------------
@! Test Harness & Assertion Utilities
@! ----------------------------------------------------------------------------

@struct TestSuiteTracker
  total: i64
  passed: i64
  failed: i64
@end

@fn suite_tracker_new() -> TestSuiteTracker
  return { total: 0, passed: 0, failed: 0 }
@end

@fn test_assert_eq(tracker: TestSuiteTracker, actual: i64, expected: i64, test_name: string) -> bool
  tracker.total = tracker.total + 1
  @if actual == expected
    println("  [PASS] " + test_name)
    tracker.passed = tracker.passed + 1
    return true
  @else
    println("  [FAIL] " + test_name + " - Expected: " + int_to_str(expected) + ", Got: " + int_to_str(actual))
    tracker.failed = tracker.failed + 1
    return false
  @end
@end

@fn test_assert_str_eq(tracker: TestSuiteTracker, actual: string, expected: string, test_name: string) -> bool
  tracker.total = tracker.total + 1
  @if actual == expected
    println("  [PASS] " + test_name)
    tracker.passed = tracker.passed + 1
    return true
  @else
    println("  [FAIL] " + test_name + " - Expected: '" + expected + "', Got: '" + actual + "'")
    tracker.failed = tracker.failed + 1
    return false
  @end
@end

@fn test_assert_true(tracker: TestSuiteTracker, cond: bool, test_name: string) -> bool
  tracker.total = tracker.total + 1
  @if cond
    println("  [PASS] " + test_name)
    tracker.passed = tracker.passed + 1
    return true
  @else
    println("  [FAIL] " + test_name + " - Condition was false, expected true")
    tracker.failed = tracker.failed + 1
    return false
  @end
@end

@fn test_assert_false(tracker: TestSuiteTracker, cond: bool, test_name: string) -> bool
  return test_assert_true(tracker, !cond, test_name)
@end

@! ----------------------------------------------------------------------------
@! Tier 1: Feature Unit Tests (T1.1 - T1.10)
@! ----------------------------------------------------------------------------

@fn test_node_and_edge_crud(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  let u1 = og_add_node(engine, "u1", "User")
  let u2 = og_add_node(engine, "u2", "User")
  let s1 = og_add_node(engine, "s1", "Server")
  let d1 = og_add_node(engine, "d1", "Database")

  let e1 = og_add_edge(engine, "e1", "u1", "s1", "CONNECTS", 10)
  let e2 = og_add_edge(engine, "e2", "s1", "d1", "QUERIES", 5)
  let e3 = og_add_edge(engine, "e3", "u2", "s1", "CONNECTS", 15)
  let e4 = og_add_edge_undirected(engine, "e4", "u1", "u2", "KNOWS", 2)

  test_assert_eq(tracker, engine.node_count, 4, "T1.1: Node count after insertion")
  test_assert_eq(tracker, engine.edge_count, 4, "T1.1: Edge count after insertion")

  let get_u1 = og_get_node(engine, "u1")
  test_assert_true(tracker, og_node_is_valid(get_u1), "T1.1: Node u1 lookup valid")
  test_assert_str_eq(tracker, get_u1.label, "User", "T1.1: Node u1 label match")

  let get_e1 = og_get_edge(engine, "e1")
  test_assert_true(tracker, og_edge_is_valid(get_e1), "T1.1: Edge e1 lookup valid")
  test_assert_eq(tracker, get_e1.weight, 10, "T1.1: Edge e1 weight match")

  let del_res = og_delete_node(engine, "u2")
  test_assert_true(tracker, del_res, "T1.1: Node u2 deleted successfully")
  test_assert_eq(tracker, engine.node_count, 3, "T1.1: Node count after deletion")
  test_assert_eq(tracker, engine.edge_count, 2, "T1.1: Edge count after cascade deletion of incident edges")

  let get_u2 = og_get_node(engine, "u2")
  test_assert_false(tracker, og_node_is_valid(get_u2), "T1.1: Node u2 is invalid after deletion")
@end

@fn test_multi_type_property_indexing(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "u1", "User")
  og_add_node(engine, "u2", "User")
  og_add_node(engine, "u3", "User")

  og_set_node_prop(engine, "u1", "role", "admin", 0, false)
  og_set_node_prop(engine, "u1", "age", "", 32, true)
  og_set_node_prop(engine, "u2", "role", "guest", 0, false)
  og_set_node_prop(engine, "u2", "age", "", 19, true)
  og_set_node_prop(engine, "u3", "role", "admin", 0, false)
  og_set_node_prop(engine, "u3", "age", "", 45, true)

  let admin_ids = og_find_nodes_by_prop_str(engine, "role", "admin")
  test_assert_eq(tracker, admin_ids.len(), 2, "T1.2: String prop index lookup count")
  test_assert_true(tracker, array_contains_str(admin_ids, "u1") == 1, "T1.2: Admin index contains u1")
  test_assert_true(tracker, array_contains_str(admin_ids, "u3") == 1, "T1.2: Admin index contains u3")

  let age19_ids = og_find_nodes_by_prop_num(engine, "age", 19)
  test_assert_eq(tracker, age19_ids.len(), 1, "T1.2: Numeric prop index lookup count")
  test_assert_str_eq(tracker, age19_ids[0], "u2", "T1.2: Numeric index matched u2")

  og_set_node_prop(engine, "u1", "role", "superadmin", 0, false)
  let updated_admins = og_find_nodes_by_prop_str(engine, "role", "admin")
  test_assert_eq(tracker, updated_admins.len(), 1, "T1.2: Prop update pruned previous index entry")
@end

@fn test_inverted_label_index_lookups(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "dev_1", "Device")
  og_add_node(engine, "dev_2", "Device")
  og_add_node(engine, "dev_3", "Device")
  og_add_node(engine, "usr_1", "User")
  og_add_node(engine, "usr_2", "User")
  og_add_node(engine, "cls_1", "Cluster")

  let devices = og_find_nodes_by_label(engine, "Device")
  test_assert_eq(tracker, devices.len(), 3, "T1.3: Inverted label index finds 3 devices")
  test_assert_true(tracker, array_contains_str(devices, "dev_2") == 1, "T1.3: Device index contains dev_2")

  let unknown = og_find_nodes_by_label(engine, "NonExistent")
  test_assert_eq(tracker, unknown.len(), 0, "T1.3: Unknown label returns empty array")
@end

@fn test_adjacency_lists_and_degree(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "s1", "Server")
  og_add_node(engine, "c1", "Client")
  og_add_node(engine, "c2", "Client")
  og_add_node(engine, "db", "Database")

  og_add_edge(engine, "e1", "c1", "s1", "REQ", 1)
  og_add_edge(engine, "e2", "c2", "s1", "REQ", 1)
  og_add_edge(engine, "e3", "s1", "db", "SQL", 2)

  let out_edges = og_get_out_edges(engine, "s1")
  test_assert_eq(tracker, out_edges.len(), 1, "T1.4: Server outgoing edge count is 1")

  let in_edges = og_get_in_edges(engine, "s1")
  test_assert_eq(tracker, in_edges.len(), 2, "T1.4: Server incoming edge count is 2")

  let out_deg = og_get_degree(engine, "s1", "OUT")
  let in_deg = og_get_degree(engine, "s1", "IN")
  let both_deg = og_get_degree(engine, "s1", "BOTH")
  test_assert_eq(tracker, out_deg, 1, "T1.4: Degree OUT match")
  test_assert_eq(tracker, in_deg, 2, "T1.4: Degree IN match")
  test_assert_eq(tracker, both_deg, 3, "T1.4: Degree BOTH match")
@end

@fn test_bfs_traversal_dag(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "A", "Node")
  og_add_node(engine, "B", "Node")
  og_add_node(engine, "C", "Node")
  og_add_node(engine, "D", "Node")

  og_add_edge(engine, "e1", "A", "B", "LINK", 1)
  og_add_edge(engine, "e2", "A", "C", "LINK", 1)
  og_add_edge(engine, "e3", "B", "D", "LINK", 1)
  og_add_edge(engine, "e4", "C", "D", "LINK", 1)

  let bfs_res = og_bfs_traverse(engine, "A")
  test_assert_eq(tracker, bfs_res.len(), 4, "T1.5: BFS visits all 4 DAG nodes")
  test_assert_str_eq(tracker, bfs_res[0], "A", "T1.5: BFS starts at root A")
  test_assert_str_eq(tracker, bfs_res[3], "D", "T1.5: BFS reaches leaf D at end")
@end

@fn test_dfs_traversal_tree(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "R", "Root")
  og_add_node(engine, "L", "Branch")
  og_add_node(engine, "R1", "Branch")
  og_add_node(engine, "LL", "Leaf")
  og_add_node(engine, "LR", "Leaf")

  og_add_edge(engine, "e1", "R", "L", "TREE", 1)
  og_add_edge(engine, "e2", "R", "R1", "TREE", 1)
  og_add_edge(engine, "e3", "L", "LL", "TREE", 1)
  og_add_edge(engine, "e4", "L", "LR", "TREE", 1)

  let dfs_res = og_dfs_traverse(engine, "R")
  test_assert_eq(tracker, dfs_res.len(), 5, "T1.6: DFS visits all 5 tree nodes")
  test_assert_str_eq(tracker, dfs_res[0], "R", "T1.6: DFS starts at root R")
@end

@fn test_dijkstra_weighted_shortest_path(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "A", "City")
  og_add_node(engine, "B", "City")
  og_add_node(engine, "C", "City")
  og_add_node(engine, "D", "City")

  og_add_edge(engine, "e1", "A", "B", "ROAD", 10)
  og_add_edge(engine, "e2", "A", "C", "ROAD", 3)
  og_add_edge(engine, "e3", "C", "B", "ROAD", 2)
  og_add_edge(engine, "e4", "B", "D", "ROAD", 4)
  og_add_edge(engine, "e5", "C", "D", "ROAD", 8)

  let path = og_dijkstra_shortest_path(engine, "A", "D")
  test_assert_eq(tracker, path.len(), 4, "T1.7: Dijkstra path hop count is 4")
  test_assert_str_eq(tracker, path[0], "A", "T1.7: Path starts at A")
  test_assert_str_eq(tracker, path[1], "C", "T1.7: Path steps to C (cost 3)")
  test_assert_str_eq(tracker, path[2], "B", "T1.7: Path steps to B (cost 5)")
  test_assert_str_eq(tracker, path[3], "D", "T1.7: Path reaches D (cost 9 vs direct 14)")
@end

@fn test_cypher_pattern_matching(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "alice", "User")
  og_add_node(engine, "bob", "User")
  og_add_node(engine, "doc1", "Article")
  og_add_node(engine, "doc2", "Article")

  og_set_node_prop(engine, "alice", "role", "admin", 0, false)
  og_set_node_prop(engine, "bob", "role", "editor", 0, false)

  og_add_edge(engine, "e1", "alice", "doc1", "AUTHORED", 1)
  og_add_edge(engine, "e2", "bob", "doc2", "AUTHORED", 1)

  let pat = {
    src_label: "User",
    edge_label: "AUTHORED",
    tgt_label: "Article",
    src_prop_key: "role",
    src_prop_val: "admin",
    tgt_prop_key: "",
    tgt_prop_val: "",
    min_weight: 0
  }

  let matches = og_match_pattern(engine, pat)
  test_assert_eq(tracker, matches.len(), 1, "T1.8: Pattern matcher filters admin author")
  let pm: PatternMatch = matches[0]
  test_assert_str_eq(tracker, pm.src_id, "alice", "T1.8: Match src is alice")
  test_assert_str_eq(tracker, pm.tgt_id, "doc1", "T1.8: Match tgt is doc1")
@end

@fn test_subgraph_extraction(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "A", "N")
  og_add_node(engine, "B", "N")
  og_add_node(engine, "C", "N")
  og_add_node(engine, "D", "N")

  og_add_edge(engine, "e1", "A", "B", "E", 1)
  og_add_edge(engine, "e2", "B", "C", "E", 2)
  og_add_edge(engine, "e3", "C", "D", "E", 3)

  let sub = og_extract_subgraph(engine, ["A", "B", "C"])
  test_assert_eq(tracker, sub.node_count, 3, "T1.9: Subgraph node count is 3")
  test_assert_eq(tracker, sub.edge_count, 2, "T1.9: Subgraph edge count is 2 (e1 and e2 only)")
@end

@fn test_snapshot_serialization_and_recovery(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "n1", "Node")
  og_add_node(engine, "n2", "Node")
  og_set_node_prop(engine, "n1", "score", "", 100, true)
  og_add_edge(engine, "e1", "n1", "n2", "LINK", 42)

  let snap_str = og_export_snapshot(engine)
  test_assert_true(tracker, str_len(snap_str) > 0, "T1.10: Snapshot exported non-empty string")

  let imported = og_import_snapshot(snap_str)
  test_assert_eq(tracker, imported.node_count, 2, "T1.10: Imported node count matches")
  test_assert_eq(tracker, imported.edge_count, 1, "T1.10: Imported edge count matches")
  let score = og_get_node_prop_num(imported, "n1", "score")
  test_assert_eq(tracker, score, 100, "T1.10: Imported property score match")
@end

@! ----------------------------------------------------------------------------
@! Tier 2: Boundary & Corner Cases (T2.1 - T2.8)
@! ----------------------------------------------------------------------------

@fn test_cyclic_graph_traversals(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "A", "N")
  og_add_node(engine, "B", "N")
  og_add_node(engine, "C", "N")

  og_add_edge(engine, "e1", "A", "B", "LOOP", 1)
  og_add_edge(engine, "e2", "B", "C", "LOOP", 1)
  og_add_edge(engine, "e3", "C", "A", "LOOP", 1)
  og_add_edge(engine, "e4", "B", "B", "SELF", 1)

  let bfs_res = og_bfs_traverse(engine, "A")
  test_assert_eq(tracker, bfs_res.len(), 3, "T2.1: BFS terminates on cycle without looping")

  let cycles = og_dfs_detect_cycles(engine, "A")
  test_assert_true(tracker, cycles.len() >= 1, "T2.1: DFS cycle detection identifies loop")
@end

@fn test_disconnected_components_and_unreachable_paths(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "A", "Island1")
  og_add_node(engine, "B", "Island1")
  og_add_node(engine, "X", "Island2")
  og_add_node(engine, "Y", "Island2")

  og_add_edge(engine, "e1", "A", "B", "ROAD", 5)
  og_add_edge(engine, "e2", "X", "Y", "ROAD", 5)

  let path = og_dijkstra_shortest_path(engine, "A", "Y")
  test_assert_eq(tracker, path.len(), 0, "T2.2: Disconnected components return empty path without panic")
@end

@fn test_parallel_edges_and_multi_relations(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "A", "Person")
  og_add_node(engine, "B", "Person")

  og_add_edge(engine, "e_slow", "A", "B", "KNOWS", 10)
  og_add_edge(engine, "e_fast", "A", "B", "WORKS_WITH", 2)

  let out_edges = og_get_out_edges(engine, "A")
  test_assert_eq(tracker, out_edges.len(), 2, "T2.3: Parallel edges both registered in adjacency")

  let path = og_dijkstra_shortest_path(engine, "A", "B")
  test_assert_eq(tracker, path.len(), 2, "T2.3: Dijkstra succeeds over parallel multi-edges")
@end

@fn test_empty_graph_and_out_of_bounds_queries(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  let ghost = og_get_node(engine, "non_existent")
  test_assert_false(tracker, og_node_is_valid(ghost), "T2.4: Querying non-existent node returns invalid node")

  let bfs_empty = og_bfs_traverse(engine, "ghost")
  test_assert_eq(tracker, bfs_empty.len(), 0, "T2.4: BFS on empty node returns empty array")

  let path_empty = og_dijkstra_shortest_path(engine, "ghost1", "ghost2")
  test_assert_eq(tracker, path_empty.len(), 0, "T2.4: Dijkstra on non-existent endpoints returns empty array")
@end

@fn test_deleted_node_cascading_edge_invalidation(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "hub", "Hub")
  og_add_node(engine, "spoke1", "Spoke")
  og_add_node(engine, "spoke2", "Spoke")

  og_add_edge(engine, "e1", "hub", "spoke1", "STAR", 1)
  og_add_edge(engine, "e2", "hub", "spoke2", "STAR", 1)

  og_delete_node(engine, "hub")
  test_assert_eq(tracker, engine.node_count, 2, "T2.5: Spokes remain after hub deleted")
  test_assert_eq(tracker, engine.edge_count, 0, "T2.5: Incident edges cascaded to 0")

  let deg = og_get_degree(engine, "spoke1", "BOTH")
  test_assert_eq(tracker, deg, 0, "T2.5: Spoke degree becomes 0 after hub deleted")
@end

@fn test_property_type_coercion_and_overwriting(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "n1", "Item")

  og_set_node_prop(engine, "n1", "val", "", 100, true)
  let num_ids = og_find_nodes_by_prop_num(engine, "val", 100)
  test_assert_eq(tracker, num_ids.len(), 1, "T2.6: Numeric prop set initially")

  og_set_node_prop(engine, "n1", "val", "hello", 0, false)
  let num_ids_after = og_find_nodes_by_prop_num(engine, "val", 100)
  let str_ids_after = og_find_nodes_by_prop_str(engine, "val", "hello")
  test_assert_eq(tracker, num_ids_after.len(), 0, "T2.6: Old numeric index pruned after type overwrite")
  test_assert_eq(tracker, str_ids_after.len(), 1, "T2.6: New string index active")
@end

@fn test_transaction_rollback_pre_tx_preservation(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "base1", "Base")
  og_add_node(engine, "base2", "Base")
  og_add_edge(engine, "base_edge", "base1", "base2", "BASE", 10)

  let tx = og_begin_tx(engine)
  test_assert_true(tracker, engine.in_tx, "T2.7: Engine entered transaction state")

  og_add_node(engine, "staged_1", "Staged")
  og_add_node(engine, "staged_2", "Staged")
  og_add_edge(engine, "staged_edge", "staged_1", "staged_2", "STAGED", 5)
  og_delete_node(engine, "base1")
  test_assert_eq(tracker, engine.node_count, 3, "T2.7: Staged count inside transaction")

  let rb_res = og_rollback_tx(engine)
  test_assert_true(tracker, rb_res, "T2.7: Transaction rollback succeeded")
  test_assert_false(tracker, engine.in_tx, "T2.7: Engine exited transaction state")
  test_assert_eq(tracker, engine.node_count, 2, "T2.7: Node count restored to baseline")
  test_assert_eq(tracker, engine.edge_count, 1, "T2.7: Edge count restored to baseline")

  let base1_restored = og_get_node(engine, "base1")
  test_assert_true(tracker, og_node_is_valid(base1_restored), "T2.7: Deleted base1 restored after rollback")

  let staged_gone = og_get_node(engine, "staged_1")
  test_assert_false(tracker, og_node_is_valid(staged_gone), "T2.7: Staged node vanished after rollback")
@end

@fn test_transaction_aborted_read_isolation(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  og_add_node(engine, "root", "System")
  
  let tx = og_begin_tx(engine)
  og_set_node_prop(engine, "root", "secret", "tx_val", 0, false)
  og_rollback_tx(engine)

  let sec = og_get_node_prop_str(engine, "root", "secret")
  test_assert_str_eq(tracker, sec, "", "T2.8: Uncommitted property mutation not present after abort")
@end

@! ----------------------------------------------------------------------------
@! Tier 3: Raft Distributed Consensus Scaffolding (T3.1 - T3.8)
@! ----------------------------------------------------------------------------

@fn test_raft_node_init_follower(tracker: TestSuiteTracker)
  let node = raft_node_new("node_1", ["node_2", "node_3"])
  test_assert_str_eq(tracker, node.node_id, "node_1", "T3.1: Raft node ID init")
  test_assert_eq(tracker, node.term, 0, "T3.1: Raft initial term is 0")
  test_assert_str_eq(tracker, node.state, "FOLLOWER", "T3.1: Raft initial state is FOLLOWER")
  test_assert_str_eq(tracker, node.voted_for, "", "T3.1: Raft initial voted_for is empty")
  test_assert_eq(tracker, node.commit_index, 0, "T3.1: Raft initial commit_index is 0")
  test_assert_eq(tracker, node.log.len(), 0, "T3.1: Raft initial log is empty")
@end

@fn test_raft_request_vote_grant_and_reject(tracker: TestSuiteTracker)
  let follower = raft_node_new("node_1", ["c1", "c2", "c3"])
  follower.term = 1

  let grant1 = raft_request_vote(follower, 1, "c1", 0, 0)
  test_assert_eq(tracker, grant1, 1, "T3.2: First candidate in term 1 receives vote")
  test_assert_str_eq(tracker, follower.voted_for, "c1", "T3.2: Follower recorded vote for c1")

  let grant2 = raft_request_vote(follower, 1, "c2", 0, 0)
  test_assert_eq(tracker, grant2, 0, "T3.2: Second candidate in term 1 is rejected")

  let grant3 = raft_request_vote(follower, 2, "c3", 0, 0)
  test_assert_eq(tracker, grant3, 1, "T3.2: Candidate in higher term 2 is granted vote")
  test_assert_eq(tracker, follower.term, 2, "T3.2: Follower updated term to 2")
  test_assert_str_eq(tracker, follower.voted_for, "c3", "T3.2: Follower updated vote for c3")
@end

@fn test_raft_leader_election_quorum(tracker: TestSuiteTracker)
  let n0 = raft_node_new("node_0", ["node_1", "node_2"])
  let n1 = raft_node_new("node_1", ["node_0", "node_2"])
  let n2 = raft_node_new("node_2", ["node_0", "node_1"])
  let cluster = [n0, n1, n2]

  let elected = raft_simulate_election(cluster)
  test_assert_str_eq(tracker, elected, "node_0", "T3.3: Node 0 achieves quorum and elected leader")
  test_assert_str_eq(tracker, n0.state, "LEADER", "T3.3: Node 0 state transitioned to LEADER")
  test_assert_eq(tracker, n0.term, 1, "T3.3: Node 0 term advanced to 1")
@end

@fn test_raft_split_vote_resolution_retry(tracker: TestSuiteTracker)
  let n0 = raft_node_new("node_0", ["node_1", "node_2"])
  let n1 = raft_node_new("node_1", ["node_0", "node_2"])
  let n2 = raft_node_new("node_2", ["node_0", "node_1"])
  let cluster = [n0, n1, n2]

  let leader_id = raft_simulate_split_vote(cluster)
  test_assert_str_eq(tracker, leader_id, "node_0", "T3.4: Split vote recovered by higher term candidate")
  test_assert_str_eq(tracker, n0.state, "LEADER", "T3.4: Node 0 becomes leader after split vote resolution")
  test_assert_eq(tracker, n0.term, 2, "T3.4: Final leader term is 2")
@end

@fn test_raft_heartbeat_and_lease_renewal(tracker: TestSuiteTracker)
  let follower = raft_node_new("node_2", ["node_1"])
  follower.term = 1
  follower.election_timer = 120

  let hb_res = raft_append_entries(follower, 1, "node_1", 0, 0, [], 0)
  test_assert_eq(tracker, hb_res, 1, "T3.5: Follower accepted leader heartbeat")
  test_assert_eq(tracker, follower.election_timer, 0, "T3.5: Election timer reset on heartbeat")
  test_assert_str_eq(tracker, follower.state, "FOLLOWER", "T3.5: State remains FOLLOWER")
@end

@fn test_raft_log_replication_pipeline(tracker: TestSuiteTracker)
  let leader = raft_node_new("leader", ["follower"])
  raft_elect_leader(leader)

  let follower = raft_node_new("follower", ["leader"])
  follower.term = leader.term

  let rep_ok = raft_replicate_command(leader, "ADD_NODE", "srv_1:Server")
  test_assert_true(tracker, rep_ok, "T3.6: Command replicated to leader log")
  test_assert_eq(tracker, leader.log.len(), 1, "T3.6: Leader log contains 1 entry")
  test_assert_eq(tracker, leader.commit_index, 1, "T3.6: Leader commit index advanced")

  let append_ok = raft_append_entries(follower, leader.term, leader.node_id, 0, 0, leader.log, leader.commit_index)
  test_assert_eq(tracker, append_ok, 1, "T3.6: Follower successfully appended leader entries")
  test_assert_eq(tracker, follower.log.len(), 1, "T3.6: Follower log matches leader")
  test_assert_eq(tracker, follower.commit_index, 1, "T3.6: Follower commit index updated")
@end

@fn test_raft_log_conflict_overwrite(tracker: TestSuiteTracker)
  let follower = raft_node_new("follower", ["leader"])
  follower.term = 1
  follower.log.push({ term: 1, index: 1, command_type: "ADD_NODE", payload: "u1:User" })
  follower.log.push({ term: 1, index: 2, command_type: "ADD_NODE", payload: "stale_node:Bad" })

  let leader_entries = [
    { term: 2, index: 2, command_type: "ADD_NODE", payload: "correct_node:Good" }
  ]

  let res = raft_append_entries(follower, 2, "leader", 1, 1, leader_entries, 2)
  test_assert_eq(tracker, res, 1, "T3.7: Leader overwrote conflicting log entry")
  test_assert_eq(tracker, follower.log.len(), 2, "T3.7: Follower log length is 2")
  let e2: RaftLogEntry = follower.log[1]
  test_assert_str_eq(tracker, e2.payload, "correct_node:Good", "T3.7: Authoritative payload persisted")
@end

@fn test_raft_state_machine_apply_congruence(tracker: TestSuiteTracker)
  let engine = og_engine_new()
  let raft_node = raft_node_new("node_1", [])
  raft_node.term = 1
  raft_node.log.push({ term: 1, index: 1, command_type: "ADD_NODE", payload: "db1:Database" })
  raft_node.log.push({ term: 1, index: 2, command_type: "SET_PROP", payload: "NODE:db1:engine:graph:0:0" })
  raft_node.commit_index = 2

  let applied = raft_apply_to_graph(raft_node, engine)
  test_assert_eq(tracker, applied, 2, "T3.8: Raft applied 2 committed entries to state machine")
  test_assert_eq(tracker, engine.node_count, 1, "T3.8: Database node created in engine")
  let prop_val = og_get_node_prop_str(engine, "db1", "engine")
  test_assert_str_eq(tracker, prop_val, "graph", "T3.8: Property applied correctly to node")
@end

@! ----------------------------------------------------------------------------
@! Tier 4: Real-World Clustered Application Scenarios (T4.1 - T4.2)
@! ----------------------------------------------------------------------------

@fn test_scenario_distributed_graph_replicated_cluster(tracker: TestSuiteTracker)
  println("  Executing Scenario 1: Distributed 3-Node Object-Graph Cluster Simulation...")
  let eng1 = og_engine_new()
  let eng2 = og_engine_new()
  let eng3 = og_engine_new()

  let n1 = raft_node_new("node_1", ["node_2", "node_3"])
  let n2 = raft_node_new("node_2", ["node_1", "node_3"])
  let n3 = raft_node_new("node_3", ["node_1", "node_2"])

  raft_elect_leader(n1)
  test_assert_str_eq(tracker, n1.state, "LEADER", "T4.1: Cluster elected Leader node_1")

  raft_replicate_command(n1, "ADD_NODE", "srv_1:Server")
  raft_replicate_command(n1, "ADD_NODE", "srv_2:Server")
  raft_replicate_command(n1, "ADD_NODE", "srv_3:Server")
  raft_replicate_command(n1, "ADD_NODE", "srv_4:Server")
  raft_replicate_command(n1, "ADD_NODE", "srv_5:Server")

  raft_replicate_command(n1, "ADD_EDGE", "e12:srv_1:srv_2:NET:10")
  raft_replicate_command(n1, "ADD_EDGE", "e13:srv_1:srv_3:NET:3")
  raft_replicate_command(n1, "ADD_EDGE", "e32:srv_3:srv_2:NET:2")
  raft_replicate_command(n1, "ADD_EDGE", "e25:srv_2:srv_5:NET:4")
  raft_replicate_command(n1, "ADD_EDGE", "e35:srv_3:srv_5:NET:8")

  raft_append_entries(n2, n1.term, n1.node_id, 0, 0, n1.log, n1.commit_index)
  raft_append_entries(n3, n1.term, n1.node_id, 0, 0, n1.log, n1.commit_index)

  raft_apply_to_graph(n1, eng1)
  raft_apply_to_graph(n2, eng2)
  raft_apply_to_graph(n3, eng3)

  test_assert_eq(tracker, eng1.node_count, 5, "T4.1: Node 1 applied 5 nodes")
  test_assert_eq(tracker, eng2.node_count, 5, "T4.1: Node 2 applied 5 nodes")
  test_assert_eq(tracker, eng3.node_count, 5, "T4.1: Node 3 applied 5 nodes")

  let path1 = og_dijkstra_shortest_path(eng1, "srv_1", "srv_5")
  let path2 = og_dijkstra_shortest_path(eng2, "srv_1", "srv_5")
  let path3 = og_dijkstra_shortest_path(eng3, "srv_1", "srv_5")

  test_assert_eq(tracker, path1.len(), 4, "T4.1: Node 1 computed optimal 4-hop path")
  test_assert_eq(tracker, path2.len(), 4, "T4.1: Node 2 computed optimal 4-hop path")
  test_assert_eq(tracker, path3.len(), 4, "T4.1: Node 3 computed optimal 4-hop path")
  test_assert_str_eq(tracker, path1[1], "srv_3", "T4.1: Path consistency via srv_3 across cluster")
@end

@fn test_scenario_leader_crash_failover_and_reconciliation(tracker: TestSuiteTracker)
  println("  Executing Scenario 2: Leader Crash, Failover Election, and Log Reconciliation...")
  let eng1 = og_engine_new()
  let eng2 = og_engine_new()

  let n1 = raft_node_new("node_1", ["node_2"])
  let n2 = raft_node_new("node_2", ["node_1"])

  raft_elect_leader(n1)
  raft_replicate_command(n1, "ADD_NODE", "v1:Vertex")
  raft_append_entries(n2, n1.term, n1.node_id, 0, 0, n1.log, n1.commit_index)
  raft_apply_to_graph(n1, eng1)
  raft_apply_to_graph(n2, eng2)

  @! Leader 1 partitions / crashes. Node 2 starts election for term 2 and becomes new Leader
  n2.term = 2
  n2.state = "LEADER"
  raft_replicate_command(n2, "ADD_NODE", "v2:Vertex")
  raft_replicate_command(n2, "ADD_EDGE", "edge_v1_v2:v1:v2:LINK:1")
  raft_apply_to_graph(n2, eng2)

  test_assert_eq(tracker, eng2.node_count, 2, "T4.2: Node 2 applied new mutations as term 2 leader")

  @! Node 1 recovers and reconciles from Node 2
  raft_append_entries(n1, n2.term, n2.node_id, 1, 1, [n2.log[1], n2.log[2]], n2.commit_index)
  raft_apply_to_graph(n1, eng1)

  test_assert_eq(tracker, eng1.node_count, 2, "T4.2: Node 1 recovered and reconciled node count")
  test_assert_eq(tracker, eng1.edge_count, 1, "T4.2: Node 1 recovered edge relationship")
@end

@! ----------------------------------------------------------------------------
@! Main Test Runner Entry Point
@! ----------------------------------------------------------------------------

@fn main()
  println("=================================================================")
  println("🚀 RUNNING MAYA OBJECT-GRAPH DB & RAFT CONSENSUS TEST SUITE")
  println("=================================================================")

  let tracker = suite_tracker_new()

  println("\n--- Tier 1: Feature Unit Tests ---")
  test_node_and_edge_crud(tracker)
  test_multi_type_property_indexing(tracker)
  test_inverted_label_index_lookups(tracker)
  test_adjacency_lists_and_degree(tracker)
  test_bfs_traversal_dag(tracker)
  test_dfs_traversal_tree(tracker)
  test_dijkstra_weighted_shortest_path(tracker)
  test_cypher_pattern_matching(tracker)
  test_subgraph_extraction(tracker)
  test_snapshot_serialization_and_recovery(tracker)

  println("\n--- Tier 2: Boundary & Corner Cases ---")
  test_cyclic_graph_traversals(tracker)
  test_disconnected_components_and_unreachable_paths(tracker)
  test_parallel_edges_and_multi_relations(tracker)
  test_empty_graph_and_out_of_bounds_queries(tracker)
  test_deleted_node_cascading_edge_invalidation(tracker)
  test_property_type_coercion_and_overwriting(tracker)
  test_transaction_rollback_pre_tx_preservation(tracker)
  test_transaction_aborted_read_isolation(tracker)

  println("\n--- Tier 3: Raft Distributed Consensus Scaffolding ---")
  test_raft_node_init_follower(tracker)
  test_raft_request_vote_grant_and_reject(tracker)
  test_raft_leader_election_quorum(tracker)
  test_raft_split_vote_resolution_retry(tracker)
  test_raft_heartbeat_and_lease_renewal(tracker)
  test_raft_log_replication_pipeline(tracker)
  test_raft_log_conflict_overwrite(tracker)
  test_raft_state_machine_apply_congruence(tracker)

  println("\n--- Tier 4: Real-World Distributed Cluster Scenarios ---")
  test_scenario_distributed_graph_replicated_cluster(tracker)
  test_scenario_leader_crash_failover_and_reconciliation(tracker)

  println("\n=================================================================")
  println("📊 TEST SUMMARY: " + int_to_str(tracker.passed) + " / " + int_to_str(tracker.total) + " PASSED (" + int_to_str(tracker.failed) + " FAILED)")
  println("=================================================================")

  @if tracker.failed > 0
    return 1
  @end
  return 0
@end
