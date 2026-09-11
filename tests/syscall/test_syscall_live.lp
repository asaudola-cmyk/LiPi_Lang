@! ============================================================================
@! MAYA UNMOCKED PURE MAYA NATIVE SYSCALL TEST SUITE
@! File: tests/syscall/test_syscall_live.maya
@! Scope: 100% Unmocked Live Linux x86-64 Syscall Verification
@! ============================================================================

import "universe/os/syscalls"

@! --- Test Harness State & Helpers ---
@struct TestContext
  total: 0
  passed: 0
  failed: 0
@end

@fn assert_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + maya_int_to_str(actual))
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected " + maya_int_to_str(expected) + ", got " + maya_int_to_str(actual))
    return 0
  @end
@end

@fn assert_str_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got \"" + actual + "\"")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
@end

@fn assert_true(ctx, name, condition)
  ctx.total = ctx.total + 1
  @if condition != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was false (0)")
    return 0
  @end
@end

@fn assert_ge(ctx, name, actual, min_val)
  ctx.total = ctx.total + 1
  @if actual >= min_val
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + maya_int_to_str(actual) + " (>= " + maya_int_to_str(min_val) + ")")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected >= " + maya_int_to_str(min_val) + ", got " + maya_int_to_str(actual))
    return 0
  @end
@end

@fn assert_errno(ctx, name, actual_ret, expected_errno)
  ctx.total = ctx.total + 1
  expected_ret = 0 - expected_errno
  @if actual_ret == expected_ret
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> correctly returned -errno " + maya_int_to_str(actual_ret))
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected -errno " + maya_int_to_str(expected_ret) + ", got " + maya_int_to_str(actual_ret))
    return 0
  @end
@end


@! ============================================================================
@! CATEGORY 1: LIVE FILE I/O OPERATIONS
@! ============================================================================

@fn test_file_io_lifecycle(ctx)
  println("\n--- [Category 1] Live File I/O Operations ---")

  pid = sys_getpid()
  test_file = "/tmp/maya_test_io_" + maya_int_to_str(pid) + ".tmp"

  @! 1. Allocate 4KB buffer via mmap
  @! PROT_READ(1) | PROT_WRITE(2) = 3
  @! MAP_PRIVATE(2) | MAP_ANONYMOUS(32) = 34
  wbuf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  assert_true(ctx, "TC-FILE-01.1: mmap write buffer allocation", wbuf > 0)

  @! 2. Open file with O_CREAT (64) | O_RDWR (2) | O_TRUNC (512) = 578, mode 0644 (420)
  fd = sys_open(test_file, 578, 420)
  assert_ge(ctx, "TC-FILE-01.2: sys_open create temporary file", fd, 3)

  @! 3. Write 40 bytes to file
  written = sys_write(fd, wbuf, 40)
  assert_eq(ctx, "TC-FILE-01.3: sys_write 40 bytes", written, 40)

  @! 4. Close file
  close_res = sys_close(fd)
  assert_eq(ctx, "TC-FILE-01.4: sys_close created file", close_res, 0)

  @! 5. Re-open with O_RDONLY (0)
  rfd = sys_open(test_file, 0, 0)
  assert_ge(ctx, "TC-FILE-01.5: sys_open reopen O_RDONLY", rfd, 3)

  @! 6. Allocate read buffer and read 4096 bytes
  rbuf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  read_bytes = sys_read(rfd, rbuf, 4096)
  assert_eq(ctx, "TC-FILE-01.6: sys_read returned exact written byte count", read_bytes, 40)

  @! 7. Close and unlink
  sys_close(rfd)
  unl_res = sys_unlink(test_file)
  assert_eq(ctx, "TC-FILE-01.7: sys_unlink remove temporary file", unl_res, 0)

  @! 8. Verify file no longer exists (reopen should fail with ENOENT = 2)
  deleted_fd = sys_open(test_file, 0, 0)
  assert_errno(ctx, "TC-FILE-01.8: sys_open deleted file returns -ENOENT (-2)", deleted_fd, 2)

  @! Free buffers
  sys_munmap(wbuf, 4096)
  sys_munmap(rbuf, 4096)
@end

