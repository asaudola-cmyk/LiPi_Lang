import "compiler/frontend/lexer"
import "compiler/frontend/parser"
@! ============================================================================
@! MAYA COMPILER V2 — Pure Maya Self-Hosted Compiler Entry Point
@! This file IS the Maya compiler, written entirely in Maya.
@! Maya compiling Maya: the ultimate bootstrap.


@! ============================================================================

import "compiler/backend/compiler"

@fn mayac_version()
  return "2.0.0-maya"
@end

@fn mayac_usage()
  println("Maya Compiler v2.0.0-maya — Pure Maya Native Compiler")
  println("Usage: mayac <source.maya|source.my> [-o <output>] [options]")
  println("")
  println("Source extensions:")
  println("  .maya            Primary Maya source file extension")
  println("  .my              Short-form Maya source file extension (alias for .maya)")
  println("")
  println("Options:")
  println("  -o <file>        Output binary path (default: a.out)")
  println("  --dump-tokens    Dump lexer token stream")
  println("  --dump-ast       Dump parsed AST statement nodes")
  println("  --dump-ir        Dump lowered Maya IR module")
  println("  --dump-asm       Dump generated x86-64 machine code info")
  println("  -v, --version    Show compiler version")
  println("  -h, --help       Show this help message")
@end

@! ============================================================================
@! EXTENSION SUPPORT: .maya and .my are both valid Maya source extensions.
@! The .my extension is a short-form alias — functionally identical to .maya.
@! ============================================================================

@fn mayac_has_valid_ext(path)
  @! Returns 1 if path ends with .maya or .my, else 0.
  @if compiler_str_ends_with(path, ".maya") == 1
    return 1
  @end
  @if compiler_str_ends_with(path, ".my") == 1
    return 1
  @end
  return 0
@end

@fn maya_resolve_import(import_path, base_dir)
  @! Resolves an import path to an actual file, trying .maya then .my extensions.
  @if mayac_has_valid_ext(import_path) == 1
    return import_path
  @end
  candidate_maya = string_concat(import_path, ".maya")
  @if file_exists(candidate_maya) == 1
    return candidate_maya
  @end
  candidate_my = string_concat(import_path, ".my")
  @if file_exists(candidate_my) == 1
    return candidate_my
  @end
  @if compiler_str_eq(base_dir, "") == 0 && compiler_str_eq(base_dir, ".") == 0
    candidate_full_maya = string_concat(string_concat(base_dir, "/"), string_concat(import_path, ".maya"))
    @if file_exists(candidate_full_maya) == 1
      return candidate_full_maya
    @end
    candidate_full_my = string_concat(string_concat(base_dir, "/"), string_concat(import_path, ".my"))
    @if file_exists(candidate_full_my) == 1
      return candidate_full_my
    @end
  @end
  return string_concat(import_path, ".maya")
@end

@fn mayac_compile_file(input_path, output_path, options) 
 
  opts = options
  @if opts == 0
    
 
 opts = {
      opt_dump_tokens: 0,
      opt_dump_ast: 0,
      opt_dump_ir: 0,
      opt_dump_asm: 0,
      opt_module_name: "maya_program",
      opt_opt_level: 0,
      opt_base_dir: "."
    }
  @end

  res = compile_file_with_options(input_path, output_path, opts)
  @if res.cr_success == 1
    return 1
  @else
    println(string_concat("Error: Compilation failed for ", input_path))
    @if res.cr_error_msg != 0 && compiler_str_eq(res.cr_error_msg, "") == 0
      println(string_concat("  ", res.cr_error_msg))
    @end
    return 0
  @end
@end

@fn mayac_self_test()
  println(string_concat(string_concat("Maya Compiler v", mayac_version()), " — Pure Maya"))
  println("Running self-test: compiling in-memory hello world...")
  test_src = "@fn main() println(\"Hello from mayac v2!\") return 0 @end"
  test_out = "/tmp/mayac_v2_test"
  r = compile_source_to_elf(test_src, test_out)
  @if r == 1
    println(string_concat("[PASS] Self-test: successfully compiled in-memory test program to ", test_out))
    return 0
  @else
    println("[FAIL] Self-test failed")
    return 1
  @end
@end

@struct ProcessStatus
  val: i64
@end

