@! ============================================================================
@! MAYA E2E TIER 1 — F18: Swarm Mailbox Dispatch
@! File: tests/e2e/tier1_features/ai/test_f18_swarm_mailbox_dispatch.maya
@! ============================================================================

import "universe/swarm/types"
import "universe/swarm/actor"

@fn acc_handler(msg, state)
  return state + msg.payload
@end

@fn main()
  table = actor_table_new()
  act = actor_create(table, "node_mb", acc_handler, 0)
  actor_dispatch_send(table, "node_mb", act.pid, "ADD", 10, 0)
  actor_dispatch_send(table, "node_mb", act.pid, "ADD", 20, 0)
  actor_dispatch_send(table, "node_mb", act.pid, "ADD", 30, 0)
  @if act.state != 60 return 1 @end
  println("✓ PASS: test_f18_swarm_mailbox_dispatch")
  return 0
@end
