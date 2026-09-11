@! ============================================================================
@! MAYA UNIVERSE DB - EMPIRICAL ADVERSARIAL CHALLENGER 1 SUITE
@! Target: universe/db/object_graph.maya
@! Stress-testing deep graphs (150+ nodes), dense meshes, Dijkstra competing paths,
@! massive cascaded deletions, repeated transaction rollbacks, large snapshots,
@! and Raft consensus edge cases under stress.
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/db/object_graph"

@struct AdvTracker
  total: i64
  passed: i64
  failed: i64
@end

@fn adv_tracker_new() -> AdvTracker
  return { total: 0, passed: 0, failed: 0 }
@end

@fn adv_assert_eq(tracker: AdvTracker, actual: i64, expected: i64, name: string) -> bool
  tracker.total = tracker.total + 1
  @if actual == expected
    println("  [PASS] " + name)
    tracker.passed = tracker.passed + 1
    return true
  @else
    println("  [FAIL] " + name + " - Expected: " + int_to_str(expected) + ", Got: " + int_to_str(actual))
    tracker.failed = tracker.failed + 1
    return false
  @end
@end

@fn adv_assert_str_eq(tracker: AdvTracker, actual: string, expected: string, name: string) -> bool
  tracker.total = tracker.total + 1
  @if actual == expected
    println("  [PASS] " + name)
    tracker.passed = tracker.passed + 1
    return true
  @else
    println("  [FAIL] " + name + " - Expected: '" + expected + "', Got: '" + actual + "'")
    tracker.failed = tracker.failed + 1
    return false
  @end
@end

@fn adv_assert_true(tracker: AdvTracker, cond: bool, name: string) -> bool
  tracker.total = tracker.total + 1
  @if cond
    println("  [PASS] " + name)
    tracker.passed = tracker.passed + 1
    return true
  @else
    println("  [FAIL] " + name + " - Condition false, expected true")
    tracker.failed = tracker.failed + 1
    return false
  @end
@end

@fn adv_assert_false(tracker: AdvTracker, cond: bool, name: string) -> bool
  return adv_assert_true(tracker, !cond, name)
@end

@! ============================================================================
@! Challenge 1: Deep 150-Node Linear Chain & Traversal Stress
@! ============================================================================

@fn test_deep_150_node_linear_chain(tracker: AdvTracker)
  println("\n--- Challenge 1: Deep 150-Node Linear Chain ---")
  let engine = og_engine_new()

  let n = 150
  let i = 0
  @while i < n
    let nid = "node_" + int_to_str(i)
    let lbl = "ChainNode"
    @if i % 2 == 0
      lbl = "EvenNode"
    @end
    og_add_node(engine, nid, lbl)
    og_set_node_prop(engine, nid, "seq", "", i, true)
    og_set_node_prop(engine, nid, "code", "C_" + int_to_str(i), 0, false)
    i = i + 1
  @end

  let j = 0
  @while j < n - 1
    let src = "node_" + int_to_str(j)
    let tgt = "node_" + int_to_str(j + 1)
    let eid = "edge_" + int_to_str(j)
    og_add_edge(engine, eid, src, tgt, "NEXT", 1)
    j = j + 1
  @end

  adv_assert_eq(tracker, engine.node_count, 150, "C1.1: 150 nodes created")
  adv_assert_eq(tracker, engine.edge_count, 149, "C1.1: 149 edges created")

  @! BFS from start to end
  let bfs_res = og_bfs_traverse(engine, "node_0")
  adv_assert_eq(tracker, bfs_res.len(), 150, "C1.2: BFS traverses all 150 nodes")
  adv_assert_str_eq(tracker, bfs_res[0], "node_0", "C1.2: BFS root is node_0")
  adv_assert_str_eq(tracker, bfs_res[149], "node_149", "C1.2: BFS leaf is node_149")

  @! DFS from start to end
  let dfs_res = og_dfs_traverse(engine, "node_0")
  adv_assert_eq(tracker, dfs_res.len(), 150, "C1.3: DFS traverses all 150 nodes without stack overflow")
  adv_assert_str_eq(tracker, dfs_res[149], "node_149", "C1.3: DFS terminates at node_149")

  @! Dijkstra 150 hops
  let path = og_dijkstra_shortest_path(engine, "node_0", "node_149")
  adv_assert_eq(tracker, path.len(), 150, "C1.4: Dijkstra 150-hop path exact length")
  adv_assert_str_eq(tracker, path[0], "node_0", "C1.4: Path start node_0")
  adv_assert_str_eq(tracker, path[149], "node_149", "C1.4: Path end node_149")

  @! Reverse direction (directed graph) must return empty path
  let rev_path = og_dijkstra_shortest_path(engine, "node_149", "node_0")
  adv_assert_eq(tracker, rev_path.len(), 0, "C1.5: Reverse directed path correctly unreachable")

  @! Inverted label indexing
  let even_nodes = og_find_nodes_by_label(engine, "EvenNode")
  adv_assert_eq(tracker, even_nodes.len(), 75, "C1.6: Label index found exactly 75 EvenNodes")

  @! Property index lookup
  let prop_match = og_find_nodes_by_prop_num(engine, "seq", 100)
  adv_assert_eq(tracker, prop_match.len(), 1, "C1.7: Numeric property index lookup at seq=100")
  adv_assert_str_eq(tracker, prop_match[0], "node_100", "C1.7: Node matches node_100")
