// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — BARE-METAL, MULTIBOOT2 & UEFI PE32+ EMITTER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% GNU ld | 0% NASM | 0% GRUB | 0% EDK2
// 🏛️ File: src/compiler/backend/formats/bare/bare_writer.lp
//
// WHY THIS MODULE:
// 1. True Freestanding Bare-Metal Output:
//    - Emits ZERO Linux syscalls (verified by compile-time Bare-Metal Purity Gate).
// 2. Four Sovereign Native Formats:
//    - `bare_emit_raw_bin`: Flat headerless machine code + rodata image.
//    - `bare_emit_elf64_kernel`: Freestanding ELF64 ET_EXEC at arbitrary `--base-addr`
//      (e.g. 0x100000 physical or 0xFFFFFFFF80000000 higher-half) + optional DWARF/eh_frame.
//    - `bare_emit_multiboot2_kernel`: Dual Multiboot1+Multiboot2 ELF32 container with an
//      embedded 100% Pure-Lipi 32-bit Protected Mode -> 64-bit Long Mode Boot Trampoline
//      (identity-mapped 1GB huge-page PML4/PDPT/PD + 64-bit GDT + 64KB kernel stack).
//      Boots DIRECTLY in `qemu-system-x86_64 -kernel` AND GRUB2/Limine!
//    - `bare_emit_uefi_pe32plus`: Sovereign UEFI PE32+ (.efi) binary with Subsystem = 10
//      (IMAGE_SUBSYSTEM_EFI_APPLICATION), zero KERNEL32.dll imports, position-independent
//      RIP-relative code, and Microsoft x64 -> System V entry bridge.
// ==============================================================================

struct BareWriteResult
    bw_success
    bw_file_size
    bw_entry_vaddr
    bw_error_msg

fn bare_push_u16 arr val
    v = val
    if v < 0 v = v + 65536 end
    push(arr, v & 255)
    push(arr, (v >> 8) & 255)
    return 0

fn bare_push_u32 arr val
    v = val
    if v < 0 v = v + 4294967296 end
    push(arr, v & 255)
    push(arr, (v >> 8) & 255)
    push(arr, (v >> 16) & 255)
    push(arr, (v >> 24) & 255)
    return 0

fn bare_push_u64 arr val
    // WHY: Signed-safe 64-bit little-endian serializer supporting higher-half canonical
    // kernel addresses like 0xFFFFFFFF80000000 (which are negative in signed i64!).
    v = val
    i = 0
    while i < 8
        b = v & 255
        push(arr, b)
        // Unsigned logical right shift by 8 via bitmask after arithmetic shift
        v = (v >> 8) & 72057594037927935
        i = i + 1
    end
    return 0

fn bare_append_bytes dst src
    i = 0
    n = src.len()
    while i < n
        push(dst, src[i])
        i = i + 1
    end
    return 0

fn bare_pad_to dst target_len
    while dst.len() < target_len
        push(dst, 0)
    end
    return 0

fn bare_align_up val align
    if align <= 1 return val end
    rem = val % align
    if rem == 0 return val end
    return val + (align - rem)

fn bare_write_disk output_path byte_list
    return elf_write_to_disk(output_path, byte_list)

fn bare_verify_zero_linux_syscalls code_bytes
    // WHY: Compile-time Bare-Metal Purity Gate — ensures zero Linux `syscall` (0F 05)
    // instructions leaked into freestanding Ring-0 / UEFI / raw-bin output.
    // Returns count of `0F 05` pairs found.
    cnt = 0
    n = code_bytes.len()
    i = 0
    while i + 1 < n
        if code_bytes[i] == 15 and code_bytes[i + 1] == 5
            cnt = cnt + 1
        end
        i = i + 1
    end
    return cnt

// ── 1. Flat Raw Binary Format (--target=raw-bin) ──────────────────────────────

fn bare_emit_raw_bin code_bytes rodata_bytes output_path
    // WHY: Emits headerless flat machine code + rodata image starting at offset 0.
    raw = list()
    bare_append_bytes(raw, code_bytes)
    bare_append_bytes(raw, rodata_bytes)
    written = bare_write_disk(output_path, raw)
    res = BareWriteResult()
    if written < 0
        res.bw_success = 0
        res.bw_file_size = 0
        res.bw_entry_vaddr = 0
        res.bw_error_msg = "Failed to write raw binary to " + output_path
        return res
    end
    res.bw_success = 1
    res.bw_file_size = raw.len()
    res.bw_entry_vaddr = 0
    res.bw_error_msg = ""
    return res

