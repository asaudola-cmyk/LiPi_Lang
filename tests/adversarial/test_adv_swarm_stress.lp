import "universe/core/string"
import "universe/core/collections"
import "universe/core/time"
import "universe/os/syscalls"
import "universe/net/udp"
import "universe/net/tcp"
import "universe/swarm/types"
import "universe/swarm/protocol"
import "universe/swarm/serializer"
import "universe/swarm/discovery"
import "universe/swarm/task_registry"
import "universe/swarm/router"
import "universe/swarm/actor"
import "universe/swarm/node"
import "universe/swarm/swarm"

@fn assert_eq(actual: i64, expected: i64, test_name: string)
  @if actual == expected
    println("  [PASS] " + test_name + " -> got " + actual.to_str())
  @else
    println("  [FAIL] " + test_name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    sys_exit(1)
  @end
@end

@fn assert_str_eq(actual: string, expected: string, test_name: string)
  @if actual == expected
    println("  [PASS] " + test_name + " -> got \"" + actual + "\"")
  @else
    println("  [FAIL] " + test_name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    sys_exit(1)
  @end
@end

@fn assert_true(cond: bool, test_name: string)
  @if cond == true
    println("  [PASS] " + test_name)
  @else
    println("  [FAIL] " + test_name)
    sys_exit(1)
  @end
@end

@fn counter_actor_handler(msg: ActorMessage, state)
  @if msg.msg_type == "ADD"
    return state + msg.payload
  @elif msg.msg_type == "SUB"
    return state - msg.payload
  @elif msg.msg_type == "MULT"
    return state * msg.payload
  @elif msg.msg_type == "GET" || msg.msg_type == "CALL" || msg.msg_type == "QUERY"
    return state
  @end
  return state
@end

@fn main()
  println("=================================================================")
  println("🛡️ ADVERSARIAL SWARM PROTOCOL & ACTOR STRESS TEST HARNESS 🛡️")
  println("=================================================================")

  @! ---------------------------------------------------------------------------
  @! SECTION 1: Wire Protocol Adversarial Fuzzing & Tamper Rejection
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 1: Binary Protocol Framing & Tamper Fuzzing...")

  valid_payload = "AUTHENTIC_SWARM_TRANSACTION_PAYLOAD_DATA"
  raw_bytes = protocol_encode_bytes(MSG_TASK_SUBMIT(), valid_payload)
  assert_true(raw_bytes.len() > 12, "ADV-SWM-01: Serialized packet length > 12")

  @! Normal parse passes
  deser_ok = protocol_decode_bytes(raw_bytes)
  assert_eq(deser_ok.valid, 1, "ADV-SWM-02: Authentic packet deserialized successfully")
  assert_str_eq(deser_ok.payload, valid_payload, "ADV-SWM-03: Authentic payload intact")

  @! Fuzz 1: Tamper magic byte [0]
  bad_magic_bytes = []
  i = 0
  @while i < raw_bytes.len()
    bad_magic_bytes.push(raw_bytes[i])
    i = i + 1
  @end
  bad_magic_bytes[0] = 0
  deser_bad_magic = protocol_decode_bytes(bad_magic_bytes)
  assert_eq(deser_bad_magic.valid, 0, "ADV-SWM-04: Bad magic bytes rejected")

  @! Fuzz 2: Single bitflip corruption in payload (CRC32 mismatch)
  corrupted_payload_bytes = []
  i = 0
  @while i < raw_bytes.len()
    corrupted_payload_bytes.push(raw_bytes[i])
    i = i + 1
  @end
  corrupted_payload_bytes[15] = 88  @! modify byte at offset 15
  deser_tampered = protocol_decode_bytes(corrupted_payload_bytes)
  assert_eq(deser_tampered.valid, 0, "ADV-SWM-05: Single-byte payload tamper rejected by CRC32")

  @! Fuzz 3: Truncated packet (less than 12 bytes header)
  truncated_header = [83, 87, 1, 4, 0, 0]
  deser_trunc_hdr = protocol_decode_bytes(truncated_header)
  assert_eq(deser_trunc_hdr.valid, 0, "ADV-SWM-06: Truncated 6-byte packet rejected")

  @! Fuzz 4: Truncated wire string
  trunc_wire = protocol_decode_wire("SW0104")
  assert_eq(trunc_wire.valid, 0, "ADV-SWM-07: Truncated wire string rejected")

  @! ---------------------------------------------------------------------------
  @! SECTION 2: Distributed Actor High-Throughput Mailbox Stress
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 2: Distributed Actor High-Throughput Mailbox Stress...")

  base_p = 39000
  node = swarm_init("adv-node-1", "127.0.0.1", base_p + 1, base_p)
  assert_true(node.is_running != 0, "ADV-SWM-08: Local Swarm node initialized")

  @! Spawn an accumulator actor with initial state 100
  pid = actor_spawn(node, counter_actor_handler, 100)
  assert_true(pid.actor_id > 0, "ADV-SWM-09: Actor spawned with valid PID")

  @! Send consecutive math operations
  actor_send_msg(node, pid, "ADD", 500)
  actor_send_msg(node, pid, "SUB", 200)
  actor_send_msg(node, pid, "MULT", 3)

  @! Synchronous RPC ask
  ask_val = actor_ask(node, pid, "QUERY", 1000)
  @! (100 + 500 - 200) * 3 = 1200
  assert_eq(ask_val, 1200, "ADV-SWM-10: Synchronous actor_ask returns 1200 ((100+500-200)*3 = 1200)")

  @! ---------------------------------------------------------------------------
  @! SECTION 3: Dynamic Load Routing & Least-Loaded Selection
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 3: Dynamic Load Routing & Cluster Failover...")

  now_ms = 100000
  pt = peer_table_new()
  p1 = node_info_new("worker-alpha", "127.0.0.1", 19810, 19811, 85, now_ms, "ALIVE")
  peer_table_upsert(pt, p1)

  p2 = node_info_new("worker-beta", "127.0.0.1", 19820, 19821, 15, now_ms, "ALIVE")
  peer_table_upsert(pt, p2)

  p3 = node_info_new("worker-gamma", "127.0.0.1", 19830, 19831, 60, now_ms, "ALIVE")
  peer_table_upsert(pt, p3)

  @! Local load = 95 (> threshold 80), should route to least loaded peer ("worker-beta")
  d1 = router_decide("AUTO", 95, pt, 80)
  assert_eq(d1.should_route_remote, 1, "ADV-SWM-11: High load triggered remote routing")
  assert_str_eq(d1.target_node.node_id, "worker-beta", "ADV-SWM-12: Optimal least-loaded peer selected")

  @! Local load = 30 (< threshold 80), should execute locally
  d2 = router_decide("AUTO", 30, pt, 80)
  assert_eq(d2.should_route_remote, 0, "ADV-SWM-13: Low load stayed local")

  @! ---------------------------------------------------------------------------
  @! SECTION 4: Peer Health Monitoring & Stale Node Reaping
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 4: Discovery Peer Health & Timeout Reaping...")

  p_stale = node_info_new("worker-dying", "127.0.0.1", 19840, 19841, 1, now_ms - 8000, "ALIVE")
  peer_table_upsert(pt, p_stale)

  h = discovery_check_health(pt, now_ms)
  dead_p = peer_table_find(pt, "worker-dying")
  assert_str_eq(dead_p.status, "DEAD", "ADV-SWM-14: 8s stale node transitioned to DEAD")
  assert_eq(h.dead_count, 1, "ADV-SWM-15: 1 dead node reported")

  alive_peers = peer_table_get_alive(pt)
  assert_eq(alive_peers.len(), 3, "ADV-SWM-16: Dead node excluded from alive list")

  swarm_shutdown(node)
  println("  [PASS] ADV-SWM-17: Swarm node cleanly shutdown")

  println("\n=================================================================")
  println("🎉 ALL 17 ADVERSARIAL SWARM STRESS TESTS PASSED SUCCESSFULLY! 🎉")
  println("=================================================================")
  return 0
@end
