@! ============================================================================
@! MAYA UNMOCKED GC TEST SUITE: REALLOCATION & BOUNDARY CROSSING
@! File: tests/gc/test_gc_realloc.maya
@! Scope: In-place growth, cross-slab migrations, slab-to-mmap promotions,
@!        mmap-to-slab demotions, and payload preservation.
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct ReallocContext
  total: 0
  passed: 0
  failed: 0
@end

@fn r_assert_true(ctx, name, cond)
  ctx.total = ctx.total + 1
  @if cond != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was false (0)")
    return 0
  @end
@end

@fn r_assert_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + maya_int_to_str(actual))
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected " + maya_int_to_str(expected) + ", got " + maya_int_to_str(actual))
    return 0
  @end
@end

@fn r_assert_str_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> matched string \"" + actual + "\"")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
@end

@fn write_str_to_ptr(ptr, str_val, pid)
  len = str_len(str_val)
  f_tmp = "/tmp/maya_realloc_w_" + maya_int_to_str(pid) + ".tmp"
  fd = sys_open(f_tmp, 578, 420)
  sys_write(fd, str_val, len)
  sys_close(fd)

  fd_r = sys_open(f_tmp, 0, 0)
  sys_read(fd_r, ptr, len)
  sys_close(fd_r)
  sys_unlink(f_tmp)
  return len
@end

@fn read_str_from_ptr(ptr, len, pid)
  f_tmp = "/tmp/maya_realloc_r_" + maya_int_to_str(pid) + ".tmp"
  fd = sys_open(f_tmp, 578, 420)
  sys_write(fd, ptr, len)
  sys_close(fd)

  res_str = file_read(f_tmp)
  sys_unlink(f_tmp)
  return res_str
@end

@! --- Tests ---

@fn test_realloc_specials(ctx)
  println("\n--- [Realloc Test Group 1] NULL and Zero Edge Cases ---")

  @! 1. realloc(0, 128) == alloc(128)
  p1 = gc_realloc(0, 128)
  r_assert_true(ctx, "TC-REALLOC-01.1: gc_realloc(0, 128) allocates new buffer", p1 > 0)
  r_assert_eq(ctx, "TC-REALLOC-01.2: pointer is 8-byte aligned", p1 % 8, 0)

  @! 2. realloc(p1, 0) == free(p1) -> returns 0
  p0 = gc_realloc(p1, 0)
  p1_base = gc_base(p1)
  r_assert_eq(ctx, "TC-REALLOC-02.1: gc_realloc(p, 0) frees and returns 0", p0, 0)
  r_assert_eq(ctx, "TC-REALLOC-02.2: gc_base(p1) is 0 after realloc(0)", p1_base, 0)
@end

@fn test_realloc_slab_expansions(ctx)
  println("\n--- [Realloc Test Group 2] Progressive Slab-to-Slab Expansions ---")
  pid = sys_getpid()

  @! Allocate 16 bytes and write data
  p = gc_alloc(16)
  msg16 = "ORIGINAL_16_BYTE"
  write_str_to_ptr(p, msg16, pid)
  r_assert_str_eq(ctx, "TC-REALLOC-04.1: Initial 16B payload confirmed", read_str_from_ptr(p, 16, pid), msg16)

  @! Realloc to 64 bytes
  p = gc_realloc(p, 64)
  r_assert_true(ctx, "TC-REALLOC-04.2: Realloc 16B -> 64B returns valid pointer", p > 0)
  r_assert_str_eq(ctx, "TC-REALLOC-04.3: Original 16B preserved after 64B realloc", read_str_from_ptr(p, 16, pid), msg16)

  @! Append new data in 64B buffer
  msg64_tail = "_EXPANDED_TO_64_BYTES_DATA_BLOCK_OK!"
  write_str_to_ptr(p + 16, msg64_tail, pid)

  @! Realloc to 256 bytes
  p = gc_realloc(p, 256)
  r_assert_true(ctx, "TC-REALLOC-05.1: Realloc 64B -> 256B returns valid pointer", p > 0)
  r_assert_str_eq(ctx, "TC-REALLOC-05.2: Header 16B preserved after 256B realloc", read_str_from_ptr(p, 16, pid), msg16)
  r_assert_str_eq(ctx, "TC-REALLOC-05.3: Mid 36B preserved after 256B realloc", read_str_from_ptr(p + 16, str_len(msg64_tail), pid), msg64_tail)

  @! Realloc to 1024 bytes
  p = gc_realloc(p, 1024)
  r_assert_true(ctx, "TC-REALLOC-06.1: Realloc 256B -> 1024B returns valid pointer", p > 0)
  r_assert_str_eq(ctx, "TC-REALLOC-06.2: Header 16B preserved after 1024B realloc", read_str_from_ptr(p, 16, pid), msg16)

  @! Realloc to 2048 bytes
  p = gc_realloc(p, 2048)
  r_assert_true(ctx, "TC-REALLOC-07.1: Realloc 1024B -> 2048B returns valid pointer", p > 0)
  r_assert_str_eq(ctx, "TC-REALLOC-07.2: Header 16B preserved after 2048B realloc", read_str_from_ptr(p, 16, pid), msg16)

  gc_free(p)