@end

@! ============================================================================
@! Challenge 2: Dense 10x10 Grid Mesh & Competing Dijkstra Paths
@! ============================================================================

@fn test_grid_mesh_and_competing_dijkstra_paths(tracker: AdvTracker)
  println("\n--- Challenge 2: 10x10 Grid Mesh & Competing Dijkstra Paths ---")
  let engine = og_engine_new()

  @! Create 100 grid nodes (g_0_0 to g_9_9)
  let r = 0
  @while r < 10
    let c = 0
    @while c < 10
      let nid = "g_" + int_to_str(r) + "_" + int_to_str(c)
      og_add_node(engine, nid, "GridNode")
      og_set_node_prop(engine, nid, "row", "", r, true)
      og_set_node_prop(engine, nid, "col", "", c, true)
      c = c + 1
    @end
    r = r + 1
  @end

  @! Connect horizontal and vertical edges with varying weights
  let e_count = 0
  r = 0
  @while r < 10
    let c = 0
    @while c < 10
      let src = "g_" + int_to_str(r) + "_" + int_to_str(c)

      @! Right edge
      @if c + 1 < 10
        let tgt_r = "g_" + int_to_str(r) + "_" + int_to_str(c + 1)
        let eid_r = "e_h_" + int_to_str(r) + "_" + int_to_str(c)
        og_add_edge(engine, eid_r, src, tgt_r, "EAST", 2)
        e_count = e_count + 1
      @end

      @! Down edge
      @if r + 1 < 10
        let tgt_d = "g_" + int_to_str(r + 1) + "_" + int_to_str(c)
        let eid_d = "e_v_" + int_to_str(r) + "_" + int_to_str(c)
        og_add_edge(engine, eid_d, src, tgt_d, "SOUTH", 2)
        e_count = e_count + 1
      @end

      c = c + 1
    @end
    r = r + 1
  @end

  adv_assert_eq(tracker, engine.node_count, 100, "C2.1: 100 Grid nodes")
  adv_assert_eq(tracker, engine.edge_count, 180, "C2.1: 180 Grid directed edges (90 horizontal + 90 vertical)")

  @! Shortest path from g_0_0 to g_9_9
  let grid_path = og_dijkstra_shortest_path(engine, "g_0_0", "g_9_9")
  adv_assert_eq(tracker, grid_path.len(), 19, "C2.2: Manhattan grid shortest path length is 19 nodes (18 steps)")
  adv_assert_str_eq(tracker, grid_path[0], "g_0_0", "C2.2: Grid path starts at g_0_0")
  adv_assert_str_eq(tracker, grid_path[18], "g_9_9", "C2.2: Grid path ends at g_9_9")

  @! Add an expensive highway edge g_0_0 -> g_9_9 with weight 500 (cost 500 > normal cost 18*2=36)
  og_add_edge(engine, "highway_slow", "g_0_0", "g_9_9", "HIGHWAY", 500)
  let path_after_slow = og_dijkstra_shortest_path(engine, "g_0_0", "g_9_9")
  adv_assert_eq(tracker, path_after_slow.len(), 19, "C2.3: Dijkstra ignores expensive 1-hop shortcut in favor of cheaper multi-hop path")

  @! Add an ultra-fast express teleport edge g_0_0 -> g_9_9 with weight 5 (cost 5 < 36)
  og_add_edge(engine, "teleport_fast", "g_0_0", "g_9_9", "TELEPORT", 5)
  let path_after_fast = og_dijkstra_shortest_path(engine, "g_0_0", "g_9_9")
  adv_assert_eq(tracker, path_after_fast.len(), 2, "C2.4: Dijkstra switches to ultra-fast express edge (len 2)")
  adv_assert_str_eq(tracker, path_after_fast[1], "g_9_9", "C2.4: Fast edge directly connects g_0_0 to g_9_9")
@end

@! ============================================================================
@! Challenge 3: Complex Multi-Cycles & Self-Loops
@! ============================================================================

