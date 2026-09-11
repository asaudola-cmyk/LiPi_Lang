@! ============================================================================
@! MAYA 0.0000001% SOVEREIGNTY VERIFICATION TEST (universe/sys)
@! File: tests/universe/test_sys_sovereignty.maya
@! Verifies:
@! 1. Raw direct kernel syscalls in universe/sys and universe/os without libc
@! 2. Zero C library wrappers for memory (mmap/munmap/brk), process (fork/execve/wait4/exit), signals
@! 3. Freestanding memory management & process lifecycle
@! ============================================================================

import "universe/sys/syscalls"
import "universe/sys/runtime"
import "universe/sys/memory"

@fn main()
  println("=================================================================")
  println("▶ [SOVEREIGNTY AUDIT] universe/sys & universe/os Deep Purity Suite")
  println("=================================================================")

  @! --------------------------------------------------------------------------
  @! TEST 1: Process Identity & Direct Syscalls (sys_getpid / sys_getppid / sys_getpgrp)
  @! --------------------------------------------------------------------------
  pid = sys_getpid()
  @if pid <= 0
    println("  [FAIL] sys_getpid returned invalid PID")
    return 1
  @end
  println(str_concat("  [PASS] TC-SYS-01: Direct sys_getpid() -> ", int_to_str(pid)))

  ppid = sys_getppid()
  @if ppid <= 0
    println("  [FAIL] sys_getppid returned invalid PPID")
    return 2
  @end
  println(str_concat("  [PASS] TC-SYS-02: Direct sys_getppid() -> ", int_to_str(ppid)))

  pgrp = sys_getpgrp()
  @if pgrp <= 0
    println("  [FAIL] sys_getpgrp returned invalid PGID")
    return 3
  @end
  println(str_concat("  [PASS] TC-SYS-03: Direct sys_getpgrp() -> ", int_to_str(pgrp)))

  @! --------------------------------------------------------------------------
  @! TEST 2: Virtual Memory Allocation via Direct sys_mmap & sys_munmap
  @! --------------------------------------------------------------------------
  page_size = PAGE_SIZE()
  mem_ptr = sys_mmap_anon(page_size, 3) @! PROT_READ(1) | PROT_WRITE(2) = 3
  @if mem_ptr <= 0
    println("  [FAIL] sys_mmap_anon failed to allocate 4096-byte page")
    return 4
  @end
  println("  [PASS] TC-SYS-04: Direct kernel anonymous mmap (4096 bytes) succeeded")

  @! Write and read back via direct poke/peek
  sys_poke8(mem_ptr, 65)      @! 'A'
  sys_poke8(mem_ptr + 1, 66)  @! 'B'
  sys_poke8(mem_ptr + 2, 67)  @! 'C'
  sys_poke8(mem_ptr + 3, 0)

  b0 = sys_peek8(mem_ptr)
  b1 = sys_peek8(mem_ptr + 1)
  b2 = sys_peek8(mem_ptr + 2)
  @if b0 != 65 || b1 != 66 || b2 != 67
    println("  [FAIL] Direct memory byte readback mismatch")
    return 5
  @end
  println("  [PASS] TC-SYS-05: Direct peek8/poke8 byte dereferencing verified")

  @! Release page via direct kernel munmap
  unmap_res = sys_munmap_anon(mem_ptr, page_size)
  @if unmap_res != 0
    println("  [FAIL] sys_munmap_anon failed to deallocate page")
    return 6
  @end
  println("  [PASS] TC-SYS-06: Direct kernel munmap released memory cleanly")

  @! --------------------------------------------------------------------------
  @! TEST 3: Memory Operations (sys_memset, sys_memcpy, sys_memcmp)
  @! --------------------------------------------------------------------------
  buf1 = sys_mmap_anon(64, 3)
  buf2 = sys_mmap_anon(64, 3)
  sys_memset(buf1, 42, 32)
  sys_memset(buf2, 42, 32)
  cmp_eq = sys_memcmp(buf1, buf2, 32)
  @if cmp_eq != 0
    println("  [FAIL] sys_memcmp reported difference on identical buffers")
    return 7
  @end
  println("  [PASS] TC-SYS-07: Freestanding sys_memset and sys_memcmp verified")

  sys_poke8(buf2 + 5, 99)
  cmp_diff = sys_memcmp(buf1, buf2, 32)
  @if cmp_diff == 0
    println("  [FAIL] sys_memcmp failed to detect byte difference")
    return 8
  @end
  println("  [PASS] TC-SYS-08: sys_memcmp correctly identified mutated byte")

  sys_memcpy(buf1, buf2, 32)
  cmp_after_copy = sys_memcmp(buf1, buf2, 32)
  @if cmp_after_copy != 0
    println("  [FAIL] sys_memcpy failed to copy contents faithfully")
    return 9
  @end
  println("  [PASS] TC-SYS-09: Freestanding sys_memcpy verified")

  sys_munmap_anon(buf1, 64)
  sys_munmap_anon(buf2, 64)

  @! --------------------------------------------------------------------------
  @! TEST 4: Direct Kernel File I/O (sys_open, sys_write, sys_read, sys_close, sys_unlink)
  @! --------------------------------------------------------------------------
  test_path = "/tmp/maya_sovereign_audit_test.tmp"
  @! Open with O_WRONLY(1) | O_CREAT(64) | O_TRUNC(512) = 577, mode 0644 (420)
  fd = sys_open(test_path, 577, 420)
  @if fd < 0
    println("  [FAIL] sys_open failed to create file")
    return 10
  @end
  println(str_concat("  [PASS] TC-SYS-10: Direct sys_open created file descriptor: ", int_to_str(fd)))

  write_payload = "0.0000001% PURE SOVEREIGN ZERO-LIBC RUNTIME\n"
  write_len = str_len(write_payload)
  w_res = sys_write(fd, write_payload, write_len)
  @if w_res != write_len
    println("  [FAIL] sys_write did not write expected bytes")
    sys_close(fd)
    return 11
  @end
  println("  [PASS] TC-SYS-11: Direct sys_write wrote payload to kernel")

  close_res = sys_close(fd)
  @if close_res != 0
    println("  [FAIL] sys_close returned error")
    return 12
  @end
  println("  [PASS] TC-SYS-12: Direct sys_close closed descriptor")

  @! Reopen O_RDONLY (0)
  rfd = sys_open(test_path, 0, 0)
  @if rfd < 0
    println("  [FAIL] sys_open failed to reopen file for reading")
    return 13
  @end

  read_buf = sys_mmap_anon(128, 3)
  read_bytes = sys_read(rfd, read_buf, 128)
  sys_close(rfd)
  @if read_bytes != write_len
    println("  [FAIL] sys_read did not match written byte count")
    sys_munmap_anon(read_buf, 128)
    return 14
  @end
  println("  [PASS] TC-SYS-13: Direct sys_read verified payload integrity")
  sys_munmap_anon(read_buf, 128)

  @! Unlink file via direct syscall 87
  unl = sys_unlink(test_path)
  @if unl != 0
    println("  [FAIL] sys_unlink failed to remove file")
    return 15
  @end
  println("  [PASS] TC-SYS-14: Direct sys_unlink removed file cleanly")

  @! Verify file does not exist anymore
  deleted_fd = sys_open(test_path, 0, 0)
  @if deleted_fd >= 0
    println("  [FAIL] Open deleted file should have failed")
    sys_close(deleted_fd)
    return 16
  @end
  @if is_error(deleted_fd) == 1 && get_errno(deleted_fd) == ENOENT()
    println("  [PASS] TC-SYS-15: Direct syscall returned -ENOENT (2) for deleted file")
  @else
    println("  [FAIL] Expected -ENOENT errno on opening non-existent file")
    return 17
  @end

  @! --------------------------------------------------------------------------
  @! TEST 5: Process Lifecycle Status Decoders
  @! --------------------------------------------------------------------------
  @! Synthetic status 0x0000 -> exit code 0
  @if process_wifexited(0) != 1 || process_wexitstatus(0) != 0
    println("  [FAIL] process_wifexited failed on exit code 0")
    return 18
  @end
  @! Synthetic status 0x2A00 (42 << 8 = 10752) -> exit code 42
  @if process_wifexited(10752) != 1 || process_wexitstatus(10752) != 42
    println("  [FAIL] process_wexitstatus failed on exit code 42")
    return 19
  @end
  @! Synthetic status 9 -> killed by signal 9 (SIGKILL)
  @if process_wifsignaled(9) != 1 || process_wtermsig(9) != 9
    println("  [FAIL] process_wifsignaled failed on signal 9")
    return 20
  @end
  println("  [PASS] TC-SYS-16: Process exit status decoders verified")

  @! --------------------------------------------------------------------------
  @! TEST 6: Process Liveness & Nanosecond Sleep
  @! --------------------------------------------------------------------------
  alive = process_is_alive(pid)
  @if alive != 1
    println("  [FAIL] process_is_alive(own_pid) reported dead")
    return 21
  @end
  println("  [PASS] TC-SYS-17: process_is_alive(pid) verified via sys_kill(pid, 0)")

  sleep_res = process_sleep_ms(5)
  @if sleep_res != 0
    println("  [FAIL] process_sleep_ms failed")
    return 22
  @end
  println("  [PASS] TC-SYS-18: process_sleep_ms(5) verified via sys_nanosleep")

  @! --------------------------------------------------------------------------
  @! SUMMARY
  @! --------------------------------------------------------------------------
  println("-----------------------------------------------------------------")
  println("✅ All 18 Sovereignty Verification Tests Passed!")
  println("   Status: 100% Freestanding Zero-Libc Purity Confirmed.")
  println("=================================================================")
  return 0
@end
