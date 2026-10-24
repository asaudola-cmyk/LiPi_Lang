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

import "utso/collections"
import "utso/string"
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
  tc_current_stmt: ASTNode
  tc_errors: array
  tc_warnings: array
@end

@fn type_checker_new(reg, symtab, scopes)
  // WHY: Initializes type checking pipeline with named constructor
  ctx = infer_ctx_new(reg, scopes)
  tc = TypeChecker()
  tc.tc_reg = reg
  tc.tc_current_stmt = 0
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

// WHY: Identifies native Silicon runtime helpers, freestanding kernel intrinsics,
// and language primitives that do not require user-defined AST function prototypes.
@fn tc_is_builtin_call(fn_name)
  // WHY: Unresolved or empty function identifiers are never builtins; return 0 so undefined/mismatched calls halt compilation.
  @if fn_name == "" return 0 @end
  @if str_eq(fn_name, "syscall") == 1 || str_eq(fn_name, "সিসকল") == 1 || str_eq(fn_name, "sys_syscall") == 1 return 1 @end
  @if str_eq(fn_name, "exit") == 1 || str_eq(fn_name, "বিদায়") == 1 || str_eq(fn_name, "sys_exit") == 1 || str_eq(fn_name, "sys_exit_group") == 1 || str_eq(fn_name, "প্রস্থান") == 1 return 1 @end
  @if str_eq(fn_name, "floor") == 1 || str_eq(fn_name, "মেঝে") == 1 return 1 @end
  @if str_eq(fn_name, "argv") == 1 || str_eq(fn_name, "আর্গস") == 1 return 1 @end
  @if str_eq(fn_name, "say") == 1 || str_eq(fn_name, "println") == 1 || str_eq(fn_name, "print") == 1 || str_eq(fn_name, "বলো") == 1 || str_eq(fn_name, "দেখাও") == 1 || str_eq(fn_name, "বলুন") == 1 || str_eq(fn_name, "প্রিন্ট") == 1 return 1 @end
  @if str_eq(fn_name, "len") == 1 || str_eq(fn_name, "length") == 1 || str_eq(fn_name, "দৈর্ঘ্য") == 1 || str_eq(fn_name, "str_len") == 1 || str_eq(fn_name, "list_len") == 1 return 1 @end
  @if str_eq(fn_name, "to_str") == 1 || str_eq(fn_name, "str") == 1 || str_eq(fn_name, "স্ট্রিং") == 1 || str_eq(fn_name, "is_str") == 1 || str_eq(fn_name, "is_string") == 1 return 1 @end
  @if str_eq(fn_name, "malloc") == 1 || str_eq(fn_name, "alloc") == 1 || str_eq(fn_name, "mem_alloc") == 1 || str_eq(fn_name, "মেমরি_বরাদ্দ") == 1 || str_eq(fn_name, "user_alloc") == 1 || str_eq(fn_name, "user_free") == 1 || str_eq(fn_name, "free") == 1 || str_eq(fn_name, "gc_collect") == 1 || str_eq(fn_name, "lipi_gc_collect") == 1 || str_eq(fn_name, "gc_init") == 1 || str_eq(fn_name, "gc_alloc") == 1 || str_eq(fn_name, "gc_free") == 1 || str_eq(fn_name, "gc_base") == 1 return 1 @end
  @if str_eq(fn_name, "mem_word_read") == 1 || str_eq(fn_name, "mem_read") == 1 || str_eq(fn_name, "mem_read_word") == 1 || str_eq(fn_name, "মেমরি_পড়ো") == 1 || str_eq(fn_name, "মেমরি_শব্দ_পড়ো") == 1 return 1 @end
  @if str_eq(fn_name, "mem_word_write") == 1 || str_eq(fn_name, "mem_write") == 1 || str_eq(fn_name, "mem_write_word") == 1 || str_eq(fn_name, "মেমরি_লেখো") == 1 || str_eq(fn_name, "মেমরি_শব্দ_লেখো") == 1 return 1 @end
  @if str_eq(fn_name, "mem_byte_read") == 1 || str_eq(fn_name, "mem_read_byte") == 1 || str_eq(fn_name, "mem_byte_পড়ো") == 1 || str_eq(fn_name, "মেমরি_বাইট_পড়ো") == 1 || str_eq(fn_name, "sys_peek8") == 1 || str_eq(fn_name, "sys_peek") == 1 return 1 @end
  @if str_eq(fn_name, "mem_byte_write") == 1 || str_eq(fn_name, "mem_write_byte") == 1 || str_eq(fn_name, "mem_byte_লেখো") == 1 || str_eq(fn_name, "মেমরি_বাইট_লেখো") == 1 || str_eq(fn_name, "sys_poke8") == 1 || str_eq(fn_name, "sys_poke") == 1 return 1 @end
  @if str_eq(fn_name, "list") == 1 || str_eq(fn_name, "তালিকা") == 1 || str_eq(fn_name, "push") == 1 || str_eq(fn_name, "get") == 1 || str_eq(fn_name, "set") == 1 || str_eq(fn_name, "pop") == 1 || str_eq(fn_name, "বাদ_দাও") == 1 return 1 @end
  @if str_eq(fn_name, "list_push") == 1 || str_eq(fn_name, "list_get") == 1 || str_eq(fn_name, "list_set") == 1 || str_eq(fn_name, "list_pop") == 1 || str_eq(fn_name, "list_create") == 1 || str_eq(fn_name, "list_free") == 1 return 1 @end
  @if str_eq(fn_name, "char_at") == 1 || str_eq(fn_name, "অক্ষর") == 1 || str_eq(fn_name, "str_sub") == 1 || str_eq(fn_name, "str_eq") == 1 || str_eq(fn_name, "str_concat") == 1 || str_eq(fn_name, "str_find") == 1 || str_eq(fn_name, "str_from_byte") == 1 return 1 @end
  @if str_eq(fn_name, "chr") == 1 || str_eq(fn_name, "অক্ষর_চিহ্ন") == 1 || str_eq(fn_name, "ord") == 1 || str_eq(fn_name, "ascii") == 1 || str_eq(fn_name, "কোড") == 1 || str_eq(fn_name, "str_slice") == 1 || str_eq(fn_name, "str_substr") == 1 || str_eq(fn_name, "str_char_at") == 1 || str_eq(fn_name, "str_starts_with") == 1 || str_eq(fn_name, "str_ends_with") == 1 return 1 @end
  @if str_eq(fn_name, "file_read") == 1 || str_eq(fn_name, "file_write") == 1 || str_eq(fn_name, "file_exists") == 1 || str_eq(fn_name, "file_size") == 1 || str_eq(fn_name, "file_write_bytes") == 1 return 1 @end
  @if str_eq(fn_name, "clock_ms") == 1 || str_eq(fn_name, "cpu_clock") == 1 || str_eq(fn_name, "time_now") == 1 || str_eq(fn_name, "time_now_ms") == 1 || str_eq(fn_name, "ক্লক") == 1 || str_eq(fn_name, "সময়_মিলি") == 1 return 1 @end
  @if str_eq(fn_name, "atomic_lock") == 1 || str_eq(fn_name, "atomic_unlock") == 1 || str_eq(fn_name, "atomic_cas") == 1 || str_eq(fn_name, "atomic_add") == 1 || str_eq(fn_name, "অ্যাটমিক_লক") == 1 || str_eq(fn_name, "অ্যাটমিক_আনলক") == 1 return 1 @end
  @if str_eq(fn_name, "fiber_switch") == 1 || str_eq(fn_name, "fiber_context_switch") == 1 || str_eq(fn_name, "stack_pointer") == 1 || str_eq(fn_name, "স্ট্যাক_পয়েন্টার") == 1 return 1 @end
  @if str_eq(fn_name, "slab_buckets_ptr") == 1 || str_eq(fn_name, "sizeof") == 1 || str_eq(fn_name, "size_of") == 1 || str_eq(fn_name, "সাইজ_অফ") == 1 || str_eq(fn_name, "sys_mmap") == 1 return 1 @end
  @if str_eq(fn_name, "arena_mark") == 1 || str_eq(fn_name, "arena_reset") == 1 || str_eq(fn_name, "arena_rollback") == 1 || str_eq(fn_name, "arena_free_all") == 1 || str_eq(fn_name, "arena_allocated") == 1 return 1 @end
  @if str_eq(fn_name, "অ্যারেনা_চিহ্ন") == 1 || str_eq(fn_name, "অ্যারেনা_রিসেট") == 1 || str_eq(fn_name, "অ্যারেনা_সব_খালি") == 1 || str_eq(fn_name, "অ্যারেনা_ব্যবহৃত") == 1 return 1 @end
  @if str_eq(fn_name, "cpu_has_avx2") == 1 || str_eq(fn_name, "cpuid_avx2") == 1 || str_eq(fn_name, "cpu_has_avx512") == 1 || str_eq(fn_name, "cpu_has_avx512f") == 1 || str_eq(fn_name, "cpuid_avx512") == 1 || str_eq(fn_name, "cpu_has_amx") == 1 || str_eq(fn_name, "cpuid_amx") == 1 || str_eq(fn_name, "সিপিইউ_এএমএক্স") == 1 || str_eq(fn_name, "cpu_has_vnni") == 1 || str_eq(fn_name, "cpuid_vnni") == 1 || str_eq(fn_name, "সিপিইউ_ভিএনএনআই") == 1 return 1 @end
  @if str_eq(fn_name, "simd_avx2_sum") == 1 || str_eq(fn_name, "simd_avx512_sum") == 1 || str_eq(fn_name, "simd_avx512_sum_u64") == 1 || str_eq(fn_name, "ভেক্টর_যোগ_২৫৬") == 1 || str_eq(fn_name, "simd_avx512_dot") == 1 || str_eq(fn_name, "simd_sse2_dot_f64") == 1 || str_eq(fn_name, "simd_sse2_gemv_f64") == 1 return 1 @end
  @if str_eq(fn_name, "matmul") == 1 || str_eq(fn_name, "ম্যাট্রিক্স_গুণ") == 1 || str_eq(fn_name, "_lipi_matmul") == 1 return 1 @end
  @if len(fn_name) >= 5 && char_at(fn_name, 0) == "s" && char_at(fn_name, 1) == "i" && char_at(fn_name, 2) == "m" && char_at(fn_name, 3) == "d" && char_at(fn_name, 4) == "_" return 1 @end
  @if str_eq(fn_name, "str_ptr") == 1 || str_eq(fn_name, "lipi_str_ptr") == 1 || str_eq(fn_name, "lipi_str_new") == 1 return 1 @end
  @if len(fn_name) >= 4 && char_at(fn_name, 0) == "s" && char_at(fn_name, 1) == "y" && char_at(fn_name, 2) == "s" && char_at(fn_name, 3) == "_" return 1 @end
  @if len(fn_name) >= 6 && char_at(fn_name, 0) == "_" && char_at(fn_name, 1) == "l" && char_at(fn_name, 2) == "i" && char_at(fn_name, 3) == "p" && char_at(fn_name, 4) == "i" && char_at(fn_name, 5) == "_" return 1 @end
  return 0
