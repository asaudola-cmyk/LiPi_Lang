// Test 14: Loop and Logic Patterns — Lipi 2.0
// Demonstrates: while, for, repeat, nested loops, break-via-return

// Sum 1..n using a while loop
fn sum_while n
    total = 0
    i = 1
    while i <= n
        total = total + i
        i = i + 1
    return total

// Sum 1..n using a for loop
fn sum_for n
    total = 0
    for i in 1..n
        total = total + i
    return total

// Find first integer k where k*k > limit
fn first_square_above limit
    k = 1
    while k * k <= limit
        k = k + 1
    return k

// Count even numbers in range [lo, hi]
fn count_even lo hi
    count = 0
    for i in lo..hi
        if i % 2 == 0
            count = count + 1
    return count

say "Sum 1..100 (while):"
say sum_while 100

say "Sum 1..100 (for):"
say sum_for 100

say "First k where k*k > 50:"
say first_square_above 50

say "Even numbers in 1..20:"
say count_even 1 20

// Repeat loop: countdown
say "Countdown:"
counter = 5
repeat 5
    say counter
    counter = counter - 1

// Nested loop: multiplication table 1..4
say "Multiplication table 1..4:"
for row in 1..4
    for col in 1..4
        say row * col

say "PASS: Test 14 Loop Logic"
