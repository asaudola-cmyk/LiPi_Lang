@! ============================================================================
@! MAYA M1 SYSCALL GATEWAY EMPIRICAL CHALLENGER TEST SUITE (PURE MAYA)
@! File: tests/syscall/test_challenger_syscall_boundary.maya
@! Target: runtime/maya_syscall.maya & runtime/syscall.s
@! Scope: Empirical adversarial boundary & stress verification
@! ============================================================================

import "universe/os/syscalls"

@struct ChallengerContext
  total: 0
  passed: 0
  failed: 0
@end

@fn c_assert_eq(ctx, name, actual, expected)
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

@fn c_assert_str_eq(ctx, name, actual, expected)
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

@fn c_assert_true(ctx, name, condition)
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

@fn c_assert_errno(ctx, name, actual_ret, expected_errno)
  ctx.total = ctx.total + 1
  let exp_ret = 0 - expected_errno
  @if actual_ret == exp_ret
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> correctly returned -errno (" + maya_int_to_str(actual_ret) + ")")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected -errno " + maya_int_to_str(exp_ret) + ", got " + maya_int_to_str(actual_ret))
    return 0
  @end
@end

@! ============================================================================
@! Test 1: Pure Maya Errno Helper Invariants & Boundaries
@! ============================================================================
@fn test_errno_helpers(ctx)
  println("\n--- [Test 1] Pure Maya Errno Helper Invariants & Boundaries ---")

  @! Positive values (0 to 1000000) are OK
  c_assert_true(ctx, "ERR-01: is_ok(0) is true", is_ok(0))
  c_assert_true(ctx, "ERR-02: is_ok(4096) is true", is_ok(4096))
  c_assert_true(ctx, "ERR-03: !is_error(0) is true", !is_error(0))
  c_assert_true(ctx, "ERR-04: get_errno(0) == 0", get_errno(0) == 0)

  @! Standard Linux negative errnos (-1 to -4095)
  c_assert_true(ctx, "ERR-05: is_error(-1) is true (EPERM)", is_error(0 - 1))
  c_assert_eq(ctx, "ERR-06: get_errno(-1) == 1", get_errno(0 - 1), 1)
  c_assert_true(ctx, "ERR-07: is_error(-4095) is true", is_error(0 - 4095))
  c_assert_eq(ctx, "ERR-08: get_errno(-4095) == 4095", get_errno(0 - 4095), 4095)

  @! Values beyond -4095 (e.g. -4096, which can be high pointer addresses)
  c_assert_true(ctx, "ERR-09: is_error(-4096) is false (pointer range)", !is_error(0 - 4096))

  @! Check errno names and strerrors
  c_assert_str_eq(ctx, "ERR-10: errno_name(1)", errno_name(1), "EPERM")
  c_assert_str_eq(ctx, "ERR-11: errno_name(9)", errno_name(9), "EBADF")
  c_assert_str_eq(ctx, "ERR-12: errno_name(14)", errno_name(14), "EFAULT")
  c_assert_str_eq(ctx, "ERR-13: errno_name(22)", errno_name(22), "EINVAL")
  c_assert_str_eq(ctx, "ERR-14: errno_name(38)", errno_name(38), "ENOSYS")

  c_assert_str_eq(ctx, "ERR-15: errno_strerror(9)", errno_strerror(9), "Bad file descriptor")
  c_assert_str_eq(ctx, "ERR-16: errno_strerror(14)", errno_strerror(14), "Bad address")
  c_assert_str_eq(ctx, "ERR-17: errno_strerror(38)", errno_strerror(38), "Function not implemented")
@end

@! ============================================================================
@! Test 2: Memory Subsystem & Alignment (sys_mmap, sys_mprotect, sys_munmap)
@! ============================================================================
@fn test_memory_subsystem(ctx)
  println("\n--- [Test 2] Memory Subsystem (sys_mmap, sys_mprotect, sys_munmap) ---")

  @! Allocate 2MB = 2097152 bytes (512 pages)
  let size_2mb = 2097152
  let addr = sys_mmap(0, size_2mb, PROT_READ() | PROT_WRITE(), MAP_PRIVATE() | MAP_ANON(), 0 - 1, 0)
  c_assert_true(ctx, "MEM-01: sys_mmap 2MB buffer returns non-null pointer", addr > 0)
  c_assert_eq(ctx, "MEM-02: 2MB buffer is 4096-byte page aligned", addr % 4096, 0)

  @! Change protections to PROT_READ
  let p_ro = sys_mprotect(addr, size_2mb, PROT_READ())
  c_assert_eq(ctx, "MEM-03: sys_mprotect PROT_READ on 2MB mapping", p_ro, 0)

  @! Restore protections to PROT_READ | PROT_WRITE
  let p_rw = sys_mprotect(addr, size_2mb, PROT_READ() | PROT_WRITE())
  c_assert_eq(ctx, "MEM-04: sys_mprotect PROT_READ|PROT_WRITE restore", p_rw, 0)

  @! Deallocate mapping
  let unmap_res = sys_munmap(addr, size_2mb)
  c_assert_eq(ctx, "MEM-05: sys_munmap 2MB buffer", unmap_res, 0)

  @! Boundary error: zero length munmap -> -EINVAL (-22)
  let z_unmap = sys_munmap(addr, 0)
  c_assert_errno(ctx, "MEM-06: sys_munmap length 0 returns -EINVAL (-22)", z_unmap, 22)
