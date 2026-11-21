@! ============================================================
@! LIPI UNIVERSE — Core String Library v3.0
@! Interpreter-compatible: uses built-in .len() .char_at()
@! NO sys_peek8 / sys_poke8 / sys_mmap — those are ELF64 only
@! ============================================================

@! ─── Basic String Primitives ─────────────────────────────────

@fn str_len(s)
  // WHY: Returns string length using compiler intrinsic len(s) for O(1) STR0 header lookup
  @if s == 0 return 0 @end
  return len(s)
@end



@fn str_char_at(s, idx)
  // WHY: Returns integer ASCII / Unicode byte value of character at idx
  @if s == 0 return 0 @end
  c = char_at(s, idx)
  return ord(c)
@end

@fn string_length(s)
  // WHY: Canonical alias for string length
  return str_len(s)
@end

@fn str_concat(s1, s2)
  // WHY: Performs string concatenation using native machine code _lipi_str_concat ensuring STR0 header tagging
  @if s1 == 0 && s2 == 0 return "" @end
  @if s1 == 0 return s2 @end
  @if s2 == 0 return s1 @end
  return s1 + s2
@end

@fn string_concat(s1, s2)
  // WHY: Canonical alias for str_concat
  return str_concat(s1, s2)
@end

@fn str_slice(s, start, stop)
  // WHY: Invokes native compiler intrinsic str_sub ensuring proper bounds checking and STR0 allocation
  return str_sub(s, start, stop)
@end

@fn string_slice(s, start, stop)
  // WHY: Canonical alias for str_slice
  return str_sub(s, start, stop)
@end

@fn str_substr(s, start, stop)
  // WHY: Canonical alias for str_slice
  return str_sub(s, start, stop)
@end

@fn substr(s, start, stop)
  // WHY: LiPi compiler lowers method calls s.substr(a, b) to substr(s, a, b)
  return str_sub(s, start, stop)
@end

@fn slice(s, start, stop)
  // WHY: LiPi compiler lowers method calls s.slice(a, b) to slice(s, a, b)
  return str_sub(s, start, stop)
@end

@fn str_starts_with(s, prefix)
  lp = str_len(prefix)
  ls = str_len(s)
  @if lp > ls
    return 0
  @end
  diff = 0
  i = 0
  @while i < lp
    @if str_char_at(s, i) != str_char_at(prefix, i)
      diff = 1
      i = lp
    @end
    i = i + 1
  @end
  @if diff == 1
    return 0
  @end
  return 1
@end

@fn starts_with(s, prefix)
  return str_starts_with(s, prefix)
@end

@fn str_ends_with(s, suffix)
  ls = str_len(s)
  lx = str_len(suffix)
  @if lx > ls
    return 0
  @end
  offset = ls - lx
  diff = 0
  i = 0
  @while i < lx
    @if str_char_at(s, offset + i) != str_char_at(suffix, i)
      diff = 1
      i = lx
    @end
    i = i + 1
  @end
  @if diff == 1
    return 0
  @end
  return 1
@end

@fn ends_with(s, suffix)
  return str_ends_with(s, suffix)
@end

@fn str_eq(s1, s2)
  // WHY: Compares two strings using native compiler equality operator ==
  // which lowers to _lipi_cmp_dynamic / lipi_fn_str_eq with full content comparison
  @if s1 == s2 return 1 @end
  return 0
@end

@fn eq(s1, s2)
  // WHY: Canonical alias for str_eq
  return str_eq(s1, s2)
@end

@fn str_contains(s, sub)
  ls = str_len(s)
  lsub = str_len(sub)
  @if lsub > ls
    return 0
  @end
  @if lsub == 0
    return 1
  @end
  i = 0
  @while i <= ls - lsub
    found = 1
    j = 0
    @while j < lsub
      @if str_char_at(s, i + j) == str_char_at(sub, j)
        j = j + 1
      @else
        found = 0
        j = lsub
      @end
    @end
    @if found == 1
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn string_contains(s, sub)
  return str_contains(s, sub)
