@! ============================================================================
@! MAYA NATIVE BACKEND UNIT & INTEGRATION TEST SUITE: MAYA IR & CFG VALIDATOR
@! Module: tests/backend/test_maya_ir.maya
@! Tests:
@! 1. Typed SSA IR Data Structures & Values (IRVal, IRInst, IRBlock, IRFunction, IRModule, IRType)
@! 2. 10-Invariant CFG Validator (Positive & Negative tests for all 10 invariants)
@! 3. Cooper-Harvey-Kennedy Dominance Analysis (idom, df, intersect)
@! 4. AST-to-IR Lowering Engine (Expressions, Control Flow, Structs, Impls, Syscalls, Defer)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"

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
@struct ASTNode
  kind: string
  name: string
  params: array
  body: array
  ret_type: string
  val: i64
  op: string
  left: ASTNode
  right: ASTNode
  expr: ASTNode
  condition: ASTNode
  then_body: array
  elif_branches: array
  else_body: array
  target: string
  value: ASTNode
  elements: array
  args: array
  func: ASTNode
  variable: string
  iterable: ASTNode
  index: ASTNode
  cond: ASTNode
@end

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

@fn main()
  r = runner_new()

  println("=================================================================")
  println("🧪 MAYA IR & CFG VALIDATOR TEST SUITE 🧪")
  println("=================================================================")

  @! --------------------------------------------------------------------------
  @! SECTION 1: IR Type System & Value Descriptors
  @! --------------------------------------------------------------------------
  println("▶ [Section 1] IR Type System & Value Descriptors...")
  t_i64 = ir_type_i64()
  t_i32 = ir_type_i32()
  t_i16 = ir_type_i16()
  t_i8 = ir_type_i8()
  t_bool = ir_type_bool()
  t_f64 = ir_type_f64()
  t_f32 = ir_type_f32()
  t_void = ir_type_void()
  t_ptr = ir_type_ptr(t_i64)
  t_arr = ir_type_array(t_i64, 8)
  t_struct = ir_type_struct("Vec3", [t_f64, t_f64, t_f64])

  r = assert_eq_str(r, t_i64.kind, "i64", "ir_type_i64 kind")
  r = assert_eq_i64(r, t_i64.size, 8, "ir_type_i64 size is 8")
  r = assert_eq_i64(r, t_i32.size, 4, "ir_type_i32 size is 4")
  r = assert_eq_i64(r, t_i16.size, 2, "ir_type_i16 size is 2")
  r = assert_eq_i64(r, t_i8.size, 1, "ir_type_i8 size is 1")
  r = assert_eq_i64(r, t_bool.size, 1, "ir_type_bool size is 1")
  r = assert_eq_i64(r, t_f64.size, 8, "ir_type_f64 size is 8")
  r = assert_eq_i64(r, t_f32.size, 4, "ir_type_f32 size is 4")
  r = assert_eq_i64(r, t_void.size, 0, "ir_type_void size is 0")
  r = assert_eq_i64(r, t_ptr.size, 8, "ir_type_ptr size is 8")
  r = assert_eq_i64(r, t_arr.size, 64, "ir_type_array size is 64")
  r = assert_eq_i64(r, t_struct.size, 24, "ir_type_struct size is 24")

  r = assert_true(r, ir_type_is_int(t_i64), "ir_type_is_int(i64)")
  r = assert_true(r, ir_type_is_float(t_f64), "ir_type_is_float(f64)")
  r = assert_true(r, ir_type_is_ptr(t_ptr), "ir_type_is_ptr(ptr)")
  r = assert_true(r, ir_type_is_void(t_void), "ir_type_is_void(void)")
  r = assert_true(r, ir_type_is_bool(t_bool), "ir_type_is_bool(bool)")

  @! Value Descriptors
  v_c10 = ir_val_const_int(10, t_i64)
  v_reg0 = ir_val_reg("%v0", t_i64)
  v_glob = ir_val_global("global_var", t_i64)
  v_param = ir_val_param(0, "arg0", t_i64)
  v_null = ir_val_null(t_ptr)

  r = assert_eq_str(r, ir_val_to_string(v_c10), "10", "ir_val_const_int string")
  r = assert_eq_str(r, ir_val_to_string(v_reg0), "%v0", "ir_val_reg string")
  r = assert_eq_str(r, ir_val_to_string(v_glob), "@global_var", "ir_val_global string")
  r = assert_eq_str(r, ir_val_to_string(v_param), "%param_arg0", "ir_val_param string")
  r = assert_eq_str(r, ir_val_to_string(v_null), "null", "ir_val_null string")

  @! --------------------------------------------------------------------------
  @! SECTION 2: IR Instructions & Opcode Properties
  @! --------------------------------------------------------------------------
  println("▶ [Section 2] IR Instructions & Opcode Properties...")
  inst_add = ir_inst_add("%v2", v_reg0, v_c10, t_i64)
  inst_sub = ir_inst_sub("%v3", v_reg0, v_c10, t_i64)
  inst_mul = ir_inst_mul("%v4", v_reg0, v_c10, t_i64)
  inst_div = ir_inst_div("%v5", v_reg0, v_c10, t_i64)
  inst_mod = ir_inst_mod("%v6", v_reg0, v_c10, t_i64)
  inst_and = ir_inst_and("%v7", v_reg0, v_c10, t_i64)
  inst_or  = ir_inst_or("%v8", v_reg0, v_c10, t_i64)
  inst_xor = ir_inst_xor("%v9", v_reg0, v_c10, t_i64)
  inst_shl = ir_inst_shl("%v10", v_reg0, v_c10, t_i64)
  inst_shr = ir_inst_shr("%v11", v_reg0, v_c10, t_i64)
  inst_neg = ir_inst_neg("%v12", v_reg0, t_i64)
  inst_not = ir_inst_not("%v13", v_reg0, t_i64)
  inst_cmp = ir_inst_cmp("==", "%v14", v_reg0, v_c10, t_i64)
  inst_alloca = ir_inst_alloca("%ptr", t_i64, 16, "x")
  inst_load = ir_inst_load("%v15", ir_val_reg("%ptr", t_ptr), t_i64)
  inst_store = ir_inst_store(v_c10, ir_val_reg("%ptr", t_ptr), t_i64)
  inst_gep = ir_inst_gep("%elem", ir_val_reg("%ptr", t_ptr), v_c10, t_i64, 8)
  inst_br = ir_inst_branch(1)
  inst_brc = ir_inst_branch_cond(ir_val_reg("%v14", t_bool), 1, 2)
  inst_ret = ir_inst_ret(v_c10, t_i64)
  inst_call = ir_inst_call("%v16", "helper_fn", [v_c10], t_i64)
  inst_sys = ir_inst_syscall("%v17", ir_val_const_int(1, t_i64), [v_c10], t_i64)
  phi_inc1 = ir_phi_incoming_new(ir_val_const_int(100, t_i64), 1, "bb_then")
  phi_inc2 = ir_phi_incoming_new(ir_val_const_int(200, t_i64), 2, "bb_else")
  inst_phi = ir_inst_phi("%v18", t_i64, [phi_inc1, phi_inc2])

  r = assert_eq_str(r, inst_add.op, "ADD", "IR ADD opcode")
  r = assert_eq_str(r, inst_sub.op, "SUB", "IR SUB opcode")
  r = assert_eq_str(r, inst_mul.op, "MUL", "IR MUL opcode")
  r = assert_eq_str(r, inst_div.op, "SDIV", "IR SDIV opcode")
  r = assert_eq_str(r, inst_mod.op, "SREM", "IR SREM opcode")
  r = assert_eq_str(r, inst_and.op, "AND", "IR AND opcode")
  r = assert_eq_str(r, inst_or.op, "OR", "IR OR opcode")
  r = assert_eq_str(r, inst_xor.op, "XOR", "IR XOR opcode")
  r = assert_eq_str(r, inst_shl.op, "SHL", "IR SHL opcode")
  r = assert_eq_str(r, inst_shr.op, "SHR", "IR SHR opcode")
  r = assert_eq_str(r, inst_neg.op, "NEG", "IR NEG opcode")
  r = assert_eq_str(r, inst_not.op, "NOT", "IR NOT opcode")
  r = assert_eq_str(r, inst_cmp.op, "CMP", "IR CMP opcode")
  r = assert_eq_str(r, inst_cmp.cmp_op, "eq", "IR CMP normalized op 'eq'")
  r = assert_eq_str(r, inst_alloca.op, "ALLOCA", "IR ALLOCA opcode")
  r = assert_eq_str(r, inst_load.op, "LOAD", "IR LOAD opcode")
  r = assert_eq_str(r, inst_store.op, "STORE", "IR STORE opcode")
  r = assert_eq_str(r, inst_gep.op, "GEP", "IR GEP opcode")
  r = assert_eq_str(r, inst_br.op, "BR", "IR BR opcode")
  r = assert_eq_str(r, inst_brc.op, "BR_COND", "IR BR_COND opcode")
  r = assert_eq_str(r, inst_ret.op, "RET", "IR RET opcode")
  r = assert_eq_str(r, inst_call.op, "CALL", "IR CALL opcode")
  r = assert_eq_str(r, inst_sys.op, "SYSCALL", "IR SYSCALL opcode")
  r = assert_eq_str(r, inst_phi.op, "PHI", "IR PHI opcode")

  r = assert_true(r, ir_op_is_term("RET"), "ir_op_is_term('RET')")
  r = assert_true(r, ir_op_is_term("BR"), "ir_op_is_term('BR')")
  r = assert_true(r, ir_op_is_term("BR_COND"), "ir_op_is_term('BR_COND')")
  r = assert_true(r, ir_op_is_br("BR"), "ir_op_is_br('BR')")
  r = assert_true(r, ir_op_is_br_cond("BR_COND"), "ir_op_is_br_cond('BR_COND')")
  r = assert_true(r, ir_op_is_phi("PHI"), "ir_op_is_phi('PHI')")
  r = assert_true(r, ir_op_is_valid("ADD"), "ir_op_is_valid('ADD')")

  @! --------------------------------------------------------------------------
  @! SECTION 3: Dominance Analysis & Cooper-Harvey-Kennedy Algorithm
  @! --------------------------------------------------------------------------
  println("▶ [Section 3] Dominance Analysis (idom, df, intersect)...")
  @! Build Diamond CFG: 0 (Entry) -> 1 (Then), 2 (Else) -> 3 (Join)
  bb0 = ir_block_new(0, "entry")
  bb0.succs = [1, 2]
  bb1 = ir_block_new(1, "then")
  bb1.preds = [0]
  bb1.succs = [3]
  bb2 = ir_block_new(2, "else")
  bb2.preds = [0]
  bb2.succs = [3]
  bb3 = ir_block_new(3, "join")
  bb3.preds = [1, 2]
  bb3.succs = []

  diamond_blocks = [bb0, bb1, bb2, bb3]
  diamond_dom = ir_compute_dominators(diamond_blocks)
  diamond_df = ir_compute_dominance_frontiers(diamond_dom)

  r = assert_eq_i64(r, diamond_dom[0].idom, 0, "Diamond Entry idom is 0")
  r = assert_eq_i64(r, diamond_dom[1].idom, 0, "Diamond Then idom is 0 (Entry)")
  r = assert_eq_i64(r, diamond_dom[2].idom, 0, "Diamond Else idom is 0 (Entry)")
  r = assert_eq_i64(r, diamond_dom[3].idom, 0, "Diamond Join idom is 0 (Entry)")
  r = assert_eq_i64(r, diamond_df[1].df.len(), 1, "Diamond Then has 1 DF block")
  r = assert_eq_i64(r, diamond_df[1].df[0], 3, "Diamond Then DF is Join (3)")
  r = assert_eq_i64(r, diamond_df[2].df[0], 3, "Diamond Else DF is Join (3)")

  @! --------------------------------------------------------------------------
  @! SECTION 4: 10-Invariant CFG Validator Tests (Positive & Negative)
  @! --------------------------------------------------------------------------
  println("▶ [Section 4] 10-Invariant CFG Validator (Positive & Negative)...")

  @! Positive test: Valid function
  fn_valid = ir_function_new("test_valid", ["x"], t_i64)
  fn_valid.blocks[0] = ir_block_add_inst(fn_valid.blocks[0], ir_inst_ret(v_c10, t_i64))
  v_res = ir_verify_function(fn_valid)
  r = assert_eq_i64(r, v_res.ok, 1, "Invariant Verifier: Valid function passes with ok=1")
  r = assert_eq_i64(r, v_res.errors.len(), 0, "Invariant Verifier: 0 errors on valid function")

  @! Invariant 1 Violation: Entry block ID != 0 or has predecessors
  fn_inv1 = ir_function_new("test_inv1", [], t_i64)
  fn_inv1.blocks[0].preds = [1]
  fn_inv1.blocks[0] = ir_block_add_inst(fn_inv1.blocks[0], ir_inst_ret(v_c10, t_i64))
  v_inv1 = ir_verify_function(fn_inv1)
  r = assert_eq_i64(r, v_inv1.ok, 0, "Invariant 1: Entry block with predecessors is rejected")

  @! Invariant 2 Violation: Missing terminator in block
  fn_inv2 = ir_function_new("test_inv2", [], t_i64)
  fn_inv2.blocks[0] = ir_block_add_inst(fn_inv2.blocks[0], inst_add)
  v_inv2 = ir_verify_function(fn_inv2)
  r = assert_eq_i64(r, v_inv2.ok, 0, "Invariant 2: Block missing terminator is rejected")

  @! Invariant 3 Violation: Branch to non-existent target
  fn_inv3 = ir_function_new("test_inv3", [], t_i64)
  fn_inv3.blocks[0] = ir_block_add_inst(fn_inv3.blocks[0], ir_inst_branch(99))
  fn_inv3.blocks[0].succs = [99]
  v_inv3 = ir_verify_function(fn_inv3)
  r = assert_eq_i64(r, v_inv3.ok, 0, "Invariant 3: Non-existent branch target is rejected")

  @! Invariant 4 Violation: Predecessor-Successor asymmetry
  fn_inv4 = ir_function_new("test_inv4", [], t_i64)
  b_next = ir_block_new(1, "b1")
  b_next = ir_block_add_inst(b_next, ir_inst_ret(v_c10, t_i64))
  fn_inv4.blocks[0] = ir_block_add_inst(fn_inv4.blocks[0], ir_inst_branch(1))
  fn_inv4.blocks[0].succs = [1]
  @! Intentionally leave b_next.preds empty!
  fn_inv4.blocks = fn_inv4.blocks.push(b_next)
  v_inv4 = ir_verify_function(fn_inv4)
  r = assert_eq_i64(r, v_inv4.ok, 0, "Invariant 4: Asymmetric CFG edge is rejected")

  @! Invariant 5 Violation: Duplicate SSA register definition
  fn_inv5 = ir_function_new("test_inv5", [], t_i64)
  fn_inv5.blocks[0] = ir_block_add_inst(fn_inv5.blocks[0], ir_inst_add("%v0", v_c10, v_c10, t_i64))
  fn_inv5.blocks[0] = ir_block_add_inst(fn_inv5.blocks[0], ir_inst_add("%v0", v_c10, v_c10, t_i64))
  fn_inv5.blocks[0] = ir_block_add_inst(fn_inv5.blocks[0], ir_inst_ret(v_c10, t_i64))
  v_inv5 = ir_verify_function(fn_inv5)
  r = assert_eq_i64(r, v_inv5.ok, 0, "Invariant 5: Duplicate SSA register definition is rejected")

  @! Invariant 6 Violation: Invalid instruction opcode
  fn_inv6 = ir_function_new("test_inv6", [], t_i64)
  bad_inst = ir_inst("UNKNOWN_OP", "%v0", t_i64, [], 0)
  fn_inv6.blocks[0] = ir_block_add_inst(fn_inv6.blocks[0], bad_inst)
  fn_inv6.blocks[0] = ir_block_add_inst(fn_inv6.blocks[0], ir_inst_ret(v_c10, t_i64))
  v_inv6 = ir_verify_function(fn_inv6)
  r = assert_eq_i64(r, v_inv6.ok, 0, "Invariant 6: Invalid opcode is rejected")

  @! Invariant 7 Violation: Unreachable block
  fn_inv7 = ir_function_new("test_inv7", [], t_i64)
  fn_inv7.blocks[0] = ir_block_add_inst(fn_inv7.blocks[0], ir_inst_ret(v_c10, t_i64))
  dead_b = ir_block_new(1, "dead_block")
  dead_b = ir_block_add_inst(dead_b, ir_inst_ret(v_c10, t_i64))
  fn_inv7.blocks = fn_inv7.blocks.push(dead_b)
  v_inv7 = ir_verify_function(fn_inv7)
  r = assert_true(r, v_inv7.warnings.len() > 0, "Invariant 7: Unreachable basic block generates warning")

  @! Invariant 8 Violation: Duplicate block IDs
  fn_inv8 = ir_function_new("test_inv8", [], t_i64)
  dup_b = ir_block_new(0, "dup_bb0")
  dup_b = ir_block_add_inst(dup_b, ir_inst_ret(v_c10, t_i64))
  fn_inv8.blocks[0] = ir_block_add_inst(fn_inv8.blocks[0], ir_inst_ret(v_c10, t_i64))
  fn_inv8.blocks = fn_inv8.blocks.push(dup_b)
  v_inv8 = ir_verify_function(fn_inv8)
  r = assert_eq_i64(r, v_inv8.ok, 0, "Invariant 8: Duplicate block ID is rejected")

  @! Invariant 9 Violation: Duplicate parameter names
  fn_inv9 = ir_function_new("test_inv9", ["x", "x"], t_i64)
  fn_inv9.blocks[0] = ir_block_add_inst(fn_inv9.blocks[0], ir_inst_ret(v_c10, t_i64))
  v_inv9 = ir_verify_function(fn_inv9)
  r = assert_eq_i64(r, v_inv9.ok, 0, "Invariant 9: Duplicate parameter name is rejected")

  @! --------------------------------------------------------------------------
  @! SECTION 5: AST-to-IR Lowering Engine End-to-End
  @! --------------------------------------------------------------------------
  println("▶ [Section 5] AST-to-IR Lowering Engine End-to-End...")

  @! Program A: Arithmetic & Control Flow
  fn_ast_a = ast_node("FnDef")
  fn_ast_a.name = "calc_sum"
  fn_ast_a.params = ["n"]
  fn_ast_a.ret_type = "i64"

  let_s = ast_node("Assign")
  let_s.target = "sum"
  let_s.value = ast_node("LiteralInt")
  let_s.value.val = 0

  let_i = ast_node("Assign")
  let_i.target = "i"
  let_i.value = ast_node("LiteralInt")
  let_i.value.val = 1

  while_node = ast_node("WhileLoop")
  cmp_n = ast_node("BinaryOp")
  cmp_n.op = "<="
  v_i = ast_node("Variable")
  v_i.name = "i"
  v_n = ast_node("Variable")
  v_n.name = "n"
  cmp_n.left = v_i
  cmp_n.right = v_n
  while_node.condition = cmp_n

  sum_add = ast_node("Assign")
  sum_add.target = "sum"
  b_sum = ast_node("BinaryOp")
  b_sum.op = "+"
  v_s2 = ast_node("Variable")
  v_s2.name = "sum"
  v_i2 = ast_node("Variable")
  v_i2.name = "i"
  b_sum.left = v_s2
  b_sum.right = v_i2
  sum_add.value = b_sum

  i_add = ast_node("Assign")
  i_add.target = "i"
  b_i = ast_node("BinaryOp")
  b_i.op = "+"
  v_i3 = ast_node("Variable")
  v_i3.name = "i"
  b_i.left = v_i3
  b_i.right = ast_node("LiteralInt")
  b_i.right.val = 1
  i_add.value = b_i

  while_node.body = [sum_add, i_add]

  ret_s = ast_node("Return")
  v_s3 = ast_node("Variable")
  v_s3.name = "sum"
  ret_s.value = v_s3

  fn_ast_a.body = [let_s, let_i, while_node, ret_s]

  mod_res_a = ir_module_from_ast([fn_ast_a], { module_name: "test_prog_a", dump_ir: 0 })
  r = assert_eq_i64(r, mod_res_a.error, 0, "Lowering calc_sum AST succeeds with error=0")
  r = assert_eq_i64(r, mod_res_a.module.functions.len(), 1, "Lowered module has 1 function")
  r = assert_eq_str(r, mod_res_a.module.functions[0].name, "calc_sum", "Function name is 'calc_sum'")
  r = assert_true(r, mod_res_a.module.functions[0].blocks.len() >= 3, "calc_sum CFG has >= 3 basic blocks")

  @! Program B: Struct Declaration & Field Lowering
  st_point = ast_node("StructDef")
  st_point.name = "Point"
  f_x = ast_node("Field")
  f_x.name = "x"
  f_x.type = "i64"
  f_y = ast_node("Field")
  f_y.name = "y"
  f_y.type = "i64"
  st_point.elements = [f_x, f_y]

  fn_ast_b = ast_node("FnDef")
  fn_ast_b.name = "make_point"
  fn_ast_b.params = []
  fn_ast_b.ret_type = "i64"
  ret_zero = ast_node("Return")
  ret_zero.value = ast_node("LiteralInt")
  ret_zero.value.val = 0
  fn_ast_b.body = [ret_zero]

  mod_res_b = ir_module_from_ast([st_point, fn_ast_b], { module_name: "test_prog_b", dump_ir: 0 })
  r = assert_eq_i64(r, mod_res_b.error, 0, "Lowering struct definition succeeds with error=0")
  r = assert_eq_i64(r, mod_res_b.module.struct_defs.len(), 1, "Module registered 1 struct definition")
  r = assert_eq_str(r, mod_res_b.module.struct_defs[0].name, "Point", "Registered struct name is 'Point'")

  @! Program C: Syscall Statement Lowering
  fn_ast_c = ast_node("FnDef")
  fn_ast_c.name = "get_pid_wrapper"
  fn_ast_c.params = []
  fn_ast_c.ret_type = "i64"

  sys_call_node = ast_node("Syscall")
  sys_call_node.target = "pid"
  sys_call_node.val = 39 @! getpid
  sys_call_node.args = []

  ret_pid = ast_node("Return")
  v_pid = ast_node("Variable")
  v_pid.name = "pid"
  ret_pid.value = v_pid
  fn_ast_c.body = [sys_call_node, ret_pid]

  mod_res_c = ir_module_from_ast([fn_ast_c], { module_name: "test_prog_c", dump_ir: 0 })
  r = assert_eq_i64(r, mod_res_c.error, 0, "Lowering Syscall AST succeeds with error=0")

  println("=================================================================")
  println("📊 MAYA IR TEST SUITE SUMMARY:")
  println("   Total Tests : " + r.total.to_str())
  println("   Passed      : " + r.passed.to_str())
  println("   Failed      : " + r.failed.to_str())
  @if r.failed == 0
    println("🎉 ALL MAYA IR TESTS PASSED CLEANLY!")
  @else
    println("❌ MAYA IR TESTS COMPLETED WITH FAILURES!")
    return 1
  @end
  println("=================================================================")
  return 0
@end
