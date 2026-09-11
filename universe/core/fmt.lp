// ==============================================================================
// 🎨 লিপি স্ট্রিং ফরম্যাটিং ও প্যাডিং ইঞ্জিন (std/fmt.lp)
// লিপি প্রথম ২.০ | ciphername: সোভেরিন
// File: std/fmt.lp
//
// WHY এই মডিউল:
//   Production-grade string formatting, padding, alignment, hex encoding,
//   and human-readable byte sizes in 100% pure Lipi 2.0 with Zero Libc.
// ==============================================================================

include "universe/core/string.lp"

// ─── 1. String Padding & Alignment ───────────────────────────────────────────

// WHY: Pads string on left with spaces up to the requested column width.
fn pad_left s width
    slen = len(s)
    if slen >= width
        return s
    pad = width - slen
    result = ""
    i = 0
    while i < pad
        result = result + " "
        i = i + 1
    return result + s

// WHY: Pads string on left with a custom character up to the requested column width.
fn pad_left_char s width ch
    slen = len(s)
    if slen >= width
        return s
    pad = width - slen
    result = ""
    i = 0
    while i < pad
        result = result + ch
        i = i + 1
    return result + s

// WHY: Pads string on right with spaces up to the requested column width.
fn pad_right s width
    slen = len(s)
    if slen >= width
        return s
    result = s
    pad = width - slen
    i = 0
    while i < pad
        result = result + " "
        i = i + 1
    return result

// WHY: Pads string on right with a custom character up to the requested column width.
fn pad_right_char s width ch
    slen = len(s)
    if slen >= width
        return s
    result = s
    pad = width - slen
    i = 0
    while i < pad
        result = result + ch
        i = i + 1
    return result

// WHY: Centers string inside a given width with balanced left/right space padding.
fn center_str s width
    slen = len(s)
    if slen >= width
        return s
    total_pad = width - slen
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

fn pad_center s width
    return center_str(s, width)

// WHY: Repeats a single character or string n times.
fn repeat_char c n
    if n <= 0
        return ""
    result = ""
    i = 0
    while i < n
        result = result + c
        i = i + 1
    return result

// WHY: Pads integer with leading zeros to guarantee fixed digit width (e.g. 0042).
fn pad_int n width
    s = str(n)
    pad = width - len(s)
    if pad <= 0
        return s
    result = ""
    i = 0
    while i < pad
        result = result + "0"
        i = i + 1
    return result + s

// WHY: Truncates long text strings exceeding max_len and appends ellipsis suffix.
fn truncate_str s max_len suffix
    slen = len(s)
    if slen <= max_len
        return s
    suf_len = len(suffix)
    cut = max_len - suf_len
    if cut <= 0
        return suffix
    return str_sub(s, 0, cut) + suffix

// WHY: Formats large integers with standard thousands-separating commas (e.g. 1,234,567).
fn format_number_commas n
    s = str(n)
    slen = len(s)
    if slen <= 3
        return s
    res = ""
    i = slen - 1
    count = 0
    while i >= 0
        res = char_at(s, i) + res
        count = count + 1
        if count == 3 and i > 0
            res = "," + res
            count = 0
        i = i - 1
    return res

// ─── 2. Hexadecimal Formatting ────────────────────────────────────────────────

// WHY: Converts a positive integer into an uppercase hexadecimal string.
fn to_hex n
    if n == 0
        return "0"
    digits = "0123456789ABCDEF"
    res = ""
    val = n
    while val > 0
        rem = val % 16
        res = char_at(digits, rem) + res
        val = val / 16
    return res

// WHY: Converts an integer into a lowercase hexadecimal string.
fn to_hex_lower n
    if n == 0
        return "0"
    digits = "0123456789abcdef"
    res = ""
    val = n
    while val > 0
        rem = val % 16
        res = char_at(digits, rem) + res
        val = val / 16
    return res

// WHY: Formats integer with standard "0x" prefix in uppercase hexadecimal.
fn format_hex n
    return "0x" + to_hex(n)

// WHY: Formats integer with standard "0x" prefix in lowercase hexadecimal.
fn format_hex_lower n
    return "0x" + to_hex_lower(n)

// WHY: Formats an 8-bit byte as exactly two uppercase hex characters (e.g. 0A, FF).
fn format_hex_byte b
    val = b % 256
    digits = "0123456789ABCDEF"
    hi = val / 16
    lo = val % 16
    return char_at(digits, hi) + char_at(digits, lo)

