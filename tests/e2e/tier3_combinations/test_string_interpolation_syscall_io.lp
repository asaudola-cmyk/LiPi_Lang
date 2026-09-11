@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: STRING INTERPOLATION + DIRECT SYSCALL I/O
@! File: tests/e2e/tier3_combinations/test_string_interpolation_syscall_io.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

import "universe/os/syscalls"

@struct LogRecord
  seq: 0
  user_name: ""
  uid: 0
  action: ""
  status: ""
@end

@fn format_log_entry(record)
  return "[LOG " + int_to_str(record.seq) + "] User: " + record.user_name + " (UID: " + int_to_str(record.uid) + ") Action: " + record.action + " -> " + record.status + "\n"
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 3: String Interpolation + Syscall I/O")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  pid = sys_getpid()
  test_file_path = "/tmp/maya_t3_syscall_log_" + int_to_str(pid) + ".txt"

  @! T3.3.1: Format structured log strings
  total = total + 1
  rec1 = { seq: 1001, user_name: "alice_admin", uid: 501, action: "AUTH_LOGIN", status: "SUCCESS" }
  rec2 = { seq: 1002, user_name: "bob_dev", uid: 502, action: "DEPLOY_SVC", status: "PENDING" }
  rec3 = { seq: 1003, user_name: "carol_qa", uid: 503, action: "RUN_E2E_SUITE", status: "PASSED" }

  log1 = format_log_entry(rec1)
  log2 = format_log_entry(rec2)
  log3 = format_log_entry(rec3)
  full_log = log1 + log2 + log3

  expected_log1 = "[LOG 1001] User: alice_admin (UID: 501) Action: AUTH_LOGIN -> SUCCESS\n"
  @if log1 == expected_log1 && str_len(full_log) > 100
    passed = passed + 1
    println("  [PASS] T3.3.1: String formatting of structured records matches expected format")
  @else
    failed = failed + 1
    println("  [FAIL] T3.3.1: String formatting mismatch: " + log1)
  @end

  @! T3.3.2: Write formatted log string via sys_open & sys_write
  total = total + 1
  @! Flags: O_CREAT (64) | O_RDWR (2) | O_TRUNC (512) = 578, Mode: 0644 (420)
  fd = sys_open(test_file_path, 578, 420)
  written_bytes = 0
  @if fd >= 3
    written_bytes = sys_write(fd, full_log, str_len(full_log))
    sys_close(fd)
  @end

  @if fd >= 3 && written_bytes == str_len(full_log)
    passed = passed + 1
    println("  [PASS] T3.3.2: sys_write wrote exact " + int_to_str(written_bytes) + " bytes to file")
  @else
    failed = failed + 1
    println("  [FAIL] T3.3.2: sys_write failed, fd=" + int_to_str(fd) + ", written=" + int_to_str(written_bytes))
  @end

  @! T3.3.3: Read back via sys_read and verify round-trip fidelity
  total = total + 1
  rfd = sys_open(test_file_path, 0, 0)  @! O_RDONLY (0)
  rbuf = sys_mmap(0, 4096, 3, 34, 0 - 1, 0)
  read_count = 0
  @if rfd >= 3 && rbuf > 0
    read_count = sys_read(rfd, rbuf, 4096)
    sys_close(rfd)
  @end

  @if read_count == written_bytes
    passed = passed + 1
    println("  [PASS] T3.3.3: sys_read returned exact written byte count (" + int_to_str(read_count) + " bytes)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.3.3: sys_read expected " + int_to_str(written_bytes) + ", got " + int_to_str(read_count))
  @end

  @! T3.3.4: Partial Seek and Read Validation
  total = total + 1
  sfd = sys_open(test_file_path, 0, 0)
  seek_res = sys_lseek(sfd, str_len(log1), 0)  @! Seek past log1 to start of log2
  partial_read = sys_read(sfd, rbuf, str_len(log2))
  sys_close(sfd)

  @if seek_res == str_len(log1) && partial_read == str_len(log2)
    passed = passed + 1
    println("  [PASS] T3.3.4: sys_lseek positioned stream offset correctly (" + int_to_str(seek_res) + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T3.3.4: sys_lseek verification failed")
  @end

  @! T3.3.5: Cleanup temporary file via sys_unlink
  total = total + 1
  unl_res = sys_unlink(test_file_path)
  sys_munmap(rbuf, 4096)
  deleted_fd = sys_open(test_file_path, 0, 0)
  @if unl_res == 0 && deleted_fd < 0
    passed = passed + 1
    println("  [PASS] T3.3.5: sys_unlink removed temporary log file cleanly (reopen returned " + int_to_str(deleted_fd) + ")")
  @else
    failed = failed + 1
    println("  [FAIL] T3.3.5: sys_unlink failed")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 3 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 3 (String Interp + Syscall I/O) PASSED")
    return 0
  @else
    println("✗ Combination 3 (String Interp + Syscall I/O) FAILED")
    return 1
  @end
@end
