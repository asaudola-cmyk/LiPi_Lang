// Test 59: Fibonacci — Global Standard (iterative, fast)

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

for i in 0..12
    say fibonacci i

say "PASS: Test 59 Fibonacci"
