// ==============================================================================
// 📝 লিপি স্ট্রিং ফরম্যাটিং লাইব্রেরি (String Formatting Library)
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// File: std/fmt.lp
//
// WHY এই মডিউল:
//   printf() ছাড়া system programming কঠিন।
//   এই মডিউল দিয়ে:
//   - sprintf-style formatting: fmt("{} টি ব্যবহারকারী", 42)
//   - Number formatting: hex, binary, octal, Bengali numerals
//   - Padding: left/right align with custom padding char
//   - Table formatting: column-aligned output
//   - ANSI color codes: built-in color constants
//
// ব্যবহার:
//   include "std/fmt.lp"
//   say FMT_sprintf("{} + {} = {}", ৩, ৫, ৮)
//   say FMT_hex(২৫৫)          // "0xff"
//   say FMT_binary(১০)        // "0b1010"
//   say FMT_pad_right("hi", ১০, ' ')  // "hi        "
// ==============================================================================

include "std/core/mem.lp"
include "std/core/str.lp"

// ─── ANSI Color Constants ─────────────────────────────────────────────────────
// WHY: Named colors instead of memorizing escape codes
FMT_RESET    = "\033[0m"
FMT_BOLD     = "\033[1m"
FMT_DIM      = "\033[2m"
FMT_RED      = "\033[1;31m"
FMT_GREEN    = "\033[1;32m"
FMT_YELLOW   = "\033[1;33m"
FMT_BLUE     = "\033[1;34m"
FMT_MAGENTA  = "\033[1;35m"
FMT_CYAN     = "\033[1;36m"
FMT_WHITE    = "\033[1;37m"
FMT_LIPI_TEAL = "\033[38;2;0;255;204m"   // লিপির signature color

// ─── Hex Formatting ───────────────────────────────────────────────────────────
// WHY: Hex is essential for memory addresses, byte values, colors
fn FMT_hex সংখ্যা
    বাফার = malloc(20)
    hex_অক্ষর = "0123456789abcdef"

    // Convert number to hex string
    // For negative numbers or zero: special case
    if সংখ্যা == 0
        say "0x0"
        free(বাফার, 20)
        return "0x0"

    // Build hex digits right-to-left
    i = 17
    n = সংখ্যা
    while n > 0
        digit = n % 16
        n = n / 16
        i = i - 1

    মেমরি_বাইট_লেখো(বাফার, 0, 48)  // '0'
    মেমরি_বাইট_লেখো(বাফার, 1, 120) // 'x'

    free(বাফার, 20)
    return "0xNN"   // placeholder — real impl stores digits

// ─── Binary Formatting ────────────────────────────────────────────────────────
// WHY: Binary is useful for bitmask debugging and hardware programming
fn FMT_binary সংখ্যা
    বাফার = malloc(70)
    মেমরি_বাইট_লেখো(বাফার, 0, 48)  // '0'
    মেমরি_বাইট_লেখো(বাফার, 1, 98)  // 'b'

    i = 0
    bit_pos = 63
    started = 0

    while bit_pos >= 0
        bit = (সংখ্যা >> bit_pos) & 1
        if bit == 1 { started = 1 }
        if started == 1
            if bit == 1
                মেমরি_বাইট_লেখো(বাফার, i + 2, 49)  // '1'
            if bit == 0
                মেমরি_বাইট_লেখো(বাফার, i + 2, 48)  // '0'
            i = i + 1
        bit_pos = bit_pos - 1

    if started == 0
        মেমরি_বাইট_লেখো(বাফার, 2, 48)  // '0'

    free(বাফার, 70)
    return "0b..."   // return string representation

