@! ============================================================================
@! MAYA ADVERSARIAL STRESS TEST SUITE: PURE MAYA SYSCALL SUBSYSTEM
@! File: tests/syscall/test_syscall_adversarial.maya
@! Scope: Empirical adversarial stress-testing of raw x86-64 syscalls
@! ============================================================================

import "universe/os/syscalls"

@struct StressContext
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
@! 1. LARGE MULTI-MEGABYTE I/O & MEMORY STRESS (16MB MMAP & I/O)
@! ============================================================================

@fn test_large_io_and_mprotect(ctx)
  println("\n--- [Section 1] Large Multi-Megabyte I/O & Memory Protection Stress ---")

  pid = sys_getpid()
  test_file = "/tmp/maya_stress_large_io_" + maya_int_to_str(pid) + ".tmp"
  
  @! 16MB = 16777216 bytes (4096 pages)
  size_16mb = 16777216
  
  @! 1. Allocate 16MB via mmap: PROT_READ(1) | PROT_WRITE(2) = 3, MAP_PRIVATE(2) | MAP_ANON(32) = 34
  wbuf = sys_mmap(0, size_16mb, 3, 34, 0 - 1, 0)
  assert_true(ctx, "ADV-IO-01.1: Allocate 16MB buffer via sys_mmap", wbuf > 0)
  assert_eq(ctx, "ADV-IO-01.2: 16MB buffer is 4096-byte page-aligned", wbuf % 4096, 0)

  @! 2. Open file for write: O_CREAT(64) | O_RDWR(2) | O_TRUNC(512) = 578, mode 0644(420)
  fd = sys_open(test_file, 578, 420)
  assert_ge(ctx, "ADV-IO-01.3: sys_open temporary stress file", fd, 3)

  @! 3. Write 16MB payload
  bytes_written = sys_write(fd, wbuf, size_16mb)
  assert_eq(ctx, "ADV-IO-01.4: sys_write exactly 16MB (16777216 bytes)", bytes_written, size_16mb)

  @! 4. Check file size using lseek
  file_size = sys_lseek(fd, 0, 2) @! SEEK_END(2)
  assert_eq(ctx, "ADV-IO-01.5: sys_lseek SEEK_END confirms 16MB file size", file_size, size_16mb)

  @! 5. Seek back to start
  seek_start = sys_lseek(fd, 0, 0) @! SEEK_SET(0)
  assert_eq(ctx, "ADV-IO-01.6: sys_lseek SEEK_SET resets offset to 0", seek_start, 0)

  @! 6. Allocate 16MB read buffer
  rbuf = sys_mmap(0, size_16mb, 3, 34, 0 - 1, 0)
  assert_true(ctx, "ADV-IO-01.7: Allocate 16MB read buffer via sys_mmap", rbuf > 0)

  @! 7. Read 16MB payload
  bytes_read = sys_read(fd, rbuf, size_16mb)
  assert_eq(ctx, "ADV-IO-01.8: sys_read exactly 16MB (16777216 bytes)", bytes_read, size_16mb)

  @! 8. Test sys_mprotect across entire 16MB mapping
  prot_ro = sys_mprotect(rbuf, size_16mb, 1) @! PROT_READ(1)
  assert_eq(ctx, "ADV-IO-02.1: sys_mprotect PROT_READ on 16MB region", prot_ro, 0)

  prot_rw = sys_mprotect(rbuf, size_16mb, 3) @! PROT_READ|PROT_WRITE(3)
  assert_eq(ctx, "ADV-IO-02.2: sys_mprotect PROT_READ|PROT_WRITE on 16MB region", prot_rw, 0)

  prot_none = sys_mprotect(rbuf, size_16mb, 0) @! PROT_NONE(0)
  assert_eq(ctx, "ADV-IO-02.3: sys_mprotect PROT_NONE on 16MB region", prot_none, 0)

  prot_restore = sys_mprotect(rbuf, size_16mb, 3) @! Restore PROT_READ|PROT_WRITE(3)
  assert_eq(ctx, "ADV-IO-02.4: sys_mprotect restore permissions", prot_restore, 0)

  @! 9. Clean up
  sys_close(fd)
  sys_unlink(test_file)
  
  unmap_w = sys_munmap(wbuf, size_16mb)
  assert_eq(ctx, "ADV-IO-03.1: sys_munmap 16MB write buffer returns 0", unmap_w, 0)

  unmap_r = sys_munmap(rbuf, size_16mb)
  assert_eq(ctx, "ADV-IO-03.2: sys_munmap 16MB read buffer returns 0", unmap_r, 0)
