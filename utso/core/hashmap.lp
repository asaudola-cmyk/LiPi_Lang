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

// ==============================================================================
// ── ৬. ডায়নামিক স্ট্রিং-কীড রবিন-হুড হ্যাশম্যাপ / ডিক্ট (String-Keyed Dynamic Dict) ──
// ==============================================================================
// WHY: Production JSON objects, HTTP headers, environment tables, and KV databases
// require O(1) runtime string-keyed maps with auto-rehash (load > 0.75), true
// backward-shift delete (zero tombstone degradation), and GC-traced backing storage.
//
// Slot layout (32 bytes per slot in GC-tracked `_lipi_user_alloc` table):
//   [+0]:  key_str_ptr  (STR0 pointer, traced by GC)
//   [+8]:  val          (any Lipi value/ptr, traced by GC)
//   [+16]: hash64       (cached positive FNV-1a hash for 1-cycle mismatch reject)
//   [+24]: state_dist   (0 = empty, >= 1 = occupied with probe_dist = state_dist - 1)

struct StrDict
    sd_table
    sd_cap
    sd_count
    sd_mask
end

fn str_hash64 s
    if s == 0
        return 1469598103
    end
    n = len(s)
    h = 2166136261 ^ n
    i = 0
    while i < n
        b = mem_read_byte(s, i)
        h = ((h ^ b) * 16777619) & 2147483647
        i = i + 1
    end
    h = (h ^ (h >> 15)) & 2147483647
    if h == 0
        h = 1
    end
    return h
end

fn _sd_str_eq a b
    if a == b
        return 1
    end
    if a == 0 or b == 0
        return 0
    end
    la = len(a)
    lb = len(b)
    if la != lb
        return 0
    end
    i = 0
    while i < la
        if mem_read_byte(a, i) != mem_read_byte(b, i)
            return 0
        end
        i = i + 1
    end
    return 1
end

fn dict_new init_cap
    cap = 16
    while cap < init_cap and cap < 16777216
        cap = cap * 2
    end
    tbl = alloc(cap * 32)
    mem_fill(tbl, 0, cap * 32)
    return StrDict(tbl, cap, 0, cap - 1)
end

fn strmap_new init_cap
    return dict_new(init_cap)
end

fn অভিধান_তৈরি init_cap
    return dict_new(init_cap)
end

fn _dict_insert_raw tbl cap mask key val h
    slot = h & mask
    cur_k = key
    cur_v = val
    cur_h = h
    cur_d = 0
    steps = 0
    while steps < cap
        off = slot * 32
        st = mem_word_read(tbl, off + 24)
        if st == 0
            mem_word_write(tbl, off, cur_k)
            mem_word_write(tbl, off + 8, cur_v)
            mem_word_write(tbl, off + 16, cur_h)
            mem_word_write(tbl, off + 24, cur_d + 1)
            return 1
        end
        ek = mem_word_read(tbl, off)
        eh = mem_word_read(tbl, off + 16)
        if eh == cur_h and _sd_str_eq(ek, cur_k) == 1
            mem_word_write(tbl, off + 8, cur_v)
            return 0
        end
        ed = st - 1
        if cur_d > ed
            ev = mem_word_read(tbl, off + 8)
            mem_word_write(tbl, off, cur_k)
            mem_word_write(tbl, off + 8, cur_v)
            mem_word_write(tbl, off + 16, cur_h)
            mem_word_write(tbl, off + 24, cur_d + 1)
            cur_k = ek
            cur_v = ev
            cur_h = eh
            cur_d = ed
        end
        cur_d = cur_d + 1
        slot = (slot + 1) & mask
        steps = steps + 1
    end
    return 0
end

fn _dict_grow m: StrDict
    old_tbl = m.sd_table
    old_cap = m.sd_cap
    new_cap = old_cap * 2
    if new_cap < 16
        new_cap = 16
    end
    new_mask = new_cap - 1
    new_tbl = alloc(new_cap * 32)
    mem_fill(new_tbl, 0, new_cap * 32)
    i = 0
    while i < old_cap
        off = i * 32
        st = mem_word_read(old_tbl, off + 24)
        if st > 0
            k = mem_word_read(old_tbl, off)
            v = mem_word_read(old_tbl, off + 8)
            h = mem_word_read(old_tbl, off + 16)
            _dict_insert_raw(new_tbl, new_cap, new_mask, k, v, h)
        end
        i = i + 1
    end
    m.sd_table = new_tbl
    m.sd_cap = new_cap
    m.sd_mask = new_mask
    if old_tbl > 0
        free(old_tbl)
    end
    return 1
