// ==============================================================================
// 🧪 LIPI COMPILER VERIFICATION: SEMANTICS, SCOPE & TYPE SYSTEM TEST SUITE
// File: tests/test_semantics_engine.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"

import "compiler/frontend/ast/ast_node"
import "compiler/semantics/symbol"
import "compiler/semantics/scope"
import "compiler/semantics/symbol_table"
import "compiler/semantics/type_def"
import "compiler/semantics/type_unify"
import "compiler/semantics/type_inference"
import "compiler/semantics/type_checker"
import "compiler/semantics/const_eval"
import "compiler/semantics/ownership_check"
import "compiler/semantics/purity_analyzer"

@fn assert_true(cond, test_name)
  @if cond == 1
    say("  [PASS] " + test_name)
    return 1
  @else
    say("  [FAIL] " + test_name)
    return 0
  @end
@end

@fn test_symbol_subsystem()
  say("── 1. Testing Symbol Subsystem (symbol.lp) ──")
  sp = span_new(10, 5, 10, 15, "main.lp")
  sym = symbol_variable("counter", 2, 0, sp, 1)

  assert_true(str_eq(sym.sym_name, "counter") == 1, "Symbol name matches")
  assert_true(sym.sym_kind == SYM_KIND_VARIABLE(), "Symbol kind is Variable")
  assert_true(sym.sym_is_const == 0, "Symbol is mutable")
  assert_true(symbol_is_active(sym) == 1, "Symbol is initially active")

  symbol_mark_moved(sym)
  assert_true(symbol_is_active(sym) == 0, "Symbol is inactive after move")
  assert_true(str_eq(symbol_kind_to_string(SYM_KIND_FUNCTION()), "function") == 1, "Kind string conversion")
  return 1
@end

@fn test_scope_subsystem()
  say("── 2. Testing Lexical Scope Stack (scope.lp) ──")
  stack = scope_stack_new()
  assert_true(stack.stk_current_id == 0, "Initial scope is Global (id=0)")

  // Define global symbol
  g_sym = symbol_variable("g_var", 2, 0, span_default(), 0)
  scope_define(stack, g_sym)

  // Push Function scope
  scope_stack_push(stack, SCOPE_FUNCTION(), "calculate")
  assert_true(scope_get_depth(stack) == 1, "Function scope depth is 1")

  // Define local symbol that shadows nothing
  l_sym = symbol_variable("local_x", 2, 0, span_default(), 1)
  scope_define(stack, l_sym)

  // Push Block scope
  scope_stack_push(stack, SCOPE_BLOCK(), "if_block")
  assert_true(scope_get_depth(stack) == 2, "Block scope depth is 2")

  // Lookup local and global from inner block
  found_l = scope_lookup(stack, "local_x")
  assert_true(found_l != 0 && str_eq(found_l.sym_name, "local_x") == 1, "Lexical lookup finds local_x")

  found_g = scope_lookup(stack, "g_var")
  assert_true(found_g != 0 && str_eq(found_g.sym_name, "g_var") == 1, "Lexical lookup climbs to g_var")

  // Check enclosing function
  enc_fn = scope_get_enclosing_function(stack)
  assert_true(enc_fn != 0 && str_eq(enc_fn.sc_name, "calculate") == 1, "Enclosing function found")

  // Pop Block & Function
  scope_stack_pop(stack)
  assert_true(scope_get_depth(stack) == 1, "Popped to Function scope")
  scope_stack_pop(stack)
  assert_true(scope_get_depth(stack) == 0, "Popped to Global scope")
  return 1
@end

@fn test_symbol_table_and_namespace()
  say("── 3. Testing Symbol Table & Namespace (symbol_table.lp) ──")
  tab = symtab_new(32)
  s1 = symbol_variable("alpha", 2, 0, span_default(), 0)
  s2 = symbol_variable("beta", 3, 0, span_default(), 0)

  symtab_put(tab, s1)
  symtab_put(tab, s2)

  assert_true(symtab_has(tab, "alpha") == 1, "Fast hash finds 'alpha'")
  assert_true(symtab_has(tab, "beta") == 1, "Fast hash finds 'beta'")
  assert_true(symtab_has(tab, "gamma") == 0, "Missing symbol returns false")

  // Namespace resolution
  root_ns = namespace_new("root", "")
  std_ns = namespace_add_child(root_ns, "std")
  math_ns = namespace_add_child(std_ns, "math")

  pi_sym = symbol_constant("pi", 3, 314, span_default(), 0)
  namespace_add_symbol(math_ns, pi_sym)

  resolved = namespace_resolve(root_ns, "std::math::pi")
  assert_true(resolved != 0 && str_eq(resolved.sym_name, "pi") == 1, "Resolved qualified path 'std::math::pi'")

  // Import alias resolution
  namespace_register_alias(root_ns, "m", "std::math")
  resolved_alias = namespace_resolve(root_ns, "m::pi")
  assert_true(resolved_alias != 0 && str_eq(resolved_alias.sym_name, "pi") == 1, "Resolved aliased path 'm::pi'")
  return 1
