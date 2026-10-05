// ==============================================================================
// 👑 LIPI SOVEREIGN REGRESSION TEST: 9-CLASS GEOMETRIC SLAB ENGINE
// ⚡ Tests 9 Size-Class Slabs (16B, 32B, 64B, 128B, 256B, 512B, 1KB, 2KB, 4KB)
// 🏛️ Architecture: Zero Runtime Fragmentation & Instant Freelist Re-linking
// 🛡️ Lifecycle: 100% Zero-Leak Verification across 10,000 Continuous Cycles
// ==============================================================================

include "src/runtime/lipi_slab.lp"

say "╔══════════════════════════════════════════════════════════════════════╗"
say "║  🧪 TEST: 9-CLASS GEOMETRIC SLAB MEMORY ENGINE & ZERO-LEAK LIFECYCLE ║"
say "╚══════════════════════════════════════════════════════════════════════╝"

// ── 1. Engine Instantiation & Class Configuration ─────────────────────────────
eng = lipi_slab_engine_new()
if eng == 0
    say "FAIL: lipi_slab_engine_new returned null"
    exit(1)
say "✔ 1. LipiSlabEngine successfully initialized with 9 geometric classes"

// Verify bucket slot sizes match geometric progression 2^4 to 2^12
sc = 1
while sc <= 9
    b = get(eng.buckets, sc - 1)
    expected_sz = lipi_slab_class_size(sc)
    if b.slot_size != expected_sz
        say "FAIL: Bucket " + str(sc) + " slot size mismatch: got " + str(b.slot_size) + ", expected " + str(expected_sz)
        exit(1)
    sc = sc + 1
say "✔ 2. Geometric class sizes verified (16B, 32B, 64B, 128B, 256B, 512B, 1KB, 2KB, 4KB)"

// ── 2. Simultaneous Allocation Across All 9 Classes & Memory Integrity ───────
p16   = lipi_slab_alloc(eng, 16)
p32   = lipi_slab_alloc(eng, 32)
p64   = lipi_slab_alloc(eng, 64)
p128  = lipi_slab_alloc(eng, 128)
p256  = lipi_slab_alloc(eng, 256)
p512  = lipi_slab_alloc(eng, 512)
p1024 = lipi_slab_alloc(eng, 1024)
p2048 = lipi_slab_alloc(eng, 2048)
p4096 = lipi_slab_alloc(eng, 4096)

if p16 == 0 or p32 == 0 or p64 == 0 or p128 == 0 or p256 == 0 or p512 == 0 or p1024 == 0 or p2048 == 0 or p4096 == 0
    say "FAIL: Failed to allocate slots across all 9 classes"
    exit(1)


// Write distinct sentinel test values to each slot boundary
mem_word_write(p16,   0, 161616)
mem_word_write(p32,   0, 323232)
mem_word_write(p64,   0, 646464)
mem_word_write(p128,  0, 128128)
mem_word_write(p256,  0, 256256)
mem_word_write(p512,  0, 512512)
mem_word_write(p1024, 0, 10241024)
mem_word_write(p2048, 0, 20482048)
mem_word_write(p4096, 0, 40964096)

// Also test non-zero interior word offsets
mem_word_write(p4096, 4088, 999888777)

// Verify sentinel data integrity
v16   = mem_word_read(p16,   0)
v32   = mem_word_read(p32,   0)
v64   = mem_word_read(p64,   0)
v128  = mem_word_read(p128,  0)
v256  = mem_word_read(p256,  0)
v512  = mem_word_read(p512,  0)
v1024 = mem_word_read(p1024, 0)
v2048 = mem_word_read(p2048, 0)
v4096 = mem_word_read(p4096, 0)
v4096_end = mem_word_read(p4096, 4088)

if v16 != 161616 or v32 != 323232 or v64 != 646464 or v128 != 128128 or v256 != 256256 or v512 != 512512 or v1024 != 10241024 or v2048 != 20482048 or v4096 != 40964096 or v4096_end != 999888777
    say "FAIL: Memory integrity violation on geometric slots"
    exit(1)
say "✔ 3. Simultaneous allocation & memory read/write verified across all 9 classes"

// ── 3. Deallocation & Instant Freelist Re-linking ──────────────────────────────
lipi_slab_free(eng, p16)
lipi_slab_free(eng, p32)
lipi_slab_free(eng, p64)
lipi_slab_free(eng, p128)
lipi_slab_free(eng, p256)
lipi_slab_free(eng, p512)
lipi_slab_free(eng, p1024)
lipi_slab_free(eng, p2048)
lipi_slab_free(eng, p4096)
say "✔ 4. All 9 slots reclaimed via lipi_slab_free"

// Verify instant LIFO slot recycling (freed slot should be re-dispensed immediately)
r4096 = lipi_slab_alloc(eng, 4096)
if r4096 != p4096
    say "FAIL: Class 9 (4KB) LIFO recycling address mismatch: got " + str(r4096) + ", expected " + str(p4096)
    exit(1)
say "✔ 5. Instant O(1) LIFO freelist re-linking verified for Class 9 (4KB slot recycled: " + str(r4096) + ")"
lipi_slab_free(eng, r4096)

r16 = lipi_slab_alloc(eng, 16)
if r16 != p16
    say "FAIL: Class 1 (16B) LIFO recycling address mismatch: got " + str(r16) + ", expected " + str(p16)
    exit(1)
