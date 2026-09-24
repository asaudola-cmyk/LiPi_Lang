import "packages/math_extra/src/lib"

@fn main()
  println("--- Math Extra Test Suite ---")
  
  // 1. Complex Arithmetic Tests
  c1 = { real: 5, imag: 7 }
  c2 = { real: 2, imag: 3 }
  
  c_add = complex_add(c1, c2)
  @if c_add.real != 7 || c_add.imag != 10
    println("FAIL: complex_add")
    return 1
  @end
  println("PASS: complex_add")

  c_sub = complex_sub(c1, c2)
  @if c_sub.real != 3 || c_sub.imag != 4
    println("FAIL: complex_sub")
    return 1
  @end
  println("PASS: complex_sub")

  // (5 + 7i) * (2 + 3i) = (10 - 21) + i(15 + 14) = -11 + 29i
  c_mul = complex_mul(c1, c2)
  @if c_mul.real != 0 - 11 || c_mul.imag != 29
    println("FAIL: complex_mul")
    return 1
  @end
  println("PASS: complex_mul")

  // |3 + 4i|^2 = 9 + 16 = 25
  c34 = { real: 3, imag: 4 }
  @if complex_abs_sq(c34) != 25
    println("FAIL: complex_abs_sq")
    return 1
  @end
  println("PASS: complex_abs_sq")

  // 2. Math Utility Tests
  @if math_abs(0 - 42) != 42 || math_abs(42) != 42
    println("FAIL: math_abs")
    return 1
  @end
  println("PASS: math_abs")

  @if clamp(10, 0, 5) != 5 || clamp(0 - 3, 0, 5) != 0 || clamp(3, 0, 5) != 3
    println("FAIL: clamp")
    return 1
  @end
  println("PASS: clamp")

  // 3. Newton-Raphson Sqrt Tests
  @if math_sqrt(0) != 0 || math_sqrt(1) != 1 || math_sqrt(144) != 12 || math_sqrt(10000) != 100
    println("FAIL: math_sqrt")
    return 1
  @end
  println("PASS: math_sqrt")

  // 4. Binary Power Tests
  @if math_pow(2, 10) != 1024 || math_pow(3, 4) != 81 || math_pow(5, 0) != 1
    println("FAIL: math_pow")
    return 1
  @end
  println("PASS: math_pow")

  // 5. GCD & LCM Tests
  @if math_gcd(48, 18) != 6 || math_gcd(101, 10) != 1
    println("FAIL: math_gcd")
    return 1
  @end
  println("PASS: math_gcd")

  @if math_lcm(12, 18) != 36
    println("FAIL: math_lcm")
    return 1
  @end
  println("PASS: math_lcm")

  // 6. Fixed-Point Circle Area (Pi = 3.14159)
  // For r = 10, area = (314159 * 100) / 100000 = 314
  a10 = area_circle(10)
  @if a10 != 314
    println("FAIL: area_circle")
    return 1
  @end
  println("PASS: area_circle (Pi=3.14159)")

  // 7. Trigonometric Sine & Cosine Tests (scaled by 1000)
  sin0 = math_sin_deg(0)
  sin30 = math_sin_deg(30)
  sin90 = math_sin_deg(90)
  sin180 = math_sin_deg(180)
  sin270 = math_sin_deg(270)

  @if sin0 != 0 || sin30 != 500 || sin90 != 1000 || sin180 != 0 || sin270 != 0 - 1000
    println("FAIL: math_sin_deg")
    return 1
  @end
  println("PASS: math_sin_deg")

  cos0 = math_cos_deg(0)
  cos90 = math_cos_deg(90)
  cos180 = math_cos_deg(180)

  @if cos0 != 1000 || cos90 != 0 || cos180 != 0 - 1000
    println("FAIL: math_cos_deg")
    return 1
  @end
  println("PASS: math_cos_deg")

  println("=== ALL MATH EXTRA TESTS PASSED ===")
  return 0
@end