@fn test_complex_multi_cycles_and_self_loops(tracker: AdvTracker)
  println("\n--- Challenge 3: Complex Multi-Cycles & Self-Loops ---")
  let engine = og_engine_new()

  @! Create 20 nodes in a ring with chords and self loops
  let k = 0
  @while k < 20
    let nid = "ring_" + int_to_str(k)
    og_add_node(engine, nid, "Ring")
    k = k + 1
  @end

  @! Ring edges
  k = 0
  @while k < 20
    let src = "ring_" + int_to_str(k)
    let tgt_idx = (k + 1) % 20
    let tgt = "ring_" + int_to_str(tgt_idx)
    og_add_edge(engine, "re_" + int_to_str(k), src, tgt, "RING_NEXT", 1)

    @! Add self-loop
    og_add_edge(engine, "self_" + int_to_str(k), src, src, "SELF", 10)

    @! Add chord
    @if k % 5 == 0
      let chord_tgt = "ring_" + int_to_str((k + 10) % 20)
      og_add_edge(engine, "chord_" + int_to_str(k), src, chord_tgt, "CHORD", 2)
    @end

    k = k + 1
  @end

  adv_assert_eq(tracker, engine.node_count, 20, "C3.1: 20 ring nodes")
  adv_assert_eq(tracker, engine.edge_count, 44, "C3.1: 20 ring edges + 20 self edges + 4 chords")

  @! Detect cycles
  let cycles = og_dfs_detect_cycles(engine, "ring_0")
  adv_assert_true(tracker, cycles.len() > 0, "C3.2: DFS detects cycles in interconnected ring with chords")

  @! BFS terminates cleanly without infinite loop
  let ring_bfs = og_bfs_traverse(engine, "ring_0")
  adv_assert_eq(tracker, ring_bfs.len(), 20, "C3.3: BFS visits all 20 ring nodes without cycling")

  @! Dijkstra uses chord shortcut (ring_0 -> ring_10 via chord has weight 2, ring has weight 10)
  let chord_path = og_dijkstra_shortest_path(engine, "ring_0", "ring_10")
  adv_assert_eq(tracker, chord_path.len(), 2, "C3.4: Dijkstra takes 1-hop chord shortcut to ring_10")
  adv_assert_str_eq(tracker, chord_path[0], "ring_0", "C3.4: Start ring_0")
  adv_assert_str_eq(tracker, chord_path[1], "ring_10", "C3.4: End ring_10 via chord")
@end

@! ============================================================================
@! Challenge 4: Massive Cascaded Deletions & Index Integrity
@! ============================================================================

@fn test_massive_cascaded_deletions_and_index_integrity(tracker: AdvTracker)
  println("\n--- Challenge 4: Massive Cascaded Deletions & Index Integrity ---")
  let engine = og_engine_new()

  @! 1. Create all 100 nodes first (50 Client, 50 Service)
  let i = 0
  @while i < 50
    og_add_node(engine, "cli_" + int_to_str(i), "Client")
    og_set_node_prop(engine, "cli_" + int_to_str(i), "tier", "standard", 0, false)
    og_set_node_prop(engine, "cli_" + int_to_str(i), "priority", "", i, true)

    og_add_node(engine, "srv_" + int_to_str(i), "Service")
    og_set_node_prop(engine, "srv_" + int_to_str(i), "tier", "backend", 0, false)
    og_set_node_prop(engine, "srv_" + int_to_str(i), "load", "", i * 10, true)
    i = i + 1
  @end

  @! 2. Create 100 edges (50 direct + 50 cross)
  let j = 0
  @while j < 50
    og_add_edge(engine, "e_call_" + int_to_str(j), "cli_" + int_to_str(j), "srv_" + int_to_str(j), "CALLS", 1)
    og_add_edge(engine, "e_cross_" + int_to_str(j), "cli_" + int_to_str(j), "srv_" + int_to_str((j + 1) % 50), "CALLS", 2)
    j = j + 1
  @end

  adv_assert_eq(tracker, engine.node_count, 100, "C4.1: Initial 100 nodes")
  adv_assert_eq(tracker, engine.edge_count, 100, "C4.1: Initial 100 edges")

  @! Verify initial index lookups
  let clients_init = og_find_nodes_by_label(engine, "Client")
  let standard_init = og_find_nodes_by_prop_str(engine, "tier", "standard")
  adv_assert_eq(tracker, clients_init.len(), 50, "C4.2: 50 Clients indexed")
  adv_assert_eq(tracker, standard_init.len(), 50, "C4.2: 50 standard tier indexed")

  @! Delete all 50 Service nodes. Each service node has 2 incoming edges.
  @! Deleting 50 service nodes must cascade-delete all 100 edges.
  let s_idx = 0
  @while s_idx < 50
    let del_ok = og_delete_node(engine, "srv_" + int_to_str(s_idx))
    adv_assert_true(tracker, del_ok, "C4.3: Service node deleted successfully")
    s_idx = s_idx + 1
  @end

  adv_assert_eq(tracker, engine.node_count, 50, "C4.4: 50 Client nodes remain")
  adv_assert_eq(tracker, engine.edge_count, 0, "C4.4: All 100 incident edges cascade-deleted")

  @! Verify Service label index is empty
  let services_after = og_find_nodes_by_label(engine, "Service")
  adv_assert_eq(tracker, services_after.len(), 0, "C4.5: Service label index purged")

  @! Verify backend tier prop index is empty
  let backend_after = og_find_nodes_by_prop_str(engine, "tier", "backend")
  adv_assert_eq(tracker, backend_after.len(), 0, "C4.6: Backend tier prop index purged")

  @! Verify Client nodes have 0 outgoing degree now
  let deg_cli_0 = og_get_degree(engine, "cli_0", "OUT")
  adv_assert_eq(tracker, deg_cli_0, 0, "C4.7: Client 0 outgoing degree is 0 after target services deleted")

  @! Re-insert srv_0 with new label "Gateway"
  og_add_node(engine, "srv_0", "Gateway")
  og_set_node_prop(engine, "srv_0", "tier", "edge", 0, false)
  og_add_edge(engine, "e_new_0", "cli_0", "srv_0", "ROUTES", 1)

  adv_assert_eq(tracker, engine.node_count, 51, "C4.8: Re-inserted node count 51")
  adv_assert_eq(tracker, engine.edge_count, 1, "C4.8: Re-inserted edge count 1")
  let gw_nodes = og_find_nodes_by_label(engine, "Gateway")
  adv_assert_eq(tracker, gw_nodes.len(), 1, "C4.9: Gateway label indexed")