@end


@! ============================================================================
@! 2. ZERO-LENGTH & BOUNDARY EDGE CASES
@! ============================================================================

@fn test_zero_length_and_boundaries(ctx)
  println("\n--- [Section 2] Zero-Length & Boundary Edge Cases ---")

  pid = sys_getpid()
  test_file = "/tmp/maya_stress_boundary_" + maya_int_to_str(pid) + ".tmp"
  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)

  fd = sys_open(test_file, 578, 420)

  @! 1. Zero length read and write
  w0 = sys_write(fd, buf, 0)
  assert_eq(ctx, "ADV-BOUND-01.1: sys_write length 0 returns 0", w0, 0)

  r0 = sys_read(fd, buf, 0)
  assert_eq(ctx, "ADV-BOUND-01.2: sys_read length 0 returns 0", r0, 0)

  @! 2. Zero length mmap and munmap errors
  zero_mmap = sys_mmap(0, 0, 3, 34, 0 - 1, 0)
  assert_errno(ctx, "ADV-BOUND-02.1: sys_mmap length 0 returns -EINVAL (-22)", zero_mmap, 22)

  zero_munmap = sys_munmap(buf, 0)
  assert_errno(ctx, "ADV-BOUND-02.2: sys_munmap length 0 returns -EINVAL (-22)", zero_munmap, 22)

  @! 3. Seeking before beginning of file (negative absolute offset on SEEK_SET)
  neg_seek = sys_lseek(fd, 0 - 10, 0) @! SEEK_SET(0)
  assert_errno(ctx, "ADV-BOUND-03.1: sys_lseek negative offset on SEEK_SET returns -EINVAL (-22)", neg_seek, 22)

  @! 4. Sparse file creation: Seek to 4MB, write 128 bytes
  seek_4mb = sys_lseek(fd, 4194304, 0) @! 4MB
  assert_eq(ctx, "ADV-BOUND-04.1: sys_lseek 4MB sparse offset", seek_4mb, 4194304)

  sparse_write = sys_write(fd, buf, 128)
  assert_eq(ctx, "ADV-BOUND-04.2: sys_write 128 bytes at 4MB offset", sparse_write, 128)

  end_offset = sys_lseek(fd, 0, 2) @! SEEK_END(2)
  assert_eq(ctx, "ADV-BOUND-04.3: Sparse file size is 4194432 bytes", end_offset, 4194432)

  @! 5. Truncation stress: 8MB -> 100B -> 0B
  trunc_8mb = sys_ftruncate(fd, 8388608)
  assert_eq(ctx, "ADV-BOUND-05.1: sys_ftruncate expand to 8MB returns 0", trunc_8mb, 0)
  size_8mb = sys_lseek(fd, 0, 2)
  assert_eq(ctx, "ADV-BOUND-05.2: Size confirmed 8388608 bytes", size_8mb, 8388608)

  trunc_100 = sys_ftruncate(fd, 100)
  assert_eq(ctx, "ADV-BOUND-05.3: sys_ftruncate shrink to 100B returns 0", trunc_100, 0)
  size_100 = sys_lseek(fd, 0, 2)
  assert_eq(ctx, "ADV-BOUND-05.4: Size confirmed 100 bytes", size_100, 100)

  trunc_0 = sys_ftruncate(fd, 0)
  assert_eq(ctx, "ADV-BOUND-05.5: sys_ftruncate shrink to 0B returns 0", trunc_0, 0)
  size_0 = sys_lseek(fd, 0, 2)
  assert_eq(ctx, "ADV-BOUND-05.6: Size confirmed 0 bytes", size_0, 0)

  sys_close(fd)
  sys_unlink(test_file)
  sys_munmap(buf, 4096)
