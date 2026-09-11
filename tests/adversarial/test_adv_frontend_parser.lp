@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE: PURE MAYA PRATT PARSER & LOWERING
@! Operator Precedence Matrix, Deep Recursion, Syntactic Lowering, Error Resilience
@! ============================================================================

import "compiler/frontend/ast"
import "compiler/frontend/lexer"
import "compiler/frontend/parser"
import "universe/core/string"
import "universe/core/collections"

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

@fn assert_true(cond, test_name)
  @if cond == 1
    println("[PASS] " + test_name)
    return 1
  @else
    println("[FAIL] " + test_name)
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS SUITE: PURE MAYA PRATT PARSER & LOWERING 🔥")
  println("=================================================================")

  total_pass = 0
  total_fail = 0

  @! --------------------------------------------------------------------------
  @! SECTION 1: 13-LEVEL OPERATOR PRECEDENCE MATRIX
  @! --------------------------------------------------------------------------
  println("\n--- [Section 1] 13-Level Operator Precedence Matrix ---")

  @! 1.1 Mult vs Add: a + b * c -> root '+', right '*'
  t1 = tokenize_source("a + b * c")
  e1 = parse_expr(t1, 0).node
  @if assert_eq_str(ast_get_op(e1), "+", "Precedence: '+' at root of (a + b * c)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_right(e1)), "*", "Precedence: '*' in right branch") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.2 Add vs Shift: a << b + c -> root '<<', right '+'
  t2 = tokenize_source("a << b + c")
  e2 = parse_expr(t2, 0).node
  @if assert_eq_str(ast_get_op(e2), "<<", "Precedence: '<<' at root of (a << b + c)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_right(e2)), "+", "Precedence: '+' in right branch of '<<'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.3 Shift vs Relational: a < b << 2 -> root '<', right '<<'
  t3 = tokenize_source("a < b << 2")
  e3 = parse_expr(t3, 0).node
  @if assert_eq_str(ast_get_op(e3), "<", "Precedence: '<' at root of (a < b << 2)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_right(e3)), "<<", "Precedence: '<<' in right branch of '<'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.4 Relational vs Equality: a == b < c -> root '==', right '<'
  t4 = tokenize_source("a == b < c")
  e4 = parse_expr(t4, 0).node
  @if assert_eq_str(ast_get_op(e4), "==", "Precedence: '==' at root of (a == b < c)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_right(e4)), "<", "Precedence: '<' in right branch of '=='") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.5 Equality vs Bitwise AND: a & b == c -> root '&', right '=='
  t5 = tokenize_source("a & b == c")
  e5 = parse_expr(t5, 0).node
  @if assert_eq_str(ast_get_op(e5), "&", "Precedence: '&' at root of (a & b == c)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_right(e5)), "==", "Precedence: '==' in right branch of '&'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.6 Bitwise AND vs Bitwise XOR: a ^ b & c -> root '^', right '&'
  t6 = tokenize_source("a ^ b & c")
  e6 = parse_expr(t6, 0).node
  @if assert_eq_str(ast_get_op(e6), "^", "Precedence: '^' at root of (a ^ b & c)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_right(e6)), "&", "Precedence: '&' in right branch of '^'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.7 Bitwise XOR vs Bitwise OR: a | b ^ c -> root '|', right '^'
  t7 = tokenize_source("a | b ^ c")
  e7 = parse_expr(t7, 0).node
  @if assert_eq_str(ast_get_op(e7), "|", "Precedence: '|' at root of (a | b ^ c)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_right(e7)), "^", "Precedence: '^' in right branch of '|'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.8 Bitwise OR vs Logical AND: a && b | c -> root '&&', right '|'
  t8 = tokenize_source("a && b | c")
  e8 = parse_expr(t8, 0).node
  @if assert_eq_str(ast_get_op(e8), "&&", "Precedence: '&&' at root of (a && b | c)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_right(e8)), "|", "Precedence: '|' in right branch of '&&'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.9 Logical AND vs Logical OR: a || b && c -> root '||', right '&&'
  t9 = tokenize_source("a || b && c")
  e9 = parse_expr(t9, 0).node
  @if assert_eq_str(ast_get_op(e9), "||", "Precedence: '||' at root of (a || b && c)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_right(e9)), "&&", "Precedence: '&&' in right branch of '||'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.10 Left Associativity of Subtraction: a - b - c -> root '-', left is (a - b)
  t10 = tokenize_source("a - b - c")
  e10 = parse_expr(t10, 0).node
  @if assert_eq_str(ast_get_op(e10), "-", "Left-assoc: root is '-'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(ast_get_left(e10)), "BinaryOp", "Left-assoc: left child is BinaryOp") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_left(e10)), "-", "Left-assoc: left op is '-'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 1.11 Pipeline precedence: x |> f + 1 -> (x |> f) + 1
  t11 = tokenize_source("x |> f + 1")
  e11 = parse_expr(t11, 0).node
  @if assert_eq_str(ast_get_op(e11), "+", "Pipeline vs Add: root is '+'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(ast_get_left(e11)), "Pipeline", "Pipeline vs Add: left is Pipeline") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! --------------------------------------------------------------------------
  @! SECTION 2: STRING INTERPOLATION LOWERING VERIFICATION
  @! --------------------------------------------------------------------------
  println("\n--- [Section 2] String Interpolation Lowering ---")

  @! 2.1 Single variable interpolation: "{count}"
  raw_interp1 = str_from_char_code(123) + "count" + str_from_char_code(125)
  lowered1 = parse_string_interpolation(raw_interp1)
  @if assert_eq_str(ast_get_kind(lowered1), "Call", "Single interp is Call node") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  callee1 = lowered1.func
  @if assert_eq_str(ast_get_kind(callee1), "MemberAccess", "Callee is MemberAccess") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_name(ast_get_left(callee1)), "count", "Target variable is 'count'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_name(callee1), "to_str", "Method is 'to_str'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 2.2 Interpolation with prefix and suffix: "Total: {x} items"
  raw_interp2 = "Total: " + str_from_char_code(123) + "x" + str_from_char_code(125) + " items"
  lowered2 = parse_string_interpolation(raw_interp2)
  @if assert_eq_str(ast_get_kind(lowered2), "BinaryOp", "Prefix/suffix interp root is BinaryOp") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(lowered2), "+", "BinaryOp is '+'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_name(ast_get_right(lowered2)), " items", "Right literal is ' items'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 2.3 Unclosed interpolation: "{unclosed"
  raw_interp3 = "Hello " + str_from_char_code(123) + "unclosed"
  lowered3 = parse_string_interpolation(raw_interp3)
  @if assert_eq_str(ast_get_kind(lowered3), "BinaryOp", "Unclosed interp lowers safely to BinaryOp") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! --------------------------------------------------------------------------
  @! SECTION 3: DEEPLY NESTED STRUCTURES STRESS
  @! --------------------------------------------------------------------------
  println("\n--- [Section 3] Deeply Nested Structures Stress ---")

  @! 3.1 50-level nested parentheses: (((...42...)))
  open_parens = ""
  close_parens = ""
  j = 0
  @while j < 50
    open_parens = open_parens + "("
    close_parens = close_parens + ")"
    j = j + 1
  @end
  src_deep_paren = open_parens + "42" + close_parens
  t_dp = tokenize_source(src_deep_paren)
  e_dp = parse_expr(t_dp, 0).node
  @if assert_eq_str(ast_get_kind(e_dp), "LiteralInt", "50-nested paren expr parses to LiteralInt") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_get_val(e_dp), 42, "50-nested paren expr value is 42") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3.2 40-term binary addition chain: 1 + 1 + ... + 1
  src_add_chain = "1"
  j = 0
  @while j < 39
    src_add_chain = src_add_chain + " + 1"
    j = j + 1
  @end
  t_ac = tokenize_source(src_add_chain)
  e_ac = parse_expr(t_ac, 0).node
  @if assert_eq_str(ast_get_kind(e_ac), "BinaryOp", "40-term addition chain parses to BinaryOp tree") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3.3 Deep nested member access: obj.a.b.c.d.e.f.g.h.i.j
  src_deep_member = "obj.a.b.c.d.e.f.g.h.i.j"
  t_dm = tokenize_source(src_deep_member)
  e_dm = parse_expr(t_dm, 0).node
  @if assert_eq_str(ast_get_kind(e_dm), "MemberAccess", "10-level member access parses to MemberAccess") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_name(e_dm), "j", "Innermost access field is 'j'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3.4 Deep nested arrays: [[[[[10]]]]]
  src_deep_arr = "[[[[[10]]]]]"
  t_da = tokenize_source(src_deep_arr)
  e_da = parse_expr(t_da, 0).node
  @if assert_eq_str(ast_get_kind(e_da), "ArrayLit", "5-nested array parses to ArrayLit") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3.5 Deep nested @if blocks (10 levels)
  src_nested_ifs = "@fn deep_ifs() -> i64\n"
  j = 0
  @while j < 10
    src_nested_ifs = src_nested_ifs + "  @if true\n"
    j = j + 1
  @end
  src_nested_ifs = src_nested_ifs + "    @return 100\n"
  j = 0
  @while j < 10
    src_nested_ifs = src_nested_ifs + "  @end\n"
    j = j + 1
  @end
  src_nested_ifs = src_nested_ifs + "  @return 0\n@end\n"
  prog_n_ifs = parse_source_program(src_nested_ifs)
  @if assert_eq_i64(prog_n_ifs.functions.len(), 1, "10-nested @if function parsed successfully") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! --------------------------------------------------------------------------
  @! SECTION 4: COMPLETE SYNTAX & CONTROL FLOW DESUGARING
  @! --------------------------------------------------------------------------
  println("\n--- [Section 4] Complete Syntax & Control Flow Desugaring ---")

  @! 4.1 Multi-branch @if/@elif/@else
  src_if_elif = "@fn check_grade(score: i64) -> string\n  @if score >= 90\n    @return \"A\"\n  @elif score >= 80\n    @return \"B\"\n  @elif score >= 70\n    @return \"C\"\n  @elif score >= 60\n    @return \"D\"\n  @else\n    @return \"F\"\n  @end\n@end\n"
  prog_ie = parse_source_program(src_if_elif)
  fn_ie = prog_ie.functions[0]
  if_stmt = ast_get_body(fn_ie)[0]
  @if assert_eq_str(ast_get_kind(if_stmt), "IfStmt", "Parsed IfStmt with elif branches") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_get_elif_branches(if_stmt).len(), 3, "3 elif branches generated") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_get_else_body(if_stmt).len(), 1, "1 else statement generated") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 4.2 @enum with custom offset progressions
  src_enum_custom = "@enum HTTPStatus\n  OK = 200\n  Created\n  Accepted\n  BadRequest = 400\n  Unauthorized\n  NotFound = 404\n@end\n"
  prog_ec = parse_source_program(src_enum_custom)
  @if assert_eq_i64(prog_ec.constants.len(), 6, "6 enum constants generated") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_const_get_value(prog_ec.constants[0]), 200, "HTTPStatus_OK == 200") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_const_get_value(prog_ec.constants[1]), 201, "HTTPStatus_Created == 201") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_const_get_value(prog_ec.constants[2]), 202, "HTTPStatus_Accepted == 202") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_const_get_value(prog_ec.constants[3]), 400, "HTTPStatus_BadRequest == 400") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_const_get_value(prog_ec.constants[4]), 401, "HTTPStatus_Unauthorized == 401") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_const_get_value(prog_ec.constants[5]), 404, "HTTPStatus_NotFound == 404") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 4.3 @impl Trait for Struct with multiple methods
  src_impl_trait = "@impl Display for Point\n  @fn to_str() -> string\n    @return \"Point\"\n  @end\n  @fn print_point(prefix: string) -> void\n    println(prefix)\n  @end\n@end\n"
  prog_it = parse_source_program(src_impl_trait)
  @if assert_eq_i64(prog_it.impls.len(), 1, "1 impl block parsed") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(prog_it.functions.len(), 2, "2 methods registered globally from impl block") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  m0 = prog_it.functions[0]
  @if assert_eq_str(ast_get_name(m0), "Point_to_str", "Method 1 mangled to Point_to_str") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_param_get_name(ast_get_params(m0)[0]), "self", "Method 1 self param injected") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 4.4 Variable Declarations & Assignments (let x = 1, x = 2, x += 10, etc.)
  src_assigns = "@fn var_ops() -> void\n  let a = 1\n  b = 2\n  c += 10\n  d -= 5\n  e *= 2\n  f /= 4\n  g %= 3\n@end\n"
  prog_as = parse_source_program(src_assigns)
  as_stmts = ast_get_body(prog_as.functions[0])
  @if assert_eq_i64(as_stmts.len(), 7, "7 assignment / expression statements parsed") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(as_stmts[0]), "Assign", "let a = 1 is Assign node") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_target(as_stmts[0]), "a", "let a target is 'a'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(as_stmts[1]), "ExpressionStmt", "b = 2 is ExpressionStmt") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_expr(as_stmts[1])), "=", "b = 2 inner op is '='") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_expr(as_stmts[2])), "+=", "c += 10 inner op is '+='") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_expr(as_stmts[3])), "-=", "d -= 5 inner op is '-='") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_expr(as_stmts[4])), "*=", "e *= 2 inner op is '*='") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_expr(as_stmts[5])), "/=", "f /= 4 inner op is '/='") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_op(ast_get_expr(as_stmts[6])), "%=", "g %= 3 inner op is '%='") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! --------------------------------------------------------------------------
  @! SECTION 5: SYNTAX ERROR RESILIENCE & MALFORMED CODE
  @! --------------------------------------------------------------------------
  println("\n--- [Section 5] Syntax Error Resilience & Malformed Code ---")

  @! 5.1 Incomplete function at EOF
  src_inc_fn = "@fn unfinished("
  prog_ifn = parse_source_program(src_inc_fn)
  @if assert_true(prog_ifn.functions.len() >= 0, "Incomplete function at EOF does not panic") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 5.2 Incomplete struct at EOF
  src_inc_st = "@struct Unfinished"
  prog_ist = parse_source_program(src_inc_st)
  @if assert_true(prog_ist.structs.len() >= 0, "Incomplete struct at EOF does not panic") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 5.3 Incomplete expression
  src_inc_exp = "1 + "
  t_ie = tokenize_source(src_inc_exp)
  e_ie = parse_expr(t_ie, 0).node
  @if assert_true(ast_get_kind(e_ie).len() > 0, "Incomplete expression parsed without panic") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 5.4 Stray delimiters and symbols
  src_stray = "]]] }}} ))) ;;; ,,, @@"
  prog_stray = parse_source_program(src_stray)
  @if assert_true(prog_stray.functions.len() == 0, "Stray delimiters parsed without panic") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 5.5 Trailing commas in array and struct literals
  src_trail_comma = "@fn dummy() -> void\n  arr = [1, 2, 3,]\n@end\n"
  prog_tc = parse_source_program(src_trail_comma)
  @if assert_eq_i64(prog_tc.functions.len(), 1, "Trailing commas in array literal handled smoothly") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  println("\n=================================================================")
  println("📊 ADVERSARIAL PARSER RESULTS: " + int_to_str(total_pass) + " passed, " + int_to_str(total_fail) + " failed")
  println("=================================================================")

  @if total_fail == 0
    println("✓ 100% of pure Maya Pratt Parser adversarial stress tests PASSED!")
    return 0
  @else
    println("❌ Failures detected in pure Maya Pratt Parser adversarial tests!")
    return 1
  @end
@end
