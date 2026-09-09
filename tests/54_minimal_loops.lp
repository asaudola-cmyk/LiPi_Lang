// Test 54: All Loop Types — Global Standard

// while loop
i = 1
total = 0
while i <= 5
    total = total + i
    i = i + 1
say total

// for range loop
for j in 1..5
    say j

// repeat loop
repeat 3
    say "hello"

// nested loops
for a in 1..3
    for b in 1..3
        say a * b

say "PASS: Test 54 Loops"
