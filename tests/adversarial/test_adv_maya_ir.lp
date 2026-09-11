@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE: MAYA IR & CFG INFRASTRUCTURE
@! Target: compiler/backend/maya_ir.maya
@! Stress testing: Struct Alignment, CFG Verifier Invariant Rejections,
@! Rodata String Deduplication, and System Invariant Boundaries
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"

@struct AdvTestState
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

@! ============================================================================
@! 1. ADVERSARIAL STRUCT LAYOUT & ALIGNMENT STRESS
@! ============================================================================

@fn test_struct_alignment_stress(state)
  println("▶ [Adversarial 1] Struct Layout & 8-Byte Alignment Stress Testing...")

  @! Test 1.1: Empty struct and null fields
  s_empty = ir_type_struct("Empty", [])
  state = assert_eq(state, s_empty.size, 8, "Empty struct size is minimum 8 bytes")
  state = assert_eq(state, s_empty.size % 8, 0, "Empty struct size is 8-byte aligned")

  s_null = ir_type_struct("NullFields", 0)
  state = assert_eq(state, s_null.size, 8, "Null fields struct size is 8 bytes")
  state = assert_eq(state, s_null.size % 8, 0, "Null fields struct size is 8-byte aligned")

  @! Test 1.2: Single odd-sized fields with explicit f_name / f_type schema
  s_i8 = ir_type_struct("SingleI8", [{ f_name: "a", f_type: ir_type_i8() }])
  state = assert_eq(state, s_i8.size, 8, "Single i8 struct size padded to 8 bytes")

  s_i16 = ir_type_struct("SingleI16", [{ f_name: "a", f_type: ir_type_i16() }])
  state = assert_eq(state, s_i16.size, 8, "Single i16 struct size padded to 8 bytes")

  s_i32 = ir_type_struct("SingleI32", [{ f_name: "a", f_type: ir_type_i32() }])
  state = assert_eq(state, s_i32.size, 8, "Single i32 struct size padded to 8 bytes")

  @! Test 1.3: Alternating odd-sized fields (i8, i16, i32, i64, bool, f32)
  odd_fields = [
    { f_name: "f_i8", f_type: ir_type_i8() },
    { f_name: "f_i16", f_type: ir_type_i16() },
    { f_name: "f_i32", f_type: ir_type_i32() },
    { f_name: "f_i64", f_type: ir_type_i64() },
    { f_name: "f_bool", f_type: ir_type_bool() },
    { f_name: "f_f32", f_type: ir_type_f32() }
  ]
  s_odd = ir_type_struct("OddMix", odd_fields)
  state = assert_eq(state, s_odd.size, 48, "OddMix total size is 48 bytes (padded to 8-byte boundary)")
  state = assert_eq(state, s_odd.size % 8, 0, "OddMix size is multiple of 8")

  @! Test 1.4: Deeply nested structs (5 Levels)
  lvl1 = ir_type_struct("Lvl1", [
    { f_name: "a", f_type: ir_type_i8() },
    { f_name: "b", f_type: ir_type_i32() },
    { f_name: "c", f_type: ir_type_i64() }
  ]) @! 3 fields -> size 24
  state = assert_eq(state, lvl1.size, 24, "Level 1 struct size == 24")

  lvl2 = ir_type_struct("Lvl2", [
    { f_name: "l1_a", f_type: lvl1 },
    { f_name: "tag", f_type: ir_type_i16() },
    { f_name: "l1_b", f_type: lvl1 }
  ]) @! lvl1 at 0 (sz 24), tag at 24 (sz 2), lvl1 at 32 (sz 24) -> total 56
  state = assert_eq(state, lvl2.size, 56, "Level 2 struct size == 56")

  lvl3 = ir_type_struct("Lvl3", [
    { f_name: "sub1", f_type: lvl2 },
    { f_name: "sub2", f_type: lvl2 }
  ]) @! 56 + 56 = 112
  state = assert_eq(state, lvl3.size, 112, "Level 3 struct size == 112")

  lvl4 = ir_type_struct("Lvl4", [
    { f_name: "head", f_type: lvl3 },
    { f_name: "flag", f_type: ir_type_bool() },
    { f_name: "tail", f_type: lvl3 }
  ]) @! lvl3 at 0 (112), flag at 112 (1), lvl3 at 120 (112) -> total 232
  state = assert_eq(state, lvl4.size, 232, "Level 4 struct size == 232")

  lvl5 = ir_type_struct("Lvl5", [
    { f_name: "a", f_type: lvl4 },
    { f_name: "b", f_type: lvl4 },
    { f_name: "c", f_type: lvl4 }
  ]) @! 232 * 3 = 696
  state = assert_eq(state, lvl5.size, 696, "Level 5 struct size == 696")
  state = assert_eq(state, lvl5.size % 8, 0, "Level 5 struct size is 8-byte aligned")

  @! Test 1.5: Large struct with 64 fields
  large_fields = []
  k = 0
  @while k < 64
    k_mod = k % 4
    f_t = ir_type_i8()
    @if k_mod == 1 f_t = ir_type_i16()
    @elif k_mod == 2 f_t = ir_type_i32()
    @elif k_mod == 3 f_t = ir_type_i64() @end
    large_fields = large_fields.push({ f_name: "field_" + k.to_str(), f_type: f_t })
    k = k + 1
  @end
  s_large = ir_type_struct("Large64", large_fields)
  state = assert_eq(state, s_large.size, 512, "Large struct 64 fields size == 512 bytes")
  state = assert_eq(state, s_large.size % 8, 0, "Large struct size is 8-byte aligned")

  @! Test 1.6: Struct naming and string representation
  state = assert_str_eq(state, ir_type_to_string(s_large), "%struct.Large64", "Struct type string representation")
  s_anon = ir_type("struct", 8, 0, [], 0)
  state = assert_str_eq(state, ir_type_to_string(s_anon), "%struct.anon", "Anonymous struct type string")

  return state
