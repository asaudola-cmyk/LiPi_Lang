@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — NATIVE RISC-V 64-BIT (RV64GC) CODE GENERATOR
@! Module: compiler/backend/riscv64/codegen.maya
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! Features: RV64I/RV64M Instruction Encoders (R/I/S/B/U/J-Types), Register
@! Allocations (x0-x31), Prologue/Epilogue, System Calls (ECALL) & Machine Code Emitter
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ============================================================================
@! 1. RISC-V REGISTER DEFINITIONS
@! ============================================================================

@struct RV64Instruction
  opcode: i64
  bytes: array
  disasm: string
@end

@struct RV64Function
  name: string
  instructions: array
  stack_size: i64
@end

@! ============================================================================
@! 2. BIT MANIPULATION & INSTRUCTION ENCODING HELPERS
@! ============================================================================

@fn rv64_encode_r(opcode, rd, funct3, rs1, rs2, funct7, disasm_str)
  @! Instruction format: [funct7:7][rs2:5][rs1:5][funct3:3][rd:5][opcode:7]
  inst_word = 0
  inst_word = inst_word + (opcode % 128)
  inst_word = inst_word + ((rd % 32) * 128)
  inst_word = inst_word + ((funct3 % 8) * 4096)
  inst_word = inst_word + ((rs1 % 32) * 32768)
  inst_word = inst_word + ((rs2 % 32) * 1048576)
  inst_word = inst_word + ((funct7 % 128) * 33554432)

  b0 = inst_word % 256
  b1 = (inst_word / 256) % 256
  b2 = (inst_word / 65536) % 256
  b3 = (inst_word / 16777216) % 256

  return {
    opcode: opcode,
    bytes: [b0, b1, b2, b3],
    disasm: disasm_str
  }
@end

@fn rv64_encode_i(opcode, rd, funct3, rs1, imm, disasm_str)
  @! Instruction format: [imm[11:0]:12][rs1:5][funct3:3][rd:5][opcode:7]
  imm12 = imm % 4096
  @if imm12 < 0 imm12 = imm12 + 4096 @end

  inst_word = 0
  inst_word = inst_word + (opcode % 128)
  inst_word = inst_word + ((rd % 32) * 128)
  inst_word = inst_word + ((funct3 % 8) * 4096)
  inst_word = inst_word + ((rs1 % 32) * 32768)
  inst_word = inst_word + (imm12 * 1048576)

  b0 = inst_word % 256
  b1 = (inst_word / 256) % 256
  b2 = (inst_word / 65536) % 256
  b3 = (inst_word / 16777216) % 256

  return {
    opcode: opcode,
    bytes: [b0, b1, b2, b3],
    disasm: disasm_str
  }
@end

@fn rv64_encode_s(opcode, funct3, rs1, rs2, imm, disasm_str)
  @! Instruction format: [imm[11:5]:7][rs2:5][rs1:5][funct3:3][imm[4:0]:5][opcode:7]
  imm12 = imm % 4096
  @if imm12 < 0 imm12 = imm12 + 4096 @end
  
  imm_low5 = imm12 % 32
  imm_high7 = (imm12 / 32) % 128

  inst_word = 0
  inst_word = inst_word + (opcode % 128)
  inst_word = inst_word + (imm_low5 * 128)
  inst_word = inst_word + ((funct3 % 8) * 4096)
  inst_word = inst_word + ((rs1 % 32) * 32768)
  inst_word = inst_word + ((rs2 % 32) * 1048576)
  inst_word = inst_word + (imm_high7 * 33554432)

  b0 = inst_word % 256
  b1 = (inst_word / 256) % 256
  b2 = (inst_word / 65536) % 256
  b3 = (inst_word / 16777216) % 256

  return {
    opcode: opcode,
    bytes: [b0, b1, b2, b3],
    disasm: disasm_str
  }
@end

@fn rv64_encode_u(opcode, rd, imm20, disasm_str)
  @! Instruction format: [imm[31:12]:20][rd:5][opcode:7]
  uimm = imm20 % 1048576
  @if uimm < 0 uimm = uimm + 1048576 @end

  inst_word = 0
  inst_word = inst_word + (opcode % 128)
  inst_word = inst_word + ((rd % 32) * 128)
  inst_word = inst_word + (uimm * 4096)

  b0 = inst_word % 256
  b1 = (inst_word / 256) % 256
  b2 = (inst_word / 65536) % 256
  b3 = (inst_word / 16777216) % 256

  return {
    opcode: opcode,
    bytes: [b0, b1, b2, b3],
    disasm: disasm_str
  }
