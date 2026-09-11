@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE F01: RAW SYSCALL LAYER
@! File: tests/e2e/tier1_features/os/test_f01_syscalls.maya
@! Description: Validates Linux x86-64 direct syscall interfaces (0x0F 0x05)
@! ============================================================================

import "universe/os/syscalls"
import "universe/tools/maya_test"

@fn test_f01_01_pid_ppid()
  pid = sys_getpid()
  ppid = sys_getppid()
  assert_gt(pid, 0, "sys_getpid() must return positive PID")
  assert_gt(ppid, 0, "sys_getppid() must return positive PPID")
  pgrp = sys_getpgrp()
  assert_gt(pgrp, 0, "sys_getpgrp() must return positive PGID")
@end

@fn test_f01_02_mmap_anon()
  @! PROT_READ (1) | PROT_WRITE (2) = 3
  @! MAP_PRIVATE (2) | MAP_ANONYMOUS (32) = 34
  page_size = 4096
  ptr = sys_mmap(0, page_size, 3, 34, 0 - 1, 0)
  assert_gt(ptr, 0, "sys_mmap anonymous 4096-byte page must return valid pointer")

  unmap_res = sys_munmap(ptr, page_size)
  assert_eq(unmap_res, 0, "sys_munmap must return 0 on successful deallocation")
@end

@fn test_f01_03_file_lifecycle()
  pid = sys_getpid()
  test_path = "/tmp/maya_t1_f01_io_" + pid.to_str() + ".tmp"

  @! O_WRONLY (1) | O_CREAT (64) | O_TRUNC (512) = 577, mode 0644 (420)
  fd_w = sys_open(test_path, 577, 420)
  assert_gt(fd_w, 2, "sys_open for write must return valid file descriptor")

  payload = "MAYA_SOVEREIGN_KERNEL_SYSCALL_F01\n"
  p_len = payload.len()
  written = sys_write(fd_w, payload, p_len)
  assert_eq(written, p_len, "sys_write must write all payload bytes")

  close_w = sys_close(fd_w)
  assert_eq(close_w, 0, "sys_close must return 0 on successful close")

  @! O_RDONLY (0)
  fd_r = sys_open(test_path, 0, 0)
  assert_gt(fd_r, 2, "sys_open for read must return valid file descriptor")

  read_buf = maya_alloc(64)
  bytes_read = sys_read(fd_r, read_buf, 64)
  assert_ge(bytes_read, p_len, "sys_read must return read byte count")
  read_str = maya_str_new(read_buf)

  close_r = sys_close(fd_r)
  assert_eq(close_r, 0, "sys_close for read-fd must succeed")

  unlink_res = sys_unlink(test_path)
  assert_eq(unlink_res, 0, "sys_unlink must cleanly delete temporary file")
@end

@fn test_f01_04_pipe_transfer()
  pipefds = [0, 0]
  pipe_res = sys_pipe(pipefds)
  assert_eq(pipe_res, 0, "sys_pipe must return 0 on success")
  assert_ge(pipefds[0], 0, "pipe read-fd must be valid")
  assert_ge(pipefds[1], 0, "pipe write-fd must be valid")

  msg = "SOVEREIGN_PIPE_MESSAGE_12345"
  msg_len = msg.len()
  w_bytes = sys_write(pipefds[1], msg, msg_len)
  assert_ge(w_bytes, 0, "sys_write to pipe must succeed")

  buf = maya_alloc(64)
  r_bytes = sys_read(pipefds[0], buf, 64)
  assert_ge(r_bytes, 0, "sys_read from pipe must succeed")

  sys_close(pipefds[0])
  sys_close(pipefds[1])
@end

@fn test_f01_05_clock_monotonic()
  @! CLOCK_MONOTONIC = 1, struct timespec = 16 bytes
  ts_buf = sys_mmap(0, 16, 3, 34, 0 - 1, 0)
  assert_gt(ts_buf, 0, "mmap for timespec buffer must succeed")

  clk_res = sys_clock_gettime(1, ts_buf)
  assert_eq(clk_res, 0, "sys_clock_gettime(CLOCK_MONOTONIC) must return 0")
  sys_munmap(ts_buf, 16)
@end

@fn test_f01_06_getrandom()
  rand_buf = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  assert_gt(rand_buf, 0, "mmap for random buffer must succeed")

  res = sys_getrandom(rand_buf, 32, 0)
  assert_eq(res, 32, "sys_getrandom must return requested 32 bytes of entropy")
  sys_munmap(rand_buf, 32)
@end

@fn run_all_f01_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F01: Raw Syscall Layer Suite")
  println("=================================================================")

  total = 0
  passed = 0

  println("  [RUN] test_f01_01_pid_ppid")
  test_f01_01_pid_ppid()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f01_01_pid_ppid")

  println("  [RUN] test_f01_02_mmap_anon")
  test_f01_02_mmap_anon()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f01_02_mmap_anon")

  println("  [RUN] test_f01_03_file_lifecycle")
  test_f01_03_file_lifecycle()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f01_03_file_lifecycle")

  println("  [RUN] test_f01_04_pipe_transfer")
  test_f01_04_pipe_transfer()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f01_04_pipe_transfer")

  println("  [RUN] test_f01_05_clock_monotonic")
  test_f01_05_clock_monotonic()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f01_05_clock_monotonic")

  println("  [RUN] test_f01_06_getrandom")
  test_f01_06_getrandom()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f01_06_getrandom")

  println("-----------------------------------------------------------------")
  println("F01 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  return 0
@end

@fn main()
  return run_all_f01_tests()
@end