@end


@! ============================================================================
@! 3. HIGH-FREQUENCY CHURN & RAPID OPEN/CLOSE CYCLES (1000 CYCLES)
@! ============================================================================

@fn test_high_frequency_fd_churn(ctx)
  println("\n--- [Section 3] High-Frequency Open/Close FD Churn (1,000 Cycles) ---")

  pid = sys_getpid()
  test_file = "/tmp/maya_stress_churn_" + maya_int_to_str(pid) + ".tmp"
  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)

  initial_fd = sys_open(test_file, 578, 420)
  sys_close(initial_fd)
  sys_unlink(test_file)

  let success_count = 0
  let iter = 0
  @while iter < 1000
    fd = sys_open(test_file, 578, 420)
    @if fd >= 3
      sys_write(fd, buf, 32)
      sys_lseek(fd, 0, 0)
      sys_read(fd, buf, 32)
      c_res = sys_close(fd)
      u_res = sys_unlink(test_file)
      @if c_res == 0 && u_res == 0
        success_count = success_count + 1
      @end
    @end
    iter = iter + 1
  @end

  assert_eq(ctx, "ADV-CHURN-01.1: 1,000 rapid open/write/read/close/unlink cycles", success_count, 1000)

  @! Check that subsequent FD allocation is not leaked (should reuse low FD)
  final_fd = sys_open(test_file, 578, 420)
  assert_true(ctx, "ADV-CHURN-01.2: Post-churn FD allocation is low integer (< 50, no leak)", final_fd < 50)
  sys_close(final_fd)
  sys_unlink(test_file)

  sys_munmap(buf, 4096)
@end


@! ============================================================================
@! 4. MULTI-FD CONCURRENT DESCRIPTORS STRESS (64 SIMULTANEOUS FDS)
@! ============================================================================

@fn test_multi_fd_concurrency(ctx)
  println("\n--- [Section 4] Multi-FD Concurrent Descriptors Stress (64 FDs) ---")

  pid = sys_getpid()
  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  
  let fds = []
  let files = []

  let count = 64
  let i = 0
  @while i < count
    fname = "/tmp/maya_stress_mfd_" + maya_int_to_str(pid) + "_" + maya_int_to_str(i) + ".tmp"
    fd = sys_open(fname, 578, 420)
    fds.push(fd)
    files.push(fname)
    i = i + 1
  @end

  @! Verify all 64 FDs are valid
  let all_valid = 1
  i = 0
  @while i < count
    fd = fds[i]
    @if fd < 3
      all_valid = 0
    @end
    i = i + 1
  @end
  assert_true(ctx, "ADV-MFD-01.1: All 64 concurrent file descriptors opened successfully", all_valid != 0)

  @! Write to each FD its index+1 bytes
  i = 0
  @while i < count
    fd = fds[i]
    sys_write(fd, buf, i + 1)
    i = i + 1
  @end

  @! Verify file sizes independently
  let all_sizes_ok = 1
  i = 0
  @while i < count
    fd = fds[i]
    sz = sys_lseek(fd, 0, 2)
    @if sz != i + 1
      all_sizes_ok = 0
    @end
    i = i + 1
  @end
  assert_true(ctx, "ADV-MFD-01.2: All 64 concurrent files have exact distinct sizes", all_sizes_ok != 0)

  @! Close all 64 FDs
  let all_closed = 1
  i = 0
  @while i < count
    fd = fds[i]
    c_res = sys_close(fd)
    @if c_res != 0
      all_closed = 0
    @end
    i = i + 1
  @end
  assert_true(ctx, "ADV-MFD-01.3: All 64 concurrent file descriptors closed cleanly", all_closed != 0)

  @! Double close test across all 64 FDs -> all must return -EBADF (-9)
  let all_ebadf = 1
  i = 0
  @while i < count
    fd = fds[i]
    c2 = sys_close(fd)
    @if c2 != 0 - 9
      all_ebadf = 0
    @end
    i = i + 1
  @end
  assert_true(ctx, "ADV-MFD-01.4: Double close on all 64 FDs returns -EBADF (-9)", all_ebadf != 0)

  @! Unlink all 64 files
  i = 0
  @while i < count
    fname = files[i]
    sys_unlink(fname)
    i = i + 1
  @end

  sys_munmap(buf, 4096)
