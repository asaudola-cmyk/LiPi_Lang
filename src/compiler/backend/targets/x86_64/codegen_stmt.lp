// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/x86_64/codegen_stmt.lp
// ==============================================================================

// ── 7. Statement Synthesizer ──────────────────────────────────────────────────

fn x86_synth_compile_statement s toks pos_box
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
    if x86_synth_is_block_end(toks, pos) == 1
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
                x86_synth_emit_print_string(s, next_tok.tok_text)
                return 0

        // General dynamic expression print (strings, numbers, variables, calculations):
        x86_synth_compile_expr(s, toks, pos_box)
        // mov rdi, rax (0x48 0x89 0xC7)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 137)
        x86_synth_emit_byte(s, 199)
        x86_synth_emit_call_helper(s, "_lipi_print_dynamic")
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
            x86_synth_compile_expr(s, toks, pos_box)
        else
            // Default 0 return
            x86_synth_emit_byte(s, 49)
            x86_synth_emit_byte(s, 192)

        x86_synth_emit_epilogue(s)
        return 0

    // ── 3. Loop Control: break / থামো & continue / চলুক ───────────────────────
    if k == TOK_KW_BREAK() or (k == TOK_IDENT() and (txt == "break" or txt == "থামো"))
        list_set(pos_box, 0, pos + 1)
        if s.synth_loop_breaks.len() > 0
            x86_synth_emit_byte(s, 233) // jmp rel32
            p_off = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            curr_brk_list = s.synth_loop_breaks[s.synth_loop_breaks.len() - 1]
            push(curr_brk_list, p_off)
        return 0

    if k == TOK_KW_CONTINUE() or (k == TOK_IDENT() and (txt == "continue" or txt == "চলুক" or txt == "চলো"))
        list_set(pos_box, 0, pos + 1)
        if s.synth_loop_starts.len() > 0
            loop_hdr = s.synth_loop_starts[s.synth_loop_starts.len() - 1]
            x86_synth_emit_byte(s, 233) // jmp rel32
            next_ip = s.synth_code.len() + 4
            disp32 = loop_hdr - next_ip
            x86_synth_emit_u32(s, disp32)
        return 0

    // ── 4. Struct Definition: struct / গঠন / @struct ──────────────────────────
    is_struct = 0
    if k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT()
        is_struct = 1
    if k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct")
        is_struct = 1

    if is_struct == 1
        return x86_synth_compile_struct_def(s, toks, pos_box, t.tok_span.span_start_col, t.tok_span.span_start_line)

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
            if t1.tok_kind == TOK_DOT() or (t1.tok_kind != TOK_STR() and t1.tok_text == ".")
                is_dot = 1
            is_assign = 0
            if t3.tok_kind == TOK_ASSIGN() or (t3.tok_kind != TOK_STR() and t3.tok_text == "=")
                is_assign = 1

            if is_dot == 1 and t2.tok_kind == TOK_IDENT() and is_assign == 1
                obj_name = txt
                field_name = t2.tok_text
                list_set(pos_box, 0, p3 + 1) // Consume obj, '.', field, '='

                // Evaluate expr into %rax
                x86_synth_compile_expr(s, toks, pos_box)

                // Save value: push rax
                x86_synth_emit_byte(s, 80)

                // Load obj pointer into %rcx
                obj_off = x86_synth_lookup_var(s, obj_name)
                if obj_off > 0
                    x86_synth_emit_load_var(s, 1, obj_off)
                else
                    // mov rcx, 0
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 49)
                    x86_synth_emit_byte(s, 201)

                // Pop value into %rax
                x86_synth_emit_byte(s, 88)

                // Store value to field: mov [rcx + f_off], rax
                stype = x86_synth_get_var_type(s, obj_name)
                f_off = x86_synth_get_field_offset(s, stype, field_name)
                if f_off < 128
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 65)
                    x86_synth_emit_byte(s, f_off)
                else
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 129)
                    x86_synth_emit_u32(s, f_off)

                return 0

    // ── 5b. Array Indexing Assignment: arr[idx] = expr ───────────────────────────
    if k == TOK_IDENT() and pos + 1 < toks.len()
        nt1 = toks[pos + 1]
        if nt1.tok_kind == TOK_LBRACKET() or (nt1.tok_kind != TOK_STR() and nt1.tok_text == "[")
            arr_name = txt
            is_arr_assign = 0
            scan_p = pos + 1
            b_depth = 0
            while scan_p < toks.len()
                st = toks[scan_p]
                if st.tok_kind == TOK_LBRACKET() or (st.tok_kind != TOK_STR() and st.tok_text == "[")
                    b_depth = b_depth + 1
                elif st.tok_kind == TOK_RBRACKET() or (st.tok_kind != TOK_STR() and st.tok_text == "]")
                    b_depth = b_depth - 1
                    if b_depth == 0
                        next_p = scan_p + 1
                        while next_p < toks.len() and (toks[next_p].tok_kind == TOK_NEWLINE() or toks[next_p].tok_kind == TOK_SEMI())
                            next_p = next_p + 1
                        if next_p < toks.len()
                            nt = toks[next_p]
                            if nt.tok_kind == TOK_ASSIGN() or (nt.tok_kind != TOK_STR() and nt.tok_text == "=")
                                is_arr_assign = 1
                        break
                scan_p = scan_p + 1

            if is_arr_assign == 1
                list_set(pos_box, 0, pos + 2) // Consume arr_name and '['
                x86_synth_compile_expr(s, toks, pos_box) // rax = idx
                x86_synth_emit_byte(s, 80) // push rax (push idx)
                // Consume ']'
                cp = get(pos_box, 0)
                if cp < toks.len() and (toks[cp].tok_kind == TOK_RBRACKET() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "]"))
                    list_set(pos_box, 0, cp + 1)
                // Consume '='
                cp = get(pos_box, 0)
                if cp < toks.len() and (toks[cp].tok_kind == TOK_ASSIGN() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "="))
                    list_set(pos_box, 0, cp + 1)
                x86_synth_compile_expr(s, toks, pos_box) // rax = val
                // Set up registers for _lipi_list_set:
                // rdx = val, rsi = idx, rdi = list_ptr
                x86_synth_emit_byte(s, 72) // mov rdx, rax (0x48 0x89 0xC2)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 194)
                x86_synth_emit_byte(s, 94)  // pop rsi (idx)
                off = x86_synth_lookup_var(s, arr_name)
                if off > 0
                    x86_synth_emit_load_var(s, 7, off)
                else
                    // mov rdi, 0
                    x86_synth_emit_byte(s, 49)
                    x86_synth_emit_byte(s, 255)
                x86_synth_emit_call_helper(s, "_lipi_list_set")
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

        // Evaluate conditional expression into %rax
        x86_synth_compile_expr(s, toks, pos_box)

        // Emit test rax, rax
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 133)
        x86_synth_emit_byte(s, 192)

        // Emit jz next_branch
        x86_synth_emit_byte(s, 15)
        x86_synth_emit_byte(s, 132)
        patch_next_branch = s.synth_code.len()
        x86_synth_emit_u32(s, 0)

        end_patches = list()

        x86_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile then-block statements
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            // Check if we hit elif, else, or end
            if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()
                break
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else")
                break
            if x86_synth_is_block_end(toks, cur_p) == 1
                break

            // Indentation check: statement on subsequent line with column <= base_col marks block end
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            before_stmt_p = get(pos_box, 0)
            x86_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == before_stmt_p
                list_set(pos_box, 0, before_stmt_p + 1)

            if cur_t.tok_span.span_start_line == base_line
                break

        // Check if there is an elif or else coming next
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        has_subsequent = 0
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if (cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()) and (cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
                has_subsequent = 1
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else") and (cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
                has_subsequent = 1

        if has_subsequent == 1
            x86_synth_emit_byte(s, 233)
            jmp_end = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            push(end_patches, jmp_end)

            cur_off = s.synth_code.len()
            rel32 = cur_off - (patch_next_branch + 4)
            x86_synth_patch_u32(s, patch_next_branch, rel32)
        else
            cur_off = s.synth_code.len()
            rel32 = cur_off - (patch_next_branch + 4)
            x86_synth_patch_u32(s, patch_next_branch, rel32)

        // Loop over elif branches
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            is_elif = 0
            if (cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF()) and (cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
                is_elif = 1
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif") and (cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
                is_elif = 1
            if is_elif == 0
                break

            elif_line = cur_t.tok_span.span_start_line
            list_set(pos_box, 0, cur_p + 1) // Consume 'elif'
            x86_synth_compile_expr(s, toks, pos_box)

            // Emit test rax, rax
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 133)
            x86_synth_emit_byte(s, 192)

            // Emit jz next_branch
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 132)
            patch_next_branch = s.synth_code.len()
            x86_synth_emit_u32(s, 0)

            x86_synth_skip_whitespace_tokens(toks, pos_box)

            // Compile elif body
            while get(pos_box, 0) < toks.len()
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cur_p2 = get(pos_box, 0)
                if cur_p2 >= toks.len()
                    break
                ct2 = toks[cur_p2]
                ck2 = ct2.tok_kind
                cx2 = ct2.tok_text
                if ck2 == TOK_KW_ELIF() or ck2 == TOK_DIR_ELIF() or ck2 == TOK_KW_ELSE() or ck2 == TOK_DIR_ELSE()
                    break
                if ck2 == TOK_IDENT() and (cx2 == "elif" or cx2 == "নাহলে_যদি" or cx2 == "@elif" or cx2 == "else" or cx2 == "নাহলে" or cx2 == "@else")
                    break
                if x86_synth_is_block_end(toks, cur_p2) == 1
                    break
                if ct2.tok_span.span_start_line > elif_line and ct2.tok_span.span_start_col <= base_col
                    break
                b_p2 = get(pos_box, 0)
                x86_synth_compile_statement(s, toks, pos_box)
                if get(pos_box, 0) == b_p2
                    list_set(pos_box, 0, b_p2 + 1)
                if ct2.tok_span.span_start_line == elif_line
                    break

            // Jump to end of if
            x86_synth_emit_byte(s, 233)
            jmp_end = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            push(end_patches, jmp_end)

            // Patch this elif's jz to next branch
            cur_off = s.synth_code.len()
            rel32 = cur_off - (patch_next_branch + 4)
            x86_synth_patch_u32(s, patch_next_branch, rel32)

        // Check for else
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            is_else = 0
            if (cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()) and (cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
                is_else = 1
            if cur_k == TOK_IDENT() and (cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else") and (cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
                is_else = 1
            if is_else == 1
                else_line = cur_t.tok_span.span_start_line
                list_set(pos_box, 0, cur_p + 1) // Consume 'else'
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    cur_p3 = get(pos_box, 0)
                    if cur_p3 >= toks.len()
                        break
                    ct3 = toks[cur_p3]
                    ck3 = ct3.tok_kind
                    cx3 = ct3.tok_text
                    if x86_synth_is_block_end(toks, cur_p3) == 1
                        break
                    if ct3.tok_span.span_start_line > else_line and ct3.tok_span.span_start_col <= base_col
                        break
                    b_p3 = get(pos_box, 0)
                    x86_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p3
                        list_set(pos_box, 0, b_p3 + 1)
                    if ct3.tok_span.span_start_line == else_line
                        break

        // Consume optional end / @end / শেষ
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            if x86_synth_is_block_end(toks, cur_p) == 1
                list_set(pos_box, 0, cur_p + 1)

        // Backpatch all exit jumps to current offset
        cur_off = s.synth_code.len()
        ei = 0
        while ei < end_patches.len()
            p_end = end_patches[ei]
            rel32 = cur_off - (p_end + 4)
            x86_synth_patch_u32(s, p_end, rel32)
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

        // Evaluate condition into %rax
        x86_synth_compile_expr(s, toks, pos_box)

        // Emit test rax, rax
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 133)
        x86_synth_emit_byte(s, 192)

        // Emit jz loop_exit (0x0F 0x84 disp32)
        x86_synth_emit_byte(s, 15)
        x86_synth_emit_byte(s, 132)
        patch_loop_exit = s.synth_code.len()
        x86_synth_emit_u32(s, 0)

        x86_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile while body statements
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if x86_synth_is_block_end(toks, cur_p) == 1
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            b_p = get(pos_box, 0)
            x86_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            if x86_synth_is_block_end(toks, cur_p) == 1
                list_set(pos_box, 0, cur_p + 1)

        // Emit backward jump to loop_header: jmp rel32 (0xE9 disp32)
        x86_synth_emit_byte(s, 233)
        next_ip = s.synth_code.len() + 4
        disp32 = loop_header - next_ip
        x86_synth_emit_u32(s, disp32)

        // Backpatch loop_exit
        loop_exit_off = s.synth_code.len()
        rel32 = loop_exit_off - (patch_loop_exit + 4)
        x86_synth_patch_u32(s, patch_loop_exit, rel32)

        // Backpatch all break jumps
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            b_rel32 = loop_exit_off - (brk_patch + 4)
            x86_synth_patch_u32(s, brk_patch, b_rel32)
            bi = bi + 1

        s.synth_loop_starts = pop(s.synth_loop_starts)
        s.synth_loop_breaks = pop(s.synth_loop_breaks)
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

        // Compile start expression into %rax
        x86_synth_compile_expr(s, toks, pos_box)
        var_off = x86_synth_alloc_var(s, var_name)
        x86_synth_emit_store_var(s, 0, var_off)

        // Consume '..' if present
        if get(pos_box, 0) < toks.len()
            dot_t = toks[get(pos_box, 0)]
            if dot_t.tok_kind == TOK_DOTDOT() or (dot_t.tok_kind != TOK_STR() and dot_t.tok_text == "..")
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile end expression into %rax
        x86_synth_compile_expr(s, toks, pos_box)
        end_var_name = "__end_" + var_name
        end_off = x86_synth_alloc_var(s, end_var_name)
        x86_synth_emit_store_var(s, 0, end_off)

        loop_header = s.synth_code.len()
        push(s.synth_loop_starts, loop_header)
        loop_brks = list()
        push(s.synth_loop_breaks, loop_brks)

        // Compare var and end: mov rax, [rbp - var_off]; cmp rax, [rbp - end_off]
        x86_synth_emit_load_var(s, 0, var_off)

        // cmp rax, [rbp - end_off]
        if end_off <= 128
            disp8 = (256 - (end_off % 256)) % 256
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 59)
            x86_synth_emit_byte(s, 69)
            x86_synth_emit_byte(s, disp8)
        else
            disp32 = 0 - end_off
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 59)
            x86_synth_emit_byte(s, 133)
            x86_synth_emit_u32(s, disp32)

        // jg loop_exit (0x0F 0x8F disp32) — inclusive range [start..end]
        x86_synth_emit_byte(s, 15)
        x86_synth_emit_byte(s, 143)
        patch_loop_exit = s.synth_code.len()
        x86_synth_emit_u32(s, 0)

        x86_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile for body statements
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if x86_synth_is_block_end(toks, cur_p) == 1
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            b_p = get(pos_box, 0)
            x86_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            if x86_synth_is_block_end(toks, cur_p) == 1
                list_set(pos_box, 0, cur_p + 1)

        // Increment var: mov rax, [rbp - var_off]; inc rax; mov [rbp - var_off], rax
        x86_synth_emit_load_var(s, 0, var_off)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 255)
        x86_synth_emit_byte(s, 192) // inc rax
        x86_synth_emit_store_var(s, 0, var_off)

        // jmp loop_header
        x86_synth_emit_byte(s, 233)
        next_ip = s.synth_code.len() + 4
        disp32 = loop_header - next_ip
        x86_synth_emit_u32(s, disp32)

        // Backpatch loop_exit
        loop_exit_off = s.synth_code.len()
        rel32 = loop_exit_off - (patch_loop_exit + 4)
        x86_synth_patch_u32(s, patch_loop_exit, rel32)

        // Backpatch breaks
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            b_rel32 = loop_exit_off - (brk_patch + 4)
            x86_synth_patch_u32(s, brk_patch, b_rel32)
            bi = bi + 1

        s.synth_loop_starts = pop(s.synth_loop_starts)
        s.synth_loop_breaks = pop(s.synth_loop_breaks)
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
        if var_pos < toks.len() and x86_synth_is_ident_token(toks[var_pos].tok_kind) == 1
            var_name = toks[var_pos].tok_text
            list_set(pos_box, 0, var_pos + 1)
            eq_pos = get(pos_box, 0)
            if eq_pos < toks.len() and (toks[eq_pos].tok_kind == TOK_ASSIGN() or toks[eq_pos].tok_text == "=")
                is_int_lit = 0
                int_lit_val = 0
                if eq_pos + 1 < toks.len()
                    rhs_tok = toks[eq_pos + 1]
                    if rhs_tok.tok_kind == TOK_INT()
                        after_rhs = eq_pos + 2
                        if after_rhs >= toks.len() or toks[after_rhs].tok_kind == TOK_NEWLINE() or toks[after_rhs].tok_kind == TOK_SEMI()
                            is_int_lit = 1
                            int_lit_val = rhs_tok.tok_int_val
                list_set(pos_box, 0, eq_pos + 1)
                x86_synth_compile_expr(s, toks, pos_box)
                off = x86_synth_bind_var(s, var_name)
                if is_int_lit == 1
                    x86_synth_set_global_const(s, var_name, int_lit_val)
        return 0

    // ── 10. Assignment: <var> = <expr> or <var> <op>= <expr> ───────────────────
    if x86_synth_is_ident_token(k) == 1
        next_pos = pos + 1
        if next_pos < toks.len()
            ntk = toks[next_pos]
            nk = ntk.tok_kind
            ntxt = ntk.tok_text
            is_assign = 0
            is_compound = 0
            comp_op = 0
            if nk == TOK_ASSIGN() or ntxt == "="
                is_assign = 1
            elif nk == TOK_PLUSEQ() or ntxt == "+="
                is_assign = 1
                is_compound = 1
                comp_op = TOK_PLUS()
            elif nk == TOK_MINUSEQ() or ntxt == "-="
                is_assign = 1
                is_compound = 1
                comp_op = TOK_MINUS()
            elif nk == TOK_STAREQ() or ntxt == "*="
                is_assign = 1
                is_compound = 1
                comp_op = TOK_STAR()
            elif nk == TOK_SLASHEQ() or ntxt == "/="
                is_assign = 1
                is_compound = 1
                comp_op = TOK_SLASH()
            elif nk == TOK_PERCENTEQ() or ntxt == "%="
                is_assign = 1
                is_compound = 1
                comp_op = TOK_PERCENT()

            if is_assign == 1
                var_name = txt
                if is_compound == 0
                    is_int_lit = 0
                    int_lit_val = 0
                    if next_pos + 1 < toks.len()
                        rhs_tok = toks[next_pos + 1]
                        if rhs_tok.tok_kind == TOK_INT()
                            after_rhs = next_pos + 2
                            if after_rhs >= toks.len() or toks[after_rhs].tok_kind == TOK_NEWLINE() or toks[after_rhs].tok_kind == TOK_SEMI()
                                is_int_lit = 1
                                int_lit_val = rhs_tok.tok_int_val
                    list_set(pos_box, 0, next_pos + 1) // Consume ident and '='
                    x86_synth_compile_expr(s, toks, pos_box)
                    off = x86_synth_bind_var(s, var_name)
                    if is_int_lit == 1
                        x86_synth_set_global_const(s, var_name, int_lit_val)
                    return 0
                else
                    // Compound assignment: target += expr, target -= expr, etc.
                    list_set(pos_box, 0, next_pos + 1) // Consume ident and op=
                    // Evaluate RHS expression into %rax
                    x86_synth_compile_expr(s, toks, pos_box)
                    // mov rcx, rax (save RHS in rcx)
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 193)
                    // Load current value of target var into %rax
                    off = x86_synth_alloc_var(s, var_name)
                    x86_synth_emit_load_var(s, 0, off)
                    if comp_op == TOK_PLUS()
                        // rdi = rax (left), rsi = rcx (right) -> call _lipi_add_dynamic
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 199)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 206)
                        x86_synth_emit_call_helper(s, "_lipi_add_dynamic")
                    elif comp_op == TOK_MINUS()
                        // sub rax, rcx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 41)
                        x86_synth_emit_byte(s, 200)
                    elif comp_op == TOK_STAR()
                        // imul rax, rcx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 15)
                        x86_synth_emit_byte(s, 175)
                        x86_synth_emit_byte(s, 193)
                    elif comp_op == TOK_SLASH()
                        // cqo; idiv rcx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 153)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 249)
                    elif comp_op == TOK_PERCENT()
                        // cqo; idiv rcx; mov rax, rdx
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 153)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 247)
                        x86_synth_emit_byte(s, 249)
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_byte(s, 208)
                    // Store updated value back to target
                    x86_synth_emit_store_var(s, 0, off)
                    return 0

    // ── 11. Function Definition: fn / কাজ / @fn ────────────────────────────────
    is_fn = 0
    if k == TOK_KW_FN() or k == TOK_DIR_FN()
        is_fn = 1
    if k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn")
        is_fn = 1

    if is_fn == 1
        return x86_synth_compile_fn_def(s, toks, pos_box)

    // Default: evaluate expression or advance token with strict forward progress guarantee
    before_expr_p = get(pos_box, 0)
    x86_synth_compile_expr(s, toks, pos_box)
    if get(pos_box, 0) <= before_expr_p
        list_set(pos_box, 0, before_expr_p + 1)
    return 0
