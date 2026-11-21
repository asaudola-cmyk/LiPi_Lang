// std/math.lp — Lipi First 1.0.0 Standard Math Library
// Global Standard | Unicode-ready
// Usage: include "utso/core/math.lp"

// Absolute value
fn abs x
    if x < 0
        return x * -1
    return x

// Integer square root (Newton's method)
fn sqrt n
    if n < 0
        return -1
    if n == 0
        return 0
    x = n
    y = (x + 1) / 2
    while y < x
        x = y
        y = (x + n / x) / 2
    return x

// Power: base ^ exp (integer)
fn power base exp
    result = 1
    i = 0
    while i < exp
        result = result * base
        i = i + 1
    return result

// Greatest common divisor (Euclidean algorithm)
fn gcd a b
    while b != 0
        temp = b
        b = a % b
        a = temp
    return a

// Least common multiple
fn lcm a b
    return (a / gcd(a, b)) * b

// Check if prime
fn is_prime n
    if n < 2
        return 0
    if n == 2
        return 1
    if n % 2 == 0
        return 0
    i = 3
    while i * i <= n
        if n % i == 0
            return 0
        i = i + 2
    return 1

// Fibonacci (iterative, fast)
fn fibonacci n
    if n <= 1
        return n
    a = 0
    b = 1
    i = 2
    while i <= n
        c = a + b
        a = b
        b = c
        i = i + 1
    return b

// Factorial (iterative)
fn factorial n
    result = 1
    i = 1
    while i <= n
        result = result * i
        i = i + 1
    return result

// Min / Max
fn min a b
    if a < b
        return a
    return b

fn max a b
    if a > b
        return a
    return b

// Clamp value between lo and hi
fn clamp val lo hi
    if val < lo
        return lo
    if val > hi
        return hi
    return val

// Floor division
fn floor_div a b = a / b

// Modulo (always positive)
fn mod_pos a b
    r = a % b
    if r < 0
        return r + b
    return r

// Math constants (legacy integer compatibility + IEEE-754 precision aliases)
PI = 3
E  = 2
MATH_PI = 3.141592653589793
MATH_E  = 2.718281828459045

@fn math_pi() -> f64
  return 3.141592653589793
@end

@fn math_e() -> f64
  return 2.718281828459045
@end

// ── Additional Mathematical Utilities & Aliases ──────────────────────────────
// WHY: Provides standard aliases and fixed-point trigonometric functions.

fn sqrt_int n
    return sqrt(n)

fn pow_int base exp
    return power(base, exp)

fn sin_fixed_deg deg scale
    d = deg % 360
    if d < 0
        d = d + 360
    sign = 1
    if d > 180
        sign = -1
        d = d - 180
    if d > 90
        d = 180 - d
    term = d * (180 - d)
    denom = 40500 - term
    if denom == 0
        return 0
    res = (4 * term * scale) / denom
    return res * sign

// WHY: Advances pseudo-random number generator state using POSIX 31-bit LCG algorithm.
// Ensures deterministic pseudo-random sequences for reinforcement learning buffers and policies.
fn math_random_seed seed
    if seed == 0
        seed = 123456789
    next = (seed * 1103515245 + 12345) & 2147483647
    if next < 0
        next = 0 - next
    return next

// WHY: IEEE-754 double-precision mathematical primitives for scientific computing and Lipi AI.
@fn math_abs(x: f64) -> f64
  @if x < 0.0
    return 0.0 - x
  @end
  return x
@end

@fn math_max(a: f64, b: f64) -> f64
  @if a > b
    return a
  @end
  return b
@end

@fn math_min(a: f64, b: f64) -> f64
  @if a < b
    return a
  @end
  return b
@end

@fn math_clamp(val: f64, lo: f64, hi: f64) -> f64
  @if val < lo
    return lo
  @end
  @if val > hi
    return hi
  @end
  return val
@end

// WHY: Range-reduced IEEE-754 square root using base-4 scaling + 10 Newton-Raphson iterations.
@fn math_sqrt(x: f64) -> f64
  @if x <= 0.0
    return 0.0
  @end
  m = x
  scale = 1.0
  @while m >= 4.0
    m = m * 0.25
    scale = scale * 2.0
  @end
  @while m < 0.25
    m = m * 4.0
    scale = scale * 0.5
  @end
  g = 0.5 * (m + 1.0)
  i = 0
  @while i < 10
    g = 0.5 * (g + (m / g))
    i = i + 1
  @end
  return g * scale
@end

