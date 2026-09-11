@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE — CHALLENGER 2
@! Target: compiler/backend/maya_ir.maya (Native Maya IR & CFG Infrastructure)
@! Focus Areas:
@!   1. Boundary Blocks (Empty, Entry-only, Single-instruction chains)
@!   2. Phi Node Resolution & Diamond CFG Invariants
@!   3. GEP Indexing on Multidimensional Arrays & Deep Nested Structs
@!   4. Synthetic 'main' AST Lowering on Top-Level Scripts & Multi-Fn Modules
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"

@struct TestState
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

@! AST node construction helper
@fn mk_ast(kind)
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

@! ============================================================================
@! 1. BOUNDARY BLOCKS & CONTROL FLOW TOPOLOGIES
@! ============================================================================

@fn test_boundary_blocks(state)
  println("▶ [Challenger 2.1] Boundary Blocks & Control Flow Topologies...")

  @! 1. Function with 0 blocks is rejected
  fn_empty = {
    fn_id: 0,
    name: "fn_empty",
    params: [],
    fn_ret_type: ir_type_void(),
    entry_block: 0,
    blocks: [],
    locals: [],
    next_vreg_id: 0,
    next_block_id: 0,
    is_varargs: 0
  }
  v_empty = ir_verify_cfg(fn_empty)
  state = assert_eq(state, v_empty.ok, 0, "Verifier rejects function with 0 blocks")
  state = assert_true(state, v_empty.errors.len() > 0, "Errors list populated for 0 blocks")

  @! 2. Function with only entry block having a single RET terminator
  fn_single_term = ir_function_new("single_term", [], ir_type_i64())
  entry_b = fn_single_term.blocks[0]
  entry_b = ir_block_add_inst(entry_b, ir_inst_ret(ir_val_const_int(42, ir_type_i64()), ir_type_i64()))
  fn_single_term.blocks[0] = entry_b
  v_single = ir_verify_cfg(fn_single_term)
  state = assert_eq(state, v_single.ok, 1, "Verifier accepts function with entry block + RET")
  state = assert_eq(state, v_single.errors.len(), 0, "Zero errors for valid single-instruction block")

  @! 3. Function with empty block (no terminator) is rejected
  fn_empty_bb = ir_function_new("has_empty_bb", [], ir_type_i64())
  v_empty_bb = ir_verify_cfg(fn_empty_bb)
  state = assert_eq(state, v_empty_bb.ok, 0, "Verifier rejects empty block without terminator")

  @! 4. Single-instruction trampoline chain: bb_0 -> bb_1 -> bb_2 -> bb_3 (RET)
  fn_chain = ir_function_new("chain_fn", [], ir_type_i64())
  bb1 = ir_function_create_block(fn_chain, "trampoline1")
  bb2 = ir_function_create_block(fn_chain, "trampoline2")
  bb3 = ir_function_create_block(fn_chain, "exit")

  @! Connect trampolines with single BR instruction each
  fn_chain.blocks[0] = ir_block_add_inst(fn_chain.blocks[0], ir_inst_br(bb1.id, bb1.name))
  fn_chain.blocks[1] = ir_block_add_inst(fn_chain.blocks[1], ir_inst_br(bb2.id, bb2.name))
  fn_chain.blocks[2] = ir_block_add_inst(fn_chain.blocks[2], ir_inst_br(bb3.id, bb3.name))
  fn_chain.blocks[3] = ir_block_add_inst(fn_chain.blocks[3], ir_inst_ret(ir_val_const_int(100, ir_type_i64()), ir_type_i64()))

  @! Resolve CFG edges symmetrically
  fn_chain = ir_resolve_cfg_edges(fn_chain)
  v_chain = ir_verify_cfg(fn_chain)
  state = assert_eq(state, v_chain.ok, 1, "Verifier accepts 4-block single-instruction trampoline chain")
  state = assert_eq(state, fn_chain.blocks[0].succs.len(), 1, "bb_0 has 1 successor")
  state = assert_eq(state, fn_chain.blocks[1].preds.len(), 1, "bb_1 has 1 predecessor")
  state = assert_eq(state, fn_chain.blocks[2].preds.len(), 1, "bb_2 has 1 predecessor")
  state = assert_eq(state, fn_chain.blocks[3].succs.len(), 0, "Exit block bb_3 has 0 successors")

  @! 5. Dominators across single-instruction chain
  fn_chain.blocks = ir_compute_dominators(fn_chain.blocks)
  state = assert_eq(state, fn_chain.blocks[0].idom, 0, "IDOM(bb_0) == bb_0")
  state = assert_eq(state, fn_chain.blocks[1].idom, 0, "IDOM(bb_1) == bb_0")
  state = assert_eq(state, fn_chain.blocks[2].idom, 1, "IDOM(bb_2) == bb_1")
  state = assert_eq(state, fn_chain.blocks[3].idom, 2, "IDOM(bb_3) == bb_2")

  @! 6. ir_resolve_cfg_edges auto-repair on unterminated block
  fn_auto = ir_function_new("auto_repair", [], ir_type_i64())
  bb_extra = ir_function_create_block(fn_auto, "extra")
  @! Both blocks have 0 instructions
  fn_auto = ir_resolve_cfg_edges(fn_auto)
  v_auto = ir_verify_cfg(fn_auto)
  state = assert_eq(state, v_auto.ok, 1, "ir_resolve_cfg_edges auto-terminates fallthrough blocks")
  state = assert_eq(state, fn_auto.blocks[0].succs[0], bb_extra.id, "Auto-inserted fallthrough jump to bb_1")

  return state
