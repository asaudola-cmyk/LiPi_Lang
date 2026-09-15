// ============================================================================
// LIPI FRONTEND COMPILER — STRING LITERAL & ESCAPE DECODER
// Module: src/compiler/frontend/lexer/str_literal.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Strings in Lipi can contain standard C escapes, hex byte escapes (\xHH),
//    and 4-digit Unicode escapes (\uHHHH) including Bengali runes (e.g. \u0995 -> ক).
// 2. String interpolation: double-quoted strings supporting `{variable}` interpolation
//    must be tagged with `str_has_interp = 1` so the parser can desugar them into
//    string concatenations or template formatting nodes.
// 3. Exact raw text vs decoded text preservation is needed for source maps, LSP hovering,
//    and deterministic bytecode/constant pool generation.
// 4. Zero-Collision Struct Schema: All fields use `str_` and `esc_` prefixes to guarantee
//    100% safe field offset resolution across untyped compiler call boundaries.
// ============================================================================

import "universe/core/string"
import "universe/core/collections"

// ── 1. Result Structures ──────────────────────────────────────────────────────

// WHY: Result of decoding a single escape sequence within a string
@struct EscapeDecodeResult
  esc_char_str: string
  esc_next_pos: i64
@end

// WHY: Container for the complete string literal parse result with zero-collision schema
@struct StrDecodeResult
  str_decoded_text: string
  str_raw_text: string
  str_has_interp: i64
  str_is_terminated: i64
  str_consumed: i64
  str_lines_consumed: i64
  str_end_col: i64
@end

// ── 2. Hexadecimal Conversion Helpers ─────────────────────────────────────────

@fn str_hex_val(c: i64)
  // WHY: Returns nibble value [0..15] for ASCII hex char, or -1 if invalid
  @if c >= 48 && c <= 57 return c - 48 @end
  @if c >= 97 && c <= 102 return c - 97 + 10 @end
  @if c >= 65 && c <= 70 return c - 65 + 10 @end
  return -1
@end

@fn str_codepoint_to_utf8(cp: i64)
  // WHY: Encodes any 16-bit Unicode scalar value (U+0000..U+FFFF) into valid UTF-8 bytes
  // using native chr() calls. Ensures \u0995 emits exact 3-byte Bengali 'ক'.
  @if cp < 128
    return chr(cp)
  @elif cp < 2048
    b1 = 192 + (cp / 64)
    b2 = 128 + (cp % 64)
    return chr(b1) + chr(b2)
  @else
    b1 = 224 + (cp / 4096)
    b2 = 128 + ((cp / 64) % 64)
    b3 = 128 + (cp % 64)
    return chr(b1) + chr(b2) + chr(b3)
  @end
@end

// ── 3. Single Escape Sequence Decoder ─────────────────────────────────────────

@fn str_decode_escape(source: string, pos: i64, num_items: i64)
  // WHY: Decodes the escape character following a backslash '\' at `pos`.
  // Supports: \n, \t, \r, \0, \e, \a, \b, \f, \v, \\, \", \', \xHH, \uHHHH.
  @if pos >= num_items
    return { esc_char_str: "", esc_next_pos: pos }
  @end

  esc_c = str_char_at(source, pos)

  // Standard C Escapes
  @if esc_c == 110 // 'n' -> LF (0x0A)
    return { esc_char_str: chr(10), esc_next_pos: pos + 1 }
  @elif esc_c == 116 // 't' -> Tab (0x09)
    return { esc_char_str: chr(9), esc_next_pos: pos + 1 }
  @elif esc_c == 114 // 'r' -> CR (0x0D)
    return { esc_char_str: chr(13), esc_next_pos: pos + 1 }
  @elif esc_c == 101 // 'e' -> ESC (0x1B)
    return { esc_char_str: chr(27), esc_next_pos: pos + 1 }
  @elif esc_c == 97  // 'a' -> Bell (0x07)
    return { esc_char_str: chr(7), esc_next_pos: pos + 1 }
  @elif esc_c == 98  // 'b' -> Backspace (0x08)
    return { esc_char_str: chr(8), esc_next_pos: pos + 1 }
  @elif esc_c == 102 // 'f' -> Formfeed (0x0C)
    return { esc_char_str: chr(12), esc_next_pos: pos + 1 }
  @elif esc_c == 118 // 'v' -> Vertical Tab (0x0B)
    return { esc_char_str: chr(11), esc_next_pos: pos + 1 }
  @elif esc_c == 92  // '\\' -> Backslash
    return { esc_char_str: "\\", esc_next_pos: pos + 1 }
  @elif esc_c == 34  // '\"' -> Double Quote
    return { esc_char_str: "\"", esc_next_pos: pos + 1 }
  @elif esc_c == 39  // '\'' -> Single Quote
    return { esc_char_str: "'", esc_next_pos: pos + 1 }

  // Null byte or Octal \0 / \033
  @elif esc_c == 48 // '0'
    @if pos + 2 < num_items
      c1 = str_char_at(source, pos + 1)
      c2 = str_char_at(source, pos + 2)
      @if c1 == 51 && c2 == 51 // \033 -> ESC (0x1B)
        return { esc_char_str: chr(27), esc_next_pos: pos + 3 }
      @end
    @end
    return { esc_char_str: chr(0), esc_next_pos: pos + 1 }

  // Hexadecimal Byte Escape: \xHH (2 hex digits)
  @elif esc_c == 120 && pos + 2 < num_items // 'x'
    h1 = str_hex_val(str_char_at(source, pos + 1))
    h2 = str_hex_val(str_char_at(source, pos + 2))
    @if h1 >= 0 && h2 >= 0
      byte_val = (h1 * 16) + h2
      return { esc_char_str: chr(byte_val), esc_next_pos: pos + 3 }
    @end

  // Unicode 16-bit Escape: \uHHHH (4 hex digits)
  @elif esc_c == 117 && pos + 4 < num_items // 'u'
    u1 = str_hex_val(str_char_at(source, pos + 1))
    u2 = str_hex_val(str_char_at(source, pos + 2))
    u3 = str_hex_val(str_char_at(source, pos + 3))
    u4 = str_hex_val(str_char_at(source, pos + 4))
    @if u1 >= 0 && u2 >= 0 && u3 >= 0 && u4 >= 0
      cp = (u1 * 4096) + (u2 * 256) + (u3 * 16) + u4
      utf8_s = str_codepoint_to_utf8(cp)
      return { esc_char_str: utf8_s, esc_next_pos: pos + 5 }
    @end
  @end

  // Fallback: literal escaped character
  return { esc_char_str: chr(esc_c), esc_next_pos: pos + 1 }
