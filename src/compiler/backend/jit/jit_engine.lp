@! ============================================================================
@! LIPI JIT COMPILER BACKEND — IN-MEMORY COMPILATION & EXECUTION ENGINE
@! Module: compiler/backend/jit/jit_engine.lp
@! Architecture: In-Memory AST -> IR -> x86-64 Machine Code Generation directly to RAM
@! Standard: Zero Disk I/O, Instant Expression Evaluation, Persistent Functions & State
@! ============================================================================

import "utso/collections"
import "utso/string"
import "src/compiler/frontend/parser"
import "src/compiler/middleend/ast_to_ssa"
import "src/compiler/backend/jit/jit_memory"
import "src/compiler/backend/jit/jit_executor"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURES & INTERFACES
@! ----------------------------------------------------------------------------

@struct SymbolOffsetEntry
  sym_id: i64
  name: string
  sym_offset: i64
@end

@struct JitSymbolEntry
  sym_name: string
  fn_addr: i64
  ret_type: string
  param_count: i64
  code_size: i64
  block_idx: i64
@end

@struct JitCompileResult
  success: i64
  entry_addr: i64
  code_size: i64
  block: any
  error_msg: string
  symbols: array
@end

@struct JitEvalResult
  success: i64
  value: i64
  val_type: string
  error_msg: string
@end

@struct JitEnvVar
  ev_pad0: i64
  name: string
  ev_val: i64
  ev_is_str: i64
  ev_sval: string
@end

@struct JitFnSource
  fs_pad0: i64
  name: string
  fs_src: string
@end

@struct JitEngine
  memory_blocks: array
  symbol_table: array
  global_env: array
  fn_sources: array
  opt_level: i64
  seq_id: i64
@end

@! ----------------------------------------------------------------------------
@! 2. ENGINE LIFECYCLE MANAGEMENT
@! ----------------------------------------------------------------------------

let g_global_jit_seq = 1000

@fn jit_next_seq()
  g_global_jit_seq = g_global_jit_seq + 1
  return g_global_jit_seq
@end

@! Creates a new instance of the sovereign LiPi JIT Engine
@fn jit_engine_new()
  eng = JitEngine()
  eng.memory_blocks = []
  eng.symbol_table = []
  eng.global_env = []
  eng.fn_sources = []
  eng.opt_level = 0
  eng.seq_id = 0
  return eng
@end

@! Frees all allocated memory pages and cleans up JIT engine resources
@fn jit_engine_free(engine)
  @if engine == 0
    return 0
  @end

  i = 0
  num_items = engine.memory_blocks.len()
  @while i < num_items
    blk = engine.memory_blocks[i]
    jit_mem_free(blk)
    i = i + 1
  @end

  engine.memory_blocks = []
  engine.symbol_table = []
  engine.global_env = []
  engine.fn_sources = []
  return 1
@end

@! ----------------------------------------------------------------------------
@! 3. SYMBOL TABLE & ENVIRONMENT MANAGEMENT
@! ----------------------------------------------------------------------------

@! Looks up a function symbol address in the JIT symbol table
@fn jit_lookup_symbol(engine, name)
  @if engine == 0
    return 0
  @end

  i = engine.symbol_table.len() - 1
  @while i >= 0
    entry = engine.symbol_table[i]
    @if entry.sym_name == name
      return entry.fn_addr
    @end
    i = i - 1
  @end
  return 0
@end

@! Looks up a full symbol table entry by name
@fn jit_lookup_symbol_entry(engine, name)
  @if engine == 0
    return 0
  @end

  i = engine.symbol_table.len() - 1
  @while i >= 0
    entry = engine.symbol_table[i]
    @if entry.sym_name == name
      return entry
    @end
    i = i - 1
  @end
  return 0
@end

@! Registers or updates a symbol in the JIT engine
@fn jit_register_symbol(engine, name, addr, ret_type, param_count, code_size, block_idx)
  new_table = []
  updated = 0
  i = 0
  num_items = engine.symbol_table.len()
  @while i < num_items
    entry = engine.symbol_table[i]
    @if entry.sym_name == name
      upd = JitSymbolEntry()
      upd.sym_name = name
      upd.fn_addr = addr
      upd.ret_type = ret_type
      upd.param_count = param_count
      upd.code_size = code_size
      upd.block_idx = block_idx
      new_table = new_table.push(upd)
      updated = 1
    @else
      new_table = new_table.push(entry)
    @end
    i = i + 1
  @end

  @if updated == 0
    add_e = JitSymbolEntry()
    add_e.sym_name = name
    add_e.fn_addr = addr
    add_e.ret_type = ret_type
    add_e.param_count = param_count
    add_e.code_size = code_size
    add_e.block_idx = block_idx
    new_table = new_table.push(add_e)
  @end

  engine.symbol_table = new_table
  return addr
