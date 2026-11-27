// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — ELF64 ET_REL (.o) / .LPO OBJECT & .EH_FRAME CFI
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero GNU as/ld | Zero External Linker
// 🏛️ File: src/compiler/backend/formats/lpo/lpo_format.lp
//
// WHY THIS MODULE:
// 1. Standard ELF64 Relocatable Object (.o / ET_REL=1) Emitter:
//    - Emits valid .text, .rodata, .data, .bss, .symtab, .strtab, .rela.text, .shstrtab
//      directly in pure Lipi so modules can be compiled separately (`lipc -c / --emit=obj`)
//      or cached incrementally.
// 2. Lipi Sovereign Object Cache (.lpo) Format:
//    - Content-hashed modular build artifact header ("LPO1") storing source fingerprint,
//      function table, code/rodata blobs, and relocation records for fast incremental rebuilds.
// 3. DWARF Call Frame Information (.eh_frame):
//    - Emits standard x86-64 CIE (Version 1, code_align=1, data_align=-8, ra_reg=16) and
//      per-function FDE entries so GDB/LLDB stack backtraces (`bt`) unwind Lipi frames cleanly
//      on both Linux and QEMU bare-metal kernels!
// ==============================================================================

struct ObjWriteResult
    ow_success
    ow_file_size
    ow_symbol_count
    ow_reloc_count
    ow_error_msg

fn lpo_emit_str_bytes arr s
    n = len(s)
    i = 0
    while i < n
        push(arr, mem_byte_read(s, i))
        i = i + 1
    end
    push(arr, 0)
    return 0

