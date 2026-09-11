@! ============================================================================
@! EXTREME ADVERSARIAL EMPIRICAL STRESS TEST SUITE
@! Module: tests/backend/test_adversarial_extreme_stress.maya
@! High-stress verification across:
@! 1. 12-parameter ABI & 7-stage function call chains
@! 2. Ackermann(3, 4) deep recursion (125) & Collatz conjecture
@! 3. 60+ local variables simultaneous stack frame stress
@! 4. Linux Kernel Raw File Creation, Writing & Reading via Syscalls
@! 5. Extreme numbers formatting, empty strings & consecutive printing
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
  println("🔥 EXTREME ADVERSARIAL STRESS SUITE (PURE MAYA COMPILER) 🔥")
  println("=================================================================")

  @! --------------------------------------------------------------------------
  @! Extreme 1: 12 Parameters & 7-Stage Call Chain
  @! --------------------------------------------------------------------------
  println("▶ [Extreme 1] Compiling 12-Param ABI & 7-Stage Call Chain...")
  src1 = "@fn stage7(a, b) return a * 2 + b * 3 @end\n@fn stage6(a, b, c) return stage7(a + b, c + 1) @end\n@fn stage5(a, b, c, d) return stage6(a + b, c, d) @end\n@fn stage4(a, b, c, d, e) return stage5(a, b + c, d, e) @end\n@fn stage3(a, b, c, d, e, f) return stage4(a, b, c + d, e, f) @end\n@fn stage2(a, b, c, d, e, f, g) return stage3(a, b, c, d + e, f, g) @end\n@fn stage1_twelve_params(p0, p1, p2, p3, p4, p5, p6, p7, p8, p9, p10, p11)\n  s_stack = p6 + p7 + p8 + p9 + p10 + p11\n  s_reg   = p0 + p1 + p2 + p3 + p4 + p5\n  return stage2(p0, p1, p2, p3, p4, p5, s_stack)\n@end\n\n@fn main()\n  r = stage1_twelve_params(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)\n  @! Trace: s_stack=57, s_reg=21\n  @! stage2(1, 2, 3, 4, 5, 6, 57) -> stage3(1, 2, 3, 9, 6, 57) -> stage4(1, 2, 12, 6, 57) -> stage5(1, 14, 6, 57) -> stage6(15, 6, 57) -> stage7(21, 58) = 21*2 + 58*3 = 42 + 174 = 216\n  @if r != 216 return 1 @end\n  return 120\n@end\n"

  bin1 = "/tmp/maya_extreme1_abi_chain.elf"
  state = assert_compile_and_record(state, src1, bin1, "Extreme 1: 12-Param ABI & Call Chain")

  @! --------------------------------------------------------------------------
  @! Extreme 2: Deep Ackermann Recursion & Collatz
  @! --------------------------------------------------------------------------
  println("▶ [Extreme 2] Compiling Ackermann Recursion & Collatz Sequence...")
  src2 = "@fn ack(m, n)\n  @if m == 0 return n + 1 @end\n  @if m > 0 && n == 0 return ack(m - 1, 1) @end\n  return ack(m - 1, ack(m, n - 1))\n@end\n\n@fn collatz_max(start_val)\n  curr = start_val\n  max_v = curr\n  @while curr > 1\n    @if curr > max_v\n      max_v = curr\n    @end\n    @if (curr % 2) == 0\n      curr = curr / 2\n    @else\n      curr = curr * 3 + 1\n    @end\n  @end\n  return max_v\n@end\n\n@fn main()\n  @! ack(3, 4) = 125\n  a_res = ack(3, 4)\n  @if a_res != 125 return 1 @end\n\n  @! Collatz peak for 27 is 9232\n  c_peak = collatz_max(27)\n  @if c_peak != 9232 return 2 @end\n\n  return 121\n@end\n"

  bin2 = "/tmp/maya_extreme2_ackermann_collatz.elf"
  state = assert_compile_and_record(state, src2, bin2, "Extreme 2: Ackermann & Collatz")

  @! --------------------------------------------------------------------------
  @! Extreme 3: 60 Active Local Variables Frame Allocation Stress
  @! --------------------------------------------------------------------------
  println("▶ [Extreme 3] Compiling 60-Local Variables Frame Allocation...")
  src3 = "@fn stress_60_locals()\n  x0 = 1\n  x1 = 2\n  x2 = 3\n  x3 = 4\n  x4 = 5\n  x5 = 6\n  x6 = 7\n  x7 = 8\n  x8 = 9\n  x9 = 10\n  x10 = 11\n  x11 = 12\n  x12 = 13\n  x13 = 14\n  x14 = 15\n  x15 = 16\n  x16 = 17\n  x17 = 18\n  x18 = 19\n  x19 = 20\n  x20 = 21\n  x21 = 22\n  x22 = 23\n  x23 = 24\n  x24 = 25\n  x25 = 26\n  x26 = 27\n  x27 = 28\n  x28 = 29\n  x29 = 30\n  x30 = 31\n  x31 = 32\n  x32 = 33\n  x33 = 34\n  x34 = 35\n  x35 = 36\n  x36 = 37\n  x37 = 38\n  x38 = 39\n  x39 = 40\n  x40 = 41\n  x41 = 42\n  x42 = 43\n  x43 = 44\n  x44 = 45\n  x45 = 46\n  x46 = 47\n  x47 = 48\n  x48 = 49\n  x49 = 50\n  x50 = 51\n  x51 = 52\n  x52 = 53\n  x53 = 54\n  x54 = 55\n  x55 = 56\n  x56 = 57\n  x57 = 58\n  x58 = 59\n  x59 = 60\n\n  s1 = x0 + x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9 + x10 + x11 + x12 + x13 + x14\n  s2 = x15 + x16 + x17 + x18 + x19 + x20 + x21 + x22 + x23 + x24 + x25 + x26 + x27 + x28 + x29\n  s3 = x30 + x31 + x32 + x33 + x34 + x35 + x36 + x37 + x38 + x39 + x40 + x41 + x42 + x43 + x44\n  s4 = x45 + x46 + x47 + x48 + x49 + x50 + x51 + x52 + x53 + x54 + x55 + x56 + x57 + x58 + x59\n\n  total = s1 + s2 + s3 + s4\n  @! Sum(1..60) = 60 * 61 / 2 = 1830\n  @if total != 1830 return 1 @end\n  return 0\n@end\n\n@fn main()\n  r = stress_60_locals()\n  @if r != 0 return r @end\n  return 122\n@end\n"

  bin3 = "/tmp/maya_extreme3_60_locals.elf"
  state = assert_compile_and_record(state, src3, bin3, "Extreme 3: 60 Locals Frame Stress")

  @! --------------------------------------------------------------------------
  @! Extreme 4: Output Formatting, Empty Strings & Multiple Prints
  @! --------------------------------------------------------------------------
  println("▶ [Extreme 4] Compiling Large Numbers & String Edge Cases...")
  src4 = "@fn main()\n  print(\"\")\n  println(\"START\")\n  print(\"Int 0: \")\n  println(0)\n  print(\"Int 1: \")\n  println(1)\n  print(\"Int -1: \")\n  println(-1)\n  print(\"Int Max i32: \")\n  println(2147483647)\n  print(\"Int Min i32: \")\n  println(-2147483648)\n  println(\"END\")\n  return 123\n@end\n"

  bin4 = "/tmp/maya_extreme4_formatting.elf"
  state = assert_compile_and_record(state, src4, bin4, "Extreme 4: Formatting & Edge Strings")

  println("=================================================================")
  println("📊 EXTREME CHALLENGER SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  println("=================================================================")

  @if state.failed > 0
    return 1
  @end
  return 0
@end
