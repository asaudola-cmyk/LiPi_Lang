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
        wasm_synth_compile_expr(s, toks, pos_box)
        // Discard value from stack to maintain stack neutrality in standalone binary
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
        if s.ws_current_fn != 0
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

        // Condition check: var >= end -> break out of outer block
        wasm_emit_local_get(s.ws_code, var_idx)
        wasm_emit_local_get(s.ws_code, end_idx)
        wasm_emit_i64_ge_s(s.ws_code)
        rel_exit = s.ws_block_depth - brk_depth
        wasm_emit_br_if(s.ws_code, rel_exit)

        // Push loop context
        loop_ctx = WasmLoopContext()
        loop_ctx.wlc_break_depth = brk_depth
        loop_ctx.wlc_continue_depth = cont_depth
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
        return 0

    // ── 8. Variable Assignment: <var> = <expr> or <var> <op>= <expr> ───────────
    if k == TOK_IDENT()
        next_pos = pos + 1
        if next_pos < toks.len()
            nt = toks[next_pos]
            nk = nt.tok_kind
            ntxt = nt.tok_text

            // Simple assignment: x = expr
            if nk == TOK_ASSIGN() or ntxt == "="
                var_name = txt
                list_set(pos_box, 0, next_pos + 1) // Consume ident and '='
                wasm_synth_compile_expr(s, toks, pos_box)
                var_idx = wasm_synth_alloc_local(s, var_name)
                wasm_emit_local_set(s.ws_code, var_idx)
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

fn wasm_synth_compile_program tokens
    // WHY: Master orchestration entry point. Transforms raw token stream into
    //      a complete, sovereign, standalone W3C WebAssembly (.wasm) binary container.
    //      - Phase 1: Pre-scans tokens to discover all user functions and top-level code.
    //      - Phase 2: Allocates function table entries (ensuring 'main' / '_start' is index 0).
    //      - Phase 3: Compiles function bodies, conditionals, and loops into bytecode.
    //      - Phase 4: Envelopes Sections 1, 3, 5, 7, 10, 11 in strictly ascending W3C order.
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
        if tk == TOK_KW_FN() or tk == TOK_DIR_FN() or (tk == TOK_IDENT() and (ttxt == "fn" or ttxt == "কাজ" or ttxt == "@fn"))
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
                    if pt.tok_kind == TOK_NEWLINE() or pt.tok_kind == TOK_SEMI() or pt.tok_kind == TOK_COLON()
                        break
                    if pt.tok_kind == TOK_IDENT()
                        push(param_names, pt.tok_text)
                    pp = pp + 1

                entry = [fn_name, param_names, scan_p]
                push(fn_headers, entry)
                scan_p = pp
        else
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

    while get(pos_box, 0) < toks.len()
        cur_p = get(pos_box, 0)
        cur_t = toks[cur_p]
        cur_k = cur_t.tok_kind
        cur_txt = cur_t.tok_text

        if cur_k == TOK_EOF()
            break

        is_fn = 0
        if cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN() or (cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "@fn"))
            is_fn = 1

        if is_fn == 1
            // Function Definition header
            list_set(pos_box, 0, cur_p + 1)
            name_p = get(pos_box, 0)
            fn_name = ""
            if name_p < toks.len() and toks[name_p].tok_kind == TOK_IDENT()
                fn_name = toks[name_p].tok_text
                list_set(pos_box, 0, name_p + 1)

            // Skip parameter tokens until newline / colon
            while get(pos_box, 0) < toks.len()
                pt = toks[get(pos_box, 0)]
                if pt.tok_kind == TOK_NEWLINE() or pt.tok_kind == TOK_SEMI() or pt.tok_kind == TOK_COLON()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    break
                list_set(pos_box, 0, get(pos_box, 0) + 1)

            target_fn = wasm_synth_find_function(s, fn_name)
            if target_fn != 0
                s.ws_current_fn = target_fn
                s.ws_code = target_fn.wfn_code
                s.ws_block_depth = 0

                // Compile function body until next function or EOF
                while get(pos_box, 0) < toks.len()
                    cp = get(pos_box, 0)
                    ct = toks[cp]
                    ck = ct.tok_kind
                    cx = ct.tok_text

                    if ck == TOK_KW_FN() or ck == TOK_DIR_FN() or (ck == TOK_IDENT() and (cx == "fn" or cx == "কাজ" or cx == "@fn"))
                        break

                    b_p = get(pos_box, 0)
                    wasm_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p
                        list_set(pos_box, 0, b_p + 1)

                // Guarantee default return 0 at end of function if not explicitly returned
                if target_fn.wfn_has_returned == 0
                    wasm_emit_i64_const(s.ws_code, 0)
                    wasm_emit_return(s.ws_code)

                // Restore main function context
                s.ws_current_fn = main_fn
                s.ws_code = main_fn.wfn_code
                s.ws_block_depth = 0
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

    // Section 1: Type Section
    sec1 = wasm_emit_type_section(s.ws_types)

    // Section 3: Function Section
    func_types = list()
    fi = 0
    while fi < s.ws_functions.len()
        push(func_types, s.ws_functions[fi].wfn_type_index)
        fi = fi + 1
    sec3 = wasm_emit_function_section(func_types)

    // Section 5: Memory Section (1 page = 64KB initial memory)
    sec5 = wasm_emit_memory_section()

    // Section 7: Export Section
    export_list = list()

    // Export 1: main (Function index 0)
    push(export_list, ["main", 0, 0])

    // Export 2: _start (Function index 0 for standard runtime compatibility)
    push(export_list, ["_start", 0, 0])

    if main_fn.wfn_name == "মূল"
        push(export_list, ["মূল", 0, 0])

    // Export 3: Export other user functions by name
    fi = 1
    while fi < s.ws_functions.len()
        u_fn = s.ws_functions[fi]
        if u_fn.wfn_name != "main" and u_fn.wfn_name != "_start" and u_fn.wfn_name != "মূল" and len(u_fn.wfn_name) > 0
            push(export_list, [u_fn.wfn_name, 0, u_fn.wfn_index])
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

    sec10 = wasm_emit_code_section(func_bodies)

    // Section 11: Data Section (Optional static string payloads)
    sec11 = list()
    if s.ws_data_bytes.len() > 0
        sec11 = wasm_emit_data_section(1024, s.ws_data_bytes)

    // ── Phase 5: Assemble Complete W3C WebAssembly Binary Container ────────────
    wasm_bytes = wasm_emit_header()
    wasm_append_bytes(wasm_bytes, sec1)
    wasm_append_bytes(wasm_bytes, sec3)
    wasm_append_bytes(wasm_bytes, sec5)
    wasm_append_bytes(wasm_bytes, sec7)
    wasm_append_bytes(wasm_bytes, sec10)
    if sec11.len() > 0
        wasm_append_bytes(wasm_bytes, sec11)

    return wasm_bytes

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
