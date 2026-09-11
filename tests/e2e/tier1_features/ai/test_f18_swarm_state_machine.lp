@! ============================================================================
@! MAYA E2E TIER 1 — F18: Swarm State Machine
@! File: tests/e2e/tier1_features/ai/test_f18_swarm_state_machine.maya
@! ============================================================================

import "universe/swarm/types"
import "universe/swarm/actor"

@fn sm_handler(msg, state)
  @if state == "IDLE" return "PLANNING" @end
  @if state == "PLANNING" return "CODING" @end
  @if state == "CODING" return "REVIEW" @end
  @if state == "REVIEW" return "DONE" @end
  return state
@end

@fn main()
  table = actor_table_new()
  act = actor_create(table, "node_sm", sm_handler, "IDLE")
  actor_dispatch_send(table, "node_sm", act.pid, "STEP", 0, 0)
  @if act.state != "PLANNING" return 1 @end
  actor_dispatch_send(table, "node_sm", act.pid, "STEP", 0, 0)
  @if act.state != "CODING" return 1 @end
  actor_dispatch_send(table, "node_sm", act.pid, "STEP", 0, 0)
  @if act.state != "REVIEW" return 1 @end
  actor_dispatch_send(table, "node_sm", act.pid, "STEP", 0, 0)
  @if act.state != "DONE" return 1 @end
  println("✓ PASS: test_f18_swarm_state_machine")
  return 0
@end
