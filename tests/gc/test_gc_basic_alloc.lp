@! ============================================================================
@! MAYA UNMOCKED GC TEST SUITE: BASIC ALLOCATION & SLAB BOUNDARIES
@! File: tests/gc/test_gc_basic_alloc.maya
@! Scope: 100% Unmocked live verification of segregated slab pools (16B-2048B)
@!        and large page-aligned mmap allocations (>2048B) in Pure Maya.
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/gc"

@struct GcTestContext
  total: 0
  passed: 0
  failed: 0
@end

@fn gc_test_assert_true(ctx, name, cond)
  ctx.total = ctx.total + 1
  @if cond != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition evaluated to false (0)")
    return 0
  @end
@end

@fn gc_test_assert_eq(ctx, name, actual, expected)
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

@fn gc_test_assert_str_eq(ctx, name, actual, expected)
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

@! Helper: write pattern to memory using raw file transfer (unmocked syscalls)
@fn verify_buffer_payload(ctx, test_name, ptr, size, pattern, pid)
  pat_len = str_len(pattern)
  f_in = "/tmp/maya_gc_in_" + maya_int_to_str(pid) + ".tmp"
  f_out = "/tmp/maya_gc_out_" + maya_int_to_str(pid) + ".tmp"

  @! Write pattern to temp file
  fd_w = sys_open(f_in, 578, 420) @! O_CREAT|O_RDWR|O_TRUNC, 0644
  sys_write(fd_w, pattern, pat_len)
  sys_close(fd_w)

  @! Read pattern into allocated GC buffer
  fd_r = sys_open(f_in, 0, 0)
  bytes_read = sys_read(fd_r, ptr, pat_len)
  sys_close(fd_r)
  sys_unlink(f_in)

  @! Write back from GC buffer to output file
  fd_ow = sys_open(f_out, 578, 420)
  bytes_written = sys_write(fd_ow, ptr, pat_len)
  sys_close(fd_ow)

  @! Read string back
  read_back = file_read(f_out)
  sys_unlink(f_out)

  gc_test_assert_eq(ctx, test_name + " [bytes read]", bytes_read, pat_len)
  gc_test_assert_eq(ctx, test_name + " [bytes written]", bytes_written, pat_len)
  gc_test_assert_str_eq(ctx, test_name + " [content integrity]", read_back, pattern)
  return 1
@end

@! --- Test Suites ---

