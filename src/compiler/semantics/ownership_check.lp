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
  rb_borrows_target: string
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
  b.rb_borrows_target = ""
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
  oc_temp_borrows: array
  oc_hold_borrow_depth: i64
  oc_defer_stmts: array
  oc_defer_depths: array
  oc_fn_scope_depth: i64
@end

@fn ownership_checker_new()
  oc = OwnershipChecker()
  oc.oc_bindings = []
  oc.oc_scope_depth = 0
  oc.oc_errors = []
  oc.oc_warnings = []
  oc.oc_struct_map = dict()
  oc.oc_fn_consumes = dict()
  oc.oc_temp_borrows = []
  oc.oc_hold_borrow_depth = 0
  oc.oc_defer_stmts = []
  oc.oc_defer_depths = []
  oc.oc_fn_scope_depth = 0
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

@fn oc_exec_defer_stmt(oc, d_stmt)
  @if d_stmt == 0 return 1 @end
  @if d_stmt.expr != 0
    // WHY: Single-statement `defer stmt` stores the deferred AST statement in `d_stmt.expr`,
    // so analyze it via `oc_analyze_statement` (which handles Assign, ExprStmt, If, etc.).
    oc_analyze_statement(oc, d_stmt.expr)
  @end
  @if d_stmt.body != 0 && d_stmt.body.len() > 0
    oc_analyze_stmt_list(oc, d_stmt.body)
  @end
  return 1
@end

@fn oc_run_defers_from_depth(oc, min_depth)
  // WHY: Executes all active deferred statements in LIFO order down to `min_depth` (used before `return`).
  idx = oc.oc_defer_stmts.len() - 1
  @while idx >= 0
    @if oc.oc_defer_depths[idx] >= min_depth
      oc_exec_defer_stmt(oc, oc.oc_defer_stmts[idx])
    @end
    idx = idx - 1
  @end
  return 1
@end

@fn oc_exit_scope_mode(oc, run_defers)
  curr_depth = oc.oc_scope_depth
  // WHY: Collect & execute deferred statements registered in this scope in LIFO order
  // BEFORE popping/dropping the scope's bindings (fixing false positives on `defer free(p); use(p)`).
  scope_defers = []
  @while oc.oc_defer_stmts.len() > 0
    d_last = oc.oc_defer_stmts.len() - 1
    @if oc.oc_defer_depths[d_last] != curr_depth
      break
    @end
    scope_defers = scope_defers.push(oc.oc_defer_stmts[d_last])
    pop(oc.oc_defer_stmts)
    pop(oc.oc_defer_depths)
  @end
  @if run_defers == 1
    di = 0
    @while di < scope_defers.len()
      oc_exec_defer_stmt(oc, scope_defers[di])
      di = di + 1
    @end
  @end

  oc.oc_scope_depth = oc.oc_scope_depth - 1

  // WHY: Bindings are pushed monotonically by scope depth, so popping LIFO from the tail
  // releases borrow variables (`r = &mut x`) BEFORE checking `x` for dangling borrows!
  @while oc.oc_bindings.len() > 0
    last_idx = oc.oc_bindings.len() - 1
    b = oc.oc_bindings[last_idx]
    @if b.rb_scope_depth != curr_depth
      break
    @end
    @if b.rb_borrows_target != ""
      oc_release_borrow(oc, b.rb_borrows_target)
      b.rb_borrows_target = ""
    @end
    @if b.rb_shared_borrow_count > 0 || b.rb_state == OWN_STATE_BORROWED_MUT()
      oc_record_error(oc, ERR_BORROW_OUTLIVES_SCOPE(), "Resource '" + b.rb_name + "' dropped while active borrows exist", b.rb_declared_span)
    @end
    b.rb_state = OWN_STATE_DROPPED()
    pop(oc.oc_bindings)
  @end

  return oc.oc_scope_depth
@end

