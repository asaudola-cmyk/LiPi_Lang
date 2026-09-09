// Test 53: Recursion — Global Standard
// WHY: lipic (C binary) could not handle recursion. lipic2 can.

fn factorial n
    if n <= 1
        return 1
    return n * factorial(n - 1)

// GCD iterative (avoid recursive call ambiguity)
fn gcd a b
    while b != 0
        temp = b
        b = a % b
        a = temp
    return a

say factorial 1
say factorial 5
say factorial 10

say gcd 48 18
say gcd 100 75

say "PASS: Test 53 Recursion"
