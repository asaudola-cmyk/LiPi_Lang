@! ============================================================================
@! MAYA SWARM — NODE DAEMON & CLUSTER COORDINATOR (universe/swarm/node.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Integrates UDP Discovery, TCP RPC Server, Actor Routing & Task Execution
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

@! ----------------------------------------------------------------------------
@! 1. SwarmNode Data Structure & Construction
@! ----------------------------------------------------------------------------

@struct SwarmNode
  info: NodeInfo
  cluster_name: string
  udp_sock: UdpSocket
  tcp_listener_fd: i64
  peer_table: PeerTable
  task_registry: TaskRegistry
  actor_table: ActorTable
  load_monitor: LoadMonitor
  futures: array
  is_running: i64
  last_beacon_ms: i64
  last_health_ms: i64
  next_task_id: i64
  next_future_id: i64
@end

@fn swarm_node_new(node_id, host, tcp_port, udp_port, cluster_name)
  info = node_info_new(node_id, host, tcp_port, udp_port, 0, clock_ms(), "ALIVE")
  table = peer_table_new()
  tasks = task_registry_new()
  actors = actor_table_new()
  mon = load_monitor_new(2)

  u_sock = { fd: -1, bound_port: udp_port, is_broadcast: 0 }

  return {
    info: info,
    cluster_name: cluster_name,
    udp_sock: u_sock,
    tcp_listener_fd: -1,
    peer_table: table,
    task_registry: tasks,
    actor_table: actors,
    load_monitor: mon,
    futures: [],
    is_running: 0,
    last_beacon_ms: 0,
    last_health_ms: 0,
    next_task_id: 1,
    next_future_id: 1
  }
@end

@! ----------------------------------------------------------------------------
@! 2. SwarmNode Lifecycle (Start, Stop, Step)
@! ----------------------------------------------------------------------------

@fn swarm_node_start(node)
  @! Bind UDP discovery socket with SO_REUSEPORT & broadcast enabled
  node.udp_sock = udp_socket_bind("0.0.0.0", node.info.udp_port, 1)

  @! Bind TCP listener
  t_fd = tcp_socket_new()
  tcp_bind(t_fd, node.info.host, node.info.tcp_port)
  tcp_listen(t_fd, 128)

  @! Configure non-blocking TCP listener for reactive event multiplexing
  flags = sys_fcntl(t_fd, 3, 0)
  sys_fcntl(t_fd, 4, flags + 2048)

  node.tcp_listener_fd = t_fd
  node.is_running = 1

  @! Update actor table current local PID
  node.actor_table.current_actor_pid = {
    node_id: node.info.node_id,
    actor_id: 0,
    is_remote: 0
  }

  @! Emit initial cluster discovery beacons
  discovery_broadcast_beacon(node.udp_sock, node.info, "255.255.255.255", node.info.udp_port)
  discovery_broadcast_beacon(node.udp_sock, node.info, "127.0.0.1", node.info.udp_port)
  node.last_beacon_ms = clock_ms()
  node.last_health_ms = clock_ms()

  return node
@end

@fn swarm_node_broadcast_beacon(node, target_host, target_port)
  @if node.udp_sock.fd >= 0
    node.info.load = load_monitor_get_load(node.load_monitor)
    discovery_broadcast_beacon(node.udp_sock, node.info, target_host, target_port)
    return 1
  @end
  return 0
@end

@fn swarm_node_step(node)
  @if node.is_running == 0 return 0 @end
  now = clock_ms()

  @! 1. Poll incoming UDP discovery beacons
  discovery_poll_beacons(node.udp_sock, node.peer_table, node.info.node_id)

  @! 2. Periodic discovery beacon heartbeat (every 1000ms)
  @if now - node.last_beacon_ms >= 1000
    swarm_node_broadcast_beacon(node, "255.255.255.255", node.info.udp_port)
    swarm_node_broadcast_beacon(node, "127.0.0.1", node.info.udp_port)
    node.last_beacon_ms = now
  @end

  @! 3. Periodic health and failure detection check (every 1500ms)
  @if now - node.last_health_ms >= 1500
    discovery_check_health(node.peer_table, now)
    node.last_health_ms = now
  @end

  @! 4. Poll and process TCP incoming RPC connections
  c_fd = tcp_accept(node.tcp_listener_fd)
  @if c_fd >= 0
    pkt = protocol_recv_tcp(c_fd)
    @if pkt.valid == 1
      @if pkt.msg_type == MSG_TASK_SUBMIT()
        desc = deserialize_task_descriptor(pkt.payload)
        arg0 = 0
        @if desc.args.len() > 0 arg0 = desc.args[0] @end

        load_monitor_inc_active(node.load_monitor)
        res_val = task_registry_invoke(node.task_registry, desc.func_name, arg0)
        load_monitor_dec_active(node.load_monitor)

        resp_join_h = swarm_join_handle_new(desc.task_id, 0, 0, node.info.node_id, desc.origin_future_id)
        resp_join_h.completed = 1
        resp_join_h.result = res_val

        resp_str = serialize_join_handle(resp_join_h)
        protocol_send_tcp(c_fd, MSG_TASK_RESULT(), resp_str)
      @elif pkt.msg_type == MSG_ACTOR_CAST()
        msg = deserialize_actor_message(pkt.payload)
        target_act = actor_table_find(node.actor_table, msg.target.actor_id)
        @if target_act != 0
          actor_deliver_local(target_act, msg)
        @end
      @elif pkt.msg_type == MSG_ACTOR_CALL()
        msg = deserialize_actor_message(pkt.payload)
        target_act = actor_table_find(node.actor_table, msg.target.actor_id)
        reply_val = 0
        @if target_act != 0
          @if target_act.handler_fn != 0
            h = target_act.handler_fn
            reply_val = h(msg, target_act.state)
          @end
        @end
        reply_msg = actor_message_new(msg.msg_id, msg.target, msg.sender, "REPLY", reply_val)
        protocol_send_tcp(c_fd, MSG_ACTOR_REPLY(), serialize_actor_message(reply_msg))
      @elif pkt.msg_type == MSG_GOSSIP_REQ()
        table_str = serialize_peer_table(node.peer_table)
        protocol_send_tcp(c_fd, MSG_GOSSIP_RESP(), table_str)
      @elif pkt.msg_type == MSG_HEARTBEAT()
        protocol_send_tcp(c_fd, MSG_HEARTBEAT_ACK(), "OK")
      @end
    @end
    tcp_close(c_fd)
  @end

  return 1
@end

@fn swarm_node_stop(node)
  @if node.is_running == 1
    node.is_running = 0
    @if node.udp_sock.fd >= 0
      udp_socket_close(node.udp_sock)
    @end
    @if node.tcp_listener_fd >= 0
      tcp_close(node.tcp_listener_fd)
      node.tcp_listener_fd = -1
    @end
  @end
  return node
@end

@! ----------------------------------------------------------------------------
@! 3. Remote Task Execution & Future Resolution
@! ----------------------------------------------------------------------------

@fn swarm_node_submit_remote_task(node, target_peer, task_name, arg)
  tid = node.next_task_id
  node.next_task_id = node.next_task_id + 1

  fid = node.next_future_id
  node.next_future_id = node.next_future_id + 1

  desc = task_descriptor_new(tid, task_name, [arg], node.info.node_id, fid)

  stream = tcp_stream_connect(target_peer.host, target_peer.tcp_port)
  @if stream.fd < 0
    println("[SwarmNode] Error: Failed to connect to remote peer " + target_peer.node_id + " at " + target_peer.host + ":" + target_peer.tcp_port.to_str())
    return swarm_join_handle_new(tid, 1, 0, target_peer.node_id, fid)
  @end

  desc_str = serialize_task_descriptor(desc)
  protocol_send_tcp(stream.fd, MSG_TASK_SUBMIT(), desc_str)

  @! Receive task execution result
  resp_pkt = protocol_recv_tcp(stream.fd)
  tcp_stream_close(stream)

  @if resp_pkt.valid == 1 && resp_pkt.msg_type == MSG_TASK_RESULT()
    join_res = deserialize_join_handle(resp_pkt.payload)
    join_res.is_remote = 1
    join_res.remote_node = target_peer.node_id
    join_res.future_id = fid
    return join_res
  @end

  println("[SwarmNode] Warning: Remote task submission received invalid or empty response")
  return swarm_join_handle_new(tid, 1, 0, target_peer.node_id, fid)
@end

@fn swarm_node_await_future(node, future_id, timeout_ms)
  start_ms = clock_ms()
  @while clock_ms() - start_ms < timeout_ms
    swarm_node_step(node)
    fut = actor_table_get_future(node.actor_table, future_id)
    @if fut != 0 && fut.completed != 0
      return fut.result
    @end
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 4. Actor Operations Bridge
@! ----------------------------------------------------------------------------

@fn swarm_node_spawn_actor(node, handler_fn, initial_state)
  act = actor_create(node.actor_table, node.info.node_id, handler_fn, initial_state)
  return act.pid
@end

@fn swarm_node_send_actor(node, target_pid: PID, msg_payload)
  return actor_dispatch_send(node.actor_table, node.info.node_id, target_pid, "CAST", msg_payload, node.peer_table)
@end

@fn swarm_node_send_actor_msg(node, target_pid: PID, msg_type, msg_payload)
  return actor_dispatch_send(node.actor_table, node.info.node_id, target_pid, msg_type, msg_payload, node.peer_table)
@end

@fn swarm_node_ask_actor(node, target_pid: PID, request_payload, timeout_ms)
  return actor_dispatch_ask(node.actor_table, node.info.node_id, target_pid, request_payload, timeout_ms, node.peer_table)
@end

@! ----------------------------------------------------------------------------
@! 5. Seed-Node Gossip Connect
@! ----------------------------------------------------------------------------

@fn swarm_node_connect_seed(node, seed_host, seed_port)
  return discovery_gossip_exchange(node.peer_table, node.info, seed_host, seed_port)
@end
