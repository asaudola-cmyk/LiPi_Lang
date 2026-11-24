// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN RISC-V 64 (RV64G) MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/riscv64/synthesizer.lp
// ==============================================================================

include "src/compiler/backend/targets/riscv64/codegen_core.lp"
include "src/compiler/backend/targets/riscv64/codegen_expr.lp"
include "src/compiler/backend/targets/riscv64/codegen_stmt.lp"
include "src/compiler/backend/targets/riscv64/riscv64_vector.lp"

// ── 11b. RV64G Dynamic Runtime Helpers (List, File I/O) ──────────────────────

fn riscv64_synth_emit_list_create_helper s
    // WHY: Native RV64G 24-byte list header {len, cap, data_ptr} constructor with dynamic capacity.
    // Input: a0 (x10) = initial len. Output: a0 (x10) = pointer to 24-byte list header.
    off = s.rv_code.len()
    s.rv_list_create_off = off
    riscv64_emit_addi(s, 2, 2, 0 - 32)
    riscv64_emit_sd(s, 1, 2, 24)
    riscv64_emit_sd(s, 9, 2, 16)
    riscv64_emit_sd(s, 18, 2, 8)
    riscv64_emit_mv(s, 9, 10)            // s1 (x9) = initial len
    riscv64_emit_li(s, 18, 16)           // s2 (x18) = default cap 16
    bge_cap = s.rv_code.len()
    riscv64_emit_bge(s, 18, 9, 0)        // if 16 >= initial_len, skip doubling
    riscv64_emit_slli(s, 18, 9, 1)       // cap = initial_len * 2
    cap_ready_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_cap, 5, 18, 9, cap_ready_off)
    riscv64_emit_slli(s, 10, 18, 3)      // cap * 8
    riscv64_emit_addi(s, 10, 10, 24)     // 24B header + cap * 8
    riscv64_synth_emit_call_alloc(s)
    riscv64_emit_sd(s, 9, 10, 0)         // [a0 + 0] = len
    riscv64_emit_sd(s, 18, 10, 8)        // [a0 + 8] = cap
    riscv64_emit_addi(s, 6, 10, 24)
    riscv64_emit_sd(s, 6, 10, 16)        // [a0 + 16] = a0 + 24 (data_ptr)
    riscv64_emit_ld(s, 18, 2, 8)
    riscv64_emit_ld(s, 9, 2, 16)
    riscv64_emit_ld(s, 1, 2, 24)
    riscv64_emit_addi(s, 2, 2, 32)
    riscv64_emit_ret(s)
    return off

