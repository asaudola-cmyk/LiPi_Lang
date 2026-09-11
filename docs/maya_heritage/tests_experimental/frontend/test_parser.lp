@! ============================================================================
@! PURE MAYA FRONTEND UNIT & INTEGRATION TESTS: PRATT PARSER & LOWERING
@! ============================================================================

import "compiler/frontend/ast"
import "compiler/frontend/lexer"
import "compiler/frontend/parser"
import "universe/core/string"

@fn assert_eq_i64(actual, expected, test_name)
  @if actual == expected
    println("[PASS] " + test_name + " -> got " + int_to_str(actual))
    return 1
  @else
    println("[FAIL] " + test_name + " -> expected " + int_to_str(expected) + ", got " + int_to_str(actual))
    return 0
  @end
@end

@fn assert_eq_str(actual, expected, test_name)
  @if actual == expected
    println("[PASS] " + test_name + " -> got \"" + actual + "\"")
    return 1
  @else
    println("[FAIL] " + test_name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🧪 PURE MAYA PRATT PARSER & LOWERING VERIFICATION SUITE 🧪")
  println("=================================================================")

  total_pass = 0
  total_fail = 0

  @! 1. Pratt Precedence Parsing: 1 + 2 * 3
  src1 = "1 + 2 * 3"
  toks1 = tokenize_source(src1)
  expr1 = parse_expr(toks1, 0).node
  r1 = ast_get_right(expr1)

  @if assert_eq_str(ast_get_kind(expr1), "BinaryOp", "Precedence root is BinaryOp") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(expr1), "+", "Precedence root op is '+'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_get_val(ast_get_left(expr1)), 1, "Left operand is 1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(r1), "BinaryOp", "Right operand is BinaryOp (*)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(r1), "*", "Right operand op is '*'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_get_val(ast_get_left(r1)), 2, "Right.left is 2") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_get_val(ast_get_right(r1)), 3, "Right.right is 3") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 2. Relational and Logical Precedence: a == 1 && b > 2
  src2 = "a == 1 && b > 2"
  toks2 = tokenize_source(src2)
  expr2 = parse_expr(toks2, 0).node
  @if assert_eq_str(ast_get_kind(expr2), "BinaryOp", "Logical AND is root") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(expr2), "&&", "Logical AND op is &&") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_left(expr2)), "==", "Left comparison is ==") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_right(expr2)), ">", "Right comparison is >") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3. Pipeline Operator: data |> process |> display
  src3 = "data |> process |> display"
  toks3 = tokenize_source(src3)
  expr3 = parse_expr(toks3, 0).node
  @if assert_eq_str(ast_get_kind(expr3), "Pipeline", "Pipeline root node is Pipeline") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 4. Function & Struct Definitions
  src_prog = "@struct Point\n  x: i64\n  y: i64\n@end\n\n@fn add_points(p1: Point, p2: Point) -> Point\n  @return { x: p1.x + p2.x, y: p1.y + p2.y }\n@end\n"
  prog = parse_source_program(src_prog)

  @if assert_eq_i64(prog.structs.len(), 1, "1 struct parsed") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  st0 = prog.structs[0]
  @if assert_eq_str(ast_get_name(st0), "Point", "Struct name is Point") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_get_params(st0).len(), 2, "Point has 2 fields") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(prog.functions.len(), 1, "1 function parsed") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  fn0 = prog.functions[0]
  @if assert_eq_str(ast_get_name(fn0), "add_points", "Function name is add_points") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 5. @impl Method Injection & Lowering
  src_impl = "@impl Circle\n  @fn area(radius: i64) -> i64\n    @return 3 * radius * radius\n  @end\n@end\n"
  prog_impl = parse_source_program(src_impl)
  @if assert_eq_i64(prog_impl.functions.len(), 1, "Impl method registered as function") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  ifn0 = prog_impl.functions[0]
  @if assert_eq_str(ast_get_name(ifn0), "Circle_area", "Impl method mangled to Circle_area") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  ifn0_params = ast_get_params(ifn0)
  p0 = ifn0_params[0]
  @if assert_eq_str(ast_param_get_name(p0), "self", "First parameter injected as 'self'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_param_get_type(p0), "Circle", "Self parameter type is Circle") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 6. @enum Desugaring
  src_enum = "@enum Status\n  Pending\n  Active\n  Completed = 10\n  Failed\n@end\n"
  prog_enum = parse_source_program(src_enum)
  @if assert_eq_i64(prog_enum.enums.len(), 1, "1 enum parsed") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(prog_enum.constants.len(), 4, "4 enum constants generated") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  c0 = prog_enum.constants[0]
  @if assert_eq_str(ast_const_get_name(c0), "Status_Pending", "Constant Status_Pending") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_const_get_value(c0), 0, "Status_Pending == 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  c2 = prog_enum.constants[2]
  @if assert_eq_str(ast_const_get_name(c2), "Status_Completed", "Constant Status_Completed") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_const_get_value(c2), 10, "Status_Completed == 10") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  c3 = prog_enum.constants[3]
  @if assert_eq_i64(ast_const_get_value(c3), 11, "Status_Failed == 11") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 7. Control Flow Statements (@while, @for, @parallel_for, @try/@catch, @defer)
  src_ctrl = "@fn test_ctrl()\n  @while x > 0\n    x -= 1\n  @end\n  @for item in items\n    println(item)\n  @end\n  @parallel_for i in chunks\n    compute(i)\n  @end\n  @try\n    risky_call()\n  @catch err\n    handle_error(err)\n  @end\n  @defer cleanup()\n@end\n"
  prog_ctrl = parse_source_program(src_ctrl)
  fn_ctrl = prog_ctrl.functions[0]
  body_ctrl = ast_get_body(fn_ctrl)
  @if assert_eq_i64(body_ctrl.len(), 5, "5 control flow statements parsed") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(body_ctrl[0]), "WhileLoop", "First stmt is WhileLoop") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(body_ctrl[1]), "ForLoop", "Second stmt is ForLoop") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(body_ctrl[2]), "ParallelFor", "Third stmt is ParallelFor") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(body_ctrl[3]), "TryCatch", "Fourth stmt is TryCatch") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(body_ctrl[4]), "Defer", "Fifth stmt is Defer") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  println("=================================================================")
  println("📊 TEST SUMMARY: " + int_to_str(total_pass) + " passed, " + int_to_str(total_fail) + " failed")
  println("=================================================================")

  @if total_fail == 0
    println("✓ Pure Maya Pratt Parser verification tests passed 100%!")
    return 0
  @else
    return 1
  @end
@end
