// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/x86_64/synthesizer.lp
// ==============================================================================

include "src/compiler/backend/targets/x86_64/codegen_core.lp"
include "src/compiler/backend/targets/x86_64/prescan.lp"
include "src/compiler/backend/targets/x86_64/codegen_postfix.lp"
include "src/compiler/backend/targets/x86_64/codegen_expr.lp"
include "src/compiler/backend/targets/x86_64/codegen_operators.lp"
include "src/compiler/backend/targets/x86_64/codegen_loops.lp"
include "src/compiler/backend/targets/x86_64/codegen_stmt.lp"
include "src/compiler/backend/targets/x86_64/silicon_encoder.lp"

// ── Function Definition Synthesizer ───────────────────────────────────────────

fn x86_synth_compile_fn_def s toks pos_box
    // WHY: Dedicated function definition synthesizer for System V AMD64 ABI.
    // Handles parameter parsing, ABI register conventions (%rdi, %rsi, etc.),
    // local stack frame allocation, and statement body synthesis.
    pos = get(pos_box, 0)
    t = toks[pos]
    base_col = t.tok_span.span_start_col
    if s.synth_pending_fn_base_col > 0
        base_col = s.synth_pending_fn_base_col
        s.synth_pending_fn_base_col = 0
    end
    base_line = t.tok_span.span_start_line
    list_set(pos_box, 0, pos + 1) // Consume fn
    name_pos = get(pos_box, 0)
    fn_name = ""
    method_alias = ""
    target_sname = ""
    if name_pos < toks.len() and toks[name_pos].tok_kind == TOK_IDENT()
        fn_name = toks[name_pos].tok_text
        target_sname = fn_name
        list_set(pos_box, 0, name_pos + 1)
        next_p = get(pos_box, 0)
        if next_p + 1 < toks.len() and (toks[next_p].tok_kind == TOK_DOT() or (toks[next_p].tok_kind != TOK_STR() and toks[next_p].tok_text == "."))
            if toks[next_p + 1].tok_kind == TOK_IDENT()
                method_alias = toks[next_p + 1].tok_text
                list_set(pos_box, 0, next_p + 2)
                fn_name = fn_name + "_" + method_alias
            end
        elif s.synth_impl_type_ctx != "" and fn_name != ""
            // WHY: Inside `impl [Trait for] Type { fn m(self, ...) }`, automatically mangle
            // method name to `Type_m` and type `self` as `Type`!
            method_alias = fn_name
            target_sname = s.synth_impl_type_ctx
            fn_name = target_sname + "_" + method_alias
        end
    end
    // Parse optional generic type parameters: fn name<T: Printable, U>(...)
    fn_tparams_raw = x86_synth_parse_type_list(toks, pos_box, 0)
    tp_split_fn = x86_synth_split_tparam_bounds(fn_tparams_raw)
    fn_tparams = tp_split_fn[0]
    fn_tbounds = tp_split_fn[1]
    saved_in_function = s.synth_in_function
    saved_current_fn = s.synth_current_fn
    mono_name = s.synth_mono_name_override
    mono_params = s.synth_mono_param_override
    mono_ret = s.synth_mono_ret_override
    s.synth_mono_name_override = ""
    s.synth_mono_param_override = 0
    s.synth_mono_ret_override = ""
    if mono_name != ""
        fn_name = mono_name
        method_alias = ""
    end
    s.synth_in_function = 1
    s.synth_current_fn = fn_name

    // Emit jump over function so top-level execution doesn't fall through into it!
    x86_synth_emit_byte(s, 233) // jmp rel32 (0xE9)
    fn_jmp_patch = s.synth_code.len()
    x86_synth_emit_u32(s, 0)

    // Record function entry point (reusing pre-scanned stub or mono stub when available)
    fn_entry_idx = 0 - 1
    if mono_name != ""
        fi_m = s.synth_functions.len() - 1
        while fi_m >= 0
            if s.synth_functions[fi_m].fn_name == fn_name
                fn_entry_idx = fi_m
                break
            end
            fi_m = fi_m - 1
        end
    else
        fn_entry_idx = x86_synth_find_prescan_stub(s, fn_name, base_line)
    end
    fn_entry = 0
    if fn_entry_idx >= 0
        fn_entry = s.synth_functions[fn_entry_idx]
        fn_entry.fn_entry_offset = s.synth_code.len()
        fn_entry.fn_end_offset = 0
    else
        fn_entry = X86Function()
        fn_entry.fn_name = fn_name
        fn_entry.fn_entry_offset = s.synth_code.len()
        fn_entry.fn_ret_type = ""
        fn_entry.fn_end_offset = 0
        fn_entry.fn_decl_line = base_line
        fn_entry.fn_param_count = 0 - 1
        fn_entry.fn_tok_pos = 0 - 1
        fn_entry.fn_param_types = list()
        fn_entry_idx = x86_synth_register_fn_obj(s, fn_entry)
    end
    fn_alias = 0
    if method_alias != ""
        alias_idx = x86_synth_find_prescan_stub(s, method_alias, base_line)
        if alias_idx >= 0
            fn_alias = s.synth_functions[alias_idx]
            fn_alias.fn_entry_offset = s.synth_code.len()
            fn_alias.fn_end_offset = 0
        else
            fn_alias = X86Function()
            fn_alias.fn_name = method_alias
            fn_alias.fn_entry_offset = s.synth_code.len()
            fn_alias.fn_ret_type = ""
            fn_alias.fn_end_offset = 0
            fn_alias.fn_decl_line = base_line
            fn_alias.fn_param_count = 0 - 1
            fn_alias.fn_tok_pos = 0 - 1
            fn_alias.fn_param_types = list()
            x86_synth_register_fn_obj(s, fn_alias)
        end
    end

    // Reset frame locals (saving enclosing scope to restore when function definition completes)
    saved_locals = s.synth_locals
    saved_stack_offset = s.synth_stack_offset
    saved_fn_idx = s.synth_current_fn_idx
    saved_try_depth = s.synth_try_depth
    saved_try_frames = s.synth_try_frames
    saved_defer_starts = s.synth_defer_starts
    saved_defer_ends = s.synth_defer_ends
    saved_has_defer_unwind = s.synth_has_defer_unwind
    saved_defer_mask_off = s.synth_defer_mask_off
    saved_defer_err_off = s.synth_defer_err_off
    saved_in_defer_unwind_pad = s.synth_in_defer_unwind_pad
    saved_loop_starts = s.synth_loop_starts
    saved_loop_breaks = s.synth_loop_breaks
    saved_loop_continues = s.synth_loop_continues
    s.synth_locals = list()
    s.synth_stack_offset = 64
    s.synth_current_fn_idx = fn_entry_idx
    s.synth_try_depth = 0
    s.synth_try_frames = list()
    s.synth_defer_starts = list()
    s.synth_defer_ends = list()
    s.synth_has_defer_unwind = 0
    s.synth_defer_mask_off = 0
    s.synth_defer_err_off = 0
    s.synth_in_defer_unwind_pad = 0
    s.synth_loop_starts = list()
    s.synth_loop_breaks = list()
    s.synth_loop_continues = list()
    saved_boxed_vars = s.synth_boxed_vars
    s.synth_boxed_vars = list()
    saved_fn_tag_offs = s.synth_fn_tag_offs
    s.synth_fn_tag_offs = list()
    saved_fn_dyn_vars = s.synth_fn_dyn_vars
    s.synth_fn_dyn_vars = list()

    // Parse parameter names (supporting parentheses, commas, and type annotations)
    params = list()
    param_types = list()
    has_paren = 0
    if get(pos_box, 0) < toks.len()
        first_p_tok = toks[get(pos_box, 0)]
        if first_p_tok.tok_kind == TOK_LPAREN() or (first_p_tok.tok_kind != TOK_STR() and first_p_tok.tok_text == "(")
            has_paren = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume '('

    while get(pos_box, 0) < toks.len()
        if has_paren == 1
            x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p_idx = get(pos_box, 0)
        if cur_p_idx >= toks.len()
            break
        p_tok = toks[cur_p_idx]
        pk = p_tok.tok_kind
        ptxt = p_tok.tok_text

        if has_paren == 1
            if pk == TOK_RPAREN() or (pk != TOK_STR() and ptxt == ")")
                list_set(pos_box, 0, cur_p_idx + 1) // Consume ')'
                break
        else
            if pk == TOK_ASSIGN() or (pk != TOK_STR() and ptxt == "=")
                break
            if pk == TOK_ARROW() or (pk != TOK_STR() and ptxt == "->")
                break
            if pk == TOK_LBRACE() or (pk != TOK_STR() and ptxt == "{")
                break
            if pk == TOK_NEWLINE() or pk == TOK_SEMI() or (pk != TOK_STR() and (ptxt == "\n" or ptxt == ";"))
                list_set(pos_box, 0, cur_p_idx + 1)
                break

        if x86_synth_is_ident_token(pk) == 1
            push(params, ptxt)
            param_type = ""
            list_set(pos_box, 0, cur_p_idx + 1) // Consume param name
            if has_paren == 1
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                // Skip optional type annotation: : type[<...>]
            after_p = get(pos_box, 0)
            if after_p < toks.len() and (toks[after_p].tok_kind == TOK_COLON() or (toks[after_p].tok_kind != TOK_STR() and toks[after_p].tok_text == ":"))
                list_set(pos_box, 0, after_p + 1) // Consume ':'
                if has_paren == 1
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                end
                param_type = x86_synth_parse_type_expr(toks, pos_box)
            end
            push(param_types, param_type)
            if has_paren == 1
                x86_synth_skip_whitespace_tokens(toks, pos_box)
            // Skip optional comma: ,
            comma_p = get(pos_box, 0)
            if comma_p < toks.len() and (toks[comma_p].tok_kind == TOK_COMMA() or (toks[comma_p].tok_kind != TOK_STR() and toks[comma_p].tok_text == ","))
                list_set(pos_box, 0, comma_p + 1) // Consume ','
        else
            list_set(pos_box, 0, cur_p_idx + 1)

    // Parse optional return type: -> return_type[<...>] or : return_type[<...>]
    x86_synth_skip_whitespace_tokens(toks, pos_box)
    ret_p = get(pos_box, 0)
    if ret_p < toks.len() and (toks[ret_p].tok_kind == TOK_ARROW() or (toks[ret_p].tok_kind != TOK_STR() and toks[ret_p].tok_text == "->") or toks[ret_p].tok_kind == TOK_COLON() or (toks[ret_p].tok_kind != TOK_STR() and toks[ret_p].tok_text == ":"))
        list_set(pos_box, 0, ret_p + 1) // Consume '->' or ':'
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        parsed_ret_t = x86_synth_parse_type_expr(toks, pos_box)
        if parsed_ret_t != ""
            fn_entry.fn_ret_type = x86_synth_subst_type(s, parsed_ret_t, 0, 0)
            fn_entry.fn_ret_explicit = 1
            if fn_alias != 0
                fn_alias.fn_ret_type = fn_entry.fn_ret_type
                fn_alias.fn_ret_explicit = 1
            end
        end
    end

    fn_entry.fn_param_count = params.len()
    fn_entry.fn_type_params = fn_tparams
    fn_entry.fn_type_bounds = fn_tbounds
    if s.synth_pending_section != ""
        fn_entry.fn_section = s.synth_pending_section
        s.synth_pending_section = ""
    end
    if fn_alias != 0
        fn_alias.fn_param_count = params.len()
        fn_alias.fn_type_params = fn_tparams
        fn_alias.fn_type_bounds = fn_tbounds
    end

    if method_alias != "" and params.len() > 0
        if param_types[0] == ""
            list_set(param_types, 0, target_sname)
        end
    end
    if mono_params != 0
        mpi = 0
        while mpi < param_types.len() and mpi < mono_params.len()
            if mono_params[mpi] != ""
                list_set(param_types, mpi, mono_params[mpi])
            end
            mpi = mpi + 1
        end
    else
        // Resolve concrete generic struct annotations like `b: Box<float>` in non-generic functions
        mpi2 = 0
        while mpi2 < param_types.len()
            if param_types[mpi2] != ""
                list_set(param_types, mpi2, x86_synth_subst_type(s, param_types[mpi2], 0, 0))
            end
            mpi2 = mpi2 + 1
        end
    end
    if mono_ret != ""
        fn_entry.fn_ret_type = mono_ret
    end

    // ── Direct SSA CFG Replacement (--ssa-codegen): Bypass Token Re-Parser for Eligible Functions (i64, f64, str, structs, inter-fn calls) ──
    if g_x86_ssa_codegen == 1 and s.synth_freestanding == 0 and s.synth_ssa_lower_res != 0 and s.synth_ssa_lower_res.slr_success == 1 and fn_tparams.len() == 0 and method_alias == "" and mono_name == "" and s.synth_pending_fn_naked == 0 and s.synth_pending_fn_interrupt == 0
        if 1 == 1
            slr = s.synth_ssa_lower_res
            ssa_match_i = 0 - 1
            if slr.slr_fn_eligible != 0
                if slr.slr_fn_name_map != 0
                    if has_key(slr.slr_fn_name_map, fn_name) == 1
                        cand_i = slr.slr_fn_name_map[fn_name] - 1
                        if cand_i >= 0 and cand_i < slr.slr_fn_eligible.len() and slr.slr_fn_eligible[cand_i] == 1
                            ssa_match_i = cand_i
                        end
                    end
                else
                    sfi = 0
                    while sfi < slr.slr_fn_names.len() and sfi < slr.slr_fn_eligible.len()
                        if slr.slr_fn_names[sfi] == fn_name and slr.slr_fn_eligible[sfi] == 1
                            ssa_match_i = sfi
                            break
                        end
                        sfi = sfi + 1
                    end
                end
            end
            if ssa_match_i >= 0 and s.synth_pending_fn_async == 0 and ssa_match_i < slr.slr_fn_offsets.len() and ssa_match_i < slr.slr_fn_sizes.len()
                ssa_off = slr.slr_fn_offsets[ssa_match_i]
                ssa_sz = slr.slr_fn_sizes[ssa_match_i]
                slr_code_len = 0
                if slr.slr_code_buf != 0
                    slr_code_len = buf_len(slr.slr_code_buf)
                elif slr.slr_code != 0
                    slr_code_len = slr.slr_code.len()
                end
                if ssa_sz > 0 and (ssa_off + ssa_sz) <= slr_code_len
                    // Merge slr_rodata into synth_rodata once via hardware ERMS rep movsb so STR0 relocs stay exact
                    if s.synth_ssa_rodata_base < 0
                        if slr.slr_rodata_buf != 0 and buf_len(slr.slr_rodata_buf) > 0
                            s.synth_ssa_rodata_base = buf_len(s.synth_rodata)
                            buf_write_mem(s.synth_rodata, buf_ptr(slr.slr_rodata_buf), buf_len(slr.slr_rodata_buf))
                        elif slr.slr_rodata != 0 and slr.slr_rodata.len() > 0
                            s.synth_ssa_rodata_base = buf_len(s.synth_rodata)
                            sri = 0
                            while sri < slr.slr_rodata.len()
                                buf_write_byte(s.synth_rodata, slr.slr_rodata[sri])
                                sri = sri + 1
                            end
                        end
                    end
                    dst_ssa_base = buf_len(s.synth_code)
                    // Emit SSA-lowered native x86-64 machine code directly via ERMS (ZERO token re-parsing!)
                    if slr.slr_code_buf != 0
                        buf_write_mem(s.synth_code, buf_ptr(slr.slr_code_buf) + ssa_off, ssa_sz)
                    else
                        sbi = 0
                        while sbi < ssa_sz
                            buf_write_byte(s.synth_code, slr.slr_code[ssa_off + sbi])
                            sbi = sbi + 1
                        end
                    end
                    // Translate STR0 string relocations falling inside this function slice (O(k) indexed when available)
                    if slr.slr_str_relocs != 0 and s.synth_ssa_rodata_base >= 0
                        sri2 = 0
                        sri2_end = slr.slr_str_relocs.len()
                        if slr.slr_fn_str_start != 0 and ssa_match_i < slr.slr_fn_str_start.len() and slr.slr_fn_str_end != 0 and ssa_match_i < slr.slr_fn_str_end.len()
                            sri2 = slr.slr_fn_str_start[ssa_match_i]
                            sri2_end = slr.slr_fn_str_end[ssa_match_i]
                        end
                        while sri2 < sri2_end
                            sr_item = slr.slr_str_relocs[sri2]
                            sr_c = sr_item[0]
                            if sr_c >= ssa_off and sr_c < (ssa_off + ssa_sz)
                                xrel = X86StringReloc()
                                xrel.sr_patch_offset = dst_ssa_base + (sr_c - ssa_off)
                                xrel.sr_rodata_offset = s.synth_ssa_rodata_base + sr_item[1]
                                push(s.synth_str_relocs, xrel)
                            end
                            sri2 = sri2 + 1
                        end
                    end
                    // Translate OP_CALL / _lipi_user_alloc / _lipi_throw_null_deref relocations inside this slice (O(k) indexed!)
                    if slr.slr_call_relocs != 0
                        cri = 0
                        cri_end = slr.slr_call_relocs.len()
                        if slr.slr_fn_call_start != 0 and ssa_match_i < slr.slr_fn_call_start.len() and slr.slr_fn_call_end != 0 and ssa_match_i < slr.slr_fn_call_end.len()
                            cri = slr.slr_fn_call_start[ssa_match_i]
                            cri_end = slr.slr_fn_call_end[ssa_match_i]
                        end
                        while cri < cri_end
                            jp_c = slr.slr_call_relocs[cri]
                            if jp_c.sjp_offset >= ssa_off and jp_c.sjp_offset < (ssa_off + ssa_sz)
                                crel = X86CallReloc()
                                crel.cr_patch_offset = dst_ssa_base + (jp_c.sjp_offset - ssa_off)
                                crel.cr_call_site_end = crel.cr_patch_offset + 4
                                crel.cr_target_name = jp_c.sjp_target
                                push(s.synth_call_relocs, crel)
                                if jp_c.sjp_target == "_lipi_user_alloc"
                                    s.synth_needs_alloc = 1
                                end
                            end
                            cri = cri + 1
                        end
                    end
                    // Propagate SSA-inferred return type (float/str/struct) onto fn_entry for callers
                    if fn_entry.fn_ret_type == "" and slr.slr_fn_ret_types != 0 and ssa_match_i < slr.slr_fn_ret_types.len()
                        ssa_rt = slr.slr_fn_ret_types[ssa_match_i]
                        if ssa_rt != "" and ssa_rt != "int"
                            fn_entry.fn_ret_type = ssa_rt
                        end
                    end
                    after_ssa_off = s.synth_code.len()
                    fn_entry.fn_end_offset = after_ssa_off
                    x86_synth_patch_u32(s, fn_jmp_patch, after_ssa_off - (fn_jmp_patch + 4))
                    s.synth_ssa_replaced_cnt = s.synth_ssa_replaced_cnt + 1
                    s.synth_ssa_replaced_bytes = s.synth_ssa_replaced_bytes + ssa_sz
                    // Advance token cursor past the unparsed function body cleanly
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_ASSIGN() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "="))
                        eq_ln = toks[get(pos_box, 0)].tok_span.span_start_line
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_NEWLINE() and toks[get(pos_box, 0)].tok_kind != TOK_SEMI() and toks[get(pos_box, 0)].tok_kind != TOK_EOF() and toks[get(pos_box, 0)].tok_span.span_start_line == eq_ln
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    elif get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                        sk_d = 1
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                        while get(pos_box, 0) < toks.len() and sk_d > 0
                            sk_t = toks[get(pos_box, 0)]
                            if sk_t.tok_kind == TOK_LBRACE() or (sk_t.tok_kind != TOK_STR() and sk_t.tok_text == "{")
                                sk_d = sk_d + 1
                            elif sk_t.tok_kind == TOK_RBRACE() or (sk_t.tok_kind != TOK_STR() and sk_t.tok_text == "}")
                                sk_d = sk_d - 1
                            end
                            list_set(pos_box, 0, get(pos_box, 0) + 1)
                        end
                    else
                        while get(pos_box, 0) < toks.len()
                            x86_synth_skip_whitespace_tokens(toks, pos_box)
                            sp_c = get(pos_box, 0)
                            if sp_c >= toks.len() break end
                            st_c = toks[sp_c]
                            if (st_c.tok_kind == TOK_KW_END() or st_c.tok_kind == TOK_DIR_END() or (st_c.tok_kind == TOK_IDENT() and (st_c.tok_text == "end" or st_c.tok_text == "শেষ" or st_c.tok_text == "@end"))) and st_c.tok_span.span_start_col <= base_col
                                if sp_c + 1 >= toks.len() or (toks[sp_c + 1].tok_kind != TOK_ASSIGN() and toks[sp_c + 1].tok_text != "=")
                                    list_set(pos_box, 0, sp_c + 1)
                                    break
                                end
                            end
                            if st_c.tok_span.span_start_col <= base_col and st_c.tok_span.span_start_line > base_line
                                break
                            end
                            list_set(pos_box, 0, sp_c + 1)
                        end
                    end
                    s.synth_locals = saved_locals
                    s.synth_stack_offset = saved_stack_offset
                    s.synth_current_fn_idx = saved_fn_idx
                    s.synth_try_depth = saved_try_depth
                    s.synth_try_frames = saved_try_frames
                    s.synth_defer_starts = saved_defer_starts
                    s.synth_defer_ends = saved_defer_ends
                    s.synth_has_defer_unwind = saved_has_defer_unwind
                    s.synth_defer_mask_off = saved_defer_mask_off
                    s.synth_defer_err_off = saved_defer_err_off
                    s.synth_in_defer_unwind_pad = saved_in_defer_unwind_pad
                    s.synth_loop_starts = saved_loop_starts
                    s.synth_loop_breaks = saved_loop_breaks
                    s.synth_loop_continues = saved_loop_continues
                    s.synth_boxed_vars = saved_boxed_vars
                    s.synth_fn_tag_offs = saved_fn_tag_offs
                    s.synth_fn_dyn_vars = saved_fn_dyn_vars
                    s.synth_in_function = saved_in_function
                    s.synth_current_fn = saved_current_fn
                    return 0
                end
            end
        end
    end

    // Emit standard function prologue, @interrupt 15-GPR ISR prologue, or omit for @naked
    is_fn_naked = s.synth_pending_fn_naked
    is_fn_interrupt = s.synth_pending_fn_interrupt
    is_fn_async = s.synth_pending_fn_async
    s.synth_pending_fn_naked = 0
    s.synth_pending_fn_interrupt = 0
    s.synth_pending_fn_async = 0
    if is_fn_async == 1
        fn_entry.fn_is_async = 1
    end
    saved_in_interrupt = s.synth_in_interrupt_fn
    saved_in_naked = s.synth_in_naked_fn
    s.synth_in_interrupt_fn = is_fn_interrupt
    s.synth_in_naked_fn = is_fn_naked
    prologue_sub_patch = 0 - 1
    tag_init_patch = 0 - 1
    if is_fn_naked == 1
        prologue_sub_patch = 0 - 1
    elif is_fn_interrupt == 1
        prologue_sub_patch = x86_synth_emit_interrupt_prologue(s)
        if s.synth_freestanding == 0
            tag_init_patch = s.synth_code.len()
            x86_synth_emit_bytes(s, [15, 31, 68, 0, 0]) // 5B NOP placeholder for dyn_tagged slot zeroing call
        end
    else
        prologue_sub_patch = x86_synth_emit_prologue(s)
        if s.synth_freestanding == 0
            tag_init_patch = s.synth_code.len()
            x86_synth_emit_bytes(s, [15, 31, 68, 0, 0]) // 5B NOP placeholder for dyn_tagged slot zeroing call
        end
    end

    // Prescan function body for outer variables mutated inside nested closures (auto-boxed upvalue cells)
    s.synth_boxed_vars = x86_synth_prescan_boxed_vars(toks, get(pos_box, 0), base_col, base_line)
    if s.synth_freestanding == 0 and is_fn_naked == 0
        s.synth_fn_dyn_vars = x86_synth_prescan_dyn_vars(toks, get(pos_box, 0), base_col, base_line, params)
    end

    // Prescan function body for defer statements: if present, push exception unwind frame so defer
    // executes in strict LIFO order during cross-frame throw unwinding as well as normal return!
    defer_pad_lea_patch = 0 - 1
    if x86_synth_body_has_defer(toks, get(pos_box, 0), base_col, base_line) == 1
        s.synth_has_defer_unwind = 1
        s.synth_stack_offset = ((s.synth_stack_offset + 15) / 16) * 16 + 96
        defer_exc_off = s.synth_stack_offset
        s.synth_defer_mask_off = defer_exc_off - 72
        s.synth_defer_err_off = defer_exc_off - 80
        // WHY: x86_synth_alloc_var allocates at [rbp - synth_stack_offset]; advance past defer_exc_off
        // so param 0 never aliases [rbp - defer_exc_off] where _lipi_exc_push writes the frame!
        s.synth_stack_offset = defer_exc_off + 8
    end

    // WHY: Two-pass parameter initialization prevents clobbering incoming argument registers.
    // In Pass 1, save ALL incoming arguments (0..5 in SysV regs, 6+ from caller stack [rbp+16+...])
    // to local stack slots [rbp - off] before modifying any hardware registers.
    pi = 0
    while pi < params.len()
        pname = params[pi]
        off = x86_synth_alloc_var(s, pname)
        ptype = param_types[pi]
        if ptype != ""
            x86_synth_set_var_type(s, pname, ptype)
            if ptype == "float" or ptype == "f64" or ptype == "f32"
                x86_synth_set_prim_type(s, pname, "float")
            elif x86_synth_is_uint_type(ptype) == 1 or x86_synth_is_ptr_type(ptype) == 1
                x86_synth_set_prim_type(s, pname, "uint")
            elif ptype == "int" or ptype == "i64" or ptype == "i32" or ptype == "i16" or ptype == "i8"
                x86_synth_set_prim_type(s, pname, "int")
            elif ptype == "str" or ptype == "string"
                x86_synth_set_prim_type(s, pname, "str")
            end
        end
        x86_synth_emit_store_param(s, pi, off)
        if x86_synth_is_narrow_int_type(ptype) == 1
            x86_synth_emit_load_var(s, 0, off)
            x86_synth_emit_truncate_int_width(s, ptype)
            x86_synth_emit_store_var(s, 0, off)
        end
        if s.synth_freestanding == 0 and x86_synth_is_dyn_var(s, pname) == 1
            lv_pdyn = x86_synth_find_local_var(s, pname)
            if lv_pdyn != 0
                if lv_pdyn.lv_tag_off == 0
                    lv_pdyn.lv_tag_off = s.synth_stack_offset
                    s.synth_stack_offset = s.synth_stack_offset + 8
                    push(s.synth_fn_tag_offs, lv_pdyn.lv_tag_off)
                end
                p_init_tag = 0
                if ptype == "float" or ptype == "f64" or ptype == "f32"
                    p_init_tag = 1
                elif ptype == "str" or ptype == "string"
                    p_init_tag = 2
                end
                x86_synth_emit_store_imm64_to_var(s, lv_pdyn.lv_tag_off, p_init_tag)
                x86_synth_set_prim_type(s, pname, "dyn_tagged")
            end
        end
        pi = pi + 1
    end

    // Pass 1b: Wrap any closure-mutated parameters in 8-byte GC upvalue cells (after all reg params are saved!)
    pi = 0
    while pi < params.len()
        pname = params[pi]
        lv_bp = x86_synth_find_local_var(s, pname)
        if lv_bp != 0 and lv_bp.lv_is_boxed == 1
            x86_synth_emit_mov_rdi_imm64(s, 8)
            x86_synth_emit_call_alloc(s)
            x86_synth_emit_load_var(s, 1, lv_bp.lv_offset) // mov rcx, [rbp - off] (raw param val)
            x86_synth_emit_bytes(s, [72, 137, 8])          // mov [rax], rcx
            x86_synth_emit_store_var(s, 0, lv_bp.lv_offset) // store cell ptr in slot
            s.synth_last_store_end = 0 - 1
        end
        pi = pi + 1
    end

    // In Pass 2, now that all incoming argument registers are preserved on the stack frame,
    // load variables assigned to hardware registers by linear scan regalloc into their target registers.
    pi = 0
    while pi < params.len()
        pname = params[pi]
        off = x86_synth_lookup_var(s, pname)
        lv_param = x86_synth_find_local_var(s, pname)
        if lv_param != 0 and lv_param.lv_is_spilled == 0 and lv_param.lv_reg >= 0
            x86_synth_emit_load_var(s, 0, off)
            x86_synth_emit_mov_reg_reg(s, lv_param.lv_reg, 0)
        end
        pi = pi + 1
    end

    // Pass 3: Install defer unwind frame AFTER all incoming parameter registers are saved!
    if s.synth_has_defer_unwind == 1
        x86_synth_emit_bytes(s, [49, 192]) // xor eax, eax
        x86_synth_emit_store_var(s, 0, s.synth_defer_mask_off)
        // lea rdi, [rbp - defer_exc_off]; lea rsi, [rip + pad_disp]; mov rdx, rbp; mov rcx, rsp; call _lipi_exc_push
        x86_synth_emit_bytes(s, [72, 141, 189])
        x86_synth_emit_u32(s, 0 - defer_exc_off)
        x86_synth_emit_bytes(s, [72, 141, 53])
        defer_pad_lea_patch = s.synth_code.len()
        x86_synth_emit_u32(s, 0)
        x86_synth_emit_bytes(s, [72, 137, 234, 72, 137, 225])
        x86_synth_emit_call_helper(s, "_lipi_exc_push")
        s.synth_last_store_end = 0 - 1
    end

    // Check for one-liner expression function: fn name args = expr
    x86_synth_skip_whitespace_tokens(toks, pos_box)
    if get(pos_box, 0) < toks.len()
        eq_tok = toks[get(pos_box, 0)]
        if eq_tok.tok_kind == TOK_ASSIGN() or (eq_tok.tok_kind != TOK_STR() and eq_tok.tok_text == "=")
            list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume '='
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            x86_synth_compile_expr(s, toks, pos_box)
            if fn_entry.fn_ret_type == "" and s.synth_last_struct != ""
                fn_entry.fn_ret_type = s.synth_last_struct
                if fn_alias != 0
                    fn_alias.fn_ret_type = s.synth_last_struct
                end
            elif fn_entry.fn_ret_type == "" and s.synth_last_expr_type == "float"
                fn_entry.fn_ret_type = "f64"
                if fn_alias != 0
                    fn_alias.fn_ret_type = "f64"
                end
            elif fn_entry.fn_ret_type == "" and s.synth_last_expr_type == "dyn_tagged"
                fn_entry.fn_ret_type = "dyn_tagged"
                if fn_alias != 0
                    fn_alias.fn_ret_type = "dyn_tagged"
                end
            end
            x86_synth_emit_defers(s, toks)
            x86_synth_emit_epilogue(s)
            x86_synth_emit_tag_init_stub_if_needed(s, tag_init_patch)
            after_fn_offset = s.synth_code.len()
            fn_entry.fn_end_offset = after_fn_offset
            if fn_alias != 0
                fn_alias.fn_end_offset = after_fn_offset
            end
            rel32 = after_fn_offset - (fn_jmp_patch + 4)
            x86_synth_patch_u32(s, fn_jmp_patch, rel32)
            needed_stack = s.synth_stack_offset
            frame_sz = ((needed_stack + 256 + 15) / 16) * 16
            if frame_sz < 512
                frame_sz = 512
            end
            if prologue_sub_patch >= 0
                x86_synth_patch_u32(s, prologue_sub_patch, frame_sz)
            end
            s.synth_locals = saved_locals
            s.synth_stack_offset = saved_stack_offset
            s.synth_current_fn_idx = saved_fn_idx
            s.synth_try_depth = saved_try_depth
            s.synth_try_frames = saved_try_frames
            s.synth_defer_starts = saved_defer_starts
            s.synth_defer_ends = saved_defer_ends
            s.synth_has_defer_unwind = saved_has_defer_unwind
            s.synth_defer_mask_off = saved_defer_mask_off
            s.synth_defer_err_off = saved_defer_err_off
            s.synth_in_defer_unwind_pad = saved_in_defer_unwind_pad
            s.synth_loop_starts = saved_loop_starts
            s.synth_loop_breaks = saved_loop_breaks
            s.synth_loop_continues = saved_loop_continues
            s.synth_boxed_vars = saved_boxed_vars
            s.synth_fn_tag_offs = saved_fn_tag_offs
            s.synth_fn_dyn_vars = saved_fn_dyn_vars
            s.synth_in_function = saved_in_function
            s.synth_current_fn = saved_current_fn
            s.synth_in_interrupt_fn = saved_in_interrupt
            s.synth_in_naked_fn = saved_in_naked
            return 0

    // Parse function body statements: supports BOTH braced `{ ... }` and indentation/`end`-delimited blocks!
    fn_braced = 0
    x86_synth_skip_whitespace_tokens(toks, pos_box)
    if get(pos_box, 0) < toks.len()
        bt0 = toks[get(pos_box, 0)]
        if bt0.tok_kind == TOK_LBRACE() or (bt0.tok_kind != TOK_STR() and bt0.tok_text == "{")
            fn_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume '{'
        end
    end
    while get(pos_box, 0) < toks.len()
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos >= toks.len()
            break
        ct = toks[cur_pos]
        if fn_braced == 1
            if ct.tok_kind == TOK_RBRACE() or (ct.tok_kind != TOK_STR() and ct.tok_text == "}")
                list_set(pos_box, 0, cur_pos + 1) // Consume '}'
                break
            end
        else
            is_fn_block_end = 0
            if (ct.tok_kind == TOK_KW_END() or ct.tok_kind == TOK_DIR_END() or (ct.tok_kind == TOK_IDENT() and (ct.tok_text == "end" or ct.tok_text == "শেষ" or ct.tok_text == "@end"))) and ct.tok_span.span_start_col <= base_col
                // WHY: Only treat as block terminator if NOT followed by an assignment '='
                if cur_pos + 1 >= toks.len() or (toks[cur_pos + 1].tok_kind != TOK_ASSIGN() and toks[cur_pos + 1].tok_text != "=")
                    is_fn_block_end = 1
            if is_fn_block_end == 1
                list_set(pos_box, 0, cur_pos + 1)
                break
            if ct.tok_kind == TOK_KW_FN() or ct.tok_kind == TOK_DIR_FN() or ct.tok_kind == TOK_KW_COMPONENT()
                break
            if ct.tok_kind == TOK_KW_ASYNC() and cur_pos + 1 < toks.len() and (toks[cur_pos + 1].tok_kind == TOK_KW_FN() or toks[cur_pos + 1].tok_kind == TOK_DIR_FN())
                break
            if ct.tok_kind == TOK_IDENT() and (ct.tok_text == "@naked" or ct.tok_text == "@interrupt" or ct.tok_text == "@packed" or ct.tok_text == "@align" or ct.tok_text == "@bss")
                break
            if ct.tok_kind == TOK_KW_STRUCT() or ct.tok_kind == TOK_DIR_STRUCT() or ct.tok_kind == TOK_KW_ENUM() or ct.tok_kind == TOK_DIR_ENUM() or ct.tok_kind == TOK_KW_IMPL()
                break
            if ct.tok_kind == TOK_DIR_TRAIT() and cur_pos + 1 < toks.len() and x86_synth_is_ident_token(toks[cur_pos + 1].tok_kind) == 1 and toks[cur_pos + 1].tok_span.span_start_line == ct.tok_span.span_start_line
                break
            if ct.tok_kind == TOK_IDENT() and (ct.tok_text == "union" or ct.tok_text == "@union" or ct.tok_text == "ইউনিয়ন")
                break
            cur_col = ct.tok_span.span_start_col
            if cur_col <= base_col and ct.tok_span.span_start_line > base_line
                break
        end
        before_fn_stmt_p = get(pos_box, 0)
        x86_synth_compile_statement(s, toks, pos_box)
        if get(pos_box, 0) <= before_fn_stmt_p
            list_set(pos_box, 0, before_fn_stmt_p + 1)

    // Default epilogue at end of function (omitted for @naked; emits iretq for @interrupt)
    if is_fn_naked == 0
        if is_fn_interrupt == 0
            x86_synth_emit_byte(s, 49)
            x86_synth_emit_byte(s, 192)
        end
        x86_synth_emit_defers(s, toks)
        x86_synth_emit_epilogue(s)
    end

    // Emit Defer Unwind Pad (landed on by _lipi_exc_throw when an exception propagates out of this function)
    if s.synth_has_defer_unwind == 1 and defer_pad_lea_patch >= 0
        defer_pad_off = s.synth_code.len()
        x86_synth_patch_u32(s, defer_pad_lea_patch, defer_pad_off - (defer_pad_lea_patch + 4))
        s.synth_last_store_end = 0 - 1
        x86_synth_emit_store_var(s, 0, s.synth_defer_err_off) // save thrown exception value in %rax
        s.synth_in_defer_unwind_pad = 1
        x86_synth_emit_defers(s, toks)
        s.synth_in_defer_unwind_pad = 0
        x86_synth_emit_load_var(s, 7, s.synth_defer_err_off)  // mov rdi, [rbp - defer_err_off]
        x86_synth_emit_call_helper(s, "_lipi_exc_throw")
    end

    // Emit zero-overhead dyn_tagged prologue tag-zeroing stub if this function allocated any lv_tag_off
    x86_synth_emit_tag_init_stub_if_needed(s, tag_init_patch)

    // WHY: For `async fn`, emit a 47-byte Static-PIE fiber-spawning wrapper right after the body
    // and point `fn_entry.fn_entry_offset` at the wrapper so calling `foo(args)` allocates a
    // GC-traced FUTR + 64KB non-executable RW fiber stack and queues the body on the event loop!
    if is_fn_async == 1 and s.synth_freestanding == 0
        body_off_as = fn_entry.fn_entry_offset
        wrapper_off_as = s.synth_code.len()
        // push rbp; mov rbp, rsp; sub rsp, 48
        // mov [rsp+0], rdi; mov [rsp+8], rsi; mov [rsp+16], rdx
        // mov [rsp+24], rcx; mov [rsp+32], r8; mov [rsp+40], r9
        // lea rdi, [rip + disp32]
        x86_synth_emit_bytes(s, [
            85, 72, 137, 229, 72, 131, 236, 48,
            72, 137, 60, 36,
            72, 137, 116, 36, 8,
            72, 137, 84, 36, 16,
            72, 137, 76, 36, 24,
            76, 137, 68, 36, 32,
            76, 137, 76, 36, 40,
            72, 141, 61
        ])
        lea_next_ip = s.synth_code.len() + 4
        x86_synth_emit_u32(s, body_off_as - lea_next_ip)
        // mov rsi, rsp
        x86_synth_emit_bytes(s, [72, 137, 230])
        x86_synth_emit_call_helper(s, "_lipi_async_spawn")
        // leave; ret
        x86_synth_emit_bytes(s, [201, 195])
        fn_entry.fn_entry_offset = wrapper_off_as
        if fn_alias != 0
            fn_alias.fn_entry_offset = wrapper_off_as
        end
    end

    // Patch jump to bypass function body during top-level execution
    after_fn_offset = s.synth_code.len()
    fn_entry.fn_end_offset = after_fn_offset
    if fn_alias != 0
        fn_alias.fn_end_offset = after_fn_offset
    end
    rel32 = after_fn_offset - (fn_jmp_patch + 4)
    x86_synth_patch_u32(s, fn_jmp_patch, rel32)
    if prologue_sub_patch >= 0
        needed_stack = s.synth_stack_offset
        frame_sz = ((needed_stack + 256 + 15) / 16) * 16
        if frame_sz < 512
            frame_sz = 512
        end
        x86_synth_patch_u32(s, prologue_sub_patch, frame_sz)
    end
    s.synth_in_interrupt_fn = saved_in_interrupt
    s.synth_in_naked_fn = saved_in_naked
    s.synth_locals = saved_locals
    s.synth_stack_offset = saved_stack_offset
    s.synth_current_fn_idx = saved_fn_idx
    s.synth_try_depth = saved_try_depth
    s.synth_try_frames = saved_try_frames
    s.synth_defer_starts = saved_defer_starts
    s.synth_defer_ends = saved_defer_ends
    s.synth_has_defer_unwind = saved_has_defer_unwind
    s.synth_defer_mask_off = saved_defer_mask_off
    s.synth_defer_err_off = saved_defer_err_off
    s.synth_in_defer_unwind_pad = saved_in_defer_unwind_pad
    s.synth_loop_starts = saved_loop_starts
    s.synth_loop_breaks = saved_loop_breaks
    s.synth_loop_continues = saved_loop_continues
    s.synth_boxed_vars = saved_boxed_vars
    s.synth_fn_tag_offs = saved_fn_tag_offs
    s.synth_fn_dyn_vars = saved_fn_dyn_vars
    s.synth_in_function = saved_in_function
    s.synth_current_fn = saved_current_fn
    // WHY: Recycle transient byte-list/prescan slabs during legacy AST synthesis on huge bundles
    // (e.g. self-hosting ~600 legacy fns) so Phase-8 RSS stays bounded without slowing small builds.
    leg_cnt_gc = s.synth_functions.len() - s.synth_ssa_replaced_cnt
    if saved_in_function == 0 and s.synth_code.len() > 200000 and leg_cnt_gc > 0 and (leg_cnt_gc % 50) == 0
        gc_collect()
    end
    return 0

