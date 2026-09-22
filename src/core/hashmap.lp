// ==============================================================================
// 👑 LIPI FIRST 1.0.0 FREESTANDING CORE SILICON PRIMITIVES: HASHMAP (src/core/hashmap.lp)
// ⚡ 100% Pure Lipi Sovereign Implementation | Zero C | Zero Libc | Zero Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Traditional chained hashmaps allocate separate linked-list nodes per key-value pair,
//    causing frequent CPU cache misses, pointer chasing, and heap fragmentation.
// 2. Open addressing with linear probing stores all keys, values, hashes, and probe metadata
//    in flat, contiguous memory arrays, utilizing hardware L1/L2 cache prefetching to the fullest.
// 3. The Robin-Hood heuristic enforces fairness during collisions:
//    "Take from the rich (short probe distance) and give to the poor (long probe distance)."
//    - Drastically bounds the maximum Probe Sequence Length (PSL) to rarely exceed 3-4.
//    - Enables early-exit lookups: if `curr_psl > slot_psl`, the search terminates immediately
//      because any existing entry would have displaced the slot.
//    - Backward-shift deletion maintains the contiguous cluster invariant without tombstones.
// ==============================================================================

struct RobinHoodMap
    map_capacity
    map_mask
    map_count
    map_keys
    map_values
    map_hashes
    map_psls

// ── 1. Universal Silicon Key Hash Dispatcher ──────────────────────────────────

// WHY: Provides deterministic, avalanche-rich hashing for both string identifiers
//      and integer keys (e.g. register indices, AST node IDs, basic block IDs).
fn map_hash_key(k)
    if is_str(k) == 1
        // FNV-1a 32-bit hash for string keys
        h = 2166136261
        slen = len(k)
        i = 0
        while i < slen
            c = ord(char_at(k, i))
            h = ((h ^ c) * 16777619) & 4294967295
            i = i + 1
        return h

    // SplitMix32 integer mixer for raw numbers and pointers
    v = k & 4294967295
    v = (v ^ (v >> 16)) * 2246822507
    v = v & 4294967295
    v = (v ^ (v >> 13)) * 3266489909
    v = v & 4294967295
    return (v ^ (v >> 16)) & 4294967295

// ── 2. Hashmap Lifecycle & Initialization ─────────────────────────────────────

// WHY: Instantiates an open-addressing hash table with power-of-two capacity.
//      Power-of-two sizing replaces expensive division/modulo with single-cycle `& mask`.
fn map_new(initial_cap)
    m = RobinHoodMap()
    cap = initial_cap
    if cap < 16
        cap = 16

    // Round up to power of 2
    p = 16
    while p < cap
        p = p * 2
    cap = p

    m.map_capacity = cap
    m.map_mask = cap - 1
    m.map_count = 0
    m.map_keys = list()
    m.map_values = list()
    m.map_hashes = list()
    m.map_psls = list()

    // Initialize all slots: psl = -1 indicates an empty slot
    i = 0
    while i < cap
        push(m.map_keys, 0)
        push(m.map_values, 0)
        push(m.map_hashes, 0)
        push(m.map_psls, 0 - 1)
        i = i + 1

    return m

// WHY: Resets all entries to empty state without reallocating arrays.
fn map_clear(m)
    if m == 0 return 0
    cap = m.map_capacity
    m.map_count = 0
    m.map_keys = list()
    m.map_values = list()
    m.map_hashes = list()
    m.map_psls = list()

    i = 0
    while i < cap
        push(m.map_keys, 0)
        push(m.map_values, 0)
        push(m.map_hashes, 0)
        push(m.map_psls, 0 - 1)
        i = i + 1
    return 1

// ── 3. Dynamic Resizing & Re-clustering ────────────────────────────────────────

// WHY: When the load factor reaches 75%, doubles the table to maintain short probe sequences.
fn map_resize(m, new_cap)
    if m == 0 return 0
    old_cap = m.map_capacity
    old_keys = m.map_keys
    old_vals = m.map_values
    old_psls = m.map_psls

    m.map_capacity = new_cap
    m.map_mask = new_cap - 1
    m.map_count = 0
    m.map_keys = list()
    m.map_values = list()
    m.map_hashes = list()
    m.map_psls = list()

    i = 0
    while i < new_cap
        push(m.map_keys, 0)
        push(m.map_values, 0)
        push(m.map_hashes, 0)
        push(m.map_psls, 0 - 1)
        i = i + 1

    // Re-insert all active entries into the enlarged table
    i = 0
    while i < old_cap
        if get(old_psls, i) != (0 - 1)
            map_insert(m, get(old_keys, i), get(old_vals, i))
        i = i + 1
    return 1

// ── 4. Robin-Hood Insertion ───────────────────────────────────────────────────

