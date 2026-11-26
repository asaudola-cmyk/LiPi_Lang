// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: ZERO-GC OWNERSHIP & MOVE ANALYZER (ownership_check.lp)
// Module: src/compiler/semantics/ownership_check.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// Zero-cost memory safety without garbage collection is essential for bare-metal OS
// kernels, real-time audio/video processing, and high-frequency trading engines.
// This module provides affine type checking and move semantics:
// 1. Single Ownership Invariant: Every non-trivial heap allocation, file handle,
//    or buffer has exactly one owning variable.
// 2. Move Semantics: Assigning or passing a non-copy value transfers ownership.
//    Subsequent reads from the moved-from variable are flagged with `ERR_USE_AFTER_MOVE`.
// 3. Aliasing XOR Mutability (Borrow Checking):
//    - Multiple simultaneous shared borrows (&T) are allowed.
//    - Exactly ONE exclusive mutable borrow (&mut T) is allowed.
//    - A resource CANNOT be moved or mutated while active borrows exist.
// 4. Copy vs Move Types: Primitive integers, floats, booleans, and bytes are
//    automatically classified as Copy types, exempt from destructive moves.
// 5. Sovereign Prefixed Fields (`rb_`, `od_`, `oc_`) eliminate struct collisions.
// ==============================================================================

import "utso/collections"
import "utso/string"
import "compiler/semantics/symbol"

import "compiler/frontend/ast/ast_node"
// ── 1. OWNERSHIP & BORROW STATE ENUMERATIONS ─────────────────────────────────

@fn OWN_STATE_UNINITIALIZED()   return 0 @end
@fn OWN_STATE_OWNED()           return 1 @end
@fn OWN_STATE_MOVED()           return 2 @end
@fn OWN_STATE_BORROWED_SHARED() return 3 @end
@fn OWN_STATE_BORROWED_MUT()    return 4 @end
@fn OWN_STATE_DROPPED()         return 5 @end

// Diagnostic Error Codes
@fn ERR_USE_AFTER_MOVE()          return 2001 @end
@fn ERR_MOVE_WHILE_BORROWED()     return 2002 @end
@fn ERR_MUT_BORROW_CONFLICT()     return 2003 @end
@fn ERR_SHARED_BORROW_CONFLICT()  return 2004 @end
@fn ERR_MUTATE_WHILE_BORROWED()   return 2005 @end
@fn ERR_USE_OF_UNINITIALIZED()    return 2006 @end
@fn ERR_BORROW_OUTLIVES_SCOPE()   return 2007 @end

// ── 2. RESOURCE BINDING & TRACKER STATE ──────────────────────────────────────

@struct ResourceBinding
  rb_name: string
  rb_state: i64
  rb_is_copy: i64
  rb_shared_borrow_count: i64
  rb_scope_depth: i64
  rb_declared_span: SourceSpan
  rb_moved_span: SourceSpan
@end

@fn binding_new(name, is_copy, depth, span)
  sp = span
  @if sp == 0 sp = span_default() @end

  b = ResourceBinding()
  b.rb_name = name
  b.rb_state = OWN_STATE_OWNED()
  b.rb_is_copy = is_copy
  b.rb_shared_borrow_count = 0
  b.rb_scope_depth = depth
  b.rb_declared_span = sp
  b.rb_moved_span = span_default()
  return b
@end

@struct OwnershipDiagnostic
  od_code: i64
  od_message: string
  od_span: SourceSpan
  od_is_warning: i64
@end

@struct OwnershipChecker
  oc_bindings: array
  oc_scope_depth: i64
  oc_errors: array
  oc_warnings: array
  oc_struct_map: i64
  oc_fn_consumes: i64
@end

@fn ownership_checker_new()
  oc = OwnershipChecker()
  oc.oc_bindings = []
  oc.oc_scope_depth = 0
  oc.oc_errors = []
  oc.oc_warnings = []
  oc.oc_struct_map = dict()
  oc.oc_fn_consumes = dict()
  return oc
@end

@fn oc_list_contains(arr, target)
  @if arr == 0 || target == "" return 0 @end
  i = 0
  n = arr.len()
  @while i < n
    @if str_eq(arr[i], target) == 1 return 1 @end
    i = i + 1
  @end
  return 0
@end

@fn oc_record_error(oc, code, msg, span)
  sp = span
  @if sp == 0 sp = span_default() @end

  d = OwnershipDiagnostic()
  d.od_code = code
  d.od_message = msg
  d.od_span = sp
  d.od_is_warning = 0
  oc.oc_errors = oc.oc_errors.push(d)
  return 0
@end

@fn oc_record_warn(oc, code, msg, span)
  sp = span
  @if sp == 0 sp = span_default() @end

  d = OwnershipDiagnostic()
  d.od_code = code
  d.od_message = msg
  d.od_span = sp
  d.od_is_warning = 1
  oc.oc_warnings = oc.oc_warnings.push(d)
  return 0
@end

@fn oc_has_errors(oc)
  @if oc == 0 return 0 @end
  @if oc.oc_errors.len() > 0 return 1 @end
  return 0
@end

@fn oc_error_count(oc)
  @if oc == 0 return 0 @end
  return oc.oc_errors.len()
@end

// ── 3. SCOPE LIFETIME MANAGEMENT ─────────────────────────────────────────────

@fn oc_enter_scope(oc)
  oc.oc_scope_depth = oc.oc_scope_depth + 1
  return oc.oc_scope_depth
@end

@fn oc_exit_scope(oc)
  curr_depth = oc.oc_scope_depth
  oc.oc_scope_depth = oc.oc_scope_depth - 1

  new_bindings = []
  i = 0
  n = oc.oc_bindings.len()
  @while i < n
    b = oc.oc_bindings[i]
    @if b.rb_scope_depth == curr_depth
      @if b.rb_shared_borrow_count > 0 || b.rb_state == OWN_STATE_BORROWED_MUT()
        oc_record_error(oc, ERR_BORROW_OUTLIVES_SCOPE(), "Resource '" + b.rb_name + "' dropped while active borrows exist", b.rb_declared_span)
      @end
      b.rb_state = OWN_STATE_DROPPED()
    @else
      new_bindings = new_bindings.push(b)
    @end
    i = i + 1
  @end

  oc.oc_bindings = new_bindings
  return oc.oc_scope_depth
