// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN ARM64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/arm64/codegen_stmt.lp
// ==============================================================================

// ── 8. Statement Synthesizer ──────────────────────────────────────────────────

fn arm64_try_compile_multi_assign s toks pos_box start_pos
    // WHY: Handles swap-safe multi-RHS (`a, b = b, a`) and single-RHS tuple destructuring (`p, q = pair()`).
    if start_pos + 2 >= toks.len() return 0 end
    if toks[start_pos].tok_kind != TOK_IDENT() return 0 end
    if toks[start_pos + 1].tok_kind != TOK_COMMA() and not (toks[start_pos + 1].tok_kind != TOK_STR() and toks[start_pos + 1].tok_text == ",")
        return 0
    end
    lhs_names = list()
    push(lhs_names, toks[start_pos].tok_text)
    mp = start_pos + 1
    while mp < toks.len()
        if toks[mp].tok_kind == TOK_COMMA() or (toks[mp].tok_kind != TOK_STR() and toks[mp].tok_text == ",")
            mp = mp + 1
            if mp < toks.len() and toks[mp].tok_kind == TOK_IDENT()
                push(lhs_names, toks[mp].tok_text)
                mp = mp + 1
            else
                return 0
            end
        else
            break
        end
    end
    if lhs_names.len() < 2 or mp >= toks.len() or toks[mp].tok_kind != TOK_ASSIGN()
        return 0
    end
    eq_ln = toks[mp].tok_span.span_start_line
    list_set(pos_box, 0, mp + 1)
    arm64_synth_compile_expr(s, toks, pos_box)
    arm64_push_reg(s, 0)
    rhs_cnt = 1
    while get(pos_box, 0) < toks.len()
        rp = get(pos_box, 0)
        if (toks[rp].tok_kind == TOK_COMMA() or (toks[rp].tok_kind != TOK_STR() and toks[rp].tok_text == ",")) and toks[rp].tok_span.span_start_line == eq_ln
            list_set(pos_box, 0, rp + 1)
            arm64_synth_compile_expr(s, toks, pos_box)
            arm64_push_reg(s, 0)
            rhs_cnt = rhs_cnt + 1
        else
            break
        end
    end
    if rhs_cnt == 1
        // Single RHS list/tuple unpack: pop list header into temp slot, then extract element 0..N-1
        tup_off = arm64_synth_alloc_var(s, "__tup_" + str(s.synth_code.len()))
        arm64_pop_reg(s, 0)
        arm64_emit_str_reg_sp(s, 0, tup_off)
        li = 0
        while li < lhs_names.len()
            arm64_emit_ldr_reg_sp(s, 9, tup_off)
            arm64_emit_ldr_x_off(s, 10, 9, 16)
            arm64_emit_mov_imm64(s, 1, li * 8)
            arm64_emit_add_x(s, 10, 10, 1)
            arm64_emit_ldr_x_off(s, 0, 10, 0)
            vn = lhs_names[li]
            plv = arm64_find_local_var(s, vn)
            if plv == 0
                voff = arm64_synth_alloc_var(s, vn)
                arm64_emit_str_reg_sp(s, 0, voff)
            elif plv.a64_lv_is_boxed == 1
                arm64_emit_ldr_reg_sp(s, 9, plv.lv_offset)
                arm64_emit_str_x_off(s, 0, 9, 0)
            else
                arm64_emit_str_reg_sp(s, 0, plv.lv_offset)
            end
            li = li + 1
        end
    else
        // Multi-RHS: pop in reverse order for 100% swap-safety (e.g. `a, b = b, a`)
        li = rhs_cnt - 1
        while li >= 0
            arm64_pop_reg(s, 0)
            if li < lhs_names.len()
                vn = lhs_names[li]
                plv = arm64_find_local_var(s, vn)
                if plv == 0
                    voff = arm64_synth_alloc_var(s, vn)
                    arm64_emit_str_reg_sp(s, 0, voff)
                elif plv.a64_lv_is_boxed == 1
                    arm64_emit_ldr_reg_sp(s, 9, plv.lv_offset)
                    arm64_emit_str_x_off(s, 0, 9, 0)
                else
                    arm64_emit_str_reg_sp(s, 0, plv.lv_offset)
                end
            end
            li = li - 1
        end
    end
    return 1
end

