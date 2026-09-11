// std/math.lp — Lipi 2.0 Standard Math Library
// Global Standard | Unicode-ready
// Usage: include "universe/core/std_math.lp"

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