@end

// ── 4. RESOURCE LOOKUP & REGISTRATION ────────────────────────────────────────

@fn oc_declare(oc, var_name, is_copy, span)
  @if oc == 0 || var_name == "" return 0 @end

  i = 0
  n = oc.oc_bindings.len()
  @while i < n
    b = oc.oc_bindings[i]
    @if str_eq(b.rb_name, var_name) == 1 && b.rb_scope_depth == oc.oc_scope_depth
      b.rb_state = OWN_STATE_OWNED()
      b.rb_shared_borrow_count = 0
      return 1
    @end
    i = i + 1
  @end

  b = binding_new(var_name, is_copy, oc.oc_scope_depth, span)
  oc.oc_bindings = oc.oc_bindings.push(b)
  return 1
@end

@fn oc_lookup(oc, var_name)
  @if oc == 0 || var_name == "" return 0 @end

  idx = oc.oc_bindings.len() - 1
  @while idx >= 0
    b = oc.oc_bindings[idx]
    @if str_eq(b.rb_name, var_name) == 1
      return b
    @end
    idx = idx - 1
  @end

  return 0
@end

// ── 5. MOVE SEMANTICS & BORROW CHECKING RULES ────────────────────────────────

@fn oc_check_read(oc, var_name, span)
  b = oc_lookup(oc, var_name)
  @if b == 0 return 1 @end

  @if b.rb_state == OWN_STATE_MOVED()
    oc_record_error(oc, ERR_USE_AFTER_MOVE(), "Use of moved value: '" + var_name + "' was previously moved at " + span_to_string(b.rb_moved_span), span)
    return 0
  @end

  @if b.rb_state == OWN_STATE_UNINITIALIZED()
    oc_record_error(oc, ERR_USE_OF_UNINITIALIZED(), "Use of uninitialized variable '" + var_name + "'", span)
    return 0
  @end

  return 1
@end

@fn oc_check_write(oc, var_name, span)
  b = oc_lookup(oc, var_name)
  @if b == 0 return 1 @end

  @if b.rb_shared_borrow_count > 0 || b.rb_state == OWN_STATE_BORROWED_SHARED()
    oc_record_error(oc, ERR_MUTATE_WHILE_BORROWED(), "Cannot assign to '" + var_name + "' because it is borrowed as shared (&)", span)
    return 0
  @end

  @if b.rb_state == OWN_STATE_BORROWED_MUT()
    oc_record_error(oc, ERR_MUTATE_WHILE_BORROWED(), "Cannot assign to '" + var_name + "' because it is already mutably borrowed (&mut)", span)
    return 0
  @end

  @if b.rb_state == OWN_STATE_MOVED()
    b.rb_state = OWN_STATE_OWNED()
  @end

  return 1
@end

@fn oc_mark_move(oc, var_name, span)
  b = oc_lookup(oc, var_name)
  @if b == 0 return 1 @end

  @if b.rb_is_copy == 1
    return 1
  @end

  @if b.rb_state == OWN_STATE_MOVED()
    oc_record_error(oc, ERR_USE_AFTER_MOVE(), "Attempt to move already-moved value: '" + var_name + "'", span)
    return 0
  @end

  @if b.rb_shared_borrow_count > 0 || b.rb_state == OWN_STATE_BORROWED_SHARED() || b.rb_state == OWN_STATE_BORROWED_MUT()
    oc_record_error(oc, ERR_MOVE_WHILE_BORROWED(), "Cannot move out of '" + var_name + "' because it is currently borrowed", span)
    return 0
  @end

  b.rb_state = OWN_STATE_MOVED()
  sp = span
  @if sp == 0 sp = span_default() @end
  b.rb_moved_span = sp
  return 1
@end

@fn oc_borrow_shared(oc, var_name, span)
  b = oc_lookup(oc, var_name)
  @if b == 0 return 1 @end

  @if b.rb_state == OWN_STATE_MOVED()
    oc_record_error(oc, ERR_USE_AFTER_MOVE(), "Cannot borrow moved value '" + var_name + "'", span)
    return 0
  @end

  @if b.rb_state == OWN_STATE_BORROWED_MUT()
    oc_record_error(oc, ERR_SHARED_BORROW_CONFLICT(), "Cannot borrow '" + var_name + "' as shared (&) because it is already borrowed as mutable (&mut)", span)
    return 0
  @end

  b.rb_shared_borrow_count = b.rb_shared_borrow_count + 1
  b.rb_state = OWN_STATE_BORROWED_SHARED()
  return 1
@end

@fn oc_borrow_mut(oc, var_name, span)
  b = oc_lookup(oc, var_name)
  @if b == 0 return 1 @end

  @if b.rb_state == OWN_STATE_MOVED()
    oc_record_error(oc, ERR_USE_AFTER_MOVE(), "Cannot mutably borrow moved value '" + var_name + "'", span)
    return 0
  @end

  @if b.rb_shared_borrow_count > 0 || b.rb_state == OWN_STATE_BORROWED_SHARED()
    oc_record_error(oc, ERR_MUT_BORROW_CONFLICT(), "Cannot borrow '" + var_name + "' as mutable (&mut) because it is already borrowed as shared (&)", span)
    return 0
  @end

  @if b.rb_state == OWN_STATE_BORROWED_MUT()
    oc_record_error(oc, ERR_MUT_BORROW_CONFLICT(), "Cannot borrow '" + var_name + "' as mutable (&mut) more than once at a time", span)
    return 0
  @end

  b.rb_state = OWN_STATE_BORROWED_MUT()
  return 1
@end

@fn oc_release_borrow(oc, var_name)
  b = oc_lookup(oc, var_name)
  @if b == 0 return 1 @end

  @if b.rb_state == OWN_STATE_BORROWED_MUT()
    b.rb_state = OWN_STATE_OWNED()
    return 1
  @end

  @if b.rb_shared_borrow_count > 0
    b.rb_shared_borrow_count = b.rb_shared_borrow_count - 1
    @if b.rb_shared_borrow_count == 0
      b.rb_state = OWN_STATE_OWNED()
    @end
  @end

  return 1
@end