@end

@fn str_index_of(s, sub)
  ls = str_len(s)
  lsub = str_len(sub)
  @if lsub > ls
    return -1
  @end
  @if lsub == 0
    return 0
  @end
  i = 0
  @while i <= ls - lsub
    found = 1
    j = 0
    @while j < lsub
      @if str_char_at(s, i + j) == str_char_at(sub, j)
        j = j + 1
      @else
        found = 0
        j = lsub
      @end
    @end
    @if found == 1
      return i
    @end
    i = i + 1
  @end
  return -1
@end

@fn str_repeat(s, n)
  result = ""
  i = 0
  @while i < n
    result = result + s
    i = i + 1
  @end
  return result
@end

@fn str_reverse(s)
  result = ""
  i = str_len(s) - 1
  @while i >= 0
    result = result + s.char_at(i)
    i = i - 1
  @end
  return result
@end

@! ─── Integer / String Conversion ────────────────────────────

@fn to_str(n)
  @! Canonical integer to string conversion in pure sovereign Lipi
  @! WHY: Directly leverages native str(n) builtin for correct STR0 tags and O(1) length.
  return str(n)
@end

@fn int_to_str(n)
  return str(n)
@end

@fn from_char(code)
  return chr(code)
@end

@fn string_length(s)
  return str_len(s)
@end

@fn lipi_str_to_int(s)
  @! Parse signed integer from string
  @! WHY: Skips leading whitespace and accumulates negatively so INT64_MIN (-9223372036854775808)
  @! parses without intermediate positive signed overflow.
  n = str_len(s)
  i = 0
  @while i < n
    wch = str_char_at(s, i)
    @if wch == 32 || wch == 9 || wch == 10 || wch == 13
      i = i + 1
    @else
      break
    @end
  @end

  negative = 0
  @if i < n
    first_ch = str_char_at(s, i)
    @if first_ch == 45 @! '-'
      negative = 1
      i = i + 1
    @elif first_ch == 43 @! '+'
      i = i + 1
    @end
  @end

  acc = 0
  @while i < n
    ch = str_char_at(s, i)
    @if ch >= 48 && ch <= 57
      digit = ch - 48
      acc = (acc * 10) - digit
    @end
    i = i + 1
  @end
  @if negative == 1
    return acc
  @end
  return 0 - acc
@end

@fn str_parse_int(s)
  @! Strict signed integer parser returning { ok: 1/0, value: i64 }
  @! WHY: Rejects empty or trailing-garbage strings while supporting whitespace and INT64_MIN.
  n = str_len(s)
  i = 0
  @while i < n
    wch = str_char_at(s, i)
    @if wch == 32 || wch == 9 || wch == 10 || wch == 13
      i = i + 1
    @else
      break
    @end
  @end
  @if i >= n
    return { ok: 0, value: 0 }
  @end

  negative = 0
  first_ch = str_char_at(s, i)
  @if first_ch == 45
    negative = 1
    i = i + 1
  @elif first_ch == 43
    i = i + 1
  @end

  acc = 0
  has_digit = 0
  @while i < n
    ch = str_char_at(s, i)
    @if ch >= 48 && ch <= 57
      digit = ch - 48
      acc = (acc * 10) - digit
      has_digit = 1
      i = i + 1
    @else
      break
    @end
  @end

  @while i < n
    tch = str_char_at(s, i)
    @if tch == 32 || tch == 9 || tch == 10 || tch == 13
      i = i + 1
    @else
      return { ok: 0, value: 0 }
    @end
  @end

  @if has_digit == 0
    return { ok: 0, value: 0 }
  @end
  val = acc
  @if negative == 0
    val = 0 - acc
  @end
  return { ok: 1, value: val }
@end

