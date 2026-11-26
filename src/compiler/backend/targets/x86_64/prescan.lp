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
    // WHY: Pre-populates declared struct names and X86Function metadata (param_count, explicit or
    // inferred float/struct return types) before sequential codegen so forward calls,
    // float propagation, zero-collision struct access, and bare fn pointers work out-of-order.
    n = tokens.len()
    known_structs = list()
    si_ps = 0
    while si_ps + 1 < n
        st_ps = tokens[si_ps]
        sk_ps = st_ps.tok_kind
        sx_ps = st_ps.tok_text
        if sk_ps == TOK_KW_STRUCT() or sk_ps == TOK_DIR_STRUCT() or (sk_ps == TOK_IDENT() and (sx_ps == "struct" or sx_ps == "গঠন" or sx_ps == "@struct" or sx_ps == "union" or sx_ps == "ইউনিয়ন" or sx_ps == "@union"))
            if tokens[si_ps + 1].tok_kind == TOK_IDENT()
                push(known_structs, tokens[si_ps + 1].tok_text)
            end
        elif sk_ps == TOK_KW_ENUM() or sk_ps == TOK_DIR_ENUM() or (sk_ps == TOK_IDENT() and (sx_ps == "enum" or sx_ps == "@enum" or sx_ps == "গণনা"))
            ep_box = [si_ps]
            x86_synth_register_enum_from_tokens(s, tokens, ep_box, st_ps.tok_span.span_start_col, st_ps.tok_span.span_start_line)
            if get(ep_box, 0) > si_ps
                si_ps = get(ep_box, 0)
                continue
            end
        end
        si_ps = si_ps + 1
    end
    impl_ctx_ps = ""
    impl_end_col = 0
    impl_brace_d = 0
    impl_is_braced = 0
    i = 0
    while i < n
        t = tokens[i]
        k = t.tok_kind
        txt = t.tok_text
        // Skip entire `trait` declaration blocks so trait method signatures aren't registered as functions!
        if (k == TOK_DIR_TRAIT() or (k == TOK_IDENT() and (txt == "trait" or txt == "বৈশিষ্ট্য" or txt == "@trait"))) and (i + 1) < n and tokens[i + 1].tok_kind == TOK_IDENT()
            tr_col = t.tok_span.span_start_col
            tr_line = t.tok_span.span_start_line
            i = i + 2
            tr_bd = 0
            tr_saw_b = 0
            while i < n
                tt = tokens[i]
                if tt.tok_kind == TOK_EOF() break end
                if tt.tok_kind == TOK_LBRACE() or (tt.tok_kind != TOK_STR() and tt.tok_text == "{")
                    tr_bd = tr_bd + 1
                    tr_saw_b = 1
                elif tt.tok_kind == TOK_RBRACE() or (tt.tok_kind != TOK_STR() and tt.tok_text == "}")
                    if tr_bd > 0
                        tr_bd = tr_bd - 1
                        if tr_bd == 0 and tr_saw_b == 1
                            i = i + 1
                            break
                        end
                    end
                elif tr_saw_b == 0
                    if x86_synth_is_block_end(tokens, i) == 1 and tt.tok_span.span_start_col <= tr_col
                        i = i + 1
                        break
                    end
                    if tt.tok_span.span_start_line > tr_line and tt.tok_span.span_start_col <= tr_col and tt.tok_kind != TOK_NEWLINE()
                        break
                    end
                end
                i = i + 1
            end
            continue
        end
        // Track `impl [Trait for] Type { ... }` context so methods get prescanned as `Type_method`!
        if (k == TOK_KW_IMPL() or k == TOK_DIR_IMPL() or (k == TOK_IDENT() and (txt == "impl" or txt == "বাস্তবায়ন" or txt == "@impl"))) and (i + 1) < n
            imp_p = i + 1
            // Optional generic params `<T>`
            if imp_p < n and tokens[imp_p].tok_text == "<"
                imp_pb = [imp_p]
                x86_synth_parse_type_list(tokens, imp_pb, 0)
                imp_p = get(imp_pb, 0)
            end
            if imp_p < n and tokens[imp_p].tok_kind == TOK_IDENT()
                f_nm = tokens[imp_p].tok_text
                imp_p = imp_p + 1
                if imp_p < n and tokens[imp_p].tok_text == "<"
                    imp_pb2 = [imp_p]
                    x86_synth_parse_type_list(tokens, imp_pb2, 0)
                    imp_p = get(imp_pb2, 0)
                end
                imp_type = f_nm
                if imp_p < n and (tokens[imp_p].tok_kind == TOK_KW_FOR() or tokens[imp_p].tok_text == "for" or tokens[imp_p].tok_text == "জন্য")
                    imp_p = imp_p + 1
                    if imp_p < n and tokens[imp_p].tok_kind == TOK_IDENT()
                        imp_type = tokens[imp_p].tok_text
                        imp_p = imp_p + 1
                    end
                    if imp_p < n and tokens[imp_p].tok_text == "<"
                        imp_pb3 = [imp_p]
                        x86_synth_parse_type_list(tokens, imp_pb3, 0)
                        imp_p = get(imp_pb3, 0)
                    end
                end
                impl_ctx_ps = imp_type
                impl_end_col = t.tok_span.span_start_col
                impl_is_braced = 0
                impl_brace_d = 0
                while imp_p < n and tokens[imp_p].tok_kind == TOK_NEWLINE()
                    imp_p = imp_p + 1
                end
                if imp_p < n and (tokens[imp_p].tok_kind == TOK_LBRACE() or tokens[imp_p].tok_text == "{")
                    impl_is_braced = 1
                    impl_brace_d = 1
                    imp_p = imp_p + 1
                end
                i = imp_p
                continue
            end
        end
        if impl_ctx_ps != ""
            if impl_is_braced == 1
                if k == TOK_LBRACE() or (k != TOK_STR() and txt == "{")
                    impl_brace_d = impl_brace_d + 1
                elif k == TOK_RBRACE() or (k != TOK_STR() and txt == "}")
                    impl_brace_d = impl_brace_d - 1
                    if impl_brace_d <= 0
                        impl_ctx_ps = ""
                        impl_is_braced = 0
                        i = i + 1
                        continue
                    end
                end
            else
                if x86_synth_is_block_end(tokens, i) == 1 and t.tok_span.span_start_col <= impl_end_col
                    impl_ctx_ps = ""
                    i = i + 1
                    continue
                elif t.tok_span.span_start_col <= impl_end_col and k != TOK_NEWLINE() and k != TOK_COMMENT_LINE() and k != TOK_COMMENT_BLOCK()
                    impl_ctx_ps = ""
                end
            end
        end
        // Skip `extern fn name(...) -> ret` forward declarations (no function body)
        if k == TOK_IDENT() and (txt == "extern" or txt == "বাহ্যিক") and (i + 1) < n
            ext_line = t.tok_span.span_start_line
            i = i + 1
            while i < n and tokens[i].tok_kind != TOK_NEWLINE() and tokens[i].tok_kind != TOK_SEMI() and tokens[i].tok_span.span_start_line == ext_line
                i = i + 1
            end
            continue
        end
        is_fn = 0
        is_async_ps = 0
        orig_fn_col_ps = t.tok_span.span_start_col
        if (k == TOK_KW_ASYNC() or (k == TOK_IDENT() and (txt == "async" or txt == "@async" or txt == "অসমলয়"))) and (i + 1) < n
            nt_a = tokens[i + 1]
            nk_a = nt_a.tok_kind
            nx_a = nt_a.tok_text
            if nk_a == TOK_KW_FN() or nk_a == TOK_DIR_FN() or (nk_a == TOK_IDENT() and (nx_a == "fn" or nx_a == "কাজ" or nx_a == "@fn"))
                is_async_ps = 1
                i = i + 1
                t = tokens[i]
                k = t.tok_kind
                txt = t.tok_text
            end
        end
        if k == TOK_KW_FN() or k == TOK_DIR_FN() or k == TOK_KW_COMPONENT()
            is_fn = 1
        elif k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn" or txt == "component" or txt == "উপাদান")
            is_fn = 1
        end
        if is_fn == 1 and (i + 1) < n and tokens[i + 1].tok_kind == TOK_IDENT()
            base_col = orig_fn_col_ps
            base_line = t.tok_span.span_start_line
            fn_name = tokens[i + 1].tok_text
            method_alias = ""
            p = i + 2
            if p + 1 < n and (tokens[p].tok_kind == TOK_DOT() or (tokens[p].tok_kind != TOK_STR() and tokens[p].tok_text == ".")) and tokens[p + 1].tok_kind == TOK_IDENT()
                method_alias = tokens[p + 1].tok_text
                fn_name = fn_name + "_" + method_alias
                p = p + 2
            elif impl_ctx_ps != ""
                method_alias = fn_name
                fn_name = impl_ctx_ps + "_" + method_alias
            end
            // Parse optional generic type parameters: fn name<T: Printable, U>(...)
            tp_box = [p]
            fn_tparams_raw = x86_synth_parse_type_list(tokens, tp_box, 0)
            if fn_tparams_raw != 0
                p = get(tp_box, 0)
            end
            tp_sp_ps = x86_synth_split_tparam_bounds(fn_tparams_raw)
            fn_tparams = tp_sp_ps[0]
            fn_tbounds = tp_sp_ps[1]
            pcount = 0
            fparams = list()
            p_types = list()
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
                    pt_decl = ""
                    p = p + 1
                    while has_paren == 1 and p < n and (tokens[p].tok_kind == TOK_NEWLINE() or tokens[p].tok_kind == TOK_COMMENT_LINE())
                        p = p + 1
                    end
                    if p < n and (tokens[p].tok_kind == TOK_COLON() or (tokens[p].tok_kind != TOK_STR() and tokens[p].tok_text == ":"))
                        p = p + 1
                        while has_paren == 1 and p < n and tokens[p].tok_kind == TOK_NEWLINE()
                            p = p + 1
                        end
                        pt_box = [p]
                        pt_ps = x86_synth_parse_type_expr(tokens, pt_box)
                        if pt_ps != ""
                            pt_decl = pt_ps
                            if pt_ps == "float" or pt_ps == "f64" or pt_ps == "f32"
                                push(fparams, pname_ps)
                            end
                            p = get(pt_box, 0)
                        end
                    end
                    push(p_types, pt_decl)
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
            ret_is_explicit = 0
            if p < n and (tokens[p].tok_kind == TOK_ARROW() or tokens[p].tok_kind == TOK_COLON() or (tokens[p].tok_kind != TOK_STR() and (tokens[p].tok_text == "->" or tokens[p].tok_text == ":")))
                p = p + 1
                while p < n and tokens[p].tok_kind == TOK_NEWLINE()
                    p = p + 1
                end
                rt_box = [p]
                rt_parsed = x86_synth_parse_type_expr(tokens, rt_box)
                if rt_parsed != ""
                    ret_t = rt_parsed
                    ret_is_explicit = 1
                    p = get(rt_box, 0)
                end
            end
            if ret_t == ""
                // Conservative lookahead across return expressions up to block end
                saw_float = 0
                saw_nonfloat = 0
                saw_concrete_nonfloat = 0
                inferred_struct = ""
                struct_conflict = 0
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
                        if bk == TOK_IDENT() and bp + 2 < n and (tokens[bp + 1].tok_kind == TOK_ASSIGN() or tokens[bp + 1].tok_text == "=")
                            asg_has_fl = 0
                            asg_pd = 0
                            asg_p = bp + 2
                            while asg_p < n and tokens[asg_p].tok_kind != TOK_NEWLINE() and tokens[asg_p].tok_kind != TOK_SEMI() and tokens[asg_p].tok_kind != TOK_EOF()
                                ak_p = tokens[asg_p].tok_kind
                                at_p = tokens[asg_p].tok_text
                                if ak_p == TOK_LPAREN() or ak_p == TOK_LBRACKET() or at_p == "(" or at_p == "["
                                    asg_pd = asg_pd + 1
                                elif ak_p == TOK_RPAREN() or ak_p == TOK_RBRACKET() or at_p == ")" or at_p == "]"
                                    if asg_pd > 0 asg_pd = asg_pd - 1 end
                                elif asg_pd == 0 and ak_p == TOK_FLOAT()
                                    asg_has_fl = 1
                                    break
                                elif asg_pd == 0 and ak_p == TOK_IDENT()
                                    fi_a = 0
                                    while fi_a < fparams.len()
                                        if fparams[fi_a] == at_p
                                            asg_has_fl = 1
                                            break
                                        end
                                        fi_a = fi_a + 1
                                    end
                                    if asg_has_fl == 1 break end
                                end
                                asg_p = asg_p + 1
                            end
                            if asg_has_fl == 1
                                push(fparams, btxt)
                            end
                        end
                        if bk == TOK_KW_RETURN() or (bk == TOK_IDENT() and (btxt == "return" or btxt == "ফিরে_যাও"))
                            rp = bp + 1
                            arm_fl = 0
                            arm_str = 0
                            arm_toks = 0
                            arm_st = ""
                            if rp + 1 < n and tokens[rp].tok_kind == TOK_IDENT() and (tokens[rp + 1].tok_kind == TOK_LPAREN() or tokens[rp + 1].tok_text == "(")
                                cand_st = tokens[rp].tok_text
                                ksi = 0
                                while ksi < known_structs.len()
                                    if known_structs[ksi] == cand_st
                                        arm_st = cand_st
                                        break
                                    end
                                    ksi = ksi + 1
                                end
                            elif rp < n and (tokens[rp].tok_kind == TOK_LBRACE() or (tokens[rp].tok_kind != TOK_STR() and tokens[rp].tok_text == "{"))
                                // WHY: Pre-register returned anonymous struct literals `{ a: 1, b: 2 }` so forward calls
                                // and `--strict-types` know exact field offsets before the callee body is synthesized.
                                kp_an = rp + 1
                                while kp_an < n and (tokens[kp_an].tok_kind == TOK_NEWLINE() or tokens[kp_an].tok_kind == TOK_SEMI())
                                    kp_an = kp_an + 1
                                end
                                if kp_an + 1 < n and tokens[kp_an].tok_kind == TOK_IDENT() and (tokens[kp_an + 1].tok_kind == TOK_COLON() or tokens[kp_an + 1].tok_text == ":")
                                    an_keys = x86_synth_scan_brace_keys(tokens, rp + 1)
                                    if an_keys.len() > 0
                                        m_an = x86_synth_find_matching_struct(s, an_keys)
                                        if m_an == ""
                                            an_sd = X86StructDef()
                                            an_sd.sd_name = "_anon_s_" + int_to_str(s.synth_structs.len())
                                            an_sd.sd_fields = an_keys
                                            an_ft = list()
                                            aki_p = 0
                                            while aki_p < an_keys.len()
                                                push(an_ft, "")
                                                aki_p = aki_p + 1
                                            end
                                            an_sd.sd_field_types = an_ft
                                            an_sd.sd_type_params = list()
                                            an_sd.sd_is_packed = 0
                                            an_sd.sd_align = 0
                                            x86_synth_compute_struct_layout(s, an_sd)
                                            push(s.synth_structs, an_sd)
                                            m_an = an_sd.sd_name
                                        end
                                        arm_st = m_an
                                    end
                                end
                            end
                            arm_concrete_nf = 0
                            r_paren_d = 0
                            while rp < n and tokens[rp].tok_kind != TOK_NEWLINE() and tokens[rp].tok_kind != TOK_SEMI() and tokens[rp].tok_kind != TOK_EOF()
                                rk = tokens[rp].tok_kind
                                rtxt = tokens[rp].tok_text
                                if rk == TOK_RBRACE() or rk == TOK_KW_END() or rk == TOK_DIR_END() or rtxt == "}" or rtxt == "end" or rtxt == "@end"
                                    break
                                end
                                arm_toks = arm_toks + 1
                                if rk == TOK_LPAREN() or rk == TOK_LBRACKET() or rtxt == "(" or rtxt == "["
                                    r_paren_d = r_paren_d + 1
                                elif rk == TOK_RPAREN() or rk == TOK_RBRACKET() or rtxt == ")" or rtxt == "]"
                                    if r_paren_d > 0
                                        r_paren_d = r_paren_d - 1
                                    end
                                elif rk == TOK_FLOAT()
                                    arm_fl = 1
                                elif rk == TOK_STR()
                                    arm_str = 1
                                    if r_paren_d == 0
                                        arm_concrete_nf = 1
                                    end
                                elif rk == TOK_INT()
                                    // WHY: Track concrete depth-0 int literals (`return 42`), NOT call arguments like `get(node, 3)`
                                    if r_paren_d == 0
                                        arm_concrete_nf = 1
                                    end
                                elif rk == TOK_IDENT()
                                    is_fp_id = 0
                                    fi = 0
                                    while fi < fparams.len()
                                        if fparams[fi] == rtxt
                                            arm_fl = 1
                                            is_fp_id = 1
                                            break
                                        end
                                        fi = fi + 1
                                    end
                                    if r_paren_d == 0 and is_fp_id == 0
                                        if rtxt == "true" or rtxt == "false"
                                            arm_concrete_nf = 1
                                        else
                                            // WHY: Bare non-float variable/parameter (e.g. `return x` in `fn ret_f(x)`),
                                            // excluding calls (`get(node, 3)`), field reads (`tok.tok_float_val`), or index ops.
                                            is_complex_id = 0
                                            if rp + 1 < n
                                                nxk = tokens[rp + 1].tok_kind
                                                nxt = tokens[rp + 1].tok_text
                                                if nxk == TOK_LPAREN() or nxk == TOK_DOT() or nxk == TOK_LBRACKET() or nxt == "(" or nxt == "." or nxt == "["
                                                    is_complex_id = 1
                                                end
                                            end
                                            if rp > 0 and (tokens[rp - 1].tok_kind == TOK_DOT() or tokens[rp - 1].tok_text == ".")
                                                is_complex_id = 1
                                            end
                                            if is_complex_id == 0
                                                arm_concrete_nf = 1
                                            end
                                        end
                                    end
                                end
                                rp = rp + 1
                            end
                            if arm_st != ""
                                if inferred_struct == ""
                                    inferred_struct = arm_st
                                elif inferred_struct != arm_st
                                    struct_conflict = 1
                                end
                                saw_nonfloat = 1
                                saw_concrete_nonfloat = 1
                            elif arm_fl == 1 and arm_str == 0
                                saw_float = 1
                            elif arm_toks > 0
                                saw_nonfloat = 1
                                if arm_concrete_nf == 1
                                    saw_concrete_nonfloat = 1
                                end
                            end
                        end
                        bp = bp + 1
                    end
                end
                if inferred_struct != "" and struct_conflict == 0 and saw_float == 0
                    ret_t = inferred_struct
                elif saw_float == 1 and saw_nonfloat == 0
                    ret_t = "f64"
                elif saw_float == 1 and saw_concrete_nonfloat == 1 and s.synth_freestanding == 0
                    ret_t = "dyn_tagged"
                end
            end
            fe = X86Function()
            fe.fn_name = fn_name
            fe.fn_entry_offset = 0 - 1
            fe.fn_ret_type = ret_t
            fe.fn_ret_explicit = ret_is_explicit
            fe.fn_end_offset = 0
            fe.fn_decl_line = base_line
            fe.fn_param_count = pcount
            fe.fn_tok_pos = i
            fe.fn_param_types = p_types
            fe.fn_type_params = fn_tparams
            fe.fn_type_bounds = fn_tbounds
            x86_synth_register_fn_obj(s, fe)
            if method_alias != ""
                fa = X86Function()
                fa.fn_name = method_alias
                fa.fn_entry_offset = 0 - 1
                fa.fn_ret_type = ret_t
                fa.fn_ret_explicit = ret_is_explicit
                fa.fn_end_offset = 0
                fa.fn_decl_line = base_line
                fa.fn_param_count = pcount
                fa.fn_tok_pos = i
                fa.fn_param_types = p_types
                fa.fn_type_params = fn_tparams
                fa.fn_type_bounds = fn_tbounds
                x86_synth_register_fn_obj(s, fa)
            end
            i = p
            continue
        end
        i = i + 1
    end
    return 0

