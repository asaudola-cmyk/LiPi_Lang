@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE: ARM64 BACKEND CODEGEN E2E TEST SUITE
@! File: tests/e2e/test_arm64_codegen_full.maya
@! Milestone 2: Complete End-to-End AArch64 Machine Code Generation & Verification
@! 100% Pure Maya Implementation — Zero External Assembler Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"
import "compiler/backend/arm64/abi"
import "compiler/backend/arm64/codegen"

@! ============================================================================
@! 1. TEST HARNESS & ASSERTION HELPERS
@! ============================================================================

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@fn test_state_new()
  return {
    total: 0,
    passed: 0,
    failed: 0
  }
@end

@fn assert_true(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == 1 || cond == true
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected true, got false)")
    return 0
  @end
@end

@fn assert_false(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == 0 || cond == false
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected false, got true)")
    return 0
  @end
@end

@fn assert_eq_int(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected " + expected.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@fn assert_eq_str(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected '" + expected + "', got '" + actual + "')")
    return 0
  @end
@end

@fn assert_bytes_4(state, buf, offset, b0, b1, b2, b3, test_id, desc)
  state.total = state.total + 1
  @if offset + 3 >= buf.ab_data.len()
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (buffer overflow at offset " + offset.to_str() + ")")
    return 0
  @end

  act0 = buf.ab_data[offset]
  act1 = buf.ab_data[offset + 1]
  act2 = buf.ab_data[offset + 2]
  act3 = buf.ab_data[offset + 3]

  @if act0 == b0 && act1 == b1 && act2 == b2 && act3 == b3
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected [" + b0.to_str() + "," + b1.to_str() + "," + b2.to_str() + "," + b3.to_str() + "], got [" + act0.to_str() + "," + act1.to_str() + "," + act2.to_str() + "," + act3.to_str() + "])")
    return 0
  @end
@end

@! ============================================================================
@! 2. TIER 1: ARM64 ABI & ARCHITECTURE SPECIFICATION TESTS
@! ============================================================================

@fn test_tier1_arm64_abi_constants(state)
  println("\n==================================================")
  println("▶ Tier 1: ARM64 ABI & Register Architecture Specification")
  println("==================================================")

  @! ABI Arguments, Return & Callee-Saved Registers
  arg_regs = arm64_abi_arg_regs()
  assert_eq_int(state, arg_regs.len(), 8, "T1.1_01", "ARM64 ABI defines 8 parameter passing registers (X0-X7)")
  assert_eq_int(state, arg_regs[0], 0, "T1.1_02", "Arg reg 0 is X0 (0)")
  assert_eq_int(state, arg_regs[1], 1, "T1.1_03", "Arg reg 1 is X1 (1)")
  assert_eq_int(state, arg_regs[2], 2, "T1.1_04", "Arg reg 2 is X2 (2)")
  assert_eq_int(state, arg_regs[3], 3, "T1.1_05", "Arg reg 3 is X3 (3)")
  assert_eq_int(state, arg_regs[4], 4, "T1.1_06", "Arg reg 4 is X4 (4)")
  assert_eq_int(state, arg_regs[5], 5, "T1.1_07", "Arg reg 5 is X5 (5)")
  assert_eq_int(state, arg_regs[6], 6, "T1.1_08", "Arg reg 6 is X6 (6)")
  assert_eq_int(state, arg_regs[7], 7, "T1.1_09", "Arg reg 7 is X7 (7)")
  assert_eq_int(state, arm64_abi_ret_reg(), 0, "T1.1_10", "ARM64 ABI return register is X0 (0)")

  callee_saved = arm64_abi_callee_saved()
  assert_eq_int(state, callee_saved.len(), 10, "T1.1_11", "ARM64 ABI defines 10 callee-saved registers (X19-X28)")
  assert_eq_int(state, callee_saved[0], 19, "T1.1_12", "First callee-saved register is X19")
  assert_eq_int(state, callee_saved[1], 20, "T1.1_13", "Callee-saved register is X20")
  assert_eq_int(state, callee_saved[2], 21, "T1.1_14", "Callee-saved register is X21")
  assert_eq_int(state, callee_saved[3], 22, "T1.1_15", "Callee-saved register is X22")
  assert_eq_int(state, callee_saved[4], 23, "T1.1_16", "Callee-saved register is X23")
  assert_eq_int(state, callee_saved[5], 24, "T1.1_17", "Callee-saved register is X24")
  assert_eq_int(state, callee_saved[6], 25, "T1.1_18", "Callee-saved register is X25")
  assert_eq_int(state, callee_saved[7], 26, "T1.1_19", "Callee-saved register is X26")
  assert_eq_int(state, callee_saved[8], 27, "T1.1_20", "Callee-saved register is X27")
  assert_eq_int(state, callee_saved[9], 28, "T1.1_21", "Last callee-saved register is X28")
  assert_eq_int(state, arm64_abi_stack_align(), 16, "T1.1_22", "ARM64 ABI stack frame alignment is 16 bytes")

  @! Register IDs
  assert_eq_int(state, arm64_reg_x0(), 0, "T1.2_01", "Hardware register X0 == 0")
  assert_eq_int(state, arm64_reg_x1(), 1, "T1.2_02", "Hardware register X1 == 1")
  assert_eq_int(state, arm64_reg_x2(), 2, "T1.2_03", "Hardware register X2 == 2")
  assert_eq_int(state, arm64_reg_x3(), 3, "T1.2_04", "Hardware register X3 == 3")
  assert_eq_int(state, arm64_reg_x4(), 4, "T1.2_05", "Hardware register X4 == 4")
  assert_eq_int(state, arm64_reg_x5(), 5, "T1.2_06", "Hardware register X5 == 5")
  assert_eq_int(state, arm64_reg_x6(), 6, "T1.2_07", "Hardware register X6 == 6")
  assert_eq_int(state, arm64_reg_x7(), 7, "T1.2_08", "Hardware register X7 == 7")
  assert_eq_int(state, arm64_reg_x8(), 8, "T1.2_09", "Syscall NR Register X8 == 8")
  assert_eq_int(state, arm64_reg_x9(), 9, "T1.2_10", "Scratch Register X9 == 9")
  assert_eq_int(state, arm64_reg_x10(), 10, "T1.2_11", "Scratch Register X10 == 10")
  assert_eq_int(state, arm64_reg_x11(), 11, "T1.2_12", "Scratch Register X11 == 11")
  assert_eq_int(state, arm64_reg_x12(), 12, "T1.2_13", "Scratch Register X12 == 12")
  assert_eq_int(state, arm64_reg_x13(), 13, "T1.2_14", "Scratch Register X13 == 13")
  assert_eq_int(state, arm64_reg_x14(), 14, "T1.2_15", "Scratch Register X14 == 14")
  assert_eq_int(state, arm64_reg_x15(), 15, "T1.2_16", "Scratch Register X15 == 15")
  assert_eq_int(state, arm64_reg_x19(), 19, "T1.2_17", "Callee-saved Register X19 == 19")
  assert_eq_int(state, arm64_reg_x20(), 20, "T1.2_18", "Callee-saved Register X20 == 20")
  assert_eq_int(state, arm64_reg_x29(), 29, "T1.2_19", "Frame Pointer (FP) Register X29 == 29")
  assert_eq_int(state, arm64_reg_x30(), 30, "T1.2_20", "Link Register (LR) Register X30 == 30")
  assert_eq_int(state, arm64_reg_sp(), 31, "T1.2_21", "Stack Pointer (SP) Register SP == 31")
  assert_eq_int(state, arm64_reg_xzr(), 31, "T1.2_22", "Zero Register (XZR) == 31")

  @! Linux AArch64 Syscall Numbers
  assert_eq_int(state, arm64_sys_read(), 63, "T1.3_01", "Linux AArch64 sys_read == 63")
  assert_eq_int(state, arm64_sys_write(), 64, "T1.3_02", "Linux AArch64 sys_write == 64")
  assert_eq_int(state, arm64_sys_exit(), 93, "T1.3_03", "Linux AArch64 sys_exit == 93")
  assert_eq_int(state, arm64_sys_open(), 56, "T1.3_04", "Linux AArch64 sys_open == 56")
  assert_eq_int(state, arm64_sys_close(), 57, "T1.3_05", "Linux AArch64 sys_close == 57")
  assert_eq_int(state, arm64_sys_mmap(), 222, "T1.3_06", "Linux AArch64 sys_mmap == 222")

  @! Condition Codes
  assert_eq_int(state, arm64_cond_code("eq"), 0, "T1.4_01", "Condition code EQ == 0")
  assert_eq_int(state, arm64_cond_code("ne"), 1, "T1.4_02", "Condition code NE == 1")
  assert_eq_int(state, arm64_cond_code("cs"), 2, "T1.4_03", "Condition code CS/HS == 2")
  assert_eq_int(state, arm64_cond_code("cc"), 3, "T1.4_04", "Condition code CC/LO == 3")
  assert_eq_int(state, arm64_cond_code("mi"), 4, "T1.4_05", "Condition code MI == 4")
  assert_eq_int(state, arm64_cond_code("pl"), 5, "T1.4_06", "Condition code PL == 5")
  assert_eq_int(state, arm64_cond_code("vs"), 6, "T1.4_07", "Condition code VS == 6")
  assert_eq_int(state, arm64_cond_code("vc"), 7, "T1.4_08", "Condition code VC == 7")
  assert_eq_int(state, arm64_cond_code("hi"), 8, "T1.4_09", "Condition code HI == 8")
  assert_eq_int(state, arm64_cond_code("ls"), 9, "T1.4_10", "Condition code LS == 9")
  assert_eq_int(state, arm64_cond_code("ge"), 10, "T1.4_11", "Condition code GE == 10")
  assert_eq_int(state, arm64_cond_code("lt"), 11, "T1.4_12", "Condition code LT == 11")
  assert_eq_int(state, arm64_cond_code("gt"), 12, "T1.4_13", "Condition code GT == 12")
  assert_eq_int(state, arm64_cond_code("le"), 13, "T1.4_14", "Condition code LE == 13")
  assert_eq_int(state, arm64_cond_code("al"), 14, "T1.4_15", "Condition code AL == 14")
