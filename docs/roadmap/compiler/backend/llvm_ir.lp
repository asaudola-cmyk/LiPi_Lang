@! ============================================================================
@! MAYA COMPILER STAGE 3 — LLVM IR GENERATOR
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! Converts a Maya MIR (Mid-Level IR) or AST program to LLVM IR textual representation.
@fn mir_to_llvm_ir(mir_prog)
  llvm_code = "; ModuleID = 'Maya_Core'\n"
  llvm_code = llvm_code + "source_filename = \"maya_program\"\n\n"

  funcs = []
  @if mir_prog != 0
    @if mir_prog.functions != 0
      funcs = mir_prog.functions
    @else
      len = mir_prog.len()
      i = 0
      @while i < len
        node = mir_prog[i]
        @if node.kind == "FnDef" || node.type == "Function"
          funcs = funcs.push(node)
        @end
        i = i + 1
      @end
    @end
  @end

  @if funcs.len() == 0
    llvm_code = llvm_code + "define i64 @main() {\nentry:\n  ret i64 0\n}\n"
    return llvm_code
  @end

  @for fn_obj in funcs
    fn_name = fn_obj.name
    @if fn_name == "main"
      llvm_code = llvm_code + "define i64 @main() {\n"
      llvm_code = llvm_code + "entry:\n"
    @else
      llvm_code = llvm_code + "define double @" + fn_name + "("
      idx = 0
      @if fn_obj.params != 0
        @for param in fn_obj.params
          pname = param
          @if param.name != 0 pname = param.name @end
          @if idx > 0
            llvm_code = llvm_code + ", "
          @end
          llvm_code = llvm_code + "double %" + pname
          idx = idx + 1
        @end
      @end
      llvm_code = llvm_code + ") {\n"
      llvm_code = llvm_code + "entry:\n"
    @end

    @if fn_obj.instructions != 0
      @for inst in fn_obj.instructions
        @if inst.op == "CONST_INT"
          llvm_code = llvm_code + "  " + inst.dest + " = fadd double 0.0, " + inst.val.to_str() + ".0\n"
        @elif inst.op == "CONST_FLOAT"
          llvm_code = llvm_code + "  " + inst.dest + " = fadd double 0.0, " + inst.val.to_str() + "\n"
        @elif inst.op == "CONST_STR"
          llvm_code = llvm_code + "  " + inst.dest + " = inttoptr i64 0 to i8*\n"
        @elif inst.op == "ASSIGN"
          llvm_code = llvm_code + "  " + "%" + inst.dest + " = fadd double 0.0, " + inst.src + "\n"
        @elif inst.op == "BINOP"
          op_str = ""
          @if inst.binop == "+"
            op_str = "fadd"
          @elif inst.binop == "-"
            op_str = "fsub"
          @elif inst.binop == "*"
            op_str = "fmul"
          @elif inst.binop == "/"
            op_str = "fdiv"
          @elif inst.binop == "=="
            op_str = "fcmp oeq"
          @elif inst.binop == "<"
            op_str = "fcmp olt"
          @elif inst.binop == ">"
            op_str = "fcmp ogt"
          @else
            op_str = "fadd"
          @end
          
          llvm_code = llvm_code + "  " + inst.dest + " = " + op_str + " double " + inst.left + ", " + inst.right + "\n"
          
          @if inst.binop == "==" || inst.binop == "<" || inst.binop == ">"
            llvm_code = llvm_code + "  " + inst.dest + "_dbl = uitofp i1 " + inst.dest + " to double\n"
          @end
        @elif inst.op == "CALL"
          llvm_code = llvm_code + "  " + inst.dest + " = call double @" + inst.func + "("
          a_idx = 0
          @if inst.args != 0
            @for arg in inst.args
              @if a_idx > 0
                llvm_code = llvm_code + ", "
              @end
              llvm_code = llvm_code + "double " + arg
              a_idx = a_idx + 1
            @end
          @end
          llvm_code = llvm_code + ")\n"
        @elif inst.op == "RETURN"
          @if fn_name == "main"
            llvm_code = llvm_code + "  %ret_int_" + inst.val + " = fptoui double " + inst.val + " to i64\n"
            llvm_code = llvm_code + "  ret i64 %ret_int_" + inst.val + "\n"
          @else
            llvm_code = llvm_code + "  ret double " + inst.val + "\n"
          @end
        @elif inst.op == "LABEL"
          llvm_code = llvm_code + inst.label + ":\n"
        @elif inst.op == "JUMP"
          llvm_code = llvm_code + "  br label %" + inst.target + "\n"
        @elif inst.op == "CONDBR"
          llvm_code = llvm_code + "  %cond_i1_" + inst.cond + " = fcmp one double " + inst.cond + ", 0.0\n"
          llvm_code = llvm_code + "  br i1 %cond_i1_" + inst.cond + ", label %" + inst.then_lbl + ", label %" + inst.else_lbl + "\n"
        @end
      @end
    @end
    
    @if fn_name == "main"
      llvm_code = llvm_code + "  ret i64 0\n"
    @else
      llvm_code = llvm_code + "  ret double 0.0\n"
    @end
    
    llvm_code = llvm_code + "}\n\n"
  @end

  return llvm_code
@end

@fn llvm_generate_program(mir_prog)
  return mir_to_llvm_ir(mir_prog)
@end
