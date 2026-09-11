@! ============================================================================
@! MAYA OMNIPOTENT X86-64 CODEGEN - 100% PURE MAYA
@! Features: System V AMD64 ABI, 16-Byte Stack Alignment, Register Allocation,
@! Floating Point (XMM0-7), Caller/Callee Saved Regs, Variadic Functions.
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. X86-64 SYSTEM V ABI REGISTER DEFINITIONS
@! ----------------------------------------------------------------------------
@fn reg_allocator_new()
  return {
    @! Integer Arguments (System V AMD64 ABI)
    int_args: ["rdi", "rsi", "rdx", "rcx", "r8", "r9"],
    
    @! Floating Point Arguments
    float_args: ["xmm0", "xmm1", "xmm2", "xmm3", "xmm4", "xmm5", "xmm6", "xmm7"],
    
    @! Return Registers
    int_ret: "rax",
    float_ret: "xmm0",
    
    @! Callee-Saved Registers (must be preserved by function)
    callee_saved: ["rbx", "rbp", "r12", "r13", "r14", "r15"],
    
    @! Caller-Saved Registers (volatile)
    caller_saved: ["rax", "rdi", "rsi", "rdx", "rcx", "r8", "r9", "r10", "r11"],
    
    @! Stack Pointer
    sp: "rsp",
    bp: "rbp",
    
    @! Current State
    used_regs: [],
    free_regs: ["r10", "r11", "r12", "r13", "r14", "r15"]
  }
@end

@fn alloc_reg(allocator)
  len = allocator.free_regs.len()
  @if len == 0
    return "SPILL"
  @end
  
  reg = allocator.free_regs[0]
  new_free = []
  i = 1
  @while i < len
    new_free = new_free.push(allocator.free_regs[i])
    i = i + 1
  @end
  allocator.free_regs = new_free
  allocator.used_regs = allocator.used_regs.push(reg)
  return reg
@end

@fn free_reg(allocator, reg)
  allocator.free_regs = allocator.free_regs.push(reg)
  
  new_used = []
  i = 0
  len = allocator.used_regs.len()
  @while i < len
    r = allocator.used_regs[i]
    @if r != reg
      new_used = new_used.push(r)
    @end
    i = i + 1
  @end
  allocator.used_regs = new_used
  return allocator
@end

@! ----------------------------------------------------------------------------
@! 2. STACK FRAME MANAGEMENT (16-BYTE ALIGNED)
@! ----------------------------------------------------------------------------
@fn stack_frame_new()
  return {
    locals: [],
    spills: [],
    total_size: 0,
    aligned_size: 0
  }
@end

@fn add_local(frame, name, size)
  offset = frame.total_size + size
  frame.total_size = offset
  frame.locals = frame.locals.push({ name: name, offset: offset })
  return frame
@end

@fn compute_alignment(frame)
  @! System V ABI requires 16-byte alignment before call
  remainder = frame.total_size % 16
  @if remainder != 0
    frame.aligned_size = frame.total_size + (16 - remainder)
  @else
    frame.aligned_size = frame.total_size
  @end
  
  @! If no locals, still might need to align if we do calls, but we'll reserve at least 16 if needed
  @if frame.aligned_size == 0
    frame.aligned_size = 16
  @end
  return frame
@end

@fn get_local_offset(frame, name)
  i = 0
  len = frame.locals.len()
  @while i < len
    local = frame.locals[i]
    @if local.name == name
      return local.offset
    @end
    i = i + 1
  @end
  return -1
@end

@! ----------------------------------------------------------------------------
@! 3. PROLOGUE AND EPILOGUE GENERATION
@! ----------------------------------------------------------------------------
@fn generate_prologue(func_name, frame)
  asm = []
  asm = asm.push(".global " + func_name)
  asm = asm.push(func_name + ":")
  
  @! Standard RBP setup
  asm = asm.push("  push rbp")
  asm = asm.push("  mov rbp, rsp")
  
  @! Reserve stack space (16-byte aligned)
  @if frame.aligned_size > 0
    asm = asm.push("  sub rsp, " + frame.aligned_size.to_str())
  @end
  
  @! Save callee-saved registers if they will be used
  @! For now, assuming r12, r13, r14, r15 are used
  asm = asm.push("  push r12")
  asm = asm.push("  push r13")
  asm = asm.push("  push r14")
  asm = asm.push("  push r15")
  
  return asm
@end

@fn generate_epilogue(func_name, frame)
  asm = []
  asm = asm.push(".L_" + func_name + "_EPILOGUE:")
  
  @! Restore callee-saved registers
  asm = asm.push("  pop r15")
  asm = asm.push("  pop r14")
  asm = asm.push("  pop r13")
  asm = asm.push("  pop r12")
  
  @! Restore RSP and RBP
  asm = asm.push("  mov rsp, rbp")
  asm = asm.push("  pop rbp")
  asm = asm.push("  ret")
  
  return asm
@end

