// Test 14: Loop and Logic Patterns — Lipi First 1.0.0
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

sw = sum_while(100)
say "Sum 1..100 (while):"
say sw
if sw != 5050
    say "FAIL: sum_while expected 5050, got " + sw
    exit(1)

sf = sum_for(100)
say "Sum 1..100 (for):"
say sf
if sf != 5050
    say "FAIL: sum_for expected 5050, got " + sf
    exit(1)

sq = first_square_above(50)
say "First k where k*k > 50:"
say sq
if sq != 8
    say "FAIL: first_square_above expected 8, got " + sq
    exit(1)

ev = count_even(1, 20)
say "Even numbers in 1..20:"
say ev
if ev != 10
    say "FAIL: count_even expected 10, got " + ev
    exit(1)

// Repeat loop: countdown
say "Countdown:"
counter = 5
repeat 5
    say counter
    counter = counter - 1

if counter != 0
    say "FAIL: repeat countdown expected 0, got " + counter
    exit(1)

// Nested loop: multiplication table 1..4
say "Multiplication table 1..4:"
table_sum = 0
for row in 1..4
    for col in 1..4
        say row * col
        table_sum = table_sum + (row * col)

if table_sum != 100
    say "FAIL: table_sum expected 100, got " + table_sum
    exit(1)

say "PASS: Test 14 Loop Logic"
