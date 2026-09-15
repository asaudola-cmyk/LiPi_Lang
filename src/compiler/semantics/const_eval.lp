// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: COMPILE-TIME CONSTANT EVALUATOR (const_eval.lp)
// Module: src/compiler/semantics/const_eval.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// Partial evaluation (Valentin Turchin Supercompilation) collapses compile-time
// deterministic computations down to zero runtime instructions.
// This module provides:
// 1. Full Constant Expression Evaluation: Solves arithmetic, bitwise shifts, string
//    concatenations, logic chains, array lengths, and comparison trees at compile time.
// 2. Hardware Trap Protection: Shields the compiler process from division-by-zero
//    crashes (SIGFPE) and out-of-range bitwise shifts (>= 64 bits).
// 3. AST Constant Folding Pass: Recursively replaces foldable AST expression
//    sub-trees with direct literal nodes, shrinking code size and eliminating jumps.
// 4. Named Struct Constructors: Uses `ConstVal()` and `ConstEnv()` ensuring safe
//    binary layout without struct collisions via `cv_` and `ce_` prefixes.
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/semantics/symbol"
import "compiler/frontend/ast/ast_node"

// ── 1. CONSTANT VALUE KIND CONSTANTS ─────────────────────────────────────────

@fn CONST_KIND_NONE()   return 0 @end
@fn CONST_KIND_INT()    return 1 @end
@fn CONST_KIND_FLOAT()  return 2 @end
@fn CONST_KIND_BOOL()   return 3 @end
@fn CONST_KIND_STRING() return 4 @end
@fn CONST_KIND_ARRAY()  return 5 @end
@fn CONST_KIND_ERROR()  return 6 @end

// ── 2. CONSTANT VALUE STRUCT & CONSTRUCTORS ──────────────────────────────────

@struct ConstVal
  cv_kind: i64
  cv_int_val: i64
  cv_bool_val: i64
  cv_str_val: string
  cv_arr_val: array
  cv_is_valid: i64
  cv_err_msg: string
@end

@fn const_val_none()
  v = ConstVal()
  v.cv_kind = CONST_KIND_NONE()
  v.cv_int_val = 0
  v.cv_bool_val = 0
  v.cv_str_val = ""
  v.cv_arr_val = []
  v.cv_is_valid = 0
  v.cv_err_msg = ""
  return v
@end

@fn const_val_int(i)
  v = ConstVal()
  v.cv_kind = CONST_KIND_INT()
  v.cv_int_val = i
  v.cv_bool_val = 0
  v.cv_str_val = ""
  v.cv_arr_val = []
  v.cv_is_valid = 1
  v.cv_err_msg = ""
  return v
@end

@fn const_val_bool(b)
  int_repr = 0
  @if b != 0 int_repr = 1 @end
  v = ConstVal()
  v.cv_kind = CONST_KIND_BOOL()
  v.cv_int_val = int_repr
  v.cv_bool_val = int_repr
  v.cv_str_val = ""
  v.cv_arr_val = []
  v.cv_is_valid = 1
  v.cv_err_msg = ""
  return v
@end

@fn const_val_str(s)
  v = ConstVal()
  v.cv_kind = CONST_KIND_STRING()
  v.cv_int_val = 0
  v.cv_bool_val = 0
  v.cv_str_val = s
  v.cv_arr_val = []
  v.cv_is_valid = 1
  v.cv_err_msg = ""
  return v
@end

@fn const_val_arr(arr)
  v = ConstVal()
  v.cv_kind = CONST_KIND_ARRAY()
  v.cv_int_val = 0
  v.cv_bool_val = 0
  v.cv_str_val = ""
  v.cv_arr_val = arr
  v.cv_is_valid = 1
  v.cv_err_msg = ""
  return v
@end

@fn const_val_err(msg)
  v = ConstVal()
  v.cv_kind = CONST_KIND_ERROR()
  v.cv_int_val = 0
  v.cv_bool_val = 0
  v.cv_str_val = ""
  v.cv_arr_val = []
  v.cv_is_valid = 0
  v.cv_err_msg = msg
  return v
@end

// ── 3. CONSTANT ENVIRONMENT BINDINGS ─────────────────────────────────────────

@struct ConstEnv
  ce_names: array
  ce_values: array
@end

@fn const_env_new()
  env = ConstEnv()
  env.ce_names = []
  env.ce_values = []
  return env
