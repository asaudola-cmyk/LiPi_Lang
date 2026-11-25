// ==============================================================================
// 👑 LIPI UNIVERSE CORE: FULL SYSTEM V AMD64 C-ABI BRIDGE (utso/core/c_abi_call.lp)
// ⚡ 100% Pure Lipi | Zero Libc | Zero libffi | Strict W^X Direct Silicon Trampolines
//
// WHY: To invoke ANY native C/C++/Rust/Zig shared library (.so) and pass Lipi
// functions & closures back into C (e.g. qsort, callbacks, FreeType, libpng) with
// ZERO external dependencies, this module synthesizes strict W^X AMD64 trampolines:
//   1. c_abi_invoke(fn_ptr, a0..a4): 5 GPR args (backwards compatible)
//   2. c_abi_invoke6(fn_ptr, a0..a5): full 6 GPR args (rdi, rsi, rdx, rcx, r8, r9)
//   3. c_abi_invoke_full(fn_ptr, int_ptr, int_cnt, flt_ptr, flt_cnt, out_xmm0_ptr)
//      + c_abi_call(fn_ptr, int_list, flt_list) -> [rax, xmm0_bits]:
//      Full System V AMD64 ABI (6 GPR + arbitrary >6 16B-aligned stack args + XMM0..XMM7 + AL!)
//   4. c_abi_make_callback(fn_or_closure) / c_abi_free_callback(cb):
//      Strict W^X C-to-Lipi callback trampoline bridging plain Lipi fns AND heap CLOS closures!
// ==============================================================================

include "utso/core/memory.lp"
include "utso/core/arena.lp"

// ── Strict W^X Trampoline Page Cache ─────────────────────────────────────────
TRAMPOLINE_PAGE_ADDR = 0
G_TRAMPOLINE_6_ADDR    = 0
G_TRAMPOLINE_FULL_ADDR = 0
G_C_ABI_CB_ROOTS     = list()
G_C_ABI_CB_PAGES     = list()

fn _c_abi_write_bytes page off arr
    i = 0
    n = len(arr)
    while i < n
        mem_byte_write(page, off + i, get(arr, i))
        i = i + 1
    end
    return off + n
end

