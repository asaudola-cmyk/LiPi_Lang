// Test 49: String Formatting — Lipi 2.0 Global Standard
// String interpolation, padding, templates

fn pad_left s width
    result = ""
    i = len s
    while i < width
        result = result + " "
        i = i + 1
    return result + s

fn pad_right s width
    result = s
    i = len s
    while i < width
        result = result + " "
        i = i + 1
    return result

fn center_str s width
    total_pad = width - len s
    left_pad  = total_pad / 2
    right_pad = total_pad - left_pad
    result = ""
    i = 0
    while i < left_pad
        result = result + " "
        i = i + 1
    result = result + s
    i = 0
    while i < right_pad
        result = result + " "
        i = i + 1
    return result

fn repeat_char c n
    result = ""
    i = 0
    while i < n
        result = result + c
        i = i + 1
    return result

say "=== String Formatting ==="
// String interpolation
name = "Lipi"
ver  = 2
say "Welcome to {name} {ver}.0!"
say "The answer is {42 + 0}!"

// Padding
say pad_left "42" 10
say pad_right "hello" 10

// Table formatting
say repeat_char "-" 30
say pad_right "Name" 15 + pad_right "Score" 10
say repeat_char "-" 30
say pad_right "Alice" 15 + pad_right "95" 10
say pad_right "Bob" 15 + pad_right "87" 10
say pad_right "Charlie" 15 + pad_right "72" 10
say repeat_char "-" 30

// Interpolation in loop
for i in 1..5
    say "Item {i}: value={i * i}"

say "PASS: Test 49 String Formatting"
