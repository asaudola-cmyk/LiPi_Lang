// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — LIVE INTERVAL ANALYSIS (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/regalloc/live_interval.lp
//
// WHY THIS MODULE:
// 1. Register allocation maps an unbounded set of virtual SSA registers onto a
//    strictly limited set of hardware silicon registers (e.g. 16 AMD64 registers,
//    31 AArch64 registers, 32 RISC-V registers).
// 2. To determine which virtual registers can share the same physical silicon register,
//    the compiler must compute the exact lifetime (live range) of each variable.
// 3. Two virtual registers can safely share the same physical register if and only if
//    their live intervals do not overlap.
// 4. Intervals that span subroutine CALL instructions must be identified early so the
//    allocator can assign callee-saved registers or plan stack spills across the call.
// ==============================================================================

// ── 1. Live Interval Data Structure ──────────────────────────────────────────
// WHY: Represents the continuous span of instruction positions where a virtual
//      register contains a valid, needed value.
struct LiveInterval
    vreg_name       // Name of virtual register (e.g. "%v0", "counter", "%param_0")
    vreg_id         // Numeric ID (-1 if identified purely by name)
    start_pos       // Monotonic instruction index where value is first defined
    end_pos         // Monotonic instruction index of last use
    assigned_reg    // Assigned hardware register ID (0..N-1), or -1 if spilled
    spill_slot      // Frame offset relative to base pointer (e.g. -8, -16)
    is_spilled      // 1 if spilled to memory stack frame, 0 if in register
    spans_call      // 1 if lifetime crosses one or more CALL instructions
    use_positions   // List of integer positions where register is read
    is_param        // 1 if function incoming argument, 0 for normal local

// ── 2. Constructor & Primitives ──────────────────────────────────────────────

fn live_interval_new name vreg_id start_pos end_pos is_param
    // WHY: Constructs a clean live interval initialized with def position.
    iv = LiveInterval()
    iv.vreg_name = name
    iv.vreg_id = vreg_id
    iv.start_pos = start_pos
    iv.end_pos = end_pos
    iv.assigned_reg = 0 - 1
    iv.spill_slot = 0
    iv.is_spilled = 0
    iv.spans_call = 0
    iv.use_positions = list()
    iv.is_param = is_param
    return iv

fn live_interval_add_use iv pos
    // WHY: Extends the interval endpoint to include a newly discovered use site.
    //      In SSA form, definitions precede uses; each use extends the live range.
    if pos > iv.end_pos
        iv.end_pos = pos
    push(iv.use_positions, pos)
    return iv

fn live_interval_covers iv pos
    // WHY: Checks if an instruction at 'pos' falls inside this variable's active span.
    if pos >= iv.start_pos and pos <= iv.end_pos
        return 1
    return 0

fn live_interval_overlaps a b
    // WHY: Two intervals conflict (interfere) if their active spans intersect.
    //      Overlapping intervals cannot share the same physical silicon register.
    if a.start_pos <= b.end_pos and b.start_pos <= a.end_pos
        return 1
    return 0

// ── 3. Interval Recording During IR Traversal ──────────────────────────────────

fn live_interval_record_def intervals name pos is_param
    // WHY: Records or updates the definition point of a virtual register.
    //      If the variable was already encountered, we update its start bound.
    if name == ""
        return intervals

    count = intervals.len()
    i = 0
    found = 0
    while i < count
        iv = intervals[i]
        if iv.vreg_name == name
            if pos < iv.start_pos
                iv.start_pos = pos
            if pos > iv.end_pos
                iv.end_pos = pos
            if is_param == 1
                iv.is_param = 1
            found = 1
            break
        i = i + 1

    if found == 0
        new_iv = live_interval_new(name, 0 - 1, pos, pos, is_param)
        push(intervals, new_iv)
    return intervals

fn live_interval_record_def_fast intervals iv_map name pos is_param
    // WHY: O(1) DICT0-indexed variant of live_interval_record_def for self-hosting speed.
    if name == ""
        return intervals
    if has_key(iv_map, name) == 1
        iv = iv_map[name]
        if pos < iv.start_pos
            iv.start_pos = pos
        if pos > iv.end_pos
            iv.end_pos = pos
        if is_param == 1
            iv.is_param = 1
        return intervals
    new_iv = live_interval_new(name, 0 - 1, pos, pos, is_param)
    push(intervals, new_iv)
    iv_map[name] = new_iv
    return intervals

