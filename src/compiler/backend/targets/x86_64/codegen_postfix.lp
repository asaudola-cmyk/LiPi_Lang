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
            s.synth_last_expr_type = ""

        // Case B: Dot Member Access or Method Call: obj.member or obj.method(...)
        elif pkind == TOK_DOT() or (pkind != TOK_STR() and ptxt == ".")
            list_set(pos_box, 0, post_p + 1) // Consume '.'
            if get(pos_box, 0) < toks.len() and x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                fn_tok = toks[get(pos_box, 0)]
                member_name = fn_tok.tok_text
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume member name

                // Check if this is a method call: obj.name(...)
                cp = get(pos_box, 0)
                if cp < toks.len() and (toks[cp].tok_kind == TOK_LPAREN() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "("))
                    list_set(pos_box, 0, cp + 1) // Consume '('
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
                        x86_synth_emit_call_helper(s, member_name)
                        s.synth_last_expr_type = ""
                else
                    // Struct Field Read: obj.field
                    f_off = x86_synth_get_field_offset(s, s.synth_last_struct, member_name)
                    s.synth_last_struct = ""
                    s.synth_last_expr_type = ""
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
        // Case C: Postfix Query '?' (Error propagation / Early return on 0)
        elif pkind == TOK_QUERY() or (pkind != TOK_STR() and ptxt == "?")
            list_set(pos_box, 0, post_p + 1) // Consume '?'
            // test rax, rax
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 133)
            x86_synth_emit_byte(s, 192)
            // jne +5 (skip 5-byte epilogue if rax != 0)
            x86_synth_emit_byte(s, 117)
            x86_synth_emit_byte(s, 5)
            // Function epilogue: mov rsp, rbp; pop rbp; ret
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 236)
            x86_synth_emit_byte(s, 93)
            x86_synth_emit_byte(s, 195)
        else
            cont_postfix = 0
    return 0
