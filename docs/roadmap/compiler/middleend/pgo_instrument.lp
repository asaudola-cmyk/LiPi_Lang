@! ============================================================================
@! MAYA COMPILER MIDDLEEND — PGO INSTRUMENTATION PASS (pgo_instrument.maya)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: Basic Block Entry Probes, Edge/Branch Profiling, Loop Trip Count
@!           Counters, Indirect Call Site Probes, Counter Vector Allocation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. COUNTER ALLOCATION & INSTRUMENTATION DESCRIPTOR
@! ----------------------------------------------------------------------------

@fn pgo_instrumentation_desc_new(func_name)
  return {
    func_name: func_name,
    next_counter_idx: 0,
    block_counters: [],
    edge_counters: [],
    call_counters: [],
    loop_counters: [],
    total_counters: 0
  }
@end

@fn pgo_alloc_counter(desc, kind, entity_id)
  idx = desc.next_counter_idx
  desc.next_counter_idx = desc.next_counter_idx + 1
  desc.total_counters = desc.next_counter_idx
  return idx
@end

@! ----------------------------------------------------------------------------
@! 2. FUNCTION LEVEL INSTRUMENTATION PASS
@! ----------------------------------------------------------------------------

@fn pgo_instrument_function(fn_obj)
  desc = pgo_instrumentation_desc_new(fn_obj.name)
  
  new_blocks = []
  block_list = fn_obj.blocks
  b_len = 0
  @if block_list != 0
    b_len = block_list.len()
  @end

  @! Phase 1: Instrument Basic Blocks and Pre-allocate Block Counters
  i = 0
  @while i < b_len
    b = block_list[i]
    b_counter_idx = pgo_alloc_counter(desc, "block", b.id)
    
    desc.block_counters = desc.block_counters.push({
      block_id: b.id,
      counter_idx: b_counter_idx
    })

    @! Prepend block entry probe
    probe_inst = {
      op: "PGO_INC_BLOCK",
      kind: "PGO_PROBE",
      block_id: b.id,
      counter_idx: b_counter_idx,
      weight: 1
    }

    new_insts = [probe_inst]
    
    @! Scan existing instructions for calls and insert call-site probes
    inst_len = 0
    @if b.instructions != 0
      inst_len = b.instructions.len()
    @end

    j = 0
    @while j < inst_len
      inst = b.instructions[j]
      is_call = inst.op == "Call" || inst.type == "Call" || inst.kind == "Call" || inst.op == "CALL"
      
      @if is_call
        call_id = desc.call_counters.len()
        c_counter_idx = pgo_alloc_counter(desc, "call", call_id)
        
        callee_name = "unknown"
        @if inst.callee != 0
          @if inst.callee.name != 0
            callee_name = inst.callee.name
          @elif inst.callee.val != 0
            callee_name = inst.callee.val
          @end
        @elif inst.func != 0
          @if inst.func.name != 0
            callee_name = inst.func.name
          @end
        @elif inst.name != 0
          callee_name = inst.name
        @end

        desc.call_counters = desc.call_counters.push({
          site_id: call_id,
          callee: callee_name,
          counter_idx: c_counter_idx
        })

        call_probe = {
          op: "PGO_INC_CALL",
          kind: "PGO_PROBE",
          site_id: call_id,
          callee: callee_name,
          counter_idx: c_counter_idx
        }
        new_insts = new_insts.push(call_probe)
      @end

      new_insts = new_insts.push(inst)
      j = j + 1
    @end

    b.instructions = new_insts
    new_blocks = new_blocks.push(b)
    i = i + 1
  @end

  @! Phase 2: Instrument Control Flow Edges and Loop Back-Edges
  i = 0
  @while i < b_len
    b = new_blocks[i]
    succ_len = 0
    @if b.succs != 0
      succ_len = b.succs.len()
    @end

    @! If block has multiple successors (conditional branch) or is a loop header
    s_idx = 0
    @while s_idx < succ_len
      dst_id = b.succs[s_idx]
      edge_counter_idx = pgo_alloc_counter(desc, "edge", desc.edge_counters.len())
      
      is_back_edge = 0
      @if dst_id <= b.id
        is_back_edge = 1
      @end

      edge_kind = "branch"
      @if is_back_edge == 1
        edge_kind = "back_edge"
      @elif succ_len == 1
        edge_kind = "fallthrough"
      @end

      desc.edge_counters = desc.edge_counters.push({
        src: b.id,
        dst: dst_id,
        kind: edge_kind,
        counter_idx: edge_counter_idx
      })

      @! If back-edge, also register loop profiling probe
      @if is_back_edge == 1
        loop_id = desc.loop_counters.len()
        loop_entry_counter = pgo_alloc_counter(desc, "loop_entry", loop_id)
        loop_back_counter = edge_counter_idx
        
        desc.loop_counters = desc.loop_counters.push({
          loop_id: loop_id,
          header_block: dst_id,
          back_edge_block: b.id,
          entry_counter_idx: loop_entry_counter,
          back_counter_idx: loop_back_counter
        })

        b.instructions = b.instructions.push({
          op: "PGO_INC_LOOP_BACKEDGE",
          kind: "PGO_PROBE",
          loop_id: loop_id,
          counter_idx: loop_back_counter
        })
      @end

      s_idx = s_idx + 1
    @end

    i = i + 1
  @end

  fn_obj.blocks = new_blocks
  fn_obj.pgo_instrumented = 1
  fn_obj.pgo_desc = desc
  return fn_obj
