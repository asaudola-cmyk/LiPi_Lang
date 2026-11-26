// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN ARM64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/arm64/synthesizer.lp
// ==============================================================================

include "src/compiler/backend/targets/arm64/codegen_core.lp"
include "src/compiler/backend/targets/arm64/runtime_parity.lp"
include "src/compiler/backend/targets/arm64/codegen_expr.lp"
include "src/compiler/backend/targets/arm64/codegen_stmt.lp"
include "src/compiler/backend/targets/arm64/arm64_simd.lp"

// ── 8b. AArch64 Dynamic Runtime Helpers (List, File I/O) ─────────────────────

fn arm64_synth_emit_list_create_helper s
    // WHY: Native AArch64 32-byte list header {len, cap, data_ptr, magic=0} constructor.
    // Magic word 0 at [+24] guarantees zero collision with DICT0 magic 0x44494354.
    // Input: X0 = initial len. Output: X0 = pointer to 32-byte list header.
    off = s.synth_code.len()
    s.a64_list_create_off = off
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 32)
    // str x19, [sp, #16]; str x20, [sp, #24]
    arm64_synth_emit32(s, 4177526784 | (2 << 10) | (31 << 5) | 19)
    arm64_synth_emit32(s, 4177526784 | (3 << 10) | (31 << 5) | 20)
    arm64_emit_mov_reg(s, 19, 0)         // X19 = initial len
    arm64_emit_movz_x(s, 20, 16, 0)      // X20 = default cap 16
    arm64_emit_cmp_x(s, 19, 20)
    arm64_emit_b_cond(s, 13, 2)          // b.le +2 words (skip add x20, x19, x19)
    arm64_emit_add_x(s, 20, 19, 19)      // cap = len * 2
    arm64_emit_add_x(s, 0, 20, 20)       // X0 = cap * 2
    arm64_emit_add_x(s, 0, 0, 0)         // X0 = cap * 4
    arm64_emit_add_x(s, 0, 0, 0)         // X0 = cap * 8
    arm64_emit_add_imm(s, 0, 0, 32)      // add x0, x0, #32
    arm64_synth_emit_call_alloc(s)
    // Store [X0 + 0] = X19 (len), [X0 + 8] = X20 (cap), [X0 + 16] = X0 + 32 (data_ptr), [X0 + 24] = 0
    arm64_emit_str_x_off(s, 19, 0, 0)
    arm64_emit_str_x_off(s, 20, 0, 8)
    arm64_emit_add_imm(s, 2, 0, 32)
    arm64_emit_str_x_off(s, 2, 0, 16)
    arm64_emit_str_x_off(s, 31, 0, 24)
    // ldr x19, [sp, #16]; ldr x20, [sp, #24]
    arm64_synth_emit32(s, 4181721088 | (2 << 10) | (31 << 5) | 19)
    arm64_synth_emit32(s, 4181721088 | (3 << 10) | (31 << 5) | 20)
    arm64_emit_ldp_post(s, 29, 30, 31, 32)
    arm64_emit_ret(s)
    return off

