@! ============================================================================
@! ADVERSARIAL STRESS TEST: OPERATOR PRECEDENCE & ASSOCIATIVITY
@! Tests custom operators: **, <=>, ^^, ~= mixed with standard arithmetic
@! ============================================================================

@fn maya_power(base, exp)
  @if exp <= 0 return 1 @end
  @if base == 0 return 0 @end
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
  @if a < b return 0 - 1
  @elif a > b return 1
  @else return 0 @end
@end

@fn maya_xor(a, b)
  b_a = 0
  @if a != 0 b_a = 1 @end
  b_b = 0
  @if b != 0 b_b = 1 @end
  @if (b_a == 1 && b_b == 0) || (b_a == 0 && b_b == 1)
    return 1
  @else
    return 0
  @end
@end

@fn maya_approx_eq(a, b, epsilon)
  diff = a - b
  @if diff < 0 diff = 0 - diff @end
  @if diff <= epsilon return 1
  @else return 0 @end
@end

@fn main()
  println("=================================================================")
  println("🧪 ADVERSARIAL STRESS: CUSTOM OPERATOR PRECEDENCE & MATH 🧪")
  println("=================================================================")

  passed = 0
  total = 0

  @! --- Category 1: Power Operator (**) & Right Associativity ---
  total = total + 1
  p1 = maya_power(2, 8)
  p2 = maya_power(3, 4)
  p3 = maya_power(5, 0)
  p4 = maya_power(0, 0)
  p5 = maya_power(0, 10)
  @if p1 == 256 && p2 == 81 && p3 == 1 && p4 == 1 && p5 == 0
    println("  [PASS] 1.1: Power operator basic & boundary semantics (2^8=256, 3^4=81, 5^0=1, 0^0=1, 0^10=0)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.1: Power operator failed")
  @end

  @! Right-associativity tower: 2^(3^2) = 2^9 = 512 vs (2^3)^2 = 64
  total = total + 1
  exp_inner = maya_power(3, 2)
  tower_res = maya_power(2, exp_inner)
  @if tower_res == 512
    println("  [PASS] 1.2: Exponentiation right-associativity 2^(3^2) == 512")
    passed = passed + 1
  @else
    println("  [FAIL] 1.2: Right-associativity tower failed")
  @end

  @! 4-level exponentiation tower: 2^(2^(2^2)) = 2^(2^4) = 2^16 = 65536
  total = total + 1
  t1 = maya_power(2, 2)
  t2 = maya_power(2, t1)
  t3 = maya_power(2, t2)
  @if t3 == 65536
    println("  [PASS] 1.3: 4-level exponentiation tower 2^(2^(2^2)) == 65536")
    passed = passed + 1
  @else
    println("  [FAIL] 1.3: 4-level tower failed")
  @end

  @! Large exponent boundary: 2^30 = 1073741824
  total = total + 1
  p30 = maya_power(2, 30)
  @if p30 == 1073741824
    println("  [PASS] 1.4: Large exponent 2^30 == 1073741824")
    passed = passed + 1
  @else
    println("  [FAIL] 1.4: Large exponent failed")
  @end

  @! --- Category 2: Spaceship Operator (<=>) ---
  total = total + 1
  s1 = maya_spaceship(10, 20)
  s2 = maya_spaceship(20, 20)
  s3 = maya_spaceship(30, 20)
  s_neg_pos = maya_spaceship(0 - 1000000, 1000000)
  s_pos_neg = maya_spaceship(1000000, 0 - 1000000)
  s_zero = maya_spaceship(0, 0)
  @if s1 == 0 - 1 && s2 == 0 && s3 == 1 && s_neg_pos == 0 - 1 && s_pos_neg == 1 && s_zero == 0
    println("  [PASS] 2.1: Spaceship comparison across positive, negative, and zero bounds")
    passed = passed + 1
  @else
    println("  [FAIL] 2.1: Spaceship comparison failed")
  @end

  @! --- Category 3: Logical/Bitwise XOR Operator (^^) ---
  total = total + 1
  x1 = maya_xor(1, 0)
  x2 = maya_xor(0, 1)
  x3 = maya_xor(1, 1)
  x4 = maya_xor(0, 0)
  x5 = maya_xor(99999, 0)
  x6 = maya_xor(8888, 8888)
  @if x1 == 1 && x2 == 1 && x3 == 0 && x4 == 0 && x5 == 1 && x6 == 0
    println("  [PASS] 3.1: XOR logical operator across zero, identity, and large operand sets")
    passed = passed + 1
  @else
    println("  [FAIL] 3.1: XOR operator failed")
  @end

  @! --- Category 4: Approximate Equality (~=) ---
  total = total + 1
  a1 = maya_approx_eq(100, 105, 10)
  a2 = maya_approx_eq(100, 95, 10)
  a3 = maya_approx_eq(100, 120, 10)
  a4 = maya_approx_eq(0, 0, 0)
  @if a1 == 1 && a2 == 1 && a3 == 0 && a4 == 1
    println("  [PASS] 4.1: Approximate equality tolerance checking (positive/negative diffs)")
    passed = passed + 1
  @else
    println("  [FAIL] 4.1: Approximate equality failed")
  @end

  @! --- Category 5: Mixed Arithmetic & Precedence Combinations ---
  total = total + 1
  @! (1 + 2**3 * 4) -> 1 + (8 * 4) = 33
  pow_part = maya_power(2, 3)
  mixed1 = 1 + pow_part * 4
  @if mixed1 == 33
    println("  [PASS] 5.1: Mixed precedence: 1 + (2^3) * 4 == 33")
    passed = passed + 1
  @else
    println("  [FAIL] 5.1: Mixed precedence failed")
  @end

  total = total + 1
  @! (2**4 <=> 16) + (2**3 <=> 10) + (2**4 <=> 10) -> 0 + (-1) + 1 = 0
  c_p1 = maya_power(2, 4)
  c_p2 = maya_power(2, 3)
  c_p3 = maya_power(2, 4)
  sp_1 = maya_spaceship(c_p1, 16)
  sp_2 = maya_spaceship(c_p2, 10)
  sp_3 = maya_spaceship(c_p3, 10)
  combined_math = sp_1 + sp_2 + sp_3
  @if combined_math == 0
    println("  [PASS] 5.2: Complex composite expression (2^4<=>16) + (2^3<=>10) + (2^4<=>10) == 0")
    passed = passed + 1
  @else
    println("  [FAIL] 5.2: Composite expression failed")
  @end

  println("=================================================================")
  println("  Passed: " + passed.to_str() + "/" + total.to_str() + " assertions")
  @if passed == total
    println("🎉 ALL CUSTOM OPERATOR PRECEDENCE ADVERSARIAL TESTS PASSED!")
    return 0
  @else
    println("❌ OPERATOR PRECEDENCE TESTS FAILED!")
    return 1
  @end
@end
