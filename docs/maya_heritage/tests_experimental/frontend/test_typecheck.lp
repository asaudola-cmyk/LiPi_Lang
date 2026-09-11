@! ============================================================================
@! PURE MAYA FRONTEND UNIT & INTEGRATION TESTS: TYPECHECKER & SEMANTIC ANALYSIS
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
  println("🧪 PURE MAYA MULTI-PASS TYPECHECKER VERIFICATION SUITE 🧪")
  println("=================================================================")

  total_pass = 0
  total_fail = 0

  @! 1. Core Type Constructors & String Formatting
  t_i64 = type_make_i64()
  t_f64 = type_make_f64()
  t_bool = type_make_bool()
  t_str = type_make_string()
  t_arr = type_make_array(t_i64)
  t_res = type_make_result(t_i64, t_str)

  @if assert_eq_str(type_to_string(t_i64), "i64", "t_i64 type string is 'i64'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(t_f64), "f64", "t_f64 type string is 'f64'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(t_bool), "bool", "t_bool type string is 'bool'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(t_str), "string", "t_str type string is 'string'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(t_arr), "array[i64]", "t_arr type string is 'array[i64]'") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 2. Type Equality & Assignability
  @if assert_eq_i64(type_equals(t_i64, type_make_i64()), 1, "i64 == i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(type_equals(t_i64, t_f64), 0, "i64 != f64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(type_is_assignable(t_i64, t_bool), 1, "bool is assignable to i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(type_is_assignable(t_str, t_i64), 0, "i64 is not assignable to string") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 3. Type Environment & Scoped Variable Shadowing
  env0 = typeenv_new()
  env0 = scope_define_var(env0, "global_x", t_i64, 0)
  v_glob = scope_lookup_var(env0, "global_x")
  @if assert_eq_str(v_glob.name, "global_x", "Found global_x in global scope") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(v_glob.var_type), "i64", "global_x type is i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  env0 = scope_enter(env0)
  env0 = scope_define_var(env0, "local_y", t_str, 0)
  v_loc = scope_lookup_var(env0, "local_y")
  @if assert_eq_str(v_loc.name, "local_y", "Found local_y in child scope") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(v_loc.var_type), "string", "local_y type is string") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Shadowing
  env0 = scope_define_var(env0, "global_x", t_bool, 0)
  v_shad = scope_lookup_var(env0, "global_x")
  @if assert_eq_str(type_to_string(v_shad.var_type), "bool", "Shadowed global_x type is bool in child scope") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  env0 = scope_exit(env0)
  v_rest = scope_lookup_var(env0, "global_x")
  @if assert_eq_str(type_to_string(v_rest.var_type), "i64", "Restored global_x type is i64 after exiting scope") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  v_dead = scope_lookup_var(env0, "local_y")
  @if assert_eq_str(v_dead.name, "", "local_y is no longer visible in parent scope") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 4. End-to-End Program Typechecking: Valid Program
  src_valid = "@struct Vector3\n  x: i64\n  y: i64\n  z: i64\n@end\n\n@fn dot_product(v1: Vector3, v2: Vector3) -> i64\n  @return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z\n@end\n\n@fn main() -> i64\n  a = { x: 1, y: 2, z: 3 }\n  b = { x: 4, y: 5, z: 6 }\n  result = dot_product(a, b)\n  @return result\n@end\n"
  env_valid = typecheck_source(src_valid)

  @if assert_eq_i64(env_valid.errors.len(), 0, "Valid program produces 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_has_struct(env_valid, "Vector3"), 1, "Struct Vector3 registered") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  st_v3 = tc_get_struct(env_valid, "Vector3")
  @if assert_eq_i64(st_v3.fields.len(), 3, "Vector3 has 3 fields") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_v3.fields[0].offset_bytes, 0, "Vector3.x offset is 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_v3.fields[1].offset_bytes, 8, "Vector3.y offset is 8") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_v3.fields[2].offset_bytes, 16, "Vector3.z offset is 16") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_v3.total_size, 24, "Vector3 total size is 24 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_has_fn(env_valid, "dot_product"), 1, "Function dot_product registered") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 5. End-to-End Program Typechecking: Duplicate Struct Error Detection
  src_dup = "@struct Item\n  id: i64\n@end\n\n@struct Item\n  name: string\n@end\n"
  env_dup = typecheck_source(src_dup)
  @if assert_eq_i64(env_dup.errors.len(), 1, "Duplicate struct triggers 1 error") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 6. Elif Branch Semantic Validation & Return Path
  src_elif = "
  @fn sign_num(x: i64) -> i64
    @if x > 0
      @return 1
    @elif x < 0
      @return -1
    @else
      @return 0
    @end
  @end
  "
  env_elif = typecheck_source(src_elif)
  @if assert_eq_i64(env_elif.errors.len(), 0, "@elif valid function produces 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(env_elif.warnings.len(), 0, "@elif exhaustive return produces 0 warnings") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 7. Struct Field Lookup with Typed Getters
  src_st_fields = "
  @struct Person
    id: i64
    name: string
    active: bool
  @end
  "
  env_st = typecheck_source(src_st_fields)
  st_person = tc_get_struct(env_st, "Person")
  f_name_sym = tc_struct_get_field(st_person, "name")
  @if assert_eq_str(tc_field_get_name(f_name_sym), "name", "Found field 'name' in Person") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_field_get_offset(f_name_sym), 8, "Person.name offset is 8 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(tc_field_get_type(f_name_sym)), "string", "Person.name type is string") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  f_act_sym = tc_struct_get_field(st_person, "active")
  @if assert_eq_str(tc_field_get_name(f_act_sym), "active", "Found field 'active' in Person") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_field_get_offset(f_act_sym), 16, "Person.active offset is 16 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 8. Enum Variant Constants Resolution
  src_enum_test = "
  @enum Priority
    LOW = 1
    MEDIUM = 5
    HIGH = 10
  @end
  "
  env_enum = typecheck_source(src_enum_test)
  @if assert_eq_i64(tc_lookup_constant(env_enum, "Priority_LOW"), 1, "Priority_LOW is 1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enum, "Priority_MEDIUM"), 5, "Priority_MEDIUM is 5") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enum, "Priority_HIGH"), 10, "Priority_HIGH is 10") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 9. Forward-Referenced Struct Field Resolution
  src_fwd = "
  @struct Tree
    root: Node
  @end

  @struct Node
    val: i64
  @end
  "
  env_fwd = typecheck_source(src_fwd)
  @if assert_eq_i64(env_fwd.errors.len(), 0, "Forward struct reference produces 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  st_tree = tc_get_struct(env_fwd, "Tree")
  f_root = tc_struct_get_field(st_tree, "root")
  @if assert_eq_str(type_to_string(tc_field_get_type(f_root)), "Node", "Tree.root resolved to Node struct") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! 10. Match Expression Typechecking
  src_match = "
  @fn test_match(code: i64) -> string
    msg = @match code
      case 0 => \"zero\"
      case 1 => \"one\"
      case _ => \"other\"
    @end
    @return msg
  @end
  "
  env_match = typecheck_source(src_match)
  @if assert_eq_i64(env_match.errors.len(), 0, "Match expression program typechecks with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  println("=================================================================")
  println("📊 TEST SUMMARY: " + int_to_str(total_pass) + " passed, " + int_to_str(total_fail) + " failed")
  println("=================================================================")

  @if total_fail == 0
    println("✓ Pure Maya Multi-Pass Typechecker verification tests passed 100%!")
    return 0
  @else
    return 1
  @end
@end