fn arm64_synth_emit_list_push_helper s
    // WHY: Appends X1 to list header X0, growing backing buffer exponentially via __alloc.
    off = s.synth_code.len()
    s.a64_list_push_off = off
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 64)
    arm64_synth_emit32(s, 4177526784 | (2 << 10) | (31 << 5) | 19)
    arm64_synth_emit32(s, 4177526784 | (3 << 10) | (31 << 5) | 20)
    arm64_synth_emit32(s, 4177526784 | (4 << 10) | (31 << 5) | 21)
    arm64_synth_emit32(s, 4177526784 | (5 << 10) | (31 << 5) | 22)
    arm64_synth_emit32(s, 4177526784 | (6 << 10) | (31 << 5) | 23)
    arm64_emit_mov_reg(s, 19, 0)         // X19 = hdr
    arm64_emit_mov_reg(s, 20, 1)         // X20 = val
    arm64_synth_emit32(s, 4181721088 | (0 << 10) | (19 << 5) | 22) // ldr x22, [x19, #0] (len)
    arm64_synth_emit32(s, 4181721088 | (1 << 10) | (19 << 5) | 23) // ldr x23, [x19, #8] (cap)
    arm64_synth_emit32(s, 4181721088 | (2 << 10) | (19 << 5) | 21) // ldr x21, [x19, #16] (data)
    arm64_emit_cmp_x(s, 22, 23)
    blt_have_cap = s.synth_code.len()
    arm64_emit_b_cond(s, 11, 0)          // b.lt .have_cap
    arm64_emit_cmp_x(s, 23, 31)
    arm64_emit_b_cond(s, 12, 2)          // b.gt +2 words
    arm64_emit_movz_x(s, 23, 8, 0)
    arm64_emit_add_x(s, 23, 23, 23)      // new_cap = cap * 2
    arm64_emit_add_x(s, 0, 23, 23)
    arm64_emit_add_x(s, 0, 0, 0)
    arm64_emit_add_x(s, 0, 0, 0)         // new_cap * 8
    arm64_synth_emit_call_alloc(s)       // X0 = new_data
    arm64_emit_movz_x(s, 9, 0, 0)        // X9 = i = 0
    copy_loop_off = s.synth_code.len()
    arm64_emit_cmp_x(s, 9, 22)
    bge_copy_done = s.synth_code.len()
    arm64_emit_b_cond(s, 10, 0)          // b.ge .copy_done
    arm64_emit_add_x(s, 10, 9, 9)
    arm64_emit_add_x(s, 10, 10, 10)
    arm64_emit_add_x(s, 10, 10, 10)      // X10 = i * 8
    arm64_emit_add_x(s, 11, 21, 10)      // &old[i]
    arm64_synth_emit32(s, 4181721088 | (0 << 10) | (11 << 5) | 12) // ldr x12, [x11, #0]
    arm64_emit_add_x(s, 11, 0, 10)       // &new[i]
    arm64_synth_emit32(s, 4177526784 | (0 << 10) | (11 << 5) | 12) // str x12, [x11, #0]
    arm64_synth_emit32(s, 2432696320 | (1 << 10) | (9 << 5) | 9)   // add x9, x9, #1
    arm64_emit_b(s, (copy_loop_off - s.synth_code.len()) / 4)
    copy_done_off = s.synth_code.len()
    cw = (copy_done_off - bge_copy_done) / 4
    arm64_synth_patch_u32(s, bge_copy_done, 1409286144 | ((cw & 524287) << 5) | 10)
    arm64_emit_mov_reg(s, 21, 0)         // X21 = new_data
    arm64_synth_emit32(s, 4177526784 | (1 << 10) | (19 << 5) | 23) // str x23, [x19, #8]
    arm64_synth_emit32(s, 4177526784 | (2 << 10) | (19 << 5) | 21) // str x21, [x19, #16]
    have_cap_off = s.synth_code.len()
    hw = (have_cap_off - blt_have_cap) / 4
    arm64_synth_patch_u32(s, blt_have_cap, 1409286144 | ((hw & 524287) << 5) | 11)
    arm64_emit_add_x(s, 10, 22, 22)
    arm64_emit_add_x(s, 10, 10, 10)
    arm64_emit_add_x(s, 10, 10, 10)      // len * 8
    arm64_emit_add_x(s, 10, 21, 10)      // &data[len]
    arm64_synth_emit32(s, 4177526784 | (0 << 10) | (10 << 5) | 20) // str x20, [x10, #0]
    arm64_synth_emit32(s, 2432696320 | (1 << 10) | (22 << 5) | 22) // add x22, x22, #1
    arm64_synth_emit32(s, 4177526784 | (0 << 10) | (19 << 5) | 22) // str x22, [x19, #0]
    arm64_emit_mov_reg(s, 0, 19)         // return hdr
    arm64_synth_emit32(s, 4181721088 | (6 << 10) | (31 << 5) | 23)
    arm64_synth_emit32(s, 4181721088 | (5 << 10) | (31 << 5) | 22)
    arm64_synth_emit32(s, 4181721088 | (4 << 10) | (31 << 5) | 21)
    arm64_synth_emit32(s, 4181721088 | (3 << 10) | (31 << 5) | 20)
    arm64_synth_emit32(s, 4181721088 | (2 << 10) | (31 << 5) | 19)
    arm64_emit_ldp_post(s, 29, 30, 31, 64)
    arm64_emit_ret(s)
    return off