@end

// ── 4. Full String Literal Parser ─────────────────────────────────────────────

@fn str_decode_literal(source: string, start_pos: i64, start_col: i64)
  // WHY: Scans string literal starting at quote character at start_pos.
  // Returns decoded text, raw source representation, interpolation flag, and coordinate diffs.
  num_items = str_len(source)
  @if start_pos >= num_items
    return { str_decoded_text: "", str_raw_text: "", str_has_interp: 0, str_is_terminated: 0, str_consumed: 0, str_lines_consumed: 0, str_end_col: start_col }
  @end

  quote_c = str_char_at(source, start_pos)
  @if quote_c != 34 && quote_c != 39 // Not '"' or '\''
    return { str_decoded_text: "", str_raw_text: "", str_has_interp: 0, str_is_terminated: 0, str_consumed: 0, str_lines_consumed: 0, str_end_col: start_col }
  @end

  quote_str = chr(quote_c)
  raw_text = quote_str
  decoded_text = ""
  has_interp = 0
  lines_consumed = 0
  col = start_col + 1
  i = start_pos + 1

  @while i < num_items && str_char_at(source, i) != quote_c
    cur = str_char_at(source, i)

    // Backslash Escape '\'
    @if cur == 92 && i + 1 < num_items
      esc_res = str_decode_escape(source, i + 1, num_items)
      decoded_text = decoded_text + esc_res.esc_char_str
      // Append raw escape sequence to raw_text
      raw_esc = str_slice(source, i, esc_res.esc_next_pos)
      raw_text = raw_text + raw_esc
      adv = esc_res.esc_next_pos - i
      col = col + adv
      i = esc_res.esc_next_pos

    // Embedded Newline
    @elif cur == 10
      raw_text = raw_text + "\n"
      decoded_text = decoded_text + "\n"
      lines_consumed = lines_consumed + 1
      col = 1
      i = i + 1

    // General Character
    @else
      // Check for interpolation "{var}" in double quotes
      @if quote_c == 34 && cur == 123 && i + 1 < num_items
        next_c = str_char_at(source, i + 1)
        // Check if next character is identifier-like (letter or underscore)
        @if (next_c >= 65 && next_c <= 90) || (next_c >= 97 && next_c <= 122) || next_c == 95 || next_c >= 224
          has_interp = 1
        @end
      @end

      ch_str = chr(cur)
      raw_text = raw_text + ch_str
      decoded_text = decoded_text + ch_str
      col = col + 1
      i = i + 1
    @end
  @end

  // Check matching closing quote
  is_term = 0
  @if i < num_items && str_char_at(source, i) == quote_c
    raw_text = raw_text + quote_str
    is_term = 1
    col = col + 1
    i = i + 1
  @end

  consumed = i - start_pos
  return {
    str_decoded_text: decoded_text,
    str_raw_text: raw_text,
    str_has_interp: has_interp,
    str_is_terminated: is_term,
    str_consumed: consumed,
    str_lines_consumed: lines_consumed,
    str_end_col: col
  }
@end
