@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: STREAMING JSON LEXER, PARSER & SERIALIZER
@! File: tests/e2e/tier4_applications/test_app_json_engine.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! ============================================================================

import "universe/core/string"

@struct JsonPair
  key: ""
  val: 0
@end

@struct JsonVal
  kind: 0       @! 0=Null, 1=Bool, 2=Int, 3=String, 4=Array, 5=Object
  bool_val: 0
  int_val: 0
  str_val: ""
  items: 0      @! array of JsonVal
  fields: 0      @! array of JsonPair
@end

@struct JsonScanner
  src: ""
  pos: 0
  len: 0
@end

@fn json_null()
  return { kind: 0, bool_val: 0, int_val: 0, str_val: "null", items: [], fields: [] }
@end

@fn json_bool(b)
  return { kind: 1, bool_val: b, int_val: 0, str_val: "", items: [], fields: [] }
@end

@fn json_int(n)
  return { kind: 2, bool_val: 0, int_val: n, str_val: "", items: [], fields: [] }
@end

@fn json_str(s)
  return { kind: 3, bool_val: 0, int_val: 0, str_val: s, items: [], fields: [] }
@end

@fn json_arr(arr)
  return { kind: 4, bool_val: 0, int_val: 0, str_val: "", items: arr, fields: [] }
@end

@fn json_obj(fields)
  return { kind: 5, bool_val: 0, int_val: 0, str_val: "", items: [], fields: fields }
@end

@fn skip_json_ws(s)
  @while s.pos < s.len
    c = char_at(s.src, s.pos)
    @if c == char_code(" ") || c == char_code("\t") || c == char_code("\n") || c == char_code("\r")
      s.pos = s.pos + 1
    @else
      return s
    @end
  @end
  return s
@end

@fn parse_json_string(s)
  s.pos = s.pos + 1  @! skip open quote '"'
  out = ""
  @while s.pos < s.len
    c = char_at(s.src, s.pos)
    @if c == char_code("\"")
      s.pos = s.pos + 1
      return out
    @elif c == char_code("\\")
      s.pos = s.pos + 1
      esc = char_at(s.src, s.pos)
      @if esc == char_code("n")
        out = out + "\n"
      @elif esc == char_code("t")
        out = out + "\t"
      @elif esc == char_code("r")
        out = out + "\r"
      @elif esc == char_code("\"")
        out = out + "\""
      @elif esc == char_code("\\")
        out = out + "\\"
      @else
        out = out + from_char(esc)
      @end
    @else
      out = out + from_char(c)
    @end
    s.pos = s.pos + 1
  @end
  return out
@end

@fn parse_json_number(s)
  num = 0
  is_neg = 0
  @if char_at(s.src, s.pos) == char_code("-")
    is_neg = 1
    s.pos = s.pos + 1
  @end
  @while s.pos < s.len
    c = char_at(s.src, s.pos)
    @if c >= char_code("0") && c <= char_code("9")
      num = num * 10 + (c - char_code("0"))
      s.pos = s.pos + 1
    @else
      break
    @end
  @end
  @if is_neg == 1
    return json_int(0 - num)
  @end
  return json_int(num)
@end

@fn parse_json_val(s)
  s = skip_json_ws(s)
  @if s.pos >= s.len
    return json_null()
  @end

  c = char_at(s.src, s.pos)

  @! String
  @if c == char_code("\"")
    str_content = parse_json_string(s)
    return json_str(str_content)
  @end

  @! Number
  @if (c >= char_code("0") && c <= char_code("9")) || c == char_code("-")
    return parse_json_number(s)
  @end

  @! Object '{'
  @if c == char_code("{")
    s.pos = s.pos + 1
    fields = []
    @while 1
      s = skip_json_ws(s)
      @if s.pos >= s.len || char_at(s.src, s.pos) == char_code("}")
        @if s.pos < s.len
          s.pos = s.pos + 1
        @end
        break
      @end
      @! Field key
      k = parse_json_string(s)
      s = skip_json_ws(s)
      @if s.pos < s.len && char_at(s.src, s.pos) == char_code(":")
        s.pos = s.pos + 1
      @end
      v = parse_json_val(s)
      fields.push({ key: k, val: v })
      s = skip_json_ws(s)
      @if s.pos < s.len && char_at(s.src, s.pos) == char_code(",")
        s.pos = s.pos + 1
      @end
    @end
    return json_obj(fields)
  @end

  @! Array '['
  @if c == char_code("[")
    s.pos = s.pos + 1
    items = []
    @while 1
      s = skip_json_ws(s)
      @if s.pos >= s.len || char_at(s.src, s.pos) == char_code("]")
        @if s.pos < s.len
          s.pos = s.pos + 1
        @end
        break
      @end
      item = parse_json_val(s)
      items.push(item)
      s = skip_json_ws(s)
      @if s.pos < s.len && char_at(s.src, s.pos) == char_code(",")
        s.pos = s.pos + 1
      @end
    @end
    return json_arr(items)
  @end

  @! Literals true, false, null
  @if string_starts_with(str_substr(s.src, s.pos, s.len), "true") == 1
    s.pos = s.pos + 4
    return json_bool(1)
  @elif string_starts_with(str_substr(s.src, s.pos, s.len), "false") == 1
    s.pos = s.pos + 5
    return json_bool(0)
  @elif string_starts_with(str_substr(s.src, s.pos, s.len), "null") == 1
    s.pos = s.pos + 4
    return json_null()
  @end

  s.pos = s.pos + 1
  return json_null()
