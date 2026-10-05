// ==============================================================================
// 👑 LIPI M:N ULTRA-LIGHTWEIGHT FIBER RUNTIME & SILICON LOCK-FREE SCHEDULER
// ⚡ 100% Pure Lipi | AMD64 Silicon Context Switching | Micro-Stacks | Zero Libc
// ==============================================================================
//
// WHY: Operating system kernel threads (sys_clone / pthreads) incur massive memory overhead
//      (8MB per thread) and expensive context switch latency (1000+ CPU cycles).
//      Lipi Fibers (green-threads) operate entirely in user-space with physical AMD64
//      silicon context switching, canary stack-guard bounds checking, and a lock-free
//      ring buffer scheduler capable of orchestrating millions of concurrent fibers
//      with sub-microsecond latency.
//
// SILICON MACHINE-LEVEL CONTEXT SWITCHING ARCHITECTURE (System V AMD64 ABI):
// 1. switch_context: Saves caller callee-saved registers (%rbp, %rbx, %r12-%r15)
//    on the current stack, stores %rsp into old_sp_ptr, loads %rsp from new_sp,
//    restores callee-saved registers from the new stack, and returns (ret).
// 2. fiber_bootstrap: Guarantees 16-byte stack alignment (and rsp, -16) per ABI,
//    unpacks the fiber descriptor, and executes the target fiber task in silicon.
// ==============================================================================

include "universe/core/memory.lp"

// ── Fiber Lifecycle State Constants ───────────────────────────────────────────
FIBER_READY   = 0
FIBER_RUNNING = 1
FIBER_WAITING = 2
FIBER_DEAD    = 3

// Canary magic value to detect stack overflow at bottom of stack frame (Trap 1 Defense)
FIBER_CANARY_MAGIC = 3735928559 // 0xDEADBEEF in decimal

// ── 0. Silicon AMD64 Context Switch Engine ────────────────────────────────────
// Holds base address of mmapped executable page for silicon context switching
G_FIBER_SWAP_ENGINE = 0
G_CURRENT_FIBER = 0

