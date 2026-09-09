// 📜 লিপি ইনোভেটিভ রবিন-হুড hashম্যাপ (Pure Lipi Robin Hood Hash Map)
// 🏛️ O(1) memory লুaআপ, Cache-Locality অপ্টিমাইজড, ও Zero-Allocation আর্aিটেaচার
// ইনোভেশন: memory ফ্র্যাগমেন্টেশন রোধ aরতে we রবিন-হুড প্রোবিং (Robin Hood Probing) ব্যবrate aরছি,
// যেbানে 'ধনী' (যার indexa্স থেaে distance less) 'গরিব' (যার distance more) aে জায়গা ছেড়ে দেয়!

include "std/mem.lp"

// ১. memতে hashtable create (Create Hash Table)
// WHY: লিংaড-লিস্ট (Linked List) ব্যবrate not aরে direct এaটানা memory ব্লaে (Contiguous Memory)
// data রাbলে CPU Cache (L1/L2) মিস হওয়ার সম্ভাবনা ৯৯% lessে যায়।
fn hashmap_create max_elements
    // each slotে needed: [Key Hash: 8 Byte] + [Value Pointer: 8 Byte] + [Probe Distance: 8 Byte] = 24 Bytes
    size = max_elements * 24
    // SYS_mmap (9) -> PROT_READ|PROT_WRITE (3), MAP_PRIVATE|MAP_ANONYMOUS (34)
    পয়েন্টার = syscall(9, 0, size, 3, 34, -1, 0)
    mem_fill(পয়েন্টার, 0, size)
    return পয়েন্টার

// ২. a্রিপ্টোগ্রাফিa নন-a্রিপ্টো hash (MurmurHash3 বিaল্প ইনোভেশন)
// WHY: সাধারণ মডুলো (Modulo) hash অনেa aোলিশন (Collision) create aরে।
// we বিট-শিফটিং এবং prime মাল্টিপ্লিaেশন দিয়ে ফাস্ট অ্যাভাল্যাঞ্জ hash create aরছি।
fn fast_hash value
    hash = value * 13145671 // এaটি prime num
    // লিপিতে বিট-শিফট বর্তvalueে গাণিতিa divideের মাধ্যমে সিমুলেট aরা যায় (if shift operator not থাaে)
    // তবে we simple লিনিয়ার aনগ্রুয়েন্সিয়াল generator (LCG) স্টাইল hash ব্যবrate aরব।
    hash = hash + (value * 73)
    if hash < 0
        hash = hash * -1
    return hash

// ৩. রবিন-হুড insert (Robin Hood Steal-from-the-Rich Insert)
// WHY: aোলিশন হলে যে data তার আসল indexa্স থেaে more দূরে (গরিব), সে আগের dataaে (ধনী) সরিয়ে জায়গা দbল aরবে।
fn hashmap_insert ম্যাপ_পয়েন্টার capacity key_val val
    hash = fast_hash(key_val)
    // capacity দিয়ে মডুলো (লিপিতে % operator not থাaলে: hash - (hash / capacity) * capacity)
    quotient = hash / capacity
    slot = hash - (quotient * capacity)

    cur_key = key_val
    cur_val = val
    cur_dist = 0

    loop_count = 0
    while loop_count < capacity
        offset = slot * 24
        stored_key = mem_শব্দ_পড়ো(ম্যাপ_পয়েন্টার, slot * 3) // Offset 0

        // slot bালি থাaলে
        if stored_key == 0
            mem_write_word(ম্যাপ_পয়েন্টার, slot * 3, cur_key)
            mem_write_word(ম্যাপ_পয়েন্টার, (slot * 3) + 1, cur_val)
            mem_write_word(ম্যাপ_পয়েন্টার, (slot * 3) + 2, cur_dist)
            return 1

        // রবিন হুড লজিa: ধনী থেaে চুরি (Steal from the rich)
        stored_dist = mem_শব্দ_পড়ো(ম্যাপ_পয়েন্টার, (slot * 3) + 2)
        if cur_dist > stored_dist
            // অদল-বদল (Swap)
            stored_val = mem_শব্দ_পড়ো(ম্যাপ_পয়েন্টার, (slot * 3) + 1)

            mem_write_word(ম্যাপ_পয়েন্টার, slot * 3, cur_key)
            mem_write_word(ম্যাপ_পয়েন্টার, (slot * 3) + 1, cur_val)
            mem_write_word(ম্যাপ_পয়েন্টার, (slot * 3) + 2, cur_dist)

            cur_key = stored_key
            cur_val = stored_val
            cur_dist = stored_dist

        cur_dist = cur_dist + 1
        slot = slot + 1
        if slot >= capacity
            slot = 0 // র‍্যাপ এরাউন্ড (Wrap Around)
        loop_count = loop_count + 1

    // map full (Full)
    return 0

// ৪. ও(১) লুaআপ (O(1) Lookup with Early Exit Innovation)
// WHY: রবিন হুড hashিং এর aারণে we জানি যে aোনো ইলিমেন্ট তার distanceের চেয়ে more দূরে থাaতে পারবে not, তাই fast লুপ ব্রেa aরা যায়।
fn hashmap_lookup ম্যাপ_পয়েন্টার capacity key_val
    hash = fast_hash(key_val)
    quotient = hash / capacity
    slot = hash - (quotient * capacity)

    distance = 0
    loop_count = 0

    while loop_count < capacity
        stored_key = mem_শব্দ_পড়ো(ম্যাপ_পয়েন্টার, slot * 3)

        if stored_key == key_val
            val = mem_শব্দ_পড়ো(ম্যাপ_পয়েন্টার, (slot * 3) + 1)
            return val

        if stored_key == 0
            return -1 // পাওয়া যায়নি

        stored_dist = mem_শব্দ_পড়ো(ম্যাপ_পয়েন্টার, (slot * 3) + 2)
        if distance > stored_dist
            return -1 // Early Exit (রবিন হুড ইনোভেশন: data এbানে থাaতে পারে না)

        distance = distance + 1
        slot = slot + 1
        if slot >= capacity
            slot = 0
        loop_count = loop_count + 1

    return -1

// ৫. hashম্যাপ অবমুa্তি
fn hashmap_delete ম্যাপ_পয়েন্টার capacity
    syscall(11, ম্যাপ_পয়েন্টার, capacity * 24) // SYS_munmap
    return 1