@end

@! ============================================================================
@! Challenge 5: Extreme Repeated ACID Transaction Rollbacks
@! ============================================================================

@fn test_extreme_transaction_rollback_cycles(tracker: AdvTracker)
  println("\n--- Challenge 5: Extreme Repeated ACID Transaction Rollbacks ---")
  let engine = og_engine_new()

  @! Baseline: 5 stable nodes, 4 edges
  og_add_node(engine, "base_0", "Base")
  og_add_node(engine, "base_1", "Base")
  og_add_node(engine, "base_2", "Base")
  og_add_node(engine, "base_3", "Base")
  og_add_node(engine, "base_4", "Base")
  og_add_edge(engine, "be_0", "base_0", "base_1", "LINK", 1)
  og_add_edge(engine, "be_1", "base_1", "base_2", "LINK", 1)
  og_add_edge(engine, "be_2", "base_2", "base_3", "LINK", 1)
  og_add_edge(engine, "be_3", "base_3", "base_4", "LINK", 1)

  let baseline_snap = og_export_snapshot(engine)

  @! Run 10 transaction cycles that perform drastic mutations and rollback
  let cycle = 0
  @while cycle < 10
    let tx = og_begin_tx(engine)
    adv_assert_true(tracker, engine.in_tx, "C5.1: Transaction started cycle " + int_to_str(cycle))

    @! Mutate: add 20 temporary nodes and 19 edges
    let m = 0
    @while m < 20
      let t_id = "temp_" + int_to_str(cycle) + "_" + int_to_str(m)
      og_add_node(engine, t_id, "Temp")
      og_set_node_prop(engine, t_id, "tmp_key", "tmp_val", m, true)
      @if m > 0
        let prev_t = "temp_" + int_to_str(cycle) + "_" + int_to_str(m - 1)
        og_add_edge(engine, "te_" + int_to_str(cycle) + "_" + int_to_str(m), prev_t, t_id, "TEMP_EDGE", 5)
      @end
      m = m + 1
    @end

    @! Mutate: delete a base node
    og_delete_node(engine, "base_2")

    adv_assert_eq(tracker, engine.node_count, 24, "C5.2: In-tx node count 24 (4 base + 20 temp)")

    @! Rollback transaction
    let rb_ok = og_rollback_tx(engine)
    adv_assert_true(tracker, rb_ok, "C5.3: Rollback succeeded cycle " + int_to_str(cycle))
    adv_assert_false(tracker, engine.in_tx, "C5.4: Engine out of tx cycle " + int_to_str(cycle))

    @! Verify state strictly reverted
    adv_assert_eq(tracker, engine.node_count, 5, "C5.5: Restored node count is 5")
    adv_assert_eq(tracker, engine.edge_count, 4, "C5.5: Restored edge count is 4")

    let b2 = og_get_node(engine, "base_2")
    adv_assert_true(tracker, og_node_is_valid(b2), "C5.6: Deleted base_2 restored")

    let temp_ghost = og_get_node(engine, "temp_" + int_to_str(cycle) + "_0")
    adv_assert_false(tracker, og_node_is_valid(temp_ghost), "C5.7: Temp node gone after rollback")

    let temp_label_ghost = og_find_nodes_by_label(engine, "Temp")
    adv_assert_eq(tracker, temp_label_ghost.len(), 0, "C5.8: Temp label index clean after rollback")

    cycle = cycle + 1
  @end

  let final_snap = og_export_snapshot(engine)
  adv_assert_str_eq(tracker, final_snap, baseline_snap, "C5.9: Final snapshot matches initial baseline snapshot identically")