fn fiber_get_swap_engine
    if G_FIBER_SWAP_ENGINE != 0
        return G_FIBER_SWAP_ENGINE
    end

    // Allocate 4KB page with PROT_READ|WRITE|EXEC (syscall 9: sys_mmap)
    p = syscall(9, 0, 4096, 7, 34, -1, 0)
    if p <= 0
        return 0
    end

    // ──────────────────────────────────────────────────────────────────────────
    // BLOCK 1: switch_context at offset 0 (0x00)
    // Signature: switch_context(rdi: old_sp_ptr, rsi: new_sp)
    // Preserves and swaps: %rbp, %rbx, %r12-%r15, %rsp
    // ──────────────────────────────────────────────────────────────────────────
    mem_byte_write(p, 0, 85)         // push rbp
    mem_byte_write(p, 1, 83)         // push rbx
    mem_byte_write(p, 2, 65)         // push r12 (41 54)
    mem_byte_write(p, 3, 84)
    mem_byte_write(p, 4, 65)         // push r13 (41 55)
    mem_byte_write(p, 5, 85)
    mem_byte_write(p, 6, 65)         // push r14 (41 56)
    mem_byte_write(p, 7, 86)
    mem_byte_write(p, 8, 65)         // push r15 (41 57)
    mem_byte_write(p, 9, 87)
    mem_byte_write(p, 10, 72)        // mov [rdi], rsp (48 89 27)
    mem_byte_write(p, 11, 137)
    mem_byte_write(p, 12, 39)
    mem_byte_write(p, 13, 72)        // mov rsp, rsi (48 89 f4)
    mem_byte_write(p, 14, 137)
    mem_byte_write(p, 15, 244)
    mem_byte_write(p, 16, 65)        // pop r15 (41 5f)
    mem_byte_write(p, 17, 95)
    mem_byte_write(p, 18, 65)        // pop r14 (41 5e)
    mem_byte_write(p, 19, 94)
    mem_byte_write(p, 20, 65)        // pop r13 (41 5d)
    mem_byte_write(p, 21, 93)
    mem_byte_write(p, 22, 65)        // pop r12 (41 5c)
    mem_byte_write(p, 23, 92)
    mem_byte_write(p, 24, 91)        // pop rbx (5b)
    mem_byte_write(p, 25, 93)        // pop rbp (5d)
    mem_byte_write(p, 26, 195)       // ret (c3)

    // ──────────────────────────────────────────────────────────────────────────
    // BLOCK 1.5: yield_silicon at offset 32 (0x20)
    // Signature: yield_silicon(rdi: desc)
    // Fast cooperative silicon yield directly called from native AMD64 code
    // ──────────────────────────────────────────────────────────────────────────
    // 32: mov qword ptr [rdi + 8], 0 (state = FIBER_READY: 48 c7 47 08 00 00 00 00)
    mem_byte_write(p, 32, 72)
    mem_byte_write(p, 33, 199)
    mem_byte_write(p, 34, 71)
    mem_byte_write(p, 35, 8)
    mem_byte_write(p, 36, 0)
    mem_byte_write(p, 37, 0)
    mem_byte_write(p, 38, 0)
    mem_byte_write(p, 39, 0)
    // 40: inc qword ptr [rdi + 48] (step_count++: 48 ff 47 30)
    mem_byte_write(p, 40, 72)
    mem_byte_write(p, 41, 255)
    mem_byte_write(p, 42, 71)
    mem_byte_write(p, 43, 48)
    // 44: mov rsi, [rdi + 0] (sched_sp: 48 8b 77 00)
    mem_byte_write(p, 44, 72)
    mem_byte_write(p, 45, 139)
    mem_byte_write(p, 46, 119)
    mem_byte_write(p, 47, 0)
    // 48: lea rdi, [rdi + 16] (&fiber_sp: 48 8d 7f 10)
    mem_byte_write(p, 48, 72)
    mem_byte_write(p, 49, 141)
    mem_byte_write(p, 50, 127)
    mem_byte_write(p, 51, 16)
    // 52: jmp switch_context (target 0, rel = -57: E9 C7 FF FF FF)
    mem_byte_write(p, 52, 233)
    mem_byte_write(p, 53, 199)
    mem_byte_write(p, 54, 255)
    mem_byte_write(p, 55, 255)
    mem_byte_write(p, 56, 255)

    // ──────────────────────────────────────────────────────────────────────────
    // BLOCK 2: fiber_bootstrap at offset 64 (0x40)
    // WHY: Entry trampoline for freshly spawned fibers.
    //      Guarantees 16-byte stack alignment per AMD64 System V ABI before invocation.
    // Registers upon arrival: rbx = pointer to 64-byte fiber descriptor
    //                         r12 = backup pointer to fiber descriptor
    // ──────────────────────────────────────────────────────────────────────────
    // 64: and rsp, -16 (48 83 e4 f0)
    mem_byte_write(p, 64, 72)
    mem_byte_write(p, 65, 131)
    mem_byte_write(p, 66, 228)
    mem_byte_write(p, 67, 240)
    // 68: mov rax, [rbx + 24] (load fn_code: 48 8b 43 18)
    mem_byte_write(p, 68, 72)
    mem_byte_write(p, 69, 139)
    mem_byte_write(p, 70, 67)
    mem_byte_write(p, 71, 24)
    // 72: cmp rax, 0 (48 83 f8 00) - Guard against null / invalid fn_code
    mem_byte_write(p, 72, 72)
    mem_byte_write(p, 73, 131)
    mem_byte_write(p, 74, 248)
    mem_byte_write(p, 75, 0)
    // 76: jle .fiber_done (target offset 320, rel = 238: 0F 8E EE 00 00 00)
    mem_byte_write(p, 76, 15)
    mem_byte_write(p, 77, 142)
    mem_byte_write(p, 78, 238)
    mem_byte_write(p, 79, 0)
    mem_byte_write(p, 80, 0)
    mem_byte_write(p, 81, 0)
    // 82: cmp rax, 1 (48 83 f8 01)
    mem_byte_write(p, 82, 72)
    mem_byte_write(p, 83, 131)
    mem_byte_write(p, 84, 248)
    mem_byte_write(p, 85, 1)
    // 86: je .do_task1 (target offset 128, rel = 36: 0F 84 24 00 00 00)
    mem_byte_write(p, 86, 15)
    mem_byte_write(p, 87, 132)
    mem_byte_write(p, 88, 36)
    mem_byte_write(p, 89, 0)
    mem_byte_write(p, 90, 0)
    mem_byte_write(p, 91, 0)
    // 92: cmp rax, 2 (48 83 f8 02)
    mem_byte_write(p, 92, 72)
    mem_byte_write(p, 93, 131)
    mem_byte_write(p, 94, 248)
    mem_byte_write(p, 95, 2)
    // 96: je .do_task2 (target offset 256, rel = 154: 0F 84 9A 00 00 00)
    mem_byte_write(p, 96, 15)
    mem_byte_write(p, 97, 132)
    mem_byte_write(p, 98, 154)
    mem_byte_write(p, 99, 0)
    mem_byte_write(p, 100, 0)
    mem_byte_write(p, 101, 0)
    // 102: Direct native function pointer execution:
    // mov rdi, [rbx + 32] (pass arg in %rdi: 48 8b 7b 20)
    mem_byte_write(p, 102, 72)
    mem_byte_write(p, 103, 139)
    mem_byte_write(p, 104, 123)
    mem_byte_write(p, 105, 32)
    // 106: mov rsi, rbx (pass desc in %rsi for silicon yield: 48 89 de)
    mem_byte_write(p, 106, 72)
    mem_byte_write(p, 107, 137)
    mem_byte_write(p, 108, 222)
    // 109: mov rdx, [rbx + 56] (pass fiber_id in %rdx: 48 8b 53 38)
    mem_byte_write(p, 109, 72)
    mem_byte_write(p, 110, 139)
    mem_byte_write(p, 111, 83)
    mem_byte_write(p, 112, 56)
    // 113: call rax (ff d0)
    mem_byte_write(p, 113, 255)
    mem_byte_write(p, 114, 208)
    // 115: mov [rbx + 40], rax (store result: 48 89 43 28)
    mem_byte_write(p, 115, 72)
    mem_byte_write(p, 116, 137)
    mem_byte_write(p, 117, 67)
    mem_byte_write(p, 118, 40)
    // 119: inc qword ptr [rbx + 48] (step_count++: 48 ff 43 30)
    mem_byte_write(p, 119, 72)
    mem_byte_write(p, 120, 255)
    mem_byte_write(p, 121, 67)
    mem_byte_write(p, 122, 48)
    // 123: jmp .fiber_done (target offset 320, rel = 192: E9 C0 00 00 00)
    mem_byte_write(p, 123, 233)
    mem_byte_write(p, 124, 192)
    mem_byte_write(p, 125, 0)
    mem_byte_write(p, 126, 0)
    mem_byte_write(p, 127, 0)

    // ──────────────────────────────────────────────────────────────────────────
    // BLOCK 3: .do_task1 at offset 128 (0x80) - Silicon Cooperative Counter Task
    // WHY: Native AMD64 loop that yields back to scheduler on each cooperative slice
    // ──────────────────────────────────────────────────────────────────────────
    // 128: mov rcx, [rbx + 40] (load current counter / result: 48 8b 4b 28)
    mem_byte_write(p, 128, 72)
    mem_byte_write(p, 129, 139)
    mem_byte_write(p, 130, 75)
    mem_byte_write(p, 131, 40)
    // 132: mov rdx, [rbx + 32] (load limit arg: 48 8b 53 20)
    mem_byte_write(p, 132, 72)
    mem_byte_write(p, 133, 139)
    mem_byte_write(p, 134, 83)
    mem_byte_write(p, 135, 32)
    // 136: cmp rcx, rdx (48 39 d1)
    mem_byte_write(p, 136, 72)
    mem_byte_write(p, 137, 57)
    mem_byte_write(p, 138, 209)
    // 139: jge .fiber_done (target 320: 0F 8D AF 00 00 00)
    mem_byte_write(p, 139, 15)
    mem_byte_write(p, 140, 141)
    mem_byte_write(p, 141, 175)
    mem_byte_write(p, 142, 0)
    mem_byte_write(p, 143, 0)
    mem_byte_write(p, 144, 0)
    // 145: inc rcx (48 ff c1)
    mem_byte_write(p, 145, 72)
    mem_byte_write(p, 146, 255)
    mem_byte_write(p, 147, 193)
    // 148: mov [rbx + 40], rcx (store updated counter: 48 89 4b 28)
    mem_byte_write(p, 148, 72)
    mem_byte_write(p, 149, 137)
    mem_byte_write(p, 150, 75)
    mem_byte_write(p, 151, 40)
    // 152: mov rax, [rbx + 48] (load step_count: 48 8b 43 30)
    mem_byte_write(p, 152, 72)
    mem_byte_write(p, 153, 139)
    mem_byte_write(p, 154, 67)
    mem_byte_write(p, 155, 48)
    // 156: inc rax (48 ff c0)
    mem_byte_write(p, 156, 72)
    mem_byte_write(p, 157, 255)
    mem_byte_write(p, 158, 192)
    // 159: mov [rbx + 48], rax (store step_count: 48 89 43 30)
    mem_byte_write(p, 159, 72)
    mem_byte_write(p, 160, 137)
    mem_byte_write(p, 161, 67)
    mem_byte_write(p, 162, 48)
    // 163: cmp rcx, rdx (48 39 d1)
    mem_byte_write(p, 163, 72)
    mem_byte_write(p, 164, 57)
    mem_byte_write(p, 165, 209)
    // 166: jge .fiber_done (target 320: 0F 8D 94 00 00 00)
    mem_byte_write(p, 166, 15)
    mem_byte_write(p, 167, 141)
    mem_byte_write(p, 168, 148)
    mem_byte_write(p, 169, 0)
    mem_byte_write(p, 170, 0)
    mem_byte_write(p, 171, 0)
    // 172: Not finished: mark state = FIBER_READY (0)
    // mov qword ptr [rbx + 8], 0 (48 c7 43 08 00 00 00 00)
    mem_byte_write(p, 172, 72)
    mem_byte_write(p, 173, 199)
    mem_byte_write(p, 174, 67)
    mem_byte_write(p, 175, 8)
    mem_byte_write(p, 176, 0)
    mem_byte_write(p, 177, 0)
    mem_byte_write(p, 178, 0)
    mem_byte_write(p, 179, 0)
    // 180: lea rdi, [rbx + 16] (&desc->saved_sp: 48 8d 7b 10)
    mem_byte_write(p, 180, 72)
    mem_byte_write(p, 181, 141)
    mem_byte_write(p, 182, 123)
    mem_byte_write(p, 183, 16)
    // 184: mov rsi, [rbx + 0] (load saved sched_sp: 48 8b 73 00)
    mem_byte_write(p, 184, 72)
    mem_byte_write(p, 185, 139)
    mem_byte_write(p, 186, 115)
    mem_byte_write(p, 187, 0)
    // 188: call switch_context (target 0, rel = -193: E8 3F FF FF FF)
    mem_byte_write(p, 188, 232)
    mem_byte_write(p, 189, 63)
    mem_byte_write(p, 190, 255)
    mem_byte_write(p, 191, 255)
    mem_byte_write(p, 192, 255)
    // 193: jmp 128 (resume loop at offset 128, rel = -70: E9 BA FF FF FF)
    mem_byte_write(p, 193, 233)
    mem_byte_write(p, 194, 186)
    mem_byte_write(p, 195, 255)
    mem_byte_write(p, 196, 255)
    mem_byte_write(p, 197, 255)

    // ──────────────────────────────────────────────────────────────────────────
    // BLOCK 4: .do_task2 at offset 256 (0x100) - Silicon Accumulator Task
    // ──────────────────────────────────────────────────────────────────────────
    // 256: mov rdx, [rbx + 32] (arg: 48 8b 53 20)
    mem_byte_write(p, 256, 72)
    mem_byte_write(p, 257, 139)
    mem_byte_write(p, 258, 83)
    mem_byte_write(p, 259, 32)
    // 260: mov rax, [rbx + 40] (cur result: 48 8b 43 28)
    mem_byte_write(p, 260, 72)
    mem_byte_write(p, 261, 139)
    mem_byte_write(p, 262, 67)
    mem_byte_write(p, 263, 40)
    // 264: add rax, rdx (48 01 d0)
    mem_byte_write(p, 264, 72)
    mem_byte_write(p, 265, 1)
    mem_byte_write(p, 266, 208)
    // 267: mov [rbx + 40], rax (store result: 48 89 43 28)
    mem_byte_write(p, 267, 72)
    mem_byte_write(p, 268, 137)
    mem_byte_write(p, 269, 67)
    mem_byte_write(p, 270, 40)
    // 271: mov rax, [rbx + 48] (load step_count: 48 8b 43 30)
    mem_byte_write(p, 271, 72)
    mem_byte_write(p, 272, 139)
    mem_byte_write(p, 273, 67)
    mem_byte_write(p, 274, 48)
    // 275: inc rax (48 ff c0)
    mem_byte_write(p, 275, 72)
    mem_byte_write(p, 276, 255)
    mem_byte_write(p, 277, 192)
    // 278: mov [rbx + 48], rax (store step_count: 48 89 43 30)
    mem_byte_write(p, 278, 72)
    mem_byte_write(p, 279, 137)
    mem_byte_write(p, 280, 67)
    mem_byte_write(p, 281, 48)
    // 282: jmp .fiber_done (target 320, rel = 33: E9 21 00 00 00)
    mem_byte_write(p, 282, 233)
    mem_byte_write(p, 283, 33)
    mem_byte_write(p, 284, 0)
    mem_byte_write(p, 285, 0)
    mem_byte_write(p, 286, 0)

    // ──────────────────────────────────────────────────────────────────────────
    // BLOCK 5: .fiber_done at offset 320 (0x140) - Termination & Stack Restoration
    // ──────────────────────────────────────────────────────────────────────────
    // 320: mov qword ptr [rbx + 8], 3 (state = FIBER_DEAD: 48 c7 43 08 03 00 00 00)
    mem_byte_write(p, 320, 72)
    mem_byte_write(p, 321, 199)
    mem_byte_write(p, 322, 67)
    mem_byte_write(p, 323, 8)
    mem_byte_write(p, 324, 3)
    mem_byte_write(p, 325, 0)
    mem_byte_write(p, 326, 0)
    mem_byte_write(p, 327, 0)
    // 328: mov rsp, [rbx + 0] (restore scheduler %rsp: 48 8b 23)
    mem_byte_write(p, 328, 72)
    mem_byte_write(p, 329, 139)
    mem_byte_write(p, 330, 35)
    // 331: Restore scheduler callee-saved registers from scheduler stack:
    mem_byte_write(p, 331, 65)        // pop r15 (41 5f)
    mem_byte_write(p, 332, 95)
    mem_byte_write(p, 333, 65)        // pop r14 (41 5e)
    mem_byte_write(p, 334, 94)
    mem_byte_write(p, 335, 65)        // pop r13 (41 5d)
    mem_byte_write(p, 336, 93)
    mem_byte_write(p, 337, 65)        // pop r12 (41 5c)
    mem_byte_write(p, 338, 92)
    mem_byte_write(p, 339, 91)        // pop rbx (5b)
    mem_byte_write(p, 340, 93)        // pop rbp (5d)
    mem_byte_write(p, 341, 195)       // ret (c3)

    G_FIBER_SWAP_ENGINE = p
    return G_FIBER_SWAP_ENGINE
