@! ============================================================================
@! MAYA SWARM ACTOR TEST SUITE (tests/swarm/test_swarm_actors.maya)
@! Tests:
@! 1. Local & Remote Actor Spawning with globally unique PIDs
@! 2. Asynchronous message passing (actor_send / actor_send_msg)
@! 3. Synchronous RPC request/reply (actor_ask)
@! 4. FIFO Mailbox queuing and batch processing
@! 5. Cross-Node inter-process actor messaging over TCP
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/core/time"
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

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@fn assert_eq(state, name, actual, expected)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str())
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_true(state, name, cond)
  state.total = state.total + 1
  @if cond != 0
    state.passed = state.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " -> condition was false")
    return 0
  @end
@end

@! --- State Actor Handlers ---

@fn counter_actor_handler(msg, state)
  @if msg.msg_type == "ADD"
    return state + msg.payload
  @elif msg.msg_type == "SUB"
    return state - msg.payload
  @elif msg.msg_type == "MULT"
    return state * msg.payload
  @elif msg.msg_type == "GET" || msg.msg_type == "CALL"
    return state
  @end
  return state
@end

@fn queue_audit_handler(msg, state)
  @! Appends msg.payload to state (state is an array)
  state.push(msg.payload)
  return state
@end

@fn main()
  println("=================================================================")
  println("▶ [MAYA SWARM ACTOR SUITE] Erlang/Elixir-Style Actors & Mailboxes")
  println("=================================================================")

  state = { total: 0, passed: 0, failed: 0 }

  base_port = 35000

  @! --------------------------------------------------------------------------
  @! SECTION 1: Local Actor Spawning & PID Verification
  @! --------------------------------------------------------------------------
  println("\n▶ Section 1: Local Actor Spawning & PID")

  node1 = swarm_init("actor-node-1", "127.0.0.1", base_port + 1, base_port)
  assert_true(state, "TC-ACT-01.1: Node 1 initialized", node1.is_running != 0)

  pid1 = actor_spawn(node1, counter_actor_handler, 100)
  assert_eq(state, "TC-ACT-01.2: Actor ID assigned is 1", pid1.actor_id, 1)
  assert_eq(state, "TC-ACT-01.3: Actor Node ID is actor-node-1", pid1.node_id, "actor-node-1")
  assert_eq(state, "TC-ACT-01.4: PID string representation formatted", pid_to_str(pid1), "<PID actor-node-1:1>")

  @! --------------------------------------------------------------------------
  @! SECTION 2: Asynchronous Message Passing (actor_send)
  @! --------------------------------------------------------------------------
  println("\n▶ Section 2: Asynchronous Message Passing & State Accumulation")

  actor_send_msg(node1, pid1, "ADD", 50)
  act1 = actor_table_find(node1.actor_table, pid1.actor_id)
  assert_eq(state, "TC-ACT-02.1: State after ADD 50 is 150", act1.state, 150)

  actor_send_msg(node1, pid1, "SUB", 30)
  assert_eq(state, "TC-ACT-02.2: State after SUB 30 is 120", act1.state, 120)

  actor_send_msg(node1, pid1, "MULT", 3)
  assert_eq(state, "TC-ACT-02.3: State after MULT 3 is 360", act1.state, 360)

  @! --------------------------------------------------------------------------
  @! SECTION 3: Synchronous Request/Reply RPC (actor_ask)
  @! --------------------------------------------------------------------------
  println("\n▶ Section 3: Synchronous Request/Reply RPC (actor_ask)")

  current_val = actor_ask(node1, pid1, "QUERY", 1000)
  assert_eq(state, "TC-ACT-03.1: Synchronous actor_ask returns current accumulated state 360", current_val, 360)

  @! --------------------------------------------------------------------------
  @! SECTION 4: FIFO Mailbox Queuing & Batch Draining
  @! --------------------------------------------------------------------------
  println("\n▶ Section 4: FIFO Mailbox Queuing")

  pid_queue = actor_spawn(node1, queue_audit_handler, [])
  act_q = actor_table_find(node1.actor_table, pid_queue.actor_id)

  @! Temporarily pause actor processing to verify mailbox queue buildup
  act_q.is_running = 0

  actor_send_msg(node1, pid_queue, "PUSH", 11)
  actor_send_msg(node1, pid_queue, "PUSH", 22)
  actor_send_msg(node1, pid_queue, "PUSH", 33)
  actor_send_msg(node1, pid_queue, "PUSH", 44)
  actor_send_msg(node1, pid_queue, "PUSH", 55)

  assert_eq(state, "TC-ACT-04.1: Mailbox queue holds 5 pending messages", queue_size(act_q.mailbox), 5)

  @! Resume and batch drain
  act_q.is_running = 1
  drained = actor_process_mailbox(act_q)

  assert_eq(state, "TC-ACT-04.2: Drained all 5 messages from mailbox", drained, 5)
  assert_eq(state, "TC-ACT-04.3: Mailbox is empty after drain", queue_size(act_q.mailbox), 0)
  assert_eq(state, "TC-ACT-04.4: First item processed was 11 (strict FIFO)", act_q.state[0], 11)
  assert_eq(state, "TC-ACT-04.5: Fifth item processed was 55 (strict FIFO)", act_q.state[4], 55)

  @! --------------------------------------------------------------------------
  @! SECTION 5: Cross-Node Distributed Actor Communication over TCP
  @! --------------------------------------------------------------------------
  println("\n▶ Section 5: Cross-Node Distributed Actor Messaging")

  node2 = swarm_init("actor-node-2", "127.0.0.1", base_port + 2, base_port)
  peer_table_upsert(node1.peer_table, node2.info)
  peer_table_upsert(node2.peer_table, node1.info)

  pid_remote = actor_spawn(node2, counter_actor_handler, 500)
  assert_eq(state, "TC-ACT-05.1: Remote actor created on Node 2", pid_remote.node_id, "actor-node-2")

  @! Connect over TCP from Node 1 to Node 2 to send CAST
  stream = tcp_stream_connect(node2.info.host, node2.info.tcp_port)
  assert_true(state, "TC-ACT-05.2: TCP stream to Node 2 open", stream.fd >= 0)

  msg_cast = actor_message_new(10, pid1, pid_remote, "ADD", 250)
  protocol_send_tcp(stream.fd, MSG_ACTOR_CAST(), serialize_actor_message(msg_cast))
  tcp_stream_close(stream)

  @! Step Node 2 to handle incoming CAST
  swarm_node_step(node2)

  act_remote = actor_table_find(node2.actor_table, pid_remote.actor_id)
  assert_eq(state, "TC-ACT-05.3: Remote actor processed TCP CAST (500 + 250 = 750)", act_remote.state, 750)

  @! Send Synchronous CALL from Node 1 to Node 2 over TCP
  stream_call = tcp_stream_connect(node2.info.host, node2.info.tcp_port)
  msg_call = actor_message_new(11, pid1, pid_remote, "CALL", 0)
  protocol_send_tcp(stream_call.fd, MSG_ACTOR_CALL(), serialize_actor_message(msg_call))

  @! Step Node 2 to process CALL and reply
  swarm_node_step(node2)

  reply_pkt = protocol_recv_tcp(stream_call.fd)
  tcp_stream_close(stream_call)

  assert_eq(state, "TC-ACT-05.4: Reply packet valid", reply_pkt.valid, 1)
  assert_eq(state, "TC-ACT-05.5: Reply packet is MSG_ACTOR_REPLY", reply_pkt.msg_type, MSG_ACTOR_REPLY())

  reply_msg = deserialize_actor_message(reply_pkt.payload)
  assert_eq(state, "TC-ACT-05.6: Synchronous cross-node RPC returned state 750", reply_msg.payload, 750)

  swarm_shutdown(node1)
  swarm_shutdown(node2)

  println("\n=================================================================")
  println("📊 SWARM ACTOR SUITE SUMMARY: " + state.passed.to_str() + "/" + state.total.to_str() + " passed")
  println("=================================================================")

  @if state.failed == 0
    println("✓ ALL SWARM ACTOR TESTS PASSED")
    return 0
  @else
    println("✗ SOME SWARM ACTOR TESTS FAILED")
    return 1
  @end
@end
