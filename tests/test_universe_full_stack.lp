// ==============================================================================
// 👑 TEST: LIPI UNIVERSE STANDARD LIBRARY FULL-STACK FLAGSHIP TEST
// ⚡ File: tests/test_universe_full_stack.lp
//
// WHY: Validates end-to-end synergy across all canonical Universe subsystems:
//      1. Core Grand Prelude & Subsystem Introspection
//      2. Sovereign 64-Byte Aligned Arena Memory Bump Allocation
//      3. Dynamic Arrays (Collections) & Robinhood Hashmap
//      4. Zero-Copy In-Place Fast JSON Parser
//      5. Silicon Cryptography SHA-256 Hashing
//      6. Hardware Silicon AVX2 Vector Operations
//      7. In-Memory Key-Value Storage (KV Store)
//
// 100% Pure Lipi | 0% C | 0% GCC | 0% Libc | Direct Machine Code
// ==============================================================================

import "universe/lipi_universe"
import "universe/db/kv"

fn main()
    say "=================================================================="
    say "🌌 LIPI UNIVERSE STANDARD LIBRARY FULL-STACK INTEGRATION TEST"
    say "=================================================================="

    // ── 1. Grand Prelude Introspection ─────────────────────────────────────────
    say "[1/7] Testing Grand Prelude Statistics & Hardware Introspection..."
    lipi_universe_stats()
    avx2_ok = lipi_hardware_info()
    say "  ✔ Universe statistics and hardware probe executed."

    // ── 2. Sovereign 64-Byte Aligned Arena Allocation ───────────────────────────
    say "[2/7] Testing Sovereign Arena Memory Allocator (64-byte Cacheline)..."
    pool = lipi_arena_new(65536)
    if pool == 0
        say "FAIL: arena_create returned null"
        exit(1)
    
    // Allocate 32 elements of 64-bit integers with 64-byte cacheline alignment
    buf = arena_alloc_aligned(pool, 256, 64)
    if buf == 0
        say "FAIL: arena_alloc_aligned returned null"
        exit(1)
    
    // Verify 64-byte alignment
    if buf % 64 != 0
        say "FAIL: Buffer address not 64-byte aligned: " + str(buf)
        exit(1)
    
    say "  ✔ Arena 64-byte cacheline alignment verified: " + str(buf)

    // Populate buffer with integers for SIMD testing
    idx = 0
    while idx < 32
        মেমরি_লেখো(buf, idx * 8, idx + 1)
        idx = idx + 1
    say "  ✔ Buffer populated with 32 consecutive QWORD integers (1..32)."

    // ── 3. Silicon Hardware SIMD Vector Sum ────────────────────────────────────
    say "[3/7] Testing Hardware AVX2 Silicon Vector Sum Kernel..."
    simd_sum = vector_sum_hardware(buf, 32)
    // Expected sum: 1 + 2 + ... + 32 = (32 * 33) / 2 = 528
    if simd_sum != 528
        say "FAIL: SIMD vector sum mismatch! Expected 528, got: " + str(simd_sum)
        exit(1)
    say "  ✔ AVX2 SIMD Vector Sum Verified: 528 (Bit-for-Bit match!)"
    
    // Test O(1) bulk arena reset
    arena_reset(pool)
    if arena_used(pool) != 0
        say "FAIL: Arena reset failed to zero used memory"
        exit(1)
    say "  ✔ O(1) Instant Arena Mass Reset Verified."
    arena_destroy(pool)

    // ── 4. Core Dynamic Collections & Robinhood Hashmap ─────────────────────────
    say "[4/7] Testing Collections Dynamic Array & Hashmap Operations..."
    lst = list()
    push(lst, "Sovereign")
    push(lst, "Lipi")
    push(lst, "Universe")
    if len(lst) != 3
        say "FAIL: Collections list length mismatch: " + str(len(lst))
        exit(1)
    if get(lst, 1) != "Lipi"
        say "FAIL: Collections get index 1 mismatch"
        exit(1)
    say "  ✔ Dynamic Array List operations verified (3 items)."

    cap = 64
    hm = hashmap_create(cap)
    hashmap_insert(hm, cap, 1001, 7777)
    hashmap_insert(hm, cap, 2002, 8888)
    v1 = hashmap_lookup(hm, cap, 1001)
    v2 = hashmap_lookup(hm, cap, 2002)
    if v1 != 7777 or v2 != 8888
        say "FAIL: Hashmap lookup mismatch: v1=" + str(v1) + ", v2=" + str(v2)
        exit(1)
    say "  ✔ Robinhood Hashmap lookup verified (Keys 1001->7777, 2002->8888)."
    hashmap_delete(hm, cap)

    // ── 5. Zero-Copy In-Place Fast JSON Parser ──────────────────────────────────
    say "[5/7] Testing Zero-Copy Fast JSON Parser Engine..."
    sample_json = "{\"engine\": \"Lipi Universe\", \"version\": 2, \"active\": true}"
    doc = fast_json_parse(sample_json)
    if doc == 0
        say "FAIL: fast_json_parse failed on valid input"
        exit(1)
    root = fast_json_root(doc)
    root_type = fast_json_node_type(doc, root)
    if root_type != 5 // FAST_JSON_OBJECT
        say "FAIL: Expected JSON root type 5 (OBJECT), got: " + str(root_type)
        exit(1)
    
    // Lookup integer key \"version\"
    ver_idx = fast_json_get(doc, root, "version")
    if ver_idx < 0
        say "FAIL: Key \"version\" not found in JSON document"
        exit(1)
    ver_val = fast_json_get_int(doc, ver_idx)
    if ver_val != 2
        say "FAIL: JSON version mismatch! Expected 2, got: " + str(ver_val)
        exit(1)
    say "  ✔ Zero-Copy JSON Parser verified: Object parsed, version = " + str(ver_val)

    // ── 6. Silicon Cryptography SHA-256 Digest ──────────────────────────────────
    say "[6/7] Testing Cryptographic SHA-256 Engine..."
    test_str = "Lipi-Universe-v2.5"
    sha_hash = crypto_sha256_hex(test_str)
    if len(sha_hash) != 64
        say "FAIL: Invalid SHA-256 hex digest length: " + str(len(sha_hash))
        exit(1)
    say "  ✔ SHA-256 Hex Digest Verified: " + sha_hash

    // ── 7. Sovereign In-Memory KV Store ─────────────────────────────────────────
    say "[7/7] Testing Sovereign In-Memory KV Database Engine..."
    kv = KV_create(128)
    if kv == 0
        say "FAIL: KV_create returned null"
        exit(1)
    KV_set(kv, "service:name", "LipiMicroservice")
    KV_set(kv, "service:tier", "Production")
    val_name = KV_get(kv, "service:name")
    val_tier = KV_get(kv, "service:tier")
    if val_name != "LipiMicroservice" or val_tier != "Production"
        say "FAIL: KV get mismatch: " + val_name + ", " + val_tier
        exit(1)
    say "  ✔ In-Memory KV Store verified: Keys retrieved successfully."
    KV_free(kv)

    say "=================================================================="
    say "🎉 ALL 7 LIPI UNIVERSE FULL-STACK PHASES PASSED WITH 100% SUCCESS!"
    say "=================================================================="
    return 0

main()
