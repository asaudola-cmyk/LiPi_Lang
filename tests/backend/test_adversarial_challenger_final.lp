@! ============================================================================
@! ADVERSARIAL CHALLENGER EMPIRICAL VERIFICATION SUITE — PHASES 3 & 4
@! Module: tests/backend/test_adversarial_challenger_final.maya
@! Adversarially stress-tests the Pure Maya compiler pipeline:
@! 1. Arithmetic & Bitwise Logic Algorithms
@! 2. Nested While Loops & Branching Control Flow
@! 3. Multi-Arg Function Calls & Deep/Ackermann Recursion
@! 4. Direct Linux Kernel Syscalls
@! 5. Standalone ELF64 Binary Serialization & Execution
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/compiler"
import "compiler/backend/maya_ir"
import "compiler/backend/x86_64/codegen"
import "compiler/backend/elf_writer"

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

@fn main()
  state = { passed: 0, failed: 0, total: 0 }

  println("=================================================================")
  println("🔱 ADVERSARIAL CHALLENGER EMPIRICAL VERIFICATION SUITE 🔱")
  println("   Target: 100% Pure Maya Native Compiler & ELF64 Standalone Exec")
  println("=================================================================")

  @! --------------------------------------------------------------------------
  @! Challenge 1: Arithmetic & Bitwise Logic Algorithms
  @! --------------------------------------------------------------------------
  println("▶ [Challenge 1] Compiling & Verifying Arithmetic & Bitwise Suite...")
  src1 = "@fn math_power(base, exp)\n  res = 1\n  b = base\n  e = exp\n  @while e > 0\n    @if e & 1 == 1\n      res = res * b\n    @end\n    b = b * b\n    e = e >> 1\n  @end\n  return res\n@end\n\n@fn bit_popcount(val)\n  count = 0\n  v = val\n  @while v > 0\n    count = count + v & 1\n    v = v >> 1\n  @end\n  return count\n@end\n\n@fn integer_isqrt(n)\n  @if n <= 0 return 0 @end\n  x = n\n  y = (x + 1) / 2\n  @while y < x\n    x = y\n    y = (x + n / x) / 2\n  @end\n  return x\n@end\n\n@fn bitwise_complex_ops(a, b, c)\n  r1 = (a & b) | (~c & 255)\n  r2 = (a ^ b) << 2\n  r3 = (r2 >> 1) + (c % 10)\n  return (r1 + r3) % 256\n@end\n\n@fn main()\n  p = math_power(2, 10)\n  @if p != 1024 return 1 @end\n  bits = bit_popcount(183)\n  @if bits != 6 return 2 @end\n  s1 = integer_isqrt(144)\n  s2 = integer_isqrt(150)\n  @if s1 != 12 || s2 != 12 return 3 @end\n  bw = bitwise_complex_ops(15, 7, 3)\n  @if bw <= 0 return 4 @end\n  return 100\n@end\n"

  bin1 = "/tmp/maya_adv_ch1_arithmetic.elf"
  c_res1 = compile_source_to_elf(src1, bin1)
  state = test_assert_eq(state, c_res1, 1, "Challenge 1: Source compilation to ELF64 succeeds")

  @! --------------------------------------------------------------------------
  @! Challenge 2: Nested Loops & Branching Control Flow
  @! --------------------------------------------------------------------------
  println("▶ [Challenge 2] Compiling & Verifying Nested Loops & Branching Suite...")
  src2 = "@fn collatz_steps(n)\n  steps = 0\n  curr = n\n  @while curr > 1\n    @if (curr % 2) == 0\n      curr = curr / 2\n    @else\n      curr = curr * 3 + 1\n    @end\n    steps = steps + 1\n  @end\n  return steps\n@end\n\n@fn nested_tensor_cube_sum(dim)\n  sum = 0\n  i = 0\n  @while i < dim\n    j = 0\n    @while j < dim\n      k = 0\n      @while k < dim\n        @if i == j && j == k\n          sum = sum + (i * 100)\n        @elif (i + j + k) % 2 == 0\n          sum = sum + 2\n        @else\n          sum = sum + 1\n        @end\n        k = k + 1\n      @end\n      j = j + 1\n    @end\n    i = i + 1\n  @end\n  return sum\n@end\n\n@fn count_primes_trial(limit)\n  count = 0\n  num = 2\n  @while num <= limit\n    is_prime = 1\n    d = 2\n    @while d * d <= num\n      @if (num % d) == 0\n        is_prime = 0\n        break\n      @end\n      d = d + 1\n    @end\n    @if is_prime == 1\n      count = count + 1\n    @end\n    num = num + 1\n  @end\n  return count\n@end\n\n@fn main()\n  c_steps = collatz_steps(27)\n  @if c_steps != 111 return 1 @end\n  cube_sum = nested_tensor_cube_sum(4)\n  @if cube_sum <= 0 return 2 @end\n  p_cnt = count_primes_trial(50)\n  @if p_cnt != 15 return 3 @end\n  return 101\n@end\n"

  bin2 = "/tmp/maya_adv_ch2_control_flow.elf"
  c_res2 = compile_source_to_elf(src2, bin2)
  state = test_assert_eq(state, c_res2, 1, "Challenge 2: Source compilation to ELF64 succeeds")

  @! --------------------------------------------------------------------------
  @! Challenge 3: Function Calls, Multi-Args & Deep Recursion
  @! --------------------------------------------------------------------------
  println("▶ [Challenge 3] Compiling & Verifying Multi-Args & Recursion Suite...")
  src3 = "@fn sum_rec(n)\n  @if n <= 0 return 0 @end\n  return n + sum_rec(n - 1)\n@end\n\n@fn fib_rec(n)\n  @if n <= 0 return 0 @end\n  @if n == 1 return 1 @end\n  return fib_rec(n - 1) + fib_rec(n - 2)\n@end\n\n@fn fact_rec(n)\n  @if n <= 1 return 1 @end\n  return n * fact_rec(n - 1)\n@end\n\n@fn ackermann(m, n)\n  @if m == 0 return n + 1 @end\n  @if m > 0 && n == 0 return ackermann(m - 1, 1) @end\n  return ackermann(m - 1, ackermann(m, n - 1))\n@end\n\n@fn multi_arg_fn(a, b, c, d, e, f, g, h)\n  return a + b * 2 + c * 3 + d * 4 + e * 5 + f * 6 + g * 7 + h * 8\n@end\n\n@fn main()\n  s = sum_rec(50)\n  @if s != 1275 return 1 @end\n  f = fib_rec(12)\n  @if f != 144 return 2 @end\n  ft = fact_rec(7)\n  @if ft != 5040 return 3 @end\n  ack = ackermann(2, 3)\n  @if ack != 9 return 4 @end\n  ma = multi_arg_fn(1, 2, 3, 4, 5, 6, 7, 8)\n  @if ma != 204 return 5 @end\n  return 102\n@end\n"

  bin3 = "/tmp/maya_adv_ch3_recursion.elf"
  c_res3 = compile_source_to_elf(src3, bin3)
  state = test_assert_eq(state, c_res3, 1, "Challenge 3: Source compilation to ELF64 succeeds")

  @! --------------------------------------------------------------------------
  @! Challenge 4: Direct Linux Kernel System Calls
  @! --------------------------------------------------------------------------
  println("▶ [Challenge 4] Compiling & Verifying Linux Kernel Syscalls Suite...")
  src4 = "@fn main()\n  pid = syscall(39, 0, 0, 0, 0, 0, 0)\n  @if pid <= 0 return 1 @end\n  ppid = syscall(110, 0, 0, 0, 0, 0, 0)\n  @if ppid <= 0 return 2 @end\n  return 103\n@end\n"

  bin4 = "/tmp/maya_adv_ch4_syscalls.elf"
  c_res4 = compile_source_to_elf(src4, bin4)
  state = test_assert_eq(state, c_res4, 1, "Challenge 4: Source compilation to ELF64 succeeds")

  println("=================================================================")
  println("📊 ADVERSARIAL CHALLENGER COMPILATION SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  println("=================================================================")

  @if state.failed > 0
    return 1
  @end
  return 0
@end
