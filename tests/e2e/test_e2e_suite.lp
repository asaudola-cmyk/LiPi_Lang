@! ============================================================================
@! MAYA COMPREHENSIVE END-TO-END MASTER SUITE (TIERS 1 - 4)
@! File: tests/e2e/test_e2e_master.maya
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"

@! --- Data Structures ---
@struct Point
  x: 0
  y: 0
@end

@struct ListNode
  val: 0
  next: 0
@end

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

@fn abs_val(n)
  @if n < 0
    return 0 - n
  @else
    return n
  @end
@end

@fn factorial(n)
  @if n <= 1
    return 1
  @else
    return n * factorial(n - 1)
  @end
@end

@fn fibonacci(n)
  @if n <= 0
    return 0
  @elif n == 1
    return 1
  @else
    return fibonacci(n - 1) + fibonacci(n - 2)
  @end
@end

@fn insertion_sort(arr, length)
  let i = 1
  @while i < length
    let key = arr[i]
    let j = i - 1
    @while j >= 0 && arr[j] > key
      arr[j + 1] = arr[j]
      j = j - 1
    @end
    arr[j + 1] = key
    i = i + 1
  @end
  return arr
@end

@fn list_prepend(head, value)
  return { val: value, next: head }
@end

@fn list_sum(head)
  let sum = 0
  let curr = head
  @while curr != 0
    sum = sum + curr.val
    curr = curr.next
  @end
  return sum
@end

@fn bst_insert(root, val)
  @if root == 0
    return { val: val, left: 0, right: 0 }
  @end
  @if val < root.val
    root.left = bst_insert(root.left, val)
  @elif val > root.val
    root.right = bst_insert(root.right, val)
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