// ── 8. Master Program Synthesizer Entry Point ──────────────────────────────────

fn x86_synth_compile_program_opt_internal tokens opt_const_names opt_const_vals reg_names reg_regs ssa_lower_res
    say "    [x86_synth] Initializing synthesizer..."
    s = x86_synth_new()
    s.synth_ssa_lower_res = ssa_lower_res

    say "    [x86_synth] Populating " + str(opt_const_names.len()) + " folded constants..."
    // 0a. Populate SSA constant-folded values
    if opt_const_names != 0 and opt_const_vals != 0
        ci = 0
        while ci < opt_const_names.len()
            c_name = opt_const_names[ci]
            c_val = opt_const_vals[ci]
            x86_synth_set_global_const(s, c_name, c_val)
            ci = ci + 1
        end
    end

    say "    [x86_synth] Binding " + str(reg_names.len()) + " register mappings..."
    // 0b. Populate SSA linear scan physical register assignments
    // WHY: Directly bind lists to synthesizer avoiding iterative copy overhead.
    if reg_names != 0 and reg_regs != 0
        s.synth_regalloc_names = reg_names
        s.synth_regalloc_regs = reg_regs
        if reg_names.len() > 0
            s.synth_regalloc_buckets = x86_synth_make_buckets_4096()
            rbi = 0
            rb_n = reg_names.len()
            while rbi < rb_n
                x86_synth_bucket_insert(s.synth_regalloc_buckets, reg_names[rbi], rbi)
                rbi = rbi + 1
    end

    // 1. Emit top-level stack frame prologue at entry point (offset 0) & pre-scan function signatures + top-level globals
    say "    [x86_synth] Emitting top-level prologue..."
    top_prologue_patch = x86_synth_emit_prologue(s)
    top_tag_init_patch = 0 - 1
    if s.synth_freestanding == 0
        top_tag_init_patch = s.synth_code.len()
        x86_synth_emit_bytes(s, [15, 31, 68, 0, 0]) // 5B NOP placeholder for top-level dyn_tagged zeroing stub
    end
    if s.synth_freestanding == 1
        // Preserve incoming boot/UEFI arguments (%rdi=magic/ImageHandle, %rsi=mb2_info/SystemTable)
        // in local slots [rbp-48] and [rbp-56] across any top-level initialization before kmain/efi_main/main!
        x86_synth_emit_bytes(s, [72, 137, 125, 208, 72, 137, 117, 200]) // mov [rbp-48], rdi; mov [rbp-56], rsi
    elif s.synth_emit_obj == 0
        // Publish dynamic RW globals scan span into [rw_vaddr + 488] (_gc_globals_bytes) for GC root scanning
        // (Skipped in -c object mode where `lipi link` trampoline publishes the merged cross-object span!)
        x86_synth_emit_bytes(s, [72, 184]) // movabs rax, <rw_vaddr + 488>
        s.synth_globals_rw_ptr_patch = s.synth_code.len()
        x86_synth_emit_u64(s, 0)
        x86_synth_emit_bytes(s, [72, 185]) // movabs rcx, <globals_bytes>
        s.synth_globals_rw_len_patch = s.synth_code.len()
        x86_synth_emit_u64(s, 0)
        x86_synth_emit_bytes(s, [72, 137, 8]) // mov [rax], rcx
    end
    x86_synth_prescan_signatures(s, tokens)
    s.synth_boxed_vars = x86_synth_prescan_boxed_vars(tokens, 0, 0 - 1, 0 - 1)
    if s.synth_freestanding == 0
        s.synth_fn_dyn_vars = x86_synth_prescan_dyn_vars(tokens, 0, 0 - 1, 0 - 1, 0)
    end
    x86_synth_prescan_globals(s, tokens)

    // Install top-level defer unwind frame if top-level statements contain `defer` (hosted mode)
    top_defer_pad_lea_patch = 0 - 1
    if s.synth_freestanding == 0 and x86_synth_body_has_defer(tokens, 0, 0 - 1, 0 - 1) == 1
        s.synth_has_defer_unwind = 1
        s.synth_stack_offset = ((s.synth_stack_offset + 15) / 16) * 16 + 96
        top_def_exc_off = s.synth_stack_offset
        s.synth_defer_mask_off = top_def_exc_off - 72
        s.synth_defer_err_off = top_def_exc_off - 80
        s.synth_stack_offset = top_def_exc_off + 8
        x86_synth_emit_bytes(s, [49, 192]) // xor eax, eax
        x86_synth_emit_store_var(s, 0, s.synth_defer_mask_off)
        x86_synth_emit_bytes(s, [72, 141, 189])
        x86_synth_emit_u32(s, 0 - top_def_exc_off)
        x86_synth_emit_bytes(s, [72, 141, 53])
        top_defer_pad_lea_patch = s.synth_code.len()
        x86_synth_emit_u32(s, 0)
        x86_synth_emit_bytes(s, [72, 137, 234, 72, 137, 225])
        x86_synth_emit_call_helper(s, "_lipi_exc_push")
        s.synth_last_store_end = 0 - 1
    end

    // 2. Synthesize all functions, structs, and statements
    say "    [x86_synth] Synthesizing top-level declarations & statements..."
    pos_box = [0]
    has_top_level = 0
    t_total = tokens.len()
    while get(pos_box, 0) < t_total
        cur_pos = get(pos_box, 0)
        cur_k = tokens[cur_pos].tok_kind
        if cur_k == TOK_EOF()
            break
        end

        tok_item = tokens[cur_pos]
        is_fn_tok = 0
        if tok_item.tok_kind == TOK_KW_FN() or tok_item.tok_kind == TOK_DIR_FN() or tok_item.tok_kind == TOK_KW_COMPONENT()
            is_fn_tok = 1
        end
        if tok_item.tok_kind == TOK_KW_ASYNC() and cur_pos + 1 < tokens.len() and (tokens[cur_pos + 1].tok_kind == TOK_KW_FN() or tokens[cur_pos + 1].tok_kind == TOK_DIR_FN())
            is_fn_tok = 1
        end
        if tok_item.tok_kind == TOK_KW_STRUCT() or tok_item.tok_kind == TOK_DIR_STRUCT() or tok_item.tok_kind == TOK_KW_ENUM() or tok_item.tok_kind == TOK_DIR_ENUM() or tok_item.tok_kind == TOK_KW_IMPL()
            is_fn_tok = 1
        end
        if tok_item.tok_kind == TOK_DIR_TRAIT() and cur_pos + 1 < tokens.len() and x86_synth_is_ident_token(tokens[cur_pos + 1].tok_kind) == 1 and tokens[cur_pos + 1].tok_span.span_start_line == tok_item.tok_span.span_start_line
            is_fn_tok = 1
        end
        if tok_item.tok_kind == TOK_IDENT() and (tok_item.tok_text == "union" or tok_item.tok_text == "@union" or tok_item.tok_text == "ইউনিয়ন")
            is_fn_tok = 1
        end

        if is_fn_tok == 0 and tok_item.tok_kind != TOK_NEWLINE() and tok_item.tok_kind != TOK_SEMI()
            has_top_level = 1
        end

        before_top_stmt_p = get(pos_box, 0)
        x86_synth_compile_statement(s, tokens, pos_box)
        if get(pos_box, 0) <= before_top_stmt_p
            list_set(pos_box, 0, before_top_stmt_p + 1)
        end

    // 3. Dispatch entry function: in freestanding mode check kmain -> efi_main -> main -> মূল
    //    and forward preserved boot/UEFI args (%rdi, %rsi); in hosted mode check main / মূল.
    has_main = 0
    main_name = ""
    if s.synth_entry_sym != ""
        idx_custom = x86_synth_find_fn_last_idx(s, s.synth_entry_sym)
        if idx_custom >= 0
            has_main = 1
            main_name = s.synth_entry_sym
        end
    end
    if has_main == 0 and s.synth_freestanding == 1
        idx_km = x86_synth_find_fn_last_idx(s, "kmain")
        idx_efi = x86_synth_find_fn_last_idx(s, "efi_main")
        idx_en = x86_synth_find_fn_last_idx(s, "main")
        idx_bn = x86_synth_find_fn_last_idx(s, "মূল")
        if idx_km >= 0
            has_main = 1
            main_name = "kmain"
        elif idx_efi >= 0
            has_main = 1
            main_name = "efi_main"
        elif idx_en >= 0 or idx_bn >= 0
            has_main = 1
            if idx_bn > idx_en
                main_name = "মূল"
            else
                main_name = "main"
            end
        end
    elif has_main == 0
        idx_en = x86_synth_find_fn_last_idx(s, "main")
        idx_bn = x86_synth_find_fn_last_idx(s, "মূল")
        if idx_en >= 0 or idx_bn >= 0
            has_main = 1
            if idx_bn > idx_en
                main_name = "মূল"
            else
                main_name = "main"
            end
        end
    end
    if has_main == 1 and s.synth_called_top_level_main == 0
        if s.synth_freestanding == 1
            // Restore boot/UEFI (%rdi, %rsi) before invoking kmain / efi_main / main
            x86_synth_emit_bytes(s, [72, 139, 125, 208, 72, 139, 117, 200]) // mov rdi, [rbp-48]; mov rsi, [rbp-56]
        end
        call_off = s.synth_code.len()
        x86_synth_emit_byte(s, 232)
        patch_pos = s.synth_code.len()
        x86_synth_emit_u32(s, 0)
        call_rel = X86CallReloc()
        call_rel.cr_patch_offset = patch_pos
        call_rel.cr_call_site_end = patch_pos + 4
        call_rel.cr_target_name = main_name
        push(s.synth_call_relocs, call_rel)
    elif has_main == 0
        // When no main exists, default exit code is 0 in rax
        x86_synth_emit_byte(s, 49)  // xor eax, eax (default exit code 0)
        x86_synth_emit_byte(s, 192)

    // 4. Backpatch top-level stack frame size & emit exit epilogue
    top_needed = s.synth_stack_offset
    top_frame = ((top_needed + 256 + 15) / 16) * 16
    if s.synth_freestanding == 1
        if top_frame < 512
            top_frame = 512
        end
    else
        if top_frame < 4096
            top_frame = 4096
        end
    end
    x86_synth_patch_u32(s, top_prologue_patch, top_frame)
    x86_synth_emit_defers(s, tokens)
    x86_synth_emit_epilogue(s)
    if s.synth_has_defer_unwind == 1 and top_defer_pad_lea_patch >= 0
        top_def_pad_off = s.synth_code.len()
        x86_synth_patch_u32(s, top_defer_pad_lea_patch, top_def_pad_off - (top_defer_pad_lea_patch + 4))
        s.synth_last_store_end = 0 - 1
        x86_synth_emit_store_var(s, 0, s.synth_defer_err_off)
        s.synth_in_defer_unwind_pad = 1
        x86_synth_emit_defers(s, tokens)
        s.synth_in_defer_unwind_pad = 0
        x86_synth_emit_load_var(s, 7, s.synth_defer_err_off)
        x86_synth_emit_call_helper(s, "_lipi_exc_throw")
    end
    x86_synth_emit_tag_init_stub_if_needed(s, top_tag_init_patch)

    // 5. Emit runtime helpers:
    //    - Freestanding (--freestanding / bare-metal): ONLY zero-syscall Ring-0 silicon helpers (0 Linux syscalls!)
    //    - Hosted: full Lipi micro-runtime + Ring-0 silicon & AVX2 helpers
    arena_offs = list()
    if s.synth_freestanding == 1
        x86_synth_emit_all_silicon_helpers(s)
    else
        x86_synth_emit_print_int_helper(s)
        x86_synth_emit_alloc_helper(s)
        x86_synth_emit_all_runtime_helpers(s)
        x86_synth_emit_all_avx2_helpers(s)
        x86_synth_emit_all_silicon_helpers(s)
        arena_offs = x86_synth_emit_arena_helpers(s)
    end

    // 5b. Attach and integrate direct SSA IR Lowering machine code & functions
    // WHY: Lowered SSA functions must be merged into s.synth_functions and s.synth_code
    // BEFORE call relocations and rodata base addresses are resolved.
    if ssa_lower_res != 0
        x86_synth_attach_ssa_lower_res(s, ssa_lower_res)
    end

    // 6. Resolve Inter-Procedural Call Relocations
    ci = 0
    while ci < s.synth_call_relocs.len()
        cr = s.synth_call_relocs[ci]
        resolved_addr = 0
        found = 0
        if cr.cr_target_name == "__print_int"
            resolved_addr = s.synth_print_int_off
            found = 1
        elif cr.cr_target_name == "__alloc"
            resolved_addr = s.synth_alloc_off
            found = 1
        else
            if cr.cr_target_name == "main" or cr.cr_target_name == "মূল"
                // WHY: For entry point main, resolve to latest definition in root translation unit
                l_idx = x86_synth_find_fn_last_idx(s, cr.cr_target_name)
                if l_idx >= 0
                    resolved_addr = s.synth_functions[l_idx].fn_entry_offset
                    found = 1
            else
                // WHY: For general functions, preserve original definition ordering via O(1) bucket index
                fn_item = x86_synth_find_fn_first(s, cr.cr_target_name)
                if fn_item != 0 and fn_item.fn_entry_offset >= 0
                    resolved_addr = fn_item.fn_entry_offset
                    found = 1

        if found == 0
            is_ext_sym = 0
            if s.synth_emit_obj == 1
                ei_x = 0
                while ei_x < s.synth_extern_fns.len()
                    if s.synth_extern_fns[ei_x] == cr.cr_target_name
                        is_ext_sym = 1
                        break
                    end
                    ei_x = ei_x + 1
                end
            end
            if is_ext_sym == 1
                // Leave rel32 = 0 for ELF64 ET_REL (.o) SHN_UNDEF + R_X86_64_PLT32 relocation!
                ci = ci + 1
                continue
            end
            say "❌ [Error]: Undefined function '" + cr.cr_target_name + "' (not declared in scope or imported modules)."
            exit(1)

        rel32 = resolved_addr - cr.cr_call_site_end
        x86_synth_patch_u32(s, cr.cr_patch_offset, rel32)
        ci = ci + 1

    // 7. Emit compact LSYM0 symbol/line table in .rodata (hosted mode), then resolve 64-Bit Virtual Memory & W^X Relocations
    lsym_ro_off = 0
    if s.synth_freestanding == 0
        lsym_ro_off = x86_synth_emit_lsym_rodata(s)
    end
    // Respect configurable base address (CLI --base-addr or source @layout(base=0x...)) & code file offset!
    eff_base_vaddr = s.synth_base_vaddr
    if s.synth_layout_base != 0 and eff_base_vaddr == 1073741824
        eff_base_vaddr = s.synth_layout_base
        s.synth_base_vaddr = eff_base_vaddr
    end
    eff_code_foff = s.synth_code_file_off
    code_base_vaddr = eff_base_vaddr - (0 - eff_code_foff)
    total_code_size = s.synth_code.len()
    rodata_base_vaddr = code_base_vaddr - (0 - total_code_size)
    ro_len = s.synth_rodata.len()
    rodata_end_vaddr = rodata_base_vaddr - (0 - ro_len)

    // Compute exact 4KB page-aligned RW data segment address (PT_LOAD[1], PF_R | PF_W)
    ro_file_off = eff_code_foff + total_code_size
    ro_end_file_off = ro_file_off + ro_len
    text_ro_end = eff_code_foff - (0 - total_code_size) - (0 - ro_len)
    rem_page = text_ro_end % 4096
    pad_bytes = 0
    if rem_page != 0
        pad_bytes = 4096 - rem_page
    end
    rw_file_off = text_ro_end + pad_bytes
    rw_vaddr = eff_base_vaddr - (0 - text_ro_end) - (0 - pad_bytes)
    g_argc_vaddr = rw_vaddr
    g_argv_vaddr = rw_vaddr - (0 - 8)
    heap_base_vaddr = rw_vaddr - (0 - 16)
    heap_ptr_vaddr = rw_vaddr - (0 - 24)
    slab_vaddr = rw_vaddr - (0 - 32)
    exc_top_vaddr = rw_vaddr - (0 - 104)
    stack_bottom_vaddr = rw_vaddr - (0 - 112)

    ri = 0
    while ri < s.synth_str_relocs.len()
        rel = s.synth_str_relocs[ri]
        target_vaddr = rodata_base_vaddr - (0 - rel.sr_rodata_offset)
        x86_synth_patch_u64(s, rel.sr_patch_offset, target_vaddr)
        ri = ri + 1

    // 8. Backpatch Strict W^X RW Runtime Globals (zero writes to .text) & Record Static-PIE Fixups
    if s.synth_alloc_off > 0
        x86_synth_patch_u64(s, s.synth_alloc_off + 19, heap_base_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_alloc_off + 19, rw_file_off + 16)
    if s.synth_argv_off > 0
        x86_synth_patch_u64(s, s.synth_argv_off + 15, g_argc_vaddr)
        x86_synth_patch_u64(s, s.synth_argv_off + 28, g_argv_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_argv_off + 15, rw_file_off)
        x86_synth_record_reloc_patch(s, s.synth_argv_off + 28, rw_file_off + 8)
    if s.synth_slab_off > 0
        x86_synth_patch_u64(s, s.synth_slab_off + 2, slab_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_slab_off + 2, rw_file_off + 32)
    if s.synth_is_str_off > 0
        x86_synth_patch_u64(s, s.synth_is_str_off + 19, rodata_base_vaddr)
        x86_synth_patch_u64(s, s.synth_is_str_off + 34, rodata_end_vaddr)
        x86_synth_patch_u64(s, s.synth_is_str_off + 49, heap_base_vaddr)
        x86_synth_patch_u64(s, s.synth_is_str_off + 72, heap_ptr_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_is_str_off + 19, ro_file_off)
        x86_synth_record_reloc_patch(s, s.synth_is_str_off + 34, ro_end_file_off)
        x86_synth_record_reloc_patch(s, s.synth_is_str_off + 49, rw_file_off + 16)
        x86_synth_record_reloc_patch(s, s.synth_is_str_off + 72, rw_file_off + 24)
    if s.synth_exc_push_off > 0
        x86_synth_patch_u64(s, s.synth_exc_push_off + 2, exc_top_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_exc_push_off + 2, rw_file_off + 104)
    if s.synth_exc_pop_off > 0
        x86_synth_patch_u64(s, s.synth_exc_pop_off + 2, exc_top_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_exc_pop_off + 2, rw_file_off + 104)
    if s.synth_exc_throw_off > 0
        x86_synth_patch_u64(s, s.synth_exc_throw_off + 2, exc_top_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_exc_throw_off + 2, rw_file_off + 104)
    if s.synth_div_zero_off > 0
        x86_synth_patch_u64(s, s.synth_div_zero_off + 2, exc_top_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_div_zero_off + 2, rw_file_off + 104)
    if s.synth_stack_bottom_off > 0
        x86_synth_patch_u64(s, s.synth_stack_bottom_off + 2, stack_bottom_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_stack_bottom_off + 2, rw_file_off + 112)
    if s.synth_heap_base_fn_off > 0
        x86_synth_patch_u64(s, s.synth_heap_base_fn_off + 2, heap_base_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_heap_base_fn_off + 2, rw_file_off + 16)
    if s.synth_heap_ptr_fn_off > 0
        x86_synth_patch_u64(s, s.synth_heap_ptr_fn_off + 2, heap_ptr_vaddr)
        x86_synth_record_reloc_patch(s, s.synth_heap_ptr_fn_off + 2, rw_file_off + 24)
    end
    trace_rw_slot = 0
    if s.synth_lsym_ptrs_off > 0
        trace_rw_slot = x86_synth_alloc_mutable_global(s, "__lipi_last_trace_ptr")
    end
    async_sched_rw_slot = 0
    if s.synth_async_sched_slot_off > 0
        async_sched_rw_slot = x86_synth_alloc_mutable_global(s, "__lipi_async_sched_ptr")
        x86_synth_patch_u64(s, s.synth_async_sched_slot_off + 2, rw_vaddr - (0 - async_sched_rw_slot))
        x86_synth_record_reloc_patch(s, s.synth_async_sched_slot_off + 2, rw_file_off + async_sched_rw_slot)
    end
    if s.synth_globals_rw_ptr_patch > 0
        x86_synth_patch_u64(s, s.synth_globals_rw_ptr_patch, rw_vaddr - (0 - 488))
        x86_synth_record_reloc_patch(s, s.synth_globals_rw_ptr_patch, rw_file_off + 488)
        gc_glob_span = s.synth_mutable_globals.len() * 8
        // WHY: Include static @bss buffers in GC root scanning so GC pointers stored inside
        // @bss globals/ring-buffers are conservatively marked and never collected prematurely!
        if s.synth_bss_cursor > 0
            bss_base_rw_gc = 512 + gc_glob_span
            bss_rem_gc = bss_base_rw_gc % 4096
            if bss_rem_gc != 0
                bss_base_rw_gc = bss_base_rw_gc + (4096 - bss_rem_gc)
            end
            if bss_base_rw_gc < 4096
                bss_base_rw_gc = 4096
            end
            bss_end_gc = bss_base_rw_gc + (((s.synth_bss_cursor + 7) / 8) * 8)
            gc_glob_span = bss_end_gc - 512
        end
        x86_synth_patch_u64(s, s.synth_globals_rw_len_patch, gc_glob_span)
    end
    if s.synth_lsym_ptrs_off > 0
        lsym_vaddr = rodata_base_vaddr - (0 - lsym_ro_off)
        x86_synth_patch_u64(s, s.synth_lsym_ptrs_off + 2, lsym_vaddr)
        x86_synth_patch_u64(s, s.synth_lsym_ptrs_off + 12, code_base_vaddr)
        x86_synth_patch_u64(s, s.synth_lsym_ptrs_off + 22, rodata_base_vaddr)
        x86_synth_patch_u64(s, s.synth_lsym_ptrs_off + 32, rw_vaddr - (0 - trace_rw_slot))
        x86_synth_record_reloc_patch(s, s.synth_lsym_ptrs_off + 2, ro_file_off + lsym_ro_off)
        x86_synth_record_reloc_patch(s, s.synth_lsym_ptrs_off + 12, eff_code_foff)
        x86_synth_record_reloc_patch(s, s.synth_lsym_ptrs_off + 22, ro_file_off)
        x86_synth_record_reloc_patch(s, s.synth_lsym_ptrs_off + 32, rw_file_off + trace_rw_slot)
    end
    mg_i = 0
    while mg_i < s.synth_global_rw_patch_offs.len()
        mg_p = s.synth_global_rw_patch_offs[mg_i]
        mg_slot = s.synth_global_rw_slot_offs[mg_i]
        x86_synth_patch_u64(s, mg_p, rw_vaddr - (0 - mg_slot))
        x86_synth_record_reloc_patch(s, mg_p, rw_file_off + mg_slot)
        mg_i = mg_i + 1
    end

    // 8b. Backpatch Static @bss Aligned Buffers (placed on a 4KB page boundary right after mutable globals!)
    if s.synth_bss_cursor > 0
        bss_base_rw = 512 + (s.synth_mutable_globals.len() * 8)
        bss_rem = bss_base_rw % 4096
        if bss_rem != 0
            bss_base_rw = bss_base_rw + (4096 - bss_rem)
        end
        if bss_base_rw < 4096
            bss_base_rw = 4096
        end
        bpi = 0
        while bpi < s.synth_bss_patch_offs.len()
            bp_off = s.synth_bss_patch_offs[bpi]
            b_idx = s.synth_bss_patch_idxs[bpi]
            slot_rw = bss_base_rw + s.synth_bss_offs[b_idx]
            x86_synth_patch_u64(s, bp_off, rw_vaddr - (0 - slot_rw))
            x86_synth_record_reloc_patch(s, bp_off, rw_file_off + slot_rw)
            bpi = bpi + 1
        end
    end

    // 9. Backpatch Scoped Arena Virtual Addresses & Record PIE Fixups
    x86_synth_patch_arena_helpers(s, arena_offs, heap_base_vaddr, heap_ptr_vaddr)
    if arena_offs.len() >= 4
        if arena_offs[0] > 0
            x86_synth_record_reloc_patch(s, arena_offs[0] + 6, rw_file_off + 16)
            x86_synth_record_reloc_patch(s, arena_offs[0] + 36, rw_file_off + 24)
        end
        if arena_offs[1] > 0
            x86_synth_record_reloc_patch(s, arena_offs[1] + 2, rw_file_off + 16)
            x86_synth_record_reloc_patch(s, arena_offs[1] + 24, rw_file_off + 24)
        end
        if arena_offs[2] > 0
            x86_synth_record_reloc_patch(s, arena_offs[2] + 2, rw_file_off + 16)
            x86_synth_record_reloc_patch(s, arena_offs[2] + 15, rw_file_off + 24)
        end
        if arena_offs[3] > 0
            x86_synth_record_reloc_patch(s, arena_offs[3] + 2, rw_file_off + 16)
            x86_synth_record_reloc_patch(s, arena_offs[3] + 15, rw_file_off + 24)
        end
    end

    // 10. Sovereign Silicon Direct Peephole Optimizer (Guarded)
    x86_silicon_optimize_code(s)

    return s