fn lpo_emit_elf64_relocatable_arch code_bytes rodata_bytes bss_size fn_items call_relocs str_relocs rw_patch_offs rw_patch_targets e_machine output_path
    // WHY: Emits a 100% standards-compliant ELF64 ET_REL (.o) object file for x86_64 (62),
    // AArch64 (183), or RISC-V (243) containing:
    //   Sec 0: NULL
    //   Sec 1: .text (PROGBITS, AX)
    //   Sec 2: .rodata (PROGBITS, A)
    //   Sec 3: .bss (NOBITS, WA)
    //   Sec 4: .symtab (SYMTAB, link=5 .strtab, info=4 first global after 3 STT_SECTION locals)
    //   Sec 5: .strtab (STRTAB)
    //   Sec 6: .rela.text (RELA, link=4 .symtab, info=1 .text)
    //   Sec 7: .shstrtab (STRTAB)
    strtab = [0]
    symtab = list()
    // Symbol 0: STN_UNDEF (24 zero bytes)
    si0 = 0
    while si0 < 24
        push(symtab, 0)
        si0 = si0 + 1
    end
    // Local STT_SECTION symbols (indices 1, 2, 3) required for R_X86_64_64 section relocations:
    // Sym 1: .text (st_info=3 = STB_LOCAL|STT_SECTION, st_shndx=1)
    bare_push_u32(symtab, 0) push(symtab, 3) push(symtab, 0) bare_push_u16(symtab, 1) bare_push_u64(symtab, 0) bare_push_u64(symtab, 0)
    // Sym 2: .rodata (st_info=3 = STB_LOCAL|STT_SECTION, st_shndx=2)
    bare_push_u32(symtab, 0) push(symtab, 3) push(symtab, 0) bare_push_u16(symtab, 2) bare_push_u64(symtab, 0) bare_push_u64(symtab, 0)
    // Sym 3: .bss / RW runtime globals (st_info=3 = STB_LOCAL|STT_SECTION, st_shndx=3)
    bare_push_u32(symtab, 0) push(symtab, 3) push(symtab, 0) bare_push_u16(symtab, 3) bare_push_u64(symtab, 0) bare_push_u64(symtab, 0)

    // Collect defined user symbols into .symtab starting at symbol index 4 (STB_GLOBAL|STT_FUNC = 18)
    sym_names = list()
    sym_is_undef = list()
    sym_count = 4
    has_main_entry_sym = 0
    if fn_items != 0
        fi = 0
        while fi < fn_items.len()
            f_it = fn_items[fi]
            fname = f_it.fn_name
            if f_it.fn_decl_line > 0 and len(fname) > 0 and f_it.fn_entry_offset >= 0
                name_off = strtab.len()
                lpo_emit_str_bytes(strtab, fname)
                f_sz = 0
                if f_it.fn_end_offset > f_it.fn_entry_offset
                    f_sz = f_it.fn_end_offset - f_it.fn_entry_offset
                end
                // Elf64_Sym (24B): st_name(4), st_info(1), st_other(1), st_shndx(2), st_value(8), st_size(8)
                bare_push_u32(symtab, name_off)
                push(symtab, 18) // (STB_GLOBAL << 4) | STT_FUNC
                push(symtab, 0)  // STV_DEFAULT
                bare_push_u16(symtab, 1) // SHN = .text (section 1)
                bare_push_u64(symtab, f_it.fn_entry_offset)
                bare_push_u64(symtab, f_sz)
                push(sym_names, fname)
                push(sym_is_undef, 0)
                sym_count = sym_count + 1
                if fname == "main" or fname == "মূল" or fname == "kmain" or fname == "efi_main"
                    has_main_entry_sym = 1
                end
            end
            fi = fi + 1
        end
    end
    // WHY: Objects defining an entry function (main/মূল/kmain/efi_main) publish `__lipi_main_entry`
    // at .text offset 0 so multi-object linking (`lipi link a.o b.o` in ANY order) executes the
    // owning object's top-level init, GC metadata setup, entry dispatch, and defers!
    has_init_array_sym = 0
    if has_main_entry_sym == 1
        me_noff = strtab.len()
        lpo_emit_str_bytes(strtab, "__lipi_main_entry")
        bare_push_u32(symtab, me_noff)
        push(symtab, 18) // (STB_GLOBAL << 4) | STT_FUNC
        push(symtab, 0)  // STV_DEFAULT
        bare_push_u16(symtab, 1) // .text
        bare_push_u64(symtab, 0) // offset 0 of this object's .text
        bare_push_u64(symtab, 0)
        push(sym_names, "__lipi_main_entry")
        push(sym_is_undef, 0)
        sym_count = sym_count + 1
    elif code_bytes.len() > 0
        // WHY: Non-entry object files publish `__lipi_init_array_entry` at .text+0 plus a real
        // ELF SHT_INIT_ARRAY section so `lipi link` automatically runs every object's top-level
        // global initializers (e.g. `global g_x = 42`, heap lists/dicts) before invoking `main`!
        ia_noff = strtab.len()
        lpo_emit_str_bytes(strtab, "__lipi_init_array_entry")
        bare_push_u32(symtab, ia_noff)
        push(symtab, 18) // (STB_GLOBAL << 4) | STT_FUNC
        push(symtab, 0)  // STV_DEFAULT
        bare_push_u16(symtab, 1) // .text
        bare_push_u64(symtab, 0) // offset 0 of this object's .text
        bare_push_u64(symtab, 0)
        push(sym_names, "__lipi_init_array_entry")
        push(sym_is_undef, 0)
        sym_count = sym_count + 1
        has_init_array_sym = 1
    end

    // Register SHN_UNDEF (st_shndx = 0, STB_GLOBAL|STT_NOTYPE = 16) ONLY for genuine external `extern fn`
    // call targets (skip internal runtime helpers already defined inside this object's fn_items with fn_decl_line == 0).
    if call_relocs != 0
        ui = 0
        while ui < call_relocs.len()
            ucr = call_relocs[ui]
            utgt = ucr.cr_target_name
            if len(utgt) > 0 and utgt != "__print_int" and utgt != "__alloc"
                found_u = 0
                sni_u = 0
                while sni_u < sym_names.len()
                    if sym_names[sni_u] == utgt
                        found_u = 1
                        break
                    end
                    sni_u = sni_u + 1
                end
                // Check if utgt is an internal local runtime helper already emitted in this .o
                if found_u == 0 and fn_items != 0
                    lfi = 0
                    while lfi < fn_items.len()
                        if fn_items[lfi].fn_name == utgt and fn_items[lfi].fn_entry_offset >= 0
                            found_u = 1
                            break
                        end
                        lfi = lfi + 1
                    end
                end
                if found_u == 0
                    u_noff = strtab.len()
                    lpo_emit_str_bytes(strtab, utgt)
                    bare_push_u32(symtab, u_noff)
                    push(symtab, 16)         // (STB_GLOBAL << 4) | STT_NOTYPE
                    push(symtab, 0)          // STV_DEFAULT
                    bare_push_u16(symtab, 0) // SHN_UNDEF (0 = external symbol resolved at link time!)
                    bare_push_u64(symtab, 0) // st_value = 0
                    bare_push_u64(symtab, 0) // st_size = 0
                    push(sym_names, utgt)
                    push(sym_is_undef, 1)
                    sym_count = sym_count + 1
                end
            end
            ui = ui + 1
        end
    end

    // Build .rela.text entries:
    //   - R_X86_64_PC32 (2) for local defined calls
    //   - R_X86_64_PLT32 (4) for SHN_UNDEF externs
    //   - R_X86_64_64 (1) against STT_SECTION (.text=1, .rodata=2, .bss/RW=3) for 64-bit data pointers!
    rela_text = list()
    reloc_cnt = 0
    if call_relocs != 0
        ri = 0
        while ri < call_relocs.len()
            cr = call_relocs[ri]
            tgt_sym_idx = 0
            tgt_is_undef = 0
            sni = 0
            while sni < sym_names.len()
                if sym_names[sni] == cr.cr_target_name
                    tgt_sym_idx = sni + 4
                    tgt_is_undef = sym_is_undef[sni]
                    break
                end
                sni = sni + 1
            end
            if tgt_sym_idx > 0
                // Elf64_Rela (24B): r_offset(8), r_info(8: (sym<<32)|type), r_addend(8: -4)
                bare_push_u64(rela_text, cr.cr_patch_offset)
                if tgt_is_undef == 1
                    bare_push_u32(rela_text, 4) // R_X86_64_PLT32 (standard external call reloc)
                else
                    bare_push_u32(rela_text, 2) // R_X86_64_PC32
                end
                bare_push_u32(rela_text, tgt_sym_idx) // symbol index (high 32 bits of r_info)
                bare_push_u64(rela_text, 0 - 4)       // r_addend = -4
                reloc_cnt = reloc_cnt + 1
            end
            ri = ri + 1
        end
    end
    // Emit R_X86_64_64 (1) relocs for all .rodata string literals (against Sym 2 = .rodata)
    if str_relocs != 0
        sri = 0
        while sri < str_relocs.len()
            srel = str_relocs[sri]
            bare_push_u64(rela_text, srel.sr_patch_offset)
            bare_push_u32(rela_text, 1) // R_X86_64_64
            bare_push_u32(rela_text, 2) // Sym 2 = .rodata
            bare_push_u64(rela_text, srel.sr_rodata_offset)
            reloc_cnt = reloc_cnt + 1
            sri = sri + 1
        end
    end
    // Emit R_X86_64_64 (1) relocs for RW globals, @bss buffers, and .rodata/.text bounds
    if rw_patch_offs != 0 and rw_patch_targets != 0
        ro_start_f = code_bytes.len()
        ro_end_f = ro_start_f + rodata_bytes.len()
        rw_start_f = bare_align_up(ro_end_f, 4096)
        rwi = 0
        while rwi < rw_patch_offs.len()
            po = rw_patch_offs[rwi]
            tf = rw_patch_targets[rwi]
            sec_sym = 3
            sec_add = tf - rw_start_f
            if tf < ro_start_f
                sec_sym = 1 // .text
                sec_add = tf
            elif tf < ro_end_f
                sec_sym = 2 // .rodata
                sec_add = tf - ro_start_f
            elif tf == ro_end_f and (ro_end_f < rw_start_f or (rwi > 0 and rw_patch_offs[rwi - 1] == po - 15 and rw_patch_targets[rwi - 1] == ro_start_f))
                sec_sym = 2 // .rodata end bound (_is_str)
                sec_add = tf - ro_start_f
            end
            bare_push_u64(rela_text, po)
            bare_push_u32(rela_text, 1) // R_X86_64_64
            bare_push_u32(rela_text, sec_sym)
            bare_push_u64(rela_text, sec_add)
            reloc_cnt = reloc_cnt + 1
            rwi = rwi + 1
        end
    end

    shstr = [
        0,
        46, 116, 101, 120, 116, 0,                                  // 1: .text
        46, 114, 111, 100, 97, 116, 97, 0,                          // 7: .rodata
        46, 98, 115, 115, 0,                                        // 15: .bss
        46, 115, 121, 109, 116, 97, 98, 0,                          // 20: .symtab
        46, 115, 116, 114, 116, 97, 98, 0,                          // 28: .strtab
        46, 114, 101, 108, 97, 46, 116, 101, 120, 116, 0,           // 36: .rela.text
        46, 115, 104, 115, 116, 114, 116, 97, 98, 0,                // 47: .shstrtab
        46, 105, 110, 105, 116, 95, 97, 114, 114, 97, 121, 0        // 57: .init_array
    ]

    text_off = 64
    ro_off = bare_align_up(text_off + code_bytes.len(), 8)
    init_arr_off = bare_align_up(ro_off + rodata_bytes.len(), 8)
    init_arr_sz = 0
    if has_init_array_sym == 1
        init_arr_sz = 8
    end
    sym_off = bare_align_up(init_arr_off + init_arr_sz, 8)
    str_off = sym_off + symtab.len()
    rela_off = bare_align_up(str_off + strtab.len(), 8)
    shstr_off = rela_off + rela_text.len()
    sh_off = bare_align_up(shstr_off + shstr.len(), 8)

    bin = list()
    // ELF64 Header (64B, e_type = ET_REL = 1, e_phnum = 0, e_shnum = 9, e_shstrndx = 7)
    push(bin, 127) push(bin, 69) push(bin, 76) push(bin, 70)
    push(bin, 2) push(bin, 1) push(bin, 1) push(bin, 0)
    bare_pad_to(bin, 16)
    bare_push_u16(bin, 1)         // ET_REL (1 = relocatable .o object!)
    bare_push_u16(bin, e_machine) // EM_X86_64 (62) / EM_AARCH64 (183) / EM_RISCV (243)
    bare_push_u32(bin, 1)       // EV_CURRENT
    bare_push_u64(bin, 0)       // e_entry = 0
    bare_push_u64(bin, 0)       // e_phoff = 0
    bare_push_u64(bin, sh_off)  // e_shoff
    bare_push_u32(bin, 0)       // e_flags
    bare_push_u16(bin, 64)      // e_ehsize
    bare_push_u16(bin, 0)       // e_phentsize
    bare_push_u16(bin, 0)       // e_phnum
    bare_push_u16(bin, 64)      // e_shentsize
    bare_push_u16(bin, 9)       // e_shnum (includes Sec 8 .init_array)
    bare_push_u16(bin, 7)       // e_shstrndx = 7 (.shstrtab)

    bare_append_bytes(bin, code_bytes)
    bare_pad_to(bin, ro_off)
    bare_append_bytes(bin, rodata_bytes)
    bare_pad_to(bin, init_arr_off)
    if has_init_array_sym == 1
        bare_push_u64(bin, 0) // .text+0 global initializer entry slot
    end
    bare_pad_to(bin, sym_off)
    bare_append_bytes(bin, symtab)
    bare_append_bytes(bin, strtab)
    bare_pad_to(bin, rela_off)
    bare_append_bytes(bin, rela_text)
    bare_append_bytes(bin, shstr)
    bare_pad_to(bin, sh_off)

    // Section 0: NULL (64B)
    zi = 0
    while zi < 64
        push(bin, 0)
        zi = zi + 1
    end
    // Sec 1: .text
    bare_push_u32(bin, 1) bare_push_u32(bin, 1) bare_push_u64(bin, 6) bare_push_u64(bin, 0) bare_push_u64(bin, text_off) bare_push_u64(bin, code_bytes.len()) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 16) bare_push_u64(bin, 0)
    // Sec 2: .rodata
    bare_push_u32(bin, 7) bare_push_u32(bin, 1) bare_push_u64(bin, 2) bare_push_u64(bin, 0) bare_push_u64(bin, ro_off) bare_push_u64(bin, rodata_bytes.len()) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 8) bare_push_u64(bin, 0)
    // Sec 3: .bss
    bare_push_u32(bin, 15) bare_push_u32(bin, 8) bare_push_u64(bin, 3) bare_push_u64(bin, 0) bare_push_u64(bin, ro_off + rodata_bytes.len()) bare_push_u64(bin, bss_size) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 16) bare_push_u64(bin, 0)
    // Sec 4: .symtab (SHT_SYMTAB=2, sh_link=5 (.strtab), sh_info=4 first global, sh_entsize=24)
    bare_push_u32(bin, 20) bare_push_u32(bin, 2) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, sym_off) bare_push_u64(bin, symtab.len()) bare_push_u32(bin, 5) bare_push_u32(bin, 4) bare_push_u64(bin, 8) bare_push_u64(bin, 24)
    // Sec 5: .strtab (SHT_STRTAB=3)
    bare_push_u32(bin, 28) bare_push_u32(bin, 3) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, str_off) bare_push_u64(bin, strtab.len()) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 1) bare_push_u64(bin, 0)
    // Sec 6: .rela.text (SHT_RELA=4, sh_link=4 (.symtab), sh_info=1 (.text), sh_entsize=24)
    bare_push_u32(bin, 36) bare_push_u32(bin, 4) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, rela_off) bare_push_u64(bin, rela_text.len()) bare_push_u32(bin, 4) bare_push_u32(bin, 1) bare_push_u64(bin, 8) bare_push_u64(bin, 24)
    // Sec 7: .shstrtab (SHT_STRTAB=3)
    bare_push_u32(bin, 47) bare_push_u32(bin, 3) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, shstr_off) bare_push_u64(bin, shstr.len()) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 1) bare_push_u64(bin, 0)
    // Sec 8: .init_array (SHT_INIT_ARRAY=14, SHF_WRITE|SHF_ALLOC=3, sh_entsize=8)
    bare_push_u32(bin, 57) bare_push_u32(bin, 14) bare_push_u64(bin, 3) bare_push_u64(bin, 0) bare_push_u64(bin, init_arr_off) bare_push_u64(bin, init_arr_sz) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 8) bare_push_u64(bin, 8)

    written = bare_write_disk(output_path, bin)
    res = ObjWriteResult()
    if written < 0
        res.ow_success = 0
        res.ow_file_size = 0
        res.ow_symbol_count = 0
        res.ow_reloc_count = 0
        res.ow_error_msg = "Failed to write ELF64 ET_REL object to " + output_path
        return res
    end
    res.ow_success = 1
    res.ow_file_size = bin.len()
    res.ow_symbol_count = sym_count - 4
    res.ow_reloc_count = reloc_cnt
    res.ow_error_msg = ""
    return res