@fn freestanding_exec(bin_path)
  child_pid = syscall(57, 0, 0, 0, 0, 0, 0)
  @if child_pid == 0
    syscall(59, bin_path, 0, 0, 0, 0, 0)
    syscall(60, 127, 0, 0, 0, 0, 0)
  @end
  @if child_pid < 0
    return child_pid
  @end
  ps = { val: 0 }
  syscall(61, child_pid, ps, 0, 0, 0, 0)
  status = ps.val
  @if (status % 256) == 0
    return (status / 256) % 256
  @end
  return status
@end

@fn main(argc, argv)
  println("DEBUG 1")
  sys_write_byte(1, 65)

  @if argc <= 1
    dump_tokens = 1
    sys_exit(42)
  @end

  input_file = ""
  output_file = ""
  dump_tokens = 0
  dump_ast = 0
  dump_ir = 0
  dump_asm = 0
  is_build_cmd = 0

  i = 1
  @while i < argc
    
 raw_arg = sys_argv(i)
    
 arg = maya_str_new(raw_arg)
    
 @if compiler_str_eq(arg, "-h") == 1 || compiler_str_eq(arg, "--help") == 1
      mayac_usage()
      return 0
    @elif compiler_str_eq(arg, "-v") == 1 || compiler_str_eq(arg, "--version") == 1
      println("Maya Compiler v2.0.0-maya")
      return 0
    @elif compiler_str_eq(arg, "build") == 1
      is_build_cmd = 1
    @elif compiler_str_eq(arg, "-o") == 1
      @if i + 1 < argc
        
 output_file = maya_str_new(sys_argv(i + 1))
        
 i = i + 1
      @else
        println("Error: -o requires an output filename")
        return 1
      @end
    @elif compiler_str_eq(arg, "--dump-tokens") == 1
      dump_tokens = 1
    @elif compiler_str_eq(arg, "--dump-ast") == 1
      dump_ast = 1
    @elif compiler_str_eq(arg, "--dump-ir") == 1
      dump_ir = 1
    @elif compiler_str_eq(arg, "--dump-asm") == 1
      dump_asm = 1
    @elif compiler_str_eq(arg, "--self-test") == 1
      dump_tokens = 1
    sys_exit(42)
    @else
      @if compiler_str_eq(input_file, "") == 1
        input_file = arg
      @end
    @end
    
 i = i + 1
  @end

  @if compiler_str_eq(input_file, "") == 1
    mayac_usage()
    return 1
  @end

  @! Validate that the input file has a recognised Maya extension (.maya or .my)
  @if mayac_has_valid_ext(input_file) == 0
    println(string_concat("Error: input file must have .maya or .my extension: ", input_file))
    println("  .maya  — standard Maya source extension")
    println("  .my    — short-form Maya source extension (alias for .maya)")
    return 1
  @end

  
 
 opts = {
    opt_dump_tokens: dump_tokens,
    opt_dump_ast: dump_ast,
    opt_dump_ir: dump_ir,
    opt_dump_asm: dump_asm,
    opt_module_name: "maya_program",
    opt_opt_level: 0,
    opt_base_dir: "."
  }

  @if compiler_str_eq(output_file, "") == 0 || is_build_cmd == 1
    @if compiler_str_eq(output_file, "") == 1
      output_file = "a.out"
    @end
    println("Before compile!")
ok = mayac_compile_file(input_file, output_file, opts)
println("After compile!")
    @if ok == 1
      return 0
    @else
      return 1
    @end
  @else
    tmp_bin = "/tmp/_maya_exec_runner.bin"
    res = compile_file_with_options(input_file, tmp_bin, opts)
    @if res.cr_success == 1
      ret = freestanding_exec(tmp_bin)
      return ret
    @else
      println(string_concat("Error: Compilation failed for ", input_file))
      @if res.cr_error_msg != 0 && compiler_str_eq(res.cr_error_msg, "") == 0
        println(string_concat("  ", res.cr_error_msg))
      @end
      return 1
    @end
  @end
@end

@fn compiler_str_ends_with(s, suffix)
  slen = str_len(s)
  suflen = str_len(suffix)
  @if suflen > slen return 0 @end
  i = 0
  start_idx = slen - suflen
  @while i < suflen
    @if str_char_at(s, start_idx + i) != str_char_at(suffix, i)
      return 0
    @end
    
 i = i + 1
  @end
  return 1
@end