fn riscv64_synth_emit_list_push_helper s
    // WHY: Appends value (a1) to list header (a0), growing backing buffer exponentially via __alloc.
    off = s.rv_code.len()
    s.rv_list_push_off = off
    riscv64_emit_addi(s, 2, 2, 0 - 48)
    riscv64_emit_sd(s, 1, 2, 40)
    riscv64_emit_sd(s, 9, 2, 32)
    riscv64_emit_sd(s, 18, 2, 24)
    riscv64_emit_sd(s, 19, 2, 16)
    riscv64_emit_sd(s, 20, 2, 8)
    riscv64_emit_sd(s, 21, 2, 0)
    riscv64_emit_mv(s, 9, 10)            // s1 = hdr
    riscv64_emit_mv(s, 18, 11)           // s2 = val
    riscv64_emit_ld(s, 20, 9, 0)         // s4 = len
    riscv64_emit_ld(s, 21, 9, 8)         // s5 = cap
    riscv64_emit_ld(s, 19, 9, 16)        // s3 = data_ptr
    blt_have_cap = s.rv_code.len()
    riscv64_emit_blt(s, 20, 21, 0)       // if len < cap, skip grow
    blt_nz_cap = s.rv_code.len()
    riscv64_emit_blt(s, 0, 21, 0)        // if 0 < cap, skip default 8
    riscv64_emit_addi(s, 21, 0, 8)
    nz_cap_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_nz_cap, 4, 0, 21, nz_cap_off)
    riscv64_emit_slli(s, 21, 21, 1)      // new_cap = cap * 2
    riscv64_emit_slli(s, 10, 21, 3)      // alloc_bytes = new_cap * 8
    riscv64_synth_emit_call_alloc(s)     // a0 = new_data
    riscv64_emit_addi(s, 5, 0, 0)        // t0 = i = 0
    copy_loop_off = s.rv_code.len()
    bge_copy_done = s.rv_code.len()
    riscv64_emit_bge(s, 5, 20, 0)        // if i >= len, done
    riscv64_emit_slli(s, 6, 5, 3)        // t1 = i * 8
    riscv64_emit_add(s, 7, 19, 6)        // &old[i]
    riscv64_emit_ld(s, 11, 7, 0)         // a1 = old[i]
    riscv64_emit_add(s, 7, 10, 6)        // &new[i]
    riscv64_emit_sd(s, 11, 7, 0)         // new[i] = old[i]
    riscv64_emit_addi(s, 5, 5, 1)        // i++
    jmp_loop = s.rv_code.len()
    riscv64_emit_jal(s, 0, copy_loop_off - jmp_loop)
    copy_done_off = s.rv_code.len()
    riscv64_synth_patch_b(s, bge_copy_done, 5, 5, 20, copy_done_off)
    riscv64_emit_mv(s, 19, 10)           // s3 = new_data
    riscv64_emit_sd(s, 21, 9, 8)         // hdr[8] = new_cap
    riscv64_emit_sd(s, 19, 9, 16)        // hdr[16] = new_data
    have_cap_off = s.rv_code.len()
    riscv64_synth_patch_b(s, blt_have_cap, 4, 20, 21, have_cap_off)
    riscv64_emit_slli(s, 5, 20, 3)       // len * 8
    riscv64_emit_add(s, 5, 19, 5)        // &data_ptr[len]
    riscv64_emit_sd(s, 18, 5, 0)         // data_ptr[len] = val
    riscv64_emit_addi(s, 20, 20, 1)      // len + 1
    riscv64_emit_sd(s, 20, 9, 0)         // hdr[0] = len + 1
    riscv64_emit_mv(s, 10, 9)            // return hdr
    riscv64_emit_ld(s, 21, 2, 0)
    riscv64_emit_ld(s, 20, 2, 8)
    riscv64_emit_ld(s, 19, 2, 16)
    riscv64_emit_ld(s, 18, 2, 24)
    riscv64_emit_ld(s, 9, 2, 32)
    riscv64_emit_ld(s, 1, 2, 40)
    riscv64_emit_addi(s, 2, 2, 48)
    riscv64_emit_ret(s)
    return off

fn riscv64_synth_emit_file_write_helper s
    // WHY: Native Linux RISC-V 64 file writer using SYS_openat (56), SYS_write (64), SYS_close (57).
    // Inputs: a0 (x10) = path_ptr, a1 (x11) = data_ptr, a2 (x12) = data_len.
    off = s.rv_code.len()
    s.rv_file_write_off = off
    riscv64_emit_addi(s, 2, 2, 0 - 32)
    riscv64_emit_sd(s, 1, 2, 24)
    riscv64_emit_mv(s, 5, 11)            // t0 = data_ptr
    riscv64_emit_mv(s, 6, 12)            // t1 = data_len
    riscv64_emit_mv(s, 11, 10)           // a1 = pathname
    riscv64_emit_addi(s, 10, 0, 0 - 100) // a0 = AT_FDCWD (-100)
    riscv64_emit_li(s, 12, 577)          // a2 = O_WRONLY|O_CREAT|O_TRUNC
    riscv64_emit_li(s, 13, 420)          // a3 = 0644
    riscv64_emit_li(s, 17, 56)           // a7 = SYS_openat (56)
    riscv64_emit_ecall(s)
    riscv64_emit_mv(s, 7, 10)            // t2 = fd
    riscv64_emit_mv(s, 11, 5)            // a1 = data_ptr
    riscv64_emit_mv(s, 12, 6)            // a2 = data_len
    riscv64_emit_li(s, 17, 64)           // a7 = SYS_write (64)
    riscv64_emit_ecall(s)
    riscv64_emit_mv(s, 10, 7)            // a0 = fd
    riscv64_emit_li(s, 17, 57)           // a7 = SYS_close (57)
    riscv64_emit_ecall(s)
    riscv64_emit_mv(s, 10, 6)            // a0 = bytes written
    riscv64_emit_ld(s, 1, 2, 24)
    riscv64_emit_addi(s, 2, 2, 32)
    riscv64_emit_ret(s)
    return off

// ── 12. Master Program Synthesizer Entry Point ─────────────────────────────────