end

fn dict_set m: StrDict key val
    if m == 0
        return 0
    end
    if (m.sd_count + 1) * 4 >= m.sd_cap * 3
        _dict_grow(m)
    end
    h = str_hash64(key)
    added = _dict_insert_raw(m.sd_table, m.sd_cap, m.sd_mask, key, val, h)
    if added == 1
        m.sd_count = m.sd_count + 1
    end
    return 1
end

fn strmap_set m: StrDict key val
    return dict_set(m, key, val)
end

fn অভিধান_সেট m: StrDict key val
    return dict_set(m, key, val)
end

fn dict_has m: StrDict key
    if m == 0 or m.sd_table == 0 or m.sd_count == 0
        return 0
    end
    tbl = m.sd_table
    cap = m.sd_cap
    mask = m.sd_mask
    h = str_hash64(key)
    slot = h & mask
    dist = 0
    steps = 0
    while steps < cap
        off = slot * 32
        st = mem_word_read(tbl, off + 24)
        if st == 0
            return 0
        end
        if dist > (st - 1)
            return 0
        end
        eh = mem_word_read(tbl, off + 16)
        if eh == h and _sd_str_eq(mem_word_read(tbl, off), key) == 1
            return 1
        end
        dist = dist + 1
        slot = (slot + 1) & mask
        steps = steps + 1
    end
    return 0
end

fn strmap_has m: StrDict key
    return dict_has(m, key)
end

fn অভিধান_আছে m: StrDict key
    return dict_has(m, key)
end

fn dict_get_or m: StrDict key default_val
    if m == 0 or m.sd_table == 0 or m.sd_count == 0
        return default_val
    end
    tbl = m.sd_table
    cap = m.sd_cap
    mask = m.sd_mask
    h = str_hash64(key)
    slot = h & mask
    dist = 0
    steps = 0
    while steps < cap
        off = slot * 32
        st = mem_word_read(tbl, off + 24)
        if st == 0
            return default_val
        end
        if dist > (st - 1)
            return default_val
        end
        eh = mem_word_read(tbl, off + 16)
        if eh == h and _sd_str_eq(mem_word_read(tbl, off), key) == 1
            return mem_word_read(tbl, off + 8)
        end
        dist = dist + 1
        slot = (slot + 1) & mask
        steps = steps + 1
    end
    return default_val
end

fn dict_get m: StrDict key
    return dict_get_or(m, key, 0)
end

fn strmap_get m: StrDict key
    return dict_get_or(m, key, 0)
end

fn অভিধান_নাও m: StrDict key
    return dict_get_or(m, key, 0)
end

fn dict_delete m: StrDict key
    // WHY: Robin-Hood backward-shift deletion removes keys in O(1) average time
    // with zero tombstones, keeping probe lengths bounded forever under heavy churn.
    if m == 0 or m.sd_table == 0 or m.sd_count == 0
        return 0
    end
    tbl = m.sd_table
    cap = m.sd_cap
    mask = m.sd_mask
    h = str_hash64(key)
    slot = h & mask
    dist = 0
    steps = 0
    found = 0 - 1
    while steps < cap
        off = slot * 32
        st = mem_word_read(tbl, off + 24)
        if st == 0 or dist > (st - 1)
            return 0
        end
        if mem_word_read(tbl, off + 16) == h and _sd_str_eq(mem_word_read(tbl, off), key) == 1
            found = slot
            break
        end
        dist = dist + 1
        slot = (slot + 1) & mask
        steps = steps + 1
    end
    if found < 0
        return 0
    end
    // Backward shift subsequent displaced entries
    cur = found
    while 1 == 1
        nxt = (cur + 1) & mask
        n_off = nxt * 32
        n_st = mem_word_read(tbl, n_off + 24)
        if n_st <= 1
            c_off = cur * 32
            mem_word_write(tbl, c_off, 0)
            mem_word_write(tbl, c_off + 8, 0)
            mem_word_write(tbl, c_off + 16, 0)
            mem_word_write(tbl, c_off + 24, 0)
            break
        end
        c_off = cur * 32
        mem_word_write(tbl, c_off, mem_word_read(tbl, n_off))
        mem_word_write(tbl, c_off + 8, mem_word_read(tbl, n_off + 8))
        mem_word_write(tbl, c_off + 16, mem_word_read(tbl, n_off + 16))
        mem_word_write(tbl, c_off + 24, n_st - 1)
        cur = nxt
    end
    m.sd_count = m.sd_count - 1
    return 1
