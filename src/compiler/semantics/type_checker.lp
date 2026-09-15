// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: TYPE CHECKER PASS (type_checker.lp)
// Module: src/compiler/semantics/type_checker.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// Semantic type checking is the fundamental gatekeeper of language soundness.
// It enforces compile-time typing rules across statements, expressions, and
// control flow:
// 1. Assignment Soundness: Verifies that RHS expression types are assignable to
//    declared LHS variable types, preventing reassignments to constants.
// 2. Control Flow Verification: Validates boolean guards for if/while statements
//    and ensures break/continue only appear inside valid loop scopes.
// 3. Signature Agreement: Ensures function return expressions match declared
//    signatures, and invocation argument lists match parameter count and types.
// 4. Collision-Free Architecture: Named constructors (`SemanticDiagnostic()`,
//    `TypeChecker()`) and prefixed fields (`sd_`, `tc_`) prevent struct collisions.
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/semantics/symbol"
import "compiler/semantics/scope"
import "compiler/semantics/symbol_table"
import "compiler/semantics/type_def"
import "compiler/semantics/type_unify"
import "compiler/semantics/type_inference"
import "compiler/frontend/ast/ast_node"

// ── 1. SEMANTIC DIAGNOSTIC CODES & STRUCTURE ─────────────────────────────────

@fn ERR_TYPE_MISMATCH()           return 1001 @end
@fn ERR_UNDEFINED_VARIABLE()      return 1002 @end
@fn ERR_CANNOT_ASSIGN_CONST()     return 1003 @end
@fn ERR_UNDEFINED_FUNCTION()      return 1004 @end
@fn ERR_INVALID_ARG_COUNT()       return 1005 @end
@fn ERR_INVALID_OPERAND_TYPE()    return 1006 @end
@fn ERR_RETURN_TYPE_MISMATCH()    return 1007 @end
@fn ERR_CONDITION_NOT_BOOL()      return 1008 @end
@fn ERR_INVALID_INDEX_TYPE()      return 1009 @end
@fn ERR_NOT_INDEXABLE()           return 1010 @end
@fn ERR_UNDEFINED_FIELD()          return 1011 @end
@fn ERR_NOT_CALLABLE()            return 1012 @end
@fn ERR_BREAK_OUTSIDE_LOOP()      return 1013 @end

@struct SemanticDiagnostic
  sd_code: i64
  sd_message: string
  sd_span: SourceSpan
  sd_is_warning: i64
@end

@fn diag_new(code, message, span, is_warning)
  // WHY: Allocates diagnostic event node with named constructor
  sp = span
  @if sp == 0 sp = span_default() @end

  d = SemanticDiagnostic()
  d.sd_code = code
  d.sd_message = message
  d.sd_span = sp
  d.sd_is_warning = is_warning
  return d
@end

// ── 2. TYPE CHECKER ENGINE STATE ─────────────────────────────────────────────

@struct TypeChecker
  tc_reg: TypeRegistry
  tc_scopes: ScopeStack
  tc_symtab: FastSymbolTable
  tc_infer_ctx: InferenceContext
  tc_current_fn_ret_type: i64
  tc_current_fn_name: string
  tc_errors: array
  tc_warnings: array
@end

@fn type_checker_new(reg, symtab, scopes)
  // WHY: Initializes type checking pipeline with named constructor
  ctx = infer_ctx_new(reg, scopes)
  tc = TypeChecker()
  tc.tc_reg = reg
  tc.tc_scopes = scopes
  tc.tc_symtab = symtab
  tc.tc_infer_ctx = ctx
  tc.tc_current_fn_ret_type = 0
  tc.tc_current_fn_name = ""
  tc.tc_errors = []
  tc.tc_warnings = []
  return tc
@end

@fn tc_error(tc, code, msg, span)
  d = diag_new(code, msg, span, 0)
  tc.tc_errors = tc.tc_errors.push(d)
  return 0
@end

@fn tc_warn(tc, code, msg, span)
  d = diag_new(code, msg, span, 1)
  tc.tc_warnings = tc.tc_warnings.push(d)
  return 0