fn riscv64_synth_compile_program tokens
    // WHY: Master orchestration entry point. Transforms complete token stream into
    // relocatable RISC-V 64 machine code, sets up top-level stack frames, patches string relocations
    // against the Linux ELF virtual address space (0x400000+), and resolves call sites.
    s = riscv64_synth_new()

    // 1. Emit top-level stack frame prologue at entry point (offset 0)
    // and clear callee-saved exception state registers (x26=s10 flag, x27=s11 value).
    riscv64_emit_prologue(s)
    riscv64_emit_addi(s, 26, 0, 0)
    riscv64_emit_addi(s, 27, 0, 0)

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

        riscv64_synth_compile_statement(s, tokens, pos_box)

    // 3. Auto-call main()/মূল() whenever defined and not already invoked at top-level
    has_main = 0
    main_name = ""
    if s.rv_called_main == 0
        fi = 0
        while fi < s.rv_functions.len()
            fn_candidate = s.rv_functions[fi].rv_fn_name
            if fn_candidate == "main" or fn_candidate == "মূল"
                has_main = 1
                main_name = fn_candidate
            fi = fi + 1
        if has_main == 1
            call_off = s.rv_code.len()
            riscv64_emit_jal(s, 1, 0) // Placeholder JAL ra, 0
            call_rel = Riscv64CallReloc()
            call_rel.rv_cr_patch_offset = call_off
            call_rel.rv_cr_target_name = main_name
            push(s.rv_call_relocs, call_rel)

    // 4. Top-level exit epilogue (preserve main() return code in a0 when auto-called)
    if has_main == 0 and s.rv_called_main == 0
        riscv64_emit_addi(s, 10, 0, 0) // exit code 0 in a0
    // Exit whole process cleanly via Linux SYS_exit_group (syscall 94 on RISC-V) with status code in a0
    riscv64_emit_li(s, 17, 94)
    riscv64_emit_ecall(s)

    // 5. Emit print_int helper if required
    if s.rv_needs_print_int == 1
        riscv64_synth_emit_print_int_helper(s)

    // 5b. Emit sovereign alloc, list_create, list_push, and file_write helpers if required
    if s.rv_needs_list_push == 1
        s.rv_needs_alloc = 1
        riscv64_synth_emit_list_push_helper(s)
    if s.rv_needs_list_create == 1
        s.rv_needs_alloc = 1
        riscv64_synth_emit_list_create_helper(s)
    if s.rv_needs_file_write == 1
        riscv64_synth_emit_file_write_helper(s)
    if s.rv_needs_alloc == 1
        riscv64_synth_emit_alloc_helper(s)

    // 6. Resolve Inter-Procedural Call Relocations (JAL ra, disp20)
    ci = 0
    while ci < s.rv_call_relocs.len()
        cr = s.rv_call_relocs[ci]
        resolved_addr = 0
        found_rel = 0
        if cr.rv_cr_target_name == "__print_int"
            resolved_addr = s.rv_print_int_off
            found_rel = 1
        elif cr.rv_cr_target_name == "__alloc"
            resolved_addr = s.rv_alloc_off
            found_rel = 1
        elif cr.rv_cr_target_name == "__list_create"
            resolved_addr = s.rv_list_create_off
            found_rel = 1
        elif cr.rv_cr_target_name == "__list_push"
            resolved_addr = s.rv_list_push_off
            found_rel = 1
        elif cr.rv_cr_target_name == "__file_write"
            resolved_addr = s.rv_file_write_off
            found_rel = 1
        else
            k = 0
            while k < s.rv_functions.len()
                fn_item = s.rv_functions[k]
                if fn_item.rv_fn_name == cr.rv_cr_target_name
                    resolved_addr = fn_item.rv_fn_entry_offset
                    found_rel = 1
                k = k + 1
        if found_rel == 0
            s.rv_error_count = s.rv_error_count + 1
            if s.rv_error_msg == ""
                s.rv_error_msg = "Undefined function in riscv64 target: " + cr.rv_cr_target_name
            end
            say "❌ [RISC-V 64 Backend Error]: Undefined function '" + cr.rv_cr_target_name + "'"
        else
            riscv64_synth_patch_jal(s, cr.rv_cr_patch_offset, 1, resolved_addr)
        end
        ci = ci + 1

    // 7. Resolve 64-Bit Virtual Memory String & Allocator RW .data Relocations
    total_code_size = s.rv_code.len()
    rodata_base_vaddr = 4194536 + total_code_size // 0x4000E8 (232B header) + total_code_size

    ri = 0
    while ri < s.rv_str_relocs.len()
        rel = s.rv_str_relocs[ri]
        target_vaddr = rodata_base_vaddr + rel.rv_sr_rodata_offset
        riscv64_synth_patch_lui_addi(s, rel.rv_sr_patch_offset, rel.rv_sr_reg, target_vaddr)
        ri = ri + 1

    if s.rv_needs_alloc == 1 and s.rv_alloc_rw_patch_off >= 0
        rx_tot = 232 + total_code_size + s.rv_rodata.len()
        rem_rx = rx_tot % 4096
        rx_pad = 0
        if rem_rx != 0
            rx_pad = 4096 - rem_rx
        rw_f_off = rx_tot + rx_pad
        rw_vaddr_target = 4198400 + rw_f_off // 0x401000 + rw_f_off (strict W^X RW .data inside 64KB VM window)
        riscv64_synth_patch_lui_addi(s, s.rv_alloc_rw_patch_off, 5, rw_vaddr_target)

    return s

