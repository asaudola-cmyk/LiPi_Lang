// ==============================================================================
// 👑 LIPI PACKAGE HUB & SEMVER LIFECYCLE REGRESSION TEST
// ⚡ 100% Pure LiPi Implementation | 0% C | 0% Libc | 0% External Runtimes
// ==============================================================================
//
// WHY: Enterprise package registries require formal SemVer 2.0.0 dependency
//      resolution, manifest cryptographic signing, and hash verification without
//      relying on cargo, npm, pip, or external dynamic libraries.

include "universe/core/io.lp"
include "universe/core/string.lp"
include "universe/core/memory.lp"
include "universe/crypto/crypto.lp"
include "universe/registry/semver.lp"

fn assert_true cond msg
    if cond == 0
        say "  ❌ FAILED: " + msg
        exit(1)
    say "  ✔ [PASS] " + msg

fn assert_eq actual expected msg
    if actual != expected
        say "  ❌ FAILED: " + msg
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ [PASS] " + msg

fn main
    say "================================================================="
    say "📦 TESTING LIPI PACKAGE HUB & SEMVER LIFECYCLE ENGINE"
    say "================================================================="

    // ── Phase 1: SemVer 2.0.0 Parsing & Precedence Hierarchy ───────────────────
    say "\n▶ Phase 1: SemVer 2.0.0 Structural Decomposition..."
    v1 = semver_parse("1.2.3")
    assert_eq(v1.major, 1, "Major version parsed (1)")
    assert_eq(v1.minor, 2, "Minor version parsed (2)")
    assert_eq(v1.patch, 3, "Patch version parsed (3)")

    v_pre = semver_parse("2.0.0-rc.1")
    assert_eq(v_pre.major, 2, "Prerelease major parsed (2)")
    assert_eq(v_pre.prerelease, "rc.1", "Prerelease identifier parsed (rc.1)")

    // ── Phase 2: Precedence Comparison Matrix ──────────────────────────────────
    say "\n▶ Phase 2: Version Precedence Ordering..."
    // 1.2.3 vs 1.2.4 (-1: v1 < v2)
    v2 = semver_parse("1.2.4")
    cmp_res1 = semver_compare(v1, v2)
    assert_eq(cmp_res1, 0 - 1, "1.2.3 < 1.2.4 precedence comparison")

    // 2.0.0 vs 1.9.9 (1: v1 > v2)
    v_old = semver_parse("1.9.9")
    v_new = semver_parse("2.0.0")
    cmp_res2 = semver_compare(v_new, v_old)
    assert_eq(cmp_res2, 1, "2.0.0 > 1.9.9 precedence comparison")

    // 1.2.3 vs 1.2.3 (0: v1 == v2)
    v_same = semver_parse("1.2.3")
    cmp_res3 = semver_compare(v1, v_same)
    assert_eq(cmp_res3, 0, "1.2.3 == 1.2.3 precedence identity")

    // ── Phase 3: Caret (^) and Tilde (~) Constraint Satisfaction ───────────────
    say "\n▶ Phase 3: Caret (^) & Tilde (~) Range Satisfaction..."
    // ^1.2.0 accepts 1.2.5
    sat1 = semver_satisfies("1.2.5", "^1.2.0")
    assert_eq(sat1, 1, "1.2.5 satisfies ^1.2.0 constraint")

    // ^1.2.0 rejects 2.0.0
    sat2 = semver_satisfies("2.0.0", "^1.2.0")
    assert_eq(sat2, 0, "2.0.0 rejects ^1.2.0 constraint")

    // ~1.2.0 accepts 1.2.9
    sat3 = semver_satisfies("1.2.9", "~1.2.0")
    assert_eq(sat3, 1, "1.2.9 satisfies ~1.2.0 constraint")

    // ~1.2.0 rejects 1.3.0
    sat4 = semver_satisfies("1.3.0", "~1.2.0")
    assert_eq(sat4, 0, "1.3.0 rejects ~1.2.0 constraint")

    // Range comparison: >=1.0.0, <2.0.0
    sat5 = semver_satisfies("1.5.2", ">=1.0.0")
    assert_eq(sat5, 1, "1.5.2 satisfies >=1.0.0 range boundary")

    // ── Phase 4: Package Manifest Integrity & Hash Verification ────────────────
    say "\n▶ Phase 4: Manifest Cryptographic Integrity (SHA-256)..."
    manifest_data = "[package]\nname = \"sovereign_sample\"\nversion = \"1.0.0\"\nedition = \"2026\"\n"
    m_len = len(manifest_data)
    manifest_buf = sys_alloc(m_len)
    i = 0
    while i < m_len
        mem_byte_write(manifest_buf, i, str_char_at(manifest_data, i))
        i = i + 1

    digest_buf = sys_alloc(65)
    sha256_hash(manifest_buf, m_len, digest_buf)
    
    // Check that 64-char hex digest is produced
    hex_len = 0
    while hex_len < 64
        b = mem_byte_read(digest_buf, hex_len)
        if b >= 48 && b <= 57 // '0'-'9'
            hex_len = hex_len + 1
        else
            if b >= 97 && b <= 102 // 'a'-'f'
                hex_len = hex_len + 1
            else
                hex_len = 65 // invalid character
    assert_eq(hex_len, 64, "SHA-256 64-character manifest hash produced")

    mem_free(manifest_buf, m_len)
    mem_free(digest_buf, 65)

    // ── Phase 5: Dependency Graph Resolution Simulation ────────────────────────
    say "\n▶ Phase 5: Multi-Package Dependency Resolution Resolution..."
    // Candidate package versions in registry: 1.0.0, 1.1.0, 1.2.0, 2.0.0
    // Requirement: ^1.1.0
    // Highest matching version should be 1.2.0
    candidates = list()
    push(candidates, "1.0.0")
    push(candidates, "1.1.0")
    push(candidates, "1.2.0")
    push(candidates, "2.0.0")

    best_match = ""
    req_constraint = "^1.1.0"
    idx = 0
    while idx < len(candidates)
        cand = get(candidates, idx)
        if semver_satisfies(cand, req_constraint) == 1
            if len(best_match) == 0
                best_match = cand
            else
                v_cand = semver_parse(cand)
                v_best = semver_parse(best_match)
                if semver_compare(v_cand, v_best) > 0
                    best_match = cand
        idx = idx + 1

    assert_true(best_match == "1.2.0", "Highest compatible version selected: 1.2.0 for ^1.1.0")

    say "\n================================================================="
    say "🎉 ALL PACKAGE HUB & SEMVER LIFECYCLE TESTS PASSED (5/5) ✔"
    say "================================================================="
    return 0