// ── 2. Freestanding ELF64 Kernel at Configurable Base Address (--target=elf-kernel) ──

fn bare_emit_elf64_kernel code_bytes rodata_bytes bss_size base_vaddr debug_line debug_info debug_abbrev eh_frame output_path
    // WHY: Sovereign freestanding ELF64 ET_EXEC kernel image supporting arbitrary virtual
    // base addresses (e.g. 0x100000 physical or 0xFFFFFFFF80000000 higher-half), zero Linux
    // _start stub (direct entry at base_vaddr + 304), strict W^X RX+RW PT_LOAD segments,
    // and optional DWARF v4 + .eh_frame for live QEMU+GDB source debugging!
    code_file_off = 304 // 64B Ehdr + 3*56B Phdrs + 72B pad -> matches synth_code_file_off=304
    entry_vaddr = base_vaddr + code_file_off
    code_size = code_bytes.len()
    code_vaddr = base_vaddr + code_file_off

    ro_file_off = code_file_off + code_size
    ro_size = rodata_bytes.len()
    ro_vaddr = base_vaddr + ro_file_off

    text_ro_end = ro_file_off + ro_size
    data_file_off = bare_align_up(text_ro_end, 4096)
    pad_bytes = data_file_off - text_ro_end
    data_vaddr = base_vaddr + data_file_off

    // 4KB RW globals header + extra bss_size in SHT_NOBITS (zero disk cost for large @bss!)
    data_filesz = 4096
    data_memsz = data_filesz + bss_size

    has_dbg = 0
    if debug_line != 0 and debug_line.len() > 0
        has_dbg = 1
    end
    has_eh = 0
    if eh_frame != 0 and eh_frame.len() > 0
        has_eh = 1
    end

    cur_off = data_file_off + data_filesz
    eh_off = cur_off
    eh_sz = 0
    if has_eh == 1
        eh_sz = eh_frame.len()
        cur_off = cur_off + eh_sz
    end
    dl_off = cur_off
    dl_sz = 0
    di_off = cur_off
    di_sz = 0
    da_off = cur_off
    da_sz = 0
    if has_dbg == 1
        dl_sz = debug_line.len()
        cur_off = cur_off + dl_sz
        di_off = cur_off
        di_sz = debug_info.len()
        cur_off = cur_off + di_sz
        da_off = cur_off
        da_sz = debug_abbrev.len()
        cur_off = cur_off + da_sz
    end

    // .shstrtab: \0.text\0.rodata\0.data\0.bss\0.eh_frame\0.debug_line\0.debug_info\0.debug_abbrev\0.shstrtab\0
    shstr = [
        0,
        46, 116, 101, 120, 116, 0,                                  // 1: .text
        46, 114, 111, 100, 97, 116, 97, 0,                          // 7: .rodata
        46, 100, 97, 116, 97, 0,                                    // 15: .data
        46, 98, 115, 115, 0,                                        // 21: .bss
        46, 101, 104, 95, 102, 114, 97, 109, 101, 0,                // 26: .eh_frame
        46, 100, 101, 98, 117, 103, 95, 108, 105, 110, 101, 0,      // 36: .debug_line
        46, 100, 101, 98, 117, 103, 95, 105, 110, 102, 111, 0,      // 48: .debug_info
        46, 100, 101, 98, 117, 103, 95, 97, 98, 98, 114, 101, 118, 0, // 60: .debug_abbrev
        46, 115, 104, 115, 116, 114, 116, 97, 98, 0                 // 74: .shstrtab
    ]
    shstr_off = cur_off
    sh_off = shstr_off + shstr.len()
    num_secs = 6 // NULL, .text, .rodata, .data, .bss, .shstrtab
    if has_eh == 1 num_secs = num_secs + 1 end
    if has_dbg == 1 num_secs = num_secs + 3 end
    shstr_idx = num_secs - 1

    bin = list()
    // ELF64 Header (64 bytes, ET_EXEC=2, EM_X86_64=62, e_phnum=3)
    push(bin, 127) push(bin, 69) push(bin, 76) push(bin, 70)
    push(bin, 2) push(bin, 1) push(bin, 1) push(bin, 0)
    bare_pad_to(bin, 16)
    bare_push_u16(bin, 2)           // ET_EXEC
    bare_push_u16(bin, 62)          // EM_X86_64
    bare_push_u32(bin, 1)           // EV_CURRENT
    bare_push_u64(bin, entry_vaddr) // e_entry
    bare_push_u64(bin, 64)          // e_phoff
    bare_push_u64(bin, sh_off)      // e_shoff
    bare_push_u32(bin, 0)           // e_flags
    bare_push_u16(bin, 64)          // e_ehsize
    bare_push_u16(bin, 56)          // e_phentsize
    bare_push_u16(bin, 3)           // e_phnum
    bare_push_u16(bin, 64)          // e_shentsize
    bare_push_u16(bin, num_secs)    // e_shnum
    bare_push_u16(bin, shstr_idx)   // e_shstrndx

    // Program Header 1: PT_LOAD RX (.text + .rodata)
    bare_push_u32(bin, 1)           // PT_LOAD
    bare_push_u32(bin, 5)           // PF_R | PF_X
    bare_push_u64(bin, 0)           // p_offset
    bare_push_u64(bin, base_vaddr)  // p_vaddr
    bare_push_u64(bin, base_vaddr)  // p_paddr
    bare_push_u64(bin, text_ro_end) // p_filesz
    bare_push_u64(bin, text_ro_end) // p_memsz
    bare_push_u64(bin, 4096)        // p_align

    // Program Header 2: PT_LOAD RW (.data + .bss)
    bare_push_u32(bin, 1)             // PT_LOAD
    bare_push_u32(bin, 6)             // PF_R | PF_W
    bare_push_u64(bin, data_file_off) // p_offset
    bare_push_u64(bin, data_vaddr)    // p_vaddr
    bare_push_u64(bin, data_vaddr)    // p_paddr
    bare_push_u64(bin, data_filesz)   // p_filesz
    bare_push_u64(bin, data_memsz)    // p_memsz
    bare_push_u64(bin, 4096)          // p_align

    // Program Header 3: PT_GNU_STACK (RW, non-executable)
    bare_push_u32(bin, 1685382481)
    bare_push_u32(bin, 6)
    bare_push_u64(bin, 0)
    bare_push_u64(bin, 0)
    bare_push_u64(bin, 0)
    bare_push_u64(bin, 0)
    bare_push_u64(bin, 0)
    bare_push_u64(bin, 16)

    // Pad to code_file_off (304)
    bare_pad_to(bin, code_file_off)
    bare_append_bytes(bin, code_bytes)
    bare_append_bytes(bin, rodata_bytes)
    bare_pad_to(bin, data_file_off)
    // 4KB zero-initialized RW .data header
    bare_pad_to(bin, data_file_off + data_filesz)
    if has_eh == 1
        bare_append_bytes(bin, eh_frame)
    end
    if has_dbg == 1
        bare_append_bytes(bin, debug_line)
        bare_append_bytes(bin, debug_info)
        bare_append_bytes(bin, debug_abbrev)
    end
    bare_append_bytes(bin, shstr)

    // Section Headers (64B each)
    sh_null_i = 0
    while sh_null_i < 64
        push(bin, 0)
        sh_null_i = sh_null_i + 1
    end
    // .text (SHT_PROGBITS=1, SHF_ALLOC|SHF_EXECINSTR=6)
    bare_push_u32(bin, 1) bare_push_u32(bin, 1) bare_push_u64(bin, 6) bare_push_u64(bin, code_vaddr) bare_push_u64(bin, code_file_off) bare_push_u64(bin, code_size) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 16) bare_push_u64(bin, 0)
    // .rodata (SHT_PROGBITS=1, SHF_ALLOC=2)
    bare_push_u32(bin, 7) bare_push_u32(bin, 1) bare_push_u64(bin, 2) bare_push_u64(bin, ro_vaddr) bare_push_u64(bin, ro_file_off) bare_push_u64(bin, ro_size) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 8) bare_push_u64(bin, 0)
    // .data (SHT_PROGBITS=1, SHF_WRITE|SHF_ALLOC=3)
    bare_push_u32(bin, 15) bare_push_u32(bin, 1) bare_push_u64(bin, 3) bare_push_u64(bin, data_vaddr) bare_push_u64(bin, data_file_off) bare_push_u64(bin, data_filesz) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 16) bare_push_u64(bin, 0)
    // .bss (SHT_NOBITS=8, SHF_WRITE|SHF_ALLOC=3)
    bare_push_u32(bin, 21) bare_push_u32(bin, 8) bare_push_u64(bin, 3) bare_push_u64(bin, data_vaddr + data_filesz) bare_push_u64(bin, data_file_off + data_filesz) bare_push_u64(bin, bss_size) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 4096) bare_push_u64(bin, 0)
    if has_eh == 1
        bare_push_u32(bin, 26) bare_push_u32(bin, 1) bare_push_u64(bin, 2) bare_push_u64(bin, 0) bare_push_u64(bin, eh_off) bare_push_u64(bin, eh_sz) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 8) bare_push_u64(bin, 0)
    end
    if has_dbg == 1
        bare_push_u32(bin, 36) bare_push_u32(bin, 1) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, dl_off) bare_push_u64(bin, dl_sz) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 1) bare_push_u64(bin, 0)
        bare_push_u32(bin, 48) bare_push_u32(bin, 1) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, di_off) bare_push_u64(bin, di_sz) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 1) bare_push_u64(bin, 0)
        bare_push_u32(bin, 60) bare_push_u32(bin, 1) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, da_off) bare_push_u64(bin, da_sz) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 1) bare_push_u64(bin, 0)
    end
    // .shstrtab (SHT_STRTAB=3)
    bare_push_u32(bin, 74) bare_push_u32(bin, 3) bare_push_u64(bin, 0) bare_push_u64(bin, 0) bare_push_u64(bin, shstr_off) bare_push_u64(bin, shstr.len()) bare_push_u32(bin, 0) bare_push_u32(bin, 0) bare_push_u64(bin, 1) bare_push_u64(bin, 0)

    written = bare_write_disk(output_path, bin)
    res = BareWriteResult()
    if written < 0
        res.bw_success = 0
        res.bw_file_size = 0
        res.bw_entry_vaddr = entry_vaddr
        res.bw_error_msg = "Failed to write freestanding ELF64 kernel to " + output_path
        return res
    end
    res.bw_success = 1
    res.bw_file_size = bin.len()
    res.bw_entry_vaddr = entry_vaddr
    res.bw_error_msg = ""
    return res

