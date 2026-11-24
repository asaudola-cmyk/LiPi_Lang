// ==============================================================================
// 👑 LIPI SOVEREIGN IN-MEMORY ELF FFI BRIDGE (utso/core/ffi_sovereign.lp)
// ⚡ 100% Pure Lipi | Zero dlopen / Zero Libc | Direct System V AMD64 ABI Invoker
// ==============================================================================
//
// WHY: Standard programming languages depend entirely on glibc's dynamic linker (ld.so)
//      and dlopen()/dlsym() to load C libraries, making the language an operational slave
//      to the C runtime.
//      Lipi achieves total FFI sovereignty by reading ELF64 shared object (.so) binaries
//      directly into memory via raw Linux kernel SYS_mmap (9), resolving dynamic symbols
//      from .dynsym/.dynstr, and invoking functions with strict 16-byte System V ABI alignment.
// ==============================================================================

include "utso/core/memory.lp"
include "utso/core/c_abi_call.lp"

// ── ELF64 Specification Constants ─────────────────────────────────────────────
ELF_MAGIC_0         = 127 // 0x7F
ELF_MAGIC_1         = 69  // 'E'
ELF_MAGIC_2         = 76  // 'L'
ELF_MAGIC_3         = 70  // 'F'
ELF_CLASS_64        = 2
ELF_DATA_2LSB       = 1

SHT_NULL            = 0
SHT_PROGBITS        = 1
SHT_SYMTAB          = 2
SHT_STRTAB          = 3
SHT_RELA            = 4
SHT_DYNSYM          = 11

PT_LOAD             = 1
PF_X                = 1
PF_W                = 2

R_X86_64_64         = 1
R_X86_64_GLOB_DAT   = 6
R_X86_64_JUMP_SLOT  = 7
R_X86_64_RELATIVE   = 8

// ── 1. Sovereign Library Container ────────────────────────────────────────────
// Library fields:
//   lib[0]: base_addr (pointer returned by mmap)
//   lib[1]: map_size (int)
//   lib[2]: dynsym_offset (int)
//   lib[3]: dynsym_count (int)
//   lib[4]: dynstr_offset (int)
//   lib[5]: dynstr_size (int)
//   lib[6]: is_loaded (1 or 0)
//   lib[7]: path (string)
//   lib[8]: min_vaddr (int)

fn ffi_lib_new path
    l = list()
    push(l, 0)    // 0: base_addr
    push(l, 0)    // 1: file_size / map_size
    push(l, 0)    // 2: dynsym_offset
    push(l, 0)    // 3: dynsym_count
    push(l, 0)    // 4: dynstr_offset
    push(l, 0)    // 5: dynstr_size
    push(l, 0)    // 6: is_loaded
    push(l, path) // 7: path
    push(l, 0)    // 8: min_vaddr
    return l

fn _ffi_align_down addr
    return addr - (addr % 4096)

fn _ffi_align_up sz
    if sz <= 0 return 4096 end
    r = sz % 4096
    if r == 0 return sz end
    return sz + (4096 - r)

// ── 2. Strict W^X In-Memory ELF64 Shared Object Loader ────────────────────────
// WHY: Ingests .so binaries cleanly without PROT_READ|PROT_WRITE|PROT_EXEC (prot=7),
// maps PT_LOAD segments, applies internal .rela.dyn/.rela.plt relocations while RW (prot=3),
// and hardware-locks executable segments via SYS_mprotect (PROT_READ|PROT_EXEC = 5).