end

fn strmap_delete m: StrDict key
    return dict_delete(m, key)
end

fn অভিধান_মুছো m: StrDict key
    return dict_delete(m, key)
end

fn dict_len m: StrDict
    if m == 0
        return 0
    end
    return m.sd_count
end

fn dict_keys m: StrDict
    ks = list()
    if m == 0 or m.sd_table == 0
        return ks
    end
    tbl = m.sd_table
    cap = m.sd_cap
    i = 0
    while i < cap
        off = i * 32
        if mem_word_read(tbl, off + 24) > 0
            push(ks, mem_word_read(tbl, off))
        end
        i = i + 1
    end
    return ks
end

fn dict_values m: StrDict
    vs = list()
    if m == 0 or m.sd_table == 0
        return vs
    end
    tbl = m.sd_table
    cap = m.sd_cap
    i = 0
    while i < cap
        off = i * 32
        if mem_word_read(tbl, off + 24) > 0
            push(vs, mem_word_read(tbl, off + 8))
        end
        i = i + 1
    end
    return vs
end

fn dict_clear m: StrDict
    if m == 0 or m.sd_table == 0
        return 0
    end
    mem_fill(m.sd_table, 0, m.sd_cap * 32)
    m.sd_count = 0
    return 1
end

fn dict_free m: StrDict
    if m == 0
        return 0
    end
    if m.sd_table > 0
        free(m.sd_table)
        m.sd_table = 0
    end
    m.sd_cap = 0
    m.sd_count = 0
    m.sd_mask = 0
    return 1
end

fn strmap_free m: StrDict
    return dict_free(m)
end

fn অভিধান_মুক্তি m: StrDict
    return dict_free(m)
end

// ── ৬. ডায়নামিক রিসাইজিং ইন্টিজার হ্যাশম্যাপ (Dynamic Auto-Resizing IntMap) ──────
// WHY: Replaces fixed-capacity manual hashmap_create with full 2x automatic rehashing at 75% load
// and zero-tombstone Robin-Hood backward-shift deletion for arbitrary 64-bit integer keys.

struct IntMap
    im_table
    im_cap
    im_count
    im_mask
end

fn intmap_new init_cap
    cap = 16
    while cap < init_cap
        cap = cap * 2
    end
    tbl = alloc(cap * 32)
    mem_fill(tbl, 0, cap * 32)
    return IntMap(tbl, cap, 0, cap - 1)
end

fn _intmap_hash64 k
    h = k ^ (k >> 30)
    h = h * 48271
    h = h ^ (h >> 17)
    h = h * 2654435761
    return h ^ (h >> 16)
end

fn _intmap_insert_raw tbl cap mask key val h
    slot = h & mask
    cur_k = key
    cur_v = val
    cur_h = h
    cur_d = 0
    steps = 0
    while steps < cap
        off = slot * 32
        st = mem_word_read(tbl, off + 24)
        if st == 0
            mem_word_write(tbl, off, cur_k)
            mem_word_write(tbl, off + 8, cur_v)
            mem_word_write(tbl, off + 16, cur_h)
            mem_word_write(tbl, off + 24, cur_d + 1)
            return 1
        end
        ek = mem_word_read(tbl, off)
        if ek == cur_k
            mem_word_write(tbl, off + 8, cur_v)
            return 0
        end
        ed = st - 1
        if cur_d > ed
            ev = mem_word_read(tbl, off + 8)
            eh = mem_word_read(tbl, off + 16)
            mem_word_write(tbl, off, cur_k)
            mem_word_write(tbl, off + 8, cur_v)
            mem_word_write(tbl, off + 16, cur_h)
            mem_word_write(tbl, off + 24, cur_d + 1)
            cur_k = ek
            cur_v = ev
            cur_h = eh
            cur_d = ed
        end
        cur_d = cur_d + 1
        slot = (slot + 1) & mask
        steps = steps + 1
    end
    return 0
end

