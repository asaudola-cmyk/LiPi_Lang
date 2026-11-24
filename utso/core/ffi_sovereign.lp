// ==============================================================================
// 👑 LIPI SOVEREIGN ELF64 DYNAMIC LINKER & FFI BRIDGE (utso/core/ffi_sovereign.lp)
// ⚡ 100% Pure Lipi | Zero ld.so / Zero dlopen / Zero Libc | Full ELF64 Linker
// ==============================================================================
//
// WHY: Standard languages are slaves to glibc's ld-linux-x86-64.so.2 and dlopen().
//      Lipi replaces ld.so directly in pure Lipi:
//        1. PT_LOAD strict W^X mapping (NEVER prot=7 RWX; RO -> RX via SYS_mprotect)
//        2. Full PT_DYNAMIC parsing (DT_NEEDED, DT_STRTAB, DT_SYMTAB, DT_GNU_HASH,
//           DT_HASH, DT_RELA, DT_JMPREL, DT_INIT, DT_INIT_ARRAY, DT_RPATH/DT_RUNPATH)
//        3. Recursive BFS DT_NEEDED dependency graph loader (cycle-safe, deduplicated)
//        4. O(1) DT_GNU_HASH + .dynsym global cross-library symbol scope resolution
//        5. Sovereign Pure-Lipi C-ABI Shim Table (malloc/calloc/realloc/free, memcpy/
//           memmove/memset/memcmp/memchr, strlen/strcmp/strncmp/strcpy, POSIX syscalls,
//           __errno_location, __stack_chk_fail, pthread_mutex_*) for virtual C deps
//        6. Complete x86_64 relocations: R_X86_64_64 (1), COPY (5), GLOB_DAT (6),
//           JUMP_SLOT (7), RELATIVE (8), DTPMOD64 (16), DTPOFF64 (17), TPOFF64 (18),
//           and R_X86_64_IRELATIVE (37, GLIBC IFUNC resolver invocation!)
//        7. Variant-II ELF64 PT_TLS + SYS_arch_prctl(ARCH_SET_FS) TCB + SYS_getrandom
//           FS:0x28 stack-protector canary + DT_INIT_ARRAY constructor execution!
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
PT_DYNAMIC          = 2
PT_TLS              = 7

PF_X                = 1
PF_W                = 2

// Dynamic Tags (ELF64 Elf64_Dyn.d_tag)
DT_NULL             = 0
DT_NEEDED           = 1
DT_PLTRELSZ         = 2
DT_HASH             = 4
DT_STRTAB           = 5
DT_SYMTAB           = 6
DT_RELA             = 7
DT_RELASZ           = 8
DT_STRSZ            = 10
DT_INIT             = 12
DT_SONAME           = 14
DT_RPATH            = 15
DT_JMPREL           = 23
DT_INIT_ARRAY       = 25
DT_INIT_ARRAYSZ     = 27
DT_RUNPATH          = 29
DT_GNU_HASH         = 1879047925 // 0x6ffffef5

// x86_64 Relocation Types
R_X86_64_64         = 1
R_X86_64_COPY       = 5
R_X86_64_GLOB_DAT   = 6
R_X86_64_JUMP_SLOT  = 7
R_X86_64_RELATIVE   = 8
R_X86_64_DTPMOD64   = 16
R_X86_64_DTPOFF64   = 17
R_X86_64_TPOFF64    = 18
R_X86_64_IRELATIVE  = 37

// ── Global Sovereign Linker State (TCB/TLS, Loaded Graph, C-ABI Errno) ────────
G_FFI_LOADED_LIBS   = list()
G_FFI_TLS_TCB       = 0
G_FFI_TLS_ALLOC_OFF = 0
G_FFI_TLS_MOD_SEQ   = 1
G_FFI_ERRNO_PTR     = 0
G_FFI_SHIM_NAMES    = list()
G_FFI_SHIM_ADDRS    = list()
G_FFI_SHIM_READY    = 0

// ── 1. Sovereign Pure-Lipi C-ABI Shim Functions (0% libc) ────────────────────
// WHY: Real Linux C libraries (libz, libpng, libm, etc.) import ~15 core C runtime
// functions (malloc/free/memcpy/strlen/__errno_location). Lipi supplies them directly
// from bare-metal Linux syscalls via Static-PIE fn_ptr() with zero libc.so.6!

FFI_ALLOC_MAGIC = 5497049257822334028 // "LIPIMALL"

fn _ffi_c_errno_location
    if G_FFI_ERRNO_PTR == 0
        G_FFI_ERRNO_PTR = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
        if G_FFI_ERRNO_PTR > 0
            mem_write(G_FFI_ERRNO_PTR, 0, 0)
        end
    end
    return G_FFI_ERRNO_PTR
end

fn _ffi_set_errno err_val
    ep = _ffi_c_errno_location()
    if ep > 0 mem_write_u32(ep, 0, err_val & 4294967295) end
    return 0
end

fn _ffi_c_malloc sz
    req = sz
    if req <= 0 req = 16 end
    tot = req + 16
    raw = syscall(9, 0, tot, 3, 34, 0 - 1, 0)
    if raw <= 0 return 0 end
    mem_write(raw, 0, tot)
    mem_write(raw, 8, FFI_ALLOC_MAGIC)
    return raw + 16
