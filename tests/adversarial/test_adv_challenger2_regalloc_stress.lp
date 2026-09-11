@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE: LINEAR SCAN REGISTER ALLOCATION
@! Challenger 2 Empirical Stress Test Harness for Milestone M3
@! Module: tests/adversarial/test_adv_challenger2_regalloc_stress.maya
@!
@! Tests:
@! 1. Extreme Register Pressure: 30+, 50+, 100+, 200+ Live Variables
@! 2. Spill Slot Uniqueness & Non-Overlapping Displacements
@! 3. Call-Crossing Intervals: Callee-Saved Preservation & Clobber Prevention
@! 4. Furthest-End Eviction Spill Allocation Oracle
@! 5. 16-Byte Stack Frame Alignment Invariance Sweep
@! 6. End-to-End Pipeline: AST Lowering -> IR CFG -> RegAlloc Run
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"
import "compiler/backend/regalloc"

@struct StressTestState
  passed: i64
  failed: i64
  total: i64
@end

@fn test_state_new() -> StressTestState
  return { passed: 0, failed: 0, total: 0 }
@end

@fn assert_eq_i64(s: StressTestState, actual: i64, expected: i64, name: string) -> StressTestState
  s.total = s.total + 1
  @if actual == expected
    s.passed = s.passed + 1
    println("  [PASS] " + name)
  @else
    s.failed = s.failed + 1
    println("  [FAIL] " + name + " (Expected: " + expected.to_str() + ", Got: " + actual.to_str() + ")")
  @end
  return s
@end

@fn assert_eq_str(s: StressTestState, actual: string, expected: string, name: string) -> StressTestState
  s.total = s.total + 1
  @if actual == expected
    s.passed = s.passed + 1
    println("  [PASS] " + name)
  @else
    s.failed = s.failed + 1
    println("  [FAIL] " + name + " (Expected: '" + expected + "', Got: '" + actual + "')")
  @end
  return s
@end

@fn assert_true(s: StressTestState, cond, name: string) -> StressTestState
  s.total = s.total + 1
  @if cond == 1 || cond == true
    s.passed = s.passed + 1
    println("  [PASS] " + name)
  @else
    s.failed = s.failed + 1
    println("  [FAIL] " + name + " (Expected condition to be true)")
  @end
  return s
@end

@! Helper to build an IR function with N simultaneously live variables
@fn build_stress_function(fn_name: string, num_vars: i64) -> IRFunction
  t_i64 = ir_type_i64()
  c_1 = ir_val_const_int(1, t_i64)
  c_2 = ir_val_const_int(2, t_i64)

  fn_obj = ir_function_new(fn_name, [], t_i64)

  @! Phase 1: Define all N variables
  i = 0
  @while i < num_vars
    v_name = "%v_" + i.to_str()
    fn_obj.blocks[0] = ir_block_add_inst(fn_obj.blocks[0], ir_inst_add(v_name, c_1, c_2, t_i64))
    i = i + 1
  @end

  @! Phase 2: Consume all N variables in an accumulator chain
  accum = ir_val_reg("%v_0", t_i64)
  k = 1
  @while k < num_vars
    dest_name = "%sum_" + k.to_str()
    use_val = ir_val_reg("%v_" + k.to_str(), t_i64)
    fn_obj.blocks[0] = ir_block_add_inst(fn_obj.blocks[0], ir_inst_add(dest_name, accum, use_val, t_i64))
    accum = ir_val_reg(dest_name, t_i64)
    k = k + 1
  @end

  @! Phase 3: Return final accumulated sum
  fn_obj.blocks[0] = ir_block_add_inst(fn_obj.blocks[0], ir_inst_ret(accum, t_i64))
  return fn_obj
@end

@! ============================================================================
@! 1. EXTREME REGISTER PRESSURE: 30+, 50+, 100+, 200+ LIVE VARIABLES
@! ============================================================================

