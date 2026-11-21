// ==============================================================================
// 👑 LIPI COMPILER BACKEND — SOVEREIGN SHARED OBJECT (.so) EMITTER
// Module: src/compiler/backend/so_emitter.lp
// Standard: Linux ELF64 Shared Library (ET_DYN) / System V AMD64 Dynamic ABI
// ⚡ 100% Pure Lipi Machine Code Engine | Zero GCC | Zero ld | Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Standalone ELF64 shared libraries (ET_DYN = 3) allow external ecosystems
//    (Python ctypes, C, C++, Rust, Go, Zig) and the Linux dynamic linker
//    (ld-linux-x86-64.so.2 / dlopen) to load Lipi functions into foreign memory
//    spaces with immediate dlsym() symbol lookup, without external linkers.
// 2. Position-Independent Code (PIC) & ASLR Defense:
//    - Relocatable virtual memory mapping with base address 0.
//    - Canonical SysV AMD64 dynamic structures: .dynamic, .dynsym, .dynstr, .hash.
// 3. Bit-Perfect Binary Assembly:
//    - Serializes complete contiguous ELF64 binary with executable permissions (0755).
// ==============================================================================

include "src/runtime/lipi_syscall.lp"

// ── 1. ELF64 Constants ────────────────────────────────────────────────────────

@fn SO_ELF_ET_DYN()   return 3 @end  // Shared object file type
@fn SO_ELF_EM_AMD64() return 62 @end // AMD x86-64 architecture

// Dynamic Array Tags (Elf64_Dyn.d_tag)
@fn SO_DT_NULL()   return 0 @end
@fn SO_DT_HASH()   return 4 @end
@fn SO_DT_STRTAB() return 5 @end
@fn SO_DT_SYMTAB() return 6 @end
@fn SO_DT_STRSZ()  return 10 @end
@fn SO_DT_SYMENT() return 11 @end

// Section Header Types
@fn SO_SHT_NULL()     return 0 @end
@fn SO_SHT_PROGBITS() return 1 @end
@fn SO_SHT_SYMTAB()   return 2 @end
@fn SO_SHT_STRTAB()   return 3 @end
@fn SO_SHT_HASH()     return 5 @end
@fn SO_SHT_DYNAMIC()  return 6 @end
@fn SO_SHT_DYNSYM()   return 11 @end

// Section Header Flags
@fn SO_SHF_WRITE()     return 1 @end
@fn SO_SHF_ALLOC()     return 2 @end
@fn SO_SHF_EXECINSTR() return 4 @end

// ── 2. Integer Packing Helpers (Little Endian) ────────────────────────────────

fn so_put16 b_list val
    push(b_list, val % 256)
    push(b_list, floor(val / 256) % 256)
    return 0

fn so_put32 b_list val
    push(b_list, val % 256)
    push(b_list, floor(val / 256) % 256)
    push(b_list, floor(val / 65536) % 256)
    push(b_list, floor(val / 16777216) % 256)
    return 0

fn so_put64 b_list val
    lo = val & 4294967295
    hi = (val / 4294967296) & 4294967295
    push(b_list, lo & 255)
    push(b_list, (lo / 256) & 255)
    push(b_list, (lo / 65536) & 255)
    push(b_list, (lo / 16777216) & 255)
    push(b_list, hi & 255)
    push(b_list, (hi / 256) & 255)
    push(b_list, (hi / 65536) & 255)
    push(b_list, (hi / 16777216) & 255)
    return 0

// WHY: Compute unsigned 32-bit SysV standard ELF hash for dynamic symbol lookup table (.hash)
fn so_elf_hash str_val
    h = 0
    g = 0
    i = 0
    slen = len(str_val)
    while i < slen
        ch = mem_byte_read(str_val, i) & 255
        h = ((h * 16) + ch) & 4294967295
        g = h & 4026531840 // 0xF0000000
        if g != 0
            h = h ^ ((g / 16777216) & 255)
        h = (h ^ g) & 4294967295
        i = i + 1
    return h & 4294967295

// Emits an 8-byte key + 8-byte value Elf64_Dyn entry (16 bytes)
fn so_emit_dyn_entry dyn_list tag val
    so_put64(dyn_list, tag)
    so_put64(dyn_list, val)
    return 0

