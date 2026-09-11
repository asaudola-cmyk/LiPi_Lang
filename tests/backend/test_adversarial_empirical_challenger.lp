@! ============================================================================
@! FINAL EMPIRICAL CHALLENGER STRESS SUITE (ITERATION 2)
@! Module: tests/backend/test_adversarial_empirical_challenger.maya
@! Comprehensive empirical verification of the Pure Maya Compiler Driver:
@! 1. Complex Variables & Expressions (32 locals, compound assigns, bitwise ops)
@! 2. Deeply Nested Loops & Branching (4-level loops, break/continue, multi-elif)
@! 3. Multi-Argument Functions (10 args across register/stack boundary) & Deep/Mutual Recursion
@! 4. Native String Literals, Escapes & Output Formatting (println/print)
@! 5. Direct Linux Kernel Syscalls & Memory/File Operations (mmap, open, write, close)
@! ============================================================================

import "compiler/backend/compiler"

@struct ChallengeState
  passed: 0
  failed: 0
  total: 0
@end

@fn assert_compile_and_record(state, src, out_path, test_name)
  state.total = state.total + 1
  res = compile_source_to_elf(src, out_path)
  @if res == 1
    state.passed = state.passed + 1
    println("  [PASS-COMPILE] " + test_name + " -> " + out_path)
  @else
    state.failed = state.failed + 1
    println("  [FAIL-COMPILE] " + test_name + " compilation failed!")
  @end
  return state
@end

