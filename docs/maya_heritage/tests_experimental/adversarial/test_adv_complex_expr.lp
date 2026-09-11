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
  println("🧪 ADVERSARIAL COMPLEX EXPRESSIONS TEST HARNESS 🧪")
  println("=================================================================")

  @! --------------------------------------------------------------------------
  @! Test 1: 50+ Chained Binary Operations (Deep Expression Tree)
  @! --------------------------------------------------------------------------
  println("▶ [Expr 1] Testing 60 chained binary operations...")
  ops = ["+", "-", "*", "/", "%", "&", "|", "^", "+", "-"]
  chain = ast_var("x")
  i = 1
  @while i <= 60
    op = ops[i % 10]
    chain = ast_binop(op, chain, ast_int(i))
    i = i + 1
  @end

  fn1_body = [
    ast_assign("res", chain),
    ast_return(ast_var("res"))
  ]
  fn1 = ast_fndef("deep_expr_60", ["x"], "i64", fn1_body)

  res1 = ir_module_from_ast([fn1], { module_name: "mod_deep_expr", dump_ir: 0 })
  println("  60-op chain lowering error: " + res1.error.to_str())
  @if res1.error == 0
    fn_ir = res1.module.functions[0]
    inst_count = fn_ir.blocks[0].instructions.len()
    println("  [PASS] 60 chained binary operations lowered cleanly (Block 0 instructions: " + inst_count.to_str() + ")")
  @else
    println("  [FAIL] 60 chained binary operations failed: " + res1.message)
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: Chained Short-Circuit Logic (&& chain of 5 variables)
  @! --------------------------------------------------------------------------
  println("▶ [Expr 2] Testing chained short-circuit AND: a && b && c && d && e...")
  and_chain = ast_binop("&&", ast_var("a"), ast_binop("&&", ast_var("b"), ast_binop("&&", ast_var("c"), ast_binop("&&", ast_var("d"), ast_var("e")))))
  fn2_body = [
    ast_assign("res", and_chain),
    ast_return(ast_var("res"))
  ]
  fn2 = ast_fndef("and_chain_5", ["a", "b", "c", "d", "e"], "i64", fn2_body)

  res2 = ir_module_from_ast([fn2], { module_name: "mod_and_chain", dump_ir: 0 })
  println("  5-way && chain lowering error: " + res2.error.to_str())
  @if res2.error == 0
    fn2_ir = res2.module.functions[0]
    v_res2 = ir_verify_cfg(fn2_ir)
    println("  5-way && chain CFG verification ok: " + v_res2.ok.to_str())
    @if v_res2.ok == 1
      println("  [PASS] 5-way && chain verified cleanly (Blocks: " + fn2_ir.blocks.len().to_str() + ")")
    @else
      println("  [FAIL] 5-way && chain CFG verification failed!")
      @for e in v_res2.errors println("    " + e) @end
    @end
  @else
    println("  [FAIL] 5-way && chain lowering failed: " + res2.message)
    @for e in res2.errors println("    " + e) @end
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: Mixed Short-Circuit Logic: (a && b) || (c && d)
  @! --------------------------------------------------------------------------
  println("▶ [Expr 3] Testing mixed short-circuit logic: (a && b) || (c && d)...")
  lhs = ast_binop("&&", ast_var("a"), ast_var("b"))
  rhs = ast_binop("&&", ast_var("c"), ast_var("d"))
  or_expr = ast_binop("||", lhs, rhs)

  fn3_body = [
    ast_assign("res", or_expr),
    ast_return(ast_var("res"))
  ]
  fn3 = ast_fndef("mixed_logic", ["a", "b", "c", "d"], "i64", fn3_body)

  res3 = ir_module_from_ast([fn3], { module_name: "mod_mixed_logic", dump_ir: 0 })
  println("  Mixed logic lowering error: " + res3.error.to_str())
  @if res3.error == 0
    fn3_ir = res3.module.functions[0]
    v_res3 = ir_verify_cfg(fn3_ir)
    println("  Mixed logic CFG verification ok: " + v_res3.ok.to_str())
    @if v_res3.ok == 1
      println("  [PASS] Mixed logic verified cleanly (Blocks: " + fn3_ir.blocks.len().to_str() + ")")
    @else
      println("  [FAIL] Mixed logic CFG verification failed:")
      @for e in v_res3.errors println("    " + e) @end
    @end
  @else
    println("  [FAIL] Mixed logic lowering failed: " + res3.message)
    @for e in res3.errors println("    " + e) @end
  @end

  return 0
@end
