// ============================================================================
// LIPI FRONTEND COMPILER — NUMERIC LITERAL PARSER
// Module: src/compiler/frontend/lexer/num_literal.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. LiPi supports bilingual numeric representations: Western numerals (0-9) and
//    native Eastern-Arabic Bengali numerals (০-৯) are parsed natively and interchangeably.
// 2. High-performance literal parsing requires immediate binary value computation
//    for hex (0x/0X), binary (0b/0B), octal (0o/0O), decimal, and IEEE-754 floating point.
// 3. Range operator disambiguation: in constructs like `1..10`, the dot must NOT be
//    consumed as a decimal point, preserving `..` for the DOTDOT range operator.
// 4. Underscore separators (e.g. `1_000_000` or `১_০০০_০০০`) must be transparently
//    supported for numeric readability without polluting the parsed binary value.
// 5. Zero-Collision Struct Schema: All fields use `num_` prefix to guarantee 100%
//    safe field offset resolution across untyped call boundaries.
// ============================================================================

import "utso/string"
import "utso/collections"
import "compiler/frontend/lexer/unicode_bengali"
import "compiler/frontend/lexer/char_stream"

// ── 1. Result Structure ───────────────────────────────────────────────────────

// WHY: Container for the completed numeric parse result with zero-collision schema
@struct NumParseResult
  num_is_valid: i64
  num_is_float: i64
  num_int_val: i64
  num_float_val: f64
  num_text: string
  num_consumed: i64
@end

// ── 2. Digit Conversion Helpers ───────────────────────────────────────────────

@fn num_hex_char_to_val(c: i64)
  // WHY: Fast ASCII hex char to nibble [0..15]
  @if c >= 48 && c <= 57 return c - 48 @end
  @if c >= 97 && c <= 102 return c - 97 + 10 @end
  @if c >= 65 && c <= 70 return c - 65 + 10 @end
  return -1
@end

@fn num_is_ascii_digit(c: i64)
  // WHY: Returns 1 if c is ASCII '0'..'9'
  @if c >= 48 && c <= 57 return 1 @end
  return 0
@end

@fn num_is_ascii_hex(c: i64)
  // WHY: Returns 1 if c is ASCII hex character
  @if (c >= 48 && c <= 57) || (c >= 97 && c <= 102) || (c >= 65 && c <= 70) return 1 @end
  return 0
@end

@fn num_is_bengali_digit_at(source: string, pos: i64, num_items: i64)
  // WHY: Inspects 3-byte sequence at pos to test if it encodes Bengali digit ০..৯ (U+09E6..U+09EF).
  // UTF-8 bytes for U+09E6..U+09EF are: 0xE0 (224), 0xA7 (167), 0xA6..0xAF (166..175).
  @if pos + 2 >= num_items
    return 0
  @end
  b0 = str_char_at(source, pos)
  b1 = str_char_at(source, pos + 1)
  b2 = str_char_at(source, pos + 2)
  @if b0 == 224 && b1 == 167 && b2 >= 166 && b2 <= 175
    return 1
  @end
  return 0
@end

@fn num_bengali_digit_val_at(source: string, pos: i64)
  // WHY: Decodes decimal value [0..9] from Bengali digit UTF-8 sequence at pos
  b2 = str_char_at(source, pos + 2)
  return b2 - 166
@end

// ── 3. Main Numeric Parser ────────────────────────────────────────────────────

