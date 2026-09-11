import "compiler/frontend/ast"
import "compiler/frontend/lexer"
import "compiler/frontend/parser"
import "compiler/frontend/typecheck"
import "universe/core/string"

@fn main()
  src = "@struct DupField\n  x: i64\n  x: string\n@end\n"
  println("Parsing dup field struct...")
  prog = parse_source_program(src)
  println("Typechecking...")
  env = typecheck_program_ast(prog)
  println("Errors: " + int_to_str(env.errors.len()))
  i = 0
  @while i < env.errors.len()
    println("Error " + int_to_str(i) + ": " + env.errors[i])
    i = i + 1
  @end
@end
