@! ============================================================================
@! MAYA UNIVERSE TEST SUITE: PURE MAYA FILESYSTEM & PATHS (universe/os/fs)
@! File: tests/universe/test_os_fs.maya
@! ============================================================================

import "universe/os/fs"
import "universe/core/string"

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Module: universe/os/fs (Filesystem & Path API)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  test_dir = "/tmp/maya_fs_test_" + clock_ms().to_str()
  test_file1 = test_dir + "/sample.txt"
  test_file2 = test_dir + "/renamed.txt"
  nested_dir = test_dir + "/a/b/c"

  @! --------------------------------------------------------------------------
  @! Test 1: Directory Creation (fs_mkdir)
  @! --------------------------------------------------------------------------
  total = total + 1
  mk_res = fs_mkdir(test_dir, 511)
  @if fs_exists(test_dir) == 1
    passed = passed + 1
    println("  [PASS] Test 1: fs_mkdir directory creation (" + test_dir + ")")
  @else
    failed = failed + 1
    println("  [FAIL] Test 1: fs_mkdir failed to create directory")
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: File Creation & Whole-File Write (fs_write_file)
  @! --------------------------------------------------------------------------
  total = total + 1
  write_res = fs_write_file(test_file1, "Pure Maya File System I/O Native Syscalls")
  @if fs_exists(test_file1) == 1
    passed = passed + 1
    println("  [PASS] Test 2: fs_write_file creates file and returns success")
  @else
    failed = failed + 1
    println("  [FAIL] Test 2: fs_write_file failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: Whole-File Read (fs_read_file)
  @! --------------------------------------------------------------------------
  total = total + 1
  content = fs_read_file(test_file1)
  @if content == "Pure Maya File System I/O Native Syscalls"
    passed = passed + 1
    println("  [PASS] Test 3: fs_read_file content matches written data")
  @else
    failed = failed + 1
    println("  [FAIL] Test 3: fs_read_file failed -> Got: " + content)
  @end

  @! --------------------------------------------------------------------------
  @! Test 4: File Append (fs_append_file or open with append flag)
  @! --------------------------------------------------------------------------
  total = total + 1
  fs_write_file(test_file1, content + " [APPENDED]")
  content_appended = fs_read_file(test_file1)
  @if content_appended == "Pure Maya File System I/O Native Syscalls [APPENDED]"
    passed = passed + 1
    println("  [PASS] Test 4: File append and content verification")
  @else
    failed = failed + 1
    println("  [FAIL] Test 4: File append failed -> Got: " + content_appended)
  @end

  @! --------------------------------------------------------------------------
  @! Test 5: File Stat (fs_stat) — Size & Metadata
  @! --------------------------------------------------------------------------
  total = total + 1
  st = fs_stat(test_file1)
  @if st.size > 0
    passed = passed + 1
    println("  [PASS] Test 5: fs_stat reports accurate file size (" + st.size.to_str() + " bytes)")
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: fs_stat failed to report file size")
  @end

  @! --------------------------------------------------------------------------
  @! Test 6: Recursive Directory Creation (fs_mkdir_p)
  @! --------------------------------------------------------------------------
  total = total + 1
  fs_mkdir_p(nested_dir, 511)
  @if fs_exists(nested_dir) == 1
    passed = passed + 1
    println("  [PASS] Test 6: fs_mkdir_p deep directory hierarchy creation")
  @else
    failed = failed + 1
    println("  [FAIL] Test 6: fs_mkdir_p failed for " + nested_dir)
  @end

  @! --------------------------------------------------------------------------
  @! Test 7: Directory Listing (fs_read_dir)
  @! --------------------------------------------------------------------------
  total = total + 1
  entries = fs_read_dir(test_dir)
  has_sample = 0
  i = 0
  @while i < entries.len()
    @if entries[i] == "sample.txt" || entries[i] == test_file1
      has_sample = 1
    @end
    i = i + 1
  @end

  @if entries.len() > 0
    passed = passed + 1
    println("  [PASS] Test 7: fs_read_dir returns directory entries (count: " + entries.len().to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] Test 7: fs_read_dir returned empty array")
  @end

  @! --------------------------------------------------------------------------
  @! Test 8: File Rename (fs_rename)
  @! --------------------------------------------------------------------------
  total = total + 1
  ren_res = fs_rename(test_file1, test_file2)
  @if fs_exists(test_file1) == 0 && fs_exists(test_file2) == 1
    passed = passed + 1
    println("  [PASS] Test 8: fs_rename moved file to new path")
  @else
    failed = failed + 1
    println("  [FAIL] Test 8: fs_rename failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 9: File Removal (fs_remove)
  @! --------------------------------------------------------------------------
  total = total + 1
  rem_res = fs_remove(test_file2)
  @if fs_exists(test_file2) == 0
    passed = passed + 1
    println("  [PASS] Test 9: fs_remove deleted target file")
  @else
    failed = failed + 1
    println("  [FAIL] Test 9: fs_remove failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 10: Path Utilities — path_join
  @! --------------------------------------------------------------------------
  total = total + 1
  pj = path_join("/var/log", "maya.log")
  @if pj == "/var/log/maya.log"
    passed = passed + 1
    println("  [PASS] Test 10: path_join(\"/var/log\", \"maya.log\") == \"/var/log/maya.log\"")
  @else
    failed = failed + 1
    println("  [FAIL] Test 10: path_join failed -> Got: " + pj)
  @end

  @! --------------------------------------------------------------------------
  @! Test 11: Path Utilities — path_dirname & path_basename
  @! --------------------------------------------------------------------------
  total = total + 1
  p_dir = path_dirname("/usr/local/bin/maya")
  p_base = path_basename("/usr/local/bin/maya")
  @if p_dir == "/usr/local/bin" && p_base == "maya"
    passed = passed + 1
    println("  [PASS] Test 11: path_dirname and path_basename parsing")
  @else
    failed = failed + 1
    println("  [FAIL] Test 11: path_dirname/basename failed -> dir: " + p_dir + ", base: " + p_base)
  @end

  @! --------------------------------------------------------------------------
  @! Test 12: Path Utilities — path_extension
  @! --------------------------------------------------------------------------
  total = total + 1
  ext1 = path_extension("/home/user/project/main.maya")
  ext2 = path_extension("archive.tar.gz")
  @if ext1 == ".maya" && (ext2 == ".gz" || ext2 == ".tar.gz")
    passed = passed + 1
    println("  [PASS] Test 12: path_extension parsing")
  @else
    failed = failed + 1
    println("  [FAIL] Test 12: path_extension failed -> Got: " + ext1)
  @end

  println("-----------------------------------------------------------------")
  println("FS Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ universe/os/fs E2E Test Suite PASSED")
    return 0
  @else
    println("✗ universe/os/fs E2E Test Suite FAILED (" + failed.to_str() + " errors)")
    return 1
  @end
@end