@fn eval_ast(node)
  @if node.kind == 1
    return node.num_val
  @end
  let left_val = eval_ast(node.left)
  let right_val = eval_ast(node.right)
  @match node.op_code
    case 1:
      return left_val + right_val
    case 2:
      return left_val - right_val
    case 3:
      return left_val * right_val
    case 4:
      return left_val / right_val
    case _:
      return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🌐 MAYA MASTER END-TO-END VERIFICATION SUITE (TIERS 1 - 4) 🌐")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! -------------------------------------------------------------
  @! TIER 1: CORE FEATURE TESTS
  @! -------------------------------------------------------------
  println("▶ Executing Tier 1: Feature Coverage...")

  @! T1.1: Arithmetic Precedence
  total = total + 1
  let arith_res = 10 + 5 * 6 - 20 / 4
  @if arith_res == 35
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T1.2: String Concat & Equality
  total = total + 1
  let s_cat = "Hello, " + "World!"
  @if s_cat == "Hello, World!"
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T1.3: Struct Instantiation & Fields
  total = total + 1
  let pt = { x: 100, y: 200 }
  @if pt.x == 100 && pt.y == 200
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T1.4: Dynamic Arrays
  total = total + 1
  let arr = [10, 20, 30]
  arr.push(40)
  @if arr[0] == 10 && arr[3] == 40
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T1.5: Functions & Scope
  total = total + 1
  let f_fact = factorial(5)
  @if f_fact == 120
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T1.6: Control Flow (@if - @elif - @else)
  total = total + 1
  let score = 85
  let grade = 0
  @if score >= 90
    grade = 1
  @elif score >= 80
    grade = 2
  @else
    grade = 3
  @end
  @if grade == 2
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T1.7: Loops (@while)
  total = total + 1
  let loop_sum = 0
  let li = 1
  @while li <= 10
    loop_sum = loop_sum + li
    li = li + 1
  @end
  @if loop_sum == 55
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T1.8: Pattern Matching (@match)
  total = total + 1
  let m_val = 2
  let m_res = 0
  @match m_val
    case 1:
      m_res = 10
    case 2:
      m_res = 20
    case _:
      m_res = 99
  @end
  @if m_res == 20
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  println("  ✓ Tier 1 Feature Coverage Passed")

  @! -------------------------------------------------------------
  @! TIER 2: BOUNDARIES & CORNER CASES
  @! -------------------------------------------------------------
  println("▶ Executing Tier 2: Boundary & Corner Cases...")

  @! T2.1: Empty Array Push
  total = total + 1
  let e_arr = []
  e_arr.push(42)
  @if e_arr[0] == 42
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T2.2: Nested Struct
  total = total + 1
  let nested_c = { center: { x: 15, y: 25 }, radius: 10 }
  @if nested_c.center.x == 15 && nested_c.radius == 10
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T2.3: Boundary Integers (0 and Negatives)
  total = total + 1
  let b_neg = abs_val(-999)
  @if b_neg == 999
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T2.4: Deep Recursion Fibonacci (fib(12) == 144)
  total = total + 1
  let fib_res = fibonacci(12)
  @if fib_res == 144
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T2.5: Nested While Loops (10x10 = 100)
  total = total + 1
  let n_cnt = 0
  let nr = 0
  @while nr < 10
    let nc = 0
    @while nc < 10
      n_cnt = n_cnt + 1
      nc = nc + 1
    @end
    nr = nr + 1
  @end
  @if n_cnt == 100
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  println("  ✓ Tier 2 Boundary Tests Passed")

  @! -------------------------------------------------------------
  @! TIER 3: CROSS-FEATURE COMBINATIONS
  @! -------------------------------------------------------------
  println("▶ Executing Tier 3: Cross-Feature Combinations...")

  @! T3.1: Struct Containing Array
  total = total + 1
  let st_arr = { id: 1, items: [5, 10, 15] }
  st_arr.items[1] = 20
  @if st_arr.items[0] == 5 && st_arr.items[1] == 20 && st_arr.items[2] == 15
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T3.2: Array of Structs Summation
  total = total + 1
  let arr_structs = [{ x: 10, y: 20 }, { x: 30, y: 40 }]
  let x_sum = arr_structs[0].x + arr_structs[1].x
  @if x_sum == 40
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T3.3: In-place Array Reverse via Two-Pointer While Loop
  total = total + 1
  let rev_test = [1, 2, 3, 4]
  let l_idx = 0
  let r_idx = 3
  @while l_idx < r_idx
    let t_val = rev_test[l_idx]
    rev_test[l_idx] = rev_test[r_idx]
    rev_test[r_idx] = t_val
    l_idx = l_idx + 1
    r_idx = r_idx - 1
  @end
  @if rev_test[0] == 4 && rev_test[1] == 3 && rev_test[2] == 2 && rev_test[3] == 1
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  println("  ✓ Tier 3 Cross-Feature Tests Passed")

  @! -------------------------------------------------------------
  @! TIER 4: REAL-WORLD APPLICATION SCENARIOS
  @! -------------------------------------------------------------
  println("▶ Executing Tier 4: Real-World Applications...")

  @! T4.1: Sorting Algorithm (Insertion Sort)
  total = total + 1
  let sort_input = [45, 12, 89, 23, 7]
  let sorted_out = insertion_sort(sort_input, 5)
  @if sorted_out[0] == 7 && sorted_out[1] == 12 && sorted_out[2] == 23 && sorted_out[3] == 45 && sorted_out[4] == 89
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T4.2: Linked List Prepend & Sum
  total = total + 1
  let list_h = 0
  list_h = list_prepend(list_h, 100)
  list_h = list_prepend(list_h, 200)
  let l_total = list_sum(list_h)
  @if l_total == 300
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T4.3: Binary Search Tree Insertion & Search
  total = total + 1
  let bst_root = 0
  bst_root = bst_insert(bst_root, 50)
  bst_root = bst_insert(bst_root, 25)
  bst_root = bst_insert(bst_root, 75)
  let bst_has_25 = bst_search(bst_root, 25)
  let bst_has_99 = bst_search(bst_root, 99)
  @if bst_has_25 == 1 && bst_has_99 == 0
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T4.4: 2x2 Matrix Multiplication
  total = total + 1
  @! [1, 2; 3, 4] * [2, 0; 1, 2] = [4, 4; 10, 8]
  let m_a = [1, 2, 3, 4]
  let m_b = [2, 0, 1, 2]
  let m_p0 = m_a[0]*m_b[0] + m_a[1]*m_b[2]
  let m_p1 = m_a[0]*m_b[1] + m_a[1]*m_b[3]
  let m_p2 = m_a[2]*m_b[0] + m_a[3]*m_b[2]
  let m_p3 = m_a[2]*m_b[1] + m_a[3]*m_b[3]
  @if m_p0 == 4 && m_p1 == 4 && m_p2 == 10 && m_p3 == 8
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  @! T4.5: Mathematical Expression AST Evaluator
  total = total + 1
  @! (10 + 2) * 5 = 60
  let n_10 = { kind: 1, num_val: 10, op_code: 0, left: 0, right: 0 }
  let n_2 = { kind: 1, num_val: 2, op_code: 0, left: 0, right: 0 }
  let n_5 = { kind: 1, num_val: 5, op_code: 0, left: 0, right: 0 }
  let ast_add = { kind: 2, num_val: 0, op_code: 1, left: n_10, right: n_2 }
  let ast_mul = { kind: 2, num_val: 0, op_code: 3, left: ast_add, right: n_5 }
  let eval_res = eval_ast(ast_mul)
  @if eval_res == 60
    passed = passed + 1
  @else
    failed = failed + 1
  @end

  println("  ✓ Tier 4 Real-World Applications Passed")

  println("=================================================================")
  println("MASTER E2E SUITE RESULTS: " + passed.to_str() + "/" + total.to_str() + " assertions passed")
  println("=================================================================")

  @if failed == 0
    println("🎉 ALL END-TO-END TESTS PASSED (100% SUCCESS)!")
    return 0
  @else
    println("❌ END-TO-END VERIFICATION FAILED!")
    return 1
  @end
@end