@end

@fn tc_has_errors(tc)
  @if tc == 0 return 0 @end
  @if tc.tc_errors.len() > 0 return 1 @end
  return 0
@end

@fn tc_error_count(tc)
  @if tc == 0 return 0 @end
  return tc.tc_errors.len()
@end

// ── 3. EXPRESSION TYPE CHECKING & VALIDATION ─────────────────────────────────

@fn tc_check_expr(tc, expr)
  @if expr == 0 return TYPE_ID_VOID() @end

  k = expr.kind

  // 1. Literals
  @if str_eq(k, "Integer") == 1 || str_eq(k, "Float") == 1 || str_eq(k, "String") == 1 || str_eq(k, "Bool") == 1 || str_eq(k, "None") == 1 || str_eq(k, "INT") == 1 || str_eq(k, "HEX_INT") == 1 || str_eq(k, "STRING") == 1 || str_eq(k, "BOOL") == 1
    return infer_literal_type(tc.tc_infer_ctx, expr)
  @end

  // 2. Variable reference
  @if str_eq(k, "Variable") == 1 || str_eq(k, "IDENT") == 1 || str_eq(k, "Identifier") == 1
    v_name = expr.name
    @if v_name == "" && expr.target != ""
      v_name = expr.target
    @end
    @if str_eq(v_name, "true") == 1 || str_eq(v_name, "false") == 1 return TYPE_ID_BOOL() @end
    @if str_eq(v_name, "null") == 1 || str_eq(v_name, "nil") == 1   return TYPE_ID_VOID() @end

    sym = scope_lookup(tc.tc_scopes, v_name)
    @if sym == 0
      sym = symtab_get(tc.tc_symtab, v_name)
    @end

    @if sym == 0
      tc_error(tc, ERR_UNDEFINED_VARIABLE(), "Undefined variable '" + v_name + "'", span_default())
      return TYPE_ID_ANY()
    @end

    symbol_mark_used(sym)
    return sym.sym_type_ref
  @end

  // 3. Binary Operations
  @if str_eq(k, "BinaryOp") == 1
    op = expr.op
    t_left = tc_check_expr(tc, expr.left)
    t_right = tc_check_expr(tc, expr.right)

    // Arithmetic checks
    @if op == "+"
      @if t_left == TYPE_ID_STRING() || t_right == TYPE_ID_STRING()
        return TYPE_ID_STRING()
      @end
      @if type_is_numeric(tc.tc_reg, t_left) == 0 || type_is_numeric(tc.tc_reg, t_right) == 0
        tc_error(tc, ERR_INVALID_OPERAND_TYPE(), "Operator '+' requires numeric or string operands", span_default())
      @end
      return infer_binary_op_type(tc.tc_infer_ctx, op, t_left, t_right)
    @end

    @if op == "-" || op == "*" || op == "/" || op == "%"
      @if type_is_numeric(tc.tc_reg, t_left) == 0 || type_is_numeric(tc.tc_reg, t_right) == 0
        tc_error(tc, ERR_INVALID_OPERAND_TYPE(), "Arithmetic operator '" + op + "' requires numeric operands", span_default())
      @end
      return infer_binary_op_type(tc.tc_infer_ctx, op, t_left, t_right)
    @end

    // Relational comparisons (<, <=, >, >=)
    @if op == "<" || op == "<=" || op == ">" || op == ">="
      @if type_is_numeric(tc.tc_reg, t_left) == 0 || type_is_numeric(tc.tc_reg, t_right) == 0
        tc_error(tc, ERR_INVALID_OPERAND_TYPE(), "Relational operator '" + op + "' requires numeric operands", span_default())
      @end
      return TYPE_ID_BOOL()
    @end

    // Equality comparisons (==, !=)
    @if op == "==" || op == "!="
      @if type_is_assignable(tc.tc_reg, t_left, t_right) == 0 && type_is_assignable(tc.tc_reg, t_right, t_left) == 0
        tc_warn(tc, ERR_TYPE_MISMATCH(), "Comparing disparate types", span_default())
      @end
      return TYPE_ID_BOOL()
    @end

    // Logical operators
    @if op == "&&" || op == "||" || op == "and" || op == "or"
      return TYPE_ID_BOOL()
    @end

    // Bitwise operators
    @if op == "&" || op == "|" || op == "^" || op == "<<" || op == ">>"
      @if t_left != TYPE_ID_I64() || t_right != TYPE_ID_I64()
        tc_error(tc, ERR_INVALID_OPERAND_TYPE(), "Bitwise operator '" + op + "' requires i64 operands", span_default())
      @end
      return TYPE_ID_I64()
    @end

    return infer_binary_op_type(tc.tc_infer_ctx, op, t_left, t_right)
  @end

  // 4. Unary Operations
  @if str_eq(k, "UnaryOp") == 1
    t_inner = tc_check_expr(tc, expr.expr)
    @if expr.op == "!" || expr.op == "not" return TYPE_ID_BOOL() @end
    @if expr.op == "-"
      @if type_is_numeric(tc.tc_reg, t_inner) == 0
        tc_error(tc, ERR_INVALID_OPERAND_TYPE(), "Unary negation requires numeric operand", span_default())
      @end
      return t_inner
    @end
    return infer_unary_op_type(tc.tc_infer_ctx, expr.op, t_inner)
  @end

  // 5. Function Call
  @if str_eq(k, "Call") == 1
    fn_name = ""
    @if expr.name != ""
      fn_name = expr.name
    @elif expr.func != 0 && expr.func.name != ""
      fn_name = expr.func.name
    @end

    @if str_eq(fn_name, "say") == 1 || str_eq(fn_name, "println") == 1 || str_eq(fn_name, "print") == 1
      i = 0
      @while i < expr.args.len()
        tc_check_expr(tc, expr.args[i])
        i = i + 1
      @end
      return TYPE_ID_VOID()
    @end
    @if str_eq(fn_name, "len") == 1 || str_eq(fn_name, "str_len") == 1
      @if expr.args.len() > 0 tc_check_expr(tc, expr.args[0]) @end
      return TYPE_ID_I64()
    @end
    @if str_eq(fn_name, "to_str") == 1
      @if expr.args.len() > 0 tc_check_expr(tc, expr.args[0]) @end
      return TYPE_ID_STRING()
    @end

    f_sym = scope_lookup(tc.tc_scopes, fn_name)
    @if f_sym == 0
      f_sym = symtab_get(tc.tc_symtab, fn_name)
    @end

    @if f_sym == 0
      tc_error(tc, ERR_UNDEFINED_FUNCTION(), "Undefined function '" + fn_name + "'", span_default())
      return TYPE_ID_ANY()
    @end

    f_type = type_registry_get(tc.tc_reg, f_sym.sym_type_ref)
    @if f_type == 0 || f_type.ty_kind != TYPE_KIND_FUNCTION()
      return TYPE_ID_ANY()
    @end

    num_params = f_type.ty_param_types.len()
    num_args = expr.args.len()
    @if num_args != num_params
      tc_error(tc, ERR_INVALID_ARG_COUNT(), "Function '" + fn_name + "' expects " + to_str(num_params) + " arguments, got " + to_str(num_args), span_default())
    @end

    check_len = num_args
    @if num_params < check_len check_len = num_params @end
    j = 0
    @while j < check_len
      arg_t = tc_check_expr(tc, expr.args[j])
      param_t = f_type.ty_param_types[j]
      @if type_is_assignable(tc.tc_reg, param_t, arg_t) == 0
        tc_error(tc, ERR_TYPE_MISMATCH(), "Argument " + to_str(j + 1) + " of '" + fn_name + "' expects " + type_to_string(tc.tc_reg, param_t) + ", got " + type_to_string(tc.tc_reg, arg_t), span_default())
      @end
      j = j + 1
    @end

    return f_type.ty_ret_type_id
  @end

  // 6. Array Indexing
  @if str_eq(k, "Index") == 1
    arr_t = tc_check_expr(tc, expr.iterable)
    idx_t = tc_check_expr(tc, expr.index)
    @if idx_t != TYPE_ID_I64() && idx_t != TYPE_ID_ANY()
      tc_error(tc, ERR_INVALID_INDEX_TYPE(), "Array index must be i64, got " + type_to_string(tc.tc_reg, idx_t), span_default())
    @end

    arr_def = type_registry_get(tc.tc_reg, arr_t)
    @if arr_def != 0 && arr_def.ty_kind == TYPE_KIND_ARRAY()
      return arr_def.ty_elem_type_id
    @end
    @if arr_t == TYPE_ID_STRING()
      return TYPE_ID_BYTE()
    @end
    return TYPE_ID_ANY()
  @end

  // 7. Member / Field Access
  @if str_eq(k, "MemberAccess") == 1 || str_eq(k, "FieldAccess") == 1
    target_t = tc_check_expr(tc, expr.target)
    f_def = type_find_field(tc.tc_reg, target_t, expr.name)
    @if f_def == 0
      tc_error(tc, ERR_UNDEFINED_FIELD(), "Field '" + expr.name + "' not found in type " + type_to_string(tc.tc_reg, target_t), span_default())
      return TYPE_ID_ANY()
    @end
    return f_def.fd_type_id
  @end

  // 8. Array Literal
  @if str_eq(k, "ArrayLit") == 1 || str_eq(k, "Array") == 1
    i = 0
    n = expr.elements.len()
    @while i < n
      tc_check_expr(tc, expr.elements[i])
      i = i + 1
    @end
    return infer_expr_type(tc.tc_infer_ctx, expr)
  @end

  // 9. Struct Literal
  @if str_eq(k, "StructLit") == 1
    i = 0
    n = expr.elements.len()
    @while i < n
      f_ast = expr.elements[i]
      @if f_ast.value != 0
        tc_check_expr(tc, f_ast.value)
      @elif f_ast.expr != 0
        tc_check_expr(tc, f_ast.expr)
      @end
      i = i + 1
    @end
    return infer_expr_type(tc.tc_infer_ctx, expr)
  @end

  return infer_expr_type(tc.tc_infer_ctx, expr)