// WHY: Canonical string_to_int parser returning integer representation of string s
@fn string_to_int(s)
  return lipi_str_to_int(s)
@end

// WHY: Canonical string equality test returning 1 if equal, 0 otherwise
@fn string_eq(s1, s2)
  @if s1 == s2
    return 1
  @end
  return 0
@end

// WHY: Verifies prefix match using character-by-character comparison bounded by prefix length
@fn string_starts_with(s, prefix)
  p_len = str_len(prefix)
  s_len = str_len(s)
  @if p_len > s_len
    return 0
  @end
  i = 0
  @while i < p_len
    @if str_char_at(s, i) != str_char_at(prefix, i)
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

// WHY: Verifies suffix match by comparing trailing characters from s_len - suf_len to s_len
@fn string_ends_with(s, suffix)
  s_len = str_len(suffix)
  target_len = str_len(s)
  @if s_len > target_len
    return 0
  @end
  offset = target_len - s_len
  i = 0
  @while i < s_len
    @if str_char_at(s, offset + i) != str_char_at(suffix, i)
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

// WHY: Repeats string s count times into a newly accumulated string
@fn string_repeat(s, count)
  @if count <= 0
    return ""
  @end
  res = ""
  i = 0
  @while i < count
    res = res + s
    i = i + 1
  @end
  return res
@end

// WHY: Returns the ASCII/byte value at idx in string s, or 0 if out of bounds
@fn str_byte_at(s, idx)
  @if idx < 0 || idx >= str_len(s)
    return 0
  @end
  return str_char_at(s, idx)
@end

// WHY: Returns the integer ASCII codepoint of the first character in string ch
@fn char_to_code(ch)
  @if str_len(ch) == 0
    return 0
  @end
  return str_char_at(ch, 0)
@end

// WHY: Canonical string_is_alphanum check returning 1 if character c is alphabetic or numeric
@fn string_is_alphanum(c)
  @if is_alpha(c) == 1 || is_digit(c) == 1
    return 1
  @end
  return 0
@end

@fn str_to_int(s)
  return lipi_str_to_int(s)
@end

@fn int_from_str(s)
  // WHY: Alias for str_to_int providing standard numeric string parsing
  return lipi_str_to_int(s)
@end

@fn to_int(v)
  // WHY: Universal to_int method. If string, parses integer; otherwise returns numeric value.
  @if is_str(v) == 1
    return lipi_str_to_int(v)
  @end
  return v
@end

@fn লিপি_ইন্টে_রূপান্তর(মান)
  return to_int(মান)
@end

@fn float_from_str(s)
  // WHY: Parses a floating point value from a decimal string without libc strtod.
  // Supports optional leading sign, integer portion, and fractional decimal digits.
  n = str_len(s)
  @if n == 0 return 0.0 @end

  negative = 0
  i = 0
  first_ch = str_char_at(s, 0)
  @if first_ch == 45
    negative = 1
    i = 1
  @elif first_ch == 43
    i = 1
  @end

  int_part = 0
  frac_part = 0
  frac_div = 1.0
  in_frac = 0

  @while i < n
    ch = str_char_at(s, i)
    @if ch == 46
      in_frac = 1
    @elif ch >= 48 && ch <= 57
      digit = ch - 48
      @if in_frac == 0
        int_part = int_part * 10 + digit
      @else
        frac_part = frac_part * 10 + digit
        frac_div = frac_div * 10.0
      @end
    @end
    i = i + 1
  @end

  val = (int_part * 1.0) + ((frac_part * 1.0) / frac_div)
  @if negative == 1
    return 0.0 - val
  @end
  return val
@end

@fn str_to_float(s)
  // WHY: Standard alias for float_from_str
  return float_from_str(s)
@end

@fn লিপি_স্ট্রিং_থেকে_ফ্লোট(লেখা)
  return float_from_str(লেখা)
@end


@! ─── Case Conversion ─────────────────────────────────────────

