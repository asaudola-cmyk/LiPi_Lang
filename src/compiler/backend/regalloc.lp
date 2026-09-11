@! ============================================================================
@! MAYA COMPILER BACKEND — LINEAR SCAN REGISTER ALLOCATOR
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Target Architecture: Linux x86-64 (System V AMD64 ABI)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/maya_ir"

@! ============================================================================
@! 1. REGISTER ALLOCATOR DATA STRUCTURES
@! ============================================================================

@struct LiveInterval
  vreg_name: string      @! e.g. "%v0", "%v1", "%param_a", "loc_x"
  vreg_id: i64           @! Numeric ID (-1 for named variables)
  start_pos: i64         @! Monotonic linear instruction index start
  end_pos: i64           @! Monotonic linear instruction index end
  assigned_reg: i64      @! Physical register ID (0..15), or -1 if spilled
  spill_slot: i64        @! RBP offset (e.g. -8, -16), or 0 if in register
  is_spilled: i64        @! 1 if spilled to stack, 0 if allocated in register
  spans_call: i64        @! 1 if interval spans across a CALL instruction
  use_positions: array   @! Array of integer instruction positions
  is_param: i64          @! 1 if function parameter, 0 otherwise
@end

@struct RegAllocLocation
  loc_kind: i64          @! 0 for register, 1 for stack spill
  name: string           @! Name of virtual register or variable
  loc_type: string       @! "reg" or "stack"
  reg_id: i64            @! Physical register ID (0..15), or -1 if spilled
  reg_num: i64           @! Physical register ID (alias for reg_id)
  reg_name: string       @! "rax", "rcx", "rdx", "rbx", "rsi", "rdi", "r8", etc.
  rbp_offset: i64        @! RBP displacement (-8, -16, etc.) or 0
@end

@struct FunctionRegAllocResult
  fn_name: string
  intervals: array       @! Array of LiveInterval
  allocated_locations: array @! Array of RegAllocLocation
  locations: array       @! Alias for allocated_locations
  used_callee_saved: array @! Array of physical register IDs (3, 12, 13, 14, 15)
  spill_count: i64
  spill_slots_count: i64
  stack_frame_size: i64
@end

@struct ModuleRegAllocResult
  function_results: array @! Array of FunctionRegAllocResult
@end

@! ============================================================================
@! 2. HARDWARE REGISTER UTILITIES & SYSTEM V AMD64 ABI CLASSIFICATION
@! ============================================================================

@fn regalloc_is_callee_saved(reg_id: i64) -> i64
  @if reg_id == 3 || reg_id == 12 || reg_id == 13 || reg_id == 14 || reg_id == 15
    return 1
  @end
  return 0
@end

@fn regalloc_is_caller_saved(reg_id: i64) -> i64
  @if reg_id == 0 || reg_id == 1 || reg_id == 2 || reg_id == 6 || reg_id == 7 || reg_id == 8 || reg_id == 9 || reg_id == 10 || reg_id == 11
    return 1
  @end
  return 0
@end

@fn regalloc_is_reserved(reg_id: i64) -> i64
  @if reg_id == 4 || reg_id == 5
    return 1
  @end
  return 0
@end

@fn regalloc_reg_id_to_name(id: i64) -> string
  @if id == 0  return "rax" @end
  @if id == 1  return "rcx" @end
  @if id == 2  return "rdx" @end
  @if id == 3  return "rbx" @end
  @if id == 4  return "rsp" @end
  @if id == 5  return "rbp" @end
  @if id == 6  return "rsi" @end
  @if id == 7  return "rdi" @end
  @if id == 8  return "r8"  @end
  @if id == 9  return "r9"  @end
  @if id == 10 return "r10" @end
  @if id == 11 return "r11" @end
  @if id == 12 return "r12" @end
  @if id == 13 return "r13" @end
  @if id == 14 return "r14" @end
  @if id == 15 return "r15" @end
  return "unknown"
@end

@fn regalloc_phys_reg_name(id: i64) -> string
  return regalloc_reg_id_to_name(id)
@end