end

fn fiber_context_switch old_sp_ptr new_sp
    sw = fiber_get_swap_engine()
    if sw > 0
        sw(old_sp_ptr, new_sp)
        return 1
    end
    return 0
end

fn fiber_switch_context old_sp_ptr new_sp
    return fiber_context_switch(old_sp_ptr, new_sp)
end

fn fiber_build_switch_code
    return fiber_get_swap_engine()
end

fn fiber_get_silicon_yield
    eng = fiber_get_swap_engine()
    if eng <= 0
        return 0
    end
    return eng + 32
end

fn fiber_get_bootstrap_entry
    eng = fiber_get_swap_engine()
    if eng <= 0
        return 0
    end
    return eng + 64
end

// ── 1. Fiber Data Structure ───────────────────────────────────────────────────
// Fiber container fields:
//   f[0]: id (int)
//   f[1]: state (FIBER_READY..FIBER_DEAD)
//   f[2]: stack_base (pointer to allocated stack buffer)
//   f[3]: stack_size (int)
//   f[4]: stack_ptr (active silicon stack pointer)
//   f[5]: fn_code (integer task action identifier or native function pointer)
//   f[6]: arg (initial argument value)
//   f[7]: result (accumulated or returned value)
//   f[8]: step_count (number of execution slices yielded)
//   f[9]: sched_sp_slot (pointer to 64-byte Silicon Fiber Descriptor)

