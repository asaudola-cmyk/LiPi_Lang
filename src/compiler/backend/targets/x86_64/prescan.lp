// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 SIGNATURE PRESCAN PASS (prescan.lp)
// ⚡ Module: src/compiler/backend/targets/x86_64/prescan.lp
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// ==============================================================================
//
// WHY THIS MODULE:
// Pre-populates X86Function signatures (parameter counts and conservative explicit
// or inferred return types) prior to sequential codegen so forward calls,
// floating-point return type propagation, and bare function-pointer values
// resolve accurately regardless of declaration order.
// ==============================================================================

fn x86_synth_find_prescan_stub s name decl_line
    // WHY: Locates an uncompiled pre-scanned X86Function entry via O(1) hash bucket lookup.
    if s.synth_fn_buckets.len() == 4096
        ent = s.synth_fn_buckets[x86_synth_hash4096(name)]
        if ent == 0
            return 0 - 1
        end
        bi = 0
        while bi < ent.len()
            idx = ent[bi]
            fn_item = s.synth_functions[idx]
            if fn_item.fn_name == name and fn_item.fn_entry_offset == (0 - 1) and fn_item.fn_decl_line == decl_line
                return idx
            end
            bi = bi + 1
        end
        return 0 - 1
    end
    return 0 - 1

