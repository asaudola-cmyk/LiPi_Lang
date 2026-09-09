// Test 08: Structs — Lipi 2.0
// Demonstrates: struct declaration, field access, struct as function argument
// NOTE: Uses fn(arg1, arg2) paren syntax for 2-arg calls inside function bodies

struct Fraction
    num
    den

struct Point
    x
    y

// Construct a Fraction with given numerator and denominator
fn make_fraction n d
    f = Fraction()
    f.num = n
    f.den = d
    return f

// Add two fractions: a/b + c/d = (a*d + c*b) / (b*d)
fn fraction_add f1 f2
    result = Fraction()
    result.num = f1.num * f2.den + f2.num * f1.den
    result.den = f1.den * f2.den
    return result

// GCD using Euclidean algorithm
fn gcd a b
    while b != 0
        temp = b
        b = a % b
        a = temp
    return a

// 1/2 + 1/3 = 5/6
// Use paren syntax inside fn body for 2-arg calls
f1 = make_fraction(1, 2)
f2 = make_fraction(1, 3)
f3 = fraction_add(f1, f2)
say f3.num
say f3.den

// Point struct: distance squared from origin
p = Point()
p.x = 3
p.y = 4
dist_sq = p.x * p.x + p.y * p.y
say dist_sq

// GCD checks using paren syntax
g1 = gcd(48, 18)
say g1
g2 = gcd(100, 75)
say g2

say "PASS: Test 08 Structs"
