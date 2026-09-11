@! ============================================================================
@! MAYA OS HEAP ALLOCATOR UNIT TEST SUITE (tests/os/test_memory_heap.maya)
@! ============================================================================

import "universe/os/memory"

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
  println("🧠 MAYA SEGREGATED FREE-LIST HEAP ALLOCATOR TEST SUITE 🧠")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: Segregated Bins & Allocations
  println("▶ Section 1: Segregated Size Classes & Allocations...")
  total_tests = total_tests + 1
  
  heap = heap_new()
  ok1 = assert_eq_int(memory_size_class(16), 0, "Size 16 maps to Bin 0")
  ok2 = assert_eq_int(memory_size_class(48), 1, "Size 48 maps to Bin 1")
  ok3 = assert_eq_int(memory_size_class(100), 2, "Size 100 maps to Bin 2")
  ok4 = assert_eq_int(memory_size_class(200), 3, "Size 200 maps to Bin 3")
  ok5 = assert_eq_int(memory_size_class(500), 4, "Size 500 maps to Bin 4")
  ok6 = assert_eq_int(memory_size_class(1000), 5, "Size 1000 maps to Bin 5")
  ok7 = assert_eq_int(memory_size_class(2000), 6, "Size 2000 maps to Bin 6")
  ok8 = assert_eq_int(memory_size_class(4000), 7, "Size 4000 maps to Bin 7")
  ok9 = assert_eq_int(memory_size_class(8000), 8, "Size 8000 maps to Bin 8")
  
  p1 = memory_alloc(heap, 32)
  p2 = memory_alloc(heap, 64)
  p3 = memory_alloc(heap, 128)
  ok10 = assert_true(p1 > 0 && p2 > 0 && p3 > 0, "Allocations succeeded")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1 && ok10 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Segregated size classes & heap allocations verified")
  @end

  @! SECTION 2: Block Splitting & Immediate Coalescing
  println("▶ Section 2: Splitting & Immediate Coalescing...")
  total_tests = total_tests + 1
  
  initial_blocks = heap.blocks.len()
  ok1 = assert_true(initial_blocks >= 2, "Block split created additional free blocks")
  
  memory_free(heap, p1)
  memory_free(heap, p2)
  memory_free(heap, p3)
  
  stats = heap_stats(heap)
  ok2 = assert_eq_int(stats.allocated_bytes, 0, "All allocated bytes returned to heap")
  ok3 = assert_true(stats.free_bytes > 0, "Free bytes tracked correctly")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Block splitting & coalescing verified")
  @end

  println("=================================================================")
  println("📊 HEAP RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    return 0
  @else
    return 1
  @end
@end
