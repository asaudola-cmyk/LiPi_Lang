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
        if s.synth_last_expr_type == "float"
            x86_synth_emit_call_helper(s, "_lipi_print_float")
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
            if nt.tok_kind != TOK_NEWLINE() and nt.tok_kind != TOK_SEMI() and nt.tok_kind != TOK_EOF()
                has_expr = 1

        if has_expr == 1
            x86_synth_compile_expr(s, toks, pos_box)
            if s.synth_last_expr_type == "float" and s.synth_current_fn_idx >= 0 and s.synth_current_fn_idx < s.synth_functions.len()
                ret_fn_obj = s.synth_functions[s.synth_current_fn_idx]
                if ret_fn_obj.fn_ret_type == ""
                    ret_fn_obj.fn_ret_type = "f64"
                end
            end
        else
            // Default 0 return
            x86_synth_emit_byte(s, 49)
            x86_synth_emit_byte(s, 192)
        end

        if s.synth_try_frames.len() > 0
            cur_tframe = s.synth_try_frames[s.synth_try_frames.len() - 1]
            tf_flag_off = cur_tframe[0]
            tf_val_off = cur_tframe[1]
            tf_patches = cur_tframe[2]
            tf_entry_depth = cur_tframe[3]
            pops_ret = s.synth_try_depth - tf_entry_depth
            if pops_ret > 0
                x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rax; sub rsp, 8
                ti_ret = 0
                while ti_ret < pops_ret
                    x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                    ti_ret = ti_ret + 1
                end
                x86_synth_emit_bytes(s, [72, 131, 196, 8, 88]) // add rsp, 8; pop rax
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
            x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rax; sub rsp, 8
            ti_ret = 0
            while ti_ret < s.synth_try_depth
                x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                ti_ret = ti_ret + 1
            end
            x86_synth_emit_bytes(s, [72, 131, 196, 8, 88]) // add rsp, 8; pop rax
        end

        x86_synth_emit_epilogue(s)
        return 0

    // ── 3. Loop Control: break / থামো & continue / চলুক ───────────────────────
    if k == TOK_KW_BREAK() or (k == TOK_IDENT() and (txt == "break" or txt == "থামো"))
        list_set(pos_box, 0, pos + 1)
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

    if k == TOK_KW_CONTINUE() or (k == TOK_IDENT() and (txt == "continue" or txt == "চলুক" or txt == "চলো"))
        list_set(pos_box, 0, pos + 1)
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

    // ── 4. Struct Definition: struct / গঠন / @struct ──────────────────────────
    is_struct = 0
    if k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT()
        is_struct = 1
    if k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct")
        is_struct = 1

    if is_struct == 1
        return x86_synth_compile_struct_def(s, toks, pos_box, t.tok_span.span_start_col, t.tok_span.span_start_line)

    // ── 5. Struct Field Assignment (arbitrary depth): obj.field = expr, obj.f1.f2 = expr
    if k == TOK_IDENT()
        scan_fp = pos + 1
        chain_fields = list()
        while scan_fp + 1 < toks.len()
            t_dot = toks[scan_fp]
            t_fld = toks[scan_fp + 1]
            is_dot = 0
            if t_dot.tok_kind == TOK_DOT() or (t_dot.tok_kind != TOK_STR() and t_dot.tok_text == ".")
                is_dot = 1
            if is_dot == 1 and t_fld.tok_kind == TOK_IDENT()
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

                // Load root obj pointer into %rcx (preserving stack alignment)
                lv_obj = x86_synth_find_local_var(s, obj_name)
                cur_stype = ""
                if lv_obj != 0 and lv_obj.lv_is_spilled == 0 and lv_obj.lv_reg >= 0
                    x86_synth_emit_mov_reg_reg(s, 1, lv_obj.lv_reg)
                    cur_stype = x86_synth_get_var_type(s, obj_name)
                else
                    mg_obj = x86_synth_find_mutable_global(s, obj_name)
                    if lv_obj == 0 and mg_obj >= 512
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

                // Walk intermediate nested struct pointers with field type propagation
                ci = 0
                while ci < chain_fields.len() - 1
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

                leaf_field = chain_fields[chain_fields.len() - 1]
                f_off = x86_synth_get_field_offset(s, cur_stype, leaf_field)
                leaf_ftype = x86_synth_get_field_type(s, cur_stype, leaf_field)
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
                    if is_flt_fld == 1 and fld_comp_op != TOK_PERCENT()
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
                        x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 5, 72, 153, 73, 247, 248])
                    elif fld_comp_op == TOK_PERCENT()
                        x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 8, 72, 153, 73, 247, 248, 72, 137, 208])
                    end
                end

                // Store value to leaf field: mov [rcx + f_off], rax
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
                if is_arr_comp == 1
                    x86_synth_emit_byte(s, 80) // push rhs (stack: [rsp]=rhs, [rsp+8]=idx)
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
                    x86_synth_emit_bytes(s, [72, 139, 116, 36, 8]) // mov rsi, [rsp + 8]
                    x86_synth_emit_call_helper(s, "_lipi_list_get") // rax = old element
                    x86_synth_emit_bytes(s, [65, 88]) // pop r8 (rhs); stack top is now idx
                    if rhs_arr_type == "float" and arr_comp_op != TOK_PERCENT()
                        x86_synth_emit_bytes(s, [102, 72, 15, 110, 192]) // movq xmm0, rax
                        x86_synth_emit_bytes(s, [102, 73, 15, 110, 200]) // movq xmm1, r8
                        if arr_comp_op == TOK_PLUS()
                            x86_synth_emit_bytes(s, [242, 15, 88, 193])
                        elif arr_comp_op == TOK_MINUS()
                            x86_synth_emit_bytes(s, [242, 15, 92, 193])
                        elif arr_comp_op == TOK_STAR()
                            x86_synth_emit_bytes(s, [242, 15, 89, 193])
                        elif arr_comp_op == TOK_SLASH()
                            x86_synth_emit_bytes(s, [242, 15, 94, 193])
                        end
                        x86_synth_emit_bytes(s, [102, 72, 15, 126, 192]) // movq rax, xmm0
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
                        x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 5, 72, 153, 73, 247, 248])
                    elif arr_comp_op == TOK_PERCENT()
                        x86_synth_emit_bytes(s, [77, 133, 192, 117, 4, 49, 192, 235, 8, 72, 153, 73, 247, 248, 72, 137, 208])
                    end
                end
                // rdx = val, rsi = idx, rdi = list_ptr
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
                        x86_synth_emit_bytes(s, [82, 86]) // push rdx; push rsi
                        x86_synth_emit_mutable_global_read(s, mg_arr2)
                        x86_synth_emit_bytes(s, [72, 137, 199, 94, 90]) // mov rdi, rax; pop rsi; pop rdx
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
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "নতুবা_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "অন্যথায়" or cur_txt == "নতুবা" or cur_txt == "@else")
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

            if cur_t.tok_span.span_start_line == base_line and x86_synth_should_stop_inline(toks, pos_box, base_line) == 1
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
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "নতুবা_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "অন্যথায়" or cur_txt == "নতুবা" or cur_txt == "@else") and (cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
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
                if ck2 == TOK_IDENT() and (cx2 == "elif" or cx2 == "নাহলে_যদি" or cx2 == "নতুবা_যদি" or cx2 == "@elif" or cx2 == "else" or cx2 == "নাহলে" or cx2 == "অন্যথায়" or cx2 == "নতুবা" or cx2 == "@else")
                    break
                if x86_synth_is_block_end(toks, cur_p2) == 1
                    break
                if ct2.tok_span.span_start_line > elif_line and ct2.tok_span.span_start_col <= base_col
                    break
                b_p2 = get(pos_box, 0)
                x86_synth_compile_statement(s, toks, pos_box)
                if get(pos_box, 0) == b_p2
                    list_set(pos_box, 0, b_p2 + 1)
                if ct2.tok_span.span_start_line == elif_line and x86_synth_should_stop_inline(toks, pos_box, elif_line) == 1
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
            if cur_k == TOK_IDENT() and (cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "অন্যথায়" or cur_txt == "নতুবা" or cur_txt == "@else") and (cur_t.tok_span.span_start_col == base_col or cur_t.tok_span.span_start_line == base_line)
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
                    if ct3.tok_span.span_start_line == else_line and x86_synth_should_stop_inline(toks, pos_box, else_line) == 1
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
            var_name = toks[var_pos].tok_text
            assigned_type = ""
            list_set(pos_box, 0, var_pos + 1)
            next_p = get(pos_box, 0)
            if next_p < toks.len() and (toks[next_p].tok_kind == TOK_COLON() or (toks[next_p].tok_kind != TOK_STR() and toks[next_p].tok_text == ":"))
                type_p = next_p + 1
                if type_p < toks.len() and x86_synth_is_ident_token(toks[type_p].tok_kind) == 1
                    assigned_type = toks[type_p].tok_text
                    list_set(pos_box, 0, type_p + 1)
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
                off = x86_synth_bind_reg_var(s, var_name, is_reg)
                if assigned_type != ""
                    x86_synth_set_var_type(s, var_name, assigned_type)
                    if assigned_type == "int" or assigned_type == "i64" or assigned_type == "i32" or assigned_type == "u64" or assigned_type == "u32"
                        x86_synth_set_prim_type(s, var_name, "int")
                    elif assigned_type == "float" or assigned_type == "f64" or assigned_type == "f32"
                        x86_synth_set_prim_type(s, var_name, "float")
                    elif assigned_type == "str" or assigned_type == "string"
                        x86_synth_set_prim_type(s, var_name, "str")
                if is_int_lit == 1
                    if s.synth_in_function == 0
                        x86_synth_set_global_const(s, var_name, int_lit_val)
                    end
                    x86_synth_set_prim_type(s, var_name, "int")
                elif s.synth_last_expr_type == "int"
                    x86_synth_set_prim_type(s, var_name, "int")
                elif s.synth_last_expr_type == "float"
                    x86_synth_set_prim_type(s, var_name, "float")
                elif s.synth_last_expr_type == "str"
                    x86_synth_set_prim_type(s, var_name, "str")
                elif assigned_type == ""
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

    // ── 9c. Structured Try/Catch/Finally: try ... catch [err] ... [finally ...] [end] ─
    is_try_stmt = 0
    if k == TOK_KW_TRY() or k == TOK_DIR_TRY() or (k == TOK_IDENT() and (txt == "try" or txt == "চেষ্টা" or txt == "@try"))
        if pos + 1 >= toks.len() or (toks[pos + 1].tok_kind != TOK_ASSIGN() and toks[pos + 1].tok_text != "=")
            is_try_stmt = 1
        end
    if is_try_stmt == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        // Reserve 96B exception frame [rbp - exc_off]; +64/+72 store pending uncaught exc for finally
        s.synth_stack_offset = ((s.synth_stack_offset + 15) / 16) * 16 + 96
        exc_off = s.synth_stack_offset
        fin_flag_off = exc_off - 64
        fin_val_off = exc_off - 72
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

        // Compile try body until 'catch', 'finally', block end, or dedent
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_pt = get(pos_box, 0)
            if cur_pt >= toks.len() break end
            ct_t = toks[cur_pt]
            if ct_t.tok_kind == TOK_KW_CATCH() or ct_t.tok_kind == TOK_DIR_CATCH() or (ct_t.tok_kind == TOK_IDENT() and (ct_t.tok_text == "catch" or ct_t.tok_text == "ধরো" or ct_t.tok_text == "@catch" or ct_t.tok_text == "finally" or ct_t.tok_text == "অবশেষে" or ct_t.tok_text == "@finally"))
                break
            end
            if x86_synth_is_block_end(toks, cur_pt) == 1 break end
            if ct_t.tok_span.span_start_line > base_line and ct_t.tok_span.span_start_col <= base_col break end
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
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            ct_c = toks[get(pos_box, 0)]
            if ct_c.tok_kind == TOK_KW_CATCH() or ct_c.tok_kind == TOK_DIR_CATCH() or (ct_c.tok_kind == TOK_IDENT() and (ct_c.tok_text == "catch" or ct_c.tok_text == "ধরো" or ct_c.tok_text == "@catch"))
                has_catch_blk = 1
                c_line = ct_c.tok_span.span_start_line
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == c_line and x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                    err_vname = toks[get(pos_box, 0)].tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    // Exception value arrives in %rax; bind to err_vname
                    x86_synth_bind_var(s, err_vname)
                end
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    cur_pc = get(pos_box, 0)
                    if cur_pc >= toks.len() break end
                    ct_c2 = toks[cur_pc]
                    if ct_c2.tok_kind == TOK_IDENT() and (ct_c2.tok_text == "finally" or ct_c2.tok_text == "অবশেষে" or ct_c2.tok_text == "@finally")
                        break
                    end
                    if x86_synth_is_block_end(toks, cur_pc) == 1 break end
                    if ct_c2.tok_span.span_start_line > c_line and ct_c2.tok_span.span_start_col <= base_col break end
                    bp_c = get(pos_box, 0)
                    x86_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) <= bp_c list_set(pos_box, 0, bp_c + 1) end
                end
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
        rp_i = 0
        while rp_i < try_ret_patches.len()
            rp_off = try_ret_patches[rp_i]
            x86_synth_patch_u32(s, rp_off, finally_entry_off - (rp_off + 4))
            rp_i = rp_i + 1
        end
        s.synth_try_frames = pop(s.synth_try_frames)
        s.synth_last_store_end = 0 - 1

        x86_synth_skip_whitespace_tokens(toks, pos_box)
        if get(pos_box, 0) < toks.len()
            ct_f = toks[get(pos_box, 0)]
            if ct_f.tok_kind == TOK_IDENT() and (ct_f.tok_text == "finally" or ct_f.tok_text == "অবশেষে" or ct_f.tok_text == "@finally")
                f_line = ct_f.tok_span.span_start_line
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    cur_pf = get(pos_box, 0)
                    if cur_pf >= toks.len() break end
                    ct_f2 = toks[cur_pf]
                    if x86_synth_is_block_end(toks, cur_pf) == 1 break end
                    if ct_f2.tok_span.span_start_line > f_line and ct_f2.tok_span.span_start_col <= base_col break end
                    bp_f = get(pos_box, 0)
                    x86_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) <= bp_f list_set(pos_box, 0, bp_f + 1) end
                end
            end
        end

        x86_synth_skip_whitespace_tokens(toks, pos_box)
        if get(pos_box, 0) < toks.len() and x86_synth_is_block_end(toks, get(pos_box, 0)) == 1 and toks[get(pos_box, 0)].tok_span.span_start_col >= base_col
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end

        if has_catch_blk == 0
            x86_synth_emit_load_var(s, 0, fin_flag_off)
            x86_synth_emit_bytes(s, [72, 131, 248, 1, 15, 133]) // cmp rax, 1; jne rel32
            skip_rethrow_patch = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            x86_synth_emit_load_var(s, 7, fin_val_off) // mov rdi, [rbp - fin_val_off]
            x86_synth_emit_call_helper(s, "_lipi_exc_throw")
            after_rethrow = s.synth_code.len()
            x86_synth_patch_u32(s, skip_rethrow_patch, after_rethrow - (skip_rethrow_patch + 4))
        end

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
            x86_synth_emit_epilogue(s)
        end
        after_fin_ret = s.synth_code.len()
        x86_synth_patch_u32(s, skip_fin_ret_patch, after_fin_ret - (skip_fin_ret_patch + 4))

        s.synth_last_store_end = 0 - 1
        return 0

    // ── 9d. Contextual Pattern Match: match <expr> ... (preserves `match = 1`) ──
    is_match_stmt = 0
    if k == TOK_KW_MATCH() or k == TOK_DIR_MATCH() or (k == TOK_IDENT() and (txt == "match" or txt == "মিল" or txt == "মেলাও" or txt == "@match"))
        if pos + 1 < toks.len()
            mn = toks[pos + 1]
            if mn.tok_kind != TOK_ASSIGN() and mn.tok_text != "=" and mn.tok_kind != TOK_PLUSEQ() and mn.tok_text != "+=" and mn.tok_kind != TOK_MINUSEQ() and mn.tok_text != "-=" and mn.tok_kind != TOK_STAREQ() and mn.tok_kind != TOK_SLASHEQ() and mn.tok_kind != TOK_PERCENTEQ() and mn.tok_kind != TOK_DOT() and mn.tok_text != "." and mn.tok_kind != TOK_LBRACKET() and mn.tok_text != "[" and mn.tok_kind != TOK_LPAREN() and mn.tok_text != "(" and mn.tok_kind != TOK_NEWLINE() and mn.tok_kind != TOK_SEMI()
                is_match_stmt = 1
            end
        end
    if is_match_stmt == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        x86_synth_compile_expr(s, toks, pos_box)
        // Store scrutinee in anonymous stack slot so arms can freely evaluate patterns
        s.synth_stack_offset = s.synth_stack_offset + 8
        scrut_off = s.synth_stack_offset
        x86_synth_emit_store_var(s, 0, scrut_off)
        match_end_patches = list()

        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_pm = get(pos_box, 0)
            if cur_pm >= toks.len() break end
            ct_m = toks[cur_pm]
            if x86_synth_is_block_end(toks, cur_pm) == 1
                if ct_m.tok_span.span_start_col >= base_col
                    list_set(pos_box, 0, cur_pm + 1)
                end
                break
            end
            if ct_m.tok_span.span_start_line > base_line and ct_m.tok_span.span_start_col <= base_col break end
            arm_col = ct_m.tok_span.span_start_col
            arm_line = ct_m.tok_span.span_start_line
            if ct_m.tok_kind == TOK_KW_CASE() or (ct_m.tok_kind == TOK_IDENT() and (ct_m.tok_text == "case" or ct_m.tok_text == "ক্ষেত্র"))
                list_set(pos_box, 0, cur_pm + 1)
            end

            miss_patch = 0 - 1
            pat_p = get(pos_box, 0)
            if pat_p < toks.len() and (toks[pat_p].tok_text == "_" or toks[pat_p].tok_text == "default" or toks[pat_p].tok_text == "অন্যথায়" or toks[pat_p].tok_kind == TOK_KW_ELSE())
                list_set(pos_box, 0, pat_p + 1)
            else
                // Compile pattern -> %rsi, load scrutinee -> %rdi, call _lipi_cmp_dynamic (0 == equal)
                x86_synth_compile_expr(s, toks, pos_box)
                x86_synth_emit_bytes(s, [72, 137, 198])
                x86_synth_emit_load_var(s, 7, scrut_off)
                x86_synth_emit_call_helper(s, "_lipi_cmp_dynamic")
                x86_synth_emit_bytes(s, [133, 192, 15, 133]) // test eax, eax; jnz next_arm
                miss_patch = s.synth_code.len()
                x86_synth_emit_u32(s, 0)
            end

            if get(pos_box, 0) < toks.len()
                sep_k = toks[get(pos_box, 0)].tok_kind
                sep_txt = toks[get(pos_box, 0)].tok_text
                if sep_k == TOK_FAT_ARROW() or sep_k == TOK_COLON() or sep_k == TOK_ARROW() or sep_txt == "=>" or sep_txt == ":" or sep_txt == "->"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end

            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_span.span_start_line == arm_line and toks[get(pos_box, 0)].tok_kind != TOK_NEWLINE() and toks[get(pos_box, 0)].tok_kind != TOK_SEMI() and toks[get(pos_box, 0)].tok_kind != TOK_COMMENT_LINE()
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

    // ── 9e. Mutable Global Declaration: global / @global / বিশ্বজনীন ───────────
    if k == TOK_IDENT() and (txt == "global" or txt == "@global" or txt == "বিশ্বজনীন")
        if pos + 1 < toks.len() and x86_synth_is_ident_token(toks[pos + 1].tok_kind) == 1
            if toks[pos + 1].tok_text != "="
                g_name = toks[pos + 1].tok_text
                g_off = x86_synth_alloc_mutable_global(s, g_name)
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
                    x86_synth_emit_mutable_global_write(s, g_off)
                    g_prim = s.synth_last_expr_type
                    g_st = s.synth_last_struct
                    if g_ann_type == "int" or g_ann_type == "i64" or g_ann_type == "i32" or g_ann_type == "u64" or g_ann_type == "u32"
                        g_prim = "int"
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
                    if g_ann_type == "int" or g_ann_type == "i64" or g_ann_type == "i32" or g_ann_type == "u64" or g_ann_type == "u32"
                        g_p2 = "int"
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

    // ── 10. Assignment: <var> = <expr> or <var>: <type> = <expr> or <var> <op>= <expr> ───────────────────
    if x86_synth_is_ident_token(k) == 1
        var_name = txt
        assigned_type = ""
        next_pos = pos + 1
        // WHY: Support typed variable declarations: name: Type = expr
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_COLON() or (toks[next_pos].tok_kind != TOK_STR() and toks[next_pos].tok_text == ":"))
            type_pos = next_pos + 1
            if type_pos < toks.len() and x86_synth_is_ident_token(toks[type_pos].tok_kind) == 1
                after_type = type_pos + 1
                if after_type < toks.len() and (toks[after_type].tok_kind == TOK_ASSIGN() or (toks[after_type].tok_kind != TOK_STR() and toks[after_type].tok_text == "="))
                    assigned_type = toks[type_pos].tok_text
                    next_pos = after_type
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
                lv_mg_chk = x86_synth_find_local_var(s, var_name)
                mg_cur_off = x86_synth_find_mutable_global(s, var_name)
                is_mg_target = 0
                if (s.synth_in_function == 0 and x86_synth_is_mutable_global_name(var_name) == 1) or (lv_mg_chk == 0 and mg_cur_off >= 512)
                    is_mg_target = 1
                end
                if is_compound == 0
                    // Fast Path A & B: Direct 1-cycle in-register increment/accumulate for unspilled integer locals:
                    //   1) `x = x + k` or `x = x - k` (0 <= k <= 127) -> single `add/sub reg, imm8`
                    //   2) `x = x + (pure_int_expr)` -> evaluate `(expr)` into %rax, then single `add reg, rax`
                    if is_mg_target == 0 and assigned_type == "" and next_pos + 3 < toks.len()
                        lv_fast = x86_synth_find_local_var(s, var_name)
                        if lv_fast != 0 and lv_fast.lv_is_spilled == 0 and lv_fast.lv_reg >= 0 and lv_fast.lv_prim_type == "int"
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
                                            if lv_inner != 0 and (lv_inner.lv_prim_type == "str" or lv_inner.lv_prim_type == "float")
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

                    is_int_lit = 0
                    int_lit_val = 0
                    if next_pos + 1 < toks.len()
                        rhs_tok = toks[next_pos + 1]
                        if rhs_tok.tok_kind == TOK_INT()
                            after_rhs = next_pos + 2
                            if after_rhs >= toks.len() or toks[after_rhs].tok_kind == TOK_NEWLINE() or toks[after_rhs].tok_kind == TOK_SEMI()
                                is_int_lit = 1
                                int_lit_val = rhs_tok.tok_int_val
                    list_set(pos_box, 0, next_pos + 1) // Consume ident [ : type ] and '='
                    x86_synth_compile_expr(s, toks, pos_box)
                    if is_mg_target == 1
                        mg_slot = x86_synth_alloc_mutable_global(s, var_name)
                        x86_synth_emit_mutable_global_write(s, mg_slot)
                        mg_p = s.synth_last_expr_type
                        mg_st = s.synth_last_struct
                        if assigned_type == "int" or assigned_type == "i64" or assigned_type == "i32" or assigned_type == "u64" or assigned_type == "u32"
                            mg_p = "int"
                        elif assigned_type == "float" or assigned_type == "f64" or assigned_type == "f32"
                            mg_p = "float"
                        elif assigned_type == "str" or assigned_type == "string"
                            mg_p = "str"
                        elif assigned_type != ""
                            mg_st = assigned_type
                        end
                        x86_synth_set_mutable_global_types(s, var_name, mg_p, mg_st)
                        return 0
                    end
                    off = x86_synth_bind_var(s, var_name)
                    if assigned_type != ""
                        x86_synth_set_var_type(s, var_name, assigned_type)
                        if assigned_type == "int" or assigned_type == "i64" or assigned_type == "i32" or assigned_type == "u64" or assigned_type == "u32"
                            x86_synth_set_prim_type(s, var_name, "int")
                        elif assigned_type == "float" or assigned_type == "f64" or assigned_type == "f32"
                            x86_synth_set_prim_type(s, var_name, "float")
                        elif assigned_type == "str" or assigned_type == "string"
                            x86_synth_set_prim_type(s, var_name, "str")
                    if is_int_lit == 1
                        if s.synth_in_function == 0
                            x86_synth_set_global_const(s, var_name, int_lit_val)
                        end
                        x86_synth_set_prim_type(s, var_name, "int")
                    elif s.synth_last_expr_type == "int"
                        x86_synth_set_prim_type(s, var_name, "int")
                    elif s.synth_last_expr_type == "float"
                        x86_synth_set_prim_type(s, var_name, "float")
                    elif s.synth_last_expr_type == "str"
                        x86_synth_set_prim_type(s, var_name, "str")
                    elif assigned_type == ""
                        x86_synth_set_prim_type(s, var_name, "")
                    return 0
                else
                    // Compound assignment: target += expr, target -= expr, etc.
                    list_set(pos_box, 0, next_pos + 1) // Consume ident and op=
                    // Evaluate RHS expression into %rax
                    x86_synth_compile_expr(s, toks, pos_box)
                    rhs_comp_type = s.synth_last_expr_type
                    // mov rcx, rax (save RHS in rcx)
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 193)
                    // Load current value of target var into %rax
                    lv_tgt = x86_synth_find_local_var(s, var_name)
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
                        pt = x86_synth_get_prim_type(s, var_name)
                    end
                    res_comp_prim = pt
                    if (pt == "float" or rhs_comp_type == "float") and comp_op != TOK_PERCENT()
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
                        if (pt == "int" or rhs_comp_type == "int") and pt != "str" and rhs_comp_type != "str"
                            // Native hardware add rax, rcx (0x48 0x01 0xC8) - 1 cycle silicon execution!
                            x86_synth_emit_byte(s, 72)
                            x86_synth_emit_byte(s, 1)
                            x86_synth_emit_byte(s, 200)
                            res_comp_prim = "int"
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
                        // Zero-guarded cqo; idiv rcx
                        x86_synth_emit_bytes(s, [72, 133, 201, 117, 4, 49, 192, 235, 5, 72, 153, 72, 247, 249])
                    elif comp_op == TOK_PERCENT()
                        // Zero-guarded cqo; idiv rcx; mov rax, rdx
                        x86_synth_emit_bytes(s, [72, 133, 201, 117, 4, 49, 192, 235, 8, 72, 153, 72, 247, 249, 72, 137, 208])
                    end
                    // Store updated value back to target
                    if is_mg_target == 1
                        x86_synth_emit_mutable_global_write(s, mg_cur_off)
                        x86_synth_set_mutable_global_types(s, var_name, res_comp_prim, x86_synth_get_mutable_global_struct(s, var_name))
                    else
                        x86_synth_set_prim_type(s, var_name, res_comp_prim)
                        if lv_tgt != 0 and lv_tgt.lv_is_spilled == 0 and lv_tgt.lv_reg >= 0
                            // WHY: Update physical register directly and keep stack slot synchronized.
                            x86_synth_emit_mov_reg_reg(s, lv_tgt.lv_reg, 0)
                            x86_synth_emit_store_var(s, 0, off)
                        else
                            x86_synth_emit_store_var(s, 0, off)
                        end
                    end
                    return 0

    // ── 11. Function & Component Definition: fn / কাজ / @fn / component / উপাদান ──
    is_fn = 0
    if k == TOK_KW_FN() or k == TOK_DIR_FN() or k == TOK_KW_COMPONENT()
        is_fn = 1
    if k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn" or txt == "component" or txt == "উপাদান")
        is_fn = 1

    if is_fn == 1
        return x86_synth_compile_fn_def(s, toks, pos_box)

    // Default: evaluate expression or advance token with strict forward progress guarantee
    before_expr_p = get(pos_box, 0)
    x86_synth_compile_expr(s, toks, pos_box)
    if get(pos_box, 0) <= before_expr_p
        list_set(pos_box, 0, before_expr_p + 1)
    return 0
