@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE FOR MAYA UNIVERSE DB ENGINE (M1)
@! Tests: Edge Cases, Buffer Pool Thrashing, Multi-Level Splits, Pin Leak Audits
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/string"
import "universe/db/page"
import "universe/db/buffer"
import "universe/db/btree"

@fn assert(cond, msg)
  @if cond == 0
    println("  ❌ [ASSERT FAIL] " + msg)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🔥 RUNNING ADVERSARIAL STRESS TESTS (M1 REVIEW)")
  println("=================================================================")

  total = 0
  passed = 0

  @! --------------------------------------------------------------------------
  @! Stress Test 1: Pin Count Leak Audit (Verify no pinned frames remain leaked)
  @! --------------------------------------------------------------------------
  total = total + 1
  db_path = "/tmp/test_maya_pin_leak.db"
  sys_unlink(db_path)

  pool = buffer_pool_open(db_path, 8)
  tree = btree_open(pool, 1)

  i = 0
  @while i < 150
    k = "key_" + (1000 + i).to_str()
    v = "val_" + i.to_str()
    tree = btree_insert(tree, k, v)
    i = i + 1
  @end

  @! Check range scan
  sc = btree_scan(tree, "key_1010", "key_1050", 100)
  @! Check point search
  get_res = btree_get(tree, "key_1020", "")
  @! Check deletion
  tree = btree_delete(tree, "key_1020")

  @! Check every frame's pin_count in pool
  leak_detected = 0
  fi = 0
  @while fi < pool.capacity
    frame = pool.frames[fi]
    @if frame.pin_count != 0
      println("  Frame " + fi.to_str() + " has leaked pin_count: " + frame.pin_count.to_str())
      leak_detected = 1
    @end
    fi = fi + 1
  @end

  buffer_pool_close(pool)

  @if assert(leak_detected == 0, "No frame pin leaks after inserts, scans, gets, deletes") == 1
    passed = passed + 1
    println("  [PASS] Stress Test 1: Zero Pin Count Leaks verified across all frames")
  @end

  @! --------------------------------------------------------------------------
  @! Stress Test 2: Severe Memory Pressure (3-Frame Pool with High Eviction Load)
  @! --------------------------------------------------------------------------
  total = total + 1
  db_path2 = "/tmp/test_maya_tiny_pool.db"
  sys_unlink(db_path2)

  pool2 = buffer_pool_open(db_path2, 3)
  tree2 = btree_open(pool2, 1)

  @! Insert 500 keys with 40-byte payloads to force 8+ pages on a 3-frame pool
  i = 0
  @while i < 500
    k = "tiny_k_" + (10000 + (i * 37 % 500)).to_str()
    v = "tiny_payload_data_padding_for_evictions_" + i.to_str()
    tree2 = btree_insert(tree2, k, v)
    i = i + 1
  @end

  st2 = buffer_pool_get_stats(pool2)
  v2_ok = btree_verify(tree2)
  cnt2 = btree_count(tree2)

  @if assert(st2.evictions > 5, "Pool successfully performed LRU evictions (" + st2.evictions.to_str() + " evictions)") == 1
    @if assert(v2_ok == 1, "B+Tree integrity under severe memory pressure") == 1
      @if assert(cnt2 == 500, "B+Tree count is 500") == 1
        passed = passed + 1
        println("  [PASS] Stress Test 2: 3-Frame Tiny Buffer Pool with page thrashing & evictions (evictions: " + st2.evictions.to_str() + ")")
      @end
    @end
  @end
  buffer_pool_close(pool2)

  @! --------------------------------------------------------------------------
  @! Stress Test 3: Multi-Level Tree Splitting (Tree Height >= 3)
  @! --------------------------------------------------------------------------
  total = total + 1
  db_path3 = "/tmp/test_maya_deep_tree.db"
  sys_unlink(db_path3)

  pool3 = buffer_pool_open(db_path3, 32)
  tree3 = btree_open(pool3, 1)

  i = 0
  @while i < 1000
    k = "key_with_a_very_long_prefix_to_fill_internal_nodes_quickly_" + (100000 + i).to_str()
    v = "value_payload_padding_data_record_for_splits_long_long_long_long_long_value_" + i.to_str()
    tree3 = btree_insert(tree3, k, v)
    i = i + 1
  @end

  h = btree_get_height(tree3)
  cnt3 = btree_count(tree3)
  v_ok = btree_verify(tree3)

  @if assert(h >= 3, "Tree height increased to >= 3 (recursive internal splits)") == 1
    @if assert(cnt3 == 1000, "Count across multi-level tree is 1000") == 1
      @if assert(v_ok == 1, "Multi-level tree verification passes") == 1
        passed = passed + 1
        println("  [PASS] Stress Test 3: Multi-level tree (height " + h.to_str() + ", 1000 keys) recursive splits")
      @end
    @end
  @end
  buffer_pool_close(pool3)

  @! --------------------------------------------------------------------------
  @! Stress Test 4: Variable Payload In-Place Updates & Defrag Stress
  @! --------------------------------------------------------------------------
  total = total + 1
  db_path4 = "/tmp/test_maya_payload_resize.db"
  sys_unlink(db_path4)

  pool4 = buffer_pool_open(db_path4, 16)
  tree4 = btree_open(pool4, 1)

  @! Insert initial key
  tree4 = btree_insert(tree4, "resize_key", "short")
  @! Update with larger payload
  tree4 = btree_insert(tree4, "resize_key", "longer_payload_string_1234567890")
  @! Update with very large payload (200 bytes)
  large_payload = "A"
  li = 0
  @while li < 200
    large_payload = large_payload + "X"
    li = li + 1
  @end
  tree4 = btree_insert(tree4, "resize_key", large_payload)

  fetched_large = btree_get(tree4, "resize_key", "")

  @if assert(str_len(fetched_large) == 201, "Large payload retrieved correctly after progressive enlargements") == 1
    passed = passed + 1
    println("  [PASS] Stress Test 4: Variable payload resize & in-place update defragmentation")
  @end
  buffer_pool_close(pool4)

  @! --------------------------------------------------------------------------
  @! Stress Test 5: Scan Edge Cases (Empty Tree, Single Key, Beyond Bound)
  @! --------------------------------------------------------------------------
  total = total + 1
  db_path5 = "/tmp/test_maya_scan_edges.db"
  sys_unlink(db_path5)

  pool5 = buffer_pool_open(db_path5, 16)
  tree5 = btree_open(pool5, 1)

  @! Empty tree scan
  s_empty = btree_scan(tree5, "", "", 10)
  @! Insert single key
  tree5 = btree_insert(tree5, "only_one", "val_one")
  s_one = btree_scan(tree5, "", "", 10)
  s_one_exact = btree_scan(tree5, "only_one", "only_one", 10)
  s_one_before = btree_scan(tree5, "aaa", "aaz", 10)
  s_one_after = btree_scan(tree5, "zzz", "zzzz", 10)

  edge_ok = 1
  @if s_empty.len() != 0 || s_one.len() != 1 || s_one_exact.len() != 1 || s_one_before.len() != 0 || s_one_after.len() != 0
    edge_ok = 0
  @end

  @if assert(edge_ok == 1, "Scan edge cases (empty tree, single key, out of bounds)") == 1
    passed = passed + 1
    println("  [PASS] Stress Test 5: Range scan boundary edge cases")
  @end
  buffer_pool_close(pool5)

  println("=================================================================")
  println("Stress Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  println("=================================================================")
  return 0
@end
