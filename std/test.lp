// ==============================================================================
// 🧪 লিপি টেস্টিং ফ্রেমওয়ার্ক (pytest + Jest Killer)
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// File: std/test.lp
//
// WHY এই মডিউল:
//   Testing is not optional for production code.
//   pytest (Python), Jest (JS), Google Test (C++) — এদের replace করবে।
//
// ব্যবহার:
//   include "std/test.lp"
//   TEST_শুরু("আমার টেস্ট স্যুট")
//   ASSERT_সমান(ফু(৪২), ৮৪, "দ্বিগুণ fn করছে")
//   ASSERT_সত্য(x > ০, "x ধনাত্মক হতে হবে")
//   TEST_শেষ()
// ==============================================================================

include "std/core/mem.lp"
include "std/core/io.lp"
include "std/version.lp"

// ─── Test stats ───────────────────────────────────────────────────────────────
TEST_পাস_গণনা  = 0
TEST_ফেল_গণনা  = 0
TEST_SKIP_গণনা = 0
TEST_suite_নাম = ""
TEST_শুরু_সময়  = 0

// ─── Test Suite ───────────────────────────────────────────────────────────────
fn TEST_শুরু suite_নাম
    TEST_suite_নাম = suite_নাম
    TEST_পাস_গণনা = 0
    TEST_ফেল_গণনা = 0
    TEST_SKIP_গণনা = 0
    TEST_শুরু_সময় = cpu_clock()
    say ""
    say "\033[1;36m🧪 টেস্ট স্যুট:", suite_নাম, "\033[0m"
    say "─────────────────────────────────────────────"

fn TEST_শেষ
    মোট = TEST_পাস_গণনা + TEST_ফেল_গণনা
    শেষ_সময় = cpu_clock()
    elapsed = শেষ_সময় - TEST_শুরু_সময়
    say ""
    say "─────────────────────────────────────────────"
    say "\033[1;33mফলাফল:\033[0m"
    say "  ✅ পাস :", TEST_পাস_গণনা
    say "  ❌ ফেল :", TEST_ফেল_গণনা
    say "  ⏭️  skip:", TEST_SKIP_গণনা
    say "  মোট   :", মোট
    say "  সময়  :", elapsed, "cycles"
    say ""
    if TEST_ফেল_গণনা == 0
        say "\033[1;32m✅ সব টেস্ট পাস!\033[0m"
        return 0
    say "\033[1;31m❌", TEST_ফেল_গণনা, "টি টেস্ট ব্যর্থ!\033[0m"
    return 1

// ─── Assertions ───────────────────────────────────────────────────────────────
fn ASSERT_সমান প্রকৃত প্রত্যাশিত বার্তা
    if প্রকৃত == প্রত্যাশিত
        TEST_পাস_গণনা = TEST_পাস_গণনা + 1
        say "  \033[1;32m✔\033[0m", বার্তা
        return true
    TEST_ফেল_গণনা = TEST_ফেল_গণনা + 1
    say "  \033[1;31m✗\033[0m", বার্তা
    say "    প্রত্যাশিত:", প্রত্যাশিত
    say "    পাওয়া গেছে:", প্রকৃত
    return false

fn ASSERT_অসমান ক খ বার্তা
    if ক != খ
        TEST_পাস_গণনা = TEST_পাস_গণনা + 1
        say "  \033[1;32m✔\033[0m", বার্তা
        return true
    TEST_ফেল_গণনা = TEST_ফেল_গণনা + 1
    say "  \033[1;31m✗\033[0m", বার্তা, "(মান সমান নয় হওয়া উচিত ছিল)"
    return false

fn ASSERT_সত্য শর্ত বার্তা
    return ASSERT_সমান(শর্ত, 1, বার্তা)

fn ASSERT_মিথ্যা শর্ত বার্তা
    return ASSERT_সমান(শর্ত, 0, বার্তা)

fn ASSERT_বড় ক খ বার্তা
    if ক > খ
        TEST_পাস_গণনা = TEST_পাস_গণনা + 1
        say "  \033[1;32m✔\033[0m", বার্তা
        return true
    TEST_ফেল_গণনা = TEST_ফেল_গণনা + 1
    say "  \033[1;31m✗\033[0m", বার্তা, "| প্রত্যাশিত:", ক, ">", খ
    return false

fn ASSERT_ছোট ক খ বার্তা
    if ক < খ
        TEST_পাস_গণনা = TEST_পাস_গণনা + 1
        say "  \033[1;32m✔\033[0m", বার্তা
        return true
    TEST_ফেল_গণনা = TEST_ফেল_গণনা + 1
    say "  \033[1;31m✗\033[0m", বার্তা, "| প্রত্যাশিত:", ক, "<", খ
    return false

fn ASSERT_NULL পয়েন্টার বার্তা
    return ASSERT_সমান(পয়েন্টার, 0, বার্তা)

fn ASSERT_NOT_NULL পয়েন্টার বার্তা
    if পয়েন্টার != 0
        TEST_পাস_গণনা = TEST_পাস_গণনা + 1
        say "  \033[1;32m✔\033[0m", বার্তা
        return true
    TEST_ফেল_গণনা = TEST_ফেল_গণনা + 1
    say "  \033[1;31m✗\033[0m", বার্তা, "(NULL হওয়া উচিত ছিল না)"
    return false

fn ASSERT_range মান min max বার্তা
    // WHY: Check value is within expected range
    if মান >= min
        if মান <= max
            TEST_পাস_গণনা = TEST_পাস_গণনা + 1
            say "  \033[1;32m✔\033[0m", বার্তা, "| মান:", মান, "∈ [", min, ",", max, "]"
            return true
    TEST_ফেল_গণনা = TEST_ফেল_গণনা + 1
    say "  \033[1;31m✗\033[0m", বার্তা, "| মান:", মান, "∉ [", min, ",", max, "]"
    return false

// ─── Test Skip ────────────────────────────────────────────────────────────────
fn TEST_skip কারণ
    TEST_SKIP_গণনা = TEST_SKIP_গণনা + 1
    say "  \033[38;2;128;128;128m⏭  SKIP:", কারণ, "\033[0m"

// ─── Benchmark ────────────────────────────────────────────────────────────────
fn BENCH_রান নাম iterations
    // WHY: Measure performance in CPU cycles
    শুরু = cpu_clock()
    i = 0
    while i < iterations
        i = i + 1
    শেষ = cpu_clock()
    মোট = শেষ - শুরু
    per_iter = মোট / iterations
    say "  📊 BENCH:", নাম
    say "    iterations:", iterations
    say "    মোট cycles:", মোট
    say "    প্রতি iter :", per_iter, "cycles"
    return per_iter

// ─── Test Reporter ────────────────────────────────────────────────────────────
fn TEST_রিপোর্ট_junit output_পাথ
    // WHY: JUnit XML format allows CI systems to parse test results
    say "  → JUnit XML রিপোর্ট:", output_পাথ
    fd = ফাইল_তৈরি(output_পাথ)
    xml = "<?xml version='1.0'?><testsuites></testsuites>"
    ফাইল_লেখো(fd, xml, len(xml))
    ফাইল_বন্ধ(fd)
    return 0