@fn string_to_lower(s)
  // WHY: Pure portable case conversion producing STR0-managed Lipi strings without raw unmanaged memory allocations
  n = str_len(s)
  @if n == 0 return "" @end
  alpha_lower = "abcdefghijklmnopqrstuvwxyz"
  res = ""
  i = 0
  @while i < n
    ch = str_char_at(s, i)
    @if ch >= 65 && ch <= 90
      idx = ch - 65
      res = res + str_sub(alpha_lower, idx, idx + 1)
    @else
      res = res + str_sub(s, i, i + 1)
    @end
    i = i + 1
  @end
  return res
@end

@fn str_to_lower(s)
  return string_to_lower(s)
@end

@fn string_lower(s)
  return string_to_lower(s)
@end

@fn str_lower(s)
  return string_to_lower(s)
@end

@fn string_to_upper(s)
  // WHY: Pure portable case conversion producing STR0-managed Lipi strings without raw unmanaged memory allocations
  n = str_len(s)
  @if n == 0 return "" @end
  alpha_upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  res = ""
  i = 0
  @while i < n
    ch = str_char_at(s, i)
    @if ch >= 97 && ch <= 122
      idx = ch - 97
      res = res + str_sub(alpha_upper, idx, idx + 1)
    @else
      res = res + str_sub(s, i, i + 1)
    @end
    i = i + 1
  @end
  return res
@end

@fn str_to_upper(s)
  return string_to_upper(s)
@end

@fn string_upper(s)
  return string_to_upper(s)
@end

@fn str_upper(s)
  return string_to_upper(s)
@end

@! ─── Trim ────────────────────────────────────────────────────

@fn string_trim(s)
  @! Pure freestanding whitespace trimming (leading and trailing)
  @! WHY: Uses str_char_at with ASCII byte codes (32, 9, 10, 13) instead of string object comparisons.
  n = str_len(s)
  @if n == 0 return "" @end
  left = 0
  stop_l = 0
  @while left < n && stop_l == 0
    c = str_char_at(s, left)
    @if c == 32 || c == 9 || c == 10 || c == 13
      left = left + 1
    @else
      stop_l = 1
    @end
  @end
  @if left >= n return "" @end
  right = n - 1
  stop_r = 0
  @while right >= left && stop_r == 0
    c = str_char_at(s, right)
    @if c == 32 || c == 9 || c == 10 || c == 13
      right = right - 1
    @else
      stop_r = 1
    @end
  @end
  return str_slice(s, left, right + 1)
@end

@fn str_trim(s)
  return string_trim(s)
@end

@fn trim(s)
  return string_trim(s)
@end

@! ─── Split / Join ────────────────────────────────────────────

@fn string_split(s, sep)
  @! Pure freestanding zero-dependency string splitting
  @! WHY: Compares separator bytes in-place via str_char_at without allocating per-byte slice temporaries.
  result = []
  n = str_len(s)
  sep_len = str_len(sep)
  @if n == 0
    return result
  @end
  @if sep_len == 0
    result = result.push(s)
    return result
  @end
  last_start = 0
  i = 0
  limit = n - sep_len + 1
  @while i < limit
    matched = 1
    j = 0
    @while j < sep_len
      @if str_char_at(s, i + j) != str_char_at(sep, j)
        matched = 0
        break
      @end
      j = j + 1
    @end
    @if matched == 1
      piece = str_slice(s, last_start, i)
      result = result.push(piece)
      i = i + sep_len
      last_start = i
    @else
      i = i + 1
    @end
  @end
  last_piece = str_slice(s, last_start, n)
  result = result.push(last_piece)
  return result
@end

@fn str_split(s, sep)
  return string_split(s, sep)
@end

@fn string_join(arr, sep)
  result = ""
  i = 0
  n = arr.len()
  @while i < n
    @if i > 0
      result = str_concat(result, sep)
    @end
    result = str_concat(result, arr[i])
    i = i + 1
  @end
  return result
