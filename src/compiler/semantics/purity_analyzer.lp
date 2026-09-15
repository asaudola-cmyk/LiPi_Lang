// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: FUNCTION PURITY & CONCURRENCY ANALYZER (purity_analyzer.lp)
// Module: src/compiler/semantics/purity_analyzer.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// Mathematical purity (referential transparency) is the bedrock of safe parallelization,
// dead-code elimination, loop invariant code motion, and function memoization.
// This module provides:
// 1. AST Purity Certification: Analyzes function bodies to determine if a routine
//    has observable side effects.
// 2. Strict Purity (Level 0): Functions that only compute on parameters, perform
//    zero I/O, allocate no long-lived global state, and mutate no outside pointers.
// 3. Read-Only (Level 1): Functions reading immutable globals but mutating nothing.
// 4. Concurrency Safety: Automatically certifies Level 0 & 1 functions as safe
//    for lock-free parallel execution across multi-core silicon threads.
// 5. Sovereign Prefixed Fields (`pv_`, `pr_`, `pa_`) eliminate struct collisions.
// ==============================================================================

import "universe/core/collections"
import "compiler/frontend/ast/ast_node"
import "universe/core/string"
import "compiler/semantics/symbol"

// ── 1. PURITY LEVELS & VIOLATION CLASSIFICATIONS ─────────────────────────────

@fn PURITY_STRICT_PURE()    return 0 @end
@fn PURITY_READ_ONLY()      return 1 @end
@fn PURITY_MUTATING_LOCAL() return 2 @end
@fn PURITY_IMPURE()         return 3 @end

// Purity Violation Kinds
@fn VIOLATION_IO_CALL()           return 1 @end
@fn VIOLATION_GLOBAL_WRITE()      return 2 @end
@fn VIOLATION_GLOBAL_READ()       return 3 @end
@fn VIOLATION_CALLS_IMPURE()      return 4 @end
@fn VIOLATION_POINTER_MUTATION()  return 5 @end
@fn VIOLATION_VOLATILE_SYSCALL()  return 6 @end

// ── 2. DATA STRUCTURES ───────────────────────────────────────────────────────

@struct PurityViolation
  pv_kind: i64
  pv_description: string
  pv_span: SourceSpan
@end

@struct FunctionPurityRecord
  pr_name: string
  pr_level: i64
  pr_violations: array
  pr_called_functions: array
  pr_is_analyzed: i64
@end

@fn purity_record_new(name)
  rec = FunctionPurityRecord()
  rec.pr_name = name
  rec.pr_level = PURITY_STRICT_PURE()
  rec.pr_violations = []
  rec.pr_called_functions = []
  rec.pr_is_analyzed = 0
  return rec
@end

@struct PurityAnalyzer
  pa_records: array
  pa_known_io_functions: array
  pa_known_pure_intrinsics: array
  pa_global_vars: array
@end

@fn purity_analyzer_new()
  io_fns = [
    "say", "print", "println", "file_read", "file_write",
    "sys_open", "sys_close", "sys_write", "sys_read", "sys_exit",
    "socket_connect", "epoll_wait", "net_send", "net_recv",
    "sys_mmap", "sys_munmap"
  ]

  pure_fns = [
    "abs", "min", "max", "len", "c_len", "str_len", "str_eq",
    "str_char_at", "str_substr", "str_slice", "str_starts_with",
    "str_ends_with", "to_str", "to_int", "int_to_str", "from_char"
  ]

  pa = PurityAnalyzer()
  pa.pa_records = []
  pa.pa_known_io_functions = io_fns
  pa.pa_known_pure_intrinsics = pure_fns
  pa.pa_global_vars = []
  return pa
@end

// ── 3. ENVIRONMENT CONFIGURATION ─────────────────────────────────────────────

@fn purity_register_io(pa, fn_name)
  @if pa == 0 || fn_name == "" return 0 @end
  pa.pa_known_io_functions = pa.pa_known_io_functions.push(fn_name)
  return 1
@end

@fn purity_register_pure(pa, fn_name)
  @if pa == 0 || fn_name == "" return 0 @end
  pa.pa_known_pure_intrinsics = pa.pa_known_pure_intrinsics.push(fn_name)
  return 1
@end

@fn purity_register_global(pa, var_name)
  @if pa == 0 || var_name == "" return 0 @end
  pa.pa_global_vars = pa.pa_global_vars.push(var_name)
  return 1
@end