end

fn _ffi_c_calloc nmemb sz
    // Linux anonymous SYS_mmap pages are kernel-zeroed by guarantee
    return _ffi_c_malloc(nmemb * sz)
end

fn _ffi_c_free ptr
    if ptr <= 4096 return 0 end
    hdr = ptr - 16
    if mem_read(hdr, 8) == FFI_ALLOC_MAGIC
        tot = mem_read(hdr, 0)
        if tot > 0 and tot < 1073741824
            syscall(11, hdr, tot, 0, 0, 0, 0)
        end
    end
    return 0
end

fn _ffi_c_realloc ptr new_sz
    if ptr <= 4096 return _ffi_c_malloc(new_sz) end
    if new_sz <= 0
        _ffi_c_free(ptr)
        return 0
    end
    np = _ffi_c_malloc(new_sz)
    if np <= 0 return 0 end
    hdr = ptr - 16
    if mem_read(hdr, 8) == FFI_ALLOC_MAGIC
        old_sz = mem_read(hdr, 0) - 16
        cp = old_sz
        if new_sz < cp cp = new_sz end
        if cp > 0 mem_copy(np, ptr, cp) end
        _ffi_c_free(ptr)
    end
    return np
end

fn _ffi_c_memcpy dst src n
    if n > 0 and dst > 0 and src > 0
        mem_copy(dst, src, n)
    end
    return dst
end

fn _ffi_c_memmove dst src n
    if n <= 0 or dst == src return dst end
    if dst > src and dst < src + n
        i = n - 1
        while i >= 0
            mem_byte_write(dst, i, mem_byte_read(src, i))
            i = i - 1
        end
    else
        mem_copy(dst, src, n)
    end
    return dst
end

fn _ffi_c_memset dst c n
    cv = c & 255
    i = 0
    while i < n
        mem_byte_write(dst, i, cv)
        i = i + 1
    end
    return dst
end

fn _ffi_c_memcmp a b n
    i = 0
    while i < n
        va = mem_byte_read(a, i) & 255
        vb = mem_byte_read(b, i) & 255
        if va != vb return va - vb end
        i = i + 1
    end
    return 0
end

fn _ffi_c_memchr s c n
    cv = c & 255
    i = 0
    while i < n
        if (mem_byte_read(s, i) & 255) == cv return s + i end
        i = i + 1
    end
    return 0
end

fn _ffi_c_strlen s
    if s <= 0 return 0 end
    i = 0
    while (mem_byte_read(s, i) & 255) != 0
        i = i + 1
    end
    return i
end

fn _ffi_c_strcmp a b
    i = 0
    while 1
        va = mem_byte_read(a, i) & 255
        vb = mem_byte_read(b, i) & 255
        if va != vb return va - vb end
        if va == 0 return 0 end
        i = i + 1
    end
    return 0
end

fn _ffi_c_strncmp a b n
    i = 0
    while i < n
        va = mem_byte_read(a, i) & 255
        vb = mem_byte_read(b, i) & 255
        if va != vb return va - vb end
        if va == 0 return 0 end
        i = i + 1
    end
    return 0
end

fn _ffi_c_strcpy dst src
    i = 0
    while 1
        b = mem_byte_read(src, i) & 255
        mem_byte_write(dst, i, b)
        if b == 0 break end
        i = i + 1
    end
    return dst
end

fn _ffi_c_open path flags mode
    r = syscall(2, path, flags, mode, 0, 0, 0)
    if r < 0
        _ffi_set_errno(0 - r)
        return 0 - 1
    end
    return r
end

fn _ffi_c_read fd buf cnt
    r = syscall(0, fd, buf, cnt, 0, 0, 0)
    if r < 0
        _ffi_set_errno(0 - r)
        return 0 - 1
    end
    return r
end

fn _ffi_c_write fd buf cnt
    r = syscall(1, fd, buf, cnt, 0, 0, 0)
    if r < 0
        _ffi_set_errno(0 - r)
        return 0 - 1
    end
    return r
end

fn _ffi_c_close fd
    r = syscall(3, fd, 0, 0, 0, 0, 0)
    if r < 0
        _ffi_set_errno(0 - r)
        return 0 - 1
    end
    return r
end

fn _ffi_c_lseek fd off whence
    r = syscall(8, fd, off, whence, 0, 0, 0)
    if r < 0
        _ffi_set_errno(0 - r)
        return 0 - 1
    end
    return r
end

fn _ffi_c_stack_chk_fail
    print("FATAL: [ffi_sovereign] stack protector smash detected (__stack_chk_fail)")
    syscall(231, 134, 0, 0, 0, 0, 0)
    return 0
end

fn _ffi_c_noop a b c
    return 0
end

fn _ffi_c_mutex_init m attr
    if m > 0 mem_write(m, 0, 0) end
    return 0
end

fn _ffi_c_mutex_lock m
    if m > 0
        while atomic_cas(m, 0, 1) == 0
            syscall(24, 0, 0, 0, 0, 0, 0) // sched_yield
        end
    end
    return 0
end

fn _ffi_c_mutex_unlock m
    if m > 0 mem_write(m, 0, 0) end
    return 0
