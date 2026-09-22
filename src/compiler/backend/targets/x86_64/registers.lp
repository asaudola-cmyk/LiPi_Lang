// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — AMD64 HARDWARE REGISTERS (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/x86_64/registers.lp
//
// WHY THIS MODULE:
// 1. The AMD64 (x86-64) architecture provides 16 64-bit general-purpose registers
//    (RAX through R15).
// 2. Hardware instruction encoding in x86-64 allocates 3 bits for register identifiers
//    in the ModR/M and SIB bytes. Therefore, registers 0-7 (RAX..RDI) fit into standard
//    opcodes, whereas registers 8-15 (R8..R15) strictly require the 1-bit extension
//    in the REX prefix (REX.R, REX.X, or REX.B).
// 3. Register classification dictates compiler calling conventions:
//    - Scratch / Caller-saved registers: May be overwritten by any function call.
//    - Callee-saved registers: Must be preserved and restored across function calls.
//    - Stack / Frame pointers: Hardware-dedicated for stack frame management.
// ==============================================================================

// ── 1. AMD64 Hardware Register Numbers ────────────────────────────────────────

X86_REG_RAX = 0   // Accumulator / Syscall number / 1st return value
X86_REG_RCX = 1   // Counter / 4th user call argument
X86_REG_RDX = 2   // Data / 3rd user call argument / 2nd return value
X86_REG_RBX = 3   // Base / Callee-saved
X86_REG_RSP = 4   // Stack Pointer (reserved hardware pointer)
X86_REG_RBP = 5   // Base Frame Pointer (reserved frame pointer)
X86_REG_RSI = 6   // Source Index / 2nd user call argument
X86_REG_RDI = 7   // Destination Index / 1st user call argument
X86_REG_R8  = 8   // Extended Register 8 / 5th user call argument
X86_REG_R9  = 9   // Extended Register 9 / 6th user call argument
X86_REG_R10 = 10  // Extended Register 10 / 4th Linux syscall argument (replaces RCX)
X86_REG_R11 = 11  // Extended Register 11 / Scratch (clobbered by SYSCALL)
X86_REG_R12 = 12  // Extended Register 12 / Callee-saved
X86_REG_R13 = 13  // Extended Register 13 / Callee-saved
X86_REG_R14 = 14  // Extended Register 14 / Callee-saved
X86_REG_R15 = 15  // Extended Register 15 / Callee-saved

// ── 2. Register Classification Queries ────────────────────────────────────────

fn x86_is_caller_saved reg_id
    // WHY: Scratch registers clobbered by standard System V procedure calls.
    //      RAX(0), RCX(1), RDX(2), RSI(6), RDI(7), R8(8), R9(9), R10(10), R11(11).
    if reg_id == 0 or reg_id == 1 or reg_id == 2 or reg_id == 6 or reg_id == 7
        return 1
    if reg_id == 8 or reg_id == 9 or reg_id == 10 or reg_id == 11
        return 1
    return 0

fn x86_is_callee_saved reg_id
    // WHY: Registers that must maintain their values across calls.
    //      RBX(3), R12(12), R13(13), R14(14), R15(15). (RBP and RSP also preserved).
    if reg_id == 3 or reg_id == 12 or reg_id == 13 or reg_id == 14 or reg_id == 15
        return 1
    return 0

fn x86_is_reserved reg_id
    // WHY: RSP (stack pointer, 4) and RBP (frame pointer, 5) are dedicated
    //      to managing stack frames and cannot be assigned by general regalloc.
    if reg_id == 4 or reg_id == 5
        return 1
    return 0

fn x86_needs_rex_bit reg_id
    // WHY: Registers 8 through 15 require an extension bit in the REX prefix byte
    //      because the standard ModR/M byte only holds 3-bit register IDs (0..7).
    if reg_id >= 8 and reg_id <= 15
        return 1
    return 0

// ── 3. Register Name Formatting & Disassembly ─────────────────────────────────

