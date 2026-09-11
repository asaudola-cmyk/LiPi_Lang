// @! RUN: %maya %file -o %out && %out
// @! EXPECT_CONTAINS: ALL ADVERSARIAL TESTS PASSED
// @! EXPECT_EXIT: 0

// @! ============================================================================
// @! ADVERSARIAL EMPIRICAL EVALUATION SUITE: INFINITY SYNTAX ENGINE (M2)
// @! Challenger: Challenger 2 (Empirical Adversarial Review)
// @! ============================================================================

@infinity_rule "mientras" => "@while" ;
@infinity_rule "si" => "@if" ;
@infinity_rule "retornar" => "return" ;
@infinity_rule "fin" => "@end" ;
@infinity_rule "forever" => "@while 1" ;
@infinity_rule "done" => "@end" ;
@custom_op "**" "INFIX_RIGHT" 80 "maya_power" ;
@custom_op "<=>" "INFIX_LEFT" 30 "maya_spaceship" ;
@custom_op "^^" "INFIX_LEFT" 25 "maya_xor" ;

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

@fn test_adversarial_keywords()
  count = 0
  mientras count < 5
    count = count + 1
  fin
  si count == 5
    retornar 1
  fin
  retornar 0
@end

@fn test_custom_ops()
  val = 2 ** 3
  si val == 8
    retornar 1
  fin
  retornar 0
@end

@fn main()
  println("=================================================================")
  println("  CHALLENGER 2: ADVERSARIAL INFINITY SYNTAX EVALUATION")
  println("=================================================================")
  
  failures = 0
  
  println("Test 1: Keyword redefinition (mientras/si/retornar/fin)...")
  r1 = test_adversarial_keywords()
  @if r1 == 1
    println("  [PASS] Test 1: Keywords dynamically rewritten")
  @else
    println("  [FAIL] Test 1: Keywords NOT rewritten by compiler")
    failures = failures + 1
  @end
  
  println("Test 2: Custom operator evaluation (2 ** 3 == 8)...")
  r2 = test_custom_ops()
  @if r2 == 1
    println("  [PASS] Test 2: Custom operators lowered and evaluated")
  @else
    println("  [FAIL] Test 2: Custom operators NOT lowered by compiler")
    failures = failures + 1
  @end
  
  @if failures == 0
    println("ALL ADVERSARIAL TESTS PASSED")
    return 0
  @else
    println("ADVERSARIAL SUITE DETECTED " + failures.to_str() + " CRITICAL DEFECTS")
    return 1
  @end
@end
