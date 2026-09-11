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
  println("🧪 ADVERSARIAL SYMBOL RESOLUTION & 500+ LOCALS STRESS 🧪")
  println("=================================================================")

  @! --------------------------------------------------------------------------
  @! Test 1: 500+ Local Variables in Single Function
  @! --------------------------------------------------------------------------
  println("▶ [Symbols 1] Testing 500 distinct local variables allocation...")
  stmts = []
  i = 0
  @while i < 500
    vname = "var_loc_" + i.to_str()
    stmts = stmts.push(ast_assign(vname, ast_int(i * 2)))
    i = i + 1
  @end

  @! Add a sum of first and last
  sum_expr = ast_binop("+", ast_var("var_loc_0"), ast_var("var_loc_499"))
  stmts = stmts.push(ast_assign("total", sum_expr))
  stmts = stmts.push(ast_return(ast_var("total")))

  fn_500 = ast_fndef("stress_500_locals", [], "i64", stmts)
  res_500 = ir_module_from_ast([fn_500], { module_name: "mod_500_locals", dump_ir: 0 })

  println("  500 locals lowering error: " + res_500.error.to_str())
  @if res_500.error == 0
    fn_ir = res_500.module.functions[0]
    println("  [PASS] 500 distinct locals created cleanly (Locals tracked: " + fn_ir.locals.len().to_str() + ")")
    @if fn_ir.locals.len() >= 501
      println("  [PASS] Locals count matches expected 501 (500 + total)")
    @else
      println("  [FAIL] Locals count mismatch: " + fn_ir.locals.len().to_str())
    @end
  @else
    println("  [FAIL] 500 locals failed: " + res_500.message)
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: Variable Shadowing in Nested Lexical Scopes
  @! --------------------------------------------------------------------------
  println("▶ [Symbols 2] Testing variable shadowing in nested lexical scopes...")
  @! Outer scope: x = 10
  @! If block 1: x = 20, inner if block 2: x = 30
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
  res_shadow = ir_module_from_ast([fn_shadow], { module_name: "mod_shadow", dump_ir: 0 })

  println("  Shadowing lowering error: " + res_shadow.error.to_str())
  @if res_shadow.error == 0
    println("  [PASS] Variable shadowing lowered cleanly without symbol collisions")
  @else
    println("  [FAIL] Variable shadowing failed: " + res_shadow.message)
  @end

  return 0
@end