// WHY: Formats hexadecimal value zero-padded to a minimum number of hex digits.
fn format_hex_padded n width
    h = to_hex(n)
    while len(h) < width
        h = "0" + h
    return "0x" + h

// ─── 3. Byte Size & Duration Formatting ───────────────────────────────────────

// WHY: Formats raw byte count into human-readable B, KB, MB, GB, or TB string.
fn format_bytes n
    if n < 1024
        return str(n) + " B"
    elif n < 1048576
        return str(n / 1024) + " KB"
    elif n < 1073741824
        return str(n / 1048576) + " MB"
    elif n < 1099511627776
        return str(n / 1073741824) + " GB"
    else
        return str(n / 1099511627776) + " TB"

// WHY: Formats byte count with one decimal place of precision (e.g. 1.5 KB, 10.2 MB).
fn format_bytes_dec n
    if n < 1024
        return str(n) + " B"
    elif n < 1048576
        whole = n / 1024
        frac = ((n % 1024) * 10) / 1024
        return str(whole) + "." + str(frac) + " KB"
    elif n < 1073741824
        whole = n / 1048576
        frac = ((n % 1048576) * 10) / 1048576
        return str(whole) + "." + str(frac) + " MB"
    elif n < 1099511627776
        whole = n / 1073741824
        frac = ((n % 1073741824) * 10) / 1073741824
        return str(whole) + "." + str(frac) + " GB"
    else
        whole = n / 1099511627776
        frac = ((n % 1099511627776) * 10) / 1099511627776
        return str(whole) + "." + str(frac) + " TB"

// WHY: Formats duration in milliseconds to human-readable ms, s, min, or h.
fn format_ms ms
    if ms < 1000
        return str(ms) + "ms"
    elif ms < 60000
        return str(ms / 1000) + "s"
    elif ms < 3600000
        return str(ms / 60000) + "min"
    else
        return str(ms / 3600000) + "h"

// ─── 4. Terminal Output, Tables & Colors ───────────────────────────────────────

// WHY: Formats aligned key-value pair for terminal dashboards and info blocks.
fn format_kv key value
    return key + ": " + value

fn print_kv key value
    say format_kv(key, value)

// WHY: Emits standard section header with decorative delimiters.
fn print_header title
    say "=== " + title + " ==="

// WHY: Standardized status indicators for terminal tools and regression runners.
fn print_ok msg
    say "[OK] " + msg

fn print_fail msg
    say "[FAIL] " + msg

fn print_warn msg
    say "[WARN] " + msg

fn print_info msg
    say "[INFO] " + msg

// ANSI Terminal Colors (using chr(27) sovereign escape character)
FMT_ESC     = chr(27)
FMT_RESET   = FMT_ESC + "[0m"
FMT_BOLD    = FMT_ESC + "[1m"
FMT_RED     = FMT_ESC + "[31m"
FMT_GREEN   = FMT_ESC + "[32m"
FMT_YELLOW  = FMT_ESC + "[33m"
FMT_BLUE    = FMT_ESC + "[34m"
FMT_MAGENTA = FMT_ESC + "[35m"
FMT_CYAN    = FMT_ESC + "[36m"
FMT_WHITE   = FMT_ESC + "[37m"

fn color_ok msg
    return FMT_GREEN + "[OK] " + msg + FMT_RESET

fn color_err msg
    return FMT_RED + "[ERR] " + msg + FMT_RESET

fn color_warn msg
    return FMT_YELLOW + "[WARN] " + msg + FMT_RESET

fn color_info msg
    return FMT_CYAN + "[INFO] " + msg + FMT_RESET

// ─── 5. Bilingual Bengali Aliases ─────────────────────────────────────────────
// WHY: Native Bengali developer ergonomics alongside global English standard.
fn প্যাড_বাম s width
    return pad_left(s, width)

fn প্যাড_ডান s width
    return pad_right(s, width)

fn প্যাড_কেন্দ্র s width
    return center_str(s, width)

fn ফরম্যাট_হেক্স n
    return format_hex(n)

fn ফরম্যাট_বাইট n
    return format_bytes(n)

fn প্রিন্ট_হেডার title
    print_header(title)

fn প্রিন্ট_সফল msg
    print_ok(msg)
