@! ============================================================================
@! MAYA ADVERSARIAL STRESS: LONG-RUNNING COMBINED APPLICATION WORKLOAD
@! File: tests/e2e/test_long_running_workload_stress.maya
@! Scope: BST, Matrix Math, Lexical Tokenizer, AST Evaluator under active GC
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Binary Search Tree Data Structure
@! ----------------------------------------------------------------------------
@struct BSTNode
  val: 0
  left: 0
  right: 0
@end

@fn bst_insert(root, v)
  @if root == 0
    return { val: v, left: 0, right: 0 }
  @end
  @if v < root.val
    root.left = bst_insert(root.left, v)
  @elif v > root.val
    root.right = bst_insert(root.right, v)
  @end
  return root
@end

@fn bst_search(root, target)
  @if root == 0
    return 0
  @end
  @if root.val == target
    return 1
  @elif target < root.val
    return bst_search(root.left, target)
  @else
    return bst_search(root.right, target)
  @end
@end

@fn bst_inorder(root, arr)
  @if root == 0
    return arr
  @end
  arr = bst_inorder(root.left, arr)
  arr = arr.push(root.val)
  arr = bst_inorder(root.right, arr)
  return arr
@end

@! ----------------------------------------------------------------------------
@! 2. Matrix Mathematics & Transformations
@! ----------------------------------------------------------------------------
@fn mat3_mul(a, b)
  res = []
  r = 0
  @while r < 3
    c = 0
    @while c < 3
      sum = 0
      k = 0
      @while k < 3
        sum = sum + a[r * 3 + k] * b[k * 3 + c]
        k = k + 1
      @end
      res = res.push(sum)
      c = c + 1
    @end
    r = r + 1
  @end
  return res
@end

@fn mat3_transpose(m)
  t = [0, 0, 0, 0, 0, 0, 0, 0, 0]
  r = 0
  @while r < 3
    c = 0
    @while c < 3
      t = list_set(t, c * 3 + r, m[r * 3 + c])
      c = c + 1
    @end
    r = r + 1
  @end
  return t
@end

@fn mat3_det(m)
  a = m[0]
  b = m[1]
  c = m[2]
  d = m[3]
  e = m[4]
  f = m[5]
  g = m[6]
  h = m[7]
  i = m[8]

  t1 = a * (e * i - f * h)
  t2 = b * (d * i - f * g)
  t3 = c * (d * h - e * g)
  return t1 - t2 + t3
@end

@! ----------------------------------------------------------------------------
@! 3. Lexical Tokenizer
@! ----------------------------------------------------------------------------
@struct Token
  type_id: 0  @! 1=INT, 3=PLUS, 4=STAR, 5=MINUS, 6=SLASH, 7=LPAREN, 8=RPAREN
  int_val: 0
@end

@fn tokenize_expr(str_stream, len)
  tokens = []
  i = 0
  @while i < len
    ch = str_stream[i]
    @if ch == 32  @! Space
      i = i + 1
    @elif ch >= 48 && ch <= 57
      tokens = tokens.push({ type_id: 1, int_val: ch - 48 })
      i = i + 1
    @elif ch == 43  @! +
      tokens = tokens.push({ type_id: 3, int_val: 0 })
      i = i + 1
    @elif ch == 42  @! *
      tokens = tokens.push({ type_id: 4, int_val: 0 })
      i = i + 1
    @elif ch == 45  @! -
      tokens = tokens.push({ type_id: 5, int_val: 0 })
      i = i + 1
    @elif ch == 47  @! /
      tokens = tokens.push({ type_id: 6, int_val: 0 })
      i = i + 1
    @elif ch == 40  @! (
      tokens = tokens.push({ type_id: 7, int_val: 0 })
      i = i + 1
    @elif ch == 41  @! )
      tokens = tokens.push({ type_id: 8, int_val: 0 })
      i = i + 1
    @else
      i = i + 1
    @end
  @end
  return tokens
@end

@! ----------------------------------------------------------------------------
@! 4. AST Expression Evaluator
@! ----------------------------------------------------------------------------
@struct ASTNode
  kind: 0     @! 1=Num, 2=BinOp
  num_val: 0
  op_code: 0  @! 1=+, 2=-, 3=*, 4=/
  left: 0
  right: 0
@end

@fn make_num(val)
  return { kind: 1, num_val: val, op_code: 0, left: 0, right: 0 }
@end

@fn make_op(op, l, r)
  return { kind: 2, num_val: 0, op_code: op, left: l, right: r }
@end

