// ==============================================================================
// 📜 লিপি ইনোভেটিভ রবিন-হুড হ্যাশম্যাপ (Pure Lipi Robin Hood Hash Map)
// 🏛️ O(1) মেমরি লুকআপ, Cache-Locality অপ্টিমাইজড, ও Zero-Allocation আর্কিটেকচার
// ==============================================================================
// ইনোভেশন: মেমরি ফ্র্যাগমেন্টেশন রোধ করতে আমরা রবিন-হুড প্রোবিং (Robin Hood Probing) ব্যবহার করছি,
// যেখানে 'ধনী' (যার ইনডেক্স থেকে দূরত্ব কম) 'গরিব' (যার দূরত্ব বেশি) কে জায়গা ছেড়ে দেয়!

include "utso/core/memory.lp"

// ── ১. মেমরিতে হ্যাশটেবিল তৈরি (Create Hash Table) ─────────────────────────────
// WHY: লিংকড-লিস্ট (Linked List) ব্যবহার না করে সরাসরি একটানা মেমরি ব্লকে (Contiguous Memory)
// ডেটা রাখলে CPU Cache (L1/L2) মিস হওয়ার সম্ভাবনা ৯৯% কমে যায়।
fn hashmap_create max_elements
    // WHY: 32 bytes per slot: [Key: 8B] + [Value: 8B] + [Probe Distance: 8B] + [State (0=empty, 1=occupied): 8B].
    // Explicit occupied state allows key == 0 without sentinel collision.
    size = max_elements * 32
    // SYS_mmap (9) -> PROT_READ|PROT_WRITE (3), MAP_PRIVATE|MAP_ANONYMOUS (34)
    pointr = syscall(9, 0, size, 3, 34, -1, 0)
    mem_fill(pointr, 0, size)
    return pointr

fn হ্যাশম্যাপ_তৈরি max_elements
    return hashmap_create(max_elements)

// ── ২. ক্রিপ্টোগ্রাফিক নন-ক্রিপ্টো হ্যাশ (Overflow-Safe Avalanche Mix) ───────────────
fn fast_hash value
    lo = value & 2147483647
    hi = (value >> 31) & 2147483647
    h = (((lo ^ (hi * 2654435761)) * 2246822519) & 2147483647)
    h = (h ^ (h >> 15)) & 2147483647
    return h

fn ফাস্ট_হ্যাশ value
    return fast_hash(value)

// ── ৩. রবিন-হুড ইনসার্ট (Robin Hood Steal-from-the-Rich Insert) ─────────────────
fn hashmap_insert map_ptr capacity key_val val
    hash = fast_hash(key_val)
    quotient = hash / capacity
    slot = hash - (quotient * capacity)

    cur_key = key_val
    cur_val = val
    cur_dist = 0

    loop_count = 0
    while loop_count < capacity
        slot_offset = slot * 32
        state = মেমরি_পড়ো(map_ptr, slot_offset + 24)
        stored_key = মেমরি_পড়ো(map_ptr, slot_offset)

        // Update existing key in place
        if state == 1 and stored_key == cur_key
            মেমরি_লেখো(map_ptr, slot_offset + 8, cur_val)
            return 1

        // Empty slot found
        if state == 0
            মেমরি_লেখো(map_ptr, slot_offset, cur_key)
            মেমরি_লেখো(map_ptr, slot_offset + 8, cur_val)
            মেমরি_লেখো(map_ptr, slot_offset + 16, cur_dist)
            মেমরি_লেখো(map_ptr, slot_offset + 24, 1)
            return 1

        // Robin Hood steal from the rich
        stored_dist = মেমরি_পড়ো(map_ptr, slot_offset + 16)
        if cur_dist > stored_dist
            stored_val = মেমরি_পড়ো(map_ptr, slot_offset + 8)

            মেমরি_লেখো(map_ptr, slot_offset, cur_key)
            মেমরি_লেখো(map_ptr, slot_offset + 8, cur_val)
            মেমরি_লেখো(map_ptr, slot_offset + 16, cur_dist)
            মেমরি_লেখো(map_ptr, slot_offset + 24, 1)

            cur_key = stored_key
            cur_val = stored_val
            cur_dist = stored_dist

        cur_dist = cur_dist + 1
        slot = slot + 1
        if slot >= capacity
            slot = 0
        loop_count = loop_count + 1

    return 0

fn হ্যাশম্যাপ_ইনসার্ট map_ptr capacity key_val val
    return hashmap_insert(map_ptr, capacity, key_val, val)

// ── ৪. O(1) লুকআপ (O(1) Lookup with Early Exit Innovation) ────────────────────
fn hashmap_contains map_ptr capacity key_val
    hash = fast_hash(key_val)
    quotient = hash / capacity
    slot = hash - (quotient * capacity)

    distance = 0
    loop_count = 0

    while loop_count < capacity
        slot_offset = slot * 32
        state = মেমরি_পড়ো(map_ptr, slot_offset + 24)
        if state == 0
            return 0
        stored_key = মেমরি_পড়ো(map_ptr, slot_offset)
        if stored_key == key_val
            return 1
        stored_dist = মেমরি_পড়ো(map_ptr, slot_offset + 16)
        if distance > stored_dist
            return 0
        distance = distance + 1
        slot = slot + 1
        if slot >= capacity
            slot = 0
        loop_count = loop_count + 1
    return 0

fn hashmap_lookup map_ptr capacity key_val
    hash = fast_hash(key_val)
    quotient = hash / capacity
    slot = hash - (quotient * capacity)

    distance = 0
    loop_count = 0

    while loop_count < capacity
        slot_offset = slot * 32
        state = মেমরি_পড়ো(map_ptr, slot_offset + 24)
        if state == 0
            return -1
        stored_key = মেমরি_পড়ো(map_ptr, slot_offset)
        if stored_key == key_val
            val = মেমরি_পড়ো(map_ptr, slot_offset + 8)
            return val
        stored_dist = মেমরি_পড়ো(map_ptr, slot_offset + 16)
        if distance > stored_dist
            return -1
        distance = distance + 1
        slot = slot + 1
        if slot >= capacity
            slot = 0
        loop_count = loop_count + 1

    return -1

fn হ্যাশম্যাপ_লুকআপ map_ptr capacity key_val
    return hashmap_lookup(map_ptr, capacity, key_val)

// ── ৫. হ্যাশম্যাপ অবমুক্তি (Destroy Hashmap via SYS_munmap) ──────────────────────
fn hashmap_delete map_ptr capacity
    syscall(11, map_ptr, capacity * 32, 0, 0, 0, 0) // SYS_munmap
    return 1

fn হ্যাশম্যাপ_মুছে_ফেলো map_ptr capacity
    return hashmap_delete(map_ptr, capacity)

fn হ্যাশম্যাপ_অবমুক্তি map_ptr capacity
    return hashmap_delete(map_ptr, capacity)