fn _intmap_grow m: IntMap
    old_tbl = m.im_table
    old_cap = m.im_cap
    new_cap = old_cap * 2
    if new_cap < 16
        new_cap = 16
    end
    new_mask = new_cap - 1
    new_tbl = alloc(new_cap * 32)
    mem_fill(new_tbl, 0, new_cap * 32)
    i = 0
    while i < old_cap
        off = i * 32
        if mem_word_read(old_tbl, off + 24) > 0
            _intmap_insert_raw(new_tbl, new_cap, new_mask, mem_word_read(old_tbl, off), mem_word_read(old_tbl, off + 8), mem_word_read(old_tbl, off + 16))
        end
        i = i + 1
    end
    m.im_table = new_tbl
    m.im_cap = new_cap
    m.im_mask = new_mask
    if old_tbl > 0
        free(old_tbl)
    end
    return 1
end

fn intmap_set m: IntMap key val
    if m == 0 return 0 end
    if (m.im_count + 1) * 4 >= m.im_cap * 3
        _intmap_grow(m)
    end
    h = _intmap_hash64(key)
    added = _intmap_insert_raw(m.im_table, m.im_cap, m.im_mask, key, val, h)
    if added == 1
        m.im_count = m.im_count + 1
    end
    return 1
end

fn intmap_has m: IntMap key
    if m == 0 or m.im_table == 0 or m.im_count == 0 return 0 end
    tbl = m.im_table
    cap = m.im_cap
    mask = m.im_mask
    slot = _intmap_hash64(key) & mask
    dist = 0
    steps = 0
    while steps < cap
        off = slot * 32
        st = mem_word_read(tbl, off + 24)
        if st == 0 or dist > (st - 1) return 0 end
        if mem_word_read(tbl, off) == key return 1 end
        dist = dist + 1
        slot = (slot + 1) & mask
        steps = steps + 1
    end
    return 0
end

fn intmap_get_or m: IntMap key default_val
    if m == 0 or m.im_table == 0 or m.im_count == 0 return default_val end
    tbl = m.im_table
    cap = m.im_cap
    mask = m.im_mask
    slot = _intmap_hash64(key) & mask
    dist = 0
    steps = 0
    while steps < cap
        off = slot * 32
        st = mem_word_read(tbl, off + 24)
        if st == 0 or dist > (st - 1) return default_val end
        if mem_word_read(tbl, off) == key return mem_word_read(tbl, off + 8) end
        dist = dist + 1
        slot = (slot + 1) & mask
        steps = steps + 1
    end
    return default_val
end

fn intmap_get m: IntMap key
    return intmap_get_or(m, key, 0)
end

fn intmap_del m: IntMap key
    if m == 0 or m.im_table == 0 or m.im_count == 0 return 0 end
    tbl = m.im_table
    cap = m.im_cap
    mask = m.im_mask
    slot = _intmap_hash64(key) & mask
    dist = 0
    steps = 0
    found = 0 - 1
    while steps < cap
        off = slot * 32
        st = mem_word_read(tbl, off + 24)
        if st == 0 or dist > (st - 1) return 0 end
        if mem_word_read(tbl, off) == key
            found = slot
            break
        end
        dist = dist + 1
        slot = (slot + 1) & mask
        steps = steps + 1
    end
    if found < 0 return 0 end
    cur = found
    while 1 == 1
        nxt = (cur + 1) & mask
        n_off = nxt * 32
        n_st = mem_word_read(tbl, n_off + 24)
        c_off = cur * 32
        if n_st <= 1
            mem_word_write(tbl, c_off, 0)
            mem_word_write(tbl, c_off + 8, 0)
            mem_word_write(tbl, c_off + 16, 0)
            mem_word_write(tbl, c_off + 24, 0)
            break
        end
        mem_word_write(tbl, c_off, mem_word_read(tbl, n_off))
        mem_word_write(tbl, c_off + 8, mem_word_read(tbl, n_off + 8))
        mem_word_write(tbl, c_off + 16, mem_word_read(tbl, n_off + 16))
        mem_word_write(tbl, c_off + 24, n_st - 1)
        cur = nxt
    end
    m.im_count = m.im_count - 1
    return 1
end

fn intmap_len m: IntMap
    if m == 0 return 0 end
    return m.im_count
end

fn intmap_free m: IntMap
    if m == 0 return 0 end
    if m.im_table > 0
        free(m.im_table)
        m.im_table = 0
    end
    m.im_cap = 0
    m.im_count = 0
    m.im_mask = 0
    return 1
end
