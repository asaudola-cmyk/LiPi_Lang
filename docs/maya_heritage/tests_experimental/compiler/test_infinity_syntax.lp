// @! ============================================================================
// @! TEST SUITE: INFINITY SYNTAX & DYNAMIC GRAMMAR RULE ENGINE
// @! File: tests/compiler/test_infinity_syntax.maya
// @! Architecture: Pure Maya Sovereign Dynamic Metaprogramming
// @!
// @! // @! RUN: %maya %file -o %out && %out
// @! // @! EXPECT_CONTAINS: ALL INFINITY SYNTAX TESTS PASSED
// @! // @! EXPECT_EXIT: 0
// @! ============================================================================

@! Sovereign Infinity Rules
@infinity_rule "mientras" => "@while" ;
@infinity_rule "si" => "@if" ;
@infinity_rule "sino" => "@else" ;
@infinity_rule "retornar" => "return" ;
@infinity_rule "fin" => "@end" ;
@infinity_rule "forever" => "@while 1" ;
@infinity_rule "done" => "@end" ;
@infinity_rule "UNLESS" => "@if 0 ==" ;
@infinity_rule "CUANDO" => "si" ;
@infinity_rule "TERMINAR" => "fin" ;
@infinity_rule "ACCUM_10" => "acc = acc + 10 ;" ;

@custom_op "**" "INFIX_RIGHT" 80 "maya_power" ;
@custom_op "<=>" "INFIX_LEFT" 30 "maya_spaceship" ;
@custom_op "^^" "INFIX_LEFT" 25 "maya_xor" ;

@! Mathematical helper functions for custom operators
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

@fn spanish_fibonacci(n)
  si n <= 0
    retornar 0
  fin
  si n == 1
    retornar 1
  fin
  a = 0
  b = 1
  i = 2
  mientras i <= n
    nxt = a + b
    a = b
    b = nxt
    i = i + 1
  fin
  retornar b
fin

@fn spanish_collatz_steps(start_val)
  steps = 0
  curr = start_val
  mientras curr > 1
    si (curr % 2) == 0
      curr = curr / 2
    sino
      curr = curr * 3 + 1
    fin
    steps = steps + 1
  fin
  retornar steps
fin

@fn test_forever_search(target)
  val = 1
  forever
    si val >= target
      break
    fin
    val = val * 2
  done
  retornar val
fin

@fn test_unless_branch(cond)
  res = 0
  UNLESS cond
    res = 100
  fin
  retornar res
fin

@fn test_chained_rules(val)
  out = 0
  CUANDO val > 50
    out = val * 2
  TERMINAR
  retornar out
fin

