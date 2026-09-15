// ============================================================================
// LIPI FRONTEND COMPILER — CHAR STREAM ENGINE
// Module: src/compiler/frontend/lexer/char_stream.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Lexical scanners require deterministic byte-level and codepoint-level lookahead
//    to disambiguate multi-byte UTF-8 sequences (specifically Bengali runes U+0980..U+09FF)
//    without incurring redundant allocations or string copies.
// 2. Exact source location tracking (1-indexed line and column, byte offset) is mandatory
//    for diagnostic spans, bilingual syntax error reporting, and IDE Language Server Protocol (LSP).
// 3. Zero-Collision Struct Schema: All struct fields use unique prefixes (pos_, cs_)
//    to guarantee deterministic offset resolution across untyped compiler call boundaries.
//
// UTF-8 ENCODING ARCHITECTURE:
// - 1-byte (0x00..0x7F): Standard ASCII range.
// - 2-byte (0xC0..0xDF): Extended Latin, Greek, Cyrillic, Arabic.
// - 3-byte (0xE0..0xEF): Indic scripts including 100% of Bengali Unicode block (0x0980..0x09FF).
// - 4-byte (0xF0..0xF7): Supplementary planes (emojis, ancient symbols).
// ============================================================================

import "universe/core/string"
import "universe/core/collections"

// ── 1. Data Structures ────────────────────────────────────────────────────────

// WHY: Source position structure capturing exact coordinates in the source buffer
@struct CharPos
  pos_offset: i64
  pos_line: i64
  pos_col: i64
@end

// WHY: Buffered character stream keeping source buffer, boundary length, and cursor state
@struct CharStream
  cs_source: string
  cs_pos: i64
  cs_len: i64
  cs_line: i64
  cs_col: i64
@end

// ── 2. Constructors & Position Queries ────────────────────────────────────────

@fn char_pos_new(offset: i64, line: i64, col: i64)
  // WHY: Constructs an immutable snapshot of current lexical position
  return {
    pos_offset: offset,
    pos_line: line,
    pos_col: col
  }
@end

@fn char_stream_new(source: string)
  // WHY: Initializes a fresh UTF-8 stream at line 1, column 1, offset 0
  n = str_len(source)
  return {
    cs_source: source,
    cs_pos: 0,
    cs_len: n,
    cs_line: 1,
    cs_col: 1
  }
@end

@fn char_stream_is_eof(stream: CharStream)
  // WHY: O(1) EOF check comparing current byte position against total source length
  @if stream.cs_pos >= stream.cs_len
    return 1
  @end
  return 0
@end

@fn char_stream_get_pos(stream: CharStream)
  // WHY: Captures current stream coordinates for span building
  return char_pos_new(stream.cs_pos, stream.cs_line, stream.cs_col)
@end

@fn char_stream_remaining(stream: CharStream)
  // WHY: Returns unread byte count in stream
  @if stream.cs_pos >= stream.cs_len
    return 0
  @end
  return stream.cs_len - stream.cs_pos
@end

// ── 3. Byte-Level Operations ──────────────────────────────────────────────────

@fn char_stream_peek_byte(stream: CharStream)
  // WHY: Returns raw byte code at current position without mutating stream cursor
  @if stream.cs_pos >= stream.cs_len
    return 0
  @end
  return str_char_at(stream.cs_source, stream.cs_pos)
@end

@fn char_stream_peek_byte_ahead(stream: CharStream, offset: i64)
  // WHY: Lookahead by arbitrary byte offset k for multi-character operator disambiguation
  target = stream.cs_pos + offset
  @if target >= stream.cs_len || target < 0
    return 0
  @end
  return str_char_at(stream.cs_source, target)
@end

@fn char_stream_advance_byte(stream: CharStream)
  // WHY: Consumes single byte, maintaining line and column invariants.
  // ASCII newline (0x0A) resets column to 1 and increments line counter.
  @if stream.cs_pos >= stream.cs_len
    return 0
  @end
  b = str_char_at(stream.cs_source, stream.cs_pos)
  stream.cs_pos = stream.cs_pos + 1

  @if b == 10 // ASCII LF (\n)
    stream.cs_line = stream.cs_line + 1
    stream.cs_col = 1
  @else
    stream.cs_col = stream.cs_col + 1
  @end

  return b
@end

