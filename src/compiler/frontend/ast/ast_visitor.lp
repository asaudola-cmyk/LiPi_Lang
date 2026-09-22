// ============================================================================
// LIPI FRONTEND COMPILER — NON-RECURSIVE STACK VISITOR INTERFACE
// Module: src/compiler/frontend/ast/ast_visitor.lp
// Standard: Lipi First 1.0.0 (প্রথম ১.০.০)
// 100% Pure Lipi | Zero C | Zero Libc | Zero External Dependencies
// ============================================================================
//
// WHY THIS MODULE:
// 1. Hardware Stack Safety: Recursive tree traversals risk stack overflow when
//    analyzing deeply nested AST trees (e.g. 5,000 chained binary expressions or
//    deeply nested if/else blocks).
// 2. Linear Memory Footprint: A non-recursive visitor manages an explicit heap-allocated
//    worklist stack (`vis_stack = []`), enabling arbitrarily deep traversals without
//    exhausting physical CPU call frames.
// 3. Pre-Order & Search Primitives: Implements iterative DFS traversal, node counting,
//    kind-based queries (`find_by_kind`), identifier collection, and call analysis.
// ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "compiler/frontend/lexer/token"
import "compiler/frontend/ast/ast_node"

// ── 1. Visitor Context Structure ──────────────────────────────────────────────

// WHY: Context container maintaining worklist stack and traversal state with zero-collision schema
@struct ASTVisitorContext
  vis_stack: array
  vis_visited_count: i64
  vis_max_depth: i64
  vis_results: array
@end

// ── 2. Constructor ────────────────────────────────────────────────────────────

@fn ast_visitor_new()
  // WHY: Allocates a clean non-recursive visitor state
  return {
    vis_stack: [],
    vis_visited_count: 0,
    vis_max_depth: 0,
    vis_results: []
  }
@end

// ── 3. Non-Recursive Pre-Order Tree Walker ─────────────────────────────────────

@fn ast_visitor_walk(root: ASTNode, visitor_fn)
  // WHY: Iterative DFS pre-order traversal visiting root and all descendants.
  // Pushes children in reverse order so the leftmost child is popped and processed first.
  @if root == 0 return 0 @end

  work_stack = []
  work_stack = work_stack.push(root)
  visited_count = 0

  @while work_stack.len() > 0
    // Pop top node from worklist stack
    last_idx = work_stack.len() - 1
    cur_node = work_stack[last_idx]
    work_stack = pop(work_stack)

    @if cur_node != 0
      // Execute visitor callback on current node
      visitor_fn(cur_node)
      visited_count = visited_count + 1

      // Aggregate all non-null child references
      children = ast_node_get_children(cur_node)
      num_children = children.len()

      // Push children in reverse order onto worklist
      i = num_children - 1
      @while i >= 0
        child = children[i]
        @if child != 0
          work_stack = work_stack.push(child)
        @end
        i = i - 1
      @end
    @end
  @end

  return visited_count
@end

// ── 4. Non-Recursive Node Counter ─────────────────────────────────────────────

@fn ast_visitor_count_nodes(root: ASTNode)
  // WHY: Non-recursively counts total number of AST nodes in the subtree
  @if root == 0 return 0 @end

  work_stack = []
  work_stack = work_stack.push(root)
  total_count = 0

  @while work_stack.len() > 0
    last_idx = work_stack.len() - 1
    cur_node = work_stack[last_idx]
    work_stack = pop(work_stack)

    @if cur_node != 0
      total_count = total_count + 1
      children = ast_node_get_children(cur_node)
      num_children = children.len()

      i = 0
      @while i < num_children
        child = children[i]
        @if child != 0
          work_stack = work_stack.push(child)
        @end
        i = i + 1
      @end
    @end
  @end

  return total_count
@end

// ── 5. Non-Recursive Filter By Node Kind ──────────────────────────────────────

@fn ast_visitor_find_by_kind(root: ASTNode, target_kind: string)
  // WHY: Gathers all AST nodes of a specific kind (e.g. "Call" or "FnDef")
  // without risking native call stack exhaustion.
  matches = []
  @if root == 0 return matches @end

  work_stack = []
  work_stack = work_stack.push(root)

  @while work_stack.len() > 0
    last_idx = work_stack.len() - 1
    cur_node = work_stack[last_idx]
    work_stack = pop(work_stack)

    @if cur_node != 0
      @if cur_node.kind == target_kind
        matches = matches.push(cur_node)
      @end

      children = ast_node_get_children(cur_node)
      num_children = children.len()

      i = 0
      @while i < num_children
        child = children[i]
        @if child != 0
          work_stack = work_stack.push(child)
        @end
        i = i + 1
      @end
    @end
  @end

  return matches
@end

// ── 6. Non-Recursive Identifier Collector ─────────────────────────────────────

@fn ast_visitor_collect_idents(root: ASTNode)
  // WHY: Extracts all variable and identifier names referenced throughout the subtree.
  // Useful for linter scoping, unused variable analysis, and register allocation.
  idents = []
  @if root == 0 return idents @end

  work_stack = []
  work_stack = work_stack.push(root)

  @while work_stack.len() > 0
    last_idx = work_stack.len() - 1
    cur_node = work_stack[last_idx]
    work_stack = pop(work_stack)

    @if cur_node != 0
      @if cur_node.kind == "Variable" && cur_node.name != ""
        idents = idents.push(cur_node.name)
      @end

      children = ast_node_get_children(cur_node)
      num_children = children.len()

      i = 0
      @while i < num_children
        child = children[i]
        @if child != 0
          work_stack = work_stack.push(child)
        @end
        i = i + 1
      @end
    @end
  @end

  return idents
@end

// ── 7. Non-Recursive Call Target Collector ────────────────────────────────────

@fn ast_visitor_collect_calls(root: ASTNode)
  // WHY: Extracts all function call names invoked within the subtree for call graph generation
  calls = []
  @if root == 0 return calls @end

  work_stack = []
  work_stack = work_stack.push(root)

  @while work_stack.len() > 0
    last_idx = work_stack.len() - 1
    cur_node = work_stack[last_idx]
    work_stack = pop(work_stack)

    @if cur_node != 0
      @if cur_node.kind == "Call" && cur_node.name != ""
        calls = calls.push(cur_node.name)
      @end

      children = ast_node_get_children(cur_node)
      num_children = children.len()

      i = 0
      @while i < num_children
        child = children[i]
        @if child != 0
          work_stack = work_stack.push(child)
        @end
        i = i + 1
      @end
    @end
  @end

  return calls
@end