// ── 6. AST STATEMENT & EXPRESSION OWNERSHIP ANALYSIS PASS ─────────────────────

@fn oc_force_move(oc, var_name, span)
  // WHY: Explicit affine ownership transfer triggered by `move(x)` or `drop(x)` / `free(x)`.
  b = oc_lookup(oc, var_name)
  @if b == 0 return 1 @end
  @if b.rb_state == OWN_STATE_MOVED()
    oc_record_error(oc, ERR_USE_AFTER_MOVE(), "Attempt to move or drop already-moved value: '" + var_name + "'", span)
    return 0
  @end
  @if b.rb_shared_borrow_count > 0 || b.rb_state == OWN_STATE_BORROWED_SHARED() || b.rb_state == OWN_STATE_BORROWED_MUT()
    oc_record_error(oc, ERR_MOVE_WHILE_BORROWED(), "Cannot move out of '" + var_name + "' because it is currently borrowed", span)
    return 0
  @end
  b.rb_state = OWN_STATE_MOVED()
  sp = span
  @if sp == 0 sp = span_default() @end
  b.rb_moved_span = sp
  return 1
@end

@fn oc_expr_is_owned_alloc(expr)
  // WHY: Identifies raw heap allocator & owned handle constructor expressions that confer non-Copy affine ownership.
  @if expr == 0 return 0 @end
  @if str_eq(expr.kind, "StructLit") == 1
    return 1
  @end
  @if str_eq(expr.kind, "Call") == 1 || str_eq(expr.kind, "CallExpr") == 1
    cn = ""
    @if expr.func != 0 && (str_eq(expr.func.kind, "Variable") == 1 || str_eq(expr.func.kind, "IDENT") == 1 || str_eq(expr.func.kind, "Identifier") == 1)
      cn = expr.func.name
    @end
    @if cn == "" && expr.callee != 0 cn = expr.callee.name @end
    @if cn == "" cn = expr.name @end
    @if str_eq(cn, "alloc") == 1 || str_eq(cn, "malloc") == 1 || str_eq(cn, "sys_alloc") == 1 || str_eq(cn, "sys_mmap") == 1 || str_eq(cn, "mem_alloc") == 1 || str_eq(cn, "slab_alloc") == 1 || str_eq(cn, "heap_alloc") == 1 || str_eq(cn, "buffer_alloc") == 1 || str_eq(cn, "buf_new") == 1 || str_eq(cn, "byte_buf_new") == 1 || str_eq(cn, "বরাদ্দ") == 1 || str_eq(cn, "মেমরি_বরাদ্দ") == 1 || str_eq(cn, "বাফার_তৈরি") == 1
      return 1
    @end
  @end
  return 0
@end

@fn oc_expr_is_owned_with_ctx(oc, expr)
  // WHY: Recognizes heap allocations, anonymous struct literals, AND user-defined struct constructors as non-Copy affine values.
  @if oc_expr_is_owned_alloc(expr) == 1 return 1 @end
  @if oc == 0 || expr == 0 return 0 @end
  @if str_eq(expr.kind, "Call") == 1 || str_eq(expr.kind, "CallExpr") == 1
    cn = ""
    @if expr.func != 0 && (str_eq(expr.func.kind, "Variable") == 1 || str_eq(expr.func.kind, "IDENT") == 1 || str_eq(expr.func.kind, "Identifier") == 1)
      cn = expr.func.name
    @end
    @if cn == "" && expr.callee != 0 cn = expr.callee.name @end
    @if cn == "" cn = expr.name @end
    @if cn != "" && oc.oc_struct_map != 0 && has_key(oc.oc_struct_map, cn) == 1
      return 1
    @end
  @end
  return 0
@end

@fn oc_extract_root_var(name)
  @if name == "" return "" @end
  i = 0
  n = len(name)
  @while i < n
    c = str_char_at(name, i)
    @if c == 46 || c == 91
      return str_slice(name, 0, i)
    @end
    i = i + 1
  @end
  return name
@end

@fn oc_is_direct_consumer(cname)
  @if cname == "" return 0 @end
  @if str_eq(cname, "move") == 1 || str_eq(cname, "drop") == 1 || str_eq(cname, "free") == 1 || str_eq(cname, "user_free") == 1 || str_eq(cname, "_lipi_user_free") == 1 || str_eq(cname, "mem_free") == 1 || str_eq(cname, "sys_free") == 1 || str_eq(cname, "buf_free") == 1 || str_eq(cname, "list_free") == 1 || str_eq(cname, "heap_free") == 1 || str_eq(cname, "slab_free") == 1 || str_eq(cname, "munmap") == 1 || str_eq(cname, "sys_munmap") == 1 || str_eq(cname, "মুক্ত") == 1 || str_eq(cname, "মেমরি_মুক্তি") == 1 || str_eq(cname, "বাফার_মুক্তি") == 1
    return 1
  @end
  return 0
@end

@fn oc_origin_clone(orig_d, orig_k)
  nd = dict()
  nk = []
  i = 0
  @while i < orig_k.len()
    ky = orig_k[i]
    nd[ky] = orig_d[ky]
    nk = nk.push(ky)
    i = i + 1
  @end
  return [nd, nk]
@end

@fn oc_origin_merge_may(dst_d, dst_k, src_d, src_k)
  // WHY: Conservative may-consume join across branches: preserves existing positive parameter
  // origins (so `if c { p = 0 }; free(p)` still sees `p` as origin) and imports new branch aliases.
  i = 0
  @while i < src_k.len()
    ky = src_k[i]
    @if has_key(src_d, ky) == 1 && src_d[ky] > 0
      @if has_key(dst_d, ky) == 0 || dst_d[ky] == 0
        @if has_key(dst_d, ky) == 0
          push(dst_k, ky)
        @end
        dst_d[ky] = src_d[ky]
      @end
    @end
    i = i + 1
  @end
  return 0
@end

@fn oc_extract_callee_name(expr)
  @if expr == 0 return "" @end
  cn = ""
  @if expr.func != 0
    fk = expr.func.kind
    @if str_eq(fk, "Variable") == 1 || str_eq(fk, "IDENT") == 1 || str_eq(fk, "Identifier") == 1 || str_eq(fk, "MemberAccess") == 1 || str_eq(fk, "FieldAccess") == 1
      cn = expr.func.name
    @end
  @elif expr.callee != 0
    cn = expr.callee.name
  @end
  @if cn == "" cn = expr.name @end
  return cn
