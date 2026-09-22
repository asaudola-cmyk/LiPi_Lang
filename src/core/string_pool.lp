// ==============================================================================
// 👑 LIPI FIRST 1.0.0 FREESTANDING CORE SILICON PRIMITIVES: STRING POOL (src/core/string_pool.lp)
// ⚡ 100% Pure Lipi Sovereign Implementation | Zero C | Zero Libc | Zero Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. High-speed compilation requires comparing thousands of identifiers, keywords,
//    and type names across lexer tokens, AST nodes, and symbol tables.
// 2. Comparing raw byte strings requires O(N) memory reads and cache thrashing.
//    By interning every distinct string into an immutable string pool, each string is
//    assigned a unique 64-bit integer ID (`symbol_id`).
// 3. Any two symbols can then be checked for equivalence with a single CPU instruction
//    (`sym_a == sym_b`, O(1)), and string storage is 100% deduplicated across the compiler.
// ==============================================================================

// ── 1. Fast FNV-1a String Hashing ─────────────────────────────────────────────

// WHY: FNV-1a (Fowler-Noll-Vo) provides superior avalanche characteristics and minimal
//      collisions for typical compiler identifiers (1 to 32 characters) with zero lookup tables.
fn string_hash(s)
    if s == 0 return 0
    h = 2166136261
    slen = len(s)
    i = 0
    while i < slen
        c = ord(char_at(s, i))
        h = ((h ^ c) * 16777619) & 4294967295
        i = i + 1
    return h

// ── 2. String Pool Struct Definition ──────────────────────────────────────────

struct StringPool
    pool_capacity
    pool_count
    pool_buckets
    pool_strings
    pool_hashes
    pool_next_chain

// ── 3. Constructor & Memory Initialization ────────────────────────────────────

// WHY: Allocates a new string pool with power-of-two capacity for fast bitwise masking.
fn string_pool_new(initial_cap)
    pool = StringPool()
    cap = initial_cap
    if cap < 16
        cap = 16

    // Round up to nearest power of 2 if not already
    p = 16
    while p < cap
        p = p * 2
    cap = p

    pool.pool_capacity = cap
    pool.pool_count = 0
    pool.pool_strings = list()
    pool.pool_hashes = list()
    pool.pool_next_chain = list()
    pool.pool_buckets = list()

    // Initialize all bucket heads to -1 (empty chain)
    i = 0
    while i < cap
        push(pool.pool_buckets, 0 - 1)
        i = i + 1

    return pool

// ── 4. Dynamic Resizing & Rehashing ───────────────────────────────────────────

// WHY: Prevents bucket chain degradation. When the load factor exceeds 75%,
//      the bucket array is doubled, maintaining O(1) average lookup time.
fn string_pool_resize(pool, new_cap)
    if pool == 0 return 0
    if new_cap <= pool.pool_capacity return 0

    old_cap = pool.pool_capacity
    pool.pool_capacity = new_cap
    new_buckets = list()

    i = 0
    while i < new_cap
        push(new_buckets, 0 - 1)
        i = i + 1

    mask = new_cap - 1
    total = pool.pool_count
    sym_id = 0
    while sym_id < total
        h = get(pool.pool_hashes, sym_id)
        b = h & mask
        head = get(new_buckets, b)
        list_set(pool.pool_next_chain, sym_id, head)
        list_set(new_buckets, b, sym_id)
        sym_id = sym_id + 1

    pool.pool_buckets = new_buckets
    return 1

// ── 5. String Interning & Lookup Operations ───────────────────────────────────

// WHY: Interns string `s`. If already present, returns existing `symbol_id`.
//      If absent, registers `s`, allocates a new contiguous ID, and returns it.
fn string_pool_intern(pool, s)
    if pool == 0 return 0 - 1
    if s == 0
        s = ""

    h = string_hash(s)
    mask = pool.pool_capacity - 1
    b = h & mask

    // Traverse collision chain in bucket `b`
    cur = get(pool.pool_buckets, b)
    while cur != (0 - 1)
        if get(pool.pool_hashes, cur) == h
            if get(pool.pool_strings, cur) == s
                // Found existing interned symbol: return O(1) ID immediately
                return cur
        cur = get(pool.pool_next_chain, cur)

    // Check load factor (count / capacity >= 75%)
    if (pool.pool_count * 4) >= (pool.pool_capacity * 3)
        string_pool_resize(pool, pool.pool_capacity * 2)
        // Recalculate bucket after resize
        mask = pool.pool_capacity - 1
        b = h & mask

    new_id = pool.pool_count
    push(pool.pool_strings, s)
    push(pool.pool_hashes, h)

    old_head = get(pool.pool_buckets, b)
    push(pool.pool_next_chain, old_head)
    list_set(pool.pool_buckets, b, new_id)

    pool.pool_count = pool.pool_count + 1
    return new_id

// WHY: Looks up whether `s` is already interned without inserting it.
//      Returns `symbol_id` if found, or -1 if absent.
fn string_pool_lookup(pool, s)
    if pool == 0 or s == 0 return 0 - 1
    h = string_hash(s)
    mask = pool.pool_capacity - 1
    b = h & mask

    cur = get(pool.pool_buckets, b)
    while cur != (0 - 1)
        if get(pool.pool_hashes, cur) == h
            if get(pool.pool_strings, cur) == s
                return cur
        cur = get(pool.pool_next_chain, cur)

    return 0 - 1

// WHY: Returns 1 if string `s` is already interned, 0 otherwise.
fn string_pool_has(pool, s)
    id = string_pool_lookup(pool, s)
    if id != (0 - 1)
        return 1
    return 0

// WHY: Retrieves the original string for a given `symbol_id` in O(1) time.
fn string_pool_get(pool, symbol_id)
    if pool == 0 return ""
    if symbol_id < 0 or symbol_id >= pool.pool_count return ""
    return get(pool.pool_strings, symbol_id)

// WHY: Returns the total number of distinct interned strings.
fn string_pool_count(pool)
    if pool == 0 return 0
    return pool.pool_count

// WHY: Returns current hash table bucket capacity.
fn string_pool_capacity(pool)
    if pool == 0 return 0
    return pool.pool_capacity

// WHY: Resets the string pool to empty state for compiler phase reuse.
fn string_pool_clear(pool)
    if pool == 0 return 0
    cap = pool.pool_capacity
    pool.pool_count = 0
    pool.pool_strings = list()
    pool.pool_hashes = list()
    pool.pool_next_chain = list()
    pool.pool_buckets = list()
    i = 0
    while i < cap
        push(pool.pool_buckets, 0 - 1)
        i = i + 1
    return 1