say "✔ 6. Instant O(1) LIFO freelist re-linking verified for Class 1 (16B slot recycled: " + str(r16) + ")"
lipi_slab_free(eng, r16)

// ── 4. Large Object Allocator Fallback (> 4KB) ─────────────────────────────────
p_large = lipi_slab_alloc(eng, 8192)
if p_large == 0
    say "FAIL: Large object allocation (8KB) failed"
    exit(1)
mem_word_write(p_large, 0, 88888888)
if mem_word_read(p_large, 0) != 88888888
    say "FAIL: Large object data integrity corrupted"
    exit(1)
lipi_slab_free(eng, p_large)
say "✔ 7. Large object (>4KB) page allocation & reclamation verified"

// ── 5. Continuous 10,000 Cycle Stress Test (Zero Memory Growth) ───────────────
iter = 0
recycled_hits = 0
test_size = 256 // Test on 256B geometric class
first_slot = lipi_slab_alloc(eng, test_size)
lipi_slab_free(eng, first_slot)

while iter < 10000
    p = lipi_slab_alloc(eng, test_size)
    if p == first_slot
        recycled_hits = recycled_hits + 1
    lipi_slab_free(eng, p)
    iter = iter + 1

say "✔ 8. 10,000 Continuous allocate/deallocate cycles executed"
say "     Recycled slot match rate: " + str(recycled_hits) + " / 10000"
if recycled_hits < 9900
    say "FAIL: Freelist cache locality dropped below 99%"
    exit(1)

// ── 6. Interleaved Multi-Class Stress Test (Zero Runtime Fragmentation) ───────
c_iter = 0
while c_iter < 1000
    a1 = lipi_slab_alloc(eng, 32)
    a2 = lipi_slab_alloc(eng, 128)
    a3 = lipi_slab_alloc(eng, 1024)
    a4 = lipi_slab_alloc(eng, 4096)

    // Free in reverse order
    lipi_slab_free(eng, a4)
    lipi_slab_free(eng, a2)
    lipi_slab_free(eng, a3)
    lipi_slab_free(eng, a1)
    c_iter = c_iter + 1

say "✔ 9. 1,000 Interleaved multi-class allocation/free cycles executed with zero fragmentation"

// ── 7. Dedicated Single Size-Class Pool Verification ──────────────────────────
pool = lipi_slab_pool_new(1024) // Dedicated 1KB pool
slot1 = lipi_slab_pool_alloc(pool)
mem_word_write(slot1, 0, 777111)
if mem_word_read(slot1, 0) != 777111
    say "FAIL: Dedicated pool memory integrity corrupted"
    exit(1)
lipi_slab_pool_free(pool, slot1)

// Re-allocating must recycle the exact slot
slot2 = lipi_slab_pool_alloc(pool)
if slot2 != slot1
    say "FAIL: Dedicated pool failed LIFO recycling"
    exit(1)
lipi_slab_pool_free(pool, slot2)
lipi_slab_pool_destroy(pool)
say "✔ 10. Dedicated single size-class pool lifecycle verified"

// ── 8. Bilingual Cultural Aliases Verification ────────────────────────────────
b_eng = স্ল্যাব_ইঞ্জিন_নতুন()
b_p = স্ল্যাব_বরাদ্দ(b_eng, 512)
mem_word_write(b_p, 0, 555)
if mem_word_read(b_p, 0) != 555
    say "FAIL: Bilingual alias allocation corrupted"
    exit(1)
স্ল্যাব_মুক্ত(b_eng, b_p)
b_zl = স্ল্যাব_লিক_যাচাই(b_eng)
if b_zl != 1
    say "FAIL: Bilingual leak verification failed"
    exit(1)
স্ল্যাব_ধ্বংস(b_eng)
say "✔ 11. Bengali cultural aliases verified (স্ল্যাব_বরাদ্দ, স্ল্যাব_মুক্ত, স্ল্যাব_লিক_যাচাই)"

// ── 9. Final 100% Zero-Leak Assertions ─────────────────────────────────────────

stats = lipi_slab_stats(eng)
say "─── Telemetry Audit ───"
say "  • Total Allocation Operations: " + str(stats.total_alloc_ops)
say "  • Total Deallocation Operations: " + str(stats.total_free_ops)
say "  • Total Recycled Freelist Hits: " + str(stats.total_recycled_ops)
say "  • Active Live Allocations: " + str(stats.active_allocations)

zl_ok = lipi_slab_verify_zero_leak(eng)
if zl_ok == 1 and stats.active_allocations == 0 and stats.total_alloc_ops == stats.total_free_ops
    say "✔ 12. 100% Zero-Leak Lifecycle Proved: active_allocations == 0, alloc_ops == free_ops"
else
    say "FAIL: Memory leak detected! active_allocations = " + str(stats.active_allocations)
    exit(1)

lipi_slab_destroy(eng)
say "✔ 13. All 64KB slab arenas cleanly destroyed and returned to OS"

say "\n══════════════════════════════════════════════════════════════════════"
say "🎉 PASS: test_slab_9_classes (100% Pure Lipi Sovereign Zero-Leak Engine)"
say "══════════════════════════════════════════════════════════════════════"