@end

// ── 4. STATEMENT SEMANTIC CHECKING ───────────────────────────────────────────

@fn tc_check_statement(tc, stmt)
  @if stmt == 0 return 0 @end

  k = stmt.kind

  // 1. Variable Assignment (target = value)
  @if str_eq(k, "Assign") == 1
    target_name = stmt.target
    val_expr = stmt.value
    @if val_expr == 0 val_expr = stmt.expr @end

    rhs_t = tc_check_expr(tc, val_expr)

    sym = scope_lookup(tc.tc_scopes, target_name)
    @if sym != 0
      @if sym.sym_is_const == 1
        tc_error(tc, ERR_CANNOT_ASSIGN_CONST(), "Cannot reassign to constant '" + target_name + "'", span_default())
      @end

      @if type_is_assignable(tc.tc_reg, sym.sym_type_ref, rhs_t) == 0
        tc_error(tc, ERR_TYPE_MISMATCH(), "Cannot assign " + type_to_string(tc.tc_reg, rhs_t) + " to variable '" + target_name + "' of type " + type_to_string(tc.tc_reg, sym.sym_type_ref), span_default())
      @end
    @else
      infer_var_declaration(tc.tc_infer_ctx, target_name, val_expr, 0, span_default())
    @end
    return 1
  @end

  // 2. Return Statement
  @if str_eq(k, "Return") == 1
    ret_expr = stmt.value
    @if ret_expr == 0 ret_expr = stmt.expr @end

    actual_ret_t = TYPE_ID_VOID()
    @if ret_expr != 0
      actual_ret_t = tc_check_expr(tc, ret_expr)
    @end

    expected_t = tc.tc_current_fn_ret_type
    @if expected_t > 0
      @if type_is_assignable(tc.tc_reg, expected_t, actual_ret_t) == 0
        tc_error(tc, ERR_RETURN_TYPE_MISMATCH(), "Function '" + tc.tc_current_fn_name + "' expected return type " + type_to_string(tc.tc_reg, expected_t) + ", but returned " + type_to_string(tc.tc_reg, actual_ret_t), span_default())
      @end
    @end
    return 1
  @end

  // 3. If Statement
  @if str_eq(k, "If") == 1
    cond_node = stmt.condition
    @if cond_node == 0 cond_node = stmt.cond @end
    @if cond_node != 0
      c_type = tc_check_expr(tc, cond_node)
      @if c_type != TYPE_ID_BOOL() && type_is_numeric(tc.tc_reg, c_type) == 0 && c_type != TYPE_ID_ANY()
        tc_error(tc, ERR_CONDITION_NOT_BOOL(), "Condition in 'if' must evaluate to bool or numeric", span_default())
      @end
    @end

    scope_stack_push(tc.tc_scopes, SCOPE_BLOCK(), "if_then")
    i = 0
    t_len = stmt.then_body.len()
    @while i < t_len
      tc_check_statement(tc, stmt.then_body[i])
      i = i + 1
    @end
    scope_stack_pop(tc.tc_scopes)

    @if stmt.else_body.len() > 0
      scope_stack_push(tc.tc_scopes, SCOPE_BLOCK(), "if_else")
      j = 0
      e_len = stmt.else_body.len()
      @while j < e_len
        tc_check_statement(tc, stmt.else_body[j])
        j = j + 1
      @end
      scope_stack_pop(tc.tc_scopes)
    @end

    return 1
  @end

  // 4. While Loop Statement
  @if str_eq(k, "While") == 1
    cond_node = stmt.condition
    @if cond_node == 0 cond_node = stmt.cond @end
    @if cond_node != 0
      c_type = tc_check_expr(tc, cond_node)
      @if c_type != TYPE_ID_BOOL() && type_is_numeric(tc.tc_reg, c_type) == 0 && c_type != TYPE_ID_ANY()
        tc_error(tc, ERR_CONDITION_NOT_BOOL(), "Condition in 'while' must evaluate to bool or numeric", span_default())
      @end
    @end

    scope_stack_push(tc.tc_scopes, SCOPE_BLOCK(), "while_loop")
    scope_set_loop(tc.tc_scopes, 1)

    i = 0
    b_len = stmt.body.len()
    @while i < b_len
      tc_check_statement(tc, stmt.body[i])
      i = i + 1
    @end

    scope_stack_pop(tc.tc_scopes)
    return 1
  @end

  // 5. Break / Continue
  @if str_eq(k, "Break") == 1 || str_eq(k, "Continue") == 1
    @if scope_is_inside_loop(tc.tc_scopes) == 0
      tc_error(tc, ERR_BREAK_OUTSIDE_LOOP(), "'" + k + "' statement used outside of any loop construct", span_default())
    @end
    return 1
  @end

  // 6. Standalone Expression Statement
  tc_check_expr(tc, stmt)
  return 1
