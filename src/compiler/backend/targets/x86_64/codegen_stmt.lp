// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/x86_64/codegen_stmt.lp
// ==============================================================================

// ── 7. Statement Synthesizer ──────────────────────────────────────────────────

fn x86_synth_emit_defers s toks
    // WHY: Emits all registered defer statements in strict LIFO order while preserving
    // the pending return value in %rax across arbitrary cleanup calls/statements.
    // On normal exit from a function with defer unwind frame, pops our exc frame first
    // so exceptions inside defer bodies propagate cleanly to callers without looping.
    if s.synth_emitting_defer == 1
        return 0
    end
    if s.synth_has_defer_unwind == 1 and s.synth_in_defer_unwind_pad == 0
        x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rax; sub rsp, 8
        x86_synth_emit_call_helper(s, "_lipi_exc_pop")
        x86_synth_emit_bytes(s, [72, 131, 196, 8, 88]) // add rsp, 8; pop rax
    end
    if s.synth_defer_starts.len() == 0
        return 0
    end
    s.synth_emitting_defer = 1
    ret_save_off = x86_synth_alloc_var(s, "__defer_ret_save")
    x86_synth_emit_store_var(s, 0, ret_save_off)
    di = s.synth_defer_starts.len() - 1
    while di >= 0
        d_skip_patch = 0 - 1
        if s.synth_has_defer_unwind == 1 and di < 64
            // bt qword ptr [rbp - defer_mask_off], di; jnc skip_defer
            x86_synth_emit_bytes(s, [72, 15, 186, 165])
            x86_synth_emit_u32(s, 0 - s.synth_defer_mask_off)
            x86_synth_emit_byte(s, di)
            x86_synth_emit_bytes(s, [15, 131]) // jnc rel32
            d_skip_patch = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            s.synth_last_store_end = 0 - 1
        end
        d_pos = [s.synth_defer_starts[di]]
        d_end = s.synth_defer_ends[di]
        while get(d_pos, 0) < d_end
            x86_synth_skip_whitespace_tokens(toks, d_pos)
            cur_d = get(d_pos, 0)
            if cur_d >= d_end
                break
            end
            x86_synth_compile_statement(s, toks, d_pos)
            if get(d_pos, 0) <= cur_d
                list_set(d_pos, 0, cur_d + 1)
            end
        end
        if d_skip_patch >= 0
            d_after_off = s.synth_code.len()
            x86_synth_patch_u32(s, d_skip_patch, d_after_off - (d_skip_patch + 4))
            s.synth_last_store_end = 0 - 1
        end
        di = di - 1
    end
    x86_synth_emit_load_var(s, 0, ret_save_off)
    s.synth_emitting_defer = 0
    return 0