@fn eval_tree(node)
  @if node.kind == 1
    return node.num_val
  @end
  lv = eval_tree(node.left)
  rv = eval_tree(node.right)
  @if node.op_code == 1
    return lv + rv
  @elif node.op_code == 2
    return lv - rv
  @elif node.op_code == 3
    return lv * rv
  @elif node.op_code == 4
    return lv / rv
  @else
    return 0
  @end
@end

@! ----------------------------------------------------------------------------
@! Combined Stress Loop
@! ----------------------------------------------------------------------------
@fn run_combined_stress_iteration(iter)
  p = 0
  f = 0

  @! 1. Binary Search Tree Stress
  root = 0
  values = [42, 17, 89, 5, 23, 67, 99, 12, 34, 56, 78, 90, 3, 19, 45]
  v_idx = 0
  @while v_idx < 15
    root = bst_insert(root, values[v_idx])
    v_idx = v_idx + 1
  @end

  @! Verify all 15 elements exist in BST
  all_found = 1
  v_idx = 0
  @while v_idx < 15
    @if bst_search(root, values[v_idx]) == 0
      all_found = 0
    @end
    v_idx = v_idx + 1
  @end
  @if all_found != 0 p = p + 1 @else f = f + 1 @end

  @! Verify missing element is rejected
  @if bst_search(root, 1000 + iter) == 0 p = p + 1 @else f = f + 1 @end

  @! In-order traversal must be strictly monotonic increasing
  inorder = []
  inorder = bst_inorder(root, inorder)
  @if inorder.len() == 15 p = p + 1 @else f = f + 1 @end
  monotonic = 1
  k = 0
  @while k < 14
    @if inorder[k] >= inorder[k + 1]
      monotonic = 0
    @end
    k = k + 1
  @end
  @if monotonic != 0 p = p + 1 @else f = f + 1 @end

  @! 2. Matrix Multiplication & Invariant Stress
  m1 = [1, 2, 0, 0, 1, 1, 2, 0, 1]
  m2 = [0, 1, 2, 1, 2, 0, 2, 0, 1]
  prod = mat3_mul(m1, m2)
  @if prod[0] == 2 p = p + 1 @else f = f + 1 @end
  @if prod[4] == 2 p = p + 1 @else f = f + 1 @end
  @if prod[8] == 5 p = p + 1 @else f = f + 1 @end

  @! Invariant: det(M) == det(M^T)
  det_orig = mat3_det(m1)
  m1_t = mat3_transpose(m1)
  det_trans = mat3_det(m1_t)
  @if det_orig == det_trans p = p + 1 @else f = f + 1 @end

  @! 3. Lexical Tokenizer Stress
  stream = [55, 32, 43, 32, 51, 32, 42, 32, 40, 56, 32, 45, 32, 50, 41, 32, 47, 32, 50]
  tokens = tokenize_expr(stream, 19)
  @if tokens.len() == 11 p = p + 1 @else f = f + 1 @end
  @if tokens[0].int_val == 7 p = p + 1 @else f = f + 1 @end

  @! 4. AST Expression Tree Evaluator: ((10 + 5) * 4 - 12) / 3 = 16
  n10 = make_num(10)
  n5 = make_num(5)
  n4 = make_num(4)
  n12 = make_num(12)
  n3 = make_num(3)

  t_add = make_op(1, n10, n5)      @! 10 + 5 = 15
  t_mul = make_op(3, t_add, n4)    @! 15 * 4 = 60
  t_sub = make_op(2, t_mul, n12)   @! 60 - 12 = 48
  t_div = make_op(4, t_sub, n3)    @! 48 / 3 = 16

  res = eval_tree(t_div)
  @if res == 16 p = p + 1 @else f = f + 1 @end

  return [p + f, p, f]
@end

@fn main()
  println("=================================================================")
  println("▶ MAYA LONG-RUNNING WORKLOAD STRESS: BST, MATRIX, TOKENIZER, AST")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  println("Executing 100 comprehensive multi-domain workload stress iterations...")
  iter = 0
  @while iter < 100
    res = run_combined_stress_iteration(iter)
    total = total + res[0]
    passed = passed + res[1]
    failed = failed + res[2]
    iter = iter + 1
  @end

  println("=================================================================")
  println("📊 WORKLOAD STRESS AUDIT SUMMARY")
  println("=================================================================")
  println("  Total Executed Assertions : " + maya_int_to_str(total))
  println("  Passed                    : " + maya_int_to_str(passed))
  println("  Failed                    : " + maya_int_to_str(failed))

  @if failed == 0
    println("✓ [VERDICT: APPROVE] 100% of Long-Running Application Stress Assertions PASSED!")
    return 0
  @else
    println("✗ [VERDICT: REQUEST_CHANGES] Failures detected in application stress.")
    return 1
  @end
@end