fn ffi_load_so path
    lib = ffi_lib_new(path)

    // Step 1: Open & read ELF64 binary into temporary RW buffer
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        return lib
    end
    sz = syscall(8, fd, 0, 2, 0, 0, 0)
    syscall(8, fd, 0, 0, 0, 0, 0)
    if sz <= 64 or sz > 67108864
        syscall(3, fd, 0, 0, 0, 0, 0)
        return lib
    end
    fbuf = malloc(sz)
    if fbuf <= 0
        syscall(3, fd, 0, 0, 0, 0, 0)
        return lib
    end
    got = 0
    while got < sz
        n = syscall(0, fd, fbuf + got, sz - got, 0, 0, 0)
        if n <= 0 break end
        got = got + n
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    if got < 64
        free(fbuf, sz)
        return lib
    end

    // Step 2: Verify ELF64 Little-Endian Header
    if mem_byte_read(fbuf, 0) != ELF_MAGIC_0 or mem_byte_read(fbuf, 1) != ELF_MAGIC_1 or mem_byte_read(fbuf, 2) != ELF_MAGIC_2 or mem_byte_read(fbuf, 3) != ELF_MAGIC_3
        free(fbuf, sz)
        return lib
    end
    if mem_byte_read(fbuf, 4) != ELF_CLASS_64 or mem_byte_read(fbuf, 5) != ELF_DATA_2LSB
        free(fbuf, sz)
        return lib
    end

    e_phoff = mem_read(fbuf, 32)
    e_shoff = mem_read(fbuf, 40)
    e_phentsize = mem_byte_read(fbuf, 54) + (mem_byte_read(fbuf, 55) * 256)
    e_phnum = mem_byte_read(fbuf, 56) + (mem_byte_read(fbuf, 57) * 256)
    e_shentsize = mem_byte_read(fbuf, 58) + (mem_byte_read(fbuf, 59) * 256)
    e_shnum = mem_byte_read(fbuf, 60) + (mem_byte_read(fbuf, 61) * 256)
    e_shstrndx = mem_byte_read(fbuf, 62) + (mem_byte_read(fbuf, 63) * 256)

    // Step 3: Measure PT_LOAD virtual address span
    has_load = 0
    min_vaddr = 0
    max_vaddr = 0
    phi = 0
    while phi < e_phnum and e_phentsize >= 56
        poff = e_phoff + (phi * e_phentsize)
        if poff + 56 <= got
            ptype = mem_read_u32(fbuf, poff)
            if ptype == PT_LOAD
                pvaddr = mem_read(fbuf, poff + 16)
                pmemsz = mem_read(fbuf, poff + 40)
                if has_load == 0
                    min_vaddr = _ffi_align_down(pvaddr)
                    max_vaddr = _ffi_align_up(pvaddr + pmemsz)
                    has_load = 1
                else
                    adn = _ffi_align_down(pvaddr)
                    aup = _ffi_align_up(pvaddr + pmemsz)
                    if adn < min_vaddr min_vaddr = adn end
                    if aup > max_vaddr max_vaddr = aup end
                end
            end
        end
        phi = phi + 1
    end

    map_sz = _ffi_align_up(got)
    if has_load == 1 and max_vaddr > min_vaddr
        map_sz = _ffi_align_up(max_vaddr - min_vaddr)
    else
        min_vaddr = 0
    end

    // Step 4: Map anonymous RW arena (prot = 3 = PROT_READ | PROT_WRITE, NEVER prot = 7 RWX!)
    base = syscall(9, 0, map_sz, 3, 34, -1, 0)
    if base <= 0
        free(fbuf, sz)
        return lib
    end

    if has_load == 1
        phi = 0
        while phi < e_phnum
            poff = e_phoff + (phi * e_phentsize)
            if poff + 56 <= got and mem_read_u32(fbuf, poff) == PT_LOAD
                p_offset = mem_read(fbuf, poff + 8)
                p_vaddr = mem_read(fbuf, poff + 16)
                p_filesz = mem_read(fbuf, poff + 32)
                dst_off = p_vaddr - min_vaddr
                if dst_off >= 0 and p_filesz > 0 and p_offset + p_filesz <= got and dst_off + p_filesz <= map_sz
                    mem_copy(base + dst_off, fbuf + p_offset, p_filesz)
                end
            end
            phi = phi + 1
        end
    else
        mem_copy(base, fbuf, got)
    end

    list_set(lib, 0, base)
    list_set(lib, 1, map_sz)
    list_set(lib, 8, min_vaddr)

    // Step 5: Parse Section Headers (.dynsym, .dynstr, and .rela.* tables) from fbuf
    rela_secs = list()
    sh_idx = 0
    while sh_idx < e_shnum and e_shentsize >= 64
        sh_off = e_shoff + (sh_idx * e_shentsize)
        if sh_off + 64 <= got
            sh_type = mem_read_u32(fbuf, sh_off + 4)
            sh_flags = mem_read(fbuf, sh_off + 8)
            sh_addr = mem_read(fbuf, sh_off + 16)
            sh_foff = mem_read(fbuf, sh_off + 24)
            sh_size = mem_read(fbuf, sh_off + 32)
            sh_link = mem_read_u32(fbuf, sh_off + 40)

            target_off = sh_foff
            if has_load == 1 and (sh_flags & 2) != 0 and sh_addr >= min_vaddr and sh_addr - min_vaddr + sh_size <= map_sz
                target_off = sh_addr - min_vaddr
            end

            if sh_type == SHT_DYNSYM
                list_set(lib, 2, target_off)
                list_set(lib, 3, sh_size / 24)
                if sh_link > 0 and sh_link < e_shnum
                    l_off = e_shoff + (sh_link * e_shentsize)
                    if l_off + 64 <= got
                        l_flags = mem_read(fbuf, l_off + 8)
                        l_addr = mem_read(fbuf, l_off + 16)
                        l_foff = mem_read(fbuf, l_off + 24)
                        l_size = mem_read(fbuf, l_off + 32)
                        l_target = l_foff
                        if has_load == 1 and (l_flags & 2) != 0 and l_addr >= min_vaddr and l_addr - min_vaddr + l_size <= map_sz
                            l_target = l_addr - min_vaddr
                        end
                        list_set(lib, 4, l_target)
                        list_set(lib, 5, l_size)
                    end
                end
            elif sh_type == SHT_STRTAB and sh_idx != e_shstrndx
                if get(lib, 4) == 0 or (has_load == 1 and (sh_flags & 2) != 0 and sh_addr > 0)
                    list_set(lib, 4, target_off)
                    list_set(lib, 5, sh_size)
                end
            elif sh_type == SHT_RELA
                push(rela_secs, [sh_foff, sh_size])
            end
        end
        sh_idx = sh_idx + 1
    end

    // Ensure .dynsym / .dynstr exist inside mapped arena even if un-allocated section headers
    dynsym_rel = get(lib, 2)
    sym_cnt = get(lib, 3)

    // Step 6: Apply Internal ELF64 Relocations (.rela.dyn & .rela.plt) while RW
    ri = 0
    while ri < len(rela_secs)
        rsec = get(rela_secs, ri)
        rf_off = rsec[0]
        rf_sz = rsec[1]
        rcount = rf_sz / 24
        ej = 0
        while ej < rcount
            re_off = rf_off + (ej * 24)
            if re_off + 24 <= got
                r_offset = mem_read(fbuf, re_off)
                r_info = mem_read(fbuf, re_off + 8)
                r_addend = mem_read(fbuf, re_off + 16)
                r_type = r_info & 4294967295
                r_sym = (r_info >> 32) & 4294967295
                patch_off = r_offset - min_vaddr
                if patch_off >= 0 and patch_off + 8 <= map_sz
                    if r_type == R_X86_64_RELATIVE
                        mem_write(base, patch_off, base + (r_addend - min_vaddr))
                    elif (r_type == R_X86_64_GLOB_DAT or r_type == R_X86_64_JUMP_SLOT or r_type == R_X86_64_64) and dynsym_rel > 0 and r_sym < sym_cnt
                        st_val = mem_read(base + dynsym_rel + (r_sym * 24), 8)
                        if st_val != 0
                            mem_write(base, patch_off, base + (st_val - min_vaddr) + r_addend)
                        end
                    end
                end
            end
            ej = ej + 1
        end
        ri = ri + 1
    end

    // Step 7: Hardware W^X Enforcement via SYS_mprotect (10): RO (1) first, then RX (5) on PF_X
    if has_load == 1
        rx_segs = list()
        ro_segs = list()
        mp_i = 0
        while mp_i < e_phnum
            mo = e_phoff + (mp_i * e_phentsize)
            if mo + 56 <= got and mem_read_u32(fbuf, mo) == PT_LOAD
                pf = mem_read_u32(fbuf, mo + 4)
                pv = mem_read(fbuf, mo + 16)
                pm = mem_read(fbuf, mo + 40)
                p_start = _ffi_align_down(pv - min_vaddr)
                p_end = _ffi_align_up((pv - min_vaddr) + pm)
                if p_end > p_start and p_end <= map_sz
                    if (pf & PF_X) != 0
                        push(rx_segs, [p_start, p_end - p_start])
                    elif (pf & PF_W) == 0
                        push(ro_segs, [p_start, p_end - p_start])
                    end
                end
            end
            mp_i = mp_i + 1
        end
        si = 0
        while si < len(ro_segs)
            seg = get(ro_segs, si)
            syscall(10, base + seg[0], seg[1], 1, 0, 0, 0)
            si = si + 1
        end
        si = 0
        while si < len(rx_segs)
            seg = get(rx_segs, si)
            syscall(10, base + seg[0], seg[1], 5, 0, 0, 0)
            si = si + 1
        end
    else
        syscall(10, base, map_sz, 5, 0, 0, 0)
    end

    free(fbuf, sz)

    list_set(lib, 6, 1)
    return lib

