@! ============================================================================
@! MAYA COMPILER OPTIMIZER TEST SUITE
@! File: tests/compiler/test_optimizer.maya
@! Tests:
@!   1. Constant Folding (BinaryOp Arithmetic: +, -, *, /, <<, >>)
@!   2. Algebraic Strength Reduction (* 0, * 1, * 2/4/8 -> <<, / 2/4/8 -> >>, + 0, - 0)
@!   3. Common Subexpression Elimination (CSE)
@!   4. Dead Code Elimination (DCE)
@!   5. Tail Call Optimization (TCO)
@!   6. Loop Invariant Code Motion (LICM) & Loop Unrolling
@!   7. Function Inlining & Global Value Numbering (GVN)
@!   8. Linear IR Instruction-Level Constant Folding & Propagation
@!   9. Master Optimization Pipeline (optimize_ast / opt_optimize_program)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/middleend/optimizer"

@fn assert_eq_int(actual, expected, msg)
  @if actual == expected
    return 1
  @else
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(to_str(expected), str_concat(", got ", to_str(actual)))))))
    return 0
  @end
@end

@fn assert_eq_str(actual, expected, msg)
  @if str_eq(actual, expected) == 1
    return 1
  @else
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected '", str_concat(expected, str_concat("', got '", str_concat(actual, "'")))))))
    return 0
  @end
@end

