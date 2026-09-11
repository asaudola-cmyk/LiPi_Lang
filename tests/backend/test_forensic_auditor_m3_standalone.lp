@! ============================================================================
@! FORENSIC INTEGRITY AUDIT TEST SUITE: MILESTONE M3
@! Native Maya IR & Linear Scan Register Allocation Independent Audit
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"
import "compiler/backend/regalloc"

@struct AuditorState
  passed: 0
  failed: 0
  total: 0
@end

@fn audit_assert_eq(st, actual, expected, name)
  st.total = st.total + 1
  @if actual == expected
    st.passed = st.passed + 1
    println("  [PASS] " + name)
  @else
    st.failed = st.failed + 1
    println("  [FAIL] " + name + " (Expected: " + expected.to_str() + ", Got: " + actual.to_str() + ")")
  @end
  return st
@end

@fn audit_assert_str_eq(st, actual, expected, name)
  st.total = st.total + 1
  @if actual == expected
    st.passed = st.passed + 1
    println("  [PASS] " + name)
  @else
    st.failed = st.failed + 1
    println("  [FAIL] " + name + " (Expected: '" + expected + "', Got: '" + actual + "')")
  @end
  return st
@end

@fn audit_assert_true(st, cond, name)
  st.total = st.total + 1
  @if cond == 1 || cond == true
    st.passed = st.passed + 1
    println("  [PASS] " + name)
  @else
    st.failed = st.failed + 1
    println("  [FAIL] " + name + " (Condition was false)")
  @end
  return st
@end

