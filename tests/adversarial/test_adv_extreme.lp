@! ============================================================================
@! ADVERSARIAL STRESS TEST: EXTREME COMPLEXITY & DEEP EDGE CASES (test_adv_extreme.maya)
@! Tests:
@! 1. Deeply nested structs and multi-level field mutation
@! 2. High-volume string concatenation & Boehm GC stress (200 string concats)
@! 3. Int64 two's complement wraparound and negative arithmetic limits
@! 4. Array of structs with high-frequency allocation and pushes
@! 5. Complex nested pipe pipelines and multi-arg numeric composition
@! ============================================================================

@struct InnerBox
  val: 0
  tag: ""
@end

@struct OuterBox
  id: 0
  inner: 0
  data: 0
@end

@fn pipe_step1(x)
  return x * 3 + 1
@end

@fn pipe_step2(x)
  return x * 2
@end

@fn pipe_step3(x)
  return x - 5
@end

@fn main()
  println("=================================================================")
  println("ADVERSARIAL SUITE: EXTREME EDGE CASES & GC STRESS")
  println("=================================================================")

  let passed = 0
  let total = 0

  @! -------------------------------------------------------------
  @! 1. Deeply Nested Structs & Multi-level Field Mutation
  @! -------------------------------------------------------------
  println("▶ Section 1: Deeply Nested Structs")

  total = total + 1
  let inner_obj = { val: 50, tag: "initial" }
  let outer_obj = { id: 1001, inner: inner_obj, data: [1, 2, 3] }

  let inner_ref = outer_obj.inner
  @if outer_obj.id == 1001 && inner_ref.val == 50 && inner_ref.tag == "initial"
    passed = passed + 1
    println("  [PASS] EX1.1: Nested struct field access (outer.inner.val == 50)")
  @else
    println("  [FAIL] EX1.1: Nested struct field access")
  @end

  total = total + 1
  inner_ref.val = 250
  inner_ref.tag = "mutated"
  let check_inner = outer_obj.inner
  @if check_inner.val == 250 && check_inner.tag == "mutated"
    passed = passed + 1
    println("  [PASS] EX1.2: In-place mutation of nested struct fields")
  @else
    println("  [FAIL] EX1.2: In-place mutation of nested struct")
  @end

  @! -------------------------------------------------------------
  @! 2. High-Volume String Concatenation & GC Allocation Stress
  @! -------------------------------------------------------------
  println("▶ Section 2: High-Volume GC String Allocation Stress")

  total = total + 1
  let stress_str = ""
  let i = 0
  @while i < 200
    stress_str = stress_str + "A"
    i = i + 1
  @end
  @if stress_str.len() == 200 && stress_str.starts_with("AAA") && stress_str.ends_with("AAA")
    passed = passed + 1
    println("  [PASS] EX2.1: 200-iteration string allocation & GC collection stress test (len = 200)")
  @else
    println("  [FAIL] EX2.1: String GC stress test")
  @end

  @! -------------------------------------------------------------
  @! 3. Int64 Two's Complement Wraparound & Boundary Limits
  @! -------------------------------------------------------------
  println("▶ Section 3: Two's Complement Integer Boundaries")

  total = total + 1
  let max_val = 9223372036854775807
  let min_val = 0 - 9223372036854775807 - 1
  let wrap_val = max_val + 1
  @if wrap_val == min_val
    passed = passed + 1
    println("  [PASS] EX3.1: Two's complement integer overflow wrap: INT64_MAX + 1 == INT64_MIN")
  @else
    println("  [FAIL] EX3.1: Two's complement overflow wrap")
  @end

  total = total + 1
  let underflow_val = min_val - 1
  @if underflow_val == max_val
    passed = passed + 1
    println("  [PASS] EX3.2: Two's complement integer underflow wrap: INT64_MIN - 1 == INT64_MAX")
  @else
    println("  [FAIL] EX3.2: Two's complement underflow wrap")
  @end

  @! -------------------------------------------------------------
  @! 4. Array of Structs with High-Frequency Pushes
  @! -------------------------------------------------------------
  println("▶ Section 4: Array Struct Allocation Growth")

  total = total + 1
  let boxes = []
  let k = 0
  @while k < 100
    boxes.push({ val: k, tag: "elem" })
    k = k + 1
  @end

  let box_sum = 0
  let m = 0
  @while m < 100
    let b = boxes[m]
    box_sum = box_sum + b.val
    m = m + 1
  @end
  @! Sum from 0 to 99: 99 * 100 / 2 = 4950
  @if boxes.len() == 100 && box_sum == 4950
    passed = passed + 1
    println("  [PASS] EX4.1: 100 dynamically allocated structs pushed into dynamic array (sum = 4950)")
  @else
    println("  [FAIL] EX4.1: Array of structs allocation growth")
  @end

  @! -------------------------------------------------------------
  @! 5. Pipe Operator Deep Composition Pipeline
  @! -------------------------------------------------------------
  println("▶ Section 5: Complex Pipe Operator Pipeline")

  total = total + 1
  @! 10 |> step1 (31) |> step2 (62) |> step3 (57) = 57
  let pipe_res = 10 |> pipe_step1 |> pipe_step2 |> pipe_step3
  @if pipe_res == 57
    passed = passed + 1
    println("  [PASS] EX5.1: Chained pipe pipeline composition (10 |> step1 |> step2 |> step3 == 57)")
  @else
    println("  [FAIL] EX5.1: Chained pipe composition")
  @end

  println("=================================================================")
  println("EXTREME TESTS SUMMARY: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")

  @if passed == total
    return 0
  @else
    return 1
  @end
@end
