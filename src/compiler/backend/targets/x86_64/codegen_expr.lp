// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/x86_64/codegen_expr.lp
// ==============================================================================

// ── 6. Recursive-Descent Expression Synthesizer ────────────────────────────────

fn x86_synth_emit_fn_ptr_lea s target_fn_name
    // WHY: Emits RIP-relative `lea rax, [rip + disp32]` (48 8D 05 <0>) with X86CallReloc
    // so taking `&fn` or `fn_ptr(fn)` is 100% Static-PIE ASLR safe.
    x86_synth_emit_bytes(s, [72, 141, 5])
    patch_pos = s.synth_code.len()
    x86_synth_emit_u32(s, 0)
    call_rel = X86CallReloc()
    call_rel.cr_patch_offset = patch_pos
    call_rel.cr_call_site_end = patch_pos + 4
    call_rel.cr_target_name = target_fn_name
    push(s.synth_call_relocs, call_rel)
    s.synth_last_struct = ""
    s.synth_last_expr_type = "int"
    return 0

fn x86_synth_emit_indirect_call_rax s
    // WHY: Dispatches both capturing heap closures (`CLOS` 0x434C4F53 header passing env_ptr in %r10
    // and calling [env_ptr+8]) AND raw function pointers in %rax without clobbering SysV %rdi..%r9.
    x86_synth_emit_bytes(s, [
        73, 137, 195,
        65, 186, 83, 79, 76, 67,
        77, 57, 19,
        117, 7,
        77, 137, 218,
        77, 139, 91, 8,
        65, 255, 211
    ])
    s.synth_last_store_end = 0 - 1
    s.synth_last_expr_type = ""
    s.synth_last_struct = ""
    return 0

fn x86_synth_emit_closure_literal s toks pos_box c_params
    // WHY: Synthesizes a first-class capturing closure (`|params| => expr` / `fn(params) => expr`).
    // Emits isolated closure machine code inline (skipped via jmp), scans free outer locals
    // to pack into a 24B+`CLOS` heap environment object, and binds captures via %r10.
    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_FAT_ARROW() or toks[get(pos_box, 0)].tok_text == "=>")
        list_set(pos_box, 0, get(pos_box, 0) + 1)
    end

    // Scan closure body tokens for free outer local variables
    cap_names = list()
    cap_types = list()
    cap_prims = list()
    scan_i = get(pos_box, 0)
    paren_d = 0
    while scan_i < toks.len()
        stk = toks[scan_i]
        sk = stk.tok_kind
        stxt = stk.tok_text
        if sk == TOK_LPAREN() or stxt == "(" or sk == TOK_LBRACKET() or stxt == "["
            paren_d = paren_d + 1
        elif sk == TOK_RPAREN() or stxt == ")" or sk == TOK_RBRACKET() or stxt == "]"
            if paren_d == 0
                break
            end
            paren_d = paren_d - 1
        elif (sk == TOK_COMMA() or stxt == ",") and paren_d == 0
            break
        elif (sk == TOK_NEWLINE() or sk == TOK_SEMI() or sk == TOK_EOF()) and paren_d == 0
            break
        elif x86_synth_is_ident_token(sk) == 1
            is_member_or_call = 0
            if scan_i > 0 and (toks[scan_i - 1].tok_kind == TOK_DOT() or toks[scan_i - 1].tok_text == ".")
                is_member_or_call = 1
            end
            if scan_i + 1 < toks.len() and (toks[scan_i + 1].tok_kind == TOK_LPAREN() or toks[scan_i + 1].tok_text == "(")
                is_member_or_call = 1
            end
            if is_member_or_call == 0
                is_param = 0
                pi = 0
                while pi < c_params.len()
                    if c_params[pi] == stxt
                        is_param = 1
                        break
                    end
                    pi = pi + 1
                end
                if is_param == 0
                    already_cap = 0
                    ci = 0
                    while ci < cap_names.len()
                        if cap_names[ci] == stxt
                            already_cap = 1
                            break
                        end
                        ci = ci + 1
                    end
                    if already_cap == 0
                        lv_o = x86_synth_find_local_var(s, stxt)
                        if lv_o != 0
                            push(cap_names, stxt)
                            lt = ""
                            if lv_o.lv_type != 0
                                lt = lv_o.lv_type
                            end
                            lp = ""
                            if lv_o.lv_prim_type != 0
                                lp = lv_o.lv_prim_type
                            end
                            push(cap_types, lt)
                            push(cap_prims, lp)
                        end
                    end
                end
            end
        end
        scan_i = scan_i + 1
    end

    // Emit jump over closure body + record closure code entry offset
    x86_synth_emit_byte(s, 233)
    skip_jmp_patch = s.synth_code.len()
    x86_synth_emit_u32(s, 0)
    clos_code_off = s.synth_code.len()

    // Isolate compiler frame/regalloc state for closure body
    saved_locals = s.synth_locals
    saved_stack_offset = s.synth_stack_offset
    saved_in_fn = s.synth_in_function
    saved_cur_fn = s.synth_current_fn
    saved_ra_names = s.synth_regalloc_names
    saved_ra_regs = s.synth_regalloc_regs
    s.synth_locals = list()
    s.synth_stack_offset = 64
    s.synth_in_function = 1
    s.synth_current_fn = "__closure"
    s.synth_regalloc_names = list()
    s.synth_regalloc_regs = list()
    s.synth_last_store_end = 0 - 1

    prologue_patch = x86_synth_emit_prologue(s)
    pi = 0
    while pi < c_params.len()
        p_off = x86_synth_alloc_var(s, c_params[pi])
        x86_synth_emit_store_param(s, pi, p_off)
        pi = pi + 1
    end

    // Load captured outer values from [r10 + 24 + ci*8] into closure local slots
    ci = 0
    while ci < cap_names.len()
        disp_c = 24 + (ci * 8)
        if disp_c < 128
            x86_synth_emit_bytes(s, [73, 139, 66, disp_c])
        else
            x86_synth_emit_bytes(s, [73, 139, 130])
            x86_synth_emit_u32(s, disp_c)
        end
        c_off = x86_synth_alloc_var(s, cap_names[ci])
        x86_synth_emit_store_var(s, 0, c_off)
        if cap_types[ci] != ""
            x86_synth_set_var_type(s, cap_names[ci], cap_types[ci])
        end
        if cap_prims[ci] != ""
            x86_synth_set_prim_type(s, cap_names[ci], cap_prims[ci])
        end
        ci = ci + 1
    end

    x86_synth_compile_expr(s, toks, pos_box)
    x86_synth_emit_epilogue(s)
    frame_sz = ((s.synth_stack_offset + 256 + 15) / 16) * 16
    if frame_sz < 512
        frame_sz = 512
    end
    x86_synth_patch_u32(s, prologue_patch, frame_sz)

    // Restore enclosing compiler state
    s.synth_locals = saved_locals
    s.synth_stack_offset = saved_stack_offset
    s.synth_in_function = saved_in_fn
    s.synth_current_fn = saved_cur_fn
    s.synth_regalloc_names = saved_ra_names
    s.synth_regalloc_regs = saved_ra_regs
    s.synth_last_store_end = 0 - 1

    after_clos = s.synth_code.len()
    x86_synth_patch_u32(s, skip_jmp_patch, after_clos - (skip_jmp_patch + 4))

    // Allocate heap CLOS object via arena allocator: [magic=0x434C4F53, code_ptr (RIP-relative), n_caps, cap0, ...]
    obj_sz = 24 + (cap_names.len() * 8)
    x86_synth_emit_mov_rdi_imm64(s, obj_sz)
    x86_synth_emit_call_alloc(s)
    x86_synth_emit_bytes(s, [72, 199, 0, 83, 79, 76, 67])
    x86_synth_emit_bytes(s, [72, 141, 21])
    disp_clos = clos_code_off - (s.synth_code.len() + 4)
    x86_synth_emit_u32(s, disp_clos)
    x86_synth_emit_bytes(s, [72, 137, 80, 8])
    x86_synth_emit_bytes(s, [72, 199, 64, 16])
    x86_synth_emit_u32(s, cap_names.len())

    ci = 0
    while ci < cap_names.len()
        lv_outer = x86_synth_find_local_var(s, cap_names[ci])
        if lv_outer != 0 and lv_outer.lv_is_spilled == 0 and lv_outer.lv_reg >= 0
            x86_synth_emit_mov_reg_reg(s, 1, lv_outer.lv_reg)
        elif lv_outer != 0
            x86_synth_emit_load_var(s, 1, lv_outer.lv_offset)
        else
            mg_cap = x86_synth_find_mutable_global(s, cap_names[ci])
            if mg_cap >= 512
                x86_synth_emit_byte(s, 80) // push rax
                x86_synth_emit_mutable_global_read(s, mg_cap)
                x86_synth_emit_bytes(s, [72, 137, 193]) // mov rcx, rax
                x86_synth_emit_byte(s, 88) // pop rax
            else
                x86_synth_emit_bytes(s, [72, 49, 201])
            end
        end
        disp_c = 24 + (ci * 8)
        if disp_c < 128
            x86_synth_emit_bytes(s, [72, 137, 72, disp_c])
        else
            x86_synth_emit_bytes(s, [72, 137, 136])
            x86_synth_emit_u32(s, disp_c)
        end
        ci = ci + 1
    end

    s.synth_last_struct = ""
    s.synth_last_expr_type = ""
    return 0