@end

@! Registers a persistent function source in the JIT engine
@fn jit_register_fn_source(engine, fn_name, fn_src)
  new_fns = []
  updated = 0
  i = 0
  num_items = engine.fn_sources.len()
  @while i < num_items
    item = engine.fn_sources[i]
    @if item.name == fn_name
      fs = JitFnSource()
      fs.fs_pad0 = 0
      fs.name = fn_name
      fs.fs_src = fn_src
      new_fns = new_fns.push(fs)
      updated = 1
    @else
      new_fns = new_fns.push(item)
    @end
    i = i + 1
  @end

  @if updated == 0
    fs2 = JitFnSource()
    fs2.fs_pad0 = 0
    fs2.name = fn_name
    fs2.fs_src = fn_src
    new_fns = new_fns.push(fs2)
  @end

  engine.fn_sources = new_fns
  return engine
@end

@! Registers or updates a persistent global variable in the JIT environment
@fn jit_env_set_var(engine, name, val, is_str, sval)
  new_env = []
  updated = 0
  i = 0
  num_items = engine.global_env.len()
  @while i < num_items
    item = engine.global_env[i]
    @if item.name == name
      ev = JitEnvVar()
      ev.ev_pad0 = 0
      ev.name = name
      ev.ev_val = val
      ev.ev_is_str = is_str
      ev.ev_sval = sval
      new_env = new_env.push(ev)
      updated = 1
    @else
      new_env = new_env.push(item)
    @end
    i = i + 1
  @end

  @if updated == 0
    ev2 = JitEnvVar()
    ev2.ev_pad0 = 0
    ev2.name = name
    ev2.ev_val = val
    ev2.ev_is_str = is_str
    ev2.ev_sval = sval
    new_env = new_env.push(ev2)
  @end

  engine.global_env = new_env
  return engine
@end

@! Gets a variable from the persistent global environment
@fn jit_env_get_var(engine, name)
  i = 0
  num_items = engine.global_env.len()
  @while i < num_items
    item = engine.global_env[i]
    @if item.name == name
      return item
    @end
    i = i + 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 4. IN-MEMORY JIT COMPILATION PIPELINE (AST -> IR -> x86-64 -> RAM)
@! ----------------------------------------------------------------------------

// ── x86-64 Machine Code Emission Helpers for Real SSA IR Lowering ────────────
// WHY: Replaces the legacy 11-byte `mov eax, 0; ret` stub with a genuine System V AMD64
// SSA IR -> x86-64 native code generator supporting constants, arithmetic, bitwise ops,
// comparisons, conditional/unconditional branches, locals (alloca/load/store), calls, and returns.

@fn _jit_push_u32(buf, val)
  v = val & 4294967295
  buf = buf.push(v & 255)
  buf = buf.push((v >> 8) & 255)
  buf = buf.push((v >> 16) & 255)
  buf = buf.push((v >> 24) & 255)
  return buf
@end

@fn _jit_push_u64(buf, val)
  lo = val & 4294967295
  hi = (val >> 32) & 4294967295
  buf = _jit_push_u32(buf, lo)
  buf = _jit_push_u32(buf, hi)
  return buf
@end

@fn _jit_patch_i32(buf, off, rel32)
  v = rel32 & 4294967295
  list_set(buf, off + 0, v & 255)
  list_set(buf, off + 1, (v >> 8) & 255)
  list_set(buf, off + 2, (v >> 16) & 255)
  list_set(buf, off + 3, (v >> 24) & 255)
  return 0
@end

@fn _jit_find_slot(slot_names, slot_offs, name)
  i = 0
  n = slot_names.len()
  @while i < n
    @if slot_names[i] == name
      return slot_offs[i]
    @end
    i = i + 1
  @end
  return 0
@end

@fn _jit_ensure_slot(slot_names, slot_offs, name)
  existing = _jit_find_slot(slot_names, slot_offs, name)
  @if existing > 0
    return existing
  @end
  new_off = (slot_names.len() + 1) * 8
  push(slot_names, name)
  push(slot_offs, new_off)
  return new_off
@end

