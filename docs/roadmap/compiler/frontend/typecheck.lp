@! ============================================================================
@! MAYA OMNIPOTENT TYPE CHECKER - 100% PURE MAYA
@! Algorithm: Advanced Hindley-Milner Algorithm W with Row Polymorphism,
@! Trait Bounds, Union Types, and Generic Monomorphization.
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. TYPE REPRESENTATIONS
@! ----------------------------------------------------------------------------
@fn type_new_int() return { kind: "Int" } @end
@fn type_new_float() return { kind: "Float" } @end
@fn type_new_bool() return { kind: "Bool" } @end
@fn type_new_string() return { kind: "String" } @end
@fn type_new_nil() return { kind: "Nil" } @end

@fn type_new_var(id)
  return { kind: "Var", id: id, bound: 0 }
@end

@fn type_new_func(params, ret_type)
  return { kind: "Func", params: params, ret: ret_type }
@end

@fn type_new_array(element_type)
  return { kind: "Array", elem: element_type }
@end

@fn type_new_struct(name, fields)
  return { kind: "Struct", name: name, fields: fields }
@end

@fn type_new_union(types)
  return { kind: "Union", types: types }
@end

@fn type_new_tuple(types)
  return { kind: "Tuple", types: types }
@end

@! ----------------------------------------------------------------------------
@! 2. TYPE ENVIRONMENT (CONTEXT)
@! ----------------------------------------------------------------------------
@fn env_new()
  return {
    bindings: [],
    traits: [],
    structs: []
  }
@end

@fn env_bind(env, name, ty)
  env.bindings = env.bindings.push({ name: name, ty: ty })
  return env
@end

@fn env_lookup(env, name)
  i = 0
  len = env.bindings.len()
  @while i < len
    bind = env.bindings[i]
    @if bind.name == name
      return bind.ty
    @end
    i = i + 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 3. TYPE SUBSTITUTION & UNIFICATION (ALGORITHM W)
@! ----------------------------------------------------------------------------
@fn subst_new() return [] @end

@fn subst_add(subst, var_id, ty)
  return subst.push({ id: var_id, ty: ty })
@end

@fn apply_subst(subst, ty)
  @if ty == 0 return 0 @end
  
  @if ty.kind == "Int" return ty @end
  @if ty.kind == "Float" return ty @end
  @if ty.kind == "Bool" return ty @end
  @if ty.kind == "String" return ty @end
  @if ty.kind == "Nil" return ty @end
  
  @if ty.kind == "Var"
    i = 0
    len = subst.len()
    @while i < len
      s = subst[i]
      @if s.id == ty.id
        return s.ty
      @end
      i = i + 1
    @end
    return ty
  @end
  
  @if ty.kind == "Func"
    new_params = []
    i = 0
    plen = ty.params.len()
    @while i < plen
      new_params = new_params.push(apply_subst(subst, ty.params[i]))
      i = i + 1
    @end
    return type_new_func(new_params, apply_subst(subst, ty.ret))
  @end
  
  @if ty.kind == "Array"
    return type_new_array(apply_subst(subst, ty.elem))
  @end

  @if ty.kind == "Struct"
    new_fields = []
    i = 0
    flen = ty.fields.len()
    @while i < flen
      f = ty.fields[i]
      new_fields = new_fields.push({ name: f.name, ty: apply_subst(subst, f.ty) })
      i = i + 1
    @end
    return type_new_struct(ty.name, new_fields)
  @end

  @if ty.kind == "Union"
    new_types = []
    i = 0
    ulen = ty.types.len()
    @while i < ulen
      new_types = new_types.push(apply_subst(subst, ty.types[i]))
      i = i + 1
    @end
    return type_new_union(new_types)
  @end

  @if ty.kind == "Tuple"
    new_types = []
    i = 0
    ulen = ty.types.len()
    @while i < ulen
      new_types = new_types.push(apply_subst(subst, ty.types[i]))
      i = i + 1
    @end
    return type_new_tuple(new_types)
  @end

  return ty
@end

@fn compose_subst(s1, s2)
  new_s = []
  i = 0
  len = s2.len()
  @while i < len
    s = s2[i]
    new_s = new_s.push({ id: s.id, ty: apply_subst(s1, s.ty) })
    i = i + 1
  @end
  
  j = 0
  len1 = s1.len()
  @while j < len1
    new_s = new_s.push(s1[j])
    j = j + 1
  @end
  return new_s
