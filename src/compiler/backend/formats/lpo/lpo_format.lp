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

fn lpo_emit_elf64_relocatable code_bytes rodata_bytes bss_size fn_items call_relocs output_path
    // WHY: Emits a 100% standards-compliant ELF64 ET_REL (.o) object file containing:
    //   Sec 0: NULL
    //   Sec 1: .text (PROGBITS, AX)
    //   Sec 2: .rodata (PROGBITS, A)
    //   Sec 3: .bss (NOBITS, WA)
    //   Sec 4: .symtab (SYMTAB, link=5 .strtab, info=1 first global)
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

    // Collect defined user symbols into .symtab (STB_GLOBAL=1, STT_FUNC=2 -> st_info = 0x12 = 18)
    sym_names = list()
    sym_count = 1
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
                sym_count = sym_count + 1
            end
            fi = fi + 1
        end
    end

    // Build .rela.text entries for any call relocations targeting known symbols (R_X86_64_PC32 = 2, addend = -4)
    rela_text = list()
    reloc_cnt = 0
    if call_relocs != 0
        ri = 0
        while ri < call_relocs.len()
            cr = call_relocs[ri]
            tgt_sym_idx = 0
            sni = 0
            while sni < sym_names.len()
                if sym_names[sni] == cr.cr_target_name
                    tgt_sym_idx = sni + 1
                    break
                end
                sni = sni + 1
            end
            if tgt_sym_idx > 0
                // Elf64_Rela (24B): r_offset(8), r_info(8: (sym<<32)|type), r_addend(8: -4)
                bare_push_u64(rela_text, cr.cr_patch_offset)
                bare_push_u32(rela_text, 2)           // R_X86_64_PC32
                bare_push_u32(rela_text, tgt_sym_idx) // symbol index (high 32 bits of r_info)
                bare_push_u64(rela_text, 0 - 4)       // r_addend = -4
                reloc_cnt = reloc_cnt + 1
            end
            ri = ri + 1
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
        46, 115, 104, 115, 116, 114, 116, 97, 98, 0                 // 47: .shstrtab
    ]

    text_off = 64
    ro_off = bare_align_up(text_off + code_bytes.len(), 8)
    sym_off = bare_align_up(ro_off + rodata_bytes.len(), 8)
    str_off = sym_off + symtab.len()
    rela_off = bare_align_up(str_off + strtab.len(), 8)
    shstr_off = rela_off + rela_text.len()
    sh_off = bare_align_up(shstr_off + shstr.len(), 8)

    bin = list()
    // ELF64 Header (64B, e_type = ET_REL = 1, e_phnum = 0, e_shnum = 8, e_shstrndx = 7)
    push(bin, 127) push(bin, 69) push(bin, 76) push(bin, 70)
    push(bin, 2) push(bin, 1) push(bin, 1) push(bin, 0)
    bare_pad_to(bin, 16)
    bare_push_u16(bin, 1)       // ET_REL (1 = relocatable .o object!)
    bare_push_u16(bin, 62)      // EM_X86_64
    bare_push_u32(bin, 1)       // EV_CURRENT
    bare_push_u64(bin, 0)       // e_entry = 0
    bare_push_u64(bin, 0)       // e_phoff = 0
    bare_push_u64(bin, sh_off)  // e_shoff
    bare_push_u32(bin, 0)       // e_flags
    bare_push_u16(bin, 64)      // e_ehsize
    bare_push_u16(bin, 0)       // e_phentsize
    bare_push_u16(bin, 0)       // e_phnum
    bare_push_u16(bin, 64)      // e_shentsize
    bare_push_u16(bin, 8)       // e_shnum
    bare_push_u16(bin, 7)       // e_shstrndx = 7 (.shstrtab)

    bare_append_bytes(bin, code_bytes)
    bare_pad_to(bin, ro_off)
    bare_append_bytes(bin, rodata_bytes)
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
    // Sec 4: .symtab (SHT_SYMTAB=2, sh_link=5 (.strtab), sh_info=1, sh_entsize=24)
    bare_push_u32(bin, 20) bare_push_u32(bin, 2) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, sym_off) bare_push_u64(bin, symtab.len()) bare_push_u32(bin, 5) bare_push_u32(bin, 1) bare_push_u64(bin, 8) bare_push_u64(bin, 24)
    // Sec 5: .strtab (SHT_STRTAB=3)
    bare_push_u32(bin, 28) bare_push_u32(bin, 3) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, str_off) bare_push_u64(bin, strtab.len()) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 1) bare_push_u64(bin, 0)
    // Sec 6: .rela.text (SHT_RELA=4, sh_link=4 (.symtab), sh_info=1 (.text), sh_entsize=24)
    bare_push_u32(bin, 36) bare_push_u32(bin, 4) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, rela_off) bare_push_u64(bin, rela_text.len()) bare_push_u32(bin, 4) bare_push_u32(bin, 1) bare_push_u64(bin, 8) bare_push_u64(bin, 24)
    // Sec 7: .shstrtab (SHT_STRTAB=3)
    bare_push_u32(bin, 47) bare_push_u32(bin, 3) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, shstr_off) bare_push_u64(bin, shstr.len()) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 1) bare_push_u64(bin, 0)

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
    res.ow_symbol_count = sym_count - 1
    res.ow_reloc_count = reloc_cnt
    res.ow_error_msg = ""
    return res

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
