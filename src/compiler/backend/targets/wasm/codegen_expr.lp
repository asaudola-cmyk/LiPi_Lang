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
    s.ws_needs_wasi_print = 0
    s.ws_structs = list()
    s.ws_global_fields = list()
    s.ws_try_depths = list()
    s.ws_last_expr_is_float = 0
    s.ws_last_expr_is_str = 0
    s.ws_float_vars = list()
    s.ws_str_vars = list()
    s.ws_narrow_vars = list()
    s.ws_narrow_types = list()
    s.ws_freestanding = g_wasm_freestanding
    s.ws_ssa_replaced_cnt = 0
    s.ws_ssa_replaced_bytes = 0
    return s

fn wasm_synth_set_narrow_type s name tname
    ni = 0
    while ni < s.ws_narrow_vars.len()
        if s.ws_narrow_vars[ni] == name
            list_set(s.ws_narrow_types, ni, tname)
            return 0
        end
        ni = ni + 1
    end
    push(s.ws_narrow_vars, name)
    push(s.ws_narrow_types, tname)
    return 0
end

fn wasm_synth_get_narrow_type s name
    ni = 0
    while ni < s.ws_narrow_vars.len()
        if s.ws_narrow_vars[ni] == name
            return s.ws_narrow_types[ni]
        end
        ni = ni + 1
    end
    return ""
end

fn wasm_list_contains lst name
    li = 0
    while li < lst.len()
        if lst[li] == name
            return 1
        li = li + 1
    return 0

fn wasm_list_set_membership lst name flag
    out = list()
    li = 0
    seen = 0
    while li < lst.len()
        item = lst[li]
        if item == name
            if flag == 1
                push(out, item)
                seen = 1
        else
            push(out, item)
        li = li + 1
    if flag == 1 and seen == 0
        push(out, name)
    return out

fn wasm_synth_is_float_var s name
    return wasm_list_contains(s.ws_float_vars, name)

fn wasm_synth_mark_float_var s name flag
    s.ws_float_vars = wasm_list_set_membership(s.ws_float_vars, name, flag)
    return 0

fn wasm_synth_is_str_var s name
    return wasm_list_contains(s.ws_str_vars, name)

fn wasm_synth_mark_str_var s name flag
    s.ws_str_vars = wasm_list_set_membership(s.ws_str_vars, name, flag)
    return 0

fn wasm_synth_find_struct s sname
    si = 0
    while si < s.ws_structs.len()
        sd = s.ws_structs[si]
        if sd.wsd_name == sname
            return sd
        si = si + 1
    return 0

fn wasm_synth_get_field_offset s fname
    // WHY: Checks defined struct field tables first so distinct structs align with positional constructors,
    // falling back to unified global field slot table for structural/dynamic field access.
    si = 0
    while si < s.ws_structs.len()
        sd = s.ws_structs[si]
        fi = 0
        while fi < sd.wsd_fields.len()
            if sd.wsd_fields[fi] == fname
                return fi * 8
            fi = fi + 1
        si = si + 1
    gi = 0
    while gi < s.ws_global_fields.len()
        if s.ws_global_fields[gi] == fname
            return gi * 8
        gi = gi + 1
    push(s.ws_global_fields, fname)
    return (s.ws_global_fields.len() - 1) * 8

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
    // WHY: Stores 8-byte aligned tagged length-prefixed UTF-8 string in linear memory:
    //   [ptr - 16] = magic 0x4C505354 ("LPST"), [ptr - 8] = byte len (i64), [ptr..] = UTF-8 + '\0'.
    while (s.ws_data_bytes.len() % 8) != 0
        push(s.ws_data_bytes, 0)
    // Magic 1280332628 = 0x4C505354 ('T','S','P','L', 0..0)
    push(s.ws_data_bytes, 84)
    push(s.ws_data_bytes, 83)
    push(s.ws_data_bytes, 80)
    push(s.ws_data_bytes, 76)
    push(s.ws_data_bytes, 0)
    push(s.ws_data_bytes, 0)
    push(s.ws_data_bytes, 0)
    push(s.ws_data_bytes, 0)
    slen = len(str_text)
    push(s.ws_data_bytes, slen & 255)
    push(s.ws_data_bytes, (slen / 256) & 255)
    push(s.ws_data_bytes, (slen / 65536) & 255)
    push(s.ws_data_bytes, (slen / 16777216) & 255)
    push(s.ws_data_bytes, 0)
    push(s.ws_data_bytes, 0)
    push(s.ws_data_bytes, 0)
    push(s.ws_data_bytes, 0)
    base_offset = 1024 + s.ws_data_bytes.len()
    i = 0
    while i < slen
        c = char_at(str_text, i)
        push(s.ws_data_bytes, ord(c))
        i = i + 1
    push(s.ws_data_bytes, 0) // Null terminator
    return base_offset

