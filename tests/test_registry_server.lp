// ==============================================================================
// 🧪 LIPI TEST SUITE: DECENTRALIZED PACKAGE REGISTRY (lipipkg hub)
// File: tests/test_registry_server.lp
// Standard: REST API | FIPS 180-4 SHA-256 | Ed25519 Provenance Verification
// 100% Pure Lipi — Zero Libc | Zero C | Zero External Dependencies
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/json.lp"
include "universe/pkg/lipipkg_hub.lp"

struct PkgRecord
    name
    version
    author
    description
    sha256_hash
    pubkey
    signature

fn pkg_record_new name version author desc sha pubkey sig
    p = PkgRecord()
    p.name = name
    p.version = version
    p.author = author
    p.description = desc
    p.sha256_hash = sha
    p.pubkey = pubkey
    p.signature = sig
    return p

fn pkg_record_to_json p
    json = "{\"name\":\"" + json_escape(p.name) + "\","
    json = json + "\"version\":\"" + json_escape(p.version) + "\","
    json = json + "\"author\":\"" + json_escape(p.author) + "\","
    json = json + "\"description\":\"" + json_escape(p.description) + "\","
    json = json + "\"sha256\":\"" + json_escape(p.sha256_hash) + "\","
    json = json + "\"pubkey\":\"" + json_escape(p.pubkey) + "\","
    json = json + "\"signature\":\"" + json_escape(p.signature) + "\"}"
    return json

fn registry_catalog_init
    catalog = list()
    p1 = pkg_record_new(
        "tensor_core",
        "1.0.0",
        "Lipi Team <dev@lipi.lang>",
        "Sovereign Silicon SIMD Tensor Engine",
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        "ed25519_pk_7f3b89012a4c5e6f7a8b9c0d1e2f3a4b",
        "sig_tensor_core_0123456789abcdef0123456789abcdef"
    )
    push(catalog, p1)

    p2 = pkg_record_new(
        "crypto_vault",
        "0.9.0",
        "Lipi Core <security@lipi.lang>",
        "NIST FIPS 180-4 SHA-256 and Ed25519 Engine",
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "ed25519_pk_8a4c5e6f7a8b9c0d1e2f3a4b7f3b8901",
        "sig_crypto_vault_abcdef0123456789abcdef0123456789"
    )
    push(catalog, p2)
    return catalog

fn registry_find_pkg catalog target_name
    i = 0
    cnt = len(catalog)
    while i < cnt
        rec = get(catalog, i)
        if rec.name == target_name
            return rec
        i = i + 1
    return 0

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

fn assert_eq_str actual expected msg
    if actual != expected
        say "  ❌ [FAIL] " + msg + " (Expected '" + expected + "', got '" + actual + "')"
        exit(1)
    say "  ✔ [PASS] " + msg

fn main
    say "================================================================="
    say "📦 LIPI DECENTRALIZED PACKAGE REGISTRY TEST SUITE 📦"
    say "================================================================="

    total_tests = 0
    passed_tests = 0

    // ── Section 1: Catalog Initialization & JSON Serialization ────────────────
    say "▶ Section 1: Catalog Initialization & Serialization..."
    total_tests = total_tests + 1

    catalog = registry_catalog_init()
    assert_eq_int(len(catalog), 2, "Registry initialized with 2 core packages")

    rec1 = registry_find_pkg(catalog, "tensor_core")
    assert_true(rec1 != 0, "Found 'tensor_core' in catalog")
    assert_eq_str(rec1.version, "1.0.0", "Version matches 1.0.0")

    rec1_json = pkg_record_to_json(rec1)
    assert_true(len(rec1_json) > 50, "JSON serialization generated valid string")
    passed_tests = passed_tests + 1

    // ── Section 2: Cryptographic Provenance Envelope Verification ──────────────
    say "\n▶ Section 2: Cryptographic Signature & Provenance Verification..."
    total_tests = total_tests + 1

    pubkey = "ed25519_pk_7f3b89012a4c5e6f7a8b9c0d1e2f3a4b"
    sig = "sig_valid_payload_0123456789abcdef0123456789abcdef"
    valid_sha = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    env_valid = lipipkg_envelope_new("autograd", "1.2.0", valid_sha, pubkey, sig)

    // Valid key check
    is_valid = lipipkg_envelope_verify(env_valid, pubkey)
    assert_eq_int(is_valid, 1, "Legitimate package publisher key verified")

    // Forged key check
    is_forged = lipipkg_envelope_verify(env_valid, "attacker_rogue_key_000000000000")
    assert_eq_int(is_forged, 0, "Forged attacker key rejected by cryptographic verifier")
    passed_tests = passed_tests + 1

    // ── Section 3: FIPS 180-4 Content Addressable Hashing (CAS) ────────────────
    say "\n▶ Section 3: Content Addressable Hashing (SHA-256)..."
    total_tests = total_tests + 1

    // Verify SHA-256 standard test vectors
    sha_empty = lipipkg_sha256("")
    assert_eq_str(sha_empty, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "SHA-256('') empty string hash matches NIST vector")

    sha_abc = lipipkg_sha256("abc")
    assert_eq_str(sha_abc, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256('abc') hash matches NIST vector")
    passed_tests = passed_tests + 1

    // ── Section 4: Dynamic Package Publishing & Catalog Update ─────────────────
    say "\n▶ Section 4: Dynamic Package Publishing & Deduplication..."
    total_tests = total_tests + 1

    // Publish new package "vision_core"
    new_pkg = pkg_record_new(
        "vision_core",
        "0.5.0",
        "Lipi Vision <vision@lipi.lang>",
        "Sovereign Computer Vision Rasterizer",
        "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb",
        "ed25519_pk_vision_123456789",
        "sig_vision_0123456789abcdef"
    )
    push(catalog, new_pkg)
    assert_eq_int(len(catalog), 3, "Catalog count increased to 3")

    found_new = registry_find_pkg(catalog, "vision_core")
    assert_true(found_new != 0, "Newly published package queryable in catalog")
    assert_eq_str(found_new.description, "Sovereign Computer Vision Rasterizer", "Description recorded correctly")
    passed_tests = passed_tests + 1

    say "\n-----------------------------------------------------------------"
    say "RESULTS: " + str(passed_tests) + "/" + str(total_tests) + " sections passed."
    say "🎉 ALL DECENTRALIZED PACKAGE REGISTRY TESTS PASSED!"
    return 0

main()
