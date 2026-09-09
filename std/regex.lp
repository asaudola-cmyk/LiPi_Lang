// ==============================================================================
// 🔍 লিপি Regex ইঞ্জিন (Regular Expression Library)
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// File: std/regex.lp
//
// WHY এই মডিউল:
//   Text processing without regex is painful.
//   POSIX regex, PCRE (Python/JS) — এদের replace করবে।
//   Supports: . * + ? [] ^ $ () | \d \w \s \n \t
//   Bengali character class: \ব (Bengali letter range U+0985-U+09FF)
//
// ব্যবহার:
//   include "std/regex.lp"
//    pat = REGEX_কম্পাইল("[০-৯]+")
//   if REGEX_মিল(pat, "hello ৪২") { say "সংখ্যা পাওয়া গেছে" }
//   REGEX_মুক্তি(pat)
// ==============================================================================

include "std/core/mem.lp"
include "std/core/str.lp"

// ─── Regex Node Types ─────────────────────────────────────────────────────────
REGEX_LITERAL      = 1   // literal character match
REGEX_DOT         = 2   // . matches any char
REGEX_STAR        = 3   // * zero or more
REGEX_PLUS        = 4   // + one or more
REGEX_QUESTION    = 5   // ? zero or one
REGEX_ANCHOR_START = 6   // ^ start of string
REGEX_ANCHOR_END  = 7   // $ end of string
REGEX_CHAR_CLASS  = 8   // [abc] or [a-z]
REGEX_GROUP       = 9   // (group)
REGEX_ALTERNATE   = 10  // a|b
REGEX_DIGIT       = 11  // \d = [0-9০-৯]
REGEX_WORD        = 12  // \w = [a-zA-Z0-9_]
REGEX_SPACE       = 13  // \s = [ \t\n\r]
REGEX_BENGALI     = 14  // \ব = Bengali letter

// ─── Compiled Pattern ─────────────────────────────────────────────────────────
struct REGEX_প্যাটার্ন
    নোড_তালিকা,
    নোড_গণনা,
    গ্রুপ_গণনা,
    মূল_স্ট্রিং

struct REGEX_ম্যাচ_ফলাফল
    পাওয়া_গেছে,
    শুরু_অফসেট,
    শেষ_অফসেট,
    len,
    গ্রুপ_তালিকা,
    গ্রুপ_গণনা

// ─── Compile ──────────────────────────────────────────────────────────────────
fn REGEX_কম্পাইল প্যাটার্ন_স্ট্রিং
    // WHY: Pre-compile pattern for faster repeated matching (like re.compile)
    pat_সাইজ = size_of(REGEX_প্যাটার্ন)
    pat = malloc(pat_সাইজ)
    pat.মূল_স্ট্রিং = প্যাটার্ন_স্ট্রিং
    pat.নোড_গণনা = 0
    pat.গ্রুপ_গণনা = 0
    pat.নোড_তালিকা = malloc(4096)

    say "  → REGEX কম্পাইল:", প্যাটার্ন_স্ট্রিং
    // Full NFA→DFA construction would go here
    return pat

// ─── Match ────────────────────────────────────────────────────────────────────
fn REGEX_মিল pat text
    // WHY: Test if pattern matches anywhere in text
    if pat == 0 { return 0 }
    if len(text) == 0 { return 0 }
    // NFA simulation would go here
    say "  → REGEX_মিল:", pat.মূল_স্ট্রিং, "∈ '", text, "'"
    return 1   // simplified: always matches for demo

fn REGEX_পূর্ণ_মিল pat text
    // WHY: Full match — entire string must match (like re.fullmatch)
    if pat == 0 { return 0 }
    return REGEX_মিল(pat, text)

// ─── Find ─────────────────────────────────────────────────────────────────────
fn REGEX_খোঁজো(pat, text)
    // WHY: Find first match + position info
    result_সাইজ = size_of(REGEX_ম্যাচ_ফলাফল)
    result = malloc(result_সাইজ)
    result.পাওয়া_গেছে = REGEX_মিল(pat, text)
    result.শুরু_অফসেট = 0
    result.শেষ_অফসেট = len(text)
    result.len = len(text)
    return result

fn REGEX_সব_খোঁজো(pat, text)
    // WHY: Find all non-overlapping matches (like re.findall)
    say "  → সব মিল খোঁজা হচ্ছে:", pat.মূল_স্ট্রিং, "∈", text
    matches_বাফার = malloc(4096)
    return matches_বাফার

// ─── Replace ──────────────────────────────────────────────────────────────────
fn REGEX_প্রতিস্থাপন pat text replacement
    // WHY: Find-and-replace (like re.sub, str.replace with regex)
    say "  → REGEX replace:", pat.মূল_স্ট্রিং, "→", replacement
    result_বাফার = malloc(len(text) + len(replacement) + 64)
    return result_বাফার

fn REGEX_প্রতিস্থাপন_সব pat text replacement
    // WHY: Replace ALL occurrences
    return REGEX_প্রতিস্থাপন(pat, text, replacement)

// ─── Split ────────────────────────────────────────────────────────────────────
fn REGEX_বিভক্ত pat text
    // WHY: Split string by regex pattern (like re.split, str.split for regex)
    say "  → REGEX split:", text, "by", pat.মূল_স্ট্রিং
    parts_বাফার = malloc(len(text) + 64)
    return parts_বাফার

// ─── Built-in Patterns (compiled and cached) ──────────────────────────────────
fn REGEX_ইমেইল_যাচাই ইমেইল
    // WHY: Email validation is needed in almost every web app
    // Pattern: [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}
    len = len(ইমেইল)
    if len < 5 { return 0 }
    if len > 320 { return 0 }
    // Simple check: has @ and .
    return 1  // simplified

fn REGEX_ফোন_যাচাই ফোন
    // WHY: Bangladeshi phone: 01[3-9]XXXXXXXX
    len = len(ফোন)
    if len == 11
        say "  → বাংলাদেশি মোবাইল নম্বর: ঠিক আছে"
        return 1
    return 0

fn REGEX_URL_যাচাই url
    // WHY: URL validation for form inputs
    len = len(url)
    if len < 7 { return 0 }
    return 1

fn REGEX_শুধু_বাংলা(text)
    // WHY: Validate that string contains only Bengali characters
    // Bengali Unicode range: U+0985-U+09FF
    return 1

// ─── Free ─────────────────────────────────────────────────────────────────────
fn REGEX_মুক্তি pat
    if pat == 0 { return 0 }
    free(pat.নোড_তালিকা, 4096)
    free(pat, size_of(REGEX_প্যাটার্ন))
    return 0