// ১. এক্সিকিউটেবল ট্রাম্পোলাইন ইনিশিয়ালাইজেশন (Initialize Strict W^X JIT Trampolines)
// WHY: Packs 5-arg, 6-arg, and full SysV (GPR + XMM0..7 + >6 stack args) trampolines
// into a single RW page then transitions once to PROT_READ|PROT_EXEC (5) via SYS_mprotect (10).
fn c_abi_init_trampoline
    if TRAMPOLINE_PAGE_ADDR > 0
        return TRAMPOLINE_PAGE_ADDR
    end

    page = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    if page <= 0
        return 0
    end

    // Offset 0: 5-arg GPR trampoline (32 bytes)
    t5 = [
        73, 137, 251, 72, 137, 247, 72, 137, 214, 72, 137, 202,
        76, 137, 193, 77, 137, 200, 72, 131, 236, 8, 49, 192,
        65, 255, 211, 72, 131, 196, 8, 195
    ]
    _c_abi_write_bytes(page, 0, t5)

    // Offset 64: 6-arg GPR trampoline (37 bytes: loads 6th arg a5 from [rsp+8] into r9)
    t6 = [
        73, 137, 251, 72, 137, 247, 72, 137, 214, 72, 137, 202,
        76, 137, 193, 77, 137, 200, 76, 139, 76, 36, 8, 72, 131,
        236, 8, 49, 192, 65, 255, 211, 72, 131, 196, 8, 195
    ]
    _c_abi_write_bytes(page, 64, t6)

    // Offset 128: Full System V AMD64 ABI trampoline (293 bytes)
    // Supports: 0..64 GPR+stack args (16B aligned), XMM0..XMM7 doubles, variadic AL, and XMM0 capture!
    tfull = [
        85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 8,
        73, 137, 252, 73, 137, 245, 72, 137, 211, 77, 137, 206, 77, 137, 199,
        72, 133, 201, 116, 87, 73, 131, 255, 1, 114, 81, 242, 15, 16, 1,
        73, 131, 255, 2, 114, 71, 242, 15, 16, 73, 8,
        73, 131, 255, 3, 114, 60, 242, 15, 16, 81, 16,
        73, 131, 255, 4, 114, 49, 242, 15, 16, 89, 24,
        73, 131, 255, 5, 114, 38, 242, 15, 16, 97, 32,
        73, 131, 255, 6, 114, 27, 242, 15, 16, 105, 40,
        73, 131, 255, 7, 114, 16, 242, 15, 16, 113, 48,
        73, 131, 255, 8, 114, 5, 242, 15, 16, 121, 56,
        72, 131, 251, 6, 118, 42, 77, 133, 237, 116, 37, 72, 137, 216,
        72, 131, 232, 6, 168, 1, 116, 4, 72, 131, 236, 8,
        72, 137, 217, 72, 255, 201, 72, 131, 249, 6, 114, 10,
        65, 255, 116, 205, 0, 72, 255, 201, 235, 240,
        49, 255, 49, 246, 49, 210, 49, 201, 69, 49, 192, 69, 49, 201,
        77, 133, 237, 116, 60,
        72, 131, 251, 1, 114, 54, 73, 139, 125, 0,
        72, 131, 251, 2, 114, 44, 73, 139, 117, 8,
        72, 131, 251, 3, 114, 34, 73, 139, 85, 16,
        72, 131, 251, 4, 114, 24, 73, 139, 77, 24,
        72, 131, 251, 5, 114, 14, 77, 139, 69, 32,
        72, 131, 251, 6, 114, 4, 77, 139, 77, 40,
        76, 137, 248, 72, 131, 248, 8, 118, 5, 184, 8, 0, 0, 0,
        65, 255, 212, 77, 133, 246, 116, 5, 102, 65, 15, 214, 6,
        72, 141, 101, 216, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195
    ]
    _c_abi_write_bytes(page, 128, tfull)

    // Strict W^X transition: remove write permission, enable execute (PROT_READ|PROT_EXEC = 5)
    mret = syscall(10, page, 4096, 5, 0, 0, 0)
    if mret < 0
        syscall(11, page, 4096, 0, 0, 0, 0)
        return 0
    end

    TRAMPOLINE_PAGE_ADDR   = page
    G_TRAMPOLINE_6_ADDR    = page + 64
    G_TRAMPOLINE_FULL_ADDR = page + 128
    return page
end

// ২. ডায়নামিক সি-ফাংশন ইনভোক (5 GPR args — backwards compatible)
fn c_abi_invoke fn_ptr a0 a1 a2 a3 a4
    if fn_ptr <= 0 return 0 end
    tramp = c_abi_init_trampoline()
    if tramp <= 0 return 0 end
    return tramp(fn_ptr, a0, a1, a2, a3, a4)
end

// ৩. ফুল ৬-আর্গুমেন্ট GPR ইনভোক (6 GPR args: rdi..r9)
fn c_abi_invoke6 fn_ptr a0 a1 a2 a3 a4 a5
    if fn_ptr <= 0 return 0 end
    tramp = c_abi_init_trampoline()
    if tramp <= 0 return 0 end
    t6 = tramp + 64
    return t6(fn_ptr, a0, a1, a2, a3, a4, a5)
end

// ৪. পূর্ণ System V AMD64 ABI ইনভোক (Unlimited Int/Stack Args + XMM0..XMM7 + XMM0 Return)
fn c_abi_invoke_full fn_ptr int_ptr int_cnt flt_ptr flt_cnt out_xmm0_ptr
    if fn_ptr <= 0 return 0 end
    tramp = c_abi_init_trampoline()
    if tramp <= 0 return 0 end
    tf = tramp + 128
    return tf(fn_ptr, int_ptr, int_cnt, flt_ptr, flt_cnt, out_xmm0_ptr)
end