fn wasm_synth_emit_list_create_opcodes code_buf heap_offset initial_len
    // WHY: Emits W3C WebAssembly linear-memory 24-byte list header {len, cap, data_ptr} initialization:
    //   [heap_offset + 0]  = initial_len (i64)
    //   [heap_offset + 8]  = 16          (i64 capacity)
    //   [heap_offset + 16] = heap_offset + 24 (i64 data_ptr)
    wasm_emit_i32_const(code_buf, heap_offset)
    wasm_emit_i64_const(code_buf, initial_len)
    wasm_emit_i64_store(code_buf, 3, 0)

    wasm_emit_i32_const(code_buf, heap_offset + 8)
    wasm_emit_i64_const(code_buf, 16)
    wasm_emit_i64_store(code_buf, 3, 0)

    wasm_emit_i32_const(code_buf, heap_offset + 16)
    wasm_emit_i64_const(code_buf, heap_offset + 24)
    wasm_emit_i64_store(code_buf, 3, 0)

    wasm_emit_i64_const(code_buf, heap_offset)
    return heap_offset + 160

fn wasm_synth_emit_bump_alloc s
    // WHY: Pops [i64 size], aligns up to 8B (min 8B), allocates sequentially via mem[24]
    // starting at 65536 (clear of .rodata at 1024..65535), and pushes allocated i64 ptr.
    l_sz = wasm_synth_alloc_local(s, "__wasi_alloc_sz")
    l_ptr = wasm_synth_alloc_local(s, "__wasi_alloc_ptr")

    wasm_emit_local_set(s.ws_code, l_sz)
    wasm_emit_local_get(s.ws_code, l_sz)
    wasm_emit_i64_const(s.ws_code, 8)
    wasm_emit_i64_lt_s(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
    wasm_emit_i64_const(s.ws_code, 8)
    wasm_emit_local_set(s.ws_code, l_sz)
    wasm_emit_else(s.ws_code)
    wasm_emit_local_get(s.ws_code, l_sz)
    wasm_emit_i64_const(s.ws_code, 7)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_i64_const(s.ws_code, 8)
    wasm_emit_i64_div_s(s.ws_code)
    wasm_emit_i64_const(s.ws_code, 8)
    wasm_emit_i64_mul(s.ws_code)
    wasm_emit_local_set(s.ws_code, l_sz)
    wasm_emit_end(s.ws_code)

    wasm_emit_i32_const(s.ws_code, 24)
    wasm_emit_i64_load(s.ws_code, 3, 0)
    wasm_emit_local_tee(s.ws_code, l_ptr)
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_i64_eq(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
    wasm_emit_i64_const(s.ws_code, 65536)
    wasm_emit_local_set(s.ws_code, l_ptr)
    wasm_emit_end(s.ws_code)

    wasm_emit_i32_const(s.ws_code, 24)
    wasm_emit_local_get(s.ws_code, l_ptr)
    wasm_emit_local_get(s.ws_code, l_sz)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_i64_store(s.ws_code, 3, 0)

    wasm_emit_local_get(s.ws_code, l_ptr)
    return 0

fn wasm_synth_emit_str_len_into s l_ptr l_out
    // WHY: Reads string length into l_out (i64) from [l_ptr - 8] if tagged with LPST magic, else 0.
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_local_set(s.ws_code, l_out)
    wasm_emit_local_get(s.ws_code, l_ptr)
    wasm_emit_i64_const(s.ws_code, 1040)
    wasm_emit_i64_ge_s(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_ptr)
        wasm_emit_i64_const(s.ws_code, 262144)
        wasm_emit_i64_lt_s(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_ptr)
            wasm_emit_i64_const(s.ws_code, 7)
            wasm_emit_i64_and(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_eq(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_ptr)
                wasm_emit_i64_const(s.ws_code, 16)
                wasm_emit_i64_sub(s.ws_code)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_i64_const(s.ws_code, 1280332628)
                wasm_emit_i64_eq(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                    wasm_emit_local_get(s.ws_code, l_ptr)
                    wasm_emit_i64_const(s.ws_code, 8)
                    wasm_emit_i64_sub(s.ws_code)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 3, 0)
                    wasm_emit_local_set(s.ws_code, l_out)
                wasm_emit_end(s.ws_code)
            wasm_emit_end(s.ws_code)
        wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0

fn wasm_synth_emit_copy_bytes s l_dst l_src l_cnt
    // WHY: Copies l_cnt bytes from linear memory l_src to l_dst using local index.
    l_ci = wasm_synth_alloc_local(s, "__wasi_cp_i")
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_local_set(s.ws_code, l_ci)
    wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
    wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_ci)
        wasm_emit_local_get(s.ws_code, l_cnt)
        wasm_emit_i64_ge_s(s.ws_code)
        wasm_emit_br_if(s.ws_code, 1)
        wasm_emit_local_get(s.ws_code, l_dst)
        wasm_emit_local_get(s.ws_code, l_ci)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_src)
        wasm_emit_local_get(s.ws_code, l_ci)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load8_u(s.ws_code, 0, 0)
        wasm_emit_i64_store8(s.ws_code, 0, 0)
        wasm_emit_local_get(s.ws_code, l_ci)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_ci)
        wasm_emit_br(s.ws_code, 0)
    wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0

