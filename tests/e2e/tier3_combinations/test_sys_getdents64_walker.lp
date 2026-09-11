@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: DIRECTORY SYSCALLS + RECURSIVE FILE WALKER
@! File: tests/e2e/tier3_combinations/test_sys_getdents64_walker.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/fs"
import "universe/core/string"

@struct WalkResult
  total_files: 0
  total_dirs: 0
  maya_files: 0
  file_paths: 0
@end

@fn walk_directory_recursive(dir_path, res)
  entries = fs_read_dir(dir_path)
  i = 0
  len = entries.len()

  @while i < len
    name = entries[i]
    full_path = dir_path + "/" + name
    st = fs_stat(full_path)

    @if st.is_dir == 1
      res.total_dirs = res.total_dirs + 1
      res = walk_directory_recursive(full_path, res)
    @elif st.is_file == 1
      res.total_files = res.total_files + 1
      res.file_paths.push(full_path)
      @if string_ends_with(name, ".maya") == 1
        res.maya_files = res.maya_files + 1
      @end
    @end
    i = i + 1
  @end

  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 14: Directory Syscalls & File Walker")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  pid = sys_getpid()
  test_dir = "/tmp/maya_walk_test_" + int_to_str(pid)

  @! T3.14.1: Direct Syscall Directory Tree Creation (sys_mkdir & sys_open)
  total = total + 1
  m1 = sys_mkdir(test_dir, 493)
  m2 = sys_mkdir(test_dir + "/subdir_a", 493)
  m3 = sys_mkdir(test_dir + "/subdir_b", 493)
  m4 = sys_mkdir(test_dir + "/subdir_a/nested", 493)

  @! Create files across tree
  fd1 = sys_open(test_dir + "/root_app.maya", 578, 420)
  sys_write(fd1, "root_app", 8)
  sys_close(fd1)

  fd2 = sys_open(test_dir + "/config.json", 578, 420)
  sys_write(fd2, "{}", 2)
  sys_close(fd2)

  fd3 = sys_open(test_dir + "/subdir_a/mod_a.maya", 578, 420)
  sys_write(fd3, "mod_a", 5)
  sys_close(fd3)

  fd4 = sys_open(test_dir + "/subdir_a/nested/deep.maya", 578, 420)
  sys_write(fd4, "deep", 4)
  sys_close(fd4)

  fd5 = sys_open(test_dir + "/subdir_b/readme.txt", 578, 420)
  sys_write(fd5, "readme", 6)
  sys_close(fd5)

  @if m1 == 0 && m2 == 0 && m3 == 0 && m4 == 0 && fd1 >= 3 && fd4 >= 3
    passed = passed + 1
    println("  [PASS] T3.14.1: Nested directory hierarchy and 5 files initialized via syscalls")
  @else
    failed = failed + 1
    println("  [FAIL] T3.14.1: Syscall directory tree setup failed")
  @end

  @! T3.14.2: Direct sys_getdents64 Directory Listing
  total = total + 1
  root_entries = fs_read_dir(test_dir)
  @! root contains subdir_a, subdir_b, root_app.maya, config.json -> 4 entries
  @if root_entries.len() == 4
    passed = passed + 1
    println("  [PASS] T3.14.2: sys_getdents64 returned exact 4 root directory items")
  @else
    failed = failed + 1
    println("  [FAIL] T3.14.2: Root directory item count expected 4, got " + int_to_str(root_entries.len()))
  @end

  @! T3.14.3: Recursive Directory Walker Traversal
  total = total + 1
  walk_res = {
    total_files: 0,
    total_dirs: 0,
    maya_files: 0,
    file_paths: []
  }
  walk_res = walk_directory_recursive(test_dir, walk_res)

  @! Total directories visited: subdir_a, subdir_b, nested = 3
  @! Total files: root_app.maya, config.json, mod_a.maya, deep.maya, readme.txt = 5
  @! Maya files: root_app.maya, mod_a.maya, deep.maya = 3
  @if walk_res.total_files == 5 && walk_res.total_dirs == 3 && walk_res.maya_files == 3
    passed = passed + 1
    println("  [PASS] T3.14.3: Recursive walker traversed 3 subdirectories, 5 total files, 3 Maya files")
  @else
    failed = failed + 1
    println("  [FAIL] T3.14.3: Recursive walk failed: files=" + int_to_str(walk_res.total_files) + ", dirs=" + int_to_str(walk_res.total_dirs) + ", maya=" + int_to_str(walk_res.maya_files))
  @end

  @! T3.14.4: File Path Suffix Filter Matching
  total = total + 1
  json_count = 0
  p_idx = 0
  @while p_idx < walk_res.file_paths.len()
    @if string_ends_with(walk_res.file_paths[p_idx], ".json") == 1
      json_count = json_count + 1
    @end
    p_idx = p_idx + 1
  @end

  @if json_count == 1
    passed = passed + 1
    println("  [PASS] T3.14.4: Extension filtering on traversed paths identified exactly 1 '.json' file")
  @else
    failed = failed + 1
    println("  [FAIL] T3.14.4: JSON filter failed")
  @end

  @! T3.14.5: Cleanup test filesystem entries
  total = total + 1
  sys_unlink(test_dir + "/subdir_a/nested/deep.maya")
  sys_rmdir(test_dir + "/subdir_a/nested")
  sys_unlink(test_dir + "/subdir_a/mod_a.maya")
  sys_rmdir(test_dir + "/subdir_a")
  sys_unlink(test_dir + "/subdir_b/readme.txt")
  sys_rmdir(test_dir + "/subdir_b")
  sys_unlink(test_dir + "/root_app.maya")
  sys_unlink(test_dir + "/config.json")
  unl_res = sys_rmdir(test_dir)

  @if unl_res == 0
    passed = passed + 1
    println("  [PASS] T3.14.5: Recursive test directory and files unlinked and removed via sys_rmdir")
  @else
    failed = failed + 1
    println("  [FAIL] T3.14.5: Cleanup failed")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 14 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 14 (Directory Syscalls & File Walker) PASSED")
    return 0
  @else
    println("✗ Combination 14 (Directory Syscalls & File Walker) FAILED")
    return 1
  @end
@end
