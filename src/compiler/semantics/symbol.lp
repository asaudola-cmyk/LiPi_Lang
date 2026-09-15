// ==============================================================================
// 🏛️ LIPI COMPILER SEMANTICS: SYMBOL REPRESENTATION & METADATA (symbol.lp)
// Module: src/compiler/semantics/symbol.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies / Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// In a sovereign self-hosting compiler, symbols are the canonical identity records
// for every named entity in the program (variables, functions, constants, types,
// modules, struct fields, and parameters).
//
// DESIGN PRINCIPLES:
// 1. Hardware-Deterministic Layout: Uses collision-free prefixed fields (`sym_name`,
//    `sym_kind`, etc.) and explicit named constructor `Symbol()` guaranteeing exact
//    byte offsets without field name collisions across AST and compiler modules.
// 2. Precise Source Spans: Every symbol carries source coordinate tracking
//    (sp_start_line, sp_start_col, sp_end_line, sp_end_col, sp_file) for pinpoint
//    diagnostic reporting.
// 3. Immutability Flags: Fast bit-level classification between mutable variables
//    and compile-time constants (sym_is_const).
// 4. Ownership & Purity Lifecycle: Direct slots for move tracking (sym_is_moved),
//    purity status (sym_is_pure), and static value tracking (sym_init_val).
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"

// ── 1. SYMBOL KIND ENUMERATION ───────────────────────────────────────────────
// WHY: Discrete integer constants enable single-cycle equality checks in compiler passes.

@fn SYM_KIND_UNKNOWN()    return 0 @end
@fn SYM_KIND_VARIABLE()   return 1 @end
@fn SYM_KIND_CONSTANT()   return 2 @end
@fn SYM_KIND_FUNCTION()   return 3 @end
@fn SYM_KIND_PARAMETER()  return 4 @end
@fn SYM_KIND_STRUCT()     return 5 @end
@fn SYM_KIND_FIELD()      return 6 @end
@fn SYM_KIND_MODULE()     return 7 @end
@fn SYM_KIND_TYPE_ALIAS() return 8 @end

// ── 2. SOURCE LOCATION TRACKING ──────────────────────────────────────────────

@struct SourceSpan
  sp_start_line: i64
  sp_start_col: i64
  sp_end_line: i64
  sp_end_col: i64
  sp_file: string
@end

@fn span_new(start_line, start_col, end_line, end_col, file)
  // WHY: Factory constructor guaranteeing exact binary field layout
  sp = SourceSpan()
  sp.sp_start_line = start_line
  sp.sp_start_col = start_col
  sp.sp_end_line = end_line
  sp.sp_end_col = end_col
  sp.sp_file = file
  return sp
@end

@fn span_default()
  // WHY: Fallback span for compiler-synthesized symbols (e.g. built-ins)
  sp = SourceSpan()
  sp.sp_start_line = 0
  sp.sp_start_col = 0
  sp.sp_end_line = 0
  sp.sp_end_col = 0
  sp.sp_file = "<built-in>"
  return sp
@end

@fn span_to_string(sp)
  // WHY: Formats canonical compiler diagnostic header (e.g. "main.lp:12:5")
  @if sp == 0
    return "<unknown>:0:0"
  @end
  res = sp.sp_file + ":" + to_str(sp.sp_start_line) + ":" + to_str(sp.sp_start_col)
  return res
@end

// ── 3. CANONICAL SYMBOL DATA STRUCTURE ────────────────────────────────────────

@struct Symbol
  sym_name: string
  sym_kind: i64
  sym_type_ref: i64
  sym_is_const: i64
  sym_span: SourceSpan
  sym_scope_id: i64
  sym_is_moved: i64
  sym_is_pure: i64
  sym_init_val: i64
  sym_usage_count: i64
  sym_is_public: i64
@end

@fn symbol_new(name, kind, type_ref, is_const, span, scope_id)
  // WHY: Canonical primary constructor with comprehensive field initialization
  sp = span
  @if sp == 0
    sp = span_default()
  @end

  sym = Symbol()
  sym.sym_name = name
  sym.sym_kind = kind
  sym.sym_type_ref = type_ref
  sym.sym_is_const = is_const
  sym.sym_span = sp
  sym.sym_scope_id = scope_id
  sym.sym_is_moved = 0
  sym.sym_is_pure = 0
  sym.sym_init_val = 0
  sym.sym_usage_count = 0
  sym.sym_is_public = 0
  return sym
