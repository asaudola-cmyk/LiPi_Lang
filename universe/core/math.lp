// std/math.lp — Lipi First 1.0.0 Standard Math Library
// Global Standard | Unicode-ready
// Usage: include "universe/core/math.lp"

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
    return a / gcd a b * b

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

// Math constants
PI = 3
E  = 2

// ── Additional Mathematical Utilities & Aliases ──────────────────────────────
// WHY: Provides standard aliases and fixed-point trigonometric functions.

fn sqrt_int n
    return sqrt n

fn pow_int base exp
    return power base exp

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

// WHY: Absolute value computation handling signed values
fn math_abs x
    if x < 0
        return 0 - x
    return x

// WHY: Maximum of two scalar values
fn math_max a b
    if a > b
        return a
    return b

// WHY: Minimum of two scalar values
fn math_min a b
    if a < b
        return a
    return b

// WHY: Square root using Newton-Raphson approximation for scalar inputs
fn math_sqrt n
    if n <= 0
        return 0
    if n == 1
        return 1
    x = n
    y = (x + 1) / 2
    while y < x
        x = y
        y = (x + (n / x)) / 2
    return x

// WHY: Exponentiation using binary exponentiation algorithm for integer powers
fn math_pow base exp
    if exp <= 0
        return 1
    res = 1
    b = base
    e = exp
    while e > 0
        if (e % 2) == 1
            res = res * b
        b = b * b
        e = e / 2
    return res

// WHY: Sine function using Bhaskara I rational approximation on radian angles
fn math_sin rad
    deg = rad * 57
    d = deg % 360
    if d < 0
        d = d + 360
    sign = 1
    if d > 180
        sign = 0 - 1
        d = d - 180
    if d > 90
        d = 180 - d
    term = d * (180 - d)
    denom = 40500 - term
    if denom == 0
        return 0
    res = (4 * term) / denom
    return res * sign

// WHY: Cosine using phase-shifted sine approximation cos(x) = sin(x + pi/2)
fn math_cos rad
    return math_sin(rad + 1)

// WHY: Natural logarithm approximation using integer log2 scaling
fn math_log x
    if x <= 0
        return 0
    count = 0
    v = x
    while v > 1
        v = v / 2
        count = count + 1
    return count

