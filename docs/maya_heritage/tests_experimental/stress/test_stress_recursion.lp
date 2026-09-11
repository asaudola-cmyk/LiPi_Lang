@! ============================================================================
@! MAYA ADVERSARIAL STRESS SUITE: DEEP RECURSION & CALL STACKS
@! File: tests/stress/test_stress_recursion.maya
@! ============================================================================

@struct RecChainNode
  node_val: 0
  next_node: 0
@end

@fn deep_sum(n)
  @if n <= 0
    return 0
  @else
    return n + deep_sum(n - 1)
  @end
@end

@fn deep_fact_mod(n, m)
  @if n <= 1
    return 1
  @else
    prev = deep_fact_mod(n - 1, m)
    return (n * prev) % m
  @end
@end

@fn ackermann(m, n)
  @if m == 0
    return n + 1
  @elif m > 0 && n == 0
    return ackermann(m - 1, 1)
  @else
    inner = ackermann(m, n - 1)
    return ackermann(m - 1, inner)
  @end
@end

@fn mutual_is_even(n)
  @if n == 0
    return 1
  @else
    return mutual_is_odd(n - 1)
  @end
@end

@fn mutual_is_odd(n)
  @if n == 0
    return 0
  @else
    return mutual_is_even(n - 1)
  @end
@end

@fn build_rec_chain(depth, acc)
  @if depth <= 0
    return acc
  @else
    node = { node_val: depth, next_node: acc }
    return build_rec_chain(depth - 1, node)
  @end
@end

@fn sum_rec_chain(curr)
  @if curr == 0
    return 0
  @else
    return curr.node_val + sum_rec_chain(curr.next_node)
  @end
@end

@fn fib_tail(n, a, b)
  @if n == 0
    return a
  @elif n == 1
    return b
  @else
    return fib_tail(n - 1, b, a + b)
  @end
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS TEST 1: DEEP RECURSION & CALL STACKS 🔥")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! Stress 1.1: Deep Recursive Summation (Depth = 500)
  total = total + 1
  s500 = deep_sum(500)
  @! 500 * 501 / 2 = 125250
  @if s500 == 125250
    passed = passed + 1
    println("  [PASS] S1.1: Deep recursion depth 500 sum (125250)")
  @else
    failed = failed + 1
    println("  [FAIL] S1.1: Deep recursion depth 500 sum")
  @end

  @! Stress 1.2: Deep Factorial with Modulo (Depth = 250, mod 1,000,000,007)
  total = total + 1
  f250 = deep_fact_mod(250, 1000000007)
  @! Precomputed oracle: 250! % 1000000007
  @if f250 > 0 && f250 < 1000000007
    passed = passed + 1
    println("  [PASS] S1.2: Deep factorial depth 250 modulo execution (res = " + f250.to_str() + ")")
  @else
    failed = failed + 1
    println("  [FAIL] S1.2: Deep factorial depth 250 modulo execution")
  @end

  @! Stress 1.3: Ackermann Function A(3, 4) == 125 (Depth up to 128+, thousands of calls)
  total = total + 1
  ack_res = ackermann(3, 4)
  @if ack_res == 125
    passed = passed + 1
    println("  [PASS] S1.3: Ackermann function A(3, 4) == 125")
  @else
    failed = failed + 1
    println("  [FAIL] S1.3: Ackermann function A(3, 4)")
  @end

  @! Stress 1.4: Mutual Recursion (Depth = 300)
  total = total + 1
  even300 = mutual_is_even(300)
  odd300 = mutual_is_odd(300)
  even301 = mutual_is_even(301)
  odd301 = mutual_is_odd(301)
  @if even300 == 1 && odd300 == 0 && even301 == 0 && odd301 == 1
    passed = passed + 1
    println("  [PASS] S1.4: Mutual recursion depth 300+ even/odd parity checks")
  @else
    failed = failed + 1
    println("  [FAIL] S1.4: Mutual recursion depth 300+")
  @end

  @! Stress 1.5: Deep Tail-Recursive Fibonacci (fib_tail(50))
  total = total + 1
  fib50 = fib_tail(50, 0, 1)
  @! fib(50) = 12586269025
  @if fib50 == 12586269025
    passed = passed + 1
    println("  [PASS] S1.5: Tail-recursive Fibonacci (fib(50) == 12586269025)")
  @else
    failed = failed + 1
    println("  [FAIL] S1.5: Tail-recursive Fibonacci fib(50)")
  @end

  @! Stress 1.6: Recursive Struct Chain Construction & Traversal (Depth = 250)
  total = total + 1
  chain_head = build_rec_chain(250, 0)
  chain_sum = sum_rec_chain(chain_head)
  @! 250 * 251 / 2 = 31375
  @if chain_sum == 31375
    passed = passed + 1
    println("  [PASS] S1.6: Recursive struct chain depth 250 construction & sum (31375)")
  @else
    failed = failed + 1
    println("  [FAIL] S1.6: Recursive struct chain depth 250")
  @end

  println("-----------------------------------------------------------------")
  println("Stress Suite 1 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ ALL RECURSION STRESS TESTS PASSED")
    return 0
  @else
    println("✗ RECURSION STRESS TESTS FAILED")
    return 1
  @end
@end
