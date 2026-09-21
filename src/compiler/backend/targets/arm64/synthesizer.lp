// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN ARM64 MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/arm64/synthesizer.lp
// ==============================================================================

include "src/compiler/backend/targets/arm64/codegen_core.lp"
include "src/compiler/backend/targets/arm64/codegen_expr.lp"
include "src/compiler/backend/targets/arm64/codegen_stmt.lp"

// ── 9. Master Program Synthesizer Entry Point ──────────────────────────────────

fn arm64_synth_compile_program tokens
    // WHY: Master orchestration entry point. Transforms complete token stream into
    // relocatable ARM64 machine code, sets up top-level stack frames, patches string relocations
    // against the Linux ELF virtual address space (0x400000+), and resolves call sites.
    s = arm64_synth_new()

    // 1. Emit top-level stack frame prologue at entry point (offset 0)
    arm64_emit_prologue(s)

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

        arm64_synth_compile_statement(s, tokens, pos_box)

    // 3. If there were NO top-level statements, but 'main' or 'মূল' exists, call main() automatically!
    has_main = 0
    main_name = ""
    if has_top_level == 0
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
            call_rel.cr_patch_offset = call_off
            call_rel.cr_target_name = main_name
            push(s.synth_call_relocs, call_rel)

    // 4. Top-level exit epilogue
    if has_top_level == 1 or has_main == 0
        arm64_emit_movz_x(s, 0, 0, 0) // exit code 0
    // Exit via Linux sys_exit (syscall 93 on AArch64) with status code in X0
    arm64_emit_movz_x(s, 8, 93, 0)
    arm64_emit_svc(s, 0)

    // 5. Emit print_int helper if required
    if s.synth_needs_print_int == 1
        arm64_synth_emit_print_int_helper(s)

    // 5b. Emit sovereign alloc helper if required
    if s.synth_needs_alloc == 1
        arm64_synth_emit_alloc_helper(s)

    // 6. Resolve Inter-Procedural Call Relocations (BL disp26)
    ci = 0
    while ci < s.synth_call_relocs.len()
        cr = s.synth_call_relocs[ci]
        resolved_addr = 0
        if cr.cr_target_name == "__print_int"
            resolved_addr = s.synth_print_int_off
        elif cr.cr_target_name == "__alloc"
            resolved_addr = s.synth_alloc_off
        else
            k = 0
            while k < s.synth_functions.len()
                fn_item = s.synth_functions[k]
                if fn_item.fn_name == cr.cr_target_name
                    resolved_addr = fn_item.fn_entry_offset
                k = k + 1

        rel_words = (resolved_addr - cr.cr_patch_offset) / 4
        imm26 = rel_words & 67108863
        bl_word = 2483027968 | imm26
        arm64_synth_patch_u32(s, cr.cr_patch_offset, bl_word)
        ci = ci + 1

    // 7. Resolve 64-Bit Virtual Memory String Relocations
    total_code_size = s.synth_code.len()
    rodata_base_vaddr = 4194424 + total_code_size

    ri = 0
    while ri < s.synth_str_relocs.len()
        rel = s.synth_str_relocs[ri]
        target_vaddr = rodata_base_vaddr + rel.sr_rodata_offset
        arm64_synth_patch_mov_imm64(s, rel.sr_patch_offset, rel.sr_reg, target_vaddr)
        ri = ri + 1

    return s

// ── 10. ELF64 AArch64 Container Header Generator ──────────────────────────────