@fn test_all_slab_classes(ctx)
  println("\n--- [Test Group 1] All 8 Segregated Slab Classes (16B to 2048B) ---")
  pid = sys_getpid()

  @! 1. Slab Class 0: 16 bytes (request 1B and 16B)
  p1 = gc_alloc(1)
  gc_test_assert_true(ctx, "TC-ALLOC-01.1: alloc(1B) returns positive address", p1 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-01.2: alloc(1B) 8-byte aligned", p1 % 8, 0)
  verify_buffer_payload(ctx, "TC-ALLOC-01.3: alloc(1B) payload", p1, 1, "A", pid)

  p16 = gc_alloc(16)
  gc_test_assert_true(ctx, "TC-ALLOC-02.1: alloc(16B) returns positive address", p16 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-02.2: alloc(16B) 8-byte aligned", p16 % 8, 0)
  verify_buffer_payload(ctx, "TC-ALLOC-02.3: alloc(16B) payload", p16, 16, "0123456789ABCDEF", pid)

  @! 2. Slab Class 1: 32 bytes (request 17B and 32B)
  p17 = gc_alloc(17)
  gc_test_assert_true(ctx, "TC-ALLOC-03.1: alloc(17B) returns positive address", p17 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-03.2: alloc(17B) 8-byte aligned", p17 % 8, 0)
  verify_buffer_payload(ctx, "TC-ALLOC-03.3: alloc(17B) payload", p17, 17, "SEVENTEEN_BYTES!!", pid)

  p32 = gc_alloc(32)
  gc_test_assert_true(ctx, "TC-ALLOC-04.1: alloc(32B) returns positive address", p32 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-04.2: alloc(32B) 8-byte aligned", p32 % 8, 0)
  verify_buffer_payload(ctx, "TC-ALLOC-04.3: alloc(32B) payload", p32, 32, "THIRTY_TWO_BYTES_OF_PAYLOAD_DATA", pid)

  @! 3. Slab Class 2: 64 bytes
  p64 = gc_alloc(64)
  gc_test_assert_true(ctx, "TC-ALLOC-05.1: alloc(64B) returns positive address", p64 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-05.2: alloc(64B) 8-byte aligned", p64 % 8, 0)
  verify_buffer_payload(ctx, "TC-ALLOC-05.3: alloc(64B) payload", p64, 64, "SIXTY_FOUR_BYTES_OF_DATA_PAYLOAD_VERIFICATION_STRING_1234567890!", pid)

  @! 4. Slab Class 3: 128 bytes
  p128 = gc_alloc(128)
  gc_test_assert_true(ctx, "TC-ALLOC-06.1: alloc(128B) returns positive address", p128 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-06.2: alloc(128B) 8-byte aligned", p128 % 8, 0)
  verify_buffer_payload(ctx, "TC-ALLOC-06.3: alloc(128B) payload", p128, 128, "ONE_HUNDRED_AND_TWENTY_EIGHT_BYTES_PAYLOAD_STRING_BLOCK_VERIFICATION_CHECK_OK_1234567890_ABCDEFGHIJKLMNOPQRSTUVWXYZ_0987654321!", pid)

  @! 5. Slab Class 4: 256 bytes
  p256 = gc_alloc(256)
  gc_test_assert_true(ctx, "TC-ALLOC-07.1: alloc(256B) returns positive address", p256 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-07.2: alloc(256B) 8-byte aligned", p256 % 8, 0)

  @! 6. Slab Class 5: 512 bytes
  p512 = gc_alloc(512)
  gc_test_assert_true(ctx, "TC-ALLOC-08.1: alloc(512B) returns positive address", p512 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-08.2: alloc(512B) 8-byte aligned", p512 % 8, 0)

  @! 7. Slab Class 6: 1024 bytes
  p1024 = gc_alloc(1024)
  gc_test_assert_true(ctx, "TC-ALLOC-09.1: alloc(1024B) returns positive address", p1024 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-09.2: alloc(1024B) 8-byte aligned", p1024 % 8, 0)

  @! 8. Slab Class 7: 2048 bytes
  p2048 = gc_alloc(2048)
  gc_test_assert_true(ctx, "TC-ALLOC-10.1: alloc(2048B) returns positive address", p2048 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-10.2: alloc(2048B) 8-byte aligned", p2048 % 8, 0)

  @! Assert all addresses are distinct
  all_distinct = (p1 != p16) && (p16 != p17) && (p17 != p32) && (p32 != p64) && (p64 != p128) && (p128 != p256) && (p256 != p512) && (p512 != p1024) && (p1024 != p2048)
  gc_test_assert_true(ctx, "TC-ALLOC-15: All 10 simultaneous slab allocations have distinct addresses", all_distinct != 0)

  @! Free all blocks
  gc_free(p1)
  gc_free(p16)
  gc_free(p17)
  gc_free(p32)
  gc_free(p64)
  gc_free(p128)
  gc_free(p256)
  gc_free(p512)
  gc_free(p1024)
  gc_free(p2048)
@end

@fn test_large_mmap_allocations(ctx)
  println("\n--- [Test Group 2] Large Mmap Allocations (>2048B to 4MB) ---")
  pid = sys_getpid()

  @! 1. 2049 bytes (just crosses slab threshold into 4KB page)
  p2049 = gc_alloc(2049)
  gc_test_assert_true(ctx, "TC-ALLOC-11.1: alloc(2049B) returns valid address", p2049 > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-11.2: alloc(2049B) 8-byte aligned", p2049 % 8, 0)
  verify_buffer_payload(ctx, "TC-ALLOC-11.3: alloc(2049B) payload", p2049, 2049, "LARGE_OBJECT_PAYLOAD_START_HEADER_2049_BYTES_BOUNDARY_CHECK", pid)
  gc_free(p2049)

  @! 2. 64KB (65536 bytes = 16 pages)
  p64k = gc_alloc(65536)
  gc_test_assert_true(ctx, "TC-ALLOC-12.1: alloc(64KB) returns valid address", p64k > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-12.2: alloc(64KB) 8-byte aligned", p64k % 8, 0)
  verify_buffer_payload(ctx, "TC-ALLOC-12.3: alloc(64KB) payload", p64k, 65536, "64KB_LARGE_MMAP_BUFFER_DATA_PAYLOAD_TEST_OK", pid)
  gc_free(p64k)

  @! 3. 1MB (1048576 bytes = 256 pages)
  p1m = gc_alloc(1048576)
  gc_test_assert_true(ctx, "TC-ALLOC-13.1: alloc(1MB) returns valid address", p1m > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-13.2: alloc(1MB) 8-byte aligned", p1m % 8, 0)
  verify_buffer_payload(ctx, "TC-ALLOC-13.3: alloc(1MB) payload", p1m, 1048576, "1MB_MEGA_BUFFER_AUTHENTICATED_PAYLOAD_STRING_HEADER", pid)
  gc_free(p1m)

  @! 4. 4MB (4194304 bytes = 1024 pages)
  p4m = gc_alloc(4194304)
  gc_test_assert_true(ctx, "TC-ALLOC-14.1: alloc(4MB) returns valid address", p4m > 0)
  gc_test_assert_eq(ctx, "TC-ALLOC-14.2: alloc(4MB) 8-byte aligned", p4m % 8, 0)
  gc_free(p4m)
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA NATIVE GC BASIC ALLOCATOR & SLAB VERIFICATION SUITE")
  println("=================================================================")

  gc_init()

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  test_all_slab_classes(ctx)
  test_large_mmap_allocations(ctx)

  println("\n=================================================================")
  println("📊 BASIC ALLOCATOR TEST SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + maya_int_to_str(ctx.total))
  println("  Passed           : " + maya_int_to_str(ctx.passed))
  println("  Failed           : " + maya_int_to_str(ctx.failed))

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] 100% of basic allocator tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more allocator tests failed.")
    return 1
  @end
@end