end

fn _ffi_init_shims
    if G_FFI_SHIM_READY == 1 return 0 end
    G_FFI_SHIM_NAMES = [
        "malloc", "calloc", "realloc", "free",
        "memcpy", "memmove", "memset", "memcmp", "memchr",
        "strlen", "strcmp", "strncmp", "strcpy",
        "open", "open64", "read", "write", "close", "lseek", "lseek64",
        "__errno_location", "__stack_chk_fail",
        "__cxa_finalize", "__gmon_start__", "_ITM_registerTMCloneTable", "_ITM_deregisterTMCloneTable",
        "pthread_mutex_init", "pthread_mutex_lock", "pthread_mutex_unlock", "pthread_mutex_destroy"
    ]
    G_FFI_SHIM_ADDRS = [
        fn_ptr(_ffi_c_malloc), fn_ptr(_ffi_c_calloc), fn_ptr(_ffi_c_realloc), fn_ptr(_ffi_c_free),
        fn_ptr(_ffi_c_memcpy), fn_ptr(_ffi_c_memmove), fn_ptr(_ffi_c_memset), fn_ptr(_ffi_c_memcmp), fn_ptr(_ffi_c_memchr),
        fn_ptr(_ffi_c_strlen), fn_ptr(_ffi_c_strcmp), fn_ptr(_ffi_c_strncmp), fn_ptr(_ffi_c_strcpy),
        fn_ptr(_ffi_c_open), fn_ptr(_ffi_c_open), fn_ptr(_ffi_c_read), fn_ptr(_ffi_c_write), fn_ptr(_ffi_c_close), fn_ptr(_ffi_c_lseek), fn_ptr(_ffi_c_lseek),
        fn_ptr(_ffi_c_errno_location), fn_ptr(_ffi_c_stack_chk_fail),
        fn_ptr(_ffi_c_noop), fn_ptr(_ffi_c_noop), fn_ptr(_ffi_c_noop), fn_ptr(_ffi_c_noop),
        fn_ptr(_ffi_c_mutex_init), fn_ptr(_ffi_c_mutex_lock), fn_ptr(_ffi_c_mutex_unlock), fn_ptr(_ffi_c_noop)
    ]
    G_FFI_SHIM_READY = 1
    return 1
end

fn _ffi_lookup_shim name
    _ffi_init_shims()
    i = 0
    n = len(G_FFI_SHIM_NAMES)
    while i < n
        if get(G_FFI_SHIM_NAMES, i) == name
            return get(G_FFI_SHIM_ADDRS, i)
        end
        i = i + 1
    end
    return 0
end

// ── 2. ELF64 Variant-II TCB / PT_TLS & FS:0x28 Stack Canary Setup ─────────────

fn _ffi_ensure_tcb
    // WHY: GCC/Clang shared libraries read the stack-guard canary from %fs:0x28 and
    // thread-local variables from negative offsets below %fs:0 (ELF x86_64 Variant II TLS).
    // We allocate a 64KB anonymous TLS/TCB region: [0..61440) holds static PT_TLS blocks
    // growing downward from TCB = region + 61440; TCB[0] = TCB self-pointer, TCB[0x28] = CSPRNG canary.
    if G_FFI_TLS_TCB > 0 return G_FFI_TLS_TCB end
    region = syscall(9, 0, 65536, 3, 34, 0 - 1, 0)
    if region <= 0 return 0 end
    tcb = region + 61440
    mem_write(tcb, 0, tcb) // %fs:0 = self pointer
    // Fill %fs:0x28 stack canary from Linux kernel CSPRNG (SYS_getrandom 318)
    syscall(318, tcb + 40, 8, 0, 0, 0, 0)
    mem_byte_write(tcb, 40, 0) // standard NUL low byte to catch C string overruns
    // Install %fs base via Linux SYS_arch_prctl (158), ARCH_SET_FS (0x1002 = 4098)
    syscall(158, 4098, tcb, 0, 0, 0, 0)
    G_FFI_TLS_TCB = tcb
    G_FFI_TLS_ALLOC_OFF = 0
    return tcb
end

fn _ffi_alloc_tls_block init_ptr filesz memsz align_v
    tcb = _ffi_ensure_tcb()
    if tcb <= 0 return 0 end
    a = align_v
    if a < 16 a = 16 end
    need = G_FFI_TLS_ALLOC_OFF + memsz
    rem = need % a
    if rem != 0 need = need + (a - rem) end
    if need > 57344 return 0 end
    G_FFI_TLS_ALLOC_OFF = need
    tls_addr = tcb - need
    if filesz > 0 and init_ptr > 0
        mem_copy(tls_addr, init_ptr, filesz)
    end
    // Zero TBSS tail (memsz - filesz)
    zi = filesz
    while zi < memsz
        mem_byte_write(tls_addr, zi, 0)
        zi = zi + 1
    end
    // Return negative TPOFF64 offset relative to %fs:0
    return 0 - need
end

