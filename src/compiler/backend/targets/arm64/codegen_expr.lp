// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN ARM64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/arm64/codegen_expr.lp
// ==============================================================================

// ── 7. Recursive-Descent Expression Synthesizer ────────────────────────────────

fn arm64_interp_is_ident inner
    ilen = len(inner)
    if ilen == 0 return 0 end
    c0 = ord(char_at(inner, 0))
    if not ((c0 >= 65 and c0 <= 90) or (c0 >= 97 and c0 <= 122) or c0 == 95 or c0 >= 128)
        return 0
    end
    k = 1
    while k < ilen
        ck = ord(char_at(inner, k))
        if not ((ck >= 65 and ck <= 90) or (ck >= 97 and ck <= 122) or (ck >= 48 and ck <= 57) or ck == 95 or ck >= 128)
            return 0
        end
        k = k + 1
    end
    return 1

fn arm64_interp_is_lsp_snippet inner
    // WHY: Preserves LSP snippet placeholders like "${1:name}" as literal strings.
    ilen = len(inner)
    idx = 0
    saw_dig = 0
    while idx < ilen
        c = ord(char_at(inner, idx))
        if c >= 48 and c <= 57
            saw_dig = 1
            idx = idx + 1
        else
            break
        end
    end
    if saw_dig == 1 and idx < ilen and ord(char_at(inner, idx)) == 58
        return 1
    end
    return 0

fn arm64_synth_emit_interp_str s txt
    // WHY: Compiles both `${expr}` (full arbitrary expression) and `{ident}` (in-scope local)
    // string interpolations directly into native ARM64 `__str_concat` chains.
    tlen = len(txt)
    chunk_types = list()  // 0 = literal, 1 = {ident}, 2 = ${expr}
    chunk_vals = list()
    has_any = 0
    cur_lit = ""
    i = 0
    while i < tlen
        ch = char_at(txt, i)
        if ch == "$" and i + 1 < tlen and char_at(txt, i + 1) == "{"
            j = i + 2
            bd = 1
            found_c = 0
            while j < tlen
                cj = char_at(txt, j)
                if cj == "{"
                    bd = bd + 1
                elif cj == "}"
                    bd = bd - 1
                    if bd == 0
                        found_c = 1
                        break
                    end
                elif cj == "\n" or cj == "\r"
                    break
                end
                j = j + 1
            end
            if found_c == 1
                inner = str_sub(txt, i + 2, j)
                if len(inner) > 0 and arm64_interp_is_lsp_snippet(inner) == 0
                    if len(cur_lit) > 0
                        push(chunk_types, 0)
                        push(chunk_vals, cur_lit)
                        cur_lit = ""
                    end
                    push(chunk_types, 2)
                    push(chunk_vals, inner)
                    has_any = 1
                    i = j + 1
                    continue
                end
            end
        elif ch == "{"
            j = i + 1
            found_c = 0
            while j < tlen
                cj = char_at(txt, j)
                if cj == "}"
                    found_c = 1
                    break
                end
                if cj == "{" or cj == "\n" or cj == "\r"
                    break
                end
                j = j + 1
            end
            if found_c == 1
                inner = str_sub(txt, i + 1, j)
                if arm64_interp_is_ident(inner) == 1 and arm64_find_local_var(s, inner) != 0
                    if len(cur_lit) > 0
                        push(chunk_types, 0)
                        push(chunk_vals, cur_lit)
                        cur_lit = ""
                    end
                    push(chunk_types, 1)
                    push(chunk_vals, inner)
                    has_any = 1
                    i = j + 1
                    continue
                end
            end
        end
        cur_lit = cur_lit + ch
        i = i + 1
    end
    if has_any == 0
        arm64_emit_load_rodata_str(s, 0, txt)
        s.a64_last_expr_type = "str"
        return 0
    end
    if len(cur_lit) > 0
        push(chunk_types, 0)
        push(chunk_vals, cur_lit)
    end
    s.a64_needs_str_helpers = 1
    s.synth_needs_alloc = 1
    ci = 0
    while ci < chunk_types.len()
        if ci > 0
            arm64_push_reg(s, 0)
        end
        cty = chunk_types[ci]
        if cty == 0
            arm64_emit_load_rodata_str(s, 0, chunk_vals[ci])
        elif cty == 1
            lv = arm64_find_local_var(s, chunk_vals[ci])
            arm64_emit_ldr_reg_sp(s, 0, lv.lv_offset)
            if lv.a64_lv_is_boxed == 1
                arm64_emit_ldr_x_off(s, 0, 0, 0)
            end
            if lv.a64_lv_prim_type == "str"
                // X0 is already a cstr pointer
            elif lv.a64_lv_prim_type == "float"
                arm64_synth_emit_call_helper(s, "__float_to_str")
            elif lv.a64_lv_prim_type == "dyn_tagged" and lv.a64_lv_tag_off > 0
                arm64_emit_ldr_reg_sp(s, 1, lv.a64_lv_tag_off)
                arm64_synth_emit_call_helper(s, "__tagged_to_str")
            elif lv.a64_lv_is_uint == 1
                arm64_synth_emit_call_helper(s, "__uint_to_str")
            else
                arm64_synth_emit_call_helper(s, "__int_to_str")
            end
        else
            sub_toks = tokenize_source(chunk_vals[ci])
            sub_pb = [0]
            arm64_synth_compile_expr(s, sub_toks, sub_pb)
            if s.a64_last_expr_type == "str"
                // X0 is already a cstr pointer
            elif s.a64_last_expr_type == "float"
                arm64_synth_emit_call_helper(s, "__float_to_str")
            elif s.a64_last_expr_type == "dyn_tagged"
                arm64_synth_emit_call_helper(s, "__tagged_to_str")
            elif s.a64_last_is_uint == 1
                arm64_synth_emit_call_helper(s, "__uint_to_str")
            else
                arm64_synth_emit_call_helper(s, "__int_to_str")
            end
        end
        if ci > 0
            arm64_emit_mov_reg(s, 1, 0)
            arm64_pop_reg(s, 0)
            arm64_synth_emit_call_helper(s, "__str_concat")
        end
        ci = ci + 1
    end
    s.a64_last_expr_type = "str"
    s.a64_last_is_uint = 0
    return 0

