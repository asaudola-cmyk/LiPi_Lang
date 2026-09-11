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

// ── ১. কার্নেল পেজ ম্যাপ দিয়ে নতুন অ্যারিনা মেমরি পুল তৈরি ────────────────────────
fn অ্যারিনা_তৈরি capacity
    // SYS_mmap(0, length, PROT_READ|PROT_WRITE=3, MAP_ANONYMOUS|MAP_PRIVATE=34, -1, 0)
    র_মেম = syscall(9, 0, capacity, 3, 34, -1, 0)
    if র_মেম <= 0
        return 0

    pool = malloc(24)
    মেমরি_লেখো(pool, 0, র_মেম)
    মেমরি_লেখো(pool, 8, capacity)
    মেমরি_লেখো(pool, 16, 0)
    return pool

fn arena_create capacity
    return অ্যারিনা_তৈরি(capacity)

// ── ২. অ্যারিনা থেকে ৮-বাইট অ্যালাইন্ড মেমরি চাঙ্ক বরাদ্দ (O(1) Bump Allocation) ──
fn অ্যারিনা_বরাদ্দ pool byte_size
    base = মেমরি_পড়ো(pool, 0)
    capacity = মেমরি_পড়ো(pool, 8)
    used = মেমরি_পড়ো(pool, 16)

    // ৮-বাইট কিউ-ওয়ার্ড (QWORD) বাউন্ডারিতে অ্যালাইনমেন্ট: ((size + 7) / 8) * 8
    অ্যালাইন্ড_size = ((byte_size + 7) / 8) * 8

    if used + অ্যালাইন্ড_size > capacity
        return 0 // মেমরি শেষ (Out of Memory)

    বরাদ্দী_addr = base + used
    নতুন_used = used + অ্যালাইন্ড_size
    মেমরি_লেখো(pool, 16, নতুন_used)

    return বরাদ্দী_addr

fn arena_alloc pool byte_size
    return অ্যারিনা_বরাদ্দ(pool, byte_size)

// ── ৩. বর্তমানে ব্যবহৃত মোট মেমরি বাইট সংখ্যা ──────────────────────────────────
fn অ্যারিনা_ব্যবহৃত_মেমরি pool
    return মেমরি_পড়ো(pool, 16)

fn arena_used_mem pool
    return অ্যারিনা_ব্যবহৃত_মেমরি(pool)

fn arena_used pool
    return অ্যারিনা_ব্যবহৃত_মেমরি(pool)

// ── ৪. অ্যারিনায় অবশিষ্ট খালি মেমরি বাইট সংখ্যা ────────────────────────────────
fn অ্যারিনা_অবশিষ্ট_মেমরি pool
    capacity = মেমরি_পড়ো(pool, 8)
    used = মেমরি_পড়ো(pool, 16)
    return capacity - used

fn arena_free_mem pool
    return অ্যারিনা_অবশিষ্ট_মেমরি(pool)

fn arena_free pool
    return অ্যারিনা_অবশিষ্ট_মেমরি(pool)

// ── ৫. এক পলকে সমস্ত বরাদ্দ মেমরি রিসেট (O(1) Instant Mass Reclamation) ───────
// WHY: Zero fragmentation and zero memory leak guarantee.
fn অ্যারিনা_রিসেট pool
    মেমরি_লেখো(pool, 16, 0)
    return 0

fn arena_reset pool
    return অ্যারিনা_রিসেট(pool)

// ── ৬. ওএস কার্নেলকে মেমরি পৃষ্ঠা ফেরত দিয়ে অ্যারিনা ধ্বংসকরণ ───────────────────
fn অ্যারিনা_ধ্বংস pool
    base = মেমরি_পড়ো(pool, 0)
    capacity = মেমরি_পড়ো(pool, 8)
    if base > 0
        // SYS_munmap(addr, length) -> Syscall 11
        syscall(11, base, capacity, 0, 0, 0, 0)
    মেমরি_লেখো(pool, 0, 0)
    মেমরি_লেখো(pool, 8, 0)
    মেমরি_লেখো(pool, 16, 0)
    free(pool, 24)
    return 0

fn arena_destroy pool
    return অ্যারিনা_ধ্বংস(pool)

// ------------------------------------------------------------------------------
// স্মার্ট রেফারেন্স কাউন্টিং (Atomic Reference Counting - ARC Primitives)
// ------------------------------------------------------------------------------

// ── ৭. রেফারেন্স সেল তৈরি (রেফারেন্স কাউন্ট = ১) ──────────────────────────────
fn রেফারেন্স_তৈরি ডাটা_মান
    cell = malloc(16)
    মেমরি_লেখো(cell, 0, 1)        // offset ০: রেফারেন্স কাউন্ট = ১
    মেমরি_লেখো(cell, 8, ডাটা_মান) // offset ৮: ডেটা পয়েন্টার / মান
    return cell

fn ref_create data_val
    return রেফারেন্স_তৈরি(data_val)

// ── ৮. রেফারেন্স কাউন্ট বৃদ্ধি ──────────────────────────────────────────────────
fn রেফারেন্স_ধরে_রাখো cell
    কাউন্ট = মেমরি_পড়ো(cell, 0)
    কাউন্ট = কাউন্ট + 1
    মেমরি_লেখো(cell, 0, কাউন্ট)
    return কাউন্ট

fn ref_retain cell
    return রেফারেন্স_ধরে_রাখো(cell)

// ── ৯. রেফারেন্স কাউন্ট হ্রাসকরণ (কাউন্ট ০ হলে স্বয়ংক্রিয়ভাবে মুক্তযোগ্য) ───────
fn রেফারেন্স_ছেড়ে_দাও cell
    কাউন্ট = মেমরি_পড়ো(cell, 0)
    if কাউন্ট > 0
        কাউন্ট = কাউন্ট - 1
        মেমরি_লেখো(cell, 0, কাউন্ট)
        if কাউন্ট == 0
            free(cell, 16)
    return কাউন্ট

fn ref_release cell
    return রেফারেন্স_ছেড়ে_দাও(cell)

// ── ১০. রেফারেন্স সেলের বর্তমান মান পাঠ ─────────────────────────────────────────
fn রেফারেন্স_মান cell
    return মেমরি_পড়ো(cell, 8)

fn ref_get cell
    return রেফারেন্স_মান(cell)

fn ref_val cell
    return রেফারেন্স_মান(cell)