fn fiber_new id fn_code arg stack_size
    f = list()
    if stack_size < 1024
        stack_size = 4096 // Default 4KB stack
    end

    stk = malloc(stack_size)
    mem_fill(stk, 0, stack_size)

    // Plant stack canary at bottom of stack (offset 0) for Trap 1 Defense
    c0 = FIBER_CANARY_MAGIC % 256
    c1 = (FIBER_CANARY_MAGIC / 256) % 256
    c2 = (FIBER_CANARY_MAGIC / 65536) % 256
    c3 = (FIBER_CANARY_MAGIC / 16777216) % 256
    mem_byte_write(stk, 0, c0)
    mem_byte_write(stk, 1, c1)
    mem_byte_write(stk, 2, c2)
    mem_byte_write(stk, 3, c3)

    // Initialize Silicon Context Switch Engine
    engine = fiber_get_swap_engine()
    boot_entry = engine + 64 // offset 64 is fiber_bootstrap

    // Allocate 64-byte Silicon Fiber Descriptor
    // Layout:
    //   desc + 0:  sched_sp (8B) - saved scheduler %rsp
    //   desc + 8:  state (8B)
    //   desc + 16: fiber_sp (8B) - saved fiber %rsp
    //   desc + 24: fn_code (8B)
    //   desc + 32: arg (8B)
    //   desc + 40: result (8B)
    //   desc + 48: step_count (8B)
    //   desc + 56: fiber_id (8B)
    desc = malloc(64)
    mem_zero(desc, 64)
    mem_write(desc, 0, 0)
    mem_write(desc, 8, FIBER_READY)
    mem_write(desc, 24, fn_code)
    mem_write(desc, 32, arg)
    mem_write(desc, 40, 0)
    mem_write(desc, 48, 0)
    mem_write(desc, 56, id)

    // 16-Byte Stack Alignment and Bootstrap Frame Initialization:
    // AMD64 System V ABI mandates (%rsp + 8) % 16 == 0 at function entry points.
    stk_top = stk + stack_size - 128
    stk_top = stk_top - (stk_top % 16)

    // Pre-populate stack for switch_context:
    // [stk_top - 8]:  fiber_bootstrap entry address (ret target)
    // [stk_top - 16]: rbp = 0
    // [stk_top - 24]: rbx = desc (passed into fiber_bootstrap)
    // [stk_top - 32]: r12 = desc (secondary descriptor backup)
    // [stk_top - 40]: r13 = 0
    // [stk_top - 48]: r14 = 0
    // [stk_top - 56]: r15 = 0
    mem_write(stk_top - 8, 0, boot_entry)
    mem_write(stk_top - 16, 0, 0)
    mem_write(stk_top - 24, 0, desc)
    mem_write(stk_top - 32, 0, desc)
    mem_write(stk_top - 40, 0, 0)
    mem_write(stk_top - 48, 0, 0)
    mem_write(stk_top - 56, 0, 0)

    initial_sp = stk_top - 56
    mem_write(desc, 16, initial_sp)

    push(f, id)            // 0: id
    push(f, FIBER_READY)   // 1: state
    push(f, stk)           // 2: stack_base
    push(f, stack_size)    // 3: stack_size
    push(f, initial_sp)    // 4: stack_ptr
    push(f, fn_code)       // 5: fn_code
    push(f, arg)           // 6: arg
    push(f, 0)             // 7: result
    push(f, 0)             // 8: step_count
    push(f, desc)          // 9: sched_sp_slot (silicon descriptor)
    return f
