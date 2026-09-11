@! ============================================================
@! MAYA UNIVERSE — Core String Library v3.0
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
  // WHY: Maya compiler lowers method calls s.substr(a, b) to substr(s, a, b)
  return str_sub(s, start, stop)
@end

@fn slice(s, start, stop)
  // WHY: Maya compiler lowers method calls s.slice(a, b) to slice(s, a, b)
  return str_sub(s, start, stop)
@end

@fn str_starts_with(s, prefix)
  lp = str_len(prefix)
  ls = str_len(s)
  @if lp > ls
    return 0
  @end
  i = 0
  @while i < lp
    @if str_char_at(s, i) != str_char_at(prefix, i)
      return 0
    @end
    i = i + 1
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
  i = 0
  @while i < lx
    @if str_char_at(s, offset + i) != str_char_at(suffix, i)
      return 0
    @end
    i = i + 1
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

@fn maya_int_to_str(n)
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

@fn maya_str_to_int(s)
  @! Parse signed integer from string
  @! WHY: Uses str_char_at with ASCII byte values (48..57) for freestanding execution.
  result = 0
  negative = 0
  i = 0
  n = str_len(s)
  @if n > 0
    first_ch = str_char_at(s, 0)
    @if first_ch == 45 @! '-'
      negative = 1
      i = 1
    @end
  @end
  @while i < n
    ch = str_char_at(s, i)
    @if ch >= 48 && ch <= 57
      digit = ch - 48
      result = result * 10 + digit
    @end
    i = i + 1
  @end
  @if negative == 1
    result = 0 - result
  @end
  return result
@end

@fn str_to_int(s)
  return maya_str_to_int(s)
@end

@fn int_from_str(s)
  // WHY: Alias for str_to_int providing standard numeric string parsing
  return maya_str_to_int(s)
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
  @! WHY: Uses byte indices and str_slice instead of pointer addition or character copying.
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
    @if str_starts_with(str_slice(s, i, n), sep) == 1
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
  @! ASCII code to single-character string
  @if code == 32 return " " @end
  @if code == 33 return "!" @end
  @if code == 34 return "\"" @end
  @if code == 35 return "#" @end
  @if code == 36 return "$" @end
  @if code == 37 return "%" @end
  @if code == 38 return "&" @end
  @if code == 39 return "'" @end
  @if code == 40 return "(" @end
  @if code == 41 return ")" @end
  @if code == 42 return "*" @end
  @if code == 43 return "+" @end
  @if code == 44 return "," @end
  @if code == 45 return "-" @end
  @if code == 46 return "." @end
  @if code == 47 return "/" @end
  @if code == 48 return "0" @end
  @if code == 49 return "1" @end
  @if code == 50 return "2" @end
  @if code == 51 return "3" @end
  @if code == 52 return "4" @end
  @if code == 53 return "5" @end
  @if code == 54 return "6" @end
  @if code == 55 return "7" @end
  @if code == 56 return "8" @end
  @if code == 57 return "9" @end
  @if code == 58 return ":" @end
  @if code == 59 return ";" @end
  @if code == 60 return "<" @end
  @if code == 61 return "=" @end
  @if code == 62 return ">" @end
  @if code == 63 return "?" @end
  @if code == 64 return "@" @end
  @if code == 65 return "A" @end
  @if code == 66 return "B" @end
  @if code == 67 return "C" @end
  @if code == 68 return "D" @end
  @if code == 69 return "E" @end
  @if code == 70 return "F" @end
  @if code == 71 return "G" @end
  @if code == 72 return "H" @end
  @if code == 73 return "I" @end
  @if code == 74 return "J" @end
  @if code == 75 return "K" @end
  @if code == 76 return "L" @end
  @if code == 77 return "M" @end
  @if code == 78 return "N" @end
  @if code == 79 return "O" @end
  @if code == 80 return "P" @end
  @if code == 81 return "Q" @end
  @if code == 82 return "R" @end
  @if code == 83 return "S" @end
  @if code == 84 return "T" @end
  @if code == 85 return "U" @end
  @if code == 86 return "V" @end
  @if code == 87 return "W" @end
  @if code == 88 return "X" @end
  @if code == 89 return "Y" @end
  @if code == 90 return "Z" @end
  @if code == 91 return "[" @end
  @if code == 92 return "\\" @end
  @if code == 93 return "]" @end
  @if code == 94 return "^" @end
  @if code == 95 return "_" @end
  @if code == 96 return "`" @end
  @if code == 97 return "a" @end
  @if code == 98 return "b" @end
  @if code == 99 return "c" @end
  @if code == 100 return "d" @end
  @if code == 101 return "e" @end
  @if code == 102 return "f" @end
  @if code == 103 return "g" @end
  @if code == 104 return "h" @end
  @if code == 105 return "i" @end
  @if code == 106 return "j" @end
  @if code == 107 return "k" @end
  @if code == 108 return "l" @end
  @if code == 109 return "m" @end
  @if code == 110 return "n" @end
  @if code == 111 return "o" @end
  @if code == 112 return "p" @end
  @if code == 113 return "q" @end
  @if code == 114 return "r" @end
  @if code == 115 return "s" @end
  @if code == 116 return "t" @end
  @if code == 117 return "u" @end
  @if code == 118 return "v" @end
  @if code == 119 return "w" @end
  @if code == 120 return "x" @end
  @if code == 121 return "y" @end
  @if code == 122 return "z" @end
  @if code == 123 return "{" @end
  @if code == 124 return "|" @end
  @if code == 125 return "}" @end
  @if code == 126 return "~" @end
  return "?"