@end

@! ============================================================================
@! Test 3: File I/O, Pipes, & Seek Operations
@! ============================================================================
@fn test_file_and_pipe_io(ctx)
  println("\n--- [Test 3] File I/O, Pipes, & Seek Operations ---")

  let pid = sys_getpid()
  let test_path = "/tmp/maya_challenger_test_" + maya_int_to_str(pid) + ".tmp"
  let buf = sys_mmap(0, 4096, PROT_READ() | PROT_WRITE(), MAP_PRIVATE() | MAP_ANON(), 0 - 1, 0)

  @! Open file O_CREAT | O_RDWR | O_TRUNC (578) mode 0644 (420)
  let fd = sys_open(test_path, 578, 420)
  c_assert_true(ctx, "IO-01: sys_open temporary file", fd >= 3)

  @! Write 1024 bytes
  let w_res = sys_write(fd, buf, 1024)
  c_assert_eq(ctx, "IO-02: sys_write 1024 bytes", w_res, 1024)

  @! Seek to end
  let end_pos = sys_lseek(fd, 0, SEEK_END())
  c_assert_eq(ctx, "IO-03: sys_lseek SEEK_END confirms 1024 bytes", end_pos, 1024)

  @! Seek to start
  let start_pos = sys_lseek(fd, 0, SEEK_SET())
  c_assert_eq(ctx, "IO-04: sys_lseek SEEK_SET resets offset to 0", start_pos, 0)

  @! Read back 1024 bytes
  let r_res = sys_read(fd, buf, 1024)
  c_assert_eq(ctx, "IO-05: sys_read 1024 bytes", r_res, 1024)

  @! Close file
  let c_res = sys_close(fd)
  c_assert_eq(ctx, "IO-06: sys_close returns 0", c_res, 0)

  @! Unlink file
  let u_res = sys_unlink(test_path)
  c_assert_eq(ctx, "IO-07: sys_unlink returns 0", u_res, 0)

  @! Test pipe operations
  let pipe_buf = sys_mmap(0, 4096, PROT_READ() | PROT_WRITE(), MAP_PRIVATE() | MAP_ANON(), 0 - 1, 0)
  let p_res = sys_pipe(pipe_buf)
  c_assert_eq(ctx, "IO-08: sys_pipe creates anonymous pipe", p_res, 0)

  let p2_res = sys_pipe2(pipe_buf, O_CLOEXEC())
  c_assert_eq(ctx, "IO-09: sys_pipe2 with O_CLOEXEC", p2_res, 0)

  sys_munmap(buf, 4096)
  sys_munmap(pipe_buf, 4096)
@end