fn x86_synth_attach_ssa_lower_res s ssa_lower_res
    // WHY: Connects middle-end SSA IR Lowering results to the backend silicon synthesizer WITHOUT
    // duplicating already-emitted AST functions (fixes 2x binary bloat under `--ssa-codegen`).
    // Copies ONLY unique SSA function byte slices that are not already present in `s.synth_functions`.
    s.synth_ssa_lower_res = ssa_lower_res
    slr_c_len = 0
    if ssa_lower_res != 0
        if ssa_lower_res.slr_code_buf != 0
            slr_c_len = buf_len(ssa_lower_res.slr_code_buf)
        elif ssa_lower_res.slr_code != 0
            slr_c_len = ssa_lower_res.slr_code.len()
        end
    end
    if ssa_lower_res != 0 and slr_c_len > 0
        attached_cnt = 0
        attached_bytes = 0
        fi = 0
        while fi < ssa_lower_res.slr_fn_names.len()
            fn_name = ssa_lower_res.slr_fn_names[fi]
            src_off = ssa_lower_res.slr_fn_offsets[fi]
            src_sz = 0
            if ssa_lower_res.slr_fn_sizes != 0 and fi < ssa_lower_res.slr_fn_sizes.len()
                src_sz = ssa_lower_res.slr_fn_sizes[fi]
            elif fi + 1 < ssa_lower_res.slr_fn_offsets.len()
                src_sz = ssa_lower_res.slr_fn_offsets[fi + 1] - src_off
            else
                src_sz = slr_c_len - src_off
            end
            already_exists = 0
            if x86_synth_find_fn_first(s, fn_name) != 0
                already_exists = 1
            end
            if already_exists == 0 and src_sz > 0 and (src_off + src_sz) <= slr_c_len
                dst_off = buf_len(s.synth_code)
                if ssa_lower_res.slr_code_buf != 0
                    buf_write_mem(s.synth_code, buf_ptr(ssa_lower_res.slr_code_buf) + src_off, src_sz)
                else
                    bi = 0
                    while bi < src_sz and (src_off + bi) < slr_c_len
                        buf_write_byte(s.synth_code, ssa_lower_res.slr_code[src_off + bi])
                        bi = bi + 1
                    end
                end
                fn_item = X86Function()
                fn_item.fn_name = fn_name
                fn_item.fn_entry_offset = dst_off
                fn_item.fn_end_offset = buf_len(s.synth_code)
                fn_item.fn_ret_type = ""
                fn_item.fn_tok_pos = 0 - 1
                fn_item.fn_param_types = list()
                x86_synth_register_fn_obj(s, fn_item)
                attached_cnt = attached_cnt + 1
                attached_bytes = attached_bytes + src_sz
            end
            fi = fi + 1
        end
        if attached_cnt > 0 and s.synth_ssa_rodata_base < 0
            if ssa_lower_res.slr_rodata_buf != 0 and buf_len(ssa_lower_res.slr_rodata_buf) > 0
                buf_write_mem(s.synth_rodata, buf_ptr(ssa_lower_res.slr_rodata_buf), buf_len(ssa_lower_res.slr_rodata_buf))
            elif ssa_lower_res.slr_rodata != 0
                ri = 0
                while ri < ssa_lower_res.slr_rodata.len()
                    buf_write_byte(s.synth_rodata, ssa_lower_res.slr_rodata[ri])
                    ri = ri + 1
                end
            end
        end
        if g_x86_ssa_codegen == 1
            say "    [x86_synth] --ssa-codegen active: replaced " + str(s.synth_ssa_replaced_cnt) + "/" + str(ssa_lower_res.slr_fn_names.len()) + " functions directly from SSA CFG (" + str(s.synth_ssa_replaced_bytes) + " bytes native IR, " + str(ssa_lower_res.slr_total_insts) + " IR insts, " + str(attached_cnt) + " auxiliary, 0 duplicates)"
        end
    end
    return 0

fn x86_synth_compile_program_full tokens opt_const_names opt_const_vals reg_names reg_regs ssa_lower_res
    // WHY: Full compiler pipeline entry point returning compact ByteBuffers in synth_code/synth_rodata.
    return x86_synth_compile_program_opt_internal(tokens, opt_const_names, opt_const_vals, reg_names, reg_regs, ssa_lower_res)

fn x86_synth_compile_program_opt tokens opt_const_names opt_const_vals reg_names reg_regs
    // WHY: Backward compatibility wrapper returning integer lists in synth_code/synth_rodata for unit tests.
    s = x86_synth_compile_program_opt_internal(tokens, opt_const_names, opt_const_vals, reg_names, reg_regs, 0)
    code_b = s.synth_code
    ro_b = s.synth_rodata
    s.synth_code = x86_synth_buf_to_list(code_b)
    s.synth_rodata = x86_synth_buf_to_list(ro_b)
    buf_free(code_b)
    buf_free(ro_b)
    return s

fn x86_synth_compile_program tokens
    // WHY: Backward compatibility wrapper returning integer lists in synth_code/synth_rodata for unit tests.
    return x86_synth_compile_program_opt(tokens, list(), list(), list(), list())
