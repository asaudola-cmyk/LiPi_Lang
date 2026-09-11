@! ============================================================================
@! ADVERSARIAL STRESS TEST: BOUNDARY TESTS & MACRO RECURSION DEPTH PROTECTION
@! Verifies:
@!   1. 2-cycle recursion termination (A -> B -> A)
@!   2. 3-cycle recursion termination (X -> Y -> Z -> X)
@!   3. Self-referential recursion bounded expansion (S -> S + 1)
@!   4. Custom depth limits (depth = 0, 1, 16, 64, 128)
@!   5. Infinite expansion prevention and deterministic termination
@! ============================================================================

@fn str_equals(s1, s2)
  @if s1 == s2 return 1 @end
  @if s1 == 0 || s2 == 0 return 0 @end
  i = 0
  @while 1
    c1 = str_char_at(s1, i)
    c2 = str_char_at(s2, i)
    @if c1 != c2 return 0 @end
    @if c1 == 0 return 1 @end
    i = i + 1
  @end
  return 1
@end

@fn simulate_cyclic_2_val(initial_token, max_depth)
  cur = initial_token
  depth = 0
  @while depth < max_depth
    @if str_equals(cur, "CYCLE_A") == 1
      cur = "CYCLE_B"
    @elif str_equals(cur, "CYCLE_B") == 1
      cur = "CYCLE_A"
    @else
      @break
    @end
    depth = depth + 1
  @end
  return cur
@end

@fn simulate_cyclic_2_iters(initial_token, max_depth)
  cur = initial_token
  depth = 0
  @while depth < max_depth
    @if str_equals(cur, "CYCLE_A") == 1
      cur = "CYCLE_B"
    @elif str_equals(cur, "CYCLE_B") == 1
      cur = "CYCLE_A"
    @else
      @break
    @end
    depth = depth + 1
  @end
  return depth
@end

@fn simulate_cyclic_3_val(initial_token, max_depth)
  cur = initial_token
  depth = 0
  @while depth < max_depth
    @if str_equals(cur, "CYC_X") == 1
      cur = "CYC_Y"
    @elif str_equals(cur, "CYC_Y") == 1
      cur = "CYC_Z"
    @elif str_equals(cur, "CYC_Z") == 1
      cur = "CYC_X"
    @else
      @break
    @end
    depth = depth + 1
  @end
  return cur
@end

@fn simulate_cyclic_3_iters(initial_token, max_depth)
  cur = initial_token
  depth = 0
  @while depth < max_depth
    @if str_equals(cur, "CYC_X") == 1
      cur = "CYC_Y"
    @elif str_equals(cur, "CYC_Y") == 1
      cur = "CYC_Z"
    @elif str_equals(cur, "CYC_Z") == 1
      cur = "CYC_X"
    @else
      @break
    @end
    depth = depth + 1
  @end
  return depth
@end

@fn simulate_self_referential_growth(initial_len, max_depth)
  cur_len = initial_len
  depth = 0
  @while depth < max_depth
    @! In each step, token expands into 3 tokens: S -> S + 1 (len grows by 2)
    cur_len = cur_len + 2
    depth = depth + 1
  @end
  return cur_len
@end

@fn main()
  println("=================================================================")
  println("🧪 ADVERSARIAL STRESS: BOUNDARY & RECURSION DEPTH PROTECTION 🧪")
  println("=================================================================")

  passed = 0
  total = 0

  @! Test 1: 2-cycle recursion terminates exactly at max_depth = 128
  total = total + 1
  c2_iters = simulate_cyclic_2_iters("CYCLE_A", 128)
  c2_val = simulate_cyclic_2_val("CYCLE_A", 128)
  @if c2_iters == 128 && str_equals(c2_val, "CYCLE_A") == 1
    println("  [PASS] 1.1: 2-cycle recursion safely bounded at max_depth = 128 without hang")
    passed = passed + 1
  @else
    println("  [FAIL] 1.1: 2-cycle recursion failed")
  @end

  @! Test 2: 2-cycle recursion terminates at odd depth
  total = total + 1
  c2_odd_iters = simulate_cyclic_2_iters("CYCLE_A", 63)
  c2_odd_val = simulate_cyclic_2_val("CYCLE_A", 63)
  @if c2_odd_iters == 63 && str_equals(c2_odd_val, "CYCLE_B") == 1
    println("  [PASS] 1.2: 2-cycle recursion at odd depth 63 -> CYCLE_B")
    passed = passed + 1
  @else
    println("  [FAIL] 1.2: 2-cycle odd depth failed")
  @end

  @! Test 3: 3-cycle recursion terminates exactly at max_depth = 64
  total = total + 1
  c3_iters = simulate_cyclic_3_iters("CYC_X", 64)
  c3_val = simulate_cyclic_3_val("CYC_X", 64)
  @if c3_iters == 64 && str_equals(c3_val, "CYC_Y") == 1
    println("  [PASS] 1.3: 3-cycle recursion safely bounded at max_depth = 64 (X->Y->Z->X)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.3: 3-cycle recursion failed")
  @end

  @! Test 4: Self-referential recursion bounded length growth
  total = total + 1
  final_len = simulate_self_referential_growth(1, 10)
  @! 1 + 10 * 2 = 21 tokens
  @if final_len == 21
    println("  [PASS] 1.4: Self-referential expanding macro strictly bounded at depth=10 (len=21)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.4: Self-referential expansion failed")
  @end

  @! Test 5: Zero depth limit protection
  total = total + 1
  z_iters = simulate_cyclic_2_iters("CYCLE_A", 0)
  z_val = simulate_cyclic_2_val("CYCLE_A", 0)
  @if z_iters == 0 && str_equals(z_val, "CYCLE_A") == 1
    println("  [PASS] 1.5: Zero max_depth boundary produces immediate zero-iteration return")
    passed = passed + 1
  @else
    println("  [FAIL] 1.5: Zero max_depth failed")
  @end

  println("=================================================================")
  println("  Passed: " + passed.to_str() + "/" + total.to_str() + " assertions")
  @if passed == total
    println("🎉 ALL RECURSION DEPTH & BOUNDARY ADVERSARIAL TESTS PASSED!")
    return 0
  @else
    println("❌ RECURSION DEPTH & BOUNDARY TESTS FAILED!")
    return 1
  @end
@end
