@! ============================================================================
@! WebAssembly Linker (Expanded)
@! ============================================================================
import "compiler/backend/wasm/wasm_ir"
import "compiler/backend/wasm/wasm_emitter"
import "compiler/backend/x86_64/codegen"
import "compiler/backend/maya_ir"

@fn lower_maya_type(maya_type)
  @! Maya Int -> I64, Bool -> I32, Float -> F64, Ptr -> I32
  @if maya_type == 1 return wasm_type_i64() @end
  @if maya_type == 2 return wasm_type_i32() @end
  @if maya_type == 3 return wasm_type_f64() @end
  @if maya_type == 4 return wasm_type_i32() @end
  return wasm_type_i32()
@end

@fn generate_imports(w_mod)
  w_mod.imports = w_mod.imports.push({
    module_name: "env",
    field_name: "console_log",
    kind: 0,
    type_idx: 0
  })
  w_mod.imports = w_mod.imports.push({
    module_name: "env",
    field_name: "performance_now",
    kind: 0,
    type_idx: 1
  })
  return w_mod
@end

@fn generate_exports(w_mod, funcs_len)
  w_mod.exports = w_mod.exports.push({ name: "maya_main", kind: 0, index: funcs_len })
  w_mod.exports = w_mod.exports.push({ name: "maya_alloc", kind: 0, index: funcs_len + 1 })
  w_mod.exports = w_mod.exports.push({ name: "maya_gc_collect", kind: 0, index: funcs_len + 2 })
  w_mod.exports = w_mod.exports.push({ name: "memory", kind: 2, index: 0 })
  return w_mod
@end

@fn setup_memory(w_mod)
  @! Page 0: stack, Page 1+: heap
  w_mod.memories = w_mod.memories.push({ limits_min: 2, limits_max: 0, has_max: 0 })
  w_mod.globals = w_mod.globals.push({
    val_type: wasm_type_i32(),
    is_mut: 1,
    init_expr: [instr_new_const_i32(65536)]
  })
  return w_mod
@end

@fn lower_ir_val(body, val)
  @if val == 0 return body @end
  @if val.val_kind == "const_int"
    op = instr_new(wasm_op_i64_const())
    op.imm_i64 = val.val_int
    body = body.push(op)
  @elif val.val_kind == "const_float"
    op = instr_new(wasm_op_f64_const())
    op.imm_i64 = val.val_int
    body = body.push(op)
  @elif val.val_kind == "const_bool"
    op = instr_new(wasm_op_i32_const())
    op.imm_i64 = val.val_int
    body = body.push(op)
  @elif val.val_kind == "reg"
    op = instr_new(wasm_op_local_get())
    idx = val.val_id
    @if idx < 0 idx = 0 @end
    op.imm_list = [idx]
    body = body.push(op)
  @elif val.val_kind == "param"
    op = instr_new(wasm_op_local_get())
    idx = val.val_index
    @if idx < 0 idx = 0 @end
    op.imm_list = [idx]
    body = body.push(op)
  @end
  return body
@end

