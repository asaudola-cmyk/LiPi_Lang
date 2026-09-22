// ==============================================================================
// 🧪 LIPI TEST: Sovereign Package Hub & Deterministic Lockfile Test Suite
// ⚡ Tests NIST FIPS 180-4 SHA-256 hash, manifest TOML emission, canonical sorting,
//    deterministic lockfile generation (Trap 3 defense), supply-chain tamper detection,
//    provenance envelope verification, and standalone zero-config source bundler.
// ==============================================================================

include "universe/pkg/lipipkg_hub.lp"

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ " + test_name

say "========================================================"
say "👑 Testing Lipi Sovereign Cryptographic Package Hub"
say "========================================================"

// ── Test 1: NIST FIPS 180-4 SHA-256 Standard Test Vector ───────────────────────
say "[1/6] Testing Native FIPS 180-4 SHA-256 Hash Engine..."
sha_abc = lipipkg_sha256("abc")
expected_sha_abc = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
assert_eq(sha_abc, expected_sha_abc, "SHA-256('abc') matches NIST standard test vector")

// ── Test 2: Package Manifest Creation & TOML Serialization ────────────────────
say "[2/6] Testing Package Manifest Generator & TOML Emitter..."
m = lipipkg_manifest_new("neural_core", "1.0.0", "Lipi Team <dev@lipi.lang>", "MIT", "Core Neural Engine", "src/lib.lp")
lipipkg_manifest_add_dep(m, "matrix_math", ">=0.4.0", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
lipipkg_manifest_add_dep(m, "autograd", ">=1.0.0", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")

assert_eq(lipipkg_manifest_get_name(m), "neural_core", "Manifest name is neural_core")
assert_eq(lipipkg_manifest_get_version(m), "1.0.0", "Manifest version is 1.0.0")
assert_eq(lipipkg_manifest_get_dep_count(m), 2, "Manifest dependency count is 2")

toml_str = lipipkg_manifest_to_toml(m)
if len(toml_str) < 50
    say "  ❌ FAILED: TOML string too short"
    exit(1)
say "  ✔ Manifest serialized to standard TOML (" + str(len(toml_str)) + " chars)"

// ── Test 3: Deterministic Canonical Lockfile (Trap 3 Defense) ─────────────────
say "[3/6] Testing Deterministic Canonical Lockfile Sorting (Trap 3 Defense)..."
// Add packages in intentionally unsorted order: "tensor", "algebra", "graphics"
lf = lipipkg_lock_new("neural_core", "1.0.0", "mock_manifest_sha256")
empty_deps = list()
lipipkg_lock_add_package(lf, "tensor", "1.1.0", "hub.lipi.lang/pkgs/tensor/1.1.0.lp", "sha_tensor", empty_deps)
lipipkg_lock_add_package(lf, "algebra", "2.0.1", "hub.lipi.lang/pkgs/algebra/2.0.1.lp", "sha_algebra", empty_deps)
lipipkg_lock_add_package(lf, "graphics", "0.9.0", "hub.lipi.lang/pkgs/graphics/0.9.0.lp", "sha_graphics", empty_deps)

// Sort canonically
lipipkg_lock_sort_canonical(lf)
pkgs = get(lf, 3)
assert_eq(get(get(pkgs, 0), 0), "algebra", "Index 0 sorted canonically to 'algebra'")
assert_eq(get(get(pkgs, 1), 0), "graphics", "Index 1 sorted canonically to 'graphics'")
assert_eq(get(get(pkgs, 2), 0), "tensor", "Index 2 sorted canonically to 'tensor'")

// Serialize lockfile and verify determinism
lock_str_1 = lipipkg_lock_serialize(lf)
lock_str_2 = lipipkg_lock_serialize(lf)
assert_eq(lock_str_1, lock_str_2, "Lockfile serialization is bit-for-bit deterministic")

// ── Test 4: Supply Chain Integrity & Tamper Detection ─────────────────────────
say "[4/6] Testing Supply Chain Tamper Detection..."
// Create clean lockfile from manifest
clean_lf = lipipkg_cmd_lock(m)
is_valid = lipipkg_cmd_verify(m, clean_lf)
assert_eq(is_valid, 1, "Clean lockfile verified successfully")

// Simulate supply-chain tampering: corrupt checksum of matrix_math in lockfile
clean_pkgs = get(clean_lf, 3)
tampered_entry = get(clean_pkgs, 1) // matrix_math
list_set(tampered_entry, 3, "0000000000000000000000000000000000000000000000000000000000000000") // Tampered!
is_tampered_valid = lipipkg_cmd_verify(m, clean_lf)
assert_eq(is_tampered_valid, 0, "Supply-chain tampering detected and rejected (0)")

// ── Test 5: Cryptographic Provenance Envelope Verification ────────────────────
say "[5/6] Testing Cryptographic Provenance Envelope..."
pubkey = "ed25519_pk_7f3b89012a4c5e6f7a8b9c0d1e2f3a4b"
sig = "sig_valid_payload_0123456789abcdef0123456789abcdef"
env = lipipkg_envelope_new("neural_core", "1.0.0", expected_sha_abc, pubkey, sig)

assert_eq(lipipkg_envelope_verify(env, pubkey), 1, "Valid envelope signature verified")
assert_eq(lipipkg_envelope_verify(env, "unauthorized_attacker_key"), 0, "Forged key rejected")

// ── Test 6: Zero-Config Standalone Source Bundler ──────────────────────────────
say "[6/6] Testing Standalone Source Bundler..."
dep_names = list()
push(dep_names, "matrix_math")
push(dep_names, "autograd")

dep_codes = list()
push(dep_codes, "fn mat_mul a b return a * b")
push(dep_codes, "fn grad_compute x return x * 2")

main_src = "fn main return mat_mul(10, grad_compute(5))"
bundle = lipipkg_bundle_source(m, main_src, dep_names, dep_codes)

if len(bundle) < 100
    say "  ❌ FAILED: Bundle too short"
    exit(1)
say "  ✔ Standalone single-binary bundle generated (" + str(len(bundle)) + " chars)"

say "========================================================"
say "PASS: Lipi Sovereign Cryptographic Package Hub Verified 100%!"
say "========================================================"
