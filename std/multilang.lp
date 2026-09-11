// ==============================================================================
// 🌍 লিপি মাল্টিলিঙ্গুয়াল কিওয়ার্ড প্যাক
// লিপি প্রথম ১.০ | ciphername: সোভেরিন
// File: std/multilang.lp
//
// WHY এই মডিউল:
//   Plan Phase 5.3 — "মাল্টিলিঙ্গুয়াল ওয়ার্ল্ড ডমিনেশন"
//   8 billion people should code in their mother tongue.
//   This module defines keyword aliases for future multilingual support.
//
// সমর্থিত ভাষাসমূহ (ভবিষ্যৎ):
//   বাংলা (Bengali)     ✅ Native — প্রথম ১.০
//   हिंदी (Hindi)       🔜 v2.0
//   العربية (Arabic)    🔜 v2.1
//   中文 (Chinese)      🔜 v2.2
//   Español (Spanish)   🔜 v2.3
//   Français (French)   🔜 v2.4
//   Русский (Russian)   🔜 v2.6
//   日本語 (Japanese)   🔜 v2.7
//   한국어 (Korean)     🔜 v2.8
// ==============================================================================

include "std/version.lp"

// ─── Keyword Translation Table ────────────────────────────────────────────────
// লিপির মূল বাংলা কিওয়ার্ড → অন্যান্য ভাষা

// WHY: Even English programmers can use লিপি via English keywords
// English aliases (already supported in compiler)
// if          → if
// else        → else
// while       → while
// for         → প্রতিটি/ভেতরে
// return      → return
// function    → fn
// struct      → struct
// include     → include
// show/print  → say

// ─── Keyword info functions ───────────────────────────────────────────────────
fn LANG_num ভাষা_code
    // WHY: Return count of languages supported in this build
    if ভাষা_code == 1
        return 1  // Bengali only in v1.0
    return 1

fn LANG_list_দেখাও
    say "লিপি সমর্থিত ভাষাসমূহ:"
    say ""
    say "  প্রকাশিত:"
    say "  ✅  বাংলা (Bengali)   — লিপি প্রথম ১.০"
    say ""
    say "  পরিকল্পিত:"
    say "  🔜  हिंदी (Hindi)      — লিপি ২.০"
    say "  🔜  العربية (Arabic)   — লিপি ২.১"
    say "  🔜  中文 (Chinese)     — লিপি ২.২"
    say "  🔜  Español (Spanish)  — লিপি ২.৩"
    say "  🔜  Français (French)  — লিপি ২.৪"
    say "  🔜  Português          — লিপি ২.৫"
    say "  🔜  Русский (Russian)  — লিপি ২.৬"
    say "  🔜  日本語 (Japanese)  — লিপি ২.৭"
    say "  🔜  한국어 (Korean)    — লিপি ২.৮"
    say "  🔜  Kiswahili (Africa) — লিপি ৩.০"
    say ""
    say "লক্ষ্য: ৮ বিলিয়ন মানুষ নিজের ভাষায় কোড লিখতে পারবে।"
    say "সংস্করণ: 1.0.0"
    return 0

// ─── Bengali Locale ───────────────────────────────────────────────────────────
fn বাংলা_তারিখ বছর month দিন
    // WHY: Native Bengali date formatting (বাংলাদেশ/ভারত standard)
    month_name = "???"
    if month == 1
        month_name = "জানুয়ারি"
    if month == 2
        month_name = "ফেব্রুয়ারি"
    if month == 3
        month_name = "মার্চ"
    if month == 4
        month_name = "এপ্রিল"
    if month == 5
        month_name = "মে"
    if month == 6
        month_name = "জুন"
    if month == 7
        month_name = "জুলাই"
    if month == 8
        month_name = "আগস্ট"
    if month == 9
        month_name = "সেপ্টেম্বর"
    if month == 10
        month_name = "অক্টোবর"
    if month == 11
        month_name = "নভেম্বর"
    if month == 12
        month_name = "ডিসেম্বর"

    say দিন + " " + month_name + " " + বছর
    return 0

fn বাংলা_সময় ঘন্টা minute
    time_name = "রাত"
    if ঘন্টা >= 6
        time_name = "সকাল"
    if ঘন্টা >= 12
        time_name = "দুপুর"
    if ঘন্টা >= 16
        time_name = "বিকেল"
    if ঘন্টা >= 19
        time_name = "সন্ধ্যা"
    if ঘন্টা >= 21
        time_name = "রাত"

    say time_name + " " + ঘন্টা + " টা " + minute + " মিনিট"
    return 0

fn বাংলা_বার day_of_week
    if day_of_week == 0
        say "রবিবার"
    if day_of_week == 1
        say "সোমবার"
    if day_of_week == 2
        say "মঙ্গলবার"
    if day_of_week == 3
        say "বুধবার"
    if day_of_week == 4
        say "বৃহস্পতিবার"
    if day_of_week == 5
        say "শুক্রবার"
    if day_of_week == 6
        say "শনিবার"
    return 0