fn x86_synth_prescan_globals s tokens
    // WHY: Pre-registers ALL top-level non-integer-literal globals (string, float, list, struct, dict,
    // computed values) and g_*/G_* globals in RW .data before sequential codegen so forward references
    // from functions declared earlier resolve exact RW slots and inferred primitive/struct types.
    n = tokens.len()
    known_structs = list()
    si = 0
    while si + 1 < n
        st = tokens[si]
        sk = st.tok_kind
        sx = st.tok_text
        if sk == TOK_KW_STRUCT() or sk == TOK_DIR_STRUCT() or (sk == TOK_IDENT() and (sx == "struct" or sx == "গঠন" or sx == "@struct"))
            if tokens[si + 1].tok_kind == TOK_IDENT()
                push(known_structs, tokens[si + 1].tok_text)
            end
        end
        si = si + 1
    end
    // Pass 1: Collect top-level candidate assignments & record function body token ranges
    // WHY: Only top-level `g_*`/`G_*` globals or top-level variables actually referenced inside
    // at least one function need RW .data/.bss storage; top-level-only script locals (such as
    // `live_eden` in conservative stack-scanning tests) stay on `_start`'s stack frame.
    cand_names = list()
    cand_ptypes = list()
    cand_stypes = list()
    cand_force = list()
    cand_used = list()
    fn_starts = list()
    fn_ends = list()

    i = 0
    while i < n
        t = tokens[i]
        k = t.tok_kind
        txt = t.tok_text
        if k == TOK_EOF()
            break
        end
        if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_BLOCK()
            i = i + 1
            continue
        end
        // Skip entire fn / struct / enum / component bodies; record fn/component ranges for ref scan
        is_blk = 0
        is_fn_blk = 0
        if k == TOK_KW_FN() or k == TOK_DIR_FN() or k == TOK_KW_COMPONENT()
            is_blk = 1
            is_fn_blk = 1
        elif k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT() or k == TOK_KW_ENUM() or k == TOK_DIR_ENUM() or k == TOK_KW_IMPL() or k == TOK_DIR_IMPL()
            is_blk = 1
        elif k == TOK_DIR_TRAIT() and (i + 1) < n and x86_synth_is_ident_token(tokens[i + 1].tok_kind) == 1 and tokens[i + 1].tok_span.span_start_line == t.tok_span.span_start_line
            is_blk = 1
        elif k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn" or txt == "component" or txt == "উপাদান")
            is_blk = 1
            is_fn_blk = 1
        elif k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct" or txt == "union" or txt == "ইউনিয়ন" or txt == "@union" or txt == "enum" or txt == "@enum" or txt == "গণনা" or txt == "trait" or txt == "বৈশিষ্ট্য" or txt == "@trait" or txt == "impl" or txt == "বাস্তবায়ন" or txt == "@impl")
            is_blk = 1
        end
        if is_blk == 1
            base_col = t.tok_span.span_start_col
            base_line = t.tok_span.span_start_line
            body_s = i + 1
            i = i + 1
            brace_d = 0
            while i < n
                bt = tokens[i]
                bk = bt.tok_kind
                btxt = bt.tok_text
                if bk == TOK_EOF()
                    break
                end
                if bk == TOK_LBRACE() or (bk != TOK_STR() and btxt == "{")
                    brace_d = brace_d + 1
                elif bk == TOK_RBRACE() or (bk != TOK_STR() and btxt == "}")
                    if brace_d > 0
                        brace_d = brace_d - 1
                        if brace_d == 0
                            i = i + 1
                            break
                        end
                    end
                end
                if brace_d == 0
                    if x86_synth_is_block_end(tokens, i) == 1 and bt.tok_span.span_start_col <= base_col
                        i = i + 1
                        break
                    end
                    if bt.tok_span.span_start_line > base_line and bt.tok_span.span_start_col <= base_col and bk != TOK_NEWLINE() and bk != TOK_SEMI() and bk != TOK_COMMENT_LINE() and bk != TOK_COMMENT_DOC() and bk != TOK_COMMENT_BLOCK()
                        if bk != TOK_KW_ELIF() and bk != TOK_KW_ELSE() and bk != TOK_DIR_ELIF() and bk != TOK_DIR_ELSE() and bk != TOK_DIR_END() and bk != TOK_KW_END() and btxt != "elif" and btxt != "else" and btxt != "অথবা" and btxt != "নাহলে"
                            break
                        end
                    end
                end
                i = i + 1
            end
            if is_fn_blk == 1
                push(fn_starts, body_s)
                push(fn_ends, i)
            end
            continue
        end

        // Only inspect top-level column <= 1 declarations (`[let|global|mut|const] name [: type] = rhs`)
        if t.tok_span.span_start_col <= 1
            p = i
            is_explicit_global = 0
            if k == TOK_KW_LET() or k == TOK_KW_MUT() or k == TOK_KW_CONST() or (k == TOK_IDENT() and (txt == "let" or txt == "mut" or txt == "const" or txt == "global" or txt == "বৈশ্বিক" or txt == "ধরি" or txt == "স্থির"))
                if k == TOK_IDENT() and (txt == "global" or txt == "বৈশ্বিক")
                    is_explicit_global = 1
                end
                p = p + 1
            end
            if p < n and tokens[p].tok_kind == TOK_IDENT()
                vname = tokens[p].tok_text
                np = p + 1
                ann_t = ""
                if np + 1 < n and (tokens[np].tok_kind == TOK_COLON() or (tokens[np].tok_kind != TOK_STR() and tokens[np].tok_text == ":"))
                    if x86_synth_is_ident_token(tokens[np + 1].tok_kind) == 1
                        ann_t = tokens[np + 1].tok_text
                        np = np + 2
                    end
                end
                if np < n and (tokens[np].tok_kind == TOK_ASSIGN() or (tokens[np].tok_kind != TOK_STR() and tokens[np].tok_text == "="))
                    rhs_p = np + 1
                    is_pure_int = 0
                    if rhs_p < n and tokens[rhs_p].tok_kind == TOK_INT()
                        af = rhs_p + 1
                        if af >= n or tokens[af].tok_kind == TOK_NEWLINE() or tokens[af].tok_kind == TOK_SEMI() or tokens[af].tok_kind == TOK_COMMENT_LINE()
                            is_pure_int = 1
                        end
                    end
                    is_mg_nm = x86_synth_is_mutable_global_name(vname)
                    if is_explicit_global == 1
                        is_mg_nm = 1
                    end
                    if (is_mg_nm == 1 or is_pure_int == 0) and x86_synth_is_boxed_name(s, vname) == 0
                        inf_p = ""
                        inf_st = ""
                        if ann_t == "int" or ann_t == "i64" or ann_t == "i32" or ann_t == "u64" or ann_t == "u32"
                            inf_p = "int"
                        elif ann_t == "float" or ann_t == "f64" or ann_t == "f32"
                            inf_p = "float"
                        elif ann_t == "str" or ann_t == "string"
                            inf_p = "str"
                        elif ann_t != ""
                            inf_st = ann_t
                        elif rhs_p < n
                            rk = tokens[rhs_p].tok_kind
                            rtxt = tokens[rhs_p].tok_text
                            if rk == TOK_STR() or rk == TOK_INTERP_STR()
                                inf_p = "str"
                            elif rk == TOK_FLOAT()
                                inf_p = "float"
                            elif rk == TOK_IDENT() and rhs_p + 1 < n and (tokens[rhs_p + 1].tok_kind == TOK_LPAREN() or tokens[rhs_p + 1].tok_text == "(")
                                ksi = 0
                                while ksi < known_structs.len()
                                    if known_structs[ksi] == rtxt
                                        inf_st = rtxt
                                        break
                                    end
                                    ksi = ksi + 1
                                end
                            end
                        end
                        // Deduplicate candidate entry
                        dup_ci = 0 - 1
                        ci = 0
                        while ci < cand_names.len()
                            if cand_names[ci] == vname
                                dup_ci = ci
                                break
                            end
                            ci = ci + 1
                        end
                        if dup_ci < 0
                            push(cand_names, vname)
                            push(cand_ptypes, inf_p)
                            push(cand_stypes, inf_st)
                            push(cand_force, is_mg_nm)
                            push(cand_used, 0)
                        else
                            if is_mg_nm == 1 list_set(cand_force, dup_ci, 1) end
                            if cand_ptypes[dup_ci] == "" and inf_p != "" list_set(cand_ptypes, dup_ci, inf_p) end
                            if cand_stypes[dup_ci] == "" and inf_st != "" list_set(cand_stypes, dup_ci, inf_st) end
                        end
                    end
                end
            end
        end
        // Advance to next line
        cur_ln = t.tok_span.span_start_line
        i = i + 1
        while i < n and tokens[i].tok_span.span_start_line == cur_ln and tokens[i].tok_kind != TOK_SEMI()
            i = i + 1
        end
    end

    // Pass 2: O(1)-bucket scan of function bodies to detect which non-g_/G_ top-level vars escape into functions
    if cand_names.len() > 0 and fn_starts.len() > 0
        buckets = list()
        bi = 0
        while bi < 256
            push(buckets, list())
            bi = bi + 1
        end
        ci = 0
        while ci < cand_names.len()
            if cand_force[ci] == 0
                cn = cand_names[ci]
                clen = str_len(cn)
                h = 0
                if clen > 0
                    h = (clen + (str_char_at(cn, 0) * 31) + (str_char_at(cn, clen - 1) * 17)) & 255
                end
                push(buckets[h], ci)
            end
            ci = ci + 1
        end

        fi = 0
        while fi < fn_starts.len()
            ti = fn_starts[fi]
            te = fn_ends[fi]
            while ti < te and ti < n
                if tokens[ti].tok_kind == TOK_IDENT()
                    tname = tokens[ti].tok_text
                    tlen = str_len(tname)
                    if tlen > 0
                        th = (tlen + (str_char_at(tname, 0) * 31) + (str_char_at(tname, tlen - 1) * 17)) & 255
                        bkt = buckets[th]
                        if bkt.len() > 0
                            ki = 0
                            while ki < bkt.len()
                                cidx = bkt[ki]
                                if cand_names[cidx] == tname
                                    list_set(cand_used, cidx, 1)
                                    break
                                end
                                ki = ki + 1
                            end
                        end
                    end
                end
                ti = ti + 1
            end
            fi = fi + 1
        end
    end

    // Pass 3: Allocate RW .data slots for all forced (g_/G_) or function-referenced top-level globals
    ci = 0
    while ci < cand_names.len()
        if cand_force[ci] == 1 or cand_used[ci] == 1
            x86_synth_alloc_mutable_global(s, cand_names[ci])
            if cand_force[ci] == 1
                x86_synth_mark_mutable_global_explicit(s, cand_names[ci])
            end
            if cand_ptypes[ci] != "" or cand_stypes[ci] != ""
                x86_synth_set_mutable_global_types(s, cand_names[ci], cand_ptypes[ci], cand_stypes[ci])
            end
        end
        ci = ci + 1
    end
    return 0