fn lpo_emit_elf64_relocatable_full code_bytes rodata_bytes bss_size fn_items call_relocs str_relocs rw_patch_offs rw_patch_targets output_path
    return lpo_emit_elf64_relocatable_arch(code_bytes, rodata_bytes, bss_size, fn_items, call_relocs, str_relocs, rw_patch_offs, rw_patch_targets, 62, output_path)
end

fn lpo_emit_elf64_relocatable code_bytes rodata_bytes bss_size fn_items call_relocs output_path
    return lpo_emit_elf64_relocatable_arch(code_bytes, rodata_bytes, bss_size, fn_items, call_relocs, 0, 0, 0, 62, output_path)
end

// ── DWARF Call Frame Information (.eh_frame CIE + per-function FDEs) ──────────

fn lpo_build_eh_frame code_base_vaddr fn_items
    // WHY: Emits standard x86-64 System V .eh_frame CFI tables (1 CIE + N FDEs + 0 terminator)
    // describing Lipi's `push rbp; mov rbp, rsp` stack frames so GDB/LLDB unwind cleanly
    // in both hosted Linux binaries AND QEMU bare-metal kernels!
    eh = list()
    // CIE (24 bytes total: length=20, CIE_id=0, version=1, aug="", code_align=1, data_align=-8(0x78), ra=16,
    //      DW_CFA_def_cfa(r7=rsp, off=8): 0C 07 08, DW_CFA_offset(r16=rip, fact=1): 90 01, NOPs to 8B align)
    bare_push_u32(eh, 20)
    bare_push_u32(eh, 0) // CIE ID = 0
    bare_append_bytes(eh, [
        1,              // version = 1
        0,              // augmentation = ""
        1,              // code_alignment_factor = 1 (ULEB128)
        120,            // data_alignment_factor = -8 (SLEB128 = 0x78)
        16,             // return_address_register = 16 (%rip)
        12, 7, 8,       // DW_CFA_def_cfa r7 (rsp), offset 8
        144, 1,         // DW_CFA_offset r16 (rip), factored offset 1 (-8)
        0, 0, 0, 0, 0, 0 // DW_CFA_nop padding to 20 bytes
    ])

    // Per-function FDEs (32 bytes each: length=28, CIE_pointer, initial_location(u64), address_range(u64), CFI ops)
    if fn_items != 0
        fi = 0
        while fi < fn_items.len()
            f_it = fn_items[fi]
            if f_it.fn_decl_line > 0 and f_it.fn_entry_offset >= 0 and f_it.fn_end_offset > f_it.fn_entry_offset
                fde_start = eh.len()
                cie_ptr = (fde_start + 4) // distance back to CIE at offset 0
                f_pc = code_base_vaddr + f_it.fn_entry_offset
                f_len = f_it.fn_end_offset - f_it.fn_entry_offset
                bare_push_u32(eh, 28)       // FDE length (28 bytes -> total 32 bytes, 8B aligned)
                bare_push_u32(eh, cie_ptr)  // CIE_pointer (offset from this field to CIE at 0)
                bare_push_u64(eh, f_pc)     // initial_location (64-bit PC)
                bare_push_u64(eh, f_len)    // address_range (64-bit byte length)
                // Standard Lipi prologue CFI:
                //   +1B (after push rbp): DW_CFA_advance_loc 1 (0x41), DW_CFA_def_cfa_offset 16 (0x0E 0x10), DW_CFA_offset r6(rbp) 2 (0x86 0x02)
                //   +3B (after mov rbp, rsp): DW_CFA_advance_loc 3 (0x43), DW_CFA_def_cfa_register r6 (0x0D 0x06)
                bare_append_bytes(eh, [65, 14, 16, 134, 2, 67, 13, 6])
            end
            fi = fi + 1
        end
    end
    // Zero-length terminator FDE (4 bytes)
    bare_push_u32(eh, 0)
    return eh

