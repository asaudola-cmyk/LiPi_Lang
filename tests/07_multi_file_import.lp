// Test 07: Multi-file Import — Lipi 2.0
// Demonstrates: utility functions, string repetition, math helpers

// Math utility functions (inline, simulating imported module)
fn square n = n * n
fn cube n = n * n * n

// Computes base^exp iteratively
fn power base exp
    result = 1
    i = 0
    while i < exp
        result = result * base
        i = i + 1
    return result

// String utility: repeat a string n times
fn repeat_str s n
    result = ""
    i = 0
    while i < n
        result = result + s
        i = i + 1
    return result

// Test math utilities — each call result stored before say
say "square(7):"
say square 7

say "cube(4):"
say cube 4

say "power(2, 10):"
p = power(2, 10)
say p

// Test string utilities
say "repeat_str('ab', 3):"
r1 = repeat_str("ab", 3)
say r1

say "repeat_str('-', 5):"
r2 = repeat_str("-", 5)
say r2

// Composed: square(3) then power result squared
sq3 = square 3
say "square(3):"
say sq3

p2_4 = power(2, 4)
say "power(2, 4):"
say p2_4

sq_p2_4 = square p2_4
say "square(power(2,4)):"
say sq_p2_4

say "PASS: Test 07 Multi File"
