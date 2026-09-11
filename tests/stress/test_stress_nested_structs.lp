@! ============================================================================
@! MAYA ADVERSARIAL STRESS SUITE: COMPLEX NESTED STRUCTS & MUTATIONS
@! File: tests/stress/test_stress_nested_structs.maya
@! ============================================================================

@struct InnerL1
  v1: 0
@end

@struct InnerL2
  v2: 0
  l1: 0
@end

@struct InnerL3
  v3: 0
  l2: 0
@end

@struct InnerL4
  v4: 0
  l3: 0
@end

@struct OuterL5
  v5: 0
  l4: 0
@end

@struct Accumulator
  acc_count: 0
  acc_sum: 0
  acc_max: 0
@end

@struct GridRow
  row_id: 0
  cols: 0
@end

@struct Grid2D
  num_rows: 0
  rows: 0
@end

@struct BstNode
  b_key: 0
  b_val: 0
  b_left: 0
  b_right: 0
@end

@fn rec_accumulate(acc, step, limit)
  @if step > limit
    return acc
  @end
  acc.acc_count = acc.acc_count + 1
  acc.acc_sum = acc.acc_sum + step
  @if step > acc.acc_max
    acc.acc_max = step
  @end
  return rec_accumulate(acc, step + 1, limit)
@end

@fn bst_insert_node(root, key, val)
  @if root == 0
    return { b_key: key, b_val: val, b_left: 0, b_right: 0 }
  @end
  @if key < root.b_key
    root.b_left = bst_insert_node(root.b_left, key, val)
  @elif key > root.b_key
    root.b_right = bst_insert_node(root.b_right, key, val)
  @else
    root.b_val = val
  @end
  return root
@end

@fn bst_search_node(root, key)
  @if root == 0
    return -1
  @end
  @if root.b_key == key
    return root.b_val
  @elif key < root.b_key
    return bst_search_node(root.b_left, key)
  @else
    return bst_search_node(root.b_right, key)
  @end
@end

@fn bst_sum_values(root)
  @if root == 0
    return 0
  @end
  return root.b_val + bst_sum_values(root.b_left) + bst_sum_values(root.b_right)
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS TEST 3: NESTED STRUCTS & MUTATIONS 🔥")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! Stress 3.1: 5-Level Deep Nested Struct Instantiation & Field Reads
  total = total + 1
  l1 = { v1: 101 }
  l2 = { v2: 202, l1: l1 }
  l3 = { v3: 303, l2: l2 }
  l4 = { v4: 404, l3: l3 }
  l5 = { v5: 505, l4: l4 }

  r_v5 = l5.v5
  r_v4 = l5.l4.v4
  r_v3 = l5.l4.l3.v3
  r_v2 = l5.l4.l3.l2.v2
  r_v1 = l5.l4.l3.l2.l1.v1

  @if r_v5 == 505 && r_v4 == 404 && r_v3 == 303 && r_v2 == 202 && r_v1 == 101
    passed = passed + 1
    println("  [PASS] S3.1: 5-level deep nested struct instantiation and reads (101..505)")
  @else
    failed = failed + 1
    println("  [FAIL] S3.1: 5-level deep nested struct instantiation and reads")
  @end

  @! Stress 3.2: Multi-Level Deep Struct Field Mutations
  total = total + 1
  l5.l4.l3.l2.l1.v1 = 99999
  l5.l4.l3.v3 = 77777

  @if l5.l4.l3.l2.l1.v1 == 99999 && l5.l4.l3.v3 == 77777 && l1.v1 == 99999
    passed = passed + 1
    println("  [PASS] S3.2: Deep nested struct mutation (l5.l4.l3.l2.l1.v1 == 99999, reflected in ref)")
  @else
    failed = failed + 1
    println("  [FAIL] S3.2: Deep nested struct mutation")
  @end

  @! Stress 3.3: Passing Struct to Recursive Function (Depth = 250)
  total = total + 1
  acc = { acc_count: 0, acc_sum: 0, acc_max: 0 }
  acc = rec_accumulate(acc, 1, 250)

  @! sum 1..250 = 250 * 251 / 2 = 31375
  @if acc.acc_count == 250 && acc.acc_sum == 31375 && acc.acc_max == 250
    passed = passed + 1
    println("  [PASS] S3.3: Struct mutated across 250 recursive calls (sum == 31375, max == 250)")
  @else
    failed = failed + 1
    println("  [FAIL] S3.3: Struct mutated across 250 recursive calls")
  @end

  @! Stress 3.4: Nested Structs Containing Dynamic Arrays of Structs (2D Grid Simulation)
  total = total + 1
  grid_rows = []
  r = 0
  @while r < 10
    row_cols = []
    c = 0
    @while c < 10
      row_cols.push(r * 100 + c)
      c = c + 1
    @end
    grow = { row_id: r, cols: row_cols }
    grid_rows.push(grow)
    r = r + 1
  @end

  grid = { num_rows: 10, rows: grid_rows }

  @! Mutate cell (4, 7) and (8, 9)
  grid.rows[4].cols[7] = 8888
  grid.rows[8].cols[9] = 9999

  val_4_7 = grid.rows[4].cols[7]
  val_8_9 = grid.rows[8].cols[9]
  val_0_0 = grid.rows[0].cols[0]
  val_9_9 = grid.rows[9].cols[9]

  @if val_4_7 == 8888 && val_8_9 == 9999 && val_0_0 == 0 && val_9_9 == 909
    passed = passed + 1
    println("  [PASS] S3.4: Struct with dynamic arrays of row structs (mutations verified)")
  @else
    failed = failed + 1
    println("  [FAIL] S3.4: Struct with dynamic arrays of row structs")
  @end

  @! Stress 3.5: Binary Search Tree (BST) Node Hierarchy with 60 Insertions
  total = total + 1
  bst = 0
  k = 1
  @while k <= 60
    @! Insert pseudorandom keys
    pseudo_key = (k * 37) % 61
    pseudo_val = pseudo_key * 10
    bst = bst_insert_node(bst, pseudo_key, pseudo_val)
    k = k + 1
  @end

  search_1 = bst_search_node(bst, 37)
  search_2 = bst_search_node(bst, 13)
  search_miss = bst_search_node(bst, 999)
  total_bst_sum = bst_sum_values(bst)

  @! Keys 1..60 each mapped to key * 10 -> Sum = 10 * (60 * 61 / 2) = 18300
  @if search_1 == 370 && search_2 == 130 && search_miss == -1 && total_bst_sum == 18300
    passed = passed + 1
    println("  [PASS] S3.5: BST struct tree 60 nodes inserted & searched (sum == 18300)")
  @else
    failed = failed + 1
    println("  [FAIL] S3.5: BST struct tree 60 nodes inserted & searched")
  @end

  println("-----------------------------------------------------------------")
  println("Stress Suite 3 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ ALL NESTED STRUCT STRESS TESTS PASSED")
    return 0
  @else
    println("✗ NESTED STRUCT STRESS TESTS FAILED")
    return 1
  @end
@end