@fn _jit_is_const_val(val)
  // WHY: Use unique SSAValue.val_kind field (index 6) rather than 'kind' (collides with ASTNode.kind @ 0).
  @if val == 0
    return 0
  @end
  @if val.val_kind == 2
    return 1
  @end
  return 0
@end

@fn _jit_emit_load_reg(buf, slot_names, slot_offs, val, dst_rcx)
  // WHY: Materializes SSA constant or stack-slotted local/temporary into rax (dst_rcx=0) or rcx (dst_rcx=1).
  @if val == 0
    @if dst_rcx == 0
      buf = buf.push(49)
      buf = buf.push(192) // xor eax, eax
    @else
      buf = buf.push(49)
      buf = buf.push(201) // xor ecx, ecx
    @end
    return buf
  @end
  @if _jit_is_const_val(val) == 1
    buf = buf.push(72)
    @if dst_rcx == 0
      buf = buf.push(184) // movabs rax, imm64
    @else
      buf = buf.push(185) // movabs rcx, imm64
    @end
    buf = _jit_push_u64(buf, val.const_val)
    return buf
  @end
  off = _jit_find_slot(slot_names, slot_offs, val.id)
  @if off <= 0
    @if dst_rcx == 0
      buf = buf.push(49)
      buf = buf.push(192)
    @else
      buf = buf.push(49)
      buf = buf.push(201)
    @end
    return buf
  @end
  disp = 0 - off
  buf = buf.push(72)
  buf = buf.push(139)
  @if dst_rcx == 0
    buf = buf.push(133) // mov rax, [rbp + disp32]
  @else
    buf = buf.push(141) // mov rcx, [rbp + disp32]
  @end
  buf = _jit_push_u32(buf, disp)
  return buf
@end

@fn _jit_emit_store_rax(buf, slot_names, slot_offs, target_val)
  @if target_val == 0
    return buf
  @end
  off = _jit_find_slot(slot_names, slot_offs, target_val.id)
  @if off <= 0
    return buf
  @end
  disp = 0 - off
  buf = buf.push(72)
  buf = buf.push(137)
  buf = buf.push(133) // mov [rbp + disp32], rax
  buf = _jit_push_u32(buf, disp)
  return buf
@end

@fn _jit_emit_epilogue(buf)
  // mov rsp, rbp (48 89 EC); pop rbp (5D); ret (C3)
  buf = buf.push(72)
  buf = buf.push(137)
  buf = buf.push(236)
  buf = buf.push(93)
  buf = buf.push(195)
  return buf
@end

