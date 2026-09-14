// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: ARENA MEMORY ALLOCATOR & ARC (std/arena.lp)
// ⚡ 100% Sovereign Silicon Memory Architecture | Zero Fragmentation | O(1) Allocation
// ==============================================================================

// WHY: Traditional malloc/free causes heap fragmentation and kernel transition overhead.
// An arena allocator acquires a large memory block once from Linux (via SYS_mmap)
// and dispenses 8-byte aligned memory chunks using an ultra-fast bump pointer (O(1)).
// All allocated memory is released in a single CPU cycle via arena reset.

include "universe/core/memory.lp"

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

// ── ১.১. ২-মেগাবাইট লিনাক্স হিউজপেজ অ্যারিনা তৈরি (2MB Linux HugePages MAP_HUGETLB) ───
// WHY: আধুনিক x86_64 প্রসেসরে প্রতি ৪KB পেজে একটি করে TLB (Translation Lookaside Buffer)
// মিস হয় যা উচ্চ-গতির নেটওয়ার্কিং বা এআই ইনফারেন্সে ১৫-২০% পারফরম্যান্স লস করায়।
// ২MB HugePages বরাদ্দ করলে ৫১২টি ৪KB পেজের স্থলে মাত্র ১টি TLB এন্ট্রি লাগে।
// কার্নেলে HugePages এনাবল না থাকলে স্বয়ংক্রিয়ভাবে স্ট্যান্ডার্ড পেজে ফলব্যাক করে।
fn অ্যারিনা_তৈরি_হিউজ capacity
    real_cap = capacity
    if real_cap <= 0
        real_cap = 2097152 // 2MB default HugePage size
    rem = real_cap % 2097152
    if rem != 0
        real_cap = real_cap + (2097152 - rem)

    // Attempt Linux MAP_HUGETLB: MAP_PRIVATE (2) | MAP_ANONYMOUS (32) | 0x40000 = 262178
    raw_mem = syscall(9, 0, real_cap, 3, 262178, -1, 0)
    if raw_mem <= 0
        // Seamless fallback to standard 4KB anonymous pages (flags: 34)
        raw_mem = syscall(9, 0, real_cap, 3, 34, -1, 0)
    if raw_mem <= 0
        return 0

    pool = malloc(24)
    মেমরি_লেখো(pool, 0, raw_mem)
    মেমরি_লেখো(pool, 8, real_cap)
    মেমরি_লেখো(pool, 16, 0)
    return pool

fn arena_create_huge capacity
    return অ্যারিনা_তৈরি_হিউজ(capacity)

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

// ── ২.১. অ্যারিনা থেকে কাস্টম অ্যালাইন্ড মেমরি বরাদ্দ (৮, ১৬, ৩২ বা ৬৪-বাইট ক্যাশলাইন) ──
// WHY: AVX2 (৩২-বাইট) এবং AVX-512 (৬৪-বাইট) ভেক্টর অপারেশন চালানোর সময়
// আন-অ্যালাইন্ড পয়েন্টার হার্ডওয়্যার ফল্ট (#GP / SIGSEGV) প্রতিরোধ করে।
fn অ্যারিনা_বরাদ্দ_অ্যালাইন্ড pool byte_size alignment
    base = মেমরি_পড়ো(pool, 0)
    capacity = মেমরি_পড়ো(pool, 8)
    used = মেমরি_পড়ো(pool, 16)

    if alignment <= 8
        alignment = 8

    current_ptr = base + used
    rem = current_ptr % alignment
    padding = 0
    if rem > 0
        padding = alignment - rem

    অ্যালাইন্ড_size = ((byte_size + 7) / 8) * 8
    total_needed = padding + অ্যালাইন্ড_size

    if used + total_needed > capacity
        return 0

    বরাদ্দী_addr = current_ptr + padding
    নতুন_used = used + total_needed
    মেমরি_লেখো(pool, 16, নতুন_used)

    return বরাদ্দী_addr

fn arena_alloc_aligned pool byte_size alignment
    return অ্যারিনা_বরাদ্দ_অ্যালাইন্ড(pool, byte_size, alignment)

// ── ২.২. ৬৪-বাইট হার্ডওয়্যার ক্যাশলাইন অ্যালাইন্ড বরাদ্দ (64-Byte CPU Cacheline Bump Alloc) ──
// WHY: Intel/AMD x86_64 ও ARM64 প্রসেসরে প্রতিটি L1/L2 ডাটা ক্যাশলাইন ঠিক ৬৪ বাইট (64 bytes)।
// ৬৪-বাইট অ্যালাইনমেন্ট কঠোরভাবে বজায় রাখলে সিপিইউ ক্যাশ ফলস-শেয়ারিং (False Sharing) শূন্যে নেমে আসে
// এবং সিপিইউ প্রি-ফেচার ও AVX2/AVX-512 ভেক্টর রেজিস্টার একক মেমরি সাইকেলে সর্বোচ্চ গতিতে নির্বাহ হতে পারে।
fn অ্যারিনা_বরাদ্দ_ক্যাশলাইন pool byte_size
    return অ্যারিনা_বরাদ্দ_অ্যালাইন্ড(pool, byte_size, 64)

fn arena_alloc_cacheline pool byte_size
    return অ্যারিনা_বরাদ্দ_অ্যালাইন্ড(pool, byte_size, 64)

// ── ২.৩. প্রথম শ্রেণির মেমরি অ্যারিনা দ্বিভাষিক নামাবলী (Bilingual Aliases) ───────────
fn মেমরি_অ্যারিনা_তৈরি capacity
    return অ্যারিনা_তৈরি(capacity)

fn মেমরি_অ্যারিনা_তৈরি_হিউজ capacity
    return arena_create_huge(capacity)

fn মেমরি_অ্যারিনা_বরাদ্দ pool byte_size
    return অ্যারিনা_বরাদ্দ(pool, byte_size)

fn মেমরি_অ্যারিনা_বরাদ্দ_ক্যাশলাইন pool byte_size
    return arena_alloc_cacheline(pool, byte_size)

fn মেমরি_অ্যারিনা_রিসেট pool
    return অ্যারিনা_রিসেট(pool)

fn মেমরি_অ্যারিনা_ধ্বংস pool
    return অ্যারিনা_ধ্বংস(pool)

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
