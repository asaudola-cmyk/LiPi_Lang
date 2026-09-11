@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — RISC-V 64 (RV64GC) CODEGEN TEST SUITE
@! File: tests/backend/test_riscv64_codegen.maya
@! ============================================================================

import "universe/core/collections"
import "compiler/backend/riscv64/codegen"

@fn assert_true(cond, msg)
  @if cond == 0 || cond == false
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🪐 MAYA NATIVE RISC-V 64-BIT (RV64GC) CODE GENERATOR TEST SUITE 🪐")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! SECTION 1: RV64I / RV64M Arithmetic Instruction Encoders
  println("▶ Section 1: R-Type & I-Type Arithmetic Opcodes (ADD, SUB, MUL, ADDI)...")
  total_tests = total_tests + 1
  @! ADD x10, x11, x12 -> opcode 0x33 (51), rd=10 (a0), funct3=0, rs1=11 (a1), rs2=12 (a2), funct7=0
  inst_add = rv64_add(10, 11, 12)
  ok1 = assert_eq_int(inst_add.bytes.len(), 4, "ADD instruction is 4 bytes")
  ok2 = assert_eq_int(inst_add.bytes[0], 51, "ADD byte 0 matches opcode 0x33 (51)")

  @! ADDI x10, x10, 42 -> opcode 0x13 (19), rd=10, rs1=10, imm=42
  inst_addi = rv64_addi(10, 10, 42)
  ok3 = assert_eq_int(inst_addi.bytes.len(), 4, "ADDI instruction is 4 bytes")
  
  @! MUL x10, x11, x12 -> opcode 0x33, funct7=1
  inst_mul = rv64_mul(10, 11, 12)
  ok4 = assert_eq_int(inst_mul.bytes.len(), 4, "MUL instruction is 4 bytes")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] R-Type and I-Type instruction encoding verified")
  @end

  @! SECTION 2: Upper Immediate & Load/Store Encoders (LUI, LD, SD)
  println("▶ Section 2: Memory Access (LD, SD) & Upper Immediate (LUI)...")
  total_tests = total_tests + 1
  @! LUI x10, 0x12345
  inst_lui = rv64_lui(10, 74565)
  ok1 = assert_eq_int(inst_lui.bytes[0], 55, "LUI byte 0 matches opcode 0x37 (55)")

  @! SD x1, 24(x2) -> Save return address (x1) to stack sp+24 (x2)
  inst_sd = rv64_sd(1, 2, 24)
  ok2 = assert_eq_int(inst_sd.bytes[0], 35, "SD byte 0 matches opcode 0x23 (35)")

  @! LD x1, 24(x2) -> Load return address (x1) from stack sp+24 (x2)
  inst_ld = rv64_ld(1, 2, 24)
  ok3 = assert_eq_int(inst_ld.bytes[0], 131, "LD byte 0 matches opcode 0x03 (0x83 = 131)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Load/Store doubleword & upper immediate encoding verified")
  @end

  @! SECTION 3: Control Flow & System Call Encoders (JALR, RET, ECALL)
  println("▶ Section 3: Control Flow & System Calls (RET, ECALL)...")
  total_tests = total_tests + 1
  inst_ret = rv64_ret()
  ok1 = assert_eq_int(inst_ret.bytes[0], 103, "RET opcode matches JALR 0x67 (103)")
  
  inst_ecall = rv64_ecall()
  ok2 = assert_eq_int(inst_ecall.bytes[0], 115, "ECALL opcode matches SYSTEM 0x73 (115)")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] RET and ECALL instruction encoding verified")
  @end

  @! SECTION 4: Function Compilation & Machine Code Emission
  println("▶ Section 4: Function Compilation with Standard Calling Convention...")
  total_tests = total_tests + 1
  body = [
    rv64_addi(10, 10, 100), @! addi a0, a0, 100
    rv64_mul(10, 10, 11)     @! mul a0, a0, a1
  ]
  fn_obj = rv64_compile_function("maya_compute", body)
  @! 4 prologue + 2 body + 4 epilogue = 10 instructions
  ok1 = assert_eq_int(fn_obj.instructions.len(), 10, "Compiled function contains exactly 10 instructions")
  
  machine_code = rv64_emit_machine_code(fn_obj)
  ok2 = assert_eq_int(machine_code.len(), 40, "Emitted RV64 machine code binary is exactly 40 bytes")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Full RV64GC function machine code generation verified")
  @end

  println("=================================================================")
  println("📊 RISC-V 64 CODEGEN TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")
  @if passed_tests == total_tests
    println("🎉 ALL 4 NATIVE RISC-V 64 TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME RISC-V 64 TESTS FAILED")
    return 1
  @end
@end