fn wasm_synth_emit_runtime_str_concat s
    // WHY: Pops [lhs_str, rhs_str], allocates length-prefixed LPST string buffer on linear heap,
    // copies both UTF-8 payloads, null-terminates, and leaves result pointer on stack.
    l_sa = wasm_synth_alloc_local(s, "__wasi_sc_a")
    l_sb = wasm_synth_alloc_local(s, "__wasi_sc_b")
    l_la = wasm_synth_alloc_local(s, "__wasi_sc_la")
    l_lb = wasm_synth_alloc_local(s, "__wasi_sc_lb")
    l_buf = wasm_synth_alloc_local(s, "__wasi_sc_buf")
    l_dst2 = wasm_synth_alloc_local(s, "__wasi_sc_dst2")

    wasm_emit_local_set(s.ws_code, l_sb)
    wasm_emit_local_set(s.ws_code, l_sa)
    wasm_synth_emit_str_len_into(s, l_sa, l_la)
    wasm_synth_emit_str_len_into(s, l_sb, l_lb)

    wasm_emit_local_get(s.ws_code, l_la)
    wasm_emit_local_get(s.ws_code, l_lb)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_i64_const(s.ws_code, 24)
    wasm_emit_i64_add(s.ws_code)
    wasm_synth_emit_bump_alloc(s)
    wasm_emit_local_set(s.ws_code, l_buf)

    wasm_emit_local_get(s.ws_code, l_buf)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_const(s.ws_code, 1280332628)
    wasm_emit_i64_store(s.ws_code, 3, 0)

    wasm_emit_local_get(s.ws_code, l_buf)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_local_get(s.ws_code, l_la)
    wasm_emit_local_get(s.ws_code, l_lb)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_i64_store(s.ws_code, 3, 8)

    wasm_emit_local_get(s.ws_code, l_buf)
    wasm_emit_i64_const(s.ws_code, 16)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_local_set(s.ws_code, l_dst2)
    wasm_synth_emit_copy_bytes(s, l_dst2, l_sa, l_la)

    wasm_emit_local_get(s.ws_code, l_dst2)
    wasm_emit_local_get(s.ws_code, l_la)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_local_set(s.ws_code, l_dst2)
    wasm_synth_emit_copy_bytes(s, l_dst2, l_sb, l_lb)

    wasm_emit_local_get(s.ws_code, l_dst2)
    wasm_emit_local_get(s.ws_code, l_lb)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_i64_store8(s.ws_code, 0, 0)

    wasm_emit_local_get(s.ws_code, l_buf)
    wasm_emit_i64_const(s.ws_code, 16)
    wasm_emit_i64_add(s.ws_code)
    s.ws_last_expr_is_str = 1
    s.ws_last_expr_is_float = 0
    return 0