// WHY: Lowers an SSA IR module into genuine executable System V AMD64 machine code bytes
// with intra-block branch backpatching and inter-function relative call resolution.
@fn x86_codegen_module(ir_mod)
  text_bytes = []
  rodata_bytes = []
  symbols = []
  call_patch_offs = []
  call_patch_names = []
  
  @if ir_mod == 0
    text_bytes = [49, 192, 195] // xor eax, eax; ret
    se0 = SymbolOffsetEntry()
    se0.sym_id = 0
    se0.name = "main"
    se0.sym_offset = 0
    symbols = symbols.push(se0)
    return {
      text_bytes: text_bytes,
      rodata_bytes: rodata_bytes,
      symbol_offsets: symbols,
      entry_offset: 0
    }
  @end

  num_fns = ir_mod.functions.len()
  @if num_fns == 0
    text_bytes = [49, 192, 195]
    se1 = SymbolOffsetEntry()
    se1.sym_id = 0
    se1.name = "main"
    se1.sym_offset = 0
    symbols = symbols.push(se1)
    return {
      text_bytes: text_bytes,
      rodata_bytes: rodata_bytes,
      symbol_offsets: symbols,
      entry_offset: 0
    }
  @end

  fi = 0
  @while fi < num_fns
    fn_obj = ir_mod.functions[fi]
    fn_off = text_bytes.len()
    se = SymbolOffsetEntry()
    se.sym_id = fi
    se.name = fn_obj.name
    se.sym_offset = fn_off
    symbols = symbols.push(se)

    // Pass 1: Reserve RBP-relative stack slots for all params, allocas, and SSA values
    slot_names = []
    slot_offs = []
    pi = 0
    pcnt = fn_obj.params.len()
    @while pi < pcnt
      pval = fn_obj.params[pi]
      @if pval != 0
        _jit_ensure_slot(slot_names, slot_offs, pval.id)
      @end
      pi = pi + 1
    @end

    ai = 0
    acnt = fn_obj.allocas.len()
    @while ai < acnt
      ainst = fn_obj.allocas[ai]
      @if ainst != 0 && ainst.result != 0
        _jit_ensure_slot(slot_names, slot_offs, ainst.result.id)
      @end
      ai = ai + 1
    @end

    bi = 0
    bcnt = fn_obj.blocks.len()
    @while bi < bcnt
      bb = fn_obj.blocks[bi]
      ii = 0
      icnt = bb.instructions.len()
      @while ii < icnt
        inst = bb.instructions[ii]
        @if inst != 0 && inst.is_dead == 0 && inst.result != 0
          _jit_ensure_slot(slot_names, slot_offs, inst.result.id)
        @end
        ii = ii + 1
      @end
      bi = bi + 1
    @end

    raw_frame = slot_names.len() * 8
    frame_size = ((raw_frame + 15) / 16) * 16
    @if frame_size < 16
      frame_size = 16
    @end

    // Emit System V AMD64 prologue: push rbp; mov rbp, rsp; sub rsp, frame_size
    text_bytes = text_bytes.push(85)
    text_bytes = text_bytes.push(72)
    text_bytes = text_bytes.push(137)
    text_bytes = text_bytes.push(229)
    text_bytes = text_bytes.push(72)
    text_bytes = text_bytes.push(129)
    text_bytes = text_bytes.push(236)
    text_bytes = _jit_push_u32(text_bytes, frame_size)

    // Spill incoming System V AMD64 parameter registers (rdi, rsi, rdx, rcx, r8, r9)
    pi = 0
    @while pi < pcnt && pi < 6
      pval = fn_obj.params[pi]
      @if pval != 0
        poff = _jit_find_slot(slot_names, slot_offs, pval.id)
        pdisp = 0 - poff
        @if pi == 0
          text_bytes = text_bytes.push(72)
          text_bytes = text_bytes.push(137)
          text_bytes = text_bytes.push(189) // mov [rbp+disp32], rdi
        @elif pi == 1
          text_bytes = text_bytes.push(72)
          text_bytes = text_bytes.push(137)
          text_bytes = text_bytes.push(181) // mov [rbp+disp32], rsi
        @elif pi == 2
          text_bytes = text_bytes.push(72)
          text_bytes = text_bytes.push(137)
          text_bytes = text_bytes.push(149) // mov [rbp+disp32], rdx
        @elif pi == 3
          text_bytes = text_bytes.push(72)
          text_bytes = text_bytes.push(137)
          text_bytes = text_bytes.push(141) // mov [rbp+disp32], rcx
        @elif pi == 4
          text_bytes = text_bytes.push(76)
          text_bytes = text_bytes.push(137)
          text_bytes = text_bytes.push(133) // mov [rbp+disp32], r8
        @elif pi == 5
          text_bytes = text_bytes.push(76)
          text_bytes = text_bytes.push(137)
          text_bytes = text_bytes.push(141) // mov [rbp+disp32], r9
        @end
        text_bytes = _jit_push_u32(text_bytes, pdisp)
      @end
      pi = pi + 1
    @end

    // Pass 2: Emit basic blocks and record jump backpatches
    bb_labels = []
    bb_offs = []
    jmp_patch_offs = []
    jmp_patch_lbls = []

    bi = 0
    @while bi < bcnt
      bb = fn_obj.blocks[bi]
      push(bb_labels, bb.label)
      push(bb_offs, text_bytes.len())

      ii = 0
      icnt = bb.instructions.len()
      @while ii < icnt
        inst = bb.instructions[ii]
        @if inst != 0 && inst.is_dead == 0
          op = inst.op
          @if op == 0
            // OP_NOP
          @elif op == 1
            // OP_ALLOCA: zero-initialize stack slot
            text_bytes = text_bytes.push(49)
            text_bytes = text_bytes.push(192) // xor eax, eax
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 2
            // OP_LOAD: read value from alloca slot into result slot
            @if inst.operands.len() >= 1
              text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
              text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
            @end
          @elif op == 3
            // OP_STORE: write operands[0] value into operands[1] alloca slot
            @if inst.operands.len() >= 2
              text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
              text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.operands[1])
            @end
          @elif op == 4 || op == 32
            // OP_ADD / OP_ADD_DYN: rax + rcx
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(1)
            text_bytes = text_bytes.push(200) // add rax, rcx
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 5
            // OP_SUB: rax - rcx
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(41)
            text_bytes = text_bytes.push(200) // sub rax, rcx
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 6
            // OP_MUL: imul rax, rcx
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(15)
            text_bytes = text_bytes.push(175)
            text_bytes = text_bytes.push(193) // imul rax, rcx
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 7
            // OP_DIV: zero- and INT64_MIN/-1-guarded signed 64-bit idiv (zero SIGFPE)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(133)
            text_bytes = text_bytes.push(201) // test rcx, rcx
            text_bytes = text_bytes.push(117)
            text_bytes = text_bytes.push(4)   // jnz +4 (skip xor+jmp)
            text_bytes = text_bytes.push(49)
            text_bytes = text_bytes.push(192) // xor eax, eax
            text_bytes = text_bytes.push(235)
            text_bytes = text_bytes.push(16)  // jmp +16 (skip cmp+jne+neg+jmp+cqo+idiv)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(131)
            text_bytes = text_bytes.push(249)
            text_bytes = text_bytes.push(255) // cmp rcx, -1
            text_bytes = text_bytes.push(117)
            text_bytes = text_bytes.push(5)   // jne +5 (skip neg+jmp)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(247)
            text_bytes = text_bytes.push(216) // neg rax (wraps INT64_MIN/-1 safely)
            text_bytes = text_bytes.push(235)
            text_bytes = text_bytes.push(5)   // jmp +5 (skip cqo+idiv)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(153) // cqo
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(247)
            text_bytes = text_bytes.push(249) // idiv rcx
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 8
            // OP_MOD: zero- and INT64_MIN/-1-guarded signed 64-bit remainder in rdx (zero SIGFPE)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(133)
            text_bytes = text_bytes.push(201) // test rcx, rcx
            text_bytes = text_bytes.push(117)
            text_bytes = text_bytes.push(4)   // jnz +4
            text_bytes = text_bytes.push(49)
            text_bytes = text_bytes.push(192) // xor eax, eax
            text_bytes = text_bytes.push(235)
            text_bytes = text_bytes.push(18)  // jmp +18 (skip cmp+jne+xor+jmp+cqo+idiv+mov)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(131)
            text_bytes = text_bytes.push(249)
            text_bytes = text_bytes.push(255) // cmp rcx, -1
            text_bytes = text_bytes.push(117)
            text_bytes = text_bytes.push(4)   // jne +4 (skip xor+jmp)
            text_bytes = text_bytes.push(49)
            text_bytes = text_bytes.push(192) // xor eax, eax (x % -1 == 0)
            text_bytes = text_bytes.push(235)
            text_bytes = text_bytes.push(8)   // jmp +8 (skip cqo+idiv+mov)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(153) // cqo
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(247)
            text_bytes = text_bytes.push(249) // idiv rcx
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(137)
            text_bytes = text_bytes.push(208) // mov rax, rdx
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 9
            // OP_NEG: neg rax
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(247)
            text_bytes = text_bytes.push(216) // neg rax
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 10
            // OP_SHL: shl rax, cl
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(211)
            text_bytes = text_bytes.push(224) // shl rax, cl
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 11
            // OP_SHR: sar rax, cl
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(211)
            text_bytes = text_bytes.push(248) // sar rax, cl
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 12
            // OP_AND: and rax, rcx
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(33)
            text_bytes = text_bytes.push(200) // and rax, rcx
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 13
            // OP_OR: or rax, rcx
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(9)
            text_bytes = text_bytes.push(200) // or rax, rcx
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 14
            // OP_XOR: xor rax, rcx
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(49)
            text_bytes = text_bytes.push(200) // xor rax, rcx
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 15 || op == 33
            // OP_CMP / OP_CMP_DYN: cmp rax, rcx; setCC al; movzx rax, al
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[1], 1)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(57)
            text_bytes = text_bytes.push(200) // cmp rax, rcx
            cc_op = 148 // sete (CMP_EQ=1)
            @if inst.extra_int == 2
              cc_op = 149 // setne (CMP_NE=2)
            @elif inst.extra_int == 3
              cc_op = 156 // setl (CMP_SLT=3)
            @elif inst.extra_int == 4
              cc_op = 158 // setle (CMP_SLE=4)
            @elif inst.extra_int == 5
              cc_op = 159 // setg (CMP_SGT=5)
            @elif inst.extra_int == 6
              cc_op = 157 // setge (CMP_SGE=6)
            @end
            text_bytes = text_bytes.push(15)
            text_bytes = text_bytes.push(cc_op)
            text_bytes = text_bytes.push(192) // setCC al
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(15)
            text_bytes = text_bytes.push(182)
            text_bytes = text_bytes.push(192) // movzx rax, al
            text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
          @elif op == 16
            // OP_BR: conditional branch br cond, true_lbl, false_lbl
            text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            text_bytes = text_bytes.push(72)
            text_bytes = text_bytes.push(133)
            text_bytes = text_bytes.push(192) // test rax, rax
            text_bytes = text_bytes.push(15)
            text_bytes = text_bytes.push(133) // jnz rel32
            push(jmp_patch_offs, text_bytes.len())
            push(jmp_patch_lbls, inst.extra_list[0])
            text_bytes = _jit_push_u32(text_bytes, 0)
            text_bytes = text_bytes.push(233) // jmp rel32
            push(jmp_patch_offs, text_bytes.len())
            push(jmp_patch_lbls, inst.extra_list[1])
            text_bytes = _jit_push_u32(text_bytes, 0)
          @elif op == 17
            // OP_JMP: unconditional jump jmp target_lbl
            text_bytes = text_bytes.push(233) // jmp rel32
            push(jmp_patch_offs, text_bytes.len())
            push(jmp_patch_lbls, inst.extra_str)
            text_bytes = _jit_push_u32(text_bytes, 0)
          @elif op == 18
            // OP_RET: return optional value in rax
            @if inst.operands.len() > 0
              text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[0], 0)
            @else
              text_bytes = text_bytes.push(49)
              text_bytes = text_bytes.push(192) // xor eax, eax
            @end
            text_bytes = _jit_emit_epilogue(text_bytes)
          @elif op == 19
            // OP_CALL: load up to 6 System V AMD64 arguments and emit relative call rel32
            ac = inst.operands.len()
            ci = 0
            @while ci < ac && ci < 6
              text_bytes = _jit_emit_load_reg(text_bytes, slot_names, slot_offs, inst.operands[ci], 0)
              @if ci == 0
                text_bytes = text_bytes.push(72)
                text_bytes = text_bytes.push(137)
                text_bytes = text_bytes.push(199) // mov rdi, rax
              @elif ci == 1
                text_bytes = text_bytes.push(72)
                text_bytes = text_bytes.push(137)
                text_bytes = text_bytes.push(198) // mov rsi, rax
              @elif ci == 2
                text_bytes = text_bytes.push(72)
                text_bytes = text_bytes.push(137)
                text_bytes = text_bytes.push(194) // mov rdx, rax
              @elif ci == 3
                text_bytes = text_bytes.push(72)
                text_bytes = text_bytes.push(137)
                text_bytes = text_bytes.push(193) // mov rcx, rax
              @elif ci == 4
                text_bytes = text_bytes.push(73)
                text_bytes = text_bytes.push(137)
                text_bytes = text_bytes.push(192) // mov r8, rax
              @elif ci == 5
                text_bytes = text_bytes.push(73)
                text_bytes = text_bytes.push(137)
                text_bytes = text_bytes.push(193) // mov r9, rax
              @end
              ci = ci + 1
            @end
            text_bytes = text_bytes.push(232) // call rel32
            push(call_patch_offs, text_bytes.len())
            push(call_patch_names, inst.extra_str)
            text_bytes = _jit_push_u32(text_bytes, 0)
            @if inst.result != 0
              text_bytes = _jit_emit_store_rax(text_bytes, slot_names, slot_offs, inst.result)
            @end
          @end
        @end
        ii = ii + 1
      @end
      bi = bi + 1
    @end

    // Fallback epilogue in case final block has no explicit OP_RET
    text_bytes = text_bytes.push(49)
    text_bytes = text_bytes.push(192)
    text_bytes = _jit_emit_epilogue(text_bytes)

    // Backpatch intra-function basic block jumps
    ji = 0
    jcnt = jmp_patch_offs.len()
    @while ji < jcnt
      poff = jmp_patch_offs[ji]
      tlbl = jmp_patch_lbls[ji]
      toff = 0 - 1
      ki = 0
      @while ki < bb_labels.len()
        @if bb_labels[ki] == tlbl
          toff = bb_offs[ki]
          ki = bb_labels.len()
        @else
          ki = ki + 1
        @end
      @end
      @if toff >= 0
        _jit_patch_i32(text_bytes, poff, toff - (poff + 4))
      @end
      ji = ji + 1
    @end

    fi = fi + 1
  @end

  // Backpatch inter-function OP_CALL rel32 displacements across the module; fail closed on unresolved targets
  // WHY: Leaving an unpatched `call rel32=0` (E8 00 00 00 00) would push a stray return address and corrupt RSP.
  has_unresolved = 0
  ci = 0
  ccnt = call_patch_offs.len()
  @while ci < ccnt
    cpoff = call_patch_offs[ci]
    cname = call_patch_names[ci]
    target_off = 0 - 1
    si = 0
    @while si < symbols.len()
      @if symbols[si].name == cname
        target_off = symbols[si].sym_offset
        si = symbols.len()
      @else
        si = si + 1
      @end
    @end
    @if target_off >= 0
      _jit_patch_i32(text_bytes, cpoff, target_off - (cpoff + 4))
    @else
      has_unresolved = 1
    @end
    ci = ci + 1
  @end

  @if has_unresolved == 1
    return {
      text_bytes: [],
      rodata_bytes: [],
      symbol_offsets: [],
      entry_offset: 0
    }
  @end

  entry_off = 0
  si = 0
  @while si < symbols.len()
    @if symbols[si].name == "main"
      entry_off = symbols[si].sym_offset
      si = symbols.len()
    @else
      si = si + 1
    @end
  @end

  return {
    text_bytes: text_bytes,
    rodata_bytes: rodata_bytes,
    symbol_offsets: symbols,
    entry_offset: entry_off
  }
