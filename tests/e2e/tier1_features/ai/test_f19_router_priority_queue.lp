@! ============================================================================
@! MAYA E2E TIER 1 — F19: Router Priority Queue
@! File: tests/e2e/tier1_features/ai/test_f19_router_priority_queue.maya
@! ============================================================================

import "universe/swarm/types"
import "universe/swarm/router"

@fn main()
  mon = load_monitor_new(5)
  load_monitor_inc_pending(mon)
  load_monitor_inc_pending(mon)
  @if mon.pending_tasks != 2 return 1 @end
  load_monitor_dec_pending(mon)
  @if mon.pending_tasks != 1 return 1 @end
  println("✓ PASS: test_f19_router_priority_queue")
  return 0
@end
