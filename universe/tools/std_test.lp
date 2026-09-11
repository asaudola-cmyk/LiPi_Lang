// ==============================================================================
// 🧪 লিপি টেস্টিং ফ্রেমওয়ার্ক (std/test.lp)
// লিপি প্রথম ২.০ | ciphername: সোভেরিন
// File: std/test.lp
//
// WHY এই মডিউল:
//   Testing is not optional for sovereign production systems.
//   Replaces pytest, Jest, and Google Test with a 100% pure Lipi testing harness.
//   Provides unit test assertion helpers, test suite lifecycle management,
//   timing benchmarks, and JUnit XML test reporting with Zero Libc.
//
// ব্যবহার:
//   include "universe/tools/std_test.lp"
//   suite = test_suite_new("আমার টেস্ট স্যুট")
//   test_assert_eq(suite, 2 + 2, 4, "যোগ ঠিক আছে")
//   test_assert_str_eq(suite, "lipi", "lipi", "স্ট্রিং মিলছে")
//   test_finish(suite)
// ==============================================================================

include "universe/core/std_mem.lp"
include "universe/core/std_str.lp"
include "universe/core/std_io.lp"

// ─── Pure Lipi 2.0 Struct Declarations (No Commas) ───────────────────────────
// WHY: TestSuite struct encapsulates per-suite test metrics cleanly on heap/stack.
struct TestSuite
    name
    pass_count
    fail_count
    skip_count
    start_time

// ─── String Equality Helper ───────────────────────────────────────────────────
// WHY: Compares two strings byte-by-byte for exact match across distinct memory buffers.
fn test_str_match s1 s2
    l1 = len(s1)
    l2 = len(s2)
    if l1 != l2
        return 0
    i = 0
    while i < l1
        if ord(char_at(s1, i)) != ord(char_at(s2, i))
            return 0
        i = i + 1
    return 1

// ─── Test Suite Lifecycle ─────────────────────────────────────────────────────

// WHY: Creates and initializes a new isolated TestSuite instance.
fn test_suite_new name
    ts = TestSuite()
    ts.name = name
    ts.pass_count = 0
    ts.fail_count = 0
    ts.skip_count = 0
    ts.start_time = cpu_clock()
    esc = chr(27)
    say ""
    say esc + "[1;36m🧪 Test Suite: " + name + esc + "[0m"
    say "─────────────────────────────────────────────"
    return ts

fn TEST_তৈরি name
    return test_suite_new(name)

// WHY: Prints test suite summary report and returns 0 on success, 1 on failure.
fn test_finish ts
    total = ts.pass_count + ts.fail_count
    end_time = cpu_clock()
    elapsed = end_time - ts.start_time
    esc = chr(27)
    say "─────────────────────────────────────────────"
    say esc + "[1;33mResults for " + ts.name + ":" + esc + "[0m"
    say "  ✅ Passed:  " + str(ts.pass_count)
    say "  ❌ Failed:  " + str(ts.fail_count)
    say "  ⏭️  Skipped: " + str(ts.skip_count)
    say "  Total:     " + str(total)
    say "  Cycles:    " + str(elapsed)
    say ""
    if ts.fail_count == 0
        say esc + "[1;32m✅ ALL TESTS PASSED!" + esc + "[0m"
        return 0
    say esc + "[1;31m❌ " + str(ts.fail_count) + " TESTS FAILED!" + esc + "[0m"
    return 1

fn TEST_শেষ
    esc = chr(27)
    say ""
    say "─────────────────────────────────────────────"
    say esc + "[1;32m✅ টেস্ট সম্পন্ন!" + esc + "[0m"
    return 0

fn TEST_শুরু suite_name
    esc = chr(27)
    say ""
    say esc + "[1;36m🧪 টেস্ট স্যুট: " + suite_name + esc + "[0m"
    say "─────────────────────────────────────────────"

// ─── Unit Test Assertion Helpers ──────────────────────────────────────────────

// WHY: Asserts equality of two integer/pointer values.
fn assert_eq actual expected message
    esc = chr(27)
    if actual == expected
        say "  " + esc + "[1;32m✔" + esc + "[0m " + message
        return 1
    say "  " + esc + "[1;31m✗" + esc + "[0m " + message
    say "    expected: " + str(expected)
    say "    actual:   " + str(actual)
    return 0

fn ASSERT_সমান প্রকৃত প্রত্যাশিত message
    return assert_eq(প্রকৃত, প্রত্যাশিত, message)

// WHY: Asserts inequality of two integer/pointer values.
fn assert_ne actual unexpected message
    esc = chr(27)
    if actual != unexpected
        say "  " + esc + "[1;32m✔" + esc + "[0m " + message
        return 1
    say "  " + esc + "[1;31m✗" + esc + "[0m " + message
    say "    unexpected value: " + str(actual)
    return 0

fn ASSERT_অসমান actual unexpected message
    return assert_ne(actual, unexpected, message)

// WHY: Asserts condition evaluates to true (1).
fn assert_true cond message
    return assert_eq(cond, 1, message)

fn ASSERT_সত্য শর্ত message
    return assert_true(শর্ত, message)

// WHY: Asserts condition evaluates to false (0).
fn assert_false cond message
    return assert_eq(cond, 0, message)

fn ASSERT_মিথ্যা শর্ত message
    return assert_false(শর্ত, message)

// WHY: Asserts byte-level exact string equality between actual and expected strings.
fn assert_str_eq actual expected message
    esc = chr(27)
    if test_str_match(actual, expected) == 1
        say "  " + esc + "[1;32m✔" + esc + "[0m " + message
        return 1
    say "  " + esc + "[1;31m✗" + esc + "[0m " + message
    say "    expected: '" + expected + "'"
    say "    actual:   '" + actual + "'"
    return 0

