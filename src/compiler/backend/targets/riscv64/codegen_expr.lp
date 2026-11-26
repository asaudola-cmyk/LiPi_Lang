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
    s.rv_last_is_uint = 0
    s.rv_last_expr_type = "int"

    // 0. Unary Operators (-, !, ~, not, না)
    if k == TOK_MINUS()
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_expr_primary(s, toks, pos_box)
        if s.rv_last_expr_type == "float"
            riscv64_emit_li(s, 5, 1)
            riscv64_emit_slli(s, 5, 5, 63)
            riscv64_emit_xor(s, 10, 10, 5)
        else
            riscv64_emit_sub(s, 10, 0, 10) // sub a0, x0, a0
        end
        return 0
    if k == TOK_BANG() or (k == TOK_IDENT() and (t.tok_text == "not" or t.tok_text == "না"))
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_expr_primary(s, toks, pos_box)
        riscv64_emit_sltiu(s, 10, 10, 1) // sltiu a0, a0, 1
        s.rv_last_expr_type = "int"
        return 0
    if k == TOK_TILDE()
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_expr_primary(s, toks, pos_box)
        riscv64_emit_xori(s, 10, 10, 0 - 1) // xori a0, a0, -1
        s.rv_last_expr_type = "int"
        return 0
    if k == TOK_KW_AWAIT() or (k == TOK_IDENT() and (t.tok_text == "await" or t.tok_text == "অপেক্ষা" or t.tok_text == "@await"))
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_expr_primary(s, toks, pos_box)
        return 0

    // 1. Integer / Boolean / Null Literal
    if k == TOK_INT() or k == TOK_BOOL() or k == TOK_NONE()
        list_set(pos_box, 0, pos + 1)
        riscv64_emit_li(s, 10, t.tok_int_val)
        s.rv_last_expr_type = "int"
        handled = 1

    // 1b. Float Literal: IEEE-754 binary64 64-bit precision
    if handled == 0 and k == TOK_FLOAT()
        list_set(pos_box, 0, pos + 1)
        fbits = riscv64_parse_float_bits(t.tok_text)
        riscv64_emit_li(s, 10, fbits)
        s.rv_last_expr_type = "float"
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

    // 1d. Closure Literal: fn(p1, p2) { ... } / => expr, |p1, p2| => expr / { ... }, || => expr
    if handled == 0 and (k == TOK_KW_FN() or (k == TOK_IDENT() and (t.tok_text == "fn" or t.tok_text == "কাজ"))) and pos + 1 < toks.len() and (toks[pos + 1].tok_kind == TOK_LPAREN() or toks[pos + 1].tok_text == "(")
        list_set(pos_box, 0, pos + 2)
        c_params = list()
        while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN() and toks[get(pos_box, 0)].tok_text != ")"
            pt = toks[get(pos_box, 0)]
            if riscv64_is_ident_token(pt.tok_kind) == 1
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
        riscv64_emit_closure_literal(s, toks, pos_box, c_params)
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
                if riscv64_is_ident_token(pt.tok_kind) == 1
                    push(c_params, pt.tok_text)
                end
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_BAR() or toks[get(pos_box, 0)].tok_text == "|")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        riscv64_emit_closure_literal(s, toks, pos_box, c_params)
        handled = 1
    end

    // 1e. Dict / HashMap Literal: { "k": v, ... } or {}
    if handled == 0 and (k == TOK_LBRACE() or (k != TOK_STR() and t.tok_text == "{"))
        list_set(pos_box, 0, pos + 1)
        s.rv_needs_dict = 1
        s.rv_needs_alloc = 1
        riscv64_emit_li(s, 10, 16)
        riscv64_synth_emit_call_helper(s, "__dict_new")
        riscv64_push_reg(s, 10)
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
            dp = get(pos_box, 0)
            if dp >= toks.len() break end
            if toks[dp].tok_kind == TOK_RBRACE() or (toks[dp].tok_kind != TOK_STR() and toks[dp].tok_text == "}")
                list_set(pos_box, 0, dp + 1)
                break
            end
            riscv64_synth_compile_expr(s, toks, pos_box)
            riscv64_push_reg(s, 10) // key
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            riscv64_synth_compile_expr(s, toks, pos_box) // a0 = val (a1 = tag if dyn_tagged)
            dval_t = s.rv_last_expr_type
            riscv64_emit_mv(s, 12, 10)
            if dval_t == "float"
                riscv64_emit_addi(s, 13, 0, 1)
            elif dval_t == "str"
                riscv64_emit_addi(s, 13, 0, 2)
            elif dval_t == "dyn_tagged"
                riscv64_emit_mv(s, 13, 11)
            else
                riscv64_emit_addi(s, 13, 0, 0)
            end
            riscv64_pop_reg(s, 11) // key
            riscv64_pop_reg(s, 10) // dict hdr
            riscv64_synth_emit_call_helper(s, "__dict_set")
            riscv64_push_reg(s, 10) // save dict hdr
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_COMMA()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        riscv64_pop_reg(s, 10)
        s.rv_last_expr_type = "int"
        handled = 1
    end

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
        s.rv_last_expr_type = "str"
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
            // Parse arguments and push to stack in order (also track arg types for tagged dict_set)
            arg_count = 0
            arg_types = list()
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                riscv64_synth_compile_expr(s, toks, pos_box)
                push(arg_types, s.rv_last_expr_type)
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
                riscv64_emit_li(s, 17, 94) // SYS_exit_group (94)
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
                        item_off = 32 + (ai * 8)
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

            // ── Intrinsic 9b: Dict / HashMap Intrinsics (DICT0 Parity) ──────
            if var_name == "dict" or var_name == "map" or var_name == "অভিধান" or (var_name == "map_new" and riscv64_synth_find_fn(s, "map_new") == 0)
                while arg_count > 1
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    riscv64_pop_reg(s, 10)
                else
                    riscv64_emit_li(s, 10, 16)
                end
                s.rv_needs_dict = 1
                s.rv_needs_alloc = 1
                riscv64_synth_emit_call_helper(s, "__dict_new")
                return 0
            end
            if var_name == "has_key" or var_name == "dict_has" or (var_name == "map_has" and riscv64_synth_find_fn(s, "map_has") == 0)
                while arg_count > 2
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.rv_needs_dict = 1
                    s.rv_needs_alloc = 1
                    riscv64_pop_reg(s, 11)
                    riscv64_pop_reg(s, 10)
                    riscv64_synth_emit_call_helper(s, "__dict_has")
                else
                    while arg_count > 0
                        riscv64_pop_reg(s, 11)
                        arg_count = arg_count - 1
                    end
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                return 0
            end
            if var_name == "del_key" or var_name == "dict_del" or (var_name == "map_del" and riscv64_synth_find_fn(s, "map_del") == 0)
                while arg_count > 2
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.rv_needs_dict = 1
                    s.rv_needs_alloc = 1
                    riscv64_pop_reg(s, 11)
                    riscv64_pop_reg(s, 10)
                    riscv64_synth_emit_call_helper(s, "__dict_del")
                else
                    while arg_count > 0
                        riscv64_pop_reg(s, 11)
                        arg_count = arg_count - 1
                    end
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                return 0
            end
            if var_name == "dict_get" or (var_name == "map_get" and riscv64_synth_find_fn(s, "map_get") == 0)
                while arg_count > 2
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.rv_needs_dict = 1
                    s.rv_needs_alloc = 1
                    riscv64_pop_reg(s, 11)
                    riscv64_pop_reg(s, 10)
                    riscv64_synth_emit_call_helper(s, "__dict_get")
                    s.rv_last_expr_type = "dyn_tagged"
                else
                    while arg_count > 0
                        riscv64_pop_reg(s, 11)
                        arg_count = arg_count - 1
                    end
                    riscv64_emit_addi(s, 10, 0, 0)
                    s.rv_last_expr_type = "int"
                end
                return 0
            end
            if var_name == "dict_set" or (var_name == "map_set" and riscv64_synth_find_fn(s, "map_set") == 0)
                while arg_count > 3
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 3
                    s.rv_needs_dict = 1
                    s.rv_needs_alloc = 1
                    ds_vtype = "int"
                    if arg_types.len() >= 3
                        ds_vtype = arg_types[2]
                    end
                    if ds_vtype == "float"
                        riscv64_emit_addi(s, 13, 0, 1)
                    elif ds_vtype == "str"
                        riscv64_emit_addi(s, 13, 0, 2)
                    else
                        riscv64_emit_addi(s, 13, 0, 0)
                    end
                    riscv64_pop_reg(s, 12)
                    riscv64_pop_reg(s, 11)
                    riscv64_pop_reg(s, 10)
                    riscv64_synth_emit_call_helper(s, "__dict_set")
                else
                    while arg_count > 0
                        riscv64_pop_reg(s, 11)
                        arg_count = arg_count - 1
                    end
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                s.rv_last_expr_type = "int"
                return 0
            end

            // ── Intrinsic 9c: ByteBuffer Intrinsics ─────────────────────────
            if var_name == "buf_new" or var_name == "byte_buf_new" or var_name == "বাফার_তৈরি"
                while arg_count > 1
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    riscv64_pop_reg(s, 10)
                else
                    riscv64_emit_li(s, 10, 64)
                end
                s.rv_needs_buf = 1
                s.rv_needs_alloc = 1
                riscv64_synth_emit_call_helper(s, "__buf_new")
                return 0
            end
            if var_name == "buf_write_byte" or var_name == "buf_append_byte" or var_name == "buf_push"
                while arg_count > 2
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.rv_needs_buf = 1
                    s.rv_needs_alloc = 1
                    riscv64_pop_reg(s, 11)
                    riscv64_pop_reg(s, 10)
                    riscv64_synth_emit_call_helper(s, "__buf_write_byte")
                else
                    while arg_count > 0
                        riscv64_pop_reg(s, 11)
                        arg_count = arg_count - 1
                    end
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                return 0
            end
            if var_name == "buf_write_str" or var_name == "buf_append" or var_name == "buf_append_str"
                while arg_count > 2
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.rv_needs_buf = 1
                    s.rv_needs_alloc = 1
                    riscv64_pop_reg(s, 11)
                    riscv64_pop_reg(s, 10)
                    riscv64_synth_emit_call_helper(s, "__buf_write_str")
                else
                    while arg_count > 0
                        riscv64_pop_reg(s, 11)
                        arg_count = arg_count - 1
                    end
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                return 0
            end
            if var_name == "buf_to_str"
                while arg_count > 1
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    s.rv_needs_buf = 1
                    s.rv_needs_alloc = 1
                    riscv64_pop_reg(s, 10)
                    riscv64_synth_emit_call_helper(s, "__buf_to_str")
                    s.rv_last_expr_type = "str"
                else
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                return 0
            end
            if var_name == "buf_len"
                while arg_count > 1
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    riscv64_pop_reg(s, 10)
                    riscv64_emit_ld(s, 10, 10, 8)
                else
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                return 0
            end
            if var_name == "buf_ptr"
                while arg_count > 1
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    riscv64_pop_reg(s, 10)
                    riscv64_emit_ld(s, 10, 10, 0)
                else
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                return 0
            end
            if var_name == "buf_clear"
                while arg_count > 1
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    riscv64_pop_reg(s, 10)
                    riscv64_emit_sd(s, 0, 10, 8)
                else
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                return 0
            end
            if var_name == "buf_get_byte"
                while arg_count > 2
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    riscv64_pop_reg(s, 11)
                    riscv64_pop_reg(s, 10)
                    riscv64_emit_ld(s, 5, 10, 0)
                    riscv64_emit_add(s, 5, 5, 11)
                    riscv64_emit_lbu(s, 10, 5, 0)
                else
                    while arg_count > 0
                        riscv64_pop_reg(s, 11)
                        arg_count = arg_count - 1
                    end
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                return 0
            end
            if var_name == "buf_free"
                while arg_count > 0
                    riscv64_pop_reg(s, 11)
                    arg_count = arg_count - 1
                end
                riscv64_emit_addi(s, 10, 0, 0)
                return 0
            end
            // ── Cross-Arch RISC-V 64 Silicon Hardware Intrinsics (MMIO, Fences, CSRs, Stack Trace) ──
            if var_name == "mmio_r8" or var_name == "mmio_r16" or var_name == "mmio_r32" or var_name == "mmio_r64"
                while arg_count > 1 riscv64_pop_reg(s, 11) arg_count = arg_count - 1 end
                if arg_count == 1
                    riscv64_pop_reg(s, 10)
                    if var_name == "mmio_r8" riscv64_synth_emit32(s, 345347)         // lbu a0, 0(a0)
                    elif var_name == "mmio_r16" riscv64_synth_emit32(s, 349443)      // lhu a0, 0(a0)
                    elif var_name == "mmio_r32" riscv64_synth_emit32(s, 353539)      // lwu a0, 0(a0)
                    else riscv64_synth_emit32(s, 341251)                             // ld  a0, 0(a0)
                    end
                else
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                return 0
            end
            if var_name == "mmio_w8" or var_name == "mmio_w16" or var_name == "mmio_w32" or var_name == "mmio_w64"
                while arg_count > 2 riscv64_pop_reg(s, 11) arg_count = arg_count - 1 end
                if arg_count == 2
                    riscv64_pop_reg(s, 11)
                    riscv64_pop_reg(s, 10)
                    if var_name == "mmio_w8" riscv64_synth_emit32(s, 11862051)       // sb a1, 0(a0)
                    elif var_name == "mmio_w16" riscv64_synth_emit32(s, 11866147)    // sh a1, 0(a0)
                    elif var_name == "mmio_w32" riscv64_synth_emit32(s, 11870243)    // sw a1, 0(a0)
                    else riscv64_synth_emit32(s, 11874339)                           // sd a1, 0(a0)
                    end
                else
                    while arg_count > 0 riscv64_pop_reg(s, 11) arg_count = arg_count - 1 end
                end
                riscv64_emit_addi(s, 10, 0, 0)
                return 0
            end
            if var_name == "cpu_fence" or var_name == "cpu_dmb" or var_name == "cpu_dsb" or var_name == "cpu_wfi" or var_name == "cpu_nop" or var_name == "cpu_halt" or var_name == "cpu_rdcycle" or var_name == "cpu_rdtime"
                while arg_count > 0 riscv64_pop_reg(s, 11) arg_count = arg_count - 1 end
                if var_name == "cpu_fence" or var_name == "cpu_dmb" or var_name == "cpu_dsb"
                    riscv64_synth_emit32(s, 267386895) // fence iorw, iorw
                    riscv64_emit_addi(s, 10, 0, 0)
                elif var_name == "cpu_wfi"
                    riscv64_synth_emit32(s, 273678451) // wfi
                    riscv64_emit_addi(s, 10, 0, 0)
                elif var_name == "cpu_nop"
                    riscv64_synth_emit32(s, 19)        // nop
                    riscv64_emit_addi(s, 10, 0, 0)
                elif var_name == "cpu_rdcycle"
                    riscv64_synth_emit32(s, 3221235059) // csrrs a0, cycle, x0
                elif var_name == "cpu_rdtime"
                    riscv64_synth_emit32(s, 3222283635) // csrrs a0, time, x0
                else
                    riscv64_synth_emit32(s, 273678451) // wfi
                    riscv64_emit_jal(s, 0, 0 - 4)      // j -4
                end
                return 0
            end
            if var_name == "stack_trace" or var_name == "backtrace" or var_name == "স্ট্যাক_ট্রেস"
                while arg_count > 0 riscv64_pop_reg(s, 11) arg_count = arg_count - 1 end
                if s.rv_freestanding == 1
                    riscv64_emit_load_rodata_str(s, 10, "  at " + s.rv_cur_fn_name + " (freestanding)\n")
                else
                    s.rv_needs_stack_trace = 1
                    s.rv_needs_buf = 1
                    s.rv_needs_alloc = 1
                    riscv64_synth_emit_call_helper(s, "_lipi_stack_trace")
                end
                s.rv_last_expr_type = "str"
                return 0
            end
            // ── ADT Tagged Enum Constructor: Ok(v), Err(e), Some(v), UserVariant(...) ──
            re_idx = riscv64_enum_find_idx(s, var_name)
            if re_idx >= 0
                re_tag = s.rv_enum_tags[re_idx]
                re_sz = (arg_count + 1) * 8
                if re_sz < 16 re_sz = 16 end
                s.rv_needs_alloc = 1
                riscv64_emit_li(s, 10, re_sz)
                riscv64_synth_emit_call_alloc(s)
                riscv64_emit_mv(s, 28, 10)
                riscv64_emit_li(s, 6, re_tag)
                riscv64_emit_sd(s, 6, 28, 0)
                ri_e = arg_count - 1
                while ri_e >= 0
                    riscv64_pop_reg(s, 11)
                    riscv64_emit_sd(s, 11, 28, (ri_e + 1) * 8)
                    ri_e = ri_e - 1
                end
                riscv64_emit_mv(s, 10, 28)
                return 0
            end

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

            // ── Indirect Closure/Fn-Ptr Call vs Direct Named Function Call ───
            lv_call = riscv64_find_local_var(s, var_name)
            if lv_call != 0
                riscv64_emit_local_ld(s, 29, lv_call.rv_lv_offset)
                if lv_call.rv_lv_is_boxed == 1
                    riscv64_emit_ld(s, 29, 29, 0)
                end
                riscv64_emit_indirect_call_t4(s)
            else
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
            end

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
                riscv64_emit_defers(s, toks)
                riscv64_emit_epilogue(s)
                riscv64_synth_patch_b(s, skip_beq_off, 0, 26, 0, s.rv_code.len())
            end
            s.rv_last_expr_type = "dyn_tagged"
        else
            // Unit ADT Variant (e.g. None or zero-arity enum variant) vs Local Variable Load
            re_u = riscv64_enum_find_idx(s, var_name)
            lv_rd = riscv64_find_local_var(s, var_name)
            if lv_rd != 0
                riscv64_emit_local_ld(s, 10, lv_rd.rv_lv_offset)
                if lv_rd.rv_lv_is_boxed == 1
                    riscv64_emit_ld(s, 10, 10, 0)
                end
                s.rv_last_is_uint = lv_rd.rv_lv_is_uint
                if lv_rd.rv_lv_prim_type != ""
                    s.rv_last_expr_type = lv_rd.rv_lv_prim_type
                else
                    s.rv_last_expr_type = "int"
                end
                if s.rv_last_expr_type == "dyn_tagged" and lv_rd.rv_lv_tag_off > 0
                    riscv64_emit_local_ld(s, 11, lv_rd.rv_lv_tag_off)
                end
            elif re_u >= 0
                s.rv_needs_alloc = 1
                riscv64_emit_li(s, 10, 16)
                riscv64_synth_emit_call_alloc(s)
                riscv64_emit_li(s, 6, s.rv_enum_tags[re_u])
                riscv64_emit_sd(s, 6, 10, 0)
                riscv64_emit_sd(s, 0, 10, 8)
            else
                riscv64_emit_addi(s, 10, 0, 0)
            end
        end

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
                    riscv64_emit_null_guard_reg(s, toks, 10)
                    f_off = riscv64_synth_get_field_offset(s, "", fn_tok.tok_text)
                    riscv64_emit_ld(s, 10, 10, f_off)
                    s.rv_last_expr_type = "int"
            else
                break
        elif ct.tok_kind == TOK_LBRACKET()
            list_set(pos_box, 0, cp + 1)
            riscv64_push_reg(s, 10) // Save hdr ptr
            riscv64_synth_compile_expr(s, toks, pos_box) // a0 = idx/key
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            riscv64_emit_mv(s, 11, 10)     // a1 = idx/key
            riscv64_pop_reg(s, 10)         // a0 = hdr
            s.rv_needs_dict = 1
            s.rv_needs_alloc = 1
            riscv64_synth_emit_call_helper(s, "__container_get")
            s.rv_last_expr_type = "dyn_tagged"
            if s.rv_try_patches.len() > 0
                npe_bne_off = s.rv_code.len()
                riscv64_emit_bne(s, 26, 0, 0)
                push(s.rv_try_patches[s.rv_try_patches.len() - 1], [npe_bne_off, 1])
            elif s.rv_in_function == 1
                npe_skip_eq = s.rv_code.len()
                riscv64_emit_beq(s, 26, 0, 0)
                riscv64_emit_addi(s, 2, 8, 0 - 1024)
                riscv64_emit_defers(s, toks)
                riscv64_emit_epilogue(s)
                riscv64_synth_patch_b(s, npe_skip_eq, 0, 26, 0, s.rv_code.len())
            end
        elif ct.tok_kind == TOK_QUERY() or (ct.tok_kind != TOK_STR() and ct.tok_text == "?")
            // Postfix `?` Result/Option propagation: if tag == Err(1002) or None(1004), early return a0; else unwrap [a0+8]
            list_set(pos_box, 0, cp + 1)
            riscv64_emit_ld(s, 5, 10, 0)
            riscv64_emit_li(s, 6, 1002)
            beq_q_ret1 = s.rv_code.len()
            riscv64_emit_beq(s, 5, 6, 0)
            riscv64_emit_li(s, 6, 1004)
            bne_q_ok = s.rv_code.len()
            riscv64_emit_bne(s, 5, 6, 0)
            q_ret_off = s.rv_code.len()
            riscv64_synth_patch_b(s, beq_q_ret1, 0, 5, 6, q_ret_off)
            riscv64_emit_addi(s, 2, 8, 0 - 1024)
            riscv64_emit_defers(s, toks)
            riscv64_emit_epilogue(s)
            q_ok_off = s.rv_code.len()
            riscv64_synth_patch_b(s, bne_q_ok, 1, 5, 6, q_ok_off)
            riscv64_emit_ld(s, 10, 10, 8)
        elif ct.tok_kind == TOK_LPAREN() and cp > 0 and ct.tok_span.span_start_line == toks[cp - 1].tok_span.span_start_line
            list_set(pos_box, 0, cp + 1)
            riscv64_push_reg(s, 10) // Save callee closure/fn_ptr
            p_argc = 0
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                riscv64_synth_compile_expr(s, toks, pos_box)
                riscv64_push_reg(s, 10)
                p_argc = p_argc + 1
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            if p_argc >= 8 riscv64_pop_reg(s, 17) end
            if p_argc >= 7 riscv64_pop_reg(s, 16) end
            if p_argc >= 6 riscv64_pop_reg(s, 15) end
            if p_argc >= 5 riscv64_pop_reg(s, 14) end
            if p_argc >= 4 riscv64_pop_reg(s, 13) end
            if p_argc >= 3 riscv64_pop_reg(s, 12) end
            if p_argc >= 2 riscv64_pop_reg(s, 11) end
            if p_argc >= 1 riscv64_pop_reg(s, 10) end
            riscv64_pop_reg(s, 29) // t4 = callee
            riscv64_emit_indirect_call_t4(s)
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
        lhs_u = s.rv_last_is_uint

        // Push left operand (a0) to stack
        riscv64_push_reg(s, 10)

        // Evaluate right operand into a0
        riscv64_synth_expr_primary(s, toks, pos_box)
        rhs_u = s.rv_last_is_uint

        // Move right operand to a1, pop left operand back into a0
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)

        if op_kind == TOK_STAR()
            riscv64_emit_mul(s, 10, 10, 11)
        elif op_kind == TOK_SLASH()
            if lhs_u == 1 or rhs_u == 1
                riscv64_emit_divu(s, 10, 10, 11)
            else
                riscv64_emit_div(s, 10, 10, 11)
            end
        elif op_kind == TOK_PERCENT()
            if lhs_u == 1 or rhs_u == 1
                riscv64_emit_remu(s, 10, 10, 11)
            else
                riscv64_emit_rem(s, 10, 10, 11)
            end
        end
        if lhs_u == 1 or rhs_u == 1 s.rv_last_is_uint = 1 else s.rv_last_is_uint = 0 end
        s.rv_last_expr_type = "int"

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
        lhs_ua = s.rv_last_is_uint

        // Push left operand (a0) to stack
        riscv64_push_reg(s, 10)

        // Evaluate right operand with multiplicative precedence into a0
        riscv64_synth_expr_mul(s, toks, pos_box)
        rhs_ua = s.rv_last_is_uint

        // Move right operand to a1, pop left operand back into a0
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)

        if op_kind == TOK_PLUS()
            riscv64_emit_add(s, 10, 10, 11)
        elif op_kind == TOK_MINUS()
            riscv64_emit_sub(s, 10, 10, 11)
        end
        if lhs_ua == 1 or rhs_ua == 1 s.rv_last_is_uint = 1 else s.rv_last_is_uint = 0 end
        s.rv_last_expr_type = "int"

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
        lhs_us = s.rv_last_is_uint
        riscv64_push_reg(s, 10)
        riscv64_synth_expr_add(s, toks, pos_box)
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)
        if k == TOK_SHL()
            riscv64_emit_sll(s, 10, 10, 11)
        elif lhs_us == 1
            riscv64_emit_srl(s, 10, 10, 11)
        else
            riscv64_emit_sra(s, 10, 10, 11)
        end
        s.rv_last_is_uint = lhs_us
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
        lhs_ur = s.rv_last_is_uint

        // Push left operand (a0) to stack
        riscv64_push_reg(s, 10)

        // Evaluate right operand into a0
        riscv64_synth_expr_shift(s, toks, pos_box)
        rhs_ur = s.rv_last_is_uint
        cmp_u = 0
        if lhs_ur == 1 or rhs_ur == 1 cmp_u = 1 end

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
            if cmp_u == 1
                riscv64_emit_sltu(s, 10, 10, 11)
            else
                riscv64_emit_slt(s, 10, 10, 11)
            end
        elif op_kind == TOK_LTE()
            if cmp_u == 1
                riscv64_emit_sltu(s, 10, 11, 10)
            else
                riscv64_emit_slt(s, 10, 11, 10)
            end
            riscv64_emit_xori(s, 10, 10, 1)
        elif op_kind == TOK_GT()
            if cmp_u == 1
                riscv64_emit_sltu(s, 10, 11, 10)
            else
                riscv64_emit_slt(s, 10, 11, 10)
            end
        elif op_kind == TOK_GTE()
            if cmp_u == 1
                riscv64_emit_sltu(s, 10, 10, 11)
            else
                riscv64_emit_slt(s, 10, 10, 11)
            end
            riscv64_emit_xori(s, 10, 10, 1)
        end
        s.rv_last_is_uint = 0

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

