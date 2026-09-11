import "compiler/frontend/ast"
import "compiler/frontend/lexer"
import "compiler/frontend/parser"
import "compiler/frontend/typecheck"
import "universe/core/string"

@fn main()
  src = "@fn test(x: i64) -> i64\n  @if x > 0\n    @return 1\n  @elif x < 0\n    @return -1\n  @else\n    @return 0\n  @end\n@end\n"
  println("Parsing elif program...")
  prog = parse_source_program(src)
  println("Typechecking...")
  env = typecheck_program_ast(prog)
  println("Errors: " + int_to_str(env.errors.len()))
  println("Warnings: " + int_to_str(env.warnings.len()))
  @if env.errors.len() == 0 && env.warnings.len() == 0
    println("✓ Elif probe passed cleanly with 0 segfaults!")
    return 0
  @else
    println("✗ Elif probe failed!")
    return 1
  @end
@end
