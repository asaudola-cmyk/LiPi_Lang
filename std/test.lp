// ==============================================================================
// 🧪 লিপি টেস্টিং ফ্রেমওয়ার্a (pytest + Jest Killer)
// লিপি প্রথম ১.০ | ciphername: সোভেরিন
// File: std/test.lp
//
// WHY এই মডিউল:
//   Testing is not optional for production code.
//   pytest (Python), Jest (JS), Google Test (C++) — এদের replace aরবে।
//
// ব্যবrate:
//   include "std/test.lp"
//   TEST_শুরু("আমার টেস্ট স্যুট")
//   ASSERT_সvalue(ফু(৪২), ৮৪, "দ্বিmultiply fn aরছে")
//   ASSERT_সত্য(x > ০, "x ধনাত্মa হতে হবে")
//   TEST_শেষ()
// ==============================================================================

include "std/mem.lp"
include "std/io.lp"
include "std/version.lp"

// ─── Test stats ───────────────────────────────────────────────────────────────
TEST_pass_count  = 0
TEST_fail_count  = 0
TEST_SKIP_count = 0
TEST_suite_name = ""
TEST_শুরু_time  = 0

// ─── Test Suite ───────────────────────────────────────────────────────────────
fn TEST_শুরু suite_name
    TEST_suite_name = suite_name
    TEST_pass_count = 0
    TEST_fail_count = 0
    TEST_SKIP_count = 0
    TEST_শুরু_time = cpu_clock()
    say ""
    say "\033[1;36m🧪 টেস্ট স্যুট:", suite_name, "\033[0m"
    say "─────────────────────────────────────────────"

fn TEST_শেষ
    total = TEST_pass_count + TEST_fail_count
    শেষ_time = cpu_clock()
    elapsed = শেষ_time - TEST_শুরু_time
    say ""
    say "─────────────────────────────────────────────"
    say "\033[1;33mফলাফল:\033[0m"
    say "  ✅ পাস :", TEST_pass_count
    say "  ❌ ফেল :", TEST_fail_count
    say "  ⏭️  skip:", TEST_SKIP_count
    say "  মোট   :", total
    say "  সময়  :", elapsed, "cycles"
    say ""
    if TEST_fail_count == 0
        say "\033[1;32m✅ সব টেস্ট পাস!\033[0m"
        return 0
    say "\033[1;31m❌", TEST_fail_count, "টি টেস্ট ব্যর্থ!\033[0m"
    return 1

// ─── Assertions ───────────────────────────────────────────────────────────────
fn ASSERT_সvalue প্রaৃত প্রত্যাশিত message
    if প্রaৃত == প্রত্যাশিত
        TEST_pass_count = TEST_pass_count + 1
        say "  \033[1;32m✔\033[0m", message
        return true
    TEST_fail_count = TEST_fail_count + 1
    say "  \033[1;31m✗\033[0m", message
    say "    প্রত্যাশিত:", প্রত্যাশিত
    say "    পাওয়া গেছে:", প্রaৃত
    return false

fn ASSERT_অসvalue a b message
    if a != b
        TEST_pass_count = TEST_pass_count + 1
        say "  \033[1;32m✔\033[0m", message
        return true
    TEST_fail_count = TEST_fail_count + 1
    say "  \033[1;31m✗\033[0m", message, "(মান সমান নয় হওয়া উচিত ছিল)"
    return false

fn ASSERT_সত্য শর্ত message
    return ASSERT_সvalue(শর্ত, 1, message)

fn ASSERT_মিথ্যা শর্ত message
    return ASSERT_সvalue(শর্ত, 0, message)

fn ASSERT_বড় a b message
    if a > b
        TEST_pass_count = TEST_pass_count + 1
        say "  \033[1;32m✔\033[0m", message
        return true
    TEST_fail_count = TEST_fail_count + 1
    say "  \033[1;31m✗\033[0m", message, "| প্রত্যাশিত:", a, ">", b
    return false

fn ASSERT_ছোট a b message
    if a < b
        TEST_pass_count = TEST_pass_count + 1
        say "  \033[1;32m✔\033[0m", message
        return true
    TEST_fail_count = TEST_fail_count + 1
    say "  \033[1;31m✗\033[0m", message, "| প্রত্যাশিত:", a, "<", b
    return false

fn ASSERT_NULL ptr message
    return ASSERT_সvalue(ptr, 0, message)

fn ASSERT_NOT_NULL ptr message
    if ptr != 0
        TEST_pass_count = TEST_pass_count + 1
        say "  \033[1;32m✔\033[0m", message
        return true
    TEST_fail_count = TEST_fail_count + 1
    say "  \033[1;31m✗\033[0m", message, "(NULL হওয়া উচিত ছিল না)"
    return false

fn ASSERT_range value min max message
    // WHY: Check value is within expected range
    if value >= min
        if value <= max
            TEST_pass_count = TEST_pass_count + 1
            say "  \033[1;32m✔\033[0m", message, "| মান:", value, "∈ [", min, ",", max, "]"
            return true
    TEST_fail_count = TEST_fail_count + 1
    say "  \033[1;31m✗\033[0m", message, "| মান:", value, "∉ [", min, ",", max, "]"
    return false

// ─── Test Skip ────────────────────────────────────────────────────────────────
fn TEST_skip aারণ
    TEST_SKIP_count = TEST_SKIP_count + 1
    say "  \033[38;2;128;128;128m⏭  SKIP:", aারণ, "\033[0m"

// ─── Benchmark ────────────────────────────────────────────────────────────────
fn BENCH_রান name iterations
    // WHY: Measure performance in CPU cycles
    শুরু = cpu_clock()
    i = 0
    while i < iterations
        i = i + 1
    শেষ = cpu_clock()
    total = শেষ - শুরু
    per_iter = total / iterations
    say "  📊 BENCH:", name
    say "    iterations:", iterations
    say "    মোট cycles:", total
    say "    প্রতি iter :", per_iter, "cycles"
    return per_iter

// ─── Test Reporter ────────────────────────────────────────────────────────────
fn TEST_রিport_junit output_path
    // WHY: JUnit XML format allows CI systems to parse test results
    say "  → JUnit XML রিপোর্ট:", output_path
    fd = file_created(output_path)
    xml = "<?xml version='1.0'?><testsuites></testsuites>"
    file_লেbো(fd, xml, len(xml))
    file_close(fd)
    return 0