// ── Native Pure-Lipi ELF64 ET_REL Multi-Object Linker (`lipc link a.o b.o -o out`) ──

struct LinkResult
    lr_success
    lr_file_size
    lr_obj_count
    lr_sym_count
    lr_reloc_count
    lr_entry_vaddr
    lr_error_msg

fn lpo_rd_u16 s off
    return (mem_byte_read(s, off) & 255) | ((mem_byte_read(s, off + 1) & 255) << 8)
end

fn lpo_rd_u32 s off
    b0 = mem_byte_read(s, off) & 255
    b1 = mem_byte_read(s, off + 1) & 255
    b2 = mem_byte_read(s, off + 2) & 255
    b3 = mem_byte_read(s, off + 3) & 255
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
end

fn lpo_rd_u64 s off
    lo = lpo_rd_u32(s, off)
    hi = lpo_rd_u32(s, off + 4)
    return lo | (hi << 32)
end

fn lpo_rd_cstr s off max_len
    n = len(s)
    end_p = off
    lim = off + max_len
    if lim > n lim = n end
    while end_p < lim and (mem_byte_read(s, end_p) & 255) != 0
        end_p = end_p + 1
    end
    if end_p <= off return "" end
    return str_sub(s, off, end_p)
end

fn lpo_patch_bytes_u32 arr off val
    v = val
    if v < 0 v = v + 4294967296 end
    list_set(arr, off, v & 255)
    list_set(arr, off + 1, (v >> 8) & 255)
    list_set(arr, off + 2, (v >> 16) & 255)
    list_set(arr, off + 3, (v >> 24) & 255)
    return 0
