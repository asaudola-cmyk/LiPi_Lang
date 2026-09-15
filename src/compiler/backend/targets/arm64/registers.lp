// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — AARCH64 (ARM64) REGISTERS (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/arm64/registers.lp
//
// WHY THIS MODULE:
// 1. The 64-bit ARM architecture (AArch64 / ARMv8-A+) features a clean orthogonal
//    register file consisting of 31 64-bit general-purpose registers (X0..X30)
//    and special register index 31 representing XZR (Zero Register) or SP (Stack Pointer).
// 2. Dual Semantics of Register 31:
//    - When encoded in memory base addresses or SP-modifying instructions: 31 represents SP.
//    - When encoded in arithmetic or logical instructions: 31 represents XZR (hardware zero).
// 3. Register Roles & ABI Responsibilities (AAPCS64):
//    - X0..X7: Parameter passing (args 0..7) and return value (X0 / X1). Caller-saved.
//    - X8: Syscall number register on Linux AArch64 (svc 0), or indirect result pointer.
//    - X9..X15: Scratch temporaries. Caller-saved.
//    - X16, X17: IP0, IP1 intra-procedure call scratch registers.
//    - X18: Platform register (reserved on Linux / iOS / macOS).
//    - X19..X28: Callee-saved registers (must be saved/restored across calls).
//    - X29: Frame Pointer (FP) used for stack unwinding.
//    - X30: Link Register (LR) holding subroutine return address written by BL.
// ==============================================================================

// ── 1. Register Identifiers ───────────────────────────────────────────────────

ARM64_REG_X0  = 0   // Argument 1 / Return value
ARM64_REG_X1  = 1   // Argument 2 / Secondary return
ARM64_REG_X2  = 2   // Argument 3
ARM64_REG_X3  = 3   // Argument 4
ARM64_REG_X4  = 4   // Argument 5
ARM64_REG_X5  = 5   // Argument 6
ARM64_REG_X6  = 6   // Argument 7
ARM64_REG_X7  = 7   // Argument 8
ARM64_REG_X8  = 8   // Linux Syscall Number / Indirect result
ARM64_REG_X9  = 9   // Scratch temporary
ARM64_REG_X10 = 10
ARM64_REG_X11 = 11
ARM64_REG_X12 = 12
ARM64_REG_X13 = 13
ARM64_REG_X14 = 14
ARM64_REG_X15 = 15
ARM64_REG_X16 = 16  // IP0 Intra-procedure temporary
ARM64_REG_X17 = 17  // IP1 Intra-procedure temporary
ARM64_REG_X18 = 18  // Platform register (reserved by OS)
ARM64_REG_X19 = 19  // Callee-saved
ARM64_REG_X20 = 20  // Callee-saved
ARM64_REG_X21 = 21  // Callee-saved
ARM64_REG_X22 = 22  // Callee-saved
ARM64_REG_X23 = 23  // Callee-saved
ARM64_REG_X24 = 24  // Callee-saved
ARM64_REG_X25 = 25  // Callee-saved
ARM64_REG_X26 = 26  // Callee-saved
ARM64_REG_X27 = 27  // Callee-saved
ARM64_REG_X28 = 28  // Callee-saved
ARM64_REG_X29 = 29  // Frame Pointer (FP)
ARM64_REG_X30 = 30  // Link Register (LR)
ARM64_REG_XZR = 31  // Zero Register
ARM64_REG_SP  = 31  // Stack Pointer (context dependent)

// ── 2. Register Classification Queries ────────────────────────────────────────

fn arm64_is_callee_saved reg_id
    // WHY: Registers X19 through X28, plus X29 (FP) and X30 (LR) must be preserved
    //      across function calls by the callee subroutine.
    if reg_id >= 19 and reg_id <= 30
        return 1
    return 0

fn arm64_is_caller_saved reg_id
    // WHY: Scratch registers X0..X17 may be freely overwritten during a procedure call.
    if reg_id >= 0 and reg_id <= 17
        return 1
    return 0

fn arm64_is_argument_reg reg_id
    // WHY: First 8 parameters pass in X0 through X7.
    if reg_id >= 0 and reg_id <= 7
        return 1
    return 0

// ── 3. Register Name Formatting & Lookup ──────────────────────────────────────

fn arm64_reg_name_64 reg_id
    // WHY: Returns canonical 64-bit register name (x0..x30, xzr, sp).
    if reg_id >= 0 and reg_id <= 30
        return "x" + str(reg_id)
    if reg_id == 31
        return "xzr"
    return "invalid"

fn arm64_reg_name_32 reg_id
    // WHY: Returns 32-bit register name (w0..w30, wzr, wsp).
    if reg_id >= 0 and reg_id <= 30
        return "w" + str(reg_id)
    if reg_id == 31
        return "wzr"
    return "invalid"

fn arm64_reg_from_name name
    // WHY: Resolves register identifier from assembly token.
    if name == "xzr" or name == "wzr" return 31
    if name == "sp"  or name == "wsp" return 31
    if name == "fp"  return 29
    if name == "lr"  return 30

    // Match x0..x30
    i = 0
    while i <= 30
        if name == ("x" + str(i)) or name == ("w" + str(i))
            return i
        i = i + 1
    return 0 - 1

// ── 4. Allocator Register Pools ───────────────────────────────────────────────

fn arm64_get_scratch_registers
    // WHY: Scratch register allocation sequence (X9..X15, then X0..X7).
    regs = list()
    push(regs, 9)
    push(regs, 10)
    push(regs, 11)
    push(regs, 12)
    push(regs, 13)
    push(regs, 14)
    push(regs, 15)
    push(regs, 0)
    push(regs, 1)
    push(regs, 2)
    push(regs, 3)
    push(regs, 4)
    push(regs, 5)
    push(regs, 6)
    push(regs, 7)
    return regs

fn arm64_get_callee_saved_registers
    // WHY: Callee-saved pool (X19 through X28).
    regs = list()
    i = 19
    while i <= 28
        push(regs, i)
        i = i + 1
    return regs

// ── 5. Verification Self-Test ────────────────────────────────────────────────

fn test_arm64_registers_subsystem
    if arm64_is_callee_saved(ARM64_REG_X19) != 1 or arm64_is_callee_saved(ARM64_REG_X28) != 1
        say "FAIL: Callee-saved checks for X19-X28 failed"
        return 0

    if arm64_is_caller_saved(ARM64_REG_X0) != 1 or arm64_is_caller_saved(ARM64_REG_X9) != 1
        say "FAIL: Caller-saved checks failed"
        return 0

    if arm64_is_argument_reg(7) != 1 or arm64_is_argument_reg(8) != 0
        say "FAIL: Argument register checks failed"
        return 0

    if arm64_reg_from_name("x29") != 29 or arm64_reg_from_name("lr") != 30
        say "FAIL: Name resolution for x29/lr failed"
        return 0

    return 1

test_arm64_registers_subsystem()
