// ==============================================================================
// 👑 LIPI ZERO-OVERHEAD BARE-METAL STACK TRACE ENGINE (runtime_trace.lp)
// ⚡ 100% Pure x86_64 Machine Code | LSYM0 .rodata Table | Static-PIE ASLR-Safe
// 🏛️ Module: src/compiler/backend/targets/x86_64/runtime_trace.lp
// ==============================================================================
//
// WHY THIS MODULE:
// Provides human-readable function + line stack traces (`stack_trace()` builtin AND
// automatic stderr backtrace on uncaught `throw`) with ZERO runtime overhead on normal calls:
// - Compact LSYM0 table emitted in .rodata with relative code & rodata offsets (100% PIE-safe)
// - Frame-pointer walker over [rbp+8] with bounds validation against _lipi_stack_bottom
// - Throw-site trace snapshot preserved across defer/finally re-throws of the same exception
// - Zero libc, zero libunwind, zero DWARF runtime parser!
// ==============================================================================

fn x86_synth_rodata_push_u32 s val
    v = val
    if v < 0
        v = v + 4294967296
    end
    push(s.synth_rodata, v % 256)
    push(s.synth_rodata, (v / 256) % 256)
    push(s.synth_rodata, (v / 65536) % 256)
    push(s.synth_rodata, (v / 16777216) % 256)
    return 0
end

fn x86_synth_emit_lsym_rodata s
    // WHY: Serializes compact LSYM0 symbol & line table into .rodata right before ELF sizing.
    // All offsets are relative to code_base (s.synth_code[0]) and rodata_base (s.synth_rodata[0]),
    // guaranteeing zero runtime relocations under full Static-PIE Linux ASLR.
    fn_starts = list()
    fn_ends = list()
    fn_name_offs = list()
    fn_lines = list()
    fi = 0
    fn_total = s.synth_functions.len()
    while fi < fn_total
        fobj = s.synth_functions[fi]
        if fobj.fn_entry_offset >= 0 and fobj.fn_end_offset > fobj.fn_entry_offset and fobj.fn_name != ""
            n_ro = x86_synth_add_rodata_str(s, fobj.fn_name, 0)
            push(fn_starts, fobj.fn_entry_offset)
            push(fn_ends, fobj.fn_end_offset)
            push(fn_name_offs, n_ro)
            push(fn_lines, fobj.fn_decl_line)
        end
        fi = fi + 1
    end

    // Align LSYM0 header to 8-byte boundary
    while (s.synth_rodata.len() % 8) != 0
        push(s.synth_rodata, 0)
    end
    lsym_off = s.synth_rodata.len()

    // Magic: "LIPLSYM0" (0x304D59534C50494C)
    push(s.synth_rodata, 76) // 'L'
    push(s.synth_rodata, 73) // 'I'
    push(s.synth_rodata, 80) // 'P'
    push(s.synth_rodata, 76) // 'L'
    push(s.synth_rodata, 83) // 'S'
    push(s.synth_rodata, 89) // 'Y'
    push(s.synth_rodata, 77) // 'M'
    push(s.synth_rodata, 48) // '0'

    fcnt = fn_starts.len()
    lcnt = s.synth_line_pcs.len()
    x86_synth_rodata_push_u32(s, fcnt)
    x86_synth_rodata_push_u32(s, lcnt)

    // Function entries (24 bytes each: start_off, end_off, name_ro_off, decl_line, reserved u64)
    i = 0
    while i < fcnt
        x86_synth_rodata_push_u32(s, fn_starts[i])
        x86_synth_rodata_push_u32(s, fn_ends[i])
        x86_synth_rodata_push_u32(s, fn_name_offs[i])
        x86_synth_rodata_push_u32(s, fn_lines[i])
        x86_synth_rodata_push_u32(s, 0)
        x86_synth_rodata_push_u32(s, 0)
        i = i + 1
    end

    // Line entries (8 bytes each: pc_off, line_num; monotonically sorted by pc_off)
    li = 0
    while li < lcnt
        x86_synth_rodata_push_u32(s, s.synth_line_pcs[li])
        x86_synth_rodata_push_u32(s, s.synth_line_nums[li])
        li = li + 1
    end
    return lsym_off
end

fn x86_synth_emit__lipi_lsym_ptrs s
    // WHY: Returns Static-PIE RIP-relative addresses of LSYM0 table, code base, rodata base,
    // and dedicated collision-free __lipi_last_trace_ptr RW slot (>= 512) in rax, rcx, rdx, rsi.
    off = s.synth_code.len()
    s.synth_lsym_ptrs_off = off
    x86_synth_register_helper_fn(s, "_lipi_lsym_ptrs", off)
    x86_synth_emit_bytes(s, [
        72, 184, 0, 0, 0, 0, 0, 0, 0, 0,
        72, 185, 0, 0, 0, 0, 0, 0, 0, 0,
        72, 186, 0, 0, 0, 0, 0, 0, 0, 0,
        72, 190, 0, 0, 0, 0, 0, 0, 0, 0,
        195
    ])
    return off
