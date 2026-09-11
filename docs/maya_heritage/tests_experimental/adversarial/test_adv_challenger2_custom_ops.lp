// @! ADVERSARIAL STRESS: CUSTOM OPERATORS, RIGHT-ASSOCIATIVITY & PRECEDENCE
@custom_op "**" "INFIX_RIGHT" 80 "adv_power" ;
@custom_op "<=>" "INFIX_LEFT" 30 "adv_spaceship" ;
@custom_op "^^" "INFIX_LEFT" 25 "adv_xor" ;
@custom_op "~=" "INFIX_LEFT" 20 "adv_approx_eq" ;

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
  @end
  @if a > b
    return 1
  @end
  return 0
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

@fn adv_approx_eq(a, b)
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
  passed = 0
  total = 0

  @! Test 1: Right-associativity 2 ** 3 ** 2 == 512
  total = total + 1
  v1 = 2 ** 3 ** 2
  @if v1 == 512
    passed = passed + 1
  @end

  @! Test 2: 4-tower right-associativity 2 ** 2 ** 2 ** 2 == 65536
  total = total + 1
  v2 = 2 ** 2 ** 2 ** 2
  @if v2 == 65536
    passed = passed + 1
  @end

  @! Test 3: Precedence climbing with arithmetic 1 + 2 * 3 ** 2 == 19
  total = total + 1
  v3 = 1 + 2 * 3 ** 2
  @if v3 == 19
    passed = passed + 1
  @end

  @! Test 4: Precedence 2 ** 3 * 4 + 1 == 33
  total = total + 1
  v4 = 2 ** 3 * 4 + 1
  @if v4 == 33
    passed = passed + 1
  @end

  @! Test 5: Spaceship operator <, ==, >
  total = total + 1
  s1 = 10 <=> 20
  s2 = 20 <=> 20
  s3 = 30 <=> 20
  @if s1 == 0 - 1 && s2 == 0 && s3 == 1
    passed = passed + 1
  @end

  @! Test 6: XOR operator
  total = total + 1
  x1 = 1 ^^ 0
  x2 = 1 ^^ 1
  x3 = 0 ^^ 0
  @if x1 == 1 && x2 == 0 && x3 == 0
    passed = passed + 1
  @end

  @! Test 7: Approximate equality ~=
  total = total + 1
  a1 = 100 ~= 104
  a2 = 100 ~= 110
  @if a1 == 1 && a2 == 0
    passed = passed + 1
  @end

  println("Custom Ops Passed: " + passed.to_str() + " / " + total.to_str())
  @if passed == total
    return 0
  @else
    return 1
  @end
@end