// ── 3. Sovereign Library Container & String / Path Helpers ────────────────────
// Library descriptor list layout (backwards compatible with indices 0..8):
//   0: base_addr          1: map_size           2: dynsym_off (rel to base)
//   3: dynsym_count       4: dynstr_off         5: dynstr_size
//   6: is_loaded (0/1)    7: path               8: min_vaddr
//   9: soname (str)      10: gnu_hash_off      11: needed_list (list of str)
//  12: deps_list (libs)  13: init_array_off    14: init_array_sz
//  15: init_fn_off       16: tls_tpoff         17: tls_mod_id
//  18: rx_segs_list      19: ro_segs_list      20: init_ran (0/1)

fn ffi_lib_new path
    l = list()
    push(l, 0)      // 0: base_addr
    push(l, 0)      // 1: map_size
    push(l, 0)      // 2: dynsym_off
    push(l, 0)      // 3: dynsym_count
    push(l, 0)      // 4: dynstr_off
    push(l, 0)      // 5: dynstr_size
    push(l, 0)      // 6: is_loaded
    push(l, path)   // 7: path
    push(l, 0)      // 8: min_vaddr
    push(l, "")     // 9: soname
    push(l, 0)      // 10: gnu_hash_off
    push(l, list()) // 11: needed_names
    push(l, list()) // 12: loaded_deps
    push(l, 0)      // 13: init_array_off
    push(l, 0)      // 14: init_array_sz
    push(l, 0)      // 15: init_fn_off
    push(l, 0)      // 16: tls_tpoff
    push(l, 0)      // 17: tls_mod_id
    push(l, list()) // 18: rx_segs
    push(l, list()) // 19: ro_segs
    push(l, 0)      // 20: init_ran
    return l
end

fn _ffi_align_down addr
    return addr - (addr % 4096)
end

fn _ffi_align_up sz
    if sz <= 0 return 4096 end
    r = sz % 4096
    if r == 0 return sz end
    return sz + (4096 - r)
end

fn _ffi_read_cstr ptr max_len
    if ptr <= 0 return "" end
    b = buf_new(64)
    i = 0
    while i < max_len
        c = mem_byte_read(ptr, i) & 255
        if c == 0 break end
        buf_write_byte(b, c)
        i = i + 1
    end
    res = buf_to_str(b)
    buf_free(b)
    return res
end

fn _ffi_cstr_eq ptr name
    n = len(name)
    i = 0
    while i < n
        if (mem_byte_read(ptr, i) & 255) != (ord(char_at(name, i)) & 255)
            return 0
        end
        i = i + 1
    end
    if (mem_byte_read(ptr, n) & 255) == 0 return 1 end
    return 0
end

fn _ffi_dirname path
    n = len(path)
    i = n - 1
    while i >= 0
        if ord(char_at(path, i)) == 47 // '/'
            if i == 0 return "/" end
            return str_sub(path, 0, i)
        end
        i = i - 1
    end
    return "."
end

fn _ffi_basename path
    n = len(path)
    i = n - 1
    while i >= 0
        if ord(char_at(path, i)) == 47
            return str_sub(path, i + 1, n)
        end
        i = i - 1
    end
    return path
end

fn _ffi_is_virtual_libc_soname name
    // WHY: Standard glibc runtime DSOs are satisfied directly by Lipi's Sovereign C-ABI Shim Table
    // without importing glibc's internal _rtld_global ld.so coupling.
    if name == "libc.so.6" or name == "libpthread.so.0" or name == "libdl.so.2" or name == "librt.so.1" or name == "ld-linux-x86-64.so.2"
        return 1
    end
    return 0
end

fn _ffi_file_readable path
    if len(path) == 0 return 0 end
    if syscall(21, path, 4, 0, 0, 0, 0) == 0 return 1 end // SYS_access(R_OK)
    return 0
end

fn _ffi_find_loaded_by_name name
    bn = _ffi_basename(name)
    i = 0
    while i < len(G_FFI_LOADED_LIBS)
        l = get(G_FFI_LOADED_LIBS, i)
        if get(l, 6) == 1
            if get(l, 7) == name or get(l, 9) == name or get(l, 9) == bn or _ffi_basename(get(l, 7)) == bn
                return l
            end
        end
        i = i + 1
    end
    return 0
end

fn _ffi_resolve_so_path soname parent_dir rpath_str
    // Search order: absolute/direct -> parent dir -> DT_RUNPATH/DT_RPATH -> standard Linux x86_64 lib dirs
    if len(soname) > 0 and ord(char_at(soname, 0)) == 47 and _ffi_file_readable(soname) == 1
        return soname
    end
    if len(parent_dir) > 0
        cand = parent_dir + "/" + soname
        if _ffi_file_readable(cand) == 1 return cand end
    end
    if len(rpath_str) > 0
        // Split colon-separated RPATH / RUNPATH entries
        rn = len(rpath_str)
        st = 0
        ri = 0
        while ri <= rn
            if ri == rn or ord(char_at(rpath_str, ri)) == 58 // ':'
                if ri > st
                    dir_p = str_sub(rpath_str, st, ri)
                    if dir_p == "$ORIGIN" dir_p = parent_dir end
                    cand_r = dir_p + "/" + soname
                    if _ffi_file_readable(cand_r) == 1 return cand_r end
                end
                st = ri + 1
            end
            ri = ri + 1
        end
    end
    std_dirs = ["/lib/x86_64-linux-gnu", "/usr/lib/x86_64-linux-gnu", "/lib64", "/usr/lib64", "/usr/lib", "/lib"]
    di = 0
    while di < len(std_dirs)
        cand_s = get(std_dirs, di) + "/" + soname
        if _ffi_file_readable(cand_s) == 1 return cand_s end
        di = di + 1
    end
    return ""