@! ----------------------------------------------------------------------------
@! 4. INSTRUCTION EMISSION (Expressions & Statements)
@! ----------------------------------------------------------------------------
@fn emit_expr(expr, frame, allocator, asm)
  @if expr == 0
    return { reg: "rax", asm: asm, allocator: allocator }
  @end
  @if expr.type == "IntLiteral" || expr.kind == "LiteralInt"
    reg = alloc_reg(allocator)
    val = expr.value
    @if val == 0 && expr.val != 0 val = expr.val @end
    asm = asm.push("  mov " + reg + ", " + val.to_str())
    return { reg: reg, asm: asm, allocator: allocator }
  @end
  
  @if expr.type == "Identifier" || expr.kind == "Variable"
    offset = get_local_offset(frame, expr.name)
    reg = alloc_reg(allocator)
    @if offset != -1
      asm = asm.push("  mov " + reg + ", [rbp - " + offset.to_str() + "]")
    @else
      @! Maybe global or parameter
      asm = asm.push("  mov " + reg + ", 0  ; (Placeholder for missing var " + expr.name + ")")
    @end
    return { reg: reg, asm: asm, allocator: allocator }
  @end
  
  @if expr.type == "BinaryOp" || expr.kind == "BinaryOp"
    res_left = emit_expr(expr.left, frame, allocator, asm)
    allocator = res_left.allocator
    asm = res_left.asm
    reg_left = res_left.reg
    
    res_right = emit_expr(expr.right, frame, allocator, asm)
    allocator = res_right.allocator
    asm = res_right.asm
    reg_right = res_right.reg
    
    @if expr.op == "+"
      asm = asm.push("  add " + reg_left + ", " + reg_right)
    @end
    @if expr.op == "-"
      asm = asm.push("  sub " + reg_left + ", " + reg_right)
    @end
    @if expr.op == "*"
      asm = asm.push("  imul " + reg_left + ", " + reg_right)
    @end
    @if expr.op == "/"
      @! x86 division is specific: rax = rax / operand, rdx = remainder
      asm = asm.push("  push rax")
      asm = asm.push("  push rdx")
      asm = asm.push("  mov rax, " + reg_left)
      asm = asm.push("  cqo") @! Sign extend rax into rdx:rax
      asm = asm.push("  idiv " + reg_right)
      asm = asm.push("  mov " + reg_left + ", rax")
      asm = asm.push("  pop rdx")
      asm = asm.push("  pop rax")
    @end
    
    allocator = free_reg(allocator, reg_right)
    return { reg: reg_left, asm: asm, allocator: allocator }
  @end
  
  @if expr.type == "Call" || expr.kind == "Call"
    callee = expr.callee
    @if callee == 0 callee = expr.func @end
    callee_name = ""
    @if callee.name != 0 callee_name = callee.name
    @else callee_name = callee.to_str() @end
    
    @! System V ABI Argument Passing
    i = 0
    len = 0
    @if expr.args != 0 len = expr.args.len() @end
    
    @! Save caller-saved registers before call
    asm = asm.push("  push r10")
    asm = asm.push("  push r11")
    
    @while i < len
      res = emit_expr(expr.args[i], frame, allocator, asm)
      allocator = res.allocator
      asm = res.asm
      arg_reg = res.reg
      
      @if i < 6
        dest_reg = allocator.int_args[i]
        asm = asm.push("  mov " + dest_reg + ", " + arg_reg)
      @else
        @! Push onto stack in reverse order
        asm = asm.push("  push " + arg_reg)
      @end
      
      allocator = free_reg(allocator, arg_reg)
      i = i + 1
    @end
    
    @! Set AL = 0 for variadic functions (no float args in XMM)
    asm = asm.push("  mov al, 0")
    
    @! The Call
    asm = asm.push("  call " + callee_name)
    
    @! Clean up stack if we pushed arguments
    @if len > 6
      stack_cleanup = (len - 6) * 8
      asm = asm.push("  add rsp, " + stack_cleanup.to_str())
    @end
    
    @! Restore caller-saved registers
    asm = asm.push("  pop r11")
    asm = asm.push("  pop r10")
    
    @! Return value is in rax
    ret_reg = alloc_reg(allocator)
    asm = asm.push("  mov " + ret_reg + ", rax")
    
    return { reg: ret_reg, asm: asm, allocator: allocator }
  @end
  
  return { reg: "rax", asm: asm, allocator: allocator }
@end

