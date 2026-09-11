@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: FUNCTIONS RETURNING STRUCTS & ARRAYS
@! File: tests/e2e/tier3_combinations/test_fn_returning_struct_array.maya
@! ============================================================================

import "universe/core/collections"

@struct Stats
  min: 0
  max: 0
  sum: 0
  count: 0
@end

@struct PointPair
  p1: 0
  p2: 0
@end

@fn compute_stats(arr, length)
  min_v = arr[0]
  max_v = arr[0]
  s = 0
  i = 0
  @while i < length
    v = arr[i]
    @if v < min_v
      min_v = v
    @end
    @if v > max_v
      max_v = v
    @end
    s = s + v
    i = i + 1
  @end
  return { min: min_v, max: max_v, sum: s, count: length }
@end

@fn filter_greater_than(arr, length, threshold)
  result = []
  i = 0
  @while i < length
    @if arr[i] > threshold
      result.push(arr[i])
    @end
    i = i + 1
  @end
  return result
@end

@fn make_range_array(start, count)
  res = []
  i = 0
  @while i < count
    res.push(start + i)
    i = i + 1
  @end
  return res
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 3: Functions Returning Structs & Arrays")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.11: Function Returning Stats Struct from Array
  total = total + 1
  data = [15, 3, 42, 9, 27]
  stats = compute_stats(data, 5)
  @! min = 3, max = 42, sum = 15+3+42+9+27 = 96, count = 5
  @if stats.min == 3 && stats.max == 42 && stats.sum == 96 && stats.count == 5
    passed = passed + 1
    println("  [PASS] T3.11: Function returning statistics struct (min: 3, max: 42, sum: 96)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.11: Function returning statistics struct")
  @end

  @! T3.12: Function Filtering Array and Returning New Dynamic Array
  total = total + 1
  filtered = filter_greater_than(data, 5, 20)
  @! Elements > 20 are: [42, 27]
  @if filtered[0] == 42 && filtered[1] == 27
    passed = passed + 1
    println("  [PASS] T3.12: Function returning dynamic filtered array ([42, 27])")
  @else
    failed = failed + 1
    println("  [FAIL] T3.12: Function returning dynamic filtered array")
  @end

  @! T3.13: Generator Function Producing Array Range
  total = total + 1
  range5 = make_range_array(10, 5)
  @! [10, 11, 12, 13, 14]
  @if range5[0] == 10 && range5[2] == 12 && range5[4] == 14
    passed = passed + 1
    println("  [PASS] T3.13: Range generator function returning array ([10, 11, 12, 13, 14])")
  @else
    failed = failed + 1
    println("  [FAIL] T3.13: Range generator function")
  @end

  @! T3.14: Chained Function Calls: Generator -> Stats Struct
  total = total + 1
  gen_arr = make_range_array(1, 10)
  @! 1..10, sum = 55, min = 1, max = 10
  gen_stats = compute_stats(gen_arr, 10)
  @if gen_stats.sum == 55 && gen_stats.min == 1 && gen_stats.max == 10
    passed = passed + 1
    println("  [PASS] T3.14: Pipelined array generator into stats analyzer (sum == 55)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.14: Pipelined array generator into stats analyzer")
  @end

  @! T3.15: Function Returning Struct of Structs
  total = total + 1
  pt_pair = { p1: { x: 10, y: 20 }, p2: { x: 30, y: 40 } }
  dx = pt_pair.p2.x - pt_pair.p1.x
  dy = pt_pair.p2.y - pt_pair.p1.y
  @if dx == 20 && dy == 20
    passed = passed + 1
    println("  [PASS] T3.15: Struct holding pairs of structs (dx == 20, dy == 20)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.15: Struct holding pairs of structs")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 3 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 3 (Functions Returning Structs/Arrays) PASSED")
    return 0
  @else
    println("✗ Combination 3 (Functions Returning Structs/Arrays) FAILED")
    return 1
  @end
@end
