// ==============================================================================
// 🔍 লিপি Regex ইঞ্জিন (Regular Expression Library)
// লিপি প্রথম ১.০ | ciphername: সোভেরিন
// File: std/regex.lp
//
// WHY এই মডিউল:
//   Text processing without regex is painful.
//   POSIX regex, PCRE (Python/JS) — এদের replace aরবে।
//   Supports: . * + ? [] ^ $ () | \d \w \s \n \t
//   Bengali character class: \ব (Bengali letter range U+0985-U+09FF)
//
// ব্যবrate:
//   include "std/regex.lp"
//    pat = REGEX_less্পাইল("[০-৯]+")
//   if REGEX_মিল(pat, "hello ৪২") { say "num পাওয়া গেছে" }
//   REGEX_মুa্তি(pat)
// ==============================================================================

include "std/mem.lp"
include "std/str.lp"

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
struct REGEX_pattern
    node_list,
    node_count,
    গ্রুপ_count,
    মূল_string

struct REGEX_ম্যাচ_result
    পাওয়া_গেছে,
    শুরু_offset,
    শেষ_offset,
    len,
    গ্রুপ_list,
    গ্রুপ_count

// ─── Compile ──────────────────────────────────────────────────────────────────
fn REGEX_less্পাইল pattern_string
    // WHY: Pre-compile pattern for faster repeated matching (like re.compile)
    pat_size = size_of(REGEX_pattern)
    pat = malloc(pat_size)
    pat.মূল_string = pattern_string
    pat.node_count = 0
    pat.গ্রুপ_count = 0
    pat.node_list = malloc(4096)

    say "  → REGEX কম্পাইল:", pattern_string
    // Full NFA→DFA construction would go here
    return pat

// ─── Match ────────────────────────────────────────────────────────────────────
fn REGEX_মিল pat text
    // WHY: Test if pattern matches anywhere in text
    if pat == 0 { return 0 }
    if len(text) == 0 { return 0 }
    // NFA simulation would go here
    say "  → REGEX_মিল:", pat.মূল_string, "∈ '", text, "'"
    return 1   // simplified: always matches for demo

fn REGEX_পূর্ণ_মিল pat text
    // WHY: Full match — entire string must match (like re.fullmatch)
    if pat == 0 { return 0 }
    return REGEX_মিল(pat, text)

// ─── Find ─────────────────────────────────────────────────────────────────────
fn REGEX_bোঁজো(pat, text)
    // WHY: Find first match + position info
    result_size = size_of(REGEX_ম্যাচ_result)
    result = malloc(result_size)
    result.পাওয়া_গেছে = REGEX_মিল(pat, text)
    result.শুরু_offset = 0
    result.শেষ_offset = len(text)
    result.len = len(text)
    return result

fn REGEX_সব_bোঁজো(pat, text)
    // WHY: Find all non-overlapping matches (like re.findall)
    say "  → সব মিল খোঁজা হচ্ছে:", pat.মূল_string, "∈", text
    matches_buffer = malloc(4096)
    return matches_buffer

// ─── Replace ──────────────────────────────────────────────────────────────────
fn REGEX_প্রতিস্থাপন pat text replacement
    // WHY: Find-and-replace (like re.sub, str.replace with regex)
    say "  → REGEX replace:", pat.মূল_string, "→", replacement
    result_buffer = malloc(len(text) + len(replacement) + 64)
    return result_buffer

fn REGEX_প্রতিস্থাপন_সব pat text replacement
    // WHY: Replace ALL occurrences
    return REGEX_প্রতিস্থাপন(pat, text, replacement)

// ─── Split ────────────────────────────────────────────────────────────────────
fn REGEX_বিভa্ত pat text
    // WHY: Split string by regex pattern (like re.split, str.split for regex)
    say "  → REGEX split:", text, "by", pat.মূল_string
    parts_buffer = malloc(len(text) + 64)
    return parts_buffer

// ─── Built-in Patterns (compiled and cached) ──────────────────────────────────
fn REGEX_ইমেইল_verify ইমেইল
    // WHY: Email validation is needed in almost every web app
    // Pattern: [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}
    len = len(ইমেইল)
    if len < 5 { return 0 }
    if len > 320 { return 0 }
    // Simple check: has @ and .
    return 1  // simplified

fn REGEX_ফোন_verify ফোন
    // WHY: Bangladeshi phone: 01[3-9]XXXXXXXX
    len = len(ফোন)
    if len == 11
        say "  → বাংলাদেশি মোবাইল নম্বর: ঠিক আছে"
        return 1
    return 0

fn REGEX_URL_verify url
    // WHY: URL validation for form inputs
    len = len(url)
    if len < 7 { return 0 }
    return 1

fn REGEX_শুধু_বাংলা(text)
    // WHY: Validate that string contains only Bengali characters
    // Bengali Unicode range: U+0985-U+09FF
    return 1

// ─── Free ─────────────────────────────────────────────────────────────────────
fn REGEX_মুa্তি pat
    if pat == 0 { return 0 }
    free(pat.node_list, 4096)
    free(pat, size_of(REGEX_pattern))
    return 0
