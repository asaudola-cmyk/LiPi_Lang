// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN RISC-V 64 (RV64G) MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/riscv64/codegen_expr.lp
// ==============================================================================

// ── 10. Recursive-Descent Expression Synthesizer ───────────────────────────────

fn riscv64_synth_expr_primary s toks pos_box
    // WHY: Parses and synthesizes primary operands (integers, strings, identifiers, calls, grouping).
    // Result is always computed into primary register a0 (x10).
    pos = get(pos_box, 0)
    if pos >= toks.len()
        riscv64_emit_addi(s, 10, 0, 0)
        return 0

    t = toks[pos]
    k = t.tok_kind
    handled = 0

    // 0. Unary Operators (-, !, ~, not, না)
    if k == TOK_MINUS()
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_expr_primary(s, toks, pos_box)
        riscv64_emit_sub(s, 10, 0, 10) // sub a0, x0, a0
        return 0
    if k == TOK_BANG() or (k == TOK_IDENT() and (t.tok_text == "not" or t.tok_text == "না"))
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_expr_primary(s, toks, pos_box)
        riscv64_emit_sltiu(s, 10, 10, 1) // sltiu a0, a0, 1
        return 0
    if k == TOK_TILDE()
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_expr_primary(s, toks, pos_box)
        riscv64_emit_xori(s, 10, 10, 0 - 1) // xori a0, a0, -1
        return 0

    // 1. Integer / Boolean / Null Literal
    if k == TOK_INT() or k == TOK_BOOL() or k == TOK_NONE()
        list_set(pos_box, 0, pos + 1)
        riscv64_emit_li(s, 10, t.tok_int_val)
        handled = 1

    // 1b. Float Literal: IEEE-754 binary64 64-bit precision
    if handled == 0 and k == TOK_FLOAT()
        list_set(pos_box, 0, pos + 1)
        fbits = riscv64_parse_float_bits(t.tok_text)
        riscv64_emit_li(s, 10, fbits)
        handled = 1

    // 1c. Array / List Literal: [e0, e1, ...]
    if handled == 0 and k == TOK_LBRACKET()
        list_set(pos_box, 0, pos + 1)
        arr_cnt = 0
        while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RBRACKET()
            riscv64_synth_compile_expr(s, toks, pos_box)
            riscv64_push_reg(s, 10)
            arr_cnt = arr_cnt + 1
            cur_p = get(pos_box, 0)
            if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_COMMA()
                list_set(pos_box, 0, cur_p + 1)
        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        s.rv_needs_list_create = 1
        s.rv_needs_alloc = 1
        riscv64_emit_li(s, 10, arr_cnt)
        arr_call_off = s.rv_code.len()
        riscv64_emit_jal(s, 1, 0)
        arr_rel = Riscv64CallReloc()
        arr_rel.rv_cr_patch_offset = arr_call_off
        arr_rel.rv_cr_target_name = "__list_create"
        push(s.rv_call_relocs, arr_rel)
        if arr_cnt > 0
            riscv64_emit_mv(s, 28, 10)
            riscv64_emit_ld(s, 29, 28, 16) // t4 = data_ptr
            ai = arr_cnt - 1
            while ai >= 0
                riscv64_pop_reg(s, 11)
                riscv64_emit_li(s, 5, ai * 8)
                riscv64_emit_add(s, 5, 29, 5)
                riscv64_emit_sd(s, 11, 5, 0)
                ai = ai - 1
            riscv64_emit_mv(s, 10, 28)
        handled = 1

    // 2. String Literal
    if handled == 0 and k == TOK_STR()
        list_set(pos_box, 0, pos + 1)
        ro_off = riscv64_synth_add_rodata_str(s, t.tok_text, 0)
        patch_pos = s.rv_code.len()
        riscv64_emit_lui(s, 10, 0)
        riscv64_emit_addi(s, 10, 10, 0)

        rel = Riscv64StringReloc()
        rel.rv_sr_patch_offset = patch_pos
        rel.rv_sr_rodata_offset = ro_off
        rel.rv_sr_reg = 10
        push(s.rv_str_relocs, rel)
        handled = 1

    // 3. Identifier or Call (Variable lookup, Field access, or Function Call)
    is_ident_or_call = 0
    if handled == 0 and (k == TOK_IDENT() or k == TOK_KW_SYSCALL() or k == TOK_KW_PRINT())
        is_ident_or_call = 1
    if is_ident_or_call == 1
        handled = 1
        list_set(pos_box, 0, pos + 1)
        var_name = t.tok_text
        next_pos = get(pos_box, 0)

        // Function call: name(...)
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_LPAREN()
            list_set(pos_box, 0, next_pos + 1) // Consume '('
            // Parse arguments and push to stack in order
            arg_count = 0
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                riscv64_synth_compile_expr(s, toks, pos_box)
                riscv64_push_reg(s, 10) // Push a0
                arg_count = arg_count + 1
                cur_pos = get(pos_box, 0)
                if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, cur_pos + 1)

            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            // ── Intrinsic 1: syscall / সিসকল ─────────────────────────────────
            // Linux RISC-V 64: a7 = syscall number, a0..a5 = args 1..6
            if var_name == "syscall" or var_name == "সিসকল"
                if arg_count >= 7
                    riscv64_pop_reg(s, 15) // arg 6 (a5)
                if arg_count >= 6
                    riscv64_pop_reg(s, 14) // arg 5 (a4)
                if arg_count >= 5
                    riscv64_pop_reg(s, 13) // arg 4 (a3)
                if arg_count >= 4
                    riscv64_pop_reg(s, 12) // arg 3 (a2)
                if arg_count >= 3
                    riscv64_pop_reg(s, 11) // arg 2 (a1)
                if arg_count >= 2
                    riscv64_pop_reg(s, 10) // arg 1 (a0)
                if arg_count >= 1
                    riscv64_pop_reg(s, 17) // syscall number (a7)
                riscv64_emit_ecall(s)
                return 0

            // ── Intrinsic 2: malloc / alloc / sys_alloc / mem_alloc / মেমরি_বরাদ্দ ──
            if var_name == "malloc" or var_name == "mem_alloc" or var_name == "মেমরি_বরাদ্দ" or var_name == "alloc" or var_name == "sys_alloc" or var_name == "বরাদ্দ"
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // requested size in a0
                else
                    riscv64_emit_li(s, 10, 32)
                riscv64_synth_emit_call_alloc(s)
                return 0

            // ── Intrinsic 2b: free / sys_free / mem_free / মুক্ত / মেমরি_মুক্তি ──
            if var_name == "free" or var_name == "sys_free" or var_name == "mem_free" or var_name == "মুক্ত" or var_name == "মেমরি_মুক্তি"
                ai = 0
                while ai < arg_count
                    riscv64_pop_reg(s, 11)
                    ai = ai + 1
                riscv64_emit_addi(s, 10, 0, 0)
                return 0

            // ── Intrinsic 3: mem_word_read / mem_read / মেমরি_পড়ো ──────────
            if var_name == "mem_word_read" or var_name == "mem_read" or var_name == "মেমরি_পড়ো"
                if arg_count >= 2
                    riscv64_pop_reg(s, 11) // offset (a1)
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // base addr (a0)
                riscv64_emit_add(s, 10, 10, 11) // a0 = addr + offset
                riscv64_emit_ld(s, 10, 10, 0)   // ld a0, 0(a0)
                return 0

            // ── Intrinsic 4: mem_word_write / mem_write / মেমরি_লেখো ───────
            if var_name == "mem_word_write" or var_name == "mem_write" or var_name == "মেমরি_লেখো"
                if arg_count >= 3
                    riscv64_pop_reg(s, 12) // value (a2)
                if arg_count >= 2
                    riscv64_pop_reg(s, 11) // offset (a1)
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // base addr (a0)
                riscv64_emit_add(s, 10, 10, 11) // a0 = addr + offset
                riscv64_emit_sd(s, 12, 10, 0)   // sd a2, 0(a0)
                riscv64_emit_mv(s, 10, 12)      // return val in a0
                return 0

            // ── Intrinsic 5: mem_byte_read / mem_read_byte / মেমরি_বাইট_পড়ো / sys_peek8
            if var_name == "mem_byte_read" or var_name == "mem_read_byte" or var_name == "মেমরি_বাইট_পড়ো" or var_name == "sys_peek8"
                if arg_count >= 2
                    riscv64_pop_reg(s, 11) // offset (a1)
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // base addr (a0)
                riscv64_emit_add(s, 10, 10, 11)
                riscv64_emit_lbu(s, 10, 10, 0)  // lbu a0, 0(a0)
                return 0

            // ── Intrinsic 6: mem_byte_write / mem_write_byte / মেমরি_বাইট_লেখো / sys_poke8
            if var_name == "mem_byte_write" or var_name == "mem_write_byte" or var_name == "মেমরি_বাইট_লেখো" or var_name == "sys_poke8"
                if arg_count >= 3
                    riscv64_pop_reg(s, 12) // value (a2)
                if arg_count >= 2
                    riscv64_pop_reg(s, 11) // offset (a1)
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // base addr (a0)
                riscv64_emit_add(s, 10, 10, 11)
                riscv64_emit_sb(s, 12, 10, 0)   // sb a2, 0(a0)
                riscv64_emit_mv(s, 10, 12)
                return 0

            // ── Intrinsic 7: exit / বিদায় ─────────────────────────────────
            if var_name == "exit" or var_name == "বিদায়"
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // status code in a0
                else
                    riscv64_emit_addi(s, 10, 0, 0)
                riscv64_emit_li(s, 17, 93) // SYS_exit (93)
                riscv64_emit_ecall(s)
                return 0

            // ── Intrinsic 8: list / তালিকা ─────────────────────────────────
            if var_name == "list" or var_name == "তালিকা"
                s.rv_needs_list_create = 1
                s.rv_needs_alloc = 1
                riscv64_emit_li(s, 10, arg_count)
                lc_call_off = s.rv_code.len()
                riscv64_emit_jal(s, 1, 0)
                lc_rel = Riscv64CallReloc()
                lc_rel.rv_cr_patch_offset = lc_call_off
                lc_rel.rv_cr_target_name = "__list_create"
                push(s.rv_call_relocs, lc_rel)
                if arg_count > 0
                    riscv64_emit_addi(s, 28, 10, 0) // t3 = list ptr (keep SP at args)
                    ai = arg_count - 1
                    while ai >= 0
                        riscv64_pop_reg(s, 11)
                        item_off = 24 + (ai * 8)
                        riscv64_emit_sd(s, 11, 28, item_off)
                        ai = ai - 1
                    riscv64_emit_addi(s, 10, 28, 0) // restore list ptr into a0
                return 0

            // ── Intrinsic 8b: len / দৈর্ঘ্য (list header [0]) ────────────────────
            if var_name == "len" or var_name == "দৈর্ঘ্য"
                while arg_count > 1
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                if arg_count == 1
                    riscv64_pop_reg(s, 10) // a0 = hdr
                    riscv64_emit_ld(s, 10, 10, 0)
                else
                    riscv64_emit_addi(s, 10, 0, 0)
                return 0

            // ── Intrinsic 8c: get / নাও (hdr, idx -> data[idx]) ────────────────
            if var_name == "get" or var_name == "নাও"
                while arg_count > 2
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                if arg_count == 2
                    riscv64_pop_reg(s, 11) // a1 = idx
                    riscv64_pop_reg(s, 10) // a0 = hdr
                    riscv64_emit_ld(s, 12, 10, 16) // a2 = data_ptr
                    riscv64_emit_add(s, 11, 11, 11)
                    riscv64_emit_add(s, 11, 11, 11)
                    riscv64_emit_add(s, 11, 11, 11) // idx * 8
                    riscv64_emit_add(s, 10, 12, 11)
                    riscv64_emit_ld(s, 10, 10, 0)
                else
                    while arg_count > 0
                        riscv64_pop_reg(s, 11)
                        arg_count = arg_count - 1
                    riscv64_emit_addi(s, 10, 0, 0)
                return 0

            // ── Intrinsic 8d: list_set / সেট (hdr, idx, val -> hdr) ────────────
            if var_name == "list_set" or var_name == "সেট"
                while arg_count > 3
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                if arg_count == 3
                    riscv64_pop_reg(s, 12) // a2 = val
                    riscv64_pop_reg(s, 11) // a1 = idx
                    riscv64_pop_reg(s, 10) // a0 = hdr
                    riscv64_emit_ld(s, 13, 10, 16) // a3 = data_ptr
                    riscv64_emit_add(s, 11, 11, 11)
                    riscv64_emit_add(s, 11, 11, 11)
                    riscv64_emit_add(s, 11, 11, 11) // idx * 8
                    riscv64_emit_add(s, 13, 13, 11) // a3 = &data[idx]
                    riscv64_emit_sd(s, 12, 13, 0)  // store a2 into 0(a3)
                else
                    while arg_count > 0
                        riscv64_pop_reg(s, 11)
                        arg_count = arg_count - 1
                    riscv64_emit_addi(s, 10, 0, 0)
                return 0

            // ── Intrinsic 8e: push / list_push / ঠেলো (hdr, val -> hdr) ──────────
            if var_name == "push" or var_name == "list_push" or var_name == "ঠেলো"
                while arg_count > 2
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                if arg_count == 2
                    s.rv_needs_list_push = 1
                    s.rv_needs_alloc = 1
                    riscv64_pop_reg(s, 11) // a1 = val
                    riscv64_pop_reg(s, 10) // a0 = hdr
                    lp_call_off = s.rv_code.len()
                    riscv64_emit_jal(s, 1, 0)
                    lp_rel = Riscv64CallReloc()
                    lp_rel.rv_cr_patch_offset = lp_call_off
                    lp_rel.rv_cr_target_name = "__list_push"
                    push(s.rv_call_relocs, lp_rel)
                else
                    while arg_count > 0
                        riscv64_pop_reg(s, 11)
                        arg_count = arg_count - 1
                    riscv64_emit_addi(s, 10, 0, 0)
                return 0

            // ── Intrinsic 9: file_write / ফাইল_লেখো ────────────────────────
            if var_name == "file_write" or var_name == "ফাইল_লেখো"
                s.rv_needs_file_write = 1
                if arg_count >= 3
                    riscv64_pop_reg(s, 12)
                else
                    riscv64_emit_addi(s, 12, 0, 0)
                if arg_count >= 2
                    riscv64_pop_reg(s, 11)
                else
                    riscv64_emit_addi(s, 11, 0, 0)
                if arg_count >= 1
                    riscv64_pop_reg(s, 10)
                else
                    riscv64_emit_addi(s, 10, 0, 0)
                fw_call_off = s.rv_code.len()
                riscv64_emit_jal(s, 1, 0)
                fw_rel = Riscv64CallReloc()
                fw_rel.rv_cr_patch_offset = fw_call_off
                fw_rel.rv_cr_target_name = "__file_write"
                push(s.rv_call_relocs, fw_rel)
                return 0

            // ── Struct Constructor: StructName(...) ─────────────────────────
            sdef = riscv64_synth_find_struct(s, var_name)
            if sdef != 0
                fcount = sdef.rv_sd_fields.len()
                alloc_sz = (fcount + 1) * 8
                if alloc_sz < 32
                    alloc_sz = 32
                riscv64_emit_li(s, 10, alloc_sz)
                riscv64_synth_emit_call_alloc(s)
                // Struct pointer is now in a0
                if arg_count > 0
                    riscv64_emit_addi(s, 28, 10, 0) // t3 = struct ptr (keep SP at args)
                    ai = arg_count - 1
                    while ai >= 0
                        riscv64_pop_reg(s, 11) // pop field value into a1
                        riscv64_emit_sd(s, 11, 28, ai * 8)
                        ai = ai - 1
                    riscv64_emit_addi(s, 10, 28, 0) // restore struct pointer into a0
                return 0

            // ── Normal Function Call: Pop arguments into LP64 registers a0..a7
            if arg_count >= 8
                riscv64_pop_reg(s, 17)
            if arg_count >= 7
                riscv64_pop_reg(s, 16)
            if arg_count >= 6
                riscv64_pop_reg(s, 15)
            if arg_count >= 5
                riscv64_pop_reg(s, 14)
            if arg_count >= 4
                riscv64_pop_reg(s, 13)
            if arg_count >= 3
                riscv64_pop_reg(s, 12)
            if arg_count >= 2
                riscv64_pop_reg(s, 11)
            if arg_count >= 1
                riscv64_pop_reg(s, 10)

            // Emit JAL instruction with relocation placeholder
            if var_name == "main" or var_name == "মূল"
                if s.rv_in_function == 0
                    s.rv_called_main = 1
            call_off = s.rv_code.len()
            riscv64_emit_jal(s, 1, 0) // JAL ra, 0

            call_rel = Riscv64CallReloc()
            call_rel.rv_cr_patch_offset = call_off
            call_rel.rv_cr_target_name = var_name
            push(s.rv_call_relocs, call_rel)

            // WHY: Check callee-saved s10 (x26) exception flag after call returns. If active,
            // branch to the innermost try/catch handler or restore sp from s0 and unwind frame.
            if s.rv_try_patches.len() > 0
                exc_bne_off = s.rv_code.len()
                riscv64_emit_bne(s, 26, 0, 0)
                active_tp = s.rv_try_patches[s.rv_try_patches.len() - 1]
                push(active_tp, [exc_bne_off, 1])
            elif s.rv_in_function == 1
                skip_beq_off = s.rv_code.len()
                riscv64_emit_beq(s, 26, 0, 0)
                riscv64_emit_addi(s, 2, 8, 0 - 1024)
                riscv64_emit_epilogue(s)
                riscv64_synth_patch_b(s, skip_beq_off, 0, 26, 0, s.rv_code.len())
            return 0

        // Variable load: ld a0, off(sp)
        off = riscv64_synth_lookup_var(s, var_name)
        if off > 0
            riscv64_emit_local_ld(s, 10, off)
        else
            riscv64_emit_addi(s, 10, 0, 0)

    // 4. Parenthesized expression: ( expr )
    if handled == 0 and k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_compile_expr(s, toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_pos + 1)
        handled = 1

    if handled == 0
        // Fallback: advance and clear a0
        list_set(pos_box, 0, pos + 1)
        riscv64_emit_addi(s, 10, 0, 0)
        return 0

    // 5. Postfix operations: .field, .len(), .push(x), [index]
    while get(pos_box, 0) < toks.len()
        cp = get(pos_box, 0)
        ct = toks[cp]
        if ct.tok_kind == TOK_DOT() or ct.tok_text == "."
            list_set(pos_box, 0, cp + 1)
            if get(pos_box, 0) < toks.len() and riscv64_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                fn_tok = toks[get(pos_box, 0)]
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                np = get(pos_box, 0)
                if np < toks.len() and toks[np].tok_kind == TOK_LPAREN()
                    list_set(pos_box, 0, np + 1)
                    m_args = 0
                    while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                        if m_args == 0
                            riscv64_push_reg(s, 10)
                        riscv64_synth_compile_expr(s, toks, pos_box)
                        riscv64_push_reg(s, 10)
                        m_args = m_args + 1
                        cur_mp = get(pos_box, 0)
                        if cur_mp < toks.len() and toks[cur_mp].tok_kind == TOK_COMMA()
                            list_set(pos_box, 0, cur_mp + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if fn_tok.tok_text == "len" or fn_tok.tok_text == "length"
                        while m_args > 0
                            riscv64_pop_reg(s, 11)
                            if m_args == 1
                                riscv64_pop_reg(s, 10)
                            m_args = m_args - 1
                        riscv64_emit_ld(s, 10, 10, 0)
                    elif fn_tok.tok_text == "push"
                        while m_args > 1
                            riscv64_pop_reg(s, 11)
                            m_args = m_args - 1
                        if m_args == 1
                            s.rv_needs_list_push = 1
                            s.rv_needs_alloc = 1
                            riscv64_pop_reg(s, 11)
                            riscv64_pop_reg(s, 10)
                            mp_off = s.rv_code.len()
                            riscv64_emit_jal(s, 1, 0)
                            mp_rel = Riscv64CallReloc()
                            mp_rel.rv_cr_patch_offset = mp_off
                            mp_rel.rv_cr_target_name = "__list_push"
                            push(s.rv_call_relocs, mp_rel)
                        else
                            riscv64_emit_addi(s, 10, 0, 0)
                    else
                        while m_args > 0
                            riscv64_pop_reg(s, 11)
                            if m_args == 1
                                riscv64_pop_reg(s, 10)
                            m_args = m_args - 1
                        riscv64_emit_addi(s, 10, 0, 0)
                else
                    f_off = riscv64_synth_get_field_offset(s, "", fn_tok.tok_text)
                    riscv64_emit_ld(s, 10, 10, f_off)
            else
                break
        elif ct.tok_kind == TOK_LBRACKET()
            list_set(pos_box, 0, cp + 1)
            riscv64_push_reg(s, 10) // Save hdr ptr
            riscv64_synth_compile_expr(s, toks, pos_box) // a0 = idx
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            riscv64_emit_mv(s, 11, 10)     // a1 = idx
            riscv64_pop_reg(s, 10)         // a0 = hdr
            riscv64_emit_ld(s, 12, 10, 16) // a2 = data_ptr
            riscv64_emit_slli(s, 11, 11, 3) // idx * 8
            riscv64_emit_add(s, 10, 12, 11)
            riscv64_emit_ld(s, 10, 10, 0)
        else
            break
    return 0

fn riscv64_synth_expr_mul s toks pos_box
    // WHY: Pratt precedence level 1 for multiplicative operations (*, /, %) in RISC-V 64.
    riscv64_synth_expr_primary(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind

        is_op = 0
        if k == TOK_STAR() or k == TOK_SLASH() or k == TOK_PERCENT()
            is_op = 1

        if is_op == 0
            break

        op_kind = k
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (a0) to stack
        riscv64_push_reg(s, 10)

        // Evaluate right operand into a0
        riscv64_synth_expr_primary(s, toks, pos_box)

        // Move right operand to a1, pop left operand back into a0
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)

        if op_kind == TOK_STAR()
            riscv64_emit_mul(s, 10, 10, 11)
        elif op_kind == TOK_SLASH()
            riscv64_emit_div(s, 10, 10, 11)
        elif op_kind == TOK_PERCENT()
            riscv64_emit_rem(s, 10, 10, 11)

    return 0

fn riscv64_synth_expr_add s toks pos_box
    // WHY: Pratt precedence level 2 for additive operations (+, -) in RISC-V 64.
    riscv64_synth_expr_mul(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind

        is_op = 0
        if k == TOK_PLUS() or k == TOK_MINUS()
            is_op = 1

        if is_op == 0
            break

        op_kind = k
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (a0) to stack
        riscv64_push_reg(s, 10)

        // Evaluate right operand with multiplicative precedence into a0
        riscv64_synth_expr_mul(s, toks, pos_box)

        // Move right operand to a1, pop left operand back into a0
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)

        if op_kind == TOK_PLUS()
            riscv64_emit_add(s, 10, 10, 11)
        elif op_kind == TOK_MINUS()
            riscv64_emit_sub(s, 10, 10, 11)

    return 0

fn riscv64_synth_expr_shift s toks pos_box
    // WHY: Pratt precedence level 3 for bitwise shifts (<<, >>) in RISC-V 64.
    riscv64_synth_expr_add(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind
        if k != TOK_SHL() and k != TOK_SHR()
            break
        list_set(pos_box, 0, pos + 1)
        riscv64_push_reg(s, 10)
        riscv64_synth_expr_add(s, toks, pos_box)
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)
        if k == TOK_SHL()
            riscv64_emit_sll(s, 10, 10, 11)
        else
            riscv64_emit_sra(s, 10, 10, 11)
    return 0

fn riscv64_synth_expr_rel s toks pos_box
    // WHY: Pratt precedence level 4 for comparison operators (==, !=, <, <=, >, >=) in RISC-V 64.
    riscv64_synth_expr_shift(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind

        is_op = 0
        if k == TOK_EQ() or k == TOK_NEQ() or k == TOK_LT() or k == TOK_LTE() or k == TOK_GT() or k == TOK_GTE()
            is_op = 1

        if is_op == 0
            break

        op_kind = k
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (a0) to stack
        riscv64_push_reg(s, 10)

        // Evaluate right operand into a0
        riscv64_synth_expr_shift(s, toks, pos_box)

        // Move right operand to a1, pop left operand back into a0
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)

        if op_kind == TOK_EQ()
            // Branchless equality: sub a0, a0, a1; sltiu a0, a0, 1
            riscv64_emit_sub(s, 10, 10, 11)
            riscv64_emit_sltiu(s, 10, 10, 1)
        elif op_kind == TOK_NEQ()
            // Branchless inequality: sub a0, a0, a1; sltu a0, x0, a0
            riscv64_emit_sub(s, 10, 10, 11)
            riscv64_emit_sltu(s, 10, 0, 10)
        elif op_kind == TOK_LT()
            // Branchless signed less than: slt a0, a0, a1
            riscv64_emit_slt(s, 10, 10, 11)
        elif op_kind == TOK_LTE()
            // Branchless signed less/equal: slt a0, a1, a0; xori a0, a0, 1
            riscv64_emit_slt(s, 10, 11, 10)
            riscv64_emit_xori(s, 10, 10, 1)
        elif op_kind == TOK_GT()
            // Branchless signed greater than: slt a0, a1, a0
            riscv64_emit_slt(s, 10, 11, 10)
        elif op_kind == TOK_GTE()
            // Branchless signed greater/equal: slt a0, a0, a1; xori a0, a0, 1
            riscv64_emit_slt(s, 10, 10, 11)
            riscv64_emit_xori(s, 10, 10, 1)

    return 0

fn riscv64_synth_expr_bit_and s toks pos_box
    riscv64_synth_expr_rel(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        if toks[pos].tok_kind != TOK_AMP()
            break
        list_set(pos_box, 0, pos + 1)
        riscv64_push_reg(s, 10)
        riscv64_synth_expr_rel(s, toks, pos_box)
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)
        riscv64_emit_and(s, 10, 10, 11)
    return 0

fn riscv64_synth_expr_bit_xor s toks pos_box
    riscv64_synth_expr_bit_and(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        if toks[pos].tok_kind != TOK_CARET()
            break
        list_set(pos_box, 0, pos + 1)
        riscv64_push_reg(s, 10)
        riscv64_synth_expr_bit_and(s, toks, pos_box)
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)
        riscv64_emit_xor(s, 10, 10, 11)
    return 0

fn riscv64_synth_expr_bit_or s toks pos_box
    riscv64_synth_expr_bit_xor(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        if toks[pos].tok_kind != TOK_BAR()
            break
        list_set(pos_box, 0, pos + 1)
        riscv64_push_reg(s, 10)
        riscv64_synth_expr_bit_xor(s, toks, pos_box)
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)
        riscv64_emit_or(s, 10, 10, 11)
    return 0

fn riscv64_synth_expr_log_and s toks pos_box
    riscv64_synth_expr_bit_or(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text
        if not (k == TOK_AND() or (k == TOK_IDENT() and (txt == "and" or txt == "এবং")))
            break
        list_set(pos_box, 0, pos + 1)
        // Normalize left to 0/1; short-circuit to end if 0
        bytes_sltu_l = rv64_encode_r(51, 10, 3, 0, 10, 0)
        riscv64_synth_emit_bytes(s, bytes_sltu_l)
        patch_false = s.rv_code.len()
        riscv64_emit_beq(s, 10, 0, 0)
        riscv64_synth_expr_bit_or(s, toks, pos_box)
        bytes_sltu_r = rv64_encode_r(51, 10, 3, 0, 10, 0)
        riscv64_synth_emit_bytes(s, bytes_sltu_r)
        riscv64_synth_patch_b(s, patch_false, 0, 10, 0, s.rv_code.len())
    return 0

fn riscv64_synth_expr_log_or s toks pos_box
    riscv64_synth_expr_log_and(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text
        if not (k == TOK_OR() or (k == TOK_IDENT() and (txt == "or" or txt == "অথবা" or txt == "বা")))
            break
        list_set(pos_box, 0, pos + 1)
        bytes_sltu_l = rv64_encode_r(51, 10, 3, 0, 10, 0)
        riscv64_synth_emit_bytes(s, bytes_sltu_l)
        patch_true = s.rv_code.len()
        riscv64_emit_bne(s, 10, 0, 0)
        riscv64_synth_expr_log_and(s, toks, pos_box)
        bytes_sltu_r = rv64_encode_r(51, 10, 3, 0, 10, 0)
        riscv64_synth_emit_bytes(s, bytes_sltu_r)
        riscv64_synth_patch_b(s, patch_true, 1, 10, 0, s.rv_code.len())
    return 0

fn riscv64_synth_compile_expr s toks pos_box
    // WHY: Master expression evaluator for RISC-V 64 entering at logical OR precedence level.
    return riscv64_synth_expr_log_or(s, toks, pos_box)

