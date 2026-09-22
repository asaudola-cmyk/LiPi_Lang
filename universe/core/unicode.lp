// ==============================================================================
// 👑 LIPI UNIVERSE — Canonical Unicode & Bengali Rune Engine (universe/core/unicode.lp)
// ⚡ 100% Pure Lipi | Zero External Dependencies (0% C / 0% Libc / 0% ICU)
// 🏛️ Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign
//
// WHY THIS MODULE:
// 1. Raw byte-level string slicing (str_slice) splits multi-byte UTF-8 sequences,
//    corrupting Bengali letters (3-byte UTF-8, range U+0980 to U+09FF) and producing
//    corrupted terminal output and memory inconsistencies.
// 2. A sovereign language whose name is 'Lipi' (লিপি) must provide native, bit-accurate,
//    mathematical Unicode Rune extraction from First Principles without linking foreign libraries.
// ==============================================================================

// ── ১. লিড বাইটের দৈর্ঘ্য নির্ধারণ (UTF-8 Lead Byte Length Classifier) ────────
// WHY: Mathematically decodes the expected byte length (1 to 4 bytes) from the lead byte
// using standard RFC 3629 UTF-8 bit prefix masking without bitwise shift dependencies.
fn utf8_byte_len lead_byte
    b = floor(lead_byte) % 256
    if b < 0
        b = b + 256
    // 1-Byte ASCII: 0xxxxxxx (0 to 127)
    if b < 128
        return 1
    // Continuation byte: 10xxxxxx (128 to 191) - orphan byte fallback
    if b < 192
        return 1
    // 2-Byte Sequence: 110xxxxx (192 to 223)
    if b < 224
        return 2
    // 3-Byte Sequence: 1110xxxx (224 to 239) -> All Bengali script lives here!
    if b < 240
        return 3
    // 4-Byte Sequence: 11110xxx (240 to 247) -> Astral plane emojis and symbols
    if b < 248
        return 4
    return 1

// ── ২. নির্দিষ্ট পজিশনে কোডপয়েন্ট ডিকোডিং (Decode Scalar Value at Byte Offset) ─
// WHY: Reconstructs the 21-bit integer Unicode scalar value from 1..4 contiguous bytes.
fn utf8_decode_codepoint s byte_pos
    slen = len(s)
    if byte_pos >= slen or byte_pos < 0
        return 0
    b1 = ord(char_at(s, byte_pos))
    blen = utf8_byte_len(b1)
    if blen == 1
        return b1
    if blen == 2
        if byte_pos + 1 >= slen
            return b1
        b2 = ord(char_at(s, byte_pos + 1))
        return ((b1 % 32) * 64) + (b2 % 64)
    if blen == 3
        if byte_pos + 2 >= slen
            return b1
        b2 = ord(char_at(s, byte_pos + 1))
        b3 = ord(char_at(s, byte_pos + 2))
        return ((b1 % 16) * 4096) + ((b2 % 64) * 64) + (b3 % 64)
    if blen == 4
        if byte_pos + 3 >= slen
            return b1
        b2 = ord(char_at(s, byte_pos + 1))
        b3 = ord(char_at(s, byte_pos + 2))
        b4 = ord(char_at(s, byte_pos + 3))
        return ((b1 % 8) * 262144) + ((b2 % 64) * 4096) + ((b3 % 64) * 64) + (b4 % 64)
    return b1

// ── ৩. মোট রুন বা অক্ষরের সংখ্যা গণনা (Count True Unicode Runes) ───────────────
// WHY: Returns the true visible character count instead of raw byte count.
// For example: "বাংলা" has 15 raw bytes but exactly 5 Unicode runes.
fn utf8_rune_len s
    slen = len(s)
    if slen == 0
        return 0
    pos = 0
    count = 0
    while pos < slen
        b = ord(char_at(s, pos))
        step = utf8_byte_len(b)
        pos = pos + step
        count = count + 1
    return count

fn রুন_গণনা s
    return utf8_rune_len(s)

fn রুন_দৈর্ঘ্য s
    return utf8_rune_len(s)

