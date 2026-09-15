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

import "universe/core/collections"
import "universe/core/string"
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
@end

@fn ownership_checker_new()
  oc = OwnershipChecker()
  oc.oc_bindings = []
  oc.oc_scope_depth = 0
  oc.oc_errors = []
  oc.oc_warnings = []
  return oc
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

// ── 6. AST STATEMENT ANALYSIS PASS ───────────────────────────────────────────

@fn oc_analyze_statement(oc, stmt)
  @if stmt == 0 return 1 @end

  k = stmt.kind

  // 1. Assignment: target = value
  @if str_eq(k, "Assign") == 1
    target = stmt.target
    val_node = stmt.value
    @if val_node == 0 val_node = stmt.expr @end

    @if val_node != 0
      @if str_eq(val_node.kind, "Variable") == 1 || str_eq(val_node.kind, "IDENT") == 1
        src_name = val_node.name
        @if src_name == "" src_name = val_node.target @end
        oc_check_read(oc, src_name, span_default())
        oc_mark_move(oc, src_name, span_default())
      @end
    @end

    b = oc_lookup(oc, target)
    @if b == 0
      is_cp = 0
      @if val_node != 0 && (str_eq(val_node.kind, "Integer") == 1 || str_eq(val_node.kind, "Bool") == 1)
        is_cp = 1
      @end
      oc_declare(oc, target, is_cp, span_default())
    @else
      oc_check_write(oc, target, span_default())
    @end
    return 1
  @end

  // 2. Variable Read / Expression Check
  @if str_eq(k, "Variable") == 1 || str_eq(k, "IDENT") == 1
    oc_check_read(oc, stmt.name, span_default())
    return 1
  @end

  // 3. Block
  @if str_eq(k, "Block") == 1 || str_eq(k, "If") == 1
    oc_enter_scope(oc)
    @if stmt.then_body != 0
      i = 0
      @while i < stmt.then_body.len()
        oc_analyze_statement(oc, stmt.then_body[i])
        i = i + 1
      @end
    @end
    oc_exit_scope(oc)
    return 1
  @end

  return 1
@end
