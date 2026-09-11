@! ============================================================================
@! MAYA E2E TIER 1 — F06.1: RamFS Inode File Create, Write, Read
@! File: tests/e2e/tier1_features/os/test_f06_vfs_ramfs_create_write_read.maya
@! ============================================================================

import "universe/os/fs"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F06.1: RamFS File I/O")

  path = "/tmp/maya_t1_f06_ramfs_io.txt"
  payload = "SOVEREIGN_RAMFS_DATA_123"
  fs_write_file(path, payload)
  read_val = fs_read_file(path)
  assert_str_eq(read_val, payload, "RamFS read data matches")
  fs_remove(path)

  println("✓ PASS: F06.1 RamFS File I/O")
  return 0
@end
