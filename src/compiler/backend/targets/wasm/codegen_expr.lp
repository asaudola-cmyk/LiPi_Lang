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
    s.ws_var_struct_names = list()
    s.ws_var_struct_types = list()
    s.ws_last_struct = ""
    s.ws_impl_type = ""
    s.ws_next_type_id = 1
    s.ws_source_toks = 0
    s.ws_float_fields = list()
    s.ws_str_fields = list()
    s.ws_float_lists = list()
    s.ws_str_lists = list()
    s.ws_last_expr_is_float_list = 0
    s.ws_last_expr_is_str_list = 0
    return s

fn wasm_synth_set_var_struct s name sname
    i = 0
    while i < s.ws_var_struct_names.len()
        if s.ws_var_struct_names[i] == name
            list_set(s.ws_var_struct_types, i, sname)
            return 0
        end
        i = i + 1
    end
    push(s.ws_var_struct_names, name)
    push(s.ws_var_struct_types, sname)
    return 0

fn wasm_synth_get_var_struct s name
    i = 0
    while i < s.ws_var_struct_names.len()
        if s.ws_var_struct_names[i] == name
            return s.ws_var_struct_types[i]
        end
        i = i + 1
    end
    return ""

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

fn wasm_type_is_float_name tname
    if tname == "float" or tname == "f64" or tname == "f32" or tname == "দশমিক"
        return 1
    end
    return 0
end

fn wasm_type_is_str_name tname
    if tname == "string" or tname == "str" or tname == "স্ট্রিং"
        return 1
    end
    return 0
end

fn wasm_synth_is_float_list s name
    return wasm_list_contains(s.ws_float_lists, name)
end

fn wasm_synth_mark_float_list s name flag
    s.ws_float_lists = wasm_list_set_membership(s.ws_float_lists, name, flag)
    return 0
end

fn wasm_synth_is_str_list s name
    return wasm_list_contains(s.ws_str_lists, name)
end

fn wasm_synth_mark_str_list s name flag
    s.ws_str_lists = wasm_list_set_membership(s.ws_str_lists, name, flag)
    return 0
end

fn wasm_synth_mark_float_field s sname fname
    // WHY: Tracks IEEE-754 float struct fields both per-struct and globally so reads
    // through untyped references still recover float semantics cleanly.
    if sname != ""
        sd = wasm_synth_find_struct(s, sname)
        if sd != 0
            sd.wsd_float_fields = wasm_list_set_membership(sd.wsd_float_fields, fname, 1)
        end
    end
    s.ws_float_fields = wasm_list_set_membership(s.ws_float_fields, fname, 1)
    return 0
end

fn wasm_synth_is_float_field s sname fname
    if sname != ""
        sd = wasm_synth_find_struct(s, sname)
        if sd != 0
            if wasm_list_contains(sd.wsd_float_fields, fname) == 1
                return 1
            end
        end
    end
    return wasm_list_contains(s.ws_float_fields, fname)
end

fn wasm_synth_mark_str_field s sname fname
    if sname != ""
        sd = wasm_synth_find_struct(s, sname)
        if sd != 0
            sd.wsd_str_fields = wasm_list_set_membership(sd.wsd_str_fields, fname, 1)
        end
    end
    s.ws_str_fields = wasm_list_set_membership(s.ws_str_fields, fname, 1)
    return 0
end

fn wasm_synth_is_str_field s sname fname
    if sname != ""
        sd = wasm_synth_find_struct(s, sname)
        if sd != 0
            if wasm_list_contains(sd.wsd_str_fields, fname) == 1
                return 1
            end
        end
    end
    return wasm_list_contains(s.ws_str_fields, fname)
end

fn wasm_synth_find_struct s sname
    si = 0
    while si < s.ws_structs.len()
        sd = s.ws_structs[si]
        if sd.wsd_name == sname
            return sd
        si = si + 1
    return 0

fn wasm_synth_get_field_offset_for s sname fname
    // WHY: Checks exact struct/union definition first (unions always return offset 0),
    // then defined structs, then global field slot table for structural access.
    if sname != ""
        sd0 = wasm_synth_find_struct(s, sname)
        if sd0 != 0
            fi0 = 0
            while fi0 < sd0.wsd_fields.len()
                if sd0.wsd_fields[fi0] == fname
                    if sd0.wsd_is_union == 1
                        return 0
                    end
                    return fi0 * 8
                end
                fi0 = fi0 + 1
            end
        end
    end
    si = 0
    while si < s.ws_structs.len()
        sd = s.ws_structs[si]
        fi = 0
        while fi < sd.wsd_fields.len()
            if sd.wsd_fields[fi] == fname
                if sd.wsd_is_union == 1
                    return 0
                end
                return fi * 8
            end
            fi = fi + 1
        end
        si = si + 1
    end
    gi = 0
    while gi < s.ws_global_fields.len()
        if s.ws_global_fields[gi] == fname
            return gi * 8
        gi = gi + 1
    push(s.ws_global_fields, fname)
    return (s.ws_global_fields.len() - 1) * 8

fn wasm_synth_get_field_offset s fname
    return wasm_synth_get_field_offset_for(s, "", fname)

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
    f.wfn_is_variadic = 0
    f.wfn_def_starts = list()
    f.wfn_returns_float = 0
    f.wfn_returns_str = 0
    f.wfn_param_is_float = list()
    pf_i = 0
    while pf_i < f.wfn_param_count
        push(f.wfn_param_is_float, 0)
        pf_i = pf_i + 1
    end
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

fn wasm_synth_emit_mem_byte_size s
    // WHY: Pushes current linear memory capacity in bytes (memory.size * 65536) as i64.
    // Replaces fixed 256KB limits so pointer/LPST checks stay valid after dynamic memory.grow.
    wasm_emit_memory_size(s.ws_code)
    wasm_emit_i64_extend_i32_u(s.ws_code)
    wasm_emit_i64_const(s.ws_code, 65536)
    wasm_emit_i64_mul(s.ws_code)
    return 0
end

fn wasm_synth_emit_bump_alloc s
    // WHY: Pops [i64 size], aligns up to 8B (min 8B), allocates sequentially via mem[24]
    // starting at 65536 (clear of .rodata at 1024..65535), dynamically invokes `memory.grow`
    // whenever the allocation exceeds current linear memory pages, and pushes allocated i64 ptr.
    l_sz = wasm_synth_alloc_local(s, "__wasi_alloc_sz")
    l_ptr = wasm_synth_alloc_local(s, "__wasi_alloc_ptr")
    l_end = wasm_synth_alloc_local(s, "__wasi_alloc_end")
    l_cap = wasm_synth_alloc_local(s, "__wasi_alloc_cap")
    l_need = wasm_synth_alloc_local(s, "__wasi_alloc_need")

    wasm_emit_local_set(s.ws_code, l_sz)
    wasm_emit_local_get(s.ws_code, l_sz)
    wasm_emit_i64_const(s.ws_code, 8)
    wasm_emit_i64_lt_s(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
    wasm_emit_i64_const(s.ws_code, 8)
    wasm_emit_local_set(s.ws_code, l_sz)
    wasm_emit_else(s.ws_code)
    // WHY: WASM32 linear memory is strictly capped at 4 GiB (65536 pages); trapping requests > 4 GiB
    // prevents i64 alignment overflow and i32.wrap_i64(2^32 == 0) bypasses of memory.grow.
    wasm_emit_local_get(s.ws_code, l_sz)
    wasm_emit_i64_const(s.ws_code, 4294967296)
    wasm_emit_i64_gt_u(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_unreachable(s.ws_code)
    wasm_emit_end(s.ws_code)
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

    wasm_emit_local_get(s.ws_code, l_ptr)
    wasm_emit_local_get(s.ws_code, l_sz)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_local_set(s.ws_code, l_end)

    wasm_synth_emit_mem_byte_size(s)
    wasm_emit_local_set(s.ws_code, l_cap)

    wasm_emit_local_get(s.ws_code, l_end)
    wasm_emit_local_get(s.ws_code, l_cap)
    wasm_emit_i64_gt_u(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_end)
        wasm_emit_local_get(s.ws_code, l_cap)
        wasm_emit_i64_sub(s.ws_code)
        wasm_emit_i64_const(s.ws_code, 65535)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i64_const(s.ws_code, 65536)
        wasm_emit_i64_div_u(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_need)

        wasm_emit_local_get(s.ws_code, l_need)
        wasm_emit_i64_const(s.ws_code, 65535)
        wasm_emit_i64_gt_u(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_unreachable(s.ws_code)
        wasm_emit_end(s.ws_code)

        wasm_emit_local_get(s.ws_code, l_need)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_memory_grow(s.ws_code)
        wasm_emit_i32_const(s.ws_code, 0 - 1)
        wasm_emit_i32_eq(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_unreachable(s.ws_code)
        wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)

    wasm_emit_i32_const(s.ws_code, 24)
    wasm_emit_local_get(s.ws_code, l_end)
    wasm_emit_i64_store(s.ws_code, 3, 0)

    wasm_emit_local_get(s.ws_code, l_ptr)
    return 0

fn wasm_synth_emit_is_lpst_str s l_ptr l_out
    // WHY: Sets l_out = 1 iff l_ptr is an 8B-aligned pointer within [1040, memory.size*65536)
    // preceded by the LPST magic tag at [l_ptr - 16]. Safe even after memory.grow.
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_local_set(s.ws_code, l_out)
    wasm_emit_local_get(s.ws_code, l_ptr)
    wasm_emit_i64_const(s.ws_code, 1040)
    wasm_emit_i64_ge_s(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_ptr)
        wasm_synth_emit_mem_byte_size(s)
        wasm_emit_i64_lt_u(s.ws_code)
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
                    wasm_emit_i64_const(s.ws_code, 1)
                    wasm_emit_local_set(s.ws_code, l_out)
                wasm_emit_end(s.ws_code)
            wasm_emit_end(s.ws_code)
        wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0
end

fn wasm_synth_emit_is_dict_ptr s l_ptr l_out
    // WHY: Sets l_out = 1 iff l_ptr is an 8B-aligned heap pointer whose [ptr+0] == WASM_DICT_MAGIC.
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_local_set(s.ws_code, l_out)
    wasm_emit_local_get(s.ws_code, l_ptr)
    wasm_emit_i64_const(s.ws_code, 65536)
    wasm_emit_i64_ge_s(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_ptr)
        wasm_emit_i64_const(s.ws_code, 32)
        wasm_emit_i64_add(s.ws_code)
        wasm_synth_emit_mem_byte_size(s)
        wasm_emit_i64_lt_u(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_ptr)
            wasm_emit_i64_const(s.ws_code, 7)
            wasm_emit_i64_and(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_eq(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_ptr)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_i64_const(s.ws_code, WASM_DICT_MAGIC)
                wasm_emit_i64_eq(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                    wasm_emit_i64_const(s.ws_code, 1)
                    wasm_emit_local_set(s.ws_code, l_out)
                wasm_emit_end(s.ws_code)
            wasm_emit_end(s.ws_code)
        wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0
end

fn wasm_synth_emit_str_len_into s l_ptr l_out
    // WHY: Reads string length into l_out (i64) from [l_ptr - 8] if tagged with LPST magic, else 0.
    l_is = wasm_synth_alloc_local(s, "__wasi_sl_is")
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_local_set(s.ws_code, l_out)
    wasm_synth_emit_is_lpst_str(s, l_ptr, l_is)
    wasm_emit_local_get(s.ws_code, l_is)
    wasm_emit_i64_const(s.ws_code, 1)
    wasm_emit_i64_eq(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_ptr)
        wasm_emit_i64_const(s.ws_code, 8)
        wasm_emit_i64_sub(s.ws_code)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 0)
        wasm_emit_local_set(s.ws_code, l_out)
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
    // WHY: Dispatches len() cleanly across LPST strings ([ptr - 8]), dicts ([ptr + 8]),
    // and lists ([ptr + 0]), guarded by dynamic memory.size bounds.
    l_is_str = wasm_synth_alloc_local(s, "__wasi_len_iss")
    l_is_dct = wasm_synth_alloc_local(s, "__wasi_len_isd")
    wasm_synth_emit_is_lpst_str(s, l_ptr, l_is_str)
    wasm_emit_local_get(s.ws_code, l_is_str)
    wasm_emit_i64_const(s.ws_code, 1)
    wasm_emit_i64_eq(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_I64)
        wasm_emit_local_get(s.ws_code, l_ptr)
        wasm_emit_i64_const(s.ws_code, 8)
        wasm_emit_i64_sub(s.ws_code)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 0)
    wasm_emit_else(s.ws_code)
        wasm_synth_emit_is_dict_ptr(s, l_ptr, l_is_dct)
        wasm_emit_local_get(s.ws_code, l_is_dct)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_eq(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_I64)
            wasm_emit_local_get(s.ws_code, l_ptr)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_load(s.ws_code, 3, 8)
        wasm_emit_else(s.ws_code)
            wasm_emit_local_get(s.ws_code, l_ptr)
            wasm_emit_i64_const(s.ws_code, 24)
            wasm_emit_i64_ge_s(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_I64)
                wasm_emit_local_get(s.ws_code, l_ptr)
                wasm_synth_emit_mem_byte_size(s)
                wasm_emit_i64_lt_u(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_I64)
                    wasm_emit_local_get(s.ws_code, l_ptr)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_else(s.ws_code)
                    wasm_emit_i64_const(s.ws_code, 0)
                wasm_emit_end(s.ws_code)
            wasm_emit_else(s.ws_code)
                wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_end(s.ws_code)
        wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0

fn wasm_synth_emit_ensure_lpst_str s
    // WHY: Pops an i64 from stack; if it is already an LPST-tagged string pointer, returns it unchanged,
    // otherwise formats the signed i64 decimal into a fresh bump-allocated LPST string on linear heap.
    l_v = wasm_synth_alloc_local(s, "__wasi_its_v")
    l_is = wasm_synth_alloc_local(s, "__wasi_its_is")
    l_neg = wasm_synth_alloc_local(s, "__wasi_its_neg")
    l_pos = wasm_synth_alloc_local(s, "__wasi_its_pos")
    l_dig = wasm_synth_alloc_local(s, "__wasi_its_dig")
    l_len = wasm_synth_alloc_local(s, "__wasi_its_len")
    l_buf = wasm_synth_alloc_local(s, "__wasi_its_buf")
    l_dst = wasm_synth_alloc_local(s, "__wasi_its_dst")

    wasm_emit_local_set(s.ws_code, l_v)
    wasm_synth_emit_is_lpst_str(s, l_v, l_is)

    wasm_emit_local_get(s.ws_code, l_is)
    wasm_emit_i64_const(s.ws_code, 1)
    wasm_emit_i64_eq(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_I64)
        wasm_emit_local_get(s.ws_code, l_v)
    wasm_emit_else(s.ws_code)
        // Format decimal ASCII digits backwards into scratch mem[64..95]
        wasm_emit_i64_const(s.ws_code, 96)
        wasm_emit_local_set(s.ws_code, l_pos)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_local_set(s.ws_code, l_neg)
        wasm_emit_local_get(s.ws_code, l_v)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_i64_lt_s(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_local_set(s.ws_code, l_neg)
        wasm_emit_end(s.ws_code)

        wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_pos)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_i64_sub(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_pos)

            wasm_emit_local_get(s.ws_code, l_v)
            wasm_emit_i64_const(s.ws_code, 10)
            wasm_emit_i64_rem_s(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_dig)
            wasm_emit_local_get(s.ws_code, l_dig)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_lt_s(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_i64_const(s.ws_code, 0)
                wasm_emit_local_get(s.ws_code, l_dig)
                wasm_emit_i64_sub(s.ws_code)
                wasm_emit_local_set(s.ws_code, l_dig)
            wasm_emit_end(s.ws_code)

            wasm_emit_local_get(s.ws_code, l_pos)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_local_get(s.ws_code, l_dig)
            wasm_emit_i64_const(s.ws_code, 48)
            wasm_emit_i64_add(s.ws_code)
            wasm_emit_i64_store8(s.ws_code, 0, 0)

            wasm_emit_local_get(s.ws_code, l_v)
            wasm_emit_i64_const(s.ws_code, 10)
            wasm_emit_i64_div_s(s.ws_code)
            wasm_emit_local_tee(s.ws_code, l_v)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_br_if(s.ws_code, 0)
        wasm_emit_end(s.ws_code)

        wasm_emit_local_get(s.ws_code, l_neg)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_eq(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_pos)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_i64_sub(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_pos)
            wasm_emit_local_get(s.ws_code, l_pos)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 45)
            wasm_emit_i64_store8(s.ws_code, 0, 0)
        wasm_emit_end(s.ws_code)

        wasm_emit_i64_const(s.ws_code, 96)
        wasm_emit_local_get(s.ws_code, l_pos)
        wasm_emit_i64_sub(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_len)

        wasm_emit_local_get(s.ws_code, l_len)
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
        wasm_emit_local_get(s.ws_code, l_len)
        wasm_emit_i64_store(s.ws_code, 3, 8)

        wasm_emit_local_get(s.ws_code, l_buf)
        wasm_emit_i64_const(s.ws_code, 16)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_dst)
        wasm_synth_emit_copy_bytes(s, l_dst, l_pos, l_len)

        wasm_emit_local_get(s.ws_code, l_dst)
        wasm_emit_local_get(s.ws_code, l_len)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_i64_store8(s.ws_code, 0, 0)

        wasm_emit_local_get(s.ws_code, l_dst)
    wasm_emit_end(s.ws_code)
    s.ws_last_expr_is_str = 1
    s.ws_last_expr_is_float = 0
    return 0

fn wasm_synth_emit_append_u64_to_wpos s l_num l_wpos
    // WHY: Formats unsigned i64 l_num into scratch [256..319] in reverse, then appends forward into l_wpos.
    l_rpos = wasm_synth_alloc_local(s, "__wasi_fu_rpos")
    l_cur = wasm_synth_alloc_local(s, "__wasi_fu_cur")
    wasm_emit_local_get(s.ws_code, l_num)
    wasm_emit_local_set(s.ws_code, l_cur)
    wasm_emit_i64_const(s.ws_code, 320)
    wasm_emit_local_set(s.ws_code, l_rpos)
    wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_rpos)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_sub(s.ws_code)
        wasm_emit_local_tee(s.ws_code, l_rpos)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_cur)
        wasm_emit_i64_const(s.ws_code, 10)
        wasm_emit_i64_rem_u(s.ws_code)
        wasm_emit_i64_const(s.ws_code, 48)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i64_store8(s.ws_code, 0, 0)

        wasm_emit_local_get(s.ws_code, l_cur)
        wasm_emit_i64_const(s.ws_code, 10)
        wasm_emit_i64_div_u(s.ws_code)
        wasm_emit_local_tee(s.ws_code, l_cur)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_i64_ne(s.ws_code)
        wasm_emit_br_if(s.ws_code, 0)
    wasm_emit_end(s.ws_code)
    wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
    wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_rpos)
        wasm_emit_i64_const(s.ws_code, 320)
        wasm_emit_i64_ge_s(s.ws_code)
        wasm_emit_br_if(s.ws_code, 1)
        wasm_emit_local_get(s.ws_code, l_wpos)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_rpos)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load8_u(s.ws_code, 0, 0)
        wasm_emit_i64_store8(s.ws_code, 0, 0)
        wasm_emit_local_get(s.ws_code, l_wpos)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_wpos)
        wasm_emit_local_get(s.ws_code, l_rpos)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_rpos)
        wasm_emit_br(s.ws_code, 0)
    wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0