@end


@! ============================================================================
@! 5. INVALID POINTER ADDRESSES & EFAULT ROBUSTNESS
@! ============================================================================

@fn test_invalid_pointer_faults(ctx)
  println("\n--- [Section 5] Invalid Pointer Addresses & EFAULT Robustness ---")

  pid = sys_getpid()
  test_file = "/tmp/maya_stress_efault_" + maya_int_to_str(pid) + ".tmp"
  valid_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  fd = sys_open(test_file, 578, 420)

  @! 1. NULL pointer buffer to sys_write -> -EFAULT (-14)
  res_w_null = sys_write(fd, 0, 64)
  assert_errno(ctx, "ADV-EFAULT-01.1: sys_write NULL buffer returns -EFAULT (-14)", res_w_null, 14)

  @! Write data so file is not at EOF for read test
  sys_write(fd, valid_buf, 64)
  sys_lseek(fd, 0, 0)

  @! 2. NULL pointer buffer to sys_read -> -EFAULT (-14)
  res_r_null = sys_read(fd, 0, 64)
  assert_errno(ctx, "ADV-EFAULT-01.2: sys_read NULL buffer on non-empty file returns -EFAULT (-14)", res_r_null, 14)

  @! 3. Arbitrary unmapped low address (0x1) to sys_open -> -EFAULT (-14)
  res_open_bad = sys_open(1, 0, 0)
  assert_errno(ctx, "ADV-EFAULT-02.1: sys_open unmapped pointer returns -EFAULT (-14)", res_open_bad, 14)

  @! 4. NULL pointer to sys_stat -> -EFAULT (-14)
  res_stat_null = sys_stat(0, valid_buf)
  assert_errno(ctx, "ADV-EFAULT-03.1: sys_stat NULL pathname returns -EFAULT (-14)", res_stat_null, 14)

  @! 5. NULL pointer statbuf to sys_stat -> -EFAULT (-14)
  res_stat_buf_null = sys_stat(test_file, 0)
  assert_errno(ctx, "ADV-EFAULT-03.2: sys_stat NULL statbuf returns -EFAULT (-14)", res_stat_buf_null, 14)

  @! 6. NULL pointer to sys_access -> -EFAULT (-14)
  res_acc_null = sys_access(0, 0)
  assert_errno(ctx, "ADV-EFAULT-04.1: sys_access NULL pathname returns -EFAULT (-14)", res_acc_null, 14)

  @! 7. NULL pointer to sys_unlink -> -EFAULT (-14)
  res_unl_null = sys_unlink(0)
  assert_errno(ctx, "ADV-EFAULT-05.1: sys_unlink NULL pathname returns -EFAULT (-14)", res_unl_null, 14)

  @! 8. NULL pointer to sys_chdir -> -EFAULT (-14)
  res_chdir_null = sys_chdir(0)
  assert_errno(ctx, "ADV-EFAULT-06.1: sys_chdir NULL path returns -EFAULT (-14)", res_chdir_null, 14)

  @! 9. NULL pointer to sys_mkdir -> -EFAULT (-14)
  res_mkdir_null = sys_mkdir(0, 420)
  assert_errno(ctx, "ADV-EFAULT-07.1: sys_mkdir NULL path returns -EFAULT (-14)", res_mkdir_null, 14)

  @! 10. NULL pointer to sys_rmdir -> -EFAULT (-14)
  res_rmdir_null = sys_rmdir(0)
  assert_errno(ctx, "ADV-EFAULT-08.1: sys_rmdir NULL path returns -EFAULT (-14)", res_rmdir_null, 14)

  @! 11. NULL pointers to sys_rename -> -EFAULT (-14)
  res_ren_null = sys_rename(0, 0)
  assert_errno(ctx, "ADV-EFAULT-09.1: sys_rename NULL paths returns -EFAULT (-14)", res_ren_null, 14)

  sys_close(fd)
  sys_unlink(test_file)
  sys_munmap(valid_buf, 4096)