@end

@! ============================================================================
@! 2. PHI NODE RESOLUTION ACROSS DIAMOND CFGS
@! ============================================================================

@fn test_phi_and_diamond_cfg(state)
  println("▶ [Challenger 2.2] Phi Node Resolution & Diamond CFG Invariants...")

  @! Build Diamond CFG: bb_0 (Entry) -> bb_1 (Then), bb_2 (Else) -> bb_3 (Merge)
  fn_diamond = ir_function_new("diamond_phi", ["cond_arg"], ir_type_i64())
  bb_then = ir_function_create_block(fn_diamond, "then_blk")
  bb_else = ir_function_create_block(fn_diamond, "else_blk")
  bb_merge = ir_function_create_block(fn_diamond, "merge_blk")

  @! bb_0: br_cond %param_cond_arg, bb_then, bb_else
  param_cond = ir_val_param(0, "cond_arg", ir_type_i64())
  fn_diamond.blocks[0] = ir_block_add_inst(fn_diamond.blocks[0], ir_inst_br_cond(param_cond, bb_then.id, bb_then.name, bb_else.id, bb_else.name))

  @! bb_1 (then): %v1 = add 10, 20 -> br bb_merge
  v1 = ir_val_reg("%v1", ir_type_i64())
  fn_diamond.blocks[1] = ir_block_add_inst(fn_diamond.blocks[1], ir_inst_add("%v1", ir_val_const_int(10, ir_type_i64()), ir_val_const_int(20, ir_type_i64()), ir_type_i64()))
  fn_diamond.blocks[1] = ir_block_add_inst(fn_diamond.blocks[1], ir_inst_br(bb_merge.id, bb_merge.name))

  @! bb_2 (else): %v2 = mul 5, 6 -> br bb_merge
  v2 = ir_val_reg("%v2", ir_type_i64())
  fn_diamond.blocks[2] = ir_block_add_inst(fn_diamond.blocks[2], ir_inst_mul("%v2", ir_val_const_int(5, ir_type_i64()), ir_val_const_int(6, ir_type_i64()), ir_type_i64()))
  fn_diamond.blocks[2] = ir_block_add_inst(fn_diamond.blocks[2], ir_inst_br(bb_merge.id, bb_merge.name))

  @! bb_3 (merge): %res = phi i64 [ %v1, %bb_1 ], [ %v2, %bb_2 ] -> ret %res
  res_val = ir_val_reg("%res", ir_type_i64())
  phi_incoming = [
    { phi_val: v1, phi_block_id: bb_then.id },
    { phi_val: v2, phi_block_id: bb_else.id }
  ]
  phi_inst = ir_inst_phi("%res", phi_incoming, ir_type_i64())
  fn_diamond.blocks[3] = ir_block_add_inst(fn_diamond.blocks[3], phi_inst)
  fn_diamond.blocks[3] = ir_block_add_inst(fn_diamond.blocks[3], ir_inst_ret(res_val, ir_type_i64()))

  @! Resolve edges and verify
  fn_diamond = ir_resolve_cfg_edges(fn_diamond)
  v_diamond = ir_verify_cfg(fn_diamond)
  state = assert_eq(state, v_diamond.ok, 1, "Valid diamond CFG with Phi node passes verifier")
  state = assert_eq(state, fn_diamond.blocks[3].preds.len(), 2, "Merge block has 2 predecessors")
  state = assert_eq(state, fn_diamond.blocks[3].instructions[0].incoming.len(), 2, "Phi node has 2 incoming edges")

  @! Verifier Rejection: Phi incoming count mismatch (1 incoming edge for 2 preds)
  fn_bad_phi = ir_function_new("bad_phi", [], ir_type_i64())
  b_then = ir_function_create_block(fn_bad_phi, "then")
  b_else = ir_function_create_block(fn_bad_phi, "else")
  b_join = ir_function_create_block(fn_bad_phi, "join")
  fn_bad_phi.blocks[0] = ir_block_add_inst(fn_bad_phi.blocks[0], ir_inst_br_cond(ir_val_const_int(1, ir_type_i64()), b_then.id, b_then.name, b_else.id, b_else.name))
  fn_bad_phi.blocks[1] = ir_block_add_inst(fn_bad_phi.blocks[1], ir_inst_br(b_join.id, b_join.name))
  fn_bad_phi.blocks[2] = ir_block_add_inst(fn_bad_phi.blocks[2], ir_inst_br(b_join.id, b_join.name))
  @! Only 1 incoming branch in phi node
  bad_phi_inst = ir_inst_phi("%r", [{ phi_val: v1, phi_block_id: b_then.id }], ir_type_i64())
  fn_bad_phi.blocks[3] = ir_block_add_inst(fn_bad_phi.blocks[3], bad_phi_inst)
  fn_bad_phi.blocks[3] = ir_block_add_inst(fn_bad_phi.blocks[3], ir_inst_ret(ir_val_reg("%r", ir_type_i64()), ir_type_i64()))
  fn_bad_phi = ir_resolve_cfg_edges(fn_bad_phi)
  v_bad_phi = ir_verify_cfg(fn_bad_phi)
  state = assert_eq(state, v_bad_phi.ok, 0, "Verifier rejects Phi node with mismatched incoming edges count")

  @! Verifier Rejection: Phi instruction placed after non-phi instruction
  fn_phi_order = ir_function_new("phi_order", [], ir_type_i64())
  bo_then = ir_function_create_block(fn_phi_order, "then")
  bo_else = ir_function_create_block(fn_phi_order, "else")
  bo_join = ir_function_create_block(fn_phi_order, "join")
  fn_phi_order.blocks[0] = ir_block_add_inst(fn_phi_order.blocks[0], ir_inst_br_cond(ir_val_const_int(1, ir_type_i64()), bo_then.id, bo_then.name, bo_else.id, bo_else.name))
  fn_phi_order.blocks[1] = ir_block_add_inst(fn_phi_order.blocks[1], ir_inst_br(bo_join.id, bo_join.name))
  fn_phi_order.blocks[2] = ir_block_add_inst(fn_phi_order.blocks[2], ir_inst_br(bo_join.id, bo_join.name))
  @! Put ADD before PHI
  fn_phi_order.blocks[3] = ir_block_add_inst(fn_phi_order.blocks[3], ir_inst_add("%pre", ir_val_const_int(1, ir_type_i64()), ir_val_const_int(2, ir_type_i64()), ir_type_i64()))
  fn_phi_order.blocks[3] = ir_block_add_inst(fn_phi_order.blocks[3], phi_inst)
  fn_phi_order.blocks[3] = ir_block_add_inst(fn_phi_order.blocks[3], ir_inst_ret(res_val, ir_type_i64()))
  fn_phi_order = ir_resolve_cfg_edges(fn_phi_order)
  v_phi_order = ir_verify_cfg(fn_phi_order)
  state = assert_eq(state, v_phi_order.ok, 0, "Verifier rejects Phi node placed after non-phi instruction")

  return state
