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

    count = len(intervals)
    i = 0
    found = 0
    while i < count
        iv = get(intervals, i)
        if iv.vreg_name == name
            if pos < iv.start_pos
                iv.start_pos = pos
            if pos > iv.end_pos
                iv.end_pos = pos
            if is_param == 1
                iv.is_param = 1
            found = 1
        i = i + 1

    if found == 0
        new_iv = live_interval_new(name, 0 - 1, pos, pos, is_param)
        push(intervals, new_iv)
    return intervals

fn live_interval_record_use intervals name pos
    // WHY: Records a read access to a virtual register. Extends the interval's
    //      end_pos to ensure the register remains live until at least this point.
    if name == ""
        return intervals

    count = len(intervals)
    i = 0
    found = 0
    while i < count
        iv = get(intervals, i)
        if iv.vreg_name == name
            live_interval_add_use(iv, pos)
            found = 1
        i = i + 1

    if found == 0
        // Variable used before explicit def (e.g. incoming global or uninitialized)
        new_iv = live_interval_new(name, 0 - 1, pos, pos, 0)
        push(new_iv.use_positions, pos)
        push(intervals, new_iv)
    return intervals

// ── 4. Call-Spanning Analysis ────────────────────────────────────────────────

fn live_interval_mark_calls intervals call_positions
    // WHY: A register live across a subroutine CALL must either be preserved
    //      in a callee-saved register or spilled to the stack frame, because
    //      caller-saved (scratch) registers are clobbered by the call ABI.
    iv_count = len(intervals)
    call_count = len(call_positions)
    i = 0
    while i < iv_count
        iv = get(intervals, i)
        spans = 0
        c = 0
        while c < call_count
            cp = get(call_positions, c)
            if cp >= iv.start_pos and cp <= iv.end_pos
                spans = 1
            c = c + 1
        iv.spans_call = spans
        i = i + 1
    return intervals

// ── 5. Linear Scan Ordering (Sort by Start Position) ──────────────────────────

fn live_interval_sort_by_start intervals
    // WHY: Linear scan register allocation processes intervals in increasing
    //      order of their start position. Stable insertion sort ensures O(N)
    //      performance for nearly sorted SSA linearizations.
    count = len(intervals)
    sorted = list()
    i = 0
    while i < count
        item = get(intervals, i)
        inserted = 0
        new_sorted = list()
        s_count = len(sorted)
        j = 0
        while j < s_count
            curr = get(sorted, j)
            if inserted == 0
                if item.start_pos < curr.start_pos or (item.start_pos == curr.start_pos and item.end_pos < curr.end_pos)
                    push(new_sorted, item)
                    inserted = 1
            push(new_sorted, curr)
            j = j + 1
        if inserted == 0
            push(new_sorted, item)
        sorted = new_sorted
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