@fn main()
  println("=================================================================")
  println("  MAYA INFINITY SYNTAX & DYNAMIC GRAMMAR TEST SUITE")
  println("=================================================================")

  passed = 0
  total = 0

  @! ----------------------------------------------------------------------
  @! Section 1: Custom Operator Precedence and Associativity
  @! ----------------------------------------------------------------------
  println("▶ Section 1: Custom Operator Precedence and Associativity")

  total = total + 1
  p1 = 2 ** 8
  @if p1 == 256
    println("  [PASS] T1.1: 2 ** 8 == 256")
    passed = passed + 1
  @else
    println("  [FAIL] T1.1: 2 ** 8 == 256 (got " + p1.to_str() + ")")
  @end

  total = total + 1
  p2 = 3 ** 4
  @if p2 == 81
    println("  [PASS] T1.2: 3 ** 4 == 81")
    passed = passed + 1
  @else
    println("  [FAIL] T1.2: 3 ** 4 == 81 (got " + p2.to_str() + ")")
  @end

  total = total + 1
  p3 = 5 ** 0
  @if p3 == 1
    println("  [PASS] T1.3: 5 ** 0 == 1")
    passed = passed + 1
  @else
    println("  [FAIL] T1.3: 5 ** 0 == 1 (got " + p3.to_str() + ")")
  @end

  total = total + 1
  p_assoc = 2 ** 3 ** 2
  @if p_assoc == 512
    println("  [PASS] T1.4: Right-associativity 2 ** 3 ** 2 == 512 (2^(3^2))")
    passed = passed + 1
  @else
    println("  [FAIL] T1.4: Right-associativity 2 ** 3 ** 2 == 512 (got " + p_assoc.to_str() + ")")
  @end

  total = total + 1
  cmp1 = 10 <=> 20
  cmp2 = 20 <=> 20
  cmp3 = 30 <=> 20
  @if cmp1 == 0 - 1 && cmp2 == 0 && cmp3 == 1
    println("  [PASS] T1.5: Spaceship 10<=>20(-1), 20<=>20(0), 30<=>20(1)")
    passed = passed + 1
  @else
    println("  [FAIL] T1.5: Spaceship operator failed")
  @end

  total = total + 1
  x1 = 1 ^^ 0
  x2 = 1 ^^ 1
  x3 = 0 ^^ 0
  x4 = 0 ^^ 1
  @if x1 == 1 && x2 == 0 && x3 == 0 && x4 == 1
    println("  [PASS] T1.6: XOR operator 1^^0(1), 1^^1(0), 0^^0(0), 0^^1(1)")
    passed = passed + 1
  @else
    println("  [FAIL] T1.6: XOR operator failed")
  @end

  total = total + 1
  mixed_math = 1 + 2 ** 3 * 4
  @if mixed_math == 33
    println("  [PASS] T1.7: Mixed precedence 1 + 2 ** 3 * 4 == 33 (1 + 8 * 4)")
    passed = passed + 1
  @else
    println("  [FAIL] T1.7: Mixed precedence failed (got " + mixed_math.to_str() + ")")
  @end

  @! ----------------------------------------------------------------------
  @! Section 2: Spanish Keyword Aliasing Control Flow
  @! ----------------------------------------------------------------------
  println("▶ Section 2: Spanish Keyword Aliasing Control Flow")

  total = total + 1
  fib_10 = spanish_fibonacci(10)
  @if fib_10 == 55
    println("  [PASS] T2.1: spanish_fibonacci(10) == 55 (using mientras/si/fin/retornar)")
    passed = passed + 1
  @else
    println("  [FAIL] T2.1: spanish_fibonacci failed")
  @end

  total = total + 1
  collatz_6 = spanish_collatz_steps(6)
  @if collatz_6 == 8
    println("  [PASS] T2.2: spanish_collatz_steps(6) == 8 (using si/sino/mientras/fin)")
    passed = passed + 1
  @else
    println("  [FAIL] T2.2: spanish_collatz_steps failed")
  @end

  @! ----------------------------------------------------------------------
  @! Section 3: Custom Loop Grammar ('forever ... done')
  @! ----------------------------------------------------------------------
  println("▶ Section 3: Custom Loop Grammar ('forever ... done')")

  total = total + 1
  search_res = test_forever_search(100)
  @if search_res == 128
    println("  [PASS] T3.1: test_forever_search(100) == 128 (using forever ... done)")
    passed = passed + 1
  @else
    println("  [FAIL] T3.1: test_forever_search failed")
  @end

  @! ----------------------------------------------------------------------
  @! Section 4: Inverted Conditionals ('UNLESS')
  @! ----------------------------------------------------------------------
  println("▶ Section 4: Inverted Conditionals ('UNLESS')")

  total = total + 1
  u0 = test_unless_branch(0)
  u1 = test_unless_branch(1)
  u42 = test_unless_branch(42)
  @if u0 == 100 && u1 == 0 && u42 == 0
    println("  [PASS] T4.1: UNLESS 0 -> 100, UNLESS 1 -> 0, UNLESS 42 -> 0")
    passed = passed + 1
  @else
    println("  [FAIL] T4.1: Inverted conditional failed")
  @end

  @! ----------------------------------------------------------------------
  @! Section 5: Pattern & Statement Macros
  @! ----------------------------------------------------------------------
  println("▶ Section 5: Pattern & Statement Macros")

  total = total + 1
  acc = 0
  ACCUM_10
  ACCUM_10
  ACCUM_10
  @if acc == 30
    println("  [PASS] T5.1: Multi-invocation statement macro ACCUM_10 (acc=30)")
    passed = passed + 1
  @else
    println("  [FAIL] T5.1: Statement macro ACCUM_10 failed")
  @end

  @! ----------------------------------------------------------------------
  @! Section 6: Dynamic Rule Chaining
  @! ----------------------------------------------------------------------
  println("▶ Section 6: Dynamic Rule Chaining")

  total = total + 1
  c_hit = test_chained_rules(75)
  c_miss = test_chained_rules(25)
  @if c_hit == 150 && c_miss == 0
    println("  [PASS] T6.1: Chained rules CUANDO -> si, TERMINAR -> fin (hit=150, miss=0)")
    passed = passed + 1
  @else
    println("  [FAIL] T6.1: Dynamic rule chaining failed")
  @end

  println("-----------------------------------------------------------------")
  println("  Summary: " + passed.to_str() + "/" + total.to_str() + " assertions passed.")

  @if passed == total && total > 0
    println("🎉 ALL INFINITY SYNTAX TESTS PASSED!")
    return 0
  @else
    println("❌ SOME INFINITY SYNTAX TESTS FAILED!")
    return 1
  @end
@end
