// ==============================================================================
// 🌍 লিপি মাল্টিলিঙ্গুয়াল কীওয়ার্ড প্যাক
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
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
// লিপির মূল বাংলা কীওয়ার্ড → অন্যান্য ভাষা

// WHY: Even English programmers can use লিপি via English keywords
// English aliases (already supported in compiler)
// if          → if
// else        → else
// while       → while
// for         → প্রতিটি/ভেতরে
// return      → return
// function    → fn
// let/var     → 
// struct      → struct
// include     → include
// show/print  → say

// ─── Hindi (হিন্দি) — v2.0 ──────────────────────────────────────────────────
// if    → यदि
// else  → अन्यथा
// while → जबतक
// return   → वापस
// fn    → काम
//     → धारण
// struct    → संरचना
// say  → दिखाओ

// ─── Arabic (আরবি) — v2.1 ───────────────────────────────────────────────────
// if    → إذا
// else  → وإلا
// while → طالما
// return   → أعد
// fn    → دالة
//     → دع
// say  → أظهر

// ─── Spanish (স্প্যানিশ) — v2.3 ─────────────────────────────────────────────
// if    → si
// else  → sino
// while → mientras
// return   → retornar
// fn    → función
//     → sea
// say  → mostrar

// ─── Keyword info functions ───────────────────────────────────────────────────
fn LANG_সংখ্যা(ভাষা_কোড)
    // WHY: Return count of languages supported in this build
    if ভাষা_কোড == 1 { return 1 }  // Bengali only in v1.0
    return 1

fn LANG_তালিকা_দেখাও
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
    say "সংস্করণ:", LIPI_সংস্করণ
    return 0

// ─── Bengali Locale ───────────────────────────────────────────────────────────
fn বাংলা_তারিখ(বছর, মাস, দিন)
    // WHY: Native Bengali date formatting (বাংলাদেশ/ভারত standard)
    মাসের_নাম = "???"
    if মাস == 1 { মাসের_নাম = "জানুয়ারি" }
    if মাস == 2 { মাসের_নাম = "ফেব্রুয়ারি" }
    if মাস == 3 { মাসের_নাম = "মার্চ" }
    if মাস == 4 { মাসের_নাম = "এপ্রিল" }
    if মাস == 5 { মাসের_নাম = "মে" }
    if মাস == 6 { মাসের_নাম = "জুন" }
    if মাস == 7 { মাসের_নাম = "জুলাই" }
    if মাস == 8 { মাসের_নাম = "আগস্ট" }
    if মাস == 9 { মাসের_নাম = "সেপ্টেম্বর" }
    if মাস == 10 { মাসের_নাম = "অক্টোবর" }
    if মাস == 11 { মাসের_নাম = "নভেম্বর" }
    if মাস == 12 { মাসের_নাম = "ডিসেম্বর" }

    say দিন, মাসের_নাম, বছর
    return 0

fn বাংলা_সময়(ঘন্টা, মিনিট)
    সময়_নাম = "রাত"
    if ঘন্টা >= 6 { সময়_নাম = "সকাল" }
    if ঘন্টা >= 12 { সময়_নাম = "দুপুর" }
    if ঘন্টা >= 16 { সময়_নাম = "বিকেল" }
    if ঘন্টা >= 19 { সময়_নাম = "সন্ধ্যা" }
    if ঘন্টা >= 21 { সময়_নাম = "রাত" }

    say সময়_নাম, ঘন্টা, "টা", মিনিট, "মিনিট"
    return 0

fn বাংলা_বার(day_of_week)
    if day_of_week == 0 { say "রবিবার" }
    if day_of_week == 1 { say "সোমবার" }
    if day_of_week == 2 { say "মঙ্গলবার" }
    if day_of_week == 3 { say "বুধবার" }
    if day_of_week == 4 { say "বৃহস্পতিবার" }
    if day_of_week == 5 { say "শুক্রবার" }
    if day_of_week == 6 { say "শনিবার" }
    return 0