@end

// WHY: Assigns concrete return types to built-in system intrinsics for static type propagation.
@fn tc_builtin_ret_type(fn_name)
  @if str_eq(fn_name, "matmul") == 1 || str_eq(fn_name, "ম্যাট্রিক্স_গুণ") == 1 || str_eq(fn_name, "_lipi_matmul") == 1 return TYPE_ID_ANY() @end
  @if str_eq(fn_name, "ভেক্টর_যোগ_২৫৬") == 1 || (len(fn_name) >= 5 && char_at(fn_name, 0) == "s" && char_at(fn_name, 1) == "i" && char_at(fn_name, 2) == "m" && char_at(fn_name, 3) == "d" && char_at(fn_name, 4) == "_") return TYPE_ID_I64() @end
  @if str_eq(fn_name, "say") == 1 || str_eq(fn_name, "println") == 1 || str_eq(fn_name, "print") == 1 || str_eq(fn_name, "বলো") == 1 || str_eq(fn_name, "দেখাও") == 1 || str_eq(fn_name, "বলুন") == 1 || str_eq(fn_name, "প্রিন্ট") == 1 return TYPE_ID_VOID() @end
  @if str_eq(fn_name, "len") == 1 || str_eq(fn_name, "length") == 1 || str_eq(fn_name, "দৈর্ঘ্য") == 1 || str_eq(fn_name, "str_len") == 1 || str_eq(fn_name, "list_len") == 1 || str_eq(fn_name, "file_size") == 1 return TYPE_ID_I64() @end
  @if str_eq(fn_name, "floor") == 1 || str_eq(fn_name, "মেঝে") == 1 return TYPE_ID_I64() @end
  @if str_eq(fn_name, "clock_ms") == 1 || str_eq(fn_name, "cpu_clock") == 1 || str_eq(fn_name, "time_now") == 1 || str_eq(fn_name, "time_now_ms") == 1 || str_eq(fn_name, "stack_pointer") == 1 || str_eq(fn_name, "ord") == 1 || str_eq(fn_name, "ascii") == 1 || str_eq(fn_name, "কোড") == 1 || str_eq(fn_name, "str_char_at") == 1 || str_eq(fn_name, "str_find") == 1 || str_eq(fn_name, "str_index_of") == 1 return TYPE_ID_I64() @end
  @if str_eq(fn_name, "to_str") == 1 || str_eq(fn_name, "str") == 1 || str_eq(fn_name, "স্ট্রিং") == 1 || str_eq(fn_name, "file_read") == 1 || str_eq(fn_name, "str_sub") == 1 || str_eq(fn_name, "char_at") == 1 || str_eq(fn_name, "অক্ষর") == 1 || str_eq(fn_name, "str_concat") == 1 || str_eq(fn_name, "str_from_byte") == 1 || str_eq(fn_name, "chr") == 1 || str_eq(fn_name, "অক্ষর_চিহ্ন") == 1 || str_eq(fn_name, "str_slice") == 1 || str_eq(fn_name, "str_substr") == 1 return TYPE_ID_STRING() @end
  @if str_eq(fn_name, "is_str") == 1 || str_eq(fn_name, "is_string") == 1 || str_eq(fn_name, "file_exists") == 1 || str_eq(fn_name, "str_eq") == 1 || str_eq(fn_name, "str_starts_with") == 1 || str_eq(fn_name, "str_ends_with") == 1 return TYPE_ID_BOOL() @end
  @if str_eq(fn_name, "syscall") == 1 || str_eq(fn_name, "সিসকল") == 1 || str_eq(fn_name, "sys_syscall") == 1 || str_eq(fn_name, "exit") == 1 || str_eq(fn_name, "বিদায়") == 1 || str_eq(fn_name, "sys_mmap") == 1 return TYPE_ID_I64() @end
  @if str_eq(fn_name, "mem_word_read") == 1 || str_eq(fn_name, "mem_read") == 1 || str_eq(fn_name, "মেমরি_পড়ো") == 1 || str_eq(fn_name, "মেমরি_শব্দ_পড়ো") == 1 || str_eq(fn_name, "mem_byte_read") == 1 || str_eq(fn_name, "mem_read_byte") == 1 || str_eq(fn_name, "mem_byte_পড়ো") == 1 || str_eq(fn_name, "মেমরি_বাইট_পড়ো") == 1 || str_eq(fn_name, "sys_peek8") == 1 || str_eq(fn_name, "sys_peek") == 1 return TYPE_ID_I64() @end
  @if str_eq(fn_name, "file_write") == 1 || str_eq(fn_name, "file_write_bytes") == 1 || str_eq(fn_name, "sys_exit") == 1 || str_eq(fn_name, "sys_exit_group") == 1 || str_eq(fn_name, "প্রস্থান") == 1 || str_eq(fn_name, "mem_word_write") == 1 || str_eq(fn_name, "mem_write") == 1 || str_eq(fn_name, "mem_write_word") == 1 || str_eq(fn_name, "মেমরি_লেখো") == 1 || str_eq(fn_name, "মেমরি_শব্দ_লেখো") == 1 || str_eq(fn_name, "mem_byte_write") == 1 || str_eq(fn_name, "mem_write_byte") == 1 || str_eq(fn_name, "mem_byte_লেখো") == 1 || str_eq(fn_name, "মেমরি_বাইট_লেখো") == 1 || str_eq(fn_name, "sys_poke8") == 1 || str_eq(fn_name, "sys_poke") == 1 return TYPE_ID_VOID() @end
  @if str_eq(fn_name, "push") == 1 || str_eq(fn_name, "set") == 1 || str_eq(fn_name, "list_push") == 1 || str_eq(fn_name, "list_set") == 1 || str_eq(fn_name, "argv") == 1 || str_eq(fn_name, "আর্গস") == 1 || str_eq(fn_name, "pop") == 1 || str_eq(fn_name, "list_pop") == 1 || str_eq(fn_name, "বাদ_দাও") == 1 || str_eq(fn_name, "get") == 1 || str_eq(fn_name, "list") == 1 || str_eq(fn_name, "malloc") == 1 || str_eq(fn_name, "alloc") == 1 || str_eq(fn_name, "mem_alloc") == 1 || str_eq(fn_name, "মেমরি_বরাদ্দ") == 1 || str_eq(fn_name, "user_alloc") == 1 || str_eq(fn_name, "user_free") == 1 || str_eq(fn_name, "free") == 1 return TYPE_ID_ANY() @end
  return TYPE_ID_ANY()
