// ==============================================================================
// 👑 LIPI FIRST 1.0.0 FREESTANDING CORE SILICON PRIMITIVES: BITSET (src/core/bitset.lp)
// ⚡ 100% Pure Lipi Sovereign Implementation | Zero C | Zero Libc | Zero Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Compiler middle-ends and backends execute dense set mathematics on registers,
//    variables, and basic block identifiers:
//    - Dataflow Analysis (LiveIn, LiveOut, Def, Use equations).
//    - Register Allocation (Interference Graph Coloring, Chaitin-Briggs, Linear Scan).
//    - Dominance Frontiers and Loop Invariant Code Motion (LICM).
// 2. Representing these sets as hash sets or integer lists requires 8-64 bytes per element
//    and causes endless memory allocations and pointer chasing.
// 3. The Lipi BitSet packs 64 boolean flags into each 64-bit silicon quadword.
//    - Set Union, Intersection, and Difference execute in single physical CPU instructions
//      (OR, AND, AND NOT).
//    - Population count (Hamming weight) and Find-First-Set (CTZ) enable instant scanning
//      of available registers and live variable sets.
// ==============================================================================

struct BitSet
    bitset_num_bits
    bitset_num_words
    bitset_words

// ── 1. BitSet Lifecycle & Allocation ──────────────────────────────────────────

// WHY: Instantiates a compact bitset capable of storing `num_bits` boolean values.
//      Computes exact 64-bit word count: `(num_bits + 63) / 64`.
fn bitset_new(num_bits)
    bs = BitSet()
    nb = num_bits
    if nb <= 0
        nb = 64

    nw = (nb + 63) / 64
    bs.bitset_num_bits = nb
    bs.bitset_num_words = nw
    bs.bitset_words = list()

    i = 0
    while i < nw
        push(bs.bitset_words, 0)
        i = i + 1

    return bs

// WHY: Creates an exact, independent deep copy of an existing bitset.
fn bitset_clone(bs)
    if bs == 0 return 0
    clone = BitSet()
    clone.bitset_num_bits = bs.bitset_num_bits
    clone.bitset_num_words = bs.bitset_num_words
    clone.bitset_words = list()

    i = 0
    nw = bs.bitset_num_words
    while i < nw
        push(clone.bitset_words, get(bs.bitset_words, i))
        i = i + 1

    return clone

// ── 2. Single-Bit Manipulation ────────────────────────────────────────────────

// WHY: Sets the bit at index `bit_idx` to 1.
//      Executes via word lookup and bitwise OR: `word | (1 << (bit_idx % 64))`.
fn bitset_set(bs, bit_idx)
    if bs == 0 return 0
    if bit_idx < 0 or bit_idx >= bs.bitset_num_bits return 0

    w_idx = bit_idx / 64
    bit_pos = bit_idx % 64

    cur = get(bs.bitset_words, w_idx)
    mask = 1 << bit_pos
    list_set(bs.bitset_words, w_idx, cur | mask)
    return 1

// WHY: Clears the bit at index `bit_idx` to 0.
//      Executes via word lookup and bitwise AND with inverted mask: `word & ~(1 << bit_pos)`.
fn bitset_clear(bs, bit_idx)
    if bs == 0 return 0
    if bit_idx < 0 or bit_idx >= bs.bitset_num_bits return 0

    w_idx = bit_idx / 64
    bit_pos = bit_idx % 64

    cur = get(bs.bitset_words, w_idx)
    mask = ~(1 << bit_pos)
    list_set(bs.bitset_words, w_idx, cur & mask)
    return 1

// WHY: Tests whether the bit at index `bit_idx` is set (returns 1) or cleared (returns 0).
fn bitset_test(bs, bit_idx)
    if bs == 0 return 0
    if bit_idx < 0 or bit_idx >= bs.bitset_num_bits return 0

    w_idx = bit_idx / 64
    bit_pos = bit_idx % 64

    cur = get(bs.bitset_words, w_idx)
    return (cur >> bit_pos) & 1

// WHY: Inverts (flips) the bit at index `bit_idx` via bitwise XOR.
fn bitset_toggle(bs, bit_idx)
    if bs == 0 return 0
    if bit_idx < 0 or bit_idx >= bs.bitset_num_bits return 0

    w_idx = bit_idx / 64
    bit_pos = bit_idx % 64

    cur = get(bs.bitset_words, w_idx)
    mask = 1 << bit_pos
    list_set(bs.bitset_words, w_idx, cur ^ mask)
    return 1

// ── 3. Bulk State Transitions ─────────────────────────────────────────────────

// WHY: Clears all bits in the bitset to 0 in O(num_words) time.
fn bitset_reset_all(bs)
    if bs == 0 return 0
    nw = bs.bitset_num_words
    i = 0
    while i < nw
        list_set(bs.bitset_words, i, 0)
        i = i + 1
    return 1

// WHY: Sets all valid bits in the bitset to 1.
//      Applies masking on the final word so extraneous bits beyond `bitset_num_bits` remain 0.
fn bitset_fill(bs)
    if bs == 0 return 0
    nw = bs.bitset_num_words
    i = 0
    while i < nw
        list_set(bs.bitset_words, i, ~0)
        i = i + 1

    // Mask off excess bits in highest word
    excess = (nw * 64) - bs.bitset_num_bits
    if excess > 0
        valid_bits = 64 - excess
        last_mask = (1 << valid_bits) - 1
        last_idx = nw - 1
        cur_last = get(bs.bitset_words, last_idx)
        list_set(bs.bitset_words, last_idx, cur_last & last_mask)

    return 1