fn arm64_synth_expr_primary s toks pos_box
    // WHY: Parses and synthesizes primary operands (integers, strings, identifiers, calls, grouping).
    // Result is always computed into X0.
    pos = get(pos_box, 0)
    if pos >= toks.len()
        arm64_emit_movz_x(s, 0, 0, 0)
        return 0

    t = toks[pos]
    k = t.tok_kind
    handled = 0
    cur_struct = ""
    s.a64_last_is_uint = 0
    s.a64_last_expr_type = "int"

    // 0. Unary Operators (-, !, ~, not, না)
    if k == TOK_MINUS()
        list_set(pos_box, 0, pos + 1)
        arm64_synth_expr_primary(s, toks, pos_box)
        if s.a64_last_expr_type == "float"
            arm64_emit_movz_x(s, 9, 32768, 48) // 0x8000000000000000
            arm64_emit_eor_x(s, 0, 0, 9)
        elif s.a64_last_expr_type == "dyn_tagged"
            // WHY: Runtime tag X1 == 1 means X0 holds IEEE-754 f64 bits (flip sign bit 63);
            // otherwise negate as signed integer (prevents corrupting `-ret_f()` via 2's complement!).
            arm64_emit_movz_x(s, 9, 1, 0)
            arm64_emit_cmp_x(s, 1, 9)
            arm64_emit_b_cond(s, 0, 3)         // b.eq .neg_fp (+3 words)
            arm64_emit_sub_x(s, 0, 31, 0)      // sub x0, xzr, x0
            arm64_emit_b(s, 3)                 // b .neg_done (+3 words)
            arm64_emit_movz_x(s, 9, 32768, 48) // 0x8000000000000000
            arm64_emit_eor_x(s, 0, 0, 9)
        else
            arm64_emit_sub_x(s, 0, 31, 0) // sub x0, xzr, x0
        end
        s.a64_last_struct = ""
        return 0
    if k == TOK_BANG() or (k == TOK_IDENT() and (t.tok_text == "not" or t.tok_text == "না"))
        list_set(pos_box, 0, pos + 1)
        arm64_synth_expr_primary(s, toks, pos_box)
        arm64_emit_cmp_x(s, 0, 31)
        arm64_emit_b_cond(s, 0, 3)     // b.eq +3 (if 0 -> set 1)
        arm64_emit_movz_x(s, 0, 0, 0)
        arm64_emit_b(s, 2)
        arm64_emit_movz_x(s, 0, 1, 0)
        s.a64_last_struct = ""
        s.a64_last_expr_type = "int"
        return 0
    if k == TOK_TILDE()
        list_set(pos_box, 0, pos + 1)
        arm64_synth_expr_primary(s, toks, pos_box)
        arm64_emit_orn_x(s, 0, 31, 0) // mvn x0, x0 (orn x0, xzr, x0)
        s.a64_last_struct = ""
        s.a64_last_expr_type = "int"
        return 0
    if k == TOK_KW_AWAIT() or (k == TOK_IDENT() and (t.tok_text == "await" or t.tok_text == "অপেক্ষা" or t.tok_text == "@await"))
        list_set(pos_box, 0, pos + 1)
        arm64_synth_expr_primary(s, toks, pos_box)
        return 0

    // 1. Integer / Boolean / Null Literal
    if k == TOK_INT() or k == TOK_BOOL() or k == TOK_NONE()
        list_set(pos_box, 0, pos + 1)
        arm64_emit_mov_imm64(s, 0, t.tok_int_val)
        s.a64_last_expr_type = "int"
        handled = 1

    // 1b. Float Literal: IEEE-754 binary64 64-bit precision
    if handled == 0 and k == TOK_FLOAT()
        list_set(pos_box, 0, pos + 1)
        fbits = arm64_parse_float_bits(t.tok_text)
        arm64_emit_mov_imm64(s, 0, fbits)
        s.a64_last_expr_type = "float"
        handled = 1

    // 1c. Array / List Literal: [e0, e1, ...]
    if handled == 0 and k == TOK_LBRACKET()
        list_set(pos_box, 0, pos + 1)
        arr_cnt = 0
        while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RBRACKET()
            arm64_synth_compile_expr(s, toks, pos_box)
            arm64_push_reg(s, 0)
            arr_cnt = arr_cnt + 1
            cur_p = get(pos_box, 0)
            if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_COMMA()
                list_set(pos_box, 0, cur_p + 1)
        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        s.a64_needs_list_create = 1
        s.synth_needs_alloc = 1
        arm64_emit_mov_imm64(s, 0, arr_cnt)
        arr_call_off = s.synth_code.len()
        arm64_emit_bl(s, 0)
        arr_rel = Arm64CallReloc()
        arr_rel.a64_cr_patch_offset = arr_call_off
        arr_rel.a64_cr_target_name = "__list_create"
        push(s.synth_call_relocs, arr_rel)
        if arr_cnt > 0
            arm64_emit_mov_reg(s, 9, 0)              // X9 = hdr
            arm64_synth_emit32(s, 4181721088 | (2 << 10) | (9 << 5) | 10) // ldr x10, [x9, #16]
            ai = arr_cnt - 1
            while ai >= 0
                arm64_pop_reg(s, 1)
                arm64_emit_mov_imm64(s, 2, ai * 8)
                arm64_emit_add_x(s, 2, 10, 2)
                arm64_synth_emit32(s, 4177526784 | (0 << 10) | (2 << 5) | 1) // str x1, [x2, #0]
                ai = ai - 1
            arm64_emit_mov_reg(s, 0, 9)
        handled = 1

    // 1d. Closure Literal: fn(p1, p2) { ... } / => expr, |p1, p2| => expr / { ... }, || => expr
    if handled == 0 and (k == TOK_KW_FN() or (k == TOK_IDENT() and (t.tok_text == "fn" or t.tok_text == "কাজ"))) and pos + 1 < toks.len() and (toks[pos + 1].tok_kind == TOK_LPAREN() or toks[pos + 1].tok_text == "(")
        list_set(pos_box, 0, pos + 2)
        c_params = list()
        while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN() and toks[get(pos_box, 0)].tok_text != ")"
            pt = toks[get(pos_box, 0)]
            if arm64_is_ident_token(pt.tok_kind) == 1
                push(c_params, pt.tok_text)
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    end
                end
            else
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or toks[get(pos_box, 0)].tok_text == ")")
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        arm64_emit_closure_literal(s, toks, pos_box, c_params)
        handled = 1
    end

    if handled == 0 and (k == TOK_BAR() or k == TOK_OR() or (k != TOK_STR() and (t.tok_text == "|" or t.tok_text == "||")))
        c_params = list()
        if k == TOK_OR() or t.tok_text == "||"
            list_set(pos_box, 0, pos + 1)
        else
            list_set(pos_box, 0, pos + 1)
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_BAR() and toks[get(pos_box, 0)].tok_text != "|"
                pt = toks[get(pos_box, 0)]
                if arm64_is_ident_token(pt.tok_kind) == 1
                    push(c_params, pt.tok_text)
                end
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_BAR() or toks[get(pos_box, 0)].tok_text == "|")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        arm64_emit_closure_literal(s, toks, pos_box, c_params)
        handled = 1
    end

    // 1e. Dict / HashMap Literal: { "k": v, ... } or {}
    if handled == 0 and (k == TOK_LBRACE() or (k != TOK_STR() and t.tok_text == "{"))
        list_set(pos_box, 0, pos + 1)
        s.a64_needs_dict = 1
        s.synth_needs_alloc = 1
        arm64_emit_movz_x(s, 0, 16, 0)
        arm64_synth_emit_call_helper(s, "__dict_new")
        arm64_push_reg(s, 0)
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            dp = get(pos_box, 0)
            if dp >= toks.len() break end
            if toks[dp].tok_kind == TOK_RBRACE() or (toks[dp].tok_kind != TOK_STR() and toks[dp].tok_text == "}")
                list_set(pos_box, 0, dp + 1)
                break
            end
            arm64_synth_compile_expr(s, toks, pos_box)
            arm64_push_reg(s, 0) // key
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or toks[get(pos_box, 0)].tok_text == ":")
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            arm64_synth_compile_expr(s, toks, pos_box) // X0 = val (X1 = tag if dyn_tagged)
            dval_t = s.a64_last_expr_type
            arm64_emit_mov_reg(s, 2, 0)
            if dval_t == "float"
                arm64_emit_movz_x(s, 3, 1, 0)
            elif dval_t == "str"
                arm64_emit_movz_x(s, 3, 2, 0)
            elif dval_t == "dyn_tagged"
                arm64_emit_mov_reg(s, 3, 1)
            else
                arm64_emit_movz_x(s, 3, 0, 0)
            end
            arm64_pop_reg(s, 1) // key
            arm64_pop_reg(s, 0) // dict hdr
            arm64_synth_emit_call_helper(s, "__dict_set")
            arm64_push_reg(s, 0)
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_COMMA()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        arm64_pop_reg(s, 0)
        s.a64_last_expr_type = "int"
        handled = 1
    end

    // 2. String Literal & Interpolated String Literal
    if handled == 0 and k == TOK_STR()
        list_set(pos_box, 0, pos + 1)
        ro_off = arm64_synth_add_rodata_str(s, t.tok_text, 0)
        patch_pos = s.synth_code.len()
        arm64_emit_movz_x(s, 0, 0, 0)
        arm64_emit_movk_x(s, 0, 0, 16)
        arm64_emit_movk_x(s, 0, 0, 32)
        arm64_emit_movk_x(s, 0, 0, 48)

        rel = Arm64StringReloc()
        rel.sr_patch_offset = patch_pos
        rel.sr_rodata_offset = ro_off
        rel.sr_reg = 0
        push(s.synth_str_relocs, rel)
        s.a64_last_expr_type = "str"
        handled = 1
    elif handled == 0 and k == TOK_INTERP_STR()
        list_set(pos_box, 0, pos + 1)
        arm64_synth_emit_interp_str(s, t.tok_text)
        handled = 1

    // 3. Identifier or Call (Variable lookup, Field access, or Function Call)
    is_ident_or_call = 0
    if handled == 0 and (k == TOK_IDENT() or k == TOK_KW_SYSCALL() or k == TOK_KW_PRINT())
        is_ident_or_call = 1
    if is_ident_or_call == 1
        handled = 1
        list_set(pos_box, 0, pos + 1)
        var_name = t.tok_text
        next_pos = get(pos_box, 0)

        // Function call: name(...)
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_LPAREN()
            list_set(pos_box, 0, next_pos + 1) // Consume '('
            // Parse arguments and push to stack in order (also track arg types & uint flags for str/dict_set)
            arg_count = 0
            arg_types = list()
            arg_is_uints = list()
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                arm64_synth_compile_expr(s, toks, pos_box)
                push(arg_types, s.a64_last_expr_type)
                push(arg_is_uints, s.a64_last_is_uint)
                arm64_push_reg(s, 0) // Push X0
                arg_count = arg_count + 1
                cur_pos = get(pos_box, 0)
                if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, cur_pos + 1)

            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            // ── Intrinsic 1: syscall / সিসকল ─────────────────────────────────
            // Linux AArch64: X8 = syscall number, X0..X5 = args 1..6
            if var_name == "syscall" or var_name == "সিসকল"
                if arg_count >= 7
                    arm64_pop_reg(s, 5) // arg 6 (X5)
                if arg_count >= 6
                    arm64_pop_reg(s, 4) // arg 5 (X4)
                if arg_count >= 5
                    arm64_pop_reg(s, 3) // arg 4 (X3)
                if arg_count >= 4
                    arm64_pop_reg(s, 2) // arg 3 (X2)
                if arg_count >= 3
                    arm64_pop_reg(s, 1) // arg 2 (X1)
                if arg_count >= 2
                    arm64_pop_reg(s, 0) // arg 1 (X0)
                if arg_count >= 1
                    arm64_pop_reg(s, 8) // syscall number (X8)
                arm64_emit_svc(s, 0)
                return 0

            // ── Intrinsic 2: malloc / alloc / sys_alloc / mem_alloc / মেমরি_বরাদ্দ ──
            if var_name == "malloc" or var_name == "mem_alloc" or var_name == "মেমরি_বরাদ্দ" or var_name == "alloc" or var_name == "sys_alloc" or var_name == "বরাদ্দ"
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // requested size in X0
                else
                    arm64_emit_mov_imm64(s, 0, 32)
                arm64_synth_emit_call_alloc(s)
                return 0

            // ── Intrinsic 2b: free / sys_free / mem_free / মুক্ত / মেমরি_মুক্তি ──
            if var_name == "free" or var_name == "sys_free" or var_name == "mem_free" or var_name == "মুক্ত" or var_name == "মেমরি_মুক্তি"
                ai = 0
                while ai < arg_count
                    arm64_pop_reg(s, 1)
                    ai = ai + 1
                arm64_emit_movz_x(s, 0, 0, 0)
                return 0

            // ── Intrinsic 3: mem_word_read / mem_read / মেমরি_পড়ো ──────────
            if var_name == "mem_word_read" or var_name == "mem_read" or var_name == "মেমরি_পড়ো"
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1) // X0 = addr + offset
                // ldr x0, [x0, #0] (0xF9400000 = 4181721088)
                arm64_synth_emit32(s, 4181721088)
                return 0

            // ── Intrinsic 4: mem_word_write / mem_write / মেমরি_লেখো ───────
            if var_name == "mem_word_write" or var_name == "mem_write" or var_name == "মেমরি_লেখো"
                if arg_count >= 3
                    arm64_pop_reg(s, 2) // value (X2)
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1) // X0 = addr + offset
                // str x2, [x0, #0] (0xF9000002)
                arm64_synth_emit32(s, 0xF9000002)
                arm64_emit_mov_reg(s, 0, 2) // return val in X0
                return 0

            // ── Intrinsic 5: mem_byte_read / sys_peek8 / মেমরি_বাইট_পড়ো ──────
            if var_name == "mem_byte_read" or var_name == "mem_read_byte" or var_name == "মেমরি_বাইট_পড়ো" or var_name == "sys_peek8"
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1)
                // ldrb w0, [x0, #0] (0x39400000)
                arm64_synth_emit32(s, 0x39400000)
                return 0

            // ── Intrinsic 6: mem_byte_write / sys_poke8 / মেমরি_বাইট_লেখো ─────
            if var_name == "mem_byte_write" or var_name == "mem_write_byte" or var_name == "মেমরি_বাইট_লেখো" or var_name == "sys_poke8"
                if arg_count >= 3
                    arm64_pop_reg(s, 2) // value (X2)
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1)
                // strb w2, [x0, #0] (0x39000002)
                arm64_synth_emit32(s, 0x39000002)
                arm64_emit_mov_reg(s, 0, 2)
                return 0

            // ── Intrinsic 7: exit / বিদায় ─────────────────────────────────
            if var_name == "exit" or var_name == "বিদায়"
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // status code
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                arm64_emit_movz_x(s, 8, 94, 0) // SYS_exit_group (94)
                arm64_emit_svc(s, 0)
                return 0

            // ── Intrinsic 8: list / তালিকা ─────────────────────────────────────
            if var_name == "list" or var_name == "তালিকা"
                s.a64_needs_list_create = 1
                s.synth_needs_alloc = 1
                arm64_emit_mov_imm64(s, 0, arg_count)
                lc_call_off = s.synth_code.len()
                arm64_emit_bl(s, 0)
                lc_rel = Arm64CallReloc()
                lc_rel.a64_cr_patch_offset = lc_call_off
                lc_rel.a64_cr_target_name = "__list_create"
                push(s.synth_call_relocs, lc_rel)
                if arg_count > 0
                    arm64_emit_mov_reg(s, 9, 0) // X9 = list header ptr (keep SP pointing to args)
                    ai = arg_count - 1
                    while ai >= 0
                        arm64_pop_reg(s, 1)
                        item_off = 32 + (ai * 8)
                        scaled = item_off / 8
                        // str x1, [x9, #item_off]
                        st_item = 4177526784 | ((scaled & 4095) << 10) | (9 << 5) | 1
                        arm64_synth_emit32(s, st_item)
                        ai = ai - 1
                    arm64_emit_mov_reg(s, 0, 9) // return list ptr in X0
                return 0

            // ── Intrinsic 8b: len / দৈর্ঘ্য (list header [0]) ────────────────────
            if var_name == "len" or var_name == "দৈর্ঘ্য"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit32(s, 4181721088) // ldr x0, [x0, #0]
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                return 0

            // ── Intrinsic 8c: get / নাও (hdr, idx -> data[idx]) ────────────────
            if var_name == "get" or var_name == "নাও"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                if arg_count == 2
                    arm64_pop_reg(s, 1) // X1 = idx
                    arm64_pop_reg(s, 0) // X0 = hdr
                    arm64_synth_emit32(s, 4181723138) // ldr x2, [x0, #16]
                    arm64_emit_add_x(s, 1, 1, 1)     // X1 = idx * 2
                    arm64_emit_add_x(s, 1, 1, 1)     // X1 = idx * 4
                    arm64_emit_add_x(s, 1, 1, 1)     // X1 = idx * 8
                    arm64_emit_add_x(s, 0, 2, 1)     // X0 = data_ptr + idx*8
                    arm64_synth_emit32(s, 4181721088) // ldr x0, [x0, #0]
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    arm64_emit_movz_x(s, 0, 0, 0)
                return 0

            // ── Intrinsic 8d: list_set / সেট (hdr, idx, val -> hdr) ────────────
            if var_name == "list_set" or var_name == "সেট"
                while arg_count > 3
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                if arg_count == 3
                    arm64_pop_reg(s, 2) // X2 = val
                    arm64_pop_reg(s, 1) // X1 = idx
                    arm64_pop_reg(s, 0) // X0 = hdr
                    arm64_synth_emit32(s, 4181723139) // ldr x3, [x0, #16]
                    arm64_emit_add_x(s, 1, 1, 1)
                    arm64_emit_add_x(s, 1, 1, 1)
                    arm64_emit_add_x(s, 1, 1, 1)
                    arm64_emit_add_x(s, 3, 3, 1)     // X3 = data_ptr + idx*8
                    arm64_synth_emit32(s, 4177526882) // str x2, [x3, #0]
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    arm64_emit_movz_x(s, 0, 0, 0)
                return 0

            // ── Intrinsic 8e: push / list_push / ঠেলো (hdr, val -> hdr) ──────────
            if var_name == "push" or var_name == "list_push" or var_name == "ঠেলো"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                if arg_count == 2
                    s.a64_needs_list_push = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1) // X1 = val
                    arm64_pop_reg(s, 0) // X0 = hdr
                    lp_call_off = s.synth_code.len()
                    arm64_emit_bl(s, 0)
                    lp_rel = Arm64CallReloc()
                    lp_rel.a64_cr_patch_offset = lp_call_off
                    lp_rel.a64_cr_target_name = "__list_push"
                    push(s.synth_call_relocs, lp_rel)
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    arm64_emit_movz_x(s, 0, 0, 0)
                return 0

            // ── Intrinsic 9: file_write / ফাইল_লেখো ────────────────────────────
            if var_name == "file_write" or var_name == "ফাইল_লেখো"
                s.a64_needs_file_write = 1
                if arg_count >= 3
                    arm64_pop_reg(s, 2)
                else
                    arm64_emit_movz_x(s, 2, 0, 0)
                if arg_count >= 2
                    arm64_pop_reg(s, 1)
                else
                    arm64_emit_movz_x(s, 1, 0, 0)
                if arg_count >= 1
                    arm64_pop_reg(s, 0)
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                fw_call_off = s.synth_code.len()
                arm64_emit_bl(s, 0)
                fw_rel = Arm64CallReloc()
                fw_rel.a64_cr_patch_offset = fw_call_off
                fw_rel.a64_cr_target_name = "__file_write"
                push(s.synth_call_relocs, fw_rel)
                return 0

            // ── Intrinsic 9b: Dict / HashMap Intrinsics (DICT0 Parity) ──────
            if var_name == "dict" or var_name == "map" or var_name == "অভিধান" or (var_name == "map_new" and arm64_synth_find_fn(s, "map_new") == 0)
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                else
                    arm64_emit_movz_x(s, 0, 16, 0)
                end
                s.a64_needs_dict = 1
                s.synth_needs_alloc = 1
                arm64_synth_emit_call_helper(s, "__dict_new")
                return 0
            end
            if var_name == "has_key" or var_name == "dict_has" or (var_name == "map_has" and arm64_synth_find_fn(s, "map_has") == 0)
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.a64_needs_dict = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__dict_has")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "del_key" or var_name == "dict_del" or (var_name == "map_del" and arm64_synth_find_fn(s, "map_del") == 0)
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.a64_needs_dict = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__dict_del")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "dict_get" or (var_name == "map_get" and arm64_synth_find_fn(s, "map_get") == 0)
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.a64_needs_dict = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__dict_get")
                    s.a64_last_expr_type = "dyn_tagged"
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                    s.a64_last_expr_type = "int"
                end
                return 0
            end
            if var_name == "dict_set" or (var_name == "map_set" and arm64_synth_find_fn(s, "map_set") == 0)
                while arg_count > 3
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 3
                    s.a64_needs_dict = 1
                    s.synth_needs_alloc = 1
                    ds_vtype = "int"
                    if arg_types.len() >= 3
                        ds_vtype = arg_types[2]
                    end
                    if ds_vtype == "float"
                        arm64_emit_movz_x(s, 3, 1, 0)
                    elif ds_vtype == "str"
                        arm64_emit_movz_x(s, 3, 2, 0)
                    else
                        arm64_emit_movz_x(s, 3, 0, 0)
                    end
                    arm64_pop_reg(s, 2)
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__dict_set")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                s.a64_last_expr_type = "int"
                return 0
            end

            // ── Intrinsic 9c: ByteBuffer Intrinsics ─────────────────────────
            if var_name == "buf_new" or var_name == "byte_buf_new" or var_name == "বাফার_তৈরি"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                else
                    arm64_emit_movz_x(s, 0, 64, 0)
                end
                s.a64_needs_buf = 1
                s.synth_needs_alloc = 1
                arm64_synth_emit_call_helper(s, "__buf_new")
                return 0
            end
            if var_name == "buf_write_byte" or var_name == "buf_append_byte" or var_name == "buf_push"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.a64_needs_buf = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__buf_write_byte")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_write_str" or var_name == "buf_append" or var_name == "buf_append_str"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    s.a64_needs_buf = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__buf_write_str")
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_to_str"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    s.a64_needs_buf = 1
                    s.synth_needs_alloc = 1
                    arm64_pop_reg(s, 0)
                    arm64_synth_emit_call_helper(s, "__buf_to_str")
                    s.a64_last_expr_type = "str"
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_len"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                    arm64_emit_ldr_x_off(s, 0, 0, 8)
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_ptr"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                    arm64_emit_ldr_x_off(s, 0, 0, 0)
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_clear"
                while arg_count > 1
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                    arm64_emit_str_x_off(s, 31, 0, 8)
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_get_byte"
                while arg_count > 2
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                if arg_count == 2
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    arm64_emit_ldr_x_off(s, 9, 0, 0)
                    arm64_emit_add_x(s, 9, 9, 1)
                    arm64_emit_ldrb_off(s, 0, 9, 0)
                else
                    while arg_count > 0
                        arm64_pop_reg(s, 1)
                        arg_count = arg_count - 1
                    end
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "buf_free"
                while arg_count > 0
                    arm64_pop_reg(s, 1)
                    arg_count = arg_count - 1
                end
                arm64_emit_movz_x(s, 0, 0, 0)
                return 0
            end
            // ── Cross-Arch ARM64 Silicon Hardware Intrinsics (MMIO, Barriers, Stack Trace) ──
            if var_name == "mmio_r8" or var_name == "mmio_r16" or var_name == "mmio_r32" or var_name == "mmio_r64"
                while arg_count > 1 arm64_pop_reg(s, 1) arg_count = arg_count - 1 end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                    if var_name == "mmio_r8" arm64_synth_emit32(s, 960495616)         // ldrb w0, [x0]
                    elif var_name == "mmio_r16" arm64_synth_emit32(s, 2034237440)     // ldrh w0, [x0]
                    elif var_name == "mmio_r32" arm64_synth_emit32(s, 3107979264)     // ldr  w0, [x0]
                    else arm64_synth_emit32(s, 4181721088)                            // ldr  x0, [x0]
                    end
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                return 0
            end
            if var_name == "mmio_w8" or var_name == "mmio_w16" or var_name == "mmio_w32" or var_name == "mmio_w64"
                while arg_count > 2 arm64_pop_reg(s, 1) arg_count = arg_count - 1 end
                if arg_count == 2
                    arm64_pop_reg(s, 1)
                    arm64_pop_reg(s, 0)
                    if var_name == "mmio_w8" arm64_synth_emit32(s, 956301313)         // strb w1, [x0]
                    elif var_name == "mmio_w16" arm64_synth_emit32(s, 2030043137)     // strh w1, [x0]
                    elif var_name == "mmio_w32" arm64_synth_emit32(s, 3103784961)     // str  w1, [x0]
                    else arm64_synth_emit32(s, 4177526785)                            // str  x1, [x0]
                    end
                else
                    while arg_count > 0 arm64_pop_reg(s, 1) arg_count = arg_count - 1 end
                end
                arm64_emit_movz_x(s, 0, 0, 0)
                return 0
            end
            if var_name == "psci_call"
                // WHY: ARM64 PSCI v0.2+ hypervisor call (`hvc #0` = 0xD4000002) for EL1 poweroff/reboot/CPU_ON
                // on QEMU `virt` and ARMv8 SoCs. Passes fn_id..a3 in x0..x3 with ZERO Linux `svc #0`!
                if arg_count > 4
                    while arg_count > 4 arm64_pop_reg(s, 9) arg_count = arg_count - 1 end
                end
                if arg_count >= 4 arm64_pop_reg(s, 3) else arm64_emit_movz_x(s, 3, 0, 0) end
                if arg_count >= 3 arm64_pop_reg(s, 2) else arm64_emit_movz_x(s, 2, 0, 0) end
                if arg_count >= 2 arm64_pop_reg(s, 1) else arm64_emit_movz_x(s, 1, 0, 0) end
                if arg_count >= 1 arm64_pop_reg(s, 0) else arm64_emit_movz_x(s, 0, 0, 0) end
                arm64_synth_emit32(s, 3556769794) // hvc #0 (0xD4000002)
                return 0
            end
            if var_name == "cpu_dmb" or var_name == "cpu_dsb" or var_name == "cpu_isb" or var_name == "cpu_wfi" or var_name == "cpu_nop" or var_name == "cpu_halt" or var_name == "cpu_fence"
                while arg_count > 0 arm64_pop_reg(s, 1) arg_count = arg_count - 1 end
                if var_name == "cpu_dmb" or var_name == "cpu_fence" arm64_synth_emit32(s, 3573759935) // dmb sy
                elif var_name == "cpu_dsb" arm64_synth_emit32(s, 3573759903) // dsb sy
                elif var_name == "cpu_isb" arm64_synth_emit32(s, 3573759967) // isb
                elif var_name == "cpu_wfi" arm64_synth_emit32(s, 3573751935) // wfi
                elif var_name == "cpu_nop" arm64_synth_emit32(s, 3573751839) // nop
                else
                    arm64_synth_emit32(s, 3573751935) // wfi
                    arm64_emit_b(s, 0 - 1)            // b -4
                end
                arm64_emit_movz_x(s, 0, 0, 0)
                return 0
            end
            if var_name == "f64_from_bits" or var_name == "f64_to_bits"
                while arg_count > 1
                    arm64_pop_reg(s, 9)
                    arg_count = arg_count - 1
                end
                if arg_count == 1
                    arm64_pop_reg(s, 0)
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                end
                if var_name == "f64_from_bits"
                    s.a64_last_expr_type = "float"
                else
                    s.a64_last_expr_type = "int"
                end
                s.a64_last_is_uint = 0
                return 0
            end
            if var_name == "str" or var_name == "to_str" or var_name == "স্ট্রিং" or var_name == "uint_to_str" or var_name == "float_to_str"
                s.a64_needs_str_helpers = 1
                s.synth_needs_alloc = 1
                if arg_count >= 1
                    while arg_count > 1
                        arm64_pop_reg(s, 9)
                        arg_count = arg_count - 1
                    end
                    // Note: X1 (dyn_tagged tag) is untouched by arm64_push_reg / arm64_pop_reg!
                    arm64_pop_reg(s, 0)
                    a0_t = "int"
                    a0_u = 0
                    if arg_types.len() >= 1 a0_t = arg_types[0] end
                    if arg_is_uints.len() >= 1 a0_u = arg_is_uints[0] end
                    if var_name == "float_to_str" or a0_t == "float"
                        arm64_synth_emit_call_helper(s, "__float_to_str")
                    elif var_name == "uint_to_str" or a0_t == "uint" or a0_u == 1
                        arm64_synth_emit_call_helper(s, "__uint_to_str")
                    elif a0_t == "str"
                        // Already a cstr pointer in X0
                    elif a0_t == "dyn_tagged"
                        arm64_synth_emit_call_helper(s, "__tagged_to_str")
                    else
                        arm64_synth_emit_call_helper(s, "__int_to_str")
                    end
                else
                    arm64_emit_load_rodata_str(s, 0, "")
                end
                s.a64_last_expr_type = "str"
                s.a64_last_is_uint = 0
                return 0
            end
            if var_name == "stack_trace" or var_name == "backtrace" or var_name == "স্ট্যাক_ট্রেস"
                while arg_count > 0 arm64_pop_reg(s, 1) arg_count = arg_count - 1 end
                if s.a64_freestanding == 1
                    arm64_emit_load_rodata_str(s, 0, "  at " + s.a64_cur_fn_name + " (freestanding)\n")
                else
                    s.a64_needs_stack_trace = 1
                    s.a64_needs_buf = 1
                    s.synth_needs_alloc = 1
                    arm64_synth_emit_call_helper(s, "_lipi_stack_trace")
                end
                s.a64_last_expr_type = "str"
                return 0
            end
            // ── ADT Tagged Enum Constructor: Ok(v), Err(e), Some(v), UserVariant(...) ──
            ae_idx = arm64_enum_find_idx(s, var_name)
            if ae_idx >= 0
                ae_tag = s.a64_enum_tags[ae_idx]
                ae_sz = (arg_count + 1) * 8
                if ae_sz < 16 ae_sz = 16 end
                s.synth_needs_alloc = 1
                arm64_emit_mov_imm64(s, 0, ae_sz)
                arm64_synth_emit_call_alloc(s)
                arm64_emit_mov_reg(s, 9, 0)
                arm64_emit_mov_imm64(s, 10, ae_tag)
                arm64_emit_str_x_off(s, 10, 9, 0)
                ai_e = arg_count - 1
                while ai_e >= 0
                    arm64_pop_reg(s, 1)
                    arm64_emit_str_x_off(s, 1, 9, (ai_e + 1) * 8)
                    ai_e = ai_e - 1
                end
                arm64_emit_mov_reg(s, 0, 9)
                return 0
            end

            // ── Struct / Union Constructor: StructName(...) ─────────────────
            sdef = arm64_synth_find_struct(s, var_name)
            if sdef != 0
                fcount = sdef.sd_fields.len()
                alloc_sz = (fcount + 1) * 8
                if alloc_sz < 32
                    alloc_sz = 32
                // Allocate +16B header so [ptr - 8] stores sovereign type tag while ptr stays 16B-aligned
                arm64_emit_mov_imm64(s, 0, alloc_sz + 16)
                arm64_synth_emit_call_alloc(s)
                arm64_emit_mov_imm64(s, 10, (1415139397 << 32) | sdef.a64_sd_type_id)
                arm64_emit_str_x_off(s, 10, 0, 8)
                arm64_emit_add_imm(s, 0, 0, 16)
                // Struct/union pointer is now in X0
                if arg_count > 0
                    arm64_emit_mov_reg(s, 9, 0) // X9 = struct ptr (keep SP pointing to args)
                    ai = arg_count - 1
                    while ai >= 0
                        arm64_pop_reg(s, 1) // pop field value into X1
                        scaled_ai = ai & 4095
                        if sdef.a64_sd_is_union == 1
                            scaled_ai = 0
                        end
                        st_word = 4177526784 | (scaled_ai << 10) | (9 << 5) | 1
                        arm64_synth_emit32(s, st_word)
                        ai = ai - 1
                    arm64_emit_mov_reg(s, 0, 9) // return struct pointer in X0
                cur_struct = var_name
                s.a64_last_struct = var_name
            else
                // ── Variadic Packing & Default Argument Filling ──
                fsig = arm64_synth_find_fn_sig(s, var_name)
                if fsig != 0
                    if fsig.a64_sig_is_variadic == 1
                        fixed_n = fsig.a64_sig_param_count - 1
                        var_cnt = arg_count - fixed_n
                        if var_cnt < 0 var_cnt = 0 end
                        s.a64_needs_list_create = 1
                        s.synth_needs_alloc = 1
                        arm64_emit_mov_imm64(s, 0, var_cnt)
                        vl_off = s.synth_code.len()
                        arm64_emit_bl(s, 0)
                        vl_rel = Arm64CallReloc()
                        vl_rel.a64_cr_patch_offset = vl_off
                        vl_rel.a64_cr_target_name = "__list_create"
                        push(s.synth_call_relocs, vl_rel)
                        if var_cnt > 0
                            arm64_emit_mov_reg(s, 9, 0)
                            arm64_synth_emit32(s, 4181721088 | (2 << 10) | (9 << 5) | 10) // ldr x10, [x9, #16]
                            vi_v = var_cnt - 1
                            while vi_v >= 0
                                arm64_pop_reg(s, 1)
                                arm64_emit_mov_imm64(s, 2, vi_v * 8)
                                arm64_emit_add_x(s, 2, 10, 2)
                                arm64_synth_emit32(s, 4177526784 | (0 << 10) | (2 << 5) | 1) // str x1, [x2, #0]
                                vi_v = vi_v - 1
                            end
                            arm64_emit_mov_reg(s, 0, 9)
                        end
                        arm64_push_reg(s, 0)
                        arg_count = fixed_n + 1
                    elif arg_count < fsig.a64_sig_param_count and s.a64_source_toks != 0
                        def_i = arg_count
                        while def_i < fsig.a64_sig_param_count
                            def_st = fsig.a64_sig_def_starts[def_i]
                            if def_st >= 0
                                def_box = [def_st]
                                arm64_synth_compile_expr(s, s.a64_source_toks, def_box)
                                arm64_push_reg(s, 0)
                                arg_count = arg_count + 1
                            else
                                break
                            end
                            def_i = def_i + 1
                        end
                    end
                end
                // ── Normal Function Call: AAPCS64 register args (X0..X7) + >8 stack args ([sp+0], [sp+8], ...) ──
                a64_cleanup_bytes = 0
                if arg_count <= 8
                    if arg_count >= 8
                        arm64_pop_reg(s, 7)
                    if arg_count >= 7
                        arm64_pop_reg(s, 6)
                    if arg_count >= 6
                        arm64_pop_reg(s, 5)
                    if arg_count >= 5
                        arm64_pop_reg(s, 4)
                    if arg_count >= 4
                        arm64_pop_reg(s, 3)
                    if arg_count >= 3
                        arm64_pop_reg(s, 2)
                    if arg_count >= 2
                        arm64_pop_reg(s, 1)
                    if arg_count >= 1
                        arm64_pop_reg(s, 0)
                else
                    // WHY: All `arg_count` arguments were pushed 16B-apart; arg_k sits at [X9 + (arg_count - 1 - k)*16].
                    // Allocate 16B-aligned outgoing stack arg area below X9 so source and destination NEVER overlap!
                    n_stack = arg_count - 8
                    stack_pad = ((n_stack + 1) / 2) * 16
                    a64_cleanup_bytes = (arg_count * 16) + stack_pad
                    arm64_emit_add_imm(s, 9, 31, 0) // X9 = sp (saved push base)
                    ri_a = 0
                    while ri_a < 8
                        arm64_emit_ldr_x_off(s, ri_a, 9, (arg_count - 1 - ri_a) * 16)
                        ri_a = ri_a + 1
                    end
                    arm64_emit_sub_imm(s, 31, 31, stack_pad)
                    s.a64_sp_delta = s.a64_sp_delta + stack_pad
                    sj_a = 0
                    while sj_a < n_stack
                        arm64_emit_ldr_x_off(s, 10, 9, (n_stack - 1 - sj_a) * 16)
                        arm64_emit_str_x_off(s, 10, 31, sj_a * 8)
                        sj_a = sj_a + 1
                    end
                end

                // ── Indirect Closure/Fn-Ptr Call vs Direct Named Function Call ───
                lv_call = arm64_find_local_var(s, var_name)
                if lv_call != 0
                    arm64_emit_ldr_reg_sp(s, 11, lv_call.lv_offset)
                    if lv_call.a64_lv_is_boxed == 1
                        arm64_emit_ldr_x_off(s, 11, 11, 0)
                    end
                    arm64_emit_indirect_call_x11(s)
                else
                    // Emit BL instruction with relocation placeholder
                    if var_name == "main" or var_name == "মূল"
                        if s.a64_in_function == 0
                            s.a64_called_main = 1
                    call_off = s.synth_code.len()
                    arm64_emit_bl(s, 0)

                    call_rel = Arm64CallReloc()
                    call_rel.a64_cr_patch_offset = call_off
                    call_rel.a64_cr_target_name = var_name
                    push(s.synth_call_relocs, call_rel)
                end

                if a64_cleanup_bytes > 0
                    arm64_emit_add_imm(s, 31, 31, a64_cleanup_bytes)
                    if s.a64_sp_delta >= a64_cleanup_bytes
                        s.a64_sp_delta = s.a64_sp_delta - a64_cleanup_bytes
                    else
                        s.a64_sp_delta = 0
                    end
                end

                // WHY: Check callee-saved X27 exception flag after call returns. If active, jump to
                // the innermost try/catch handler or immediately unwind the current stack frame.
                if s.a64_try_patches.len() > 0
                    arm64_emit_cmp_x(s, 27, 31)
                    exc_bne_off = s.synth_code.len()
                    arm64_emit_b_cond(s, 1, 0)
                    active_tp = s.a64_try_patches[s.a64_try_patches.len() - 1]
                    push(active_tp, [exc_bne_off, 1])
                elif s.a64_in_function == 1
                    arm64_emit_cmp_x(s, 27, 31)
                    skip_eq_off = s.synth_code.len()
                    arm64_emit_b_cond(s, 0, 0)
                    arm64_emit_defers(s, toks)
                    arm64_emit_epilogue(s)
                    skip_words = (s.synth_code.len() - skip_eq_off) / 4
                    arm64_synth_patch_u32(s, skip_eq_off, 1409286144 | ((skip_words & 524287) << 5) | 0)
                elif s.a64_freestanding == 0
                    // WHY: Uncaught top-level call exception prints "Uncaught exception: <val>" and exits 1.
                    s.a64_needs_uncaught_throw = 1
                    arm64_emit_cmp_x(s, 27, 31)
                    skip_ut_off = s.synth_code.len()
                    arm64_emit_b_cond(s, 0, 0)
                    arm64_synth_emit_call_helper(s, "__uncaught_throw")
                    arm64_patch_b_cond(s, skip_ut_off, 0, s.synth_code.len())
                end
                if fsig != 0 and fsig.a64_sig_ret_type == "float"
                    s.a64_last_expr_type = "float"
                    s.a64_last_is_uint = 0
                elif fsig != 0 and fsig.a64_sig_ret_type == "uint"
                    s.a64_last_expr_type = "int"
                    s.a64_last_is_uint = 1
                elif fsig != 0 and fsig.a64_sig_ret_type == "str"
                    s.a64_last_expr_type = "str"
                    s.a64_last_is_uint = 0
                else
                    s.a64_last_expr_type = "dyn_tagged"
                end
            end
        else
            // Unit ADT Variant (e.g. None or zero-arity enum variant) vs Local Variable Load
            ae_u = arm64_enum_find_idx(s, var_name)
            lv_rd = arm64_find_local_var(s, var_name)
            if lv_rd != 0
                arm64_emit_ldr_reg_sp(s, 0, lv_rd.lv_offset)
                if lv_rd.a64_lv_is_boxed == 1
                    arm64_emit_ldr_x_off(s, 0, 0, 0)
                end
                cur_struct = lv_rd.a64_lv_struct_type
                s.a64_last_is_uint = lv_rd.a64_lv_is_uint
                if lv_rd.a64_lv_prim_type != ""
                    s.a64_last_expr_type = lv_rd.a64_lv_prim_type
                else
                    s.a64_last_expr_type = "int"
                end
                if s.a64_last_expr_type == "dyn_tagged" and lv_rd.a64_lv_tag_off > 0
                    arm64_emit_ldr_reg_sp(s, 1, lv_rd.a64_lv_tag_off)
                end
            elif ae_u >= 0
                s.synth_needs_alloc = 1
                arm64_emit_mov_imm64(s, 0, 16)
                arm64_synth_emit_call_alloc(s)
                arm64_emit_mov_imm64(s, 10, s.a64_enum_tags[ae_u])
                arm64_emit_str_x_off(s, 10, 0, 0)
                arm64_emit_str_x_off(s, 31, 0, 8)
            else
                arm64_emit_movz_x(s, 0, 0, 0)
            end
        end

    // 4. Parenthesized expression: ( expr )
    if handled == 0 and k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1)
        arm64_synth_compile_expr(s, toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_pos + 1)
        handled = 1
        cur_struct = s.a64_last_struct

    if handled == 0
        // Fallback: advance and clear X0
        list_set(pos_box, 0, pos + 1)
        arm64_emit_movz_x(s, 0, 0, 0)
        s.a64_last_struct = ""
        return 0

    // 5. Postfix operations: .field, .len(), .push(x), [index]
    while get(pos_box, 0) < toks.len()
        cp = get(pos_box, 0)
        ct = toks[cp]
        if ct.tok_kind == TOK_DOT() or ct.tok_text == "."
            list_set(pos_box, 0, cp + 1)
            if get(pos_box, 0) < toks.len() and arm64_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                fn_tok = toks[get(pos_box, 0)]
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                np = get(pos_box, 0)
                if np < toks.len() and toks[np].tok_kind == TOK_LPAREN()
                    list_set(pos_box, 0, np + 1)
                    // Always push receiver X0 before evaluating explicit args (uniform 0..7 arg ABI)
                    arm64_push_reg(s, 0)
                    m_args = 0
                    while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                        arm64_synth_compile_expr(s, toks, pos_box)
                        arm64_push_reg(s, 0)
                        m_args = m_args + 1
                        cur_mp = get(pos_box, 0)
                        if cur_mp < toks.len() and toks[cur_mp].tok_kind == TOK_COMMA()
                            list_set(pos_box, 0, cur_mp + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)
                    if fn_tok.tok_text == "len" or fn_tok.tok_text == "length"
                        while m_args > 0
                            arm64_pop_reg(s, 1)
                            m_args = m_args - 1
                        arm64_pop_reg(s, 0)
                        arm64_synth_emit32(s, 4181721088) // ldr x0, [x0, #0]
                        s.a64_last_expr_type = "int"
                    elif fn_tok.tok_text == "push"
                        while m_args > 1
                            arm64_pop_reg(s, 1)
                            m_args = m_args - 1
                        if m_args == 1
                            s.a64_needs_list_push = 1
                            s.synth_needs_alloc = 1
                            arm64_pop_reg(s, 1)
                            arm64_pop_reg(s, 0)
                            mp_off = s.synth_code.len()
                            arm64_emit_bl(s, 0)
                            mp_rel = Arm64CallReloc()
                            mp_rel.a64_cr_patch_offset = mp_off
                            mp_rel.a64_cr_target_name = "__list_push"
                            push(s.synth_call_relocs, mp_rel)
                        else
                            arm64_pop_reg(s, 0)
                            arm64_emit_movz_x(s, 0, 0, 0)
                        end
                    else
                        // General trait/impl method call & sovereign dyn Trait runtime dispatch!
                        tot_m = 1 + m_args
                        while tot_m > 8
                            arm64_pop_reg(s, 9)
                            tot_m = tot_m - 1
                        end
                        if tot_m >= 8 arm64_pop_reg(s, 7) end
                        if tot_m >= 7 arm64_pop_reg(s, 6) end
                        if tot_m >= 6 arm64_pop_reg(s, 5) end
                        if tot_m >= 5 arm64_pop_reg(s, 4) end
                        if tot_m >= 4 arm64_pop_reg(s, 3) end
                        if tot_m >= 3 arm64_pop_reg(s, 2) end
                        if tot_m >= 2 arm64_pop_reg(s, 1) end
                        if tot_m >= 1 arm64_pop_reg(s, 0) end
                        m_nm = fn_tok.tok_text
                        direct_tgt = ""
                        if cur_struct != "" and str_starts_with(cur_struct, "dyn ") == 0 and arm64_synth_has_impl_method(s, cur_struct, m_nm) == 1
                            direct_tgt = cur_struct + "_" + m_nm
                        end
                        if direct_tgt != ""
                            mc_off = s.synth_code.len()
                            arm64_emit_bl(s, 0)
                            mc_rel = Arm64CallReloc()
                            mc_rel.a64_cr_patch_offset = mc_off
                            mc_rel.a64_cr_target_name = direct_tgt
                            push(s.synth_call_relocs, mc_rel)
                        else
                            m_cands = arm64_synth_find_method_candidates(s, m_nm)
                            if m_cands.len() == 1
                                mc_off = s.synth_code.len()
                                arm64_emit_bl(s, 0)
                                mc_rel = Arm64CallReloc()
                                mc_rel.a64_cr_patch_offset = mc_off
                                mc_rel.a64_cr_target_name = m_cands[0][1]
                                push(s.synth_call_relocs, mc_rel)
                            elif m_cands.len() >= 2
                                // Sovereign dyn Trait runtime dispatch: inspect [X0 - 8] type tag
                                arm64_emit_null_guard_reg(s, toks, 0)
                                arm64_emit_ldur_x_off(s, 9, 0, 0 - 8)
                                done_jumps = list()
                                dci = 0
                                while dci < m_cands.len()
                                    dc = m_cands[dci]
                                    arm64_emit_mov_imm64(s, 10, (1415139397 << 32) | dc[0])
                                    arm64_emit_cmp_x(s, 9, 10)
                                    bne_next = s.synth_code.len()
                                    arm64_emit_b_cond(s, 1, 0)
                                    mc_off = s.synth_code.len()
                                    arm64_emit_bl(s, 0)
                                    mc_rel = Arm64CallReloc()
                                    mc_rel.a64_cr_patch_offset = mc_off
                                    mc_rel.a64_cr_target_name = dc[1]
                                    push(s.synth_call_relocs, mc_rel)
                                    j_done = s.synth_code.len()
                                    arm64_emit_b(s, 0)
                                    push(done_jumps, j_done)
                                    arm64_patch_b_cond(s, bne_next, 1, s.synth_code.len())
                                    dci = dci + 1
                                end
                                arm64_emit_movz_x(s, 0, 0, 0)
                                arm64_emit_movz_x(s, 1, 0, 0)
                                end_disp_off = s.synth_code.len()
                                dji = 0
                                while dji < done_jumps.len()
                                    arm64_patch_b(s, done_jumps[dji], end_disp_off)
                                    dji = dji + 1
                                end
                            else
                                mc_off = s.synth_code.len()
                                arm64_emit_bl(s, 0)
                                mc_rel = Arm64CallReloc()
                                mc_rel.a64_cr_patch_offset = mc_off
                                mc_rel.a64_cr_target_name = m_nm
                                push(s.synth_call_relocs, mc_rel)
                            end
                        end
                        if s.a64_try_patches.len() > 0
                            arm64_emit_cmp_x(s, 27, 31)
                            m_exc_bne = s.synth_code.len()
                            arm64_emit_b_cond(s, 1, 0)
                            push(s.a64_try_patches[s.a64_try_patches.len() - 1], [m_exc_bne, 1])
                        elif s.a64_in_function == 1
                            arm64_emit_cmp_x(s, 27, 31)
                            m_skip_eq = s.synth_code.len()
                            arm64_emit_b_cond(s, 0, 0)
                            arm64_emit_defers(s, toks)
                            arm64_emit_epilogue(s)
                            arm64_patch_b_cond(s, m_skip_eq, 0, s.synth_code.len())
                        elif s.a64_freestanding == 0
                            s.a64_needs_uncaught_throw = 1
                            arm64_emit_cmp_x(s, 27, 31)
                            m_skip_ut = s.synth_code.len()
                            arm64_emit_b_cond(s, 0, 0)
                            arm64_synth_emit_call_helper(s, "__uncaught_throw")
                            arm64_patch_b_cond(s, m_skip_ut, 0, s.synth_code.len())
                        end
                        s.a64_last_expr_type = "dyn_tagged"
                    end
                    cur_struct = ""
                else
                    arm64_emit_null_guard_reg(s, toks, 0)
                    f_off = arm64_synth_get_field_offset(s, cur_struct, fn_tok.tok_text)
                    f_type_a64 = arm64_synth_get_field_type(s, cur_struct, fn_tok.tok_text)
                    scaled_fo = (f_off / 8) & 4095
                    ldr_word = 4181721088 | (scaled_fo << 10)
                    arm64_synth_emit32(s, ldr_word)
                    cur_struct = ""
                    if arm64_is_float_type(f_type_a64) == 1
                        s.a64_last_expr_type = "float"
                        s.a64_last_is_uint = 0
                    elif arm64_is_uint_type(f_type_a64) == 1
                        s.a64_last_expr_type = "int"
                        s.a64_last_is_uint = 1
                    elif f_type_a64 == "str" or f_type_a64 == "string"
                        s.a64_last_expr_type = "str"
                        s.a64_last_is_uint = 0
                    else
                        s.a64_last_expr_type = "int"
                        s.a64_last_is_uint = 0
                    end
            else
                break
        elif ct.tok_kind == TOK_LBRACKET()
            list_set(pos_box, 0, cp + 1)
            arm64_push_reg(s, 0) // Save hdr
            arm64_synth_compile_expr(s, toks, pos_box) // X0 = idx/key
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            arm64_emit_mov_reg(s, 1, 0)     // X1 = idx/key
            arm64_pop_reg(s, 0)             // X0 = hdr
            s.a64_needs_dict = 1
            s.synth_needs_alloc = 1
            arm64_synth_emit_call_helper(s, "__container_get")
            s.a64_last_expr_type = "dyn_tagged"
            if s.a64_try_patches.len() > 0
                arm64_emit_cmp_x(s, 27, 31)
                npe_bne_off = s.synth_code.len()
                arm64_emit_b_cond(s, 1, 0)
                push(s.a64_try_patches[s.a64_try_patches.len() - 1], [npe_bne_off, 1])
            elif s.a64_in_function == 1
                arm64_emit_cmp_x(s, 27, 31)
                npe_skip_eq = s.synth_code.len()
                arm64_emit_b_cond(s, 0, 0)
                arm64_emit_defers(s, toks)
                arm64_emit_epilogue(s)
                arm64_patch_b_cond(s, npe_skip_eq, 0, s.synth_code.len())
            elif s.a64_freestanding == 0
                s.a64_needs_uncaught_throw = 1
                arm64_emit_cmp_x(s, 27, 31)
                npe_skip_ut = s.synth_code.len()
                arm64_emit_b_cond(s, 0, 0)
                arm64_synth_emit_call_helper(s, "__uncaught_throw")
                arm64_patch_b_cond(s, npe_skip_ut, 0, s.synth_code.len())
            end
            cur_struct = ""
        elif ct.tok_kind == TOK_QUERY() or (ct.tok_kind != TOK_STR() and ct.tok_text == "?")
            // Postfix `?` Result/Option propagation: if tag == Err(1002) or None(1004), early return X0; else unwrap [X0+8]
            list_set(pos_box, 0, cp + 1)
            arm64_emit_ldr_x_off(s, 9, 0, 0)
            arm64_emit_movz_x(s, 10, 1002, 0)
            arm64_emit_cmp_x(s, 9, 10)
            beq_q_ret1 = s.synth_code.len()
            arm64_emit_b_cond(s, 0, 0)
            arm64_emit_movz_x(s, 10, 1004, 0)
            arm64_emit_cmp_x(s, 9, 10)
            bne_q_ok = s.synth_code.len()
            arm64_emit_b_cond(s, 1, 0)
            q_ret_off = s.synth_code.len()
            arm64_patch_b_cond(s, beq_q_ret1, 0, q_ret_off)
            arm64_emit_defers(s, toks)
            arm64_emit_epilogue(s)
            q_ok_off = s.synth_code.len()
            arm64_patch_b_cond(s, bne_q_ok, 1, q_ok_off)
            arm64_emit_ldr_x_off(s, 0, 0, 8)
            cur_struct = ""
        elif ct.tok_kind == TOK_LPAREN() and cp > 0 and ct.tok_span.span_start_line == toks[cp - 1].tok_span.span_start_line
            list_set(pos_box, 0, cp + 1)
            arm64_push_reg(s, 0) // Save callee closure/fn_ptr
            p_argc = 0
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                arm64_synth_compile_expr(s, toks, pos_box)
                arm64_push_reg(s, 0)
                p_argc = p_argc + 1
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            if p_argc >= 8 arm64_pop_reg(s, 7) end
            if p_argc >= 7 arm64_pop_reg(s, 6) end
            if p_argc >= 6 arm64_pop_reg(s, 5) end
            if p_argc >= 5 arm64_pop_reg(s, 4) end
            if p_argc >= 4 arm64_pop_reg(s, 3) end
            if p_argc >= 3 arm64_pop_reg(s, 2) end
            if p_argc >= 2 arm64_pop_reg(s, 1) end
            if p_argc >= 1 arm64_pop_reg(s, 0) end
            arm64_pop_reg(s, 11) // X11 = callee
            arm64_emit_indirect_call_x11(s)
            cur_struct = ""
        else
            break
    s.a64_last_struct = cur_struct
    return 0

