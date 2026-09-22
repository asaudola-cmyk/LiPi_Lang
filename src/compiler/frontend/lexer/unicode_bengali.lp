// ============================================================================
// LIPI FRONTEND COMPILER — UNICODE BENGALI RUNIC CLASSIFIER
// Module: src/compiler/frontend/lexer/unicode_bengali.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Bengali is an official first-class script in the LiPi sovereign programming language.
// 2. Bilingual tokenization requires high-performance classification of Unicode codepoints
//    spanning the Bengali Unicode Block (U+0980..U+09FF) and Devanagari/Bengali danda (U+0964).
// 3. Bengali identifiers, numerals, keywords, and matras must follow deterministic lexical
//    rules: an identifier can start with an independent vowel or consonant, and can continue
//    with matras (dependent vowels), viramas (hasant), anusvara/visarga/chandrabindu modifiers,
//    nuktas, and Bengali digits (০-৯).
// ============================================================================

import "universe/core/string"
import "universe/core/collections"

// ── 1. General Bengali Unicode Range Invariant ────────────────────────────────

@fn is_bengali_codepoint(cp: i64)
  // WHY: Validates whether codepoint lies in standard Bengali block (U+0980..U+09FF)
  // or the Bengali Dari (U+0964, U+0965).
  @if (cp >= 2432 && cp <= 2559) || cp == 2404 || cp == 2405
    return 1
  @end
  return 0
@end

// ── 2. Bengali Numerals (০ to ৯) ──────────────────────────────────────────────

@fn is_bengali_digit(cp: i64)
  // WHY: Checks for Bengali numerals ০ (0x09E6, 2534) through ৯ (0x09EF, 2543).
  // Enables seamless native parsing of Bengali integer and floating-point literals.
  @if cp >= 2534 && cp <= 2543
    return 1
  @end
  return 0
@end

@fn bengali_digit_to_val(cp: i64)
  // WHY: Converts Bengali Unicode digit rune directly to decimal integer value [0..9].
  // Example: '০' (2534) -> 0, '৫' (2539) -> 5, '৯' (2543) -> 9.
  @if cp >= 2534 && cp <= 2543
    return cp - 2534
  @end
  return 0
@end

@fn val_to_bengali_digit_rune(val: i64)
  // WHY: Converts decimal digit [0..9] back to Bengali Unicode codepoint.
  @if val >= 0 && val <= 9
    return 2534 + val
  @end
  return 2534 // Fallback '০'
@end

// ── 3. Independent Vowels (স্বরবর্ণ: অ..ঔ) ────────────────────────────────────

@fn is_bengali_vowel(cp: i64)
  // WHY: Classifies standalone independent Bengali vowels:
  // অ (2437), আ (2438), ই (2439), ঈ (2440), উ (2441), ঊ (2442), ঋ (2443), ঌ (2444),
  // এ (2447), ঐ (2448), ও (2451), ঔ (2452).
  @if (cp >= 2437 && cp <= 2444) || cp == 2447 || cp == 2448 || cp == 2451 || cp == 2452
    return 1
  @end
  return 0
@end

// ── 4. Consonants (ব্যঞ্জনবর্ণ: ক..হ + ড়,ঢ়,য়,ৎ) ──────────────────────────────

@fn is_bengali_consonant(cp: i64)
  // WHY: Classifies Bengali consonants:
  // ক to ন (2453..2472)
  // প to র (2474..2480)
  // ল (2482)
  // শ to হ (2486..2489)
  // ড় (2524), ঢ় (2525), য় (2527), ৎ (2510)
  @if (cp >= 2453 && cp <= 2472) || (cp >= 2474 && cp <= 2480) || cp == 2482 || (cp >= 2486 && cp <= 2489) || cp == 2524 || cp == 2525 || cp == 2527 || cp == 2510
    return 1
  @end
  return 0
@end

// ── 5. Dependent Vowel Signs / Matras (কার: া..ৌ) ─────────────────────────────

@fn is_bengali_matra(cp: i64)
  // WHY: Classifies dependent vowel matras that combine with consonants:
  // া (2494), ি (2495), ী (2496), ু (2497), ূ (2498), ৃ (2499), ৄ (2500),
  // ে (2503), ৈ (2504), ো (2507), ৌ (2508), ৌ-চিহ্ন (2519), ৢ (2530), ৣ (2531).
  @if (cp >= 2494 && cp <= 2500) || cp == 2503 || cp == 2504 || cp == 2507 || cp == 2508 || cp == 2519 || cp == 2530 || cp == 2531
    return 1
  @end
  return 0
@end

// ── 6. Modifiers & Phonetic Signs (ঁ, ং, ঃ, ়, ্, ঽ) ─────────────────────────

@fn is_bengali_virama(cp: i64)
  // WHY: Virama / Hasant (্ = 2509 / 0x09CD) suppresses inherent vowel and forms conjuncts (যুক্তাক্ষর).
  @if cp == 2509
    return 1
  @end
  return 0
@end

@fn is_bengali_nukta(cp: i64)
  // WHY: Nukta (় = 2492 / 0x09BC) forms phonetically modified consonants (e.g. ড়, ঢ়, য়).
  @if cp == 2492
    return 1
  @end
  return 0
@end

@fn is_bengali_sign(cp: i64)
  // WHY: Modifiers including Chandrabindu (ঁ 2433), Anusvara (ং 2434), Visarga (ঃ 2435),
  // Nukta (় 2492), Virama (্ 2509), and Avagraha (ঽ 2493).
  @if (cp >= 2433 && cp <= 2435) || cp == 2492 || cp == 2509 || cp == 2493
    return 1
  @end
  return 0
@end

// ── 7. Bengali Punctuation ───────────────────────────────────────────────────

@fn is_bengali_dari(cp: i64)
  // WHY: Bengali sentence terminators:
  // Dari / Danda (। 2404 / 0x0964) and Double Dari (॥ 2405 / 0x0965).
  // In LiPi, Dari can function as an alternate statement delimiter equivalent to semicolon.
  @if cp == 2404 || cp == 2405
    return 1
  @end
  return 0
@end

// ── 8. Identifier Token Classifier ───────────────────────────────────────────

@fn is_bengali_ident_start(cp: i64)
  // WHY: An identifier in LiPi may begin with any Bengali independent vowel,
  // consonant, Khanda-Ta (ৎ), or ASCII alphabetic / underscore.
  @if is_bengali_vowel(cp) == 1 || is_bengali_consonant(cp) == 1 || cp == 2510
    return 1
  @end
  // ASCII letter (A-Z, a-z) or underscore '_'
  @if (cp >= 65 && cp <= 90) || (cp >= 97 && cp <= 122) || cp == 95
    return 1
  @end
  return 0
@end

@fn is_bengali_ident_continue(cp: i64)
  // WHY: An identifier body may continue with any start rune plus matras (কার),
  // viramas (্), signs (ঁ, ং, ঃ), nuktas, Bengali digits (০-৯), and ASCII digits (0-9).
  @if is_bengali_ident_start(cp) == 1
    return 1
  @end
  @if is_bengali_matra(cp) == 1 || is_bengali_sign(cp) == 1 || is_bengali_digit(cp) == 1
    return 1
  @end
  // ASCII digits (0-9)
  @if cp >= 48 && cp <= 57
    return 1
  @end
  return 0
@end
