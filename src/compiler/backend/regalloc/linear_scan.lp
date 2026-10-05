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
    cnt = arr.len()
    i = 0
    while i < cnt
        if arr[i] == val
            return 1
        i = i + 1
    return 0

fn list_remove_at arr idx
    // WHY: Pure functional list extraction without modifying source buffer.
    res = list()
    cnt = arr.len()
    i = 0
    while i < cnt
        if i != idx
            push(res, arr[i])
        i = i + 1
    return res

// ── 3. Linear Scan Allocation Core Algorithm ─────────────────────────────────

fn linear_scan_allocate intervals caller_regs callee_regs word_size
    // WHY: Primary allocation loop. Takes sorted intervals and target register pools.
    //      Outputs assignment maps and calculates spill requirements.
    
    // Clone register pools to mutable worklists
    free_caller = list()
    c_count = caller_regs.len()
    i = 0
    while i < c_count
        push(free_caller, caller_regs[i])
        i = i + 1

    free_callee = list()
    cl_count = callee_regs.len()
    i = 0
    while i < cl_count
        push(free_callee, callee_regs[i])
        i = i + 1

    active = list()                 // Intervals currently holding a physical register
    used_callee = list()            // Set of callee-saved registers that need saving
    spill_count = 0
    spill_offset = 0 - word_size    // First spill slot (e.g. -8 on 64-bit)

    count = intervals.len()
    idx = 0
    while idx < count
        cur = intervals[idx]

        // ── Step 1: Expire Old Intervals ─────────────────────────────────────
        // Free registers belonging to intervals that ended before cur.start_pos
        new_active = list()
        a_count = active.len()
        a_i = 0
        while a_i < a_count
            act = active[a_i]
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
            // Call-crossing interval: Strictly allocate Callee-Saved registers.
            // WHY: Caller-saved registers are clobbered across CALL instructions.
            // If callee-saved registers are exhausted, the interval must spill to stack frame.
            if free_callee.len() > 0
                last_idx = free_callee.len() - 1
                assigned_reg = free_callee[last_idx]
                free_callee = list_remove_at(free_callee, last_idx)
                allocated = 1
                if contains_int(used_callee, assigned_reg) == 0
                    push(used_callee, assigned_reg)
                end
            end
        else
            // Leaf interval: Prefer Caller-Saved
            if free_caller.len() > 0
                last_idx = free_caller.len() - 1
                assigned_reg = free_caller[last_idx]
                free_caller = list_remove_at(free_caller, last_idx)
                allocated = 1
            else
                // Fallback to Callee-Saved if caller-saved registers exhausted
                if free_callee.len() > 0
                    last_idx = free_callee.len() - 1
                    assigned_reg = free_callee[last_idx]
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
            act_len = active.len()
            k = 0
            while k < act_len
                item = active[k]
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
            if active.len() > 0
                spill_cand_idx = active.len() - 1

            if spill_cand_idx >= 0
                cand = active[spill_cand_idx]
                if cand.end_pos > cur.end_pos
                    // Evict candidate: give candidate's physical register to cur
                    cand_reg = cand.assigned_reg
                    cand.is_spilled = 1
                    cand.spill_slot = spill_offset
                    cand.assigned_reg = 0 - 1
                    spill_offset = spill_offset - word_size
                    spill_count = spill_count + 1

                    cur.assigned_reg = cand_reg
                    cur.is_spilled = 0
                    cur.spill_slot = 0

                    // Remove candidate from active and insert cur
                    trimmed_act = list_remove_at(active, spill_cand_idx)
                    ins_act = list()
                    inserted = 0
                    t_len = trimmed_act.len()
                    k = 0
                    while k < t_len
                        item = trimmed_act[k]
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

// ── 3b. IRFunction Linear Scan Allocator ──────────────────────────────────────