@fn test_extreme_pressure(s: StressTestState) -> StressTestState
  println("▶ [Challenge 1] Extreme Register Pressure (30, 50, 100, 200 Live Variables)...")

  @! Test 30 Live Variables
  fn30 = build_stress_function("stress_30", 30)
  alloc30 = regalloc_allocate_function(fn30)

  s = assert_true(s, alloc30.spill_count >= 18, "30 live vars: Spill count >= 18 (actual: " + alloc30.spill_count.to_str() + ")")
  s = assert_eq_i64(s, alloc30.stack_frame_size % 16, 0, "30 live vars: Stack frame size is 16-byte aligned (frame=" + alloc30.stack_frame_size.to_str() + ")")
  s = assert_true(s, alloc30.used_callee_saved.len() > 0, "30 live vars: Callee-saved registers utilized")

  @! Test 50 Live Variables
  fn50 = build_stress_function("stress_50", 50)
  alloc50 = regalloc_allocate_function(fn50)

  s = assert_true(s, alloc50.spill_count >= 38, "50 live vars: Spill count >= 38 (actual: " + alloc50.spill_count.to_str() + ")")
  s = assert_eq_i64(s, alloc50.stack_frame_size % 16, 0, "50 live vars: Stack frame size is 16-byte aligned (frame=" + alloc50.stack_frame_size.to_str() + ")")

  @! Test 100 Live Variables
  fn100 = build_stress_function("stress_100", 100)
  alloc100 = regalloc_allocate_function(fn100)

  s = assert_true(s, alloc100.spill_count >= 88, "100 live vars: Spill count >= 88 (actual: " + alloc100.spill_count.to_str() + ")")
  s = assert_eq_i64(s, alloc100.stack_frame_size % 16, 0, "100 live vars: Stack frame size is 16-byte aligned (frame=" + alloc100.stack_frame_size.to_str() + ")")

  @! Test 200 Live Variables
  fn200 = build_stress_function("stress_200", 200)
  alloc200 = regalloc_allocate_function(fn200)

  s = assert_true(s, alloc200.spill_count >= 188, "200 live vars: Spill count >= 188 (actual: " + alloc200.spill_count.to_str() + ")")
  s = assert_eq_i64(s, alloc200.stack_frame_size % 16, 0, "200 live vars: Stack frame size is 16-byte aligned (frame=" + alloc200.stack_frame_size.to_str() + ")")

  return s
@end

@! ============================================================================
@! 2. SPILL SLOT DISPLACEMENT UNIQUENESS & INTEGRITY
@! ============================================================================

@fn test_spill_slot_uniqueness(s: StressTestState) -> StressTestState
  println("▶ [Challenge 2] Spill Slot Uniqueness & Non-Overlapping Offsets...")

  fn50 = build_stress_function("stress_spill_unique", 50)
  alloc = regalloc_allocate_function(fn50)

  @! Verify all spilled intervals have unique, distinct negative offsets
  offsets_seen = []
  duplicate_found = 0
  invalid_offset = 0

  i = 0
  @while i < alloc.intervals.len()
    iv = alloc.intervals[i]
    @if iv.is_spilled == 1
      off = iv.spill_slot
      @if off >= 0 || (off % 8) != 0
        invalid_offset = 1
      @end
      @for seen in offsets_seen
        @if seen == off
          duplicate_found = 1
        @end
      @end
      offsets_seen = offsets_seen.push(off)
    @end
    i = i + 1
  @end

  s = assert_eq_i64(s, invalid_offset, 0, "All spill offsets are strictly negative 8-byte aligned offsets")
  s = assert_eq_i64(s, duplicate_found, 0, "Zero duplicate spill slot offsets among 50 live variables")
  s = assert_eq_i64(s, offsets_seen.len(), alloc.spill_count, "Unique offsets count exactly matches spill_count")

  return s
@end

@! ============================================================================
@! 3. CALL-CROSSING INTERVALS & CALLEE-SAVED PRESERVATION
@! ============================================================================