fn arm64_synth_compile_statement s toks pos_box
    // WHY: Synthesizes execution bytes for statements (control flow, structs, loops, calls).
    s.a64_sp_delta = 0
    pos = get(pos_box, 0)
    if pos >= toks.len()
        return 0

    t = toks[pos]
    k = t.tok_kind
    txt = t.tok_text

    // Skip redundant newlines, semicolons, comments
    if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
        list_set(pos_box, 0, pos + 1)
        return 0

    // Consume standalone block end markers (@end, end, শেষ)
    if k == TOK_KW_END() or k == TOK_DIR_END() or (k == TOK_IDENT() and (txt == "@end" or txt == "end" or txt == "শেষ"))
        list_set(pos_box, 0, pos + 1)
        return 0

    // Skip compiler attribute directives (@strict, @fn_strict, @kavach, @freestanding, @attr_*)
    if k == TOK_IDENT() and (txt == "@strict" or txt == "@fn_strict" or txt == "@strict_types" or txt == "@strict_ownership" or txt == "@strict_proof" or txt == "@kavach" or txt == "@freestanding" or txt == "@ring0" or txt == "@silicon" or txt == "@packed" or txt == "@naked" or txt == "@interrupt" or str_starts_with(txt, "@attr_") == 1)
        list_set(pos_box, 0, pos + 1)
        return 0
    end

    // ── 1. Output Statement: say / বলো / print / println / show / দেখাও ──────────
    is_print = 0
    if k == TOK_KW_PRINT()
        is_print = 1
    if k == TOK_IDENT() and (txt == "say" or txt == "বলো" or txt == "print" or txt == "println" or txt == "show" or txt == "দেখাও")
        is_print = 1

    if is_print == 1
        list_set(pos_box, 0, pos + 1) // Consume keyword
        next_pos = get(pos_box, 0)
        if next_pos < toks.len()
            next_tok = toks[next_pos]
            // Direct string constant print optimization:
            after_next = next_pos + 1
            is_simple_str = 0
            if next_tok.tok_kind == TOK_STR()
                if after_next >= toks.len() or toks[after_next].tok_kind == TOK_NEWLINE() or toks[after_next].tok_kind == TOK_SEMI() or toks[after_next].tok_kind == TOK_EOF()
                    is_simple_str = 1

            if is_simple_str == 1
                list_set(pos_box, 0, next_pos + 1)
                arm64_emit_print_string(s, next_tok.tok_text)
                return 0

        // General expression print (ints, uints, floats, strings, dyn_tagged):
        arm64_synth_compile_expr(s, toks, pos_box)
        if s.a64_last_expr_type == "str"
            s.a64_needs_print_tagged = 1
            arm64_synth_emit_call_helper(s, "__print_str")
        elif s.a64_last_expr_type == "float"
            s.a64_needs_print_tagged = 1
            arm64_synth_emit_call_helper(s, "__print_float")
        elif s.a64_last_expr_type == "dyn_tagged"
            s.a64_needs_print_tagged = 1
            s.synth_needs_print_int = 1
            arm64_synth_emit_call_helper(s, "__print_tagged")
        elif s.a64_last_is_uint == 1
            arm64_synth_emit_call_print_uint(s)
        else
            arm64_synth_emit_call_print_int(s)
        end
        return 0

    // ── 1b. Deferred Execution: defer / @defer / বিলম্ব ─────────────────────────
    if k != TOK_STR() and (txt == "defer" or txt == "@defer" or txt == "বিলম্ব")
        is_def = 1
        if pos + 1 < toks.len()
            dn_k = toks[pos + 1].tok_kind
            dn_t = toks[pos + 1].tok_text
            if dn_k == TOK_ASSIGN() or dn_t == "=" or dn_k == TOK_LPAREN() or dn_t == "(" or dn_k == TOK_DOT() or dn_t == "."
                is_def = 0
            end
        end
        if is_def == 1
            d_line = t.tok_span.span_start_line
            d_start = pos + 1
            if d_start < toks.len() and (toks[d_start].tok_kind == TOK_LBRACE() or toks[d_start].tok_text == "{")
                d_start = d_start + 1
                d_scan = d_start
                d_bd = 1
                while d_scan < toks.len() and d_bd > 0
                    if toks[d_scan].tok_kind == TOK_LBRACE() or toks[d_scan].tok_text == "{"
                        d_bd = d_bd + 1
                    elif toks[d_scan].tok_kind == TOK_RBRACE() or toks[d_scan].tok_text == "}"
                        d_bd = d_bd - 1
                        if d_bd == 0 break end
                    end
                    d_scan = d_scan + 1
                end
                push(s.a64_defer_starts, d_start)
                push(s.a64_defer_ends, d_scan)
                if d_scan < toks.len() d_scan = d_scan + 1 end
                list_set(pos_box, 0, d_scan)
            else
                d_scan = d_start
                while d_scan < toks.len() and toks[d_scan].tok_kind != TOK_NEWLINE() and toks[d_scan].tok_kind != TOK_SEMI() and toks[d_scan].tok_kind != TOK_EOF() and toks[d_scan].tok_span.span_start_line == d_line
                    d_scan = d_scan + 1
                end
                push(s.a64_defer_starts, d_start)
                push(s.a64_defer_ends, d_scan)
                list_set(pos_box, 0, d_scan)
            end
            return 0
        end
    end

    // ── 2. Control Flow: return / ফেরত ─────────────────────────────────────────
    if k == TOK_KW_RETURN() or (k == TOK_IDENT() and (txt == "return" or txt == "ফেরত"))
        list_set(pos_box, 0, pos + 1) // Consume keyword
        next_pos = get(pos_box, 0)
        has_expr = 0
        if next_pos < toks.len()
            nt = toks[next_pos]
            if nt.tok_kind != TOK_NEWLINE() and nt.tok_kind != TOK_SEMI() and nt.tok_kind != TOK_EOF() and nt.tok_kind != TOK_KW_END() and nt.tok_kind != TOK_DIR_END() and nt.tok_kind != TOK_RBRACE() and not (nt.tok_kind == TOK_IDENT() and (nt.tok_text == "end" or nt.tok_text == "শেষ" or nt.tok_text == "@end"))
                has_expr = 1

        if has_expr == 1
            ret_ln = t.tok_span.span_start_line
            arm64_synth_compile_expr(s, toks, pos_box)
            // Tuple return: `return e1, e2 [, ...]` packs values into a first-class list
            cp_rt = get(pos_box, 0)
            if cp_rt < toks.len() and (toks[cp_rt].tok_kind == TOK_COMMA() or (toks[cp_rt].tok_kind != TOK_STR() and toks[cp_rt].tok_text == ",")) and toks[cp_rt].tok_span.span_start_line == ret_ln
                arm64_push_reg(s, 0)
                rt_cnt = 1
                while get(pos_box, 0) < toks.len()
                    cr_p = get(pos_box, 0)
                    if (toks[cr_p].tok_kind == TOK_COMMA() or (toks[cr_p].tok_kind != TOK_STR() and toks[cr_p].tok_text == ",")) and toks[cr_p].tok_span.span_start_line == ret_ln
                        list_set(pos_box, 0, cr_p + 1)
                        arm64_synth_compile_expr(s, toks, pos_box)
                        arm64_push_reg(s, 0)
                        rt_cnt = rt_cnt + 1
                    else
                        break
                    end
                end
                s.a64_needs_list_create = 1
                s.synth_needs_alloc = 1
                arm64_emit_mov_imm64(s, 0, rt_cnt)
                rt_call_off = s.synth_code.len()
                arm64_emit_bl(s, 0)
                rt_rel = Arm64CallReloc()
                rt_rel.a64_cr_patch_offset = rt_call_off
                rt_rel.a64_cr_target_name = "__list_create"
                push(s.synth_call_relocs, rt_rel)
                arm64_emit_mov_reg(s, 9, 0)
                arm64_synth_emit32(s, 4181721088 | (2 << 10) | (9 << 5) | 10) // ldr x10, [x9, #16]
                ri_t = rt_cnt - 1
                while ri_t >= 0
                    arm64_pop_reg(s, 1)
                    arm64_emit_mov_imm64(s, 2, ri_t * 8)
                    arm64_emit_add_x(s, 2, 10, 2)
                    arm64_synth_emit32(s, 4177526784 | (0 << 10) | (2 << 5) | 1) // str x1, [x2, #0]
                    ri_t = ri_t - 1
                end
                arm64_emit_mov_reg(s, 0, 9)
                arm64_emit_movz_x(s, 1, 0, 0)
                s.a64_last_expr_type = "int"
            else
                if s.a64_last_expr_type == "float"
                    arm64_emit_movz_x(s, 1, 1, 0)
                elif s.a64_last_expr_type == "str"
                    arm64_emit_movz_x(s, 1, 2, 0)
                elif s.a64_last_expr_type != "dyn_tagged"
                    arm64_emit_movz_x(s, 1, 0, 0)
                end
            end
        else
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_movz_x(s, 1, 0, 0)
        end

        if s.a64_in_function == 1
            arm64_emit_defers(s, toks)
            arm64_emit_epilogue(s)
        else
            // Top-level return: exit whole process cleanly with code in X0 via Linux SYS_exit_group (94)
            arm64_emit_defers(s, toks)
            arm64_emit_movz_x(s, 8, 94, 0)
            arm64_emit_svc(s, 0)
        return 0

    // ── 3. Loop Control: break / থামো & continue / চলুক ───────────────────────
    if k == TOK_KW_BREAK() or (k == TOK_IDENT() and (txt == "break" or txt == "থামো"))
        list_set(pos_box, 0, pos + 1)
        if s.synth_loop_breaks.len() > 0
            p_off = s.synth_code.len()
            arm64_emit_b(s, 0) // Placeholder
            curr_brk_list = s.synth_loop_breaks[s.synth_loop_breaks.len() - 1]
            push(curr_brk_list, p_off)
        return 0

    if k == TOK_KW_CONTINUE() or (k == TOK_IDENT() and (txt == "continue" or txt == "চলুক" or txt == "চলো"))
        list_set(pos_box, 0, pos + 1)
        if s.synth_loop_starts.len() > 0
            loop_hdr = s.synth_loop_starts[s.synth_loop_starts.len() - 1]
            cur_off = s.synth_code.len()
            if loop_hdr < 0 and s.a64_for_conts.len() > 0
                arm64_emit_b(s, 0)
                fc_list = s.a64_for_conts[s.a64_for_conts.len() - 1]
                push(fc_list, cur_off)
            else
                rel_words = (loop_hdr - cur_off) / 4
                arm64_emit_b(s, rel_words)
            end
        return 0

    // ── 4b. ADT Enum Definition: enum / @enum Name { Variant(T), ... } ───────
    if k == TOK_KW_ENUM() or k == TOK_DIR_ENUM() or (k == TOK_IDENT() and (txt == "enum" or txt == "@enum"))
        eb_col = t.tok_span.span_start_col
        eb_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        e_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            e_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            ep = get(pos_box, 0)
            if ep >= toks.len() break end
            et = toks[ep]
            ek = et.tok_kind
            ex = et.tok_text
            if ek == TOK_EOF() break end
            if e_braced == 1 and (ek == TOK_RBRACE() or ex == "}")
                list_set(pos_box, 0, ep + 1)
                break
            end
            if e_braced == 0
                if ek == TOK_KW_END() or ek == TOK_DIR_END() or ex == "end" or ex == "@end" or ex == "শেষ"
                    list_set(pos_box, 0, ep + 1)
                    break
                end
                if et.tok_span.span_start_line > eb_line and et.tok_span.span_start_col <= eb_col
                    break
                end
            end
            if ek == TOK_COMMA() or ex == ","
                list_set(pos_box, 0, ep + 1)
                continue
            end
            if ek == TOK_IDENT()
                vname = ex
                list_set(pos_box, 0, ep + 1)
                arity = 0
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                        arity = 1
                    end
                    while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN() and toks[get(pos_box, 0)].tok_kind != TOK_EOF()
                        if toks[get(pos_box, 0)].tok_kind == TOK_COMMA()
                            arity = arity + 1
                        end
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                end
                arm64_enum_register(s, vname, s.a64_next_enum_tag, arity)
                s.a64_next_enum_tag = s.a64_next_enum_tag + 1
            else
                list_set(pos_box, 0, ep + 1)
            end
        end
        return 0
    end

    // ── 4c. Trait Declaration: trait / @trait / বৈশিষ্ট্য Name { ... } ────────
    if (k == TOK_DIR_TRAIT() or (k == TOK_IDENT() and (txt == "trait" or txt == "বৈশিষ্ট্য" or txt == "@trait"))) and pos + 1 < toks.len() and toks[pos + 1].tok_kind == TOK_IDENT()
        tr_col = t.tok_span.span_start_col
        tr_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 2)
        tr_bd = 0
        tr_saw = 0
        while get(pos_box, 0) < toks.len()
            tt_p = get(pos_box, 0)
            tt = toks[tt_p]
            if tt.tok_kind == TOK_EOF() break end
            if tt.tok_kind == TOK_LBRACE() or (tt.tok_kind != TOK_STR() and tt.tok_text == "{")
                tr_bd = tr_bd + 1
                tr_saw = 1
                list_set(pos_box, 0, tt_p + 1)
            elif tt.tok_kind == TOK_RBRACE() or (tt.tok_kind != TOK_STR() and tt.tok_text == "}")
                list_set(pos_box, 0, tt_p + 1)
                if tr_bd > 0
                    tr_bd = tr_bd - 1
                    if tr_bd == 0 and tr_saw == 1
                        break
                    end
                end
            elif tr_saw == 0
                if (tt.tok_kind == TOK_KW_END() or tt.tok_kind == TOK_DIR_END() or (tt.tok_kind == TOK_IDENT() and (tt.tok_text == "end" or tt.tok_text == "শেষ" or tt.tok_text == "@end"))) and tt.tok_span.span_start_col <= tr_col
                    list_set(pos_box, 0, tt_p + 1)
                    break
                end
                if tt.tok_span.span_start_line > tr_line and tt.tok_span.span_start_col <= tr_col and tt.tok_kind != TOK_NEWLINE()
                    break
                end
                list_set(pos_box, 0, tt_p + 1)
            else
                list_set(pos_box, 0, tt_p + 1)
            end
        end
        return 0
    end

    // ── 4d. Trait / Inherent Impl Block: impl [Trait for] TargetType { ... } ──
    if (k == TOK_KW_IMPL() or k == TOK_DIR_IMPL() or (k == TOK_IDENT() and (txt == "impl" or txt == "বাস্তবায়ন" or txt == "@impl"))) and pos + 1 < toks.len()
        imp_col = t.tok_span.span_start_col
        imp_line = t.tok_span.span_start_line
        ip = pos + 1
        if ip < toks.len() and toks[ip].tok_text == "<"
            gd = 1
            ip = ip + 1
            while ip < toks.len() and gd > 0
                if toks[ip].tok_text == "<" gd = gd + 1
                elif toks[ip].tok_text == ">" gd = gd - 1 end
                ip = ip + 1
            end
        end
        imp_t = ""
        if ip < toks.len() and toks[ip].tok_kind == TOK_IDENT()
            imp_t = toks[ip].tok_text
            ip = ip + 1
            if ip < toks.len() and toks[ip].tok_text == "<"
                gd = 1
                ip = ip + 1
                while ip < toks.len() and gd > 0
                    if toks[ip].tok_text == "<" gd = gd + 1
                    elif toks[ip].tok_text == ">" gd = gd - 1 end
                    ip = ip + 1
                end
            end
            if ip < toks.len() and (toks[ip].tok_kind == TOK_KW_FOR() or toks[ip].tok_text == "for" or toks[ip].tok_text == "জন্য")
                ip = ip + 1
                if ip < toks.len() and toks[ip].tok_kind == TOK_IDENT()
                    imp_t = toks[ip].tok_text
                    ip = ip + 1
                end
                if ip < toks.len() and toks[ip].tok_text == "<"
                    gd = 1
                    ip = ip + 1
                    while ip < toks.len() and gd > 0
                        if toks[ip].tok_text == "<" gd = gd + 1
                        elif toks[ip].tok_text == ">" gd = gd - 1 end
                        ip = ip + 1
                    end
                end
            end
        end
        list_set(pos_box, 0, ip)
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        imp_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            imp_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        saved_impl = s.a64_impl_type
        s.a64_impl_type = imp_t
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            icp = get(pos_box, 0)
            if icp >= toks.len() break end
            ict = toks[icp]
            ick = ict.tok_kind
            icx = ict.tok_text
            if ick == TOK_EOF() break end
            if imp_braced == 1
                if ick == TOK_RBRACE() or icx == "}"
                    list_set(pos_box, 0, icp + 1)
                    break
                end
            else
                if ick == TOK_KW_END() or ick == TOK_DIR_END() or (ick == TOK_IDENT() and (icx == "end" or icx == "শেষ" or icx == "@end"))
                    list_set(pos_box, 0, icp + 1)
                    break
                end
                if ict.tok_span.span_start_line > imp_line and ict.tok_span.span_start_col <= imp_col
                    break
                end
            end
            ib_p = get(pos_box, 0)
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == ib_p
                list_set(pos_box, 0, ib_p + 1)
            end
        end
        s.a64_impl_type = saved_impl
        return 0
    end

    // ── 4. Struct / Union Definition: struct / union / গঠন / ইউনিয়ন ────────────
    is_struct = 0
    is_union_decl = 0
    if k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT()
        is_struct = 1
    if k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct")
        is_struct = 1
    if k == TOK_IDENT() and (txt == "union" or txt == "ইউনিয়ন" or txt == "@union")
        is_struct = 1
        is_union_decl = 1

    if is_struct == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'struct' / 'union'

        sname_tok = toks[get(pos_box, 0)]
        sname = sname_tok.tok_text
        list_set(pos_box, 0, get(pos_box, 0) + 1)

        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        s_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            s_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end

        fields = list()
        field_types = list()
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if s_braced == 1
                if cur_k == TOK_RBRACE() or cur_txt == "}"
                    list_set(pos_box, 0, cur_p + 1)
                    break
                end
                if cur_k == TOK_EOF()
                    break
                end
                if cur_k == TOK_COMMA() or cur_txt == ","
                    list_set(pos_box, 0, cur_p + 1)
                    continue
                end
            else
                if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                    list_set(pos_box, 0, cur_p + 1)
                    break
                if cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN() or cur_k == TOK_KW_STRUCT() or cur_k == TOK_DIR_STRUCT()
                    break
                if cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "struct" or cur_txt == "গঠন" or cur_txt == "union" or cur_txt == "ইউনিয়ন")
                    break
                if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                    break
            end

            if cur_k == TOK_IDENT()
                push(fields, cur_txt)
                ft_nm_s = ""
                list_set(pos_box, 0, cur_p + 1)
                // Capture optional type annotation: : i64 / : f64 / : u64
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_COLON()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                        ft_nm_s = toks[get(pos_box, 0)].tok_text
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                end
                push(field_types, ft_nm_s)
            else
                list_set(pos_box, 0, cur_p + 1)
            end

        if arm64_synth_find_struct(s, sname) == 0
            sdef = Arm64StructDef()
            sdef.sd_name = sname
            sdef.sd_fields = fields
            sdef.a64_sd_is_union = is_union_decl
            sdef.a64_sd_type_id = s.a64_next_type_id
            sdef.a64_sd_field_types = field_types
            s.a64_next_type_id = s.a64_next_type_id + 1
            push(s.synth_structs, sdef)
        end
        return 0

    // ── 5.0 Mixed / Multi-Level Chained L-Value Assignment: o.inn.arr[1] = 99, m[i][j] = 5, a[0].f = 7 ──
    if k == TOK_IDENT() and pos + 2 < toks.len()
        a_scan = pos + 1
        a_kinds = list()
        a_fields = list()
        a_starts = list()
        a_has_brk = 0
        while a_scan < toks.len()
            at_l = toks[a_scan]
            ak_l = at_l.tok_kind
            ax_l = at_l.tok_text
            if (ak_l == TOK_DOT() or (ak_l != TOK_STR() and ax_l == ".")) and a_scan + 1 < toks.len() and arm64_is_ident_token(toks[a_scan + 1].tok_kind) == 1
                push(a_kinds, 0)
                push(a_fields, toks[a_scan + 1].tok_text)
                push(a_starts, a_scan + 1)
                a_scan = a_scan + 2
            elif ak_l == TOK_LBRACKET() or (ak_l != TOK_STR() and ax_l == "[")
                ab_d = 1
                ab_c = a_scan + 1
                while ab_c < toks.len() and ab_d > 0
                    abk = toks[ab_c].tok_kind
                    if abk == TOK_LBRACKET()
                        ab_d = ab_d + 1
                    elif abk == TOK_RBRACKET()
                        ab_d = ab_d - 1
                        if ab_d == 0
                            break
                        end
                    end
                    ab_c = ab_c + 1
                end
                if ab_d == 0 and ab_c < toks.len()
                    push(a_kinds, 1)
                    push(a_fields, "")
                    push(a_starts, a_scan + 1)
                    a_has_brk = 1
                    a_scan = ab_c + 1
                else
                    break
                end
            else
                break
            end
        end
        if a_has_brk == 1 and a_kinds.len() >= 2 and a_scan < toks.len() and (toks[a_scan].tok_kind == TOK_ASSIGN() or toks[a_scan].tok_text == "=")
            a_off = arm64_synth_lookup_var(s, txt)
            a_stype = arm64_synth_get_var_struct(s, txt)
            if a_off > 0
                arm64_emit_ldr_reg_sp(s, 0, a_off)
            else
                arm64_emit_movz_x(s, 0, 0, 0)
            end
            a_n = a_kinds.len()
            a_si = 0
            while a_si < a_n - 1
                if a_kinds[a_si] == 0
                    am_off = arm64_synth_get_field_offset(s, a_stype, a_fields[a_si])
                    a_stype = ""
                    am_sc = (am_off / 8) & 4095
                    arm64_synth_emit32(s, 4181721088 | (am_sc << 10) | (0 << 5) | 0) // ldr x0, [x0, #am_off]
                else
                    arm64_push_reg(s, 0) // save list ptr
                    a_ipb = [a_starts[a_si]]
                    arm64_synth_compile_expr(s, toks, a_ipb) // X0 = idx
                    arm64_pop_reg(s, 1) // X1 = list hdr
                    arm64_synth_emit32(s, 4181723171) // ldr x3, [x1, #16] (data_ptr)
                    arm64_emit_add_x(s, 0, 0, 0)
                    arm64_emit_add_x(s, 0, 0, 0)
                    arm64_emit_add_x(s, 0, 0, 0)
                    arm64_emit_add_x(s, 3, 3, 0)
                    arm64_synth_emit32(s, 4181721184) // ldr x0, [x3, #0]
                    a_stype = ""
                end
                a_si = a_si + 1
            end
            a_leaf = a_n - 1
            if a_kinds[a_leaf] == 0
                arm64_push_reg(s, 0) // save parent struct ptr
                list_set(pos_box, 0, a_scan + 1)
                arm64_synth_compile_expr(s, toks, pos_box) // X0 = rhs
                arm64_pop_reg(s, 1) // X1 = parent
                alf_off = arm64_synth_get_field_offset(s, a_stype, a_fields[a_leaf])
                alf_sc = (alf_off / 8) & 4095
                arm64_synth_emit32(s, 4177526784 | (alf_sc << 10) | (1 << 5) | 0) // str x0, [x1, #alf_off]
                return 0
            else
                arm64_push_reg(s, 0) // save list ptr
                a_lpb = [a_starts[a_leaf]]
                arm64_synth_compile_expr(s, toks, a_lpb) // X0 = leaf_idx
                arm64_push_reg(s, 0) // save leaf_idx
                list_set(pos_box, 0, a_scan + 1)
                arm64_synth_compile_expr(s, toks, pos_box) // X0 = rhs
                arm64_emit_add_x(s, 2, 0, 31) // X2 = rhs (mov x2, x0)
                arm64_pop_reg(s, 1) // X1 = leaf_idx
                arm64_pop_reg(s, 0) // X0 = list hdr
                arm64_synth_emit32(s, 4181723139) // ldr x3, [x0, #16]
                arm64_emit_add_x(s, 1, 1, 1)
                arm64_emit_add_x(s, 1, 1, 1)
                arm64_emit_add_x(s, 1, 1, 1)
                arm64_emit_add_x(s, 3, 3, 1)
                arm64_synth_emit32(s, 4177526882) // str x2, [x3, #0]
                return 0
            end
        end
    end

    // ── 5. Struct Field Assignment: obj.field (= | += | -= | *= | /= | %=) expr ──
    if k == TOK_IDENT()
        p1 = pos + 1
        p2 = pos + 2
        p3 = pos + 3
        if p3 < toks.len()
            t1 = toks[p1]
            t2 = toks[p2]
            t3 = toks[p3]
            is_dot = 0
            if t1.tok_kind == TOK_DOT() or t1.tok_text == "."
                is_dot = 1
            is_assign = 0
            f_comp_op = 0
            if t3.tok_kind == TOK_ASSIGN() or (t3.tok_kind != TOK_STR() and t3.tok_text == "=")
                is_assign = 1
            elif t3.tok_kind == TOK_PLUSEQ() or (t3.tok_kind != TOK_STR() and t3.tok_text == "+=")
                is_assign = 1
                f_comp_op = TOK_PLUS()
            elif t3.tok_kind == TOK_MINUSEQ() or (t3.tok_kind != TOK_STR() and t3.tok_text == "-=")
                is_assign = 1
                f_comp_op = TOK_MINUS()
            elif t3.tok_kind == TOK_STAREQ() or (t3.tok_kind != TOK_STR() and t3.tok_text == "*=")
                is_assign = 1
                f_comp_op = TOK_STAR()
            elif t3.tok_kind == TOK_SLASHEQ() or (t3.tok_kind != TOK_STR() and t3.tok_text == "/=")
                is_assign = 1
                f_comp_op = TOK_SLASH()
            elif t3.tok_kind == TOK_PERCENTEQ() or (t3.tok_kind != TOK_STR() and t3.tok_text == "%=")
                is_assign = 1
                f_comp_op = TOK_PERCENT()
            end

            if is_dot == 1 and arm64_is_ident_token(t2.tok_kind) == 1 and is_assign == 1
                obj_name = txt
                field_name = t2.tok_text
                list_set(pos_box, 0, p3 + 1) // Consume obj, '.', field, op

                // Evaluate RHS expr into X0 (plus X1 tag if dyn_tagged)
                arm64_synth_compile_expr(s, toks, pos_box)
                f_rhs_t = s.a64_last_expr_type
                f_rhs_u = s.a64_last_is_uint
                arm64_push_reg(s, 0)
                if f_rhs_t == "dyn_tagged"
                    arm64_push_reg(s, 1)
                end

                // Load obj pointer into X1 and guard against null/low dereference
                obj_off = arm64_synth_lookup_var(s, obj_name)
                if obj_off > 0
                    arm64_emit_ldr_reg_sp(s, 1, obj_off)
                else
                    arm64_emit_movz_x(s, 1, 0, 0)
                end
                arm64_emit_null_guard_reg(s, toks, 1)
                arm64_emit_mov_reg(s, 13, 1) // X13 = obj_ptr (preserved across FP/ALU helpers)

                // Pop RHS (and optional runtime tag into X11)
                if f_rhs_t == "dyn_tagged"
                    arm64_pop_reg(s, 11)
                end
                arm64_pop_reg(s, 10) // X10 = rhs

                obj_sname = arm64_synth_get_var_struct(s, obj_name)
                f_off = arm64_synth_get_field_offset(s, obj_sname, field_name)
                f_decl_t = arm64_synth_get_field_type(s, obj_sname, field_name)
                f_is_flt = arm64_is_float_type(f_decl_t)
                f_is_u = arm64_is_uint_type(f_decl_t)
                scaled_fo = (f_off / 8) & 4095

                if f_comp_op == 0
                    arm64_emit_mov_reg(s, 0, 10)
                    if f_is_flt == 1 and f_rhs_t != "float"
                        // WHY: Promote integer RHS to IEEE-754 f64 when storing into an f64 struct field.
                        arm64_emit_load_fp_reg(s, 0, 0, f_rhs_t, f_rhs_u, 11)
                        arm64_emit_fmov_x_d(s, 0, 0)
                    end
                else
                    // WHY: Load existing field into X0, perform hardware IEEE-754 f64 or guarded integer op.
                    arm64_synth_emit32(s, 4181721088 | (scaled_fo << 10) | (13 << 5) | 0) // ldr x0, [x13, #f_off]
                    if f_is_flt == 1 or f_rhs_t == "float"
                        f_lhs_t = "int"
                        if f_is_flt == 1 f_lhs_t = "float" end
                        arm64_emit_load_fp_reg(s, 0, 0, f_lhs_t, f_is_u, 9)
                        arm64_emit_load_fp_reg(s, 1, 10, f_rhs_t, f_rhs_u, 11)
                        arm64_emit_fp_arith_op(s, f_comp_op)
                    else
                        arm64_emit_mov_reg(s, 1, 10)
                        fc_u = f_is_u
                        if f_rhs_u == 1 fc_u = 1 end
                        if f_comp_op == TOK_PLUS()
                            arm64_emit_add_x(s, 0, 0, 1)
                        elif f_comp_op == TOK_MINUS()
                            arm64_emit_sub_x(s, 0, 0, 1)
                        elif f_comp_op == TOK_STAR()
                            arm64_emit_mul_x(s, 0, 0, 1)
                        elif f_comp_op == TOK_SLASH()
                            if fc_u == 1 arm64_emit_udiv_x(s, 0, 0, 1) else arm64_emit_sdiv_x(s, 0, 0, 1) end
                        elif f_comp_op == TOK_PERCENT()
                            if fc_u == 1 arm64_emit_udiv_x(s, 2, 0, 1) else arm64_emit_sdiv_x(s, 2, 0, 1) end
                            arm64_emit_mul_x(s, 2, 2, 1)
                            arm64_emit_sub_x(s, 0, 0, 2)
                            arm64_emit_cmp_x(s, 1, 31)
                            arm64_synth_emit32(s, 2592080864) // csel x0, xzr, x0, eq
                        end
                    end
                end

                // Store value to field: str X0, [X13, #f_off]
                st_word = 4177526784 | (scaled_fo << 10) | (13 << 5) | 0
                arm64_synth_emit32(s, st_word)
                return 0

    // ── 5b. Indexed Element Assignment: arr[idx] = expr ────────────────────────
    if k == TOK_IDENT()
        if pos + 2 < toks.len() and toks[pos + 1].tok_kind == TOK_LBRACKET()
            scan_p = pos + 2
            brk_depth = 1
            while scan_p < toks.len() and brk_depth > 0
                sk = toks[scan_p].tok_kind
                if sk == TOK_LBRACKET()
                    brk_depth = brk_depth + 1
                elif sk == TOK_RBRACKET()
                    brk_depth = brk_depth - 1
                end
                scan_p = scan_p + 1
            end
            if brk_depth == 0 and scan_p < toks.len() and toks[scan_p].tok_kind == TOK_ASSIGN()
                arr_name = txt
                list_set(pos_box, 0, pos + 2)
                arm64_synth_compile_expr(s, toks, pos_box) // X0 = idx
                arm64_push_reg(s, 0)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_ASSIGN()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                arm64_synth_compile_expr(s, toks, pos_box) // X0 = rhs (X1 = tag if dyn_tagged)
                cs_rhs_type = s.a64_last_expr_type
                arm64_push_reg(s, 0)
                if cs_rhs_type == "dyn_tagged"
                    arm64_push_reg(s, 1)
                end
                lv_arr = arm64_find_local_var(s, arr_name)
                if lv_arr != 0
                    if cs_rhs_type == "dyn_tagged"
                        arm64_pop_reg(s, 3)                  // X3 = runtime val_tag
                    elif cs_rhs_type == "float"
                        arm64_emit_movz_x(s, 3, 1, 0)
                    elif cs_rhs_type == "str"
                        arm64_emit_movz_x(s, 3, 2, 0)
                    else
                        arm64_emit_movz_x(s, 3, 0, 0)
                    end
                    arm64_pop_reg(s, 2)                  // X2 = val
                    arm64_pop_reg(s, 1)                  // X1 = key/idx
                    arm64_emit_ldr_reg_sp(s, 0, lv_arr.lv_offset) // X0 = hdr
                    if lv_arr.a64_lv_is_boxed == 1
                        arm64_emit_ldr_x_off(s, 0, 0, 0)
                    end
                    s.a64_needs_dict = 1
                    s.synth_needs_alloc = 1
                    arm64_synth_emit_call_helper(s, "__container_set")
                    if s.a64_try_patches.len() > 0
                        arm64_emit_cmp_x(s, 27, 31)
                        cs_npe_bne = s.synth_code.len()
                        arm64_emit_b_cond(s, 1, 0)
                        push(s.a64_try_patches[s.a64_try_patches.len() - 1], [cs_npe_bne, 1])
                    elif s.a64_in_function == 1
                        arm64_emit_cmp_x(s, 27, 31)
                        cs_npe_eq = s.synth_code.len()
                        arm64_emit_b_cond(s, 0, 0)
                        arm64_emit_defers(s, toks)
                        arm64_emit_epilogue(s)
                        arm64_patch_b_cond(s, cs_npe_eq, 0, s.synth_code.len())
                    elif s.a64_freestanding == 0
                        s.a64_needs_uncaught_throw = 1
                        arm64_emit_cmp_x(s, 27, 31)
                        cs_npe_ut = s.synth_code.len()
                        arm64_emit_b_cond(s, 0, 0)
                        arm64_synth_emit_call_helper(s, "__uncaught_throw")
                        arm64_patch_b_cond(s, cs_npe_ut, 0, s.synth_code.len())
                    end
                else
                    if cs_rhs_type == "dyn_tagged"
                        arm64_pop_reg(s, 3)
                    end
                    arm64_pop_reg(s, 2)
                    arm64_pop_reg(s, 1)
                end
                return 0
            end
        end
    end

    // ── 6. Conditionals: if / elif / else (যদি / নাহলে_যদি / নাহলে / @if...) ──
    is_if = 0
    if k == TOK_KW_IF() or k == TOK_DIR_IF()
        is_if = 1
    if k == TOK_IDENT() and (txt == "if" or txt == "যদি" or txt == "@if")
        is_if = 1

    if is_if == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'if'

        // Evaluate conditional expression into X0
        arm64_synth_compile_expr(s, toks, pos_box)

        // Compare X0 with XZR: cmp x0, xzr
        arm64_emit_cmp_x(s, 0, 31)

        // b.eq next_branch (branch if zero/false)
        patch_next_branch = s.synth_code.len()
        arm64_emit_b_cond(s, 0, 0) // Placeholder

        end_patches = list()
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        if_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            if_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile then-block statements
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if if_braced == 1
                if cur_k == TOK_RBRACE() or cur_txt == "}"
                    list_set(pos_box, 0, cur_p + 1)
                    break
                if cur_k == TOK_EOF()
                    break
            else
                if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE() or cur_k == TOK_KW_END() or cur_k == TOK_DIR_END()
                    break
                if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else" or cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end")
                    break
                if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                    break

            before_stmt_p = get(pos_box, 0)
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == before_stmt_p
                list_set(pos_box, 0, before_stmt_p + 1)

            if if_braced == 0 and cur_t.tok_span.span_start_line == base_line
                break

        // Check if there is an elif or else coming next
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        has_subsequent = 0
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()
                has_subsequent = 1
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else")
                has_subsequent = 1

        if has_subsequent == 1
            jmp_end = s.synth_code.len()
            arm64_emit_b(s, 0)
            push(end_patches, jmp_end)

            cur_off = s.synth_code.len()
            rel_words = (cur_off - patch_next_branch) / 4
            arm64_synth_patch_u32(s, patch_next_branch, 1409286144 | ((rel_words & 524287) << 5) | 0)
        else
            cur_off = s.synth_code.len()
            rel_words = (cur_off - patch_next_branch) / 4
            arm64_synth_patch_u32(s, patch_next_branch, 1409286144 | ((rel_words & 524287) << 5) | 0)

        // Loop over elif branches
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            is_elif = 0
            if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF()
                is_elif = 1
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif")
                is_elif = 1
            if is_elif == 0
                break

            elif_line = cur_t.tok_span.span_start_line
            list_set(pos_box, 0, cur_p + 1) // Consume 'elif'
            arm64_synth_compile_expr(s, toks, pos_box)

            arm64_emit_cmp_x(s, 0, 31)
            patch_next_branch = s.synth_code.len()
            arm64_emit_b_cond(s, 0, 0) // b.eq next_branch

            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            elif_braced = 0
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
                elif_braced = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)

            while get(pos_box, 0) < toks.len()
                arm64_synth_skip_whitespace_tokens(toks, pos_box)
                cur_p2 = get(pos_box, 0)
                if cur_p2 >= toks.len()
                    break
                ct2 = toks[cur_p2]
                ck2 = ct2.tok_kind
                cx2 = ct2.tok_text
                if elif_braced == 1
                    if ck2 == TOK_RBRACE() or cx2 == "}"
                        list_set(pos_box, 0, cur_p2 + 1)
                        break
                    if ck2 == TOK_EOF()
                        break
                else
                    if ck2 == TOK_KW_ELIF() or ck2 == TOK_DIR_ELIF() or ck2 == TOK_KW_ELSE() or ck2 == TOK_DIR_ELSE() or ck2 == TOK_KW_END() or ck2 == TOK_DIR_END()
                        break
                    if ck2 == TOK_IDENT() and (cx2 == "elif" or cx2 == "নাহলে_যদি" or cx2 == "@elif" or cx2 == "else" or cx2 == "নাহলে" or cx2 == "@else" or cx2 == "end" or cx2 == "শেষ" or cx2 == "@end")
                        break
                    if ct2.tok_span.span_start_line > elif_line and ct2.tok_span.span_start_col <= base_col
                        break
                b_p2 = get(pos_box, 0)
                arm64_synth_compile_statement(s, toks, pos_box)
                if get(pos_box, 0) == b_p2
                    list_set(pos_box, 0, b_p2 + 1)
                if elif_braced == 0 and ct2.tok_span.span_start_line == elif_line
                    break

            jmp_end = s.synth_code.len()
            arm64_emit_b(s, 0)
            push(end_patches, jmp_end)

            cur_off = s.synth_code.len()
            rel_words = (cur_off - patch_next_branch) / 4
            arm64_synth_patch_u32(s, patch_next_branch, 1409286144 | ((rel_words & 524287) << 5) | 0)

        // Check for else
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            is_else = 0
            if cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()
                is_else = 1
            if cur_k == TOK_IDENT() and (cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else")
                is_else = 1
            if is_else == 1
                else_line = cur_t.tok_span.span_start_line
                list_set(pos_box, 0, cur_p + 1) // Consume 'else'
                arm64_synth_skip_whitespace_tokens(toks, pos_box)
                else_braced = 0
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
                    else_braced = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    arm64_synth_skip_whitespace_tokens(toks, pos_box)
                    cur_p3 = get(pos_box, 0)
                    if cur_p3 >= toks.len()
                        break
                    ct3 = toks[cur_p3]
                    ck3 = ct3.tok_kind
                    cx3 = ct3.tok_text
                    if else_braced == 1
                        if ck3 == TOK_RBRACE() or cx3 == "}"
                            list_set(pos_box, 0, cur_p3 + 1)
                            break
                        if ck3 == TOK_EOF()
                            break
                    else
                        if ck3 == TOK_KW_END() or ck3 == TOK_DIR_END()
                            break
                        if ck3 == TOK_IDENT() and (cx3 == "end" or cx3 == "শেষ" or cx3 == "@end")
                            break
                        if ct3.tok_span.span_start_line > else_line and ct3.tok_span.span_start_col <= base_col
                            break
                    b_p3 = get(pos_box, 0)
                    arm64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p3
                        list_set(pos_box, 0, b_p3 + 1)
                    if else_braced == 0 and ct3.tok_span.span_start_line == else_line
                        break

        // Consume optional end / @end / শেষ
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Backpatch all exit jumps to current offset
        cur_off = s.synth_code.len()
        ei = 0
        while ei < end_patches.len()
            p_end = end_patches[ei]
            rel_words = (cur_off - p_end) / 4
            b_word = 335544320 | (rel_words & 67108863)
            arm64_synth_patch_u32(s, p_end, b_word)
            ei = ei + 1
        return 0

    // ── 7. Loops: while / যতক্ষণ / @while ─────────────────────────────────────
    is_while = 0
    if k == TOK_KW_WHILE() or k == TOK_DIR_WHILE()
        is_while = 1
    if k == TOK_IDENT() and (txt == "while" or txt == "যতক্ষণ" or txt == "@while")
        is_while = 1

    if is_while == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'while'

        loop_header = s.synth_code.len()
        push(s.synth_loop_starts, loop_header)
        loop_brks = list()
        push(s.synth_loop_breaks, loop_brks)
        push(s.a64_for_conts, list())

        // Evaluate condition into X0
        arm64_synth_compile_expr(s, toks, pos_box)

        // cmp x0, xzr; b.eq loop_exit
        arm64_emit_cmp_x(s, 0, 31)
        patch_loop_exit = s.synth_code.len()
        arm64_emit_b_cond(s, 0, 0) // Placeholder

        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        while_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            while_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile while body statements
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if while_braced == 1
                if cur_k == TOK_RBRACE() or cur_txt == "}"
                    list_set(pos_box, 0, cur_p + 1)
                    break
                if cur_k == TOK_EOF()
                    break
            else
                if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                    break
                if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                    break

            b_p = get(pos_box, 0)
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if while_braced == 0 and cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Backward jump to loop_header: b loop_header
        cur_off = s.synth_code.len()
        rel_words = (loop_header - cur_off) / 4
        arm64_emit_b(s, rel_words)

        // Backpatch loop_exit
        loop_exit_off = s.synth_code.len()
        exit_words = (loop_exit_off - patch_loop_exit) / 4
        arm64_synth_patch_u32(s, patch_loop_exit, 1409286144 | ((exit_words & 524287) << 5) | 0)

        // Backpatch all break jumps
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            b_words = (loop_exit_off - brk_patch) / 4
            arm64_synth_patch_u32(s, brk_patch, 335544320 | (b_words & 67108863))
            bi = bi + 1

        s.synth_loop_starts = pop(s.synth_loop_starts)
        s.synth_loop_breaks = pop(s.synth_loop_breaks)
        s.a64_for_conts = pop(s.a64_for_conts)
        return 0

    // ── 8. Loops: for / প্রতিটি / @for ───────────────────────────────────────
    is_for = 0
    if k == TOK_KW_FOR() or k == TOK_DIR_FOR()
        is_for = 1
    if k == TOK_IDENT() and (txt == "for" or txt == "প্রতিটি" or txt == "@for")
        is_for = 1

    if is_for == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'for'

        var_tok = toks[get(pos_box, 0)]
        var_name = var_tok.tok_text
        list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume var_name

        // Consume 'in' or 'মধ্যে' if present
        if get(pos_box, 0) < toks.len()
            in_t = toks[get(pos_box, 0)]
            if in_t.tok_kind == TOK_KW_IN() or (in_t.tok_kind == TOK_IDENT() and (in_t.tok_text == "in" or in_t.tok_text == "মধ্যে"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile first iterable expression into X0 (either range start `a` or collection `arr`)
        arm64_synth_compile_expr(s, toks, pos_box)
        var_off = arm64_synth_alloc_var(s, var_name)

        // Check if range `a..b` or collection `for x in arr`
        is_for_range = 0
        if get(pos_box, 0) < toks.len()
            dot_t = toks[get(pos_box, 0)]
            if dot_t.tok_kind == TOK_DOTDOT() or dot_t.tok_text == ".."
                is_for_range = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end

        col_off = 0
        idx_off = 0
        end_off = 0
        if is_for_range == 1
            arm64_emit_str_reg_sp(s, 0, var_off)
            // Compile end expression into X0
            arm64_synth_compile_expr(s, toks, pos_box)
            end_var_name = "__end_" + var_name + "_" + str(s.synth_code.len())
            end_off = arm64_synth_alloc_var(s, end_var_name)
            arm64_emit_str_reg_sp(s, 0, end_off)
        else
            // Collection iteration: X0 holds list header [len, cap, data_ptr]
            col_off = arm64_synth_alloc_var(s, "__fcol_" + var_name + "_" + str(s.synth_code.len()))
            arm64_emit_str_reg_sp(s, 0, col_off)
            end_off = arm64_synth_alloc_var(s, "__flen_" + var_name + "_" + str(s.synth_code.len()))
            // Load len = [col + 0] (0 if col == 0)
            arm64_emit_ldr_x_off(s, 0, 0, 0)
            arm64_emit_str_reg_sp(s, 0, end_off)
            idx_off = arm64_synth_alloc_var(s, "__fidx_" + var_name + "_" + str(s.synth_code.len()))
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_str_reg_sp(s, 0, idx_off)
        end

        loop_header = s.synth_code.len()
        push(s.synth_loop_starts, 0 - 1)
        loop_brks = list()
        push(s.synth_loop_breaks, loop_brks)
        for_conts = list()
        push(s.a64_for_conts, for_conts)

        patch_loop_exit = 0
        if is_for_range == 1
            // Compare var and end: exit if var > end (cond=12 GT — inclusive a..b)
            arm64_emit_ldr_reg_sp(s, 0, var_off)
            arm64_emit_ldr_reg_sp(s, 1, end_off)
            arm64_emit_cmp_x(s, 0, 1)
            patch_loop_exit = s.synth_code.len()
            arm64_emit_b_cond(s, 12, 0)
        else
            // Compare idx and len: exit if idx >= len (cond=10 GE)
            arm64_emit_ldr_reg_sp(s, 0, idx_off)
            arm64_emit_ldr_reg_sp(s, 1, end_off)
            arm64_emit_cmp_x(s, 0, 1)
            patch_loop_exit = s.synth_code.len()
            arm64_emit_b_cond(s, 10, 0)
            // Load element var = data_ptr[idx]
            arm64_emit_ldr_reg_sp(s, 9, col_off)
            arm64_emit_ldr_x_off(s, 10, 9, 16)
            arm64_emit_ldr_reg_sp(s, 1, idx_off)
            arm64_emit_movz_x(s, 2, 8, 0)
            arm64_emit_mul_x(s, 1, 1, 2)
            arm64_emit_add_x(s, 10, 10, 1)
            arm64_emit_ldr_x_off(s, 0, 10, 0)
            arm64_emit_str_reg_sp(s, 0, var_off)
        end

        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        for_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            for_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile for body statements
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if for_braced == 1
                if cur_k == TOK_RBRACE() or cur_txt == "}"
                    list_set(pos_box, 0, cur_p + 1)
                    break
                if cur_k == TOK_EOF()
                    break
            else
                if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                    break
                if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                    break

            b_p = get(pos_box, 0)
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if for_braced == 0 and cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Patch continue targets directly to loop step increment
        step_off = s.synth_code.len()
        fci = 0
        while fci < for_conts.len()
            fc_patch = for_conts[fci]
            fc_words = (step_off - fc_patch) / 4
            arm64_synth_patch_u32(s, fc_patch, 335544320 | (fc_words & 67108863))
            fci = fci + 1
        end

        // Increment range var or collection index
        step_var_off = var_off
        if is_for_range == 0
            step_var_off = idx_off
        end
        arm64_emit_ldr_reg_sp(s, 0, step_var_off)
        arm64_emit_movz_x(s, 1, 1, 0)
        arm64_emit_add_x(s, 0, 0, 1)
        arm64_emit_str_reg_sp(s, 0, step_var_off)

        // b loop_header
        cur_off = s.synth_code.len()
        rel_words = (loop_header - cur_off) / 4
        arm64_emit_b(s, rel_words)

        // Backpatch loop_exit (b.gt=12 for range, b.ge=10 for collection)
        loop_exit_off = s.synth_code.len()
        exit_words = (loop_exit_off - patch_loop_exit) / 4
        exit_cc = 12
        if is_for_range == 0
            exit_cc = 10
        end
        arm64_synth_patch_u32(s, patch_loop_exit, 1409286144 | ((exit_words & 524287) << 5) | exit_cc)

        // Backpatch breaks
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            b_words = (loop_exit_off - brk_patch) / 4
            arm64_synth_patch_u32(s, brk_patch, 335544320 | (b_words & 67108863))
            bi = bi + 1

        s.synth_loop_starts = pop(s.synth_loop_starts)
        s.synth_loop_breaks = pop(s.synth_loop_breaks)
        s.a64_for_conts = pop(s.a64_for_conts)
        return 0

    // ── 8b. Pattern Match: match / মিল / মেলাও / @match ────────────────────────
    is_match = 0
    if k == TOK_KW_MATCH() or k == TOK_DIR_MATCH() or (k == TOK_IDENT() and (txt == "match" or txt == "মিল" or txt == "মেলাও" or txt == "@match"))
        if pos + 1 < toks.len()
            mn_a = toks[pos + 1]
            if mn_a.tok_kind != TOK_ASSIGN() and mn_a.tok_text != "=" and mn_a.tok_kind != TOK_PLUSEQ() and mn_a.tok_text != "+=" and mn_a.tok_kind != TOK_MINUSEQ() and mn_a.tok_text != "-=" and mn_a.tok_kind != TOK_STAREQ() and mn_a.tok_kind != TOK_SLASHEQ() and mn_a.tok_kind != TOK_PERCENTEQ() and mn_a.tok_kind != TOK_DOT() and mn_a.tok_text != "." and mn_a.tok_kind != TOK_LBRACKET() and mn_a.tok_text != "[" and mn_a.tok_kind != TOK_LPAREN() and mn_a.tok_text != "(" and mn_a.tok_kind != TOK_NEWLINE() and mn_a.tok_kind != TOK_SEMI()
                is_match = 1

    if is_match == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)

        arm64_synth_compile_expr(s, toks, pos_box)
        m_off = arm64_synth_alloc_var(s, "__arm64_match_" + str(pos))
        arm64_emit_str_reg_sp(s, 0, m_off)
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        m_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            m_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end

        end_patches = list()
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cp_m = get(pos_box, 0)
            if cp_m >= toks.len()
                break
            ct_m = toks[cp_m]
            ck_m = ct_m.tok_kind
            cx_m = ct_m.tok_text
            if m_braced == 1 and (ck_m == TOK_RBRACE() or cx_m == "}")
                list_set(pos_box, 0, cp_m + 1)
                break
            end
            if ck_m == TOK_COMMA() or cx_m == ","
                list_set(pos_box, 0, cp_m + 1)
                continue
            end
            if ck_m == TOK_EOF() or ck_m == TOK_KW_END() or ck_m == TOK_DIR_END() or (ck_m == TOK_IDENT() and (cx_m == "end" or cx_m == "শেষ" or cx_m == "@end"))
                break
            if m_braced == 0 and ct_m.tok_span.span_start_line > base_line and ct_m.tok_span.span_start_col <= base_col
                break

            arm_col = ct_m.tok_span.span_start_col
            arm_line = ct_m.tok_span.span_start_line

            if ck_m == TOK_KW_CASE() or (ck_m == TOK_IDENT() and (cx_m == "case" or cx_m == "ঘটনা" or cx_m == "ক্ষেত্র" or cx_m == "@case"))
                list_set(pos_box, 0, cp_m + 1)

            pat_p = get(pos_box, 0)
            if pat_p >= toks.len()
                break
            pt_m = toks[pat_p]
            pk_m = pt_m.tok_kind
            px_m = pt_m.tok_text

            is_default_arm = 0
            if pk_m == TOK_KW_ELSE() or pk_m == TOK_DIR_ELSE() or (pk_m == TOK_IDENT() and (px_m == "_" or px_m == "default" or px_m == "else" or px_m == "নাহলে" or px_m == "অন্যথায়" or px_m == "@else"))
                is_default_arm = 1
                list_set(pos_box, 0, pat_p + 1)

            if get(pos_box, 0) < toks.len() and is_default_arm == 1
                sep_k = toks[get(pos_box, 0)].tok_kind
                sep_txt = toks[get(pos_box, 0)].tok_text
                if sep_k == TOK_FAT_ARROW() or sep_k == TOK_COLON() or sep_k == TOK_ARROW() or sep_txt == "=>" or sep_txt == ":" or sep_txt == "->"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)

            if is_default_arm == 1
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == arm_line and toks[get(pos_box, 0)].tok_kind != TOK_NEWLINE() and toks[get(pos_box, 0)].tok_kind != TOK_SEMI() and toks[get(pos_box, 0)].tok_kind != TOK_COMMENT_LINE()
                    bp_e1 = get(pos_box, 0)
                    arm64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == bp_e1
                        list_set(pos_box, 0, bp_e1 + 1)
                else
                    while get(pos_box, 0) < toks.len()
                        arm64_synth_skip_whitespace_tokens(toks, pos_box)
                        cp_e = get(pos_box, 0)
                        if cp_e >= toks.len()
                            break
                        ct_e = toks[cp_e]
                        ck_e = ct_e.tok_kind
                        cx_e = ct_e.tok_text
                        if ck_e == TOK_KW_END() or ck_e == TOK_DIR_END() or (ck_e == TOK_IDENT() and (cx_e == "end" or cx_e == "শেষ" or cx_e == "@end"))
                            break
                        if ct_e.tok_span.span_start_line > arm_line and ct_e.tok_span.span_start_col <= base_col
                            break
                        bp_e = get(pos_box, 0)
                        arm64_synth_compile_statement(s, toks, pos_box)
                        if get(pos_box, 0) == bp_e
                            list_set(pos_box, 0, bp_e + 1)
                break
            else
                // ADT Enum Variant Pattern (e.g. Some(v) => ..., None => ..., Ok(x) => ...) vs Scalar Value Pattern
                adt_pidx = arm64_enum_find_idx(s, px_m)
                patch_miss_null = 0 - 1
                if adt_pidx >= 0
                    adt_tag = s.a64_enum_tags[adt_pidx]
                    list_set(pos_box, 0, pat_p + 1)
                    adt_binds = list()
                    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN() and toks[get(pos_box, 0)].tok_kind != TOK_EOF()
                            if toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                                push(adt_binds, toks[get(pos_box, 0)].tok_text)
                            end
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    end
                    if get(pos_box, 0) < toks.len()
                        sep_k2 = toks[get(pos_box, 0)].tok_kind
                        sep_t2 = toks[get(pos_box, 0)].tok_text
                        if sep_k2 == TOK_FAT_ARROW() or sep_k2 == TOK_COLON() or sep_k2 == TOK_ARROW() or sep_t2 == "=>" or sep_t2 == ":" or sep_t2 == "->"
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    end
                    arm64_emit_ldr_reg_sp(s, 1, m_off)
                    arm64_emit_movz_x(s, 10, 4096, 0)
                    arm64_emit_cmp_x(s, 1, 10)
                    patch_miss_null = s.synth_code.len()
                    arm64_emit_b_cond(s, 3, 0) // b.lo miss (< 4096)
                    arm64_emit_ldr_x_off(s, 9, 1, 0)
                    arm64_emit_mov_imm64(s, 10, adt_tag)
                    arm64_emit_cmp_x(s, 9, 10)
                    patch_miss = s.synth_code.len()
                    arm64_emit_b_cond(s, 1, 0) // b.ne miss
                    bi_a = 0
                    while bi_a < adt_binds.len()
                        bnm = adt_binds[bi_a]
                        if bnm != "_"
                            boff = arm64_synth_alloc_var(s, bnm)
                            arm64_emit_ldr_x_off(s, 9, 1, (bi_a + 1) * 8)
                            arm64_emit_str_reg_sp(s, 9, boff)
                        end
                        bi_a = bi_a + 1
                    end
                else
                    arm64_synth_compile_expr(s, toks, pos_box)
                    if get(pos_box, 0) < toks.len()
                        sep_k2 = toks[get(pos_box, 0)].tok_kind
                        sep_t2 = toks[get(pos_box, 0)].tok_text
                        if sep_k2 == TOK_FAT_ARROW() or sep_k2 == TOK_COLON() or sep_k2 == TOK_ARROW() or sep_t2 == "=>" or sep_t2 == ":" or sep_t2 == "->"
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    end
                    arm64_emit_ldr_reg_sp(s, 1, m_off)
                    arm64_emit_cmp_x(s, 1, 0)
                    patch_miss = s.synth_code.len()
                    arm64_emit_b_cond(s, 1, 0) // b.ne miss
                end

                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == arm_line and toks[get(pos_box, 0)].tok_kind != TOK_NEWLINE() and toks[get(pos_box, 0)].tok_kind != TOK_SEMI() and toks[get(pos_box, 0)].tok_kind != TOK_COMMENT_LINE()
                    bp_c1 = get(pos_box, 0)
                    arm64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == bp_c1
                        list_set(pos_box, 0, bp_c1 + 1)
                else
                    while get(pos_box, 0) < toks.len()
                        arm64_synth_skip_whitespace_tokens(toks, pos_box)
                        cp_b = get(pos_box, 0)
                        if cp_b >= toks.len()
                            break
                        ct_b = toks[cp_b]
                        ck_b = ct_b.tok_kind
                        cx_b = ct_b.tok_text
                        if ck_b == TOK_KW_CASE() or ck_b == TOK_KW_ELSE() or ck_b == TOK_DIR_ELSE() or ck_b == TOK_KW_END() or ck_b == TOK_DIR_END() or ck_b == TOK_RBRACE() or cx_b == "}"
                            break
                        if ck_b == TOK_IDENT() and (cx_b == "case" or cx_b == "ঘটনা" or cx_b == "ক্ষেত্র" or cx_b == "@case" or cx_b == "else" or cx_b == "নাহলে" or cx_b == "অন্যথায়" or cx_b == "_" or cx_b == "default" or cx_b == "@else" or cx_b == "end" or cx_b == "শেষ" or cx_b == "@end")
                            break
                        if ct_b.tok_span.span_start_line > arm_line and ct_b.tok_span.span_start_col <= arm_col
                            break
                        bp_c = get(pos_box, 0)
                        arm64_synth_compile_statement(s, toks, pos_box)
                        if get(pos_box, 0) == bp_c
                            list_set(pos_box, 0, bp_c + 1)

                jmp_end = s.synth_code.len()
                arm64_emit_b(s, 0)
                push(end_patches, jmp_end)

                miss_off = s.synth_code.len()
                if patch_miss_null >= 0
                    arm64_patch_b_cond(s, patch_miss_null, 3, miss_off)
                end
                miss_words = (miss_off - patch_miss) / 4
                arm64_synth_patch_u32(s, patch_miss, 1409286144 | ((miss_words & 524287) << 5) | 1)

        end_off = s.synth_code.len()
        ei = 0
        while ei < end_patches.len()
            ep = end_patches[ei]
            ew = (end_off - ep) / 4
            arm64_synth_patch_u32(s, ep, 335544320 | (ew & 67108863))
            ei = ei + 1

        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            et_m = toks[get(pos_box, 0)]
            if et_m.tok_kind == TOK_KW_END() or et_m.tok_kind == TOK_DIR_END() or (et_m.tok_kind == TOK_IDENT() and (et_m.tok_text == "end" or et_m.tok_text == "শেষ" or et_m.tok_text == "@end"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
        return 0

    // ── 8c. Exception Handling: throw / নিক্ষেপ & try / চেষ্টা ... catch / ধরো ─
    if k == TOK_IDENT() and (txt == "throw" or txt == "নিক্ষেপ" or txt == "@throw")
        list_set(pos_box, 0, pos + 1)
        arm64_synth_compile_expr(s, toks, pos_box)
        arm64_emit_mov_reg(s, 28, 0)
        if s.a64_last_expr_type == "float"
            arm64_emit_movz_x(s, 27, 2, 0)
        elif s.a64_last_expr_type == "str"
            arm64_emit_movz_x(s, 27, 3, 0)
        elif s.a64_last_expr_type == "dyn_tagged"
            arm64_emit_add_imm(s, 27, 1, 1)
        else
            arm64_emit_movz_x(s, 27, 1, 0)
        end
        if s.a64_try_patches.len() > 0
            p_off = s.synth_code.len()
            arm64_emit_b(s, 0)
            active_tp = s.a64_try_patches[s.a64_try_patches.len() - 1]
            push(active_tp, [p_off, 0])
        elif s.a64_in_function == 1
            arm64_emit_defers(s, toks)
            arm64_emit_epilogue(s)
        elif s.a64_freestanding == 0
            // WHY: Top-level uncaught throw runs defers, prints "Uncaught exception: <val>" to stderr, and exits 1.
            arm64_emit_defers(s, toks)
            s.a64_needs_uncaught_throw = 1
            arm64_synth_emit_call_helper(s, "__uncaught_throw")
        end
        return 0

    is_try = 0
    if k == TOK_KW_TRY() or k == TOK_DIR_TRY()
        is_try = 1
    if k == TOK_IDENT() and (txt == "try" or txt == "চেষ্টা" or txt == "@try")
        is_try = 1

    if is_try == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        try_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            try_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end

        // Reset X27 exception flag before entering try block
        arm64_emit_movz_x(s, 27, 0, 0)
        tp_list = list()
        push(s.a64_try_patches, tp_list)

        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cp_t = get(pos_box, 0)
            if cp_t >= toks.len()
                break
            ct_t = toks[cp_t]
            ck_t = ct_t.tok_kind
            cx_t = ct_t.tok_text
            if ck_t == TOK_EOF()
                break
            if try_braced == 1
                if ck_t == TOK_RBRACE() or cx_t == "}"
                    list_set(pos_box, 0, cp_t + 1)
                    break
                end
            else
                if ck_t == TOK_KW_CATCH() or ck_t == TOK_DIR_CATCH() or ck_t == TOK_KW_END() or ck_t == TOK_DIR_END()
                    break
                if ck_t == TOK_IDENT() and (cx_t == "catch" or cx_t == "ধরো" or cx_t == "@catch" or cx_t == "end" or cx_t == "শেষ" or cx_t == "@end")
                    break
                if ct_t.tok_span.span_start_line > base_line and ct_t.tok_span.span_start_col <= base_col
                    break
            end
            bp_t = get(pos_box, 0)
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == bp_t
                list_set(pos_box, 0, bp_t + 1)

        cur_tp = s.a64_try_patches[s.a64_try_patches.len() - 1]
        s.a64_try_patches = pop(s.a64_try_patches)

        jmp_after_catch = s.synth_code.len()
        arm64_emit_b(s, 0)

        catch_entry_off = s.synth_code.len()
        tpi = 0
        while tpi < cur_tp.len()
            p_item = cur_tp[tpi]
            p_off = p_item[0]
            p_kind = p_item[1]
            rel_w = (catch_entry_off - p_off) / 4
            if p_kind == 0
                arm64_synth_patch_u32(s, p_off, 335544320 | (rel_w & 67108863))
            else
                arm64_synth_patch_u32(s, p_off, 1409286144 | ((rel_w & 524287) << 5) | 1)
            tpi = tpi + 1

        // Restore SP = X29 - 2048, extract exception tag = (X27 - 1) into X9, then clear X27
        arm64_synth_emit32(s, 3508536255)
        arm64_emit_sub_imm(s, 9, 27, 1)
        arm64_emit_movz_x(s, 27, 0, 0)

        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        cp_c = get(pos_box, 0)
        if cp_c < toks.len()
            ct_c = toks[cp_c]
            ck_c = ct_c.tok_kind
            cx_c = ct_c.tok_text
            is_catch = 0
            if ck_c == TOK_KW_CATCH() or ck_c == TOK_DIR_CATCH()
                is_catch = 1
            if ck_c == TOK_IDENT() and (cx_c == "catch" or cx_c == "ধরো" or cx_c == "@catch")
                is_catch = 1

            if is_catch == 1
                catch_line = ct_c.tok_span.span_start_line
                list_set(pos_box, 0, cp_c + 1)
                catch_var = ""
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() and toks[get(pos_box, 0)].tok_span.span_start_line == catch_line
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                        catch_var = toks[get(pos_box, 0)].tok_text
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT() and toks[get(pos_box, 0)].tok_span.span_start_line == catch_line
                    catch_var = toks[get(pos_box, 0)].tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)

                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                arm64_synth_skip_whitespace_tokens(toks, pos_box)
                catch_braced = 0
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
                    catch_braced = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end

                if catch_var != ""
                    cv_off = arm64_synth_alloc_var(s, catch_var)
                    arm64_emit_str_reg_sp(s, 28, cv_off)
                    cv_lv = arm64_find_local_var(s, catch_var)
                    if cv_lv != 0
                        cv_lv.a64_lv_prim_type = "dyn_tagged"
                        cv_toff = arm64_synth_alloc_tag_slot(s, cv_lv)
                        arm64_emit_str_reg_sp(s, 9, cv_toff)
                    end
                end

                while get(pos_box, 0) < toks.len()
                    arm64_synth_skip_whitespace_tokens(toks, pos_box)
                    cp_cb = get(pos_box, 0)
                    if cp_cb >= toks.len()
                        break
                    ct_cb = toks[cp_cb]
                    ck_cb = ct_cb.tok_kind
                    cx_cb = ct_cb.tok_text
                    if ck_cb == TOK_EOF()
                        break
                    if catch_braced == 1
                        if ck_cb == TOK_RBRACE() or cx_cb == "}"
                            list_set(pos_box, 0, cp_cb + 1)
                            break
                        end
                    else
                        if ck_cb == TOK_KW_END() or ck_cb == TOK_DIR_END()
                            break
                        if ck_cb == TOK_IDENT() and (cx_cb == "end" or cx_cb == "শেষ" or cx_cb == "@end")
                            break
                        if ct_cb.tok_span.span_start_line > catch_line and ct_cb.tok_span.span_start_col <= base_col
                            break
                    end
                    bp_cb = get(pos_box, 0)
                    arm64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == bp_cb
                        list_set(pos_box, 0, bp_cb + 1)

        after_catch_off = s.synth_code.len()
        ac_words = (after_catch_off - jmp_after_catch) / 4
        arm64_synth_patch_u32(s, jmp_after_catch, 335544320 | (ac_words & 67108863))

        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            et_t = toks[get(pos_box, 0)]
            if et_t.tok_kind == TOK_KW_END() or et_t.tok_kind == TOK_DIR_END() or (et_t.tok_kind == TOK_IDENT() and (et_t.tok_text == "end" or et_t.tok_text == "শেষ" or et_t.tok_text == "@end"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
        return 0

    // ── 9. Variable Declaration: let / চলক / ধরি / var ─────────────────────────
    is_let = 0
    if k == TOK_KW_LET()
        is_let = 1
    if k == TOK_IDENT() and (txt == "let" or txt == "চলক" or txt == "ধরি" or txt == "var")
        is_let = 1

    if is_let == 1
        list_set(pos_box, 0, pos + 1) // Consume let
        var_pos = get(pos_box, 0)
        if arm64_try_compile_multi_assign(s, toks, pos_box, var_pos) == 1
            return 0
        end
        if var_pos < toks.len() and toks[var_pos].tok_kind == TOK_IDENT()
            var_name = toks[var_pos].tok_text
            list_set(pos_box, 0, var_pos + 1)
            let_decl_type = ""
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ":"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "dyn"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                        let_decl_type = "dyn " + toks[get(pos_box, 0)].tok_text
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                    let_decl_type = toks[get(pos_box, 0)].tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "<"
                        lg_d = 1
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        while get(pos_box, 0) < toks.len() and lg_d > 0
                            if toks[get(pos_box, 0)].tok_text == "<" lg_d = lg_d + 1
                            elif toks[get(pos_box, 0)].tok_text == ">" lg_d = lg_d - 1 end
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    end
                end
            end
            eq_pos = get(pos_box, 0)
            if eq_pos < toks.len() and toks[eq_pos].tok_kind == TOK_ASSIGN()
                list_set(pos_box, 0, eq_pos + 1)
                s.a64_last_struct = ""
                arm64_synth_compile_expr(s, toks, pos_box)
                if arm64_is_float_type(let_decl_type) == 1
                    if s.a64_last_expr_type != "float"
                        arm64_emit_load_fp_reg(s, 0, 0, s.a64_last_expr_type, s.a64_last_is_uint, 1)
                        arm64_emit_fmov_x_d(s, 0, 0)
                    end
                    s.a64_last_expr_type = "float"
                    s.a64_last_is_uint = 0
                end
                prev_lv = arm64_find_local_var(s, var_name)
                eff_let_itype = let_decl_type
                if eff_let_itype == "" and prev_lv != 0
                    eff_let_itype = prev_lv.a64_lv_int_type
                end
                if arm64_is_narrow_int_type(eff_let_itype) == 1
                    arm64_emit_truncate_int_width(s, 0, eff_let_itype)
                end
                if prev_lv == 0
                    off = arm64_synth_alloc_var(s, var_name)
                    if arm64_is_boxed_name(s, var_name) == 1
                        arm64_push_reg(s, 0)
                        arm64_emit_movz_x(s, 0, 8, 0)
                        arm64_synth_emit_call_alloc(s)
                        arm64_pop_reg(s, 9)
                        arm64_emit_str_x_off(s, 9, 0, 0)
                        arm64_emit_str_reg_sp(s, 0, off)
                    else
                        arm64_emit_str_reg_sp(s, 0, off)
                    end
                    prev_lv = arm64_find_local_var(s, var_name)
                elif prev_lv.a64_lv_is_boxed == 1
                    arm64_emit_ldr_reg_sp(s, 9, prev_lv.lv_offset)
                    arm64_emit_str_x_off(s, 0, 9, 0)
                else
                    arm64_emit_str_reg_sp(s, 0, prev_lv.lv_offset)
                end
                if prev_lv != 0
                    if arm64_is_uint_type(let_decl_type) == 1 or (let_decl_type == "" and s.a64_last_is_uint == 1)
                        prev_lv.a64_lv_is_uint = 1
                    elif let_decl_type != ""
                        prev_lv.a64_lv_is_uint = 0
                    end
                    if let_decl_type != ""
                        if arm64_is_narrow_int_type(let_decl_type) == 1
                            prev_lv.a64_lv_int_type = let_decl_type
                        else
                            prev_lv.a64_lv_int_type = ""
                        end
                    end
                    prev_lv.a64_lv_prim_type = s.a64_last_expr_type
                    if s.a64_last_expr_type == "dyn_tagged"
                        t_off = arm64_synth_alloc_tag_slot(s, prev_lv)
                        arm64_emit_str_reg_sp(s, 1, t_off)
                    end
                end
                arm64_synth_set_var_struct(s, var_name, s.a64_last_struct)
        return 0

    // ── 10. Assignment & Compound Assignment: <var> [: Type] = <expr>, <var> += <expr> ─
    if k == TOK_IDENT()
        if arm64_try_compile_multi_assign(s, toks, pos_box, pos) == 1
            return 0
        end
        next_pos = pos + 1
        decl_type_a64 = ""
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_COLON() or (toks[next_pos].tok_kind != TOK_STR() and toks[next_pos].tok_text == ":"))
            tp_a64 = next_pos + 1
            if tp_a64 < toks.len() and toks[tp_a64].tok_text == "dyn" and tp_a64 + 2 < toks.len() and toks[tp_a64 + 1].tok_kind == TOK_IDENT() and toks[tp_a64 + 2].tok_kind == TOK_ASSIGN()
                decl_type_a64 = "dyn " + toks[tp_a64 + 1].tok_text
                next_pos = tp_a64 + 2
            elif tp_a64 < toks.len() and toks[tp_a64].tok_kind == TOK_IDENT()
                tp_end = tp_a64 + 1
                if tp_end < toks.len() and toks[tp_end].tok_text == "<"
                    ag_d = 1
                    tp_end = tp_end + 1
                    while tp_end < toks.len() and ag_d > 0
                        if toks[tp_end].tok_text == "<" ag_d = ag_d + 1
                        elif toks[tp_end].tok_text == ">" ag_d = ag_d - 1 end
                        tp_end = tp_end + 1
                    end
                end
                if tp_end < toks.len() and toks[tp_end].tok_kind == TOK_ASSIGN()
                    decl_type_a64 = toks[tp_a64].tok_text
                    next_pos = tp_end
                end
            end
        end
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_ASSIGN()
            var_name = txt
            list_set(pos_box, 0, next_pos + 1) // Consume ident [: type] and '='
            s.a64_last_struct = ""
            arm64_synth_compile_expr(s, toks, pos_box)
            if arm64_is_float_type(decl_type_a64) == 1
                if s.a64_last_expr_type != "float"
                    arm64_emit_load_fp_reg(s, 0, 0, s.a64_last_expr_type, s.a64_last_is_uint, 1)
                    arm64_emit_fmov_x_d(s, 0, 0)
                end
                s.a64_last_expr_type = "float"
                s.a64_last_is_uint = 0
            end
            prev_lv = arm64_find_local_var(s, var_name)
            eff_as_itype = decl_type_a64
            if eff_as_itype == "" and prev_lv != 0
                eff_as_itype = prev_lv.a64_lv_int_type
            end
            if arm64_is_narrow_int_type(eff_as_itype) == 1
                arm64_emit_truncate_int_width(s, 0, eff_as_itype)
            end
            if prev_lv == 0
                off = arm64_synth_alloc_var(s, var_name)
                if arm64_is_boxed_name(s, var_name) == 1
                    arm64_push_reg(s, 0)
                    arm64_emit_movz_x(s, 0, 8, 0)
                    arm64_synth_emit_call_alloc(s)
                    arm64_pop_reg(s, 9)
                    arm64_emit_str_x_off(s, 9, 0, 0)
                    arm64_emit_str_reg_sp(s, 0, off)
                else
                    arm64_emit_str_reg_sp(s, 0, off)
                end
                prev_lv = arm64_find_local_var(s, var_name)
            elif prev_lv.a64_lv_is_boxed == 1
                arm64_emit_ldr_reg_sp(s, 9, prev_lv.lv_offset)
                arm64_emit_str_x_off(s, 0, 9, 0)
            else
                arm64_emit_str_reg_sp(s, 0, prev_lv.lv_offset)
            end
            if prev_lv != 0
                if arm64_is_uint_type(decl_type_a64) == 1 or (decl_type_a64 == "" and s.a64_last_is_uint == 1)
                    prev_lv.a64_lv_is_uint = 1
                elif decl_type_a64 != ""
                    prev_lv.a64_lv_is_uint = 0
                end
                if decl_type_a64 != ""
                    if arm64_is_narrow_int_type(decl_type_a64) == 1
                        prev_lv.a64_lv_int_type = decl_type_a64
                    else
                        prev_lv.a64_lv_int_type = ""
                    end
                end
                prev_lv.a64_lv_prim_type = s.a64_last_expr_type
                if s.a64_last_expr_type == "dyn_tagged"
                    t_off = arm64_synth_alloc_tag_slot(s, prev_lv)
                    arm64_emit_str_reg_sp(s, 1, t_off)
                end
            end
            arm64_synth_set_var_struct(s, var_name, s.a64_last_struct)
            return 0
        end
        if next_pos < toks.len()
            ca_op = arm64_is_compound_assign_tok(toks[next_pos])
            ca_adv = 1
            if ca_op == 0 and next_pos + 1 < toks.len() and toks[next_pos + 1].tok_kind == TOK_ASSIGN()
                if toks[next_pos].tok_kind == TOK_SHR() ca_op = TOK_SHR() ca_adv = 2
                elif toks[next_pos].tok_kind == TOK_SHL() ca_op = TOK_SHL() ca_adv = 2
                elif toks[next_pos].tok_kind == TOK_AMP() ca_op = TOK_AMP() ca_adv = 2
                elif toks[next_pos].tok_kind == TOK_BAR() ca_op = TOK_BAR() ca_adv = 2
                elif toks[next_pos].tok_kind == TOK_CARET() ca_op = TOK_CARET() ca_adv = 2
                end
            end
            if ca_op != 0
                var_name = txt
                list_set(pos_box, 0, next_pos + ca_adv)
                arm64_synth_compile_expr(s, toks, pos_box) // X0 = rhs
                ca_rhs_u = s.a64_last_is_uint
                ca_rhs_t = s.a64_last_expr_type
                if ca_rhs_t == "dyn_tagged"
                    arm64_emit_mov_reg(s, 11, 1)
                end
                arm64_emit_mov_reg(s, 10, 0) // X10 = rhs
                arm64_emit_mov_reg(s, 1, 0)  // X1 = rhs
                ca_lv = arm64_find_local_var(s, var_name)
                ca_u = ca_rhs_u
                ca_lhs_t = "int"
                ca_lhs_u = 0
                if ca_lv != 0
                    if ca_lv.a64_lv_is_uint == 1
                        ca_u = 1
                        ca_lhs_u = 1
                    end
                    if ca_lv.a64_lv_prim_type != ""
                        ca_lhs_t = ca_lv.a64_lv_prim_type
                    end
                    arm64_emit_ldr_reg_sp(s, 0, ca_lv.lv_offset)
                    if ca_lv.a64_lv_is_boxed == 1
                        arm64_emit_ldr_x_off(s, 0, 0, 0)
                    end
                    if ca_lhs_t == "dyn_tagged" and ca_lv.a64_lv_tag_off > 0
                        arm64_emit_ldr_reg_sp(s, 9, ca_lv.a64_lv_tag_off)
                    end
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                if (ca_lhs_t == "float" or ca_rhs_t == "float") and (ca_op == TOK_PLUS() or ca_op == TOK_MINUS() or ca_op == TOK_STAR() or ca_op == TOK_SLASH() or ca_op == TOK_PERCENT())
                    arm64_emit_load_fp_reg(s, 0, 0, ca_lhs_t, ca_lhs_u, 9)
                    arm64_emit_load_fp_reg(s, 1, 10, ca_rhs_t, ca_rhs_u, 11)
                    arm64_emit_fp_arith_op(s, ca_op)
                    if ca_lv != 0
                        ca_lv.a64_lv_prim_type = "float"
                        ca_lv.a64_lv_is_uint = 0
                    end
                elif ca_op == TOK_PLUS()
                    arm64_emit_add_x(s, 0, 0, 1)
                elif ca_op == TOK_MINUS()
                    arm64_emit_sub_x(s, 0, 0, 1)
                elif ca_op == TOK_STAR()
                    arm64_emit_mul_x(s, 0, 0, 1)
                elif ca_op == TOK_SLASH()
                    if ca_u == 1 arm64_emit_udiv_x(s, 0, 0, 1) else arm64_emit_sdiv_x(s, 0, 0, 1) end
                elif ca_op == TOK_PERCENT()
                    if ca_u == 1 arm64_emit_udiv_x(s, 2, 0, 1) else arm64_emit_sdiv_x(s, 2, 0, 1) end
                    arm64_emit_mul_x(s, 2, 2, 1)
                    arm64_emit_sub_x(s, 0, 0, 2)
                    // WHY: Match cross-target `x %= 0 -> 0` instead of AArch64 `x - 0*0 == x`.
                    arm64_emit_cmp_x(s, 1, 31)
                    arm64_synth_emit32(s, 2592080864) // csel x0, xzr, x0, eq
                elif ca_op == TOK_SHR()
                    if ca_lv != 0 and ca_lv.a64_lv_is_uint == 1 arm64_emit_lsrv_x(s, 0, 0, 1) else arm64_emit_asrv_x(s, 0, 0, 1) end
                elif ca_op == TOK_SHL()
                    arm64_emit_lslv_x(s, 0, 0, 1)
                elif ca_op == TOK_AMP()
                    arm64_emit_and_x(s, 0, 0, 1)
                elif ca_op == TOK_BAR()
                    arm64_emit_orr_x(s, 0, 0, 1)
                elif ca_op == TOK_CARET()
                    arm64_emit_eor_x(s, 0, 0, 1)
                end
                if ca_lv != 0
                    if arm64_is_narrow_int_type(ca_lv.a64_lv_int_type) == 1
                        arm64_emit_truncate_int_width(s, 0, ca_lv.a64_lv_int_type)
                    end
                    if ca_lv.a64_lv_is_boxed == 1
                        arm64_emit_ldr_reg_sp(s, 9, ca_lv.lv_offset)
                        arm64_emit_str_x_off(s, 0, 9, 0)
                    else
                        arm64_emit_str_reg_sp(s, 0, ca_lv.lv_offset)
                    end
                end
                return 0
            end
        end

    // ── 11. Function & Component Definition: [async] fn / কাজ / @fn / component / উপাদান ──
    is_fn = 0
    fn_start_col = t.tok_span.span_start_col
    fn_start_line = t.tok_span.span_start_line
    fn_kw_pos = pos
    if k == TOK_KW_ASYNC() or (k == TOK_IDENT() and (txt == "async" or txt == "@async" or txt == "অসমলয়"))
        if pos + 1 < toks.len()
            nt_a = toks[pos + 1]
            nk_a = nt_a.tok_kind
            nx_a = nt_a.tok_text
            if nk_a == TOK_KW_FN() or nk_a == TOK_DIR_FN() or nk_a == TOK_KW_COMPONENT() or (nk_a == TOK_IDENT() and (nx_a == "fn" or nx_a == "কাজ" or nx_a == "@fn" or nx_a == "component" or nx_a == "উপাদান"))
                is_fn = 1
                fn_kw_pos = pos + 1
            else
                // Standalone async modifier not followed by fn
                list_set(pos_box, 0, pos + 1)
                return 0
            end
        else
            list_set(pos_box, 0, pos + 1)
            return 0
        end
    end
    if is_fn == 0
        if k == TOK_KW_FN() or k == TOK_DIR_FN() or k == TOK_KW_COMPONENT()
            is_fn = 1
        if k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn" or txt == "component" or txt == "উপাদান")
            is_fn = 1
    end
    if is_fn == 1 and fn_kw_pos + 1 < toks.len() and (toks[fn_kw_pos + 1].tok_kind == TOK_LPAREN() or toks[fn_kw_pos + 1].tok_text == "(")
        is_fn = 0
    end

    if is_fn == 1
        base_col = fn_start_col
        base_line = fn_start_line
        list_set(pos_box, 0, fn_kw_pos + 1) // Consume [async] fn
        name_pos = get(pos_box, 0)
        fn_name = ""
        eff_impl_type = s.a64_impl_type
        if name_pos < toks.len() and toks[name_pos].tok_kind == TOK_IDENT()
            fn_name = toks[name_pos].tok_text
            list_set(pos_box, 0, name_pos + 1)
            // Support `fn Type.method(...)` as well as `impl [Trait for] Type { fn method(...) }`
            if get(pos_box, 0) + 1 < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_DOT() or toks[get(pos_box, 0)].tok_text == ".") and toks[get(pos_box, 0) + 1].tok_kind == TOK_IDENT()
                eff_impl_type = fn_name
                m_sub = toks[get(pos_box, 0) + 1].tok_text
                fn_name = eff_impl_type + "_" + m_sub
                arm64_synth_add_impl_method(s, eff_impl_type, m_sub)
                list_set(pos_box, 0, get(pos_box, 0) + 2)
            elif eff_impl_type != ""
                arm64_synth_add_impl_method(s, eff_impl_type, fn_name)
                fn_name = eff_impl_type + "_" + fn_name
            end
        end

        // Jump over function so top-level execution doesn't fall through into function body
        fn_jmp_patch = s.synth_code.len()
        arm64_emit_b(s, 0) // Placeholder

        // Record function entry point (immediately after the skip jump)
        fn_entry = Arm64Function()
        fn_entry.fn_name = fn_name
        fn_entry.fn_entry_offset = s.synth_code.len()
        fn_entry.a64_fn_end_offset = 0
        fn_entry.a64_fn_decl_line = base_line
        push(s.synth_functions, fn_entry)

        // Save enclosing scope (e.g. top-level _start locals) and reset function frame locals
        saved_arm_locals = s.synth_locals
        saved_arm_stack_off = s.synth_stack_offset
        saved_arm_sp_delta = s.a64_sp_delta
        saved_arm_try_patches = s.a64_try_patches
        saved_arm_boxed = s.a64_boxed_vars
        saved_arm_ds = s.a64_defer_starts
        saved_arm_de = s.a64_defer_ends
        s.synth_locals = list()
        s.synth_stack_offset = 16
        s.a64_sp_delta = 0
        s.a64_in_function = 1
        s.a64_cur_fn_name = fn_name
        s.a64_try_patches = list()
        s.a64_defer_starts = list()
        s.a64_defer_ends = list()

        // Parse parameter names & unsigned/narrow/float/struct type annotations until ')', newline, '{', '->', or inline body keyword
        params = list()
        param_is_uint = list()
        param_int_types = list()
        param_struct_types = list()
        param_prim_types = list()
        fn_paren_depth = 0
        while get(pos_box, 0) < toks.len()
            p_tok = toks[get(pos_box, 0)]
            if p_tok.tok_kind == TOK_NEWLINE() or p_tok.tok_kind == TOK_SEMI()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                break
            if p_tok.tok_kind == TOK_LBRACE() or (p_tok.tok_kind != TOK_STR() and p_tok.tok_text == "{")
                break
            if p_tok.tok_kind == TOK_LPAREN() or (p_tok.tok_kind != TOK_STR() and p_tok.tok_text == "(")
                fn_paren_depth = fn_paren_depth + 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                continue
            if p_tok.tok_kind == TOK_RPAREN() or (p_tok.tok_kind != TOK_STR() and p_tok.tok_text == ")")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                fn_paren_depth = fn_paren_depth - 1
                if fn_paren_depth <= 0
                    // WHY: Single-line functions (`fn BASE() return 0x09000000 end`) place their body
                    // immediately after ')' (or optional '-> RetType'), so stop scanning params here!
                    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_ARROW() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "->"))
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "dyn"
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "<"
                                rg_d = 1
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                                while get(pos_box, 0) < toks.len() and rg_d > 0
                                    if toks[get(pos_box, 0)].tok_text == "<" rg_d = rg_d + 1
                                    elif toks[get(pos_box, 0)].tok_text == ">" rg_d = rg_d - 1 end
                                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                                end
                            end
                        end
                    end
                    break
                end
                continue
            if p_tok.tok_kind == TOK_ARROW() or (p_tok.tok_kind != TOK_STR() and p_tok.tok_text == "->")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "dyn"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                break
            if fn_paren_depth == 0
                pk_b = p_tok.tok_kind
                pt_b = p_tok.tok_text
                if pk_b == TOK_KW_RETURN() or pk_b == TOK_KW_IF() or pk_b == TOK_KW_WHILE() or pk_b == TOK_KW_FOR() or pk_b == TOK_KW_PRINT() or pk_b == TOK_KW_END() or pk_b == TOK_DIR_END() or (pk_b == TOK_IDENT() and (pt_b == "return" or pt_b == "ফেরত" or pt_b == "end" or pt_b == "শেষ" or pt_b == "@end"))
                    break
                end
            end
            if p_tok.tok_kind == TOK_KW_MUT() or (p_tok.tok_kind == TOK_IDENT() and p_tok.tok_text == "mut")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                continue
            end
            if p_tok.tok_kind == TOK_DOTDOT() and get(pos_box, 0) + 1 < toks.len() and toks[get(pos_box, 0) + 1].tok_kind == TOK_DOT()
                list_set(pos_box, 0, get(pos_box, 0) + 2)
                continue
            end
            if p_tok.tok_kind == TOK_IDENT()
                pname = p_tok.tok_text
                push(params, pname)
                p_uflag = 0
                p_itype = ""
                p_stype = ""
                p_prim = "int"
                if pname == "self" and eff_impl_type != ""
                    p_stype = eff_impl_type
                end
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                // Parse optional type annotation: : [...] [dyn] type[<...>]
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ":"))
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) + 1 < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_DOTDOT() and toks[get(pos_box, 0) + 1].tok_kind == TOK_DOT()
                        list_set(pos_box, 0, get(pos_box, 0) + 2)
                    end
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "dyn"
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                            p_stype = "dyn " + toks[get(pos_box, 0)].tok_text
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                        pt_txt = toks[get(pos_box, 0)].tok_text
                        if arm64_is_float_type(pt_txt) == 1
                            p_prim = "float"
                        elif pt_txt == "str" or pt_txt == "string"
                            p_prim = "str"
                        end
                        if arm64_is_uint_type(pt_txt) == 1
                            p_uflag = 1
                        end
                        if arm64_is_narrow_int_type(pt_txt) == 1
                            p_itype = pt_txt
                        elif arm64_synth_find_struct(s, pt_txt) != 0
                            p_stype = pt_txt
                        end
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "<"
                            pg_d = 1
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                            while get(pos_box, 0) < toks.len() and pg_d > 0
                                if toks[get(pos_box, 0)].tok_text == "<" pg_d = pg_d + 1
                                elif toks[get(pos_box, 0)].tok_text == ">" pg_d = pg_d - 1 end
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                            end
                        end
                    end
                end
                // Skip optional default value `= <expr>` (evaluated at call sites via prescanned Arm64FnSig)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_ASSIGN()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    d_nest = 0
                    while get(pos_box, 0) < toks.len()
                        dtk = toks[get(pos_box, 0)].tok_kind
                        if d_nest == 0 and (dtk == TOK_COMMA() or dtk == TOK_RPAREN() or dtk == TOK_NEWLINE() or dtk == TOK_LBRACE() or dtk == TOK_EOF())
                            break
                        end
                        if dtk == TOK_LPAREN() or dtk == TOK_LBRACKET() or dtk == TOK_LBRACE()
                            d_nest = d_nest + 1
                        elif dtk == TOK_RPAREN() or dtk == TOK_RBRACKET() or dtk == TOK_RBRACE()
                            if d_nest > 0 d_nest = d_nest - 1 end
                        end
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                end
                push(param_is_uint, p_uflag)
                push(param_int_types, p_itype)
                push(param_struct_types, p_stype)
                push(param_prim_types, p_prim)
            else
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end

        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        fn_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            fn_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end

        // ── Direct ARM64 SSA CFG Replacement (--ssa-codegen) ─────────────────
        if g_arm64_ssa_codegen == 1 and s.a64_ssa_lower_res != 0 and s.a64_ssa_lower_res.slr_success == 1
            a_slr = s.a64_ssa_lower_res
            a_mi = 0 - 1
            if a_slr.slr_fn_eligible != 0
                asfi = 0
                while asfi < a_slr.slr_fn_names.len() and asfi < a_slr.slr_fn_eligible.len()
                    if a_slr.slr_fn_names[asfi] == fn_name and a_slr.slr_fn_eligible[asfi] == 1
                        a_mi = asfi
                        break
                    end
                    asfi = asfi + 1
                end
            end
            if a_mi >= 0 and a_mi < a_slr.slr_fn_offsets.len() and a_mi < a_slr.slr_fn_sizes.len()
                a_off = a_slr.slr_fn_offsets[a_mi]
                a_sz = a_slr.slr_fn_sizes[a_mi]
                a_clen = 0
                if a_slr.slr_code_buf != 0
                    a_clen = buf_len(a_slr.slr_code_buf)
                elif a_slr.slr_code != 0
                    a_clen = a_slr.slr_code.len()
                end
                if a_sz > 0 and (a_off + a_sz) <= a_clen
                    dst_a_base = s.synth_code.len()
                    if a_slr.slr_code_buf != 0
                        a_cp = buf_ptr(a_slr.slr_code_buf)
                        abi = 0
                        while abi < a_sz
                            push(s.synth_code, mem_byte_read(a_cp, a_off + abi))
                            abi = abi + 1
                        end
                    else
                        abi = 0
                        while abi < a_sz
                            push(s.synth_code, a_slr.slr_code[a_off + abi])
                            abi = abi + 1
                        end
                    end
                    if a_slr.slr_call_relocs != 0
                        acri = 0
                        while acri < a_slr.slr_call_relocs.len()
                            ajp = a_slr.slr_call_relocs[acri]
                            if ajp.sjp_offset >= a_off and ajp.sjp_offset < (a_off + a_sz)
                                acrel = Arm64CallReloc()
                                acrel.a64_cr_patch_offset = dst_a_base + (ajp.sjp_offset - a_off)
                                acrel.a64_cr_target_name = ajp.sjp_target
                                push(s.synth_call_relocs, acrel)
                            end
                            acri = acri + 1
                        end
                    end
                    if fn_braced == 1
                        ask_d = 1
                        while get(pos_box, 0) < toks.len() and ask_d > 0
                            ask_t = toks[get(pos_box, 0)]
                            if ask_t.tok_kind == TOK_LBRACE() or (ask_t.tok_kind != TOK_STR() and ask_t.tok_text == "{")
                                ask_d = ask_d + 1
                            elif ask_t.tok_kind == TOK_RBRACE() or (ask_t.tok_kind != TOK_STR() and ask_t.tok_text == "}")
                                ask_d = ask_d - 1
                            end
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    else
                        a_sl_nest = 0
                        while get(pos_box, 0) < toks.len()
                            arm64_synth_skip_whitespace_tokens(toks, pos_box)
                            asp_c = get(pos_box, 0)
                            if asp_c >= toks.len() break end
                            ast_c = toks[asp_c]
                            if ast_c.tok_span.span_start_line == base_line and (ast_c.tok_kind == TOK_KW_IF() or ast_c.tok_kind == TOK_KW_WHILE() or ast_c.tok_kind == TOK_KW_FOR() or ast_c.tok_kind == TOK_KW_MATCH() or ast_c.tok_kind == TOK_KW_TRY())
                                a_sl_nest = a_sl_nest + 1
                            end
                            if ast_c.tok_kind == TOK_KW_END() or ast_c.tok_kind == TOK_DIR_END() or (ast_c.tok_kind == TOK_IDENT() and (ast_c.tok_text == "end" or ast_c.tok_text == "শেষ" or ast_c.tok_text == "@end"))
                                if ast_c.tok_span.span_start_col <= base_col or (ast_c.tok_span.span_start_line == base_line and a_sl_nest == 0)
                                    list_set(pos_box, 0, asp_c + 1)
                                    break
                                end
                                if ast_c.tok_span.span_start_line == base_line and a_sl_nest > 0
                                    a_sl_nest = a_sl_nest - 1
                                end
                            end
                            if ast_c.tok_span.span_start_line > base_line and ast_c.tok_span.span_start_col <= base_col
                                break
                            end
                            list_set(pos_box, 0, asp_c + 1)
                        end
                    end
                    after_a_off = s.synth_code.len()
                    fn_entry.a64_fn_end_offset = after_a_off
                    s.a64_ssa_replaced_cnt = s.a64_ssa_replaced_cnt + 1
                    s.a64_ssa_replaced_bytes = s.a64_ssa_replaced_bytes + a_sz
                    s.synth_locals = saved_arm_locals
                    s.synth_stack_offset = saved_arm_stack_off
                    s.a64_sp_delta = saved_arm_sp_delta
                    s.a64_in_function = 0
                    s.a64_try_patches = saved_arm_try_patches
                    s.a64_boxed_vars = saved_arm_boxed
                    s.a64_defer_starts = saved_arm_ds
                    s.a64_defer_ends = saved_arm_de
                    a_rel_w = (after_a_off - fn_jmp_patch) / 4
                    arm64_synth_patch_u32(s, fn_jmp_patch, 335544320 | (a_rel_w & 67108863))
                    return 0
                end
            end
        end

        // Prescan function body for variables mutated inside nested closures
        s.a64_boxed_vars = arm64_prescan_boxed_vars(toks, get(pos_box, 0), base_col, base_line)

        // Emit function prologue
        arm64_emit_prologue(s)

        // Save incoming argument registers (X0..X7) into local stack slots
        pi = 0
        while pi < params.len()
            pname = params[pi]
            off = arm64_synth_alloc_var(s, pname)
            plv_u = arm64_find_local_var(s, pname)
            p_it = ""
            if plv_u != 0 and pi < param_is_uint.len()
                plv_u.a64_lv_is_uint = param_is_uint[pi]
            end
            if plv_u != 0 and pi < param_int_types.len()
                p_it = param_int_types[pi]
                plv_u.a64_lv_int_type = p_it
            end
            if plv_u != 0 and pi < param_struct_types.len()
                plv_u.a64_lv_struct_type = param_struct_types[pi]
            end
            if plv_u != 0 and pi < param_prim_types.len()
                plv_u.a64_lv_prim_type = param_prim_types[pi]
            end
            if pi < 8
                if arm64_is_narrow_int_type(p_it) == 1
                    arm64_emit_truncate_int_width(s, pi, p_it)
                end
                arm64_emit_str_reg_sp(s, pi, off)
            else
                // AAPCS64 stack parameter pi >= 8 sits at [x29 + 16 + (pi - 8) * 8] above saved {x29, x30}
                arm64_emit_ldr_x_off(s, 9, 29, 16 + ((pi - 8) * 8))
                if arm64_is_narrow_int_type(p_it) == 1
                    arm64_emit_truncate_int_width(s, 9, p_it)
                end
                arm64_emit_str_reg_sp(s, 9, off)
            end
            pi = pi + 1
        // Wrap any closure-mutated parameter into a shared 8-byte heap upvalue cell
        pi = 0
        while pi < params.len()
            pname = params[pi]
            plv = arm64_find_local_var(s, pname)
            if plv != 0 and plv.a64_lv_is_boxed == 1
                arm64_emit_movz_x(s, 0, 8, 0)
                arm64_synth_emit_call_alloc(s)
                arm64_emit_ldr_reg_sp(s, 9, plv.lv_offset)
                arm64_emit_str_x_off(s, 9, 0, 0)
                arm64_emit_str_reg_sp(s, 0, plv.lv_offset)
            end
            pi = pi + 1
        end

        arm64_synth_skip_whitespace_tokens(toks, pos_box)

        // Parse function body statements until matching '}', next function, explicit end, or dedent
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_pos = get(pos_box, 0)
            if cur_pos >= toks.len()
                break
            ct = toks[cur_pos]
            cur_k = ct.tok_kind
            cur_txt = ct.tok_text
            if fn_braced == 1
                if cur_k == TOK_RBRACE() or cur_txt == "}"
                    list_set(pos_box, 0, cur_pos + 1)
                    break
                if cur_k == TOK_EOF()
                    break
            else
                if (cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN() or (cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "@fn"))) and cur_pos + 1 < toks.len() and toks[cur_pos + 1].tok_kind == TOK_IDENT()
                    break
                if (cur_k == TOK_KW_ASYNC() or (cur_k == TOK_IDENT() and (cur_txt == "async" or cur_txt == "@async"))) and cur_pos + 1 < toks.len() and (toks[cur_pos + 1].tok_kind == TOK_KW_FN() or toks[cur_pos + 1].tok_kind == TOK_DIR_FN() or toks[cur_pos + 1].tok_text == "fn" or toks[cur_pos + 1].tok_text == "কাজ")
                    break
                if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                    break
                if ct.tok_span.span_start_line > base_line and ct.tok_span.span_start_col <= base_col
                    break

            b_p = get(pos_box, 0)
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

        // Consume optional end / @end / শেষ
        if fn_braced == 0
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_pos = get(pos_box, 0)
            if cur_pos < toks.len()
                ct = toks[cur_pos]
                cur_k = ct.tok_kind
                cur_txt = ct.tok_text
                if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                    list_set(pos_box, 0, cur_pos + 1)
        end

        // Default epilogue at end of function
        arm64_emit_movz_x(s, 0, 0, 0)
        arm64_emit_movz_x(s, 1, 0, 0)
        arm64_emit_defers(s, toks)
        arm64_emit_epilogue(s)
        fn_entry.a64_fn_end_offset = s.synth_code.len()
        s.synth_locals = saved_arm_locals
        s.synth_stack_offset = saved_arm_stack_off
        s.a64_sp_delta = saved_arm_sp_delta
        s.a64_in_function = 0
        s.a64_try_patches = saved_arm_try_patches
        s.a64_boxed_vars = saved_arm_boxed
        s.a64_defer_starts = saved_arm_ds
        s.a64_defer_ends = saved_arm_de

        // Patch jump to bypass function body during top-level execution
        after_fn_offset = s.synth_code.len()
        rel_words = (after_fn_offset - fn_jmp_patch) / 4
        arm64_synth_patch_u32(s, fn_jmp_patch, 335544320 | (rel_words & 67108863))
        return 0

    // Default: evaluate expression or advance token
    arm64_synth_compile_expr(s, toks, pos_box)
    return 0

