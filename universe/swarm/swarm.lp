@! ============================================================================
@! MAYA SWARM — UNIFIED PUBLIC DISTRIBUTED RUNTIME API (universe/swarm/swarm.maya)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! P2P Cluster Runtime, Dynamic Scheduler, Actor System, and Remote Task Router
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

@! ----------------------------------------------------------------------------
@! 1. Global Swarm Context
@! ----------------------------------------------------------------------------

@struct SwarmSystem
  node: any
  is_initialized: i64
@end

@fn _swarm_global_ctx()
  return { node: 0, is_initialized: 0 }
@end

@! ----------------------------------------------------------------------------
@! 2. Public Cluster Lifecycle API
@! ----------------------------------------------------------------------------

@fn swarm_init(node_id, host, tcp_port, udp_port)
  n = swarm_node_new(node_id, host, tcp_port, udp_port, "maya-swarm")
  swarm_node_start(n)
  return n
@end

@fn swarm_shutdown(node)
  @if node != 0
    return swarm_node_stop(node)
  @end
  return 0
@end

@fn swarm_get_local_info(node)
  @if node != 0 return node.info @end
  return 0
@end

@fn swarm_get_local_load(node)
  @if node != 0
    return load_monitor_get_load(node.load_monitor)
  @end
  return 0
@end

@fn swarm_step_node(node)
  @if node != 0
    return swarm_node_step(node)
  @end
  return 0
@end

@fn swarm_cluster_peers(node)
  @if node != 0
    return peer_table_get_alive(node.peer_table)
  @end
  return []
@end

@fn swarm_connect_seed(node, seed_host, seed_port)
  @if node != 0
    return swarm_node_connect_seed(node, seed_host, seed_port)
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 3. Public Task Registration & Dynamic Routing API
@! ----------------------------------------------------------------------------

@fn swarm_register_task(node, name, func_ptr)
  @if node != 0
    task_registry_register(node.task_registry, name, func_ptr)
    return 1
  @end
  return 0
@end

@fn swarm_spawn(node, task_name, arg)
  @if node == 0
    return swarm_join_handle_new(0, 0, 0, "", 0)
  @end

  local_load = load_monitor_get_load(node.load_monitor)
  decision = router_decide("AUTO", local_load, node.peer_table, node.load_monitor.load_threshold)

  @if decision.should_route_remote != 0 && decision.target_node != 0
    return swarm_node_submit_remote_task(node, decision.target_node, task_name, arg)
  @else
    @! Local execution
    load_monitor_inc_active(node.load_monitor)
    res_val = task_registry_invoke(node.task_registry, task_name, arg)
    load_monitor_dec_active(node.load_monitor)

    tid = node.next_task_id
    node.next_task_id = node.next_task_id + 1

    h = swarm_join_handle_new(tid, 0, 0, node.info.node_id, 0)
    h.completed = 1
    h.result = res_val
    return h
  @end
@end

@fn swarm_spawn_remote(node, target_node_id, task_name, arg)
  @if node == 0
    return swarm_join_handle_new(0, 1, 0, target_node_id, 0)
  @end

  target_peer = peer_table_find(node.peer_table, target_node_id)
  @if target_peer != 0
    return swarm_node_submit_remote_task(node, target_peer, task_name, arg)
  @end

  println("[Swarm] Error: Target node '" + target_node_id + "' not found in active peer table")
  return swarm_join_handle_new(0, 1, 0, target_node_id, 0)
@end

@fn swarm_join(join_h: SwarmJoinHandle)
  @if join_h.completed != 0
    return join_h.result
  @end
  return join_h.result
@end

@! ----------------------------------------------------------------------------
@! 4. Public Distributed Actor API
@! ----------------------------------------------------------------------------

@fn actor_spawn(node, handler_fn, initial_state)
  @if node != 0
    return swarm_node_spawn_actor(node, handler_fn, initial_state)
  @end
  return pid_new("none", 0, 0)
@end

@fn actor_send(node, target_pid: PID, msg_payload)
  @if node != 0
    return swarm_node_send_actor(node, target_pid, msg_payload)
  @end
  return 0
@end

@fn actor_send_msg(node, target_pid: PID, msg_type, msg_payload)
  @if node != 0
    return swarm_node_send_actor_msg(node, target_pid, msg_type, msg_payload)
  @end
  return 0
@end

@fn actor_ask(node, target_pid: PID, request_payload, timeout_ms)
  @if node != 0
    return swarm_node_ask_actor(node, target_pid, request_payload, timeout_ms)
  @end
  return 0
@end

@fn actor_self(node)
  @if node != 0
    return node.actor_table.current_actor_pid
  @end
  return pid_new("none", 0, 0)
@end