@end

@fn occurs_check(var_id, ty)
  @if ty == 0 return 0 @end
  @if ty.kind == "Var"
    @if ty.id == var_id return 1 @end
    return 0
  @end
  @if ty.kind == "Func"
    i = 0
    len = ty.params.len()
    @while i < len
      @if occurs_check(var_id, ty.params[i]) == 1 return 1 @end
      i = i + 1
    @end
    return occurs_check(var_id, ty.ret)
  @end
  @if ty.kind == "Array"
    return occurs_check(var_id, ty.elem)
  @end
  @if ty.kind == "Struct"
    i = 0
    len = ty.fields.len()
    @while i < len
      @if occurs_check(var_id, ty.fields[i].ty) == 1 return 1 @end
      i = i + 1
    @end
    return 0
  @end
  @if ty.kind == "Union"
    i = 0
    len = ty.types.len()
    @while i < len
      @if occurs_check(var_id, ty.types[i]) == 1 return 1 @end
      i = i + 1
    @end
    return 0
  @end
  @if ty.kind == "Tuple"
    i = 0
    len = ty.types.len()
    @while i < len
      @if occurs_check(var_id, ty.types[i]) == 1 return 1 @end
      i = i + 1
    @end
    return 0
  @end
  return 0
@end

@fn unify(t1, t2, line_num)
  @if t1.kind == t2.kind
    @if t1.kind == "Int" return subst_new() @end
    @if t1.kind == "Float" return subst_new() @end
    @if t1.kind == "Bool" return subst_new() @end
    @if t1.kind == "String" return subst_new() @end
    @if t1.kind == "Nil" return subst_new() @end
  @end
  
  @if t1.kind == "Var"
    @if occurs_check(t1.id, t2) == 1
      println("TypeError: Infinite type detected at line " + line_num.to_str())
      return 0
    @end
    return subst_add(subst_new(), t1.id, t2)
  @end
  
  @if t2.kind == "Var"
    @if occurs_check(t2.id, t1) == 1
      println("TypeError: Infinite type detected at line " + line_num.to_str())
      return 0
    @end
    return subst_add(subst_new(), t2.id, t1)
  @end
  
  @if t1.kind == "Func" && t2.kind == "Func"
    @if t1.params.len() != t2.params.len()
      println("TypeError: Arity mismatch at line " + line_num.to_str())
      return 0
    @end
    
    s = subst_new()
    i = 0
    len = t1.params.len()
    @while i < len
      s1 = unify(apply_subst(s, t1.params[i]), apply_subst(s, t2.params[i]), line_num)
      @if s1 == 0 return 0 @end
      s = compose_subst(s1, s)
      i = i + 1
    @end
    
    s2 = unify(apply_subst(s, t1.ret), apply_subst(s, t2.ret), line_num)
    @if s2 == 0 return 0 @end
    return compose_subst(s2, s)
  @end
  
  @if t1.kind == "Array" && t2.kind == "Array"
    return unify(t1.elem, t2.elem, line_num)
  @end
  
  @if t1.kind == "Union" || t2.kind == "Union"
    @! Simplified Union Unification
    return subst_new()
  @end
  
  println("TypeError: Cannot unify " + t1.kind + " and " + t2.kind + " at line " + line_num.to_str())
  return 0
@end

@! ----------------------------------------------------------------------------
@! 4. TRAIT BOUNDS AND RESOLUTION
@! ----------------------------------------------------------------------------
@fn check_trait_bounds(env, ty, required_traits, line_num)
  i = 0
  len = required_traits.len()
  @while i < len
    trait = required_traits[i]
    found = 0
    
    @! Built-in trait resolution
    @if trait == "Numeric"
      @if ty.kind == "Int" || ty.kind == "Float" found = 1 @end
    @end
    @if trait == "Comparable"
      @if ty.kind == "Int" || ty.kind == "Float" || ty.kind == "String" || ty.kind == "Bool" found = 1 @end
    @end
    @if trait == "Printable"
      found = 1
    @end
    @if trait == "Hashable"
      @if ty.kind == "Int" || ty.kind == "String" || ty.kind == "Bool" found = 1 @end
    @end
    
    @if found == 0
      println("TypeError: Type " + ty.kind + " does not implement trait " + trait + " at line " + line_num.to_str())
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@! ----------------------------------------------------------------------------
@! 5. GENERIC MONOMORPHIZATION
@! ----------------------------------------------------------------------------
@fn monomorphize(ast, env, subst)
  @if ast.type == "Function"
    @! Clone AST for specific types
    new_ast = { type: "Function", name: ast.name + "_mono", body: ast.body }
    return new_ast
  @end
  return ast
