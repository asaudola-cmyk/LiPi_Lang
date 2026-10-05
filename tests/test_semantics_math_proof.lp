// ==============================================================================
// 🧪 LIPI COMPILER TEST: MATHEMATICAL MEMORY SAFETY & CFG PROOF SUITE
// File: tests/test_semantics_math_proof.lp
// Version: First 1.0.0 (প্রথম ১.০.০) — Sovereign Edition
// 100% Pure LiPi Implementation — Zero External Dependencies
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/frontend/ast/ast_node"
import "compiler/semantics/symbol"
import "compiler/semantics/math_proof"

@fn assert_true(cond, test_name)
  @if cond == 1
    say("  [PASS] " + test_name)
    return 1
  @else
    say("  [FAIL] " + test_name)
    exit(1)
    return 0
  @end
@end

@fn test_legacy_cfg_proofs()
  say("── 1. Testing Universal CFG Node Proofs (analyze_cfg_node & prove_memory_safety) ──")

  // Test 1.1: Balanced sequence: ALLOC -> FREE
  seq_balanced = cfg_node_seq(cfg_node_alloc(), cfg_node_free())
  assert_true(analyze_cfg_node(seq_balanced, 0) == 0, "ALLOC + FREE yields net delta = 0")
  assert_true(prove_memory_safety(seq_balanced) == 1, "ALLOC + FREE proved memory safe")

  // Test 1.2: Unbalanced sequence: ALLOC without FREE
  seq_leak = cfg_node_alloc()
  assert_true(analyze_cfg_node(seq_leak, 0) == 1, "Single ALLOC yields net delta = 1 (leak)")
  assert_true(prove_memory_safety(seq_leak) == 0, "Single ALLOC rejected as memory unsafe")

  // Test 1.3: Underflow: FREE without ALLOC
  seq_underflow = cfg_node_free()
  assert_true(analyze_cfg_node(seq_underflow, 0) == -1, "Single FREE yields net delta = -1 (underflow)")
  assert_true(prove_memory_safety(seq_underflow) == 0, "Single FREE rejected as memory unsafe")

  // Test 1.4: Balanced Branching: True path (ALLOC+FREE) vs False path (ALLOC+FREE)
  br_true = cfg_node_seq(cfg_node_alloc(), cfg_node_free())
  br_false = cfg_node_seq(cfg_node_alloc(), cfg_node_free())
  br_balanced = cfg_node_branch(br_true, br_false)
  assert_true(analyze_cfg_node(br_balanced, 0) == 0, "Symmetric balanced branch yields delta = 0")
  assert_true(prove_memory_safety(br_balanced) == 1, "Symmetric branch proved memory safe")

  // Test 1.5: Imbalanced Branching: True path (ALLOC) vs False path (FREE)
  br_imbalanced = cfg_node_branch(cfg_node_alloc(), cfg_node_free())
  assert_true(analyze_cfg_node(br_imbalanced, 0) == -9999, "Asymmetric branch returns -9999 (imbalanced paths)")
  assert_true(prove_memory_safety(br_imbalanced) == 0, "Asymmetric branch rejected as unsafe")

  // Test 1.6: Balanced Loop: Body has ALLOC + FREE
  loop_body_bal = cfg_node_seq(cfg_node_alloc(), cfg_node_free())
  loop_balanced = cfg_node_loop(loop_body_bal)
  assert_true(analyze_cfg_node(loop_balanced, 0) == 0, "Balanced loop body conserves memory across iterations")
  assert_true(prove_memory_safety(loop_balanced) == 1, "Balanced loop proved memory safe")

  // Test 1.7: Leaking Loop: Body has ALLOC without FREE
  loop_leaking = cfg_node_loop(cfg_node_alloc())
  assert_true(analyze_cfg_node(loop_leaking, 0) == -9999, "Leaking loop returns -9999 (unbounded accumulation)")
  assert_true(prove_memory_safety(loop_leaking) == 0, "Leaking loop rejected as unsafe")

  return 1
@end

