// Test 46: Type Annotations — Lipi 2.0 Global Standard
// Type annotation patterns using comments

fn add_ints a b
    // a: int, b: int -> int
    return a + b

fn safe_divide a b
    // a: num, b: num -> num | null
    if b == 0
        return null
    return a / b

fn clamp val lo hi
    // val: num, lo: num, hi: num -> num
    if val < lo
        return lo
    if val > hi
        return hi
    return val

struct TypedPoint
    x   // float
    y   // float

struct TypedPerson
    name    // string
    age     // int
    score   // float

say "=== Type Annotations ==="
say add_ints(10, 20)
say add_ints(100, 200)

r = safe_divide(10, 3)
say r

r2 = safe_divide(5, 0)
if r2 == null
    say "null returned"

say clamp(150, 0, 100)
say clamp(-5, 0, 100)
say clamp(50, 0, 100)

p = TypedPoint()
p.x = 3
p.y = 4
say p.x
say p.y

person = TypedPerson()
person.name = "Alice"
person.age = 30
person.score = 95
say person.name
say person.age
say person.score

say "PASS: Test 46 Type Annotations"
