@! ============================================================================
@! MAYA COMPILER STAGE 3 — WEBASSEMBLY (WASM) GENERATOR
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! Converts a Maya MIR (Mid-Level IR) or AST program to WASM Text Format (WAT)
@fn mir_to_wasm_wat(mir_prog)
  wat_code = "(module\n"
  wat_code = wat_code + "  (memory (export \"memory\") 1)\n"

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
    @! Fallback minimal module with main
    wat_code = wat_code + "  (func $main (result f64)\n"
    wat_code = wat_code + "    f64.const 0.0\n"
    wat_code = wat_code + "    return\n"
    wat_code = wat_code + "  )\n"
    wat_code = wat_code + "  (export \"main\" (func $main))\n"
    wat_code = wat_code + ")\n"
    return wat_code
  @end

  @for fn_obj in funcs
    fn_name = fn_obj.name
    
    wat_code = wat_code + "  (func $" + fn_name
    
    @if fn_obj.params != 0
      @for param in fn_obj.params
        pname = param
        @if param.name != 0 pname = param.name @end
        wat_code = wat_code + " (param $" + pname + " f64)"
      @end
    @end
    
    wat_code = wat_code + " (result f64)\n"

    @! Declare locals for temps/instructions
    @if fn_obj.instructions != 0
      @for inst in fn_obj.instructions
        @if inst.op == "CONST_INT" || inst.op == "CONST_FLOAT" || inst.op == "BINOP" || inst.op == "CALL"
          @if inst.dest != ""
            wat_code = wat_code + "    (local " + inst.dest + " f64)\n"
          @end
        @end
      @end

      @for inst in fn_obj.instructions
        @if inst.op == "CONST_INT" || inst.op == "CONST_FLOAT"
          wat_code = wat_code + "    f64.const " + inst.val.to_str() + "\n"
          wat_code = wat_code + "    local.set " + inst.dest + "\n"
        @elif inst.op == "ASSIGN"
          wat_code = wat_code + "    local.get " + inst.src + "\n"
          wat_code = wat_code + "    local.set $" + inst.dest + "\n"
        @elif inst.op == "BINOP"
          wat_code = wat_code + "    local.get " + inst.left + "\n"
          wat_code = wat_code + "    local.get " + inst.right + "\n"
          
          @if inst.binop == "+"
            wat_code = wat_code + "    f64.add\n"
          @elif inst.binop == "-"
            wat_code = wat_code + "    f64.sub\n"
          @elif inst.binop == "*"
            wat_code = wat_code + "    f64.mul\n"
          @elif inst.binop == "/"
            wat_code = wat_code + "    f64.div\n"
          @elif inst.binop == "=="
            wat_code = wat_code + "    f64.eq\n"
          @elif inst.binop == "<"
            wat_code = wat_code + "    f64.lt\n"
          @elif inst.binop == ">"
            wat_code = wat_code + "    f64.gt\n"
          @else
            wat_code = wat_code + "    f64.add\n"
          @end
          wat_code = wat_code + "    local.set " + inst.dest + "\n"
        @elif inst.op == "CALL"
          @for arg in inst.args
            wat_code = wat_code + "    local.get " + arg + "\n"
          @end
          wat_code = wat_code + "    call $" + inst.func + "\n"
          wat_code = wat_code + "    local.set " + inst.dest + "\n"
        @elif inst.op == "RETURN"
          wat_code = wat_code + "    local.get " + inst.val + "\n"
          wat_code = wat_code + "    return\n"
        @end
      @end
    @end
    
    wat_code = wat_code + "    f64.const 0.0\n"
    wat_code = wat_code + "    return\n"
    wat_code = wat_code + "  )\n"
    
    @if fn_name == "main"
      wat_code = wat_code + "  (export \"main\" (func $main))\n"
    @end
  @end

  wat_code = wat_code + ")\n"
  return wat_code
@end

@fn wasm_generate_program(mir_prog)
  return mir_to_wasm_wat(mir_prog)
@end
