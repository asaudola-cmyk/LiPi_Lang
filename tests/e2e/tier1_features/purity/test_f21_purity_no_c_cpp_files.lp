@! ============================================================================
@! MAYA E2E TIER 1 — F21: Zero C / C++ Files Purity
@! File: tests/e2e/tier1_features/infra/test_f21_purity_no_c_cpp_files.maya
@! ============================================================================

import "universe/os/fs"

@fn main()
  has_c = fs_exists("runtime/maya_gc.c")
  has_cpp = fs_exists("compiler/backend/emitter.cpp")
  has_h = fs_exists("runtime/maya_runtime.h")
  @if has_c != 0 || has_cpp != 0 || has_h != 0 return 1 @end
  println("✓ PASS: test_f21_purity_no_c_cpp_files")
  return 0
@end
