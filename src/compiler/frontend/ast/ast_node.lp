// ============================================================================
// LIPI FRONTEND COMPILER — BASE AST NODE MODEL & SPECIFICATION
// Module: src/compiler/frontend/ast/ast_node.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Abstract Syntax Trees (AST) form the intermediate semantic representation
//    bridging the bilingual lexical scanner and downstream type checking, IR lowering,
//    and code generation stages.
// 2. High-performance matching: Every ASTNode carries both an integer `tag` (for O(1)
//    numeric matching in hot dispatch loops) and a canonical `kind` string (for human
//    readability, debugging, and backward compatibility with existing compiler passes).
// 3. Precise source coordinates: Every node embeds a `SourceSpan` tracking file, line,
//    column, and offset bounds for error diagnostics, LSP hovers, and debugger symbol maps.
// 4. Zero-Collision 25-Field Schema: Standardized slot layout ensures direct hardware
//    register alignment and prevents field offset collisions across compiler modules.
// ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/lexer/token"

// ── 1. AST Tag Enumeration ───────────────────────────────────────────────────

@fn AST_TAG_NONE() return 0 @end

// Expressions (1..15)
@fn AST_TAG_LITERAL_INT() return 1 @end
@fn AST_TAG_LITERAL_FLOAT() return 2 @end
@fn AST_TAG_LITERAL_STR() return 3 @end
@fn AST_TAG_LITERAL_BOOL() return 4 @end
@fn AST_TAG_LITERAL_NONE() return 5 @end
@fn AST_TAG_VARIABLE() return 6 @end
@fn AST_TAG_BINARY_OP() return 7 @end
@fn AST_TAG_UNARY_OP() return 8 @end
@fn AST_TAG_CALL() return 9 @end
@fn AST_TAG_MEMBER_ACCESS() return 10 @end
@fn AST_TAG_INDEX() return 11 @end
@fn AST_TAG_PIPELINE() return 12 @end
@fn AST_TAG_ARRAY_LIT() return 13 @end
@fn AST_TAG_MAP_LIT() return 14 @end
@fn AST_TAG_CLOSURE() return 15 @end

// Statements (16..28)
@fn AST_TAG_ASSIGN() return 16 @end
@fn AST_TAG_ASSIGN_OP() return 17 @end
@fn AST_TAG_IF_STMT() return 18 @end
@fn AST_TAG_WHILE_LOOP() return 19 @end
@fn AST_TAG_FOR_LOOP() return 20 @end
@fn AST_TAG_RETURN() return 21 @end
@fn AST_TAG_BREAK() return 22 @end
@fn AST_TAG_CONTINUE() return 23 @end
@fn AST_TAG_EXPR_STMT() return 24 @end
@fn AST_TAG_BLOCK() return 25 @end
@fn AST_TAG_DEFER() return 26 @end
@fn AST_TAG_MATCH_STMT() return 27 @end
@fn AST_TAG_TRY_CATCH() return 28 @end

// Declarations (29..34)
@fn AST_TAG_FN_DEF() return 29 @end
@fn AST_TAG_STRUCT_DEF() return 30 @end
@fn AST_TAG_ENUM_DEF() return 31 @end
@fn AST_TAG_GLOBAL_VAR() return 32 @end
@fn AST_TAG_IMPORT() return 33 @end
@fn AST_TAG_PROGRAM() return 34 @end

// ── 2. Universal Base AST Node Struct ────────────────────────────────────────

// WHY: Unified 25-field node definition providing zero-collision layout compatible
// with both existing Lipi backend passes and high-speed Pratt parser micro-modules.
@struct ASTNode
  kind: string          // 0: Canonical node kind name (e.g. "BinaryOp", "IfStmt", "FnDef")
  name: string          // 1: Symbol / identifier / function name
  params: array         // 2: Parameter or field list
  body: array           // 3: Statements or method bodies
  ret_type: string      // 4: Return type annotation
  val: i64              // 5: Integer literal or bool value
  op: string            // 6: Operator string ("+", "==", etc.)
  left: ASTNode         // 7: Left child operand pointer
  right: ASTNode        // 8: Right child operand pointer
  expr: ASTNode         // 9: Expression operand pointer
  condition: ASTNode    // 10: Conditional expression pointer
  then_body: array      // 11: True branch statement list
  elif_branches: array  // 12: List of elif branch descriptors
  else_body: array      // 13: False branch statement list
  target: string        // 14: Assignment target name
  value: ASTNode        // 15: Assigned value or return value pointer
  elements: array       // 16: List elements, map entries, or match arms
  args: array           // 17: Call argument list
  func: ASTNode         // 18: Callee expression pointer
  variable: string      // 19: Loop iteration variable name
  iterable: ASTNode     // 20: Loop collection expression pointer
  index: ASTNode        // 21: Index expression pointer
  cond: ASTNode         // 22: While/If condition alias
  tag: i64              // 23: Fast integer tag for O(1) matching
  span: SourceSpan      // 24: Source span location coordinates
