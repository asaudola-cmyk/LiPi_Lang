import "compiler/frontend/ast"
import "compiler/frontend/lexer"
import "compiler/frontend/parser"
import "compiler/frontend/typecheck"
import "universe/core/string"

@fn main()
  src = "@struct MultiField\n  a: i64\n  b: f64\n  c: bool\n@end\n"
  println("Parsing struct program...")
  prog = parse_source_program(src)
  println("Typechecking...")
  env = typecheck_program_ast(prog)
  st = tc_get_struct(env, "MultiField")
  println("Struct name: " + tc_struct_get_name(st))
  f = tc_struct_get_field(st, "c")
  println("Found field 'c': name=" + tc_field_get_name(f) + " offset=" + int_to_str(tc_field_get_offset(f)) + " idx=" + int_to_str(tc_field_get_index(f)))
  @if tc_field_get_name(f) == "c" && tc_field_get_offset(f) == 16
    println("✓ Struct field probe passed cleanly!")
    return 0
  @else
    println("✗ Struct field probe failed!")
    return 1
  @end
@end
