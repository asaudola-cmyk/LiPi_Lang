@! ============================================================================
@! MAYA COMPILER STAGE 2 — ABSTRACT SYNTAX TREE (AST) DEFINITIONS
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"

@! AST Node Constructors for Expressions
@fn ast_literal_int(val)
  return { kind: "LiteralInt", val: val }
@end

@fn ast_literal_float(val)
  return { kind: "LiteralFloat", val: val }
@end

@fn ast_literal_str(val)
  return { kind: "LiteralStr", val: val }
@end

@fn ast_literal_bool(val)
  return { kind: "LiteralBool", val: val }
@end

@fn ast_literal_none()
  return { kind: "LiteralNone", val: "none" }
@end

@fn ast_variable(name)
  return { kind: "Variable", name: name }
@end

@fn ast_unary_op(op, expr)
  return { kind: "UnaryOp", op: op, expr: expr }
@end

@fn ast_binary_op(left, op, right)
  return { kind: "BinaryOp", left: left, op: op, right: right }
@end

@fn ast_pipeline(left, right)
  return { kind: "Pipeline", left: left, right: right }
@end

@fn ast_call(func, args)
  return { kind: "Call", func: func, args: args }
@end

@fn ast_member_access(target, field)
  return { kind: "MemberAccess", target: target, field: field }
@end

@fn ast_index(target, index)
  return { kind: "Index", target: target, index: index }
@end

@fn ast_array_lit(elements)
  return { kind: "ArrayLit", elements: elements }
@end

@fn ast_map_lit(entries)
  return { kind: "MapLit", entries: entries }
@end

@fn ast_closure(params, body)
  return { kind: "Closure", params: params, body: body }
@end

@fn ast_match_expr(target, arms)
  return { kind: "MatchExpr", target: target, arms: arms }
@end

@fn ast_perform_effect(effect_name, operation, args)
  return { kind: "PerformEffect", effect_name: effect_name, operation: operation, args: args }
@end

@! AST Node Constructors for Statements
@fn ast_assign(target, value)
  return { kind: "Assign", target: target, value: value }
@end

@fn ast_fn_def(name, params, ret_type, body)
  return { kind: "FnDef", name: name, params: params, ret_type: ret_type, body: body }
@end

@fn ast_if_stmt(condition, then_body, elif_branches, else_body)
  return { kind: "IfStmt", condition: condition, then_body: then_body, elif_branches: elif_branches, else_body: else_body }
@end

@fn ast_while_loop(condition, body)
  return { kind: "WhileLoop", condition: condition, body: body }
@end

@fn ast_for_loop(variable, iterable, body)
  return { kind: "ForLoop", variable: variable, iterable: iterable, body: body }
@end

@fn ast_return(value)
  return { kind: "Return", value: value }
@end

@fn ast_spawn(handle, body)
  return { kind: "Spawn", handle: handle, body: body }
@end

@fn ast_import(path)
  return { kind: "Import", path: path }
@end

@fn ast_type_def(name, variants)
  return { kind: "TypeDef", name: name, variants: variants }
@end

@fn ast_trait_def(name, methods)
  return { kind: "TraitDef", name: name, methods: methods }
@end

@fn ast_impl_block(trait_name, target_type, methods)
  return { kind: "ImplBlock", trait_name: trait_name, target_type: target_type, methods: methods }
@end

@fn ast_actor_def(name, body)
  return { kind: "ActorDef", name: name, body: body }
@end

@fn ast_supervisor_def(name, strategy, children)
  return { kind: "SupervisorDef", name: name, strategy: strategy, children: children }
@end

@fn ast_effect_def(name, operations)
  return { kind: "EffectDef", name: name, operations: operations }
@end

@fn ast_handle_effect(effect_name, handlers, body)
  return { kind: "HandleEffect", effect_name: effect_name, handlers: handlers, body: body }
@end

@fn ast_implicit_render(content)
  return { kind: "ImplicitRender", content: content }
@end

@fn ast_shader(name, dispatch, body)
  return { kind: "Shader", name: name, dispatch: dispatch, body: body }
@end

@fn ast_expression_stmt(expr)
  return { kind: "ExpressionStmt", expr: expr }
@end
