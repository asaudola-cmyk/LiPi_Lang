@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP 2: LINKED LIST & BINARY SEARCH TREE
@! File: tests/e2e/tier4_applications/test_linked_list_bst.maya
@! ============================================================================

import "universe/core/collections"

@struct ListNode
  val: 0
  next: 0
@end

@struct BSTNode
  val: 0
  left: 0
  right: 0
@end

@fn list_prepend(head, value)
  return { val: value, next: head }
@end

@fn list_sum(head)
  sum = 0
  curr = head
  @while curr != 0
    sum = sum + curr.val
    curr = curr.next
  @end
  return sum
@end

@fn list_contains(head, target)
  curr = head
  @while curr != 0
    @if curr.val == target
      return 1
    @end
    curr = curr.next
  @end
  return 0
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

@fn bst_inorder(root, out_arr)
  @if root == 0
    return out_arr
  @end
  bst_inorder(root.left, out_arr)
  out_arr.push(root.val)
  bst_inorder(root.right, out_arr)
  return out_arr
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Application 2: Linked List & Binary Search Tree (BST)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T4.2.1: Linked List Creation via Prepending
  total = total + 1
  head = 0
  head = list_prepend(head, 10)
  head = list_prepend(head, 20)
  head = list_prepend(head, 30)
  @! List is: 30 -> 20 -> 10 -> 0
  @if head.val == 30 && head.next.val == 20 && head.next.next.val == 10
    passed = passed + 1
    println("  [PASS] T4.2.1: Linked list prepend node construction (30 -> 20 -> 10)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2.1: Linked list prepend node construction")
  @end

  @! T4.2.2: Linked List Traversal and Summation
  total = total + 1
  @! 30 + 20 + 10 = 60
  l_sum = list_sum(head)
  @if l_sum == 60
    passed = passed + 1
    println("  [PASS] T4.2.2: Linked list traversal and summation (sum == 60)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2.2: Linked list traversal and summation")
  @end

  @! T4.2.3: Linked List Search
  total = total + 1
  has_20 = list_contains(head, 20)
  has_99 = list_contains(head, 99)
  @if has_20 == 1 && has_99 == 0
    passed = passed + 1
    println("  [PASS] T4.2.3: Linked list linear search (found 20, rejected 99)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2.3: Linked list linear search")
  @end

  @! T4.2.4: Binary Search Tree Insertion and Search
  total = total + 1
  root = 0
  root = bst_insert(root, 50)
  root = bst_insert(root, 30)
  root = bst_insert(root, 70)
  root = bst_insert(root, 20)
  root = bst_insert(root, 40)
  root = bst_insert(root, 60)
  root = bst_insert(root, 80)
  found_60 = bst_search(root, 60)
  found_25 = bst_search(root, 25)
  @if found_60 == 1 && found_25 == 0
    passed = passed + 1
    println("  [PASS] T4.2.4: BST insertion and search (found 60, rejected 25)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2.4: BST insertion and search")
  @end

  @! T4.2.5: BST In-Order Traversal (Sorted Output Generation)
  total = total + 1
  inorder_result = []
  inorder_result = bst_inorder(root, inorder_result)
  @! In-order of [50, 30, 70, 20, 40, 60, 80] is [20, 30, 40, 50, 60, 70, 80]
  @if inorder_result[0] == 20 && inorder_result[3] == 50 && inorder_result[6] == 80
    passed = passed + 1
    println("  [PASS] T4.2.5: BST in-order traversal yields sorted array ([20, ..., 50, ..., 80])")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2.5: BST in-order traversal")
  @end

  println("-----------------------------------------------------------------")
  println("App 2 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Application 2 (Linked List & BST) PASSED")
    return 0
  @else
    println("✗ Application 2 (Linked List & BST) FAILED")
    return 1
  @end
@end