fn x86_reg_name_64 reg_id
    // WHY: Full 64-bit quadword register name for assembly and debugging.
    if reg_id == 0  return "rax"
    if reg_id == 1  return "rcx"
    if reg_id == 2  return "rdx"
    if reg_id == 3  return "rbx"
    if reg_id == 4  return "rsp"
    if reg_id == 5  return "rbp"
    if reg_id == 6  return "rsi"
    if reg_id == 7  return "rdi"
    if reg_id == 8  return "r8"
    if reg_id == 9  return "r9"
    if reg_id == 10 return "r10"
    if reg_id == 11 return "r11"
    if reg_id == 12 return "r12"
    if reg_id == 13 return "r13"
    if reg_id == 14 return "r14"
    if reg_id == 15 return "r15"
    return "invalid"

fn x86_reg_name_32 reg_id
    // WHY: 32-bit doubleword register names (writes zero-extend to 64 bits).
    if reg_id == 0  return "eax"
    if reg_id == 1  return "ecx"
    if reg_id == 2  return "edx"
    if reg_id == 3  return "ebx"
    if reg_id == 4  return "esp"
    if reg_id == 5  return "ebp"
    if reg_id == 6  return "esi"
    if reg_id == 7  return "edi"
    if reg_id == 8  return "r8d"
    if reg_id == 9  return "r9d"
    if reg_id == 10 return "r10d"
    if reg_id == 11 return "r11d"
    if reg_id == 12 return "r12d"
    if reg_id == 13 return "r13d"
    if reg_id == 14 return "r14d"
    if reg_id == 15 return "r15d"
    return "invalid"

fn x86_reg_from_name name
    // WHY: Parses string register names back to numeric IDs.
    if name == "rax" or name == "eax" return 0
    if name == "rcx" or name == "ecx" return 1
    if name == "rdx" or name == "edx" return 2
    if name == "rbx" or name == "ebx" return 3
    if name == "rsp" or name == "esp" return 4
    if name == "rbp" or name == "ebp" return 5
    if name == "rsi" or name == "esi" return 6
    if name == "rdi" or name == "edi" return 7
    if name == "r8"  or name == "r8d" return 8
    if name == "r9"  or name == "r9d" return 9
    if name == "r10" or name == "r10d" return 10
    if name == "r11" or name == "r11d" return 11
    if name == "r12" or name == "r12d" return 12
    if name == "r13" or name == "r13d" return 13
    if name == "r14" or name == "r14d" return 14
    if name == "r15" or name == "r15d" return 15
    return 0 - 1

// ── 4. Allocator Register Pools ───────────────────────────────────────────────

fn x86_get_scratch_registers
    // WHY: Caller-saved registers in preferred allocation order.
    //      Uses R10, R11, RDI, RSI, RDX, RCX, R8, R9.
    regs = list()
    push(regs, 10)
    push(regs, 11)
    push(regs, 7)
    push(regs, 6)
    push(regs, 2)
    push(regs, 1)
    push(regs, 8)
    push(regs, 9)
    return regs

fn x86_get_callee_saved_registers
    // WHY: Preserved registers in preferred allocation order.
    //      Uses RBX, R12, R13, R14, R15.
    regs = list()
    push(regs, 3)
    push(regs, 12)
    push(regs, 13)
    push(regs, 14)
    push(regs, 15)
    return regs

// ── 5. Verification Self-Test ────────────────────────────────────────────────

fn test_x86_registers_subsystem
    if x86_needs_rex_bit(X86_REG_R12) != 1
        say "FAIL: R12 expected to need REX bit"
        return 0

    if x86_needs_rex_bit(X86_REG_RAX) != 0
        say "FAIL: RAX should not need REX bit"
        return 0

    if x86_is_callee_saved(X86_REG_RBX) != 1
        say "FAIL: RBX must be callee-saved"
        return 0

    if x86_is_caller_saved(X86_REG_RDI) != 1
        say "FAIL: RDI must be caller-saved"
        return 0

    if x86_reg_from_name("r14") != 14
        say "FAIL: r14 name resolution failed"
        return 0

    return 1

// test_x86_registers_subsystem()
