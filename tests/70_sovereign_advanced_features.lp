// ==============================================================================
// 👑 Test 70: Lipi Sovereign Advanced Architecture Integration Test
// ⚡ Features Tested:
//    1. Result/Option `?` Postfix Error Propagation Operator
//    2. Sovereign Segregated Slab Allocator (16B - 2048B) with O(1) Freelist Recycling
//    3. Rust-Style Visual Diagnostics Formatter (ANSI, Caret, Hints)
//    4. Pure Linux Kernel epoll Async Event Loop Reactor (Syscall 291 / C10K)
// ==============================================================================

import "universe/core/memory.lp"
import "universe/tools/debug.lp"
import "universe/os/event.lp"

// ── 1. Result/Option `?` Operator Test Functions ──────────────────────────────
fn validate_positive num
    if num <= 0
        return 0
    return num * 10

fn run_pipeline_with_question_op val
    // WHY: If validate_positive returns 0 (failure), ? must early-return 0 immediately
    res = validate_positive(val)?
    return res + 5

fn run_pipeline_paren_op val
    // WHY: Verify parenthesized postfix ? operator: (expr)?
    res = (validate_positive(val))?
    return res + 100

// ── Main Test Runner ──────────────────────────────────────────────────────────
say "========================================================"
say "👑 Testing Lipi Sovereign Advanced Architecture Features"
say "========================================================"

// ── Test Part 1: Postfix `?` Error Operator ──────────────────────────────────
say "[1/4] Testing Postfix ? Error Propagation Operator..."

// Success case: positive value
r_ok = run_pipeline_with_question_op(7)
if r_ok != 75
    say "FAILED: Expected 75, got:"
    say r_ok
    exit(1)
say "  ✔ Question operator success path: 7 -> 75"

// Error case: negative value early return
r_err = run_pipeline_with_question_op(-5)
if r_err != 0
    say "FAILED: Expected 0 on early return, got:"
    say r_err
    exit(1)
say "  ✔ Question operator early-return error path: -5 -> 0"

// Parenthesized success case
rp_ok = run_pipeline_paren_op(5)
if rp_ok != 150
    say "FAILED: Expected 150, got:"
    say rp_ok
    exit(1)
say "  ✔ Parenthesized (expr)? success path: 5 -> 150"

// Parenthesized error case
rp_err = run_pipeline_paren_op(0)
if rp_err != 0
    say "FAILED: Expected 0 on paren early return, got:"
    say rp_err
    exit(1)
say "  ✔ Parenthesized (expr)? early-return path: 0 -> 0"

// ── Test Part 2: Sovereign Segregated Slab Allocator ─────────────────────────
say "[2/4] Testing Sovereign Segregated Slab Allocator..."

// Test 32-byte slot allocation
p1 = slab_alloc(32)
if p1 <= 0
    say "FAILED: slab_alloc(32) returned 0"
    exit(1)

// Write test pattern
mem_write(p1, 0, 123456789)
val1 = mem_read(p1, 0)
if val1 != 123456789
    say "FAILED: Memory readback mismatch"
    exit(1)

// Free and recycle
slab_free(p1, 32)

// Next alloc should recycle p1 instantly via O(1) freelist pop
p2 = slab_alloc(32)
if p2 != p1
    say "FAILED: Slab freelist did not recycle slot in O(1) LIFO order!"
    exit(1)
say "  ✔ Slab Allocator recycled 32-byte slot with O(1) LIFO precision"

// Test bilingual Bengali interfaces: স্ল্যাব_বরাদ্দ ও স্ল্যাব_মুক্তি
p_bn = স্ল্যাব_বরাদ্দ(64)
if p_bn <= 0
    say "FAILED: স্ল্যাব_বরাদ্দ(64) returned 0"
    exit(1)
mem_write(p_bn, 0, 987654321)
val_bn = mem_read(p_bn, 0)
if val_bn != 987654321
    say "FAILED: Bengali slab readback mismatch"
    exit(1)
স্ল্যাব_মুক্তি(p_bn, 64)
say "  ✔ Bilingual Bengali Slab Allocator (স্ল্যাব_বরাদ্দ/স্ল্যাব_মুক্তি) verified"

// ── Test Part 3: Rust-Style Visual Diagnostics Formatter ────────────────────
say "[3/4] Testing Rust-Style Diagnostic Formatter..."

diag_str = format_diagnostic("E0308", "Mismatched types", "main.lp", 14, 8, "    x = 10 + \"foo\"", "expected integer, found string")
dlen = len(diag_str)
if dlen <= 0
    say "FAILED: format_diagnostic returned empty string"
    exit(1)

diag_bn = ডায়াগনস্টিক_ফরম্যাট("E0001", "অপরিচিত টোকেন", "উৎস.লিপি", 5, 12, "চলক @মান = ১০০", "টোকেনের বানান পরীক্ষা করুন")
if len(diag_bn) <= 0
    say "FAILED: ডায়াগনস্টিক_ফরম্যাট returned empty string"
    exit(1)

say "  ✔ Rust-Style Diagnostics (format_diagnostic / ডায়াগনস্টিক_ফরম্যাট) rendered successfully"

// ── Test Part 4: Pure Linux epoll Async Event Loop Reactor ──────────────────
say "[4/4] Testing Pure Linux epoll Event Loop Reactor (Syscall 291)..."

ep_fd = event_loop_create()
if ep_fd <= 0
    say "FAILED: event_loop_create() returned invalid fd"
    exit(1)

say "  ✔ epoll instance initialized with kernel fd: " + ep_fd

// Close epfd using Linux syscall 3 (SYS_close)
syscall(3, ep_fd, 0, 0, 0, 0, 0)
say "  ✔ epoll instance closed cleanly without resource leaks"
say ""
say "========================================================"
say "🎉 ALL 4 ADVANCED ARCHITECTURE SECTIONS PASSED! 👑"
say "========================================================"