@end

@! ----------------------------------------------------------------------------
@! 3. MODULE LEVEL INSTRUMENTATION PASS
@! ----------------------------------------------------------------------------

@fn pgo_instrument_module(mod)
  instrumented_funcs = []
  fn_list = mod.functions
  @if fn_list == 0
    fn_list = mod.funcs
  @end

  f_len = 0
  @if fn_list != 0
    f_len = fn_list.len()
  @end

  total_module_counters = 0
  metadata_entries = []

  i = 0
  @while i < f_len
    fn_obj = fn_list[i]
    inst_fn = pgo_instrument_function(fn_obj)
    instrumented_funcs = instrumented_funcs.push(inst_fn)

    metadata_entries = metadata_entries.push({
      func_name: inst_fn.name,
      counter_offset: total_module_counters,
      counter_count: inst_fn.pgo_desc.total_counters,
      desc: inst_fn.pgo_desc
    })

    total_module_counters = total_module_counters + inst_fn.pgo_desc.total_counters
    i = i + 1
  @end

  mod.functions = instrumented_funcs
  mod.pgo_metadata = {
    total_counters: total_module_counters,
    functions: metadata_entries
  }
  return mod
@end

@! ----------------------------------------------------------------------------
@! 4. HELPER QUERIES & INTROSPECTION
@! ----------------------------------------------------------------------------

@fn pgo_count_probes(fn_obj)
  count = 0
  b_list = fn_obj.blocks
  @if b_list == 0
    return 0
  @end

  i = 0
  b_len = b_list.len()
  @while i < b_len
    b = b_list[i]
    inst_list = b.instructions
    @if inst_list != 0
      j = 0
      j_len = inst_list.len()
      @while j < j_len
        inst = inst_list[j]
        @if inst.kind == "PGO_PROBE" || (inst.op != 0 && starts_with(inst.op, "PGO_INC"))
          count = count + 1
        @end
        j = j + 1
      @end
    @end
    i = i + 1
  @end
  return count
@end

@fn pgo_get_block_counter_index(fn_obj, block_id)
  @if fn_obj.pgo_desc == 0
    return -1
  @end
  bc_list = fn_obj.pgo_desc.block_counters
  i = 0
  len = bc_list.len()
  @while i < len
    entry = bc_list[i]
    @if entry.block_id == block_id
      return entry.counter_idx
    @end
    i = i + 1
  @end
  return -1
@end

@fn pgo_get_edge_counter_index(fn_obj, src_id, dst_id)
  @if fn_obj.pgo_desc == 0
    return -1
  @end
  ec_list = fn_obj.pgo_desc.edge_counters
  i = 0
  len = ec_list.len()
  @while i < len
    entry = ec_list[i]
    @if entry.src == src_id && entry.dst == dst_id
      return entry.counter_idx
    @end
    i = i + 1
  @end
  return -1
@end
