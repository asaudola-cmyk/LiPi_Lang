// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN ARM64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/arm64/codegen_stmt.lp
// ==============================================================================

// ── 8. Statement Synthesizer ──────────────────────────────────────────────────

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

        // General expression print (numbers, variables, calculations):
        arm64_synth_compile_expr(s, toks, pos_box)
        arm64_synth_emit_call_print_int(s)
        return 0

    // ── 2. Control Flow: return / ফেরত ─────────────────────────────────────────
    if k == TOK_KW_RETURN() or (k == TOK_IDENT() and (txt == "return" or txt == "ফেরত"))
        list_set(pos_box, 0, pos + 1) // Consume keyword
        next_pos = get(pos_box, 0)
        has_expr = 0
        if next_pos < toks.len()
            nt = toks[next_pos]
            if nt.tok_kind != TOK_NEWLINE() and nt.tok_kind != TOK_SEMI() and nt.tok_kind != TOK_EOF()
                has_expr = 1

        if has_expr == 1
            arm64_synth_compile_expr(s, toks, pos_box)
        else
            arm64_emit_movz_x(s, 0, 0, 0)

        if s.a64_in_function == 1
            arm64_emit_epilogue(s)
        else
            // Top-level return: exit with code in X0 via Linux SYS_exit (93)
            arm64_emit_movz_x(s, 8, 93, 0)
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

    // ── 4. Struct Definition: struct / গঠন / @struct ──────────────────────────
    is_struct = 0
    if k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT()
        is_struct = 1
    if k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct")
        is_struct = 1

    if is_struct == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'struct'

        sname_tok = toks[get(pos_box, 0)]
        sname = sname_tok.tok_text
        list_set(pos_box, 0, get(pos_box, 0) + 1)

        fields = list()
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)
                break
            if cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN() or cur_k == TOK_KW_STRUCT() or cur_k == TOK_DIR_STRUCT()
                break
            if cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "struct" or cur_txt == "গঠন")
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            if cur_k == TOK_IDENT()
                push(fields, cur_txt)
                // Skip optional type annotation: : i64
                nxt = cur_p + 1
                if nxt < toks.len() and toks[nxt].tok_kind == TOK_COLON()
                    list_set(pos_box, 0, nxt + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)

            list_set(pos_box, 0, get(pos_box, 0) + 1)

        sdef = Arm64StructDef()
        sdef.sd_name = sname
        sdef.sd_fields = fields
        push(s.synth_structs, sdef)
        return 0

    // ── 5. Struct Field Assignment: obj.field = expr ─────────────────────────────
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
            if t3.tok_kind == TOK_ASSIGN() or t3.tok_text == "="
                is_assign = 1

            if is_dot == 1 and arm64_is_ident_token(t2.tok_kind) == 1 and is_assign == 1
                obj_name = txt
                field_name = t2.tok_text
                list_set(pos_box, 0, p3 + 1) // Consume obj, '.', field, '='

                // Evaluate expr into X0
                arm64_synth_compile_expr(s, toks, pos_box)

                // Save value: push X0
                arm64_push_reg(s, 0)

                // Load obj pointer into X1
                obj_off = arm64_synth_lookup_var(s, obj_name)
                if obj_off > 0
                    arm64_emit_ldr_reg_sp(s, 1, obj_off)
                else
                    arm64_emit_movz_x(s, 1, 0, 0)

                // Pop value into X0
                arm64_pop_reg(s, 0)

                // Store value to field: str X0, [X1, #f_off]
                obj_sname = arm64_synth_get_var_struct(s, obj_name)
                f_off = arm64_synth_get_field_offset(s, obj_sname, field_name)
                scaled_fo = (f_off / 8) & 4095
                st_word = 4177526784 | (scaled_fo << 10) | (1 << 5) | 0
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
                arm64_synth_compile_expr(s, toks, pos_box) // X0 = rhs
                arm64_push_reg(s, 0)
                arr_off = arm64_synth_lookup_var(s, arr_name)
                if arr_off > 0
                    arm64_emit_ldr_reg_sp(s, 0, arr_off) // X0 = hdr
                    arm64_synth_emit32(s, 4181723139)    // ldr x3, [x0, #16] (data_ptr)
                    arm64_pop_reg(s, 2)                  // X2 = val
                    arm64_pop_reg(s, 1)                  // X1 = idx
                    arm64_emit_add_x(s, 1, 1, 1)
                    arm64_emit_add_x(s, 1, 1, 1)
                    arm64_emit_add_x(s, 1, 1, 1)
                    arm64_emit_add_x(s, 3, 3, 1)         // &data[idx]
                    arm64_synth_emit32(s, 4177526882)    // str x2, [x3, #0]
                else
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

        // Compile then-block statements
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

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

            if cur_t.tok_span.span_start_line == base_line
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

            while get(pos_box, 0) < toks.len()
                arm64_synth_skip_whitespace_tokens(toks, pos_box)
                cur_p2 = get(pos_box, 0)
                if cur_p2 >= toks.len()
                    break
                ct2 = toks[cur_p2]
                ck2 = ct2.tok_kind
                cx2 = ct2.tok_text
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
                if ct2.tok_span.span_start_line == elif_line
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
                while get(pos_box, 0) < toks.len()
                    arm64_synth_skip_whitespace_tokens(toks, pos_box)
                    cur_p3 = get(pos_box, 0)
                    if cur_p3 >= toks.len()
                        break
                    ct3 = toks[cur_p3]
                    ck3 = ct3.tok_kind
                    cx3 = ct3.tok_text
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
                    if ct3.tok_span.span_start_line == else_line
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

        // Compile while body statements
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            b_p = get(pos_box, 0)
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if cur_t.tok_span.span_start_line == base_line
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

        // Compile start expression into X0
        arm64_synth_compile_expr(s, toks, pos_box)
        var_off = arm64_synth_alloc_var(s, var_name)
        arm64_emit_str_reg_sp(s, 0, var_off)

        // Consume '..' if present
        if get(pos_box, 0) < toks.len()
            dot_t = toks[get(pos_box, 0)]
            if dot_t.tok_kind == TOK_DOTDOT() or dot_t.tok_text == ".."
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile end expression into X0
        arm64_synth_compile_expr(s, toks, pos_box)
        end_var_name = "__end_" + var_name
        end_off = arm64_synth_alloc_var(s, end_var_name)
        arm64_emit_str_reg_sp(s, 0, end_off)

        loop_header = s.synth_code.len()
        push(s.synth_loop_starts, 0 - 1)
        loop_brks = list()
        push(s.synth_loop_breaks, loop_brks)
        for_conts = list()
        push(s.a64_for_conts, for_conts)

        // Compare var and end: ldr x0, [sp, #var_off]; ldr x1, [sp, #end_off]; cmp x0, x1
        arm64_emit_ldr_reg_sp(s, 0, var_off)
        arm64_emit_ldr_reg_sp(s, 1, end_off)
        arm64_emit_cmp_x(s, 0, 1)

        // b.gt loop_exit (cond=12: exit if var > end — inclusive a..b)
        patch_loop_exit = s.synth_code.len()
        arm64_emit_b_cond(s, 12, 0)

        arm64_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile for body statements
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            b_p = get(pos_box, 0)
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if cur_t.tok_span.span_start_line == base_line
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

        // Increment var: ldr x0, [sp, #var_off]; mov x1, 1; add x0, x0, x1; str x0, [sp, #var_off]
        arm64_emit_ldr_reg_sp(s, 0, var_off)
        arm64_emit_movz_x(s, 1, 1, 0)
        arm64_emit_add_x(s, 0, 0, 1)
        arm64_emit_str_reg_sp(s, 0, var_off)

        // b loop_header
        cur_off = s.synth_code.len()
        rel_words = (loop_header - cur_off) / 4
        arm64_emit_b(s, rel_words)

        // Backpatch loop_exit (b.gt cond=12)
        loop_exit_off = s.synth_code.len()
        exit_words = (loop_exit_off - patch_loop_exit) / 4
        arm64_synth_patch_u32(s, patch_loop_exit, 1409286144 | ((exit_words & 524287) << 5) | 12)

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

        end_patches = list()
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cp_m = get(pos_box, 0)
            if cp_m >= toks.len()
                break
            ct_m = toks[cp_m]
            ck_m = ct_m.tok_kind
            cx_m = ct_m.tok_text
            if ck_m == TOK_EOF() or ck_m == TOK_KW_END() or ck_m == TOK_DIR_END() or (ck_m == TOK_IDENT() and (cx_m == "end" or cx_m == "শেষ" or cx_m == "@end"))
                break
            if ct_m.tok_span.span_start_line > base_line and ct_m.tok_span.span_start_col <= base_col
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
                arm64_synth_compile_expr(s, toks, pos_box)
                if get(pos_box, 0) < toks.len()
                    sep_k2 = toks[get(pos_box, 0)].tok_kind
                    sep_t2 = toks[get(pos_box, 0)].tok_text
                    if sep_k2 == TOK_FAT_ARROW() or sep_k2 == TOK_COLON() or sep_k2 == TOK_ARROW() or sep_t2 == "=>" or sep_t2 == ":" or sep_t2 == "->"
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                arm64_emit_ldr_reg_sp(s, 1, m_off)
                arm64_emit_cmp_x(s, 1, 0)
                patch_miss = s.synth_code.len()
                arm64_emit_b_cond(s, 1, 0) // b.ne miss

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
                        if ck_b == TOK_KW_CASE() or ck_b == TOK_KW_ELSE() or ck_b == TOK_DIR_ELSE() or ck_b == TOK_KW_END() or ck_b == TOK_DIR_END()
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
        arm64_emit_movz_x(s, 27, 1, 0)
        if s.a64_try_patches.len() > 0
            p_off = s.synth_code.len()
            arm64_emit_b(s, 0)
            active_tp = s.a64_try_patches[s.a64_try_patches.len() - 1]
            push(active_tp, [p_off, 0])
        elif s.a64_in_function == 1
            arm64_emit_epilogue(s)
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
            if ck_t == TOK_EOF() or ck_t == TOK_KW_CATCH() or ck_t == TOK_DIR_CATCH() or ck_t == TOK_KW_END() or ck_t == TOK_DIR_END()
                break
            if ck_t == TOK_IDENT() and (cx_t == "catch" or cx_t == "ধরো" or cx_t == "@catch" or cx_t == "end" or cx_t == "শেষ" or cx_t == "@end")
                break
            if ct_t.tok_span.span_start_line > base_line and ct_t.tok_span.span_start_col <= base_col
                break
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

        // Restore SP = X29 - 2048 so mid-expression unwinds keep stack slot layout intact, then clear X27
        arm64_synth_emit32(s, 3508536255)
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

                if catch_var != ""
                    cv_off = arm64_synth_alloc_var(s, catch_var)
                    arm64_emit_str_reg_sp(s, 28, cv_off)

                while get(pos_box, 0) < toks.len()
                    arm64_synth_skip_whitespace_tokens(toks, pos_box)
                    cp_cb = get(pos_box, 0)
                    if cp_cb >= toks.len()
                        break
                    ct_cb = toks[cp_cb]
                    ck_cb = ct_cb.tok_kind
                    cx_cb = ct_cb.tok_text
                    if ck_cb == TOK_EOF() or ck_cb == TOK_KW_END() or ck_cb == TOK_DIR_END()
                        break
                    if ck_cb == TOK_IDENT() and (cx_cb == "end" or cx_cb == "শেষ" or cx_cb == "@end")
                        break
                    if ct_cb.tok_span.span_start_line > catch_line and ct_cb.tok_span.span_start_col <= base_col
                        break
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
        if var_pos < toks.len() and toks[var_pos].tok_kind == TOK_IDENT()
            var_name = toks[var_pos].tok_text
            list_set(pos_box, 0, var_pos + 1)
            eq_pos = get(pos_box, 0)
            if eq_pos < toks.len() and toks[eq_pos].tok_kind == TOK_ASSIGN()
                list_set(pos_box, 0, eq_pos + 1)
                s.a64_last_struct = ""
                arm64_synth_compile_expr(s, toks, pos_box)
                off = arm64_synth_alloc_var(s, var_name)
                arm64_emit_str_reg_sp(s, 0, off)
                arm64_synth_set_var_struct(s, var_name, s.a64_last_struct)
        return 0

    // ── 10. Assignment: <var> = <expr> ─────────────────────────────────────────
    if k == TOK_IDENT()
        next_pos = pos + 1
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_ASSIGN()
            var_name = txt
            list_set(pos_box, 0, next_pos + 1) // Consume ident and '='
            s.a64_last_struct = ""
            arm64_synth_compile_expr(s, toks, pos_box)
            off = arm64_synth_alloc_var(s, var_name)
            arm64_emit_str_reg_sp(s, 0, off)
            arm64_synth_set_var_struct(s, var_name, s.a64_last_struct)
            return 0

    // ── 11. Function & Component Definition: fn / কাজ / @fn / component / উপাদান ──
    is_fn = 0
    if k == TOK_KW_FN() or k == TOK_DIR_FN() or k == TOK_KW_COMPONENT()
        is_fn = 1
    if k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn" or txt == "component" or txt == "উপাদান")
        is_fn = 1

    if is_fn == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume fn
        name_pos = get(pos_box, 0)
        fn_name = ""
        if name_pos < toks.len() and toks[name_pos].tok_kind == TOK_IDENT()
            fn_name = toks[name_pos].tok_text
            list_set(pos_box, 0, name_pos + 1)

        // Jump over function so top-level execution doesn't fall through into function body
        fn_jmp_patch = s.synth_code.len()
        arm64_emit_b(s, 0) // Placeholder

        // Record function entry point (immediately after the skip jump)
        fn_entry = Arm64Function()
        fn_entry.fn_name = fn_name
        fn_entry.fn_entry_offset = s.synth_code.len()
        push(s.synth_functions, fn_entry)

        // Save enclosing scope (e.g. top-level _start locals) and reset function frame locals
        saved_arm_locals = s.synth_locals
        saved_arm_stack_off = s.synth_stack_offset
        saved_arm_sp_delta = s.a64_sp_delta
        saved_arm_try_patches = s.a64_try_patches
        s.synth_locals = list()
        s.synth_stack_offset = 16
        s.a64_sp_delta = 0
        s.a64_in_function = 1
        s.a64_try_patches = list()

        // Parse parameter names until newline or return arrow
        params = list()
        while get(pos_box, 0) < toks.len()
            p_tok = toks[get(pos_box, 0)]
            if p_tok.tok_kind == TOK_NEWLINE() or p_tok.tok_kind == TOK_SEMI()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                break
            if p_tok.tok_kind == TOK_ARROW() or (p_tok.tok_kind != TOK_STR() and p_tok.tok_text == "->")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                break
            if p_tok.tok_kind == TOK_IDENT()
                pname = p_tok.tok_text
                push(params, pname)
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                // Skip optional type annotation: : type
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ":"))
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                end
            else
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end

        // Emit function prologue
        arm64_emit_prologue(s)

        // Save incoming argument registers (X0..X7) into local stack slots
        pi = 0
        while pi < params.len()
            pname = params[pi]
            off = arm64_synth_alloc_var(s, pname)
            if pi < 8
                arm64_emit_str_reg_sp(s, pi, off)
            pi = pi + 1

        arm64_synth_skip_whitespace_tokens(toks, pos_box)

        // Parse function body statements until next function, explicit end, or column indentation drop
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_pos = get(pos_box, 0)
            if cur_pos >= toks.len()
                break
            ct = toks[cur_pos]
            cur_k = ct.tok_kind
            cur_txt = ct.tok_text
            if cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN()
                break
            if cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "@fn")
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
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len()
            ct = toks[cur_pos]
            cur_k = ct.tok_kind
            cur_txt = ct.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_pos + 1)

        // Default epilogue at end of function
        arm64_emit_movz_x(s, 0, 0, 0)
        arm64_emit_epilogue(s)
        s.synth_locals = saved_arm_locals
        s.synth_stack_offset = saved_arm_stack_off
        s.a64_sp_delta = saved_arm_sp_delta
        s.a64_in_function = 0
        s.a64_try_patches = saved_arm_try_patches

        // Patch jump to bypass function body during top-level execution
        after_fn_offset = s.synth_code.len()
        rel_words = (after_fn_offset - fn_jmp_patch) / 4
        arm64_synth_patch_u32(s, fn_jmp_patch, 335544320 | (rel_words & 67108863))
        return 0

    // Default: evaluate expression or advance token
    arm64_synth_compile_expr(s, toks, pos_box)
    return 0

