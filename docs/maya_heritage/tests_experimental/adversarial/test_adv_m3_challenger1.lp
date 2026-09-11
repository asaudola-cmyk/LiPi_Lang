@! ============================================================================
@! ADVERSARIAL CHALLENGER 1 STRESS TEST SUITE: MAYA IR & CFG VALIDATOR
@! Milestone M3: Pure Maya Native IR, Dominance Analysis & AST-to-IR Lowering
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"

@struct AdvChallengerState
  passed: 0
  failed: 0
  total: 0
@end

@fn assert_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: " + expected.to_str() + ", Got: " + actual.to_str() + ")")
  @end
  return state
@end

@fn assert_str_eq(state, actual, expected, name)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Expected: '" + expected + "', Got: '" + actual + "')")
  @end
  return state
@end

@fn assert_true(state, cond, name)
  state.total = state.total + 1
  @if cond == 1 || cond == true
    state.passed = state.passed + 1
    println("  [PASS] " + name)
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + name + " (Condition was false)")
  @end
  return state
@end

@fn contains_substring(haystack, needle)
  return string_contains(haystack, needle)
@end

@! ============================================================================
@! 1. MALFORMED CFG VERIFIER STRESS TESTS: INVARIANTS 1 THROUGH 10
@! ============================================================================

