import "compiler/backend/maya_ir"

@fn main()
  println("=== FOR LOOP LOWERING TEST ===")
  
  @! Create For Loop with break & continue inside
  for_stmt = ast_node("ForLoop")
  for_stmt.variable = "item"
  for_stmt.iterable = ast_node("Variable")
  for_stmt.iterable.name = "items"

  if_break = ast_node("IfStmt")
  if_break.condition = ast_node("BinaryOp")
  if_break.condition.op = "=="
  if_break.condition.left = ast_node("Variable")
  if_break.condition.left.name = "item"
  if_break.condition.right = ast_node("LiteralInt")
  if_break.condition.right.val = 10
  if_break.then_body = [ast_node("Break")]

  if_cont = ast_node("IfStmt")
  if_cont.condition = ast_node("BinaryOp")
  if_cont.condition.op = "=="
  if_cont.condition.left = ast_node("Variable")
  if_cont.condition.left.name = "item"
  if_cont.condition.right = ast_node("LiteralInt")
  if_cont.condition.right.val = 5
  if_cont.then_body = [ast_node("Continue")]

  for_stmt.body = [if_break, if_cont]

  fn_for = ast_fndef("test_for", ["items"], "i64", [for_stmt, ast_node("Return")])
  mod_res = ir_module_from_ast([fn_for], { dump_ir: 0, module_name: "test_for_mod" })

  println("For loop lowering error: " + mod_res.error.to_str())
  println("For loop warnings count : " + mod_res.warnings.len().to_str())
  @for w in mod_res.warnings
    println("Warning: " + w)
  @end
  @for e in mod_res.errors
    println("Error: " + e)
  @end
  
  @if mod_res.error == 0 && mod_res.warnings.len() == 0
    println("✅ For loop CFG lowering passed cleanly!")
  @else
    println("❌ For loop CFG lowering failed!")
  @end
@end
