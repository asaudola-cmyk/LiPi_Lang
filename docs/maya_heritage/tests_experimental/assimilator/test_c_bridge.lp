@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — C BRIDGE ASSIMILATOR TEST SUITE
@! File: tests/assimilator/test_c_bridge.maya
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/assimilator/c_bridge"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ MAYA C HEADER ASSIMILATOR & BRIDGE GENERATOR TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: C Header Lexer & Tokenizer
  println("▶ Section 1: C Header Lexer & Comment Stripping...")
  total_tests = total_tests + 1
  c_code = "// Line comment\n/* Block comment */\n#define BUFFER_SIZE 4096\nint add(int a, int b);"
  tokens = c_tokenize_header(c_code)
  
  ok1_1 = assert_true(tokens.len() >= 10, "Token stream generated from C source")
  ok1_2 = assert_true(tokens[0].kind == "PREPROC", "Preproc directive tokenized")
  ok1_3 = assert_true(tokens[0].value == "define BUFFER_SIZE 4096", "Preproc text extracted without comments")
  @if ok1_1 == 1 && ok1_2 == 1 && ok1_3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] C Lexer & comment stripping verified")
  @end

  @! SECTION 2: Recursive-Descent C Declaration Parser
  println("▶ Section 2: Recursive-Descent Declaration Parser (Funcs, Structs, Enums)...")
  total_tests = total_tests + 1
  
  header_sample = "#define MAX_ENTRIES 256\n\ntypedef struct {\n    int x;\n    int y;\n    double z;\n} Point3D;\n\ntypedef enum {\n    STATUS_OK = 0,\n    STATUS_ERR = 1,\n    STATUS_BUSY = 2\n} StatusCode;\n\ntypedef uint64_t handle_t;\n\nint printf(const char* format, ...);\nvoid* malloc(size_t size);\nvoid free(void* ptr);\n"

  ast = c_parse_header_declarations(header_sample, "sample.h")

  @! Verify Macros
  ok2_1 = assert_eq_int(ast.macros.len(), 1, "Parsed 1 macro constant")
  ok2_2 = assert_true(ast.macros[0].name == "MAX_ENTRIES", "Macro name is MAX_ENTRIES")
  ok2_3 = assert_eq_int(ast.macros[0].int_val, 256, "Macro value is 256")

  @! Verify Structs
  ok2_4 = assert_eq_int(ast.structs.len(), 1, "Parsed 1 struct definition")
  s0 = ast.structs[0]
  ok2_5 = assert_true(s0.name == "Point3D", "Struct name is Point3D")
  ok2_6 = assert_eq_int(s0.fields.len(), 3, "Point3D has 3 fields (x, y, z)")
  ok2_7 = assert_true(s0.fields[0].name == "x" && s0.fields[0].field_type.base_name == "int", "Field x is int")
  ok2_8 = assert_true(s0.fields[2].name == "z" && s0.fields[2].field_type.base_name == "double", "Field z is double")

  @! Verify Enums
  ok2_9 = assert_eq_int(ast.enums.len(), 1, "Parsed 1 enum declaration")
  e0 = ast.enums[0]
  ok2_10 = assert_true(e0.name == "StatusCode", "Enum name is StatusCode")
  ok2_11 = assert_eq_int(e0.variants.len(), 3, "StatusCode has 3 variants")
  ok2_12 = assert_true(e0.variants[0].name == "STATUS_OK" && e0.variants[0].val == 0, "STATUS_OK == 0")
  ok2_13 = assert_true(e0.variants[2].name == "STATUS_BUSY" && e0.variants[2].val == 2, "STATUS_BUSY == 2")

  @! Verify Typedefs
  ok2_14 = assert_eq_int(ast.typedefs.len(), 1, "Parsed 1 typedef")
  ok2_15 = assert_true(ast.typedefs[0].alias_name == "handle_t", "Typedef alias is handle_t")

  @! Verify Functions
  ok2_16 = assert_eq_int(ast.functions.len(), 3, "Parsed 3 function prototypes (printf, malloc, free)")
  f_printf = ast.functions[0]
  ok2_17 = assert_true(f_printf.name == "printf", "Function name is printf")
  ok2_18 = assert_eq_int(f_printf.is_varargs, 1, "printf prototype has varargs (...)")
  ok2_19 = assert_true(f_printf.params[0].param_type.is_pointer == 1, "printf format parameter is pointer (char*)")

  f_malloc = ast.functions[1]
  ok2_20 = assert_true(f_malloc.name == "malloc", "Function name is malloc")
  ok2_21 = assert_true(f_malloc.ret_type.is_pointer == 1 && f_malloc.ret_type.base_name == "void", "malloc returns void*")

  @if ok2_1 == 1 && ok2_2 == 1 && ok2_3 == 1 && ok2_4 == 1 && ok2_5 == 1 && ok2_6 == 1 && ok2_7 == 1 && ok2_8 == 1 && ok2_9 == 1 && ok2_10 == 1 && ok2_11 == 1 && ok2_12 == 1 && ok2_13 == 1 && ok2_14 == 1 && ok2_15 == 1 && ok2_16 == 1 && ok2_17 == 1 && ok2_18 == 1 && ok2_19 == 1 && ok2_20 == 1 && ok2_21 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Complete C declaration parsing verified")
  @end

  @! SECTION 3: Maya FFI Bridge Code Generator
  println("▶ Section 3: Maya FFI Bridge Code Generation...")
  total_tests = total_tests + 1
  
  ca = {
    ca_funcs: [],
    ca_libs: [],
    ca_loaded: 1,
    ast: ast
  }
  @! Populate ca_funcs from ast
  i = 0
  @while i < ast.functions.len()
    fn_decl = ast.functions[i]
    ret_m = c_map_type_to_maya(fn_decl.ret_type)
    args = []
    j = 0
    @while j < fn_decl.params.len()
      p = fn_decl.params[j]
      args = args.push({ name: p.name, type: c_map_type_to_maya(p.param_type) })
      j = j + 1
    @end
    spec = {
      cf_name: fn_decl.name,
      cf_lib: "libc.so.6",
      cf_args: args,
      cf_ret_type: ret_m
    }
    ca.ca_funcs = ca.ca_funcs.push(spec)
    i = i + 1
  @end

  out_bridge_path = "/tmp/test_generated_bridge.maya"
  gen_ok = c_generate_bridge(ca, out_bridge_path)
  ok3_1 = assert_eq_int(gen_ok, 1, "Bridge generation returned success")
  
  bridge_content = file_read(out_bridge_path)
  ok3_2 = assert_true(contains(bridge_content, "const C_MAX_ENTRIES = 256"), "Emitted macro constant")
  ok3_3 = assert_true(contains(bridge_content, "@struct C_Point3D"), "Emitted Point3D struct")
  ok3_4 = assert_true(contains(bridge_content, "@fn c_printf("), "Emitted c_printf wrapper")
  ok3_5 = assert_true(contains(bridge_content, "@fn c_malloc("), "Emitted c_malloc wrapper")

  @if ok3_1 == 1 && ok3_2 == 1 && ok3_3 == 1 && ok3_4 == 1 && ok3_5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Maya FFI Bridge code generation verified")
  @end

  println("=================================================================")
  println("📊 C BRIDGE ASSIMILATOR TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 3 C BRIDGE ASSIMILATOR TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME C BRIDGE TESTS FAILED")
    return 1
  @end
@end
