// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/x86_64/codegen_expr.lp
// ==============================================================================

// ── 6. Recursive-Descent Expression Synthesizer ────────────────────────────────

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
        // neg rax (0x48 0xF7 0xD8)
        x86_synth_emit_byte(s, 72)
        x86_synth_emit_byte(s, 247)
        x86_synth_emit_byte(s, 216)
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

    // 1. Integer Literal
    elif k == TOK_INT()
        list_set(pos_box, 0, pos + 1)
        x86_synth_emit_mov_rax_imm64(s, t.tok_int_val)
        s.synth_last_expr_type = "int"

    // 1b. Float Literal (lowered integer value representation)
    elif k == TOK_FLOAT()
        list_set(pos_box, 0, pos + 1)
        x86_synth_emit_mov_rax_imm64(s, t.tok_int_val)
        s.synth_last_expr_type = "int"

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
        if sname == "" and keys.len() > 0
            anon_sdef = X86StructDef()
            anon_sdef.sd_name = "_anon_s_" + int_to_str(s.synth_structs.len())
            anon_sdef.sd_fields = keys
            push(s.synth_structs, anon_sdef)
            sname = anon_sdef.sd_name
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
            // Intrinsic 2: malloc
            elif var_name == "malloc" or var_name == "mem_alloc" or var_name == "মেমরি_বরাদ্দ"
                if arg_count >= 1
                    x86_synth_emit_byte(s, 95) // pop rdi
                else
                    x86_synth_emit_mov_rdi_imm64(s, 32)
                x86_synth_emit_call_helper(s, "_lipi_malloc")
                s.synth_last_expr_type = ""
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
                    // Pop arguments in reverse into LiPi 12-register calling convention
                    x86_synth_emit_pop_args(s, arg_count)

                    var_off = x86_synth_lookup_var(s, var_name)
                    if var_off > 0
                        // WHY: Indirect Function Call / Callback:
                        // The callee is a function pointer stored in a local variable (e.g. f(x), pred(x)).
                        // Load function pointer from [rbp - var_off] into %rax and call dynamically.
                        x86_synth_emit_load_var(s, 0, var_off)
                        x86_synth_emit_byte(s, 255) // call rax (0xFF 0xD0)
                        x86_synth_emit_byte(s, 208)
                        s.synth_last_expr_type = ""
                    else
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
                        if var_name == "len" or var_name == "length" or var_name == "দৈর্ঘ্য" or var_name == "str_len"
                            s.synth_last_expr_type = "int"
                        elif var_name == "str" or var_name == "to_str" or var_name == "স্ট্রিং"
                            s.synth_last_expr_type = "str"
                        else
                            s.synth_last_expr_type = ""
        else
            // Plain variable load
            off = x86_synth_lookup_var(s, var_name)
            if off > 0
                x86_synth_emit_load_var(s, 0, off)
                s.synth_last_struct = x86_synth_get_var_type(s, var_name)
                s.synth_last_expr_type = x86_synth_get_prim_type(s, var_name)
            else
                // Check if var_name is a registered compile-time global constant
                g_val = x86_synth_lookup_global_const(s, var_name)
                if g_val != (0 - 999999999)
                    x86_synth_emit_mov_rax_imm64(s, g_val)
                    s.synth_last_expr_type = "int"
                else
                    // Check if var_name is a registered zero-arg constant function
                    is_fn_const = 0
                    fi = 0
                    while fi < s.synth_functions.len()
                        if s.synth_functions[fi].fn_name == var_name
                            is_fn_const = 1
                            break
                        fi = fi + 1
                    if is_fn_const == 1
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
                        if var_name == "len" or var_name == "length" or var_name == "দৈর্ঘ্য" or var_name == "str_len"
                            s.synth_last_expr_type = "int"
                        elif var_name == "str" or var_name == "to_str" or var_name == "স্ট্রিং"
                            s.synth_last_expr_type = "str"
                        else
                            s.synth_last_expr_type = ""
                    else
                        // Unbound identifier defaults to 0
                        x86_synth_emit_byte(s, 49)
                        x86_synth_emit_byte(s, 192)
                        s.synth_last_expr_type = ""
    else
        // Fallback: advance and clear %rax
        list_set(pos_box, 0, pos + 1)
        x86_synth_emit_byte(s, 49)
        x86_synth_emit_byte(s, 192)
        s.synth_last_expr_type = ""

    // ── Postfix Chaining Loop: [index], .field, .method(...) ────────────────
    x86_synth_expr_postfix(s, toks, pos_box)
    return 0

