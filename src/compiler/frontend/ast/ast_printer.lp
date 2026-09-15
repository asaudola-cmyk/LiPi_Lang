// ============================================================================
// LIPI FRONTEND COMPILER — VISUAL AST TREE PRINTER
// Module: src/compiler/frontend/ast/ast_printer.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. AST Visualization: Renders intuitive ASCII/Unicode tree hierarchies (using
//    `├── `, `└── `, and `│   ` branch guides) for compiler pipeline debugging,
//    verification test output, and developer inspection.
// 2. High Diagnostic Fidelity: Formats node-specific metadata (operators, literal values,
//    identifiers, return types, and source spans) directly onto each tree branch.
// 3. Program Structure Printing: Provides dedicated formatters for entire `ASTProgram`
//    units, cleanly rendering imports, struct definitions, functions, and top-level code.
// ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/lexer/token"
import "compiler/frontend/ast/ast_node"
import "compiler/frontend/ast/ast_decl"

// ── 1. Node Label Formatter ───────────────────────────────────────────────────

@fn ast_format_node_label(node: ASTNode)
  // WHY: Synthesizes a compact, informative text badge for any ASTNode
  @if node == 0 return "<null>" @end

  k = node.kind
  label = k

  // Enrich label with node-specific values
  @if k == "LiteralInt"
    label = "LiteralInt(" + to_str(node.val) + ")"
  @elif k == "LiteralFloat"
    label = "LiteralFloat"
  @elif k == "LiteralStr"
    label = "LiteralStr(\"" + node.name + "\")"
  @elif k == "LiteralBool"
    b_text = "false"
    @if node.val == 1 b_text = "true" @end
    label = "LiteralBool(" + b_text + ")"
  @elif k == "LiteralNone"
    label = "LiteralNone"
  @elif k == "Variable"
    label = "Variable(" + node.name + ")"
  @elif k == "BinaryOp"
    label = "BinaryOp('" + node.op + "')"
  @elif k == "UnaryOp"
    label = "UnaryOp('" + node.op + "')"
  @elif k == "Call"
    label = "Call(" + node.name + ")"
  @elif k == "MemberAccess"
    label = "MemberAccess(." + node.name + ")"
  @elif k == "Index"
    label = "Index"
  @elif k == "Pipeline"
    label = "Pipeline(|>)"
  @elif k == "ArrayLit"
    label = "ArrayLit"
  @elif k == "MapLit"
    label = "MapLit"
  @elif k == "Assign"
    label = "Assign(" + node.target + ")"
  @elif k == "AssignOp"
    label = "AssignOp(" + node.target + " " + node.op + ")"
  @elif k == "IfStmt"
    label = "IfStmt"
  @elif k == "WhileLoop"
    label = "WhileLoop"
  @elif k == "ForLoop"
    label = "ForLoop(" + node.variable + ")"
  @elif k == "Return"
    label = "Return"
  @elif k == "Break"
    label = "Break"
  @elif k == "Continue"
    label = "Continue"
  @elif k == "ExpressionStmt"
    label = "ExpressionStmt"
  @elif k == "Block"
    label = "Block"
  @elif k == "Defer"
    label = "Defer"
  @elif k == "FnDef"
    label = "FnDef(" + node.name + " -> " + node.ret_type + ")"
  @elif k == "StructDef"
    label = "StructDef(" + node.name + ")"
  @elif k == "EnumDef"
    label = "EnumDef(" + node.name + ")"
  @elif k == "Import"
    label = "Import(\"" + node.name + "\")"
  @end

  // Append source coordinates if available
  @if node.span.span_start_line > 0
    label = label + " [" + to_str(node.span.span_start_line) + ":" + to_str(node.span.span_start_col) + "]"
  @end

  return label
@end

// ── 2. Recursive Tree Formatter ───────────────────────────────────────────────

@fn ast_print_subtree(node: ASTNode, prefix: string, is_tail: i64)
  // WHY: Renders formatted branch with connecting pipes and branch marks
  @if node == 0 return "" @end

  branch_mark = "├── "
  @if is_tail == 1
    branch_mark = "└── "
  @end

  line_str = prefix + branch_mark + ast_format_node_label(node) + "\n"

  // Compute indentation prefix for children
  child_prefix = prefix + "│   "
  @if is_tail == 1
    child_prefix = prefix + "    "
  @end

  children = ast_node_get_children(node)
  n = children.len()
  i = 0
  @while i < n
    child = children[i]
    is_child_tail = 0
    @if i == n - 1
      is_child_tail = 1
    @end
    child_str = ast_print_subtree(child, child_prefix, is_child_tail)
    line_str = line_str + child_str
    i = i + 1
  @end

  return line_str
@end

// ── 3. Public Visualization Interfaces ────────────────────────────────────────

@fn ast_print_tree(root: ASTNode)
  // WHY: Returns full formatted ASCII tree string for any AST subtree
  @if root == 0 return "<empty AST>\n" @end
  root_label = ast_format_node_label(root) + "\n"
  children = ast_node_get_children(root)
  n = children.len()
  res = root_label
  i = 0
  @while i < n
    child = children[i]
    is_tail = 0
    @if i == n - 1
      is_tail = 1
    @end
    child_str = ast_print_subtree(child, "", is_tail)
    res = res + child_str
    i = i + 1
  @end
  return res
@end

@fn ast_print_program(prog: ASTProgram)
  // WHY: Produces formatted visual report of all declarations inside an ASTProgram unit
  @if prog == 0 return "<null program>\n" @end

  res = "Program Root:\n"

  // 1. Imports
  i = 0
  n = prog.prog_imports.len()
  @if n > 0
    res = res + "├── Imports (" + to_str(n) + ")\n"
    @while i < n
      imp = prog.prog_imports[i]
      is_tail = 0
      @if i == n - 1 is_tail = 1 @end
      res = res + ast_print_subtree(imp, "│   ", is_tail)
      i = i + 1
    @end
  @end

  // 2. Structs
  i = 0
  n = prog.prog_structs.len()
  @if n > 0
    res = res + "├── Structs (" + to_str(n) + ")\n"
    @while i < n
      st = prog.prog_structs[i]
      is_tail = 0
      @if i == n - 1 is_tail = 1 @end
      res = res + ast_print_subtree(st, "│   ", is_tail)
      i = i + 1
    @end
  @end

  // 3. Functions
  i = 0
  n = prog.prog_functions.len()
  @if n > 0
    res = res + "└── Functions (" + to_str(n) + ")\n"
    @while i < n
      f = prog.prog_functions[i]
      is_tail = 0
      @if i == n - 1 is_tail = 1 @end
      res = res + ast_print_subtree(f, "    ", is_tail)
      i = i + 1
    @end
  @end

  return res
@end

@fn ast_dump(root: ASTNode)
  // WHY: Direct debug dumper emitting AST hierarchy to console
  s = ast_print_tree(root)
  println(s)
  return 0
@end