// WHY: Splitting section header serialization to satisfy SysV ABI 6-parameter register limit
fn so_emit_shdr_base shdrs_list name_off stype flags addr offset
    so_put32(shdrs_list, name_off)
    so_put32(shdrs_list, stype)
    so_put64(shdrs_list, flags)
    so_put64(shdrs_list, addr)
    so_put64(shdrs_list, offset)
    return 0

fn so_emit_shdr_tail shdrs_list size link info addralign entsize
    so_put64(shdrs_list, size)
    so_put32(shdrs_list, link)
    so_put32(shdrs_list, info)
    so_put64(shdrs_list, addralign)
    so_put64(shdrs_list, entsize)
    return 0

// =============================================================================
// Position-Independent Code (PIC) RIP-Relative .rodata + RW Globals Patcher
// =============================================================================
fn so_patch_pic_full code_bytes rodata_len text_offset rw_vaddr
    code_len = len(code_bytes)
    if code_len < 10
        return code_bytes
    linux_rodata_base = 1073742128 + code_len
    linux_rodata_end = linux_rodata_base + rodata_len
    text_ro_end = 304 + code_len + rodata_len
    rem_page = text_ro_end % 4096
    pad_bytes = 0
    if rem_page != 0
        pad_bytes = 4096 - rem_page
    linux_rw_base = 1073741824 + text_ro_end + pad_bytes
    linux_rw_end = linux_rw_base + 4096

    out = list()
    i = 0
    while i < code_len
        b0 = get(code_bytes, i)
        if i + 10 <= code_len and (b0 == 72 or b0 == 73)
            b1 = get(code_bytes, i + 1)
            if (b1 >= 184 and b1 <= 191) and get(code_bytes, i + 6) == 0 and get(code_bytes, i + 7) == 0 and get(code_bytes, i + 8) == 0 and get(code_bytes, i + 9) == 0
                imm32 = get(code_bytes, i + 2) + (get(code_bytes, i + 3) << 8) + (get(code_bytes, i + 4) << 16) + (get(code_bytes, i + 5) << 24)
                lea_rex = 72
                if b0 == 73
                    lea_rex = 76 // REX.WR for r8..r15
                end
                modrm = 5 + ((b1 - 184) * 8)
                if imm32 >= linux_rodata_base and imm32 <= linux_rodata_end
                    ro_off = imm32 - linux_rodata_base
                    disp32 = (code_len + ro_off) - (i + 7)
                    push(out, lea_rex)
                    push(out, 141)
                    push(out, modrm)
                    push(out, disp32 & 255)
                    push(out, (disp32 >> 8) & 255)
                    push(out, (disp32 >> 16) & 255)
                    push(out, (disp32 >> 24) & 255)
                    push(out, 144)
                    push(out, 144)
                    push(out, 144)
                    i = i + 10
                    continue
                elif imm32 >= linux_rw_base and imm32 <= linux_rw_end
                    rw_off = imm32 - linux_rw_base
                    disp32 = (rw_vaddr + rw_off) - (text_offset + i + 7)
                    push(out, lea_rex)
                    push(out, 141)
                    push(out, modrm)
                    push(out, disp32 & 255)
                    push(out, (disp32 >> 8) & 255)
                    push(out, (disp32 >> 16) & 255)
                    push(out, (disp32 >> 24) & 255)
                    push(out, 144)
                    push(out, 144)
                    push(out, 144)
                    i = i + 10
                    continue
                end
            end
        end
        push(out, b0)
        i = i + 1
    return out

fn so_patch_pic_rodata code_bytes rodata_len
    return so_patch_pic_full(code_bytes, rodata_len, 0, len(code_bytes) + rodata_len)

// ── 3. Standalone Shared Library Assembler & Emitter (Strict W^X 4-PHDR) ────