@fn oc_exit_scope(oc)
  return oc_exit_scope_mode(oc, 1)
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

  @if b.rb_state == OWN_STATE_BORROWED_MUT()
    oc_record_error(oc, ERR_MOVE_WHILE_BORROWED(), "Cannot access or move '" + var_name + "' while it is mutably borrowed (&mut)", span)
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
    m_oc_s = arena_mark()
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
      @if (fi % 16) == 0
        param_origin = 0
        origin_keys = 0
        arena_reset(m_oc_s)
      @end
    @end
    param_origin = 0
    origin_keys = 0
    arena_reset(m_oc_s)
    @if any_changed == 0
      break
    @end
    pass_num = pass_num + 1
  @end
  return 1
@end

@fn oc_node_span(node: ASTNode)
  // WHY: Converts a lexer SourceSpan attached to an ASTNode (field 24 via typed ast_get_span)
  // into a semantic SourceSpan so ownership diagnostics report exact file:line:col instead of <built-in>:0:0.
  @if node == 0 return span_default() @end
  nsp = ast_get_span(node)
  @if nsp == 0 return span_default() @end
  @if nsp.span_start_line > 0
    sf = nsp.span_file
    @if sf == "" sf = "<source>" @end
    return span_new(nsp.span_start_line, nsp.span_start_col, nsp.span_end_line, nsp.span_end_col, sf)
  @end
  return span_default()
@end

@fn oc_extract_place_key(expr)
  // WHY: Builds a canonical place path (`s.buf`, `a.b.c`, `arr[0]`) for struct field and
  // constant-index places so `free(s.buf); free(s.buf)` and `free(arr[0]); free(arr[0])`
  // are caught without false positives on variable-indexed loops like `free(arr[i])`.
  @if expr == 0 return "" @end
  k = expr.kind
  @if str_eq(k, "Variable") == 1 || str_eq(k, "IDENT") == 1 || str_eq(k, "Identifier") == 1
    vn = expr.name
    @if vn == "" vn = expr.target @end
    return vn
  @end
  @if str_eq(k, "MemberAccess") == 1 || str_eq(k, "FieldAccess") == 1 || str_eq(k, "Member") == 1
    base_n = expr.left
    @if base_n == 0 base_n = expr.target @end
    bk = oc_extract_place_key(base_n)
    @if bk != "" && expr.name != ""
      return bk + "." + expr.name
    @end
    return ""
  @end
  @if str_eq(k, "Index") == 1
    base_i = expr.iterable
    @if base_i == 0 base_i = expr.left @end
    bk2 = oc_extract_place_key(base_i)
    @if bk2 != "" && expr.index != 0
      ik = expr.index.kind
      @if str_eq(ik, "LiteralInt") == 1 || str_eq(ik, "Integer") == 1 || str_eq(ik, "INT") == 1
        return bk2 + "[" + to_str(expr.index.val) + "]"
      @end
    @end
    return ""
  @end
  return ""
@end

@fn oc_reset_subplaces(oc, root_name)
  // WHY: Reassigning a whole struct/array (`s = new_s`) refreshes its field/index sub-places.
  @if oc == 0 || root_name == "" return 0 @end
  pref_dot = root_name + "."
  pref_idx = root_name + "["
  i = 0
  n = oc.oc_bindings.len()
  @while i < n
    b = oc.oc_bindings[i]
    @if str_starts_with(b.rb_name, pref_dot) == 1 || str_starts_with(b.rb_name, pref_idx) == 1
      b.rb_state = OWN_STATE_OWNED()
      b.rb_shared_borrow_count = 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn oc_release_temp_borrows_to(oc, mark)
  @while oc.oc_temp_borrows.len() > mark
    last_b = oc.oc_temp_borrows[oc.oc_temp_borrows.len() - 1]
    pop(oc.oc_temp_borrows)
    oc_release_borrow(oc, last_b)
  @end
  return 1
@end

