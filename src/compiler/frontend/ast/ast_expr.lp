// ============================================================================
// LIPI FRONTEND COMPILER — EXPRESSION AST NODES
// Module: src/compiler/frontend/ast/ast_expr.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Encapsulates all value-producing expression AST nodes (literals, variables,
//    binary/unary operators, calls, indexing, member access, pipeline, and collections).
// 2. Exact typing and span preservation: Each constructor stamps the appropriate
//    `ret_type` and `span` metadata for type-checking inference and diagnostic reporting.
// 3. Backward Compatibility: Provides both modern span-aware constructors
//    (`ast_expr_*`) and canonical legacy shorthands (`ast_binary_op`, `ast_call`, etc.).
// ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/lexer/token"
import "compiler/frontend/ast/ast_node"

// ── 1. Literal Expression Constructors ────────────────────────────────────────

@fn ast_expr_literal_int(val: i64, span: SourceSpan)
  // WHY: Allocates integer constant node with exact 64-bit integer payload
  node = ast_node_new(AST_TAG_LITERAL_INT(), "LiteralInt", span)
  node.val = val
  node.ret_type = "i64"
  return node
@end

@fn ast_literal_int(val: i64)
  // WHY: Legacy compatibility constructor for integer literals
  return ast_expr_literal_int(val, source_span_zero())
@end

@fn ast_expr_literal_float(val: f64, span: SourceSpan)
  // WHY: Allocates IEEE-754 floating point literal node for 64-bit hardware registers
  node = ast_node_new(AST_TAG_LITERAL_FLOAT(), "LiteralFloat", span)
  node.val = 0
  node.ret_type = "f64"
  return node
@end

@fn ast_literal_float(val: f64)
  // WHY: Legacy compatibility constructor for float literals
  return ast_expr_literal_float(val, source_span_zero())
@end

@fn ast_expr_literal_str(text: string, span: SourceSpan)
  // WHY: Allocates string literal node storing string payload in `name`
  node = ast_node_new(AST_TAG_LITERAL_STR(), "LiteralStr", span)
  node.name = text
  node.ret_type = "string"
  return node
@end

@fn ast_literal_str(text: string)
  // WHY: Legacy compatibility constructor for string literals
  return ast_expr_literal_str(text, source_span_zero())
@end

@fn ast_expr_literal_bool(val: i64, span: SourceSpan)
  // WHY: Allocates boolean literal node where 1 represents true and 0 represents false
  node = ast_node_new(AST_TAG_LITERAL_BOOL(), "LiteralBool", span)
  node.val = val
  node.ret_type = "bool"
  return node
@end

@fn ast_literal_bool(val: i64)
  // WHY: Legacy compatibility constructor for boolean literals
  return ast_expr_literal_bool(val, source_span_zero())
@end

@fn ast_expr_literal_none(span: SourceSpan)
  // WHY: Allocates none / nil / null singleton literal node
  node = ast_node_new(AST_TAG_LITERAL_NONE(), "LiteralNone", span)
  node.name = "none"
  node.ret_type = "none"
  return node
@end

@fn ast_literal_none()
  // WHY: Legacy compatibility constructor for none literal
  return ast_expr_literal_none(source_span_zero())
@end

// ── 2. Identifier & Variable Nodes ────────────────────────────────────────────

@fn ast_expr_ident(name: string, span: SourceSpan)
  // WHY: Allocates variable reference expression by identifier name
  node = ast_node_new(AST_TAG_VARIABLE(), "Variable", span)
  node.name = name
  node.ret_type = "i64"
  return node
@end

@fn ast_variable(name: string)
  // WHY: Legacy compatibility constructor for variable identifier nodes
  return ast_expr_ident(name, source_span_zero())
@end

// ── 3. Arithmetic, Logical, & Bitwise Operator Nodes ─────────────────────────

@fn ast_expr_binary(left: ASTNode, op: string, right: ASTNode, span: SourceSpan)
  // WHY: Allocates binary expression joining left and right operands by operator op
  node = ast_node_new(AST_TAG_BINARY_OP(), "BinaryOp", span)
  node.left = left
  node.right = right
  node.op = op
  node.ret_type = "i64"
  return node
@end

@fn ast_binary_op(left: ASTNode, op: string, right: ASTNode)
  // WHY: Legacy compatibility constructor for binary operators
  return ast_expr_binary(left, op, right, source_span_zero())
@end