fn arm64_synth_emit_file_write_helper s
    // WHY: Native Linux AArch64 file writer using SYS_openat (56), SYS_write (64), SYS_close (57).
    // Inputs: X0 = path_ptr, X1 = data_ptr, X2 = data_len.
    off = s.synth_code.len()
    s.a64_file_write_off = off
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 32)
    arm64_emit_mov_reg(s, 19, 1)         // X19 = data_ptr
    arm64_emit_mov_reg(s, 20, 2)         // X20 = data_len
    arm64_emit_mov_reg(s, 1, 0)          // X1 = pathname
    // mov x0, #-100 (AT_FDCWD: 0x92800C60 = 2457865312)
    arm64_synth_emit32(s, 2457865312)
    arm64_emit_movz_x(s, 2, 577, 0)      // O_WRONLY|O_CREAT|O_TRUNC
    arm64_emit_movz_x(s, 3, 420, 0)      // 0644
    arm64_emit_movz_x(s, 8, 56, 0)       // SYS_openat = 56
    arm64_emit_svc(s, 0)
    arm64_emit_mov_reg(s, 21, 0)         // X21 = fd
    arm64_emit_mov_reg(s, 1, 19)         // X1 = data_ptr
    arm64_emit_mov_reg(s, 2, 20)         // X2 = data_len
    arm64_emit_movz_x(s, 8, 64, 0)       // SYS_write = 64
    arm64_emit_svc(s, 0)
    arm64_emit_mov_reg(s, 0, 21)         // X0 = fd
    arm64_emit_movz_x(s, 8, 57, 0)       // SYS_close = 57
    arm64_emit_svc(s, 0)
    arm64_emit_mov_reg(s, 0, 20)         // Return bytes written
    arm64_emit_ldp_post(s, 29, 30, 31, 32)
    arm64_emit_ret(s)
    return off

// ── 9. Master Program Synthesizer Entry Point ──────────────────────────────────

