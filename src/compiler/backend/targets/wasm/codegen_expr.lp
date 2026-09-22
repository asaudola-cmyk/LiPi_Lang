// ==============================================================================
// ── 6. Synthesizer State Management & Local Allocation ────────────────────────
// ==============================================================================

fn wasm_synth_new
    // WHY: Allocates clean synthesizer state for bytecode compilation.
    s = WasmSynthesizer()
    s.ws_code = list()
    s.ws_locals = list()
    s.ws_functions = list()
    s.ws_loop_stack = list()
    s.ws_current_fn = 0
    s.ws_types = list()
    s.ws_block_depth = 0
    s.ws_data_bytes = list()
    return s

fn wasm_synth_get_or_add_type s param_count
    // WHY: Deduplicates function signatures in Type Section. Each signature
    //      takes param_count i64 arguments and returns 1 i64 value.
    ti = 0
    tcount = s.ws_types.len()
    while ti < tcount
        if s.ws_types[ti] == param_count
            return ti
        ti = ti + 1

    push(s.ws_types, param_count)
    return s.ws_types.len() - 1

fn wasm_synth_find_function s name
    // WHY: Looks up a registered function by name to resolve call sites.
    fi = 0
    fcount = s.ws_functions.len()
    while fi < fcount
        f = s.ws_functions[fi]
        if f.wfn_name == name
            return f
        fi = fi + 1
    return 0

fn wasm_synth_create_func s name param_names
    // WHY: Constructs a function definition, registers its parameter locals,
    //      and records its type signature index.
    f = WasmFuncDef()
    f.wfn_name = name
    f.wfn_index = s.ws_functions.len()
    f.wfn_param_count = param_names.len()
    f.wfn_param_names = param_names
    f.wfn_locals = list()
    f.wfn_var_locals = list()
    f.wfn_code = list()
    f.wfn_has_returned = 0
    f.wfn_type_index = wasm_synth_get_or_add_type(s, f.wfn_param_count)

    // Register formal parameters as locals 0..P-1
    pi = 0
    while pi < f.wfn_param_count
        lv = WasmLocalVar()
        lv.wlv_name = param_names[pi]
        lv.wlv_index = pi
        lv.wlv_is_param = 1
        push(f.wfn_locals, lv)
        pi = pi + 1

    push(s.ws_functions, f)
    return f

fn wasm_synth_lookup_local s name
    // WHY: Finds local variable index by name in current function scope.
    if s.ws_current_fn == 0
        return 0 - 1
    f = s.ws_current_fn
    li = 0
    lcount = f.wfn_locals.len()
    while li < lcount
        lv = f.wfn_locals[li]
        if lv.wlv_name == name
            return lv.wlv_index
        li = li + 1
    return 0 - 1

fn wasm_synth_alloc_local s name
    // WHY: Retrieves existing local variable index or allocates next available slot.
    existing = wasm_synth_lookup_local(s, name)
    if existing >= 0
        return existing

    f = s.ws_current_fn
    next_idx = f.wfn_param_count + f.wfn_var_locals.len()

    lv = WasmLocalVar()
    lv.wlv_name = name
    lv.wlv_index = next_idx
    lv.wlv_is_param = 0
    push(f.wfn_locals, lv)
    push(f.wfn_var_locals, name)

    return next_idx

fn wasm_synth_add_string_constant s str_text
    // WHY: Appends string literal into linear memory rodata buffer and returns its offset.
    base_offset = 1024 + s.ws_data_bytes.len()
    slen = len(str_text)
    i = 0
    while i < slen
        c = char_at(str_text, i)
        push(s.ws_data_bytes, ord(c))
        i = i + 1
    push(s.ws_data_bytes, 0) // Null terminator
    return base_offset

// ==============================================================================
// ── 7. Recursive-Descent Expression Synthesizer ────────────────────────────────
// ==============================================================================

fn wasm_synth_skip_whitespace toks pos_box
    // WHY: Advances token pointer across non-executable trivia (newlines, semicolons, comments).
    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind
        if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
            list_set(pos_box, 0, p + 1)
        else
            break
    return 0