@end

@! Lowers an IR module to machine code and directly copies into W^X-protected RAM (RW -> RX)
@fn jit_compile_ir_to_memory(engine, ir_mod)
  @! 1. Generate System V AMD64 Machine Code opcodes in RAM buffer
  x86_res = x86_codegen_module(ir_mod)

  text_len = x86_res.text_bytes.len()
  rodata_len = x86_res.rodata_bytes.len()
  total_bytes = text_len + rodata_len

  @if total_bytes <= 0
    return {
      success: 0,
      entry_addr: 0,
      code_size: 0,
      block: 0,
      error_msg: "JIT Codegen Error: 0 machine code bytes generated",
      symbols: []
    }
  @end

  @! 2. Allocate Anonymous RW-Only RAM via sys_mmap (PROT_READ|PROT_WRITE = 3, strict W^X)
  block = jit_mem_alloc(total_bytes)
  @if block.addr == 0
    return {
      success: 0,
      entry_addr: 0,
      code_size: 0,
      block: 0,
      error_msg: "JIT Memory Error: sys_mmap allocation failed",
      symbols: []
    }
  @end

  @! 3. Copy .text machine code bytes directly into RW RAM page
  jit_mem_write_bytes(block, 0, x86_res.text_bytes)

  @! 4. Copy .rodata constants if present
  @if rodata_len > 0
    jit_mem_write_bytes(block, text_len, x86_res.rodata_bytes)
  @end

  @! 5. Apply Strict W^X Page Protection Transition (RW -> RX: PROT_READ|PROT_EXEC = 5)
  mprot_res = jit_mem_protect_rx(block)
  @if mprot_res < 0
    jit_mem_free(block)
    return {
      success: 0,
      entry_addr: 0,
      code_size: 0,
      block: 0,
      error_msg: "JIT W^X Error: sys_mprotect(PROT_READ|PROT_EXEC) failed",
      symbols: []
    }
  @end

  @! 6. Record memory block in engine
  block_idx = engine.memory_blocks.len()
  engine.memory_blocks = engine.memory_blocks.push(block)

  @! 7. Register all exported functions in the JIT symbol table
  _i_sym_entry_0 = 0
  @while _i_sym_entry_0 < x86_res.symbol_offsets.len()
    sym_entry = x86_res.symbol_offsets[_i_sym_entry_0]
    fn_addr = block.addr + sym_entry.sym_offset
    jit_register_symbol(engine, sym_entry.name, fn_addr, "i64", 0, text_len, block_idx)
    _i_sym_entry_0 = _i_sym_entry_0 + 1
  @end

  entry_addr = block.addr + x86_res.entry_offset
  @if x86_res.entry_offset == 0 && x86_res.symbol_offsets.len() > 0
    entry_addr = block.addr + x86_res.symbol_offsets[0].sym_offset
  @end

  return {
    success: 1,
    entry_addr: entry_addr,
    code_size: total_bytes,
    block: block,
    error_msg: "",
    symbols: x86_res.symbol_offsets
  }
