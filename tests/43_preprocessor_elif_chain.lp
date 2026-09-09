// Test 43: elif Chain — Lipi 2.0 Global Standard

fn classify n
    if n < 0
        return "negative"
    elif n == 0
        return "zero"
    elif n < 10
        return "single digit"
    elif n < 100
        return "double digit"
    elif n < 1000
        return "triple digit"
    else
        return "large"

fn fizzbuzz n
    if n % 15 == 0
        return "FizzBuzz"
    elif n % 3 == 0
        return "Fizz"
    elif n % 5 == 0
        return "Buzz"
    else
        return n

say "=== elif Chain ==="
say classify(-5)
say classify(0)
say classify(7)
say classify(42)
say classify(999)
say classify(10000)

say "=== FizzBuzz ==="
for i in 1..20
    say fizzbuzz(i)

say "PASS: Test 43 elif Chain"
