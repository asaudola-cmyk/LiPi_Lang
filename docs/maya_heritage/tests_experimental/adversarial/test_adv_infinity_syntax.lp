// @! ============================================================================
// @! ADVERSARIAL STRESS SUITE: INFINITY SYNTAX & DYNAMIC GRAMMAR RULES
// @! File: tests/adversarial/test_adv_infinity_syntax.maya
// @! Architecture: Pure Maya Sovereign Dynamic Metaprogramming Stress
// @!
// @! // @! RUN: %maya %file -o %out && %out
// @! // @! EXPECT_CONTAINS: ALL ADVERSARIAL INFINITY SYNTAX TESTS PASSED
// @! // @! EXPECT_EXIT: 0
// @! ============================================================================

@! Sovereign Infinity Rules with boundary edge patterns
@infinity_rule "mientras" => "@while" ;
@infinity_rule "si" => "@if" ;
@infinity_rule "sino" => "@else" ;
@infinity_rule "retornar" => "return" ;
@infinity_rule "fin" => "@end" ;
@infinity_rule "forever" => "@while 1" ;
@infinity_rule "done" => "@end" ;
@infinity_rule "UNLESS" => "@if 0 ==" ;

@! 10-Level Recursive Macro Chain for Depth Stress
@infinity_rule "MACRO_L1" => "MACRO_L2" ;
@infinity_rule "MACRO_L2" => "MACRO_L3" ;
@infinity_rule "MACRO_L3" => "MACRO_L4" ;
@infinity_rule "MACRO_L4" => "MACRO_L5" ;
@infinity_rule "MACRO_L5" => "MACRO_L6" ;
@infinity_rule "MACRO_L6" => "MACRO_L7" ;
@infinity_rule "MACRO_L7" => "MACRO_L8" ;
@infinity_rule "MACRO_L8" => "MACRO_L9" ;
@infinity_rule "MACRO_L9" => "MACRO_L10" ;
@infinity_rule "MACRO_L10" => "acc = acc + 777 ;" ;

@custom_op "**" "INFIX_RIGHT" 80 "adv_power" ;
@custom_op "<=>" "INFIX_LEFT" 30 "adv_spaceship" ;
@custom_op "^^" "INFIX_LEFT" 25 "adv_xor" ;

@fn adv_power(base, exp)
  @if exp <= 0
    return 1
  @end
  res = 1
  b = base
  e = exp
  @while e > 0
    @if (e % 2) == 1
      res = res * b
    @end
    b = b * b
    e = e / 2
  @end
  return res
@end

@fn adv_spaceship(a, b)
  @if a < b
    return 0 - 1
  @elif a > b
    return 1
  @else
    return 0
  @end
@end

@fn adv_xor(a, b)
  b_a = 0
  @if a != 0
    b_a = 1
  @end
  b_b = 0
  @if b != 0
    b_b = 1
  @end
  @if (b_a == 1 && b_b == 0) || (b_a == 0 && b_b == 1)
    return 1
  @else
    return 0
  @end
@end

@fn test_large_spanish_workload(count)
  acc = 0
  i = 0
  mientras i < count
    si (i % 2) == 0
      acc = acc + i
    sino
      acc = acc - i
    fin
    i = i + 1
  fin
  retornar acc
fin

@fn test_deep_nested_spanish(val)
  depth = 0
  si val > 0
    depth = depth + 1
    si val > 10
      depth = depth + 1
      si val > 50
        depth = depth + 1
        si val > 100
          depth = depth + 1
          si val > 200
            depth = depth + 1
            si val <= 500
              depth = depth + 1
            fin
          fin
        fin
      fin
    fin
  fin
  retornar depth
fin

