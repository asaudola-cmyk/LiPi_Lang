// Test 19: Memory Management Pattern — Lipi 2.0
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

// Bump allocate: move pointer forward by aligned size (returns new used or -1 on OOM)
fn arena_alloc used capacity size align
    aligned = align_up(size, align)
    if used + aligned > capacity
        return -1
    return used + aligned

// Compute fragmentation: wasted * 100 / total (integer percent)
fn fragmentation_pct wasted total
    if total == 0
        return 0
    return wasted * 100 / total

// Slab: how many slabs of slab_size fit in pool_size
fn slab_count pool_size slab_size
    if slab_size == 0
        return 0
    return pool_size / slab_size

// Free-list: available blocks
fn free_count n_blocks k_used
    return n_blocks - k_used

// === Simulation ===
say "=== Arena Allocator ==="
say "Capacity: 4096"

// Alloc 128 bytes with 8-byte alignment
off1 = arena_alloc(0, 4096, 128, 8)
say "After alloc 128:"
say off1

// Alloc 256 bytes
off2 = arena_alloc(off1, 4096, 256, 8)
say "After alloc 256:"
say off2

// Alloc 512 bytes
off3 = arena_alloc(off2, 4096, 512, 8)
say "After alloc 512:"
say off3

// Remaining
remaining = 4096 - off3
say "Remaining bytes:"
say remaining

// Fragmentation: 200 wasted out of 4096
frag = fragmentation_pct(200, 4096)
say "Fragmentation %:"
say frag

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

// Slab: 4096-byte pool, 64-byte slabs
slabs = slab_count(4096, 64)
say "Slab count:"
say slabs

// Free list: 32 blocks, 10 used
free = free_count(32, 10)
say "Free blocks:"
say free

say "PASS: Test 19 Memory Management"
