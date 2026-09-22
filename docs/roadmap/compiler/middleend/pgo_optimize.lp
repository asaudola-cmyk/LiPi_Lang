@! ============================================================================
@! MAYA COMPILER MIDDLEEND — PGO OPTIMIZATION PASSES (pgo_optimize.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: Pettis-Hansen CFG Trace Layout, Hot/Cold Splitting, Branch
@!           Probability Hinting & Fallthrough Inversion, Hot Function Inlining,
@!           Trip-Count Hot Loop Full/Partial Unrolling
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. BRANCH PROBABILITY ESTIMATION & CONDITION INVERSION
@! ----------------------------------------------------------------------------

@fn pgo_invert_op(op)
  @if op == "==" return "!=" @end
  @if op == "!=" return "==" @end
  @if op == "<" return ">=" @end
  @if op == "<=" return ">" @end
  @if op == ">" return "<=" @end
  @if op == ">=" return "<" @end
  return op
@end

@fn pgo_pass_branch_probabilities(fn_obj, fn_profile)
  @if fn_profile == 0 || fn_obj.blocks == 0
    return fn_obj
  @end

  b_list = fn_obj.blocks
  b_len = b_list.len()
  new_blocks = []

  i = 0
  @while i < b_len
    b = b_list[i]
    
    @! Check if conditional branch (2 successors)
    @if b.succs != 0 && b.succs.len() == 2
      then_id = b.succs[0]
      else_id = b.succs[1]
      
      c_then = 0
      c_else = 0
      
      @! Look up edge counts in profile
      edges = fn_profile.edges
      e_len = 0
      @if edges != 0 e_len = edges.len() @end
      
      ei = 0
      @while ei < e_len
        e = edges[ei]
        @if e.src == b.id && e.dst == then_id
          c_then = e.count
        @elif e.src == b.id && e.dst == else_id
          c_else = e.count
        @end
        ei = ei + 1
      @end

      c_total = c_then + c_else
      prob_then = 50
      prob_else = 50
      @if c_total > 0
        prob_then = (c_then * 100) / c_total
        prob_else = 100 - prob_then
      @end

      b.branch_prob = {
        then_dest: then_id,
        else_dest: else_id,
        prob_then: prob_then,
        prob_else: prob_else,
        inverted: 0
      }

      @! If else path is substantially hotter than then path (> 60% probability)
      @! Invert condition to make the hot path the direct fallthrough
      @if prob_else > 60
        b.branch_prob.inverted = 1
        b.succs = [else_id, then_id]
        
        @! Invert last branch instruction condition if present
        inst_len = 0
        @if b.instructions != 0 inst_len = b.instructions.len() @end
        @if inst_len > 0
          last_inst = b.instructions[inst_len - 1]
          @if last_inst.cond != 0 && last_inst.cond.op != 0
            last_inst.cond.op = pgo_invert_op(last_inst.cond.op)
            last_inst.inverted_by_pgo = 1
          @end
        @end
      @end
    @end

    new_blocks = new_blocks.push(b)
    i = i + 1
  @end

  fn_obj.blocks = new_blocks
  return fn_obj
@end

@! ----------------------------------------------------------------------------
@! 2. PETTIS-HANSEN HOT BASIC BLOCK LAYOUT & HOT/COLD SPLITTING
@! ----------------------------------------------------------------------------

@fn pgo_pass_pettis_hansen_layout(fn_obj, fn_profile)
  @if fn_profile == 0 || fn_obj.blocks == 0
    return fn_obj
  @end

  b_list = fn_obj.blocks
  b_len = b_list.len()
  @if b_len <= 1
    return fn_obj
  @end

  @! Step 1: Assign execution counts to blocks from profile
  block_map = []
  i = 0
  @while i < b_len
    b = b_list[i]
    b_count = 0
    @if fn_profile.block_counts != 0 && i < fn_profile.block_counts.len()
      b_count = fn_profile.block_counts[i]
    @end
    b.execution_count = b_count
    b.is_cold = 0
    @if b_count == 0
      b.is_cold = 1
    @end
    block_map = block_map.push(b)
    i = i + 1
  @end

  @! Step 2: Extract and sort edges by transition weight descending
  edges = []
  @if fn_profile.edges != 0
    edges = fn_profile.edges
  @end

  @! Step 3: Greedily chain blocks along heaviest edges into traces
  visited = []
  i = 0
  @while i < b_len
    visited = visited.push(0)
    i = i + 1
  @end

  traces = []
  
  @! Always start Trace 0 with entry block (Block 0)
  entry_trace = [block_map[0]]
  visited = list_set(visited, 0, 1)
  curr_b = block_map[0]

  trace_running = 1
  @while trace_running == 1
    @! Find highest weight outgoing edge from curr_b to unvisited block
    best_dst = -1
    best_weight = -1
    
    ei = 0
    e_len = edges.len()
    @while ei < e_len
      e = edges[ei]
      @if e.src == curr_b.id && e.dst < b_len
        @if visited[e.dst] == 0 && e.count > best_weight
          best_weight = e.count
          best_dst = e.dst
        @end
      @end
      ei = ei + 1
    @end

    @if best_dst != -1 && best_weight > 0
      entry_trace = entry_trace.push(block_map[best_dst])
      visited = list_set(visited, best_dst, 1)
      curr_b = block_map[best_dst]
    @else
      trace_running = 0
    @end
  @end
  traces = traces.push(entry_trace)

  @! Form remaining hot traces
  i = 1
  @while i < b_len
    @if visited[i] == 0 && block_map[i].is_cold == 0
      hot_trace = [block_map[i]]
      visited = list_set(visited, i, 1)
      curr_b = block_map[i]
      
      sub_running = 1
      @while sub_running == 1
        best_dst = -1
        best_weight = -1
        ei = 0
        e_len = edges.len()
        @while ei < e_len
          e = edges[ei]
          @if e.src == curr_b.id && e.dst < b_len
            @if visited[e.dst] == 0 && e.count > best_weight
              best_weight = e.count
              best_dst = e.dst
            @end
          @end
          ei = ei + 1
        @end
        @if best_dst != -1 && best_weight > 0
          hot_trace = hot_trace.push(block_map[best_dst])
          visited = list_set(visited, best_dst, 1)
          curr_b = block_map[best_dst]
        @else
          sub_running = 0
        @end
      @end
      traces = traces.push(hot_trace)
    @end
    i = i + 1
  @end

  @! Cold blocks trace (Hot/Cold Splitting)
  cold_trace = []
  i = 0
  @while i < b_len
    @if visited[i] == 0
      block_map[i].is_cold = 1
      cold_trace = cold_trace.push(block_map[i])
      visited = list_set(visited, i, 1)
    @end
    i = i + 1
  @end

  @! Flatten all hot traces then append cold trace
  reordered_blocks = []
  ti = 0
  t_len = traces.len()
  @while ti < t_len
    tr = traces[ti]
    tj = 0
    tr_len = tr.len()
    @while tj < tr_len
      reordered_blocks = reordered_blocks.push(tr[tj])
      tj = tj + 1
    @end
    ti = ti + 1
  @end

  @! Append cold partition
  ci = 0
  c_len = cold_trace.len()
  @while ci < c_len
    reordered_blocks = reordered_blocks.push(cold_trace[ci])
    ci = ci + 1
  @end

  fn_obj.blocks = reordered_blocks
  fn_obj.pgo_layout_optimized = 1
  fn_obj.cold_block_count = c_len
  return fn_obj
@end

@! ----------------------------------------------------------------------------
@! 3. PROFILE-INFORMED HOT FUNCTION INLINING
@! ----------------------------------------------------------------------------

@fn pgo_pass_hot_inlining(fn_obj, fn_profile)
  @if fn_profile == 0 || fn_obj.blocks == 0
    return fn_obj
  @end

  total_invocations = fn_profile.invocations
  @if total_invocations <= 0
    total_invocations = 1
  @end

  inline_candidates = []
  b_list = fn_obj.blocks
  b_len = b_list.len()

  i = 0
  @while i < b_len
    b = b_list[i]
    inst_list = b.instructions
    inst_len = 0
    @if inst_list != 0 inst_len = inst_list.len() @end
    
    j = 0
    @while j < inst_len
      inst = inst_list[j]
      is_call = inst.op == "Call" || inst.type == "Call" || inst.kind == "Call" || inst.op == "PGO_INC_CALL"
      @if is_call
        callee_name = inst.callee
        @if callee_name == 0 callee_name = inst.target @end
        
        call_count = 0
        @if fn_profile.call_sites != 0
          cs_list = fn_profile.call_sites
          cs_len = cs_list.len()
          csi = 0
          @while csi < cs_len
            cs = cs_list[csi]
            @if cs.target == callee_name || (inst.site_id != 0 && cs.site_id == inst.site_id)
              call_count = cs.count
            @end
            csi = csi + 1
          @end
        @end

        call_pct = (call_count * 100) / total_invocations
        
        @! Rule: If call site > 5% of total invocations -> Hot inlining boost
        @! If call site == 0 -> Cold call site, forbid inlining
        hotness = "WARM"
        inline_budget_multiplier = 1
        inline_forbidden = 0

        @if call_pct >= 5
          hotness = "HOT"
          inline_budget_multiplier = 4
        @elif call_pct == 0
          hotness = "COLD"
          inline_forbidden = 1
        @end

        candidate = {
          callee: callee_name,
          call_count: call_count,
          call_pct: call_pct,
          hotness: hotness,
          inline_budget_multiplier: inline_budget_multiplier,
          inline_forbidden: inline_forbidden
        }
        inline_candidates = inline_candidates.push(candidate)
      @end
      j = j + 1
    @end
    i = i + 1
  @end

  fn_obj.pgo_inline_candidates = inline_candidates
  return fn_obj
@end

@! ----------------------------------------------------------------------------
@! 4. TRIP-COUNT HOT LOOP UNROLLING
@! ----------------------------------------------------------------------------

@fn pgo_pass_hot_loop_unrolling(fn_obj, fn_profile)
  @if fn_profile == 0 || fn_profile.loops == 0
    return fn_obj
  @end

  loop_plans = []
  loops = fn_profile.loops
  l_len = loops.len()

  li = 0
  @while li < l_len
    lp = loops[li]
    trip = lp.avg_trip_count
    plan = "NONE"
    unroll_factor = 1

    @! Small constant hot loop (trip count <= 8) -> Full unroll
    @if trip > 0 && trip <= 8
      plan = "FULL_UNROLL"
      unroll_factor = trip
    @elif trip > 8
      @! Large hot loop -> Unroll by 4
      plan = "PARTIAL_UNROLL"
      unroll_factor = 4
    @else
      @! Cold or zero-trip loop -> Preserve compact representation
      plan = "PRESERVE_COMPACT"
      unroll_factor = 1
    @end

    loop_plans = loop_plans.push({
      loop_id: lp.loop_id,
      header_block: lp.header_block,
      avg_trip_count: trip,
      plan: plan,
      unroll_factor: unroll_factor
    })
    li = li + 1
  @end

  fn_obj.pgo_loop_unroll_plans = loop_plans
  return fn_obj
@end

@! ----------------------------------------------------------------------------
@! 5. MASTER OPTIMIZATION PIPELINE
@! ----------------------------------------------------------------------------

@fn pgo_optimize_function(fn_obj, fn_profile)
  @if fn_profile == 0
    return fn_obj
  @end

  fn_obj = pgo_pass_branch_probabilities(fn_obj, fn_profile)
  fn_obj = pgo_pass_pettis_hansen_layout(fn_obj, fn_profile)
  fn_obj = pgo_pass_hot_inlining(fn_obj, fn_profile)
  fn_obj = pgo_pass_hot_loop_unrolling(fn_obj, fn_profile)
  fn_obj.pgo_optimized = 1
  return fn_obj
@end

@fn pgo_optimize_module(mod, profile)
  @if profile == 0
    return mod
  @end

  fn_list = mod.functions
  @if fn_list == 0 fn_list = mod.funcs @end
  @if fn_list == 0 return mod @end

  opt_funcs = []
  i = 0
  len = fn_list.len()
  @while i < len
    fn_obj = fn_list[i]
    fn_prof = 0
    @! Look up function in profile
    @if profile.functions != 0
      p_len = profile.functions.len()
      pi = 0
      @while pi < p_len
        pf = profile.functions[pi]
        @if pf.name == fn_obj.name
          fn_prof = pf
        @end
        pi = pi + 1
      @end
    @end

    opt_fn = pgo_optimize_function(fn_obj, fn_prof)
    opt_funcs = opt_funcs.push(opt_fn)
    i = i + 1
  @end

  mod.functions = opt_funcs
  mod.pgo_optimized = 1
  return mod
@end