end

// ── 4. O(1) DT_GNU_HASH + .dynsym Symbol Lookup (Local & Global Scope) ───────

fn _ffi_gnu_hash_name name
    h = 5381
    i = 0
    n = len(name)
    while i < n
        h = (((h << 5) + h) + (ord(char_at(name, i)) & 255)) & 4294967295
        i = i + 1
    end
    return h
end

fn _ffi_find_symbol_entry_in_lib lib sym_name
    // Returns [addr, st_size, found (0/1)] for a DEFINED (st_shndx != 0) symbol in `lib`.
    if get(lib, 6) == 0 return [0, 0, 0] end
    base = get(lib, 0)
    dynsym_off = get(lib, 2)
    sym_count = get(lib, 3)
    dynstr_off = get(lib, 4)
    min_vaddr = get(lib, 8)
    gnu_hash_off = 0
    if len(lib) > 10 gnu_hash_off = get(lib, 10) end
    if dynsym_off == 0 or dynstr_off == 0 return [0, 0, 0] end

    // Fast path: O(1) DT_GNU_HASH Bloom filter + bucket chain
    if gnu_hash_off > 0
        gh = base + gnu_hash_off
        nbuckets = mem_read_u32(gh, 0)
        symoffset = mem_read_u32(gh, 4)
        bloom_sz = mem_read_u32(gh, 8)
        bloom_shift = mem_read_u32(gh, 12)
        if nbuckets > 0 and bloom_sz > 0
            h = _ffi_gnu_hash_name(sym_name)
            bloom_word = mem_read(gh + 16, ((h / 64) % bloom_sz) * 8)
            bit1 = 1 << (h & 63)
            bit2 = 1 << ((h >> bloom_shift) & 63)
            if (bloom_word & (bit1 | bit2)) == (bit1 | bit2)
                buckets_ptr = gh + 16 + (bloom_sz * 8)
                chains_ptr = buckets_ptr + (nbuckets * 4)
                b_idx = mem_read_u32(buckets_ptr, (h % nbuckets) * 4)
                if b_idx >= symoffset and b_idx > 0
                    cur = b_idx
                    guard = 0
                    while guard < 4096
                        chash = mem_read_u32(chains_ptr, (cur - symoffset) * 4)
                        if (chash & 4294967294) == (h & 4294967294)
                            sym_e = base + dynsym_off + (cur * 24)
                            st_shndx = mem_byte_read(sym_e, 6) + (mem_byte_read(sym_e, 7) * 256)
                            if st_shndx != 0
                                st_name = mem_read_u32(sym_e, 0)
                                if _ffi_cstr_eq(base + dynstr_off + st_name, sym_name) == 1
                                    st_val = mem_read(sym_e, 8)
                                    st_sz = mem_read(sym_e, 16)
                                    return [base + (st_val - min_vaddr), st_sz, 1]
                                end
                            end
                        end
                        if (chash & 1) != 0 break end
                        cur = cur + 1
                        guard = guard + 1
                    end
                end
            end
        end
    end

    // Fallback linear .dynsym scan (handles stripped/minimal .so without GNU_HASH)
    i = 0
    while i < sym_count
        sym_entry = base + dynsym_off + (i * 24)
        st_shndx = mem_byte_read(sym_entry, 6) + (mem_byte_read(sym_entry, 7) * 256)
        st_name = mem_read_u32(sym_entry, 0)
        if st_shndx != 0 or sym_count <= 64
            if _ffi_cstr_eq(base + dynstr_off + st_name, sym_name) == 1
                st_value = mem_read(sym_entry, 8)
                st_size = mem_read(sym_entry, 16)
                if st_shndx != 0 or st_value != 0
                    return [base + (st_value - min_vaddr), st_size, 1]
                end
            end
        end
        i = i + 1
    end
    return [0, 0, 0]
end

fn _ffi_resolve_global_symbol lib sym_name skip_self
    // Search order: (1) self (unless R_X86_64_COPY skip_self=1), (2) BFS deps & global loaded graph, (3) Lipi C-ABI Shim Table
    if skip_self == 0
        r0 = _ffi_find_symbol_entry_in_lib(lib, sym_name)
        if r0[2] == 1 return r0 end
    end
    deps = get(lib, 12)
    di = 0
    while di < len(deps)
        dl = get(deps, di)
        if dl != lib
            rd = _ffi_find_symbol_entry_in_lib(dl, sym_name)
            if rd[2] == 1 return rd end
        end
        di = di + 1
    end
    gi = 0
    while gi < len(G_FFI_LOADED_LIBS)
        gl = get(G_FFI_LOADED_LIBS, gi)
        if gl != lib
            rg = _ffi_find_symbol_entry_in_lib(gl, sym_name)
            if rg[2] == 1 return rg end
        end
        gi = gi + 1
    end
    sh = _ffi_lookup_shim(sym_name)
    if sh > 0 return [sh, 0, 1] end
    return [0, 0, 0]