@end

@! ============================================================================
@! Challenge 6: Large Complex Snapshot Round-Trip Verification
@! ============================================================================

@fn test_large_snapshot_round_trip(tracker: AdvTracker)
  println("\n--- Challenge 6: Large Complex Snapshot Round-Trip ---")
  let engine1 = og_engine_new()

  let count = 50
  let i = 0
  @while i < count
    let nid = "complex_node_" + int_to_str(i)
    og_add_node(engine1, nid, "Entity")
    og_set_node_prop(engine1, nid, "name", "Alice_" + int_to_str(i), 0, false)
    og_set_node_prop(engine1, nid, "balance", "", i * 100, true)
    og_set_node_prop(engine1, nid, "status", "active", 0, false)
    i = i + 1
  @end

  let j = 0
  @while j < count - 1
    let eid = "complex_edge_" + int_to_str(j)
    let src = "complex_node_" + int_to_str(j)
    let tgt = "complex_node_" + int_to_str(j + 1)
    let dir = (j % 2 == 0)
    @if dir
      og_add_edge(engine1, eid, src, tgt, "TRANSFER", j + 1)
    @else
      og_add_edge_undirected(engine1, eid, src, tgt, "PEER", j + 1)
    @end
    og_set_edge_prop(engine1, eid, "tx_hash", "0x" + int_to_str(j * 999), 0, false)
    og_set_edge_prop(engine1, eid, "fee", "", j * 2, true)
    j = j + 1
  @end

  let snap1 = og_export_snapshot(engine1)
  adv_assert_true(tracker, str_len(snap1) > 1000, "C6.1: Exported snapshot > 1000 bytes")

  @! Import into fresh engine2
  let engine2 = og_import_snapshot(snap1)
  adv_assert_eq(tracker, engine2.node_count, 50, "C6.2: Imported engine2 has 50 nodes")
  adv_assert_eq(tracker, engine2.edge_count, 49, "C6.2: Imported engine2 has 49 edges")

  @! Verify properties on engine2
  let bal_25 = og_get_node_prop_num(engine2, "complex_node_25", "balance")
  adv_assert_eq(tracker, bal_25, 2500, "C6.3: Balance property accurate on imported node 25")

  let edge_prop = og_get_edge(engine2, "complex_edge_10")
  adv_assert_true(tracker, og_edge_is_valid(edge_prop), "C6.4: Edge 10 exists in imported engine")
  adv_assert_eq(tracker, edge_prop.weight, 11, "C6.4: Edge 10 weight matches")

  @! Verify shortest path behaves identically on both engines
  let path1 = og_dijkstra_shortest_path(engine1, "complex_node_0", "complex_node_10")
  let path2 = og_dijkstra_shortest_path(engine2, "complex_node_0", "complex_node_10")
  adv_assert_eq(tracker, path1.len(), path2.len(), "C6.5: Shortest path length identical on original and imported engines")
  adv_assert_str_eq(tracker, path1[5], path2[5], "C6.5: Shortest path node 5 identical")

  @! Export snapshot from engine2 and compare with snap1
  let snap2 = og_export_snapshot(engine2)
  adv_assert_str_eq(tracker, snap2, snap1, "C6.6: Re-exported snapshot matches original snapshot bit-for-bit")
@end

@! ============================================================================
@! Challenge 7: Raft Distributed Consensus Stress & Stale Term Rejection
@! ============================================================================

