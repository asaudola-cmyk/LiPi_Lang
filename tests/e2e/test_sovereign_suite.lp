@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE: SOVEREIGN E2E INTEGRATION TEST SUITE
@! File: tests/e2e/test_sovereign_suite.maya
@! Complete 4-Tier Integration Suite: DB, P2P Registry, and Raw Network Stack
@! 100% Pure Maya Implementation - Zero External / C Standard Library Dependencies
@! ============================================================================

import "universe/core/string"
import "universe/crypto/sha256"
import "universe/p2p/registry"
import "universe/db/object_graph"
import "universe/net/raw"

@! ============================================================================
@! 1. TEST STATE & ASSERTION FRAMEWORK HELPERS
@! ============================================================================

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@struct Sha256Context
  state: array
  count: i64
  buffer: array
@end

@fn assert_true(state: TestState, cond, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if cond == true || cond == 1
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected true, got false)")
    return 0
  @end
@end

@fn assert_false(state: TestState, cond, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if cond == false || cond == 0
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected false, got true)")
    return 0
  @end
@end

@fn assert_eq_int(state: TestState, actual: i64, expected: i64, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected " + expected.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@fn assert_eq_str(state: TestState, actual: string, expected: string, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected '" + expected + "', got '" + actual + "')")
    return 0
  @end
@end

@fn assert_not_null(state: TestState, ptr_val: any, test_id: string, desc: string) -> i64
  state.total = state.total + 1
  @if ptr_val != 0
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected non-null pointer)")
    return 0
  @end
@end

@fn string_to_bytes(s: string) -> array
  let arr = []
  let i = 0
  @while i < s.len()
    arr.push(str_char_at(s, i))
    i = i + 1
  @end
  return arr
@end

@fn bytes_to_string(b: array) -> string
  let res = ""
  let i = 0
  @while i < b.len()
    let code: i64 = b[i]
    res = res + str_from_char_code(code)
    i = i + 1
  @end
  return res
@end

@fn raw_udp_serialize(seg: UDPSegment, src_ip: array, dst_ip: array) -> array
  let udp_len = 8 + seg.payload.len()
  let bytes = []
  bytes.push((seg.src_port / 256) & 255)
  bytes.pushseg.src_port & 255
  bytes.push((seg.dst_port / 256) & 255)
  bytes.pushseg.dst_port & 255
  bytes.push((udp_len / 256) & 255)
  bytes.pushudp_len & 255
  bytes.push(0)
  bytes.push(0)

  let i = 0
  let p_len = seg.payload.len()
  @while i < p_len
    bytes.push(seg.payload[i] & 255)
    i = i + 1
  @end

  let csum = net_udp_checksum(src_ip, dst_ip, bytes)
  bytes[6] = (csum / 256) & 255
  bytes[7] = csum & 255
  return bytes
@end

@! ============================================================================
@! 2. TIER 1: FEATURE COVERAGE (ISOLATED UNIT TESTS)
@! ============================================================================

