// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN AMD64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/x86_64/synthesizer.lp
// ==============================================================================

include "src/compiler/backend/targets/x86_64/codegen_core.lp"
include "src/compiler/backend/targets/x86_64/codegen_expr.lp"
include "src/compiler/backend/targets/x86_64/codegen_operators.lp"
include "src/compiler/backend/targets/x86_64/codegen_stmt.lp"

// ── Function Definition Synthesizer ───────────────────────────────────────────

fn x86_synth_compile_fn_def s toks pos_box
    // WHY: Dedicated function definition synthesizer for System V AMD64 ABI.
    // Handles parameter parsing, ABI register conventions (%rdi, %rsi, etc.),
    // local stack frame allocation, and statement body synthesis.
    pos = get(pos_box, 0)
    t = toks[pos]
    base_col = t.tok_span.span_start_col
    base_line = t.tok_span.span_start_line
    list_set(pos_box, 0, pos + 1) // Consume fn
    name_pos = get(pos_box, 0)
    fn_name = ""
    method_alias = ""
    if name_pos < toks.len() and toks[name_pos].tok_kind == TOK_IDENT()
        fn_name = toks[name_pos].tok_text
        list_set(pos_box, 0, name_pos + 1)
        next_p = get(pos_box, 0)
        if next_p + 1 < toks.len() and (toks[next_p].tok_kind == TOK_DOT() or (toks[next_p].tok_kind != TOK_STR() and toks[next_p].tok_text == "."))
            if toks[next_p + 1].tok_kind == TOK_IDENT()
                method_alias = toks[next_p + 1].tok_text
                list_set(pos_box, 0, next_p + 2)
                fn_name = fn_name + "_" + method_alias

    // Emit jump over function so top-level execution doesn't fall through into it!
    x86_synth_emit_byte(s, 233) // jmp rel32 (0xE9)
    fn_jmp_patch = s.synth_code.len()
    x86_synth_emit_u32(s, 0)

    // Record function entry point (immediately after the skip jump)
    fn_entry = X86Function()
    fn_entry.fn_name = fn_name
    fn_entry.fn_entry_offset = s.synth_code.len()
    push(s.synth_functions, fn_entry)
    if method_alias != ""
        fn_alias = X86Function()
        fn_alias.fn_name = method_alias
        fn_alias.fn_entry_offset = s.synth_code.len()
        push(s.synth_functions, fn_alias)

    // Reset frame locals (saving enclosing scope to restore when function definition completes)
    saved_locals = s.synth_locals
    saved_stack_offset = s.synth_stack_offset
    s.synth_locals = list()
    s.synth_stack_offset = 8

    // Parse parameter names (supporting parentheses, commas, and type annotations)
    params = list()
    has_paren = 0
    if get(pos_box, 0) < toks.len()
        first_p_tok = toks[get(pos_box, 0)]
        if first_p_tok.tok_kind == TOK_LPAREN() or (first_p_tok.tok_kind != TOK_STR() and first_p_tok.tok_text == "(")
            has_paren = 1
            list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume '('

    while get(pos_box, 0) < toks.len()
        if has_paren == 1
            x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p_idx = get(pos_box, 0)
        if cur_p_idx >= toks.len()
            break
        p_tok = toks[cur_p_idx]
        pk = p_tok.tok_kind
        ptxt = p_tok.tok_text

        if has_paren == 1
            if pk == TOK_RPAREN() or (pk != TOK_STR() and ptxt == ")")
                list_set(pos_box, 0, cur_p_idx + 1) // Consume ')'
                break
        else
            if pk == TOK_ASSIGN() or (pk != TOK_STR() and ptxt == "=")
                break
            if pk == TOK_NEWLINE() or pk == TOK_SEMI() or (pk != TOK_STR() and (ptxt == "\n" or ptxt == ";"))
                list_set(pos_box, 0, cur_p_idx + 1)
                break

        if x86_synth_is_ident_token(pk) == 1
            push(params, ptxt)
            list_set(pos_box, 0, cur_p_idx + 1) // Consume param name
            if has_paren == 1
                x86_synth_skip_whitespace_tokens(toks, pos_box)
            // Skip optional type annotation: : type
            after_p = get(pos_box, 0)
            if after_p < toks.len() and (toks[after_p].tok_kind == TOK_COLON() or (toks[after_p].tok_kind != TOK_STR() and toks[after_p].tok_text == ":"))
                list_set(pos_box, 0, after_p + 1) // Consume ':'
                if has_paren == 1
                    x86_synth_skip_whitespace_tokens(toks, pos_box)
                if get(pos_box, 0) < toks.len() and (x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1 or toks[get(pos_box, 0)].tok_text == "string" or toks[get(pos_box, 0)].tok_text == "i64" or toks[get(pos_box, 0)].tok_text == "f64" or toks[get(pos_box, 0)].tok_text == "bool" or toks[get(pos_box, 0)].tok_text == "array")
                    list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume type name
            if has_paren == 1
                x86_synth_skip_whitespace_tokens(toks, pos_box)
            // Skip optional comma: ,
            comma_p = get(pos_box, 0)
            if comma_p < toks.len() and (toks[comma_p].tok_kind == TOK_COMMA() or (toks[comma_p].tok_kind != TOK_STR() and toks[comma_p].tok_text == ","))
                list_set(pos_box, 0, comma_p + 1) // Consume ','
        else
            list_set(pos_box, 0, cur_p_idx + 1)

    // Skip optional return type: -> return_type or : return_type
    x86_synth_skip_whitespace_tokens(toks, pos_box)
    ret_p = get(pos_box, 0)
    if ret_p < toks.len() and (toks[ret_p].tok_kind == TOK_ARROW() or (toks[ret_p].tok_kind != TOK_STR() and toks[ret_p].tok_text == "->") or toks[ret_p].tok_kind == TOK_COLON() or (toks[ret_p].tok_kind != TOK_STR() and toks[ret_p].tok_text == ":"))
        list_set(pos_box, 0, ret_p + 1) // Consume '->' or ':'
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        if get(pos_box, 0) < toks.len() and (x86_synth_is_ident_token(toks[get(pos_box, 0)].tok_kind) == 1 or toks[get(pos_box, 0)].tok_kind == TOK_IDENT())
            list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume return type name

    // Emit function prologue
    x86_synth_emit_prologue(s)

    // Save incoming argument registers to local stack slots (supports up to 12 registers)
    pi = 0
    while pi < params.len()
        pname = params[pi]
        off = x86_synth_alloc_var(s, pname)
        x86_synth_emit_store_param(s, pi, off)
        pi = pi + 1


    // Check for one-liner expression function: fn name args = expr
    x86_synth_skip_whitespace_tokens(toks, pos_box)
    if get(pos_box, 0) < toks.len()
        eq_tok = toks[get(pos_box, 0)]
        if eq_tok.tok_kind == TOK_ASSIGN() or (eq_tok.tok_kind != TOK_STR() and eq_tok.tok_text == "=")
            list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume '='
            x86_synth_skip_whitespace_tokens(toks, pos_box)
            x86_synth_compile_expr(s, toks, pos_box)
            x86_synth_emit_epilogue(s)
            after_fn_offset = s.synth_code.len()
            rel32 = after_fn_offset - (fn_jmp_patch + 4)
            x86_synth_patch_u32(s, fn_jmp_patch, rel32)
            s.synth_locals = saved_locals
            s.synth_stack_offset = saved_stack_offset
            return 0

    // Parse function body statements until next function, EOF, or dedent
    while get(pos_box, 0) < toks.len()
        x86_synth_skip_whitespace_tokens(toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos >= toks.len()
            break
        ct = toks[cur_pos]
        is_fn_block_end = 0
        if (ct.tok_kind == TOK_KW_END() or ct.tok_kind == TOK_DIR_END() or (ct.tok_kind == TOK_IDENT() and (ct.tok_text == "end" or ct.tok_text == "শেষ" or ct.tok_text == "@end"))) and ct.tok_span.span_start_col <= base_col
            // WHY: Only treat as block terminator if NOT followed by an assignment '='
            if cur_pos + 1 >= toks.len() or (toks[cur_pos + 1].tok_kind != TOK_ASSIGN() and toks[cur_pos + 1].tok_text != "=")
                is_fn_block_end = 1
        if is_fn_block_end == 1
            list_set(pos_box, 0, cur_pos + 1)
            break
        if ct.tok_kind == TOK_KW_FN() or ct.tok_kind == TOK_DIR_FN()
            break
        if ct.tok_kind == TOK_IDENT() and (ct.tok_text == "fn" or ct.tok_text == "কাজ" or ct.tok_text == "@fn")
            break
        if ct.tok_kind == TOK_KW_STRUCT() or ct.tok_kind == TOK_DIR_STRUCT()
            break
        if ct.tok_kind == TOK_IDENT() and (ct.tok_text == "struct" or ct.tok_text == "গঠন" or ct.tok_text == "@struct")
            break
        cur_col = ct.tok_span.span_start_col
        if cur_col <= base_col and ct.tok_span.span_start_line > base_line
            break
        before_fn_stmt_p = get(pos_box, 0)
        x86_synth_compile_statement(s, toks, pos_box)
        if get(pos_box, 0) <= before_fn_stmt_p
            list_set(pos_box, 0, before_fn_stmt_p + 1)

    // Default epilogue at end of function
    x86_synth_emit_byte(s, 49)
    x86_synth_emit_byte(s, 192)
    x86_synth_emit_epilogue(s)

    // Patch jump to bypass function body during top-level execution
    after_fn_offset = s.synth_code.len()
    rel32 = after_fn_offset - (fn_jmp_patch + 4)
    x86_synth_patch_u32(s, fn_jmp_patch, rel32)
    s.synth_locals = saved_locals
    s.synth_stack_offset = saved_stack_offset
    return 0

// ── 8. Master Program Synthesizer Entry Point ──────────────────────────────────

fn x86_synth_compile_program tokens
    // WHY: Master orchestration entry point. Transforms complete token stream into
    // relocatable AMD64 machine code, sets up top-level stack frames, patches string relocations
    // against the Linux ELF virtual address space (0x400000+), and resolves call sites.
    s = x86_synth_new()

    // 1. Emit top-level stack frame prologue at entry point (offset 0)
    x86_synth_emit_prologue(s)

    // 2. Synthesize all functions, structs, and statements
    pos_box = [0]
    has_top_level = 0
    while get(pos_box, 0) < tokens.len()
        cur_pos = get(pos_box, 0)
        cur_k = tokens[cur_pos].tok_kind
        if cur_k == TOK_EOF()
            break

        tok_item = tokens[cur_pos]
        is_fn_tok = 0
        if tok_item.tok_kind == TOK_KW_FN() or tok_item.tok_kind == TOK_DIR_FN()
            is_fn_tok = 1
        if tok_item.tok_kind == TOK_IDENT() and (tok_item.tok_text == "fn" or tok_item.tok_text == "কাজ" or tok_item.tok_text == "@fn")
            is_fn_tok = 1
        if tok_item.tok_kind == TOK_KW_STRUCT() or tok_item.tok_kind == TOK_DIR_STRUCT()
            is_fn_tok = 1
        if tok_item.tok_kind == TOK_IDENT() and (tok_item.tok_text == "struct" or tok_item.tok_text == "গঠন" or tok_item.tok_text == "@struct")
            is_fn_tok = 1

        if is_fn_tok == 0 and tok_item.tok_kind != TOK_NEWLINE() and tok_item.tok_kind != TOK_SEMI()
            has_top_level = 1

        before_top_stmt_p = get(pos_box, 0)
        x86_synth_compile_statement(s, tokens, pos_box)
        if get(pos_box, 0) <= before_top_stmt_p
            list_set(pos_box, 0, before_top_stmt_p + 1)

    // 3. If 'main' or 'মূল' exists, call main() automatically!
    // WHY: Search backwards so translation unit's main() takes precedence over imported modules
    has_main = 0
    main_name = ""
    fi = s.synth_functions.len() - 1
    while fi >= 0
        fn_candidate = s.synth_functions[fi].fn_name
        if fn_candidate == "main" or fn_candidate == "মূল"
            has_main = 1
            main_name = fn_candidate
            break
        fi = fi - 1
    if has_main == 1 and s.synth_called_top_level_main == 0
        call_off = s.synth_code.len()
        x86_synth_emit_byte(s, 232)
        patch_pos = s.synth_code.len()
        x86_synth_emit_u32(s, 0)
        call_rel = X86CallReloc()
        call_rel.cr_patch_offset = patch_pos
        call_rel.cr_call_site_end = patch_pos + 4
        call_rel.cr_target_name = main_name
        push(s.synth_call_relocs, call_rel)
    elif has_main == 0
        // When no main exists, default exit code is 0 in rax
        x86_synth_emit_byte(s, 49)  // xor eax, eax (default exit code 0)
        x86_synth_emit_byte(s, 192)

    // 4. Top-level exit epilogue
    x86_synth_emit_epilogue(s)

    // 5. Emit complete micro-runtime helpers (zero C/libc, pure silicon execution)
    x86_synth_emit_print_int_helper(s)
    x86_synth_emit_alloc_helper(s)
    x86_synth_emit_all_runtime_helpers(s)
    x86_synth_emit_all_avx2_helpers(s)
    arena_offs = x86_synth_emit_arena_helpers(s)

    // 6. Resolve Inter-Procedural Call Relocations
    ci = 0
    while ci < s.synth_call_relocs.len()
        cr = s.synth_call_relocs[ci]
        resolved_addr = 0
        found = 0
        if cr.cr_target_name == "__print_int"
            resolved_addr = s.synth_print_int_off
            found = 1
        elif cr.cr_target_name == "__alloc"
            resolved_addr = s.synth_alloc_off
            found = 1
        else
            if cr.cr_target_name == "main" or cr.cr_target_name == "মূল"
                // WHY: For entry point main, resolve to latest definition in root translation unit
                k = s.synth_functions.len() - 1
                while k >= 0
                    fn_item = s.synth_functions[k]
                    if fn_item.fn_name == cr.cr_target_name
                        resolved_addr = fn_item.fn_entry_offset
                        found = 1
                        break
                    k = k - 1
            else
                // WHY: For general functions, preserve original definition ordering and ABI stability
                k = 0
                while k < s.synth_functions.len()
                    fn_item = s.synth_functions[k]
                    if fn_item.fn_name == cr.cr_target_name
                        resolved_addr = fn_item.fn_entry_offset
                        found = 1
                        break
                    k = k + 1

        if found == 0
            say "❌ [LINKER ERROR]: Unresolved function symbol: " + cr.cr_target_name
            say "  • Total registered functions: " + str(s.synth_functions.len())
            say "  • Call reloc target: " + cr.cr_target_name + " at patch offset " + str(cr.cr_patch_offset)
            i = 0
            while i < s.synth_functions.len()
                say "    fn[" + str(i) + "]: " + s.synth_functions[i].fn_name
                i = i + 1
            exit(1)

        rel32 = resolved_addr - cr.cr_call_site_end
        x86_synth_patch_u32(s, cr.cr_patch_offset, rel32)
        ci = ci + 1

    // 7. Resolve 64-Bit Virtual Memory String Relocations
    total_code_size = s.synth_code.len()
    rodata_base_vaddr = 1073742064 - (0 - total_code_size)
    ro_len = s.synth_rodata.len()
    rodata_end_vaddr = rodata_base_vaddr - (0 - ro_len)

    ri = 0
    while ri < s.synth_str_relocs.len()
        rel = s.synth_str_relocs[ri]
        target_vaddr = rodata_base_vaddr - (0 - rel.sr_rodata_offset)
        x86_synth_patch_u64(s, rel.sr_patch_offset, target_vaddr)
        ri = ri + 1

    // 8. Backpatch _lipi_is_str precise virtual memory bounds (zero SEGV_MAPERR)
    heap_base_vaddr = 1073742064 - (0 - s.synth_alloc_off) - (0 - 78)
    heap_ptr_vaddr = 1073742064 - (0 - s.synth_alloc_off) - (0 - 86)
    if s.synth_is_str_off > 0
        x86_synth_patch_u64(s, s.synth_is_str_off + 19, rodata_base_vaddr)
        x86_synth_patch_u64(s, s.synth_is_str_off + 34, rodata_end_vaddr)
        x86_synth_patch_u64(s, s.synth_is_str_off + 49, heap_base_vaddr)
        x86_synth_patch_u64(s, s.synth_is_str_off + 72, heap_ptr_vaddr)

    // 9. Backpatch Scoped Arena Virtual Addresses
    x86_synth_patch_arena_helpers(s, arena_offs, heap_base_vaddr, heap_ptr_vaddr)

    // 10. Sovereign Silicon Direct Peephole Optimizer (Guarded)
    x86_silicon_optimize_code(s)

    return s