fn wasm_synth_emit_str_or_list_len s l_ptr
    // WHY: Dispatches len() cleanly: LPST tagged strings return [ptr - 8]; lists return [ptr + 0].
    wasm_emit_local_get(s.ws_code, l_ptr)
    wasm_emit_i64_const(s.ws_code, 1040)
    wasm_emit_i64_ge_s(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_I64)
        wasm_emit_local_get(s.ws_code, l_ptr)
        wasm_emit_i64_const(s.ws_code, 262144)
        wasm_emit_i64_lt_s(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_I64)
            wasm_emit_local_get(s.ws_code, l_ptr)
            wasm_emit_i64_const(s.ws_code, 7)
            wasm_emit_i64_and(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_eq(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_I64)
                wasm_emit_local_get(s.ws_code, l_ptr)
                wasm_emit_i64_const(s.ws_code, 16)
                wasm_emit_i64_sub(s.ws_code)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_i64_const(s.ws_code, 1280332628)
                wasm_emit_i64_eq(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_I64)
                    wasm_emit_local_get(s.ws_code, l_ptr)
                    wasm_emit_i64_const(s.ws_code, 8)
                    wasm_emit_i64_sub(s.ws_code)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_else(s.ws_code)
                    wasm_emit_local_get(s.ws_code, l_ptr)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_end(s.ws_code)
            wasm_emit_else(s.ws_code)
                wasm_emit_local_get(s.ws_code, l_ptr)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_load(s.ws_code, 3, 0)
            wasm_emit_end(s.ws_code)
        wasm_emit_else(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_end(s.ws_code)
    wasm_emit_else(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_ptr)
        wasm_emit_i64_const(s.ws_code, 24)
        wasm_emit_i64_ge_s(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_I64)
            wasm_emit_local_get(s.ws_code, l_ptr)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_load(s.ws_code, 3, 0)
        wasm_emit_else(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0

fn wasm_synth_emit_str_concat_opcodes s str_a str_b
    // WHY: Interns concatenated string constant into WASM linear memory data segment
    // and pushes its 64-bit linear memory pointer onto the WASM value stack.
    joined = str_a + str_b
    off = wasm_synth_add_string_constant(s, joined)
    wasm_emit_i64_const(s.ws_code, off)
    s.ws_last_expr_is_str = 1
    s.ws_last_expr_is_float = 0
    return off

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
    s.ws_last_expr_is_float = 0
    s.ws_last_expr_is_str = 0
    pos = get(pos_box, 0)
    if pos >= toks.len()
        wasm_emit_i64_const(s.ws_code, 0)
        return 0

    t = toks[pos]
    k = t.tok_kind
    txt = t.tok_text

    // 1. Integer / Boolean / Null Literal
    if k == TOK_INT() or k == TOK_BOOL() or k == TOK_NONE()
        list_set(pos_box, 0, pos + 1)
        int_val = t.tok_int_val
        wasm_emit_i64_const(s.ws_code, int_val)
        return 0

    // 1b. Float Literal: IEEE-754 binary64 64-bit precision
    if k == TOK_FLOAT()
        list_set(pos_box, 0, pos + 1)
        fbits = wasm_parse_float_bits(t.tok_text)
        wasm_emit_i64_const(s.ws_code, fbits)
        s.ws_last_expr_is_float = 1
        return 0

    // 2. String Literal
    if k == TOK_STR()
        list_set(pos_box, 0, pos + 1)
        str_offset = wasm_synth_add_string_constant(s, txt)
        wasm_emit_i64_const(s.ws_code, str_offset)
        s.ws_last_expr_is_str = 1
        return 0

    // 3. Parenthesized Expression: ( expr )
    if k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1) // Consume '('
        wasm_synth_compile_expr(s, toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_p + 1) // Consume ')'
        return 0

    // 4. Unary Minus: -expr (handles both i64 negation and f64 IEEE-754 sign flip)
    if k == TOK_MINUS()
        list_set(pos_box, 0, pos + 1)
        wasm_synth_expr_primary(s, toks, pos_box)
        if s.ws_last_expr_is_float == 1
            wasm_emit_f64_reinterpret_i64(s.ws_code)
            wasm_emit_f64_neg(s.ws_code)
            wasm_emit_i64_reinterpret_f64(s.ws_code)
            s.ws_last_expr_is_float = 1
        else
            l_un = wasm_synth_alloc_local(s, "__wasi_un_neg")
            wasm_emit_local_set(s.ws_code, l_un)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_local_get(s.ws_code, l_un)
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
                // WHY: WASI import fd_write occupies function index 0 when ws_needs_wasi_print == 1,
                // shifting all module-defined WASM function indices up by +1.
                wasm_emit_call(s.ws_code, target_fn.wfn_index + s.ws_needs_wasi_print)
                // WHY: Inter-procedural exception propagation across WASM calls checks linear
                // memory flag at offset 104 immediately after each call returns.
                l_cret = wasm_synth_alloc_local(s, "__wasi_call_ret")
                wasm_emit_local_set(s.ws_code, l_cret)
                wasm_emit_i32_const(s.ws_code, 104)
                wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_i64_const(s.ws_code, 0)
                wasm_emit_i64_ne(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                if s.ws_try_depths.len() > 0
                    t_depth = s.ws_try_depths[s.ws_try_depths.len() - 1]
                    rel_try = (s.ws_block_depth + 1) - t_depth
                    wasm_emit_br(s.ws_code, rel_try)
                elif s.ws_current_fn != 0 and s.ws_current_fn.wfn_name != "main" and s.ws_current_fn.wfn_name != "_start" and s.ws_current_fn.wfn_name != "মূল"
                    wasm_emit_i64_const(s.ws_code, 0)
                    wasm_emit_return(s.ws_code)
                wasm_emit_end(s.ws_code)
                wasm_emit_local_get(s.ws_code, l_cret)
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
            elif ident_name == "malloc" or ident_name == "মেমরি_বরাদ্দ" or ident_name == "alloc" or ident_name == "sys_alloc" or ident_name == "mem_alloc" or ident_name == "বরাদ্দ"
                if arg_count == 0
                    wasm_emit_i64_const(s.ws_code, 8)
                else
                    // Keep first size argument on stack; discard any extra args
                    while arg_count > 1
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                wasm_synth_emit_bump_alloc(s)
            elif ident_name == "free" or ident_name == "sys_free" or ident_name == "mem_free" or ident_name == "মুক্ত" or ident_name == "মেমরি_মুক্তি"
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_emit_i64_const(s.ws_code, 0)
            elif ident_name == "mem_write" or ident_name == "mem_word_write" or ident_name == "মেমরি_লেখো" or ident_name == "মেমরি_শব্দ_লেখো"
                if arg_count >= 3
                    while arg_count > 3
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_mwv = wasm_synth_alloc_local(s, "__wasi_mw_v")
                    wasm_emit_local_set(s.ws_code, l_mwv)
                    wasm_emit_i64_add(s.ws_code)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_local_get(s.ws_code, l_mwv)
                    wasm_emit_i64_store(s.ws_code, 0, 0)
                    wasm_emit_local_get(s.ws_code, l_mwv)
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
            elif ident_name == "mem_byte_write" or ident_name == "mem_write_byte" or ident_name == "মেমরি_বাইট_লেখো" or ident_name == "sys_poke8"
                if arg_count >= 3
                    while arg_count > 3
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_mbwv = wasm_synth_alloc_local(s, "__wasi_mbw_v")
                    wasm_emit_local_set(s.ws_code, l_mbwv)
                    wasm_emit_i64_add(s.ws_code)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_local_get(s.ws_code, l_mbwv)
                    wasm_emit_i64_store8(s.ws_code, 0, 0)
                    wasm_emit_local_get(s.ws_code, l_mbwv)
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
            elif ident_name == "int" or ident_name == "পূর্ণসংখ্যা"
                if arg_count >= 1
                    while arg_count > 1
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    if s.ws_last_expr_is_float == 1
                        wasm_emit_f64_reinterpret_i64(s.ws_code)
                        wasm_emit_i64_trunc_f64_s(s.ws_code)
                else
                    wasm_emit_i64_const(s.ws_code, 0)
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "float" or ident_name == "দশমিক"
                if arg_count >= 1
                    while arg_count > 1
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    if s.ws_last_expr_is_float == 0
                        wasm_emit_f64_convert_i64_s(s.ws_code)
                        wasm_emit_i64_reinterpret_f64(s.ws_code)
                else
                    wasm_emit_i64_const(s.ws_code, 0)
                    wasm_emit_f64_convert_i64_s(s.ws_code)
                    wasm_emit_i64_reinterpret_f64(s.ws_code)
                s.ws_last_expr_is_float = 1
                s.ws_last_expr_is_str = 0
            elif ident_name == "str_concat"
                if arg_count >= 2
                    while arg_count > 2
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    wasm_synth_emit_runtime_str_concat(s)
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, wasm_synth_add_string_constant(s, ""))
                    s.ws_last_expr_is_str = 1
                    s.ws_last_expr_is_float = 0
            elif ident_name == "len" or ident_name == "দৈর্ঘ্য"
                if arg_count >= 1
                    while arg_count > 1
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_len_p = wasm_synth_alloc_local(s, "__wasi_len_p")
                    wasm_emit_local_set(s.ws_code, l_len_p)
                    wasm_synth_emit_str_or_list_len(s, l_len_p)
                else
                    wasm_emit_i64_const(s.ws_code, 0)
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "get" or ident_name == "নাও"
                if arg_count >= 2
                    while arg_count > 2
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_lgi = wasm_synth_alloc_local(s, "__wasi_lg_i")
                    wasm_emit_local_set(s.ws_code, l_lgi)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 3, 16)
                    wasm_emit_local_get(s.ws_code, l_lgi)
                    wasm_emit_i64_const(s.ws_code, 8)
                    wasm_emit_i64_mul(s.ws_code)
                    wasm_emit_i64_add(s.ws_code)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 3, 0)
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
            elif ident_name == "list_set" or ident_name == "সেট"
                if arg_count >= 3
                    while arg_count > 3
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_lsv = wasm_synth_alloc_local(s, "__wasi_ls_v")
                    l_lsi = wasm_synth_alloc_local(s, "__wasi_ls_i")
                    l_lsh = wasm_synth_alloc_local(s, "__wasi_ls_h")
                    wasm_emit_local_set(s.ws_code, l_lsv)
                    wasm_emit_local_set(s.ws_code, l_lsi)
                    wasm_emit_local_set(s.ws_code, l_lsh)
                    wasm_emit_local_get(s.ws_code, l_lsh)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 3, 16)
                    wasm_emit_local_get(s.ws_code, l_lsi)
                    wasm_emit_i64_const(s.ws_code, 8)
                    wasm_emit_i64_mul(s.ws_code)
                    wasm_emit_i64_add(s.ws_code)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_local_get(s.ws_code, l_lsv)
                    wasm_emit_i64_store(s.ws_code, 3, 0)
                    wasm_emit_local_get(s.ws_code, l_lsh)
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
            elif ident_name == "list" or ident_name == "তালিকা"
                // WHY: Pops evaluated args in reverse into locals, bump-allocates 24-byte header +
                // element storage via mem[24], and stores elements in order at [hdr + 24 + i*8].
                arg_locs = list()
                ai = 0
                while ai < arg_count
                    push(arg_locs, wasm_synth_alloc_local(s, "__wasi_list_arg_" + str(ai)))
                    ai = ai + 1
                rev = arg_count - 1
                while rev >= 0
                    wasm_emit_local_set(s.ws_code, arg_locs[rev])
                    rev = rev - 1

                l_cap = 16
                if arg_count > 16
                    l_cap = arg_count
                total_sz = 24 + (l_cap * 8)
                wasm_emit_i64_const(s.ws_code, total_sz)
                wasm_synth_emit_bump_alloc(s)

                l_hdr = wasm_synth_alloc_local(s, "__wasi_list_hdr")
                wasm_emit_local_set(s.ws_code, l_hdr)

                wasm_emit_local_get(s.ws_code, l_hdr)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_const(s.ws_code, arg_count)
                wasm_emit_i64_store(s.ws_code, 3, 0)

                wasm_emit_local_get(s.ws_code, l_hdr)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_const(s.ws_code, l_cap)
                wasm_emit_i64_store(s.ws_code, 3, 8)

                wasm_emit_local_get(s.ws_code, l_hdr)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_local_get(s.ws_code, l_hdr)
                wasm_emit_i64_const(s.ws_code, 24)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_i64_store(s.ws_code, 3, 16)

                ei = 0
                while ei < arg_count
                    wasm_emit_local_get(s.ws_code, l_hdr)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_local_get(s.ws_code, arg_locs[ei])
                    wasm_emit_i64_store(s.ws_code, 3, 24 + (ei * 8))
                    ei = ei + 1
                wasm_emit_local_get(s.ws_code, l_hdr)
            elif wasm_synth_find_struct(s, ident_name) != 0
                // WHY: Pops evaluated struct constructor args in reverse into locals, bump-allocates
                // 8 bytes per field via mem[24], stores fields at offset fi*8, and pushes struct ptr.
                sdef = wasm_synth_find_struct(s, ident_name)
                sc_locs = list()
                ai = 0
                while ai < arg_count
                    push(sc_locs, wasm_synth_alloc_local(s, "__wasi_sc_arg_" + str(ai)))
                    ai = ai + 1
                rev = arg_count - 1
                while rev >= 0
                    wasm_emit_local_set(s.ws_code, sc_locs[rev])
                    rev = rev - 1

                num_fields = sdef.wsd_fields.len()
                alloc_sz = num_fields * 8
                if alloc_sz < 8
                    alloc_sz = 8
                wasm_emit_i64_const(s.ws_code, alloc_sz)
                wasm_synth_emit_bump_alloc(s)

                l_sptr = wasm_synth_alloc_local(s, "__wasi_struct_ptr")
                wasm_emit_local_set(s.ws_code, l_sptr)

                fi = 0
                while fi < arg_count and fi < num_fields
                    wasm_emit_local_get(s.ws_code, l_sptr)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_local_get(s.ws_code, sc_locs[fi])
                    wasm_emit_i64_store(s.ws_code, 3, fi * 8)
                    fi = fi + 1
                wasm_emit_local_get(s.ws_code, l_sptr)
            else
                // Intrinsic / Unknown function fallback: discard args, push 0
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_emit_i64_const(s.ws_code, 0)
        else
            // Local variable read:
            loc_idx = wasm_synth_lookup_local(s, ident_name)
            if loc_idx >= 0
                wasm_emit_local_get(s.ws_code, loc_idx)
            else
                // Unbound identifier defaults to 0
                wasm_emit_i64_const(s.ws_code, 0)
            s.ws_last_expr_is_float = wasm_synth_is_float_var(s, ident_name)
            s.ws_last_expr_is_str = wasm_synth_is_str_var(s, ident_name)

        // Postfix member read: obj.field (supports chained a.b.c and fn().field and lst.len() / s.len())
        while get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_DOT() or toks[get(pos_box, 0)].tok_text == ".")
            dp = get(pos_box, 0)
            if dp + 1 < toks.len() and wasm_is_ident_token(toks[dp + 1].tok_kind) == 1
                fname = toks[dp + 1].tok_text
                if dp + 2 < toks.len() and toks[dp + 2].tok_kind == TOK_LPAREN()
                    if fname == "len" and dp + 3 < toks.len() and toks[dp + 3].tok_kind == TOK_RPAREN()
                        list_set(pos_box, 0, dp + 4)
                        l_plen = wasm_synth_alloc_local(s, "__wasi_plen_p")
                        wasm_emit_local_set(s.ws_code, l_plen)
                        wasm_synth_emit_str_or_list_len(s, l_plen)
                        s.ws_last_expr_is_float = 0
                        s.ws_last_expr_is_str = 0
                    else
                        break
                else
                    list_set(pos_box, 0, dp + 2)
                    f_off = wasm_synth_get_field_offset(s, fname)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 3, f_off)
                    s.ws_last_expr_is_float = 0
                    s.ws_last_expr_is_str = 0
            else
                break
        return 0

    // Fallback: advance position and push 0
    list_set(pos_box, 0, pos + 1)
    wasm_emit_i64_const(s.ws_code, 0)
    return 0

