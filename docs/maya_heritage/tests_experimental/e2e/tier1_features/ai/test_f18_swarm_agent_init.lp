@! ============================================================================
@! MAYA E2E TIER 1 — F18: Swarm Agent Init
@! File: tests/e2e/tier1_features/ai/test_f18_swarm_agent_init.maya
@! ============================================================================

import "universe/swarm/types"
import "universe/swarm/actor"

@fn dummy_h(msg, state)
  return state
@end

@fn main()
  table = actor_table_new()
  act = actor_create(table, "node_test", dummy_h, 42)
  @if act.pid.actor_id != 1 || act.pid.node_id != "node_test" return 1 @end
  @if act.state != 42 return 1 @end
  println("✓ PASS: test_f18_swarm_agent_init")
  return 0
@end