// ── ৪. নির্দিষ্ট রুন ইনডেক্সের স্ট্রিং আহরণ (Extract Single Rune by Index) ─────
// WHY: Returns the full 1-4 byte UTF-8 string for the n-th rune without byte splitting.
fn utf8_rune_at s rune_idx
    slen = len(s)
    if slen == 0 or rune_idx < 0
        return ""
    pos = 0
    current_rune = 0
    while pos < slen
        b = ord(char_at(s, pos))
        step = utf8_byte_len(b)
        if current_rune == rune_idx
            res = ""
            k = 0
            while k < step and (pos + k) < slen
                res = res + char_at(s, pos + k)
                k = k + 1
            return res
        pos = pos + step
        current_rune = current_rune + 1
    return ""

fn রুন_অক্ষর s ইনডেক্স
    return utf8_rune_at(s, ইনডেক্স)

// ── ৫. নির্দিষ্ট রুন ইনডেক্সের পূর্ণসংখ্যা কোডপয়েন্ট (Codepoint Scalar by Index) ─
fn utf8_codepoint_at s rune_idx
    slen = len(s)
    if slen == 0 or rune_idx < 0
        return 0
    pos = 0
    current_rune = 0
    while pos < slen
        b = ord(char_at(s, pos))
        step = utf8_byte_len(b)
        if current_rune == rune_idx
            return utf8_decode_codepoint(s, pos)
        pos = pos + step
        current_rune = current_rune + 1
    return 0

fn রুন_কোড s ইনডেক্স
    return utf8_codepoint_at(s, ইনডেক্স)

// ── ৬. নিরাপদ রুন স্লাইসিং (Unicode-Safe Substring Slicing) ───────────────────
// WHY: Slices a substring between rune indices, guaranteeing that multi-byte Bengali
// characters are never cut in the middle.
fn utf8_rune_slice s start_rune count_runes
    slen = len(s)
    if slen == 0 or count_runes <= 0 or start_rune < 0
        return ""
    pos = 0
    current_rune = 0
    start_byte = -1
    end_byte = slen
    target_end = start_rune + count_runes
    while pos < slen
        if current_rune == start_rune
            start_byte = pos
        if current_rune == target_end
            end_byte = pos
            break
        b = ord(char_at(s, pos))
        step = utf8_byte_len(b)
        pos = pos + step
        current_rune = current_rune + 1
    if start_byte < 0
        return ""
    if current_rune < target_end
        end_byte = slen
    res = ""
    bi = start_byte
    while bi < end_byte
        res = res + char_at(s, bi)
        bi = bi + 1
    return res

fn রুন_স্লাইস s শুরু দৈর্ঘ্য
    return utf8_rune_slice(s, শুরু, দৈর্ঘ্য)

// ── ৭. বাংলা বর্ণমালা যাচাই (Bengali Unicode Block Validation U+0980..U+09FF) ──
// WHY: Validates whether a Unicode scalar point belongs to the canonical Bengali script block.
fn is_bengali_rune cp
    if cp >= 2432 and cp <= 2559
        return 1
    return 0

fn বাংলা_অক্ষর_কিনা কোড
    return is_bengali_rune(কোড)

// ── ৮. দ্বি-ভাষিক সংখ্যা রূপান্তর (Dual-Numeral Bengali <-> ASCII Conversion) ──
// WHY: Enables seamless interop between Bengali numerals (০-৯) and ASCII digits (0-9).
fn bengali_digit_to_int ch_str
    if len(ch_str) == 0
        return -1
    c = ord(char_at(ch_str, 0))
    // Standard ASCII '0'..'9'
    if c >= 48 and c <= 57
        return c - 48
    // Bengali Digits '০'..'৯' (U+09E6 to U+09EF: bytes 0xE0 0xA7 0xA6 to 0xE0 0xA7 0xAF)
    if len(ch_str) >= 3
        b1 = ord(char_at(ch_str, 0))
        b2 = ord(char_at(ch_str, 1))
        b3 = ord(char_at(ch_str, 2))
        if b1 == 224 and b2 == 167
            if b3 >= 166 and b3 <= 175
                return b3 - 166
    return -1

fn int_to_bengali_digit n
    if n == 0 return "০"
    if n == 1 return "১"
    if n == 2 return "২"
    if n == 3 return "৩"
    if n == 4 return "৪"
    if n == 5 return "৫"
    if n == 6 return "৬"
    if n == 7 return "৭"
    if n == 8 return "৮"
    if n == 9 return "৯"
    return str(n)