// ── 4. UTF-8 Codepoint / Rune Operations ──────────────────────────────────────

@fn char_stream_peek_rune_size(stream: CharStream)
  // WHY: Inspects leading UTF-8 byte bit-pattern to determine codepoint byte length (1 to 4)
  @if stream.cs_pos >= stream.cs_len
    return 0
  @end
  b0 = str_char_at(stream.cs_source, stream.cs_pos)
  @if b0 < 128
    return 1 // Standard ASCII
  @elif (b0 >= 192) && (b0 <= 223)
    return 2 // 2-byte sequence
  @elif (b0 >= 224) && (b0 <= 239)
    return 3 // 3-byte sequence (includes all Bengali characters)
  @elif (b0 >= 240) && (b0 <= 247)
    return 4 // 4-byte sequence (SMP / Emojis)
  @end
  return 1 // Fallback for continuation/invalid byte to avoid deadloop
@end

@fn char_stream_peek_rune(stream: CharStream)
  // WHY: Decodes full UTF-8 codepoint (rune) at current cursor without advancing.
  // Ensures seamless parsing of Bengali runes (e.g. 0x0995 'ক' -> 2453 decimal).
  @if stream.cs_pos >= stream.cs_len
    return 0
  @end

  b0 = str_char_at(stream.cs_source, stream.cs_pos)

  // 1-Byte ASCII
  @if b0 < 128
    return b0
  @end

  // 2-Byte Sequence (0xC0..0xDF)
  @if (b0 >= 192) && (b0 <= 223)
    @if stream.cs_pos + 1 >= stream.cs_len
      return b0
    @end
    b1 = str_char_at(stream.cs_source, stream.cs_pos + 1)
    cp = ((b0 - 192) * 64) + (b1 - 128)
    return cp
  @end

  // 3-Byte Sequence (0xE0..0xEF) — Primary Bengali Block
  @if (b0 >= 224) && (b0 <= 239)
    @if stream.cs_pos + 2 >= stream.cs_len
      return b0
    @end
    b1 = str_char_at(stream.cs_source, stream.cs_pos + 1)
    b2 = str_char_at(stream.cs_source, stream.cs_pos + 2)
    cp = ((b0 - 224) * 4096) + ((b1 - 128) * 64) + (b2 - 128)
    return cp
  @end

  // 4-Byte Sequence (0xF0..0xF7)
  @if (b0 >= 240) && (b0 <= 247)
    @if stream.cs_pos + 3 >= stream.cs_len
      return b0
    @end
    b1 = str_char_at(stream.cs_source, stream.cs_pos + 1)
    b2 = str_char_at(stream.cs_source, stream.cs_pos + 2)
    cp = ((b0 - 240) * 262144) + ((b1 - 128) * 4096) + ((b2 - 128) * 64) + (b3 - 128)
    return cp
  @end

  return b0
@end

@fn char_stream_advance_rune(stream: CharStream)
  // WHY: Consumes full UTF-8 codepoint (1 to 4 bytes) and advances column by exactly 1 rune.
  // Treats newline as line increment and column reset to 1.
  @if stream.cs_pos >= stream.cs_len
    return 0
  @end

  rune = char_stream_peek_rune(stream)
  rune_size = char_stream_peek_rune_size(stream)

  @if rune == 10 // ASCII LF (\n)
    stream.cs_pos = stream.cs_pos + 1
    stream.cs_line = stream.cs_line + 1
    stream.cs_col = 1
  @else
    stream.cs_pos = stream.cs_pos + rune_size
    stream.cs_col = stream.cs_col + 1
  @end

  return rune
@end

// ── 5. Slicing & Extraction ───────────────────────────────────────────────────

@fn char_stream_slice(stream: CharStream, start_offset: i64, end_offset: i64)
  // WHY: Extracts zero-copy string slice directly from source text between offsets
  @if start_offset < 0
    start_offset = 0
  @end
  @if end_offset > stream.cs_len
    end_offset = stream.cs_len
  @end
  @if start_offset >= end_offset
    return ""
  @end
  return str_slice(stream.cs_source, start_offset, end_offset)
@end

@fn char_stream_slice_from(stream: CharStream, start_offset: i64)
  // WHY: Extracts slice from starting offset up to current stream position
  return char_stream_slice(stream, start_offset, stream.cs_pos)
@end