@end

@fn str_join(arr, sep)
  return string_join(arr, sep)
@end

@! ─── Char Code ───────────────────────────────────────────────

@fn str_from_char_code(code)
  @! Encode Unicode scalar codepoint (0..0x10FFFF) to UTF-8 string
  @if code < 0 || code > 1114111
    return chr(239) + chr(191) + chr(189)
  @end
  @if code < 128
    return chr(code)
  @end
  @if code < 2048
    b0 = 192 + ((code / 64) % 32)
    b1 = 128 + (code % 64)
    return chr(b0) + chr(b1)
  @end
  @if code < 65536
    @if code >= 55296 && code <= 57343
      return chr(239) + chr(191) + chr(189)
    @end
    b0 = 224 + ((code / 4096) % 16)
    b1 = 128 + ((code / 64) % 64)
    b2 = 128 + (code % 64)
    return chr(b0) + chr(b1) + chr(b2)
  @end
  b0 = 240 + ((code / 262144) % 8)
  b1 = 128 + ((code / 4096) % 64)
  b2 = 128 + ((code / 64) % 64)
  b3 = 128 + (code % 64)
  return chr(b0) + chr(b1) + chr(b2) + chr(b3)
@end

@fn char_code(c)
  @! Single char / UTF-8 rune string -> integer codepoint
  @if c == 0 return 0 @end
  n = len(c)
  @if n == 0 return 0 @end
  b0 = ord(char_at(c, 0))
  @if b0 < 128 return b0 @end
  @if b0 >= 194 && b0 < 224 && n >= 2
    b1 = ord(char_at(c, 1))
    @if b1 >= 128 && b1 <= 191
      return ((b0 - 192) * 64) + (b1 - 128)
    @end
  @end
  @if b0 >= 224 && b0 < 240 && n >= 3
    b1 = ord(char_at(c, 1))
    b2 = ord(char_at(c, 2))
    @if b1 >= 128 && b1 <= 191 && b2 >= 128 && b2 <= 191
      return ((b0 - 224) * 4096) + ((b1 - 128) * 64) + (b2 - 128)
    @end
  @end
  @if b0 >= 240 && b0 < 245 && n >= 4
    b1 = ord(char_at(c, 1))
    b2 = ord(char_at(c, 2))
    b3 = ord(char_at(c, 3))
    @if b1 >= 128 && b1 <= 191 && b2 >= 128 && b2 <= 191 && b3 >= 128 && b3 <= 191
      return ((b0 - 240) * 262144) + ((b1 - 128) * 4096) + ((b2 - 128) * 64) + (b3 - 128)
    @end
  @end
  return b0
@end

@fn is_digit(c)
  @if c == "0" return 1 @end
  @if c == "1" return 1 @end
  @if c == "2" return 1 @end
  @if c == "3" return 1 @end
  @if c == "4" return 1 @end
  @if c == "5" return 1 @end
  @if c == "6" return 1 @end
  @if c == "7" return 1 @end
  @if c == "8" return 1 @end
  @if c == "9" return 1 @end
  return 0
@end

@fn string_is_digit(c)
  // WHY: Canonical string_is_digit alias matching SQL lexer and markup parser expectations
  return is_digit(c)
@end

