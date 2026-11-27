// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN RISC-V 64 (RV64G) MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/riscv64/codegen_stmt.lp
// ==============================================================================

// ── 11. Statement Synthesizer ─────────────────────────────────────────────────

fn riscv64_try_compile_multi_assign s toks pos_box start_pos
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
    riscv64_synth_compile_expr(s, toks, pos_box)
    riscv64_push_reg(s, 10)
    rhs_cnt = 1
    while get(pos_box, 0) < toks.len()
        rp = get(pos_box, 0)
        if (toks[rp].tok_kind == TOK_COMMA() or (toks[rp].tok_kind != TOK_STR() and toks[rp].tok_text == ",")) and toks[rp].tok_span.span_start_line == eq_ln
            list_set(pos_box, 0, rp + 1)
            riscv64_synth_compile_expr(s, toks, pos_box)
            riscv64_push_reg(s, 10)
            rhs_cnt = rhs_cnt + 1
        else
            break
        end
    end
    if rhs_cnt == 1
        // Single RHS list/tuple unpack: pop list header into temp slot, then extract element 0..N-1
        tup_off = riscv64_synth_alloc_var(s, "__tup_" + str(s.rv_code.len()))
        riscv64_pop_reg(s, 10)
        riscv64_emit_local_sd(s, 10, tup_off)
        li = 0
        while li < lhs_names.len()
            riscv64_emit_local_ld(s, 28, tup_off)
            riscv64_emit_ld(s, 29, 28, 16)
            riscv64_emit_li(s, 5, li * 8)
            riscv64_emit_add(s, 29, 29, 5)
            riscv64_emit_ld(s, 10, 29, 0)
            vn = lhs_names[li]
            plv = riscv64_find_local_var(s, vn)
            if plv == 0
                voff = riscv64_synth_alloc_var(s, vn)
                riscv64_emit_local_sd(s, 10, voff)
            elif plv.rv_lv_is_boxed == 1
                riscv64_emit_local_ld(s, 5, plv.rv_lv_offset)
                riscv64_emit_sd(s, 10, 5, 0)
            else
                riscv64_emit_local_sd(s, 10, plv.rv_lv_offset)
            end
            li = li + 1
        end
    else
        // Multi-RHS: pop in reverse order for 100% swap-safety (e.g. `a, b = b, a`)
        li = rhs_cnt - 1
        while li >= 0
            riscv64_pop_reg(s, 10)
            if li < lhs_names.len()
                vn = lhs_names[li]
                plv = riscv64_find_local_var(s, vn)
                if plv == 0
                    voff = riscv64_synth_alloc_var(s, vn)
                    riscv64_emit_local_sd(s, 10, voff)
                elif plv.rv_lv_is_boxed == 1
                    riscv64_emit_local_ld(s, 5, plv.rv_lv_offset)
                    riscv64_emit_sd(s, 10, 5, 0)
                else
                    riscv64_emit_local_sd(s, 10, plv.rv_lv_offset)
                end
            end
            li = li - 1
        end
    end
    return 1
end