@fn test_ast_linear_proofs()
  say("── 2. Testing AST Linear Execution & Variable Lifetime Proofs ──")

  // Clean routine: fn clean() { return 0 }
  fn_clean = ast_node("FnDef")
  fn_clean.name = "clean_func"
  ret_0 = ast_node("Return")
  fn_clean.body = [ret_0]

  eng1 = math_proof_engine_new()
  cert1 = math_proof_verify_fn(eng1, fn_clean)
  assert_true(cert1.mpc_is_proven == 1, "Clean routine mathematically proved (ΔMemory = 0)")
  assert_true(cert1.mpc_net_delta == 0, "Net memory delta is exactly 0")
  assert_true(cert1.mpc_violation_count == 0, "Zero violations detected")

  // Balanced routine:
  // fn balanced() {
  //   buf = alloc()
  //   free(buf)
  //   return 0
  // }
  fn_bal = ast_node("FnDef")
  fn_bal.name = "balanced_func"

  call_alloc = ast_node("Call")
  call_alloc.name = "alloc"
  call_alloc.args = []

  assign_buf = ast_node("Assign")
  assign_buf.target = "buf"
  assign_buf.value = call_alloc

  var_buf = ast_node("Variable")
  var_buf.name = "buf"

  call_free = ast_node("Call")
  call_free.name = "free"
  call_free.args = [var_buf]

  fn_bal.body = [assign_buf, call_free, ret_0]

  eng2 = math_proof_engine_new()
  cert2 = math_proof_verify_fn(eng2, fn_bal)
  assert_true(cert2.mpc_is_proven == 1, "Balanced alloc/free pair proved memory safe")
  assert_true(cert2.mpc_total_allocations == 1, "Tracked exactly 1 allocation")
  assert_true(cert2.mpc_total_deallocations == 1, "Tracked exactly 1 deallocation")
  assert_true(cert2.mpc_net_delta == 0, "Net delta = 0 (Memory Conserved)")

  // Leaking routine:
  // fn leak() {
  //   buf = alloc()
  //   return 0
  // }
  fn_leak = ast_node("FnDef")
  fn_leak.name = "leaking_func"
  fn_leak.body = [assign_buf, ret_0]

  eng3 = math_proof_engine_new()
  cert3 = math_proof_verify_fn(eng3, fn_leak)
  assert_true(cert3.mpc_is_proven == 0, "Leaking function proof fails")
  assert_true(cert3.mpc_net_delta == 1, "Net delta is +1 (unfreed memory)")
  assert_true(cert3.mpc_violation_count > 0, "Memory leak violation recorded")

  // Double free routine:
  // fn dbl_free() {
  //   buf = alloc()
  //   free(buf)
  //   free(buf)
  // }
  fn_df = ast_node("FnDef")
  fn_df.name = "double_free_func"
  fn_df.body = [assign_buf, call_free, call_free]

  eng4 = math_proof_engine_new()
  cert4 = math_proof_verify_fn(eng4, fn_df)
  assert_true(cert4.mpc_is_proven == 0, "Double free routine proof fails")
  assert_true(cert4.mpc_violation_count > 0, "Double free violation recorded")

  return 1
@end

@fn test_ast_branching_proofs()
  say("── 3. Testing AST Control Flow Graph Branch Symmetry Proofs ──")

  call_alloc = ast_node("Call")
  call_alloc.name = "alloc"
  call_alloc.args = []

  assign_a = ast_node("Assign")
  assign_a.target = "a"
  assign_a.value = call_alloc

  var_a = ast_node("Variable")
  var_a.name = "a"

  call_free_a = ast_node("Call")
  call_free_a.name = "free"
  call_free_a.args = [var_a]

  assign_b = ast_node("Assign")
  assign_b.target = "b"
  assign_b.value = call_alloc

  var_b = ast_node("Variable")
  var_b.name = "b"

  call_free_b = ast_node("Call")
  call_free_b.name = "free"
  call_free_b.args = [var_b]

  // Branch 1: Symmetric balanced branches
  // if cond { a = alloc(); free(a); } else { b = alloc(); free(b); }
  if_sym = ast_node("IfStmt")
  if_sym.condition = ast_node("Variable")
  if_sym.then_body = [assign_a, call_free_a]
  if_sym.else_body = [assign_b, call_free_b]

  fn_sym = ast_node("FnDef")
  fn_sym.name = "sym_branch_func"
  fn_sym.body = [if_sym]

  eng_sym = math_proof_engine_new()
  cert_sym = math_proof_verify_fn(eng_sym, fn_sym)
  assert_true(cert_sym.mpc_is_proven == 1, "Symmetric branch proved memory safe across all paths")
  assert_true(cert_sym.mpc_paths_verified >= 2, "Verified multiple CFG paths")

  // Branch 2: Asymmetric branches (then has leak, else is clean)
  // if cond { a = alloc(); } else { b = alloc(); free(b); }
  if_asym = ast_node("IfStmt")
  if_asym.condition = ast_node("Variable")
  if_asym.then_body = [assign_a] // leak
  if_asym.else_body = [assign_b, call_free_b]

  fn_asym = ast_node("FnDef")
  fn_asym.name = "asym_branch_func"
  fn_asym.body = [if_asym]

  eng_asym = math_proof_engine_new()
  cert_asym = math_proof_verify_fn(eng_asym, fn_asym)
  assert_true(cert_asym.mpc_is_proven == 0, "Asymmetric branch rejected as memory unsafe")
  assert_true(cert_asym.mpc_violation_count > 0, "Branch imbalance violation recorded")

  // Branch 3: Missing else branch with allocating then branch
  // if cond { a = alloc(); }
  if_no_else = ast_node("IfStmt")
  if_no_else.condition = ast_node("Variable")
  if_no_else.then_body = [assign_a]
  if_no_else.else_body = []

  fn_no_else = ast_node("FnDef")
  fn_no_else.name = "no_else_branch_func"
  fn_no_else.body = [if_no_else]

  eng_ne = math_proof_engine_new()
  cert_ne = math_proof_verify_fn(eng_ne, fn_no_else)
  assert_true(cert_ne.mpc_is_proven == 0, "Allocating if without else rejected (fallthrough imbalance)")

  return 1