// WHY: Inserts key-value pair. If incoming entry has traveled further from its ideal bucket
//      than the current occupant (curr_psl > slot_psl), it steals the slot and the displaced
//      entry continues probing.
fn map_insert(m, key, val)
    if m == 0 return 0

    // Check load factor: count * 4 >= capacity * 3 (75% threshold)
    if (m.map_count * 4) >= (m.map_capacity * 3)
        map_resize(m, m.map_capacity * 2)

    h = map_hash_key(key)
    curr_key = key
    curr_val = val
    curr_hash = h
    curr_psl = 0

    idx = curr_hash & m.map_mask
    done = 0
    while done == 0
        slot_psl = get(m.map_psls, idx)
        if slot_psl == (0 - 1)
            // Empty slot found: claim it
            list_set(m.map_keys, idx, curr_key)
            list_set(m.map_values, idx, curr_val)
            list_set(m.map_hashes, idx, curr_hash)
            list_set(m.map_psls, idx, curr_psl)
            m.map_count = m.map_count + 1
            done = 1
        else
            if get(m.map_hashes, idx) == curr_hash and get(m.map_keys, idx) == curr_key
                // Key already exists: update value in place
                list_set(m.map_values, idx, curr_val)
                done = 1
            else
                if slot_psl < curr_psl
                    // Robin-Hood Swap: displace the existing occupant
                    tmp_k = get(m.map_keys, idx)
                    tmp_v = get(m.map_values, idx)
                    tmp_h = get(m.map_hashes, idx)
                    tmp_p = slot_psl

                    list_set(m.map_keys, idx, curr_key)
                    list_set(m.map_values, idx, curr_val)
                    list_set(m.map_hashes, idx, curr_hash)
                    list_set(m.map_psls, idx, curr_psl)

                    curr_key = tmp_k
                    curr_val = tmp_v
                    curr_hash = tmp_h
                    curr_psl = tmp_p

                curr_psl = curr_psl + 1
                idx = (idx + 1) & m.map_mask
    return 1

// ── 5. Early-Exit Lookup ──────────────────────────────────────────────────────

// WHY: Finds `key` in the map. If `curr_psl > slot_psl`, we can guarantee that `key`
//      does NOT exist in the map without continuing to probe further.
fn map_get(m, key, default_val)
    if m == 0 or m.map_count == 0 return default_val
    h = map_hash_key(key)
    idx = h & m.map_mask
    curr_psl = 0

    while 1 == 1
        slot_psl = get(m.map_psls, idx)
        if slot_psl == (0 - 1) or curr_psl > slot_psl
            // Early Exit: entry cannot exist beyond this point
            return default_val
        if get(m.map_hashes, idx) == h and get(m.map_keys, idx) == key
            return get(m.map_values, idx)
        curr_psl = curr_psl + 1
        idx = (idx + 1) & m.map_mask
    return default_val

// WHY: Returns 1 if `key` exists in the map, 0 otherwise.
fn map_has(m, key)
    if m == 0 or m.map_count == 0 return 0
    h = map_hash_key(key)
    idx = h & m.map_mask
    curr_psl = 0

    while 1 == 1
        slot_psl = get(m.map_psls, idx)
        if slot_psl == (0 - 1) or curr_psl > slot_psl
            return 0
        if get(m.map_hashes, idx) == h and get(m.map_keys, idx) == key
            return 1
        curr_psl = curr_psl + 1
        idx = (idx + 1) & m.map_mask
    return 0

// ── 6. Backward-Shift Deletion (Zero Tombstones) ──────────────────────────────

// WHY: Deletes `key` and backward-shifts subsequent colliding elements until an element
//      with `psl == 0` or an empty slot is reached. This completely eliminates tombstone
//      markers and prevents cluster degradation over repeated deletions.
fn map_remove(m, key)
    if m == 0 or m.map_count == 0 return 0
    h = map_hash_key(key)
    idx = h & m.map_mask
    curr_psl = 0

    del_idx = 0 - 1
    found = 0
    while found == 0
        slot_psl = get(m.map_psls, idx)
        if slot_psl == (0 - 1) or curr_psl > slot_psl
            return 0 // Key not found
        if get(m.map_hashes, idx) == h and get(m.map_keys, idx) == key
            del_idx = idx
            found = 1
        else
            curr_psl = curr_psl + 1
            idx = (idx + 1) & m.map_mask

    // Clear deleted slot
    list_set(m.map_psls, del_idx, 0 - 1)
    list_set(m.map_keys, del_idx, 0)
    list_set(m.map_values, del_idx, 0)
    m.map_count = m.map_count - 1

    // Backward shift following entries
    curr = del_idx
    shift_done = 0
    while shift_done == 0
        next_i = (curr + 1) & m.map_mask
        next_p = get(m.map_psls, next_i)
        if next_p <= 0
            shift_done = 1
        else
            // Shift next element backward by 1 slot
            list_set(m.map_keys, curr, get(m.map_keys, next_i))
            list_set(m.map_values, curr, get(m.map_values, next_i))
            list_set(m.map_hashes, curr, get(m.map_hashes, next_i))
            list_set(m.map_psls, curr, next_p - 1)

            // Clear moved slot
            list_set(m.map_psls, next_i, 0 - 1)
            list_set(m.map_keys, next_i, 0)
            list_set(m.map_values, next_i, 0)
            curr = next_i
    return 1

// ── 7. Map Metrics & Diagnostics ──────────────────────────────────────────────

fn map_count(m)
    if m == 0 return 0
    return m.map_count

fn map_capacity(m)
    if m == 0 return 0
    return m.map_capacity