@fn oc_analyze_expr(oc, expr)
  @if expr == 0 return 1 @end
  k = expr.kind
  esp = oc_node_span(expr)
  @if str_eq(k, "Variable") == 1 || str_eq(k, "IDENT") == 1 || str_eq(k, "Identifier") == 1
    vname = expr.name
    @if vname == "" vname = expr.target @end
    oc_check_read(oc, vname, esp)
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
      a0_sp = oc_node_span(a0)
      @if a0_sp.sp_start_line == 0 a0_sp = esp @end
      @if a0 != 0 && (str_eq(a0.kind, "Variable") == 1 || str_eq(a0.kind, "IDENT") == 1 || str_eq(a0.kind, "Identifier") == 1)
        aname = a0.name
        @if aname == "" aname = a0.target @end
        rb_drop = oc_lookup(oc, aname)
        @if rb_drop != 0 && rb_drop.rb_borrows_target != ""
          oc_release_borrow(oc, rb_drop.rb_borrows_target)
          rb_drop.rb_borrows_target = ""
        @end
        oc_check_read(oc, aname, a0_sp)
        oc_force_move(oc, aname, a0_sp)
        @if call_args.len() > 1
          pi2 = 1
          @while pi2 < call_args.len()
            oc_analyze_expr(oc, call_args[pi2])
            pi2 = pi2 + 1
          @end
        @end
        return 1
      @elif a0 != 0
        // WHY: Track struct-field & constant-index places (`free(s.buf)`, `free(arr[0])`)
        // so double-free and use-after-free of owned fields/elements are caught.
        place_k = oc_extract_place_key(a0)
        @if place_k != "" && (str_contains(place_k, ".") == 1 || str_contains(place_k, "[") == 1)
          root_pk = oc_extract_root_var(place_k)
          oc_check_read(oc, root_pk, a0_sp)
          pk_b = oc_lookup(oc, place_k)
          @if pk_b == 0
            oc_declare(oc, place_k, 0, a0_sp)
          @else
            oc_check_read(oc, place_k, a0_sp)
          @end
          oc_force_move(oc, place_k, a0_sp)
          @if call_args.len() > 1
            pi2p = 1
            @while pi2p < call_args.len()
              oc_analyze_expr(oc, call_args[pi2p])
              pi2p = pi2p + 1
            @end
          @end
          return 1
        @end
      @end
    @end
    // WHY: Hold temporary borrows (`&x` / `&mut x`) across ALL sibling call arguments
    // so `foo(&mut x, &x)` and `foo(&x, &mut x)` trigger borrow conflicts, then release after call!
    tb_mark = oc.oc_temp_borrows.len()
    oc.oc_hold_borrow_depth = oc.oc_hold_borrow_depth + 1
    // Inter-procedural consuming wrapper propagation: order-independent aliasing check + consumes_param[i] move
    @if cname != "" && oc.oc_fn_consumes != 0 && has_key(oc.oc_fn_consumes, cname) == 1 && call_args != 0
      c_flags = oc.oc_fn_consumes[cname]
      // Phase 1: Check all arguments for reads & detect aliasing between consumed and borrowed positions
      consumed_names = []
      consumed_idxs = []
      consumed_spans = []
      pi_c = 0
      @while pi_c < call_args.len()
        arg_c = call_args[pi_c]
        is_cvar = 0
        @if pi_c < c_flags.len() && c_flags[pi_c] == 1 && arg_c != 0 && (str_eq(arg_c.kind, "Variable") == 1 || str_eq(arg_c.kind, "IDENT") == 1 || str_eq(arg_c.kind, "Identifier") == 1)
          an_c = arg_c.name
          @if an_c == "" an_c = arg_c.target @end
          ac_sp = oc_node_span(arg_c)
          @if ac_sp.sp_start_line == 0 ac_sp = esp @end
          oc_check_read(oc, an_c, ac_sp)
          consumed_names = consumed_names.push(an_c)
          consumed_idxs = consumed_idxs.push(pi_c)
          consumed_spans = consumed_spans.push(ac_sp)
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
                  oc_record_error(oc, ERR_USE_AFTER_MOVE(), "Aliasing use of value '" + cn_a + "' passed both as consumed and borrowed argument in call to '" + cname + "'", esp)
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
        oc_force_move(oc, consumed_names[ci_m], consumed_spans[ci_m])
        ci_m = ci_m + 1
      @end
      oc.oc_hold_borrow_depth = oc.oc_hold_borrow_depth - 1
      oc_release_temp_borrows_to(oc, tb_mark)
      return 1
    @end
    @if call_args != 0
      pi = 0
      @while pi < call_args.len()
        oc_analyze_expr(oc, call_args[pi])
        pi = pi + 1
      @end
    @end
    oc.oc_hold_borrow_depth = oc.oc_hold_borrow_depth - 1
    oc_release_temp_borrows_to(oc, tb_mark)
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
        in_sp = oc_node_span(inner)
        @if in_sp.sp_start_line == 0 in_sp = esp @end
        // WHY: Only track borrows for known local bindings (`&fn_name` has no binding -> no-op).
        @if oc_lookup(oc, bn) != 0
          @if str_eq(expr.op, "&mut") == 1
            ok_b = oc_borrow_mut(oc, bn, in_sp)
            @if ok_b == 1
              @if oc.oc_hold_borrow_depth > 0
                oc.oc_temp_borrows = oc.oc_temp_borrows.push(bn)
              @else
                oc_release_borrow(oc, bn)
              @end
            @end
          @else
            ok_b = oc_borrow_shared(oc, bn, in_sp)
            @if ok_b == 1
              @if oc.oc_hold_borrow_depth > 0
                oc.oc_temp_borrows = oc.oc_temp_borrows.push(bn)
              @else
                oc_release_borrow(oc, bn)
              @end
            @end
          @end
        @end
        return 1
      @end
    @end
    oc_analyze_expr(oc, expr.expr)
    return 1
  @end
  @if str_eq(k, "Index") == 1 || str_eq(k, "Member") == 1 || str_eq(k, "MemberAccess") == 1 || str_eq(k, "FieldAccess") == 1
    pk_r = oc_extract_place_key(expr)
    @if pk_r != "" && (str_contains(pk_r, ".") == 1 || str_contains(pk_r, "[") == 1)
      @if oc_lookup(oc, pk_r) != 0
        oc_check_read(oc, pk_r, esp)
      @end
    @end
    oc_analyze_expr(oc, expr.left)
    @if expr.right != 0 oc_analyze_expr(oc, expr.right) @end
    @if expr.index != 0 oc_analyze_expr(oc, expr.index) @end
    return 1
  @end
  @if str_eq(k, "MatchExpr") == 1
    @if expr.expr != 0 oc_analyze_expr(oc, expr.expr) @end
    @if expr.body != 0 && expr.body.len() > 0
      me_pre = oc_snapshot_states(oc)
      me_snaps = []
      mi_e = 0
      @while mi_e < expr.body.len()
        oc_restore_states(oc, me_pre)
        arm_n = expr.body[mi_e]
        oc_enter_scope(oc)
        arm_stmts_e = 0
        @if arm_n != 0 && (str_eq(arm_n.kind, "If") == 1 || str_eq(arm_n.kind, "IfStmt") == 1)
          arm_stmts_e = arm_n.then_body
          oc_analyze_stmt_list(oc, arm_stmts_e)
        @else
          oc_analyze_statement(oc, arm_n)
        @end
        arm_t_e = oc_block_terminates(arm_stmts_e)
        oc_exit_scope_mode(oc, 1 - arm_t_e)
        @if arm_t_e == 0
          me_snaps = me_snaps.push(oc_snapshot_states(oc))
        @end
        mi_e = mi_e + 1
      @end
      oc_restore_states(oc, me_pre)
      msi = 0
      @while msi < me_snaps.len()
        oc_merge_branch_snap(oc, me_snaps[msi])
        msi = msi + 1
      @end
    @end
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
    // WHY: Closure `expr.params` stores raw parameter name strings (unlike FnDef Param structs),
    // and its own `oc_fn_scope_depth` prevents `return` inside a closure from running outer defers.
    prev_clo_fn_depth = oc.oc_fn_scope_depth
    oc_enter_scope(oc)
    oc.oc_fn_scope_depth = oc.oc_scope_depth
    @if expr.params != 0
      pi = 0
      @while pi < expr.params.len()
        pname = expr.params[pi]
        @if pname != "" oc_declare(oc, pname, 1, esp) @end
        pi = pi + 1
      @end
    @end
    oc_analyze_stmt_list(oc, expr.body)
    clo_terms = oc_block_terminates(expr.body)
    oc_exit_scope_mode(oc, 1 - clo_terms)
    oc.oc_fn_scope_depth = prev_clo_fn_depth
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
  // WHY: Captures current moved/borrow state, shared borrow counts, AND active borrow targets
  // before branching control flow so restoring across mutually exclusive arms never leaks stale borrows.
  states = []
  counts = []
  targets = []
  i = 0
  n = oc.oc_bindings.len()
  @while i < n
    b = oc.oc_bindings[i]
    states = states.push(b.rb_state)
    counts = counts.push(b.rb_shared_borrow_count)
    targets = targets.push(b.rb_borrows_target)
    i = i + 1
  @end
  return [states, counts, targets]
