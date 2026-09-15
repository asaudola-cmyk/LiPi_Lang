// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — SYSTEM V AMD64 CALLING CONVENTION (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/x86_64/calling_conv.lp
//
// WHY THIS MODULE:
// 1. System V AMD64 ABI defines the binary contract between callers and callees on
//    Linux, BSD, and macOS systems running on x86-64 silicon.
// 2. Register argument allocation:
//    - The first 6 integer/pointer parameters are passed in specific hardware registers:
//      [0: %rdi, 1: %rsi, 2: %rdx, 3: %rcx, 4: %r8, 5: %r9].
//    - Any arguments beyond 6 are pushed onto the caller's stack frame in right-to-left
//      order, accessible via positive offsets from RBP ([%rbp + 16], [%rbp + 24], ...).
// 3. Linux Kernel Syscall ABI Divergence:
//    - In kernel space, the SYSCALL instruction destroys %rcx (saving %rip) and %r11
//      (saving %rflags).
//    - Therefore, Linux kernel syscalls replace %rcx with %r10 for the 4th argument!
// 4. Return Value Register:
//    - Primary scalar return values are delivered in %rax.
//    - 128-bit wide composite returns deliver lower 64-bits in %rax and upper in %rdx.
// ==============================================================================

// ── 1. ABI Function Parameter Registers ───────────────────────────────────────

fn x86_abi_arg_register idx
    // WHY: Maps zero-based parameter index to hardware System V register ID.
    //      Returns -1 if argument must be passed on the stack.
    if idx == 0 return 7   // RDI
    if idx == 1 return 6   // RSI
    if idx == 2 return 2   // RDX
    if idx == 3 return 1   // RCX
    if idx == 4 return 8   // R8
    if idx == 5 return 9   // R9
    return 0 - 1

fn x86_abi_syscall_arg_register idx
    // WHY: Linux kernel syscall convention differs from userland System V at index 3:
    //      %rcx is clobbered by CPU hardware during the SYSCALL instruction to store RIP;
    //      the kernel therefore expects argument 4 in %r10 instead of %rcx.
    if idx == 0 return 7   // RDI
    if idx == 1 return 6   // RSI
    if idx == 2 return 2   // RDX
    if idx == 3 return 10  // R10 (Kernel replaces RCX)
    if idx == 4 return 8   // R8
    if idx == 5 return 9   // R9
    return 0 - 1

fn x86_abi_is_arg_in_reg idx
    // WHY: Returns 1 if argument index fits in the 6 register parameter slots.
    if idx >= 0 and idx < 6
        return 1
    return 0

// ── 2. Stack Parameter Accessors ──────────────────────────────────────────────

fn x86_abi_stack_arg_offset idx
    // WHY: Arguments 6 and above are placed on the stack by the caller before CALL.
    //      Stack geometry immediately after prologue (PUSH RBP; MOV RBP, RSP):
    //      [RBP + 0]  = Saved old RBP
    //      [RBP + 8]  = 8-byte Return address pushed by CALL instruction
    //      [RBP + 16] = 7th parameter (index 6)
    //      [RBP + 24] = 8th parameter (index 7)
    if idx < 6
        return 0 // Argument is in a physical register, not on the stack
    stack_index = idx - 6
    return 16 + (stack_index * 8)

// ── 3. Return Value Register Identifiers ──────────────────────────────────────

fn x86_abi_return_register
    // WHY: System V AMD64 delivers primary 64-bit integer return values in RAX (0).
    return 0

fn x86_abi_secondary_return_register
    // WHY: Upper 64 bits of 128-bit return values are delivered in RDX (2).
    return 2

// ── 4. Callee-Saved Register Preservation Rules ───────────────────────────────

fn x86_abi_is_preserved reg_id
    // WHY: A function must preserve RBX(3), R12(12), R13(13), R14(14), R15(15),
    //      and RBP(5). Returns 1 if register must be restored before RET.
    if reg_id == 3 or reg_id == 5 or reg_id == 12 or reg_id == 13 or reg_id == 14 or reg_id == 15
        return 1
    return 0

// ── 5. Verification Self-Test ────────────────────────────────────────────────

fn test_x86_calling_conv_subsystem
    // Verify first 6 userland registers
    if x86_abi_arg_register(0) != 7 or x86_abi_arg_register(1) != 6
        say "FAIL: Arg 0/1 register mismatch"
        return 0

    if x86_abi_arg_register(3) != 1
        say "FAIL: Arg 3 must be RCX (1) in userland"
        return 0

    // Verify Linux syscall override: arg 3 must be R10 (10)
    if x86_abi_syscall_arg_register(3) != 10
        say "FAIL: Syscall arg 3 must be R10 (10)"
        return 0

    // Verify stack offset for 7th argument (index 6) -> RBP + 16
    if x86_abi_stack_arg_offset(6) != 16
        say "FAIL: 7th argument expected at offset 16"
        return 0

    // Verify stack offset for 8th argument (index 7) -> RBP + 24
    if x86_abi_stack_arg_offset(7) != 24
        say "FAIL: 8th argument expected at offset 24"
        return 0

    // Verify return register is RAX (0)
    if x86_abi_return_register() != 0
        say "FAIL: Return register must be RAX (0)"
        return 0

    return 1

test_x86_calling_conv_subsystem()