@end

// ── 3. Base Constructors & Initializers ───────────────────────────────────────

@fn ast_node_new(tag: i64, kind: string, span: SourceSpan)
  // WHY: Primary constructor allocating a pristine base AST node with tag and span
  return {
    kind: kind,
    name: "",
    params: [],
    body: [],
    ret_type: "void",
    val: 0,
    op: "",
    left: 0,
    right: 0,
    expr: 0,
    condition: 0,
    then_body: [],
    elif_branches: [],
    else_body: [],
    target: "",
    value: 0,
    elements: [],
    args: [],
    func: 0,
    variable: "",
    iterable: 0,
    index: 0,
    cond: 0,
    tag: tag,
    span: span
  }
@end

@fn ast_node(kind: string)
  // WHY: Legacy compatibility constructor defaulting to synthetic zero span and tag 0
  span = source_span_zero()
  return ast_node_new(AST_TAG_NONE(), kind, span)
@end

@fn ast_node_set_span(node: ASTNode, span: SourceSpan)
  // WHY: Attaches or updates source coordinates after parse tree reduction
  node.span = span
  return node
@end

// ── 4. Child Pointer Aggregation ──────────────────────────────────────────────

@fn ast_node_get_children(node: ASTNode)
  // WHY: Extracts all non-null child ASTNode references for generic tree walkers,
  // visitors, transformers, and printers.
  children = []
  @if node == 0 return children @end

  // Single-child pointers
  @if node.left != 0 children = children.push(node.left) @end
  @if node.right != 0 children = children.push(node.right) @end
  @if node.expr != 0 children = children.push(node.expr) @end
  @if node.condition != 0 children = children.push(node.condition) @end
  @if node.value != 0 children = children.push(node.value) @end
  @if node.func != 0 children = children.push(node.func) @end
  @if node.iterable != 0 children = children.push(node.iterable) @end
  @if node.index != 0 children = children.push(node.index) @end

  // Array child containers
  i = 0
  @if node.body != 0
    @while i < node.body.len()
      item = node.body[i]
      @if item != 0 children = children.push(item) @end
      i = i + 1
    @end
  @end

  i = 0
  @if node.then_body != 0
    @while i < node.then_body.len()
      item = node.then_body[i]
      @if item != 0 children = children.push(item) @end
      i = i + 1
    @end
  @end

  i = 0
  @if node.else_body != 0
    @while i < node.else_body.len()
      item = node.else_body[i]
      @if item != 0 children = children.push(item) @end
      i = i + 1
    @end
  @end

  i = 0
  @if node.args != 0
    @while i < node.args.len()
      item = node.args[i]
      @if item != 0 children = children.push(item) @end
      i = i + 1
    @end
  @end

  i = 0
  @if node.elements != 0
    @while i < node.elements.len()
      item = node.elements[i]
      @if item != 0 children = children.push(item) @end
      i = i + 1
    @end
  @end

  return children
@end

// ── 5. Standard Getters & Introspection ────────────────────────────────────────

@fn ast_get_kind(node: ASTNode)
  @if node == 0 return "" @end
  return node.kind
@end

@fn ast_get_tag(node: ASTNode)
  @if node == 0 return 0 @end
  return node.tag
@end

@fn ast_get_name(node: ASTNode)
  @if node == 0 return "" @end
  return node.name
@end

@fn ast_get_op(node: ASTNode)
  @if node == 0 return "" @end
  return node.op
@end

@fn ast_get_val(node: ASTNode)
  @if node == 0 return 0 @end
  return node.val
@end

@fn ast_get_ret_type(node: ASTNode)
  @if node == 0 return "" @end
  return node.ret_type
@end

@fn ast_get_left(node: ASTNode) return node.left @end
@fn ast_get_right(node: ASTNode) return node.right @end
@fn ast_get_expr(node: ASTNode) return node.expr @end
@fn ast_get_condition(node: ASTNode) return node.condition @end
@fn ast_get_value(node: ASTNode) return node.value @end
@fn ast_get_body(node: ASTNode) return node.body @end
@fn ast_get_params(node: ASTNode) return node.params @end
@fn ast_get_args(node: ASTNode) return node.args @end
@fn ast_get_elements(node: ASTNode) return node.elements @end
@fn ast_get_target(node: ASTNode) return node.target @end
@fn ast_get_variable(node: ASTNode) return node.variable @end
@fn ast_get_iterable(node: ASTNode) return node.iterable @end
@fn ast_get_index(node: ASTNode) return node.index @end
@fn ast_get_func(node: ASTNode) return node.func @end
@fn ast_get_span(node: ASTNode) return node.span @end
