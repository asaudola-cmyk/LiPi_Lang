// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: SOVEREIGN DEBUGGING & INTROSPECTION (std/debug.lp)
// ⚡ Runtime Assertions | Physical Stack Inspection | Hardware Breakpoint Hooks
// ==============================================================================

// WHY: High-reliability systems programming requires deep runtime diagnostics.
// std/debug.lp provides assertion primitives, stack inspection, and debugging utilities
// without external runtime or libc dependency.

include "universe/core/memory.lp"

// ১. রানটাইম এসার্শন যাচাই (assert_val / assert)
// WHY: Ensures invariant correctness. If condition evaluates to 0 (false),
// immediately reports failure message to console and exits with code 1.
fn assert_val শর্ত error_message
    if শর্ত == 0
        say "❌ [দাবি ব্যর্থ / ASSERTION FAILED]: " + error_message
        syscall(60, 1, 0, 0, 0, 0, 0) // SYS_exit 1

fn দাবি শর্ত error_message
    assert_val(শর্ত, error_message)

// ২. বর্তমান স্ট্যাক পয়েন্টার পরিদর্শন
// WHY: Returns the raw %rsp register address at execution time.
fn বর্তমান_স্ট্যাক
    rsp = স্ট্যাক_পয়েন্টার()
    return rsp

fn stack_ptr
    return stack_pointer()

// ৩. র মেমরি হেক্স ডাম্পার (বাইটভিত্তিক পরিদর্শন)
// WHY: Dumps consecutive bytes from a base memory address for diagnostic verification.
fn mem_পরিদর্শন base len
    say "  [মেমরি পরিদর্শন @ " + base + ", সাইজ: " + len + " বাইট]"
    i = 0
    while i < len
        b = mem_byte_পড়ো(base, i)
        say "    • অফসেট +" + i + " : " + b
        i = i + 1

fn mem_dump base len
    mem_পরিদর্শন(base, len)

// ── ৪. রাস্ট-স্টাইল ভিজুয়াল ডায়াগনস্টিকস (Rust-Style Diagnostic Engine) ───────────
// WHY: আধুনিক ডেভেলপার অভিজ্ঞতার (DX) জন্য রঙিন, ভিজুয়াল ও সুনির্দিষ্ট সমাধানমূলক এরর বক্স রেন্ডার করা।
// সোর্স কোডের লাইন, কলাম ও লাল ক্যারোট (^) দিয়ে এরর লোকেশন চিহ্নিত করে এবং সাহায্যকারী টিপস প্রদর্শন করে।
fn format_diagnostic err_code title file_path line_no col_no line_content hint
    esc = chr(27)
    c_red = esc + "[1;31m"
    c_cyan = esc + "[1;36m"
    c_yellow = esc + "[1;33m"
    c_bold = esc + "[1m"
    c_reset = esc + "[0m"

    actual_col = col_no
    if actual_col <= 0
        actual_col = 1

    actual_line = line_no
    if actual_line <= 0
        actual_line = 1

    out = ""
    out = out + c_red + "Error[" + err_code + "]" + c_reset + ": " + c_bold + title + c_reset + "\n"
    out = out + "  " + c_cyan + "-->" + c_reset + " " + file_path + ":" + str(actual_line) + ":" + str(actual_col) + "\n"
    out = out + "   " + c_cyan + "|" + c_reset + "\n"

    line_str = str(actual_line)
    pad = ""
    if len(line_str) == 1
        pad = " "

    out = out + pad + line_str + " " + c_cyan + "|" + c_reset + " " + line_content + "\n"

    // Construct pointing caret line
    caret_pad = ""
    ci = 1
    while ci < actual_col
        caret_pad = caret_pad + " "
        ci = ci + 1

    out = out + "   " + c_cyan + "|" + c_reset + " " + caret_pad + c_red + "^ " + title + c_reset + "\n"
    out = out + "   " + c_cyan + "|" + c_reset + "\n"

    if len(hint) > 0
        out = out + "   " + c_yellow + "= help" + c_reset + ": " + hint + "\n"

    return out

fn ডায়াগনস্টিক_ফরম্যাট err_code title file_path line_no col_no line_content hint
    return format_diagnostic(err_code, title, file_path, line_no, col_no, line_content, hint)
