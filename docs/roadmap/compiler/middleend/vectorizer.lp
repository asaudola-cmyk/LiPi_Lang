@! ============================================================================
@! MAYA COMPILER MIDDLEEND — AUTO-VECTORIZATION PASS (vectorizer.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: SIMD Loop Transformation, Vector Preamble, Vector Main Loop (8x/4x),
@!           Horizontal Reduction Epilogue, Scalar Remainder Cleanup Loop
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/middleend/loop_analysis"
import "compiler/middleend/vector_ir"

@! ----------------------------------------------------------------------------
@! 1. LOOP TRANSFORMATION ENGINE
@! ----------------------------------------------------------------------------

@fn vectorize_loop(loop_desc)
  @! Perform complete loop and stride analysis
  verdict = analyze_loop(loop_desc, 0)
  
  @if verdict.is_vectorizable == 0
    return {
      is_vectorized: 0,
      original_loop: loop_desc,
      verdict: verdict
    }
  @end

  vf = verdict.vector_factor
  vtype = vec_type_f32(vf)
  @if verdict.element_type == "float64"
    vtype = vec_type_f64(vf)
  @elif verdict.element_type == "int32"
    vtype = vec_type_i32(vf)
  @end

  ind_var = verdict.induction.var_name
  upper_bound = loop_desc.upper_bound
  
  @! 1. Vector Preamble
  preamble_insts = []
  preamble_insts = preamble_insts.push({
    op: "ASSIGN",
    var: ind_var + "_vec_limit",
    expr: { op: "-", left: upper_bound, right: { op: "%", left: upper_bound, right: vf } }
  })
  preamble_insts = preamble_insts.push({
    op: "ASSIGN",
    var: ind_var,
    expr: 0
  })

  has_reduction = verdict.reduction.has_reduction
  acc_vreg = 0
  @if has_reduction == 1
    acc_vreg = vreg_new(100, "%v_acc_" + verdict.reduction.reduction_var, vtype)
    preamble_insts = preamble_insts.push(vir_vbroadcast(acc_vreg, verdict.reduction.identity_val, vtype))
  @end

  @! 2. Vector Main Loop Body
  vec_body_insts = []
  vreg_counter = 0

  body_ops = loop_desc.body_operations
  b_len = 0
  @if body_ops != 0 b_len = body_ops.len() @end

  bi = 0
  @while bi < b_len
    b_op = body_ops[bi]
    
    @if b_op.op == "LOAD" || b_op.kind == "ARRAY_LOAD"
      vreg = vreg_new(vreg_counter, "%v_" + b_op.dest, vtype)
      vreg_counter = vreg_counter + 1
      vec_body_insts = vec_body_insts.push(vir_vload(vreg, b_op.array, ind_var, vtype))
    @elif b_op.op == "STORE" || b_op.kind == "ARRAY_STORE"
      src_vreg = vreg_new(vreg_counter - 1, "%v_" + b_op.src, vtype)
      vec_body_insts = vec_body_insts.push(vir_vstore(b_op.array, ind_var, src_vreg, vtype))
    @elif b_op.op == "+" || b_op.op == "ADD" || b_op.op == "ARRAY_ADD"
      v_dest = vreg_new(vreg_counter, "%v_" + b_op.dest, vtype)
      vreg_counter = vreg_counter + 1
      v_left = vreg_new(vreg_counter - 3, "%v_" + b_op.left, vtype)
      v_right = vreg_new(vreg_counter - 2, "%v_" + b_op.right, vtype)
      
      @if has_reduction == 1 && b_op.dest == verdict.reduction.reduction_var
        vec_body_insts = vec_body_insts.push(vir_vadd(acc_vreg, acc_vreg, v_left, vtype))
      @else
        vec_body_insts = vec_body_insts.push(vir_vadd(v_dest, v_left, v_right, vtype))
      @end
    @elif b_op.op == "*" || b_op.op == "MUL" || b_op.op == "ARRAY_MUL"
      v_dest = vreg_new(vreg_counter, "%v_" + b_op.dest, vtype)
      vreg_counter = vreg_counter + 1
      v_left = vreg_new(vreg_counter - 3, "%v_" + b_op.left, vtype)
      v_right = vreg_new(vreg_counter - 2, "%v_" + b_op.right, vtype)
      vec_body_insts = vec_body_insts.push(vir_vmul(v_dest, v_left, v_right, vtype))
    @elif b_op.op == "FMA" || b_op.op == "VFMA"
      v_dest = vreg_new(vreg_counter, "%v_" + b_op.dest, vtype)
      vreg_counter = vreg_counter + 1
      v_a = vreg_new(vreg_counter - 4, "%v_" + b_op.a, vtype)
      v_b = vreg_new(vreg_counter - 3, "%v_" + b_op.b, vtype)
      v_c = vreg_new(vreg_counter - 2, "%v_" + b_op.c, vtype)
      vec_body_insts = vec_body_insts.push(vir_vfma(v_dest, v_a, v_b, v_c, vtype))
    @end
    bi = bi + 1
  @end

  @! Increment vector induction variable by vector factor
  vec_body_insts = vec_body_insts.push({
    op: "ASSIGN",
    var: ind_var,
    expr: { op: "+", left: ind_var, right: vf }
  })

  @! 3. Horizontal Reduction Epilogue
  epilogue_insts = []
  @if has_reduction == 1
    epilogue_insts = epilogue_insts.push(vir_vreduce_sum(verdict.reduction.reduction_var, acc_vreg, vtype))
  @end

  @! 4. Scalar Remainder Cleanup Loop
  remainder_insts = []
  @! Original scalar body executed 1-by-1 until upper_bound
  ri = 0
  @while ri < b_len
    remainder_insts = remainder_insts.push(body_ops[ri])
    ri = ri + 1
  @end
  remainder_insts = remainder_insts.push({
    op: "ASSIGN",
    var: ind_var,
    expr: { op: "+", left: ind_var, right: 1 }
  })

  return {
    is_vectorized: 1,
    vector_factor: vf,
    vector_type: vtype,
    preamble: preamble_insts,
    vector_body: vec_body_insts,
    epilogue: epilogue_insts,
    remainder_body: remainder_insts,
    verdict: verdict
  }
@end

@! ----------------------------------------------------------------------------
@! 2. FUNCTION & MODULE VECTORIZATION PASSES
@! ----------------------------------------------------------------------------

@fn vectorize_function_loops(fn_obj)
  new_blocks = []
  b_list = fn_obj.blocks
  b_len = 0
  @if b_list != 0 b_len = b_list.len() @end

  i = 0
  @while i < b_len
    block = b_list[i]
    new_insts = []
    
    inst_len = 0
    @if block.instructions != 0 inst_len = block.instructions.len() @end

    idx = 0
    @while idx < inst_len
      inst = block.instructions[idx]
      
      @if inst.op == "LOOP_START" || inst.kind == "LOOP_START"
        vec_inst = { op: "VECTOR_LOOP", factor: 8 }
        new_insts = new_insts.push(vec_inst)
      @elif inst.op == "ARRAY_ADD"
        new_insts = new_insts.push({ op: "VADDPS", dest: inst.dest, left: inst.left, right: inst.right, factor: 8 })
      @elif inst.op == "ARRAY_MUL"
        new_insts = new_insts.push({ op: "VMULPS", dest: inst.dest, left: inst.left, right: inst.right, factor: 8 })
      @elif inst.op == "ARRAY_FMA"
        new_insts = new_insts.push({ op: "VFMA", dest: inst.dest, a: inst.a, b: inst.b, c: inst.c, factor: 8 })
      @else
        new_insts = new_insts.push(inst)
      @end
      idx = idx + 1
    @end

    block.instructions = new_insts
    new_blocks = new_blocks.push(block)
    i = i + 1
  @end

  fn_obj.blocks = new_blocks
  fn_obj.vectorized = 1
  return fn_obj
@end

@fn vectorize_function(fn_obj)
  return vectorize_function_loops(fn_obj)
@end

@fn vectorize_module(mod)
  fn_list = mod.functions
  @if fn_list == 0 fn_list = mod.funcs @end
  @if fn_list == 0 return mod @end

  new_funcs = []
  i = 0
  len = fn_list.len()
  @while i < len
    fn_obj = fn_list[i]
    new_funcs = new_funcs.push(vectorize_function(fn_obj))
    i = i + 1
  @end

  mod.functions = new_funcs
  mod.vectorized = 1
  return mod
@end
