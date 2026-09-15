// ============================================================================
// LIPI FRONTEND COMPILER — STATEMENT AST NODES
// Module: src/compiler/frontend/ast/ast_stmt.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Encapsulates all imperative control flow, iteration, and assignment statements
//    (assign, compound assign, if/elif/else, while, for-in, return, break, continue,
//    expression statements, blocks, defer, match, and try-catch).
// 2. Control flow integrity: Branching nodes carry dedicated slot pointers
//    (`condition`, `then_body`, `elif_branches`, `else_body`) to enable deterministic
//    basic block formation during SSA/CFG IR lowering.
// 3. Backward Compatibility: Implements standard span-aware constructors and canonical
//    legacy helpers (`ast_assign`, `ast_if_stmt`, `ast_while_loop`, etc.).
// ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/lexer/token"
import "compiler/frontend/ast/ast_node"

// ── 1. Supporting Descriptor Structs ──────────────────────────────────────────

// WHY: Elif branch descriptor with zero-collision field names
@struct ASTElifBranch
  elif_condition: ASTNode
  elif_body: array
  elif_span: SourceSpan
@end

// WHY: Match arm pattern-body pair descriptor with zero-collision field names
@struct ASTMatchArm
  arm_pattern: ASTNode
  arm_body: array
@end

@fn ast_elif_branch_new(cond: ASTNode, body: array, span: SourceSpan)
  // WHY: Allocates elif branch descriptor linking condition and execution block
  return {
    elif_condition: cond,
    elif_body: body,
    elif_span: span
  }
@end

@fn ast_elif_branch(condition, body)
  // WHY: Legacy compatibility constructor for elif branches
  return ast_elif_branch_new(condition, body, source_span_zero())
@end

@fn ast_match_arm_new(pattern: ASTNode, body: array)
  // WHY: Allocates match arm with pattern to test and resulting statement body
  return {
    arm_pattern: pattern,
    arm_body: body
  }
@end

@fn ast_match_arm(pattern, guard, body)
  // WHY: Legacy compatibility constructor for pattern match arms
  return ast_match_arm_new(pattern, body)
@end

// ── 2. Assignment Statements ──────────────────────────────────────────────────

@fn ast_stmt_assign(target: string, value: ASTNode, span: SourceSpan)
  // WHY: Allocates simple assignment statement `target = value`
  node = ast_node_new(AST_TAG_ASSIGN(), "Assign", span)
  node.target = target
  node.value = value
  node.ret_type = "void"
  return node
@end

@fn ast_assign(target: string, value: ASTNode)
  // WHY: Legacy compatibility constructor for assignment
  return ast_stmt_assign(target, value, source_span_zero())
@end

@fn ast_stmt_assign_op(target: string, value: ASTNode, op: string, span: SourceSpan)
  // WHY: Allocates compound assignment statement `target <op>= value` (+=, -=, *=, /=, %=)
  node = ast_node_new(AST_TAG_ASSIGN_OP(), "AssignOp", span)
  node.target = target
  node.value = value
  node.op = op
  node.ret_type = "void"
  return node
@end

@fn ast_assign_op(target: string, value: ASTNode, op: string)
  // WHY: Legacy compatibility constructor for compound assignment
  return ast_stmt_assign_op(target, value, op, source_span_zero())
@end

// ── 3. Conditional Statements (if / elif / else) ──────────────────────────────

@fn ast_stmt_if(cond: ASTNode, then_body: array, elif_branches: array, else_body: array, span: SourceSpan)
  // WHY: Allocates full conditional branch node capturing condition, true block,
  // chained elif descriptors, and optional else block.
  node = ast_node_new(AST_TAG_IF_STMT(), "IfStmt", span)
  node.condition = cond
  node.cond = cond
  node.then_body = then_body
  node.elif_branches = elif_branches
  node.else_body = else_body
  node.ret_type = "void"
  return node
@end

@fn ast_if_stmt(cond: ASTNode, then_body: array, elif_branches: array, else_body: array)
  // WHY: Legacy compatibility constructor for if statements
  return ast_stmt_if(cond, then_body, elif_branches, else_body, source_span_zero())
@end

// ── 4. Loops (while & for-in) ─────────────────────────────────────────────────

@fn ast_stmt_while(cond: ASTNode, body: array, span: SourceSpan)
  // WHY: Allocates while loop continuing while condition evaluates non-zero
  node = ast_node_new(AST_TAG_WHILE_LOOP(), "WhileLoop", span)
  node.condition = cond
  node.cond = cond
  node.body = body
  node.ret_type = "void"
  return node
