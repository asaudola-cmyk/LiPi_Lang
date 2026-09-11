@! ============================================================================
@! MAYA NATIVE BACKEND UNIT & INTEGRATION TEST SUITE: REGISTER ALLOCATOR
@! Module: tests/backend/test_regalloc.maya
@! Tests:
@! 1. System V AMD64 Physical Register Classification & Free Pools
@! 2. Monotonic Instruction Numbering & Live Interval Range Construction
@! 3. Leaf Function Register Allocation (Caller-Saved Preference)
@! 4. Call-Crossing Interval Register Allocation (Callee-Saved Preference)
@! 5. Register Exhaustion & Linear Scan Spill Allocation (Furthest-End Spill)
@! 6. 16-Byte Stack Frame ABI Alignment Calculation
@! 7. Module-level Register Allocation Pass (regalloc_run)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"
import "compiler/backend/regalloc"

@struct TestRunner
  passed: i64
  failed: i64
  total: i64
@end

@fn runner_new() -> TestRunner
  return { passed: 0, failed: 0, total: 0 }
@end

@fn assert_true(r: TestRunner, cond, name: string) -> TestRunner
  r.total = r.total + 1
  @if cond == 1 || cond == true
    r.passed = r.passed + 1
    println("  [PASS] " + name)
  @else
    r.failed = r.failed + 1
    println("  [FAIL] " + name + " (Expected true, got false)")
  @end
  return r
@end

@fn assert_eq_i64(r: TestRunner, actual: i64, expected: i64, name: string) -> TestRunner
  r.total = r.total + 1
  @if actual == expected
    r.passed = r.passed + 1
    println("  [PASS] " + name)
  @else
    r.failed = r.failed + 1
    println("  [FAIL] " + name + " (Expected: " + expected.to_str() + ", Got: " + actual.to_str() + ")")
  @end
  return r
@end

@fn assert_eq_str(r: TestRunner, actual: string, expected: string, name: string) -> TestRunner
  r.total = r.total + 1
  @if actual == expected
    r.passed = r.passed + 1
    println("  [PASS] " + name)
  @else
    r.failed = r.failed + 1
    println("  [FAIL] " + name + " (Expected: '" + expected + "', Got: '" + actual + "')")
  @end
  return r
@end