@end

@! ============================================================================
@! 3. GEP INDEXING ON ARRAYS & DEEPLY NESTED STRUCTS
@! ============================================================================

@fn test_gep_and_nested_structs(state)
  println("▶ [Challenger 2.3] GEP Indexing on Arrays & Deeply Nested Structs...")

  @! 1. 1D Array Type & GEP
  t_arr_1d = ir_type_array(ir_type_i64(), 10)
  state = assert_eq(state, t_arr_1d.size, 80, "1D Array [10 x i64] size == 80 bytes")
  state = assert_str_eq(state, ir_type_to_string(t_arr_1d), "[10 x i64]", "1D Array type string")

  gep_arr = ir_inst_gep("%elem_ptr", ir_val_reg("%arr_base", ir_type_ptr(t_arr_1d)), ir_val_const_int(4, ir_type_i64()), ir_type_i64(), 8)
  gep_arr_str = ir_inst_to_string(gep_arr)
  state = assert_true(state, string_contains(gep_arr_str, "%elem_ptr = gep"), "Array GEP instruction formatting")
  state = assert_true(state, string_contains(gep_arr_str, "ptr %arr_base"), "Array GEP base pointer")
  state = assert_true(state, string_contains(gep_arr_str, "i64 4"), "Array GEP index operand")

  @! 2. 2D Array Type [5 x [10 x f64]]
  t_row = ir_type_array(ir_type_f64(), 10)
  t_matrix = ir_type_array(t_row, 5)
  state = assert_eq(state, t_matrix.size, 400, "2D Matrix [5 x [10 x f64]] size == 400 bytes (5 * 10 * 8)")

  @! 3. Nested Struct Layouts: Vec3 -> Transform -> Actor
  f_vec3 = [
    { f_name: "x", f_type: ir_type_f64(), f_offset: 0, f_size: 8 },
    { f_name: "y", f_type: ir_type_f64(), f_offset: 0, f_size: 8 },
    { f_name: "z", f_type: ir_type_f64(), f_offset: 0, f_size: 8 }
  ]
  t_vec3 = ir_type_struct("Vec3", f_vec3)
  state = assert_eq(state, t_vec3.size, 24, "Vec3 size == 24 bytes")

  f_transform = [
    { f_name: "pos", f_type: t_vec3, f_offset: 0, f_size: 24 },
    { f_name: "rot", f_type: t_vec3, f_offset: 0, f_size: 24 },
    { f_name: "scale", f_type: t_vec3, f_offset: 0, f_size: 24 }
  ]
  t_transform = ir_type_struct("Transform", f_transform)
  state = assert_eq(state, t_transform.size, 72, "Transform size == 72 bytes (3 * 24)")

  f_actor = [
    { f_name: "id", f_type: ir_type_i64(), f_offset: 0, f_size: 8 },
    { f_name: "xform", f_type: t_transform, f_offset: 0, f_size: 72 },
    { f_name: "flags", f_type: ir_type_i32(), f_offset: 0, f_size: 4 }
  ]
  t_actor = ir_type_struct("Actor", f_actor)
  @! Offset calculation: id @ 0 (8B), xform @ 8 (72B), flags @ 80 (4B) -> total 84, aligned to 88 (multiple of 8)
  state = assert_eq(state, t_actor.size, 88, "Actor size aligned to 88 bytes (multiple of 8)")
  state = assert_eq(state, t_actor.size % 8, 0, "Actor size is 8-byte aligned")
  state = assert_eq(state, t_actor.fields[0].f_offset, 0, "Actor.id offset == 0")
  state = assert_eq(state, t_actor.fields[1].f_offset, 8, "Actor.xform offset == 8")
  state = assert_eq(state, t_actor.fields[2].f_offset, 80, "Actor.flags offset == 80")

  @! 4. Array of Structs: [16 x Actor]
  t_actor_array = ir_type_array(t_actor, 16)
  state = assert_eq(state, t_actor_array.size, 1408, "Actor array [16 x Actor] size == 1408 bytes (16 * 88)")

  @! 5. GEP into nested struct field
  gep_actor_xform = ir_inst_gep("%xform_ptr", ir_val_reg("%actor_base", ir_type_ptr(t_actor)), ir_val_const_int(1, ir_type_i64()), t_transform, 72)
  state = assert_str_eq(state, ir_inst_to_string(gep_actor_xform), "%xform_ptr = gep %struct.Transform, ptr %actor_base, i64 1", "Struct field GEP formatting")

  return state
