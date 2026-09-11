@! ============================================================================
@! ADVERSARIAL CHALLENGER VERIFICATION SUITE: MILESTONE M2
@! Typechecker, Semantic Analyzer, Struct Layout & Import Resolution
@! ============================================================================

import "compiler/frontend/ast"
import "compiler/frontend/lexer"
import "compiler/frontend/parser"
import "compiler/frontend/typecheck"
import "universe/core/string"

@fn assert_true(cond, test_name)
  @if cond == 1
    println("[PASS] " + test_name)
    return 1
  @else
    println("[FAIL] " + test_name)
    return 0
  @end
@end

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
  println("⚔️  ADVERSARIAL CHALLENGER VERIFICATION SUITE (MILESTONE M2) ⚔️")
  println("=================================================================")

  total_pass = 0
  total_fail = 0

  @! ---------------------------------------------------------------------------
  @! TEST SUITE 1: STRUCT LAYOUT ALIGNMENT & DEEP FIELD OFFSET COMPUTATION
  @! ---------------------------------------------------------------------------
  println("\n--- [1] Struct Layout Alignment & Offset Verification ---")

  src_structs = "
  @struct EmptyStruct
  @end

  @struct SingleField
    val: i64
  @end

  @struct MultiField
    a: i64
    b: f64
    c: bool
    d: string
    e: ptr
  @end

  @struct TenFields
    f0: i64
    f1: i64
    f2: i64
    f3: i64
    f4: i64
    f5: i64
    f6: i64
    f7: i64
    f8: i64
    f9: i64
  @end
  "

  env1 = typecheck_source(src_structs)

  @if assert_eq_i64(env1.errors.len(), 0, "No errors parsing 4 distinct structs") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_empty = tc_get_struct(env1, "EmptyStruct")
  @if assert_eq_i64(st_empty.total_size, 8, "Empty struct minimal aligned size is 8 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_empty.alignment, 8, "Empty struct alignment is 8") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_single = tc_get_struct(env1, "SingleField")
  @if assert_eq_i64(st_single.total_size, 8, "SingleField total size is 8 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_single.fields[0].offset_bytes, 0, "SingleField.val offset is 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_multi = tc_get_struct(env1, "MultiField")
  @if assert_eq_i64(st_multi.total_size, 40, "MultiField (5 fields) total size is 40 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_multi.fields[0].offset_bytes, 0, "MultiField.a offset is 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_multi.fields[1].offset_bytes, 8, "MultiField.b offset is 8") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_multi.fields[2].offset_bytes, 16, "MultiField.c offset is 16") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_multi.fields[3].offset_bytes, 24, "MultiField.d offset is 24") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_multi.fields[4].offset_bytes, 32, "MultiField.e offset is 32") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_ten = tc_get_struct(env1, "TenFields")
  @if assert_eq_i64(st_ten.total_size, 80, "TenFields total size is 80 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_ten.fields[9].offset_bytes, 72, "TenFields.f9 offset is 72") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST SUITE 2: MULTI-LEVEL SCOPING & SHADOWING RESILIENCE
  @! ---------------------------------------------------------------------------
  println("\n--- [2] Deep Scoping & Symbol Shadowing ---")

  env2 = typeenv_new()
  t_i64 = type_make_i64()
  t_f64 = type_make_f64()
  t_str = type_make_string()
  t_bool = type_make_bool()

  @! Global scope (depth 0)
  env2 = scope_define_var(env2, "x", t_i64, 0)
  env2 = scope_define_var(env2, "y", t_str, 0)

  @! Scope depth 1
  env2 = scope_enter(env2)
  env2 = scope_define_var(env2, "x", t_f64, 0)
  env2 = scope_define_var(env2, "z", t_bool, 0)

  @! Scope depth 2
  env2 = scope_enter(env2)
  env2 = scope_define_var(env2, "x", t_str, 0)
  env2 = scope_define_var(env2, "w", t_i64, 0)

  @! Scope depth 3
  env2 = scope_enter(env2)
  env2 = scope_define_var(env2, "x", t_bool, 0)

  @! At depth 3: x should be bool, w should be i64 (depth 2), z should be bool (depth 1), y should be string (depth 0)
  @if assert_eq_str(type_to_string(scope_lookup_var(env2, "x").var_type), "bool", "Depth 3: x is bool") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(scope_lookup_var(env2, "w").var_type), "i64", "Depth 3: w is i64 from depth 2") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(scope_lookup_var(env2, "z").var_type), "bool", "Depth 3: z is bool from depth 1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(scope_lookup_var(env2, "y").var_type), "string", "Depth 3: y is string from global") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Exit to depth 2: x should restore to string
  env2 = scope_exit(env2)
  @if assert_eq_str(type_to_string(scope_lookup_var(env2, "x").var_type), "string", "Depth 2: x restored to string") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Exit to depth 1: x should restore to f64, w should be gone
  env2 = scope_exit(env2)
  @if assert_eq_str(type_to_string(scope_lookup_var(env2, "x").var_type), "f64", "Depth 1: x restored to f64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(scope_lookup_var(env2, "w").name, "", "Depth 1: w is not visible") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Exit to global: x should restore to i64, z should be gone
  env2 = scope_exit(env2)
  @if assert_eq_str(type_to_string(scope_lookup_var(env2, "x").var_type), "i64", "Global: x restored to i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(scope_lookup_var(env2, "z").name, "", "Global: z is not visible") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST SUITE 3: TYPE INFERENCE ACROSS ARITHMETIC & LOGICAL BINARY OPS
  @! ---------------------------------------------------------------------------
  println("\n--- [3] Expression Type Inference & Binary Operations ---")

  env3 = typeenv_new()

  @! Helper AST nodes
  n_i64_1 = ast_literal_int(10)
  n_i64_2 = ast_literal_int(20)
  n_f64_1 = ast_literal_float(3.14)
  n_str_1 = ast_literal_str("hello")
  n_bool_1 = ast_literal_bool(1)

  @! i64 + i64 -> i64
  res_add_ii = check_expression(ast_binary_op(n_i64_1, "+", n_i64_2), env3)
  @if assert_eq_str(type_to_string(res_add_ii.type), "i64", "i64 + i64 -> i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! i64 + f64 -> f64
  res_add_if = check_expression(ast_binary_op(n_i64_1, "+", n_f64_1), env3)
  @if assert_eq_str(type_to_string(res_add_if.type), "f64", "i64 + f64 -> f64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! str + i64 -> string
  res_add_si = check_expression(ast_binary_op(n_str_1, "+", n_i64_1), env3)
  @if assert_eq_str(type_to_string(res_add_si.type), "string", "str + i64 -> string") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Comparisons -> bool
  res_eq = check_expression(ast_binary_op(n_i64_1, "==", n_i64_2), env3)
  @if assert_eq_str(type_to_string(res_eq.type), "bool", "i64 == i64 -> bool") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  res_gt = check_expression(ast_binary_op(n_f64_1, ">", n_i64_1), env3)
  @if assert_eq_str(type_to_string(res_gt.type), "bool", "f64 > i64 -> bool") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Logical AND / OR -> bool
  res_and = check_expression(ast_binary_op(n_bool_1, "&&", n_bool_1), env3)
  @if assert_eq_str(type_to_string(res_and.type), "bool", "bool && bool -> bool") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Bitwise operations -> i64
  res_shl = check_expression(ast_binary_op(n_i64_1, "<<", n_i64_2), env3)
  @if assert_eq_str(type_to_string(res_shl.type), "i64", "i64 << i64 -> i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Pipeline operator |>
  res_pipe = check_expression(ast_binary_op(n_i64_1, "|>", n_str_1), env3)
  @if assert_eq_str(type_to_string(res_pipe.type), "string", "expr |> str -> string") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Unary not ! -> bool
  res_not = check_expression(ast_unary_op("!", n_i64_1), env3)
  @if assert_eq_str(type_to_string(res_not.type), "bool", "!i64 -> bool") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST SUITE 4: DEEP MEMBER ACCESS & METHOD CHAINS
  @! ---------------------------------------------------------------------------
  println("\n--- [4] Deep Member Access & Method Resolution Chains ---")

  src_chain = "
  @struct Inner
    value: i64
  @end

  @struct Middle
    inner: Inner
  @end

  @struct Outer
    middle: Middle
  @end

  @impl Outer
    @fn get_middle() -> Middle
      @return self.middle
    @end
  @end

  @impl Middle
    @fn get_inner() -> Inner
      @return self.inner
    @end
  @end

  @impl Inner
    @fn get_val() -> i64
      @return self.value
    @end
  @end

  @fn main() -> i64
    out = { middle: { inner: { value: 99 } } }
    v1 = out.middle.inner.value
    m = out.get_middle()
    i = m.get_inner()
    v2 = i.get_val()
    @return v1 + v2
  @end
  "

  env4 = typecheck_source(src_chain)
  @if assert_eq_i64(env4.errors.len(), 0, "Deep chain program typechecks with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Check structs registered
  @if assert_true(tc_has_struct(env4, "Outer"), "Outer struct registered") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_true(tc_has_struct(env4, "Middle"), "Middle struct registered") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_true(tc_has_struct(env4, "Inner"), "Inner struct registered") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Check methods registered with receiver injection
  @if assert_true(tc_has_fn(env4, "Outer_get_middle"), "Outer_get_middle registered") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_true(tc_has_fn(env4, "Middle_get_inner"), "Middle_get_inner registered") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_true(tc_has_fn(env4, "Inner_get_val"), "Inner_get_val registered") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Verify method return types
  fn_mid = tc_lookup_fn(env4, "Outer_get_middle")
  @if assert_eq_str(type_to_string(fn_mid.ret_type), "Middle", "Outer_get_middle returns Middle") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  fn_inn = tc_lookup_fn(env4, "Middle_get_inner")
  @if assert_eq_str(type_to_string(fn_inn.ret_type), "Inner", "Middle_get_inner returns Inner") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  fn_val = tc_lookup_fn(env4, "Inner_get_val")
  @if assert_eq_str(type_to_string(fn_val.ret_type), "i64", "Inner_get_val returns i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Array and String built-in .len property access
  t_arr_i64 = type_make_array(t_i64)
  env4 = scope_define_var(env4, "test_arr", t_arr_i64, 0)
  env4 = scope_define_var(env4, "test_str", t_str, 0)

  arr_var = ast_variable("test_arr")
  str_var = ast_variable("test_str")

  arr_len_acc = ast_member_access(arr_var, "len")
  res_arr_len = check_expression(arr_len_acc, env4)
  @if assert_eq_str(type_to_string(res_arr_len.type), "i64", "array.len returns i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  str_len_acc = ast_member_access(str_var, "len")
  res_str_len = check_expression(str_len_acc, env4)
  @if assert_eq_str(type_to_string(res_str_len.type), "i64", "string.len returns i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST SUITE 5: CONTROL-FLOW ANALYSIS & MISSING RETURN VERIFICATION (PASS 4)
  @! ---------------------------------------------------------------------------
  println("\n--- [5] Control-Flow & Return Path Analysis ---")

  @! 5a. Complete return paths: if/else with return in both branches
  src_ret_complete = "
  @fn abs_val(x: i64) -> i64
    @if x >= 0
      @return x
    @else
      @return -x
    @end
  @end
  "
  env5a = typecheck_source(src_ret_complete)
  @if assert_eq_i64(env5a.warnings.len(), 0, "Complete if-else return produces 0 warnings") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 5b. Incomplete return path: if without else
  src_ret_missing = "
  @fn bad_fn(x: i64) -> i64
    @if x > 10
      @return x
    @end
  @end
  "
  env5b = typecheck_source(src_ret_missing)
  @if assert_eq_i64(env5b.warnings.len(), 1, "Missing else branch generates 1 return warning") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 5c. Void function does not require return
  src_void_fn = "
  @fn log_msg(msg: string) -> void
    println(msg)
  @end
  "
  env5e = typecheck_source(src_void_fn)
  @if assert_eq_i64(env5e.warnings.len(), 0, "Void function requires 0 returns") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST SUITE 6: IMPORT CYCLE DETECTION ALGORITHMS
  @! ---------------------------------------------------------------------------
  println("\n--- [6] Import Cycle Detection (Graph Traversal) ---")

  @! Test import_graph_has_cycle
  visited_stack1 = ["moduleA", "moduleB", "moduleC"]

  @! Check cycle when next path is moduleA (cycle: moduleA -> moduleB -> moduleC -> moduleA)
  @if assert_eq_i64(import_graph_has_cycle([], "moduleA", visited_stack1), 1, "Direct cycle detected on moduleA") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Check cycle when next path is moduleB (cycle: moduleB -> moduleC -> moduleB)
  @if assert_eq_i64(import_graph_has_cycle([], "moduleB", visited_stack1), 1, "Subcycle detected on moduleB") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Check non-cycle when next path is moduleD (no cycle)
  @if assert_eq_i64(import_graph_has_cycle([], "moduleD", visited_stack1), 0, "No cycle for fresh unvisited moduleD") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Empty stack has no cycle
  @if assert_eq_i64(import_graph_has_cycle([], "moduleA", []), 0, "Empty stack has no cycle") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST SUITE 7: TYPE ASSIGNABILITY & EQUALITY MATRIX
  @! ---------------------------------------------------------------------------
  println("\n--- [7] Type System Assignability & Subtyping Rules ---")

  t_any = type_make_any()
  t_void = type_make_void()
  t_ptr = type_make_ptr()
  st_a = type_make_struct("StructA", [])
  st_b = type_make_struct("StructB", [])
  arr_i64 = type_make_array(t_i64)
  arr_str = type_make_array(t_str)

  @! Any matches anything
  @if assert_eq_i64(type_is_assignable(t_any, t_i64), 1, "any <- i64 assignable") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(type_is_assignable(t_i64, t_any), 1, "i64 <- any assignable") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! bool -> i64 coercion supported in Maya
  @if assert_eq_i64(type_is_assignable(t_i64, t_bool), 1, "i64 <- bool assignable") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Incompatible types
  @if assert_eq_i64(type_is_assignable(t_bool, t_i64), 0, "bool <- i64 NOT assignable") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(type_is_assignable(t_str, t_f64), 0, "string <- f64 NOT assignable") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(type_is_assignable(st_a, st_b), 0, "StructA <- StructB NOT assignable") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(type_is_assignable(arr_i64, arr_str), 0, "array[i64] <- array[string] NOT assignable") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(type_is_assignable(arr_i64, arr_i64), 1, "array[i64] <- array[i64] assignable") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! TEST SUITE 8: DIAGNOSTIC & ERROR GENERATION EDGE CASES
  @! ---------------------------------------------------------------------------
  println("\n--- [8] Diagnostic & Error Reporting Verification ---")

  @! 8a. Break outside loop triggers error
  src_bad_break = "
  @fn run() -> void
    @break
  @end
  "
  env8a = typecheck_source(src_bad_break)
  @if assert_eq_i64(env8a.errors.len(), 1, "Break outside loop generates 1 error") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 8b. Continue outside loop triggers error
  src_bad_cont = "
  @fn run() -> void
    @continue
  @end
  "
  env8c = typecheck_source(src_bad_cont)
  @if assert_eq_i64(env8c.errors.len(), 1, "Continue outside loop generates 1 error") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 8c. Break inside loop is valid (0 errors)
  src_good_loop = "
  @fn run() -> void
    i = 0
    @while i < 10
      @if i == 5
        @break
      @end
      i = i + 1
    @end
  @end
  "
  env8d = typecheck_source(src_good_loop)
  @if assert_eq_i64(env8d.errors.len(), 0, "Break inside while loop produces 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 8d. Enum constants registration and resolution
  src_enum = "
  @enum LogLevel
    DEBUG = 0
    INFO = 1
    WARN = 5
    ERROR = 6
  @end

  @fn get_default_level() -> i64
    @return LogLevel_INFO
  @end
  "
  env8e = typecheck_source(src_enum)
  @if assert_eq_i64(env8e.errors.len(), 0, "Enum definition and usage produces 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env8e, "LogLevel_WARN"), 5, "LogLevel_WARN constant value is 5") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  println("\n=================================================================")
  println("📊 ADVERSARIAL CHALLENGER SUMMARY: " + int_to_str(total_pass) + " passed, " + int_to_str(total_fail) + " failed")
  println("=================================================================")

  @if total_fail == 0
    println("✓ All Base Adversarial Challenger Tests Passed 100%!")
    return 0
  @else
    println("✗ Adversarial Challenger Tests Failed!")
    return 1
  @end
@end