// ── 7. Expression Synthesizer (Pratt / Operator Precedence Hierarchy) ──────────

fn arm64_emit_fp_arith_op s k
    // WHY: Emits IEEE-754 binary64 hardware arithmetic on d0 (LHS) and d1 (RHS), writing bits to X0.
    if k == TOK_PLUS()
        arm64_emit_fadd_d(s, 0, 0, 1)
    elif k == TOK_MINUS()
        arm64_emit_fsub_d(s, 0, 0, 1)
    elif k == TOK_STAR()
        arm64_emit_fmul_d(s, 0, 0, 1)
    elif k == TOK_SLASH()
        arm64_emit_fdiv_d(s, 0, 0, 1)
    elif k == TOK_PERCENT()
        // IEEE-754 fmod: d0 - trunc(d0 / d1) * d1
        arm64_emit_fdiv_d(s, 2, 0, 1)
        arm64_emit_frintz_d(s, 2, 2)
        arm64_emit_fmul_d(s, 2, 2, 1)
        arm64_emit_fsub_d(s, 0, 0, 2)
    end
    arm64_emit_fmov_x_d(s, 0, 0)
    return 0

fn arm64_emit_fcmp_cond_x0 s k
    // WHY: Emits IEEE-754 NaN-safe AArch64 FP comparison (`fcmp d0, d1`) producing 0/1 in X0.
    // On NaN: NZCV = 0011 -> EQ=0, NE=1, MI(N=1)=0, LS(C=0|Z=1)=0, GT(Z=0&N=V)=0, GE(N=V)=0.
    arm64_emit_fcmp_d(s, 0, 1)
    cc = 0
    if k == TOK_EQ() cc = 0
    elif k == TOK_NEQ() cc = 1
    elif k == TOK_LT() cc = 4
    elif k == TOK_LTE() cc = 9
    elif k == TOK_GT() cc = 12
    elif k == TOK_GTE() cc = 10
    end
    arm64_emit_b_cond(s, cc, 3)
    arm64_emit_movz_x(s, 0, 0, 0)
    arm64_emit_b(s, 2)
    arm64_emit_movz_x(s, 0, 1, 0)
    return 0