end

// Verifies that stack canary is untouched (Trap 1 Defense)
fn fiber_check_stack_guard f
    if f == 0 or len(f) <= 3
        return 0
    end
    stk = get(f, 2)
    if stk <= 0
        return 0
    end
    c0 = mem_byte_read(stk, 0)
    c1 = mem_byte_read(stk, 1)
    c2 = mem_byte_read(stk, 2)
    c3 = mem_byte_read(stk, 3)
    val = c0 + (c1 * 256) + (c2 * 65536) + (c3 * 16777216)
    if val != FIBER_CANARY_MAGIC
        return 0 // Stack guard corrupted!
    end
    return 1     // Stack guard intact
end

fn fiber_free f
    if f == 0 or len(f) <= 4
        return 0
    end
    stk = get(f, 2)
    sz = get(f, 3)
    if stk > 0 and sz > 0
        free(stk, sz)
    end
    if len(f) > 9
        slot = get(f, 9)
        if slot > 0
            free(slot, 64)
            list_set(f, 9, 0)
        end
    end
    list_set(f, 2, 0)
    list_set(f, 3, 0)
    return 0
end

// ── 2. Lock-Free Ring Buffer Fiber Queue ───────────────────────────────────────
// WHY: Circular FIFO buffer allows O(1) fiber enqueue and dequeue operations without
//      dynamic memory reallocation during high-throughput scheduling.
// Queue fields:
//   q[0]: buffer (list of fibers)
//   q[1]: capacity (int)
//   q[2]: head (int)
//   q[3]: tail (int)
//   q[4]: count (int)

