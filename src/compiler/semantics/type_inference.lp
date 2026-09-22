// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: LOCAL TYPE INFERENCE ENGINE (type_inference.lp)
// Module: src/compiler/semantics/type_inference.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// Modern programmers demand strong static type guarantees without redundant, verbose
// type annotations on every local variable binding. This module implements:
// 1. Algorithmic Type Inference: Infers the precise concrete type of unannotated
//    local variables (`x = 42`, `msg = "hello"`, `points = [p1, p2]`) directly
//    from their initialization expressions.
// 2. Compositional Expression Deduction: Recursively computes result types for
//    binary arithmetic, string concatenations, pointer borrows, struct accessors,
//    and function invocations.
// 3. Bidirectional Scope Registration: Upon successful inference, automatically
//    binds the typed Symbol into the active lexical ScopeStack.
// 4. Sovereign Prefixed Layout: Named constructors `InferenceContext()` and
//    `InferredBinding()` with `ic_` and `ib_` prefixes eliminate field collisions.
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/semantics/symbol"
import "compiler/semantics/scope"
import "compiler/semantics/type_def"
import "compiler/semantics/type_unify"
import "compiler/frontend/ast/ast_node"

// ── 1. INFERENCE CONTEXT DEFINITION ──────────────────────────────────────────

@struct InferredBinding
  ib_name: string
  ib_type_id: i64
@end

@struct InferenceContext
  ic_reg: TypeRegistry
  ic_scopes: ScopeStack
  ic_subst: TypeSubst
  ic_next_var_id: i64
  ic_bindings: array
@end

@fn infer_ctx_new(reg, scopes)
  // WHY: Constructs an isolated inference state wrapping the active scope stack
  ctx = InferenceContext()
  ctx.ic_reg = reg
  ctx.ic_scopes = scopes
  ctx.ic_subst = subst_new()
  ctx.ic_next_var_id = 1
  ctx.ic_bindings = []
  return ctx
@end

@fn infer_fresh_var(ctx, prefix)
  v_id = ctx.ic_next_var_id
  ctx.ic_next_var_id = ctx.ic_next_var_id + 1
  v_name = prefix + "_" + to_str(v_id)
  return type_make_var(ctx.ic_reg, v_id, v_name)
@end

// ── 2. LITERAL TYPE RECOGNITION ──────────────────────────────────────────────

@fn infer_literal_type(ctx, lit_ast)
  @if lit_ast == 0 return TYPE_ID_VOID() @end

  k = lit_ast.kind
  @if str_eq(k, "Integer") == 1 || str_eq(k, "INT") == 1 || str_eq(k, "HEX_INT") == 1 || str_eq(k, "BIN_INT") == 1
    return TYPE_ID_I64()
  @end

  @if str_eq(k, "Float") == 1 || str_eq(k, "FLOAT") == 1
    return TYPE_ID_F64()
  @end

  @if str_eq(k, "String") == 1 || str_eq(k, "STRING") == 1
    return TYPE_ID_STRING()
  @end

  @if str_eq(k, "Bool") == 1 || str_eq(k, "BOOL") == 1
    return TYPE_ID_BOOL()
  @end

  @if str_eq(k, "None") == 1 || str_eq(k, "NONE") == 1 || str_eq(k, "NIL") == 1
    return TYPE_ID_VOID()
  @end

  return TYPE_ID_ANY()
@end

// ── 3. OPERATOR TYPE DEDUCTION ───────────────────────────────────────────────

@fn infer_binary_op_type(ctx, op, left_t, right_t)
  @if op == "+"
    @if left_t == TYPE_ID_STRING() || right_t == TYPE_ID_STRING()
      return TYPE_ID_STRING()
    @end
    @if left_t == TYPE_ID_F64() || right_t == TYPE_ID_F64()
      return TYPE_ID_F64()
    @end
    return TYPE_ID_I64()
  @end

  @if op == "-" || op == "*" || op == "/" || op == "%"
    @if left_t == TYPE_ID_F64() || right_t == TYPE_ID_F64()
      return TYPE_ID_F64()
    @end
    return TYPE_ID_I64()
  @end

  // Relational & equality comparisons always yield a 1-byte boolean
  @if op == "==" || op == "!=" || op == "<" || op == "<=" || op == ">" || op == ">="
    return TYPE_ID_BOOL()
  @end

  // Logical operations yield boolean
  @if op == "&&" || op == "||" || op == "and" || op == "or"
    return TYPE_ID_BOOL()
  @end

  // Bitwise operations
  @if op == "&" || op == "|" || op == "^" || op == "<<" || op == ">>"
    return TYPE_ID_I64()
  @end

  return TYPE_ID_I64()
