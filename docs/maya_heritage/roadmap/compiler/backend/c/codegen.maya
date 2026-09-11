@! ============================================================================
@! MAYA COMPILER STAGE 4 — NATIVE C CODE GENERATOR (compiler/backend/c/codegen)
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@fn cgen_expr(expr)
  @if expr == 0
    return "0"
  @end
  
  @if expr.kind == "LiteralInt" || expr.type == "IntLiteral"
    val = expr.val
    @if val == 0 val = expr.value @end
    return val.to_str()
  @elif expr.kind == "LiteralFloat" || expr.type == "FloatLiteral"
    val = expr.val
    @if val == 0 val = expr.value @end
    return val.to_str()
  @elif expr.kind == "LiteralStr" || expr.type == "StringLiteral"
    val = expr.val
    @if val == 0 val = expr.value @end
    return "\"" + val + "\""
  @elif expr.kind == "LiteralBool" || expr.type == "BoolLiteral"
    val = expr.val
    @if val == 0 val = expr.value @end
    @if val == 1 || val == "true" return "1" @end
    return "0"
  @elif expr.kind == "LiteralNone" || expr.type == "NilLiteral"
    return "0"
  @elif expr.kind == "Variable" || expr.type == "Identifier"
    return expr.name
  @elif expr.kind == "UnaryOp"
    return "(" + expr.op + cgen_expr(expr.expr) + ")"
  @elif expr.kind == "BinaryOp" || expr.type == "BinaryOp"
    left_str = cgen_expr(expr.left)
    right_str = cgen_expr(expr.right)
    return "(" + left_str + " " + expr.op + " " + right_str + ")"
  @elif expr.kind == "Call" || expr.type == "Call"
    fname = "func"
    @if expr.func != 0
      @if expr.func.name != 0 fname = expr.func.name
      @else fname = cgen_expr(expr.func) @end
    @elif expr.callee != 0
      @if expr.callee.name != 0 fname = expr.callee.name
      @else fname = cgen_expr(expr.callee) @end
    @end
    
    args_str = ""
    @if expr.args != 0
      i = 0
      len = expr.args.len()
      @while i < len
        @if i > 0 args_str = args_str + ", " @end
        args_str = args_str + cgen_expr(expr.args[i])
        i = i + 1
      @end
    @end
    return fname + "(" + args_str + ")"
  @elif expr.kind == "Index"
    return cgen_expr(expr.target) + "[" + cgen_expr(expr.index) + "]"
  @elif expr.kind == "MemberAccess" || expr.type == "FieldAccess"
    obj_str = cgen_expr(expr.target)
    @if obj_str == "0" obj_str = cgen_expr(expr.obj) @end
    return obj_str + "." + expr.field
  @end
  
  return "0"
@end

@fn cgen_stmt(stmt, indent)
  @if stmt == 0 return "" @end
  
  pad = "  "
  i = 0
  @while i < indent
    pad = pad + "  "
    i = i + 1
  @end
  
  @if stmt.kind == "Assign" || stmt.type == "VarDecl"
    target_name = stmt.name
    @if target_name == 0 || target_name == "none" target_name = stmt.target @end
    val_expr = stmt.expr
    @if val_expr == 0 val_expr = stmt.value @end
    val_str = cgen_expr(val_expr)
    return pad + "int64_t " + target_name + " = " + val_str + ";\n"
  @elif stmt.kind == "Return" || stmt.type == "ReturnStmt"
    val_expr = stmt.value
    @if val_expr == 0 val_expr = stmt.expr @end
    @if val_expr != 0
      return pad + "return " + cgen_expr(val_expr) + ";\n"
    @end
    return pad + "return 0;\n"
  @elif stmt.kind == "ExpressionStmt" || stmt.type == "ExprStmt"
    return pad + cgen_expr(stmt.expr) + ";\n"
  @elif stmt.kind == "IfStmt" || stmt.type == "IfStmt"
    cond_expr = stmt.condition
    @if cond_expr == 0 cond_expr = stmt.cond @end
    out = pad + "if (" + cgen_expr(cond_expr) + ") {\n"
    
    tb = stmt.then_body
    @if tb == 0 tb = stmt.then_branch @end
    @if tb != 0
      @for s in tb
        out = out + cgen_stmt(s, indent + 1)
      @end
    @end
    out = out + pad + "}"
    
    @if stmt.elif_branches != 0
      @for br in stmt.elif_branches
        out = out + " else if (" + cgen_expr(br.cond) + ") {\n"
        @if br.body != 0
          @for s in br.body
            out = out + cgen_stmt(s, indent + 1)
          @end
        @end
        out = out + pad + "}"
      @end
    @end
    
    eb = stmt.else_body
    @if eb == 0 eb = stmt.else_branch @end
    @if eb != 0
      out = out + " else {\n"
      @for s in eb
        out = out + cgen_stmt(s, indent + 1)
      @end
      out = out + pad + "}"
    @end
    out = out + "\n"
    return out
  @elif stmt.kind == "WhileLoop" || stmt.type == "WhileStmt"
    cond_expr = stmt.condition
    @if cond_expr == 0 cond_expr = stmt.cond @end
    out = pad + "while (" + cgen_expr(cond_expr) + ") {\n"
    @if stmt.body != 0
      @for s in stmt.body
        out = out + cgen_stmt(s, indent + 1)
      @end
    @end
    out = out + pad + "}\n"
    return out
  @end
  
  return ""
@end

@fn cgen_function(node)
  fn_name = node.name
  params_str = ""
  @if node.params != 0
    i = 0
    len = node.params.len()
    @while i < len
      pname = node.params[i]
      @if pname.name != 0 pname = pname.name @end
      @if i > 0 params_str = params_str + ", " @end
      params_str = params_str + "int64_t " + pname
      i = i + 1
    @end
  @end
  @if params_str == "" params_str = "void" @end
  
  out = "int64_t " + fn_name + "(" + params_str + ") {\n"
  @if node.body != 0
    @for s in node.body
      out = out + cgen_stmt(s, 0)
    @end
  @end
  out = out + "  return 0;\n"
  out = out + "}\n\n"
  return out
@end

@fn cgen_generate_program(ast_or_mir)
  code = "// ============================================================================\n"
  code = code + "// Native C Source Code generated by Maya Sovereign Compiler (Freestanding Archive)\n"
  code = code + "// ============================================================================\n"
  code = code + "typedef signed long int int64_t;\n"
  code = code + "typedef unsigned long int uint64_t;\n"
  code = code + "typedef int bool;\n\n"
  
  has_funcs = 0
  top_stmts = []
  
  @if ast_or_mir != 0
    @if ast_or_mir.functions != 0
      @for fn_obj in ast_or_mir.functions
        code = code + cgen_function(fn_obj)
        has_funcs = 1
      @end
    @else
      len = ast_or_mir.len()
      i = 0
      @while i < len
        node = ast_or_mir[i]
        @if node.kind == "FnDef" || node.type == "Function"
          code = code + cgen_function(node)
          has_funcs = 1
        @else
          top_stmts = top_stmts.push(node)
        @end
        i = i + 1
      @end
    @end
  @end
  
  @if top_stmts.len() > 0
    code = code + "int main(int argc, char** argv) {\n"
    @for s in top_stmts
      code = code + cgen_stmt(s, 0)
    @end
    code = code + "  return 0;\n"
    code = code + "}\n"
  @elif has_funcs == 0
    code = code + "int main(void) {\n  return 0;\n}\n"
  @end
  
  return code
@end