@fn test_malformed_cfg_invariants(state)
  println("▶ [Challenger 1.1] Testing Malformed CFGs against Invariants 1-10...")

  @! --------------------------------------------------------------------------
  @! Invariant 1: Single Entry Block
  @! --------------------------------------------------------------------------
  @! Test 1a: Entry block with non-zero ID
  fn_bad_entry_id = ir_function_new("bad_entry_id", [], ir_type_i64())
  fn_bad_entry_id.blocks[0].id = 5
  fn_bad_entry_id.blocks[0].instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  res_inv1a = ir_verify_cfg(fn_bad_entry_id)
  state = assert_eq(state, res_inv1a.ok, 0, "Invariant 1: Rejects entry block with id != 0")
  state = assert_true(state, contains_substring(res_inv1a.errors[0], "Invariant 1 Violation"), "Invariant 1: Error message cites Invariant 1")

  @! Test 1b: Entry block with predecessor edges
  fn_bad_entry_preds = ir_function_new("bad_entry_preds", [], ir_type_i64())
  fn_bad_entry_preds.blocks[0].preds = [1]
  fn_bad_entry_preds.blocks[0].instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  res_inv1b = ir_verify_cfg(fn_bad_entry_preds)
  state = assert_eq(state, res_inv1b.ok, 0, "Invariant 1: Rejects entry block with predecessor edges")

  @! --------------------------------------------------------------------------
  @! Invariant 2: Valid Block Terminators
  @! --------------------------------------------------------------------------
  @! Test 2a: Empty block without instructions
  fn_empty_b = ir_function_new("empty_block", [], ir_type_i64())
  fn_empty_b.blocks[0].instructions = []
  res_inv2a = ir_verify_cfg(fn_empty_b)
  state = assert_eq(state, res_inv2a.ok, 0, "Invariant 2: Rejects empty basic block")

  @! Test 2b: Block ending with non-terminator instruction (e.g. ADD)
  fn_no_term = ir_function_new("no_term", [], ir_type_i64())
  fn_no_term.blocks[0].instructions = [
    ir_inst_add("%v0", ir_val_const_int(1, ir_type_i64()), ir_val_const_int(2, ir_type_i64()), ir_type_i64())
  ]
  res_inv2b = ir_verify_cfg(fn_no_term)
  state = assert_eq(state, res_inv2b.ok, 0, "Invariant 2: Rejects block ending in non-terminator (ADD)")

  @! Test 2c: Block containing internal terminator followed by dead instructions
  fn_internal_term = ir_function_new("internal_term", [], ir_type_i64())
  fn_internal_term.blocks[0].instructions = [
    ir_inst_branch(1),
    ir_inst_add("%v0", ir_val_const_int(1, ir_type_i64()), ir_val_const_int(2, ir_type_i64()), ir_type_i64()),
    ir_inst_ret(ir_val_const_int(42, ir_type_i64()), ir_type_i64())
  ]
  res_inv2c = ir_verify_cfg(fn_internal_term)
  state = assert_eq(state, res_inv2c.ok, 0, "Invariant 2: Rejects block with internal terminator")
  has_intern_err = 0
  @for err in res_inv2c.errors
    @if contains_substring(err, "internal terminator") has_intern_err = 1 @end
  @end
  state = assert_true(state, has_intern_err, "Invariant 2: Reports internal terminator error")

  @! --------------------------------------------------------------------------
  @! Invariant 3: Valid Branch Targets & Terminator Consistency
  @! --------------------------------------------------------------------------
  @! Test 3a: BR target refers to non-existent block ID
  fn_bad_br_tgt = ir_function_new("bad_br_tgt", [], ir_type_i64())
  fn_bad_br_tgt.blocks[0].instructions = [ir_inst_branch(99)]
  fn_bad_br_tgt.blocks[0].succs = [99]
  res_inv3a = ir_verify_cfg(fn_bad_br_tgt)
  state = assert_eq(state, res_inv3a.ok, 0, "Invariant 3: Rejects BR target to non-existent block")

  @! Test 3b: BR_COND true_target non-existent
  fn_bad_cond_true = ir_function_new("bad_cond_true", [], ir_type_i64())
  b1_valid = ir_block_new(1, "b1")
  b1_valid.preds = [0]
  b1_valid.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  fn_bad_cond_true.blocks[0].instructions = [ir_inst_branch_cond(ir_val_const_bool(1), 42, 1)]
  fn_bad_cond_true.blocks[0].succs = [42, 1]
  fn_bad_cond_true.blocks = [fn_bad_cond_true.blocks[0], b1_valid]
  res_inv3b = ir_verify_cfg(fn_bad_cond_true)
  state = assert_eq(state, res_inv3b.ok, 0, "Invariant 3: Rejects BR_COND with invalid true_target")

  @! Test 3c: BR_COND false_target non-existent
  fn_bad_cond_false = ir_function_new("bad_cond_false", [], ir_type_i64())
  fn_bad_cond_false.blocks[0].instructions = [ir_inst_branch_cond(ir_val_const_bool(1), 1, 88)]
  fn_bad_cond_false.blocks[0].succs = [1, 88]
  fn_bad_cond_false.blocks = [fn_bad_cond_false.blocks[0], b1_valid]
  res_inv3c = ir_verify_cfg(fn_bad_cond_false)
  state = assert_eq(state, res_inv3c.ok, 0, "Invariant 3: Rejects BR_COND with invalid false_target")

  @! --------------------------------------------------------------------------
  @! Invariant 4: Symmetric CFG Edge Consistency
  @! --------------------------------------------------------------------------
  @! Test 4a: BR target mismatch with succs array
  fn_br_succs_mismatch = ir_function_new("br_succs_mismatch", [], ir_type_i64())
  b1_succ = ir_block_new(1, "b1")
  b1_succ.preds = [0]
  b1_succ.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  b2_succ = ir_block_new(2, "b2")
  b2_succ.preds = [0]
  b2_succ.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  fn_br_succs_mismatch.blocks[0].instructions = [ir_inst_branch(1)]
  fn_br_succs_mismatch.blocks[0].succs = [2] @! mismatch!
  fn_br_succs_mismatch.blocks = [fn_br_succs_mismatch.blocks[0], b1_succ, b2_succ]
  res_inv4a = ir_verify_cfg(fn_br_succs_mismatch)
  state = assert_eq(state, res_inv4a.ok, 0, "Invariant 4: Rejects BR target / succs list mismatch")

  @! Test 4b: BR_COND target mismatch with succs array
  fn_cond_succs_mismatch = ir_function_new("cond_succs_mismatch", [], ir_type_i64())
  fn_cond_succs_mismatch.blocks[0].instructions = [ir_inst_branch_cond(ir_val_const_bool(1), 1, 2)]
  fn_cond_succs_mismatch.blocks[0].succs = [1, 1] @! mismatch!
  fn_cond_succs_mismatch.blocks = [fn_cond_succs_mismatch.blocks[0], b1_succ, b2_succ]
  res_inv4b = ir_verify_cfg(fn_cond_succs_mismatch)
  state = assert_eq(state, res_inv4b.ok, 0, "Invariant 4: Rejects BR_COND targets / succs list mismatch")

  @! Test 4c: RET instruction having non-empty succs array
  fn_ret_nonempty_succs = ir_function_new("ret_nonempty_succs", [], ir_type_i64())
  fn_ret_nonempty_succs.blocks[0].instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  fn_ret_nonempty_succs.blocks[0].succs = [1] @! ret must have 0 succs
  fn_ret_nonempty_succs.blocks = [fn_ret_nonempty_succs.blocks[0], b1_succ]
  res_inv4c = ir_verify_cfg(fn_ret_nonempty_succs)
  state = assert_eq(state, res_inv4c.ok, 0, "Invariant 4: Rejects RET instruction with successors")

  @! Test 4d: Missing symmetric predecessor edge (A -> B, but B.preds has no A)
  fn_missing_pred_edge = ir_function_new("missing_pred_edge", [], ir_type_i64())
  b0_edge = fn_missing_pred_edge.blocks[0]
  b0_edge.instructions = [ir_inst_branch(1)]
  b0_edge.succs = [1]
  b1_missing_pred = ir_block_new(1, "b1")
  b1_missing_pred.preds = [] @! Missing 0!
  b1_missing_pred.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  fn_missing_pred_edge.blocks = [b0_edge, b1_missing_pred]
  res_inv4d = ir_verify_cfg(fn_missing_pred_edge)
  state = assert_eq(state, res_inv4d.ok, 0, "Invariant 4: Rejects missing symmetric predecessor edge")

  @! --------------------------------------------------------------------------
  @! Invariant 5: Single Static Assignment (SSA) & Phi Invariants
  @! --------------------------------------------------------------------------
  @! Test 5a: Duplicate SSA register definition in same basic block
  fn_dup_reg_same_bb = ir_function_new("dup_reg_same_bb", [], ir_type_i64())
  fn_dup_reg_same_bb.blocks[0].instructions = [
    ir_inst_add("%v0", ir_val_const_int(1, ir_type_i64()), ir_val_const_int(2, ir_type_i64()), ir_type_i64()),
    ir_inst_mul("%v0", ir_val_reg("%v0", ir_type_i64()), ir_val_const_int(3, ir_type_i64()), ir_type_i64()),
    ir_inst_ret(ir_val_reg("%v0", ir_type_i64()), ir_type_i64())
  ]
  res_inv5a = ir_verify_cfg(fn_dup_reg_same_bb)
  state = assert_eq(state, res_inv5a.ok, 0, "Invariant 5: Rejects duplicate SSA register definition in same block")

  @! Test 5b: Duplicate SSA register definition across different basic blocks
  fn_dup_reg_cross_bb = ir_function_new("dup_reg_cross_bb", [], ir_type_i64())
  b0_cross = fn_dup_reg_cross_bb.blocks[0]
  b0_cross.instructions = [
    ir_inst_add("%v0", ir_val_const_int(10, ir_type_i64()), ir_val_const_int(20, ir_type_i64()), ir_type_i64()),
    ir_inst_branch(1)
  ]
  b0_cross.succs = [1]
  b1_cross = ir_block_new(1, "b1")
  b1_cross.preds = [0]
  b1_cross.instructions = [
    ir_inst_add("%v0", ir_val_const_int(30, ir_type_i64()), ir_val_const_int(40, ir_type_i64()), ir_type_i64()),
    ir_inst_ret(ir_val_reg("%v0", ir_type_i64()), ir_type_i64())
  ]
  fn_dup_reg_cross_bb.blocks = [b0_cross, b1_cross]
  res_inv5b = ir_verify_cfg(fn_dup_reg_cross_bb)
  state = assert_eq(state, res_inv5b.ok, 0, "Invariant 5: Rejects duplicate SSA register across blocks")

  @! Test 5c: Phi instruction positioned after non-phi instruction
  fn_phi_order = ir_function_new("phi_order", [], ir_type_i64())
  b0_phi = fn_phi_order.blocks[0]
  b0_phi.instructions = [ir_inst_branch(1)]
  b0_phi.succs = [1]
  b1_phi = ir_block_new(1, "b1")
  b1_phi.preds = [0]
  b1_phi.instructions = [
    ir_inst_add("%v0", ir_val_const_int(1, ir_type_i64()), ir_val_const_int(2, ir_type_i64()), ir_type_i64()),
    ir_inst_phi("%v1", [{ phi_val: ir_val_reg("%v0", ir_type_i64()), phi_block_id: 0 }], ir_type_i64()),
    ir_inst_ret(ir_val_reg("%v1", ir_type_i64()), ir_type_i64())
  ]
  fn_phi_order.blocks = [b0_phi, b1_phi]
  res_inv5c = ir_verify_cfg(fn_phi_order)
  state = assert_eq(state, res_inv5c.ok, 0, "Invariant 5: Rejects Phi instruction placed after non-Phi")

  @! Test 5d: Phi incoming count mismatch with predecessor count
  fn_phi_count = ir_function_new("phi_count", [], ir_type_i64())
  b0_pc = fn_phi_count.blocks[0]
  b0_pc.instructions = [ir_inst_branch_cond(ir_val_const_bool(1), 1, 2)]
  b0_pc.succs = [1, 2]
  b1_pc = ir_block_new(1, "b1")
  b1_pc.preds = [0]
  b1_pc.instructions = [ir_inst_branch(3)]
  b1_pc.succs = [3]
  b2_pc = ir_block_new(2, "b2")
  b2_pc.preds = [0]
  b2_pc.instructions = [ir_inst_branch(3)]
  b2_pc.succs = [3]
  b3_pc = ir_block_new(3, "b3")
  b3_pc.preds = [1, 2] @! 2 predecessors!
  b3_pc.instructions = [
    ir_inst_phi("%v3", [{ phi_val: ir_val_const_int(10, ir_type_i64()), phi_block_id: 1 }], ir_type_i64()), @! only 1 incoming!
    ir_inst_ret(ir_val_reg("%v3", ir_type_i64()), ir_type_i64())
  ]
  fn_phi_count.blocks = [b0_pc, b1_pc, b2_pc, b3_pc]
  res_inv5d = ir_verify_cfg(fn_phi_count)
  state = assert_eq(state, res_inv5d.ok, 0, "Invariant 5: Rejects Phi incoming count mismatch with predecessors")

  @! --------------------------------------------------------------------------
  @! Invariant 6: Valid Opcodes
  @! --------------------------------------------------------------------------
  @! Test 6a: Instruction with unknown opcode
  fn_bad_opcode = ir_function_new("bad_opcode", [], ir_type_i64())
  fn_bad_opcode.blocks[0].instructions = [
    ir_inst_binary("INVALID_OPCODE_X", "%v0", ir_val_const_int(1, ir_type_i64()), ir_val_const_int(2, ir_type_i64()), ir_type_i64()),
    ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())
  ]
  res_inv6a = ir_verify_cfg(fn_bad_opcode)
  state = assert_eq(state, res_inv6a.ok, 0, "Invariant 6: Rejects invalid opcode")

  @! --------------------------------------------------------------------------
  @! Invariant 7: Reachability Analysis
  @! --------------------------------------------------------------------------
  @! Test 7a: Unreachable basic block generates warning
  fn_unreach = ir_function_new("unreachable_block_fn", [], ir_type_i64())
  b0_unreach = fn_unreach.blocks[0]
  b0_unreach.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  b1_orphan = ir_block_new(1, "orphan_bb")
  b1_orphan.instructions = [ir_inst_ret(ir_val_const_int(1, ir_type_i64()), ir_type_i64())]
  fn_unreach.blocks = [b0_unreach, b1_orphan]
  res_inv7a = ir_verify_cfg(fn_unreach)
  state = assert_eq(state, res_inv7a.ok, 1, "Invariant 7: Unreachable block is non-fatal for syntax")
  state = assert_true(state, res_inv7a.warnings.len() > 0, "Invariant 7: Warning generated for unreachable block")
  state = assert_true(state, contains_substring(res_inv7a.warnings[0], "Invariant 7 Warning: Unreachable"), "Invariant 7: Warning text cites Invariant 7")

  @! --------------------------------------------------------------------------
  @! Invariant 8: Unique Basic Block IDs and Block Names
  @! --------------------------------------------------------------------------
  @! Test 8a: Duplicate block ID
  fn_dup_bid = ir_function_new("dup_bid", [], ir_type_i64())
  b0_d = fn_dup_bid.blocks[0]
  b0_d.instructions = [ir_inst_branch(1)]
  b0_d.succs = [1]
  b1_first = ir_block_new(1, "b1_first")
  b1_first.preds = [0]
  b1_first.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  b1_second = ir_block_new(1, "b1_second") @! Duplicate ID 1!
  b1_second.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  fn_dup_bid.blocks = [b0_d, b1_first, b1_second]
  res_inv8a = ir_verify_cfg(fn_dup_bid)
  state = assert_eq(state, res_inv8a.ok, 0, "Invariant 8: Rejects duplicate basic block ID")

  @! Test 8b: Duplicate block name
  fn_dup_bname = ir_function_new("dup_bname", [], ir_type_i64())
  b0_dn = fn_dup_bname.blocks[0]
  b0_dn.instructions = [ir_inst_branch(1)]
  b0_dn.succs = [1]
  b1_dn = ir_block_new(1, "same_name")
  b1_dn.preds = [0]
  b1_dn.instructions = [ir_inst_branch(2)]
  b1_dn.succs = [2]
  b2_dn = ir_block_new(2, "same_name") @! Duplicate name!
  b2_dn.preds = [1]
  b2_dn.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  fn_dup_bname.blocks = [b0_dn, b1_dn, b2_dn]
  res_inv8b = ir_verify_cfg(fn_dup_bname)
  state = assert_eq(state, res_inv8b.ok, 0, "Invariant 8: Rejects duplicate basic block name")

  @! --------------------------------------------------------------------------
  @! Invariant 9: Unique Function Parameters
  @! --------------------------------------------------------------------------
  @! Test 9a: Duplicate parameter name
  fn_dup_param_name = ir_function_new("dup_param_name", ["arg", "arg"], ir_type_i64())
  fn_dup_param_name.blocks[0].instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  res_inv9a = ir_verify_cfg(fn_dup_param_name)
  state = assert_eq(state, res_inv9a.ok, 0, "Invariant 9: Rejects duplicate parameter name")

  @! Test 9b: Duplicate parameter register
  fn_dup_param_reg = ir_function_new("dup_param_reg", ["p1", "p2"], ir_type_i64())
  fn_dup_param_reg.params[0].reg = "%rdi"
  fn_dup_param_reg.params[1].reg = "%rdi" @! Duplicate %rdi!
  fn_dup_param_reg.blocks[0].instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  res_inv9b = ir_verify_cfg(fn_dup_param_reg)
  state = assert_eq(state, res_inv9b.ok, 0, "Invariant 9: Rejects duplicate parameter register")

  @! --------------------------------------------------------------------------
  @! Invariant 10: Return Type Conformance
  @! --------------------------------------------------------------------------
  @! Test 10a: Void function returning non-void constant value
  fn_void_ret_val = ir_function_new("void_ret_val", [], ir_type_void())
  fn_void_ret_val.blocks[0].instructions = [
    ir_inst_ret(ir_val_reg("%v0", ir_type_i64()), ir_type_void())
  ]
  res_inv10a = ir_verify_cfg(fn_void_ret_val)
  state = assert_true(state, res_inv10a.warnings.len() > 0, "Invariant 10: Warns on non-void return value in void function")
  state = assert_true(state, contains_substring(res_inv10a.warnings[0], "Invariant 10"), "Invariant 10: Warning text cites Invariant 10")

  return state