fn x86_synth_expr_primary s toks pos_box
    // WHY: Parses and synthesizes primary operands (integers, strings, lists, identifiers, grouping).
    // Result is always computed into %rax, followed by postfix chained evaluation for [index] and .member.
    // Skip any inter-token whitespace or newlines before reading the primary token
    x86_synth_skip_whitespace_tokens(toks, pos_box)
    pos = get(pos_box, 0)
    if pos >= toks.len()
        x86_synth_emit_byte(s, 49)  // xor eax, eax
        x86_synth_emit_byte(s, 192)
        return 0

    t = toks[pos]
    k = t.tok_kind
    txt = t.tok_text

    // 0. Unary NOT (!, not, না)
    if k == TOK_BANG() or (k == TOK_IDENT() and (txt == "not" or txt == "না" or txt == "!"))
        list_set(pos_box, 0, pos + 1)
        x86_synth_expr_primary(s, toks, pos_box)
        // test rax, rax; setz al; movzx rax, al
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 133)
        x86_synth_emit_byte(s, 192)
        x86_synth_emit_byte(s, 15)
        x86_synth_emit_byte(s, 148)
        x86_synth_emit_byte(s, 192)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 15)
        x86_synth_emit_byte(s, 182)
        x86_synth_emit_byte(s, 192)
        return 0

    // 0b. Unary Negation (-)
    elif (k == TOK_MINUS() or (k == TOK_IDENT() and txt == "-")) and pos + 1 < toks.len()
        list_set(pos_box, 0, pos + 1)
        x86_synth_expr_primary(s, toks, pos_box)
        if s.synth_last_expr_type == "float"
            // btc rax, 63 (0x48 0x0F 0xBA 0xF8 0x3F) — toggle IEEE-754 sign bit
            x86_synth_emit_bytes(s, [72, 15, 186, 248, 63])
            s.synth_last_expr_type = "float"
        else
            // neg rax (0x48 0xF7 0xD8)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 247)
            x86_synth_emit_byte(s, 216)
        end
        return 0

    // 0c. Unary Bitwise NOT (~)
    elif (k == TOK_TILDE() or (k == TOK_IDENT() and txt == "~")) and pos + 1 < toks.len()
        list_set(pos_box, 0, pos + 1)
        x86_synth_expr_primary(s, toks, pos_box)
        // not rax (0x48 0xF7 0xD0)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 247)
        x86_synth_emit_byte(s, 208)
        return 0

    // 0d. Address-of function / local (&fn_name)
    elif (k == TOK_AMP() or (k != TOK_STR() and txt == "&")) and pos + 1 < toks.len()
        list_set(pos_box, 0, pos + 1)
        np_a = get(pos_box, 0)
        if np_a < toks.len() and x86_synth_is_ident_token(toks[np_a].tok_kind) == 1
            tname = toks[np_a].tok_text
            list_set(pos_box, 0, np_a + 1)
            is_reg_fn = 0
            if x86_synth_find_fn_first(s, tname) != 0
                is_reg_fn = 1
            end
            lv_amp = x86_synth_find_local_var(s, tname)
            if is_reg_fn == 1 or lv_amp == 0
                x86_synth_emit_fn_ptr_lea(s, tname)
            else
                // lea rax, [rbp - off] (48 8D 85 disp32)
                x86_synth_emit_bytes(s, [72, 141, 133])
                x86_synth_emit_u32(s, 0 - lv_amp.lv_offset)
                s.synth_last_struct = ""
                s.synth_last_expr_type = "int"
            end
            return 0
        end
        x86_synth_expr_primary(s, toks, pos_box)
        return 0

    // 0e. Closure literal: |p1, p2| => expr
    elif k == TOK_BAR() or (k != TOK_STR() and txt == "|")
        list_set(pos_box, 0, pos + 1)
        c_params = list()
        while get(pos_box, 0) < toks.len()
            cp_c = get(pos_box, 0)
            ct_c = toks[cp_c]
            if ct_c.tok_kind == TOK_BAR() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == "|")
                list_set(pos_box, 0, cp_c + 1)
                break
            elif ct_c.tok_kind == TOK_COMMA() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == ",")
                list_set(pos_box, 0, cp_c + 1)
            elif x86_synth_is_ident_token(ct_c.tok_kind) == 1
                push(c_params, ct_c.tok_text)
                list_set(pos_box, 0, cp_c + 1)
            else
                list_set(pos_box, 0, cp_c + 1)
            end
        end
        x86_synth_emit_closure_literal(s, toks, pos_box, c_params)
        return 0

    // 0f. Lambda literal: fn(p1, p2) => expr
    elif (k == TOK_KW_FN() or (k == TOK_IDENT() and (txt == "fn" or txt == "কাজ"))) and pos + 1 < toks.len() and (toks[pos + 1].tok_kind == TOK_LPAREN() or toks[pos + 1].tok_text == "(")
        list_set(pos_box, 0, pos + 2)
        c_params = list()
        while get(pos_box, 0) < toks.len()
            cp_c = get(pos_box, 0)
            ct_c = toks[cp_c]
            if ct_c.tok_kind == TOK_RPAREN() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == ")")
                list_set(pos_box, 0, cp_c + 1)
                break
            elif ct_c.tok_kind == TOK_COMMA() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == ",")
                list_set(pos_box, 0, cp_c + 1)
            elif x86_synth_is_ident_token(ct_c.tok_kind) == 1
                push(c_params, ct_c.tok_text)
                list_set(pos_box, 0, cp_c + 1)
            else
                list_set(pos_box, 0, cp_c + 1)
            end
        end
        x86_synth_emit_closure_literal(s, toks, pos_box, c_params)
        return 0

    // 1. Integer Literal
    elif k == TOK_INT()
        list_set(pos_box, 0, pos + 1)
        x86_synth_emit_mov_rax_imm64(s, t.tok_int_val)
        s.synth_last_expr_type = "int"
        s.synth_last_struct = ""

    // 1b. Float Literal: IEEE-754 binary64 64-bit precision
    elif k == TOK_FLOAT()
        list_set(pos_box, 0, pos + 1)
        fbits = x86_synth_parse_float_bits(t.tok_text)
        x86_synth_emit_mov_rax_imm64(s, fbits)
        s.synth_last_expr_type = "float"
        s.synth_last_struct = ""

    // 2. String Literal
    elif k == TOK_STR() or k == TOK_INTERP_STR()
        list_set(pos_box, 0, pos + 1)
        ro_off = x86_synth_add_rodata_str(s, t.tok_text, 0)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 184) // mov rax, imm64
        patch_pos = s.synth_code.len()
        x86_synth_emit_u64(s, 0)
        rel = X86StringReloc()
        rel.sr_patch_offset = patch_pos
        rel.sr_rodata_offset = ro_off
        push(s.synth_str_relocs, rel)
        s.synth_last_expr_type = "str"
        s.synth_last_struct = ""

    // 3. Array / List Literal: [elem0, elem1, ...]
    elif k == TOK_LBRACKET() or (k == TOK_IDENT() and txt == "[")
        list_set(pos_box, 0, pos + 1) // Consume '['
        cp = get(pos_box, 0)
        if cp < toks.len() and (toks[cp].tok_kind == TOK_RBRACKET() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "]"))
            list_set(pos_box, 0, cp + 1) // Consume ']'
            // Empty list: _lipi_list_create(0, 0)
            x86_synth_emit_byte(s, 49) // xor edi, edi
            x86_synth_emit_byte(s, 255)
            x86_synth_emit_byte(s, 49) // xor esi, esi
            x86_synth_emit_byte(s, 246)
            x86_synth_emit_call_helper(s, "_lipi_list_create")
        else
            elem_count = 0
            while get(pos_box, 0) < toks.len()
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cp = get(pos_box, 0)
                if cp >= toks.len() or toks[cp].tok_kind == TOK_RBRACKET() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "]")
                    break
                x86_synth_compile_expr(s, toks, pos_box)
                x86_synth_emit_byte(s, 80) // push rax
                elem_count = elem_count + 1
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cp = get(pos_box, 0)
                if cp < toks.len() and (toks[cp].tok_kind == TOK_COMMA() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == ","))
                    list_set(pos_box, 0, cp + 1)
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cp = get(pos_box, 0)
            if cp < toks.len() and (toks[cp].tok_kind == TOK_RBRACKET() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "]"))
                list_set(pos_box, 0, cp + 1)

            // Allocate list: _lipi_list_create(elem_count, 0)
            x86_synth_emit_mov_rdi_imm64(s, elem_count)
            x86_synth_emit_byte(s, 49) // xor esi, esi
            x86_synth_emit_byte(s, 246)
            x86_synth_emit_call_helper(s, "_lipi_list_create")
            // List struct is in %rax: [0]=count, [8]=cap, [16]=data_ptr
            // mov r10, rax (preserve list struct ptr)
            x86_synth_emit_byte(s, 73)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 194)
            // mov r11, [rax + 16] (data_ptr)
            x86_synth_emit_byte(s, 76)
            x86_synth_emit_byte(s, 139)
            x86_synth_emit_byte(s, 88)  // ModR/M: [rax + disp8] (0x58: mod=01, reg=r11, rm=rax)
            x86_synth_emit_byte(s, 16)
            // Pop elements from stack in reverse order and store into data_ptr
            ai = elem_count - 1
            while ai >= 0
                x86_synth_emit_byte(s, 88) // pop rax
                off = ai * 8
                if off < 128
                    x86_synth_emit_byte(s, 73)  // REX.W + REX.B (0x49)
                    x86_synth_emit_byte(s, 137) // mov
                    x86_synth_emit_byte(s, 67)  // ModR/M: [r11 + disp8] (0x43)
                    x86_synth_emit_byte(s, off)
                else
                    x86_synth_emit_byte(s, 73)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 131) // ModR/M: [r11 + disp32] (0x83)
                    x86_synth_emit_u32(s, off)
                ai = ai - 1
            // Restore list pointer to %rax: mov rax, r10
            x86_synth_emit_byte(s, 76)
            x86_synth_emit_byte(s, 137)
            x86_synth_emit_byte(s, 208)
            s.synth_last_expr_type = ""

    // 3b. Struct / Map Literal: { key: val, key2: val2, ... }
    elif k == TOK_LBRACE() or (k == TOK_IDENT() and txt == "{") or txt == "{"
        list_set(pos_box, 0, pos + 1) // Consume '{'
        x86_synth_skip_whitespace_tokens(toks, pos_box)

        // WHY: Scans keys to identify matching struct schema for deterministic field offsets
        keys = x86_synth_scan_brace_keys(toks, pos + 1)
        sname = x86_synth_find_matching_struct(s, keys)
        is_anon_s = 0
        if sname == "" and keys.len() > 0
            anon_sdef = X86StructDef()
            anon_sdef.sd_name = "_anon_s_" + int_to_str(s.synth_structs.len())
            anon_sdef.sd_fields = keys
            anon_types = list()
            ki_init = 0
            while ki_init < keys.len()
                push(anon_types, "")
                ki_init = ki_init + 1
            end
            anon_sdef.sd_field_types = anon_types
            push(s.synth_structs, anon_sdef)
            sname = anon_sdef.sd_name
            is_anon_s = 1
        end
        s.synth_last_struct = sname

        alloc_sz = 1024
        if sname != ""
            sdef = x86_synth_find_struct(s, sname)
            if sdef != 0
                alloc_sz = (sdef.sd_fields.len() + 2) * 8
        if alloc_sz < 64
            alloc_sz = 64

        // Allocate heap memory for struct: _lipi_alloc_helper(alloc_sz)
        x86_synth_emit_mov_rdi_imm64(s, alloc_sz)
        x86_synth_emit_call_alloc(s)

        // Preserve base struct pointer on stack across field evaluations: push rax (0x50)
        x86_synth_emit_byte(s, 80)

        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_tk = toks[cur_p]
            if cur_tk.tok_kind == TOK_RBRACE() or (cur_tk.tok_kind != TOK_STR() and cur_tk.tok_text == "}")
                break

            key_name = cur_tk.tok_text
            list_set(pos_box, 0, cur_p + 1) // Consume field name

            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p < toks.len() and (toks[cur_p].tok_kind == TOK_COLON() or (toks[cur_p].tok_kind != TOK_STR() and toks[cur_p].tok_text == ":"))
                list_set(pos_box, 0, cur_p + 1) // Consume ':'

            x86_synth_skip_whitespace_tokens(toks, pos_box)

            // Compile field value expression into %rax
            x86_synth_compile_expr(s, toks, pos_box)
            fld_inf_type = s.synth_last_struct
            if fld_inf_type == ""
                fld_inf_type = s.synth_last_expr_type
            end
            if sname != "" and fld_inf_type != ""
                cur_sd_fill = x86_synth_find_struct(s, sname)
                if cur_sd_fill != 0 and cur_sd_fill.sd_field_types.len() == cur_sd_fill.sd_fields.len()
                    kf_i = 0
                    while kf_i < cur_sd_fill.sd_fields.len()
                        if cur_sd_fill.sd_fields[kf_i] == key_name and cur_sd_fill.sd_field_types[kf_i] == ""
                            list_set(cur_sd_fill.sd_field_types, kf_i, fld_inf_type)
                            break
                        end
                        kf_i = kf_i + 1
                    end
                end
            end

            f_off = x86_synth_get_field_offset(s, sname, key_name)

            // Base struct pointer is preserved at top of stack: mov rdx, [rsp] (0x48 0x8B 0x14 0x24)
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 139)
            x86_synth_emit_byte(s, 20)
            x86_synth_emit_byte(s, 36)

            // Store %rax into [rdx + f_off]: mov [rdx + f_off], rax
            x86_synth_emit_byte(s, 72)
            x86_synth_emit_byte(s, 137)
            if f_off < 128
                x86_synth_emit_byte(s, 66)
                x86_synth_emit_byte(s, f_off)
            else
                x86_synth_emit_byte(s, 130)
                x86_synth_emit_u32(s, f_off)

            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p < toks.len() and (toks[cur_p].tok_kind == TOK_COMMA() or (toks[cur_p].tok_kind != TOK_STR() and toks[cur_p].tok_text == ","))
                list_set(pos_box, 0, cur_p + 1) // Consume ','

        x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len() and (toks[cur_p].tok_kind == TOK_RBRACE() or (toks[cur_p].tok_kind != TOK_STR() and toks[cur_p].tok_text == "}"))
            list_set(pos_box, 0, cur_p + 1) // Consume '}'

        // Restore base struct pointer into %rax: pop rax (0x58)
        x86_synth_emit_byte(s, 88)
        s.synth_last_struct = sname
        s.synth_last_expr_type = ""

    // 4. Parenthesized expression: ( expr )
    elif k == TOK_LPAREN() or (k != TOK_STR() and txt == "(")
        list_set(pos_box, 0, pos + 1)
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        x86_synth_compile_expr(s, toks, pos_box)
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len() and (toks[cur_pos].tok_kind == TOK_RPAREN() or (toks[cur_pos].tok_kind != TOK_STR() and toks[cur_pos].tok_text == ")"))
            list_set(pos_box, 0, cur_pos + 1)

    // 5. Identifier, Intrinsic, Struct Ctor, or Variable
    elif x86_synth_is_ident_token(k) == 1
        list_set(pos_box, 0, pos + 1)
        var_name = txt
        next_pos = get(pos_box, 0)

        // Function or intrinsic call: name(...)
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_LPAREN() or (toks[next_pos].tok_kind != TOK_STR() and toks[next_pos].tok_text == "("))
            list_set(pos_box, 0, next_pos + 1) // Consume '('
            if (var_name == "fn_ptr" or var_name == "fn_addr") and x86_synth_find_local_var(s, var_name) == 0
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                fp_idx = get(pos_box, 0)
                fp_name = ""
                if fp_idx < toks.len() and x86_synth_is_ident_token(toks[fp_idx].tok_kind) == 1
                    fp_name = toks[fp_idx].tok_text
                    list_set(pos_box, 0, fp_idx + 1)
                end
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ")"))
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                if fp_name != ""
                    x86_synth_emit_fn_ptr_lea(s, fp_name)
                else
                    x86_synth_emit_byte(s, 49)
                    x86_synth_emit_byte(s, 192)
                    s.synth_last_expr_type = "int"
                    s.synth_last_struct = ""
                end
                x86_synth_expr_postfix(s, toks, pos_box)
                return 0
            end
            // Parse arguments into caller registers (%rdi, %rsi, %rdx, %rcx, %r8, %r9)
            // WHY: Multi-line argument lists (e.g. error_code_new(\n "E0001",\n ...)) contain
            // TOK_NEWLINE() tokens that must be skipped so they are not evaluated as spurious 0 arguments.
            arg_count = 0
            while get(pos_box, 0) < toks.len()
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cur_pos = get(pos_box, 0)
                if cur_pos >= toks.len() or toks[cur_pos].tok_kind == TOK_RPAREN() or (toks[cur_pos].tok_kind != TOK_STR() and toks[cur_pos].tok_text == ")")
                    break
                x86_synth_compile_expr(s, toks, pos_box)
                x86_synth_emit_byte(s, 80) // push rax (save argument)
                arg_count = arg_count + 1
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cur_pos = get(pos_box, 0)
                if cur_pos < toks.len() and (toks[cur_pos].tok_kind == TOK_COMMA() or (toks[cur_pos].tok_kind != TOK_STR() and toks[cur_pos].tok_text == ","))
                    list_set(pos_box, 0, cur_pos + 1)

            x86_synth_skip_whitespace_tokens(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ")"))
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            // Intrinsic 1: syscall
            if var_name == "syscall" or var_name == "সিসকল" or var_name == "sys_syscall"
                if arg_count >= 7
                    x86_synth_emit_byte(s, 65)
                    x86_synth_emit_byte(s, 89) // pop r9
                if arg_count >= 6
                    x86_synth_emit_byte(s, 65)
                    x86_synth_emit_byte(s, 88) // pop r8
                if arg_count >= 5
                    x86_synth_emit_byte(s, 65)
                    x86_synth_emit_byte(s, 90) // pop r10
                if arg_count >= 4
                    x86_synth_emit_byte(s, 90) // pop rdx
                if arg_count >= 3
                    x86_synth_emit_byte(s, 94) // pop rsi
                if arg_count >= 2
                    x86_synth_emit_byte(s, 95) // pop rdi
                if arg_count >= 1
                    x86_synth_emit_byte(s, 88) // pop rax
                x86_synth_emit_byte(s, 15)
                x86_synth_emit_byte(s, 5)  // syscall
                s.synth_last_expr_type = "int"
            // Intrinsic 2: malloc (raw direct kernel SYS_mmap page allocator)
            elif var_name == "malloc"
                if arg_count >= 1
                    x86_synth_emit_byte(s, 95) // pop rdi
                else
                    x86_synth_emit_mov_rdi_imm64(s, 32)
                x86_synth_emit_call_helper(s, "_lipi_malloc")
                s.synth_last_expr_type = ""
            // Intrinsic 2b: alloc / বরাদ্দ / mem_alloc / মেমরি_বরাদ্দ (segregated slab freelist bump allocator)
            // WHY: Uses O(1) segregated slab freelist recycling and stores valid size/STR0 headers within [_heap_base, _heap_ptr)
            elif var_name == "alloc" or var_name == "বরাদ্দ" or var_name == "mem_alloc" or var_name == "মেমরি_বরাদ্দ" or var_name == "sys_alloc"
                if arg_count >= 1
                    x86_synth_emit_byte(s, 95) // pop rdi
                else
                    x86_synth_emit_mov_rdi_imm64(s, 32)
                x86_synth_emit_call_helper(s, "_lipi_user_alloc")
                s.synth_last_expr_type = ""
            // Intrinsic 2c: 1-arg free / মুক্ত (segregated slab freelist recycler)
            // WHY: Routes 1-argument free(ptr) directly to _lipi_user_free even when utso/core/memory.lp
            // defines 2-argument free(addr, size) for kernel page SYS_munmap.
            elif arg_count == 1 and (var_name == "free" or var_name == "মুক্ত" or var_name == "mem_free" or var_name == "sys_free" or var_name == "মেমরি_মুক্তি")
                x86_synth_emit_byte(s, 95) // pop rdi
                x86_synth_emit_call_helper(s, "_lipi_user_free")
                s.synth_last_expr_type = "int"
            // Intrinsic 3: mem_word_read
            elif var_name == "mem_word_read" or var_name == "mem_read" or var_name == "মেমরি_পড়ো"
                if arg_count >= 2
                    x86_synth_emit_byte(s, 94) // pop rsi
                if arg_count >= 1
                    x86_synth_emit_byte(s, 95) // pop rdi
                // mov rax, [rdi + rsi]
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 139)
                x86_synth_emit_byte(s, 4)
                x86_synth_emit_byte(s, 55)
                s.synth_last_expr_type = "int"
            // Intrinsic 4: mem_word_write
            elif var_name == "mem_word_write" or var_name == "mem_write" or var_name == "মেমরি_লেখো"
                if arg_count >= 3
                    x86_synth_emit_byte(s, 90) // pop rdx
                if arg_count >= 2
                    x86_synth_emit_byte(s, 94) // pop rsi
                if arg_count >= 1
                    x86_synth_emit_byte(s, 95) // pop rdi
                // mov [rdi + rsi], rdx
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 20)
                x86_synth_emit_byte(s, 55)
                // mov rax, rdx
                x86_synth_emit_byte(s, 72)
                x86_synth_emit_byte(s, 137)
                x86_synth_emit_byte(s, 208)
                s.synth_last_expr_type = "int"
            // Intrinsic 5: mem_byte_read
            elif var_name == "mem_byte_read" or var_name == "mem_read_byte" or var_name == "মেমরি_বাইট_পড়ো" or var_name == "sys_peek8"
                if arg_count >= 2
                    x86_synth_emit_byte(s, 94) // pop rsi (offset)
                    x86_synth_emit_byte(s, 95) // pop rdi (addr)
                    // movzx rax, byte ptr [rdi + rsi]: 0x48 0x0F 0xB6 0x04 0x37
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 15)
                    x86_synth_emit_byte(s, 182)
                    x86_synth_emit_byte(s, 4)
                    x86_synth_emit_byte(s, 55)
                elif arg_count == 1
                    x86_synth_emit_byte(s, 95) // pop rdi (addr)
                    // movzx rax, byte ptr [rdi]: 0x48 0x0F 0xB6 0x07
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 15)
                    x86_synth_emit_byte(s, 182)
                    x86_synth_emit_byte(s, 7)
                else
                    x86_synth_emit_byte(s, 49) // xor eax, eax
                    x86_synth_emit_byte(s, 192)
                s.synth_last_expr_type = "int"
            // ── Intrinsic 6: mem_byte_write / mem_write_byte / মেমরি_বাইট_লেখো / sys_poke8
            elif var_name == "mem_byte_write" or var_name == "mem_write_byte" or var_name == "মেমরি_বাইট_লেখো" or var_name == "sys_poke8"
                if arg_count >= 3
                    x86_synth_emit_byte(s, 90) // pop rdx (val)
                    x86_synth_emit_byte(s, 94) // pop rsi (offset)
                    x86_synth_emit_byte(s, 95) // pop rdi (addr)
                    // mov [rdi + rsi], dl: 0x88 0x14 0x37
                    x86_synth_emit_byte(s, 136)
                    x86_synth_emit_byte(s, 20)
                    x86_synth_emit_byte(s, 55)
                    // mov rax, rdx
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 208)
                elif arg_count == 2
                    // sys_poke8(addr, val): pop rdx (val), pop rdi (addr)
                    x86_synth_emit_byte(s, 90) // pop rdx (val)
                    x86_synth_emit_byte(s, 95) // pop rdi (addr)
                    // mov [rdi], dl: 0x88 0x17
                    x86_synth_emit_byte(s, 136)
                    x86_synth_emit_byte(s, 23)
                    // mov rax, rdx
                    x86_synth_emit_byte(s, 72)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 208)
                else
                    x86_synth_emit_byte(s, 49) // xor eax, eax
                    x86_synth_emit_byte(s, 192)
                s.synth_last_expr_type = "int"
            // ── Intrinsic 7: exit / বিদায় ─────────────────────────────────────
            elif var_name == "exit" or var_name == "বিদায়"
                if arg_count >= 1
                    x86_synth_emit_byte(s, 95) // pop rdi (status code)
                else
                    x86_synth_emit_byte(s, 49) // xor edi, edi
                    x86_synth_emit_byte(s, 255)
                x86_synth_emit_byte(s, 184)
                x86_synth_emit_u32(s, 60)  // mov eax, 60
                x86_synth_emit_byte(s, 15)
                x86_synth_emit_byte(s, 5)   // syscall
                s.synth_last_expr_type = ""
            // ── Intrinsic 8: list / তালিকা ─────────────────────────────────────
            elif var_name == "list" or var_name == "তালিকা"
                if arg_count == 0
                    // Empty list: _lipi_list_create(0, 0)
                    x86_synth_emit_byte(s, 49) // xor edi, edi
                    x86_synth_emit_byte(s, 255)
                    x86_synth_emit_byte(s, 49) // xor esi, esi
                    x86_synth_emit_byte(s, 246)
                    x86_synth_emit_call_helper(s, "_lipi_list_create")
                else
                    // Allocate list: _lipi_list_create(arg_count, 0)
                    x86_synth_emit_mov_rdi_imm64(s, arg_count)
                    x86_synth_emit_byte(s, 49) // xor esi, esi
                    x86_synth_emit_byte(s, 246)
                    x86_synth_emit_call_helper(s, "_lipi_list_create")
                    // List struct is in %rax: [0]=count, [8]=cap, [16]=data_ptr
                    // mov r10, rax (preserve list struct ptr)
                    x86_synth_emit_byte(s, 73)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 194)
                    // mov r11, [rax + 16] (data_ptr)
                    x86_synth_emit_byte(s, 76)
                    x86_synth_emit_byte(s, 139)
                    x86_synth_emit_byte(s, 88)  // ModR/M: [rax + disp8] (0x58: mod=01, reg=r11, rm=rax)
                    x86_synth_emit_byte(s, 16)
                    // Pop elements from stack in reverse order and store into data_ptr
                    ai = arg_count - 1
                    while ai >= 0
                        x86_synth_emit_byte(s, 88) // pop rax
                        off = ai * 8
                        if off < 128
                            x86_synth_emit_byte(s, 73)  // REX.W + REX.B (0x49)
                            x86_synth_emit_byte(s, 137) // mov
                            x86_synth_emit_byte(s, 67)  // ModR/M: [r11 + disp8] (0x43)
                            x86_synth_emit_byte(s, off)
                        else
                            x86_synth_emit_byte(s, 73)
                            x86_synth_emit_byte(s, 137)
                            x86_synth_emit_byte(s, 131) // ModR/M: [r11 + disp32] (0x83)
                            x86_synth_emit_u32(s, off)
                        ai = ai - 1
                    // Restore list pointer to %rax: mov rax, r10
                    x86_synth_emit_byte(s, 76)
                    x86_synth_emit_byte(s, 137)
                    x86_synth_emit_byte(s, 208)
                s.synth_last_expr_type = ""
            else
                // ── Struct Constructor or Regular Function Call ──────────────
                sdef = x86_synth_find_struct(s, var_name)
                if sdef != 0
                    s.synth_last_struct = var_name
                    fcount = sdef.sd_fields.len()
                    alloc_sz = (fcount + 1) * 8
                    if alloc_sz < 32
                        alloc_sz = 32
                    x86_synth_emit_mov_rdi_imm64(s, alloc_sz)
                    x86_synth_emit_call_alloc(s)
                    if arg_count > 0
                        // Preserve struct pointer in %r10 across argument pops: mov r10, rax
                        x86_synth_emit_byte(s, 73)  // REX.W + REX.B (0x49)
                        x86_synth_emit_byte(s, 137) // mov r/m64, r64 (0x89)
                        x86_synth_emit_byte(s, 194) // ModR/M: r10 <- rax (0xC2)
                        ai = arg_count - 1
                        while ai >= 0
                            x86_synth_emit_byte(s, 89) // pop rcx (arg val)
                            field_off = ai * 8
                            if field_off < 128
                                x86_synth_emit_byte(s, 73)  // REX.W + REX.B (0x49)
                                x86_synth_emit_byte(s, 137) // mov r/m64, r64 (0x89)
                                x86_synth_emit_byte(s, 74)  // ModR/M: [r10 + disp8] (0x4A)
                                x86_synth_emit_byte(s, field_off)
                            else
                                x86_synth_emit_byte(s, 73)  // REX.W + REX.B (0x49)
                                x86_synth_emit_byte(s, 137) // mov r/m64, r64 (0x89)
                                x86_synth_emit_byte(s, 138) // ModR/M: [r10 + disp32] (0x8A)
                                x86_synth_emit_u32(s, field_off)
                            ai = ai - 1
                        // Restore struct pointer to %rax: mov rax, r10
                        x86_synth_emit_byte(s, 76)  // REX.W + REX.R (0x4C)
                        x86_synth_emit_byte(s, 137) // mov r/m64, r64 (0x89)
                        x86_synth_emit_byte(s, 208) // ModR/M: rax <- r10 (0xD0)
                    s.synth_last_expr_type = ""
                else
                    // Regular Function Call: Pop arguments in reverse into calling convention registers
                    lv_fn = x86_synth_find_local_var(s, var_name)
                    if lv_fn != 0 and ((lv_fn.lv_is_spilled == 0 and lv_fn.lv_reg >= 0) or lv_fn.lv_offset > 0)
                        // WHY: Load target fn_ptr/closure into %rax before pop_args so popping
                        // %rdi/%rsi/etc. cannot clobber a register-allocated callee variable.
                        if lv_fn.lv_is_spilled == 0 and lv_fn.lv_reg >= 0
                            x86_synth_emit_mov_reg_reg(s, 0, lv_fn.lv_reg)
                        else
                            x86_synth_emit_load_var(s, 0, lv_fn.lv_offset)
                        end
                        x86_synth_emit_pop_args(s, arg_count)
                        x86_synth_emit_indirect_call_rax(s)
                    else
                        x86_synth_emit_pop_args(s, arg_count)
                        // Direct Function Call: Emits call rel32 (0xE8) and queues relocation
                        call_off = s.synth_code.len()
                        x86_synth_emit_byte(s, 232)
                        patch_pos = s.synth_code.len()
                        x86_synth_emit_u32(s, 0)
                        call_rel = X86CallReloc()
                        call_rel.cr_patch_offset = patch_pos
                        call_rel.cr_call_site_end = patch_pos + 4
                        call_rel.cr_target_name = var_name
                        push(s.synth_call_relocs, call_rel)
                        if var_name == "main" or var_name == "মূল"
                            s.synth_called_top_level_main = 1
                        rt_name = x86_synth_lookup_fn_ret_type(s, var_name)
                        if var_name == "len" or var_name == "length" or var_name == "দৈর্ঘ্য" or var_name == "str_len"
                            s.synth_last_expr_type = "int"
                        elif var_name == "str" or var_name == "to_str" or var_name == "স্ট্রিং"
                            s.synth_last_expr_type = "str"
                        elif var_name == "floor" or var_name == "মেঝে" or var_name == "gc_collect" or var_name == "lipi_gc_collect" or var_name == "ord" or var_name == "mem_byte_read" or var_name == "mem_read_byte" or var_name == "mem_read" or var_name == "mem_word_read" or var_name == "str_char_at" or var_name == "ror32" or var_name == "rol32" or var_name == "clock_ms" or var_name == "cpu_clock" or var_name == "arena_mark" or var_name == "arena_allocated" or var_name == "file_exists" or var_name == "sha256_ch" or var_name == "sha256_maj" or var_name == "sha256_sigma0" or var_name == "sha256_sigma1" or var_name == "sha256_gamma0" or var_name == "sha256_gamma1"
                            s.synth_last_expr_type = "int"
                        else
                            s.synth_last_expr_type = ""
                        if var_name == "restore_extract_single_file"
                            s.synth_last_struct = "ExtractedSingleFile"
                        elif rt_name == "int" or rt_name == "i64" or rt_name == "i32" or rt_name == "u64" or rt_name == "u32"
                            s.synth_last_expr_type = "int"
                            s.synth_last_struct = ""
                        elif rt_name == "float" or rt_name == "f64" or rt_name == "f32"
                            s.synth_last_expr_type = "float"
                            s.synth_last_struct = ""
                        elif rt_name == "str" or rt_name == "string"
                            s.synth_last_expr_type = "str"
                            s.synth_last_struct = ""
                        else
                            s.synth_last_struct = rt_name
                        end
                    end
        else
            // Plain variable load
            lv = x86_synth_find_local_var(s, var_name)
            if lv != 0
                if lv.lv_is_spilled == 0 and lv.lv_reg >= 0
                    x86_synth_emit_mov_reg_reg(s, 0, lv.lv_reg)
                else
                    x86_synth_emit_load_var(s, 0, lv.lv_offset)
                s.synth_last_struct = x86_synth_get_var_type(s, var_name)
                s.synth_last_expr_type = x86_synth_get_prim_type(s, var_name)
            else
                // Check if var_name is a mutable RW global slot or compile-time constant
                mg_off = x86_synth_find_mutable_global(s, var_name)
                if mg_off >= 512
                    x86_synth_emit_mutable_global_read(s, mg_off)
                    s.synth_last_struct = x86_synth_get_mutable_global_struct(s, var_name)
                    s.synth_last_expr_type = x86_synth_get_mutable_global_prim(s, var_name)
                else
                    g_val = x86_synth_lookup_global_const(s, var_name)
                    if g_val != (0 - 999999999)
                        x86_synth_emit_mov_rax_imm64(s, g_val)
                        s.synth_last_expr_type = "int"
                    else
                        // Check if var_name is a registered zero-arg constant function
                        is_fn_const = 0
                        if x86_synth_find_fn_first(s, var_name) != 0
                            is_fn_const = 1
                        end
                        if is_fn_const == 1
                            // Check for parenthesis-less argument on the same line (e.g. say bench_loop 10000000)
                            if next_pos < toks.len() and toks[next_pos].tok_span.span_start_line == t.tok_span.span_start_line
                                nk = toks[next_pos].tok_kind
                                ntxt = toks[next_pos].tok_text
                                if nk == TOK_INT() or nk == TOK_FLOAT() or nk == TOK_STR() or nk == TOK_INTERP_STR() or (nk == TOK_IDENT() and x86_synth_find_local_var(s, ntxt) != 0)
                                    x86_synth_compile_expr(s, toks, pos_box)
                                    // mov rdi, rax (pass argument 0 in %rdi)
                                    x86_synth_emit_byte(s, 72)
                                    x86_synth_emit_byte(s, 137)
                                    x86_synth_emit_byte(s, 199)
                                end
                            end
                            // Emit direct call: call var_name (leaves return value in %rax)
                            x86_synth_emit_byte(s, 232)
                            patch_pos = s.synth_code.len()
                            x86_synth_emit_u32(s, 0)
                            call_rel = X86CallReloc()
                            call_rel.cr_patch_offset = patch_pos
                            call_rel.cr_call_site_end = patch_pos + 4
                            call_rel.cr_target_name = var_name
                            push(s.synth_call_relocs, call_rel)
                            if var_name == "main" or var_name == "মূল"
                                s.synth_called_top_level_main = 1
                            end
                            if var_name == "len" or var_name == "length" or var_name == "দৈর্ঘ্য" or var_name == "str_len"
                                s.synth_last_expr_type = "int"
                            elif var_name == "str" or var_name == "to_str" or var_name == "স্ট্রিং"
                                s.synth_last_expr_type = "str"
                            else
                                s.synth_last_expr_type = ""
                            end
                        else
                            // Unbound identifier defaults to 0
                            x86_synth_emit_byte(s, 49)
                            x86_synth_emit_byte(s, 192)
                            s.synth_last_expr_type = ""
                        end
                    end
                end
    else
        // WHY: Syntax error guard against unexpected delimiters inside expression operands
        if k == TOK_SEMI() or k == TOK_RBRACE() or k == TOK_RPAREN() or txt == ";" or txt == "}" or txt == ")"
            say "❌ [Syntax Error]: Unexpected delimiter '" + txt + "' in expression at line " + str(t.tok_span.span_start_line)
            exit(1)
        end
        // Fallback: advance and clear %rax
        list_set(pos_box, 0, pos + 1)
        x86_synth_emit_byte(s, 49)
        x86_synth_emit_byte(s, 192)
        s.synth_last_expr_type = ""

    // ── Postfix Chaining Loop: [index], .field, .method(...) ────────────────
    x86_synth_expr_postfix(s, toks, pos_box)
    return 0

