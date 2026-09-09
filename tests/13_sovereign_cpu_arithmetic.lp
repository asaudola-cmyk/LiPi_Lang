// Test 13: CPU Arithmetic — Lipi 2.0
// Demonstrates: integer division, modulo, signed arithmetic, absolute value, isqrt

// Safe integer division (guards against divide-by-zero)
fn safe_div a b
    if b == 0
        return 0
    return a / b

// Compute average of sum/count (safe)
fn average sum count
    return safe_div(sum, count)

// Absolute value without built-in
fn abs_val x
    if x < 0
        return 0 - x
    return x

// Integer square root via linear search (guaranteed termination)
fn isqrt n
    if n < 0
        return 0
    x = 0
    while (x + 1) * (x + 1) <= n
        x = x + 1
    return x

// Power using repeated multiplication
fn power base exp
    result = 1
    i = 0
    while i < exp
        result = result * base
        i = i + 1
    return result

say "Safe division:"
say safe_div(100, 4)
say safe_div(100, 0)

say "Average of sum=150 over 6:"
say average(150, 6)

// Absolute value: use variable for negative inputs
neg42 = 0 - 42
say "Abs of -42:"
say abs_val neg42

say "Abs of 17:"
say abs_val 17

say "Integer sqrt of 144:"
say isqrt 144

say "Integer sqrt of 50:"
say isqrt 50

say "Power 2^10:"
say power(2, 10)

say "Power 3^5:"
say power(3, 5)

// Modulo chain
r = 1
for i in 1..10
    r = r * i % 1000007
say "Factorial mod 1000007 (1..10):"
say r

say "PASS: Test 13 CPU Arithmetic"