fn arm64_synth_compile_program tokens
    // WHY: Master orchestration entry point. Transforms complete token stream into
    // relocatable ARM64 machine code, sets up top-level stack frames, patches string relocations
    // against the Linux ELF virtual address space (0x400000+), and resolves call sites.
    s = arm64_synth_new()

    // 1. Zero initial frame pointer X29 so LSYM0 stack_trace() terminates cleanly at root,
    // emit top-level stack frame prologue, and clear exception registers (X27=flag, X28=value).
    arm64_emit_movz_x(s, 29, 0, 0)
    arm64_emit_prologue(s)
    arm64_emit_movz_x(s, 27, 0, 0)
    arm64_emit_movz_x(s, 28, 0, 0)

    // 2. Prescan top-level closure-mutated locals and synthesize all functions, structs, and statements
    s.a64_boxed_vars = arm64_prescan_boxed_vars(tokens, 0, 0, 0 - 1)
    pos_box = [0]
    has_top_level = 0
    while get(pos_box, 0) < tokens.len()
        cur_pos = get(pos_box, 0)
        cur_k = tokens[cur_pos].tok_kind
        if cur_k == TOK_EOF()
            break

        tok_item = tokens[cur_pos]
        is_fn_tok = 0
        if tok_item.tok_kind == TOK_KW_FN() or tok_item.tok_kind == TOK_DIR_FN() or tok_item.tok_kind == TOK_KW_COMPONENT()
            is_fn_tok = 1
        if tok_item.tok_kind == TOK_IDENT() and (tok_item.tok_text == "fn" or tok_item.tok_text == "কাজ" or tok_item.tok_text == "@fn" or tok_item.tok_text == "component" or tok_item.tok_text == "উপাদান")
            is_fn_tok = 1
        if tok_item.tok_kind == TOK_KW_STRUCT() or tok_item.tok_kind == TOK_DIR_STRUCT()
            is_fn_tok = 1
        if tok_item.tok_kind == TOK_IDENT() and (tok_item.tok_text == "struct" or tok_item.tok_text == "গঠন" or tok_item.tok_text == "@struct")
            is_fn_tok = 1

        if is_fn_tok == 0 and tok_item.tok_kind != TOK_NEWLINE() and tok_item.tok_kind != TOK_SEMI()
            has_top_level = 1

        arm64_synth_compile_statement(s, tokens, pos_box)

    // 3. Auto-call main()/মূল() whenever defined and not already invoked at top-level
    has_main = 0
    main_name = ""
    if s.a64_called_main == 0
        fi = 0
        while fi < s.synth_functions.len()
            fn_candidate = s.synth_functions[fi].fn_name
            if fn_candidate == "main" or fn_candidate == "মূল"
                has_main = 1
                main_name = fn_candidate
            fi = fi + 1
        if has_main == 1
            call_off = s.synth_code.len()
            arm64_emit_bl(s, 0) // Placeholder
            call_rel = Arm64CallReloc()
            call_rel.a64_cr_patch_offset = call_off
            call_rel.a64_cr_target_name = main_name
            push(s.synth_call_relocs, call_rel)

    // 4. Top-level exit epilogue
    arm64_emit_defers(s, tokens)
    if has_main == 0 and s.a64_called_main == 0
        arm64_emit_movz_x(s, 0, 0, 0) // exit code 0
    if s.a64_freestanding == 1
        // Bare-metal ARM64 halt loop (wfi; b -4) — ZERO Linux SVC instructions!
        arm64_synth_emit32(s, 3573751935) // wfi (0xD503207F)
        arm64_emit_b(s, 0 - 1)            // b -4
    else
        // Exit whole process cleanly via Linux SYS_exit_group (syscall 94 on AArch64) with status code in X0
        arm64_emit_movz_x(s, 8, 94, 0)
        arm64_emit_svc(s, 0)
    end

    // 5. Emit print_int, tagged print, and LSYM0 stack_trace helpers if required
    if s.a64_needs_print_tagged == 1
        s.synth_needs_print_int = 1
    end
    if s.a64_needs_stack_trace == 1
        s.a64_needs_buf = 1
        s.synth_needs_alloc = 1
    end
    if s.synth_needs_print_int == 1
        arm64_synth_emit_print_int_helper(s)
    if s.a64_needs_print_uint == 1
        arm64_synth_emit_print_uint_helper(s)
    if s.a64_needs_print_tagged == 1
        arm64_synth_emit_print_tagged_helpers(s)
    if s.a64_needs_stack_trace == 1
        arm64_synth_emit_stack_trace_helper(s)

    // 5b. Emit sovereign alloc, list_create, list_push, dict, throw_null, bytebuffer, and file_write helpers if required
    if s.a64_needs_list_push == 1
        s.synth_needs_alloc = 1
        arm64_synth_emit_list_push_helper(s)
    if s.a64_needs_list_create == 1
        s.synth_needs_alloc = 1
        arm64_synth_emit_list_create_helper(s)
    if s.a64_needs_dict == 1
        s.synth_needs_alloc = 1
        arm64_synth_emit_dict_helpers(s)
    if s.a64_needs_throw_null == 1
        arm64_synth_emit_throw_null_helper(s)
    if s.a64_needs_buf == 1
        s.synth_needs_alloc = 1
        arm64_synth_emit_buf_helpers(s)
    if s.a64_needs_file_write == 1
        arm64_synth_emit_file_write_helper(s)
    if s.synth_needs_alloc == 1
        arm64_synth_emit_alloc_helper(s)

    // 6. Resolve Inter-Procedural Call Relocations (BL disp26)
    ci = 0
    while ci < s.synth_call_relocs.len()
        cr = s.synth_call_relocs[ci]
        resolved_addr = 0
        found_rel = 0
        if cr.a64_cr_target_name == "__print_int"
            resolved_addr = s.synth_print_int_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__print_uint"
            resolved_addr = s.a64_print_uint_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__print_str"
            resolved_addr = s.a64_print_str_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__print_float"
            resolved_addr = s.a64_print_float_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__print_tagged"
            resolved_addr = s.a64_print_tagged_off
            found_rel = 1
        elif cr.a64_cr_target_name == "_lipi_throw_null_deref"
            resolved_addr = s.a64_throw_null_off
            found_rel = 1
        elif cr.a64_cr_target_name == "_lipi_stack_trace"
            resolved_addr = s.a64_stack_trace_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__alloc"
            resolved_addr = s.synth_alloc_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__list_create"
            resolved_addr = s.a64_list_create_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__list_push"
            resolved_addr = s.a64_list_push_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__file_write"
            resolved_addr = s.a64_file_write_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__dict_hash"
            resolved_addr = s.a64_dict_hash_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__dict_key_eq"
            resolved_addr = s.a64_dict_eq_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__dict_new"
            resolved_addr = s.a64_dict_new_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__dict_set"
            resolved_addr = s.a64_dict_set_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__dict_get"
            resolved_addr = s.a64_dict_get_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__dict_has"
            resolved_addr = s.a64_dict_has_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__dict_del"
            resolved_addr = s.a64_dict_del_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__container_get"
            resolved_addr = s.a64_cont_get_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__container_set"
            resolved_addr = s.a64_cont_set_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__buf_new"
            resolved_addr = s.a64_buf_new_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__buf_write_byte"
            resolved_addr = s.a64_buf_wbyte_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__buf_write_str"
            resolved_addr = s.a64_buf_wstr_off
            found_rel = 1
        elif cr.a64_cr_target_name == "__buf_to_str"
            resolved_addr = s.a64_buf_tostr_off
            found_rel = 1
        else
            k = 0
            while k < s.synth_functions.len()
                fn_item = s.synth_functions[k]
                if fn_item.fn_name == cr.a64_cr_target_name
                    resolved_addr = fn_item.fn_entry_offset
                    found_rel = 1
                k = k + 1

        if found_rel == 0
            s.a64_error_count = s.a64_error_count + 1
            if s.a64_error_msg == ""
                s.a64_error_msg = "Undefined function in arm64 target: " + cr.a64_cr_target_name
            end
            say "❌ [ARM64 Backend Error]: Undefined function '" + cr.a64_cr_target_name + "'"
        else
            rel_words = (resolved_addr - cr.a64_cr_patch_offset) / 4
            imm26 = rel_words & 67108863
            bl_word = 2483027968 | imm26
            arm64_synth_patch_u32(s, cr.a64_cr_patch_offset, bl_word)
        end
        ci = ci + 1

    // 7. Emit LSYM0 symbol table in .rodata (hosted mode), then resolve 64-Bit Virtual Memory String & Strict-W^X RW Heap Relocations
    lsym_ro_off = 0
    if s.a64_freestanding == 0
        lsym_ro_off = arm64_synth_emit_lsym_rodata(s)
    end
    total_code_size = s.synth_code.len()
    code_base_vaddr = 4194536 // 0x4000E8
    rodata_base_vaddr = code_base_vaddr + total_code_size

    if s.a64_lsym_patch_lsym >= 0
        arm64_synth_patch_mov_imm64(s, s.a64_lsym_patch_lsym, 22, rodata_base_vaddr + lsym_ro_off)
    end
    if s.a64_lsym_patch_code >= 0
        arm64_synth_patch_mov_imm64(s, s.a64_lsym_patch_code, 23, code_base_vaddr)
    end
    if s.a64_lsym_patch_ro >= 0
        arm64_synth_patch_mov_imm64(s, s.a64_lsym_patch_ro, 24, rodata_base_vaddr)
    end

    if s.synth_needs_alloc == 1 and s.a64_alloc_rw_patch_off >= 0
        rx_tot = 232 + total_code_size + s.synth_rodata.len()
        rw_f_off = ((rx_tot + 4095) / 4096) * 4096
        rw_vaddr_target = 4259840 + rw_f_off
        arm64_synth_patch_mov_imm64(s, s.a64_alloc_rw_patch_off, 1, rw_vaddr_target)
    end

    ri = 0
    while ri < s.synth_str_relocs.len()
        rel = s.synth_str_relocs[ri]
        target_vaddr = rodata_base_vaddr + rel.sr_rodata_offset
        arm64_synth_patch_mov_imm64(s, rel.sr_patch_offset, rel.sr_reg, target_vaddr)
        ri = ri + 1

    return s