fn linear_scan_allocate_function fn_obj caller_regs callee_regs word_size
    // WHY: Performs full live-range analysis and Poletto-Sarkar linear scan allocation
    // over all basic blocks and instructions of an SSA IRFunction.
    // Skips dead instructions pruned by DCE, accurately reflects register pressure,
    // and prioritizes call-crossing virtual registers into callee-saved registers.
    if fn_obj == 0
        res = LinearScanResult()
        res.intervals = list()
        res.used_callee_saved = list()
        res.spill_count = 0
        res.max_spill_offset = 0
        return res

    intervals = list()
    call_positions = list()

    // 1. Record incoming formal parameters at position 0
    pi = 0
    while pi < fn_obj.params.len()
        p_val = fn_obj.params[pi]
        if p_val != 0
            live_interval_record_def(intervals, p_val.id, 0, 1)
        pi = pi + 1

    // 2. Monotonic traversal over all basic blocks and instructions
    pos = 1
    bi = 0
    while bi < fn_obj.blocks.len()
        bb = fn_obj.blocks[bi]
        ii = 0
        while ii < bb.instructions.len()
            inst = bb.instructions[ii]
            if inst.is_dead == 0
                // Mark call positions for ABI caller-vs-callee saved prioritization (19 is OP_CALL)
                if inst.op == 19 or inst.op == OP_CALL
                    push(call_positions, pos)

                // Record operand read accesses (1 is VAL_KIND_INST, 3 is VAL_KIND_ARG)
                // WHY: Untyped field resolution in the 1-pass backend collides on 'kind' (matching ASTNode.kind at offset 0).
                // Checking 'val_kind' and '%' register prefix ensures virtual registers/arguments are identified reliably.
                oi = 0
                while oi < inst.operands.len()
                    opnd = inst.operands[oi]
                    if opnd != 0
                        is_reg_opnd = 0
                        if opnd.val_kind == 1 or opnd.val_kind == 3
                            is_reg_opnd = 1
                        elif len(opnd.id) > 0 and mem_byte_read(opnd.id, 0) == 37
                            is_reg_opnd = 1
                        elif opnd.kind == 1 or opnd.kind == 3 or opnd.kind == VAL_KIND_INST or opnd.kind == VAL_KIND_ARG
                            is_reg_opnd = 1
                        end
                        if is_reg_opnd == 1
                            live_interval_record_use(intervals, opnd.id, pos)
                        end
                    end
                    oi = oi + 1

                // Record instruction result definition
                // WHY: Instructions produce virtual registers. Checking val_kind, '%' prefix, or non-empty id registers def.
                if inst.result != 0
                    is_res_vreg = 0
                    if inst.result.val_kind == 1
                        is_res_vreg = 1
                    elif len(inst.result.id) > 0 and mem_byte_read(inst.result.id, 0) == 37
                        is_res_vreg = 1
                    elif inst.result.kind == 1 or inst.result.kind == VAL_KIND_INST
                        is_res_vreg = 1
                    end
                    if is_res_vreg == 1
                        live_interval_record_def(intervals, inst.result.id, pos, 0)
                    end
                end

                pos = pos + 1
            ii = ii + 1
        bi = bi + 1

    // 3. Mark call-spanning intervals
    live_interval_mark_calls(intervals, call_positions)

    // 4. Sort intervals by start position for deterministic single-pass allocation
    sorted = live_interval_sort_by_start(intervals)

    // 5. Execute Linear Scan allocation algorithm
    return linear_scan_allocate(sorted, caller_regs, callee_regs, word_size)

// ── 4. Verification Self-Test ────────────────────────────────────────────────

fn create_test_interval name start_p end_p spans_c
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
    push(intervals, create_test_interval("v0", 0, 10, 0))
    push(intervals, create_test_interval("v1", 2, 8, 1))  // spans call -> gets callee 12
    push(intervals, create_test_interval("v2", 4, 12, 0))
    push(intervals, create_test_interval("v3", 6, 14, 0)) // 4th concurrent -> spills!

    res = linear_scan_allocate(intervals, callers, callees, 8)

    if res.spill_count != 1
        say "FAIL: Expected exactly 1 spill, got: " + str(res.spill_count)
        return 0

    if len(res.used_callee_saved) != 1
        say "FAIL: Expected 1 used callee register"
        return 0

    return 1

// test_linear_scan_subsystem()