// ── 3. Dual Multiboot1+Multiboot2 32->64-bit Long-Mode Kernel (--target=multiboot2-bare / unikernel) ──

fn bare_emit_multiboot2_kernel code_bytes rodata_bytes bss_size base_phys output_path
    // WHY: Sovereign bare-metal Multiboot1+Multiboot2 kernel image loaded at physical `base_phys`
    // (default 0x100000 = 1MB) with a 100% Pure-Lipi 32-bit Protected Mode -> 64-bit Long Mode
    // Boot Trampoline embedded directly in the binary (zero GRUB/NASM/C/ld dependencies!).
    // Boots LIVE in `qemu-system-x86_64 -kernel <out> -nographic -serial stdio` AND GRUB2/Limine!
    //
    // Image Physical Layout (ELF32 PT_LOAD maps file offset 0x1000 -> physical base_phys):
    //   [+0x000 .. +0x00B] Multiboot1 Header (magic 0x1BADB002, flags 0, checksum 0xE4524FFE)
    //   [+0x010 .. +0x037] Multiboot2 Header (magic 0xE85250D6, arch 0, ENTRY tag -> base_phys+0x70)
    //   [+0x040 .. +0x057] 64-bit GDT (null, 0x08 code64, 0x10 data64)
    //   [+0x058 .. +0x061] GDTR (limit=23, base=base_phys+0x40)
    //   [+0x070 .. +0x0FF] 32-bit Protected Mode -> 64-bit Long Mode Trampoline (PML4/PDPT/PD 1GB 2MB pages)
    //   [+0x100 .. +0x12F] 64-bit Long Mode Bridge (reloads data segs, sets 64KB RSP, calls +0x130, cli;hlt)
    //   [+0x130 ..       ] Lipi freestanding 64-bit kernel code (`synth_code`) + `.rodata`
    //   [rw_off ..       ] 4KB RW globals + user `@bss` + 12KB boot page tables + 64KB kernel stack!
    phys = base_phys
    if phys <= 0
        phys = 1048576 // 0x100000 (1MB standard x86 kernel physical load address)
    end
    code_off = 304 // 0x130: matches synth_code_file_off = 304 so ALL RIP-relative & absolute refs align!
    ro_off = code_off + code_bytes.len()
    text_ro_end = ro_off + rodata_bytes.len()
    rw_off = bare_align_up(text_ro_end, 4096)
    rw_data_sz = 4096
    user_bss_aligned = bare_align_up(bss_size, 4096)

    // Boot page tables (PML4 4KB + PDPT 4KB + PD 4KB = 12KB) & 64KB kernel stack right after user @bss
    pt_off = rw_off + rw_data_sz + user_bss_aligned
    pt_phys = phys + pt_off
    pdpt_phys = pt_phys + 4096
    pd_phys = pt_phys + 8192
    stack_top_phys = pt_phys + 12288 + 65536
    total_memsz = pt_off + 12288 + 65536
    total_filesz = rw_off + rw_data_sz

    // Build payload starting at phys (+0x000 .. total_filesz)
    img = list()

    // [+0x000 .. +0x00B]: Multiboot1 Header (QEMU `-kernel` native support!)
    bare_push_u32(img, 464367618)   // 0x1BADB002
    bare_push_u32(img, 0)           // flags = 0
    bare_push_u32(img, 3830599678)  // checksum = -(0x1BADB002) & 0xFFFFFFFF = 0xE4524FFE
    bare_pad_to(img, 16)

    // [+0x010 .. +0x037]: Multiboot2 Header (GRUB2 / Limine native support!)
    bare_push_u32(img, 3897708758)  // 0xE85250D6
    bare_push_u32(img, 0)           // arch = 0 (i386/x86_64)
    bare_push_u32(img, 40)          // header length = 40
    bare_push_u32(img, 397258498)   // checksum = -(0xE85250D6 + 40) & 0xFFFFFFFF = 0x17ADAF02
    // Tag 3: Entry Address (type=3, flags=0, size=12, entry=phys+0x70, 4B pad)
    bare_push_u16(img, 3) bare_push_u16(img, 0) bare_push_u32(img, 12)
    bare_push_u32(img, phys + 112)  // entry = phys + 0x70
    bare_push_u32(img, 0)           // 8-byte align pad
    // Tag 0: End Tag (type=0, flags=0, size=8)
    bare_push_u16(img, 0) bare_push_u16(img, 0) bare_push_u32(img, 8)
    bare_pad_to(img, 64)

    // [+0x040 .. +0x057]: 64-bit GDT (24 bytes: Null, Code64=0x08, Data64=0x10)
    bare_append_bytes(img, [
        0, 0, 0, 0, 0, 0, 0, 0,             // 0x00: Null descriptor
        255, 255, 0, 0, 0, 154, 175, 0,     // 0x08: 64-bit Kernel Code (L=1, D=0, P=1, DPL=0, RX)
        255, 255, 0, 0, 0, 146, 207, 0      // 0x10: 64-bit Kernel Data (P=1, DPL=0, RW)
    ])
    // [+0x058 .. +0x061]: 10-byte GDTR (limit=23, base=phys+0x40)
    bare_push_u16(img, 23)
    bare_push_u64(img, phys + 64)
    bare_pad_to(img, 112) // pad to +0x70

    // [+0x070 .. +0x0FF]: 32-bit Protected Mode -> 64-bit Long Mode Boot Trampoline!
    // 1. cli; mov esi, eax (MB magic); mov ebp, ebx (MB info ptr)
    bare_append_bytes(img, [250, 137, 198, 137, 221])
    // 2. Zero 12KB (3072 dwords) boot page tables at pt_phys: mov edi, pt_phys; xor eax, eax; mov ecx, 3072; cld; rep stosd
    push(img, 191) bare_push_u32(img, pt_phys)
    bare_append_bytes(img, [49, 192, 185, 0, 12, 0, 0, 252, 243, 171])
    // 3. PML4[0] = pdpt_phys | 0x03 (Present | Writable)
    push(img, 184) bare_push_u32(img, pdpt_phys + 3)
    push(img, 163) bare_push_u32(img, pt_phys)
    // 4. PDPT[0] = pd_phys | 0x03
    push(img, 184) bare_push_u32(img, pd_phys + 3)
    push(img, 163) bare_push_u32(img, pdpt_phys)
    // 5. Fill 512 PD entries with 2MB identity huge pages (0..1GB physical RAM, flags 0x83)
    push(img, 191) bare_push_u32(img, pd_phys)
    bare_append_bytes(img, [
        184, 131, 0, 0, 0,          // mov eax, 0x83
        185, 0, 2, 0, 0,            // mov ecx, 512
        137, 7,                     // .pd_loop: mov [edi], eax
        5, 0, 0, 32, 0,             // add eax, 0x200000 (2MB)
        131, 199, 8,                // add edi, 8
        226, 244                    // loop .pd_loop (-12)
    ])
    // 6. Enable PAE (CR4 |= 0x20)
    bare_append_bytes(img, [15, 32, 224, 131, 200, 32, 15, 34, 224])
    // 7. Load CR3 = pt_phys
    push(img, 184) bare_push_u32(img, pt_phys)
    bare_append_bytes(img, [15, 34, 216])
    // 8. Enable Long Mode in IA32_EFER MSR (0xC0000080 |= 0x100)
    bare_append_bytes(img, [185, 128, 0, 0, 192, 15, 50, 13, 0, 1, 0, 0, 15, 48])
    // 9. Enable Paging + Protected Mode (CR0 |= 0x80000001)
    bare_append_bytes(img, [15, 32, 192, 13, 1, 0, 0, 128, 15, 34, 192])
    // 10. lgdt [phys + 0x58]; far jmp 0x0008:(phys + 0x100)
    bare_append_bytes(img, [15, 1, 21]) bare_push_u32(img, phys + 88)
    push(img, 234) bare_push_u32(img, phys + 256) bare_push_u16(img, 8)
    bare_pad_to(img, 256) // pad to +0x100

    // [+0x100 .. +0x12F]: 64-bit Long Mode Entry Bridge
    bare_append_bytes(img, [
        102, 184, 16, 0,            // mov ax, 0x10
        142, 216, 142, 192, 142, 208, 142, 224, 142, 232, // mov ds/es/ss/fs/gs, ax
        72, 188                     // movabs rsp, stack_top_phys
    ])
    bare_push_u64(img, stack_top_phys)
    // mov edi, esi (MB magic -> arg0); mov esi, ebp (MB info -> arg1)
    bare_append_bytes(img, [137, 247, 137, 238])
    // call rel32 -> offset +0x130 (304)
    call_next_off = img.len() + 5
    push(img, 232)
    bare_push_u32(img, code_off - call_next_off)
    // If kmain returns: cli; hlt; jmp $-3
    bare_append_bytes(img, [250, 244, 235, 252])
    bare_pad_to(img, code_off)

    // [+0x130 .. ]: Lipi 64-bit kernel code + .rodata + 4KB RW globals
    bare_append_bytes(img, code_bytes)
    bare_append_bytes(img, rodata_bytes)
    bare_pad_to(img, total_filesz)

    // Wrap payload in a clean ELF32 ET_EXEC container (EM_386=3) so QEMU `-kernel` AND GRUB2
    // load the entire image directly at physical `phys` (0x100000) and jump to `phys + 0x70`!
    elf32 = list()
    // ELF32 Header (52 bytes)
    push(elf32, 127) push(elf32, 69) push(elf32, 76) push(elf32, 70)
    push(elf32, 1) push(elf32, 1) push(elf32, 1) push(elf32, 0) // EI_CLASS=1 (ELF32), LE, v1
    bare_pad_to(elf32, 16)
    bare_push_u16(elf32, 2)         // ET_EXEC
    bare_push_u16(elf32, 3)         // EM_386 (32-bit boot entry transitions itself to 64-bit Long Mode!)
    bare_push_u32(elf32, 1)         // EV_CURRENT
    bare_push_u32(elf32, phys + 112)// e_entry = phys + 0x70 (32-bit trampoline)
    bare_push_u32(elf32, 52)        // e_phoff = 52
    bare_push_u32(elf32, 0)         // e_shoff = 0
    bare_push_u32(elf32, 0)         // e_flags = 0
    bare_push_u16(elf32, 52)        // e_ehsize
    bare_push_u16(elf32, 32)        // e_phentsize
    bare_push_u16(elf32, 1)         // e_phnum = 1
    bare_push_u16(elf32, 40)        // e_shentsize
    bare_push_u16(elf32, 0)         // e_shnum
    bare_push_u16(elf32, 0)         // e_shstrndx

    // ELF32 Program Header (32 bytes): PT_LOAD file_off=0x1000 -> vaddr/paddr=phys
    bare_push_u32(elf32, 1)            // PT_LOAD
    bare_push_u32(elf32, 4096)         // p_offset = 0x1000 (keeps MB1/MB2 headers well inside first 8KB!)
    bare_push_u32(elf32, phys)         // p_vaddr
    bare_push_u32(elf32, phys)         // p_paddr
    bare_push_u32(elf32, total_filesz) // p_filesz
    bare_push_u32(elf32, total_memsz)  // p_memsz (includes user @bss + 12KB page tables + 64KB stack!)
    bare_push_u32(elf32, 7)            // PF_R | PF_W | PF_X (boot self-paging kernel segment)
    bare_push_u32(elf32, 4096)         // p_align

    bare_pad_to(elf32, 4096)
    bare_append_bytes(elf32, img)

    written = bare_write_disk(output_path, elf32)
    res = BareWriteResult()
    if written < 0
        res.bw_success = 0
        res.bw_file_size = 0
        res.bw_entry_vaddr = phys + 112
        res.bw_error_msg = "Failed to write Multiboot2 kernel to " + output_path
        return res
    end
    res.bw_success = 1
    res.bw_file_size = elf32.len()
    res.bw_entry_vaddr = phys + 112
    res.bw_error_msg = ""
    return res

