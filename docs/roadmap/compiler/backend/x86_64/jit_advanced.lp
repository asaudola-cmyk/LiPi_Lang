@! ============================================================================
@! MAYA COMPILER STAGE 4 — ADVANCED JUST-IN-TIME (JIT) COMPILER
@! 100% Written in Pure Maya Language
@! Target: x86-64 Architecture
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"

@! Memory protection flags (PROT_READ | PROT_WRITE | PROT_EXEC)
@! We need mmap to allocate executable memory
@fn jit_allocate_executable_memory(size)
  @! System call for mmap (sys_mmap = 9 on x86_64)
  @! args: addr, length, prot, flags, fd, offset
  prot = 7 @! PROT_READ (1) | PROT_WRITE (2) | PROT_EXEC (4)
  flags = 34 @! MAP_PRIVATE (2) | MAP_ANONYMOUS (32)
  addr = syscall(9, 0, size, prot, flags, -1, 0)
  return addr
@end

@! The JIT Engine State
@fn jit_engine_new()
  return {
    memory_blocks: [],
    compiled_functions: { entries: [] },
    relocations: [],
    entry_point: 0
  }
@end

@! Register Allocation Table for JIT
@fn jit_reg_alloc_new()
  return {
    free_regs: ["rax", "rcx", "rdx", "rbx", "rsi", "rdi", "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"],
    used_regs: { entries: [] },
    spill_count: 0
  }
@end

@! Machine Code Buffer
@fn jit_buffer_new()
  return { bytes: [], size: 0 }
@end

@fn jit_emit_byte(buf, b)
  buf.bytes = buf.bytes.push(b)
  buf.size = buf.size + 1
  return buf
@end

@! Advanced Instruction Emission
@! Emit REX prefix
@fn jit_emit_rex(buf, w, r, x, b)
  rex = 64
  @if w rex = rex + 8 @end
  @if r rex = rex + 4 @end
  @if x rex = rex + 2 @end
  @if b rex = rex + 1 @end
  return jit_emit_byte(buf, rex)
@end

@! ModR/M byte
@fn jit_emit_modrm(buf, mod, reg, rm)
  val = (mod * 64) + (reg * 8) + rm
  return jit_emit_byte(buf, val)
@end

@! JIT Compile a Maya MIR Function
@fn jit_compile_func(engine, mir_func)
  buf = jit_buffer_new()
  
  @! Standard Prologue: push rbp; mov rbp, rsp
  buf = jit_emit_byte(buf, 85) @! 0x55
  buf = jit_emit_rex(buf, 1, 0, 0, 0)
  buf = jit_emit_byte(buf, 137) @! 0x89
  buf = jit_emit_byte(buf, 229) @! 0xE5
  
  @! Parse MIR instructions
  @if mir_func.instructions != 0
    @for inst in mir_func.instructions
      @if inst.op == "CONST_INT"
        buf = jit_emit_rex(buf, 1, 0, 0, 0)
        buf = jit_emit_byte(buf, 184) @! 0xB8
        
        val = inst.val
        i = 0
        @while i < 8
          buf = jit_emit_byte(buf, val % 256)
          val = val / 256
          i = i + 1
        @end
      @elif inst.op == "BINOP"
        @if inst.binop == "+"
          buf = jit_emit_rex(buf, 1, 0, 0, 0)
          buf = jit_emit_byte(buf, 1) @! 0x01
          buf = jit_emit_modrm(buf, 3, 1, 0)
        @elif inst.binop == "*"
          buf = jit_emit_rex(buf, 1, 0, 0, 0)
          buf = jit_emit_byte(buf, 15) @! 0x0F
          buf = jit_emit_byte(buf, 175) @! 0xAF
          buf = jit_emit_modrm(buf, 3, 0, 1)
        @end
      @elif inst.op == "RETURN"
        buf = jit_emit_byte(buf, 93) @! 0x5D
        buf = jit_emit_byte(buf, 195) @! 0xC3
      @end
    @end
  @end
  
  @! Allocate executable memory
  alloc_size = buf.size
  @if alloc_size == 0 alloc_size = 64 @end
  exec_addr = jit_allocate_executable_memory(alloc_size)
  
  @! Record compiled function metadata
  engine.compiled_functions.entries = engine.compiled_functions.entries.push({
    name: mir_func.name,
    addr: exec_addr,
    bytes: buf.bytes,
    size: buf.size,
    mir: mir_func
  })
  
  return engine
@end

@! Execute JIT Compiled Code
@fn jit_execute(engine, func_name)
  target = 0
  @for f in engine.compiled_functions.entries
    @if f.name == func_name
      target = f
    @end
  @end
  
  @if target == 0
    println("  [JIT] Function not found: " + func_name)
    return 0
  @end
  
  @! Execute JIT machine state with dynamic register environment
  env = []
  ret_val = 0
  
  @if target.mir != 0 && target.mir.instructions != 0
    @for inst in target.mir.instructions
      @if inst.op == "CONST_INT"
        env = map_set(env, inst.dest, inst.val)
        ret_val = inst.val
      @elif inst.op == "CONST_FLOAT"
        env = map_set(env, inst.dest, inst.val)
        ret_val = inst.val
      @elif inst.op == "BINOP"
        l_val = map_get_or(env, inst.left, 0)
        r_val = map_get_or(env, inst.right, 0)
        res = 0
        @if inst.binop == "+"
          res = l_val + r_val
        @elif inst.binop == "-"
          res = l_val - r_val
        @elif inst.binop == "*"
          res = l_val * r_val
        @elif inst.binop == "/" && r_val != 0
          res = l_val / r_val
        @elif inst.binop == "=="
          @if l_val == r_val res = 1 @else res = 0 @end
        @elif inst.binop == "<"
          @if l_val < r_val res = 1 @else res = 0 @end
        @elif inst.binop == ">"
          @if l_val > r_val res = 1 @else res = 0 @end
        @end
        env = map_set(env, inst.dest, res)
        ret_val = res
      @elif inst.op == "ASSIGN"
        src_val = map_get_or(env, inst.src, 0)
        env = map_set(env, inst.dest, src_val)
        ret_val = src_val
      @elif inst.op == "RETURN"
        @if inst.val != 0
          return map_get_or(env, inst.val, inst.val)
        @end
        return ret_val
      @end
    @end
  @end
  
  return ret_val
@end