fn wasm_synth_emit_f64_binop s lhs_f rhs_f op_kind is_rel
    // WHY: Promotes integer operands to f64 via f64.convert_i64_s or reinterprets f64 bit patterns,
    // executes IEEE-754 f64 arithmetic or comparison, and restores Lipi's 64-bit i64 value ABI.
    l_rhs = wasm_synth_alloc_local(s, "__wasi_f64_r")
    l_lhs = wasm_synth_alloc_local(s, "__wasi_f64_l")
    wasm_emit_local_set(s.ws_code, l_rhs)
    wasm_emit_local_set(s.ws_code, l_lhs)

    wasm_emit_local_get(s.ws_code, l_lhs)
    if lhs_f == 1
        wasm_emit_f64_reinterpret_i64(s.ws_code)
    else
        wasm_emit_f64_convert_i64_s(s.ws_code)

    wasm_emit_local_get(s.ws_code, l_rhs)
    if rhs_f == 1
        wasm_emit_f64_reinterpret_i64(s.ws_code)
    else
        wasm_emit_f64_convert_i64_s(s.ws_code)

    if is_rel == 1
        if op_kind == TOK_EQ()
            wasm_emit_f64_eq(s.ws_code)
        elif op_kind == TOK_NEQ()
            wasm_emit_f64_ne(s.ws_code)
        elif op_kind == TOK_LT()
            wasm_emit_f64_lt(s.ws_code)
        elif op_kind == TOK_LTE()
            wasm_emit_f64_le(s.ws_code)
        elif op_kind == TOK_GT()
            wasm_emit_f64_gt(s.ws_code)
        else
            wasm_emit_f64_ge(s.ws_code)
        wasm_emit_i64_extend_i32_u(s.ws_code)
        s.ws_last_expr_is_float = 0
        s.ws_last_expr_is_str = 0
    else
        if op_kind == TOK_PLUS()
            wasm_emit_f64_add(s.ws_code)
        elif op_kind == TOK_MINUS()
            wasm_emit_f64_sub(s.ws_code)
        elif op_kind == TOK_STAR()
            wasm_emit_f64_mul(s.ws_code)
        else
            wasm_emit_f64_div(s.ws_code)
        wasm_emit_i64_reinterpret_f64(s.ws_code)
        s.ws_last_expr_is_float = 1
        s.ws_last_expr_is_str = 0
    return 0