@end

// ── 5. FUNCTION & PROGRAM VERIFICATION ───────────────────────────────────────

@fn tc_check_function_def(tc, fn_node)
  fn_name = fn_node.name

  param_types = []
  i = 0
  n = fn_node.params.len()
  @while i < n
    param = fn_node.params[i]
    p_type_id = TYPE_ID_ANY()
    @if param.ret_type != ""
      @if str_eq(param.ret_type, "i64") == 1    p_type_id = TYPE_ID_I64()    @end
      @if str_eq(param.ret_type, "f64") == 1    p_type_id = TYPE_ID_F64()    @end
      @if str_eq(param.ret_type, "bool") == 1   p_type_id = TYPE_ID_BOOL()   @end
      @if str_eq(param.ret_type, "string") == 1 p_type_id = TYPE_ID_STRING() @end
      @if str_eq(param.ret_type, "byte") == 1   p_type_id = TYPE_ID_BYTE()   @end
    @end
    param_types = param_types.push(p_type_id)
    i = i + 1
  @end

  ret_type_id = TYPE_ID_I64()
  @if fn_node.ret_type != ""
    @if str_eq(fn_node.ret_type, "void") == 1   ret_type_id = TYPE_ID_VOID()   @end
    @if str_eq(fn_node.ret_type, "i64") == 1    ret_type_id = TYPE_ID_I64()    @end
    @if str_eq(fn_node.ret_type, "f64") == 1    ret_type_id = TYPE_ID_F64()    @end
    @if str_eq(fn_node.ret_type, "bool") == 1   ret_type_id = TYPE_ID_BOOL()   @end
    @if str_eq(fn_node.ret_type, "string") == 1 ret_type_id = TYPE_ID_STRING() @end
  @end

  fn_type_id = type_make_function(tc.tc_reg, param_types, ret_type_id)
  fn_sym = symbol_function(fn_name, fn_type_id, span_default(), tc.tc_scopes.stk_current_id, 1)
  scope_define(tc.tc_scopes, fn_sym)
  symtab_put(tc.tc_symtab, fn_sym)

  scope_stack_push(tc.tc_scopes, SCOPE_FUNCTION(), fn_name)
  curr_sc = scope_stack_current(tc.tc_scopes)
  curr_sc.sc_ret_type = ret_type_id

  prev_fn_ret = tc.tc_current_fn_ret_type
  prev_fn_name = tc.tc_current_fn_name
  tc.tc_current_fn_ret_type = ret_type_id
  tc.tc_current_fn_name = fn_name

  j = 0
  @while j < n
    param = fn_node.params[j]
    p_sym = symbol_parameter(param.name, param_types[j], span_default(), tc.tc_scopes.stk_current_id)
    scope_define(tc.tc_scopes, p_sym)
    j = j + 1
  @end

  k_stmt = 0
  body_len = fn_node.body.len()
  @while k_stmt < body_len
    tc_check_statement(tc, fn_node.body[k_stmt])
    k_stmt = k_stmt + 1
  @end

  scope_stack_pop(tc.tc_scopes)
  tc.tc_current_fn_ret_type = prev_fn_ret
  tc.tc_current_fn_name = prev_fn_name

  return 1