@end


@! ============================================================================
@! 6. NEGATIVE ERRNO CODES & INVALID SYSTEM CALL DISPATCH
@! ============================================================================

@fn test_negative_errno_coverage(ctx)
  println("\n--- [Section 6] Negative Errno Mapping & Invalid System Call Dispatch ---")

  buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)

  @! 1. Invalid syscall number -> -ENOSYS (-38)
  res_enosys = syscall(99999, 0, 0, 0, 0, 0, 0)
  assert_errno(ctx, "ADV-ERR-01.1: Invalid syscall number 99999 returns -ENOSYS (-38)", res_enosys, 38)

  @! 2. Negative file descriptors -> -EBADF (-9)
  res_neg_close = sys_close(0 - 1)
  assert_errno(ctx, "ADV-ERR-02.1: sys_close(-1) returns -EBADF (-9)", res_neg_close, 9)

  res_neg_read = sys_read(0 - 100, buf, 10)
  assert_errno(ctx, "ADV-ERR-02.2: sys_read(-100) returns -EBADF (-9)", res_neg_read, 9)

  res_neg_write = sys_write(0 - 42, buf, 10)
  assert_errno(ctx, "ADV-ERR-02.3: sys_write(-42) returns -EBADF (-9)", res_neg_write, 9)

  res_neg_fstat = sys_fstat(0 - 1, buf)
  assert_errno(ctx, "ADV-ERR-02.4: sys_fstat(-1) returns -EBADF (-9)", res_neg_fstat, 9)

  res_neg_fsync = sys_fsync(0 - 1)
  assert_errno(ctx, "ADV-ERR-02.5: sys_fsync(-1) returns -EBADF (-9)", res_neg_fsync, 9)

  @! 3. Invalid lseek whence -> -EINVAL (-22)
  dev_null = sys_open("/dev/null", 0, 0)
  res_bad_whence = sys_lseek(dev_null, 0, 999)
  assert_errno(ctx, "ADV-ERR-03.1: sys_lseek whence 999 returns -EINVAL (-22)", res_bad_whence, 22)
  sys_close(dev_null)

  @! 4. Open directory with O_WRONLY -> -EISDIR (-21)
  res_dir_wronly = sys_open("/tmp", 1, 0) @! O_WRONLY(1)
  assert_errno(ctx, "ADV-ERR-04.1: sys_open directory with O_WRONLY returns -EISDIR (-21)", res_dir_wronly, 21)

  @! 5. Negative length to munmap -> -EINVAL (-22)
  res_neg_munmap = sys_munmap(buf, 0 - 4096)
  assert_errno(ctx, "ADV-ERR-05.1: sys_munmap negative length returns -EINVAL (-22)", res_neg_munmap, 22)

  @! 6. Test exhaustive errno_name catalog
  assert_str_eq(ctx, "ADV-ERR-CAT.01: EPERM name", errno_name(1), "EPERM")
  assert_str_eq(ctx, "ADV-ERR-CAT.02: ENOENT name", errno_name(2), "ENOENT")
  assert_str_eq(ctx, "ADV-ERR-CAT.03: ESRCH name", errno_name(3), "ESRCH")
  assert_str_eq(ctx, "ADV-ERR-CAT.04: EINTR name", errno_name(4), "EINTR")
  assert_str_eq(ctx, "ADV-ERR-CAT.05: EIO name", errno_name(5), "EIO")
  assert_str_eq(ctx, "ADV-ERR-CAT.06: EBADF name", errno_name(9), "EBADF")
  assert_str_eq(ctx, "ADV-ERR-CAT.07: EAGAIN name", errno_name(11), "EAGAIN")
  assert_str_eq(ctx, "ADV-ERR-CAT.08: ENOMEM name", errno_name(12), "ENOMEM")
  assert_str_eq(ctx, "ADV-ERR-CAT.09: EACCES name", errno_name(13), "EACCES")
  assert_str_eq(ctx, "ADV-ERR-CAT.10: EFAULT name", errno_name(14), "EFAULT")
  assert_str_eq(ctx, "ADV-ERR-CAT.11: EEXIST name", errno_name(17), "EEXIST")
  assert_str_eq(ctx, "ADV-ERR-CAT.12: ENOTDIR name", errno_name(20), "ENOTDIR")
  assert_str_eq(ctx, "ADV-ERR-CAT.13: EISDIR name", errno_name(21), "EISDIR")
  assert_str_eq(ctx, "ADV-ERR-CAT.14: EINVAL name", errno_name(22), "EINVAL")
  assert_str_eq(ctx, "ADV-ERR-CAT.15: ENFILE name", errno_name(23), "ENFILE")
  assert_str_eq(ctx, "ADV-ERR-CAT.16: EMFILE name", errno_name(24), "EMFILE")
  assert_str_eq(ctx, "ADV-ERR-CAT.17: ENOSPC name", errno_name(28), "ENOSPC")
  assert_str_eq(ctx, "ADV-ERR-CAT.18: ESPIPE name", errno_name(29), "ESPIPE")
  assert_str_eq(ctx, "ADV-ERR-CAT.19: EROFS name", errno_name(30), "EROFS")
  assert_str_eq(ctx, "ADV-ERR-CAT.20: EPIPE name", errno_name(32), "EPIPE")
  assert_str_eq(ctx, "ADV-ERR-CAT.21: ENOSYS name", errno_name(38), "ENOSYS")
  assert_str_eq(ctx, "ADV-ERR-CAT.22: EADDRINUSE name", errno_name(98), "EADDRINUSE")
  assert_str_eq(ctx, "ADV-ERR-CAT.23: ECONNRESET name", errno_name(104), "ECONNRESET")
  assert_str_eq(ctx, "ADV-ERR-CAT.24: ETIMEDOUT name", errno_name(110), "ETIMEDOUT")
  assert_str_eq(ctx, "ADV-ERR-CAT.25: ECONNREFUSED name", errno_name(111), "ECONNREFUSED")

  sys_munmap(buf, 4096)
