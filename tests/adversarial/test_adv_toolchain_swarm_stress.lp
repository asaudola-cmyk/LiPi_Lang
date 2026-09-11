@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE: MAYA SWARM DISTRIBUTED ACTOR SYSTEM
@! File: tests/adversarial/test_adv_toolchain_swarm_stress.maya
@! Focus: Framing corruption, CRC32 tamper detection, serializer escapes & bounds,
@!        high-throughput FIFO actor mailboxes, and load routing heuristics
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/swarm/types"
import "universe/swarm/protocol"
import "universe/swarm/serializer"
import "universe/swarm/discovery"
import "universe/swarm/router"
import "universe/swarm/actor"

@struct AdvSwarmTestContext
  total: i64
  passed: i64
  failed: i64
@end

@fn assert_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str())
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_str_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got \"" + actual + "\"")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
@end

@fn assert_true(ctx, name, cond)
  ctx.total = ctx.total + 1
  @if cond != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was false")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🔥 [ADVERSARIAL SUITE 2] SWARM PROTOCOL, CRC32, ACTOR & ROUTER STRESS")
  println("=================================================================")

  ctx = { total: 0, passed: 0, failed: 0 }

  @! --------------------------------------------------------------------------
  @! SECTION 1: CRC32 Polynomial Correctness & Tamper Detection
  @! --------------------------------------------------------------------------
  println("\n▶ Section 1: CRC32 Standard Checksums & Bitflip Resistance")

  @! Standard CRC32 vector for "123456789" = 0xCBF43926 (3421780262)
  crc_std = compute_crc32("123456789")
  assert_eq(ctx, "ADV-CRC-01: Standard vector CRC32('123456789') == 0xCBF43926", crc_std, 3421780262)

  @! Empty string CRC32
  crc_empty = compute_crc32("")
  assert_eq(ctx, "ADV-CRC-02: CRC32('') is 0", crc_empty, 0)

  @! Single character difference produces radically different CRC
  crc_a = compute_crc32("maya_swarm_node_alpha")
  crc_b = compute_crc32("maya_swarm_node_alphb")
  assert_true(ctx, "ADV-CRC-03: Single character change alters CRC32", crc_a != crc_b)

  @! --------------------------------------------------------------------------
  @! SECTION 2: Binary Byte Packet Framing & Corruptions
  @! --------------------------------------------------------------------------
  println("\n▶ Section 2: Binary Byte Packet Framing & Corruptions")

  raw_payload = "DISTRIBUTED_ACTOR_PAYLOAD_TEST_42"
  encoded_bytes = protocol_encode_bytes(MSG_TASK_SUBMIT(), raw_payload)

  @! Valid decode
  dec_valid = protocol_decode_bytes(encoded_bytes)
  assert_eq(ctx, "ADV-FRAME-01: Valid packet decodes successfully", dec_valid.valid, 1)
  assert_eq(ctx, "ADV-FRAME-02: Decoded magic matches 0x5357", dec_valid.magic, 21335)
  assert_eq(ctx, "ADV-FRAME-03: Decoded version matches 1", dec_valid.version, 1)
  assert_eq(ctx, "ADV-FRAME-04: Decoded msg_type is MSG_TASK_SUBMIT (4)", dec_valid.msg_type, 4)
  assert_str_eq(ctx, "ADV-FRAME-05: Payload verified verbatim", dec_valid.payload, raw_payload)

  @! Test 2.1: Truncated header (< 12 bytes)
  short_buf = [83, 87, 1, 4, 0, 0]
  dec_short = protocol_decode_bytes(short_buf)
  assert_eq(ctx, "ADV-FRAME-06: Truncated buffer (<12 bytes) rejected", dec_short.valid, 0)

  @! Test 2.2: Bad Magic header (0x00 0x00)
  bad_magic = []
  i = 0
  @while i < encoded_bytes.len()
    @if i == 0 || i == 1
      bad_magic.push(0)
    @else
      bad_magic.push(encoded_bytes[i])
    @end
    i = i + 1
  @end
  dec_bad_magic = protocol_decode_bytes(bad_magic)
  assert_eq(ctx, "ADV-FRAME-07: Bad magic bytes rejected", dec_bad_magic.valid, 0)

  @! Test 2.3: Unsupported version (version = 99)
  bad_ver = []
  i = 0
  @while i < encoded_bytes.len()
    @if i == 2
      bad_ver.push(99)
    @else
      bad_ver.push(encoded_bytes[i])
    @end
    i = i + 1
  @end
  dec_bad_ver = protocol_decode_bytes(bad_ver)
  assert_eq(ctx, "ADV-FRAME-08: Unsupported version rejected", dec_bad_ver.valid, 0)

  @! Test 2.4: Payload length claims more than buffer contains
  bad_len = []
  i = 0
  @while i < encoded_bytes.len()
    @if i == 7
      bad_len.push(255) @! Inflate low byte of length
    @else
      bad_len.push(encoded_bytes[i])
    @end
    i = i + 1
  @end
  dec_bad_len = protocol_decode_bytes(bad_len)
  assert_eq(ctx, "ADV-FRAME-09: Overstated payload length rejected", dec_bad_len.valid, 0)

  @! Test 2.5: Checksum bitflip in payload
  corrupt_payload = []
  i = 0
  @while i < encoded_bytes.len()
    @if i == 15 @! Flip byte in payload
      corrupt_payload.push((encoded_bytes[i] ^ 0xFF) & 255)
    @else
      corrupt_payload.push(encoded_bytes[i])
    @end
    i = i + 1
  @end
  dec_corrupt = protocol_decode_bytes(corrupt_payload)
  assert_eq(ctx, "ADV-FRAME-10: Bitflipped payload rejected by CRC32 check", dec_corrupt.valid, 0)

  @! --------------------------------------------------------------------------
  @! SECTION 3: Deep Serializer & Escape Sequence Stress
  @! --------------------------------------------------------------------------
  println("\n▶ Section 3: Deep Serializer & Escape Sequence Stress")

  @! Test 3.1: Strings with complex escapes in JSON tokenizer
  esc_json_raw = "{\"key\":\"line1\\nline2\\t\\\"quoted\\\"\\\\backslash\"}"
  tokens = swarm_json_tokenize(esc_json_raw)
  assert_eq(ctx, "ADV-SER-01: JSON tokenizer produces 5 tokens for key-value pair", tokens.len(), 5)
  entries = parse_json_object(tokens)
  val_parsed = json_get_str(entries, "key")
  assert_true(ctx, "ADV-SER-02: String contains decoded newline", str_index_of(val_parsed, "\n") >= 0)
  assert_true(ctx, "ADV-SER-03: String contains decoded tab", str_index_of(val_parsed, "\t") >= 0)
  assert_true(ctx, "ADV-SER-04: String contains decoded quote", str_index_of(val_parsed, "\"") >= 0)

  @! Test 3.2: PID Serialization Roundtrip
  pid_test = pid_new("cluster_node_42", 1007, 1)
  ser_pid = serialize_pid(pid_test)
  deser_pid = deserialize_pid(ser_pid)
  assert_str_eq(ctx, "ADV-SER-05: Deserialized PID node_id matches", deser_pid.node_id, "cluster_node_42")
  assert_eq(ctx, "ADV-SER-06: Deserialized PID actor_id matches", deser_pid.actor_id, 1007)
  assert_eq(ctx, "ADV-SER-07: Deserialized PID is_remote matches", deser_pid.is_remote, 1)

  @! Test 3.3: Task Descriptor Serialization Roundtrip
  desc = task_descriptor_new(987654321, "cluster_matrix_mul", [10, 20, 30], "node_alpha_master", 555)
  ser_desc = serialize_task_descriptor(desc)
  deser_desc = deserialize_task_descriptor(ser_desc)
  assert_eq(ctx, "ADV-SER-08: Deserialized task_id matches", deser_desc.task_id, 987654321)
  assert_str_eq(ctx, "ADV-SER-09: Deserialized func_name matches", deser_desc.func_name, "cluster_matrix_mul")
  assert_str_eq(ctx, "ADV-SER-10: Deserialized origin_node matches", deser_desc.origin_node, "node_alpha_master")
  assert_eq(ctx, "ADV-SER-11: Deserialized origin_future_id matches", deser_desc.origin_future_id, 555)

  @! Test 3.4: NodeInfo Serialization Roundtrip
  ninfo = node_info_new("p2p_worker_99", "192.168.1.50", 9876, 9877, 15, 12345678, "ALIVE")
  ser_ninfo = serialize_node_info(ninfo)
  deser_ninfo = deserialize_node_info(ser_ninfo)
  assert_str_eq(ctx, "ADV-SER-12: Deserialized node_id matches", deser_ninfo.node_id, "p2p_worker_99")
  assert_str_eq(ctx, "ADV-SER-13: Deserialized host matches", deser_ninfo.host, "192.168.1.50")
  assert_eq(ctx, "ADV-SER-14: Deserialized tcp_port matches", deser_ninfo.tcp_port, 9876)
  assert_eq(ctx, "ADV-SER-15: Deserialized load matches", deser_ninfo.load, 15)
  assert_str_eq(ctx, "ADV-SER-16: Deserialized status matches", deser_ninfo.status, "ALIVE")

  @! --------------------------------------------------------------------------
  @! SECTION 4: High-Volume Actor Mailbox & FIFO Ordering
  @! --------------------------------------------------------------------------
  println("\n▶ Section 4: High-Volume Actor Mailbox & Strict FIFO Ordering")

  tbl = actor_table_new()
  act_pid = pid_new("local_node", 1, 0)

  test_actor = {
    pid: act_pid,
    handler_fn: 0,
    state: 0,
    mailbox: queue_new(),
    is_running: 1
  }
  actor_table_register(tbl, test_actor)

  @! Push 100 messages into the actor's mailbox rapidly
  msg_idx = 1
  @while msg_idx <= 100
    msg = actor_message_new(msg_idx, pid_new("sender", 99, 0), act_pid, "CAST", msg_idx * 10)
    queue_enqueue(test_actor.mailbox, msg)
    msg_idx = msg_idx + 1
  @end

  assert_eq(ctx, "ADV-ACTOR-01: Mailbox size is 100", queue_size(test_actor.mailbox), 100)

  @! Verify strict FIFO order when dequeuing all 100 messages
  fifo_ok = 1
  pop_idx = 1
  @while queue_is_empty(test_actor.mailbox) == 0
    dq = queue_dequeue(test_actor.mailbox)
    dequeued = dq.dq_val
    expected_payload = pop_idx * 10
    @if dequeued.payload != expected_payload || dequeued.msg_id != pop_idx
      fifo_ok = 0
    @end
    pop_idx = pop_idx + 1
  @end

  assert_eq(ctx, "ADV-ACTOR-02: Strict FIFO order preserved across 100 messages", fifo_ok, 1)
  assert_eq(ctx, "ADV-ACTOR-03: Mailbox is empty after draining", queue_size(test_actor.mailbox), 0)

  @! Test 4.2: Actor Table lookup safety
  found_act = actor_table_find(tbl, 1)
  assert_true(ctx, "ADV-ACTOR-04: Existing actor found in table", found_act != 0)

  bad_act = actor_table_find(tbl, 9999)
  assert_eq(ctx, "ADV-ACTOR-05: Non-existent actor lookup returns 0 safely", bad_act, 0)

  @! --------------------------------------------------------------------------
  @! SECTION 5: Dynamic Load Router Heuristics & Metrics
  @! --------------------------------------------------------------------------
  println("\n▶ Section 5: Dynamic Load Router Decision Engine")

  mon = load_monitor_new(4)
  assert_eq(ctx, "ADV-ROUTER-01: Initial load is 0", load_monitor_get_load(mon), 0)

  load_monitor_inc_active(mon)
  load_monitor_inc_active(mon)
  load_monitor_inc_pending(mon)
  assert_eq(ctx, "ADV-ROUTER-02: Load matches 2 active + 1 pending = 3", load_monitor_get_load(mon), 3)

  @! Routing when load (3) is below threshold (4)
  p_table = peer_table_new()
  dec_low = router_decide("AUTO", load_monitor_get_load(mon), p_table, mon.load_threshold)
  assert_str_eq(ctx, "ADV-ROUTER-03: Below threshold routes LOCAL", dec_low.destination, "LOCAL")

  @! Add more load so load = 6 >= threshold (4), but peer table has no peers
  load_monitor_inc_active(mon)
  load_monitor_inc_active(mon)
  load_monitor_inc_active(mon)
  assert_eq(ctx, "ADV-ROUTER-04: Elevated load is 6", load_monitor_get_load(mon), 6)

  dec_no_peers = router_decide("AUTO", load_monitor_get_load(mon), p_table, mon.load_threshold)
  assert_str_eq(ctx, "ADV-ROUTER-05: High load with no remote peers falls back to LOCAL", dec_no_peers.destination, "LOCAL")

  @! Add remote idle peer to peer table
  peer_worker = node_info_new("worker_idle_node", "10.0.0.2", 9876, 9877, 1, 100, "ALIVE")
  peer_table_upsert(p_table, peer_worker)

  dec_routed_remote = router_decide("AUTO", load_monitor_get_load(mon), p_table, mon.load_threshold)
  assert_str_eq(ctx, "ADV-ROUTER-06: High load routes REMOTE to idle peer", dec_routed_remote.destination, "REMOTE")
  assert_str_eq(ctx, "ADV-ROUTER-07: Remote target is worker_idle_node", dec_routed_remote.target_node.node_id, "worker_idle_node")

  println("=================================================================")
  println("📊 ADVERSARIAL SWARM SUITE SUMMARY")
  println("=================================================================")
  println("Total Assertions: " + ctx.total.to_str())
  println("Passed          : " + ctx.passed.to_str())
  println("Failed          : " + ctx.failed.to_str())
  println("=================================================================")

  @if ctx.failed == 0
    println("🎉 ALL ADVERSARIAL SWARM TESTS PASSED! 🎉")
  @else
    println("❌ SOME ADVERSARIAL SWARM TESTS FAILED!")
  @end
@end