@end

@! Compiles full LiPi source code directly into RAM without disk I/O
@fn jit_compile_source(engine, source_code)
  @! 1. Tokenize & Parse AST
  parsed = parser_parse_program(source_code)
  ast = parsed.ast_statements
  tokens = parsed.ast_tokens

  @if ast.len() == 0
    return {
      success: 0,
      entry_addr: 0,
      code_size: 0,
      block: 0,
      error_msg: "JIT Syntax Error: Parser produced 0 AST statements",
      symbols: []
    }
  @end

  @! 2. Lower AST to LiPi IR
  engine.seq_id = engine.seq_id + 1
  mod_name = "jit_mod_" + int_to_str(engine.seq_id)
  ir_opts = { module_name: mod_name, dump_ir: 0 }
  ir_res = ir_module_from_ast(ast, ir_opts)

  @if ir_res.error == 1
    return {
      success: 0,
      entry_addr: 0,
      code_size: 0,
      block: 0,
      error_msg: "JIT IR Lowering Error: " + ir_res.message,
      symbols: []
    }
  @end

  @! 3. Emit directly into executable memory
  return jit_compile_ir_to_memory(engine, ir_res.module)
@end

@! Compiles a single function AST node directly into RAM
@fn jit_compile_function(engine, fn_name, fn_source)
  @! Register in persistent function sources
  jit_register_fn_source(engine, fn_name, fn_source)

  @! Compile the function source
  return jit_compile_source(engine, fn_source)
