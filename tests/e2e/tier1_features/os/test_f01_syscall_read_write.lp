@! ============================================================================
@! MAYA E2E TIER 1 — F01.1: Syscall Read / Write Stream I/O
@! File: tests/e2e/tier1_features/os/test_f01_syscall_read_write.maya
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn main()
  println("▶ [TIER 1] F01.1: Syscall Read/Write Stream")

  path = "/tmp/maya_t1_f01_rw_" + sys_getpid().to_str() + ".tmp"
  @! O_WRONLY (1) | O_CREAT (64) | O_TRUNC (512) = 577, 0644 (420)
  fd_w = sys_open(path, 577, 420)
  assert_gt(fd_w, 2, "sys_open for write must succeed")

  data = "MAYA_STREAM_IO_DATA_XYZ_12345\n"
  written = sys_write(fd_w, data, data.len())
  assert_eq(written, data.len(), "sys_write wrote full length")
  sys_close(fd_w)

  fd_r = sys_open(path, 0, 0)
  assert_gt(fd_r, 2, "sys_open for read must succeed")

  buf = maya_alloc(64)
  n = sys_read(fd_r, buf, 64)
  assert_eq(n, data.len(), "sys_read got exact bytes")
  read_str = maya_str_new(buf)
  assert_str_eq(read_str, data, "Read data matches written data")

  sys_close(fd_r)
  sys_unlink(path)

  println("✓ PASS: F01.1 Syscall Read/Write Stream")
  return 0
@end
