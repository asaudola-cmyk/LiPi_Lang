// std/fmt.lp — Lipi 2.0 Formatting Library
// Global Standard | String formatting utilities

// Pad integer with leading zeros
fn pad_int n width
    s = str n
    pad = width - len s
    if pad <= 0
        return s
    result = ""
    i = 0
    while i < pad
        result = result + "0"
        i = i + 1
    return result + s

// Format bytes as human-readable size
fn format_bytes n
    if n < 1024
        return str n + " B"
    elif n < 1048576
        return str n / 1024 + " KB"
    elif n < 1073741824
        return str n / 1048576 + " MB"
    else
        return str n / 1073741824 + " GB"

// Format duration in ms as human-readable
fn format_ms ms
    if ms < 1000
        return str ms + "ms"
    elif ms < 60000
        return str ms / 1000 + "s"
    else
        return str ms / 60000 + "min"

// Print key: value table
fn print_kv key value
    say key + ": " + value

// Print section header
fn print_header title
    say "=== " + title + " ==="

// Print success / failure
fn print_ok msg
    say "[OK] " + msg

fn print_fail msg
    say "[FAIL] " + msg

fn print_warn msg
    say "[WARN] " + msg

// ANSI colors (terminal)
FMT_RESET   = "\033[0m"
FMT_BOLD    = "\033[1m"
FMT_RED     = "\033[31m"
FMT_GREEN   = "\033[32m"
FMT_YELLOW  = "\033[33m"
FMT_BLUE    = "\033[34m"
FMT_CYAN    = "\033[36m"

fn color_ok msg   = "[GREEN]" + msg
fn color_err msg  = "[RED]" + msg
fn color_warn msg = "[YELLOW]" + msg
