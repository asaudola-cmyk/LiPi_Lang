@! ============================================================================
@! MAYA SWARM — CORE TYPES & DATA STRUCTURES (universe/swarm/types.maya)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Defines PID, NodeInfo, TaskDescriptor, SwarmJoinHandle, ActorMessage, SwarmPacket
@! ============================================================================

import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Node Identification & Cluster Types
@! ----------------------------------------------------------------------------

@struct NodeID
  id: string
  cluster_name: string
@end

@fn node_id_new(id, cluster_name)
  return { id: id, cluster_name: cluster_name }
@end

@fn node_id_to_str(node_id)
  return node_id.cluster_name + "@" + node_id.id
@end

@! ----------------------------------------------------------------------------
@! 2. Globally Routable Process/Actor ID (PID)
@! ----------------------------------------------------------------------------

@struct PID
  node_id: string
  actor_id: i64
  is_remote: i64
@end

@fn pid_new(node_id, actor_id, is_remote)
  return {
    node_id: node_id,
    actor_id: actor_id,
    is_remote: is_remote
  }
@end

@fn pid_to_str(pid)
  return "<PID " + pid.node_id + ":" + pid.actor_id.to_str() + ">"
@end

@fn pid_eq(p1, p2)
  @if p1.actor_id != p2.actor_id return 0 @end
  @if p1.node_id != p2.node_id return 0 @end
  return 1
@end

@! ----------------------------------------------------------------------------
@! 3. Swarm Node Peer Metadata (NodeInfo)
@! ----------------------------------------------------------------------------

@struct NodeInfo
  node_id: string
  host: string
  tcp_port: i64
  udp_port: i64
  load: i64
  last_seen: i64
  status: string
@end

@fn node_info_new(node_id, host, tcp_port, udp_port, load, last_seen, status)
  return {
    node_id: node_id,
    host: host,
    tcp_port: tcp_port,
    udp_port: udp_port,
    load: load,
    last_seen: last_seen,
    status: status
  }
@end

@fn node_info_to_str(info)
  return "Node[" + info.node_id + " @ " + info.host + ":" + info.tcp_port.to_str() + " load=" + info.load.to_str() + " status=" + info.status + "]"
@end

@! ----------------------------------------------------------------------------
@! 4. Remote Task Descriptor & Concurrency Join Handle
@! ----------------------------------------------------------------------------

@struct TaskDescriptor
  task_id: i64
  func_name: string
  args: array
  origin_node: string
  origin_future_id: i64
@end

@fn task_descriptor_new(task_id, func_name, args, origin_node, origin_future_id)
  return {
    task_id: task_id,
    func_name: func_name,
    args: args,
    origin_node: origin_node,
    origin_future_id: origin_future_id
  }
@end

@struct SwarmJoinHandle
  task_id: i64
  is_remote: i64
  local_pid: i64
  remote_node: string
  future_id: i64
  completed: i64
  result: any
@end

@fn swarm_join_handle_new(task_id, is_remote, local_pid, remote_node, future_id)
  return {
    task_id: task_id,
    is_remote: is_remote,
    local_pid: local_pid,
    remote_node: remote_node,
    future_id: future_id,
    completed: 0,
    result: 0
  }
@end

@! ----------------------------------------------------------------------------
@! 5. Distributed Actor Message
@! ----------------------------------------------------------------------------

@struct ActorMessage
  msg_id: i64
  sender: PID
  target: PID
  msg_type: string
  payload: any
@end

@fn actor_message_new(msg_id, sender, target, msg_type, payload)
  return {
    msg_id: msg_id,
    sender: sender,
    target: target,
    msg_type: msg_type,
    payload: payload
  }
@end

@! ----------------------------------------------------------------------------
@! 6. Wire Framing Packets
@! ----------------------------------------------------------------------------

@struct SwarmPacket
  magic: i64
  version: i64
  msg_type: i64
  payload_len: i64
  checksum: i64
  payload: string
@end

@struct DecodedPacket
  valid: i64
  reason: string
  magic: i64
  version: i64
  msg_type: i64
  payload_len: i64
  checksum: i64
  payload: string
@end

@fn swarm_packet_new(msg_type, payload_str, checksum)
  return {
    magic: 21335,
    version: 1,
    msg_type: msg_type,
    payload_len: payload_str.len(),
    checksum: checksum,
    payload: payload_str
  }
@end