@end

@fn oc_scan_expr_consumes(oc, expr, param_origin, flags)
  // WHY: Scans an expression inside a function body to detect whether any parameter
  // (or local alias of a parameter) flows into a consuming builtin or consuming user helper.
  @if expr == 0 return 0 @end
  changed = 0
  k = expr.kind
  @if str_eq(k, "ExprStmt") == 1 || str_eq(k, "ExpressionStmt") == 1
    return oc_scan_expr_consumes(oc, expr.expr, param_origin, flags)
  @end
  @if str_eq(k, "Call") == 1 || str_eq(k, "CallExpr") == 1
    cname = oc_extract_callee_name(expr)
    call_args = expr.args
    @if call_args == 0 call_args = expr.params @end
    @if oc_is_direct_consumer(cname) == 1 && call_args != 0 && call_args.len() >= 1
      a0 = call_args[0]
      @if a0 != 0 && (str_eq(a0.kind, "Variable") == 1 || str_eq(a0.kind, "IDENT") == 1 || str_eq(a0.kind, "Identifier") == 1)
        an = a0.name
        @if an == "" an = a0.target @end
        @if an != "" && has_key(param_origin, an) == 1
          orig_p = param_origin[an]
          @if orig_p > 0
            pidx = orig_p - 1
            @if pidx < flags.len() && flags[pidx] == 0
              list_set(flags, pidx, 1)
              changed = 1
            @end
          @end
        @end
      @end
    @elif cname != "" && oc.oc_fn_consumes != 0 && has_key(oc.oc_fn_consumes, cname) == 1 && call_args != 0
      callee_flags = oc.oc_fn_consumes[cname]
      ai = 0
      @while ai < call_args.len() && ai < callee_flags.len()
        @if callee_flags[ai] == 1
          arg_n = call_args[ai]
          @if arg_n != 0 && (str_eq(arg_n.kind, "Variable") == 1 || str_eq(arg_n.kind, "IDENT") == 1 || str_eq(arg_n.kind, "Identifier") == 1)
            an2 = arg_n.name
            @if an2 == "" an2 = arg_n.target @end
            @if an2 != "" && has_key(param_origin, an2) == 1
              orig_p2 = param_origin[an2]
              @if orig_p2 > 0
                pidx2 = orig_p2 - 1
                @if pidx2 < flags.len() && flags[pidx2] == 0
                  list_set(flags, pidx2, 1)
                  changed = 1
                @end
              @end
            @end
          @end
        @end
        ai = ai + 1
      @end
    @end
    @if call_args != 0
      ci = 0
      @while ci < call_args.len()
        @if oc_scan_expr_consumes(oc, call_args[ci], param_origin, flags) == 1 changed = 1 @end
        ci = ci + 1
      @end
    @end
    return changed
  @end
  @if str_eq(k, "Binary") == 1 || str_eq(k, "BinaryExpr") == 1 || str_eq(k, "BinaryOp") == 1
    @if oc_scan_expr_consumes(oc, expr.left, param_origin, flags) == 1 changed = 1 @end
    @if oc_scan_expr_consumes(oc, expr.right, param_origin, flags) == 1 changed = 1 @end
    return changed
  @end
  @if str_eq(k, "Unary") == 1 || str_eq(k, "UnaryOp") == 1
    return oc_scan_expr_consumes(oc, expr.expr, param_origin, flags)
  @end
  @if str_eq(k, "Index") == 1 || str_eq(k, "Member") == 1 || str_eq(k, "MemberAccess") == 1
    @if oc_scan_expr_consumes(oc, expr.left, param_origin, flags) == 1 changed = 1 @end
    @if expr.right != 0 && oc_scan_expr_consumes(oc, expr.right, param_origin, flags) == 1 changed = 1 @end
    @if expr.index != 0 && oc_scan_expr_consumes(oc, expr.index, param_origin, flags) == 1 changed = 1 @end
    return changed
  @end
  @if str_eq(k, "Field") == 1
    @if expr.value != 0 && oc_scan_expr_consumes(oc, expr.value, param_origin, flags) == 1 changed = 1 @end
    @if expr.expr != 0 && oc_scan_expr_consumes(oc, expr.expr, param_origin, flags) == 1 changed = 1 @end
    return changed
  @end
  @if str_eq(k, "ArrayLit") == 1 || str_eq(k, "MapLit") == 1 || str_eq(k, "StructLit") == 1
    @if expr.elements != 0
      ei = 0
      @while ei < expr.elements.len()
        @if oc_scan_expr_consumes(oc, expr.elements[ei], param_origin, flags) == 1 changed = 1 @end
        ei = ei + 1
      @end
    @end
    return changed
  @end
  return changed
@end

