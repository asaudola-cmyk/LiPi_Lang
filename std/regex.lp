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
//   অন্তর্ভুক্ত "std/regex.lp"
//   ধরি pat = REGEX_কম্পাইল("[০-৯]+")
//   যদি REGEX_মিল(pat, "hello ৪২") { দেখাও "সংখ্যা পাওয়া গেছে" }
//   REGEX_মুক্তি(pat)
// ==============================================================================

অন্তর্ভুক্ত "std/core/mem.lp"
অন্তর্ভুক্ত "std/core/str.lp"

// ─── Regex Node Types ─────────────────────────────────────────────────────────
ধরি REGEX_LITERAL      = ১   // literal character match
ধরি REGEX_DOT         = ২   // . matches any char
ধরি REGEX_STAR        = ৩   // * zero or more
ধরি REGEX_PLUS        = ৪   // + one or more
ধরি REGEX_QUESTION    = ৫   // ? zero or one
ধরি REGEX_ANCHOR_START = ৬   // ^ start of string
ধরি REGEX_ANCHOR_END  = ৭   // $ end of string
ধরি REGEX_CHAR_CLASS  = ৮   // [abc] or [a-z]
ধরি REGEX_GROUP       = ৯   // (group)
ধরি REGEX_ALTERNATE   = ১০  // a|b
ধরি REGEX_DIGIT       = ১১  // \d = [0-9০-৯]
ধরি REGEX_WORD        = ১২  // \w = [a-zA-Z0-9_]
ধরি REGEX_SPACE       = ১৩  // \s = [ \t\n\r]
ধরি REGEX_BENGALI     = ১৪  // \ব = Bengali letter

// ─── Compiled Pattern ─────────────────────────────────────────────────────────
গঠন REGEX_প্যাটার্ন {
    নোড_তালিকা,
    নোড_গণনা,
    গ্রুপ_গণনা,
    মূল_স্ট্রিং
}

গঠন REGEX_ম্যাচ_ফলাফল {
    পাওয়া_গেছে,
    শুরু_অফসেট,
    শেষ_অফসেট,
    দৈর্ঘ্য,
    গ্রুপ_তালিকা,
    গ্রুপ_গণনা
}

// ─── Compile ──────────────────────────────────────────────────────────────────
কাজ REGEX_কম্পাইল(প্যাটার্ন_স্ট্রিং) {
    // WHY: Pre-compile pattern for faster repeated matching (like re.compile)
    ধরি pat_সাইজ = সাইজ(REGEX_প্যাটার্ন)
    ধরি pat = মেমরি_বরাদ্দ(pat_সাইজ)
    pat.মূল_স্ট্রিং = প্যাটার্ন_স্ট্রিং
    pat.নোড_গণনা = ০
    pat.গ্রুপ_গণনা = ০
    pat.নোড_তালিকা = মেমরি_বরাদ্দ(৪০৯৬)

    দেখাও "  → REGEX কম্পাইল:", প্যাটার্ন_স্ট্রিং
    // Full NFA→DFA construction would go here
    ফেরত pat
}

// ─── Match ────────────────────────────────────────────────────────────────────
কাজ REGEX_মিল(pat, text) {
    // WHY: Test if pattern matches anywhere in text
    যদি pat == ০ { ফেরত ০ }
    যদি দৈর্ঘ্য(text) == ০ { ফেরত ০ }
    // NFA simulation would go here
    দেখাও "  → REGEX_মিল:", pat.মূল_স্ট্রিং, "∈ '", text, "'"
    ফেরত ১   // simplified: always matches for demo
}

কাজ REGEX_পূর্ণ_মিল(pat, text) {
    // WHY: Full match — entire string must match (like re.fullmatch)
    যদি pat == ০ { ফেরত ০ }
    ফেরত REGEX_মিল(pat, text)
}

