@! ============================================================================
@! MAYA E2E TIER 1 — F19: Router Dependency Graph
@! File: tests/e2e/tier1_features/ai/test_f19_router_dependency_graph.maya
@! ============================================================================

import "universe/swarm/types"
import "universe/swarm/task_registry"
import "universe/swarm/swarm"

@fn step1(x) return x + 10 @end
@fn step2(x) return x * 2 @end

@fn main()
  reg = task_registry_new()
  task_registry_register(reg, "s1", step1)
  task_registry_register(reg, "s2", step2)
  
  res1 = task_registry_invoke(reg, "s1", 5)  @! 15
  res2 = task_registry_invoke(reg, "s2", res1) @! 30
  @if res2 != 30 return 1 @end
  println("✓ PASS: test_f19_router_dependency_graph")
  return 0
@end