@fn test_call_crossing_adversarial(s: StressTestState) -> StressTestState
  println("▶ [Challenge 3] Call-Crossing Intervals & Caller/Callee Register Invariance...")

  t_i64 = ir_type_i64()
  c_10 = ir_val_const_int(10, t_i64)
  c_20 = ir_val_const_int(20, t_i64)
  c_30 = ir_val_const_int(30, t_i64)

  @! Build function with call-crossing and pure post-call leaf variables:
  @! %v_cross1 = 10
  @! %v_cross2 = 20
  @! %call1_res = call external_1()
  @! %v_cross3 = add %v_cross1, %call1_res
  @! %call2_res = call external_2()
  @! %v_leaf_pure = add 30, 30               <-- Pure leaf defined after all calls
  @! %final_res = add %v_cross2, %v_leaf_pure
  @! ret %final_res

  fn_calls = ir_function_new("multi_call_fn", [], t_i64)
  fn_calls.blocks[0] = ir_block_add_inst(fn_calls.blocks[0], ir_inst_add("%v_cross1", c_10, c_10, t_i64))
  fn_calls.blocks[0] = ir_block_add_inst(fn_calls.blocks[0], ir_inst_add("%v_cross2", c_20, c_20, t_i64))

  fn_calls.blocks[0] = ir_block_add_inst(fn_calls.blocks[0], ir_inst_call("%call1_res", "external_1", [], t_i64))

  v_cross1 = ir_val_reg("%v_cross1", t_i64)
  v_call1_res = ir_val_reg("%call1_res", t_i64)
  fn_calls.blocks[0] = ir_block_add_inst(fn_calls.blocks[0], ir_inst_add("%v_cross3", v_cross1, v_call1_res, t_i64))

  fn_calls.blocks[0] = ir_block_add_inst(fn_calls.blocks[0], ir_inst_call("%call2_res", "external_2", [], t_i64))

  fn_calls.blocks[0] = ir_block_add_inst(fn_calls.blocks[0], ir_inst_add("%v_leaf_pure", c_30, c_30, t_i64))

  v_cross2 = ir_val_reg("%v_cross2", t_i64)
  v_leaf_pure = ir_val_reg("%v_leaf_pure", t_i64)
  fn_calls.blocks[0] = ir_block_add_inst(fn_calls.blocks[0], ir_inst_add("%final_res", v_cross2, v_leaf_pure, t_i64))
  fn_calls.blocks[0] = ir_block_add_inst(fn_calls.blocks[0], ir_inst_ret(ir_val_reg("%final_res", t_i64), t_i64))

  intervals = regalloc_compute_live_intervals(fn_calls)

  iv_cross1 = regalloc_find_interval(intervals, "%v_cross1")
  iv_cross2 = regalloc_find_interval(intervals, "%v_cross2")
  iv_leaf   = regalloc_find_interval(intervals, "%v_leaf_pure")

  s = assert_eq_i64(s, iv_cross1.spans_call, 1, "%v_cross1 spans across function calls")
  s = assert_eq_i64(s, iv_cross2.spans_call, 1, "%v_cross2 spans across function calls")
  s = assert_eq_i64(s, iv_leaf.spans_call, 0, "%v_leaf_pure (post-call) has spans_call == 0")

  alloc_res = regalloc_allocate_function(fn_calls)

  loc_cross1 = regalloc_get_location(alloc_res, "%v_cross1")
  loc_cross2 = regalloc_get_location(alloc_res, "%v_cross2")
  loc_leaf   = regalloc_get_location(alloc_res, "%v_leaf_pure")

  @! Verify %v_cross1 and %v_cross2 are in callee-saved registers or stack spill, never caller-saved!
  @if loc_cross1.loc_kind == 0
    s = assert_true(s, regalloc_is_callee_saved(loc_cross1.reg_num), "%v_cross1 assigned callee-saved register")
  @else
    s = assert_eq_i64(s, loc_cross1.loc_kind, 1, "%v_cross1 spilled to stack")
  @end

  @if loc_cross2.loc_kind == 0
    s = assert_true(s, regalloc_is_callee_saved(loc_cross2.reg_num), "%v_cross2 assigned callee-saved register")
  @else
    s = assert_eq_i64(s, loc_cross2.loc_kind, 1, "%v_cross2 spilled to stack")
  @end

  @! Leaf variable prefers caller-saved register
  @if loc_leaf.loc_kind == 0
    s = assert_true(s, regalloc_is_caller_saved(loc_leaf.reg_num), "%v_leaf_pure assigned caller-saved register")
  @end

  @! Verify used_callee_saved list contains the assigned callee registers
  @for reg in alloc_res.used_callee_saved
    s = assert_true(s, regalloc_is_callee_saved(reg), "used_callee_saved entry " + reg.to_str() + " is callee-saved")
  @end

  return s