@end

@fn char_code(c)
  @! Single char string → ASCII code
  @if c == " " return 32 @end
  @if c == "!" return 33 @end
  @if c == "\"" return 34 @end
  @if c == "#" return 35 @end
  @if c == "$" return 36 @end
  @if c == "%" return 37 @end
  @if c == "&" return 38 @end
  @if c == "'" return 39 @end
  @if c == "(" return 40 @end
  @if c == ")" return 41 @end
  @if c == "*" return 42 @end
  @if c == "+" return 43 @end
  @if c == "," return 44 @end
  @if c == "-" return 45 @end
  @if c == "." return 46 @end
  @if c == "/" return 47 @end
  @if c == "0" return 48 @end
  @if c == "1" return 49 @end
  @if c == "2" return 50 @end
  @if c == "3" return 51 @end
  @if c == "4" return 52 @end
  @if c == "5" return 53 @end
  @if c == "6" return 54 @end
  @if c == "7" return 55 @end
  @if c == "8" return 56 @end
  @if c == "9" return 57 @end
  @if c == ":" return 58 @end
  @if c == ";" return 59 @end
  @if c == "<" return 60 @end
  @if c == "=" return 61 @end
  @if c == ">" return 62 @end
  @if c == "?" return 63 @end
  @if c == "@" return 64 @end
  @if c == "A" return 65 @end
  @if c == "B" return 66 @end
  @if c == "C" return 67 @end
  @if c == "D" return 68 @end
  @if c == "E" return 69 @end
  @if c == "F" return 70 @end
  @if c == "G" return 71 @end
  @if c == "H" return 72 @end
  @if c == "I" return 73 @end
  @if c == "J" return 74 @end
  @if c == "K" return 75 @end
  @if c == "L" return 76 @end
  @if c == "M" return 77 @end
  @if c == "N" return 78 @end
  @if c == "O" return 79 @end
  @if c == "P" return 80 @end
  @if c == "Q" return 81 @end
  @if c == "R" return 82 @end
  @if c == "S" return 83 @end
  @if c == "T" return 84 @end
  @if c == "U" return 85 @end
  @if c == "V" return 86 @end
  @if c == "W" return 87 @end
  @if c == "X" return 88 @end
  @if c == "Y" return 89 @end
  @if c == "Z" return 90 @end
  @if c == "a" return 97 @end
  @if c == "b" return 98 @end
  @if c == "c" return 99 @end
  @if c == "d" return 100 @end
  @if c == "e" return 101 @end
  @if c == "f" return 102 @end
  @if c == "g" return 103 @end
  @if c == "h" return 104 @end
  @if c == "i" return 105 @end
  @if c == "j" return 106 @end
  @if c == "k" return 107 @end
  @if c == "l" return 108 @end
  @if c == "m" return 109 @end
  @if c == "n" return 110 @end
  @if c == "o" return 111 @end
  @if c == "p" return 112 @end
  @if c == "q" return 113 @end
  @if c == "r" return 114 @end
  @if c == "s" return 115 @end
  @if c == "t" return 116 @end
  @if c == "u" return 117 @end
  @if c == "v" return 118 @end
  @if c == "w" return 119 @end
  @if c == "x" return 120 @end
  @if c == "y" return 121 @end
  @if c == "z" return 122 @end
  return 0
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

// ─── Pure Lipi 2.0 String Algorithms & Case Transformations ───────────────────

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
    res = ""
    i = start
    while i <= end
        res = res + char_at(s, i)
        i = i + 1
    return res

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
    return contains(s, sub)

fn ধারণ_করে s sub
    return contains(s, sub)

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

// WHY: Extracts substring from [start, end) exclusive. Handles boundary clamps cleanly.
fn str_sub s start end
    slen = len(s)
    if start < 0
        start = 0
    if end > slen
        end = slen
    if start >= end
        return ""
    res = ""
    i = start
    while i < end
        res = res + char_at(s, i)
        i = i + 1
    return res

fn substring s start end
    return str_sub(s, start, end)

fn উপস্ট্রিং s start end
    return str_sub(s, start, end)

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

fn str_split s
    return split(s)

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

// WHY: Joins a list of items into a single string separated by sep.
fn str_join sep items
    count = len(items)
    if count == 0
        return ""
    res = "" + get(items, 0)
    i = 1
    while i < count
        res = res + sep + get(items, i)
        i = i + 1
    return res

fn যুক্ত_করো sep items
    return str_join(sep, items)

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