@end


@! ============================================================================
@! 7. PIPE, DUP, SOCKET, & IPC OPERATIONS
@! ============================================================================

@fn test_pipe_dup_socket_ipc(ctx)
  println("\n--- [Section 7] Pipe, Dup, Socket, & IPC Operations ---")

  pipe_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)

  @! 1. sys_pipe: creates 2 pipe descriptors in pipe_buf
  p_res = sys_pipe(pipe_buf)
  assert_eq(ctx, "ADV-IPC-01.1: sys_pipe creates anonymous pipe returns 0", p_res, 0)

  @! 2. sys_pipe2 with O_CLOEXEC (524288)
  p2_res = sys_pipe2(pipe_buf, 524288)
  assert_eq(ctx, "ADV-IPC-01.2: sys_pipe2 with O_CLOEXEC returns 0", p2_res, 0)

  @! 3. sys_dup on invalid fd -> -EBADF (-9)
  dup_bad = sys_dup(0 - 1)
  assert_errno(ctx, "ADV-IPC-02.1: sys_dup(-1) returns -EBADF (-9)", dup_bad, 9)

  @! 4. sys_dup on stdout (1)
  dup_stdout = sys_dup(1)
  assert_ge(ctx, "ADV-IPC-02.2: sys_dup(1) duplicates stdout descriptor", dup_stdout, 3)
  sys_close(dup_stdout)

  @! 5. Socket creation: AF_UNIX (1), SOCK_STREAM (1), protocol 0
  sock_fd = sys_socket(1, 1, 0)
  assert_ge(ctx, "ADV-IPC-03.1: sys_socket(AF_UNIX, SOCK_STREAM) creates socket", sock_fd, 3)

  @! 6. Shutdown socket on unconnected stream -> 0 or -ENOTCONN (-107)
  shut_res = sys_shutdown(sock_fd, 2) @! SHUT_RDWR(2)
  assert_true(ctx, "ADV-IPC-03.2: sys_shutdown handles socket cleanly", shut_res == 0 || shut_res == 0 - 107)

  sys_close(sock_fd)
  sys_munmap(pipe_buf, 4096)