@fn oc_scan_stmts_consumes(oc, stmts, param_origin, origin_keys, flags)
  @if stmts == 0 return 0 @end
  changed = 0
  i = 0
  n = stmts.len()
  @while i < n
    st = stmts[i]
    @if st != 0
      k = st.kind
      @if str_eq(k, "Assign") == 1 || str_eq(k, "AssignOp") == 1
        @if st.index != 0 && oc_scan_expr_consumes(oc, st.index, param_origin, flags) == 1 changed = 1 @end
        val_n = st.value
        @if val_n == 0 val_n = st.expr @end
        @if oc_scan_expr_consumes(oc, val_n, param_origin, flags) == 1 changed = 1 @end
        tgt = st.target
        @if str_eq(k, "Assign") == 1 && st.index == 0 && tgt != "" && str_contains(tgt, ".") == 0 && str_contains(tgt, "[") == 0
          @if has_key(param_origin, tgt) == 0
            push(origin_keys, tgt)
          @end
          @if val_n != 0 && (str_eq(val_n.kind, "Variable") == 1 || str_eq(val_n.kind, "IDENT") == 1 || str_eq(val_n.kind, "Identifier") == 1)
            rvn = val_n.name
            @if rvn == "" rvn = val_n.target @end
            @if rvn != "" && has_key(param_origin, rvn) == 1 && param_origin[rvn] > 0
              param_origin[tgt] = param_origin[rvn]
            @else
              param_origin[tgt] = 0
            @end
          @else
            param_origin[tgt] = 0
          @end
        @end
      @elif str_eq(k, "ExprStmt") == 1 || str_eq(k, "ExpressionStmt") == 1 || str_eq(k, "Call") == 1 || str_eq(k, "CallExpr") == 1
        @if oc_scan_expr_consumes(oc, st, param_origin, flags) == 1 changed = 1 @end
      @elif str_eq(k, "Print") == 1 || str_eq(k, "Say") == 1 || str_eq(k, "Return") == 1 || str_eq(k, "ফেরত") == 1
        @if st.expr != 0 && oc_scan_expr_consumes(oc, st.expr, param_origin, flags) == 1 changed = 1 @end
        @if st.value != 0 && oc_scan_expr_consumes(oc, st.value, param_origin, flags) == 1 changed = 1 @end
        @if st.args != 0
          pai = 0
          @while pai < st.args.len()
            @if oc_scan_expr_consumes(oc, st.args[pai], param_origin, flags) == 1 changed = 1 @end
            pai = pai + 1
          @end
        @end
      @elif str_eq(k, "Defer") == 1
        @if st.expr != 0 && oc_scan_expr_consumes(oc, st.expr, param_origin, flags) == 1 changed = 1 @end
        dc = oc_origin_clone(param_origin, origin_keys)
        @if oc_scan_stmts_consumes(oc, st.body, dc[0], dc[1], flags) == 1 changed = 1 @end
        oc_origin_merge_may(param_origin, origin_keys, dc[0], dc[1])
      @elif str_eq(k, "While") == 1 || str_eq(k, "WhileLoop") == 1 || str_eq(k, "যতক্ষণ") == 1
        @if st.condition != 0 && oc_scan_expr_consumes(oc, st.condition, param_origin, flags) == 1 changed = 1 @end
        wc = oc_origin_clone(param_origin, origin_keys)
        @if oc_scan_stmts_consumes(oc, st.body, wc[0], wc[1], flags) == 1 changed = 1 @end
        oc_origin_merge_may(param_origin, origin_keys, wc[0], wc[1])
      @elif str_eq(k, "For") == 1 || str_eq(k, "ForLoop") == 1 || str_eq(k, "প্রতিটি") == 1
        @if st.iterable != 0 && oc_scan_expr_consumes(oc, st.iterable, param_origin, flags) == 1 changed = 1 @end
        fc = oc_origin_clone(param_origin, origin_keys)
        @if oc_scan_stmts_consumes(oc, st.body, fc[0], fc[1], flags) == 1 changed = 1 @end
        oc_origin_merge_may(param_origin, origin_keys, fc[0], fc[1])
      @elif str_eq(k, "Block") == 1
        @if oc_scan_stmts_consumes(oc, st.body, param_origin, origin_keys, flags) == 1 changed = 1 @end
        @if oc_scan_stmts_consumes(oc, st.then_body, param_origin, origin_keys, flags) == 1 changed = 1 @end
      @elif str_eq(k, "If") == 1 || str_eq(k, "IfStmt") == 1 || str_eq(k, "যদি") == 1 || str_eq(k, "TryCatch") == 1 || str_eq(k, "Try") == 1
        @if st.condition != 0 && oc_scan_expr_consumes(oc, st.condition, param_origin, flags) == 1 changed = 1 @end
        tc = oc_origin_clone(param_origin, origin_keys)
        ec = oc_origin_clone(param_origin, origin_keys)
        @if oc_scan_stmts_consumes(oc, st.then_body, tc[0], tc[1], flags) == 1 changed = 1 @end
        @if oc_scan_stmts_consumes(oc, st.else_body, ec[0], ec[1], flags) == 1 changed = 1 @end
        oc_origin_merge_may(param_origin, origin_keys, tc[0], tc[1])
        oc_origin_merge_may(param_origin, origin_keys, ec[0], ec[1])
        @if st.body != 0
          bc = oc_origin_clone(param_origin, origin_keys)
          @if oc_scan_stmts_consumes(oc, st.body, bc[0], bc[1], flags) == 1 changed = 1 @end
          oc_origin_merge_may(param_origin, origin_keys, bc[0], bc[1])
        @end
      @elif str_eq(k, "MatchStmt") == 1 || str_eq(k, "Match") == 1
        @if st.left != 0 && oc_scan_expr_consumes(oc, st.left, param_origin, flags) == 1 changed = 1 @end
        @if st.elements != 0
          mc = oc_origin_clone(param_origin, origin_keys)
          @if oc_scan_stmts_consumes(oc, st.elements, mc[0], mc[1], flags) == 1 changed = 1 @end
          oc_origin_merge_may(param_origin, origin_keys, mc[0], mc[1])
        @end
      @end
    @end
    i = i + 1
  @end
  return changed
@end

@fn oc_build_fn_consume_summaries(oc, stmts)
  // WHY: Fixed-point inter-procedural parameter-consumption summary (`consumes_param[i]`).
  // Catches custom wrapper destructors (`fn my_free p { free(p) }` and transitive wrappers)
  // at call sites while keeping borrow-by-default for non-freeing helpers (`silicon_seal`, `mem_zero`).
  @if oc == 0 || stmts == 0 return 0 @end
  fn_list = []
  i = 0
  n = stmts.len()
  @while i < n
    st = stmts[i]
    @if st != 0
      k = st.kind
      @if (str_eq(k, "FnDef") == 1 || str_eq(k, "Function") == 1 || str_eq(k, "কাজ") == 1 || str_eq(k, "Component") == 1) && st.name != ""
        flags = []
        @if st.params != 0
          pi = 0
          @while pi < st.params.len()
            flags = flags.push(0)
            pi = pi + 1
          @end
        @end
        oc.oc_fn_consumes[st.name] = flags
        fn_list = fn_list.push(st)
      @end
    @end
    i = i + 1
  @end
  pass_num = 0
  @while pass_num < 8
    any_changed = 0
    fi = 0
    @while fi < fn_list.len()
      fd = fn_list[fi]
      flags = oc.oc_fn_consumes[fd.name]
      @if fd.params != 0 && fd.params.len() > 0 && fd.body != 0
        param_origin = dict()
        origin_keys = []
        pi2 = 0
        @while pi2 < fd.params.len()
          pm = fd.params[pi2]
          pn = pm.param_name
          @if pn == "" pn = pm.name @end
          @if pn != ""
            param_origin[pn] = pi2 + 1
            origin_keys = origin_keys.push(pn)
          @end
          pi2 = pi2 + 1
        @end
        @if oc_scan_stmts_consumes(oc, fd.body, param_origin, origin_keys, flags) == 1
          any_changed = 1
        @end
      @end
      fi = fi + 1
    @end
    @if any_changed == 0
      break
    @end
    pass_num = pass_num + 1
  @end
  return 1