@end

@fn symbol_variable(name, type_ref, is_const, span, scope_id)
  // WHY: Dedicated constructor for local and global variables
  sym = symbol_new(name, SYM_KIND_VARIABLE(), type_ref, is_const, span, scope_id)
  return sym
@end

@fn symbol_constant(name, type_ref, val, span, scope_id)
  // WHY: Dedicated constructor for compile-time folded constants
  sym = symbol_new(name, SYM_KIND_CONSTANT(), type_ref, 1, span, scope_id)
  sym.sym_init_val = val
  return sym
@end

@fn symbol_function(name, type_ref, span, scope_id, is_pure)
  // WHY: Dedicated constructor for top-level or member functions
  sym = symbol_new(name, SYM_KIND_FUNCTION(), type_ref, 1, span, scope_id)
  sym.sym_is_pure = is_pure
  return sym
@end

@fn symbol_parameter(name, type_ref, span, scope_id)
  // WHY: Dedicated constructor for formal parameters in function signatures
  sym = symbol_new(name, SYM_KIND_PARAMETER(), type_ref, 0, span, scope_id)
  return sym
@end

@fn symbol_struct(name, type_ref, span, scope_id)
  // WHY: Dedicated constructor for aggregate user-defined struct definitions
  sym = symbol_new(name, SYM_KIND_STRUCT(), type_ref, 1, span, scope_id)
  return sym
@end

@fn symbol_field(name, type_ref, span, scope_id)
  // WHY: Dedicated constructor for struct member fields
  sym = symbol_new(name, SYM_KIND_FIELD(), type_ref, 0, span, scope_id)
  return sym
@end

@fn symbol_module(name, span, scope_id)
  // WHY: Dedicated constructor for imported namespaces and module identifiers
  sym = symbol_new(name, SYM_KIND_MODULE(), 0, 1, span, scope_id)
  return sym
@end

// ── 4. LIFECYCLE & STATE TRANSITION HELPERS ──────────────────────────────────

@fn symbol_mark_used(sym)
  // WHY: Tracks identifier occurrences to detect unused variable warnings
  @if sym != 0
    sym.sym_usage_count = sym.sym_usage_count + 1
  @end
  return sym
@end

@fn symbol_mark_moved(sym)
  // WHY: Enforces affine type semantics (preventing use-after-move errors)
  @if sym != 0
    sym.sym_is_moved = 1
  @end
  return sym
@end

@fn symbol_is_active(sym)
  // WHY: Check if a symbol is valid for reading (i.e. not moved)
  @if sym == 0 return 0 @end
  @if sym.sym_is_moved == 1 return 0 @end
  return 1
@end

@fn symbol_kind_to_string(kind)
  // WHY: Human-readable diagnostic output for type check and error messages
  @if kind == SYM_KIND_VARIABLE()   return "variable"  @end
  @if kind == SYM_KIND_CONSTANT()   return "constant"  @end
  @if kind == SYM_KIND_FUNCTION()   return "function"  @end
  @if kind == SYM_KIND_PARAMETER()  return "parameter" @end
  @if kind == SYM_KIND_STRUCT()     return "struct"    @end
  @if kind == SYM_KIND_FIELD()      return "field"     @end
  @if kind == SYM_KIND_MODULE()     return "module"    @end
  @if kind == SYM_KIND_TYPE_ALIAS() return "type_alias"@end
  return "unknown"
@end

@fn symbol_to_string(sym)
  // WHY: Serializes symbol state for compiler IR dumps and debug logging
  @if sym == 0 return "<nil-symbol>" @end
  res = symbol_kind_to_string(sym.sym_kind) + " " + sym.sym_name + " (scope=" + to_str(sym.sym_scope_id) + ", type=" + to_str(sym.sym_type_ref)
  @if sym.sym_is_const == 1
    res = res + ", const"
  @end
  @if sym.sym_is_moved == 1
    res = res + ", MOVED"
  @end
  res = res + ")"
  return res
@end