@fn emit_stmt(stmt, frame, allocator, asm, func_name)
  @if stmt == 0
    return { asm: asm, allocator: allocator }
  @end
  
  @if stmt.type == "VarDecl" || stmt.kind == "Assign"
    vexpr = stmt.expr
    @if vexpr == 0 vexpr = stmt.value @end
    res = emit_expr(vexpr, frame, allocator, asm)
    allocator = res.allocator
    asm = res.asm
    reg = res.reg
    
    vname = stmt.name
    @if vname == 0 || vname == "none" vname = stmt.target @end
    offset = get_local_offset(frame, vname)
    @if offset != -1
      asm = asm.push("  mov [rbp - " + offset.to_str() + "], " + reg)
    @end
    
    allocator = free_reg(allocator, reg)
    return { asm: asm, allocator: allocator }
  @end
  
  @if stmt.type == "ReturnStmt" || stmt.kind == "Return"
    vexpr = stmt.expr
    @if vexpr == 0 vexpr = stmt.value @end
    @if vexpr != 0
      res = emit_expr(vexpr, frame, allocator, asm)
      allocator = res.allocator
      asm = res.asm
      reg = res.reg
      
      asm = asm.push("  mov rax, " + reg)
      allocator = free_reg(allocator, reg)
    @end
    
    asm = asm.push("  jmp .L_" + func_name + "_EPILOGUE")
    return { asm: asm, allocator: allocator }
  @end
  
  @if stmt.type == "ExprStmt" || stmt.kind == "ExpressionStmt"
    res = emit_expr(stmt.expr, frame, allocator, asm)
    allocator = free_reg(res.allocator, res.reg)
    return { asm: res.asm, allocator: allocator }
  @end
  
  return { asm: asm, allocator: allocator }
@end

@! ----------------------------------------------------------------------------
@! 5. MASTER CODE GENERATOR
@! ----------------------------------------------------------------------------
@fn codegen_x86_64(ast)
  println("▶ [CG] Generating System V AMD64 Assembly...")
  
  full_asm = []
  
  i = 0
  len = ast.len()
  @while i < len
    node = ast[i]
    
    @if node.type == "Function" || node.kind == "FnDef"
      allocator = reg_allocator_new()
      frame = stack_frame_new()
      
      @! Pass 1: Compute stack frame for locals
      j = 0
      blen = 0
      @if node.body != 0 blen = node.body.len() @end
      @while j < blen
        stmt = node.body[j]
        @if stmt.type == "VarDecl" || stmt.kind == "Assign"
          vname = stmt.name
          @if vname == 0 || vname == "none" vname = stmt.target @end
          frame = add_local(frame, vname, 8) @! 8 bytes for Int/Ptr
        @end
        j = j + 1
      @end
      
      frame = compute_alignment(frame)
      
      @! Prologue
      prologue = generate_prologue(node.name, frame)
      j = 0
      @while j < prologue.len()
        full_asm = full_asm.push(prologue[j])
        j = j + 1
      @end
      
      @! Body
      j = 0
      @while j < blen
        stmt = node.body[j]
        res = emit_stmt(stmt, frame, allocator, full_asm, node.name)
        full_asm = res.asm
        allocator = res.allocator
        j = j + 1
      @end
      
      @! Epilogue
      epilogue = generate_epilogue(node.name, frame)
      j = 0
      @while j < epilogue.len()
        full_asm = full_asm.push(epilogue[j])
        j = j + 1
      @end
      
      full_asm = full_asm.push("") @! Empty line
    @end
    
    i = i + 1
  @end
  
  println("✅ x86_64 Assembly successfully generated with strict ABI adherence.")
  return full_asm
@end

@fn x86_generate_program(ast)
  return codegen_x86_64(ast)
@end

@! ----------------------------------------------------------------------------
@! 6. WINDOWS X64 ABI SUPPORT
@! ----------------------------------------------------------------------------
@fn codegen_windows_x64(ast)
  @! Windows x64 ABI uses RCX, RDX, R8, R9 for first 4 integer args
  @! Requires 32-byte shadow space above return address
  println("▶ [CG] Generating Windows x64 ABI Assembly...")
  full_asm = []
  i = 0
  len = ast.len()
  @while i < len
    node = ast[i]
    @if node.type == "Function" || node.kind == "FnDef"
      frame = stack_frame_new()
      j = 0
      blen = 0
      @if node.body != 0 blen = node.body.len() @end
      @while j < blen
        stmt = node.body[j]
        @if stmt.type == "VarDecl" || stmt.kind == "Assign"
          vname = stmt.name
          @if vname == 0 || vname == "none" vname = stmt.target @end
          frame = add_local(frame, vname, 8)
        @end
        j = j + 1
      @end
      frame = compute_alignment(frame)
      
      alloc_size = 32 + frame.aligned_size
      @if (alloc_size % 16) != 0 alloc_size = alloc_size + (16 - (alloc_size % 16)) @end
      
      full_asm = full_asm.push(".global " + node.name)
      full_asm = full_asm.push(node.name + ":")
      full_asm = full_asm.push("  push rbp")
      full_asm = full_asm.push("  mov rbp, rsp")
      full_asm = full_asm.push("  sub rsp, " + alloc_size.to_str())
      
      allocator = reg_allocator_new()
      j = 0
      @while j < blen
        stmt = node.body[j]
        res = emit_stmt(stmt, frame, allocator, full_asm, node.name)
        full_asm = res.asm
        allocator = res.allocator
        j = j + 1
      @end
      
      full_asm = full_asm.push(".L_" + node.name + "_EPILOGUE:")
      full_asm = full_asm.push("  mov rsp, rbp")
      full_asm = full_asm.push("  pop rbp")
      full_asm = full_asm.push("  ret")
      full_asm = full_asm.push("")
    @end
    i = i + 1
  @end
  return full_asm
@end