@fn is_alpha(c)
  @if c == "a" return 1 @end @if c == "b" return 1 @end
  @if c == "c" return 1 @end @if c == "d" return 1 @end
  @if c == "e" return 1 @end @if c == "f" return 1 @end
  @if c == "g" return 1 @end @if c == "h" return 1 @end
  @if c == "i" return 1 @end @if c == "j" return 1 @end
  @if c == "k" return 1 @end @if c == "l" return 1 @end
  @if c == "m" return 1 @end @if c == "n" return 1 @end
  @if c == "o" return 1 @end @if c == "p" return 1 @end
  @if c == "q" return 1 @end @if c == "r" return 1 @end
  @if c == "s" return 1 @end @if c == "t" return 1 @end
  @if c == "u" return 1 @end @if c == "v" return 1 @end
  @if c == "w" return 1 @end @if c == "x" return 1 @end
  @if c == "y" return 1 @end @if c == "z" return 1 @end
  @if c == "A" return 1 @end @if c == "B" return 1 @end
  @if c == "C" return 1 @end @if c == "D" return 1 @end
  @if c == "E" return 1 @end @if c == "F" return 1 @end
  @if c == "G" return 1 @end @if c == "H" return 1 @end
  @if c == "I" return 1 @end @if c == "J" return 1 @end
  @if c == "K" return 1 @end @if c == "L" return 1 @end
  @if c == "M" return 1 @end @if c == "N" return 1 @end
  @if c == "O" return 1 @end @if c == "P" return 1 @end
  @if c == "Q" return 1 @end @if c == "R" return 1 @end
  @if c == "S" return 1 @end @if c == "T" return 1 @end
  @if c == "U" return 1 @end @if c == "V" return 1 @end
  @if c == "W" return 1 @end @if c == "X" return 1 @end
  @if c == "Y" return 1 @end @if c == "Z" return 1 @end
  return 0
@end

@fn string_is_alpha(c)
  // WHY: Canonical string_is_alpha alias
  return is_alpha(c)
@end

@fn is_space(c)
  @if c == " " return 1 @end
  @if c == "\t" return 1 @end
  @if c == "\n" return 1 @end
  @if c == "\r" return 1 @end
  return 0
@end

@! ─── Hex string helpers ──────────────────────────────────────

@fn hex_char(n)
  @! 0-15 → '0'-'9','a'-'f'
  @if n == 0 return "0" @end
  @if n == 1 return "1" @end
  @if n == 2 return "2" @end
  @if n == 3 return "3" @end
  @if n == 4 return "4" @end
  @if n == 5 return "5" @end
  @if n == 6 return "6" @end
  @if n == 7 return "7" @end
  @if n == 8 return "8" @end
  @if n == 9 return "9" @end
  @if n == 10 return "a" @end
  @if n == 11 return "b" @end
  @if n == 12 return "c" @end
  @if n == 13 return "d" @end
  @if n == 14 return "e" @end
  @if n == 15 return "f" @end
  return "?"
@end

@fn byte_to_hex(b)
  hi = b / 16
  lo = b % 16
  @if hi < 0 hi = 0 @end
  @if lo < 0 lo = lo + 16 @end
  return hex_char(hi) + hex_char(lo)
@end

@fn hex_val(c)
  @if c == "0" return 0 @end @if c == "1" return 1 @end
  @if c == "2" return 2 @end @if c == "3" return 3 @end
  @if c == "4" return 4 @end @if c == "5" return 5 @end
  @if c == "6" return 6 @end @if c == "7" return 7 @end
  @if c == "8" return 8 @end @if c == "9" return 9 @end
  @if c == "a" return 10 @end @if c == "b" return 11 @end
  @if c == "c" return 12 @end @if c == "d" return 13 @end
  @if c == "e" return 14 @end @if c == "f" return 15 @end
  @if c == "A" return 10 @end @if c == "B" return 11 @end
  @if c == "C" return 12 @end @if c == "D" return 13 @end
  @if c == "E" return 14 @end @if c == "F" return 15 @end
  return 0
@end

// ─── Pure Lipi First 1.0.0 String Algorithms & Case Transformations ───────────────────

// WHY: Converts lowercase ASCII characters (a-z: 97-122) to uppercase (A-Z: 65-90).
fn upper s
    res = ""
    i = 0
    slen = len(s)
    while i < slen
        c = char_at(s, i)
        code = ord(c)
        if code >= 97 and code <= 122
            res = res + chr(code - 32)
        else
            res = res + c
        i = i + 1
    return res

