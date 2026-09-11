@! ============================================================================
@! FREESTANDING ADVERSARIAL STRESS TEST FOR MAYA SOVEREIGN NATIVE BINARY
@! ============================================================================

@struct StackItem
  value: 0
  depth: 0
@end

@fn gcd(a, b)
  @while b != 0
    t = b
    b = a % b
    a = t
  @end
  return a
@end

@fn count_primes(limit)
  primes_found = 0
  n = 2
  @while n <= limit
    is_p = 1
    d = 2
    @while d * d <= n
      @if n % d == 0
        is_p = 0
        d = n
      @end
      d = d + 1
    @end
    @if is_p == 1
      primes_found = primes_found + 1
    @end
    n = n + 1
  @end
  return primes_found
@end

@fn main()
  println("================================================================")
  println("  SOVEREIGN MAYA FREESTANDING EMPIRICAL VERIFICATION HARNESS")
  println("================================================================")
  
  @! Test 1: GCD computation
  g = gcd(48, 18)
  @if g == 6
    println("  [PASS] TC-GCD-01: GCD(48, 18) == 6")
  @else
    println("  [FAIL] TC-GCD-01: GCD mismatch")
    return 1
  @end

  @! Test 2: Prime Sieve computation up to 1000 (168 primes)
  p_count = count_primes(1000)
  @if p_count == 168
    println("  [PASS] TC-PRIME-01: Prime Count in [2..1000] == 168")
  @else
    println("  [FAIL] TC-PRIME-01: Prime Count mismatch")
    return 1
  @end

  @! Test 3: Struct allocation & member read
  item = {
    value: 1337,
    depth: 42
  }
  @if item.value == 1337 && item.depth == 42
    println("  [PASS] TC-STRUCT-01: Struct Instantiation and Member Read")
  @else
    println("  [FAIL] TC-STRUCT-01: Struct member mismatch")
    return 1
  @end

  println("================================================================")
  println("  ALL FREESTANDING ADVERSARIAL TESTS PASSED (EXIT CODE 0)")
  println("================================================================")
  return 0
@end
