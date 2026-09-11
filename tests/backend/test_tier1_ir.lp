@! ============================================================================
@! MAYA NATIVE BACKEND TEST SUITE — TIER 1: INTERMEDIATE REPRESENTATION (IR)
@! Tests Maya IR data structures, instruction creation, CFG manipulation,
@! Dominator trees, dominance frontiers, verifier, and AST->IR lowering.
@! 100% Pure Maya — Direct Integration with compiler/backend/maya_ir.maya
@! Zero Mock Logic — Strict Authentic Verification
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"

@! ----------------------------------------------------------------------------
@! 1. Test Harness & Utilities
@! ----------------------------------------------------------------------------

@struct TestState
  passed: 0
  failed: 0
  total: 0
@end

@fn test_assert_eq(state, actual, expected, name)
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

@fn test_assert_true(state, cond, name)
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

@fn test_assert_str_eq(state, actual, expected, name)
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

@! AST node construction helper for genuine AST->IR lowering verification
@fn ast_node(kind)
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

@! ----------------------------------------------------------------------------
@! 2. Test Suite Runner
@! ----------------------------------------------------------------------------

@fn main()
  println("=================================================================")
  println("🧪 MAYA NATIVE BACKEND TEST SUITE — TIER 1: MAYA IR & CFG 🧪")
  println("=================================================================")

  state = { passed: 0, failed: 0, total: 0 }

  @! --------------------------------------------------------------------------
  @! Category 1: IR Types and Value Descriptors (≥15 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 1.1] Verifying IR Types and Value Descriptors...")

  t_i64 = ir_type_i64()
  t_i32 = ir_type_i32()
  t_i16 = ir_type_i16()
  t_i8 = ir_type_i8()
  t_bool = ir_type_bool()
  t_f64 = ir_type_f64()
  t_f32 = ir_type_f32()
  t_void = ir_type_void()
  t_ptr_i64 = ir_type_ptr(t_i64)
  t_arr = ir_type_array(t_i64, 4)

  state = test_assert_str_eq(state, t_i64.kind, "i64", "Type i64 kind")
  state = test_assert_eq(state, t_i64.size, 8, "Type i64 size == 8")
  state = test_assert_eq(state, t_i32.size, 4, "Type i32 size == 4")
  state = test_assert_eq(state, t_i16.size, 2, "Type i16 size == 2")
  state = test_assert_eq(state, t_i8.size, 1, "Type i8 size == 1")
  state = test_assert_eq(state, t_bool.size, 1, "Type bool size == 1")
  state = test_assert_eq(state, t_f64.size, 8, "Type f64 size == 8")
  state = test_assert_eq(state, t_f32.size, 4, "Type f32 size == 4")
  state = test_assert_eq(state, t_void.size, 0, "Type void size == 0")
  state = test_assert_eq(state, t_ptr_i64.size, 8, "Type ptr size == 8")
  state = test_assert_eq(state, t_arr.size, 32, "Type array [4 x i64] size == 32")

  @! Struct Type & Alignment
  struct_fields = [
    { f_name: "f_a", f_type: t_i8 },
    { f_name: "f_b", f_type: t_i32 },
    { f_name: "f_c", f_type: t_i64 }
  ]
  t_struct = ir_type_struct("Point", struct_fields)
  state = test_assert_eq(state, t_struct.size, 24, "Struct Point size 24 (aligned)")
  state = test_assert_eq(state, t_struct.size % 8, 0, "Struct Point 8-byte alignment")
  state = test_assert_str_eq(state, ir_type_to_string(t_struct), "%struct.Point", "Struct type name formatting")

  @! Type Predicates
  state = test_assert_true(state, ir_type_is_int(t_i64), "ir_type_is_int(i64)")
  state = test_assert_true(state, ir_type_is_float(t_f64), "ir_type_is_float(f64)")
  state = test_assert_true(state, ir_type_is_numeric(t_i32), "ir_type_is_numeric(i32)")
  state = test_assert_true(state, ir_type_is_ptr(t_ptr_i64), "ir_type_is_ptr(ptr)")
  state = test_assert_true(state, ir_type_is_void(t_void), "ir_type_is_void(void)")
  state = test_assert_true(state, ir_type_is_bool(t_bool), "ir_type_is_bool(bool)")

  @! Value Descriptors
  v_vreg = ir_val_vreg(0, t_i64, "tmp")
  v_reg = ir_val_reg("%rax", t_i64)
  v_cint = ir_val_const_int(42, t_i64)
  v_cflt = ir_val_const_float(3, t_f64)
  v_cbool = ir_val_const_bool(1)
  v_cnull = ir_val_const_null()
  v_glob = ir_val_global("g_counter", t_i64)
  v_param = ir_val_param(0, "arg0", t_i64)

  state = test_assert_str_eq(state, v_vreg.name, "%tmp_0", "Virtual register name %tmp_0")
  state = test_assert_str_eq(state, ir_val_to_string(v_cint), "42", "Const int string representation")
  state = test_assert_str_eq(state, ir_val_to_string(v_cnull), "null", "Const null string representation")
  state = test_assert_str_eq(state, ir_val_to_string(v_glob), "@g_counter", "Global ref string representation")
  state = test_assert_str_eq(state, ir_val_to_string(v_param), "%param_arg0", "Param string representation")

  @! --------------------------------------------------------------------------
  @! Category 2: IR Instruction Constructors & Predicates (≥15 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 1.2] Verifying IR Instructions & Predicates...")

  val_a = ir_val_reg("%a", t_i64)
  val_b = ir_val_reg("%b", t_i64)
  val_cond = ir_val_reg("%cond0", t_bool)
  ptr_v0 = ir_val_reg("%ptr0", t_ptr_i64)

  @! ALU Binary Instructions
  inst_add = ir_inst_binary("ADD", "%t0", val_a, val_b, t_i64)
  state = test_assert_str_eq(state, inst_add.op, "ADD", "IR binary op ADD opcode")
  state = test_assert_str_eq(state, inst_add.dest, "%t0", "IR binary op ADD dest")
  state = test_assert_eq(state, inst_add.inst_type.size, 8, "IR binary op ADD 64-bit size")
  state = test_assert_str_eq(state, ir_inst_to_string(inst_add), "%t0 = add i64 %a, %b", "ADD instruction string")

  inst_xor = ir_inst_binary("XOR", "%t1", val_a, val_b, t_i32)
  state = test_assert_str_eq(state, inst_xor.op, "XOR", "IR bitwise op XOR opcode")
  state = test_assert_eq(state, inst_xor.inst_type.size, 4, "IR bitwise op XOR 32-bit size")

  inst_neg = ir_inst_neg("%t2", val_a, t_i64)
  inst_not = ir_inst_not("%t3", val_a, t_i64)
  state = test_assert_str_eq(state, inst_neg.op, "NEG", "IR unary op NEG")
  state = test_assert_str_eq(state, inst_not.op, "NOT", "IR unary op NOT")

  @! Comparison Instructions
  inst_cmp = ir_inst_cmp("==", "%c0", val_a, val_b, t_i64)
  state = test_assert_str_eq(state, inst_cmp.op, "CMP", "IR CMP opcode")
  state = test_assert_str_eq(state, inst_cmp.cmp_op, "eq", "IR CMP normalized op 'eq'")

  @! Memory Instructions (ALLOCA, LOAD, STORE, GEP)
  inst_alloca = ir_inst_alloca("%ptr0", t_i64, 16, "ptr0")
  inst_load = ir_inst_load("%val0", ptr_v0, t_i64)
  inst_store = ir_inst_store(val_a, ptr_v0, t_i64)
  inst_gep = ir_inst_gep("%elem0", ptr_v0, v_cint, t_i64, 8)

  state = test_assert_str_eq(state, inst_alloca.op, "ALLOCA", "IR memory ALLOCA opcode")
  state = test_assert_eq(state, inst_alloca.align, 16, "IR memory ALLOCA alignment")
  state = test_assert_str_eq(state, inst_load.op, "LOAD", "IR memory LOAD opcode")
  state = test_assert_str_eq(state, inst_store.op, "STORE", "IR memory STORE opcode")
  state = test_assert_str_eq(state, inst_gep.op, "GEP", "IR memory GEP opcode")

  @! Control Flow Instructions (BR, BR_COND, RET)
  inst_br = ir_inst_branch(3)
  inst_br_cond = ir_inst_branch_cond(val_cond, 1, 2)
  inst_ret = ir_inst_ret(val_a, t_i64)

  state = test_assert_str_eq(state, inst_br.op, "BR", "IR unconditional branch opcode")
  state = test_assert_eq(state, inst_br.target, 3, "IR unconditional branch target")
  state = test_assert_str_eq(state, inst_br_cond.op, "BR_COND", "IR conditional branch opcode")
  state = test_assert_eq(state, inst_br_cond.true_target, 1, "IR conditional branch true target")
  state = test_assert_eq(state, inst_br_cond.false_target, 2, "IR conditional branch false target")
  state = test_assert_str_eq(state, inst_ret.op, "RET", "IR return opcode")
  state = test_assert_true(state, ir_op_is_term("RET"), "ir_op_is_term('RET')")
  state = test_assert_true(state, ir_op_is_br("BR"), "ir_op_is_br('BR')")
  state = test_assert_true(state, ir_op_is_br_cond("BR_COND"), "ir_op_is_br_cond('BR_COND')")

  @! Syscall & Call Instructions
  sys_args = [val_a, ptr_v0, val_b]
  inst_sys = ir_inst_syscall("%ret0", v_cint, sys_args, t_i64)
  state = test_assert_str_eq(state, inst_sys.op, "SYSCALL", "IR syscall opcode")
  state = test_assert_eq(state, inst_sys.args.len(), 3, "IR syscall argument count == 3")

  inst_call = ir_inst_call("%call_res", "math_sqrt", [val_a], t_i64)
  state = test_assert_str_eq(state, inst_call.op, "CALL", "IR call opcode")
  state = test_assert_str_eq(state, inst_call.callee, "math_sqrt", "IR call callee")

  @! Phi Node Instruction
  phi_pairs = [{ block: 1, val: ir_val_reg("%x_1", t_i64) }, { block: 2, val: ir_val_reg("%x_2", t_i64) }]
  inst_phi = ir_inst_phi("%x_3", phi_pairs, t_i64)
  state = test_assert_str_eq(state, inst_phi.op, "PHI", "IR phi node opcode")
  state = test_assert_eq(state, inst_phi.incoming.len(), 2, "IR phi incoming branches count == 2")
  state = test_assert_true(state, ir_op_is_phi("PHI"), "ir_op_is_phi('PHI')")

  @! --------------------------------------------------------------------------
  @! Category 3: Basic Blocks, CFG Graph, Dominators & CFG Verifier (≥15 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 1.3] Verifying Basic Blocks, CFG Graph & Dominators...")

  b0 = ir_block_new(0, "entry")
  b1 = ir_block_new(1, "then")
  b2 = ir_block_new(2, "else")
  b3 = ir_block_new(3, "join")

  state = test_assert_eq(state, b0.id, 0, "Basic block 0 id")
  state = test_assert_str_eq(state, b0.name, "entry", "Basic block 0 name")
  state = test_assert_eq(state, b0.instructions.len(), 0, "Basic block initial instruction count")

  @! Build Diamond CFG: b0 -> b1, b2; b1, b2 -> b3
  ir_cfg_add_edge(b0, b1)
  ir_cfg_add_edge(b0, b2)
  ir_cfg_add_edge(b1, b3)
  ir_cfg_add_edge(b2, b3)

  state = test_assert_eq(state, b0.succs.len(), 2, "Entry block successor count = 2")
  state = test_assert_eq(state, b1.preds.len(), 1, "Then block predecessor count = 1")
  state = test_assert_eq(state, b2.preds.len(), 1, "Else block predecessor count = 1")
  state = test_assert_eq(state, b3.preds.len(), 2, "Join block predecessor count = 2")

  @! Loop CFG Construction with Back-edge
  b_loop_header = ir_block_new(4, "loop_hdr")
  b_loop_body = ir_block_new(5, "loop_body")
  b_loop_exit = ir_block_new(6, "loop_exit")

  ir_cfg_add_edge(b_loop_header, b_loop_body)
  ir_cfg_add_edge(b_loop_header, b_loop_exit)
  ir_cfg_add_edge(b_loop_body, b_loop_header)

  state = test_assert_eq(state, b_loop_header.preds.len(), 1, "Loop header back-edge predecessor count")
  state = test_assert_eq(state, b_loop_header.preds[0], 5, "Loop header predecessor is loop body (5)")
  state = test_assert_eq(state, b_loop_body.succs[0], 4, "Loop body back-edge targets loop header (4)")

  @! Dominator Tree Computation on Diamond CFG
  blocks_diamond = [b0, b1, b2, b3]
  blocks_diamond = ir_compute_dominators(blocks_diamond)

  state = test_assert_eq(state, blocks_diamond[0].idom, 0, "Entry block IDOM is itself (0)")
  state = test_assert_eq(state, blocks_diamond[1].idom, 0, "Then block IDOM is Entry (0)")
  state = test_assert_eq(state, blocks_diamond[2].idom, 0, "Else block IDOM is Entry (0)")
  state = test_assert_eq(state, blocks_diamond[3].idom, 0, "Join block IDOM is Entry (0)")

  @! Dominance Frontiers Computation
  blocks_diamond = ir_compute_dominance_frontiers(blocks_diamond)
  state = test_assert_eq(state, blocks_diamond[1].df.len(), 1, "Then block has 1 dominance frontier")
  state = test_assert_eq(state, blocks_diamond[1].df[0], 3, "Then block DF is Join block (3)")
  state = test_assert_eq(state, blocks_diamond[2].df[0], 3, "Else block DF is Join block (3)")

  @! CFG Verifier Positive & Negative Invariants
  valid_fn = ir_function_new("test_func", ["x"], t_i64)
  valid_fn.blocks[0] = ir_block_add_inst(valid_fn.blocks[0], ir_inst_ret(val_a, t_i64))
  v_res = ir_verify_cfg(valid_fn)
  state = test_assert_true(state, v_res.ok, "CFG verifier passes valid single-block function")

  @! Negative test: Block without terminator
  bad_fn = ir_function_new("bad_func", [], t_i64)
  bad_fn.blocks[0] = ir_block_add_inst(bad_fn.blocks[0], inst_add)
  v_bad_res = ir_verify_cfg(bad_fn)
  state = test_assert_eq(state, v_bad_res.ok, 0, "CFG verifier rejects block without terminator")

  @! --------------------------------------------------------------------------
  @! Category 4: IR Function & Module Hierarchy (≥8 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 1.4] Verifying Function & Module Containers...")

  mod = ir_module_new("test_module")
  state = test_assert_str_eq(state, mod.name, "test_module", "Module name")

  @! Rodata string deduplication in module
  s_ref1 = ir_module_add_string_literal(mod, "hello world")
  s_ref2 = ir_module_add_string_literal(mod, "hello world")
  s_ref3 = ir_module_add_string_literal(mod, "second string")

  state = test_assert_str_eq(state, s_ref1.val_label, ".str.0", "First string label .str.0")
  state = test_assert_str_eq(state, s_ref2.val_label, ".str.0", "Duplicate string reuses .str.0")
  state = test_assert_str_eq(state, s_ref3.val_label, ".str.1", "Distinct string gets .str.1")
  state = test_assert_eq(state, mod.string_literals.len(), 2, "Module contains exactly 2 string literals")

  @! Module functions & globals
  mod = ir_module_add_global(mod, "g_val", t_i64, v_cint)
  mod = ir_module_add_function(mod, valid_fn)
  state = test_assert_eq(state, mod.globals.len(), 1, "Module has 1 global variable")
  state = test_assert_eq(state, mod.functions.len(), 1, "Module has 1 function")

  m_v_res = ir_verify_module(mod)
  state = test_assert_true(state, m_v_res.ok, "ir_verify_module passes valid module")

  @! --------------------------------------------------------------------------
  @! Category 5: AST to IR Lowering Engine (Zero Mock) (≥10 test cases)
  @! --------------------------------------------------------------------------
  println("▶ [Tier 1.5] Verifying AST Lowering Engine...")

  @! Program 1: Linear Arithmetic Function: @fn add_two(a, b) { let s = a + b; return s; }
  fn_ast1 = ast_node("FnDef")
  fn_ast1.name = "add_two"
  fn_ast1.params = ["a", "b"]
  fn_ast1.ret_type = "i64"

  stmt_add = ast_node("Assign")
  stmt_add.target = "s"
  bin_add = ast_node("BinaryOp")
  bin_add.op = "+"
  var_a_node = ast_node("Variable")
  var_a_node.name = "a"
  var_b_node = ast_node("Variable")
  var_b_node.name = "b"
  bin_add.left = var_a_node
  bin_add.right = var_b_node
  stmt_add.value = bin_add

  stmt_ret = ast_node("Return")
  var_s_node = ast_node("Variable")
  var_s_node.name = "s"
  stmt_ret.value = var_s_node

  fn_ast1.body = [stmt_add, stmt_ret]

  lower_res1 = ir_module_from_ast([fn_ast1], { module_name: "e2e_prog", dump_ir: 0 })
  state = test_assert_eq(state, lower_res1.error, 0, "Lowering linear function succeeds with error=0")
  state = test_assert_eq(state, lower_res1.module.functions.len(), 1, "Lowered module contains 1 function")

  lowered_fn1 = lower_res1.module.functions[0]
  state = test_assert_str_eq(state, lowered_fn1.name, "add_two", "Lowered function name is 'add_two'")
  state = test_assert_true(state, lowered_fn1.blocks.len() >= 1, "Lowered function has entry block")

  @! Program 2: While Loop AST Lowering: @fn sum_to_n(n) { let i = 0; let total = 0; while i < n { total = total + i; i = i + 1; } return total; }
  fn_ast2 = ast_node("FnDef")
  fn_ast2.name = "sum_to_n"
  fn_ast2.params = ["n"]
  fn_ast2.ret_type = "i64"

  stmt_i = ast_node("Assign")
  stmt_i.target = "i"
  c_0 = ast_node("LiteralInt")
  c_0.val = 0
  stmt_i.value = c_0

  stmt_tot = ast_node("Assign")
  stmt_tot.target = "total"
  stmt_tot.value = c_0

  while_node = ast_node("WhileLoop")
  cmp_cond = ast_node("BinaryOp")
  cmp_cond.op = "<"
  var_i_node = ast_node("Variable")
  var_i_node.name = "i"
  var_n_node = ast_node("Variable")
  var_n_node.name = "n"
  cmp_cond.left = var_i_node
  cmp_cond.right = var_n_node
  while_node.condition = cmp_cond

  tot_inc = ast_node("Assign")
  tot_inc.target = "total"
  bin_tot = ast_node("BinaryOp")
  bin_tot.op = "+"
  var_tot_node = ast_node("Variable")
  var_tot_node.name = "total"
  bin_tot.left = var_tot_node
  bin_tot.right = var_i_node
  tot_inc.value = bin_tot

  i_inc = ast_node("Assign")
  i_inc.target = "i"
  bin_i = ast_node("BinaryOp")
  bin_i.op = "+"
  bin_i.left = var_i_node
  c_1 = ast_node("LiteralInt")
  c_1.val = 1
  bin_i.right = c_1
  i_inc.value = bin_i

  while_node.body = [tot_inc, i_inc]

  stmt_ret2 = ast_node("Return")
  stmt_ret2.value = var_tot_node

  fn_ast2.body = [stmt_i, stmt_tot, while_node, stmt_ret2]

  lower_res2 = ir_module_from_ast([fn_ast2], { module_name: "while_prog", dump_ir: 0 })
  state = test_assert_eq(state, lower_res2.error, 0, "Lowering while loop function succeeds with error=0")
  lowered_fn2 = lower_res2.module.functions[0]
  state = test_assert_true(state, lowered_fn2.blocks.len() >= 3, "While loop generated >= 3 basic blocks (cond, body, exit)")

  @! Verify CFG validity on lowered while loop
  v_while = ir_verify_cfg(lowered_fn2)
  state = test_assert_true(state, v_while.ok, "Lowered while loop CFG is strictly valid")

  println("")
  println("=================================================================")
  println("📊 TIER 1 (IR) SUMMARY:")
  println("   Total Tests : " + state.total.to_str())
  println("   Passed      : " + state.passed.to_str())
  println("   Failed      : " + state.failed.to_str())
  @if state.failed == 0
    println("🎉 ALL TIER 1 IR TESTS PASSED CLEANLY!")
  @else
    println("❌ TIER 1 IR TESTS COMPLETED WITH FAILURES!")
  @end
  println("=================================================================")

  @if state.failed == 0
    return 0
  @else
    return 1
  @end
@end
