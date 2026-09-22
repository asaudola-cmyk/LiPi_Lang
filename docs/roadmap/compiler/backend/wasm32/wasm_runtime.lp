@! ============================================================================
@! MAYA STANDARD LIBRARY — WEBASSEMBLY RUNTIME (std.wasm)
@! 100% Written in Pure Maya Language — Run .wasm directly in Maya!
@! ============================================================================

import "universe/core/collections"

@fn list_pop(arr)
  res = []
  len = arr.len()
  @if len <= 1 return res @end
  i = 0
  @while i < len - 1
    res = res.push(arr[i])
    i = i + 1
  @end
  return res
@end

@fn wasm_module_new()
  return {
    memory: [],
    globals: [],
    functions: [],
    exports: []
  }
@end

@fn wasm_parse_binary(wasm_bytes)
  mod = wasm_module_new()
  @if wasm_bytes.len() < 8
    println("  [WASM] Error: Binary too small")
    return mod
  @end
  
  @! Validate WASM Magic: \0asm (0x00, 0x61, 0x73, 0x6D)
  @if wasm_bytes[0] != 0 || wasm_bytes[1] != 97 || wasm_bytes[2] != 115 || wasm_bytes[3] != 109
    println("  [WASM] Invalid WebAssembly Magic Header")
    return mod
  @end
  
  println("  [WASM] Valid WebAssembly binary detected (Version " + wasm_bytes[4].to_str() + ")")
  
  pos = 8
  len = wasm_bytes.len()
  @while pos < len
    sec_id = wasm_bytes[pos]
    pos = pos + 1
    
    @! Read section size (LEB128 simplified to 1-2 bytes)
    sec_size = wasm_bytes[pos]
    pos = pos + 1
    
    sec_end = pos + sec_size
    @if sec_end > len sec_end = len @end
    
    @if sec_id == 7
      @! Export Section
      num_exports = wasm_bytes[pos]
      pos = pos + 1
      e_idx = 0
      @while e_idx < num_exports && pos < sec_end
        name_len = wasm_bytes[pos]
        pos = pos + 1
        exp_name = ""
        n_i = 0
        @while n_i < name_len && pos < sec_end
          exp_name = exp_name + wasm_bytes[pos].to_str()
          pos = pos + 1
          n_i = n_i + 1
        @end
        exp_kind = wasm_bytes[pos]
        pos = pos + 1
        exp_func_idx = wasm_bytes[pos]
        pos = pos + 1
        mod.exports = mod.exports.push({ name: exp_name, kind: exp_kind, index: exp_func_idx })
        e_idx = e_idx + 1
      @end
    @elif sec_id == 10
      @! Code Section (Function Bodies)
      num_funcs = wasm_bytes[pos]
      pos = pos + 1
      f_idx = 0
      @while f_idx < num_funcs && pos < sec_end
        body_size = wasm_bytes[pos]
        pos = pos + 1
        f_end = pos + body_size
        @if f_end > sec_end f_end = sec_end @end
        
        num_locals = wasm_bytes[pos]
        pos = pos + 1
        
        code_bytes = []
        @while pos < f_end
          code_bytes = code_bytes.push(wasm_bytes[pos])
          pos = pos + 1
        @end
        mod.functions = mod.functions.push({ locals: num_locals, code: code_bytes })
        f_idx = f_idx + 1
      @end
    @else
      pos = sec_end
    @end
  @end
  
  return mod
@end

@fn wasm_execute(mod, func_name, args)
  println("  [WASM] Executing WASM function: " + func_name)
  
  target_func = 0
  @for exp in mod.exports
    @if exp.name == func_name && exp.index < mod.functions.len()
      target_func = mod.functions[exp.index]
    @end
  @end
  
  @if target_func == 0 && mod.functions.len() > 0
    target_func = mod.functions[0]
  @end
  
  @if target_func == 0
    @! If no bytecode loaded, evaluate args directly or return 0
    @if args.len() > 0 return args[0] @end
    return 0
  @end
  
  stack = []
  locals = []
  @for a in args
    locals = locals.push(a)
  @end
  @while locals.len() < (args.len() + target_func.locals)
    locals = locals.push(0)
  @end
  
  pc = 0
  code = target_func.code
  clen = code.len()
  
  @while pc < clen
    op = code[pc]
    pc = pc + 1
    
    @if op == 0x41 || op == 0x44 @! i32.const / f64.const
      val = code[pc]
      pc = pc + 1
      stack = stack.push(val)
    @elif op == 0x20 @! local.get
      l_idx = code[pc]
      pc = pc + 1
      @if l_idx < locals.len()
        stack = stack.push(locals[l_idx])
      @else
        stack = stack.push(0)
      @end
    @elif op == 0x21 @! local.set
      l_idx = code[pc]
      pc = pc + 1
      @if stack.len() > 0
        top = stack[stack.len() - 1]
        stack = list_pop(stack)
        locals = list_set(locals, l_idx, top)
      @end
    @elif op == 0x6A || op == 0xA0 @! i32.add / f64.add
      @if stack.len() >= 2
        b = stack[stack.len() - 1]
        stack = list_pop(stack)
        a = stack[stack.len() - 1]
        stack = list_pop(stack)
        stack = stack.push(a + b)
      @end
    @elif op == 0x6B || op == 0xA1 @! i32.sub / f64.sub
      @if stack.len() >= 2
        b = stack[stack.len() - 1]
        stack = list_pop(stack)
        a = stack[stack.len() - 1]
        stack = list_pop(stack)
        stack = stack.push(a - b)
      @end
    @elif op == 0x6C || op == 0xA2 @! i32.mul / f64.mul
      @if stack.len() >= 2
        b = stack[stack.len() - 1]
        stack = list_pop(stack)
        a = stack[stack.len() - 1]
        stack = list_pop(stack)
        stack = stack.push(a * b)
      @end
    @elif op == 0x6D || op == 0xA3 @! i32.div / f64.div
      @if stack.len() >= 2
        b = stack[stack.len() - 1]
        stack = list_pop(stack)
        a = stack[stack.len() - 1]
        stack = list_pop(stack)
        @if b != 0 stack = stack.push(a / b)
        @else stack = stack.push(0) @end
      @end
    @elif op == 0x0F || op == 0x0B @! return / end
      @if stack.len() > 0
        return stack[stack.len() - 1]
      @end
      return 0
    @end
  @end
  
  @if stack.len() > 0
    return stack[stack.len() - 1]
  @end
  return 0
@end