@end

@fn const_env_set(env, name, val)
  @if env == 0 || name == "" return 0 @end

  i = 0
  n = env.ce_names.len()
  @while i < n
    @if str_eq(env.ce_names[i], name) == 1
      env.ce_values[i] = val
      return 1
    @end
    i = i + 1
  @end

  env.ce_names = env.ce_names.push(name)
  env.ce_values = env.ce_values.push(val)
  return 1
@end

@fn const_env_get(env, name)
  @if env == 0 return const_val_none() @end

  i = 0
  n = env.ce_names.len()
  @while i < n
    @if str_eq(env.ce_names[i], name) == 1
      return env.ce_values[i]
    @end
    i = i + 1
  @end

  return const_val_none()
@end

@fn const_env_has(env, name)
  res = const_env_get(env, name)
  @if res.cv_is_valid == 1 return 1 @end
  return 0
@end

// ── 4. BINARY CONSTANT FOLDING WITH TRAP PROTECTION ──────────────────────────

@fn const_eval_binop(op, lhs, rhs)
  @if lhs.cv_is_valid == 0 || rhs.cv_is_valid == 0
    return const_val_none()
  @end

  // String concatenation
  @if op == "+" && (lhs.cv_kind == CONST_KIND_STRING() || rhs.cv_kind == CONST_KIND_STRING())
    l_str = lhs.cv_str_val
    r_str = rhs.cv_str_val
    @if lhs.cv_kind == CONST_KIND_INT() l_str = to_str(lhs.cv_int_val) @end
    @if rhs.cv_kind == CONST_KIND_INT() r_str = to_str(rhs.cv_int_val) @end
    return const_val_str(l_str + r_str)
  @end

  // Integer arithmetic
  @if lhs.cv_kind == CONST_KIND_INT() && rhs.cv_kind == CONST_KIND_INT()
    l = lhs.cv_int_val
    r = rhs.cv_int_val

    @if op == "+" return const_val_int(l + r) @end
    @if op == "-" return const_val_int(l - r) @end
    @if op == "*" return const_val_int(l * r) @end

    @if op == "/"
      @if r == 0
        return const_val_err("Division by zero in compile-time constant expression")
      @end
      return const_val_int(l / r)
    @end

    @if op == "%"
      @if r == 0
        return const_val_err("Modulo by zero in compile-time constant expression")
      @end
      return const_val_int(l % r)
    @end

    @if op == "<<"
      @if r < 0 || r >= 64 return const_val_int(0) @end
      res = l
      shift_i = 0
      @while shift_i < r
        res = res * 2
        shift_i = shift_i + 1
      @end
      return const_val_int(res)
    @end

    @if op == ">>"
      @if r < 0 || r >= 64 return const_val_int(0) @end
      res = l
      shift_i = 0
      @while shift_i < r
        res = res / 2
        shift_i = shift_i + 1
      @end
      return const_val_int(res)
    @end

    @if op == "&" return const_val_int(l & r) @end
    @if op == "|" return const_val_int(l | r) @end
    @if op == "^" return const_val_int(l ^ r) @end

    // Comparisons
    @if op == "==" @if l == r return const_val_bool(1) @else return const_val_bool(0) @end @end
    @if op == "!=" @if l != r return const_val_bool(1) @else return const_val_bool(0) @end @end
    @if op == "<"  @if l < r  return const_val_bool(1) @else return const_val_bool(0) @end @end
    @if op == "<=" @if l <= r return const_val_bool(1) @else return const_val_bool(0) @end @end
    @if op == ">"  @if l > r  return const_val_bool(1) @else return const_val_bool(0) @end @end
    @if op == ">=" @if l >= r return const_val_bool(1) @else return const_val_bool(0) @end @end
  @end

  // Boolean logic
  @if lhs.cv_kind == CONST_KIND_BOOL() && rhs.cv_kind == CONST_KIND_BOOL()
    lb = lhs.cv_bool_val
    rb = rhs.cv_bool_val
    @if op == "&&" || op == "and"
      @if lb == 1 && rb == 1 return const_val_bool(1) @else return const_val_bool(0) @end
    @end
    @if op == "||" || op == "or"
      @if lb == 1 || rb == 1 return const_val_bool(1) @else return const_val_bool(0) @end
    @end
    @if op == "=="
      @if lb == rb return const_val_bool(1) @else return const_val_bool(0) @end
    @end
    @if op == "!="
      @if lb != rb return const_val_bool(1) @else return const_val_bool(0) @end
    @end
  @end

  // String equality
  @if lhs.cv_kind == CONST_KIND_STRING() && rhs.cv_kind == CONST_KIND_STRING()
    @if op == "=="
      @if str_eq(lhs.cv_str_val, rhs.cv_str_val) == 1 return const_val_bool(1) @else return const_val_bool(0) @end
    @end
    @if op == "!="
      @if str_eq(lhs.cv_str_val, rhs.cv_str_val) == 0 return const_val_bool(1) @else return const_val_bool(0) @end
    @end
  @end

  return const_val_none()
