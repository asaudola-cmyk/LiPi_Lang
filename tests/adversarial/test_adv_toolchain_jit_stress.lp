@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE: MAYA JIT COMPILER & INTERACTIVE REPL ENGINE
@! File: tests/adversarial/test_adv_toolchain_jit_stress.maya
@! Focus: Memory bounds, W^X transitions, operator precedence, deep recursion,
@!        multi-arg functions, and REPL edge cases
@! ============================================================================

import "compiler/backend/jit/jit_memory"
import "compiler/backend/jit/jit_executor"
import "compiler/backend/jit/jit_engine"
import "compiler/backend/jit/repl"

@struct AdvTestContext
  total: i64
  passed: i64
  failed: i64
@end

@fn assert_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str())
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_str_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got \"" + actual + "\"")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
@end

@fn assert_true(ctx, name, cond)
  ctx.total = ctx.total + 1
  @if cond != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was false")
    return 0
  @end
@end

@fn assert_ge(ctx, name, actual, min_val)
  ctx.total = ctx.total + 1
  @if actual >= min_val
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str() + " (>= " + min_val.to_str() + ")")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected >= " + min_val.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🔥 [ADVERSARIAL SUITE 1] JIT MEMORY, W^X, COMPILATION & REPL STRESS")
  println("=================================================================")

  ctx = { total: 0, passed: 0, failed: 0 }

  @! --------------------------------------------------------------------------
  @! SECTION 1: JIT RAM Memory Boundaries & Buffer Safety
  @! --------------------------------------------------------------------------
  println("\n▶ Section 1: JIT RAM Memory Boundaries & W^X Lifecycle Stress")

  @! Test 1: Zero-byte allocation should safely fall back to 1 page (4096 bytes)
  b0 = jit_mem_alloc(0)
  assert_true(ctx, "ADV-JIT-MEM-01: Zero-size alloc returns valid block", b0.addr > 0)
  assert_eq(ctx, "ADV-JIT-MEM-02: Zero-size alloc aligned to 4096", b0.size, 4096)
  assert_eq(ctx, "ADV-JIT-MEM-03: Zero-size alloc capacity is 4096", b0.capacity, 4096)
  jit_mem_free(b0)

  @! Test 2: Multi-page large allocation (65536 bytes = 16 pages)
  b_large = jit_mem_alloc(65536)
  assert_true(ctx, "ADV-JIT-MEM-04: Large alloc (64KB) returns valid base addr", b_large.addr > 0)
  assert_eq(ctx, "ADV-JIT-MEM-05: Large alloc size is 65536", b_large.size, 65536)

  @! Test 3: Boundary writes on 64KB block (offset 0, offset capacity - 1)
  w_start = jit_mem_write_byte(b_large, 0, 0x90) @! NOP
  assert_eq(ctx, "ADV-JIT-MEM-06: Write at offset 0 succeeds", w_start, 1)
  r_start = jit_mem_read_byte(b_large, 0)
  assert_eq(ctx, "ADV-JIT-MEM-07: Read at offset 0 matches 0x90 (144)", r_start, 144)

  w_end = jit_mem_write_byte(b_large, 65535, 0xC3) @! RET
  assert_eq(ctx, "ADV-JIT-MEM-08: Write at offset capacity-1 succeeds", w_end, 1)
  r_end = jit_mem_read_byte(b_large, 65535)
  assert_eq(ctx, "ADV-JIT-MEM-09: Read at offset capacity-1 matches 0xC3 (195)", r_end, 195)

  @! Test 4: Out-of-bounds write prevention
  w_oob1 = jit_mem_write_byte(b_large, 65536, 0xCC) @! Past capacity
  assert_eq(ctx, "ADV-JIT-MEM-10: Write at exact capacity rejected", w_oob1, 0)

  w_oob2 = jit_mem_write_byte(b_large, 100000, 0xCC) @! Far past capacity
  assert_eq(ctx, "ADV-JIT-MEM-11: Write far past capacity rejected", w_oob2, 0)

  w_neg = jit_mem_write_byte(b_large, 0 - 1, 0xCC) @! Negative offset
  assert_eq(ctx, "ADV-JIT-MEM-12: Write at negative offset rejected", w_neg, 0)

  @! Test 5: Out-of-bounds read prevention
  r_oob1 = jit_mem_read_byte(b_large, 65536)
  assert_eq(ctx, "ADV-JIT-MEM-13: Read at exact capacity rejected", r_oob1, 0)

  r_neg = jit_mem_read_byte(b_large, 0 - 5)
  assert_eq(ctx, "ADV-JIT-MEM-14: Read at negative offset rejected", r_neg, 0)

  @! Test 6: Buffer overflow in write_bytes
  arr_small = [0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90]
  w_arr_oob = jit_mem_write_bytes(b_large, 65530, arr_small) @! 65530 + 8 = 65538 > 65536
  assert_eq(ctx, "ADV-JIT-MEM-15: Multi-byte write spanning past capacity rejected", w_arr_oob, 0)

  w_arr_fit = jit_mem_write_bytes(b_large, 65528, arr_small) @! 65528 + 8 = 65536 <= 65536
  assert_eq(ctx, "ADV-JIT-MEM-16: Multi-byte write fitting exactly at end succeeds", w_arr_fit, 8)

  @! Test 7: W^X protection state cycling
  p_rw = jit_mem_protect_rw(b_large)
  assert_eq(ctx, "ADV-JIT-MEM-17: Protect RW returns 0", p_rw, 0)
  assert_eq(ctx, "ADV-JIT-MEM-18: is_exec is 0 after RW protect", b_large.is_exec, 0)

  p_rx = jit_mem_protect_rx(b_large)
  assert_eq(ctx, "ADV-JIT-MEM-19: Protect RX returns 0", p_rx, 0)
  assert_eq(ctx, "ADV-JIT-MEM-20: is_exec is 1 after RX protect", b_large.is_exec, 1)

  p_rwx = jit_mem_protect_rwx(b_large)
  assert_eq(ctx, "ADV-JIT-MEM-21: Protect RWX returns 0", p_rwx, 0)
  assert_eq(ctx, "ADV-JIT-MEM-22: is_exec is 1 after RWX protect", b_large.is_exec, 1)

  @! Test 8: Memory Deallocation & Double Free idempotency
  free_res1 = jit_mem_free(b_large)
  assert_eq(ctx, "ADV-JIT-MEM-23: First free returns 0", free_res1, 0)
  assert_eq(ctx, "ADV-JIT-MEM-24: Block addr zeroed out after free", b_large.addr, 0)

  free_res2 = jit_mem_free(b_large)
  assert_eq(ctx, "ADV-JIT-MEM-25: Double free handles gracefully (returns 0)", free_res2, 0)

  @! --------------------------------------------------------------------------
  @! SECTION 2: Complex Arithmetic & Operator Precedence in RAM
  @! --------------------------------------------------------------------------
  println("\n▶ Section 2: Complex Arithmetic Expressions & Operator Precedence")

  engine = jit_engine_new()

  @! Test 2.1: Standard Precedence (* and / before + and -)
  res1 = jit_eval_expression(engine, "100 + 20 * 5 - 50 / 2")
  assert_eq(ctx, "ADV-JIT-ARITH-01: 100 + 20*5 - 50/2 == 175", res1.value, 175)

  @! Test 2.2: Deeply Nested Parentheses
  res2 = jit_eval_expression(engine, "((10 + 20) * (30 - 10)) / (5 + 5)")
  assert_eq(ctx, "ADV-JIT-ARITH-02: ((10+20)*(30-10))/(5+5) == 60", res2.value, 60)

  @! Test 2.3: Complex 4-level nested parentheses
  res3 = jit_eval_expression(engine, "((((2 + 3) * 4) - 5) * 2) + 10")
  assert_eq(ctx, "ADV-JIT-ARITH-03: ((((2+3)*4)-5)*2)+10 == 40", res3.value, 40)

  @! Test 2.4: Bitwise Shift and Masking
  res4 = jit_eval_expression(engine, "(1 * 256) | (pow2(4)) | 1")
  assert_eq(ctx, "ADV-JIT-ARITH-04: (pow2(8))|(pow2(4))|1 == 273", res4.value, 273)

  res5 = jit_eval_expression(engine, "((1 * 256) | 0x0F) & 0xFF")
  assert_eq(ctx, "ADV-JIT-ARITH-05: ((pow2(8))|0x0F) & 0xFF == 15", res5.value, 15)

  res6 = jit_eval_expression(engine, "0xAA ^ 0xFF")
  assert_eq(ctx, "ADV-JIT-ARITH-06: 0xAA ^ 0xFF == 85", res6.value, 85)

  @! Test 2.5: Zero handling & Large Constants
  res7 = jit_eval_expression(engine, "1000000 * 2 + 500000")
  assert_eq(ctx, "ADV-JIT-ARITH-07: 1000000*2 + 500000 == 2500000", res7.value, 2500000)

  res8 = jit_eval_expression(engine, "0 * 99999 + (0 - 42) + 42")
  assert_eq(ctx, "ADV-JIT-ARITH-08: 0*99999 + (0-42) + 42 == 0", res8.value, 0)

  @! --------------------------------------------------------------------------
  @! SECTION 3: Multi-Argument Functions & Deep Recursion in RAM
  @! --------------------------------------------------------------------------
  println("\n▶ Section 3: Multi-Argument Functions & Deep Recursion")

  @! Test 3.1: 0-Argument function
  src_fn0 = "@fn get_magic_constant()\n  return 1337\n@end\n"
  jit_compile_function(engine, "get_magic_constant", src_fn0)
  fn0_addr = jit_lookup_symbol(engine, "get_magic_constant")
  assert_true(ctx, "ADV-JIT-FN-01: 0-arg function compiled to RAM", fn0_addr > 0)
  val_fn0 = jit_invoke_fn0(fn0_addr)
  assert_eq(ctx, "ADV-JIT-FN-02: 0-arg function invocation returns 1337", val_fn0, 1337)

  @! Test 3.2: 1-Argument recursive Collatz step count
  src_collatz = "@fn collatz_steps(n)\n  steps = 0\n  curr = n\n  @while curr > 1\n    @if (curr % 2) == 0\n      curr = curr / 2\n    @else\n      curr = (curr * 3) + 1\n    @end\n    steps = steps + 1\n  @end\n  return steps\n@end\n"
  jit_compile_function(engine, "collatz_steps", src_collatz)
  fn_c_addr = jit_lookup_symbol(engine, "collatz_steps")
  assert_true(ctx, "ADV-JIT-FN-03: Collatz function compiled", fn_c_addr > 0)
  steps_27 = jit_invoke_fn1(fn_c_addr, 27)
  assert_eq(ctx, "ADV-JIT-FN-04: collatz_steps(27) == 111", steps_27, 111)

  @! Test 3.3: 2-Argument Power function
  src_pow = "@fn int_pow(base, exp)\n  res = 1\n  i = 0\n  @while i < exp\n    res = res * base\n    i = i + 1\n  @end\n  return res\n@end\n"
  jit_compile_function(engine, "int_pow", src_pow)
  fn_pow_addr = jit_lookup_symbol(engine, "int_pow")
  val_pow = jit_invoke_fn2(fn_pow_addr, 2, 16)
  assert_eq(ctx, "ADV-JIT-FN-05: int_pow(2, 16) == 65536", val_pow, 65536)

  @! Test 3.4: 3-Argument Linear Interpolator
  src_lerp = "@fn calc_lerp(a, b, t_pct)\n  return a + ((b - a) * t_pct / 100)\n@end\n"
  jit_compile_function(engine, "calc_lerp", src_lerp)
  fn_lerp_addr = jit_lookup_symbol(engine, "calc_lerp")
  val_lerp = jit_invoke_fn3(fn_lerp_addr, 100, 500, 50)
  assert_eq(ctx, "ADV-JIT-FN-06: calc_lerp(100, 500, 50) == 300", val_lerp, 300)

  @! Test 3.5: 4-Argument Weighted Sum
  src_wsum = "@fn weighted_sum4(w1, w2, w3, w4)\n  return (w1 * 1000) + (w2 * 100) + (w3 * 10) + w4\n@end\n"
  jit_compile_function(engine, "weighted_sum4", src_wsum)
  fn_wsum_addr = jit_lookup_symbol(engine, "weighted_sum4")
  val_wsum = jit_invoke_fn4(fn_wsum_addr, 9, 8, 7, 6)
  assert_eq(ctx, "ADV-JIT-FN-07: weighted_sum4(9, 8, 7, 6) == 9876", val_wsum, 9876)

  @! Test 3.6: Deep Recursive Fibonacci
  src_fib = "@fn fib_rec(n)\n  @if n <= 0 return 0 @end\n  @if n == 1 return 1 @end\n  return fib_rec(n - 1) + fib_rec(n - 2)\n@end\n"
  jit_compile_function(engine, "fib_rec", src_fib)
  fn_fib_addr = jit_lookup_symbol(engine, "fib_rec")
  val_fib12 = jit_invoke_fn1(fn_fib_addr, 12)
  assert_eq(ctx, "ADV-JIT-FN-08: Recursive fib_rec(12) == 144", val_fib12, 144)

  @! --------------------------------------------------------------------------
  @! SECTION 4: Interactive REPL Edge Cases & Persistence
  @! --------------------------------------------------------------------------
  println("\n▶ Section 4: Interactive REPL Edge Cases & Metacommands")

  repl_sess = repl_init()
  assert_eq(ctx, "ADV-REPL-01: Initial running state is 1", repl_sess.running, 1)

  @! Test 4.1: Empty and whitespace lines
  out_empty = repl_eval_line(repl_sess, "")
  assert_str_eq(ctx, "ADV-REPL-02: Empty line returns empty output", out_empty.output, "")
  assert_eq(ctx, "ADV-REPL-03: Empty line is not error", out_empty.is_error, 0)

  out_ws = repl_eval_line(repl_sess, "     ")
  assert_str_eq(ctx, "ADV-REPL-04: Pure whitespace returns empty output", out_ws.output, "")

  @! Test 4.2: Variable Definition & Multiple Updates
  repl_eval_line(repl_sess, "alpha = 50")
  repl_eval_line(repl_sess, "beta = 75")
  out_sum = repl_eval_line(repl_sess, "alpha + beta")
  assert_str_eq(ctx, "ADV-REPL-06: Evaluates alpha + beta == 125", out_sum.output, "125")

  @! Variable Shadowing / Update
  repl_eval_line(repl_sess, "alpha = 200")
  out_sum2 = repl_eval_line(repl_sess, "alpha + beta")
  assert_str_eq(ctx, "ADV-REPL-07: Evaluates updated alpha + beta == 275", out_sum2.output, "275")

  @! Test 4.3: Syntax Error resilience (should return error object, not crash)
  out_bad_syntax = repl_eval_line(repl_sess, "@fn ()\n@end")
  assert_eq(ctx, "ADV-REPL-07b: Malformed syntax error handled safely (is_error == 1)", out_bad_syntax.is_error, 1)

  @! Test 4.3b: Incomplete multiline detection
  assert_eq(ctx, "ADV-REPL-07c: Incomplete open parenthesis detected", repl_is_incomplete("((100 + 200"), 1)

  @! Test 4.4: Metacommands
  out_help = repl_handle_metacommand(repl_sess, ":help")
  assert_eq(ctx, "ADV-REPL-08: :help command executed", out_help.is_error, 0)

  out_vars = repl_handle_metacommand(repl_sess, ":vars")
  assert_eq(ctx, "ADV-REPL-09: :vars command lists variables", out_vars.is_error, 0)

  out_type = repl_handle_metacommand(repl_sess, ":type alpha")
  assert_eq(ctx, "ADV-REPL-10: :type returns i64", out_type.is_error, 0)

  out_bad_meta = repl_handle_metacommand(repl_sess, ":nonexistent_meta_cmd")
  assert_eq(ctx, "ADV-REPL-11: Invalid metacommand reports error", out_bad_meta.is_error, 1)

  @! Test 4.5: Clean Session Termination
  out_quit = repl_handle_metacommand(repl_sess, ":quit")
  assert_eq(ctx, "ADV-REPL-12: :quit sets session termination flag", out_quit.quit, 1)

  @! Cleanup
  jit_engine_free(engine)

  println("=================================================================")
  println("📊 ADVERSARIAL JIT & REPL SUITE SUMMARY")
  println("=================================================================")
  println("Total Assertions: " + ctx.total.to_str())
  println("Passed          : " + ctx.passed.to_str())
  println("Failed          : " + ctx.failed.to_str())
  println("=================================================================")

  @if ctx.failed == 0
    println("🎉 ALL ADVERSARIAL JIT TESTS PASSED! 🎉")
  @else
    println("❌ SOME ADVERSARIAL JIT TESTS FAILED!")
  @end
@end
