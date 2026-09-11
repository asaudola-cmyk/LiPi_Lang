@! ============================================================================
@! ADVERSARIAL BUG REPRODUCTION: STRUCT FIELD COLLISION IN UNTYPED CALLS
@! ============================================================================
@! When multiple structs share a field name at different field offsets/indices
@! (e.g. BSTNode has 'left' at index 1, ExprAST has 'left' at index 3),
@! an untyped function parameter accessing 'node.left' resolves to the first
@! matching struct in the symbol table (index 1), corrupting memory reads
@! for any subsequent struct (causing offset misread or NULL deref segfault).

@struct BSTNode
  val: 0
  left: 0
  right: 0
@end

@struct ExprAST
  kind: 0
  num_val: 0
  op_code: 0
  left: 0
  right: 0
@end

@fn get_left_child(node)
  return node.left
@end

@fn main()
  let child = { val: 99, left: 0, right: 0 }
  let parent_expr = { kind: 2, num_val: 100, op_code: 1, left: child, right: 0 }

  let extracted_child = get_left_child(parent_expr)

  @! parent_expr.left is child (which has val 99).
  @! But if it reads index 1 (num_val = 100), extracted_child will be 100, or dereferencing extracted_child.val will fail!
  println("Extracted child: " + extracted_child.to_str())
  @if extracted_child == child
    println("PASS: Field index resolved correctly")
    return 0
  @else
    println("FAIL: Field index resolved to wrong offset due to name collision in symbol table")
    return 1
  @end
@end