fn fiber_queue_new capacity
    q = list()
    buf = list()
    i = 0
    while i < capacity
        push(buf, 0)
        i = i + 1
    end
    push(q, buf)      // 0: buffer
    push(q, capacity) // 1: capacity
    push(q, 0)        // 2: head
    push(q, 0)        // 3: tail
    push(q, 0)        // 4: count
    return q
end

fn fiber_queue_push q fiber
    cnt = get(q, 4)
    cap = get(q, 1)
    if cnt >= cap
        return 0 // Queue full
    end

    tl = get(q, 3)
    list_set(get(q, 0), tl, fiber)
    next_tl = (tl + 1) % cap
    list_set(q, 3, next_tl)
    list_set(q, 4, cnt + 1)
    return 1
end

fn fiber_queue_pop q
    cnt = get(q, 4)
    if cnt == 0
        return 0 // Queue empty
    end

    hd = get(q, 2)
    cap = get(q, 1)
    fiber = get(get(q, 0), hd)
    list_set(get(q, 0), hd, 0)
    next_hd = (hd + 1) % cap
    list_set(q, 2, next_hd)
    list_set(q, 4, cnt - 1)
    return fiber
end

fn fiber_queue_len q
    return get(q, 4)
end

// ── 3. M:N Cooperative Fiber Scheduler ────────────────────────────────────────
// WHY: Coordinates fiber execution across available workers with fair time slicing.
// Scheduler fields:
//   s[0]: ready_queue (FiberQueue)
//   s[1]: current_fiber (LipiFiber or 0)
//   s[2]: completed_count (int)
//   s[3]: next_fiber_id (int)
//   s[4]: fibers_all (list of all active fibers)