@fn test_file_lseek_operations(ctx)
  pid = sys_getpid()
  test_file = "/tmp/maya_test_lseek_" + maya_int_to_str(pid) + ".tmp"

  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)

  @! Create file and write 100 bytes
  fd = sys_open(test_file, 578, 420)
  sys_write(fd, buf, 100)

  @! SEEK_SET (0): Seek to beginning
  offset0 = sys_lseek(fd, 0, 0)
  assert_eq(ctx, "TC-FILE-02.1: sys_lseek SEEK_SET(0)", offset0, 0)

  @! Read 10 bytes, then SEEK_CUR (1) +20 bytes
  sys_read(fd, buf, 10)
  offset_cur = sys_lseek(fd, 20, 1)
  assert_eq(ctx, "TC-FILE-02.2: sys_lseek SEEK_CUR(+20) from pos 10", offset_cur, 30)

  @! SEEK_END (2): Seek to end of file
  offset_end = sys_lseek(fd, 0, 2)
  assert_eq(ctx, "TC-FILE-02.3: sys_lseek SEEK_END(0) matches file size", offset_end, 100)

  @! Seek backwards 15 bytes from end
  offset_tail = sys_lseek(fd, 0 - 15, 2)
  assert_eq(ctx, "TC-FILE-02.4: sys_lseek SEEK_END(-15)", offset_tail, 85)

  sys_close(fd)
  sys_unlink(test_file)
  sys_munmap(buf, 4096)
@end

@fn test_file_append_and_truncate(ctx)
  pid = sys_getpid()
  test_file = "/tmp/maya_test_apptrunc_" + maya_int_to_str(pid) + ".tmp"
  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)

  @! 1. Create file and write 50 bytes
  fd1 = sys_open(test_file, 578, 420)
  sys_write(fd1, buf, 50)
  sys_close(fd1)

  @! 2. Re-open with O_WRONLY (1) | O_APPEND (1024) = 1025
  fd_app = sys_open(test_file, 1025, 0)
  sys_write(fd_app, buf, 30)
  sys_close(fd_app)

  @! 3. Verify total size is 80 bytes
  fd_check = sys_open(test_file, 0, 0)
  size = sys_lseek(fd_check, 0, 2)
  assert_eq(ctx, "TC-FILE-03.1: O_APPEND appends 30B to 50B (total 80B)", size, 80)
  sys_close(fd_check)

  @! 4. Re-open with O_RDWR (2) | O_TRUNC (512) = 514
  fd_trunc = sys_open(test_file, 514, 0)
  trunc_size = sys_lseek(fd_trunc, 0, 2)
  assert_eq(ctx, "TC-FILE-05.1: O_TRUNC resets file length to 0", trunc_size, 0)
  sys_close(fd_trunc)

  sys_unlink(test_file)
  sys_munmap(buf, 4096)
@end

@fn test_multi_file_concurrent(ctx)
  pid = sys_getpid()
  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)

  f1 = "/tmp/maya_test_m1_" + maya_int_to_str(pid) + ".tmp"
  f2 = "/tmp/maya_test_m2_" + maya_int_to_str(pid) + ".tmp"
  f3 = "/tmp/maya_test_m3_" + maya_int_to_str(pid) + ".tmp"

  fd1 = sys_open(f1, 578, 420)
  fd2 = sys_open(f2, 578, 420)
  fd3 = sys_open(f3, 578, 420)

  assert_true(ctx, "TC-FILE-04.1: 3 simultaneous file descriptors open", (fd1 >= 3) && (fd2 >= 3) && (fd3 >= 3))
  assert_true(ctx, "TC-FILE-04.2: file descriptors are distinct", (fd1 != fd2) && (fd2 != fd3) && (fd1 != fd3))

  sys_write(fd1, buf, 16)
  sys_write(fd2, buf, 32)
  sys_write(fd3, buf, 64)

  s1 = sys_lseek(fd1, 0, 2)
  s2 = sys_lseek(fd2, 0, 2)
  s3 = sys_lseek(fd3, 0, 2)

  assert_eq(ctx, "TC-FILE-04.3: fd1 size is 16", s1, 16)
  assert_eq(ctx, "TC-FILE-04.4: fd2 size is 32", s2, 32)
  assert_eq(ctx, "TC-FILE-04.5: fd3 size is 64", s3, 64)

  sys_close(fd1)
  sys_close(fd2)
  sys_close(fd3)

  sys_unlink(f1)
  sys_unlink(f2)
  sys_unlink(f3)
  sys_munmap(buf, 4096)
@end


@! ============================================================================
@! CATEGORY 2: LIVE MEMORY MAPPING & ANONYMOUS PAGES
@! ============================================================================