end

fn wasm_synth_emit_append_fixed_digits_to_wpos s l_num l_ndig l_wpos
    // WHY: Formats exactly l_ndig decimal digits of l_num with leading-zero padding (e.g. .005).
    l_rpos = wasm_synth_alloc_local(s, "__wasi_ff_rpos")
    l_cur = wasm_synth_alloc_local(s, "__wasi_ff_cur")
    l_cnt = wasm_synth_alloc_local(s, "__wasi_ff_cnt")
    wasm_emit_local_get(s.ws_code, l_num)
    wasm_emit_local_set(s.ws_code, l_cur)
    wasm_emit_local_get(s.ws_code, l_ndig)
    wasm_emit_local_set(s.ws_code, l_cnt)
    wasm_emit_i64_const(s.ws_code, 320)
    wasm_emit_local_set(s.ws_code, l_rpos)
    wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_rpos)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_sub(s.ws_code)
        wasm_emit_local_tee(s.ws_code, l_rpos)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_cur)
        wasm_emit_i64_const(s.ws_code, 10)
        wasm_emit_i64_rem_u(s.ws_code)
        wasm_emit_i64_const(s.ws_code, 48)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i64_store8(s.ws_code, 0, 0)

        wasm_emit_local_get(s.ws_code, l_cur)
        wasm_emit_i64_const(s.ws_code, 10)
        wasm_emit_i64_div_u(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_cur)

        wasm_emit_local_get(s.ws_code, l_cnt)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_sub(s.ws_code)
        wasm_emit_local_tee(s.ws_code, l_cnt)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_i64_gt_s(s.ws_code)
        wasm_emit_br_if(s.ws_code, 0)
    wasm_emit_end(s.ws_code)
    wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
    wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_rpos)
        wasm_emit_i64_const(s.ws_code, 320)
        wasm_emit_i64_ge_s(s.ws_code)
        wasm_emit_br_if(s.ws_code, 1)
        wasm_emit_local_get(s.ws_code, l_wpos)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_rpos)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load8_u(s.ws_code, 0, 0)
        wasm_emit_i64_store8(s.ws_code, 0, 0)
        wasm_emit_local_get(s.ws_code, l_wpos)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_wpos)
        wasm_emit_local_get(s.ws_code, l_rpos)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_rpos)
        wasm_emit_br(s.ws_code, 0)
    wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0
end

