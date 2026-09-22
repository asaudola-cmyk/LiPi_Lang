// ============================================================================
// LIPI FRONTEND COMPILER — DOC COMMENT & COMMENT SCANNER
// Module: src/compiler/frontend/lexer/comment_doc.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. First-class documentation generator (lipidoc) and IDE hover tools (lipilsp)
//    require pristine extraction of doc comments (`///` and `/** ... */`)
//    attached to preceding functions, structs, and variables.
// 2. Regular compiler comments (`//`, `@!`, `/* ... */`) must be distinguished from
//    doc comments so the lexer can either discard them or emit TOK_COMMENT_DOC
//    tokens for AST documentation binding.
// 3. Multiline block doc comments (`/** ... */`) must normalize Markdown formatting
//    by stripping leading asterisk (`*`) decoration margins from each line.
// 4. Zero-Collision Struct Schema: All fields use `comm_` prefix to guarantee 100%
//    safe field offset resolution across untyped compiler call boundaries.
// ============================================================================

import "universe/core/string"
import "universe/core/collections"

// ── 1. Result Data Structure ──────────────────────────────────────────────────

// WHY: Structured descriptor returned when parsing any line or block comment with zero-collision schema
@struct CommentResult
  comm_is_doc: i64           // 1 if '///' or '/**', 0 if normal comment
  comm_is_block: i64         // 1 if multiline block, 0 if single line
  comm_content: string       // Normalized documentation content (stripped of delimiters)
  comm_raw_text: string      // Full raw comment text as appeared in source
  comm_consumed: i64         // Total bytes spanned by comment
  comm_lines_consumed: i64   // Number of newlines crossed
@end

// ── 2. Line Comment Parser (//, ///, @!) ──────────────────────────────────────

@fn comment_parse_line(source: string, start_pos: i64)
  // WHY: Inspects line comment starting at start_pos.
  // Detects whether prefix is '///' (doc comment), '//' (normal), or '@!' (compiler internal comment).
  num_items = str_len(source)
  @if start_pos >= num_items
    return { comm_is_doc: 0, comm_is_block: 0, comm_content: "", comm_raw_text: "", comm_consumed: 0, comm_lines_consumed: 0 }
  @end

  c0 = str_char_at(source, start_pos)
  c1 = 0
  @if start_pos + 1 < num_items
    c1 = str_char_at(source, start_pos + 1)
  @end

  is_triple_slash = 0
  prefix_len = 2

  // Check '///' vs '//'
  @if c0 == 47 && c1 == 47 // '//'
    @if start_pos + 2 < num_items && str_char_at(source, start_pos + 2) == 47
      is_triple_slash = 1
      prefix_len = 3
    @end
  @elif c0 == 64 && c1 == 33 // '@!' internal directive comment
    prefix_len = 2
  @else
    // Not a valid line comment start
    return { comm_is_doc: 0, comm_is_block: 0, comm_content: "", comm_raw_text: "", comm_consumed: 0, comm_lines_consumed: 0 }
  @end

  // Scan until LF (\n) or EOF
  i = start_pos + prefix_len
  content_start = i

  // If doc comment and followed by single space ' ', skip the decorative space
  @if is_triple_slash == 1 && i < num_items && str_char_at(source, i) == 32
    content_start = i + 1
  @end

  @while i < num_items && str_char_at(source, i) != 10 && str_char_at(source, i) != 13
    i = i + 1
  @end

  doc_content = ""
  @if is_triple_slash == 1
    doc_content = str_slice(source, content_start, i)
  @end

  raw_str = str_slice(source, start_pos, i)
  consumed = i - start_pos

  return {
    comm_is_doc: is_triple_slash,
    comm_is_block: 0,
    comm_content: doc_content,
    comm_raw_text: raw_str,
    comm_consumed: consumed,
    comm_lines_consumed: 0
  }
@end

// ── 3. Block Comment Parser (/* ... */, /** ... */) ───────────────────────────

@fn comment_parse_block(source: string, start_pos: i64)
  // WHY: Scans multiline comment starting at '/*'.
  // Detects whether it is '/**' (doc block) or '/*' (standard block).
  // Normalizes Markdown margins by stripping decorative leading '*' characters.
  num_items = str_len(source)
  @if start_pos + 1 >= num_items
    return { comm_is_doc: 0, comm_is_block: 1, comm_content: "", comm_raw_text: "", comm_consumed: 0, comm_lines_consumed: 0 }
  @end

  c0 = str_char_at(source, start_pos)
  c1 = str_char_at(source, start_pos + 1)
  @if c0 != 47 || c1 != 42 // Not '/*'
    return { comm_is_doc: 0, comm_is_block: 1, comm_content: "", comm_raw_text: "", comm_consumed: 0, comm_lines_consumed: 0 }
  @end

  is_doc_block = 0
  prefix_len = 2

  // Check '/**' doc block prefix
  @if start_pos + 2 < num_items && str_char_at(source, start_pos + 2) == 42
    // Check it's not immediately closing '/***/'
    @if start_pos + 3 < num_items && str_char_at(source, start_pos + 3) != 47
      is_doc_block = 1
      prefix_len = 3
    @end
  @end

  i = start_pos + prefix_len
  lines_count = 0

  // Scan until closing '*/' or EOF
  @while i + 1 < num_items && (str_char_at(source, i) != 42 || str_char_at(source, i + 1) != 47)
    cur = str_char_at(source, i)
    @if cur == 10 // LF
      lines_count = lines_count + 1
    @end
    i = i + 1
  @end

  raw_inner = str_slice(source, start_pos + prefix_len, i)

  // Consume closing '*/'
  @if i + 1 < num_items
    i = i + 2
  @end

  full_raw = str_slice(source, start_pos, i)
  consumed = i - start_pos

  // Normalize doc block content: strip decorative asterisks from line starts
  normalized = ""
  @if is_doc_block == 1
    normalized = comment_normalize_block_doc(raw_inner)
  @end

  return {
    comm_is_doc: is_doc_block,
    comm_is_block: 1,
    comm_content: normalized,
    comm_raw_text: full_raw,
    comm_consumed: consumed,
    comm_lines_consumed: lines_count
  }
@end

// ── 4. Block Doc Normalizer ───────────────────────────────────────────────────

@fn comment_normalize_block_doc(text: string)
  // WHY: Strips leading '*' and indentation on each line of a multiline doc comment
  // so the resulting Markdown text is clean for documentation tooling.
  n = str_len(text)
  @if n == 0 return "" @end

  result = ""
  i = 0
  at_line_start = 1

  @while i < n
    c = str_char_at(text, i)
    @if at_line_start == 1
      // Skip leading spaces and tabs
      @while i < n && (str_char_at(text, i) == 32 || str_char_at(text, i) == 9)
        i = i + 1
      @end
      // Skip leading '*'
      @if i < n && str_char_at(text, i) == 42
        i = i + 1
        // Skip space following '*'
        @if i < n && str_char_at(text, i) == 32
          i = i + 1
        @end
      @end
      at_line_start = 0
    @end

    @if i < n
      cur = str_char_at(text, i)
      result = result + chr(cur)
      @if cur == 10 // Newline resets line start state
        at_line_start = 1
      @end
      i = i + 1
    @end
  @end

  return result
@end
