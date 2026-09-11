@! ============================================================================
@! MAYA E2E TIER 1 — F21: Zero Python Files Purity
@! File: tests/e2e/tier1_features/infra/test_f21_purity_no_python_files.maya
@! ============================================================================

import "universe/os/fs"

@fn main()
  has_py1 = fs_exists("build.py")
  has_py2 = fs_exists("compiler/main.py")
  has_py3 = fs_exists("scripts/test.py")
  @if has_py1 != 0 || has_py2 != 0 || has_py3 != 0 return 1 @end
  println("✓ PASS: test_f21_purity_no_python_files")
  return 0
@end