@end

@fn oc_restore_states(oc, snap)
  // WHY: Restores prior binding states, borrow counts, and borrow targets across mutually exclusive branches.
  states = snap[0]
  counts = snap[1]
  targets = snap[2]
  i = 0
  n = states.len()
  @if oc.oc_bindings.len() < n n = oc.oc_bindings.len() @end
  @while i < n
    b = oc.oc_bindings[i]
    b.rb_state = states[i]
    b.rb_shared_borrow_count = counts[i]
    b.rb_borrows_target = targets[i]
    i = i + 1
  @end
  return 1
@end

@fn oc_merge_branch_snap(oc, br_snap)
  // WHY: Conservatively joins another non-terminating branch snapshot into current bindings:
  // MOVED > BORROWED_MUT > BORROWED_SHARED > OWNED, preserving borrow target ownership so
  // `if cond { r = &mut x } else { y = 1 }; x = 99` is caught while still releasing cleanly at scope exit.
  b_states = br_snap[0]
  b_counts = br_snap[1]
  b_targets = br_snap[2]
  mlen = b_states.len()
  @if oc.oc_bindings.len() < mlen mlen = oc.oc_bindings.len() @end
  mi = 0
  @while mi < mlen
    cur_b = oc.oc_bindings[mi]
    bs = b_states[mi]
    bc = b_counts[mi]
    bt = b_targets[mi]
    @if bs == OWN_STATE_MOVED()
      cur_b.rb_state = OWN_STATE_MOVED()
    @elif cur_b.rb_state != OWN_STATE_MOVED()
      @if bs == OWN_STATE_BORROWED_MUT()
        cur_b.rb_state = OWN_STATE_BORROWED_MUT()
        cur_b.rb_shared_borrow_count = 0
      @elif cur_b.rb_state != OWN_STATE_BORROWED_MUT() && bc > cur_b.rb_shared_borrow_count
        cur_b.rb_shared_borrow_count = bc
        cur_b.rb_state = OWN_STATE_BORROWED_SHARED()
      @end
    @end
    @if cur_b.rb_borrows_target == "" && bt != ""
      cur_b.rb_borrows_target = bt
    @end
    mi = mi + 1
  @end
  return 1