@end

@fn oc_analyze_expr(oc, expr)
  @if expr == 0 return 1 @end
  k = expr.kind
  @if str_eq(k, "Variable") == 1 || str_eq(k, "IDENT") == 1 || str_eq(k, "Identifier") == 1
    vname = expr.name
    @if vname == "" vname = expr.target @end
    oc_check_read(oc, vname, span_default())
    return 1
  @end
  @if str_eq(k, "ExprStmt") == 1 || str_eq(k, "ExpressionStmt") == 1
    return oc_analyze_expr(oc, expr.expr)
  @end
  @if str_eq(k, "Call") == 1 || str_eq(k, "CallExpr") == 1
    cname = ""
    @if expr.func != 0
      fk_o = expr.func.kind
      @if str_eq(fk_o, "Variable") == 1 || str_eq(fk_o, "IDENT") == 1 || str_eq(fk_o, "Identifier") == 1
        cname = expr.func.name
      @elif str_eq(fk_o, "MemberAccess") == 1 || str_eq(fk_o, "FieldAccess") == 1
        cname = expr.func.name
        oc_analyze_expr(oc, expr.func)
      @else
        // Indirect call callee (e.g. `fns[0](10)`): check callee expression for moved reads
        oc_analyze_expr(oc, expr.func)
      @end
    @elif expr.callee != 0
      cname = expr.callee.name
    @end
    @if cname == "" cname = expr.name @end
    call_args = expr.args
    @if call_args == 0 call_args = expr.params @end
    @if oc_is_direct_consumer(cname) == 1 && call_args != 0 && call_args.len() >= 1
      a0 = call_args[0]
      @if a0 != 0 && (str_eq(a0.kind, "Variable") == 1 || str_eq(a0.kind, "IDENT") == 1 || str_eq(a0.kind, "Identifier") == 1)
        aname = a0.name
        @if aname == "" aname = a0.target @end
        oc_check_read(oc, aname, span_default())
        oc_force_move(oc, aname, span_default())
        @if call_args.len() > 1
          pi2 = 1
          @while pi2 < call_args.len()
            oc_analyze_expr(oc, call_args[pi2])
            pi2 = pi2 + 1
          @end
        @end
        return 1
      @end
    @end
    // Inter-procedural consuming wrapper propagation: order-independent aliasing check + consumes_param[i] move
    @if cname != "" && oc.oc_fn_consumes != 0 && has_key(oc.oc_fn_consumes, cname) == 1 && call_args != 0
      c_flags = oc.oc_fn_consumes[cname]
      // Phase 1: Check all arguments for reads & detect aliasing between consumed and borrowed positions
      consumed_names = []
      consumed_idxs = []
      pi_c = 0
      @while pi_c < call_args.len()
        arg_c = call_args[pi_c]
        is_cvar = 0
        @if pi_c < c_flags.len() && c_flags[pi_c] == 1 && arg_c != 0 && (str_eq(arg_c.kind, "Variable") == 1 || str_eq(arg_c.kind, "IDENT") == 1 || str_eq(arg_c.kind, "Identifier") == 1)
          an_c = arg_c.name
          @if an_c == "" an_c = arg_c.target @end
          oc_check_read(oc, an_c, span_default())
          consumed_names = consumed_names.push(an_c)
          consumed_idxs = consumed_idxs.push(pi_c)
          is_cvar = 1
        @end
        @if is_cvar == 0
          oc_analyze_expr(oc, arg_c)
        @end
        pi_c = pi_c + 1
      @end
      // Detect order-independent aliasing: `wf(x, x)` where one arg consumes `x` and another borrows/uses `x`
      ci_a = 0
      @while ci_a < consumed_names.len()
        cn_a = consumed_names[ci_a]
        cidx_a = consumed_idxs[ci_a]
        @if oc_lookup(oc, cn_a) != 0
          pi_b = 0
          @while pi_b < call_args.len()
            @if pi_b != cidx_a && (pi_b >= c_flags.len() || c_flags[pi_b] == 0)
              arg_b = call_args[pi_b]
              @if arg_b != 0 && (str_eq(arg_b.kind, "Variable") == 1 || str_eq(arg_b.kind, "IDENT") == 1 || str_eq(arg_b.kind, "Identifier") == 1)
                bn_a = arg_b.name
                @if bn_a == "" bn_a = arg_b.target @end
                @if str_eq(bn_a, cn_a) == 1
                  oc_record_error(oc, ERR_USE_AFTER_MOVE(), "Aliasing use of value '" + cn_a + "' passed both as consumed and borrowed argument in call to '" + cname + "'", span_default())
                @end
              @end
            @end
            pi_b = pi_b + 1
          @end
        @end
        ci_a = ci_a + 1
      @end
      // Phase 2: Move all consumed variable arguments
      ci_m = 0
      @while ci_m < consumed_names.len()
        oc_force_move(oc, consumed_names[ci_m], span_default())
        ci_m = ci_m + 1
      @end
      return 1
    @end
    @if call_args != 0
      pi = 0
      @while pi < call_args.len()
        oc_analyze_expr(oc, call_args[pi])
        pi = pi + 1
      @end
    @end
    return 1
  @end
  @if str_eq(k, "Binary") == 1 || str_eq(k, "BinaryExpr") == 1 || str_eq(k, "BinaryOp") == 1
    oc_analyze_expr(oc, expr.left)
    oc_analyze_expr(oc, expr.right)
    return 1
  @end
  @if str_eq(k, "Unary") == 1 || str_eq(k, "UnaryOp") == 1
    @if (str_eq(expr.op, "&") == 1 || str_eq(expr.op, "&mut") == 1) && expr.expr != 0
      inner = expr.expr
      @if str_eq(inner.kind, "Variable") == 1 || str_eq(inner.kind, "IDENT") == 1 || str_eq(inner.kind, "Identifier") == 1
        bn = inner.name
        @if bn == "" bn = inner.target @end
        oc_check_read(oc, bn, span_default())
        @if str_eq(expr.op, "&mut") == 1
          oc_borrow_mut(oc, bn, span_default())
        @else
          oc_borrow_shared(oc, bn, span_default())
        @end
        oc_release_borrow(oc, bn)
        return 1
      @end
    @end
    oc_analyze_expr(oc, expr.expr)
    return 1
  @end
  @if str_eq(k, "Index") == 1 || str_eq(k, "Member") == 1 || str_eq(k, "MemberAccess") == 1
    oc_analyze_expr(oc, expr.left)
    @if expr.right != 0 oc_analyze_expr(oc, expr.right) @end
    @if expr.index != 0 oc_analyze_expr(oc, expr.index) @end
    return 1
  @end
  @if str_eq(k, "Field") == 1
    @if expr.value != 0 oc_analyze_expr(oc, expr.value) @end
    @if expr.expr != 0 oc_analyze_expr(oc, expr.expr) @end
    return 1
  @end
  @if str_eq(k, "ArrayLit") == 1 || str_eq(k, "MapLit") == 1 || str_eq(k, "StructLit") == 1
    @if expr.elements != 0
      ei = 0
      @while ei < expr.elements.len()
        oc_analyze_expr(oc, expr.elements[ei])
        ei = ei + 1
      @end
    @end
    return 1
  @end
  @if str_eq(k, "Closure") == 1
    oc_enter_scope(oc)
    @if expr.params != 0
      pi = 0
      @while pi < expr.params.len()
        pm = expr.params[pi]
        pname = pm.param_name
        @if pname == "" pname = pm.name @end
        @if pname != "" oc_declare(oc, pname, 1, span_default()) @end
        pi = pi + 1
      @end
    @end
    oc_analyze_stmt_list(oc, expr.body)
    oc_exit_scope(oc)
    return 1
  @end
  return 1
