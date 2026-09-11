@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: STRUCT + RECURSION + RESULT/ERROR
@! File: tests/e2e/tier3_combinations/test_struct_recursion_result.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

@struct Result
  is_ok: 0
  val: 0
  path: ""
  err_msg: ""
@end

@fn ok_res(val, path)
  return { is_ok: 1, val: val, path: path, err_msg: "" }
@end

@fn err_res(msg)
  return { is_ok: 0, val: 0, path: "", err_msg: msg }
@end

@struct TreeNode
  val: 0
  left: 0
  right: 0
@end

@impl TreeNode
  @fn new_node(self, v)
    return { val: v, left: 0, right: 0 }
  @end

  @fn insert(self, v)
    @if v < self.val
      @if self.left == 0
        self.left = { val: v, left: 0, right: 0 }
      @else
        self.left = self.left.insert(v)
      @end
    @elif v > self.val
      @if self.right == 0
        self.right = { val: v, left: 0, right: 0 }
      @else
        self.right = self.right.insert(v)
      @end
    @end
    return self
  @end

  @fn tree_depth(self)
    left_d = 0
    right_d = 0
    @if self.left != 0
      left_d = self.left.tree_depth()
    @end
    @if self.right != 0
      right_d = self.right.tree_depth()
    @end
    @if left_d > right_d
      return 1 + left_d
    @else
      return 1 + right_d
    @end
  @end

  @fn count_nodes(self)
    cnt = 1
    @if self.left != 0
      cnt = cnt + self.left.count_nodes()
    @end
    @if self.right != 0
      cnt = cnt + self.right.count_nodes()
    @end
    return cnt
  @end

  @fn find_path_helper(self, target, current_path)
    step = int_to_str(self.val)
    new_path = ""
    @if str_len(current_path) == 0
      new_path = step
    @else
      new_path = current_path + "->" + step
    @end

    @if self.val == target
      return ok_res(self.val, new_path)
    @elif target < self.val
      @if self.left == 0
        return err_res("Key " + int_to_str(target) + " not found in tree")
      @end
      return self.left.find_path_helper(target, new_path)
    @else
      @if self.right == 0
        return err_res("Key " + int_to_str(target) + " not found in tree")
      @end
      return self.right.find_path_helper(target, new_path)
    @end
  @end

  @fn find_path(self, target)
    return self.find_path_helper(target, "")
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 1: Struct + Recursive Method + Result/Error")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! Construct binary search tree of depth 4 with 15 nodes:
  @! [50, 30, 70, 20, 40, 60, 80, 10, 25, 35, 45, 55, 65, 75, 85]
  tree = { val: 50, left: 0, right: 0 }
  tree = tree.insert(30)
  tree = tree.insert(70)
  tree = tree.insert(20)
  tree = tree.insert(40)
  tree = tree.insert(60)
  tree = tree.insert(80)
  tree = tree.insert(10)
  tree = tree.insert(25)
  tree = tree.insert(35)
  tree = tree.insert(45)
  tree = tree.insert(55)
  tree = tree.insert(65)
  tree = tree.insert(75)
  tree = tree.insert(85)

  @! T3.1.1: Node Count Verification
  total = total + 1
  node_count = tree.count_nodes()
  @if node_count == 15
    passed = passed + 1
    println("  [PASS] T3.1.1: Node count in recursive BST matches expected (15)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.1.1: Node count expected 15, got " + int_to_str(node_count))
  @end

  @! T3.1.2: Tree Depth Invariant
  total = total + 1
  depth = tree.tree_depth()
  @if depth == 4
    passed = passed + 1
    println("  [PASS] T3.1.2: Maximum tree depth matches expected (4)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.1.2: Tree depth expected 4, got " + int_to_str(depth))
  @end

  @! T3.1.3: Successful Path Search Returning Result.Ok
  total = total + 1
  res_45 = tree.find_path(45)
  @if res_45.is_ok == 1 && res_45.path == "50->30->40->45" && res_45.val == 45
    passed = passed + 1
    println("  [PASS] T3.1.3: find_path(45) returns Ok with path: " + res_45.path)
  @else
    failed = failed + 1
    println("  [FAIL] T3.1.3: find_path(45) failed: is_ok=" + int_to_str(res_45.is_ok) + ", path=" + res_45.path)
  @end

  @! T3.1.4: Successful Path Search on Right Subtree
  total = total + 1
  res_65 = tree.find_path(65)
  @if res_65.is_ok == 1 && res_65.path == "50->70->60->65"
    passed = passed + 1
    println("  [PASS] T3.1.4: find_path(65) returns Ok with path: " + res_65.path)
  @else
    failed = failed + 1
    println("  [FAIL] T3.1.4: find_path(65) failed: path=" + res_65.path)
  @end

  @! T3.1.5: Missing Key Returning Result.Err with Diagnostic Message
  total = total + 1
  res_999 = tree.find_path(999)
  @if res_999.is_ok == 0 && res_999.err_msg == "Key 999 not found in tree"
    passed = passed + 1
    println("  [PASS] T3.1.5: find_path(999) returns Err: \"" + res_999.err_msg + "\"")
  @else
    failed = failed + 1
    println("  [FAIL] T3.1.5: find_path(999) did not return expected error message")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 1 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 1 (Struct + Recursion + Result) PASSED")
    return 0
  @else
    println("✗ Combination 1 (Struct + Recursion + Result) FAILED")
    return 1
  @end
@end