@end

// ── 3. EXPRESSION TYPE CHECKING & VALIDATION ─────────────────────────────────

@fn tc_check_expr(tc, expr)
  @if expr == 0 return TYPE_ID_VOID() @end

  k = expr.kind

  // 0. Expression Statement Unpacking
  // WHY: AST expression statements wrap expressions inside an ExprStmt/ExpressionStmt node.
  // Unpacking stmt.expr guarantees calls, operators, and method invocations are inspected.
  @if str_eq(k, "ExprStmt") == 1 || str_eq(k, "ExpressionStmt") == 1
    @if expr.expr != 0
      return tc_check_expr(tc, expr.expr)
    @end
    return TYPE_ID_VOID()
  @end

  // 1. Literals
  @if str_eq(k, "LiteralInt") == 1 || str_eq(k, "LiteralFloat") == 1 || str_eq(k, "LiteralStr") == 1 || str_eq(k, "LiteralBool") == 1 || str_eq(k, "LiteralNone") == 1 || str_eq(k, "Integer") == 1 || str_eq(k, "Float") == 1 || str_eq(k, "String") == 1 || str_eq(k, "Bool") == 1 || str_eq(k, "None") == 1 || str_eq(k, "INT") == 1 || str_eq(k, "HEX_INT") == 1 || str_eq(k, "STRING") == 1 || str_eq(k, "BOOL") == 1
    return infer_literal_type(tc.tc_infer_ctx, expr)
  @end

  // 2. Variable reference
  @if str_eq(k, "Variable") == 1 || str_eq(k, "IDENT") == 1 || str_eq(k, "Identifier") == 1
    v_name = expr.name
    @if v_name == "" && expr.target != ""
      v_name = expr.target
    @end
    @if str_eq(v_name, "true") == 1 || str_eq(v_name, "false") == 1 || str_eq(v_name, "সত্য") == 1 || str_eq(v_name, "মিথ্যা") == 1 return TYPE_ID_BOOL() @end
    @if str_eq(v_name, "null") == 1 || str_eq(v_name, "nil") == 1 || str_eq(v_name, "শূন্য") == 1 return TYPE_ID_VOID() @end
    @if str_eq(v_name, "break") == 1 || str_eq(v_name, "continue") == 1 || str_eq(v_name, "থামো") == 1 || str_eq(v_name, "চালিয়ে_যাও") == 1 return TYPE_ID_VOID() @end

    sym = scope_lookup(tc.tc_scopes, v_name)
    @if sym == 0
      sym = symtab_get(tc.tc_symtab, v_name)
    @end

    @if sym == 0
      @if tc_is_builtin_call(v_name) == 1
        return TYPE_ID_ANY()
      @end
      tc_error(tc, ERR_UNDEFINED_VARIABLE(), "In function '" + tc.tc_current_fn_name + "': Undefined variable '" + v_name + "'", span_default())
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
      // WHY: LiPi supports gradual/dynamic typing where untyped expressions evaluate to ANY, UNKNOWN, or 0.
      // Permit dynamic operands to flow through without spurious compile-time rejection.
      @if t_left == TYPE_ID_ANY() || t_right == TYPE_ID_ANY() || t_left == TYPE_ID_UNKNOWN() || t_right == TYPE_ID_UNKNOWN() || t_left == 0 || t_right == 0
        return TYPE_ID_ANY()
      @end
      @if type_is_numeric(tc.tc_reg, t_left) == 0 || type_is_numeric(tc.tc_reg, t_right) == 0
        tc_error(tc, ERR_INVALID_OPERAND_TYPE(), "Operator '+' requires numeric or string operands", span_default())
      @end
      return infer_binary_op_type(tc.tc_infer_ctx, op, t_left, t_right)
    @end

    @if op == "-" || op == "*" || op == "/" || op == "%" || op == "@"
      // WHY: Allow dynamic/untyped values in arithmetic expressions for gradual typing
      @if t_left == TYPE_ID_ANY() || t_right == TYPE_ID_ANY() || t_left == TYPE_ID_UNKNOWN() || t_right == TYPE_ID_UNKNOWN() || t_left == 0 || t_right == 0
        return TYPE_ID_ANY()
      @end
      @if op == "@"
        // WHY: Matrix/Tensor multiplication accepts vectors, 2D arrays, tensors, or numeric scalars
        return TYPE_ID_ANY()
      @end
      @if type_is_numeric(tc.tc_reg, t_left) == 0 || type_is_numeric(tc.tc_reg, t_right) == 0
        tc_error(tc, ERR_INVALID_OPERAND_TYPE(), "In function '" + tc.tc_current_fn_name + "': Arithmetic operator '" + op + "' requires numeric operands, got " + type_to_string(tc.tc_reg, t_left) + " and " + type_to_string(tc.tc_reg, t_right), span_default())
      @end
      return infer_binary_op_type(tc.tc_infer_ctx, op, t_left, t_right)
    @end

    // Relational comparisons (<, <=, >, >=)
    @if op == "<" || op == "<=" || op == ">" || op == ">="
      // WHY: Dynamic operands in comparisons evaluate to boolean at runtime
      @if t_left == TYPE_ID_ANY() || t_right == TYPE_ID_ANY() || t_left == TYPE_ID_UNKNOWN() || t_right == TYPE_ID_UNKNOWN() || t_left == 0 || t_right == 0
        return TYPE_ID_BOOL()
      @end
      @if type_is_numeric(tc.tc_reg, t_left) == 0 || type_is_numeric(tc.tc_reg, t_right) == 0
        tc_error(tc, ERR_INVALID_OPERAND_TYPE(), "Relational operator '" + op + "' requires numeric operands", span_default())
      @end
      return TYPE_ID_BOOL()
    @end

    // Equality comparisons (==, !=)
    @if op == "==" || op == "!="
      @if t_left == TYPE_ID_ANY() || t_right == TYPE_ID_ANY() || t_left == TYPE_ID_UNKNOWN() || t_right == TYPE_ID_UNKNOWN() || t_left == 0 || t_right == 0
        return TYPE_ID_BOOL()
      @end
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
      @if t_left == TYPE_ID_ANY() || t_right == TYPE_ID_ANY() || t_left == TYPE_ID_UNKNOWN() || t_right == TYPE_ID_UNKNOWN() || t_left == 0 || t_right == 0
        return TYPE_ID_I64()
      @end
      @if (t_left != TYPE_ID_I64() && t_left != TYPE_ID_ANY() && t_left != TYPE_ID_BYTE()) || (t_right != TYPE_ID_I64() && t_right != TYPE_ID_ANY() && t_right != TYPE_ID_BYTE())
        tc_error(tc, ERR_INVALID_OPERAND_TYPE(), "Bitwise operator '" + op + "' requires i64 operands", span_default())
      @end
      return TYPE_ID_I64()
    @end

    // Range operator (..) for loop iterations and slices
    // WHY: Range operator produces an iterable range sequence
    @if op == ".."
      return TYPE_ID_ANY()
    @end

    return infer_binary_op_type(tc.tc_infer_ctx, op, t_left, t_right)
  @end

  // 4. Unary Operations
  @if str_eq(k, "UnaryOp") == 1
    t_inner = tc_check_expr(tc, expr.expr)
    @if expr.op == "!" || expr.op == "not" || expr.op == "না" return TYPE_ID_BOOL() @end
    @if expr.op == "-"
      @if t_inner == TYPE_ID_ANY() || t_inner == TYPE_ID_UNKNOWN() || t_inner == 0
        return TYPE_ID_ANY()
      @end
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
    @elif expr.func != 0 && expr.func.target != ""
      fn_name = expr.func.target
    @end

    // WHY: Built-in system intrinsics and hardware runtime primitives are validated directly
    @if tc_is_builtin_call(fn_name) == 1
      i = 0
      @while i < expr.args.len()
        tc_check_expr(tc, expr.args[i])
        i = i + 1
      @end
      return tc_builtin_ret_type(fn_name)
    @end

    // WHY: Check if call is a struct constructor instantiation
    s_sym = scope_lookup(tc.tc_scopes, fn_name)
    @if s_sym == 0
      s_sym = symtab_get(tc.tc_symtab, fn_name)
    @end
    @if s_sym != 0 && s_sym.sym_kind == SYM_KIND_STRUCT()
      i = 0
      @while i < expr.args.len()
        tc_check_expr(tc, expr.args[i])
        i = i + 1
      @end
      return s_sym.sym_type_ref
    @end

    // WHY: Check if call is a method invocation on an object: receiver.method(args...)
    is_method_call = 0
    recv_t = TYPE_ID_ANY()
    @if expr.func != 0 && (str_eq(expr.func.kind, "MemberAccess") == 1 || str_eq(expr.func.kind, "FieldAccess") == 1)
      is_method_call = 1
      recv_node = expr.func.left
      @if recv_node == 0 recv_node = expr.func.target @end
      recv_t = tc_check_expr(tc, recv_node)
    @end

    f_sym = s_sym
    @if f_sym == 0 && is_method_call == 1
      t_def = type_registry_get(tc.tc_reg, recv_t)
      @if t_def != 0 && t_def.ty_name != ""
        alt_name = t_def.ty_name + "_" + fn_name
        f_sym = scope_lookup(tc.tc_scopes, alt_name)
        @if f_sym == 0 f_sym = symtab_get(tc.tc_symtab, alt_name) @end
      @end
    @end

    @if f_sym == 0
      @if is_method_call == 1 && recv_t == TYPE_ID_ANY()
        i = 0
        @while i < expr.args.len()
          tc_check_expr(tc, expr.args[i])
          i = i + 1
        @end
        return TYPE_ID_ANY()
      @end
      tc_error(tc, ERR_UNDEFINED_FUNCTION(), "Undefined function '" + fn_name + "'", span_default())
      return TYPE_ID_ANY()
    @end

    f_type = type_registry_get(tc.tc_reg, f_sym.sym_type_ref)
    @if f_type == 0 || f_type.ty_kind != TYPE_KIND_FUNCTION()
      return TYPE_ID_ANY()
    @end

    num_params = f_type.ty_param_types.len()
    num_args = expr.args.len()
    effective_args = num_args
    @if is_method_call == 1
      effective_args = num_args + 1
    @end

    @if effective_args != num_params
      @if is_method_call == 1 && num_args == num_params
        effective_args = num_args
        is_method_call = 0
      @elif str_eq(fn_name, "main") == 1 || str_eq(fn_name, "মূল") == 1
        // Entry point main may be called by runtime with 0 arguments or argc/argv
      @else
        tc_error(tc, ERR_INVALID_ARG_COUNT(), "Function '" + fn_name + "' expects " + to_str(num_params) + " arguments, got " + to_str(effective_args), span_default())
      @end
    @end

    @if is_method_call == 1
      @if num_params > 0
        p0_t = f_type.ty_param_types[0]
        @if type_is_assignable(tc.tc_reg, p0_t, recv_t) == 0
          tc_error(tc, ERR_TYPE_MISMATCH(), "Receiver of '" + fn_name + "' expects " + type_to_string(tc.tc_reg, p0_t) + ", got " + type_to_string(tc.tc_reg, recv_t), span_default())
        @end
      @end
      j = 0
      check_len = num_args
      @if num_params - 1 < check_len check_len = num_params - 1 @end
      @while j < check_len
        arg_t = tc_check_expr(tc, expr.args[j])
        param_t = f_type.ty_param_types[j + 1]
        @if type_is_assignable(tc.tc_reg, param_t, arg_t) == 0
          tc_error(tc, ERR_TYPE_MISMATCH(), "Argument " + to_str(j + 1) + " of '" + fn_name + "' expects " + type_to_string(tc.tc_reg, param_t) + ", got " + type_to_string(tc.tc_reg, arg_t), span_default())
        @end
        j = j + 1
      @end
    @else
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
    target_node = expr.target
    @if target_node == 0 target_node = expr.left @end
    target_t = tc_check_expr(tc, target_node)
    @if target_t == TYPE_ID_ANY()
      return TYPE_ID_ANY()
    @end
    f_def = type_find_field(tc.tc_reg, target_t, expr.name)
    @if f_def == 0
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
  tc.tc_current_stmt = stmt

  k = stmt.kind

  // 1. Variable Assignment (target = value)
  @if str_eq(k, "Assign") == 1
    target_name = stmt.target
    val_expr = stmt.value
    @if val_expr == 0 val_expr = stmt.expr @end

    rhs_t = tc_check_expr(tc, val_expr)

    // WHY: Struct field assignments (obj.field = expr) or array element updates (arr[i] = expr)
    // modify properties or heap buffers rather than declaring a new scalar symbol in the current scope.
    @if str_contains(target_name, ".") == 1 || str_contains(target_name, "[") == 1
      return 1
    @end

    sym = scope_lookup(tc.tc_scopes, target_name)
    @if sym != 0 && sym.sym_kind == SYM_KIND_FUNCTION()
      sym = scope_lookup_current(tc.tc_scopes, target_name)
    @end

    @if sym != 0
      @if sym.sym_is_const == 1 || sym.sym_kind == SYM_KIND_CONSTANT()
        tc_error(tc, ERR_CANNOT_ASSIGN_CONST(), "Cannot reassign to constant '" + target_name + "'", span_default())
      @end

      @if type_is_assignable(tc.tc_reg, sym.sym_type_ref, rhs_t) == 0
        @if sym.sym_kind == SYM_KIND_VARIABLE() && sym.sym_is_const == 0
          sym.sym_type_ref = TYPE_ID_ANY()
        @else
          tc_error(tc, ERR_TYPE_MISMATCH(), "In function '" + tc.tc_current_fn_name + "': Cannot assign " + type_to_string(tc.tc_reg, rhs_t) + " to variable '" + target_name + "' of type " + type_to_string(tc.tc_reg, sym.sym_type_ref), span_default())
        @end
      @end
    @else
      infer_var_declaration(tc.tc_infer_ctx, target_name, val_expr, 0, span_default())
      fn_sid = scope_get_enclosing_function_id(tc.tc_scopes)
      target_scope_id = tc.tc_scopes.stk_current_id
      @if fn_sid >= 0
        target_scope_id = fn_sid
      @end
      new_sym = symbol_variable(target_name, rhs_t, 0, span_default(), target_scope_id)
      scope_define_in_scope_id(tc.tc_scopes, target_scope_id, new_sym)
      symtab_put(tc.tc_symtab, new_sym)
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
    @if expected_t > 0 && expected_t != TYPE_ID_ANY()
      is_ok = type_is_assignable(tc.tc_reg, expected_t, actual_ret_t)
      // WHY: Allow i64 <-> bool assignability for returns since boolean is represented as 0/1 in silicon register %rax
      @if (expected_t == TYPE_ID_I64() && actual_ret_t == TYPE_ID_BOOL()) || (expected_t == TYPE_ID_BOOL() && actual_ret_t == TYPE_ID_I64())
        is_ok = 1
      @end
      @if is_ok == 0
        tc_error(tc, ERR_RETURN_TYPE_MISMATCH(), "Function '" + tc.tc_current_fn_name + "' expected return type " + type_to_string(tc.tc_reg, expected_t) + ", but returned " + type_to_string(tc.tc_reg, actual_ret_t), span_default())
      @end
    @end
    return 1
  @end

  // 3. If Statement
  @if str_eq(k, "If") == 1 || str_eq(k, "IfStmt") == 1
    cond_node = stmt.condition
    @if cond_node == 0 cond_node = stmt.cond @end
    @if cond_node != 0
      c_type = tc_check_expr(tc, cond_node)
      @if c_type != TYPE_ID_BOOL() && type_is_numeric(tc.tc_reg, c_type) == 0 && c_type != TYPE_ID_ANY() && c_type != TYPE_ID_UNKNOWN() && c_type != 0
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
  @if str_eq(k, "While") == 1 || str_eq(k, "WhileLoop") == 1
    cond_node = stmt.condition
    @if cond_node == 0 cond_node = stmt.cond @end
    @if cond_node != 0
      c_type = tc_check_expr(tc, cond_node)
      @if c_type != TYPE_ID_BOOL() && type_is_numeric(tc.tc_reg, c_type) == 0 && c_type != TYPE_ID_ANY() && c_type != TYPE_ID_UNKNOWN() && c_type != 0
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

  // 4b. For Loop Statement
  @if str_eq(k, "For") == 1 || str_eq(k, "ForLoop") == 1
    // WHY: Type check iterable expression and define induction variable in loop body scope
    iter_node = stmt.iterable
    @if iter_node == 0 iter_node = stmt.iter @end
    @if iter_node != 0
      tc_check_expr(tc, iter_node)
    @end

    scope_stack_push(tc.tc_scopes, SCOPE_BLOCK(), "for_loop")
    scope_set_loop(tc.tc_scopes, 1)

    // Define induction variable in loop scope as i64
    var_name = stmt.variable
    @if var_name != ""
      ind_sym = symbol_variable(var_name, TYPE_ID_I64(), 0, span_default(), tc.tc_scopes.stk_current_id)
      scope_define(tc.tc_scopes, ind_sym)
    @end

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
  // WHY: Checks the underlying expression within the expression statement wrapper
  @if str_eq(k, "ExprStmt") == 1 || str_eq(k, "ExpressionStmt") == 1
    @if stmt.expr != 0
      tc_check_expr(tc, stmt.expr)
    @end
    return 1
  @end

  tc_check_expr(tc, stmt)
  return 1