@fn main()
  st = { passed: 0, failed: 0, total: 0 }
  println("=================================================================")
  println("🔎 FORENSIC AUDIT: 10-INVARIANT CFG VALIDATOR & REGALLOC 🔎")
  println("=================================================================")

  t_i64 = ir_type_i64()
  t_bool = ir_type_bool()
  v_c10 = ir_val_const_int(10, t_i64)
  v_c20 = ir_val_const_int(20, t_i64)

  @! --------------------------------------------------------------------------
  @! PART 1: 10-INVARIANT CFG VALIDATOR FORENSIC VERIFICATION
  @! --------------------------------------------------------------------------
  println("▶ [Audit 1] CFG Invariant 1: Single Entry Block Check...")
  fn1_valid = ir_function_new("fn1_valid", [], t_i64)
  fn1_valid.blocks[0] = ir_block_add_inst(fn1_valid.blocks[0], ir_inst_ret(v_c10, t_i64))
  res1_valid = ir_verify_function(fn1_valid)
  st = audit_assert_eq(st, res1_valid.ok, 1, "Invariant 1: Valid function passes")

  fn1_bad = ir_function_new("fn1_bad", [], t_i64)
  fn1_bad.blocks[0].preds = [1]
  fn1_bad.blocks[0] = ir_block_add_inst(fn1_bad.blocks[0], ir_inst_ret(v_c10, t_i64))
  res1_bad = ir_verify_function(fn1_bad)
  st = audit_assert_eq(st, res1_bad.ok, 0, "Invariant 1: Rejected entry block with preds")

  println("▶ [Audit 2] CFG Invariant 2: Block Terminators (Missing & Internal)...")
  fn2_missing = ir_function_new("fn2_missing", [], t_i64)
  fn2_missing.blocks[0] = ir_block_add_inst(fn2_missing.blocks[0], ir_inst_add("%v0", v_c10, v_c20, t_i64))
  res2_missing = ir_verify_function(fn2_missing)
  st = audit_assert_eq(st, res2_missing.ok, 0, "Invariant 2: Rejected missing terminator")

  fn2_internal = ir_function_new("fn2_internal", [], t_i64)
  fn2_internal.blocks[0] = ir_block_add_inst(fn2_internal.blocks[0], ir_inst_ret(v_c10, t_i64))
  fn2_internal.blocks[0] = ir_block_add_inst(fn2_internal.blocks[0], ir_inst_ret(v_c20, t_i64))
  res2_internal = ir_verify_function(fn2_internal)
  st = audit_assert_eq(st, res2_internal.ok, 0, "Invariant 2: Rejected internal terminator")

  println("▶ [Audit 3] CFG Invariant 3: Terminator Target Existence...")
  fn3_bad = ir_function_new("fn3_bad", [], t_i64)
  fn3_bad.blocks[0] = ir_block_add_inst(fn3_bad.blocks[0], ir_inst_branch(42))
  fn3_bad.blocks[0].succs = [42]
  res3_bad = ir_verify_function(fn3_bad)
  st = audit_assert_eq(st, res3_bad.ok, 0, "Invariant 3: Rejected non-existent branch target 42")

  println("▶ [Audit 4] CFG Invariant 4: Predecessor/Successor Consistency...")
  fn4_asym = ir_function_new("fn4_asym", [], t_i64)
  b1 = ir_block_new(1, "b1")
  b1 = ir_block_add_inst(b1, ir_inst_ret(v_c10, t_i64))
  fn4_asym.blocks[0] = ir_block_add_inst(fn4_asym.blocks[0], ir_inst_branch(1))
  fn4_asym.blocks[0].succs = [1]
  fn4_asym.blocks = fn4_asym.blocks.push(b1) @! b1.preds is empty!
  res4_asym = ir_verify_function(fn4_asym)
  st = audit_assert_eq(st, res4_asym.ok, 0, "Invariant 4: Rejected asymmetric edge")

  println("▶ [Audit 5] CFG Invariant 5: SSA Uniqueness & Phi Rules...")
  fn5_dup = ir_function_new("fn5_dup", [], t_i64)
  fn5_dup.blocks[0] = ir_block_add_inst(fn5_dup.blocks[0], ir_inst_add("%v0", v_c10, v_c20, t_i64))
  fn5_dup.blocks[0] = ir_block_add_inst(fn5_dup.blocks[0], ir_inst_sub("%v0", v_c10, v_c20, t_i64))
  fn5_dup.blocks[0] = ir_block_add_inst(fn5_dup.blocks[0], ir_inst_ret(v_c10, t_i64))
  res5_dup = ir_verify_function(fn5_dup)
  st = audit_assert_eq(st, res5_dup.ok, 0, "Invariant 5: Rejected duplicate SSA register definition")

  fn5_phi_order = ir_function_new("fn5_phi_order", [], t_i64)
  fn5_phi_order.blocks[0] = ir_block_add_inst(fn5_phi_order.blocks[0], ir_inst_add("%v0", v_c10, v_c20, t_i64))
  fn5_phi_order.blocks[0] = ir_block_add_inst(fn5_phi_order.blocks[0], ir_inst_phi("%v1", t_i64, []))
  fn5_phi_order.blocks[0] = ir_block_add_inst(fn5_phi_order.blocks[0], ir_inst_ret(v_c10, t_i64))
  res5_phi_order = ir_verify_function(fn5_phi_order)
  st = audit_assert_eq(st, res5_phi_order.ok, 0, "Invariant 5: Rejected Phi instruction placed after non-Phi")

  println("▶ [Audit 6] CFG Invariant 6: Opcode Validity...")
  fn6_bad_op = ir_function_new("fn6_bad_op", [], t_i64)
  fn6_bad_op.blocks[0] = ir_block_add_inst(fn6_bad_op.blocks[0], ir_inst("INVALID_OPCODE_XYZ", "%v0", t_i64, [], 0))
  fn6_bad_op.blocks[0] = ir_block_add_inst(fn6_bad_op.blocks[0], ir_inst_ret(v_c10, t_i64))
  res6_bad_op = ir_verify_function(fn6_bad_op)
  st = audit_assert_eq(st, res6_bad_op.ok, 0, "Invariant 6: Rejected invalid opcode")

  println("▶ [Audit 7] CFG Invariant 7: Reachability Analysis...")
  fn7_unreach = ir_function_new("fn7_unreach", [], t_i64)
  fn7_unreach.blocks[0] = ir_block_add_inst(fn7_unreach.blocks[0], ir_inst_ret(v_c10, t_i64))
  b_dead = ir_block_new(1, "dead_block")
  b_dead = ir_block_add_inst(b_dead, ir_inst_ret(v_c20, t_i64))
  fn7_unreach.blocks = fn7_unreach.blocks.push(b_dead)
  res7_unreach = ir_verify_function(fn7_unreach)
  st = audit_assert_true(st, res7_unreach.warnings.len() > 0, "Invariant 7: Unreachable block generates warning")

  println("▶ [Audit 8] CFG Invariant 8: Unique Block IDs and Names...")
  fn8_dup_id = ir_function_new("fn8_dup_id", [], t_i64)
  b_dup = ir_block_new(0, "dup_b")
  b_dup = ir_block_add_inst(b_dup, ir_inst_ret(v_c10, t_i64))
  fn8_dup_id.blocks[0] = ir_block_add_inst(fn8_dup_id.blocks[0], ir_inst_ret(v_c10, t_i64))
  fn8_dup_id.blocks = fn8_dup_id.blocks.push(b_dup)
  res8_dup_id = ir_verify_function(fn8_dup_id)
  st = audit_assert_eq(st, res8_dup_id.ok, 0, "Invariant 8: Rejected duplicate block ID")

  println("▶ [Audit 9] CFG Invariant 9: Unique Function Parameters...")
  fn9_dup_p = ir_function_new("fn9_dup_p", ["arg", "arg"], t_i64)
  fn9_dup_p.blocks[0] = ir_block_add_inst(fn9_dup_p.blocks[0], ir_inst_ret(v_c10, t_i64))
  res9_dup_p = ir_verify_function(fn9_dup_p)
  st = audit_assert_eq(st, res9_dup_p.ok, 0, "Invariant 9: Rejected duplicate parameter name")

  println("▶ [Audit 10] CFG Invariant 10: Return Type Conformance...")
  fn10_void = ir_function_new("fn10_void", [], ir_type_void())
  fn10_void.blocks[0] = ir_block_add_inst(fn10_void.blocks[0], ir_inst_ret(ir_val_reg("%v0", t_i64), t_i64))
  res10_void = ir_verify_function(fn10_void)
  st = audit_assert_true(st, res10_void.warnings.len() > 0, "Invariant 10: Non-void return in void function generates warning")

  @! --------------------------------------------------------------------------
  @! PART 2: LINEAR SCAN REGISTER ALLOCATOR FORENSIC VERIFICATION
  @! --------------------------------------------------------------------------
  println("▶ [Audit 11] RegAlloc: Call-Crossing vs Leaf Variable Mapping...")
  fn_reg_test = ir_function_new("fn_reg_test", ["a"], t_i64)
  @! %v0 = add %param_a, 10
  @! %v1 = call external()
  @! %v2 = add %v0, %v1
  @! ret %v2
  v_pa = ir_val_param(0, "a", t_i64)
  v_v0 = ir_val_reg("%v0", t_i64)
  v_v1 = ir_val_reg("%v1", t_i64)
  v_v2 = ir_val_reg("%v2", t_i64)

  fn_reg_test.blocks[0] = ir_block_add_inst(fn_reg_test.blocks[0], ir_inst_add("%v0", v_pa, v_c10, t_i64))
  fn_reg_test.blocks[0] = ir_block_add_inst(fn_reg_test.blocks[0], ir_inst_call("%v1", "external", [], t_i64))
  fn_reg_test.blocks[0] = ir_block_add_inst(fn_reg_test.blocks[0], ir_inst_add("%v2", v_v0, v_v1, t_i64))
  fn_reg_test.blocks[0] = ir_block_add_inst(fn_reg_test.blocks[0], ir_inst_ret(v_v2, t_i64))

  alloc_fn_res = regalloc_allocate_function(fn_reg_test)
  loc_v0 = regalloc_get_location(alloc_fn_res, "%v0")
  loc_v2 = regalloc_get_location(alloc_fn_res, "%v2")

  @! %v0 spans call -> callee-saved register (3, 12, 13, 14, 15)
  st = audit_assert_true(st, regalloc_is_callee_saved(loc_v0.reg_num), "%v0 assigned callee-saved register")
  @! %v2 does not span call -> caller-saved register
  st = audit_assert_true(st, regalloc_is_caller_saved(loc_v2.reg_num), "%v2 assigned caller-saved register")

  println("▶ [Audit 12] RegAlloc: Massive Register Pressure & Stack Spilling...")
  @! Create 30 concurrently live virtual registers
  fn_heavy = ir_function_new("fn_heavy", [], t_i64)
  k = 0
  @while k < 30
    fn_heavy.blocks[0] = ir_block_add_inst(fn_heavy.blocks[0], ir_inst_add("%v" + k.to_str(), v_c10, v_c20, t_i64))
    k = k + 1
  @end
  @! Sum them up
  acc = ir_val_reg("%v0", t_i64)
  k2 = 1
  @while k2 < 30
    dest_k = "%sum" + k2.to_str()
    use_k = ir_val_reg("%v" + k2.to_str(), t_i64)
    fn_heavy.blocks[0] = ir_block_add_inst(fn_heavy.blocks[0], ir_inst_add(dest_k, acc, use_k, t_i64))
    acc = ir_val_reg(dest_k, t_i64)
    k2 = k2 + 1
  @end
  fn_heavy.blocks[0] = ir_block_add_inst(fn_heavy.blocks[0], ir_inst_ret(acc, t_i64))

  alloc_heavy = regalloc_allocate_function(fn_heavy)
  st = audit_assert_true(st, alloc_heavy.spill_count >= 18, "Register allocator spills >= 18 virtual registers under pressure")
  st = audit_assert_eq(st, alloc_heavy.stack_frame_size % 16, 0, "Stack frame size is 16-byte aligned")

  @! Verify spill offset sequencing (-8, -16, -24, etc.)
  spill_seen = 0
  loc_idx = 0
  @while loc_idx < alloc_heavy.locations.len()
    loc = alloc_heavy.locations[loc_idx]
    @if loc.loc_kind == 1
      st = audit_assert_true(st, loc.rbp_offset < 0, "Spill slot offset is negative RBP offset (" + loc.rbp_offset.to_str() + ")")
      spill_seen = 1
    @end
    loc_idx = loc_idx + 1
  @end
  st = audit_assert_eq(st, spill_seen, 1, "Spill slots were genuinely created and assigned")

  println("=================================================================")
  println("📊 AUDITOR STANDALONE RESULTS:")
  println("   Total Tests : " + st.total.to_str())
  println("   Passed      : " + st.passed.to_str())
  println("   Failed      : " + st.failed.to_str())
  println("=================================================================")
  @if st.failed > 0 return 1 @end
  return 0
@end