// ── 4. Sovereign UEFI PE32+ Application Emitter (--target=uefi, Subsystem = 10) ──

fn bare_emit_uefi_pe32plus code_bytes rodata_bytes bss_size output_path
    // WHY: Emits a standards-compliant UEFI PE32+ (.efi) executable with:
    //   - Subsystem = 10 (IMAGE_SUBSYSTEM_EFI_APPLICATION)
    //   - Zero KERNEL32.dll IAT (Import Directory = 0)
    //   - Position-independent RIP-relative .text/.rodata/.bss addressing + valid empty .reloc
    //   - MS x64 ABI -> System V ABI entry bridge forwarding (ImageHandle, SystemTable) to Lipi efi_main/main!
    // Zero EDK2, zero gnu-efi, zero LLVM/lld!
    file_align = 512
    sect_align = 4096
    image_base = 4194304 // 0x00400000 (relocatable via RIP-relative addressing!)
    size_of_headers = 1024

    // Build 32-byte UEFI MS x64 -> Lipi SysV entry stub:
    //   push rdi (57); push rsi (56); sub rsp, 8 (48 83 EC 08) [16B aligned]
    //   mov rdi, rcx (48 89 CF); mov rsi, rdx (48 89 D6)
    //   call +11 (E8 0B 00 00 00) -> lands at offset 32 (start of Lipi code!)
    //   add rsp, 8 (48 83 C4 08); pop rsi (5E); pop rdi (5F); ret (C3)
    //   [pad with NOPs to 32 bytes]
    efi_stub = [
        87, 86, 72, 131, 236, 8,    // [0..5]   push rdi; push rsi; sub rsp, 8
        72, 137, 207, 72, 137, 214, // [6..11]  mov rdi, rcx; mov rsi, rdx
        232, 15, 0, 0, 0,           // [12..16] call +15 (17 + 15 = 32!)
        72, 131, 196, 8, 94, 95, 195, // [17..23] add rsp, 8; pop rsi; pop rdi; ret
        144, 144, 144, 144, 144, 144, 144, 144 // [24..31] NOP pad
    ]

    // Combine [efi_stub(32) + code_bytes + rodata_bytes] in .text (so PIE RIP-relative rodata offsets
    // stay 100% invariant!), followed by 4KB-aligned .data (4096B globals + bss_size) and .reloc (12B)!
    text_payload = list()
    bare_append_bytes(text_payload, efi_stub)
    bare_append_bytes(text_payload, code_bytes)
    bare_append_bytes(text_payload, rodata_bytes)
    text_vsize = text_payload.len()
    text_rva = sect_align // 0x1000
    text_raw_size = bare_align_up(text_vsize, file_align)
    text_raw_ptr = size_of_headers

    data_rva = text_rva + bare_align_up(text_vsize, sect_align)
    data_raw_ptr = text_raw_ptr + text_raw_size
    data_raw_size = 4096
    data_vsize = 4096 + bss_size

    reloc_rva = data_rva + bare_align_up(data_vsize, sect_align)
    reloc_raw_ptr = data_raw_ptr + data_raw_size
    // Minimal valid empty PE base relocation block (PageRVA=0x1000, BlockSize=8 -> 0 fixups needed!)
    reloc_bytes = [0, 16, 0, 0, 8, 0, 0, 0]
    reloc_vsize = 8
    reloc_raw_size = file_align
    size_of_image = reloc_rva + sect_align

    // Build PE32+ headers using Lipi's existing dos_header.lp & coff_header.lp
    dos_block = pe_dos_block_serialize()
    pe_sig = pe_signature_bytes()
    coff_hdr = pe_coff_header_create(IMAGE_FILE_MACHINE_AMD64(), 3)
    coff_bytes = pe_coff_header_serialize(coff_hdr)

    opt_hdr = ImageOptionalHeader64()
    opt_hdr.magic = PE32PLUS_MAGIC()
    opt_hdr.major_linker_version = 1
    opt_hdr.minor_linker_version = 0
    opt_hdr.size_of_code = text_raw_size
    opt_hdr.size_of_initialized_data = data_raw_size + reloc_raw_size
    opt_hdr.size_of_uninitialized_data = bss_size
    opt_hdr.address_of_entry_point = text_rva
    opt_hdr.base_of_code = text_rva
    opt_hdr.image_base = image_base
    opt_hdr.section_alignment = sect_align
    opt_hdr.file_alignment = file_align
    opt_hdr.major_os_version = 0
    opt_hdr.minor_os_version = 0
    opt_hdr.major_subsystem_version = 0
    opt_hdr.minor_subsystem_version = 0
    opt_hdr.size_of_image = size_of_image
    opt_hdr.size_of_headers = size_of_headers
    opt_hdr.checksum = 0
    opt_hdr.subsystem = IMAGE_SUBSYSTEM_EFI_APPLICATION() // 10 = EFI_APPLICATION!
    opt_hdr.dll_characteristics = IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE() | IMAGE_DLLCHARACTERISTICS_NX_COMPAT()
    opt_hdr.size_of_stack_reserve = 1048576
    opt_hdr.size_of_stack_commit = 4096
    opt_hdr.size_of_heap_reserve = 0
    opt_hdr.size_of_heap_commit = 0
    opt_hdr.opt_import_table_rva = 0
    opt_hdr.opt_import_table_size = 0
    opt_hdr.opt_iat_rva = 0
    opt_hdr.opt_iat_size = 0
    opt_bytes = pe_optional_header64_serialize(opt_hdr)
    // Patch DataDirectory[5] (Base Relocation Table) at offset 112 + 5*8 = 152 inside OptionalHeader64!
    // (112 = standard+windows fields; dir 0=Export,1=Import,2=Res,3=Exc,4=Sec,5=BaseReloc)
    rel_rva_b = pe_pack_u32(reloc_rva)
    rel_sz_b = pe_pack_u32(reloc_vsize)
    list_set(opt_bytes, 152, rel_rva_b[0]) list_set(opt_bytes, 153, rel_rva_b[1])
    list_set(opt_bytes, 154, rel_rva_b[2]) list_set(opt_bytes, 155, rel_rva_b[3])
    list_set(opt_bytes, 156, rel_sz_b[0])  list_set(opt_bytes, 157, rel_sz_b[1])
    list_set(opt_bytes, 158, rel_sz_b[2])  list_set(opt_bytes, 159, rel_sz_b[3])

    // Section headers: .text, .data, .reloc
    sec_text = pe_section_text_create(text_vsize, text_rva, text_raw_size, text_raw_ptr)
    sec_data = pe_section_data_create(data_vsize, data_rva, data_raw_size, data_raw_ptr)
    sec_reloc = ImageSectionHeader()
    sec_reloc.sh_name = ".reloc"
    sec_reloc.sh_virtual_size = reloc_vsize
    sec_reloc.sh_virtual_address = reloc_rva
    sec_reloc.sh_size_of_raw_data = reloc_raw_size
    sec_reloc.sh_pointer_to_raw_data = reloc_raw_ptr
    sec_reloc.sh_pointer_to_relocations = 0
    sec_reloc.sh_pointer_to_linenumbers = 0
    sec_reloc.sh_number_of_relocations = 0
    sec_reloc.sh_number_of_linenumbers = 0
    sec_reloc.sh_characteristics = 1107296320 // 0x42000040: INITIALIZED_DATA | MEM_DISCARDABLE | MEM_READ

    bin = list()
    bare_append_bytes(bin, dos_block)
    bare_append_bytes(bin, pe_sig)
    bare_append_bytes(bin, coff_bytes)
    bare_append_bytes(bin, opt_bytes)
    bare_append_bytes(bin, pe_section_header_serialize(sec_text))
    bare_append_bytes(bin, pe_section_header_serialize(sec_data))
    bare_append_bytes(bin, pe_section_header_serialize(sec_reloc))
    bare_pad_to(bin, size_of_headers)

    bare_append_bytes(bin, text_payload)
    bare_pad_to(bin, data_raw_ptr)
    bare_pad_to(bin, reloc_raw_ptr)
    bare_append_bytes(bin, reloc_bytes)
    bare_pad_to(bin, reloc_raw_ptr + reloc_raw_size)

    written = bare_write_disk(output_path, bin)
    res = BareWriteResult()
    if written < 0
        res.bw_success = 0
        res.bw_file_size = 0
        res.bw_entry_vaddr = image_base + text_rva
        res.bw_error_msg = "Failed to write UEFI PE32+ image to " + output_path
        return res
    end
    res.bw_success = 1
    res.bw_file_size = bin.len()
    res.bw_entry_vaddr = image_base + text_rva
    res.bw_error_msg = ""
    return res
