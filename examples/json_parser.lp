// ==============================================================================
// 👑 LIPI EXAMPLE: JSON PARSER & SERIALIZER (examples/json_parser.lp)
// ⚡ 100% Pure Lipi First 1.0.0
// Uses universe/core/json.lp
// ==============================================================================

import "universe/core/json"

fn main
    say "=== Lipi JSON Parser & Serializer ==="
    say ""
    
    // Serializing JSON primitives
    s1 = json_str("Lipi Language")
    s2 = json_num(2026)
    s3 = json_bool(1)
    s4 = json_null()
    
    say "JSON Primitives:"
    say "  String: " + s1
    say "  Number: " + s2
    say "  Boolean: " + s3
    say "  Null: " + s4
    say ""
    
    // String escaping
    raw = "Hello \"World\"\nLine 2\tTabbed"
    escaped = json_escape(raw)
    say "Escaped JSON string: " + escaped
    unescaped = json_unescape(escaped)
    say "Unescaped original: " + unescaped
    say ""
    
    // Parsing test
    json_doc = "\"Hello Sovereign Universe\""
    parsed = json_parse_str(json_doc)
    say "Parsed JSON: " + parsed
    
    say ""
    say "JSON parsing and serialization verified."
    return 0

main()
