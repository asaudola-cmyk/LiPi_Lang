@! ============================================================================
@! MAYA COMPILER STAGE 2 — SCOPE ANALYSIS & NAME RESOLVER
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"

@fn scope_new()
  return { parent: "none", symbols: [] }
@end

@fn scope_with_parent(parent_scope)
  return { parent: parent_scope, symbols: [] }
@end

@fn scope_define(scope, name)
  scope.symbols = scope.symbols.push(name)
@end

@fn scope_has(scope, name)
  @for sym in scope.symbols
    @if sym == name
      return 1
    @end
  @end
  @if scope.parent != "none"
    return scope_has(scope.parent, name)
  @end
  return 0
@end

@fn resolve_expression(expr, scope)
  @if expr == 0
    return 1
  @end
  @if expr.kind == "Variable" || expr.type == "Identifier"
    @if scope_has(scope, expr.name) == 0
      @! Implicit auto-declaration in global/local scope
      scope_define(scope, expr.name)
    @end
    return 1
  @elif expr.kind == "BinaryOp" || expr.type == "BinaryOp"
    resolve_expression(expr.left, scope)
    resolve_expression(expr.right, scope)
    return 1
  @elif expr.kind == "UnaryOp"
    resolve_expression(expr.expr, scope)
    return 1
  @elif expr.kind == "Pipeline"
    resolve_expression(expr.left, scope)
    resolve_expression(expr.right, scope)
    return 1
  @elif expr.kind == "Call" || expr.type == "Call"
    @if expr.func != 0
      resolve_expression(expr.func, scope)
    @elif expr.callee != 0
      resolve_expression(expr.callee, scope)
    @end
    @if expr.args != 0
      @for arg in expr.args
        resolve_expression(arg, scope)
      @end
    @end
    return 1
  @elif expr.kind == "MemberAccess" || expr.type == "FieldAccess"
    @if expr.target != 0
      resolve_expression(expr.target, scope)
    @elif expr.obj != 0
      resolve_expression(expr.obj, scope)
    @end
    return 1
  @elif expr.kind == "Index"
    resolve_expression(expr.target, scope)
    resolve_expression(expr.index, scope)
    return 1
  @elif expr.kind == "ArrayLit" || expr.type == "ArrayLiteral"
    @if expr.elements != 0
      @for el in expr.elements
        resolve_expression(el, scope)
      @end
    @end
    return 1
  @elif expr.kind == "MapLit"
    @if expr.entries != 0
      @for entry in expr.entries
        @if entry.value != 0
          resolve_expression(entry.value, scope)
        @elif entry.val != 0
          resolve_expression(entry.val, scope)
        @end
      @end
    @end
    return 1
  @elif expr.kind == "Closure"
    c_scope = scope_with_parent(scope)
    @if expr.params != 0
      @for p in expr.params
        scope_define(c_scope, p)
      @end
    @end
    @if expr.body != 0
      @for sub_stmt in expr.body
        resolve_statement(sub_stmt, c_scope)
      @end
    @end
    return 1
  @elif expr.kind == "MatchExpr"
    resolve_expression(expr.target, scope)
    @if expr.arms != 0
      @for arm in expr.arms
        resolve_expression(arm.body, scope)
      @end
    @end
    return 1
  @end
  return 1
@end

