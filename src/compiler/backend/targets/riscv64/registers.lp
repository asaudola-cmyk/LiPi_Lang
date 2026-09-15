// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — RISC-V 64-BIT (RV64) REGISTERS (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/riscv64/registers.lp
//
// WHY THIS MODULE:
// 1. The RISC-V architecture (RV64I / RV64GC) specifies 32 64-bit integer registers
//    (x0 through x31).
// 2. Silicon Hardwired Constant:
//    - Register x0 is physically hardwired to zero in the silicon CPU core.
//    - Reads from x0 always yield 0; writes to x0 are discarded with zero side-effects.
// 3. Standard LP64 ABI Register Classification:
//    - x1 (ra): Return address written by JAL/JALR instructions. Caller-saved.
//    - x2 (sp): Stack pointer (must maintain 16-byte alignment). Callee-saved.
//    - x3 (gp) & x4 (tp): Dedicated global and thread pointers.
//    - x5..x7 (t0..t2) & x28..x31 (t3..t6): Scratch temporaries. Caller-saved.
//    - x8 (s0/fp) & x9 (s1) & x18..x27 (s2..s11): Preserved registers. Callee-saved.
//    - x10..x17 (a0..a7): Function arguments 1-8. Return values in a0 (and a1).
//    - x17 (a7): Linux RISC-V ECALL syscall number register.
// ==============================================================================

// ── 1. Register Numbers ───────────────────────────────────────────────────────

RV64_REG_ZERO = 0   // Hardwired zero
RV64_REG_RA   = 1   // Return address
RV64_REG_SP   = 2   // Stack pointer
RV64_REG_GP   = 3   // Global pointer
RV64_REG_TP   = 4   // Thread pointer
RV64_REG_T0   = 5   // Temporary 0
RV64_REG_T1   = 6   // Temporary 1
RV64_REG_T2   = 7   // Temporary 2
RV64_REG_S0   = 8   // Saved 0 / Frame pointer (fp)
RV64_REG_FP   = 8   // Frame pointer alias
RV64_REG_S1   = 9   // Saved 1
RV64_REG_A0   = 10  // Function arg 1 / Return value 1
RV64_REG_A1   = 11  // Function arg 2 / Return value 2
RV64_REG_A2   = 12  // Function arg 3
RV64_REG_A3   = 13  // Function arg 4
RV64_REG_A4   = 14  // Function arg 5
RV64_REG_A5   = 15  // Function arg 6
RV64_REG_A6   = 16  // Function arg 7
RV64_REG_A7   = 17  // Function arg 8 / Linux ECALL syscall number
RV64_REG_S2   = 18  // Saved 2
RV64_REG_S3   = 19  // Saved 3
RV64_REG_S4   = 20  // Saved 4
RV64_REG_S5   = 21  // Saved 5
RV64_REG_S6   = 22  // Saved 6
RV64_REG_S7   = 23  // Saved 7
RV64_REG_S8   = 24  // Saved 8
RV64_REG_S9   = 25  // Saved 9
RV64_REG_S10  = 26  // Saved 10
RV64_REG_S11  = 27  // Saved 11
RV64_REG_T3   = 28  // Temporary 3
RV64_REG_T4   = 29  // Temporary 4
RV64_REG_T5   = 30  // Temporary 5
RV64_REG_T6   = 31  // Temporary 6

// ── 2. Register Classification Queries ────────────────────────────────────────

fn rv64_is_callee_saved reg_id
    // WHY: In LP64, callee-saved registers are:
    //      sp(2), s0/fp(8), s1(9), and s2..s11 (18..27).
    if reg_id == 2 or reg_id == 8 or reg_id == 9
        return 1
    if reg_id >= 18 and reg_id <= 27
        return 1
    return 0

fn rv64_is_caller_saved reg_id
    // WHY: Scratch registers: ra(1), t0..t2 (5..7), a0..a7 (10..17), t3..t6 (28..31).
    if reg_id == 1
        return 1
    if reg_id >= 5 and reg_id <= 7
        return 1
    if reg_id >= 10 and reg_id <= 17
        return 1
    if reg_id >= 28 and reg_id <= 31
        return 1
    return 0

fn rv64_is_arg_reg reg_id
    // WHY: Arguments pass in a0..a7 (x10..x17).
    if reg_id >= 10 and reg_id <= 17
        return 1
    return 0

// ── 3. ABI Name Formatting & Resolution ───────────────────────────────────────

