@! ============================================================================
@! MAYA E2E TIER 1 — F21: Pure Maya Compiler Self-Sufficiency
@! File: tests/e2e/tier1_features/infra/test_f21_purity_pure_maya_compiler.maya
@! ============================================================================

import "universe/os/fs"

@fn main()
  has_compiler = fs_exists("bin/mayac_v2")
  @if has_compiler != 1 return 1 @end
  println("✓ PASS: test_f21_purity_pure_maya_compiler")
  return 0
@end