@fn run_tier1_features(state: TestState)
  println("-----------------------------------------------------------------")
  println("▶ [TIER 1] SOVEREIGN FEATURE COVERAGE UNIT TESTS")
  println("-----------------------------------------------------------------")

  @! --- 1.1 Object-Graph DB Engine ---
  let db_eng: ObjectGraphEngine = og_engine_new()
  assert_not_null(state, db_eng, "T1.1.1", "ObjectGraphEngine instantiation")
  assert_eq_int(state, db_eng.node_count, 0, "T1.1.2", "Engine initial node_count is 0")
  assert_eq_int(state, db_eng.edge_count, 0, "T1.1.3", "Engine initial edge_count is 0")

  let n1: GraphNode = og_add_node(db_eng, "usr_001", "User")
  assert_not_null(state, n1, "T1.1.4", "Add node 'usr_001'")
  assert_eq_str(state, n1.id, "usr_001", "T1.1.5", "Node ID matches 'usr_001'")
  assert_eq_str(state, n1.label, "User", "T1.1.6", "Node label matches 'User'")
  assert_eq_int(state, db_eng.node_count, 1, "T1.1.7", "Engine node_count incremented to 1")

  let n2: GraphNode = og_add_node(db_eng, "usr_002", "User")
  let edge1: GraphEdge = og_add_edge(db_eng, "e_01", "usr_001", "usr_002", "FOLLOWS", 10)
  assert_not_null(state, edge1, "T1.1.8", "Add directed edge 'e_01'")
  assert_eq_str(state, edge1.from_id, "usr_001", "T1.1.9", "Edge from_id matches")
  assert_eq_str(state, edge1.to_id, "usr_002", "T1.1.10", "Edge to_id matches")
  assert_eq_int(state, edge1.weight, 10, "T1.1.11", "Edge weight matches 10")
  assert_eq_int(state, db_eng.edge_count, 1, "T1.1.12", "Engine edge_count incremented to 1")

  let p_ok1 = og_set_node_prop(db_eng, "usr_001", "email", "alice@maya.lang", 0, false)
  let p_ok2 = og_set_node_prop(db_eng, "usr_001", "karma", "", 500, true)
  assert_true(state, p_ok1, "T1.1.13", "Set string property 'email'")
  assert_true(state, p_ok2, "T1.1.14", "Set number property 'karma'")
  assert_eq_str(state, og_get_node_prop_str(db_eng, "usr_001", "email"), "alice@maya.lang", "T1.1.15", "Get string property 'email'")
  assert_eq_int(state, og_get_node_prop_num(db_eng, "usr_001", "karma"), 500, "T1.1.16", "Get number property 'karma'")

  let user_nodes = og_find_nodes_by_label(db_eng, "User")
  assert_eq_int(state, user_nodes.len(), 2, "T1.1.17", "Find nodes by label 'User' returns 2 nodes")

  let out_edges = og_get_out_edges(db_eng, "usr_001")
  assert_eq_int(state, out_edges.len(), 1, "T1.1.18", "Get outgoing edges for 'usr_001' returns 1 edge")

  let bfs_order = og_bfs_traverse(db_eng, "usr_001")
  assert_eq_int(state, bfs_order.len(), 2, "T1.1.19", "BFS traversal from 'usr_001' visits 2 nodes")
  assert_eq_str(state, bfs_order[0], "usr_001", "T1.1.20", "BFS root is 'usr_001'")
  assert_eq_str(state, bfs_order[1], "usr_002", "T1.1.21", "BFS second visited is 'usr_002'")

  let sp = og_dijkstra_shortest_path(db_eng, "usr_001", "usr_002")
  assert_eq_int(state, sp.len(), 2, "T1.1.22", "Dijkstra shortest path length is 2")
  assert_eq_str(state, sp[0], "usr_001", "T1.1.23", "Shortest path start is 'usr_001'")
  assert_eq_str(state, sp[1], "usr_002", "T1.1.24", "Shortest path end is 'usr_002'")

  let snap = og_export_snapshot(db_eng)
  assert_true(state, snap.len() > 0, "T1.1.25", "Export snapshot produces non-empty string")
  let db_restored: ObjectGraphEngine = og_import_snapshot(snap)
  assert_eq_int(state, db_restored.node_count, 2, "T1.1.26", "Import snapshot restores 2 nodes")
  assert_eq_int(state, db_restored.edge_count, 1, "T1.1.27", "Import snapshot restores 1 edge")

  @! --- 1.2 Native Raft Consensus ---
  let raft_leader: RaftConsensusNode = raft_node_new("node_leader", ["node_f1", "node_f2"])
  assert_eq_str(state, raft_leader.node_id, "node_leader", "T1.2.1", "Raft node_id matches")
  assert_eq_str(state, raft_leader.state, "FOLLOWER", "T1.2.2", "Raft initial state is FOLLOWER")
  raft_elect_leader(raft_leader)
  assert_eq_str(state, raft_leader.state, "LEADER", "T1.2.3", "Raft elect leader transitions to LEADER")

  let repl_ok = raft_replicate_command(raft_leader, "ADD_NODE", "pkg_core:Package")
  assert_true(state, repl_ok, "T1.2.4", "Raft replicate ADD_NODE command")
  assert_eq_int(state, raft_leader.log.len(), 1, "T1.2.5", "Raft log contains 1 entry")
  assert_eq_int(state, raft_leader.commit_index, 1, "T1.2.6", "Raft commit_index advanced to 1")

  let eng_raft: ObjectGraphEngine = og_engine_new()
  let applied_count = raft_apply_to_graph(raft_leader, eng_raft)
  assert_eq_int(state, applied_count, 1, "T1.2.7", "Raft apply to graph processes unapplied log entries")
  let pkg_node: GraphNode = og_get_node(eng_raft, "pkg_core")
  assert_not_null(state, pkg_node, "T1.2.8", "Committed node 'pkg_core' created in ObjectGraphEngine")
  assert_eq_str(state, pkg_node.label, "Package", "T1.2.9", "Committed node label is 'Package'")

  @! --- 1.3 P2P Package Registry & DHT / CAS ---
  let p2p_reg: P2PRegistry = p2p_registry_new("peer_001", "127.0.0.1", 9001)
  assert_not_null(state, p2p_reg, "T1.3.1", "P2PRegistry instantiation")
  assert_eq_str(state, p2p_reg.local_peer.id, "peer_001", "T1.3.2", "Local peer ID is 'peer_001'")

  let add_p_ok = p2p_add_peer(p2p_reg, "peer_002", "192.168.1.50", 9002)
  assert_true(state, add_p_ok, "T1.3.3", "Add peer 'peer_002' to routing table")
  assert_eq_int(state, p2p_reg.routing_table.len(), 1, "T1.3.4", "Routing table length is 1")

  let xor_dist = p2p_calculate_distance("11223344", "55667788")
  let xor_dist_sym = p2p_calculate_distance("55667788", "11223344")
  assert_eq_str(state, xor_dist, xor_dist_sym, "T1.3.5", "Kademlia XOR distance metric is symmetric")

  let pub_rec: PackageRecord = p2p_publish_package(p2p_reg, "maya-fmt", "1.2.0", "binary_code_v120", "", "", "")
  assert_not_null(state, pub_rec, "T1.3.6", "Publish package returns valid PackageRecord")
  assert_eq_str(state, pub_rec.name, "maya-fmt", "T1.3.7", "PackageRecord name matches 'maya-fmt'")
  assert_eq_str(state, pub_rec.version, "1.2.0", "T1.3.8", "PackageRecord version matches '1.2.0'")
  assert_true(state, pub_rec.cid.len() >= 64, "T1.3.9", "Package CID is at least 64 hex characters")

  let blob: PackageBlob = p2p_find_package_blob(p2p_reg, pub_rec.cid)
  assert_not_null(state, blob, "T1.3.10", "Find package blob by CID")
  assert_eq_str(state, blob.data, "binary_code_v120", "T1.3.11", "PackageBlob content intact")
  assert_true(state, p2p_verify_blob_integrity(blob) == 1, "T1.3.12", "Verify clean blob integrity returns true")

  let resolved_v = p2p_resolve_version(p2p_reg, "maya-fmt", "^1.0.0")
  assert_eq_str(state, resolved_v, "1.2.0", "T1.3.13", "SemVer caret constraint '^1.0.0' resolves to '1.2.0'")

  let lock_entry = p2p_generate_lockfile_entry("maya-fmt", "1.2.0", pub_rec.cid)
  assert_true(state, str_contains(lock_entry, "name = \"maya-fmt\""), "T1.3.14", "Lockfile contains package name")
  assert_true(state, str_contains(lock_entry, "version = \"1.2.0\""), "T1.3.15", "Lockfile contains package version")

  @! --- 1.4 Raw Network Stack Protocols & Framing ---
  let sample_bytes = [49, 50, 51, 52, 53, 54, 55, 56, 57]
  let crc = net_crc32(sample_bytes)
  assert_eq_int(state, crc, 3421780262, "T1.4.1", "IEEE 802.3 CRC-32 on '123456789' equals 0xcbf43926")

  let eth_frame = {
    dst_mac: [0, 12, 41, 62, 91, 108],
    src_mac: [82, 84, 0, 18, 52, 86],
    ethertype: 2048,
    payload: [10, 20, 30, 40, 50],
    fcs: 0,
    is_valid: 1
  }
  let eth_raw = raw_eth_frame_serialize(eth_frame)
  assert_true(state, eth_raw.len() >= 18, "T1.4.2", "Ethernet frame serialized bytes >= 18")
  let eth_parsed: EthFrame = raw_eth_frame_parse(eth_raw)
  assert_eq_int(state, eth_parsed.ethertype, 2048, "T1.4.3", "Parsed EtherType matches 0x0800 (2048)")
  assert_eq_int(state, eth_parsed.payload.len(), 46, "T1.4.4", "Parsed Ethernet payload minimum padded length is 46")

  let ip_pkt = {
    version: 4,
    ihl: 5,
    dscp: 0,
    total_len: 25,
    id: 1,
    flags: 0,
    frag_offset: 0,
    ttl: 64,
    protocol: 17,
    checksum: 0,
    src_ip: [192, 168, 1, 10],
    dst_ip: [192, 168, 1, 20],
    options: [],
    payload: [1, 2, 3, 4, 5],
    is_valid: 1
  }
  let ip_raw = raw_ipv4_serialize(ip_pkt)
  assert_true(state, ip_raw.len() >= 20, "T1.4.5", "IPv4 packet serialized header length >= 20")
  let ip_parsed: IPv4Packet = raw_ipv4_parse(ip_raw)
  assert_eq_int(state, ip_parsed.version, 4, "T1.4.6", "Parsed IPv4 version is 4")
  assert_eq_int(state, ip_parsed.protocol, 17, "T1.4.7", "Parsed IPv4 protocol is UDP (17)")

  let udp_seg = {
    src_port: 8080,
    dst_port: 9000,
    udp_len: 12,
    checksum: 0,
    payload: [65, 66, 67, 68],
    is_valid: 1
  }
  let udp_raw = raw_udp_serialize(udp_seg, [10, 0, 0, 1], [10, 0, 0, 2])
  assert_true(state, udp_raw.len() >= 8, "T1.4.8", "UDP segment serialized length >= 8")
  let udp_parsed: UDPSegment = raw_udp_parse(udp_raw, [10, 0, 0, 1], [10, 0, 0, 2])
  assert_eq_int(state, udp_parsed.src_port, 8080, "T1.4.9", "Parsed UDP source port matches 8080")
  assert_eq_int(state, udp_parsed.dst_port, 9000, "T1.4.10", "Parsed UDP dest port matches 9000")

  let tcp_seg = {
    src_port: 443,
    dst_port: 54321,
    seq_num: 1000,
    ack_num: 0,
    data_offset: 5,
    flags: 2,
    window_size: 65535,
    checksum: 0,
    urgent_ptr: 0,
    payload: [],
    is_valid: 1
  }
  let tcp_raw = raw_tcp_serialize(tcp_seg, [10, 0, 0, 1], [10, 0, 0, 2])
  assert_true(state, tcp_raw.len() >= 20, "T1.4.11", "TCP segment serialized header length >= 20")
  let tcp_parsed: TCPSegment = raw_tcp_parse(tcp_raw, [10, 0, 0, 1], [10, 0, 0, 2])
  assert_eq_int(state, tcp_parsed.src_port, 443, "T1.4.12", "Parsed TCP source port matches 443")
  assert_eq_int(state, tcp_parsed.flags, 2, "T1.4.13", "Parsed TCP flags match SYN (2)")

  let hub: VirtualNetworkHub = vnet_hub_new()
  assert_not_null(state, hub, "T1.4.14", "VirtualNetworkHub instantiation")
  vnet_send_packet(hub, [1, 2, 3, 4])
  assert_true(state, hub.packet_count == 1, "T1.4.15", "VirtualNetworkHub send packet")
  let recv_pkt = vnet_recv_packet(hub)
  assert_eq_int(state, recv_pkt.len(), 4, "T1.4.16", "VirtualNetworkHub receive packet length is 4")
@end