@fn test_raft_adversarial_consensus_stress(tracker: AdvTracker)
  println("\n--- Challenge 7: Raft Adversarial Consensus Stress ---")

  @! 1. Follower term and stale vote tests
  let follower = raft_node_new("follower_x", ["c1", "c2"])
  follower.term = 2

  @! RequestVote from stale candidate in Term 1 (must be rejected)
  let vote_stale = raft_request_vote(follower, 1, "stale_candidate", 0, 0)
  adv_assert_eq(tracker, vote_stale, 0, "C7.1: Stale term candidate rejected")

  @! RequestVote from candidate with shorter log index
  follower.log.push({ term: 2, index: 1, command_type: "ADD_NODE", payload: "a:A" })
  follower.log.push({ term: 2, index: 2, command_type: "ADD_NODE", payload: "b:B" })
  let vote_short_log = raft_request_vote(follower, 2, "short_candidate", 1, 2)
  adv_assert_eq(tracker, vote_short_log, 0, "C7.2: Candidate with shorter log index rejected by up-to-date follower")

  @! 2. 5-node Raft cluster simulation
  let n0 = raft_node_new("node_0", ["node_1", "node_2", "node_3", "node_4"])
  let n1 = raft_node_new("node_1", ["node_0", "node_2", "node_3", "node_4"])
  let n2 = raft_node_new("node_2", ["node_0", "node_1", "node_3", "node_4"])
  let n3 = raft_node_new("node_3", ["node_0", "node_1", "node_2", "node_4"])
  let n4 = raft_node_new("node_4", ["node_0", "node_1", "node_2", "node_3"])
  let cluster = [n0, n1, n2, n3, n4]

  let leader_id = raft_simulate_election(cluster)
  adv_assert_str_eq(tracker, leader_id, "node_0", "C7.3: 5-node cluster elects node_0 as leader")
  adv_assert_eq(tracker, n0.term, 1, "C7.3: Term is 1")

  @! 3. Large log replication: Replicate 30 commands from Leader n0
  let cmd_idx = 0
  @while cmd_idx < 30
    let nid = "raft_v_" + int_to_str(cmd_idx)
    let rep_ok = raft_replicate_command(n0, "ADD_NODE", nid + ":RaftVertex")
    adv_assert_true(tracker, rep_ok, "C7.4: Command " + int_to_str(cmd_idx) + " replicated to leader log")
    cmd_idx = cmd_idx + 1
  @end

  adv_assert_eq(tracker, n0.log.len(), 30, "C7.5: Leader log has 30 entries")
  adv_assert_eq(tracker, n0.commit_index, 30, "C7.5: Leader commit index is 30")

  @! 4. Replicate entries to followers n1, n2, n3, n4
  let c_idx = 1
  @while c_idx < cluster.len()
    let peer: RaftConsensusNode = cluster[c_idx]
    let app_res = raft_append_entries(peer, n0.term, n0.node_id, 0, 0, n0.log, n0.commit_index)
    adv_assert_eq(tracker, app_res, 1, "C7.6: Peer " + peer.node_id + " accepted leader log replication")
    adv_assert_eq(tracker, peer.log.len(), 30, "C7.6: Peer " + peer.node_id + " log length matches leader")
    adv_assert_eq(tracker, peer.commit_index, 30, "C7.6: Peer " + peer.node_id + " commit index matches leader")
    c_idx = c_idx + 1
  @end

  @! 5. Apply state machine to 5 separate ObjectGraphEngine instances
  let e0 = og_engine_new()
  let e1 = og_engine_new()
  let e2 = og_engine_new()
  let e3 = og_engine_new()
  let e4 = og_engine_new()

  let app0 = raft_apply_to_graph(n0, e0)
  let app1 = raft_apply_to_graph(n1, e1)
  let app2 = raft_apply_to_graph(n2, e2)
  let app3 = raft_apply_to_graph(n3, e3)
  let app4 = raft_apply_to_graph(n4, e4)

  adv_assert_eq(tracker, app0, 30, "C7.7: Applied 30 entries to e0")
  adv_assert_eq(tracker, app1, 30, "C7.7: Applied 30 entries to e1")
  adv_assert_eq(tracker, app2, 30, "C7.7: Applied 30 entries to e2")
  adv_assert_eq(tracker, app3, 30, "C7.7: Applied 30 entries to e3")
  adv_assert_eq(tracker, app4, 30, "C7.7: Applied 30 entries to e4")

  adv_assert_eq(tracker, e0.node_count, 30, "C7.8: e0 node count is 30")
  adv_assert_eq(tracker, e1.node_count, 30, "C7.8: e1 node count is 30")
  adv_assert_eq(tracker, e2.node_count, 30, "C7.8: e2 node count is 30")
  adv_assert_eq(tracker, e3.node_count, 30, "C7.8: e3 node count is 30")
  adv_assert_eq(tracker, e4.node_count, 30, "C7.8: e4 node count is 30")

  let snap_e0 = og_export_snapshot(e0)
  let snap_e1 = og_export_snapshot(e1)
  let snap_e4 = og_export_snapshot(e4)
  adv_assert_str_eq(tracker, snap_e1, snap_e0, "C7.9: State machine snapshot e1 matches leader e0 identically")
  adv_assert_str_eq(tracker, snap_e4, snap_e0, "C7.9: State machine snapshot e4 matches leader e0 identically")
@end

@! ============================================================================
@! Challenge 8: Subgraph Extraction & Pattern Matching Stress
@! ============================================================================

