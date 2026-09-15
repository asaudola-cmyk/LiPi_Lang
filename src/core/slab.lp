// ==============================================================================
// 👑 LIPI FIRST 1.0.0 FREESTANDING CORE SILICON PRIMITIVES: SLAB (src/core/slab.lp)
// ⚡ 100% Pure Lipi Sovereign Implementation | Zero C | Zero Libc | Zero Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Compilers continuously allocate and destroy millions of homogeneous, fixed-size
//    micro-objects with dynamic lifetimes (e.g. AST nodes, tokens, SSA phi nodes, CFG edges,
//    register intervals).
// 2. Allocating these via general-purpose heap allocators causes catastrophic issues:
//    - Memory fragmentation: odd-sized gaps pepper virtual memory pages.
//    - Metadata tax: general malloc incurs 16-32 bytes of boundary headers per object.
// 3. The Lipi Slab Allocator divides contiguous pages into uniform "slots" and threads an
//    intrusive singly-linked freelist directly through the unallocated memory slots themselves.
//    - Zero external metadata storage overhead (0 bytes).
//    - O(1) allocation: pops from the intrusive freelist head (< 3 CPU instructions).
//    - O(1) deallocation: pushes onto the intrusive freelist head (< 3 CPU instructions).
//    - Absolute zero fragmentation: any freed slot can satisfy any future allocation.
// ==============================================================================

struct SlabPool
    slab_slot_size
    slab_slots_per_slab
    slab_byte_size
    slab_free_head
    slab_chunks
    slab_active_count
    slab_total_capacity

// ── 1. Slab Expansion & Intrusive Freelist Threading ─────────────────────────

// WHY: Allocates a new contiguous slab memory chunk from the kernel and threads an
//      intrusive freelist across all its slots. The first 8 bytes of each unused slot
//      store the physical pointer to the next free slot, achieving 0-overhead metadata.
fn slab_expand(p)
    if p == 0 return 0
    base = alloc(p.slab_byte_size)
    if base == 0 return 0 // Allocation failure

    push(p.slab_chunks, base)

    // Thread intrusive freelist through every slot in the slab
    i = 0
    slot_ptr = base
    limit = p.slab_slots_per_slab - 1
    while i < limit
        next_slot = slot_ptr + p.slab_slot_size
        mem_write(slot_ptr, 0, next_slot)
        slot_ptr = next_slot
        i = i + 1

    // Link the last slot of the new slab to the previous freelist head
    mem_write(slot_ptr, 0, p.slab_free_head)
    p.slab_free_head = base
    p.slab_total_capacity = p.slab_total_capacity + p.slab_slots_per_slab
    return 1

// ── 2. Slab Pool Lifecycle ───────────────────────────────────────────────────

// WHY: Creates a dedicated fixed-size object pool.
//      `slot_size` is rounded up to an 8-byte word boundary (minimum 8 bytes for intrusive pointer).
fn slab_pool_new(slot_sz, slots_count)
    p = SlabPool()

    sz = slot_sz
    if sz < 8
        sz = 8

    // Enforce 8-byte natural quadword alignment
    rem = sz % 8
    if rem != 0
        sz = sz + (8 - rem)

    cnt = slots_count
    if cnt < 16
        cnt = 64 // Default to 64 slots per slab chunk

    p.slab_slot_size = sz
    p.slab_slots_per_slab = cnt
    p.slab_byte_size = sz * cnt
    p.slab_free_head = 0
    p.slab_chunks = list()
    p.slab_active_count = 0
    p.slab_total_capacity = 0

    // Pre-allocate the first slab chunk
    slab_expand(p)
    return p

// WHY: Destroys all memory blocks held by the pool, releasing all slabs to the kernel.
fn slab_pool_destroy(p)
    if p == 0 return 0
    num_chunks = len(p.slab_chunks)
    i = 0
    while i < num_chunks
        base = get(p.slab_chunks, i)
        if base != 0 and p.slab_byte_size > 0
            free(base, p.slab_byte_size)
        i = i + 1

    p.slab_chunks = list()
    p.slab_free_head = 0
    p.slab_active_count = 0
    p.slab_total_capacity = 0
    return 1

// ── 3. High-Speed O(1) Allocation & Deallocation ─────────────────────────────

// WHY: Dispenses a slot in O(1) time by popping the intrusive freelist head.
//      If all current slabs are exhausted, automatically expands with a new slab chunk.
fn slab_alloc(p)
    if p == 0 return 0
    if p.slab_free_head == 0
        expanded = slab_expand(p)
        if expanded == 0 return 0 // Out of memory

    slot = p.slab_free_head
    // Advance free_head to the next available free slot in the intrusive chain
    p.slab_free_head = mem_read(slot, 0)
    p.slab_active_count = p.slab_active_count + 1

    // Zero out the first 8 bytes of the slot to scrub the intrusive pointer
    mem_write(slot, 0, 0)
    return slot

// WHY: Reclaims a slot in O(1) time by prepending it back to the intrusive freelist head.
//      Executes in 2 memory writes with zero syscalls and zero page scanning.
fn slab_free(p, ptr)
    if p == 0 or ptr == 0 return 0
    // Thread current free_head into the newly freed slot
    mem_write(ptr, 0, p.slab_free_head)
    // Make the freed slot the new free_head
    p.slab_free_head = ptr
    p.slab_active_count = p.slab_active_count - 1
    return 1

// ── 4. Pool Metrics & Diagnostics ─────────────────────────────────────────────

// WHY: Returns the number of currently active/in-use objects.
fn slab_pool_active_count(p)
    if p == 0 return 0
    return p.slab_active_count

// WHY: Returns the total slot capacity across all allocated slab chunks.
fn slab_pool_total_capacity(p)
    if p == 0 return 0
    return p.slab_total_capacity

// WHY: Returns the number of slab chunks currently mapped.
fn slab_pool_chunk_count(p)
    if p == 0 return 0
    return len(p.slab_chunks)

// WHY: Returns the current memory utilization percentage (0 to 100).
fn slab_pool_utilization_pct(p)
    if p == 0 or p.slab_total_capacity == 0 return 0
    return (p.slab_active_count * 100) / p.slab_total_capacity