@end

@! ============================================================================
@! 2. ADVERSARIAL CFG VERIFIER INVARIANT REJECTION STRESS
@! ============================================================================

@fn test_cfg_verifier_rejection_stress(state)
  println("▶ [Adversarial 2] CFG Verifier Invariant Rejections Stress Testing...")

  @! Test 2.1: Function with zero basic blocks
  fn_empty_blocks = ir_function_new("empty_fn", [], ir_type_i64())
  fn_empty_blocks.blocks = []
  res_v0 = ir_verify_cfg(fn_empty_blocks)
  state = assert_eq(state, res_v0.ok, 0, "Verifier rejects function with 0 basic blocks")
  state = assert_true(state, res_v0.errors.len() > 0, "Errors list populated for empty function")

  @! Test 2.2: Entry block ID != 0
  fn_bad_entry_id = ir_function_new("bad_entry_id_fn", [], ir_type_i64())
  fn_bad_entry_id.blocks[0].id = 1
  fn_bad_entry_id.blocks[0].instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  res_v1 = ir_verify_cfg(fn_bad_entry_id)
  state = assert_eq(state, res_v1.ok, 0, "Verifier rejects entry block with ID != 0")

  @! Test 2.3: Entry block has predecessor edges (must have 0)
  fn_entry_pred = ir_function_new("entry_with_preds", [], ir_type_i64())
  fn_entry_pred.blocks[0].preds = [1]
  fn_entry_pred.blocks[0].instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  res_v2 = ir_verify_cfg(fn_entry_pred)
  state = assert_eq(state, res_v2.ok, 0, "Verifier rejects entry block having predecessors")

  @! Test 2.4: Empty basic block (missing terminator)
  fn_empty_insts = ir_function_new("empty_insts_fn", [], ir_type_i64())
  fn_empty_insts.blocks[0].instructions = []
  res_v3 = ir_verify_cfg(fn_empty_insts)
  state = assert_eq(state, res_v3.ok, 0, "Verifier rejects empty basic block")

  @! Test 2.5: Block last instruction is NOT a terminator (ends in ADD)
  fn_no_term = ir_function_new("no_term_fn", [], ir_type_i64())
  fn_no_term.blocks[0].instructions = [ir_inst_add("%v0", ir_val_const_int(1, ir_type_i64()), ir_val_const_int(2, ir_type_i64()), ir_type_i64())]
  res_v4 = ir_verify_cfg(fn_no_term)
  state = assert_eq(state, res_v4.ok, 0, "Verifier rejects block without terminator")

  @! Test 2.6: Unconditional branch target mismatch with succs list
  fn_br_mismatch = ir_function_new("br_mismatch_fn", [], ir_type_i64())
  b0 = fn_br_mismatch.blocks[0]
  b0.succs = [2] @! succs says 2, but inst targets 1
  b0.instructions = [ir_inst_branch(1)]
  b1 = ir_block_new(1, "b1")
  b1.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  b2 = ir_block_new(2, "b2")
  b2.preds = [0]
  b2.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  fn_br_mismatch.blocks = [b0, b1, b2]
  res_v6 = ir_verify_cfg(fn_br_mismatch)
  state = assert_eq(state, res_v6.ok, 0, "Verifier rejects BR target / succs list mismatch")

  @! Test 2.7: Conditional branch targets mismatch with succs list
  fn_cond_mismatch = ir_function_new("cond_mismatch_fn", [], ir_type_i64())
  b0_c = fn_cond_mismatch.blocks[0]
  b0_c.succs = [1, 1] @! succs has duplicate 1, but targets are 1 and 2
  b0_c.instructions = [ir_inst_branch_cond(ir_val_const_bool(1), 1, 2)]
  fn_cond_mismatch.blocks = [b0_c, b1, b2]
  res_v7 = ir_verify_cfg(fn_cond_mismatch)
  state = assert_eq(state, res_v7.ok, 0, "Verifier rejects BR_COND targets / succs list mismatch")

  @! Test 2.8: Return instruction with non-zero successors
  fn_ret_succs = ir_function_new("ret_succs_fn", [], ir_type_i64())
  fn_ret_succs.blocks[0].succs = [1]
  fn_ret_succs.blocks[0].instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  fn_ret_succs.blocks = [fn_ret_succs.blocks[0], b1]
  res_v8 = ir_verify_cfg(fn_ret_succs)
  state = assert_eq(state, res_v8.ok, 0, "Verifier rejects RET instruction with successors")

  @! Test 2.9: Non-existent successor block ID
  fn_bad_succ = ir_function_new("bad_succ_fn", [], ir_type_i64())
  fn_bad_succ.blocks[0].succs = [99]
  fn_bad_succ.blocks[0].instructions = [ir_inst_branch(99)]
  res_v9 = ir_verify_cfg(fn_bad_succ)
  state = assert_eq(state, res_v9.ok, 0, "Verifier rejects non-existent successor ID")

  @! Test 2.10: Missing symmetric predecessor edge
  fn_missing_pred = ir_function_new("missing_pred_fn", [], ir_type_i64())
  b0_m = fn_missing_pred.blocks[0]
  b0_m.succs = [1]
  b0_m.instructions = [ir_inst_branch(1)]
  b1_m = ir_block_new(1, "b1")
  b1_m.preds = [] @! Missing pred back to 0!
  b1_m.instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  fn_missing_pred.blocks = [b0_m, b1_m]
  res_v10 = ir_verify_cfg(fn_missing_pred)
  state = assert_eq(state, res_v10.ok, 0, "Verifier rejects missing symmetric predecessor edge")

  @! Test 2.11: SSA Single Static Assignment violation (duplicate %v0)
  fn_dup_ssa = ir_function_new("dup_ssa_fn", [], ir_type_i64())
  fn_dup_ssa.blocks[0].instructions = [
    ir_inst_add("%v0", ir_val_const_int(1, ir_type_i64()), ir_val_const_int(2, ir_type_i64()), ir_type_i64()),
    ir_inst_mul("%v0", ir_val_reg("%v0", ir_type_i64()), ir_val_const_int(3, ir_type_i64()), ir_type_i64()),
    ir_inst_ret(ir_val_reg("%v0", ir_type_i64()), ir_type_i64())
  ]
  res_v11 = ir_verify_cfg(fn_dup_ssa)
  state = assert_eq(state, res_v11.ok, 0, "Verifier rejects duplicate SSA register definition")

  @! Test 2.12: Phi incoming edges count mismatch with preds count
  fn_phi_mismatch = ir_function_new("phi_mismatch_fn", [], ir_type_i64())
  b0_p = fn_phi_mismatch.blocks[0]
  b0_p.succs = [2]
  b0_p.instructions = [ir_inst_branch(2)]
  b1_p = ir_block_new(1, "b1")
  b1_p.succs = [2]
  b1_p.instructions = [ir_inst_branch(2)]
  b2_p = ir_block_new(2, "join")
  b2_p.preds = [0, 1] @! 2 predecessors, but phi has 1 incoming edge
  b2_p.instructions = [
    ir_inst_phi("%res", [{ block: 0, val: "%v0" }], ir_type_i64()),
    ir_inst_ret(ir_val_reg("%res", ir_type_i64()), ir_type_i64())
  ]
  fn_phi_mismatch.blocks = [b0_p, b1_p, b2_p]
  res_v13 = ir_verify_cfg(fn_phi_mismatch)
  state = assert_eq(state, res_v13.ok, 0, "Verifier rejects Phi incoming count mismatch with predecessor count")

  @! Test 2.13: Unreachable basic block emits warning
  fn_unreach = ir_function_new("unreach_fn", [], ir_type_i64())
  fn_unreach.blocks[0].instructions = [ir_inst_ret(ir_val_const_int(0, ir_type_i64()), ir_type_i64())]
  b_unreach = ir_block_new(1, "unreachable_bb")
  b_unreach.instructions = [ir_inst_ret(ir_val_const_int(42, ir_type_i64()), ir_type_i64())]
  fn_unreach.blocks = [fn_unreach.blocks[0], b_unreach]
  res_v14 = ir_verify_cfg(fn_unreach)
  state = assert_eq(state, res_v14.ok, 1, "Unreachable block does not fail fatal verification if syntax valid")
  state = assert_true(state, res_v14.warnings.len() > 0, "Unreachable block generates warning")

  @! Test 2.14: Module-level verification aggregation
  mod_mixed = ir_module_new("mixed_module")
  mod_mixed = ir_module_add_function(mod_mixed, fn_dup_ssa)       @! Error
  mod_mixed = ir_module_add_function(mod_mixed, fn_empty_blocks)  @! Error
  mod_mixed = ir_module_add_function(mod_mixed, fn_unreach)       @! Warning
  res_mod = ir_verify_module(mod_mixed)
  state = assert_eq(state, res_mod.ok, 0, "Module verifier rejects module containing invalid functions")
  state = assert_true(state, res_mod.errors.len() >= 2, "Module verifier aggregated errors from all functions")
  state = assert_eq(state, res_mod.functions_verified, 3, "Module verified all 3 functions")

  return state
