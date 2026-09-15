// ============================================================================
// LIPI FRONTEND COMPILER — TOKEN & SOURCE SPAN MODEL
// Module: src/compiler/frontend/lexer/token.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Tokens represent the fundamental atomic units produced by lexical analysis.
// 2. High-precision source span tracking (file path, starting/ending line, column,
//    and byte offset) is vital for actionable compiler diagnostics, syntax highlighting,
//    and source mapping.
// 3. Tokens carry precomputed literal values (integer and IEEE-754 floating point)
//    to eliminate redundant string-to-number parsing in the compiler's semantic stages.
// 4. Zero-Collision Struct Schema: All struct fields use unique prefixes (span_, tok_)
//    to guarantee deterministic offset resolution across untyped compiler call boundaries.
// ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/lexer/token_kind"

// ── 1. Source Span Data Structure ─────────────────────────────────────────────

// WHY: SourceSpan models a precise 2D region within a source file
@struct SourceSpan
  span_file: string
  span_start_line: i64
  span_start_col: i64
  span_start_offset: i64
  span_end_line: i64
  span_end_col: i64
  span_end_offset: i64
@end

// ── 2. Token Data Structure ───────────────────────────────────────────────────

// WHY: Core Token struct containing kind enum, text representation, pre-parsed values, and span
@struct Token
  tok_kind: i64
  tok_kind_name: string
  tok_text: string
  tok_int_val: i64
  tok_float_val: f64
  tok_span: SourceSpan
@end

// ── 3. SourceSpan Constructors & Operations ───────────────────────────────────

@fn source_span_new(file: string, sl: i64, sc: i64, so: i64, el: i64, ec: i64, eo: i64)
  // WHY: Constructs an explicit start-to-end span bounding a token or AST node
  return {
    span_file: file,
    span_start_line: sl,
    span_start_col: sc,
    span_start_offset: so,
    span_end_line: el,
    span_end_col: ec,
    span_end_offset: eo
  }
@end

@fn source_span_zero()
  // WHY: Returns a canonical zero span for synthetic or compiler-generated tokens
  return {
    span_file: "",
    span_start_line: 0,
    span_start_col: 0,
    span_start_offset: 0,
    span_end_line: 0,
    span_end_col: 0,
    span_end_offset: 0
  }
@end

@fn source_span_point(file: string, line: i64, col: i64, offset: i64)
  // WHY: Constructs a single-point span where start and end coordinates coincide
  return {
    span_file: file,
    span_start_line: line,
    span_start_col: col,
    span_start_offset: offset,
    span_end_line: line,
    span_end_col: col,
    span_end_offset: offset
  }
@end

@fn source_span_merge(s1: SourceSpan, s2: SourceSpan)
  // WHY: Spans the contiguous region from start of s1 to end of s2
  file = s1.span_file
  @if file == ""
    file = s2.span_file
  @end
  return {
    span_file: file,
    span_start_line: s1.span_start_line,
    span_start_col: s1.span_start_col,
    span_start_offset: s1.span_start_offset,
    span_end_line: s2.span_end_line,
    span_end_col: s2.span_end_col,
    span_end_offset: s2.span_end_offset
  }
@end

// ── 4. Token Constructors ─────────────────────────────────────────────────────

@fn token_new(kind: i64, kind_name: string, text: string, int_val: i64, float_val: f64, span: SourceSpan)
  // WHY: Canonical token constructor with all metadata populated
  return {
    tok_kind: kind,
    tok_kind_name: kind_name,
    tok_text: text,
    tok_int_val: int_val,
    tok_float_val: float_val,
    tok_span: span
  }
@end

@fn token_new_simple(kind: i64, text: string, line: i64, col: i64)
  // WHY: Simplified constructor for single-line tokens with synthetic span
  span = source_span_point("", line, col, 0)
  name = token_kind_name(kind)
  return {
    tok_kind: kind,
    tok_kind_name: name,
    tok_text: text,
    tok_int_val: 0,
    tok_float_val: 0.0,
    tok_span: span
  }
@end

@fn token_eof(file: string, line: i64, col: i64, offset: i64)
  // WHY: Produces canonical EOF token marking terminal boundary of source stream
  span = source_span_point(file, line, col, offset)
  return {
    tok_kind: TOK_EOF(),
    tok_kind_name: "EOF",
    tok_text: "",
    tok_int_val: 0,
    tok_float_val: 0.0,
    tok_span: span
  }
@end

// ── 5. Token Field Accessors & Inspectors ─────────────────────────────────────

@fn tok_kind(tok: Token)
  @if tok == 0 return TOK_EOF() @end
  return tok.tok_kind
@end

@fn tok_type(tok: Token)
  // WHY: Alias for kind_name providing compatibility with existing compiler frontend
  @if tok == 0 return "EOF" @end
  return tok.tok_kind_name
@end

@fn tok_text(tok: Token)
  @if tok == 0 return "" @end
  return tok.tok_text
@end

@fn tok_val(tok: Token)
  // WHY: Value string alias for parser compatibility
  @if tok == 0 return "" @end
  return tok.tok_text
@end

@fn tok_int(tok: Token)
  @if tok == 0 return 0 @end
  return tok.tok_int_val
@end

@fn tok_float(tok: Token)
  @if tok == 0 return 0.0 @end
  return tok.tok_float_val
@end

@fn tok_line(tok: Token)
  @if tok == 0 return 0 @end
  return tok.tok_span.span_start_line
@end

@fn tok_col(tok: Token)
  @if tok == 0 return 0 @end
  return tok.tok_span.span_start_col
@end

@fn token_to_string(tok: Token)
  // WHY: Diagnostic string representation for debugging and token dumping
  @if tok == 0 return "<null token>" @end
  s = "[" + tok.tok_kind_name + " '" + tok.tok_text + "' at " + to_str(tok.tok_span.span_start_line) + ":" + to_str(tok.tok_span.span_start_col) + "]"
  return s
@end
