@! ============================================================================
@! MAYA JIT TEST SUITE: IMMEDIATE ARITHMETIC & EXPRESSION EVALUATION
@! Test File: tests/jit/test_jit_arithmetic.maya
@! Verification: Zero Disk I/O In-Memory Expression JIT Execution
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

@fn test_eval(ctx, engine, name, expr_str, expected_val)
  res = jit_eval_expression(engine, expr_str)
  assert_eq(ctx, name + " (success)", res.success, 1)
  assert_eq(ctx, name + " (value)", res.value, expected_val)
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA JIT ARITHMETIC & EXPRESSION EVALUATION TEST SUITE")
  println("=================================================================")

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  engine = jit_engine_new()

  @! --------------------------------------------------------------------------
  @! 1. Basic Arithmetic Operations in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [1] Basic Arithmetic In RAM ---")
  test_eval(ctx, engine, "JIT-ARITH-01: Addition (2 + 3)", "2 + 3", 5)
  test_eval(ctx, engine, "JIT-ARITH-02: Subtraction (100 - 45)", "100 - 45", 55)
  test_eval(ctx, engine, "JIT-ARITH-03: Multiplication (7 * 8)", "7 * 8", 56)
  test_eval(ctx, engine, "JIT-ARITH-04: Integer Division (144 / 12)", "144 / 12", 12)
  test_eval(ctx, engine, "JIT-ARITH-05: Modulo Division (17 % 5)", "17 % 5", 2)

  @! --------------------------------------------------------------------------
  @! 2. Operator Precedence & Parenthesization
  @! --------------------------------------------------------------------------
  println("\n--- [2] Operator Precedence & Grouping ---")
  test_eval(ctx, engine, "JIT-ARITH-06: Precedence (2 + 3 * 4)", "2 + 3 * 4", 14)
  test_eval(ctx, engine, "JIT-ARITH-07: Grouping ((2 + 3) * 4)", "(2 + 3) * 4", 20)
  test_eval(ctx, engine, "JIT-ARITH-08: Mixed Precedence (100 - 20 / 4 + 3 * 2)", "100 - 20 / 4 + 3 * 2", 101)
  test_eval(ctx, engine, "JIT-ARITH-09: Nested Parentheses (((10 + 20) * 3 - 10) / 4 + 2)", "((10 + 20) * 3 - 10) / 4 + 2", 22)

  @! --------------------------------------------------------------------------
  @! 3. Bitwise Operations in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [3] Bitwise Operations ---")
  test_eval(ctx, engine, "JIT-ARITH-10: Bitwise AND 15 & 7", "15 & 7", 7)
  test_eval(ctx, engine, "JIT-ARITH-11: Bitwise OR (8 | 4)", "8 | 4", 12)
  test_eval(ctx, engine, "JIT-ARITH-12: Bitwise XOR (15 ^ 6)", "15 ^ 6", 9)
  test_eval(ctx, engine, "JIT-ARITH-13: Left Shift (pow2(4))", "pow2(4)", 16)
  test_eval(ctx, engine, "JIT-ARITH-14: Right Shift (64 >> 2)", "64 >> 2", 16)

  @! --------------------------------------------------------------------------
  @! 4. Comparisons & Relational Logic
  @! --------------------------------------------------------------------------
  println("\n--- [4] Comparison & Relational Expressions ---")
  test_eval(ctx, engine, "JIT-ARITH-15: Greater Than (10 > 5)", "10 > 5", 1)
  test_eval(ctx, engine, "JIT-ARITH-16: Less Than (10 < 5)", "10 < 5", 0)
  test_eval(ctx, engine, "JIT-ARITH-17: Equality (42 == 42)", "42 == 42", 1)
  test_eval(ctx, engine, "JIT-ARITH-18: Inequality (42 != 99)", "42 != 99", 1)
  test_eval(ctx, engine, "JIT-ARITH-19: Greater Equal (10 >= 10)", "10 >= 10", 1)
  test_eval(ctx, engine, "JIT-ARITH-20: Less Equal (5 <= 8)", "5 <= 8", 1)

  @! --------------------------------------------------------------------------
  @! 5. Math Builtin Function Evaluation in RAM
  @! --------------------------------------------------------------------------
  println("\n--- [5] Math Builtins in RAM ---")
  test_eval(ctx, engine, "JIT-ARITH-21: math_sqrt(144)", "math_sqrt(144)", 12)
  test_eval(ctx, engine, "JIT-ARITH-22: math_abs(0 - 99)", "math_abs(0 - 99)", 99)
  test_eval(ctx, engine, "JIT-ARITH-23: math_max(10, 25)", "math_max(10, 25)", 25)
  test_eval(ctx, engine, "JIT-ARITH-24: math_min(10, 25)", "math_min(10, 25)", 10)

  @! --------------------------------------------------------------------------
  @! 6. One-Shot Convenience Execution (jit_compile_and_exec)
  @! --------------------------------------------------------------------------
  println("\n--- [6] One-Shot In-Memory Execution ---")
  one_shot_res = jit_compile_and_exec("@fn main()\n  return 1000 + 337\n@end\n")
  assert_eq(ctx, "JIT-ARITH-25: jit_compile_and_exec one-shot evaluation", one_shot_res, 1337)

  jit_engine_free(engine)

  println("\n=================================================================")
  println("📊 JIT ARITHMETIC TEST SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + ctx.total.to_str())
  println("  Passed           : " + ctx.passed.to_str())
  println("  Failed           : " + ctx.failed.to_str())

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] All JIT Arithmetic tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more JIT Arithmetic tests failed.")
    return 1
  @end
@end