@fn ast_expr_unary(op: string, expr: ASTNode, span: SourceSpan)
  // WHY: Allocates unary operator expression (e.g. '-' or '!')
  node = ast_node_new(AST_TAG_UNARY_OP(), "UnaryOp", span)
  node.op = op
  node.expr = expr
  node.ret_type = "i64"
  return node
@end

@fn ast_unary_op(op: string, expr: ASTNode)
  // WHY: Legacy compatibility constructor for unary operators
  return ast_expr_unary(op, expr, source_span_zero())
@end

@fn ast_expr_pipeline(left: ASTNode, right: ASTNode, span: SourceSpan)
  // WHY: Allocates pipe operator expression (|>) chaining output to downstream callee
  node = ast_node_new(AST_TAG_PIPELINE(), "Pipeline", span)
  node.left = left
  node.right = right
  node.op = "|>"
  node.ret_type = "i64"
  return node
@end

@fn ast_pipeline(left: ASTNode, right: ASTNode)
  // WHY: Legacy compatibility constructor for pipeline operator
  return ast_expr_pipeline(left, right, source_span_zero())
@end

// ── 4. Invocations & Accessors ────────────────────────────────────────────────

@fn ast_expr_call(callee: ASTNode, args: array, span: SourceSpan)
  // WHY: Allocates function invocation node with callee pointer and parameter array
  fn_name = ""
  @if callee != 0 && callee.kind == "Variable"
    fn_name = callee.name
  @end
  node = ast_node_new(AST_TAG_CALL(), "Call", span)
  node.name = fn_name
  node.func = callee
  node.args = args
  node.ret_type = "i64"
  return node
@end

@fn ast_call(func_expr: ASTNode, args: array)
  // WHY: Legacy compatibility constructor for call expressions
  return ast_expr_call(func_expr, args, source_span_zero())
@end

@fn ast_expr_index(target: ASTNode, index_expr: ASTNode, span: SourceSpan)
  // WHY: Allocates subscript indexing expression `target[index]`
  node = ast_node_new(AST_TAG_INDEX(), "Index", span)
  node.left = target
  node.index = index_expr
  node.ret_type = "i64"
  return node
@end

@fn ast_index(target: ASTNode, index_expr: ASTNode)
  // WHY: Legacy compatibility constructor for subscript indexing
  return ast_expr_index(target, index_expr, source_span_zero())
@end

@fn ast_expr_member(target: ASTNode, member_name: string, span: SourceSpan)
  // WHY: Allocates dot member access expression `target.member`
  node = ast_node_new(AST_TAG_MEMBER_ACCESS(), "MemberAccess", span)
  node.left = target
  node.name = member_name
  node.ret_type = "i64"
  return node
@end

@fn ast_member_access(target: ASTNode, field_name: string)
  // WHY: Legacy compatibility constructor for member field access
  return ast_expr_member(target, field_name, source_span_zero())
@end

// ── 5. Composite Collections & Closures ───────────────────────────────────────

@fn ast_expr_array_lit(elements: array, span: SourceSpan)
  // WHY: Allocates array literal expression `[e1, e2, ...]`
  node = ast_node_new(AST_TAG_ARRAY_LIT(), "ArrayLit", span)
  node.elements = elements
  node.ret_type = "array"
  return node
@end

@fn ast_array_lit(elements: array)
  // WHY: Legacy compatibility constructor for array literals
  return ast_expr_array_lit(elements, source_span_zero())
@end

@fn ast_expr_map_lit(entries: array, span: SourceSpan)
  // WHY: Allocates map/dictionary literal expression `{ k1: v1, ... }`
  node = ast_node_new(AST_TAG_MAP_LIT(), "MapLit", span)
  node.elements = entries
  node.ret_type = "map"
  return node
@end

@fn ast_map_lit(entries: array)
  // WHY: Legacy compatibility constructor for map literals
  return ast_expr_map_lit(entries, source_span_zero())
@end

@fn ast_expr_closure(params: array, body: array, span: SourceSpan)
  // WHY: Allocates anonymous function closure with capture scope
  node = ast_node_new(AST_TAG_CLOSURE(), "Closure", span)
  node.params = params
  node.body = body
  node.ret_type = "fn"
  return node
@end

@fn ast_closure(params: array, body: array)
  // WHY: Legacy compatibility constructor for anonymous closures
  return ast_expr_closure(params, body, source_span_zero())
@end