@end

@fn const_eval_unop(op, inner)
  @if inner.cv_is_valid == 0 return const_val_none() @end

  @if op == "!" || op == "not"
    @if inner.cv_kind == CONST_KIND_BOOL()
      @if inner.cv_bool_val == 0 return const_val_bool(1) @else return const_val_bool(0) @end
    @end
    @if inner.cv_kind == CONST_KIND_INT()
      @if inner.cv_int_val == 0 return const_val_bool(1) @else return const_val_bool(0) @end
    @end
  @end

  @if op == "-" && inner.cv_kind == CONST_KIND_INT()
    return const_val_int(0 - inner.cv_int_val)
  @end

  @if op == "+" && inner.cv_kind == CONST_KIND_INT()
    return inner
  @end

  return const_val_none()
@end

// ── 5. RECURSIVE CONSTANT EXPRESSION EVALUATION ───────────────────────────────

@fn const_eval_expr(env, expr)
  @if expr == 0 return const_val_none() @end

  k = expr.kind

  // 1. Literal Integer
  @if str_eq(k, "Integer") == 1 || str_eq(k, "INT") == 1 || str_eq(k, "HEX_INT") == 1
    return const_val_int(expr.val)
  @end

  // 2. Literal Boolean
  @if str_eq(k, "Bool") == 1 || str_eq(k, "BOOL") == 1
    @if str_eq(expr.name, "true") == 1 || expr.val == 1
      return const_val_bool(1)
    @end
    return const_val_bool(0)
  @end

  // 3. Literal String
  @if str_eq(k, "String") == 1 || str_eq(k, "STRING") == 1
    return const_val_str(expr.name)
  @end

  // 4. Identifier lookup in constant environment
  @if str_eq(k, "Variable") == 1 || str_eq(k, "IDENT") == 1
    v_name = expr.name
    @if v_name == "" && expr.target != "" v_name = expr.target @end
    @if str_eq(v_name, "true") == 1  return const_val_bool(1) @end
    @if str_eq(v_name, "false") == 1 return const_val_bool(0) @end
    return const_env_get(env, v_name)
  @end

  // 5. Binary Operation
  @if str_eq(k, "BinaryOp") == 1
    lhs_val = const_eval_expr(env, expr.left)
    rhs_val = const_eval_expr(env, expr.right)
    return const_eval_binop(expr.op, lhs_val, rhs_val)
  @end

  // 6. Unary Operation
  @if str_eq(k, "UnaryOp") == 1
    inner_val = const_eval_expr(env, expr.expr)
    return const_eval_unop(expr.op, inner_val)
  @end

  // 7. Array Literal
  @if str_eq(k, "ArrayLit") == 1 || str_eq(k, "Array") == 1
    items = []
    i = 0
    n = expr.elements.len()
    all_const = 1
    @while i < n && all_const == 1
      item_val = const_eval_expr(env, expr.elements[i])
      @if item_val.cv_is_valid == 1
        items = items.push(item_val)
      @else
        all_const = 0
      @end
      i = i + 1
    @end
    @if all_const == 1
      return const_val_arr(items)
    @end
    return const_val_none()
  @end

  // 8. Built-in Function Call (len, str_len)
  @if str_eq(k, "Call") == 1
    fn_name = expr.name
    @if fn_name == "" && expr.func != 0 fn_name = expr.func.name @end
    @if (str_eq(fn_name, "len") == 1 || str_eq(fn_name, "str_len") == 1) && expr.args.len() == 1
      arg_val = const_eval_expr(env, expr.args[0])
      @if arg_val.cv_is_valid == 1
        @if arg_val.cv_kind == CONST_KIND_STRING()
          return const_val_int(str_len(arg_val.cv_str_val))
        @end
        @if arg_val.cv_kind == CONST_KIND_ARRAY()
          return const_val_int(arg_val.cv_arr_val.len())
        @end
      @end
    @end
  @end

  // 9. Array Indexing on constant array
  @if str_eq(k, "Index") == 1
    arr_val = const_eval_expr(env, expr.iterable)
    idx_val = const_eval_expr(env, expr.index)
    @if arr_val.cv_is_valid == 1 && idx_val.cv_is_valid == 1 && idx_val.cv_kind == CONST_KIND_INT()
      idx = idx_val.cv_int_val
      @if arr_val.cv_kind == CONST_KIND_ARRAY()
        @if idx >= 0 && idx < arr_val.cv_arr_val.len()
          return arr_val.cv_arr_val[idx]
        @end
      @end
      @if arr_val.cv_kind == CONST_KIND_STRING()
        @if idx >= 0 && idx < str_len(arr_val.cv_str_val)
          code = str_char_at(arr_val.cv_str_val, idx)
          return const_val_int(code)
        @end
      @end
    @end
  @end

  return const_val_none()
