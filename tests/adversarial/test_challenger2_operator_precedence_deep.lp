@! ============================================================================
@! CHALLENGER 2 ADVERSARIAL TEST SUITE: OPERATOR PRECEDENCE & PIPELINE CHAINS
@! File: tests/adversarial/test_challenger2_operator_precedence_deep.maya
@! Architecture: Pure Maya Custom Infix/Prefix/Pipeline Operator Engine
@! ============================================================================

@custom_op "**" "INFIX_RIGHT" 80 "maya_power" ;
@custom_op "<=>" "INFIX_LEFT" 30 "maya_spaceship" ;
@custom_op "^^" "INFIX_LEFT" 25 "maya_xor" ;
@custom_op "~=" "INFIX_LEFT" 20 "maya_approx_eq" ;

@fn maya_power(base, exp)
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

@fn maya_spaceship(a, b)
  @if a < b
    return 0 - 1
  @elif a > b
    return 1
  @else
    return 0
  @end
@end

@fn maya_xor(a, b)
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

@fn maya_approx_eq(a, b)
  diff = a - b
  @if diff < 0
    diff = 0 - diff
  @end
  @if diff <= 5
    return 1
  @else
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("  CHALLENGER 2: OPERATOR PRECEDENCE & ASSOCIATIVITY TEST SUITE")
  println("=================================================================")

  passed = 0
  total = 0

  @! Test 1: Right-Associative Exponentiation (2 ** 2 ** 3)
  @! In right-associative power: 2 ** (2 ** 3) = 2 ** 8 = 256
  total = total + 1
  pow_right = 2 ** 2 ** 3
  @if pow_right == 256
    println("  [PASS] C2.PREC.1: Right-associative exponentiation (2 ** 2 ** 3 == 256)")
    passed = passed + 1
  @else
    println("  [FAIL] C2.PREC.1: Right-associative exponentiation failed")
  @end

  @! Test 2: Precedence Binding: Multiplication vs Exponentiation (2 * 3 ** 2)
  @! Power (prec 80) binds tighter than Star (prec 10): 2 * (3 ** 2) = 2 * 9 = 18
  total = total + 1
  mul_pow = 2 * 3 ** 2
  @if mul_pow == 18
    println("  [PASS] C2.PREC.2: Exponentiation binds tighter than multiplication (2 * 3 ** 2 == 18)")
    passed = passed + 1
  @else
    println("  [FAIL] C2.PREC.2: Multiplication vs exponentiation binding failed")
  @end

  @! Test 3: Precedence Binding: Addition vs Exponentiation (5 + 2 ** 3)
  @! Power (prec 80) binds tighter than Plus (prec 9): 5 + 8 = 13
  total = total + 1
  add_pow = 5 + 2 ** 3
  @if add_pow == 13
    println("  [PASS] C2.PREC.3: Exponentiation binds tighter than addition (5 + 2 ** 3 == 13)")
    passed = passed + 1
  @else
    println("  [FAIL] C2.PREC.3: Addition vs exponentiation binding failed")
  @end

  @! Test 4: Spaceship Operator Compound Expressions
  total = total + 1
  s1 = 10 <=> 5
  s2 = 5 <=> 10
  s3 = 10 <=> 10
  cmp_sum = s1 + s2 + s3
  @! 1 + (-1) + 0 = 0
  @if cmp_sum == 0
    println("  [PASS] C2.PREC.4: Spaceship operator evaluations sum to 0 (1 + -1 + 0 == 0)")
    passed = passed + 1
  @else
    println("  [FAIL] C2.PREC.4: Spaceship operator evaluations failed")
  @end

  @! Test 5: Logical XOR Chain Associativity (1 ^^ 0 ^^ 1)
  @! (1 ^^ 0) ^^ 1 = 1 ^^ 1 = 0
  total = total + 1
  xor_chain = 1 ^^ 0 ^^ 1
  @if xor_chain == 0
    println("  [PASS] C2.PREC.5: Chained XOR operator evaluation (1 ^^ 0 ^^ 1 == 0)")
    passed = passed + 1
  @else
    println("  [FAIL] C2.PREC.5: Chained XOR evaluation failed")
  @end

  @! Test 6: Custom Approx Equals (~=) Tolerance Operator
  total = total + 1
  app_yes = 100 ~= 104
  app_no = 100 ~= 120
  @if app_yes == 1 && app_no == 0
    println("  [PASS] C2.PREC.6: Custom tolerance approx equals (100 ~= 104 -> 1, 100 ~= 120 -> 0)")
    passed = passed + 1
  @else
    println("  [FAIL] C2.PREC.6: Approx equals operator failed")
  @end

  println("-----------------------------------------------------------------")
  println("  Summary: " + passed.to_str() + "/" + total.to_str() + " assertions passed.")

  @if passed == total && total > 0
    println("🏆 VERDICT: ALL OPERATOR PRECEDENCE TESTS PASSED!")
    return 0
  @else
    println("💥 VERDICT: SOME OPERATOR PRECEDENCE TESTS FAILED!")
    return 1
  @end
@end