fn str_upper s
    return upper(s)

fn বড়_অক্ষর s
    return upper(s)

// WHY: Converts uppercase ASCII characters (A-Z: 65-90) to lowercase (a-z: 97-122).
fn lower s
    res = ""
    i = 0
    slen = len(s)
    while i < slen
        c = char_at(s, i)
        code = ord(c)
        if code >= 65 and code <= 90
            res = res + chr(code + 32)
        else
            res = res + c
        i = i + 1
    return res

fn str_lower s
    return lower(s)

fn ছোট_অক্ষর s
    return lower(s)

// WHY: Strips leading and trailing ASCII whitespace (spaces, tabs, newlines, carriage returns).
fn trim s
    slen = len(s)
    if slen == 0
        return ""
    start = 0
    while start < slen
        c = char_at(s, start)
        if c == " " or c == "\t" or c == "\n" or c == "\r"
            start = start + 1
        else
            break
    if start >= slen
        return ""
    end = slen - 1
    while end >= start
        c = char_at(s, end)
        if c == " " or c == "\t" or c == "\n" or c == "\r"
            end = end - 1
        else
            break
    return str_sub(s, start, end + 1)

fn str_trim s
    return trim(s)

fn ছাঁটাই s
    return trim(s)

// WHY: Returns the 0-based start index of first occurrence of sub in s, or -1 if not found.
fn index_of s sub
    slen = len(s)
    sublen = len(sub)
    if sublen == 0
        return 0
    if sublen > slen
        return -1
    limit = slen - sublen
    i = 0
    while i <= limit
        match = 1
        j = 0
        while j < sublen
            if char_at(s, i + j) != char_at(sub, j)
                match = 0
                j = sublen
            else
                j = j + 1
        if match == 1
            return i
        i = i + 1
    return -1

fn str_index_of s sub
    return index_of(s, sub)

fn স্ট্রিং_সূচক s sub
    return index_of(s, sub)

// WHY: Returns 1 if s contains sub, 0 otherwise.
fn contains s sub
    if index_of(s, sub) >= 0
        return 1
    return 0

fn str_contains s sub
    if index_of(s, sub) >= 0
        return 1
    return 0

fn ধারণ_করে s sub
    if index_of(s, sub) >= 0
        return 1
    return 0

// WHY: Returns 1 if string s starts with prefix, 0 otherwise.
fn starts_with s prefix
    slen = len(s)
    plen = len(prefix)
    if plen > slen
        return 0
    i = 0
    while i < plen
        if char_at(s, i) != char_at(prefix, i)
            return 0
        i = i + 1
    return 1

fn str_starts_with s prefix
    return starts_with(s, prefix)

fn str_starts prefix s
    return starts_with(s, prefix)

fn শুরু_হয় s prefix
    return starts_with(s, prefix)

// WHY: Returns 1 if string s ends with suffix, 0 otherwise.
fn ends_with s suffix
    slen = len(s)
    flen = len(suffix)
    if flen > slen
        return 0
    offset = slen - flen
    i = 0
    while i < flen
        if char_at(s, offset + i) != char_at(suffix, i)
            return 0
        i = i + 1
    return 1

fn str_ends_with s suffix
    return ends_with(s, suffix)

fn শেষ_হয় s suffix
    return ends_with(s, suffix)

// WHY: Substring aliases delegate directly to native silicon-intrinsic str_sub (_lipi_str_sub).
// Eliminates software divide-and-conquer recursion and keyword collision with 'end'.
fn substring s start end_pos
    return str_sub(s, start, end_pos)

fn উপস্ট্রিং s start end_pos
    return str_sub(s, start, end_pos)