@end

@! ----------------------------------------------------------------------------
@! 5. INSTANT EXPRESSION EVALUATION ENGINE
@! ----------------------------------------------------------------------------

@! Builds a synthetic source wrapper containing registered functions & variables
@fn jit_build_eval_source(engine, expr_code, fn_name)
  source = ""

  @! 1. Prepend all persistent function definitions
  i = 0
  f_len = engine.fn_sources.len()
  @while i < f_len
    item = engine.fn_sources[i]
    source = source + item.fs_src + "\n"
    i = i + 1
  @end

  @! 2. Generate synthetic evaluation function
  source = source + "@fn " + fn_name + "()\n"

  @! Inject persistent variables from global environment
  v_i = 0
  v_len = engine.global_env.len()
  @while v_i < v_len
    v = engine.global_env[v_i]
    @if v.ev_is_str == 1
      source = source + "  " + v.name + " = \"" + v.ev_sval + "\"\n"
    @else
      source = source + "  " + v.name + " = " + int_to_str(v.ev_val) + "\n"
    @end
    v_i = v_i + 1
  @end

  @! Return evaluated expression
  source = source + "  return " + expr_code + "\n@end\n"
  return source
@end

@! Compiles an interactive expression into a synthetic RAM function
@fn jit_compile_expression(engine, expr_code)
  engine.seq_id = engine.seq_id + 1
  fn_name = "__jit_eval_" + int_to_str(engine.seq_id)

  synthetic_source = jit_build_eval_source(engine, expr_code, fn_name)
  comp_res = jit_compile_source(engine, synthetic_source)

  @if comp_res.success == 0
    return comp_res
  @end

  fn_addr = jit_lookup_symbol(engine, fn_name)
  @if fn_addr != 0
    comp_res.entry_addr = fn_addr
  @end

  return comp_res
@end

@! Compiles and immediately executes an expression in RAM, returning JitEvalResult
@fn jit_eval_expression(engine, expr_code)
  comp_res = jit_compile_expression(engine, expr_code)
  @if comp_res == 0 || comp_res.success == 0
    return {
      success: 0,
      value: 0,
      val_type: "error",
      error_msg: "error"
    }
  @end

  res_val = lipi_jit_call0(comp_res.entry_addr)
  res_obj = {
    success: 1,
    value: res_val,
    val_type: "i64",
    error_msg: ""
  }
  return res_obj
@end

@! ----------------------------------------------------------------------------
@! 6. CONVENIENCE HIGH-LEVEL JIT API
@! ----------------------------------------------------------------------------

@! Compiles and executes a LiPi source string in a transient JIT engine with zero disk I/O
@fn jit_compile_and_exec(source_code)
  engine = jit_engine_new()
  comp_res = jit_compile_source(engine, source_code)

  @if comp_res.success == 0
    jit_engine_free(engine)
    return 0 - 1
  @end

  res = jit_invoke_fn0(comp_res.entry_addr)
  jit_engine_free(engine)
  return res
@end
