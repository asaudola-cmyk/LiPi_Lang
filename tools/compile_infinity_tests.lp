import "compiler/backend/compiler"

@fn main()
  println("▶ Compiling tests/test_infinity_syntax.maya directly...")
  src = file_read("tests/test_infinity_syntax.lp")
  opts = CompilerOptions {
    opt_dump_tokens: 0,
    opt_dump_ast: 0,
    opt_dump_ir: 0,
    opt_dump_asm: 0,
    opt_module_name: "test_infinity_syntax",
    opt_opt_level: 0,
    opt_base_dir: "."
  }
  res = compile_source_with_options(src, "bin/test_infinity_syntax_direct", opts)
  println("  Compile result: " + res.cr_success.to_str())
  @if res.cr_success == 1
    println("✓ Compilation SUCCESS! Output: bin/test_infinity_syntax_direct")
    return 0
  @else
    println("❌ Compilation FAILED: " + res.cr_error_msg)
    return 1
  @end
@end