// ── 10. ELF64 AArch64 Container Header Generator (Strict W^X 3-PHDR Layout) ─

fn arm64_elf_emit_executable code_bytes rodata_bytes out_path
    // WHY: Packages AArch64 machine instructions and .rodata into a strict W^X Linux ELF64
    // executable (0 RWE segments): PHDR 0 = RX (5), PHDR 1 = RW (6), PHDR 2 = PT_GNU_STACK (6).
    // Base Virtual Address: 0x400000; Header: 64 + 3*56 = 232 bytes; Entry: 0x4000E8 (4194536).
    total_hdr_size = 232
    code_size = code_bytes.len()
    rodata_size = rodata_bytes.len()
    rx_size = total_hdr_size + code_size + rodata_size
    rem_rx = rx_size % 4096
    rx_pad = 0
    if rem_rx != 0
        rx_pad = 4096 - rem_rx
    end
    rw_file_off = rx_size + rx_pad
    rw_vaddr = 4259840 + rw_file_off // 0x410000 + rw_file_off (congruent mod 64KB)
    rw_size = 64
    base_vaddr = 4194304   // 0x400000
    entry_vaddr = 4194536  // 0x4000E8 (0x400000 + 232)

    elf = list()

    // ── 1. ELF64 Header (64 bytes) ──────────────────────────────────────────
    push(elf, 127) push(elf, 69) push(elf, 76) push(elf, 70) // \x7FELF
    push(elf, 2)   push(elf, 1)  push(elf, 1)  push(elf, 0)  // 64-bit LE v1 SysV
    push(elf, 0)   push(elf, 0)  push(elf, 0)  push(elf, 0)
    push(elf, 0)   push(elf, 0)  push(elf, 0)  push(elf, 0)

    // e_type: ET_EXEC (2), e_machine: EM_AARCH64 (183), e_version: 1
    push(elf, 2)   push(elf, 0)
    push(elf, 183) push(elf, 0)
    push(elf, 1)   push(elf, 0)  push(elf, 0)  push(elf, 0)

    // e_entry: 0x4000E8 (4194536) (8 bytes)
    push(elf, 232) push(elf, 0) push(elf, 64) push(elf, 0)
    push(elf, 0)   push(elf, 0) push(elf, 0)  push(elf, 0)

    // e_phoff: 64 (8 bytes), e_shoff: 0 (8 bytes), e_flags: 0 (4 bytes)
    push(elf, 64) push(elf, 0) push(elf, 0) push(elf, 0)
    push(elf, 0)  push(elf, 0) push(elf, 0) push(elf, 0)
    push(elf, 0)  push(elf, 0) push(elf, 0) push(elf, 0)
    push(elf, 0)  push(elf, 0) push(elf, 0) push(elf, 0)
    push(elf, 0)  push(elf, 0) push(elf, 0) push(elf, 0)

    // e_ehsize: 64, e_phentsize: 56, e_phnum: 3, e_shentsize: 0, e_shnum: 0, e_shstrndx: 0
    push(elf, 64) push(elf, 0)
    push(elf, 56) push(elf, 0)
    push(elf, 3)  push(elf, 0)
    push(elf, 0)  push(elf, 0)
    push(elf, 0)  push(elf, 0)
    push(elf, 0)  push(elf, 0)

    // ── 2. Program Header 0: PT_LOAD Strict RX (PF_R | PF_X = 5) ─────────────
    push(elf, 1) push(elf, 0) push(elf, 0) push(elf, 0) // PT_LOAD
    push(elf, 5) push(elf, 0) push(elf, 0) push(elf, 0) // PF_R | PF_X (5)
    push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_offset = 0
    push(elf, 0) push(elf, 0) push(elf, 64) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_vaddr = 0x400000
    push(elf, 0) push(elf, 0) push(elf, 64) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_paddr = 0x400000
    push(elf, rx_size & 255) push(elf, (rx_size / 256) & 255) push(elf, (rx_size / 65536) & 255) push(elf, (rx_size / 16777216) & 255)
    push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_filesz
    push(elf, rx_size & 255) push(elf, (rx_size / 256) & 255) push(elf, (rx_size / 65536) & 255) push(elf, (rx_size / 16777216) & 255)
    push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_memsz
    push(elf, 0) push(elf, 0) push(elf, 1) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_align = 65536

    // ── 2b. Program Header 1: PT_LOAD Strict RW (PF_R | PF_W = 6) ────────────
    push(elf, 1) push(elf, 0) push(elf, 0) push(elf, 0) // PT_LOAD
    push(elf, 6) push(elf, 0) push(elf, 0) push(elf, 0) // PF_R | PF_W (6)
    push(elf, rw_file_off & 255) push(elf, (rw_file_off / 256) & 255) push(elf, (rw_file_off / 65536) & 255) push(elf, (rw_file_off / 16777216) & 255)
    push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_offset
    push(elf, rw_vaddr & 255) push(elf, (rw_vaddr / 256) & 255) push(elf, (rw_vaddr / 65536) & 255) push(elf, (rw_vaddr / 16777216) & 255)
    push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_vaddr
    push(elf, rw_vaddr & 255) push(elf, (rw_vaddr / 256) & 255) push(elf, (rw_vaddr / 65536) & 255) push(elf, (rw_vaddr / 16777216) & 255)
    push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_paddr
    push(elf, rw_size) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_filesz
    push(elf, rw_size) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_memsz
    push(elf, 0) push(elf, 0) push(elf, 1) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_align = 65536

    // ── 2c. Program Header 2: PT_GNU_STACK (PF_R | PF_W = 6) ────────────────
    push(elf, 81) push(elf, 229) push(elf, 116) push(elf, 100) // 0x6474E551
    push(elf, 6)  push(elf, 0)   push(elf, 0)   push(elf, 0)   // PF_R | PF_W
    zi_p = 0
    while zi_p < 40
        push(elf, 0)
        zi_p = zi_p + 1
    end
    push(elf, 16) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_align = 16

    // ── 3. Append Code Bytes ────────────────────────────────────────────────
    ci = 0
    while ci < code_size
        push(elf, code_bytes[ci])
        ci = ci + 1

    // ── 4. Append Rodata Bytes + Page Pad + 64B RW .data ─────────────────────
    ri = 0
    while ri < rodata_size
        push(elf, rodata_bytes[ri])
        ri = ri + 1
    pi = 0
    while pi < rx_pad
        push(elf, 0)
        pi = pi + 1
    wi = 0
    while wi < rw_size
        push(elf, 0)
        wi = wi + 1

    // ── 5. Write Full Executable to Disk with 0755 Permissions ──────────────
    w_res = file_write_bytes(out_path, elf)
    if w_res < 0
        err_res = Arm64ElfResult()
        err_res.ew_success = 0
        err_res.ew_out_path = out_path
        err_res.ew_file_size = 0
        err_res.ew_entry_vaddr = entry_vaddr
        err_res.ew_error_msg = "Failed to write ARM64 ELF64 binary"
        return err_res

    res = Arm64ElfResult()
    res.ew_success = 1
    res.ew_out_path = out_path
    res.ew_file_size = elf.len()
    res.ew_entry_vaddr = entry_vaddr
    res.ew_error_msg = ""
    return res