fn wasm_synth_expr_multiplicative s toks pos_box
    // WHY: Pratt level for high-precedence binary operators: *, /, % (i64 & IEEE-754 f64)
    wasm_synth_expr_primary(s, toks, pos_box)
    lhs_f = s.ws_last_expr_is_float

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind

        if k == TOK_STAR()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_primary(s, toks, pos_box)
            rhs_f = s.ws_last_expr_is_float
            if lhs_f == 1 or rhs_f == 1
                wasm_synth_emit_f64_binop(s, lhs_f, rhs_f, TOK_STAR(), 0)
                lhs_f = 1
            else
                wasm_emit_i64_mul(s.ws_code)
                s.ws_last_expr_is_str = 0
        elif k == TOK_SLASH()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_primary(s, toks, pos_box)
            rhs_f = s.ws_last_expr_is_float
            if lhs_f == 1 or rhs_f == 1
                wasm_synth_emit_f64_binop(s, lhs_f, rhs_f, TOK_SLASH(), 0)
                lhs_f = 1
            else
                wasm_emit_i64_div_s(s.ws_code)
                s.ws_last_expr_is_str = 0
        elif k == TOK_PERCENT()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_primary(s, toks, pos_box)
            wasm_emit_i64_rem_s(s.ws_code)
            lhs_f = 0
            s.ws_last_expr_is_float = 0
            s.ws_last_expr_is_str = 0
        else
            break
    s.ws_last_expr_is_float = lhs_f
    return 0

