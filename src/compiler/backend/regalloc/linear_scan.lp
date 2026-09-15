// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — LINEAR SCAN REGISTER ALLOCATOR (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/regalloc/linear_scan.lp
//
// WHY THIS MODULE:
// 1. Traditional Graph Coloring register allocators build an O(V^2) interference
//    graph and solve an NP-complete K-coloring problem, which produces high compilation
//    latency and large memory footprint during self-hosting.
// 2. Linear Scan (Poletto & Sarkar) allocates physical registers in a single O(N)
//    forward pass over intervals sorted by start position, ideal for high-throughput
//    compilers and bare-metal self-hosting.
// 3. Spilling heuristic: When silicon registers are exhausted, the interval with the
//    furthest end position is evicted to stack memory, minimizing register contention
//    in high-frequency loop kernels.
// 4. ABI-Aware Allocation: Variables active across subroutine calls are prioritized
//    into callee-saved registers; local leaf variables are prioritized into caller-saved
//    scratch registers to prevent unnecessary stack spills in the prologue.
// ==============================================================================

// ── 1. Data Structures ───────────────────────────────────────────────────────

struct LiveInterval
    vreg_name           // Name of virtual register (e.g. "%v0", "counter")
    vreg_id             // Numeric ID (-1 if identified purely by name)
    start_pos           // Monotonic instruction index where value is first defined
    end_pos             // Monotonic instruction index of last use
    assigned_reg        // Assigned hardware register ID (0..N-1), or -1 if spilled
    spill_slot          // Frame offset relative to base pointer (e.g. -8, -16)
    is_spilled          // 1 if spilled to memory stack frame, 0 if in register
    spans_call          // 1 if lifetime crosses one or more CALL instructions
    use_positions       // List of integer positions where register is read
    is_param            // 1 if function incoming argument, 0 for normal local

struct LinearScanResult
    intervals           // List of allocated/spilled LiveInterval objects
    used_callee_saved   // List of unique callee-saved physical registers assigned
    spill_count         // Total number of virtual registers evicted to stack
    max_spill_offset    // Deepest stack frame displacement in bytes

// ── 2. Helper Utilities ──────────────────────────────────────────────────────

fn contains_int arr val
    // WHY: Checks if an integer already exists in a list (e.g. used callee registers).
    cnt = len(arr)
    i = 0
    while i < cnt
        if get(arr, i) == val
            return 1
        i = i + 1
    return 0

fn list_remove_at arr idx
    // WHY: Pure functional list extraction without modifying source buffer.
    res = list()
    cnt = len(arr)
    i = 0
    while i < cnt
        if i != idx
            push(res, get(arr, i))
        i = i + 1
    return res

// ── 3. Linear Scan Allocation Core Algorithm ─────────────────────────────────

