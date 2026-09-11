// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: SOVEREIGN DEBUGGING & INTROSPECTION (std/debug.lp)
// ⚡ Runtime Assertions | Physical Stack Inspection | Hardware Breakpoint Hooks
// ==============================================================================

// WHY: High-reliability systems programming requires deep runtime diagnostics.
// std/debug.lp provides assertion primitives, stack inspection, and debugging utilities
// without external runtime or libc dependency.

include "std/mem.lp"

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