@end

@fn test_ast_loop_proofs()
  say("── 4. Testing AST Loop Iteration Invariance Proofs (while & for) ──")

  call_alloc = ast_node("Call")
  call_alloc.name = "alloc"
  call_alloc.args = []

  assign_tmp = ast_node("Assign")
  assign_tmp.target = "tmp"
  assign_tmp.value = call_alloc

  var_tmp = ast_node("Variable")
  var_tmp.name = "tmp"

  call_free_tmp = ast_node("Call")
  call_free_tmp.name = "free"
  call_free_tmp.args = [var_tmp]

  // Loop 1: Balanced loop
  // while cond { tmp = alloc(); free(tmp); }
  while_bal = ast_node("WhileLoop")
  while_bal.body = [assign_tmp, call_free_tmp]

  fn_while_bal = ast_node("FnDef")
  fn_while_bal.name = "balanced_loop_func"
  fn_while_bal.body = [while_bal]

  eng_wb = math_proof_engine_new()
  cert_wb = math_proof_verify_fn(eng_wb, fn_while_bal)
  assert_true(cert_wb.mpc_is_proven == 1, "Balanced loop body satisfies iteration invariant (Δ=0)")
  assert_true(cert_wb.mpc_loops_verified >= 1, "Tracked loop invariant check")

  // Loop 2: Leaking loop
  // while cond { tmp = alloc(); }
  while_leak = ast_node("WhileLoop")
  while_leak.body = [assign_tmp]

  fn_while_leak = ast_node("FnDef")
  fn_while_leak.name = "leaking_loop_func"
  fn_while_leak.body = [while_leak]

  eng_wl = math_proof_engine_new()
  cert_wl = math_proof_verify_fn(eng_wl, fn_while_leak)
  assert_true(cert_wl.mpc_is_proven == 0, "Leaking loop rejected (unbounded iteration leak)")
  assert_true(cert_wl.mpc_violation_count > 0, "Loop leak violation recorded")

  return 1
@end

@fn test_ast_scope_lifetime_proofs()
  say("── 5. Testing Lexical Scope Lifetime Encapsulation Proofs ──")

  call_alloc = ast_node("Call")
  call_alloc.name = "alloc"
  call_alloc.args = []

  assign_sc = ast_node("Assign")
  assign_sc.target = "scoped_var"
  assign_sc.value = call_alloc

  var_sc = ast_node("Variable")
  var_sc.name = "scoped_var"

  call_free_sc = ast_node("Call")
  call_free_sc.name = "free"
  call_free_sc.args = [var_sc]

  // Scope 1: Balanced inner block
  blk_bal = ast_node("Block")
  blk_bal.body = [assign_sc, call_free_sc]

  fn_blk_bal = ast_node("FnDef")
  fn_blk_bal.name = "balanced_block_func"
  fn_blk_bal.body = [blk_bal]

  eng_bb = math_proof_engine_new()
  cert_bb = math_proof_verify_fn(eng_bb, fn_blk_bal)
  assert_true(cert_bb.mpc_is_proven == 1, "Balanced block scope proved memory safe")
  assert_true(cert_bb.mpc_scopes_verified >= 2, "Verified nested lexical scopes")

  // Scope 2: Leaking inner block (variable allocated in block, not freed before block exit)
  blk_leak = ast_node("Block")
  blk_leak.body = [assign_sc] // no free in block

  fn_blk_leak = ast_node("FnDef")
  fn_blk_leak.name = "leaking_block_func"
  fn_blk_leak.body = [blk_leak]

  eng_bl = math_proof_engine_new()
  cert_bl = math_proof_verify_fn(eng_bl, fn_blk_leak)
  assert_true(cert_bl.mpc_is_proven == 0, "Scope escape rejected as memory unsafe")
  assert_true(cert_bl.mpc_violation_count > 0, "Scope escape violation recorded")

  return 1
