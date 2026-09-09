// Test 15: Functions and Recursion — Lipi 2.0
// Demonstrates: one-liner fns, recursive factorial, GCD, LCM, recursive Fibonacci

// One-liner function definitions
fn double n = n * 2
fn square n = n * n
fn inc n = n + 1

// Recursive factorial
fn factorial n
    if n <= 1
        return 1
    return n * factorial(n - 1)

// GCD via Euclidean algorithm (iterative)
fn gcd a b
    while b != 0
        temp = b
        b = a % b
        a = temp
    return a

// LCM using GCD (paren syntax: gcd(a, b) works inside fn body)
fn lcm a b
    g = gcd(a, b)
    return a * b / g

// Recursive Fibonacci (works for small n)
fn fib n
    if n <= 1
        return n
    return fib(n - 1) + fib(n - 2)

say "double 7:"
say double 7

say "square 9:"
say square 9

say "factorial 10:"
say factorial 10

say "gcd(48, 18):"
say gcd(48, 18)

say "lcm(12, 18):"
say lcm(12, 18)

say "fib 10:"
say fib 10

say "square(double(3)) = 36:"
say square double 3

say "PASS: Test 15 Functions Recursion"