@end

// ── 5. FUNCTION & PROGRAM VERIFICATION ───────────────────────────────────────

@fn tc_declare_function(tc, fn_node)
  // WHY: First pass registers function prototype in symbol table enabling forward calls and mutual recursion.
  fn_name = fn_node.name

  param_types = []
  i = 0
  n = fn_node.params.len()
  @while i < n
    param = fn_node.params[i]
    p_type_id = TYPE_ID_ANY()
    p_t_str = ""
    @if param != 0
      @if param.param_type != ""
        p_t_str = param.param_type
      @elif param.ret_type != ""
        p_t_str = param.ret_type
      @elif param.type_name != ""
        p_t_str = param.type_name
      @end
    @end
    @if p_t_str != ""
      @if str_eq(p_t_str, "i64") == 1 || str_eq(p_t_str, "int") == 1 || str_eq(p_t_str, "i32") == 1 || str_eq(p_t_str, "u64") == 1 || str_eq(p_t_str, "u32") == 1 || str_eq(p_t_str, "সংখ্যা") == 1 || str_eq(p_t_str, "পূর্ণসংখ্যা") == 1 p_type_id = TYPE_ID_I64() @end
      @if str_eq(p_t_str, "f64") == 1 || str_eq(p_t_str, "float") == 1 || str_eq(p_t_str, "দশমিক") == 1 p_type_id = TYPE_ID_F64() @end
      @if str_eq(p_t_str, "bool") == 1 || str_eq(p_t_str, "boolean") == 1 || str_eq(p_t_str, "বুলিয়ান") == 1 p_type_id = TYPE_ID_BOOL() @end
      @if str_eq(p_t_str, "string") == 1 || str_eq(p_t_str, "str") == 1 || str_eq(p_t_str, "স্ট্রিং") == 1 || str_eq(p_t_str, "বর্ণমালা") == 1 p_type_id = TYPE_ID_STRING() @end
      @if str_eq(p_t_str, "byte") == 1 || str_eq(p_t_str, "বাইট") == 1 p_type_id = TYPE_ID_BYTE() @end
      @if str_eq(p_t_str, "any") == 1 || str_eq(p_t_str, "যেকোনো") == 1 p_type_id = TYPE_ID_ANY() @end
      @if p_type_id == TYPE_ID_ANY()
        st_sym = symtab_get(tc.tc_symtab, p_t_str)
        @if st_sym != 0 && st_sym.sym_kind == SYM_KIND_STRUCT()
          p_type_id = st_sym.sym_type_ref
        @end
      @end
    @end
    param_types = param_types.push(p_type_id)
    i = i + 1
  @end

  ret_type_id = TYPE_ID_ANY()
  @if fn_node.ret_type != ""
    @if str_eq(fn_node.ret_type, "void") == 1 || str_eq(fn_node.ret_type, "শূন্য") == 1 ret_type_id = TYPE_ID_VOID() @end
    @if str_eq(fn_node.ret_type, "i64") == 1 || str_eq(fn_node.ret_type, "int") == 1 || str_eq(fn_node.ret_type, "i32") == 1 || str_eq(fn_node.ret_type, "u64") == 1 || str_eq(fn_node.ret_type, "u32") == 1 || str_eq(fn_node.ret_type, "সংখ্যা") == 1 || str_eq(fn_node.ret_type, "পূর্ণসংখ্যা") == 1 ret_type_id = TYPE_ID_I64() @end
    @if str_eq(fn_node.ret_type, "f64") == 1 || str_eq(fn_node.ret_type, "float") == 1 || str_eq(fn_node.ret_type, "দশমিক") == 1 ret_type_id = TYPE_ID_F64() @end
    @if str_eq(fn_node.ret_type, "bool") == 1 || str_eq(fn_node.ret_type, "boolean") == 1 || str_eq(fn_node.ret_type, "বুলিয়ান") == 1 ret_type_id = TYPE_ID_BOOL() @end
    @if str_eq(fn_node.ret_type, "string") == 1 || str_eq(fn_node.ret_type, "str") == 1 || str_eq(fn_node.ret_type, "স্ট্রিং") == 1 || str_eq(fn_node.ret_type, "বর্ণমালা") == 1 ret_type_id = TYPE_ID_STRING() @end
    @if str_eq(fn_node.ret_type, "byte") == 1 || str_eq(fn_node.ret_type, "বাইট") == 1 ret_type_id = TYPE_ID_BYTE() @end
  @end

  fn_type_id = type_make_function(tc.tc_reg, param_types, ret_type_id)
  fn_sym = symbol_function(fn_name, fn_type_id, span_default(), tc.tc_scopes.stk_current_id, 1)
  scope_define(tc.tc_scopes, fn_sym)
  symtab_put(tc.tc_symtab, fn_sym)
  return fn_sym
