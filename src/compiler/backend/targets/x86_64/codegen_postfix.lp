// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ Module: src/compiler/backend/targets/x86_64/codegen_postfix.lp
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Enforces Golden 35KB File Size Rule:
//    - Extracts postfix chaining expressions (bracket indexing, dot field/method access,
//      and error-propagation queries) into a dedicated modular subsystem.
// 2. Direct Hardware Postfix Traversal:
//    - Translates [index] to optimized _lipi_list_get calls.
//    - Translates .field directly to 1-cycle AMD64 memory offsets [rax + disp].
//    - Translates .method(...) to ABI argument passing and direct call relocations.
// ==============================================================================

fn x86_synth_expr_postfix s toks pos_box
    // WHY: Evaluates postfix chained expressions on %rax (e.g. obj[idx], obj.field, obj.method(...), obj?)
    cont_postfix = 1
    while cont_postfix == 1 and get(pos_box, 0) < toks.len()
        post_p = get(pos_box, 0)
        ptok = toks[post_p]
        pkind = ptok.tok_kind
        ptxt = ptok.tok_text

        // Case A: Bracket Indexing: obj[index] (or typed pointer p[index])
        if pkind == TOK_LBRACKET() or (pkind != TOK_STR() and ptxt == "[")
            list_set(pos_box, 0, post_p + 1) // Consume '['
            arr_el_t = s.synth_last_elem_type
            base_ptr_t = s.synth_last_struct
            raw_info = x86_synth_parse_raw_elem_tag(arr_el_t)
            x86_synth_emit_byte(s, 80)        // push rax (save collection/buffer ptr)
            x86_synth_compile_expr(s, toks, pos_box) // rax = index
            cp = get(pos_box, 0)
            if cp < toks.len() and (toks[cp].tok_kind == TOK_RBRACKET() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "]"))
                list_set(pos_box, 0, cp + 1) // Consume ']'
            // mov rsi, rax (index)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 198)
            x86_synth_emit_byte(s, 95)        // pop rdi (collection/buffer ptr)
            if raw_info[0] > 0
                // Direct inline fixed-size / @bss array load: [rdi + rsi * scale] (zero heap call!)
                x86_synth_emit_raw_array_load(s, raw_info[0], raw_info[1])
                if raw_info[1] == 0
                    s.synth_last_expr_type = "uint"
                else
                    s.synth_last_expr_type = "int"
                end
                s.synth_last_struct = ""
            elif x86_synth_is_ptr_type(base_ptr_t) == 1
                // WHY: Typed pointer indexing `p[i]` scales by `sizeof(T)` and loads exact element width!
                pt_el = x86_synth_ptr_pointee(base_ptr_t)
                x86_synth_emit_null_check_rdi(s)
                if x86_synth_find_struct(s, pt_el) != 0
                    pt_sz = x86_synth_sizeof_type(s, pt_el)
                    if pt_sz > 1
                        // imul rsi, rsi, pt_sz (48 69 F6 <u32>)
                        x86_synth_emit_bytes(s, [72, 105, 246])
                        x86_synth_emit_u32(s, pt_sz)
                    end
                    // lea rax, [rdi + rsi] (48 8D 04 37)
                    x86_synth_emit_bytes(s, [72, 141, 4, 55])
                    s.synth_last_struct = pt_el
                    s.synth_last_expr_type = ""
                else
                    pt_info = x86_synth_type_layout_info(s, pt_el)
                    x86_synth_emit_raw_array_load(s, pt_info[0], pt_info[3])
                    if pt_el == "float" or pt_el == "f64" or pt_el == "f32"
                        s.synth_last_expr_type = "float"
                        s.synth_last_struct = ""
                    elif x86_synth_is_ptr_type(pt_el) == 1
                        s.synth_last_expr_type = "uint"
                        s.synth_last_struct = pt_el
                    elif pt_info[3] == 0
                        s.synth_last_expr_type = "uint"
                        s.synth_last_struct = ""
                    else
                        s.synth_last_expr_type = "int"
                        s.synth_last_struct = ""
                    end
                end
            else
                x86_synth_emit_null_check_rdi(s)
                x86_synth_emit_call_helper(s, "_lipi_list_get")
                if arr_el_t == "float" or arr_el_t == "int" or arr_el_t == "uint" or arr_el_t == "str"
                    s.synth_last_expr_type = arr_el_t
                    s.synth_last_struct = ""
                elif arr_el_t == "dyn_dict"
                    s.synth_last_expr_type = "dyn_tagged"
                    s.synth_last_struct = ""
                elif arr_el_t != ""
                    s.synth_last_expr_type = ""
                    s.synth_last_struct = arr_el_t
                else
                    s.synth_last_expr_type = "dyn_tagged"
                    s.synth_last_struct = ""
                end
            end
            s.synth_last_elem_type = ""

        // Case B: Dot Member Access or Method Call: obj.member or obj.method(...)
        elif pkind == TOK_DOT() or (pkind != TOK_STR() and ptxt == ".")
            list_set(pos_box, 0, post_p + 1) // Consume '.'
            if get(pos_box, 0) < toks.len() and x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                fn_tok = toks[get(pos_box, 0)]
                member_name = fn_tok.tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume member name

                // Check if this is a true method call vs field closure call obj.cb(...)
                cp = get(pos_box, 0)
                is_method_paren = 0
                if cp < toks.len() and (toks[cp].tok_kind == TOK_LPAREN() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "("))
                    if member_name == "push" or member_name == "যোগ_করো" or member_name == "get" or member_name == "নাও" or member_name == "len" or member_name == "length" or member_name == "দৈর্ঘ্য" or member_name == "pop" or member_name == "বাদ_দাও" or member_name == "list_set" or member_name == "set" or member_name == "সেট" or member_name == "to_str" or member_name == "str" or member_name == "স্ট্রিং" or member_name == "restore_extract_single_file"
                        is_method_paren = 1
                    elif s.synth_last_struct != ""
                        chk_st_nm = s.synth_last_struct
                        if x86_synth_is_ptr_type(chk_st_nm) == 1
                            chk_st_nm = x86_synth_ptr_pointee(chk_st_nm)
                        end
                        if x86_synth_find_fn_first(s, chk_st_nm + "_" + member_name) != 0
                            is_method_paren = 1
                        else
                            sd_chk = x86_synth_find_struct(s, chk_st_nm)
                            has_fld_chk = 0
                            if sd_chk != 0
                                fci = 0
                                while fci < sd_chk.sd_fields.len()
                                    if sd_chk.sd_fields[fci] == member_name
                                        has_fld_chk = 1
                                        break
                                    end
                                    fci = fci + 1
                                end
                            end
                            if has_fld_chk == 0 and x86_synth_find_fn_first(s, member_name) != 0
                                is_method_paren = 1
                            end
                        end
                    elif x86_synth_find_fn_first(s, member_name) != 0
                        is_method_paren = 1
                    end
                end
                if is_method_paren == 1
                    list_set(pos_box, 0, cp + 1) // Consume '('
                    recv_struct = s.synth_last_struct
                    // Save obj ptr on stack as first argument (SysV %rdi)
                    x86_synth_emit_byte(s, 80) // push rax
                    m_args = 1
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    while get(pos_box, 0) < toks.len()
                        x86_synth_skip_whitespace_tokens(toks, pos_box)
                        cur_p = get(pos_box, 0)
                        if cur_p >= toks.len() or toks[cur_p].tok_kind == TOK_RPAREN() or (toks[cur_p].tok_kind != TOK_STR() and toks[cur_p].tok_text == ")")
                            break
                        x86_synth_compile_expr(s, toks, pos_box)
                        x86_synth_emit_byte(s, 80) // push rax
                        m_args = m_args + 1
                        x86_synth_skip_whitespace_tokens(toks, pos_box)
                        np = get(pos_box, 0)
                        if np < toks.len() and (toks[np].tok_kind == TOK_COMMA() or (toks[np].tok_kind != TOK_STR() and toks[np].tok_text == ","))
                            list_set(pos_box, 0, np + 1)

                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ")"))
                        list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

                    // Pop arguments into standard System V AMD64 ABI (6 regs + unlimited stack args)
                    m_cleanup = x86_synth_emit_pop_args(s, m_args)

                    if member_name == "push" or member_name == "যোগ_করো"
                        x86_synth_emit_call_helper(s, "_lipi_list_push")
                        s.synth_last_expr_type = ""
                    elif member_name == "get" or member_name == "নাও"
                        x86_synth_emit_call_helper(s, "_lipi_list_get")
                        s.synth_last_expr_type = ""
                    elif member_name == "len" or member_name == "length" or member_name == "দৈর্ঘ্য"
                        x86_synth_emit_call_helper(s, "_lipi_len")
                        s.synth_last_expr_type = "int"
                    elif member_name == "pop" or member_name == "বাদ_দাও"
                        x86_synth_emit_call_helper(s, "_lipi_list_pop")
                        s.synth_last_expr_type = ""
                    elif member_name == "list_set" or member_name == "set" or member_name == "সেট"
                        x86_synth_emit_call_helper(s, "_lipi_list_set")
                        s.synth_last_expr_type = ""
                    elif member_name == "to_str" or member_name == "str" or member_name == "স্ট্রিং"
                        x86_synth_emit_call_helper(s, "_lipi_ensure_str")
                        s.synth_last_expr_type = "str"
                    else
                        call_tgt = member_name
                        if recv_struct != ""
                            eff_recv = recv_struct
                            if x86_synth_is_ptr_type(eff_recv) == 1
                                eff_recv = x86_synth_ptr_pointee(eff_recv)
                            end
                            mangled_tgt = eff_recv + "_" + member_name
                            if x86_synth_find_fn_first(s, mangled_tgt) != 0
                                call_tgt = mangled_tgt
                            end
                        end
                        x86_synth_emit_call_helper(s, call_tgt)
                        s.synth_last_expr_type = ""
                        s.synth_last_struct = ""
                        s.synth_last_elem_type = ""
                        if member_name == "restore_extract_single_file"
                            s.synth_last_struct = "ExtractedSingleFile"
                        else
                            rt_m = x86_synth_lookup_fn_ret_type(s, call_tgt)
                            if rt_m == "float" or rt_m == "f64" or rt_m == "f32"
                                s.synth_last_expr_type = "float"
                            elif x86_synth_is_ptr_type(rt_m) == 1
                                s.synth_last_expr_type = "uint"
                                s.synth_last_struct = rt_m
                            elif x86_synth_is_uint_type(rt_m) == 1
                                s.synth_last_expr_type = "uint"
                            elif rt_m == "int" or rt_m == "i64" or rt_m == "i32" or rt_m == "i16" or rt_m == "i8"
                                s.synth_last_expr_type = "int"
                            elif rt_m == "str" or rt_m == "string"
                                s.synth_last_expr_type = "str"
                            elif rt_m == "dyn_tagged"
                                s.synth_last_expr_type = "dyn_tagged"
                            else
                                s.synth_last_struct = rt_m
                            end
                        end
                    x86_synth_emit_cleanup_stack_args(s, m_cleanup)
                else
                    // Struct / Union Field Read: obj.field (exact packed/aligned offset, bitfield extraction, or [N]T LEA)
                    fmeta = x86_synth_get_field_meta(s, s.synth_last_struct, member_name)
                    f_off = fmeta[0]
                    f_sz = fmeta[1]
                    f_sgn = fmeta[2]
                    f_el = fmeta[3]
                    ft = fmeta[4]
                    f_bo = 0
                    f_bw = 0
                    if fmeta.len() >= 7
                        f_bo = fmeta[5]
                        f_bw = fmeta[6]
                    end
                    s.synth_last_struct = ""
                    s.synth_last_expr_type = ""
                    s.synth_last_elem_type = ""
                    if f_el > 0
                        s.synth_last_elem_type = x86_synth_raw_elem_tag(f_el, f_sgn)
                        s.synth_last_expr_type = "int"
                    elif ft == "f64" or ft == "f32" or ft == "float"
                        s.synth_last_expr_type = "float"
                    elif x86_synth_is_ptr_type(ft) == 1
                        s.synth_last_expr_type = "uint"
                        s.synth_last_struct = ft
                    elif x86_synth_is_uint_type(ft) == 1
                        s.synth_last_expr_type = "uint"
                    elif ft == "int" or ft == "i64" or ft == "i32" or ft == "i16" or ft == "i8" or ft == "ptr"
                        s.synth_last_expr_type = "int"
                    elif ft == "str" or ft == "string"
                        s.synth_last_expr_type = "str"
                    elif ft != ""
                        s.synth_last_struct = ft
                    end
                    // Guard null / low-page struct pointer (< 4096) in hosted mode
                    x86_synth_emit_null_check_rax(s)
                    x86_synth_emit_field_load_rax(s, f_off, f_sz, f_sgn, f_el)
                    if f_bw > 0
                        x86_synth_emit_bitfield_extract_rax(s, f_bo, f_bw, f_sgn)
                    end
                end
            else
                cont_postfix = 0
        // Case C: Postfix Query '?' — Sovereign ADT (Result/Option) unwrap & early return + legacy 0-guard
        // WHY: If %rax is an ADT0 cell ([rax+16]==0x41445430): tag==0 (Ok/Some) unwraps [rax+24] & 2-bit
        // payload tag into %rdx; tag!=0 (Err/None) pops try frames, runs defers, and returns the Err/None cell!
        // For non-ADT values, preserves 100% backwards-compatible `test rax, rax; jz early_ret` behavior.
        elif pkind == TOK_QUERY() or (pkind != TOK_STR() and ptxt == "?")
            list_set(pos_box, 0, post_p + 1) // Consume '?'
            // cmp rax, 4096; jb .q_not_adt
            x86_synth_emit_bytes(s, [72, 61, 0, 16, 0, 0, 15, 130])
            q_not_adt_1 = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            // cmp dword ptr [rax + 16], 0x41445430 ('ADT0'); jne .q_not_adt
            x86_synth_emit_bytes(s, [129, 120, 16, 48, 84, 68, 65, 15, 133])
            q_not_adt_2 = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            // cmp qword ptr [rax + 0], 0; jne .q_early_ret (propagate Err/None cell in %rax!)
            x86_synth_emit_bytes(s, [72, 131, 56, 0, 15, 133])
            q_early_adt = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            // Ok/Some (tag == 0): mov edx, [rax + 20]; and edx, 3; mov rax, [rax + 24]; jmp .q_ok
            x86_synth_emit_bytes(s, [139, 80, 20, 131, 226, 3, 72, 139, 64, 24, 233])
            q_ok_adt = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            // .q_not_adt: xor edx, edx; test rax, rax; jne .q_ok
            not_adt_off = s.synth_code.len()
            x86_synth_patch_u32(s, q_not_adt_1, not_adt_off - (q_not_adt_1 + 4))
            x86_synth_patch_u32(s, q_not_adt_2, not_adt_off - (q_not_adt_2 + 4))
            x86_synth_emit_bytes(s, [49, 210, 72, 133, 192, 15, 133])
            q_ok_raw = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            // .q_early_ret:
            early_off = s.synth_code.len()
            x86_synth_patch_u32(s, q_early_adt, early_off - (q_early_adt + 4))
            if s.synth_try_depth > 0
                x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rax; sub rsp, 8
                ti_q = 0
                while ti_q < s.synth_try_depth
                    x86_synth_emit_call_helper(s, "_lipi_exc_pop")
                    ti_q = ti_q + 1
                end
                x86_synth_emit_bytes(s, [72, 131, 196, 8, 88]) // add rsp, 8; pop rax
            end
            x86_synth_emit_defers(s, toks)
            x86_synth_emit_epilogue(s)
            // .q_ok:
            q_ok_off = s.synth_code.len()
            x86_synth_patch_u32(s, q_ok_adt, q_ok_off - (q_ok_adt + 4))
            x86_synth_patch_u32(s, q_ok_raw, q_ok_off - (q_ok_raw + 4))
            s.synth_last_expr_type = "dyn_tagged"
            s.synth_last_struct = ""
            s.synth_last_elem_type = ""
            s.synth_last_store_end = 0 - 1
        // Case D: Postfix Indirect Call expr(...) — supports (make_adder(5))(10), arr[0](x), obj.cb(x)
        elif pkind == TOK_LPAREN() or (pkind != TOK_STR() and ptxt == "(")
            list_set(pos_box, 0, post_p + 1) // Consume '('
            s.synth_stack_offset = s.synth_stack_offset + 8
            callee_off = s.synth_stack_offset
            x86_synth_emit_store_var(s, 0, callee_off)
            c_args = 0
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            while get(pos_box, 0) < toks.len()
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cur_p = get(pos_box, 0)
                if cur_p >= toks.len() or toks[cur_p].tok_kind == TOK_RPAREN() or (toks[cur_p].tok_kind != TOK_STR() and toks[cur_p].tok_text == ")")
                    break
                x86_synth_compile_expr(s, toks, pos_box)
                x86_synth_emit_byte(s, 80) // push rax
                c_args = c_args + 1
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                np = get(pos_box, 0)
                if np < toks.len() and (toks[np].tok_kind == TOK_COMMA() or (toks[np].tok_kind != TOK_STR() and toks[np].tok_text == ","))
                    list_set(pos_box, 0, np + 1)
                end
            end
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ")"))
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'
            end
            c_cleanup = x86_synth_emit_pop_args(s, c_args)
            x86_synth_emit_load_var(s, 0, callee_off)
            x86_synth_emit_indirect_call_rax(s)
            x86_synth_emit_cleanup_stack_args(s, c_cleanup)
            s.synth_last_expr_type = ""
            s.synth_last_struct = ""
            s.synth_last_elem_type = ""
        else
            cont_postfix = 0
    return 0