fn riscv64_synth_compile_statement s toks pos_box
    // WHY: Synthesizes execution bytes for statements (control flow, structs, loops, calls).
    s.rv_sp_delta = 0
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
                riscv64_emit_print_string(s, next_tok.tok_text)
                return 0

        // General expression print (ints, uints, floats, strings, dyn_tagged):
        riscv64_synth_compile_expr(s, toks, pos_box)
        if s.rv_last_expr_type == "str"
            s.rv_needs_print_tagged = 1
            riscv64_synth_emit_call_helper(s, "__print_str")
        elif s.rv_last_expr_type == "float"
            s.rv_needs_print_tagged = 1
            riscv64_synth_emit_call_helper(s, "__print_float")
        elif s.rv_last_expr_type == "dyn_tagged"
            s.rv_needs_print_tagged = 1
            s.rv_needs_print_int = 1
            riscv64_synth_emit_call_helper(s, "__print_tagged")
        elif s.rv_last_is_uint == 1
            riscv64_synth_emit_call_print_uint(s)
        else
            riscv64_synth_emit_call_print_int(s)
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
                push(s.rv_defer_starts, d_start)
                push(s.rv_defer_ends, d_scan)
                if d_scan < toks.len() d_scan = d_scan + 1 end
                list_set(pos_box, 0, d_scan)
            else
                d_scan = d_start
                while d_scan < toks.len() and toks[d_scan].tok_kind != TOK_NEWLINE() and toks[d_scan].tok_kind != TOK_SEMI() and toks[d_scan].tok_kind != TOK_EOF() and toks[d_scan].tok_span.span_start_line == d_line
                    d_scan = d_scan + 1
                end
                push(s.rv_defer_starts, d_start)
                push(s.rv_defer_ends, d_scan)
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
            riscv64_synth_compile_expr(s, toks, pos_box)
            // Tuple return: `return e1, e2 [, ...]` packs values into a first-class list
            cp_rt = get(pos_box, 0)
            if cp_rt < toks.len() and (toks[cp_rt].tok_kind == TOK_COMMA() or (toks[cp_rt].tok_kind != TOK_STR() and toks[cp_rt].tok_text == ",")) and toks[cp_rt].tok_span.span_start_line == ret_ln
                riscv64_push_reg(s, 10)
                rt_cnt = 1
                while get(pos_box, 0) < toks.len()
                    cr_p = get(pos_box, 0)
                    if (toks[cr_p].tok_kind == TOK_COMMA() or (toks[cr_p].tok_kind != TOK_STR() and toks[cr_p].tok_text == ",")) and toks[cr_p].tok_span.span_start_line == ret_ln
                        list_set(pos_box, 0, cr_p + 1)
                        riscv64_synth_compile_expr(s, toks, pos_box)
                        riscv64_push_reg(s, 10)
                        rt_cnt = rt_cnt + 1
                    else
                        break
                    end
                end
                s.rv_needs_list_create = 1
                s.rv_needs_alloc = 1
                riscv64_emit_li(s, 10, rt_cnt)
                rt_call_off = s.rv_code.len()
                riscv64_emit_jal(s, 1, 0)
                rt_rel = Riscv64CallReloc()
                rt_rel.rv_cr_patch_offset = rt_call_off
                rt_rel.rv_cr_target_name = "__list_create"
                push(s.rv_call_relocs, rt_rel)
                riscv64_emit_mv(s, 28, 10)
                riscv64_emit_ld(s, 29, 28, 16)
                ri_t = rt_cnt - 1
                while ri_t >= 0
                    riscv64_pop_reg(s, 11)
                    riscv64_emit_li(s, 5, ri_t * 8)
                    riscv64_emit_add(s, 5, 29, 5)
                    riscv64_emit_sd(s, 11, 5, 0)
                    ri_t = ri_t - 1
                end
                riscv64_emit_mv(s, 10, 28)
                riscv64_emit_addi(s, 11, 0, 0)
                s.rv_last_expr_type = "int"
            else
                if s.rv_last_expr_type == "float"
                    riscv64_emit_addi(s, 11, 0, 1)
                elif s.rv_last_expr_type == "str"
                    riscv64_emit_addi(s, 11, 0, 2)
                elif s.rv_last_expr_type != "dyn_tagged"
                    riscv64_emit_addi(s, 11, 0, 0)
                end
            end
        else
            riscv64_emit_addi(s, 10, 0, 0)
            riscv64_emit_addi(s, 11, 0, 0)
        end

        if s.rv_in_function == 1
            riscv64_emit_defers(s, toks)
            riscv64_emit_epilogue(s)
        else
            // Top-level return: exit whole process cleanly with code in a0 via Linux SYS_exit_group (94)
            riscv64_emit_defers(s, toks)
            riscv64_emit_li(s, 17, 94)
            riscv64_emit_ecall(s)
        return 0

    // ── 3. Loop Control: break / থামো & continue / চলুক ───────────────────────
    if k == TOK_KW_BREAK() or (k == TOK_IDENT() and (txt == "break" or txt == "থামো"))
        list_set(pos_box, 0, pos + 1)
        if s.rv_loop_breaks.len() > 0
            p_off = s.rv_code.len()
            riscv64_emit_jal(s, 0, 0) // Placeholder JAL x0, 0
            curr_brk_list = s.rv_loop_breaks[s.rv_loop_breaks.len() - 1]
            push(curr_brk_list, p_off)
        return 0

    if k == TOK_KW_CONTINUE() or (k == TOK_IDENT() and (txt == "continue" or txt == "চলুক" or txt == "চলো"))
        list_set(pos_box, 0, pos + 1)
        if s.rv_loop_starts.len() > 0
            loop_hdr = s.rv_loop_starts[s.rv_loop_starts.len() - 1]
            if loop_hdr < 0
                cont_patch = s.rv_code.len()
                riscv64_emit_jal(s, 0, 0)
                if s.rv_for_conts.len() > 0
                    curr_cont_list = s.rv_for_conts[s.rv_for_conts.len() - 1]
                    push(curr_cont_list, cont_patch)
            else
                cur_off = s.rv_code.len()
                rel_bytes = loop_hdr - cur_off
                riscv64_emit_jal(s, 0, rel_bytes)
        return 0

    // ── 4b. ADT Enum Definition: enum / @enum Name { Variant(T), ... } ───────
    if k == TOK_KW_ENUM() or k == TOK_DIR_ENUM() or (k == TOK_IDENT() and (txt == "enum" or txt == "@enum"))
        eb_col = t.tok_span.span_start_col
        eb_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        e_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            e_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                riscv64_enum_register(s, vname, s.rv_next_enum_tag, arity)
                s.rv_next_enum_tag = s.rv_next_enum_tag + 1
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
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        imp_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            imp_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        saved_impl = s.rv_impl_type
        s.rv_impl_type = imp_t
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == ib_p
                list_set(pos_box, 0, ib_p + 1)
            end
        end
        s.rv_impl_type = saved_impl
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

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        s_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            s_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end

        fields = list()
        field_types = list()
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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

        if riscv64_synth_find_struct(s, sname) == 0
            sdef = Riscv64StructDef()
            sdef.rv_sd_name = sname
            sdef.rv_sd_fields = fields
            sdef.rv_sd_is_union = is_union_decl
            sdef.rv_sd_type_id = s.rv_next_type_id
            sdef.rv_sd_field_types = field_types
            s.rv_next_type_id = s.rv_next_type_id + 1
            push(s.rv_structs, sdef)
        end
        return 0

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

            if is_dot == 1 and riscv64_is_ident_token(t2.tok_kind) == 1 and is_assign == 1
                obj_name = txt
                field_name = t2.tok_text
                list_set(pos_box, 0, p3 + 1) // Consume obj, '.', field, op

                // Evaluate RHS expr into a0 (plus a1 tag if dyn_tagged)
                riscv64_synth_compile_expr(s, toks, pos_box)
                f_rhs_t = s.rv_last_expr_type
                f_rhs_u = s.rv_last_is_uint
                riscv64_push_reg(s, 10)
                if f_rhs_t == "dyn_tagged"
                    riscv64_push_reg(s, 11)
                end

                // Load obj pointer into a1 and guard against null/low dereference
                obj_off = riscv64_synth_lookup_var(s, obj_name)
                if obj_off > 0
                    riscv64_emit_local_ld(s, 11, obj_off)
                else
                    riscv64_emit_addi(s, 11, 0, 0)
                end
                riscv64_emit_null_guard_reg(s, toks, 11)
                riscv64_emit_mv(s, 29, 11) // t4 (x29) = obj_ptr (preserved across FP/ALU helpers)

                // Pop RHS (and optional runtime tag into t2/x7)
                if f_rhs_t == "dyn_tagged"
                    riscv64_pop_reg(s, 7)
                end
                riscv64_pop_reg(s, 6) // t1 (x6) = rhs

                obj_st_rv = riscv64_synth_get_var_struct(s, obj_name)
                f_off = riscv64_synth_get_field_offset(s, obj_st_rv, field_name)
                f_decl_t = riscv64_synth_get_field_type(s, obj_st_rv, field_name)
                f_is_flt = riscv64_is_float_type(f_decl_t)
                f_is_u = riscv64_is_uint_type(f_decl_t)

                if f_comp_op == 0
                    riscv64_emit_mv(s, 10, 6)
                    if f_is_flt == 1 and f_rhs_t != "float"
                        // WHY: Promote integer RHS to IEEE-754 f64 when storing into an f64 struct field.
                        riscv64_emit_load_fp_reg(s, 10, 10, f_rhs_t, f_rhs_u, 7)
                        riscv64_emit_fmv_x_d(s, 10, 10)
                    end
                else
                    // WHY: Load existing field into a0, perform hardware RV64D f64 or div0-guarded integer op.
                    riscv64_emit_ld(s, 10, 29, f_off)
                    if f_is_flt == 1 or f_rhs_t == "float"
                        f_lhs_t = "int"
                        if f_is_flt == 1 f_lhs_t = "float" end
                        riscv64_emit_load_fp_reg(s, 10, 10, f_lhs_t, f_is_u, 5)
                        riscv64_emit_load_fp_reg(s, 11, 6, f_rhs_t, f_rhs_u, 7)
                        riscv64_emit_fp_arith_op(s, f_comp_op)
                    else
                        riscv64_emit_mv(s, 11, 6)
                        fc_u = f_is_u
                        if f_rhs_u == 1 fc_u = 1 end
                        if f_comp_op == TOK_PLUS()
                            riscv64_emit_add(s, 10, 10, 11)
                        elif f_comp_op == TOK_MINUS()
                            riscv64_emit_sub(s, 10, 10, 11)
                        elif f_comp_op == TOK_STAR()
                            riscv64_emit_mul(s, 10, 10, 11)
                        elif f_comp_op == TOK_SLASH()
                            bne_fdz = s.rv_code.len()
                            riscv64_emit_bne(s, 11, 0, 0)
                            riscv64_emit_addi(s, 10, 0, 0)
                            jmp_fdz = s.rv_code.len()
                            riscv64_emit_jal(s, 0, 0)
                            riscv64_synth_patch_b(s, bne_fdz, 1, 11, 0, s.rv_code.len())
                            if fc_u == 1 riscv64_emit_divu(s, 10, 10, 11) else riscv64_emit_div(s, 10, 10, 11) end
                            riscv64_synth_patch_jal(s, jmp_fdz, 0, s.rv_code.len())
                        elif f_comp_op == TOK_PERCENT()
                            bne_frz = s.rv_code.len()
                            riscv64_emit_bne(s, 11, 0, 0)
                            riscv64_emit_addi(s, 10, 0, 0)
                            jmp_frz = s.rv_code.len()
                            riscv64_emit_jal(s, 0, 0)
                            riscv64_synth_patch_b(s, bne_frz, 1, 11, 0, s.rv_code.len())
                            if fc_u == 1 riscv64_emit_remu(s, 10, 10, 11) else riscv64_emit_rem(s, 10, 10, 11) end
                            riscv64_synth_patch_jal(s, jmp_frz, 0, s.rv_code.len())
                        end
                    end
                end

                // Store value to field: sd a0, f_off(t4)
                riscv64_emit_sd(s, 10, 29, f_off)
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
                list_set(pos_box, 0, pos + 2) // Consume arr and '['
                riscv64_synth_compile_expr(s, toks, pos_box) // a0 = idx
                riscv64_push_reg(s, 10)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_ASSIGN()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                riscv64_synth_compile_expr(s, toks, pos_box) // a0 = rhs (a1 = tag if dyn_tagged)
                cs_rhs_type = s.rv_last_expr_type
                riscv64_push_reg(s, 10)
                if cs_rhs_type == "dyn_tagged"
                    riscv64_push_reg(s, 11)
                end
                lv_arr = riscv64_find_local_var(s, arr_name)
                if lv_arr != 0
                    if cs_rhs_type == "dyn_tagged"
                        riscv64_pop_reg(s, 13)            // a3 = runtime val_tag
                    elif cs_rhs_type == "float"
                        riscv64_emit_addi(s, 13, 0, 1)
                    elif cs_rhs_type == "str"
                        riscv64_emit_addi(s, 13, 0, 2)
                    else
                        riscv64_emit_addi(s, 13, 0, 0)
                    end
                    riscv64_pop_reg(s, 12)                // a2 = val
                    riscv64_pop_reg(s, 11)                // a1 = key/idx
                    riscv64_emit_local_ld(s, 10, lv_arr.rv_lv_offset) // a0 = hdr
                    if lv_arr.rv_lv_is_boxed == 1
                        riscv64_emit_ld(s, 10, 10, 0)
                    end
                    s.rv_needs_dict = 1
                    s.rv_needs_alloc = 1
                    riscv64_synth_emit_call_helper(s, "__container_set")
                    if s.rv_try_patches.len() > 0
                        cs_npe_bne = s.rv_code.len()
                        riscv64_emit_bne(s, 26, 0, 0)
                        push(s.rv_try_patches[s.rv_try_patches.len() - 1], [cs_npe_bne, 1])
                    elif s.rv_in_function == 1
                        cs_npe_eq = s.rv_code.len()
                        riscv64_emit_beq(s, 26, 0, 0)
                        riscv64_emit_addi(s, 2, 8, 0 - 1024)
                        riscv64_emit_defers(s, toks)
                        riscv64_emit_epilogue(s)
                        riscv64_synth_patch_b(s, cs_npe_eq, 0, 26, 0, s.rv_code.len())
                    elif s.rv_freestanding == 0
                        s.rv_needs_uncaught_throw = 1
                        cs_npe_ut = s.rv_code.len()
                        riscv64_emit_beq(s, 26, 0, 0)
                        riscv64_synth_emit_call_helper(s, "__uncaught_throw")
                        riscv64_synth_patch_b(s, cs_npe_ut, 0, 26, 0, s.rv_code.len())
                    end
                else
                    if cs_rhs_type == "dyn_tagged"
                        riscv64_pop_reg(s, 13)
                    end
                    riscv64_pop_reg(s, 12)
                    riscv64_pop_reg(s, 11)
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

        // Evaluate conditional expression into a0
        riscv64_synth_compile_expr(s, toks, pos_box)

        // beq a0, x0, next_branch (branch if zero/false)
        patch_next_branch = s.rv_code.len()
        riscv64_emit_beq(s, 10, 0, 0) // Placeholder

        end_patches = list()
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        if_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            if_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile then-block statements
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == before_stmt_p
                list_set(pos_box, 0, before_stmt_p + 1)

            if if_braced == 0 and cur_t.tok_span.span_start_line == base_line
                break

        // Check if there is an elif or else coming next
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
            jmp_end = s.rv_code.len()
            riscv64_emit_jal(s, 0, 0) // Placeholder JAL x0, 0
            push(end_patches, jmp_end)

            cur_off = s.rv_code.len()
            riscv64_synth_patch_b(s, patch_next_branch, 0, 10, 0, cur_off)
        else
            cur_off = s.rv_code.len()
            riscv64_synth_patch_b(s, patch_next_branch, 0, 10, 0, cur_off)

        // Loop over elif branches
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
            riscv64_synth_compile_expr(s, toks, pos_box)

            patch_next_branch = s.rv_code.len()
            riscv64_emit_beq(s, 10, 0, 0) // beq a0, x0, next_branch

            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
            elif_braced = 0
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
                elif_braced = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)

            while get(pos_box, 0) < toks.len()
                riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                riscv64_synth_compile_statement(s, toks, pos_box)
                if get(pos_box, 0) == b_p2
                    list_set(pos_box, 0, b_p2 + 1)
                if elif_braced == 0 and ct2.tok_span.span_start_line == elif_line
                    break

            jmp_end = s.rv_code.len()
            riscv64_emit_jal(s, 0, 0)
            push(end_patches, jmp_end)

            cur_off = s.rv_code.len()
            riscv64_synth_patch_b(s, patch_next_branch, 0, 10, 0, cur_off)

        // Check for else
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                riscv64_synth_skip_whitespace_tokens(toks, pos_box)
                else_braced = 0
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
                    else_braced = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                    riscv64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p3
                        list_set(pos_box, 0, b_p3 + 1)
                    if else_braced == 0 and ct3.tok_span.span_start_line == else_line
                        break

        // Consume optional end / @end / শেষ
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Backpatch all exit jumps to current offset
        cur_off = s.rv_code.len()
        ei = 0
        while ei < end_patches.len()
            p_end = end_patches[ei]
            riscv64_synth_patch_jal(s, p_end, 0, cur_off)
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

        loop_header = s.rv_code.len()
        push(s.rv_loop_starts, loop_header)
        loop_brks = list()
        push(s.rv_loop_breaks, loop_brks)
        while_conts = list()
        push(s.rv_for_conts, while_conts)

        // Evaluate condition into a0
        riscv64_synth_compile_expr(s, toks, pos_box)

        // beq a0, x0, loop_exit
        patch_loop_exit = s.rv_code.len()
        riscv64_emit_beq(s, 10, 0, 0) // Placeholder

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        while_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            while_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile while body statements
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if while_braced == 0 and cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Backward jump to loop_header: jal x0, loop_header
        cur_off = s.rv_code.len()
        rel_bytes = loop_header - cur_off
        riscv64_emit_jal(s, 0, rel_bytes)

        // Backpatch loop_exit
        loop_exit_off = s.rv_code.len()
        riscv64_synth_patch_b(s, patch_loop_exit, 0, 10, 0, loop_exit_off)

        // Backpatch all break jumps
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            riscv64_synth_patch_jal(s, brk_patch, 0, loop_exit_off)
            bi = bi + 1

        s.rv_loop_starts = pop(s.rv_loop_starts)
        s.rv_loop_breaks = pop(s.rv_loop_breaks)
        s.rv_for_conts = pop(s.rv_for_conts)
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

        // Compile first iterable expression into a0 (either range start `a` or collection `arr`)
        riscv64_synth_compile_expr(s, toks, pos_box)
        var_off = riscv64_synth_alloc_var(s, var_name)

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
            riscv64_emit_local_sd(s, 10, var_off)
            // Compile end expression into a0
            riscv64_synth_compile_expr(s, toks, pos_box)
            end_var_name = "__end_" + var_name + "_" + str(s.rv_code.len())
            end_off = riscv64_synth_alloc_var(s, end_var_name)
            riscv64_emit_local_sd(s, 10, end_off)
        else
            // Collection iteration: a0 holds list header [len, cap, data_ptr]
            col_off = riscv64_synth_alloc_var(s, "__fcol_" + var_name + "_" + str(s.rv_code.len()))
            riscv64_emit_local_sd(s, 10, col_off)
            end_off = riscv64_synth_alloc_var(s, "__flen_" + var_name + "_" + str(s.rv_code.len()))
            riscv64_emit_ld(s, 10, 10, 0)
            riscv64_emit_local_sd(s, 10, end_off)
            idx_off = riscv64_synth_alloc_var(s, "__fidx_" + var_name + "_" + str(s.rv_code.len()))
            riscv64_emit_addi(s, 10, 0, 0)
            riscv64_emit_local_sd(s, 10, idx_off)
        end

        loop_header = s.rv_code.len()
        push(s.rv_loop_starts, 0 - 1)
        loop_brks = list()
        push(s.rv_loop_breaks, loop_brks)
        for_conts = list()
        push(s.rv_for_conts, for_conts)

        patch_loop_exit = 0
        if is_for_range == 1
            // Compare var and end inclusive (a..b): exit if end < var (blt a1, a0)
            riscv64_emit_local_ld(s, 10, var_off)
            riscv64_emit_local_ld(s, 11, end_off)
            patch_loop_exit = s.rv_code.len()
            riscv64_emit_blt(s, 11, 10, 0)
        else
            // Compare idx and len: exit if idx >= len (bge a0, a1)
            riscv64_emit_local_ld(s, 10, idx_off)
            riscv64_emit_local_ld(s, 11, end_off)
            patch_loop_exit = s.rv_code.len()
            riscv64_emit_bge(s, 10, 11, 0)
            // Load element var = data_ptr[idx]
            riscv64_emit_local_ld(s, 28, col_off)
            riscv64_emit_ld(s, 29, 28, 16)
            riscv64_emit_local_ld(s, 5, idx_off)
            riscv64_emit_slli(s, 5, 5, 3)
            riscv64_emit_add(s, 29, 29, 5)
            riscv64_emit_ld(s, 10, 29, 0)
            riscv64_emit_local_sd(s, 10, var_off)
        end

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        for_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            for_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile for body statements
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if for_braced == 0 and cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Step target for continue statements inside for-loop
        step_off = s.rv_code.len()
        fci = 0
        while fci < for_conts.len()
            riscv64_synth_patch_jal(s, for_conts[fci], 0, step_off)
            fci = fci + 1

        // Increment range var or collection index
        step_var_off = var_off
        if is_for_range == 0
            step_var_off = idx_off
        end
        riscv64_emit_local_ld(s, 10, step_var_off)
        riscv64_emit_addi(s, 10, 10, 1)
        riscv64_emit_local_sd(s, 10, step_var_off)

        // jal x0, loop_header
        cur_off = s.rv_code.len()
        rel_bytes = loop_header - cur_off
        riscv64_emit_jal(s, 0, rel_bytes)

        // Backpatch loop_exit (blt a1, a0 for range; bge a0, a1 for collection)
        loop_exit_off = s.rv_code.len()
        if is_for_range == 1
            riscv64_synth_patch_b(s, patch_loop_exit, 4, 11, 10, loop_exit_off)
        else
            riscv64_synth_patch_b(s, patch_loop_exit, 5, 10, 11, loop_exit_off)
        end

        // Backpatch breaks
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            riscv64_synth_patch_jal(s, brk_patch, 0, loop_exit_off)
            bi = bi + 1

        s.rv_loop_starts = pop(s.rv_loop_starts)
        s.rv_loop_breaks = pop(s.rv_loop_breaks)
        s.rv_for_conts = pop(s.rv_for_conts)
        return 0

    // ── 8b. Pattern Match: match / মিল / মেলাও / @match ────────────────────────
    is_match = 0
    if k == TOK_KW_MATCH() or k == TOK_DIR_MATCH() or (k == TOK_IDENT() and (txt == "match" or txt == "মিল" or txt == "মেলাও" or txt == "@match"))
        if pos + 1 < toks.len()
            mn_r = toks[pos + 1]
            if mn_r.tok_kind != TOK_ASSIGN() and mn_r.tok_text != "=" and mn_r.tok_kind != TOK_PLUSEQ() and mn_r.tok_text != "+=" and mn_r.tok_kind != TOK_MINUSEQ() and mn_r.tok_text != "-=" and mn_r.tok_kind != TOK_STAREQ() and mn_r.tok_kind != TOK_SLASHEQ() and mn_r.tok_kind != TOK_PERCENTEQ() and mn_r.tok_kind != TOK_DOT() and mn_r.tok_text != "." and mn_r.tok_kind != TOK_LBRACKET() and mn_r.tok_text != "[" and mn_r.tok_kind != TOK_LPAREN() and mn_r.tok_text != "(" and mn_r.tok_kind != TOK_NEWLINE() and mn_r.tok_kind != TOK_SEMI()
                is_match = 1

    if is_match == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)

        riscv64_synth_compile_expr(s, toks, pos_box)
        m_off = riscv64_synth_alloc_var(s, "__rv64_match_" + str(pos))
        riscv64_emit_local_sd(s, 10, m_off)
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        m_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            m_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end

        end_patches = list()
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                    riscv64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == bp_e1
                        list_set(pos_box, 0, bp_e1 + 1)
                else
                    while get(pos_box, 0) < toks.len()
                        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                        riscv64_synth_compile_statement(s, toks, pos_box)
                        if get(pos_box, 0) == bp_e
                            list_set(pos_box, 0, bp_e + 1)
                break
            else
                // ADT Enum Variant Pattern (e.g. Some(v) => ..., None => ..., Ok(x) => ...) vs Scalar Value Pattern
                adt_pidx = riscv64_enum_find_idx(s, px_m)
                patch_miss_null = 0 - 1
                patch_miss_r1 = 11
                patch_miss_r2 = 10
                if adt_pidx >= 0
                    adt_tag = s.rv_enum_tags[adt_pidx]
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
                    riscv64_emit_local_ld(s, 11, m_off)
                    riscv64_emit_li(s, 6, 4096)
                    patch_miss_null = s.rv_code.len()
                    riscv64_emit_bltu(s, 11, 6, 0) // bltu a1, t1, miss (< 4096)
                    riscv64_emit_ld(s, 5, 11, 0)
                    riscv64_emit_li(s, 6, adt_tag)
                    patch_miss = s.rv_code.len()
                    riscv64_emit_bne(s, 5, 6, 0) // bne t0, t1, miss
                    patch_miss_r1 = 5
                    patch_miss_r2 = 6
                    bi_r = 0
                    while bi_r < adt_binds.len()
                        bnm = adt_binds[bi_r]
                        if bnm != "_"
                            boff = riscv64_synth_alloc_var(s, bnm)
                            riscv64_emit_ld(s, 5, 11, (bi_r + 1) * 8)
                            riscv64_emit_local_sd(s, 5, boff)
                        end
                        bi_r = bi_r + 1
                    end
                else
                    riscv64_synth_compile_expr(s, toks, pos_box)
                    if get(pos_box, 0) < toks.len()
                        sep_k2 = toks[get(pos_box, 0)].tok_kind
                        sep_t2 = toks[get(pos_box, 0)].tok_text
                        if sep_k2 == TOK_FAT_ARROW() or sep_k2 == TOK_COLON() or sep_k2 == TOK_ARROW() or sep_t2 == "=>" or sep_t2 == ":" or sep_t2 == "->"
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    end
                    riscv64_emit_local_ld(s, 11, m_off)
                    patch_miss = s.rv_code.len()
                    riscv64_emit_bne(s, 11, 10, 0) // bne a1, a0, miss
                end

                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == arm_line and toks[get(pos_box, 0)].tok_kind != TOK_NEWLINE() and toks[get(pos_box, 0)].tok_kind != TOK_SEMI() and toks[get(pos_box, 0)].tok_kind != TOK_COMMENT_LINE()
                    bp_c1 = get(pos_box, 0)
                    riscv64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == bp_c1
                        list_set(pos_box, 0, bp_c1 + 1)
                else
                    while get(pos_box, 0) < toks.len()
                        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                        riscv64_synth_compile_statement(s, toks, pos_box)
                        if get(pos_box, 0) == bp_c
                            list_set(pos_box, 0, bp_c + 1)

                jmp_end = s.rv_code.len()
                riscv64_emit_jal(s, 0, 0)
                push(end_patches, jmp_end)

                miss_off = s.rv_code.len()
                if patch_miss_null >= 0
                    riscv64_synth_patch_b(s, patch_miss_null, 6, 11, 6, miss_off)
                end
                riscv64_synth_patch_b(s, patch_miss, 1, patch_miss_r1, patch_miss_r2, miss_off)

        end_off = s.rv_code.len()
        ei = 0
        while ei < end_patches.len()
            ep = end_patches[ei]
            riscv64_synth_patch_jal(s, ep, 0, end_off)
            ei = ei + 1

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            et_m = toks[get(pos_box, 0)]
            if et_m.tok_kind == TOK_KW_END() or et_m.tok_kind == TOK_DIR_END() or (et_m.tok_kind == TOK_IDENT() and (et_m.tok_text == "end" or et_m.tok_text == "শেষ" or et_m.tok_text == "@end"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
        return 0

    // ── 8c. Exception Handling: throw / নিক্ষেপ & try / চেষ্টা ... catch / ধরো ─
    if k == TOK_IDENT() and (txt == "throw" or txt == "নিক্ষেপ" or txt == "@throw")
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_compile_expr(s, toks, pos_box)
        riscv64_emit_addi(s, 27, 10, 0)
        if s.rv_last_expr_type == "float"
            riscv64_emit_addi(s, 26, 0, 2)
        elif s.rv_last_expr_type == "str"
            riscv64_emit_addi(s, 26, 0, 3)
        elif s.rv_last_expr_type == "dyn_tagged"
            riscv64_emit_addi(s, 26, 11, 1)
        else
            riscv64_emit_addi(s, 26, 0, 1)
        end
        if s.rv_try_patches.len() > 0
            p_off = s.rv_code.len()
            riscv64_emit_jal(s, 0, 0)
            active_tp = s.rv_try_patches[s.rv_try_patches.len() - 1]
            push(active_tp, [p_off, 0])
        elif s.rv_in_function == 1
            riscv64_emit_addi(s, 2, 8, 0 - 1024)
            riscv64_emit_defers(s, toks)
            riscv64_emit_epilogue(s)
        elif s.rv_freestanding == 0
            // WHY: Top-level uncaught throw runs defers, prints "Uncaught exception: <val>" to stderr, and exits 1.
            riscv64_emit_defers(s, toks)
            s.rv_needs_uncaught_throw = 1
            riscv64_synth_emit_call_helper(s, "__uncaught_throw")
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
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        try_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            try_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end

        // Reset s10 (x26) exception flag before entering try block
        riscv64_emit_addi(s, 26, 0, 0)
        tp_list = list()
        push(s.rv_try_patches, tp_list)

        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == bp_t
                list_set(pos_box, 0, bp_t + 1)

        cur_tp = s.rv_try_patches[s.rv_try_patches.len() - 1]
        s.rv_try_patches = pop(s.rv_try_patches)

        jmp_after_catch = s.rv_code.len()
        riscv64_emit_jal(s, 0, 0)

        catch_entry_off = s.rv_code.len()
        tpi = 0
        while tpi < cur_tp.len()
            p_item = cur_tp[tpi]
            p_off = p_item[0]
            p_kind = p_item[1]
            if p_kind == 0
                riscv64_synth_patch_jal(s, p_off, 0, catch_entry_off)
            else
                riscv64_synth_patch_b(s, p_off, 1, 26, 0, catch_entry_off)
            tpi = tpi + 1

        // Restore SP = s0 - 1024, extract exception tag = (s10 - 1) into t0, then clear s10
        riscv64_emit_addi(s, 2, 8, 0 - 1024)
        riscv64_emit_addi(s, 5, 26, 0 - 1)
        riscv64_emit_addi(s, 26, 0, 0)

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                riscv64_synth_skip_whitespace_tokens(toks, pos_box)
                catch_braced = 0
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
                    catch_braced = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end

                if catch_var != ""
                    cv_off = riscv64_synth_alloc_var(s, catch_var)
                    riscv64_emit_local_sd(s, 27, cv_off)
                    cv_lv = riscv64_find_local_var(s, catch_var)
                    if cv_lv != 0
                        cv_lv.rv_lv_prim_type = "dyn_tagged"
                        cv_toff = riscv64_synth_alloc_tag_slot(s, cv_lv)
                        riscv64_emit_local_sd(s, 5, cv_toff)
                    end
                end

                while get(pos_box, 0) < toks.len()
                    riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                    riscv64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == bp_cb
                        list_set(pos_box, 0, bp_cb + 1)

        after_catch_off = s.rv_code.len()
        riscv64_synth_patch_jal(s, jmp_after_catch, 0, after_catch_off)

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
        if riscv64_try_compile_multi_assign(s, toks, pos_box, var_pos) == 1
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
                s.rv_last_struct = ""
                riscv64_synth_compile_expr(s, toks, pos_box)
                if riscv64_is_float_type(let_decl_type) == 1
                    if s.rv_last_expr_type != "float"
                        riscv64_emit_load_fp_reg(s, 10, 10, s.rv_last_expr_type, s.rv_last_is_uint, 11)
                        riscv64_emit_fmv_x_d(s, 10, 10)
                    end
                    s.rv_last_expr_type = "float"
                    s.rv_last_is_uint = 0
                end
                prev_lv = riscv64_find_local_var(s, var_name)
                eff_let_itype = let_decl_type
                if eff_let_itype == "" and prev_lv != 0
                    eff_let_itype = prev_lv.rv_lv_int_type
                end
                if riscv64_is_narrow_int_type(eff_let_itype) == 1
                    riscv64_emit_truncate_int_width(s, 10, eff_let_itype)
                end
                if prev_lv == 0
                    off = riscv64_synth_alloc_var(s, var_name)
                    if riscv64_is_boxed_name(s, var_name) == 1
                        riscv64_push_reg(s, 10)
                        riscv64_emit_li(s, 10, 8)
                        riscv64_synth_emit_call_alloc(s)
                        riscv64_pop_reg(s, 5)
                        riscv64_emit_sd(s, 5, 10, 0)
                        riscv64_emit_local_sd(s, 10, off)
                    else
                        riscv64_emit_local_sd(s, 10, off)
                    end
                    prev_lv = riscv64_find_local_var(s, var_name)
                elif prev_lv.rv_lv_is_boxed == 1
                    riscv64_emit_local_ld(s, 5, prev_lv.rv_lv_offset)
                    riscv64_emit_sd(s, 10, 5, 0)
                else
                    riscv64_emit_local_sd(s, 10, prev_lv.rv_lv_offset)
                end
                if prev_lv != 0
                    if riscv64_is_uint_type(let_decl_type) == 1 or (let_decl_type == "" and s.rv_last_is_uint == 1)
                        prev_lv.rv_lv_is_uint = 1
                    elif let_decl_type != ""
                        prev_lv.rv_lv_is_uint = 0
                    end
                    if let_decl_type != ""
                        if riscv64_is_narrow_int_type(let_decl_type) == 1
                            prev_lv.rv_lv_int_type = let_decl_type
                        else
                            prev_lv.rv_lv_int_type = ""
                        end
                    end
                    prev_lv.rv_lv_prim_type = s.rv_last_expr_type
                    if s.rv_last_expr_type == "dyn_tagged"
                        t_off = riscv64_synth_alloc_tag_slot(s, prev_lv)
                        riscv64_emit_local_sd(s, 11, t_off)
                    end
                end
                riscv64_synth_set_var_struct(s, var_name, s.rv_last_struct)
        return 0

    // ── 10. Assignment & Compound Assignment: <var> [: Type] = <expr>, <var> += <expr> ─
    if k == TOK_IDENT()
        if riscv64_try_compile_multi_assign(s, toks, pos_box, pos) == 1
            return 0
        end
        next_pos = pos + 1
        decl_type_rv = ""
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_COLON() or (toks[next_pos].tok_kind != TOK_STR() and toks[next_pos].tok_text == ":"))
            tp_rv = next_pos + 1
            if tp_rv < toks.len() and toks[tp_rv].tok_text == "dyn" and tp_rv + 2 < toks.len() and toks[tp_rv + 1].tok_kind == TOK_IDENT() and toks[tp_rv + 2].tok_kind == TOK_ASSIGN()
                decl_type_rv = "dyn " + toks[tp_rv + 1].tok_text
                next_pos = tp_rv + 2
            elif tp_rv < toks.len() and toks[tp_rv].tok_kind == TOK_IDENT()
                tp_end = tp_rv + 1
                if tp_end < toks.len() and toks[tp_end].tok_text == "<"
                    rg_d = 1
                    tp_end = tp_end + 1
                    while tp_end < toks.len() and rg_d > 0
                        if toks[tp_end].tok_text == "<" rg_d = rg_d + 1
                        elif toks[tp_end].tok_text == ">" rg_d = rg_d - 1 end
                        tp_end = tp_end + 1
                    end
                end
                if tp_end < toks.len() and toks[tp_end].tok_kind == TOK_ASSIGN()
                    decl_type_rv = toks[tp_rv].tok_text
                    next_pos = tp_end
                end
            end
        end
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_ASSIGN()
            var_name = txt
            list_set(pos_box, 0, next_pos + 1) // Consume ident [: type] and '='
            s.rv_last_struct = ""
            riscv64_synth_compile_expr(s, toks, pos_box)
            if riscv64_is_float_type(decl_type_rv) == 1
                if s.rv_last_expr_type != "float"
                    riscv64_emit_load_fp_reg(s, 10, 10, s.rv_last_expr_type, s.rv_last_is_uint, 11)
                    riscv64_emit_fmv_x_d(s, 10, 10)
                end
                s.rv_last_expr_type = "float"
                s.rv_last_is_uint = 0
            end
            prev_lv = riscv64_find_local_var(s, var_name)
            eff_as_itype = decl_type_rv
            if eff_as_itype == "" and prev_lv != 0
                eff_as_itype = prev_lv.rv_lv_int_type
            end
            if riscv64_is_narrow_int_type(eff_as_itype) == 1
                riscv64_emit_truncate_int_width(s, 10, eff_as_itype)
            end
            if prev_lv == 0
                off = riscv64_synth_alloc_var(s, var_name)
                if riscv64_is_boxed_name(s, var_name) == 1
                    riscv64_push_reg(s, 10)
                    riscv64_emit_li(s, 10, 8)
                    riscv64_synth_emit_call_alloc(s)
                    riscv64_pop_reg(s, 5)
                    riscv64_emit_sd(s, 5, 10, 0)
                    riscv64_emit_local_sd(s, 10, off)
                else
                    riscv64_emit_local_sd(s, 10, off)
                end
                prev_lv = riscv64_find_local_var(s, var_name)
            elif prev_lv.rv_lv_is_boxed == 1
                riscv64_emit_local_ld(s, 5, prev_lv.rv_lv_offset)
                riscv64_emit_sd(s, 10, 5, 0)
            else
                riscv64_emit_local_sd(s, 10, prev_lv.rv_lv_offset)
            end
            if prev_lv != 0
                if riscv64_is_uint_type(decl_type_rv) == 1 or (decl_type_rv == "" and s.rv_last_is_uint == 1)
                    prev_lv.rv_lv_is_uint = 1
                elif decl_type_rv != ""
                    prev_lv.rv_lv_is_uint = 0
                end
                if decl_type_rv != ""
                    if riscv64_is_narrow_int_type(decl_type_rv) == 1
                        prev_lv.rv_lv_int_type = decl_type_rv
                    else
                        prev_lv.rv_lv_int_type = ""
                    end
                end
                prev_lv.rv_lv_prim_type = s.rv_last_expr_type
                if s.rv_last_expr_type == "dyn_tagged"
                    t_off = riscv64_synth_alloc_tag_slot(s, prev_lv)
                    riscv64_emit_local_sd(s, 11, t_off)
                end
            end
            riscv64_synth_set_var_struct(s, var_name, s.rv_last_struct)
            return 0
        end
        if next_pos < toks.len()
            ca_op = riscv64_is_compound_assign_tok(toks[next_pos])
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
                riscv64_synth_compile_expr(s, toks, pos_box) // a0 = rhs
                ca_rhs_u = s.rv_last_is_uint
                ca_rhs_t = s.rv_last_expr_type
                if ca_rhs_t == "dyn_tagged"
                    riscv64_emit_mv(s, 7, 11)
                end
                riscv64_emit_mv(s, 6, 10)  // t1 = rhs
                riscv64_emit_mv(s, 11, 10) // a1 = rhs
                ca_lv = riscv64_find_local_var(s, var_name)
                ca_u = ca_rhs_u
                ca_lhs_t = "int"
                ca_lhs_u = 0
                if ca_lv != 0
                    if ca_lv.rv_lv_is_uint == 1
                        ca_u = 1
                        ca_lhs_u = 1
                    end
                    if ca_lv.rv_lv_prim_type != ""
                        ca_lhs_t = ca_lv.rv_lv_prim_type
                    end
                    riscv64_emit_local_ld(s, 10, ca_lv.rv_lv_offset)
                    if ca_lv.rv_lv_is_boxed == 1
                        riscv64_emit_ld(s, 10, 10, 0)
                    end
                    if ca_lhs_t == "dyn_tagged" and ca_lv.rv_lv_tag_off > 0
                        riscv64_emit_local_ld(s, 5, ca_lv.rv_lv_tag_off)
                    end
                else
                    riscv64_emit_addi(s, 10, 0, 0)
                end
                if (ca_lhs_t == "float" or ca_rhs_t == "float") and (ca_op == TOK_PLUS() or ca_op == TOK_MINUS() or ca_op == TOK_STAR() or ca_op == TOK_SLASH() or ca_op == TOK_PERCENT())
                    riscv64_emit_load_fp_reg(s, 10, 10, ca_lhs_t, ca_lhs_u, 5)
                    riscv64_emit_load_fp_reg(s, 11, 6, ca_rhs_t, ca_rhs_u, 7)
                    riscv64_emit_fp_arith_op(s, ca_op)
                    if ca_lv != 0
                        ca_lv.rv_lv_prim_type = "float"
                        ca_lv.rv_lv_is_uint = 0
                    end
                elif ca_op == TOK_PLUS()
                    riscv64_emit_add(s, 10, 10, 11)
                elif ca_op == TOK_MINUS()
                    riscv64_emit_sub(s, 10, 10, 11)
                elif ca_op == TOK_STAR()
                    riscv64_emit_mul(s, 10, 10, 11)
                elif ca_op == TOK_SLASH()
                    bne_cdz = s.rv_code.len()
                    riscv64_emit_bne(s, 11, 0, 0)
                    riscv64_emit_addi(s, 10, 0, 0)
                    jmp_cdz = s.rv_code.len()
                    riscv64_emit_jal(s, 0, 0)
                    riscv64_synth_patch_b(s, bne_cdz, 1, 11, 0, s.rv_code.len())
                    if ca_u == 1 riscv64_emit_divu(s, 10, 10, 11) else riscv64_emit_div(s, 10, 10, 11) end
                    riscv64_synth_patch_jal(s, jmp_cdz, 0, s.rv_code.len())
                elif ca_op == TOK_PERCENT()
                    bne_crz = s.rv_code.len()
                    riscv64_emit_bne(s, 11, 0, 0)
                    riscv64_emit_addi(s, 10, 0, 0)
                    jmp_crz = s.rv_code.len()
                    riscv64_emit_jal(s, 0, 0)
                    riscv64_synth_patch_b(s, bne_crz, 1, 11, 0, s.rv_code.len())
                    if ca_u == 1 riscv64_emit_remu(s, 10, 10, 11) else riscv64_emit_rem(s, 10, 10, 11) end
                    riscv64_synth_patch_jal(s, jmp_crz, 0, s.rv_code.len())
                elif ca_op == TOK_SHR()
                    if ca_lv != 0 and ca_lv.rv_lv_is_uint == 1 riscv64_emit_srl(s, 10, 10, 11) else riscv64_emit_sra(s, 10, 10, 11) end
                elif ca_op == TOK_SHL()
                    riscv64_emit_sll(s, 10, 10, 11)
                elif ca_op == TOK_AMP()
                    riscv64_emit_and(s, 10, 10, 11)
                elif ca_op == TOK_BAR()
                    riscv64_emit_or(s, 10, 10, 11)
                elif ca_op == TOK_CARET()
                    riscv64_emit_xor(s, 10, 10, 11)
                end
                if ca_lv != 0
                    if riscv64_is_narrow_int_type(ca_lv.rv_lv_int_type) == 1
                        riscv64_emit_truncate_int_width(s, 10, ca_lv.rv_lv_int_type)
                    end
                    if ca_lv.rv_lv_is_boxed == 1
                        riscv64_emit_local_ld(s, 5, ca_lv.rv_lv_offset)
                        riscv64_emit_sd(s, 10, 5, 0)
                    else
                        riscv64_emit_local_sd(s, 10, ca_lv.rv_lv_offset)
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
    // Do NOT treat anonymous closure expression `fn(...)` as a top-level named function def
    if is_fn == 1 and fn_kw_pos + 1 < toks.len() and (toks[fn_kw_pos + 1].tok_kind == TOK_LPAREN() or toks[fn_kw_pos + 1].tok_text == "(")
        is_fn = 0
    end

    if is_fn == 1
        fn_base_col = fn_start_col
        fn_base_line = fn_start_line
        list_set(pos_box, 0, fn_kw_pos + 1) // Consume [async] fn
        name_pos = get(pos_box, 0)
        fn_name = ""
        eff_impl_type = s.rv_impl_type
        if name_pos < toks.len() and toks[name_pos].tok_kind == TOK_IDENT()
            fn_name = toks[name_pos].tok_text
            list_set(pos_box, 0, name_pos + 1)
            if get(pos_box, 0) + 1 < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_DOT() or toks[get(pos_box, 0)].tok_text == ".") and toks[get(pos_box, 0) + 1].tok_kind == TOK_IDENT()
                eff_impl_type = fn_name
                m_sub = toks[get(pos_box, 0) + 1].tok_text
                fn_name = eff_impl_type + "_" + m_sub
                riscv64_synth_add_impl_method(s, eff_impl_type, m_sub)
                list_set(pos_box, 0, get(pos_box, 0) + 2)
            elif eff_impl_type != ""
                riscv64_synth_add_impl_method(s, eff_impl_type, fn_name)
                fn_name = eff_impl_type + "_" + fn_name
            end
        end

        // Jump over function so top-level execution doesn't fall through into function body
        fn_jmp_patch = s.rv_code.len()
        riscv64_emit_jal(s, 0, 0) // Placeholder JAL x0, 0

        // Record function entry point (immediately after the skip jump)
        fn_entry = Riscv64Function()
        fn_entry.rv_fn_name = fn_name
        fn_entry.rv_fn_entry_offset = s.rv_code.len()
        fn_entry.rv_fn_end_offset = 0
        fn_entry.rv_fn_decl_line = fn_base_line
        push(s.rv_functions, fn_entry)

        // Save outer scope and initialize function frame locals
        saved_rv_locals = s.rv_locals
        saved_rv_stack_off = s.rv_stack_offset
        saved_rv_try_patches = s.rv_try_patches
        saved_rv_sp_delta = s.rv_sp_delta
        saved_rv_boxed = s.rv_boxed_vars
        saved_rv_ds = s.rv_defer_starts
        saved_rv_de = s.rv_defer_ends
        s.rv_locals = list()
        s.rv_stack_offset = 16
        s.rv_in_function = 1
        s.rv_cur_fn_name = fn_name
        s.rv_try_patches = list()
        s.rv_sp_delta = 0
        s.rv_defer_starts = list()
        s.rv_defer_ends = list()

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
                    // WHY: Single-line functions (`fn RV_UART0_BASE() return 268435456 end`) place their body
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
                        if riscv64_is_float_type(pt_txt) == 1
                            p_prim = "float"
                        elif pt_txt == "str" or pt_txt == "string"
                            p_prim = "str"
                        end
                        if riscv64_is_uint_type(pt_txt) == 1
                            p_uflag = 1
                        end
                        if riscv64_is_narrow_int_type(pt_txt) == 1
                            p_itype = pt_txt
                        elif riscv64_synth_find_struct(s, pt_txt) != 0
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
                // Skip optional default value `= <expr>` (evaluated at call sites via prescanned Riscv64FnSig)
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

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        fn_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or toks[get(pos_box, 0)].tok_text == "{")
            fn_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end

        // ── Direct RISC-V 64 SSA CFG Replacement (--ssa-codegen) ─────────────
        if g_rv64_ssa_codegen == 1 and s.rv_ssa_lower_res != 0 and s.rv_ssa_lower_res.slr_success == 1
            r_slr = s.rv_ssa_lower_res
            r_mi = 0 - 1
            if r_slr.slr_fn_eligible != 0
                rsfi = 0
                while rsfi < r_slr.slr_fn_names.len() and rsfi < r_slr.slr_fn_eligible.len()
                    if r_slr.slr_fn_names[rsfi] == fn_name and r_slr.slr_fn_eligible[rsfi] == 1
                        r_mi = rsfi
                        break
                    end
                    rsfi = rsfi + 1
                end
            end
            if r_mi >= 0 and r_mi < r_slr.slr_fn_offsets.len() and r_mi < r_slr.slr_fn_sizes.len()
                r_off = r_slr.slr_fn_offsets[r_mi]
                r_sz = r_slr.slr_fn_sizes[r_mi]
                r_clen = 0
                if r_slr.slr_code_buf != 0
                    r_clen = buf_len(r_slr.slr_code_buf)
                elif r_slr.slr_code != 0
                    r_clen = r_slr.slr_code.len()
                end
                if r_sz > 0 and (r_off + r_sz) <= r_clen
                    dst_r_base = s.rv_code.len()
                    if r_slr.slr_code_buf != 0
                        r_cp = buf_ptr(r_slr.slr_code_buf)
                        rbi = 0
                        while rbi < r_sz
                            push(s.rv_code, mem_byte_read(r_cp, r_off + rbi))
                            rbi = rbi + 1
                        end
                    else
                        rbi = 0
                        while rbi < r_sz
                            push(s.rv_code, r_slr.slr_code[r_off + rbi])
                            rbi = rbi + 1
                        end
                    end
                    if r_slr.slr_call_relocs != 0
                        rcri = 0
                        while rcri < r_slr.slr_call_relocs.len()
                            rjp = r_slr.slr_call_relocs[rcri]
                            if rjp.sjp_offset >= r_off and rjp.sjp_offset < (r_off + r_sz)
                                rcrel = Riscv64CallReloc()
                                rcrel.rv_cr_patch_offset = dst_r_base + (rjp.sjp_offset - r_off)
                                rcrel.rv_cr_target_name = rjp.sjp_target
                                push(s.rv_call_relocs, rcrel)
                            end
                            rcri = rcri + 1
                        end
                    end
                    if fn_braced == 1
                        rsk_d = 1
                        while get(pos_box, 0) < toks.len() and rsk_d > 0
                            rsk_t = toks[get(pos_box, 0)]
                            if rsk_t.tok_kind == TOK_LBRACE() or (rsk_t.tok_kind != TOK_STR() and rsk_t.tok_text == "{")
                                rsk_d = rsk_d + 1
                            elif rsk_t.tok_kind == TOK_RBRACE() or (rsk_t.tok_kind != TOK_STR() and rsk_t.tok_text == "}")
                                rsk_d = rsk_d - 1
                            end
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    else
                        r_sl_nest = 0
                        while get(pos_box, 0) < toks.len()
                            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
                            rsp_c = get(pos_box, 0)
                            if rsp_c >= toks.len() break end
                            rst_c = toks[rsp_c]
                            if rst_c.tok_span.span_start_line == fn_base_line and (rst_c.tok_kind == TOK_KW_IF() or rst_c.tok_kind == TOK_KW_WHILE() or rst_c.tok_kind == TOK_KW_FOR() or rst_c.tok_kind == TOK_KW_MATCH() or rst_c.tok_kind == TOK_KW_TRY())
                                r_sl_nest = r_sl_nest + 1
                            end
                            if rst_c.tok_kind == TOK_KW_END() or rst_c.tok_kind == TOK_DIR_END() or (rst_c.tok_kind == TOK_IDENT() and (rst_c.tok_text == "end" or rst_c.tok_text == "শেষ" or rst_c.tok_text == "@end"))
                                if rst_c.tok_span.span_start_col <= fn_base_col or (rst_c.tok_span.span_start_line == fn_base_line and r_sl_nest == 0)
                                    list_set(pos_box, 0, rsp_c + 1)
                                    break
                                end
                                if rst_c.tok_span.span_start_line == fn_base_line and r_sl_nest > 0
                                    r_sl_nest = r_sl_nest - 1
                                end
                            end
                            if rst_c.tok_span.span_start_line > fn_base_line and rst_c.tok_span.span_start_col <= fn_base_col
                                break
                            end
                            list_set(pos_box, 0, rsp_c + 1)
                        end
                    end
                    after_r_off = s.rv_code.len()
                    fn_entry.rv_fn_end_offset = after_r_off
                    s.rv_ssa_replaced_cnt = s.rv_ssa_replaced_cnt + 1
                    s.rv_ssa_replaced_bytes = s.rv_ssa_replaced_bytes + r_sz
                    s.rv_locals = saved_rv_locals
                    s.rv_stack_offset = saved_rv_stack_off
                    s.rv_try_patches = saved_rv_try_patches
                    s.rv_sp_delta = saved_rv_sp_delta
                    s.rv_boxed_vars = saved_rv_boxed
                    s.rv_defer_starts = saved_rv_ds
                    s.rv_defer_ends = saved_rv_de
                    s.rv_in_function = 0
                    riscv64_synth_patch_jal(s, fn_jmp_patch, 0, after_r_off)
                    return 0
                end
            end
        end

        // Prescan function body for variables mutated inside nested closures
        s.rv_boxed_vars = riscv64_prescan_boxed_vars(toks, get(pos_box, 0), fn_base_col, fn_base_line)

        // Emit function prologue
        riscv64_emit_prologue(s)

        // Save incoming argument registers (a0..a7 = x10..x17) into local stack slots first
        pi = 0
        while pi < params.len()
            pname = params[pi]
            off = riscv64_synth_alloc_var(s, pname)
            plv_u = riscv64_find_local_var(s, pname)
            p_it = ""
            if plv_u != 0 and pi < param_is_uint.len()
                plv_u.rv_lv_is_uint = param_is_uint[pi]
            end
            if plv_u != 0 and pi < param_int_types.len()
                p_it = param_int_types[pi]
                plv_u.rv_lv_int_type = p_it
            end
            if plv_u != 0 and pi < param_struct_types.len()
                plv_u.rv_lv_struct_type = param_struct_types[pi]
            end
            if plv_u != 0 and pi < param_prim_types.len()
                plv_u.rv_lv_prim_type = param_prim_types[pi]
            end
            if pi < 8
                arg_reg = 10 + pi
                if riscv64_is_narrow_int_type(p_it) == 1
                    riscv64_emit_truncate_int_width(s, arg_reg, p_it)
                end
                riscv64_emit_local_sd(s, arg_reg, off)
            else
                // RV64 LP64 stack parameter pi >= 8 sits at [s0 + (pi - 8) * 8] (s0 == sp_at_call)
                riscv64_emit_ld(s, 5, 8, (pi - 8) * 8)
                if riscv64_is_narrow_int_type(p_it) == 1
                    riscv64_emit_truncate_int_width(s, 5, p_it)
                end
                riscv64_emit_local_sd(s, 5, off)
            end
            pi = pi + 1
        // Wrap any closure-mutated parameter into a shared 8-byte heap upvalue cell
        pi = 0
        while pi < params.len()
            pname = params[pi]
            plv = riscv64_find_local_var(s, pname)
            if plv != 0 and plv.rv_lv_is_boxed == 1
                riscv64_emit_li(s, 10, 8)
                riscv64_synth_emit_call_alloc(s)
                riscv64_emit_local_ld(s, 5, plv.rv_lv_offset)
                riscv64_emit_sd(s, 5, 10, 0)
                riscv64_emit_local_sd(s, 10, plv.rv_lv_offset)
            end
            pi = pi + 1
        end

        // Parse function body statements until matching '}', explicit end, next fn, dedent, or EOF
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_pos = get(pos_box, 0)
            if cur_pos >= toks.len()
                break
            end
            ct = toks[cur_pos]
            ck_fn = ct.tok_kind
            ctx_fn = ct.tok_text
            if ck_fn == TOK_EOF()
                break
            end
            if fn_braced == 1
                if ck_fn == TOK_RBRACE() or ctx_fn == "}"
                    list_set(pos_box, 0, cur_pos + 1)
                    break
                end
            else
                if ck_fn == TOK_KW_END() or ck_fn == TOK_DIR_END() or (ck_fn == TOK_IDENT() and (ctx_fn == "end" or ctx_fn == "@end" or ctx_fn == "শেষ"))
                    list_set(pos_box, 0, cur_pos + 1)
                    break
                end
                if (ck_fn == TOK_KW_FN() or ck_fn == TOK_DIR_FN() or (ck_fn == TOK_IDENT() and (ctx_fn == "fn" or ctx_fn == "কাজ" or ctx_fn == "@fn"))) and cur_pos + 1 < toks.len() and toks[cur_pos + 1].tok_kind == TOK_IDENT()
                    break
                end
                if (ck_fn == TOK_KW_ASYNC() or (ck_fn == TOK_IDENT() and (ctx_fn == "async" or ctx_fn == "@async"))) and cur_pos + 1 < toks.len() and (toks[cur_pos + 1].tok_kind == TOK_KW_FN() or toks[cur_pos + 1].tok_kind == TOK_DIR_FN() or toks[cur_pos + 1].tok_text == "fn" or toks[cur_pos + 1].tok_text == "কাজ")
                    break
                end
                if ct.tok_span.span_start_line > fn_base_line and ct.tok_span.span_start_col <= fn_base_col
                    break
                end
            end
            bp_fn = get(pos_box, 0)
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == bp_fn
                list_set(pos_box, 0, bp_fn + 1)
            end
        end

        // Default epilogue at end of function
        riscv64_emit_addi(s, 10, 0, 0)
        riscv64_emit_addi(s, 11, 0, 0)
        riscv64_emit_defers(s, toks)
        riscv64_emit_epilogue(s)
        fn_entry.rv_fn_end_offset = s.rv_code.len()
        s.rv_locals = saved_rv_locals
        s.rv_stack_offset = saved_rv_stack_off
        s.rv_try_patches = saved_rv_try_patches
        s.rv_sp_delta = saved_rv_sp_delta
        s.rv_boxed_vars = saved_rv_boxed
        s.rv_defer_starts = saved_rv_ds
        s.rv_defer_ends = saved_rv_de
        s.rv_in_function = 0

        // Patch jump to bypass function body during top-level execution
        after_fn_offset = s.rv_code.len()
        riscv64_synth_patch_jal(s, fn_jmp_patch, 0, after_fn_offset)
        return 0

    // Default: evaluate expression or advance token
    riscv64_synth_compile_expr(s, toks, pos_box)
    return 0

