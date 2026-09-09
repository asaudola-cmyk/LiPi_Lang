// Test 17: Standard Library Usage — Lipi 2.0
// Demonstrates: math helpers, clamp, min/max, digit_sum, palindrome check

// Clamp a value to [lo, hi]
fn clamp x lo hi
    if x < lo
        return lo
    if x > hi
        return hi
    return x

// Minimum of two values
fn min2 a b
    if a < b
        return a
    return b

// Maximum of two values
fn max2 a b
    if a > b
        return a
    return b

// Integer absolute value
fn abs_val x
    if x < 0
        return 0 - x
    return x

// Sum of digits of a non-negative integer
// WHY: Lipi / is float division, so we use (n - d) / 10 to keep integer-like values
fn digit_sum n
    total = 0
    while n >= 10
        d = n % 10
        total = total + d
        n = (n - d) / 10
    total = total + n
    return total

// Reverse digits of a number
fn reverse_digits n
    result = 0
    while n >= 10
        result = result * 10 + n % 10
        d = n % 10
        n = (n - d) / 10
    result = result * 10 + n
    return result

// Check palindrome number
fn is_palindrome n
    if n < 0
        return 0
    rev = reverse_digits n
    if rev == n
        return 1
    return 0

say "clamp(15, 0, 10):"
say clamp(15, 0, 10)

say "clamp(5, 0, 10):"
say clamp(5, 0, 10)

say "clamp(-5, 0, 10):"
say clamp(0 - 5, 0, 10)

say "min2(42, 17):"
say min2(42, 17)

say "max2(42, 17):"
say max2(42, 17)

// Negative literals via parenthesized expressions
say "abs_val(-99):"
neg99 = 0 - 99
say abs_val neg99

say "digit_sum(12345):"
say digit_sum 12345

say "reverse_digits(12345):"
say reverse_digits 12345

say "is_palindrome(121):"
say is_palindrome 121

say "is_palindrome(123):"
say is_palindrome 123

say "PASS: Test 17 Standard Library"