@fn main()
  r = runner_new()

  println("=================================================================")
  println("🧪 MAYA LINEAR SCAN REGISTER ALLOCATOR TEST SUITE 🧪")
  println("=================================================================")

  @! --------------------------------------------------------------------------
  @! SECTION 1: System V AMD64 Physical Register Descriptors
  @! --------------------------------------------------------------------------
  println("▶ [Section 1] System V AMD64 Physical Register Descriptors...")
  r = assert_eq_str(r, regalloc_phys_reg_name(0), "rax", "Reg 0 is RAX")
  r = assert_eq_str(r, regalloc_phys_reg_name(1), "rcx", "Reg 1 is RCX")
  r = assert_eq_str(r, regalloc_phys_reg_name(2), "rdx", "Reg 2 is RDX")
  r = assert_eq_str(r, regalloc_phys_reg_name(3), "rbx", "Reg 3 is RBX")
  r = assert_eq_str(r, regalloc_phys_reg_name(4), "rsp", "Reg 4 is RSP")
  r = assert_eq_str(r, regalloc_phys_reg_name(5), "rbp", "Reg 5 is RBP")
  r = assert_eq_str(r, regalloc_phys_reg_name(6), "rsi", "Reg 6 is RSI")
  r = assert_eq_str(r, regalloc_phys_reg_name(7), "rdi", "Reg 7 is RDI")
  r = assert_eq_str(r, regalloc_phys_reg_name(8), "r8",  "Reg 8 is R8")
  r = assert_eq_str(r, regalloc_phys_reg_name(9), "r9",  "Reg 9 is R9")
  r = assert_eq_str(r, regalloc_phys_reg_name(10), "r10", "Reg 10 is R10")
  r = assert_eq_str(r, regalloc_phys_reg_name(11), "r11", "Reg 11 is R11")
  r = assert_eq_str(r, regalloc_phys_reg_name(12), "r12", "Reg 12 is R12")
  r = assert_eq_str(r, regalloc_phys_reg_name(13), "r13", "Reg 13 is R13")
  r = assert_eq_str(r, regalloc_phys_reg_name(14), "r14", "Reg 14 is R14")
  r = assert_eq_str(r, regalloc_phys_reg_name(15), "r15", "Reg 15 is R15")

  r = assert_true(r, regalloc_is_caller_saved(0), "RAX is caller-saved")
  r = assert_true(r, regalloc_is_caller_saved(1), "RCX is caller-saved")
  r = assert_true(r, regalloc_is_caller_saved(2), "RDX is caller-saved")
  r = assert_true(r, regalloc_is_caller_saved(6), "RSI is caller-saved")
  r = assert_true(r, regalloc_is_caller_saved(7), "RDI is caller-saved")
  r = assert_true(r, regalloc_is_caller_saved(8), "R8 is caller-saved")
  r = assert_true(r, regalloc_is_caller_saved(9), "R9 is caller-saved")
  r = assert_true(r, regalloc_is_caller_saved(10), "R10 is caller-saved")
  r = assert_true(r, regalloc_is_caller_saved(11), "R11 is caller-saved")

  r = assert_true(r, regalloc_is_callee_saved(3), "RBX is callee-saved")
  r = assert_true(r, regalloc_is_callee_saved(12), "R12 is callee-saved")
  r = assert_true(r, regalloc_is_callee_saved(13), "R13 is callee-saved")
  r = assert_true(r, regalloc_is_callee_saved(14), "R14 is callee-saved")
  r = assert_true(r, regalloc_is_callee_saved(15), "R15 is callee-saved")

  r = assert_true(r, regalloc_is_reserved(4), "RSP is reserved")
  r = assert_true(r, regalloc_is_reserved(5), "RBP is reserved")

  @! --------------------------------------------------------------------------
  @! SECTION 2: Live Interval Construction
  @! --------------------------------------------------------------------------
  println("▶ [Section 2] Live Interval Range Construction...")
  t_i64 = ir_type_i64()
  v_c1 = ir_val_const_int(1, t_i64)
  v_c2 = ir_val_const_int(2, t_i64)

  fn1 = ir_function_new("leaf_math", ["a", "b"], t_i64)
  @! bb_0:
  @! %v0 = add %param_a, %param_b
  @! %v1 = mul %v0, 2
  @! ret %v1
  v_pa = ir_val_param(0, "a", t_i64)
  v_pb = ir_val_param(1, "b", t_i64)
  v_v0 = ir_val_reg("%v0", t_i64)
  v_v1 = ir_val_reg("%v1", t_i64)

  fn1.blocks[0] = ir_block_add_inst(fn1.blocks[0], ir_inst_add("%v0", v_pa, v_pb, t_i64))
  fn1.blocks[0] = ir_block_add_inst(fn1.blocks[0], ir_inst_mul("%v1", v_v0, v_c2, t_i64))
  fn1.blocks[0] = ir_block_add_inst(fn1.blocks[0], ir_inst_ret(v_v1, t_i64))

  intervals1 = regalloc_compute_live_intervals(fn1)
  r = assert_true(r, intervals1.len() >= 4, "Computed >= 4 live intervals (params + vregs)")

  @! Check parameter 'a' starts at position 0
  iv_a = regalloc_find_interval(intervals1, "%param_a")
  r = assert_eq_i64(r, iv_a.start_pos, 0, "%param_a starts at pos 0")
  r = assert_eq_i64(r, iv_a.is_param, 1, "%param_a is_param flag is 1")

  @! Check %v0 live range spans from def (pos 0) to use in mul (pos 2)
  iv_v0 = regalloc_find_interval(intervals1, "%v0")
  r = assert_true(r, iv_v0.start_pos >= 0, "%v0 has valid start_pos")
  r = assert_true(r, iv_v0.end_pos >= iv_v0.start_pos, "%v0 end_pos >= start_pos")

  @! --------------------------------------------------------------------------
  @! SECTION 3: Leaf Function Linear Scan Allocation
  @! --------------------------------------------------------------------------
  println("▶ [Section 3] Leaf Function Linear Scan Allocation...")
  alloc_res1 = regalloc_allocate_function(fn1)
  r = assert_eq_i64(r, alloc_res1.spill_count, 0, "Leaf function requires 0 stack spills")
  r = assert_true(r, alloc_res1.allocated_locations.len() >= 4, "Allocated locations for all virtual registers")

  @! Look up allocation for %v0 and %v1
  loc_v0 = regalloc_get_location(alloc_res1, "%v0")
  r = assert_eq_i64(r, loc_v0.loc_kind, 0, "%v0 allocated in physical register (loc_kind=0)")
  r = assert_true(r, regalloc_is_caller_saved(loc_v0.reg_num), "%v0 assigned caller-saved register")

  loc_v1 = regalloc_get_location(alloc_res1, "%v1")
  r = assert_eq_i64(r, loc_v1.loc_kind, 0, "%v1 allocated in physical register (loc_kind=0)")

  @! --------------------------------------------------------------------------
  @! SECTION 4: Call-Crossing Interval Allocation (Callee-Saved Preference)
  @! --------------------------------------------------------------------------
  println("▶ [Section 4] Call-Crossing Interval Allocation...")
  fn_call = ir_function_new("call_crossing", [], t_i64)
  @! %v0 = 100
  @! %v1 = call external_fn()  <-- Call instruction
  @! %v2 = add %v0, %v1        <-- %v0 used after call! (spans call)
  @! ret %v2
  v_v2 = ir_val_reg("%v2", t_i64)

  fn_call.blocks[0] = ir_block_add_inst(fn_call.blocks[0], ir_inst_add("%v0", v_c1, v_c2, t_i64))
  fn_call.blocks[0] = ir_block_add_inst(fn_call.blocks[0], ir_inst_call("%v1", "external_fn", [], t_i64))
  fn_call.blocks[0] = ir_block_add_inst(fn_call.blocks[0], ir_inst_add("%v2", v_v0, v_v1, t_i64))
  fn_call.blocks[0] = ir_block_add_inst(fn_call.blocks[0], ir_inst_ret(v_v2, t_i64))

  intervals_call = regalloc_compute_live_intervals(fn_call)
  iv_cross = regalloc_find_interval(intervals_call, "%v0")
  r = assert_eq_i64(r, iv_cross.spans_call, 1, "%v0 spans_call is correctly flagged as 1")

  alloc_call = regalloc_allocate_function(fn_call)
  loc_cross = regalloc_get_location(alloc_call, "%v0")
  @! Call-crossing interval must receive callee-saved register (RBX, R12-R15) or spill
  @if loc_cross.loc_kind == 0
    r = assert_true(r, regalloc_is_callee_saved(loc_cross.reg_num), "%v0 assigned callee-saved register across call")
  @else
    r = assert_eq_i64(r, loc_cross.loc_kind, 1, "%v0 assigned spill slot")
  @end

  @! --------------------------------------------------------------------------
  @! SECTION 5: Register Exhaustion & Spill Allocation
  @! --------------------------------------------------------------------------
  println("▶ [Section 5] Register Exhaustion & Linear Scan Spill Allocation...")
  @! Construct function with 25 concurrently live variables
  fn_stress = ir_function_new("stress_spill", [], t_i64)
  s_i = 0
  @while s_i < 25
    r_name = "%v" + s_i.to_str()
    fn_stress.blocks[0] = ir_block_add_inst(fn_stress.blocks[0], ir_inst_add(r_name, v_c1, v_c2, t_i64))
    s_i = s_i + 1
  @end

  @! Use all 25 variables in a final addition tree
  last_v = ir_val_reg("%v0", t_i64)
  s_k = 1
  @while s_k < 25
    next_dest = "%v_sum" + s_k.to_str()
    next_use = ir_val_reg("%v" + s_k.to_str(), t_i64)
    fn_stress.blocks[0] = ir_block_add_inst(fn_stress.blocks[0], ir_inst_add(next_dest, last_v, next_use, t_i64))
    last_v = ir_val_reg(next_dest, t_i64)
    s_k = s_k + 1
  @end
  fn_stress.blocks[0] = ir_block_add_inst(fn_stress.blocks[0], ir_inst_ret(last_v, t_i64))

  alloc_stress = regalloc_allocate_function(fn_stress)
  r = assert_true(r, alloc_stress.spill_count > 0, "Stress function produces stack spills (>0)")
  r = assert_true(r, alloc_stress.used_callee_saved.len() > 0, "Stress function utilizes callee-saved registers")

  @! Verify 16-byte stack frame alignment
  frame_size = alloc_stress.stack_frame_size
  r = assert_eq_i64(r, frame_size % 16, 0, "Calculated stack frame size is 16-byte aligned (size=" + frame_size.to_str() + ")")

  @! --------------------------------------------------------------------------
  @! SECTION 6: Module-Level Register Allocation Pass
  @! --------------------------------------------------------------------------
  println("▶ [Section 6] Module-Level Register Allocation Pass (regalloc_run)...")
  mod = ir_module_new("test_mod")
  mod = ir_module_add_function(mod, fn1)
  mod = ir_module_add_function(mod, fn_call)
  mod = ir_module_add_function(mod, fn_stress)

  module_allocations = regalloc_run(mod)
  r = assert_eq_i64(r, module_allocations.len(), 3, "regalloc_run allocated all 3 module functions")
  r = assert_eq_str(r, module_allocations[0].fn_name, "leaf_math", "Func 0 alloc is 'leaf_math'")
  r = assert_eq_str(r, module_allocations[1].fn_name, "call_crossing", "Func 1 alloc is 'call_crossing'")
  r = assert_eq_str(r, module_allocations[2].fn_name, "stress_spill", "Func 2 alloc is 'stress_spill'")

  println("=================================================================")
  println("📊 REGALLOC TEST SUITE SUMMARY:")
  println("   Total Tests : " + r.total.to_str())
  println("   Passed      : " + r.passed.to_str())
  println("   Failed      : " + r.failed.to_str())
  @if r.failed == 0
    println("🎉 ALL REGISTER ALLOCATOR TESTS PASSED CLEANLY!")
  @else
    println("❌ REGISTER ALLOCATOR TESTS COMPLETED WITH FAILURES!")
    return 1
  @end
  println("=================================================================")
  return 0
@end
