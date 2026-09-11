import "compiler/backend/maya_ir"

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

@fn ast_if(cond, then_b, elif_b, else_b)
  n = new_ast_node()
  n.kind = "IfStmt"
  n.condition = cond
  n.then_body = then_b
  n.elif_branches = elif_b
  n.else_body = else_b
  return n
@end

@fn ast_elif(cond, body)
  n = new_ast_node()
  n.cond = cond
  n.body = body
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

@fn main()
  println("=================================================================")
  println("🧪 ADVERSARIAL CFG TOPOLOGY TEST HARNESS 🧪")
  println("=================================================================")

  @! --------------------------------------------------------------------------
  @! Test 1: Deeply Nested 10-Level If-Else Ladder
  @! --------------------------------------------------------------------------
  println("▶ [CFG 1] Testing 10-level nested If-Else ladder...")
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

  res1 = ir_module_from_ast([fn1], { module_name: "mod_nested_if", dump_ir: 0 })
  println("  10-level nested if lowering error: " + res1.error.to_str())
  @if res1.error == 0
    println("  [PASS] 10-level nested if lowered successfully (Blocks: " + res1.module.functions[0].blocks.len().to_str() + ")")
  @else
    println("  [FAIL] 10-level nested if failed: " + res1.message)
    @for err in res1.errors
      println("    " + err)
    @end
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: Multi-Loop Break and Continue Nesting (3 Nested Loops)
  @! --------------------------------------------------------------------------
  println("▶ [CFG 2] Testing 3-level nested while loops with break & continue...")
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

  res2 = ir_module_from_ast([fn2], { module_name: "mod_nested_loops", dump_ir: 0 })
  println("  3-level nested loop lowering error: " + res2.error.to_str())
  @if res2.error == 0
    println("  [PASS] 3-level nested loop lowered successfully (Blocks: " + res2.module.functions[0].blocks.len().to_str() + ")")
  @else
    println("  [FAIL] 3-level nested loop failed: " + res2.message)
    @for err in res2.errors
      println("    " + err)
    @end
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: Unreachable Dead Code Blocks (Code after return)
  @! --------------------------------------------------------------------------
  println("▶ [CFG 3] Testing dead code blocks after return...")
  fn3_body = [
    ast_assign("a", ast_int(42)),
    ast_return(ast_var("a")),
    ast_assign("dead1", ast_int(99)),
    ast_assign("dead2", ast_int(100)),
    ast_return(ast_var("dead1"))
  ]
  fn3 = ast_fndef("dead_code_fn", [], "i64", fn3_body)
  res3 = ir_module_from_ast([fn3], { module_name: "mod_dead_code", dump_ir: 0 })
  println("  Dead code after return lowering error: " + res3.error.to_str())
  @if res3.error == 0
    println("  [PASS] Dead code after return handled cleanly (Blocks: " + res3.module.functions[0].blocks.len().to_str() + ")")
  @else
    println("  [FAIL] Dead code after return failed: " + res3.message)
    @for err in res3.errors
      println("    " + err)
    @end
  @end

  @! --------------------------------------------------------------------------
  @! Test 4: Break and Continue outside loops (Edge case)
  @! --------------------------------------------------------------------------
  println("▶ [CFG 4] Testing break/continue outside loops...")
  fn4_body = [
    ast_break(),
    ast_continue(),
    ast_return(ast_int(0))
  ]
  fn4 = ast_fndef("orphan_break", [], "i64", fn4_body)
  res4 = ir_module_from_ast([fn4], { module_name: "mod_orphan_break", dump_ir: 0 })
  println("  Orphan break/continue error: " + res4.error.to_str())
  @if res4.error == 0
    println("  [PASS] Orphan break/continue handled gracefully without crash")
  @else
    println("  [FAIL] Orphan break/continue error: " + res4.message)
  @end

  return 0
@end
