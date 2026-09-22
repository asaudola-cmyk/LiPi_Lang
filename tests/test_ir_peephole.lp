// tests/test_ir_peephole.lp
// Validates 3AC IR-level Peephole Optimizer
import "compiler/backend/lipi_ir"
import "compiler/middleend/ir_peephole"
import "universe/core/io"

@fn main()
  say("Testing IR Peephole Optimizer...")
  
  // Create an IR instruction: ADD r0, r1, 0
  inst = {
    inst_op: "ADD",
    dest: "r0",
    inst_type: 1,
    op: "+",
    left: 1,
    right: 0,
    ptr: 0,
    inst_val: 0,
    target: 0,
    cond: 0,
    true_target: 0,
    false_target: 0,
    nr: 0,
    stride: 0,
    args: [],
    incoming: [],
    is_terminator: 0,
    cmp_op: "",
    align: 0,
    inst_elem_type: 0,
    target_label: "",
    then_label: "",
    else_label: "",
    callee: ""
  }
  
  opt_inst = ir_peephole_simplify_inst(inst)
  if ir_opt_str_eq(opt_inst.op, "MOV") == 1
    say("PASS: x + 0 optimized to MOV x")
  else
    say("FAIL: x + 0 not optimized")
  end

  // Create an IR instruction: MUL r2, r3, 1
  inst2 = {
    inst_op: "MUL",
    dest: "r2",
    inst_type: 1,
    op: "*",
    left: 3,
    right: 1,
    ptr: 0,
    inst_val: 1,
    target: 0,
    cond: 0,
    true_target: 0,
    false_target: 0,
    nr: 0,
    stride: 0,
    args: [],
    incoming: [],
    is_terminator: 0,
    cmp_op: "",
    align: 0,
    inst_elem_type: 0,
    target_label: "",
    then_label: "",
    else_label: "",
    callee: ""
  }
  
  opt_inst2 = ir_peephole_simplify_inst(inst2)
  if ir_opt_str_eq(opt_inst2.op, "MOV") == 1
    say("PASS: x * 1 optimized to MOV x")
  else
    say("FAIL: x * 1 not optimized")
  end

  // Test 3: MUL r4, r5, 8 -> SHL r4, r5, 3
  inst3 = {
    inst_op: "MUL",
    dest: "r4",
    inst_type: 1,
    op: "*",
    left: 5,
    right: 8,
    ptr: 0,
    inst_val: 8,
    target: 0,
    cond: 0,
    true_target: 0,
    false_target: 0,
    nr: 0,
    stride: 0,
    args: [],
    incoming: [],
    is_terminator: 0,
    cmp_op: "",
    align: 0,
    inst_elem_type: 0,
    target_label: "",
    then_label: "",
    else_label: "",
    callee: ""
  }
  opt_inst3 = ir_peephole_simplify_inst(inst3)
  if ir_opt_str_eq(opt_inst3.op, "SHL") == 1 && opt_inst3.inst_val == 3
    say("PASS: x * 8 optimized to SHL x, 3")
  else
    say("FAIL: x * 8 not optimized to SHL")
  end

  // Test 4: MOD r6, r7, 16 -> AND r6, r7, 15
  inst4 = {
    inst_op: "MOD",
    dest: "r6",
    inst_type: 1,
    op: "%",
    left: 7,
    right: 16,
    ptr: 0,
    inst_val: 16,
    target: 0,
    cond: 0,
    true_target: 0,
    false_target: 0,
    nr: 0,
    stride: 0,
    args: [],
    incoming: [],
    is_terminator: 0,
    cmp_op: "",
    align: 0,
    inst_elem_type: 0,
    target_label: "",
    then_label: "",
    else_label: "",
    callee: ""
  }
  opt_inst4 = ir_peephole_simplify_inst(inst4)
  if ir_opt_str_eq(opt_inst4.op, "AND") == 1 && opt_inst4.inst_val == 15
    say("PASS: x % 16 optimized to AND x, 15")
  else
    say("FAIL: x % 16 not optimized to AND")
  end

  say("ALL IR PEEPHOLE TESTS PASSED")
  return 0
@end
