// ==============================================================================
// 👑 LIPI UNIVERSE — Canonical Unicode & Bengali Rune Engine (utso/core/unicode.lp)
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
// WHY: RFC 3629 compliant lead byte length classification.
// Rejects continuation bytes (128..191), C0/C1 overlong leads (192..193), and >=245 leads as 1-byte error steps.
fn utf8_byte_len lead_byte
    b = floor(lead_byte) % 256
    if b < 0
        b = b + 256
    // 1-Byte ASCII: 0xxxxxxx (0 to 127)
    if b < 128
        return 1
    // Invalid continuation/overlong lead: 128..193
    if b < 194
        return 1
    // 2-Byte Sequence: 110xxxxx (194 to 223)
    if b < 224
        return 2
    // 3-Byte Sequence: 1110xxxx (224 to 239) -> Bengali U+0980..U+09FF lives here
    if b < 240
        return 3
    // 4-Byte Sequence: 11110xxx (240 to 244) -> Up to U+10FFFF
    if b < 245
        return 4
    return 1

// ── ২. নির্দিষ্ট পজিশনে কোডপয়েন্ট ডিকোডিং (Decode Scalar Value at Byte Offset) ─
// WHY: Strictly validates continuation bytes (10xxxxxx), overlong encodings, UTF-16 surrogates
// (U+D800..U+DFFF), and range <= U+10FFFF per RFC 3629, returning U+FFFD (65533) on malformed input.
fn utf8_decode_codepoint s byte_pos
    slen = len(s)
    if byte_pos >= slen or byte_pos < 0
        return 0
    b1 = ord(char_at(s, byte_pos))
    if b1 < 128
        return b1
    if b1 < 194 or b1 > 244
        return 65533
    blen = utf8_byte_len(b1)
    if blen == 2
        if byte_pos + 1 >= slen
            return 65533
        b2 = ord(char_at(s, byte_pos + 1))
        if b2 < 128 or b2 > 191
            return 65533
        cp2 = ((b1 - 192) * 64) + (b2 - 128)
        if cp2 < 128
            return 65533
        return cp2
    if blen == 3
        if byte_pos + 2 >= slen
            return 65533
        b2 = ord(char_at(s, byte_pos + 1))
        b3 = ord(char_at(s, byte_pos + 2))
        if b2 < 128 or b2 > 191 or b3 < 128 or b3 > 191
            return 65533
        cp3 = ((b1 - 224) * 4096) + ((b2 - 128) * 64) + (b3 - 128)
        if cp3 < 2048
            return 65533
        if cp3 >= 55296 and cp3 <= 57343
            return 65533
        return cp3
    if blen == 4
        if byte_pos + 3 >= slen
            return 65533
        b2 = ord(char_at(s, byte_pos + 1))
        b3 = ord(char_at(s, byte_pos + 2))
        b4 = ord(char_at(s, byte_pos + 3))
        if b2 < 128 or b2 > 191 or b3 < 128 or b3 > 191 or b4 < 128 or b4 > 191
            return 65533
        cp4 = ((b1 - 240) * 262144) + ((b2 - 128) * 4096) + ((b3 - 128) * 64) + (b4 - 128)
        if cp4 < 65536 or cp4 > 1114111
            return 65533
        return cp4
    return 65533

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

// WHY: Verifies every byte sequence in string s conforms strictly to RFC 3629 UTF-8.
fn utf8_is_valid s
    slen = len(s)
    pos = 0
    while pos < slen
        b1 = ord(char_at(s, pos))
        if b1 < 128
            pos = pos + 1
        elif b1 >= 194 and b1 <= 244
            step = utf8_byte_len(b1)
            cp = utf8_decode_codepoint(s, pos)
            if cp == 65533
                // Only valid if literal U+FFFD (EF BF BD = 239 191 189)
                if not (step == 3 and pos + 2 < slen and b1 == 239 and ord(char_at(s, pos + 1)) == 191 and ord(char_at(s, pos + 2)) == 189)
                    return 0
            pos = pos + step
        else
            return 0
    return 1

// WHY: Parses multi-digit Bengali (০..৯) and ASCII (0..9) integer strings with optional sign.
fn bengali_num_to_int s
    slen = len(s)
    pos = 0
    while pos < slen
        c = ord(char_at(s, pos))
        if c == 32 or c == 9 or c == 10 or c == 13
            pos = pos + 1
        else
            break
    if pos >= slen
        return 0
    neg = 0
    fc = ord(char_at(s, pos))
    if fc == 45
        neg = 1
        pos = pos + 1
    elif fc == 43
        pos = pos + 1
    acc = 0
    while pos < slen
        cp = utf8_decode_codepoint(s, pos)
        b = ord(char_at(s, pos))
        step = utf8_byte_len(b)
        if cp >= 48 and cp <= 57
            acc = (acc * 10) - (cp - 48)
        elif cp >= 2534 and cp <= 2543
            acc = (acc * 10) - (cp - 2534)
        else
            break
        pos = pos + step
    if neg == 1
        return acc
    return 0 - acc