@end

@fn ast_while_loop(cond: ASTNode, body: array)
  // WHY: Legacy compatibility constructor for while loops
  return ast_stmt_while(cond, body, source_span_zero())
@end

@fn ast_stmt_for(variable: string, iterable: ASTNode, body: array, span: SourceSpan)
  // WHY: Allocates for-in loop binding each element of iterable to variable
  node = ast_node_new(AST_TAG_FOR_LOOP(), "ForLoop", span)
  node.variable = variable
  node.iterable = iterable
  node.body = body
  node.ret_type = "void"
  return node
@end

@fn ast_for_loop(variable: string, iterable: ASTNode, body: array)
  // WHY: Legacy compatibility constructor for for loops
  return ast_stmt_for(variable, iterable, body, source_span_zero())
@end

// ── 5. Jumps & Control Exits ──────────────────────────────────────────────────

@fn ast_stmt_return(value: ASTNode, span: SourceSpan)
  // WHY: Allocates return statement carrying optional return expression value
  node = ast_node_new(AST_TAG_RETURN(), "Return", span)
  node.value = value
  node.ret_type = "void"
  return node
@end

@fn ast_return(value: ASTNode)
  // WHY: Legacy compatibility constructor for return statements
  return ast_stmt_return(value, source_span_zero())
@end

@fn ast_stmt_break(span: SourceSpan)
  // WHY: Allocates break statement terminating innermost loop
  return ast_node_new(AST_TAG_BREAK(), "Break", span)
@end

@fn ast_break()
  // WHY: Legacy compatibility constructor for break
  return ast_stmt_break(source_span_zero())
@end

@fn ast_stmt_continue(span: SourceSpan)
  // WHY: Allocates continue statement advancing to next loop iteration
  return ast_node_new(AST_TAG_CONTINUE(), "Continue", span)
@end

@fn ast_continue()
  // WHY: Legacy compatibility constructor for continue
  return ast_stmt_continue(source_span_zero())
@end

// ── 6. Blocks, Expressions & Deferrals ────────────────────────────────────────

@fn ast_stmt_expr(expr: ASTNode, span: SourceSpan)
  // WHY: Wraps a freestanding expression as an executable statement
  node = ast_node_new(AST_TAG_EXPR_STMT(), "ExpressionStmt", span)
  node.expr = expr
  node.ret_type = "void"
  return node
@end

@fn ast_expression_stmt(expr: ASTNode)
  // WHY: Legacy compatibility constructor for expression statements
  return ast_stmt_expr(expr, source_span_zero())
@end

@fn ast_stmt_block(stmts: array, span: SourceSpan)
  // WHY: Groups a sequential list of statements under a single lexical scope
  node = ast_node_new(AST_TAG_BLOCK(), "Block", span)
  node.body = stmts
  node.ret_type = "void"
  return node
@end

@fn ast_stmt_defer(stmt: ASTNode, span: SourceSpan)
  // WHY: Defer execution of statement until enclosing function scope exits
  node = ast_node_new(AST_TAG_DEFER(), "Defer", span)
  node.body = [stmt]
  node.ret_type = "void"
  return node
@end

@fn ast_defer(stmt: ASTNode)
  // WHY: Legacy compatibility constructor for defer statements
  return ast_stmt_defer(stmt, source_span_zero())
@end

// ── 7. Pattern Matching & Exception Handling ──────────────────────────────────

@fn ast_stmt_match(target: ASTNode, arms: array, span: SourceSpan)
  // WHY: Multi-way pattern matching construct evaluating target against match arms
  node = ast_node_new(AST_TAG_MATCH_STMT(), "MatchStmt", span)
  node.left = target
  node.elements = arms
  node.ret_type = "void"
  return node
@end

@fn ast_match_stmt(target: ASTNode, arms: array)
  // WHY: Legacy compatibility constructor for match statements
  return ast_stmt_match(target, arms, source_span_zero())
@end

@fn ast_stmt_try_catch(try_body: array, err_var: string, catch_body: array, span: SourceSpan)
  // WHY: Structured error handling executing catch_body on panic/fault with err_var bound
  node = ast_node_new(AST_TAG_TRY_CATCH(), "TryCatch", span)
  node.then_body = try_body
  node.variable = err_var
  node.else_body = catch_body
  node.ret_type = "void"
  return node
@end

@fn ast_try_catch(try_body: array, err_var: string, catch_body: array)
  // WHY: Legacy compatibility constructor for try-catch
  return ast_stmt_try_catch(try_body, err_var, catch_body, source_span_zero())
@end