@end

// ── 6. CONSTANT FOLDING AST TRANSFORM PASS ───────────────────────────────────

@fn const_fold_expr(env, expr)
  // WHY: If expr can be completely evaluated at compile time, rewrites it into
  // a clean literal node. Otherwise, recursively folds its children.
  @if expr == 0 return 0 @end

  val = const_eval_expr(env, expr)
  @if val.cv_is_valid == 1
    @if val.cv_kind == CONST_KIND_INT()
      folded = {
        kind: "Integer",
        name: to_str(val.cv_int_val),
        params: [],
        body: [],
        ret_type: "i64",
        val: val.cv_int_val,
        op: "",
        left: 0,
        right: 0,
        expr: 0,
        condition: 0,
        then_body: [],
        elif_branches: [],
        else_body: [],
        target: "",
        value: 0,
        elements: [],
        args: [],
        func: 0,
        variable: "",
        iterable: 0,
        index: 0,
        cond: 0
      }
      return folded
    @end

    @if val.cv_kind == CONST_KIND_BOOL()
      b_str = "false"
      @if val.cv_bool_val == 1 b_str = "true" @end
      folded = {
        kind: "Bool",
        name: b_str,
        params: [],
        body: [],
        ret_type: "bool",
        val: val.cv_bool_val,
        op: "",
        left: 0,
        right: 0,
        expr: 0,
        condition: 0,
        then_body: [],
        elif_branches: [],
        else_body: [],
        target: "",
        value: 0,
        elements: [],
        args: [],
        func: 0,
        variable: "",
        iterable: 0,
        index: 0,
        cond: 0
      }
      return folded
    @end

    @if val.cv_kind == CONST_KIND_STRING()
      folded = {
        kind: "String",
        name: val.cv_str_val,
        params: [],
        body: [],
        ret_type: "string",
        val: 0,
        op: "",
        left: 0,
        right: 0,
        expr: 0,
        condition: 0,
        then_body: [],
        elif_branches: [],
        else_body: [],
        target: "",
        value: 0,
        elements: [],
        args: [],
        func: 0,
        variable: "",
        iterable: 0,
        index: 0,
        cond: 0
      }
      return folded
    @end
  @end

  // Could not fold top node; recursively fold children
  @if str_eq(expr.kind, "BinaryOp") == 1
    expr.left = const_fold_expr(env, expr.left)
    expr.right = const_fold_expr(env, expr.right)
  @end
  @if str_eq(expr.kind, "UnaryOp") == 1
    expr.expr = const_fold_expr(env, expr.expr)
  @end

  return expr
@end

@fn const_val_to_string(val)
  @if val.cv_is_valid == 0 return "<invalid_const>" @end
  @if val.cv_kind == CONST_KIND_INT()    return to_str(val.cv_int_val)   @end
  @if val.cv_kind == CONST_KIND_BOOL()
    @if val.cv_bool_val == 1 return "true" @else return "false" @end
  @end
  @if val.cv_kind == CONST_KIND_STRING() return "\"" + val.cv_str_val + "\"" @end
  @if val.cv_kind == CONST_KIND_ARRAY()  return "array[" + to_str(val.cv_arr_val.len()) + "]" @end
  return "const"
@end