fn wasm_synth_expr_additive s toks pos_box
    // WHY: Pratt level for standard arithmetic operators: +, - (i64, IEEE-754 f64, & string concat)
    // Also folds simple two-literal string concatenation ("a" + "b") directly into linear memory.
    p_lhs = get(pos_box, 0)
    if p_lhs + 2 < toks.len() and toks[p_lhs].tok_kind == TOK_STR() and toks[p_lhs + 1].tok_kind == TOK_PLUS() and toks[p_lhs + 2].tok_kind == TOK_STR()
        if p_lhs + 3 >= toks.len() or toks[p_lhs + 3].tok_kind != TOK_PLUS()
            str_a = toks[p_lhs].tok_text
            str_b = toks[p_lhs + 2].tok_text
            list_set(pos_box, 0, p_lhs + 3)
            wasm_synth_emit_str_concat_opcodes(s, str_a, str_b)
            return 0

    wasm_synth_expr_multiplicative(s, toks, pos_box)
    lhs_f = s.ws_last_expr_is_float
    lhs_s = s.ws_last_expr_is_str

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind

        if k == TOK_PLUS()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_multiplicative(s, toks, pos_box)
            rhs_f = s.ws_last_expr_is_float
            rhs_s = s.ws_last_expr_is_str
            if lhs_s == 1 or rhs_s == 1
                wasm_synth_emit_runtime_str_concat(s)
                lhs_s = 1
                lhs_f = 0
            elif lhs_f == 1 or rhs_f == 1
                wasm_synth_emit_f64_binop(s, lhs_f, rhs_f, TOK_PLUS(), 0)
                lhs_f = 1
                lhs_s = 0
            else
                wasm_emit_i64_add(s.ws_code)
                lhs_s = 0
        elif k == TOK_MINUS()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_multiplicative(s, toks, pos_box)
            rhs_f = s.ws_last_expr_is_float
            if lhs_f == 1 or rhs_f == 1
                wasm_synth_emit_f64_binop(s, lhs_f, rhs_f, TOK_MINUS(), 0)
                lhs_f = 1
            else
                wasm_emit_i64_sub(s.ws_code)
            lhs_s = 0
        else
            break
    s.ws_last_expr_is_float = lhs_f
    s.ws_last_expr_is_str = lhs_s
    return 0

