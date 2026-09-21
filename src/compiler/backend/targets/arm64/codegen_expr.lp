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

    // 1. Integer Literal
    if k == TOK_INT()
        list_set(pos_box, 0, pos + 1)
        arm64_emit_mov_imm64(s, 0, t.tok_int_val)
        return 0

    // 2. String Literal
    if k == TOK_STR()
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
        return 0

    // 3. Identifier or Call (Variable lookup, Field access, or Function Call)
    is_ident_or_call = 0
    if k == TOK_IDENT() or k == TOK_KW_SYSCALL() or k == TOK_KW_PRINT()
        is_ident_or_call = 1
    if is_ident_or_call == 1
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

            // ── Intrinsic 2: malloc / mem_alloc / মেমরি_বরাদ্দ ──────────────
            if var_name == "malloc" or var_name == "mem_alloc" or var_name == "মেমরি_বরাদ্দ"
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // requested size in X0
                else
                    arm64_emit_mov_imm64(s, 0, 32)
                arm64_synth_emit_call_alloc(s)
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
                arm64_emit_movz_x(s, 8, 93, 0) // SYS_exit (93)
                arm64_emit_svc(s, 0)
                return 0

            // ── Intrinsic 8: list / তালিকা ─────────────────────────────────────
            if var_name == "list" or var_name == "তালিকা"
                if arg_count == 0
                    arm64_emit_mov_imm64(s, 0, 32)
                    arm64_synth_emit_call_alloc(s)
                else
                    total_alloc = 32 + (arg_count * 8)
                    arm64_emit_mov_imm64(s, 0, total_alloc)
                    arm64_synth_emit_call_alloc(s)
                    arm64_push_reg(s, 0)
                    ai = arg_count - 1
                    while ai >= 0
                        arm64_pop_reg(s, 1)
                        arm64_emit_ldr_reg_sp(s, 2, 0)
                        item_off = 24 + (ai * 8)
                        scaled = item_off / 8
                        st_item = 0xF9000000 | (scaled << 10) | (2 << 5) | 1
                        arm64_synth_emit32(s, st_item)
                        ai = ai - 1
                    arm64_pop_reg(s, 0)
                return 0

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
                    arm64_push_reg(s, 0) // preserve struct pointer on stack
                    ai = arg_count - 1
                    while ai >= 0
                        arm64_pop_reg(s, 1) // pop field value into X1
                        // ldr x2, [sp, #0] -> reload struct pointer into X2
                        arm64_emit_ldr_reg_sp(s, 2, 0)
                        // str x1, [x2, #ai*8] -> 0xF9000000 | (((ai*8)/8) << 10) | (2 << 5) | 1
                        scaled_ai = ai & 4095
                        st_word = 4177526784 | (scaled_ai << 10) | (2 << 5) | 1
                        arm64_synth_emit32(s, st_word)
                        ai = ai - 1
                    arm64_pop_reg(s, 0) // restore struct pointer into X0
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

            // Emit BL instruction with relocation placeholder
            call_off = s.synth_code.len()
            arm64_emit_bl(s, 0)

            call_rel = Arm64CallReloc()
            call_rel.cr_patch_offset = call_off
            call_rel.cr_target_name = var_name
            push(s.synth_call_relocs, call_rel)
            return 0

        // ── Struct Field Access: obj.field ──────────────────────────────────
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_DOT() or toks[next_pos].tok_text == ".")
            // Load base object pointer from local stack into X0
            off = arm64_synth_lookup_var(s, var_name)
            if off > 0
                arm64_emit_ldr_reg_sp(s, 0, off)
            else
                arm64_emit_movz_x(s, 0, 0, 0)

            while get(pos_box, 0) < toks.len()
                cp = get(pos_box, 0)
                if toks[cp].tok_kind != TOK_DOT() and toks[cp].tok_text != "."
                    break
                list_set(pos_box, 0, cp + 1) // Consume '.'
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                    fn_tok = toks[get(pos_box, 0)]
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    f_off = arm64_synth_get_field_offset(s, "", fn_tok.tok_text)
                    // ldr x0, [x0, #f_off]: 0xF9400000 | (((f_off/8) & 0xFFF) << 10) | (0 << 5) | 0
                    scaled_fo = (f_off / 8) & 4095
                    ldr_word = 4181721088 | (scaled_fo << 10)
                    arm64_synth_emit32(s, ldr_word)
            return 0

        // Variable load: ldr x0, [sp, #off]
        off = arm64_synth_lookup_var(s, var_name)
        if off > 0
            arm64_emit_ldr_reg_sp(s, 0, off)
        else
            arm64_emit_movz_x(s, 0, 0, 0)
        return 0

    // 4. Parenthesized expression: ( expr )
    if k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1)
        arm64_synth_compile_expr(s, toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_pos + 1)
        return 0

    // Fallback: advance and clear X0
    list_set(pos_box, 0, pos + 1)
    arm64_emit_movz_x(s, 0, 0, 0)
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

fn arm64_synth_expr_relational s toks pos_box
    // WHY: Pratt precedence level 3 for comparison operators (==, !=, <, <=, >, >=)
    arm64_synth_expr_additive(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind
        if k != TOK_EQ() and k != TOK_NEQ() and k != TOK_LT() and k != TOK_LTE() and k != TOK_GT() and k != TOK_GTE()
            break
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (X0) to stack
        arm64_push_reg(s, 0)

        // Evaluate right operand into X0
        arm64_synth_expr_additive(s, toks, pos_box)

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

fn arm64_synth_expr_and s toks pos_box
    // WHY: Pratt precedence level 4 for logical AND (and, &&, এবং)
    arm64_synth_expr_relational(s, toks, pos_box)

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
        arm64_synth_expr_relational(s, toks, pos_box)

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

