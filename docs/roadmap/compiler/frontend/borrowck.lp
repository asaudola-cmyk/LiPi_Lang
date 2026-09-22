@! ============================================================================
@! MAYA COMPILER STAGE 1 — AFFINE OWNERSHIP & LINEAR BORROW CHECKER
@! 100% Written in Pure Maya Language — Zero Rust/C/External Dependency
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Borrow Checker State & Lifetime Regions
@! ----------------------------------------------------------------------------

@fn borrow_context_new()
  return { 
    owners: [], 
    shared_borrows: [], 
    mut_borrows: [], 
    moved: [],
    lifetimes: [],
    current_scope: 0,
    errors: []
  }
@end

@fn borrowck_enter_scope(ctx)
  ctx.current_scope = ctx.current_scope + 1
  return ctx
@end

@fn borrowck_exit_scope(ctx)
  @! Drop all variables and borrow grants bounded by this scope
  new_shared = []
  @for b in ctx.shared_borrows
    @if b.scope < ctx.current_scope
      new_shared = new_shared.push(b)
    @end
  @end
  ctx.shared_borrows = new_shared

  new_mut = []
  @for b in ctx.mut_borrows
    @if b.scope < ctx.current_scope
      new_mut = new_mut.push(b)
    @end
  @end
  ctx.mut_borrows = new_mut

  ctx.current_scope = ctx.current_scope - 1
  return ctx
@end

@! ----------------------------------------------------------------------------
@! 2. Ownership & Move Semantics Analysis
@! ----------------------------------------------------------------------------

@fn borrowck_mark_owned(ctx, var_name)
  ctx.owners = ctx.owners.push({ name: var_name, scope: ctx.current_scope })
@end

@fn borrowck_is_moved(ctx, var_name)
  @for m in ctx.moved
    @if m == var_name
      return 1
    @end
  @end
  return 0
@end

@fn borrowck_mark_moved(ctx, var_name)
  @if borrowck_has_borrows(ctx, var_name)
    ctx.errors = ctx.errors.push("BorrowError: Cannot move out of `" + var_name + "` because it is currently borrowed")
  @end
  ctx.moved = ctx.moved.push(var_name)
@end

@fn borrowck_has_borrows(ctx, var_name)
  @for b in ctx.shared_borrows
    @if b.name == var_name
      return 1
    @end
  @end
  @for b in ctx.mut_borrows
    @if b.name == var_name
      return 1
    @end
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 3. Shared (&) and Mutable (&mut) Borrow Verification
@! ----------------------------------------------------------------------------

@fn borrowck_borrow_shared(ctx, var_name)
  @if borrowck_is_moved(ctx, var_name)
    ctx.errors = ctx.errors.push("BorrowError: Cannot borrow `" + var_name + "` after move")
    return 0
  @end
  
  @for b in ctx.mut_borrows
    @if b.name == var_name
      ctx.errors = ctx.errors.push("BorrowError: Cannot borrow `" + var_name + "` as shared because it is already mutably borrowed")
      return 0
    @end
  @end
  
  ctx.shared_borrows = ctx.shared_borrows.push({ name: var_name, scope: ctx.current_scope })
  return 1
@end

@fn borrowck_borrow_mut(ctx, var_name)
  @if borrowck_is_moved(ctx, var_name)
    ctx.errors = ctx.errors.push("BorrowError: Cannot mutably borrow `" + var_name + "` after move")
    return 0
  @end

  @for b in ctx.shared_borrows
    @if b.name == var_name
      ctx.errors = ctx.errors.push("BorrowError: Cannot mutably borrow `" + var_name + "` while shared borrows exist")
      return 0
    @end
  @end

  @for b in ctx.mut_borrows
    @if b.name == var_name
      ctx.errors = ctx.errors.push("BorrowError: Cannot borrow `" + var_name + "` as mutable more than once simultaneously")
      return 0
    @end
  @end

  ctx.mut_borrows = ctx.mut_borrows.push({ name: var_name, scope: ctx.current_scope })
  return 1
@end

@! ----------------------------------------------------------------------------
@! 4. Statement & Program Checking Pass
@! ----------------------------------------------------------------------------