// ── 4. Set Algebraic Operations (Single-Cycle CPU Instructions) ───────────────

// WHY: Computes Set Union (`dest = dest ∪ src`).
//      Translates directly to physical CPU `OR` instructions across all words.
//      Standard in Compiler Liveness Analysis: `LiveOut = ⋃ (LiveIn of successors)`.
fn bitset_union(dest, src)
    if dest == 0 or src == 0 return 0
    nw = dest.bitset_num_words
    if src.bitset_num_words < nw
        nw = src.bitset_num_words

    i = 0
    while i < nw
        d = get(dest.bitset_words, i)
        s = get(src.bitset_words, i)
        list_set(dest.bitset_words, i, d | s)
        i = i + 1
    return 1

// WHY: Computes Set Intersection (`dest = dest ∩ src`).
//      Translates directly to physical CPU `AND` instructions across all words.
fn bitset_intersect(dest, src)
    if dest == 0 or src == 0 return 0
    nw = dest.bitset_num_words
    if src.bitset_num_words < nw
        nw = src.bitset_num_words

    i = 0
    while i < nw
        d = get(dest.bitset_words, i)
        s = get(src.bitset_words, i)
        list_set(dest.bitset_words, i, d & s)
        i = i + 1

    // Any remaining words in dest beyond src become 0
    while i < dest.bitset_num_words
        list_set(dest.bitset_words, i, 0)
        i = i + 1

    return 1

// WHY: Computes Set Difference (`dest = dest \ src` or `dest & ~src`).
//      Critical for liveness equations: `LiveIn = Use ∪ (LiveOut \ Def)`.
fn bitset_difference(dest, src)
    if dest == 0 or src == 0 return 0
    nw = dest.bitset_num_words
    if src.bitset_num_words < nw
        nw = src.bitset_num_words

    i = 0
    while i < nw
        d = get(dest.bitset_words, i)
        s = get(src.bitset_words, i)
        list_set(dest.bitset_words, i, d & (~s))
        i = i + 1
    return 1

// ── 5. Predicates & Comparisons ───────────────────────────────────────────────

// WHY: Tests whether two bitsets are identical bit-for-bit.
fn bitset_equals(bs1, bs2)
    if bs1 == 0 and bs2 == 0 return 1
    if bs1 == 0 or bs2 == 0 return 0
    if bs1.bitset_num_bits != bs2.bitset_num_bits return 0

    nw = bs1.bitset_num_words
    i = 0
    while i < nw
        if get(bs1.bitset_words, i) != get(bs2.bitset_words, i)
            return 0
        i = i + 1
    return 1

// WHY: Tests whether all bits in the bitset are zero (empty set).
fn bitset_is_empty(bs)
    if bs == 0 return 1
    nw = bs.bitset_num_words
    i = 0
    while i < nw
        if get(bs.bitset_words, i) != 0
            return 0
        i = i + 1
    return 1

// WHY: Tests whether `sub` is a subset of `parent` (`sub ⊆ parent`).
//      True if and only if `(sub & ~parent) == 0` across all words.
fn bitset_is_subset(sub, parent)
    if sub == 0 return 1
    if parent == 0 return bitset_is_empty(sub)

    nw = sub.bitset_num_words
    if parent.bitset_num_words < nw
        nw = parent.bitset_num_words

    i = 0
    while i < nw
        s = get(sub.bitset_words, i)
        p = get(parent.bitset_words, i)
        if (s & (~p)) != 0
            return 0
        i = i + 1

    // If sub has more words than parent, those extra words must all be 0
    while i < sub.bitset_num_words
        if get(sub.bitset_words, i) != 0
            return 0
        i = i + 1

    return 1

// ── 6. Population Count & Bit Scanning ────────────────────────────────────────

// WHY: Internal 64-bit Hamming weight helper using 32-bit partitioned Kernighan loops
//      to eliminate negative two's-complement arithmetic quirks.
fn bitset_word_popcount(w)
    low = w & 4294967295
    high = (w >> 32) & 4294967295
    cnt = 0
    while low != 0
        low = low & (low - 1)
        cnt = cnt + 1
    while high != 0
        high = high & (high - 1)
        cnt = cnt + 1
    return cnt

// WHY: Returns the total number of set bits (1s) across the entire bitset.
fn bitset_popcount(bs)
    if bs == 0 return 0
    total = 0
    nw = bs.bitset_num_words
    i = 0
    while i < nw
        w = get(bs.bitset_words, i)
        if w != 0
            total = total + bitset_word_popcount(w)
        i = i + 1
    return total

// WHY: Finds the lowest bit index that is set to 1 (Count Trailing Zeros scan).
//      Used by register allocators to pick the first available free physical register.
//      Returns -1 if the bitset contains zero set bits.
fn bitset_find_first_set(bs)
    if bs == 0 return 0 - 1
    nw = bs.bitset_num_words
    w_idx = 0
    while w_idx < nw
        w = get(bs.bitset_words, w_idx)
        if w != 0
            // Test 32-bit low half
            low = w & 4294967295
            if low != 0
                b = 0
                while b < 32
                    if ((low >> b) & 1) == 1
                        idx = (w_idx * 64) + b
                        if idx < bs.bitset_num_bits return idx
                        return 0 - 1
                    b = b + 1

            // Test 32-bit high half
            high = (w >> 32) & 4294967295
            if high != 0
                b = 0
                while b < 32
                    if ((high >> b) & 1) == 1
                        idx = (w_idx * 64) + 32 + b
                        if idx < bs.bitset_num_bits return idx
                        return 0 - 1
                    b = b + 1
        w_idx = w_idx + 1

    return 0 - 1