end

// ── 5. Full ELF64 Shared Object Loader (PT_DYNAMIC + BFS DT_NEEDED + IFUNC + TLS) ──

fn _ffi_load_so_internal path depth
    if depth > 16 return ffi_lib_new(path) end
    existing = _ffi_find_loaded_by_name(path)
    if existing != 0 return existing end

    lib = ffi_lib_new(path)
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0 return lib end
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

    // Verify ELF64 Little-Endian Header
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

    // Step 1: Scan Program Headers (PT_LOAD, PT_DYNAMIC, PT_TLS)
    has_load = 0
    min_vaddr = 0
    max_vaddr = 0
    dyn_vaddr = 0
    dyn_memsz = 0
    tls_foff = 0
    tls_filesz = 0
    tls_memsz = 0
    tls_align = 16
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
            elif ptype == PT_DYNAMIC
                dyn_vaddr = mem_read(fbuf, poff + 16)
                dyn_memsz = mem_read(fbuf, poff + 40)
            elif ptype == PT_TLS
                tls_foff = mem_read(fbuf, poff + 8)
                tls_filesz = mem_read(fbuf, poff + 32)
                tls_memsz = mem_read(fbuf, poff + 40)
                tls_align = mem_read(fbuf, poff + 48)
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

    // Step 2: Map anonymous RW arena (prot=3, NEVER RWX) & copy PT_LOAD segments
    base = syscall(9, 0, map_sz, 3, 34, 0 - 1, 0)
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

    // Ensure %fs TCB/canary exists before running any loaded code; allocate PT_TLS block if present
    _ffi_ensure_tcb()
    if tls_memsz > 0
        tpoff = _ffi_alloc_tls_block(fbuf + tls_foff, tls_filesz, tls_memsz, tls_align)
        list_set(lib, 16, tpoff)
        list_set(lib, 17, G_FFI_TLS_MOD_SEQ)
        G_FFI_TLS_MOD_SEQ = G_FFI_TLS_MOD_SEQ + 1
    end

    // Step 3: Parse Section Headers (optional — handles stripped binaries too via PT_DYNAMIC!)
    rela_blocks = list() // each [ptr, byte_sz]
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
                push(rela_blocks, [fbuf + sh_foff, sh_size])
            end
        end
        sh_idx = sh_idx + 1
    end

    // Step 4: Parse PT_DYNAMIC (DT_NEEDED, DT_STRTAB, DT_SYMTAB, DT_GNU_HASH, DT_RELA, DT_JMPREL, DT_INIT_ARRAY)
    needed_offs = list()
    soname_off = 0 - 1
    rpath_off = 0 - 1
    runpath_off = 0 - 1
    dt_rela_v = 0
    dt_relasz = 0
    dt_jmprel_v = 0
    dt_pltrelsz = 0
    dt_hash_v = 0
    if dyn_vaddr >= min_vaddr and dyn_memsz >= 16 and (dyn_vaddr - min_vaddr) + dyn_memsz <= map_sz
        dyn_ptr = base + (dyn_vaddr - min_vaddr)
        di = 0
        while di + 16 <= dyn_memsz
            d_tag = mem_read(dyn_ptr, di)
            d_val = mem_read(dyn_ptr, di + 8)
            if d_tag == DT_NULL break end
            if d_tag == DT_NEEDED
                push(needed_offs, d_val)
            elif d_tag == DT_STRTAB and d_val >= min_vaddr
                if get(lib, 4) == 0 list_set(lib, 4, d_val - min_vaddr) end
            elif d_tag == DT_STRSZ
                if get(lib, 5) == 0 list_set(lib, 5, d_val) end
            elif d_tag == DT_SYMTAB and d_val >= min_vaddr
                if get(lib, 2) == 0 list_set(lib, 2, d_val - min_vaddr) end
            elif d_tag == DT_HASH and d_val >= min_vaddr
                dt_hash_v = d_val - min_vaddr
            elif d_tag == DT_GNU_HASH and d_val >= min_vaddr
                list_set(lib, 10, d_val - min_vaddr)
            elif d_tag == DT_RELA
                dt_rela_v = d_val
            elif d_tag == DT_RELASZ
                dt_relasz = d_val
            elif d_tag == DT_JMPREL
                dt_jmprel_v = d_val
            elif d_tag == DT_PLTRELSZ
                dt_pltrelsz = d_val
            elif d_tag == DT_SONAME
                soname_off = d_val
            elif d_tag == DT_RPATH
                rpath_off = d_val
            elif d_tag == DT_RUNPATH
                runpath_off = d_val
            elif d_tag == DT_INIT and d_val >= min_vaddr
                list_set(lib, 15, d_val - min_vaddr)
            elif d_tag == DT_INIT_ARRAY and d_val >= min_vaddr
                list_set(lib, 13, d_val - min_vaddr)
            elif d_tag == DT_INIT_ARRAYSZ
                list_set(lib, 14, d_val)
            end
            di = di + 16
        end
    end

    // Derive sym_count from DT_HASH when section headers are stripped
    if get(lib, 3) == 0 and dt_hash_v > 0 and dt_hash_v + 8 <= map_sz
        list_set(lib, 3, mem_read_u32(base + dt_hash_v, 4))
    end
    // If section headers were stripped (no SHT_RELA), use PT_DYNAMIC DT_RELA + DT_JMPREL directly!
    if len(rela_blocks) == 0
        if dt_rela_v >= min_vaddr and dt_relasz > 0 and (dt_rela_v - min_vaddr) + dt_relasz <= map_sz
            push(rela_blocks, [base + (dt_rela_v - min_vaddr), dt_relasz])
        end
        if dt_jmprel_v >= min_vaddr and dt_pltrelsz > 0 and (dt_jmprel_v - min_vaddr) + dt_pltrelsz <= map_sz
            push(rela_blocks, [base + (dt_jmprel_v - min_vaddr), dt_pltrelsz])
        end
    end

    dynstr_off = get(lib, 4)
    if soname_off >= 0 and dynstr_off > 0
        list_set(lib, 9, _ffi_read_cstr(base + dynstr_off + soname_off, 256))
    else
        list_set(lib, 9, _ffi_basename(path))
    end
    rpath_str = ""
    if runpath_off >= 0 and dynstr_off > 0
        rpath_str = _ffi_read_cstr(base + dynstr_off + runpath_off, 1024)
    elif rpath_off >= 0 and dynstr_off > 0
        rpath_str = _ffi_read_cstr(base + dynstr_off + rpath_off, 1024)
    end

    // Mark loaded & register in global scope BEFORE recursive DT_NEEDED load to break cyclic graphs!
    list_set(lib, 6, 1)
    push(G_FFI_LOADED_LIBS, lib)

    // Step 5: Recursive BFS DT_NEEDED Dependency Loading
    parent_dir = _ffi_dirname(path)
    needed_names = get(lib, 11)
    loaded_deps = get(lib, 12)
    ni = 0
    while ni < len(needed_offs)
        if dynstr_off > 0
            nstr = _ffi_read_cstr(base + dynstr_off + get(needed_offs, ni), 256)
            if len(nstr) > 0
                push(needed_names, nstr)
                if _ffi_is_virtual_libc_soname(nstr) == 0
                    dep_path = _ffi_resolve_so_path(nstr, parent_dir, rpath_str)
                    if len(dep_path) > 0
                        dep_lib = _ffi_load_so_internal(dep_path, depth + 1)
                        if get(dep_lib, 6) == 1
                            push(loaded_deps, dep_lib)
                        end
                    end
                end
            end
        end
        ni = ni + 1
    end

    // Step 6: Apply Complete x86_64 Dynamic Relocations while RW (defer IRELATIVE until after RX!)
    dynsym_rel = get(lib, 2)
    sym_cnt = get(lib, 3)
    irel_list = list() // each [patch_off, resolver_addr]
    ri = 0
    while ri < len(rela_blocks)
        rblk = get(rela_blocks, ri)
        rptr = rblk[0]
        rsz = rblk[1]
        rcount = rsz / 24
        ej = 0
        while ej < rcount
            re_off = ej * 24
            r_offset = mem_read(rptr, re_off)
            r_info = mem_read(rptr, re_off + 8)
            r_addend = mem_read(rptr, re_off + 16)
            r_type = r_info & 4294967295
            r_sym = (r_info >> 32) & 4294967295
            patch_off = r_offset - min_vaddr
            if patch_off >= 0 and patch_off + 8 <= map_sz
                if r_type == R_X86_64_RELATIVE
                    mem_write(base, patch_off, base + (r_addend - min_vaddr))
                elif r_type == R_X86_64_IRELATIVE
                    // Defer IFUNC resolver execution until .text is locked PROT_READ|PROT_EXEC
                    push(irel_list, [patch_off, base + (r_addend - min_vaddr)])
                elif r_type == R_X86_64_DTPMOD64
                    mem_write(base, patch_off, get(lib, 17))
                elif r_type == R_X86_64_DTPOFF64
                    sv = 0
                    if dynsym_rel > 0 and r_sym > 0 and (sym_cnt == 0 or r_sym < sym_cnt)
                        sv = mem_read(base + dynsym_rel + (r_sym * 24), 8)
                    end
                    mem_write(base, patch_off, sv + r_addend)
                elif r_type == R_X86_64_TPOFF64
                    sv = 0
                    if dynsym_rel > 0 and r_sym > 0 and (sym_cnt == 0 or r_sym < sym_cnt)
                        sv = mem_read(base + dynsym_rel + (r_sym * 24), 8)
                    end
                    mem_write(base, patch_off, get(lib, 16) + sv + r_addend)
                elif (r_type == R_X86_64_GLOB_DAT or r_type == R_X86_64_JUMP_SLOT or r_type == R_X86_64_64 or r_type == R_X86_64_COPY) and dynsym_rel > 0 and r_sym > 0
                    sym_e = base + dynsym_rel + (r_sym * 24)
                    st_name = mem_read_u32(sym_e, 0)
                    st_shndx = mem_byte_read(sym_e, 6) + (mem_byte_read(sym_e, 7) * 256)
                    st_val = mem_read(sym_e, 8)
                    st_sz = mem_read(sym_e, 16)
                    resolved = 0
                    if r_type == R_X86_64_COPY
                        sname = _ffi_read_cstr(base + dynstr_off + st_name, 256)
                        gr = _ffi_resolve_global_symbol(lib, sname, 1)
                        if gr[2] == 1 and gr[0] > 0 and st_sz > 0 and patch_off + st_sz <= map_sz
                            mem_copy(base + patch_off, gr[0], st_sz)
                        end
                    else
                        if st_shndx != 0 and st_val != 0
                            resolved = base + (st_val - min_vaddr)
                        elif dynstr_off > 0 and st_name > 0
                            sname = _ffi_read_cstr(base + dynstr_off + st_name, 256)
                            gr = _ffi_resolve_global_symbol(lib, sname, 0)
                            if gr[2] == 1 resolved = gr[0] end
                        end
                        if resolved != 0
                            if r_type == R_X86_64_64
                                mem_write(base, patch_off, resolved + r_addend)
                            else
                                mem_write(base, patch_off, resolved)
                            end
                        end
                    end
                end
            end
            ej = ej + 1
        end
        ri = ri + 1
    end

    // Step 7: Hardware W^X Enforcement via SYS_mprotect (10): RO (1) first, then RX (5) on PF_X
    rx_segs = get(lib, 18)
    ro_segs = get(lib, 19)
    if has_load == 1
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

    // Step 8: Execute R_X86_64_IRELATIVE (GLIBC IFUNC) resolvers now that .text is RX!
    ii = 0
    while ii < len(irel_list)
        ir = get(irel_list, ii)
        po = ir[0]
        rfn = ir[1]
        if rfn > 0
            target_fn = c_abi_invoke(rfn, 0, 0, 0, 0, 0)
            mem_write(base, po, target_fn)
        end
        ii = ii + 1
    end

    // Step 9: Run DT_INIT_ARRAY constructors (deps already ran before us via post-order recursion!)
    if get(lib, 20) == 0
        list_set(lib, 20, 1)
        ia_off = get(lib, 13)
        ia_sz = get(lib, 14)
        if ia_off > 0 and ia_sz >= 8
            cnt = ia_sz / 8
            ci = 0
            while ci < cnt
                ctor = mem_read(base + ia_off, ci * 8)
                // Skip sentinel values 0 and -1
                if ctor > 4096
                    c_abi_invoke(ctor, 0, 0, 0, 0, 0)
                end
                ci = ci + 1
            end
        end
    end

    return lib