fn linear_scan_allocate intervals caller_regs callee_regs word_size
    // WHY: Primary allocation loop. Takes sorted intervals and target register pools.
    //      Outputs assignment maps and calculates spill requirements.
    
    // Clone register pools to mutable worklists
    free_caller = list()
    c_count = len(caller_regs)
    i = 0
    while i < c_count
        push(free_caller, get(caller_regs, i))
        i = i + 1

    free_callee = list()
    cl_count = len(callee_regs)
    i = 0
    while i < cl_count
        push(free_callee, get(callee_regs, i))
        i = i + 1

    active = list()                 // Intervals currently holding a physical register
    used_callee = list()            // Set of callee-saved registers that need saving
    spill_count = 0
    spill_offset = 0 - word_size    // First spill slot (e.g. -8 on 64-bit)

    count = len(intervals)
    idx = 0
    while idx < count
        cur = get(intervals, idx)

        // ── Step 1: Expire Old Intervals ─────────────────────────────────────
        // Free registers belonging to intervals that ended before cur.start_pos
        new_active = list()
        a_count = len(active)
        a_i = 0
        while a_i < a_count
            act = get(active, a_i)
            if act.end_pos < cur.start_pos
                // Register is now free; return it to the corresponding pool
                reg_id = act.assigned_reg
                if contains_int(callee_regs, reg_id) == 1
                    push(free_callee, reg_id)
                else
                    push(free_caller, reg_id)
            else
                push(new_active, act)
            a_i = a_i + 1
        active = new_active

        // ── Step 2: Attempt Allocation from Preferred Pool ────────────────────
        assigned_reg = 0 - 1
        allocated = 0

        if cur.spans_call == 1
            // Call-crossing interval: Prefer Callee-Saved
            if len(free_callee) > 0
                last_idx = len(free_callee) - 1
                assigned_reg = get(free_callee, last_idx)
                free_callee = list_remove_at(free_callee, last_idx)
                allocated = 1
                if contains_int(used_callee, assigned_reg) == 0
                    push(used_callee, assigned_reg)
            else
                // Fallback to Caller-Saved if no callee-saved available
                if len(free_caller) > 0
                    last_idx = len(free_caller) - 1
                    assigned_reg = get(free_caller, last_idx)
                    free_caller = list_remove_at(free_caller, last_idx)
                    allocated = 1
        else
            // Leaf interval: Prefer Caller-Saved
            if len(free_caller) > 0
                last_idx = len(free_caller) - 1
                assigned_reg = get(free_caller, last_idx)
                free_caller = list_remove_at(free_caller, last_idx)
                allocated = 1
            else
                // Fallback to Callee-Saved if caller-saved registers exhausted
                if len(free_callee) > 0
                    last_idx = len(free_callee) - 1
                    assigned_reg = get(free_callee, last_idx)
                    free_callee = list_remove_at(free_callee, last_idx)
                    allocated = 1
                    if contains_int(used_callee, assigned_reg) == 0
                        push(used_callee, assigned_reg)

        // ── Step 3: Handle Register Assignment or Eviction / Spill ────────────
        if allocated == 1
            cur.assigned_reg = assigned_reg
            cur.is_spilled = 0
            cur.spill_slot = 0

            // Insert into active list sorted by end_pos ascending
            ins_act = list()
            inserted = 0
            act_len = len(active)
            k = 0
            while k < act_len
                item = get(active, k)
                if inserted == 0 and cur.end_pos < item.end_pos
                    push(ins_act, cur)
                    inserted = 1
                push(ins_act, item)
                k = k + 1
            if inserted == 0
                push(ins_act, cur)
            active = ins_act
        else
            // Register starvation: Must spill either cur or an active interval
            spill_cand_idx = 0 - 1
            if len(active) > 0
                spill_cand_idx = len(active) - 1

            if spill_cand_idx >= 0
                cand = get(active, spill_cand_idx)
                if cand.end_pos > cur.end_pos
                    // Evict candidate: give candidate's physical register to cur
                    cand.is_spilled = 1
                    cand.spill_slot = spill_offset
                    cand.assigned_reg = 0 - 1
                    spill_offset = spill_offset - word_size
                    spill_count = spill_count + 1

                    cur.assigned_reg = cand.assigned_reg
                    cur.is_spilled = 0
                    cur.spill_slot = 0

                    // Remove candidate from active and insert cur
                    trimmed_act = list_remove_at(active, spill_cand_idx)
                    ins_act = list()
                    inserted = 0
                    t_len = len(trimmed_act)
                    k = 0
                    while k < t_len
                        item = get(trimmed_act, k)
                        if inserted == 0 and cur.end_pos < item.end_pos
                            push(ins_act, cur)
                            inserted = 1
                        push(ins_act, item)
                        k = k + 1
                    if inserted == 0
                        push(ins_act, cur)
                    active = ins_act
                else
                    // Spill cur directly
                    cur.is_spilled = 1
                    cur.assigned_reg = 0 - 1
                    cur.spill_slot = spill_offset
                    spill_offset = spill_offset - word_size
                    spill_count = spill_count + 1
            else
                // No active intervals (zero registers available)
                cur.is_spilled = 1
                cur.assigned_reg = 0 - 1
                cur.spill_slot = spill_offset
                spill_offset = spill_offset - word_size
                spill_count = spill_count + 1

        idx = idx + 1

    result = LinearScanResult()
    result.intervals = intervals
    result.used_callee_saved = used_callee
    result.spill_count = spill_count
    result.max_spill_offset = 0 - spill_offset
    return result

// ── 4. Verification Self-Test ────────────────────────────────────────────────

fn mock_interval name start_p end_p spans_c
    iv = LiveInterval()
    iv.vreg_name = name
    iv.vreg_id = 0 - 1
    iv.start_pos = start_p
    iv.end_pos = end_p
    iv.assigned_reg = 0 - 1
    iv.spill_slot = 0
    iv.is_spilled = 0
    iv.spans_call = spans_c
    iv.use_positions = list()
    iv.is_param = 0
    return iv

fn test_linear_scan_subsystem
    // Set up 2 scratch registers [7, 6] and 1 callee register [12]
    callers = list()
    push(callers, 7)
    push(callers, 6)

    callees = list()
    push(callees, 12)

    // Create 4 overlapping intervals to force 1 spill
    intervals = list()
    push(intervals, mock_interval("v0", 0, 10, 0))
    push(intervals, mock_interval("v1", 2, 8, 1))  // spans call -> gets callee 12
    push(intervals, mock_interval("v2", 4, 12, 0))
    push(intervals, mock_interval("v3", 6, 14, 0)) // 4th concurrent -> spills!

    res = linear_scan_allocate(intervals, callers, callees, 8)

    if res.spill_count != 1
        say "FAIL: Expected exactly 1 spill, got: " + str(res.spill_count)
        return 0

    if len(res.used_callee_saved) != 1
        say "FAIL: Expected 1 used callee register"
        return 0

    return 1

// test_linear_scan_subsystem()
