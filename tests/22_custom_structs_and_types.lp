// Test 22: Type System Demo — Lipi 2.0
// Demonstrates: runtime type checking patterns, value classification, guards

// Classify an integer as negative, zero, or positive
fn classify_sign x
    if x < 0
        return "negative"
    elif x == 0
        return "zero"
    else
        return "positive"

// Check if a value is within a valid range
fn in_range x lo hi
    if x >= lo and x <= hi
        return 1
    return 0

// Tag value by magnitude
fn type_tag x
    if x < 0
        y = 0 - x
    else
        y = x
    if y <= 255
        return "byte"
    elif y <= 65535
        return "short"
    else
        return "int"

// Clamp to byte range [0, 255]
fn to_byte x
    if x < 0
        return 0
    if x > 255
        return 255
    return x

// Struct with typed fields
struct TypedRecord
    int_val
    flag
    level

fn make_record iv flag lvl
    r = TypedRecord()
    r.int_val = iv
    r.flag = flag
    r.level = lvl
    return r

// Test classify_sign — use variable for negative input
say "Sign of -7:"
neg7 = 0 - 7
say classify_sign neg7

say "Sign of 0:"
say classify_sign 0

say "Sign of 42:"
say classify_sign 42

// in_range with paren syntax
say "in_range(5, 1, 10):"
say in_range(5, 1, 10)

say "in_range(15, 1, 10):"
say in_range(15, 1, 10)

say "type_tag(42):"
say type_tag 42

say "type_tag(70000):"
say type_tag 70000

say "to_byte(300):"
say to_byte 300

say "to_byte(-5):"
say to_byte(0 - 5)

// Struct-based typed record using paren syntax
rec = make_record(1024, 1, 3)
say "Record int_val:"
say rec.int_val
say "Record flag:"
say rec.flag
say "Record level:"
say rec.level

say "PASS: Test 22 Type System"