fn x86_synth_emit_defers_range s toks start_idx
    // WHY: Replays deferred statements registered within a `try` scope (indices [start_idx .. len-1])
    // in strict LIFO order upon exiting the `try/catch/finally` statement (normal exit, caught throw,
    // uncaught rethrow, or return inside try). Uses x86-64 `btr` (bit test & reset) on defer_mask so
    // each defer runs at most once and is NEVER double-executed at enclosing function exit, while still
    // running on the function unwind pad if `catch` throws a new exception before reaching this point!
    if s.synth_emitting_defer == 1
        return 0
    end
    cur_len = s.synth_defer_starts.len()
    if cur_len <= start_idx
        return 0
    end
    s.synth_emitting_defer = 1
    ret_save_off = x86_synth_alloc_var(s, "__defer_try_ret_save")
    x86_synth_emit_store_var(s, 0, ret_save_off)
    di = cur_len - 1
    while di >= start_idx
        d_skip_patch = 0 - 1
        if s.synth_has_defer_unwind == 1 and di < 64
            // btr qword ptr [rbp - defer_mask_off], di; jnc skip_defer (atomic test-and-clear!)
            x86_synth_emit_bytes(s, [72, 15, 186, 181])
            x86_synth_emit_u32(s, 0 - s.synth_defer_mask_off)
            x86_synth_emit_byte(s, di)
            x86_synth_emit_bytes(s, [15, 131]) // jnc rel32
            d_skip_patch = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            s.synth_last_store_end = 0 - 1
        end
        d_pos = [s.synth_defer_starts[di]]
        d_end = s.synth_defer_ends[di]
        while get(d_pos, 0) < d_end
            x86_synth_skip_whitespace_tokens(toks, d_pos)
            cur_d = get(d_pos, 0)
            if cur_d >= d_end
                break
            end
            x86_synth_compile_statement(s, toks, d_pos)
            if get(d_pos, 0) <= cur_d
                list_set(d_pos, 0, cur_d + 1)
            end
        end
        if d_skip_patch >= 0
            d_after_off = s.synth_code.len()
            x86_synth_patch_u32(s, d_skip_patch, d_after_off - (d_skip_patch + 4))
            s.synth_last_store_end = 0 - 1
        end
        di = di - 1
    end
    // If function has no defer_mask (e.g. closure), trim replayed entries so epilogue won't double-run them
    if s.synth_has_defer_unwind == 0
        while s.synth_defer_starts.len() > start_idx
            s.synth_defer_starts = pop(s.synth_defer_starts)
            s.synth_defer_ends = pop(s.synth_defer_ends)
        end
    end
    x86_synth_emit_load_var(s, 0, ret_save_off)
    s.synth_emitting_defer = 0
    return 0

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

    // ── 0.0 External Function Declaration: `extern fn name(a: i64, ...) -> ret` ──
    if k == TOK_IDENT() and (txt == "extern" or txt == "বাহ্যিক") and pos + 1 < toks.len() and (toks[pos + 1].tok_kind == TOK_KW_FN() or toks[pos + 1].tok_kind == TOK_DIR_FN() or (toks[pos + 1].tok_kind == TOK_IDENT() and (toks[pos + 1].tok_text == "fn" or toks[pos + 1].tok_text == "কাজ" or toks[pos + 1].tok_text == "@fn")))
        // Syntax: `extern fn foo(a: i64, b: i64) -> i64` (emits SHN_UNDEF + R_X86_64_PLT32 in .o!)
        list_set(pos_box, 0, pos + 2)
        ext_name = ""
        if get(pos_box, 0) < toks.len() and x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
            ext_name = toks[get(pos_box, 0)].tok_text
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        ext_pcount = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
            list_set(pos_box, 0, get(pos_box, 0) + 1)
            while get(pos_box, 0) < toks.len()
                etk = toks[get(pos_box, 0)]
                if etk.tok_kind == TOK_RPAREN() or etk.tok_text == ")"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    break
                elif etk.tok_kind == TOK_COLON() or etk.tok_text == ":"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    x86_synth_parse_type_expr(toks, pos_box)
                elif etk.tok_kind == TOK_COMMA() or etk.tok_text == "," or etk.tok_kind == TOK_NEWLINE()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                elif x86_synth_is_ident_token(etk.tok_kind) == 1
                    ext_pcount = ext_pcount + 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                else
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
        end
        ext_ret = ""
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_ARROW() or toks[get(pos_box, 0)].tok_text == "->" or toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
            list_set(pos_box, 0, get(pos_box, 0) + 1)
            ext_ret = x86_synth_parse_type_expr(toks, pos_box)
        end
        if ext_name != ""
            push(s.synth_extern_fns, ext_name)
            if x86_synth_find_fn_first(s, ext_name) == 0
                efn = X86Function()
                efn.fn_name = ext_name
                efn.fn_entry_offset = 0 - 1
                efn.fn_ret_type = ext_ret
                efn.fn_end_offset = 0
                efn.fn_decl_line = 0
                efn.fn_param_count = ext_pcount
                efn.fn_tok_pos = 0 - 1
                efn.fn_param_types = list()
                efn.fn_type_params = list()
                efn.fn_type_bounds = list()
                efn.fn_section = ""
                x86_synth_register_fn_obj(s, efn)
            end
        end
        return 0
    end

    // ── 0. Sovereign Silicon & Hardware Layout Directives (@asm, @naked, @interrupt, @packed, @align, @bss, @ring0, @layout, @section) ──
    if k == TOK_IDENT() and len(txt) >= 2 and mem_byte_read(txt, 0) == 64
        if txt == "@asm" or txt == "@অ্যাসেম্বলি"
            return x86_synth_compile_asm_stmt(s, toks, pos_box)
        elif txt == "@naked"
            s.synth_pending_fn_naked = 1
            list_set(pos_box, 0, pos + 1)
            return 0
        elif txt == "@interrupt"
            s.synth_pending_fn_interrupt = 1
            list_set(pos_box, 0, pos + 1)
            return 0
        elif txt == "@packed"
            s.synth_pending_struct_packed = 1
            list_set(pos_box, 0, pos + 1)
            return 0
        elif txt == "@ring0" or txt == "@silicon" or txt == "@strict" or txt == "@fn_strict" or txt == "@strict_types" or txt == "@strict_ownership" or txt == "@strict_proof" or txt == "@kavach" or txt == "@freestanding" or str_starts_with(txt, "@attr_") == 1
            list_set(pos_box, 0, pos + 1)
            return 0
        elif txt == "@align"
            list_set(pos_box, 0, pos + 1)
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            ap = get(pos_box, 0)
            if ap < toks.len() and (toks[ap].tok_kind == TOK_LPAREN() or toks[ap].tok_text == "(")
                list_set(pos_box, 0, ap + 1)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_INT()
                    s.synth_pending_struct_align = toks[get(pos_box, 0)].tok_int_val
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or toks[get(pos_box, 0)].tok_text == ")")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            elif ap < toks.len() and toks[ap].tok_kind == TOK_INT()
                s.synth_pending_struct_align = toks[ap].tok_int_val
                list_set(pos_box, 0, ap + 1)
            end
            return 0
        elif txt == "@layout"
            list_set(pos_box, 0, pos + 1)
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    lp = get(pos_box, 0)
                    if lp >= toks.len() break end
                    lt = toks[lp]
                    if lt.tok_kind == TOK_RPAREN() or lt.tok_text == ")"
                        list_set(pos_box, 0, lp + 1)
                        break
                    elif lt.tok_kind == TOK_COMMA() or lt.tok_text == ","
                        list_set(pos_box, 0, lp + 1)
                    elif x86_synth_is_ident_token(lt.tok_kind) == 1
                        lkey = lt.tok_text
                        list_set(pos_box, 0, lp + 1)
                        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_ASSIGN() or toks[get(pos_box, 0)].tok_text == "=" or toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_INT()
                            lval = toks[get(pos_box, 0)].tok_int_val
                            if lkey == "base" or lkey == "base_addr"
                                s.synth_layout_base = lval
                            elif lkey == "stack" or lkey == "stack_size"
                                s.synth_layout_stack = lval
                            end
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    else
                        list_set(pos_box, 0, lp + 1)
                    end
                end
            end
            return 0
        elif txt == "@section"
            // Syntax: `@section(".boot")` — assigns custom ELF/PE section placement to next fn/data
            list_set(pos_box, 0, pos + 1)
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_STR() or x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1)
                    s.synth_pending_section = toks[get(pos_box, 0)].tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or toks[get(pos_box, 0)].tok_text == ")")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_STR()
                s.synth_pending_section = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            return 0
        elif txt == "@bss"
            // Syntax: `@bss [@align(N)] [static] name: [N]T` or `@align(N) @bss [static] name: StructType`
            list_set(pos_box, 0, pos + 1)
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            bss_al = s.synth_pending_struct_align
            s.synth_pending_struct_align = 0
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "@align"
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LPAREN() or toks[get(pos_box, 0)].tok_text == "(")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_INT()
                        bss_al = toks[get(pos_box, 0)].tok_int_val
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or toks[get(pos_box, 0)].tok_text == ")")
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_INT()
                    bss_al = toks[get(pos_box, 0)].tok_int_val
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                x86_synth_skip_whitespace_tokens(toks, pos_box)
            end
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_text == "static"
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
            end
            if get(pos_box, 0) < toks.len() and x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                bss_nm = toks[get(pos_box, 0)].tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                bss_type = "[64]u8"
                has_raw_bss_sz = 0
                raw_bss_sz = 64
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    bss_type = x86_synth_parse_type_expr(toks, pos_box)
                elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_INT()
                    raw_bss_sz = toks[get(pos_box, 0)].tok_int_val
                    if raw_bss_sz <= 0
                        raw_bss_sz = 64
                    end
                    has_raw_bss_sz = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                if has_raw_bss_sz == 1
                    bal = 16
                    if bss_al > bal bal = bss_al end
                    x86_synth_alloc_bss(s, bss_nm, raw_bss_sz, bal, 1, 0, "")
                else
                    bss_sd = x86_synth_find_struct(s, bss_type)
                    if bss_sd != 0
                        bsz = bss_sd.sd_total_size
                        if bsz <= 0 bsz = 64 end
                        if bss_al < bss_sd.sd_align bss_al = bss_sd.sd_align end
                        x86_synth_alloc_bss(s, bss_nm, bsz, bss_al, 0, 0, bss_sd.sd_name)
                    else
                        binfo = x86_synth_type_layout_info(s, bss_type)
                        bsz = binfo[0]
                        bal = binfo[1]
                        bel = binfo[2]
                        bsgn = binfo[3]
                        if bss_al > bal bal = bss_al end
                        x86_synth_alloc_bss(s, bss_nm, bsz, bal, bel, bsgn, "")
                    end
                end
            end
            return 0
        end
    end

    // WHY: Record real source line -> machine-code PC mappings for DWARF v4 .debug_line
    stmt_src_line = t.tok_span.span_start_line
    if stmt_src_line > 0
        cur_pc_line = s.synth_code.len()
        if s.synth_line_pcs.len() == 0
            push(s.synth_line_pcs, cur_pc_line)
            push(s.synth_line_nums, stmt_src_line)
        else
            last_lp_idx = s.synth_line_pcs.len() - 1
            if cur_pc_line > s.synth_line_pcs[last_lp_idx] and stmt_src_line != s.synth_line_nums[last_lp_idx]
                push(s.synth_line_pcs, cur_pc_line)
                push(s.synth_line_nums, stmt_src_line)
            elif cur_pc_line == s.synth_line_pcs[last_lp_idx]
                list_set(s.synth_line_nums, last_lp_idx, stmt_src_line)
            end
        end
    end

    // ── 1. Output Statement: canonical TOK_KW_PRINT (say/বলো/print/println/দেখাও/@say/@print) + show ──
    is_print = 0
    if k == TOK_KW_PRINT() or (k == TOK_IDENT() and txt == "show")
        is_print = 1
    end

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
        if s.synth_last_expr_type == "float"
            x86_synth_emit_call_helper(s, "_lipi_print_float")
        elif s.synth_last_expr_type == "uint"
            x86_synth_emit_call_helper(s, "_lipi_print_uint")
        elif s.synth_last_expr_type == "dyn_tagged"
            x86_synth_emit_bytes(s, [72, 137, 214]) // mov rsi, rdx (val_tag)
            x86_synth_emit_call_helper(s, "_lipi_print_tagged")
        else
            x86_synth_emit_call_helper(s, "_lipi_print_dynamic")
        end
        return 0

    // ── 2. Control Flow: return / ফেরত ─────────────────────────────────────────
    if k == TOK_KW_RETURN() or (k == TOK_IDENT() and (txt == "return" or txt == "ফেরত"))
        list_set(pos_box, 0, pos + 1) // Consume keyword
        next_pos = get(pos_box, 0)
        has_expr = 0
        if next_pos < toks.len()
            nt = toks[next_pos]
            if nt.tok_kind != TOK_NEWLINE() and nt.tok_kind != TOK_SEMI() and nt.tok_kind != TOK_EOF() and nt.tok_kind != TOK_RBRACE() and (nt.tok_kind == TOK_STR() or nt.tok_text != "}")
                has_expr = 1

        ret_expr_t = ""
        if has_expr == 1
            ret_ln = t.tok_span.span_start_line
            x86_synth_compile_expr(s, toks, pos_box)
            // Tuple return: `return e1, e2 [, ...]` packs values into a first-class list
            cp_rt = get(pos_box, 0)
            if cp_rt < toks.len() and (toks[cp_rt].tok_kind == TOK_COMMA() or (toks[cp_rt].tok_kind != TOK_STR() and toks[cp_rt].tok_text == ",")) and toks[cp_rt].tok_span.span_start_line == ret_ln
                x86_synth_emit_byte(s, 80) // push rax
                rt_cnt = 1
                while get(pos_box, 0) < toks.len()
                    cp_r2 = get(pos_box, 0)
                    if (toks[cp_r2].tok_kind == TOK_COMMA() or (toks[cp_r2].tok_kind != TOK_STR() and toks[cp_r2].tok_text == ",")) and toks[cp_r2].tok_span.span_start_line == ret_ln
                        list_set(pos_box, 0, cp_r2 + 1)
                        x86_synth_compile_expr(s, toks, pos_box)
                        x86_synth_emit_byte(s, 80) // push rax
                        rt_cnt = rt_cnt + 1
                    else
                        break
                    end
                end
                x86_synth_emit_mov_rdi_imm64(s, rt_cnt)
                x86_synth_emit_bytes(s, [49, 246]) // xor esi, esi
                x86_synth_emit_call_helper(s, "_lipi_list_create")
                x86_synth_emit_bytes(s, [73, 137, 194]) // mov r10, rax
                x86_synth_emit_bytes(s, [76, 139, 88, 16]) // mov r11, [rax + 16]
                ri_t = rt_cnt - 1
                while ri_t >= 0
                    x86_synth_emit_byte(s, 88) // pop rax
                    r_off = ri_t * 8
                    if r_off < 128
                        x86_synth_emit_bytes(s, [73, 137, 67, r_off])
                    else
                        x86_synth_emit_bytes(s, [73, 137, 131])
                        x86_synth_emit_u32(s, r_off)
                    end
                    ri_t = ri_t - 1
                end
                x86_synth_emit_bytes(s, [76, 137, 208]) // mov rax, r10
                s.synth_last_expr_type = ""
                s.synth_last_struct = ""
            end
            ret_expr_t = s.synth_last_expr_type
            if s.synth_current_fn_idx >= 0 and s.synth_current_fn_idx < s.synth_functions.len()
                ret_fn_obj = s.synth_functions[s.synth_current_fn_idx]
                if s.synth_last_struct != "" and (ret_fn_obj.fn_ret_type == "" or ret_fn_obj.fn_ret_type == "int")
                    ret_fn_obj.fn_ret_type = s.synth_last_struct
                elif ret_fn_obj.fn_ret_type == ""
                    if ret_expr_t == "float"
                        ret_fn_obj.fn_ret_type = "f64"
                    elif ret_expr_t == "uint"
                        ret_fn_obj.fn_ret_type = "u64"
                    elif ret_expr_t == "int" or ret_expr_t == "str" or ret_expr_t == "dyn_tagged"
                        ret_fn_obj.fn_ret_type = ret_expr_t
                    end
                elif ret_fn_obj.fn_ret_explicit == 1 and (ret_fn_obj.fn_ret_type == "f64" or ret_fn_obj.fn_ret_type == "float") and x86_synth_is_int_like(ret_expr_t) == 1
                    // WHY: Coerce integer return value to IEEE-754 f64 ONLY when function explicitly declared `-> f64`/`-> float`
                    // (Never coerce inferred unannotated float helpers like `fast_json_as_float` returning raw f64 bits from `get(node, 3)`!)
                    x86_synth_emit_bytes(s, [242, 72, 15, 42, 192, 102, 72, 15, 126, 192]) // cvtsi2sd xmm0, rax; movq rax, xmm0
                elif ret_fn_obj.fn_ret_type == "dyn_tagged" and ret_expr_t != "dyn_tagged"
                    // Keep (%rax, %rdx) tagged return ABI consistent across all return paths
                    if ret_expr_t == "float"
                        x86_synth_emit_bytes(s, [186, 1, 0, 0, 0]) // mov edx, 1
                    elif ret_expr_t == "str"
                        x86_synth_emit_bytes(s, [186, 2, 0, 0, 0]) // mov edx, 2
                    else
                        x86_synth_emit_bytes(s, [49, 210]) // xor edx, edx
                    end
                end
            end
        else
            // Default 0 return
            x86_synth_emit_byte(s, 49)
            x86_synth_emit_byte(s, 192)
            if s.synth_current_fn_idx >= 0 and s.synth_current_fn_idx < s.synth_functions.len() and s.synth_functions[s.synth_current_fn_idx].fn_ret_type == "dyn_tagged"
                x86_synth_emit_bytes(s, [49, 210]) // xor edx, edx
            end
        end

        if s.synth_try_frames.len() > 0
            cur_tframe = s.synth_try_frames[s.synth_try_frames.len() - 1]
            tf_flag_off = cur_tframe[0]
            tf_val_off = cur_tframe[1]
            tf_patches = cur_tframe[2]
            tf_entry_depth = cur_tframe[3]
            pops_ret = s.synth_try_depth - tf_entry_depth
            if pops_ret > 0
                x86_synth_emit_bytes(s, [80, 82]) // push rax; push rdx (16B aligned)
                ti_ret = 0
                while ti_ret < pops_ret
                    x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                    ti_ret = ti_ret + 1
                end
                x86_synth_emit_bytes(s, [90, 88]) // pop rdx; pop rax
            end
            x86_synth_emit_store_var(s, 0, tf_val_off)
            x86_synth_emit_bytes(s, [184, 2, 0, 0, 0]) // mov eax, 2
            x86_synth_emit_store_var(s, 0, tf_flag_off)
            x86_synth_emit_byte(s, 233) // jmp rel32 -> enclosing finally
            rj_off = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            push(tf_patches, rj_off)
            return 0
        end

        if s.synth_try_depth > 0
            x86_synth_emit_bytes(s, [80, 82]) // push rax; push rdx (16B aligned)
            ti_ret = 0
            while ti_ret < s.synth_try_depth
                x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                ti_ret = ti_ret + 1
            end
            x86_synth_emit_bytes(s, [90, 88]) // pop rdx; pop rax
        end

        if ret_expr_t == "dyn_tagged" and (s.synth_defer_starts.len() > 0 or s.synth_has_defer_unwind == 1)
            x86_synth_emit_bytes(s, [80, 82]) // push rax; push rdx across defer replay
            x86_synth_emit_defers(s, toks)
            x86_synth_emit_bytes(s, [90, 88]) // pop rdx; pop rax
        else
            x86_synth_emit_defers(s, toks)
        end
        x86_synth_emit_epilogue(s)
        return 0

    // ── 2b. Deferred Execution: canonical TOK_KW_DEFER (defer / @defer / বিলম্ব) ─
    is_defer_stmt = 0
    if k == TOK_KW_DEFER() or k == TOK_DIR_DEFER()
        if pos + 1 >= toks.len()
            is_defer_stmt = 1
        else
            dn = toks[pos + 1]
            if dn.tok_kind != TOK_ASSIGN() and dn.tok_text != "=" and dn.tok_kind != TOK_LPAREN() and dn.tok_text != "(" and dn.tok_kind != TOK_DOT() and dn.tok_text != "."
                is_defer_stmt = 1
            end
        end
    end
    if is_defer_stmt == 1
        d_line = t.tok_span.span_start_line
        d_col = t.tok_span.span_start_col
        list_set(pos_box, 0, pos + 1)
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        d_start = get(pos_box, 0)
        d_scan = d_start
        if d_start < toks.len()
            dt0 = toks[d_start]
            if dt0.tok_kind == TOK_LBRACE() or (dt0.tok_kind != TOK_STR() and dt0.tok_text == "{")
                // Braced defer block: `defer { stmt1; stmt2 }`
                bd_def = 1
                d_scan = d_start + 1
                while d_scan < toks.len() and bd_def > 0
                    bt_d = toks[d_scan]
                    if bt_d.tok_kind == TOK_LBRACE() or (bt_d.tok_kind != TOK_STR() and bt_d.tok_text == "{")
                        bd_def = bd_def + 1
                    elif bt_d.tok_kind == TOK_RBRACE() or (bt_d.tok_kind != TOK_STR() and bt_d.tok_text == "}")
                        bd_def = bd_def - 1
                        if bd_def == 0 break end
                    end
                    d_scan = d_scan + 1
                end
                d_idx_br = s.synth_defer_starts.len()
                push(s.synth_defer_starts, d_start + 1)
                push(s.synth_defer_ends, d_scan)
                if s.synth_has_defer_unwind == 1 and d_idx_br < 64
                    x86_synth_emit_bytes(s, [72, 15, 186, 173])
                    x86_synth_emit_u32(s, 0 - s.synth_defer_mask_off)
                    x86_synth_emit_byte(s, d_idx_br)
                    s.synth_last_store_end = 0 - 1
                end
                if d_scan < toks.len() and (toks[d_scan].tok_kind == TOK_RBRACE() or toks[d_scan].tok_text == "}")
                    list_set(pos_box, 0, d_scan + 1)
                else
                    list_set(pos_box, 0, d_scan)
                end
                return 0
            end
            is_block_defer = 0
            if dt0.tok_span.span_start_line > d_line
                is_block_defer = 1
            elif dt0.tok_kind == TOK_KW_IF() or dt0.tok_kind == TOK_KW_WHILE() or dt0.tok_kind == TOK_KW_FOR() or dt0.tok_kind == TOK_KW_MATCH() or dt0.tok_kind == TOK_KW_TRY() or dt0.tok_kind == TOK_DIR_IF() or dt0.tok_kind == TOK_DIR_WHILE() or dt0.tok_kind == TOK_DIR_FOR() or dt0.tok_kind == TOK_DIR_MATCH() or dt0.tok_kind == TOK_DIR_TRY()
                is_block_defer = 1
            elif dt0.tok_kind == TOK_IDENT() and (dt0.tok_text == "if" or dt0.tok_text == "while" or dt0.tok_text == "for" or dt0.tok_text == "repeat" or dt0.tok_text == "match" or dt0.tok_text == "try")
                is_block_defer = 1
            end
            if is_block_defer == 1
                blk_depth = 0
                while d_scan < toks.len()
                    bt = toks[d_scan]
                    bk = bt.tok_kind
                    btxt = bt.tok_text
                    if bk == TOK_EOF()
                        break
                    end
                    if dt0.tok_span.span_start_line > d_line and blk_depth == 0 and bt.tok_span.span_start_line > d_line and bt.tok_span.span_start_col <= d_col
                        if x86_synth_is_block_end(toks, d_scan) == 1
                            list_set(pos_box, 0, d_scan + 1)
                            d_idx_b = s.synth_defer_starts.len()
                            push(s.synth_defer_starts, d_start)
                            push(s.synth_defer_ends, d_scan)
                            if s.synth_has_defer_unwind == 1 and d_idx_b < 64
                                // bts qword ptr [rbp - defer_mask_off], d_idx_b
                                x86_synth_emit_bytes(s, [72, 15, 186, 173])
                                x86_synth_emit_u32(s, 0 - s.synth_defer_mask_off)
                                x86_synth_emit_byte(s, d_idx_b)
                                s.synth_last_store_end = 0 - 1
                            end
                            return 0
                        end
                        break
                    end
                    if bk == TOK_KW_IF() or bk == TOK_KW_WHILE() or bk == TOK_KW_FOR() or bk == TOK_KW_MATCH() or bk == TOK_KW_TRY() or bk == TOK_DIR_IF() or bk == TOK_DIR_WHILE() or bk == TOK_DIR_FOR() or bk == TOK_DIR_MATCH() or bk == TOK_DIR_TRY() or (bk == TOK_IDENT() and (btxt == "if" or btxt == "while" or btxt == "for" or btxt == "repeat" or btxt == "match" or btxt == "try"))
                        blk_depth = blk_depth + 1
                    elif x86_synth_is_block_end(toks, d_scan) == 1
                        blk_depth = blk_depth - 1
                        if blk_depth <= 0 and dt0.tok_span.span_start_line == d_line
                            d_scan = d_scan + 1
                            break
                        end
                    end
                    d_scan = d_scan + 1
                end
            else
                paren_d = 0
                while d_scan < toks.len()
                    st_d = toks[d_scan]
                    sk_d = st_d.tok_kind
                    stxt_d = st_d.tok_text
                    if sk_d == TOK_EOF()
                        break
                    end
                    if sk_d == TOK_LPAREN() or sk_d == TOK_LBRACKET() or sk_d == TOK_LBRACE() or stxt_d == "(" or stxt_d == "[" or stxt_d == "{"
                        paren_d = paren_d + 1
                    elif sk_d == TOK_RPAREN() or sk_d == TOK_RBRACKET() or sk_d == TOK_RBRACE() or stxt_d == ")" or stxt_d == "]" or stxt_d == "}"
                        if paren_d > 0
                            paren_d = paren_d - 1
                        else
                            // Stop before enclosing block's closing '}' / ')' / ']'
                            break
                        end
                    elif paren_d == 0 and (sk_d == TOK_NEWLINE() or sk_d == TOK_SEMI() or sk_d == TOK_COMMENT_LINE())
                        break
                    end
                    d_scan = d_scan + 1
                end
            end
            d_idx_s = s.synth_defer_starts.len()
            push(s.synth_defer_starts, d_start)
            push(s.synth_defer_ends, d_scan)
            if s.synth_has_defer_unwind == 1 and d_idx_s < 64
                // bts qword ptr [rbp - defer_mask_off], d_idx_s
                x86_synth_emit_bytes(s, [72, 15, 186, 173])
                x86_synth_emit_u32(s, 0 - s.synth_defer_mask_off)
                x86_synth_emit_byte(s, d_idx_s)
                s.synth_last_store_end = 0 - 1
            end
            list_set(pos_box, 0, d_scan)
        end
        return 0
    end

    // ── 3. Loop Control: break / থামো & continue / চলুক ───────────────────────
    if k == TOK_KW_BREAK() or (k == TOK_IDENT() and (txt == "break" or txt == "থামো"))
        list_set(pos_box, 0, pos + 1)
        // WHY: If breaking out of a try/catch/finally block entered inside the active loop,
        // route through enclosing finally + try-scoped defers via fin_flag = 3!
        if s.synth_try_frames.len() > 0 and s.synth_loop_try_depths.len() > 0
            cur_tframe_b = s.synth_try_frames[s.synth_try_frames.len() - 1]
            l_td_b = s.synth_loop_try_depths[s.synth_loop_try_depths.len() - 1]
            if cur_tframe_b[3] >= l_td_b
                pops_brk = s.synth_try_depth - cur_tframe_b[3]
                ti_b = 0
                while ti_b < pops_brk
                    x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                    ti_b = ti_b + 1
                end
                x86_synth_emit_bytes(s, [184, 3, 0, 0, 0]) // mov eax, 3 (pending break)
                x86_synth_emit_store_var(s, 0, cur_tframe_b[0])
                x86_synth_emit_byte(s, 233) // jmp rel32 -> enclosing finally
                bj_off = s.synth_code.len()
                x86_synth_emit_u32(s, 0)
                push(cur_tframe_b[2], bj_off)
                return 0
            end
        end
        if s.synth_loop_try_depths.len() > 0
            l_td = s.synth_loop_try_depths[s.synth_loop_try_depths.len() - 1]
            diff_td = s.synth_try_depth - l_td
            ti_brk = 0
            while ti_brk < diff_td
                x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                ti_brk = ti_brk + 1
            end
        end
        if s.synth_loop_breaks.len() > 0
            x86_synth_emit_byte(s, 233) // jmp rel32
            p_off = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            curr_brk_list = s.synth_loop_breaks[s.synth_loop_breaks.len() - 1]
            push(curr_brk_list, p_off)
        return 0

    if k == TOK_KW_CONTINUE() or k == TOK_DIR_CONTINUE()
        list_set(pos_box, 0, pos + 1)
        // WHY: If continuing out of a try/catch/finally block entered inside the active loop,
        // route through enclosing finally + try-scoped defers via fin_flag = 4!
        if s.synth_try_frames.len() > 0 and s.synth_loop_try_depths.len() > 0
            cur_tframe_c = s.synth_try_frames[s.synth_try_frames.len() - 1]
            l_td_c = s.synth_loop_try_depths[s.synth_loop_try_depths.len() - 1]
            if cur_tframe_c[3] >= l_td_c
                pops_cnt = s.synth_try_depth - cur_tframe_c[3]
                ti_c = 0
                while ti_c < pops_cnt
                    x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                    ti_c = ti_c + 1
                end
                x86_synth_emit_bytes(s, [184, 4, 0, 0, 0]) // mov eax, 4 (pending continue)
                x86_synth_emit_store_var(s, 0, cur_tframe_c[0])
                x86_synth_emit_byte(s, 233) // jmp rel32 -> enclosing finally
                cj_off = s.synth_code.len()
                x86_synth_emit_u32(s, 0)
                push(cur_tframe_c[2], cj_off)
                return 0
            end
        end
        if s.synth_loop_try_depths.len() > 0
            l_td = s.synth_loop_try_depths[s.synth_loop_try_depths.len() - 1]
            diff_td = s.synth_try_depth - l_td
            ti_cnt = 0
            while ti_cnt < diff_td
                x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                ti_cnt = ti_cnt + 1
            end
        end
        if s.synth_loop_continues.len() > 0
            x86_synth_emit_byte(s, 233) // jmp rel32
            p_off = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            curr_cont_list = s.synth_loop_continues[s.synth_loop_continues.len() - 1]
            push(curr_cont_list, p_off)
        elif s.synth_loop_starts.len() > 0
            loop_hdr = s.synth_loop_starts[s.synth_loop_starts.len() - 1]
            x86_synth_emit_byte(s, 233) // jmp rel32
            next_ip = s.synth_code.len() + 4
            disp32 = loop_hdr - next_ip
            x86_synth_emit_u32(s, disp32)
        end
        return 0

    // ── 4. Struct / Union Definition: canonical TOK_KW_STRUCT + union ──
    is_struct = 0
    if k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT()
        is_struct = 1
    if k == TOK_IDENT() and (txt == "union" or txt == "ইউনিয়ন" or txt == "@union")
        is_struct = 1

    if is_struct == 1
        return x86_synth_compile_struct_def(s, toks, pos_box, t.tok_span.span_start_col, t.tok_span.span_start_line)

    // ── 4a. Trait / Impl Definition: canonical TOK_DIR_TRAIT & TOK_KW_IMPL ──
    if k == TOK_DIR_TRAIT() and pos + 1 < toks.len() and x86_synth_is_ident_token(toks[pos + 1].tok_kind) == 1 and toks[pos + 1].tok_span.span_start_line == t.tok_span.span_start_line
        return x86_synth_compile_trait_def(s, toks, pos_box, t.tok_span.span_start_col, t.tok_span.span_start_line)
    end
    if k == TOK_KW_IMPL() or k == TOK_DIR_IMPL()
        return x86_synth_compile_impl_block(s, toks, pos_box, t.tok_span.span_start_col, t.tok_span.span_start_line)
    end

    // ── 4a2. Pointer Dereference Assignment: *ptr_expr = rhs ───────────────────
    if (k == TOK_STAR() or (k != TOK_STR() and txt == "*")) and pos + 2 < toks.len()
        // Scan ahead to check if '=' appears on the same line after the pointer l-value
        dp_scan = pos + 1
        dp_pdepth = 0
        dp_eq_pos = 0 - 1
        dp_line = t.tok_span.span_start_line
        while dp_scan < toks.len()
            dpt = toks[dp_scan]
            dpk = dpt.tok_kind
            dpx = dpt.tok_text
            if dpk == TOK_NEWLINE() or dpk == TOK_SEMI() or dpk == TOK_EOF() or dpt.tok_span.span_start_line > dp_line
                break
            end
            if dpk == TOK_LPAREN() or dpx == "(" or dpk == TOK_LBRACKET() or dpx == "["
                dp_pdepth = dp_pdepth + 1
            elif dpk == TOK_RPAREN() or dpx == ")" or dpk == TOK_RBRACKET() or dpx == "]"
                if dp_pdepth > 0 dp_pdepth = dp_pdepth - 1 end
            elif dp_pdepth == 0 and (dpk == TOK_ASSIGN() or (dpk != TOK_STR() and dpx == "="))
                dp_eq_pos = dp_scan
                break
            end
            dp_scan = dp_scan + 1
        end
        if dp_eq_pos > pos + 1
            // Evaluate pointer expression into %rax
            list_set(pos_box, 0, pos + 1)
            x86_synth_compile_expr(s, toks, pos_box)
            lhs_ptr_t = s.synth_last_struct
            if x86_synth_is_const_ptr_type(lhs_ptr_t) == 1
                say "❌ [Error]: Cannot write through immutable const pointer '" + lhs_ptr_t + "' at line " + str(dp_line)
                exit(1)
            end
            pt_w = x86_synth_ptr_pointee(lhs_ptr_t)
            if pt_w == "" pt_w = "i64" end
            st_sz = x86_synth_sizeof_type(s, pt_w)
            // Push target address (16B aligned), evaluate RHS, pop into %rcx, store exact width
            x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rax; sub rsp, 8
            list_set(pos_box, 0, dp_eq_pos + 1)
            x86_synth_compile_expr(s, toks, pos_box)
            x86_synth_emit_bytes(s, [72, 131, 196, 8, 89]) // add rsp, 8; pop rcx
            x86_synth_emit_null_check_rcx(s)
            x86_synth_emit_field_store_rcx_rax(s, 0, st_sz)
            s.synth_last_store_end = 0 - 1
            return 0
        end
    end

    // ── 4b. Enum / Tagged ADT Definition: canonical TOK_KW_ENUM ──────────────
    is_enum = 0
    if k == TOK_KW_ENUM() or k == TOK_DIR_ENUM()
        is_enum = 1

    if is_enum == 1
        return x86_synth_register_enum_from_tokens(s, toks, pos_box, t.tok_span.span_start_col, t.tok_span.span_start_line)

    // ── 5. Struct Field Assignment (arbitrary depth): obj.field = expr, obj.f1.f2 = expr
    // ── 5.0 Mixed / Multi-Level Chained L-Value Assignment: o.inn.arr[1] = 99, m[i][j] += 5, a[0].f = 7 ──
    if k == TOK_IDENT() and pos + 2 < toks.len()
        scan_lp = pos + 1
        lv_kinds = list()
        lv_fields = list()
        lv_starts = list()
        lv_has_brk = 0
        while scan_lp < toks.len()
            tlp = toks[scan_lp]
            tlp_k = tlp.tok_kind
            tlp_t = tlp.tok_text
            if (tlp_k == TOK_DOT() or (tlp_k != TOK_STR() and tlp_t == ".")) and scan_lp + 1 < toks.len() and x86_synth_is_ident_token(toks[scan_lp + 1].tok_kind) == 1
                push(lv_kinds, 0)
                push(lv_fields, toks[scan_lp + 1].tok_text)
                push(lv_starts, scan_lp + 1)
                scan_lp = scan_lp + 2
            elif tlp_k == TOK_LBRACKET() or (tlp_k != TOK_STR() and tlp_t == "[")
                b_dep = 1
                b_cur = scan_lp + 1
                while b_cur < toks.len() and b_dep > 0
                    bk_c = toks[b_cur].tok_kind
                    bt_c = toks[b_cur].tok_text
                    if bk_c == TOK_LBRACKET() or (bk_c != TOK_STR() and bt_c == "[")
                        b_dep = b_dep + 1
                    elif bk_c == TOK_RBRACKET() or (bk_c != TOK_STR() and bt_c == "]")
                        b_dep = b_dep - 1
                        if b_dep == 0
                            break
                        end
                    end
                    b_cur = b_cur + 1
                end
                if b_dep == 0 and b_cur < toks.len()
                    push(lv_kinds, 1)
                    push(lv_fields, "")
                    push(lv_starts, scan_lp + 1)
                    lv_has_brk = 1
                    scan_lp = b_cur + 1
                else
                    break
                end
            else
                break
            end
        end
        if lv_has_brk == 1 and lv_kinds.len() >= 2 and scan_lp < toks.len()
            lv_eq = toks[scan_lp]
            lve_k = lv_eq.tok_kind
            lve_t = lv_eq.tok_text
            lv_is_assign = 0
            lv_is_comp = 0
            lv_comp_op = 0
            if lve_k == TOK_ASSIGN() or (lve_k != TOK_STR() and lve_t == "=")
                lv_is_assign = 1
            elif lve_k == TOK_PLUSEQ() or lve_t == "+="
                lv_is_assign = 1
                lv_is_comp = 1
                lv_comp_op = TOK_PLUS()
            elif lve_k == TOK_MINUSEQ() or lve_t == "-="
                lv_is_assign = 1
                lv_is_comp = 1
                lv_comp_op = TOK_MINUS()
            elif lve_k == TOK_STAREQ() or lve_t == "*="
                lv_is_assign = 1
                lv_is_comp = 1
                lv_comp_op = TOK_STAR()
            elif lve_k == TOK_SLASHEQ() or lve_t == "/="
                lv_is_assign = 1
                lv_is_comp = 1
                lv_comp_op = TOK_SLASH()
            elif lve_k == TOK_PERCENTEQ() or lve_t == "%="
                lv_is_assign = 1
                lv_is_comp = 1
                lv_comp_op = TOK_PERCENT()
            end
            if lv_is_assign == 1
                root_name = txt
                lv_root = x86_synth_find_local_var(s, root_name)
                cur_stype = ""
                cur_el_t = ""
                if lv_root != 0 and lv_root.lv_is_spilled == 0 and lv_root.lv_reg >= 0
                    x86_synth_emit_mov_reg_reg(s, 0, lv_root.lv_reg)
                    cur_stype = x86_synth_get_var_type(s, root_name)
                    cur_el_t = x86_synth_get_elem_type(s, root_name)
                else
                    mg_root = x86_synth_find_mutable_global(s, root_name)
                    if lv_root == 0 and mg_root >= 512
                        x86_synth_emit_mutable_global_read(s, mg_root)
                        cur_stype = x86_synth_get_mutable_global_struct(s, root_name)
                    else
                        r_off = x86_synth_lookup_var(s, root_name)
                        if r_off > 0
                            x86_synth_emit_load_var(s, 0, r_off)
                        else
                            x86_synth_emit_bytes(s, [49, 192]) // xor eax, eax
                        end
                        cur_stype = x86_synth_get_var_type(s, root_name)
                        cur_el_t = x86_synth_get_elem_type(s, root_name)
                    end
                end

                // Walk intermediate segments 0 .. n_segs - 2 leaving final parent container in %rax
                n_lv = lv_kinds.len()
                si_lv = 0
                while si_lv < n_lv - 1
                    if lv_kinds[si_lv] == 0
                        m_fld = lv_fields[si_lv]
                        m_meta = x86_synth_get_field_meta(s, cur_stype, m_fld)
                        m_off = m_meta[0]
                        m_sz = m_meta[1]
                        m_sgn = m_meta[2]
                        m_el = m_meta[3]
                        m_ft = m_meta[4]
                        cur_stype = ""
                        cur_el_t = ""
                        if m_el > 0
                            cur_el_t = x86_synth_raw_elem_tag(m_el, m_sgn)
                        elif m_ft != "" and m_ft != "int" and m_ft != "i64" and m_ft != "i32" and m_ft != "i16" and m_ft != "i8" and m_ft != "u64" and m_ft != "u32" and m_ft != "u16" and m_ft != "u8" and m_ft != "float" and m_ft != "f64" and m_ft != "f32" and m_ft != "str" and m_ft != "string"
                            cur_stype = m_ft
                        end
                        x86_synth_emit_field_load_rax(s, m_off, m_sz, m_sgn, m_el)
                    else
                        // Index dereference with 16-byte stack alignment around index expression & call
                        x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rax; sub rsp, 8
                        idx_pb = [lv_starts[si_lv]]
                        x86_synth_compile_expr(s, toks, idx_pb)
                        x86_synth_emit_bytes(s, [72, 137, 198, 72, 131, 196, 8, 95]) // mov rsi, rax; add rsp, 8; pop rdi
                        raw_mi = x86_synth_parse_raw_elem_tag(cur_el_t)
                        if raw_mi[0] > 0
                            x86_synth_emit_raw_array_load(s, raw_mi[0], raw_mi[1])
                        else
                            x86_synth_emit_call_helper(s, "_lipi_list_get")
                        end
                        if cur_el_t != "" and cur_el_t != "int" and cur_el_t != "float" and cur_el_t != "str" and raw_mi[0] == 0
                            cur_stype = cur_el_t
                        else
                            cur_stype = ""
                        end
                        cur_el_t = ""
                    end
                    si_lv = si_lv + 1
                end

                leaf_i = n_lv - 1
                if lv_kinds[leaf_i] == 0
                    // Final write to struct field: <expr>.leaf_field op= rhs
                    x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rax (parent); sub rsp, 8
                    list_set(pos_box, 0, scan_lp + 1)
                    x86_synth_compile_expr(s, toks, pos_box)
                    lv_rhs_t = s.synth_last_expr_type
                    x86_synth_emit_bytes(s, [72, 131, 196, 8, 89]) // add rsp, 8; pop rcx (parent)
                    x86_synth_emit_null_check_rcx(s)
                    lf_name = lv_fields[leaf_i]
                    if x86_synth_is_const_ptr_type(cur_stype) == 1
                        say "❌ [Error]: Cannot mutate field '" + lf_name + "' through immutable const pointer '" + cur_stype + "'"
                        exit(1)
                    end
                    lf_meta = x86_synth_get_field_meta(s, cur_stype, lf_name)
                    lf_off = lf_meta[0]
                    lf_sz = lf_meta[1]
                    lf_ft = lf_meta[4]
                    lf_bo = 0
                    lf_bw = 0
                    if lf_meta.len() >= 7
                        lf_bo = lf_meta[5]
                        lf_bw = lf_meta[6]
                    end
                    if lv_is_comp == 1
                        x86_synth_emit_bytes(s, [73, 137, 192]) // mov r8, rax (rhs)
                        if lf_off < 128
                            x86_synth_emit_bytes(s, [72, 139, 65, lf_off])
                        else
                            x86_synth_emit_bytes(s, [72, 139, 129])
                            x86_synth_emit_u32(s, lf_off)
                        end
                        if lf_ft == "f64" or lf_ft == "f32" or lf_ft == "float" or lv_rhs_t == "float"
                            if lf_ft == "f64" or lf_ft == "f32" or lf_ft == "float"
                                x86_synth_emit_bytes(s, [102, 72, 15, 110, 192])
                            else
                                x86_synth_emit_bytes(s, [242, 72, 15, 42, 192])
                            end
                            if lv_rhs_t == "float"
                                x86_synth_emit_bytes(s, [102, 73, 15, 110, 200])
                            else
                                x86_synth_emit_bytes(s, [242, 73, 15, 42, 200])
                            end
                            if lv_comp_op == TOK_PLUS()
                                x86_synth_emit_bytes(s, [242, 15, 88, 193])
                            elif lv_comp_op == TOK_MINUS()
                                x86_synth_emit_bytes(s, [242, 15, 92, 193])
                            elif lv_comp_op == TOK_STAR()
                                x86_synth_emit_bytes(s, [242, 15, 89, 193])
                            elif lv_comp_op == TOK_SLASH()
                                x86_synth_emit_bytes(s, [242, 15, 94, 193])
                            elif lv_comp_op == TOK_PERCENT()
                                x86_synth_emit_bytes(s, [102, 15, 40, 208, 242, 15, 94, 193, 102, 15, 58, 11, 192, 3, 242, 15, 89, 193, 242, 15, 92, 208, 102, 15, 40, 194])
                            end
                            x86_synth_emit_bytes(s, [102, 72, 15, 126, 192])
                        elif lv_comp_op == TOK_PLUS() and (lf_ft == "str" or lf_ft == "string" or lv_rhs_t == "str")
                            x86_synth_emit_bytes(s, [81, 72, 131, 236, 8, 72, 137, 199, 76, 137, 198])
                            x86_synth_emit_call_helper(s, "_lipi_add_dynamic")
                            x86_synth_emit_bytes(s, [72, 131, 196, 8, 89])
                        elif lv_comp_op == TOK_PLUS()
                            x86_synth_emit_bytes(s, [76, 1, 192])
                        elif lv_comp_op == TOK_MINUS()
                            x86_synth_emit_bytes(s, [76, 41, 192])
                        elif lv_comp_op == TOK_STAR()
                            x86_synth_emit_bytes(s, [73, 15, 175, 192])
                        elif lv_comp_op == TOK_SLASH()
                            // WHY: Match `/` semantics on chained struct fields: unsigned `div r8` for u64/u32/u16/u8
                            // and hosted `_lipi_div_by_zero` (saving rcx) on divisor == 0.
                            if x86_synth_is_uint_type(lf_ft) == 1
                                if s.synth_freestanding == 0
                                    x86_synth_emit_bytes(s, [77, 133, 192, 117, 17, 81, 72, 131, 236, 8])
                                    x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                    x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 235, 5, 49, 210, 73, 247, 240])
                                else
                                    x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 5, 49, 210, 73, 247, 240])
                                end
                            elif s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 17, 81, 72, 131, 236, 8])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 235, 16, 73, 131, 248, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 73, 247, 248])
                            else
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 16, 73, 131, 248, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 73, 247, 248])
                            end
                        elif lv_comp_op == TOK_PERCENT()
                            if x86_synth_is_uint_type(lf_ft) == 1
                                if s.synth_freestanding == 0
                                    x86_synth_emit_bytes(s, [77, 133, 192, 117, 17, 81, 72, 131, 236, 8])
                                    x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                    x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 235, 8, 49, 210, 73, 247, 240, 72, 137, 208])
                                else
                                    x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 8, 49, 210, 73, 247, 240, 72, 137, 208])
                                end
                            elif s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 17, 81, 72, 131, 236, 8])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 235, 18, 73, 131, 248, 255, 117, 4, 49, 192, 235, 8, 72, 153, 73, 247, 248, 72, 137, 208])
                            else
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 18, 73, 131, 248, 255, 117, 4, 49, 192, 235, 8, 72, 153, 73, 247, 248, 72, 137, 208])
                            end
                        end
                    end
                    if lf_bw > 0
                        x86_synth_emit_bitfield_store_rcx_rax(s, lf_off, lf_sz, lf_bo, lf_bw)
                    else
                        x86_synth_emit_field_store_rcx_rax(s, lf_off, lf_sz)
                    end
                    s.synth_last_store_end = 0 - 1
                    return 0
                else
                    // Final write to list OR inline fixed-array element: <expr>[leaf_idx] op= rhs
                    raw_leaf = x86_synth_parse_raw_elem_tag(cur_el_t)
                    // Stack layout: [rsp+8] = list/buf ptr, [rsp+0] = leaf_idx (16-byte aligned throughout!)
                    x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rax (list/buf ptr); sub rsp, 8
                    lidx_pb = [lv_starts[leaf_i]]
                    x86_synth_compile_expr(s, toks, lidx_pb)
                    x86_synth_emit_bytes(s, [72, 137, 4, 36]) // mov [rsp], rax (leaf_idx)
                    list_set(pos_box, 0, scan_lp + 1)
                    x86_synth_compile_expr(s, toks, pos_box)
                    lv_rhs_t2 = s.synth_last_expr_type
                    if raw_leaf[0] > 0 and lv_is_comp == 0
                        x86_synth_emit_bytes(s, [72, 137, 194, 94, 95]) // mov rdx, rax; pop rsi (idx); pop rdi (buf)
                        x86_synth_emit_raw_array_store(s, raw_leaf[0])
                        s.synth_last_store_end = 0 - 1
                        return 0
                    end
                    if lv_is_comp == 1
                        x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rhs; sub rsp, 8 -> [rsp+8]=rhs,[rsp+16]=idx,[rsp+24]=list
                        x86_synth_emit_bytes(s, [72, 139, 124, 36, 24, 72, 139, 116, 36, 16]) // mov rdi,[rsp+24]; mov rsi,[rsp+16]
                        x86_synth_emit_call_helper(s, "_lipi_list_get")
                        x86_synth_emit_bytes(s, [72, 131, 196, 8, 65, 88]) // add rsp, 8; pop r8 (rhs)
                        if lv_rhs_t2 == "float"
                            x86_synth_emit_bytes(s, [102, 72, 15, 110, 192, 102, 73, 15, 110, 200])
                            if lv_comp_op == TOK_PLUS()
                                x86_synth_emit_bytes(s, [242, 15, 88, 193])
                            elif lv_comp_op == TOK_MINUS()
                                x86_synth_emit_bytes(s, [242, 15, 92, 193])
                            elif lv_comp_op == TOK_STAR()
                                x86_synth_emit_bytes(s, [242, 15, 89, 193])
                            elif lv_comp_op == TOK_SLASH()
                                x86_synth_emit_bytes(s, [242, 15, 94, 193])
                            elif lv_comp_op == TOK_PERCENT()
                                x86_synth_emit_bytes(s, [102, 15, 40, 208, 242, 15, 94, 193, 102, 15, 58, 11, 192, 3, 242, 15, 89, 193, 242, 15, 92, 208, 102, 15, 40, 194])
                            end
                            x86_synth_emit_bytes(s, [102, 72, 15, 126, 192])
                        elif lv_comp_op == TOK_PLUS() and lv_rhs_t2 == "str"
                            x86_synth_emit_bytes(s, [72, 137, 199, 76, 137, 198])
                            x86_synth_emit_call_helper(s, "_lipi_add_dynamic")
                        elif lv_comp_op == TOK_PLUS()
                            x86_synth_emit_bytes(s, [76, 1, 192])
                        elif lv_comp_op == TOK_MINUS()
                            x86_synth_emit_bytes(s, [76, 41, 192])
                        elif lv_comp_op == TOK_STAR()
                            x86_synth_emit_bytes(s, [73, 15, 175, 192])
                        elif lv_comp_op == TOK_SLASH()
                            // WHY: Hosted compound `/=` on chained index calls _lipi_div_by_zero on divisor == 0.
                            if s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 7])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [235, 16, 73, 131, 248, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 73, 247, 248])
                            else
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 16, 73, 131, 248, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 73, 247, 248])
                            end
                        elif lv_comp_op == TOK_PERCENT()
                            // WHY: Hosted compound `%=` on chained index calls _lipi_div_by_zero on divisor == 0.
                            if s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 7])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [235, 18, 73, 131, 248, 255, 117, 4, 49, 192, 235, 8, 72, 153, 73, 247, 248, 72, 137, 208])
                            else
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 18, 73, 131, 248, 255, 117, 4, 49, 192, 235, 8, 72, 153, 73, 247, 248, 72, 137, 208])
                            end
                        end
                    end
                    if lv_rhs_t2 == "float"
                        x86_synth_emit_bytes(s, [185, 1, 0, 0, 0]) // mov ecx, 1
                    elif lv_rhs_t2 == "str"
                        x86_synth_emit_bytes(s, [185, 2, 0, 0, 0]) // mov ecx, 2
                    elif lv_rhs_t2 == "dyn_tagged"
                        x86_synth_emit_bytes(s, [72, 137, 209]) // mov rcx, rdx
                    else
                        x86_synth_emit_bytes(s, [49, 201]) // xor ecx, ecx
                    end
                    x86_synth_emit_bytes(s, [72, 137, 194, 94, 95]) // mov rdx, rax; pop rsi (idx); pop rdi (list)
                    x86_synth_emit_call_helper(s, "_lipi_list_set_typed")
                    s.synth_last_store_end = 0 - 1
                    return 0
                end
            end
        end
    end

    if k == TOK_IDENT()
        scan_fp = pos + 1
        chain_fields = list()
        while scan_fp + 1 < toks.len()
            t_dot = toks[scan_fp]
            t_fld = toks[scan_fp + 1]
            is_dot = 0
            if t_dot.tok_kind == TOK_DOT() or (t_dot.tok_kind != TOK_STR() and t_dot.tok_text == ".")
                is_dot = 1
            if is_dot == 1 and x86_synth_is_ident_token(t_fld.tok_kind) == 1
                push(chain_fields, t_fld.tok_text)
                scan_fp = scan_fp + 2
            else
                break
        if chain_fields.len() > 0 and scan_fp < toks.len()
            t_eq = toks[scan_fp]
            teq_k = t_eq.tok_kind
            teq_txt = t_eq.tok_text
            is_assign = 0
            is_fld_comp = 0
            fld_comp_op = 0
            if teq_k == TOK_ASSIGN() or (teq_k != TOK_STR() and teq_txt == "=")
                is_assign = 1
            elif teq_k == TOK_PLUSEQ() or teq_txt == "+="
                is_assign = 1
                is_fld_comp = 1
                fld_comp_op = TOK_PLUS()
            elif teq_k == TOK_MINUSEQ() or teq_txt == "-="
                is_assign = 1
                is_fld_comp = 1
                fld_comp_op = TOK_MINUS()
            elif teq_k == TOK_STAREQ() or teq_txt == "*="
                is_assign = 1
                is_fld_comp = 1
                fld_comp_op = TOK_STAR()
            elif teq_k == TOK_SLASHEQ() or teq_txt == "/="
                is_assign = 1
                is_fld_comp = 1
                fld_comp_op = TOK_SLASH()
            elif teq_k == TOK_PERCENTEQ() or teq_txt == "%="
                is_assign = 1
                is_fld_comp = 1
                fld_comp_op = TOK_PERCENT()
            end
            if is_assign == 1
                obj_name = txt
                list_set(pos_box, 0, scan_fp + 1) // Consume obj, '.f1...fN', op

                // Evaluate expr into %rax and save RHS value on stack
                x86_synth_compile_expr(s, toks, pos_box)
                rhs_fld_type = s.synth_last_expr_type
                x86_synth_emit_byte(s, 80) // push rax

                // Load root obj pointer into %rcx (supports locals, @bss static structs, & mutable globals)
                lv_obj = x86_synth_find_local_var(s, obj_name)
                cur_stype = ""
                if lv_obj != 0 and lv_obj.lv_is_spilled == 0 and lv_obj.lv_reg >= 0
                    x86_synth_emit_mov_reg_reg(s, 1, lv_obj.lv_reg)
                    cur_stype = x86_synth_get_var_type(s, obj_name)
                else
                    bss_obj = x86_synth_find_bss(s, obj_name)
                    mg_obj = x86_synth_find_mutable_global(s, obj_name)
                    if lv_obj == 0 and bss_obj >= 0
                        x86_synth_emit_bss_addr(s, bss_obj)
                        x86_synth_emit_bytes(s, [72, 137, 193]) // mov rcx, rax
                        cur_stype = s.synth_bss_structs[bss_obj]
                    elif lv_obj == 0 and mg_obj >= 512
                        x86_synth_emit_mutable_global_read(s, mg_obj)
                        x86_synth_emit_bytes(s, [72, 137, 193]) // mov rcx, rax
                        cur_stype = x86_synth_get_mutable_global_struct(s, obj_name)
                    else
                        obj_off = x86_synth_lookup_var(s, obj_name)
                        if obj_off > 0
                            x86_synth_emit_load_var(s, 1, obj_off)
                        else
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 49)
                            x86_synth_emit_byte(s, 201)
                        end
                        cur_stype = x86_synth_get_var_type(s, obj_name)
                    end
                end

                // Walk intermediate nested struct pointers with field type propagation & null guard
                ci = 0
                while ci < chain_fields.len() - 1
                    x86_synth_emit_null_check_rcx(s)
                    mid_off = x86_synth_get_field_offset(s, cur_stype, chain_fields[ci])
                    cur_stype = x86_synth_get_field_type(s, cur_stype, chain_fields[ci])
                    if mid_off < 128
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 139)
                        x86_synth_emit_byte(s, 73)
                        x86_synth_emit_byte(s, mid_off)
                    else
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 139)
                        x86_synth_emit_byte(s, 137)
                        x86_synth_emit_u32(s, mid_off)
                    end
                    ci = ci + 1
                end

                x86_synth_emit_null_check_rcx(s)
                leaf_field = chain_fields[chain_fields.len() - 1]
                if x86_synth_is_const_ptr_type(cur_stype) == 1
                    say "❌ [Error]: Cannot mutate field '" + leaf_field + "' through immutable const pointer '" + cur_stype + "'"
                    exit(1)
                end
                lf_meta2 = x86_synth_get_field_meta(s, cur_stype, leaf_field)
                f_off = lf_meta2[0]
                f_sz2 = lf_meta2[1]
                leaf_ftype = lf_meta2[4]
                f_bo2 = 0
                f_bw2 = 0
                if lf_meta2.len() >= 7
                    f_bo2 = lf_meta2[5]
                    f_bw2 = lf_meta2[6]
                end
                if is_fld_comp == 0
                    // Pop RHS value into %rax
                    x86_synth_emit_byte(s, 88)
                else
                    // Pop RHS value into %r8, load old [rcx + f_off] into %rax
                    x86_synth_emit_bytes(s, [65, 88]) // pop r8
                    if f_off < 128
                        x86_synth_emit_bytes(s, [72, 139, 65, f_off])
                    else
                        x86_synth_emit_bytes(s, [72, 139, 129])
                        x86_synth_emit_u32(s, f_off)
                    end
                    is_flt_fld = 0
                    if leaf_ftype == "f64" or leaf_ftype == "f32" or leaf_ftype == "float" or rhs_fld_type == "float"
                        is_flt_fld = 1
                    end
                    if is_flt_fld == 1
                        if leaf_ftype == "f64" or leaf_ftype == "f32" or leaf_ftype == "float"
                            x86_synth_emit_bytes(s, [102, 72, 15, 110, 192]) // movq xmm0, rax
                        else
                            x86_synth_emit_bytes(s, [242, 72, 15, 42, 192])  // cvtsi2sd xmm0, rax
                        end
                        if rhs_fld_type == "float"
                            x86_synth_emit_bytes(s, [102, 73, 15, 110, 200]) // movq xmm1, r8
                        else
                            x86_synth_emit_bytes(s, [242, 73, 15, 42, 200])  // cvtsi2sd xmm1, r8
                        end
                        if fld_comp_op == TOK_PLUS()
                            x86_synth_emit_bytes(s, [242, 15, 88, 193])
                        elif fld_comp_op == TOK_MINUS()
                            x86_synth_emit_bytes(s, [242, 15, 92, 193])
                        elif fld_comp_op == TOK_STAR()
                            x86_synth_emit_bytes(s, [242, 15, 89, 193])
                        elif fld_comp_op == TOK_SLASH()
                            x86_synth_emit_bytes(s, [242, 15, 94, 193])
                        elif fld_comp_op == TOK_PERCENT()
                            x86_synth_emit_bytes(s, [102, 15, 40, 208, 242, 15, 94, 193, 102, 15, 58, 11, 192, 3, 242, 15, 89, 193, 242, 15, 92, 208, 102, 15, 40, 194])
                        end
                        x86_synth_emit_bytes(s, [102, 72, 15, 126, 192]) // movq rax, xmm0
                    elif fld_comp_op == TOK_PLUS() and (leaf_ftype == "str" or leaf_ftype == "string" or rhs_fld_type == "str")
                        x86_synth_emit_bytes(s, [81, 72, 131, 236, 8, 72, 137, 199, 76, 137, 198])
                        x86_synth_emit_call_helper(s, "_lipi_add_dynamic")
                        x86_synth_emit_bytes(s, [72, 131, 196, 8, 89])
                    elif fld_comp_op == TOK_PLUS()
                        x86_synth_emit_bytes(s, [76, 1, 192]) // add rax, r8
                    elif fld_comp_op == TOK_MINUS()
                        x86_synth_emit_bytes(s, [76, 41, 192]) // sub rax, r8
                    elif fld_comp_op == TOK_STAR()
                        x86_synth_emit_bytes(s, [73, 15, 175, 192]) // imul rax, r8
                    elif fld_comp_op == TOK_SLASH()
                        // WHY: Match `/` semantics on struct fields: unsigned `div r8` for u64/u32/u16/u8
                        // and hosted `_lipi_div_by_zero` (preserving rcx) on divisor == 0.
                        if x86_synth_is_uint_type(leaf_ftype) == 1
                            if s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 17, 81, 72, 131, 236, 8])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 235, 5, 49, 210, 73, 247, 240])
                            else
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 5, 49, 210, 73, 247, 240])
                            end
                        elif s.synth_freestanding == 0
                            x86_synth_emit_bytes(s, [77, 133, 192, 117, 17, 81, 72, 131, 236, 8])
                            x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                            x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 235, 16, 73, 131, 248, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 73, 247, 248])
                        else
                            x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 16, 73, 131, 248, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 73, 247, 248])
                        end
                    elif fld_comp_op == TOK_PERCENT()
                        if x86_synth_is_uint_type(leaf_ftype) == 1
                            if s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 17, 81, 72, 131, 236, 8])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 235, 8, 49, 210, 73, 247, 240, 72, 137, 208])
                            else
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 8, 49, 210, 73, 247, 240, 72, 137, 208])
                            end
                        elif s.synth_freestanding == 0
                            x86_synth_emit_bytes(s, [77, 133, 192, 117, 17, 81, 72, 131, 236, 8])
                            x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                            x86_synth_emit_bytes(s, [72, 131, 196, 8, 89, 235, 18, 73, 131, 248, 255, 117, 4, 49, 192, 235, 8, 72, 153, 73, 247, 248, 72, 137, 208])
                        else
                            x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 18, 73, 131, 248, 255, 117, 4, 49, 192, 235, 8, 72, 153, 73, 247, 248, 72, 137, 208])
                        end
                    end
                end

                // Store value to leaf field with exact 1/2/4/8B hardware width (or read-modify-write bitfield!)
                if f_bw2 > 0
                    x86_synth_emit_bitfield_store_rcx_rax(s, f_off, f_sz2, f_bo2, f_bw2)
                else
                    x86_synth_emit_field_store_rcx_rax(s, f_off, f_sz2)
                end

                return 0

    // ── 5b. Array Indexing Assignment: arr[idx] (= | += | -= | *= | /= | %=) expr ───────
    if k == TOK_IDENT() and pos + 1 < toks.len()
        nt1 = toks[pos + 1]
        if nt1.tok_kind == TOK_LBRACKET() or (nt1.tok_kind != TOK_STR() and nt1.tok_text == "[")
            arr_name = txt
            is_arr_assign = 0
            is_arr_comp = 0
            arr_comp_op = 0
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
                            nk_arr = nt.tok_kind
                            nt_arr = nt.tok_text
                            if nk_arr == TOK_ASSIGN() or (nk_arr != TOK_STR() and nt_arr == "=")
                                is_arr_assign = 1
                            elif nk_arr == TOK_PLUSEQ() or nt_arr == "+="
                                is_arr_assign = 1
                                is_arr_comp = 1
                                arr_comp_op = TOK_PLUS()
                            elif nk_arr == TOK_MINUSEQ() or nt_arr == "-="
                                is_arr_assign = 1
                                is_arr_comp = 1
                                arr_comp_op = TOK_MINUS()
                            elif nk_arr == TOK_STAREQ() or nt_arr == "*="
                                is_arr_assign = 1
                                is_arr_comp = 1
                                arr_comp_op = TOK_STAR()
                            elif nk_arr == TOK_SLASHEQ() or nt_arr == "/="
                                is_arr_assign = 1
                                is_arr_comp = 1
                                arr_comp_op = TOK_SLASH()
                            elif nk_arr == TOK_PERCENTEQ() or nt_arr == "%="
                                is_arr_assign = 1
                                is_arr_comp = 1
                                arr_comp_op = TOK_PERCENT()
                            end
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
                // Consume '=' or compound op
                cp = get(pos_box, 0)
                if cp < toks.len()
                    list_set(pos_box, 0, cp + 1)
                end
                x86_synth_compile_expr(s, toks, pos_box) // rax = val
                rhs_arr_type = s.synth_last_expr_type
                // Direct zero-heap store for static @bss `[N]T` buffers!
                bss_arr_idx = x86_synth_find_bss(s, arr_name)
                if bss_arr_idx >= 0 and s.synth_bss_elem_sizes[bss_arr_idx] > 0 and is_arr_comp == 0
                    x86_synth_emit_bytes(s, [72, 137, 194, 94]) // mov rdx, rax (val); pop rsi (idx)
                    x86_synth_emit_bss_addr(s, bss_arr_idx)     // rax = bss buffer base
                    x86_synth_emit_bytes(s, [72, 137, 199])     // mov rdi, rax
                    x86_synth_emit_raw_array_store(s, s.synth_bss_elem_sizes[bss_arr_idx])
                    s.synth_last_store_end = 0 - 1
                    return 0
                end
                // Direct scaled store for typed pointers `p[i] = val` (rejects `*const T` at compile time!)
                ptr_arr_t = x86_synth_get_var_type(s, arr_name)
                if ptr_arr_t == ""
                    ptr_arr_t = x86_synth_get_mutable_global_struct(s, arr_name)
                end
                if x86_synth_is_ptr_type(ptr_arr_t) == 1 and is_arr_comp == 0
                    if x86_synth_is_const_ptr_type(ptr_arr_t) == 1
                        say "❌ [Error]: Cannot index-write through immutable const pointer '" + ptr_arr_t + "'"
                        exit(1)
                    end
                    pt_w_el = x86_synth_ptr_pointee(ptr_arr_t)
                    pt_w_sz = x86_synth_sizeof_type(s, pt_w_el)
                    x86_synth_emit_bytes(s, [72, 137, 194, 94]) // mov rdx, rax (val); pop rsi (idx)
                    lv_pa = x86_synth_find_local_var(s, arr_name)
                    if lv_pa != 0 and lv_pa.lv_is_spilled == 0 and lv_pa.lv_reg >= 0
                        x86_synth_emit_mov_reg_reg(s, 7, lv_pa.lv_reg)
                    else
                        mg_pa = x86_synth_find_mutable_global(s, arr_name)
                        if lv_pa == 0 and mg_pa >= 512
                            x86_synth_emit_mutable_global_read(s, mg_pa)
                            x86_synth_emit_bytes(s, [72, 137, 199]) // mov rdi, rax
                        else
                            off_pa = x86_synth_lookup_var(s, arr_name)
                            if off_pa > 0
                                x86_synth_emit_load_var(s, 7, off_pa)
                            else
                                x86_synth_emit_bytes(s, [49, 255])
                            end
                        end
                    end
                    x86_synth_emit_null_check_rdi(s)
                    x86_synth_emit_raw_array_store(s, pt_w_sz)
                    s.synth_last_store_end = 0 - 1
                    return 0
                end
                if is_arr_comp == 1
                    x86_synth_emit_byte(s, 80) // push rhs (stack: [rsp]=rhs, [rsp+8]=idx)
                    if rhs_arr_type == "dyn_tagged"
                        x86_synth_emit_byte(s, 82) // push rdx ([rsp]=rtag, [rsp+8]=rhs, [rsp+16]=idx)
                    end
                    lv_arr = x86_synth_find_local_var(s, arr_name)
                    if lv_arr != 0 and lv_arr.lv_is_spilled == 0 and lv_arr.lv_reg >= 0
                        x86_synth_emit_mov_reg_reg(s, 7, lv_arr.lv_reg)
                    else
                        mg_arr = x86_synth_find_mutable_global(s, arr_name)
                        if lv_arr == 0 and mg_arr >= 512
                            x86_synth_emit_mutable_global_read(s, mg_arr)
                            x86_synth_emit_bytes(s, [72, 137, 199]) // mov rdi, rax
                        else
                            off = x86_synth_lookup_var(s, arr_name)
                            if off > 0
                                x86_synth_emit_load_var(s, 7, off)
                            else
                                x86_synth_emit_bytes(s, [49, 255])
                            end
                        end
                    end
                    if rhs_arr_type == "dyn_tagged"
                        x86_synth_emit_bytes(s, [72, 139, 116, 36, 16]) // mov rsi, [rsp + 16]
                    else
                        x86_synth_emit_bytes(s, [72, 139, 116, 36, 8]) // mov rsi, [rsp + 8]
                    end
                    x86_synth_emit_call_helper(s, "_lipi_list_get") // rax = old element, rdx = old tag
                    arr_el_prim = x86_synth_get_elem_type(s, arr_name)
                    if arr_el_prim == "dyn_dict" or rhs_arr_type == "dyn_tagged"
                        // Pop rtag (if pushed) into rcx, pop rhs into rsi; rdi = old(rax), rdx = old_tag
                        if rhs_arr_type == "dyn_tagged"
                            x86_synth_emit_bytes(s, [89, 94]) // pop rcx (rtag); pop rsi (rhs)
                        else
                            x86_synth_emit_byte(s, 94) // pop rsi (rhs)
                            if rhs_arr_type == "float"
                                x86_synth_emit_bytes(s, [185, 1, 0, 0, 0])
                            elif rhs_arr_type == "str"
                                x86_synth_emit_bytes(s, [185, 2, 0, 0, 0])
                            else
                                x86_synth_emit_bytes(s, [49, 201])
                            end
                        end
                        x86_synth_emit_bytes(s, [72, 137, 199]) // mov rdi, rax
                        c_tag_op = 0
                        if arr_comp_op == TOK_MINUS()
                            c_tag_op = 1
                        elif arr_comp_op == TOK_STAR()
                            c_tag_op = 2
                        elif arr_comp_op == TOK_SLASH()
                            c_tag_op = 3
                        elif arr_comp_op == TOK_PERCENT()
                            c_tag_op = 4
                        end
                        x86_synth_emit_bytes(s, [65, 184])
                        x86_synth_emit_u32(s, c_tag_op)
                        x86_synth_emit_call_helper(s, "_lipi_binop_tagged")
                        rhs_arr_type = "dyn_tagged"
                    else
                        x86_synth_emit_bytes(s, [65, 88]) // pop r8 (rhs); stack top is now idx
                        if rhs_arr_type == "float" or arr_el_prim == "float"
                            if arr_el_prim == "float"
                                x86_synth_emit_bytes(s, [102, 72, 15, 110, 192]) // movq xmm0, rax
                            else
                                x86_synth_emit_bytes(s, [242, 72, 15, 42, 192])  // cvtsi2sd xmm0, rax
                            end
                            if rhs_arr_type == "float"
                                x86_synth_emit_bytes(s, [102, 73, 15, 110, 200]) // movq xmm1, r8
                            else
                                x86_synth_emit_bytes(s, [242, 73, 15, 42, 200])  // cvtsi2sd xmm1, r8
                            end
                            if arr_comp_op == TOK_PLUS()
                                x86_synth_emit_bytes(s, [242, 15, 88, 193])
                            elif arr_comp_op == TOK_MINUS()
                                x86_synth_emit_bytes(s, [242, 15, 92, 193])
                            elif arr_comp_op == TOK_STAR()
                                x86_synth_emit_bytes(s, [242, 15, 89, 193])
                            elif arr_comp_op == TOK_SLASH()
                                x86_synth_emit_bytes(s, [242, 15, 94, 193])
                            elif arr_comp_op == TOK_PERCENT()
                                x86_synth_emit_bytes(s, [102, 15, 40, 208, 242, 15, 94, 193, 102, 15, 58, 11, 192, 3, 242, 15, 89, 193, 242, 15, 92, 208, 102, 15, 40, 194])
                            end
                            x86_synth_emit_bytes(s, [102, 72, 15, 126, 192]) // movq rax, xmm0
                            x86_synth_set_elem_type(s, arr_name, "float")
                            rhs_arr_type = "float"
                        elif arr_comp_op == TOK_PLUS() and rhs_arr_type == "str"
                            x86_synth_emit_bytes(s, [72, 137, 199, 76, 137, 198])
                            x86_synth_emit_call_helper(s, "_lipi_add_dynamic")
                        elif arr_comp_op == TOK_PLUS()
                            x86_synth_emit_bytes(s, [76, 1, 192])
                        elif arr_comp_op == TOK_MINUS()
                            x86_synth_emit_bytes(s, [76, 41, 192])
                        elif arr_comp_op == TOK_STAR()
                            x86_synth_emit_bytes(s, [73, 15, 175, 192])
                        elif arr_comp_op == TOK_SLASH()
                            // WHY: Hosted compound `/=` on typed array elements calls _lipi_div_by_zero (16B-aligned).
                            if s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 15, 72, 131, 236, 8])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [72, 131, 196, 8, 235, 16, 73, 131, 248, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 73, 247, 248])
                            else
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 16, 73, 131, 248, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 73, 247, 248])
                            end
                        elif arr_comp_op == TOK_PERCENT()
                            // WHY: Hosted compound `%=` on typed array elements calls _lipi_div_by_zero (16B-aligned).
                            if s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 15, 72, 131, 236, 8])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [72, 131, 196, 8, 235, 18, 73, 131, 248, 255, 117, 4, 49, 192, 235, 8, 72, 153, 73, 247, 248, 72, 137, 208])
                            else
                                x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 18, 73, 131, 248, 255, 117, 4, 49, 192, 235, 8, 72, 153, 73, 247, 248, 72, 137, 208])
                            end
                        end
                    end
                end
                // rcx = vtag (1=float, 2=str, rdx=dyn_tagged, 0=other), rdx = val, rsi = idx, rdi = obj
                if rhs_arr_type == "float"
                    x86_synth_emit_bytes(s, [185, 1, 0, 0, 0]) // mov ecx, 1
                elif rhs_arr_type == "str"
                    x86_synth_emit_bytes(s, [185, 2, 0, 0, 0]) // mov ecx, 2
                elif rhs_arr_type == "dyn_tagged"
                    x86_synth_emit_bytes(s, [72, 137, 209]) // mov rcx, rdx
                else
                    x86_synth_emit_bytes(s, [49, 201]) // xor ecx, ecx
                end
                x86_synth_emit_byte(s, 72) // mov rdx, rax (0x48 0x89 0xC2)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 194)
                x86_synth_emit_byte(s, 94)  // pop rsi (idx)
                lv_arr2 = x86_synth_find_local_var(s, arr_name)
                if lv_arr2 != 0 and lv_arr2.lv_is_spilled == 0 and lv_arr2.lv_reg >= 0
                    x86_synth_emit_mov_reg_reg(s, 7, lv_arr2.lv_reg)
                else
                    mg_arr2 = x86_synth_find_mutable_global(s, arr_name)
                    if lv_arr2 == 0 and mg_arr2 >= 512
                        x86_synth_emit_bytes(s, [81, 82, 86]) // push rcx; push rdx; push rsi
                        x86_synth_emit_mutable_global_read(s, mg_arr2)
                        x86_synth_emit_bytes(s, [72, 137, 199, 94, 90, 89]) // mov rdi, rax; pop rsi; pop rdx; pop rcx
                    else
                        off = x86_synth_lookup_var(s, arr_name)
                        if off > 0
                            x86_synth_emit_load_var(s, 7, off)
                        else
                            x86_synth_emit_byte(s, 49)
                            x86_synth_emit_byte(s, 255)
                        end
                    end
                end
                if rhs_arr_type == "float" and x86_synth_get_elem_type(s, arr_name) != "dyn_dict"
                    x86_synth_set_elem_type(s, arr_name, "float")
                end
                x86_synth_emit_call_helper(s, "_lipi_list_set_typed")
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
        if_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            if_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        if_has_end = x86_synth_line_has_inline_end(toks, get(pos_box, 0), base_line)

        // Compile then-block statements (braced `{ ... }`, indented, or `end`-delimited)
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if if_braced == 1
                if cur_k == TOK_RBRACE() or (cur_k != TOK_STR() and cur_txt == "}")
                    list_set(pos_box, 0, cur_p + 1)
                    break
                end
            else
                // Check if we hit closing '}' of enclosing braced block, elif, else, or end
                if cur_k == TOK_RBRACE() or (cur_k != TOK_STR() and cur_txt == "}")
                    break
                end
                if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()
                    break
                if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "নতুবা_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "অন্যথায়" or cur_txt == "নতুবা" or cur_txt == "@else")
                    break
                if x86_synth_is_block_end(toks, cur_p) == 1
                    break

                // Indentation check: statement on subsequent line with column <= base_col marks block end
                if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                    break
            end

            before_stmt_p = get(pos_box, 0)
            x86_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == before_stmt_p
                list_set(pos_box, 0, before_stmt_p + 1)

            if if_braced == 0 and cur_t.tok_span.span_start_line == base_line and if_has_end == 0 and x86_synth_should_stop_inline(toks, pos_box, base_line) == 1
                break

        // Check if there is an elif or else coming next
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        has_subsequent = 0
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if (cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()) and (if_braced == 1 or cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
                has_subsequent = 1
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "নতুবা_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "অন্যথায়" or cur_txt == "নতুবা" or cur_txt == "@else") and (if_braced == 1 or cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
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
            if (cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF()) and (if_braced == 1 or cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
                is_elif = 1
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif") and (if_braced == 1 or cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
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
            elif_braced = 0
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                elif_braced = 1
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            elif_has_end = x86_synth_line_has_inline_end(toks, get(pos_box, 0), elif_line)

            // Compile elif body
            while get(pos_box, 0) < toks.len()
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cur_p2 = get(pos_box, 0)
                if cur_p2 >= toks.len()
                    break
                ct2 = toks[cur_p2]
                ck2 = ct2.tok_kind
                cx2 = ct2.tok_text
                if elif_braced == 1
                    if ck2 == TOK_RBRACE() or (ck2 != TOK_STR() and cx2 == "}")
                        list_set(pos_box, 0, cur_p2 + 1)
                        break
                    end
                else
                    if ck2 == TOK_RBRACE() or (ck2 != TOK_STR() and cx2 == "}")
                        break
                    end
                    if ck2 == TOK_KW_ELIF() or ck2 == TOK_DIR_ELIF() or ck2 == TOK_KW_ELSE() or ck2 == TOK_DIR_ELSE()
                        break
                    if ck2 == TOK_IDENT() and (cx2 == "elif" or cx2 == "নাহলে_যদি" or cx2 == "নতুবা_যদি" or cx2 == "@elif" or cx2 == "else" or cx2 == "নাহলে" or cx2 == "অন্যথায়" or cx2 == "নতুবা" or cx2 == "@else")
                        break
                    if x86_synth_is_block_end(toks, cur_p2) == 1
                        break
                    if ct2.tok_span.span_start_line > elif_line and ct2.tok_span.span_start_col <= base_col
                        break
                end
                b_p2 = get(pos_box, 0)
                x86_synth_compile_statement(s, toks, pos_box)
                if get(pos_box, 0) == b_p2
                    list_set(pos_box, 0, b_p2 + 1)
                if elif_braced == 0 and ct2.tok_span.span_start_line == elif_line and elif_has_end == 0 and x86_synth_should_stop_inline(toks, pos_box, elif_line) == 1
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
            if (cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()) and (if_braced == 1 or cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
                is_else = 1
            if cur_k == TOK_IDENT() and (cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "অন্যথায়" or cur_txt == "নতুবা" or cur_txt == "@else") and (if_braced == 1 or cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
                is_else = 1
            if is_else == 1
                else_line = cur_t.tok_span.span_start_line
                list_set(pos_box, 0, cur_p + 1) // Consume 'else'
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                else_braced = 0
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                    else_braced = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                else_has_end = x86_synth_line_has_inline_end(toks, get(pos_box, 0), else_line)
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    cur_p3 = get(pos_box, 0)
                    if cur_p3 >= toks.len()
                        break
                    ct3 = toks[cur_p3]
                    ck3 = ct3.tok_kind
                    cx3 = ct3.tok_text
                    if else_braced == 1
                        if ck3 == TOK_RBRACE() or (ck3 != TOK_STR() and cx3 == "}")
                            list_set(pos_box, 0, cur_p3 + 1)
                            break
                        end
                    else
                        if ck3 == TOK_RBRACE() or (ck3 != TOK_STR() and cx3 == "}")
                            break
                        end
                        if x86_synth_is_block_end(toks, cur_p3) == 1
                            break
                        if ct3.tok_span.span_start_line > else_line and ct3.tok_span.span_start_col <= base_col
                            break
                    end
                    b_p3 = get(pos_box, 0)
                    x86_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p3
                        list_set(pos_box, 0, b_p3 + 1)
                    if else_braced == 0 and ct3.tok_span.span_start_line == else_line and else_has_end == 0 and x86_synth_should_stop_inline(toks, pos_box, else_line) == 1
                        break

        // Consume optional end / @end / শেষ (only when not braced)
        if if_braced == 0
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p < toks.len()
                if x86_synth_is_block_end(toks, cur_p) == 1
                    list_set(pos_box, 0, cur_p + 1)
        end

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
        return x86_synth_compile_while(s, toks, pos_box, base_col, base_line)

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
        return x86_synth_compile_for(s, toks, pos_box, base_col, base_line)

    // ── 8b. Loops: repeat / বার / @repeat ─────────────────────────────────────
    is_repeat = 0
    if k == TOK_IDENT() and (txt == "repeat" or txt == "বার" or txt == "@repeat")
        is_repeat = 1
    if is_repeat == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'repeat'
        return x86_synth_compile_repeat(s, toks, pos_box, base_col, base_line)

    // ── 9. Variable Declaration: let / চলক / ধরি / var ─────────────────────────
    is_let = 0
    if k == TOK_KW_LET()
        is_let = 1
    is_reg = 0
    if k == TOK_IDENT() and (txt == "let" or txt == "চলক" or txt == "ধরি" or txt == "var" or txt == "@let")
        is_let = 1
    if k == TOK_IDENT() and (txt == "@reg" or txt == "রেজিস্টার")
        is_let = 1
        is_reg = 1
    if k == TOK_IDENT() and txt == "reg"
        // WHY: Disambiguate 'reg x = expr' (register-hint declaration) from 'reg = expr'
        // (direct assignment to variable named 'reg' such as registry objects).
        next_p = pos + 1
        if next_p < toks.len() and x86_synth_is_ident_token(toks[next_p].tok_kind) == 1
            if toks[next_p].tok_text != "="
                is_let = 1
                is_reg = 1
            end
        end
    end

    if is_let == 1
        list_set(pos_box, 0, pos + 1) // Consume let
        var_pos = get(pos_box, 0)
        if var_pos < toks.len() and x86_synth_is_ident_token(toks[var_pos].tok_kind) == 1
            // Multi-variable tuple destructuring: let a, b [, c...] = rhs1 [, rhs2...]
            if var_pos + 1 < toks.len() and (toks[var_pos + 1].tok_kind == TOK_COMMA() or (toks[var_pos + 1].tok_kind != TOK_STR() and toks[var_pos + 1].tok_text == ","))
                ml_names = [toks[var_pos].tok_text]
                ml_p = var_pos + 1
                ml_ok = 1
                while ml_p < toks.len()
                    if toks[ml_p].tok_kind == TOK_COMMA() or (toks[ml_p].tok_kind != TOK_STR() and toks[ml_p].tok_text == ",")
                        ml_p = ml_p + 1
                        if ml_p < toks.len() and x86_synth_is_ident_token(toks[ml_p].tok_kind) == 1
                            push(ml_names, toks[ml_p].tok_text)
                            ml_p = ml_p + 1
                        else
                            ml_ok = 0
                            break
                        end
                    else
                        break
                    end
                end
                if ml_ok == 1 and ml_names.len() >= 2 and ml_p < toks.len() and (toks[ml_p].tok_kind == TOK_ASSIGN() or (toks[ml_p].tok_kind != TOK_STR() and toks[ml_p].tok_text == "="))
                    ml_ln = toks[ml_p].tok_span.span_start_line
                    list_set(pos_box, 0, ml_p + 1)
                    ml_rhs_types = list()
                    ml_rhs_structs = list()
                    ml_rcnt = 0
                    while 1 == 1
                        x86_synth_compile_expr(s, toks, pos_box)
                        push(ml_rhs_types, s.synth_last_expr_type)
                        push(ml_rhs_structs, s.synth_last_struct)
                        x86_synth_emit_byte(s, 80) // push rax
                        ml_rcnt = ml_rcnt + 1
                        mp_c = get(pos_box, 0)
                        if mp_c < toks.len() and (toks[mp_c].tok_kind == TOK_COMMA() or (toks[mp_c].tok_kind != TOK_STR() and toks[mp_c].tok_text == ",")) and toks[mp_c].tok_span.span_start_line == ml_ln
                            list_set(pos_box, 0, mp_c + 1)
                        else
                            break
                        end
                    end
                    if ml_rcnt == 1
                        // Unpack single tuple/list RHS into ml_names[0..N-1]
                        tup_tmp = s.synth_stack_offset
                        s.synth_stack_offset = s.synth_stack_offset + 8
                        x86_synth_emit_byte(s, 88) // pop rax
                        x86_synth_emit_store_var(s, 0, tup_tmp)
                        mli = 0
                        while mli < ml_names.len()
                            x86_synth_emit_load_var(s, 7, tup_tmp) // mov rdi, [rbp - tup_tmp]
                            x86_synth_emit_mov_rax_imm64(s, mli)
                            x86_synth_emit_bytes(s, [72, 137, 198]) // mov rsi, rax
                            x86_synth_emit_call_helper(s, "_lipi_list_get")
                            x86_synth_bind_reg_var(s, ml_names[mli], is_reg)
                            x86_synth_set_var_type(s, ml_names[mli], "")
                            x86_synth_set_prim_type(s, ml_names[mli], "")
                            mli = mli + 1
                        end
                    else
                        // Parallel multi-assign (swap-safe: all RHS evaluated on stack before any write!)
                        while ml_rcnt > ml_names.len()
                            x86_synth_emit_byte(s, 88) // discard excess RHS
                            ml_rcnt = ml_rcnt - 1
                        end
                        mli_z = ml_names.len() - 1
                        while mli_z >= ml_rcnt
                            x86_synth_emit_bytes(s, [49, 192]) // xor eax, eax
                            x86_synth_bind_reg_var(s, ml_names[mli_z], is_reg)
                            x86_synth_set_prim_type(s, ml_names[mli_z], "int")
                            mli_z = mli_z - 1
                        end
                        mli_r = ml_rcnt - 1
                        while mli_r >= 0
                            x86_synth_emit_byte(s, 88) // pop rax
                            mn_r = ml_names[mli_r]
                            x86_synth_bind_reg_var(s, mn_r, is_reg)
                            if mli_r < ml_rhs_structs.len() and ml_rhs_structs[mli_r] != ""
                                x86_synth_set_var_type(s, mn_r, ml_rhs_structs[mli_r])
                            end
                            if mli_r < ml_rhs_types.len()
                                x86_synth_set_prim_type(s, mn_r, ml_rhs_types[mli_r])
                            end
                            mli_r = mli_r - 1
                        end
                    end
                    return 0
                end
            end
            var_name = toks[var_pos].tok_text
            assigned_type = ""
            list_set(pos_box, 0, var_pos + 1)
            next_p = get(pos_box, 0)
            if next_p < toks.len() and (toks[next_p].tok_kind == TOK_COLON() or (toks[next_p].tok_kind != TOK_STR() and toks[next_p].tok_text == ":"))
                list_set(pos_box, 0, next_p + 1)
                raw_at = x86_synth_parse_type_expr(toks, pos_box)
                if raw_at != ""
                    assigned_type = x86_synth_subst_type(s, raw_at, 0, 0)
                end
            end
            eq_pos = get(pos_box, 0)
            if eq_pos < toks.len() and (toks[eq_pos].tok_kind == TOK_ASSIGN() or (toks[eq_pos].tok_kind != TOK_STR() and toks[eq_pos].tok_text == "="))
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
                eff_let_type = assigned_type
                if eff_let_type == ""
                    eff_let_type = x86_synth_get_var_type(s, var_name)
                end
                if x86_synth_is_narrow_int_type(eff_let_type) == 1
                    x86_synth_emit_truncate_int_width(s, eff_let_type)
                end
                off = x86_synth_bind_reg_var(s, var_name, is_reg)
                lv_let_post = x86_synth_find_local_var(s, var_name)
                if assigned_type != ""
                    x86_synth_set_var_type(s, var_name, assigned_type)
                    if x86_synth_is_uint_type(assigned_type) == 1 or x86_synth_is_ptr_type(assigned_type) == 1
                        x86_synth_set_prim_type(s, var_name, "uint")
                    elif assigned_type == "int" or assigned_type == "i64" or assigned_type == "i32" or assigned_type == "i16" or assigned_type == "i8"
                        x86_synth_set_prim_type(s, var_name, "int")
                    elif assigned_type == "float" or assigned_type == "f64" or assigned_type == "f32"
                        x86_synth_set_prim_type(s, var_name, "float")
                    elif assigned_type == "str" or assigned_type == "string"
                        x86_synth_set_prim_type(s, var_name, "str")
                if is_int_lit == 1
                    if s.synth_in_function == 0 and x86_synth_is_uint_type(eff_let_type) == 0 and x86_synth_is_narrow_int_type(eff_let_type) == 0 and x86_synth_is_ptr_type(eff_let_type) == 0
                        x86_synth_set_global_const(s, var_name, int_lit_val)
                    end
                    if x86_synth_is_uint_type(eff_let_type) == 1 or x86_synth_is_ptr_type(eff_let_type) == 1
                        x86_synth_set_prim_type(s, var_name, "uint")
                    elif assigned_type == "" and lv_let_post != 0 and lv_let_post.lv_tag_off > 0
                        x86_synth_set_prim_type(s, var_name, "dyn_tagged")
                    else
                        x86_synth_set_prim_type(s, var_name, "int")
                    end
                elif assigned_type == "" and lv_let_post != 0 and lv_let_post.lv_tag_off > 0
                    x86_synth_set_prim_type(s, var_name, "dyn_tagged")
                elif x86_synth_is_uint_type(eff_let_type) == 1 or x86_synth_is_ptr_type(eff_let_type) == 1 or s.synth_last_expr_type == "uint"
                    x86_synth_set_prim_type(s, var_name, "uint")
                elif s.synth_last_expr_type == "int"
                    x86_synth_set_prim_type(s, var_name, "int")
                elif s.synth_last_expr_type == "float"
                    x86_synth_set_prim_type(s, var_name, "float")
                elif s.synth_last_expr_type == "str"
                    x86_synth_set_prim_type(s, var_name, "str")
                elif s.synth_last_expr_type == "dyn_tagged"
                    x86_synth_set_prim_type(s, var_name, "dyn_tagged")
                elif eff_let_type == ""
                    x86_synth_set_prim_type(s, var_name, "")
        return 0

    // ── 9b. Exception Throw: throw <expr> / নিক্ষেপ <expr> ─────────────────────
    if k == TOK_IDENT() and (txt == "throw" or txt == "নিক্ষেপ" or txt == "@throw")
        if pos + 1 >= toks.len() or (toks[pos + 1].tok_kind != TOK_ASSIGN() and toks[pos + 1].tok_text != "=")
            list_set(pos_box, 0, pos + 1)
            x86_synth_compile_expr(s, toks, pos_box)
            // mov rdi, rax; call _lipi_exc_throw
            x86_synth_emit_bytes(s, [72, 137, 199])
            x86_synth_emit_call_helper(s, "_lipi_exc_throw")
            s.synth_last_store_end = 0 - 1
            return 0
        end

    // ── 9c. Structured Try/Catch/Finally: canonical TOK_KW_TRY / TOK_KW_CATCH ─
    is_try_stmt = 0
    if k == TOK_KW_TRY() or k == TOK_DIR_TRY()
        if pos + 1 >= toks.len() or (toks[pos + 1].tok_kind != TOK_ASSIGN() and toks[pos + 1].tok_text != "=")
            is_try_stmt = 1
        end
    if is_try_stmt == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        // Reserve 96B exception frame [rbp - exc_off] (+0..+71 = 72B _lipi_exc_push frame);
        // +72 (exc_off - 72) and +80 (exc_off - 80) store pending uncaught exc / return state for finally.
        // Advance synth_stack_offset past exc_off so local vars inside try NEVER overwrite [rbp - exc_off]!
        s.synth_stack_offset = ((s.synth_stack_offset + 15) / 16) * 16 + 96
        exc_off = s.synth_stack_offset
        fin_flag_off = exc_off - 72
        fin_val_off = exc_off - 80
        s.synth_stack_offset = exc_off + 8
        try_defer_start_idx = s.synth_defer_starts.len()
        x86_synth_emit_bytes(s, [49, 192]) // xor eax, eax
        x86_synth_emit_store_var(s, 0, fin_flag_off)

        // lea rdi, [rbp - exc_off]; lea rsi, [rip + catch_disp]; mov rdx, rbp; mov rcx, rsp; call _lipi_exc_push
        x86_synth_emit_bytes(s, [72, 141, 189])
        x86_synth_emit_u32(s, 0 - exc_off)
        x86_synth_emit_bytes(s, [72, 141, 53])
        catch_lea_patch = s.synth_code.len()
        x86_synth_emit_u32(s, 0)
        x86_synth_emit_bytes(s, [72, 137, 234, 72, 137, 225])
        x86_synth_emit_call_helper(s, "_lipi_exc_push")
        s.synth_last_store_end = 0 - 1

        outer_try_depth = s.synth_try_depth
        s.synth_try_depth = outer_try_depth + 1
        try_ret_patches = list()
        try_frame = [fin_flag_off, fin_val_off, try_ret_patches, outer_try_depth]
        push(s.synth_try_frames, try_frame)

        // Compile try body: supports BOTH braced `{ ... }` AND indentation/`end` blocks
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        try_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            try_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_pt = get(pos_box, 0)
            if cur_pt >= toks.len() break end
            ct_t = toks[cur_pt]
            if try_braced == 1
                if ct_t.tok_kind == TOK_RBRACE() or (ct_t.tok_kind != TOK_STR() and ct_t.tok_text == "}")
                    list_set(pos_box, 0, cur_pt + 1)
                    break
                end
            else
                if ct_t.tok_kind == TOK_RBRACE() or (ct_t.tok_kind != TOK_STR() and ct_t.tok_text == "}")
                    break
                end
                if ct_t.tok_kind == TOK_KW_CATCH() or ct_t.tok_kind == TOK_DIR_CATCH() or (ct_t.tok_kind == TOK_IDENT() and (ct_t.tok_text == "finally" or ct_t.tok_text == "অবশেষে" or ct_t.tok_text == "@finally"))
                    break
                end
                if x86_synth_is_block_end(toks, cur_pt) == 1 break end
                if ct_t.tok_span.span_start_line > base_line and ct_t.tok_span.span_start_col <= base_col break end
            end
            bp_t = get(pos_box, 0)
            x86_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) <= bp_t list_set(pos_box, 0, bp_t + 1) end
        end

        s.synth_try_depth = outer_try_depth

        // Normal exit from try: pop handler and jump past catch block into finally
        x86_synth_emit_call_helper(s, "_lipi_exc_pop")
        x86_synth_emit_byte(s, 233)
        jmp_after_catch = s.synth_code.len()
        x86_synth_emit_u32(s, 0)

        // Patch catch_rip target
        catch_target_off = s.synth_code.len()
        x86_synth_patch_u32(s, catch_lea_patch, catch_target_off - (catch_lea_patch + 4))
        s.synth_last_store_end = 0 - 1

        has_catch_blk = 0
        catch_braced = 1
        jmp_catch_normal_to_fin = 0 - 1
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            ct_c = toks[get(pos_box, 0)]
            if ct_c.tok_kind == TOK_KW_CATCH() or ct_c.tok_kind == TOK_DIR_CATCH()
                has_catch_blk = 1
                c_line = ct_c.tok_span.span_start_line
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == c_line and x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                    err_vname = toks[get(pos_box, 0)].tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    // Exception value arrives in %rax; bind to err_vname
                    x86_synth_bind_var(s, err_vname)
                end
                // WHY: Guard catch body against same-function rethrow by reusing [rbp - exc_off]
                // (already popped on entry to catch). If catch throws a new exception, unwind through
                // inner finally AND inner try/catch defers BEFORE rethrowing to outer catch!
                x86_synth_emit_bytes(s, [72, 141, 189])
                x86_synth_emit_u32(s, 0 - exc_off)
                x86_synth_emit_bytes(s, [72, 141, 53])
                catch_rethrow_lea_patch = s.synth_code.len()
                x86_synth_emit_u32(s, 0)
                x86_synth_emit_bytes(s, [72, 137, 234, 72, 137, 225])
                x86_synth_emit_call_helper(s, "_lipi_exc_push")
                s.synth_last_store_end = 0 - 1
                s.synth_try_depth = outer_try_depth + 1

                x86_synth_skip_whitespace_tokens(toks, pos_box)
                catch_braced = 0
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                    catch_braced = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    cur_pc = get(pos_box, 0)
                    if cur_pc >= toks.len() break end
                    ct_c2 = toks[cur_pc]
                    if catch_braced == 1
                        if ct_c2.tok_kind == TOK_RBRACE() or (ct_c2.tok_kind != TOK_STR() and ct_c2.tok_text == "}")
                            list_set(pos_box, 0, cur_pc + 1)
                            break
                        end
                    else
                        if ct_c2.tok_kind == TOK_RBRACE() or (ct_c2.tok_kind != TOK_STR() and ct_c2.tok_text == "}")
                            break
                        end
                        if ct_c2.tok_kind == TOK_IDENT() and (ct_c2.tok_text == "finally" or ct_c2.tok_text == "অবশেষে" or ct_c2.tok_text == "@finally")
                            break
                        end
                        if x86_synth_is_block_end(toks, cur_pc) == 1 break end
                        if ct_c2.tok_span.span_start_line > c_line and ct_c2.tok_span.span_start_col <= base_col break end
                    end
                    bp_c = get(pos_box, 0)
                    x86_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) <= bp_c list_set(pos_box, 0, bp_c + 1) end
                end

                s.synth_try_depth = outer_try_depth
                // Normal catch completion: pop catch-rethrow guard and jump into finally (fin_flag remains 0)
                x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                x86_synth_emit_byte(s, 233)
                jmp_catch_normal_to_fin = s.synth_code.len()
                x86_synth_emit_u32(s, 0)

                // Rethrow landing pad for exceptions thrown inside catch: record fin_val/fin_flag=1 and run finally+defers!
                catch_rethrow_off = s.synth_code.len()
                x86_synth_patch_u32(s, catch_rethrow_lea_patch, catch_rethrow_off - (catch_rethrow_lea_patch + 4))
                s.synth_last_store_end = 0 - 1
                x86_synth_emit_store_var(s, 0, fin_val_off)
                x86_synth_emit_mov_rax_imm64(s, 1)
                x86_synth_emit_store_var(s, 0, fin_flag_off)
            end
        end

        if has_catch_blk == 0
            // Standalone try ... finally: record uncaught exception so it re-throws after finally
            x86_synth_emit_store_var(s, 0, fin_val_off)
            x86_synth_emit_mov_rax_imm64(s, 1)
            x86_synth_emit_store_var(s, 0, fin_flag_off)
        end

        finally_entry_off = s.synth_code.len()
        x86_synth_patch_u32(s, jmp_after_catch, finally_entry_off - (jmp_after_catch + 4))
        if jmp_catch_normal_to_fin >= 0
            x86_synth_patch_u32(s, jmp_catch_normal_to_fin, finally_entry_off - (jmp_catch_normal_to_fin + 4))
        end
        rp_i = 0
        while rp_i < try_ret_patches.len()
            rp_off = try_ret_patches[rp_i]
            x86_synth_patch_u32(s, rp_off, finally_entry_off - (rp_off + 4))
            rp_i = rp_i + 1
        end
        s.synth_try_frames = pop(s.synth_try_frames)
        s.synth_last_store_end = 0 - 1

        has_fin_blk = 0
        fin_braced = 1
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            ct_f = toks[get(pos_box, 0)]
            if ct_f.tok_kind == TOK_IDENT() and (ct_f.tok_text == "finally" or ct_f.tok_text == "অবশেষে" or ct_f.tok_text == "@finally")
                has_fin_blk = 1
                f_line = ct_f.tok_span.span_start_line
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                fin_braced = 0
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                    fin_braced = 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    cur_pf = get(pos_box, 0)
                    if cur_pf >= toks.len() break end
                    ct_f2 = toks[cur_pf]
                    if fin_braced == 1
                        if ct_f2.tok_kind == TOK_RBRACE() or (ct_f2.tok_kind != TOK_STR() and ct_f2.tok_text == "}")
                            list_set(pos_box, 0, cur_pf + 1)
                            break
                        end
                    else
                        if ct_f2.tok_kind == TOK_RBRACE() or (ct_f2.tok_kind != TOK_STR() and ct_f2.tok_text == "}")
                            break
                        end
                        if x86_synth_is_block_end(toks, cur_pf) == 1 break end
                        if ct_f2.tok_span.span_start_line > f_line and ct_f2.tok_span.span_start_col <= base_col break end
                    end
                    bp_f = get(pos_box, 0)
                    x86_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) <= bp_f list_set(pos_box, 0, bp_f + 1) end
                end
            end
        end

        any_unbraced = 0
        if try_braced == 0 or (has_catch_blk == 1 and catch_braced == 0) or (has_fin_blk == 1 and fin_braced == 0)
            any_unbraced = 1
        end
        if any_unbraced == 1
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            if get(pos_box, 0) < toks.len() and x86_synth_is_block_end(toks, get(pos_box, 0)) == 1 and toks[get(pos_box, 0)].tok_span.span_start_col >= base_col
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end

        // Replay any defers registered inside this try/catch/finally block (atomic btr clears mask bits
        // so enclosing function exit will NOT double-run them, while running on throw/rethrow/return/normal exit!)
        if s.synth_defer_starts.len() > try_defer_start_idx
            x86_synth_emit_defers_range(s, toks, try_defer_start_idx)
        end

        // Rethrow any pending uncaught exception (either from try-without-catch OR rethrown from catch body!)
        x86_synth_emit_load_var(s, 0, fin_flag_off)
        x86_synth_emit_bytes(s, [72, 131, 248, 1, 15, 133]) // cmp rax, 1; jne rel32
        skip_rethrow_patch = s.synth_code.len()
        x86_synth_emit_u32(s, 0)
        x86_synth_emit_load_var(s, 7, fin_val_off) // mov rdi, [rbp - fin_val_off]
        x86_synth_emit_call_helper(s, "_lipi_exc_throw")
        after_rethrow = s.synth_code.len()
        x86_synth_patch_u32(s, skip_rethrow_patch, after_rethrow - (skip_rethrow_patch + 4))

        // Propagate or emit epilogue for pending return (fin_flag == 2)
        x86_synth_emit_load_var(s, 0, fin_flag_off)
        x86_synth_emit_bytes(s, [72, 131, 248, 2, 15, 133]) // cmp rax, 2; jne rel32
        skip_fin_ret_patch = s.synth_code.len()
        x86_synth_emit_u32(s, 0)
        x86_synth_emit_load_var(s, 0, fin_val_off)
        if s.synth_try_frames.len() > 0
            p_frame = s.synth_try_frames[s.synth_try_frames.len() - 1]
            p_flag_off = p_frame[0]
            p_val_off = p_frame[1]
            p_patches = p_frame[2]
            p_entry_depth = p_frame[3]
            p_pops = outer_try_depth - p_entry_depth
            if p_pops > 0
                x86_synth_emit_bytes(s, [80, 72, 131, 236, 8])
                pi_fp = 0
                while pi_fp < p_pops
                    x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                    pi_fp = pi_fp + 1
                end
                x86_synth_emit_bytes(s, [72, 131, 196, 8, 88])
            end
            x86_synth_emit_store_var(s, 0, p_val_off)
            x86_synth_emit_bytes(s, [184, 2, 0, 0, 0]) // mov eax, 2
            x86_synth_emit_store_var(s, 0, p_flag_off)
            x86_synth_emit_byte(s, 233)
            p_jmp_off = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            push(p_patches, p_jmp_off)
        else
            x86_synth_emit_defers(s, toks)
            x86_synth_emit_epilogue(s)
        end
        after_fin_ret = s.synth_code.len()
        x86_synth_patch_u32(s, skip_fin_ret_patch, after_fin_ret - (skip_fin_ret_patch + 4))

        // Propagate or dispatch pending loop break (fin_flag == 3) and continue (fin_flag == 4)
        // AFTER finally AND try-scoped defers have finished executing!
        if s.synth_loop_try_depths.len() > 0 and outer_try_depth >= s.synth_loop_try_depths[s.synth_loop_try_depths.len() - 1]
            l_td_fin = s.synth_loop_try_depths[s.synth_loop_try_depths.len() - 1]
            has_parent_loop_try = 0
            if s.synth_try_frames.len() > 0
                pf_lc = s.synth_try_frames[s.synth_try_frames.len() - 1]
                if pf_lc[3] >= l_td_fin
                    has_parent_loop_try = 1
                end
            end
            // Pending break (fin_flag == 3)
            x86_synth_emit_load_var(s, 0, fin_flag_off)
            x86_synth_emit_bytes(s, [72, 131, 248, 3, 15, 133]) // cmp rax, 3; jne rel32
            skip_fin_brk_patch = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            if has_parent_loop_try == 1
                pf_b = s.synth_try_frames[s.synth_try_frames.len() - 1]
                p_pops_b = outer_try_depth - pf_b[3]
                pib = 0
                while pib < p_pops_b
                    x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                    pib = pib + 1
                end
                x86_synth_emit_bytes(s, [184, 3, 0, 0, 0])
                x86_synth_emit_store_var(s, 0, pf_b[0])
                x86_synth_emit_byte(s, 233)
                pb_jmp = s.synth_code.len()
                x86_synth_emit_u32(s, 0)
                push(pf_b[2], pb_jmp)
            elif s.synth_loop_breaks.len() > 0
                x86_synth_emit_byte(s, 233)
                fb_jmp = s.synth_code.len()
                x86_synth_emit_u32(s, 0)
                push(s.synth_loop_breaks[s.synth_loop_breaks.len() - 1], fb_jmp)
            end
            after_fin_brk = s.synth_code.len()
            x86_synth_patch_u32(s, skip_fin_brk_patch, after_fin_brk - (skip_fin_brk_patch + 4))

            // Pending continue (fin_flag == 4)
            x86_synth_emit_load_var(s, 0, fin_flag_off)
            x86_synth_emit_bytes(s, [72, 131, 248, 4, 15, 133]) // cmp rax, 4; jne rel32
            skip_fin_cnt_patch = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            if has_parent_loop_try == 1
                pf_c = s.synth_try_frames[s.synth_try_frames.len() - 1]
                p_pops_c = outer_try_depth - pf_c[3]
                pic = 0
                while pic < p_pops_c
                    x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                    pic = pic + 1
                end
                x86_synth_emit_bytes(s, [184, 4, 0, 0, 0])
                x86_synth_emit_store_var(s, 0, pf_c[0])
                x86_synth_emit_byte(s, 233)
                pc_jmp = s.synth_code.len()
                x86_synth_emit_u32(s, 0)
                push(pf_c[2], pc_jmp)
            elif s.synth_loop_continues.len() > 0
                x86_synth_emit_byte(s, 233)
                fc_jmp = s.synth_code.len()
                x86_synth_emit_u32(s, 0)
                push(s.synth_loop_continues[s.synth_loop_continues.len() - 1], fc_jmp)
            elif s.synth_loop_starts.len() > 0
                lh_f = s.synth_loop_starts[s.synth_loop_starts.len() - 1]
                x86_synth_emit_byte(s, 233)
                x86_synth_emit_u32(s, lh_f - (s.synth_code.len() + 4))
            end
            after_fin_cnt = s.synth_code.len()
            x86_synth_patch_u32(s, skip_fin_cnt_patch, after_fin_cnt - (skip_fin_cnt_patch + 4))
        end

        s.synth_last_store_end = 0 - 1
        return 0

    // ── 9d. Contextual Pattern Match: match <expr> ... (preserves `match = 1`) ──
    if x86_synth_is_match_start(toks, pos) == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        x86_synth_compile_expr(s, toks, pos_box)
        // Store scrutinee in anonymous stack slot so arms can freely evaluate patterns
        scrut_off = s.synth_stack_offset
        s.synth_stack_offset = s.synth_stack_offset + 8
        x86_synth_emit_store_var(s, 0, scrut_off)
        match_end_patches = list()
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        match_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            match_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end

        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_pm = get(pos_box, 0)
            if cur_pm >= toks.len() break end
            ct_m = toks[cur_pm]
            if match_braced == 1
                if ct_m.tok_kind == TOK_RBRACE() or (ct_m.tok_kind != TOK_STR() and ct_m.tok_text == "}")
                    list_set(pos_box, 0, cur_pm + 1)
                    break
                end
                if ct_m.tok_kind == TOK_COMMA() or (ct_m.tok_kind != TOK_STR() and ct_m.tok_text == ",")
                    list_set(pos_box, 0, cur_pm + 1)
                    continue
                end
            else
                if ct_m.tok_kind == TOK_RBRACE() or (ct_m.tok_kind != TOK_STR() and ct_m.tok_text == "}")
                    break
                end
                if x86_synth_is_block_end(toks, cur_pm) == 1
                    if ct_m.tok_span.span_start_col >= base_col
                        list_set(pos_box, 0, cur_pm + 1)
                    end
                    break
                end
                if ct_m.tok_span.span_start_line > base_line and ct_m.tok_span.span_start_col <= base_col break end
            end
            arm_col = ct_m.tok_span.span_start_col
            arm_line = ct_m.tok_span.span_start_line
            if ct_m.tok_kind == TOK_KW_CASE() or (ct_m.tok_kind == TOK_IDENT() and (ct_m.tok_text == "case" or ct_m.tok_text == "ক্ষেত্র"))
                list_set(pos_box, 0, cur_pm + 1)
            end

            miss_patch = 0 - 1
            adt_miss_patches = 0
            pat_p = get(pos_box, 0)
            if pat_p < toks.len() and (toks[pat_p].tok_text == "_" or toks[pat_p].tok_text == "default" or toks[pat_p].tok_text == "অন্যথায়" or toks[pat_p].tok_kind == TOK_KW_ELSE())
                list_set(pos_box, 0, pat_p + 1)
            else
                adt_miss_patches = x86_synth_try_compile_adt_pattern(s, toks, pos_box, scrut_off)
                if adt_miss_patches == 0
                    // Compile value pattern -> %rsi, load scrutinee -> %rdi, call _lipi_cmp_dynamic (0 == equal)
                    x86_synth_compile_expr(s, toks, pos_box)
                    x86_synth_emit_bytes(s, [72, 137, 198])
                    x86_synth_emit_load_var(s, 7, scrut_off)
                    if s.synth_freestanding == 1
                        x86_synth_emit_bytes(s, [72, 57, 247, 15, 133]) // cmp rdi, rsi; jne next_arm
                    else
                        x86_synth_emit_call_helper(s, "_lipi_cmp_dynamic")
                        x86_synth_emit_bytes(s, [133, 192, 15, 133]) // test eax, eax; jnz next_arm
                    end
                    miss_patch = s.synth_code.len()
                    x86_synth_emit_u32(s, 0)
                end
            end

            if get(pos_box, 0) < toks.len()
                sep_k = toks[get(pos_box, 0)].tok_kind
                sep_txt = toks[get(pos_box, 0)].tok_text
                if sep_k == TOK_FAT_ARROW() or sep_k == TOK_COLON() or sep_k == TOK_ARROW() or sep_txt == "=>" or sep_txt == ":" or sep_txt == "->"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end

            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    cp_ab = get(pos_box, 0)
                    if cp_ab >= toks.len() break end
                    if toks[cp_ab].tok_kind == TOK_RBRACE() or (toks[cp_ab].tok_kind != TOK_STR() and toks[cp_ab].tok_text == "}")
                        list_set(pos_box, 0, cp_ab + 1)
                        break
                    end
                    bp_mb = get(pos_box, 0)
                    x86_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) <= bp_mb list_set(pos_box, 0, bp_mb + 1) end
                end
            elif get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == arm_line and toks[get(pos_box, 0)].tok_kind != TOK_NEWLINE() and toks[get(pos_box, 0)].tok_kind != TOK_SEMI() and toks[get(pos_box, 0)].tok_kind != TOK_COMMENT_LINE()
                bp_m = get(pos_box, 0)
                x86_synth_compile_statement(s, toks, pos_box)
                if get(pos_box, 0) <= bp_m list_set(pos_box, 0, bp_m + 1) end
            else
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    cp_ab = get(pos_box, 0)
                    if cp_ab >= toks.len() break end
                    ct_ab = toks[cp_ab]
                    if x86_synth_is_block_end(toks, cp_ab) == 1 break end
                    if match_braced == 1 and (ct_ab.tok_kind == TOK_RBRACE() or (ct_ab.tok_kind != TOK_STR() and ct_ab.tok_text == "}")) break end
                    if ct_ab.tok_span.span_start_line > arm_line and ct_ab.tok_span.span_start_col <= arm_col break end
                    bp_m2 = get(pos_box, 0)
                    x86_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) <= bp_m2 list_set(pos_box, 0, bp_m2 + 1) end
                end
            end

            x86_synth_emit_byte(s, 233)
            ep_m = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            push(match_end_patches, ep_m)

            if miss_patch >= 0
                next_arm_off = s.synth_code.len()
                x86_synth_patch_u32(s, miss_patch, next_arm_off - (miss_patch + 4))
            end
            if adt_miss_patches != 0
                next_arm_off = s.synth_code.len()
                ami = 0
                while ami < adt_miss_patches.len()
                    am_p = adt_miss_patches[ami]
                    x86_synth_patch_u32(s, am_p, next_arm_off - (am_p + 4))
                    ami = ami + 1
                end
            end
            s.synth_last_store_end = 0 - 1
        end

        end_m_off = s.synth_code.len()
        mi = 0
        while mi < match_end_patches.len()
            mp = match_end_patches[mi]
            x86_synth_patch_u32(s, mp, end_m_off - (mp + 4))
            mi = mi + 1
        end
        s.synth_last_store_end = 0 - 1
        return 0

    // ── 9d2. Deterministic Scoped Memory Region: region ... end / অঞ্চল ... শেষ ──
    // WHY: Captures arena watermark on entry and deterministically rolls back & releases
    // OS physical pages (MADV_DONTNEED) on block exit with 0% GC pause.
    if x86_synth_is_region_start(toks, pos) == 1
        reg_base_col = t.tok_span.span_start_col
        reg_base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        reg_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            reg_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        reg_mark_off = s.synth_stack_offset
        s.synth_stack_offset = s.synth_stack_offset + 8
        x86_synth_emit_call_helper(s, "_lipi_arena_mark")
        x86_synth_emit_store_var(s, 0, reg_mark_off)
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_pr = get(pos_box, 0)
            if cur_pr >= toks.len() break end
            ct_r = toks[cur_pr]
            if reg_braced == 1
                if ct_r.tok_kind == TOK_RBRACE() or (ct_r.tok_kind != TOK_STR() and ct_r.tok_text == "}")
                    list_set(pos_box, 0, cur_pr + 1)
                    break
                end
            else
                if ct_r.tok_kind == TOK_RBRACE() or (ct_r.tok_kind != TOK_STR() and ct_r.tok_text == "}")
                    break
                end
                if x86_synth_is_block_end(toks, cur_pr) == 1
                    if ct_r.tok_span.span_start_col >= reg_base_col
                        list_set(pos_box, 0, cur_pr + 1)
                    end
                    break
                end
                if ct_r.tok_span.span_start_line > reg_base_line and ct_r.tok_span.span_start_col <= reg_base_col break end
            end
            bp_r = get(pos_box, 0)
            x86_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) <= bp_r list_set(pos_box, 0, bp_r + 1) end
        end
        x86_synth_emit_load_var(s, 7, reg_mark_off) // mov rdi, [rbp - reg_mark_off]
        x86_synth_emit_call_helper(s, "_lipi_arena_reset")
        s.synth_last_store_end = 0 - 1
        return 0
    end

    // ── 9e. Mutable Global Declaration: global / @global / বিশ্বজনীন ───────────
    if k == TOK_IDENT() and (txt == "global" or txt == "@global" or txt == "বিশ্বজনীন")
        if pos + 1 < toks.len() and x86_synth_is_ident_token(toks[pos + 1].tok_kind) == 1
            if toks[pos + 1].tok_text != "="
                g_name = toks[pos + 1].tok_text
                g_off = x86_synth_alloc_mutable_global(s, g_name)
                x86_synth_mark_mutable_global_explicit(s, g_name)
                list_set(pos_box, 0, pos + 2)
                g_ann_type = ""
                g_np = get(pos_box, 0)
                if g_np < toks.len() and (toks[g_np].tok_kind == TOK_COLON() or (toks[g_np].tok_kind != TOK_STR() and toks[g_np].tok_text == ":"))
                    if g_np + 1 < toks.len() and x86_synth_is_ident_token(toks[g_np + 1].tok_kind) == 1
                        g_ann_type = toks[g_np + 1].tok_text
                        list_set(pos_box, 0, g_np + 2)
                    end
                end
                g_eqp = get(pos_box, 0)
                if g_eqp < toks.len() and (toks[g_eqp].tok_kind == TOK_ASSIGN() or (toks[g_eqp].tok_kind != TOK_STR() and toks[g_eqp].tok_text == "="))
                    list_set(pos_box, 0, g_eqp + 1)
                    x86_synth_compile_expr(s, toks, pos_box)
                    if x86_synth_is_narrow_int_type(g_ann_type) == 1
                        x86_synth_emit_truncate_int_width(s, g_ann_type)
                    end
                    x86_synth_emit_mutable_global_write(s, g_off)
                    g_prim = s.synth_last_expr_type
                    g_st = s.synth_last_struct
                    if x86_synth_is_uint_type(g_ann_type) == 1
                        g_prim = "uint"
                        if x86_synth_is_narrow_int_type(g_ann_type) == 1
                            g_st = g_ann_type
                        end
                    elif g_ann_type == "int" or g_ann_type == "i64" or g_ann_type == "i32" or g_ann_type == "i16" or g_ann_type == "i8"
                        g_prim = "int"
                        if x86_synth_is_narrow_int_type(g_ann_type) == 1
                            g_st = g_ann_type
                        end
                    elif g_ann_type == "float" or g_ann_type == "f64" or g_ann_type == "f32"
                        g_prim = "float"
                    elif g_ann_type == "str" or g_ann_type == "string"
                        g_prim = "str"
                    elif g_ann_type != ""
                        g_st = g_ann_type
                    end
                    x86_synth_set_mutable_global_types(s, g_name, g_prim, g_st)
                elif g_ann_type != ""
                    g_p2 = ""
                    g_s2 = ""
                    if x86_synth_is_uint_type(g_ann_type) == 1
                        g_p2 = "uint"
                        if x86_synth_is_narrow_int_type(g_ann_type) == 1
                            g_s2 = g_ann_type
                        end
                    elif g_ann_type == "int" or g_ann_type == "i64" or g_ann_type == "i32" or g_ann_type == "i16" or g_ann_type == "i8"
                        g_p2 = "int"
                        if x86_synth_is_narrow_int_type(g_ann_type) == 1
                            g_s2 = g_ann_type
                        end
                    elif g_ann_type == "float" or g_ann_type == "f64" or g_ann_type == "f32"
                        g_p2 = "float"
                    elif g_ann_type == "str" or g_ann_type == "string"
                        g_p2 = "str"
                    else
                        g_s2 = g_ann_type
                    end
                    x86_synth_set_mutable_global_types(s, g_name, g_p2, g_s2)
                end
                return 0
            end
        end
    end

    // ── 10. Assignment: <var> = <expr>, multi-var destructuring a, b = rhs1, rhs2, <var>: <type> = <expr>, or <var> <op>= <expr> ──
    if x86_synth_is_ident_token(k) == 1
        var_name = txt
        assigned_type = ""
        next_pos = pos + 1
        // Multi-variable tuple destructuring & swap: a, b [, c...] = rhs1 [, rhs2...]
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_COMMA() or (toks[next_pos].tok_kind != TOK_STR() and toks[next_pos].tok_text == ","))
            ma_names = [var_name]
            ma_p = next_pos
            ma_ok = 1
            while ma_p < toks.len()
                if toks[ma_p].tok_kind == TOK_COMMA() or (toks[ma_p].tok_kind != TOK_STR() and toks[ma_p].tok_text == ",")
                    ma_p = ma_p + 1
                    if ma_p < toks.len() and x86_synth_is_ident_token(toks[ma_p].tok_kind) == 1
                        push(ma_names, toks[ma_p].tok_text)
                        ma_p = ma_p + 1
                    else
                        ma_ok = 0
                        break
                    end
                else
                    break
                end
            end
            if ma_ok == 1 and ma_names.len() >= 2 and ma_p < toks.len() and (toks[ma_p].tok_kind == TOK_ASSIGN() or (toks[ma_p].tok_kind != TOK_STR() and toks[ma_p].tok_text == "="))
                ma_ln = toks[ma_p].tok_span.span_start_line
                list_set(pos_box, 0, ma_p + 1)
                ma_rhs_types = list()
                ma_rhs_structs = list()
                ma_rcnt = 0
                while 1 == 1
                    x86_synth_compile_expr(s, toks, pos_box)
                    push(ma_rhs_types, s.synth_last_expr_type)
                    push(ma_rhs_structs, s.synth_last_struct)
                    x86_synth_emit_byte(s, 80) // push rax
                    ma_rcnt = ma_rcnt + 1
                    mp2 = get(pos_box, 0)
                    if mp2 < toks.len() and (toks[mp2].tok_kind == TOK_COMMA() or (toks[mp2].tok_kind != TOK_STR() and toks[mp2].tok_text == ",")) and toks[mp2].tok_span.span_start_line == ma_ln
                        list_set(pos_box, 0, mp2 + 1)
                    else
                        break
                    end
                end
                if ma_rcnt == 1
                    // Unpack single tuple/list RHS into ma_names[0..N-1]
                    tup_tmp2 = s.synth_stack_offset
                    s.synth_stack_offset = s.synth_stack_offset + 8
                    x86_synth_emit_byte(s, 88) // pop rax
                    x86_synth_emit_store_var(s, 0, tup_tmp2)
                    mai = 0
                    while mai < ma_names.len()
                        mn_u = ma_names[mai]
                        x86_synth_emit_load_var(s, 7, tup_tmp2) // mov rdi, [rbp - tup_tmp2]
                        x86_synth_emit_mov_rax_imm64(s, mai)
                        x86_synth_emit_bytes(s, [72, 137, 198]) // mov rsi, rax
                        x86_synth_emit_call_helper(s, "_lipi_list_get")
                        mg_u = x86_synth_find_mutable_global(s, mn_u)
                        lv_u = x86_synth_find_local_var(s, mn_u)
                        if lv_u == 0 and mg_u >= 512 and (s.synth_in_function == 0 or x86_synth_is_mutable_global_name(mn_u) == 1 or x86_synth_is_explicit_mutable_global(s, mn_u) == 1)
                            x86_synth_emit_mutable_global_write(s, mg_u)
                            x86_synth_set_mutable_global_types(s, mn_u, "", "")
                        else
                            x86_synth_bind_var(s, mn_u)
                            x86_synth_set_var_type(s, mn_u, "")
                            x86_synth_set_prim_type(s, mn_u, "")
                        end
                        mai = mai + 1
                    end
                else
                    while ma_rcnt > ma_names.len()
                        x86_synth_emit_byte(s, 88) // discard excess RHS
                        ma_rcnt = ma_rcnt - 1
                    end
                    mai_z = ma_names.len() - 1
                    while mai_z >= ma_rcnt
                        x86_synth_emit_bytes(s, [49, 192]) // xor eax, eax
                        x86_synth_bind_var(s, ma_names[mai_z])
                        x86_synth_set_prim_type(s, ma_names[mai_z], "int")
                        mai_z = mai_z - 1
                    end
                    mai_r = ma_rcnt - 1
                    while mai_r >= 0
                        x86_synth_emit_byte(s, 88) // pop rax
                        mn_p = ma_names[mai_r]
                        mg_p2 = x86_synth_find_mutable_global(s, mn_p)
                        lv_p2 = x86_synth_find_local_var(s, mn_p)
                        if lv_p2 == 0 and mg_p2 >= 512 and (s.synth_in_function == 0 or x86_synth_is_mutable_global_name(mn_p) == 1 or x86_synth_is_explicit_mutable_global(s, mn_p) == 1)
                            x86_synth_emit_mutable_global_write(s, mg_p2)
                            x86_synth_set_mutable_global_types(s, mn_p, ma_rhs_types[mai_r], ma_rhs_structs[mai_r])
                        else
                            x86_synth_bind_var(s, mn_p)
                            if mai_r < ma_rhs_structs.len() and ma_rhs_structs[mai_r] != ""
                                x86_synth_set_var_type(s, mn_p, ma_rhs_structs[mai_r])
                            end
                            if mai_r < ma_rhs_types.len()
                                x86_synth_set_prim_type(s, mn_p, ma_rhs_types[mai_r])
                            end
                        end
                        mai_r = mai_r - 1
                    end
                end
                return 0
            end
        end
        // WHY: Support typed variable declarations: name: Type[<...>] = expr
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_COLON() or (toks[next_pos].tok_kind != TOK_STR() and toks[next_pos].tok_text == ":"))
            t_scan_box = [next_pos + 1]
            raw_at2 = x86_synth_parse_type_expr(toks, t_scan_box)
            after_type = get(t_scan_box, 0)
            if raw_at2 != "" and after_type < toks.len() and (toks[after_type].tok_kind == TOK_ASSIGN() or (toks[after_type].tok_kind != TOK_STR() and toks[after_type].tok_text == "="))
                assigned_type = x86_synth_subst_type(s, raw_at2, 0, 0)
                next_pos = after_type
            end
        end
        if next_pos < toks.len()
            ntk = toks[next_pos]
            nk = ntk.tok_kind
            ntxt = ntk.tok_text
            is_assign = 0
            is_compound = 0
            comp_op = 0
            comp_tok_adv = 1
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
            elif next_pos + 1 < toks.len() and (toks[next_pos + 1].tok_kind == TOK_ASSIGN() or (toks[next_pos + 1].tok_kind != TOK_STR() and toks[next_pos + 1].tok_text == "="))
                if nk == TOK_SHR() or (nk != TOK_STR() and ntxt == ">>")
                    is_assign = 1
                    is_compound = 1
                    comp_op = TOK_SHR()
                    comp_tok_adv = 2
                elif nk == TOK_SHL() or (nk != TOK_STR() and ntxt == "<<")
                    is_assign = 1
                    is_compound = 1
                    comp_op = TOK_SHL()
                    comp_tok_adv = 2
                elif nk == TOK_AMP() or (nk != TOK_STR() and ntxt == "&")
                    is_assign = 1
                    is_compound = 1
                    comp_op = TOK_AMP()
                    comp_tok_adv = 2
                elif nk == TOK_BAR() or (nk != TOK_STR() and ntxt == "|")
                    is_assign = 1
                    is_compound = 1
                    comp_op = TOK_BAR()
                    comp_tok_adv = 2
                elif nk == TOK_CARET() or (nk != TOK_STR() and ntxt == "^")
                    is_assign = 1
                    is_compound = 1
                    comp_op = TOK_CARET()
                    comp_tok_adv = 2
                end
            end

            if is_assign == 1
                is_int_lit = 0
                int_lit_val = 0
                if is_compound == 0 and next_pos + 1 < toks.len()
                    rhs_tok = toks[next_pos + 1]
                    if rhs_tok.tok_kind == TOK_INT()
                        after_rhs = next_pos + 2
                        if after_rhs >= toks.len() or toks[after_rhs].tok_kind == TOK_NEWLINE() or toks[after_rhs].tok_kind == TOK_SEMI() or toks[after_rhs].tok_kind == TOK_COMMENT_LINE()
                            is_int_lit = 1
                            int_lit_val = rhs_tok.tok_int_val
                        end
                    end
                end
                lv_mg_chk = x86_synth_find_local_var(s, var_name)
                mg_cur_off = x86_synth_find_mutable_global(s, var_name)
                is_mg_target = 0
                if s.synth_in_function == 0
                    if x86_synth_is_mutable_global_name(var_name) == 1 or (lv_mg_chk == 0 and mg_cur_off >= 512)
                        is_mg_target = 1
                    end
                else
                    if lv_mg_chk == 0 and mg_cur_off >= 512 and (x86_synth_is_mutable_global_name(var_name) == 1 or x86_synth_is_explicit_mutable_global(s, var_name) == 1 or is_compound == 1)
                        is_mg_target = 1
                    end
                end
                if is_compound == 0
                    // Fast Path A & B: Direct 1-cycle in-register increment/accumulate for unspilled integer locals:
                    //   1) `x = x + k` or `x = x - k` (0 <= k <= 127) -> single `add/sub reg, imm8`
                    //   2) `x = x + (pure_int_expr)` -> evaluate `(expr)` into %rax, then single `add reg, rax`
                    if is_mg_target == 0 and assigned_type == "" and next_pos + 3 < toks.len()
                        lv_fast = x86_synth_find_local_var(s, var_name)
                        if lv_fast != 0 and lv_fast.lv_is_spilled == 0 and lv_fast.lv_reg >= 0 and lv_fast.lv_prim_type == "int" and lv_fast.lv_tag_off == 0
                            ft1 = toks[next_pos + 1]
                            ft2 = toks[next_pos + 2]
                            ft3 = toks[next_pos + 3]
                            if x86_synth_is_ident_token(ft1.tok_kind) == 1 and ft1.tok_text == var_name
                                is_fplus = 0
                                is_fminus = 0
                                if ft2.tok_kind == TOK_PLUS() or ft2.tok_text == "+"
                                    is_fplus = 1
                                elif ft2.tok_kind == TOK_MINUS() or ft2.tok_text == "-"
                                    is_fminus = 1
                                end
                                // Case 1: x = x + k / x = x - k
                                if (is_fplus == 1 or is_fminus == 1) and ft3.tok_kind == TOK_INT()
                                    fk = ft3.tok_int_val
                                    f_ok_end = 0
                                    if next_pos + 4 >= toks.len()
                                        f_ok_end = 1
                                    else
                                        fak = toks[next_pos + 4].tok_kind
                                        if fak == TOK_NEWLINE() or fak == TOK_SEMI() or fak == TOK_COMMENT_LINE() or fak == TOK_COMMENT_BLOCK()
                                            f_ok_end = 1
                                        end
                                    end
                                    if f_ok_end == 1 and fk >= 0 and fk <= 127
                                        freg = lv_fast.lv_reg
                                        fmod = 192
                                        if is_fminus == 1
                                            fmod = 232
                                        end
                                        if freg < 8
                                            x86_synth_emit_byte(s, 72)
                                            x86_synth_emit_byte(s, 131)
                                            x86_synth_emit_byte(s, fmod + freg)
                                            x86_synth_emit_byte(s, fk)
                                        else
                                            x86_synth_emit_byte(s, 73)
                                            x86_synth_emit_byte(s, 131)
                                            x86_synth_emit_byte(s, fmod + (freg - 8))
                                            x86_synth_emit_byte(s, fk)
                                        end
                                        list_set(pos_box, 0, next_pos + 4)
                                        return 0
                                    end
                                end
                                // Case 2: x = x + (pure_int_expr) with matching ')' at end of statement
                                if is_fplus == 1 and (ft3.tok_kind == TOK_LPAREN() or ft3.tok_text == "(")
                                    sp_i = next_pos + 4
                                    sp_depth = 1
                                    sp_pure = 1
                                    while sp_i < toks.len() and sp_depth > 0
                                        stk = toks[sp_i]
                                        sk = stk.tok_kind
                                        if sk == TOK_LPAREN() or stk.tok_text == "("
                                            sp_depth = sp_depth + 1
                                        elif sk == TOK_RPAREN() or stk.tok_text == ")"
                                            sp_depth = sp_depth - 1
                                            if sp_depth == 0
                                                break
                                            end
                                        elif sk == TOK_STR() or sk == TOK_FLOAT()
                                            sp_pure = 0
                                            break
                                        elif x86_synth_is_ident_token(sk) == 1
                                            if sp_i + 1 < toks.len() and (toks[sp_i + 1].tok_kind == TOK_LPAREN() or toks[sp_i + 1].tok_text == "(" or toks[sp_i + 1].tok_kind == TOK_DOT() or toks[sp_i + 1].tok_kind == TOK_LBRACKET())
                                                sp_pure = 0
                                                break
                                            end
                                            lv_inner = x86_synth_find_local_var(s, stk.tok_text)
                                            if lv_inner != 0 and (lv_inner.lv_prim_type == "str" or lv_inner.lv_prim_type == "float" or lv_inner.lv_prim_type == "dyn_tagged" or lv_inner.lv_tag_off > 0)
                                                sp_pure = 0
                                                break
                                            end
                                        end
                                        sp_i = sp_i + 1
                                    end
                                    if sp_pure == 1 and sp_depth == 0
                                        sp_end_ok = 0
                                        if sp_i + 1 >= toks.len()
                                            sp_end_ok = 1
                                        else
                                            se_k = toks[sp_i + 1].tok_kind
                                            if se_k == TOK_NEWLINE() or se_k == TOK_SEMI() or se_k == TOK_COMMENT_LINE() or se_k == TOK_COMMENT_BLOCK()
                                                sp_end_ok = 1
                                            end
                                        end
                                        if sp_end_ok == 1
                                            list_set(pos_box, 0, next_pos + 3)
                                            x86_synth_compile_expr(s, toks, pos_box)
                                            freg2 = lv_fast.lv_reg
                                            // add freg2, rax (REX.W + 01 /0)
                                            if freg2 < 8
                                                x86_synth_emit_byte(s, 72)
                                                x86_synth_emit_byte(s, 1)
                                                x86_synth_emit_byte(s, 192 + freg2)
                                            else
                                                x86_synth_emit_byte(s, 73)
                                                x86_synth_emit_byte(s, 1)
                                                x86_synth_emit_byte(s, 192 + (freg2 - 8))
                                            end
                                            return 0
                                        end
                                    end
                                end
                            end
                        end
                    end

                    list_set(pos_box, 0, next_pos + 1) // Consume ident [ : type ] and '='
                    x86_synth_compile_expr(s, toks, pos_box)
                    if is_mg_target == 1
                        mg_slot = x86_synth_alloc_mutable_global(s, var_name)
                        eff_mg_t = assigned_type
                        if eff_mg_t == ""
                            eff_mg_t = x86_synth_get_mutable_global_struct(s, var_name)
                        end
                        if x86_synth_is_narrow_int_type(eff_mg_t) == 1
                            x86_synth_emit_truncate_int_width(s, eff_mg_t)
                        end
                        x86_synth_emit_mutable_global_write(s, mg_slot)
                        mg_p = s.synth_last_expr_type
                        mg_st = s.synth_last_struct
                        if x86_synth_is_uint_type(eff_mg_t) == 1
                            mg_p = "uint"
                            if x86_synth_is_narrow_int_type(eff_mg_t) == 1
                                mg_st = eff_mg_t
                            end
                        elif eff_mg_t == "int" or eff_mg_t == "i64" or eff_mg_t == "i32" or eff_mg_t == "i16" or eff_mg_t == "i8"
                            mg_p = "int"
                            if x86_synth_is_narrow_int_type(eff_mg_t) == 1
                                mg_st = eff_mg_t
                            end
                        elif assigned_type == "float" or assigned_type == "f64" or assigned_type == "f32"
                            mg_p = "float"
                        elif assigned_type == "str" or assigned_type == "string"
                            mg_p = "str"
                        elif assigned_type != ""
                            mg_st = assigned_type
                        end
                        x86_synth_set_mutable_global_types(s, var_name, mg_p, mg_st)
                        s.synth_last_elem_type = ""
                        return 0
                    end
                    eff_asg_type = assigned_type
                    if eff_asg_type == ""
                        eff_asg_type = x86_synth_get_var_type(s, var_name)
                    end
                    if x86_synth_is_narrow_int_type(eff_asg_type) == 1
                        x86_synth_emit_truncate_int_width(s, eff_asg_type)
                    end
                    off = x86_synth_bind_var(s, var_name)
                    lv_asg_post = x86_synth_find_local_var(s, var_name)
                    if assigned_type != ""
                        x86_synth_set_var_type(s, var_name, assigned_type)
                        if x86_synth_is_uint_type(assigned_type) == 1 or x86_synth_is_ptr_type(assigned_type) == 1
                            x86_synth_set_prim_type(s, var_name, "uint")
                        elif assigned_type == "int" or assigned_type == "i64" or assigned_type == "i32" or assigned_type == "i16" or assigned_type == "i8"
                            x86_synth_set_prim_type(s, var_name, "int")
                        elif assigned_type == "float" or assigned_type == "f64" or assigned_type == "f32"
                            x86_synth_set_prim_type(s, var_name, "float")
                        elif assigned_type == "str" or assigned_type == "string"
                            x86_synth_set_prim_type(s, var_name, "str")
                    if is_int_lit == 1
                        if s.synth_in_function == 0 and x86_synth_is_uint_type(eff_asg_type) == 0 and x86_synth_is_narrow_int_type(eff_asg_type) == 0 and x86_synth_is_ptr_type(eff_asg_type) == 0
                            x86_synth_set_global_const(s, var_name, int_lit_val)
                        end
                        if x86_synth_is_uint_type(eff_asg_type) == 1 or x86_synth_is_ptr_type(eff_asg_type) == 1
                            x86_synth_set_prim_type(s, var_name, "uint")
                        elif assigned_type == "" and lv_asg_post != 0 and lv_asg_post.lv_tag_off > 0
                            x86_synth_set_prim_type(s, var_name, "dyn_tagged")
                        else
                            x86_synth_set_prim_type(s, var_name, "int")
                        end
                    elif assigned_type == "" and lv_asg_post != 0 and lv_asg_post.lv_tag_off > 0
                        x86_synth_set_prim_type(s, var_name, "dyn_tagged")
                    elif x86_synth_is_uint_type(eff_asg_type) == 1 or x86_synth_is_ptr_type(eff_asg_type) == 1 or s.synth_last_expr_type == "uint"
                        x86_synth_set_prim_type(s, var_name, "uint")
                    elif s.synth_last_expr_type == "int"
                        x86_synth_set_prim_type(s, var_name, "int")
                    elif s.synth_last_expr_type == "float"
                        x86_synth_set_prim_type(s, var_name, "float")
                    elif s.synth_last_expr_type == "str"
                        x86_synth_set_prim_type(s, var_name, "str")
                    elif s.synth_last_expr_type == "dyn_tagged"
                        x86_synth_set_prim_type(s, var_name, "dyn_tagged")
                    elif eff_asg_type == ""
                        x86_synth_set_prim_type(s, var_name, "")
                    return 0
                else
                    // Compound assignment: target += expr, target -= expr, /=, %=, >>=, <<=, &=, |=, ^=
                    list_set(pos_box, 0, next_pos + comp_tok_adv) // Consume ident and op=
                    // Evaluate RHS expression into %rax (and %rdx = rtag if dyn_tagged)
                    x86_synth_compile_expr(s, toks, pos_box)
                    rhs_comp_type = s.synth_last_expr_type
                    lv_tgt = x86_synth_find_local_var(s, var_name)
                    pt_pre = ""
                    if is_mg_target == 0
                        pt_pre = x86_synth_get_prim_type(s, var_name)
                    end
                    is_arith_comp = 0
                    if comp_op == TOK_PLUS() or comp_op == TOK_MINUS() or comp_op == TOK_STAR() or comp_op == TOK_SLASH() or comp_op == TOK_PERCENT()
                        is_arith_comp = 1
                    end
                    // Runtime-tagged compound assignment fast path via _lipi_binop_tagged
                    if is_arith_comp == 1 and s.synth_freestanding == 0 and is_mg_target == 0 and (pt_pre == "dyn_tagged" or rhs_comp_type == "dyn_tagged" or (lv_tgt != 0 and lv_tgt.lv_tag_off > 0))
                        tag_op = 0
                        if comp_op == TOK_MINUS()
                            tag_op = 1
                        elif comp_op == TOK_STAR()
                            tag_op = 2
                        elif comp_op == TOK_SLASH()
                            tag_op = 3
                        elif comp_op == TOK_PERCENT()
                            tag_op = 4
                        end
                        // %rsi = rhs, %rcx = rtag (preserve %rdx before loading ltag!)
                        x86_synth_emit_bytes(s, [72, 137, 198]) // mov rsi, rax
                        if rhs_comp_type == "dyn_tagged"
                            x86_synth_emit_bytes(s, [72, 137, 209]) // mov rcx, rdx
                        elif rhs_comp_type == "float"
                            x86_synth_emit_bytes(s, [185, 1, 0, 0, 0]) // mov ecx, 1
                        elif rhs_comp_type == "str"
                            x86_synth_emit_bytes(s, [185, 2, 0, 0, 0]) // mov ecx, 2
                        else
                            x86_synth_emit_bytes(s, [49, 201]) // xor ecx, ecx
                        end
                        // %rdi = lhs (without clobbering %rsi or %rcx)
                        off = 0
                        if lv_tgt != 0 and lv_tgt.lv_is_spilled == 0 and lv_tgt.lv_reg >= 0
                            x86_synth_emit_mov_reg_reg(s, 7, lv_tgt.lv_reg)
                            off = lv_tgt.lv_offset
                        else
                            off = x86_synth_alloc_var(s, var_name)
                            lv_tgt = x86_synth_find_local_var(s, var_name)
                            x86_synth_emit_load_var(s, 7, off)
                            if lv_tgt != 0 and lv_tgt.lv_is_boxed == 1
                                x86_synth_emit_bytes(s, [72, 139, 63]) // mov rdi, [rdi]
                            end
                        end
                        // %rdx = ltag
                        if lv_tgt != 0 and lv_tgt.lv_tag_off > 0
                            x86_synth_emit_load_var(s, 2, lv_tgt.lv_tag_off) // mov rdx, [rbp - lv_tag_off]
                        elif pt_pre == "float"
                            x86_synth_emit_bytes(s, [186, 1, 0, 0, 0]) // mov edx, 1
                        elif pt_pre == "str"
                            x86_synth_emit_bytes(s, [186, 2, 0, 0, 0]) // mov edx, 2
                        else
                            x86_synth_emit_bytes(s, [49, 210]) // xor edx, edx
                        end
                        // %r8d = tag_op; call _lipi_binop_tagged -> %rax = res, %rdx = res_tag
                        x86_synth_emit_bytes(s, [65, 184])
                        x86_synth_emit_u32(s, tag_op)
                        x86_synth_emit_call_helper(s, "_lipi_binop_tagged")
                        if lv_tgt != 0
                            if lv_tgt.lv_tag_off == 0
                                lv_tgt.lv_tag_off = s.synth_stack_offset
                                s.synth_stack_offset = s.synth_stack_offset + 8
                                push(s.synth_fn_tag_offs, lv_tgt.lv_tag_off)
                            end
                            x86_synth_emit_store_var(s, 2, lv_tgt.lv_tag_off) // mov [rbp - lv_tag_off], rdx
                        end
                        x86_synth_set_prim_type(s, var_name, "dyn_tagged")
                        if lv_tgt != 0 and lv_tgt.lv_is_boxed == 1
                            x86_synth_emit_load_var(s, 2, off) // mov rdx, [rbp - off] (cell ptr)
                            x86_synth_emit_bytes(s, [72, 137, 2]) // mov [rdx], rax
                            s.synth_last_store_end = 0 - 1
                        elif lv_tgt != 0 and lv_tgt.lv_is_spilled == 0 and lv_tgt.lv_reg >= 0
                            x86_synth_emit_mov_reg_reg(s, lv_tgt.lv_reg, 0)
                            x86_synth_emit_store_var(s, 0, off)
                        else
                            x86_synth_emit_store_var(s, 0, off)
                        end
                        return 0
                    end
                    // mov rcx, rax (save RHS in rcx)
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 193)
                    // Load current value of target var into %rax
                    off = 0
                    pt = ""
                    if is_mg_target == 1
                        mg_cur_off = x86_synth_alloc_mutable_global(s, var_name)
                        x86_synth_emit_mutable_global_read(s, mg_cur_off)
                        pt = x86_synth_get_mutable_global_prim(s, var_name)
                    elif lv_tgt != 0 and lv_tgt.lv_is_spilled == 0 and lv_tgt.lv_reg >= 0
                        x86_synth_emit_mov_reg_reg(s, 0, lv_tgt.lv_reg)
                        off = lv_tgt.lv_offset
                        pt = x86_synth_get_prim_type(s, var_name)
                    else
                        off = x86_synth_alloc_var(s, var_name)
                        x86_synth_emit_load_var(s, 0, off)
                        if lv_tgt != 0 and lv_tgt.lv_is_boxed == 1
                            x86_synth_emit_bytes(s, [72, 139, 0]) // mov rax, [rax]
                        end
                        pt = x86_synth_get_prim_type(s, var_name)
                    end
                    res_comp_prim = pt
                    is_uint_comp = 0
                    if pt == "uint" or rhs_comp_type == "uint"
                        is_uint_comp = 1
                    end
                    if is_arith_comp == 1 and (pt == "float" or rhs_comp_type == "float") and comp_op != TOK_PERCENT()
                        if pt == "float"
                            x86_synth_emit_bytes(s, [102, 72, 15, 110, 192]) // movq xmm0, rax
                        else
                            x86_synth_emit_bytes(s, [242, 72, 15, 42, 192])  // cvtsi2sd xmm0, rax
                        end
                        if rhs_comp_type == "float"
                            x86_synth_emit_bytes(s, [102, 72, 15, 110, 201]) // movq xmm1, rcx
                        else
                            x86_synth_emit_bytes(s, [242, 72, 15, 42, 201])  // cvtsi2sd xmm1, rcx
                        end
                        if comp_op == TOK_PLUS()
                            x86_synth_emit_bytes(s, [242, 15, 88, 193])
                        elif comp_op == TOK_MINUS()
                            x86_synth_emit_bytes(s, [242, 15, 92, 193])
                        elif comp_op == TOK_STAR()
                            x86_synth_emit_bytes(s, [242, 15, 89, 193])
                        elif comp_op == TOK_SLASH()
                            x86_synth_emit_bytes(s, [242, 15, 94, 193])
                        end
                        x86_synth_emit_bytes(s, [102, 72, 15, 126, 192]) // movq rax, xmm0
                        res_comp_prim = "float"
                    elif comp_op == TOK_PLUS()
                        if s.synth_freestanding == 1 or ((pt == "int" or pt == "uint" or rhs_comp_type == "int" or rhs_comp_type == "uint") and pt != "str" and rhs_comp_type != "str")
                            // Native hardware add rax, rcx (0x48 0x01 0xC8) - 1 cycle silicon execution!
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 1)
                            x86_synth_emit_byte(s, 200)
                            if is_uint_comp == 1
                                res_comp_prim = "uint"
                            else
                                res_comp_prim = "int"
                            end
                        else
                            // Safe dynamic fallback for strings, lists, objects
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 137)
                            x86_synth_emit_byte(s, 199)
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 137)
                            x86_synth_emit_byte(s, 206)
                            x86_synth_emit_call_helper(s, "_lipi_add_dynamic")
                            res_comp_prim = ""
                        end
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
                        if is_uint_comp == 1
                            // WHY: Unsigned division (u8/u16/u32/u64): call _lipi_div_by_zero in hosted mode
                            // matching `/` so `try { u /= 0 } catch e` throws DivisionByZeroException.
                            if s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [72, 133, 201, 117, 7])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [235, 5, 49, 210, 72, 247, 241])
                            else
                                x86_synth_emit_bytes(s, [72, 133, 201, 117, 4, 49, 192, 235, 5, 49, 210, 72, 247, 241])
                            end
                            res_comp_prim = "uint"
                        elif s.synth_freestanding == 0
                            // WHY: Hosted compound `/=` calls _lipi_div_by_zero on divisor == 0 (matching `/`)
                            // and guards INT64_MIN / -1 without #DE SIGFPE.
                            x86_synth_emit_bytes(s, [72, 133, 201, 117, 7])
                            x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                            x86_synth_emit_bytes(s, [235, 16, 72, 131, 249, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 72, 247, 249])
                        else
                            // Freestanding division-by-zero & INT64_MIN / -1 guarded cqo; idiv rcx
                            x86_synth_emit_bytes(s, [72, 133, 201, 117, 4, 49, 192, 235, 16, 72, 131, 249, 255, 117, 5, 72, 247, 216, 235, 5, 72, 153, 72, 247, 249])
                        end
                    elif comp_op == TOK_PERCENT()
                        if is_uint_comp == 1
                            // WHY: Unsigned modulo (u8/u16/u32/u64): call _lipi_div_by_zero in hosted mode
                            // matching `%` so `try { u %= 0 } catch e` throws DivisionByZeroException.
                            if s.synth_freestanding == 0
                                x86_synth_emit_bytes(s, [72, 133, 201, 117, 7])
                                x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                                x86_synth_emit_bytes(s, [235, 8, 49, 210, 72, 247, 241, 72, 137, 208])
                            else
                                x86_synth_emit_bytes(s, [72, 133, 201, 117, 4, 49, 192, 235, 8, 49, 210, 72, 247, 241, 72, 137, 208])
                            end
                            res_comp_prim = "uint"
                        elif s.synth_freestanding == 0
                            // WHY: Hosted compound `%=` calls _lipi_div_by_zero on divisor == 0 (matching `%`)
                            // and guards INT64_MIN % -1 -> 0 without #DE SIGFPE.
                            x86_synth_emit_bytes(s, [72, 133, 201, 117, 7])
                            x86_synth_emit_call_helper(s, "_lipi_div_by_zero")
                            x86_synth_emit_bytes(s, [235, 18, 72, 131, 249, 255, 117, 4, 49, 192, 235, 8, 72, 153, 72, 247, 249, 72, 137, 208])
                        else
                            // Freestanding modulo-by-zero & INT64_MIN % -1 guarded cqo; idiv rcx; mov rax, rdx
                            x86_synth_emit_bytes(s, [72, 133, 201, 117, 4, 49, 192, 235, 18, 72, 131, 249, 255, 117, 4, 49, 192, 235, 8, 72, 153, 72, 247, 249, 72, 137, 208])
                        end
                    elif comp_op == TOK_SHR()
                        if pt == "uint"
                            // Logical shift right: shr rax, cl (0x48 0xD3 0xE8)
                            x86_synth_emit_bytes(s, [72, 211, 232])
                            res_comp_prim = "uint"
                        else
                            // Arithmetic shift right: sar rax, cl (0x48 0xD3 0xF8)
                            x86_synth_emit_bytes(s, [72, 211, 248])
                        end
                    elif comp_op == TOK_SHL()
                        // shl rax, cl (0x48 0xD3 0xE0)
                        x86_synth_emit_bytes(s, [72, 211, 224])
                    elif comp_op == TOK_AMP()
                        // and rax, rcx (0x48 0x21 0xC8)
                        x86_synth_emit_bytes(s, [72, 33, 200])
                    elif comp_op == TOK_BAR()
                        // or rax, rcx (0x48 0x09 0xC8)
                        x86_synth_emit_bytes(s, [72, 9, 200])
                    elif comp_op == TOK_CARET()
                        // xor rax, rcx (0x48 0x31 0xC8)
                        x86_synth_emit_bytes(s, [72, 49, 200])
                    end
                    // Truncate to fixed narrow integer bit-width (u8/u16/u32/i8/i16/i32) before storing
                    if is_mg_target == 1
                        mg_ct = x86_synth_get_mutable_global_struct(s, var_name)
                        if x86_synth_is_narrow_int_type(mg_ct) == 1
                            x86_synth_emit_truncate_int_width(s, mg_ct)
                        end
                        x86_synth_emit_mutable_global_write(s, mg_cur_off)
                        x86_synth_set_mutable_global_types(s, var_name, res_comp_prim, mg_ct)
                    else
                        lv_ct = x86_synth_get_var_type(s, var_name)
                        if x86_synth_is_narrow_int_type(lv_ct) == 1
                            x86_synth_emit_truncate_int_width(s, lv_ct)
                        end
                        x86_synth_set_prim_type(s, var_name, res_comp_prim)
                        if lv_tgt != 0 and lv_tgt.lv_is_boxed == 1
                            x86_synth_emit_load_var(s, 2, off) // mov rdx, [rbp - off] (cell ptr)
                            x86_synth_emit_bytes(s, [72, 137, 2]) // mov [rdx], rax
                            s.synth_last_store_end = 0 - 1
                        elif lv_tgt != 0 and lv_tgt.lv_is_spilled == 0 and lv_tgt.lv_reg >= 0
                            // WHY: Update physical register directly and keep stack slot synchronized.
                            x86_synth_emit_mov_reg_reg(s, lv_tgt.lv_reg, 0)
                            x86_synth_emit_store_var(s, 0, off)
                        else
                            x86_synth_emit_store_var(s, 0, off)
                        end
                    end
                    return 0

    // ── 11. Function & Component Definition: canonical TOK_KW_ASYNC / TOK_KW_FN / TOK_KW_COMPONENT ──
    if k == TOK_KW_ASYNC() and pos + 1 < toks.len()
        nt_af = toks[pos + 1]
        if nt_af.tok_kind == TOK_KW_FN() or nt_af.tok_kind == TOK_DIR_FN()
            s.synth_pending_fn_async = 1
            s.synth_pending_fn_base_col = t.tok_span.span_start_col
            list_set(pos_box, 0, pos + 1)
            return x86_synth_compile_fn_def(s, toks, pos_box)
        end
    end
    is_fn = 0
    if k == TOK_KW_FN() or k == TOK_DIR_FN() or k == TOK_KW_COMPONENT()
        is_fn = 1
    end

    if is_fn == 1
        return x86_synth_compile_fn_def(s, toks, pos_box)

    // Default: evaluate expression or advance token with strict forward progress & zero silent assignment drop
    before_expr_p = get(pos_box, 0)
    x86_synth_compile_expr(s, toks, pos_box)
    after_expr_p = get(pos_box, 0)
    if after_expr_p < toks.len() and toks[after_expr_p].tok_span.span_start_line == t.tok_span.span_start_line
        ak_chk = toks[after_expr_p].tok_kind
        at_chk = toks[after_expr_p].tok_text
        if ak_chk == TOK_ASSIGN() or ak_chk == TOK_PLUSEQ() or ak_chk == TOK_MINUSEQ() or ak_chk == TOK_STAREQ() or ak_chk == TOK_SLASHEQ() or ak_chk == TOK_PERCENTEQ() or (ak_chk != TOK_STR() and (at_chk == "=" or at_chk == "+=" or at_chk == "-=" or at_chk == "*=" or at_chk == "/=" or at_chk == "%="))
            say "❌ [Syntax Error]: Invalid or unsupported assignment target before '" + at_chk + "' at line " + str(t.tok_span.span_start_line)
            exit(1)
        end
    end
    if after_expr_p <= before_expr_p
        list_set(pos_box, 0, before_expr_p + 1)
    return 0