@end

@fn test_ast_early_return_proofs()
  say("── 6. Testing Early Returns & Divergent CFG Path Proofs ──")

  call_alloc = ast_node("Call")
  call_alloc.name = "alloc"
  call_alloc.args = []

  assign_x = ast_node("Assign")
  assign_x.target = "x"
  assign_x.value = call_alloc

  var_x = ast_node("Variable")
  var_x.name = "x"
  call_free_x = ast_node("Call")
  call_free_x.name = "free"
  call_free_x.args = [var_x]

  ret_0 = ast_node("Return")

  // Function with early return leak:
  // fn early_leak() {
  //   x = alloc()
  //   if cond { return 0 } // leaks x on true branch!
  //   free(x)
  //   return 0
  // }
  if_early = ast_node("IfStmt")
  if_early.condition = ast_node("Variable")
  if_early.then_body = [ret_0]
  if_early.else_body = []

  fn_early = ast_node("FnDef")
  fn_early.name = "early_return_leak"
  fn_early.body = [assign_x, if_early, call_free_x, ret_0]

  eng1 = math_proof_engine_new()
  cert1 = math_proof_verify_fn(eng1, fn_early)
  assert_true(cert1.mpc_is_proven == 0, "Early return leak correctly rejected as memory unsafe")
  assert_true(cert1.mpc_violation_count > 0, "Early return leak violation recorded in certificate")

  return 1
@end

@fn test_ast_break_loop_proofs()
  say("── 7. Testing Loop Breaks & Divergent Exit Edges ──")

  call_alloc = ast_node("Call")
  call_alloc.name = "alloc"
  call_alloc.args = []

  assign_x = ast_node("Assign")
  assign_x.target = "x"
  assign_x.value = call_alloc

  var_x = ast_node("Variable")
  var_x.name = "x"
  call_free_x = ast_node("Call")
  call_free_x.name = "free"
  call_free_x.args = [var_x]

  brk = ast_node("Break")

  // Loop with break leaking memory:
  // while cond { x = alloc(); break; free(x); }
  while_brk = ast_node("WhileLoop")
  while_brk.body = [assign_x, brk, call_free_x]

  fn_brk = ast_node("FnDef")
  fn_brk.name = "loop_break_leak"
  fn_brk.body = [while_brk]

  eng2 = math_proof_engine_new()
  cert2 = math_proof_verify_fn(eng2, fn_brk)
  assert_true(cert2.mpc_is_proven == 0, "Loop break leak correctly rejected as memory unsafe")
  assert_true(cert2.mpc_violation_count > 0, "Loop break violation recorded in certificate")

  return 1
@end

@fn test_ast_cross_scope_reassign_proofs()
  say("── 8. Testing Cross-Scope Variable Reassignment Protection ──")

  call_alloc = ast_node("Call")
  call_alloc.name = "alloc"
  call_alloc.args = []

  assign_x = ast_node("Assign")
  assign_x.target = "x"
  assign_x.value = call_alloc

  var_x = ast_node("Variable")
  var_x.name = "x"
  call_free_x = ast_node("Call")
  call_free_x.name = "free"
  call_free_x.args = [var_x]

  // Outer: x = alloc()
  // Inner if: x = alloc(); free(x)
  // Outer exit: free(x)
  if_reassign = ast_node("IfStmt")
  if_reassign.condition = ast_node("Variable")
  if_reassign.then_body = [assign_x, call_free_x]
  if_reassign.else_body = []

  fn_reassign = ast_node("FnDef")
  fn_reassign.name = "reassign_leak"
  fn_reassign.body = [assign_x, if_reassign, call_free_x]

  eng3 = math_proof_engine_new()
  cert3 = math_proof_verify_fn(eng3, fn_reassign)
  assert_true(cert3.mpc_is_proven == 0, "Cross-scope reassignment leak correctly rejected")
  assert_true(cert3.mpc_violation_count > 0, "Reassignment overwrite violation recorded")

  return 1