@end

@! ============================================================================
@! 2. VALID COMPLEX CFG TOPOLOGIES & DOMINANCE ANALYSIS STRESS
@! ============================================================================

@fn test_complex_cfg_topologies(state)
  println("▶ [Challenger 1.2] Testing Valid Complex CFGs & Dominator Analysis...")

  @! Test 2.1: 3-Level Deeply Nested While Loop Topology
  @! Loop 1 (outer): 1 (cond), 2 (body)
  @! Loop 2 (mid):   3 (cond), 4 (body)
  @! Loop 3 (inner): 5 (cond), 6 (body), 7 (step), 8 (inner exit)
  @! Mid exit: 9, Outer exit: 10
  fn_nest = ir_function_new("nested_3x_loops", ["n"], ir_type_i64())
  
  b0 = fn_nest.blocks[0]
  b0.instructions = [ir_inst_branch(1)]
  b0.succs = [1]

  @! Outer cond
  b1 = ir_block_new(1, "outer_cond")
  b1.preds = [0, 9]
  b1.instructions = [ir_inst_branch_cond(ir_val_const_bool(1), 2, 10)]
  b1.succs = [2, 10]

  @! Outer body -> enters mid cond
  b2 = ir_block_new(2, "outer_body")
  b2.preds = [1]
  b2.instructions = [ir_inst_branch(3)]
  b2.succs = [3]

  @! Mid cond
  b3 = ir_block_new(3, "mid_cond")
  b3.preds = [2, 8]
  b3.instructions = [ir_inst_branch_cond(ir_val_const_bool(1), 4, 9)]
  b3.succs = [4, 9]

  @! Mid body -> enters inner cond
  b4 = ir_block_new(4, "mid_body")
  b4.preds = [3]
  b4.instructions = [ir_inst_branch(5)]
  b4.succs = [5]

  @! Inner cond
  b5 = ir_block_new(5, "inner_cond")
  b5.preds = [4, 7]
  b5.instructions = [ir_inst_branch_cond(ir_val_const_bool(1), 6, 8)]
  b5.succs = [6, 8]

  @! Inner body -> step
  b6 = ir_block_new(6, "inner_body")
  b6.preds = [5]
  b6.instructions = [ir_inst_branch(7)]
  b6.succs = [7]

  @! Inner step -> inner cond back-edge
  b7 = ir_block_new(7, "inner_step")
  b7.preds = [6]
  b7.instructions = [ir_inst_branch(5)]
  b7.succs = [5]

  @! Inner exit -> mid cond back-edge
  b8 = ir_block_new(8, "inner_exit")
  b8.preds = [5]
  b8.instructions = [ir_inst_branch(3)]
  b8.succs = [3]

  @! Mid exit -> outer cond back-edge
  b9 = ir_block_new(9, "mid_exit")
  b9.preds = [3]
  b9.instructions = [ir_inst_branch(1)]
  b9.succs = [1]

  @! Outer exit -> return
  b10 = ir_block_new(10, "outer_exit")
  b10.preds = [1]
  b10.instructions = [ir_inst_ret(ir_val_const_int(100, ir_type_i64()), ir_type_i64())]
  b10.succs = []

  fn_nest.blocks = [b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10]
  res_nest = ir_verify_cfg(fn_nest)
  state = assert_eq(state, res_nest.ok, 1, "Complex CFG: 3-level nested loop passes verifier")
  state = assert_eq(state, res_nest.errors.len(), 0, "Complex CFG: 0 errors on nested loops")

  @! Dominator Analysis on 3-level nested loop
  fn_nest.blocks = ir_compute_dominators(fn_nest.blocks)
  state = assert_eq(state, fn_nest.blocks[0].idom, 0, "IDOM(bb_0) == bb_0")
  state = assert_eq(state, fn_nest.blocks[1].idom, 0, "IDOM(outer_cond) == bb_0")
  state = assert_eq(state, fn_nest.blocks[2].idom, 1, "IDOM(outer_body) == outer_cond")
  state = assert_eq(state, fn_nest.blocks[3].idom, 2, "IDOM(mid_cond) == outer_body")
  state = assert_eq(state, fn_nest.blocks[4].idom, 3, "IDOM(mid_body) == mid_cond")
  state = assert_eq(state, fn_nest.blocks[5].idom, 4, "IDOM(inner_cond) == mid_body")
  state = assert_eq(state, fn_nest.blocks[6].idom, 5, "IDOM(inner_body) == inner_cond")
  state = assert_eq(state, fn_nest.blocks[7].idom, 6, "IDOM(inner_step) == inner_body")
  state = assert_eq(state, fn_nest.blocks[8].idom, 5, "IDOM(inner_exit) == inner_cond")
  state = assert_eq(state, fn_nest.blocks[9].idom, 3, "IDOM(mid_exit) == mid_cond")
  state = assert_eq(state, fn_nest.blocks[10].idom, 1, "IDOM(outer_exit) == outer_cond")

  @! Dominance Frontiers on nested loops
  fn_nest.blocks = ir_compute_dominance_frontiers(fn_nest.blocks)
  @! Inner step (7) back-edge to inner cond (5) -> DF(7) contains 5
  df_has_5 = 0
  @for df_id in fn_nest.blocks[7].df
    @if df_id == 5 df_has_5 = 1 @end
  @end
  state = assert_eq(state, df_has_5, 1, "DF(inner_step) contains inner_cond (5)")

  @! Mid exit (9) back-edge to outer cond (1) -> DF(9) contains 1
  df_has_1 = 0
  @for df_id in fn_nest.blocks[9].df
    @if df_id == 1 df_has_1 = 1 @end
  @end
  state = assert_eq(state, df_has_1, 1, "DF(mid_exit) contains outer_cond (1)")

  @! --------------------------------------------------------------------------
  @! Test 2.2: 8-Way Branching (If-Elif Ladder) CFG
  @! --------------------------------------------------------------------------
  fn_ladder = ir_function_new("multiway_branch_8", ["x"], ir_type_i64())
  ladder_blocks = []
  
  @! Entry 0
  entry_l = ir_block_new(0, "entry")
  entry_l.instructions = [ir_inst_branch_cond(ir_val_const_bool(1), 1, 2)]
  entry_l.succs = [1, 2]
  ladder_blocks = ladder_blocks.push(entry_l)

  merge_id = 17
  k = 1
  @while k <= 8
    then_bid = k * 2 - 1
    next_cond_bid = k * 2
    @if k == 8 next_cond_bid = 16 @end

    @! Then block
    b_then = ir_block_new(then_bid, "then_" + k.to_str())
    b_then.preds = [next_cond_bid - 2]
    @if k == 1 b_then.preds = [0] @end
    b_then.instructions = [ir_inst_branch(merge_id)]
    b_then.succs = [merge_id]
    ladder_blocks = ladder_blocks.push(b_then)

    @! Elif cond block
    @if k < 8
      b_cond = ir_block_new(next_cond_bid, "cond_" + k.to_str())
      b_cond.preds = [next_cond_bid - 2]
      @if k == 1 b_cond.preds = [0] @end
      b_cond.instructions = [ir_inst_branch_cond(ir_val_const_bool(1), then_bid + 2, next_cond_bid + 2)]
      b_cond.succs = [then_bid + 2, next_cond_bid + 2]
      ladder_blocks = ladder_blocks.push(b_cond)
    @else
      @! Else block
      b_else = ir_block_new(16, "else_block")
      b_else.preds = [14]
      b_else.instructions = [ir_inst_branch(merge_id)]
      b_else.succs = [merge_id]
      ladder_blocks = ladder_blocks.push(b_else)
    @end
    k = k + 1
  @end

  @! Merge block
  b_merge = ir_block_new(merge_id, "merge")
  b_merge.preds = [1, 3, 5, 7, 9, 11, 13, 15, 16]
  b_merge.instructions = [ir_inst_ret(ir_val_const_int(42, ir_type_i64()), ir_type_i64())]
  b_merge.succs = []
  ladder_blocks = ladder_blocks.push(b_merge)

  fn_ladder.blocks = ladder_blocks
  res_ladder = ir_verify_cfg(fn_ladder)
  state = assert_eq(state, res_ladder.ok, 1, "8-way branch ladder passes CFG verifier")
  state = assert_eq(state, b_merge.preds.len(), 9, "Merge block has 9 incoming predecessor edges")

  @! Dominance computation on 8-way branch ladder
  fn_ladder.blocks = ir_compute_dominators(fn_ladder.blocks)
  state = assert_eq(state, fn_ladder.blocks[0].idom, 0, "IDOM(entry) == entry")
  state = assert_eq(state, fn_ladder.blocks[1].idom, 0, "IDOM(then_1) == entry")
  state = assert_eq(state, fn_ladder.blocks[merge_id].idom, 0, "IDOM(merge) == entry")

  return state
