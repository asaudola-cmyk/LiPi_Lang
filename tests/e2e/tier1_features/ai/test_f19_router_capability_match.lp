@! ============================================================================
@! MAYA E2E TIER 1 — F19: Router Capability Match
@! File: tests/e2e/tier1_features/ai/test_f19_router_capability_match.maya
@! ============================================================================

import "universe/swarm/types"
import "universe/swarm/discovery"
import "universe/swarm/router"

@fn main()
  peers = peer_table_new()
  p1 = { node_id: "coder_node", host: "127.0.0.1", tcp_port: 8001, udp_port: 8002, cluster_name: "maya", capabilities: ["coding"] }
  peer_table_upsert(peers, p1, 1, 100)
  
  dec = router_decide("REMOTE", 10, peers, 2)
  @if dec.destination != "REMOTE" || dec.should_route_remote != 1 return 1 @end
  @if dec.target_node.info.node_id != "coder_node" return 1 @end
  println("✓ PASS: test_f19_router_capability_match")
  return 0
@end
