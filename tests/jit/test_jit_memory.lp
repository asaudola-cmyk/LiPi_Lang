@! ============================================================================
@! MAYA JIT TEST SUITE: MEMORY ALLOCATION & W^X PAGE PROTECTION
@! Test File: tests/jit/test_jit_memory.maya
@! Verification: sys_mmap (PROT_EXEC), sys_mprotect (W^X), sys_munmap, RAM Byte Ops
@! ============================================================================

import "compiler/backend/jit/jit_memory"

@struct TestContext
  total: 0
  passed: 0
  failed: 0
@end

@fn assert_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str())
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_true(ctx, name, condition)
  ctx.total = ctx.total + 1
  @if condition != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was false (0)")
    return 0
  @end
@end

@fn assert_ge(ctx, name, actual, min_val)
  ctx.total = ctx.total + 1
  @if actual >= min_val
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str() + " (>= " + min_val.to_str() + ")")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected >= " + min_val.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA JIT MEMORY & PROTECTION (W^X) TEST SUITE")
  println("=================================================================")

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  @! --------------------------------------------------------------------------
  @! 1. RAM Allocation via sys_mmap (PROT_EXEC)
  @! --------------------------------------------------------------------------
  println("\n--- [1] RAM Memory Allocation via sys_mmap ---")
  blk = jit_mem_alloc(4096)
  assert_true(ctx, "JIT-MEM-01: Allocated block virtual address > 0", blk.addr > 0)
  assert_eq(ctx, "JIT-MEM-02: Block size matches 4096 bytes", blk.size, 4096)
  assert_eq(ctx, "JIT-MEM-03: Block capacity matches 4096 bytes", blk.capacity, 4096)
  assert_eq(ctx, "JIT-MEM-04: Block initially has 0 used bytes", blk.used, 0)
  assert_eq(ctx, "JIT-MEM-05: Block has is_exec flag enabled (1)", blk.is_exec, 1)

  @! Page alignment check (must be multiple of 4096)
  blk_large = jit_mem_alloc(5000)
  assert_true(ctx, "JIT-MEM-06: Large block virtual address > 0", blk_large.addr > 0)
  assert_eq(ctx, "JIT-MEM-07: 5000 bytes rounded up to 8192 bytes (2 pages)", blk_large.size, 8192)

  @! --------------------------------------------------------------------------
  @! 2. RAM Byte Write & Read Operations
  @! --------------------------------------------------------------------------
  println("\n--- [2] RAM Machine Code Byte Writing & Reading ---")
  @! Write single byte: RET opcode 0xC3 (195)
  w1 = jit_mem_write_byte(blk, 0, 195)
  assert_eq(ctx, "JIT-MEM-08: jit_mem_write_byte returns 1 on success", w1, 1)
  assert_eq(ctx, "JIT-MEM-09: Read back byte at offset 0 matches 195 (0xC3 RET)", jit_mem_read_byte(blk, 0), 195)
  assert_eq(ctx, "JIT-MEM-10: Used cursor updated to 1", blk.used, 1)

  @! Write byte sequence: mov eax, 42; ret -> [184, 42, 0, 0, 0, 195]
  code_bytes = [184, 42, 0, 0, 0, 195]
  wb = jit_mem_write_bytes(blk, 0, code_bytes)
  assert_eq(ctx, "JIT-MEM-11: jit_mem_write_bytes returns 6 bytes written", wb, 6)
  assert_eq(ctx, "JIT-MEM-12: Read byte 0 (0xB8 MOV EAX)", jit_mem_read_byte(blk, 0), 184)
  assert_eq(ctx, "JIT-MEM-13: Read byte 1 (immediate 42)", jit_mem_read_byte(blk, 1), 42)
  assert_eq(ctx, "JIT-MEM-14: Read byte 5 (0xC3 RET)", jit_mem_read_byte(blk, 5), 195)
  assert_eq(ctx, "JIT-MEM-15: Used cursor updated to 6", blk.used, 6)

  @! --------------------------------------------------------------------------
  @! 3. W^X Memory Protection Transitions (sys_mprotect)
  @! --------------------------------------------------------------------------
  println("\n--- [3] W^X Memory Page Protection Transitions ---")
  @! Transition to RW (Read+Write)
  rw_res = jit_mem_protect_rw(blk)
  assert_eq(ctx, "JIT-MEM-16: Protect RW returns 0 (success)", rw_res, 0)
  assert_eq(ctx, "JIT-MEM-17: Block is_exec is 0 in RW mode", blk.is_exec, 0)

  @! Transition to RX (Read+Execute)
  rx_res = jit_mem_protect_rx(blk)
  assert_eq(ctx, "JIT-MEM-18: Protect RX returns 0 (success)", rx_res, 0)
  assert_eq(ctx, "JIT-MEM-19: Block is_exec is 1 in RX mode", blk.is_exec, 1)

  @! Transition to RWX (Read+Write+Execute)
  rwx_res = jit_mem_protect_rwx(blk)
  assert_eq(ctx, "JIT-MEM-20: Protect RWX returns 0 (success)", rwx_res, 0)
  assert_eq(ctx, "JIT-MEM-21: Block is_exec is 1 in RWX mode", blk.is_exec, 1)

  @! --------------------------------------------------------------------------
  @! 4. Memory Cleanup via sys_munmap
  @! --------------------------------------------------------------------------
  println("\n--- [4] Memory Deallocation via sys_munmap ---")
  free_res = jit_mem_free(blk)
  assert_eq(ctx, "JIT-MEM-22: jit_mem_free returns 0 (success)", free_res, 0)
  assert_eq(ctx, "JIT-MEM-23: Block address cleared to 0 after free", blk.addr, 0)
  assert_eq(ctx, "JIT-MEM-24: Block size cleared to 0 after free", blk.size, 0)

  free_res_large = jit_mem_free(blk_large)
  assert_eq(ctx, "JIT-MEM-25: Large block freed successfully", free_res_large, 0)

  @! --------------------------------------------------------------------------
  @! 5. Edge Cases & Boundary Handling
  @! --------------------------------------------------------------------------
  println("\n--- [5] Edge Cases & Guard Conditions ---")
  blk_zero = jit_mem_alloc(0)
  assert_true(ctx, "JIT-MEM-26: jit_mem_alloc(0) safely allocates default 1 page (4096)", blk_zero.size == 4096)
  jit_mem_free(blk_zero)

  free_null = jit_mem_free(0)
  assert_eq(ctx, "JIT-MEM-27: jit_mem_free(0) safely returns 0 without crashing", free_null, 0)

  println("\n=================================================================")
  println("📊 JIT MEMORY TEST SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + ctx.total.to_str())
  println("  Passed           : " + ctx.passed.to_str())
  println("  Failed           : " + ctx.failed.to_str())

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] All JIT Memory & Protection tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more JIT Memory tests failed.")
    return 1
  @end
@end
