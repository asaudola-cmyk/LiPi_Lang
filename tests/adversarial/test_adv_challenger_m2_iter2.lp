@! ============================================================================
@! ADVERSARIAL CHALLENGER SUITE (MILESTONE M2 ITERATION 2)
@! Pure Maya Frontend Typechecker, AST Lowering & Semantic Resilience Stress
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
  println("⚔️  ADVERSARIAL CHALLENGER VERIFICATION (M2 ITERATION 2) ⚔️")
  println("=================================================================")

  total_pass = 0
  total_fail = 0

  @! ---------------------------------------------------------------------------
  @! [1] @elif DEEP CASCADE, CONDITION EVALUATION & RETURN REACHABILITY
  @! ---------------------------------------------------------------------------
  println("\n--- [1] @elif Branch Evaluation & Return Flow Stress ---")

  src_elif_deep = "
  @fn classify_number(n: i64) -> string
    @if n == 0
      res = \"zero\"
      @return res
    @elif n == 1
      res = \"one\"
      @return res
    @elif n == 2
      res = \"two\"
      @return res
    @elif n > 2 && n <= 10
      res = \"small\"
      @return res
    @elif n > 10 && n <= 100
      res = \"medium\"
      @return res
    @elif n > 100 && n <= 1000
      res = \"large\"
      @return res
    @elif n < 0 && n >= -100
      res = \"negative small\"
      @return res
    @elif n < -100
      res = \"negative large\"
      @return res
    @else
      res = \"huge\"
      @return res
    @end
  @end
  "

  env_elif = typecheck_source(src_elif_deep)
  @if assert_eq_i64(env_elif.errors.len(), 0, "8-branch @elif cascade typechecks with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(env_elif.warnings.len(), 0, "Exhaustive @elif ladder produces 0 return warnings") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Incomplete @elif: one @elif branch missing return statement
  src_elif_incomplete = "
  @fn test_incomplete_elif(x: i64) -> i64
    @if x == 1
      @return 10
    @elif x == 2
      y = 20
      @! Missing return here!
    @else
      @return 30
    @end
  @end
  "
  env_elif_incomp = typecheck_source(src_elif_incomplete)
  @if assert_eq_i64(env_elif_incomp.warnings.len(), 1, "Incomplete @elif branch triggers 1 return warning") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Direct ASTElifBranch API schema validation
  cond_node = ast_literal_bool(1)
  body_stmts = [ast_return(ast_literal_int(42))]
  branch_obj = ast_elif_branch(cond_node, body_stmts)

  @if assert_eq_str(ast_get_kind(ast_elif_get_condition(branch_obj)), "LiteralBool", "ast_elif_get_condition returns LiteralBool") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(ast_get_kind(ast_elif_get_cond(branch_obj)), "LiteralBool", "ast_elif_get_cond alias returns LiteralBool") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(ast_elif_get_body(branch_obj).len(), 1, "ast_elif_get_body returns array of 1 statement") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! [2] MULTI-FIELD STRUCT FIELD LOOKUP & ISOLATION (tc_struct_get_field)
  @! ---------------------------------------------------------------------------
  println("\n--- [2] tc_struct_get_field Multi-Field & Cross-Struct Lookup ---")

  src_multi_fields = "
  @struct Employee
    id: i64
    age: i64
    salary: f64
    name: string
    is_active: bool
    manager_ptr: ptr
    dept_id: i64
    bonus: f64
    title: string
    level: i64
  @end

  @struct Contractor
    id: i64
    hourly_rate: f64
    name: string
    active: bool
  @end
  "

  env_structs = typecheck_source(src_multi_fields)
  @if assert_eq_i64(env_structs.errors.len(), 0, "Multi-struct definition typechecks with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_emp = tc_get_struct(env_structs, "Employee")
  @if assert_eq_i64(st_emp.total_size, 80, "Employee (10 fields) total size is 80 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Verify all 10 fields individually via tc_struct_get_field
  f0 = tc_struct_get_field(st_emp, "id")
  @if assert_eq_i64(tc_field_get_index(f0), 0, "Employee.id index is 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_field_get_offset(f0), 0, "Employee.id offset is 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(tc_field_get_type(f0)), "i64", "Employee.id type is i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  f2 = tc_struct_get_field(st_emp, "salary")
  @if assert_eq_i64(tc_field_get_index(f2), 2, "Employee.salary index is 2") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_field_get_offset(f2), 16, "Employee.salary offset is 16") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(tc_field_get_type(f2)), "f64", "Employee.salary type is f64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  f3 = tc_struct_get_field(st_emp, "name")
  @if assert_eq_i64(tc_field_get_index(f3), 3, "Employee.name index is 3") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_field_get_offset(f3), 24, "Employee.name offset is 24") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(tc_field_get_type(f3)), "string", "Employee.name type is string") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  f4 = tc_struct_get_field(st_emp, "is_active")
  @if assert_eq_i64(tc_field_get_index(f4), 4, "Employee.is_active index is 4") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_field_get_offset(f4), 32, "Employee.is_active offset is 32") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(tc_field_get_type(f4)), "bool", "Employee.is_active type is bool") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  f9 = tc_struct_get_field(st_emp, "level")
  @if assert_eq_i64(tc_field_get_index(f9), 9, "Employee.level index is 9") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_field_get_offset(f9), 72, "Employee.level offset is 72") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Non-existent field returns index == -1
  f_none = tc_struct_get_field(st_emp, "non_existent_field")
  @if assert_eq_i64(tc_field_get_index(f_none), -1, "Unknown field lookup returns index -1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Cross-struct isolation: Contractor also has 'name' at index 2 (offset 16)
  st_con = tc_get_struct(env_structs, "Contractor")
  f_con_name = tc_struct_get_field(st_con, "name")
  @if assert_eq_i64(tc_field_get_index(f_con_name), 2, "Contractor.name index is 2 (distinct from Employee)") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_field_get_offset(f_con_name), 16, "Contractor.name offset is 16") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! MemberAccess type inference in expressions
  env_structs = scope_define_var(env_structs, "e", type_make_struct("Employee", tc_struct_get_fields(st_emp)), 0)
  acc_e_name = ast_member_access(ast_variable("e"), "name")
  res_acc_name = check_expression(acc_e_name, env_structs)
  @if assert_eq_str(type_to_string(res_acc_name.type), "string", "check_expression(e.name) infers string") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  acc_e_sal = ast_member_access(ast_variable("e"), "salary")
  res_acc_sal = check_expression(acc_e_sal, env_structs)
  @if assert_eq_str(type_to_string(res_acc_sal.type), "f64", "check_expression(e.salary) infers f64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! [3] ENUM CONSTANTS & DISCRIMINANT EVALUATION IN env.constants
  @! ---------------------------------------------------------------------------
  println("\n--- [3] Enum Constants & Discriminant Values Stress ---")

  src_enums = "
  @enum HttpStatus
    OK = 200
    Created = 201
    Accepted = 202
    BadRequest = 400
    Unauthorized = 401
    Forbidden = 403
    NotFound = 404
    InternalServerError = 500
  @end

  @enum Color
    Red = 0
    Green = 1
    Blue = 2
  @end

  @fn get_status_message(code: i64) -> string
    @if code == HttpStatus_OK
      @return \"Success\"
    @elif code == HttpStatus_NotFound
      @return \"Not Found\"
    @else
      @return \"Other\"
    @end
  @end
  "

  env_enums = typecheck_source(src_enums)
  @if assert_eq_i64(env_enums.errors.len(), 0, "Multiple enum definitions typecheck with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Check all HttpStatus enum constants registered with exact discriminants
  @if assert_eq_i64(tc_lookup_constant(env_enums, "HttpStatus_OK"), 200, "HttpStatus_OK is 200") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "HttpStatus_Created"), 201, "HttpStatus_Created is 201") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "HttpStatus_BadRequest"), 400, "HttpStatus_BadRequest is 400") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "HttpStatus_NotFound"), 404, "HttpStatus_NotFound is 404") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "HttpStatus_InternalServerError"), 500, "HttpStatus_InternalServerError is 500") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Check Color constants
  @if assert_eq_i64(tc_lookup_constant(env_enums, "Color_Red"), 0, "Color_Red is 0") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "Color_Green"), 1, "Color_Green is 1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(tc_lookup_constant(env_enums, "Color_Blue"), 2, "Color_Blue is 2") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Unknown constant lookup returns -1
  @if assert_eq_i64(tc_lookup_constant(env_enums, "HttpStatus_NonExistent"), -1, "Unknown constant returns -1") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Constant expression type inference
  c_var_res = check_expression(ast_variable("HttpStatus_OK"), env_enums)
  @if assert_eq_str(type_to_string(c_var_res.type), "i64", "HttpStatus_OK resolves to i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! [4] PASS 2 FORWARD-REFERENCED & CYCLIC STRUCT FIELD TYPES
  @! ---------------------------------------------------------------------------
  println("\n--- [4] Pass 2 Forward-Referenced Struct Types Stress ---")

  src_forward_structs = "
  @struct Tree
    root: TreeNode
    count: i64
  @end

  @struct TreeNode
    left: TreeNode
    right: TreeNode
    value: i64
    owner_forest: Forest
  @end

  @struct Forest
    trees: Tree
    forest_name: string
  @end
  "

  env_fwd = typecheck_source(src_forward_structs)
  @if assert_eq_i64(env_fwd.errors.len(), 0, "Mutual/forward referencing structs typecheck with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_tree = tc_get_struct(env_fwd, "Tree")
  f_root = tc_struct_get_field(st_tree, "root")
  @if assert_eq_str(tc_field_get_type_name(f_root), "TreeNode", "Tree.root type_name is TreeNode") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(tc_field_get_type(f_root)), "TreeNode", "Tree.root resolved to TreeNode struct") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_node = tc_get_struct(env_fwd, "TreeNode")
  f_forest = tc_struct_get_field(st_node, "owner_forest")
  @if assert_eq_str(type_to_string(tc_field_get_type(f_forest)), "Forest", "TreeNode.owner_forest resolved to Forest struct") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! [5] MATCH ARM STATEMENT CHECKING & SCOPE ISOLATION
  @! ---------------------------------------------------------------------------
  println("\n--- [5] Match Arm Statement Typechecking & Scope Isolation ---")

  src_match_expr = "
  @fn evaluate_token_expr(token_kind: i64, val: i64) -> i64
    res = @match token_kind
      1 => val * 10
      2 => val + 100
      3 => val * val
      _ => 0
    @end
    @return res
  @end
  "

  env_match = typecheck_source(src_match_expr)
  @if assert_eq_i64(env_match.errors.len(), 0, "Multi-arm match expression typechecks with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(env_match.warnings.len(), 0, "Exhaustive match expression produces 0 return warnings") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Direct MatchExpr node construction and type inference
  arm1 = ast_match_arm(ast_literal_int(1), 0, [ast_return(ast_literal_str("one"))])
  arm2 = ast_match_arm(ast_literal_int(2), 0, [ast_return(ast_literal_str("two"))])
  match_node = ast_match_expr(ast_variable("x"), [arm1, arm2])

  env_match_expr = typeenv_new()
  env_match_expr = scope_define_var(env_match_expr, "x", type_make_i64(), 0)
  res_match_expr = check_expression(match_node, env_match_expr)
  @if assert_eq_str(type_to_string(res_match_expr.type), "string", "MatchExpr returns string from Return in arm") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! [6] STRUCT ALIGNMENT RULES & POWER-OF-TWO SIZES
  @! ---------------------------------------------------------------------------
  println("\n--- [6] Struct Alignment & Size Rules ---")

  src_align = "
  @struct Empty
  @end

  @struct Size1
    a: i64
  @end

  @struct Size3
    a: i64
    b: i64
    c: i64
  @end

  @struct Size7
    a: i64
    b: i64
    c: i64
    d: i64
    e: i64
    f: i64
    g: i64
  @end
  "

  env_align = typecheck_source(src_align)
  @if assert_eq_i64(env_align.errors.len(), 0, "Alignment structs typecheck with 0 errors") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_empty = tc_get_struct(env_align, "Empty")
  @if assert_eq_i64(st_empty.total_size, 8, "Empty struct minimal size is 8 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_i64(st_empty.alignment, 8, "Empty struct alignment is 8") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_s1 = tc_get_struct(env_align, "Size1")
  @if assert_eq_i64(st_s1.total_size, 8, "Size1 struct total size is 8 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_s3 = tc_get_struct(env_align, "Size3")
  @if assert_eq_i64(st_s3.total_size, 24, "Size3 struct total size is 24 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  st_s7 = tc_get_struct(env_align, "Size7")
  @if assert_eq_i64(st_s7.total_size, 56, "Size7 struct total size is 56 bytes") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! [7] DEEP 5-LEVEL NESTED SCOPES & VARIABLE SHADOWING UNWINDING
  @! ---------------------------------------------------------------------------
  println("\n--- [7] 5-Level Nested Scope Variable Shadowing & Unwinding ---")

  env_scope = typeenv_new()
  t_i64 = type_make_i64()
  t_f64 = type_make_f64()
  t_bool = type_make_bool()
  t_str = type_make_string()
  t_ptr = type_make_ptr()

  @! Level 0 (Global)
  env_scope = scope_define_var(env_scope, "v", t_i64, 0)
  env_scope = scope_define_var(env_scope, "g0", t_i64, 0)

  @! Level 1
  env_scope = scope_enter(env_scope)
  env_scope = scope_define_var(env_scope, "v", t_f64, 0)
  env_scope = scope_define_var(env_scope, "g1", t_f64, 0)

  @! Level 2
  env_scope = scope_enter(env_scope)
  env_scope = scope_define_var(env_scope, "v", t_bool, 0)
  env_scope = scope_define_var(env_scope, "g2", t_bool, 0)

  @! Level 3
  env_scope = scope_enter(env_scope)
  env_scope = scope_define_var(env_scope, "v", t_str, 0)
  env_scope = scope_define_var(env_scope, "g3", t_str, 0)

  @! Level 4
  env_scope = scope_enter(env_scope)
  env_scope = scope_define_var(env_scope, "v", t_ptr, 0)
  env_scope = scope_define_var(env_scope, "g4", t_ptr, 0)

  @! At Level 4: v should be ptr, g0..g4 all accessible
  @if assert_eq_str(type_to_string(scope_lookup_var(env_scope, "v").var_type), "ptr", "Level 4: shadowed v is ptr") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(scope_lookup_var(env_scope, "g0").var_type), "i64", "Level 4: g0 is i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(type_to_string(scope_lookup_var(env_scope, "g4").var_type), "ptr", "Level 4: g4 is ptr") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Unwind to Level 3
  env_scope = scope_exit(env_scope)
  @if assert_eq_str(type_to_string(scope_lookup_var(env_scope, "v").var_type), "string", "Level 3: restored v is string") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(scope_lookup_var(env_scope, "g4").name, "", "Level 3: g4 is no longer visible") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Unwind to Level 2
  env_scope = scope_exit(env_scope)
  @if assert_eq_str(type_to_string(scope_lookup_var(env_scope, "v").var_type), "bool", "Level 2: restored v is bool") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Unwind to Level 1
  env_scope = scope_exit(env_scope)
  @if assert_eq_str(type_to_string(scope_lookup_var(env_scope, "v").var_type), "f64", "Level 1: restored v is f64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Unwind to Level 0
  env_scope = scope_exit(env_scope)
  @if assert_eq_str(type_to_string(scope_lookup_var(env_scope, "v").var_type), "i64", "Level 0: restored v is i64") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end
  @if assert_eq_str(scope_lookup_var(env_scope, "g1").name, "", "Level 0: g1 is no longer visible") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! ---------------------------------------------------------------------------
  @! [8] CYCLIC IMPORT GRAPH DETECTION (Tri-Color DFS)
  @! ---------------------------------------------------------------------------
  println("\n--- [8] Cyclic Import Graph Traversal Stress ---")

  visited_chain = ["alpha", "beta", "gamma", "delta"]

  @! Self cycle
  @if assert_eq_i64(import_graph_has_cycle([], "alpha", visited_chain), 1, "Cycle on alpha detected") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Mid-chain cycle (beta)
  @if assert_eq_i64(import_graph_has_cycle([], "beta", visited_chain), 1, "Cycle on beta detected") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Tail cycle (delta)
  @if assert_eq_i64(import_graph_has_cycle([], "delta", visited_chain), 1, "Cycle on delta detected") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  @! Fresh module (epsilon) -> no cycle
  @if assert_eq_i64(import_graph_has_cycle([], "epsilon", visited_chain), 0, "No cycle on epsilon") == 1 total_pass = total_pass + 1 @else total_fail = total_fail + 1 @end

  println("\n=================================================================")
  println("📊 ADVERSARIAL CHALLENGER ITER 2 SUMMARY: " + int_to_str(total_pass) + " passed, " + int_to_str(total_fail) + " failed")
  println("=================================================================")

  @if total_fail == 0
    println("✓ 100% of Milestone M2 Iteration 2 Adversarial Challenges PASSED!")
    return 0
  @else
    println("✗ Challenges Failed!")
    return 1
  @end
@end
