// Test 52: Functions — Global Standard
// fn keyword, space-separated params, indented body

// One-liner function
fn double n = n * 2
fn square n = n * n
fn add a b = a + b
fn max2 a b
    if a > b
        return a
    return b

say double 7
say square 9
say add 10 20
say max2 100 42
say max2 3 99

// Multi-line function with loop
fn sum_to n
    total = 0
    i = 1
    while i <= n
        total = total + i
        i = i + 1
    return total

say sum_to 10
say sum_to 100

say "PASS: Test 52 Functions"