fn live_interval_record_use intervals name pos
    // WHY: Records a read access to a virtual register. Extends the interval's
    //      end_pos to ensure the register remains live until at least this point.
    if name == ""
        return intervals

    count = intervals.len()
    i = 0
    found = 0
    while i < count
        iv = intervals[i]
        if iv.vreg_name == name
            live_interval_add_use(iv, pos)
            found = 1
            break
        i = i + 1

    if found == 0
        // Variable used before explicit def (e.g. incoming global or uninitialized)
        new_iv = live_interval_new(name, 0 - 1, pos, pos, 0)
        push(new_iv.use_positions, pos)
        push(intervals, new_iv)
    return intervals

fn live_interval_record_use_fast intervals iv_map name pos
    // WHY: O(1) DICT0-indexed variant of live_interval_record_use for self-hosting speed.
    if name == ""
        return intervals
    if has_key(iv_map, name) == 1
        live_interval_add_use(iv_map[name], pos)
        return intervals
    new_iv = live_interval_new(name, 0 - 1, pos, pos, 0)
    push(new_iv.use_positions, pos)
    push(intervals, new_iv)
    iv_map[name] = new_iv
    return intervals

// ── 4. Call-Spanning Analysis ────────────────────────────────────────────────

fn live_interval_mark_calls intervals call_positions
    // WHY: A register live across a subroutine CALL must either be preserved
    //      in a callee-saved register or spilled to the stack frame, because
    //      caller-saved (scratch) registers are clobbered by the call ABI.
    //      Uses O(log C) binary search over monotonically ascending call_positions.
    iv_count = intervals.len()
    call_count = call_positions.len()
    if call_count == 0
        i0 = 0
        while i0 < iv_count
            intervals[i0].spans_call = 0
            i0 = i0 + 1
        return intervals
    end
    i = 0
    while i < iv_count
        iv = intervals[i]
        st = iv.start_pos
        en = iv.end_pos
        spans = 0
        if en > st + 1
            // Binary search for first call position strictly > st
            lo = 0
            hi = call_count
            while lo < hi
                mid = (lo + hi) / 2
                if call_positions[mid] <= st
                    lo = mid + 1
                else
                    hi = mid
                end
            end
            if lo < call_count and call_positions[lo] < en
                spans = 1
            end
        end
        iv.spans_call = spans
        i = i + 1
    return intervals

// ── 5. Linear Scan Ordering (Sort by Start Position) ──────────────────────────

fn live_interval_sort_by_start intervals
    // WHY: Linear scan register allocation processes intervals in increasing
    //      order of their start position. In-place stable insertion sort gives
    //      O(N) time and O(1) extra allocations for nearly-sorted SSA intervals.
    count = intervals.len()
    sorted = list()
    i = 0
    while i < count
        push(sorted, intervals[i])
        i = i + 1
    i = 1
    while i < count
        key = sorted[i]
        k_st = key.start_pos
        k_en = key.end_pos
        j = i - 1
        while j >= 0
            curr = sorted[j]
            if k_st < curr.start_pos or (k_st == curr.start_pos and k_en < curr.end_pos)
                list_set(sorted, j + 1, curr)
                j = j - 1
            else
                break
            end
        end
        list_set(sorted, j + 1, key)
        i = i + 1
    return sorted

// ── 6. Verification Self-Test ────────────────────────────────────────────────

fn test_live_interval_subsystem
    intervals = list()
    // Def param_a at pos 0, used at pos 10
    live_interval_record_def(intervals, "param_a", 0, 1)
    live_interval_record_use(intervals, "param_a", 10)

    // Def v0 at pos 2, used at pos 6
    live_interval_record_def(intervals, "v0", 2, 0)
    live_interval_record_use(intervals, "v0", 6)

    // Def v1 at pos 8, used at pos 14
    live_interval_record_def(intervals, "v1", 8, 0)
    live_interval_record_use(intervals, "v1", 14)

    // Mark calls at pos 4 and pos 12
    calls = list()
    push(calls, 4)
    push(calls, 12)
    live_interval_mark_calls(intervals, calls)

    sorted = live_interval_sort_by_start(intervals)
    first = get(sorted, 0)
    if first.vreg_name != "param_a"
        say "FAIL: live_interval sorting order mismatch"
        return 0

    if first.spans_call != 1
        say "FAIL: param_a expected to span calls"
        return 0

    return 1

// test_live_interval_subsystem()
