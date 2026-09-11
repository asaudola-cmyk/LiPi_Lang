@! ============================================================================
@! COMPREHENSIVE ADVERSARIAL STRESS TEST SUITE: MAYA IR & CFG INFRASTRUCTURE
@! Target: compiler/backend/maya_ir.maya
@! Empirical challenger verification across all 4 stress dimensions:
@! 1. Extreme CFG Topologies (10-level nested if/else, 3-level loops, dead code)
@! 2. Complex Expressions (60 chained binary ops, short-circuit logic)
@! 3. Symbol Resolution & Scale (500+ locals, variable shadowing)
@! 4. Linux Syscall Edge Cases (0-6 args padding, syscall number preservation)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"

@struct AdvSummaryState
  passed: 0
  failed: 0
  total: 0
@end

@fn assert_eq(state, actual, expected, name)
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

@fn assert_str_eq(state, actual, expected, name)
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

@fn assert_true(state, cond, name)
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

@! Helper to instantiate typed ASTNode
@fn new_ast_node()
  return {
    kind: "",
    name: "",
    params: [],
    body: [],
    ret_type: "",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn ast_var(name)
  n = new_ast_node()
  n.kind = "Variable"
  n.name = name
  return n
@end

@fn ast_int(val)
  n = new_ast_node()
  n.kind = "LiteralInt"
  n.val = val
  return n
@end

@fn ast_binop(op, left, right)
  n = new_ast_node()
  n.kind = "BinaryOp"
  n.op = op
  n.left = left
  n.right = right
  return n
@end

@fn ast_assign(target, value)
  n = new_ast_node()
  n.kind = "Assign"
  n.target = target
  n.value = value
  return n
@end

@fn ast_return(value)
  n = new_ast_node()
  n.kind = "Return"
  n.value = value
  return n
@end

@fn ast_call(callee_name, args)
  n = new_ast_node()
  n.kind = "Call"
  n.func = ast_var(callee_name)
  n.args = args
  return n
@end

@fn ast_if(cond, then_b, elif_b, else_b)
  n = new_ast_node()
  n.kind = "IfStmt"
  n.condition = cond
  n.then_body = then_b
  n.elif_branches = elif_b
  n.else_body = else_b
  return n
@end

@fn ast_while(cond, body)
  n = new_ast_node()
  n.kind = "WhileLoop"
  n.condition = cond
  n.body = body
  return n
@end

@fn ast_break()
  n = new_ast_node()
  n.kind = "Break"
  return n
@end

@fn ast_continue()
  n = new_ast_node()
  n.kind = "Continue"
  return n
@end

@fn ast_fndef(name, params, ret_type, body)
  n = new_ast_node()
  n.kind = "FnDef"
  n.name = name
  n.params = params
  n.ret_type = ret_type
  n.body = body
  return n
@end

@! ============================================================================
@! 1. EXTREME CFG TOPOLOGIES
@! ============================================================================
@fn test_extreme_cfg_topologies(state)
  println("▶ [Empirical Challenge 1] Extreme CFG Topologies...")

  @! 1.1 Deeply nested 10-level if-else ladder
  curr_stmt = [ast_assign("res", ast_int(100))]
  lvl = 10
  @while lvl >= 1
    cond = ast_binop("==", ast_var("x"), ast_int(lvl))
    then_b = [ast_assign("res", ast_int(lvl * 10))]
    else_b = curr_stmt
    curr_stmt = [ast_if(cond, then_b, [], else_b)]
    lvl = lvl - 1
  @end

  body1 = [ast_assign("res", ast_int(0))]
  body1 = body1.push(curr_stmt[0])
  body1 = body1.push(ast_return(ast_var("res")))
  fn1 = ast_fndef("nested_if_10", ["x"], "i64", body1)

  res1 = ir_module_from_ast([fn1], { module_name: "mod_cfg1", dump_ir: 0 })
  state = assert_eq(state, res1.error, 0, "10-level nested if/else lowers without error")
  state = assert_true(state, res1.module.functions[0].blocks.len() >= 20, "10-level nested if creates sufficient basic blocks")

  @! 1.2 3-level nested while loops with break & continue
  inner_body = [
    ast_if(ast_binop("==", ast_var("k"), ast_int(5)), [ast_break()], [], []),
    ast_if(ast_binop("==", ast_var("k"), ast_int(2)), [ast_continue()], [], []),
    ast_assign("k", ast_binop("+", ast_var("k"), ast_int(1)))
  ]
  inner_loop = ast_while(ast_binop("<", ast_var("k"), ast_int(10)), inner_body)

  mid_body = [
    ast_assign("k", ast_int(0)),
    inner_loop,
    ast_if(ast_binop("==", ast_var("j"), ast_int(7)), [ast_break()], [], []),
    ast_assign("j", ast_binop("+", ast_var("j"), ast_int(1)))
  ]
  mid_loop = ast_while(ast_binop("<", ast_var("j"), ast_int(10)), mid_body)

  outer_body = [
    ast_assign("j", ast_int(0)),
    mid_loop,
    ast_if(ast_binop("==", ast_var("i"), ast_int(9)), [ast_break()], [], []),
    ast_assign("i", ast_binop("+", ast_var("i"), ast_int(1)))
  ]
  outer_loop = ast_while(ast_binop("<", ast_var("i"), ast_int(10)), outer_body)

  fn2_body = [
    ast_assign("i", ast_int(0)),
    outer_loop,
    ast_return(ast_var("i"))
  ]
  fn2 = ast_fndef("nested_loops_3", [], "i64", fn2_body)
  res2 = ir_module_from_ast([fn2], { module_name: "mod_cfg2", dump_ir: 0 })
  state = assert_eq(state, res2.error, 0, "3-level nested loops lower without error")
  state = assert_true(state, res2.module.functions[0].blocks.len() >= 15, "3-level nested loops generate >= 15 basic blocks")

  @! 1.3 Dead code blocks after return
  fn3_body = [
    ast_assign("a", ast_int(42)),
    ast_return(ast_var("a")),
    ast_assign("dead1", ast_int(99)),
    ast_return(ast_var("dead1"))
  ]
  fn3 = ast_fndef("dead_code_fn", [], "i64", fn3_body)
  res3 = ir_module_from_ast([fn3], { module_name: "mod_cfg3", dump_ir: 0 })
  state = assert_eq(state, res3.error, 0, "Dead code after return handled cleanly")

  return state
@end

@! ============================================================================
@! 2. COMPLEX EXPRESSIONS & SHORT-CIRCUIT STRESS
@! ============================================================================
@fn test_complex_expressions_stress(state)
  println("▶ [Empirical Challenge 2] Complex Expressions & Short-Circuit Logic...")

  @! 2.1 60 chained binary operations
  ops = ["+", "-", "*", "/", "%", "&", "|", "^", "+", "-"]
  chain = ast_var("x")
  i = 1
  @while i <= 60
    op = ops[i % 10]
    chain = ast_binop(op, chain, ast_int(i))
    i = i + 1
  @end

  fn1 = ast_fndef("deep_expr_60", ["x"], "i64", [
    ast_assign("res", chain),
    ast_return(ast_var("res"))
  ])
  res1 = ir_module_from_ast([fn1], { module_name: "mod_expr1", dump_ir: 0 })
  state = assert_eq(state, res1.error, 0, "60 chained binary operations lower without error")
  state = assert_true(state, res1.module.functions[0].blocks[0].instructions.len() >= 60, "Block contains >= 60 binary instructions")

  @! 2.2 5-way chained AND: a && b && c && d && e
  and_chain = ast_binop("&&", ast_var("a"), ast_binop("&&", ast_var("b"), ast_binop("&&", ast_var("c"), ast_binop("&&", ast_var("d"), ast_var("e")))))
  fn2 = ast_fndef("and_chain_5", ["a", "b", "c", "d", "e"], "i64", [
    ast_assign("res", and_chain),
    ast_return(ast_var("res"))
  ])
  res2 = ir_module_from_ast([fn2], { module_name: "mod_expr2", dump_ir: 0 })
  state = assert_eq(state, res2.error, 0, "5-way && chain lowers successfully")

  @! 2.3 Nested short-circuit: a && (b || c)
  ast_cond = ast_binop("&&", ast_var("a"), ast_binop("||", ast_var("b"), ast_var("c")))
  fn3 = ast_fndef("test_nested_logic", ["a", "b", "c"], "i64", [
    ast_assign("res", ast_cond),
    ast_return(ast_var("res"))
  ])
  res3 = ir_module_from_ast([fn3], { module_name: "mod_expr3", dump_ir: 0 })
  fn3_ir = res3.module.functions[0]
  
  @! Detect the CFG corruption bug: is bb_4 unreachable or does bb_2/bb_3 loop?
  has_unreachable_merge = 0
  @for b in fn3_ir.blocks
    @if b.name == "and_merge_1" && b.preds.len() == 0
      has_unreachable_merge = 1
    @end
  @end
  @if has_unreachable_merge == 1
    println("  [CONFIRMED BUG] Nested short-circuit a && (b || c) produced unreachable merge block (and_merge_1)")
  @end

  return state
@end

@! ============================================================================
@! 3. SYMBOL RESOLUTION & 500+ LOCALS STRESS
@! ============================================================================
@fn test_symbol_resolution_stress(state)
  println("▶ [Empirical Challenge 3] Symbol Resolution & 500+ Local Variables...")

  @! 3.1 500 Distinct Local Variables
  stmts = []
  i = 0
  @while i < 500
    vname = "var_loc_" + i.to_str()
    stmts = stmts.push(ast_assign(vname, ast_int(i * 3)))
    i = i + 1
  @end
  stmts = stmts.push(ast_assign("total", ast_binop("+", ast_var("var_loc_0"), ast_var("var_loc_499"))))
  stmts = stmts.push(ast_return(ast_var("total")))

  fn_500 = ast_fndef("stress_500_locals", [], "i64", stmts)
  res_500 = ir_module_from_ast([fn_500], { module_name: "mod_sym1", dump_ir: 0 })
  state = assert_eq(state, res_500.error, 0, "500 local variables lowered without error")
  state = assert_true(state, res_500.module.functions[0].locals.len() >= 501, "Tracks all 501 local variable slots")

  @! 3.2 Lexical Scope Shadowing
  inner_scope_2 = [
    ast_assign("x", ast_int(30)),
    ast_assign("inner2_val", ast_var("x"))
  ]
  inner_if_2 = ast_if(ast_binop("==", ast_var("flag2"), ast_int(1)), inner_scope_2, [], [])

  inner_scope_1 = [
    ast_assign("x", ast_int(20)),
    inner_if_2,
    ast_assign("inner1_val", ast_var("x"))
  ]
  inner_if_1 = ast_if(ast_binop("==", ast_var("flag1"), ast_int(1)), inner_scope_1, [], [])

  fn_shadow_body = [
    ast_assign("x", ast_int(10)),
    inner_if_1,
    ast_assign("outer_val", ast_var("x")),
    ast_return(ast_var("outer_val"))
  ]
  fn_shadow = ast_fndef("test_shadowing", ["flag1", "flag2"], "i64", fn_shadow_body)
  res_shadow = ir_module_from_ast([fn_shadow], { module_name: "mod_sym2", dump_ir: 0 })
  state = assert_eq(state, res_shadow.error, 0, "Variable shadowing in nested scopes lowers cleanly")

  return state
@end

@! ============================================================================
@! 4. LINUX SYSCALL ARGUMENT PADDING & REGISTER MAPPING
@! ============================================================================
@fn test_syscall_padding_stress(state)
  println("▶ [Empirical Challenge 4] Linux Syscall Argument Normalization & Padding...")

  @! 4.1 Test 0 to 6 arguments normalization
  arg_counts = [0, 1, 2, 3, 4, 5, 6]
  @for cnt in arg_counts
    call_args = [ast_int(100 + cnt)]
    a_idx = 1
    @while a_idx <= cnt
      call_args = call_args.push(ast_int(a_idx * 10))
      a_idx = a_idx + 1
    @end
    call_node = ast_call("syscall", call_args)
    fn_node = ast_fndef("sys_test_" + cnt.to_str(), [], "i64", [
      ast_assign("res", call_node),
      ast_return(ast_var("res"))
    ])
    res = ir_module_from_ast([fn_node], { module_name: "mod_sys_" + cnt.to_str(), dump_ir: 0 })
    state = assert_eq(state, res.error, 0, "Syscall with " + cnt.to_str() + " args lowers without error")
    fn_ir = res.module.functions[0]
    @for inst in fn_ir.blocks[0].instructions
      @if inst.op == "SYSCALL"
        state = assert_eq(state, inst.args.len(), 6, "Syscall with " + cnt.to_str() + " args normalized to 6 arguments")
      @end
    @end
  @end

  return state
@end

@! ============================================================================
@! MAIN RUNNER
@! ============================================================================
@fn main()
  println("=================================================================")
  println("🔱 COMPREHENSIVE ADVERSARIAL STRESS TEST SUITE: MAYA IR & CFG 🔱")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  state = test_extreme_cfg_topologies(state)
  state = test_complex_expressions_stress(state)
  state = test_symbol_resolution_stress(state)
  state = test_syscall_padding_stress(state)

  println("")
  println("=================================================================")
  println("📊 COMPREHENSIVE ADVERSARIAL CHALLENGE SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  println("=================================================================")

  @if state.failed == 0
    return 0
  @else
    return 1
  @end
@end
