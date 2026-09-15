// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — AMD64 RAW BINARY OPCODE TABLE (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/x86_64/opcode_table.lp
//
// WHY THIS MODULE:
// 1. In a sovereign compiler with zero external toolchain dependencies (no GCC,
//    no LLVM, no GNU Assembler / as), all CPU instructions must be synthesized
//    as exact raw byte sequences.
// 2. This module catalogues the canonical AMD64 machine code opcodes:
//    - Data transfer: MOV (r/m<-r, r<-r/m, r<-imm64, r/m<-imm32)
//    - Arithmetic: ADD, SUB (r/m<-r, r<-r/m, imm8, imm32)
//    - Comparison: CMP, TEST
//    - Control flow: JMP (rel8, rel32, indirect), CALL (rel32, indirect), RET
//    - Conditional branches: JCC short (rel8) and JCC near (rel32)
//    - Stack operations: PUSH, POP
//    - System & Control: SYSCALL, NOP, LEA
// ==============================================================================

// ── 1. Data Movement Opcodes ──────────────────────────────────────────────────

OP_MOV_RM_R      = 137  // 0x89: MOV r/m64, r64 (store reg into r/m)
OP_MOV_R_RM      = 139  // 0x8B: MOV r64, r/m64 (load r/m into reg)
OP_MOV_R_IMM_BASE= 184  // 0xB8: MOV r64, imm64 (+ reg 0..7)
OP_MOV_RM_IMM32  = 199  // 0xC7: MOV r/m64, imm32 (ModR/M /0)

// ── 2. Arithmetic & Logic Opcodes ─────────────────────────────────────────────

OP_ADD_RM_R      = 1    // 0x01: ADD r/m64, r64
OP_ADD_R_RM      = 3    // 0x03: ADD r64, r/m64
OP_ADD_IMM_GROUP = 129  // 0x81: ADD r/m64, imm32 (ModR/M /0)
OP_ADD_IMM8_GROUP= 131  // 0x83: ADD r/m64, imm8  (ModR/M /0)

OP_SUB_RM_R      = 41   // 0x29: SUB r/m64, r64
OP_SUB_R_RM      = 43   // 0x2B: SUB r64, r/m64
OP_SUB_IMM_GROUP = 129  // 0x81: SUB r/m64, imm32 (ModR/M /5)
OP_SUB_IMM8_GROUP= 131  // 0x83: SUB r/m64, imm8  (ModR/M /5)

OP_CMP_RM_R      = 57   // 0x39: CMP r/m64, r64
OP_CMP_R_RM      = 59   // 0x3B: CMP r64, r/m64
OP_CMP_IMM_GROUP = 129  // 0x81: CMP r/m64, imm32 (ModR/M /7)
OP_CMP_IMM8_GROUP= 131  // 0x83: CMP r/m64, imm8  (ModR/M /7)

OP_TEST_RM_R     = 133  // 0x85: TEST r/m64, r64
OP_LEA           = 141  // 0x8D: LEA r64, m

// ── 3. Branching, Call, & Return Opcodes ──────────────────────────────────────

OP_JMP_REL8      = 235  // 0xEB: JMP rel8 (short unconditional jump)
OP_JMP_REL32     = 233  // 0xE9: JMP rel32 (near unconditional jump)
OP_JMP_INDIRECT  = 255  // 0xFF: JMP r/m64 (ModR/M /4)

OP_CALL_REL32    = 232  // 0xE8: CALL rel32 (subroutine call)
OP_CALL_INDIRECT = 255  // 0xFF: CALL r/m64 (ModR/M /2)

OP_RET           = 195  // 0xC3: RET near
OP_RET_IMM16     = 194  // 0xC2: RET imm16

// ── 4. Stack & Control Opcodes ────────────────────────────────────────────────

OP_PUSH_BASE     = 80   // 0x50: PUSH r64 (+ reg 0..7)
OP_POP_BASE      = 88   // 0x58: POP r64 (+ reg 0..7)

OP_NOP           = 144  // 0x90: NOP (XCHG eax, eax)
OP_TWO_BYTE_ESC  = 15   // 0x0F: Two-byte opcode escape prefix
OP_SYSCALL_BYTE2 = 5    // 0x05: Second byte of SYSCALL (0x0F 0x05)

// ── 5. Conditional Jump Condition Codes (JCC) ─────────────────────────────────

// WHY: AMD64 condition codes map to CPU arithmetic flags (ZF, CF, SF, OF).
CC_E  = 4   // Equal / Zero (ZF = 1)
CC_NE = 5   // Not Equal / Not Zero (ZF = 0)
CC_B  = 2   // Below / Carry (CF = 1, unsigned <)
CC_AE = 3   // Above or Equal (CF = 0, unsigned >=)
CC_L  = 12  // Less (SF != OF, signed <)
CC_GE = 13  // Greater or Equal (SF == OF, signed >=)
CC_LE = 14  // Less or Equal (ZF = 1 or SF != OF, signed <=)
CC_G  = 15  // Greater (ZF = 0 and SF == OF, signed >)

fn x86_jcc_rel8_opcode cond_code
    // WHY: Returns 1-byte opcode for short conditional jump (0x70 + cond).
    return 112 + (cond_code % 16)

fn x86_jcc_rel32_opcode cond_code
    // WHY: Returns second byte of 2-byte near conditional jump (0x0F 0x80+cond).
    return 128 + (cond_code % 16)

fn x86_cond_from_string cond_str
    // WHY: Translates string comparison operator to hardware condition code.
    if cond_str == "==" or cond_str == "eq"  return CC_E
    if cond_str == "!=" or cond_str == "ne"  return CC_NE
    if cond_str == "<"  or cond_str == "lt"  return CC_L
    if cond_str == ">=" or cond_str == "ge"  return CC_GE
    if cond_str == "<=" or cond_str == "le"  return CC_LE
    if cond_str == ">"  or cond_str == "gt"  return CC_G
    if cond_str == "b"  or cond_str == "ult" return CC_B
    if cond_str == "ae" or cond_str == "uge" return CC_AE
    return CC_E // Default

// ── 6. Verification Self-Test ────────────────────────────────────────────────

fn test_opcode_table_subsystem
    // Verify standard MOV opcodes
    if OP_MOV_RM_R != 137 or OP_MOV_R_RM != 139
        say "FAIL: MOV opcode mismatch"
        return 0

    // Verify JMP & CALL
    if OP_JMP_REL8 != 235 or OP_CALL_REL32 != 232 or OP_RET != 195
        say "FAIL: Control flow opcode mismatch"
        return 0

    // Verify JCC: JE rel8 should be 0x74 = 116
    je_op = x86_jcc_rel8_opcode(CC_E)
    if je_op != 116
        say "FAIL: Expected JE rel8 opcode 116, got: " + str(je_op)
        return 0

    // Verify JCC: JNE rel32 2nd byte should be 0x85 = 133
    jne_op32 = x86_jcc_rel32_opcode(CC_NE)
    if jne_op32 != 133
        say "FAIL: Expected JNE rel32 opcode 133, got: " + str(jne_op32)
        return 0

    // Verify SYSCALL bytes: 0x0F 0x05
    if OP_TWO_BYTE_ESC != 15 or OP_SYSCALL_BYTE2 != 5
        say "FAIL: SYSCALL byte values invalid"
        return 0

    return 1

test_opcode_table_subsystem()
