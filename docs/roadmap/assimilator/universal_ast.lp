@! ============================================================================
@! MAYA ASSIMILATOR — UNIVERSAL ABSTRACT SYNTAX TREE (UAST)
@! 100% Written in Pure Maya Language
@! Provides intermediate representation for multi-language transpilation
@! ============================================================================

import "compiler/frontend/ast"
import "universe/core/collections"
import "universe/core/string"

@! Create a new Universal AST node
@fn uast_node_new(kind)
  return {
    kind: kind,
    name: "",
    value: 0,
    op: "",
    type: "any",
    children: [],
    params: [],
    body: [],
    attributes: {}
  }
@end

@! Set name on UAST node
@fn uast_set_name(node, name)
  node.name = name
  return node
@end

@! Set value on UAST node
@fn uast_set_value(node, val)
  node.value = val
  return node
@end

@! Set operator on UAST node
@fn uast_set_op(node, op)
  node.op = op
  return node
@end

@! Set type on UAST node
@fn uast_set_type(node, type_name)
  node.type = type_name
  return node
@end

@! Add child node to UAST node
@fn uast_add_child(node, child)
  node.children = node.children.push(child)
  return node
@end

@! Add parameter to UAST function node
@fn uast_add_param(node, param_name)
  node.params = node.params.push(param_name)
  return node
@end

@! Add statement to UAST function / block body
@fn uast_add_body(node, stmt)
  node.body = node.body.push(stmt)
  return node
@end

@! Convert Universal AST node tree to Maya Compiler AST
@fn uast_to_maya_ast(uast_node)
  @if uast_node == 0 || uast_node == "none"
    return 0
  @end

  kind = uast_node.kind

  @! Module / Program root
  @if kind == "U_Module" || kind == "U_Program"
    statements = []
    i = 0
    len = uast_node.children.len()
    @while i < len
      child_ast = uast_to_maya_ast(uast_node.children[i])
      @if child_ast != 0
        statements = statements.push(child_ast)
      @end
      i = i + 1
    @end
    return statements
  @end

  @! Function Definition
  @if kind == "U_Function" || kind == "U_FnDef"
    body_statements = []
    i = 0
    blen = uast_node.body.len()
    @while i < blen
      stmt_ast = uast_to_maya_ast(uast_node.body[i])
      @if stmt_ast != 0
        body_statements = body_statements.push(stmt_ast)
      @end
      i = i + 1
    @end

    @! If body was empty but children had statements, convert children
    @if body_statements.len() == 0 && uast_node.children.len() > 0
      i = 0
      clen = uast_node.children.len()
      @while i < clen
        c_ast = uast_to_maya_ast(uast_node.children[i])
        @if c_ast != 0
          body_statements = body_statements.push(c_ast)
        @end
        i = i + 1
      @end
    @end

    return ast_fn_def(uast_node.name, uast_node.params, uast_node.type, body_statements)
  @end

  @! Return Statement
  @if kind == "U_Return"
    val = 0
    @if uast_node.children.len() > 0
      val = uast_to_maya_ast(uast_node.children[0])
    @elif uast_node.value != 0
      val = ast_literal_int(uast_node.value)
    @end
    return ast_return(val)
  @end

  @! Variable Assignment / Declaration
  @if kind == "U_Assign" || kind == "U_VarDecl"
    val = 0
    @if uast_node.children.len() > 0
      val = uast_to_maya_ast(uast_node.children[0])
    @elif uast_node.value != 0
      val = ast_literal_int(uast_node.value)
    @end
    return ast_assign(uast_node.name, val)
  @end

  @! Binary Operation
  @if kind == "U_BinaryOp"
    left = 0
    right = 0
    @if uast_node.children.len() > 0
      left = uast_to_maya_ast(uast_node.children[0])
    @end
    @if uast_node.children.len() > 1
      right = uast_to_maya_ast(uast_node.children[1])
    @end
    return ast_binary_op(left, uast_node.op, right)
  @end

  @! Unary Operation
  @if kind == "U_UnaryOp"
    expr = 0
    @if uast_node.children.len() > 0
      expr = uast_to_maya_ast(uast_node.children[0])
    @end
    return ast_unary_op(uast_node.op, expr)
  @end

  @! Function Call
  @if kind == "U_Call"
    args = []
    i = 0
    len = uast_node.children.len()
    @while i < len
      arg_ast = uast_to_maya_ast(uast_node.children[i])
      @if arg_ast != 0
        args = args.push(arg_ast)
      @end
      i = i + 1
    @end
    return ast_call(uast_node.name, args)
  @end

  @! Literal Int
  @if kind == "U_LiteralInt" || kind == "U_Int"
    return ast_literal_int(uast_node.value)
  @end

  @! Literal Float
  @if kind == "U_LiteralFloat" || kind == "U_Float"
    return ast_literal_float(uast_node.value)
  @end

  @! Literal String
  @if kind == "U_LiteralStr" || kind == "U_Str"
    return ast_literal_str(uast_node.value)
  @end

  @! Literal Bool
  @if kind == "U_LiteralBool" || kind == "U_Bool"
    return ast_literal_bool(uast_node.value)
  @end

  @! Literal None
  @if kind == "U_LiteralNone" || kind == "U_None"
    return ast_literal_none()
  @end

  @! Variable / Identifier
  @if kind == "U_Variable" || kind == "U_Ident"
    return ast_variable(uast_node.name)
  @end

  @! If Statement
  @if kind == "U_If"
    cond = 0
    then_body = []
    else_body = []
    @if uast_node.children.len() > 0
      cond = uast_to_maya_ast(uast_node.children[0])
    @end
    @if uast_node.children.len() > 1
      then_body = uast_to_maya_ast(uast_node.children[1])
    @end
    @if uast_node.children.len() > 2
      else_body = uast_to_maya_ast(uast_node.children[2])
    @end
    return ast_if_stmt(cond, then_body, [], else_body)
  @end

  @! While Loop
  @if kind == "U_While"
    cond = 0
    body = []
    @if uast_node.children.len() > 0
      cond = uast_to_maya_ast(uast_node.children[0])
    @end
    @if uast_node.children.len() > 1
      body = uast_to_maya_ast(uast_node.children[1])
    @end
    return ast_while_loop(cond, body)
  @end

  @! Fallback generic node conversion
  return {
    kind: kind,
    name: uast_node.name,
    value: uast_node.value,
    op: uast_node.op,
    children: uast_node.children
  }
@end