@fn regalloc_reg_name_to_id(name: string) -> i64
  n = name
  @if n == "rax" || n == "eax" || n == "ax" || n == "al" return 0  @end
  @if n == "rcx" || n == "ecx" || n == "cx" || n == "cl" return 1  @end
  @if n == "rdx" || n == "edx" || n == "dx" || n == "dl" return 2  @end
  @if n == "rbx" || n == "ebx" || n == "bx" || n == "bl" return 3  @end
  @if n == "rsp" || n == "esp" || n == "sp" || n == "spl" return 4  @end
  @if n == "rbp" || n == "ebp" || n == "bp" || n == "bpl" return 5  @end
  @if n == "rsi" || n == "esi" || n == "si" || n == "sil" return 6  @end
  @if n == "rdi" || n == "edi" || n == "di" || n == "dil" return 7  @end
  @if n == "r8"  || n == "r8d" || n == "r8w" || n == "r8b" return 8  @end
  @if n == "r9"  || n == "r9d" || n == "r9w" || n == "r9b" return 9  @end
  @if n == "r10" || n == "r10d" || n == "r10w" || n == "r10b" return 10 @end
  @if n == "r11" || n == "r11d" || n == "r11w" || n == "r11b" return 11 @end
  @if n == "r12" || n == "r12d" || n == "r12w" || n == "r12b" return 12 @end
  @if n == "r13" || n == "r13d" || n == "r13w" || n == "r13b" return 13 @end
  @if n == "r14" || n == "r14d" || n == "r14w" || n == "r14b" return 14 @end
  @if n == "r15" || n == "r15d" || n == "r15w" || n == "r15b" return 15 @end
  return -1
@end

@fn regalloc_strip_percent(s: string) -> string
  @if s != 0 && s.len() > 0 && s[0] == 37
    return str_substr(s, 1, s.len())
  @end
  return s
@end

@fn regalloc_name_match(query: string, candidate: string) -> i64
  @if query == candidate return 1 @end
  q_nopct = regalloc_strip_percent(query)
  c_nopct = regalloc_strip_percent(candidate)
  @if q_nopct == c_nopct return 1 @end
  @if q_nopct == (string_concat("param_", c_nopct)) || c_nopct == (string_concat("param_", q_nopct)) return 1 @end
  return 0
@end

@! ============================================================================
@! 3. LIVE INTERVAL ANALYSIS
@! ============================================================================

@fn regalloc_record_def(intervals: array, name: string, pos: i64, is_param: i64) -> array
  @if name == "" || name == 0 return intervals @end
  new_list = []
  found = 0
  i = 0
  num = intervals.len()
  @while i < num
    iv = intervals[i]
    @if iv.vreg_name == name
      new_start = iv.start_pos
      @if pos < new_start new_start = pos @end
      new_end = iv.end_pos
      @if pos > new_end new_end = pos @end
      p_flag = iv.is_param
      @if is_param == 1 p_flag = 1 @end
      new_list = new_list.push({
        vreg_name: name,
        vreg_id: iv.vreg_id,
        start_pos: new_start,
        end_pos: new_end,
        assigned_reg: -1,
        spill_slot: 0,
        is_spilled: 0,
        spans_call: 0,
        use_positions: iv.use_positions,
        is_param: p_flag
      })
      found = 1
    @else
      new_list = new_list.push(iv)
    @end
    i = i + 1
  @end

  @if found == 0
    new_list = new_list.push({
      vreg_name: name,
      vreg_id: -1,
      start_pos: pos,
      end_pos: pos,
      assigned_reg: -1,
      spill_slot: 0,
      is_spilled: 0,
      spans_call: 0,
      use_positions: [],
      is_param: is_param
    })
  @end
  return new_list
@end

@fn regalloc_record_use(intervals: array, name: string, pos: i64) -> array
  @if name == "" || name == 0 return intervals @end
  new_list = []
  found = 0
  i = 0
  num = intervals.len()
  @while i < num
    iv = intervals[i]
    @if iv.vreg_name == name
      new_end = iv.end_pos
      @if pos > new_end new_end = pos @end
      u_list = iv.use_positions.push(pos)
      new_list = new_list.push({
        vreg_name: name,
        vreg_id: iv.vreg_id,
        start_pos: iv.start_pos,
        end_pos: new_end,
        assigned_reg: -1,
        spill_slot: 0,
        is_spilled: 0,
        spans_call: 0,
        use_positions: u_list,
        is_param: iv.is_param
      })
      found = 1
    @else
      new_list = new_list.push(iv)
    @end
    i = i + 1
  @end

  @if found == 0
    new_list = new_list.push({
      vreg_name: name,
      vreg_id: -1,
      start_pos: pos,
      end_pos: pos,
      assigned_reg: -1,
      spill_slot: 0,
      is_spilled: 0,
      spans_call: 0,
      use_positions: [pos],
      is_param: 0
    })
  @end
  return new_list
