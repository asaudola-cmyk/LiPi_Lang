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

    // 1. Integer Literal
    if k == TOK_INT()
        list_set(pos_box, 0, pos + 1)
        riscv64_emit_li(s, 10, t.tok_int_val)
        return 0

    // 2. String Literal
    if k == TOK_STR()
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

            // ── Intrinsic 2: malloc / mem_alloc / মেমরি_বরাদ্দ ──────────────
            if var_name == "malloc" or var_name == "mem_alloc" or var_name == "মেমরি_বরাদ্দ"
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // requested size in a0
                else
                    riscv64_emit_li(s, 10, 32)
                riscv64_synth_emit_call_alloc(s)
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
                if arg_count == 0
                    riscv64_emit_li(s, 10, 32)
                    riscv64_synth_emit_call_alloc(s)
                else
                    total_alloc = 32 + (arg_count * 8)
                    riscv64_emit_li(s, 10, total_alloc)
                    riscv64_synth_emit_call_alloc(s)
                    riscv64_push_reg(s, 10)
                    ai = arg_count - 1
                    while ai >= 0
                        riscv64_pop_reg(s, 11)
                        riscv64_emit_ld(s, 12, 2, 0)
                        item_off = 24 + (ai * 8)
                        riscv64_emit_sd(s, 11, 12, item_off)
                        ai = ai - 1
                    riscv64_pop_reg(s, 10)
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
                    riscv64_push_reg(s, 10) // preserve struct pointer on stack
                    ai = arg_count - 1
                    while ai >= 0
                        riscv64_pop_reg(s, 11) // pop field value into a1
                        // ld a2, 0(sp) -> reload struct pointer into a2
                        riscv64_emit_ld(s, 12, 2, 0)
                        // sd a1, (ai*8)(a2)
                        riscv64_emit_sd(s, 11, 12, ai * 8)
                        ai = ai - 1
                    riscv64_pop_reg(s, 10) // restore struct pointer into a0
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
            call_off = s.rv_code.len()
            riscv64_emit_jal(s, 1, 0) // JAL ra, 0

            call_rel = Riscv64CallReloc()
            call_rel.rv_cr_patch_offset = call_off
            call_rel.rv_cr_target_name = var_name
            push(s.rv_call_relocs, call_rel)
            return 0

        // ── Struct Field Access: obj.field ──────────────────────────────────
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_DOT() or toks[next_pos].tok_text == ".")
            // Load base object pointer from local stack into a0
            off = riscv64_synth_lookup_var(s, var_name)
            if off > 0
                riscv64_emit_ld(s, 10, 2, off)
            else
                riscv64_emit_addi(s, 10, 0, 0)

            while get(pos_box, 0) < toks.len()
                cp = get(pos_box, 0)
                if toks[cp].tok_kind != TOK_DOT() and toks[cp].tok_text != "."
                    break
                list_set(pos_box, 0, cp + 1) // Consume '.'
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                    fn_tok = toks[get(pos_box, 0)]
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    f_off = riscv64_synth_get_field_offset(s, "", fn_tok.tok_text)
                    // ld a0, f_off(a0)
                    riscv64_emit_ld(s, 10, 10, f_off)
            return 0

        // Variable load: ld a0, off(sp)
        off = riscv64_synth_lookup_var(s, var_name)
        if off > 0
            riscv64_emit_ld(s, 10, 2, off)
        else
            riscv64_emit_addi(s, 10, 0, 0)
        return 0

    // 4. Parenthesized expression: ( expr )
    if k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_compile_expr(s, toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_pos + 1)
        return 0

    // Fallback: advance and clear a0
    list_set(pos_box, 0, pos + 1)
    riscv64_emit_addi(s, 10, 0, 0)
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

fn riscv64_synth_expr_rel s toks pos_box
    // WHY: Pratt precedence level 3 for comparison operators (==, !=, <, <=, >, >=) in RISC-V 64.
    riscv64_synth_expr_add(s, toks, pos_box)

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

        // Evaluate right operand with additive precedence into a0
        riscv64_synth_expr_add(s, toks, pos_box)

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

fn riscv64_synth_compile_expr s toks pos_box
    // WHY: Master expression evaluator for RISC-V 64 entering at relational precedence level.
    return riscv64_synth_expr_rel(s, toks, pos_box)