@end

@! ============================================================================
@! 3. TIER 2: 32-BIT OPCODES & LITTLE-ENDIAN BYTE SEQUENCES
@! ============================================================================

@fn test_tier2_memory_opcodes_and_bytes(state)
  println("\n==================================================")
  println("▶ Tier 2.1: Memory LDR / STR (Immediate & Register Offsets)")
  println("==================================================")

  @! LDR Immediate: LDR X0, [X1, #0] -> 0xF9400020 -> [0x20, 0x00, 0x40, 0xF9]
  ldr_imm1 = arm64_ldr_imm(0, 1, 0)
  assert_eq_int(state, ldr_imm1, 0xF9400020, "T2.1_01", "Opcode LDR X0, [X1, #0] == 0xF9400020")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, ldr_imm1)
  assert_bytes_4(state, buf, 0, 0x20, 0x00, 0x40, 0xF9, "T2.1_02", "Bytes LDR X0, [X1, #0] == [0x20, 0x00, 0x40, 0xF9]")

  @! LDR Immediate with offset: LDR X0, [X29, #16] -> 0xF9400BA0 -> [0xA0, 0x0B, 0x40, 0xF9]
  ldr_imm2 = arm64_ldr_imm(0, 29, 16)
  assert_eq_int(state, ldr_imm2, 0xF9400BA0, "T2.1_03", "Opcode LDR X0, [X29, #16] == 0xF9400BA0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, ldr_imm2)
  assert_bytes_4(state, buf, 0, 0xA0, 0x0B, 0x40, 0xF9, "T2.1_04", "Bytes LDR X0, [X29, #16] == [0xA0, 0x0B, 0x40, 0xF9]")

  @! LDR Immediate large offset: LDR X3, [X4, #64] -> 0xF9402083 -> [0x83, 0x20, 0x40, 0xF9]
  ldr_imm3 = arm64_ldr_imm(3, 4, 64)
  assert_eq_int(state, ldr_imm3, 0xF9402083, "T2.1_05", "Opcode LDR X3, [X4, #64] == 0xF9402083")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, ldr_imm3)
  assert_bytes_4(state, buf, 0, 0x83, 0x20, 0x40, 0xF9, "T2.1_06", "Bytes LDR X3, [X4, #64] == [0x83, 0x20, 0x40, 0xF9]")

  @! LDR Register: LDR X0, [X1, X2] -> 0xF8626820 -> [0x20, 0x68, 0x62, 0xF8]
  ldr_reg1 = arm64_ldr_reg(0, 1, 2)
  assert_eq_int(state, ldr_reg1, 0xF8626820, "T2.1_07", "Opcode LDR X0, [X1, X2] == 0xF8626820")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, ldr_reg1)
  assert_bytes_4(state, buf, 0, 0x20, 0x68, 0x62, 0xF8, "T2.1_08", "Bytes LDR X0, [X1, X2] == [0x20, 0x68, 0x62, 0xF8]")

  @! LDR Register: LDR X9, [X29, X15] -> 0xF86F6BA9 -> [0xA9, 0x6B, 0x6F, 0xF8]
  ldr_reg2 = arm64_ldr_reg(9, 29, 15)
  assert_eq_int(state, ldr_reg2, 0xF86F6BA9, "T2.1_09", "Opcode LDR X9, [X29, X15] == 0xF86F6BA9")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, ldr_reg2)
  assert_bytes_4(state, buf, 0, 0xA9, 0x6B, 0x6F, 0xF8, "T2.1_10", "Bytes LDR X9, [X29, X15] == [0xA9, 0x6B, 0x6F, 0xF8]")

  @! STR Immediate: STR X0, [X1, #0] -> 0xF9000020 -> [0x20, 0x00, 0x00, 0xF9]
  str_imm1 = arm64_str_imm(0, 1, 0)
  assert_eq_int(state, str_imm1, 0xF9000020, "T2.1_11", "Opcode STR X0, [X1, #0] == 0xF9000020")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, str_imm1)
  assert_bytes_4(state, buf, 0, 0x20, 0x00, 0x00, 0xF9, "T2.1_12", "Bytes STR X0, [X1, #0] == [0x20, 0x00, 0x00, 0xF9]")

  @! STR Immediate with offset: STR X2, [X29, #16] -> 0xF9000BA2 -> [0xA2, 0x0B, 0x00, 0xF9]
  str_imm2 = arm64_str_imm(2, 29, 16)
  assert_eq_int(state, str_imm2, 0xF9000BA2, "T2.1_13", "Opcode STR X2, [X29, #16] == 0xF9000BA2")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, str_imm2)
  assert_bytes_4(state, buf, 0, 0xA2, 0x0B, 0x00, 0xF9, "T2.1_14", "Bytes STR X2, [X29, #16] == [0xA2, 0x0B, 0x00, 0xF9]")

  @! STR Immediate: STR X9, [X10, #0] -> 0xF9000149 -> [0x49, 0x01, 0x00, 0xF9]
  str_imm3 = arm64_str_imm(9, 10, 0)
  assert_eq_int(state, str_imm3, 0xF9000149, "T2.1_15", "Opcode STR X9, [X10, #0] == 0xF9000149")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, str_imm3)
  assert_bytes_4(state, buf, 0, 0x49, 0x01, 0x00, 0xF9, "T2.1_16", "Bytes STR X9, [X10, #0] == [0x49, 0x01, 0x00, 0xF9]")

  @! STR Register: STR X0, [X1, X2] -> 0xF8226820 -> [0x20, 0x68, 0x22, 0xF8]
  str_reg1 = arm64_str_reg(0, 1, 2)
  assert_eq_int(state, str_reg1, 0xF8226820, "T2.1_17", "Opcode STR X0, [X1, X2] == 0xF8226820")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, str_reg1)
  assert_bytes_4(state, buf, 0, 0x20, 0x68, 0x22, 0xF8, "T2.1_18", "Bytes STR X0, [X1, X2] == [0x20, 0x68, 0x22, 0xF8]")

  @! STR Register: STR X0, [X29, X15] -> 0xF82F6BA0 -> [0xA0, 0x6B, 0x2F, 0xF8]
  str_reg2 = arm64_str_reg(0, 29, 15)
  assert_eq_int(state, str_reg2, 0xF82F6BA0, "T2.1_19", "Opcode STR X0, [X29, X15] == 0xF82F6BA0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, str_reg2)
  assert_bytes_4(state, buf, 0, 0xA0, 0x6B, 0x2F, 0xF8, "T2.1_20", "Bytes STR X0, [X29, X15] == [0xA0, 0x6B, 0x2F, 0xF8]")
@end

@fn test_tier2_arithmetic_opcodes_and_bytes(state)
  println("\n==================================================")
  println("▶ Tier 2.2: Arithmetic ADD, SUB, MUL, MSUB, SDIV (Reg & Imm)")
  println("==================================================")

  @! ADD Register: ADD X0, X1, X2 -> 0x8B020020 -> [0x20, 0x00, 0x02, 0x8B]
  add_reg1 = arm64_add(0, 1, 2)
  assert_eq_int(state, add_reg1, 0x8B020020, "T2.2_01", "Opcode ADD X0, X1, X2 == 0x8B020020")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, add_reg1)
  assert_bytes_4(state, buf, 0, 0x20, 0x00, 0x02, 0x8B, "T2.2_02", "Bytes ADD X0, X1, X2 == [0x20, 0x00, 0x02, 0x8B]")

  @! ADD Register: ADD X0, X9, X10 -> 0x8B0A0120 -> [0x20, 0x01, 0x0A, 0x8B]
  add_reg2 = arm64_add(0, 9, 10)
  assert_eq_int(state, add_reg2, 0x8B0A0120, "T2.2_03", "Opcode ADD X0, X9, X10 == 0x8B0A0120")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, add_reg2)
  assert_bytes_4(state, buf, 0, 0x20, 0x01, 0x0A, 0x8B, "T2.2_04", "Bytes ADD X0, X9, X10 == [0x20, 0x01, 0x0A, 0x8B]")

  @! ADD Register: ADD X0, X29, X15 -> 0x8B0F03A0 -> [0xA0, 0x03, 0x0F, 0x8B]
  add_reg3 = arm64_add(0, 29, 15)
  assert_eq_int(state, add_reg3, 0x8B0F03A0, "T2.2_05", "Opcode ADD X0, X29, X15 == 0x8B0F03A0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, add_reg3)
  assert_bytes_4(state, buf, 0, 0xA0, 0x03, 0x0F, 0x8B, "T2.2_06", "Bytes ADD X0, X29, X15 == [0xA0, 0x03, 0x0F, 0x8B]")

  @! ADD Immediate: ADD X29, SP, #0 -> 0x910003FD -> [0xFD, 0x03, 0x00, 0x91]
  add_imm1 = arm64_add_imm(29, 31, 0)
  assert_eq_int(state, add_imm1, 0x910003FD, "T2.2_07", "Opcode ADD X29, SP, #0 == 0x910003FD")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, add_imm1)
  assert_bytes_4(state, buf, 0, 0xFD, 0x03, 0x00, 0x91, "T2.2_08", "Bytes ADD X29, SP, #0 == [0xFD, 0x03, 0x00, 0x91]")

  @! ADD Immediate: ADD SP, X29, #0 -> 0x910003BF -> [0xBF, 0x03, 0x00, 0x91]
  add_imm2 = arm64_add_imm(31, 29, 0)
  assert_eq_int(state, add_imm2, 0x910003BF, "T2.2_09", "Opcode ADD SP, X29, #0 == 0x910003BF")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, add_imm2)
  assert_bytes_4(state, buf, 0, 0xBF, 0x03, 0x00, 0x91, "T2.2_10", "Bytes ADD SP, X29, #0 == [0xBF, 0x03, 0x00, 0x91]")

  @! ADD Immediate: ADD X0, X1, #100 -> 0x91019020 -> [0x20, 0x90, 0x01, 0x91]
  add_imm3 = arm64_add_imm(0, 1, 100)
  assert_eq_int(state, add_imm3, 0x91019020, "T2.2_11", "Opcode ADD X0, X1, #100 == 0x91019020")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, add_imm3)
  assert_bytes_4(state, buf, 0, 0x20, 0x90, 0x01, 0x91, "T2.2_12", "Bytes ADD X0, X1, #100 == [0x20, 0x90, 0x01, 0x91]")

  @! SUB Register: SUB X0, X1, X2 -> 0xCB020020 -> [0x20, 0x00, 0x02, 0xCB]
  sub_reg1 = arm64_sub(0, 1, 2)
  assert_eq_int(state, sub_reg1, 0xCB020020, "T2.2_13", "Opcode SUB X0, X1, X2 == 0xCB020020")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, sub_reg1)
  assert_bytes_4(state, buf, 0, 0x20, 0x00, 0x02, 0xCB, "T2.2_14", "Bytes SUB X0, X1, X2 == [0x20, 0x00, 0x02, 0xCB]")

  @! SUB Register: SUB X0, X9, X10 -> 0xCB0A0120 -> [0x20, 0x01, 0x0A, 0xCB]
  sub_reg2 = arm64_sub(0, 9, 10)
  assert_eq_int(state, sub_reg2, 0xCB0A0120, "T2.2_15", "Opcode SUB X0, X9, X10 == 0xCB0A0120")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, sub_reg2)
  assert_bytes_4(state, buf, 0, 0x20, 0x01, 0x0A, 0xCB, "T2.2_16", "Bytes SUB X0, X9, X10 == [0x20, 0x01, 0x0A, 0xCB]")

  @! SUB Immediate: SUB SP, SP, #16 -> 0xD10043FF -> [0xFF, 0x43, 0x00, 0xD1]
  sub_imm1 = arm64_sub_imm(31, 31, 16)
  assert_eq_int(state, sub_imm1, 0xD10043FF, "T2.2_17", "Opcode SUB SP, SP, #16 == 0xD10043FF")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, sub_imm1)
  assert_bytes_4(state, buf, 0, 0xFF, 0x43, 0x00, 0xD1, "T2.2_18", "Bytes SUB SP, SP, #16 == [0xFF, 0x43, 0x00, 0xD1]")

  @! SUB Immediate: SUB SP, SP, #64 -> 0xD10103FF -> [0xFF, 0x03, 0x01, 0xD1]
  sub_imm2 = arm64_sub_imm(31, 31, 64)
  assert_eq_int(state, sub_imm2, 0xD10103FF, "T2.2_19", "Opcode SUB SP, SP, #64 == 0xD10103FF")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, sub_imm2)
  assert_bytes_4(state, buf, 0, 0xFF, 0x03, 0x01, 0xD1, "T2.2_20", "Bytes SUB SP, SP, #64 == [0xFF, 0x03, 0x01, 0xD1]")

  @! MUL: MUL X0, X1, X2 -> 0x9B027C20 -> [0x20, 0x7C, 0x02, 0x9B]
  mul1 = arm64_mul(0, 1, 2)
  assert_eq_int(state, mul1, 0x9B027C20, "T2.2_21", "Opcode MUL X0, X1, X2 == 0x9B027C20")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, mul1)
  assert_bytes_4(state, buf, 0, 0x20, 0x7C, 0x02, 0x9B, "T2.2_22", "Bytes MUL X0, X1, X2 == [0x20, 0x7C, 0x02, 0x9B]")

  @! MUL: MUL X0, X9, X10 -> 0x9B0A7D20 -> [0x20, 0x7D, 0x0A, 0x9B]
  mul2 = arm64_mul(0, 9, 10)
  assert_eq_int(state, mul2, 0x9B0A7D20, "T2.2_23", "Opcode MUL X0, X9, X10 == 0x9B0A7D20")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, mul2)
  assert_bytes_4(state, buf, 0, 0x20, 0x7D, 0x0A, 0x9B, "T2.2_24", "Bytes MUL X0, X9, X10 == [0x20, 0x7D, 0x0A, 0x9B]")

  @! MUL: MUL X12, X10, X11 -> 0x9B0B7D4C -> [0x4C, 0x7D, 0x0B, 0x9B]
  mul3 = arm64_mul(12, 10, 11)
  assert_eq_int(state, mul3, 0x9B0B7D4C, "T2.2_25", "Opcode MUL X12, X10, X11 == 0x9B0B7D4C")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, mul3)
  assert_bytes_4(state, buf, 0, 0x4C, 0x7D, 0x0B, 0x9B, "T2.2_26", "Bytes MUL X12, X10, X11 == [0x4C, 0x7D, 0x0B, 0x9B]")

  @! MSUB: MSUB X0, X11, X10, X9 (X0 = X9 - X11 * X10) -> 0x9B0AA560 -> [0x60, 0xA5, 0x0A, 0x9B]
  msub1 = arm64_msub(0, 11, 10, 9)
  assert_eq_int(state, msub1, 0x9B0AA560, "T2.2_27", "Opcode MSUB X0, X11, X10, X9 == 0x9B0AA560")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, msub1)
  assert_bytes_4(state, buf, 0, 0x60, 0xA5, 0x0A, 0x9B, "T2.2_28", "Bytes MSUB X0, X11, X10, X9 == [0x60, 0xA5, 0x0A, 0x9B]")

  @! MSUB: MSUB X1, X2, X3, X4 -> 0x9B039041 -> [0x41, 0x90, 0x03, 0x9B]
  msub2 = arm64_msub(1, 2, 3, 4)
  assert_eq_int(state, msub2, 0x9B039041, "T2.2_29", "Opcode MSUB X1, X2, X3, X4 == 0x9B039041")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, msub2)
  assert_bytes_4(state, buf, 0, 0x41, 0x90, 0x03, 0x9B, "T2.2_30", "Bytes MSUB X1, X2, X3, X4 == [0x41, 0x90, 0x03, 0x9B]")

  @! SDIV: SDIV X0, X1, X2 -> 0x9AC20C20 -> [0x20, 0x0C, 0xC2, 0x9A]
  sdiv1 = arm64_sdiv(0, 1, 2)
  assert_eq_int(state, sdiv1, 0x9AC20C20, "T2.2_31", "Opcode SDIV X0, X1, X2 == 0x9AC20C20")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, sdiv1)
  assert_bytes_4(state, buf, 0, 0x20, 0x0C, 0xC2, 0x9A, "T2.2_32", "Bytes SDIV X0, X1, X2 == [0x20, 0x0C, 0xC2, 0x9A]")

  @! SDIV: SDIV X0, X9, X10 -> 0x9ACA0D20 -> [0x20, 0x0D, 0xCA, 0x9A]
  sdiv2 = arm64_sdiv(0, 9, 10)
  assert_eq_int(state, sdiv2, 0x9ACA0D20, "T2.2_33", "Opcode SDIV X0, X9, X10 == 0x9ACA0D20")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, sdiv2)
  assert_bytes_4(state, buf, 0, 0x20, 0x0D, 0xCA, 0x9A, "T2.2_34", "Bytes SDIV X0, X9, X10 == [0x20, 0x0D, 0xCA, 0x9A]")

  @! SDIV: SDIV X11, X9, X10 -> 0x9ACA0D2B -> [0x2B, 0x0D, 0xCA, 0x9A]
  sdiv3 = arm64_sdiv(11, 9, 10)
  assert_eq_int(state, sdiv3, 0x9ACA0D2B, "T2.2_35", "Opcode SDIV X11, X9, X10 == 0x9ACA0D2B")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, sdiv3)
  assert_bytes_4(state, buf, 0, 0x2B, 0x0D, 0xCA, 0x9A, "T2.2_36", "Bytes SDIV X11, X9, X10 == [0x2B, 0x0D, 0xCA, 0x9A]")
