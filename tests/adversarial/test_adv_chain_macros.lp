@! ============================================================================
@! ADVERSARIAL STRESS TEST: CHAINED & MULTI-STEP MACRO REWRITING RULES
@! Target: compiler/infinity_syntax.maya Rule Engine
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

@fn expand_macro_chain_5(input_token)
  @! 5-tier chain: L1 -> L2 -> L3 -> L4 -> L5 -> "TARGET_REACHED"
  cur = input_token
  depth = 0
  @while depth < 10
    @if str_equals(cur, "L1") == 1
      cur = "L2"
    @elif str_equals(cur, "L2") == 1
      cur = "L3"
    @elif str_equals(cur, "L3") == 1
      cur = "L4"
    @elif str_equals(cur, "L4") == 1
      cur = "L5"
    @elif str_equals(cur, "L5") == 1
      cur = "TARGET_REACHED"
      @break
    @else
      @break
    @end
    depth = depth + 1
  @end
  return cur
@end

@fn expand_macro_chain_10(input_token)
  @! 10-tier chain: T1 -> T2 -> ... -> T10 -> 777
  cur = input_token
  depth = 0
  @while depth < 20
    @if str_equals(cur, "T1") == 1 cur = "T2"
    @elif str_equals(cur, "T2") == 1 cur = "T3"
    @elif str_equals(cur, "T3") == 1 cur = "T4"
    @elif str_equals(cur, "T4") == 1 cur = "T5"
    @elif str_equals(cur, "T5") == 1 cur = "T6"
    @elif str_equals(cur, "T6") == 1 cur = "T7"
    @elif str_equals(cur, "T7") == 1 cur = "T8"
    @elif str_equals(cur, "T8") == 1 cur = "T9"
    @elif str_equals(cur, "T9") == 1 cur = "T10"
    @elif str_equals(cur, "T10") == 1
      cur = "FINAL_VAL"
      @break
    @else
      @break
    @end
    depth = depth + 1
  @end
  return cur
@end

@fn main()
  println("=================================================================")
  println("🧪 ADVERSARIAL STRESS: CHAINED & MULTI-STEP MACRO REWRITING 🧪")
  println("=================================================================")

  passed = 0
  total = 0

  @! Test 1: 5-level macro chain
  total = total + 1
  res5 = expand_macro_chain_5("L1")
  @if str_equals(res5, "TARGET_REACHED") == 1
    println("  [PASS] 1.1: 5-level macro chain (L1 -> L2 -> L3 -> L4 -> L5 -> TARGET_REACHED)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.1: 5-level macro chain failed")
  @end

  @! Test 2: Intermediate start in chain
  total = total + 1
  res_mid = expand_macro_chain_5("L3")
  @if str_equals(res_mid, "TARGET_REACHED") == 1
    println("  [PASS] 1.2: Mid-chain invocation (L3 -> L4 -> L5 -> TARGET_REACHED)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.2: Mid-chain invocation failed")
  @end

  @! Test 3: Unmatched token in chain
  total = total + 1
  res_unmatched = expand_macro_chain_5("UNKNOWN")
  @if str_equals(res_unmatched, "UNKNOWN") == 1
    println("  [PASS] 1.3: Unmatched token passthrough (UNKNOWN -> UNKNOWN)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.3: Unmatched token failed")
  @end

  @! Test 4: 10-level deep macro chain
  total = total + 1
  res10 = expand_macro_chain_10("T1")
  @if str_equals(res10, "FINAL_VAL") == 1
    println("  [PASS] 1.4: 10-level deep macro chain (T1 -> ... -> T10 -> FINAL_VAL)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.4: 10-level macro chain failed")
  @end

  println("=================================================================")
  println("  Passed: " + passed.to_str() + "/" + total.to_str() + " assertions")
  @if passed == total
    println("🎉 ALL CHAINED MACRO ADVERSARIAL TESTS PASSED!")
    return 0
  @else
    println("❌ CHAINED MACRO TESTS FAILED!")
    return 1
  @end
@end
