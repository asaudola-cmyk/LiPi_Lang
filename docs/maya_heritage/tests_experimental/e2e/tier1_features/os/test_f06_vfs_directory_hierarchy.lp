@! ============================================================================
@! MAYA E2E TIER 1 — F06.2: VFS Nested Directory Hierarchy Creation
@! File: tests/e2e/tier1_features/os/test_f06_vfs_directory_hierarchy.maya
@! ============================================================================

import "universe/os/fs"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F06.2: Directory Hierarchy")

  nested = "/tmp/maya_t1_f06_hier/d1/d2/d3"
  res = fs_mkdir_p(nested, 511)
  assert_eq(res, 0, "fs_mkdir_p succeeded")
  assert_eq(fs_exists(nested), 1, "Directory path exists")
  fs_rmdir(nested)

  println("✓ PASS: F06.2 Directory Hierarchy")
  return 0
@end