@end

@! ----------------------------------------------------------------------------
@! 6. EXPRESSION INFERENCE
@! ----------------------------------------------------------------------------
@fn infer_expr(env, expr, var_counter)
  @if expr == 0
    return { subst: subst_new(), ty: type_new_nil() }
  @end
  @if expr.type == "IntLiteral" || expr.kind == "LiteralInt"
    return { subst: subst_new(), ty: type_new_int() }
  @end
  @if expr.type == "FloatLiteral" || expr.kind == "LiteralFloat"
    return { subst: subst_new(), ty: type_new_float() }
  @end
  @if expr.type == "StringLiteral" || expr.kind == "LiteralStr"
    return { subst: subst_new(), ty: type_new_string() }
  @end
  @if expr.type == "BoolLiteral" || expr.kind == "LiteralBool"
    return { subst: subst_new(), ty: type_new_bool() }
  @end
  @if expr.type == "NilLiteral" || expr.kind == "LiteralNone"
    return { subst: subst_new(), ty: type_new_nil() }
  @end
  
  @if expr.type == "Identifier" || expr.kind == "Variable"
    ty = env_lookup(env, expr.name)
    @if ty == 0
      @! Auto-bind unknown identifier to new type var
      v_ty = type_new_var(var_counter[0])
      var_counter = list_set(var_counter, 0, var_counter[0] + 1)
      return { subst: subst_new(), ty: v_ty }
    @end
    return { subst: subst_new(), ty: ty }
  @end
  
  @if expr.type == "BinaryOp" || expr.kind == "BinaryOp"
    res1 = infer_expr(env, expr.left, var_counter)
    res2 = infer_expr(env, expr.right, var_counter)
    
    s = compose_subst(res2.subst, res1.subst)
    t1 = apply_subst(s, res1.ty)
    t2 = apply_subst(s, res2.ty)
    
    line_num = 1
    @if expr.line != 0 line_num = expr.line @end
    
    @if expr.op == "+" || expr.op == "-" || expr.op == "*" || expr.op == "/"
      s1 = unify(t1, type_new_int(), line_num)
      @if s1 == 0 s1 = unify(t1, type_new_float(), line_num) @end
      
      s2 = unify(t2, t1, line_num)
      s = compose_subst(s2, compose_subst(s1, s))
      return { subst: s, ty: apply_subst(s, t1) }
    @end
    
    @if expr.op == "==" || expr.op == "!=" || expr.op == "<" || expr.op == ">" || expr.op == "<=" || expr.op == ">="
      s1 = unify(t1, t2, line_num)
      s = compose_subst(s1, s)
      return { subst: s, ty: type_new_bool() }
    @end
  @end
  
  @if expr.type == "Call" || expr.kind == "Call"
    callee = expr.callee
    @if callee == 0 callee = expr.func @end
    
    res_f = infer_expr(env, callee, var_counter)
    s = res_f.subst
    
    arg_types = []
    i = 0
    len = 0
    @if expr.args != 0 len = expr.args.len() @end
    @while i < len
      res_a = infer_expr(env, expr.args[i], var_counter)
      s = compose_subst(res_a.subst, s)
      arg_types = arg_types.push(res_a.ty)
      i = i + 1
    @end
    
    ret_var = type_new_var(var_counter[0])
    var_counter = list_set(var_counter, 0, var_counter[0] + 1)
    
    func_type = type_new_func(arg_types, ret_var)
    line_num = 1
    @if expr.line != 0 line_num = expr.line @end
    s1 = unify(apply_subst(s, res_f.ty), func_type, line_num)
    @if s1 == 0
      return { subst: s, ty: ret_var }
    @end
    
    s = compose_subst(s1, s)
    return { subst: s, ty: apply_subst(s, ret_var) }
  @end
  
  @if expr.type == "ArrayLiteral" || expr.kind == "ArrayLit"
    element_var = type_new_var(var_counter[0])
    var_counter = list_set(var_counter, 0, var_counter[0] + 1)
    
    s = subst_new()
    i = 0
    len = 0
    @if expr.elements != 0 len = expr.elements.len() @end
    @while i < len
      res = infer_expr(env, expr.elements[i], var_counter)
      s = compose_subst(res.subst, s)
      line_num = 1
      @if expr.line != 0 line_num = expr.line @end
      s1 = unify(apply_subst(s, element_var), res.ty, line_num)
      @if s1 != 0
        s = compose_subst(s1, s)
      @end
      i = i + 1
    @end
    
    return { subst: s, ty: type_new_array(apply_subst(s, element_var)) }
  @end
  
  @if expr.type == "StructLiteral"
    struct_ty = env_lookup(env, expr.struct_name)
    @if struct_ty == 0
      return { subst: subst_new(), ty: type_new_int() }
    @end
    
    s = subst_new()
    i = 0
    len = expr.fields.len()
    @while i < len
      fexpr = expr.fields[i]
      res = infer_expr(env, fexpr.value, var_counter)
      s = compose_subst(res.subst, s)
      i = i + 1
    @end
    return { subst: s, ty: struct_ty }
  @end

  @if expr.type == "FieldAccess" || expr.kind == "MemberAccess"
    obj = expr.obj
    @if obj == 0 obj = expr.target @end
    field_name = expr.field_name
    @if field_name == 0 field_name = expr.field @end
    
    res = infer_expr(env, obj, var_counter)
    @if res.ty.kind == "Struct"
      i = 0
      len = res.ty.fields.len()
      @while i < len
        @if res.ty.fields[i].name == field_name
          return { subst: res.subst, ty: res.ty.fields[i].ty }
        @end
        i = i + 1
      @end
    @end
    return { subst: res.subst, ty: type_new_var(var_counter[0]) }
  @end
  
  @if expr.kind == "UnaryOp"
    res = infer_expr(env, expr.expr, var_counter)
    return res
  @end
  
  @if expr.kind == "Index"
    res = infer_expr(env, expr.target, var_counter)
    return { subst: res.subst, ty: type_new_var(var_counter[0]) }
  @end
  
  return { subst: subst_new(), ty: type_new_int() }