fn x86_synth_prescan_signatures s tokens
    // WHY: Pre-populates X86Function metadata (param_count, explicit/inferred return types)
    // before sequential codegen so forward calls, float propagation, and fn pointers work out-of-order.
    n = tokens.len()
    i = 0
    while i < n
        t = tokens[i]
        k = t.tok_kind
        txt = t.tok_text
        is_fn = 0
        if k == TOK_KW_FN() or k == TOK_DIR_FN() or k == TOK_KW_COMPONENT()
            is_fn = 1
        elif k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn" or txt == "component" or txt == "উপাদান")
            is_fn = 1
        end
        if is_fn == 1 and (i + 1) < n and tokens[i + 1].tok_kind == TOK_IDENT()
            base_col = t.tok_span.span_start_col
            base_line = t.tok_span.span_start_line
            fn_name = tokens[i + 1].tok_text
            method_alias = ""
            p = i + 2
            if p + 1 < n and (tokens[p].tok_kind == TOK_DOT() or (tokens[p].tok_kind != TOK_STR() and tokens[p].tok_text == ".")) and tokens[p + 1].tok_kind == TOK_IDENT()
                method_alias = tokens[p + 1].tok_text
                fn_name = fn_name + "_" + method_alias
                p = p + 2
            end
            pcount = 0
            fparams = list()
            has_paren = 0
            if p < n and (tokens[p].tok_kind == TOK_LPAREN() or (tokens[p].tok_kind != TOK_STR() and tokens[p].tok_text == "("))
                has_paren = 1
                p = p + 1
            end
            while p < n
                pk = tokens[p].tok_kind
                ptxt = tokens[p].tok_text
                if has_paren == 1
                    if pk == TOK_NEWLINE() or pk == TOK_SEMI() or pk == TOK_COMMENT_LINE() or pk == TOK_COMMENT_DOC() or pk == TOK_COMMENT_BLOCK()
                        p = p + 1
                        continue
                    end
                    if pk == TOK_RPAREN() or (pk != TOK_STR() and ptxt == ")")
                        p = p + 1
                        break
                    end
                else
                    if pk == TOK_ASSIGN() or pk == TOK_ARROW() or pk == TOK_NEWLINE() or pk == TOK_SEMI() or (pk != TOK_STR() and (ptxt == "=" or ptxt == "->" or ptxt == ";" or ptxt == "{" or ptxt == ":"))
                        if pk == TOK_NEWLINE() or pk == TOK_SEMI()
                            p = p + 1
                        end
                        break
                    end
                end
                if x86_synth_is_ident_token(pk) == 1
                    pname_ps = ptxt
                    pcount = pcount + 1
                    p = p + 1
                    while has_paren == 1 and p < n and (tokens[p].tok_kind == TOK_NEWLINE() or tokens[p].tok_kind == TOK_COMMENT_LINE())
                        p = p + 1
                    end
                    if p < n and (tokens[p].tok_kind == TOK_COLON() or (tokens[p].tok_kind != TOK_STR() and tokens[p].tok_text == ":"))
                        p = p + 1
                        while has_paren == 1 and p < n and tokens[p].tok_kind == TOK_NEWLINE()
                            p = p + 1
                        end
                        if p < n and x86_synth_is_ident_token(tokens[p].tok_kind) == 1
                            pt_ps = tokens[p].tok_text
                            if pt_ps == "float" or pt_ps == "f64" or pt_ps == "f32"
                                push(fparams, pname_ps)
                            end
                            p = p + 1
                        end
                    end
                    while has_paren == 1 and p < n and tokens[p].tok_kind == TOK_NEWLINE()
                        p = p + 1
                    end
                    if p < n and (tokens[p].tok_kind == TOK_COMMA() or (tokens[p].tok_kind != TOK_STR() and tokens[p].tok_text == ","))
                        p = p + 1
                    end
                else
                    p = p + 1
                end
            end
            while p < n and (tokens[p].tok_kind == TOK_NEWLINE() or tokens[p].tok_kind == TOK_COMMENT_LINE())
                p = p + 1
            end
            ret_t = ""
            if p < n and (tokens[p].tok_kind == TOK_ARROW() or tokens[p].tok_kind == TOK_COLON() or (tokens[p].tok_kind != TOK_STR() and (tokens[p].tok_text == "->" or tokens[p].tok_text == ":")))
                p = p + 1
                while p < n and tokens[p].tok_kind == TOK_NEWLINE()
                    p = p + 1
                end
                if p < n and (x86_synth_is_ident_token(tokens[p].tok_kind) == 1 or tokens[p].tok_kind == TOK_IDENT())
                    ret_t = tokens[p].tok_text
                    p = p + 1
                end
            end
            if ret_t == ""
                // Conservative lookahead across return expressions up to block end
                saw_float = 0
                saw_nonfloat = 0
                bp = p
                brace_d = 0
                if bp < n and (tokens[bp].tok_kind == TOK_ASSIGN() or (tokens[bp].tok_kind != TOK_STR() and tokens[bp].tok_text == "="))
                    bp = bp + 1
                    while bp < n and tokens[bp].tok_kind != TOK_NEWLINE() and tokens[bp].tok_kind != TOK_SEMI() and tokens[bp].tok_kind != TOK_EOF()
                        if tokens[bp].tok_kind == TOK_FLOAT()
                            saw_float = 1
                        elif tokens[bp].tok_kind == TOK_STR()
                            saw_nonfloat = 1
                        end
                        bp = bp + 1
                    end
                else
                    while bp < n
                        bt = tokens[bp]
                        bk = bt.tok_kind
                        btxt = bt.tok_text
                        if bk == TOK_EOF()
                            break
                        end
                        if bk == TOK_LBRACE() or (bk != TOK_STR() and btxt == "{")
                            brace_d = brace_d + 1
                        elif bk == TOK_RBRACE() or (bk != TOK_STR() and btxt == "}")
                            brace_d = brace_d - 1
                            if brace_d <= 0
                                break
                            end
                        end
                        if brace_d == 0
                            if (bk == TOK_KW_END() or bk == TOK_DIR_END() or (bk == TOK_IDENT() and (btxt == "end" or btxt == "শেষ" or btxt == "@end"))) and bt.tok_span.span_start_col <= base_col
                                if bp + 1 >= n or (tokens[bp + 1].tok_kind != TOK_ASSIGN() and tokens[bp + 1].tok_text != "=")
                                    break
                                end
                            end
                            if (bk == TOK_KW_FN() or bk == TOK_DIR_FN()) and bt.tok_span.span_start_line > base_line and bt.tok_span.span_start_col <= base_col
                                break
                            end
                            if bt.tok_span.span_start_line > base_line and bt.tok_span.span_start_col <= base_col and bk != TOK_NEWLINE() and bk != TOK_SEMI() and bk != TOK_COMMENT_LINE() and bk != TOK_COMMENT_DOC() and bk != TOK_COMMENT_BLOCK()
                                if bk != TOK_KW_ELIF() and bk != TOK_KW_ELSE() and bk != TOK_DIR_ELIF() and bk != TOK_DIR_ELSE() and bk != TOK_DIR_END() and bk != TOK_KW_END() and btxt != "elif" and btxt != "else" and btxt != "অথবা" and btxt != "নাহলে"
                                    break
                                end
                            end
                        end
                        if bk == TOK_KW_RETURN() or (bk == TOK_IDENT() and (btxt == "return" or btxt == "ফিরে_যাও"))
                            rp = bp + 1
                            arm_fl = 0
                            arm_str = 0
                            arm_toks = 0
                            while rp < n and tokens[rp].tok_kind != TOK_NEWLINE() and tokens[rp].tok_kind != TOK_SEMI() and tokens[rp].tok_kind != TOK_EOF()
                                rk = tokens[rp].tok_kind
                                rtxt = tokens[rp].tok_text
                                if rk == TOK_RBRACE() or rk == TOK_KW_END() or rk == TOK_DIR_END() or rtxt == "}" or rtxt == "end" or rtxt == "@end"
                                    break
                                end
                                arm_toks = arm_toks + 1
                                if rk == TOK_FLOAT()
                                    arm_fl = 1
                                elif rk == TOK_STR()
                                    arm_str = 1
                                elif rk == TOK_IDENT()
                                    fi = 0
                                    while fi < fparams.len()
                                        if fparams[fi] == rtxt
                                            arm_fl = 1
                                            break
                                        end
                                        fi = fi + 1
                                    end
                                end
                                rp = rp + 1
                            end
                            if arm_fl == 1 and arm_str == 0
                                saw_float = 1
                            elif arm_toks > 0
                                saw_nonfloat = 1
                            end
                        end
                        bp = bp + 1
                    end
                end
                if saw_float == 1 and saw_nonfloat == 0
                    ret_t = "f64"
                end
            end
            fe = X86Function()
            fe.fn_name = fn_name
            fe.fn_entry_offset = 0 - 1
            fe.fn_ret_type = ret_t
            fe.fn_end_offset = 0
            fe.fn_decl_line = base_line
            fe.fn_param_count = pcount
            x86_synth_register_fn_obj(s, fe)
            if method_alias != ""
                fa = X86Function()
                fa.fn_name = method_alias
                fa.fn_entry_offset = 0 - 1
                fa.fn_ret_type = ret_t
                fa.fn_end_offset = 0
                fa.fn_decl_line = base_line
                fa.fn_param_count = pcount
                x86_synth_register_fn_obj(s, fa)
            end
            i = p
            continue
        end
        i = i + 1
    end
    return 0
