@! ============================================================================
@! MAYA E2E TIER 1 — F19: Router Load Balancing
@! File: tests/e2e/tier1_features/ai/test_f19_router_load_balancing.maya
@! ============================================================================

import "universe/swarm/types"
import "universe/swarm/discovery"
import "universe/swarm/router"

@fn main()
  peers = peer_table_new()
  p1 = { node_id: "busy_node", host: "127.0.0.1", tcp_port: 8001, udp_port: 8002, cluster_name: "maya", capabilities: [] }
  p2 = { node_id: "idle_node", host: "127.0.0.1", tcp_port: 8003, udp_port: 8004, cluster_name: "maya", capabilities: [] }
  peer_table_upsert(peers, p1, 10, 100) @! Load 10
  peer_table_upsert(peers, p2, 1, 100)  @! Load 1

  dec = router_decide("AUTO", 5, peers, 2)
  @if dec.destination != "REMOTE" return 1 @end
  @if dec.target_node.info.node_id != "idle_node" return 1 @end
  println("✓ PASS: test_f19_router_load_balancing")
  return 0
@end
