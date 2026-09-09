// Test 60: Prime Numbers — Global Standard

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

say "Primes up to 30:"
for n in 2..30
    if is_prime n
        say n

count = 0
for n in 2..100
    if is_prime n
        count = count + 1
say "Count of primes up to 100:"
say count

say "PASS: Test 60 Primes"