@fn resolve_statement(stmt, scope)
  @if stmt == 0
    return 1
  @end
  @if stmt.kind == "Assign" || stmt.type == "VarDecl"
    target_name = ""
    @if stmt.target != 0
      target_name = stmt.target
    @elif stmt.name != 0
      target_name = stmt.name
    @end
    @if target_name != ""
      scope_define(scope, target_name)
    @end
    @if stmt.value != 0
      resolve_expression(stmt.value, scope)
    @elif stmt.expr != 0
      resolve_expression(stmt.expr, scope)
    @end
  @elif stmt.kind == "FnDef" || stmt.type == "Function"
    scope_define(scope, stmt.name)
    fn_scope = scope_with_parent(scope)
    @if stmt.params != 0
      @for param in stmt.params
        @if param.name != 0
          scope_define(fn_scope, param.name)
        @else
          scope_define(fn_scope, param)
        @end
      @end
    @end
    @if stmt.body != 0
      @for sub_stmt in stmt.body
        resolve_statement(sub_stmt, fn_scope)
      @end
    @end
  @elif stmt.kind == "IfStmt" || stmt.type == "IfStmt"
    @if stmt.condition != 0
      resolve_expression(stmt.condition, scope)
    @elif stmt.cond != 0
      resolve_expression(stmt.cond, scope)
    @end
    @if stmt.then_body != 0
      @for sub_stmt in stmt.then_body
        resolve_statement(sub_stmt, scope)
      @end
    @elif stmt.then_branch != 0
      @for sub_stmt in stmt.then_branch
        resolve_statement(sub_stmt, scope)
      @end
    @end
    @if stmt.elif_branches != 0
      @for branch in stmt.elif_branches
        @if branch.cond != 0
          resolve_expression(branch.cond, scope)
        @end
        @if branch.body != 0
          @for sub_stmt in branch.body
            resolve_statement(sub_stmt, scope)
          @end
        @end
      @end
    @end
    @if stmt.else_body != 0
      @for sub_stmt in stmt.else_body
        resolve_statement(sub_stmt, scope)
      @end
    @elif stmt.else_branch != 0
      @for sub_stmt in stmt.else_branch
        resolve_statement(sub_stmt, scope)
      @end
    @end
  @elif stmt.kind == "WhileLoop" || stmt.type == "WhileStmt"
    @if stmt.condition != 0
      resolve_expression(stmt.condition, scope)
    @elif stmt.cond != 0
      resolve_expression(stmt.cond, scope)
    @end
    @if stmt.body != 0
      @for sub_stmt in stmt.body
        resolve_statement(sub_stmt, scope)
      @end
    @end
  @elif stmt.kind == "ForLoop" || stmt.type == "ForLoop"
    loop_scope = scope_with_parent(scope)
    @if stmt.variable != 0 && stmt.variable != ""
      scope_define(loop_scope, stmt.variable)
    @end
    @if stmt.iterable != 0
      resolve_expression(stmt.iterable, scope)
    @end
    @if stmt.body != 0
      @for sub_stmt in stmt.body
        resolve_statement(sub_stmt, loop_scope)
      @end
    @end
  @elif stmt.kind == "Return" || stmt.type == "ReturnStmt"
    @if stmt.value != 0
      resolve_expression(stmt.value, scope)
    @elif stmt.expr != 0
      resolve_expression(stmt.expr, scope)
    @end
  @elif stmt.kind == "ExpressionStmt" || stmt.type == "ExprStmt"
    resolve_expression(stmt.expr, scope)
  @elif stmt.kind == "TypeDef" || stmt.type == "StructDef"
    scope_define(scope, stmt.name)
  @elif stmt.kind == "TraitDef"
    scope_define(scope, stmt.name)
  @elif stmt.kind == "ImplBlock"
    @if stmt.methods != 0
      @for m in stmt.methods
        resolve_statement(m, scope)
      @end
    @end
  @elif stmt.kind == "ActorDef"
    scope_define(scope, stmt.name)
    @if stmt.body != 0
      @for s in stmt.body
        resolve_statement(s, scope)
      @end
    @end
  @elif stmt.kind == "SupervisorDef"
    scope_define(scope, stmt.name)
  @elif stmt.kind == "Spawn"
    @if stmt.handle != 0
      scope_define(scope, stmt.handle)
    @end
    @if stmt.body != 0
      @for s in stmt.body
        resolve_statement(s, scope)
      @end
    @end
  @end
  return 1
@end

@fn resolve_program(statements)
  global_scope = scope_new()
  @for stmt in statements
    resolve_statement(stmt, global_scope)
  @end
  return global_scope
@end

@fn resolve_imports(ast, search_paths)
  @! Resolves module imports for given AST
  return { ast: ast, imports: search_paths }
@end