@end

@fn oc_block_terminates(stmts)
  // WHY: Detects unconditional early-exit blocks (`return`, `break`, `continue`, `throw`) so fallthrough
  // after `if cond { free(x); return }` does not falsely treat `x` as moved on the normal path.
  @if stmts == 0 || stmts.len() == 0 return 0 @end
  last = stmts[stmts.len() - 1]
  @if last == 0 return 0 @end
  lk = last.kind
  @if str_eq(lk, "Return") == 1 || str_eq(lk, "ফেরত") == 1 || str_eq(lk, "Break") == 1 || str_eq(lk, "Continue") == 1
    return 1
  @end
  @if (str_eq(lk, "ExprStmt") == 1 || str_eq(lk, "ExpressionStmt") == 1) && str_eq(last.op, "throw") == 1
    return 1
  @end
  @if (str_eq(lk, "If") == 1 || str_eq(lk, "IfStmt") == 1 || str_eq(lk, "যদি") == 1) && str_eq(last.op, "match") == 0 && str_eq(last.op, "try") == 0
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
  ssp = oc_node_span(stmt)

  // 0. Struct Definition: register struct name as non-Copy owned type
  @if str_eq(k, "StructDef") == 1 || str_eq(k, "Struct") == 1 || str_eq(k, "গঠন") == 1
    @if stmt.name != ""
      oc.oc_struct_map[stmt.name] = 1
    @end
    return 1
  @end

  // 1. Function Definition: create isolated function scope with deferred-cleanup tracking
  @if str_eq(k, "FnDef") == 1 || str_eq(k, "Function") == 1 || str_eq(k, "কাজ") == 1 || str_eq(k, "Component") == 1
    prev_fn_depth = oc.oc_fn_scope_depth
    oc_enter_scope(oc)
    oc.oc_fn_scope_depth = oc.oc_scope_depth
    @if stmt.params != 0
      pi = 0
      @while pi < stmt.params.len()
        pm = stmt.params[pi]
        pname = pm.param_name
        @if pname == "" pname = pm.name @end
        @if pname != "" oc_declare(oc, pname, 1, ssp) @end
        pi = pi + 1
      @end
    @end
    oc_analyze_stmt_list(oc, stmt.body)
    fn_terms = oc_block_terminates(stmt.body)
    oc_exit_scope_mode(oc, 1 - fn_terms)
    oc.oc_fn_scope_depth = prev_fn_depth
    return 1
  @end

  // 2. Assignment & Compound Assignment: target = value, target <op>= value, *ptr = value
  @if str_eq(k, "Assign") == 1 || str_eq(k, "AssignOp") == 1
    @if str_eq(stmt.op, "deref_assign") == 1 || str_eq(stmt.target, "*") == 1
      @if stmt.left != 0 oc_analyze_expr(oc, stmt.left) @end
      val_da = stmt.value
      @if val_da == 0 val_da = stmt.expr @end
      oc_analyze_expr(oc, val_da)
      return 1
    @end
    @if stmt.index != 0
      oc_analyze_expr(oc, stmt.index)
    @end
    target = stmt.target
    val_node = stmt.value
    @if val_node == 0 val_node = stmt.expr @end

    // Detect persistent borrow binding: `r = &x` or `r = &mut x`
    borrow_tgt = ""
    borrow_is_mut = 0
    @if str_eq(k, "Assign") == 1 && stmt.index == 0 && str_contains(target, ".") == 0 && str_contains(target, "[") == 0 && val_node != 0 && (str_eq(val_node.kind, "Unary") == 1 || str_eq(val_node.kind, "UnaryOp") == 1) && (str_eq(val_node.op, "&") == 1 || str_eq(val_node.op, "&mut") == 1) && val_node.expr != 0
      bv_in = val_node.expr
      @if str_eq(bv_in.kind, "Variable") == 1 || str_eq(bv_in.kind, "IDENT") == 1 || str_eq(bv_in.kind, "Identifier") == 1
        bvn = bv_in.name
        @if bvn == "" bvn = bv_in.target @end
        @if oc_lookup(oc, bvn) != 0
          borrow_tgt = bvn
          @if str_eq(val_node.op, "&mut") == 1 borrow_is_mut = 1 @end
        @end
      @end
    @end

    // Detect alias move: q = p when p holds a non-Copy owned heap handle or struct
    move_src = ""
    rhs_is_copy = 1
    @if borrow_tgt != ""
      // Release any previous borrow held by `target` before acquiring the new borrow
      b_prev = oc_lookup(oc, target)
      @if b_prev != 0 && b_prev.rb_borrows_target != ""
        oc_release_borrow(oc, b_prev.rb_borrows_target)
        b_prev.rb_borrows_target = ""
      @end
      b_sp = oc_node_span(val_node)
      @if b_sp.sp_start_line == 0 b_sp = ssp @end
      b_ok = 0
      @if borrow_is_mut == 1
        b_ok = oc_borrow_mut(oc, borrow_tgt, b_sp)
      @else
        b_ok = oc_borrow_shared(oc, borrow_tgt, b_sp)
      @end
      @if b_prev == 0
        oc_declare(oc, target, 1, ssp)
        b_prev = oc_lookup(oc, target)
      @else
        oc_check_write(oc, target, ssp)
        b_prev.rb_is_copy = 1
      @end
      @if b_ok == 1 && b_prev != 0
        b_prev.rb_borrows_target = borrow_tgt
      @end
      return 1
    @end
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
      mv_sp = oc_node_span(val_node)
      @if mv_sp.sp_start_line == 0 mv_sp = ssp @end
      oc_mark_move(oc, move_src, mv_sp)
    @end

    @if stmt.index != 0 || str_contains(target, ".") == 1 || str_contains(target, "[") == 1
      root_t = oc_extract_root_var(target)
      rb_root = oc_lookup(oc, root_t)
      @if rb_root != 0
        oc_check_read(oc, root_t, ssp)
        @if rb_root.rb_shared_borrow_count > 0 || rb_root.rb_state == OWN_STATE_BORROWED_SHARED()
          oc_record_error(oc, ERR_MUTATE_WHILE_BORROWED(), "Cannot mutate '" + root_t + "' through field/index while borrowed", ssp)
        @end
      @end
      // Refresh or track field / constant-index place (e.g. `s.buf = malloc(16)` or `arr[0] = malloc(16)`)
      as_pk = ""
      @if stmt.index != 0
        ik_a = stmt.index.kind
        @if str_eq(ik_a, "LiteralInt") == 1 || str_eq(ik_a, "Integer") == 1 || str_eq(ik_a, "INT") == 1
          as_pk = target + "[" + to_str(stmt.index.val) + "]"
        @end
      @elif str_contains(target, ".") == 1
        as_pk = target
      @end
      @if as_pk != ""
        b_pk = oc_lookup(oc, as_pk)
        @if b_pk != 0
          oc_check_write(oc, as_pk, ssp)
          b_pk.rb_is_copy = rhs_is_copy
        @elif rhs_is_copy == 0
          oc_declare(oc, as_pk, 0, ssp)
        @end
      @end
      return 1
    @end

    b = oc_lookup(oc, target)
    @if b == 0
      oc_declare(oc, target, rhs_is_copy, ssp)
    @else
      @if b.rb_borrows_target != ""
        oc_release_borrow(oc, b.rb_borrows_target)
        b.rb_borrows_target = ""
      @end
      oc_check_write(oc, target, ssp)
      b.rb_is_copy = rhs_is_copy
      oc_reset_subplaces(oc, target)
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
    // WHY: Execute all active deferred statements in LIFO order at `return` AFTER evaluating the return value!
    oc_run_defers_from_depth(oc, oc.oc_fn_scope_depth)
    return 1
  @end

  @if str_eq(k, "Defer") == 1
    // WHY: Collect `defer` statements and defer their ownership analysis until scope exit / `return`!
    oc.oc_defer_stmts = oc.oc_defer_stmts.push(stmt)
    oc.oc_defer_depths = oc.oc_defer_depths.push(oc.oc_scope_depth)
    return 1
  @end

  // 5. While / For / Match / Try-Catch-Finally / Block / If scopes
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
    @if fvar != "" oc_declare(oc, fvar, 1, ssp) @end
    oc_analyze_stmt_list(oc, stmt.body)
    oc_analyze_stmt_list(oc, stmt.body)
    oc_exit_scope(oc)
    return 1
  @end

  // 5a. Match Statement: isolate every arm from sibling arms, then conservatively merge post-states!
  @if (str_eq(k, "If") == 1 || str_eq(k, "IfStmt") == 1 || str_eq(k, "MatchStmt") == 1 || str_eq(k, "Match") == 1) && (str_eq(stmt.op, "match") == 1 || str_eq(k, "MatchStmt") == 1 || str_eq(k, "Match") == 1)
    @if stmt.condition != 0 oc_analyze_expr(oc, stmt.condition) @else oc_analyze_expr(oc, stmt.expr) @end
    m_pre = oc_snapshot_states(oc)
    m_snaps = []
    arms = stmt.then_body
    @if arms == 0 || arms.len() == 0 arms = stmt.elements @end
    @if arms != 0
      ai = 0
      @while ai < arms.len()
        oc_restore_states(oc, m_pre)
        arm_st = arms[ai]
        oc_enter_scope(oc)
        arm_stmts = 0
        @if arm_st != 0 && (str_eq(arm_st.kind, "If") == 1 || str_eq(arm_st.kind, "IfStmt") == 1)
          arm_stmts = arm_st.then_body
          oc_analyze_stmt_list(oc, arm_stmts)
        @else
          oc_analyze_statement(oc, arm_st)
        @end
        arm_terms = oc_block_terminates(arm_stmts)
        oc_exit_scope_mode(oc, 1 - arm_terms)
        @if arm_terms == 0
          m_snaps = m_snaps.push(oc_snapshot_states(oc))
        @end
        ai = ai + 1
      @end
    @end
    oc_restore_states(oc, m_pre)
    msi_s = 0
    @while msi_s < m_snaps.len()
      oc_merge_branch_snap(oc, m_snaps[msi_s])
      msi_s = msi_s + 1
    @end
    return 1
  @end

  // 5b. Try / Catch / Finally: `catch` sees potential moves from `try`, and `finally` runs after both!
  @if ((str_eq(k, "If") == 1 || str_eq(k, "IfStmt") == 1) && str_eq(stmt.op, "try") == 1) || str_eq(k, "TryCatch") == 1 || str_eq(k, "Try") == 1
    try_pre = oc_snapshot_states(oc)
    oc_enter_scope(oc)
    oc_analyze_stmt_list(oc, stmt.then_body)
    try_terms = oc_block_terminates(stmt.then_body)
    oc_exit_scope_mode(oc, 1 - try_terms)
    post_try = oc_snapshot_states(oc)

    // WHY: An exception may be thrown at any point during `try`, so `catch` must conservatively
    // observe every move performed in `try` (catching `try { free(p); throw 1 } catch e { use(p) }`).
    @if stmt.else_body != 0 && stmt.else_body.len() > 0
      oc_restore_states(oc, try_pre)
      ti_m = 0
      @while ti_m < post_try[0].len() && ti_m < oc.oc_bindings.len()
        @if post_try[0][ti_m] == OWN_STATE_MOVED()
          oc.oc_bindings[ti_m].rb_state = OWN_STATE_MOVED()
        @end
        ti_m = ti_m + 1
      @end
      oc_enter_scope(oc)
      oc_analyze_stmt_list(oc, stmt.else_body)
      catch_terms = oc_block_terminates(stmt.else_body)
      oc_exit_scope_mode(oc, 1 - catch_terms)
      post_catch = oc_snapshot_states(oc)
      // Conservative join of try and catch states before `finally`
      ti_j = 0
      @while ti_j < post_try[0].len() && ti_j < oc.oc_bindings.len()
        @if post_try[0][ti_j] == OWN_STATE_MOVED() || (ti_j < post_catch[0].len() && post_catch[0][ti_j] == OWN_STATE_MOVED())
          oc.oc_bindings[ti_j].rb_state = OWN_STATE_MOVED()
        @end
        ti_j = ti_j + 1
      @end
    @end

    // `finally` always runs after both `try` and `catch`
    @if stmt.body != 0 && stmt.body.len() > 0
      oc_enter_scope(oc)
      oc_analyze_stmt_list(oc, stmt.body)
      fin_terms = oc_block_terminates(stmt.body)
      oc_exit_scope_mode(oc, 1 - fin_terms)
    @end
    return 1
  @end

  @if str_eq(k, "Block") == 1 || str_eq(k, "If") == 1 || str_eq(k, "IfStmt") == 1 || str_eq(k, "যদি") == 1
    @if stmt.condition != 0 oc_analyze_expr(oc, stmt.condition) @else oc_analyze_expr(oc, stmt.expr) @end
    pre_snap = oc_snapshot_states(oc)
    oc_enter_scope(oc)
    oc_analyze_stmt_list(oc, stmt.then_body)
    then_terms = oc_block_terminates(stmt.then_body)
    oc_exit_scope_mode(oc, 1 - then_terms)
    then_snap = oc_snapshot_states(oc)

    has_else = 0
    else_terms = 0
    @if stmt.else_body != 0 && stmt.else_body.len() > 0
      has_else = 1
      oc_restore_states(oc, pre_snap)
      oc_enter_scope(oc)
      oc_analyze_stmt_list(oc, stmt.else_body)
      else_terms = oc_block_terminates(stmt.else_body)
      oc_exit_scope_mode(oc, 1 - else_terms)
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
      // Conservative merge: moved OR borrowed in either path stays moved/borrowed after join
      oc_merge_branch_snap(oc, then_snap)
    @end
    return 1
  @end

  return 1
@end
