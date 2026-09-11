@! ============================================================================
@! MAYA JIT TEST SUITE: MULTI-ARGUMENT & RECURSIVE FUNCTION COMPILATION
@! Test File: tests/jit/test_jit_functions.maya
@! Verification: In-Memory Native JIT Function Definition & Multi-Arg Invocation
@! ============================================================================

import "compiler/backend/jit/jit_memory"
import "compiler/backend/jit/jit_executor"
import "compiler/backend/jit/jit_engine"

@struct TestContext
  total: 0
  passed: 0
  failed: 0
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

@fn assert_true(ctx, name, condition)
  ctx.total = ctx.total + 1
  @if condition != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was false (0)")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA JIT FUNCTIONS & RECURSION TEST SUITE")
  println("=================================================================")

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  engine = jit_engine_new()

  @! --------------------------------------------------------------------------
  @! 1. 0-Argument Function in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [1] 0-Argument Function ---")
  src0 = "@fn get_answer()\n  return 42\n@end\n"
  comp0 = jit_compile_source(engine, src0)
  assert_eq(ctx, "JIT-FN-01: Compile 0-arg function (success)", comp0.success, 1)
  fn0_addr = jit_lookup_symbol(engine, "get_answer")
  assert_true(ctx, "JIT-FN-02: Symbol 'get_answer' has valid RAM address", fn0_addr > 0)
  res0 = jit_invoke_fn0(fn0_addr)
  assert_eq(ctx, "JIT-FN-03: jit_invoke_fn0(get_answer)", res0, 42)

  @! --------------------------------------------------------------------------
  @! 2. 1-Argument Function in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [2] 1-Argument Function ---")
  src1 = "@fn square(x)\n  return x * x\n@end\n"
  comp1 = jit_compile_source(engine, src1)
  assert_eq(ctx, "JIT-FN-04: Compile 1-arg function (success)", comp1.success, 1)
  fn1_addr = jit_lookup_symbol(engine, "square")
  res1_a = jit_invoke_fn1(fn1_addr, 9)
  assert_eq(ctx, "JIT-FN-05: square(9) == 81", res1_a, 81)
  res1_b = jit_invoke_fn1(fn1_addr, 12)
  assert_eq(ctx, "JIT-FN-06: square(12) == 144", res1_b, 144)

  @! --------------------------------------------------------------------------
  @! 3. 2-Argument Function in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [3] 2-Argument Function ---")
  src2 = "@fn multiply(a, b)\n  return a * b\n@end\n"
  comp2 = jit_compile_source(engine, src2)
  assert_eq(ctx, "JIT-FN-07: Compile 2-arg function (success)", comp2.success, 1)
  fn2_addr = jit_lookup_symbol(engine, "multiply")
  res2 = jit_invoke_fn2(fn2_addr, 6, 7)
  assert_eq(ctx, "JIT-FN-08: multiply(6, 7) == 42", res2, 42)

  @! --------------------------------------------------------------------------
  @! 4. 3-Argument Function in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [4] 3-Argument Function ---")
  src3 = "@fn weighted_sum(w, a, b)\n  return w * a + b\n@end\n"
  comp3 = jit_compile_source(engine, src3)
  assert_eq(ctx, "JIT-FN-09: Compile 3-arg function (success)", comp3.success, 1)
  fn3_addr = jit_lookup_symbol(engine, "weighted_sum")
  res3 = jit_invoke_fn3(fn3_addr, 5, 10, 3)
  assert_eq(ctx, "JIT-FN-10: weighted_sum(5, 10, 3) == 53", res3, 53)

  @! --------------------------------------------------------------------------
  @! 5. 4-Argument Function in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [5] 4-Argument Function ---")
  src4 = "@fn calc4(a, b, c, d)\n  return (a + b) * (c - d)\n@end\n"
  comp4 = jit_compile_source(engine, src4)
  assert_eq(ctx, "JIT-FN-11: Compile 4-arg function (success)", comp4.success, 1)
  fn4_addr = jit_lookup_symbol(engine, "calc4")
  res4 = jit_invoke_fn4(fn4_addr, 10, 5, 8, 2)
  assert_eq(ctx, "JIT-FN-12: calc4(10, 5, 8, 2) == 90", res4, 90)

  @! --------------------------------------------------------------------------
  @! 6. Recursive Factorial in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [6] Recursive Factorial ---")
  src_fact = "@fn fact(n)\n  @if n <= 1 return 1 @end\n  return n * fact(n - 1)\n@end\n"
  comp_fact = jit_compile_source(engine, src_fact)
  assert_eq(ctx, "JIT-FN-13: Compile recursive factorial (success)", comp_fact.success, 1)
  fact_addr = jit_lookup_symbol(engine, "fact")
  assert_eq(ctx, "JIT-FN-14: fact(0) == 1", jit_invoke_fn1(fact_addr, 0), 1)
  assert_eq(ctx, "JIT-FN-15: fact(1) == 1", jit_invoke_fn1(fact_addr, 1), 1)
  assert_eq(ctx, "JIT-FN-16: fact(5) == 120", jit_invoke_fn1(fact_addr, 5), 120)
  assert_eq(ctx, "JIT-FN-17: fact(6) == 720", jit_invoke_fn1(fact_addr, 6), 720)

  @! --------------------------------------------------------------------------
  @! 7. Recursive Fibonacci in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [7] Recursive Fibonacci ---")
  src_fib = "@fn fib(n)\n  @if n <= 1 return n @end\n  return fib(n - 1) + fib(n - 2)\n@end\n"
  comp_fib = jit_compile_source(engine, src_fib)
  assert_eq(ctx, "JIT-FN-18: Compile recursive Fibonacci (success)", comp_fib.success, 1)
  fib_addr = jit_lookup_symbol(engine, "fib")
  assert_eq(ctx, "JIT-FN-19: fib(0) == 0", jit_invoke_fn1(fib_addr, 0), 0)
  assert_eq(ctx, "JIT-FN-20: fib(1) == 1", jit_invoke_fn1(fib_addr, 1), 1)
  assert_eq(ctx, "JIT-FN-21: fib(7) == 13", jit_invoke_fn1(fib_addr, 7), 13)
  assert_eq(ctx, "JIT-FN-22: fib(10) == 55", jit_invoke_fn1(fib_addr, 10), 55)

  @! --------------------------------------------------------------------------
  @! 8. Function Calling Another Function in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [8] Function Composition ---")
  src_comp = "@fn double_val(x)\n  return x * 2\n@end\n\n@fn quad_val(x)\n  return double_val(double_val(x))\n@end\n"
  comp_comp = jit_compile_source(engine, src_comp)
  assert_eq(ctx, "JIT-FN-23: Compile composed functions (success)", comp_comp.success, 1)
  quad_addr = jit_lookup_symbol(engine, "quad_val")
  assert_eq(ctx, "JIT-FN-24: quad_val(7) == 28", jit_invoke_fn1(quad_addr, 7), 28)

  @! --------------------------------------------------------------------------
  @! 9. Persistent Function Registration & Interactive Calling
  @! --------------------------------------------------------------------------
  println("\n--- [9] Persistent JIT Function Registration ---")
  cube_src = "@fn cube(x)\n  return x * x * x\n@end\n"
  jit_register_fn_source(engine, "cube", cube_src)

  eval_cube_res = jit_eval_expression(engine, "cube(4) + 10")
  assert_eq(ctx, "JIT-FN-25: Interactive expression calling registered cube(4) + 10 (success)", eval_cube_res.success, 1)
  assert_eq(ctx, "JIT-FN-26: cube(4) + 10 == 74", eval_cube_res.value, 74)

  jit_engine_free(engine)

  println("\n=================================================================")
  println("📊 JIT FUNCTIONS TEST SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + ctx.total.to_str())
  println("  Passed           : " + ctx.passed.to_str())
  println("  Failed           : " + ctx.failed.to_str())

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] All JIT Function compilation & invocation tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more JIT Function tests failed.")
    return 1
  @end
@end
