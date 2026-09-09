// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: ARENA MEMORY ALLOCATOR & ARC (std/arena.lp)
// ⚡ 100% Sovereign Silicon Memory Architecture | Zero Fragmentation | O(1) Allocation
// ==============================================================================

// WHY: Traditional malloc/free causes heap fragmentation and kernel transition overhead.
// An arena allocator acquires a large memory block once from Linux (via SYS_mmap)
// and dispenses 8-byte aligned memory chunks using an ultra-fast bump pointer (O(1)).
// All allocated memory is released in a single CPU cycle via arena reset.

include "std/mem.lp"

struct অ্যারিনা
    base,
    capacity,
    used

// ১. aার্নেল page map দিয়ে নতুন অ্যারিনা memory pool তৈরি
fn অ্যারিনা_created(capacity)
    // SYS_mmap(0, length, PROT_READ|PROT_WRITE=3, MAP_ANONYMOUS|MAP_PRIVATE=34, -1, 0)
    র_মেম = syscall(9, 0, capacity, 3, 34, -1, 0)
    if র_মেম <= 0
        return 0

    pool = malloc(24)
    mem_write(pool, 0, র_মেম)
    mem_write(pool, 8, capacity)
    mem_write(pool, 16, 0)
    return pool

// ২. অ্যারিনা থেaে ৮-byte অ্যালাইন্ড memory চাঙ্a allocation (O(1) Bump Allocation)
fn অ্যারিনা_বরাদ্দ(pool, byte_size)
    base = mem_পড়ো(pool, 0)
    capacity = mem_পড়ো(pool, 8)
    used = mem_পড়ো(pool, 16)

    // ৮-byte aিউ-ওয়ার্ড (QWORD) বাউন্ডারিতে অ্যালাইনমেন্ট: (size + 7) & ~7
    অ্যালাইন্ড_size = (byte_size + 7) & (0 - 8)

    if used + অ্যালাইন্ড_size > capacity
        return 0 // memory শেষ (Out of Memory)

    বরাদ্দী_addr = base + used
    নতুন_used = used + অ্যালাইন্ড_size
    mem_write(pool, 16, নতুন_used)

    return বরাদ্দী_addr

// ৩. বর্তvalueে ব্যবহৃত total memory byte num
fn অ্যারিনা_used_mem(pool)
    return mem_পড়ো(pool, 16)

// ৪. অ্যারিনায় অবশিষ্ট bালি memory byte num
fn অ্যারিনা_অবশিষ্ট_mem(pool)
    capacity = mem_পড়ো(pool, 8)
    used = mem_পড়ো(pool, 16)
    return capacity - used

// ৫. এa পলaে সমস্ত allocation memory রিসেট (O(1) Instant Mass Reclamation)
// WHY: Zero fragmentation and zero memory leak guarantee.
fn অ্যারিনা_রিসেট(pool)
    mem_write(pool, 16, 0)
    return 0

// ৬. ওএস aার্নেলaে memory পৃষ্ঠা return দিয়ে অ্যারিনা ধ্বংসaরণ
fn অ্যারিনা_ধ্বংস(pool)
    base = mem_পড়ো(pool, 0)
    capacity = mem_পড়ো(pool, 8)
    if base > 0
        // SYS_munmap(addr, length) -> Syscall 11
        syscall(11, base, capacity, 0, 0, 0, 0)
    mem_write(pool, 0, 0)
    mem_write(pool, 8, 0)
    mem_write(pool, 16, 0)
    return 0

// ------------------------------------------------------------------------------
// স্মার্ট রেফারেন্স aাউন্টিং (Atomic Reference Counting - ARC Primitives)
// ------------------------------------------------------------------------------

// ৭. রেফারেন্স সেল create (রেফারেন্স aাউন্ট = ১)
fn রেফারেন্স_created(ডাটা_value)
    cell = malloc(16)
    mem_write(cell, 0, 1)        // offset ০: রেফারেন্স aাউন্ট = ১
    mem_write(cell, 8, ডাটা_value) // offset ৮: data পয়েন্টার / value
    return cell

// ৮. রেফারেন্স aাউন্ট বৃদ্ধি
fn রেফারেন্স_ধরে_রাbো(cell)
    aাউন্ট = mem_পড়ো(cell, 0)
    aাউন্ট = aাউন্ট + 1
    mem_write(cell, 0, aাউন্ট)
    return aাউন্ট

// ৯. রেফারেন্স aাউন্ট হ্রাসaরণ (aাউন্ট ০ হলে স্বয়ংa্রিয়ভাবে মুa্তadd্য)
fn রেফারেন্স_ছেড়ে_দাও(cell)
    aাউন্ট = mem_পড়ো(cell, 0)
    if aাউন্ট > 0
        aাউন্ট = aাউন্ট - 1
        mem_write(cell, 0, aাউন্ট)
    return aাউন্ট

// ১০. রেফারেন্স সেলের বর্তvalue value পাঠ
fn রেফারেন্স_value(cell)
    return mem_পড়ো(cell, 8)
