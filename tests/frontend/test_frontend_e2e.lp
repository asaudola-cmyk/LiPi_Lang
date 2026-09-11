@! ============================================================================
@! PURE MAYA FRONTEND END-TO-END PIPELINE INTEGRATION SUITE
@! Tests Full Lifecycle: Source -> Lexer -> Pratt Parser -> Lowering -> Typecheck
@! ============================================================================

import "compiler/frontend/ast"
import "compiler/frontend/lexer"
import "compiler/frontend/parser"
import "compiler/frontend/typecheck"
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
  println("🧪 PURE MAYA FRONTEND E2E PIPELINE INTEGRATION SUITE 🧪")
  println("=================================================================")

  total_pass = 0
  total_fail = 0

  @! Complex Real-World Maya Program: Geometry, Vector Math, String Interpolation & Impl Blocks
  src_pipeline = "// Geometry System in Pure Maya\n@struct Point2D\n  x: i64\n  y: i64\n@end\n\n@enum ShapeType\n  Circle\n  Rectangle\n  Polygon = 10\n@end\n\n@impl Point2D\n  @fn manhattan_dist(other: Point2D) -> i64\n    dx = self.x - other.x\n    dy = self.y - other.y\n    @if dx < 0 dx = -dx @end\n    @if dy < 0 dy = -dy @end\n    @return dx + dy\n  @end\n@end\n\n@fn compute_metrics(p1: Point2D, p2: Point2D) -> i64\n  dist = p1.manhattan_dist(p2)\n  msg = \"Distance: {dist}\"\n  @return dist\n@end\n\n@fn main() -> i64\n  pt_a = { x: 10, y: 20 }\n  pt_b = { x: 30, y: 50 }\n  d = compute_metrics(pt_a, pt_b)\n  @return d\n@end\n"

  @! Stage 1: Lexical Analysis
  tokens = tokenize_source(src_pipeline)
  @if assert_eq_i64(tokens.len() > 20, 1, "Lexer produced > 20 tokens") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Stage 2: Pratt Parsing & Syntactic Lowering
  prog = parse_program_from_tokens(tokens)
  @if assert_eq_i64(prog.structs.len(), 1, "Parser extracted 1 struct (Point2D)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_name(prog.structs[0]), "Point2D", "Struct name is Point2D") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(prog.enums.len(), 1, "Parser extracted 1 enum (ShapeType)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(prog.constants.len(), 3, "Desugared 3 enum constants") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_const_get_name(prog.constants[2]), "ShapeType_Polygon", "Polygon constant generated") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_const_get_value(prog.constants[2]), 10, "Polygon value is 10") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Stage 3: Impl Method Injection
  @if assert_eq_i64(prog.functions.len(), 3, "Functions include Point2D_manhattan_dist, compute_metrics, main") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  fn_dist = prog.functions[0]
  @if assert_eq_str(ast_get_name(fn_dist), "Point2D_manhattan_dist", "Impl method injected as Point2D_manhattan_dist") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Stage 4: Multi-Pass Semantic Typechecking
  env = typecheck_program_ast(prog)
  @if assert_eq_i64(env.errors.len(), 0, "Pipeline typecheck produced 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_has_struct(env, "Point2D"), 1, "Typeenv registered Point2D") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_has_fn(env, "Point2D_manhattan_dist"), 1, "Typeenv registered Point2D_manhattan_dist") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_has_fn(env, "compute_metrics"), 1, "Typeenv registered compute_metrics") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  println("=================================================================")
  println("📊 TEST SUMMARY: " + int_to_str(total_pass) + " passed, " + int_to_str(total_fail) + " failed")
  println("=================================================================")

  @if total_fail == 0
    println("✓ Pure Maya Frontend E2E Pipeline Integration tests passed 100%!")
    return 0
  @else
    return 1
  @end
@end
