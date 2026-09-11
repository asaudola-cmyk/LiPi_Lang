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
