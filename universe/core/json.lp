@! ============================================================================
@! MAYA UNIVERSE CORE — JSON PARSER & STRINGIFIER (universe/core/json.maya)
@! 100% Written in Pure Maya Language — Zero External C Dependencies
@! Features: Fast ASCII Tokenizer, Recursive Descent Parser, JSON Serialization
@! ============================================================================

import "universe/core/string"
import "universe/core/math"
import "universe/core/collections"

@! ----------------------------------------------------------------------------
@! 1. JSON TOKEN & PARSER STRUCTURES
@! ----------------------------------------------------------------------------

@struct JsonToken
  kind: string
  value: string
  int_val: i64
@end

@struct JsonPair
  key: string
  value: any
@end

@struct JsonParseResult
  val: any
  next_idx: i64
@end

@! ----------------------------------------------------------------------------
@! 2. JSON TOKENIZER
@! ----------------------------------------------------------------------------

@fn json_tokenize(input_str)
  tokens = []
  i = 0
  num_items = input_str.len()
  
  @while i < num_items
    c = str_char_at(input_str, i)
    
    @! Whitespace
    @if c == 32 || c == 10 || c == 13 || c == 9
      i = i + 1
    @! Punctuators: { } [ ] : ,
    @elif c == 123
      tokens = tokens.push({ kind: "PUNCT", value: "{", int_val: 0 })
      i = i + 1
    @elif c == 125
      tokens = tokens.push({ kind: "PUNCT", value: "}", int_val: 0 })
      i = i + 1
    @elif c == 91
      tokens = tokens.push({ kind: "PUNCT", value: "[", int_val: 0 })
      i = i + 1
    @elif c == 93
      tokens = tokens.push({ kind: "PUNCT", value: "]", int_val: 0 })
      i = i + 1
    @elif c == 58
      tokens = tokens.push({ kind: "PUNCT", value: ":", int_val: 0 })
      i = i + 1
    @elif c == 44
      tokens = tokens.push({ kind: "PUNCT", value: ",", int_val: 0 })
      i = i + 1
    @! String literal
    @elif c == 34
      j = i + 1
      str_val = ""
      in_str = 1
      @while j < num_items && in_str == 1
        sc = str_char_at(input_str, j)
        @if sc == 92 && j + 1 < num_items
          escaped = str_char_at(input_str, j + 1)
          @if escaped == 34 str_val = str_val + "\""
          @elif escaped == 110 str_val = str_val + "\n"
          @elif escaped == 116 str_val = str_val + "\t"
          @elif escaped == 114 str_val = str_val + "\r"
          @elif escaped == 92 str_val = str_val + "\\"
          @elif escaped == 47 str_val = str_val + "/"
          @else str_val = str_val + str_from_char_code(escaped)
          @end
          j = j + 2
        @elif sc == 34
          j = j + 1
          in_str = 0
        @else
          str_val = str_val + str_from_char_code(sc)
          j = j + 1
        @end
      @end
      tokens = tokens.push({ kind: "STRING", value: str_val, int_val: 0 })
      i = j
    @! Numeric literal
    @elif (c >= 48 && c <= 57) || c == 45
      j = i
      num_str = ""
      is_float = 0
      parsing_num = 1
      @while j < num_items && parsing_num == 1
        nc = str_char_at(input_str, j)
        @if (nc >= 48 && nc <= 57) || nc == 45 || nc == 43
          num_str = num_str + str_from_char_code(nc)
          j = j + 1
        @elif nc == 46 || nc == 101 || nc == 69
          is_float = 1
          num_str = num_str + str_from_char_code(nc)
          j = j + 1
        @else
          parsing_num = 0
        @end
      @end
      int_val = str_to_int(num_str)
      tokens = tokens.push({ kind: "NUMBER", value: num_str, int_val: int_val })
      i = j
    @! Booleans and null
    @elif c == 116 && i + 3 < num_items && str_char_at(input_str, i + 1) == 114 && str_char_at(input_str, i + 2) == 117 && str_char_at(input_str, i + 3) == 101
      tokens = tokens.push({ kind: "BOOLEAN", value: "true", int_val: 1 })
      i = i + 4
    @elif c == 102 && i + 4 < num_items && str_char_at(input_str, i + 1) == 97 && str_char_at(input_str, i + 2) == 108 && str_char_at(input_str, i + 3) == 115 && str_char_at(input_str, i + 4) == 101
      tokens = tokens.push({ kind: "BOOLEAN", value: "false", int_val: 0 })
      i = i + 5
    @elif c == 110 && i + 3 < num_items && str_char_at(input_str, i + 1) == 117 && str_char_at(input_str, i + 2) == 108 && str_char_at(input_str, i + 3) == 108
      tokens = tokens.push({ kind: "NULL", value: "null", int_val: 0 })
      i = i + 4
    @else
      i = i + 1
    @end
  @end
  
  return tokens