@end

@fn test_tier2_bitwise_and_unary_opcodes(state)
  println("\n==================================================")
  println("▶ Tier 2.3: Bitwise & Unary (AND, ORR, EOR, LSLV, LSRV, ASRV, NEG, MVN)")
  println("==================================================")

  @! AND: AND X0, X1, X2 -> 0x8A020020 -> [0x20, 0x00, 0x02, 0x8A]
  and1 = arm64_and(0, 1, 2)
  assert_eq_int(state, and1, 0x8A020020, "T2.3_01", "Opcode AND X0, X1, X2 == 0x8A020020")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, and1)
  assert_bytes_4(state, buf, 0, 0x20, 0x00, 0x02, 0x8A, "T2.3_02", "Bytes AND X0, X1, X2 == [0x20, 0x00, 0x02, 0x8A]")

  @! ORR: ORR X0, X1, X2 -> 0xAA020020 -> [0x20, 0x00, 0x02, 0xAA]
  orr1 = arm64_orr(0, 1, 2)
  assert_eq_int(state, orr1, 0xAA020020, "T2.3_03", "Opcode ORR X0, X1, X2 == 0xAA020020")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, orr1)
  assert_bytes_4(state, buf, 0, 0x20, 0x00, 0x02, 0xAA, "T2.3_04", "Bytes ORR X0, X1, X2 == [0x20, 0x00, 0x02, 0xAA]")

  @! EOR: EOR X0, X1, X2 -> 0xCA020020 -> [0x20, 0x00, 0x02, 0xCA]
  eor1 = arm64_eor(0, 1, 2)
  assert_eq_int(state, eor1, 0xCA020020, "T2.3_05", "Opcode EOR X0, X1, X2 == 0xCA020020")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, eor1)
  assert_bytes_4(state, buf, 0, 0x20, 0x00, 0x02, 0xCA, "T2.3_06", "Bytes EOR X0, X1, X2 == [0x20, 0x00, 0x02, 0xCA]")

  @! LSLV: LSLV X0, X9, X10 -> 0x9ACA2120 -> [0x20, 0x21, 0xCA, 0x9A]
  lslv1 = arm64_lslv(0, 9, 10)
  assert_eq_int(state, lslv1, 0x9ACA2120, "T2.3_07", "Opcode LSLV X0, X9, X10 == 0x9ACA2120")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, lslv1)
  assert_bytes_4(state, buf, 0, 0x20, 0x21, 0xCA, 0x9A, "T2.3_08", "Bytes LSLV X0, X9, X10 == [0x20, 0x21, 0xCA, 0x9A]")

  @! LSRV: LSRV X0, X9, X10 -> 0x9ACA2520 -> [0x20, 0x25, 0xCA, 0x9A]
  lsrv1 = arm64_lsrv(0, 9, 10)
  assert_eq_int(state, lsrv1, 0x9ACA2520, "T2.3_09", "Opcode LSRV X0, X9, X10 == 0x9ACA2520")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, lsrv1)
  assert_bytes_4(state, buf, 0, 0x20, 0x25, 0xCA, 0x9A, "T2.3_10", "Bytes LSRV X0, X9, X10 == [0x20, 0x25, 0xCA, 0x9A]")

  @! ASRV: ASRV X0, X9, X10 -> 0x9ACA2920 -> [0x20, 0x29, 0xCA, 0x9A]
  asrv1 = arm64_asrv(0, 9, 10)
  assert_eq_int(state, asrv1, 0x9ACA2920, "T2.3_11", "Opcode ASRV X0, X9, X10 == 0x9ACA2920")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, asrv1)
  assert_bytes_4(state, buf, 0, 0x20, 0x29, 0xCA, 0x9A, "T2.3_12", "Bytes ASRV X0, X9, X10 == [0x20, 0x29, 0xCA, 0x9A]")

  @! NEG: NEG X0, X9 -> 0xCB0903E0 -> [0xE0, 0x03, 0x09, 0xCB]
  neg1 = arm64_neg(0, 9)
  assert_eq_int(state, neg1, 0xCB0903E0, "T2.3_13", "Opcode NEG X0, X9 == 0xCB0903E0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, neg1)
  assert_bytes_4(state, buf, 0, 0xE0, 0x03, 0x09, 0xCB, "T2.3_14", "Bytes NEG X0, X9 == [0xE0, 0x03, 0x09, 0xCB]")

  @! MVN: MVN X0, X9 -> 0xAA2903E0 -> [0xE0, 0x03, 0x29, 0xAA]
  mvn1 = arm64_mvn(0, 9)
  assert_eq_int(state, mvn1, 0xAA2903E0, "T2.3_15", "Opcode MVN X0, X9 == 0xAA2903E0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, mvn1)
  assert_bytes_4(state, buf, 0, 0xE0, 0x03, 0x29, 0xAA, "T2.3_16", "Bytes MVN X0, X9 == [0xE0, 0x03, 0x29, 0xAA]")
@end

@fn test_tier2_call_syscall_branch_opcodes(state)
  println("\n==================================================")
  println("▶ Tier 2.4: BL, BLR, SVC, STP, LDP, CMP, CSET, B, B.cond")
  println("==================================================")

  @! BL: BL #0 -> 0x94000000 -> [0x00, 0x00, 0x00, 0x94]
  bl1 = arm64_bl(0)
  assert_eq_int(state, bl1, 0x94000000, "T2.4_01", "Opcode BL #0 == 0x94000000")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, bl1)
  assert_bytes_4(state, buf, 0, 0x00, 0x00, 0x00, 0x94, "T2.4_02", "Bytes BL #0 == [0x00, 0x00, 0x00, 0x94]")

  @! BL: BL #100 -> 0x94000064 -> [0x64, 0x00, 0x00, 0x94]
  bl2 = arm64_bl(100)
  assert_eq_int(state, bl2, 0x94000064, "T2.4_03", "Opcode BL #100 == 0x94000064")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, bl2)
  assert_bytes_4(state, buf, 0, 0x64, 0x00, 0x00, 0x94, "T2.4_04", "Bytes BL #100 == [0x64, 0x00, 0x00, 0x94]")

  @! BL: BL #-4 -> 0x97FFFFFC -> [0xFC, 0xFF, 0xFF, 0x97]
  bl3 = arm64_bl(-4)
  assert_eq_int(state, bl3, 0x97FFFFFC, "T2.4_05", "Opcode BL #-4 == 0x97FFFFFC")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, bl3)
  assert_bytes_4(state, buf, 0, 0xFC, 0xFF, 0xFF, 0x97, "T2.4_06", "Bytes BL #-4 == [0xFC, 0xFF, 0xFF, 0x97]")

  @! BLR: BLR X0 -> 0xD63F0000 -> [0x00, 0x00, 0x3F, 0xD6]
  blr1 = arm64_blr(0)
  assert_eq_int(state, blr1, 0xD63F0000, "T2.4_07", "Opcode BLR X0 == 0xD63F0000")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, blr1)
  assert_bytes_4(state, buf, 0, 0x00, 0x00, 0x3F, 0xD6, "T2.4_08", "Bytes BLR X0 == [0x00, 0x00, 0x3F, 0xD6]")

  @! BLR: BLR X1 -> 0xD63F0020 -> [0x20, 0x00, 0x3F, 0xD6]
  blr2 = arm64_blr(1)
  assert_eq_int(state, blr2, 0xD63F0020, "T2.4_09", "Opcode BLR X1 == 0xD63F0020")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, blr2)
  assert_bytes_4(state, buf, 0, 0x20, 0x00, 0x3F, 0xD6, "T2.4_10", "Bytes BLR X1 == [0x20, 0x00, 0x3F, 0xD6]")

  @! BLR: BLR X8 -> 0xD63F0100 -> [0x00, 0x01, 0x3F, 0xD6]
  blr3 = arm64_blr(8)
  assert_eq_int(state, blr3, 0xD63F0100, "T2.4_11", "Opcode BLR X8 == 0xD63F0100")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, blr3)
  assert_bytes_4(state, buf, 0, 0x00, 0x01, 0x3F, 0xD6, "T2.4_12", "Bytes BLR X8 == [0x00, 0x01, 0x3F, 0xD6]")

  @! SVC: SVC #0 (Linux AArch64 Syscall) -> 0xD4000001 -> [0x01, 0x00, 0x00, 0xD4]
  svc1 = arm64_svc()
  assert_eq_int(state, svc1, 0xD4000001, "T2.4_13", "Opcode SVC #0 == 0xD4000001")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, svc1)
  assert_bytes_4(state, buf, 0, 0x01, 0x00, 0x00, 0xD4, "T2.4_14", "Bytes SVC #0 == [0x01, 0x00, 0x00, 0xD4]")

  @! STP Pre-indexed: STP X29, X30, [SP, #-16]! -> 0xA9BF7BFD -> [0xFD, 0x7B, 0xBF, 0xA9]
  stp1 = arm64_stp(29, 30, 31, -16)
  assert_eq_int(state, stp1, 0xA9BF7BFD, "T2.4_15", "Opcode STP X29, X30, [SP, #-16]! == 0xA9BF7BFD")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, stp1)
  assert_bytes_4(state, buf, 0, 0xFD, 0x7B, 0xBF, 0xA9, "T2.4_16", "Bytes STP X29, X30, [SP, #-16]! == [0xFD, 0x7B, 0xBF, 0xA9]")

  @! LDP Post-indexed: LDP X29, X30, [SP], #16 -> 0xA8C17BFD -> [0xFD, 0x7B, 0xC1, 0xA8]
  ldp1 = arm64_ldp(29, 30, 31, 16)
  assert_eq_int(state, ldp1, 0xA8C17BFD, "T2.4_17", "Opcode LDP X29, X30, [SP], #16 == 0xA8C17BFD")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, ldp1)
  assert_bytes_4(state, buf, 0, 0xFD, 0x7B, 0xC1, 0xA8, "T2.4_18", "Bytes LDP X29, X30, [SP], #16 == [0xFD, 0x7B, 0xC1, 0xA8]")

  @! STP Callee-saved: STP X19, X20, [SP, #-16]! -> 0xA9BF53F3 -> [0xF3, 0x53, 0xBF, 0xA9]
  stp2 = arm64_stp(19, 20, 31, -16)
  assert_eq_int(state, stp2, 0xA9BF53F3, "T2.4_19", "Opcode STP X19, X20, [SP, #-16]! == 0xA9BF53F3")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, stp2)
  assert_bytes_4(state, buf, 0, 0xF3, 0x53, 0xBF, 0xA9, "T2.4_20", "Bytes STP X19, X20, [SP, #-16]! == [0xF3, 0x53, 0xBF, 0xA9]")

  @! LDP Callee-saved: LDP X19, X20, [SP], #16 -> 0xA8C153F3 -> [0xF3, 0x53, 0xC1, 0xA8]
  ldp2 = arm64_ldp(19, 20, 31, 16)
  assert_eq_int(state, ldp2, 0xA8C153F3, "T2.4_21", "Opcode LDP X19, X20, [SP], #16 == 0xA8C153F3")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, ldp2)
  assert_bytes_4(state, buf, 0, 0xF3, 0x53, 0xC1, 0xA8, "T2.4_22", "Bytes LDP X19, X20, [SP], #16 == [0xF3, 0x53, 0xC1, 0xA8]")

  @! CMP Register: CMP X1, X2 -> 0xEB02003F -> [0x3F, 0x00, 0x02, 0xEB]
  cmp1 = arm64_cmp(1, 2)
  assert_eq_int(state, cmp1, 0xEB02003F, "T2.4_23", "Opcode CMP X1, X2 == 0xEB02003F")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, cmp1)
  assert_bytes_4(state, buf, 0, 0x3F, 0x00, 0x02, 0xEB, "T2.4_24", "Bytes CMP X1, X2 == [0x3F, 0x00, 0x02, 0xEB]")

  @! CMP Register: CMP X9, X10 -> 0xEB0A013F -> [0x3F, 0x01, 0x0A, 0xEB]
  cmp2 = arm64_cmp(9, 10)
  assert_eq_int(state, cmp2, 0xEB0A013F, "T2.4_25", "Opcode CMP X9, X10 == 0xEB0A013F")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, cmp2)
  assert_bytes_4(state, buf, 0, 0x3F, 0x01, 0x0A, 0xEB, "T2.4_26", "Bytes CMP X9, X10 == [0x3F, 0x01, 0x0A, 0xEB]")

  @! CMP Immediate: CMP X9, #0 -> 0xF100013F -> [0x3F, 0x01, 0x00, 0xF1]
  cmp_imm1 = arm64_cmp_imm(9, 0)
  assert_eq_int(state, cmp_imm1, 0xF100013F, "T2.4_27", "Opcode CMP X9, #0 == 0xF100013F")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, cmp_imm1)
  assert_bytes_4(state, buf, 0, 0x3F, 0x01, 0x00, 0xF1, "T2.4_28", "Bytes CMP X9, #0 == [0x3F, 0x01, 0x00, 0xF1]")

  @! CSET for condition EQ (cond 0 -> inv 1 NE): 0x9A9F17E0 -> [0xE0, 0x17, 0x9F, 0x9A]
  cset_eq = arm64_cset(0, 0)
  assert_eq_int(state, cset_eq, 0x9A9F17E0, "T2.4_29", "Opcode CSET X0, EQ == 0x9A9F17E0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, cset_eq)
  assert_bytes_4(state, buf, 0, 0xE0, 0x17, 0x9F, 0x9A, "T2.4_30", "Bytes CSET X0, EQ == [0xE0, 0x17, 0x9F, 0x9A]")

  @! CSET for condition NE (cond 1 -> inv 0 EQ): 0x9A9F07E0 -> [0xE0, 0x07, 0x9F, 0x9A]
  cset_ne = arm64_cset(0, 1)
  assert_eq_int(state, cset_ne, 0x9A9F07E0, "T2.4_31", "Opcode CSET X0, NE == 0x9A9F07E0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, cset_ne)
  assert_bytes_4(state, buf, 0, 0xE0, 0x07, 0x9F, 0x9A, "T2.4_32", "Bytes CSET X0, NE == [0xE0, 0x07, 0x9F, 0x9A]")

  @! CSET for condition GE (cond 10 -> inv 11 LT): 0x9A9FB7E0 -> [0xE0, 0xB7, 0x9F, 0x9A]
  cset_ge = arm64_cset(0, 10)
  assert_eq_int(state, cset_ge, 0x9A9FB7E0, "T2.4_33", "Opcode CSET X0, GE == 0x9A9FB7E0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, cset_ge)
  assert_bytes_4(state, buf, 0, 0xE0, 0xB7, 0x9F, 0x9A, "T2.4_34", "Bytes CSET X0, GE == [0xE0, 0xB7, 0x9F, 0x9A]")

  @! CSET for condition LT (cond 11 -> inv 10 GE): 0x9A9FA7E0 -> [0xE0, 0xA7, 0x9F, 0x9A]
  cset_lt = arm64_cset(0, 11)
  assert_eq_int(state, cset_lt, 0x9A9FA7E0, "T2.4_35", "Opcode CSET X0, LT == 0x9A9FA7E0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, cset_lt)
  assert_bytes_4(state, buf, 0, 0xE0, 0xA7, 0x9F, 0x9A, "T2.4_36", "Bytes CSET X0, LT == [0xE0, 0xA7, 0x9F, 0x9A]")

  @! CSET for condition GT (cond 12 -> inv 13 LE): 0x9A9FD7E0 -> [0xE0, 0xD7, 0x9F, 0x9A]
  cset_gt = arm64_cset(0, 12)
  assert_eq_int(state, cset_gt, 0x9A9FD7E0, "T2.4_37", "Opcode CSET X0, GT == 0x9A9FD7E0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, cset_gt)
  assert_bytes_4(state, buf, 0, 0xE0, 0xD7, 0x9F, 0x9A, "T2.4_38", "Bytes CSET X0, GT == [0xE0, 0xD7, 0x9F, 0x9A]")

  @! CSET for condition LE (cond 13 -> inv 12 GT): 0x9A9FC7E0 -> [0xE0, 0xC7, 0x9F, 0x9A]
  cset_le = arm64_cset(0, 13)
  assert_eq_int(state, cset_le, 0x9A9FC7E0, "T2.4_39", "Opcode CSET X0, LE == 0x9A9FC7E0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, cset_le)
  assert_bytes_4(state, buf, 0, 0xE0, 0xC7, 0x9F, 0x9A, "T2.4_40", "Bytes CSET X0, LE == [0xE0, 0xC7, 0x9F, 0x9A]")

  @! B Unconditional Branch: B #10 -> 0x1400000A -> [0x0A, 0x00, 0x00, 0x14]
  b1 = arm64_b(10)
  assert_eq_int(state, b1, 0x1400000A, "T2.4_41", "Opcode B #10 == 0x1400000A")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, b1)
  assert_bytes_4(state, buf, 0, 0x0A, 0x00, 0x00, 0x14, "T2.4_42", "Bytes B #10 == [0x0A, 0x00, 0x00, 0x14]")

  @! B Backward Unconditional Branch: B #-5 -> 0x17FFFFFB -> [0xFB, 0xFF, 0xFF, 0x17]
  b2 = arm64_b(-5)
  assert_eq_int(state, b2, 0x17FFFFFB, "T2.4_43", "Opcode B #-5 == 0x17FFFFFB")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, b2)
  assert_bytes_4(state, buf, 0, 0xFB, 0xFF, 0xFF, 0x17, "T2.4_44", "Bytes B #-5 == [0xFB, 0xFF, 0xFF, 0x17]")

  @! B.cond Conditional Branch: B.EQ #5 -> 0x540000A0 -> [0xA0, 0x00, 0x00, 0x54]
  b_cond1 = arm64_b_cond(0, 5)
  assert_eq_int(state, b_cond1, 0x540000A0, "T2.4_45", "Opcode B.EQ #5 == 0x540000A0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, b_cond1)
  assert_bytes_4(state, buf, 0, 0xA0, 0x00, 0x00, 0x54, "T2.4_46", "Bytes B.EQ #5 == [0xA0, 0x00, 0x00, 0x54]")

  @! B.cond Conditional Branch: B.NE #5 -> 0x540000A1 -> [0xA1, 0x00, 0x00, 0x54]
  b_cond2 = arm64_b_cond(1, 5)
  assert_eq_int(state, b_cond2, 0x540000A1, "T2.4_47", "Opcode B.NE #5 == 0x540000A1")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, b_cond2)
  assert_bytes_4(state, buf, 0, 0xA1, 0x00, 0x00, 0x54, "T2.4_48", "Bytes B.NE #5 == [0xA1, 0x00, 0x00, 0x54]")

  @! B.cond Backward Conditional Branch: B.NE #-4 -> 0x54FFFF81 -> [0x81, 0xFF, 0xFF, 0x54]
  b_cond3 = arm64_b_cond(1, -4)
  assert_eq_int(state, b_cond3, 0x54FFFF81, "T2.4_49", "Opcode B.NE #-4 == 0x54FFFF81")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, b_cond3)
  assert_bytes_4(state, buf, 0, 0x81, 0xFF, 0xFF, 0x54, "T2.4_50", "Bytes B.NE #-4 == [0x81, 0xFF, 0xFF, 0x54]")

  @! B.cond Backward Conditional Branch: B.EQ #-1 -> 0x54FFFFE0 -> [0xE0, 0xFF, 0xFF, 0x54]
  b_cond4 = arm64_b_cond(0, -1)
  assert_eq_int(state, b_cond4, 0x54FFFFE0, "T2.4_51", "Opcode B.EQ #-1 == 0x54FFFFE0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, b_cond4)
  assert_bytes_4(state, buf, 0, 0xE0, 0xFF, 0xFF, 0x54, "T2.4_52", "Bytes B.EQ #-1 == [0xE0, 0xFF, 0xFF, 0x54]")

  @! RET -> 0xD65F03C0 -> [0xC0, 0x03, 0x5F, 0xD6]
  ret1 = arm64_ret()
  assert_eq_int(state, ret1, 0xD65F03C0, "T2.4_53", "Opcode RET == 0xD65F03C0")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, ret1)
  assert_bytes_4(state, buf, 0, 0xC0, 0x03, 0x5F, 0xD6, "T2.4_54", "Bytes RET == [0xC0, 0x03, 0x5F, 0xD6]")

  @! NOP -> 0xD503201F -> [0x1F, 0x20, 0x03, 0xD5]
  nop1 = arm64_nop()
  assert_eq_int(state, nop1, 0xD503201F, "T2.4_55", "Opcode NOP == 0xD503201F")
  buf = arm64_buf_new()
  buf = arm64_emit32(buf, nop1)
  assert_bytes_4(state, buf, 0, 0x1F, 0x20, 0x03, 0xD5, "T2.4_56", "Bytes NOP == [0x1F, 0x20, 0x03, 0xD5]")
@end

@! ============================================================================
@! 4. TIER 3: FIXUP RESOLUTION ENGINE VERIFICATION
@! ============================================================================

@fn test_tier3_fixup_resolution(state)
  println("\n==================================================")
  println("▶ Tier 3: Branch & Call Fixup Resolution Engine")
  println("==================================================")

  ctx = arm64_ctx_new()

  @! Emit forward branch fixup at offset 0 targeting block 1 (at offset 16)
  ctx.buf = arm64_emit32(ctx.buf, arm64_b(0))
  ctx.fixups = ctx.fixups.push({
    kind: "b",
    cond_code: 0,
    fixup_offset: 0,
    target_id: 1,
    target_name: "bb_1"
  })

  @! Emit 3 padding NOPs (offsets 4, 8, 12)
  ctx.buf = arm64_emit32(ctx.buf, arm64_nop())
  ctx.buf = arm64_emit32(ctx.buf, arm64_nop())
  ctx.buf = arm64_emit32(ctx.buf, arm64_nop())

  @! Define Block 1 at offset 16
  ctx.block_offsets = arm64_map_set(ctx.block_offsets, "1", 16)

  @! Emit backward conditional branch fixup at offset 16 targeting block 0 (at offset 0)
  ctx.buf = arm64_emit32(ctx.buf, arm64_b_cond(1, 0))
  ctx.fixups = ctx.fixups.push({
    kind: "b_cond",
    cond_code: 1,
    fixup_offset: 16,
    target_id: 0,
    target_name: "bb_0"
  })
  ctx.block_offsets = arm64_map_set(ctx.block_offsets, "0", 0)

  @! Emit BL call fixup at offset 20 targeting function "helper_fn" at offset 40
  ctx.buf = arm64_emit32(ctx.buf, arm64_bl(0))
  ctx.fixups = ctx.fixups.push({
    kind: "bl",
    cond_code: 0,
    fixup_offset: 20,
    target_id: -1,
    target_name: "helper_fn"
  })
  ctx.fn_offsets = arm64_map_set(ctx.fn_offsets, "helper_fn", 40)

  @! Resolve all fixups
  ctx = arm64_resolve_fixups(ctx)

  @! Check Forward B fixup at offset 0: target = 16, disp = (16 - 0) / 4 = 4. Expected: arm64_b(4) = 0x14000004 -> [0x04, 0x00, 0x00, 0x14]
  assert_bytes_4(state, ctx.buf, 0, 0x04, 0x00, 0x00, 0x14, "T3.1_01", "Forward B fixup resolved to disp +4 (0x14000004)")

  @! Check Backward B.cond fixup at offset 16: target = 0, disp = (0 - 16) / 4 = -4. Expected: arm64_b_cond(1, -4) = 0x54FFFF81 -> [0x81, 0xFF, 0xFF, 0x54]
  assert_bytes_4(state, ctx.buf, 16, 0x81, 0xFF, 0xFF, 0x54, "T3.1_02", "Backward B.NE fixup resolved to disp -4 (0x54FFFF81)")

  @! Check BL call fixup at offset 20: target = 40, disp = (40 - 20) / 4 = 5. Expected: arm64_bl(5) = 0x94000005 -> [0x05, 0x00, 0x00, 0x94]
  assert_bytes_4(state, ctx.buf, 20, 0x05, 0x00, 0x00, 0x94, "T3.1_03", "Function call BL fixup resolved to disp +5 (0x94000005)")
@end

@! ============================================================================
@! 5. TIER 4: FULL E2E COMPILATION OF SAMPLE MAYA FUNCTIONS
@! ============================================================================

@! E2E Case 1: Comprehensive Arithmetic & Remainder Pipeline
@fn test_tier4_case1_arithmetic_pipeline(state)
  println("\n▶ E2E Case 1: Arithmetic & Remainder Pipeline (ADD, SUB, MUL, SDIV, SREM/MSUB)")

  fn_math = ir_function_new("math_pipeline", ["a", "b", "c", "d", "e", "f"], ir_type_i64())
  blk0 = fn_math.blocks[0]

  @! %v10 = a + b
  inst_add = ir_inst_add("%v10", ir_val_vreg(0, ir_type_i64(), ""), ir_val_vreg(1, ir_type_i64(), ""), ir_type_i64())
  blk0.instructions = blk0.instructions.push(inst_add)

  @! %v11 = %v10 - c
  inst_sub = ir_inst_sub("%v11", ir_val_vreg(10, ir_type_i64(), ""), ir_val_vreg(2, ir_type_i64(), ""), ir_type_i64())
  blk0.instructions = blk0.instructions.push(inst_sub)

  @! %v12 = %v11 * d
  inst_mul = ir_inst_mul("%v12", ir_val_vreg(11, ir_type_i64(), ""), ir_val_vreg(3, ir_type_i64(), ""), ir_type_i64())
  blk0.instructions = blk0.instructions.push(inst_mul)

  @! %v13 = %v12 / e
  inst_div = ir_inst_div("%v13", ir_val_vreg(12, ir_type_i64(), ""), ir_val_vreg(4, ir_type_i64(), ""), ir_type_i64())
  blk0.instructions = blk0.instructions.push(inst_div)

  @! %v14 = %v13 % f (SREM lowering emits SDIV + MSUB)
  inst_mod = ir_inst_mod("%v14", ir_val_vreg(13, ir_type_i64(), ""), ir_val_vreg(5, ir_type_i64(), ""), ir_type_i64())
  blk0.instructions = blk0.instructions.push(inst_mod)

  @! RET %v14
  inst_ret = ir_inst_ret(ir_val_vreg(14, ir_type_i64(), ""), ir_type_i64())
  blk0.instructions = blk0.instructions.push(inst_ret)

  fn_math.blocks = [blk0]
  mod = ir_module_new("mod_math")
  mod.functions = [fn_math]

  res = arm64_codegen_module(mod)
  assert_true(state, res.text_bytes.len() > 0, "T4.1_01", "Machine code generated for math pipeline")
  assert_eq_int(state, res.text_bytes.len() % 4, 0, "T4.1_02", "Instruction stream aligned to 4 bytes")
  assert_eq_str(state, res.symbols[0], "math_pipeline", "T4.1_03", "Symbol table records 'math_pipeline'")

  @! Verify Prologue at function entry: STP X29, X30, [SP, #-16]! -> [0xFD, 0x7B, 0xBF, 0xA9]
  assert_eq_int(state, res.text_bytes[0], 0xFD, "T4.1_04", "Function entry begins with STP byte 0")
  assert_eq_int(state, res.text_bytes[1], 0x7B, "T4.1_05", "Function entry begins with STP byte 1")
  assert_eq_int(state, res.text_bytes[2], 0xBF, "T4.1_06", "Function entry begins with STP byte 2")
  assert_eq_int(state, res.text_bytes[3], 0xA9, "T4.1_07", "Function entry begins with STP byte 3")

  @! Verify Epilogue at end: RET -> [0xC0, 0x03, 0x5F, 0xD6]
  last_idx = res.text_bytes.len() - 4
  assert_eq_int(state, res.text_bytes[last_idx], 0xC0, "T4.1_08", "Function ends with RET byte 0")
  assert_eq_int(state, res.text_bytes[last_idx + 1], 0x03, "T4.1_09", "Function ends with RET byte 1")
  assert_eq_int(state, res.text_bytes[last_idx + 2], 0x5F, "T4.1_10", "Function ends with RET byte 2")
  assert_eq_int(state, res.text_bytes[last_idx + 3], 0xD6, "T4.1_11", "Function ends with RET byte 3")
@end

@! E2E Case 2: Conditional Branching & Comparison (CMP, CSET, B.cond, B)
@fn test_tier4_case2_conditional_branching(state)
  println("\n▶ E2E Case 2: Conditional Branching & Control Flow (abs_diff)")

  fn_abs = ir_function_new("abs_diff", ["a", "b"], ir_type_i64())
  
  @! Block 0: entry
  blk0 = {
    id: 0,
    name: "entry",
    instructions: [],
    preds: [],
    succs: [1, 2],
    is_terminated: 1,
    dom: [],
    idom: -1,
    df: [],
    blk_label: "entry"
  }
  @! %v2 = a > b (CMP "gt")
  inst_cmp = ir_inst_cmp("gt", "%v2", ir_val_vreg(0, ir_type_i64(), ""), ir_val_vreg(1, ir_type_i64(), ""), ir_type_bool())
  blk0.instructions = blk0.instructions.push(inst_cmp)
  @! BR_COND %v2 -> then: 1 (bb_then), else: 2 (bb_else)
  inst_brc = ir_inst_br_cond(ir_val_vreg(2, ir_type_bool(), ""), 1, "bb_then", 2, "bb_else")
  blk0.instructions = blk0.instructions.push(inst_brc)

  @! Block 1: then (a - b)
  blk1 = {
    id: 1,
    name: "bb_then",
    instructions: [],
    preds: [0],
    succs: [3],
    is_terminated: 1,
    dom: [],
    idom: 0,
    df: [],
    blk_label: "bb_then"
  }
  inst_sub1 = ir_inst_sub("%v3", ir_val_vreg(0, ir_type_i64(), ""), ir_val_vreg(1, ir_type_i64(), ""), ir_type_i64())
  blk1.instructions = blk1.instructions.push(inst_sub1)
  inst_br_merge1 = ir_inst_br(3, "bb_merge")
  blk1.instructions = blk1.instructions.push(inst_br_merge1)

  @! Block 2: else (b - a)
  blk2 = {
    id: 2,
    name: "bb_else",
    instructions: [],
    preds: [0],
    succs: [3],
    is_terminated: 1,
    dom: [],
    idom: 0,
    df: [],
    blk_label: "bb_else"
  }
  inst_sub2 = ir_inst_sub("%v3", ir_val_vreg(1, ir_type_i64(), ""), ir_val_vreg(0, ir_type_i64(), ""), ir_type_i64())
  blk2.instructions = blk2.instructions.push(inst_sub2)
  inst_br_merge2 = ir_inst_br(3, "bb_merge")
  blk2.instructions = blk2.instructions.push(inst_br_merge2)

  @! Block 3: merge (return %v3)
  blk3 = {
    id: 3,
    name: "bb_merge",
    instructions: [],
    preds: [1, 2],
    succs: [],
    is_terminated: 1,
    dom: [],
    idom: 0,
    df: [],
    blk_label: "bb_merge"
  }
  inst_ret = ir_inst_ret(ir_val_vreg(3, ir_type_i64(), ""), ir_type_i64())
  blk3.instructions = blk3.instructions.push(inst_ret)

  fn_abs.blocks = [blk0, blk1, blk2, blk3]
  mod = ir_module_new("mod_abs")
  mod.functions = [fn_abs]

  res = arm64_codegen_module(mod)
  assert_true(state, res.text_bytes.len() > 0, "T4.2_01", "Generated ARM64 code for conditional branch function")
  assert_eq_int(state, res.text_bytes.len() % 4, 0, "T4.2_02", "Instruction stream length is multiple of 4")
@end

@! E2E Case 3: Loop / Iterative Factorial with Backward Jump
@fn test_tier4_case3_iterative_loop(state)
  println("\n▶ E2E Case 3: Iterative Loop with Backward Jump (loop_factorial)")

  fn_loop = ir_function_new("loop_factorial", ["n"], ir_type_i64())

  @! Block 0: entry -> alloca acc, store 1, store n, br -> loop_header (1)
  blk0 = {
    id: 0,
    name: "entry",
    instructions: [],
    preds: [],
    succs: [1],
    is_terminated: 1,
    dom: [],
    idom: -1,
    df: [],
    blk_label: "entry"
  }
  blk0.instructions = blk0.instructions.push(ir_inst_alloca("%v_acc", ir_type_i64(), 8, "acc"))
  blk0.instructions = blk0.instructions.push(ir_inst_store(ir_val_const_int(1, ir_type_i64()), ir_val_vreg(10, ir_type_ptr(ir_type_i64()), "acc"), ir_type_i64()))
  blk0.instructions = blk0.instructions.push(ir_inst_br(1, "loop_header"))

  @! Block 1: loop_header -> load n, cmp n > 1, br_cond -> body (2), exit (3)
  blk1 = {
    id: 1,
    name: "loop_header",
    instructions: [],
    preds: [0, 2],
    succs: [2, 3],
    is_terminated: 1,
    dom: [],
    idom: 0,
    df: [],
    blk_label: "loop_header"
  }
  blk1.instructions = blk1.instructions.push(ir_inst_cmp("gt", "%v_cond", ir_val_vreg(0, ir_type_i64(), "n"), ir_val_const_int(1, ir_type_i64()), ir_type_bool()))
  blk1.instructions = blk1.instructions.push(ir_inst_br_cond(ir_val_vreg(11, ir_type_bool(), "cond"), 2, "loop_body", 3, "loop_exit"))

  @! Block 2: loop_body -> acc = acc * n, n = n - 1, br -> loop_header (1) (BACKWARD JUMP!)
  blk2 = {
    id: 2,
    name: "loop_body",
    instructions: [],
    preds: [1],
    succs: [1],
    is_terminated: 1,
    dom: [],
    idom: 1,
    df: [],
    blk_label: "loop_body"
  }
  blk2.instructions = blk2.instructions.push(ir_inst_load("%v_acc_val", ir_val_vreg(10, ir_type_ptr(ir_type_i64()), "acc"), ir_type_i64()))
  blk2.instructions = blk2.instructions.push(ir_inst_mul("%v_new_acc", ir_val_vreg(12, ir_type_i64(), "acc_val"), ir_val_vreg(0, ir_type_i64(), "n"), ir_type_i64()))
  blk2.instructions = blk2.instructions.push(ir_inst_store(ir_val_vreg(13, ir_type_i64(), "new_acc"), ir_val_vreg(10, ir_type_ptr(ir_type_i64()), "acc"), ir_type_i64()))
  blk2.instructions = blk2.instructions.push(ir_inst_sub("%v0", ir_val_vreg(0, ir_type_i64(), "n"), ir_val_const_int(1, ir_type_i64()), ir_type_i64()))
  blk2.instructions = blk2.instructions.push(ir_inst_br(1, "loop_header"))

  @! Block 3: loop_exit -> load acc, ret acc
  blk3 = {
    id: 3,
    name: "loop_exit",
    instructions: [],
    preds: [1],
    succs: [],
    is_terminated: 1,
    dom: [],
    idom: 1,
    df: [],
    blk_label: "loop_exit"
  }
  blk3.instructions = blk3.instructions.push(ir_inst_load("%v_final_acc", ir_val_vreg(10, ir_type_ptr(ir_type_i64()), "acc"), ir_type_i64()))
  blk3.instructions = blk3.instructions.push(ir_inst_ret(ir_val_vreg(14, ir_type_i64(), "final_acc"), ir_type_i64()))

  fn_loop.blocks = [blk0, blk1, blk2, blk3]
  mod = ir_module_new("mod_loop")
  mod.functions = [fn_loop]

  res = arm64_codegen_module(mod)
  assert_true(state, res.text_bytes.len() > 0, "T4.3_01", "Generated ARM64 code for iterative loop with backward branch")
  assert_eq_int(state, res.text_bytes.len() % 4, 0, "T4.3_02", "Instruction stream length is aligned to 4 bytes")
@end

@! E2E Case 4: Memory Operations & Array Indexing (ALLOCA, STORE, LOAD, GEP)
@fn test_tier4_case4_memory_and_gep(state)
  println("\n▶ E2E Case 4: Memory Operations & Struct/Array GEP (mem_vector)")

  fn_mem = ir_function_new("mem_vector", ["base_idx"], ir_type_i64())
  blk0 = fn_mem.blocks[0]

  @! %v10 = alloca 64 bytes array
  blk0.instructions = blk0.instructions.push(ir_inst_alloca("%v10", ir_type_i64(), 64, "buf"))

  @! %v11 = gep %v10, index 0, stride 8
  blk0.instructions = blk0.instructions.push(ir_inst_gep("%v11", ir_val_vreg(10, ir_type_ptr(ir_type_i64()), "buf"), ir_val_const_int(0, ir_type_i64()), ir_type_i64(), 8))
  @! store 42 -> %v11
  blk0.instructions = blk0.instructions.push(ir_inst_store(ir_val_const_int(42, ir_type_i64()), ir_val_vreg(11, ir_type_ptr(ir_type_i64()), ""), ir_type_i64()))

  @! %v12 = gep %v10, index base_idx (%v0), stride 8
  blk0.instructions = blk0.instructions.push(ir_inst_gep("%v12", ir_val_vreg(10, ir_type_ptr(ir_type_i64()), "buf"), ir_val_vreg(0, ir_type_i64(), "base_idx"), ir_type_i64(), 8))
  @! store 99 -> %v12
  blk0.instructions = blk0.instructions.push(ir_inst_store(ir_val_const_int(99, ir_type_i64()), ir_val_vreg(12, ir_type_ptr(ir_type_i64()), ""), ir_type_i64()))

  @! %v13 = load from %v11
  blk0.instructions = blk0.instructions.push(ir_inst_load("%v13", ir_val_vreg(11, ir_type_ptr(ir_type_i64()), ""), ir_type_i64()))
  @! %v14 = load from %v12
  blk0.instructions = blk0.instructions.push(ir_inst_load("%v14", ir_val_vreg(12, ir_type_ptr(ir_type_i64()), ""), ir_type_i64()))

  @! %v15 = %v13 + %v14
  blk0.instructions = blk0.instructions.push(ir_inst_add("%v15", ir_val_vreg(13, ir_type_i64(), ""), ir_val_vreg(14, ir_type_i64(), ""), ir_type_i64()))
  @! ret %v15
  blk0.instructions = blk0.instructions.push(ir_inst_ret(ir_val_vreg(15, ir_type_i64(), ""), ir_type_i64()))

  fn_mem.blocks = [blk0]
  mod = ir_module_new("mod_mem")
  mod.functions = [fn_mem]

  res = arm64_codegen_module(mod)
  assert_true(state, res.text_bytes.len() > 0, "T4.4_01", "Generated ARM64 code for memory and GEP operations")
  assert_eq_int(state, res.text_bytes.len() % 4, 0, "T4.4_02", "Instruction stream length is aligned to 4 bytes")
@end

@! E2E Case 5: Direct Linux AArch64 Syscall Gateway (SYSCALL)
@fn test_tier4_case5_syscall_gateway(state)
  println("\n▶ E2E Case 5: Direct Linux AArch64 Syscall Gateway (sys_write_exit)")

  fn_sys = ir_function_new("sys_write_exit", ["fd", "buf_ptr", "count"], ir_type_i64())
  blk0 = fn_sys.blocks[0]

  @! %v10 = syscall 64 (sys_write), args: [fd (%v0), buf_ptr (%v1), count (%v2)]
  sys_write_inst = ir_inst_syscall("%v10", ir_val_const_int(64, ir_type_i64()), [ir_val_vreg(0, ir_type_i64(), ""), ir_val_vreg(1, ir_type_i64(), ""), ir_val_vreg(2, ir_type_i64(), "")], ir_type_i64())
  blk0.instructions = blk0.instructions.push(sys_write_inst)

  @! %v11 = syscall 93 (sys_exit), args: [0]
  sys_exit_inst = ir_inst_syscall("%v11", ir_val_const_int(93, ir_type_i64()), [ir_val_const_int(0, ir_type_i64())], ir_type_i64())
  blk0.instructions = blk0.instructions.push(sys_exit_inst)

  @! ret %v10
  blk0.instructions = blk0.instructions.push(ir_inst_ret(ir_val_vreg(10, ir_type_i64(), ""), ir_type_i64()))

  fn_sys.blocks = [blk0]
  mod = ir_module_new("mod_syscall")
  mod.functions = [fn_sys]

  res = arm64_codegen_module(mod)
  assert_true(state, res.text_bytes.len() > 0, "T4.5_01", "Generated ARM64 code for Linux AArch64 syscall gateway")
  assert_eq_int(state, res.text_bytes.len() % 4, 0, "T4.5_02", "Instruction stream length is aligned to 4 bytes")

  @! Find SVC instruction opcode in emitted bytes (0x01, 0x00, 0x00, 0xD4)
  svc_count = 0
  i = 0
  @while i + 3 < res.text_bytes.len()
    @if res.text_bytes[i] == 0x01 && res.text_bytes[i + 1] == 0x00 && res.text_bytes[i + 2] == 0x00 && res.text_bytes[i + 3] == 0xD4
      svc_count = svc_count + 1
    @end
    i = i + 4
  @end
  assert_eq_int(state, svc_count, 2, "T4.5_03", "Emitted exactly 2 SVC #0 (0xD4000001) instructions for syscalls")
@end

@! E2E Case 6: Multi-Function Module with Inter-Function Calls & Symbol Fixups
@fn test_tier4_case6_multi_function_module(state)
  println("\n▶ E2E Case 6: Multi-Function Module & Inter-Function BL Call (multi_fn)")

  @! Function 1: helper_calc(x, y) -> returns (x * y) + 1
  fn_helper = ir_function_new("helper_calc", ["x", "y"], ir_type_i64())
  h_blk0 = fn_helper.blocks[0]
  h_blk0.instructions = h_blk0.instructions.push(ir_inst_mul("%v10", ir_val_vreg(0, ir_type_i64(), ""), ir_val_vreg(1, ir_type_i64(), ""), ir_type_i64()))
  h_blk0.instructions = h_blk0.instructions.push(ir_inst_add("%v11", ir_val_vreg(10, ir_type_i64(), ""), ir_val_const_int(1, ir_type_i64()), ir_type_i64()))
  h_blk0.instructions = h_blk0.instructions.push(ir_inst_ret(ir_val_vreg(11, ir_type_i64(), ""), ir_type_i64()))
  fn_helper.blocks = [h_blk0]

  @! Function 2: main() -> calls helper_calc(5, 10), returns result
  fn_main = ir_function_new("main", [], ir_type_i64())
  m_blk0 = fn_main.blocks[0]
  call_inst = ir_inst_call("%v0", "helper_calc", [ir_val_const_int(5, ir_type_i64()), ir_val_const_int(10, ir_type_i64())], ir_type_i64())
  m_blk0.instructions = m_blk0.instructions.push(call_inst)
  m_blk0.instructions = m_blk0.instructions.push(ir_inst_ret(ir_val_vreg(0, ir_type_i64(), ""), ir_type_i64()))
  fn_main.blocks = [m_blk0]

  mod = ir_module_new("mod_multi_fn")
  mod.functions = [fn_helper, fn_main]

  res = arm64_codegen_module(mod)
  assert_true(state, res.text_bytes.len() > 0, "T4.6_01", "Generated ARM64 code for multi-function module")
  assert_eq_int(state, res.text_bytes.len() % 4, 0, "T4.6_02", "Instruction stream length is aligned to 4 bytes")
  assert_eq_int(state, res.symbols.len(), 2, "T4.6_03", "Module exports exactly 2 symbols")
  assert_eq_str(state, res.symbols[0], "helper_calc", "T4.6_04", "Symbol 0 is 'helper_calc'")
  assert_eq_str(state, res.symbols[1], "main", "T4.6_05", "Symbol 1 is 'main'")
  assert_true(state, res.entry_offset > 0, "T4.6_06", "Main entry point offset is recorded (> 0)")
@end

@! ============================================================================
@! 6. MAIN TEST RUNNER
@! ============================================================================

@fn main()
  println("================================================================================")
  println("      MAYA UNIVERSAL ARCHITECTURE: ARM64 CODEGEN FULL E2E SUITE                 ")
  println("================================================================================")

  state = test_state_new()

  @! Run all test tiers
  test_tier1_arm64_abi_constants(state)
  test_tier2_memory_opcodes_and_bytes(state)
  test_tier2_arithmetic_opcodes_and_bytes(state)
  test_tier2_bitwise_and_unary_opcodes(state)
  test_tier2_call_syscall_branch_opcodes(state)
  test_tier3_fixup_resolution(state)
  test_tier4_case1_arithmetic_pipeline(state)
  test_tier4_case2_conditional_branching(state)
  test_tier4_case3_iterative_loop(state)
  test_tier4_case4_memory_and_gep(state)
  test_tier4_case5_syscall_gateway(state)
  test_tier4_case6_multi_function_module(state)

  println("\n================================================================================")
  println("ARM64 CODEGEN E2E TEST SUMMARY:")
  println("  Total assertions : " + state.total.to_str())
  println("  Passed assertions: " + state.passed.to_str())
  println("  Failed assertions: " + state.failed.to_str())
  println("================================================================================")

  @if state.failed == 0
    println("🎉 ALL ARM64 BACKEND CODE GENERATION E2E TESTS PASSED CLEANLY!")
    return 0
  @else
    println("❌ SOME TESTS FAILED!")
    return 1
  @end
@end