@fn main()
  println("=================================================================")
  println("  MAYA ADVERSARIAL & STRESS TEST SUITE (INFINITY SYNTAX)")
  println("=================================================================")

  passed = 0
  total = 0

  @! ----------------------------------------------------------------------
  @! Section 1: Extreme Mathematical Operator Boundaries (Direct Custom Operators)
  @! ----------------------------------------------------------------------
  println("▶ Adv Section 1: Extreme Mathematical Operator Boundaries")

  total = total + 1
  p_30 = 2 ** 30
  @if p_30 == 1073741824
    println("  [PASS] ADV 1.1: 2 ** 30 == 1073741824")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 1.1: 2 ** 30 failed (got " + p_30.to_str() + ")")
  @end

  total = total + 1
  p_00 = 0 ** 0
  @if p_00 == 1
    println("  [PASS] ADV 1.2: 0 ** 0 == 1")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 1.2: 0 ** 0 failed")
  @end

  total = total + 1
  p_10_0 = 10 ** 0
  @if p_10_0 == 1
    println("  [PASS] ADV 1.3: 10 ** 0 == 1")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 1.3: 10 ** 0 failed")
  @end

  @! STRICT ASSERTION FOR 0 ** 10 (Fixes previous unconditional pass branch defect)
  total = total + 1
  p_0_10 = 0 ** 10
  @if p_0_10 == 0
    println("  [PASS] ADV 1.4: 0 ** 10 == 0 (strict single assertion branch)")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 1.4: 0 ** 10 failed (got " + p_0_10.to_str() + ")")
  @end

  total = total + 1
  cmp_neg = (0 - 1000000) <=> 1000000
  @if cmp_neg == 0 - 1
    println("  [PASS] ADV 1.5: (-1M) <=> (+1M) == -1")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 1.5: Spaceship negative vs positive failed")
  @end

  total = total + 1
  cmp_pos = 1000000 <=> (0 - 1000000)
  @if cmp_pos == 1
    println("  [PASS] ADV 1.6: (+1M) <=> (-1M) == 1")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 1.6: Spaceship positive vs negative failed")
  @end

  total = total + 1
  cmp_zero = 0 <=> 0
  @if cmp_zero == 0
    println("  [PASS] ADV 1.7: 0 <=> 0 == 0")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 1.7: Spaceship zero vs zero failed")
  @end

  total = total + 1
  x_large = 99999 ^^ 0
  @if x_large == 1
    println("  [PASS] ADV 1.8: 99999 ^^ 0 == 1")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 1.8: XOR large non-zero vs 0 failed")
  @end

  total = total + 1
  x_same = 8888 ^^ 8888
  @if x_same == 0
    println("  [PASS] ADV 1.9: 8888 ^^ 8888 == 0")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 1.9: XOR large non-zero vs large non-zero failed")
  @end

  @! ----------------------------------------------------------------------
  @! Section 2: Deep Recursive Macro Expansion Stress (10 Tiers)
  @! ----------------------------------------------------------------------
  println("▶ Adv Section 2: Deep Recursive Macro Expansion Stress (10 Tiers)")

  total = total + 1
  acc = 0
  MACRO_L1
  @if acc == 777
    println("  [PASS] ADV 2.1: 10-level recursive macro expansion (MACRO_L1 -> ... -> acc=777)")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 2.1: Recursive macro expansion failed (got acc=" + acc.to_str() + ")")
  @end

  @! ----------------------------------------------------------------------
  @! Section 3: Large Workload & High-Iteration Churn with Dynamic Grammar
  @! ----------------------------------------------------------------------
  println("▶ Adv Section 3: Large Workload & High-Iteration Churn")

  total = total + 1
  churn_res = test_large_spanish_workload(1000)
  @if churn_res == 0 - 500
    println("  [PASS] ADV 3.1: 1,000-iteration alternating accumulator in Spanish loop (acc == -500)")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 3.1: Large workload failed (got " + churn_res.to_str() + ")")
  @end

  @! ----------------------------------------------------------------------
  @! Section 4: Deeply Nested Dynamic Control Flow (6 Levels)
  @! ----------------------------------------------------------------------
  println("▶ Adv Section 4: Deeply Nested Dynamic Control Flow")

  total = total + 1
  d6 = test_deep_nested_spanish(250)
  d1 = test_deep_nested_spanish(5)
  @if d6 == 6 && d1 == 1
    println("  [PASS] ADV 4.1: 6-level nested Spanish 'si ... fin' blocks (d6=6, d1=1)")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 4.1: Nested control flow failed (d6=" + d6.to_str() + ", d1=" + d1.to_str() + ")")
  @end

  @! ----------------------------------------------------------------------
  @! Section 5: Exponentiation Tower & Associativity Stress
  @! ----------------------------------------------------------------------
  println("▶ Adv Section 5: Exponentiation Tower & Associativity Stress")

  total = total + 1
  tower = 2 ** 2 ** 2 ** 2
  @if tower == 65536
    println("  [PASS] ADV 5.1: Exponentiation tower 2 ** 2 ** 2 ** 2 == 65536 (2^(2^(2^2)))")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 5.1: Exponentiation tower failed (got " + tower.to_str() + ")")
  @end

  total = total + 1
  prec_mixed = (2 ** 4 <=> 16) + (2 ** 3 <=> 10) + (2 ** 4 <=> 10)
  @! 2**4<=>16 is 0, 2**3<=>10 is -1, 2**4<=>10 is +1 -> 0 + (-1) + 1 = 0
  @if prec_mixed == 0
    println("  [PASS] ADV 5.2: Complex precedence resolution (2**4<=>16) + (2**3<=>10) + (2**4<=>10) == 0")
    passed = passed + 1
  @else
    println("  [FAIL] ADV 5.2: Complex precedence resolution failed")
  @end

  println("-----------------------------------------------------------------")
  println("  Summary: " + passed.to_str() + "/" + total.to_str() + " adversarial assertions passed.")

  @if passed == total && total > 0
    println("🎉 ALL ADVERSARIAL INFINITY SYNTAX TESTS PASSED!")
    return 0
  @else
    println("❌ SOME ADVERSARIAL INFINITY SYNTAX TESTS FAILED!")
    return 1
  @end
@end