@end

@fn regalloc_compute_intervals(func: IRFunction) -> array
  intervals_map = []
  call_positions = []
  current_pos = 0

  @! Pass 1: Handle function parameters (live from position 0)
  p_idx = 0
  num_params = 0
  @if func.params != 0 num_params = func.params.len() @end
  @while p_idx < num_params
    p = func.params[p_idx]
    p_name = ""
    p_reg = ""
    @if p != 0
      @if p.p_name != 0 && p.p_name != ""
        p_name = p.p_name
      @end
      @if p.reg != 0 && p.reg != ""
        p_reg = p.reg
      @end
    @end
    @if p_name == ""
      p_name = string_concat("arg", p_idx.to_str())
    @end
    @if p_reg == ""
      p_reg = string_concat("%param_", p_name)
    @end
    intervals_map = regalloc_record_def(intervals_map, p_reg, 0, 1)
    p_idx = p_idx + 1
  @end

  @! Pass 2: Linearize instructions and collect defs/uses
  b_idx = 0
  num_blocks = 0
  @if func.blocks != 0 num_blocks = func.blocks.len() @end
  @while b_idx < num_blocks
    blk = func.blocks[b_idx]
    inst_idx = 0
    num_insts = 0
    @if blk.instructions != 0 num_insts = blk.instructions.len() @end
    @while inst_idx < num_insts
      inst = blk.instructions[inst_idx]
      op = inst.inst_op
      @if op == "" || op == 0 op = inst.op @end
      dest = inst.dest

      @! Track CALL instruction positions
      @if op == "CALL" || op == "call"
        call_positions = call_positions.push(current_pos)
      @end

      @! Process instruction Definition
      @if dest != "" && dest != 0 && op != "STORE" && op != "store" && op != "BR" && op != "br" && op != "BR_COND" && op != "br_cond" && op != "RET" && op != "ret"
        intervals_map = regalloc_record_def(intervals_map, dest, current_pos, 0)
      @end

      @! Process instruction Uses
      @if inst.left != 0 && (inst.left.val_kind == "reg" || inst.left.val_kind == "param")
        intervals_map = regalloc_record_use(intervals_map, inst.left.name, current_pos + 1)
      @end
      @if inst.right != 0 && (inst.right.val_kind == "reg" || inst.right.val_kind == "param")
        intervals_map = regalloc_record_use(intervals_map, inst.right.name, current_pos + 1)
      @end
      @if inst.ptr != 0 && (inst.ptr.val_kind == "reg" || inst.ptr.val_kind == "param")
        intervals_map = regalloc_record_use(intervals_map, inst.ptr.name, current_pos + 1)
      @end
      @if inst.inst_val != 0 && (inst.inst_val.val_kind == "reg" || inst.inst_val.val_kind == "param")
        intervals_map = regalloc_record_use(intervals_map, inst.inst_val.name, current_pos + 1)
      @end
      @if inst.cond != 0 && (inst.cond.val_kind == "reg" || inst.cond.val_kind == "param")
        intervals_map = regalloc_record_use(intervals_map, inst.cond.name, current_pos + 1)
      @end

      @! Process Argument Array Uses (CALL / SYSCALL)
      @if inst.args != 0
        arg_i = 0
        num_args = inst.args.len()
        @while arg_i < num_args
          arg = inst.args[arg_i]
          @if arg != 0 && (arg.val_kind == "reg" || arg.val_kind == "param")
            intervals_map = regalloc_record_use(intervals_map, arg.name, current_pos + 1)
          @end
          arg_i = arg_i + 1
        @end
      @end

      @! Process PHI Incoming Uses
      @if inst.incoming != 0
        inc_i = 0
        num_inc = inst.incoming.len()
        @while inc_i < num_inc
          inc = inst.incoming[inc_i]
          @if inc != 0 && inc.phi_val != 0 && (inc.phi_val.val_kind == "reg" || inc.phi_val.val_kind == "param")
            intervals_map = regalloc_record_use(intervals_map, inc.phi_val.name, current_pos + 1)
          @end
          inc_i = inc_i + 1
        @end
      @end

      current_pos = current_pos + 2
      inst_idx = inst_idx + 1
    @end
    b_idx = b_idx + 1
  @end

  @! Pass 3: Annotate Call-Crossing intervals
  final_intervals = []
  iv_i = 0
  num_ivs = intervals_map.len()
  @while iv_i < num_ivs
    iv = intervals_map[iv_i]
    spans = 0
    cp_i = 0
    num_cp = call_positions.len()
    @while cp_i < num_cp
      cp = call_positions[cp_i]
      @if cp >= iv.start_pos && cp <= iv.end_pos
        spans = 1
      @end
      cp_i = cp_i + 1
    @end
    iv.spans_call = spans
    final_intervals = final_intervals.push(iv)
    iv_i = iv_i + 1
  @end

  return final_intervals
