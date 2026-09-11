@! ============================================================================
@! MAYA VFS & IPC UNIT TEST SUITE (tests/os/test_vfs_ipc.maya)
@! ============================================================================

import "universe/os/vfs"
import "universe/os/ipc"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("📁 MAYA VFS & IPC SUBSYSTEMS TEST SUITE 📁")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: VFS Directory Operations & Traversal
  println("▶ Section 1: VFS Directories & Path Traversal...")
  total_tests = total_tests + 1
  
  vfs = vfs_init()
  mkdir_res = vfs_mkdir(vfs, "/home/user", 493)
  ok1 = assert_eq_int(mkdir_res, 0, "Created directory /home/user")
  
  st = vfs_stat(vfs, "/home/user")
  ok2 = assert_eq_int(st.is_dir, 1, "Verified /home/user is directory")
  
  dir_entries = vfs_read_dir(vfs, "/home")
  ok3 = assert_true(dir_entries.len() >= 1, "Directory /home contains entries")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] VFS directory creation & traversal verified")
  @end

  @! SECTION 2: IPC FIFO Ring Buffer Wrapping
  println("▶ Section 2: IPC FIFO Ring Buffer Wrap-Around...")
  total_tests = total_tests + 1
  
  fifo = ipc_fifo_create("wrap_pipe", 4)
  ipc_fifo_write(fifo, [1, 2, 3])
  r1 = ipc_fifo_read(fifo, 2)
  ok1 = assert_eq_int(r1.len(), 2, "Read 2 bytes")
  
  @! Write 2 more bytes (wrapping around ring buffer)
  w2 = ipc_fifo_write(fifo, [4, 5])
  ok2 = assert_eq_int(w2, 2, "Wrote 2 bytes with wrap-around")
  
  r2 = ipc_fifo_read(fifo, 3)
  ok3 = assert_eq_int(r2.len(), 3, "Read 3 remaining bytes")
  ok4 = assert_eq_int(r2[0], 3, "Preserved FIFO sequence 3")
  ok5 = assert_eq_int(r2[1], 4, "Preserved FIFO sequence 4")
  ok6 = assert_eq_int(r2[2], 5, "Preserved FIFO sequence 5")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] IPC FIFO ring buffer wrap-around verified")
  @end

  println("=================================================================")
  println("📊 VFS & IPC RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    return 0
  @else
    return 1
  @end
@end
