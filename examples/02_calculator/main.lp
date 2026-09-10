// Calculator — Lipi 2.0 Example
// A full-featured calculator with all operations

fn add a b = a + b
fn sub a b = a - b
fn mul a b = a * b

fn div a b
    if b == 0
        say "Error: division by zero"
        return null
    return a / b

fn mod a b
    if b == 0
        say "Error: modulo by zero"
        return null
    return a % b

fn power base exp
    // WHY: iterative power avoids recursion limit for large exp
    if exp == 0
        return 1
    result = 1
    i = 0
    while i < exp
        result = result * base
        i = i + 1
    return result

fn factorial n
    if n < 0
        say "Error: factorial of negative"
        return null
    if n <= 1
        return 1
    return n * factorial(n - 1)

fn gcd a b
    while b != 0
        t = b
        b = a % b
        a = t
    return a

fn lcm a b
    return a * b / gcd(a, b)

fn is_prime n
    if n < 2
        return 0
    if n == 2
        return 1
    if n % 2 == 0
        return 0
    i = 3
    while i * i <= n
        if n % i == 0
            return 0
        i = i + 2
    return 1

say "=== Lipi Calculator ==="
say ""
say "Basic Arithmetic:"
say "  10 + 5 = " + add(10, 5)
say "  10 - 5 = " + sub(10, 5)
say "  10 * 5 = " + mul(10, 5)
say "  10 / 5 = " + div(10, 5)
say "  10 % 3 = " + mod(10, 3)

say ""
say "Powers:"
say "  2^10 = " + power(2, 10)
say "  3^5  = " + power(3, 5)

say ""
say "Factorials:"
say "  5!  = " + factorial(5)
say "  10! = " + factorial(10)
say "  12! = " + factorial(12)

say ""
say "Number Theory:"
say "  gcd(48, 18) = " + gcd(48, 18)
say "  lcm(12, 8)  = " + lcm(12, 8)

say ""
say "Primes up to 50:"
for n in 2..50
    if is_prime(n) == 1
        say n

say ""
say "Error handling:"
div(10, 0)
mod(5, 0)
factorial(-1)