@end

@fn tc_check_function_body(tc, fn_node)
  // WHY: Checks statement semantics and local variable scopes inside the function body.
  fn_name = fn_node.name
  f_sym = symtab_get(tc.tc_symtab, fn_name)
  ret_type_id = TYPE_ID_ANY()
  param_types = []
  @if f_sym != 0
    f_type = type_registry_get(tc.tc_reg, f_sym.sym_type_ref)
    @if f_type != 0
      ret_type_id = f_type.ty_ret_type_id
      param_types = f_type.ty_param_types
    @end
  @end

  scope_stack_push(tc.tc_scopes, SCOPE_FUNCTION(), fn_name)
  curr_sc = scope_stack_current(tc.tc_scopes)
  curr_sc.sc_ret_type = ret_type_id

  prev_fn_ret = tc.tc_current_fn_ret_type
  prev_fn_name = tc.tc_current_fn_name
  tc.tc_current_fn_ret_type = ret_type_id
  tc.tc_current_fn_name = fn_name

  j = 0
  n = fn_node.params.len()
  @while j < n
    param = fn_node.params[j]
    p_name = ""
    @if param != 0
      p_name = param.param_name
      @if len(p_name) == 0 p_name = param.name @end
    @end
    p_tid = TYPE_ID_ANY()
    @if j < param_types.len() p_tid = param_types[j] @end
    p_sym = symbol_parameter(p_name, p_tid, span_default(), tc.tc_scopes.stk_current_id)
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