fn wasm_synth_emit_format_f64_to_scratch s l_bits l_out_len
    // WHY: Formats IEEE-754 binary64 bits in l_bits into ASCII decimal text at scratch mem[128..255],
    // setting l_out_len to byte length. Matches x86_64/ARM64/RV64 formatting (NaN, Inf, -Inf, -0.0,
    // up to 6 fractional digits with trailing-zero trimming & scientific notation for extreme scales).
    l_abs = wasm_synth_alloc_local(s, "__wasi_f_abs")
    l_wpos = wasm_synth_alloc_local(s, "__wasi_f_wpos")
    l_esgn = wasm_synth_alloc_local(s, "__wasi_f_esgn")
    l_eval = wasm_synth_alloc_local(s, "__wasi_f_eval")
    l_fb = wasm_synth_alloc_local(s, "__wasi_f_fb")
    l_ip = wasm_synth_alloc_local(s, "__wasi_f_ip")
    l_fr = wasm_synth_alloc_local(s, "__wasi_f_fr")
    l_fd = wasm_synth_alloc_local(s, "__wasi_f_fd")

    b_1e18 = wasm_parse_float_bits("1e18")
    b_1e16 = wasm_parse_float_bits("1e16")
    b_10 = wasm_parse_float_bits("10.0")
    b_1e_6 = wasm_parse_float_bits("1e-6")
    b_1e_16 = wasm_parse_float_bits("1e-16")
    b_1 = wasm_parse_float_bits("1.0")
    b_1e6 = wasm_parse_float_bits("1000000.0")
    b_half = wasm_parse_float_bits("0.5")

    wasm_emit_i64_const(s.ws_code, 128)
    wasm_emit_local_set(s.ws_code, l_wpos)

    // Strip sign bit: l_abs = l_bits & 0x7FFFFFFFFFFFFFFF
    wasm_emit_local_get(s.ws_code, l_bits)
    wasm_emit_i64_const(s.ws_code, 9223372036854775807)
    wasm_emit_i64_and(s.ws_code)
    wasm_emit_local_set(s.ws_code, l_abs)

    // NaN check: l_abs > 0x7FF0000000000000 (9218868437227405312)
    wasm_emit_local_get(s.ws_code, l_abs)
    wasm_emit_i64_const(s.ws_code, 9218868437227405312)
    wasm_emit_i64_gt_s(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_i32_const(s.ws_code, 128)
        wasm_emit_i64_const(s.ws_code, 78)
        wasm_emit_i64_store8(s.ws_code, 0, 0)
        wasm_emit_i32_const(s.ws_code, 129)
        wasm_emit_i64_const(s.ws_code, 97)
        wasm_emit_i64_store8(s.ws_code, 0, 0)
        wasm_emit_i32_const(s.ws_code, 130)
        wasm_emit_i64_const(s.ws_code, 78)
        wasm_emit_i64_store8(s.ws_code, 0, 0)
        wasm_emit_i64_const(s.ws_code, 131)
        wasm_emit_local_set(s.ws_code, l_wpos)
    wasm_emit_else(s.ws_code)
        // Inf check: l_abs == 0x7FF0000000000000
        wasm_emit_local_get(s.ws_code, l_abs)
        wasm_emit_i64_const(s.ws_code, 9218868437227405312)
        wasm_emit_i64_eq(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_bits)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_lt_s(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_wpos)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_const(s.ws_code, 45)
                wasm_emit_i64_store8(s.ws_code, 0, 0)
                wasm_emit_local_get(s.ws_code, l_wpos)
                wasm_emit_i64_const(s.ws_code, 1)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_local_set(s.ws_code, l_wpos)
            wasm_emit_end(s.ws_code)
            wasm_emit_local_get(s.ws_code, l_wpos)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 73)
            wasm_emit_i64_store8(s.ws_code, 0, 0)
            wasm_emit_local_get(s.ws_code, l_wpos)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 110)
            wasm_emit_i64_store8(s.ws_code, 0, 1)
            wasm_emit_local_get(s.ws_code, l_wpos)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 102)
            wasm_emit_i64_store8(s.ws_code, 0, 2)
            wasm_emit_local_get(s.ws_code, l_wpos)
            wasm_emit_i64_const(s.ws_code, 3)
            wasm_emit_i64_add(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_wpos)
        wasm_emit_else(s.ws_code)
            // Finite float: emit '-' if sign bit is set (including -0.0)
            wasm_emit_local_get(s.ws_code, l_bits)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_lt_s(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_wpos)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_const(s.ws_code, 45)
                wasm_emit_i64_store8(s.ws_code, 0, 0)
                wasm_emit_local_get(s.ws_code, l_wpos)
                wasm_emit_i64_const(s.ws_code, 1)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_local_set(s.ws_code, l_wpos)
            wasm_emit_end(s.ws_code)

            wasm_emit_local_get(s.ws_code, l_abs)
            wasm_emit_local_set(s.ws_code, l_fb)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_local_set(s.ws_code, l_esgn)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_local_set(s.ws_code, l_eval)

            wasm_emit_local_get(s.ws_code, l_abs)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                // |x| >= 1e18 -> scale down to [1, 10) with positive exponent
                wasm_emit_local_get(s.ws_code, l_fb)
                wasm_emit_f64_reinterpret_i64(s.ws_code)
                wasm_emit_i64_const(s.ws_code, b_1e18)
                wasm_emit_f64_reinterpret_i64(s.ws_code)
                wasm_emit_f64_ge(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                    wasm_emit_i64_const(s.ws_code, 1)
                    wasm_emit_local_set(s.ws_code, l_esgn)
                    wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
                    wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
                        wasm_emit_local_get(s.ws_code, l_fb)
                        wasm_emit_f64_reinterpret_i64(s.ws_code)
                        wasm_emit_i64_const(s.ws_code, b_1e16)
                        wasm_emit_f64_reinterpret_i64(s.ws_code)
                        wasm_emit_f64_lt(s.ws_code)
                        wasm_emit_br_if(s.ws_code, 1)
                        wasm_emit_local_get(s.ws_code, l_fb)
                        wasm_emit_f64_reinterpret_i64(s.ws_code)
                        wasm_emit_i64_const(s.ws_code, b_1e16)
                        wasm_emit_f64_reinterpret_i64(s.ws_code)
                        wasm_emit_f64_div(s.ws_code)
                        wasm_emit_i64_reinterpret_f64(s.ws_code)
                        wasm_emit_local_set(s.ws_code, l_fb)
                        wasm_emit_local_get(s.ws_code, l_eval)
                        wasm_emit_i64_const(s.ws_code, 16)
                        wasm_emit_i64_add(s.ws_code)
                        wasm_emit_local_set(s.ws_code, l_eval)
                        wasm_emit_br(s.ws_code, 0)
                    wasm_emit_end(s.ws_code)
                    wasm_emit_end(s.ws_code)
                    wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
                    wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
                        wasm_emit_local_get(s.ws_code, l_fb)
                        wasm_emit_f64_reinterpret_i64(s.ws_code)
                        wasm_emit_i64_const(s.ws_code, b_10)
                        wasm_emit_f64_reinterpret_i64(s.ws_code)
                        wasm_emit_f64_lt(s.ws_code)
                        wasm_emit_br_if(s.ws_code, 1)
                        wasm_emit_local_get(s.ws_code, l_fb)
                        wasm_emit_f64_reinterpret_i64(s.ws_code)
                        wasm_emit_i64_const(s.ws_code, b_10)
                        wasm_emit_f64_reinterpret_i64(s.ws_code)
                        wasm_emit_f64_div(s.ws_code)
                        wasm_emit_i64_reinterpret_f64(s.ws_code)
                        wasm_emit_local_set(s.ws_code, l_fb)
                        wasm_emit_local_get(s.ws_code, l_eval)
                        wasm_emit_i64_const(s.ws_code, 1)
                        wasm_emit_i64_add(s.ws_code)
                        wasm_emit_local_set(s.ws_code, l_eval)
                        wasm_emit_br(s.ws_code, 0)
                    wasm_emit_end(s.ws_code)
                    wasm_emit_end(s.ws_code)
                wasm_emit_else(s.ws_code)
                    // 0 < |x| < 1e-6 -> scale up to [1, 10) with negative exponent
                    wasm_emit_local_get(s.ws_code, l_fb)
                    wasm_emit_f64_reinterpret_i64(s.ws_code)
                    wasm_emit_i64_const(s.ws_code, b_1e_6)
                    wasm_emit_f64_reinterpret_i64(s.ws_code)
                    wasm_emit_f64_lt(s.ws_code)
                    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                        wasm_emit_i64_const(s.ws_code, 0 - 1)
                        wasm_emit_local_set(s.ws_code, l_esgn)
                        wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
                        wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
                            wasm_emit_local_get(s.ws_code, l_fb)
                            wasm_emit_f64_reinterpret_i64(s.ws_code)
                            wasm_emit_i64_const(s.ws_code, b_1e_16)
                            wasm_emit_f64_reinterpret_i64(s.ws_code)
                            wasm_emit_f64_ge(s.ws_code)
                            wasm_emit_br_if(s.ws_code, 1)
                            wasm_emit_local_get(s.ws_code, l_fb)
                            wasm_emit_f64_reinterpret_i64(s.ws_code)
                            wasm_emit_i64_const(s.ws_code, b_1e16)
                            wasm_emit_f64_reinterpret_i64(s.ws_code)
                            wasm_emit_f64_mul(s.ws_code)
                            wasm_emit_i64_reinterpret_f64(s.ws_code)
                            wasm_emit_local_set(s.ws_code, l_fb)
                            wasm_emit_local_get(s.ws_code, l_eval)
                            wasm_emit_i64_const(s.ws_code, 16)
                            wasm_emit_i64_add(s.ws_code)
                            wasm_emit_local_set(s.ws_code, l_eval)
                            wasm_emit_br(s.ws_code, 0)
                        wasm_emit_end(s.ws_code)
                        wasm_emit_end(s.ws_code)
                        wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
                        wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
                            wasm_emit_local_get(s.ws_code, l_fb)
                            wasm_emit_f64_reinterpret_i64(s.ws_code)
                            wasm_emit_i64_const(s.ws_code, b_1)
                            wasm_emit_f64_reinterpret_i64(s.ws_code)
                            wasm_emit_f64_ge(s.ws_code)
                            wasm_emit_br_if(s.ws_code, 1)
                            wasm_emit_local_get(s.ws_code, l_fb)
                            wasm_emit_f64_reinterpret_i64(s.ws_code)
                            wasm_emit_i64_const(s.ws_code, b_10)
                            wasm_emit_f64_reinterpret_i64(s.ws_code)
                            wasm_emit_f64_mul(s.ws_code)
                            wasm_emit_i64_reinterpret_f64(s.ws_code)
                            wasm_emit_local_set(s.ws_code, l_fb)
                            wasm_emit_local_get(s.ws_code, l_eval)
                            wasm_emit_i64_const(s.ws_code, 1)
                            wasm_emit_i64_add(s.ws_code)
                            wasm_emit_local_set(s.ws_code, l_eval)
                            wasm_emit_br(s.ws_code, 0)
                        wasm_emit_end(s.ws_code)
                        wasm_emit_end(s.ws_code)
                    wasm_emit_end(s.ws_code)
                wasm_emit_end(s.ws_code)
            wasm_emit_end(s.ws_code)

            // Integer part = i64.trunc_f64_s(f), frac = i64.trunc_f64_s((f - ip) * 1e6 + 0.5)
            wasm_emit_local_get(s.ws_code, l_fb)
            wasm_emit_f64_reinterpret_i64(s.ws_code)
            wasm_emit_i64_trunc_f64_s(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_ip)

            wasm_emit_local_get(s.ws_code, l_fb)
            wasm_emit_f64_reinterpret_i64(s.ws_code)
            wasm_emit_local_get(s.ws_code, l_ip)
            wasm_emit_f64_convert_i64_s(s.ws_code)
            wasm_emit_f64_sub(s.ws_code)
            wasm_emit_i64_const(s.ws_code, b_1e6)
            wasm_emit_f64_reinterpret_i64(s.ws_code)
            wasm_emit_f64_mul(s.ws_code)
            wasm_emit_i64_const(s.ws_code, b_half)
            wasm_emit_f64_reinterpret_i64(s.ws_code)
            wasm_emit_f64_add(s.ws_code)
            wasm_emit_i64_trunc_f64_s(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_fr)

            // Carry rounding overflow into integer part
            wasm_emit_local_get(s.ws_code, l_fr)
            wasm_emit_i64_const(s.ws_code, 1000000)
            wasm_emit_i64_ge_s(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_ip)
                wasm_emit_i64_const(s.ws_code, 1)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_local_set(s.ws_code, l_ip)
                wasm_emit_i64_const(s.ws_code, 0)
                wasm_emit_local_set(s.ws_code, l_fr)
            wasm_emit_end(s.ws_code)

            // Emit integer digits + '.'
            wasm_synth_emit_append_u64_to_wpos(s, l_ip, l_wpos)
            wasm_emit_local_get(s.ws_code, l_wpos)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 46)
            wasm_emit_i64_store8(s.ws_code, 0, 0)
            wasm_emit_local_get(s.ws_code, l_wpos)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_i64_add(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_wpos)

            // Emit fractional digits with trailing zeros trimmed (or single '0' if zero)
            wasm_emit_local_get(s.ws_code, l_fr)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_eq(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_wpos)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_const(s.ws_code, 48)
                wasm_emit_i64_store8(s.ws_code, 0, 0)
                wasm_emit_local_get(s.ws_code, l_wpos)
                wasm_emit_i64_const(s.ws_code, 1)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_local_set(s.ws_code, l_wpos)
            wasm_emit_else(s.ws_code)
                wasm_emit_i64_const(s.ws_code, 6)
                wasm_emit_local_set(s.ws_code, l_fd)
                wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
                    wasm_emit_local_get(s.ws_code, l_fr)
                    wasm_emit_i64_const(s.ws_code, 10)
                    wasm_emit_i64_rem_u(s.ws_code)
                    wasm_emit_i64_const(s.ws_code, 0)
                    wasm_emit_i64_ne(s.ws_code)
                    wasm_emit_br_if(s.ws_code, 1)
                    wasm_emit_local_get(s.ws_code, l_fr)
                    wasm_emit_i64_const(s.ws_code, 10)
                    wasm_emit_i64_div_u(s.ws_code)
                    wasm_emit_local_set(s.ws_code, l_fr)
                    wasm_emit_local_get(s.ws_code, l_fd)
                    wasm_emit_i64_const(s.ws_code, 1)
                    wasm_emit_i64_sub(s.ws_code)
                    wasm_emit_local_set(s.ws_code, l_fd)
                    wasm_emit_br(s.ws_code, 0)
                wasm_emit_end(s.ws_code)
                wasm_emit_end(s.ws_code)
                wasm_synth_emit_append_fixed_digits_to_wpos(s, l_fr, l_fd, l_wpos)
            wasm_emit_end(s.ws_code)

            // Emit scientific exponent e+N / e-N if scaled
            wasm_emit_local_get(s.ws_code, l_esgn)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_wpos)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_const(s.ws_code, 101)
                wasm_emit_i64_store8(s.ws_code, 0, 0)
                wasm_emit_local_get(s.ws_code, l_wpos)
                wasm_emit_i64_const(s.ws_code, 1)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_local_set(s.ws_code, l_wpos)

                wasm_emit_local_get(s.ws_code, l_esgn)
                wasm_emit_i64_const(s.ws_code, 0)
                wasm_emit_i64_gt_s(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                    wasm_emit_local_get(s.ws_code, l_wpos)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_const(s.ws_code, 43)
                    wasm_emit_i64_store8(s.ws_code, 0, 0)
                wasm_emit_else(s.ws_code)
                    wasm_emit_local_get(s.ws_code, l_wpos)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_i64_const(s.ws_code, 45)
                    wasm_emit_i64_store8(s.ws_code, 0, 0)
                wasm_emit_end(s.ws_code)
                wasm_emit_local_get(s.ws_code, l_wpos)
                wasm_emit_i64_const(s.ws_code, 1)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_local_set(s.ws_code, l_wpos)

                wasm_synth_emit_append_u64_to_wpos(s, l_eval, l_wpos)
            wasm_emit_end(s.ws_code)
        wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)

    wasm_emit_local_get(s.ws_code, l_wpos)
    wasm_emit_i64_const(s.ws_code, 128)
    wasm_emit_i64_sub(s.ws_code)
    wasm_emit_local_set(s.ws_code, l_out_len)
    return 0
end

fn wasm_synth_emit_float_to_lpst_str s
    // WHY: Pops IEEE-754 f64 bits (i64), formats to scratch [128..], copies into a heap LPST string.
    l_fbits = wasm_synth_alloc_local(s, "__wasi_fts_b")
    l_flen = wasm_synth_alloc_local(s, "__wasi_fts_len")
    l_fbuf = wasm_synth_alloc_local(s, "__wasi_fts_buf")
    l_fdst = wasm_synth_alloc_local(s, "__wasi_fts_dst")
    l_fsrc = wasm_synth_alloc_local(s, "__wasi_fts_src")

    wasm_emit_local_set(s.ws_code, l_fbits)
    wasm_synth_emit_format_f64_to_scratch(s, l_fbits, l_flen)

    wasm_emit_local_get(s.ws_code, l_flen)
    wasm_emit_i64_const(s.ws_code, 24)
    wasm_emit_i64_add(s.ws_code)
    wasm_synth_emit_bump_alloc(s)
    wasm_emit_local_set(s.ws_code, l_fbuf)

    wasm_emit_local_get(s.ws_code, l_fbuf)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_const(s.ws_code, 1280332628)
    wasm_emit_i64_store(s.ws_code, 3, 0)

    wasm_emit_local_get(s.ws_code, l_fbuf)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_local_get(s.ws_code, l_flen)
    wasm_emit_i64_store(s.ws_code, 3, 8)

    wasm_emit_local_get(s.ws_code, l_fbuf)
    wasm_emit_i64_const(s.ws_code, 16)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_local_set(s.ws_code, l_fdst)
    wasm_emit_i64_const(s.ws_code, 128)
    wasm_emit_local_set(s.ws_code, l_fsrc)
    wasm_synth_emit_copy_bytes(s, l_fdst, l_fsrc, l_flen)

    wasm_emit_local_get(s.ws_code, l_fdst)
    wasm_emit_local_get(s.ws_code, l_flen)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_i64_store8(s.ws_code, 0, 0)

    wasm_emit_local_get(s.ws_code, l_fdst)
    s.ws_last_expr_is_str = 1
    s.ws_last_expr_is_float = 0
    return 0
end