// ── 13. ELF64 RISC-V Container Header Generator ───────────────────────────────

fn riscv64_elf_emit_executable code_bytes rodata_bytes out_path
    // WHY: Packages RISC-V 64 machine instructions and read-only constants into a
    // strict W^X 3-PHDR Linux ELF64 executable container (zero RWE segments) and persists it with 0755 permissions.
    //
    // Binary Layout:
    //   - Base Virtual Address: 0x400000 (4194304)
    //   - ELF64 Header: 64 bytes + 3 * 56 Program Headers = 232 bytes (0xE8)
    //   - Entry Point: 0x4000E8 (4194536) -> code_bytes starts immediately at offset 232
    //   - Machine: EM_RISCV = 243 (0x00F3)
    //   - PHDR 0: PT_LOAD Strict RX (PF_R | PF_X = 5) covering header + code + rodata
    //   - PHDR 1: PT_LOAD Strict RW (PF_R | PF_W = 6) 4KB-aligned covering 64B _heap_ptr .data
    //   - PHDR 2: PT_GNU_STACK Non-Executable Stack (PF_R | PF_W = 6)
    total_hdr_size = 232
    code_size = code_bytes.len()
    rodata_size = rodata_bytes.len()
    rx_size = total_hdr_size + code_size + rodata_size
    rem_rx = rx_size % 4096
    rx_pad = 0
    if rem_rx != 0
        rx_pad = 4096 - rem_rx
    rw_file_off = rx_size + rx_pad
    rw_vaddr = 4198400 + rw_file_off // 0x401000 + rw_file_off (congruent mod 4096, fits 0x400000..0x410000)
    rw_size = 64
    base_vaddr = 4194304   // 0x400000
    entry_vaddr = 4194536  // 0x4000E8 (0x400000 + 232)

    elf = list()

    // ── 1. ELF64 Header (64 bytes) ──────────────────────────────────────────
    push(elf, 127) // 0x7F
    push(elf, 69)  // 'E'
    push(elf, 76)  // 'L'
    push(elf, 70)  // 'F'
    push(elf, 2)   // ELFCLASS64 (64-bit)
    push(elf, 1)   // ELFDATA2LSB (Little-Endian)
    push(elf, 1)   // EV_CURRENT (1)
    push(elf, 0)   // ELFOSABI_NONE / System V
    push(elf, 0)   // ABI Version (0)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   // 7 pad bytes (total 16 bytes e_ident)

    // e_type: ET_EXEC (2), e_machine: EM_RISCV (243), e_version: 1
    push(elf, 2)   push(elf, 0)
    push(elf, 243) push(elf, 0)
    push(elf, 1)   push(elf, 0)   push(elf, 0)   push(elf, 0)

    // e_entry: 0x4000E8 (4194536) (8 bytes)
    push(elf, 232) push(elf, 0)   push(elf, 64)  push(elf, 0)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0)

    // e_phoff: 64 (0x40), e_shoff: 0, e_flags: 0
    push(elf, 64)  push(elf, 0)   push(elf, 0)   push(elf, 0)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0)

    // e_ehsize: 64, e_phentsize: 56, e_phnum: 3, e_shentsize: 0, e_shnum: 0, e_shstrndx: 0
    push(elf, 64)  push(elf, 0)
    push(elf, 56)  push(elf, 0)
    push(elf, 3)   push(elf, 0)
    push(elf, 0)   push(elf, 0)
    push(elf, 0)   push(elf, 0)
    push(elf, 0)   push(elf, 0)

    // ── 2. Program Header 0: PT_LOAD Strict RX (PF_R | PF_X = 5) ─────────────
    push(elf, 1)   push(elf, 0)   push(elf, 0)   push(elf, 0) // PT_LOAD
    push(elf, 5)   push(elf, 0)   push(elf, 0)   push(elf, 0) // PF_R | PF_X (5)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_offset = 0
    push(elf, 0)   push(elf, 0)   push(elf, 64)  push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_vaddr = 0x400000
    push(elf, 0)   push(elf, 0)   push(elf, 64)  push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_paddr = 0x400000
    push(elf, rx_size % 256) push(elf, (rx_size / 256) % 256) push(elf, (rx_size / 65536) % 256) push(elf, (rx_size / 16777216) % 256)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0) // p_filesz
    push(elf, rx_size % 256) push(elf, (rx_size / 256) % 256) push(elf, (rx_size / 65536) % 256) push(elf, (rx_size / 16777216) % 256)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0) // p_memsz
    push(elf, 0)   push(elf, 16)  push(elf, 0)   push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_align = 4096

    // ── 2b. Program Header 1: PT_LOAD Strict RW (PF_R | PF_W = 6) ────────────
    push(elf, 1)   push(elf, 0)   push(elf, 0)   push(elf, 0) // PT_LOAD
    push(elf, 6)   push(elf, 0)   push(elf, 0)   push(elf, 0) // PF_R | PF_W (6)
    push(elf, rw_file_off % 256) push(elf, (rw_file_off / 256) % 256) push(elf, (rw_file_off / 65536) % 256) push(elf, (rw_file_off / 16777216) % 256)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0) // p_offset
    push(elf, rw_vaddr % 256) push(elf, (rw_vaddr / 256) % 256) push(elf, (rw_vaddr / 65536) % 256) push(elf, (rw_vaddr / 16777216) % 256)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0) // p_vaddr
    push(elf, rw_vaddr % 256) push(elf, (rw_vaddr / 256) % 256) push(elf, (rw_vaddr / 65536) % 256) push(elf, (rw_vaddr / 16777216) % 256)
    push(elf, 0)   push(elf, 0)   push(elf, 0)   push(elf, 0) // p_paddr
    push(elf, rw_size) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_filesz
    push(elf, rw_size) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_memsz
    push(elf, 0)   push(elf, 16)  push(elf, 0)   push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_align = 4096

    // ── 2c. Program Header 2: PT_GNU_STACK (PF_R | PF_W = 6) ────────────────
    push(elf, 81)  push(elf, 229) push(elf, 116) push(elf, 100) // 0x6474E551
    push(elf, 6)   push(elf, 0)   push(elf, 0)   push(elf, 0)   // PF_R | PF_W
    zi_p = 0
    while zi_p < 40
        push(elf, 0)
        zi_p = zi_p + 1
    push(elf, 16)  push(elf, 0)   push(elf, 0)   push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) push(elf, 0) // p_align = 16

    // ── 3. Append Executable Machine Code ───────────────────────────────────
    ci = 0
    while ci < code_size
        push(elf, code_bytes[ci])
        ci = ci + 1

    // ── 4. Append Read-Only Data (.rodata) + Page Pad + 64B RW .data ────────
    di = 0
    while di < rodata_size
        push(elf, rodata_bytes[di])
        di = di + 1
    pi = 0
    while pi < rx_pad
        push(elf, 0)
        pi = pi + 1
    wi = 0
    while wi < rw_size
        push(elf, 0)
        wi = wi + 1

    // ── 5. Direct Binary Persistence to Filesystem ─────────────────────────
    w_res = file_write_bytes(out_path, elf)
    res = Riscv64ElfResult()
    if w_res < 0
        res.rv_ew_success = 0
        res.rv_ew_error_msg = "Failed to write ELF64 RISC-V executable to " + out_path
        return res

    // ── 6. Grant Executable Permissions via Linux sys_chmod (syscall 90) ────
    // 493 decimal = 0755 octal (rwxr-xr-x)
    syscall(90, out_path, 493, 0, 0, 0, 0)

    res.rv_ew_success = 1
    res.rv_ew_out_path = out_path
    res.rv_ew_file_size = elf.len()
    res.rv_ew_entry_vaddr = entry_vaddr
    res.rv_ew_error_msg = ""
    return res
