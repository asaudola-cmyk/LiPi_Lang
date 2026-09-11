@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: ARRAYS OF STRUCTS
@! File: tests/e2e/tier3_combinations/test_arrays_of_structs.maya
@! ============================================================================

@struct Item
  id: 0
  price: 0
  quantity: 0
@end

@fn total_inventory_value(items, count)
  total = 0
  i = 0
  @while i < count
    it = items[i]
    total = total + it.price * it.quantity
    i = i + 1
  @end
  return total
@end

@fn find_highest_priced_id(items, count)
  max_price = items[0].price
  max_id = items[0].id
  i = 1
  @while i < count
    @if items[i].price > max_price
      max_price = items[i].price
      max_id = items[i].id
    @end
    i = i + 1
  @end
  return max_id
@end

@fn search_item_by_id(items, count, target_id)
  found_idx = -1
  i = 0
  @while i < count
    @if items[i].id == target_id
      found_idx = i
    @end
    i = i + 1
  @end
  return found_idx
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 2: Arrays of Structs")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.6: Array of Structs Initialization
  total = total + 1
  item1 = { id: 101, price: 50, quantity: 2 }
  item2 = { id: 102, price: 120, quantity: 1 }
  item3 = { id: 103, price: 30, quantity: 5 }
  inventory = [item1, item2, item3]
  @if inventory[0].id == 101 && inventory[1].price == 120 && inventory[2].quantity == 5
    passed = passed + 1
    println("  [PASS] T3.6: Array containing struct objects initialization")
  @else
    failed = failed + 1
    println("  [FAIL] T3.6: Array containing struct objects initialization")
  @end

  @! T3.7: Total Value Computation Across Struct Array
  total = total + 1
  @! (50 * 2) + (120 * 1) + (30 * 5) = 100 + 120 + 150 = 370
  inv_val = total_inventory_value(inventory, 3)
  @if inv_val == 370
    passed = passed + 1
    println("  [PASS] T3.7: Field summation across array of structs (total == 370)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.7: Field summation across array of structs")
  @end

  @! T3.8: Search for Highest Priced Struct in Array
  total = total + 1
  highest_id = find_highest_priced_id(inventory, 3)
  @if highest_id == 102
    passed = passed + 1
    println("  [PASS] T3.8: Finding struct with max field value in array (max id == 102)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.8: Finding struct with max field value in array")
  @end

  @! T3.9: In-place Field Mutation in Array of Structs
  total = total + 1
  inventory[0].quantity = 10  @! Now 50 * 10 = 500
  @! New total = 500 + 120 + 150 = 770
  new_inv_val = total_inventory_value(inventory, 3)
  @if inventory[0].quantity == 10 && new_inv_val == 770
    passed = passed + 1
    println("  [PASS] T3.9: In-place field mutation within array-indexed struct (new total == 770)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.9: In-place field mutation within array-indexed struct")
  @end

  @! T3.10: Linear Search in Array of Structs by Key
  total = total + 1
  search_idx = search_item_by_id(inventory, 3, 103)
  @if search_idx == 2 && inventory[search_idx].price == 30
    passed = passed + 1
    println("  [PASS] T3.10: Search by ID key in array of structs (index == 2, price == 30)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.10: Search by ID key in array of structs")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 2 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 2 (Arrays of Structs) PASSED")
    return 0
  @else
    println("✗ Combination 2 (Arrays of Structs) FAILED")
    return 1
  @end
@end