fn wasm_synth_emit_val_eq s l_a l_b l_out
    // WHY: Value-aware equality for WASM i64 values and LPST strings.
    // Fast-paths pointer/int identity (a == b), then compares LPST string lengths and bytes
    // when both operands carry the LPST header magic so ("ab" + "c") == "abc" evaluates to 1.
    l_isa = wasm_synth_alloc_local(s, "__wasi_veq_isa")
    l_isb = wasm_synth_alloc_local(s, "__wasi_veq_isb")
    l_la = wasm_synth_alloc_local(s, "__wasi_veq_la")
    l_lb = wasm_synth_alloc_local(s, "__wasi_veq_lb")
    l_i = wasm_synth_alloc_local(s, "__wasi_veq_i")

    wasm_emit_local_get(s.ws_code, l_a)
    wasm_emit_local_get(s.ws_code, l_b)
    wasm_emit_i64_eq(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_local_set(s.ws_code, l_out)
    wasm_emit_else(s.ws_code)
        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_local_set(s.ws_code, l_out)
        wasm_synth_emit_is_lpst_str(s, l_a, l_isa)
        wasm_emit_local_get(s.ws_code, l_isa)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_eq(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_synth_emit_is_lpst_str(s, l_b, l_isb)
            wasm_emit_local_get(s.ws_code, l_isb)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_i64_eq(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_a)
                wasm_emit_i64_const(s.ws_code, 8)
                wasm_emit_i64_sub(s.ws_code)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_local_set(s.ws_code, l_la)

                wasm_emit_local_get(s.ws_code, l_b)
                wasm_emit_i64_const(s.ws_code, 8)
                wasm_emit_i64_sub(s.ws_code)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_local_set(s.ws_code, l_lb)

                wasm_emit_local_get(s.ws_code, l_la)
                wasm_emit_local_get(s.ws_code, l_lb)
                wasm_emit_i64_eq(s.ws_code)
                wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                    wasm_emit_i64_const(s.ws_code, 1)
                    wasm_emit_local_set(s.ws_code, l_out)
                    wasm_emit_i64_const(s.ws_code, 0)
                    wasm_emit_local_set(s.ws_code, l_i)
                    wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
                    wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
                        wasm_emit_local_get(s.ws_code, l_i)
                        wasm_emit_local_get(s.ws_code, l_la)
                        wasm_emit_i64_ge_s(s.ws_code)
                        wasm_emit_br_if(s.ws_code, 1)

                        wasm_emit_local_get(s.ws_code, l_a)
                        wasm_emit_local_get(s.ws_code, l_i)
                        wasm_emit_i64_add(s.ws_code)
                        wasm_emit_i32_wrap_i64(s.ws_code)
                        wasm_emit_i64_load8_u(s.ws_code, 0, 0)

                        wasm_emit_local_get(s.ws_code, l_b)
                        wasm_emit_local_get(s.ws_code, l_i)
                        wasm_emit_i64_add(s.ws_code)
                        wasm_emit_i32_wrap_i64(s.ws_code)
                        wasm_emit_i64_load8_u(s.ws_code, 0, 0)

                        wasm_emit_i64_ne(s.ws_code)
                        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                            wasm_emit_i64_const(s.ws_code, 0)
                            wasm_emit_local_set(s.ws_code, l_out)
                            wasm_emit_br(s.ws_code, 2)
                        wasm_emit_end(s.ws_code)

                        wasm_emit_local_get(s.ws_code, l_i)
                        wasm_emit_i64_const(s.ws_code, 1)
                        wasm_emit_i64_add(s.ws_code)
                        wasm_emit_local_set(s.ws_code, l_i)
                        wasm_emit_br(s.ws_code, 0)
                    wasm_emit_end(s.ws_code)
                    wasm_emit_end(s.ws_code)
                wasm_emit_end(s.ws_code)
            wasm_emit_end(s.ws_code)
        wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0
end

fn wasm_synth_emit_dict_new s
    // WHY: Allocates a tagged linear-memory dict header:
    //   [hdr+0]=WASM_DICT_MAGIC, [hdr+8]=count(0), [hdr+16]=cap(16), [hdr+24]=entries_ptr(hdr+32).
    // Pushes hdr (i64) onto stack.
    l_hdr = wasm_synth_alloc_local(s, "__wasi_dnew_hdr")
    wasm_emit_i64_const(s.ws_code, 288)
    wasm_synth_emit_bump_alloc(s)
    wasm_emit_local_set(s.ws_code, l_hdr)

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_const(s.ws_code, WASM_DICT_MAGIC)
    wasm_emit_i64_store(s.ws_code, 3, 0)

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_i64_store(s.ws_code, 3, 8)

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_const(s.ws_code, 16)
    wasm_emit_i64_store(s.ws_code, 3, 16)

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i64_const(s.ws_code, 32)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_i64_store(s.ws_code, 3, 24)

    wasm_emit_local_get(s.ws_code, l_hdr)
    return 0
end

fn wasm_synth_emit_dict_set s l_hdr l_key l_val
    // WHY: Updates existing key in linear-memory dict or inserts new (key, val) pair,
    // dynamically doubling entry table capacity via bump_alloc + memory.grow when full.
    l_cnt = wasm_synth_alloc_local(s, "__wasi_ds_cnt")
    l_cap = wasm_synth_alloc_local(s, "__wasi_ds_cap")
    l_ent = wasm_synth_alloc_local(s, "__wasi_ds_ent")
    l_i = wasm_synth_alloc_local(s, "__wasi_ds_i")
    l_ek = wasm_synth_alloc_local(s, "__wasi_ds_ek")
    l_eq = wasm_synth_alloc_local(s, "__wasi_ds_eq")
    l_fnd = wasm_synth_alloc_local(s, "__wasi_ds_fnd")
    l_ncap = wasm_synth_alloc_local(s, "__wasi_ds_ncap")
    l_nent = wasm_synth_alloc_local(s, "__wasi_ds_nent")
    l_cbytes = wasm_synth_alloc_local(s, "__wasi_ds_cb")

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_load(s.ws_code, 3, 8)
    wasm_emit_local_set(s.ws_code, l_cnt)

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_load(s.ws_code, 3, 16)
    wasm_emit_local_set(s.ws_code, l_cap)

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_load(s.ws_code, 3, 24)
    wasm_emit_local_set(s.ws_code, l_ent)

    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_local_set(s.ws_code, l_fnd)
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_local_set(s.ws_code, l_i)

    wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
    wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_i)
        wasm_emit_local_get(s.ws_code, l_cnt)
        wasm_emit_i64_ge_s(s.ws_code)
        wasm_emit_br_if(s.ws_code, 1)

        wasm_emit_local_get(s.ws_code, l_ent)
        wasm_emit_local_get(s.ws_code, l_i)
        wasm_emit_i64_const(s.ws_code, 16)
        wasm_emit_i64_mul(s.ws_code)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 0)
        wasm_emit_local_set(s.ws_code, l_ek)

        wasm_synth_emit_val_eq(s, l_ek, l_key, l_eq)
        wasm_emit_local_get(s.ws_code, l_eq)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_eq(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_ent)
            wasm_emit_local_get(s.ws_code, l_i)
            wasm_emit_i64_const(s.ws_code, 16)
            wasm_emit_i64_mul(s.ws_code)
            wasm_emit_i64_add(s.ws_code)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_local_get(s.ws_code, l_val)
            wasm_emit_i64_store(s.ws_code, 3, 8)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_local_set(s.ws_code, l_fnd)
            wasm_emit_br(s.ws_code, 2)
        wasm_emit_end(s.ws_code)

        wasm_emit_local_get(s.ws_code, l_i)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_i)
        wasm_emit_br(s.ws_code, 0)
    wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)

    wasm_emit_local_get(s.ws_code, l_fnd)
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_i64_eq(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_cnt)
        wasm_emit_local_get(s.ws_code, l_cap)
        wasm_emit_i64_ge_s(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_cap)
            wasm_emit_i64_const(s.ws_code, 2)
            wasm_emit_i64_mul(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_ncap)
            wasm_emit_local_get(s.ws_code, l_ncap)
            wasm_emit_i64_const(s.ws_code, 16)
            wasm_emit_i64_lt_s(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_i64_const(s.ws_code, 16)
                wasm_emit_local_set(s.ws_code, l_ncap)
            wasm_emit_end(s.ws_code)

            wasm_emit_local_get(s.ws_code, l_ncap)
            wasm_emit_i64_const(s.ws_code, 16)
            wasm_emit_i64_mul(s.ws_code)
            wasm_synth_emit_bump_alloc(s)
            wasm_emit_local_set(s.ws_code, l_nent)

            wasm_emit_local_get(s.ws_code, l_cnt)
            wasm_emit_i64_const(s.ws_code, 16)
            wasm_emit_i64_mul(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_cbytes)
            wasm_synth_emit_copy_bytes(s, l_nent, l_ent, l_cbytes)

            wasm_emit_local_get(s.ws_code, l_hdr)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_local_get(s.ws_code, l_ncap)
            wasm_emit_i64_store(s.ws_code, 3, 16)

            wasm_emit_local_get(s.ws_code, l_hdr)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_local_get(s.ws_code, l_nent)
            wasm_emit_i64_store(s.ws_code, 3, 24)

            wasm_emit_local_get(s.ws_code, l_nent)
            wasm_emit_local_set(s.ws_code, l_ent)
        wasm_emit_end(s.ws_code)

        wasm_emit_local_get(s.ws_code, l_ent)
        wasm_emit_local_get(s.ws_code, l_cnt)
        wasm_emit_i64_const(s.ws_code, 16)
        wasm_emit_i64_mul(s.ws_code)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_key)
        wasm_emit_i64_store(s.ws_code, 3, 0)

        wasm_emit_local_get(s.ws_code, l_ent)
        wasm_emit_local_get(s.ws_code, l_cnt)
        wasm_emit_i64_const(s.ws_code, 16)
        wasm_emit_i64_mul(s.ws_code)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_val)
        wasm_emit_i64_store(s.ws_code, 3, 8)

        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_cnt)
        wasm_emit_i64_const(s.ws_code, 1)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i64_store(s.ws_code, 3, 8)
    wasm_emit_end(s.ws_code)
    return 0
end

fn wasm_synth_emit_dict_lookup s l_hdr l_key l_out_val l_out_found
    // WHY: Looks up l_key in linear-memory dict l_hdr using value/string-content equality,
    // populating l_out_val (0 if absent) and l_out_found (1 if present, 0 if absent).
    l_isd = wasm_synth_alloc_local(s, "__wasi_dl_isd")
    l_cnt = wasm_synth_alloc_local(s, "__wasi_dl_cnt")
    l_ent = wasm_synth_alloc_local(s, "__wasi_dl_ent")
    l_i = wasm_synth_alloc_local(s, "__wasi_dl_i")
    l_ek = wasm_synth_alloc_local(s, "__wasi_dl_ek")
    l_eq = wasm_synth_alloc_local(s, "__wasi_dl_eq")

    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_local_set(s.ws_code, l_out_val)
    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_local_set(s.ws_code, l_out_found)

    wasm_synth_emit_is_dict_ptr(s, l_hdr, l_isd)
    wasm_emit_local_get(s.ws_code, l_isd)
    wasm_emit_i64_const(s.ws_code, 1)
    wasm_emit_i64_eq(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 8)
        wasm_emit_local_set(s.ws_code, l_cnt)

        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 24)
        wasm_emit_local_set(s.ws_code, l_ent)

        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_local_set(s.ws_code, l_i)

        wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_i)
            wasm_emit_local_get(s.ws_code, l_cnt)
            wasm_emit_i64_ge_s(s.ws_code)
            wasm_emit_br_if(s.ws_code, 1)

            wasm_emit_local_get(s.ws_code, l_ent)
            wasm_emit_local_get(s.ws_code, l_i)
            wasm_emit_i64_const(s.ws_code, 16)
            wasm_emit_i64_mul(s.ws_code)
            wasm_emit_i64_add(s.ws_code)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_load(s.ws_code, 3, 0)
            wasm_emit_local_set(s.ws_code, l_ek)

            wasm_synth_emit_val_eq(s, l_ek, l_key, l_eq)
            wasm_emit_local_get(s.ws_code, l_eq)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_i64_eq(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_ent)
                wasm_emit_local_get(s.ws_code, l_i)
                wasm_emit_i64_const(s.ws_code, 16)
                wasm_emit_i64_mul(s.ws_code)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_load(s.ws_code, 3, 8)
                wasm_emit_local_set(s.ws_code, l_out_val)
                wasm_emit_i64_const(s.ws_code, 1)
                wasm_emit_local_set(s.ws_code, l_out_found)
                wasm_emit_br(s.ws_code, 2)
            wasm_emit_end(s.ws_code)

            wasm_emit_local_get(s.ws_code, l_i)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_i64_add(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_i)
            wasm_emit_br(s.ws_code, 0)
        wasm_emit_end(s.ws_code)
        wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0
end