fn arm64_elf_emit_executable code_bytes rodata_bytes out_path
    // WHY: Packages the compiled AArch64 machine instructions and read-only constants into a
    // bit-perfect Linux ELF64 standalone executable container and persists it to disk with 0755 permissions.
    //
    // Binary Layout:
    //   - Base Virtual Address: 0x400000 (4194304)
    //   - ELF64 Header: 64 bytes (0x00 - 0x3F)
    //   - PT_LOAD Program Header: 56 bytes (0x40 - 0x77)
    //   - Total Header Overhead: 120 bytes (0x78)
    //   - Entry Point: 0x400078 (4194424) -> code_bytes starts immediately at offset 120
    //   - Machine: EM_AARCH64 = 183 (0x00B7)
    //   - Single PT_LOAD segment encompassing header, code, and rodata.
    total_hdr_size = 120 // 64 (ELF Header) + 56 (PT_LOAD Program Header)
    code_size = code_bytes.len()
    rodata_size = rodata_bytes.len()
    total_size = total_hdr_size + code_size + rodata_size
    base_vaddr = 4194304  // 0x400000
    entry_vaddr = 4194424 // 0x400078 (0x400000 + 120)

    elf = list()

    // ── 1. ELF64 Header (64 bytes) ──────────────────────────────────────────
    // e_ident: Magic \x7FELF, Class 2 (64-bit), Data 1 (Little-Endian), Version 1, OS/ABI 0 (System V), 8 padding zeroes
    push(elf, 127) // 0x7F
    push(elf, 69)  // 'E'
    push(elf, 76)  // 'L'
    push(elf, 70)  // 'F'
    push(elf, 2)   // ELFCLASS64 (64-bit)
    push(elf, 1)   // ELFDATA2LSB (Little-Endian)
    push(elf, 1)   // EV_CURRENT (1)
    push(elf, 0)   // ELFOSABI_NONE / System V
    push(elf, 0)   // ABI Version (0)
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad (total 16 bytes e_ident)

    // e_type: ET_EXEC (2) (2 bytes)
    push(elf, 2)
    push(elf, 0)

    // e_machine: EM_AARCH64 (183 = 0x00B7) (2 bytes)
    push(elf, 183)
    push(elf, 0)

    // e_version: EV_CURRENT (1) (4 bytes)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_entry: 0x400078 (4194424) (8 bytes)
    push(elf, 120)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_phoff: 64 (0x40) (8 bytes) -> Program header table follows immediately
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_shoff: 0 (8 bytes) -> No section headers in raw sovereign binary
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_flags: 0 (4 bytes)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_ehsize: 64 (2 bytes)
    push(elf, 64)
    push(elf, 0)

    // e_phentsize: 56 (2 bytes)
    push(elf, 56)
    push(elf, 0)

    // e_phnum: 1 (2 bytes) -> Single PT_LOAD segment
    push(elf, 1)
    push(elf, 0)

    // e_shentsize: 0 (2 bytes)
    push(elf, 0)
    push(elf, 0)

    // e_shnum: 0 (2 bytes)
    push(elf, 0)
    push(elf, 0)

    // e_shstrndx: 0 (2 bytes)
    push(elf, 0)
    push(elf, 0)

    // ── 2. Program Header Table (56 bytes, PT_LOAD) ─────────────────────────
    // p_type: PT_LOAD (1) (4 bytes)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_flags: PF_R | PF_W | PF_X = 7 (Read, Write, Execute) (4 bytes)
    push(elf, 7)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_offset: 0 (8 bytes)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_vaddr: 0x400000 (4194304) (8 bytes)
    push(elf, 0)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_paddr: 0x400000 (4194304) (8 bytes)
    push(elf, 0)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_filesz: total_size (8 bytes)
    push(elf, total_size % 256)
    push(elf, (total_size / 256) % 256)
    push(elf, (total_size / 65536) % 256)
    push(elf, (total_size / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_memsz: total_size (8 bytes)
    push(elf, total_size % 256)
    push(elf, (total_size / 256) % 256)
    push(elf, (total_size / 65536) % 256)
    push(elf, (total_size / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_align: 64KB (65536 = 0x10000) (8 bytes)
    push(elf, 0)
    push(elf, 0)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // ── 3. Append Code Bytes ────────────────────────────────────────────────
    ci = 0
    while ci < code_size
        push(elf, code_bytes[ci])
        ci = ci + 1

    // ── 4. Append Rodata Bytes ──────────────────────────────────────────────
    ri = 0
    while ri < rodata_size
        push(elf, rodata_bytes[ri])
        ri = ri + 1

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
