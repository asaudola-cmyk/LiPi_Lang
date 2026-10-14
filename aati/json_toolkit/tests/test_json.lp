import "packages/json_toolkit/src/lib"

@fn main()
  println("--- JSON Toolkit Test Suite ---")
  
  // 1. Validation Tests
  v_empty = json_validate("{}")
  v_arr = json_validate("[1, 2, 3]")
  v_nested = json_validate("{\"name\": \"lipi\", \"version\": 1, \"features\": [\"fast\", \"pure\"]}")
  v_bad1 = json_validate("{unclosed: 1")
  v_bad2 = json_validate("[1, 2, 3}")

  @if v_empty != 1 || v_arr != 1 || v_nested != 1
    println("FAIL: json_validate valid")
    return 1
  @end
  @if v_bad1 != 0 || v_bad2 != 0
    println("FAIL: json_validate invalid rejection")
    return 1
  @end
  println("PASS: json_validate")

  // 2. Escape Tests
  esc = json_escape_string("hello \"world\"\nnewline\ttab")
  @if str_contains(esc, "\\\"") == 0 || str_contains(esc, "\\n") == 0
    println("FAIL: json_escape_string")
    return 1
  @end
  println("PASS: json_escape_string")

  // 3. Serialization Tests
  s_str = json_serialize_str("lipi_language")
  @if s_str != "\"lipi_language\""
    println("FAIL: json_serialize_str")
    return 1
  @end
  println("PASS: json_serialize_str")

  s_int = json_serialize_int(42)
  @if s_int != "42"
    println("FAIL: json_serialize_int")
    return 1
  @end
  println("PASS: json_serialize_int")

  // 4. Query Engine Tests (Dot Path / Key Extraction)
  json_doc = "{\"project\": \"Lipi\", \"stars\": 9999, \"active\": true}"
  q_proj = json_query(json_doc, "project")
  q_stars = json_query(json_doc, "stars")
  q_active = json_query(json_doc, "active")

  @if q_proj != "Lipi"
    println("FAIL: json_query string")
    return 1
  @end
  println("PASS: json_query string")

  @if q_stars != "9999"
    println("FAIL: json_query int")
    return 1
  @end
  println("PASS: json_query int")

  @if q_active != "true"
    println("FAIL: json_query bool")
    return 1
  @end
  println("PASS: json_query bool")

  println("=== ALL JSON TOOLKIT TESTS PASSED ===")
  return 0
@end