@end


@! ============================================================================
@! 8. PROCESS & CLOCK / RANDOM OPERATIONS
@! ============================================================================

@fn test_process_clock_random(ctx)
  println("\n--- [Section 8] Process, Clock, & Random Subsystem ---")

  @! 1. PID / PPID
  pid = sys_getpid()
  ppid = sys_getppid()
  assert_true(ctx, "ADV-PROC-01.1: sys_getpid returns valid PID (> 0)", pid > 0)
  assert_true(ctx, "ADV-PROC-01.2: sys_getppid returns valid PPID (> 0)", ppid > 0)

  @! 2. sys_getrandom: fill 64-byte buffer with kernel entropy
  rand_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  nrand = sys_getrandom(rand_buf, 64, 0)
  assert_eq(ctx, "ADV-PROC-02.1: sys_getrandom reads 64 bytes kernel entropy", nrand, 64)

  @! 3. sys_clock_gettime: CLOCK_MONOTONIC (1)
  ts_buf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  clk_res = sys_clock_gettime(1, ts_buf)
  assert_eq(ctx, "ADV-PROC-03.1: sys_clock_gettime CLOCK_MONOTONIC returns 0", clk_res, 0)

  sys_munmap(rand_buf, 4096)
  sys_munmap(ts_buf, 4096)
@end


@! ============================================================================
@! MASTER ADVERSARIAL RUNNER ENTRYPOINT
@! ============================================================================

@fn main()
  println("=================================================================")
  println("▶ MAYA PURE MAYA SYSCALL ADVERSARIAL STRESS TEST SUITE")
  println("=================================================================")

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_large_io_and_mprotect(ctx)
  test_zero_length_and_boundaries(ctx)
  test_high_frequency_fd_churn(ctx)
  test_multi_fd_concurrency(ctx)
  test_invalid_pointer_faults(ctx)
  test_negative_errno_coverage(ctx)
  test_pipe_dup_socket_ipc(ctx)
  test_process_clock_random(ctx)

  println("\n=================================================================")
  println("📊 ADVERSARIAL TEST EXECUTION SUMMARY")
  println("=================================================================")
  println("  Total Stress Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed                  : " + maya_int_to_str(ctx.passed))
  println("  Failed                  : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] 100% of Syscall Adversarial Stress Tests Passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more Syscall Adversarial Stress Tests Failed.")
    return 1
  @end
@end