@fn test_subgraph_and_pattern_matching_stress(tracker: AdvTracker)
  println("\n--- Challenge 8: Subgraph & Pattern Matching Stress ---")
  let engine = og_engine_new()

  @! Create author -> book -> genre network
  let a_idx = 0
  @while a_idx < 10
    let aid = "author_" + int_to_str(a_idx)
    og_add_node(engine, aid, "Author")
    og_set_node_prop(engine, aid, "rating", "", (a_idx + 1) * 10, true)

    let b_idx = 0
    @while b_idx < 3
      let bid = "book_" + int_to_str(a_idx) + "_" + int_to_str(b_idx)
      og_add_node(engine, bid, "Book")
      og_set_node_prop(engine, bid, "pages", "", 100 + b_idx * 50, true)

      og_add_edge(engine, "wrote_" + aid + "_" + bid, aid, bid, "WROTE", 1)
      b_idx = b_idx + 1
    @end
    a_idx = a_idx + 1
  @end

  adv_assert_eq(tracker, engine.node_count, 40, "C8.1: 10 Authors + 30 Books = 40 nodes")
  adv_assert_eq(tracker, engine.edge_count, 30, "C8.1: 30 WROTE edges")

  @! Pattern query: find all (Author)-[WROTE]->(Book)
  let pat_all = {
    src_label: "Author",
    edge_label: "WROTE",
    tgt_label: "Book",
    src_prop_key: "",
    src_prop_val: "",
    tgt_prop_key: "",
    tgt_prop_val: "",
    min_weight: 0
  }
  let matches_all = og_match_pattern(engine, pat_all)
  adv_assert_eq(tracker, matches_all.len(), 30, "C8.2: Pattern matcher found all 30 WROTE relations")

  @! Subgraph extraction of author_0 and its 3 books
  let sub_nodes = ["author_0", "book_0_0", "book_0_1", "book_0_2"]
  let sub = og_extract_subgraph(engine, sub_nodes)
  adv_assert_eq(tracker, sub.node_count, 4, "C8.3: Subgraph contains 4 nodes")
  adv_assert_eq(tracker, sub.edge_count, 3, "C8.3: Subgraph contains 3 edges")

  let author_0_out = og_get_out_edges(sub, "author_0")
  adv_assert_eq(tracker, author_0_out.len(), 3, "C8.4: Subgraph author_0 has 3 outgoing edges")
@end

@! ============================================================================
@! Challenge 9: Property Type Flapping & Index Leak Verification
@! ============================================================================

@fn test_property_type_flapping_stress(tracker: AdvTracker)
  println("\n--- Challenge 9: Property Type Flapping Stress ---")
  let engine = og_engine_new()
  og_add_node(engine, "flap_node", "Flapper")

  let iter = 0
  @while iter < 50
    @! Set string
    og_set_node_prop(engine, "flap_node", "dynamic_key", "str_val_" + int_to_str(iter), 0, false)
    let s_match = og_find_nodes_by_prop_str(engine, "dynamic_key", "str_val_" + int_to_str(iter))
    adv_assert_eq(tracker, s_match.len(), 1, "C9.1: String prop indexed iter " + int_to_str(iter))

    @! Set numeric
    og_set_node_prop(engine, "flap_node", "dynamic_key", "", iter * 10, true)
    let n_match = og_find_nodes_by_prop_num(engine, "dynamic_key", iter * 10)
    adv_assert_eq(tracker, n_match.len(), 1, "C9.2: Numeric prop indexed iter " + int_to_str(iter))

    @! Previous string index must be cleared
    let s_old = og_find_nodes_by_prop_str(engine, "dynamic_key", "str_val_" + int_to_str(iter))
    adv_assert_eq(tracker, s_old.len(), 0, "C9.3: Previous string index pruned iter " + int_to_str(iter))

    iter = iter + 1
  @end

  let final_val_num = og_get_node_prop_num(engine, "flap_node", "dynamic_key")
  adv_assert_eq(tracker, final_val_num, 490, "C9.4: Final numeric value is 490")
@end

@! ============================================================================
@! Challenge 10: Snapshot Boundary & Malformed Input Handling
@! ============================================================================

@fn test_snapshot_malformed_and_empty_inputs(tracker: AdvTracker)
  println("\n--- Challenge 10: Snapshot Malformed & Boundary Inputs ---")

  @! 1. Empty string
  let e_empty = og_import_snapshot("")
  adv_assert_eq(tracker, e_empty.node_count, 0, "C10.1: Empty snapshot string returns empty engine")

  @! 2. Truncated snapshot header
  let e_trunc = og_import_snapshot("OG_SNAPSHOT_V1|NODES")
  adv_assert_eq(tracker, e_trunc.node_count, 0, "C10.2: Truncated snapshot returns empty engine without crash")

  @! 3. Snapshot with 0 nodes and 0 edges
  let empty_snap = "OG_SNAPSHOT_V1|NODES:|EDGES:"
  let e_zero = og_import_snapshot(empty_snap)
  adv_assert_eq(tracker, e_zero.node_count, 0, "C10.3: Zero-entity snapshot imported cleanly")
  adv_assert_eq(tracker, e_zero.edge_count, 0, "C10.3: Zero edges imported cleanly")

  @! 4. Snapshot with properties containing empty values
  let engine_props = og_engine_new()
  og_add_node(engine_props, "n_empty_val", "Test")
  og_set_node_prop(engine_props, "n_empty_val", "empty_str_key", "EMPTY_TEST", 0, false)
  let snap_props = og_export_snapshot(engine_props)
  let imported_props = og_import_snapshot(snap_props)
  let val_read = og_get_node_prop_str(imported_props, "n_empty_val", "empty_str_key")
  adv_assert_str_eq(tracker, val_read, "EMPTY_TEST", "C10.4: String prop accurately preserved through round-trip")