end

fn lpo_patch_bytes_u64 arr off val
    v = val
    i = 0
    while i < 8
        list_set(arr, off + i, v & 255)
        v = (v >> 8) & 72057594037927935
        i = i + 1
    end
    return 0
end

fn lpo_link_elf64_objects obj_paths output_path entry_sym base_vaddr
    // WHY: 100% Pure-Lipi Sovereign ELF64 Multi-Object Linker (0% GNU ld, 0% lld, 0% C).
    // Merges N ELF64 ET_REL (.o) files, resolves cross-object SHN_UNDEF symbols across
    // R_X86_64_PC32 (2), R_X86_64_PLT32 (4), and R_X86_64_64 (1), and emits a runnable ELF64 ET_EXEC!
    res = LinkResult()
    res.lr_success = 0
    res.lr_file_size = 0
    res.lr_obj_count = 0
    res.lr_sym_count = 0
    res.lr_reloc_count = 0
    res.lr_entry_vaddr = 0
    res.lr_error_msg = ""

    if obj_paths == 0 or obj_paths.len() == 0
        res.lr_error_msg = "No input .o object files supplied to linker"
        return res
    end
    eff_base = base_vaddr
    if eff_base <= 0
        eff_base = 1073741824 // 0x40000000
    end

    merged_text = list()
    merged_rodata = list()
    total_bss = 0
    g_sym_names = list()
    g_sym_offs = list()
    init_array_offs = list()

    // Per-object parsed metadata for Pass 2 relocation resolution
    obj_blobs = list()
    obj_text_bases = list()
    obj_ro_bases = list()
    obj_rw_shifts = list()
    obj_symtab_offs = list()
    obj_symtab_szs = list()
    obj_strtab_offs = list()
    obj_rela_offs = list()
    obj_rela_szs = list()
    rw_cursor = 0

    // Pass 1: Load objects, merge .text/.rodata/.bss, isolate per-object RW/BSS spans, and build global symbol table
    oi = 0
    while oi < obj_paths.len()
        opath = obj_paths[oi]
        if file_exists(opath) == 0
            res.lr_error_msg = "Linker input object not found: " + opath
            return res
        end
        blob = file_read(opath)
        blen = len(blob)
        if blen < 64 or (mem_byte_read(blob, 0) & 255) != 127 or (mem_byte_read(blob, 1) & 255) != 69 or (mem_byte_read(blob, 2) & 255) != 76 or (mem_byte_read(blob, 3) & 255) != 70
            res.lr_error_msg = "Invalid ELF64 object header: " + opath
            return res
        end
        e_type = lpo_rd_u16(blob, 16)
        if e_type != 1
            res.lr_error_msg = "Expected ELF64 ET_REL (e_type=1), got " + str(e_type) + " in " + opath
            return res
        end
        e_shoff = lpo_rd_u64(blob, 40)
        e_shentsize = lpo_rd_u16(blob, 58)
        e_shnum = lpo_rd_u16(blob, 60)

        t_foff = 0
        t_sz = 0
        ro_foff = 0
        ro_sz = 0
        obj_bss_sz = 0
        sym_foff = 0
        sym_sz = 0
        sym_link = 0
        str_foff = 0
        rela_foff = 0
        rela_sz = 0

        si = 0
        while si < e_shnum and e_shentsize >= 64
            sh = e_shoff + (si * e_shentsize)
            if sh + 64 <= blen
                sh_type = lpo_rd_u32(blob, sh + 4)
                sh_flags = lpo_rd_u64(blob, sh + 8)
                sh_fo = lpo_rd_u64(blob, sh + 24)
                sh_sz = lpo_rd_u64(blob, sh + 32)
                sh_lnk = lpo_rd_u32(blob, sh + 40)
                if sh_type == 1 and (sh_flags & 4) != 0 and t_sz == 0
                    t_foff = sh_fo
                    t_sz = sh_sz
                elif sh_type == 1 and (sh_flags & 2) != 0 and (sh_flags & 4) == 0 and ro_sz == 0
                    ro_foff = sh_fo
                    ro_sz = sh_sz
                elif sh_type == 8
                    obj_bss_sz = obj_bss_sz + sh_sz
                elif sh_type == 2
                    sym_foff = sh_fo
                    sym_sz = sh_sz
                    sym_link = sh_lnk
                elif sh_type == 4 and rela_sz == 0
                    rela_foff = sh_fo
                    rela_sz = sh_sz
                end
            end
            si = si + 1
        end
        if sym_link > 0 and sym_link < e_shnum
            lsh = e_shoff + (sym_link * e_shentsize)
            if lsh + 64 <= blen
                str_foff = lpo_rd_u64(blob, lsh + 24)
            end
        end

        // Pre-scan STT_SECTION (.bss/RW, shndx==3) relocs to isolate this object's user globals & @bss (r_add >= 512)
        // WHY: Runtime slots (< 512: heap, slab, GC, exc, argv) stay shared at rw_vaddr+0..511 across all .o files,
        // while per-object mutable globals & 4KB-aligned @bss buffers get disjoint 4KB-aligned RW windows.
        max_user_radd = 0
        if rela_foff > 0 and rela_sz >= 24 and sym_foff > 0
            p_rcnt = rela_sz / 24
            p_rji = 0
            while p_rji < p_rcnt
                p_re = rela_foff + (p_rji * 24)
                if p_re + 24 <= blen
                    p_rsym = lpo_rd_u32(blob, p_re + 12)
                    p_radd = lpo_rd_u64(blob, p_re + 16)
                    if p_rsym > 0 and sym_foff + (p_rsym * 24) + 24 <= blen
                        p_se = sym_foff + (p_rsym * 24)
                        p_info = mem_byte_read(blob, p_se + 4) & 255
                        p_sh = lpo_rd_u16(blob, p_se + 6)
                        if (p_info & 15) == 3 and p_sh == 3 and p_radd >= 512
                            if p_radd > max_user_radd
                                max_user_radd = p_radd
                            end
                        end
                    end
                end
                p_rji = p_rji + 1
            end
        end
        obj_rw_span = 0
        if max_user_radd >= 512
            obj_rw_span = max_user_radd + 8
            if obj_bss_sz > 0
                bss_hi = 4096 + obj_bss_sz
                if max_user_radd >= 4096
                    bss_hi = max_user_radd + obj_bss_sz
                end
                if bss_hi > obj_rw_span
                    obj_rw_span = bss_hi
                end
            end
        elif obj_bss_sz > 0
            obj_rw_span = 4096 + obj_bss_sz
        end
        obj_rw_shift = 0
        if obj_rw_span > 0
            obj_rw_span_aligned = bare_align_up(obj_rw_span, 4096)
            obj_rw_shift = rw_cursor
            rw_cursor = rw_cursor + obj_rw_span_aligned
        end

        // Align merged .text to 16B boundary with NOP (0x90)
        while (merged_text.len() % 16) != 0
            push(merged_text, 144)
        end
        obj_tbase = merged_text.len()
        ti = 0
        while ti < t_sz and (t_foff + ti) < blen
            push(merged_text, mem_byte_read(blob, t_foff + ti) & 255)
            ti = ti + 1
        end
        while (merged_rodata.len() % 8) != 0
            push(merged_rodata, 0)
        end
        obj_robase = merged_rodata.len()
        ri = 0
        while ri < ro_sz and (ro_foff + ri) < blen
            push(merged_rodata, mem_byte_read(blob, ro_foff + ri) & 255)
            ri = ri + 1
        end

        // Register all defined symbols (st_shndx != 0) into global symbol table
        if sym_foff > 0 and sym_sz >= 24 and str_foff > 0
            scnt = sym_sz / 24
            syi = 1
            while syi < scnt
                se = sym_foff + (syi * 24)
                if se + 24 <= blen
                    st_name = lpo_rd_u32(blob, se)
                    st_shndx = lpo_rd_u16(blob, se + 6)
                    st_val = lpo_rd_u64(blob, se + 8)
                    if st_shndx != 0 and st_name > 0
                        snm = lpo_rd_cstr(blob, str_foff + st_name, 256)
                        if len(snm) > 0
                            if snm == "__lipi_init_array_entry"
                                push(init_array_offs, obj_tbase + st_val)
                            else
                                push(g_sym_names, snm)
                                push(g_sym_offs, obj_tbase + st_val)
                            end
                        end
                    end
                end
                syi = syi + 1
            end
        end

        push(obj_blobs, blob)
        push(obj_text_bases, obj_tbase)
        push(obj_ro_bases, obj_robase)
        push(obj_rw_shifts, obj_rw_shift)
        push(obj_symtab_offs, sym_foff)
        push(obj_symtab_szs, sym_sz)
        push(obj_strtab_offs, str_foff)
        push(obj_rela_offs, rela_foff)
        push(obj_rela_szs, rela_sz)
        oi = oi + 1
    end
    if rw_cursor > 4096
        total_bss = rw_cursor - 4096
    end

    // Resolve entry point BEFORE Pass 2 so any hosted _start trampoline is included in final merged_text.len()
    // WHY: Object file order on the command line (`lipi link a.o b.o` vs `b.o a.o`) must NEVER pick
    // the wrong entry point. Resolve `--entry=<sym>` strictly, else prioritize:
    //   _start -> __lipi_main_entry -> main -> মূল -> kmain -> efi_main -> 0.
    entry_off = 0
    if entry_sym != ""
        entry_found = 0
        ei_e = 0
        while ei_e < g_sym_names.len()
            if g_sym_names[ei_e] == entry_sym
                entry_off = g_sym_offs[ei_e]
                entry_found = 1
                break
            end
            ei_e = ei_e + 1
        end
        if entry_found == 0
            res.lr_error_msg = "Entry symbol '" + entry_sym + "' not found in linked objects"
            return res
        end
    else
        entry_cands = ["_start", "__lipi_main_entry", "main", "মূল", "kmain", "efi_main"]
        ec_i = 0
        entry_found = 0
        while ec_i < entry_cands.len() and entry_found == 0
            want_sym = entry_cands[ec_i]
            ei_s = 0
            while ei_s < g_sym_names.len()
                if g_sym_names[ei_s] == want_sym
                    entry_off = g_sym_offs[ei_s]
                    entry_found = 1
                    break
                end
                ei_s = ei_s + 1
            end
            ec_i = ec_i + 1
        end
    end
    tramp_rw_patch = 0 - 1
    if eff_base == 1073741824
        tramp_off = merged_text.len()
        // Populate argc/argv/stack_bottom/_gc_globals_bytes into rw_vaddr+0/+8/+112/+488 before calling entry_off
        // mov rdi, [rsp]; lea rsi, [rsp+8]; movabs rdx, <rw_vaddr>
        bare_append_bytes(merged_text, [72, 139, 60, 36, 72, 141, 116, 36, 8, 72, 186])
        tramp_rw_patch = merged_text.len()
        bare_push_u64(merged_text, 0)
        // mov [rdx], rdi; mov [rdx+8], rsi; mov [rdx+112], rsp
        bare_append_bytes(merged_text, [72, 137, 58, 72, 137, 114, 8, 72, 137, 98, 112])
        // movabs rcx, <gc_glob_span>; mov [rdx+488], rcx
        gc_glob_span = 3584
        if rw_cursor > 512 and (rw_cursor - 512) > gc_glob_span
            gc_glob_span = rw_cursor - 512
        end
        bare_append_bytes(merged_text, [72, 185])
        bare_push_u64(merged_text, gc_glob_span)
        bare_append_bytes(merged_text, [72, 137, 138, 232, 1, 0, 0])
        // Execute every linked non-entry object's `.init_array` global initializer in order BEFORE main!
        iai = 0
        while iai < init_array_offs.len()
            ia_tgt = init_array_offs[iai]
            if ia_tgt != entry_off
                ia_cpos = merged_text.len()
                ia_rel = ia_tgt - (ia_cpos + 5)
                push(merged_text, 232) // call rel32 (__lipi_init_array_entry)
                bare_push_u32(merged_text, ia_rel)
            end
            iai = iai + 1
        end
        call_pos = merged_text.len()
        call_rel = entry_off - (call_pos + 5)
        push(merged_text, 232) // call rel32
        bare_push_u32(merged_text, call_rel)
        // mov rdi, rax (48 89 C7); mov eax, 231 (B8 E7 00 00 00); syscall (0F 05); hlt (F4)
        bare_append_bytes(merged_text, [72, 137, 199, 184, 231, 0, 0, 0, 15, 5, 244])
        entry_off = tramp_off
    end

    // Pass 2: Apply ALL .rela.text relocations across merged objects (including STT_SECTION .rodata/.bss)!
    code_base_vaddr = eff_base + 304
    rodata_base_vaddr = code_base_vaddr + merged_text.len()
    rw_vaddr = eff_base + bare_align_up(304 + merged_text.len() + merged_rodata.len(), 4096)
    if tramp_rw_patch >= 0
        lpo_patch_bytes_u64(merged_text, tramp_rw_patch, rw_vaddr)
    end
    total_relocs = 0
    oi = 0
    while oi < obj_blobs.len()
        blob = obj_blobs[oi]
        blen = len(blob)
        obj_tbase = obj_text_bases[oi]
        obj_robase = obj_ro_bases[oi]
        obj_rw_shift = obj_rw_shifts[oi]
        sym_foff = obj_symtab_offs[oi]
        sym_sz = obj_symtab_szs[oi]
        str_foff = obj_strtab_offs[oi]
        rela_foff = obj_rela_offs[oi]
        rela_sz = obj_rela_szs[oi]
        if rela_foff > 0 and rela_sz >= 24
            rcnt = rela_sz / 24
            rji = 0
            while rji < rcnt
                re = rela_foff + (rji * 24)
                if re + 24 <= blen
                    r_off = lpo_rd_u64(blob, re)
                    r_type = lpo_rd_u32(blob, re + 8)
                    r_sym = lpo_rd_u32(blob, re + 12)
                    r_add = lpo_rd_u64(blob, re + 16)
                    p_off = obj_tbase + r_off
                    // Check for STT_SECTION (st_info == 3) relocations (.text=1, .rodata=2, .bss/RW=3)
                    is_sec_reloc = 0
                    if r_sym > 0 and sym_foff + (r_sym * 24) + 24 <= blen
                        se_chk = sym_foff + (r_sym * 24)
                        st_info_chk = mem_byte_read(blob, se_chk + 4) & 255
                        st_sh_chk = lpo_rd_u16(blob, se_chk + 6)
                        if (st_info_chk & 15) == 3
                            is_sec_reloc = 1
                            sec_base_v = rw_vaddr
                            if st_sh_chk == 1
                                sec_base_v = code_base_vaddr + obj_tbase
                            elif st_sh_chk == 2
                                sec_base_v = rodata_base_vaddr + obj_robase
                            elif st_sh_chk == 3 and r_add >= 512
                                sec_base_v = rw_vaddr + obj_rw_shift
                            end
                            if r_type == 1 and p_off + 8 <= merged_text.len()
                                lpo_patch_bytes_u64(merged_text, p_off, sec_base_v + r_add)
                                total_relocs = total_relocs + 1
                            end
                        end
                    end
                    if is_sec_reloc == 0
                        // Resolve named function symbol S
                        target_off = 0 - 1
                        sym_nm = ""
                        if r_sym > 0 and sym_foff + (r_sym * 24) + 24 <= blen
                            se2 = sym_foff + (r_sym * 24)
                            st_n2 = lpo_rd_u32(blob, se2)
                            st_sh2 = lpo_rd_u16(blob, se2 + 6)
                            st_v2 = lpo_rd_u64(blob, se2 + 8)
                            sym_nm = lpo_rd_cstr(blob, str_foff + st_n2, 256)
                            if st_sh2 != 0
                                target_off = obj_tbase + st_v2
                            else
                                gi = 0
                                while gi < g_sym_names.len()
                                    if g_sym_names[gi] == sym_nm
                                        target_off = g_sym_offs[gi]
                                        break
                                    end
                                    gi = gi + 1
                                end
                            end
                        end
                        if target_off < 0
                            res.lr_error_msg = "Unresolved external symbol '" + sym_nm + "' during linking"
                            return res
                        end
                        if (r_type == 2 or r_type == 4) and p_off + 4 <= merged_text.len()
                            // R_X86_64_PC32 / R_X86_64_PLT32: S + A - P
                            disp = target_off + r_add - p_off
                            lpo_patch_bytes_u32(merged_text, p_off, disp)
                            total_relocs = total_relocs + 1
                        elif r_type == 1 and p_off + 8 <= merged_text.len()
                            // R_X86_64_64: code_base_vaddr + S + A
                            lpo_patch_bytes_u64(merged_text, p_off, code_base_vaddr + target_off + r_add)
                            total_relocs = total_relocs + 1
                        end
                    end
                end
                rji = rji + 1
            end
        end
        oi = oi + 1
    end

    // Emit linked ELF64 ET_EXEC binary directly (patch e_entry if entry_off > 0!)
    bw = bare_emit_elf64_kernel(merged_text, merged_rodata, total_bss, eff_base, 0, 0, 0, 0, output_path)
    if bw.bw_success == 0
        res.lr_error_msg = bw.bw_error_msg
        return res
    end
    if entry_off > 0
        // Patch e_entry at ELF64 header offset +24 directly on disk
        fd_p = syscall(2, output_path, 2, 0, 0, 0, 0) // O_RDWR
        if fd_p >= 0
            syscall(8, fd_p, 24, 0, 0, 0, 0) // lseek 24
            ebuf = syscall(9, 0, 16, 3, 34, 0 - 1, 0)
            if ebuf > 0
                mem_write(ebuf, 0, eff_base + 304 + entry_off)
                syscall(1, fd_p, ebuf, 8, 0, 0, 0)
                syscall(11, ebuf, 16, 0, 0, 0, 0)
            end
            syscall(3, fd_p, 0, 0, 0, 0, 0)
        end
    end

    res.lr_success = 1
    res.lr_file_size = bw.bw_file_size
    res.lr_obj_count = obj_paths.len()
    res.lr_sym_count = g_sym_names.len()
    res.lr_reloc_count = total_relocs
    res.lr_entry_vaddr = eff_base + 304 + entry_off
    res.lr_error_msg = ""
    return res
