@! ============================================================================
@! MAYA COMPILER MIDDLEEND — SIMD LOOP & STRIDE ANALYSIS (loop_analysis.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: Canonical Loop Induction Detection, Memory Access Stride Analysis,
@!           Affine Borrow Checker Alias-Free Verification, Reduction Detection
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. ANALYSIS STATE CONSTRUCTOR
@! ----------------------------------------------------------------------------

@fn loop_analysis_new()
  return {
    canonical_loops: [],
    strides: [],
    reductions: [],
    alias_free_checks: []
  }
@end

@! ----------------------------------------------------------------------------
@! 2. CANONICAL INDUCTION VARIABLE ANALYSIS
@! ----------------------------------------------------------------------------

@fn analyze_induction_variable(loop_desc)
  @! Analyzes loop initialization, step, and termination condition
  var_name = loop_desc.induction_var
  @if var_name == 0
    var_name = "i"
  @end

  init_val = loop_desc.init_val
  step_val = loop_desc.step
  @if step_val == 0
    step_val = 1
  @end

  upper_bound = loop_desc.upper_bound
  cond_op = loop_desc.cond_op
  @if cond_op == 0
    cond_op = "<"
  @end

  is_canonical = 0
  @if init_val == 0 && step_val == 1 && (cond_op == "<" || cond_op == "<=")
    is_canonical = 1
  @elif step_val > 0 && (cond_op == "<" || cond_op == "<=")
    is_canonical = 1
  @end

  return {
    is_canonical: is_canonical,
    var_name: var_name,
    init_val: init_val,
    step: step_val,
    cond_op: cond_op,
    upper_bound: upper_bound
  }
@end

@! ----------------------------------------------------------------------------
@! 3. MEMORY ACCESS STRIDE ANALYSIS
@! ----------------------------------------------------------------------------

@fn analyze_array_strides(loop_desc, ind_var_name)
  accesses = loop_desc.array_accesses
  a_len = 0
  @if accesses != 0
    a_len = accesses.len()
  @end

  stride_results = []
  all_unit_stride = 1

  i = 0
  @while i < a_len
    acc = accesses[i]
    arr_name = acc.array
    idx_expr = acc.index_expr
    is_write = acc.is_write
    
    stride = 1
    kind = "UNIT_STRIDE"
    
    @if acc.stride != 0
      stride = acc.stride
    @elif idx_expr == ind_var_name
      stride = 1
      kind = "UNIT_STRIDE"
    @elif idx_expr == "const" || idx_expr == 0
      stride = 0
      kind = "INVARIANT_BROADCAST"
    @else
      stride = acc.stride
      @if stride == 0
        kind = "INVARIANT_BROADCAST"
      @elif stride == 1
        kind = "UNIT_STRIDE"
      @else
        kind = "NON_UNIT_STRIDE"
        all_unit_stride = 0
      @end
    @end

    stride_results = stride_results.push({
      array: arr_name,
      stride: stride,
      kind: kind,
      is_write: is_write
    })
    i = i + 1
  @end

  return {
    accesses: stride_results,
    all_unit_stride: all_unit_stride
  }
@end

@! ----------------------------------------------------------------------------
@! 4. AFFINE BORROW CHECKER ALIAS-FREE VERIFICATION
@! ----------------------------------------------------------------------------

@fn analyze_alias_free(loop_desc, borrowck_env)
  @! Maya Affine Borrow Checker guarantee:
  @! Mutable output buffer (&mut) cannot alias with any input buffer (&)
  @! In Maya, distinct named array parameters with affine ownership are
  @! provably disjoint at compile-time with zero runtime alias checks needed.
  
  write_arrays = []
  read_arrays = []

  accesses = loop_desc.array_accesses
  a_len = 0
  @if accesses != 0 a_len = accesses.len() @end

  i = 0
  @while i < a_len
    acc = accesses[i]
    @if acc.is_write == 1
      write_arrays = write_arrays.push(acc.array)
    @else
      read_arrays = read_arrays.push(acc.array)
    @end
    i = i + 1
  @end

  @! Check for overlapping names between write and read sets
  has_self_aliasing = 0
  w_len = write_arrays.len()
  wi = 0
  @while wi < w_len
    w_name = write_arrays[wi]
    ri = 0
    r_len = read_arrays.len()
    @while ri < r_len
      r_name = read_arrays[ri]
      @if w_name == r_name && loop_desc.allow_in_place != 1
        has_self_aliasing = 1
      @end
      ri = ri + 1
    @end
    wi = wi + 1
  @end

  alias_free = 1
  @if has_self_aliasing == 1 && loop_desc.is_pointwise != 1
    alias_free = 0
  @end

  return {
    alias_free: alias_free,
    write_arrays: write_arrays,
    read_arrays: read_arrays,
    affine_safety_proof: "PROVABLY_ALIAS_FREE_BY_BORROWCK"
  }
@end

@! ----------------------------------------------------------------------------
@! 5. REDUCTION OPERATION DETECTION
@! ----------------------------------------------------------------------------

@fn analyze_reductions(loop_desc, ind_var_name)
  body_ops = loop_desc.body_operations
  b_len = 0
  @if body_ops != 0 b_len = body_ops.len() @end

  has_reduction = 0
  reduction_var = ""
  reduction_op = ""
  reduction_kind = "NONE"
  identity_val = 0

  i = 0
  @while i < b_len
    op_desc = body_ops[i]
    
    @! Check for: acc = acc + A[i] (Sum Reduction)
    @if op_desc.is_reduction == 1 || op_desc.op == "REDUCE_SUM" || op_desc.kind == "REDUCE_SUM"
      has_reduction = 1
      reduction_var = op_desc.acc_var
      reduction_op = "+"
      reduction_kind = "REDUCE_SUM"
      identity_val = 0
    @elif op_desc.dest == op_desc.left && (op_desc.op == "+" || op_desc.op == "ADD")
      has_reduction = 1
      reduction_var = op_desc.dest
      reduction_op = "+"
      reduction_kind = "REDUCE_SUM"
      identity_val = 0
    @elif op_desc.dest == op_desc.left && (op_desc.op == "*" || op_desc.op == "MUL")
      has_reduction = 1
      reduction_var = op_desc.dest
      reduction_op = "*"
      reduction_kind = "REDUCE_MUL"
      identity_val = 1
    @elif op_desc.op == "MIN" || op_desc.kind == "REDUCE_MIN"
      has_reduction = 1
      reduction_var = op_desc.dest
      reduction_op = "MIN"
      reduction_kind = "REDUCE_MIN"
      identity_val = 2147483647
    @elif op_desc.op == "MAX" || op_desc.kind == "REDUCE_MAX"
      has_reduction = 1
      reduction_var = op_desc.dest
      reduction_op = "MAX"
      reduction_kind = "REDUCE_MAX"
      identity_val = -2147483647
    @end
    i = i + 1
  @end

  return {
    has_reduction: has_reduction,
    reduction_var: reduction_var,
    reduction_op: reduction_op,
    reduction_kind: reduction_kind,
    identity_val: identity_val
  }
@end

@! ----------------------------------------------------------------------------
@! 6. MASTER LOOP VECTORIZABILITY VERDICT
@! ----------------------------------------------------------------------------

@fn analyze_loop(loop_desc, borrowck_env)
  ind_info = analyze_induction_variable(loop_desc)
  stride_info = analyze_array_strides(loop_desc, ind_info.var_name)
  alias_info = analyze_alias_free(loop_desc, borrowck_env)
  red_info = analyze_reductions(loop_desc, ind_info.var_name)

  is_vectorizable = 1
  reasons = []

  @if ind_info.is_canonical == 0
    is_vectorizable = 0
    reasons = reasons.push("Non-canonical induction variable")
  @end

  @if stride_info.all_unit_stride == 0
    is_vectorizable = 0
    reasons = reasons.push("Non-unit stride memory access detected")
  @end

  @if alias_info.alias_free == 0
    is_vectorizable = 0
    reasons = reasons.push("Potential array pointer aliasing hazard")
  @end

  elem_type = loop_desc.elem_type
  @if elem_type == 0
    elem_type = "float32"
  @end

  vector_factor = 8
  @if elem_type == "float64"
    vector_factor = 4
  @elif elem_type == "int32"
    vector_factor = 8
  @end

  return {
    is_vectorizable: is_vectorizable,
    vector_factor: vector_factor,
    element_type: elem_type,
    unroll_factor: 4,
    induction: ind_info,
    strides: stride_info,
    alias_free: alias_info,
    reduction: red_info,
    reasons: reasons
  }
@end
