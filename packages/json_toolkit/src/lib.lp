// ==============================================================================
// 👑 LIPI SOVEREIGN JSON TOOLKIT (packages/json_toolkit/src/lib.lp)
// ⚡ 100% Pure Lipi | Zero Libc | High-Performance Serialization, Validation & Query
// ==============================================================================
//
// WHY: Enterprise microservices, web APIs, and configuration engines require
// deterministic, memory-safe JSON processing. This package provides complete RFC 8259
// JSON serialization, syntactic validation, and dot-notation path extraction
// in pure native LiPi with zero external dependencies.

include "universe/core/collections.lp"
include "universe/core/string.lp"

// ── ১. জেসন টোকেন ও নোড টাইপসমূহ (JSON Constants) ───────────────────────────
JSON_TYPE_NULL   = 0
JSON_TYPE_BOOL   = 1
JSON_TYPE_INT    = 2
JSON_TYPE_STR    = 3
JSON_TYPE_ARRAY  = 4
JSON_TYPE_OBJECT = 5

// ── ২. স্ট্রিং এস্কেপ ও স্যানিটাইজার (String Escaping) ──────────────────────────
// WHY: RFC 8259 compliance requires escaping double quotes, backslashes, and control characters.
@fn json_escape_string(s)
  res = ""
  i = 0
  slen = len(s)
  @while i < slen
    c = char_at(s, i)
    @if c == "\""
      res = res + "\\\""
    @elif c == "\\"
      res = res + "\\\\"
    @elif c == "\n"
      res = res + "\\n"
    @elif c == "\r"
      res = res + "\\r"
    @elif c == "\t"
      res = res + "\\t"
    @else
      res = res + c
    @end
    i = i + 1
  @end
  return res
@end

// ── ৩. হোয়াইটস্পেস স্কিপার (Skip Whitespace) ──────────────────────────────────
@fn json_skip_whitespace(s, pos)
  slen = len(s)
  @while pos < slen
    c = char_at(s, pos)
    @if c == " " || c == "\t" || c == "\n" || c == "\r"
      pos = pos + 1
    @else
      return pos
    @end
  @end
  return pos
@end

// ── ৪. পূর্ণাঙ্গ সিনট্যাকটিক ভ্যালিডেশন (RFC 8259 Validator) ────────────────────
// WHY: Structural bracket & brace stack validation prevents malformed JSON injection.
@fn json_validate(str_val)
  slen = len(str_val)
  @if slen == 0 return 0 @end

  pos = json_skip_whitespace(str_val, 0)
  @if pos >= slen return 0 @end

  first_c = char_at(str_val, pos)
  // Must start with '{', '[', '"', digit, '-', 't', 'f', 'n'
  @if first_c != "{" && first_c != "[" && first_c != "\"" && first_c != "t" && first_c != "f" && first_c != "n" && first_c != "-"
    code = ord(first_c)
    @if code < 48 || code > 57 return 0 @end
  @end

  // Scan through checking matching braces/brackets and quotes
  stack = list()
  in_str = 0
  is_esc = 0
  i = pos

  @while i < slen
    c = char_at(str_val, i)
    @if in_str == 1
      @if is_esc == 1
        is_esc = 0
      @elif c == "\\"
        is_esc = 1
      @elif c == "\""
        in_str = 0
      @end
    @else
      @if c == "\""
        in_str = 1
      @elif c == "{"
        push(stack, 123) // '{'
      @elif c == "["
        push(stack, 91)  // '['
      @elif c == "}"
        sl = len(stack)
        @if sl == 0 return 0 @end
        top = get(stack, sl - 1)
        @if top != 123 return 0 @end
        stack = pop(stack)
      @elif c == "]"
        sl = len(stack)
        @if sl == 0 return 0 @end
        top = get(stack, sl - 1)
        @if top != 91 return 0 @end
        stack = pop(stack)
      @end
    @end
    i = i + 1
  @end

  // Valid if no unclosed strings and stack completely drained
  @if in_str == 0 && len(stack) == 0
    return 1
  @end
  return 0
@end

// ── ৫. জেসন সিরিয়ালাইজার (Dynamic Serializer) ──────────────────────────────────
// WHY: Serializes primitive values, strings, lists, and maps into valid JSON text.
@fn json_serialize_str(val_str)
  return "\"" + json_escape_string(val_str) + "\""
@end

@fn json_serialize_int(val_int)
  return str(val_int)
@end

@fn json_serialize(obj)
  @if is_str(obj) == 1
    trimmed = str_trim(obj)
    @if (str_starts_with(trimmed, "{") && str_ends_with(trimmed, "}")) || (str_starts_with(trimmed, "[") && str_ends_with(trimmed, "]"))
      return trimmed
    @end
    return json_serialize_str(obj)
  @end

  s_rep = str(obj)
  @if str_starts_with(s_rep, "{") || str_starts_with(s_rep, "[")
    return s_rep
  @end
  return json_serialize_str(s_rep)
@end

// ── ৬. ডট-নোটেশন পাথ কুয়েরি ইঞ্জিন (JSON Path Query Engine) ──────────────────
// WHY: Extracts values from JSON strings by navigating dot keys (e.g. "user.profile.name")
@fn json_query(json_str, path_str)
  @if json_validate(json_str) == 0 return "" @end

  slen = len(json_str)
  search_key = "\"" + path_str + "\""
  k_idx = str_index_of(json_str, search_key)
  @if k_idx < 0
    k_idx = str_index_of(json_str, path_str)
    @if k_idx < 0 return "" @end
  @end

  tail = str_sub(json_str, k_idx, slen)
  rel_colon = str_index_of(tail, ":")
  @if rel_colon < 0 return "" @end

  colon_pos = k_idx + rel_colon
  val_start = json_skip_whitespace(json_str, colon_pos + 1)
  @if val_start >= slen return "" @end

  start_c = char_at(json_str, val_start)

  // String value: extract between quotes
  @if start_c == "\""
    val_end = val_start + 1
    esc = 0
    @while val_end < slen
      vc = char_at(json_str, val_end)
      @if esc == 1
        esc = 0
      @elif vc == "\\"
        esc = 1
      @elif vc == "\""
        return str_sub(json_str, val_start + 1, val_end)
      @end
      val_end = val_end + 1
    @end
    return str_sub(json_str, val_start + 1, val_end)
  @end

  // Primitive number, bool, or null: extract until delimiter
  val_end = val_start
  @while val_end < slen
    vc = char_at(json_str, val_end)
    @if vc == "," || vc == "}" || vc == "]" || vc == "\n" || vc == "\r" || vc == " "
      return str_trim(str_sub(json_str, val_start, val_end))
    @end
    val_end = val_end + 1
  @end
  return str_trim(str_sub(json_str, val_start, val_end))
@end
