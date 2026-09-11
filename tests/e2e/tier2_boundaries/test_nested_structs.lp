// @! RUN: %maya %file
// @! EXPECT: ✓ Boundary: Nested Structs PASSED
// @! EXPECT_EXIT: 0
// @! TIER: 2
// @! TAGS: boundary, nested_structs, deep_traversal, wide_struct, struct_arrays, cross_hierarchy

@! ============================================================================
@! MAYA E2E TIER 2 — BOUNDARY & CORNER CASES: NESTED STRUCTS (5 LEVELS & WIDE)
@! File: tests/e2e/tier2_boundaries/test_nested_structs.maya
@! ============================================================================

@struct Level5
  val: i64
@end

@struct Level4
  l5: Level5
@end

@struct Level3
  l4: Level4
@end

@struct Level2
  l3: Level3
@end

@struct Level1
  l2: Level2
  id: i64
@end

@struct Wide20
  f1: i64, f2: i64, f3: i64, f4: i64, f5: i64
  f6: i64, f7: i64, f8: i64, f9: i64, f10: i64
  f11: i64, f12: i64, f13: i64, f14: i64, f15: i64
  f16: i64, f17: i64, f18: i64, f19: i64, f20: i64
@end

@struct Item
  id: i64
  weight: i64
@end

@struct Inventory
  items: array
  owner: string
@end

@fn make_level5_hierarchy(val)
  l5 = { val: val }
  l4 = { l5: l5 }
  l3 = { l4: l4 }
  l2 = { l3: l3 }
  return { l2: l2, id: 1001 }
@end

@fn read_deep_val(root: Level1)
  return root.l2.l3.l4.l5.val
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 2] Boundary: Deep Nested Structs (5 Levels & 20 Fields)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! BC-NST-01: 5-Level Nested Struct Traversal
  total = total + 1
  root = make_level5_hierarchy(999)
  @if root.id == 1001 && root.l2.l3.l4.l5.val == 999
    passed = passed + 1
    println("  [PASS] BC-NST-01: 5-level nested struct traversal (root.l2.l3.l4.l5.val == 999)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NST-01: 5-level nested struct traversal")
  @end

  @! BC-NST-02: Deep Struct Field Mutation
  total = total + 1
  root.l2.l3.l4.l5.val = 8888
  @if root.l2.l3.l4.l5.val == 8888
    passed = passed + 1
    println("  [PASS] BC-NST-02: In-place mutation of 5th level struct field (val = 8888)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NST-02: Deep field mutation")
  @end

  @! BC-NST-03: Wide Struct with 20 Fields
  total = total + 1
  w = {
    f1: 1, f2: 2, f3: 3, f4: 4, f5: 5,
    f6: 6, f7: 7, f8: 8, f9: 9, f10: 10,
    f11: 11, f12: 12, f13: 13, f14: 14, f15: 15,
    f16: 16, f17: 17, f18: 18, f19: 19, f20: 20
  }
  sum20 = w.f1 + w.f5 + w.f10 + w.f15 + w.f20
  @! 1 + 5 + 10 + 15 + 20 = 51
  @if w.f1 == 1 && w.f20 == 20 && sum20 == 51
    passed = passed + 1
    println("  [PASS] BC-NST-03: 20-field wide struct offset indexing (sum20 == 51)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NST-03: 20-field struct offset indexing")
  @end

  @! BC-NST-04: Struct Containing Array of Structs
  total = total + 1
  i1 = { id: 1, weight: 10 }
  i2 = { id: 2, weight: 25 }
  inv = { items: [i1, i2], owner: "MayaBuilder" }
  first_item = inv.items[0]
  second_item = inv.items[1]
  total_wt = first_item.weight + second_item.weight
  @if inv.owner == "MayaBuilder" && total_wt == 35
    passed = passed + 1
    println("  [PASS] BC-NST-04: Struct containing array of struct instances (total_weight == 35)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NST-04: Struct containing array of structs")
  @end

  @! BC-NST-05: Struct Hierarchy Passing & Modifying
  total = total + 1
  sub_tree = make_level5_hierarchy(42)
  sub_tree.l2.l3.l4.l5.val = sub_tree.l2.l3.l4.l5.val + 100
  @if sub_tree.l2.l3.l4.l5.val == 142
    passed = passed + 1
    println("  [PASS] BC-NST-05: Hierarchy instantiation via factory function and update (val == 142)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NST-05: Struct hierarchy factory")
  @end

  @! BC-NST-06: Cross-Hierarchy Field Assignment
  total = total + 1
  tree_a = make_level5_hierarchy(100)
  tree_b = make_level5_hierarchy(200)
  tree_a.l2.l3.l4.l5.val = tree_b.l2.l3.l4.l5.val
  @if tree_a.l2.l3.l4.l5.val == 200 && tree_b.l2.l3.l4.l5.val == 200
    passed = passed + 1
    println("  [PASS] BC-NST-06: Cross-hierarchy deep field value copying")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NST-06: Cross-hierarchy assignment")
  @end

  @! BC-NST-07: Deep Struct Passing into Specialized Function
  total = total + 1
  passed_val = read_deep_val(tree_a)
  @if passed_val == 200
    passed = passed + 1
    println("  [PASS] BC-NST-07: Passing deep struct to function as typed parameter (val == 200)")
  @else
    failed = failed + 1
    println("  [FAIL] BC-NST-07: Deep struct parameter passing")
  @end

  println("-----------------------------------------------------------------")
  println("Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Boundary: Nested Structs PASSED")
    return 0
  @else
    println("✗ Boundary: Nested Structs FAILED")
    return 1
  @end
@end