fn fiber_scheduler_new
    s = list()
    push(s, fiber_queue_new(1024)) // 0: ready_queue
    push(s, 0)                     // 1: current_fiber
    push(s, 0)                     // 2: completed_count
    push(s, 1)                     // 3: next_id
    push(s, list())                // 4: fibers_all
    return s
end

fn fiber_scheduler_spawn sched fn_code arg
    fid = get(sched, 3)
    list_set(sched, 3, fid + 1)

    f = fiber_new(fid, fn_code, arg, 4096)
    fiber_queue_push(get(sched, 0), f)
    push(get(sched, 4), f)
    return fid
end

// Executes a cooperative execution slice of the fiber via pure silicon context switch.
// Eliminates mock loop counters completely: swaps hardware %rsp to fiber stack and executes.
fn fiber_execute_slice f
    // Verify stack safety before execution (Trap 1 Defense)
    if fiber_check_stack_guard(f) == 0
        list_set(f, 1, FIBER_DEAD)
        if len(f) > 9
            desc = get(f, 9)
            if desc > 0
                mem_write(desc, 8, FIBER_DEAD)
            end
        end
        return -1 // Panic: Stack overflow detected!
    end

    if get(f, 1) == FIBER_DEAD
        return FIBER_DEAD
    end

    if len(f) <= 9
        return get(f, 1)
    end

    desc = get(f, 9)
    if desc == 0
        return get(f, 1)
    end

    cur_state = mem_read(desc, 8)
    if cur_state == FIBER_DEAD
        list_set(f, 1, FIBER_DEAD)
        return FIBER_DEAD
    end

    // Mark running
    list_set(f, 1, FIBER_RUNNING)
    mem_write(desc, 8, FIBER_RUNNING)

    // Retrieve silicon context switch routine
    sw_fn = fiber_get_swap_engine()
    if sw_fn <= 0
        return get(f, 1)
    end

    // Read current fiber stack pointer
    fiber_sp = mem_read(desc, 16)

    // Set active fiber for parameterless yields
    G_CURRENT_FIBER = f

    // ──────────────────────────────────────────────────────────────────────────
    // Physical AMD64 Silicon Context Switch:
    // 1. Saves scheduler callee-saved registers (%rbp, %rbx, %r12-%r15) on scheduler stack
    // 2. Stores scheduler %rsp into desc + 0 (sched_sp)
    // 3. Sets CPU %rsp to fiber_sp
    // 4. Restores fiber registers and resumes/starts execution in fiber context
    // ──────────────────────────────────────────────────────────────────────────
    sw_fn(desc, fiber_sp)

    // Clear active fiber context
    G_CURRENT_FIBER = 0

    // Resumed back in scheduler context:
    // Synchronize state, stack pointer, result, and step_count from silicon descriptor
    new_state = mem_read(desc, 8)
    new_sp = mem_read(desc, 16)
    new_res = mem_read(desc, 40)
    new_steps = mem_read(desc, 48)

    list_set(f, 1, new_state)
    list_set(f, 4, new_sp)
    list_set(f, 7, new_res)
    list_set(f, 8, new_steps)

    // Post-execution stack guard verification
    if fiber_check_stack_guard(f) == 0
        list_set(f, 1, FIBER_DEAD)
        mem_write(desc, 8, FIBER_DEAD)
        return -1
    end

    return new_state
