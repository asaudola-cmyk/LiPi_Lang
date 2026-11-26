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
    // and calling [env_ptr+8]) AND raw function pointers in %rax without clobbering %r11.
    // Safely returns 0 on NULL or small integer targets (<= 4096).
    x86_synth_emit_bytes(s, [
        72, 61, 0, 16, 0, 0,
        118, 19,
        129, 56, 83, 79, 76, 67,
        117, 7,
        73, 137, 194,
        72, 139, 64, 8,
        255, 208,
        235, 2,
        49, 192
    ])
    s.synth_last_store_end = 0 - 1
    s.synth_last_expr_type = ""
    s.synth_last_struct = ""
    s.synth_last_elem_type = ""
    return 0

fn x86_synth_emit_closure_literal s toks pos_box c_params
    // WHY: Synthesizes a first-class capturing closure supporting all 3 Lipi forms:
    //   1. Single expression: |x| => expr  /  fn(a, b) => expr
    //   2. Brace block:       |x| => { stmts }  /  fn(a, b) => { stmts }
    //   3. Native block:      fn(a, b)\n stmts\n end  /  fn(a, b) =>\n stmts\n end
    // Emits isolated closure machine code inline (skipped via jmp), scans free outer locals
    // to pack into a 24B+`CLOS` heap environment object, and binds captures via %r10.
    clos_hdr_line = 0
    if get(pos_box, 0) > 0 and get(pos_box, 0) - 1 < toks.len()
        clos_hdr_line = toks[get(pos_box, 0) - 1].tok_span.span_start_line
    end
    if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_FAT_ARROW() or toks[get(pos_box, 0)].tok_text == "=>" or toks[get(pos_box, 0)].tok_kind == TOK_ARROW() or toks[get(pos_box, 0)].tok_text == "->")
        clos_hdr_line = toks[get(pos_box, 0)].tok_span.span_start_line
        list_set(pos_box, 0, get(pos_box, 0) + 1)
    end

    // Determine body form: 0 = inline expr, 1 = { ... } brace block, 2 = native multi-line ... end block
    clos_mode = 0
    if get(pos_box, 0) < toks.len()
        bt_c = toks[get(pos_box, 0)]
        if bt_c.tok_kind == TOK_LBRACE() or (bt_c.tok_kind != TOK_STR() and bt_c.tok_text == "{")
            clos_mode = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        elif bt_c.tok_kind == TOK_NEWLINE()
            clos_mode = 2
            x86_synth_skip_whitespace_tokens(toks, pos_box)
        end
    end

    // Scan closure body tokens for free outer local variables
    cap_names = list()
    cap_types = list()
    cap_prims = list()
    cap_boxed = list()
    scan_i = get(pos_box, 0)
    paren_d = 0
    blk_depth = 0
    while scan_i < toks.len()
        stk = toks[scan_i]
        sk = stk.tok_kind
        stxt = stk.tok_text
        if clos_mode == 1
            if sk == TOK_LBRACE() or (sk != TOK_STR() and stxt == "{")
                blk_depth = blk_depth + 1
            elif sk == TOK_RBRACE() or (sk != TOK_STR() and stxt == "}")
                if blk_depth == 0
                    break
                end
                blk_depth = blk_depth - 1
            end
        elif clos_mode == 2
            if sk == TOK_EOF()
                break
            elif sk == TOK_KW_IF() or sk == TOK_KW_WHILE() or sk == TOK_KW_FOR() or sk == TOK_KW_MATCH() or sk == TOK_KW_TRY() or sk == TOK_KW_FN() or (sk == TOK_IDENT() and (stxt == "if" or stxt == "while" or stxt == "for" or stxt == "match" or stxt == "try" or stxt == "region" or stxt == "অঞ্চল" or stxt == "fn" or stxt == "কাজ" or stxt == "মিল" or stxt == "যদি" or stxt == "যতক্ষণ"))
                if scan_i + 1 >= toks.len() or (toks[scan_i + 1].tok_kind != TOK_ASSIGN() and toks[scan_i + 1].tok_text != "=")
                    blk_depth = blk_depth + 1
                end
            elif x86_synth_is_block_end(toks, scan_i) == 1
                if blk_depth == 0
                    break
                end
                blk_depth = blk_depth - 1
            end
        else
            if sk == TOK_LPAREN() or stxt == "(" or sk == TOK_LBRACKET() or stxt == "[" or sk == TOK_LBRACE() or stxt == "{"
                paren_d = paren_d + 1
            elif sk == TOK_RPAREN() or stxt == ")" or sk == TOK_RBRACKET() or stxt == "]" or sk == TOK_RBRACE() or stxt == "}"
                if paren_d == 0
                    break
                end
                paren_d = paren_d - 1
            elif (sk == TOK_COMMA() or stxt == ",") and paren_d == 0
                break
            elif (sk == TOK_NEWLINE() or sk == TOK_SEMI() or sk == TOK_EOF()) and paren_d == 0
                break
            end
        end
        if x86_synth_is_ident_token(sk) == 1
            is_member_or_call = 0
            if scan_i > 0 and (toks[scan_i - 1].tok_kind == TOK_DOT() or toks[scan_i - 1].tok_text == ".")
                is_member_or_call = 1
            end
            if scan_i + 1 < toks.len() and (toks[scan_i + 1].tok_kind == TOK_LPAREN() or toks[scan_i + 1].tok_text == "(")
                // WHY: Allow capturing outer local closure/fn-ptr variables when invoked inside a nested closure
                // (enables recursive closures like `f = 0; f = fn(n) { ... f(n - 1) }`), while skipping top-level fn calls.
                if x86_synth_find_local_var(s, stxt) == 0
                    is_member_or_call = 1
                end
            end
            if scan_i > 0 and (toks[scan_i - 1].tok_kind == TOK_KW_LET() or toks[scan_i - 1].tok_text == "let" or toks[scan_i - 1].tok_text == "ধরি" or toks[scan_i - 1].tok_text == "চলক")
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
                            push(cap_boxed, lv_o.lv_is_boxed)
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
    saved_boxed_c = s.synth_boxed_vars
    saved_def_s = s.synth_defer_starts
    saved_def_e = s.synth_defer_ends
    saved_def_u = s.synth_has_defer_unwind
    saved_def_m = s.synth_defer_mask_off
    saved_def_err = s.synth_defer_err_off
    saved_def_pad = s.synth_in_defer_unwind_pad
    s.synth_locals = list()
    s.synth_stack_offset = 64
    s.synth_in_function = 1
    s.synth_current_fn = "__closure"
    s.synth_regalloc_names = list()
    s.synth_regalloc_regs = list()
    s.synth_boxed_vars = list()
    s.synth_defer_starts = list()
    s.synth_defer_ends = list()
    s.synth_has_defer_unwind = 0
    s.synth_defer_mask_off = 0
    s.synth_defer_err_off = 0
    s.synth_in_defer_unwind_pad = 0
    s.synth_last_store_end = 0 - 1

    prologue_patch = x86_synth_emit_prologue(s)
    pi = 0
    while pi < c_params.len()
        p_off = x86_synth_alloc_var(s, c_params[pi])
        x86_synth_emit_store_param(s, pi, p_off)
        pi = pi + 1
    end

    // Load captured outer values (or shared 8B upvalue cell pointers!) from [r10 + 24 + ci*8]
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
        if cap_boxed[ci] == 1
            lv_cb = x86_synth_find_local_var(s, cap_names[ci])
            if lv_cb != 0
                lv_cb.lv_is_boxed = 1
            end
        end
        if cap_types[ci] != ""
            x86_synth_set_var_type(s, cap_names[ci], cap_types[ci])
        end
        if cap_prims[ci] != ""
            x86_synth_set_prim_type(s, cap_names[ci], cap_prims[ci])
        end
        ci = ci + 1
    end

    if clos_mode == 1
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cp_cb = get(pos_box, 0)
            if cp_cb >= toks.len() break end
            if toks[cp_cb].tok_kind == TOK_RBRACE() or (toks[cp_cb].tok_kind != TOK_STR() and toks[cp_cb].tok_text == "}")
                list_set(pos_box, 0, cp_cb + 1)
                break
            end
            bp_cb = get(pos_box, 0)
            x86_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) <= bp_cb list_set(pos_box, 0, bp_cb + 1) end
        end
    elif clos_mode == 2
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cp_cb2 = get(pos_box, 0)
            if cp_cb2 >= toks.len() break end
            if x86_synth_is_block_end(toks, cp_cb2) == 1
                list_set(pos_box, 0, cp_cb2 + 1)
                break
            end
            bp_cb2 = get(pos_box, 0)
            x86_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) <= bp_cb2 list_set(pos_box, 0, bp_cb2 + 1) end
        end
    else
        x86_synth_compile_expr(s, toks, pos_box)
    end
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
    s.synth_boxed_vars = saved_boxed_c
    s.synth_defer_starts = saved_def_s
    s.synth_defer_ends = saved_def_e
    s.synth_has_defer_unwind = saved_def_u
    s.synth_defer_mask_off = saved_def_m
    s.synth_defer_err_off = saved_def_err
    s.synth_in_defer_unwind_pad = saved_def_pad
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

fn x86_synth_interp_load_rodata s lit_text
    ro_off = x86_synth_add_rodata_str(s, lit_text, 0)
    x86_synth_emit_byte(s, 72)
    x86_synth_emit_byte(s, 184) // mov rax, imm64
    patch_pos = s.synth_code.len()
    x86_synth_emit_u64(s, 0)
    rel = X86StringReloc()
    rel.sr_patch_offset = patch_pos
    rel.sr_rodata_offset = ro_off
    push(s.synth_str_relocs, rel)
    return 0

