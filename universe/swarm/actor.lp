@! ============================================================================
@! MAYA SWARM — DISTRIBUTED ACTOR MODEL (universe/swarm/actor.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Erlang/Elixir-Style Actors, Mailboxes, PIDs, actor_send(), actor_ask() RPC
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/core/time"
import "universe/net/tcp"
import "universe/swarm/types"
import "universe/swarm/protocol"
import "universe/swarm/serializer"
import "universe/swarm/discovery"

@! ----------------------------------------------------------------------------
@! 1. Swarm Actor & Future Data Structures
@! ----------------------------------------------------------------------------

@struct SwarmActor
  pid: PID
  handler_fn: any
  state: any
  mailbox: Queue
  is_running: i64
@end

@struct SwarmFuture
  future_id: i64
  completed: i64
  result: any
  timeout_at: i64
@end

@struct ActorTable
  actors: array
  next_actor_id: i64
  next_msg_id: i64
  futures: array
  next_future_id: i64
  current_actor_pid: PID
@end

@fn actor_table_new()
  return {
    actors: [],
    next_actor_id: 1,
    next_msg_id: 1,
    futures: [],
    next_future_id: 1,
    current_actor_pid: { node_id: "local", actor_id: 0, is_remote: 0 }
  }
@end

@fn actor_table_register(table, act)
  table.actors.push(act)
  return act
@end

@fn actor_table_find(table, actor_id)
  i = 0
  num_items = table.actors.len()
  @while i < num_items
    a = table.actors[i]
    @if a.pid.actor_id == actor_id
      return a
    @end
    i = i + 1
  @end
  return 0
@end

@fn actor_table_create_future(table, timeout_ms)
  fid = table.next_future_id
  table.next_future_id = table.next_future_id + 1
  now = clock_ms()
  fut = {
    future_id: fid,
    completed: 0,
    result: 0,
    timeout_at: now + timeout_ms
  }
  table.futures.push(fut)
  return fut
@end

@fn actor_table_resolve_future(table, future_id, res)
  i = 0
  num_items = table.futures.len()
  @while i < num_items
    f = table.futures[i]
    @if f.future_id == future_id
      f.result = res
      f.completed = 1
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn actor_table_get_future(table, future_id)
  i = 0
  num_items = table.futures.len()
  @while i < num_items
    f = table.futures[i]
    @if f.future_id == future_id
      return f
    @end
    i = i + 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 2. Actor Lifecycle & Local Dispatching
@! ----------------------------------------------------------------------------

@fn actor_create(table, local_node_id, handler_fn, initial_state)
  actor_id = table.next_actor_id
  table.next_actor_id = table.next_actor_id + 1

  q = queue_new()
  act = {
    pid: { node_id: local_node_id, actor_id: actor_id, is_remote: 0 },
    handler_fn: handler_fn,
    state: initial_state,
    mailbox: q,
    is_running: 1
  }
  actor_table_register(table, act)
  return act
@end

@fn actor_deliver_local(act, msg)
  queue_enqueue(act.mailbox, msg)

  @! Process message with handler function if running
  @if act.is_running != 0 && act.handler_fn != 0
    dq = queue_dequeue(act.mailbox)
    next_msg = dq.dq_val
    h = act.handler_fn
    new_state = h(next_msg, act.state)
    act.state = new_state
    return act.state
  @end
  return 0
@end

@fn actor_process_mailbox(act)
  count = 0
  @while queue_is_empty(act.mailbox) == 0 && act.is_running != 0
    dq = queue_dequeue(act.mailbox)
    msg = dq.dq_val
    @if act.handler_fn != 0
      h = act.handler_fn
      new_state = h(msg, act.state)
      act.state = new_state
      count = count + 1
    @end
  @end
  return count
@end

@! ----------------------------------------------------------------------------
@! 3. Actor Message Passing & RPC Functions
@! ----------------------------------------------------------------------------

@fn actor_dispatch_send(table, local_node_id, target_pid: PID, msg_type, msg_payload, peer_table)
  mid = table.next_msg_id
  table.next_msg_id = table.next_msg_id + 1

  sender_pid = table.current_actor_pid
  msg = actor_message_new(mid, sender_pid, target_pid, msg_type, msg_payload)

  @! Local delivery
  @if target_pid.node_id == local_node_id || target_pid.is_remote == 0
    target_act = actor_table_find(table, target_pid.actor_id)
    @if target_act != 0
      actor_deliver_local(target_act, msg)
      return 1
    @end
    return 0
  @end

  @! Remote delivery via TCP
  @if peer_table != 0
    peer = peer_table_find(peer_table, target_pid.node_id)
    @if peer != 0
      stream = tcp_stream_connect(peer.host, peer.tcp_port)
      @if stream.fd >= 0
        msg_str = serialize_actor_message(msg)
        protocol_send_tcp(stream.fd, MSG_ACTOR_CAST(), msg_str)
        tcp_stream_close(stream)
        return 1
      @end
    @end
  @end

  return 0
@end

@fn actor_dispatch_ask(table, local_node_id, target_pid: PID, request_payload, timeout_ms, peer_table)
  mid = table.next_msg_id
  table.next_msg_id = table.next_msg_id + 1

  sender_pid = table.current_actor_pid
  msg = actor_message_new(mid, sender_pid, target_pid, "CALL", request_payload)

  @! Local synchronous call
  @if target_pid.node_id == local_node_id || target_pid.is_remote == 0
    target_act = actor_table_find(table, target_pid.actor_id)
    @if target_act != 0
      @if target_act.handler_fn != 0
        h = target_act.handler_fn
        res = h(msg, target_act.state)
        return res
      @end
    @end
    return 0
  @end

  @! Remote synchronous RPC call via TCP
  @if peer_table != 0
    peer = peer_table_find(peer_table, target_pid.node_id)
    @if peer != 0
      stream = tcp_stream_connect(peer.host, peer.tcp_port)
      @if stream.fd >= 0
        msg_str = serialize_actor_message(msg)
        protocol_send_tcp(stream.fd, MSG_ACTOR_CALL(), msg_str)

        @! Wait for response packet
        resp_pkt = protocol_recv_tcp(stream.fd)
        tcp_stream_close(stream)

        @if resp_pkt.valid == 1 && resp_pkt.msg_type == MSG_ACTOR_REPLY()
          reply_msg = deserialize_actor_message(resp_pkt.payload)
          return reply_msg.payload
        @end
      @end
    @end
  @end

  return 0
@end
