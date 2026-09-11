@! ============================================================================
@! MAYA E2E TIER 3 — CROSS-FEATURE: GC ARENA + DEEP STRUCT NESTING & GRAPH POINTERS
@! File: tests/e2e/tier3_combinations/test_gc_arena_deep_struct_nesting.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 3
@! ============================================================================

@struct GraphNode
  id: 0
  weight: 0
  child1: 0
  child2: 0
  next: 0
@end

@fn build_deep_linked_list(count, base_weight)
  head = { id: 0, weight: base_weight, child1: 0, child2: 0, next: 0 }
  i = 1
  @while i < count
    new_node = {
      id: i,
      weight: base_weight,
      child1: 0,
      child2: 0,
      next: head
    }
    head = new_node
    i = i + 1
  @end
  return head
@end

@fn sum_linked_list(head)
  total_weight = 0
  curr = head
  count = 0
  @while curr != 0
    total_weight = total_weight + curr.weight
    count = count + 1
    curr = curr.next
  @end
  return { sum: total_weight, count: count }
@end

@fn make_leaf_node(current_id, weight)
  return { id: current_id, weight: weight, child1: 0, child2: 0, next: 0 }
@end

@fn build_binary_graph_tree(depth, current_id, weight)
  @if depth <= 1
    return make_leaf_node(current_id, weight)
  @end
  node = {
    id: current_id,
    weight: weight,
    child1: 0,
    child2: 0,
    next: 0
  }
  node.child1 = build_binary_graph_tree(depth - 1, current_id * 2 + 1, weight)
  node.child2 = build_binary_graph_tree(depth - 1, current_id * 2 + 2, weight)
  return node
@end

@fn sum_graph_tree(node)
  @if node == 0
    return 0
  @end
  return node.weight + sum_graph_tree(node.child1) + sum_graph_tree(node.child2)
@end

@fn count_graph_tree(node)
  @if node == 0
    return 0
  @end
  return 1 + count_graph_tree(node.child1) + count_graph_tree(node.child2)
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 3] Combination 5: GC Arena + Deep Struct Nesting & Graphs")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! T3.5.1: Allocate 5,000 deeply linked nodes in heap
  total = total + 1
  list_5k = build_deep_linked_list(5000, 100)
  list_stats = sum_linked_list(list_5k)
  @! 5000 * 100 = 500,000
  @if list_stats.count == 5000 && list_stats.sum == 500000
    passed = passed + 1
    println("  [PASS] T3.5.1: 5,000 heap-allocated linked struct nodes (sum == 500,000)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.5.1: Linked list failed: count=" + int_to_str(list_stats.count) + ", sum=" + int_to_str(list_stats.sum))
  @end

  @! T3.5.2: Binary Tree Graph with 10 Levels (1023 nodes)
  total = total + 1
  tree_root = build_binary_graph_tree(10, 0, 50)
  tree_nodes = count_graph_tree(tree_root)
  tree_weight_sum = sum_graph_tree(tree_root)
  @! 2^10 - 1 = 1023 nodes. 1023 * 50 = 51,150
  @if tree_nodes == 1023 && tree_weight_sum == 51150
    passed = passed + 1
    println("  [PASS] T3.5.2: 10-level recursive binary graph tree (1,023 nodes, sum == 51,150)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.5.2: Binary graph tree failed: nodes=" + int_to_str(tree_nodes) + ", sum=" + int_to_str(tree_weight_sum))
  @end

  @! T3.5.3: Graph Cross-Pointers & Cyclic Mutation
  total = total + 1
  node_a = { id: 1, weight: 200, child1: 0, child2: 0, next: 0 }
  node_b = { id: 2, weight: 300, child1: 0, child2: 0, next: 0 }
  node_c = { id: 3, weight: 500, child1: 0, child2: 0, next: 0 }
  node_a.child1 = node_b
  node_b.child1 = node_c
  node_c.child1 = node_a  @! cycle
  @! Traverse cycle safely 3 steps
  cyc_sum = node_a.weight + node_a.child1.weight + node_a.child1.child1.weight + node_a.child1.child1.child1.weight
  @! 200 + 300 + 500 + 200 = 1200
  @if cyc_sum == 1200
    passed = passed + 1
    println("  [PASS] T3.5.3: Cyclic graph struct pointer traversal (sum == 1,200)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.5.3: Cyclic graph traversal failed")
  @end

  @! T3.5.4: Multi-list Interleaving
  total = total + 1
  list_a = build_deep_linked_list(500, 10)
  list_b = build_deep_linked_list(500, 20)
  curr_a = list_a
  curr_b = list_b
  interleaved_sum = 0
  @while curr_a != 0 && curr_b != 0
    interleaved_sum = interleaved_sum + curr_a.weight + curr_b.weight
    curr_a = curr_a.next
    curr_b = curr_b.next
  @end
  @! 500 * (10 + 20) = 15,000
  @if interleaved_sum == 15000
    passed = passed + 1
    println("  [PASS] T3.5.4: Simultaneous traversal of multiple allocated struct lists (sum == 15,000)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.5.4: Multi-list traversal failed")
  @end

  @! T3.5.5: Deep Nesting Field Access
  total = total + 1
  nested = { id: 1, weight: 1, child1: 0, child2: 0, next: 0 }
  nested.child1 = { id: 2, weight: 2, child1: 0, child2: 0, next: 0 }
  nested.child1.child1 = { id: 3, weight: 3, child1: 0, child2: 0, next: 0 }
  nested.child1.child1.child1 = { id: 4, weight: 4, child1: 0, child2: 0, next: 0 }
  nested.child1.child1.child1.child1 = { id: 5, weight: 5, child1: 0, child2: 0, next: 0 }

  leaf_id = nested.child1.child1.child1.child1.id
  leaf_weight = nested.child1.child1.child1.child1.weight
  @if leaf_id == 5 && leaf_weight == 5
    passed = passed + 1
    println("  [PASS] T3.5.5: 5-level deep nested field pointer access (id == 5, weight == 5)")
  @else
    failed = failed + 1
    println("  [FAIL] T3.5.5: Deep nested field access failed")
  @end

  println("-----------------------------------------------------------------")
  println("Combination 5 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Combination 5 (GC Arena & Deep Structs) PASSED")
    return 0
  @else
    println("✗ Combination 5 (GC Arena & Deep Structs) FAILED")
    return 1
  @end
@end
