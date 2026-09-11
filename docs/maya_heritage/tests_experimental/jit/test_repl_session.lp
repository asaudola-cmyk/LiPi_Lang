@! ============================================================================
@! MAYA REPL TEST SUITE: INTERACTIVE REPL ENGINE SESSION SIMULATION
@! Test File: tests/jit/test_repl_session.maya
@! Verification: Metacommands, Persistent Variables, Multiline Input, Syntax Errors
@! ============================================================================

import "compiler/backend/jit/jit_memory"
import "compiler/backend/jit/jit_executor"
import "compiler/backend/jit/jit_engine"
import "compiler/backend/jit/repl"

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
  println("▶ MAYA INTERACTIVE REPL SESSION TEST SUITE")
  println("=================================================================")

  ctx = {
    total: 0,
    passed: 0,
    failed: 0
  }

  state = repl_init()

  @! --------------------------------------------------------------------------
  @! 1. REPL State Initialization
  @! --------------------------------------------------------------------------
  println("\n--- [1] REPL Initialization ---")
  assert_eq(ctx, "REPL-01: Running state is 1", state.running, 1)
  assert_str_eq(ctx, "REPL-02: Default prompt is 'maya > '", state.prompt, "maya > ")
  assert_str_eq(ctx, "REPL-03: Continuation prompt is '... '", state.prompt_cont, "... ")
  assert_eq(ctx, "REPL-04: Initial history is empty", state.history.len(), 0)
  assert_eq(ctx, "REPL-05: Initial variables list is empty", state.vars.len(), 0)

  @! --------------------------------------------------------------------------
  @! 2. Metacommands (:help, :vars, :type, :env, :clear, :quit)
  @! --------------------------------------------------------------------------
  println("\n--- [2] Metacommands ---")
  out_help = repl_eval_line(state, ":help")
  assert_eq(ctx, "REPL-06: :help succeeds", out_help.is_error, 0)
  assert_true(ctx, "REPL-07: :help output contains 'Maya Sovereign Interactive REPL'", str_index_of(out_help.output, "Maya Sovereign Interactive REPL") >= 0)

  out_vars_empty = repl_eval_line(state, ":vars")
  assert_str_eq(ctx, "REPL-08: :vars with no variables defined", out_vars_empty.output, "No variables currently defined.")

  out_type = repl_eval_line(state, ":type 40 + 2")
  assert_eq(ctx, "REPL-09: :type succeeds", out_type.is_error, 0)
  assert_true(ctx, "REPL-10: :type returns i64 = 42", str_index_of(out_type.output, "42") >= 0)

  out_env = repl_eval_line(state, ":env")
  assert_eq(ctx, "REPL-11: :env succeeds", out_env.is_error, 0)
  assert_true(ctx, "REPL-12: :env contains Memory Pages", str_index_of(out_env.output, "Memory Pages Allocated") >= 0)

  out_clear = repl_eval_line(state, ":clear")
  assert_eq(ctx, "REPL-13: :clear succeeds", out_clear.is_error, 0)

  @! --------------------------------------------------------------------------
  @! 3. Variable Binding & Persistence
  @! --------------------------------------------------------------------------
  println("\n--- [3] Variable Bindings & Environment Persistence ---")
  out_v1 = repl_eval_line(state, "x = 100")
  assert_eq(ctx, "REPL-14: Assignment x = 100 (is_error)", out_v1.is_error, 0)
  assert_str_eq(ctx, "REPL-15: Assignment x = 100 (output)", out_v1.output, "x = 100")

  out_v2 = repl_eval_line(state, "let y = x * 2")
  assert_eq(ctx, "REPL-16: Assignment let y = x * 2 (is_error)", out_v2.is_error, 0)
  assert_str_eq(ctx, "REPL-17: Assignment let y = x * 2 (output)", out_v2.output, "y = 200")

  out_expr_xy = repl_eval_line(state, "x + y")
  assert_eq(ctx, "REPL-18: Evaluation x + y (is_error)", out_expr_xy.is_error, 0)
  assert_str_eq(ctx, "REPL-19: Evaluation x + y == 300", out_expr_xy.output, "300")

  out_v3 = repl_eval_line(state, "lang = \"Maya\"")
  assert_eq(ctx, "REPL-20: String assignment lang = \"Maya\" (is_error)", out_v3.is_error, 0)
  assert_str_eq(ctx, "REPL-21: String assignment lang = \"Maya\" (output)", out_v3.output, "lang = \"Maya\"")

  out_vars = repl_eval_line(state, ":vars")
  assert_true(ctx, "REPL-22: :vars shows x", str_index_of(out_vars.output, "x") >= 0)
  assert_true(ctx, "REPL-23: :vars shows y", str_index_of(out_vars.output, "y") >= 0)
  assert_true(ctx, "REPL-24: :vars shows lang", str_index_of(out_vars.output, "lang") >= 0)

  @! --------------------------------------------------------------------------
  @! 4. Incremental Function Definition & Calling
  @! --------------------------------------------------------------------------
  println("\n--- [4] Incremental Function Definition ---")
  fn_def = "@fn mul_add(a, b, c)\n  return a * b + c\n@end"
  out_fn = repl_eval_line(state, fn_def)
  assert_eq(ctx, "REPL-25: Define function mul_add (is_error)", out_fn.is_error, 0)
  assert_true(ctx, "REPL-26: Output confirms mul_add definition", str_index_of(out_fn.output, "Defined function: mul_add") >= 0)

  out_fn_call = repl_eval_line(state, "mul_add(x, 2, 50)")
  assert_eq(ctx, "REPL-27: Call mul_add(100, 2, 50) (is_error)", out_fn_call.is_error, 0)
  assert_str_eq(ctx, "REPL-28: mul_add(100, 2, 50) == 250", out_fn_call.output, "250")

  @! --------------------------------------------------------------------------
  @! 5. Multiline Input Continuation
  @! --------------------------------------------------------------------------
  println("\n--- [5] Multiline Continuation ---")
  assert_eq(ctx, "REPL-29: repl_is_incomplete('2 + ') is true", repl_is_incomplete("2 + "), 1)
  assert_eq(ctx, "REPL-30: repl_is_incomplete('(10 + 20') is true", repl_is_incomplete("(10 + 20"), 1)
  assert_eq(ctx, "REPL-31: repl_is_incomplete('@fn foo(x)') is true", repl_is_incomplete("@fn foo(x)"), 1)
  assert_eq(ctx, "REPL-32: repl_is_incomplete('10 + 20') is false", repl_is_incomplete("10 + 20"), 0)

  @! Feed line 1 of multiline expression
  ml_1 = repl_eval_line(state, "(10 +")
  assert_eq(ctx, "REPL-33: Line 1 triggers is_incomplete", ml_1.is_incomplete, 1)

  @! Feed line 2 of multiline expression
  ml_2 = repl_eval_line(state, "20)")
  assert_eq(ctx, "REPL-34: Line 2 completes construct", ml_2.is_incomplete, 0)
  assert_str_eq(ctx, "REPL-35: Multiline (10 + 20) evaluates to 30", ml_2.output, "30")

  @! --------------------------------------------------------------------------
  @! 6. Syntax Error Handling & Recovery
  @! --------------------------------------------------------------------------
  println("\n--- [6] Syntax Error Handling ---")
  out_err = repl_eval_line(state, "@fn ()\n@end")
  assert_eq(ctx, "REPL-36: Malformed function syntax error flagged (is_error == 1)", out_err.is_error, 1)
  assert_true(ctx, "REPL-37: Error output contains descriptive message", str_index_of(out_err.output, "Error") >= 0)

  @! Verify REPL state remains intact after error
  out_post_err = repl_eval_line(state, "50 + 50")
  assert_eq(ctx, "REPL-38: Expression evaluates cleanly after error", out_post_err.is_error, 0)
  assert_str_eq(ctx, "REPL-39: 50 + 50 == 100", out_post_err.output, "100")

  @! --------------------------------------------------------------------------
  @! 7. Session Termination (:quit)
  @! --------------------------------------------------------------------------
  println("\n--- [7] Session Termination ---")
  out_quit = repl_eval_line(state, ":quit")
  assert_eq(ctx, "REPL-40: :quit sets quit flag", out_quit.quit, 1)
  assert_eq(ctx, "REPL-41: :quit sets running to 0", state.running, 0)

  jit_engine_free(state.engine)

  println("\n=================================================================")
  println("📊 REPL SESSION TEST SUMMARY")
  println("=================================================================")
  println("  Total Assertions : " + ctx.total.to_str())
  println("  Passed           : " + ctx.passed.to_str())
  println("  Failed           : " + ctx.failed.to_str())

  @if ctx.failed == 0
    println("\n✓ [SUCCESS] All Interactive REPL tests passed!")
    return 0
  @else
    println("\n✗ [FAILURE] One or more REPL tests failed.")
    return 1
  @end
@end