// WHY: Replaces all occurrences of old_sub with new_sub throughout string s.
fn replace s old_sub new_sub
    slen = len(s)
    olen = len(old_sub)
    if olen == 0
        return s
    res = ""
    i = 0
    while i < slen
        if i + olen <= slen
            match = 1
            j = 0
            while j < olen
                if char_at(s, i + j) != char_at(old_sub, j)
                    match = 0
                    j = olen
                else
                    j = j + 1
            if match == 1
                res = res + new_sub
                i = i + olen
            else
                res = res + char_at(s, i)
                i = i + 1
        else
            res = res + char_at(s, i)
            i = i + 1
    return res

fn str_replace s old_sub new_sub
    return replace(s, old_sub, new_sub)

fn প্রতিস্থাপন s old_sub new_sub
    return replace(s, old_sub, new_sub)

// WHY: Splits string s by whitespace into a list of word tokens.
fn split s
    res = list()
    slen = len(s)
    i = 0
    while i < slen
        while i < slen
            c = char_at(s, i)
            if c == " " or c == "\t" or c == "\n" or c == "\r"
                i = i + 1
            else
                break
        if i < slen
            word = ""
            while i < slen
                c = char_at(s, i)
                if c != " " and c != "\t" and c != "\n" and c != "\r"
                    word = word + c
                    i = i + 1
                else
                    break
            res = push(res, word)
    return res

fn বিভাজন s
    return split(s)

// WHY: Splits string s by a specific delimiter string.
fn split_delim s delim
    res = list()
    slen = len(s)
    dlen = len(delim)
    if dlen == 0
        i = 0
        while i < slen
            res = push(res, char_at(s, i))
            i = i + 1
        return res
    cur = ""
    i = 0
    while i < slen
        if i + dlen <= slen
            match = 1
            j = 0
            while j < dlen
                if char_at(s, i + j) != char_at(delim, j)
                    match = 0
                    j = dlen
                else
                    j = j + 1
            if match == 1
                res = push(res, cur)
                cur = ""
                i = i + dlen
            else
                cur = cur + char_at(s, i)
                i = i + 1
        else
            cur = cur + char_at(s, i)
            i = i + 1
    res = push(res, cur)
    return res

// WHY: Joins a list of items using the canonical str_join(items, sep) parameter order.
fn যুক্ত_করো items sep
    return str_join(items, sep)

// WHY: Repeat string n times.
fn str_repeat s n
    result = ""
    i = 0
    while i < n
        result = result + s
        i = i + 1
    return result

fn chars n c
    return str_repeat(c, n)

fn পুনরাবৃত্তি s n
    return str_repeat(s, n)

// WHY: Pad string on left to given width with padding character.
fn str_pad_left s width char
    pad = width - len(s)
    if pad <= 0
        return s
    return str_repeat(char, pad) + s

// WHY: Pad string on right to given width with padding character.
fn str_pad_right s width char
    pad = width - len(s)
    if pad <= 0
        return s
    return s + str_repeat(char, pad)

// WHY: Center string in given width with padding character.
fn str_center s width char
    pad = width - len(s)
    if pad <= 0
        return s
    left = pad / 2
    right = pad - left
    return str_repeat(char, left) + s + str_repeat(char, right)

fn str_signed n
    if n > 0
        return "+" + str(n)
    return str(n)

fn str_empty s
    if len(s) == 0
        return 1
    return 0

fn খালি_কিনা s
    return str_empty(s)

fn to_upper s
    return upper(s)

fn to_lower s
    return lower(s)

// ── ৭. ইউনিকোড ও বাংলা রুন ব্রিজ (Unicode & Bengali Rune Bridge) ───────────────
// WHY: Exposes Unicode-safe character counting and slicing through canonical string API
// without breaking legacy byte-level str_len or str_slice.
include "utso/core/unicode.lp"

fn str_rune_len s
    return utf8_rune_len(s)

fn str_rune_slice s start count
    return utf8_rune_slice(s, start, count)

fn str_rune_at s idx
    return utf8_rune_at(s, idx)
