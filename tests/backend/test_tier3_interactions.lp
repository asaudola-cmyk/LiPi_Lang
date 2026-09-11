@! ============================================================================
@! MAYA NATIVE BACKEND TEST SUITE — TIER 3: CROSS-FEATURE INTERACTIONS
@! Tests nested control flow, recursive call conventions, complex expressions,
@! register spilling, chained Linux syscalls, and multi-stage pipeline flow.
@! 100% Pure Maya — Zero Mock Logic — Strict Verification
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"

@struct TestState
  passed: 0
  failed: 0
  total: 0
@end

@fn test_assert_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: " + expected.to_str() + ", Got: " + actual.to_str() + ")")
  @end
  return state
@end

@fn test_assert_true(state, cond, name)
  state.total = state.total + 1
  @if cond == 1 || cond == true
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Condition was false)")
  @end
  return state
@end

@fn test_assert_str_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: '" + expected + "', Got: '" + actual + "')")
  @end
  return state
@end

@! Interaction Helpers: Recursive Fibonacci & Factorial
@fn math_fibonacci(n)
  @if n <= 0
    return 0
  @elif n == 1
    return 1
  @else
    return math_fibonacci(n - 1) + math_fibonacci(n - 2)
  @end
@end

@fn math_factorial(n)
  @if n <= 1
    return 1
  @else
    return n * math_factorial(n - 1)
  @end
@end

@! Complex Expression Evaluator
@fn eval_complex_expression(a, b, c, d, e, f)
  term1 = a * b
  term2 = c / d
  term3 = e % f
  return (term1 + term2) - term3
@end

@! Nested Control Flow Simulation (Prime sieve / Collatz)
@fn collatz_steps(start_val)
  n = start_val
  steps = 0
  @while n > 1
    @if (n % 2) == 0
      n = n / 2
    @else
      n = (3 * n) + 1
    @end
    steps = steps + 1
  @end
  return steps
@end

@fn main()
  println("=================================================================")
  println("🧪 MAYA NATIVE BACKEND TEST SUITE — TIER 3: INTERACTIONS 🧪")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  @! --------------------------------------------------------------------------
  @! Interaction 1: Recursive Functions & System V ABI Stack Alignment
  @! --------------------------------------------------------------------------
  println("▶ [Tier 3.1] Verifying Recursive Functions & Stack ABI Preservation...")

  @! Test 1: Fibonacci sequence
  state = test_assert_eq(state, math_fibonacci(0), 0, "fib(0) = 0")
  state = test_assert_eq(state, math_fibonacci(1), 1, "fib(1) = 1")
  state = test_assert_eq(state, math_fibonacci(6), 8, "fib(6) = 8")
  state = test_assert_eq(state, math_fibonacci(10), 55, "fib(10) = 55")
  state = test_assert_eq(state, math_fibonacci(12), 144, "fib(12) = 144")

  @! Test 2: Factorial sequence
  state = test_assert_eq(state, math_factorial(1), 1, "fact(1) = 1")
  state = test_assert_eq(state, math_factorial(5), 120, "fact(5) = 120")
  state = test_assert_eq(state, math_factorial(7), 5040, "fact(7) = 5040")

  @! --------------------------------------------------------------------------
  @! Interaction 2: Nested Loops & Conditional Branches (Collatz Conjecture)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 3.2] Verifying Nested Loops, Branches & Register Allocation...")

  @! Test 3: Collatz convergence steps
  state = test_assert_eq(state, collatz_steps(1), 0, "collatz(1) = 0 steps")
  state = test_assert_eq(state, collatz_steps(6), 8, "collatz(6) = 8 steps (6->3->10->5->16->8->4->2->1)")
  state = test_assert_eq(state, collatz_steps(27), 111, "collatz(27) = 111 steps")

  @! Test 4: Nested matrix multiplication & accumulator
  mat_sum = 0
  row = 0
  @while row < 4
    col = 0
    @while col < 4
      @if (row + col) % 2 == 0
        mat_sum = mat_sum + (row * 10 + col)
      @else
        mat_sum = mat_sum - (row * 10 + col)
      @end
      col = col + 1
    @end
    row = row + 1
  @end
  state = test_assert_eq(state, mat_sum, 0, "Alternating 4x4 matrix sum symmetry = 0")

  @! --------------------------------------------------------------------------
  @! Interaction 3: Complex Multi-Operand Expressions & ALU Lowering
  @! --------------------------------------------------------------------------
  println("▶ [Tier 3.3] Verifying Multi-Operand Arithmetic & Operator Precedence...")

  @! a=10, b=20, c=100, d=4, e=25, f=7
  @! term1 = 10 * 20 = 200
  @! term2 = 100 / 4 = 25
  @! term3 = 25 % 7 = 4
  @! (200 + 25) - 4 = 221
  expr_res = eval_complex_expression(10, 20, 100, 4, 25, 7)
  state = test_assert_eq(state, expr_res, 221, "eval_complex_expr(10,20,100,4,25,7) = 221")

  @! --------------------------------------------------------------------------
  @! Interaction 4: Chained Linux Syscalls (sys_getpid, sys_getppid, sys_mmap)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 3.4] Verifying Chained Linux Syscalls Execution...")

  pid = sys_getpid()
  state = test_assert_true(state, pid > 0, "sys_getpid() returns valid positive PID")

  ppid = sys_getppid()
  state = test_assert_true(state, ppid > 0, "sys_getppid() returns valid positive PPID")

  @! Verify consecutive syscall preserves register state
  pid2 = sys_getpid()
  state = test_assert_eq(state, pid, pid2, "Consecutive sys_getpid() returns consistent PID")

  @! Test memory mapping syscall mmap (9)
  @! PROT_READ (1) | PROT_WRITE (2) = 3
  @! MAP_PRIVATE (2) | MAP_ANONYMOUS (32) = 34
  mmap_addr = sys_mmap(0, 4096, 3, 34, -1, 0)
  state = test_assert_true(state, mmap_addr > 0, "sys_mmap(4096) returns valid mapped page address")
  
  @! Unmap allocated memory via munmap (11)
  unmap_res = sys_munmap(mmap_addr, 4096)
  state = test_assert_eq(state, unmap_res, 0, "sys_munmap() returns 0 on successful free")

  println("")
  println("=================================================================")
  println("📊 TIER 3 (INTERACTIONS) SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  @if state.failed == 0
    println("🎉 ALL TIER 3 INTERACTION TESTS PASSED CLEANLY!")
  @else
    println("❌ TIER 3 INTERACTION TESTS COMPLETED WITH FAILURES!")
  @end
  println("=================================================================")

  @if state.failed == 0
    return 0
  @else
    return 1
  @end
@end
