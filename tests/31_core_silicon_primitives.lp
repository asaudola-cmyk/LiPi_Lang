// ==============================================================================
// 👑 LIPI FIRST 1.0.0 TEST 31: CORE SILICON PRIMITIVES VERIFICATION PROBE
// ⚡ 100% Pure Lipi Sovereign Implementation | Zero Libc | Zero Dependencies
// Tests all 9 micro-modules in src/core/
// ==============================================================================

include "src/core/types.lp"
include "src/core/span.lp"
include "src/core/string_pool.lp"
include "src/core/endian.lp"
include "src/core/buffer.lp"
include "src/core/arena.lp"
include "src/core/slab.lp"
include "src/core/hashmap.lp"
include "src/core/bitset.lp"

// ── Assertion Helper ──────────────────────────────────────────────────────────

fn assert_true(cond, msg)
    if cond == 0
        say "ASSERTION FAILED: " + msg
        exit(1)
    return 1

// ── 1. Types & Slice Verification ─────────────────────────────────────────────

fn test_types()
    say "[1/9] Testing src/core/types.lp..."

    assert_true(POINTER_WIDTH == 8, "POINTER_WIDTH must be 8")
    assert_true(WORD_SIZE == 8, "WORD_SIZE must be 8")
    assert_true(CACHELINE_SIZE == 64, "CACHELINE_SIZE must be 64")

    assert_true(align_up(10, 8) == 16, "align_up 10 to 8")
    assert_true(align_up(16, 8) == 16, "align_up 16 to 8")
    assert_true(align_down(15, 8) == 8, "align_down 15 to 8")
    assert_true(is_aligned(64, 64) == 1, "is_aligned 64 to 64")
    assert_true(is_aligned(65, 64) == 0, "is_aligned 65 to 64")

    assert_true(type_byte_size(TYPE_I8) == 1, "size of i8")
    assert_true(type_byte_size(TYPE_I16) == 2, "size of i16")
    assert_true(type_byte_size(TYPE_I32) == 4, "size of i32")
    assert_true(type_byte_size(TYPE_I64) == 8, "size of i64")
    assert_true(type_byte_size(TYPE_SLICE) == 24, "size of slice")

    assert_true(type_is_integer(TYPE_U32) == 1, "u32 is integer")
    assert_true(type_is_signed(TYPE_I32) == 1, "i32 is signed")
    assert_true(type_is_unsigned(TYPE_U32) == 1, "u32 is unsigned")
    assert_true(int_fits_type(100, TYPE_I8) == 1, "100 fits in i8")
    assert_true(int_fits_type(200, TYPE_I8) == 0, "200 does not fit in i8")

    // Slice operations
    raw_mem = alloc(64)
    assert_true(raw_mem != 0, "alloc raw_mem for slice")

    sl = slice_new(raw_mem, 8, 8)
    slice_write_word(sl, 0, 11112222)
    slice_write_word(sl, 1, 33334444)

    assert_true(slice_read_word(sl, 0) == 11112222, "slice read word 0")
    assert_true(slice_read_word(sl, 1) == 33334444, "slice read word 1")

    sub = slice_subslice(sl, 1, 2)
    assert_true(slice_length(sub) == 1, "subslice length 1")
    assert_true(slice_read_word(sub, 0) == 33334444, "subslice read word 0")

    free(raw_mem, 64)
    say "      types.lp PASS"
    return 1

// ── 2. Span Verification ──────────────────────────────────────────────────────

fn test_span()
    say "[2/9] Testing src/core/span.lp..."

    s1 = span_new(1, 10, 5, 100, 150)
    s2 = span_new(1, 12, 1, 120, 200)

    assert_true(span_is_valid(s1) == 1, "s1 is valid")
    assert_true(span_len(s1) == 50, "s1 len is 50")
    assert_true(span_contains_offset(s1, 125) == 1, "s1 contains 125")
    assert_true(span_contains_offset(s1, 99) == 0, "s1 does not contain 99")
    assert_true(span_overlaps(s1, s2) == 1, "s1 and s2 overlap")

    comb = span_combine(s1, s2)
    assert_true(comb.start_byte == 100, "combined start byte 100")
    assert_true(comb.end_byte == 200, "combined end byte 200")
    assert_true(comb.line == 10, "combined line 10")
    assert_true(comb.col == 5, "combined col 5")

    pt = span_point(1, 5, 8, 42)
    assert_true(span_len(pt) == 0, "point span len is 0")
    assert_true(span_is_empty(pt) == 1, "point span is empty")

    say "      span.lp PASS"
    return 1