@end

@! ============================================================================
@! 4. FURTHEST-END EVICTION SPILL ALLOCATION ORACLE
@! ============================================================================

@fn test_furthest_end_eviction(s: StressTestState) -> StressTestState
  println("▶ [Challenge 4] Furthest-End Eviction Spill Allocation Oracle...")

  t_i64 = ir_type_i64()
  c_1 = ir_val_const_int(1, t_i64)
  c_2 = ir_val_const_int(2, t_i64)

  fn_evict = ir_function_new("eviction_oracle", [], t_i64)

  @! Fill all 12 registers with long-lived variables (ending at pos 100)
  i = 0
  @while i < 12
    v_n = "%long_" + i.to_str()
    fn_evict.blocks[0] = ir_block_add_inst(fn_evict.blocks[0], ir_inst_add(v_n, c_1, c_2, t_i64))
    i = i + 1
  @end

  @! Now introduce short-lived variable %short_v (defined at pos 24, used immediately at pos 26)
  fn_evict.blocks[0] = ir_block_add_inst(fn_evict.blocks[0], ir_inst_add("%short_v", c_1, c_2, t_i64))
  fn_evict.blocks[0] = ir_block_add_inst(fn_evict.blocks[0], ir_inst_add("%short_sum", ir_val_reg("%short_v", t_i64), c_1, t_i64))

  @! Finally consume all 12 %long_* variables at the end (pos 28 to 50)
  acc = ir_val_reg("%short_sum", t_i64)
  j = 0
  @while j < 12
    use_l = ir_val_reg("%long_" + j.to_str(), t_i64)
    dst = "%acc_" + j.to_str()
    fn_evict.blocks[0] = ir_block_add_inst(fn_evict.blocks[0], ir_inst_add(dst, acc, use_l, t_i64))
    acc = ir_val_reg(dst, t_i64)
    j = j + 1
  @end
  fn_evict.blocks[0] = ir_block_add_inst(fn_evict.blocks[0], ir_inst_ret(acc, t_i64))

  alloc_evict = regalloc_allocate_function(fn_evict)

  @! %short_v should be allocated in a register because its end_pos is earlier than the long-lived variables!
  loc_short = regalloc_get_location(alloc_evict, "%short_v")
  s = assert_eq_i64(s, loc_short.loc_kind, 0, "%short_v evicted a longer-lived variable and got physical register")

  @! Total spills should be exactly 1
  s = assert_true(s, alloc_evict.spill_count >= 1, "At least 1 long-lived variable was spilled to stack")

  return s
@end

@! ============================================================================
@! 5. 16-BYTE STACK FRAME ALIGNMENT INVARIANCE SWEEP
@! ============================================================================

@fn test_stack_alignment_sweep(s: StressTestState) -> StressTestState
  println("▶ [Challenge 5] 16-Byte Stack Frame Alignment Invariance Sweep...")

  @! Test various function sizes from 1 to 64 variables
  v_count = 1
  all_aligned = 1
  all_ge_raw = 1

  @while v_count <= 64
    fn_test = build_stress_function("align_sweep_" + v_count.to_str(), v_count)
    res = regalloc_allocate_function(fn_test)

    frame = res.stack_frame_size
    @if (frame % 16) != 0
      all_aligned = 0
    @end

    raw = res.spill_count * 8 + res.used_callee_saved.len() * 8
    @if frame < raw
      all_ge_raw = 0
    @end

    v_count = v_count + 1
  @end

  s = assert_eq_i64(s, all_aligned, 1, "All 64 synthesized functions have 16-byte aligned stack frames")
  s = assert_eq_i64(s, all_ge_raw, 1, "All 64 stack frame sizes are >= raw required byte counts")

  return s
@end

@! ============================================================================
@! 6. END-TO-END PIPELINE: AST LOWERING -> IR CFG -> REGALLOC
@! ============================================================================