@end

@! ============================================================================
@! 3. AST TO MAYA IR LOWERING STRESS & ADVERSARIAL CASES
@! ============================================================================

@fn test_ast_lowering_stress(state)
  println("▶ [Challenger 1.3] Testing AST-to-IR Lowering Edge Cases...")

  @! Test 3.1: Short-circuit chaining (A && B && C && D)
  var_a = ast_node("Variable")
  var_a.name = "a"
  var_b = ast_node("Variable")
  var_b.name = "b"
  var_c = ast_node("Variable")
  var_c.name = "c"
  var_d = ast_node("Variable")
  var_d.name = "d"

  and_ab = ast_node("BinaryOp")
  and_ab.op = "&&"
  and_ab.left = var_a
  and_ab.right = var_b

  and_abc = ast_node("BinaryOp")
  and_abc.op = "&&"
  and_abc.left = and_ab
  and_abc.right = var_c

  ast_and_4 = ast_node("BinaryOp")
  ast_and_4.op = "&&"
  ast_and_4.left = and_abc
  ast_and_4.right = var_d

  ast_sc_return = ast_node("Return")
  ast_sc_return.expr = ast_and_4
  ast_sc_return.value = ast_and_4

  ast_sc = [
    ast_fndef("test_and_chain", ["a", "b", "c", "d"], "i64", [
      ast_sc_return
    ])
  ]
  
  res_sc = ir_module_from_ast(ast_sc, 0)
  state = assert_eq(state, res_sc.error, 0, "Lowering 4-way short-circuit && succeeds")
  state = assert_true(state, res_sc.module.functions[0].blocks.len() >= 4, "4-way && generates multiple short-circuit branches")
  res_sc_v = ir_verify_module(res_sc.module)
  state = assert_eq(state, res_sc_v.ok, 1, "Generated short-circuit CFG is strictly valid")

  @! Test 3.2: Defer Unwinding across Multiple Return Paths
  ast_defer_fn = ast_fndef("test_defer_unwind", ["cond_flag"], "i64", [
    {
      kind: "Defer",
      name: "",
      params: [],
      body: [],
      ret_type: "",
      val: 0,
      op: "",
      left: 0,
      right: 0,
      expr: {
        kind: "Assign",
        name: "",
        params: [],
        body: [],
        ret_type: "",
        val: 0,
        op: "",
        left: 0,
        right: 0,
        expr: 0,
        condition: 0,
        then_body: [],
        elif_branches: [],
        else_body: [],
        target: "cleanup_1",
        value: { kind: "LiteralInt", name: "", params: [], body: [], ret_type: "", val: 1, op: "", left: 0, right: 0, expr: 0, condition: 0, then_body: [], elif_branches: [], else_body: [], target: "", value: 0, elements: [], args: [], func: 0, variable: "", iterable: 0, index: 0, cond: 0 },
        elements: [],
        args: [],
        func: 0,
        variable: "",
        iterable: 0,
        index: 0,
        cond: 0
      },
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
    },
    {
      kind: "IfStmt",
      name: "",
      params: [],
      body: [],
      ret_type: "",
      val: 0,
      op: "",
      left: 0,
      right: 0,
      expr: 0,
      condition: { kind: "Variable", name: "cond_flag", params: [], body: [], ret_type: "", val: 0, op: "", left: 0, right: 0, expr: 0, condition: 0, then_body: [], elif_branches: [], else_body: [], target: "", value: 0, elements: [], args: [], func: 0, variable: "", iterable: 0, index: 0, cond: 0 },
      then_body: [
        {
          kind: "Return",
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
          value: { kind: "LiteralInt", name: "", params: [], body: [], ret_type: "", val: 10, op: "", left: 0, right: 0, expr: 0, condition: 0, then_body: [], elif_branches: [], else_body: [], target: "", value: 0, elements: [], args: [], func: 0, variable: "", iterable: 0, index: 0, cond: 0 },
          elements: [],
          args: [],
          func: 0,
          variable: "",
          iterable: 0,
          index: 0,
          cond: 0
        }
      ],
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
    },
    {
      kind: "Return",
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
      value: { kind: "LiteralInt", name: "", params: [], body: [], ret_type: "", val: 20, op: "", left: 0, right: 0, expr: 0, condition: 0, then_body: [], elif_branches: [], else_body: [], target: "", value: 0, elements: [], args: [], func: 0, variable: "", iterable: 0, index: 0, cond: 0 },
      elements: [],
      args: [],
      func: 0,
      variable: "",
      iterable: 0,
      index: 0,
      cond: 0
    }
  ])

  res_def = ir_module_from_ast([ast_defer_fn], 0)
  state = assert_eq(state, res_def.error, 0, "Lowering defer statements succeeds")
  res_def_v = ir_verify_module(res_def.module)
  state = assert_eq(state, res_def_v.ok, 1, "Defer lowering produces valid CFG")

  @! Test 3.3: 15-Level Deep Expression Tree Lowering
  @! (1 + (2 + (3 + ... + (14 + 15)...)))
  expr_curr = ast_node("LiteralInt")
  expr_curr.val = 15
  d_i = 14
  @while d_i >= 1
    left_n = ast_node("LiteralInt")
    left_n.val = d_i
    parent_n = ast_node("BinaryOp")
    parent_n.op = "+"
    parent_n.left = left_n
    parent_n.right = expr_curr
    expr_curr = parent_n
    d_i = d_i - 1
  @end
  deep_ret = ast_node("Return")
  deep_ret.expr = expr_curr
  deep_ret.value = expr_curr
  deep_fn = ast_fndef("deep_expr", [], "i64", [
    deep_ret
  ])
  res_deep = ir_module_from_ast([deep_fn], 0)
  state = assert_eq(state, res_deep.error, 0, "Lowering 15-level deep expression tree succeeds")
  state = assert_true(state, res_deep.module.functions[0].blocks[0].instructions.len() >= 14, "Deep expression generates >= 14 instructions")
  res_deep_v = ir_verify_module(res_deep.module)
  state = assert_eq(state, res_deep_v.ok, 1, "Deep expression tree CFG is valid")
  return state
@end

@! ============================================================================
@! MAIN RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🔱 ADVERSARIAL CHALLENGER 1 TEST SUITE: MAYA IR & CFG 🔱")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  state = test_malformed_cfg_invariants(state)
  state = test_complex_cfg_topologies(state)
  state = test_ast_lowering_stress(state)

  println("=================================================================")
  println("📊 CHALLENGER 1 TEST SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  println("=================================================================")

  @if state.failed > 0
    println("❌ CHALLENGER 1 TESTS DETECTED FAILURES!")
    return 1
  @end

  println("🎉 ALL CHALLENGER 1 ADVERSARIAL TESTS PASSED CLEANLY!")
  return 0
@end