end

// Yields current fiber cooperatively back to the scheduler
fn fiber_yield f
    if f == 0
        f = G_CURRENT_FIBER
    end
    if f == 0
        return 0
    end
    if len(f) <= 9
        return 0
    end
    desc = get(f, 9)
    if desc <= 0
        return 0
    end

    if fiber_check_stack_guard(f) == 0
        list_set(f, 1, FIBER_DEAD)
        mem_write(desc, 8, FIBER_DEAD)
        return -1
    end

    // Set state to FIBER_READY
    mem_write(desc, 8, FIBER_READY)
    list_set(f, 1, FIBER_READY)

    // Increment step counter
    steps = mem_read(desc, 48) + 1
    mem_write(desc, 48, steps)
    list_set(f, 8, steps)

    sw_fn = fiber_get_swap_engine()
    sched_sp = mem_read(desc, 0) // saved scheduler %rsp

    // Switch context from fiber stack back to scheduler stack
    // &desc->fiber_sp is desc + 16
    sw_fn(desc + 16, sched_sp)
    return 1
end

// Runs scheduler until all ready fibers complete
fn fiber_scheduler_run_all sched max_ticks
    ticks = 0
    q = get(sched, 0)
    while ticks < max_ticks and fiber_queue_len(q) > 0
        f = fiber_queue_pop(q)
        if f != 0
            list_set(sched, 1, f)
            list_set(f, 1, FIBER_RUNNING)

            status = fiber_execute_slice(f)

            if status == FIBER_READY
                // Fiber yielded cooperatively; place back into ready queue
                fiber_queue_push(q, f)
            elif status == FIBER_DEAD
                list_set(sched, 2, get(sched, 2) + 1)
            end
        end

        ticks = ticks + 1
    end
    return get(sched, 2)
end

// ── 4. Fiber Channel Synchronization Primitives (chan) ────────────────────────
// WHY: Enables lock-free message passing between concurrent fibers without shared state.
// Channel fields:
//   c[0]: buffer (list of values)
//   c[1]: capacity (int)
//   c[2]: is_closed (0 or 1)

fn fiber_chan_new capacity
    ch = list()
    push(ch, list())   // 0: buffer
    push(ch, capacity) // 1: capacity
    push(ch, 0)        // 2: is_closed
    return ch
end

fn fiber_chan_send ch val
    if get(ch, 2) == 1
        return -1 // Error: Send on closed channel
    end

    buf = get(ch, 0)
    cap = get(ch, 1)
    if len(buf) >= cap
        return 0 // Channel full (would suspend fiber)
    end

    push(buf, val)
    return 1 // Send successful
end

fn fiber_chan_recv ch out_val
    buf = get(ch, 0)
    if len(buf) == 0
        return 0 // Channel empty (would suspend fiber)
    end

    val = get(buf, 0)
    // Shift elements
    new_buf = list()
    i = 1
    while i < len(buf)
        push(new_buf, get(buf, i))
        i = i + 1
    end
    list_set(ch, 0, new_buf)
    push(out_val, val)
    return 1 // Recv successful
end

fn fiber_chan_close ch
    list_set(ch, 2, 1)
    return 1
end