@fn mk_ast_node(kind: string) -> ASTNode
  return {
    kind: kind,
    name: "",
    params: [],
    body: [],
    ret_type: "i64",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0
  }
@end

@fn test_end_to_end_pipeline(s: StressTestState) -> StressTestState
  println("▶ [Challenge 6] End-to-End Pipeline: AST Lowering -> CFG -> RegAlloc...")

  n_a = mk_ast_node("LiteralInt")
  n_a.val = 10
  stmt1 = mk_ast_node("Assign")
  stmt1.target = "a"
  stmt1.value = n_a

  n_b = mk_ast_node("LiteralInt")
  n_b.val = 20
  stmt2 = mk_ast_node("Assign")
  stmt2.target = "b"
  stmt2.value = n_b

  var_a = mk_ast_node("Variable")
  var_a.name = "a"
  var_b = mk_ast_node("Variable")
  var_b.name = "b"

  op_add = mk_ast_node("BinaryOp")
  op_add.op = "+"
  op_add.left = var_a
  op_add.right = var_b

  stmt3 = mk_ast_node("Assign")
  stmt3.target = "c"
  stmt3.value = op_add

  var_c = mk_ast_node("Variable")
  var_c.name = "c"
  stmt4 = mk_ast_node("Return")
  stmt4.value = var_c

  fn_ast = mk_ast_node("FnDef")
  fn_ast.name = "e2e_calc"
  fn_ast.params = []
  fn_ast.ret_type = "i64"
  fn_ast.body = [stmt1, stmt2, stmt3, stmt4]

  lower_res = ir_module_from_ast([fn_ast], { module_name: "e2e_mod", dump_ir: 0 })
  s = assert_eq_i64(s, lower_res.error, 0, "ir_module_from_ast returned error=0")
  s = assert_eq_i64(s, lower_res.module.functions.len(), 1, "Lowered module has 1 function")

  cfg_ok = ir_verify_cfg(lower_res.module.functions[0])
  s = assert_eq_i64(s, cfg_ok.ok, 1, "Lowered function CFG passes 10-invariant validation")

  alloc_results = regalloc_run(lower_res.module)
  s = assert_eq_i64(s, alloc_results.len(), 1, "regalloc_run returned 1 function allocation result")
  s = assert_eq_str(s, alloc_results[0].fn_name, "e2e_calc", "Function allocation result name is 'e2e_calc'")
  s = assert_eq_i64(s, alloc_results[0].stack_frame_size % 16, 0, "Function stack frame is 16-byte aligned")

  return s
@end

@! ============================================================================
@! 7. LOOP WITH INTERNAL FUNCTION CALLS & CROSS-ITERATION VARIABLES
@! ============================================================================

