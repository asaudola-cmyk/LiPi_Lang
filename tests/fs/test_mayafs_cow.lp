@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — MAYAFS COPY-ON-WRITE TEST SUITE
@! File: tests/fs/test_mayafs_cow.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/fs/mayafs"

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
  println("💾 MAYAFS (NATIVE COPY-ON-WRITE FILE SYSTEM) TEST SUITE 💾")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: MayaFS Formatting & Superblock Setup
  println("▶ Section 1: MayaFS Formatting (100,000 4KB Blocks)...")
  total_tests = total_tests + 1
  fs = mayafs_format("MayaFS_DataPool", 100000)
  ok1 = assert_eq_int(fs.total_blocks_count, 100000, "MayaFS formatted with 100000 blocks (~400MB)")
  ok2 = assert_eq_int(fs.free_block_pointer, 1, "Free block allocator starts at block 1")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] MayaFS formatting & superblock initialization verified")
  @end

  @! SECTION 2: Copy-on-Write File Creation & Merkle Hash Generation
  println("▶ Section 2: Copy-on-Write Block Writes & Merkle Tree Root Swap...")
  total_tests = total_tests + 1
  test_bytes = [77, 65, 89, 65, 32, 70, 83] @! "MAYA FS"
  fs = mayafs_write_file_cow(fs, "kernel_backup.bin", test_bytes)
  
  ok1 = assert_eq_int(fs.inodes_table.len(), 1, "Created 1 Inode in file system")
  ok2 = assert_eq_int(fs.allocated_blocks.len(), 1, "Allocated 1 4KB physical block")
  ok3 = assert_eq_int(fs.active_root_generation, 2, "Atomic root generation incremented to 2")
  ok4 = assert_true(str_len(fs.merkle_tree_root) == 64, "Generated 64-char SHA-256 Merkle root hash")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Copy-on-write file allocation & Merkle root verified")
  @end

  @! SECTION 3: Self-Healing Merkle Block Integrity Verification
  println("▶ Section 3: Self-Healing Block Integrity Verification...")
  total_tests = total_tests + 1
  is_healthy = mayafs_verify_and_heal_block(fs, 1, test_bytes)
  ok1 = assert_eq_int(is_healthy, 1, "Block 1 verified healthy and uncorrupted")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Self-healing block verification verified")
  @end

  println("=================================================================")
  println("📊 MAYAFS TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 MAYAFS COPY-ON-WRITE TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME MAYAFS TESTS FAILED")
    return 1
  @end
@end