@fn assert_true(cond, msg)
  @if cond == 1
    return 1
  @else
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("⚙️  MAYA COMPILER OPTIMIZER & IR TRANSFORMATION TEST SUITE ⚙️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ============================================================================
  @! SECTION 1: Constant Folding (Basic Arithmetic)
  @! ============================================================================
  println("▶ Section 1: Constant Folding on AST Binary Expressions...")
  total_tests = total_tests + 1

  @! 1.1 Addition: 15 + 27 = 42
  e_add = { type: "BinaryOp", kind: "BinaryOp", op: "+", left: { type: "IntLiteral", kind: "LiteralInt", value: 15, val: 15 }, right: { type: "IntLiteral", kind: "LiteralInt", value: 27, val: 27 } }
  f_add = fold_constants(e_add)
  ok1_1 = assert_eq_int(f_add.value, 42, "15 + 27 constant folded to 42")

  @! 1.2 Subtraction: 100 - 58 = 42
  e_sub = { type: "BinaryOp", kind: "BinaryOp", op: "-", left: { type: "IntLiteral", kind: "LiteralInt", value: 100, val: 100 }, right: { type: "IntLiteral", kind: "LiteralInt", value: 58, val: 58 } }
  f_sub = fold_constants(e_sub)
  ok1_2 = assert_eq_int(f_sub.value, 42, "100 - 58 constant folded to 42")

  @! 1.3 Multiplication: 6 * 7 = 42
  e_mul = { type: "BinaryOp", kind: "BinaryOp", op: "*", left: { type: "IntLiteral", kind: "LiteralInt", value: 6, val: 6 }, right: { type: "IntLiteral", kind: "LiteralInt", value: 7, val: 7 } }
  f_mul = fold_constants(e_mul)
  ok1_3 = assert_eq_int(f_mul.value, 42, "6 * 7 constant folded to 42")

  @! 1.4 Division: 126 / 3 = 42
  e_div = { type: "BinaryOp", kind: "BinaryOp", op: "/", left: { type: "IntLiteral", kind: "LiteralInt", value: 126, val: 126 }, right: { type: "IntLiteral", kind: "LiteralInt", value: 3, val: 3 } }
  f_div = fold_constants(e_div)
  ok1_4 = assert_eq_int(f_div.value, 42, "126 / 3 constant folded to 42")

  @! 1.5 Nested Folding: (10 + 5) * (4 - 2) = 30
  e_nested = { type: "BinaryOp", kind: "BinaryOp", op: "*", left: { type: "BinaryOp", kind: "BinaryOp", op: "+", left: { type: "IntLiteral", kind: "LiteralInt", value: 10, val: 10 }, right: { type: "IntLiteral", kind: "LiteralInt", value: 5, val: 5 } }, right: { type: "BinaryOp", kind: "BinaryOp", op: "-", left: { type: "IntLiteral", kind: "LiteralInt", value: 4, val: 4 }, right: { type: "IntLiteral", kind: "LiteralInt", value: 2, val: 2 } } }
  f_nested = fold_constants(e_nested)
  ok1_5 = assert_eq_int(f_nested.value, 30, "(10 + 5) * (4 - 2) folded to 30")

  @! 1.6 Call Arguments Constant Folding
  c_args = [
    { type: "BinaryOp", kind: "BinaryOp", op: "+", left: { type: "IntLiteral", kind: "LiteralInt", value: 1, val: 1 }, right: { type: "IntLiteral", kind: "LiteralInt", value: 2, val: 2 } },
    { type: "BinaryOp", kind: "BinaryOp", op: "*", left: { type: "IntLiteral", kind: "LiteralInt", value: 3, val: 3 }, right: { type: "IntLiteral", kind: "LiteralInt", value: 4, val: 4 } }
  ]
  e_call = { type: "Call", kind: "Call", callee: { type: "Identifier", name: "foo" }, func: { type: "Identifier", name: "foo" }, args: c_args }
  f_call = fold_constants(e_call)
  ok1_6 = assert_eq_int(f_call.args[0].value, 3, "Call arg 0 folded to 3")
  ok1_7 = assert_eq_int(f_call.args[1].value, 12, "Call arg 1 folded to 12")

  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1 && ok1_4 == 1 && ok1_5 == 1 && ok1_6 == 1 && ok1_7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Constant folding on arithmetic expressions verified")
  @end

  @! ============================================================================
  @! SECTION 2: Algebraic Strength Reduction
  @! ============================================================================
  println("▶ Section 2: Algebraic Strength Reduction (Powers of 2, Identities)...")
  total_tests = total_tests + 1

  var_x = { type: "Identifier", name: "x" }

  @! 2.1 x * 0 -> 0
  e_mul0 = { type: "BinaryOp", kind: "BinaryOp", op: "*", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 0, val: 0 } }
  f_mul0 = fold_constants(e_mul0)
  ok2_1 = assert_eq_int(f_mul0.value, 0, "x * 0 reduced to 0")

  @! 2.2 x * 1 -> x
  e_mul1 = { type: "BinaryOp", kind: "BinaryOp", op: "*", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 1, val: 1 } }
  f_mul1 = fold_constants(e_mul1)
  ok2_2 = assert_eq_str(f_mul1.name, "x", "x * 1 reduced to x")

  @! 2.3 x * 2 -> x << 1
  e_mul2 = { type: "BinaryOp", kind: "BinaryOp", op: "*", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 2, val: 2 } }
  f_mul2 = fold_constants(e_mul2)
  ok2_3 = assert_eq_str(f_mul2.op, "<<", "x * 2 converted to left shift <<")
  ok2_4 = assert_eq_int(f_mul2.right.value, 1, "x * 2 shift amount is 1")

  @! 2.4 x * 4 -> x << 2
  e_mul4 = { type: "BinaryOp", kind: "BinaryOp", op: "*", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 4, val: 4 } }
  f_mul4 = fold_constants(e_mul4)
  ok2_5 = assert_eq_str(f_mul4.op, "<<", "x * 4 converted to left shift <<")
  ok2_6 = assert_eq_int(f_mul4.right.value, 2, "x * 4 shift amount is 2")

  @! 2.5 x * 8 -> x << 3
  e_mul8 = { type: "BinaryOp", kind: "BinaryOp", op: "*", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 8, val: 8 } }
  f_mul8 = fold_constants(e_mul8)
  ok2_7 = assert_eq_str(f_mul8.op, "<<", "x * 8 converted to left shift <<")
  ok2_8 = assert_eq_int(f_mul8.right.value, 3, "x * 8 shift amount is 3")

  @! 2.6 x / 1 -> x
  e_div1 = { type: "BinaryOp", kind: "BinaryOp", op: "/", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 1, val: 1 } }
  f_div1 = fold_constants(e_div1)
  ok2_9 = assert_eq_str(f_div1.name, "x", "x / 1 reduced to x")

  @! 2.7 x / 2 -> x >> 1
  e_div2 = { type: "BinaryOp", kind: "BinaryOp", op: "/", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 2, val: 2 } }
  f_div2 = fold_constants(e_div2)
  ok2_10 = assert_eq_str(f_div2.op, ">>", "x / 2 converted to right shift >>")
  ok2_11 = assert_eq_int(f_div2.right.value, 1, "x / 2 shift amount is 1")

  @! 2.8 x / 4 -> x >> 2
  e_div4 = { type: "BinaryOp", kind: "BinaryOp", op: "/", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 4, val: 4 } }
  f_div4 = fold_constants(e_div4)
  ok2_12 = assert_eq_str(f_div4.op, ">>", "x / 4 converted to right shift >>")
  ok2_13 = assert_eq_int(f_div4.right.value, 2, "x / 4 shift amount is 2")

  @! 2.9 x / 8 -> x >> 3
  e_div8 = { type: "BinaryOp", kind: "BinaryOp", op: "/", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 8, val: 8 } }
  f_div8 = fold_constants(e_div8)
  ok2_14 = assert_eq_str(f_div8.op, ">>", "x / 8 converted to right shift >>")
  ok2_15 = assert_eq_int(f_div8.right.value, 3, "x / 8 shift amount is 3")

  @! 2.10 Identity Add & Sub: x + 0 -> x, x - 0 -> x
  e_add0 = { type: "BinaryOp", kind: "BinaryOp", op: "+", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 0, val: 0 } }
  f_add0 = fold_constants(e_add0)
  ok2_16 = assert_eq_str(f_add0.name, "x", "x + 0 reduced to x")

  e_sub0 = { type: "BinaryOp", kind: "BinaryOp", op: "-", left: var_x, right: { type: "IntLiteral", kind: "LiteralInt", value: 0, val: 0 } }
  f_sub0 = fold_constants(e_sub0)
  ok2_17 = assert_eq_str(f_sub0.name, "x", "x - 0 reduced to x")

  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1 && ok2_5 == 1 && ok2_6 == 1 && ok2_7 == 1 && ok2_8 == 1 && ok2_9 == 1 && ok2_10 == 1 && ok2_11 == 1 && ok2_12 == 1 && ok2_13 == 1 && ok2_14 == 1 && ok2_15 == 1 && ok2_16 == 1 && ok2_17 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Algebraic strength reduction verified")
  @end

  @! ============================================================================
  @! SECTION 3: Common Subexpression Elimination (CSE)
  @! ============================================================================
  println("▶ Section 3: Common Subexpression Elimination (CSE)...")
  total_tests = total_tests + 1

  @! stmts:
  @!   t1 = a + b
  @!   t2 = a + b   -> should be rewritten to t2 = t1
  cse_stmts = [
    { type: "VarDecl", name: "t1", expr: { type: "BinaryOp", op: "+", left: { type: "Identifier", name: "a" }, right: { type: "Identifier", name: "b" } } },
    { type: "VarDecl", name: "t2", expr: { type: "BinaryOp", op: "+", left: { type: "Identifier", name: "a" }, right: { type: "Identifier", name: "b" } } }
  ]
  opt_cse = apply_cse(cse_stmts)
  ok3_1 = assert_eq_int(opt_cse.len(), 2, "CSE preserved statement count")
  ok3_2 = assert_eq_str(opt_cse[0].name, "t1", "First statement is t1")
  ok3_3 = assert_eq_str(opt_cse[1].name, "t2", "Second statement is t2")
  ok3_4 = assert_eq_str(opt_cse[1].expr.type, "Identifier", "t2 RHS rewritten to Identifier")
  ok3_5 = assert_eq_str(opt_cse[1].expr.name, "t1", "t2 RHS points to t1")

  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1 && ok3_4 == 1 && ok3_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Common subexpression elimination verified")
  @end

  @! ============================================================================
  @! SECTION 4: Dead Code Elimination (DCE)
  @! ============================================================================
  println("▶ Section 4: Dead Code Elimination (DCE)...")
  total_tests = total_tests + 1

  @! stmts:
  @!   dead_a = 100   (never used)
  @!   live_b = 42    (used in return)
  @!   dead_c = 200   (never used)
  @!   return live_b
  dce_stmts = [
    { type: "VarDecl", name: "dead_a", expr: { type: "IntLiteral", value: 100 } },
    { type: "VarDecl", name: "live_b", expr: { type: "IntLiteral", value: 42 } },
    { type: "VarDecl", name: "dead_c", expr: { type: "IntLiteral", value: 200 } },
    { type: "ReturnStmt", expr: { type: "Identifier", name: "live_b" } }
  ]
  opt_dce = apply_dce(dce_stmts)
  ok4_1 = assert_eq_int(opt_dce.len(), 2, "DCE stripped dead statements (4 -> 2)")
  ok4_2 = assert_eq_str(opt_dce[0].name, "live_b", "First statement is live_b")
  ok4_3 = assert_eq_str(opt_dce[1].type, "ReturnStmt", "Second statement is ReturnStmt")

  @if ok4_1 == 1 && ok4_2 == 1 && ok4_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Dead code elimination verified")
  @end

  @! ============================================================================
  @! SECTION 5: Tail Call Optimization (TCO)
  @! ============================================================================
  println("▶ Section 5: Tail Call Optimization (TCO)...")
  total_tests = total_tests + 1

  @! Function that ends with recursive tail call
  tco_stmts = [
    { type: "ReturnStmt", expr: { type: "Call", callee: { type: "Identifier", name: "recurse_fn" }, args: [] } }
  ]
  opt_tco = apply_tco("recurse_fn", tco_stmts)
  ok5_1 = assert_eq_int(opt_tco[0].is_tco, 1, "Tail call flagged with is_tco = 1")

  @! Function that ends with non-tail call or different callee
  non_tco_stmts = [
    { type: "ReturnStmt", expr: { type: "Call", callee: { type: "Identifier", name: "other_fn" }, args: [] } }
  ]
  opt_non_tco = apply_tco("recurse_fn", non_tco_stmts)
  ok5_2 = assert_true(opt_non_tco[0].is_tco == 0, "Non-matching callee not flagged for TCO")

  @if ok5_1 == 1 && ok5_2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Tail call optimization detection verified")
  @end

  @! ============================================================================
  @! SECTION 6: Loop Invariant Code Motion (LICM) & Inlining
  @! ============================================================================
  println("▶ Section 6: Loop Invariant Code Motion (LICM) & Inlining Heuristics...")
  total_tests = total_tests + 1

  @! LICM: while loop containing invariant constant declaration
  while_body = [
    { type: "VarDecl", name: "const_k", expr: { type: "IntLiteral", value: 1024 } },
    { type: "ExprStmt", expr: { type: "Identifier", name: "work" } }
  ]
  licm_stmts = [
    { type: "WhileStmt", cond: { type: "Identifier", name: "running" }, body: while_body }
  ]
  opt_licm = apply_licm(licm_stmts)
  ok6_1 = assert_eq_int(opt_licm.len(), 2, "LICM hoisted invariant outside loop (1 -> 2 statements)")
  ok6_2 = assert_eq_str(opt_licm[0].name, "const_k", "Hoisted statement is const_k")
  ok6_3 = assert_eq_int(opt_licm[1].body.len(), 1, "Loop body size reduced to 1 statement")

  @! Inlining heuristic
  small_func = { name: "small", body: [ { type: "ReturnStmt", expr: 0 } ] }
  big_body = [
    { type: "ExprStmt", expr: 0 },
    { type: "ExprStmt", expr: 0 },
    { type: "ExprStmt", expr: 0 },
    { type: "ExprStmt", expr: 0 },
    { type: "ExprStmt", expr: 0 },
    { type: "ReturnStmt", expr: 0 }
  ]
  big_func = { name: "big", body: big_body }
  ok6_4 = assert_eq_int(should_inline(small_func), 1, "Small function (< 5 stmts) marked for inlining")
  ok6_5 = assert_eq_int(should_inline(big_func), 0, "Large function (>= 5 stmts) not marked for inlining")

  @if ok6_1 == 1 && ok6_2 == 1 && ok6_3 == 1 && ok6_4 == 1 && ok6_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] LICM hoisting and inlining heuristics verified")
  @end

  @! ============================================================================
  @! SECTION 7: Linear IR Constant Folding & Propagation Engine
  @! ============================================================================
  println("▶ Section 7: Linear IR Instruction-Level Constant Folding...")
  total_tests = total_tests + 1

  mir_insts = [
    { op: "CONST_INT", dest: "%t0", val: 20 },
    { op: "CONST_INT", dest: "%t1", val: 22 },
    { op: "BINOP", binop: "+", dest: "%t2", left: "%t0", right: "%t1" },
    { op: "CONST_INT", dest: "%t3", val: 2 },
    { op: "BINOP", binop: "*", dest: "%t4", left: "%t2", right: "%t3" },
    { op: "RETURN", val: "%t4" }
  ]
  opt_mir = opt_constant_fold_insts(mir_insts)
  ok7_1 = assert_eq_int(opt_mir.len(), 6, "IR instruction count preserved")
  ok7_2 = assert_eq_str(opt_mir[2].op, "CONST_INT", "%t2 folded to CONST_INT")
  ok7_3 = assert_eq_int(opt_mir[2].val, 42, "%t2 value is 20 + 22 = 42")
  ok7_4 = assert_eq_str(opt_mir[4].op, "CONST_INT", "%t4 folded to CONST_INT")
  ok7_5 = assert_eq_int(opt_mir[4].val, 84, "%t4 value is 42 * 2 = 84")

  @if ok7_1 == 1 && ok7_2 == 1 && ok7_3 == 1 && ok7_4 == 1 && ok7_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Linear IR instruction constant folding verified")
  @end

  @! ============================================================================
  @! SECTION 8: Master Optimization Pipeline (opt_optimize_program)
  @! ============================================================================
  println("▶ Section 8: Master AST Multi-Pass Optimization Pipeline...")
  total_tests = total_tests + 1

  fn_body = [
    { type: "VarDecl", name: "unused_var", expr: { type: "BinaryOp", op: "+", left: { type: "IntLiteral", value: 10 }, right: { type: "IntLiteral", value: 20 } } },
    { type: "VarDecl", name: "result", expr: { type: "BinaryOp", op: "*", left: { type: "IntLiteral", value: 6 }, right: { type: "IntLiteral", value: 7 } } },
    { type: "ReturnStmt", expr: { type: "Identifier", name: "result" } }
  ]
  mock_func = {
    type: "Function",
    name: "calc",
    body: fn_body
  }
  ast_program = [mock_func]
  opt_program = opt_optimize_program(ast_program)
  ok8_1 = assert_eq_int(opt_program.len(), 1, "Pipeline returned 1 function")
  res_func = opt_program[0]
  ok8_2 = assert_eq_str(res_func.name, "calc", "Function name preserved")
  @! In fn_body: unused_var is dead and eliminated by DCE!
  @! result = 6 * 7 is folded to 42!
  @! result is returned!
  ok8_3 = assert_eq_int(res_func.body.len(), 2, "DCE eliminated unused_var (3 stmts -> 2 stmts)")
  ok8_4 = assert_eq_str(res_func.body[0].name, "result", "First remaining stmt is result")
  ok8_5 = assert_eq_int(res_func.body[0].expr.value, 42, "result constant folded to 42")

  @if ok8_1 == 1 && ok8_2 == 1 && ok8_3 == 1 && ok8_4 == 1 && ok8_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Master multi-pass optimization pipeline verified")
  @end

  println("=================================================================")
  res_str = str_concat("📊 COMPILER OPTIMIZER TEST RESULTS: ", str_concat(to_str(passed_tests), str_concat(" / ", str_concat(to_str(total_tests), " passed"))))
  println(res_str)
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL 8 COMPILER OPTIMIZER TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME COMPILER OPTIMIZER TESTS FAILED")
    return 1
  @end
@end
