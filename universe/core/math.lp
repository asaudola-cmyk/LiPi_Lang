@fn abs(x)
  @if x < 0 return 0 - x @end
  return x
@end

@fn max(a, b)
  @if a > b return a @end
  return b
@end

@fn min(a, b)
  @if a < b return a @end
  return b
@end

// ── Sovereign Mathematical Combinators ───────────────────────────────────────
// WHY: Used across Maya heritage test suite and scientific numeric algorithms.

@fn clamp(val, min_val, max_val)
  // WHY: Restricts a value to lie within the closed interval [min_val, max_val].
  @if val < min_val return min_val @end
  @if val > max_val return max_val @end
  return val
@end

@fn factorial(n)
  // WHY: Iterative/recursive factorial computation for combinatorial operations.
  @if n <= 1 return 1 @end
  return n * factorial(n - 1)
@end

@fn gcd(a, b)
  // WHY: Euclidean algorithm to find greatest common divisor of two integers.
  @while b != 0
    t = b
    b = a % b
    a = t
  @end
  return a
@end

@fn pow_int(base, exp)
  // WHY: Exponentiation by squaring for O(log exp) fast integer power calculation.
  res = 1
  curr_b = base
  curr_e = exp
  @while curr_e > 0
    @if (curr_e % 2) == 1
      res = res * curr_b
    @end
    curr_b = curr_b * curr_b
    curr_e = curr_e / 2
  @end
  return res
@end

@fn lcm(a, b)
  // WHY: Least common multiple defined as (|a * b|) / gcd(a, b) with zero-division guard
  @if a == 0 or b == 0 return 0 @end
  prod = a * b
  @if prod < 0 prod = 0 - prod @end
  return prod / gcd(a, b)
@end

@fn is_prime(n)
  // WHY: Deterministic primality test with trial division (skip evens) for freestanding numerical sovereignty
  @if n <= 1 return 0 @end
  @if n <= 3 return 1 @end
  @if (n % 2) == 0 or (n % 3) == 0 return 0 @end
  d = 5
  @while d * d <= n
    @if (n % d) == 0 or (n % (d + 2)) == 0
      return 0
    @end
    d = d + 6
  @end
  return 1
@end

@fn sqrt_int(n)
  // WHY: Integer square root using Newton-Raphson Babylonian iteration
  @if n <= 0 return 0 @end
  @if n == 1 return 1 @end
  x0 = n / 2
  x1 = (x0 + n / x0) / 2
  @while x1 < x0
    x0 = x1
    x1 = (x0 + n / x0) / 2
  @end
  return x0
@end

@fn sin_fixed_deg(deg, scale)
  // WHY: Bhaskara I's sine approximation formula: (4 * d * (180 - d) * scale) / (40500 - d * (180 - d))
  d = deg % 360
  @if d < 0
    d = d + 360
  @end
  sign = 1
  @if d > 180
    sign = 0 - 1
    d = d - 180
  @end
  @if d > 90
    d = 180 - d
  @end
  term = d * (180 - d)
  num = 4 * term * scale
  den = 40500 - term
  @if den == 0
    return scale * sign
  @end
  return (num / den) * sign
@end

@fn cos_fixed_deg(deg, scale)
  // WHY: cos(deg) = sin(deg + 90)
  return sin_fixed_deg(deg + 90, scale)
@end

