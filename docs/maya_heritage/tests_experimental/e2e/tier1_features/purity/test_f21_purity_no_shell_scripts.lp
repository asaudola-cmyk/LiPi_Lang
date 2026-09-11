@! ============================================================================
@! MAYA E2E TIER 1 — F21: Zero Shell Scripts Purity
@! File: tests/e2e/tier1_features/infra/test_f21_purity_no_shell_scripts.maya
@! ============================================================================

import "universe/os/fs"

@fn main()
  has_sh1 = fs_exists("build.sh")
  has_sh2 = fs_exists("run.sh")
  has_sh3 = fs_exists("tests/run.sh")
  @if has_sh1 != 0 || has_sh2 != 0 || has_sh3 != 0 return 1 @end
  println("✓ PASS: test_f21_purity_no_shell_scripts")
  return 0
@end