fn arm64_synth_expr_multiplicative s toks pos_box
    // WHY: Pratt precedence level 1 for high-precedence arithmetic (*, /, %) with hardware IEEE-754 f64.
    arm64_synth_expr_primary(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind
        if k != TOK_STAR() and k != TOK_SLASH() and k != TOK_PERCENT()
            break
        list_set(pos_box, 0, pos + 1) // Consume operator
        lhs_u = s.a64_last_is_uint
        lhs_t = s.a64_last_expr_type

        // Push left operand (X0) to stack (plus X1 tag if dyn_tagged)
        arm64_push_reg(s, 0)
        if lhs_t == "dyn_tagged"
            arm64_push_reg(s, 1)
        end

        // Evaluate right operand into X0
        arm64_synth_expr_primary(s, toks, pos_box)
        rhs_u = s.a64_last_is_uint
        rhs_t = s.a64_last_expr_type

        if lhs_t == "float" or rhs_t == "float"
            if rhs_t == "dyn_tagged"
                arm64_emit_mov_reg(s, 11, 1)
            end
            arm64_emit_mov_reg(s, 10, 0)
            if lhs_t == "dyn_tagged"
                arm64_pop_reg(s, 9)
            end
            arm64_pop_reg(s, 0)
            arm64_emit_load_fp_reg(s, 0, 0, lhs_t, lhs_u, 9)
            arm64_emit_load_fp_reg(s, 1, 10, rhs_t, rhs_u, 11)
            arm64_emit_fp_arith_op(s, k)
            s.a64_last_is_uint = 0
            s.a64_last_expr_type = "float"
        elif lhs_t == "dyn_tagged" or rhs_t == "dyn_tagged"
            if rhs_t == "dyn_tagged"
                arm64_emit_mov_reg(s, 11, 1)
            else
                arm64_emit_movz_x(s, 11, 0, 0)
            end
            arm64_emit_mov_reg(s, 10, 0)
            if lhs_t == "dyn_tagged"
                arm64_pop_reg(s, 9)
            else
                arm64_emit_movz_x(s, 9, 0, 0)
            end
            arm64_pop_reg(s, 0)
            arm64_emit_mov_reg(s, 1, 10)
            arm64_emit_movz_x(s, 12, 1, 0)
            arm64_emit_cmp_x(s, 9, 12)
            beq_dm_fp1 = s.synth_code.len()
            arm64_emit_b_cond(s, 0, 0)
            arm64_emit_cmp_x(s, 11, 12)
            beq_dm_fp2 = s.synth_code.len()
            arm64_emit_b_cond(s, 0, 0)
            if k == TOK_STAR()
                arm64_emit_mul_x(s, 0, 0, 1)
            elif k == TOK_SLASH()
                if lhs_u == 1 or rhs_u == 1 arm64_emit_udiv_x(s, 0, 0, 1) else arm64_emit_sdiv_x(s, 0, 0, 1) end
            elif k == TOK_PERCENT()
                if lhs_u == 1 or rhs_u == 1 arm64_emit_udiv_x(s, 2, 0, 1) else arm64_emit_sdiv_x(s, 2, 0, 1) end
                arm64_emit_mul_x(s, 2, 2, 1)
                arm64_emit_sub_x(s, 0, 0, 2)
                // WHY: Guard dyn_tagged `x % 0 == 0` branchlessly matching non-tagged ARM64/x86_64/RV64/WASM.
                arm64_emit_cmp_x(s, 1, 31)
                arm64_synth_emit32(s, 2592080864) // csel x0, xzr, x0, eq
            end
            arm64_emit_movz_x(s, 1, 0, 0)
            jmp_dm_done = s.synth_code.len()
            arm64_emit_b(s, 0)
            dm_fp_off = s.synth_code.len()
            arm64_patch_b_cond(s, beq_dm_fp1, 0, dm_fp_off)
            arm64_patch_b_cond(s, beq_dm_fp2, 0, dm_fp_off)
            arm64_emit_load_fp_reg(s, 0, 0, "dyn_tagged", lhs_u, 9)
            arm64_emit_load_fp_reg(s, 1, 10, "dyn_tagged", rhs_u, 11)
            arm64_emit_fp_arith_op(s, k)
            arm64_emit_movz_x(s, 1, 1, 0)
            arm64_patch_b(s, jmp_dm_done, s.synth_code.len())
            s.a64_last_is_uint = 0
            s.a64_last_expr_type = "dyn_tagged"
        else
            // Move right operand to X1, pop left operand back into X0
            arm64_emit_mov_reg(s, 1, 0)
            arm64_pop_reg(s, 0)

            if k == TOK_STAR()
                arm64_emit_mul_x(s, 0, 0, 1)
            elif k == TOK_SLASH()
                if lhs_u == 1 or rhs_u == 1
                    arm64_emit_udiv_x(s, 0, 0, 1)
                else
                    arm64_emit_sdiv_x(s, 0, 0, 1)
                end
            elif k == TOK_PERCENT()
                // Remainder in AArch64: X2 = X0 / X1; X2 = X2 * X1; X0 = X0 - X2
                // WHY: Guard divisor == 0 branchlessly (`cmp x1, xzr; csel x0, xzr, x0, eq`) so `x % 0 == 0`
                // matches x86_64/RV64/WASM instead of AArch64's `x - 0*0 == x`.
                if lhs_u == 1 or rhs_u == 1
                    arm64_emit_udiv_x(s, 2, 0, 1)
                else
                    arm64_emit_sdiv_x(s, 2, 0, 1)
                end
                arm64_emit_mul_x(s, 2, 2, 1)
                arm64_emit_sub_x(s, 0, 0, 2)
                arm64_emit_cmp_x(s, 1, 31)
                arm64_synth_emit32(s, 2592080864) // csel x0, xzr, x0, eq
            end
            if lhs_u == 1 or rhs_u == 1 s.a64_last_is_uint = 1 else s.a64_last_is_uint = 0 end
            s.a64_last_expr_type = "int"
        end
    return 0

fn arm64_synth_expr_additive s toks pos_box
    // WHY: Pratt precedence level 2 for standard arithmetic (+, -) with string concat & hardware IEEE-754 f64.
    arm64_synth_expr_multiplicative(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind
        if k != TOK_PLUS() and k != TOK_MINUS()
            break
        list_set(pos_box, 0, pos + 1) // Consume operator
        lhs_ua = s.a64_last_is_uint
        lhs_ta = s.a64_last_expr_type

        // Push left operand (X0) to stack (plus X1 tag if dyn_tagged)
        arm64_push_reg(s, 0)
        if lhs_ta == "dyn_tagged"
            arm64_push_reg(s, 1)
        end

        // Evaluate right operand into X0
        arm64_synth_expr_multiplicative(s, toks, pos_box)
        rhs_ua = s.a64_last_is_uint
        rhs_ta = s.a64_last_expr_type

        if k == TOK_PLUS() and (lhs_ta == "str" or rhs_ta == "str")
            s.a64_needs_str_helpers = 1
            s.synth_needs_alloc = 1
            // Auto-stringify non-string RHS cleanly (prevents segfault on "val=" + int/float/u64/dyn_tagged)
            if rhs_ta != "str"
                if rhs_ta == "float"
                    arm64_synth_emit_call_helper(s, "__float_to_str")
                elif rhs_ta == "dyn_tagged"
                    arm64_synth_emit_call_helper(s, "__tagged_to_str")
                elif rhs_ua == 1 or rhs_ta == "uint"
                    arm64_synth_emit_call_helper(s, "__uint_to_str")
                else
                    arm64_synth_emit_call_helper(s, "__int_to_str")
                end
            end
            if lhs_ta != "str"
                arm64_emit_mov_reg(s, 1, 0) // X1 = rhs_str
                if lhs_ta == "dyn_tagged"
                    arm64_pop_reg(s, 9) // X9 = lhs_tag
                end
                arm64_pop_reg(s, 0) // X0 = lhs
                arm64_push_reg(s, 1) // save rhs_str on stack
                if lhs_ta == "float"
                    arm64_synth_emit_call_helper(s, "__float_to_str")
                elif lhs_ta == "dyn_tagged"
                    arm64_emit_mov_reg(s, 1, 9)
                    arm64_synth_emit_call_helper(s, "__tagged_to_str")
                elif lhs_ua == 1 or lhs_ta == "uint"
                    arm64_synth_emit_call_helper(s, "__uint_to_str")
                else
                    arm64_synth_emit_call_helper(s, "__int_to_str")
                end
                arm64_pop_reg(s, 1) // X1 = rhs_str
            else
                arm64_emit_mov_reg(s, 1, 0)
                arm64_pop_reg(s, 0)
            end
            arm64_synth_emit_call_helper(s, "__str_concat")
            s.a64_last_is_uint = 0
            s.a64_last_expr_type = "str"
        elif lhs_ta == "float" or rhs_ta == "float"
            if rhs_ta == "dyn_tagged"
                arm64_emit_mov_reg(s, 11, 1)
            end
            arm64_emit_mov_reg(s, 10, 0)
            if lhs_ta == "dyn_tagged"
                arm64_pop_reg(s, 9)
            end
            arm64_pop_reg(s, 0)
            arm64_emit_load_fp_reg(s, 0, 0, lhs_ta, lhs_ua, 9)
            arm64_emit_load_fp_reg(s, 1, 10, rhs_ta, rhs_ua, 11)
            arm64_emit_fp_arith_op(s, k)
            s.a64_last_is_uint = 0
            s.a64_last_expr_type = "float"
        elif lhs_ta == "dyn_tagged" or rhs_ta == "dyn_tagged"
            if rhs_ta == "dyn_tagged"
                arm64_emit_mov_reg(s, 11, 1)
            else
                arm64_emit_movz_x(s, 11, 0, 0)
            end
            arm64_emit_mov_reg(s, 10, 0)
            if lhs_ta == "dyn_tagged"
                arm64_pop_reg(s, 9)
            else
                arm64_emit_movz_x(s, 9, 0, 0)
            end
            arm64_pop_reg(s, 0)
            arm64_emit_mov_reg(s, 1, 10)
            arm64_emit_movz_x(s, 12, 1, 0)
            arm64_emit_cmp_x(s, 9, 12)
            beq_da_fp1 = s.synth_code.len()
            arm64_emit_b_cond(s, 0, 0)
            arm64_emit_cmp_x(s, 11, 12)
            beq_da_fp2 = s.synth_code.len()
            arm64_emit_b_cond(s, 0, 0)
            if k == TOK_PLUS() arm64_emit_add_x(s, 0, 0, 1) else arm64_emit_sub_x(s, 0, 0, 1) end
            arm64_emit_movz_x(s, 1, 0, 0)
            jmp_da_done = s.synth_code.len()
            arm64_emit_b(s, 0)
            da_fp_off = s.synth_code.len()
            arm64_patch_b_cond(s, beq_da_fp1, 0, da_fp_off)
            arm64_patch_b_cond(s, beq_da_fp2, 0, da_fp_off)
            arm64_emit_load_fp_reg(s, 0, 0, "dyn_tagged", lhs_ua, 9)
            arm64_emit_load_fp_reg(s, 1, 10, "dyn_tagged", rhs_ua, 11)
            arm64_emit_fp_arith_op(s, k)
            arm64_emit_movz_x(s, 1, 1, 0)
            arm64_patch_b(s, jmp_da_done, s.synth_code.len())
            s.a64_last_is_uint = 0
            s.a64_last_expr_type = "dyn_tagged"
        elif k == TOK_PLUS()
            arm64_emit_mov_reg(s, 1, 0)
            arm64_pop_reg(s, 0)
            arm64_emit_add_x(s, 0, 0, 1)
            if lhs_ua == 1 or rhs_ua == 1 s.a64_last_is_uint = 1 else s.a64_last_is_uint = 0 end
            s.a64_last_expr_type = "int"
        elif k == TOK_MINUS()
            arm64_emit_mov_reg(s, 1, 0)
            arm64_pop_reg(s, 0)
            arm64_emit_sub_x(s, 0, 0, 1)
            if lhs_ua == 1 or rhs_ua == 1 s.a64_last_is_uint = 1 else s.a64_last_is_uint = 0 end
            s.a64_last_expr_type = "int"
        end
    return 0

fn arm64_synth_expr_shift s toks pos_box
    // WHY: Pratt precedence level 3a for bitwise shifts (<<, >>)
    arm64_synth_expr_additive(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind
        if k != TOK_SHL() and k != TOK_SHR()
            break
        list_set(pos_box, 0, pos + 1)
        lhs_us = s.a64_last_is_uint
        arm64_push_reg(s, 0)
        arm64_synth_expr_additive(s, toks, pos_box)
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)
        if k == TOK_SHL()
            arm64_emit_lslv_x(s, 0, 0, 1)
        elif lhs_us == 1
            arm64_emit_lsrv_x(s, 0, 0, 1)
        else
            arm64_emit_asrv_x(s, 0, 0, 1)
        end
        s.a64_last_struct = ""
        s.a64_last_is_uint = lhs_us
        s.a64_last_expr_type = "int"
    return 0

fn arm64_synth_expr_relational s toks pos_box
    // WHY: Pratt precedence level 3 for comparison operators (==, !=, <, <=, >, >=) with IEEE-754 NaN-safe FP compares.
    arm64_synth_expr_shift(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        k = toks[pos].tok_kind
        if k != TOK_EQ() and k != TOK_NEQ() and k != TOK_LT() and k != TOK_LTE() and k != TOK_GT() and k != TOK_GTE()
            break
        list_set(pos_box, 0, pos + 1) // Consume operator
        lhs_ur = s.a64_last_is_uint
        lhs_tr = s.a64_last_expr_type

        // Push left operand (X0) to stack (plus X1 tag if dyn_tagged)
        arm64_push_reg(s, 0)
        if lhs_tr == "dyn_tagged"
            arm64_push_reg(s, 1)
        end

        // Evaluate right operand into X0
        arm64_synth_expr_shift(s, toks, pos_box)
        rhs_ur = s.a64_last_is_uint
        rhs_tr = s.a64_last_expr_type
        cmp_u = 0
        if lhs_ur == 1 or rhs_ur == 1 cmp_u = 1 end

        if lhs_tr == "float" or rhs_tr == "float"
            if rhs_tr == "dyn_tagged"
                arm64_emit_mov_reg(s, 11, 1)
            end
            arm64_emit_mov_reg(s, 10, 0)
            if lhs_tr == "dyn_tagged"
                arm64_pop_reg(s, 9)
            end
            arm64_pop_reg(s, 0)
            arm64_emit_load_fp_reg(s, 0, 0, lhs_tr, lhs_ur, 9)
            arm64_emit_load_fp_reg(s, 1, 10, rhs_tr, rhs_ur, 11)
            arm64_emit_fcmp_cond_x0(s, k)
        elif lhs_tr == "dyn_tagged" or rhs_tr == "dyn_tagged"
            if rhs_tr == "dyn_tagged"
                arm64_emit_mov_reg(s, 11, 1)
            else
                arm64_emit_movz_x(s, 11, 0, 0)
            end
            arm64_emit_mov_reg(s, 10, 0)
            if lhs_tr == "dyn_tagged"
                arm64_pop_reg(s, 9)
            else
                arm64_emit_movz_x(s, 9, 0, 0)
            end
            arm64_pop_reg(s, 0)
            arm64_emit_mov_reg(s, 1, 10)
            arm64_emit_movz_x(s, 12, 1, 0)
            arm64_emit_cmp_x(s, 9, 12)
            beq_dr_fp1 = s.synth_code.len()
            arm64_emit_b_cond(s, 0, 0)
            arm64_emit_cmp_x(s, 11, 12)
            beq_dr_fp2 = s.synth_code.len()
            arm64_emit_b_cond(s, 0, 0)
            arm64_emit_cmp_x(s, 0, 1)
            icc_d = 0
            if k == TOK_EQ() icc_d = 0
            elif k == TOK_NEQ() icc_d = 1
            elif k == TOK_LT()
                if cmp_u == 1 icc_d = 3 else icc_d = 11 end
            elif k == TOK_LTE()
                if cmp_u == 1 icc_d = 9 else icc_d = 13 end
            elif k == TOK_GT()
                if cmp_u == 1 icc_d = 8 else icc_d = 12 end
            elif k == TOK_GTE()
                if cmp_u == 1 icc_d = 2 else icc_d = 10 end
            end
            arm64_emit_b_cond(s, icc_d, 3)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
            jmp_dr_done = s.synth_code.len()
            arm64_emit_b(s, 0)
            dr_fp_off = s.synth_code.len()
            arm64_patch_b_cond(s, beq_dr_fp1, 0, dr_fp_off)
            arm64_patch_b_cond(s, beq_dr_fp2, 0, dr_fp_off)
            arm64_emit_load_fp_reg(s, 0, 0, "dyn_tagged", lhs_ur, 9)
            arm64_emit_load_fp_reg(s, 1, 10, "dyn_tagged", rhs_ur, 11)
            arm64_emit_fcmp_cond_x0(s, k)
            arm64_patch_b(s, jmp_dr_done, s.synth_code.len())
        else
            // Move right operand to X1, pop left operand back into X0
            arm64_emit_mov_reg(s, 1, 0)
            arm64_pop_reg(s, 0)

            if k == TOK_EQ()
                // cmp x0, x1; b.eq +3; mov x0, 0; b +2; mov x0, 1
                arm64_emit_cmp_x(s, 0, 1)
                arm64_emit_b_cond(s, 0, 3)
                arm64_emit_movz_x(s, 0, 0, 0)
                arm64_emit_b(s, 2)
                arm64_emit_movz_x(s, 0, 1, 0)
            elif k == TOK_NEQ()
                arm64_emit_cmp_x(s, 0, 1)
                arm64_emit_b_cond(s, 1, 3)
                arm64_emit_movz_x(s, 0, 0, 0)
                arm64_emit_b(s, 2)
                arm64_emit_movz_x(s, 0, 1, 0)
            elif k == TOK_LT()
                arm64_emit_cmp_x(s, 0, 1)
                if cmp_u == 1 arm64_emit_b_cond(s, 3, 3) else arm64_emit_b_cond(s, 11, 3) end
                arm64_emit_movz_x(s, 0, 0, 0)
                arm64_emit_b(s, 2)
                arm64_emit_movz_x(s, 0, 1, 0)
            elif k == TOK_LTE()
                arm64_emit_cmp_x(s, 0, 1)
                if cmp_u == 1 arm64_emit_b_cond(s, 9, 3) else arm64_emit_b_cond(s, 13, 3) end
                arm64_emit_movz_x(s, 0, 0, 0)
                arm64_emit_b(s, 2)
                arm64_emit_movz_x(s, 0, 1, 0)
            elif k == TOK_GT()
                arm64_emit_cmp_x(s, 0, 1)
                if cmp_u == 1 arm64_emit_b_cond(s, 8, 3) else arm64_emit_b_cond(s, 12, 3) end
                arm64_emit_movz_x(s, 0, 0, 0)
                arm64_emit_b(s, 2)
                arm64_emit_movz_x(s, 0, 1, 0)
            elif k == TOK_GTE()
                arm64_emit_cmp_x(s, 0, 1)
                if cmp_u == 1 arm64_emit_b_cond(s, 2, 3) else arm64_emit_b_cond(s, 10, 3) end
                arm64_emit_movz_x(s, 0, 0, 0)
                arm64_emit_b(s, 2)
                arm64_emit_movz_x(s, 0, 1, 0)
            end
        end
        s.a64_last_is_uint = 0
        s.a64_last_expr_type = "int"
    return 0

fn arm64_synth_expr_bit_and s toks pos_box
    arm64_synth_expr_relational(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        if toks[pos].tok_kind != TOK_AMP()
            break
        list_set(pos_box, 0, pos + 1)
        arm64_push_reg(s, 0)
        arm64_synth_expr_relational(s, toks, pos_box)
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)
        arm64_emit_and_x(s, 0, 0, 1)
        s.a64_last_struct = ""
    return 0

fn arm64_synth_expr_bit_xor s toks pos_box
    arm64_synth_expr_bit_and(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        if toks[pos].tok_kind != TOK_CARET()
            break
        list_set(pos_box, 0, pos + 1)
        arm64_push_reg(s, 0)
        arm64_synth_expr_bit_and(s, toks, pos_box)
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)
        arm64_emit_eor_x(s, 0, 0, 1)
        s.a64_last_struct = ""
    return 0

fn arm64_synth_expr_bit_or s toks pos_box
    arm64_synth_expr_bit_xor(s, toks, pos_box)
    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        if toks[pos].tok_kind != TOK_BAR()
            break
        list_set(pos_box, 0, pos + 1)
        arm64_push_reg(s, 0)
        arm64_synth_expr_bit_xor(s, toks, pos_box)
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)
        arm64_emit_orr_x(s, 0, 0, 1)
        s.a64_last_struct = ""
    return 0

fn arm64_synth_expr_and s toks pos_box
    // WHY: Pratt precedence level 4 for logical AND (and, &&, এবং)
    arm64_synth_expr_bit_or(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text
        is_and = 0
        if k == TOK_AND() or (k == TOK_IDENT() and (txt == "and" or txt == "এবং"))
            is_and = 1
        if is_and == 0
            break
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (X0) to stack
        arm64_push_reg(s, 0)

        // Evaluate right operand into X0
        arm64_synth_expr_bit_or(s, toks, pos_box)

        // Move right operand to X1, pop left operand back into X0
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)

        // X0 = (X0 != 0 && X1 != 0) ? 1 : 0
        arm64_emit_cmp_x(s, 0, 31)     // +0: cmp x0, xzr
        arm64_emit_b_cond(s, 0, 5)     // +1: b.eq fail (+5 -> +6)
        arm64_emit_cmp_x(s, 1, 31)     // +2: cmp x1, xzr
        arm64_emit_b_cond(s, 0, 3)     // +3: b.eq fail (+3 -> +6)
        arm64_emit_movz_x(s, 0, 1, 0)  // +4: movz x0, 1
        arm64_emit_b(s, 2)             // +5: b done (+2 -> +7)
        arm64_emit_movz_x(s, 0, 0, 0)  // +6: fail: movz x0, 0
    return 0

fn arm64_synth_expr_or s toks pos_box
    // WHY: Pratt precedence level 5 for logical OR (or, ||, অথবা)
    arm64_synth_expr_and(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind
        txt = t.tok_text
        is_or = 0
        if k == TOK_OR() or (k == TOK_IDENT() and (txt == "or" or txt == "অথবা"))
            is_or = 1
        if is_or == 0
            break
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (X0) to stack
        arm64_push_reg(s, 0)

        // Evaluate right operand into X0
        arm64_synth_expr_and(s, toks, pos_box)

        // Move right operand to X1, pop left operand back into X0
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)

        // X0 = (X0 != 0 || X1 != 0) ? 1 : 0
        arm64_emit_cmp_x(s, 0, 31)     // +0: cmp x0, xzr
        arm64_emit_b_cond(s, 1, 5)     // +1: b.ne success (+5 -> +6)
        arm64_emit_cmp_x(s, 1, 31)     // +2: cmp x1, xzr
        arm64_emit_b_cond(s, 1, 3)     // +3: b.ne success (+3 -> +6)
        arm64_emit_movz_x(s, 0, 0, 0)  // +4: movz x0, 0
        arm64_emit_b(s, 2)             // +5: b done (+2 -> +7)
        arm64_emit_movz_x(s, 0, 1, 0)  // +6: success: movz x0, 1
    return 0

fn arm64_synth_compile_expr s toks pos_box
    // WHY: Master expression evaluator entering at lowest-precedence (logical OR) level.
    return arm64_synth_expr_or(s, toks, pos_box)