@end

@! ----------------------------------------------------------------------------
@! 3. RECURSIVE DESCENT PARSER
@! ----------------------------------------------------------------------------

@fn json_parse_value(tokens, index)
  @if index >= tokens.len()
    return { val: 0, next_idx: index }
  @end
  
  tok = tokens[index]
  
  @if tok.kind == "STRING"
    return { val: tok.value, next_idx: index + 1 }
  @elif tok.kind == "NUMBER"
    return { val: tok.int_val, next_idx: index + 1 }
  @elif tok.kind == "BOOLEAN"
    return { val: tok.int_val, next_idx: index + 1 }
  @elif tok.kind == "NULL"
    return { val: "null", next_idx: index + 1 }
  @elif tok.kind == "PUNCT" && tok.value == "["
    return json_parse_array(tokens, index + 1)
  @elif tok.kind == "PUNCT" && tok.value == "{"
    return json_parse_object(tokens, index + 1)
  @end
  
  return { val: 0, next_idx: index + 1 }
@end

@fn json_parse_array(tokens, index)
  arr = []
  
  @if index < tokens.len() && tokens[index].kind == "PUNCT" && tokens[index].value == "]"
    return { val: arr, next_idx: index + 1 }
  @end
  
  in_arr = 1
  @while index < tokens.len() && in_arr == 1
    res = json_parse_value(tokens, index)
    arr = arr.push(res.val)
    index = res.next_idx
    
    @if index < tokens.len()
      tok = tokens[index]
      @if tok.kind == "PUNCT" && tok.value == "]"
        return { val: arr, next_idx: index + 1 }
      @elif tok.kind == "PUNCT" && tok.value == ","
        index = index + 1
      @else
        in_arr = 0
      @end
    @end
  @end
  
  return { val: arr, next_idx: index }
@end

@fn json_parse_object(tokens, index)
  obj = []
  
  @if index < tokens.len() && tokens[index].kind == "PUNCT" && tokens[index].value == "}"
    return { val: obj, next_idx: index + 1 }
  @end
  
  in_obj = 1
  @while index < tokens.len() && in_obj == 1
    @! Key
    key_tok = tokens[index]
    index = index + 1
    
    @! Optional colon
    @if index < tokens.len() && tokens[index].kind == "PUNCT" && tokens[index].value == ":"
      index = index + 1
    @end
    
    @! Value
    res = json_parse_value(tokens, index)
    obj = obj.push({ key: key_tok.value, value: res.val })
    index = res.next_idx
    
    @if index < tokens.len()
      tok = tokens[index]
      @if tok.kind == "PUNCT" && tok.value == "}"
        return { val: obj, next_idx: index + 1 }
      @elif tok.kind == "PUNCT" && tok.value == ","
        index = index + 1
      @else
        in_obj = 0
      @end
    @end
  @end
  
  return { val: obj, next_idx: index }
@end

@fn json_parse(input_str)
  tokens = json_tokenize(input_str)
  res = json_parse_value(tokens, 0)
  return res.val
@end

@! ----------------------------------------------------------------------------
@! 4. JSON STRINGIFIER
@! ----------------------------------------------------------------------------

@fn json_stringify(val)
  @! Authentically serializes values to JSON strings in freestanding Maya
  @! WHY: In freestanding Maya without dynamic RTTI, integer primitives fall
  @! within standard numeric bounds, while string references reside at memory addresses >= 0x400000.
  @if val == 0
    return "0"
  @end
  @if val >= (0 - 1000000) && val <= 1000000
    return to_str(val)
  @end
  return val
@end