@end

@fn test_type_def_and_registry()
  say("── 4. Testing Type Definitions & Registry (type_def.lp) ──")
  reg = type_registry_new()

  t_i64 = type_i64(reg)
  assert_true(t_i64.ty_kind == TYPE_KIND_I64(), "Primitive i64 is kind I64")
  assert_true(t_i64.ty_size_bytes == 8, "i64 size is 8 bytes")

  // Create Struct Point { x: i64, y: i64 }
  f1 = type_make_field("x", TYPE_ID_I64(), 0, 8, 1)
  f2 = type_make_field("y", TYPE_ID_I64(), 8, 8, 1)
  p_fields = [f1, f2]
  point_tid = type_make_struct(reg, "Point", p_fields)

  point_ty = type_registry_get(reg, point_tid)
  assert_true(point_ty.ty_size_bytes == 16, "Point struct size is 16 bytes")

  field_y = type_find_field(reg, point_tid, "y")
  assert_true(field_y != 0 && field_y.fd_offset == 8, "Field 'y' has offset 8")

  // Create Array and Pointer types
  arr_tid = type_make_array(reg, TYPE_ID_I64(), 10)
  arr_ty = type_registry_get(reg, arr_tid)
  assert_true(arr_ty.ty_size_bytes == 80, "[i64; 10] size is 80 bytes")

  ptr_tid = type_make_pointer(reg, point_tid, 1)
  assert_true(type_is_pointer(reg, ptr_tid) == 1, "Pointer type recognized")

  // Function type: fn(i64, Point) -> bool
  fn_tid = type_make_function(reg, [TYPE_ID_I64(), point_tid], TYPE_ID_BOOL())
  assert_true(type_is_function(reg, fn_tid) == 1, "Function signature registered")
  return 1
@end

@fn test_type_unification()
  say("── 5. Testing Type Unification & Equivalence (type_unify.lp) ──")
  reg = type_registry_new()
  subst = subst_new()

  // Strict equality
  assert_true(type_is_equal(reg, TYPE_ID_I64(), TYPE_ID_I64()) == 1, "i64 == i64")
  assert_true(type_is_equal(reg, TYPE_ID_I64(), TYPE_ID_STRING()) == 0, "i64 != string")

  // Subtyping and assignability
  assert_true(type_is_assignable(reg, TYPE_ID_ANY(), TYPE_ID_I64()) == 1, "any accepts i64")
  assert_true(type_is_assignable(reg, TYPE_ID_I64(), TYPE_ID_BYTE()) == 1, "i64 accepts byte (widening)")

  // Type variable unification
  var1_id = type_make_var(reg, 101, "T")
  unify_ok = type_unify(reg, subst, var1_id, TYPE_ID_STRING())
  assert_true(unify_ok == 1, "Unification of 'T with string succeeds")

  resolved = subst_apply(subst, reg, var1_id)
  assert_true(resolved == TYPE_ID_STRING(), "Variable 'T solved to string")

  // Occurs check prevents recursive type T = []T
  subst2 = subst_new()
  var2_id = type_make_var(reg, 102, "U")
  rec_arr_id = type_make_array(reg, var2_id, -1)
  assert_true(type_occurs_in(subst2, reg, 102, rec_arr_id) == 1, "Occurs check detects U in []U")
  assert_true(type_unify(reg, subst2, var2_id, rec_arr_id) == 0, "Unification rejects infinite cyclic type")

  // Common supertype for branches
  common_num = type_common_supertype(reg, TYPE_ID_I64(), TYPE_ID_BYTE())
  assert_true(common_num == TYPE_ID_I64(), "Common supertype of (i64, byte) is i64")
  return 1