end

fn ffi_load_so path
    return _ffi_load_so_internal(path, 0)
end

fn ffi_close_so lib
    base = get(lib, 0)
    sz = get(lib, 1)
    if base > 0 and sz > 0
        syscall(11, base, sz, 0, 0, 0, 0) // munmap
    end
    list_set(lib, 0, 0)
    list_set(lib, 6, 0)
    return 0
end

// ── 6. Dynamic Symbol Resolver (O(1) GNU_HASH + Cross-Library DT_NEEDED) ─────

fn ffi_find_symbol lib sym_name
    r = _ffi_find_symbol_entry_in_lib(lib, sym_name)
    if r[2] == 1 return r[0] end
    // Also search transitively loaded DT_NEEDED dependencies
    if len(lib) > 12
        deps = get(lib, 12)
        di = 0
        while di < len(deps)
            rd = _ffi_find_symbol_entry_in_lib(get(deps, di), sym_name)
            if rd[2] == 1 return rd[0] end
            di = di + 1
        end
    end
    return 0
end

// ── 7. System V AMD64 ABI Invoker with 16-Byte Stack Alignment (Trap 2 Defense) ──

fn ffi_check_abi_alignment sp
    if (sp % 16) == 0
        return 1
    end
    return 0
end

fn ffi_prepare_call fn_ptr a0 a1 a2 a3 a4 a5 simulated_sp
    call_pkg = list()
    push(call_pkg, fn_ptr)
    aligned_sp = (simulated_sp / 16) * 16
    push(call_pkg, aligned_sp)
    push(call_pkg, a0)
    push(call_pkg, a1)
    push(call_pkg, a2)
    push(call_pkg, a3)
    push(call_pkg, a4)
    push(call_pkg, a5)
    push(call_pkg, 0)
    return call_pkg
end

fn ffi_inspect_machine_opcode fn_ptr
    if fn_ptr <= 65536
        return 0
    end
    b0 = mem_byte_read(fn_ptr, 0)
    b1 = mem_byte_read(fn_ptr, 1)
    if b0 == 85 or b0 == 243 or b0 == 184 or b0 == 72
        return (b0 * 256) + b1
    end
    return b0
end

fn ffi_call_simulated call_pkg
    fn_ptr = get(call_pkg, 0)
    aligned_sp = get(call_pkg, 1)
    if ffi_check_abi_alignment(aligned_sp) == 0
        return 0 - 1
    end
    if fn_ptr <= 0
        return 0 - 2
    end
    return get(call_pkg, 2) + get(call_pkg, 3) + get(call_pkg, 4) + get(call_pkg, 5) + get(call_pkg, 6) + get(call_pkg, 7)
end

fn ffi_call_native fn_ptr a0 a1 a2 a3 a4
    if fn_ptr <= 0
        return 0 - 2
    end
    return c_abi_invoke(fn_ptr, a0, a1, a2, a3, a4)
end
