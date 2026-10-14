// ==============================================================================
// 👑 LIPI UNIVERSE — ADVANCED MATHEMATICS & NUMERICS (packages/math_extra/src/lib.lp)
// ⚡ 100% Pure Lipi Implementation — Zero C / Zero External Runtime Dependencies
// ==============================================================================

@struct Complex
  real: i64
  imag: i64
@end

// WHY: Adds two complex numbers using component-wise Cartesian addition
@fn complex_add(a, b)
  return { real: a.real + b.real, imag: a.imag + b.imag }
@end

// WHY: Subtracts complex number b from a (component-wise Cartesian subtraction)
@fn complex_sub(a, b)
  return { real: a.real - b.real, imag: a.imag - b.imag }
@end

// WHY: Multiplies two complex numbers: (a.r*b.r - a.i*b.i) + i*(a.r*b.i + a.i*b.r)
@fn complex_mul(a, b)
  return {
    real: a.real * b.real - a.imag * b.imag,
    imag: a.real * b.imag + a.imag * b.real
  }
@end

// WHY: Returns squared Euclidean modulus |z|^2 = real^2 + imag^2 without square root truncation
@fn complex_abs_sq(a)
  return a.real * a.real + a.imag * a.imag
@end

// WHY: Absolute value of 64-bit integer with sign-bit reflection
@fn math_abs(x)
  @if x < 0
    return 0 - x
  @end
  return x
@end

// WHY: Fast integer square root using Newton-Raphson method (converges in O(log n))
@fn math_sqrt(n)
  @if n <= 0
    return 0
  @end
  @if n == 1
    return 1
  @end
  x0 = n / 2
  @if x0 == 0
    x0 = 1
  @end
  x1 = (x0 + n / x0) / 2
  @while x1 < x0
    x0 = x1
    x1 = (x0 + n / x0) / 2
  @end
  return x0
@end

// WHY: Fast exponentiation by squaring in O(log exp) time
@fn math_pow(base, exp)
  @if exp < 0
    return 0
  @end
  @if exp == 0
    return 1
  @end
  res = 1
  b = base
  e = exp
  @while e > 0
    @if e % 2 == 1
      res = res * b
    @end
    b = b * b
    e = e / 2
  @end
  return res
@end

// WHY: Greatest Common Divisor via Euclidean algorithm
@fn math_gcd(a, b)
  x = math_abs(a)
  y = math_abs(b)
  @while y != 0
    t = y
    y = x % y
    x = t
  @end
  return x
@end

// WHY: Least Common Multiple via |a * b| / gcd(a, b)
@fn math_lcm(a, b)
  @if a == 0 || b == 0
    return 0
  @end
  g = math_gcd(a, b)
  return (math_abs(a) / g) * math_abs(b)
@end

// WHY: Real fixed-point circle area with Pi = 3.14159 (scaled by 100,000 for precision)
@fn area_circle(radius)
  // Pi scaled by 100000: 314159
  pi_scaled = 314159
  r_sq = radius * radius
  return (pi_scaled * r_sq) / 100000
@end

// WHY: Clamps value within [min_val, max_val] boundaries
@fn clamp(val, min_val, max_val)
  @if val < min_val
    return min_val
  @elif val > max_val
    return max_val
  @else
    return val
  @end
@end

// WHY: Fixed-point sine in degrees scaled by 1000 using ancient Bhaskara I sine approximation formula
// Precision: max absolute error < 0.0016 (~0.16%) across all 360 degrees
@fn math_sin_deg(deg)
  d = deg % 360
  @if d < 0
    d = d + 360
  @end
  
  sign = 1
  @if d >= 180
    sign = 0 - 1
    d = d - 180
  @end

  // Bhaskara I formula: 4000 * d * (180 - d) / (40500 - d * (180 - d))
  prod = d * (180 - d)
  denom = 40500 - prod
  @if denom == 0
    return 0
  @end
  sin_val = (4000 * prod) / denom
  return sign * sin_val
@end

// WHY: Fixed-point cosine in degrees scaled by 1000 using identity cos(x) = sin(x + 90)
@fn math_cos_deg(deg)
  return math_sin_deg(deg + 90)
@end
