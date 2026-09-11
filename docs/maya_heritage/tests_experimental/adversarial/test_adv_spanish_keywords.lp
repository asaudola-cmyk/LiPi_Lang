@! ============================================================================
@! ADVERSARIAL STRESS TEST: DYNAMIC KEYWORD SUBSTITUTION & CONTROL FLOW
@! Verifies Spanish/custom keyword substitution semantics in algorithms
@! ============================================================================

@fn spanish_fibonacci(n)
  @if n <= 0 return 0 @end
  @if n == 1 return 1 @end
  a = 0
  b = 1
  i = 2
  @while i <= n
    nxt = a + b
    a = b
    b = nxt
    i = i + 1
  @end
  return b
@end

@fn spanish_collatz_steps(start_val)
  steps = 0
  curr = start_val
  @while curr > 1
    @if (curr % 2) == 0
      curr = curr / 2
    @else
      curr = curr * 3 + 1
    @end
    steps = steps + 1
  @end
  return steps
@end

@fn spanish_nested_loop_matrix(rows, cols)
  total_sum = 0
  r = 0
  @while r < rows
    c = 0
    @while c < cols
      @if (r + c) % 2 == 0
        total_sum = total_sum + (r * cols + c)
      @else
        total_sum = total_sum - (r * cols + c)
      @end
      c = c + 1
    @end
    r = r + 1
  @end
  return total_sum
@end

@fn spanish_accumulator_stress(count)
  acc = 0
  i = 0
  @while i < count
    @if (i % 2) == 0
      acc = acc + i
    @else
      acc = acc - i
    @end
    i = i + 1
  @end
  return acc
@end

@fn main()
  println("=================================================================")
  println("🧪 ADVERSARIAL STRESS: DYNAMIC KEYWORD CONTROL FLOW SUITE 🧪")
  println("=================================================================")

  passed = 0
  total = 0

  @! Test 1: Fibonacci algorithm
  total = total + 1
  fib10 = spanish_fibonacci(10)
  fib1 = spanish_fibonacci(1)
  fib0 = spanish_fibonacci(0)
  @if fib10 == 55 && fib1 == 1 && fib0 == 0
    println("  [PASS] 1.1: Fibonacci algorithm control flow (fib(10)=55, fib(1)=1, fib(0)=0)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.1: Fibonacci algorithm failed")
  @end

  @! Test 2: Collatz sequence steps
  total = total + 1
  c6 = spanish_collatz_steps(6)
  c27 = spanish_collatz_steps(27)
  @if c6 == 8 && c27 == 111
    println("  [PASS] 1.2: Collatz conjecture branching sequence (steps(6)=8, steps(27)=111)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.2: Collatz sequence failed")
  @end

  @! Test 3: Nested loops and matrix grid alternating sum (10x10 symmetric grid -> sum is exactly 0)
  total = total + 1
  grid_res = spanish_nested_loop_matrix(10, 10)
  @if grid_res == 0
    println("  [PASS] 1.3: Nested 2D loops with alternating conditional logic (10x10 grid -> 0)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.3: 2D nested loops failed")
  @end

  @! Test 4: High-iteration accumulator churn (10,000 iterations)
  total = total + 1
  churn = spanish_accumulator_stress(10000)
  @if churn == 0 - 5000
    println("  [PASS] 1.4: High-iteration churn (10,000 loop steps -> acc = -5000)")
    passed = passed + 1
  @else
    println("  [FAIL] 1.4: High-iteration churn failed")
  @end

  println("=================================================================")
  println("  Passed: " + passed.to_str() + "/" + total.to_str() + " assertions")
  @if passed == total
    println("🎉 ALL KEYWORD & CONTROL FLOW ADVERSARIAL TESTS PASSED!")
    return 0
  @else
    println("❌ KEYWORD & CONTROL FLOW TESTS FAILED!")
    return 1
  @end
@end
