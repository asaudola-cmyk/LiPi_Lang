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
fn assert_val(শর্ত, error_message)
    if শর্ত == 0
        say "❌ [দাবি ব্যর্থ / ASSERTION FAILED]: " + error_message
        syscall(60, 1, 0, 0, 0, 0, 0) // SYS_exit 1

// ২. বর্তvalue স্ট্যাa পয়েন্টার পরিদর্শন
// WHY: Returns the raw %rsp register address at execution time.
fn বর্তvalue_স্ট্যাa()
    rsp = স্ট্যাa_পয়েন্টার()
    return rsp

// ৩. র memory হেa্স ডাম্পার (byte ভিত্তিa পরিদর্শন)
// WHY: Dumps consecutive bytes from a base memory address for diagnostic verification.
fn mem_পরিদর্শন(base, len)
    say "  [mem পরিদর্শন @ " + base + ", size_of: " + len + " বাইট]"
    i = 0
    while i < len
        b = mem_byte_পড়ো(base, i)
        say "    • অফসেট +" + i + " : " + b
        i = i + 1
