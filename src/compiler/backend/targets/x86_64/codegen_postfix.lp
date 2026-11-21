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

        // Case A: Bracket Indexing: obj[index]
        if pkind == TOK_LBRACKET() or (pkind != TOK_STR() and ptxt == "[")
            list_set(pos_box, 0, post_p + 1) // Consume '['
            arr_el_t = s.synth_last_elem_type
            x86_synth_emit_byte(s, 80)        // push rax (save collection ptr)
            x86_synth_compile_expr(s, toks, pos_box) // rax = index
            cp = get(pos_box, 0)
            if cp < toks.len() and (toks[cp].tok_kind == TOK_RBRACKET() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "]"))
                list_set(pos_box, 0, cp + 1) // Consume ']'
            // mov rsi, rax (index)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 198)
            x86_synth_emit_byte(s, 95)        // pop rdi (collection ptr)
            x86_synth_emit_call_helper(s, "_lipi_list_get")
            s.synth_last_expr_type = arr_el_t
            s.synth_last_struct = ""
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
                        if x86_synth_find_fn_first(s, s.synth_last_struct + "_" + member_name) != 0
                            is_method_paren = 1
                        else
                            sd_chk = x86_synth_find_struct(s, s.synth_last_struct)
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

                    m_abi_save = 0
                    if m_args >= 9
                        m_abi_save = x86_synth_emit_save_r12_r15(s)
                    end
                    // Pop arguments in reverse into LiPi 12-register calling convention
                    x86_synth_emit_pop_args(s, m_args)

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
                            mangled_tgt = recv_struct + "_" + member_name
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
                            elif rt_m == "int" or rt_m == "i64" or rt_m == "i32" or rt_m == "u64" or rt_m == "u32"
                                s.synth_last_expr_type = "int"
                            elif rt_m == "str" or rt_m == "string"
                                s.synth_last_expr_type = "str"
                            else
                                s.synth_last_struct = rt_m
                            end
                        end
                    if m_abi_save != 0
                        x86_synth_emit_restore_r12_r15(s, m_abi_save)
                    end
                else
                    // Struct Field Read: obj.field
                    f_off = x86_synth_get_field_offset(s, s.synth_last_struct, member_name)
                    ft = x86_synth_get_field_type(s, s.synth_last_struct, member_name)
                    s.synth_last_struct = ""
                    s.synth_last_expr_type = ""
                    if ft == "f64" or ft == "f32" or ft == "float"
                        s.synth_last_expr_type = "float"
                    elif ft == "int" or ft == "i64" or ft == "i32" or ft == "u64" or ft == "u32"
                        s.synth_last_expr_type = "int"
                    elif ft == "str" or ft == "string"
                        s.synth_last_expr_type = "str"
                    elif ft != ""
                        s.synth_last_struct = ft
                    end
                    if f_off < 128
                        // mov rax, [rax + f_off]: 0x48 0x8B 0x40 disp8
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 139)
                        x86_synth_emit_byte(s, 64)
                        x86_synth_emit_byte(s, f_off)
                    else
                        // mov rax, [rax + f_off]: 0x48 0x8B 0x80 disp32
                        x86_synth_emit_byte(s, 72)
                        x86_synth_emit_byte(s, 139)
                        x86_synth_emit_byte(s, 128)
                        x86_synth_emit_u32(s, f_off)
            else
                cont_postfix = 0
        // Case C: Postfix Query '?' (Error propagation / Early return on 0 with full epilogue & unwind)
        elif pkind == TOK_QUERY() or (pkind != TOK_STR() and ptxt == "?")
            list_set(pos_box, 0, post_p + 1) // Consume '?'
            // test rax, rax
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 133)
            x86_synth_emit_byte(s, 192)
            // jne ok_label (0x0F 0x85 rel32)
            x86_synth_emit_byte(s, 15)
            x86_synth_emit_byte(s, 133)
            q_patch = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
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
            q_ok_off = s.synth_code.len()
            x86_synth_patch_u32(s, q_patch, q_ok_off - (q_patch + 4))
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
            c_abi_save = 0
            if c_args >= 9
                c_abi_save = x86_synth_emit_save_r12_r15(s)
            end
            x86_synth_emit_pop_args(s, c_args)
            x86_synth_emit_load_var(s, 0, callee_off)
            x86_synth_emit_indirect_call_rax(s)
            if c_abi_save != 0
                x86_synth_emit_restore_r12_r15(s, c_abi_save)
            end
            s.synth_last_expr_type = ""
            s.synth_last_struct = ""
            s.synth_last_elem_type = ""
        else
            cont_postfix = 0
    return 0
