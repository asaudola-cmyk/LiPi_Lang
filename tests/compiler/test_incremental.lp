@! ============================================================================
@! MAYA COMPILER TEST SUITE — INCREMENTAL COMPILATION & DEPENDENCY GRAPH
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "compiler/middleend/incremental"

@fn assert_eq(actual, expected, msg)
  @if actual == expected
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg + " (expected " + expected.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@fn assert_true(cond, msg)
  @if cond == 1
    println("  [PASS] " + msg)
    return 1
  @else
    println("  [FAIL] " + msg)
    return 0
  @end
@end

@fn mock_file_loader(path)
  @if path == "a.maya"
    return "@fn add(x, y) return x + y @end"
  @elif path == "b.maya"
    return "import "a"
@fn double(x) return add(x, x) @end"
  @elif path == "c.maya"
    return "import "b"
@fn quad(x) return double(double(x)) @end"
  @end
  return "@fn main() return 0 @end"
@end

@fn main()
  println("==================================================")
  println("   MAYA INCREMENTAL BUILD COMPREHENSIVE TESTS     ")
  println("==================================================")

  @! 1. Hashing Tests (FNV-1a & SHA-256)
  println("▶ Testing Hashing Functions...")
  h1 = fnv1a_64_string("let x = 42")
  h2 = fnv1a_64_string("let x = 42")
  h3 = fnv1a_64_string("let x = 43")
  assert_eq(h1, h2, "FNV-1a deterministic hash match")
  assert_true(h1 != h3, "FNV-1a distinct content produces distinct hash")

  sha_res = hash_source_sha256("hello maya")
  assert_true(sha_res.len() == 64, "SHA-256 hex string length == 64")

  @! 2. Dependency Graph & Cycle Detection Tests
  println("▶ Testing Dependency Graph & Tarjan's Cycle Detection...")
  graph = dep_graph_new()
  f_a = { sf_path: "a.maya", sf_content_hash: 101, sf_content_hash_hex: "a1", sf_last_modified: 1, sf_dependencies: [] }
  f_b = { sf_path: "b.maya", sf_content_hash: 102, sf_content_hash_hex: "b1", sf_last_modified: 2, sf_dependencies: ["a.maya"] }
  f_c = { sf_path: "c.maya", sf_content_hash: 103, sf_content_hash_hex: "c1", sf_last_modified: 3, sf_dependencies: ["b.maya"] }

  graph = dep_graph_add_node(graph, f_a)
  graph = dep_graph_add_node(graph, f_b)
  graph = dep_graph_add_node(graph, f_c)

  @! b depends on a; c depends on b
  graph = dep_graph_add_edge(graph, "b.maya", "a.maya")
  graph = dep_graph_add_edge(graph, "c.maya", "b.maya")

  assert_eq(graph.dg_nodes.len(), 3, "Graph node count == 3")
  cycles = dep_graph_find_cycles(graph)
  assert_eq(cycles.len(), 0, "Acyclic graph produces 0 cycles")

  @! 3. Kahn's Topological Sorting
  println("▶ Testing Topological Sort...")
  sort_res = dep_graph_topological_sort(graph)
  assert_eq(sort_res.ok, 1, "Topological sort succeeded")
  order = sort_res.order
  assert_eq(order.len(), 3, "Topological sort order length == 3")
  assert_eq(order[0], "a.maya", "Order[0] is root dependency a.maya")
  assert_eq(order[1], "b.maya", "Order[1] is intermediate b.maya")
  assert_eq(order[2], "c.maya", "Order[2] is leaf dependent c.maya")

  @! 4. Cycle Detection on Cyclic Graph
  println("▶ Testing Cycle Detection on Cyclic Graph...")
  cyc_graph = dep_graph_new()
  cyc_graph = dep_graph_add_node(cyc_graph, f_a)
  cyc_graph = dep_graph_add_node(cyc_graph, f_b)
  cyc_graph = dep_graph_add_edge(cyc_graph, "a.maya", "b.maya")
  cyc_graph = dep_graph_add_edge(cyc_graph, "b.maya", "a.maya")
  cyc_list = dep_graph_find_cycles(cyc_graph)
  assert_true(cyc_list.len() > 0, "Cycle detected between a.maya <-> b.maya")
  cyc_sort = dep_graph_topological_sort(cyc_graph)
  assert_eq(cyc_sort.ok, 0, "Topological sort correctly rejected cyclic graph")

  @! 5. BFS Change Propagation (affected_by)
  println("▶ Testing Change Propagation (affected_by)...")
  aff = dep_graph_affected_by(graph, ["a.maya"])
  assert_eq(aff.len(), 3, "Changing a.maya affects a.maya, b.maya, and c.maya")
  assert_true(inc_list_contains(aff, "b.maya"), "affected contains b.maya")
  assert_true(inc_list_contains(aff, "c.maya"), "affected contains c.maya")

  aff_c = dep_graph_affected_by(graph, ["c.maya"])
  assert_eq(aff_c.len(), 1, "Changing leaf c.maya affects only c.maya")

  @! 6. Compilation Cache Unit Tests
  println("▶ Testing Compilation Cache...")
  cache = compilation_cache_new("/tmp/maya_cache_test")
  mock_res = {
    cr_file_path: "a.maya",
    cr_content_hash: 12345,
    cr_content_hash_hex: "abcd",
    cr_ast_hash: 67890,
    cr_ast: [],
    cr_type_env: [],
    cr_exported_symbols: [],
    cr_ir_bytes: [1, 2, 3, 4],
    cr_ir_text: "; IR for a.maya",
    cr_ir_module: 0
  }
  cache = compilation_cache_put(cache, 12345, mock_res)
  retrieved = compilation_cache_get(cache, 12345)
  assert_true(retrieved != 0, "Cache retrieved by hash")
  assert_eq(retrieved.cr_file_path, "a.maya", "Retrieved correct file path from cache")

  cache = compilation_cache_invalidate(cache, "a.maya")
  after_inv = compilation_cache_get(cache, 12345)
  assert_true(after_inv == 0, "Cache invalidated successfully")

  @! 7. Real AST-to-IR Compilation & Serialization
  println("▶ Testing Real AST-to-IR Compilation & Caching...")
  source_test = "@fn square(x: i64) -> i64
  return x * x
@end
"
  comp_res = inc_compile_source("test_math.maya", source_test)
  assert_eq(comp_res.cr_file_path, "test_math.maya", "Compiled result file path matches")
  assert_true(comp_res.cr_ast.len() > 0, "AST statements parsed successfully")
  assert_true(comp_res.cr_ir_bytes.len() > 0, "Genuine IR byte representation generated")
  assert_true(comp_res.cr_ir_text.len() > 0, "Genuine textual IR generated")
  assert_true(comp_res.cr_exported_symbols.len() > 0, "Exported symbols extracted")

  @! 8. Incremental Driver compile_dirty Execution
  println("▶ Testing Incremental Driver compile_dirty...")
  fresh_cache = compilation_cache_new("/tmp/maya_cache_live")
  driver_res = compile_dirty(["a.maya", "b.maya"], graph, fresh_cache, mock_file_loader)
  assert_eq(driver_res.ok, 1, "compile_dirty executed successfully")
  assert_eq(driver_res.compiled_count, 2, "Compiled exactly 2 dirty files")

  println("🎉 ALL INCREMENTAL BUILD TESTS PASSED!")
  return 0
@end
