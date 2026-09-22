// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — AAPCS64 CALLING CONVENTION (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/arm64/calling_conv.lp
//
// WHY THIS MODULE:
// 1. AAPCS64 (ARM 64-bit Architecture Procedure Call Standard) establishes the
//    binary calling convention for Linux and bare-metal AArch64 targets.
// 2. Register Parameters:
//    - The first 8 arguments pass in X0 through X7.
//    - Arguments beyond 8 spill to the caller's stack frame.
// 3. Return Values:
//    - Primary scalar return value is delivered in X0.
//    - 128-bit composite return values utilize X0 (low 64-bits) and X1 (high 64-bits).
// 4. Linux Kernel Syscall ABI:
//    - Syscall number is passed in X8.
//    - Arguments 1-6 are passed in X0 through X5.
//    - Syscall trap is executed using "SVC #0" (0xD4000001).
// 5. Stack Alignment & Frame Record:
//    - SP must be 16-byte aligned at all times when dereferenced.
//    - AAPCS64 specifies a 16-byte Frame Record consisting of [FP (X29), LR (X30)]
//      saved at the bottom of the stack frame (STP X29, X30, [SP, #-16]!).
// ==============================================================================

// ── 1. Parameter Passing Registers ────────────────────────────────────────────

fn arm64_abi_arg_register idx
    // WHY: Maps parameter index 0..7 to hardware registers X0..X7.
    //      Returns -1 if argument must be passed on the stack.
    if idx >= 0 and idx <= 7
        return idx
    return 0 - 1

fn arm64_abi_is_arg_in_reg idx
    // WHY: Returns 1 if parameter index is passed in a hardware register.
    if idx >= 0 and idx <= 7
        return 1
    return 0

fn arm64_abi_stack_arg_offset idx
    // WHY: Arguments 8 and beyond are placed on the stack by caller.
    //      In AAPCS64, stack parameters are positioned above the caller's frame.
    if idx < 8
        return 0
    stack_idx = idx - 8
    return stack_idx * 8

// ── 2. Return Value & Syscall Registers ───────────────────────────────────────

fn arm64_abi_return_register
    // WHY: Scalar 64-bit return values are delivered in X0.
    return 0

fn arm64_abi_secondary_return_register
    // WHY: Secondary 64-bit return values (or 128-bit high half) are in X1.
    return 1

fn arm64_abi_syscall_num_register
    // WHY: Linux AArch64 syscall number register is X8.
    return 8

// ── 3. Callee-Saved Register Preservation Rules ───────────────────────────────

fn arm64_abi_is_preserved reg_id
    // WHY: X19 through X28, plus X29 (FP) and X30 (LR) must be preserved.
    if reg_id >= 19 and reg_id <= 30
        return 1
    return 0

fn arm64_abi_callee_saved_list
    // WHY: Returns standard callee-saved registers X19..X28.
    res = list()
    i = 19
    while i <= 28
        push(res, i)
        i = i + 1
    return res

// ── 4. Verification Self-Test ────────────────────────────────────────────────

fn test_arm64_calling_conv_subsystem
    // Verify 8 register parameters (X0..X7)
    i = 0
    while i < 8
        if arm64_abi_arg_register(i) != i or arm64_abi_is_arg_in_reg(i) != 1
            say "FAIL: Arg " + str(i) + " register check failed"
            return 0
        i = i + 1

    // Verify 9th parameter (idx 8) is on stack at offset 0
    if arm64_abi_arg_register(8) != (0 - 1) or arm64_abi_stack_arg_offset(8) != 0
        say "FAIL: 9th parameter stack offset failed"
        return 0

    // Verify 10th parameter (idx 9) is on stack at offset 8
    if arm64_abi_stack_arg_offset(9) != 8
        say "FAIL: 10th parameter stack offset failed"
        return 0

    // Verify Linux Syscall register is X8
    if arm64_abi_syscall_num_register() != 8
        say "FAIL: Syscall register must be X8"
        return 0

    return 1

// test_arm64_calling_conv_subsystem()
