@! Empirical reproduction of Rule 3 CFG Verifier Internal Terminator bypass bug
import "compiler/backend/maya_ir"

fn main()
  println("=== CFG VERIFIER INTERNAL TERMINATOR ADVERSARIAL TEST ===")
  
  @! Construct a malformed function where Block 0 contains an internal RET followed by dead ADD and another RET
  fn_bad = ir_function_new("bad_fn_internal_term", [], ir_type_i64())
  bb = fn_bad.blocks[0]
  
  ret1 = ir_inst_ret(ir_val_const_int(1, ir_type_i64()), ir_type_i64())
  dead_add = ir_inst_add("%t0", ir_val_const_int(10, ir_type_i64()), ir_val_const_int(20, ir_type_i64()), ir_type_i64())
  ret2 = ir_inst_ret(ir_val_reg("%t0", ir_type_i64()), ir_type_i64())
  
  bb.instructions = [ret1, dead_add, ret2]
  fn_bad.blocks = [bb]

  res = ir_verify_cfg(fn_bad)
  
  println("Function has 3 instructions in Block 0: [RET, ADD, RET]")
  println("Expected Verifier Result: ok = 0 (MUST reject internal terminator)")
  println("Actual Verifier Result  : ok = " + res.ok.to_str())
  println("Errors Count            : " + res.errors.len().to_str())
  
  @if res.ok == 1
    println("❌ CRITICAL BUG CONFIRMED: ir_verify_cfg falsely accepted block with mid-block terminator!")
  @else
    println("✅ Verifier correctly rejected mid-block terminator.")
  @end
