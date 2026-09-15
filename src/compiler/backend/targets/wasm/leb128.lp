// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — LEB128 VARIABLE-LENGTH INTEGER ENCODER (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/wasm/leb128.lp
//
// WHY THIS MODULE:
// 1. WebAssembly (W3C WASM Core Specification) requires all integer quantities,
//    type indices, section payloads, string lengths, and instruction immediates to
//    be encoded using Little-Endian Base 128 (LEB128).
// 2. LEB128 compresses integer storage:
//    - Integers 0..127 consume exactly 1 byte.
//    - Integers 128..16383 consume 2 bytes.
//    - Bit 7 of each byte acts as a continuation flag (1 = more bytes follow, 0 = final byte).
// 3. Signed vs Unsigned Invariance:
//    - Unsigned (u32/u64): Terminates when remainder becomes 0.
//    - Signed (i32/i64): Must account for two's complement sign-extension. Terminates
//      when (val == 0 and sign_bit == 0) OR (val == -1 and sign_bit == 1).
// ==============================================================================

// ── 1. Unsigned LEB128 Encoder (u32 / u64) ────────────────────────────────────

fn leb128_encode_u32 val
    // WHY: Encodes unsigned 32-bit integer into minimal LEB128 byte sequence.
    bytes = list()
    v = val
    if v < 0
        v = v + 4294967296 // Map negative to 32-bit unsigned modular domain

    more = 1
    while more == 1
        b = v % 128
        v = v / 128
        if v == 0
            push(bytes, b)
            more = 0
        else
            push(bytes, b + 128) // Set continuation bit 7
    return bytes

fn leb128_encode_u64 val
    // WHY: Encodes unsigned 64-bit integer into LEB128 bytes.
    bytes = list()
    v = val
    more = 1
    while more == 1
        b = v % 128
        v = v / 128
        if v == 0
            push(bytes, b)
            more = 0
        else
            push(bytes, b + 128)
    return bytes

// ── 2. Signed LEB128 Encoder (i32 / i64) ──────────────────────────────────────

fn leb128_encode_i32 val
    // WHY: Encodes signed 32-bit integer with two's-complement sign preservation.
    bytes = list()
    v = val
    more = 1
    while more == 1
        b = v % 128
        if b < 0 b = b + 128

        // Arithmetic right shift by 7 bits:
        // In integer division: if negative and odd division, adjust towards negative infinity
        v = v / 128
        if val < 0 and (val % 128) != 0 and v >= 0
            v = 0 - 1

        sign_bit = 0
        if (b % 128) >= 64
            sign_bit = 1

        if (v == 0 and sign_bit == 0) or (v == (0 - 1) and sign_bit == 1)
            push(bytes, b)
            more = 0
        else
            push(bytes, b + 128)
    return bytes

fn leb128_encode_i64 val
    // WHY: Alias for 64-bit signed LEB128 encoding.
    return leb128_encode_i32(val)

// ── 3. LEB128 Verification Decoder ───────────────────────────────────────────

struct LEB128DecodeResult
    value
    bytes_consumed

fn leb128_decode_u32 bytes offset
    // WHY: Decodes LEB128 byte stream at offset to verify roundtrip fidelity.
    res = LEB128DecodeResult()
    result = 0
    shift = 0
    idx = offset
    more = 1
    count = 0

    while more == 1
        b = get(bytes, idx)
        idx = idx + 1
        count = count + 1

        val_chunk = b % 128
        // Multiply by 2^shift
        mul = 1
        s = 0
        while s < shift
            mul = mul * 2
            s = s + 1

        result = result + (val_chunk * mul)

        if b < 128
            more = 0
        else
            shift = shift + 7

    res.value = result
    res.bytes_consumed = count
    return res

// ── 4. Verification Self-Test ────────────────────────────────────────────────

fn test_leb128_subsystem
    // 1. Value 0 -> single byte 0x00
    b0 = leb128_encode_u32(0)
    if len(b0) != 1 or get(b0, 0) != 0
        say "FAIL: LEB128 0 encoding failed"
        return 0

    // 2. Value 1 -> single byte 0x01
    b1 = leb128_encode_u32(1)
    if len(b1) != 1 or get(b1, 0) != 1
        say "FAIL: LEB128 1 encoding failed"
        return 0

    // 3. Value 127 -> single byte 0x7F
    b127 = leb128_encode_u32(127)
    if len(b127) != 1 or get(b127, 0) != 127
        say "FAIL: LEB128 127 encoding failed"
        return 0

    // 4. Value 128 -> two bytes: 0x80, 0x01 (128, 1)
    b128 = leb128_encode_u32(128)
    if len(b128) != 2 or get(b128, 0) != 128 or get(b128, 1) != 1
        say "FAIL: LEB128 128 encoding failed"
        return 0

    // 5. Value 624485 -> 0xE5, 0x8E, 0x26
    b_large = leb128_encode_u32(624485)
    if len(b_large) != 3 or get(b_large, 0) != 229 or get(b_large, 1) != 142 or get(b_large, 2) != 38
        say "FAIL: LEB128 624485 encoding failed"
        return 0

    // 6. Roundtrip decoder test
    dec = leb128_decode_u32(b_large, 0)
    if dec.value != 624485 or dec.bytes_consumed != 3
        say "FAIL: LEB128 decode roundtrip failed"
        return 0

    // 7. Signed value -1 -> 0x7F
    b_neg1 = leb128_encode_i32(0 - 1)
    if len(b_neg1) != 1 or get(b_neg1, 0) != 127
        say "FAIL: Signed LEB128 -1 encoding failed"
        return 0

    return 1

test_leb128_subsystem()
