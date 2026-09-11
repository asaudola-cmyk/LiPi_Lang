@! ============================================================================
@! MAYA JIT COMPILER BACKEND — IN-MEMORY COMPILATION & EXECUTION ENGINE
@! Module: compiler/backend/jit/jit_engine.maya
@! Architecture: In-Memory AST -> IR -> x86-64 Machine Code Generation directly to RAM
@! Standard: Zero Disk I/O, Instant Expression Evaluation, Persistent Functions & State
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/backend/compiler"
import "compiler/backend/maya_ir"
import "compiler/backend/x86_64/codegen"
import "compiler/backend/jit/jit_memory"
import "compiler/backend/jit/jit_executor"

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
  name: string
  val: i64
  is_str: i64
  sval: string
@end

@struct JitFnSource
  name: string
  src: string
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

@! Creates a new instance of the sovereign Maya JIT Engine
@fn jit_engine_new()
  return {
    memory_blocks: [],
    symbol_table: [],
    global_env: [],
    fn_sources: [],
    opt_level: 0,
    seq_id: 0
  }
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
      new_table = new_table.push({
        sym_name: name,
        fn_addr: addr,
        ret_type: ret_type,
        param_count: param_count,
        code_size: code_size,
        block_idx: block_idx
      })
      updated = 1
    @else
      new_table = new_table.push(entry)
    @end
    i = i + 1
  @end

  @if updated == 0
    new_table = new_table.push({
      sym_name: name,
      fn_addr: addr,
      ret_type: ret_type,
      param_count: param_count,
      code_size: code_size,
      block_idx: block_idx
    })
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
      new_fns = new_fns.push({ name: fn_name, src: fn_src })
      updated = 1
    @else
      new_fns = new_fns.push(item)
    @end
    i = i + 1
  @end

  @if updated == 0
    new_fns = new_fns.push({ name: fn_name, src: fn_src })
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
      new_env = new_env.push({ name: name, val: val, is_str: is_str, sval: sval })
      updated = 1
    @else
      new_env = new_env.push(item)
    @end
    i = i + 1
  @end

  @if updated == 0
    new_env = new_env.push({ name: name, val: val, is_str: is_str, sval: sval })
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

@! Lowers an IR module to machine code and directly copies into allocated executable RAM
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

  @! 2. Allocate Anonymous Executable RAM via sys_mmap (PROT_READ|PROT_WRITE|PROT_EXEC)
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

  @! 3. Copy .text machine code bytes directly into RAM page
  jit_mem_write_bytes(block, 0, x86_res.text_bytes)

  @! 4. Copy .rodata constants if present
  @if rodata_len > 0
    jit_mem_write_bytes(block, text_len, x86_res.rodata_bytes)
  @end

  @! 5. Apply W^X Page Protection (RX)
  jit_mem_protect_rx(block)

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

  entry_addr = block.addr
  @if x86_res.symbol_offsets.len() > 0
    entry_addr = block.addr + x86_res.symbol_offsets[0].sym_offset
  @elif x86_res.entry_offset != 0
    entry_addr = block.addr + x86_res.entry_offset
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

@! Compiles full Maya source code directly into RAM without disk I/O
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

  @! 2. Lower AST to Maya IR
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
    source = source + item.src + "\n"
    i = i + 1
  @end

  @! 2. Generate synthetic evaluation function
  source = source + "@fn " + fn_name + "()\n"

  @! Inject persistent variables from global environment
  v_i = 0
  v_len = engine.global_env.len()
  @while v_i < v_len
    v = engine.global_env[v_i]
    @if v.is_str == 1
      source = source + "  " + v.name + " = \"" + v.sval + "\"\n"
    @else
      source = source + "  " + v.name + " = " + int_to_str(v.val) + "\n"
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

  res_val = maya_jit_call0(comp_res.entry_addr)
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

@! Compiles and executes a Maya source string in a transient JIT engine with zero disk I/O
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
