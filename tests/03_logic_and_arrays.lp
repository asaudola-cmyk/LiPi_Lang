// Test 03: Logic and Conditionals — Lipi 2.0
// Demonstrates: if/elif/else chains, boolean logic (and, or, not)

fn grade score
    if score >= 90
        return "A+"
    elif score >= 80
        return "A"
    elif score >= 70
        return "B"
    elif score >= 60
        return "C"
    else
        return "F"

// Test grade function with several scores
say grade 95
say grade 85
say grade 75
say grade 55

// Boolean logic with and
x = 15
if x > 10 and x < 20
    say "x is between 10 and 20"

// Boolean logic with or
if x == 15 or x == 20
    say "x is 15 or 20"

// Boolean logic with not
if not x == 99
    say "x is not 99"

// Nested conditionals
a = 100
b = 200
if a < b
    if a > 50
        say "a is between 50 and 200"

say "PASS: Test 03 Logic"