@fn test_mmap_operations(ctx)
  println("\n--- [Category 2] Live Memory Mapping Operations ---")

  @! 1. Allocate single 4096-byte page
  ptr4k = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  assert_true(ctx, "TC-MMAP-01.1: sys_mmap allocate 4KB page returns positive address", ptr4k > 0)
  assert_eq(ctx, "TC-MMAP-01.2: 4KB page is 4096-byte aligned", ptr4k % 4096, 0)

  @! 2. Unmap 4KB page
  unmap_res = sys_munmap(ptr4k, 4096)
  assert_eq(ctx, "TC-MMAP-01.3: sys_munmap release 4KB page returns 0", unmap_res, 0)

  @! 3. Allocate 64KB arena (16 pages = 65536 bytes)
  ptr64k = sys_mmap(0, 65536, 3, 34, 0 - 1, 0)
  assert_true(ctx, "TC-MMAP-02.1: sys_mmap allocate 64KB arena", ptr64k > 0)
  assert_eq(ctx, "TC-MMAP-02.2: 64KB arena is 4096-byte aligned", ptr64k % 4096, 0)

  @! Release 64KB arena
  unmap64 = sys_munmap(ptr64k, 65536)
  assert_eq(ctx, "TC-MMAP-02.3: sys_munmap release 64KB arena returns 0", unmap64, 0)

  @! 4. PROT_READ (1) page
  ro_page = sys_mmap(0, 4096, 1, 34, 0 - 1, 0)
  assert_true(ctx, "TC-MMAP-03.1: sys_mmap allocate PROT_READ page", ro_page > 0)
  sys_munmap(ro_page, 4096)

  @! 5. Zero length boundary
  zero_munmap = sys_munmap(ptr4k, 0)
  assert_errno(ctx, "TC-MMAP-04.1: sys_munmap length 0 returns -EINVAL (-22)", zero_munmap, 22)
@end


@! ============================================================================
@! CATEGORY 3: NEGATIVE TESTING & ERRNO TRANSLATION
@! ============================================================================

@fn test_negative_error_conditions(ctx)
  println("\n--- [Category 3] Negative Testing & Errno Translation ---")

  @! 1. Open non-existent file -> -ENOENT (-2)
  res_enoent = sys_open("/tmp/non_existent_maya_test_file_987654.xyz", 0, 0)
  assert_errno(ctx, "TC-ERR-01: sys_open non-existent file returns -ENOENT (-2)", res_enoent, 2)

  @! 2. Open path with non-existent directory -> -ENOENT (-2)
  res_nodir = sys_open("/non_existent_dir_12345/file.tmp", 578, 420)
  assert_errno(ctx, "TC-ERR-02: sys_open non-existent dir path returns -ENOENT (-2)", res_nodir, 2)

  @! 3. Close invalid file descriptor -> -EBADF (-9)
  res_ebadf_close = sys_close(999999)
  assert_errno(ctx, "TC-ERR-03: sys_close invalid fd returns -EBADF (-9)", res_ebadf_close, 9)

  @! 4. Read from invalid file descriptor -> -EBADF (-9)
  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  res_ebadf_read = sys_read(999999, buf, 64)
  assert_errno(ctx, "TC-ERR-04: sys_read invalid fd returns -EBADF (-9)", res_ebadf_read, 9)

  @! 5. Write to read-only file descriptor -> -EBADF (-9)
  pid = sys_getpid()
  tmpf = "/tmp/maya_test_ro_" + maya_int_to_str(pid) + ".tmp"
  create_fd = sys_open(tmpf, 578, 420)
  sys_close(create_fd)

  ro_fd = sys_open(tmpf, 0, 0) @! O_RDONLY (0)
  res_ro_write = sys_write(ro_fd, buf, 16)
  assert_errno(ctx, "TC-ERR-05: sys_write to O_RDONLY fd returns -EBADF (-9)", res_ro_write, 9)
  sys_close(ro_fd)
  sys_unlink(tmpf)

  @! 6. Seek on invalid file descriptor -> -EBADF (-9)
  res_lseek_ebadf = sys_lseek(888888, 0, 0)
  assert_errno(ctx, "TC-ERR-06: sys_lseek invalid fd returns -EBADF (-9)", res_lseek_ebadf, 9)

  @! 7. Seek with invalid whence -> -EINVAL (-22)
  valid_fd = sys_open("/dev/null", 0, 0)
  res_lseek_einval = sys_lseek(valid_fd, 0, 999)
  assert_errno(ctx, "TC-ERR-07: sys_lseek invalid whence 999 returns -EINVAL (-22)", res_lseek_einval, 22)
  sys_close(valid_fd)

  @! 8. Unlink non-existent file -> -ENOENT (-2)
  res_unl_enoent = sys_unlink("/tmp/definitely_not_existing_file_999.tmp")
  assert_errno(ctx, "TC-ERR-08: sys_unlink non-existent file returns -ENOENT (-2)", res_unl_enoent, 2)

  @! 9. Munmap unaligned address -> -EINVAL (-22)
  res_unmap_einval = sys_munmap(12345, 4096)
  assert_errno(ctx, "TC-ERR-09: sys_munmap unaligned address returns -EINVAL (-22)", res_unmap_einval, 22)

  sys_munmap(buf, 4096)
@end


@! ============================================================================
@! CATEGORY 4: EDGE CASES & SYSTEM CALLS
@! ============================================================================