fn rv64_reg_abi_name reg_id
    // WHY: Converts numeric register index to standard RISC-V ABI mnemonic.
    if reg_id == 0  return "zero"
    if reg_id == 1  return "ra"
    if reg_id == 2  return "sp"
    if reg_id == 3  return "gp"
    if reg_id == 4  return "tp"
    if reg_id == 5  return "t0"
    if reg_id == 6  return "t1"
    if reg_id == 7  return "t2"
    if reg_id == 8  return "s0"
    if reg_id == 9  return "s1"
    if reg_id == 10 return "a0"
    if reg_id == 11 return "a1"
    if reg_id == 12 return "a2"
    if reg_id == 13 return "a3"
    if reg_id == 14 return "a4"
    if reg_id == 15 return "a5"
    if reg_id == 16 return "a6"
    if reg_id == 17 return "a7"
    if reg_id == 18 return "s2"
    if reg_id == 19 return "s3"
    if reg_id == 20 return "s4"
    if reg_id == 21 return "s5"
    if reg_id == 22 return "s6"
    if reg_id == 23 return "s7"
    if reg_id == 24 return "s8"
    if reg_id == 25 return "s9"
    if reg_id == 26 return "s10"
    if reg_id == 27 return "s11"
    if reg_id == 28 return "t3"
    if reg_id == 29 return "t4"
    if reg_id == 30 return "t5"
    if reg_id == 31 return "t6"
    return "invalid"

fn rv64_reg_from_abi_name name
    // WHY: Resolves register ID from string name.
    if name == "zero" return 0
    if name == "ra"   return 1
    if name == "sp"   return 2
    if name == "gp"   return 3
    if name == "tp"   return 4
    if name == "t0"   return 5
    if name == "t1"   return 6
    if name == "t2"   return 7
    if name == "s0" or name == "fp" return 8
    if name == "s1"   return 9
    if name == "a0"   return 10
    if name == "a1"   return 11
    if name == "a2"   return 12
    if name == "a3"   return 13
    if name == "a4"   return 14
    if name == "a5"   return 15
    if name == "a6"   return 16
    if name == "a7"   return 17
    if name == "s2"   return 18
    if name == "s3"   return 19
    if name == "s4"   return 20
    if name == "s5"   return 21
    if name == "s6"   return 22
    if name == "s7"   return 23
    if name == "s8"   return 24
    if name == "s9"   return 25
    if name == "s10"  return 26
    if name == "s11"  return 27
    if name == "t3"   return 28
    if name == "t4"   return 29
    if name == "t5"   return 30
    if name == "t6"   return 31
    return 0 - 1

// ── 4. Allocator Register Pools ───────────────────────────────────────────────

fn rv64_get_scratch_registers
    // WHY: Preferred caller-saved registers for leaf allocations.
    //      Uses t0..t2, a0..a7, t3..t6.
    regs = list()
    push(regs, 5)
    push(regs, 6)
    push(regs, 7)
    push(regs, 28)
    push(regs, 29)
    push(regs, 30)
    push(regs, 31)
    push(regs, 10)
    push(regs, 11)
    push(regs, 12)
    push(regs, 13)
    push(regs, 14)
    push(regs, 15)
    push(regs, 16)
    push(regs, 17)
    return regs

fn rv64_get_callee_saved_registers
    // WHY: Preserved registers across calls: s1..s11. (s0 reserved as FP).
    regs = list()
    push(regs, 9) // s1
    i = 18
    while i <= 27
        push(regs, i) // s2..s11
        i = i + 1
    return regs

// ── 5. Verification Self-Test ────────────────────────────────────────────────

fn test_rv64_registers_subsystem
    // Verify x0 is hardwired zero
    if RV64_REG_ZERO != 0 or rv64_reg_abi_name(0) != "zero"
        say "FAIL: x0 zero register invalid"
        return 0

    // Verify FP is x8 / s0
    if RV64_REG_FP != 8 or rv64_reg_from_abi_name("fp") != 8 or rv64_reg_from_abi_name("s0") != 8
        say "FAIL: FP / s0 mapping invalid"
        return 0

    // Verify callee-saved checks
    if rv64_is_callee_saved(8) != 1 or rv64_is_callee_saved(18) != 1 or rv64_is_callee_saved(10) != 0
        say "FAIL: Callee-saved checks failed"
        return 0

    // Verify caller-saved checks
    if rv64_is_caller_saved(10) != 1 or rv64_is_caller_saved(5) != 1 or rv64_is_caller_saved(8) != 0
        say "FAIL: Caller-saved checks failed"
        return 0

    return 1

// test_rv64_registers_subsystem()