fn wasm_synth_expr_relational s toks pos_box
    // WHY: Pratt level for comparison operators: ==, !=, <, <=, >, >= (i64 & IEEE-754 f64)
    // Produces a consistent 64-bit boolean (1 or 0) via i64.extend_i32_u.
    wasm_synth_expr_additive(s, toks, pos_box)
    lhs_f = s.ws_last_expr_is_float

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind

        if k == TOK_EQ() or k == TOK_NEQ() or k == TOK_LT() or k == TOK_LTE() or k == TOK_GT() or k == TOK_GTE()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            rhs_f = s.ws_last_expr_is_float
            if lhs_f == 1 or rhs_f == 1
                wasm_synth_emit_f64_binop(s, lhs_f, rhs_f, k, 1)
                lhs_f = 0
            else
                if k == TOK_EQ()
                    wasm_emit_i64_eq(s.ws_code)
                elif k == TOK_NEQ()
                    wasm_emit_i64_ne(s.ws_code)
                elif k == TOK_LT()
                    wasm_emit_i64_lt_s(s.ws_code)
                elif k == TOK_LTE()
                    wasm_emit_i64_le_s(s.ws_code)
                elif k == TOK_GT()
                    wasm_emit_i64_gt_s(s.ws_code)
                else
                    wasm_emit_i64_ge_s(s.ws_code)
                wasm_emit_i64_extend_i32_u(s.ws_code)
                lhs_f = 0
            s.ws_last_expr_is_float = 0
            s.ws_last_expr_is_str = 0
        else
            break
    return 0

fn wasm_synth_expr_logical_and s toks pos_box
    // WHY: Pratt level for logical conjunction (and / && / এবং).
    wasm_synth_expr_relational(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        t = toks[p]
        k = t.tok_kind
        txt = t.tok_text
        if k == TOK_AND() or (k != TOK_STR() and (txt == "and" or txt == "&&" or txt == "এবং"))
            list_set(pos_box, 0, p + 1)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
            wasm_synth_expr_relational(s, toks, pos_box)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
            wasm_emit_i64_mul(s.ws_code)
        else
            break
    return 0

fn wasm_synth_expr_logical_or s toks pos_box
    // WHY: Pratt level for logical disjunction (or / || / অথবা).
    wasm_synth_expr_logical_and(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        t = toks[p]
        k = t.tok_kind
        txt = t.tok_text
        if k == TOK_OR() or (k != TOK_STR() and (txt == "or" or txt == "||" or txt == "অথবা"))
            list_set(pos_box, 0, p + 1)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
            wasm_synth_expr_logical_and(s, toks, pos_box)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
            wasm_emit_i64_add(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
        else
            break
    return 0

fn wasm_synth_compile_expr s toks pos_box
    // WHY: Master expression evaluator entering at logical disjunction precedence level.
    return wasm_synth_expr_logical_or(s, toks, pos_box)

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

    // Skip compiler attribute directives (@strict, @fn_strict, @kavach, @freestanding, @attr_*) and `async` fn modifier
    if k == TOK_KW_ASYNC() or (k == TOK_IDENT() and (txt == "async" or txt == "@async" or txt == "@strict" or txt == "@fn_strict" or txt == "@strict_types" or txt == "@strict_ownership" or txt == "@strict_proof" or txt == "@kavach" or txt == "@freestanding" or txt == "@ring0" or txt == "@silicon" or txt == "@packed" or txt == "@naked" or txt == "@interrupt" or str_starts_with(txt, "@attr_") == 1))
        list_set(pos_box, 0, pos + 1)
        return 0
    end

