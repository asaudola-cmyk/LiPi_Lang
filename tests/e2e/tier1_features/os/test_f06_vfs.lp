@! ============================================================================
@! MAYA E2E TIER 1 — FEATURE F06: VIRTUAL FILESYSTEM (VFS)
@! File: tests/e2e/tier1_features/os/test_f06_vfs.maya
@! Description: Validates RamFS, /dev character devices, inode hierarchy, and I/O
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/fs"
import "universe/tools/maya_test"

@! Pure Maya Inode RamFS Structs
@struct RamInode
  ino_id: 0
  name: ""
  is_dir: 0
  content: ""
  size: 0
  children: []
@end

@struct RamFilesystem
  inodes: []
  next_ino: 1
@end

@fn ramfs_new()
  root_inode = {
    ino_id: 1,
    name: "/",
    is_dir: 1,
    content: "",
    size: 0,
    children: []
  }
  return {
    inodes: [root_inode],
    next_ino: 2
  }
@end

@fn ramfs_create_file(ramfs, filename, content)
  new_ino = {
    ino_id: ramfs.next_ino,
    name: filename,
    is_dir: 0,
    content: content,
    size: content.len(),
    children: []
  }
  ramfs.next_ino = ramfs.next_ino + 1
  ramfs.inodes = ramfs.inodes.push(new_ino)
  return new_ino.ino_id
@end

@fn ramfs_read_file(ramfs, filename)
  i = 0
  n = ramfs.inodes.len()
  @while i < n
    ino = ramfs.inodes[i]
    @if ino.name == filename && ino.is_dir == 0
      return ino.content
    @end
    i = i + 1
  @end
  return ""
@end

@fn test_f06_01_ramfs_write_read()
  test_file = "/tmp/maya_t1_f06_ramfs_" + sys_getpid().to_str() + ".txt"
  payload = "SOVEREIGN_RAMFS_VFS_PAYLOAD_DATA\nLine 2: 1234567890\n"
  
  write_res = fs_write_file(test_file, payload)
  assert_eq(write_res, 1, "fs_write_file must succeed")

  read_back = fs_read_file(test_file)
  assert_str_eq(read_back, payload, "fs_read_file content must match payload exactly")

  st = fs_stat(test_file)
  assert_eq(st.is_file, 1, "fs_stat must identify regular file")
  assert_eq(st.size, payload.len(), "fs_stat size must equal payload byte length")

  fs_remove(test_file)
@end

@fn test_f06_02_dev_zero()
  fd = sys_open("/dev/zero", 0, 0) @! O_RDONLY
  assert_gt(fd, 0, "Opening /dev/zero must succeed")

  buf = maya_alloc(64)
  n_read = sys_read(fd, buf, 64)
  assert_eq(n_read, 64, "Reading from /dev/zero must return requested byte count")
  sys_close(fd)
@end

@fn test_f06_03_dev_null()
  fd = sys_open("/dev/null", 1, 0) @! O_WRONLY
  assert_gt(fd, 0, "Opening /dev/null must succeed")

  payload = "MAYA_DEV_NULL_DISCARD_STREAM_DATA_TEST"
  p_len = payload.len()
  written = sys_write(fd, payload, p_len)
  assert_eq(written, p_len, "Writing to /dev/null must return written length")
  sys_close(fd)
@end

@fn test_f06_04_dev_random()
  fd = sys_open("/dev/urandom", 0, 0) @! O_RDONLY
  assert_gt(fd, 0, "Opening /dev/urandom must succeed")

  buf = maya_alloc(32)
  n_read = sys_read(fd, buf, 32)
  assert_eq(n_read, 32, "Reading from /dev/urandom must return 32 bytes")
  sys_close(fd)
@end

@fn test_f06_05_mkdir_hierarchy()
  base_dir = "/tmp/maya_vfs_hier_" + sys_getpid().to_str()
  nested_path = base_dir + "/sub1/sub2/sub3"
  
  res = fs_mkdir_p(nested_path, 511)
  assert_eq(res, 0, "fs_mkdir_p must create nested directory hierarchy")
  assert_eq(fs_exists(nested_path), 1, "Nested path must exist")

  st = fs_stat(nested_path)
  assert_eq(st.is_dir, 1, "fs_stat must confirm nested path is a directory")

  @! Clean up
  fs_rmdir(nested_path)
@end

@fn test_f06_06_in_memory_ramfs()
  rfs = ramfs_new()
  ino1 = ramfs_create_file(rfs, "kernel.config", "SOVEREIGN=1\nARCH=x86_64\n")
  ino2 = ramfs_create_file(rfs, "boot.ini", "TIMEOUT=3\n")
  assert_eq(rfs.inodes.len(), 3, "RamFS contains root + 2 files")

  c1 = ramfs_read_file(rfs, "kernel.config")
  assert_str_eq(c1, "SOVEREIGN=1\nARCH=x86_64\n", "RamFS read kernel.config match")

  c2 = ramfs_read_file(rfs, "boot.ini")
  assert_str_eq(c2, "TIMEOUT=3\n", "RamFS read boot.ini match")
@end

@fn run_all_f06_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F06: Virtual Filesystem (VFS) Suite")
  println("=================================================================")

  total = 0
  passed = 0

  println("  [RUN] test_f06_01_ramfs_write_read")
  test_f06_01_ramfs_write_read()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f06_01_ramfs_write_read")

  println("  [RUN] test_f06_02_dev_zero")
  test_f06_02_dev_zero()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f06_02_dev_zero")

  println("  [RUN] test_f06_03_dev_null")
  test_f06_03_dev_null()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f06_03_dev_null")

  println("  [RUN] test_f06_04_dev_random")
  test_f06_04_dev_random()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f06_04_dev_random")

  println("  [RUN] test_f06_05_mkdir_hierarchy")
  test_f06_05_mkdir_hierarchy()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f06_05_mkdir_hierarchy")

  println("  [RUN] test_f06_06_in_memory_ramfs")
  test_f06_06_in_memory_ramfs()
  passed = passed + 1
  total = total + 1
  println("  [PASS] test_f06_06_in_memory_ramfs")

  println("-----------------------------------------------------------------")
  println("F06 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  return 0
@end

@fn main()
  return run_all_f06_tests()
@end
