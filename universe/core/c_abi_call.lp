// ==============================================================================
// 👑 LIPI UNIVERSE CORE: UNIVERSAL C-ABI DYNAMIC INVOCATION (universe/core/c_abi_call.lp)
// ⚡ 100% Pure Lipi | Zero Libc | Zero C Compiler | Direct AMD64 Register Marshalling
//
// WHY: To truly replace C, C++, and Zig, LiPi must effortlessly invoke existing shared
// object (.so) functions without wrapping them in C stubs or relying on libffi/dlopen.
// This module synthesizes an in-memory AMD64 execution trampoline in an executable page
// (via Linux SYS_mmap), shifts caller registers into System V AMD64 ABI positions
// (RDI, RSI, RDX, RCX, R8, R9), aligns RSP to 16-byte boundary, and executes dynamically.
// ==============================================================================

include "universe/core/memory.lp"
include "universe/core/arena.lp"

// ── Trampoline Cache State ───────────────────────────────────────────────────
// Holds base address of mmapped executable trampoline page
TRAMPOLINE_PAGE_ADDR = 0

// ১. এক্সিকিউটেবল ট্রাম্পোলাইন ইনিশিয়ালাইজেশন (Initialize Executable JIT Trampoline)
// WHY: PROT_READ (1) | PROT_WRITE (2) | PROT_EXEC (4) = 7
// MAP_PRIVATE (2) | MAP_ANONYMOUS (32) = 34
fn c_abi_init_trampoline
    if TRAMPOLINE_PAGE_ADDR > 0
        return TRAMPOLINE_PAGE_ADDR

    page = syscall(9, 0, 4096, 7, 34, -1, 0)
    if page <= 0
        return 0

    // Machine code:
    // 00: 49 89 fb       mov r11, rdi          ; r11 = target function pointer
    // 03: 48 89 f7       mov rdi, rsi          ; rdi = a0
    // 06: 48 89 d6       mov rsi, rdx          ; rsi = a1
    // 09: 48 89 ca       mov rdx, rcx          ; rdx = a2
    // 0c: 49 89 c1       mov rcx, r8           ; rcx = a3
    // 0f: 4d 89 c8       mov r8,  r9           ; r8  = a4
    // 12: 48 83 ec 08    sub rsp, 8            ; 16-byte stack alignment guard
    // 16: 31 c0          xor eax, eax          ; AL=0 (System V variadic vector count)
    // 18: 41 ff d3       call r11              ; Call target C function
    // 1b: 48 83 c4 08    add rsp, 8            ; Restore stack frame
    // 1f: c3             ret                   ; Return RAX to caller

    mem_byte_write(page, 0, 73)   // 0x49
    mem_byte_write(page, 1, 137)  // 0x89
    mem_byte_write(page, 2, 251)  // 0xFB

    mem_byte_write(page, 3, 72)   // 0x48
    mem_byte_write(page, 4, 137)  // 0x89
    mem_byte_write(page, 5, 247)  // 0xF7

    mem_byte_write(page, 6, 72)   // 0x48
    mem_byte_write(page, 7, 137)  // 0x89
    mem_byte_write(page, 8, 214)  // 0xD6

    mem_byte_write(page, 9, 72)   // 0x48
    mem_byte_write(page, 10, 137) // 0x89
    mem_byte_write(page, 11, 202) // 0xCA

    mem_byte_write(page, 12, 73)  // 0x49
    mem_byte_write(page, 13, 137) // 0x89
    mem_byte_write(page, 14, 193) // 0xC1

    mem_byte_write(page, 15, 77)  // 0x4D
    mem_byte_write(page, 16, 137) // 0x89
    mem_byte_write(page, 17, 200) // 0xC8

    mem_byte_write(page, 18, 72)  // 0x48
    mem_byte_write(page, 19, 131) // 0x83
    mem_byte_write(page, 20, 236) // 0xEC
    mem_byte_write(page, 21, 8)   // 0x08

    mem_byte_write(page, 22, 49)  // 0x31
    mem_byte_write(page, 23, 192) // 0xC0

    mem_byte_write(page, 24, 65)  // 0x41
    mem_byte_write(page, 25, 255) // 0xFF
    mem_byte_write(page, 26, 211) // 0xD3

    mem_byte_write(page, 27, 72)  // 0x48
    mem_byte_write(page, 28, 131) // 0x83
    mem_byte_write(page, 29, 196) // 0xC4
    mem_byte_write(page, 30, 8)   // 0x08

    mem_byte_write(page, 31, 195) // 0xC3 (ret)

    TRAMPOLINE_PAGE_ADDR = page
    return page

// ২. ডায়নামিক সি-ফাংশন ইনভোক (Invoke Function via Trampoline)
// Calls target function pointer with up to 5 arguments
fn c_abi_invoke fn_ptr a0 a1 a2 a3 a4
    if fn_ptr <= 0
        return 0
    tramp = c_abi_init_trampoline()
    if tramp <= 0
        return 0

    // In LiPi, calling a function pointer variable executes the machine code at that address!
    // The Lipi compiler treats function values as callable addresses.
    // However, calling through trampoline directly transfers control to the JIT trampoline:
    res = tramp(fn_ptr, a0, a1, a2, a3, a4)
    return res

// ৩. স্কোপড মেমরি পুল দিয়ে সি-ফাংশন কল (Call with Scoped Arena Memory Lifecycle)
// WHY: Eliminates manual free() tracking by allocating C string/struct buffers in an arena
// and dropping the entire arena in a single step after the call completes.
fn c_abi_scoped_call fn_ptr a0 a1 a2 arena_capacity
    if arena_capacity <= 0
        arena_capacity = 65536
    scope_arena = arena_create(arena_capacity)
    
    res = c_abi_invoke(fn_ptr, a0, a1, a2, 0, 0)
    
    arena_destroy(scope_arena)
    return res
