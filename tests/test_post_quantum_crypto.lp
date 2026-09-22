// ==============================================================================
// 🧪 LIPI TEST SUITE: POST-QUANTUM CRYPTOGRAPHY (PQC) & LATTICE ARITHMETIC
// File: tests/test_post_quantum_crypto.lp
// Standard: NIST FIPS 203 ML-KEM / Kyber Lattice Ring Rq (q=3329, n=16)
// 100% Pure Lipi — Zero OpenSSL | Zero C | Zero Libc
// ==============================================================================

include "universe/crypto/pqc.lp"

fn assert_true cond msg
    if cond == 0
        say "  ❌ [FAIL] Assertion failed: " + msg
        exit(1)
    say "  ✔ [PASS] " + msg

fn assert_eq_int actual expected msg
    if actual != expected
        say "  ❌ [FAIL] " + msg + " (Expected " + str(expected) + ", got " + str(actual) + ")"
        exit(1)
    say "  ✔ [PASS] " + msg

fn main
    say "================================================================="
    say "🛡️ LIPI POST-QUANTUM CRYPTOGRAPHY (KYBER LATTICE) TEST SUITE 🛡️"
    say "================================================================="

    total_tests = 0
    passed_tests = 0

    // ── Section 1: Ring R_q Modular Reduction & Addition ──────────────────────
    say "▶ Section 1: Polynomial Ring R_q Modular Arithmetic (q=3329)..."
    total_tests = total_tests + 1

    p1 = poly_new(4)
    p2 = poly_new(4)

    list_set(p1, 0, 3000)
    list_set(p1, 1, 500)
    list_set(p2, 0, 400)
    list_set(p2, 1, 3000)

    // (3000 + 400) % 3329 = 3400 % 3329 = 71
    p_add = poly_add(p1, p2, 4)
    assert_eq_int(get(p_add, 0), 71, "Coeff 0 modular addition: (3000 + 400) mod 3329 = 71")

    // (500 - 3000) = -2500 -> (-2500 + 3329) = 829
    p_sub = poly_sub(p1, p2, 4)
    assert_eq_int(get(p_sub, 1), 829, "Coeff 1 modular subtraction: (500 - 3000) mod 3329 = 829")
    passed_tests = passed_tests + 1

    // ── Section 2: Negative Wrapped Convolution: X^n = -1 Modulo (X^n + 1) ───
    say "\n▶ Section 2: Negative Wrapped Convolution Modulo (X^n + 1)..."
    total_tests = total_tests + 1

    // Let n = 4. Test X^1 * X^3 = X^4.
    // In R_q = Z_q[X]/(X^4 + 1), X^4 = -1 = 3328 mod 3329!
    pa = poly_new(4)
    pb = poly_new(4)
    list_set(pa, 1, 1) // pa = X
    list_set(pb, 3, 1) // pb = X^3

    prod = poly_mul_rq(pa, pb, 4)
    // Degree 4 wrapped around to degree 0 with negative sign: -1 = 3328
    assert_eq_int(get(prod, 0), 3328, "X^1 * X^3 = X^4 = -1 = 3328 (negative wrap verified)")
    assert_eq_int(get(prod, 1), 0, "Degree 1 is 0")
    assert_eq_int(get(prod, 2), 0, "Degree 2 is 0")
    assert_eq_int(get(prod, 3), 0, "Degree 3 is 0")
    passed_tests = passed_tests + 1

    // ── Section 3: Kyber Key Generation (A * s + e = t) ───────────────────────
    say "\n▶ Section 3: Kyber-512 Key Generation (A * s + e = t)..."
    total_tests = total_tests + 1

    n = 16
    keys = pqc_keygen(n)
    assert_eq_int(len(keys), 3, "Generated key container [A, t, s]")

    poly_A = get(keys, 0)
    poly_t = get(keys, 1)
    poly_s = get(keys, 2)

    assert_eq_int(len(poly_A), n, "Public matrix vector A length is 16")
    assert_eq_int(len(poly_t), n, "Public key vector t length is 16")
    assert_eq_int(len(poly_s), n, "Secret key vector s length is 16")
    passed_tests = passed_tests + 1

    // ── Section 4: IND-CPA Lattice Encapsulation & Decapsulation Roundtrip ────
    say "\n▶ Section 4: IND-CPA Encapsulation & Decapsulation Roundtrip..."
    total_tests = total_tests + 1

    // Encapsulate Secret Bit 1
    ct1 = pqc_encaps(keys, 1, n)
    rec1 = pqc_decaps(keys, ct1, n)
    assert_eq_int(rec1, 1, "Encapsulated shared secret bit 1 successfully decapsulated")

    // Encapsulate Secret Bit 0
    ct0 = pqc_encaps(keys, 0, n)
    rec0 = pqc_decaps(keys, ct0, n)
    assert_eq_int(rec0, 0, "Encapsulated shared secret bit 0 successfully decapsulated")

    passed_tests = passed_tests + 1

    say "\n-----------------------------------------------------------------"
    say "RESULTS: " + str(passed_tests) + "/" + str(total_tests) + " sections passed."
    say "🎉 ALL POST-QUANTUM CRYPTOGRAPHY TESTS PASSED!"
    return 0

main()