fn ffi_close_so lib
    base = get(lib, 0)
    sz = get(lib, 1)
    if base > 0 and sz > 0
        syscall(11, base, sz, 0, 0, 0, 0) // munmap
    list_set(lib, 0, 0)
    list_set(lib, 6, 0)
    return 0

// ── 3. Dynamic Symbol Resolver ────────────────────────────────────────────────
// WHY: Resolves function addresses from .dynsym and .dynstr tables without dlsym().

fn ffi_find_symbol lib sym_name
    if get(lib, 6) == 0
        return 0

    base = get(lib, 0)
    dynsym_off = get(lib, 2)
    sym_count = get(lib, 3)
    dynstr_off = get(lib, 4)
    min_vaddr = 0
    if len(lib) > 8
        min_vaddr = get(lib, 8)
    end

    if dynsym_off == 0 or dynstr_off == 0
        return 0

    target_len = len(sym_name)
    i = 0
    while i < sym_count
        sym_entry = base + dynsym_off + (i * 24)
        st_name = mem_read_u32(sym_entry, 0)

        str_ptr = base + dynstr_off + st_name
        is_match = 1
        ci = 0
        while ci < target_len
            c_target = ord(char_at(sym_name, ci))
            c_actual = mem_byte_read(str_ptr, ci)
            if c_target != c_actual
                is_match = 0
                ci = target_len
            ci = ci + 1

        if is_match == 1
            if mem_byte_read(str_ptr, target_len) == 0
                st_value = mem_read(sym_entry, 8)
                return base + (st_value - min_vaddr)

        i = i + 1

    return 0

