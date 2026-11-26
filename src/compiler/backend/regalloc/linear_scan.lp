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
    spilled_active = list()         // Spilled intervals still live (for stack slot recycling on expiry)
    free_spill_slots = list()       // Recycled frame offsets from dead spilled intervals (cuts stack bloat!)
    used_callee = list()            // Set of callee-saved registers that need saving
    spill_count = 0
    spill_offset = 0 - word_size    // First spill slot (e.g. -8 on 64-bit)

    count = intervals.len()
    idx = 0
    while idx < count
        cur = intervals[idx]

        // ── Step 1: Expire Old Intervals (Registers AND Recycled Stack Spill Slots) ──
        // WHY: `active` is maintained sorted ascending by end_pos; O(1) fast-path skips
        // allocation completely when the earliest active interval has not expired yet.
        a_count = active.len()
        if a_count > 0 and active[0].end_pos <= cur.start_pos
            new_active = list()
            a_i = 0
            while a_i < a_count
                act = active[a_i]
                // WHY: Require act.start_pos < cur.start_pos so zero-length intervals defined
                // simultaneously at the same start_pos (e.g. unused vs used prologue params at pos 0)
                // NEVER alias the same physical register and clobber each other!
                if act.end_pos <= cur.start_pos and act.start_pos < cur.start_pos
                    reg_id = act.assigned_reg
                    if contains_int(callee_regs, reg_id) == 1
                        push(free_callee, reg_id)
                    else
                        push(free_caller, reg_id)
                    end
                else
                    push(new_active, act)
                end
                a_i = a_i + 1
            end
            active = new_active
        end

        sp_count = spilled_active.len()
        if sp_count > 0
            has_sp_exp = 0
            sp_i = 0
            while sp_i < sp_count
                if spilled_active[sp_i].end_pos <= cur.start_pos and spilled_active[sp_i].start_pos < cur.start_pos
                    has_sp_exp = 1
                    break
                end
                sp_i = sp_i + 1
            end
            if has_sp_exp == 1
                new_spilled = list()
                sp_i = 0
                while sp_i < sp_count
                    s_iv = spilled_active[sp_i]
                    if s_iv.end_pos <= cur.start_pos and s_iv.start_pos < cur.start_pos
                        push(free_spill_slots, s_iv.spill_slot)
                    else
                        push(new_spilled, s_iv)
                    end
                    sp_i = sp_i + 1
                end
                spilled_active = new_spilled
            end
        end

        // ── Step 2: Attempt Allocation from Preferred Pool ────────────────────
        assigned_reg = 0 - 1
        allocated = 0

        if cur.spans_call == 1
            // Call-crossing interval: Strictly allocate Callee-Saved registers.
            // WHY: Caller-saved registers are clobbered across CALL instructions.
            // If callee-saved registers are exhausted, the interval must spill to stack frame.
            if free_callee.len() > 0
                assigned_reg = list_pop(free_callee)
                allocated = 1
                if contains_int(used_callee, assigned_reg) == 0
                    push(used_callee, assigned_reg)
                end
            end
        else
            // Leaf interval: Prefer Caller-Saved
            if free_caller.len() > 0
                assigned_reg = list_pop(free_caller)
                allocated = 1
            else
                // Fallback to Callee-Saved if caller-saved registers exhausted
                if free_callee.len() > 0
                    assigned_reg = list_pop(free_callee)
                    allocated = 1
                    if contains_int(used_callee, assigned_reg) == 0
                        push(used_callee, assigned_reg)
                    end
                end
            end
        end

        // ── Step 3: Handle Register Assignment or Eviction / Spill ────────────
        if allocated == 1
            cur.assigned_reg = assigned_reg
            cur.is_spilled = 0
            cur.spill_slot = 0

            // In-place insertion into active list sorted by end_pos ascending (zero heap alloc)
            push(active, cur)
            k_ins = active.len() - 1
            while k_ins > 0
                prev_it = active[k_ins - 1]
                if prev_it.end_pos > cur.end_pos
                    list_set(active, k_ins, prev_it)
                    k_ins = k_ins - 1
                else
                    break
                end
            end
            list_set(active, k_ins, cur)
        else
            // Register starvation: Use-density + furthest-end eviction with spill-slot recycling!
            // WHY: Never assign a caller-saved register to a call-spanning interval on eviction,
            // and keep heavily-used hot loop variables in physical registers by comparing
            // spill cost = (uses * 1024) / span_len alongside end_pos.
            cur_uses = 1
            if cur.use_positions != 0 and cur.use_positions.len() > 0
                cur_uses = cur.use_positions.len()
            end
            cur_span = cur.end_pos - cur.start_pos + 1
            if cur_span < 1 cur_span = 1 end
            cur_weight = (cur_uses * 1024) / cur_span

            spill_cand_idx = 0 - 1
            best_evict_score = 0 - 1
            sc_i = active.len() - 1
            while sc_i >= 0
                sc_cand = active[sc_i]
                abi_ok = 1
                if cur.spans_call == 1 and contains_int(callee_regs, sc_cand.assigned_reg) == 0
                    abi_ok = 0
                end
                if abi_ok == 1
                    c_uses = 1
                    if sc_cand.use_positions != 0 and sc_cand.use_positions.len() > 0
                        c_uses = sc_cand.use_positions.len()
                    end
                    c_span = sc_cand.end_pos - sc_cand.start_pos + 1
                    if c_span < 1 c_span = 1 end
                    c_weight = (c_uses * 1024) / c_span
                    // Higher evict_score = better candidate to evict (lower use density, further end_pos)
                    evict_score = (sc_cand.end_pos * 16) - c_weight
                    if spill_cand_idx < 0 or evict_score > best_evict_score
                        spill_cand_idx = sc_i
                        best_evict_score = evict_score
                    end
                end
                sc_i = sc_i - 1
            end

            // Allocate a stack spill slot (preferring recycled dead slots!)
            alloc_slot = 0
            if free_spill_slots.len() > 0
                alloc_slot = list_pop(free_spill_slots)
            else
                alloc_slot = spill_offset
                spill_offset = spill_offset - word_size
            end

            if spill_cand_idx >= 0
                cand = active[spill_cand_idx]
                cand_uses = 1
                if cand.use_positions != 0 and cand.use_positions.len() > 0
                    cand_uses = cand.use_positions.len()
                end
                cand_span = cand.end_pos - cand.start_pos + 1
                if cand_span < 1 cand_span = 1 end
                cand_weight = (cand_uses * 1024) / cand_span
                if cand.end_pos > cur.end_pos or cur_weight > cand_weight * 2
                    // Evict candidate: give candidate's physical register to cur
                    cand_reg = cand.assigned_reg
                    cand.is_spilled = 1
                    cand.spill_slot = alloc_slot
                    cand.assigned_reg = 0 - 1
                    push(spilled_active, cand)
                    spill_count = spill_count + 1

                    cur.assigned_reg = cand_reg
                    cur.is_spilled = 0
                    cur.spill_slot = 0

                    // Replace candidate in-place and re-establish ascending end_pos order (zero heap alloc)
                    list_set(active, spill_cand_idx, cur)
                    k_ev = spill_cand_idx
                    while k_ev > 0 and active[k_ev - 1].end_pos > cur.end_pos
                        list_set(active, k_ev, active[k_ev - 1])
                        k_ev = k_ev - 1
                    end
                    list_set(active, k_ev, cur)
                    a_n2 = active.len()
                    while k_ev + 1 < a_n2 and active[k_ev + 1].end_pos < cur.end_pos
                        list_set(active, k_ev, active[k_ev + 1])
                        k_ev = k_ev + 1
                    end
                    list_set(active, k_ev, cur)
                else
                    // Spill cur directly
                    cur.is_spilled = 1
                    cur.assigned_reg = 0 - 1
                    cur.spill_slot = alloc_slot
                    push(spilled_active, cur)
                    spill_count = spill_count + 1
                end
            else
                // No active intervals (zero registers available)
                cur.is_spilled = 1
                cur.assigned_reg = 0 - 1
                cur.spill_slot = alloc_slot
                push(spilled_active, cur)
                spill_count = spill_count + 1
            end

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
    iv_map = dict()
    call_positions = list()

    // 1. Record incoming formal parameters at position 0
    pi = 0
    while pi < fn_obj.params.len()
        p_val = fn_obj.params[pi]
        if p_val != 0
            live_interval_record_def_fast(intervals, iv_map, p_val.id, 0, 1)
        pi = pi + 1

    // 2. Monotonic traversal over all basic blocks and instructions
    // Record per-block linear spans [blk_start, blk_end) and CFG edges for exact dataflow liveness.
    n_blks = fn_obj.blocks.len()
    blk_lbl_idx = dict()
    bi_m = 0
    while bi_m < n_blks
        blk_lbl_idx[fn_obj.blocks[bi_m].label] = bi_m + 1
        bi_m = bi_m + 1
    end

    blk_starts = list()
    blk_ends = list()
    blk_succs = list()
    pos = 1
    bi = 0
    while bi < n_blks
        bb = fn_obj.blocks[bi]
        push(blk_starts, pos)
        succs_b = list()
        has_term = 0
        ii = 0
        while ii < bb.instructions.len()
            inst = bb.instructions[ii]
            if inst.is_dead == 0
                iop = inst.op
                // Mark ALL call-emitting ops (OP_CALL=19, OP_ADD_DYN, OP_CMP_DYN, OP_STRUCT_NEW, OP_DIV, OP_MOD)
                // so caller-saved registers are never left live across user calls or runtime helper calls!
                is_call_op = 0
                if iop == 19 or iop == OP_CALL or iop == OP_ADD_DYN or iop == OP_CMP_DYN or iop == OP_DIV or iop == OP_MOD
                    is_call_op = 1
                end
                if is_call_op == 1
                    push(call_positions, pos)
                end

                // Special case: OP_STRUCT_NEW calls _lipi_user_alloc FIRST, then reads operands to populate fields!
                // Recording call at pos, operand uses at pos+1, and result def at pos+2 guarantees operands span
                // the alloc call (getting callee-saved regs or stack slots) and never alias the result register.
                use_pos = pos
                def_pos = pos
                if iop == OP_STRUCT_NEW
                    push(call_positions, pos)
                    use_pos = pos + 1
                    def_pos = pos + 2
                end

                // Record operand read accesses (1 is VAL_KIND_INST, 3 is VAL_KIND_ARG)
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
                            live_interval_record_use_fast(intervals, iv_map, opnd.id, use_pos)
                        end
                    end
                    oi = oi + 1
                end

                // Record instruction result definition
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
                        live_interval_record_def_fast(intervals, iv_map, inst.result.id, def_pos, 0)
                    end
                end

                // Record CFG successor edges for exact multi-block liveness dataflow
                if iop == OP_JMP
                    has_term = 1
                    if len(inst.extra_str) > 0 and has_key(blk_lbl_idx, inst.extra_str) == 1
                        push(succs_b, blk_lbl_idx[inst.extra_str] - 1)
                    end
                elif iop == OP_BR
                    has_term = 1
                    if inst.extra_list != 0 and inst.extra_list.len() > 0
                        bt0 = inst.extra_list[0]
                        if len(bt0) > 0 and has_key(blk_lbl_idx, bt0) == 1
                            push(succs_b, blk_lbl_idx[bt0] - 1)
                        end
                        if inst.extra_list.len() > 1
                            bt1 = inst.extra_list[1]
                            if len(bt1) > 0 and has_key(blk_lbl_idx, bt1) == 1
                                push(succs_b, blk_lbl_idx[bt1] - 1)
                            end
                        end
                    elif len(inst.extra_str) > 0 and has_key(blk_lbl_idx, inst.extra_str) == 1
                        push(succs_b, blk_lbl_idx[inst.extra_str] - 1)
                    end
                elif iop == OP_RET
                    has_term = 1
                end

                if iop == OP_STRUCT_NEW
                    pos = pos + 3
                else
                    pos = pos + 1
                end
            end
            ii = ii + 1
        end
        if has_term == 0 and bi + 1 < n_blks
            push(succs_b, bi + 1)
        end
        push(blk_ends, pos)
        push(blk_succs, succs_b)
        bi = bi + 1
    end

    // 2b. Exact Backward CFG Dataflow Liveness (60-bit-word bitsets, Wimmer-Franz soundness):
    // WHY: AST-emitted blocks can place inner-loop if/else bodies AFTER an outer-loop latch in
    // linear order; pure back-edge span extension misses outer-loop vars still live inside those
    // inner blocks. Exact backward dataflow (`live_out[B] = U live_in[S]`, `live_in[B] = use[B] U (live_out[B] - def[B])`)
    // is 100% sound for arbitrary CFG topologies, nested loops, and non-RPO block orderings!
    n_vregs = intervals.len()
    if n_blks > 1 and n_vregs > 0
        vreg_idx_map = dict()
        vi_m = 0
        while vi_m < n_vregs
            vreg_idx_map[intervals[vi_m].vreg_name] = vi_m + 1
            vi_m = vi_m + 1
        end

        n_words = (n_vregs + 59) / 60
        total_w = n_blks * n_words
        stride_b = total_w * 8
        bs_buf = buf_new(stride_b * 4)
        bs_ptr = buf_ptr(bs_buf)
        off_def = stride_b
        off_in = stride_b * 2
        off_out = stride_b * 3
        wi_z = 0
        end_z = stride_b * 4
        while wi_z < end_z
            mem_word_write(bs_ptr, wi_z, 0)
            wi_z = wi_z + 8
        end

        // Populate per-block use/def bitsets (OP_STORE keeps target slot in use, never kills prematurely)
        bi_u = 0
        while bi_u < n_blks
            bb_u = fn_obj.blocks[bi_u]
            b_base_b = bi_u * n_words * 8
            ii_u = 0
            while ii_u < bb_u.instructions.len()
                inst_u = bb_u.instructions[ii_u]
                if inst_u.is_dead == 0
                    oi_u = 0
                    while oi_u < inst_u.operands.len()
                        op_u = inst_u.operands[oi_u]
                        if op_u != 0 and has_key(vreg_idx_map, op_u.id) == 1
                            vid_u = vreg_idx_map[op_u.id] - 1
                            w_off_u = b_base_b + ((vid_u / 60) * 8)
                            bit_u = 1 << (vid_u % 60)
                            if (mem_word_read(bs_ptr, off_def + w_off_u) & bit_u) == 0
                                mem_word_write(bs_ptr, w_off_u, mem_word_read(bs_ptr, w_off_u) | bit_u)
                            end
                        end
                        oi_u = oi_u + 1
                    end
                    if inst_u.result != 0 and has_key(vreg_idx_map, inst_u.result.id) == 1
                        vid_d = vreg_idx_map[inst_u.result.id] - 1
                        w_off_d = b_base_b + ((vid_d / 60) * 8)
                        bit_d = 1 << (vid_d % 60)
                        mem_word_write(bs_ptr, off_def + w_off_d, mem_word_read(bs_ptr, off_def + w_off_d) | bit_d)
                    end
                end
                ii_u = ii_u + 1
            end
            bi_u = bi_u + 1
        end

        // Fixed-point backward iteration over CFG (converges in 2-4 passes even for nested loops)
        fp_changed = 1
        fp_guard = 0
        fp_max = n_blks + 64
        if fp_max < 128 fp_max = 128 end
        while fp_changed == 1 and fp_guard < fp_max
            fp_changed = 0
            fp_guard = fp_guard + 1
            bi_f = n_blks - 1
            while bi_f >= 0
                b_base_b = bi_f * n_words * 8
                succs_f = blk_succs[bi_f]
                n_sf = succs_f.len()
                w_f = 0
                while w_f < n_words
                    w_off_f = b_base_b + (w_f * 8)
                    out_val = 0
                    si_f = 0
                    while si_f < n_sf
                        s_blk = succs_f[si_f]
                        out_val = out_val | mem_word_read(bs_ptr, off_in + (((s_blk * n_words) + w_f) * 8))
                        si_f = si_f + 1
                    end
                    def_val = mem_word_read(bs_ptr, off_def + w_off_f)
                    use_val = mem_word_read(bs_ptr, w_off_f)
                    // in_val = use | (out & ~def) == use | ((out | def) ^ def)
                    in_val = use_val | ((out_val | def_val) ^ def_val)
                    if out_val != mem_word_read(bs_ptr, off_out + w_off_f) or in_val != mem_word_read(bs_ptr, off_in + w_off_f)
                        mem_word_write(bs_ptr, off_out + w_off_f, out_val)
                        mem_word_write(bs_ptr, off_in + w_off_f, in_val)
                        fp_changed = 1
                    end
                    w_f = w_f + 1
                end
                bi_f = bi_f - 1
            end
        end

        // Extend live intervals to cover every block where each vreg is live_in or live_out (byte-skipping scan)
        bi_e = 0
        while bi_e < n_blks
            st_b = blk_starts[bi_e]
            en_b = blk_ends[bi_e]
            b_base_b = bi_e * n_words * 8
            w_e = 0
            while w_e < n_words
                w_off_e = b_base_b + (w_e * 8)
                in_w = mem_word_read(bs_ptr, off_in + w_off_e)
                out_w = mem_word_read(bs_ptr, off_out + w_off_e)
                rem = in_w | out_w
                if rem != 0
                    v_base = w_e * 60
                    k_b = 0
                    while rem != 0
                        if (rem & 255) == 0
                            rem = rem >> 8
                            k_b = k_b + 8
                        else
                            if (rem & 1) != 0
                                vid_e = v_base + k_b
                                if vid_e < n_vregs
                                    bit_e = 1 << k_b
                                    iv_e = intervals[vid_e]
                                    if (in_w & bit_e) != 0
                                        if st_b < iv_e.start_pos iv_e.start_pos = st_b end
                                        if st_b > iv_e.end_pos iv_e.end_pos = st_b end
                                    end
                                    if (out_w & bit_e) != 0
                                        if en_b > iv_e.end_pos iv_e.end_pos = en_b end
                                    end
                                end
                            end
                            rem = rem >> 1
                            k_b = k_b + 1
                        end
                    end
                end
                w_e = w_e + 1
            end
            bi_e = bi_e + 1
        end
        buf_free(bs_buf)
    end

    // 3. Mark call-spanning intervals (after exact CFG dataflow extension!)
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
