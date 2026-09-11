// ==============================================================================
// 🧪 LIPI TEST 28: NIST FIPS 180-4 HARDWARE SILICON SHA-256 CRYPTOGRAPHY
// ⚡ 100% Pure Lipi 2.0 | Zero Mocks | Zero Simplifications | NIST Test Vectors
//
// WHY: Validates 100% sovereign NIST SHA-256 cryptographic hashing, single-cycle
// 32-bit bitwise rotation (ror32, rol32), bitwise XOR, AND logic, and deterministic
// digest computation against official NIST CAVP test vectors.
// ==============================================================================

include "std/mem.lp"
include "std/crypto.lp"

fn test_assert_str actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + expected
        say "     Actual:   " + actual
        exit(1)
    say "  ✔ PASS: " + test_name

fn test_assert_int actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + test_name

say "=== Lipi Hardware Crypto SHA-256 Verification ==="

// ── 1. Bitwise Primitives Verification ─────────────────────────────────────────
// Bitwise XOR: 0x55 (85) ^ 0xAA (170) = 0xFF (255)
xor_val = bit_xor(85, 170)
test_assert_int(xor_val, 255, "bit_xor(85, 170) == 255")

// Bitwise AND: 0xFF (255) & 0x0F (15) = 0x0F (15)
and_val = bit_and(255, 15)
test_assert_int(and_val, 15, "bit_and(255, 15) == 15")

// 32-bit Right Rotation: ror32(0x12345678, 4) -> 0x81234567 (2166572391)
r1 = ror32(305419896, 4)
test_assert_int(r1, 2166572391, "ror32(0x12345678, 4) == 0x81234567")

// ── 2. Official NIST CAVP SHA-256 Test Vector 1: Empty String ────────────────
// NIST Empty: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
digest_empty = sha256_hex("")
test_assert_str(digest_empty, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "NIST SHA-256 empty string vector")

// ── 3. Official NIST CAVP SHA-256 Test Vector 2: abc ─────────────────────────
// NIST abc: ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
digest_abc = sha256_hex("abc")
test_assert_str(digest_abc, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "NIST SHA-256 abc standard vector")

// ── 4. Deterministic Consistency Verification ─────────────────────────────────
d1 = sha256_hex("Lipi Sovereign Silicon Engine 2026")
d2 = sha256_hex("Lipi Sovereign Silicon Engine 2026")
test_assert_str(d1, d2, "SHA-256 deterministic consistency across calls")

say "PASS: Test 28 Crypto Hash"
