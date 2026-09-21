// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN RISC-V 64 (RV64G) MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/riscv64/codegen_stmt.lp
// ==============================================================================

// ── 11. Statement Synthesizer ─────────────────────────────────────────────────

fn riscv64_synth_compile_statement s toks pos_box
    // WHY: Synthesizes execution bytes for statements (control flow, structs, loops, calls).
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
                riscv64_emit_print_string(s, next_tok.tok_text)
                return 0

        // General expression print (numbers, variables, calculations):
        riscv64_synth_compile_expr(s, toks, pos_box)
        riscv64_synth_emit_call_print_int(s)
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
            riscv64_synth_compile_expr(s, toks, pos_box)
        else
            riscv64_emit_addi(s, 10, 0, 0)

        if s.rv_in_function == 1
            riscv64_emit_epilogue(s)
        else
            // Top-level return: exit with code in a0 via Linux SYS_exit (93)
            riscv64_emit_li(s, 17, 93)
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
            cur_off = s.rv_code.len()
            rel_bytes = loop_hdr - cur_off
            riscv64_emit_jal(s, 0, rel_bytes)
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
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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

        sdef = Riscv64StructDef()
        sdef.rv_sd_name = sname
        sdef.rv_sd_fields = fields
        push(s.rv_structs, sdef)
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

            if is_dot == 1 and t2.tok_kind == TOK_IDENT() and is_assign == 1
                obj_name = txt
                field_name = t2.tok_text
                list_set(pos_box, 0, p3 + 1) // Consume obj, '.', field, '='

                // Evaluate expr into a0
                riscv64_synth_compile_expr(s, toks, pos_box)

                // Save value: push a0
                riscv64_push_reg(s, 10)

                // Load obj pointer into a1
                obj_off = riscv64_synth_lookup_var(s, obj_name)
                if obj_off > 0
                    riscv64_emit_ld(s, 11, 2, obj_off)
                else
                    riscv64_emit_addi(s, 11, 0, 0)

                // Pop value into a0
                riscv64_pop_reg(s, 10)

                // Store value to field: sd a0, f_off(a1)
                f_off = riscv64_synth_get_field_offset(s, "", field_name)
                riscv64_emit_sd(s, 10, 11, f_off)
                return 0

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

        // Compile then-block statements
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == before_stmt_p
                list_set(pos_box, 0, before_stmt_p + 1)

            if cur_t.tok_span.span_start_line == base_line
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

            while get(pos_box, 0) < toks.len()
                riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                riscv64_synth_compile_statement(s, toks, pos_box)
                if get(pos_box, 0) == b_p2
                    list_set(pos_box, 0, b_p2 + 1)
                if ct2.tok_span.span_start_line == elif_line
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
                while get(pos_box, 0) < toks.len()
                    riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
                    riscv64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p3
                        list_set(pos_box, 0, b_p3 + 1)
                    if ct3.tok_span.span_start_line == else_line
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

        // Evaluate condition into a0
        riscv64_synth_compile_expr(s, toks, pos_box)

        // beq a0, x0, loop_exit
        patch_loop_exit = s.rv_code.len()
        riscv64_emit_beq(s, 10, 0, 0) // Placeholder

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile while body statements
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if cur_t.tok_span.span_start_line == base_line
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

        // Compile start expression into a0
        riscv64_synth_compile_expr(s, toks, pos_box)
        var_off = riscv64_synth_alloc_var(s, var_name)
        riscv64_emit_sd(s, 10, 2, var_off)

        // Consume '..' if present
        if get(pos_box, 0) < toks.len()
            dot_t = toks[get(pos_box, 0)]
            if dot_t.tok_kind == TOK_DOTDOT() or dot_t.tok_text == ".."
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile end expression into a0
        riscv64_synth_compile_expr(s, toks, pos_box)
        end_var_name = "__end_" + var_name
        end_off = riscv64_synth_alloc_var(s, end_var_name)
        riscv64_emit_sd(s, 10, 2, end_off)

        loop_header = s.rv_code.len()
        push(s.rv_loop_starts, loop_header)
        loop_brks = list()
        push(s.rv_loop_breaks, loop_brks)

        // Compare var and end: ld a0, var_off(sp); ld a1, end_off(sp); bge a0, a1, loop_exit
        riscv64_emit_ld(s, 10, 2, var_off)
        riscv64_emit_ld(s, 11, 2, end_off)

        // bge a0, a1, loop_exit (exit if var >= end)
        patch_loop_exit = s.rv_code.len()
        riscv64_emit_bge(s, 10, 11, 0)

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile for body statements
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
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
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if cur_t.tok_span.span_start_line == base_line
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

        // Increment var: ld a0, var_off(sp); addi a0, a0, 1; sd a0, var_off(sp)
        riscv64_emit_ld(s, 10, 2, var_off)
        riscv64_emit_addi(s, 10, 10, 1)
        riscv64_emit_sd(s, 10, 2, var_off)

        // jal x0, loop_header
        cur_off = s.rv_code.len()
        rel_bytes = loop_header - cur_off
        riscv64_emit_jal(s, 0, rel_bytes)

        // Backpatch loop_exit
        loop_exit_off = s.rv_code.len()
        riscv64_synth_patch_b(s, patch_loop_exit, 5, 10, 11, loop_exit_off)

        // Backpatch breaks
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            riscv64_synth_patch_jal(s, brk_patch, 0, loop_exit_off)
            bi = bi + 1

        s.rv_loop_starts = pop(s.rv_loop_starts)
        s.rv_loop_breaks = pop(s.rv_loop_breaks)
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
                riscv64_synth_compile_expr(s, toks, pos_box)
                off = riscv64_synth_alloc_var(s, var_name)
                riscv64_emit_sd(s, 10, 2, off)
        return 0

    // ── 10. Assignment: <var> = <expr> ─────────────────────────────────────────
    if k == TOK_IDENT()
        next_pos = pos + 1
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_ASSIGN()
            var_name = txt
            list_set(pos_box, 0, next_pos + 1) // Consume ident and '='
            riscv64_synth_compile_expr(s, toks, pos_box)
            off = riscv64_synth_alloc_var(s, var_name)
            riscv64_emit_sd(s, 10, 2, off)
            return 0

    // ── 11. Function Definition: fn / কাজ / @fn ────────────────────────────────
    is_fn = 0
    if k == TOK_KW_FN() or k == TOK_DIR_FN()
        is_fn = 1
    if k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn")
        is_fn = 1

    if is_fn == 1
        list_set(pos_box, 0, pos + 1) // Consume fn
        name_pos = get(pos_box, 0)
        fn_name = ""
        if name_pos < toks.len() and toks[name_pos].tok_kind == TOK_IDENT()
            fn_name = toks[name_pos].tok_text
            list_set(pos_box, 0, name_pos + 1)

        // Jump over function so top-level execution doesn't fall through into function body
        fn_jmp_patch = s.rv_code.len()
        riscv64_emit_jal(s, 0, 0) // Placeholder JAL x0, 0

        // Record function entry point (immediately after the skip jump)
        fn_entry = Riscv64Function()
        fn_entry.rv_fn_name = fn_name
        fn_entry.rv_fn_entry_offset = s.rv_code.len()
        push(s.rv_functions, fn_entry)

        // Reset frame locals
        s.rv_locals = list()
        s.rv_stack_offset = 16
        s.rv_in_function = 1

        // Parse parameter names until newline
        params = list()
        while get(pos_box, 0) < toks.len()
            p_tok = toks[get(pos_box, 0)]
            if p_tok.tok_kind == TOK_NEWLINE() or p_tok.tok_kind == TOK_SEMI()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                break
            if p_tok.tok_kind == TOK_IDENT()
                push(params, p_tok.tok_text)
            list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Emit function prologue
        riscv64_emit_prologue(s)

        // Save incoming argument registers (a0..a7 = x10..x17) into local stack slots
        pi = 0
        while pi < params.len()
            pname = params[pi]
            off = riscv64_synth_alloc_var(s, pname)
            if pi < 8
                arg_reg = 10 + pi
                riscv64_emit_sd(s, arg_reg, 2, off)
            pi = pi + 1

        // Parse function body statements until next function or EOF
        while get(pos_box, 0) < toks.len()
            cur_pos = get(pos_box, 0)
            ct = toks[cur_pos]
            if ct.tok_kind == TOK_KW_FN() or ct.tok_kind == TOK_DIR_FN()
                break
            if ct.tok_kind == TOK_IDENT() and (ct.tok_text == "fn" or ct.tok_text == "কাজ" or ct.tok_text == "@fn")
                break
            riscv64_synth_compile_statement(s, toks, pos_box)

        // Default epilogue at end of function
        riscv64_emit_addi(s, 10, 0, 0)
        riscv64_emit_epilogue(s)
        s.rv_in_function = 0

        // Patch jump to bypass function body during top-level execution
        after_fn_offset = s.rv_code.len()
        riscv64_synth_patch_jal(s, fn_jmp_patch, 0, after_fn_offset)
        return 0

    // Default: evaluate expression or advance token
    riscv64_synth_compile_expr(s, toks, pos_box)
    return 0