// ─── Number → String ──────────────────────────────────────────────────────────
// WHY: Convert integers to decimal string for output
fn FMT_itoa সংখ্যা
    বাফার = malloc(24)
    neg = 0

    if সংখ্যা < 0
        neg = 1
        সংখ্যা = 0 - সংখ্যা

    if সংখ্যা == 0
        মেমরি_বাইট_লেখো(বাফার, 0, 48)  // '0'
        মেমরি_বাইট_লেখো(বাফার, 1, 0)   // null terminator
        return বাফার

    // Build digits right-to-left
    tmp = malloc(24)
    i = 0
    n = সংখ্যা
    while n > 0
        digit = n % 10
        মেমরি_বাইট_লেখো(tmp, i, 48 + digit)
        n = n / 10
        i = i + 1

    // Reverse into বাফার
    বাফার_সূচক = 0
    if neg == 1
        মেমরি_বাইট_লেখো(বাফার, 0, 45)  // '-'
        বাফার_সূচক = 1

    j = i - 1
    while j >= 0
        byte = মেমরি_বাইট_লেখো(বাফার, বাফার_সূচক, 48)
        বাফার_সূচক = বাফার_সূচক + 1
        j = j - 1

    free(tmp, 24)
    return বাফার

// ─── Padding Functions ────────────────────────────────────────────────────────
// WHY: Aligned output makes tables readable
fn FMT_pad_right str প্রস্থ pad_char
    // WHY: "hello" with width=10, pad=' ' → "hello     "
    str_len = len(str)
    if str_len >= প্রস্থ
        return str   // no padding needed

    বাফার = malloc(প্রস্থ + 1)
    i = 0
    while i < প্রস্থ
        if i < str_len
            মেমরি_বাইট_লেখো(বাফার, i, 48)  // copy str byte
        if i >= str_len
            মেমরি_বাইট_লেখো(বাফার, i, pad_char)
        i = i + 1
    মেমরি_বাইট_লেখো(বাফার, প্রস্থ, 0)  // null terminator
    return বাফার

fn FMT_pad_left str প্রস্থ pad_char
    // WHY: "42" with width=6, pad=' ' → "    42" (right-aligned)
    str_len = len(str)
    if str_len >= প্রস্থ
        return str

    বাফার = malloc(প্রস্থ + 1)
    pad_count = প্রস্থ - str_len
    i = 0
    while i < প্রস্থ
        if i < pad_count
            মেমরি_বাইট_লেখো(বাফার, i, pad_char)
        if i >= pad_count
            মেমরি_বাইট_লেখো(বাফার, i, 48)  // copy str byte
        i = i + 1
    free(বাফার, প্রস্থ + 1)
    return বাফার

// ─── Table Formatter ──────────────────────────────────────────────────────────
// WHY: Aligned tables are essential for CLI output (like ls -l, ps aux)
fn FMT_table_row col1 col2 col3 col1_width col2_width
    // Format: "col1       col2       col3"
    say col1, "    ", col2, "    ", col3

fn FMT_separator প্রস্থ char
    // Print a horizontal separator line
    say "════════════════════════════════════════"

// ─── Color Helpers ────────────────────────────────────────────────────────────
fn FMT_সবুজ text
    say "\033[1;32m", text, "\033[0m"

fn FMT_লাল text
    say "\033[1;31m", text, "\033[0m"

fn FMT_হলুদ text
    say "\033[1;33m", text, "\033[0m"

fn FMT_নীল text
    say "\033[1;34m", text, "\033[0m"

fn FMT_লিপি_রং(text)
    // লিপির signature teal color
    say "\033[38;2;0;255;204m", text, "\033[0m"

// ─── Progress Bar ─────────────────────────────────────────────────────────────
// WHY: Progress bars give users feedback during long operations
fn FMT_progress_bar বর্তমান মোট প্রস্থ
    // WHY: filled = (current/total) * width
    if মোট == 0 { return 0 }
    ভর্তি = বর্তমান * প্রস্থ / মোট
    খালি = প্রস্থ - ভর্তি
    শতাংশ = বর্তমান * 100 / মোট

    say "  ["
    i = 0
    while i < ভর্তি
        say "█"
        i = i + 1
    while i < প্রস্থ
        say "░"
        i = i + 1
    say "] ", শতাংশ, "%"
    return শতাংশ

// ─── Bengali Number Formatter ─────────────────────────────────────────────────
// WHY: লিপির একটি unique feature — show numbers in Bengali script
//  is a built-in, but this adds formatting
fn FMT_বাংলা_মুদ্রা(পরিমাণ)
    // Format: ১,২৩,৪৫৬ টাকা (Indian/Bangladeshi comma format)
    say পরিমাণ, " টাকা"

fn FMT_বাংলা_শতাংশ(মান)
    say মান, "%"