@end

@fn test_ast_defer_cleanup_proofs()
  say("── 9. Testing Idiomatic Defer Statement Cleanups ──")

  call_alloc = ast_node("Call")
  call_alloc.name = "alloc"
  call_alloc.args = []

  assign_x = ast_node("Assign")
  assign_x.target = "x"
  assign_x.value = call_alloc

  var_x = ast_node("Variable")
  var_x.name = "x"
  call_free_x = ast_node("Call")
  call_free_x.name = "free"
  call_free_x.args = [var_x]

  ret_0 = ast_node("Return")

  defer_free = ast_node("Defer")
  defer_free.expr = call_free_x

  fn_defer = ast_node("FnDef")
  fn_defer.name = "defer_clean_routine"
  fn_defer.body = [assign_x, defer_free, ret_0]

  eng4 = math_proof_engine_new()
  cert4 = math_proof_verify_fn(eng4, fn_defer)
  assert_true(cert4.mpc_is_proven == 1, "Idiomatic defer free proven memory safe (Δ=0)")
  assert_true(cert4.mpc_net_delta == 0, "Defer cleanup yields net delta = 0")

  return 1
@end

@fn test_ast_untracked_free_proofs()
  say("── 10. Testing Untracked Free Detection ──")

  var_untracked = ast_node("Variable")
  var_untracked.name = "unallocated_handle"
  call_free_untracked = ast_node("Call")
  call_free_untracked.name = "free"
  call_free_untracked.args = [var_untracked]

  ret_0 = ast_node("Return")

  fn_untracked = ast_node("FnDef")
  fn_untracked.name = "untracked_free_routine"
  fn_untracked.body = [call_free_untracked, ret_0]

  eng5 = math_proof_engine_new()
  cert5 = math_proof_verify_fn(eng5, fn_untracked)
  assert_true(cert5.mpc_is_proven == 0, "Untracked free of unallocated variable rejected")
  assert_true(cert5.mpc_violation_count > 0, "Untracked free violation recorded in certificate")

  return 1
@end

@fn test_real_cfg_graph_inspection()
  say("── 11. Testing Real AST Control-Flow Graph Construction & Topology ──")

  call_alloc = ast_node("Call")
  call_alloc.name = "alloc"
  call_alloc.args = []

  assign_x = ast_node("Assign")
  assign_x.target = "x"
  assign_x.value = call_alloc

  ret_0 = ast_node("Return")

  if_node = ast_node("IfStmt")
  if_node.condition = ast_node("Variable")
  if_node.then_body = [ret_0]
  if_node.else_body = []

  fn_test = ast_node("FnDef")
  fn_test.name = "cfg_inspect_routine"
  fn_test.body = [assign_x, if_node, ret_0]

  cfg = cfg_build_from_fn(fn_test)
  assert_true(cfg.cfg_blocks.len() >= 4, "CFG contains multiple basic blocks")
  assert_true(cfg.cfg_entry_id == 0, "Entry basic block ID is 0")
  assert_true(cfg.cfg_exit_id == 1, "Exit basic block ID is 1")
  assert_true(cfg.cfg_branches.len() >= 1, "CFG tracks conditional branch descriptor")

  entry_blk = cfg.cfg_blocks[0]
  assert_true(entry_blk.cbb_succs.len() > 0, "Entry block has outgoing control-flow edges")

  return 1
@end

@fn main()
  say("==================================================================")
  say("🏛️  LIPI FIRST 1.0.0: MATHEMATICAL MEMORY SAFETY & CFG PROOF TEST")
  say("==================================================================")

  test_legacy_cfg_proofs()
  test_ast_linear_proofs()
  test_ast_branching_proofs()
  test_ast_loop_proofs()
  test_ast_scope_lifetime_proofs()
  test_ast_early_return_proofs()
  test_ast_break_loop_proofs()
  test_ast_cross_scope_reassign_proofs()
  test_ast_defer_cleanup_proofs()
  test_ast_untracked_free_proofs()
  test_real_cfg_graph_inspection()

  say("==================================================================")
  say("👑 ALL 11 MATHEMATICAL MEMORY SAFETY & CFG PROOF TESTS PASSED (100% PURE LIPI)")
  say("==================================================================")
  return 0
@end

main()
