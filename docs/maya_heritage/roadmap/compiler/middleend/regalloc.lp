@! ============================================================================
@! MAYA COMPILER STAGE 3 — ADVANCED REGISTER ALLOCATOR (LINEAR SCAN)
@! 100% Written in Pure Maya Language — Zero External C/LLVM Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Hardware Register Model (System V AMD64 ABI)
@! ----------------------------------------------------------------------------

@fn reg_name(id)
  names = ["rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"]
  @if id >= 0 && id < names.len()
    return names[id]
  @end
  return "spill_slot_" + id.to_str()
@end

@fn init_allocatable_registers()
  @! Caller-saved and general scratch registers: RAX(0), RDI(7), RSI(6), RDX(2), RCX(1), R8(8), R9(9), R10(10), R11(11)
  return [0, 7, 6, 2, 1, 8, 9, 10, 11]
@end

@! ----------------------------------------------------------------------------
@! 2. Live Range Analysis
@! ----------------------------------------------------------------------------

@fn compute_live_intervals(mir_instructions)
  intervals = []
  inst_idx = 0
  
  @while inst_idx < mir_instructions.len()
    inst = mir_instructions[inst_idx]
    
    @! Check definition (dest)
    @if inst.dest != -1
      found = 0
      @for it in intervals
        @if it.vreg == inst.dest
          it.end_point = inst_idx
          found = 1
        @end
      @end
      @if found == 0
        intervals = intervals.push({
          vreg: inst.dest,
          start_point: inst_idx,
          end_point: inst_idx + 1,
          preg: -1,
          spill_offset: 0
        })
      @end
    @end
    
    @! Check uses (left / right / src)
    @if inst.left != -1
      @for it in intervals
        @if it.vreg == inst.left
          it.end_point = inst_idx
        @end
      @end
    @end
    
    @if inst.right != -1
      @for it in intervals
        @if it.vreg == inst.right
          it.end_point = inst_idx
        @end
      @end
    @end
    
    inst_idx = inst_idx + 1
  @end
  
  return intervals
@end

@! ----------------------------------------------------------------------------
@! 3. Linear Scan Register Allocation Algorithm (Poletto & Sarkar)
@! ----------------------------------------------------------------------------

@fn linear_scan_allocate(intervals)
  free_regs = init_allocatable_registers()
  active = []
  allocated = []
  next_spill_slot = 8
  
  i = 0
  @while i < intervals.len()
    current = intervals[i]
    
    @! Expire old intervals
    j = 0
    new_active = []
    @while j < active.len()
      act = active[j]
      @if act.end_point <= current.start_point
        @! Reclaim register
        @if act.preg != -1
          free_regs = free_regs.push(act.preg)
        @end
      @else
        new_active = new_active.push(act)
      @end
      j = j + 1
    @end
    active = new_active
    
    @! Assign register or spill
    @if free_regs.len() > 0
      assigned_reg = free_regs[free_regs.len() - 1]
      
      @! Pop from free_regs
      new_free = []
      k = 0
      @while k < free_regs.len() - 1
        new_free = new_free.push(free_regs[k])
        k = k + 1
      @end
      free_regs = new_free
      
      current.preg = assigned_reg
      active = active.push(current)
    @else
      @! Spill to stack frame: [rbp - next_spill_slot]
      current.preg = -1
      current.spill_offset = next_spill_slot
      next_spill_slot = next_spill_slot + 8
    @end
    
    allocated = allocated.push(current)
    i = i + 1
  @end
  
  return {
    allocated_intervals: allocated,
    stack_frame_size: next_spill_slot
  }
@end

@! ----------------------------------------------------------------------------
@! 4. Spill Code Generator
@! ----------------------------------------------------------------------------

@fn generate_spill_load(reg, spill_offset)
  return "  mov " + reg_name(reg) + ", [rbp - " + spill_offset.to_str() + "]"
@end

@fn generate_spill_store(reg, spill_offset)
  return "  mov [rbp - " + spill_offset.to_str() + "], " + reg_name(reg)
@end

@fn get_abi_arg_reg(arg_idx)
  @! System V AMD64 ABI Calling Convention: RDI, RSI, RDX, RCX, R8, R9
  abi_regs = [7, 6, 2, 1, 8, 9]
  @if arg_idx >= 0 && arg_idx < abi_regs.len()
    return abi_regs[arg_idx]
  @end
  return -1 @! Passed via stack
@end