fn so_emit_shared_library code_bytes rodata_bytes exp_names exp_offs out_path
    // WHY: Assembles an independent, strict W^X (0 RWE) ELF64 ET_DYN shared library.
    code_len = len(code_bytes)
    rodata_len = len(rodata_bytes)

    // Base header offset: 64 (ELF Header) + 224 (4 Program Headers: RX, RW, DYNAMIC, GNU_STACK) = 288
    text_offset = 288

    // 1. Build .dynstr table
    dynstr = list(0)
    dynstr_name_offs = list()
    ei = 0
    while ei < len(exp_names)
        ename = get(exp_names, ei)
        push(dynstr_name_offs, len(dynstr))
        ci = 0
        while ci < len(ename)
            push(dynstr, mem_byte_read(ename, ci))
            ci = ci + 1
        push(dynstr, 0) // Null terminator
        ei = ei + 1
    dynstr_len = len(dynstr)

    // 2. Build .dynsym table (24 bytes per Elf64_Sym; symbol 0 is STN_UNDEF)
    dynsym = list()
    zi = 0
    while zi < 24
        push(dynsym, 0)
        zi = zi + 1

    ei = 0
    while ei < len(exp_names)
        sname_off = get(dynstr_name_offs, ei)
        sv_addr = text_offset + get(exp_offs, ei)
        so_put32(dynsym, sname_off)
        push(dynsym, 18) // STB_GLOBAL (1) << 4 | STT_FUNC (2) = 18
        push(dynsym, 0)  // STV_DEFAULT
        push(dynsym, 1)  // st_shndx = 1 (.text section)
        push(dynsym, 0)
        so_put64(dynsym, sv_addr)
        so_put64(dynsym, 0)
        ei = ei + 1

    num_syms = len(exp_names) + 1
    dynsym_len = len(dynsym)

    // 3. Build multi-bucket SysV .hash table
    nbucket = num_syms
    if nbucket < 4
        nbucket = 4
    end
    buckets = list()
    bi = 0
    while bi < nbucket
        push(buckets, 0)
        bi = bi + 1
    end
    chains = list()
    ci_h = 0
    while ci_h < num_syms
        push(chains, 0)
        ci_h = ci_h + 1
    end
    si_h = 0
    while si_h < len(exp_names)
        sym_idx = si_h + 1
        hval = so_elf_hash(get(exp_names, si_h))
        bkt = hval % nbucket
        list_set(chains, sym_idx, get(buckets, bkt))
        list_set(buckets, bkt, sym_idx)
        si_h = si_h + 1
    end
    hashtab = list()
    so_put32(hashtab, nbucket)
    so_put32(hashtab, num_syms)
    bi = 0
    while bi < nbucket
        so_put32(hashtab, get(buckets, bi))
        bi = bi + 1
    end
    ci_h = 0
    while ci_h < num_syms
        so_put32(hashtab, get(chains, ci_h))
        ci_h = ci_h + 1
    end
    hash_len = len(hashtab)

    // 4. Layout Strict W^X Segments:
    //   Segment 0 (PF_R|PF_X = 5): [0 .. rx_end) = ELF Hdr + 4 PHDRs + .text + .rodata + .dynstr + .dynsym + .hash
    //   Segment 1 (PF_R|PF_W = 6): [rw_file_offset .. rw_end) = 4096B RW runtime/mutable globals + .dynamic
    rodata_offset  = text_offset + code_len
    dynstr_offset  = rodata_offset + rodata_len
    dynsym_offset  = dynstr_offset + dynstr_len
    hash_offset    = dynsym_offset + dynsym_len
    rx_end         = hash_offset + hash_len

    rem_rx = rx_end % 4096
    rx_pad = 0
    if rem_rx != 0
        rx_pad = 4096 - rem_rx
    end
    rw_file_offset = rx_end + rx_pad
    rw_vaddr       = rw_file_offset
    rw_globals_len = 4096
    dynamic_offset = rw_file_offset + rw_globals_len

    code_bytes = so_patch_pic_full(code_bytes, rodata_len, text_offset, rw_vaddr)

    // 5. Build .dynamic array (16 bytes per entry)
    dynamic = list()
    so_emit_dyn_entry(dynamic, SO_DT_HASH(), hash_offset)
    so_emit_dyn_entry(dynamic, SO_DT_STRTAB(), dynstr_offset)
    so_emit_dyn_entry(dynamic, SO_DT_SYMTAB(), dynsym_offset)
    so_emit_dyn_entry(dynamic, SO_DT_STRSZ(), dynstr_len)
    so_emit_dyn_entry(dynamic, SO_DT_SYMENT(), 24)
    so_emit_dyn_entry(dynamic, SO_DT_NULL(), 0)
    dynamic_len = len(dynamic)

    rw_end = dynamic_offset + dynamic_len
    rw_seg_size = rw_end - rw_file_offset

    // 6. Build .shstrtab section name string table
    shstrtab = list(
        0,
        46, 116, 101, 120, 116, 0,             // .text
        46, 114, 111, 100, 97, 116, 97, 0,     // .rodata
        46, 100, 121, 110, 115, 121, 109, 0,   // .dynsym
        46, 100, 121, 110, 115, 116, 114, 0,   // .dynstr
        46, 104, 97, 115, 104, 0,             // .hash
        46, 100, 121, 110, 97, 109, 105, 99, 0,// .dynamic
        46, 115, 104, 115, 116, 114, 116, 97, 98, 0 // .shstrtab
    )
    shstrtab_offset = rw_end
    sh_offset = shstrtab_offset + len(shstrtab)

    // 7. Build Section Header Table (8 sections * 64 = 512 bytes)
    shdrs = list()
    // [0] NULL section
    so_emit_shdr_base(shdrs, 0, SO_SHT_NULL(), 0, 0, 0)
    so_emit_shdr_tail(shdrs, 0, 0, 0, 0, 0)
    // [1] .text section
    so_emit_shdr_base(shdrs, 1, SO_SHT_PROGBITS(), SO_SHF_ALLOC() | SO_SHF_EXECINSTR(), text_offset, text_offset)
    so_emit_shdr_tail(shdrs, code_len, 0, 0, 16, 0)
    // [2] .rodata section
    so_emit_shdr_base(shdrs, 7, SO_SHT_PROGBITS(), SO_SHF_ALLOC(), rodata_offset, rodata_offset)
    so_emit_shdr_tail(shdrs, rodata_len, 0, 0, 8, 0)
    // [3] .dynsym section
    so_emit_shdr_base(shdrs, 15, SO_SHT_DYNSYM(), SO_SHF_ALLOC(), dynsym_offset, dynsym_offset)
    so_emit_shdr_tail(shdrs, dynsym_len, 4, 1, 8, 24)
    // [4] .dynstr section
    so_emit_shdr_base(shdrs, 23, SO_SHT_STRTAB(), SO_SHF_ALLOC(), dynstr_offset, dynstr_offset)
    so_emit_shdr_tail(shdrs, dynstr_len, 0, 0, 1, 0)
    // [5] .hash section
    so_emit_shdr_base(shdrs, 31, SO_SHT_HASH(), SO_SHF_ALLOC(), hash_offset, hash_offset)
    so_emit_shdr_tail(shdrs, hash_len, 3, 0, 4, 4)
    // [6] .dynamic section
    so_emit_shdr_base(shdrs, 37, SO_SHT_DYNAMIC(), SO_SHF_ALLOC() | SO_SHF_WRITE(), dynamic_offset, dynamic_offset)
    so_emit_shdr_tail(shdrs, dynamic_len, 4, 0, 8, 16)
    // [7] .shstrtab section
    so_emit_shdr_base(shdrs, 46, SO_SHT_STRTAB(), 0, 0, shstrtab_offset)
    so_emit_shdr_tail(shdrs, len(shstrtab), 0, 0, 1, 0)

    // 8. Assemble Full Binary Bytes
    elf = list()

    // ELF Ident (16 bytes)
    ident = list(127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    ii = 0
    while ii < len(ident)
        push(elf, get(ident, ii))
        ii = ii + 1

    so_put16(elf, SO_ELF_ET_DYN())   // e_type: ET_DYN (3)
    so_put16(elf, SO_ELF_EM_AMD64())  // e_machine: EM_X86_64 (62)
    so_put32(elf, 1)                // e_version: 1
    so_put64(elf, 0)                // e_entry: 0 (shared libraries have no entry point)
    so_put64(elf, 64)               // e_phoff: 64
    so_put64(elf, sh_offset)        // e_shoff: section header offset
    so_put32(elf, 0)                // e_flags: 0
    so_put16(elf, 64)               // e_ehsize: 64
    so_put16(elf, 56)               // e_phentsize: 56
    so_put16(elf, 4)                // e_phnum: 4 (PT_LOAD RX, PT_LOAD RW, PT_DYNAMIC, PT_GNU_STACK)
    so_put16(elf, 64)               // e_shentsize: 64
    so_put16(elf, 8)                // e_shnum: 8 sections
    so_put16(elf, 7)                // e_shstrndx: 7 (.shstrtab index)

    // Program Header 0: PT_LOAD (Strict RX = 5)
    so_put32(elf, 1)          // p_type: PT_LOAD
    so_put32(elf, 5)          // p_flags: PF_R | PF_X
    so_put64(elf, 0)          // p_offset: 0
    so_put64(elf, 0)          // p_vaddr: 0
    so_put64(elf, 0)          // p_paddr: 0
    so_put64(elf, rx_end)     // p_filesz
    so_put64(elf, rx_end)     // p_memsz
    so_put64(elf, 4096)       // p_align: 4KB

    // Program Header 1: PT_LOAD (Strict RW = 6) for runtime/mutable globals & .dynamic
    so_put32(elf, 1)              // p_type: PT_LOAD
    so_put32(elf, 6)              // p_flags: PF_R | PF_W
    so_put64(elf, rw_file_offset) // p_offset
    so_put64(elf, rw_vaddr)       // p_vaddr
    so_put64(elf, rw_vaddr)       // p_paddr
    so_put64(elf, rw_seg_size)    // p_filesz
    so_put64(elf, rw_seg_size)    // p_memsz
    so_put64(elf, 4096)           // p_align: 4KB

    // Program Header 2: PT_DYNAMIC
    so_put32(elf, 2)              // p_type: PT_DYNAMIC
    so_put32(elf, 6)              // p_flags: PF_R | PF_W
    so_put64(elf, dynamic_offset) // p_offset
    so_put64(elf, dynamic_offset) // p_vaddr
    so_put64(elf, dynamic_offset) // p_paddr
    so_put64(elf, dynamic_len)    // p_filesz
    so_put64(elf, dynamic_len)    // p_memsz
    so_put64(elf, 8)              // p_align: 8 bytes

    // Program Header 3: PT_GNU_STACK (Non-executable stack RW = 6)
    so_put32(elf, 1685382481)     // p_type: PT_GNU_STACK (0x6474E551)
    so_put32(elf, 6)              // p_flags: PF_R | PF_W
    so_put64(elf, 0)
    so_put64(elf, 0)
    so_put64(elf, 0)
    so_put64(elf, 0)
    so_put64(elf, 0)
    so_put64(elf, 16)

    // Concatenate .text payload
    ii = 0
    while ii < code_len
        push(elf, get(code_bytes, ii))
        ii = ii + 1

    // Concatenate .rodata payload
    ii = 0
    while ii < rodata_len
        push(elf, get(rodata_bytes, ii))
        ii = ii + 1

    // Concatenate .dynstr
    ii = 0
    while ii < dynstr_len
        push(elf, get(dynstr, ii))
        ii = ii + 1

    // Concatenate .dynsym
    ii = 0
    while ii < dynsym_len
        push(elf, get(dynsym, ii))
        ii = ii + 1

    // Concatenate .hash
    ii = 0
    while ii < hash_len
        push(elf, get(hashtab, ii))
        ii = ii + 1

    // Page-align RX segment before RW segment
    ii = 0
    while ii < rx_pad
        push(elf, 0)
        ii = ii + 1

    // Append 4096-byte zeroed PIC RW globals slot
    ii = 0
    while ii < rw_globals_len
        push(elf, 0)
        ii = ii + 1

    // Concatenate .dynamic
    ii = 0
    while ii < dynamic_len
        push(elf, get(dynamic, ii))
        ii = ii + 1

    // Concatenate .shstrtab
    ii = 0
    while ii < len(shstrtab)
        push(elf, get(shstrtab, ii))
        ii = ii + 1

    // Concatenate Section Header Table (shdrs)
    ii = 0
    while ii < len(shdrs)
        push(elf, get(shdrs, ii))
        ii = ii + 1

    // 9. Persist directly to disk via raw Linux syscalls
    fd = syscall(2, out_path, 577, 493, 0, 0, 0) // O_WRONLY | O_CREAT | O_TRUNC (577), 0755 (493)
    if fd < 0
        return 0 - 1

    written_total = len(elf)
    buf = syscall(9, 0, written_total + 16, 3, 34, 0 - 1, 0)
    if buf <= 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        return 0 - 2

    wi = 0
    while wi < written_total
        sys_poke8(buf + wi, get(elf, wi))
        wi = wi + 1

    syscall(1, fd, buf, written_total, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    syscall(11, buf, written_total + 16, 0, 0, 0, 0)
    syscall(90, out_path, 493, 0, 0, 0, 0) // sys_chmod 0755

    return written_total

