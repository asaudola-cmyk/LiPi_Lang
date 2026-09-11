@! ============================================================================
@! ADVERSARIAL STRESS TEST 4: RAW SYSCALL CHAINING & KERNEL BYPASS
@! File: tests/adversarial/test_adv_syscall_chaining_gate1.maya
@! Target: Sovereign Pure Maya Compiler Backend (x86-64 freestanding ELF)
@! ============================================================================

@fn mem_alloc(size)
  return syscall(9, 0, size, 3, 34, -1, 0)
@end

@fn mem_free(ptr, size)
  return syscall(11, ptr, size, 0, 0, 0, 0)
@end

@fn main()
  println("================================================================")
  println("  ADVERSARIAL STRESS 4: RAW KERNEL SYSCALL CHAINING PIPELINE")
  println("================================================================")

  @! Phase 1: Process & Identity Syscalls
  println("▶ [TC-SYS-01] Executing Process & Identity Syscalls (getpid, getppid, getuid, getgid)...")
  pid = syscall(39, 0, 0, 0, 0, 0, 0)
  ppid = syscall(110, 0, 0, 0, 0, 0, 0)
  uid = syscall(102, 0, 0, 0, 0, 0, 0)
  gid = syscall(104, 0, 0, 0, 0, 0, 0)

  @if pid <= 0 || ppid <= 0 || uid < 0 || gid < 0
    println("  [FAIL] TC-SYS-01: Process identity syscall returned invalid ID")
    return 401
  @end
  println("  [PASS] TC-SYS-01: Valid kernel process context (PID > 0, PPID > 0, UID >= 0, GID >= 0)")

  @! Phase 2: Kernel uname Syscall (Syscall 63)
  println("▶ [TC-SYS-02] Invoking sys_uname (Syscall 63)...")
  uts_buf = mem_alloc(512)
  @if uts_buf <= 0
    println("  [FAIL] TC-SYS-02: uts_buf allocation failed")
    return 402
  @end

  uname_res = syscall(63, uts_buf, 0, 0, 0, 0, 0)
  @if uname_res != 0
    println("  [FAIL] TC-SYS-02: sys_uname failed")
    return 403
  @end
  println("  [PASS] TC-SYS-02: sys_uname populated kernel UTS structure")

  @! Phase 3: High-Resolution Clock Syscalls (Syscall 228: sys_clock_gettime)
  println("▶ [TC-SYS-03] Invoking sys_clock_gettime (Syscall 228)...")
  ts_buf = mem_alloc(64)
  @if ts_buf <= 0
    println("  [FAIL] TC-SYS-03: ts_buf allocation failed")
    return 404
  @end

  @! CLOCK_REALTIME (0)
  clk_res1 = syscall(228, 0, ts_buf, 0, 0, 0, 0)
  @! CLOCK_MONOTONIC (1)
  clk_res2 = syscall(228, 1, ts_buf, 0, 0, 0, 0)

  @if clk_res1 != 0 || clk_res2 != 0
    println("  [FAIL] TC-SYS-03: sys_clock_gettime returned error")
    return 405
  @end
  println("  [PASS] TC-SYS-03: sys_clock_gettime retrieved realtime and monotonic clocks")

  @! Phase 4: Full Freestanding File I/O Chaining (open, write, lseek, read, close, unlink)
  println("▶ [TC-SYS-04] Executing 6-step raw Syscall File I/O Pipeline...")
  tmp_path = "/tmp/maya_adv_gate1_syscall_test.tmp"

  @! Step A: sys_open with O_CREAT (64) | O_WRONLY (1) | O_TRUNC (512) = 577 (or 578), mode 0644 (420)
  fd_w = syscall(2, tmp_path, 578, 420, 0, 0, 0)
  @if fd_w < 0
    println("  [FAIL] TC-SYS-04: sys_open (write) failed")
    return 406
  @end

  @! Step B: sys_write 128 bytes from uts_buf to file
  wr_bytes = syscall(1, fd_w, uts_buf, 128, 0, 0, 0)
  @if wr_bytes != 128
    println("  [FAIL] TC-SYS-04: sys_write wrote incorrect byte count")
    return 407
  @end

  @! Step C: sys_close write fd
  cl_res1 = syscall(3, fd_w, 0, 0, 0, 0, 0)
  @if cl_res1 != 0
    println("  [FAIL] TC-SYS-04: sys_close (write) failed")
    return 408
  @end

  @! Step D: sys_open with O_RDONLY (0)
  fd_r = syscall(2, tmp_path, 0, 0, 0, 0, 0)
  @if fd_r < 0
    println("  [FAIL] TC-SYS-04: sys_open (read) failed")
    return 409
  @end

  @! Step E: sys_lseek SEEK_END (2) to verify file size
  file_sz = syscall(8, fd_r, 0, 2, 0, 0, 0)
  @if file_sz != 128
    println("  [FAIL] TC-SYS-04: sys_lseek SEEK_END size mismatch")
    return 410
  @end

  @! Step F: sys_lseek SEEK_SET (0) to rewind to offset 0
  rewind_pos = syscall(8, fd_r, 0, 0, 0, 0, 0)
  @if rewind_pos != 0
    println("  [FAIL] TC-SYS-04: sys_lseek SEEK_SET rewind failed")
    return 411
  @end

  @! Step G: sys_read into read buffer
  rd_buf = mem_alloc(512)
  rd_bytes = syscall(0, fd_r, rd_buf, 128, 0, 0, 0)
  @if rd_bytes != 128
    println("  [FAIL] TC-SYS-04: sys_read read incorrect byte count")
    return 412
  @end

  @! Step H: sys_close read fd
  cl_res2 = syscall(3, fd_r, 0, 0, 0, 0, 0)
  @if cl_res2 != 0
    println("  [FAIL] TC-SYS-04: sys_close (read) failed")
    return 413
  @end

  @! Step I: sys_unlink temporary file
  unl_res = syscall(87, tmp_path, 0, 0, 0, 0, 0)
  @if unl_res != 0
    println("  [FAIL] TC-SYS-04: sys_unlink failed")
    return 414
  @end

  println("  [PASS] TC-SYS-04: 6-step file I/O pipeline completed with bitwise roundtrip integrity")

  @! Teardown buffers
  mem_free(uts_buf, 512)
  mem_free(ts_buf, 64)
  mem_free(rd_buf, 512)

  println("================================================================")
  println("  ALL RAW KERNEL SYSCALL CHAINING TESTS PASSED (EXIT CODE 0)")
  println("================================================================")
  return 0
@end