@end

@fn infer_unary_op_type(ctx, op, inner_t)
  @if op == "!" || op == "not" return TYPE_ID_BOOL() @end
  @if op == "-" || op == "+"   return inner_t @end
  @if op == "~"                return TYPE_ID_I64() @end

  @if op == "&"
    return type_make_pointer(ctx.ic_reg, inner_t, 0)
  @end

  @if op == "&mut"
    return type_make_pointer(ctx.ic_reg, inner_t, 1)
  @end

  @if op == "*"
    ty = type_registry_get(ctx.ic_reg, inner_t)
    @if ty != 0 && ty.ty_kind == TYPE_KIND_POINTER()
      return ty.ty_elem_type_id
    @end
    return TYPE_ID_ANY()
  @end

  return inner_t
@end

// ── 4. RECURSIVE EXPRESSION TYPE INFERENCE ───────────────────────────────────

@fn infer_expr_type(ctx, expr)
  @if expr == 0 return TYPE_ID_VOID() @end

  k = expr.kind

  // 1. Literals
  @if str_eq(k, "Integer") == 1 || str_eq(k, "Float") == 1 || str_eq(k, "String") == 1 || str_eq(k, "Bool") == 1 || str_eq(k, "None") == 1 || str_eq(k, "INT") == 1 || str_eq(k, "HEX_INT") == 1 || str_eq(k, "STRING") == 1 || str_eq(k, "BOOL") == 1
    return infer_literal_type(ctx, expr)
  @end

  // 2. Variable / Identifier lookup
  @if str_eq(k, "Variable") == 1 || str_eq(k, "IDENT") == 1 || str_eq(k, "Identifier") == 1
    v_name = expr.name
    @if v_name == "" && expr.target != ""
      v_name = expr.target
    @end
    sym = scope_lookup(ctx.ic_scopes, v_name)
    @if sym != 0 && sym.sym_type_ref > 0
      return sym.sym_type_ref
    @end
    @if str_eq(v_name, "true") == 1 || str_eq(v_name, "false") == 1 return TYPE_ID_BOOL() @end
    @if str_eq(v_name, "null") == 1 || str_eq(v_name, "nil") == 1 || str_eq(v_name, "none") == 1 return TYPE_ID_VOID() @end
    return TYPE_ID_ANY()
  @end

  // 3. Binary Operations
  @if str_eq(k, "BinaryOp") == 1
    left_t = infer_expr_type(ctx, expr.left)
    right_t = infer_expr_type(ctx, expr.right)
    return infer_binary_op_type(ctx, expr.op, left_t, right_t)
  @end

  // 4. Unary Operations
  @if str_eq(k, "UnaryOp") == 1
    inner_t = infer_expr_type(ctx, expr.expr)
    return infer_unary_op_type(ctx, expr.op, inner_t)
  @end

  // 5. Array Literal: [e1, e2, e3]
  @if str_eq(k, "ArrayLit") == 1 || str_eq(k, "Array") == 1
    elem_count = expr.elements.len()
    @if elem_count == 0
      return type_make_array(ctx.ic_reg, TYPE_ID_ANY(), -1)
    @end
    first_t = infer_expr_type(ctx, expr.elements[0])
    i = 1
    @while i < elem_count
      curr_t = infer_expr_type(ctx, expr.elements[i])
      first_t = type_common_supertype(ctx.ic_reg, first_t, curr_t)
      i = i + 1
    @end
    return type_make_array(ctx.ic_reg, first_t, elem_count)
  @end

  // 6. Struct Literal: { x: 1, y: 2 }
  @if str_eq(k, "StructLit") == 1
    @if expr.name != ""
      s_sym = scope_lookup(ctx.ic_scopes, expr.name)
      @if s_sym != 0 && s_sym.sym_type_ref > 0
        return s_sym.sym_type_ref
      @end
    @end
    fields = []
    i = 0
    n = expr.elements.len()
    @while i < n
      f_ast = expr.elements[i]
      f_type = infer_expr_type(ctx, f_ast.value)
      @if f_type == 0 || f_type == TYPE_ID_VOID()
        f_type = infer_expr_type(ctx, f_ast.expr)
      @end
      f_def = type_make_field(f_ast.name, f_type, 0, 8, 1)
      fields = fields.push(f_def)
      i = i + 1
    @end
    return type_make_struct(ctx.ic_reg, "<anon_struct>", fields)
  @end

  // 7. Function Call: func(a, b)
  @if str_eq(k, "Call") == 1
    fn_name = ""
    @if expr.name != ""
      fn_name = expr.name
    @elif expr.func != 0 && expr.func.name != ""
      fn_name = expr.func.name
    @end

    @if str_eq(fn_name, "len") == 1 || str_eq(fn_name, "str_len") == 1 || str_eq(fn_name, "c_len") == 1 || str_eq(fn_name, "to_int") == 1 || str_eq(fn_name, "str_to_int") == 1
      return TYPE_ID_I64()
    @end
    @if str_eq(fn_name, "to_str") == 1 || str_eq(fn_name, "str_concat") == 1 || str_eq(fn_name, "str_substr") == 1 || str_eq(fn_name, "str_slice") == 1
      return TYPE_ID_STRING()
    @end
    @if str_eq(fn_name, "str_eq") == 1 || str_eq(fn_name, "str_starts_with") == 1 || str_eq(fn_name, "str_ends_with") == 1
      return TYPE_ID_BOOL()
    @end
    @if str_eq(fn_name, "say") == 1 || str_eq(fn_name, "println") == 1 || str_eq(fn_name, "print") == 1
      return TYPE_ID_VOID()
    @end

    f_sym = scope_lookup(ctx.ic_scopes, fn_name)
    @if f_sym != 0
      f_ty = type_registry_get(ctx.ic_reg, f_sym.sym_type_ref)
      @if f_ty != 0 && f_ty.ty_kind == TYPE_KIND_FUNCTION()
        return f_ty.ty_ret_type_id
      @end
    @end
    return TYPE_ID_ANY()
  @end

  // 8. Field Access: target.member
  @if str_eq(k, "MemberAccess") == 1 || str_eq(k, "FieldAccess") == 1
    target_t = infer_expr_type(ctx, expr.target)
    f_def = type_find_field(ctx.ic_reg, target_t, expr.name)
    @if f_def != 0
      return f_def.fd_type_id
    @end
    return TYPE_ID_ANY()
  @end

  // 9. Index Access: array[index]
  @if str_eq(k, "Index") == 1
    arr_t = infer_expr_type(ctx, expr.iterable)
    ty = type_registry_get(ctx.ic_reg, arr_t)
    @if ty != 0
      @if ty.ty_kind == TYPE_KIND_ARRAY()
        return ty.ty_elem_type_id
      @end
      @if ty.ty_kind == TYPE_KIND_STRING()
        return TYPE_ID_BYTE()
      @end
    @end
    return TYPE_ID_ANY()
  @end

  return TYPE_ID_ANY()
@end

// ── 5. LOCAL VARIABLE DECLARATION INFERENCE & BINDING ────────────────────────

@fn infer_var_declaration(ctx, var_name, init_ast, is_const, span)
  // WHY: Analyzes the RHS initialization expression, determines the variable's
  // concrete type, and creates a sound Symbol in the current lexical scope.
  @if ctx == 0 || var_name == "" return 0 @end

  inferred_t = infer_expr_type(ctx, init_ast)
  @if inferred_t <= 0
    inferred_t = TYPE_ID_ANY()
  @end

  binding = InferredBinding()
  binding.ib_name = var_name
  binding.ib_type_id = inferred_t
  ctx.ic_bindings = ctx.ic_bindings.push(binding)

  sym = symbol_new(var_name, SYM_KIND_VARIABLE(), inferred_t, is_const, span, ctx.ic_scopes.stk_current_id)
  scope_define(ctx.ic_scopes, sym)

  return inferred_t
@end