// Ergonomic high-level wrapper accepting Lipi lists of int args & float args -> returns [rax_val, xmm0_bits]
fn c_abi_call fn_ptr int_args flt_args
    if fn_ptr <= 0 return [0, 0] end
    if c_abi_init_trampoline() <= 0 return [0, 0] end
    n_i = 0
    if int_args != 0 n_i = len(int_args) end
    n_f = 0
    if flt_args != 0 n_f = len(flt_args) end
    i_buf = 0
    if n_i > 0
        i_buf = alloc(n_i * 8)
        ii = 0
        while ii < n_i
            mem_write(i_buf, ii * 8, get(int_args, ii))
            ii = ii + 1
        end
    end
    f_buf = 0
    if n_f > 0
        f_buf = alloc(n_f * 8)
        fi = 0
        while fi < n_f
            mem_write(f_buf, fi * 8, get(flt_args, fi))
            fi = fi + 1
        end
    end
    out_xmm = alloc(8)
    mem_write(out_xmm, 0, 0)
    rax_res = c_abi_invoke_full(fn_ptr, i_buf, n_i, f_buf, n_f, out_xmm)
    xmm_res = mem_read(out_xmm, 0)
    free(out_xmm)
    if i_buf != 0 free(i_buf) end
    if f_buf != 0 free(f_buf) end
    return [rax_res, xmm_res]
end

// ৫. C-to-Lipi কলব্যাক ট্রাম্পোলাইন (Strict W^X Callback Bridge for Plain Functions & Closures!)
// WHY: Plain Lipi functions already match SysV AMD64 ABI directly (zero overhead!).
// Heap closures (`CLOS` magic 0x434C4F53) expect %r10 = closure_ptr; this allocates a
// strict W^X 16-byte trampoline: `movabs r10, closure; mov rax, [r10+8]; jmp rax`
// preserving all incoming C arguments (GPR + XMM + stack args) untouched!
fn c_abi_make_callback callable
    if callable <= 4096 return 0 end
    // Detect Lipi heap closure object (magic 0x434C4F53 = 1129074515 "CLOS" at [+0])
    magic = mem_read(callable, 0)
    if magic != 1129074515
        // Plain Lipi function pointer — directly callable from C with zero wrapper!
        return callable
    end
    page = syscall(9, 0, 4096, 3, 34, 0 - 1, 0)
    if page <= 0 return 0 end
    // 49 BA <u64 closure_ptr>   (movabs r10, closure_ptr)
    // 49 8B 42 08               (mov rax, [r10 + 8])
    // FF E0                     (jmp rax)
    mem_byte_write(page, 0, 73)   // 0x49
    mem_byte_write(page, 1, 186)  // 0xBA
    mem_write(page, 2, callable)  // 8-byte closure pointer
    mem_byte_write(page, 10, 73)  // 0x49
    mem_byte_write(page, 11, 139) // 0x8B
    mem_byte_write(page, 12, 66)  // 0x42
    mem_byte_write(page, 13, 8)   // 0x08
    mem_byte_write(page, 14, 255) // 0xFF
    mem_byte_write(page, 15, 224) // 0xE0
    if syscall(10, page, 4096, 5, 0, 0, 0) < 0
        syscall(11, page, 4096, 0, 0, 0, 0)
        return 0
    end
    // Keep closure GC-rooted while trampoline is live
    push(G_C_ABI_CB_ROOTS, callable)
    push(G_C_ABI_CB_PAGES, page)
    return page
end

fn c_abi_make_closure_callback closure_obj
    return c_abi_make_callback(closure_obj)
end

fn c_abi_free_callback cb_ptr
    if cb_ptr <= 4096 return 0 end
    i = 0
    n = len(G_C_ABI_CB_PAGES)
    while i < n
        if get(G_C_ABI_CB_PAGES, i) == cb_ptr
            syscall(11, cb_ptr, 4096, 0, 0, 0, 0)
            list_set(G_C_ABI_CB_PAGES, i, 0)
            list_set(G_C_ABI_CB_ROOTS, i, 0)
            return 1
        end
        i = i + 1
    end
    return 0
end

// ৬. স্কোপড মেমরি পুল দিয়ে সি-ফাংশন কল (Call with Scoped Arena Memory Lifecycle)
fn c_abi_scoped_call fn_ptr a0 a1 a2 arena_capacity
    if arena_capacity <= 0
        arena_capacity = 65536
    end
    scope_arena = arena_create(arena_capacity)
    res = c_abi_invoke(fn_ptr, a0, a1, a2, 0, 0)
    arena_destroy(scope_arena)
    return res
end
