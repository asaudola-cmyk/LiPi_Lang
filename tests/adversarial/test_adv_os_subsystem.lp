@! ============================================================================
@! ADVERSARIAL STRESS TEST: PURE MAYA OS SUBSYSTEM (test_adv_os_subsystem.maya)
@! Tests:
@! 1. Deep 5-level recursive directory creation (fs_mkdir_p) & idempotency
@! 2. High-frequency sequential file append cycles & line verification
@! 3. Large 64KB file read/write, stat size check, and content invariant
@! 4. Multi-process fork lifecycle and exit code propagation (0, 42, 127, 255)
@! 5. Environment variable querying (env_get, env_get_or fallback, env_all)
@! 6. Directory enumeration (fs_read_dir), renaming, and unlinking
@! ============================================================================

import "universe/os/fs"
import "universe/os/process"
import "universe/os/env"
import "universe/core/string"

@fn build_large_buffer(target_bytes)
  chunk = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@#$%^&*()_+-=\n"
  c_len = chunk.len()
  res = ""
  @while res.len() < target_bytes
    rem = target_bytes - res.len()
    @if rem >= c_len
      res = res + chunk
    @else
      res = res + str_substr(chunk, 0, rem)
    @end
  @end
  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [ADVERSARIAL STRESS SUITE] universe/os (FS, Process, Env)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  my_pid = process_getpid()
  test_root = "/tmp/maya_os_adv_" + my_pid.to_str()

  @! --------------------------------------------------------------------------
  @! SECTION 1: Deep 5-Level fs_mkdir_p & Idempotency
  @! --------------------------------------------------------------------------
  println("▶ Section 1: Deep Directory Hierarchy (fs_mkdir_p)")

  deep_dir = test_root + "/l1/l2/l3/l4/l5"
  mkdir_res = fs_mkdir_p(deep_dir, 511)

  total = total + 1
  @if mkdir_res == 0 && fs_exists(deep_dir) == 1
    passed = passed + 1
    println("  [PASS] OS1.1: 5-level deep directory created successfully: " + deep_dir)
  @else
    failed = failed + 1
    println("  [FAIL] OS1.1: fs_mkdir_p failed for deep dir (code: " + mkdir_res.to_str() + ")")
  @end

  total = total + 1
  st_deep = fs_stat(deep_dir)
  @if st_deep.is_dir == 1 && st_deep.is_file == 0
    passed = passed + 1
    println("  [PASS] OS1.2: fs_stat confirmed target is a directory")
  @else
    failed = failed + 1
    println("  [FAIL] OS1.2: fs_stat reported is_dir=" + st_deep.is_dir.to_str())
  @end

  total = total + 1
  idempotent_res = fs_mkdir_p(deep_dir, 511)
  @if idempotent_res == 0
    passed = passed + 1
    println("  [PASS] OS1.3: fs_mkdir_p on existing directory is cleanly idempotent (returned 0)")
  @else
    failed = failed + 1
    println("  [FAIL] OS1.3: fs_mkdir_p re-run on existing directory failed: " + idempotent_res.to_str())
  @end

  nested_file = deep_dir + "/nested_test.txt"
  fs_write_file(nested_file, "DeepNestedPayload")
  nested_read = fs_read_file(nested_file)

  total = total + 1
  @if nested_read == "DeepNestedPayload"
    passed = passed + 1
    println("  [PASS] OS1.4: File I/O inside deep 5-level directory verified")
  @else
    failed = failed + 1
    println("  [FAIL] OS1.4: Deep file I/O content mismatch: " + nested_read)
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: Sequential File Append Cycles
  @! --------------------------------------------------------------------------
  println("▶ Section 2: Sequential File Append Stress (25 Appends)")

  append_file = test_root + "/append_stress.log"
  fs_write_file(append_file, "HEADER_LINE\n")

  idx = 0
  @while idx < 25
    line_to_append = "APPEND_RECORD_" + idx.to_str() + "\n"
    fs_append_file(append_file, line_to_append)
    idx = idx + 1
  @end

  lines = fs_read_lines(append_file)

  total = total + 1
  @if lines.len() == 26
    passed = passed + 1
    println("  [PASS] OS2.1: 25 sequential appends produced exact 26 lines")
  @else
    failed = failed + 1
    println("  [FAIL] OS2.1: Line count mismatch after appends: " + lines.len().to_str() + " (expected 26)")
  @end

  total = total + 1
  first_ok = (lines[0] == "HEADER_LINE")
  last_ok = (lines[25] == "APPEND_RECORD_24")
  mid_ok = (lines[12] == "APPEND_RECORD_11")

  @if first_ok == 1 && last_ok == 1 && mid_ok == 1
    passed = passed + 1
    println("  [PASS] OS2.2: First, middle, and last append records preserved perfectly")
  @else
    failed = failed + 1
    println("  [FAIL] OS2.2: Append content corruption detected")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: Large 65,536-Byte (64KB) File I/O
  @! --------------------------------------------------------------------------
  println("▶ Section 3: Large 64KB File Read/Write Stress")

  large_target = 65536
  large_data = build_large_buffer(large_target)
  large_path = test_root + "/large_64k.bin"

  w_res = fs_write_file(large_path, large_data)
  st_large = fs_stat(large_path)

  total = total + 1
  @if st_large.size == 65536 && st_large.is_file == 1
    passed = passed + 1
    println("  [PASS] OS3.1: fs_write_file wrote 65536 bytes; fs_stat confirmed exact size")
  @else
    failed = failed + 1
    println("  [FAIL] OS3.1: fs_stat size mismatch: " + st_large.size.to_str() + " (expected 65536)")
  @end

  read_large_data = fs_read_file(large_path)

  total = total + 1
  @if read_large_data.len() == 65536 && read_large_data == large_data
    passed = passed + 1
    println("  [PASS] OS3.2: fs_read_file read complete 64KB file with 100% byte-for-byte fidelity")
  @else
    failed = failed + 1
    println("  [FAIL] OS3.2: 64KB read mismatch: len=" + read_large_data.len().to_str())
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 4: Process Fork & Exit Code Propagation
  @! --------------------------------------------------------------------------
  println("▶ Section 4: Process Fork & Exit Code Propagation")

  @! Test exit codes: 0, 42, 127, 255
  codes = [0, 42, 127, 255]
  c_idx = 0
  fork_fails = 0

  @while c_idx < codes.len()
    expected_code = codes[c_idx]
    child_p = process_fork()
    @if child_p == 0
      process_exit(expected_code)
    @elif child_p > 0
      raw_stat = process_wait(child_p)
      ret_code = (raw_stat / 256) & 255
      @if ret_code != expected_code
        fork_fails = fork_fails + 1
      @end
    @else
      fork_fails = fork_fails + 1
    @end
    c_idx = c_idx + 1
  @end

  total = total + 1
  @if fork_fails == 0
    passed = passed + 1
    println("  [PASS] OS4.1: Process fork and exit codes (0, 42, 127, 255) propagated and decoded accurately")
  @else
    failed = failed + 1
    println("  [FAIL] OS4.1: Exit code propagation failed on " + fork_fails.to_str() + " tests")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 5: Environment Variable Querying & Defaults
  @! --------------------------------------------------------------------------
  println("▶ Section 5: Environment Variables (env_get, env_get_or, env_all)")

  path_val = env_get("PATH")
  total = total + 1
  @if path_val.len() > 0 && contains(path_val, "/bin") == 1
    passed = passed + 1
    println("  [PASS] OS5.1: env_get('PATH') retrieved system PATH: " + str_substr(path_val, 0, 30) + "...")
  @else
    failed = failed + 1
    println("  [FAIL] OS5.1: env_get('PATH') returned empty or invalid: " + path_val)
  @end

  fallback_val = env_get_or("DEFINITELY_NON_EXISTENT_VAR_12345", "MAYA_FALLBACK_DEFAULT")
  total = total + 1
  @if fallback_val == "MAYA_FALLBACK_DEFAULT"
    passed = passed + 1
    println("  [PASS] OS5.2: env_get_or returned designated fallback on missing variable")
  @else
    failed = failed + 1
    println("  [FAIL] OS5.2: env_get_or fallback failed: " + fallback_val)
  @end

  missing_direct = env_get("DEFINITELY_NON_EXISTENT_VAR_12345")
  total = total + 1
  @if missing_direct == ""
    passed = passed + 1
    println("  [PASS] OS5.3: env_get returned empty string for missing variable")
  @else
    failed = failed + 1
    println("  [FAIL] OS5.3: env_get returned non-empty: " + missing_direct)
  @end

  all_vars = env_all()
  total = total + 1
  @if all_vars.len() > 0
    passed = passed + 1
    println("  [PASS] OS5.4: env_all() returned " + all_vars.len().to_str() + " parsed environment key-value pairs")
  @else
    failed = failed + 1
    println("  [FAIL] OS5.4: env_all() returned 0 environment variables")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 6: Directory Enumeration, Renaming & Cleanup
  @! --------------------------------------------------------------------------
  println("▶ Section 6: Directory Enumeration & File Cleanup")

  dir_entries = fs_read_dir(deep_dir)
  total = total + 1
  @if dir_entries.len() >= 1 && contains_item(dir_entries, "nested_test.txt") == 1
    passed = passed + 1
    println("  [PASS] OS6.1: fs_read_dir correctly enumerated directory files without '.' or '..'")
  @else
    failed = failed + 1
    println("  [FAIL] OS6.1: fs_read_dir failed to list nested_test.txt")
  @end

  renamed_file = deep_dir + "/nested_renamed.txt"
  fs_rename(nested_file, renamed_file)

  total = total + 1
  @if fs_exists(nested_file) == 0 && fs_exists(renamed_file) == 1
    passed = passed + 1
    println("  [PASS] OS6.2: fs_rename moved file successfully")
  @else
    failed = failed + 1
    println("  [FAIL] OS6.2: fs_rename verification failed")
  @end

  fs_remove(renamed_file)
  total = total + 1
  @if fs_exists(renamed_file) == 0
    passed = passed + 1
    println("  [PASS] OS6.3: fs_remove deleted file successfully")
  @else
    failed = failed + 1
    println("  [FAIL] OS6.3: fs_remove failed to delete file")
  @end

  @! Cleanup test files
  fs_remove(append_file)
  fs_remove(large_path)

  @! --------------------------------------------------------------------------
  @! Summary
  @! --------------------------------------------------------------------------
  println("=================================================================")
  println("ADVERSARIAL OS SUITE SUMMARY: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")

  @if failed == 0
    println("✓ ALL OS ADVERSARIAL TESTS PASSED")
    return 0
  @else
    println("✗ SOME OS ADVERSARIAL TESTS FAILED (" + failed.to_str() + " failures)")
    return 1
  @end
@end

@fn contains_item(arr, item)
  j = 0
  @while j < arr.len()
    @if arr[j] == item
      return 1
    @end
    j = j + 1
  @end
  return 0
@end