end

fn x86_synth_emit__lipi_trace_capture_into s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_trace_capture_into", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 73, 137, 252, 73, 137, 245])
    x86_synth_emit_call_helper(s, "_lipi_stack_bottom")
    x86_synth_emit_bytes(s, [73, 137, 198, 49, 219, 131, 251, 16, 115, 60, 77, 133, 228, 116, 55, 65, 246, 196, 7, 117, 49, 73, 57, 228, 118, 44, 77, 133, 246, 116, 5, 77, 57, 244, 115, 34, 73, 139, 68, 36, 8, 72, 61, 0, 16, 0, 0, 114, 21, 73, 137, 68, 221, 0, 255, 195, 73, 139, 4, 36, 76, 57, 224, 118, 5, 73, 137, 196, 235, 191, 137, 216, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off
end

fn x86_synth_emit__lipi_trace_save_throw s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_trace_save_throw", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 87, 86, 65, 82, 65, 84, 65, 85, 72, 131, 236, 8])
    x86_synth_emit_call_helper(s, "_lipi_lsym_ptrs")
    x86_synth_emit_bytes(s, [73, 137, 244, 77, 139, 44, 36, 77, 133, 237, 117, 79, 49, 255, 190, 0, 16, 0, 0, 186, 3, 0, 0, 0, 65, 186, 34, 0, 0, 0, 73, 199, 192, 255, 255, 255, 255, 69, 49, 201, 184, 9, 0, 0, 0, 15, 5, 72, 61, 0, 16, 0, 0, 118, 100, 72, 137, 193, 49, 192, 240, 73, 15, 177, 12, 36, 116, 20, 73, 137, 197, 72, 137, 207, 190, 0, 16, 0, 0, 184, 11, 0, 0, 0, 15, 5, 235, 3, 73, 137, 205, 72, 139, 125, 248, 73, 131, 125, 0, 0, 116, 9, 73, 57, 189, 248, 0, 0, 0, 116, 44, 73, 137, 189, 248, 0, 0, 0, 72, 139, 69, 16, 73, 137, 69, 8, 72, 139, 125, 0, 73, 141, 117, 16])
    x86_synth_emit_call_helper(s, "_lipi_trace_capture_into")
    x86_synth_emit_bytes(s, [131, 248, 15, 118, 5, 184, 15, 0, 0, 0, 255, 192, 73, 137, 69, 0, 72, 131, 196, 8, 65, 93, 65, 92, 65, 90, 94, 95, 93, 195])
    return off
end

fn x86_synth_emit__lipi_trace_format_rips s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_trace_format_rips", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 56, 72, 137, 125, 184, 72, 137, 117, 176])
    x86_synth_emit_call_helper(s, "_lipi_lsym_ptrs")
    x86_synth_emit_bytes(s, [72, 137, 69, 208, 72, 137, 77, 200, 72, 137, 85, 192, 191, 0, 1, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_new")
    x86_synth_emit_bytes(s, [72, 137, 69, 168, 76, 139, 101, 208, 77, 133, 228, 15, 132, 202, 1, 0, 0, 72, 184, 76, 73, 80, 76, 83, 89, 77, 48, 73, 57, 4, 36, 15, 133, 182, 1, 0, 0, 49, 219, 72, 59, 93, 176, 15, 131, 170, 1, 0, 0, 72, 139, 69, 184, 76, 139, 44, 216, 72, 139, 77, 200, 73, 57, 205, 15, 134, 141, 1, 0, 0, 73, 41, 205, 73, 255, 205, 76, 139, 101, 208, 69, 139, 116, 36, 8, 77, 141, 124, 36, 16, 49, 201, 69, 49, 192, 69, 49, 201, 76, 57, 241, 115, 43, 72, 137, 200, 72, 107, 192, 24, 65, 139, 20, 7, 73, 57, 213, 114, 22, 65, 139, 84, 7, 4, 73, 57, 213, 115, 12, 69, 139, 68, 7, 8, 69, 139, 76, 7, 12, 235, 5, 72, 255, 193, 235, 208, 69, 133, 192, 15, 132, 56, 1, 0, 0, 76, 139, 101, 208, 65, 139, 68, 36, 8, 72, 107, 192, 24, 77, 141, 124, 4, 16, 69, 139, 116, 36, 12, 69, 133, 246, 116, 53, 49, 201, 76, 137, 242, 69, 49, 210, 72, 57, 209, 115, 32, 72, 141, 4, 17, 72, 209, 232, 69, 139, 28, 199, 77, 57, 235, 119, 11, 69, 139, 84, 199, 4, 72, 141, 72, 1, 235, 224, 72, 137, 194, 235, 219, 69, 133, 210, 116, 3, 69, 137, 209, 72, 139, 69, 192, 76, 1, 192, 72, 137, 69, 160, 77, 137, 206, 76, 139, 125, 168, 76, 137, 255, 190, 32, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 32, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 97, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 116, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 32, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 72, 139, 117, 160])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_str")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 32, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 40, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 108, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 105, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 110, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 101, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 32, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 247])
    x86_synth_emit_call_helper(s, "_lipi_int_to_str")
    x86_synth_emit_bytes(s, [76, 137, 255, 72, 137, 198])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_str")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 41, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [76, 137, 255, 190, 10, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_buf_write_byte")
    x86_synth_emit_bytes(s, [72, 255, 195, 233, 76, 254, 255, 255, 72, 139, 125, 168])
    x86_synth_emit_call_helper(s, "_lipi_buf_to_str")
    x86_synth_emit_bytes(s, [73, 137, 196, 72, 139, 125, 168])
    x86_synth_emit_call_helper(s, "_lipi_buf_free")
    x86_synth_emit_bytes(s, [76, 137, 224, 72, 131, 196, 56, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off
end

fn x86_synth_emit__lipi_stack_trace s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_stack_trace", off)
    x86_synth_register_helper_fn(s, "stack_trace", off)
    x86_synth_register_helper_fn(s, "backtrace", off)
    x86_synth_register_helper_fn(s, "স্ট্যাক_ট্রেস", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 72, 129, 236, 136, 0, 0, 0])
    x86_synth_emit_call_helper(s, "_lipi_lsym_ptrs")
    x86_synth_emit_bytes(s, [76, 139, 38, 77, 133, 228, 116, 29, 73, 139, 52, 36, 72, 133, 246, 116, 20, 73, 199, 4, 36, 0, 0, 0, 0, 73, 141, 124, 36, 8])
    x86_synth_emit_call_helper(s, "_lipi_trace_format_rips")
    x86_synth_emit_bytes(s, [235, 45, 72, 139, 69, 8, 72, 137, 4, 36, 72, 139, 125, 0, 72, 141, 116, 36, 8])
    x86_synth_emit_call_helper(s, "_lipi_trace_capture_into")
    x86_synth_emit_bytes(s, [131, 248, 15, 118, 5, 184, 15, 0, 0, 0, 255, 192, 72, 137, 231, 72, 137, 198])
    x86_synth_emit_call_helper(s, "_lipi_trace_format_rips")
    x86_synth_emit_bytes(s, [72, 129, 196, 136, 0, 0, 0, 65, 92, 93, 195])
    return off
end

fn x86_synth_emit__lipi_exc_print_unhandled s
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_exc_print_unhandled", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 65, 84, 72, 131, 236, 24, 73, 137, 252, 199, 4, 36, 85, 110, 99, 97, 199, 68, 36, 4, 117, 103, 104, 116, 199, 68, 36, 8, 32, 101, 120, 99, 199, 68, 36, 12, 101, 112, 116, 105, 199, 68, 36, 16, 111, 110, 58, 32, 191, 2, 0, 0, 0, 72, 137, 230, 186, 20, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 76, 137, 231])
    x86_synth_emit_call_helper(s, "_lipi_ensure_str")
    x86_synth_emit_bytes(s, [72, 137, 198, 139, 80, 248, 191, 2, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 199, 4, 36, 10, 83, 116, 97, 199, 68, 36, 4, 99, 107, 32, 116, 199, 68, 36, 8, 114, 97, 99, 101, 102, 199, 68, 36, 12, 58, 10, 191, 2, 0, 0, 0, 72, 137, 230, 186, 14, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5])
    x86_synth_emit_call_helper(s, "_lipi_stack_trace")
    x86_synth_emit_bytes(s, [72, 137, 198, 139, 80, 248, 191, 2, 0, 0, 0, 184, 1, 0, 0, 0, 15, 5, 191, 1, 0, 0, 0, 184, 231, 0, 0, 0, 15, 5, 244])
    return off
end

fn x86_synth_emit_all_trace_helpers s
    x86_synth_emit__lipi_lsym_ptrs(s)
    x86_synth_emit__lipi_trace_capture_into(s)
    x86_synth_emit__lipi_trace_save_throw(s)
    x86_synth_emit__lipi_trace_format_rips(s)
    x86_synth_emit__lipi_stack_trace(s)
    x86_synth_emit__lipi_exc_print_unhandled(s)
    return 0
end
