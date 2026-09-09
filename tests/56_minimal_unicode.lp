// Test 56: Unicode Identifiers — Global Standard
// English keywords + Bengali/Unicode variable names = global + local

// Bengali variable names work perfectly
নাম = "লিপি"
সংস্করণ = 2
say নাম
say সংস্করণ

// Bengali function names work too
fn যোগফল a b = a + b
fn গুণফল a b = a * b

say যোগফল 10 20
say গুণফল 5 6

// Bengali identifiers in loops
total = 0
for i in 1..10
    total = total + i
say total

say "PASS: Test 56 Unicode"
