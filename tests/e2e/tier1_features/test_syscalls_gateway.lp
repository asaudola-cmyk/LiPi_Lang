// @! RUN: %maya %file
// @! EXPECT: ✓ Feature: Kernel Syscalls Gateway PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 1
// @! TAGS: syscalls, gateway, posix, io, mmap, getpid

@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE COVERAGE: LINUX KERNEL SYSCALL GATEWAY
@! File: tests/e2e/tier1_features/test_syscalls_gateway.maya
@! ============================================================================

import "universe/os/syscalls"

@fn main()
  println("=================================================================")
  println("▶ [TIER 1] Feature: Linux Kernel Syscall Gateway")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! TC-SYS-01: File Write & Read Lifecycle
  total = total + 1
  pid = sys_getpid()
  test_file = "/tmp/maya_t1_sys_" + maya_int_to_str(pid) + ".tmp"

  @! Open with O_CREAT (64) | O_RDWR (2) | O_TRUNC (512) = 578, mode 0644 (420)
  fd_w = sys_open(test_file, 578, 420)
  buf_w = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  
  @! Populate buffer via direct file copy or raw byte write
  written = sys_write(fd_w, buf_w, 64)
  sys_close(fd_w)

  @! Read back
  fd_r = sys_open(test_file, 0, 0)
  buf_r = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  n_read = sys_read(fd_r, buf_r, 64)
  sys_close(fd_r)
  sys_unlink(test_file)
  sys_munmap(buf_w, 4096)
  sys_munmap(buf_r, 4096)

  @if fd_w > 0 && written == 64 && fd_r > 0 && n_read == 64
    passed = passed + 1
    println("  [PASS] TC-SYS-01: File I/O lifecycle (sys_open, sys_write, sys_read, sys_close, sys_unlink)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-SYS-01: File I/O lifecycle")
  @end

  @! TC-SYS-02: Memory Mapping (sys_mmap & sys_munmap)
  total = total + 1
  @! PROT_READ (1) | PROT_WRITE (2) = 3, MAP_PRIVATE (2) | MAP_ANON (32) = 34
  mmap_ptr = sys_mmap(0, 8192, 3, 34, 0 - 1, 0)
  unmap_res = sys_munmap(mmap_ptr, 8192)
  @if mmap_ptr > 0 && unmap_res == 0
    passed = passed + 1
    println("  [PASS] TC-SYS-02: Anonymous memory mapping (sys_mmap 8KB & sys_munmap == 0)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-SYS-02: sys_mmap / sys_munmap")
  @end

  @! TC-SYS-03: File Seeking via sys_lseek
  total = total + 1
  test_file_seek = "/tmp/maya_t1_sys_seek_" + maya_int_to_str(pid) + ".tmp"
  fd_seek = sys_open(test_file_seek, 578, 420)
  payload100 = "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
  n_written = sys_write(fd_seek, payload100, 100)
  pos_start = sys_lseek(fd_seek, 0, 0)  @! SEEK_SET
  pos_cur = sys_lseek(fd_seek, 25, 1)   @! SEEK_CUR
  pos_end = sys_lseek(fd_seek, 0, 2)    @! SEEK_END
  sys_close(fd_seek)
  sys_unlink(test_file_seek)

  @if pos_start == 0 && pos_cur == 25 && pos_end == 100
    passed = passed + 1
    println("  [PASS] TC-SYS-03: sys_lseek offsets (SEEK_SET: 0, SEEK_CUR: 25, SEEK_END: 100)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-SYS-03: sys_lseek got " + pos_start.to_str() + ", " + pos_cur.to_str() + ", " + pos_end.to_str() + " (written=" + n_written.to_str() + ", fd=" + fd_seek.to_str() + ")")
  @end

  @! TC-SYS-04: Process ID Information
  total = total + 1
  curr_pid = sys_getpid()
  curr_ppid = sys_getppid()
  @if curr_pid > 0 && curr_ppid > 0
    passed = passed + 1
    println("  [PASS] TC-SYS-04: Process ID queries (PID > 0, PPID > 0)")
  @else
    failed = failed + 1
    println("  [FAIL] TC-SYS-04: Process ID queries")
  @end

  @! TC-SYS-05: Hardware Clock & Time (sys_clock_gettime)
  total = total + 1
  ts_buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  clk_res = sys_clock_gettime(1, ts_buf)  @! CLOCK_MONOTONIC = 1
  sys_munmap(ts_buf, 16)
  @if clk_res == 0
    passed = passed + 1
    println("  [PASS] TC-SYS-05: sys_clock_gettime(CLOCK_MONOTONIC) == 0")
  @else
    failed = failed + 1
    println("  [FAIL] TC-SYS-05: sys_clock_gettime")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Feature: Kernel Syscalls Gateway PASSED")
    return 0
  @else
    println("✗ Feature: Kernel Syscalls Gateway FAILED")
    return 1
  @end
@end
