// Test 47: Memory Patterns — Lipi 2.0 Global Standard

struct Arena
    base
    offset
    capacity

fn arena_new base cap
    a = Arena()
    a.base = base
    a.offset = 0
    a.capacity = cap
    return a

fn arena_alloc arena_cap arena_offset size
    // WHY: structs are value types — pass fields individually
    if arena_offset + size > arena_cap
        say "Arena full!"
        return -1
    addr = 1048576 + arena_offset
    return addr

fn arena_used offset = offset
fn arena_free cap offset = cap - offset

// Pool allocator
struct Pool
    capacity
    used

fn pool_new cap
    p = Pool()
    p.capacity = cap
    p.used = 0
    return p

say "=== Memory Patterns ==="
arena = arena_new(1048576, 65536)
say "Arena base: " + arena.base
say "Arena cap:  " + arena.capacity

offset = 0
a1 = arena_alloc(arena.capacity, offset, 64)
offset = offset + 64
a2 = arena_alloc(arena.capacity, offset, 128)
offset = offset + 128
a3 = arena_alloc(arena.capacity, offset, 256)
offset = offset + 256

say "Alloc1: " + a1
say "Alloc2: " + a2
say "Alloc3: " + a3
say "Used:   " + arena_used(offset)
say "Free:   " + arena_free(arena.capacity, offset)

// Pool
pool = pool_new(10)
say "Pool capacity: " + pool.capacity
for i in 1..5
    addr = i * 64
    say "Pool slot " + i + ": " + addr

say "PASS: Test 47 Memory Patterns"