@end

@fn tc_check_struct_def(tc, struct_node)
  s_name = struct_node.name
  fields = []
  i = 0
  n = struct_node.elements.len()
  @while i < n
    f_node = struct_node.elements[i]
    f_t_id = TYPE_ID_I64()
    @if str_eq(f_node.ret_type, "i64") == 1    f_t_id = TYPE_ID_I64()    @end
    @if str_eq(f_node.ret_type, "f64") == 1    f_t_id = TYPE_ID_F64()    @end
    @if str_eq(f_node.ret_type, "bool") == 1   f_t_id = TYPE_ID_BOOL()   @end
    @if str_eq(f_node.ret_type, "string") == 1 f_t_id = TYPE_ID_STRING() @end
    @if str_eq(f_node.ret_type, "byte") == 1   f_t_id = TYPE_ID_BYTE()   @end

    f_def = type_make_field(f_node.name, f_t_id, 0, 8, 1)
    fields = fields.push(f_def)
    i = i + 1
  @end

  struct_type_id = type_make_struct(tc.tc_reg, s_name, fields)
  s_sym = symbol_struct(s_name, struct_type_id, span_default(), tc.tc_scopes.stk_current_id)
  scope_define(tc.tc_scopes, s_sym)
  symtab_put(tc.tc_symtab, s_sym)
  return struct_type_id
@end

@fn tc_check_program(tc, statements)
  @if statements == 0 return 1 @end

  i = 0
  n = statements.len()
  @while i < n
    st = statements[i]
    @if str_eq(st.kind, "StructDef") == 1
      tc_check_struct_def(tc, st)
    @end
    i = i + 1
  @end

  j = 0
  @while j < n
    st = statements[j]
    @if str_eq(st.kind, "FnDef") == 1 || str_eq(st.kind, "Function") == 1
      tc_check_function_def(tc, st)
    @elif str_eq(st.kind, "StructDef") == 0
      tc_check_statement(tc, st)
    @end
    j = j + 1
  @end

  return tc_has_errors(tc) == 0
@end
