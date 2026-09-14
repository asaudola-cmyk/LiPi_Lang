// ==============================================================================
// 👑 LIPI SOVEREIGN REGRESSION TEST: UNICODE & BENGALI RUNE ENGINE
// ⚡ Tests Byte-Accurate UTF-8 Decoding, Grapheme Slicing & Dual Numerals
// 🏛️ Version: First 1.0.0 (প্রথম ১.০.০) — 100% Pure Lipi / Zero External Libs
// ==============================================================================

include "universe/core/unicode.lp"
include "universe/core/string.lp"

say "=== LIPI UNICODE & BENGALI RUNE TEST ==="

// 1. Lead Byte Classification (RFC 3629)
ascii_len = utf8_byte_len(65)    // 'A' -> 1 byte
bengali_len = utf8_byte_len(224) // 0xE0 -> 3 bytes
emoji_len = utf8_byte_len(240)   // 0xF0 -> 4 bytes

if ascii_len != 1 or bengali_len != 3 or emoji_len != 4
    say "FAIL: UTF-8 lead byte length classification error"
    exit(1)
say "✔ UTF-8 lead byte length detection verified (1B ASCII, 3B Bengali, 4B Emoji)"

// 2. True Rune Length vs Raw Byte Length
word_bn = "বাংলা"
raw_bytes = len(word_bn)
true_runes = utf8_rune_len(word_bn)

say "  Word: '" + word_bn + "' -> Raw Bytes: " + str(raw_bytes) + " | Runes: " + str(true_runes)
if raw_bytes != 15 or true_runes != 5
    say "FAIL: Bengali rune count mismatch. Expected 5 runes, 15 bytes."
    exit(1)
say "✔ Bengali rune count matches perfectly (5 runes across 15 UTF-8 bytes)"

// 3. Bilingual Alias Verification (রুন_গণনা)
if রুন_গণনা(word_bn) != 5
    say "FAIL: Bengali bilingual alias রুন_গণনা failed"
    exit(1)
say "✔ Bengali bilingual alias রুন_গণনা verified"

// 4. Safe Rune Slicing Without Byte Splitting
// "বাংলা" runes: [0: ব, 1: া, 2: ং, 3: ল, 4: া]
// Slicing first 2 runes -> "বা" (6 bytes)
slice_ba = utf8_rune_slice(word_bn, 0, 2)
if slice_ba != "বা" or len(slice_ba) != 6
    say "FAIL: utf8_rune_slice expected 'বা' (6 bytes), got: '" + slice_ba + "' (" + str(len(slice_ba)) + " bytes)"
    exit(1)
say "✔ Safe Rune Slice: '" + word_bn + "'[0..2] = '" + slice_ba + "' (Valid 6-byte UTF-8 sequence)"

// Slicing last 2 runes -> "লা" (6 bytes)
slice_la = utf8_rune_slice(word_bn, 3, 2)
if slice_la != "লা"
    say "FAIL: utf8_rune_slice expected 'লা', got: '" + slice_la + "'"
    exit(1)
say "✔ Safe Rune Slice: '" + word_bn + "'[3..5] = '" + slice_la + "'"

// 5. Bengali Block Codepoint Verification
// Bengali block is U+0980 (2432) to U+09FF (2559)
cp_ba = utf8_codepoint_at(word_bn, 0) // 'ব' = U+09AC = 2476
if cp_ba != 2476 or is_bengali_rune(cp_ba) != 1
    say "FAIL: Codepoint for 'ব' incorrect: " + str(cp_ba)
    exit(1)
say "✔ Unicode codepoint scalar decoded: 'ব' = U+" + str(cp_ba) + " (Valid Bengali Script Block)"

// 6. Dual-Numeral Bengali Digits
d_bn = "৭"
d_int = bengali_digit_to_int(d_bn)
if d_int != 7
    say "FAIL: bengali_digit_to_int('৭') expected 7, got: " + str(d_int)
    exit(1)
say "✔ Bengali numeral conversion: '৭' -> " + str(d_int)

if int_to_bengali_digit(5) != "৫"
    say "FAIL: int_to_bengali_digit(5) expected '৫'"
    exit(1)
say "✔ ASCII to Bengali numeral conversion: 5 -> '৫'"

say "PASS: test_unicode_bengali_runes"