@end

@! ============================================================================
@! 4. SYNTHETIC 'MAIN' AST LOWERING ON SCRIPTS & MULTI-FUNCTION MODULES
@! ============================================================================

@fn test_synthetic_main_lowering(state)
  println("▶ [Challenger 2.4] Synthetic 'main' AST Lowering on Top-Level Scripts...")

  @! Case 1: Multi-statement top-level script without explicit @fn main()
  @! Script:
  @!   a = 10
  @!   b = 20
  @!   c = a + b
  @!   print(c)
  s1 = mk_ast("VarDecl")
  s1.target = "a"
  s1.value = mk_ast("LiteralInt")
  s1.value.val = 10

  s2 = mk_ast("VarDecl")
  s2.target = "b"
  s2.value = mk_ast("LiteralInt")
  s2.value.val = 20

  s3 = mk_ast("VarDecl")
  s3.target = "c"
  s3.value = mk_ast("BinaryOp")
  s3.value.op = "+"
  s3.value.left = mk_ast("Variable")
  s3.value.left.name = "a"
  s3.value.right = mk_ast("Variable")
  s3.value.right.name = "b"

  s4 = mk_ast("ExprStmt")
  s4.expr = mk_ast("Call")
  s4.expr.func = mk_ast("Variable")
  s4.expr.func.name = "print"
  s4.expr.args = [mk_ast("Variable")]
  s4.expr.args[0].name = "c"

  ast_script = [s1, s2, s3, s4]
  res_mod1 = ir_module_from_ast(ast_script, { module_name: "synthetic_script_test" })

  state = assert_eq(state, res_mod1.error, 0, "Lowering multi-statement script succeeds with error=0")
  state = assert_eq(state, res_mod1.module.functions.len(), 1, "Synthesized exactly 1 function")
  state = assert_str_eq(state, res_mod1.module.functions[0].name, "main", "Synthesized function name is 'main'")
  state = assert_true(state, res_mod1.module.functions[0].blocks.len() >= 1, "Synthetic main has basic blocks")
  state = assert_eq(state, res_mod1.module.functions[0].blocks[0].is_terminated, 1, "Synthetic main entry is terminated")

  @! Case 2: Script with BOTH user function definitions AND top-level script statements
  @! fn helper(x) { return x * 2 }
  @! y = helper(5)
  fn_helper_body = [mk_ast("Return")]
  fn_helper_body[0].value = mk_ast("BinaryOp")
  fn_helper_body[0].value.op = "*"
  fn_helper_body[0].value.left = mk_ast("Variable")
  fn_helper_body[0].value.left.name = "x"
  fn_helper_body[0].value.right = mk_ast("LiteralInt")
  fn_helper_body[0].value.right.val = 2

  fn_helper_ast = ast_fndef("helper", ["x"], "i64", fn_helper_body)

  top_call = mk_ast("VarDecl")
  top_call.target = "y"
  top_call.value = mk_ast("Call")
  top_call.value.func = mk_ast("Variable")
  top_call.value.func.name = "helper"
  top_call.value.args = [mk_ast("LiteralInt")]
  top_call.value.args[0].val = 5

  ast_mixed = [fn_helper_ast, top_call]
  res_mod2 = ir_module_from_ast(ast_mixed, { module_name: "mixed_module_test" })

  state = assert_eq(state, res_mod2.error, 0, "Lowering mixed script + function module succeeds with error=0")
  state = assert_eq(state, res_mod2.module.functions.len(), 2, "Module contains 2 functions (helper + synthetic main)")
  state = assert_str_eq(state, res_mod2.module.functions[0].name, "helper", "First function is 'helper'")
  state = assert_str_eq(state, res_mod2.module.functions[1].name, "main", "Second function is synthetic 'main'")

  @! Case 3: Script with EXPLICIT @fn main() -> should NOT create duplicate synthetic main
  fn_explicit_main_body = [mk_ast("Return")]
  fn_explicit_main_body[0].value = mk_ast("LiteralInt")
  fn_explicit_main_body[0].value.val = 0
  fn_explicit_main = ast_fndef("main", [], "i64", fn_explicit_main_body)

  ast_explicit = [fn_explicit_main]
  res_mod3 = ir_module_from_ast(ast_explicit, { module_name: "explicit_main_test" })

  state = assert_eq(state, res_mod3.error, 0, "Explicit main lowers cleanly with error=0")
  state = assert_eq(state, res_mod3.module.functions.len(), 1, "Module contains exactly 1 function (no duplicate main)")
  state = assert_str_eq(state, res_mod3.module.functions[0].name, "main", "Function name is 'main'")

  @! Case 4: Empty AST script (0 statements) -> 0 functions, passes verification
  res_mod4 = ir_module_from_ast([], { module_name: "empty_mod_test" })
  state = assert_eq(state, res_mod4.error, 0, "Empty AST module lowers cleanly with error=0")
  state = assert_eq(state, res_mod4.module.functions.len(), 0, "Empty module contains 0 functions")

  return state
@end

@! ============================================================================
@! MAIN RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🔱 ADVERSARIAL STRESS SUITE: CHALLENGER 2 (MAYA IR & CFG) 🔱")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  state = test_boundary_blocks(state)
  state = test_phi_and_diamond_cfg(state)
  state = test_gep_and_nested_structs(state)
  state = test_synthetic_main_lowering(state)

  println("\n=================================================================")
  println("📊 CHALLENGER 2 SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  @if state.failed == 0
    println("🎉 ALL CHALLENGER 2 STRESS TESTS PASSED CLEANLY!")
  @else
    println("❌ CHALLENGER 2 DETECTED FAILURES!")
  @end
  println("=================================================================")

  @if state.failed > 0
    return 1
  @end
  return 0
@end
