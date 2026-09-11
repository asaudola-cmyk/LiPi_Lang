@! ============================================================================
@! ADVERSARIAL STRESS TEST 1: DEEP RECURSION & CALL STACK HARDENING
@! File: tests/adversarial/test_adv_deep_recursion_gate1.maya
@! Target: Sovereign Pure Maya Compiler Backend (x86-64 freestanding ELF)
@! ============================================================================

@fn recursive_sum(n, acc)
  @if n <= 0
    return acc
  @end
  return recursive_sum(n - 1, acc + n)
@end

@fn ackermann(m, n)
  @if m == 0
    return n + 1
  @end
  @if m > 0 && n == 0
    return ackermann(m - 1, 1)
  @end
  inner = ackermann(m, n - 1)
  return ackermann(m - 1, inner)
@end

@fn fib_iter_rec(n, a, b)
  @if n <= 0
    return a
  @end
  return fib_iter_rec(n - 1, b, a + b)
@end

@fn deep_call_depth(depth)
  @if depth <= 0
    return 1337
  @end
  sub = deep_call_depth(depth - 1)
  return sub + 1
@end

@fn main()
  println("================================================================")
  println("  ADVERSARIAL STRESS 1: DEEP RECURSION & STACK HARDENING")
  println("================================================================")

  @! Test 1: Recursive sum to depth 1000: sum(1..1000) = 1000 * 1001 / 2 = 500500
  println("▶ [TC-REC-01] Testing deep linear recursion (depth = 1,000)...")
  sum1k = recursive_sum(1000, 0)
  @if sum1k == 500500
    println("  [PASS] TC-REC-01: recursive_sum(1000, 0) == 500500")
  @else
    println("  [FAIL] TC-REC-01: recursive_sum mismatch")
    return 101
  @end

  @! Test 2: Deep non-tail call stack unrolling (depth = 1,000) -> returns 1337 + 1000 = 2337
  println("▶ [TC-REC-02] Testing non-tail call stack unrolling (depth = 1,000)...")
  deep_res = deep_call_depth(1000)
  @if deep_res == 2337
    println("  [PASS] TC-REC-02: deep_call_depth(1000) == 2337")
  @else
    println("  [FAIL] TC-REC-02: deep_call_depth mismatch")
    return 102
  @end

  @! Test 3: Ackermann function A(3, 4) = 125 (deep nested recursion tree)
  println("▶ [TC-REC-03] Testing Ackermann(3, 4)...")
  ack = ackermann(3, 4)
  @if ack == 125
    println("  [PASS] TC-REC-03: ackermann(3, 4) == 125")
  @else
    println("  [FAIL] TC-REC-03: ackermann(3, 4) mismatch")
    return 103
  @end

  @! Test 4: Fibonacci tail-recursive to 50: Fib(50) = 12586269025
  println("▶ [TC-REC-04] Testing deep Fibonacci iteration (n = 50)...")
  fib50 = fib_iter_rec(50, 0, 1)
  @if fib50 == 12586269025
    println("  [PASS] TC-REC-04: fib_iter_rec(50, 0, 1) == 12586269025")
  @else
    println("  [FAIL] TC-REC-04: fib_iter_rec mismatch")
    return 104
  @end

  println("================================================================")
  println("  ALL DEEP RECURSION STRESS TESTS PASSED (EXIT CODE 0)")
  println("================================================================")
  return 0
@end
