@! ============================================================================
@! ADVERSARIAL STRESS TEST: OPERATOR PRECEDENCE & SHORT-CIRCUITING (test_adv_operator_precedence.maya)
@! Tests:
@! 1. Complex arithmetic precedence and left-associativity
@! 2. Bitwise operator precedence and bit manipulation (&, |, ^, <<, >>)
@! 3. Boolean short-circuit evaluation guarantees with side-effect tracking
@! 4. Pipe operator (|>) chaining, argument passing, and expression composition
@! ============================================================================

@fn track_true(counter)
  counter[0] = counter[0] + 1
  return 1
@end

@fn track_false(counter)
  counter[0] = counter[0] + 1
  return 0
@end

@fn add_five(x)
  return x + 5
@end

@fn mult_two(x)
  return x * 2
@end

@fn scale_and_offset(x, scale, offset)
  return x * scale + offset
@end

@fn main()
  println("=================================================================")
  println("ADVERSARIAL SUITE: OPERATORS, PRECEDENCE & SHORT-CIRCUITING")
  println("=================================================================")

  let passed = 0
  let total = 0

  @! -------------------------------------------------------------
  @! 1. Arithmetic Precedence & Associativity
  @! -------------------------------------------------------------
  println("▶ Section 1: Arithmetic Precedence & Associativity")

  total = total + 1
  @! 10 + 20 * 3 - 40 / 5 % 3 = 10 + 60 - (8 % 3) = 70 - 2 = 68
  let arith1 = 10 + 20 * 3 - 40 / 5 % 3
  @if arith1 == 68
    passed = passed + 1
    println("  [PASS] OP1.1: Multi-operator arithmetic precedence (*, /, % over +, -) == 68")
  @else
    println("  [FAIL] OP1.1: Arithmetic precedence failure")
  @end

  total = total + 1
  @! Left associativity: 100 - 50 - 20 = (100 - 50) - 20 = 30
  let arith_sub = 100 - 50 - 20
  @! Left associativity: 24 / 4 / 2 = (24 / 4) / 2 = 3
  let arith_div = 24 / 4 / 2
  @if arith_sub == 30 && arith_div == 3
    passed = passed + 1
    println("  [PASS] OP1.2: Left-associativity of subtraction and division (100-50-20=30, 24/4/2=3)")
  @else
    println("  [FAIL] OP1.2: Left-associativity failure")
  @end

  total = total + 1
  @! Parentheses override: (10 + 20) * (3 - 1) = 30 * 2 = 60
  let arith_paren = (10 + 20) * (3 - 1)
  @if arith_paren == 60
    passed = passed + 1
    println("  [PASS] OP1.3: Parentheses precedence override == 60")
  @else
    println("  [FAIL] OP1.3: Parentheses override failure")
  @end

  @! -------------------------------------------------------------
  @! 2. Bitwise Operators & Precedence
  @! -------------------------------------------------------------
  println("▶ Section 2: Bitwise Operators & Precedence")

  total = total + 1
  @! Shift has lower precedence than +: pow2(2) + 1 = pow2(3) = 8
  let shift_add = pow2(2) + 1
  @! 1 + 2 << 2 = 3 << 2 = 12
  let add_shift = 1 + 2 << 2
  @if shift_add == 8 && add_shift == 12
    passed = passed + 1
    println("  [PASS] OP2.1: Addition precedence over bitwise shifts (pow2(2)+1=8, 1+2<<2=12)")
  @else
    println("  [FAIL] OP2.1: Shift precedence failure")
  @end

  total = total + 1
  let bw_and = 0xAA & 0x0F
  let bw_or = 0xA0 | 0x0B
  let bw_xor = 0xAA ^ 0x55
  let bw_shr = 256 >> 4
  @if bw_and == 0x0A && bw_or == 0xAB && bw_xor == 0xFF && bw_shr == 16
    passed = passed + 1
    println("  [PASS] OP2.2: Bitwise AND, OR, XOR, SHR logic evaluations")
  @else
    println("  [FAIL] OP2.2: Bitwise operations failure")
  @end

  @! -------------------------------------------------------------
  @! 3. Boolean Short-Circuiting Verification
  @! -------------------------------------------------------------
  println("▶ Section 3: Boolean Short-Circuiting Verification")

  total = total + 1
  let counter = [0]
  @! 0 && track_true(counter) -> RHS must NOT be evaluated
  let res_and_short = 0 && track_true(counter)
  @if res_and_short == 0 && counter[0] == 0
    passed = passed + 1
    println("  [PASS] OP3.1: Logical AND short-circuiting: false && effect() does not evaluate RHS")
  @else
    println("  [FAIL] OP3.1: AND short-circuiting evaluated RHS")
  @end

  total = total + 1
  @! 1 && track_true(counter) -> RHS MUST be evaluated
  let res_and_eval = 1 && track_true(counter)
  @if res_and_eval == 1 && counter[0] == 1
    passed = passed + 1
    println("  [PASS] OP3.2: Logical AND evaluation: true && effect() evaluates RHS")
  @else
    println("  [FAIL] OP3.2: AND evaluation failure")
  @end

  total = total + 1
  @! 1 || track_true(counter) -> RHS must NOT be evaluated
  let res_or_short = 1 || track_true(counter)
  @if res_or_short == 1 && counter[0] == 1
    passed = passed + 1
    println("  [PASS] OP3.3: Logical OR short-circuiting: true || effect() does not evaluate RHS")
  @else
    println("  [FAIL] OP3.3: OR short-circuiting evaluated RHS")
  @end

  total = total + 1
  @! 0 || track_true(counter) -> RHS MUST be evaluated
  let res_or_eval = 0 || track_true(counter)
  @if res_or_eval == 1 && counter[0] == 2
    passed = passed + 1
    println("  [PASS] OP3.4: Logical OR evaluation: false || effect() evaluates RHS")
  @else
    println("  [FAIL] OP3.4: OR evaluation failure")
  @end

  total = total + 1
  @! Nested complex short circuit: (0 && track_true(counter)) || (1 && track_false(counter))
  @! Left side does not call track_true (counter remains 2)
  @! Left side is 0, so || evaluates RHS: (1 && track_false(counter)), which calls track_false (counter becomes 3)
  let res_complex = (0 && track_true(counter)) || (1 && track_false(counter))
  @if res_complex == 0 && counter[0] == 3
    passed = passed + 1
    println("  [PASS] OP3.5: Nested short-circuit logic: (0 && e) || (1 && e) evaluated exactly once")
  @else
    println("  [FAIL] OP3.5: Nested short-circuit logic failure")
  @end

  @! -------------------------------------------------------------
  @! 4. Pipe Operator (|>) Stress Testing
  @! -------------------------------------------------------------
  println("▶ Section 4: Pipe Operator (|>)")

  total = total + 1
  @! 10 |> add_five -> add_five(10) = 15
  let pipe_unary = 10 |> add_five
  @if pipe_unary == 15
    passed = passed + 1
    println("  [PASS] OP4.1: Unary pipe operator (10 |> add_five == 15)")
  @else
    println("  [FAIL] OP4.1: Unary pipe operator failure")
  @end

  total = total + 1
  @! 10 |> add_five |> mult_two |> add_five = ((10 + 5) * 2) + 5 = 35
  let pipe_chain = 10 |> add_five |> mult_two |> add_five
  @if pipe_chain == 35
    passed = passed + 1
    println("  [PASS] OP4.2: Chained pipe operator (10 |> add_five |> mult_two |> add_five == 35)")
  @else
    println("  [FAIL] OP4.2: Chained pipe operator failure")
  @end

  total = total + 1
  @! 10 |> scale_and_offset(3, 7) -> scale_and_offset(10, 3, 7) = 10 * 3 + 7 = 37
  let pipe_multi_arg = 10 |> scale_and_offset(3, 7)
  @if pipe_multi_arg == 37
    passed = passed + 1
    println("  [PASS] OP4.3: Multi-argument pipe operator (10 |> scale_and_offset(3, 7) == 37)")
  @else
    println("  [FAIL] OP4.3: Multi-argument pipe failure")
  @end

  total = total + 1
  @! Precedence: (2 + 3) * 2 |> add_five = 10 |> add_five = 15
  let pipe_expr = (2 + 3) * 2 |> add_five
  @if pipe_expr == 15
    passed = passed + 1
    println("  [PASS] OP4.4: Pipe operator with complex expression on LHS == 15")
  @else
    println("  [FAIL] OP4.4: Pipe LHS expression failure")
  @end

  println("=================================================================")
  println("OPERATORS & PRECEDENCE TESTS SUMMARY: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")

  @if passed == total
    return 0
  @else
    return 1
  @end
@end