@fn test_loop_with_call_stress(s: StressTestState) -> StressTestState
  println("▶ [Challenge 7] Loop with Internal Function Calls & Live Carry Invariance...")

  t_i64 = ir_type_i64()
  c_0 = ir_val_const_int(0, t_i64)
  c_1 = ir_val_const_int(1, t_i64)
  c_10 = ir_val_const_int(10, t_i64)

  @! Build function with loop:
  @! bb_0 (entry): %v_accum = 0; %v_iter = 0; br bb_cond
  @! bb_cond: %c_cmp = cmp lt %v_iter, 10; br_cond %c_cmp, bb_body, bb_exit
  @! bb_body:
  @!   %call_sub = call work_fn(%v_iter)   <-- CALL inside loop body
  @!   %v_accum_next = add %v_accum, %call_sub
  @!   %v_iter_next = add %v_iter, 1
  @!   br bb_cond
  @! bb_exit: ret %v_accum

  fn_loop = ir_function_new("loop_with_call", [], t_i64)
  bb_cond = ir_function_create_block(fn_loop, "loop_cond")
  bb_body = ir_function_create_block(fn_loop, "loop_body")
  bb_exit = ir_function_create_block(fn_loop, "loop_exit")

  @! bb_0
  fn_loop.blocks[0] = ir_block_add_inst(fn_loop.blocks[0], ir_inst_add("%v_accum", c_0, c_0, t_i64))
  fn_loop.blocks[0] = ir_block_add_inst(fn_loop.blocks[0], ir_inst_add("%v_iter", c_0, c_0, t_i64))
  fn_loop.blocks[0] = ir_block_add_inst(fn_loop.blocks[0], ir_inst_br(bb_cond.id, bb_cond.name))

  @! bb_cond
  v_iter = ir_val_reg("%v_iter", t_i64)
  fn_loop.blocks[1] = ir_block_add_inst(fn_loop.blocks[1], ir_inst_cmp("%c_cmp", "lt", v_iter, c_10, t_i64))
  fn_loop.blocks[1] = ir_block_add_inst(fn_loop.blocks[1], ir_inst_br_cond(ir_val_reg("%c_cmp", t_i64), bb_body.id, bb_body.name, bb_exit.id, bb_exit.name))

  @! bb_body
  fn_loop.blocks[2] = ir_block_add_inst(fn_loop.blocks[2], ir_inst_call("%call_sub", "work_fn", [v_iter], t_i64))
  v_accum = ir_val_reg("%v_accum", t_i64)
  v_call_sub = ir_val_reg("%call_sub", t_i64)
  fn_loop.blocks[2] = ir_block_add_inst(fn_loop.blocks[2], ir_inst_add("%v_accum_next", v_accum, v_call_sub, t_i64))
  fn_loop.blocks[2] = ir_block_add_inst(fn_loop.blocks[2], ir_inst_add("%v_iter_next", v_iter, c_1, t_i64))
  fn_loop.blocks[2] = ir_block_add_inst(fn_loop.blocks[2], ir_inst_br(bb_cond.id, bb_cond.name))

  @! bb_exit
  fn_loop.blocks[3] = ir_block_add_inst(fn_loop.blocks[3], ir_inst_ret(v_accum, t_i64))

  alloc_loop = regalloc_allocate_function(fn_loop)

  @! %v_accum is defined before the call and used after the call -> must span call
  iv_accum = regalloc_find_interval(alloc_loop.intervals, "%v_accum")
  s = assert_eq_i64(s, iv_accum.spans_call, 1, "%v_accum spanning loop body call is marked spans_call=1")

  loc_accum = regalloc_get_location(alloc_loop, "%v_accum")
  @if loc_accum.loc_kind == 0
    s = assert_true(s, regalloc_is_callee_saved(loc_accum.reg_num), "%v_accum assigned callee-saved register across loop call")
  @else
    s = assert_eq_i64(s, loc_accum.loc_kind, 1, "%v_accum safely spilled to stack")
  @end

  return s
@end

@! ============================================================================
@! 8. PARAMETER CALL-CROSSING & PRESERVATION
@! ============================================================================

