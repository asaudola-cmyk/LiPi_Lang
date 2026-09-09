// std/json.lp — Lipi 2.0 JSON Library
// Global Standard | JSON parse and serialize

// JSON value types
JSON_NULL   = 0
JSON_BOOL   = 1
JSON_NUMBER = 2
JSON_STRING = 3
JSON_ARRAY  = 4
JSON_OBJECT = 5

// Serialize a string value
fn json_str s
    return "\"" + s + "\""

// Serialize a number
fn json_num n = str n

// Serialize boolean
fn json_bool b
    if b
        return "true"
    return "false"

// Serialize null
fn json_null = "null"

// Build JSON object from two key-value pairs
fn json_obj2 k1 v1 k2 v2
    return "{\"" + k1 + "\": " + v1 + ", \"" + k2 + "\": " + v2 + "}"

// Build JSON array from two elements
fn json_arr2 a b
    return "[" + a + ", " + b + "]"

// Build simple response
fn json_response_ok data
    return "{\"status\": \"ok\", \"data\": " + data + "}"

fn json_response_err msg
    return "{\"status\": \"error\", \"message\": " + json_str msg + "}"

// Parse: check if string looks like JSON number
fn json_is_num s
    if len s == 0
        return 0
    return 1  // Simplified

// Pretty print
fn json_pretty obj indent
    say obj