@! ============================================================================
@! Test 4: Adversarial Boundaries & Negative Inputs
@! ============================================================================
@fn test_adversarial_boundaries(ctx)
  println("\n--- [Test 4] Adversarial Boundaries & Negative Inputs ---")

  let buf = sys_mmap(0, 4096, PROT_READ() | PROT_WRITE(), MAP_PRIVATE() | MAP_ANON(), 0 - 1, 0)

  @! 1. Invalid syscall number -> -ENOSYS (-38)
  let bad_sys = syscall(999999, 0, 0, 0, 0, 0, 0)
  c_assert_errno(ctx, "ADV-01: syscall(999999) returns -ENOSYS (-38)", bad_sys, 38)

  @! 2. Negative file descriptors -> -EBADF (-9)
  let bad_close = sys_close(0 - 1)
  c_assert_errno(ctx, "ADV-02: sys_close(-1) returns -EBADF (-9)", bad_close, 9)

  let bad_read = sys_read(0 - 50, buf, 16)
  c_assert_errno(ctx, "ADV-03: sys_read(-50) returns -EBADF (-9)", bad_read, 9)

  let bad_write = sys_write(0 - 100, buf, 16)
  c_assert_errno(ctx, "ADV-04: sys_write(-100) returns -EBADF (-9)", bad_write, 9)

  let bad_fstat = sys_fstat(0 - 1, buf)
  c_assert_errno(ctx, "ADV-05: sys_fstat(-1) returns -EBADF (-9)", bad_fstat, 9)

  let bad_fsync = sys_fsync(0 - 1)
  c_assert_errno(ctx, "ADV-06: sys_fsync(-1) returns -EBADF (-9)", bad_fsync, 9)

  @! 3. NULL pointer addresses -> -EFAULT (-14)
  let bad_open_null = sys_open(0, 0, 0)
  c_assert_errno(ctx, "ADV-07: sys_open(0) returns -EFAULT (-14)", bad_open_null, 14)

  let bad_stat_null = sys_stat(0, buf)
  c_assert_errno(ctx, "ADV-08: sys_stat(0) returns -EFAULT (-14)", bad_stat_null, 14)

  let bad_access_null = sys_access(0, 0)
  c_assert_errno(ctx, "ADV-09: sys_access(0) returns -EFAULT (-14)", bad_access_null, 14)

  let bad_unlink_null = sys_unlink(0)
  c_assert_errno(ctx, "ADV-10: sys_unlink(0) returns -EFAULT (-14)", bad_unlink_null, 14)

  let bad_pipe_null = sys_pipe(0)
  c_assert_errno(ctx, "ADV-11: sys_pipe(0) returns -EFAULT (-14)", bad_pipe_null, 14)

  let bad_clock_null = sys_clock_gettime(CLOCK_MONOTONIC(), 0)
  c_assert_errno(ctx, "ADV-12: sys_clock_gettime(0) returns -EFAULT (-14)", bad_clock_null, 14)

  let bad_random_null = sys_getrandom(0, 32, 0)
  c_assert_errno(ctx, "ADV-13: sys_getrandom(0) returns -EFAULT (-14)", bad_random_null, 14)

  sys_munmap(buf, 4096)
@end

@! ============================================================================
@! Test 5: High-Frequency Churn Stress (1,000 Rapid Cycles)
@! ============================================================================
@fn test_stress_churn(ctx)
  println("\n--- [Test 5] High-Frequency Churn Stress (1,000 Cycles) ---")

  let pid = sys_getpid()
  let churn_path = "/tmp/maya_challenger_churn_" + maya_int_to_str(pid) + ".tmp"
  let buf = sys_mmap(0, 4096, PROT_READ() | PROT_WRITE(), MAP_PRIVATE() | MAP_ANON(), 0 - 1, 0)

  let success_count = 0
  let i = 0
  @while i < 1000
    let fd = sys_open(churn_path, 578, 420)
    @if fd >= 3
      sys_write(fd, buf, 64)
      sys_lseek(fd, 0, SEEK_SET())
      sys_read(fd, buf, 64)
      let c = sys_close(fd)
      let u = sys_unlink(churn_path)
      @if c == 0 && u == 0
        success_count = success_count + 1
      @end
    @end
    i = i + 1
  @end

  c_assert_eq(ctx, "CHURN-01: 1,000 rapid file open/write/read/close/unlink cycles", success_count, 1000)

  @! Post-churn FD allocation must be low (< 50, zero descriptor leak)
  let test_fd = sys_open(churn_path, 578, 420)
  c_assert_true(ctx, "CHURN-02: FD after 1,000 cycles is low integer (< 50, zero leak)", test_fd < 50)
  sys_close(test_fd)
  sys_unlink(churn_path)

  sys_munmap(buf, 4096)
@end

@! ============================================================================
@! Master Entrypoint
@! ============================================================================
@fn main()
  println("=================================================================")
  println("⚔️  MAYA M1 PURE MAYA SYSCALL CHALLENGER ADVERSARIAL SUITE ⚔️")
  println("=================================================================")

  let ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_errno_helpers(ctx)
  test_memory_subsystem(ctx)
  test_file_and_pipe_io(ctx)
  test_adversarial_boundaries(ctx)
  test_stress_churn(ctx)

  println("\n=================================================================")
  println("📊 CHALLENGER AUDIT SUMMARY REPORT")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [VERDICT: APPROVE] 100% of pure Maya syscall challenges passed!")
    return 0
  @else
    println("\n✗ [VERDICT: REQUEST_CHANGES] One or more challenges failed.")
    return 1
  @end
@end
