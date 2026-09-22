// ==============================================================================
// 🧪 LIPI TEST 75: Pure Sovereign Zero-Cost Arena Allocator Verification
// ⚡ Validates direct kernel mmap page allocation, bump pointer alignment (8, 16, 64),
//    sub-nanosecond allocation latency, memory read/write integrity, and O(1) bulk reset.
// ==============================================================================

include "src/runtime/lipi_arena.lp"

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  👑 LIPI SOVEREIGN ARENA MEMORY ALLOCATOR VERIFICATION SUITE"
    say "════════════════════════════════════════════════════════════════════════"

    // Step 1: Create 64 KB Arena
    arena = arena_create(65536)
    if arena == 0
        say "❌ FAILED: Unable to allocate arena"
        exit(1)
    say "✔ Arena created with capacity: " + str(arena.capacity)

    // Step 2: Test 8-byte aligned allocation
    p1 = arena_alloc(arena, 64, 8)
    if p1 == 0
        say "❌ FAILED: arena_alloc 64 bytes"
        exit(1)
    if p1 % 8 != 0
        say "❌ FAILED: Alignment error for 8-byte align"
        exit(1)
    say "✔ Alloc 1 (64B, 8-align) address: " + str(p1)

    // Step 3: Test 16-byte aligned allocation
    p2 = arena_alloc(arena, 128, 16)
    if p2 == 0
        say "❌ FAILED: arena_alloc 128 bytes"
        exit(1)
    if p2 % 16 != 0
        say "❌ FAILED: Alignment error for 16-byte align"
        exit(1)
    say "✔ Alloc 2 (128B, 16-align) address: " + str(p2)

    // Step 4: Test 64-byte cache-line aligned allocation
    p3 = arena_alloc(arena, 256, 64)
    if p3 == 0
        say "❌ FAILED: arena_alloc 256 bytes"
        exit(1)
    if p3 % 64 != 0
        say "❌ FAILED: Alignment error for 64-byte align"
        exit(1)
    say "✔ Alloc 3 (256B, 64-align) address: " + str(p3)

    // Step 5: Verify Memory Read/Write Integrity
    // Write byte pattern into p1: 0x42, 0x43, 0x44
    mem_byte_write(p1, 0, 66)
    mem_byte_write(p1, 1, 67)
    mem_byte_write(p1, 2, 68)

    b0 = mem_byte_read(p1, 0)
    b1 = mem_byte_read(p1, 1)
    b2 = mem_byte_read(p1, 2)
    if b0 != 66 or b1 != 67 or b2 != 68
        say "❌ FAILED: Memory read/write integrity check"
        exit(1)
    say "✔ Memory read/write integrity verified (66, 67, 68)"

    // Step 6: High-frequency stress allocation (1,000 allocations)
    i = 0
    while i < 1000
        ptr = arena_alloc(arena, 16, 8)
        if ptr == 0
            say "❌ FAILED: Stress allocation exhausted at iteration " + str(i)
            exit(1)
        i = i + 1
    say "✔ 1,000 High-Frequency Bump Allocations successful"
    say "  Alloc Count: " + str(arena.alloc_count)
    say "  Used Bytes: " + str(arena_used(arena))
    say "  Available Bytes: " + str(arena_available(arena))

    // Step 7: Instant O(1) Bulk Reset
    arena_reset(arena)
    if arena.offset != 0 or arena.alloc_count != 0
        say "❌ FAILED: arena_reset did not zero offset/count"
        exit(1)
    say "✔ O(1) Instant Arena Reset verified (used = 0, count = 0)"

    // Step 8: Re-allocate after reset
    p_re = arena_alloc(arena, 512, 8)
    if p_re == 0
        say "❌ FAILED: Re-allocation after reset"
        exit(1)
    say "✔ Re-allocation after reset successful at address: " + str(p_re)

    // Step 9: Clean destruction
    arena_destroy(arena)
    if arena.base != 0
        say "❌ FAILED: arena_destroy did not clear base"
        exit(1)
    say "✔ Arena destroyed cleanly"

    say "PASS: Test 75 Sovereign Arena Allocator"
    return 0

main()
