@! ============================================================================
@! MAYA E2E TIER 1 — F19: Router Task Retry
@! File: tests/e2e/tier1_features/ai/test_f19_router_task_retry.maya
@! ============================================================================

import "universe/swarm/types"
import "universe/swarm/router"

@fn main()
  mon = load_monitor_new(3)
  load_monitor_inc_active(mon)
  @if load_monitor_get_load(mon) != 1 return 1 @end
  @! Simulate retry/backoff: dec then re-inc
  load_monitor_dec_active(mon)
  load_monitor_inc_pending(mon)
  @if load_monitor_get_load(mon) != 1 return 1 @end
  println("✓ PASS: test_f19_router_task_retry")
  return 0
@end