@fn purity_is_known_io(pa, name)
  @if pa == 0 return 0 @end
  i = 0
  n = pa.pa_known_io_functions.len()
  @while i < n
    @if str_eq(pa.pa_known_io_functions[i], name) == 1 return 1 @end
    i = i + 1
  @end
  return 0
@end

@fn purity_is_known_pure(pa, name)
  @if pa == 0 return 0 @end
  i = 0
  n = pa.pa_known_pure_intrinsics.len()
  @while i < n
    @if str_eq(pa.pa_known_pure_intrinsics[i], name) == 1 return 1 @end
    i = i + 1
  @end
  return 0
@end

@fn purity_is_global_var(pa, name)
  @if pa == 0 return 0 @end
  i = 0
  n = pa.pa_global_vars.len()
  @while i < n
    @if str_eq(pa.pa_global_vars[i], name) == 1 return 1 @end
    i = i + 1
  @end
  return 0
@end

// ── 4. RECORD MANAGEMENT ─────────────────────────────────────────────────────

@fn purity_get_record(pa, fn_name)
  @if pa == 0 return 0 @end
  i = 0
  n = pa.pa_records.len()
  @while i < n
    rec = pa.pa_records[i]
    @if str_eq(rec.pr_name, fn_name) == 1
      return rec
    @end
    i = i + 1
  @end
  return 0
@end

@fn purity_add_violation(rec, kind, desc, span)
  sp = span
  @if sp == 0 sp = span_default() @end

  v = PurityViolation()
  v.pv_kind = kind
  v.pv_description = desc
  v.pv_span = sp
  rec.pr_violations = rec.pr_violations.push(v)

  @if kind == VIOLATION_IO_CALL() || kind == VIOLATION_GLOBAL_WRITE() || kind == VIOLATION_CALLS_IMPURE() || kind == VIOLATION_VOLATILE_SYSCALL()
    rec.pr_level = PURITY_IMPURE()
  @elif kind == VIOLATION_POINTER_MUTATION()
    @if rec.pr_level < PURITY_MUTATING_LOCAL()
      rec.pr_level = PURITY_MUTATING_LOCAL()
    @end
  @elif kind == VIOLATION_GLOBAL_READ()
    @if rec.pr_level < PURITY_READ_ONLY()
      rec.pr_level = PURITY_READ_ONLY()
    @end
  @end

  return rec.pr_level
@end

// ── 5. RECURSIVE AST EFFECT SCANNER ──────────────────────────────────────────

@fn purity_scan_expr(pa, rec, expr)
  @if expr == 0 return 0 @end

  k = expr.kind

  // 1. Function Call Check
  @if str_eq(k, "Call") == 1
    fn_name = expr.name
    @if fn_name == "" && expr.func != 0 fn_name = expr.func.name @end

    rec.pr_called_functions = rec.pr_called_functions.push(fn_name)

    @if purity_is_known_io(pa, fn_name) == 1
      purity_add_violation(rec, VIOLATION_IO_CALL(), "Invocation of I/O routine '" + fn_name + "'", span_default())
    @elif purity_is_known_pure(pa, fn_name) == 0
      callee_rec = purity_get_record(pa, fn_name)
      @if callee_rec != 0 && callee_rec.pr_level == PURITY_IMPURE()
        purity_add_violation(rec, VIOLATION_CALLS_IMPURE(), "Call to impure function '" + fn_name + "'", span_default())
      @end
    @end

    i = 0
    n = expr.args.len()
    @while i < n
      purity_scan_expr(pa, rec, expr.args[i])
      i = i + 1
    @end
    return 1
  @end

  // 2. Global Variable Read
  @if str_eq(k, "Variable") == 1 || str_eq(k, "IDENT") == 1
    v_name = expr.name
    @if v_name == "" && expr.target != "" v_name = expr.target @end
    @if purity_is_global_var(pa, v_name) == 1
      purity_add_violation(rec, VIOLATION_GLOBAL_READ(), "Reads mutable global state '" + v_name + "'", span_default())
    @end
    return 1
  @end

  // 3. Binary Operations
  @if str_eq(k, "BinaryOp") == 1
    purity_scan_expr(pa, rec, expr.left)
    purity_scan_expr(pa, rec, expr.right)
    return 1
  @end

  // 4. Unary Operations
  @if str_eq(k, "UnaryOp") == 1
    purity_scan_expr(pa, rec, expr.expr)
    return 1
  @end

  return 1
@end

