@! ============================================================================
@! MAYA E2E TIER 1 — F18: Swarm Peer Consensus
@! File: tests/e2e/tier1_features/ai/test_f18_swarm_peer_consensus.maya
@! ============================================================================

import "universe/swarm/types"
import "universe/swarm/actor"

@fn main()
  table = actor_table_new()
  fut1 = actor_table_create_future(table, 1000)
  fut2 = actor_table_create_future(table, 1000)
  actor_table_resolve_future(table, fut1.future_id, "APPROVE")
  actor_table_resolve_future(table, fut2.future_id, "APPROVE")
  
  f1 = actor_table_get_future(table, fut1.future_id)
  f2 = actor_table_get_future(table, fut2.future_id)
  @if f1.result != "APPROVE" || f2.result != "APPROVE" return 1 @end
  println("✓ PASS: test_f18_swarm_peer_consensus")
  return 0
@end