@fn num_parse_literal(source: string, start_pos: i64)
  // WHY: Parses any supported integer or float format starting at start_pos
  num_items = str_len(source)
  @if start_pos >= num_items
    return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: "", num_consumed: 0 }
  @end

  i = start_pos
  first_c = str_char_at(source, i)

  // Test for Bengali zero '০' (224, 167, 166)
  is_bengali_zero = 0
  @if first_c == 224 && i + 2 < num_items && str_char_at(source, i + 1) == 167 && str_char_at(source, i + 2) == 166
    is_bengali_zero = 1
  @end

  // ── A. Hexadecimal Literal (0x / 0X / ০x / ০X) ─────────────────────────────
  is_hex_prefix = 0
  hex_prefix_len = 0
  @if first_c == 48 && i + 1 < num_items // ASCII '0'
    next_c = str_char_at(source, i + 1)
    @if next_c == 120 || next_c == 88 // 'x' or 'X'
      is_hex_prefix = 1
      hex_prefix_len = 2
    @end
  @elif is_bengali_zero == 1 && i + 3 < num_items // Bengali '০'
    next_c = str_char_at(source, i + 3)
    @if next_c == 120 || next_c == 88 // 'x' or 'X'
      is_hex_prefix = 1
      hex_prefix_len = 4
    @end
  @end

  @if is_hex_prefix == 1
    i = i + hex_prefix_len
    hex_val = 0
    digit_count = 0
    @while i < num_items
      cur = str_char_at(source, i)
      @if cur == 95 // '_' separator
        i = i + 1
      @else
        hval = num_hex_char_to_val(cur)
        @if hval >= 0
          hex_val = (hex_val * 16) + hval
          digit_count = digit_count + 1
          i = i + 1
        @else
          // Non-hex character marks end of literal
          raw_text = str_slice(source, start_pos, i)
          @if digit_count > 0
            return { num_is_valid: 1, num_is_float: 0, num_int_val: hex_val, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
          @else
            return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
          @end
        @end
      @end
    @end
    raw_text = str_slice(source, start_pos, i)
    @if digit_count > 0
      return { num_is_valid: 1, num_is_float: 0, num_int_val: hex_val, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
    @end
    return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
  @end

  // ── B. Binary Literal (0b / 0B / ০b / ০B) ──────────────────────────────────
  is_bin_prefix = 0
  bin_prefix_len = 0
  @if first_c == 48 && i + 1 < num_items // ASCII '0'
    next_c = str_char_at(source, i + 1)
    @if next_c == 98 || next_c == 66 // 'b' or 'B'
      is_bin_prefix = 1
      bin_prefix_len = 2
    @end
  @elif is_bengali_zero == 1 && i + 3 < num_items // Bengali '০'
    next_c = str_char_at(source, i + 3)
    @if next_c == 98 || next_c == 66 // 'b' or 'B'
      is_bin_prefix = 1
      bin_prefix_len = 4
    @end
  @end

  @if is_bin_prefix == 1
    i = i + bin_prefix_len
    bin_val = 0
    digit_count = 0
    @while i < num_items
      cur = str_char_at(source, i)
      @if cur == 95 // '_' separator
        i = i + 1
      @elif cur == 48 || cur == 49 // ASCII '0' or '1'
        bit = 0
        @if cur == 49 bit = 1 @end
        bin_val = (bin_val * 2) + bit
        digit_count = digit_count + 1
        i = i + 1
      @elif num_is_bengali_digit_at(source, i, num_items) == 1
        b_digit = num_bengali_digit_val_at(source, i)
        @if b_digit == 0 || b_digit == 1
          bin_val = (bin_val * 2) + b_digit
          digit_count = digit_count + 1
          i = i + 3
        @else
          // Bengali digit > 1 in binary literal is invalid
          return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: str_slice(source, start_pos, i), num_consumed: i - start_pos }
        @end
      @else
        raw_text = str_slice(source, start_pos, i)
        @if digit_count > 0
          return { num_is_valid: 1, num_is_float: 0, num_int_val: bin_val, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
        @else
          return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
        @end
      @end
    @end
    raw_text = str_slice(source, start_pos, i)
    @if digit_count > 0
      return { num_is_valid: 1, num_is_float: 0, num_int_val: bin_val, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
    @end
    return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
  @end

  // ── B2. Octal Literal (0o / 0O / ০o / ০O) ───────────────────────────────────
  is_oct_prefix = 0
  oct_prefix_len = 0
  @if first_c == 48 && i + 1 < num_items // ASCII '0'
    next_c = str_char_at(source, i + 1)
    @if next_c == 111 || next_c == 79 // 'o' or 'O'
      is_oct_prefix = 1
      oct_prefix_len = 2
    @end
  @elif is_bengali_zero == 1 && i + 3 < num_items // Bengali '০'
    next_c = str_char_at(source, i + 3)
    @if next_c == 111 || next_c == 79 // 'o' or 'O'
      is_oct_prefix = 1
      oct_prefix_len = 4
    @end
  @end

  @if is_oct_prefix == 1
    i = i + oct_prefix_len
    oct_val = 0
    digit_count = 0
    @while i < num_items
      cur = str_char_at(source, i)
      @if cur == 95 // '_' separator
        i = i + 1
      @elif cur >= 48 && cur <= 55 // ASCII '0'..'7'
        oct_val = (oct_val * 8) + (cur - 48)
        digit_count = digit_count + 1
        i = i + 1
      @elif num_is_bengali_digit_at(source, i, num_items) == 1
        b_digit = num_bengali_digit_val_at(source, i)
        @if b_digit >= 0 && b_digit <= 7
          oct_val = (oct_val * 8) + b_digit
          digit_count = digit_count + 1
          i = i + 3
        @else
          return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: str_slice(source, start_pos, i), num_consumed: i - start_pos }
        @end
      @else
        raw_text = str_slice(source, start_pos, i)
        @if digit_count > 0
          return { num_is_valid: 1, num_is_float: 0, num_int_val: oct_val, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
        @else
          return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
        @end
      @end
    @end
    raw_text = str_slice(source, start_pos, i)
    @if digit_count > 0
      return { num_is_valid: 1, num_is_float: 0, num_int_val: oct_val, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
    @end
    return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: raw_text, num_consumed: i - start_pos }
  @end

  // ── C. Decimal Integer & Floating Point (Western & Bengali) ────────────────
  int_val = 0
  is_float = 0
  digit_count = 0
  has_dot = 0
  frac_divisor = 1.0
  float_val = 0.0

  @while i < num_items
    cur = str_char_at(source, i)

    // Underscore separator
    @if cur == 95
      i = i + 1

    // ASCII Digit
    @elif num_is_ascii_digit(cur) == 1
      d = cur - 48
      @if has_dot == 0
        int_val = (int_val * 10) + d
      @else
        frac_divisor = frac_divisor * 10.0
        float_val = float_val + (d / frac_divisor)
      @end
      digit_count = digit_count + 1
      i = i + 1

    // Bengali Digit (৩-byte UTF-8)
    @elif num_is_bengali_digit_at(source, i, num_items) == 1
      d = num_bengali_digit_val_at(source, i)
      @if has_dot == 0
        int_val = (int_val * 10) + d
      @else
        frac_divisor = frac_divisor * 10.0
        float_val = float_val + (d / frac_divisor)
      @end
      digit_count = digit_count + 1
      i = i + 3

    // Decimal Point '.' (ASCII 46)
    // WHY: Disambiguate against DOTDOT (..) range operator
    @elif cur == 46 && has_dot == 0 && (i + 1 < num_items) && (str_char_at(source, i + 1) != 46) && (num_is_ascii_digit(str_char_at(source, i + 1)) == 1 || num_is_bengali_digit_at(source, i + 1, num_items) == 1)
      has_dot = 1
      is_float = 1
      float_val = int_val + 0.0
      i = i + 1

    // Exponent 'e' or 'E' (supports both integer 1e5 and decimal 1.5e-3 mantissas)
    @elif (cur == 101 || cur == 69) && digit_count > 0 && (i + 1 < num_items)
      saved_exp_i = i
      i = i + 1
      exp_neg = 0
      @if i < num_items && (str_char_at(source, i) == 43 || str_char_at(source, i) == 45) // '+' or '-'
        @if str_char_at(source, i) == 45
          exp_neg = 1
        @end
        i = i + 1
      @end
      exp_digits = 0
      exp_val = 0
      @while i < num_items && num_is_ascii_digit(str_char_at(source, i)) == 1
        ec = str_char_at(source, i)
        @if exp_val < 320
          exp_val = (exp_val * 10) + (ec - 48)
        @end
        exp_digits = exp_digits + 1
        i = i + 1
      @end
      @if exp_digits == 0
        // Not a scientific exponent (e.g. `1e_foo`); restore before 'e' and return mantissa
        i = saved_exp_i
        @if is_float == 0
          float_val = int_val + 0.0
        @end
        return { num_is_valid: 1, num_is_float: is_float, num_int_val: int_val, num_float_val: float_val, num_text: str_slice(source, start_pos, i), num_consumed: i - start_pos }
      @end
      @if is_float == 0
        float_val = int_val + 0.0
      @end
      ek = 0
      @while ek < exp_val
        @if exp_neg == 1
          float_val = float_val / 10.0
        @else
          float_val = float_val * 10.0
        @end
        ek = ek + 1
      @end
      return { num_is_valid: 1, num_is_float: 1, num_int_val: int_val, num_float_val: float_val, num_text: str_slice(source, start_pos, i), num_consumed: i - start_pos }

    @else
      // Non-digit character ends numeric literal
      @if digit_count > 0
        @if is_float == 0
          float_val = int_val + 0.0
        @end
        return { num_is_valid: 1, num_is_float: is_float, num_int_val: int_val, num_float_val: float_val, num_text: str_slice(source, start_pos, i), num_consumed: i - start_pos }
      @end
      return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: "", num_consumed: 0 }
    @end
  @end

  @if digit_count > 0
    @if is_float == 0
      float_val = int_val + 0.0
    @end
    return { num_is_valid: 1, num_is_float: is_float, num_int_val: int_val, num_float_val: float_val, num_text: str_slice(source, start_pos, i), num_consumed: i - start_pos }
  @end

  return { num_is_valid: 0, num_is_float: 0, num_int_val: 0, num_float_val: 0.0, num_text: "", num_consumed: 0 }
@end