@end

@fn test_realloc_slab_mmap_transitions(ctx)
  println("\n--- [Realloc Test Group 3] Slab-to-Mmap Promotions & Demotions ---")
  pid = sys_getpid()

  @! 1. Slab (1024B) -> Large Mmap (8192B)
  p_slab = gc_alloc(1024)
  msg_slab = "SLAB_TO_MMAP_PROMOTION_TEST_HEADER_DATA_1234567890_ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  write_str_to_ptr(p_slab, msg_slab, pid)

  p_mmap = gc_realloc(p_slab, 8192)
  r_assert_true(ctx, "TC-REALLOC-08.1: Realloc 1024B -> 8192B (mmap) returns valid pointer", p_mmap > 0)
  r_assert_str_eq(ctx, "TC-REALLOC-08.2: Data preserved across slab->mmap boundary", read_str_from_ptr(p_mmap, str_len(msg_slab), pid), msg_slab)

  @! 2. Large Mmap (4096B) -> Slab (64B) Demotion
  p_big = gc_alloc(4096)
  msg_big = "MMAP_TO_SLAB_DEMOTION_TEST_PREFIX_PAYLOAD_CHECK_VALIDATION_STRING_OK"
  write_str_to_ptr(p_big, msg_big, pid)

  p_small = gc_realloc(p_big, 64)
  r_assert_true(ctx, "TC-REALLOC-09.1: Realloc 4096B -> 64B (slab) returns valid pointer", p_small > 0)
  r_assert_str_eq(ctx, "TC-REALLOC-09.2: Data preserved across mmap->slab demotion", read_str_from_ptr(p_small, 64, pid), str_substr(msg_big, 0, 64))

  @! 3. Buffer Shrinkage within Slab (2048B -> 32B)
  p_2048 = gc_alloc(2048)
  msg_shrink = "SHRINK_TEST_FIRST_32_BYTES_DATA!"
  write_str_to_ptr(p_2048, msg_shrink, pid)

  p_32 = gc_realloc(p_2048, 32)
  r_assert_true(ctx, "TC-REALLOC-10.1: Realloc 2048B -> 32B shrinkage returns valid pointer", p_32 > 0)
  r_assert_str_eq(ctx, "TC-REALLOC-10.2: First 32 bytes preserved after shrinkage", read_str_from_ptr(p_32, 32, pid), msg_shrink)

  gc_free(p_mmap)
  gc_free(p_small)
  gc_free(p_32)
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA NATIVE GC REALLOCATION VERIFICATION SUITE")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_realloc_specials(ctx)
  test_realloc_slab_expansions(ctx)
  test_realloc_slab_mmap_transitions(ctx)

  println("\n=================================================================")
  println("📊 REALLOCATION TEST SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] 100% of reallocation tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more reallocation tests failed.")
    return 1
  @end
@end
