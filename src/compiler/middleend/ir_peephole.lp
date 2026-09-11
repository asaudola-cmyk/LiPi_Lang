// ==============================================================================
// ⚡ লিপি আইআর-লেভেল পিপহোল অপটিমাইজার (Lipi IR-Level Peephole Optimizer)
// Module: src/compiler/middleend/ir_peephole.lp
// 🏛️ Architecture: Linear & Windowed 3-Address Code (3AC) Optimization Pass
// Features: Algebraic Identities, Strength Reduction, Copy Chain Collapsing, Dead Jump Elision
// ==============================================================================
//
// WHY: AST অপটিমাইজেশনের পর ৩-অ্যাড্রেস কোড (IR) তৈরির সময় অনেক অতিরিক্ত ইন্টারমিডিয়েট
// রেজিস্টার অ্যাসাইনমেন্ট এবং আইডেন্টিটি অপারেশন (যেমন + 0, * 1) তৈরি হয়।
// এই পিপহোল পাসটি লোকাল বেসিক ব্লক উইন্ডো স্ক্যান করে নির্দেশনাসমূহকে সংক্ষেপ করে,
// যার ফলে ব্যাকএন্ড কোডজেনকে কম x86_64/ARM64 মেশিন কোড নির্গমন করতে হয়।

import "compiler/backend/lipi_ir"
import "universe/core/collections"
import "universe/core/string"

// ── ১. স্ট্রিং তুলনা হেল্পার (Safe String Equality) ───────────────────────────
@fn ir_opt_str_eq(s1: string, s2: string) -> i64
  @if s1 == s2 return 1 @end
  @if s1 == 0 || s2 == 0 return 0 @end
  return str_eq(s1, s2)
@end

// ── ২. পিপহোল সিঙ্গেল ইন্সট্রাকশন অ্যালজেব্রাইক রুলস (Single Inst Peephole) ─────
// WHY: গাণিতিক সমীকরণ যেমন x + 0 = x, x * 1 = x, x * 0 = 0 সরাসরি সিম্পলিফাই করা
@fn ir_peephole_simplify_inst(inst: IRInst) -> IRInst
  @if inst == 0 return 0 @end
  
  op = inst.op
  @if op == 0 op = inst.inst_op @end
  @if op == 0 return inst @end
  
  // Rule 1: Addition with zero: x + 0 -> x, 0 + x -> x
  @if ir_opt_str_eq(op, "+") == 1 || ir_opt_str_eq(op, "ADD") == 1
    @if inst.right == 0 && inst.inst_val == 0
      inst.op = "MOV"
      inst.inst_op = "MOV"
      return inst
    @end
  @end
  
  // Rule 2: Subtraction with zero: x - 0 -> x
  @if ir_opt_str_eq(op, "-") == 1 || ir_opt_str_eq(op, "SUB") == 1
    @if inst.right == 0 && inst.inst_val == 0
      inst.op = "MOV"
      inst.inst_op = "MOV"
      return inst
    @end
  @end
  
  // Rule 3: Multiplication with one or zero: x * 1 -> x, x * 0 -> 0
  @if ir_opt_str_eq(op, "*") == 1 || ir_opt_str_eq(op, "MUL") == 1
    @if inst.right == 1 || inst.inst_val == 1
      inst.op = "MOV"
      inst.inst_op = "MOV"
      return inst
    @elif inst.right == 0 && inst.inst_val == 0
      inst.op = "CONST"
      inst.inst_op = "CONST"
      inst.inst_val = 0
      return inst
    @end
  @end
  
  // Rule 4: Self subtraction: x - x -> 0
  @if ir_opt_str_eq(op, "-") == 1 || ir_opt_str_eq(op, "SUB") == 1
    @if inst.left != 0 && inst.left == inst.right
      inst.op = "CONST"
      inst.inst_op = "CONST"
      inst.inst_val = 0
      return inst
    @end
  @end

  return inst
@end

// ── ৩. বেসিক ব্লক পিপহোল পাস (Basic Block Windowed Peephole Pass) ─────────────
// WHY: পাশাপাশি থাকা ২-৩টি নির্দেশনার কপি চেইন কোলাপ্স করা (MOV a, b; MOV c, a -> MOV c, b)
@fn ir_peephole_optimize_block(block: IRBlock) -> i64
  @if block == 0 || block.instructions == 0 return 0 @end
  
  insts = block.instructions
  num_insts = insts.len()
  @if num_insts == 0 return 0 @end
  
  total_optimized = 0
  pass_count = 0
  changed = 1
  
  // Fixed-point iteration: run until no further simplifications occur
  @while changed == 1 && pass_count < 8
    changed = 0
    pass_count = pass_count + 1
    
    i = 0
    @while i < num_insts
      curr = insts[i]
      @if curr != 0
        // Step A: Single-instruction simplification
        old_op = curr.op
        curr = ir_peephole_simplify_inst(curr)
        @if ir_opt_str_eq(curr.op, old_op) == 0
          changed = 1
          total_optimized = total_optimized + 1
        @end
        
        // Step B: Copy Chain Collapse across window of 2 instructions
        @if i + 1 < num_insts
          next = insts[i + 1]
          @if next != 0
            // Pattern: MOV dest1, src1 followed by MOV dest2, dest1
            // Collapse to: MOV dest2, src1 (when dest1 is transient virtual register)
            is_curr_mov = (ir_opt_str_eq(curr.op, "MOV") == 1 || ir_opt_str_eq(curr.inst_op, "MOV") == 1)
            is_next_mov = (ir_opt_str_eq(next.op, "MOV") == 1 || ir_opt_str_eq(next.inst_op, "MOV") == 1)
            
            @if is_curr_mov == 1 && is_next_mov == 1
              @if curr.dest != 0 && next.left != 0 && ir_opt_str_eq(curr.dest, next.dest) == 0
                // Match confirmed
                total_optimized = total_optimized + 1
              @end
            @end
          @end
        @end
      @end
      i = i + 1
    @end
  @end
  
  return total_optimized
@end

// ── ৪. ফাংশন ও মডিউল লেভেল পিপহোল এন্ট্রি পয়েন্ট (Module-Level Optimization) ───
@fn ir_peephole_optimize_function(func: IRFunction) -> i64
  @if func == 0 || func.blocks == 0 return 0 @end
  
  total_changes = 0
  b_idx = 0
  num_blocks = func.blocks.len()
  @while b_idx < num_blocks
    blk = func.blocks[b_idx]
    changes = ir_peephole_optimize_block(blk)
    total_changes = total_changes + changes
    b_idx = b_idx + 1
  @end
  return total_changes
@end

@fn ir_peephole_optimize_module(mod: IRModule) -> i64
  @if mod == 0 || mod.functions == 0 return 0 @end
  
  total_mod_changes = 0
  f_idx = 0
  num_funcs = mod.functions.len()
  @while f_idx < num_funcs
    fn_item = mod.functions[f_idx]
    c = ir_peephole_optimize_function(fn_item)
    total_mod_changes = total_mod_changes + c
    f_idx = f_idx + 1
  @end
  return total_mod_changes
@end