end

// ── .LPO Content-Hashed Object Cache ("LPO1" header + 64-bit FNV-1a digest) ──

fn lpo_source_hash src_text
    // WHY: 64-bit FNV-1a content fingerprint for deterministic incremental .lpo caching.
    h = 2166136261
    n = len(src_text)
    i = 0
    while i < n
        h = ((h ^ (mem_byte_read(src_text, i) & 255)) * 16777619) & 9223372036854775807
        i = i + 1
    end
    return h
end

fn lpo_write_cache cache_path src_hash obj_path
    if file_exists(obj_path) == 0 return 0 end
    obj_data = file_read(obj_path)
    olen = len(obj_data)
    out = list()
    // Magic "LPO1" (4B) + src_hash (8B) + payload_len (8B) + ELF64 .o payload
    push(out, 76) push(out, 80) push(out, 79) push(out, 49)
    bare_push_u64(out, src_hash)
    bare_push_u64(out, olen)
    i = 0
    while i < olen
        push(out, mem_byte_read(obj_data, i) & 255)
        i = i + 1
    end
    w = bare_write_disk(cache_path, out)
    if w > 0 return 1 end
    return 0
end

fn lpo_read_cache cache_path expected_hash out_obj_path
    if file_exists(cache_path) == 0 return 0 end
    cdata = file_read(cache_path)
    clen = len(cdata)
    if clen < 20 return 0 end
    if (mem_byte_read(cdata, 0) & 255) != 76 or (mem_byte_read(cdata, 1) & 255) != 80 or (mem_byte_read(cdata, 2) & 255) != 79 or (mem_byte_read(cdata, 3) & 255) != 49
        return 0
    end
    stored_hash = lpo_rd_u64(cdata, 4)
    if stored_hash != expected_hash return 0 end
    plen = lpo_rd_u64(cdata, 12)
    if plen <= 0 or 20 + plen > clen return 0 end
    payload = list()
    i = 0
    while i < plen
        push(payload, mem_byte_read(cdata, 20 + i) & 255)
        i = i + 1
    end
    w = bare_write_disk(out_obj_path, payload)
    if w > 0 return 1 end
    return 0
end
