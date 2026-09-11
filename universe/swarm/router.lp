@! ============================================================================
@! MAYA SWARM — DYNAMIC LOAD ROUTER & SCHEDULER (universe/swarm/router.maya)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Load Metrics, Green Thread vs Remote P2P Node Routing Heuristics
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/swarm/types"
import "universe/swarm/discovery"

@! ----------------------------------------------------------------------------
@! 1. Load Monitor & Metrics
@! ----------------------------------------------------------------------------

@struct LoadMonitor
  active_threads: i64
  pending_tasks: i64
  load_threshold: i64
@end

@fn load_monitor_new(threshold)
  @if threshold <= 0 threshold = 2 @end
  return {
    active_threads: 0,
    pending_tasks: 0,
    load_threshold: threshold
  }
@end

@fn load_monitor_get_load(mon)
  return mon.active_threads + mon.pending_tasks
@end

@fn load_monitor_inc_active(mon)
  mon.active_threads = mon.active_threads + 1
  return mon
@end

@fn load_monitor_dec_active(mon)
  @if mon.active_threads > 0
    mon.active_threads = mon.active_threads - 1
  @end
  return mon
@end

@fn load_monitor_inc_pending(mon)
  mon.pending_tasks = mon.pending_tasks + 1
  return mon
@end

@fn load_monitor_dec_pending(mon)
  @if mon.pending_tasks > 0
    mon.pending_tasks = mon.pending_tasks - 1
  @end
  return mon
@end

@! ----------------------------------------------------------------------------
@! 2. Routing Decision Engine
@! ----------------------------------------------------------------------------

@struct RoutingDecision
  destination: string
  target_node: any
  should_route_remote: i64
@end

@fn router_decide(policy, local_load, peer_table, threshold)
  @if policy == "LOCAL"
    return {
      destination: "LOCAL",
      target_node: 0,
      should_route_remote: 0
    }
  @end

  @if policy == "REMOTE"
    best = peer_table_get_least_loaded(peer_table)
    @if best != 0
      return {
        destination: "REMOTE",
        target_node: best,
        should_route_remote: 1
      }
    @end
    return {
      destination: "LOCAL",
      target_node: 0,
      should_route_remote: 0
    }
  @end

  @! AUTO policy: if local load exceeds threshold and remote peer has lower load
  @if local_load >= threshold
    best = peer_table_get_least_loaded(peer_table)
    @if best != 0 && best.load < local_load
      return {
        destination: "REMOTE",
        target_node: best,
        should_route_remote: 1
      }
    @end
  @end

  return {
    destination: "LOCAL",
    target_node: 0,
    should_route_remote: 0
  }
@end
