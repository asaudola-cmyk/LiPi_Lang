// ==============================================================================
// 🧪 LIPI TEST SUITE: Autonomous P2P Swarm & LipRPC Protocol (tests/test_swarm_liprpc.lp)
// ⚡ Tests 16-byte compact binary frames, zero-copy pack/unpack,
//    synchronous method dispatch, and Chase-Lev distributed work-stealing scheduler.
// ==============================================================================

include "universe/swarm/liprpc.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    say "  ✔ [PASS] " + test_name

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ [PASS] " + test_name

say "================================================================="
say "👑 LIPI SWARM & LipRPC PROTOCOL SUITE (Frontier 6) 👑"
say "================================================================="

// ── Section 1: 16-Byte Binary Frame Header Encoding & Decoding ────────────────
say "▶ Section 1: 16-Byte Binary Frame Header Encoding & Decoding..."
hdr_buf = malloc(64)
mem_fill(hdr_buf, 0, 64)

// Encode frame: msg_type=LIPRPC_MSG_REQ (1), method_id=42, seq_id=98765, payload_len=32
bytes_written = liprpc_encode_header(hdr_buf, LIPRPC_MSG_REQ, 42, 98765, 32)
assert_eq(bytes_written, 16, "Header serialized exactly 16 bytes")

meta = list()
res = liprpc_decode_header(hdr_buf, 64, meta)
assert_eq(res, 1, "16-byte header decoded successfully")
assert_eq(get(meta, 0), LIPRPC_MSG_REQ, "Message type is LIPRPC_MSG_REQ (1)")
assert_eq(get(meta, 1), 42, "Method ID is 42")
assert_eq(get(meta, 2), 98765, "Sequence ID is 98765")
assert_eq(get(meta, 3), 32, "Payload length is 32")

// Test corrupted magic rejection
mem_byte_write(hdr_buf, 0, 0)
bad_meta = list()
bad_res = liprpc_decode_header(hdr_buf, 64, bad_meta)
assert_eq(bad_res, 0, "Corrupted magic correctly rejected (0)")

free(hdr_buf, 64)

// ── Section 2: High-Speed Parameter Packing & Zero-Copy Unpacking ─────────────
say ""
say "▶ Section 2: High-Speed Parameter Packing & Zero-Copy Unpacking..."
data_buf = malloc(128)
mem_fill(data_buf, 0, 128)

// Pack 32-bit integer
ipack_len = liprpc_pack_i32(data_buf, 0, 1048576)
assert_eq(ipack_len, 4, "Packed 32-bit integer in 4 bytes")
i_val = liprpc_unpack_i32(data_buf, 0)
assert_eq(i_val, 1048576, "Unpacked 32-bit integer matches (1048576)")

// Pack string
spack_len = liprpc_pack_str(data_buf, 4, "LipiSwarmMesh")
assert_eq(spack_len, 15, "Packed string 'LipiSwarmMesh' in 15 bytes (2 len + 13 chars)")
s_val = liprpc_unpack_str(data_buf, 4)
assert_true(len(s_val) == 13, "Unpacked string length is 13")

free(data_buf, 128)

// ── Section 3: Synchronous LipRPC Server Dispatch & Method Invocation ──────────
say ""
say "▶ Section 3: Synchronous LipRPC Server Dispatch & Method Invocation..."
node_alpha = liprpc_node_new("node-alpha", 16)
liprpc_register_method(node_alpha, 101, 1) // Handler 1: integer sum
liprpc_register_method(node_alpha, 102, 2) // Handler 2: string reply

wire_req = malloc(256)
wire_resp = malloc(256)
mem_fill(wire_req, 0, 256)
mem_fill(wire_resp, 0, 256)

// Build request: Method 101 (Sum), Seq 5001, Args: 1234 + 5678
liprpc_encode_header(wire_req, LIPRPC_MSG_REQ, 101, 5001, 8)
liprpc_pack_i32(wire_req, LIPRPC_HDR_SIZE, 1234)
liprpc_pack_i32(wire_req, LIPRPC_HDR_SIZE + 4, 5678)

resp_len = liprpc_dispatch_frame(node_alpha, wire_req, LIPRPC_HDR_SIZE + 8, wire_resp, 256)
assert_eq(resp_len, 20, "Response length is 20 bytes (16 header + 4 payload)")

resp_meta = list()
liprpc_decode_header(wire_resp, resp_len, resp_meta)
assert_eq(get(resp_meta, 0), LIPRPC_MSG_RESP, "Response message type is LIPRPC_MSG_RESP (2)")
assert_eq(get(resp_meta, 2), 5001, "Response sequence ID matches request (5001)")

sum_val = liprpc_unpack_i32(wire_resp, LIPRPC_HDR_SIZE)
assert_eq(sum_val, 6912, "Server computed correct sum: 1234 + 5678 = 6912")

free(wire_req, 256)
free(wire_resp, 256)

// ── Section 4: Autonomous Chase-Lev Distributed Work-Stealing Scheduler ────────
say ""
say "▶ Section 4: Autonomous Chase-Lev Distributed Work-Stealing Scheduler..."
node_victim = liprpc_node_new("victim-worker", 16)
node_thief = liprpc_node_new("idle-thief", 16)

// Submit 3 tasks to victim worker:
// Task 1: Type 1 (Square), arg=7 -> 49
// Task 2: Type 2 (Increment), arg=10 -> 21
// Task 3: Type 1 (Square), arg=12 -> 144
liprpc_submit_task(node_victim, 1, 1, 7)
liprpc_submit_task(node_victim, 2, 2, 10)
liprpc_submit_task(node_victim, 3, 1, 12)

v_queue = get(node_victim, 3)
assert_eq(liprpc_queue_len(v_queue), 3, "Victim worker has 3 tasks queued")

// Victim executes 1 task locally (LIFO order: Task 3)
local_res = liprpc_run_local_task(node_victim)
assert_eq(local_res, 144, "Victim executed Task 3 locally with result 144 (LIFO order)")
assert_eq(liprpc_queue_len(v_queue), 2, "Victim worker has 2 tasks remaining")

// Thief steals 1 task from victim across simulated LipRPC wire (FIFO order: Task 1)
wire_steal_buf = malloc(256)
mem_fill(wire_steal_buf, 0, 256)

stolen_res = liprpc_steal_from_victim(node_thief, node_victim, wire_steal_buf, 7701)
assert_eq(stolen_res, 49, "Idle thief stole Task 1 and computed 7 * 7 = 49 (FIFO order)")
assert_eq(liprpc_queue_len(v_queue), 1, "Victim queue reduced to 1 task")

thief_stats = get(node_thief, 4)
assert_eq(get(thief_stats, 2), 1, "Thief recorded 1 stolen task in stats")
assert_eq(get(thief_stats, 1), 1, "Thief executed 1 task in stats")

// Victim executes remaining task (Task 2)
last_res = liprpc_run_local_task(node_victim)
assert_eq(last_res, 21, "Victim executed remaining Task 2 (10 * 2 + 1 = 21)")
assert_eq(liprpc_queue_len(v_queue), 0, "Victim queue is now completely drained (0)")

// Thief attempts another steal from drained victim queue
empty_res = liprpc_steal_from_victim(node_thief, node_victim, wire_steal_buf, 7702)
assert_eq(empty_res, 0, "Steal from empty queue gracefully returns 0 (LIPRPC_STATUS_EMPTY)")

free(wire_steal_buf, 256)

say ""
say "-----------------------------------------------------------------"
say "RESULTS: 4/4 sections passed."
say "🎉 ALL LIPRPC & P2P SWARM TESTS PASSED!"
say ""
