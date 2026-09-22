// Test 55: Conditionals — Global Standard

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

say grade 95
say grade 85
say grade 75
say grade 65
say grade 50

// Boolean logic
x = 10
y = 20

if x < y and x > 0
    say "x is between 0 and y"

if x == 10 or y == 10
    say "one of them is 10"

if not x == 99
    say "x is not 99"

say "PASS: Test 55 Conditionals"