fn wasm_synth_emit_dict_del s l_hdr l_key l_out_ok
    // WHY: Deletes l_key from linear-memory dict l_hdr via O(1) swap-with-last removal.
    l_isd = wasm_synth_alloc_local(s, "__wasi_dd_isd")
    l_cnt = wasm_synth_alloc_local(s, "__wasi_dd_cnt")
    l_ent = wasm_synth_alloc_local(s, "__wasi_dd_ent")
    l_i = wasm_synth_alloc_local(s, "__wasi_dd_i")
    l_ek = wasm_synth_alloc_local(s, "__wasi_dd_ek")
    l_eq = wasm_synth_alloc_local(s, "__wasi_dd_eq")
    l_last = wasm_synth_alloc_local(s, "__wasi_dd_last")

    wasm_emit_i64_const(s.ws_code, 0)
    wasm_emit_local_set(s.ws_code, l_out_ok)
    wasm_synth_emit_is_dict_ptr(s, l_hdr, l_isd)
    wasm_emit_local_get(s.ws_code, l_isd)
    wasm_emit_i64_const(s.ws_code, 1)
    wasm_emit_i64_eq(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 8)
        wasm_emit_local_set(s.ws_code, l_cnt)

        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 24)
        wasm_emit_local_set(s.ws_code, l_ent)

        wasm_emit_i64_const(s.ws_code, 0)
        wasm_emit_local_set(s.ws_code, l_i)
        wasm_emit_block(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_loop(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_local_get(s.ws_code, l_i)
            wasm_emit_local_get(s.ws_code, l_cnt)
            wasm_emit_i64_ge_s(s.ws_code)
            wasm_emit_br_if(s.ws_code, 1)

            wasm_emit_local_get(s.ws_code, l_ent)
            wasm_emit_local_get(s.ws_code, l_i)
            wasm_emit_i64_const(s.ws_code, 16)
            wasm_emit_i64_mul(s.ws_code)
            wasm_emit_i64_add(s.ws_code)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_load(s.ws_code, 3, 0)
            wasm_emit_local_set(s.ws_code, l_ek)

            wasm_synth_emit_val_eq(s, l_ek, l_key, l_eq)
            wasm_emit_local_get(s.ws_code, l_eq)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_i64_eq(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                wasm_emit_local_get(s.ws_code, l_cnt)
                wasm_emit_i64_const(s.ws_code, 1)
                wasm_emit_i64_sub(s.ws_code)
                wasm_emit_local_set(s.ws_code, l_last)

                wasm_emit_local_get(s.ws_code, l_ent)
                wasm_emit_local_get(s.ws_code, l_i)
                wasm_emit_i64_const(s.ws_code, 16)
                wasm_emit_i64_mul(s.ws_code)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_local_get(s.ws_code, l_ent)
                wasm_emit_local_get(s.ws_code, l_last)
                wasm_emit_i64_const(s.ws_code, 16)
                wasm_emit_i64_mul(s.ws_code)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_load(s.ws_code, 3, 0)
                wasm_emit_i64_store(s.ws_code, 3, 0)

                wasm_emit_local_get(s.ws_code, l_ent)
                wasm_emit_local_get(s.ws_code, l_i)
                wasm_emit_i64_const(s.ws_code, 16)
                wasm_emit_i64_mul(s.ws_code)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_local_get(s.ws_code, l_ent)
                wasm_emit_local_get(s.ws_code, l_last)
                wasm_emit_i64_const(s.ws_code, 16)
                wasm_emit_i64_mul(s.ws_code)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_load(s.ws_code, 3, 8)
                wasm_emit_i64_store(s.ws_code, 3, 8)

                wasm_emit_local_get(s.ws_code, l_hdr)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_local_get(s.ws_code, l_last)
                wasm_emit_i64_store(s.ws_code, 3, 8)

                wasm_emit_i64_const(s.ws_code, 1)
                wasm_emit_local_set(s.ws_code, l_out_ok)
                wasm_emit_br(s.ws_code, 2)
            wasm_emit_end(s.ws_code)

            wasm_emit_local_get(s.ws_code, l_i)
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_i64_add(s.ws_code)
            wasm_emit_local_set(s.ws_code, l_i)
            wasm_emit_br(s.ws_code, 0)
        wasm_emit_end(s.ws_code)
        wasm_emit_end(s.ws_code)
    wasm_emit_end(s.ws_code)
    return 0
end

fn wasm_synth_emit_poly_index_get s l_hdr l_idx
    // WHY: Polymorphic container read c[k] dispatching dicts via WASM_DICT_MAGIC and lists via data_ptr.
    // Pushes resulting i64 value onto the WASM stack.
    l_isd = wasm_synth_alloc_local(s, "__wasi_pig_isd")
    l_dval = wasm_synth_alloc_local(s, "__wasi_pig_dv")
    l_dfnd = wasm_synth_alloc_local(s, "__wasi_pig_df")
    wasm_synth_emit_is_dict_ptr(s, l_hdr, l_isd)
    wasm_emit_local_get(s.ws_code, l_isd)
    wasm_emit_i64_const(s.ws_code, 1)
    wasm_emit_i64_eq(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_I64)
        wasm_synth_emit_dict_lookup(s, l_hdr, l_idx, l_dval, l_dfnd)
        wasm_emit_local_get(s.ws_code, l_dval)
    wasm_emit_else(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 16)
        wasm_emit_local_get(s.ws_code, l_idx)
        wasm_emit_i64_const(s.ws_code, 8)
        wasm_emit_i64_mul(s.ws_code)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 0)
    wasm_emit_end(s.ws_code)
    return 0
end

fn wasm_synth_emit_poly_index_set s l_hdr l_idx l_val
    // WHY: Polymorphic container write c[k] = v supporting both dicts (with growth) and lists.
    l_isd = wasm_synth_alloc_local(s, "__wasi_pis_isd")
    wasm_synth_emit_is_dict_ptr(s, l_hdr, l_isd)
    wasm_emit_local_get(s.ws_code, l_isd)
    wasm_emit_i64_const(s.ws_code, 1)
    wasm_emit_i64_eq(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_synth_emit_dict_set(s, l_hdr, l_idx, l_val)
    wasm_emit_else(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 16)
        wasm_emit_local_get(s.ws_code, l_idx)
        wasm_emit_i64_const(s.ws_code, 8)
        wasm_emit_i64_mul(s.ws_code)
        wasm_emit_i64_add(s.ws_code)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_val)
        wasm_emit_i64_store(s.ws_code, 3, 0)
    wasm_emit_end(s.ws_code)
    return 0
end

fn wasm_synth_emit_list_push s l_hdr l_val
    // WHY: Appends l_val to linear-memory list l_hdr, dynamically doubling capacity when len >= cap.
    l_len = wasm_synth_alloc_local(s, "__wasi_lp_len")
    l_cap = wasm_synth_alloc_local(s, "__wasi_lp_cap")
    l_dp = wasm_synth_alloc_local(s, "__wasi_lp_dp")
    l_ncap = wasm_synth_alloc_local(s, "__wasi_lp_ncap")
    l_ndp = wasm_synth_alloc_local(s, "__wasi_lp_ndp")
    l_cb = wasm_synth_alloc_local(s, "__wasi_lp_cb")

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_load(s.ws_code, 3, 0)
    wasm_emit_local_set(s.ws_code, l_len)

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_load(s.ws_code, 3, 8)
    wasm_emit_local_set(s.ws_code, l_cap)

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_load(s.ws_code, 3, 16)
    wasm_emit_local_set(s.ws_code, l_dp)

    wasm_emit_local_get(s.ws_code, l_len)
    wasm_emit_local_get(s.ws_code, l_cap)
    wasm_emit_i64_ge_s(s.ws_code)
    wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
        wasm_emit_local_get(s.ws_code, l_cap)
        wasm_emit_i64_const(s.ws_code, 2)
        wasm_emit_i64_mul(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_ncap)
        wasm_emit_local_get(s.ws_code, l_ncap)
        wasm_emit_i64_const(s.ws_code, 16)
        wasm_emit_i64_lt_s(s.ws_code)
        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
            wasm_emit_i64_const(s.ws_code, 16)
            wasm_emit_local_set(s.ws_code, l_ncap)
        wasm_emit_end(s.ws_code)

        wasm_emit_local_get(s.ws_code, l_ncap)
        wasm_emit_i64_const(s.ws_code, 8)
        wasm_emit_i64_mul(s.ws_code)
        wasm_synth_emit_bump_alloc(s)
        wasm_emit_local_set(s.ws_code, l_ndp)

        wasm_emit_local_get(s.ws_code, l_len)
        wasm_emit_i64_const(s.ws_code, 8)
        wasm_emit_i64_mul(s.ws_code)
        wasm_emit_local_set(s.ws_code, l_cb)
        wasm_synth_emit_copy_bytes(s, l_ndp, l_dp, l_cb)

        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_ncap)
        wasm_emit_i64_store(s.ws_code, 3, 8)

        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, l_ndp)
        wasm_emit_i64_store(s.ws_code, 3, 16)

        wasm_emit_local_get(s.ws_code, l_ndp)
        wasm_emit_local_set(s.ws_code, l_dp)
    wasm_emit_end(s.ws_code)

    wasm_emit_local_get(s.ws_code, l_dp)
    wasm_emit_local_get(s.ws_code, l_len)
    wasm_emit_i64_const(s.ws_code, 8)
    wasm_emit_i64_mul(s.ws_code)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_local_get(s.ws_code, l_val)
    wasm_emit_i64_store(s.ws_code, 3, 0)

    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_local_get(s.ws_code, l_len)
    wasm_emit_i64_const(s.ws_code, 1)
    wasm_emit_i64_add(s.ws_code)
    wasm_emit_i64_store(s.ws_code, 3, 0)
    return 0
end

fn wasm_interp_is_ident inner
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

fn wasm_interp_is_lsp_snippet inner
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

fn wasm_synth_emit_interp_str s txt
    // WHY: Compiles both `${expr}` and `{ident}` string interpolation into LPST linear-memory strings.
    tlen = len(txt)
    chunk_types = list()
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
                if len(inner) > 0 and wasm_interp_is_lsp_snippet(inner) == 0
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
                if wasm_interp_is_ident(inner) == 1 and wasm_synth_lookup_local(s, inner) >= 0
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
        str_off = wasm_synth_add_string_constant(s, txt)
        wasm_emit_i64_const(s.ws_code, str_off)
        s.ws_last_expr_is_str = 1
        s.ws_last_expr_is_float = 0
        return 0
    end
    if len(cur_lit) > 0
        push(chunk_types, 0)
        push(chunk_vals, cur_lit)
    end
    ci = 0
    while ci < chunk_types.len()
        cty = chunk_types[ci]
        if cty == 0
            str_off = wasm_synth_add_string_constant(s, chunk_vals[ci])
            wasm_emit_i64_const(s.ws_code, str_off)
        elif cty == 1
            lidx = wasm_synth_lookup_local(s, chunk_vals[ci])
            wasm_emit_local_get(s.ws_code, lidx)
            if wasm_synth_is_float_var(s, chunk_vals[ci]) == 1
                wasm_synth_emit_float_to_lpst_str(s)
            else
                wasm_synth_emit_ensure_lpst_str(s)
            end
        else
            sub_toks = tokenize_source(chunk_vals[ci])
            sub_pb = [0]
            wasm_synth_compile_expr(s, sub_toks, sub_pb)
            if s.ws_last_expr_is_float == 1
                wasm_synth_emit_float_to_lpst_str(s)
            else
                wasm_synth_emit_ensure_lpst_str(s)
            end
        end
        if ci > 0
            wasm_synth_emit_runtime_str_concat(s)
        end
        ci = ci + 1
    end
    s.ws_last_expr_is_str = 1
    s.ws_last_expr_is_float = 0
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

fn wasm_synth_emit_pack_locals_into_list s elem_locs
    // WHY: Allocates a linear-memory LiPi list header [len, cap, data_ptr] + elements from local slots
    // and leaves the list header pointer on top of the WASM i64 operand stack.
    cnt = elem_locs.len()
    l_cap = 16
    if cnt > 16
        l_cap = cnt
    end
    wasm_emit_i64_const(s.ws_code, 24 + (l_cap * 8))
    wasm_synth_emit_bump_alloc(s)
    l_hdr = wasm_synth_alloc_local(s, "__wasi_pack_hdr_" + str(s.ws_code.len()))
    wasm_emit_local_set(s.ws_code, l_hdr)
    wasm_emit_local_get(s.ws_code, l_hdr)
    wasm_emit_i32_wrap_i64(s.ws_code)
    wasm_emit_i64_const(s.ws_code, cnt)
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
    while ei < cnt
        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_local_get(s.ws_code, elem_locs[ei])
        wasm_emit_i64_store(s.ws_code, 3, 24 + (ei * 8))
        ei = ei + 1
    end
    wasm_emit_local_get(s.ws_code, l_hdr)
    return 0
end

