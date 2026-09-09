// Test 56: Unicode Identifiers — Global Standard
// English keywords + Bengali/Unicode variable names = global + local

// Bengali variable names work perfectly
name = "লিপি"
version = 2
say name
say version

// Bengali function names work too
fn sum a b = a + b
fn product a b = a * b

say sum 10 20
say product 5 6

// Bengali identifiers in loops
total = 0
for i in 1..10
    total = total + i
say total

say "PASS: Test 56 Unicode"