@end

@! ============================================================================
@! Challenge 11: Raft Uncommitted Log Overwrite Across Terms
@! ============================================================================

@fn test_raft_uncommitted_log_conflict_overwriting(tracker: AdvTracker)
  println("\n--- Challenge 11: Raft Uncommitted Log Conflict Overwrite ---")

  @! Follower has stale uncommitted entries at indices 2 and 3 from term 1
  let follower = raft_node_new("f1", ["leader"])
  follower.term = 1
  follower.log.push({ term: 1, index: 1, command_type: "ADD_NODE", payload: "v1:Vertex" })
  follower.log.push({ term: 1, index: 2, command_type: "ADD_NODE", payload: "stale_v2:Vertex" })
  follower.log.push({ term: 1, index: 3, command_type: "ADD_NODE", payload: "stale_v3:Vertex" })
  follower.commit_index = 1

  @! New Leader elected at term 2 with new authoritative entries for indices 2, 3, 4
  let leader_entries = [
    { term: 2, index: 2, command_type: "ADD_NODE", payload: "good_v2:Vertex" },
    { term: 2, index: 3, command_type: "ADD_NODE", payload: "good_v3:Vertex" },
    { term: 2, index: 4, command_type: "ADD_EDGE", payload: "e_v1_v2:v1:good_v2:LINK:1" }
  ]

  @! AppendEntries from Term 2 Leader with prev_log_idx=1, prev_log_term=1, leader_commit=4
  let app_res = raft_append_entries(follower, 2, "leader", 1, 1, leader_entries, 4)
  adv_assert_eq(tracker, app_res, 1, "C11.1: Follower accepted Term 2 AppendEntries")
  adv_assert_eq(tracker, follower.term, 2, "C11.2: Follower updated term to 2")
  adv_assert_eq(tracker, follower.log.len(), 4, "C11.3: Follower log length is 4")
  adv_assert_eq(tracker, follower.commit_index, 4, "C11.4: Follower commit index is 4")

  let entry2: RaftLogEntry = follower.log[1]
  let entry3: RaftLogEntry = follower.log[2]
  adv_assert_str_eq(tracker, entry2.payload, "good_v2:Vertex", "C11.5: Stale entry 2 overwritten by term 2 entry")
  adv_assert_str_eq(tracker, entry3.payload, "good_v3:Vertex", "C11.6: Stale entry 3 overwritten by term 2 entry")

  @! Apply follower's log to state machine
  let eng = og_engine_new()
  let applied = raft_apply_to_graph(follower, eng)
  adv_assert_eq(tracker, applied, 4, "C11.7: Applied all 4 reconciled entries")
  adv_assert_eq(tracker, eng.node_count, 3, "C11.8: Engine has 3 nodes (v1, good_v2, good_v3)")
  adv_assert_eq(tracker, eng.edge_count, 1, "C11.8: Engine has 1 edge")

  let stale_check = og_get_node(eng, "stale_v2")
  adv_assert_false(tracker, og_node_is_valid(stale_check), "C11.9: Stale node not present in state machine")
@end

@! ============================================================================
@! Main Adversarial Runner
@! ============================================================================

@fn main()
  println("=================================================================")
  println("⚔️  MAYA OBJECT-GRAPH DB ADVERSARIAL CHALLENGER 1 STRESS SUITE")
  println("=================================================================")

  let tracker = adv_tracker_new()

  test_deep_150_node_linear_chain(tracker)
  test_grid_mesh_and_competing_dijkstra_paths(tracker)
  test_complex_multi_cycles_and_self_loops(tracker)
  test_massive_cascaded_deletions_and_index_integrity(tracker)
  test_extreme_transaction_rollback_cycles(tracker)
  test_large_snapshot_round_trip(tracker)
  test_raft_adversarial_consensus_stress(tracker)
  test_subgraph_and_pattern_matching_stress(tracker)
  test_property_type_flapping_stress(tracker)
  test_snapshot_malformed_and_empty_inputs(tracker)
  test_raft_uncommitted_log_conflict_overwriting(tracker)

  println("\n=================================================================")
  println("📊 ADVERSARIAL TEST SUMMARY: " + int_to_str(tracker.passed) + " / " + int_to_str(tracker.total) + " PASSED (" + int_to_str(tracker.failed) + " FAILED)")
  println("=================================================================")

  @if tracker.failed > 0
    return 1
  @end
  return 0
@end
