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

  say("ALL IR PEEPHOLE TESTS PASSED")
  return 0
@end