@end

@fn regalloc_compute_live_intervals(func: IRFunction) -> array
  return regalloc_compute_intervals(func)
@end

@fn regalloc_find_interval(intervals: array, name: string) -> LiveInterval
  i = 0
  num = intervals.len()
  @while i < num
    iv = intervals[i]
    @if regalloc_name_match(name, iv.vreg_name) == 1
      return iv
    @end
    i = i + 1
  @end

  return {
    vreg_name: name,
    vreg_id: -1,
    start_pos: 0,
    end_pos: 0,
    assigned_reg: -1,
    spill_slot: 0,
    is_spilled: 0,
    spans_call: 0,
    use_positions: [],
    is_param: 0
  }
@end

@! ============================================================================
@! 4. LINEAR SCAN ALLOCATION ALGORITHM
@! ============================================================================

@fn regalloc_sort_intervals_by_start(intervals: array) -> array
  sorted = []
  i = 0
  num = intervals.len()
  @while i < num
    item = intervals[i]
    inserted = 0
    new_sorted = []
    j = 0
    s_num = sorted.len()
    @while j < s_num
      s = sorted[j]
      @if inserted == 0 && (item.start_pos < s.start_pos || (item.start_pos == s.start_pos && item.end_pos < s.end_pos))
        new_sorted = new_sorted.push(item)
        inserted = 1
      @end
      new_sorted = new_sorted.push(s)
      j = j + 1
    @end
    @if inserted == 0
      new_sorted = new_sorted.push(item)
    @end
    sorted = new_sorted
    i = i + 1
  @end
  return sorted
@end

@fn regalloc_allocate_function(func: IRFunction) -> FunctionRegAllocResult
  raw_intervals = regalloc_compute_intervals(func)
  unhandled = regalloc_sort_intervals_by_start(raw_intervals)

  @! Register pools (System V AMD64 ABI)
  @! Caller-saved pool: RDI(7), RSI(6), RDX(2), RCX(1), R8(8), R9(9), R10(10)
  free_caller = [7, 6, 2, 1, 8, 9, 10]
  @! Callee-saved pool: RBX(3), R12(12), R13(13), R14(14), R15(15)
  free_callee = [3, 12, 13, 14, 15]

  active = []
  allocated_intervals = []
  used_callee_saved = []
  spill_offset = -8
  spill_count = 0

  cur_idx = 0
  num_unhandled = unhandled.len()
  @while cur_idx < num_unhandled
    cur = unhandled[cur_idx]

    @! 1. Expire old intervals
    new_active = []
    a_i = 0
    num_active = active.len()
    @while a_i < num_active
      a = active[a_i]
      @if a.end_pos < cur.start_pos
        @! Return register to pool
        @if regalloc_is_callee_saved(a.assigned_reg) == 1
          free_callee = free_callee.push(a.assigned_reg)
        @else
          free_caller = free_caller.push(a.assigned_reg)
        @end
      @else
        new_active = new_active.push(a)
      @end
      a_i = a_i + 1
    @end
    active = new_active

    @! 2. Allocate or Spill
    allocated = 0
    assigned_r = -1

    @if cur.spans_call == 1
      @! Prefer Callee-Saved for call-crossing intervals
      @if free_callee.len() > 0
        last_callee_idx = free_callee.len() - 1
        assigned_r = free_callee[last_callee_idx]
        new_free_callee = []
        k = 0
        @while k < last_callee_idx
          new_free_callee = new_free_callee.push(free_callee[k])
          k = k + 1
        @end
        free_callee = new_free_callee
        allocated = 1

        already_used = 0
