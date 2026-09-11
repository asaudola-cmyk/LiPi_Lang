import "compiler/frontend/ast"
import "compiler/frontend/lexer"
import "compiler/frontend/parser"
import "compiler/frontend/typecheck"
import "universe/core/string"

@fn main()
  src = "@enum LogLevel\n  DEBUG = 0\n  INFO = 1\n  WARN = 5\n  ERROR = 6\n@end\n"
  prog = parse_source_program(src)
  println("prog.constants len: " + int_to_str(prog.constants.len()))
  i = 0
  @while i < prog.constants.len()
    c = prog.constants[i]
    println("prog.constant " + int_to_str(i) + ": name=" + ast_const_get_name(c) + ", val=" + int_to_str(ast_const_get_value(c)))
    i = i + 1
  @end
  
  env = typecheck_program_ast(prog)
  println("env.constants len: " + int_to_str(env.constants.len()))
  i = 0
  @while i < env.constants.len()
    c = env.constants[i]
    println("env.constant " + int_to_str(i) + ": name=" + ast_const_get_name(c) + " val=" + int_to_str(ast_const_get_value(c)))
    i = i + 1
  @end
@end
