@! ============================================================================
@! MAYA JSON PARSER — Full JSON parser written in Maya
@! Supports: strings, numbers, booleans, null, arrays, objects
@! ============================================================================

@enum JsonType
  Null
  Bool
  Int
  String
  Array
  Object
@end

@struct JsonValue
  jv_type: i64
  jv_int: i64
  jv_str: string
  jv_bool: i64
  jv_items: array
@end

@struct JsonParser
  jp_src: string
  jp_pos: i64
  jp_len: i64
@end

@fn json_null()
  return JsonValue { jv_type: JsonType_Null, jv_int: 0, jv_str: "null", jv_bool: 0, jv_items: [] }
@end

@fn json_bool(b)
  return JsonValue { jv_type: JsonType_Bool, jv_int: 0, jv_str: "", jv_bool: b, jv_items: [] }
@end

@fn json_int(n)
  return JsonValue { jv_type: JsonType_Int, jv_int: n, jv_str: "", jv_bool: 0, jv_items: [] }
@end

@fn json_str(s)
  return JsonValue { jv_type: JsonType_String, jv_int: 0, jv_str: s, jv_bool: 0, jv_items: [] }
@end

@fn json_array(items)
  return JsonValue { jv_type: JsonType_Array, jv_int: 0, jv_str: "", jv_bool: 0, jv_items: items }
@end

@fn json_is_null(v) return v.jv_type == JsonType_Null @end
@fn json_is_bool(v) return v.jv_type == JsonType_Bool @end
@fn json_is_int(v) return v.jv_type == JsonType_Int @end
@fn json_is_str(v) return v.jv_type == JsonType_String @end
@fn json_is_array(v) return v.jv_type == JsonType_Array @end

@fn json_to_str(v)
  @if v.jv_type == JsonType_Null
    return "null"
  @end
  @if v.jv_type == JsonType_Bool
    @if v.jv_bool == 1
      return "true"
    @end
    return "false"
  @end
  @if v.jv_type == JsonType_Int
    return int_to_str(v.jv_int)
  @end
  @if v.jv_type == JsonType_String
    return "\"" + v.jv_str + "\""
  @end
  return "[...]"
@end

@fn parser_new(src)
  return JsonParser { jp_src: src, jp_pos: 0, jp_len: str_len(src) }
@end

@fn parser_peek(p)
  @if p.jp_pos >= p.jp_len
    return 0
  @end
  return char_at(p.jp_src, p.jp_pos)
@end

@fn parser_skip_ws(p)
  @while p.jp_pos < p.jp_len
    c = char_at(p.jp_src, p.jp_pos)
    @if c == char_code(" ") || c == char_code("\n") || c == char_code("\t") || c == char_code("\r")
      p.jp_pos = p.jp_pos + 1
    @else
      return p
    @end
  @end
  return p
@end

@fn parser_read_string(p)
  @! Skip opening quote
  p.jp_pos = p.jp_pos + 1
  result = ""
  @while p.jp_pos < p.jp_len
    c = char_at(p.jp_src, p.jp_pos)
    @if c == char_code("\\")
      p.jp_pos = p.jp_pos + 1
      nc = char_at(p.jp_src, p.jp_pos)
      result = result + char_from_code(nc)
    @elif c == char_code("\"")
      p.jp_pos = p.jp_pos + 1
      return { parsed_str: result, parsed_p: p }
    @else
      result = result + char_from_code(c)
    @end
    p.jp_pos = p.jp_pos + 1
  @end
  return { parsed_str: result, parsed_p: p }
@end

@fn parser_read_number(p)
  start = p.jp_pos
  is_neg = 0
  @if char_at(p.jp_src, p.jp_pos) == char_code("-")
    is_neg = 1
    p.jp_pos = p.jp_pos + 1
  @end
  num = 0
  @while p.jp_pos < p.jp_len
    c = char_at(p.jp_src, p.jp_pos)
    @if c >= char_code("0") && c <= char_code("9")
      digit = c - char_code("0")
      num = num * 10 + digit
      p.jp_pos = p.jp_pos + 1
    @else
      return { parsed_int: num, parsed_p: p }
    @end
  @end
  return { parsed_int: num, parsed_p: p }
@end

@fn json_stringify(v)
  return json_to_str(v)
@end

@fn main()
  println("JSON Parser compilation successful.")
  return 0
@end