@end

@fn parse_json(json_str)
  s = { src: json_str, pos: 0, len: str_len(json_str) }
  return parse_json_val(s)
@end

@fn json_get_field(obj, key_name)
  @if obj.kind != 5
    return json_null()
  @end
  i = 0
  len = obj.fields.len()
  @while i < len
    @if obj.fields[i].key == key_name
      return obj.fields[i].val
    @end
    i = i + 1
  @end
  return json_null()
@end

@fn json_get_index(arr, idx)
  @if arr.kind != 4 || idx < 0 || idx >= arr.items.len()
    return json_null()
  @end
  return arr.items[idx]
@end

@fn json_stringify(v)
  @if v.kind == 0
    return "null"
  @elif v.kind == 1
    @if v.bool_val == 1 return "true" @end
    return "false"
  @elif v.kind == 2
    return int_to_str(v.int_val)
  @elif v.kind == 3
    return "\"" + v.str_val + "\""
  @elif v.kind == 4
    out = "["
    i = 0
    len = v.items.len()
    @while i < len
      @if i > 0 out = out + ", " @end
      out = out + json_stringify(v.items[i])
      i = i + 1
    @end
    return out + "]"
  @elif v.kind == 5
    out = "{"
    i = 0
    len = v.fields.len()
    @while i < len
      @if i > 0 out = out + ", " @end
      out = out + "\"" + v.fields[i].key + "\": " + json_stringify(v.fields[i].val)
      i = i + 1
    @end
    return out + "}"
  @end
  return "null"
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Scenario 3: Streaming JSON Lexer & Parser Engine")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  payload = "{\"compiler\": \"Maya Self-Hosted\", \"version\": 2, \"release\": true, \"metadata\": {\"author\": \"Maya Core Team\", \"targets\": [\"x86_64\", \"arm64\", \"wasm\"]}, \"stats\": {\"modules\": 640, \"pass_rate\": 100, \"optimizations\": null}}"

  ast = parse_json(payload)

  @! T4.3.1: Top-Level Scalar Fields (compiler, version, release)
  total = total + 1
  c_val = json_get_field(ast, "compiler")
  v_val = json_get_field(ast, "version")
  r_val = json_get_field(ast, "release")

  @if c_val.kind == 3 && c_val.str_val == "Maya Self-Hosted" && v_val.kind == 2 && v_val.int_val == 2 && r_val.kind == 1 && r_val.bool_val == 1
    passed = passed + 1
    println("  [PASS] T4.3.1: Top-level scalar fields parsed (compiler=\"Maya Self-Hosted\", version=2, release=true)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3.1: Top-level fields failed")
  @end

  @! T4.3.2: Nested Object & Array Indexing (metadata.targets[1] == "arm64")
  total = total + 1
  meta = json_get_field(ast, "metadata")
  author = json_get_field(meta, "author")
  targets = json_get_field(meta, "targets")
  t0 = json_get_index(targets, 0)
  t1 = json_get_index(targets, 1)
  t2 = json_get_index(targets, 2)

  @if author.str_val == "Maya Core Team" && targets.items.len() == 3 && t0.str_val == "x86_64" && t1.str_val == "arm64" && t2.str_val == "wasm"
    passed = passed + 1
    println("  [PASS] T4.3.2: Nested array targets parsed: [\"x86_64\", \"arm64\", \"wasm\"]")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3.2: Nested array targets failed")
  @end

  @! T4.3.3: Numeric & Null Discriminants (stats.modules == 640, stats.optimizations == null)
  total = total + 1
  stats = json_get_field(ast, "stats")
  mods = json_get_field(stats, "modules")
  pass_rate = json_get_field(stats, "pass_rate")
  opts = json_get_field(stats, "optimizations")

  @if mods.int_val == 640 && pass_rate.int_val == 100 && opts.kind == 0
    passed = passed + 1
    println("  [PASS] T4.3.3: Numeric stats (modules=640, pass_rate=100) and Null literal parsed correctly")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3.3: Stats failed")
  @end

  @! T4.3.4: Serialization / Stringification Round-Trip
  total = total + 1
  serialized = json_stringify(ast)
  re_ast = parse_json(serialized)
  re_c = json_get_field(re_ast, "compiler")
  re_mods = json_get_field(json_get_field(re_ast, "stats"), "modules")

  @if re_c.str_val == "Maya Self-Hosted" && re_mods.int_val == 640
    passed = passed + 1
    println("  [PASS] T4.3.4: Re-serialized JSON re-parsed back to identical AST (round-trip idempotency)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3.4: Round-trip serialization failed")
  @end

  @! T4.3.5: Missing Field & Out of Bounds Safeguard
  total = total + 1
  missing_f = json_get_field(ast, "nonexistent_field")
  oob_item = json_get_index(targets, 99)

  @if missing_f.kind == 0 && oob_item.kind == 0
    passed = passed + 1
    println("  [PASS] T4.3.5: Missing fields and out-of-bounds array indices return JsonNull safely")
  @else
    failed = failed + 1
    println("  [FAIL] T4.3.5: Missing field safeguard failed")
  @end

  println("-----------------------------------------------------------------")
  println("Scenario 3 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Scenario 3 (JSON Lexer, Parser & Serializer) PASSED")
    return 0
  @else
    println("✗ Scenario 3 (JSON Lexer, Parser & Serializer) FAILED")
    return 1
  @end
@end