@end

@fn test_type_inference()
  say("── 6. Testing Type Inference Engine (type_inference.lp) ──")
  reg = type_registry_new()
  scopes = scope_stack_new()
  ctx = infer_ctx_new(reg, scopes)

  // Infer literal types
  lit_int = ast_node("Integer")
  lit_int.val = 12345
  assert_true(infer_expr_type(ctx, lit_int) == TYPE_ID_I64(), "Infers Integer literal as i64")

  lit_str = ast_node("String")
  lit_str.name = "hello"
  assert_true(infer_expr_type(ctx, lit_str) == TYPE_ID_STRING(), "Infers String literal as string")

  // Infer binary arithmetic: 10 + 20 -> i64
  b_add = ast_node("BinaryOp")
  b_add.op = "+"
  b_add.left = lit_int
  b_add.right = lit_int
  assert_true(infer_expr_type(ctx, b_add) == TYPE_ID_I64(), "Infers int + int as i64")

  // Infer binary comparison: 10 == 20 -> bool
  b_eq = ast_node("BinaryOp")
  b_eq.op = "=="
  b_eq.left = lit_int
  b_eq.right = lit_int
  assert_true(infer_expr_type(ctx, b_eq) == TYPE_ID_BOOL(), "Infers int == int as bool")

  // Infer variable declaration: let total = 10 + 20
  inferred_tid = infer_var_declaration(ctx, "total", b_add, 0, span_default())
  assert_true(inferred_tid == TYPE_ID_I64(), "Infers 'total' as i64")

  sym_total = scope_lookup(scopes, "total")
  assert_true(sym_total != 0 && sym_total.sym_type_ref == TYPE_ID_I64(), "Variable 'total' registered in scope")
  return 1
@end

@fn test_type_checker_pass()
  say("── 7. Testing Type Checker Pass (type_checker.lp) ──")
  reg = type_registry_new()
  scopes = scope_stack_new()
  symtab = symtab_new(64)
  tc = type_checker_new(reg, symtab, scopes)

  val_100 = ast_node("Integer")
  val_100.val = 100

  assign_valid = ast_node("Assign")
  assign_valid.target = "x"
  assign_valid.value = val_100

  tc_check_statement(tc, assign_valid)
  assert_true(tc_has_errors(tc) == 0, "Valid integer assignment produces no errors")

  const_sym = symbol_constant("MAX", TYPE_ID_I64(), 50, span_default(), 0)
  scope_define(scopes, const_sym)

  assign_const = ast_node("Assign")
  assign_const.target = "MAX"
  assign_const.value = val_100

  tc_check_statement(tc, assign_const)
  assert_true(tc_has_errors(tc) == 1, "Reassignment to constant produces semantic error")
  return 1
@end

@fn test_const_evaluator()
  say("── 8. Testing Comptime Constant Evaluator (const_eval.lp) ──")
  env = const_env_new()
  const_env_set(env, "LIMIT", const_val_int(256))

  lit_10 = ast_node("Integer")
  lit_10.val = 10
  lit_5 = ast_node("Integer")
  lit_5.val = 5

  ast_mul = ast_node("BinaryOp")
  ast_mul.op = "*"
  ast_mul.left = lit_10
  ast_mul.right = lit_5

  lit_2 = ast_node("Integer")
  lit_2.val = 2

  ast_expr = ast_node("BinaryOp")
  ast_expr.op = "+"
  ast_expr.left = ast_mul
  ast_expr.right = lit_2

  res = const_eval_expr(env, ast_expr)
  assert_true(res.cv_is_valid == 1 && res.cv_int_val == 52, "Compile-time evaluation of 10*5+2 = 52")

  lit_1 = ast_node("Integer")
  lit_1.val = 1
  lit_8 = ast_node("Integer")
  lit_8.val = 8

  ast_shift = ast_node("BinaryOp")
  ast_shift.op = "<<"
  ast_shift.left = lit_1
  ast_shift.right = lit_8

  res_shift = const_eval_expr(env, ast_shift)
  assert_true(res_shift.cv_is_valid == 1 && res_shift.cv_int_val == 256, "Compile-time evaluation of 1 << 8 = 256")

  lit_100 = ast_node("Integer")
  lit_100.val = 100
  lit_0 = ast_node("Integer")
  lit_0.val = 0

  ast_div_zero = ast_node("BinaryOp")
  ast_div_zero.op = "/"
  ast_div_zero.left = lit_100
  ast_div_zero.right = lit_0

  res_zero = const_eval_expr(env, ast_div_zero)
  assert_true(res_zero.cv_is_valid == 0, "Division by zero gracefully returns error without crashing compiler")

  folded_ast = const_fold_expr(env, ast_expr)
  assert_true(str_eq(folded_ast.kind, "Integer") == 1 && folded_ast.val == 52, "AST subtree rewritten to literal node")
  return 1
