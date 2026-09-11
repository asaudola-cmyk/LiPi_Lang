@! ============================================================================
@! ADVERSARIAL TEST SUITE — PHASE 5: C HEADER ASSIMILATOR & BRIDGE (CHALLENGER 2)
@! Module: tests/adversarial/test_adv_phase5_challenger2_c_bridge.maya
@! Stress-testing C header lexer, comments, multi-parameter prototypes, structs,
@! enums, typedefs, preprocessor macros, and FFI bridge code generation.
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/assimilator/c_bridge"

@fn assert_true(cond, msg: string)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    exit(1)
  @else
    println("  [PASS] " + msg)
  @end
@end

@fn assert_eq_str(got: string, exp: string, msg: string)
  @if got != exp
    println("  [FAIL] " + msg + " (Got: '" + got + "', Expected: '" + exp + "')")
    exit(1)
  @else
    println("  [PASS] " + msg)
  @end
@end

@fn assert_eq_int(got: i64, exp: i64, msg: string)
  @if got != exp
    println("  [FAIL] " + msg + " (Got: " + got.to_str() + ", Expected: " + exp.to_str() + ")")
    exit(1)
  @else
    println("  [PASS] " + msg + " == " + exp.to_str())
  @end
@end

@fn assert_contains(haystack: string, needle: string, msg: string)
  @if string_contains(haystack, needle) != 1
    println("  [FAIL] Output does not contain: '" + needle + "' - " + msg)
    exit(1)
  @else
    println("  [PASS] Contains '" + needle + "' (" + msg + ")")
  @end
@end

println("=================================================================")
println("⚡ ADVERSARIAL C HEADER ASSIMILATOR TEST SUITE (CHALLENGER 2) ⚡")
println("=================================================================")

@! ----------------------------------------------------------------------------
@! 1. Complex C Header with Tricky Comments & Preprocessor Directives
@! ----------------------------------------------------------------------------
println("\n▶ Section 1: Complex C Header Lexing & Comment Stripping...")

header_path = "tests/adversarial/input_test_c_bridge.h"
complex_c_header = file_read(header_path)
assert_true(complex_c_header.len() > 0, "Read C header file")

ast = c_parse_header_declarations(complex_c_header, header_path)

@! 1.1 Verify Macros
assert_eq_int(ast.macros.len(), 2, "2 macro constants extracted")
assert_eq_str(ast.macros[0].name, "BUFFER_CAPACITY", "Macro 0 name")
assert_eq_str(ast.macros[0].val_str, "8192", "Macro 0 value string")
assert_eq_int(ast.macros[0].int_val, 8192, "Macro 0 evaluated int == 8192")
assert_eq_str(ast.macros[1].name, "MAGIC_HEADER", "Macro 1 name")
assert_eq_str(ast.macros[1].val_str, "0xDEADBEEF", "Macro 1 value string (0xDEADBEEF)")

@! 1.2 Verify Enums
assert_eq_int(ast.enums.len(), 1, "1 enum declaration extracted")
enum_decl = ast.enums[0]
assert_eq_str(enum_decl.name, "StatusCode", "Enum name 'StatusCode'")
assert_eq_int(enum_decl.variants.len(), 5, "5 enum variants")
assert_eq_str(enum_decl.variants[0].name, "STATUS_OK", "Variant 0 name")
assert_eq_int(enum_decl.variants[0].val, 0, "Variant 0 value == 0")
assert_eq_str(enum_decl.variants[1].name, "STATUS_PENDING", "Variant 1 name")
assert_eq_int(enum_decl.variants[1].val, 5, "Variant 1 value == 5")
assert_eq_str(enum_decl.variants[2].name, "STATUS_TIMEOUT", "Variant 2 name")
assert_eq_int(enum_decl.variants[2].val, 6, "Variant 2 sequential value == 6")
assert_eq_str(enum_decl.variants[3].name, "STATUS_ERR_OOM", "Variant 3 name")
assert_eq_int(enum_decl.variants[3].val, 100, "Variant 3 explicit value == 100")
assert_eq_str(enum_decl.variants[4].name, "STATUS_ERR_FATAL", "Variant 4 name")
assert_eq_int(enum_decl.variants[4].val, 101, "Variant 4 sequential value == 101")

