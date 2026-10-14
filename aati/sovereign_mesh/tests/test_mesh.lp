// ==============================================================================
// 👑 LIPI SOVEREIGN MESH: VERIFICATION & COMPLIANCE TEST SUITE
// ⚡ File: packages/sovereign_mesh/tests/test_mesh.lp
//
// WHY: Validates packet framing, multi-hop routing, loop prevention, and
//      deduplication guarantees of sovereign mesh peer-to-peer networking.
//
// 100% Pure Lipi | 0% C | 0% Libc | Direct Silicon
// ==============================================================================

import "packages/sovereign_mesh/src/mesh"

fn assert_eq(actual, expected, test_name)
    if actual == expected
        say "  ✔ [PASS] " + test_name + " == " + str(expected)
        return 1
    else
        say "  ❌ [FAIL] " + test_name + " expected " + str(expected) + " but got " + str(actual)
        return 0

fn test_node_lifecycle()
    say "── Test 1: Node Initialization & Peer Registration ──"
    let n_alpha = mesh_node_new("node-alpha")
    let n_beta = mesh_node_new("node-beta")
    let n_gamma = mesh_node_new("node-gamma")

    mesh_node_add_peer(n_alpha, "node-beta")
    mesh_node_add_peer(n_beta, "node-gamma")

    // Route: alpha -> gamma via beta
    mesh_node_add_route(n_alpha, "node-gamma", "node-beta")

    let r1 = mesh_node_lookup_route(n_alpha, "node-beta")
    let r2 = mesh_node_lookup_route(n_alpha, "node-gamma")
    let r3 = mesh_node_lookup_route(n_alpha, "node-alpha")

    let p1 = assert_eq(r1, "node-beta", "Route Alpha->Beta")
    let p2 = assert_eq(r2, "node-beta", "Route Alpha->Gamma via Beta")
    let p3 = assert_eq(r3, "LOCAL", "Route Alpha->Alpha (Local)")
    return p1 and p2 and p3

fn test_packet_serialization()
    say "── Test 2: Wire Frame Serialization & Parsing ──"
    let raw = mesh_packet_create("node-alpha", "node-beta", 42, 5, "PAYLOAD_PING")
    let parsed = mesh_packet_parse(raw)
    let p_len = len(parsed)
    let p1 = assert_eq(p_len, 7, "Parsed Segment Count")
    let p2 = assert_eq(get(parsed, 2), "node-alpha", "Packet Source")
    let p3 = assert_eq(get(parsed, 3), "node-beta", "Packet Destination")
    let p4 = assert_eq(get(parsed, 4), "42", "Packet Sequence")
    let p5 = assert_eq(get(parsed, 5), "5", "Packet TTL")
    let p6 = assert_eq(get(parsed, 6), "PAYLOAD_PING", "Packet Payload")
    return p1 and p2 and p3 and p4 and p5 and p6

fn test_direct_delivery()
    say "── Test 3: Direct Unicast Delivery ──"
    let n_alpha = mesh_node_new("node-alpha")
    let n_beta = mesh_node_new("node-beta")
    mesh_node_add_peer(n_alpha, "node-beta")
    mesh_node_add_peer(n_beta, "node-alpha")

    let wire = mesh_send_packet(n_alpha, "node-beta", "HELLO_BETA", 10)
    let res = mesh_receive_packet(n_beta, wire)
    let p1 = assert_eq(res, 1, "Direct Delivery Return Code (1=Local)")
    return p1

fn test_multi_hop_routing()
    say "── Test 4: Multi-Hop Routing & TTL Decrement ──"
    let n_alpha = mesh_node_new("node-alpha")
    let n_beta = mesh_node_new("node-beta")
    let n_gamma = mesh_node_new("node-gamma")

    mesh_node_add_peer(n_alpha, "node-beta")
    mesh_node_add_peer(n_beta, "node-gamma")
    mesh_node_add_route(n_alpha, "node-gamma", "node-beta")
    mesh_node_add_route(n_beta, "node-gamma", "node-gamma")

    // Alpha sends to Gamma with TTL=3
    let wire1 = mesh_send_packet(n_alpha, "node-gamma", "CRITICAL_DATA", 3)
    
    // Intermediate Node Beta receives and forwards
    let res_beta = mesh_receive_packet(n_beta, wire1)
    let p1 = assert_eq(res_beta, 3, "Hop Beta Forward Return Code (3=Forwarded)")

    // Gamma receives packet
    let wire2 = mesh_packet_create("node-alpha", "node-gamma", 1, 2, "CRITICAL_DATA")
    let res_gamma = mesh_receive_packet(n_gamma, wire2)
    let p2 = assert_eq(res_gamma, 1, "Final Hop Gamma Delivery (1=Local)")
    return p1 and p2

fn test_loop_prevention_ttl()
    say "── Test 5: Loop Prevention via TTL Expiration ──"
    let n_beta = mesh_node_new("node-beta")
    mesh_node_add_route(n_beta, "node-gamma", "node-gamma")

    // Expired packet with TTL=1 addressed to Gamma arriving at Beta
    let expired_wire = mesh_packet_create("node-alpha", "node-gamma", 99, 1, "LOOPING_DATA")
    let res = mesh_receive_packet(n_beta, expired_wire)
    let p1 = assert_eq(res, 0 - 1, "TTL Expired Drop Code (-1)")
    return p1

fn test_broadcast_deduplication()
    say "── Test 6: Broadcast Flood & Deduplication ──"
    let n_node = mesh_node_new("node-cluster-1")
    let bcast_wire = mesh_packet_create("sender-x", "BROADCAST", 101, 8, "SYNC_EVENT")

    // First arrival: accepted as broadcast
    let res1 = mesh_receive_packet(n_node, bcast_wire)
    let p1 = assert_eq(res1, 2, "First Broadcast Arrival (2=Delivered Broadcast)")

    // Second arrival of same packet: dropped as duplicate
    let res2 = mesh_receive_packet(n_node, bcast_wire)
    let p2 = assert_eq(res2, 0, "Duplicate Broadcast Arrival (0=Duplicate Dropped)")
    return p1 and p2

fn main()
    say "=================================================================="
    say "👑 LIPI SOVEREIGN MESH COMPLIANCE SUITE"
    say "=================================================================="
    let pass1 = test_node_lifecycle()
    let pass2 = test_packet_serialization()
    let pass3 = test_direct_delivery()
    let pass4 = test_multi_hop_routing()
    let pass5 = test_loop_prevention_ttl()
    let pass6 = test_broadcast_deduplication()

    let all_passed = pass1 and pass2 and pass3 and pass4 and pass5 and pass6
    say "=================================================================="
    if all_passed == 1
        say "✔ ALL SOVEREIGN MESH TESTS PASSED (6/6 SUITES GREEN)"
        say "=================================================================="
        return 0
    else
        say "❌ TEST FAILURES DETECTED IN SOVEREIGN MESH SUITE"
        say "=================================================================="
        return 1

main()