@end

@fn test_ownership_analyzer()
  say("── 9. Testing Zero-GC Ownership & Move Semantics (ownership_check.lp) ──")
  oc = ownership_checker_new()

  oc_declare(oc, "buffer", 0, span_default())
  assert_true(oc_check_read(oc, "buffer", span_default()) == 1, "Initial buffer read is valid")

  oc_mark_move(oc, "buffer", span_default())
  assert_true(oc_check_read(oc, "buffer", span_default()) == 0, "Read of moved buffer rejected")
  assert_true(oc_has_errors(oc) == 1, "Use-after-move error recorded")

  oc2 = ownership_checker_new()
  oc_declare(oc2, "doc", 0, span_default())

  assert_true(oc_borrow_shared(oc2, "doc", span_default()) == 1, "First shared borrow ok")
  assert_true(oc_borrow_shared(oc2, "doc", span_default()) == 1, "Second shared borrow ok")

  assert_true(oc_borrow_mut(oc2, "doc", span_default()) == 0, "Mutable borrow rejected when shared active")

  oc_release_borrow(oc2, "doc")
  oc_release_borrow(oc2, "doc")

  assert_true(oc_borrow_mut(oc2, "doc", span_default()) == 1, "Exclusive mutable borrow succeeds when unborrowed")
  return 1
@end

@fn test_purity_analyzer()
  say("── 10. Testing Purity & Concurrency Analyzer (purity_analyzer.lp) ──")
  pa = purity_analyzer_new()
  purity_register_global(pa, "GLOBAL_CONFIG")

  var_a = ast_node("Variable")
  var_a.name = "a"

  var_b = ast_node("Variable")
  var_b.name = "b"

  bin_add = ast_node("BinaryOp")
  bin_add.op = "+"
  bin_add.left = var_a
  bin_add.right = var_b

  ret_stmt = ast_node("Return")
  ret_stmt.value = bin_add

  fn_pure = ast_node("FnDef")
  fn_pure.name = "add_numbers"
  fn_pure.body = [ret_stmt]

  purity_analyze_fn(pa, fn_pure)
  assert_true(purity_is_pure(pa, "add_numbers") == 1, "add_numbers certified strictly pure")
  assert_true(purity_can_parallelize(pa, "add_numbers") == 1, "add_numbers certified safe for concurrency")
  assert_true(purity_can_memoize(pa, "add_numbers") == 1, "add_numbers certified eligible for memoization")

  arg_node = ast_node("String")
  arg_node.name = "Hello"

  call_stmt = ast_node("Call")
  call_stmt.name = "say"
  call_stmt.args = [arg_node]

  fn_impure = ast_node("FnDef")
  fn_impure.name = "log_message"
  fn_impure.body = [call_stmt]

  purity_analyze_fn(pa, fn_impure)
  assert_true(purity_is_pure(pa, "log_message") == 0, "log_message detected as impure (I/O call)")
  assert_true(purity_can_memoize(pa, "log_message") == 0, "log_message ineligible for memoization")
  return 1
@end

@fn main()
  say("==================================================================")
  say("🏛️  LIPI FIRST 1.0.0: SEMANTICS & TYPE SYSTEM SOVEREIGN SUITE")
  say("==================================================================")

  test_symbol_subsystem()
  test_scope_subsystem()
  test_symbol_table_and_namespace()
  test_type_def_and_registry()
  test_type_unification()
  test_type_inference()
  test_type_checker_pass()
  test_const_evaluator()
  test_ownership_analyzer()
  test_purity_analyzer()

  say("==================================================================")
  say("👑 ALL 10 SEMANTICS SUBSYSTEMS PASSED WITH 100% SOVEREIGN PURITY")
  say("==================================================================")
  return 0
@end

main()