@end

@fn oc_analyze_stmt_list(oc, stmts)
  @if stmts == 0 return 1 @end
  // Pre-register top-level StructDef declarations and build inter-procedural parameter-consumption summaries
  @if oc.oc_scope_depth == 0
    pi0 = 0
    n0 = stmts.len()
    @while pi0 < n0
      st0 = stmts[pi0]
      @if st0 != 0
        k0 = st0.kind
        @if (str_eq(k0, "StructDef") == 1 || str_eq(k0, "Struct") == 1 || str_eq(k0, "গঠন") == 1) && st0.name != ""
          oc.oc_struct_map[st0.name] = 1
        @end
      @end
      pi0 = pi0 + 1
    @end
    oc_build_fn_consume_summaries(oc, stmts)
  @end
  i = 0
  n = stmts.len()
  @while i < n
    oc_analyze_statement(oc, stmts[i])
    i = i + 1
  @end
  return 1
@end

@fn oc_snapshot_states(oc)
  // WHY: Captures current moved/borrow state for each binding before branching control flow.
  snap = []
  i = 0
  n = oc.oc_bindings.len()
  @while i < n
    b = oc.oc_bindings[i]
    snap = snap.push(b.rb_state)
    i = i + 1
  @end
  return snap
@end

@fn oc_restore_states(oc, snap)
  // WHY: Restores prior binding states across mutually exclusive control-flow branches.
  i = 0
  n = snap.len()
  @if oc.oc_bindings.len() < n n = oc.oc_bindings.len() @end
  @while i < n
    b = oc.oc_bindings[i]
    b.rb_state = snap[i]
    i = i + 1
  @end
  return 1
@end

@fn oc_block_terminates(stmts)
  // WHY: Detects unconditional early-exit blocks (`return`, `break`, `continue`) so fallthrough
  // after `if cond { free(x); return }` does not falsely treat `x` as moved on the normal path.
  @if stmts == 0 || stmts.len() == 0 return 0 @end
  last = stmts[stmts.len() - 1]
  @if last == 0 return 0 @end
  lk = last.kind
  @if str_eq(lk, "Return") == 1 || str_eq(lk, "ফেরত") == 1 || str_eq(lk, "Break") == 1 || str_eq(lk, "Continue") == 1
    return 1
  @end
  @if str_eq(lk, "If") == 1 || str_eq(lk, "IfStmt") == 1 || str_eq(lk, "যদি") == 1
    @if last.else_body != 0 && last.else_body.len() > 0
      @if oc_block_terminates(last.then_body) == 1 && oc_block_terminates(last.else_body) == 1
        return 1
      @end
    @end
  @end
  return 0
@end