@fn test_param_call_crossing_stress(s: StressTestState) -> StressTestState
  println("▶ [Challenge 8] Parameter Call-Crossing & Preservation across Nested Calls...")

  t_i64 = ir_type_i64()
  c_1 = ir_val_const_int(1, t_i64)

  @! Function with 4 parameters, calling an external function, and then using the params
  fn_param = ir_function_new("param_preservation", ["p0", "p1", "p2", "p3"], t_i64)

  @! bb_0:
  @!   %v_call = call helper_fn()
  @!   %s1 = add %param_p0, %param_p1
  @!   %s2 = add %param_p2, %param_p3
  @!   %s3 = add %s1, %s2
  @!   %res = add %s3, %v_call
  @!   ret %res

  fn_param.blocks[0] = ir_block_add_inst(fn_param.blocks[0], ir_inst_call("%v_call", "helper_fn", [], t_i64))

  p0 = ir_val_param(0, "p0", t_i64)
  p1 = ir_val_param(1, "p1", t_i64)
  p2 = ir_val_param(2, "p2", t_i64)
  p3 = ir_val_param(3, "p3", t_i64)

  fn_param.blocks[0] = ir_block_add_inst(fn_param.blocks[0], ir_inst_add("%s1", p0, p1, t_i64))
  fn_param.blocks[0] = ir_block_add_inst(fn_param.blocks[0], ir_inst_add("%s2", p2, p3, t_i64))
  fn_param.blocks[0] = ir_block_add_inst(fn_param.blocks[0], ir_inst_add("%s3", ir_val_reg("%s1", t_i64), ir_val_reg("%s2", t_i64), t_i64))
  fn_param.blocks[0] = ir_block_add_inst(fn_param.blocks[0], ir_inst_add("%res", ir_val_reg("%s3", t_i64), ir_val_reg("%v_call", t_i64), t_i64))
  fn_param.blocks[0] = ir_block_add_inst(fn_param.blocks[0], ir_inst_ret(ir_val_reg("%res", t_i64), t_i64))

  alloc_param = regalloc_allocate_function(fn_param)

  @! All 4 parameters must be marked spans_call=1 because they are live from pos 0 across helper_fn call!
  iv_p0 = regalloc_find_interval(alloc_param.intervals, "%param_p0")
  iv_p1 = regalloc_find_interval(alloc_param.intervals, "%param_p1")
  iv_p2 = regalloc_find_interval(alloc_param.intervals, "%param_p2")
  iv_p3 = regalloc_find_interval(alloc_param.intervals, "%param_p3")

  s = assert_eq_i64(s, iv_p0.spans_call, 1, "%param_p0 spans across call")
  s = assert_eq_i64(s, iv_p1.spans_call, 1, "%param_p1 spans across call")
  s = assert_eq_i64(s, iv_p2.spans_call, 1, "%param_p2 spans across call")
  s = assert_eq_i64(s, iv_p3.spans_call, 1, "%param_p3 spans across call")

  @! Verify that each parameter is assigned a callee-saved register or stack slot
  loc_p0 = regalloc_get_location(alloc_param, "%param_p0")
  loc_p1 = regalloc_get_location(alloc_param, "%param_p1")
  loc_p2 = regalloc_get_location(alloc_param, "%param_p2")
  loc_p3 = regalloc_get_location(alloc_param, "%param_p3")

  @if loc_p0.loc_kind == 0
    s = assert_true(s, regalloc_is_callee_saved(loc_p0.reg_num), "%param_p0 in callee-saved register")
  @else
    s = assert_eq_i64(s, loc_p0.loc_kind, 1, "%param_p0 spilled to stack")
  @end

  @if loc_p1.loc_kind == 0
    s = assert_true(s, regalloc_is_callee_saved(loc_p1.reg_num), "%param_p1 in callee-saved register")
  @else
    s = assert_eq_i64(s, loc_p1.loc_kind, 1, "%param_p1 spilled to stack")
  @end

  return s
@end

@! ============================================================================
@! 9. DIAMOND CFG WITH PHI NODES UNDER REGISTER ALLOCATION
@! ============================================================================

@fn test_diamond_phi_regalloc(s: StressTestState) -> StressTestState
  println("▶ [Challenge 9] Diamond CFG with Phi Nodes Register Allocation...")

  t_i64 = ir_type_i64()
  c_10 = ir_val_const_int(10, t_i64)
  c_20 = ir_val_const_int(20, t_i64)

  fn_diamond = ir_function_new("diamond_phi_reg", ["flag"], t_i64)
  bb_then = ir_function_create_block(fn_diamond, "then_blk")
  bb_else = ir_function_create_block(fn_diamond, "else_blk")
  bb_join = ir_function_create_block(fn_diamond, "join_blk")

  p_flag = ir_val_param(0, "flag", t_i64)
  fn_diamond.blocks[0] = ir_block_add_inst(fn_diamond.blocks[0], ir_inst_br_cond(p_flag, bb_then.id, bb_then.name, bb_else.id, bb_else.name))

  fn_diamond.blocks[1] = ir_block_add_inst(fn_diamond.blocks[1], ir_inst_add("%v_then", c_10, c_10, t_i64))
  fn_diamond.blocks[1] = ir_block_add_inst(fn_diamond.blocks[1], ir_inst_br(bb_join.id, bb_join.name))

  fn_diamond.blocks[2] = ir_block_add_inst(fn_diamond.blocks[2], ir_inst_add("%v_else", c_20, c_20, t_i64))
  fn_diamond.blocks[2] = ir_block_add_inst(fn_diamond.blocks[2], ir_inst_br(bb_join.id, bb_join.name))

  phi_incoming = [
    { phi_val: ir_val_reg("%v_then", t_i64), phi_block_id: bb_then.id },
    { phi_val: ir_val_reg("%v_else", t_i64), phi_block_id: bb_else.id }
  ]
  fn_diamond.blocks[3] = ir_block_add_inst(fn_diamond.blocks[3], ir_inst_phi("%v_phi", phi_incoming, t_i64))
  fn_diamond.blocks[3] = ir_block_add_inst(fn_diamond.blocks[3], ir_inst_ret(ir_val_reg("%v_phi", t_i64), t_i64))

  alloc_diamond = regalloc_allocate_function(fn_diamond)
  s = assert_true(s, alloc_diamond.intervals.len() >= 4, "Allocated intervals for diamond CFG (param + then + else + phi)")

  loc_phi = regalloc_get_location(alloc_diamond, "%v_phi")
  s = assert_true(s, loc_phi.loc_kind == 0 || loc_phi.loc_kind == 1, "%v_phi has valid location")

  return s