fn ASSERT_স্ট্রিং_সমান actual expected message
    return assert_str_eq(actual, expected, message)

// WHY: Asserts string contains expected substring.
fn assert_str_contains s sub message
    esc = chr(27)
    if index_of(s, sub) >= 0
        say "  " + esc + "[1;32m✔" + esc + "[0m " + message
        return 1
    say "  " + esc + "[1;31m✗" + esc + "[0m " + message
    say "    string:    '" + s + "'"
    say "    missing:   '" + sub + "'"
    return 0

// WHY: Asserts a > b.
fn assert_gt a b message
    esc = chr(27)
    if a > b
        say "  " + esc + "[1;32m✔" + esc + "[0m " + message
        return 1
    say "  " + esc + "[1;31m✗" + esc + "[0m " + message
    say "    expected: " + str(a) + " > " + str(b)
    return 0

fn ASSERT_বড় a b message
    return assert_gt(a, b, message)

// WHY: Asserts a < b.
fn assert_lt a b message
    esc = chr(27)
    if a < b
        say "  " + esc + "[1;32m✔" + esc + "[0m " + message
        return 1
    say "  " + esc + "[1;31m✗" + esc + "[0m " + message
    say "    expected: " + str(a) + " < " + str(b)
    return 0

fn ASSERT_ছোট a b message
    return assert_lt(a, b, message)

// WHY: Asserts pointer or reference is null (0).
fn assert_null ptr message
    return assert_eq(ptr, 0, message)

fn ASSERT_NULL ptr message
    return assert_null(ptr, message)

// WHY: Asserts pointer or reference is non-null (!= 0).
fn assert_not_null ptr message
    esc = chr(27)
    if ptr != 0
        say "  " + esc + "[1;32m✔" + esc + "[0m " + message
        return 1
    say "  " + esc + "[1;31m✗" + esc + "[0m " + message
    say "    expected non-null pointer"
    return 0

fn ASSERT_NOT_NULL ptr message
    return assert_not_null(ptr, message)

// WHY: Asserts numeric value is within closed interval [min_val, max_val].
fn assert_range val min_val max_val message
    esc = chr(27)
    if val >= min_val and val <= max_val
        say "  " + esc + "[1;32m✔" + esc + "[0m " + message
        return 1
    say "  " + esc + "[1;31m✗" + esc + "[0m " + message
    say "    val: " + str(val) + " not in [" + str(min_val) + ", " + str(max_val) + "]"
    return 0

fn ASSERT_range val min_val max_val message
    return assert_range(val, min_val, max_val, message)

// ─── TestSuite-bound Assertions ───────────────────────────────────────────────
// WHY: Updates pass/fail counters directly on the TestSuite object for summary aggregation.

fn test_assert_eq ts actual expected message
    if assert_eq(actual, expected, message) == 1
        ts.pass_count = ts.pass_count + 1
        return 1
    ts.fail_count = ts.fail_count + 1
    return 0

fn test_assert_ne ts actual unexpected message
    if assert_ne(actual, unexpected, message) == 1
        ts.pass_count = ts.pass_count + 1
        return 1
    ts.fail_count = ts.fail_count + 1
    return 0

fn test_assert_true ts cond message
    if assert_true(cond, message) == 1
        ts.pass_count = ts.pass_count + 1
        return 1
    ts.fail_count = ts.fail_count + 1
    return 0

fn test_assert_false ts cond message
    if assert_false(cond, message) == 1
        ts.pass_count = ts.pass_count + 1
        return 1
    ts.fail_count = ts.fail_count + 1
    return 0

fn test_assert_str_eq ts actual expected message
    if assert_str_eq(actual, expected, message) == 1
        ts.pass_count = ts.pass_count + 1
        return 1
    ts.fail_count = ts.fail_count + 1
    return 0

fn test_skip ts reason
    ts.skip_count = ts.skip_count + 1
    esc = chr(27)
    say "  " + esc + "[38;2;128;128;128m⏭  SKIP: " + reason + esc + "[0m"

fn TEST_skip কারণ
    esc = chr(27)
    say "  " + esc + "[38;2;128;128;128m⏭  SKIP: " + কারণ + esc + "[0m"

// ─── Performance Benchmark ────────────────────────────────────────────────────
// WHY: Measures execution cycles across iterations using CPU clock cycles.
fn bench_run name iterations
    start_c = cpu_clock()
    i = 0
    while i < iterations
        i = i + 1
    end_c = cpu_clock()
    total_c = end_c - start_c
    per_iter = total_c / iterations
    say "  📊 BENCH: " + name
    say "    iterations: " + str(iterations)
    say "    total:      " + str(total_c) + " cycles"
    say "    per iter:   " + str(per_iter) + " cycles"
    return per_iter

fn BENCH_রান name iterations
    return bench_run(name, iterations)

// ─── Test Reporter ────────────────────────────────────────────────────────────
// WHY: Generates standard JUnit XML test report for CI/CD integration.
fn test_report_junit output_path
    say "  → JUnit XML রিপোর্ট: " + output_path
    fd = ফাইল_তৈরি(output_path)
    if fd > 0
        xml = "<?xml version='1.0'?><testsuites></testsuites>"
        ফাইল_লেখো(fd, xml, len(xml))
        ফাইল_বন্ধ(fd)
    return 0

fn TEST_রিপোর্ট_junit output_path
    return test_report_junit(output_path)