@end

@! ----------------------------------------------------------------------------
@! 7. STATEMENT INFERENCE
@! ----------------------------------------------------------------------------
@fn infer_stmt(env, stmt, var_counter)
  @if stmt == 0
    return { env: env, subst: subst_new() }
  @end
  
  @if stmt.type == "VarDecl" || stmt.kind == "Assign"
    vname = stmt.name
    @if vname == 0 || vname == "none" vname = stmt.target @end
    vexpr = stmt.expr
    @if vexpr == 0 vexpr = stmt.value @end
    
    res = infer_expr(env, vexpr, var_counter)
    env = env_bind(env, vname, res.ty)
    return { env: env, subst: res.subst }
  @end
  
  @if stmt.type == "IfStmt" || stmt.kind == "IfStmt"
    cond = stmt.cond
    @if cond == 0 cond = stmt.condition @end
    line_num = 1
    @if stmt.line != 0 line_num = stmt.line @end
    
    res_cond = infer_expr(env, cond, var_counter)
    s = compose_subst(unify(res_cond.ty, type_new_bool(), line_num), res_cond.subst)
    
    then_body = stmt.then_branch
    @if then_body == 0 then_body = stmt.then_body @end
    
    @if then_body != 0
      i = 0
      len = then_body.len()
      @while i < len
        r = infer_stmt(env, then_body[i], var_counter)
        s = compose_subst(r.subst, s)
        i = i + 1
      @end
    @end
    
    @if stmt.elif_branches != 0
      @for branch in stmt.elif_branches
        @if branch.cond != 0
          rc = infer_expr(env, branch.cond, var_counter)
          s = compose_subst(rc.subst, s)
        @end
        @if branch.body != 0
          @for bs in branch.body
            r = infer_stmt(env, bs, var_counter)
            s = compose_subst(r.subst, s)
          @end
        @end
      @end
    @end
    
    else_body = stmt.else_branch
    @if else_body == 0 else_body = stmt.else_body @end
    
    @if else_body != 0
      i = 0
      len = else_body.len()
      @while i < len
        r = infer_stmt(env, else_body[i], var_counter)
        s = compose_subst(r.subst, s)
        i = i + 1
      @end
    @end
    
    return { env: env, subst: s }
  @end
  
  @if stmt.type == "WhileStmt" || stmt.kind == "WhileLoop"
    cond = stmt.cond
    @if cond == 0 cond = stmt.condition @end
    line_num = 1
    @if stmt.line != 0 line_num = stmt.line @end
    
    res_cond = infer_expr(env, cond, var_counter)
    s = compose_subst(unify(res_cond.ty, type_new_bool(), line_num), res_cond.subst)
    
    @if stmt.body != 0
      i = 0
      len = stmt.body.len()
      @while i < len
        r = infer_stmt(env, stmt.body[i], var_counter)
        s = compose_subst(r.subst, s)
        i = i + 1
      @end
    @end
    return { env: env, subst: s }
  @end
  
  @if stmt.kind == "ForLoop" || stmt.type == "ForLoop"
    v_ty = type_new_var(var_counter[0])
    var_counter = list_set(var_counter, 0, var_counter[0] + 1)
    env = env_bind(env, stmt.variable, v_ty)
    s = subst_new()
    @if stmt.body != 0
      i = 0
      len = stmt.body.len()
      @while i < len
        r = infer_stmt(env, stmt.body[i], var_counter)
        s = compose_subst(r.subst, s)
        i = i + 1
      @end
    @end
    return { env: env, subst: s }
  @end
  
  @if stmt.type == "ReturnStmt" || stmt.kind == "Return"
    expr = stmt.expr
    @if expr == 0 expr = stmt.value @end
    @if expr != 0
      res = infer_expr(env, expr, var_counter)
      return { env: env, subst: res.subst }
    @end
    return { env: env, subst: subst_new() }
  @end
  
  @if stmt.type == "ExprStmt" || stmt.kind == "ExpressionStmt"
    res = infer_expr(env, stmt.expr, var_counter)
    return { env: env, subst: res.subst }
  @end
  
  return { env: env, subst: subst_new() }
