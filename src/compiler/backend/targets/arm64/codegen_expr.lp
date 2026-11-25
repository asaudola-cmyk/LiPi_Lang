// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN ARM64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/arm64/codegen_expr.lp
// ==============================================================================

// ── 7. Recursive-Descent Expression Synthesizer ────────────────────────────────

fn arm64_synth_expr_primary s toks pos_box
    // WHY: Parses and synthesizes primary operands (integers, strings, identifiers, calls, grouping).
    // Result is always computed into X0.
    pos = get(pos_box, 0)
    if pos >= toks.len()
        arm64_emit_movz_x(s, 0, 0, 0)
        return 0

    t = toks[pos]
    k = t.tok_kind
    handled = 0
    cur_struct = ""

    // 0. Unary Operators (-, !, ~, not, না)
    if k == TOK_MINUS()
        list_set(pos_box, 0, pos + 1)
        arm64_synth_expr_primary(s, toks, pos_box)
        arm64_emit_sub_x(s, 0, 31, 0) // sub x0, xzr, x0
        s.a64_last_struct = ""
        return 0
    if k == TOK_BANG() or (k == TOK_IDENT() and (t.tok_text == "not" or t.tok_text == "না"))
        list_set(pos_box, 0, pos + 1)
        arm64_synth_expr_primary(s, toks, pos_box)
        arm64_emit_cmp_x(s, 0, 31)
        arm64_emit_b_cond(s, 0, 3)     // b.eq +3 (if 0 -> set 1)
        arm64_emit_movz_x(s, 0, 0, 0)
        arm64_emit_b(s, 2)
        arm64_emit_movz_x(s, 0, 1, 0)
        s.a64_last_struct = ""
        return 0
    if k == TOK_TILDE()
        list_set(pos_box, 0, pos + 1)
        arm64_synth_expr_primary(s, toks, pos_box)
        arm64_emit_orn_x(s, 0, 31, 0) // mvn x0, x0 (orn x0, xzr, x0)
        s.a64_last_struct = ""
        return 0

    // 1. Integer / Boolean / Null Literal
    if k == TOK_INT() or k == TOK_BOOL() or k == TOK_NONE()
        list_set(pos_box, 0, pos + 1)
        arm64_emit_mov_imm64(s, 0, t.tok_int_val)
        handled = 1

    // 1b. Float Literal: IEEE-754 binary64 64-bit precision
    if handled == 0 and k == TOK_FLOAT()
        list_set(pos_box, 0, pos + 1)
        fbits = arm64_parse_float_bits(t.tok_text)
        arm64_emit_mov_imm64(s, 0, fbits)
        handled = 1

    // 1c. Array / List Literal: [e0, e1, ...]
    if handled == 0 and k == TOK_LBRACKET()
        list_set(pos_box, 0, pos + 1)
        arr_cnt = 0
        while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RBRACKET()
            arm64_synth_compile_expr(s, toks, pos_box)
            arm64_push_reg(s, 0)
            arr_cnt = arr_cnt + 1
            cur_p = get(pos_box, 0)
            if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_COMMA()
                list_set(pos_box, 0, cur_p + 1)
        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        s.a64_needs_list_create = 1
        s.synth_needs_alloc = 1
        arm64_emit_mov_imm64(s, 0, arr_cnt)
        arr_call_off = s.synth_code.len()
        arm64_emit_bl(s, 0)
        arr_rel = Arm64CallReloc()
        arr_rel.a64_cr_patch_offset = arr_call_off
        arr_rel.a64_cr_target_name = "__list_create"
        push(s.synth_call_relocs, arr_rel)
        if arr_cnt > 0
            arm64_emit_mov_reg(s, 9, 0)              // X9 = hdr
            arm64_synth_emit32(s, 4181721088 | (2 << 10) | (9 << 5) | 10) // ldr x10, [x9, #16]
            ai = arr_cnt - 1
            while ai >= 0
                arm64_pop_reg(s, 1)
                arm64_emit_mov_imm64(s, 2, ai * 8)
                arm64_emit_add_x(s, 2, 10, 2)
                arm64_synth_emit32(s, 4177526784 | (0 << 10) | (2 << 5) | 1) // str x1, [x2, #0]
                ai = ai - 1
            arm64_emit_mov_reg(s, 0, 9)
        handled = 1

    // 1d. Closure Literal: fn(p1, p2) { ... } / => expr, |p1, p2| => expr / { ... }, || => expr
    if handled == 0 and (k == TOK_KW_FN() or (k == TOK_IDENT() and (t.tok_text == "fn" or t.tok_text == "কাজ"))) and pos + 1 < toks.len() and (toks[pos + 1].tok_kind == TOK_LPAREN() or toks[pos + 1].tok_text == "(")
        list_set(pos_box, 0, pos + 2)
        c_params = list()
        while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN() and toks[get(pos_box, 0)].tok_text != ")"
            pt = toks[get(pos_box, 0)]
            if arm64_is_ident_token(pt.tok_kind) == 1
                push(c_params, pt.tok_text)
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                end
            else
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or toks[get(pos_box, 0)].tok_text == ")")
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        arm64_emit_closure_literal(s, toks, pos_box, c_params)
        handled = 1
    end

    if handled == 0 and (k == TOK_BAR() or k == TOK_OR() or (k != TOK_STR() and (t.tok_text == "|" or t.tok_text == "||")))
        c_params = list()
        if k == TOK_OR() or t.tok_text == "||"
            list_set(pos_box, 0, pos + 1)
        else
            list_set(pos_box, 0, pos + 1)
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_BAR() and toks[get(pos_box, 0)].tok_text != "|"
                pt = toks[get(pos_box, 0)]
                if arm64_is_ident_token(pt.tok_kind) == 1
                    push(c_params, pt.tok_text)
                end
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_BAR() or toks[get(pos_box, 0)].tok_text == "|")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        arm64_emit_closure_literal(s, toks, pos_box, c_params)
        handled = 1
    end

    // 1e. Dict / HashMap Literal: { "k": v, ... } or {}
    if handled == 0 and (k == TOK_LBRACE() or (k != TOK_STR() and t.tok_text == "{"))
        list_set(pos_box, 0, pos + 1)
        s.a64_needs_dict = 1
        s.synth_needs_alloc = 1
        arm64_emit_movz_x(s, 0, 16, 0)
        arm64_synth_emit_call_helper(s, "__dict_new")
        arm64_push_reg(s, 0)
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            dp = get(pos_box, 0)
            if dp >= toks.len() break end
            if toks[dp].tok_kind == TOK_RBRACE() or (toks[dp].tok_kind != TOK_STR() and toks[dp].tok_text == "}")
                list_set(pos_box, 0, dp + 1)
                break
            end
            arm64_synth_compile_expr(s, toks, pos_box)
            arm64_push_reg(s, 0) // key
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            arm64_synth_compile_expr(s, toks, pos_box) // X0 = val
            arm64_emit_mov_reg(s, 2, 0)
            arm64_pop_reg(s, 1) // key
            arm64_pop_reg(s, 0) // dict hdr
            arm64_synth_emit_call_helper(s, "__dict_set")
            arm64_push_reg(s, 0)
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_COMMA()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        arm64_pop_reg(s, 0)
        handled = 1
    end

    // 2. String Literal
    if handled == 0 and k == TOK_STR()
        list_set(pos_box, 0, pos + 1)
        ro_off = arm64_synth_add_rodata_str(s, t.tok_text, 0)
        patch_pos = s.synth_code.len()
        arm64_emit_movz_x(s, 0, 0, 0)
        arm64_emit_movk_x(s, 0, 0, 16)
        arm64_emit_movk_x(s, 0, 0, 32)
        arm64_emit_movk_x(s, 0, 0, 48)

        rel = Arm64StringReloc()
        rel.sr_patch_offset = patch_pos
        rel.sr_rodata_offset = ro_off
        rel.sr_reg = 0
        push(s.synth_str_relocs, rel)
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
                arm64_synth_compile_expr(s, toks, pos_box)
                arm64_push_reg(s, 0) // Push X0
                arg_count = arg_count + 1
                cur_pos = get(pos_box, 0)
                if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, cur_pos + 1)

            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            // ── Intrinsic 1: syscall / সিসকল ─────────────────────────────────
            // Linux AArch64: X8 = syscall number, X0..X5 = args 1..6
            if var_name == "syscall" or var_name == "সিসকল"
                if arg_count >= 7
                    arm64_pop_reg(s, 5) // arg 6 (X5)
                if arg_count >= 6
                    arm64_pop_reg(s, 4) // arg 5 (X4)
                if arg_count >= 5
                    arm64_pop_reg(s, 3) // arg 4 (X3)
                if arg_count >= 4
                    arm64_pop_reg(s, 2) // arg 3 (X2)
                if arg_count >= 3
                    arm64_pop_reg(s, 1) // arg 2 (X1)
                if arg_count >= 2
                    arm64_pop_reg(s, 0) // arg 1 (X0)
                if arg_count >= 1
                    arm64_pop_reg(s, 8) // syscall number (X8)
                arm64_emit_svc(s, 0)
                return 0

            // ── Intrinsic 2: malloc / alloc / sys_alloc / mem_alloc / মেমরি_বরাদ্দ ──
            if var_name == "malloc" or var_name == "mem_alloc" or var_name == "মেমরি_বরাদ্দ" or var_name == "alloc" or var_name == "sys_alloc" or var_name == "বরাদ্দ"
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // requested size in X0
                else
                    arm64_emit_mov_imm64(s, 0, 32)
                arm64_synth_emit_call_alloc(s)
                return 0

            // ── Intrinsic 2b: free / sys_free / mem_free / মুক্ত / মেমরি_মুক্তি ──
            if var_name == "free" or var_name == "sys_free" or var_name == "mem_free" or var_name == "মুক্ত" or var_name == "মেমরি_মুক্তি"
                ai = 0
                while ai < arg_count
                    arm64_pop_reg(s, 1)
                    ai = ai + 1
                arm64_emit_movz_x(s, 0, 0, 0)
                return 0

            // ── Intrinsic 3: mem_word_read / mem_read / মেমরি_পড়ো ──────────
            if var_name == "mem_word_read" or var_name == "mem_read" or var_name == "মেমরি_পড়ো"
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1) // X0 = addr + offset
                // ldr x0, [x0, #0] (0xF9400000 = 4181721088)
                arm64_synth_emit32(s, 4181721088)
                return 0

            // ── Intrinsic 4: mem_word_write / mem_write / মেমরি_লেখো ───────
            if var_name == "mem_word_write" or var_name == "mem_write" or var_name == "মেমরি_লেখো"
                if arg_count >= 3
                    arm64_pop_reg(s, 2) // value (X2)
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1) // X0 = addr + offset
                // str x2, [x0, #0] (0xF9000002)
                arm64_synth_emit32(s, 0xF9000002)
                arm64_emit_mov_reg(s, 0, 2) // return val in X0
                return 0

            // ── Intrinsic 5: mem_byte_read / sys_peek8 / মেমরি_বাইট_পড়ো ──────
            if var_name == "mem_byte_read" or var_name == "mem_read_byte" or var_name == "মেমরি_বাইট_পড়ো" or var_name == "sys_peek8"
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1)
                // ldrb w0, [x0, #0] (0x39400000)
                arm64_synth_emit32(s, 0x39400000)
                return 0

            // ── Intrinsic 6: mem_byte_write / sys_poke8 / মেমরি_বাইট_লেখো ─────
            if var_name == "mem_byte_write" or var_name == "mem_write_byte" or var_name == "মেমরি_বাইট_লেখো" or var_name == "sys_poke8"
                if arg_count >= 3
                    arm64_pop_reg(s, 2) // value (X2)
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1)
                // strb w2, [x0, #0] (0x39000002)
                arm64_synth_emit32(s, 0x39000002)
                arm64_emit_mov_reg(s, 0, 2)
                return 0

            // ── Intrinsic 7: exit / বিদায় ─────────────────────────────────
            if var_name == "exit" or var_name == "বিদায়"
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // status code
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                arm64_emit_movz_x(s, 8, 94, 0) // SYS_exit_group (94)
                arm64_emit_svc(s, 0)
                return 0

            // ── Intrinsic 8: list / তালিকা ─────────────────────────────────────
            if var_name == "list" or var_name == "তালিকা"
                s.a64_needs_list_create = 1
                s.synth_needs_alloc = 1
                arm64_emit_mov_imm64(s, 0, arg_count)
                lc_call_off = s.synth_code.len()
                arm64_emit_bl(s, 0)
                lc_rel = Arm64CallReloc()
                lc_rel.a64_cr_patch_offset = lc_call_off
                lc_rel.a64_cr_target_name = "__list_create"
                push(s.synth_call_relocs, lc_rel)
                if arg_count > 0
                    arm64_emit_mov_reg(s, 9, 0) // X9 = list header ptr (keep SP pointing to args)
                    ai = arg_count - 1
                    while ai >= 0
                        arm64_pop_reg(s, 1)
                        item_off = 32 + (ai * 8)
                        scaled = item_off / 8
                        // str x1, [x9, #item_off]
                        st_item = 4177526784 | ((scaled & 4095) << 10) | (9 << 5) | 1
                        arm64_synth_emit32(s, st_item)
                        ai = ai - 1
                    arm64_emit_mov_reg(s, 0, 9) // return list ptr in X0
                return 0

            // ── Intrinsic 8b: len / দৈর্ঘ্য (list header [0]) ────────────────────
            if var_name == "len" or var_name == "দৈর্ঘ্য"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit32(s, 4181721088) // ldr x0, [x0, #0]
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                return 0

            // ── Intrinsic 8c: get / নাও (hdr, idx -> data[idx]) ────────────────
            if var_name == "get" or var_name == "নাও"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                if arg_count == 2
                    arm64_pop_reg(s, 1) // X1 = idx
                    arm64_pop_reg(s, 0) // X0 = hdr
                    arm64_synth_emit32(s, 4181723138) // ldr x2, [x0, #16]
                    arm64_emit_add_x(s, 1, 1, 1)     // X1 = idx * 2
                    arm64_emit_add_x(s, 1, 1, 1)     // X1 = idx * 4
                    arm64_emit_add_x(s, 1, 1, 1)     // X1 = idx * 8
                    arm64_emit_add_x(s, 0, 2, 1)     // X0 = data_ptr + idx*8
                    arm64_synth_emit32(s, 4181721088) // ldr x0, [x0, #0]
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    arm64_emit_movz_x(s, 0, 0, 0)
                return 0

            // ── Intrinsic 8d: list_set / সেট (hdr, idx, val -> hdr) ────────────
            if var_name == "list_set" or var_name == "সেট"
                while arg_count > 3
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                if arg_count == 3
                    arm64_pop_reg(s, 2) // X2 = val
                    arm64_pop_reg(s, 1) // X1 = idx
                    arm64_pop_reg(s, 0) // X0 = hdr
                    arm64_synth_emit32(s, 4181723139) // ldr x3, [x0, #16]
                    arm64_emit_add_x(s, 1, 1, 1)
                    arm64_emit_add_x(s, 1, 1, 1)
                    arm64_emit_add_x(s, 1, 1, 1)
                    arm64_emit_add_x(s, 3, 3, 1)     // X3 = data_ptr + idx*8
                    arm64_synth_emit32(s, 4177526882) // str x2, [x3, #0]
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    arm64_emit_movz_x(s, 0, 0, 0)
                return 0

            // ── Intrinsic 8e: push / list_push / ঠেলো (hdr, val -> hdr) ──────────
            if var_name == "push" or var_name == "list_push" or var_name == "ঠেলো"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                if arg_count == 2
                    s.a64_needs_list_push = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1) // X1 = val
                    arm64_pop_reg(s, 0) // X0 = hdr
                    lp_call_off = s.synth_code.len()
                    arm64_emit_bl(s, 0)
                    lp_rel = Arm64CallReloc()
                    lp_rel.a64_cr_patch_offset = lp_call_off
                    lp_rel.a64_cr_target_name = "__list_push"
                    push(s.synth_call_relocs, lp_rel)
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    arm64_emit_movz_x(s, 0, 0, 0)
                return 0

            // ── Intrinsic 9: file_write / ফাইল_লেখো ────────────────────────────
            if var_name == "file_write" or var_name == "ফাইল_লেখো"
                s.a64_needs_file_write = 1
                if arg_count >= 3
                    arm64_pop_reg(s, 2)
                else
                    arm64_emit_movz_x(s, 2, 0, 0)
                if arg_count >= 2
                    arm64_pop_reg(s, 1)
                else
                    arm64_emit_movz_x(s, 1, 0, 0)
                if arg_count >= 1
                    arm64_pop_reg(s, 0)
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                fw_call_off = s.synth_code.len()
                arm64_emit_bl(s, 0)
                fw_rel = Arm64CallReloc()
                fw_rel.a64_cr_patch_offset = fw_call_off
                fw_rel.a64_cr_target_name = "__file_write"
                push(s.synth_call_relocs, fw_rel)
                return 0

            // ── Intrinsic 9b: Dict / HashMap Intrinsics (DICT0 Parity) ──────
            if var_name == "dict" or var_name == "map" or var_name == "অভিধান"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                else
                    arm64_emit_movz_x(s, 0, 16, 0)
                end
                s.a64_needs_dict = 1
                s.synth_needs_alloc = 1
                arm64_synth_emit_call_helper(s, "__dict_new")
                return 0
            end
            if var_name == "has_key" or var_name == "dict_has"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.a64_needs_dict = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__dict_has")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "del_key" or var_name == "dict_del"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.a64_needs_dict = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__dict_del")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "dict_get"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.a64_needs_dict = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__dict_get")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "dict_set"
                while arg_count > 3
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 3
                    s.a64_needs_dict = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 2)
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__dict_set")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end

            // ── Intrinsic 9c: ByteBuffer Intrinsics ─────────────────────────
            if var_name == "buf_new" or var_name == "byte_buf_new" or var_name == "বাফার_তৈরি"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                else
                    arm64_emit_movz_x(s, 0, 64, 0)
                end
                s.a64_needs_buf = 1
                s.synth_needs_alloc = 1
                arm64_synth_emit_call_helper(s, "__buf_new")
                return 0
            end
            if var_name == "buf_write_byte" or var_name == "buf_append_byte" or var_name == "buf_push"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.a64_needs_buf = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__buf_write_byte")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_write_str" or var_name == "buf_append" or var_name == "buf_append_str"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.a64_needs_buf = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__buf_write_str")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_to_str"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    s.a64_needs_buf = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__buf_to_str")
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_len"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                    arm64_emit_ldr_x_off(s, 0, 0, 8)
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_ptr"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                    arm64_emit_ldr_x_off(s, 0, 0, 0)
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_clear"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                    arm64_emit_str_x_off(s, 31, 0, 8)
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_get_byte"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_emit_ldr_x_off(s, 9, 0, 0)
                    arm64_emit_add_x(s, 9, 9, 1)
                    arm64_emit_ldrb_off(s, 0, 9, 0)
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_free"
                while arg_count > 0
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                arm64_emit_movz_x(s, 0, 0, 0)
                return 0
            end

            // ── Struct Constructor: StructName(...) ─────────────────────────
            sdef = arm64_synth_find_struct(s, var_name)
            if sdef != 0
                fcount = sdef.sd_fields.len()
                alloc_sz = (fcount + 1) * 8
                if alloc_sz < 32
                    alloc_sz = 32
                arm64_emit_mov_imm64(s, 0, alloc_sz)
                arm64_synth_emit_call_alloc(s)
                // Struct pointer is now in X0
                if arg_count > 0
                    arm64_emit_mov_reg(s, 9, 0) // X9 = struct ptr (keep SP pointing to args)
                    ai = arg_count - 1
                    while ai >= 0
                        arm64_pop_reg(s, 1) // pop field value into X1
                        // str x1, [x9, #ai*8]
                        scaled_ai = ai & 4095
                        st_word = 4177526784 | (scaled_ai << 10) | (9 << 5) | 1
                        arm64_synth_emit32(s, st_word)
                        ai = ai - 1
                    arm64_emit_mov_reg(s, 0, 9) // return struct pointer in X0
                s.a64_last_struct = var_name
                return 0

            // ── Normal Function Call: Pop arguments into AAPCS64 registers X0..X7
            if arg_count >= 8
                arm64_pop_reg(s, 7)
            if arg_count >= 7
                arm64_pop_reg(s, 6)
            if arg_count >= 6
                arm64_pop_reg(s, 5)
            if arg_count >= 5
                arm64_pop_reg(s, 4)
            if arg_count >= 4
                arm64_pop_reg(s, 3)
            if arg_count >= 3
                arm64_pop_reg(s, 2)
            if arg_count >= 2
                arm64_pop_reg(s, 1)
            if arg_count >= 1
                arm64_pop_reg(s, 0)

            // ── Indirect Closure/Fn-Ptr Call vs Direct Named Function Call ───
            lv_call = arm64_find_local_var(s, var_name)
            if lv_call != 0
                arm64_emit_ldr_reg_sp(s, 11, lv_call.lv_offset)
                if lv_call.a64_lv_is_boxed == 1
                    arm64_emit_ldr_x_off(s, 11, 11, 0)
                end
                arm64_emit_indirect_call_x11(s)
            else
                // Emit BL instruction with relocation placeholder
                if var_name == "main" or var_name == "মূল"
                    if s.a64_in_function == 0
                        s.a64_called_main = 1
                call_off = s.synth_code.len()
                arm64_emit_bl(s, 0)

                call_rel = Arm64CallReloc()
                call_rel.a64_cr_patch_offset = call_off
                call_rel.a64_cr_target_name = var_name
                push(s.synth_call_relocs, call_rel)
            end

            // WHY: Check callee-saved X27 exception flag after call returns. If active, jump to
            // the innermost try/catch handler or immediately unwind the current stack frame.
            if s.a64_try_patches.len() > 0
                arm64_emit_cmp_x(s, 27, 31)
                exc_bne_off = s.synth_code.len()
                arm64_emit_b_cond(s, 1, 0)
                active_tp = s.a64_try_patches[s.a64_try_patches.len() - 1]
                push(active_tp, [exc_bne_off, 1])
            elif s.a64_in_function == 1
                arm64_emit_cmp_x(s, 27, 31)
                skip_eq_off = s.synth_code.len()
                arm64_emit_b_cond(s, 0, 0)
                arm64_emit_defers(s, toks)
                arm64_emit_epilogue(s)
                skip_words = (s.synth_code.len() - skip_eq_off) / 4
                arm64_synth_patch_u32(s, skip_eq_off, 1409286144 | ((skip_words & 524287) << 5) | 0)
            end
        else
            // Variable load: ldr x0, [sp, #off] (auto-deref boxed upvalue cells!)
            lv_rd = arm64_find_local_var(s, var_name)
            if lv_rd != 0
                arm64_emit_ldr_reg_sp(s, 0, lv_rd.lv_offset)
                if lv_rd.a64_lv_is_boxed == 1
                    arm64_emit_ldr_x_off(s, 0, 0, 0)
                end
                cur_struct = lv_rd.a64_lv_struct_type
            else
                arm64_emit_movz_x(s, 0, 0, 0)
            end
        end

    // 4. Parenthesized expression: ( expr )
    if handled == 0 and k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1)
        arm64_synth_compile_expr(s, toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_pos + 1)
        handled = 1
        cur_struct = s.a64_last_struct

    if handled == 0
        // Fallback: advance and clear X0
        list_set(pos_box, 0, pos + 1)
        arm64_emit_movz_x(s, 0, 0, 0)
        s.a64_last_struct = ""
        return 0

    // 5. Postfix operations: .field, .len(), .push(x), [index]
    while get(pos_box, 0) < toks.len()
        cp = get(pos_box, 0)
        ct = toks[cp]
        if ct.tok_kind == TOK_DOT() or ct.tok_text == "."
            list_set(pos_box, 0, cp + 1)
            if get(pos_box, 0) < toks.len() and arm64_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                fn_tok = toks[get(pos_box, 0)]
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                np = get(pos_box, 0)
                if np < toks.len() and toks[np].tok_kind == TOK_LPAREN()
                    list_set(pos_box, 0, np + 1)
                    m_args = 0
                    while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                        if m_args == 0
                            arm64_push_reg(s, 0)
                        arm64_synth_compile_expr(s, toks, pos_box)
                        arm64_push_reg(s, 0)
                        m_args = m_args + 1
                        cur_mp = get(pos_box, 0)
                        if cur_mp < toks.len() and toks[cur_mp].tok_kind == TOK_COMMA()
                            list_set(pos_box, 0, cur_mp + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if fn_tok.tok_text == "len" or fn_tok.tok_text == "length"
                        while m_args > 0
                            arm64_pop_reg(s, 1)
                            if m_args == 1
                                arm64_pop_reg(s, 0)
                            m_args = m_args - 1
                        arm64_synth_emit32(s, 4181721088) // ldr x0, [x0, #0]
                    elif fn_tok.tok_text == "push"
                        while m_args > 1
                            arm64_pop_reg(s, 1)
                            m_args = m_args - 1
                        if m_args == 1
                            s.a64_needs_list_push = 1
                            s.synth_needs_alloc = 1
                            arm64_pop_reg(s, 1)
                            arm64_pop_reg(s, 0)
                            mp_off = s.synth_code.len()
                            arm64_emit_bl(s, 0)
                            mp_rel = Arm64CallReloc()
                            mp_rel.a64_cr_patch_offset = mp_off
                            mp_rel.a64_cr_target_name = "__list_push"
                            push(s.synth_call_relocs, mp_rel)
                        else
                            arm64_emit_movz_x(s, 0, 0, 0)
                    else
                        while m_args > 0
                            arm64_pop_reg(s, 1)
                            if m_args == 1
                                arm64_pop_reg(s, 0)
                            m_args = m_args - 1
                        arm64_emit_movz_x(s, 0, 0, 0)
                    cur_struct = ""
                else
                    f_off = arm64_synth_get_field_offset(s, cur_struct, fn_tok.tok_text)
                    scaled_fo = (f_off / 8) & 4095
                    ldr_word = 4181721088 | (scaled_fo << 10)
                    arm64_synth_emit32(s, ldr_word)
                    cur_struct = ""
            else
                break
        elif ct.tok_kind == TOK_LBRACKET()
            list_set(pos_box, 0, cp + 1)
            arm64_push_reg(s, 0) // Save hdr
            arm64_synth_compile_expr(s, toks, pos_box) // X0 = idx/key
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            arm64_emit_mov_reg(s, 1, 0)     // X1 = idx/key
            arm64_pop_reg(s, 0)             // X0 = hdr
            s.a64_needs_dict = 1
            s.synth_needs_alloc = 1
            arm64_synth_emit_call_helper(s, "__container_get")
            cur_struct = ""
        elif ct.tok_kind == TOK_LPAREN() and cp > 0 and ct.tok_span.span_start_line == toks[cp - 1].tok_span.span_start_line
            list_set(pos_box, 0, cp + 1)
            arm64_push_reg(s, 0) // Save callee closure/fn_ptr
            p_argc = 0
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                arm64_synth_compile_expr(s, toks, pos_box)
                arm64_push_reg(s, 0)
                p_argc = p_argc + 1
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            if p_argc >= 8 arm64_pop_reg(s, 7) end
            if p_argc >= 7 arm64_pop_reg(s, 6) end
            if p_argc >= 6 arm64_pop_reg(s, 5) end
            if p_argc >= 5 arm64_pop_reg(s, 4) end
            if p_argc >= 4 arm64_pop_reg(s, 3) end
            if p_argc >= 3 arm64_pop_reg(s, 2) end
            if p_argc >= 2 arm64_pop_reg(s, 1) end
            if p_argc >= 1 arm64_pop_reg(s, 0) end
            arm64_pop_reg(s, 11) // X11 = callee
            arm64_emit_indirect_call_x11(s)
            cur_struct = ""
        else
            break
    s.a64_last_struct = cur_struct
    return 0

// ── 7. Expression Synthesizer (Pratt / Operator Precedence Hierarchy) ──────────

fn arm64_synth_expr_multiplicative s toks pos_box
    // WHY: Pratt precedence level 1 for high-precedence arithmetic (*, /, %)
    arm64_synth_expr_primary(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind
        if k != TOK_STAR() and k != TOK_SLASH() and k != TOK_PERCENT()
            break
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (X0) to stack
        arm64_push_reg(s, 0)

        // Evaluate right operand into X0
        arm64_synth_expr_primary(s, toks, pos_box)

        // Move right operand to X1, pop left operand back into X0
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)

        if k == TOK_STAR()
            arm64_emit_mul_x(s, 0, 0, 1)
        elif k == TOK_SLASH()
            arm64_emit_sdiv_x(s, 0, 0, 1)
        elif k == TOK_PERCENT()
            // Remainder in AArch64: X2 = X0 / X1; X2 = X2 * X1; X0 = X0 - X2
            arm64_emit_sdiv_x(s, 2, 0, 1)
            arm64_emit_mul_x(s, 2, 2, 1)
            arm64_emit_sub_x(s, 0, 0, 2)
    return 0

fn arm64_synth_expr_additive s toks pos_box
    // WHY: Pratt precedence level 2 for standard arithmetic (+, -)
    arm64_synth_expr_multiplicative(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind
        if k != TOK_PLUS() and k != TOK_MINUS()
            break
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (X0) to stack
        arm64_push_reg(s, 0)

        // Evaluate right operand into X0
        arm64_synth_expr_multiplicative(s, toks, pos_box)

        // Move right operand to X1, pop left operand back into X0
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)

        if k == TOK_PLUS()
            arm64_emit_add_x(s, 0, 0, 1)
        elif k == TOK_MINUS()
            arm64_emit_sub_x(s, 0, 0, 1)
    return 0

fn arm64_synth_expr_shift s toks pos_box
    // WHY: Pratt precedence level 3a for bitwise shifts (<<, >>)
    arm64_synth_expr_additive(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind
        if k != TOK_SHL() and k != TOK_SHR()
            break
        list_set(pos_box, 0, pos + 1)
        arm64_push_reg(s, 0)
        arm64_synth_expr_additive(s, toks, pos_box)
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)
        if k == TOK_SHL()
            arm64_emit_lslv_x(s, 0, 0, 1)
        else
            arm64_emit_asrv_x(s, 0, 0, 1)
        s.a64_last_struct = ""
    return 0

fn arm64_synth_expr_relational s toks pos_box
    // WHY: Pratt precedence level 3 for comparison operators (==, !=, <, <=, >, >=)
    arm64_synth_expr_shift(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind
        if k != TOK_EQ() and k != TOK_NEQ() and k != TOK_LT() and k != TOK_LTE() and k != TOK_GT() and k != TOK_GTE()
            break
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (X0) to stack
        arm64_push_reg(s, 0)

        // Evaluate right operand into X0
        arm64_synth_expr_shift(s, toks, pos_box)

        // Move right operand to X1, pop left operand back into X0
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)

        if k == TOK_EQ()
            // cmp x0, x1; b.eq +2; mov x0, 0; b +2; mov x0, 1
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 0, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
        elif k == TOK_NEQ()
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 1, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
        elif k == TOK_LT()
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 11, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
        elif k == TOK_LTE()
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 13, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
        elif k == TOK_GT()
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 12, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
        elif k == TOK_GTE()
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 10, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
    return 0

fn arm64_synth_expr_bit_and s toks pos_box
    arm64_synth_expr_relational(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        if toks[pos].tok_kind != TOK_AMP()
            break
        list_set(pos_box, 0, pos + 1)
        arm64_push_reg(s, 0)
        arm64_synth_expr_relational(s, toks, pos_box)
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)
        arm64_emit_and_x(s, 0, 0, 1)
        s.a64_last_struct = ""
    return 0

fn arm64_synth_expr_bit_xor s toks pos_box
    arm64_synth_expr_bit_and(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        if toks[pos].tok_kind != TOK_CARET()
            break
        list_set(pos_box, 0, pos + 1)
        arm64_push_reg(s, 0)
        arm64_synth_expr_bit_and(s, toks, pos_box)
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)
        arm64_emit_eor_x(s, 0, 0, 1)
        s.a64_last_struct = ""
    return 0

fn arm64_synth_expr_bit_or s toks pos_box
    arm64_synth_expr_bit_xor(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        if toks[pos].tok_kind != TOK_BAR()
            break
        list_set(pos_box, 0, pos + 1)
        arm64_push_reg(s, 0)
        arm64_synth_expr_bit_xor(s, toks, pos_box)
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)
        arm64_emit_orr_x(s, 0, 0, 1)
        s.a64_last_struct = ""
    return 0

fn arm64_synth_expr_and s toks pos_box
    // WHY: Pratt precedence level 4 for logical AND (and, &&, এবং)
    arm64_synth_expr_bit_or(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text
        is_and = 0
        if k == TOK_AND() or (k == TOK_IDENT() and (txt == "and" or txt == "এবং"))
            is_and = 1
        if is_and == 0
            break
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (X0) to stack
        arm64_push_reg(s, 0)

        // Evaluate right operand into X0
        arm64_synth_expr_bit_or(s, toks, pos_box)

        // Move right operand to X1, pop left operand back into X0
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)

        // X0 = (X0 != 0 && X1 != 0) ? 1 : 0
        arm64_emit_cmp_x(s, 0, 31)     // cmp x0, xzr
        arm64_emit_b_cond(s, 0, 4)     // b.eq fail (+4 words)
        arm64_emit_cmp_x(s, 1, 31)     // cmp x1, xzr
        arm64_emit_b_cond(s, 0, 2)     // b.eq fail (+2 words)
        arm64_emit_movz_x(s, 0, 1, 0)  // movz x0, 1
        arm64_emit_b(s, 2)             // b done (+2 words)
        arm64_emit_movz_x(s, 0, 0, 0)  // fail: movz x0, 0
    return 0

fn arm64_synth_expr_or s toks pos_box
    // WHY: Pratt precedence level 5 for logical OR (or, ||, অথবা)
    arm64_synth_expr_and(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text
        is_or = 0
        if k == TOK_OR() or (k == TOK_IDENT() and (txt == "or" or txt == "অথবা"))
            is_or = 1
        if is_or == 0
            break
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (X0) to stack
        arm64_push_reg(s, 0)

        // Evaluate right operand into X0
        arm64_synth_expr_and(s, toks, pos_box)

        // Move right operand to X1, pop left operand back into X0
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)

        // X0 = (X0 != 0 || X1 != 0) ? 1 : 0
        arm64_emit_cmp_x(s, 0, 31)     // cmp x0, xzr
        arm64_emit_b_cond(s, 1, 4)     // b.ne success (+4 words)
        arm64_emit_cmp_x(s, 1, 31)     // cmp x1, xzr
        arm64_emit_b_cond(s, 1, 2)     // b.ne success (+2 words)
        arm64_emit_movz_x(s, 0, 0, 0)  // movz x0, 0
        arm64_emit_b(s, 2)             // b done (+2 words)
        arm64_emit_movz_x(s, 0, 1, 0)  // success: movz x0, 1
    return 0

fn arm64_synth_compile_expr s toks pos_box
    // WHY: Master expression evaluator entering at lowest-precedence (logical OR) level.
    return arm64_synth_expr_or(s, toks, pos_box)

