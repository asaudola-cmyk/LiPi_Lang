// Test 25: Memory Allocator Pattern — Lipi 2.0
// Demonstrates: arena allocator simulation, alignment, fragmentation analysis

struct Arena
    capacity
    used
    alloc_count

// Align size up to the nearest multiple of align
fn align_up size align
    remainder = size % align
    if remainder == 0
        return size
    return size + align - remainder

// Arena alloc: returns new used pointer or -1 on OOM
fn arena_alloc used capacity size align
    aligned = align_up(size, align)
    if used + aligned > capacity
        return -1
    return used + aligned

// Utilization percentage
fn util_pct used capacity
    return used * 100 / capacity

// Free-list allocator simulation
fn freelist_alloc total_blocks used_blocks request_blocks
    free_blocks = total_blocks - used_blocks
    if request_blocks > free_blocks
        return -1
    return used_blocks + request_blocks

// === Arena Simulation ===
say "=== Arena Allocator ==="
say "Capacity: 4096"

// Alloc 1: 128 bytes, 8-byte alignment
off1 = arena_alloc(0, 4096, 128, 8)
say "Alloc 128:"
say off1

// Alloc 2: 256 bytes
off2 = arena_alloc(off1, 4096, 256, 8)
say "Alloc 256:"
say off2

// Alloc 3: 512 bytes
off3 = arena_alloc(off2, 4096, 512, 8)
say "Alloc 512:"
say off3

// Remaining
rem = 4096 - off3
say "Remaining:"
say rem

// Utilization
util = util_pct(off3, 4096)
say "Utilization %:"
say util

// Over-allocation attempt
over = arena_alloc(off3, 4096, 5000, 8)
say "Over-alloc (expect -1):"
say over

// Alignment tests
say "align_up(13, 8) = 16:"
say align_up(13, 8)

say "align_up(16, 8) = 16:"
say align_up(16, 8)

say "align_up(1, 64) = 64:"
say align_up(1, 64)

// Free-list: 32 blocks, 10 used, alloc 5
fl = freelist_alloc(32, 10, 5)
say "Free-list alloc 5 (new used count):"
say fl

// Exhaustion: alloc 30 from 22 free (expect -1)
fl_fail = freelist_alloc(32, 10, 30)
say "Free-list over-alloc (expect -1):"
say fl_fail

say "PASS: Test 25 Memory Allocator"