@! 1.3 Verify Structs
assert_eq_int(ast.structs.len(), 2, "2 structs extracted")
s1 = ast.structs[0]
assert_eq_str(s1.name, "ClientMetrics", "Struct 1 name 'ClientMetrics'")
assert_eq_int(s1.fields.len(), 6, "Struct 1 has 6 fields")
assert_eq_str(s1.fields[0].name, "session_id", "Field 0 name")
assert_eq_str(s1.fields[0].field_type.base_name, "uint32_t", "Field 0 type base")
assert_eq_str(s1.fields[1].name, "timestamp", "Field 1 name")
assert_eq_str(s1.fields[2].name, "client_ip", "Field 2 name")
assert_eq_int(s1.fields[2].field_type.is_pointer, 1, "Field 2 is pointer")
assert_eq_str(s1.fields[3].name, "throughput_mbps", "Field 3 name")
assert_eq_str(s1.fields[3].field_type.base_name, "double", "Field 3 type base")
assert_eq_str(s1.fields[4].name, "latency_ms", "Field 4 name")
assert_eq_str(s1.fields[5].name, "user_ctx", "Field 5 name")

s2 = ast.structs[1]
assert_eq_str(s2.name, "TaskNode", "Struct 2 name 'TaskNode'")
assert_eq_int(s2.fields.len(), 2, "Struct 2 has 2 fields")
assert_eq_str(s2.fields[0].name, "task_id", "TaskNode field 0")
assert_eq_str(s2.fields[1].name, "next", "TaskNode field 1")
assert_eq_int(s2.fields[1].field_type.is_pointer, 1, "TaskNode field 1 is pointer")

@! 1.4 Verify Functions
assert_eq_int(ast.functions.len(), 5, "5 functions extracted")

@! engine_reset(void)
fn0 = ast.functions[0]
assert_eq_str(fn0.name, "engine_reset", "Fn 0 name")
assert_eq_str(fn0.ret_type.base_name, "void", "Fn 0 return type void")
assert_eq_int(fn0.params.len(), 0, "Fn 0 has 0 params (void param omitted)")

@! engine_init(const char *config_path)
fn1 = ast.functions[1]
assert_eq_str(fn1.name, "engine_init", "Fn 1 name")
assert_eq_str(fn1.ret_type.base_name, "int", "Fn 1 return type int")
assert_eq_int(fn1.params.len(), 1, "Fn 1 has 1 param")
assert_eq_str(fn1.params[0].name, "config_path", "Fn 1 param 0 name")
assert_eq_int(fn1.params[0].param_type.is_pointer, 1, "Fn 1 param 0 is pointer")

@! net_send_packet(int, const void*, size_t, uint32_t, const char*, uint16_t)
fn2 = ast.functions[2]
assert_eq_str(fn2.name, "net_send_packet", "Fn 2 name")
assert_eq_int(fn2.params.len(), 6, "Fn 2 has 6 params")
assert_eq_str(fn2.params[0].name, "socket_fd", "Fn 2 param 0 name")
assert_eq_str(fn2.params[1].name, "payload", "Fn 2 param 1 name")
assert_eq_str(fn2.params[2].name, "length", "Fn 2 param 2 name")
assert_eq_str(fn2.params[3].name, "flags", "Fn 2 param 3 name")
assert_eq_str(fn2.params[4].name, "dest_host", "Fn 2 param 4 name")
assert_eq_str(fn2.params[5].name, "port", "Fn 2 param 5 name")

@! log_formatted_event(int level, const char *format, ...)
fn3 = ast.functions[3]
assert_eq_str(fn3.name, "log_formatted_event", "Fn 3 name")
assert_eq_int(fn3.is_varargs, 1, "Fn 3 is_varargs == 1")
assert_eq_int(fn3.params.len(), 2, "Fn 3 has 2 named params before varargs")

@! compute_clamp (inline function with body)
fn4 = ast.functions[4]
assert_eq_str(fn4.name, "compute_clamp", "Fn 4 name")
assert_eq_int(fn4.is_inline, 1, "Fn 4 is_inline == 1")
assert_eq_int(fn4.params.len(), 3, "Fn 4 has 3 params")

@! ----------------------------------------------------------------------------
@! 2. Maya FFI Bridge Code Generation
@! ----------------------------------------------------------------------------
println("\n▶ Section 2: Maya FFI Bridge Code Generation...")

ca = {
  ca_funcs: [],
  ca_libs: [],
  ca_loaded: 1,
  ast: ast
}

@! Register function specs for bridge emitter
i = 0
@while i < ast.functions.len()
  f_ast = ast.functions[i]
  ret_t = c_map_type_to_maya(f_ast.ret_type)
  args_t = []
  j = 0
  @while j < f_ast.params.len()
    p_ast = f_ast.params[j]
    args_t = args_t.push({ name: p_ast.name, type: c_map_type_to_maya(p_ast.param_type) })
    j = j + 1
  @end
  spec = {
    cf_name: f_ast.name,
    cf_lib: "libnet.so",
    cf_args: args_t,
    cf_ret_type: ret_t
  }
  ca.ca_funcs = ca.ca_funcs.push(spec)
  i = i + 1
@end
