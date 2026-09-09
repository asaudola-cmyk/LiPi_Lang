// Test 20: Algorithm Showcase — Lipi 2.0
// Demonstrates: binary search, prime sieve, GCD/LCM, sort analysis

// Binary search: value at index i = i * 3 (sorted array simulation)
// Returns index of target or -1
fn binary_search target lo hi
    while lo < hi
        mid = (lo + hi) / 2
        val = mid * 3
        if val == target
            return mid
        elif val < target
            lo = mid + 1
        else
            hi = mid
    return -1

// Check if n is prime (trial division)
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

// Count primes up to n
fn count_primes n
    count = 0
    for k in 2..n
        if is_prime k
            count = count + 1
    return count

// Bubble sort swap count (worst case for n elements)
fn bubble_sort_swaps n = n * (n - 1) / 2

// GCD iterative
fn gcd a b
    while b != 0
        temp = b
        b = a % b
        a = temp
    return a

// LCM using GCD
fn lcm a b
    g = gcd(a, b)
    return a * b / g

say "Binary search for 15 in i*3 array [0..20):"
say binary_search(15, 0, 20)

say "Binary search for 7 (not found, expect -1):"
say binary_search(7, 0, 20)

say "Prime count up to 50:"
say count_primes 50

say "Bubble sort swaps n=10:"
say bubble_sort_swaps 10

say "GCD(56, 98):"
say gcd(56, 98)

say "LCM(12, 18):"
say lcm(12, 18)

say "Primes up to 30:"
for n in 2..30
    if is_prime n
        say n

say "PASS: Test 20 Algorithm Showcase"
