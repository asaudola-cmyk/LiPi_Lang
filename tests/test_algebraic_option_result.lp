// ==============================================================================
// 👑 LIPI TEST SUITE: ALGEBRAIC OPTION & MONADIC RESULT (Pillar 1)
// ⚡ 100% Pure LiPi Implementation | Zero C | Zero Libc | Zero Stack Unwinding
// 🏛️ File: tests/test_algebraic_option_result.lp
// ==============================================================================

include "universe/core/error.lp"
include "universe/core/option.lp"
include "universe/core/result.lp"

fn assert_eq actual expected msg
    if actual != expected
        say "  ❌ [FAIL] " + msg + " (Expected: " + str(expected) + ", Got: " + str(actual) + ")"
        exit(1)
    say "  ✔ [PASS] " + msg

fn assert_true cond msg
    if cond == 0
        say "  ❌ [FAIL] " + msg
        exit(1)
    say "  ✔ [PASS] " + msg

fn main
    say "================================================================="
    say "👑 TESTING LIPI ALGEBRAIC OPTION & MONADIC RESULT ENGINE"
    say "================================================================="

    // ── 1. Basic Option Constructors & Unwrapping ─────────────────────────────
    say "▶ Section 1: Pure Option Construction & Invariants..."
    opt_val = some(42)
    assert_eq(is_some(opt_val), 1, "is_some(some(42)) == 1")
    assert_eq(is_none(opt_val), 0, "is_none(some(42)) == 0")
    assert_eq(unwrap_option(opt_val), 42, "unwrap_option(some(42)) == 42")
    assert_eq(unwrap_option_or(opt_val, 999), 42, "unwrap_option_or(some(42), 999) == 42")

    opt_empty = option_none()
    assert_eq(is_some(opt_empty), 0, "is_some(option_none()) == 0")
    assert_eq(is_none(opt_empty), 1, "is_none(option_none()) == 1")
    assert_eq(unwrap_option_or(opt_empty, 999), 999, "unwrap_option_or(option_none(), 999) == 999 fallback")

    // Test raw 0 / null literal safety
    assert_eq(is_some(0), 0, "is_some(0) safe null guard == 0")
    assert_eq(is_none(0), 1, "is_none(0) safe null guard == 1")
    assert_eq(unwrap_option_or(0, 500), 500, "unwrap_option_or(0, 500) == 500")

    // ── 2. Option Monadic Combinators ─────────────────────────────────────────
    say "▶ Section 2: Option Monadic Combinators (map, and_then, or)..."
    opt_mapped = option_map(opt_val, 84)
    assert_eq(unwrap_option(opt_mapped), 84, "option_map on Some produces Some(84)")

    opt_mapped_empty = option_map(opt_empty, 100)
    assert_eq(is_none(opt_mapped_empty), 1, "option_map on None propagates None")

    next_opt = option_some(200)
    chained = option_and_then(opt_val, next_opt)
    assert_eq(unwrap_option(chained), 200, "option_and_then(Some, Some(200)) returns Some(200)")

    chained_none = option_and_then(opt_empty, next_opt)
    assert_eq(is_none(chained_none), 1, "option_and_then(None, Some) propagates None")

    or_opt = option_or(opt_empty, option_some(555))
    assert_eq(unwrap_option(or_opt), 555, "option_or(None, Some(555)) recovers with Some(555)")

    // ── 3. Conversion Between Option & Result ──────────────────────────────────
    say "▶ Section 3: Isomorphic Option <-> Result Conversions..."
    res_from_opt = option_to_result(opt_val, "missing value")
    assert_eq(is_ok(res_from_opt), 1, "option_to_result(Some(42)) is Ok")
    assert_eq(unwrap(res_from_opt), 42, "option_to_result value is 42")

    res_from_none = option_to_result(opt_empty, "item not found")
    assert_eq(is_err(res_from_none), 1, "option_to_result(None) is Err")
    assert_eq(unwrap_or(res_from_none, 777), 777, "unwrap_or on Err returns fallback 777")

    opt_from_ok = result_to_option(ok(314))
    assert_eq(unwrap_option(opt_from_ok), 314, "result_to_option(Ok(314)) is Some(314)")

    opt_from_err = result_to_option(err("failure"))
    assert_eq(is_none(opt_from_err), 1, "result_to_option(Err) is None")

    // ── 4. Panic-Free Pure Arithmetic via Result ──────────────────────────────
    say "▶ Section 4: Pure Arithmetic Fault Handling (Division & Parse)..."
    div_good = try_divide(100, 5)
    assert_eq(is_ok(div_good), 1, "try_divide(100, 5) succeeds")
    assert_eq(unwrap(div_good), 20, "100 / 5 == 20")

    div_zero = try_divide(100, 0)
    assert_eq(is_err(div_zero), 1, "try_divide(100, 0) is Err (zero div guarded)")
    assert_eq(unwrap_or(div_zero, -1), -1, "unwrap_or on division by zero returns -1")

    // ── 5. Bengali Native Tri-Syntax Aliases ───────────────────────────────────
    say "▶ Section 5: Bengali Sovereign Native Tri-Syntax Invariants..."
    বাংলা_অপশন = কিছু(777)
    assert_eq(আছে_কি(বাংলা_অপশন), 1, "আছে_কি(কিছু(777)) == 1")
    assert_eq(নাই_কি(বাংলা_অপশন), 0, "নাই_কি(কিছু(777)) == 0")
    assert_eq(খোল_বা_ফেরত(বাংলা_অপশন, 0), 777, "খোল_বা_ফেরত(বাংলা_অপশন, 0) == 777")

    বাংলা_শূন্য = নাই()
    assert_eq(নাই_কি(বাংলা_শূন্য), 1, "নাই_কি(নাই()) == 1")
    assert_eq(খোল_বা_ফেরত(বাংলা_শূন্য, 999), 999, "খোল_বা_ফেরত(নাই(), 999) == 999")

    বাংলা_সফল = সফল(888)
    assert_eq(সফল_কি(বাংলা_সফল), 1, "সফল_কি(সফল(888)) == 1")
    assert_eq(রেজাল্ট_খোল(বাংলা_সফল), 888, "রেজাল্ট_খোল(সফল(888)) == 888")

    বাংলা_ব্যর্থ = ব্যর্থ("সার্বভৌম ত্রুটি")
    assert_eq(ব্যর্থ_কি(বাংলা_ব্যর্থ), 1, "ব্যর্থ_কি(ব্যর্থ(...)) == 1")
    assert_eq(রেজাল্ট_খোল_বা_ফেরত(বাংলা_ব্যর্থ, 123), 123, "রেজাল্ট_খোল_বা_ফেরত == 123")

    নিরাপদ_ভাগ = ভাগ_করো_নিরাপদে(50, 2)
    assert_eq(রেজাল্ট_খোল(নিরাপদ_ভাগ), 25, "ভাগ_করো_নিরাপদে(50, 2) == 25")

    say "================================================================="
    say "🎉 ALL ALGEBRAIC OPTION & RESULT TESTS PASSED (100% GREEN)!"
    say "================================================================="
    return 0