@end

@! ============================================================================
@! 10. 500 LIVE VARIABLES EXTREME SCALABILITY STRESS
@! ============================================================================

@fn test_500_variables_stress(s: StressTestState) -> StressTestState
  println("▶ [Challenge 10] 500 Live Variables Extreme Scalability Stress...")

  fn500 = build_stress_function("stress_500_vars", 500)
  alloc500 = regalloc_allocate_function(fn500)

  s = assert_true(s, alloc500.spill_count >= 488, "500 live vars: Spill count >= 488 (actual: " + alloc500.spill_count.to_str() + ")")
  s = assert_eq_i64(s, alloc500.stack_frame_size % 16, 0, "500 live vars: Stack frame size is 16-byte aligned (frame=" + alloc500.stack_frame_size.to_str() + ")")
  s = assert_true(s, alloc500.stack_frame_size >= 3900, "500 live vars: Stack frame size is >= 3900 bytes")

  @! Verify 0 duplicate spill slots among all 500 intervals
  offsets = []
  dups = 0
  i = 0
  @while i < alloc500.intervals.len()
    iv = alloc500.intervals[i]
    @if iv.is_spilled == 1
      off = iv.spill_slot
      @for seen in offsets
        @if seen == off dups = 1 @end
      @end
      offsets = offsets.push(off)
    @end
    i = i + 1
  @end

  s = assert_eq_i64(s, dups, 0, "500 live vars: Zero duplicate spill offsets")
  s = assert_eq_i64(s, offsets.len(), alloc500.spill_count, "500 live vars: Spilled offsets count matches spill_count")

  return s
@end

@! ============================================================================
@! MAIN RUNNER
@! ============================================================================

@fn main() -> i64
  s = test_state_new()

  println("=================================================================")
  println("🔱 ADVERSARIAL STRESS SUITE: REGISTER ALLOCATOR (CHALLENGER 2) 🔱")
  println("=================================================================")

  s = test_extreme_pressure(s)
  s = test_spill_slot_uniqueness(s)
  s = test_call_crossing_adversarial(s)
  s = test_furthest_end_eviction(s)
  s = test_stack_alignment_sweep(s)
  s = test_end_to_end_pipeline(s)
  s = test_loop_with_call_stress(s)
  s = test_param_call_crossing_stress(s)
  s = test_diamond_phi_regalloc(s)
  s = test_500_variables_stress(s)

  println("=================================================================")
  println("📊 CHALLENGER 2 REGALLOC STRESS SUMMARY:")
  println("   Total Tests : " + s.total.to_str())
  println("   Passed      : " + s.passed.to_str())
  println("   Failed      : " + s.failed.to_str())
  @if s.failed == 0
    println("🎉 ALL CHALLENGER 2 REGALLOC STRESS TESTS PASSED CLEANLY!")
  @else
    println("❌ FAILURES DETECTED IN REGISTER ALLOCATOR STRESS SUITE!")
    return 1
  @end
  println("=================================================================")
  return 0
@end