@fn test_edge_cases_and_system(ctx)
  println("\n--- [Category 4] Edge Cases & System Calls ---")

  pid = sys_getpid()
  assert_true(ctx, "TC-EDGE-03.1: sys_getpid returns valid PID (> 0)", pid > 0)

  ppid = sys_getppid()
  assert_true(ctx, "TC-EDGE-03.2: sys_getppid returns valid PPID (> 0)", ppid > 0)

  buf = sys_mmap(0, 8192, 3, 34, 0 - 1, 0)
  test_file = "/tmp/maya_test_edge_" + maya_int_to_str(pid) + ".tmp"
  fd = sys_open(test_file, 578, 420)

  @! 1. Zero-byte write & read
  w0 = sys_write(fd, buf, 0)
  assert_eq(ctx, "TC-EDGE-01.1: sys_write 0 bytes returns 0", w0, 0)

  r0 = sys_read(fd, buf, 0)
  assert_eq(ctx, "TC-EDGE-01.2: sys_read 0 bytes returns 0", r0, 0)

  @! 2. Large buffer transfer (8192 bytes across page boundary)
  w8k = sys_write(fd, buf, 8192)
  assert_eq(ctx, "TC-EDGE-04.1: sys_write 8192 bytes (2 pages)", w8k, 8192)

  sys_lseek(fd, 0, 0)
  r8k = sys_read(fd, buf, 8192)
  assert_eq(ctx, "TC-EDGE-04.2: sys_read 8192 bytes (2 pages)", r8k, 8192)

  @! 3. Read at EOF
  eof_bytes = sys_read(fd, buf, 64)
  assert_eq(ctx, "TC-EDGE-02.1: sys_read at EOF returns 0", eof_bytes, 0)

  sys_close(fd)
  sys_unlink(test_file)

  @! 4. Restrictive permissions mode (0600 = 384)
  f_mode = "/tmp/maya_test_mode_" + maya_int_to_str(pid) + ".tmp"
  fd_mode = sys_open(f_mode, 578, 384)
  assert_ge(ctx, "TC-EDGE-05.1: sys_open create file with mode 0600", fd_mode, 3)
  sys_close(fd_mode)
  sys_unlink(f_mode)

  sys_munmap(buf, 8192)
@end


@! ============================================================================
@! CATEGORY 5: ERROR HELPER & TRANSLATION FUNCTIONS
@! ============================================================================

@fn test_error_helpers(ctx)
  println("\n--- [Category 5] Error Helpers & Errno Strings ---")

  assert_true(ctx, "TC-ERR-HELP.1: is_error(-2) is true", is_error(0 - 2))
  assert_true(ctx, "TC-ERR-HELP.2: is_error(0) is false", !is_error(0))
  assert_true(ctx, "TC-ERR-HELP.3: is_ok(10) is true", is_ok(10))
  assert_true(ctx, "TC-ERR-HELP.4: is_ok(-1) is false", !is_ok(0 - 1))

  assert_eq(ctx, "TC-ERR-HELP.5: get_errno(-2) == 2", get_errno(0 - 2), 2)
  assert_eq(ctx, "TC-ERR-HELP.6: get_errno(0) == 0", get_errno(0), 0)

  assert_str_eq(ctx, "TC-ERR-HELP.7: errno_name(2) == 'ENOENT'", errno_name(2), "ENOENT")
  assert_str_eq(ctx, "TC-ERR-HELP.8: errno_name(9) == 'EBADF'", errno_name(9), "EBADF")
  assert_str_eq(ctx, "TC-ERR-HELP.9: errno_name(22) == 'EINVAL'", errno_name(22), "EINVAL")

  assert_str_eq(ctx, "TC-ERR-HELP.10: errno_strerror(2) matches", errno_strerror(2), "No such file or directory")
  assert_str_eq(ctx, "TC-ERR-HELP.11: errno_strerror(9) matches", errno_strerror(9), "Bad file descriptor")
  assert_str_eq(ctx, "TC-ERR-HELP.12: errno_strerror(22) matches", errno_strerror(22), "Invalid argument")
@end


@! ============================================================================
@! MASTER RUNNER ENTRYPOINT
@! ============================================================================

@fn main()
  println("=================================================================")
  println("▶ MAYA PURE MAYA UNMOCKED SYSCALL VERIFICATION SUITE")
  println("=================================================================")

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_file_io_lifecycle(ctx)
  test_file_lseek_operations(ctx)
  test_file_append_and_truncate(ctx)
  test_multi_file_concurrent(ctx)
  test_mmap_operations(ctx)
  test_negative_error_conditions(ctx)
  test_edge_cases_and_system(ctx)
  test_error_helpers(ctx)

  println("\n=================================================================")
  println("📊 SYSCALL TEST EXECUTION SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] 100% of unmocked Pure Maya syscall tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more syscall tests failed.")
    return 1
  @end
@end
