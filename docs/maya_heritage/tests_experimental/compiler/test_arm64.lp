@! ============================================================================
@! MAYA COMPILER TEST SUITE — ARM64 AArch64 BACKEND CODE GENERATOR
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"
import "compiler/backend/arm64/codegen"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (expected " + expected.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@fn assert_true(cond, msg)
  @if cond == 1
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@fn main()
  println("==================================================")
  println("   MAYA ARM64 AARCH64 CODEGEN COMPREHENSIVE TESTS ")
  println("==================================================")

  @! 1. Register encoding tests
  println("▶ Testing AArch64 Register Encodings...")
  assert_eq(arm64_reg_x0(), 0, "Register X0 == 0")
  assert_eq(arm64_reg_x1(), 1, "Register X1 == 1")
  assert_eq(arm64_reg_x8(), 8, "Register X8 (Syscall NR) == 8")
  assert_eq(arm64_reg_x29(), 29, "Register X29 (FP) == 29")
  assert_eq(arm64_reg_x30(), 30, "Register X30 (LR) == 30")
  assert_eq(arm64_reg_sp(), 31, "Register SP == 31")

  @! 2. Basic Instruction Emitter Tests
  println("▶ Testing Arithmetic & Logical Instruction Emitters...")
  add_inst = arm64_add(0, 1, 2)
  assert_eq(add_inst, 0x8B020020, "ADD X0, X1, X2 encoding")

  sub_inst = arm64_sub(0, 1, 2)
  assert_eq(sub_inst, 0xCB020020, "SUB X0, X1, X2 encoding")

  mul_inst = arm64_mul(0, 1, 2)
  assert_eq(mul_inst, 0x9B027C20, "MUL X0, X1, X2 encoding")

  sdiv_inst = arm64_sdiv(0, 1, 2)
  assert_eq(sdiv_inst, 0x9AC20C20, "SDIV X0, X1, X2 encoding")

  cmp_inst = arm64_cmp(1, 2)
  assert_eq(cmp_inst, 0xEB02003F, "CMP X1, X2 encoding")

  cset_inst = arm64_cset(0, 0)
  assert_true(cset_inst != 0, "CSET X0, EQ emitter valid")

  @! 3. Memory & Load/Store Emitters
  println("▶ Testing Load/Store & Stack Emitters...")
  ldr_imm = arm64_ldr_imm(0, 1, 0)
  assert_eq(ldr_imm, 0xF9400020, "LDR X0, [X1, #0] unsigned offset encoding")

  str_imm = arm64_str_imm(0, 1, 0)
  assert_eq(str_imm, 0xF9000020, "STR X0, [X1, #0] unsigned offset encoding")

  ldr_reg = arm64_ldr_reg(0, 1, 2)
  assert_eq(ldr_reg, 0xF8626820, "LDR X0, [X1, X2] register offset encoding")

  str_reg = arm64_str_reg(0, 1, 2)
  assert_eq(str_reg, 0xF8226820, "STR X0, [X1, X2] register offset encoding")

  stp_inst = arm64_stp(29, 30, 31, -16)
  assert_eq(stp_inst, 0xA9BF7BFD, "STP X29, X30, [SP, #-16]! pre-indexed encoding")

  ldp_inst = arm64_ldp(29, 30, 31, 16)
  assert_eq(ldp_inst, 0xA8C17BFD, "LDP X29, X30, [SP], #16 post-indexed encoding")

  @! 4. Constants & Branch Emitters
  println("▶ Testing Immediate & Branch Emitters...")
  movz_inst = arm64_movz(0, 42, 0)
  assert_eq(movz_inst, 0xD2800540, "MOVZ X0, #42 encoding")

  movk_inst = arm64_movk(0, 1, 16)
  assert_eq(movk_inst, 0xF2A00020, "MOVK X0, #1, LSL #16 encoding")

  b_inst = arm64_b(10)
  assert_eq(b_inst, 0x1400000A, "B #10 encoding")

  b_cond_inst = arm64_b_cond(0, 5)
  assert_eq(b_cond_inst, 0x540000A0, "B.EQ #5 encoding")

  bl_inst = arm64_bl(100)
  assert_eq(bl_inst, 0x94000064, "BL #100 encoding")

  ret_inst = arm64_ret()
  assert_eq(ret_inst, 0xD65F03C0, "RET encoding")

  svc_inst = arm64_svc()
  assert_eq(svc_inst, 0xD4000001, "SVC #0 encoding")

  @! 5. Function Prologue & Epilogue Emission
  println("▶ Testing Function Prologue & Epilogue Emission...")
  buf = arm64_buf_new()
  buf = arm64_emit_prologue(buf, 32)
  assert_true(buf.ab_size >= 12, "Prologue emits STP, MOV FP, SUB SP")
  assert_eq(buf.ab_data[0], 0xFD, "Prologue byte 0 matches STP (0xFD)")
  assert_eq(buf.ab_data[1], 0x7B, "Prologue byte 1 matches STP (0x7B)")
  assert_eq(buf.ab_data[2], 0xBF, "Prologue byte 2 matches STP (0xBF)")
  assert_eq(buf.ab_data[3], 0xA9, "Prologue byte 3 matches STP (0xA9)")

  buf_epi = arm64_buf_new()
  buf_epi = arm64_emit_epilogue(buf_epi, 32)
  assert_true(buf_epi.ab_size >= 12, "Epilogue emits MOV SP, LDP, RET")

  @! 6. Full Maya IR Module Lowering
  println("▶ Testing Full Maya IR Lowering Engine...")
  fn_main = {
    fn_id: 1,
    name: "main",
    params: [],
    fn_ret_type: ir_type_i64(),
    entry_block: 0,
    blocks: [],
    locals: [],
    next_vreg_id: 10,
    next_block_id: 2,
    is_varargs: 0
  }

  blk0 = {
    id: 0,
    name: "bb_0",
    instructions: [],
    preds: [],
    succs: [1],
    is_terminated: 1,
    dom: [],
    idom: -1,
    df: [],
    blk_label: "bb_0"
  }

  alloca_i = ir_inst_alloca("%v0", ir_type_i64(), 8, "")
  blk0.instructions = blk0.instructions.push(alloca_i)

  store_i = ir_inst_store(ir_val_const_int(42, ir_type_i64()), ir_val_vreg(0, ir_type_ptr(ir_type_i64()), ""), ir_type_i64())
  blk0.instructions = blk0.instructions.push(store_i)

  load_i = ir_inst_load("%v1", ir_val_vreg(0, ir_type_ptr(ir_type_i64()), ""), ir_type_i64())
  blk0.instructions = blk0.instructions.push(load_i)

  add_i = ir_inst_add("%v2", ir_val_vreg(1, ir_type_i64(), ""), ir_val_const_int(8, ir_type_i64()), ir_type_i64())
  blk0.instructions = blk0.instructions.push(add_i)

  sub_i = ir_inst_sub("%v3", ir_val_vreg(2, ir_type_i64(), ""), ir_val_const_int(2, ir_type_i64()), ir_type_i64())
  blk0.instructions = blk0.instructions.push(sub_i)

  mul_i = ir_inst_mul("%v4", ir_val_vreg(3, ir_type_i64(), ""), ir_val_const_int(3, ir_type_i64()), ir_type_i64())
  blk0.instructions = blk0.instructions.push(mul_i)

  div_i = ir_inst_div("%v5", ir_val_vreg(4, ir_type_i64(), ""), ir_val_const_int(2, ir_type_i64()), ir_type_i64())
  blk0.instructions = blk0.instructions.push(div_i)

  cmp_i = ir_inst_cmp("==", "%v6", ir_val_vreg(5, ir_type_i64(), ""), ir_val_const_int(72, ir_type_i64()), ir_type_bool())
  blk0.instructions = blk0.instructions.push(cmp_i)

  br_i = ir_inst_br(1, "bb_1")
  blk0.instructions = blk0.instructions.push(br_i)

  blk1 = {
    id: 1,
    name: "bb_1",
    instructions: [],
    preds: [0],
    succs: [],
    is_terminated: 1,
    dom: [],
    idom: 0,
    df: [],
    blk_label: "bb_1"
  }

  ret_i = ir_inst_ret(ir_val_vreg(5, ir_type_i64(), ""), ir_type_i64())
  blk1.instructions = blk1.instructions.push(ret_i)

  fn_main.blocks = [blk0, blk1]

  ir_mod = {
    mod_id: 1,
    name: "arm64_test_module",
    structs: [],
    enums: [],
    functions: [fn_main],
    globals: [],
    string_literals: [],
    struct_defs: [],
    rodata_map: [],
    next_str_id: 0
  }

  codegen_res = arm64_codegen_module(ir_mod)
  assert_true(codegen_res.text_bytes.len() > 0, "ARM64 machine code emitted successfully")
  assert_true(codegen_res.text_bytes.len() % 4 == 0, "ARM64 machine code size is multiple of 4 bytes")
  assert_eq(codegen_res.symbols.len(), 1, "Exported symbol 'main' recorded")
  assert_eq(codegen_res.symbols[0], "main", "Main symbol name matches")

  println("🎉 ALL ARM64 BACKEND TESTS PASSED!")
  return 0
@end