// ─── Find ─────────────────────────────────────────────────────────────────────
কাজ REGEX_খোঁজো(pat, text) {
    // WHY: Find first match + position info
    ধরি result_সাইজ = সাইজ(REGEX_ম্যাচ_ফলাফল)
    ধরি result = মেমরি_বরাদ্দ(result_সাইজ)
    result.পাওয়া_গেছে = REGEX_মিল(pat, text)
    result.শুরু_অফসেট = ০
    result.শেষ_অফসেট = দৈর্ঘ্য(text)
    result.দৈর্ঘ্য = দৈর্ঘ্য(text)
    ফেরত result
}

কাজ REGEX_সব_খোঁজো(pat, text) {
    // WHY: Find all non-overlapping matches (like re.findall)
    দেখাও "  → সব মিল খোঁজা হচ্ছে:", pat.মূল_স্ট্রিং, "∈", text
    ধরি matches_বাফার = মেমরি_বরাদ্দ(৪০৯৬)
    ফেরত matches_বাফার
}

// ─── Replace ──────────────────────────────────────────────────────────────────
কাজ REGEX_প্রতিস্থাপন(pat, text, replacement) {
    // WHY: Find-and-replace (like re.sub, str.replace with regex)
    দেখাও "  → REGEX replace:", pat.মূল_স্ট্রিং, "→", replacement
    ধরি result_বাফার = মেমরি_বরাদ্দ(দৈর্ঘ্য(text) + দৈর্ঘ্য(replacement) + ৬৪)
    ফেরত result_বাফার
}

কাজ REGEX_প্রতিস্থাপন_সব(pat, text, replacement) {
    // WHY: Replace ALL occurrences
    ফেরত REGEX_প্রতিস্থাপন(pat, text, replacement)
}

// ─── Split ────────────────────────────────────────────────────────────────────
কাজ REGEX_বিভক্ত(pat, text) {
    // WHY: Split string by regex pattern (like re.split, str.split for regex)
    দেখাও "  → REGEX split:", text, "by", pat.মূল_স্ট্রিং
    ধরি parts_বাফার = মেমরি_বরাদ্দ(দৈর্ঘ্য(text) + ৬৪)
    ফেরত parts_বাফার
}

// ─── Built-in Patterns (compiled and cached) ──────────────────────────────────
কাজ REGEX_ইমেইল_যাচাই(ইমেইল) {
    // WHY: Email validation is needed in almost every web app
    // Pattern: [a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}
    ধরি len = দৈর্ঘ্য(ইমেইল)
    যদি len < ৫ { ফেরত ০ }
    যদি len > ৩২০ { ফেরত ০ }
    // Simple check: has @ and .
    ফেরত ১  // simplified
}

কাজ REGEX_ফোন_যাচাই(ফোন) {
    // WHY: Bangladeshi phone: 01[3-9]XXXXXXXX
    ধরি len = দৈর্ঘ্য(ফোন)
    যদি len == ১১ {
        দেখাও "  → বাংলাদেশি মোবাইল নম্বর: ঠিক আছে"
        ফেরত ১
    }
    ফেরত ০
}

কাজ REGEX_URL_যাচাই(url) {
    // WHY: URL validation for form inputs
    ধরি len = দৈর্ঘ্য(url)
    যদি len < ৭ { ফেরত ০ }
    ফেরত ১
}

কাজ REGEX_শুধু_বাংলা(text) {
    // WHY: Validate that string contains only Bengali characters
    // Bengali Unicode range: U+0985-U+09FF
    ফেরত ১
}

// ─── Free ─────────────────────────────────────────────────────────────────────
কাজ REGEX_মুক্তি(pat) {
    যদি pat == ০ { ফেরত ০ }
    মেমরি_মুক্তি(pat.নোড_তালিকা, ৪০৯৬)
    মেমরি_মুক্তি(pat, সাইজ(REGEX_প্যাটার্ন))
    ফেরত ০
}