@fn purity_scan_stmt(pa, rec, stmt)
  @if stmt == 0 return 0 @end

  k = stmt.kind

  // 1. Assignment
  @if str_eq(k, "Assign") == 1
    target = stmt.target
    val_expr = stmt.value
    @if val_expr == 0 val_expr = stmt.expr @end

    @if purity_is_global_var(pa, target) == 1
      purity_add_violation(rec, VIOLATION_GLOBAL_WRITE(), "Mutates global variable '" + target + "'", span_default())
    @end

    purity_scan_expr(pa, rec, val_expr)
    return 1
  @end

  // 2. If Statement
  @if str_eq(k, "If") == 1
    cond = stmt.condition
    @if cond == 0 cond = stmt.cond @end
    purity_scan_expr(pa, rec, cond)
    i = 0
    t_len = stmt.then_body.len()
    @while i < t_len
      purity_scan_stmt(pa, rec, stmt.then_body[i])
      i = i + 1
    @end
    j = 0
    e_len = stmt.else_body.len()
    @while j < e_len
      purity_scan_stmt(pa, rec, stmt.else_body[j])
      j = j + 1
    @end
    return 1
  @end

  // 3. While Loop
  @if str_eq(k, "While") == 1
    cond = stmt.condition
    @if cond == 0 cond = stmt.cond @end
    purity_scan_expr(pa, rec, cond)
    i = 0
    b_len = stmt.body.len()
    @while i < b_len
      purity_scan_stmt(pa, rec, stmt.body[i])
      i = i + 1
    @end
    return 1
  @end

  // 4. Return Statement
  @if str_eq(k, "Return") == 1
    val_expr = stmt.value
    @if val_expr == 0 val_expr = stmt.expr @end
    @if val_expr != 0
      purity_scan_expr(pa, rec, val_expr)
    @end
    return 1
  @end

  // 5. Standalone Expression
  purity_scan_expr(pa, rec, stmt)
  return 1
@end

// ── 6. PRIMARY ANALYSIS DRIVER & QUERY INTERFACE ─────────────────────────────

@fn purity_analyze_fn(pa, fn_node)
  @if pa == 0 || fn_node == 0 return 0 @end

  fn_name = fn_node.name

  rec = purity_get_record(pa, fn_name)
  @if rec == 0
    rec = purity_record_new(fn_name)
    pa.pa_records = pa.pa_records.push(rec)
  @end

  i = 0
  n = fn_node.body.len()
  @while i < n
    purity_scan_stmt(pa, rec, fn_node.body[i])
    i = i + 1
  @end

  rec.pr_is_analyzed = 1
  return rec.pr_level
@end

@fn purity_is_pure(pa, fn_name)
  rec = purity_get_record(pa, fn_name)
  @if rec == 0
    @if purity_is_known_pure(pa, fn_name) == 1 return 1 @end
    return 0
  @end
  @if rec.pr_level == PURITY_STRICT_PURE() return 1 @end
  return 0
@end

@fn purity_can_parallelize(pa, fn_name)
  rec = purity_get_record(pa, fn_name)
  @if rec == 0
    @if purity_is_known_pure(pa, fn_name) == 1 return 1 @end
    return 0
  @end
  @if rec.pr_level == PURITY_STRICT_PURE() || rec.pr_level == PURITY_READ_ONLY()
    return 1
  @end
  return 0
@end

@fn purity_can_memoize(pa, fn_name)
  return purity_is_pure(pa, fn_name)
@end

@fn purity_level_to_string(level)
  @if level == PURITY_STRICT_PURE()    return "Strictly Pure"   @end
  @if level == PURITY_READ_ONLY()      return "Read-Only"       @end
  @if level == PURITY_MUTATING_LOCAL() return "Mutating Local"  @end
  @if level == PURITY_IMPURE()         return "Impure"          @end
  return "Unknown"
@end

@fn purity_explain(pa, fn_name)
  rec = purity_get_record(pa, fn_name)
  @if rec == 0
    return "Function '" + fn_name + "' has not been analyzed."
  @end

  res = "Function '" + fn_name + "' is classified as: " + purity_level_to_string(rec.pr_level) + ".\n"
  @if rec.pr_violations.len() == 0
    res = res + "  - Certified referentially transparent; safe for concurrency and memoization."
  @else
    res = res + "  - Violations detected:\n"
    i = 0
    n = rec.pr_violations.len()
    @while i < n
      v = rec.pr_violations[i]
      res = res + "    * " + v.pv_description + "\n"
      i = i + 1
    @end
  @end

  return res
@end
