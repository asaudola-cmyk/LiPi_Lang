// ==============================================================================
// 🧪 LIPI TEST: LipiRPC Zero-Copy Binary RPC & P2P Swarm Gossip Mesh Test Suite
// ⚡ Tests 16-byte compact binary frames, zero-copy parameter pack/unpack,
//    cryptographic authentication, P2P gossip peer discovery, and node failure detection.
// ==============================================================================

include "universe/net/lipirpc.lp"

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ " + test_name

say "========================================================"
say "👑 Testing LipiRPC Binary RPC & P2P Swarm Mesh Protocol"
say "========================================================"

// ── Test 1: 16-Byte Compact Binary Frame Header ───────────────────────────────
say "[1/5] Testing 16-Byte Frame Header Serialization..."
buf = malloc(64)
mem_fill(buf, 0, 64)

// Write header: flags=LIPIRPC_FLAG_REQ, method_id=42, seq_id=1001, payload_len=20
lipirpc_write_header(buf, LIPIRPC_FLAG_REQ, 42, 1001, 20)

meta = list()
res = lipirpc_parse_header(buf, 64, meta)
assert_eq(res, 1, "Header parsed successfully")
assert_eq(get(meta, 0), LIPIRPC_VERSION, "Protocol version is 1")
assert_eq(get(meta, 1), LIPIRPC_FLAG_REQ, "Flags match LIPIRPC_FLAG_REQ (1)")
assert_eq(get(meta, 2), 42, "Method ID is 42")
assert_eq(get(meta, 3), 1001, "Sequence / Message ID is 1001")
assert_eq(get(meta, 4), 20, "Payload length is 20")

// ── Test 2: Typed Payload Packing & Unpacking ─────────────────────────────────
say "[2/5] Testing High-Speed Parameter Pack / Unpack..."
// Pack integer 987654 at payload offset 16
bytes_written = lipirpc_pack_int(buf, 16, 987654)
assert_eq(bytes_written, 5, "Packed int in 5 bytes (tag + 4 bytes)")

val = lipirpc_unpack_int(buf, 16)
assert_eq(val, 987654, "Unpacked integer matches original value (987654)")

// Pack string "LipiCloud" at offset 21
str_bytes = lipirpc_pack_str(buf, 21, "LipiCloud")
assert_eq(str_bytes, 12, "Packed string 'LipiCloud' in 12 bytes")

// ── Test 3: Cryptographic Message Authentication ──────────────────────────────
say "[3/5] Testing Cryptographic Frame Authentication..."
secret_key = 88392104

// Sign payload (offset 16, length 17)
lipirpc_sign_frame(buf, 16, 17, secret_key)

// Verify untampered signature
valid = lipirpc_verify_frame(buf, 16, 17, secret_key)
assert_eq(valid, 1, "Untampered frame signature verified successfully")

// Tamper with payload byte at offset 18
mem_byte_write(buf, 18, 99)
invalid = lipirpc_verify_frame(buf, 16, 17, secret_key)
assert_eq(invalid, 0, "Tampered frame signature correctly rejected (0)")

free(buf, 64)

// ── Test 4: P2P Swarm Gossip Node Discovery ───────────────────────────────────
say "[4/5] Testing P2P Swarm Gossip Peer Discovery..."
cluster = lipirpc_cluster_new()

// Node 1 joins cluster
p1 = lipirpc_peer_new("node-alpha", 1)
lipirpc_cluster_add_peer(cluster, p1)

// Node 2 discovered via gossip packet
res_gossip = lipirpc_cluster_gossip_update(cluster, "node-beta", 10, 100)
assert_eq(res_gossip, 1, "Gossip update discovered new peer (node-beta)")

// Verify cluster has 2 active peers
peers = get(cluster, 0)
assert_eq(len(peers), 2, "Cluster contains 2 active peers")

// Gossip update with higher heartbeat
res_hb = lipirpc_cluster_gossip_update(cluster, "node-beta", 15, 105)
assert_eq(res_hb, 2, "Heartbeat incremented to 15")
p_beta = lipirpc_cluster_find_peer(cluster, "node-beta")
assert_eq(get(p_beta, 1), 15, "Peer node-beta heartbeat updated to 15")

// ── Test 5: Failure Detection State Transitions ───────────────────────────────
say "[5/5] Testing Cluster Failure Detector (Alive -> Suspect -> Dead)..."
// Node alpha has last_seen = 0, current tick = 100
// Suspect threshold = 30, Dead threshold = 60
// Since (100 - 0) = 100 >= 60, node-alpha should transition to Dead (3)
dead_count = lipirpc_cluster_detect_failures(cluster, 100, 30, 60)
assert_eq(dead_count, 1, "Failure detector marked 1 silent node as Dead")

p_alpha = lipirpc_cluster_find_peer(cluster, "node-alpha")
assert_eq(get(p_alpha, 2), 3, "Node-alpha status transitioned to Dead (3)")

// Node-beta had last_seen = 105 (current 100), remains Alive (1)
assert_eq(get(p_beta, 2), 1, "Node-beta remains Alive (1)")

say "========================================================"
say "PASS: LipiRPC Binary RPC & P2P Swarm Mesh Verified 100%!"
say "========================================================"