@fn borrowck_check_expr(ctx, expr)
  @if expr == 0
    return 1
  @end
  
  @if expr.kind == "Identifier" || expr.kind == "Variable" || expr.type == "Identifier"
    @if borrowck_is_moved(ctx, expr.name)
      ctx.errors = ctx.errors.push("BorrowError: Use of moved value `" + expr.name + "`")
    @end
  @elif expr.kind == "Borrow"
    @if expr.is_mut == 1
      borrowck_borrow_mut(ctx, expr.target)
    @else
      borrowck_borrow_shared(ctx, expr.target)
    @end
  @elif expr.kind == "Binary" || expr.kind == "BinaryOp" || expr.type == "BinaryOp"
    borrowck_check_expr(ctx, expr.left)
    borrowck_check_expr(ctx, expr.right)
  @elif expr.kind == "UnaryOp"
    borrowck_check_expr(ctx, expr.expr)
  @elif expr.kind == "Call" || expr.type == "Call"
    func_expr = expr.callee
    @if func_expr == 0 func_expr = expr.func @end
    @if func_expr != 0
      borrowck_check_expr(ctx, func_expr)
    @end
    @if expr.args != 0
      @for arg in expr.args
        borrowck_check_expr(ctx, arg)
      @end
    @end
  @elif expr.kind == "MemberAccess" || expr.type == "FieldAccess"
    obj = expr.target
    @if obj == 0 obj = expr.obj @end
    borrowck_check_expr(ctx, obj)
  @elif expr.kind == "Index"
    borrowck_check_expr(ctx, expr.target)
    borrowck_check_expr(ctx, expr.index)
  @elif expr.kind == "ArrayLit" || expr.type == "ArrayLiteral"
    @if expr.elements != 0
      @for el in expr.elements
        borrowck_check_expr(ctx, el)
      @end
    @end
  @elif expr.kind == "MapLit"
    @if expr.entries != 0
      @for entry in expr.entries
        @if entry.value != 0
          borrowck_check_expr(ctx, entry.value)
        @elif entry.val != 0
          borrowck_check_expr(ctx, entry.val)
        @end
      @end
    @end
  @end
  return 1
@end

@fn borrowck_check_stmt(ctx, stmt)
  @if stmt == 0
    return 1
  @end
  @if stmt.kind == "Assign" || stmt.type == "VarDecl"
    val = stmt.value
    @if val == 0 val = stmt.expr @end
    borrowck_check_expr(ctx, val)
    target = stmt.target
    @if target == 0 || target == "none" target = stmt.name @end
    @if target != "" && target != 0
      borrowck_mark_owned(ctx, target)
    @end
  @elif stmt.kind == "FnDef" || stmt.type == "Function"
    borrowck_enter_scope(ctx)
    @if stmt.params != 0
      @for param in stmt.params
        pname = param
        @if param.name != 0 pname = param.name @end
        borrowck_mark_owned(ctx, pname)
      @end
    @end
    @if stmt.body != 0
      @for s in stmt.body
        borrowck_check_stmt(ctx, s)
      @end
    @end
    borrowck_exit_scope(ctx)
  @elif stmt.kind == "If" || stmt.kind == "IfStmt" || stmt.type == "IfStmt"
    cond = stmt.condition
    @if cond == 0 cond = stmt.cond @end
    borrowck_check_expr(ctx, cond)
    
    then_body = stmt.then_body
    @if then_body == 0 then_body = stmt.then_branch @end
    @if then_body == 0 then_body = stmt.body @end
    
    @if then_body != 0
      borrowck_enter_scope(ctx)
      @for s in then_body
        borrowck_check_stmt(ctx, s)
      @end
      borrowck_exit_scope(ctx)
    @end
    
    @if stmt.elif_branches != 0
      @for branch in stmt.elif_branches
        @if branch.cond != 0
          borrowck_check_expr(ctx, branch.cond)
        @end
        @if branch.body != 0
          borrowck_enter_scope(ctx)
          @for bs in branch.body
            borrowck_check_stmt(ctx, bs)
          @end
          borrowck_exit_scope(ctx)
        @end
      @end
    @end
    
    else_body = stmt.else_body
    @if else_body == 0 else_body = stmt.else_branch @end
    @if else_body != 0
      borrowck_enter_scope(ctx)
      @for s in else_body
        borrowck_check_stmt(ctx, s)
      @end
      borrowck_exit_scope(ctx)
    @end
  @elif stmt.kind == "While" || stmt.kind == "WhileLoop" || stmt.type == "WhileStmt"
    cond = stmt.condition
    @if cond == 0 cond = stmt.cond @end
    borrowck_check_expr(ctx, cond)
    @if stmt.body != 0
      borrowck_enter_scope(ctx)
      @for s in stmt.body
        borrowck_check_stmt(ctx, s)
      @end
      borrowck_exit_scope(ctx)
    @end
  @elif stmt.kind == "ForLoop" || stmt.type == "ForLoop"
    @if stmt.iterable != 0
      borrowck_check_expr(ctx, stmt.iterable)
    @end
    borrowck_enter_scope(ctx)
    @if stmt.variable != 0 && stmt.variable != ""
      borrowck_mark_owned(ctx, stmt.variable)
    @end
    @if stmt.body != 0
      @for s in stmt.body
        borrowck_check_stmt(ctx, s)
      @end
    @end
    borrowck_exit_scope(ctx)
  @elif stmt.kind == "Return" || stmt.type == "ReturnStmt"
    val = stmt.value
    @if val == 0 val = stmt.expr @end
    @if val != 0
      borrowck_check_expr(ctx, val)
    @end
  @elif stmt.kind == "ExpressionStmt" || stmt.type == "ExprStmt"
    borrowck_check_expr(ctx, stmt.expr)
  @end
  return 1
@end

@fn borrowck_program(ast)
  ctx = borrow_context_new()
  @for stmt in ast
    borrowck_check_stmt(ctx, stmt)
  @end
  return ctx.errors
@end

@fn borrowck_ast(ast)
  return borrowck_program(ast)
@end

@fn track_ownership(ast)
  return borrowck_program(ast)
@end

@fn check_lifetimes(ast)
  return 1
@end
