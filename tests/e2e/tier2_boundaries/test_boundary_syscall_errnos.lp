// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Syscall Errnos & Kernel Edge Cases PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, syscalls, errno, enoent, ebadf, einval, eof, access

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: SYSCALL ERRNOS & LIMITS
@! File: tests/e2e/tier2_boundaries/test_boundary_syscall_errnos.maya
@! ============================================================================

import "universe/os/syscalls"

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Linux Syscall Errnos & Edge Cases")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-SYS-01: sys_open on Non-Existent File Path -> -ENOENT (-2)
  total = total + 1
  ret_missing = sys_open("/nonexistent_directory_for_maya_test/file.tmp", 0, 0)
  @if ret_missing == -2
    passed = passed + 1
    println("  [PASS] BC-SYS-01: sys_open on missing path returns -ENOENT (-2)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SYS-01: sys_open ENOENT")
  @end

  @! BC-SYS-02: sys_close on Invalid File Descriptor -> -EBADF (-9)
  total = total + 1
  ret_ebadf = sys_close(999999)
  @if ret_ebadf == -9
    passed = passed + 1
    println("  [PASS] BC-SYS-02: sys_close on invalid fd 999999 returns -EBADF (-9)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SYS-02: sys_close EBADF")
  @end

  @! BC-SYS-03: sys_munmap on Unaligned Memory Address -> -EINVAL (-22)
  total = total + 1
  ret_einval = sys_munmap(12345, 4096)
  @if ret_einval == -22
    passed = passed + 1
    println("  [PASS] BC-SYS-03: sys_munmap on unaligned address 12345 returns -EINVAL (-22)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SYS-03: sys_munmap EINVAL")
  @end

  @! BC-SYS-04: sys_write 0 Bytes to Valid FD -> 0
  total = total + 1
  pid = sys_getpid()
  test_file = "/tmp/maya_t2_errno_" + maya_int_to_str(pid) + ".tmp"
  fd = sys_open(test_file, 578, 420)
  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  w0 = sys_write(fd, buf, 0)
  @if w0 == 0
    passed = passed + 1
    println("  [PASS] BC-SYS-04: sys_write 0 bytes returns 0 without error")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SYS-04: sys_write 0 bytes")
  @end

  @! BC-SYS-05: sys_read 0 Bytes & sys_read at EOF -> 0
  total = total + 1
  r0 = sys_read(fd, buf, 0)
  @! File has 0 bytes, so reading from start is at EOF -> returns 0
  sys_lseek(fd, 0, 0)
  r_eof = sys_read(fd, buf, 64)
  sys_close(fd)
  sys_unlink(test_file)
  sys_munmap(buf, 4096)

  @if r0 == 0 && r_eof == 0
    passed = passed + 1
    println("  [PASS] BC-SYS-05: sys_read 0 bytes and sys_read at EOF return 0 bytes read")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SYS-05: sys_read 0 bytes / EOF")
  @end

  @! BC-SYS-06: sys_lseek on Invalid Whence (99) -> -EINVAL (-22)
  total = total + 1
  fd_temp = sys_open("/dev/null", 0, 0)
  ret_bad_seek = sys_lseek(fd_temp, 0, 99)
  sys_close(fd_temp)
  @if ret_bad_seek == -22
    passed = passed + 1
    println("  [PASS] BC-SYS-06: sys_lseek with invalid whence parameter returns -EINVAL (-22)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SYS-06: sys_lseek invalid whence")
  @end

  @! BC-SYS-07: sys_access on Missing File -> -ENOENT (-2)
  total = total + 1
  ret_acc = sys_access("/nonexistent_access_check_file.tmp", 0)
  @if ret_acc == -2
    passed = passed + 1
    println("  [PASS] BC-SYS-07: sys_access on non-existent file returns -ENOENT (-2)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-SYS-07: sys_access on missing file")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Syscall Errnos & Kernel Edge Cases PASSED")
    return 0
  @else
    println("✗ Boundary: Syscall Errnos & Kernel Edge Cases FAILED")
    return 1
  @end
@end