_i_u_0 = 0
@while _i_u_0 < used_callee_saved.len()
  u = used_callee_saved[_i_u_0]
          @if u == assigned_r already_used = 1 @end
  _i_u_0 = _i_u_0 + 1
@end
        @if already_used == 0
          used_callee_saved = used_callee_saved.push(assigned_r)
        @end
      @elif free_caller.len() > 0
        last_caller_idx = free_caller.len() - 1
        assigned_r = free_caller[last_caller_idx]
        new_free_caller = []
        k = 0
        @while k < last_caller_idx
          new_free_caller = new_free_caller.push(free_caller[k])
          k = k + 1
        @end
        free_caller = new_free_caller
        allocated = 1
      @end
    @else
      @! Leaf / non-call: Prefer Caller-Saved
      @if free_caller.len() > 0
        last_caller_idx = free_caller.len() - 1
        assigned_r = free_caller[last_caller_idx]
        new_free_caller = []
        k = 0
        @while k < last_caller_idx
          new_free_caller = new_free_caller.push(free_caller[k])
          k = k + 1
        @end
        free_caller = new_free_caller
        allocated = 1
      @elif free_callee.len() > 0
        last_callee_idx = free_callee.len() - 1
        assigned_r = free_callee[last_callee_idx]
        new_free_callee = []
        k = 0
        @while k < last_callee_idx
          new_free_callee = new_free_callee.push(free_callee[k])
          k = k + 1
        @end
        free_callee = new_free_callee
        allocated = 1

        already_used = 0
_i_u_0 = 0
@while _i_u_0 < used_callee_saved.len()
  u = used_callee_saved[_i_u_0]
          @if u == assigned_r already_used = 1 @end
  _i_u_0 = _i_u_0 + 1
@end
        @if already_used == 0
          used_callee_saved = used_callee_saved.push(assigned_r)
        @end
      @end
    @end

    @if allocated == 1
      cur.assigned_reg = assigned_r
      cur.is_spilled = 0
      cur.spill_slot = 0

      @! Insert cur into active sorted by end_pos
      inserted = 0
      new_act = []
      act_i = 0
      @while act_i < active.len()
        act = active[act_i]
        @if inserted == 0 && cur.end_pos < act.end_pos
          new_act = new_act.push(cur)
          inserted = 1
        @end
        new_act = new_act.push(act)
        act_i = act_i + 1
      @end
      @if inserted == 0 new_act = new_act.push(cur) @end
      active = new_act
      allocated_intervals = allocated_intervals.push(cur)
    @else
      @! Spill handling (furthest end point evicts)
      spill_cand_idx = -1
      @if active.len() > 0
        spill_cand_idx = active.len() - 1
      @end

      @if spill_cand_idx >= 0 && active[spill_cand_idx].end_pos > cur.end_pos
        spill_cand = active[spill_cand_idx]
        spill_cand.is_spilled = 1
        spill_cand.spill_slot = spill_offset
        spill_offset = spill_offset - 8
        spill_count = spill_count + 1

        cur.assigned_reg = spill_cand.assigned_reg
        cur.is_spilled = 0
        cur.spill_slot = 0

        @! Replace spill_cand in active with cur
        new_act = []
        act_i = 0
        @while act_i < active.len()
          act = active[act_i]
          @if act.vreg_name != spill_cand.vreg_name
            new_act = new_act.push(act)
          @end
          act_i = act_i + 1
        @end

        @! Re-insert cur sorted by end_pos
        ins = 0
        final_act = []
        act_i = 0
        @while act_i < new_act.len()
          act = new_act[act_i]
          @if ins == 0 && cur.end_pos < act.end_pos
            final_act = final_act.push(cur)
            ins = 1
          @end
          final_act = final_act.push(act)
          act_i = act_i + 1
        @end
        @if ins == 0 final_act = final_act.push(cur) @end
        active = final_act

        @! Update spill_cand in allocated_intervals
        updated_alloc = []
        al_i = 0
        @while al_i < allocated_intervals.len()
          al = allocated_intervals[al_i]
          @if al.vreg_name == spill_cand.vreg_name
            updated_alloc = updated_alloc.push(spill_cand)
          @else
            updated_alloc = updated_alloc.push(al)
          @end
          al_i = al_i + 1
        @end
        allocated_intervals = updated_alloc
        allocated_intervals = allocated_intervals.push(cur)
      @else
        @! Spill cur
        cur.is_spilled = 1
        cur.assigned_reg = -1
        cur.spill_slot = spill_offset
        spill_offset = spill_offset - 8
        spill_count = spill_count + 1
        allocated_intervals = allocated_intervals.push(cur)
      @end
    @end

    cur_idx = cur_idx + 1
  @end

  @! Build Location Map
  locations = []
  loc_i = 0
  num_alloc = allocated_intervals.len()
  @while loc_i < num_alloc
    iv = allocated_intervals[loc_i]
    @if iv.is_spilled == 1
      locations = locations.push({
        loc_kind: 1,
        name: iv.vreg_name,
        loc_type: "stack",
        reg_id: -1,
        reg_num: -1,
        reg_name: "none",
        rbp_offset: iv.spill_slot
      })
    @else
      locations = locations.push({
        loc_kind: 0,
        name: iv.vreg_name,
        loc_type: "reg",
        reg_id: iv.assigned_reg,
        reg_num: iv.assigned_reg,
        reg_name: regalloc_reg_id_to_name(iv.assigned_reg),
        rbp_offset: 0
      })
    @end
    loc_i = loc_i + 1
  @end

  @! Calculate 16-byte aligned stack frame size (System V AMD64 ABI)
  num_locals = 0
  @if func.locals != 0 num_locals = func.locals.len() @end
  raw_bytes = spill_count * 8 + num_locals * 8 + used_callee_saved.len() * 8
  rem = raw_bytes % 16
  frame_sz = raw_bytes
  @if rem != 0 frame_sz = frame_sz + (16 - rem) @end

  fn_n = "anonymous"
  @if func.name != 0 && func.name != "" fn_n = func.name @end

  return {
    fn_name: fn_n,
    intervals: allocated_intervals,
    allocated_locations: locations,
    locations: locations,
    used_callee_saved: used_callee_saved,
    spill_count: spill_count,
    spill_slots_count: spill_count,
    stack_frame_size: frame_sz
  }