@end

@! ============================================================================
@! 3. RV64 INSTRUCTION SET EMITTERS
@! ============================================================================

@! Arithmetic & Logic Instructions
@fn rv64_add(rd, rs1, rs2)
  return rv64_encode_r(51, rd, 0, rs1, rs2, 0, "add x" + rd.to_str() + ", x" + rs1.to_str() + ", x" + rs2.to_str())
@end

@fn rv64_sub(rd, rs1, rs2)
  return rv64_encode_r(51, rd, 0, rs1, rs2, 32, "sub x" + rd.to_str() + ", x" + rs1.to_str() + ", x" + rs2.to_str())
@end

@fn rv64_mul(rd, rs1, rs2)
  return rv64_encode_r(51, rd, 0, rs1, rs2, 1, "mul x" + rd.to_str() + ", x" + rs1.to_str() + ", x" + rs2.to_str())
@end

@fn rv64_div(rd, rs1, rs2)
  return rv64_encode_r(51, rd, 4, rs1, rs2, 1, "div x" + rd.to_str() + ", x" + rs1.to_str() + ", x" + rs2.to_str())
@end

@fn rv64_addi(rd, rs1, imm)
  return rv64_encode_i(19, rd, 0, rs1, imm, "addi x" + rd.to_str() + ", x" + rs1.to_str() + ", " + imm.to_str())
@end

@fn rv64_lui(rd, imm20)
  return rv64_encode_u(55, rd, imm20, "lui x" + rd.to_str() + ", " + imm20.to_str())
@end

@! Load & Store Instructions (64-bit Doubleword)
@fn rv64_ld(rd, rs1, offset)
  return rv64_encode_i(3, rd, 3, rs1, offset, "ld x" + rd.to_str() + ", " + offset.to_str() + "(x" + rs1.to_str() + ")")
@end

@fn rv64_sd(rs2, rs1, offset)
  return rv64_encode_s(35, 3, rs1, rs2, offset, "sd x" + rs2.to_str() + ", " + offset.to_str() + "(x" + rs1.to_str() + ")")
@end

@! Jumps & System Calls
@fn rv64_jalr(rd, rs1, offset)
  return rv64_encode_i(103, rd, 0, rs1, offset, "jalr x" + rd.to_str() + ", " + offset.to_str() + "(x" + rs1.to_str() + ")")
@end

@fn rv64_ret()
  return rv64_jalr(0, 1, 0) @! jalr zero, 0(ra)
@end

@fn rv64_ecall()
  return rv64_encode_i(115, 0, 0, 0, 0, "ecall")
@end

@! ============================================================================
@! 4. FUNCTION COMPILER & PROLOGUE/EPILOGUE
@! ============================================================================

@fn rv64_compile_function(name, body_instructions)
  insts = []
  
  @! Prologue:
  @! addi sp, sp, -32 (Adjust stack)
  @! sd ra, 24(sp)    (Save return address)
  @! sd s0, 16(sp)    (Save frame pointer)
  @! addi s0, sp, 32  (Set up new frame pointer)
  insts = insts.push(rv64_addi(2, 2, -32))
  insts = insts.push(rv64_sd(1, 2, 24))
  insts = insts.push(rv64_sd(8, 2, 16))
  insts = insts.push(rv64_addi(8, 2, 32))

  @! Body Instructions
  i = 0
  n_body = body_instructions.len()
  @while i < n_body
    insts = insts.push(body_instructions[i])
    i = i + 1
  @end

  @! Epilogue:
  @! ld s0, 16(sp)    (Restore frame pointer)
  @! ld ra, 24(sp)    (Restore return address)
  @! addi sp, sp, 32  (Restore stack)
  @! ret (jalr zero, 0(ra))
  insts = insts.push(rv64_ld(8, 2, 16))
  insts = insts.push(rv64_ld(1, 2, 24))
  insts = insts.push(rv64_addi(2, 2, 32))
  insts = insts.push(rv64_ret())

  return {
    name: name,
    instructions: insts,
    stack_size: 32
  }
@end

@fn rv64_emit_machine_code(fn_obj)
  raw_bytes = []
  i = 0
  n_inst = fn_obj.instructions.len()
  @while i < n_inst
    inst = fn_obj.instructions[i]
    raw_bytes = raw_bytes.push(inst.bytes[0])
    raw_bytes = raw_bytes.push(inst.bytes[1])
    raw_bytes = raw_bytes.push(inst.bytes[2])
    raw_bytes = raw_bytes.push(inst.bytes[3])
    i = i + 1
  @end
  return raw_bytes
@end
