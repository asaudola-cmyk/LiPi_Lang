// Test 02: Math and Fibonacci — Lipi 2.0
// Demonstrates: iterative fibonacci, factorial, for loops

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

say "Fibonacci sequence:"
for i in 0..12
    say fibonacci i

fn factorial n
    result = 1
    i = 1
    while i <= n
        result = result * i
        i = i + 1
    return result

say "Factorials:"
for i in 1..8
    say factorial i

say "PASS: Test 02 Math Fibonacci"
