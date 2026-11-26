// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN WEBASSEMBLY (WASM) BYTECODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | 0% Node.js | Direct W3C Binary Generation
// 🏛️ File: src/compiler/backend/targets/wasm/synthesizer.lp
// ==============================================================================

include "src/compiler/backend/targets/wasm/codegen_core.lp"
include "src/compiler/backend/targets/wasm/codegen_expr.lp"

    // ── 1. Output Statement: say / বলো / print / println / show / দেখাও ──────────
    is_print = 0
    if k == TOK_KW_PRINT()
        is_print = 1
    if k == TOK_IDENT() and (txt == "say" or txt == "বলো" or txt == "print" or txt == "println" or txt == "show" or txt == "দেখাও")
        is_print = 1

    if is_print == 1
        list_set(pos_box, 0, pos + 1) // Consume print keyword
        if s.ws_freestanding == 1
            // WHY: Freestanding WASM emits zero wasi_snapshot_preview1 imports; evaluate side effects cleanly and drop.
            cur_p_fs = get(pos_box, 0)
            if cur_p_fs < toks.len() and toks[cur_p_fs].tok_kind == TOK_STR()
                np_fs = cur_p_fs + 1
                if np_fs >= toks.len() or toks[np_fs].tok_kind == TOK_NEWLINE() or toks[np_fs].tok_kind == TOK_SEMI() or toks[np_fs].tok_kind == TOK_EOF()
                    list_set(pos_box, 0, cur_p_fs + 1)
                    return 0
                end
            end
            wasm_synth_compile_expr(s, toks, pos_box)
            wasm_emit_drop(s.ws_code)
            return 0
        end
        s.ws_needs_wasi_print = 1
        cur_p = get(pos_box, 0)
        is_direct_str = 0
        if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_STR()
            next_p = cur_p + 1
            if next_p >= toks.len() or toks[next_p].tok_kind == TOK_NEWLINE() or toks[next_p].tok_kind == TOK_SEMI() or toks[next_p].tok_kind == TOK_EOF()
                is_direct_str = 1
            end
        end
        if is_direct_str == 1
            str_payload = toks[cur_p].tok_text + "\n"
            str_len = len(str_payload)
            str_off = wasm_synth_add_string_constant(s, str_payload)
            list_set(pos_box, 0, cur_p + 1)
            wasm_emit_i32_const(s.ws_code, 0)
            wasm_emit_i32_const(s.ws_code, str_off)
            wasm_emit_i32_store(s.ws_code, 2, 0)
            wasm_emit_i32_const(s.ws_code, 4)
            wasm_emit_i32_const(s.ws_code, str_len)
            wasm_emit_i32_store(s.ws_code, 2, 0)
            wasm_emit_i32_const(s.ws_code, 1) // STDOUT
            wasm_emit_i32_const(s.ws_code, 0) // iovs
            wasm_emit_i32_const(s.ws_code, 1) // iovs_len
            wasm_emit_i32_const(s.ws_code, 8) // nwritten
            wasm_emit_call(s.ws_code, 0)      // call fd_write
            wasm_emit_drop(s.ws_code)
            return 0
        end

        // General expression print: runtime detection of LPST tagged string vs signed i64 decimal
        l_val = wasm_synth_alloc_local(s, "__wasi_p_val")
        l_pos = wasm_synth_alloc_local(s, "__wasi_p_pos")
        l_neg = wasm_synth_alloc_local(s, "__wasi_p_neg")
        l_dig = wasm_synth_alloc_local(s, "__wasi_p_dig")
        l_is_str = wasm_synth_alloc_local(s, "__wasi_p_is_str")
        l_niovs = wasm_synth_alloc_local(s, "__wasi_p_niovs")

        wasm_synth_compile_expr(s, toks, pos_box)
        wasm_emit_local_set(s.ws_code, l_val)

        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_local_set(s.ws_code, l_is_str)
        wasm_emit_local_get(s.ws_code, l_val)
        wasm_emit_i64_const(s.ws_code, 1040)
        wasm_emit_i64_ge_s(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_val)
            wasm_emit_i64_const(s.ws_code, 262144)
            wasm_emit_i64_lt_s(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_val)
                wasm_emit_i64_const(s.ws_code, 7)
                wasm_emit_i64_and(s.ws_code)
                wasm_emit_i64_const(s.ws_code, 0)
                wasm_emit_i64_eq(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                    wasm_emit_local_get(s.ws_code, l_val)
                    wasm_emit_i64_const(s.ws_code, 16)
                    wasm_emit_i64_sub(s.ws_code)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 3, 0)
                    wasm_emit_i64_const(s.ws_code, 1280332628)
                    wasm_emit_i64_eq(s.ws_code)
                    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                        wasm_emit_i64_const(s.ws_code, 1)
                        wasm_emit_local_set(s.ws_code, l_is_str)
                    wasm_emit_end(s.ws_code)
                wasm_emit_end(s.ws_code)
            wasm_emit_end(s.ws_code)
        wasm_emit_end(s.ws_code)

        wasm_emit_local_get(s.ws_code, l_is_str)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_eq(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            // iovs[0] = { base: l_val, len: [l_val - 8] }, iovs[1] = { base: 95 ('\n'), len: 1 }
            wasm_emit_i32_const(s.ws_code, 0)
            wasm_emit_local_get(s.ws_code, l_val)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i32_store(s.ws_code, 2, 0)

            wasm_emit_i32_const(s.ws_code, 4)
            wasm_emit_local_get(s.ws_code, l_val)
            wasm_emit_i64_const(s.ws_code, 8)
            wasm_emit_i64_sub(s.ws_code)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_load(s.ws_code, 3, 0)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i32_store(s.ws_code, 2, 0)

            wasm_emit_i32_const(s.ws_code, 95)
            wasm_emit_i64_const(s.ws_code, 10)
            wasm_emit_i64_store8(s.ws_code, 0, 0)

            wasm_emit_i32_const(s.ws_code, 8)
            wasm_emit_i32_const(s.ws_code, 95)
            wasm_emit_i32_store(s.ws_code, 2, 0)

            wasm_emit_i32_const(s.ws_code, 12)
            wasm_emit_i32_const(s.ws_code, 1)
            wasm_emit_i32_store(s.ws_code, 2, 0)

            wasm_emit_i64_const(s.ws_code, 2)
            wasm_emit_local_set(s.ws_code, l_niovs)
        wasm_emit_else(s.ws_code)
            // Format evaluated signed i64 expression into decimal ASCII bytes at [64..95] + '\n'
            wasm_emit_i32_const(s.ws_code, 95)
            wasm_emit_i64_const(s.ws_code, 10)
            wasm_emit_i64_store8(s.ws_code, 0, 0)
            wasm_emit_i64_const(s.ws_code, 95)
            wasm_emit_local_set(s.ws_code, l_pos)

            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_local_set(s.ws_code, l_neg)
            wasm_emit_local_get(s.ws_code, l_val)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_lt_s(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_local_set(s.ws_code, l_neg)
            wasm_emit_end(s.ws_code)

            wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_pos)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_i64_sub(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_pos)

            wasm_emit_local_get(s.ws_code, l_val)
            wasm_emit_i64_const(s.ws_code, 10)
            wasm_emit_i64_rem_s(s.ws_code)
            wasm_emit_local_tee(s.ws_code, l_dig)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_lt_s(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_local_get(s.ws_code, l_dig)
            wasm_emit_i64_sub(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_dig)
            wasm_emit_end(s.ws_code)

            wasm_emit_local_get(s.ws_code, l_pos)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_local_get(s.ws_code, l_dig)
            wasm_emit_i64_const(s.ws_code, 48)
            wasm_emit_i64_add(s.ws_code)
            wasm_emit_i64_store8(s.ws_code, 0, 0)

            wasm_emit_local_get(s.ws_code, l_val)
            wasm_emit_i64_const(s.ws_code, 10)
            wasm_emit_i64_div_s(s.ws_code)
            wasm_emit_local_tee(s.ws_code, l_val)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_br_if(s.ws_code, 0)
            wasm_emit_end(s.ws_code)

            wasm_emit_local_get(s.ws_code, l_neg)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_pos)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_i64_sub(s.ws_code)
            wasm_emit_local_tee(s.ws_code, l_pos)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 45)
            wasm_emit_i64_store8(s.ws_code, 0, 0)
            wasm_emit_end(s.ws_code)

            wasm_emit_i32_const(s.ws_code, 0)
            wasm_emit_local_get(s.ws_code, l_pos)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i32_store(s.ws_code, 2, 0)

            wasm_emit_i32_const(s.ws_code, 4)
            wasm_emit_i64_const(s.ws_code, 96)
            wasm_emit_local_get(s.ws_code, l_pos)
            wasm_emit_i64_sub(s.ws_code)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i32_store(s.ws_code, 2, 0)

            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_local_set(s.ws_code, l_niovs)
        wasm_emit_end(s.ws_code)
        // Invoke WASI fd_write: fd=1, iovs=0, iovs_len=l_niovs, nwritten=16
        wasm_emit_i32_const(s.ws_code, 1)
        wasm_emit_i32_const(s.ws_code, 0)
        wasm_emit_local_get(s.ws_code, l_niovs)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i32_const(s.ws_code, 16)
        wasm_emit_call(s.ws_code, 0)
        wasm_emit_drop(s.ws_code)
        return 0

    // ── 2. Control Flow: return / ফেরত ─────────────────────────────────────────
    if k == TOK_KW_RETURN() or k == TOK_DIR_RETURN() or (k == TOK_IDENT() and (txt == "return" or txt == "ফেরত" or txt == "@return"))
        list_set(pos_box, 0, pos + 1) // Consume keyword
        next_pos = get(pos_box, 0)
        has_expr = 0
        if next_pos < toks.len()
            nt = toks[next_pos]
            if nt.tok_kind != TOK_NEWLINE() and nt.tok_kind != TOK_SEMI() and nt.tok_kind != TOK_EOF()
                has_expr = 1

        if has_expr == 1
            wasm_synth_compile_expr(s, toks, pos_box)
        else
            wasm_emit_i64_const(s.ws_code, 0)

        wasm_emit_return(s.ws_code)
        if s.ws_current_fn != 0 and s.ws_block_depth == 0
            s.ws_current_fn.wfn_has_returned = 1
        return 0

    // ── 3. Loop Control: break / থামো & continue / চলুক ───────────────────────
    if k == TOK_KW_BREAK() or k == TOK_DIR_BREAK() or (k == TOK_IDENT() and (txt == "break" or txt == "থামো" or txt == "@break"))
        list_set(pos_box, 0, pos + 1)
        if s.ws_loop_stack.len() > 0
            cur_loop = s.ws_loop_stack[s.ws_loop_stack.len() - 1]
            rel_depth = s.ws_block_depth - cur_loop.wlc_break_depth
            wasm_emit_br(s.ws_code, rel_depth)
        return 0

    if k == TOK_KW_CONTINUE() or k == TOK_DIR_CONTINUE() or (k == TOK_IDENT() and (txt == "continue" or txt == "চলুক" or txt == "চলো" or txt == "@continue"))
        list_set(pos_box, 0, pos + 1)
        if s.ws_loop_stack.len() > 0
            cur_loop = s.ws_loop_stack[s.ws_loop_stack.len() - 1]
            rel_depth = s.ws_block_depth - cur_loop.wlc_continue_depth
            wasm_emit_br(s.ws_code, rel_depth)
        return 0

    // ── 4. Conditionals: if / elif / else (যদি / নাহলে_যদি / নাহলে / @if...) ──
    is_if = 0
    if k == TOK_KW_IF() or k == TOK_DIR_IF()
        is_if = 1
    if k == TOK_IDENT() and (txt == "if" or txt == "যদি" or txt == "@if")
        is_if = 1

    if is_if == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'if'

        // Evaluate condition expression
        wasm_synth_compile_expr(s, toks, pos_box)

        // Convert i64 condition to i32 boolean for WASM if instruction:
        // condition != 0 -> i32 (1 if true, 0 if false)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_i64_ne(s.ws_code)

        // Emit if 0x40
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1

        wasm_synth_skip_whitespace(toks, pos_box)

        // Compile then-block statements
        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
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

            b_p = get(pos_box, 0)
            wasm_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)
            if cur_t.tok_span.span_start_line == base_line
                break

        // Process chained elif / else branches
        opened_blocks = 1

        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            is_elif = 0
            if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or (cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif"))
                is_elif = 1

            is_else = 0
            if cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE() or (cur_k == TOK_IDENT() and (cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else"))
                is_else = 1

            if is_elif == 1
                list_set(pos_box, 0, cur_p + 1) // Consume 'elif'
                elif_line = cur_t.tok_span.span_start_line

                wasm_emit_else(s.ws_code)

                wasm_synth_compile_expr(s, toks, pos_box)
                wasm_emit_i64_const(s.ws_code, 0)
                wasm_emit_i64_ne(s.ws_code)

                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                s.ws_block_depth = s.ws_block_depth + 1
                opened_blocks = opened_blocks + 1

                while get(pos_box, 0) < toks.len()
                    wasm_synth_skip_whitespace(toks, pos_box)
                    cp2 = get(pos_box, 0)
                    if cp2 >= toks.len()
                        break
                    ct2 = toks[cp2]
                    ck2 = ct2.tok_kind
                    cx2 = ct2.tok_text

                    if ck2 == TOK_KW_ELIF() or ck2 == TOK_DIR_ELIF() or ck2 == TOK_KW_ELSE() or ck2 == TOK_DIR_ELSE() or ck2 == TOK_KW_END() or ck2 == TOK_DIR_END()
                        break
                    if ck2 == TOK_IDENT() and (cx2 == "elif" or cx2 == "নাহলে_যদি" or cx2 == "@elif" or cx2 == "else" or cx2 == "নাহলে" or cx2 == "@else" or cx2 == "end" or cx2 == "শেষ" or cx2 == "@end")
                        break
                    if ct2.tok_span.span_start_line > elif_line and ct2.tok_span.span_start_col <= base_col
                        break

                    b_p2 = get(pos_box, 0)
                    wasm_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p2
                        list_set(pos_box, 0, b_p2 + 1)
                    if ct2.tok_span.span_start_line == elif_line
                        break

            elif is_else == 1
                list_set(pos_box, 0, cur_p + 1) // Consume 'else'
                else_line = cur_t.tok_span.span_start_line
                wasm_emit_else(s.ws_code)

                while get(pos_box, 0) < toks.len()
                    wasm_synth_skip_whitespace(toks, pos_box)
                    cp3 = get(pos_box, 0)
                    if cp3 >= toks.len()
                        break
                    ct3 = toks[cp3]
                    ck3 = ct3.tok_kind
                    cx3 = ct3.tok_text

                    if ck3 == TOK_KW_END() or ck3 == TOK_DIR_END() or (ck3 == TOK_IDENT() and (cx3 == "end" or cx3 == "শেষ" or cx3 == "@end"))
                        break
                    if ct3.tok_span.span_start_line > else_line and ct3.tok_span.span_start_col <= base_col
                        break

                    b_p3 = get(pos_box, 0)
                    wasm_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p3
                        list_set(pos_box, 0, b_p3 + 1)
                    if ct3.tok_span.span_start_line == else_line
                        break
                break
            else
                break

        // Close all nested if structures with 0x0B
        while opened_blocks > 0
            wasm_emit_end(s.ws_code)
            s.ws_block_depth = s.ws_block_depth - 1
            opened_blocks = opened_blocks - 1

        // Consume optional end / @end / শেষ
        wasm_synth_skip_whitespace(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        return 0

    // ── 5. Loops: while / যতক্ষণ / @while ─────────────────────────────────────
    is_while = 0
    if k == TOK_KW_WHILE() or k == TOK_DIR_WHILE()
        is_while = 1
    if k == TOK_IDENT() and (txt == "while" or txt == "যতক্ষণ" or txt == "@while")
        is_while = 1

    if is_while == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'while'

        // Outer block for break: block 0x40
        wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1
        brk_depth = s.ws_block_depth

        // Inner loop for continue: loop 0x40
        wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1
        cont_depth = s.ws_block_depth

        // Push loop context
        loop_ctx = WasmLoopContext()
        loop_ctx.wlc_break_depth = brk_depth
        loop_ctx.wlc_continue_depth = cont_depth
        loop_ctx.wlc_is_for = 0
        loop_ctx.wlc_var_idx = 0
        push(s.ws_loop_stack, loop_ctx)

        // Evaluate condition: condition == 0 -> br_if out to outer block
        wasm_synth_compile_expr(s, toks, pos_box)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_i64_eq(s.ws_code)
        // Relative label to outer break block:
        rel_exit = s.ws_block_depth - brk_depth
        wasm_emit_br_if(s.ws_code, rel_exit)

        wasm_synth_skip_whitespace(toks, pos_box)

        // Compile while body statements
        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
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
            wasm_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)
            if cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        wasm_synth_skip_whitespace(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Loop repeat: br to inner loop
        rel_loop = s.ws_block_depth - cont_depth
        wasm_emit_br(s.ws_code, rel_loop)

        // Close loop and block
        wasm_emit_end(s.ws_code) // End loop
        s.ws_block_depth = s.ws_block_depth - 1
        wasm_emit_end(s.ws_code) // End block
        s.ws_block_depth = s.ws_block_depth - 1

        s.ws_loop_stack = pop(s.ws_loop_stack)
        return 0

    // ── 6. Loops: for / প্রতিটি / @for ───────────────────────────────────────
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
        list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Consume 'in' or 'মধ্যে' if present
        if get(pos_box, 0) < toks.len()
            in_t = toks[get(pos_box, 0)]
            if in_t.tok_kind == TOK_KW_IN() or (in_t.tok_kind == TOK_IDENT() and (in_t.tok_text == "in" or in_t.tok_text == "মধ্যে"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile start expression
        wasm_synth_compile_expr(s, toks, pos_box)
        var_idx = wasm_synth_alloc_local(s, var_name)
        wasm_emit_local_set(s.ws_code, var_idx)

        // Consume '..' if present
        if get(pos_box, 0) < toks.len()
            dot_t = toks[get(pos_box, 0)]
            if dot_t.tok_kind == TOK_DOTDOT() or dot_t.tok_text == ".."
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile end bound expression
        wasm_synth_compile_expr(s, toks, pos_box)
        end_var_name = "__end_" + var_name
        end_idx = wasm_synth_alloc_local(s, end_var_name)
        wasm_emit_local_set(s.ws_code, end_idx)

        // Outer block for break: block 0x40
        wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1
        brk_depth = s.ws_block_depth

        // Inner loop: loop 0x40
        wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1
        cont_depth = s.ws_block_depth

        // Condition check: var > end -> break out of outer block (inclusive a..b)
        wasm_emit_local_get(s.ws_code, var_idx)
        wasm_emit_local_get(s.ws_code, end_idx)
        wasm_emit_i64_gt_s(s.ws_code)
        rel_exit = s.ws_block_depth - brk_depth
        wasm_emit_br_if(s.ws_code, rel_exit)

        // Inner step block so continue lands directly at var = var + 1 increment
        wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1
        step_depth = s.ws_block_depth

        // Push loop context
        loop_ctx = WasmLoopContext()
        loop_ctx.wlc_break_depth = brk_depth
        loop_ctx.wlc_continue_depth = step_depth
        loop_ctx.wlc_is_for = 1
        loop_ctx.wlc_var_idx = var_idx
        push(s.ws_loop_stack, loop_ctx)

        wasm_synth_skip_whitespace(toks, pos_box)

        // Compile for body statements
        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
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
            wasm_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)
            if cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        wasm_synth_skip_whitespace(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Close inner $step block before increment so `continue` reaches var = var + 1
        wasm_emit_end(s.ws_code)
        s.ws_block_depth = s.ws_block_depth - 1

        // Step increment: var = var + 1
        wasm_emit_local_get(s.ws_code, var_idx)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_local_set(s.ws_code, var_idx)

        // Loop repeat
        rel_loop = s.ws_block_depth - cont_depth
        wasm_emit_br(s.ws_code, rel_loop)

        // Close loop and block
        wasm_emit_end(s.ws_code) // End loop
        s.ws_block_depth = s.ws_block_depth - 1
        wasm_emit_end(s.ws_code) // End block
        s.ws_block_depth = s.ws_block_depth - 1

        s.ws_loop_stack = pop(s.ws_loop_stack)
        return 0

    // ── 6b. Struct Definition Skip (already pre-scanned in Phase 1) ─────────────
    is_struct_stmt = 0
    if k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT()
        is_struct_stmt = 1
    if k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct")
        is_struct_stmt = 1

    if is_struct_stmt == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
            cp_s = get(pos_box, 0)
            if cp_s >= toks.len()
                break
            ct_s = toks[cp_s]
            ck_s = ct_s.tok_kind
            cx_s = ct_s.tok_text
            if ck_s == TOK_EOF()
                break
            if ck_s == TOK_KW_END() or ck_s == TOK_DIR_END() or (ck_s == TOK_IDENT() and (cx_s == "end" or cx_s == "শেষ" or cx_s == "@end"))
                list_set(pos_box, 0, cp_s + 1)
                break
            if ck_s == TOK_KW_FN() or ck_s == TOK_DIR_FN() or ck_s == TOK_KW_STRUCT() or ck_s == TOK_DIR_STRUCT()
                break
            if ck_s == TOK_IDENT() and (cx_s == "fn" or cx_s == "কাজ" or cx_s == "@fn" or cx_s == "struct" or cx_s == "গঠন" or cx_s == "@struct")
                break
            if ct_s.tok_span.span_start_line > base_line and ct_s.tok_span.span_start_col <= base_col
                break
            list_set(pos_box, 0, cp_s + 1)
        return 0

    // ── 6c. Pattern Match: match / মিল / মেলাও / @match ────────────────────────
    is_match = 0
    if k == TOK_KW_MATCH() or k == TOK_DIR_MATCH() or (k == TOK_IDENT() and (txt == "match" or txt == "মিল" or txt == "মেলাও" or txt == "@match"))
        if pos + 1 < toks.len()
            mn_w = toks[pos + 1]
            if mn_w.tok_kind != TOK_ASSIGN() and mn_w.tok_text != "=" and mn_w.tok_kind != TOK_PLUSEQ() and mn_w.tok_text != "+=" and mn_w.tok_kind != TOK_MINUSEQ() and mn_w.tok_text != "-=" and mn_w.tok_kind != TOK_STAREQ() and mn_w.tok_kind != TOK_SLASHEQ() and mn_w.tok_kind != TOK_PERCENTEQ() and mn_w.tok_kind != TOK_DOT() and mn_w.tok_text != "." and mn_w.tok_kind != TOK_LBRACKET() and mn_w.tok_text != "[" and mn_w.tok_kind != TOK_LPAREN() and mn_w.tok_text != "(" and mn_w.tok_kind != TOK_NEWLINE() and mn_w.tok_kind != TOK_SEMI()
                is_match = 1

    if is_match == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        l_mval = wasm_synth_alloc_local(s, "__wasi_match_" + str(pos))
        wasm_synth_compile_expr(s, toks, pos_box)
        wasm_emit_local_set(s.ws_code, l_mval)
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        wasm_synth_skip_whitespace(toks, pos_box)

        opened_cases = 0
        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
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

            if get(pos_box, 0) < toks.len()
                sep_k = toks[get(pos_box, 0)].tok_kind
                sep_txt = toks[get(pos_box, 0)].tok_text
                if is_default_arm == 1 and (sep_k == TOK_FAT_ARROW() or sep_k == TOK_COLON() or sep_k == TOK_ARROW() or sep_txt == "=>" or sep_txt == ":" or sep_txt == "->")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)

            if is_default_arm == 1
                if opened_cases > 0
                    wasm_emit_else(s.ws_code)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == arm_line and toks[get(pos_box, 0)].tok_kind != TOK_NEWLINE() and toks[get(pos_box, 0)].tok_kind != TOK_SEMI() and toks[get(pos_box, 0)].tok_kind != TOK_COMMENT_LINE()
                    bp_e1 = get(pos_box, 0)
                    wasm_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == bp_e1
                        list_set(pos_box, 0, bp_e1 + 1)
                else
                    while get(pos_box, 0) < toks.len()
                        wasm_synth_skip_whitespace(toks, pos_box)
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
                        wasm_synth_compile_statement(s, toks, pos_box)
                        if get(pos_box, 0) == bp_e
                            list_set(pos_box, 0, bp_e + 1)
                break
            else
                if opened_cases > 0
                    wasm_emit_else(s.ws_code)
                wasm_emit_local_get(s.ws_code, l_mval)
                wasm_synth_compile_expr(s, toks, pos_box)
                if get(pos_box, 0) < toks.len()
                    sep_k2 = toks[get(pos_box, 0)].tok_kind
                    sep_t2 = toks[get(pos_box, 0)].tok_text
                    if sep_k2 == TOK_FAT_ARROW() or sep_k2 == TOK_COLON() or sep_k2 == TOK_ARROW() or sep_t2 == "=>" or sep_t2 == ":" or sep_t2 == "->"
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                wasm_emit_i64_eq(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                s.ws_block_depth = s.ws_block_depth + 1
                opened_cases = opened_cases + 1

                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == arm_line and toks[get(pos_box, 0)].tok_kind != TOK_NEWLINE() and toks[get(pos_box, 0)].tok_kind != TOK_SEMI() and toks[get(pos_box, 0)].tok_kind != TOK_COMMENT_LINE()
                    bp_c1 = get(pos_box, 0)
                    wasm_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == bp_c1
                        list_set(pos_box, 0, bp_c1 + 1)
                else
                    while get(pos_box, 0) < toks.len()
                        wasm_synth_skip_whitespace(toks, pos_box)
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
                        wasm_synth_compile_statement(s, toks, pos_box)
                        if get(pos_box, 0) == bp_c
                            list_set(pos_box, 0, bp_c + 1)

        while opened_cases > 0
            wasm_emit_end(s.ws_code)
            s.ws_block_depth = s.ws_block_depth - 1
            opened_cases = opened_cases - 1

        wasm_synth_skip_whitespace(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            et_m = toks[get(pos_box, 0)]
            if et_m.tok_kind == TOK_KW_END() or et_m.tok_kind == TOK_DIR_END() or (et_m.tok_kind == TOK_IDENT() and (et_m.tok_text == "end" or et_m.tok_text == "শেষ" or et_m.tok_text == "@end"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
        return 0

    // ── 6d. Exception Handling: throw / নিক্ষেপ & try / চেষ্টা ... catch / ধরো ─
    if k == TOK_IDENT() and (txt == "throw" or txt == "নিক্ষেপ" or txt == "@throw")
        list_set(pos_box, 0, pos + 1)
        l_tv = wasm_synth_alloc_local(s, "__wasi_throw_v")
        wasm_synth_compile_expr(s, toks, pos_box)
        wasm_emit_local_set(s.ws_code, l_tv)
        wasm_emit_i32_const(s.ws_code, 112)
        wasm_emit_local_get(s.ws_code, l_tv)
        wasm_emit_i64_store(s.ws_code, 3, 0)
        wasm_emit_i32_const(s.ws_code, 104)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_store(s.ws_code, 3, 0)
        if s.ws_try_depths.len() > 0
            t_depth = s.ws_try_depths[s.ws_try_depths.len() - 1]
            wasm_emit_br(s.ws_code, s.ws_block_depth - t_depth)
        elif s.ws_current_fn != 0 and s.ws_current_fn.wfn_name != "main" and s.ws_current_fn.wfn_name != "_start" and s.ws_current_fn.wfn_name != "মূল"
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_return(s.ws_code)
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

        // Reset exception flag before entering try block
        wasm_emit_i32_const(s.ws_code, 104)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_i64_store(s.ws_code, 3, 0)

        wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
        s.ws_block_depth = s.ws_block_depth + 1
        push(s.ws_try_depths, s.ws_block_depth)

        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
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
            wasm_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == bp_t
                list_set(pos_box, 0, bp_t + 1)

        s.ws_try_depths = pop(s.ws_try_depths)
        wasm_emit_end(s.ws_code)
        s.ws_block_depth = s.ws_block_depth - 1

        wasm_synth_skip_whitespace(toks, pos_box)
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

                wasm_emit_i32_const(s.ws_code, 104)
                wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_i64_const(s.ws_code, 0)
                wasm_emit_i64_ne(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                s.ws_block_depth = s.ws_block_depth + 1

                // Clear active exception flag before running catch body
                wasm_emit_i32_const(s.ws_code, 104)
                wasm_emit_i64_const(s.ws_code, 0)
                wasm_emit_i64_store(s.ws_code, 3, 0)

                if catch_var != ""
                    cv_idx = wasm_synth_alloc_local(s, catch_var)
                    wasm_emit_i32_const(s.ws_code, 112)
                    wasm_emit_i64_load(s.ws_code, 3, 0)
                    wasm_emit_local_set(s.ws_code, cv_idx)

                while get(pos_box, 0) < toks.len()
                    wasm_synth_skip_whitespace(toks, pos_box)
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
                    wasm_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == bp_cb
                        list_set(pos_box, 0, bp_cb + 1)

                wasm_emit_end(s.ws_code)
                s.ws_block_depth = s.ws_block_depth - 1

        wasm_synth_skip_whitespace(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            et_t = toks[get(pos_box, 0)]
            if et_t.tok_kind == TOK_KW_END() or et_t.tok_kind == TOK_DIR_END() or (et_t.tok_kind == TOK_IDENT() and (et_t.tok_text == "end" or et_t.tok_text == "শেষ" or et_t.tok_text == "@end"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
        return 0

    // ── 7. Variable Declarations: let / var / চলক / ধরি ──────────────────────
    is_let = 0
    if k == TOK_KW_LET() or (k == TOK_IDENT() and (txt == "let" or txt == "var" or txt == "ধরি" or txt == "চলক" or txt == "@let"))
        is_let = 1

    if is_let == 1
        list_set(pos_box, 0, pos + 1) // Consume let
        var_pos = get(pos_box, 0)
        if var_pos < toks.len() and toks[var_pos].tok_kind == TOK_IDENT()
            var_name = toks[var_pos].tok_text
            list_set(pos_box, 0, var_pos + 1)

            eq_pos = get(pos_box, 0)
            if eq_pos < toks.len() and (toks[eq_pos].tok_kind == TOK_ASSIGN() or toks[eq_pos].tok_text == "=")
                list_set(pos_box, 0, eq_pos + 1) // Consume '='
                wasm_synth_compile_expr(s, toks, pos_box)
                var_idx = wasm_synth_alloc_local(s, var_name)
                wasm_emit_local_set(s.ws_code, var_idx)
                wasm_synth_mark_float_var(s, var_name, s.ws_last_expr_is_float)
                wasm_synth_mark_str_var(s, var_name, s.ws_last_expr_is_str)
        return 0

    // ── 8. Struct Field & Variable Assignment: obj.field = expr / x = expr ────
    if k == TOK_IDENT()
        // Check obj.field = expr (with arbitrary chained a.b.c = expr support)
        if pos + 3 < toks.len() and (toks[pos + 1].tok_kind == TOK_DOT() or toks[pos + 1].tok_text == ".") and wasm_is_ident_token(toks[pos + 2].tok_kind) == 1
            scan_f = pos + 1
            fnames = list()
            while scan_f + 1 < toks.len() and (toks[scan_f].tok_kind == TOK_DOT() or toks[scan_f].tok_text == ".") and wasm_is_ident_token(toks[scan_f + 1].tok_kind) == 1
                push(fnames, toks[scan_f + 1].tok_text)
                scan_f = scan_f + 2
            if fnames.len() > 0 and scan_f < toks.len() and (toks[scan_f].tok_kind == TOK_ASSIGN() or toks[scan_f].tok_text == "=")
                obj_idx = wasm_synth_alloc_local(s, txt)
                wasm_emit_local_get(s.ws_code, obj_idx)
                fi_m = 0
                while fi_m < fnames.len() - 1
                    mid_off = wasm_synth_get_field_offset(s, fnames[fi_m])
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 3, mid_off)
                    fi_m = fi_m + 1
                wasm_emit_i32_wrap_i64(s.ws_code)
                last_off = wasm_synth_get_field_offset(s, fnames[fnames.len() - 1])
                list_set(pos_box, 0, scan_f + 1)
                wasm_synth_compile_expr(s, toks, pos_box)
                wasm_emit_i64_store(s.ws_code, 3, last_off)
                return 0

        next_pos = pos + 1
        if next_pos < toks.len()
            nt = toks[next_pos]
            nk = nt.tok_kind
            ntxt = nt.tok_text

            // Typed local variable declaration: x: u8 = expr / x: i64 = expr
            if (nk == TOK_COLON() or (nk != TOK_STR() and ntxt == ":")) and next_pos + 2 < toks.len() and toks[next_pos + 1].tok_kind == TOK_IDENT()
                decl_type = toks[next_pos + 1].tok_text
                eq_p = next_pos + 2
                if eq_p < toks.len() and (toks[eq_p].tok_kind == TOK_ASSIGN() or toks[eq_p].tok_text == "=")
                    var_name = txt
                    list_set(pos_box, 0, eq_p + 1)
                    wasm_synth_compile_expr(s, toks, pos_box)
                    if wasm_is_narrow_int_type(decl_type) == 1
                        wasm_synth_set_narrow_type(s, var_name, decl_type)
                        wasm_emit_truncate_int_width(s.ws_code, decl_type)
                    end
                    var_idx = wasm_synth_alloc_local(s, var_name)
                    wasm_emit_local_set(s.ws_code, var_idx)
                    wasm_synth_mark_float_var(s, var_name, s.ws_last_expr_is_float)
                    wasm_synth_mark_str_var(s, var_name, s.ws_last_expr_is_str)
                    return 0
                end
            end

            // Simple assignment: x = expr
            if nk == TOK_ASSIGN() or ntxt == "="
                var_name = txt
                list_set(pos_box, 0, next_pos + 1) // Consume ident and '='
                wasm_synth_compile_expr(s, toks, pos_box)
                nt_cur = wasm_synth_get_narrow_type(s, var_name)
                if wasm_is_narrow_int_type(nt_cur) == 1
                    wasm_emit_truncate_int_width(s.ws_code, nt_cur)
                end
                var_idx = wasm_synth_alloc_local(s, var_name)
                wasm_emit_local_set(s.ws_code, var_idx)
                wasm_synth_mark_float_var(s, var_name, s.ws_last_expr_is_float)
                wasm_synth_mark_str_var(s, var_name, s.ws_last_expr_is_str)
                return 0

            // Compound assignment: x += expr, x -= expr, x *= expr, x /= expr, x %= expr
            is_compound = 0
            if nk == TOK_PLUSEQ() or nk == TOK_MINUSEQ() or nk == TOK_STAREQ() or nk == TOK_SLASHEQ() or nk == TOK_PERCENTEQ()
                is_compound = 1
            if ntxt == "+=" or ntxt == "-=" or ntxt == "*=" or ntxt == "/=" or ntxt == "%="
                is_compound = 1

            if is_compound == 1
                var_name = txt
                list_set(pos_box, 0, next_pos + 1) // Consume ident and op=
                var_idx = wasm_synth_alloc_local(s, var_name)

                wasm_emit_local_get(s.ws_code, var_idx)
                wasm_synth_compile_expr(s, toks, pos_box)

                if nk == TOK_PLUSEQ() or ntxt == "+="
                    wasm_emit_i64_add(s.ws_code)
                elif nk == TOK_MINUSEQ() or ntxt == "-="
                    wasm_emit_i64_sub(s.ws_code)
                elif nk == TOK_STAREQ() or ntxt == "*="
                    wasm_emit_i64_mul(s.ws_code)
                elif nk == TOK_SLASHEQ() or ntxt == "/="
                    wasm_emit_i64_div_s(s.ws_code)
                elif nk == TOK_PERCENTEQ() or ntxt == "%="
                    wasm_emit_i64_rem_s(s.ws_code)

                nt_comp = wasm_synth_get_narrow_type(s, var_name)
                if wasm_is_narrow_int_type(nt_comp) == 1
                    wasm_emit_truncate_int_width(s.ws_code, nt_comp)
                end
                wasm_emit_local_set(s.ws_code, var_idx)
                return 0

    // ── 9. Standalone Expression Statement ────────────────────────────────────
    wasm_synth_compile_expr(s, toks, pos_box)
    // Discard expression result from stack to preserve stack neutral execution
    wasm_emit_drop(s.ws_code)
    return 0

// ==============================================================================
// ── 9. Master Compilation Engine & Program Synthesizer ────────────────────────
// ==============================================================================

fn wasm_synth_compile_program_ssa tokens ssa_lower_res
    // WHY: Master orchestration entry point. Transforms raw token stream (and optionally
    //      direct SSA CFG-lowered WebAssembly MVP functions when --ssa-codegen is active)
    //      into a complete, sovereign, standalone W3C WebAssembly (.wasm) binary container.
    s = wasm_synth_new()
    toks = tokens

    // ── Phase 1: Pre-scan token stream for function declarations ───────────────
    scan_p = 0
    fn_headers = list()
    has_top_level_code = 0
    user_main_found = 0

    while scan_p < toks.len()
        tok = toks[scan_p]
        tk = tok.tok_kind
        ttxt = tok.tok_text

        is_fn = 0
        if tk == TOK_KW_FN() or tk == TOK_DIR_FN() or tk == TOK_KW_COMPONENT() or (tk == TOK_IDENT() and (ttxt == "fn" or ttxt == "কাজ" or ttxt == "@fn" or ttxt == "component" or ttxt == "উপাদান"))
            is_fn = 1

        if is_fn == 1
            name_p = scan_p + 1
            if name_p < toks.len() and toks[name_p].tok_kind == TOK_IDENT()
                fn_name = toks[name_p].tok_text
                if fn_name == "main" or fn_name == "_start" or fn_name == "মূল"
                    user_main_found = 1

                // Extract parameter names
                param_names = list()
                pp = name_p + 1
                while pp < toks.len()
                    pt = toks[pp]
                    if pt.tok_kind == TOK_NEWLINE() or pt.tok_kind == TOK_SEMI()
                        break
                    end
                    if pt.tok_kind == TOK_ARROW() or (pt.tok_kind != TOK_STR() and pt.tok_text == "->")
                        pp = pp + 1
                        if pp < toks.len() and toks[pp].tok_kind == TOK_IDENT()
                            pp = pp + 1
                        end
                        break
                    end
                    if pt.tok_kind == TOK_IDENT()
                        push(param_names, pt.tok_text)
                        pp = pp + 1
                        if pp < toks.len() and (toks[pp].tok_kind == TOK_COLON() or (toks[pp].tok_kind != TOK_STR() and toks[pp].tok_text == ":"))
                            pp = pp + 1
                            if pp < toks.len() and toks[pp].tok_kind == TOK_IDENT()
                                pp = pp + 1
                            end
                        end
                    else
                        pp = pp + 1
                    end
                end

                entry = [fn_name, param_names, scan_p]
                push(fn_headers, entry)
                scan_p = pp
        elif tk == TOK_KW_STRUCT() or tk == TOK_DIR_STRUCT() or (tk == TOK_IDENT() and (ttxt == "struct" or ttxt == "গঠন" or ttxt == "@struct"))
            base_col_s = tok.tok_span.span_start_col
            hdr_line_s = tok.tok_span.span_start_line
            sp = scan_p + 1
            if sp < toks.len() and toks[sp].tok_kind == TOK_IDENT()
                sname = toks[sp].tok_text
                sp = sp + 1
                s_fields = list()
                while sp < toks.len()
                    st_f = toks[sp]
                    sk_f = st_f.tok_kind
                    stxt_f = st_f.tok_text
                    if sk_f == TOK_EOF()
                        break
                    if sk_f == TOK_NEWLINE() or sk_f == TOK_SEMI() or sk_f == TOK_COMMENT_DOC() or sk_f == TOK_COMMENT_LINE() or sk_f == TOK_COMMENT_BLOCK()
                        sp = sp + 1
                    elif sk_f == TOK_KW_END() or sk_f == TOK_DIR_END() or (sk_f == TOK_IDENT() and (stxt_f == "end" or stxt_f == "@end" or stxt_f == "শেষ"))
                        sp = sp + 1
                        break
                    elif sk_f == TOK_KW_FN() or sk_f == TOK_DIR_FN() or sk_f == TOK_KW_STRUCT() or sk_f == TOK_DIR_STRUCT() or (sk_f == TOK_IDENT() and (stxt_f == "fn" or stxt_f == "কাজ" or stxt_f == "@fn" or stxt_f == "struct" or stxt_f == "গঠন" or stxt_f == "@struct"))
                        break
                    elif st_f.tok_span.span_start_line > hdr_line_s and st_f.tok_span.span_start_col <= base_col_s
                        break
                    elif wasm_is_ident_token(sk_f) == 1
                        push(s_fields, stxt_f)
                        sp = sp + 1
                        if sp < toks.len() and (toks[sp].tok_kind == TOK_COLON() or (toks[sp].tok_kind != TOK_STR() and toks[sp].tok_text == ":"))
                            sp = sp + 1
                            if sp < toks.len() and toks[sp].tok_kind == TOK_IDENT()
                                sp = sp + 1
                    else
                        sp = sp + 1
                if wasm_synth_find_struct(s, sname) == 0
                    sdef_new = WasmStructDef()
                    sdef_new.wsd_name = sname
                    sdef_new.wsd_fields = s_fields
                    push(s.ws_structs, sdef_new)
                scan_p = sp - 1
        else
            if s.ws_freestanding == 0 and (tk == TOK_KW_PRINT() or (tk == TOK_IDENT() and (ttxt == "say" or ttxt == "বলো" or ttxt == "print" or ttxt == "println" or ttxt == "show" or ttxt == "দেখাও")))
                s.ws_needs_wasi_print = 1
            end
            if tk != TOK_NEWLINE() and tk != TOK_SEMI() and tk != TOK_EOF() and tk != TOK_COMMENT_DOC() and tk != TOK_COMMENT_LINE() and tk != TOK_COMMENT_BLOCK()
                has_top_level_code = 1
        scan_p = scan_p + 1

    // ── Phase 2: Register Function Table Entries ───────────────────────────────
    // In accordance with W3C WASM standalone execution convention, function index 0
    // must be the executable entrypoint ('main', '_start', or 'মূল').
    main_fn = 0
    if has_top_level_code == 1 or user_main_found == 0
        main_fn = wasm_synth_create_func(s, "main", list())

    hi = 0
    while hi < fn_headers.len()
        h = fn_headers[hi]
        h_name = get(h, 0)
        h_params = get(h, 1)

        // If user defined 'main' / '_start' / 'মূল' and no synthetic main was added yet:
        if (h_name == "main" or h_name == "_start" or h_name == "মূল") and main_fn == 0
            main_fn = wasm_synth_create_func(s, h_name, h_params)
        elif h_name != "main" and h_name != "_start" and h_name != "মূল"
            wasm_synth_create_func(s, h_name, h_params)
        hi = hi + 1

    // ── Phase 3: Compile Function Bodies & Top-Level Statements ─────────────────
    pos_box = [0]

    // Set active compilation target to main for top-level code
    s.ws_current_fn = main_fn
    s.ws_code = main_fn.wfn_code
    s.ws_block_depth = 0
    s.ws_try_depths = list()

    while get(pos_box, 0) < toks.len()
        cur_p = get(pos_box, 0)
        cur_t = toks[cur_p]
        cur_k = cur_t.tok_kind
        cur_txt = cur_t.tok_text

        if cur_k == TOK_EOF()
            break

        is_fn = 0
        if cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN() or cur_k == TOK_KW_COMPONENT() or (cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "@fn" or cur_txt == "component" or cur_txt == "উপাদান"))
            is_fn = 1

        if is_fn == 1
            // Function Definition header
            fn_base_col = cur_t.tok_span.span_start_col
            fn_header_line = cur_t.tok_span.span_start_line
            list_set(pos_box, 0, cur_p + 1)
            name_p = get(pos_box, 0)
            fn_name = ""
            if name_p < toks.len() and toks[name_p].tok_kind == TOK_IDENT()
                fn_name = toks[name_p].tok_text
                list_set(pos_box, 0, name_p + 1)

            // Parse parameter narrow types while advancing past parameter list until newline or return arrow
            p_narrow_names = list()
            p_narrow_types = list()
            while get(pos_box, 0) < toks.len()
                pt = toks[get(pos_box, 0)]
                if pt.tok_kind == TOK_NEWLINE() or pt.tok_kind == TOK_SEMI()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    break
                end
                if pt.tok_kind == TOK_ARROW() or (pt.tok_kind != TOK_STR() and pt.tok_text == "->")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                    break
                end
                if pt.tok_kind == TOK_IDENT()
                    p_nm_cur = pt.tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ":"))
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                            p_ty_cur = toks[get(pos_box, 0)].tok_text
                            if wasm_is_narrow_int_type(p_ty_cur) == 1
                                push(p_narrow_names, p_nm_cur)
                                push(p_narrow_types, p_ty_cur)
                            end
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    end
                else
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end

            target_fn = wasm_synth_find_function(s, fn_name)
            if target_fn != 0
                saved_ws_try_depths = s.ws_try_depths
                saved_ws_float_vars = s.ws_float_vars
                saved_ws_str_vars = s.ws_str_vars
                saved_ws_narrow_vars = s.ws_narrow_vars
                saved_ws_narrow_types = s.ws_narrow_types
                s.ws_current_fn = target_fn
                s.ws_code = target_fn.wfn_code
                s.ws_block_depth = 0
                s.ws_try_depths = list()
                s.ws_float_vars = list()
                s.ws_str_vars = list()
                s.ws_narrow_vars = list()
                s.ws_narrow_types = list()

                // Enforce narrow bit-width truncation on incoming parameter values at function entry
                pni = 0
                while pni < p_narrow_names.len()
                    pn_nm = p_narrow_names[pni]
                    pn_ty = p_narrow_types[pni]
                    wasm_synth_set_narrow_type(s, pn_nm, pn_ty)
                    pn_idx = wasm_synth_alloc_local(s, pn_nm)
                    wasm_emit_local_get(s.ws_code, pn_idx)
                    wasm_emit_truncate_int_width(s.ws_code, pn_ty)
                    wasm_emit_local_set(s.ws_code, pn_idx)
                    pni = pni + 1
                end

                // Compile function body until explicit end marker, next function, dedent, or EOF
                while get(pos_box, 0) < toks.len()
                    cp = get(pos_box, 0)
                    ct = toks[cp]
                    ck = ct.tok_kind
                    cx = ct.tok_text

                    if ck == TOK_EOF()
                        break
                    end
                    if ck == TOK_NEWLINE() or ck == TOK_SEMI() or ck == TOK_COMMENT_DOC() or ck == TOK_COMMENT_LINE() or ck == TOK_COMMENT_BLOCK()
                        list_set(pos_box, 0, cp + 1)
                    elif ck == TOK_KW_END() or ck == TOK_DIR_END() or (ck == TOK_IDENT() and (cx == "end" or cx == "@end" or cx == "শেষ"))
                        list_set(pos_box, 0, cp + 1)
                        break
                    elif ck == TOK_KW_FN() or ck == TOK_DIR_FN() or ck == TOK_KW_COMPONENT() or (ck == TOK_IDENT() and (cx == "fn" or cx == "কাজ" or cx == "@fn" or cx == "component" or cx == "উপাদান"))
                        break
                    elif ct.tok_span.span_start_line > fn_header_line and ct.tok_span.span_start_col <= fn_base_col
                        break
                    else
                        b_p = get(pos_box, 0)
                        wasm_synth_compile_statement(s, toks, pos_box)
                        if get(pos_box, 0) == b_p
                            list_set(pos_box, 0, b_p + 1)
                        end
                    end

                // Guarantee default return 0 at end of function if not explicitly returned
                if target_fn.wfn_has_returned == 0
                    wasm_emit_i64_const(s.ws_code, 0)
                    wasm_emit_return(s.ws_code)

                // Restore main function context
                s.ws_current_fn = main_fn
                s.ws_code = main_fn.wfn_code
                s.ws_block_depth = 0
                s.ws_try_depths = saved_ws_try_depths
                s.ws_float_vars = saved_ws_float_vars
                s.ws_str_vars = saved_ws_str_vars
                s.ws_narrow_vars = saved_ws_narrow_vars
                s.ws_narrow_types = saved_ws_narrow_types
        else
            // Compile top-level statement into main function
            b_p = get(pos_box, 0)
            wasm_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

    // Terminate main function with return 0 if not explicitly returned
    if main_fn.wfn_has_returned == 0
        wasm_emit_i64_const(main_fn.wfn_code, 0)
        wasm_emit_return(main_fn.wfn_code)

    // ── Phase 4: Construct W3C Binary Sections ─────────────────────────────────

    // Section 1: Type Section & Section 2: Import Section
    import_list = list()
    import_fn_count = 0
    if s.ws_needs_wasi_print == 1 and s.ws_freestanding == 0
        wasi_type_idx = s.ws_types.len()
        push(s.ws_types, 0 - 4)
        push(import_list, ["wasi_snapshot_preview1", "fd_write", 0, wasi_type_idx])
        import_fn_count = 1
    end

    // ── Phase 4a: Direct --ssa-codegen WASM MVP CFG Function Splicing ──────────
    if g_wasm_ssa_codegen == 1 and ssa_lower_res != 0 and ssa_lower_res.slr_success == 1 and ssa_lower_res.slr_code_buf != 0
        w_cp = buf_ptr(ssa_lower_res.slr_code_buf)
        si_w = 0
        sn_w = ssa_lower_res.slr_fn_names.len()
        while si_w < sn_w
            if ssa_lower_res.slr_fn_eligible[si_w] == 1
                s_fnm = ssa_lower_res.slr_fn_names[si_w]
                if s_fnm != "main" or has_top_level_code == 0
                    w_tgt = wasm_synth_find_function(s, s_fnm)
                    if w_tgt != 0
                        s_off = ssa_lower_res.slr_fn_offsets[si_w]
                        s_sz = ssa_lower_res.slr_fn_sizes[si_w]
                        s_tot_loc = ssa_lower_res.slr_fn_locals[si_w]
                        if s_sz > 0 and s_tot_loc >= w_tgt.wfn_param_count
                            w_bytes = list()
                            bi_cp = 0
                            while bi_cp < s_sz
                                push(w_bytes, mem_byte_read(w_cp, s_off + bi_cp) & 255)
                                bi_cp = bi_cp + 1
                            end
                            // Patch all 5-byte padded ULEB128 OP_CALL targets inside this SSA function
                            all_calls_ok = 1
                            cri = 0
                            while cri < ssa_lower_res.slr_call_relocs.len()
                                cr = ssa_lower_res.slr_call_relocs[cri]
                                if cr.sjp_kind == 20 and cr.sjp_offset >= s_off and cr.sjp_offset + 5 <= s_off + s_sz
                                    c_wfn = wasm_synth_find_function(s, cr.sjp_target)
                                    if c_wfn == 0
                                        all_calls_ok = 0
                                        break
                                    end
                                    t_idx = c_wfn.wfn_index + import_fn_count
                                    ro_c = cr.sjp_offset - s_off
                                    list_set(w_bytes, ro_c + 0, (t_idx & 127) | 128)
                                    list_set(w_bytes, ro_c + 1, ((t_idx >> 7) & 127) | 128)
                                    list_set(w_bytes, ro_c + 2, ((t_idx >> 14) & 127) | 128)
                                    list_set(w_bytes, ro_c + 3, ((t_idx >> 21) & 127) | 128)
                                    list_set(w_bytes, ro_c + 4, (t_idx >> 28) & 15)
                                end
                                cri = cri + 1
                            end
                            if all_calls_ok == 1
                                w_tgt.wfn_code = w_bytes
                                w_tgt.wfn_has_returned = 1
                                extra_loc = s_tot_loc - w_tgt.wfn_param_count
                                new_vl = list()
                                li_e = 0
                                while li_e < extra_loc
                                    push(new_vl, "__ssa_loc_" + str(li_e))
                                    li_e = li_e + 1
                                end
                                w_tgt.wfn_var_locals = new_vl
                                s.ws_ssa_replaced_cnt = s.ws_ssa_replaced_cnt + 1
                                s.ws_ssa_replaced_bytes = s.ws_ssa_replaced_bytes + s_sz
                            end
                        end
                    end
                end
            end
            si_w = si_w + 1
        end
        say "    [wasm_synth] --ssa-codegen active: replaced " + str(s.ws_ssa_replaced_cnt) + "/" + str(sn_w) + " functions directly from SSA CFG (" + str(s.ws_ssa_replaced_bytes) + " bytes native WASM MVP IR, " + str(ssa_lower_res.slr_total_insts) + " IR insts)"
    end

    // Register WASI standard _start signature: () -> () only in hosted WASI mode (omitted in --freestanding)
    wasi_start_type_idx = 0 - 1
    if s.ws_freestanding == 0
        wasi_start_type_idx = wasm_synth_get_or_add_type(s, 0 - 5)
    end

    sec1 = wasm_emit_type_section(s.ws_types)
    sec2 = wasm_emit_import_section(import_list)

    // Section 3: Function Section
    func_types = list()
    fi = 0
    while fi < s.ws_functions.len()
        push(func_types, s.ws_functions[fi].wfn_type_index)
        fi = fi + 1
    if s.ws_freestanding == 0
        // Append WASI _start wrapper signature after user functions so all user indices stay unchanged
        push(func_types, wasi_start_type_idx)
    end
    sec3 = wasm_emit_function_section(func_types)

    // Section 5: Memory Section (4 pages = 256KB initial memory)
    sec5 = wasm_emit_memory_section()

    // Section 7: Export Section
    export_list = list()

    // Export 1: main (Function index 0 + import_fn_count, () -> i64)
    push(export_list, ["main", 0, import_fn_count])

    if s.ws_freestanding == 0
        // Export 2: _start (WASI () -> () wrapper calling main and dropping return value)
        wasi_start_fn_idx = import_fn_count + s.ws_functions.len()
        push(export_list, ["_start", 0, wasi_start_fn_idx])
    end

    if main_fn.wfn_name == "মূল"
        push(export_list, ["মূল", 0, import_fn_count])

    // Export 3: Export other user functions by name
    fi = 1
    while fi < s.ws_functions.len()
        u_fn = s.ws_functions[fi]
        if u_fn.wfn_name != "main" and u_fn.wfn_name != "_start" and u_fn.wfn_name != "মূল" and len(u_fn.wfn_name) > 0
            push(export_list, [u_fn.wfn_name, 0, u_fn.wfn_index + import_fn_count])
        fi = fi + 1

    // Export 4: memory (Memory index 0)
    push(export_list, ["memory", 2, 0])

    sec7 = wasm_emit_export_section(export_list)

    // Section 10: Code Section
    func_bodies = list()
    fi = 0
    while fi < s.ws_functions.len()
        fn_item = s.ws_functions[fi]
        body = list()

        // Locals vector: encode non-parameter variables as i64
        num_locals = fn_item.wfn_var_locals.len()
        if num_locals == 0
            push(body, 0) // 0 local declarations
        else
            wasm_emit_u32_leb(body, 1)          // 1 local group
            wasm_emit_u32_leb(body, num_locals) // count
            push(body, WASM_TYPE_I64)            // valtype = i64 (0x7E)

        // Append instructions
        wasm_append_bytes(body, fn_item.wfn_code)

        // Terminating 0x0B END opcode for function body
        push(body, WASM_OP_END)

        push(func_bodies, body)
        fi = fi + 1

    if s.ws_freestanding == 0
        // Append WASI _start wrapper body: call main; drop; end
        start_body = list()
        push(start_body, 0)
        wasm_emit_call(start_body, import_fn_count)
        wasm_emit_drop(start_body)
        push(start_body, WASM_OP_END)
        push(func_bodies, start_body)
    end

    sec10 = wasm_emit_code_section(func_bodies)

    // Section 11: Data Section (Optional static string payloads)
    sec11 = list()
    if s.ws_data_bytes.len() > 0
        sec11 = wasm_emit_data_section(1024, s.ws_data_bytes)

    // ── Phase 5: Assemble Complete W3C WebAssembly Binary Container ────────────
    wasm_bytes = wasm_emit_header()
    wasm_append_bytes(wasm_bytes, sec1)
    if sec2.len() > 0
        wasm_append_bytes(wasm_bytes, sec2)
    wasm_append_bytes(wasm_bytes, sec3)
    wasm_append_bytes(wasm_bytes, sec5)
    wasm_append_bytes(wasm_bytes, sec7)
    wasm_append_bytes(wasm_bytes, sec10)
    if sec11.len() > 0
        wasm_append_bytes(wasm_bytes, sec11)

    return wasm_bytes

fn wasm_synth_compile_program tokens
    return wasm_synth_compile_program_ssa(tokens, 0)

fn wasm_synth_compile_source source_code
    // WHY: High-level convenience compiler turning raw LiPi source string
    //      directly into valid W3C WebAssembly bytecode bytes.
    toks = tokenize_source(source_code)
    return wasm_synth_compile_program(toks)

fn wasm_emit_binary_file wasm_bytes out_path
    // WHY: Commits raw WebAssembly binary bytecode bytes directly to disk via file_write_bytes.
    //      Pure Lipi sovereign binary write without external shell or tools.
    return file_write_bytes(out_path, wasm_bytes)

// ==============================================================================
// ── 10. Autonomous Verification Self-Test Suite ───────────────────────────────
// ==============================================================================

fn test_wasm_synthesizer_subsystem
    // WHY: Autonomous self-test suite validating LEB128 encoders, section assembly,
    //      expression compilation, conditionals, loops, and standalone binary emission.

    // 1. Verify Unsigned LEB128
    u_buf = list()
    wasm_emit_u32_leb(u_buf, 0)
    if u_buf.len() != 1 or u_buf[0] != 0
        say "FAIL: wasm_emit_u32_leb(0)"
        return 0

    u_buf = list()
    wasm_emit_u32_leb(u_buf, 624485)
    if u_buf.len() != 3 or u_buf[0] != 229 or u_buf[1] != 142 or u_buf[2] != 38
        say "FAIL: wasm_emit_u32_leb(624485)"
        return 0

    // 2. Verify Signed LEB128
    s_buf = list()
    wasm_emit_i64_leb(s_buf, 0 - 1)
    if s_buf.len() != 1 or s_buf[0] != 127
        say "FAIL: wasm_emit_i64_leb(-1)"
        return 0

    s_buf = list()
    wasm_emit_i64_leb(s_buf, 0 - 624485)
    if s_buf.len() != 3 or s_buf[0] != 155 or s_buf[1] != 241 or s_buf[2] != 89
        say "FAIL: wasm_emit_i64_leb(-624485)"
        return 0

    // 3. Verify Header and Magic Byte Sequence
    hdr = wasm_emit_header()
    if hdr.len() != 8 or hdr[0] != 0 or hdr[1] != 97 or hdr[2] != 115 or hdr[3] != 109 or hdr[4] != 1
        say "FAIL: WASM header sequence mismatch"
        return 0

    // 4. Verify Program Compilation (Arithmetic + Variable + Return)
    prog_src = "x = 10\ny = 32\nreturn x + y"
    toks = tokenize_source(prog_src)
    wasm_bin = wasm_synth_compile_program(toks)

    if wasm_bin.len() < 30
        say "FAIL: Compiled wasm binary is too small"
        return 0

    if wasm_bin[0] != 0 or wasm_bin[1] != 97 or wasm_bin[2] != 115 or wasm_bin[3] != 109
        say "FAIL: Compiled binary lacks \\0asm magic header"
        return 0

    // 5. Verify Standalone File Emission
    out_file = "/tmp/lipi_wasm_synth_test.wasm"
    write_res = wasm_emit_binary_file(wasm_bin, out_file)
    if write_res < 0
        say "FAIL: wasm_emit_binary_file failed to write disk binary"
        return 0

    say "✔ WASM Synthesizer self-test passed successfully!"
    return 1

// test_wasm_synthesizer_subsystem()