fn wasm_synth_expr_primary s toks pos_box
    // WHY: Synthesizes primary operands: literals, variables, calls, parenthesized expressions.
    // Leaves exactly one 64-bit operand on the WASM evaluation stack.
    s.ws_last_expr_is_float = 0
    s.ws_last_expr_is_str = 0
    s.ws_last_expr_is_float_list = 0
    s.ws_last_expr_is_str_list = 0
    s.ws_last_struct = ""
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

    // 1c. List Literal: [e0, e1, ...]
    if k == TOK_LBRACKET()
        list_set(pos_box, 0, pos + 1)
        ltag = str(s.ws_code.len())
        arr_locs = list()
        arr_is_f = list()
        arr_has_f = 0
        arr_has_s = 0
        arr_cnt = 0
        while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RBRACKET()
            wasm_synth_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) >= toks.len() or toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
                break
            end
            wasm_synth_compile_expr(s, toks, pos_box)
            if s.ws_last_expr_is_float == 1
                arr_has_f = 1
            end
            if s.ws_last_expr_is_str == 1
                arr_has_s = 1
            end
            push(arr_is_f, s.ws_last_expr_is_float)
            al = wasm_synth_alloc_local(s, "__wasi_arr_el_" + ltag + "_" + str(arr_cnt))
            wasm_emit_local_set(s.ws_code, al)
            push(arr_locs, al)
            arr_cnt = arr_cnt + 1
            wasm_synth_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_COMMA()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        l_cap = 16
        if arr_cnt > 16
            l_cap = arr_cnt
        end
        wasm_emit_i64_const(s.ws_code, 24 + (l_cap * 8))
        wasm_synth_emit_bump_alloc(s)
        l_hdr = wasm_synth_alloc_local(s, "__wasi_list_hdr_" + ltag)
        wasm_emit_local_set(s.ws_code, l_hdr)
        wasm_emit_local_get(s.ws_code, l_hdr)
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_const(s.ws_code, arr_cnt)
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
        while ei < arr_cnt
            wasm_emit_local_get(s.ws_code, l_hdr)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_local_get(s.ws_code, arr_locs[ei])
            if arr_has_f == 1 and arr_is_f[ei] == 0
                wasm_emit_f64_convert_i64_s(s.ws_code)
                wasm_emit_i64_reinterpret_f64(s.ws_code)
            end
            wasm_emit_i64_store(s.ws_code, 3, 24 + (ei * 8))
            ei = ei + 1
        end
        wasm_emit_local_get(s.ws_code, l_hdr)
        s.ws_last_expr_is_float = 0
        s.ws_last_expr_is_str = 0
        s.ws_last_expr_is_float_list = arr_has_f
        s.ws_last_expr_is_str_list = arr_has_s
        return 0

    // 1d. Dict Literal: {}, {:}, { "k": v, ... }
    if k == TOK_LBRACE() or (k != TOK_STR() and txt == "{")
        list_set(pos_box, 0, pos + 1)
        dtag = str(s.ws_code.len())
        wasm_synth_emit_dict_new(s)
        l_dhdr = wasm_synth_alloc_local(s, "__wasi_dlit_" + dtag)
        wasm_emit_local_set(s.ws_code, l_dhdr)
        d_has_f = 0
        d_has_s = 0
        wasm_synth_skip_whitespace(toks, pos_box)
        // Handle `{:}` empty dict form
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ":"))
            list_set(pos_box, 0, get(pos_box, 0) + 1)
            wasm_synth_skip_whitespace(toks, pos_box)
        end
        d_idx = 0
        while get(pos_box, 0) < toks.len()
            wasm_synth_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) >= toks.len()
                break
            end
            dt_end = toks[get(pos_box, 0)]
            if dt_end.tok_kind == TOK_RBRACE() or (dt_end.tok_kind != TOK_STR() and dt_end.tok_text == "}")
                break
            end
            if dt_end.tok_kind == TOK_EOF()
                break
            end
            l_dk = wasm_synth_alloc_local(s, "__wasi_dlk_" + dtag + "_" + str(d_idx))
            l_dv = wasm_synth_alloc_local(s, "__wasi_dlv_" + dtag + "_" + str(d_idx))
            wasm_synth_compile_expr(s, toks, pos_box)
            wasm_emit_local_set(s.ws_code, l_dk)
            wasm_synth_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COLON() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ":"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
            wasm_synth_skip_whitespace(toks, pos_box)
            wasm_synth_compile_expr(s, toks, pos_box)
            if s.ws_last_expr_is_float == 1
                d_has_f = 1
            end
            if s.ws_last_expr_is_str == 1
                d_has_s = 1
            end
            wasm_emit_local_set(s.ws_code, l_dv)
            wasm_synth_emit_dict_set(s, l_dhdr, l_dk, l_dv)
            d_idx = d_idx + 1
            wasm_synth_skip_whitespace(toks, pos_box)
            if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_COMMA() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == ","))
                list_set(pos_box, 0, get(pos_box, 0) + 1)
            end
        end
        if get(pos_box, 0) < toks.len() and (toks[get(pos_box, 0)].tok_kind == TOK_RBRACE() or (toks[get(pos_box, 0)].tok_kind != TOK_STR() and toks[get(pos_box, 0)].tok_text == "}"))
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        end
        wasm_emit_local_get(s.ws_code, l_dhdr)
        s.ws_last_expr_is_float = 0
        s.ws_last_expr_is_str = 0
        s.ws_last_expr_is_float_list = d_has_f
        s.ws_last_expr_is_str_list = d_has_s
        return 0

    // 2. String Literal & Interpolated String Literal
    if k == TOK_STR()
        list_set(pos_box, 0, pos + 1)
        str_offset = wasm_synth_add_string_constant(s, txt)
        wasm_emit_i64_const(s.ws_code, str_offset)
        s.ws_last_expr_is_str = 1
        return 0
    if k == TOK_INTERP_STR()
        list_set(pos_box, 0, pos + 1)
        wasm_synth_emit_interp_str(s, txt)
        return 0

    // 3. Parenthesized Expression: ( expr )
    if k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1) // Consume '('
        wasm_synth_compile_expr(s, toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_p + 1) // Consume ')'
        return 0

    // 4. Unary Operators: -, await
    if k == TOK_KW_AWAIT() or (k == TOK_IDENT() and (txt == "await" or txt == "অপেক্ষা" or txt == "@await"))
        list_set(pos_box, 0, pos + 1)
        wasm_synth_expr_primary(s, toks, pos_box)
        return 0
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

            target_fn = wasm_synth_find_function(s, ident_name)
            arg_count = 0
            arg_is_f = list()
            arg_is_s = list()
            arg_is_fl = list()
            arg_is_sl = list()
            arg_var_names = list()
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                arg_start_p = get(pos_box, 0)
                a_vname = ""
                if arg_start_p < toks.len() and toks[arg_start_p].tok_kind == TOK_IDENT()
                    if arg_start_p + 1 >= toks.len() or toks[arg_start_p + 1].tok_kind == TOK_COMMA() or toks[arg_start_p + 1].tok_kind == TOK_RPAREN()
                        a_vname = toks[arg_start_p].tok_text
                    end
                end
                wasm_synth_compile_expr(s, toks, pos_box)
                // Auto-promote int argument to f64 bits when callee parameter expects float
                a_f = s.ws_last_expr_is_float
                if target_fn != 0 and target_fn.wfn_param_is_float != 0 and arg_count < target_fn.wfn_param_is_float.len()
                    if target_fn.wfn_param_is_float[arg_count] == 1 and a_f == 0
                        wasm_emit_f64_convert_i64_s(s.ws_code)
                        wasm_emit_i64_reinterpret_f64(s.ws_code)
                        a_f = 1
                    end
                end
                push(arg_is_f, a_f)
                push(arg_is_s, s.ws_last_expr_is_str)
                push(arg_is_fl, s.ws_last_expr_is_float_list)
                push(arg_is_sl, s.ws_last_expr_is_str_list)
                push(arg_var_names, a_vname)
                arg_count = arg_count + 1

                cur_p = get(pos_box, 0)
                if cur_p < toks.len() and toks[cur_p].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, cur_p + 1)

            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            if target_fn != 0
                // Variadic packing & default argument evaluation before WASM call
                if target_fn.wfn_is_variadic == 1
                    fixed_n = target_fn.wfn_param_count - 1
                    var_cnt = arg_count - fixed_n
                    if var_cnt < 0 var_cnt = 0 end
                    v_locs = list()
                    vi_a = 0
                    while vi_a < var_cnt
                        push(v_locs, wasm_synth_alloc_local(s, "__wasi_varg_" + str(s.ws_code.len()) + "_" + str(vi_a)))
                        vi_a = vi_a + 1
                    end
                    vi_r = var_cnt - 1
                    while vi_r >= 0
                        wasm_emit_local_set(s.ws_code, v_locs[vi_r])
                        vi_r = vi_r - 1
                    end
                    wasm_synth_emit_pack_locals_into_list(s, v_locs)
                    arg_count = fixed_n + 1
                end
                while arg_count < target_fn.wfn_param_count
                    def_st = 0 - 1
                    if target_fn.wfn_def_starts != 0 and arg_count < target_fn.wfn_def_starts.len()
                        def_st = target_fn.wfn_def_starts[arg_count]
                    end
                    if def_st >= 0 and s.ws_source_toks != 0
                        def_box = [def_st]
                        wasm_synth_compile_expr(s, s.ws_source_toks, def_box)
                    else
                        wasm_emit_i64_const(s.ws_code, 0)
                    end
                    arg_count = arg_count + 1
                end
                while arg_count > target_fn.wfn_param_count
                    wasm_emit_drop(s.ws_code)
                    arg_count = arg_count - 1
                end
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
                s.ws_last_expr_is_float = target_fn.wfn_returns_float
                s.ws_last_expr_is_str = target_fn.wfn_returns_str
                s.ws_last_expr_is_float_list = 0
                s.ws_last_expr_is_str_list = 0
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
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
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
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "exit" or ident_name == "বিদায়"
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_emit_unreachable(s.ws_code)
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "syscall" or ident_name == "সিসকল"
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_emit_i64_const(s.ws_code, 0)
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "malloc" or ident_name == "মেমরি_বরাদ্দ" or ident_name == "alloc" or ident_name == "sys_alloc" or ident_name == "mem_alloc" or ident_name == "বরাদ্দ"
                if arg_count == 0
                    wasm_emit_i64_const(s.ws_code, 8)
                else
                    // Keep first size argument on stack; discard any extra args
                    while arg_count > 1
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                wasm_synth_emit_bump_alloc(s)
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "free" or ident_name == "sys_free" or ident_name == "mem_free" or ident_name == "মুক্ত" or ident_name == "মেমরি_মুক্তি"
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_emit_i64_const(s.ws_code, 0)
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
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
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
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
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "int" or ident_name == "পূর্ণসংখ্যা"
                if arg_count >= 1
                    while arg_count > 1
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    if arg_is_f[0] == 1
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
                    if arg_is_f[0] == 0
                        wasm_emit_f64_convert_i64_s(s.ws_code)
                        wasm_emit_i64_reinterpret_f64(s.ws_code)
                else
                    wasm_emit_i64_const(s.ws_code, 0)
                    wasm_emit_f64_convert_i64_s(s.ws_code)
                    wasm_emit_i64_reinterpret_f64(s.ws_code)
                s.ws_last_expr_is_float = 1
                s.ws_last_expr_is_str = 0
            elif ident_name == "str" or ident_name == "to_str" or ident_name == "স্ট্রিং"
                if arg_count >= 1
                    while arg_count > 1
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    if arg_is_f[0] == 1
                        wasm_synth_emit_float_to_lpst_str(s)
                    else
                        wasm_synth_emit_ensure_lpst_str(s)
                    end
                else
                    wasm_emit_i64_const(s.ws_code, wasm_synth_add_string_constant(s, ""))
                end
                s.ws_last_expr_is_str = 1
                s.ws_last_expr_is_float = 0
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
            elif ident_name == "dict" or ident_name == "ম্যাপ" or ident_name == "অভিধান"
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_synth_emit_dict_new(s)
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
                s.ws_last_expr_is_float_list = 0
                s.ws_last_expr_is_str_list = 0
            elif ident_name == "has_key" or ident_name == "dict_has" or ident_name == "map_has" or ident_name == "has"
                if arg_count >= 2
                    while arg_count > 2
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_hk_k = wasm_synth_alloc_local(s, "__wasi_hk_k")
                    l_hk_h = wasm_synth_alloc_local(s, "__wasi_hk_h")
                    l_hk_v = wasm_synth_alloc_local(s, "__wasi_hk_v")
                    l_hk_f = wasm_synth_alloc_local(s, "__wasi_hk_f")
                    wasm_emit_local_set(s.ws_code, l_hk_k)
                    wasm_emit_local_set(s.ws_code, l_hk_h)
                    wasm_synth_emit_dict_lookup(s, l_hk_h, l_hk_k, l_hk_v, l_hk_f)
                    wasm_emit_local_get(s.ws_code, l_hk_f)
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
                end
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "dict_get" or ident_name == "map_get"
                if arg_count >= 2
                    while arg_count > 2
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_dg_k = wasm_synth_alloc_local(s, "__wasi_dg_k")
                    l_dg_h = wasm_synth_alloc_local(s, "__wasi_dg_h")
                    l_dg_v = wasm_synth_alloc_local(s, "__wasi_dg_v")
                    l_dg_f = wasm_synth_alloc_local(s, "__wasi_dg_f")
                    wasm_emit_local_set(s.ws_code, l_dg_k)
                    wasm_emit_local_set(s.ws_code, l_dg_h)
                    wasm_synth_emit_dict_lookup(s, l_dg_h, l_dg_k, l_dg_v, l_dg_f)
                    wasm_emit_local_get(s.ws_code, l_dg_v)
                    s.ws_last_expr_is_float = arg_is_fl[0]
                    s.ws_last_expr_is_str = arg_is_sl[0]
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
                    s.ws_last_expr_is_float = 0
                    s.ws_last_expr_is_str = 0
                end
            elif ident_name == "dict_set" or ident_name == "map_set"
                if arg_count >= 3
                    while arg_count > 3
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_dsv = wasm_synth_alloc_local(s, "__wasi_dsb_v")
                    l_dsk = wasm_synth_alloc_local(s, "__wasi_dsb_k")
                    l_dsh = wasm_synth_alloc_local(s, "__wasi_dsb_h")
                    wasm_emit_local_set(s.ws_code, l_dsv)
                    wasm_emit_local_set(s.ws_code, l_dsk)
                    wasm_emit_local_set(s.ws_code, l_dsh)
                    wasm_synth_emit_dict_set(s, l_dsh, l_dsk, l_dsv)
                    wasm_emit_local_get(s.ws_code, l_dsh)
                    if arg_var_names[0] != ""
                        if arg_is_f[2] == 1
                            wasm_synth_mark_float_list(s, arg_var_names[0], 1)
                        end
                        if arg_is_s[2] == 1
                            wasm_synth_mark_str_list(s, arg_var_names[0], 1)
                        end
                    end
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
                end
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "del_key" or ident_name == "dict_del" or ident_name == "map_del"
                if arg_count >= 2
                    while arg_count > 2
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_dk_k = wasm_synth_alloc_local(s, "__wasi_dk_k")
                    l_dk_h = wasm_synth_alloc_local(s, "__wasi_dk_h")
                    l_dk_ok = wasm_synth_alloc_local(s, "__wasi_dk_ok")
                    wasm_emit_local_set(s.ws_code, l_dk_k)
                    wasm_emit_local_set(s.ws_code, l_dk_h)
                    wasm_synth_emit_dict_del(s, l_dk_h, l_dk_k, l_dk_ok)
                    wasm_emit_local_get(s.ws_code, l_dk_ok)
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
                end
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "push" or ident_name == "যোগ"
                if arg_count >= 2
                    while arg_count > 2
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_psv = wasm_synth_alloc_local(s, "__wasi_ps_v")
                    l_psh = wasm_synth_alloc_local(s, "__wasi_ps_h")
                    if arg_is_fl[0] == 1 and arg_is_f[1] == 0
                        wasm_emit_f64_convert_i64_s(s.ws_code)
                        wasm_emit_i64_reinterpret_f64(s.ws_code)
                    end
                    wasm_emit_local_set(s.ws_code, l_psv)
                    wasm_emit_local_set(s.ws_code, l_psh)
                    wasm_synth_emit_list_push(s, l_psh, l_psv)
                    wasm_emit_local_get(s.ws_code, l_psh)
                    if arg_var_names[0] != ""
                        if arg_is_f[1] == 1
                            wasm_synth_mark_float_list(s, arg_var_names[0], 1)
                        end
                        if arg_is_s[1] == 1
                            wasm_synth_mark_str_list(s, arg_var_names[0], 1)
                        end
                    end
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
                end
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
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
                    l_lgh = wasm_synth_alloc_local(s, "__wasi_lg_h")
                    wasm_emit_local_set(s.ws_code, l_lgi)
                    wasm_emit_local_set(s.ws_code, l_lgh)
                    wasm_synth_emit_poly_index_get(s, l_lgh, l_lgi)
                    s.ws_last_expr_is_float = arg_is_fl[0]
                    s.ws_last_expr_is_str = arg_is_sl[0]
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
                    s.ws_last_expr_is_float = 0
                    s.ws_last_expr_is_str = 0
            elif ident_name == "list_set" or ident_name == "সেট"
                if arg_count >= 3
                    while arg_count > 3
                        wasm_emit_drop(s.ws_code)
                        arg_count = arg_count - 1
                    l_lsv = wasm_synth_alloc_local(s, "__wasi_ls_v")
                    l_lsi = wasm_synth_alloc_local(s, "__wasi_ls_i")
                    l_lsh = wasm_synth_alloc_local(s, "__wasi_ls_h")
                    if arg_is_fl[0] == 1 and arg_is_f[2] == 0
                        wasm_emit_f64_convert_i64_s(s.ws_code)
                        wasm_emit_i64_reinterpret_f64(s.ws_code)
                    end
                    wasm_emit_local_set(s.ws_code, l_lsv)
                    wasm_emit_local_set(s.ws_code, l_lsi)
                    wasm_emit_local_set(s.ws_code, l_lsh)
                    wasm_synth_emit_poly_index_set(s, l_lsh, l_lsi, l_lsv)
                    wasm_emit_local_get(s.ws_code, l_lsh)
                    if arg_var_names[0] != ""
                        if arg_is_f[2] == 1
                            wasm_synth_mark_float_list(s, arg_var_names[0], 1)
                        end
                        if arg_is_s[2] == 1
                            wasm_synth_mark_str_list(s, arg_var_names[0], 1)
                        end
                    end
                else
                    ai = 0
                    while ai < arg_count
                        wasm_emit_drop(s.ws_code)
                        ai = ai + 1
                    wasm_emit_i64_const(s.ws_code, 0)
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            elif ident_name == "list" or ident_name == "তালিকা"
                // WHY: Pops evaluated args in reverse into locals, bump-allocates 24-byte header +
                // element storage via mem[24], and stores elements in order at [hdr + 24 + i*8].
                ltag_l = str(s.ws_code.len())
                arg_locs = list()
                list_has_f = 0
                list_has_s = 0
                ai = 0
                while ai < arg_count
                    push(arg_locs, wasm_synth_alloc_local(s, "__wasi_list_arg_" + ltag_l + "_" + str(ai)))
                    if arg_is_f[ai] == 1 list_has_f = 1 end
                    if arg_is_s[ai] == 1 list_has_s = 1 end
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

                l_hdr = wasm_synth_alloc_local(s, "__wasi_list_hdr_" + ltag_l)
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
                    if list_has_f == 1 and arg_is_f[ei] == 0
                        wasm_emit_f64_convert_i64_s(s.ws_code)
                        wasm_emit_i64_reinterpret_f64(s.ws_code)
                    end
                    wasm_emit_i64_store(s.ws_code, 3, 24 + (ei * 8))
                    ei = ei + 1
                wasm_emit_local_get(s.ws_code, l_hdr)
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
                s.ws_last_expr_is_float_list = list_has_f
                s.ws_last_expr_is_str_list = list_has_s
            elif wasm_synth_find_struct(s, ident_name) != 0
                // WHY: Allocates +8B header before struct/union fields so [ptr - 8] stores sovereign type tag.
                // Unions place all fields at offset 0. Tracks float/str field types for downstream reads.
                sdef = wasm_synth_find_struct(s, ident_name)
                stag = str(s.ws_code.len())
                sc_locs = list()
                ai = 0
                while ai < arg_count
                    push(sc_locs, wasm_synth_alloc_local(s, "__wasi_sc_arg_" + stag + "_" + str(ai)))
                    ai = ai + 1
                rev = arg_count - 1
                while rev >= 0
                    wasm_emit_local_set(s.ws_code, sc_locs[rev])
                    rev = rev - 1

                num_fields = sdef.wsd_fields.len()
                alloc_sz = num_fields * 8
                if alloc_sz < 8
                    alloc_sz = 8
                wasm_emit_i64_const(s.ws_code, alloc_sz + 8)
                wasm_synth_emit_bump_alloc(s)

                l_sptr = wasm_synth_alloc_local(s, "__wasi_struct_ptr_" + stag)
                wasm_emit_local_set(s.ws_code, l_sptr)

                wasm_emit_local_get(s.ws_code, l_sptr)
                wasm_emit_i32_wrap_i64(s.ws_code)
                wasm_emit_i64_const(s.ws_code, (1415139397 << 32) | sdef.wsd_type_id)
                wasm_emit_i64_store(s.ws_code, 3, 0)

                wasm_emit_local_get(s.ws_code, l_sptr)
                wasm_emit_i64_const(s.ws_code, 8)
                wasm_emit_i64_add(s.ws_code)
                wasm_emit_local_set(s.ws_code, l_sptr)

                fi = 0
                while fi < arg_count and fi < num_fields
                    f_nm_c = sdef.wsd_fields[fi]
                    if arg_is_f[fi] == 1
                        wasm_synth_mark_float_field(s, ident_name, f_nm_c)
                    end
                    if arg_is_s[fi] == 1
                        wasm_synth_mark_str_field(s, ident_name, f_nm_c)
                    end
                    wasm_emit_local_get(s.ws_code, l_sptr)
                    wasm_emit_i32_wrap_i64(s.ws_code)
                    wasm_emit_local_get(s.ws_code, sc_locs[fi])
                    if wasm_synth_is_float_field(s, ident_name, f_nm_c) == 1 and arg_is_f[fi] == 0
                        wasm_emit_f64_convert_i64_s(s.ws_code)
                        wasm_emit_i64_reinterpret_f64(s.ws_code)
                    end
                    st_off = fi * 8
                    if sdef.wsd_is_union == 1
                        st_off = 0
                    end
                    wasm_emit_i64_store(s.ws_code, 3, st_off)
                    fi = fi + 1
                wasm_emit_local_get(s.ws_code, l_sptr)
                s.ws_last_struct = ident_name
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
            else
                // Intrinsic / Unknown function fallback: discard args, push 0
                ai = 0
                while ai < arg_count
                    wasm_emit_drop(s.ws_code)
                    ai = ai + 1
                wasm_emit_i64_const(s.ws_code, 0)
                s.ws_last_expr_is_float = 0
                s.ws_last_expr_is_str = 0
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
            s.ws_last_expr_is_float_list = wasm_synth_is_float_list(s, ident_name)
            s.ws_last_expr_is_str_list = wasm_synth_is_str_list(s, ident_name)
            s.ws_last_struct = wasm_synth_get_var_struct(s, ident_name)

        // Postfix member read, method calls (incl. dyn Trait dispatch), and [index]
        while get(pos_box, 0) < toks.len()
            dp = get(pos_box, 0)
            dt = toks[dp]
            if dt.tok_kind == TOK_LBRACKET()
                list_set(pos_box, 0, dp + 1)
                itag = str(s.ws_code.len())
                base_is_fl = s.ws_last_expr_is_float_list
                base_is_sl = s.ws_last_expr_is_str_list
                l_idx_hdr = wasm_synth_alloc_local(s, "__wasi_idx_hdr_" + itag)
                wasm_emit_local_set(s.ws_code, l_idx_hdr)
                wasm_synth_compile_expr(s, toks, pos_box)
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RBRACKET()
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                end
                l_idx_i = wasm_synth_alloc_local(s, "__wasi_idx_i_" + itag)
                wasm_emit_local_set(s.ws_code, l_idx_i)
                wasm_synth_emit_poly_index_get(s, l_idx_hdr, l_idx_i)
                s.ws_last_struct = ""
                s.ws_last_expr_is_float = base_is_fl
                s.ws_last_expr_is_str = base_is_sl
                s.ws_last_expr_is_float_list = 0
                s.ws_last_expr_is_str_list = 0
            elif dt.tok_kind == TOK_DOT() or dt.tok_text == "."
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
                            s.ws_last_expr_is_float_list = 0
                            s.ws_last_expr_is_str_list = 0
                            s.ws_last_struct = ""
                        elif (fname == "has" or fname == "has_key") and s.ws_last_struct == ""
                            mtag_h = str(s.ws_code.len())
                            l_dh_r = wasm_synth_alloc_local(s, "__wasi_mh_r_" + mtag_h)
                            wasm_emit_local_set(s.ws_code, l_dh_r)
                            list_set(pos_box, 0, dp + 3)
                            l_dh_k = wasm_synth_alloc_local(s, "__wasi_mh_k_" + mtag_h)
                            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                                wasm_synth_compile_expr(s, toks, pos_box)
                                wasm_emit_local_set(s.ws_code, l_dh_k)
                            else
                                wasm_emit_i64_const(s.ws_code, 0)
                                wasm_emit_local_set(s.ws_code, l_dh_k)
                            end
                            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                            end
                            l_dh_v = wasm_synth_alloc_local(s, "__wasi_mh_v")
                            l_dh_f = wasm_synth_alloc_local(s, "__wasi_mh_f")
                            wasm_synth_emit_dict_lookup(s, l_dh_r, l_dh_k, l_dh_v, l_dh_f)
                            wasm_emit_local_get(s.ws_code, l_dh_f)
                            s.ws_last_expr_is_float = 0
                            s.ws_last_expr_is_str = 0
                            s.ws_last_struct = ""
                        elif fname == "push" and s.ws_last_struct == ""
                            mtag_p = str(s.ws_code.len())
                            l_mp_r = wasm_synth_alloc_local(s, "__wasi_mp_r_" + mtag_p)
                            recv_is_fl = s.ws_last_expr_is_float_list
                            wasm_emit_local_set(s.ws_code, l_mp_r)
                            list_set(pos_box, 0, dp + 3)
                            l_mp_v = wasm_synth_alloc_local(s, "__wasi_mp_v_" + mtag_p)
                            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                                wasm_synth_compile_expr(s, toks, pos_box)
                                if recv_is_fl == 1 and s.ws_last_expr_is_float == 0
                                    wasm_emit_f64_convert_i64_s(s.ws_code)
                                    wasm_emit_i64_reinterpret_f64(s.ws_code)
                                end
                                if s.ws_last_expr_is_float == 1
                                    wasm_synth_mark_float_list(s, ident_name, 1)
                                end
                                if s.ws_last_expr_is_str == 1
                                    wasm_synth_mark_str_list(s, ident_name, 1)
                                end
                                wasm_emit_local_set(s.ws_code, l_mp_v)
                            else
                                wasm_emit_i64_const(s.ws_code, 0)
                                wasm_emit_local_set(s.ws_code, l_mp_v)
                            end
                            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                            end
                            wasm_synth_emit_list_push(s, l_mp_r, l_mp_v)
                            wasm_emit_local_get(s.ws_code, l_mp_r)
                            s.ws_last_expr_is_float = 0
                            s.ws_last_expr_is_str = 0
                            s.ws_last_struct = ""
                        else
                            // General trait/impl method call & sovereign dyn Trait dispatch
                            recv_st = s.ws_last_struct
                            mtag = str(s.ws_code.len())
                            l_mrecv = wasm_synth_alloc_local(s, "__wasi_m_recv_" + mtag)
                            wasm_emit_local_set(s.ws_code, l_mrecv)
                            list_set(pos_box, 0, dp + 3) // Consume '.', name, '('
                            m_alocs = list()
                            m_acnt = 0
                            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                                wasm_synth_compile_expr(s, toks, pos_box)
                                mal = wasm_synth_alloc_local(s, "__wasi_m_arg_" + mtag + "_" + str(m_acnt))
                                wasm_emit_local_set(s.ws_code, mal)
                                push(m_alocs, mal)
                                m_acnt = m_acnt + 1
                                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_COMMA()
                                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                                end
                            end
                            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                                list_set(pos_box, 0, get(pos_box, 0) + 1)
                            end
                            m_ret_f = 0
                            m_ret_s = 0
                            direct_fn = 0
                            if recv_st != "" and str_starts_with(recv_st, "dyn ") == 0
                                direct_fn = wasm_synth_find_function(s, recv_st + "_" + fname)
                            end
                            if direct_fn != 0
                                wasm_emit_local_get(s.ws_code, l_mrecv)
                                mai = 0
                                while mai < m_acnt
                                    wasm_emit_local_get(s.ws_code, m_alocs[mai])
                                    mai = mai + 1
                                end
                                wasm_emit_call(s.ws_code, direct_fn.wfn_index + s.ws_needs_wasi_print)
                                m_ret_f = direct_fn.wfn_returns_float
                                m_ret_s = direct_fn.wfn_returns_str
                            else
                                // Collect all registered structs with Type_fname function
                                cand_tids = list()
                                cand_fns = list()
                                csi = 0
                                while csi < s.ws_structs.len()
                                    csd = s.ws_structs[csi]
                                    cfn = wasm_synth_find_function(s, csd.wsd_name + "_" + fname)
                                    if cfn != 0
                                        push(cand_tids, csd.wsd_type_id)
                                        push(cand_fns, cfn)
                                    end
                                    csi = csi + 1
                                end
                                if cand_fns.len() == 1
                                    cf0 = cand_fns[0]
                                    wasm_emit_local_get(s.ws_code, l_mrecv)
                                    mai = 0
                                    while mai < m_acnt
                                        wasm_emit_local_get(s.ws_code, m_alocs[mai])
                                        mai = mai + 1
                                    end
                                    wasm_emit_call(s.ws_code, cf0.wfn_index + s.ws_needs_wasi_print)
                                    m_ret_f = cf0.wfn_returns_float
                                    m_ret_s = cf0.wfn_returns_str
                                elif cand_fns.len() >= 2
                                    // Sovereign dyn Trait runtime dispatch: inspect [l_mrecv - 8] type tag
                                    l_mtag = wasm_synth_alloc_local(s, "__wasi_m_tag")
                                    l_mres = wasm_synth_alloc_local(s, "__wasi_m_res")
                                    wasm_emit_i64_const(s.ws_code, 0)
                                    wasm_emit_local_set(s.ws_code, l_mres)
                                    wasm_emit_local_get(s.ws_code, l_mrecv)
                                    wasm_emit_i64_const(s.ws_code, 8)
                                    wasm_emit_i64_sub(s.ws_code)
                                    wasm_emit_i32_wrap_i64(s.ws_code)
                                    wasm_emit_i64_load(s.ws_code, 3, 0)
                                    wasm_emit_local_set(s.ws_code, l_mtag)
                                    dci = 0
                                    while dci < cand_fns.len()
                                        cf_d = cand_fns[dci]
                                        if cf_d.wfn_returns_float == 1 m_ret_f = 1 end
                                        if cf_d.wfn_returns_str == 1 m_ret_s = 1 end
                                        wasm_emit_local_get(s.ws_code, l_mtag)
                                        wasm_emit_i64_const(s.ws_code, (1415139397 << 32) | cand_tids[dci])
                                        wasm_emit_i64_eq(s.ws_code)
                                        wasm_emit_if(s.ws_code, WASM_TYPE_EMPTY)
                                            wasm_emit_local_get(s.ws_code, l_mrecv)
                                            mai = 0
                                            while mai < m_acnt
                                                wasm_emit_local_get(s.ws_code, m_alocs[mai])
                                                mai = mai + 1
                                            end
                                            wasm_emit_call(s.ws_code, cf_d.wfn_index + s.ws_needs_wasi_print)
                                            wasm_emit_local_set(s.ws_code, l_mres)
                                        wasm_emit_end(s.ws_code)
                                        dci = dci + 1
                                    end
                                    wasm_emit_local_get(s.ws_code, l_mres)
                                else
                                    ufcs_fn = wasm_synth_find_function(s, fname)
                                    if ufcs_fn != 0
                                        wasm_emit_local_get(s.ws_code, l_mrecv)
                                        mai = 0
                                        while mai < m_acnt
                                            wasm_emit_local_get(s.ws_code, m_alocs[mai])
                                            mai = mai + 1
                                        end
                                        wasm_emit_call(s.ws_code, ufcs_fn.wfn_index + s.ws_needs_wasi_print)
                                        m_ret_f = ufcs_fn.wfn_returns_float
                                        m_ret_s = ufcs_fn.wfn_returns_str
                                    else
                                        wasm_emit_i64_const(s.ws_code, 0)
                                    end
                                end
                            end
                            // Inter-procedural exception check after method call
                            l_mret = wasm_synth_alloc_local(s, "__wasi_call_ret")
                            wasm_emit_local_set(s.ws_code, l_mret)
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
                            end
                            wasm_emit_end(s.ws_code)
                            wasm_emit_local_get(s.ws_code, l_mret)
                            s.ws_last_struct = ""
                            s.ws_last_expr_is_float = m_ret_f
                            s.ws_last_expr_is_str = m_ret_s
                            s.ws_last_expr_is_float_list = 0
                            s.ws_last_expr_is_str_list = 0
                        end
                    else
                        list_set(pos_box, 0, dp + 2)
                        f_st_cur = s.ws_last_struct
                        f_off = wasm_synth_get_field_offset_for(s, f_st_cur, fname)
                        wasm_emit_i32_wrap_i64(s.ws_code)
                        wasm_emit_i64_load(s.ws_code, 3, f_off)
                        s.ws_last_expr_is_float = wasm_synth_is_float_field(s, f_st_cur, fname)
                        s.ws_last_expr_is_str = wasm_synth_is_str_field(s, f_st_cur, fname)
                        s.ws_last_expr_is_float_list = 0
                        s.ws_last_expr_is_str_list = 0
                        s.ws_last_struct = ""
                    end
                else
                    break
                end
            else
                break
            end
        end
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
    // WHY: Pratt level for comparison operators: ==, !=, <, <=, >, >=, in (i64, IEEE-754 f64, & LPST strings).
    // Produces a consistent 64-bit boolean (1 or 0). Non-float == and != compare LPST string bytes,
    // never raw pointers, so ("ab" + "c") == "abc" evaluates to 1.
    wasm_synth_expr_additive(s, toks, pos_box)
    lhs_f = s.ws_last_expr_is_float

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        k = toks[p].tok_kind
        txt_r = toks[p].tok_text

        if k == TOK_EQ() or k == TOK_NEQ() or k == TOK_LT() or k == TOK_LTE() or k == TOK_GT() or k == TOK_GTE()
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_additive(s, toks, pos_box)
            rhs_f = s.ws_last_expr_is_float
            if lhs_f == 1 or rhs_f == 1
                wasm_synth_emit_f64_binop(s, lhs_f, rhs_f, k, 1)
                lhs_f = 0
            elif k == TOK_EQ() or k == TOK_NEQ()
                l_eq_b = wasm_synth_alloc_local(s, "__wasi_rel_b")
                l_eq_a = wasm_synth_alloc_local(s, "__wasi_rel_a")
                l_eq_r = wasm_synth_alloc_local(s, "__wasi_rel_r")
                wasm_emit_local_set(s.ws_code, l_eq_b)
                wasm_emit_local_set(s.ws_code, l_eq_a)
                wasm_synth_emit_val_eq(s, l_eq_a, l_eq_b, l_eq_r)
                wasm_emit_local_get(s.ws_code, l_eq_r)
                if k == TOK_NEQ()
                    wasm_emit_i64_const(s.ws_code, 0)
                    wasm_emit_i64_eq(s.ws_code)
                    wasm_emit_i64_extend_i32_u(s.ws_code)
                end
                lhs_f = 0
            else
                if k == TOK_LT()
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
        elif k == TOK_KW_IN() or (k != TOK_STR() and txt_r == "in")
            list_set(pos_box, 0, p + 1)
            l_in_k = wasm_synth_alloc_local(s, "__wasi_in_k")
            l_in_d = wasm_synth_alloc_local(s, "__wasi_in_d")
            l_in_v = wasm_synth_alloc_local(s, "__wasi_in_v")
            l_in_f = wasm_synth_alloc_local(s, "__wasi_in_f")
            wasm_emit_local_set(s.ws_code, l_in_k)
            wasm_synth_expr_additive(s, toks, pos_box)
            wasm_emit_local_set(s.ws_code, l_in_d)
            wasm_synth_emit_dict_lookup(s, l_in_d, l_in_k, l_in_v, l_in_f)
            wasm_emit_local_get(s.ws_code, l_in_f)
            lhs_f = 0
            s.ws_last_expr_is_float = 0
            s.ws_last_expr_is_str = 0
        else
            break
    return 0