@fn tc_check_function_def(tc, fn_node)
  tc_declare_function(tc, fn_node)
  return tc_check_function_body(tc, fn_node)
@end

@fn tc_check_struct_def(tc, struct_node)
  s_name = struct_node.name
  fields = []
  i = 0
  elems = struct_node.elements
  @if elems == 0 || elems.len() == 0
    elems = struct_node.params
  @end
  @if elems != 0
    n = elems.len()
    @while i < n
      f_node = elems[i]
      f_t_id = TYPE_ID_ANY()
      f_t_str = f_node.ret_type
      @if len(f_t_str) == 0 f_t_str = f_node.field_type @end
      @if str_eq(f_t_str, "i64") == 1 || str_eq(f_t_str, "int") == 1 || str_eq(f_t_str, "i32") == 1 || str_eq(f_t_str, "u64") == 1 || str_eq(f_t_str, "u32") == 1 || str_eq(f_t_str, "সংখ্যা") == 1 || str_eq(f_t_str, "পূর্ণসংখ্যা") == 1 f_t_id = TYPE_ID_I64() @end
      @if str_eq(f_t_str, "f64") == 1 || str_eq(f_t_str, "float") == 1 || str_eq(f_t_str, "দশমিক") == 1 f_t_id = TYPE_ID_F64() @end
      @if str_eq(f_t_str, "bool") == 1 || str_eq(f_t_str, "boolean") == 1 || str_eq(f_t_str, "বুলিয়ান") == 1 f_t_id = TYPE_ID_BOOL() @end
      @if str_eq(f_t_str, "string") == 1 || str_eq(f_t_str, "str") == 1 || str_eq(f_t_str, "স্ট্রিং") == 1 || str_eq(f_t_str, "বর্ণমালা") == 1 f_t_id = TYPE_ID_STRING() @end
      @if str_eq(f_t_str, "byte") == 1 || str_eq(f_t_str, "বাইট") == 1 f_t_id = TYPE_ID_BYTE() @end

      f_name = f_node.name
      @if len(f_name) == 0 f_name = f_node.field_name @end
      f_def = type_make_field(f_name, f_t_id, 0, 8, 1)
      fields = fields.push(f_def)
      i = i + 1
    @end
  @end

  struct_type_id = type_make_struct(tc.tc_reg, s_name, fields)
  s_sym = symbol_struct(s_name, struct_type_id, span_default(), tc.tc_scopes.stk_current_id)
  scope_define(tc.tc_scopes, s_sym)
  symtab_put(tc.tc_symtab, s_sym)
  return struct_type_id
