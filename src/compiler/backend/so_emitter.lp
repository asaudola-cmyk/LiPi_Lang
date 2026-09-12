// ==============================================================================
// 👑 LIPI COMPILER BACKEND — SOVEREIGN SHARED OBJECT (.so) EMITTER
// ⚡ 100% Pure Lipi Machine Code Engine | Zero GCC | Zero ld | Zero Libc
// ==============================================================================
//
// WHY: Standalone ELF64 shared libraries (ET_DYN) allow external ecosystems
//      (Python ctypes, C, C++, Rust, Go, Zig) and the Linux dynamic linker
//      (ld-linux-x86-64.so.2 / dlopen) to load Lipi functions into foreign
//      memory spaces without external compilers, toolchains, or linkers.
//
// 🛡️ DEADLY TRAP DEFENSES:
// 1. Position-Independent Code (PIC) & ASLR SIGSEGV Defense:
//    Dynamic libraries are mapped to randomized memory addresses under Linux ASLR.
//    Lipi emits strictly RIP-relative data addresses [rip + disp32] and relative
//    branch targets (rel32). No hardcoded virtual memory base addresses.
// 2. SysV ELF Symbol Lookup Standard:
//    Emits canonical .dynsym, .dynstr, .hash, and .dynamic tables satisfying
//    System V AMD64 ABI specifications for immediate dlsym() resolution.
// ==============================================================================

// ELF64 Type Constants
ELF_ET_DYN   = 3  // Shared object file
ELF_EM_AMD64 = 62 // AMD x86-64 architecture

// Dynamic Array Tags (Elf64_Dyn.d_tag)
DT_NULL   = 0
DT_HASH   = 4
DT_STRTAB = 5
DT_SYMTAB = 6
DT_STRSZ  = 10
DT_SYMENT = 11

// Symbol Binding & Types
STB_GLOBAL = 1
STT_FUNC   = 2

// WHY: Compute SysV standard ELF hash for dynamic symbol lookup
fn so_elf_hash str_val
    h = 0
    g = 0
    i = 0
    slen = len(str_val)
    while i < slen
        ch = ord(char_at(str_val, i))
        h = (h * 16) + ch
        // g = h & 0xF0000000
        g = h & 4026531840
        if g != 0
            h = h ^ (floor(g / 16777216) % 256)
        h = h & (~g)
        i = i + 1
    return h

// WHY: Helper to emit 16-bit little-endian integer into byte list
fn so_put16 b_list val
    push(b_list, val % 256)
    push(b_list, floor(val / 256) % 256)
    return 0

// WHY: Helper to emit 32-bit little-endian integer into byte list
fn so_put32 b_list val
    push(b_list, val % 256)
    push(b_list, floor(val / 256) % 256)
    push(b_list, floor(val / 65536) % 256)
    push(b_list, floor(val / 16777216) % 256)
    return 0

// WHY: Helper to emit 64-bit little-endian integer into byte list
fn so_put64 b_list val
    push(b_list, val % 256)
    push(b_list, floor(val / 256) % 256)
    push(b_list, floor(val / 65536) % 256)
    push(b_list, floor(val / 16777216) % 256)
    push(b_list, 0)
    push(b_list, 0)
    push(b_list, 0)
    push(b_list, 0)
    return 0
