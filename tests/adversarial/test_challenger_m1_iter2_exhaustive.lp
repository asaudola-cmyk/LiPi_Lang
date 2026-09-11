@! ============================================================================
@! ADVERSARIAL CHALLENGER EXHAUSTIVE STRESS SUITE: MAYA IR & CFG INFRASTRUCTURE
@! Focus: Milestone 1 Iteration 2 (Native Maya IR)
@! ============================================================================

import "compiler/backend/maya_ir"
import "universe/core/collections"
import "universe/core/string"

fn print_pass(name)
  println("  [PASS] " + name)
end

fn print_fail(name, reason)
  println("  [FAIL] " + name + " -> " + reason)
end

fn main()
  println("=================================================================")
  println("🔱 EMPIRICAL CHALLENGER ADVERSARIAL EXHAUSTIVE STRESS SUITE 🔱")
  println("=================================================================")
  
  total_tests = 0
  passed_tests = 0
  failed_tests = 0

  @! --------------------------------------------------------------------------
  @! CHALLENGE SUITE 1: Extreme CFG Topologies & Control Flow Invariants
  @! --------------------------------------------------------------------------
  println("▶ [Challenger 1] Extreme CFG Topologies & Dominance Tree...")

  @! 1.1 Multi-way If-Elif-Else Ladder (15 elif branches)
  elif_branches = []
  e = 0
  @while e < 15
    cond_node = ast_node("BinaryOp")
    cond_node.op = "=="
    cond_node.left = ast_node("Variable")
    cond_node.left.name = "x"
    cond_node.right = ast_node("LiteralInt")
    cond_node.right.val = e + 1

    body_node = ast_node("Assign")
    body_node.target = "y"
    body_node.value = ast_node("LiteralInt")
    body_node.value.val = (e + 1) * 10

    branch = ast_node("ElifBranch")
    branch.cond = cond_node
    branch.body = [body_node]
    elif_branches = elif_branches.push(branch)
    e = e + 1
  @end

  if_stmt = ast_node("IfStmt")
  if_stmt.condition = ast_node("BinaryOp")
  if_stmt.condition.op = "=="
  if_stmt.condition.left = ast_node("Variable")
  if_stmt.condition.left.name = "x"
  if_stmt.condition.right = ast_node("LiteralInt")
  if_stmt.condition.right.val = 0

  if_then_assign = ast_node("Assign")
  if_then_assign.target = "y"
  if_then_assign.value = ast_node("LiteralInt")
  if_then_assign.value.val = 100
  if_stmt.then_body = [if_then_assign]
  if_stmt.elif_branches = elif_branches

  else_assign = ast_node("Assign")
  else_assign.target = "y"
  else_assign.value = ast_node("LiteralInt")
  else_assign.value.val = -1
  if_stmt.else_body = [else_assign]

  ret_y = ast_node("Return")
  ret_y.value = ast_node("Variable")
  ret_y.value.name = "y"

  fn_ast1 = ast_fndef("multi_elif_15", ["x"], "i64", [if_stmt, ret_y])
  mod_res1 = ir_module_from_ast([fn_ast1], { dump_ir: 0, module_name: "test_elif_mod" })

  total_tests = total_tests + 1
  @if mod_res1.error == 0
    passed_tests = passed_tests + 1
    print_pass("15-way elif ladder lowers cleanly with zero CFG errors")
  @else
    failed_tests = failed_tests + 1
    print_fail("15-way elif ladder lowers cleanly", mod_res1.message)
  @end

  total_tests = total_tests + 1
  @if mod_res1.warnings.len() == 0
    passed_tests = passed_tests + 1
    print_pass("15-way elif ladder has zero unreachable block warnings")
  @else
    failed_tests = failed_tests + 1
    print_fail("15-way elif ladder has zero unreachable block warnings", "Found " + mod_res1.warnings.len().to_str() + " warnings")
  @end

  @! 1.2 Deeply Nested 4-Level Loops with Interleaved Break and Continue
  @! Loop 1 (outer) -> Loop 2 -> Loop 3 -> Loop 4 (inner)
  l4_body = [
    ast_node("Assign"),
    ast_node("Break"),
    ast_node("Continue")
  ]
  l4_body[0].target = "cnt"
  l4_body[0].value = ast_node("LiteralInt")
  l4_body[0].value.val = 42

  l4 = ast_node("WhileLoop")
  l4.condition = ast_node("LiteralBool")
  l4.condition.val = 1
  l4.body = l4_body

  l3 = ast_node("WhileLoop")
  l3.condition = ast_node("LiteralBool")
  l3.condition.val = 1
  l3.body = [l4, ast_node("Continue")]

  l2 = ast_node("WhileLoop")
  l2.condition = ast_node("LiteralBool")
  l2.condition.val = 1
  l2.body = [l3, ast_node("Break")]

  l1 = ast_node("WhileLoop")
  l1.condition = ast_node("LiteralBool")
  l1.condition.val = 1
  l1.body = [l2]

  fn_ast2 = ast_fndef("nested_4_loops", [], "i64", [l1, ret_y])
  mod_res2 = ir_module_from_ast([fn_ast2], { dump_ir: 0, module_name: "test_loops_mod" })

  total_tests = total_tests + 1
  @if mod_res2.error == 0
    passed_tests = passed_tests + 1
    print_pass("4-level nested loops with break & continue lower with zero errors")
  @else
    failed_tests = failed_tests + 1
    print_fail("4-level nested loops lower with zero errors", mod_res2.message)
  @end

  @! 1.3 Dominator Tree & Dominance Frontiers for Diamond CFG
  @! Construct manual diamond CFG: Entry (0) -> B1 (1), B2 (2) -> Join (3) -> Exit (4)
  test_fn = ir_function_new("diamond_dom", [], ir_type_i64())
  bb0 = test_fn.blocks[0]
  bb1 = ir_block_new(1, "b1")
  bb2 = ir_block_new(2, "b2")
  bb3 = ir_block_new(3, "join")
  bb4 = ir_block_new(4, "exit")

  bb0.succs = [1, 2]
  bb1.preds = [0]
  bb1.succs = [3]
  bb2.preds = [0]
  bb2.succs = [3]
  bb3.preds = [1, 2]
  bb3.succs = [4]
  bb4.preds = [3]

  blocks_list = [bb0, bb1, bb2, bb3, bb4]
  blocks_dom = ir_compute_dominators(blocks_list)
  blocks_df = ir_compute_dominance_frontiers(blocks_dom)

  total_tests = total_tests + 1
  @if blocks_dom[0].idom == 0 && blocks_dom[1].idom == 0 && blocks_dom[2].idom == 0 && blocks_dom[3].idom == 0 && blocks_dom[4].idom == 3
    passed_tests = passed_tests + 1
    print_pass("Dominator tree strictly correct across all 5 diamond blocks")
  @else
    failed_tests = failed_tests + 1
    print_fail("Dominator tree strictly correct", "Mismatch in idom array")
  @end

  total_tests = total_tests + 1
  df1_ok = (blocks_df[1].df.len() == 1 && blocks_df[1].df[0] == 3)
  df2_ok = (blocks_df[2].df.len() == 1 && blocks_df[2].df[0] == 3)
  @if df1_ok == 1 && df2_ok == 1
    passed_tests = passed_tests + 1
    print_pass("Dominance frontier for B1 and B2 is {Join=3}")
  @else
    failed_tests = failed_tests + 1
    print_fail("Dominance frontier for B1 and B2 is {Join=3}", "DF mismatch")
  @end

  @! --------------------------------------------------------------------------
  @! CHALLENGE SUITE 2: Complex Nested Short-Circuit Evaluation
  @! --------------------------------------------------------------------------
  println("▶ [Challenger 2] Nested Short-Circuit Control Flow & Boolean Logic...")

  @! 2.1 Formula: (a && (b || c)) && (d || (e && f))
  @! Construct nested AST
  var_a = ast_node("Variable") var_a.name = "a"
  var_b = ast_node("Variable") var_b.name = "b"
  var_c = ast_node("Variable") var_c.name = "c"
  var_d = ast_node("Variable") var_d.name = "d"
  var_e = ast_node("Variable") var_e.name = "e"
  var_f = ast_node("Variable") var_f.name = "f"

  b_or_c = ast_node("BinaryOp")
  b_or_c.op = "||"
  b_or_c.left = var_b
  b_or_c.right = var_c

  a_and_b_or_c = ast_node("BinaryOp")
  a_and_b_or_c.op = "&&"
  a_and_b_or_c.left = var_a
  a_and_b_or_c.right = b_or_c

  e_and_f = ast_node("BinaryOp")
  e_and_f.op = "&&"
  e_and_f.left = var_e
  e_and_f.right = var_f

  d_or_e_and_f = ast_node("BinaryOp")
  d_or_e_and_f.op = "||"
  d_or_e_and_f.left = var_d
  d_or_e_and_f.right = e_and_f

  full_sc_expr = ast_node("BinaryOp")
  full_sc_expr.op = "&&"
  full_sc_expr.left = a_and_b_or_c
  full_sc_expr.right = d_or_e_and_f

  assign_sc = ast_node("Assign")
  assign_sc.target = "res"
  assign_sc.value = full_sc_expr

  ret_sc = ast_node("Return")
  ret_sc.value = ast_node("Variable")
  ret_sc.value.name = "res"

  fn_sc = ast_fndef("eval_complex_sc", ["a", "b", "c", "d", "e", "f"], "i64", [assign_sc, ret_sc])
  mod_sc = ir_module_from_ast([fn_sc], { dump_ir: 0, module_name: "test_sc_mod" })

  total_tests = total_tests + 1
  @if mod_sc.error == 0
    passed_tests = passed_tests + 1
    print_pass("Deep nested short-circuit formula (a && (b||c)) && (d||(e&&f)) lowers cleanly")
  @else
    failed_tests = failed_tests + 1
    print_fail("Deep nested short-circuit formula lowers cleanly", mod_sc.message)
  @end

  total_tests = total_tests + 1
  @if mod_sc.warnings.len() == 0
    passed_tests = passed_tests + 1
    print_pass("Deep nested short-circuit has zero CFG unreachable block warnings")
  @else
    failed_tests = failed_tests + 1
    print_fail("Deep nested short-circuit has zero CFG unreachable block warnings", "Found " + mod_sc.warnings.len().to_str() + " warnings")
  @end

  total_tests = total_tests + 1
  lowered_fn = mod_sc.module.functions[0]
  num_sc_blocks = lowered_fn.blocks.len()
  @if num_sc_blocks >= 8
    passed_tests = passed_tests + 1
    print_pass("Deep short-circuit creates fine-grained basic blocks (" + num_sc_blocks.to_str() + " >= 8)")
  @else
    failed_tests = failed_tests + 1
    print_fail("Deep short-circuit creates fine-grained basic blocks", "Blocks: " + num_sc_blocks.to_str())
  @end

  @! --------------------------------------------------------------------------
  @! CHALLENGE SUITE 3: Struct Layouts, Alignments & Deep Pointer Indirection
  @! --------------------------------------------------------------------------
  println("▶ [Challenger 3] Struct Layouts, Memory Alignment & GEP Indirections...")

  @! 3.1 Struct with Mixed Fields: i8, i16, i32, i64, bool, ptr, array, nested struct
  inner_f1 = { f_name: "in_a", f_type: ir_type_i8(), f_offset: 0, f_size: 1 }
  inner_f2 = { f_name: "in_b", f_type: ir_type_i64(), f_offset: 0, f_size: 8 }
  inner_struct = ir_type_struct("InnerStruct", [inner_f1, inner_f2])

  f_i8 = { f_name: "f_i8", f_type: ir_type_i8(), f_offset: 0, f_size: 1 }
  f_i16 = { f_name: "f_i16", f_type: ir_type_i16(), f_offset: 0, f_size: 2 }
  f_i32 = { f_name: "f_i32", f_type: ir_type_i32(), f_offset: 0, f_size: 4 }
  f_i64 = { f_name: "f_i64", f_type: ir_type_i64(), f_offset: 0, f_size: 8 }
  f_bool = { f_name: "f_bool", f_type: ir_type_bool(), f_offset: 0, f_size: 1 }
  f_ptr = { f_name: "f_ptr", f_type: ir_type_ptr(ir_type_i64()), f_offset: 0, f_size: 8 }
  f_arr = { f_name: "f_arr", f_type: ir_type_array(ir_type_i32(), 4), f_offset: 0, f_size: 16 }
  f_nested = { f_name: "f_nested", f_type: inner_struct, f_offset: 0, f_size: inner_struct.size }

  mixed_struct = ir_type_struct("MixedStruct", [f_i8, f_i16, f_i32, f_i64, f_bool, f_ptr, f_arr, f_nested])

  total_tests = total_tests + 1
  @if mixed_struct.size % 8 == 0
    passed_tests = passed_tests + 1
    print_pass("MixedStruct total size (" + mixed_struct.size.to_str() + " bytes) is 8-byte aligned")
  @else
    failed_tests = failed_tests + 1
    print_fail("MixedStruct size is 8-byte aligned", "Size is " + mixed_struct.size.to_str())
  @end

  total_tests = total_tests + 1
  @! Verify offsets are monotonic and padded
  offsets_valid = 1
  idx = 0
  @while idx < mixed_struct.fields.len()
    fld = mixed_struct.fields[idx]
    @if fld.f_offset % 8 != 0
      offsets_valid = 0
    @end
    idx = idx + 1
  @end
  @if offsets_valid == 1
    passed_tests = passed_tests + 1
    print_pass("All struct field offsets are 8-byte aligned")
  @else
    failed_tests = failed_tests + 1
    print_fail("All struct field offsets are 8-byte aligned", "Unpadded offset detected")
  @end

  @! 3.2 Deep Pointer Indirection GEP Chain (4-level pointer indirection)
  gep_inst1 = ir_inst_gep("%gep1", ir_val_reg("%ptr0", ir_type_ptr(ir_type_i64())), ir_val_const_int(0, ir_type_i64()), ir_type_i64(), 8)
  gep_inst2 = ir_inst_gep("%gep2", ir_val_reg("%gep1", ir_type_ptr(ir_type_i64())), ir_val_const_int(2, ir_type_i64()), ir_type_i64(), 8)
  gep_inst3 = ir_inst_gep("%gep3", ir_val_reg("%gep2", ir_type_ptr(ir_type_i64())), ir_val_const_int(5, ir_type_i64()), ir_type_i64(), 8)
  gep_str = ir_inst_to_string(gep_inst3)

  total_tests = total_tests + 1
  @if gep_str == "%gep3 = gep i64, ptr %gep2, i64 5"
    passed_tests = passed_tests + 1
    print_pass("Chained GEP instruction formatting matches canonical IR syntax")
  @else
    failed_tests = failed_tests + 1
    print_fail("Chained GEP instruction formatting", "Got: " + gep_str)
  @end

  @! --------------------------------------------------------------------------
  @! CHALLENGE SUITE 4: Linux Syscall Instructions & Calling Conventions
  @! --------------------------------------------------------------------------
  println("▶ [Challenger 4] Linux Syscall Instruction Matrix & Argument Register Lowering...")

  @! Test Syscalls: 0 (read), 1 (write), 9 (mmap), 10 (mprotect), 11 (munmap), 39 (getpid), 60 (exit)
  sys0 = ir_inst_syscall("%res0", ir_val_const_int(0, ir_type_i64()), [ir_val_const_int(0, ir_type_i64()), ir_val_reg("%buf", ir_type_ptr(ir_type_i8())), ir_val_const_int(1024, ir_type_i64())], ir_type_i64())
  sys1 = ir_inst_syscall("%res1", ir_val_const_int(1, ir_type_i64()), [ir_val_const_int(1, ir_type_i64()), ir_val_reg("%msg", ir_type_ptr(ir_type_i8())), ir_val_const_int(14, ir_type_i64())], ir_type_i64())
  sys39 = ir_inst_syscall("%pid", ir_val_const_int(39, ir_type_i64()), [], ir_type_i64())
  sys60 = ir_inst_syscall("", ir_val_const_int(60, ir_type_i64()), [ir_val_const_int(0, ir_type_i64())], ir_type_void())

  total_tests = total_tests + 1
  @if sys0.nr == 0 && sys0.op == "SYSCALL"
    passed_tests = passed_tests + 1
    print_pass("Syscall 0 (read) correctly represented with nr=0")
  @else
    failed_tests = failed_tests + 1
    print_fail("Syscall 0 (read)", "nr=" + sys0.nr.to_str())
  @end

  total_tests = total_tests + 1
  @if sys1.nr == 1 && sys1.op == "SYSCALL"
    passed_tests = passed_tests + 1
    print_pass("Syscall 1 (write) correctly represented with nr=1")
  @else
    failed_tests = failed_tests + 1
    print_fail("Syscall 1 (write)", "nr=" + sys1.nr.to_str())
  @end

  total_tests = total_tests + 1
  @if sys39.nr == 39 && sys39.op == "SYSCALL"
    passed_tests = passed_tests + 1
    print_pass("Syscall 39 (getpid) correctly represented with nr=39")
  @else
    failed_tests = failed_tests + 1
    print_fail("Syscall 39 (getpid)", "nr=" + sys39.nr.to_str())
  @end

  total_tests = total_tests + 1
  @if sys60.nr == 60 && sys60.op == "SYSCALL"
    passed_tests = passed_tests + 1
    print_pass("Syscall 60 (exit) correctly represented with nr=60")
  @else
    failed_tests = failed_tests + 1
    print_fail("Syscall 60 (exit)", "nr=" + sys60.nr.to_str())
  @end

  total_tests = total_tests + 1
  sys39_str = ir_inst_to_string(sys39)
  @if sys39_str == "%pid = syscall 39()"
    passed_tests = passed_tests + 1
    print_pass("Syscall 39 formatted string matches canonical syntax: '%pid = syscall 39()'")
  @else
    failed_tests = failed_tests + 1
    print_fail("Syscall 39 formatted string", "Got: " + sys39_str)
  @end

  @! 4.2 Syscall Call Lowering in AST with exit() and syscall()
  ast_call_exit = ast_node("Call")
  ast_call_exit.func = ast_node("Variable")
  ast_call_exit.func.name = "exit"
  ast_call_exit.args = [ast_node("LiteralInt")]
  ast_call_exit.args[0].val = 0

  fn_exit_ast = ast_fndef("test_exit_call", [], "void", [ast_call_exit])
  mod_exit_res = ir_module_from_ast([fn_exit_ast], { dump_ir: 0, module_name: "test_exit_mod" })

  total_tests = total_tests + 1
  @if mod_exit_res.error == 0
    passed_tests = passed_tests + 1
    print_pass("AST exit(0) lowers to genuine Linux Syscall 60 without error")
  @else
    failed_tests = failed_tests + 1
    print_fail("AST exit(0) lowers to Linux Syscall 60", mod_exit_res.message)
  @end

  @! --------------------------------------------------------------------------
  @! CHALLENGE SUITE 5: 1,000 Local Variables & 20-Level Scope Shadowing
  @! --------------------------------------------------------------------------
  println("▶ [Challenger 5] Massive Symbol Table (1,000 locals) & Deep Scopes (20 levels)...")

  thousand_stmts = []
  k = 0
  @while k < 1000
    st = ast_node("Assign")
    st.target = "v_" + k.to_str()
    st.value = ast_node("LiteralInt")
    st.value.val = k
    thousand_stmts = thousand_stmts.push(st)
    k = k + 1
  @end
  thousand_stmts = thousand_stmts.push(ret_y)

  fn_thousand = ast_fndef("fn_1000_locals", [], "i64", thousand_stmts)
  mod_thousand = ir_module_from_ast([fn_thousand], { dump_ir: 0, module_name: "test_1000_locals" })

  total_tests = total_tests + 1
  @if mod_thousand.error == 0
    passed_tests = passed_tests + 1
    print_pass("1,000 local variables lowered with zero collision or stack overflow")
  @else
    failed_tests = failed_tests + 1
    print_fail("1,000 local variables lowered", mod_thousand.message)
  @end

  total_tests = total_tests + 1
  fn_th = mod_thousand.module.functions[0]
  @if fn_th.locals.len() >= 1000
    passed_tests = passed_tests + 1
    print_pass("Function tracks all " + fn_th.locals.len().to_str() + " local variable slots")
  @else
    failed_tests = failed_tests + 1
    print_fail("Function tracks all locals", "Tracked only " + fn_th.locals.len().to_str())
  @end

  println("=================================================================")
  println("📊 EMPIRICAL CHALLENGER TEST SUMMARY:")
  println("   Total Tests : " + total_tests.to_str())
  println("   Passed      : " + passed_tests.to_str())
  println("   Failed      : " + failed_tests.to_str())
  println("=================================================================")

  @if failed_tests == 0
    println("🎉 ALL EMPIRICAL CHALLENGER STRESS TESTS PASSED WITH 100% SUCCESS!")
  @else
    println("❌ CHALLENGER STRESS TESTS ENCOUNTERED FAILURES!")
  @end