// ── 3. String Pool Verification ───────────────────────────────────────────────

fn test_string_pool()
    say "[3/9] Testing src/core/string_pool.lp..."

    pool = string_pool_new(16)
    sym1 = string_pool_intern(pool, "keyword_fn")
    sym2 = string_pool_intern(pool, "keyword_return")
    sym3 = string_pool_intern(pool, "keyword_fn")

    assert_true(sym1 == sym3, "sym1 == sym3 O(1) deduplication")
    assert_true(sym1 != sym2, "sym1 != sym2 distinct symbols")
    assert_true(string_pool_get(pool, sym1) == "keyword_fn", "retrieve sym1 text")
    assert_true(string_pool_get(pool, sym2) == "keyword_return", "retrieve sym2 text")
    assert_true(string_pool_has(pool, "keyword_fn") == 1, "has keyword_fn")
    assert_true(string_pool_has(pool, "keyword_missing") == 0, "has missing is 0")
    assert_true(string_pool_count(pool) == 2, "pool count is 2")

    say "      string_pool.lp PASS"
    return 1

// ── 4. Endian Serialization Verification ──────────────────────────────────────

fn test_endian()
    say "[4/9] Testing src/core/endian.lp..."

    assert_true(bswap16(4660) == 13330, "bswap16 0x1234 -> 0x3412")
    assert_true(bswap32(305419896) == 2018915346, "bswap32 0x12345678 -> 0x78563412")
    assert_true(endian_is_host_little() == 1, "host is little-endian")

    mem = alloc(64)
    mem_write_u16_le(mem, 0, 12345)
    assert_true(mem_read_u16_le(mem, 0) == 12345, "mem u16 le roundtrip")

    mem_write_u32_le(mem, 8, 987654321)
    assert_true(mem_read_u32_le(mem, 8) == 987654321, "mem u32 le roundtrip")

    mem_write_u32_be(mem, 16, 987654321)
    assert_true(mem_read_u32_be(mem, 16) == 987654321, "mem u32 be roundtrip")

    free(mem, 64)
    say "      endian.lp PASS"
    return 1

// ── 5. Buffer Verification ────────────────────────────────────────────────────

fn test_buffer()
    say "[5/9] Testing src/core/buffer.lp..."

    buf = buffer_new(16)
    buffer_write_u8(buf, 65)
    buffer_write_u16_le(buf, 4660)
    buffer_write_u32_le(buf, 305419896)
    buffer_write_string(buf, "LIPI")

    // Test ULEB128: 624485 encodes into 3 bytes [229, 142, 38]
    u_bytes = buffer_write_uleb128(buf, 624485)
    assert_true(u_bytes == 3, "ULEB128 wrote 3 bytes")

    // Test buffer alignment padding to 8 bytes
    pad = buffer_align_to(buf, 8)
    assert_true((buffer_len(buf) % 8) == 0, "buffer is 8-byte aligned")

    assert_true(buffer_read_u8(buf, 0) == 65, "read u8 at 0 is 65 ('A')")
    buffer_set_u8(buf, 0, 66)
    assert_true(buffer_read_u8(buf, 0) == 66, "patched u8 at 0 is 66 ('B')")

    buffer_free(buf)
    say "      buffer.lp PASS"
    return 1

// ── 6. Arena Allocator Verification ───────────────────────────────────────────

fn test_arena()
    say "[6/9] Testing src/core/arena.lp..."

    a = arena_new(4096)
    // Allocate with strict 64-byte hardware cacheline alignment
    p1 = arena_alloc_cacheline(a, 64)
    assert_true((p1 % 64) == 0, "p1 is 64-byte cacheline aligned")

    p2 = arena_alloc_cacheline(a, 128)
    assert_true((p2 % 64) == 0, "p2 is 64-byte cacheline aligned")

    mem_write(p1, 0, 88889999)
    assert_true(mem_read(p1, 0) == 88889999, "read stored value in arena p1")

    // O(1) bulk reset
    arena_reset(a)
    assert_true(arena_alloc_count(a) == 0, "arena reset alloc count to 0")

    p3 = arena_alloc_cacheline(a, 64)
    assert_true((p3 % 64) == 0, "p3 is 64-byte cacheline aligned after reset")

    arena_destroy(a)
    say "      arena.lp PASS"
    return 1

// ── 7. Slab Allocator Verification ───────────────────────────────────────────