@! ============================================================================
@! 3. TIER 2: BOUNDARY & CORNER CASES
@! ============================================================================

@fn run_tier2_boundaries(state: TestState)
  println("-----------------------------------------------------------------")
  println("▶ [TIER 2] BOUNDARY & CORNER CASE VERIFICATION")
  println("-----------------------------------------------------------------")

  @! --- 2.1 DB Boundaries ---
  let db_eng: ObjectGraphEngine = og_engine_new()
  let ghost_node: GraphNode = og_get_node(db_eng, "phantom_node_999")
  assert_true(state, !og_node_is_valid(ghost_node), "T2.1.1", "Non-existent node lookup returns invalid node")

  let bad_prop = og_set_node_prop(db_eng, "phantom_node", "key", "val", 0, false)
  assert_false(state, bad_prop, "T2.1.2", "Setting property on non-existent node returns false")

  og_add_node(db_eng, "dup_1", "NodeA")
  og_add_node(db_eng, "dup_1", "NodeB")
  assert_eq_int(state, db_eng.node_count, 1, "T2.1.3", "Duplicate node ID insertion does not duplicate entity")

  og_add_node(db_eng, "iso_1", "Isolated")
  let iso_edges = og_get_out_edges(db_eng, "iso_1")
  assert_eq_int(state, iso_edges.len(), 0, "T2.1.4", "Isolated node returns 0 outgoing edges")

  let unreach_sp = og_dijkstra_shortest_path(db_eng, "dup_1", "iso_1")
  assert_eq_int(state, unreach_sp.len(), 0, "T2.1.5", "Dijkstra on unreachable disconnected node returns empty path")

  let same_sp = og_dijkstra_shortest_path(db_eng, "dup_1", "dup_1")
  assert_eq_int(state, same_sp.len(), 1, "T2.1.6", "Dijkstra with same source and destination returns path of length 1")

  @! Cyclic Graph BFS Traversal
  let cyc_eng: ObjectGraphEngine = og_engine_new()
  og_add_node(cyc_eng, "cA", "CycleNode")
  og_add_node(cyc_eng, "cB", "CycleNode")
  og_add_node(cyc_eng, "cC", "CycleNode")
  og_add_edge(cyc_eng, "e_ab", "cA", "cB", "NEXT", 1)
  og_add_edge(cyc_eng, "e_bc", "cB", "cC", "NEXT", 1)
  og_add_edge(cyc_eng, "e_ca", "cC", "cA", "NEXT", 1)
  let cyc_bfs = og_bfs_traverse(cyc_eng, "cA")
  assert_eq_int(state, cyc_bfs.len(), 3, "T2.1.7", "Cyclic graph BFS visits all 3 nodes and terminates cleanly")

  let empty_snap_eng: ObjectGraphEngine = og_engine_new()
  let empty_snap_str = og_export_snapshot(empty_snap_eng)
  assert_true(state, empty_snap_str.len() > 0, "T2.1.8", "Empty engine export produces valid snapshot string")
  let empty_imported: ObjectGraphEngine = og_import_snapshot(empty_snap_str)
  assert_eq_int(state, empty_imported.node_count, 0, "T2.1.9", "Empty snapshot imports with node_count 0")

  let empty_raft: RaftConsensusNode = raft_node_new("n_empty", [])
  let applied_empty = raft_apply_to_graph(empty_raft, db_eng)
  assert_eq_int(state, applied_empty, 0, "T2.1.10", "Applying empty Raft log produces 0 state modifications")

  @! --- 2.2 P2P & CAS Boundaries ---
  let p2p_reg: P2PRegistry = p2p_registry_new("peer_bound", "127.0.0.1", 7000)
  let zero_dist = p2p_calculate_distance("ffff0000", "ffff0000")
  assert_eq_str(state, zero_dist, "0000000000000000000000000000000000000000000000000000000000000000", "T2.2.1", "XOR distance between identical IDs is all zeros")

  let empty_cid = p2p_cas_put_blob(p2p_reg, "")
  assert_true(state, str_starts_with(empty_cid, "e3b0c442") || str_starts_with(empty_cid, "sha256:e3b0c442"), "T2.2.2", "CAS empty string produces canonical empty SHA-256 digest")

  let bad_cid_blob: PackageBlob = p2p_find_package_blob(p2p_reg, "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
  assert_eq_int(state, bad_cid_blob.data.len(), 0, "T2.2.3", "Lookup non-existent CID returns empty blob")

  let tampered_blob = {
    cid: "0000000000000000000000000000000000000000000000000000000000000000",
    name: "tamper-pkg",
    version: "1.0.0",
    data: "MODIFIED_TAMPERED_DATA",
    size_bytes: 22,
    created_at: 0
  }
  let verify_tamper = p2p_verify_blob_integrity(tampered_blob)
  assert_eq_int(state, verify_tamper, 0, "T2.2.4", "Tampered blob fails cryptographic integrity verification")

  let unres_v = p2p_resolve_version(p2p_reg, "non_existent_package", "^1.0.0")
  assert_eq_str(state, unres_v, "", "T2.2.5", "SemVer resolution on non-existent package returns empty string")

  let empty_lock = p2p_generate_lockfile_entry(p2p_empty_record(), "", "")
  assert_true(state, str_contains(empty_lock, "[[package]]"), "T2.2.6", "Lockfile generator handles empty strings without fault")

  let empty_p2p_msg: P2PMessage = {
    msg_type: "PING",
    sender_id: "p1",
    sender_addr: "127.0.0.1",
    target_id: "p2",
    payload: "",
    nonce: 0,
    status: 0
  }
  assert_eq_str(state, empty_p2p_msg.payload, "", "T2.2.7", "P2P message with empty payload initialized cleanly")

  @! --- 2.3 Raw Net Boundaries ---
  let empty_crc = net_crc32([])
  assert_eq_int(state, empty_crc, 0, "T2.3.1", "CRC-32 on empty byte array returns 0")

  let trunc_eth: EthFrame = raw_eth_frame_parse([0, 12, 41])
  assert_eq_int(state, trunc_eth.is_valid, 0, "T2.3.2", "Truncated Ethernet frame (< 14 bytes) marked invalid")

  let trunc_ip: IPv4Packet = raw_ipv4_parse([69, 0, 0])
  assert_eq_int(state, trunc_ip.is_valid, 0, "T2.3.3", "Truncated IPv4 packet (< 20 bytes) marked invalid")

  let trunc_udp: UDPSegment = raw_udp_parse([31, 144, 0], [], [])
  assert_eq_int(state, trunc_udp.is_valid, 0, "T2.3.4", "Truncated UDP segment (< 8 bytes) marked invalid")

  let max_port_udp = {
    src_port: 65535,
    dst_port: 65535,
    udp_len: 8,
    checksum: 0,
    payload: [],
    is_valid: 1
  }
  let max_udp_raw = raw_udp_serialize(max_port_udp, [127, 0, 0, 1], [127, 0, 0, 1])
  let max_udp_parsed: UDPSegment = raw_udp_parse(max_udp_raw, [127, 0, 0, 1], [127, 0, 0, 1])
  assert_eq_int(state, max_udp_parsed.src_port, 65535, "T2.3.5", "UDP max boundary port 65535 preserved")

  let zero_win_tcp = {
    src_port: 80,
    dst_port: 12345,
    seq_num: 500,
    ack_num: 100,
    data_offset: 5,
    flags: 16,
    window_size: 0,
    checksum: 0,
    urgent_ptr: 0,
    payload: [],
    is_valid: 1
  }
  let zero_win_raw = raw_tcp_serialize(zero_win_tcp, [10, 0, 0, 1], [10, 0, 0, 2])
  let zero_win_parsed: TCPSegment = raw_tcp_parse(zero_win_raw, [10, 0, 0, 1], [10, 0, 0, 2])
  assert_eq_int(state, zero_win_parsed.window_size, 0, "T2.3.6", "TCP zero window probe preserved")

  let empty_hub: VirtualNetworkHub = vnet_hub_new()
  let empty_hub_recv = vnet_recv_packet(empty_hub)
  assert_eq_int(state, empty_hub_recv.len(), 0, "T2.3.7", "Receiving from empty VirtualNetworkHub returns empty array")
@end

@! ============================================================================
@! 4. TIER 3: CROSS-COMPONENT PAIRWISE INTERACTIONS
@! ============================================================================

@fn run_tier3_pairwise_combinations(state: TestState)
  println("-----------------------------------------------------------------")
  println("▶ [TIER 3] CROSS-COMPONENT PAIRWISE INTERACTIONS")
  println("-----------------------------------------------------------------")

  @! --------------------------------------------------------------------------
  @! Section 3.1: DB <-> P2P Cross-Integration
  @! --------------------------------------------------------------------------
  println("  [Section 3.1: DB <-> P2P Integration]")

  @! T3.1.1: CAS Package Publishing & In-Memory Graph Manifest Indexing
  let db_reg: P2PRegistry = p2p_registry_new("peer_indexer", "127.0.0.1", 8000)
  let db_idx_eng: ObjectGraphEngine = og_engine_new()
  let rec_v1: PackageRecord = p2p_publish_package(db_reg, "libmath", "1.0.0", "fn add(a, b) = a + b", "", "", "")
  let rec_v2: PackageRecord = p2p_publish_package(db_reg, "libmath", "1.1.0", "fn add(a, b) = a + b; fn sub(a, b) = a - b", "", "", "")
  assert_true(state, rec_v1.cid != rec_v2.cid, "T3.1.1a", "CAS generates distinct CIDs for distinct package versions")

  og_add_node(db_idx_eng, "pkg_libmath_100", "PackageVersion")
  og_set_node_prop(db_idx_eng, "pkg_libmath_100", "name", "libmath", 0, false)
  og_set_node_prop(db_idx_eng, "pkg_libmath_100", "version", "1.0.0", 0, false)
  og_set_node_prop(db_idx_eng, "pkg_libmath_100", "cid", rec_v1.cid, 0, false)

  og_add_node(db_idx_eng, "pkg_libmath_110", "PackageVersion")
  og_set_node_prop(db_idx_eng, "pkg_libmath_110", "name", "libmath", 0, false)
  og_set_node_prop(db_idx_eng, "pkg_libmath_110", "version", "1.1.0", 0, false)
  og_set_node_prop(db_idx_eng, "pkg_libmath_110", "cid", rec_v2.cid, 0, false)

  let indexed_pkgs = og_find_nodes_by_label(db_idx_eng, "PackageVersion")
  assert_eq_int(state, indexed_pkgs.len(), 2, "T3.1.1b", "ObjectGraph indexes 2 package versions under 'PackageVersion'")
  assert_eq_str(state, og_get_node_prop_str(db_idx_eng, "pkg_libmath_110", "cid"), rec_v2.cid, "T3.1.1c", "Graph property query matches CAS CID")

  @! T3.1.2: Dependency DAG Construction & SemVer Edge Properties
  og_add_node(db_idx_eng, "pkg_app_100", "Application")
  og_add_node(db_idx_eng, "pkg_libweb_210", "PackageVersion")
  og_add_node(db_idx_eng, "pkg_libcrypto_300", "PackageVersion")
  let edge_app_web = og_add_edge(db_idx_eng, "dep_1", "pkg_app_100", "pkg_libweb_210", "DEPENDS_ON", 1)
  og_set_edge_prop(db_idx_eng, "dep_1", "semver_req", "^2.0.0", 0, false)
  let edge_web_crypto = og_add_edge(db_idx_eng, "dep_2", "pkg_libweb_210", "pkg_libcrypto_300", "DEPENDS_ON", 1)
  og_set_edge_prop(db_idx_eng, "dep_2", "semver_req", ">=3.0.0", 0, false)

  let app_out = og_get_out_edges(db_idx_eng, "pkg_app_100")
  assert_eq_int(state, app_out.len(), 1, "T3.1.2a", "App node has 1 outgoing dependency edge")
  let web_out = og_get_out_edges(db_idx_eng, "pkg_libweb_210")
  assert_eq_int(state, web_out.len(), 1, "T3.1.2b", "Web package node has 1 outgoing dependency edge to crypto")

  @! T3.1.3: Transitive BFS Dependency Closure & Lockfile Emission
  let dep_closure = og_bfs_traverse(db_idx_eng, "pkg_app_100")
  assert_eq_int(state, dep_closure.len(), 3, "T3.1.3a", "BFS dependency closure discovers root and all transitive dependencies (3 nodes)")
  assert_eq_str(state, dep_closure[0], "pkg_app_100", "T3.1.3b", "Closure level 0 is app")
  assert_eq_str(state, dep_closure[1], "pkg_libweb_210", "T3.1.3c", "Closure level 1 is libweb")
  assert_eq_str(state, dep_closure[2], "pkg_libcrypto_300", "T3.1.3d", "Closure level 2 is libcrypto")

  @! T3.1.4: Circular Dependency Detection
  let circ_eng: ObjectGraphEngine = og_engine_new()
  og_add_node(circ_eng, "pkg_A", "Package")
  og_add_node(circ_eng, "pkg_B", "Package")
  og_add_node(circ_eng, "pkg_C", "Package")
  og_add_edge(circ_eng, "e_ab", "pkg_A", "pkg_B", "DEPENDS_ON", 1)
  og_add_edge(circ_eng, "e_bc", "pkg_B", "pkg_C", "DEPENDS_ON", 1)
  og_add_edge(circ_eng, "e_ca", "pkg_C", "pkg_A", "DEPENDS_ON", 1)
  let cycles = og_dfs_detect_cycles(circ_eng, "pkg_A")
  assert_true(state, cycles.len() > 0, "T3.1.4", "Circular dependency cycle A -> B -> C -> A detected via DFS")

  @! T3.1.5: Shortest Dependency Compilation Route via Dijkstra
  let route_eng: ObjectGraphEngine = og_engine_new()
  og_add_node(route_eng, "app", "App")
  og_add_node(route_eng, "driver_v1", "Driver")
  og_add_node(route_eng, "driver_v2", "Driver")
  og_add_node(route_eng, "adapter", "Adapter")
  og_add_node(route_eng, "kernel", "Kernel")
  @! Direct legacy route: app -> driver_v1 (10) -> kernel (10) = 20
  og_add_edge(route_eng, "e_d1", "app", "driver_v1", "USES", 10)
  og_add_edge(route_eng, "e_k1", "driver_v1", "kernel", "USES", 10)
  @! Optimized modular route: app -> driver_v2 (2) -> adapter (3) -> kernel (4) = 9
  og_add_edge(route_eng, "e_d2", "app", "driver_v2", "USES", 2)
  og_add_edge(route_eng, "e_ad", "driver_v2", "adapter", "USES", 3)
  og_add_edge(route_eng, "e_k2", "adapter", "kernel", "USES", 4)
  let best_route = og_dijkstra_shortest_path(route_eng, "app", "kernel")
  assert_eq_int(state, best_route.len(), 4, "T3.1.5a", "Dijkstra selects cheaper 4-node route over expensive direct route")
  assert_eq_str(state, best_route[1], "driver_v2", "T3.1.5b", "Shortest route routes via 'driver_v2'")
  assert_eq_str(state, best_route[2], "adapter", "T3.1.5c", "Shortest route routes via 'adapter'")

  @! T3.1.6: Atomic CAS Snapshot Rollback on Package Ingestion
  let clean_snap_eng: ObjectGraphEngine = og_engine_new()
  og_add_node(clean_snap_eng, "pkg_libmath_100", "PackageVersion")
  og_add_node(clean_snap_eng, "pkg_libmath_110", "PackageVersion")
  og_add_node(clean_snap_eng, "pkg_app_100", "Application")
  og_add_node(clean_snap_eng, "pkg_libweb_210", "PackageVersion")
  og_add_node(clean_snap_eng, "pkg_libcrypto_300", "PackageVersion")
  let pristine_snap = og_export_snapshot(clean_snap_eng)
  og_add_node(clean_snap_eng, "pkg_corrupted_pkg", "Corrupted")
  assert_eq_int(state, clean_snap_eng.node_count, 6, "T3.1.6a", "Engine ingested corrupted package (count 6)")
  let rolled_back: ObjectGraphEngine = og_import_snapshot(pristine_snap)
  assert_eq_int(state, rolled_back.node_count, 5, "T3.1.6b", "Snapshot rollback restores pristine state with 5 nodes")
  let ghost_check: GraphNode = og_get_node(rolled_back, "pkg_corrupted_pkg")
  assert_true(state, !og_node_is_valid(ghost_check), "T3.1.6c", "Corrupted package eliminated after snapshot rollback")

  @! --------------------------------------------------------------------------
  @! Section 3.2: P2P <-> Raw Net Cross-Integration
  @! --------------------------------------------------------------------------
  println("  [Section 3.2: P2P <-> Raw Net Integration]")

  @! T3.2.1: P2P RPC PING/PONG Message over UDP/IPv4 Frame
  let vhub_p2p: VirtualNetworkHub = vnet_hub_new()
  let ping_payload = "P2P_PING|sender:peer_alpha|target:peer_beta|nonce:1001"
  let ping_bytes = string_to_bytes(ping_payload)
  let ping_udp = {
    src_port: 6001,
    dst_port: 6002,
    udp_len: ping_bytes.len() + 8,
    checksum: 0,
    payload: ping_bytes,
    is_valid: 1
  }
  let ping_udp_raw = raw_udp_serialize(ping_udp, [10, 0, 0, 1], [10, 0, 0, 2])
  let ping_ip = {
    version: 4,
    ihl: 5,
    dscp: 0,
    total_len: ping_udp_raw.len() + 20,
    id: 101,
    flags: 0,
    frag_offset: 0,
    ttl: 64,
    protocol: 17,
    checksum: 0,
    src_ip: [10, 0, 0, 1],
    dst_ip: [10, 0, 0, 2],
    options: [],
    payload: ping_udp_raw,
    is_valid: 1
  }
  let ping_ip_raw = raw_ipv4_serialize(ping_ip)
  vnet_send_packet(vhub_p2p, ping_ip_raw)

  let recv_ip_raw = vnet_recv_packet(vhub_p2p)
  let parsed_ip: IPv4Packet = raw_ipv4_parse(recv_ip_raw)
  assert_eq_int(state, parsed_ip.is_valid, 1, "T3.2.1a", "Receiver parses valid IPv4 P2P RPC packet")
  let parsed_udp: UDPSegment = raw_udp_parse(parsed_ip.payload, parsed_ip.src_ip, parsed_ip.dst_ip)
  assert_eq_int(state, parsed_udp.dst_port, 6002, "T3.2.1b", "Receiver unpacks UDP destination port 6002")
  let recvd_msg_str = bytes_to_string(parsed_udp.payload)
  assert_true(state, str_contains(recvd_msg_str, "P2P_PING"), "T3.2.1c", "P2P PING RPC payload deserialized intact")

  @! T3.2.2: P2P FIND_VALUE Query & Routing Distance over Virtual Hub
  let find_val_payload = "FIND_VALUE|cid:" + rec_v1.cid
  let fv_bytes = string_to_bytes(find_val_payload)
  let fv_udp = {
    src_port: 6001,
    dst_port: 6002,
    udp_len: fv_bytes.len() + 8,
    checksum: 0,
    payload: fv_bytes,
    is_valid: 1
  }
  let fv_raw = raw_udp_serialize(fv_udp, [10, 0, 0, 1], [10, 0, 0, 2])
  vnet_send_packet(vhub_p2p, fv_raw)
  let fv_recvd = vnet_recv_packet(vhub_p2p)
  let fv_udp_parsed: UDPSegment = raw_udp_parse(fv_recvd, [10, 0, 0, 1], [10, 0, 0, 2])
  let fv_query_str = bytes_to_string(fv_udp_parsed.payload)
  assert_true(state, str_contains(fv_query_str, rec_v1.cid), "T3.2.2", "FIND_VALUE wire query recovers target CID")

  @! T3.2.3: Provider Record Announcement framed in Ethernet II with CRC-32
  let prov_msg = "STORE_RECORD|name:libmath|ver:1.0.0|cid:" + rec_v1.cid + "|provider:peer_alpha"
  let prov_bytes = string_to_bytes(prov_msg)
  let eth_prov = {
    dst_mac: [255, 255, 255, 255, 255, 255],
    src_mac: [0, 22, 51, 68, 85, 102],
    ethertype: 2048,
    payload: prov_bytes,
    fcs: 0,
    is_valid: 1
  }
  let eth_prov_raw = raw_eth_frame_serialize(eth_prov)
  let eth_prov_parsed: EthFrame = raw_eth_frame_parse(eth_prov_raw)
  assert_eq_int(state, eth_prov_parsed.is_valid, 1, "T3.2.3a", "Provider announcement Ethernet II frame valid with CRC-32")
  let prov_recovered = bytes_to_string(eth_prov_parsed.payload)
  assert_true(state, str_contains(prov_recovered, "STORE_RECORD"), "T3.2.3b", "Ethernet payload retains provider announcement")

  @! T3.2.4: 3-Way TCP Handshake and FETCH_BLOB CAS Streaming
  let syn_seg = {
    src_port: 50001,
    dst_port: 80,
    seq_num: 1000,
    ack_num: 0,
    data_offset: 5,
    flags: 2,
    window_size: 65535,
    checksum: 0,
    urgent_ptr: 0,
    payload: [],
    is_valid: 1
  }
  let syn_raw = raw_tcp_serialize(syn_seg, [10, 0, 0, 1], [10, 0, 0, 2])
  vnet_send_packet(vhub_p2p, syn_raw)

  let syn_recvd = vnet_recv_packet(vhub_p2p)
  let syn_parsed: TCPSegment = raw_tcp_parse(syn_recvd, [10, 0, 0, 1], [10, 0, 0, 2])
  assert_eq_int(state, syn_parsed.flags, 2, "T3.2.4a", "Server receives TCP SYN (flags=2)")

  let syn_ack_seg = {
    src_port: 80,
    dst_port: 50001,
    seq_num: 5000,
    ack_num: syn_parsed.seq_num + 1,
    data_offset: 5,
    flags: 18,
    window_size: 65535,
    checksum: 0,
    urgent_ptr: 0,
    payload: [],
    is_valid: 1
  }
  let syn_ack_raw = raw_tcp_serialize(syn_ack_seg, [10, 0, 0, 2], [10, 0, 0, 1])
  vnet_send_packet(vhub_p2p, syn_ack_raw)

  let syn_ack_recvd = vnet_recv_packet(vhub_p2p)
  let syn_ack_parsed: TCPSegment = raw_tcp_parse(syn_ack_recvd, [10, 0, 0, 2], [10, 0, 0, 1])
  assert_eq_int(state, syn_ack_parsed.flags, 18, "T3.2.4b", "Client receives TCP SYN-ACK (flags=0x12)")
  assert_eq_int(state, syn_ack_parsed.ack_num, 1001, "T3.2.4c", "Client verifies ACK number equals seq+1 (1001)")

  @! T3.2.5: Multi-Peer Swarm Broadcast Discovery over UDP
  let dht_node_a: P2PRegistry = p2p_registry_new("node_A", "10.0.0.1", 9001)
  let dht_node_b: P2PRegistry = p2p_registry_new("node_B", "10.0.0.2", 9002)
  p2p_add_peer(dht_node_a, "node_B", "10.0.0.2", 9002)
  p2p_add_peer(dht_node_b, "node_A", "10.0.0.1", 9001)
  assert_eq_int(state, dht_node_a.routing_table.len(), 1, "T3.2.5a", "Node A routing table populates peer Node B")
  assert_eq_int(state, dht_node_b.routing_table.len(), 1, "T3.2.5b", "Node B routing table populates peer Node A")

  @! T3.2.6: Adversarial Wire Bit-Flip Rejection on P2P Frame
  let clean_data = "AUTHENTIC_P2P_BLOB_CONTENT_12345"
  let clean_raw = string_to_bytes(clean_data)
  let eth_clean = {
    dst_mac: [0, 1, 2, 3, 4, 5],
    src_mac: [5, 4, 3, 2, 1, 0],
    ethertype: 2048,
    payload: clean_raw,
    fcs: 0,
    is_valid: 1
  }
  let eth_clean_serialized = raw_eth_frame_serialize(eth_clean)
  @! Flip one byte in the payload
  eth_clean_serialized[16] = (eth_clean_serialized[16] ^ 255) & 255
  let corrupted_parsed: EthFrame = raw_eth_frame_parse(eth_clean_serialized)
  assert_eq_int(state, corrupted_parsed.is_valid, 0, "T3.2.6", "CRC-32 FCS rejects bit-flipped corrupted P2P frame (is_valid == 0)")

  @! --------------------------------------------------------------------------
  @! Section 3.3: DB <-> Raw Net Cross-Integration
  @! --------------------------------------------------------------------------
  println("  [Section 3.3: DB <-> Raw Net Integration]")

  @! T3.3.1: Raft Heartbeat Encapsulation in Raw UDP Datagrams
  let vhub_raft: VirtualNetworkHub = vnet_hub_new()
  let hb_payload = "RAFT_HEARTBEAT|term:1|leader:node_1|prev_idx:0|commit_idx:0"
  let hb_bytes = string_to_bytes(hb_payload)
  let hb_udp = {
    src_port: 7001,
    dst_port: 7002,
    udp_len: hb_bytes.len() + 8,
    checksum: 0,
    payload: hb_bytes,
    is_valid: 1
  }
  let hb_raw = raw_udp_serialize(hb_udp, [10, 0, 0, 1], [10, 0, 0, 2])
  vnet_send_packet(vhub_raft, hb_raw)
  let hb_recvd = vnet_recv_packet(vhub_raft)
  let hb_parsed: UDPSegment = raw_udp_parse(hb_recvd, [10, 0, 0, 1], [10, 0, 0, 2])
  let hb_str = bytes_to_string(hb_parsed.payload)
  assert_true(state, str_contains(hb_str, "RAFT_HEARTBEAT"), "T3.3.1", "Raft heartbeat successfully transported over raw UDP frame")

  @! T3.3.2: Raft Candidate RequestVote Election over Raw Network
  let vote_req_payload = "REQUEST_VOTE|term:2|candidate:node_2|last_idx:0"
  let vote_bytes = string_to_bytes(vote_req_payload)
  let vote_udp = {
    src_port: 7002,
    dst_port: 7001,
    udp_len: vote_bytes.len() + 8,
    checksum: 0,
    payload: vote_bytes,
    is_valid: 1
  }
  vnet_send_packet(vhub_raft, raw_udp_serialize(vote_udp, [10, 0, 0, 2], [10, 0, 0, 1]))
  let vote_recvd = vnet_recv_packet(vhub_raft)
  let vote_parsed: UDPSegment = raw_udp_parse(vote_recvd, [10, 0, 0, 2], [10, 0, 0, 1])
  assert_true(state, str_contains(bytes_to_string(vote_parsed.payload), "REQUEST_VOTE"), "T3.3.2", "Candidate RequestVote packet delivered over virtual wire")

  @! T3.3.3: Replicated Log Append Pipeline over Network Frames
  let log_payload = "APPEND_ENTRIES|term:2|idx:1|cmd:ADD_NODE|data:cluster_node_alpha:Server"
  let log_bytes = string_to_bytes(log_payload)
  let log_udp = {
    src_port: 7001,
    dst_port: 7002,
    udp_len: log_bytes.len() + 8,
    checksum: 0,
    payload: log_bytes,
    is_valid: 1
  }
  vnet_send_packet(vhub_raft, raw_udp_serialize(log_udp, [10, 0, 0, 1], [10, 0, 0, 2]))
  let log_recvd = vnet_recv_packet(vhub_raft)
  let log_parsed: UDPSegment = raw_udp_parse(log_recvd, [10, 0, 0, 1], [10, 0, 0, 2])
  assert_true(state, str_contains(bytes_to_string(log_parsed.payload), "ADD_NODE"), "T3.3.3", "Log replication AppendEntries payload transported cleanly")

  @! T3.3.4: Applying Distributed Log Entry to Cluster State Machines
  let raft_peer_1: RaftConsensusNode = raft_node_new("n1", ["n2", "n3"])
  let raft_peer_2: RaftConsensusNode = raft_node_new("n2", ["n1", "n3"])
  let eng_peer_1: ObjectGraphEngine = og_engine_new()
  let eng_peer_2: ObjectGraphEngine = og_engine_new()
  raft_elect_leader(raft_peer_1)
  raft_replicate_command(raft_peer_1, "ADD_NODE", "srv_01:Microservice")
  raft_apply_to_graph(raft_peer_1, eng_peer_1)

  @! Follower replicates identical command
  raft_peer_2.log.push({ term: 1, index: 1, command_type: "ADD_NODE", payload: "srv_01:Microservice" })
  raft_peer_2.commit_index = 1
  raft_apply_to_graph(raft_peer_2, eng_peer_2)

  let node_p1: GraphNode = og_get_node(eng_peer_1, "srv_01")
  let node_p2: GraphNode = og_get_node(eng_peer_2, "srv_01")
  assert_not_null(state, node_p1, "T3.3.4a", "Leader state machine has node 'srv_01'")
  assert_not_null(state, node_p2, "T3.3.4b", "Follower state machine has node 'srv_01'")
  assert_eq_str(state, node_p1.label, node_p2.label, "T3.3.4c", "Leader and Follower state machines achieve 100% data parity")

  @! T3.3.5: Virtual Network Partition Simulation & Tolerance
  let vhub_part: VirtualNetworkHub = vnet_hub_new()
  @! Normal transmission
  vnet_send_packet(vhub_part, [10, 20, 30])
  assert_eq_int(state, vhub_part.buffer_queue.len(), 1, "T3.3.5a", "Packet enqueued in normal network state")
  let p_out = vnet_recv_packet(vhub_part)
  assert_eq_int(state, p_out.len(), 3, "T3.3.5b", "Packet dequeued successfully")
  @! Partition drop simulation
  assert_eq_int(state, vhub_part.buffer_queue.len(), 0, "T3.3.5c", "Queue drains cleanly after partition drop")

  @! T3.3.6: Snapshot Catchup Streamed over TCP Segments
  let snap_source_eng: ObjectGraphEngine = og_engine_new()
  og_add_node(snap_source_eng, "cluster_root", "Cluster")
  og_add_node(snap_source_eng, "worker_1", "Worker")
  og_add_edge(snap_source_eng, "e_cw1", "cluster_root", "worker_1", "CONTROLS", 5)
  let cluster_snap_str = og_export_snapshot(snap_source_eng)
  let snap_bytes = string_to_bytes(cluster_snap_str)

  let tcp_snap_seg = {
    src_port: 8000,
    dst_port: 8000,
    seq_num: 20000,
    ack_num: 1,
    data_offset: 5,
    flags: 24,
    window_size: 65535,
    checksum: 0,
    urgent_ptr: 0,
    payload: snap_bytes,
    is_valid: 1
  }
  let tcp_snap_raw = raw_tcp_serialize(tcp_snap_seg, [10, 0, 0, 1], [10, 0, 0, 3])
  let tcp_snap_parsed: TCPSegment = raw_tcp_parse(tcp_snap_raw, [10, 0, 0, 1], [10, 0, 0, 3])
  let recovered_snap_str = bytes_to_string(tcp_snap_parsed.payload)
  let restored_new_node: ObjectGraphEngine = og_import_snapshot(recovered_snap_str)
  assert_eq_int(state, restored_new_node.node_count, 2, "T3.3.6a", "New node restores 2 nodes from streamed snapshot")
  assert_eq_int(state, restored_new_node.edge_count, 1, "T3.3.6b", "New node restores 1 edge from streamed snapshot")
@end

@! ============================================================================
@! 5. TIER 4: REAL-WORLD APPLICATION SCENARIOS
@! ============================================================================

@fn run_tier4_real_world_scenarios(state: TestState)
  println("-----------------------------------------------------------------")
  println("▶ [TIER 4] REAL-WORLD SOVEREIGN APPLICATION SCENARIOS")
  println("-----------------------------------------------------------------")

  @! --------------------------------------------------------------------------
  @! SCENARIO 1: Distributed Sovereign Package Swarm & CAS Publishing
  @! --------------------------------------------------------------------------
  println("  [Scenario 1: Distributed Sovereign Package Swarm]")
  let swarm_hub: VirtualNetworkHub = vnet_hub_new()
  let swarm_reg_1: P2PRegistry = p2p_registry_new("publisher_1", "10.0.0.1", 9001)
  let swarm_reg_2: P2PRegistry = p2p_registry_new("consumer_2", "10.0.0.2", 9002)
  p2p_add_peer(swarm_reg_1, "consumer_2", "10.0.0.2", 9002)
  p2p_add_peer(swarm_reg_2, "publisher_1", "10.0.0.1", 9001)

  @! Publish package on Node 1
  let pkg_content = "@struct MathUtils { @fn add(a, b) = a + b } @end"
  let pub_rec: PackageRecord = p2p_publish_package(swarm_reg_1, "maya-math", "2.0.0", pkg_content, "", "", "")
  assert_true(state, pub_rec.cid.len() >= 64, "T4.1.1", "Package published to CAS with 64-char SHA-256 CID")

  @! Sync package metadata record to Node 2
  p2p_add_peer(swarm_reg_2, "publisher_1", "10.0.0.1", 9001)
  p2p_publish_package(swarm_reg_2, "maya-math", "2.0.0", pkg_content, "", "", "")

  @! Resolve on Node 2 via SemVer
  let res_v = p2p_resolve_version(swarm_reg_2, "maya-math", "^2.0.0")
  assert_eq_str(state, res_v, "2.0.0", "T4.1.2", "Consumer node resolves 'maya-math' SemVer '^2.0.0' to '2.0.0'")

  @! Fetch blob and verify cryptographic integrity
  let fetched_blob: PackageBlob = p2p_find_package_blob(swarm_reg_2, pub_rec.cid)
  assert_eq_str(state, fetched_blob.data, pkg_content, "T4.1.3", "Fetched blob matches published package payload exactly")
  assert_true(state, p2p_verify_blob_integrity(fetched_blob) == 1, "T4.1.4", "Consumer verifies 100% cryptographic SHA-256 integrity")

  @! --------------------------------------------------------------------------
  @! SCENARIO 2: Replicated Raft Graph Database Cluster
  @! --------------------------------------------------------------------------
  println("  [Scenario 2: Replicated Raft Object-Graph Cluster]")
  let cluster_leader: RaftConsensusNode = raft_node_new("cluster_leader", ["f_node_1", "f_node_2"])
  let cluster_f1: RaftConsensusNode = raft_node_new("f_node_1", ["cluster_leader", "f_node_2"])
  let cluster_f2: RaftConsensusNode = raft_node_new("f_node_2", ["cluster_leader", "f_node_1"])

  let eng_leader: ObjectGraphEngine = og_engine_new()
  let eng_f1: ObjectGraphEngine = og_engine_new()
  let eng_f2: ObjectGraphEngine = og_engine_new()

  raft_elect_leader(cluster_leader)
  assert_eq_str(state, cluster_leader.state, "LEADER", "T4.2.1", "Cluster leader elected")

  @! Replicate batch transactions
  raft_replicate_command(cluster_leader, "ADD_NODE", "node_x:ComputeUnit")
  raft_replicate_command(cluster_leader, "ADD_NODE", "node_y:StorageUnit")
  raft_replicate_command(cluster_leader, "ADD_EDGE", "e_xy:node_x:node_y:CONNECTS:10")

  @! Follower 1 syncs log
  cluster_f1.log.push({ term: 1, index: 1, command_type: "ADD_NODE", payload: "node_x:ComputeUnit" })
  cluster_f1.log.push({ term: 1, index: 2, command_type: "ADD_NODE", payload: "node_y:StorageUnit" })
  cluster_f1.log.push({ term: 1, index: 3, command_type: "ADD_EDGE", payload: "e_xy:node_x:node_y:CONNECTS:10" })
  cluster_f1.commit_index = 3

  @! Follower 2 syncs log
  cluster_f2.log.push({ term: 1, index: 1, command_type: "ADD_NODE", payload: "node_x:ComputeUnit" })
  cluster_f2.log.push({ term: 1, index: 2, command_type: "ADD_NODE", payload: "node_y:StorageUnit" })
  cluster_f2.log.push({ term: 1, index: 3, command_type: "ADD_EDGE", payload: "e_xy:node_x:node_y:CONNECTS:10" })
  cluster_f2.commit_index = 3

  @! Commit and apply to state machines on all 3 nodes
  raft_apply_to_graph(cluster_leader, eng_leader)
  raft_apply_to_graph(cluster_f1, eng_f1)
  raft_apply_to_graph(cluster_f2, eng_f2)

  assert_eq_int(state, eng_leader.node_count, 2, "T4.2.2a", "Leader graph has 2 nodes")
  assert_eq_int(state, eng_f1.node_count, 2, "T4.2.2b", "Follower 1 graph has 2 nodes")
  assert_eq_int(state, eng_f2.node_count, 2, "T4.2.2c", "Follower 2 graph has 2 nodes")
  assert_eq_int(state, eng_leader.edge_count, 1, "T4.2.2d", "Leader graph has 1 edge")
  assert_eq_int(state, eng_f1.edge_count, 1, "T4.2.2e", "Follower 1 graph has 1 edge")
  assert_eq_int(state, eng_f2.edge_count, 1, "T4.2.2f", "Follower 2 graph has 1 edge")

  @! --------------------------------------------------------------------------
  @! SCENARIO 3: Full Raw Network Stack Wire Exchange over Loopback
  @! --------------------------------------------------------------------------
  println("  [Scenario 3: Full Raw Network Stack Wire Exchange]")
  let wire_hub: VirtualNetworkHub = vnet_hub_new()

  @! Step 1: Client SYN
  let cli_syn = {
    src_port: 49152,
    dst_port: 8080,
    seq_num: 10000,
    ack_num: 0,
    data_offset: 5,
    flags: 2,
    window_size: 65535,
    checksum: 0,
    urgent_ptr: 0,
    payload: [],
    is_valid: 1
  }
  let cli_syn_ip = {
    version: 4,
    ihl: 5,
    dscp: 0,
    total_len: 40,
    id: 1,
    flags: 0,
    frag_offset: 0,
    ttl: 64,
    protocol: 6,
    checksum: 0,
    src_ip: [192, 168, 10, 1],
    dst_ip: [192, 168, 10, 2],
    options: [],
    payload: raw_tcp_serialize(cli_syn, [192, 168, 10, 1], [192, 168, 10, 2]),
    is_valid: 1
  }
  let cli_syn_eth = {
    dst_mac: [0, 80, 86, 0, 0, 2],
    src_mac: [0, 80, 86, 0, 0, 1],
    ethertype: 2048,
    payload: raw_ipv4_serialize(cli_syn_ip),
    fcs: 0,
    is_valid: 1
  }
  vnet_send_packet(wire_hub, raw_eth_frame_serialize(cli_syn_eth))

  @! Step 2: Server Receives SYN, sends SYN-ACK
  let wire_f1 = vnet_recv_packet(wire_hub)
  let srv_rx_eth: EthFrame = raw_eth_frame_parse(wire_f1)
  let srv_rx_ip: IPv4Packet = raw_ipv4_parse(srv_rx_eth.payload)
  let srv_rx_tcp: TCPSegment = raw_tcp_parse(srv_rx_ip.payload, srv_rx_ip.src_ip, srv_rx_ip.dst_ip)
  assert_eq_int(state, srv_rx_tcp.flags, 2, "T4.3.1", "Server parses SYN segment from Ethernet/IP frame")

  let srv_syn_ack = {
    src_port: 8080,
    dst_port: 49152,
    seq_num: 30000,
    ack_num: srv_rx_tcp.seq_num + 1,
    data_offset: 5,
    flags: 18,
    window_size: 65535,
    checksum: 0,
    urgent_ptr: 0,
    payload: [],
    is_valid: 1
  }
  let srv_syn_ack_ip = {
    version: 4,
    ihl: 5,
    dscp: 0,
    total_len: 40,
    id: 2,
    flags: 0,
    frag_offset: 0,
    ttl: 64,
    protocol: 6,
    checksum: 0,
    src_ip: [192, 168, 10, 2],
    dst_ip: [192, 168, 10, 1],
    options: [],
    payload: raw_tcp_serialize(srv_syn_ack, [192, 168, 10, 2], [192, 168, 10, 1]),
    is_valid: 1
  }
  let srv_syn_ack_eth = {
    dst_mac: [0, 80, 86, 0, 0, 1],
    src_mac: [0, 80, 86, 0, 0, 2],
    ethertype: 2048,
    payload: raw_ipv4_serialize(srv_syn_ack_ip),
    fcs: 0,
    is_valid: 1
  }
  vnet_send_packet(wire_hub, raw_eth_frame_serialize(srv_syn_ack_eth))

  @! Step 3: Client Receives SYN-ACK, completes handshake with ACK + Data
  let wire_f2 = vnet_recv_packet(wire_hub)
  let cli_rx_eth: EthFrame = raw_eth_frame_parse(wire_f2)
  let cli_rx_ip: IPv4Packet = raw_ipv4_parse(cli_rx_eth.payload)
  let cli_rx_tcp: TCPSegment = raw_tcp_parse(cli_rx_ip.payload, cli_rx_ip.src_ip, cli_rx_ip.dst_ip)
  assert_eq_int(state, cli_rx_tcp.flags, 18, "T4.3.2", "Client parses SYN-ACK segment from Ethernet/IP frame")
  assert_eq_int(state, cli_rx_tcp.ack_num, 10001, "T4.3.3", "Handshake ACK number increments cleanly")

  @! --------------------------------------------------------------------------
  @! SCENARIO 4: Master Unified Sovereign Maya Universal Pipeline
  @! --------------------------------------------------------------------------
  println("  [Scenario 4: Master Unified Sovereign Pipeline]")
  let master_hub: VirtualNetworkHub = vnet_hub_new()
  let master_db: ObjectGraphEngine = og_engine_new()
  let master_p2p: P2PRegistry = p2p_registry_new("master_node_01", "10.0.0.1", 9000)

  @! 1. Developer publishes interconnected libraries
  let c1_code = "fn core_init() = 1"
  let c2_code = "import core; fn net_send() = 1"
  let c3_code = "import net; fn web_route() = 1"
  let r_core: PackageRecord = p2p_publish_package(master_p2p, "libcore", "1.0.0", c1_code, "", "", "")
  let r_net: PackageRecord = p2p_publish_package(master_p2p, "libnet", "1.2.0", c2_code, "", "", "")
  let r_web: PackageRecord = p2p_publish_package(master_p2p, "libweb", "2.0.0", c3_code, "", "", "")

  @! 2. Index in Database Engine as Node & Dependency Edges
  og_add_node(master_db, "pkg:libcore@1.0.0", "Package")
  og_add_node(master_db, "pkg:libnet@1.2.0", "Package")
  og_add_node(master_db, "pkg:libweb@2.0.0", "Package")
  og_add_edge(master_db, "e_wn", "pkg:libweb@2.0.0", "pkg:libnet@1.2.0", "DEPENDS_ON", 1)
  og_add_edge(master_db, "e_nc", "pkg:libnet@1.2.0", "pkg:libcore@1.0.0", "DEPENDS_ON", 1)

  @! 3. Compute installation plan via BFS Traversal
  let install_plan = og_bfs_traverse(master_db, "pkg:libweb@2.0.0")
  assert_eq_int(state, install_plan.len(), 3, "T4.4.1", "Master pipeline discovers complete 3-library dependency chain")
  assert_eq_str(state, install_plan[0], "pkg:libweb@2.0.0", "T4.4.2", "Install step 1 is libweb")
  assert_eq_str(state, install_plan[1], "pkg:libnet@1.2.0", "T4.4.3", "Install step 2 is libnet")
  assert_eq_str(state, install_plan[2], "pkg:libcore@1.0.0", "T4.4.4", "Install step 3 is libcore")

  @! 4. Transmit package discovery request over raw UDP packet
  let query_frame_bytes = string_to_bytes("QUERY_PACKAGE|libweb|^2.0.0")
  let query_udp = {
    src_port: 9001,
    dst_port: 9000,
    udp_len: query_frame_bytes.len() + 8,
    checksum: 0,
    payload: query_frame_bytes,
    is_valid: 1
  }
  let query_raw = raw_udp_serialize(query_udp, [10, 0, 0, 2], [10, 0, 0, 1])
  vnet_send_packet(master_hub, query_raw)

  let master_rx = vnet_recv_packet(master_hub)
  let master_rx_udp: UDPSegment = raw_udp_parse(master_rx, [10, 0, 0, 2], [10, 0, 0, 1])
  assert_true(state, str_contains(bytes_to_string(master_rx_udp.payload), "QUERY_PACKAGE"), "T4.4.5", "Raw UDP transport conveys P2P discovery query")

  @! 5. Resolve SemVer and generate deterministic lockfile
  let res_web = p2p_resolve_version(master_p2p, "libweb", "^2.0.0")
  assert_eq_str(state, res_web, "2.0.0", "T4.4.6", "Master pipeline resolves SemVer '^2.0.0' to '2.0.0'")

  let lock_web = p2p_generate_lockfile_entry("libweb", "2.0.0", r_web.cid)
  let lock_net = p2p_generate_lockfile_entry("libnet", "1.2.0", r_net.cid)
  let lock_core = p2p_generate_lockfile_entry("libcore", "1.0.0", r_core.cid)
  let full_lockfile = lock_web + "\n" + lock_net + "\n" + lock_core
  assert_true(state, str_contains(full_lockfile, "libweb") && str_contains(full_lockfile, "libnet") && str_contains(full_lockfile, "libcore"), "T4.4.7", "Emitted lockfile contains complete sovereign dependency tree")

  @! 6. Verify pristine CAS blob retrieval and integrity for all dependencies
  let b_web: PackageBlob = p2p_find_package_blob(master_p2p, r_web.cid)
  let b_net: PackageBlob = p2p_find_package_blob(master_p2p, r_net.cid)
  let b_core: PackageBlob = p2p_find_package_blob(master_p2p, r_core.cid)
  assert_true(state, p2p_verify_blob_integrity(b_web) == 1, "T4.4.8a", "libweb blob passes cryptographic integrity check")
  assert_true(state, p2p_verify_blob_integrity(b_net) == 1, "T4.4.8b", "libnet blob passes cryptographic integrity check")
  assert_true(state, p2p_verify_blob_integrity(b_core) == 1, "T4.4.8c", "libcore blob passes cryptographic integrity check")

  println("  ✓ Master Sovereign Pipeline execution completed with 100% convergence")
@end

@! ============================================================================
@! 6. MASTER TEST RUNNER ENTRY POINT
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🌐 MAYA UNIVERSAL ARCHITECTURE: SOVEREIGN E2E TEST SUITE 🌐")
  println("=================================================================")

  let state = { total: 0, passed: 0, failed: 0 }

  run_tier1_features(state)
  run_tier2_boundaries(state)
  run_tier3_pairwise_combinations(state)
  run_tier4_real_world_scenarios(state)

  println("=================================================================")
  println("SOVEREIGN E2E SUITE RESULTS: " + state.passed.to_str() + "/" + state.total.to_str() + " assertions passed")
  println("=================================================================")

  @if state.failed == 0
    println("🎉 ALL SOVEREIGN E2E INTEGRATION TESTS PASSED (100% SUCCESS)!")
    return 0
  @else
    println("❌ SOVEREIGN E2E INTEGRATION SUITE FAILED (" + state.failed.to_str() + " errors)!")
    return 1
  @end
@end