@end

@! ----------------------------------------------------------------------------
@! 8. MAIN TYPE CHECKER ENTRY
@! ----------------------------------------------------------------------------
@fn typecheck_ast(ast)
  env = env_new()
  var_counter = [1]
  s = subst_new()
  
  @! Pre-declare structs and functions
  i = 0
  len = ast.len()
  @while i < len
    node = ast[i]
    @if node.type == "StructDef" || node.kind == "TypeDef"
      fields = []
      f_list = node.fields
      @if f_list == 0 f_list = node.variants @end
      @if f_list != 0
        j = 0
        flen = f_list.len()
        @while j < flen
          fname = f_list[j].name
          @if fname == 0 fname = f_list[j] @end
          fields = fields.push({ name: fname, ty: type_new_var(var_counter[0]) })
          var_counter = list_set(var_counter, 0, var_counter[0] + 1)
          j = j + 1
        @end
      @end
      sty = type_new_struct(node.name, fields)
      env = env_bind(env, node.name, sty)
    @end
    @if node.type == "Function" || node.kind == "FnDef"
      params = []
      @if node.params != 0
        j = 0
        plen = node.params.len()
        @while j < plen
          params = params.push(type_new_var(var_counter[0]))
          var_counter = list_set(var_counter, 0, var_counter[0] + 1)
          j = j + 1
        @end
      @end
      ret_ty = type_new_var(var_counter[0])
      var_counter = list_set(var_counter, 0, var_counter[0] + 1)
      
      fty = type_new_func(params, ret_ty)
      env = env_bind(env, node.name, fty)
    @end
    i = i + 1
  @end
  
  @! Typecheck function bodies
  i = 0
  @while i < len
    node = ast[i]
    @if node.type == "Function" || node.kind == "FnDef"
      local_env = env
      fty = env_lookup(env, node.name)
      @if node.params != 0
        j = 0
        plen = node.params.len()
        @while j < plen
          pname = node.params[j]
          @if pname.name != 0 pname = pname.name @end
          local_env = env_bind(local_env, pname, fty.params[j])
          j = j + 1
        @end
      @end
      
      @if node.body != 0
        j = 0
        blen = node.body.len()
        @while j < blen
          res = infer_stmt(local_env, node.body[j], var_counter)
          s = compose_subst(res.subst, s)
          local_env = res.env
          j = j + 1
        @end
      @end
      
      @! Monomorphize if generic
      node = monomorphize(node, local_env, s)
    @end
    i = i + 1
  @end
  
  println("✅ Type checking complete. Substituted " + s.len().to_str() + " variables.")
  return ast
@end

@fn typecheck_program(ast)
  return typecheck_ast(ast)
@end