fn test_slab()
    say "[7/9] Testing src/core/slab.lp..."

    pool = slab_pool_new(64, 32)
    o1 = slab_alloc(pool)
    o2 = slab_alloc(pool)

    assert_true(o1 != 0, "o1 alloc non-zero")
    assert_true(o2 != 0, "o2 alloc non-zero")
    assert_true(o1 != o2, "o1 and o2 are distinct slots")
    assert_true(slab_pool_active_count(pool) == 2, "2 active slots")

    // Free o1 and verify instant intrusive freelist reuse
    slab_free(pool, o1)
    assert_true(slab_pool_active_count(pool) == 1, "1 active slot after free")

    o3 = slab_alloc(pool)
    assert_true(o3 == o1, "o3 reuses freed slot o1 in O(1) time")

    slab_pool_destroy(pool)
    say "      slab.lp PASS"
    return 1

// ── 8. Hashmap Verification ───────────────────────────────────────────────────

fn test_hashmap()
    say "[8/9] Testing src/core/hashmap.lp..."

    m = map_new(16)
    map_insert(m, "compiler", 101)
    map_insert(m, "optimizer", 202)
    map_insert(m, "emitter", 303)
    map_insert(m, 404, 888) // Integer key

    assert_true(map_get(m, "compiler", 0) == 101, "get compiler")
    assert_true(map_get(m, "optimizer", 0) == 202, "get optimizer")
    assert_true(map_get(m, "emitter", 0) == 303, "get emitter")
    assert_true(map_get(m, 404, 0) == 888, "get integer key 404")

    // Early exit lookup for non-existent key
    assert_true(map_get(m, "not_present", 0 - 1) == (0 - 1), "early exit for missing key")

    // Overwrite existing key
    map_insert(m, "compiler", 999)
    assert_true(map_get(m, "compiler", 0) == 999, "overwritten compiler is 999")

    // Backward-shift deletion
    assert_true(map_remove(m, "optimizer") == 1, "removed optimizer")
    assert_true(map_has(m, "optimizer") == 0, "has optimizer is 0")
    assert_true(map_get(m, "emitter", 0) == 303, "emitter still found after backward shift")
    assert_true(map_count(m) == 3, "map count is 3")

    say "      hashmap.lp PASS"
    return 1

// ── 9. BitSet Verification ────────────────────────────────────────────────────

fn test_bitset()
    say "[9/9] Testing src/core/bitset.lp..."

    bs1 = bitset_new(128)
    bs2 = bitset_new(128)

    bitset_set(bs1, 5)
    bitset_set(bs1, 70)

    assert_true(bitset_test(bs1, 5) == 1, "bit 5 is set")
    assert_true(bitset_test(bs1, 70) == 1, "bit 70 is set")
    assert_true(bitset_test(bs1, 6) == 0, "bit 6 is cleared")
    assert_true(bitset_popcount(bs1) == 2, "popcount of bs1 is 2")
    assert_true(bitset_find_first_set(bs1) == 5, "find_first_set is 5")

    bitset_set(bs2, 5)
    bitset_set(bs2, 10)

    // Union: {5, 70} ∪ {5, 10} = {5, 10, 70}
    bs_u = bitset_clone(bs1)
    bitset_union(bs_u, bs2)
    assert_true(bitset_popcount(bs_u) == 3, "union popcount is 3")

    // Intersection: {5, 70} ∩ {5, 10} = {5}
    bs_i = bitset_clone(bs1)
    bitset_intersect(bs_i, bs2)
    assert_true(bitset_popcount(bs_i) == 1, "intersect popcount is 1")
    assert_true(bitset_test(bs_i, 5) == 1, "intersect contains 5")

    // Difference: {5, 70} \ {5, 10} = {70}
    bs_d = bitset_clone(bs1)
    bitset_difference(bs_d, bs2)
    assert_true(bitset_popcount(bs_d) == 1, "difference popcount is 1")
    assert_true(bitset_test(bs_d, 70) == 1, "difference contains 70")

    say "      bitset.lp PASS"
    return 1

// ── Main Verification Probe Orchestrator ──────────────────────────────────────

fn main()
    say "=================================================================="
    say "👑 LIPI FIRST 1.0.0 CORE SILICON PRIMITIVES VERIFICATION PROBE"
    say "⚡ Freestanding Zero-Dependency Silicon Subsystem Test Suite"
    say "=================================================================="

    test_types()
    test_span()
    test_string_pool()
    test_endian()
    test_buffer()
    test_arena()
    test_slab()
    test_hashmap()
    test_bitset()

    say "=================================================================="
    say "✔ ALL 9 CORE SILICON PRIMITIVE MODULES VERIFIED WITH ZERO ERRORS!"
    say "=================================================================="
    return 0