@end

@! ============================================================================
@! 3. ADVERSARIAL RODATA STRING DEDUPLICATION STRESS
@! ============================================================================

@fn test_rodata_deduplication_stress(state)
  println("▶ [Adversarial 3] Rodata String Deduplication Stress Testing...")

  mod = ir_module_new("rodata_stress_mod")

  @! Test 3.1: Basic Duplicate Strings
  ref1 = ir_module_add_string_literal(mod, "hello world")
  ref2 = ir_module_add_string_literal(mod, "hello world")
  ref3 = ir_module_add_string_literal(mod, "hello world")
  state = assert_str_eq(state, ref1.label, ".str.0", "First string label .str.0")
  state = assert_str_eq(state, ref2.label, ".str.0", "Duplicate string reuses .str.0")
  state = assert_str_eq(state, ref3.label, ".str.0", "Duplicate string reuses .str.0 (3rd)")
  state = assert_eq(state, mod.string_literals.len(), 1, "Only 1 string literal in table")
  state = assert_eq(state, mod.rodata_map.len(), 1, "Only 1 rodata entry in rodata_map")

  @! Test 3.2: Empty String Deduplication
  ref_empty1 = ir_module_add_string_literal(mod, "")
  ref_empty2 = ir_module_add_string_literal(mod, "")
  state = assert_str_eq(state, ref_empty1.label, ".str.1", "Empty string label .str.1")
  state = assert_str_eq(state, ref_empty2.label, ".str.1", "Empty string duplicate reuses .str.1")
  state = assert_eq(state, mod.string_literals.len(), 2, "Table has 2 entries (hello + empty)")

  @! Test 3.3: Unicode Strings Deduplication
  ref_u1 = ir_module_add_string_literal(mod, "こんにちは世界")
  ref_u2 = ir_module_add_string_literal(mod, "こんにちは世界")
  ref_emoji1 = ir_module_add_string_literal(mod, "🔥 Maya IR Native 🚀")
  ref_emoji2 = ir_module_add_string_literal(mod, "🔥 Maya IR Native 🚀")
  state = assert_str_eq(state, ref_u1.label, ".str.2", "Unicode Japanese string label .str.2")
  state = assert_str_eq(state, ref_u2.label, ".str.2", "Unicode duplicate reuses .str.2")
  state = assert_str_eq(state, ref_emoji1.label, ".str.3", "Emoji string label .str.3")
  state = assert_str_eq(state, ref_emoji2.label, ".str.3", "Emoji duplicate reuses .str.3")
  state = assert_eq(state, mod.string_literals.len(), 4, "Table has 4 unique entries")

  @! Test 3.4: Large string table stress (100 unique strings x 5 repetitions = 500 insertions)
  large_mod = ir_module_new("large_rodata_mod")
  u_idx = 0
  @while u_idx < 100
    str_val = "constant_token_identifier_key_" + u_idx.to_str()
    rep = 0
    @while rep < 5
      r = ir_module_add_string_literal(large_mod, str_val)
      expected_label = ".str." + u_idx.to_str()
      @if r.label != expected_label
        println("  [FAIL] Label mismatch on repetition " + rep.to_str() + " for " + str_val)
      @end
      rep = rep + 1
    @end
    u_idx = u_idx + 1
  @end

  state = assert_eq(state, large_mod.string_literals.len(), 100, "Large rodata has exactly 100 unique entries after 500 insertions")
  state = assert_eq(state, large_mod.rodata_map.len(), 100, "Large rodata_map has exactly 100 entries")
  state = assert_eq(state, large_mod.next_str_id, 100, "Next string ID counter is exactly 100")

  @! Test 3.5: Module serialization of rodata table
  mod_out = ir_module_to_string(mod)
  state = assert_true(state, string_contains(mod_out, "@.str.0 = private constant"), "Module output contains @.str.0 definition")
  state = assert_true(state, string_contains(mod_out, "@.str.1 = private constant"), "Module output contains @.str.1 definition")
  state = assert_true(state, string_contains(mod_out, "@.str.2 = private constant"), "Module output contains @.str.2 definition")

  return state
@end

@! ============================================================================
@! MAIN RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🔱 ADVERSARIAL CHALLENGE TEST SUITE: MAYA IR & CFG 🔱")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  state = test_struct_alignment_stress(state)
  state = test_cfg_verifier_rejection_stress(state)
  state = test_rodata_deduplication_stress(state)

  println("")
  println("=================================================================")
  println("📊 ADVERSARIAL CHALLENGE SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  @if state.failed == 0
    println("🎉 ALL ADVERSARIAL CHALLENGE TESTS PASSED CLEANLY!")
  @else
    println("❌ ADVERSARIAL CHALLENGE COMPLETED WITH FAILURES!")
  @end
  println("=================================================================")

  @if state.failed == 0
    return 0
  @else
    return 1
  @end
@end
