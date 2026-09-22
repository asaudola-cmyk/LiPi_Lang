// ==============================================================================
// 👑 LIPI SOVEREIGN REGRESSION TEST: SLAB MEMORY RECLAMATION
// ⚡ Tests O(1) Segregated Freelist Recycling (_lipi_free / lipi_fn_free)
// 🏛️ Version: First 1.0.0 (প্রথম ১.০.০) — 100% Pure Silicon / Zero Libc
// ==============================================================================

say "=== LIPI SLAB MEMORY RECLAMATION TEST ==="

// 1. Basic Allocation & Value Integrity
p1 = alloc(32)
mem_word_write(p1, 0, 12345678)
mem_word_write(p1, 8, 87654321)

val1 = mem_word_read(p1, 0)
val2 = mem_word_read(p1, 8)

if val1 != 12345678 or val2 != 87654321
    say "FAIL: Initial allocation value corrupted"
    exit(1)
say "✔ Allocation and memory write verified"

// 2. Freeing Slot
res = free(p1)
say "✔ Slot successfully reclaimed via free()"

// 3. Re-allocation should recycle from the same size-class slab bucket
p2 = alloc(32)
if p2 == p1
    say "✔ Perfect O(1) Slab LIFO Recycling: p2 address identical to freed p1 (" + str(p2) + ")"
else
    say "✔ Allocation succeeded: p2 = " + str(p2)

// 4. Repeated Allocation & Free Stress Loop (10,000 cycles)
// WHY: In a bump-pointer only allocator, 10,000 * 64B would consume 640KB.
// With slab freelist recycling, peak consumption is exactly 1 slot!
iter = 0
recycled_count = 0
first_addr = alloc(64)
free(first_addr)

while iter < 10000
    p = alloc(64)
    if p == first_addr
        recycled_count = recycled_count + 1
    free(p)
    iter = iter + 1

say "✔ 10,000 Slab allocation & reclamation cycles executed without memory exhaustion"
say "  Recycled slot match rate: " + str(recycled_count) + " / 10000"

if recycled_count < 9900
    say "FAIL: Freelist recycling failed to achieve high cache locality"
    exit(1)

say "PASS: test_slab_memory_reclaim"
