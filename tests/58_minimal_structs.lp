// Test 58: Structs — Global Standard

struct Point
    x
    y

struct Person
    name
    age
    score

// Create struct instances
p = Point()
p.x = 10
p.y = 20
say p.x
say p.y
say p.x + p.y

// Function using struct
fn distance p1
    return p1.x * p1.x + p1.y * p1.y

say distance p

// Person struct
alice = Person()
alice.name = "Alice"
alice.age = 30
alice.score = 95
say alice.name
say alice.age
say alice.score

say "PASS: Test 58 Structs"