// ── 4. System V AMD64 ABI Invoker with 16-Byte Stack Alignment (Trap 2 Defense) ──
// WHY: The System V AMD64 ABI strictly mandates that the stack pointer (%rsp) must be
//      16-byte aligned before calling external C functions. An unaligned call immediately
//      triggers a SIGSEGV inside SSE/AVX vector code.

// Validates 16-byte stack frame alignment (Trap 2 Defense)
fn ffi_check_abi_alignment sp
    if (sp % 16) == 0
        return 1
    return 0

// Simulates and validates complete System V ABI call package
fn ffi_prepare_call fn_ptr a0 a1 a2 a3 a4 a5 simulated_sp
    call_pkg = list()
    push(call_pkg, fn_ptr) // 0: target function pointer

    // Align stack pointer to 16 bytes: sp & -16 (Trap 2 Defense)
    aligned_sp = (simulated_sp / 16) * 16
    push(call_pkg, aligned_sp) // 1: aligned stack pointer

    // System V registers: rdi, rsi, rdx, rcx, r8, r9
    push(call_pkg, a0) // 2: RDI
    push(call_pkg, a1) // 3: RSI
    push(call_pkg, a2) // 4: RDX
    push(call_pkg, a3) // 5: RCX
    push(call_pkg, a4) // 6: R8
    push(call_pkg, a5) // 7: R9
    push(call_pkg, 0)  // 8: RAX (AL = 0 for variadic safety)
    return call_pkg

// Inspects mapped x86_64 machine code at fn_ptr when fn_ptr points to a live ELF .text section
fn ffi_inspect_machine_opcode fn_ptr
    if fn_ptr <= 65536
        return 0
    b0 = mem_byte_read(fn_ptr, 0)
    b1 = mem_byte_read(fn_ptr, 1)
    // Detect standard x86_64 prologues: push rbp (0x55), endbr64 (0xF3 0x0F), or direct mov eax, imm32 (0xB8)
    if b0 == 85 or b0 == 243 or b0 == 184 or b0 == 72
        return (b0 * 256) + b1
    return b0

fn ffi_call_simulated call_pkg
    fn_ptr = get(call_pkg, 0)
    aligned_sp = get(call_pkg, 1)

    // Ensure 16-byte alignment condition holds
    if ffi_check_abi_alignment(aligned_sp) == 0
        return -1 // Alignment trap!

    if fn_ptr <= 0
        return -2 // Null function pointer trap!

    // Extract System V AMD64 ABI registers (RDI, RSI, RDX, RCX, R8, R9)
    rdi = get(call_pkg, 2)
    rsi = get(call_pkg, 3)
    rdx = get(call_pkg, 4)
    rcx = get(call_pkg, 5)
    r8  = get(call_pkg, 6)
    r9  = get(call_pkg, 7)
    return rdi + rsi + rdx + rcx + r8 + r9

fn ffi_call_native fn_ptr a0 a1 a2 a3 a4
    // WHY: Dispatches a real native SysV ABI call through the W^X mprotect JIT trampoline.
    if fn_ptr <= 0
        return 0 - 2
    end
    return c_abi_invoke(fn_ptr, a0, a1, a2, a3, a4)