fn wasm_synth_expr_unary_not s toks pos_box
    // WHY: Handles logical negation (`not expr` / `!expr` / `নয় expr`) cleanly above relational level.
    p = get(pos_box, 0)
    if p < toks.len()
        t = toks[p]
        if t.tok_kind == TOK_BANG() or (t.tok_kind != TOK_STR() and (t.tok_text == "not" or t.tok_text == "!" or t.tok_text == "নয়"))
            list_set(pos_box, 0, p + 1)
            wasm_synth_expr_unary_not(s, toks, pos_box)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_eq(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
            s.ws_last_expr_is_float = 0
            s.ws_last_expr_is_str = 0
            return 0
        end
    end
    return wasm_synth_expr_relational(s, toks, pos_box)
end

fn wasm_synth_expr_logical_and s toks pos_box
    // WHY: Short-circuit logical conjunction (and / && / এবং) using WASM `if (result i64)`.
    // Guarantees RHS is NEVER evaluated when LHS is 0 (false).
    wasm_synth_expr_unary_not(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        p = get(pos_box, 0)
        t = toks[p]
        k = t.tok_kind
        txt = t.tok_text
        if k == TOK_AND() or (k != TOK_STR() and (txt == "and" or txt == "&&" or txt == "এবং"))
            list_set(pos_box, 0, p + 1)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_if(s.ws_code, WASM_TYPE_I64)
            s.ws_block_depth = s.ws_block_depth + 1
            wasm_synth_expr_unary_not(s, toks, pos_box)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
            wasm_emit_else(s.ws_code)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_end(s.ws_code)
            s.ws_block_depth = s.ws_block_depth - 1
            s.ws_last_expr_is_float = 0
            s.ws_last_expr_is_str = 0
        else
            break
    return 0

fn wasm_synth_expr_logical_or s toks pos_box
    // WHY: Short-circuit logical disjunction (or / || / অথবা) using WASM `if (result i64)`.
    // Guarantees RHS is NEVER evaluated when LHS is non-zero (true).
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
            wasm_emit_if(s.ws_code, WASM_TYPE_I64)
            s.ws_block_depth = s.ws_block_depth + 1
            wasm_emit_i64_const(s.ws_code, 1)
            wasm_emit_else(s.ws_code)
            wasm_synth_expr_logical_and(s, toks, pos_box)
            wasm_emit_i64_const(s.ws_code, 0)
            wasm_emit_i64_ne(s.ws_code)
            wasm_emit_i64_extend_i32_u(s.ws_code)
            wasm_emit_end(s.ws_code)
            s.ws_block_depth = s.ws_block_depth - 1
            s.ws_last_expr_is_float = 0
            s.ws_last_expr_is_str = 0
        else
            break
    return 0

fn wasm_synth_compile_expr s toks pos_box
    // WHY: Master expression evaluator entering at logical disjunction precedence level.
    return wasm_synth_expr_logical_or(s, toks, pos_box)

// ==============================================================================
// ── 8. Statement Synthesizer (Control Flow, Loops, Variables) ──────────────────
// ==============================================================================

fn wasm_try_compile_multi_assign s toks pos_box start_pos
    // WHY: Handles swap-safe multi-RHS (`a, b = b, a`) and single-RHS tuple destructuring (`p, q = pair()`).
    if start_pos + 2 >= toks.len() return 0 end
    if toks[start_pos].tok_kind != TOK_IDENT() return 0 end
    if toks[start_pos + 1].tok_kind != TOK_COMMA() and not (toks[start_pos + 1].tok_kind != TOK_STR() and toks[start_pos + 1].tok_text == ",")
        return 0
    end
    lhs_names = list()
    push(lhs_names, toks[start_pos].tok_text)
    mp = start_pos + 1
    while mp < toks.len()
        if toks[mp].tok_kind == TOK_COMMA() or (toks[mp].tok_kind != TOK_STR() and toks[mp].tok_text == ",")
            mp = mp + 1
            if mp < toks.len() and toks[mp].tok_kind == TOK_IDENT()
                push(lhs_names, toks[mp].tok_text)
                mp = mp + 1
            else
                return 0
            end
        else
            break
        end
    end
    if lhs_names.len() < 2 or mp >= toks.len() or toks[mp].tok_kind != TOK_ASSIGN()
        return 0
    end
    eq_ln = toks[mp].tok_span.span_start_line
    list_set(pos_box, 0, mp + 1)
    rhs_locs = list()
    base_tag = str(s.ws_code.len())
    wasm_synth_compile_expr(s, toks, pos_box)
    rl0 = wasm_synth_alloc_local(s, "__wasi_ma_" + base_tag + "_0")
    wasm_emit_local_set(s.ws_code, rl0)
    push(rhs_locs, rl0)
    while get(pos_box, 0) < toks.len()
        rp = get(pos_box, 0)
        if (toks[rp].tok_kind == TOK_COMMA() or (toks[rp].tok_kind != TOK_STR() and toks[rp].tok_text == ",")) and toks[rp].tok_span.span_start_line == eq_ln
            list_set(pos_box, 0, rp + 1)
            wasm_synth_compile_expr(s, toks, pos_box)
            rli = wasm_synth_alloc_local(s, "__wasi_ma_" + base_tag + "_" + str(rhs_locs.len()))
            wasm_emit_local_set(s.ws_code, rli)
            push(rhs_locs, rli)
        else
            break
        end
    end
    if rhs_locs.len() == 1
        // Single-RHS tuple unpack from linear-memory list header [len, cap, data_ptr]
        l_dp = wasm_synth_alloc_local(s, "__wasi_ma_dp_" + base_tag)
        wasm_emit_local_get(s.ws_code, rhs_locs[0])
        wasm_emit_i32_wrap_i64(s.ws_code)
        wasm_emit_i64_load(s.ws_code, 3, 16)
        wasm_emit_local_set(s.ws_code, l_dp)
        li = 0
        while li < lhs_names.len()
            wasm_emit_local_get(s.ws_code, l_dp)
            wasm_emit_i32_wrap_i64(s.ws_code)
            wasm_emit_i64_load(s.ws_code, 3, li * 8)
            vidx = wasm_synth_alloc_local(s, lhs_names[li])
            wasm_emit_local_set(s.ws_code, vidx)
            li = li + 1
        end
    else
        li = 0
        while li < lhs_names.len() and li < rhs_locs.len()
            wasm_emit_local_get(s.ws_code, rhs_locs[li])
            vidx = wasm_synth_alloc_local(s, lhs_names[li])
            wasm_emit_local_set(s.ws_code, vidx)
            li = li + 1
        end
    end
    return 1
end

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