// WHY: Natural exponential exp(x) via binary range reduction x = k * ln(2) + r, |r| <= ln(2)/2.
@fn math_exp(x: f64) -> f64
  @if x < 0.0 - 709.0
    return 0.0
  @end
  @if x > 709.0
    x = 709.0
  @end
  ln2 = 0.6931471805599453
  k = floor((x / ln2) + 0.5)
  @if x < 0.0
    k = floor((x / ln2) - 0.5)
  @end
  r = x - ((k * 1.0) * ln2)
  term = 1.0
  sum = 1.0
  i = 1
  @while i <= 14
    term = term * (r / (i * 1.0))
    sum = sum + term
    i = i + 1
  @end
  @if k >= 0
    j = 0
    @while j < k
      sum = sum * 2.0
      j = j + 1
    @end
  @else
    j = 0
    neg_k = 0 - k
    @while j < neg_k
      sum = sum * 0.5
      j = j + 1
    @end
  @end
  return sum
@end

// WHY: Natural logarithm ln(x) via power-of-two scaling into [sqrt(0.5), sqrt(2)] + atanh series.
@fn math_ln(x: f64) -> f64
  @if x <= 0.0
    return 0.0 - 1000000.0
  @end
  ln2 = 0.6931471805599453
  k = 0
  m = x
  @while m > 1.4142135623730951
    m = m * 0.5
    k = k + 1
  @end
  @while m < 0.7071067811865475
    m = m * 2.0
    k = k - 1
  @end
  z = (m - 1.0) / (m + 1.0)
  z2 = z * z
  term = z
  sum = z
  n = 3
  @while n <= 19
    term = term * z2
    sum = sum + (term / (n * 1.0))
    n = n + 2
  @end
  return (2.0 * sum) + ((k * 1.0) * ln2)
@end

@fn math_log(x: f64) -> f64
  return math_ln(x)
@end

// WHY: IEEE-754 sine with 2*pi modulo reduction, quadrant folding into [-pi/2, pi/2], and 9-term Taylor polynomial.
@fn math_sin(rad: f64) -> f64
  pi = 3.141592653589793
  two_pi = 6.283185307179586
  half_pi = 1.5707963267948966
  k = floor(rad / two_pi)
  r = rad - ((k * 1.0) * two_pi)
  @if r < 0.0
    r = r + two_pi
  @end
  @if r > pi
    r = r - two_pi
  @end
  @if r > half_pi
    r = pi - r
  @elif r < (0.0 - half_pi)
    r = (0.0 - pi) - r
  @end
  r2 = r * r
  term = r
  sum = r
  n = 1
  @while n <= 8
    d1 = (2 * n) * 1.0
    d2 = ((2 * n) + 1) * 1.0
    term = (0.0 - term) * r2 / (d1 * d2)
    sum = sum + term
    n = n + 1
  @end
  return sum
@end

// WHY: IEEE-754 cosine with 2*pi reduction and direct even Taylor series (exact cos(0) = 1.0).
@fn math_cos(rad: f64) -> f64
  pi = 3.141592653589793
  two_pi = 6.283185307179586
  half_pi = 1.5707963267948966
  k = floor(rad / two_pi)
  r = rad - ((k * 1.0) * two_pi)
  @if r < 0.0
    r = r + two_pi
  @end
  @if r > pi
    r = r - two_pi
  @end
  sign = 1.0
  @if r > half_pi
    r = pi - r
    sign = 0.0 - 1.0
  @elif r < (0.0 - half_pi)
    r = (0.0 - pi) - r
    sign = 0.0 - 1.0
  @end
  r2 = r * r
  term = 1.0
  sum = 1.0
  n = 1
  @while n <= 8
    d1 = ((2 * n) - 1) * 1.0
    d2 = (2 * n) * 1.0
    term = (0.0 - term) * r2 / (d1 * d2)
    sum = sum + term
    n = n + 1
  @end
  return sign * sum
@end

@fn math_tan(rad: f64) -> f64
  c = math_cos(rad)
  @if math_abs(c) < 0.000000000000001
    return 0.0
  @end
  return math_sin(rad) / c
@end

// WHY: Real exponentiation supporting exact integer exponents (including negative bases) and real powers.
@fn math_pow(base: f64, exp: f64) -> f64
  @if exp == 0.0
    return 1.0
  @end
  @if base == 0.0
    return 0.0
  @end
  exp_i = floor(exp)
  @if (exp_i * 1.0) == exp
    is_neg_e = 0
    e = exp_i
    @if e < 0
      is_neg_e = 1
      e = 0 - e
    @end
    res = 1.0
    b = base
    @while e > 0
      @if (e % 2) == 1
        res = res * b
      @end
      b = b * b
      e = e / 2
    @end
    @if is_neg_e == 1
      return 1.0 / res
    @end
    return res
  @end
  @if base < 0.0
    return 0.0
  @end
  return math_exp(exp * math_ln(base))
@end