@fn compile_maya_func(maya_func, type_idx)
  body = []
  
  @! Lower all instructions from function blocks or instruction list
  insts = []
  @if maya_func != 0
    @if maya_func.instructions != 0 && maya_func.instructions.len() > 0
      insts = maya_func.instructions
    @elif maya_func.blocks != 0 && maya_func.blocks.len() > 0
      b_idx = 0
      @while b_idx < maya_func.blocks.len()
        blk = maya_func.blocks[b_idx]
        @if blk != 0 && blk.instructions != 0
          i_idx = 0
          @while i_idx < blk.instructions.len()
            insts = insts.push(blk.instructions[i_idx])
            i_idx = i_idx + 1
          @end
        @end
        b_idx = b_idx + 1
      @end
    @end
  @end

  i = 0
  num_items = insts.len()
  @while i < num_items
    ir = insts[i]
    op_name = ir.inst_op
    @if op_name == "" || op_name == 0
      op_name = ir.op
    @end

    @! 1. Binary Arithmetic & Bitwise
    @if op_name == "ADD"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_add()))
    @elif op_name == "SUB"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_sub()))
    @elif op_name == "MUL"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_mul()))
    @elif op_name == "SDIV" || op_name == "DIV_S"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_div_s()))
    @elif op_name == "UDIV" || op_name == "DIV_U"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_div_u()))
    @elif op_name == "SREM" || op_name == "REM_S"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_rem_s()))
    @elif op_name == "UREM" || op_name == "REM_U"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_rem_u()))
    @elif op_name == "AND"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_and()))
    @elif op_name == "OR"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_or()))
    @elif op_name == "XOR"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_xor()))
    @elif op_name == "SHL"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_shl()))
    @elif op_name == "SHR" || op_name == "SHR_S"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_shr_s()))
    @! 2. Memory Load / Store
    @elif op_name == "LOAD"
      body = lower_ir_val(body, ir.ptr)
      op = instr_new(wasm_op_i64_load())
      align = 3
      @if ir.align > 0 align = ir.align @end
      op.imm_list = [align, 0]
      body = body.push(op)
    @elif op_name == "STORE"
      body = lower_ir_val(body, ir.ptr)
      body = lower_ir_val(body, ir.inst_val)
      op = instr_new(wasm_op_i64_store())
      align = 3
      @if ir.align > 0 align = ir.align @end
      op.imm_list = [align, 0]
      body = body.push(op)
    @! 3. Comparisons
    @elif op_name == "EQ" || op_name == "eq"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_eq()))
    @elif op_name == "NE" || op_name == "ne"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_ne()))
    @elif op_name == "LT" || op_name == "slt"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_lt_s()))
    @elif op_name == "LE" || op_name == "sle"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_le_s()))
    @elif op_name == "GT" || op_name == "sgt"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_gt_s()))
    @elif op_name == "GE" || op_name == "sge"
      body = lower_ir_val(body, ir.left)
      body = lower_ir_val(body, ir.right)
      body = body.push(instr_new(wasm_op_i64_ge_s()))
    @! 4. Control Flow & Calls
    @elif op_name == "RETURN" || op_name == "RET"
      @if ir.inst_val != 0
        body = lower_ir_val(body, ir.inst_val)
      @end
      body = body.push(instr_new(wasm_op_return()))
    @elif op_name == "CALL"
      callee_idx = 0
      @if ir.callee != ""
        @! Function call target
      @end
      c_op = instr_new(wasm_op_call())
      c_op.imm_list = [callee_idx]
      body = body.push(c_op)
    @end

    i = i + 1
  @end
  
  f = { type_idx: type_idx, locals: [], body: body }
  return f
@end

@fn emit_wasm(maya_module)
  w_mod = wasm_module_new()
  
  w_mod.types = w_mod.types.push({ params: [wasm_type_i32()], results: [] })
  w_mod.types = w_mod.types.push({ params: [], results: [wasm_type_f64()] })
  w_mod.types = w_mod.types.push({ params: [wasm_type_i32()], results: [wasm_type_i32()] }) @! alloc
  w_mod.types = w_mod.types.push({ params: [], results: [] }) @! gc
  w_mod.types = w_mod.types.push({ params: [wasm_type_i32(), wasm_type_i32()], results: [wasm_type_i32()] })
  
  w_mod = generate_imports(w_mod)
  w_mod = setup_memory(w_mod)
  
  @! Process functions from maya_module if present
  @if maya_module != 0 && maya_module.functions != 0 && maya_module.functions.len() > 0
    fn_i = 0
    @while fn_i < maya_module.functions.len()
      m_fn = maya_module.functions[fn_i]
      compiled_fn = compile_maya_func(m_fn, 4)
      w_mod.functions = w_mod.functions.push(compiled_fn)
      fn_i = fn_i + 1
    @end
  @else
    body = []
    body = body.push(instr_new(wasm_op_local_get()))
    body[0].imm_list = [0]
    body = body.push(instr_new(wasm_op_local_get()))
    body[1].imm_list = [1]
    body = body.push(instr_new(wasm_op_i32_add()))
    f = { type_idx: 4, locals: [], body: body }
    w_mod.functions = w_mod.functions.push(f)
  @end
  
  alloc_body = []
  
  @! global.get 0 (return value)
  alloc_body = alloc_body.push(instr_new(wasm_op_global_get()))
  alloc_body[0].imm_list = [0]
  
  @! global.get 0 (for addition)
  alloc_body = alloc_body.push(instr_new(wasm_op_global_get()))
  alloc_body[1].imm_list = [0]
  
  @! local.get 0 (size)
  alloc_body = alloc_body.push(instr_new(wasm_op_local_get()))
  alloc_body[2].imm_list = [0]
  
  @! i32.add
  alloc_body = alloc_body.push(instr_new(wasm_op_i32_add()))
  
  @! global.set 0
  alloc_body = alloc_body.push(instr_new(wasm_op_global_set()))
  alloc_body[4].imm_list = [0]
  
  f_alloc = { type_idx: 2, locals: [], body: alloc_body }
  w_mod.functions = w_mod.functions.push(f_alloc)
  
  f_gc = { type_idx: 3, locals: [], body: [] }
  w_mod.functions = w_mod.functions.push(f_gc)
  
  w_mod = generate_exports(w_mod, 2)
  
  buf = write_wasm_module(w_mod)
  return buf.bytes
@end