@end

@fn tc_check_program(tc, statements)
  @if statements == 0 return 1 @end

  n = statements.len()
  // Pass 1: Struct definitions and top-level global variables registered in global symbol table
  i = 0
  @while i < n
    st = statements[i]
    @if str_eq(st.kind, "StructDef") == 1
      tc_check_struct_def(tc, st)
    @elif str_eq(st.kind, "Assign") == 1 || str_eq(st.kind, "VarDecl") == 1
      v_name = st.target
      @if v_name != ""
        v_sym = symbol_variable(v_name, TYPE_ID_ANY(), 0, span_default(), tc.tc_scopes.stk_current_id)
        scope_define(tc.tc_scopes, v_sym)
        symtab_put(tc.tc_symtab, v_sym)
      @end
    @elif (str_eq(st.kind, "FnDef") == 1 || str_eq(st.kind, "Function") == 1) && (str_eq(st.name, "main") == 1 || str_eq(st.name, "মূল") == 1)
      b_idx = 0
      b_len = st.body.len()
      @while b_idx < b_len
        b_st = st.body[b_idx]
        @if str_eq(b_st.kind, "Assign") == 1 || str_eq(b_st.kind, "VarDecl") == 1
          v_name = b_st.target
          @if v_name != ""
            v_sym = symbol_variable(v_name, TYPE_ID_ANY(), 0, span_default(), tc.tc_scopes.stk_current_id)
            scope_define(tc.tc_scopes, v_sym)
            symtab_put(tc.tc_symtab, v_sym)
          @end
        @end
        b_idx = b_idx + 1
      @end
    @end
    i = i + 1
  @end

  // Pass 2: Function signature forward declarations (enables mutual recursion and forward calls)
  j = 0
  @while j < n
    st = statements[j]
    @if str_eq(st.kind, "FnDef") == 1 || str_eq(st.kind, "Function") == 1
      tc_declare_function(tc, st)
    @end
    j = j + 1
  @end

  // Pass 3: Verification of function bodies and standalone top-level statements
  k = 0
  @while k < n
    st = statements[k]
    @if str_eq(st.kind, "FnDef") == 1 || str_eq(st.kind, "Function") == 1
      tc_check_function_body(tc, st)
    @elif str_eq(st.kind, "StructDef") == 0
      tc_check_statement(tc, st)
    @end
    k = k + 1
  @end

  return tc_has_errors(tc) == 0
@end