@fn oc_analyze_statement(oc, stmt)
  @if stmt == 0 return 1 @end

  k = stmt.kind

  // 0. Struct Definition: register struct name as non-Copy owned type
  @if str_eq(k, "StructDef") == 1 || str_eq(k, "Struct") == 1 || str_eq(k, "গঠন") == 1
    @if stmt.name != ""
      oc.oc_struct_map[stmt.name] = 1
    @end
    return 1
  @end

  // 1. Function Definition: create isolated function scope
  @if str_eq(k, "FnDef") == 1 || str_eq(k, "Function") == 1 || str_eq(k, "কাজ") == 1 || str_eq(k, "Component") == 1
    oc_enter_scope(oc)
    @if stmt.params != 0
      pi = 0
      @while pi < stmt.params.len()
        pm = stmt.params[pi]
        pname = pm.param_name
        @if pname == "" pname = pm.name @end
        @if pname != "" oc_declare(oc, pname, 1, span_default()) @end
        pi = pi + 1
      @end
    @end
    oc_analyze_stmt_list(oc, stmt.body)
    oc_exit_scope(oc)
    return 1
  @end

  // 2. Assignment & Compound Assignment: target = value, target <op>= value
  @if str_eq(k, "Assign") == 1 || str_eq(k, "AssignOp") == 1
    @if stmt.index != 0
      oc_analyze_expr(oc, stmt.index)
    @end
    target = stmt.target
    val_node = stmt.value
    @if val_node == 0 val_node = stmt.expr @end

    // Detect alias move: q = p when p holds a non-Copy owned heap handle or struct
    move_src = ""
    rhs_is_copy = 1
    @if oc_expr_is_owned_with_ctx(oc, val_node) == 1
      rhs_is_copy = 0
    @elif str_eq(k, "Assign") == 1 && val_node != 0 && (str_eq(val_node.kind, "Variable") == 1 || str_eq(val_node.kind, "IDENT") == 1 || str_eq(val_node.kind, "Identifier") == 1)
      rhs_vn = val_node.name
      @if rhs_vn == "" rhs_vn = val_node.target @end
      rb_src = oc_lookup(oc, rhs_vn)
      @if rb_src != 0 && rb_src.rb_is_copy == 0
        move_src = rhs_vn
        rhs_is_copy = 0
      @end
    @end

    oc_analyze_expr(oc, val_node)
    @if move_src != "" && str_eq(move_src, target) == 0
      oc_mark_move(oc, move_src, span_default())
    @end

    @if stmt.index != 0 || str_contains(target, ".") == 1 || str_contains(target, "[") == 1
      root_t = oc_extract_root_var(target)
      rb_root = oc_lookup(oc, root_t)
      @if rb_root != 0
        oc_check_read(oc, root_t, span_default())
        @if rb_root.rb_shared_borrow_count > 0 || rb_root.rb_state == OWN_STATE_BORROWED_SHARED()
          oc_record_error(oc, ERR_MUTATE_WHILE_BORROWED(), "Cannot mutate '" + root_t + "' through field/index while borrowed", span_default())
        @end
      @end
      return 1
    @end

    b = oc_lookup(oc, target)
    @if b == 0
      oc_declare(oc, target, rhs_is_copy, span_default())
    @else
      oc_check_write(oc, target, span_default())
      b.rb_is_copy = rhs_is_copy
    @end
    return 1
  @end

  // 3. Expression statement / Call
  @if str_eq(k, "ExprStmt") == 1 || str_eq(k, "ExpressionStmt") == 1 || str_eq(k, "Call") == 1 || str_eq(k, "CallExpr") == 1 || str_eq(k, "Variable") == 1 || str_eq(k, "IDENT") == 1
    oc_analyze_expr(oc, stmt)
    return 1
  @end

  // 4. Return / Defer statements
  @if str_eq(k, "Return") == 1 || str_eq(k, "ফেরত") == 1
    @if stmt.expr != 0 oc_analyze_expr(oc, stmt.expr) @end
    @if stmt.value != 0 oc_analyze_expr(oc, stmt.value) @end
    return 1
  @end

  @if str_eq(k, "Defer") == 1
    @if stmt.expr != 0 oc_analyze_expr(oc, stmt.expr) @end
    oc_analyze_stmt_list(oc, stmt.body)
    return 1
  @end

  // 5. While / For / Block / If scopes
  @if str_eq(k, "While") == 1 || str_eq(k, "WhileLoop") == 1 || str_eq(k, "যতক্ষণ") == 1
    @if stmt.condition != 0 oc_analyze_expr(oc, stmt.condition) @else oc_analyze_expr(oc, stmt.expr) @end
    oc_enter_scope(oc)
    oc_analyze_stmt_list(oc, stmt.body)
    oc_analyze_stmt_list(oc, stmt.body)
    oc_exit_scope(oc)
    return 1
  @end

  @if str_eq(k, "For") == 1 || str_eq(k, "ForLoop") == 1 || str_eq(k, "প্রতিটি") == 1
    @if stmt.iterable != 0 oc_analyze_expr(oc, stmt.iterable) @else oc_analyze_expr(oc, stmt.expr) @end
    oc_enter_scope(oc)
    fvar = stmt.variable
    @if fvar == "" fvar = stmt.target @end
    @if fvar != "" oc_declare(oc, fvar, 1, span_default()) @end
    oc_analyze_stmt_list(oc, stmt.body)
    oc_analyze_stmt_list(oc, stmt.body)
    oc_exit_scope(oc)
    return 1
  @end

  @if str_eq(k, "Block") == 1 || str_eq(k, "If") == 1 || str_eq(k, "IfStmt") == 1 || str_eq(k, "যদি") == 1
    @if stmt.condition != 0 oc_analyze_expr(oc, stmt.condition) @else oc_analyze_expr(oc, stmt.expr) @end
    pre_snap = oc_snapshot_states(oc)
    oc_enter_scope(oc)
    oc_analyze_stmt_list(oc, stmt.then_body)
    oc_exit_scope(oc)
    then_terms = oc_block_terminates(stmt.then_body)
    then_snap = oc_snapshot_states(oc)

    has_else = 0
    else_terms = 0
    @if stmt.else_body != 0 && stmt.else_body.len() > 0
      has_else = 1
      oc_restore_states(oc, pre_snap)
      oc_enter_scope(oc)
      oc_analyze_stmt_list(oc, stmt.else_body)
      oc_exit_scope(oc)
      else_terms = oc_block_terminates(stmt.else_body)
    @end

    @if then_terms == 1 && has_else == 0
      // Only fallthrough path is when condition was false (pre-branch ownership intact)
      oc_restore_states(oc, pre_snap)
    @elif then_terms == 1 && else_terms == 1
      // Both branches terminate; fallthrough is unreachable
      oc_restore_states(oc, pre_snap)
    @elif then_terms == 0 && else_terms == 1
      // Only fallthrough path is from then_body
      oc_restore_states(oc, then_snap)
    @elif has_else == 1 && then_terms == 0 && else_terms == 0
      // Conservative merge: moved if moved in either path
      mi = 0
      mlen = pre_snap.len()
      @if oc.oc_bindings.len() < mlen mlen = oc.oc_bindings.len() @end
      @if then_snap.len() < mlen mlen = then_snap.len() @end
      @while mi < mlen
        @if then_snap[mi] == OWN_STATE_MOVED()
          oc.oc_bindings[mi].rb_state = OWN_STATE_MOVED()
        @end
        mi = mi + 1
      @end
    @end
    return 1
  @end

  return 1
@end