fn x86_synth_interp_is_ident inner
    ilen = len(inner)
    if ilen == 0
        return 0
    end
    ii = 0
    while ii < ilen
        c = ord(char_at(inner, ii))
        ok = 0
        if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c >= 128
            ok = 1
        end
        if ok == 0
            return 0
        end
        ii = ii + 1
    end
    return 1

fn x86_synth_interp_can_resolve s inner
    if x86_synth_find_local_var(s, inner) != 0
        return 1
    end
    if x86_synth_find_mutable_global(s, inner) >= 512
        return 1
    end
    if x86_synth_lookup_global_const(s, inner) != (0 - 999999999)
        return 1
    end
    return 0

fn x86_synth_emit_interp_str s txt
    // WHY: Safely expands ONLY `{ident}` placeholders whose identifier resolves in scope.
    // CSS/JS/JSON strings like "body {margin:0}" or "{return 1}" stay 100% literal in .rodata!
    tlen = len(txt)
    chunk_types = list()
    chunk_vals = list()
    has_any_var = 0
    cur_lit = ""
    i = 0
    while i < tlen
        ch = char_at(txt, i)
        if ch == "{"
            j = i + 1
            found_close = 0
            while j < tlen
                cj = char_at(txt, j)
                if cj == "}"
                    found_close = 1
                    break
                end
                if cj == "{" or cj == "\n" or cj == "\r"
                    break
                end
                j = j + 1
            end
            if found_close == 1
                inner = str_sub(txt, i + 1, j)
                if x86_synth_interp_is_ident(inner) == 1 and x86_synth_interp_can_resolve(s, inner) == 1
                    if len(cur_lit) > 0
                        push(chunk_types, 0)
                        push(chunk_vals, cur_lit)
                        cur_lit = ""
                    end
                    push(chunk_types, 1)
                    push(chunk_vals, inner)
                    has_any_var = 1
                    i = j + 1
                    continue
                end
            end
        end
        cur_lit = cur_lit + ch
        i = i + 1
    end
    if has_any_var == 0
        x86_synth_interp_load_rodata(s, txt)
        return 0
    end
    if len(cur_lit) > 0
        push(chunk_types, 0)
        push(chunk_vals, cur_lit)
    end

    // Emit and concatenate parts safely with 16-byte stack alignment
    ci = 0
    while ci < chunk_types.len()
        if ci > 0
            x86_synth_emit_bytes(s, [80, 72, 131, 236, 8]) // push rax; sub rsp, 8
        end
        if chunk_types[ci] == 0
            x86_synth_interp_load_rodata(s, chunk_vals[ci])
        else
            vname = chunk_vals[ci]
            lv = x86_synth_find_local_var(s, vname)
            if lv != 0
                if lv.lv_is_spilled == 0 and lv.lv_reg >= 0
                    x86_synth_emit_mov_reg_reg(s, 0, lv.lv_reg)
                else
                    x86_synth_emit_load_var(s, 0, lv.lv_offset)
                end
                if lv.lv_is_boxed == 1
                    x86_synth_emit_bytes(s, [72, 139, 0]) // mov rax, [rax]
                end
            else
                mg_off = x86_synth_find_mutable_global(s, vname)
                if mg_off >= 512
                    x86_synth_emit_mutable_global_read(s, mg_off)
                else
                    g_val = x86_synth_lookup_global_const(s, vname)
                    x86_synth_emit_mov_rax_imm64(s, g_val)
                end
            end
            // mov rdi, rax; call typed/tagged string converter
            x86_synth_emit_bytes(s, [72, 137, 199])
            if lv != 0 and lv.lv_prim_type == "float"
                x86_synth_emit_call_helper(s, "_lipi_float_to_str")
            elif lv != 0 and lv.lv_prim_type == "dyn_tagged" and lv.lv_tag_off > 0
                x86_synth_emit_load_var(s, 6, lv.lv_tag_off) // mov rsi, [rbp - lv_tag_off]
                x86_synth_emit_call_helper(s, "_lipi_ensure_str_tagged")
            else
                x86_synth_emit_call_helper(s, "_lipi_ensure_str")
            end
        end
        if ci > 0
            // mov rsi, rax; add rsp, 8; pop rdi; call _lipi_str_concat
            x86_synth_emit_bytes(s, [72, 137, 198, 72, 131, 196, 8, 95])
            x86_synth_emit_call_helper(s, "_lipi_str_concat")
        end
        ci = ci + 1
    end
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
        elif s.synth_last_expr_type == "dyn_tagged"
            // test dl, 1; jz +7; btc rax, 63; jmp +3; neg rax (preserves %rdx tag!)
            x86_synth_emit_bytes(s, [246, 194, 1, 116, 7, 72, 15, 186, 248, 63, 235, 3, 72, 247, 216])
            s.synth_last_expr_type = "dyn_tagged"
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
            if lv_amp != 0
                if lv_amp.lv_is_spilled == 0 and lv_amp.lv_reg >= 0
                    x86_synth_emit_mov_reg_reg(s, 0, lv_amp.lv_reg)
                    x86_synth_emit_store_var(s, 0, lv_amp.lv_offset)
                    lv_amp.lv_is_spilled = 1
                end
                // lea rax, [rbp - off] (48 8D 85 disp32)
                x86_synth_emit_bytes(s, [72, 141, 133])
                x86_synth_emit_u32(s, 0 - lv_amp.lv_offset)
                amp_inner = "i64"
                if lv_amp.lv_type != ""
                    amp_inner = lv_amp.lv_type
                elif lv_amp.lv_prim_type == "float"
                    amp_inner = "f64"
                elif lv_amp.lv_prim_type == "uint"
                    amp_inner = "u64"
                end
                s.synth_last_struct = "*mut " + amp_inner
                s.synth_last_expr_type = "uint"
                s.synth_last_elem_type = ""
            else
                x86_synth_emit_fn_ptr_lea(s, tname)
            end
            return 0
        end
        x86_synth_expr_primary(s, toks, pos_box)
        return 0

    // 0d3. Unary `await` / `অপেক্ষা` — drives stackful fiber + Linux epoll event loop to completion!
    elif (k == TOK_KW_AWAIT() or (k == TOK_IDENT() and (txt == "await" or txt == "অপেক্ষা" or txt == "@await"))) and pos + 1 < toks.len() and toks[pos + 1].tok_span.span_start_line == t.tok_span.span_start_line and (x86_synth_is_ident_token(toks[pos + 1].tok_kind) == 1 or toks[pos + 1].tok_kind == TOK_LPAREN() or toks[pos + 1].tok_kind == TOK_LBRACKET() or toks[pos + 1].tok_kind == TOK_INT() or toks[pos + 1].tok_kind == TOK_FLOAT() or toks[pos + 1].tok_kind == TOK_STR() or toks[pos + 1].tok_kind == TOK_INTERP_STR() or toks[pos + 1].tok_kind == TOK_BOOL() or toks[pos + 1].tok_kind == TOK_NONE() or toks[pos + 1].tok_kind == TOK_BANG() or toks[pos + 1].tok_kind == TOK_AMP())
        list_set(pos_box, 0, pos + 1)
        x86_synth_expr_primary(s, toks, pos_box)
        aw_expr_t = s.synth_last_expr_type
        aw_struct = s.synth_last_struct
        aw_elem_t = s.synth_last_elem_type
        if s.synth_freestanding == 0
            x86_synth_emit_bytes(s, [72, 137, 199]) // mov rdi, rax
            x86_synth_emit_call_helper(s, "_lipi_async_await")
        end
        s.synth_last_expr_type = aw_expr_t
        s.synth_last_struct = aw_struct
        s.synth_last_elem_type = aw_elem_t
        return 0

    // 0d2. Unary Pointer Dereference (*ptr_expr) — loads exact pointee width (1/2/4/8B) or struct ref!
    elif (k == TOK_STAR() or (k != TOK_STR() and txt == "*")) and pos + 1 < toks.len()
        list_set(pos_box, 0, pos + 1)
        x86_synth_expr_primary(s, toks, pos_box)
        deref_ptr_t = s.synth_last_struct
        deref_pt = x86_synth_ptr_pointee(deref_ptr_t)
        if deref_pt == ""
            deref_pt = "i64"
        end
        x86_synth_emit_null_check_rax(s)
        if x86_synth_find_struct(s, deref_pt) != 0
            // Struct/union pointer dereference preserves address in %rax with unwrapped struct type
            s.synth_last_struct = deref_pt
            s.synth_last_expr_type = ""
            s.synth_last_elem_type = ""
        else
            dp_info = x86_synth_type_layout_info(s, deref_pt)
            x86_synth_emit_field_load_rax(s, 0, dp_info[0], dp_info[3], 0)
            s.synth_last_elem_type = ""
            if deref_pt == "float" or deref_pt == "f64" or deref_pt == "f32"
                s.synth_last_expr_type = "float"
                s.synth_last_struct = ""
            elif x86_synth_is_ptr_type(deref_pt) == 1
                s.synth_last_expr_type = "uint"
                s.synth_last_struct = deref_pt
            elif dp_info[3] == 0
                s.synth_last_expr_type = "uint"
                s.synth_last_struct = ""
            else
                s.synth_last_expr_type = "int"
                s.synth_last_struct = ""
            end
        end
        return 0

    // 0e. Closure literal: |p1, p2| => expr / { ... }
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
            elif ct_c.tok_kind == TOK_COLON() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == ":")
                list_set(pos_box, 0, cp_c + 1)
                if get(pos_box, 0) < toks.len() and x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            elif x86_synth_is_ident_token(ct_c.tok_kind) == 1
                push(c_params, ct_c.tok_text)
                list_set(pos_box, 0, cp_c + 1)
            else
                list_set(pos_box, 0, cp_c + 1)
            end
        end
        x86_synth_emit_closure_literal(s, toks, pos_box, c_params)
        return 0

    // 0f. Lambda literal: fn(p1, p2) => expr / { ... } / native block ... end
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
            elif ct_c.tok_kind == TOK_COLON() or (ct_c.tok_kind != TOK_STR() and ct_c.tok_text == ":")
                list_set(pos_box, 0, cp_c + 1)
                if get(pos_box, 0) < toks.len() and x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            elif x86_synth_is_ident_token(ct_c.tok_kind) == 1
                push(c_params, ct_c.tok_text)
                list_set(pos_box, 0, cp_c + 1)
            else
                list_set(pos_box, 0, cp_c + 1)
            end
        end
        x86_synth_emit_closure_literal(s, toks, pos_box, c_params)
        return 0

    // 0g. Value-Returning Pattern Match Expression: res = match x ... end  /  match x { 1 => v1, _ => v2 }
    elif x86_synth_is_match_start(toks, pos) == 1
        me_base_col = t.tok_span.span_start_col
        me_base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1)
        x86_synth_compile_expr(s, toks, pos_box)
        me_scrut_off = s.synth_stack_offset
        s.synth_stack_offset = s.synth_stack_offset + 8
        x86_synth_emit_store_var(s, 0, me_scrut_off)
        me_end_patches = list()
        me_has_wild = 0
        me_arm_type = ""
        me_arm_struct = ""
        me_saw_adt = 0
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        me_braced = 0
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
            me_braced = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        me_first_arm_col = 0 - 1
        while get(pos_box, 0) < toks.len()
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_me = get(pos_box, 0)
            if cur_me >= toks.len() break end
            ct_me = toks[cur_me]
            if me_braced == 1
                if ct_me.tok_kind == TOK_RBRACE() or (ct_me.tok_kind != TOK_STR() and ct_me.tok_text == "}")
                    list_set(pos_box, 0, cur_me + 1)
                    break
                end
                if ct_me.tok_kind == TOK_COMMA() or (ct_me.tok_kind != TOK_STR() and ct_me.tok_text == ",")
                    list_set(pos_box, 0, cur_me + 1)
                    continue
                end
            else
                if x86_synth_is_block_end(toks, cur_me) == 1
                    list_set(pos_box, 0, cur_me + 1)
                    break
                end
                if me_first_arm_col < 0
                    me_first_arm_col = ct_me.tok_span.span_start_col
                elif ct_me.tok_span.span_start_col < me_first_arm_col
                    break
                end
            end
            if ct_me.tok_kind == TOK_KW_CASE() or (ct_me.tok_kind == TOK_IDENT() and (ct_me.tok_text == "case" or ct_me.tok_text == "ক্ষেত্র"))
                list_set(pos_box, 0, cur_me + 1)
            end
            me_miss = 0 - 1
            me_adt_miss = 0
            mp_p = get(pos_box, 0)
            if mp_p < toks.len() and (toks[mp_p].tok_text == "_" or toks[mp_p].tok_text == "default" or toks[mp_p].tok_text == "অন্যথায়" or toks[mp_p].tok_kind == TOK_KW_ELSE())
                me_has_wild = 1
                list_set(pos_box, 0, mp_p + 1)
            else
                me_adt_miss = x86_synth_try_compile_adt_pattern(s, toks, pos_box, me_scrut_off)
                if me_adt_miss != 0
                    me_saw_adt = 1
                else
                    x86_synth_compile_expr(s, toks, pos_box)
                    x86_synth_emit_bytes(s, [72, 137, 198]) // mov rsi, rax
                    x86_synth_emit_load_var(s, 7, me_scrut_off)
                    if s.synth_freestanding == 1
                        x86_synth_emit_bytes(s, [72, 57, 247, 15, 133]) // cmp rdi, rsi; jne next_arm
                    else
                        x86_synth_emit_call_helper(s, "_lipi_cmp_dynamic")
                        x86_synth_emit_bytes(s, [133, 192, 15, 133]) // test eax, eax; jnz next_arm
                    end
                    me_miss = s.synth_code.len()
                    x86_synth_emit_u32(s, 0)
                end
            end
            if get(pos_box, 0) < toks.len()
                sk_me = toks[get(pos_box, 0)].tok_kind
                st_me = toks[get(pos_box, 0)].tok_text
                if sk_me == TOK_FAT_ARROW() or sk_me == TOK_COLON() or sk_me == TOK_ARROW() or st_me == "=>" or st_me == ":" or st_me == "->"
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
            end
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_LBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "{"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                while get(pos_box, 0) < toks.len()
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                    cp_mb = get(pos_box, 0)
                    if cp_mb >= toks.len() break end
                    if toks[cp_mb].tok_kind == TOK_RBRACE() or (toks[cp_mb].tok_kind != TOK_STR() and toks[cp_mb].tok_text == "}")
                        list_set(pos_box, 0, cp_mb + 1)
                        break
                    end
                    bp_me = get(pos_box, 0)
                    x86_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) <= bp_me list_set(pos_box, 0, bp_me + 1) end
                end
            else
                x86_synth_compile_expr(s, toks, pos_box)
                if me_saw_adt == 1 and s.synth_last_expr_type != "dyn_tagged"
                    if s.synth_last_expr_type == "float"
                        x86_synth_emit_bytes(s, [186, 1, 0, 0, 0]) // mov edx, 1
                    elif s.synth_last_expr_type == "str"
                        x86_synth_emit_bytes(s, [186, 2, 0, 0, 0]) // mov edx, 2
                    else
                        x86_synth_emit_bytes(s, [49, 210]) // xor edx, edx
                    end
                end
                if me_arm_type == ""
                    me_arm_type = s.synth_last_expr_type
                elif s.synth_last_expr_type != "" and me_arm_type != s.synth_last_expr_type
                    if me_saw_adt == 1
                        me_arm_type = "dyn_tagged"
                    end
                end
                if me_arm_struct == "" and s.synth_last_struct != ""
                    me_arm_struct = s.synth_last_struct
                end
            end
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COMMA() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ","))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            x86_synth_emit_byte(s, 233)
            ep_me = s.synth_code.len()
            x86_synth_emit_u32(s, 0)
            push(me_end_patches, ep_me)
            if me_miss >= 0
                next_me_off = s.synth_code.len()
                x86_synth_patch_u32(s, me_miss, next_me_off - (me_miss + 4))
            end
            if me_adt_miss != 0
                next_me_off = s.synth_code.len()
                mai = 0
                while mai < me_adt_miss.len()
                    x86_synth_patch_u32(s, me_adt_miss[mai], next_me_off - (me_adt_miss[mai] + 4))
                    mai = mai + 1
                end
            end
            s.synth_last_store_end = 0 - 1
        end
        if me_has_wild == 0
            x86_synth_emit_bytes(s, [49, 192, 49, 210]) // default 0 (tag 0) if no arm matched
        end
        end_me_off = s.synth_code.len()
        mei = 0
        while mei < me_end_patches.len()
            x86_synth_patch_u32(s, me_end_patches[mei], end_me_off - (me_end_patches[mei] + 4))
            mei = mei + 1
        end
        s.synth_last_expr_type = me_arm_type
        s.synth_last_struct = me_arm_struct
        s.synth_last_elem_type = ""
        s.synth_last_store_end = 0 - 1
        return 0

    // 1. Integer / Boolean / None Literal (checks ADT unit variant first if user defined `enum Option { ..., None }`)
    elif k == TOK_INT() or k == TOK_BOOL() or k == TOK_NONE()
        list_set(pos_box, 0, pos + 1)
        none_adt = 0
        if k == TOK_NONE()
            none_adt = x86_synth_find_adt_variant(s, "", txt)
        end
        if none_adt != 0 and none_adt[0].ed_is_adt == 1
            x86_synth_emit_adt_alloc(s, none_adt[1], 0, 0)
            s.synth_last_expr_type = ""
            s.synth_last_struct = none_adt[0].ed_name
            s.synth_last_elem_type = ""
        else
            x86_synth_emit_mov_rax_imm64(s, t.tok_int_val)
            s.synth_last_expr_type = "int"
            s.synth_last_struct = ""
            s.synth_last_elem_type = ""
        end

    // 1b. Float Literal: IEEE-754 binary64 64-bit precision
    elif k == TOK_FLOAT()
        list_set(pos_box, 0, pos + 1)
        fbits = x86_synth_parse_float_bits(t.tok_text)
        x86_synth_emit_mov_rax_imm64(s, fbits)
        s.synth_last_expr_type = "float"
        s.synth_last_struct = ""
        s.synth_last_elem_type = ""

    // 2. String Literal & Interpolated String Literal (safe resolved-{ident} expansion)
    elif k == TOK_STR()
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
        s.synth_last_elem_type = ""

    elif k == TOK_INTERP_STR()
        list_set(pos_box, 0, pos + 1)
        x86_synth_emit_interp_str(s, t.tok_text)
        s.synth_last_expr_type = "str"
        s.synth_last_struct = ""
        s.synth_last_elem_type = ""

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
            s.synth_last_expr_type = ""
            s.synth_last_struct = ""
            s.synth_last_elem_type = ""
        else
            elem_count = 0
            arr_elem_t = ""
            mixed_elem_t = 0
            while get(pos_box, 0) < toks.len()
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cp = get(pos_box, 0)
                if cp >= toks.len() or toks[cp].tok_kind == TOK_RBRACKET() or (toks[cp].tok_kind != TOK_STR() and toks[cp].tok_text == "]")
                    break
                x86_synth_compile_expr(s, toks, pos_box)
                et = s.synth_last_expr_type
                es = s.synth_last_struct
                if es != "" and mixed_elem_t == 0
                    if arr_elem_t == ""
                        arr_elem_t = es
                    elif arr_elem_t != es
                        arr_elem_t = ""
                        mixed_elem_t = 1
                    end
                elif et == "float" and mixed_elem_t == 0
                    if arr_elem_t == "" or arr_elem_t == "float"
                        arr_elem_t = "float"
                    else
                        arr_elem_t = ""
                        mixed_elem_t = 1
                    end
                elif et == "str" or et == "int"
                    if arr_elem_t != "" and arr_elem_t != et
                        if arr_elem_t == "float" and et == "int"
                            // int widens cleanly in float arrays
                        else
                            arr_elem_t = ""
                            mixed_elem_t = 1
                        end
                    end
                end
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
            s.synth_last_struct = ""
            s.synth_last_elem_type = arr_elem_t

    // 3b. Dynamic Silicon Dict (`{ "k": v }`, `{}`, `{:}`) OR Static Struct Literal (`{ field: val }`)
    elif k == TOK_LBRACE() or (k == TOK_IDENT() and txt == "{") or txt == "{"
        list_set(pos_box, 0, pos + 1) // Consume '{'
        x86_synth_skip_whitespace_tokens(toks, pos_box)

        // WHY: String-keyed literals (`{ "alpha": 10 }`), empty `{}` / `{:}`, and int/computed keys
        // lower to First-Class Silicon DICT0 HashMaps (O(1) Robin-Hood, GC-traced, polymorphic d[k]).
        // Unquoted identifier literals (`{ a: 1, b: 2 }`) remain zero-overhead static structs.
        is_dict_lit = 0
        dp_peek = get(pos_box, 0)
        if dp_peek < toks.len()
            dk0 = toks[dp_peek].tok_kind
            dtxt0 = toks[dp_peek].tok_text
            if dk0 == TOK_RBRACE() or dk0 == TOK_COLON() or dk0 == TOK_STR() or dk0 == TOK_INTERP_STR() or dk0 == TOK_INT() or dk0 == TOK_LBRACKET() or (dk0 != TOK_STR() and (dtxt0 == "}" or dtxt0 == ":" or dtxt0 == "["))
                is_dict_lit = 1
            end
        end
        if is_dict_lit == 1
            x86_synth_emit_mov_rdi_imm64(s, 16)
            x86_synth_emit_call_helper(s, "_lipi_dict_new")
            x86_synth_emit_byte(s, 80) // push rax (preserve dict ptr on stack)
            if dp_peek < toks.len() and (toks[dp_peek].tok_kind == TOK_COLON() or (toks[dp_peek].tok_kind != TOK_STR() and toks[dp_peek].tok_text == ":"))
                list_set(pos_box, 0, dp_peek + 1) // Consume ':' in empty `{:}`
            end
            while get(pos_box, 0) < toks.len()
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cur_dp = get(pos_box, 0)
                if cur_dp >= toks.len()
                    break
                end
                cur_dt = toks[cur_dp]
                if cur_dt.tok_kind == TOK_RBRACE() or (cur_dt.tok_kind != TOK_STR() and cur_dt.tok_text == "}")
                    break
                end
                // Compile dynamic key expression -> push rax
                x86_synth_compile_expr(s, toks, pos_box)
                x86_synth_emit_byte(s, 80) // push rax ([rsp]=key, [rsp+8]=dict)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cur_dp = get(pos_box, 0)
                if cur_dp < toks.len() and (toks[cur_dp].tok_kind == TOK_COLON() or (toks[cur_dp].tok_kind != TOK_STR() and toks[cur_dp].tok_text == ":"))
                    list_set(pos_box, 0, cur_dp + 1) // Consume ':'
                end
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                // Compile value expression -> %rax (with runtime tag in %rdx if dyn_tagged)
                x86_synth_compile_expr(s, toks, pos_box)
                val_et = s.synth_last_expr_type
                // rcx = vtag (1=float, 2=str, rdx if dyn_tagged, 0 otherwise)
                if val_et == "float"
                    x86_synth_emit_bytes(s, [185, 1, 0, 0, 0]) // mov ecx, 1
                elif val_et == "str"
                    x86_synth_emit_bytes(s, [185, 2, 0, 0, 0]) // mov ecx, 2
                elif val_et == "dyn_tagged"
                    x86_synth_emit_bytes(s, [72, 137, 209]) // mov rcx, rdx
                else
                    x86_synth_emit_bytes(s, [49, 201]) // xor ecx, ecx
                end
                // rdx = val, rsi = pop key, rdi = [rsp] (dict) -> call _lipi_dict_set_typed
                x86_synth_emit_bytes(s, [72, 137, 194, 94, 72, 139, 60, 36])
                x86_synth_emit_call_helper(s, "_lipi_dict_set_typed")
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cur_dp = get(pos_box, 0)
                if cur_dp < toks.len() and (toks[cur_dp].tok_kind == TOK_COMMA() or (toks[cur_dp].tok_kind != TOK_STR() and toks[cur_dp].tok_text == ","))
                    list_set(pos_box, 0, cur_dp + 1)
                end
            end
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            cur_dp = get(pos_box, 0)
            if cur_dp < toks.len() and (toks[cur_dp].tok_kind == TOK_RBRACE() or (toks[cur_dp].tok_kind != TOK_STR() and toks[cur_dp].tok_text == "}"))
                list_set(pos_box, 0, cur_dp + 1)
            end
            x86_synth_emit_byte(s, 88) // pop rax (dict ptr)
            s.synth_last_struct = ""
            s.synth_last_expr_type = ""
            s.synth_last_elem_type = "dyn_dict"
            return 0
        end

        // WHY: Scans keys to identify matching struct schema for deterministic field offsets.
        // If any key was already lowered via s.synth_global_fields by an earlier consumer function,
        // keep sname="" so this literal writes to the exact same global field offsets.
        keys = x86_synth_scan_brace_keys(toks, pos + 1)
        sname = x86_synth_find_matching_struct(s, keys)
        is_anon_s = 0
        if sname == "" and keys.len() > 0
            has_gf_conflict = 0
            gki = 0
            while gki < keys.len()
                gfi = 0
                while gfi < s.synth_global_fields.len()
                    if s.synth_global_fields[gfi] == keys[gki]
                        has_gf_conflict = 1
                        break
                    end
                    gfi = gfi + 1
                end
                if has_gf_conflict == 1
                    break
                end
                gki = gki + 1
            end
            if has_gf_conflict == 0
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
        end
        s.synth_last_struct = sname

        // WHY: Size record literals accurately without wasting 1024 bytes per small anonymous object.
        alloc_sz = (keys.len() + 2) * 8
        if sname != ""
            sdef = x86_synth_find_struct(s, sname)
            if sdef != 0
                alloc_sz = (sdef.sd_fields.len() + 2) * 8
            end
        else
            max_gf_off = 0
            gki2 = 0
            while gki2 < keys.len()
                gf_o = x86_synth_get_field_offset(s, "", keys[gki2])
                if gf_o + 8 > max_gf_off
                    max_gf_off = gf_o + 8
                end
                gki2 = gki2 + 1
            end
            if max_gf_off + 16 > alloc_sz
                alloc_sz = max_gf_off + 16
            end
        end
        if alloc_sz < 32
            alloc_sz = 32
        end

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
        s.synth_last_elem_type = ""

    // 4. Parenthesized expression: ( expr )
    elif k == TOK_LPAREN() or (k != TOK_STR() and txt == "(")
        list_set(pos_box, 0, pos + 1)
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        x86_synth_compile_expr(s, toks, pos_box)
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len() and (toks[cur_pos].tok_kind == TOK_RPAREN() or (toks[cur_pos].tok_kind != TOK_STR() and toks[cur_pos].tok_text == ")"))
            list_set(pos_box, 0, cur_pos + 1)

    // 5. Identifier, Intrinsic, ADT Constructor, Generic Struct/Fn Call, or Variable
    elif x86_synth_is_ident_token(k) == 1
        list_set(pos_box, 0, pos + 1)
        var_name = txt
        enum_qual = ""
        next_pos = get(pos_box, 0)
        // Check qualified enum variant: Enum::Variant (e.g. Result::Ok(42), Option::None)
        if next_pos + 2 < toks.len() and (toks[next_pos].tok_kind == TOK_COLON() or toks[next_pos].tok_text == ":") and (toks[next_pos + 1].tok_kind == TOK_COLON() or toks[next_pos + 1].tok_text == ":") and x86_synth_is_ident_token(toks[next_pos + 2].tok_kind) == 1
            enum_qual = var_name
            var_name = toks[next_pos + 2].tok_text
            list_set(pos_box, 0, next_pos + 3)
            next_pos = get(pos_box, 0)
        end
        // Parse optional explicit generic type arguments before '(': fn<float>(...), Box<float>(...)
        call_targs = x86_synth_parse_type_list(toks, pos_box, 1)
        next_pos = get(pos_box, 0)

        // Function, ADT variant, struct constructor, or intrinsic call: name[<T>](...)
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_LPAREN() or (toks[next_pos].tok_kind != TOK_STR() and toks[next_pos].tok_text == "("))
            list_set(pos_box, 0, next_pos + 1) // Consume '('
            if enum_qual == "" and (var_name == "fn_ptr" or var_name == "fn_addr") and x86_synth_find_local_var(s, var_name) == 0
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
            // Compile-time sizeof(Type | Struct | @bss | [N]T) — exact byte size, 0 runtime cost!
            if enum_qual == "" and (var_name == "sizeof" or var_name == "size_of" or var_name == "সাইজ_অফ") and x86_synth_find_local_var(s, var_name) == 0
                save_sz_p = get(pos_box, 0)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                t_sz_str = x86_synth_parse_type_expr(toks, pos_box)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                ct_sz_end = get(pos_box, 0)
                if t_sz_str != "" and ct_sz_end < toks.len() and (toks[ct_sz_end].tok_kind == TOK_RPAREN() or (toks[ct_sz_end].tok_kind != TOK_STR() and toks[ct_sz_end].tok_text == ")"))
                    exact_sz = 0 - 1
                    sd_sz = x86_synth_find_struct(s, t_sz_str)
                    if sd_sz != 0
                        exact_sz = sd_sz.sd_total_size
                    elif t_sz_str == "u8" or t_sz_str == "i8" or t_sz_str == "byte"
                        exact_sz = 1
                    elif t_sz_str == "u16" or t_sz_str == "i16"
                        exact_sz = 2
                    elif t_sz_str == "u32" or t_sz_str == "i32" or t_sz_str == "f32"
                        exact_sz = 4
                    elif t_sz_str == "u64" or t_sz_str == "i64" or t_sz_str == "int" or t_sz_str == "f64" or t_sz_str == "float" or t_sz_str == "ptr" or t_sz_str == "bool" or t_sz_str == "str" or t_sz_str == "string" or x86_synth_is_ptr_type(t_sz_str) == 1
                        exact_sz = 8
                    elif len(t_sz_str) >= 4 and mem_byte_read(t_sz_str, 0) == 91
                        li_sz = x86_synth_type_layout_info(s, t_sz_str)
                        exact_sz = li_sz[0]
                    else
                        bi_sz = x86_synth_find_bss(s, t_sz_str)
                        if bi_sz >= 0
                            exact_sz = s.synth_bss_sizes[bi_sz]
                        else
                            vt_sz = x86_synth_get_var_type(s, t_sz_str)
                            if vt_sz != ""
                                sd_vsz = x86_synth_find_struct(s, vt_sz)
                                if sd_vsz != 0
                                    exact_sz = sd_vsz.sd_total_size
                                end
                            end
                        end
                    end
                    if exact_sz >= 0
                        list_set(pos_box, 0, ct_sz_end + 1) // Consume ')'
                        x86_synth_emit_mov_rax_imm64(s, exact_sz)
                        s.synth_last_expr_type = "int"
                        s.synth_last_struct = ""
                        s.synth_last_elem_type = ""
                        x86_synth_expr_postfix(s, toks, pos_box)
                        return 0
                    end
                end
                list_set(pos_box, 0, save_sz_p)
            end
            // Compile-time offsetof(StructName, field_name) — exact hardware byte offset!
            if enum_qual == "" and (var_name == "offsetof" or var_name == "offset_of" or var_name == "অফসেট_অফ") and x86_synth_find_local_var(s, var_name) == 0
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                of_st = x86_synth_parse_type_expr(toks, pos_box)
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COMMA() or toks[get(pos_box, 0)].tok_text == ",")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                of_fld = ""
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_STR() or x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1)
                    of_fld = toks[get(pos_box, 0)].tok_text
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or toks[get(pos_box, 0)].tok_text == ")")
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                exact_off = x86_synth_get_field_offset(s, of_st, of_fld)
                x86_synth_emit_mov_rax_imm64(s, exact_off)
                s.synth_last_expr_type = "int"
                s.synth_last_struct = ""
                s.synth_last_elem_type = ""
                x86_synth_expr_postfix(s, toks, pos_box)
                return 0
            end
            // Parse arguments into caller registers (%rdi, %rsi, %rdx, %rcx, %r8, %r9)
            // WHY: Multi-line argument lists (e.g. error_code_new(\n "E0001",\n ...)) contain
            // TOK_NEWLINE() tokens that must be skipped so they are not evaluated as spurious 0 arguments.
            arg_count = 0
            arg_expr_types = list()
            arg_struct_types = list()
            while get(pos_box, 0) < toks.len()
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cur_pos = get(pos_box, 0)
                if cur_pos >= toks.len() or toks[cur_pos].tok_kind == TOK_RPAREN() or (toks[cur_pos].tok_kind != TOK_STR() and toks[cur_pos].tok_text == ")")
                    break
                x86_synth_compile_expr(s, toks, pos_box)
                push(arg_expr_types, s.synth_last_expr_type)
                push(arg_struct_types, s.synth_last_struct)
                x86_synth_emit_byte(s, 80) // push rax (save argument)
                arg_count = arg_count + 1
                x86_synth_skip_whitespace_tokens(toks, pos_box)
                cur_pos = get(pos_box, 0)
                if cur_pos < toks.len() and (toks[cur_pos].tok_kind == TOK_COMMA() or (toks[cur_pos].tok_kind != TOK_STR() and toks[cur_pos].tok_text == ","))
                    list_set(pos_box, 0, cur_pos + 1)

            x86_synth_skip_whitespace_tokens(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RPAREN() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ")"))
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            // Intrinsic 1: syscall (blocked at compile time in --freestanding / bare-metal mode)
            if var_name == "syscall" or var_name == "সিসকল" or var_name == "sys_syscall"
                if s.synth_freestanding == 1
                    say "❌ [Bare-Metal Purity Gate]: Linux 'syscall' instruction is forbidden in --freestanding / bare-metal mode! Use port_in*/port_out*/mmio_*/cpu_* or @asm instead."
                    exit(1)
                end
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
                // WHY: For 1..4-arg raw user syscall(...), append a single 1-cycle 5-byte hardware NOP
                // (0F 1F 44 00 00) so Mach-O Darwin translation can unambiguously replace it in-place
                // with `add rsp, N*8; push -78; pop rax` (-ENOSYS) at exact byte-for-byte length!
                if arg_count < 5
                    x86_synth_emit_bytes(s, [15, 31, 68, 0, 0])
                end
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
            // Intrinsic 2c: 1-arg free / মুক্ত / drop (segregated slab freelist recycler)
            // WHY: Routes 1-argument free(ptr) / drop(ptr) directly to _lipi_user_free even when utso/core/memory.lp
            // defines 2-argument free(addr, size) for kernel page SYS_munmap.
            elif arg_count == 1 and (var_name == "free" or var_name == "drop" or var_name == "মুক্ত" or var_name == "mem_free" or var_name == "sys_free" or var_name == "মেমরি_মুক্তি")
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
            // ── Intrinsic 6b: Single-Instruction Volatile Hardware MMIO (16/32/64-bit) ──
            // WHY: Lowers sys_peek16/32/64 & sys_poke16/32/64 inline to a single hardware bus
            // transaction (eliminating utso/os/syscalls.lp byte-loop tearing on PCIe/APIC/VirtIO).
            elif arg_count == 1 and (var_name == "sys_peek16" or var_name == "mmio_r16" or var_name == "mmio_read16" or var_name == "mem_u16_read")
                x86_synth_emit_bytes(s, [95, 15, 183, 7]) // pop rdi; movzx eax, word ptr [rdi]
                s.synth_last_expr_type = "int"
            elif arg_count == 1 and (var_name == "sys_peek32" or var_name == "mmio_r32" or var_name == "mmio_read32_hw" or var_name == "mem_u32_read")
                x86_synth_emit_bytes(s, [95, 139, 7])     // pop rdi; mov eax, dword ptr [rdi]
                s.synth_last_expr_type = "int"
            elif arg_count == 1 and (var_name == "sys_peek64" or var_name == "mmio_r64" or var_name == "mmio_read64" or var_name == "mem_u64_read")
                x86_synth_emit_bytes(s, [95, 72, 139, 7]) // pop rdi; mov rax, qword ptr [rdi]
                s.synth_last_expr_type = "int"
            elif arg_count == 2 and (var_name == "sys_poke16" or var_name == "mmio_w16" or var_name == "mmio_write16" or var_name == "mem_u16_write")
                x86_synth_emit_bytes(s, [88, 95, 102, 137, 7]) // pop rax; pop rdi; mov word ptr [rdi], ax
                s.synth_last_expr_type = "int"
            elif arg_count == 2 and (var_name == "sys_poke32" or var_name == "mmio_w32" or var_name == "mmio_write32_hw" or var_name == "mem_u32_write")
                x86_synth_emit_bytes(s, [88, 95, 137, 7])      // pop rax; pop rdi; mov dword ptr [rdi], eax
                s.synth_last_expr_type = "int"
            elif arg_count == 2 and (var_name == "sys_poke64" or var_name == "mmio_w64" or var_name == "mmio_write64" or var_name == "mem_u64_write")
                x86_synth_emit_bytes(s, [88, 95, 72, 137, 7])  // pop rax; pop rdi; mov qword ptr [rdi], rax
                s.synth_last_expr_type = "int"
            // ── Intrinsic 7: exit / বিদায় ─────────────────────────────────────
            elif var_name == "exit" or var_name == "বিদায়"
                // WHY: Linux SYS_exit_group (231) terminates the entire process & all OS threads cleanly
                // (never leaves orphaned worker threads hanging like single-thread SYS_exit 60).
                if arg_count >= 1
                    x86_synth_emit_byte(s, 95) // pop rdi (status code)
                else
                    x86_synth_emit_byte(s, 49) // xor edi, edi
                    x86_synth_emit_byte(s, 255)
                x86_synth_emit_byte(s, 184)
                x86_synth_emit_u32(s, 231)  // mov eax, 231 (SYS_exit_group)
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
                    s.synth_last_elem_type = ""
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
                    list_el_t = ""
                    ai = arg_count - 1
                    while ai >= 0
                        if ai < arg_expr_types.len() and arg_expr_types[ai] == "float"
                            list_el_t = "float"
                        end
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
                    s.synth_last_elem_type = list_el_t
                end
                s.synth_last_expr_type = ""
                s.synth_last_struct = ""
            // ── Intrinsic 8b: dict / map / অভিধান + native DICT0 operations ────
            elif (var_name == "dict" or var_name == "map" or var_name == "অভিধান" or (var_name == "map_new" and x86_synth_find_fn_first(s, "map_new") == 0)) and arg_count <= 1
                if arg_count == 0
                    x86_synth_emit_bytes(s, [49, 255]) // xor edi, edi
                else
                    x86_synth_emit_byte(s, 95)         // pop rdi (initial cap)
                end
                x86_synth_emit_call_helper(s, "_lipi_dict_new")
                s.synth_last_expr_type = ""
                s.synth_last_struct = ""
                s.synth_last_elem_type = "dyn_dict"
            elif (var_name == "map_set" and x86_synth_find_fn_first(s, "map_set") == 0) and arg_count == 3
                val_t_ms = 0
                if arg_expr_types.len() >= 3
                    if arg_expr_types[2] == "float" val_t_ms = 1
                    elif arg_expr_types[2] == "str" val_t_ms = 2 end
                end
                x86_synth_emit_byte(s, 90) // pop rdx (val)
                x86_synth_emit_byte(s, 94) // pop rsi (key)
                x86_synth_emit_byte(s, 95) // pop rdi (dict)
                if val_t_ms == 0
                    x86_synth_emit_bytes(s, [49, 201]) // xor ecx, ecx
                else
                    x86_synth_emit_bytes(s, [185, val_t_ms, 0, 0, 0]) // mov ecx, val_tag
                end
                x86_synth_emit_call_helper(s, "_lipi_dict_set_typed")
                s.synth_last_expr_type = ""
                s.synth_last_struct = ""
                s.synth_last_elem_type = "dyn_dict"
            elif (var_name == "map_get" and x86_synth_find_fn_first(s, "map_get") == 0) and arg_count == 2
                x86_synth_emit_byte(s, 94) // pop rsi (key)
                x86_synth_emit_byte(s, 95) // pop rdi (dict)
                x86_synth_emit_call_helper(s, "_lipi_dict_get")
                s.synth_last_expr_type = "dyn_tagged"
                s.synth_last_struct = ""
                s.synth_last_elem_type = ""
            elif (var_name == "has_key" or ((var_name == "dict_has" or var_name == "map_has") and x86_synth_find_fn_first(s, var_name) == 0)) and arg_count == 2
                x86_synth_emit_byte(s, 94) // pop rsi (key)
                x86_synth_emit_byte(s, 95) // pop rdi (dict)
                x86_synth_emit_call_helper(s, "_lipi_dict_has")
                s.synth_last_expr_type = ""
                s.synth_last_struct = ""
                s.synth_last_elem_type = ""
            elif (var_name == "del_key" or ((var_name == "dict_del" or var_name == "map_del") and x86_synth_find_fn_first(s, var_name) == 0)) and arg_count == 2
                x86_synth_emit_byte(s, 94) // pop rsi (key)
                x86_synth_emit_byte(s, 95) // pop rdi (dict)
                x86_synth_emit_call_helper(s, "_lipi_dict_del")
                s.synth_last_expr_type = ""
                s.synth_last_struct = ""
                s.synth_last_elem_type = ""
            elif var_name == "hashmap_delete" and x86_synth_find_fn_first(s, var_name) == 0 and arg_count == 2
                // WHY: Fallback DICT0 delete returning the map handle when utso/hashmap is not imported
                // (avoids symbol collision with utso/core/hashmap.lp's hashmap_delete while keeping signed packages intact).
                x86_synth_emit_bytes(s, [94, 95, 87, 72, 131, 236, 8]) // pop rsi; pop rdi; push rdi; sub rsp, 8
                x86_synth_emit_call_helper(s, "_lipi_dict_del")
                x86_synth_emit_bytes(s, [72, 131, 196, 8, 88])         // add rsp, 8; pop rax (return dict handle)
                s.synth_last_expr_type = ""
                s.synth_last_struct = ""
                s.synth_last_elem_type = ""
            elif (var_name == "keys" or ((var_name == "dict_keys" or var_name == "map_keys") and x86_synth_find_fn_first(s, var_name) == 0)) and arg_count == 1
                x86_synth_emit_byte(s, 95) // pop rdi (dict)
                x86_synth_emit_call_helper(s, "_lipi_dict_keys")
                s.synth_last_expr_type = ""
                s.synth_last_struct = ""
                s.synth_last_elem_type = ""
            elif (var_name == "values" or ((var_name == "dict_values" or var_name == "map_values") and x86_synth_find_fn_first(s, var_name) == 0)) and arg_count == 1
                x86_synth_emit_byte(s, 95) // pop rdi (dict)
                x86_synth_emit_call_helper(s, "_lipi_dict_values")
                s.synth_last_expr_type = ""
                s.synth_last_struct = ""
                s.synth_last_elem_type = ""
            elif (var_name == "str" or var_name == "to_str" or var_name == "স্ট্রিং") and arg_count == 1 and arg_expr_types.len() >= 1 and arg_expr_types[0] == "float"
                x86_synth_emit_byte(s, 95) // pop rdi
                x86_synth_emit_call_helper(s, "_lipi_float_to_str")
                s.synth_last_expr_type = "str"
                s.synth_last_struct = ""
                s.synth_last_elem_type = ""
            elif (var_name == "str" or var_name == "to_str" or var_name == "স্ট্রিং") and arg_count == 1 and arg_expr_types.len() >= 1 and arg_expr_types[0] == "dyn_tagged"
                // pop rdi; mov rsi, rdx (%rdx preserved across push rax); call _lipi_ensure_str_tagged
                x86_synth_emit_bytes(s, [95, 72, 137, 214])
                x86_synth_emit_call_helper(s, "_lipi_ensure_str_tagged")
                s.synth_last_expr_type = "str"
                s.synth_last_struct = ""
                s.synth_last_elem_type = ""
            else
                // ── ADT Variant Constructor, Struct Constructor, or Regular Function Call ──
                adt_call = x86_synth_find_adt_variant(s, enum_qual, var_name)
                if adt_call != 0 and adt_call[0].ed_is_adt == 1
                    x86_synth_emit_adt_alloc(s, adt_call[1], arg_count, arg_expr_types)
                    s.synth_last_struct = adt_call[0].ed_name
                    s.synth_last_expr_type = ""
                    s.synth_last_elem_type = ""
                else
                    sdef = x86_synth_find_struct(s, var_name)
                    if sdef != 0
                        if sdef.sd_type_params != 0 and sdef.sd_type_params.len() > 0
                            st_targs = call_targs
                            if st_targs == 0 or st_targs.len() == 0
                                st_targs = list()
                                tpi = 0
                                while tpi < sdef.sd_type_params.len()
                                    tp_nm = sdef.sd_type_params[tpi]
                                    inf_t = "int"
                                    sfi = 0
                                    while sfi < sdef.sd_field_types.len() and sfi < arg_count
                                        if sdef.sd_field_types[sfi] == tp_nm
                                            if sfi < arg_struct_types.len() and arg_struct_types[sfi] != ""
                                                inf_t = arg_struct_types[sfi]
                                            elif sfi < arg_expr_types.len() and arg_expr_types[sfi] != ""
                                                inf_t = arg_expr_types[sfi]
                                            end
                                            break
                                        end
                                        sfi = sfi + 1
                                    end
                                    push(st_targs, inf_t)
                                    tpi = tpi + 1
                                end
                            end
                            sdef = x86_synth_specialize_struct(s, sdef, st_targs)
                        end
                        s.synth_last_struct = sdef.sd_name
                        fcount = sdef.sd_fields.len()
                        alloc_sz = sdef.sd_total_size
                        if alloc_sz <= 0
                            alloc_sz = (fcount + 1) * 8
                        end
                        if alloc_sz < 32
                            alloc_sz = 32
                        end
                        x86_synth_emit_mov_rdi_imm64(s, alloc_sz)
                        x86_synth_emit_call_alloc(s)
                        if arg_count > 0
                            // Preserve struct pointer in %r10 across argument pops: mov r10, rax
                            x86_synth_emit_byte(s, 73)  // REX.W + REX.B (0x49)
                            x86_synth_emit_byte(s, 137) // mov r/m64, r64 (0x89)
                            x86_synth_emit_byte(s, 194) // ModR/M: r10 <- rax (0xC2)
                            ai = arg_count - 1
                            while ai >= 0
                                if ai < arg_expr_types.len() and ai < sdef.sd_field_types.len() and sdef.sd_field_types[ai] == "" and arg_expr_types[ai] != ""
                                    list_set(sdef.sd_field_types, ai, arg_expr_types[ai])
                                end
                                x86_synth_emit_byte(s, 88) // pop rax (arg val)
                                x86_synth_emit_bytes(s, [76, 137, 209]) // mov rcx, r10
                                field_off = ai * 8
                                field_sz = 8
                                if sdef.sd_field_offsets != 0 and ai < sdef.sd_field_offsets.len()
                                    field_off = sdef.sd_field_offsets[ai]
                                    field_sz = sdef.sd_field_sizes[ai]
                                end
                                x86_synth_emit_field_store_rcx_rax(s, field_off, field_sz)
                                ai = ai - 1
                            // Restore struct pointer to %rax: mov rax, r10
                            x86_synth_emit_byte(s, 76)  // REX.W + REX.R (0x4C)
                            x86_synth_emit_byte(s, 137) // mov r/m64, r64 (0x89)
                            x86_synth_emit_byte(s, 208) // ModR/M: rax <- r10 (0xD0)
                        s.synth_last_expr_type = ""
                        s.synth_last_elem_type = ""
                    else
                        // Regular Function Call: Pop arguments in reverse into calling convention registers
                        lv_fn = x86_synth_find_local_var(s, var_name)
                        mg_fn = 0
                        if lv_fn == 0
                            mg_fn = x86_synth_find_mutable_global(s, var_name)
                        end
                        if lv_fn != 0 and ((lv_fn.lv_is_spilled == 0 and lv_fn.lv_reg >= 0) or lv_fn.lv_offset > 0)
                            if lv_fn.lv_is_spilled == 0 and lv_fn.lv_reg >= 0
                                x86_synth_emit_mov_reg_reg(s, 0, lv_fn.lv_reg)
                            else
                                x86_synth_emit_load_var(s, 0, lv_fn.lv_offset)
                            end
                            if lv_fn.lv_is_boxed == 1
                                x86_synth_emit_bytes(s, [72, 139, 0]) // mov rax, [rax]
                            end
                            fn_cleanup = x86_synth_emit_pop_args(s, arg_count)
                            x86_synth_emit_indirect_call_rax(s)
                            x86_synth_emit_cleanup_stack_args(s, fn_cleanup)
                        elif mg_fn >= 512
                            fn_cleanup = x86_synth_emit_pop_args(s, arg_count)
                            x86_synth_emit_mutable_global_read(s, mg_fn)
                            x86_synth_emit_indirect_call_rax(s)
                            x86_synth_emit_cleanup_stack_args(s, fn_cleanup)
                        else
                            if s.synth_strict_types == 1
                                arity_fn = x86_synth_find_fn_first(s, var_name)
                                if arity_fn != 0 and arity_fn.fn_param_count >= 0 and arg_count != arity_fn.fn_param_count
                                    say "❌ [Strict Arity Error]: Function '" + var_name + "' expects " + str(arity_fn.fn_param_count) + " argument(s), got " + str(arg_count) + " at line " + str(t.tok_span.span_start_line)
                                    exit(1)
                                end
                            end
                            // WHY: Sovereign Compile-Time Monomorphization (0% boxing, 0% runtime overhead!).
                            // Supports BOTH explicit/inferred Generic Functions (`fn pair_sum<T>(a: T, b: T) -> T`)
                            // AND untyped Float Monomorphization (`fn add(x, y)` called with float args).
                            call_target_name = var_name
                            orig_fn = x86_synth_find_fn_first(s, var_name)
                            did_generic_mono = 0
                            if orig_fn != 0 and orig_fn.fn_tok_pos >= 0 and orig_fn.fn_type_params != 0 and orig_fn.fn_type_params.len() > 0 and orig_fn.fn_param_count == arg_count
                                g_targs = call_targs
                                if g_targs == 0 or g_targs.len() == 0
                                    g_targs = list()
                                    gti = 0
                                    while gti < orig_fn.fn_type_params.len()
                                        gtp = orig_fn.fn_type_params[gti]
                                        ginf = "int"
                                        gpi = 0
                                        while gpi < orig_fn.fn_param_types.len() and gpi < arg_count
                                            if orig_fn.fn_param_types[gpi] == gtp
                                                if gpi < arg_struct_types.len() and arg_struct_types[gpi] != ""
                                                    ginf = arg_struct_types[gpi]
                                                elif gpi < arg_expr_types.len() and arg_expr_types[gpi] != ""
                                                    ginf = arg_expr_types[gpi]
                                                end
                                                break
                                            end
                                            gpi = gpi + 1
                                        end
                                        push(g_targs, ginf)
                                        gti = gti + 1
                                    end
                                end
                                // Enforce compile-time generic trait bounds (`<T: Printable>`, `<T: A + B>`)
                                x86_synth_verify_generic_bounds(s, var_name, orig_fn.fn_type_params, orig_fn.fn_type_bounds, g_targs)
                                g_suffix = "__g"
                                gsi = 0
                                while gsi < g_targs.len()
                                    g_suffix = g_suffix + "_" + x86_synth_norm_type_name(g_targs[gsi])
                                    gsi = gsi + 1
                                end
                                call_target_name = var_name + g_suffix
                                did_generic_mono = 1
                                if x86_synth_find_fn_first(s, call_target_name) == 0
                                    g_ptypes = list()
                                    gpk = 0
                                    while gpk < arg_count
                                        raw_gp = ""
                                        if orig_fn.fn_param_types != 0 and gpk < orig_fn.fn_param_types.len()
                                            raw_gp = orig_fn.fn_param_types[gpk]
                                        end
                                        push(g_ptypes, x86_synth_subst_type(s, raw_gp, orig_fn.fn_type_params, g_targs))
                                        gpk = gpk + 1
                                    end
                                    g_ret = x86_synth_subst_type(s, orig_fn.fn_ret_type, orig_fn.fn_type_params, g_targs)
                                    gm_stub = X86Function()
                                    gm_stub.fn_name = call_target_name
                                    gm_stub.fn_entry_offset = 0 - 1
                                    gm_stub.fn_ret_type = g_ret
                                    gm_stub.fn_end_offset = 0
                                    gm_stub.fn_decl_line = orig_fn.fn_decl_line
                                    gm_stub.fn_param_count = arg_count
                                    gm_stub.fn_tok_pos = 0 - 1
                                    gm_stub.fn_param_types = g_ptypes
                                    gm_stub.fn_type_params = list()
                                    x86_synth_register_fn_obj(s, gm_stub)
                                    s.synth_last_store_end = 0 - 1
                                    s.synth_mono_name_override = call_target_name
                                    s.synth_mono_param_override = g_ptypes
                                    s.synth_mono_ret_override = g_ret
                                    gm_pos_box = [orig_fn.fn_tok_pos]
                                    x86_synth_compile_fn_def(s, toks, gm_pos_box)
                                    s.synth_last_store_end = 0 - 1
                                end
                            end
                            if did_generic_mono == 0
                                has_flt_mono = 0
                                m_i = 0
                                while m_i < arg_expr_types.len()
                                    if arg_expr_types[m_i] == "float"
                                        has_flt_mono = 1
                                        break
                                    end
                                    m_i = m_i + 1
                                end
                                if has_flt_mono == 1 and orig_fn != 0 and orig_fn.fn_tok_pos >= 0 and orig_fn.fn_param_count == arg_count and orig_fn.fn_param_types != 0 and orig_fn.fn_param_types.len() == arg_count
                                    needs_mono = 0
                                    spec_ptypes = list()
                                    spec_suffix = "__mono"
                                    m_k = 0
                                    while m_k < arg_count
                                        decl_pt = orig_fn.fn_param_types[m_k]
                                        if decl_pt == "" and m_k < arg_expr_types.len() and arg_expr_types[m_k] == "float"
                                            needs_mono = 1
                                            push(spec_ptypes, "float")
                                            spec_suffix = spec_suffix + "_f"
                                        else
                                            push(spec_ptypes, decl_pt)
                                            spec_suffix = spec_suffix + "_a"
                                        end
                                        m_k = m_k + 1
                                    end
                                    if needs_mono == 1
                                        call_target_name = var_name + spec_suffix
                                        if x86_synth_find_fn_first(s, call_target_name) == 0
                                            m_stub = X86Function()
                                            m_stub.fn_name = call_target_name
                                            m_stub.fn_entry_offset = 0 - 1
                                            m_stub.fn_ret_type = orig_fn.fn_ret_type
                                            m_stub.fn_end_offset = 0
                                            m_stub.fn_decl_line = orig_fn.fn_decl_line
                                            m_stub.fn_param_count = arg_count
                                            m_stub.fn_tok_pos = 0 - 1
                                            m_stub.fn_param_types = spec_ptypes
                                            m_stub.fn_type_params = list()
                                            x86_synth_register_fn_obj(s, m_stub)
                                            s.synth_last_store_end = 0 - 1
                                            s.synth_mono_name_override = call_target_name
                                            s.synth_mono_param_override = spec_ptypes
                                            m_pos_box = [orig_fn.fn_tok_pos]
                                            x86_synth_compile_fn_def(s, toks, m_pos_box)
                                            s.synth_last_store_end = 0 - 1
                                        end
                                    end
                                end
                            end
                            // Direct Function Call: route str(u64_expr) to _lipi_uint_to_str for full unsigned range
                            if arg_count == 1 and (var_name == "str" or var_name == "to_str" or var_name == "স্ট্রিং") and arg_expr_types.len() > 0 and arg_expr_types[0] == "uint"
                                call_target_name = "_lipi_uint_to_str"
                            end
                            fn_cleanup = x86_synth_emit_pop_args(s, arg_count)
                            // Direct Function Call: Emits call rel32 (0xE8) and queues relocation
                            call_off = s.synth_code.len()
                            x86_synth_emit_byte(s, 232)
                            patch_pos = s.synth_code.len()
                            x86_synth_emit_u32(s, 0)
                            call_rel = X86CallReloc()
                            call_rel.cr_patch_offset = patch_pos
                            call_rel.cr_call_site_end = patch_pos + 4
                            call_rel.cr_target_name = call_target_name
                            push(s.synth_call_relocs, call_rel)
                            x86_synth_emit_cleanup_stack_args(s, fn_cleanup)
                            if var_name == "main" or var_name == "মূল"
                                s.synth_called_top_level_main = 1
                            rt_name = x86_synth_lookup_fn_ret_type(s, call_target_name)
                            if var_name == "len" or var_name == "length" or var_name == "দৈর্ঘ্য" or var_name == "str_len"
                                s.synth_last_expr_type = "int"
                            elif var_name == "str" or var_name == "to_str" or var_name == "স্ট্রিং" or var_name == "float_to_str" or var_name == "uint_to_str" or var_name == "stack_trace" or var_name == "backtrace" or var_name == "স্ট্যাক_ট্রেস" or var_name == "sha256_hex" or var_name == "str_sub" or var_name == "char_at" or var_name == "chr" or var_name == "file_read" or var_name == "bytes_to_hex" or var_name == "qword_to_hex" or var_name == "buf_to_str" or var_name == "bytes_to_str" or var_name == "mem_to_str" or var_name == "বাফার_স্ট্রিংয়ে" or var_name == "বাইট_থেকে_স্ট্রিং"
                                s.synth_last_expr_type = "str"
                            elif var_name == "floor" or var_name == "মেঝে" or var_name == "gc_collect" or var_name == "lipi_gc_collect" or var_name == "gc_live_bytes" or var_name == "gc_set_threshold" or var_name == "gc_set_auto" or var_name == "buf_len" or var_name == "buf_ptr" or var_name == "buf_write_byte" or var_name == "buf_append_byte" or var_name == "buf_push" or var_name == "buf_write_mem" or var_name == "buf_write_str" or var_name == "buf_get_byte" or var_name == "buf_clear" or var_name == "buf_free" or var_name == "ord" or var_name == "mem_byte_read" or var_name == "mem_read_byte" or var_name == "mem_read" or var_name == "mem_word_read" or var_name == "str_char_at" or var_name == "ror32" or var_name == "rol32" or var_name == "clock_ms" or var_name == "cpu_clock" or var_name == "arena_mark" or var_name == "arena_allocated" or var_name == "file_exists" or var_name == "sha256_ch" or var_name == "sha256_maj" or var_name == "sha256_sigma0" or var_name == "sha256_sigma1" or var_name == "sha256_gamma0" or var_name == "sha256_gamma1"
                                s.synth_last_expr_type = "int"
                            else
                                s.synth_last_expr_type = ""
                            if var_name == "restore_extract_single_file"
                                s.synth_last_struct = "ExtractedSingleFile"
                            elif x86_synth_is_ptr_type(rt_name) == 1
                                s.synth_last_expr_type = "uint"
                                s.synth_last_struct = rt_name
                            elif x86_synth_is_uint_type(rt_name) == 1
                                s.synth_last_expr_type = "uint"
                                s.synth_last_struct = ""
                            elif rt_name == "int" or rt_name == "i64" or rt_name == "i32" or rt_name == "i16" or rt_name == "i8"
                                s.synth_last_expr_type = "int"
                                s.synth_last_struct = ""
                            elif rt_name == "float" or rt_name == "f64" or rt_name == "f32"
                                s.synth_last_expr_type = "float"
                                s.synth_last_struct = ""
                            elif rt_name == "str" or rt_name == "string"
                                s.synth_last_expr_type = "str"
                                s.synth_last_struct = ""
                            elif rt_name == "dyn_tagged"
                                s.synth_last_expr_type = "dyn_tagged"
                                s.synth_last_struct = ""
                            else
                                s.synth_last_struct = rt_name
                            end
                        end
                    end
                end
        else
            // Qualified Enum::Variant OR bare unit ADT variant (e.g. Option::None, None, Point)
            adt_bare = x86_synth_find_adt_variant(s, enum_qual, var_name)
            lv = x86_synth_find_local_var(s, var_name)
            if adt_bare != 0 and (enum_qual != "" or (lv == 0 and x86_synth_find_mutable_global(s, var_name) < 512))
                if adt_bare[0].ed_is_adt == 1
                    x86_synth_emit_adt_alloc(s, adt_bare[1], 0, 0)
                    s.synth_last_struct = adt_bare[0].ed_name
                    s.synth_last_expr_type = ""
                    s.synth_last_elem_type = ""
                else
                    x86_synth_emit_mov_rax_imm64(s, adt_bare[1])
                    s.synth_last_expr_type = "int"
                    s.synth_last_struct = ""
                    s.synth_last_elem_type = ""
                end
            elif lv != 0
                if lv.lv_is_spilled == 0 and lv.lv_reg >= 0
                    x86_synth_emit_mov_reg_reg(s, 0, lv.lv_reg)
                else
                    x86_synth_emit_load_var(s, 0, lv.lv_offset)
                end
                if lv.lv_is_boxed == 1
                    x86_synth_emit_bytes(s, [72, 139, 0]) // mov rax, [rax]
                end
                s.synth_last_struct = x86_synth_get_var_type(s, var_name)
                s.synth_last_expr_type = x86_synth_get_prim_type(s, var_name)
                s.synth_last_elem_type = x86_synth_get_elem_type(s, var_name)
                if s.synth_last_expr_type == "dyn_tagged" and lv.lv_tag_off > 0
                    x86_synth_emit_load_var(s, 2, lv.lv_tag_off) // mov rdx, [rbp - lv_tag_off]
                end
            else
                // Check static @bss aligned hardware buffer BEFORE mutable globals/constants
                bss_idx = x86_synth_find_bss(s, var_name)
                mg_off = x86_synth_find_mutable_global(s, var_name)
                if bss_idx >= 0
                    x86_synth_emit_bss_addr(s, bss_idx)
                    s.synth_last_struct = s.synth_bss_structs[bss_idx]
                    s.synth_last_expr_type = "int"
                    b_el = s.synth_bss_elem_sizes[bss_idx]
                    if b_el > 0
                        s.synth_last_elem_type = x86_synth_raw_elem_tag(b_el, s.synth_bss_signed[bss_idx])
                    else
                        s.synth_last_elem_type = ""
                    end
                elif mg_off >= 512
                    x86_synth_emit_mutable_global_read(s, mg_off)
                    s.synth_last_struct = x86_synth_get_mutable_global_struct(s, var_name)
                    s.synth_last_expr_type = x86_synth_get_mutable_global_prim(s, var_name)
                    s.synth_last_elem_type = ""
                else
                    g_val = x86_synth_lookup_global_const(s, var_name)
                    if g_val != (0 - 999999999)
                        x86_synth_emit_mov_rax_imm64(s, g_val)
                        s.synth_last_expr_type = "int"
                        s.synth_last_struct = ""
                        s.synth_last_elem_type = ""
                    else
                        // Check if var_name is a registered function (0-arg call OR bare fn_ptr value)
                        fn_cand = x86_synth_find_fn_first(s, var_name)
                        if fn_cand != 0
                            has_inline_arg = 0
                            if next_pos < toks.len() and toks[next_pos].tok_span.span_start_line == t.tok_span.span_start_line
                                nk = toks[next_pos].tok_kind
                                ntxt = toks[next_pos].tok_text
                                if nk == TOK_INT() or nk == TOK_FLOAT() or nk == TOK_STR() or nk == TOK_INTERP_STR() or (nk == TOK_IDENT() and x86_synth_find_local_var(s, ntxt) != 0)
                                    has_inline_arg = 1
                                end
                            end
                            if fn_cand.fn_param_count > 0 and has_inline_arg == 0
                                x86_synth_emit_fn_ptr_lea(s, var_name)
                            else
                                if has_inline_arg == 1
                                    x86_synth_compile_expr(s, toks, pos_box)
                                    // mov rdi, rax (pass argument 0 in %rdi)
                                    x86_synth_emit_byte(s, 72)
                                    x86_synth_emit_byte(s, 137)
                                    x86_synth_emit_byte(s, 199)
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
                                rt0 = x86_synth_lookup_fn_ret_type(s, var_name)
                                s.synth_last_struct = ""
                                s.synth_last_elem_type = ""
                                if var_name == "len" or var_name == "length" or var_name == "দৈর্ঘ্য" or var_name == "str_len"
                                    s.synth_last_expr_type = "int"
                                elif var_name == "str" or var_name == "to_str" or var_name == "স্ট্রিং"
                                    s.synth_last_expr_type = "str"
                                elif rt0 == "float" or rt0 == "f64" or rt0 == "f32"
                                    s.synth_last_expr_type = "float"
                                elif x86_synth_is_uint_type(rt0) == 1
                                    s.synth_last_expr_type = "uint"
                                elif rt0 == "int" or rt0 == "i64" or rt0 == "i32" or rt0 == "i16" or rt0 == "i8"
                                    s.synth_last_expr_type = "int"
                                elif rt0 == "str" or rt0 == "string"
                                    s.synth_last_expr_type = "str"
                                elif rt0 == "dyn_tagged"
                                    s.synth_last_expr_type = "dyn_tagged"
                                else
                                    s.synth_last_expr_type = ""
                                    s.synth_last_struct = rt0
                                end
                            end
                        else
                            // Unbound identifier defaults to 0
                            x86_synth_emit_byte(s, 49)
                            x86_synth_emit_byte(s, 192)
                            s.synth_last_expr_type = ""
                            s.synth_last_struct = ""
                            s.synth_last_elem_type = ""
                        end
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