@end

@! ============================================================================
@! 5. MODULE-LEVEL ENTRY POINT & LOCATION LOOKUP
@! ============================================================================

@fn regalloc_run(module: IRModule) -> array
  results = []
  f_idx = 0
  num_funcs = 0
  @if module != 0 && module.functions != 0 num_funcs = module.functions.len() @end
  @while f_idx < num_funcs
    fn_item = module.functions[f_idx]
    f_res = regalloc_allocate_function(fn_item)
    results = results.push(f_res)
    f_idx = f_idx + 1
  @end
  return results
@end

@fn regalloc_get_location(res: FunctionRegAllocResult, name: string) -> RegAllocLocation
  return loc_get(res.allocated_locations, name)
@end

@fn loc_get(locations: array, vreg_name: string) -> RegAllocLocation
  i = 0
  num_locs = 0
  @if locations != 0 num_locs = locations.len() @end
  @while i < num_locs
    loc = locations[i]
    @if regalloc_name_match(vreg_name, loc.name) == 1
      return loc
    @end
    i = i + 1
  @end

  @! Default fallback: spilled at 0
  return {
    loc_kind: 1,
    name: vreg_name,
    loc_type: "stack",
    reg_id: -1,
    reg_num: -1,
    reg_name: "none",
    rbp_offset: 0
  }
@end

@fn regalloc_result_to_string(res)
  out = string_concat(string_concat("RegAlloc Result for @", res.fn_name), ":
")
  out = string_concat(string_concat(out, string_concat("  Spill Slots: ", int_to_str(res.spill_slots_count))), "
")
  out = string_concat(string_concat(out, string_concat("  Stack Frame Size: ", int_to_str(res.stack_frame_size))), " bytes
")
  out = string_concat(string_concat(out, string_concat("  Used Callee-Saved: ", int_to_str(res.used_callee_saved.len()))), "
")
  out = string_concat(out, "  Allocations:
")
  i = 0
  @while i < res.locations.len()
    loc = res.locations[i]
    @if loc.loc_kind == 0
      out = string_concat(string_concat(string_concat(string_concat(out, string_concat("    ", loc.name)), string_concat(" -> %", loc.reg_name)), string_concat(" (reg ", int_to_str(loc.reg_id))), ")
")
    @else
      out = string_concat(string_concat(string_concat(string_concat(out, string_concat("    ", loc.name)), " -> stack ["), int_to_str(loc.rbp_offset)), "(%rbp)]
")
    @end
    i = i + 1
  @end
  return out
@end
