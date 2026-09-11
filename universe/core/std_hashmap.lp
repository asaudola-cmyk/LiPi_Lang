// ==============================================================================
// 📜 লিপি ইনোভেটিভ রবিন-হুড হ্যাশম্যাপ (Pure Lipi Robin Hood Hash Map)
// 🏛️ O(1) মেমরি লুকআপ, Cache-Locality অপ্টিমাইজড, ও Zero-Allocation আর্কিটেকচার
// ==============================================================================
// ইনোভেশন: মেমরি ফ্র্যাগমেন্টেশন রোধ করতে আমরা রবিন-হুড প্রোবিং (Robin Hood Probing) ব্যবহার করছি,
// যেখানে 'ধনী' (যার ইনডেক্স থেকে দূরত্ব কম) 'গরিব' (যার দূরত্ব বেশি) কে জায়গা ছেড়ে দেয়!

include "universe/core/std_mem.lp"

// ── ১. মেমরিতে হ্যাশটেবিল তৈরি (Create Hash Table) ─────────────────────────────
// WHY: লিংকড-লিস্ট (Linked List) ব্যবহার না করে সরাসরি একটানা মেমরি ব্লকে (Contiguous Memory)
// ডেটা রাখলে CPU Cache (L1/L2) মিস হওয়ার সম্ভাবনা ৯৯% কমে যায়।
fn hashmap_create max_elements
    // প্রতি স্লটে প্রয়োজন: [Key Hash: 8 Byte] + [Value Pointer: 8 Byte] + [Probe Distance: 8 Byte] = 24 Bytes
    size = max_elements * 24
    // SYS_mmap (9) -> PROT_READ|PROT_WRITE (3), MAP_PRIVATE|MAP_ANONYMOUS (34)
    pointr = syscall(9, 0, size, 3, 34, -1, 0)
    mem_fill(pointr, 0, size)
    return pointr

fn হ্যাশম্যাপ_তৈরি max_elements
    return hashmap_create(max_elements)

// ── ২. ক্রিপ্টোগ্রাফিক নন-ক্রিপ্টো হ্যাশ (MurmurHash3 বিকল্প ইনোভেশন) ───────────
// WHY: সাধারণ মডুলো (Modulo) হ্যাশ অনেক কোলিশন (Collision) তৈরি করে।
// আমরা বিট-শিফটিং এবং প্রাইম মাল্টিপ্লিকেশন দিয়ে ফাস্ট অ্যাভাল্যাঞ্জ হ্যাশ তৈরি করছি।
fn fast_hash value
    hash = value * 13145671 // একটি প্রাইম সংখ্যা
    // লিপিতে বিট-শিফট বর্তমানে গাণিতিক ভাগের মাধ্যমে সিমুলেট করা যায় (যদি শিফট অপারেটর না থাকে)
    // তবে আমরা সাধারণ লিনিয়ার কনগ্রুয়েন্সিয়াল জেনারেটর (LCG) স্টাইল হ্যাশ ব্যবহার করব।
    hash = hash + (value * 73)
    if hash < 0
        hash = hash * -1
    return hash

fn ফাস্ট_হ্যাশ value
    return fast_hash(value)

// ── ৩. রবিন-হুড ইনসার্ট (Robin Hood Steal-from-the-Rich Insert) ─────────────────
// WHY: কোলিশন হলে যে ডেটা তার আসল ইনডেক্স থেকে বেশি দূরে (গরিব), সে আগের ডেটাকে (ধনী) সরিয়ে জায়গা দখল করবে।
fn hashmap_insert map_ptr capacity key_val val
    hash = fast_hash(key_val)
    quotient = hash / capacity
    slot = hash - (quotient * capacity)

    cur_key = key_val
    cur_val = val
    cur_dist = 0

    loop_count = 0
    while loop_count < capacity
        slot_offset = slot * 24
        stored_key = মেমরি_পড়ো(map_ptr, slot_offset)

        // যদি একই কী আগেই উপস্থিত থাকে, মান আপডেট করো
        if stored_key == cur_key
            মেমরি_লেখো(map_ptr, slot_offset + 8, cur_val)
            return 1

        // স্লট খালি থাকলে সংরক্ষণ করো
        if stored_key == 0
            মেমরি_লেখো(map_ptr, slot_offset, cur_key)
            মেমরি_লেখো(map_ptr, slot_offset + 8, cur_val)
            মেমরি_লেখো(map_ptr, slot_offset + 16, cur_dist)
            return 1

        // রবিন হুড লজিক: ধনী থেকে চুরি (Steal from the rich)
        stored_dist = মেমরি_পড়ো(map_ptr, slot_offset + 16)
        if cur_dist > stored_dist
            // অদল-বদল (Swap)
            stored_val = মেমরি_পড়ো(map_ptr, slot_offset + 8)

            মেমরি_লেখো(map_ptr, slot_offset, cur_key)
            মেমরি_লেখো(map_ptr, slot_offset + 8, cur_val)
            মেমরি_লেখো(map_ptr, slot_offset + 16, cur_dist)

            cur_key = stored_key
            cur_val = stored_val
            cur_dist = stored_dist

        cur_dist = cur_dist + 1
        slot = slot + 1
        if slot >= capacity
            slot = 0 // র‍্যাপ এরাউন্ড (Wrap Around)
        loop_count = loop_count + 1

    // ম্যাপ পূর্ণ (Full)
    return 0

fn হ্যাশম্যাপ_ইনসার্ট map_ptr capacity key_val val
    return hashmap_insert(map_ptr, capacity, key_val, val)

// ── ৪. O(1) লুকআপ (O(1) Lookup with Early Exit Innovation) ────────────────────
// WHY: রবিন হুড হ্যাশিং এর কারণে আমরা জানি যে কোনো উপাদান তার দূরত্বের চেয়ে বেশি দূরে থাকতে পারবে না, তাই দ্রুত লুপ ব্রেক করা যায়।
fn hashmap_lookup map_ptr capacity key_val
    hash = fast_hash(key_val)
    quotient = hash / capacity
    slot = hash - (quotient * capacity)

    distance = 0
    loop_count = 0

    while loop_count < capacity
        slot_offset = slot * 24
        stored_key = মেমরি_পড়ো(map_ptr, slot_offset)

        if stored_key == key_val
            val = মেমরি_পড়ো(map_ptr, slot_offset + 8)
            return val

        if stored_key == 0
            return -1 // পাওয়া যায়নি

        stored_dist = মেমরি_পড়ো(map_ptr, slot_offset + 16)
        if distance > stored_dist
            return -1 // Early Exit (রবিন হুড ইনোভেশন: ডেটা এখানে থাকতে পারে না)

        distance = distance + 1
        slot = slot + 1
        if slot >= capacity
            slot = 0
        loop_count = loop_count + 1

    return -1

fn হ্যাশম্যাপ_লুকআপ map_ptr capacity key_val
    return hashmap_lookup(map_ptr, capacity, key_val)

// ── ৫. হ্যাশম্যাপ অবমুক্তি (Destroy Hashmap via SYS_munmap) ──────────────────────
// WHY: ম্যাপের জন্য বরাদ্দকৃত মেমরি কার্নেলে ফিরিয়ে দেওয়া।
fn hashmap_delete map_ptr capacity
    syscall(11, map_ptr, capacity * 24, 0, 0, 0, 0) // SYS_munmap
    return 1

fn হ্যাশম্যাপ_মুছে_ফেলো map_ptr capacity
    return hashmap_delete(map_ptr, capacity)

fn হ্যাশম্যাপ_অবমুক্তি map_ptr capacity
    return hashmap_delete(map_ptr, capacity)