fn wasm_synth_expr_primary s toks pos_box
    // WHY: Synthesizes primary operands: literals, variables, calls, parenthesized expressions.
    // Leaves exactly one 64-bit operand on the WASM evaluation stack.
    pos = get(pos_box, 0)
    if pos >= toks.len()
        wasm_emit_i64_const(s.ws_code, 0)
        return 0

    t = toks[pos]
    k = t.tok_kind
    txt = t.tok_text

    // 1. Integer Literal
    if k == TOK_INT()
        list_set(pos_box, 0, pos + 1)
        int_val = t.tok_int_val
        wasm_emit_i64_const(s.ws_code, int_val)
        return 0

    // 2. String Literal
    if k == TOK_STR()
        list_set(pos_box, 0, pos + 1)
        str_offset = wasm_synth_add_string_constant(s, txt)
        wasm_emit_i64_const(s.ws_code, str_offset)
        return 0

    // 3. Parenthesized Expression: ( expr )
    if k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1) // Consume '('
        wasm_synth_compile_expr(s, toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_p + 1) // Consume ')'
        return 0

    // 4. Unary Minus: -expr
    if k == TOK_MINUS()
        list_set(pos_box, 0, pos + 1)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_synth_expr_primary(s, toks, pos_box)
        wasm_emit_i64_sub(s.ws_code)
        return 0

    // 5. Identifier: Variable Read or Function Call
    is_ident = 0
    if k == TOK_IDENT() or k == TOK_KW_PRINT() or k == TOK_KW_SYSCALL()
        is_ident = 1

    if is_ident == 1
        list_set(pos_box, 0, pos + 1)
        ident_name = txt
        next_pos = get(pos_box, 0)

        // Function call check: ident(...)
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_LPAREN()
            list_set(pos_box, 0, next_pos + 1) // Consume '('

            arg_count = 0
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                wasm_synth_compile_expr(s, toks, pos_box)
                arg_count = arg_count + 1

                cur_p = get(pos_box, 0)
                if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, cur_p + 1)

            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            // Lookup target function in registry
            target_fn = wasm_synth_find_function(s, ident_name)
            if target_fn != 0
                wasm_emit_call(s.ws_code, target_fn.wfn_index)
            elif ident_name == "mem_read" or ident_name == "mem_word_read" or ident_name == "মেমরি_পড়ো"
                if arg_count >= 2
                    wasm_emit_i64_add(s.ws_code)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 0, 0)
                elif arg_count == 1
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 0, 0)
                else
                    wasm_emit_i64_const(s.ws_code, 0)
            elif ident_name == "mem_byte_read" or ident_name == "mem_read_byte" or ident_name == "মেমরি_বাইট_পড়ো" or ident_name == "sys_peek8"
                if arg_count >= 2
                    wasm_emit_i64_add(s.ws_code)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load8_u(s.ws_code, 0, 0)
                elif arg_count == 1
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load8_u(s.ws_code, 0, 0)
                else
                    wasm_emit_i64_const(s.ws_code, 0)
            elif ident_name == "exit" or ident_name == "বিদায়"
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_emit_unreachable(s.ws_code)
            elif ident_name == "syscall" or ident_name == "সিসকল"
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_emit_i64_const(s.ws_code, 0)
            elif ident_name == "malloc" or ident_name == "মেমরি_বরাদ্দ"
                if arg_count == 0
                    wasm_emit_i64_const(s.ws_code, 65536)
                else
                    wasm_emit_i64_const(s.ws_code, 65536)
                    wasm_emit_i64_add(s.ws_code)
            else
                // Intrinsic / Unknown function fallback: discard args, push 0
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_emit_i64_const(s.ws_code, 0)
            return 0

        // Local variable read:
        loc_idx = wasm_synth_lookup_local(s, ident_name)
        if loc_idx >= 0
            wasm_emit_local_get(s.ws_code, loc_idx)
        else
            // Unbound identifier defaults to 0
            wasm_emit_i64_const(s.ws_code, 0)
        return 0

    // Fallback: advance position and push 0
    list_set(pos_box, 0, pos + 1)
    wasm_emit_i64_const(s.ws_code, 0)
    return 0

fn wasm_synth_expr_multiplicative s toks pos_box
    // WHY: Pratt level for high-precedence binary operators: *, /, %
    wasm_synth_expr_primary(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind

        if k == TOK_STAR()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_primary(s, toks, pos_box)
            wasm_emit_i64_mul(s.ws_code)
        elif k == TOK_SLASH()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_primary(s, toks, pos_box)
            wasm_emit_i64_div_s(s.ws_code)
        elif k == TOK_PERCENT()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_primary(s, toks, pos_box)
            wasm_emit_i64_rem_s(s.ws_code)
        else
            break
    return 0

fn wasm_synth_expr_additive s toks pos_box
    // WHY: Pratt level for standard arithmetic operators: +, -
    wasm_synth_expr_multiplicative(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind

        if k == TOK_PLUS()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_multiplicative(s, toks, pos_box)
            wasm_emit_i64_add(s.ws_code)
        elif k == TOK_MINUS()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_multiplicative(s, toks, pos_box)
            wasm_emit_i64_sub(s.ws_code)
        else
            break
    return 0

fn wasm_synth_expr_relational s toks pos_box
    // WHY: Pratt level for comparison operators: ==, !=, <, <=, >, >=
    // Produces a consistent 64-bit boolean (1 or 0) via i64.extend_i32_u.
    wasm_synth_expr_additive(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind

        if k == TOK_EQ()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_eq(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        elif k == TOK_NEQ()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        elif k == TOK_LT()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_lt_s(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        elif k == TOK_LTE()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_le_s(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        elif k == TOK_GT()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_gt_s(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        elif k == TOK_GTE()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_i64_ge_s(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        else
            break
    return 0

fn wasm_synth_compile_expr s toks pos_box
    // WHY: Master expression evaluator entering at relational precedence level.
    return wasm_synth_expr_relational(s, toks, pos_box)

// ==============================================================================
// ── 8. Statement Synthesizer (Control Flow, Loops, Variables) ──────────────────
// ==============================================================================

fn wasm_synth_compile_statement s toks pos_box
    // WHY: Synthesizes WebAssembly bytecode for statements:
    //      - return / ফেরত
    //      - break / থামো & continue / চলুক
    //      - if / elif / else (যদি / নাহলে_যদি / নাহলে)
    //      - while / যতক্ষণ & for / প্রতিটি
    //      - variable declarations and assignments (x = 42)
    //      - say / বলো / print (emits expression + drop)
    pos = get(pos_box, 0)
    if pos >= toks.len()
        return 0

    t = toks[pos]
    k = t.tok_kind
    txt = t.tok_text

    // Skip newlines, semicolons, comments
    if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
        list_set(pos_box, 0, pos + 1)
        return 0

    // Consume standalone block end markers (@end, end, শেষ)
    if k == TOK_KW_END() or k == TOK_DIR_END() or (k == TOK_IDENT() and (txt == "@end" or txt == "end" or txt == "শেষ"))
        list_set(pos_box, 0, pos + 1)
        return 0