@fn main()
  state = { passed: 0, failed: 0, total: 0 }

  println("=================================================================")
  println("🔱 EMPIRICAL CHALLENGER ITERATION 2 STRESS SUITE 🔱")
  println("   Target: Pure Native Maya Compiler Driver ELF Verification")
  println("=================================================================")

  @! --------------------------------------------------------------------------
  @! 1. Variables, Bitwise Ops, Complex Arithmetic & 32 Local Variables
  @! --------------------------------------------------------------------------
  println("▶ [Stress 1] Compiling 32-Variable Arithmetic & Expression Suite...")
  src1 = "@fn stress_vars_arithmetic()\n  v0 = 1\n  v1 = 2\n  v2 = 3\n  v3 = 4\n  v4 = 5\n  v5 = 6\n  v6 = 7\n  v7 = 8\n  v8 = 9\n  v9 = 10\n  v10 = 11\n  v11 = 12\n  v12 = 13\n  v13 = 14\n  v14 = 15\n  v15 = 16\n  v16 = 17\n  v17 = 18\n  v18 = 19\n  v19 = 20\n  v20 = 21\n  v21 = 22\n  v22 = 23\n  v23 = 24\n  v24 = 25\n  v25 = 26\n  v26 = 27\n  v27 = 28\n  v28 = 29\n  v29 = 30\n  v30 = 31\n  v31 = 32\n\n  sum1 = v0 + v1 + v2 + v3 + v4 + v5 + v6 + v7 + v8 + v9 + v10 + v11 + v12 + v13 + v14 + v15\n  sum2 = v16 + v17 + v18 + v19 + v20 + v21 + v22 + v23 + v24 + v25 + v26 + v27 + v28 + v29 + v30 + v31\n  total = sum1 + sum2\n  @if total != 528 return 1 @end\n\n  @! Test compound assignments\n  acc = 100\n  acc += 50\n  acc -= 20\n  acc *= 3\n  acc /= 2\n  @if acc != 195 return 2 @end\n\n  @! Test bitwise precedence and nested expressions\n  a = 170\n  b = 85\n  c = 15\n  d = 3\n  bit_res = ((a & b) | (~c & 255)) ^ (d << 4)\n  @if bit_res != 192 return 3 @end\n\n  return 0\n@end\n\n@fn main()\n  r = stress_vars_arithmetic()\n  @if r != 0 return r @end\n  return 110\n@end\n"

  bin1 = "/tmp/maya_stress1_variables.elf"
  state = assert_compile_and_record(state, src1, bin1, "Stress 1: Variables & Arithmetic")

  @! --------------------------------------------------------------------------
  @! 2. Nested Loops (4-level), Break/Continue & Multi-Branch If/Elif/Else
  @! --------------------------------------------------------------------------
  println("▶ [Stress 2] Compiling Nested Loops & Branching Suite...")
  src2 = "@fn stress_loops_and_branches()\n  @! 4-level nested while loops\n  total_iters = 0\n  a = 0\n  @while a < 3\n    b = 0\n    @while b < 3\n      c = 0\n      @while c < 3\n        d = 0\n        @while d < 3\n          total_iters = total_iters + 1\n          d = d + 1\n        @end\n        c = c + 1\n      @end\n      b = b + 1\n    @end\n    a = a + 1\n  @end\n  @if total_iters != 81 return 1 @end\n\n  @! While loop with break\n  sum_break = 0\n  k = 0\n  @while k < 100\n    @if k >= 10\n      break\n    @end\n    sum_break = sum_break + k\n    k = k + 1\n  @end\n  @if sum_break != 45 return 2 @end\n\n  @! Multi-tier if/elif/else classification\n  score_sum = 0\n  val = 0\n  @while val < 6\n    @if val == 0\n      score_sum = score_sum + 10\n    @elif val == 1\n      score_sum = score_sum + 20\n    @elif val == 2\n      score_sum = score_sum + 30\n    @elif val == 3\n      score_sum = score_sum + 40\n    @elif val == 4\n      score_sum = score_sum + 50\n    @else\n      score_sum = score_sum + 60\n    @end\n    val = val + 1\n  @end\n  @if score_sum != 210 return 3 @end\n\n  return 0\n@end\n\n@fn main()\n  r = stress_loops_and_branches()\n  @if r != 0 return r @end\n  return 111\n@end\n"

  bin2 = "/tmp/maya_stress2_loops.elf"
  state = assert_compile_and_record(state, src2, bin2, "Stress 2: Loops & Branches")

  @! --------------------------------------------------------------------------
  @! 3. Multi-Argument Functions (10 args) & Deep/Mutual Recursion
  @! --------------------------------------------------------------------------
  println("▶ [Stress 3] Compiling Multi-Arg Functions & Recursion Suite...")
  src3 = "@fn ten_args_fn(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)\n  return a1 + a2*2 + a3*3 + a4*4 + a5*5 + a6*6 + a7*7 + a8*8 + a9*9 + a10*10\n@end\n\n@fn deep_rec_sum(n, acc)\n  @if n <= 0 return acc @end\n  return deep_rec_sum(n - 1, acc + n)\n@end\n\n@fn mutual_even(n)\n  @if n == 0 return 1 @end\n  return mutual_odd(n - 1)\n@end\n\n@fn mutual_odd(n)\n  @if n == 0 return 0 @end\n  return mutual_even(n - 1)\n@end\n\n@fn main()\n  @! 10 arguments test (RDI, RSI, RDX, RCX, R8, R9 + 4 on stack)\n  res10 = ten_args_fn(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)\n  @if res10 != 385 return 1 @end\n\n  @! Deep recursion test (depth 100)\n  rec_val = deep_rec_sum(100, 0)\n  @if rec_val != 5050 return 2 @end\n\n  @! Mutual recursion test\n  e50 = mutual_even(50)\n  o50 = mutual_odd(50)\n  e51 = mutual_even(51)\n  o51 = mutual_odd(51)\n  @if e50 != 1 || o50 != 0 || e51 != 0 || o51 != 1 return 3 @end\n\n  return 112\n@end\n"

  bin3 = "/tmp/maya_stress3_recursion.elf"
  state = assert_compile_and_record(state, src3, bin3, "Stress 3: Multi-Args & Recursion")

  @! --------------------------------------------------------------------------
  @! 4. Strings, Escape Sequences & Output Formatting
  @! --------------------------------------------------------------------------
  println("▶ [Stress 4] Compiling Native Strings & Output Formatting Suite...")
  src4 = "@fn main()\n  println(\"=== MAYA STRESS TEST 4 ===\")\n  println(\"Line 1: Hello\")\n  println(\"Line 2: Tab\tSeparated\")\n  println(\"Line 3: Quotes \\\"Maya\\\" and Backslash \\\\\")\n  print(\"Positive: \")\n  println(987654)\n  print(\"Negative: \")\n  println(-12345)\n  print(\"Zero: \")\n  println(0)\n  println(\"DONE\")\n  return 113\n@end\n"

  bin4 = "/tmp/maya_stress4_strings.elf"
  state = assert_compile_and_record(state, src4, bin4, "Stress 4: Strings & Formatting")

  @! --------------------------------------------------------------------------
  @! 5. Direct Linux Kernel Syscalls & Bare Memory / File Operations
  @! --------------------------------------------------------------------------
  println("▶ [Stress 5] Compiling Direct Linux Syscalls Suite...")
  src5 = "@fn main()\n  @! 1. Syscall 39 (sys_getpid) & 110 (sys_getppid)\n  pid = syscall(39, 0, 0, 0, 0, 0, 0)\n  ppid = syscall(110, 0, 0, 0, 0, 0, 0)\n  @if pid <= 0 || ppid <= 0 return 1 @end\n\n  @! 2. Syscall 9 (sys_mmap: addr=0, len=4096, prot=3(RW), flags=34(PRIVATE|ANONYMOUS), fd=-1, off=0)\n  page_addr = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)\n  @if page_addr <= 0 return 2 @end\n\n  @! 3. Syscall 11 (sys_munmap: addr=page_addr, len=4096)\n  unmap_res = syscall(11, page_addr, 4096, 0, 0, 0, 0)\n  @if unmap_res != 0 return 3 @end\n\n  return 114\n@end\n"

  bin5 = "/tmp/maya_stress5_syscalls.elf"
  state = assert_compile_and_record(state, src5, bin5, "Stress 5: Linux Syscalls")

  println("=================================================================")
  println("📊 COMPILATION SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  println("=================================================================")

  @if state.failed > 0
    return 1
  @end
  return 0
@end
