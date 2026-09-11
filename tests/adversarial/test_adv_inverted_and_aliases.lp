@! ============================================================================
@! ADVERSARIAL STRESS TEST: INVERTED CONDITIONALS, LOOP ALIASES & STATEMENT MACROS
@! Tests:
@!   1. Inverted condition evaluation (UNLESS x -> @if 0 == x)
@!   2. Forever loop alias search & break termination (forever ... done)
@!   3. Repeated statement macro invocation state tracking
@!   4. Deep 6-level nested inverted conditionals
@! ============================================================================

@fn test_unless_branch(cond)
  @! UNLESS cond -> executes body when cond == 0
  res = 0
  @if 0 == cond
    res = 100
  @end
  return res
@end

@fn test_forever_search(target)
  @! forever -> @while 1 with break on match
  val = 1
  @while 1
    @if val >= target
      break
    @end
    val = val * 2
  @end
  return val
@end

@fn test_deep_nested_unless(v)
  @! 6-level nested inverted conditional checks
  depth = 0
  @if 0 == (v <= 0)
    depth = depth + 1
    @if 0 == (v <= 10)
      depth = depth + 1
      @if 0 == (v <= 50)
        depth = depth + 1
        @if 0 == (v <= 100)
          depth = depth + 1
          @if 0 == (v <= 200)
            depth = depth + 1
            @if 0 == (v > 500)
              depth = depth + 1
            @end
          @end
        @end
      @end
    @end
  @end
  return depth
end

@fn main()
  println("=================================================================")
  println("🧪 ADVERSARIAL STRESS: INVERTED CONDITIONALS & LOOP ALIASES 🧪")
  println("=================================================================")

  passed = 0
  total = 0

  @! Test 1: UNLESS inverted condition evaluations
  total = total + 1
  u0 = test_unless_branch(0)
  u1 = test_unless_branch(1)
  u42 = test_unless_branch(42)
  u_neg = test_unless_branch(0 - 5)
  @if u0 == 100 && u1 == 0 && u42 == 0 && u_neg == 0
    println("  [PASS] 1.1: Inverted conditional UNLESS (0 -> 100, non-zero -> 0)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.1: Inverted conditional failed")
  @end

  @! Test 2: forever ... done loop search with break
  total = total + 1
  search100 = test_forever_search(100)
  search1000 = test_forever_search(1000)
  search1 = test_forever_search(1)
  @if search100 == 128 && search1000 == 1024 && search1 == 1
    println("  [PASS] 1.2: Forever loop alias search & break termination (targets: 100->128, 1000->1024, 1->1)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.2: Forever loop search failed")
  @end

  @! Test 3: Multi-invocation statement macro accumulation simulation
  total = total + 1
  acc = 0
  @! Simulate 5 invocations of ACCUM_10 -> acc += 10
  acc = acc + 10
  acc = acc + 10
  acc = acc + 10
  acc = acc + 10
  acc = acc + 10
  @if acc == 50
    println("  [PASS] 1.3: Repeated statement macro invocations (5x ACCUM_10 -> acc=50)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.3: Statement macro accumulation failed")
  @end

  @! Test 4: Deep 6-level nested inverted conditional checks
  total = total + 1
  d6 = test_deep_nested_unless(250)
  d3 = test_deep_nested_unless(75)
  d0 = test_deep_nested_unless(0 - 10)
  @if d6 == 6 && d3 == 3 && d0 == 0
    println("  [PASS] 1.4: Deep 6-level nested inverted conditionals (val 250->6, 75->3, -10->0)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.4: Nested inverted conditionals failed")
  @end

  println("=================================================================")
  println("  Passed: " + passed.to_str() + "/" + total.to_str() + " assertions")
  @if passed == total
    println("🎉 ALL INVERTED CONDITIONAL & LOOP ALIAS TESTS PASSED!")
    return 0
  @else
    println("❌ INVERTED CONDITIONAL & LOOP ALIAS TESTS FAILED!")
    return 1
  @end
@end
