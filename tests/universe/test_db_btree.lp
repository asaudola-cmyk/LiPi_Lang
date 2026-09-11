@! ============================================================================
@! MAYA UNIVERSE DB — B+TREE & BUFFER POOL E2E INTEGRATION TEST SUITE
@! tests/universe/test_db_btree.maya
@! 100% Pure Maya Native Implementation Verification
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/string"
import "universe/db/page"
import "universe/db/buffer"
import "universe/db/btree"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(to_str(expected), str_concat(", got ", to_str(actual)))))))
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if str_eq(actual, expected) == 0
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected '", str_concat(expected, str_concat("', got '", str_concat(actual, "'")))))))
    return 0
  @end
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 1: Buffer Pool Allocation, LRU Eviction & Disk Persistence
@! ----------------------------------------------------------------------------
@fn test_buffer_pool_eviction_and_persistence()
  db_path = "/tmp/test_maya_bp_persistence.db"
  sys_unlink(db_path)

  @! Capacity of 3 frames to trigger eviction quickly
  pool = buffer_pool_open(db_path, 3)
  @if assert_true(pool.fd >= 0, "Buffer pool should open valid file descriptor") == 0 return 0 @end
  @if assert_eq_int(pool.total_pages, 2, "Fresh DB has 2 initial pages (0 and 1)") == 0 return 0 @end

  @! Allocate pages 2, 3, 4, 5 (4 allocations on 3-frame pool -> forces eviction)
  p2_info = buffer_pool_allocate_page(pool)
  page_format_leaf(p2_info.buffer, 2, 0, 0)
  page_insert_leaf_cell(p2_info.buffer, "item_2", "payload_2")
  buffer_pool_unpin_page(pool, 2, 1)

  p3_info = buffer_pool_allocate_page(pool)
  page_format_leaf(p3_info.buffer, 3, 0, 0)
  page_insert_leaf_cell(p3_info.buffer, "item_3", "payload_3")
  buffer_pool_unpin_page(pool, 3, 1)

  p4_info = buffer_pool_allocate_page(pool)
  page_format_leaf(p4_info.buffer, 4, 0, 0)
  page_insert_leaf_cell(p4_info.buffer, "item_4", "payload_4")
  buffer_pool_unpin_page(pool, 4, 1)

  p5_info = buffer_pool_allocate_page(pool)
  page_format_leaf(p5_info.buffer, 5, 0, 0)
  page_insert_leaf_cell(p5_info.buffer, "item_5", "payload_5")
  buffer_pool_unpin_page(pool, 5, 1)

  @if assert_true(pool.stats_evictions > 0, "Pool must have evicted frames under memory pressure") == 0 return 0 @end

  buffer_pool_close(pool)

  @! Reopen pool and verify all pages retrieved correctly from disk
  pool2 = buffer_pool_open(db_path, 3)
  @if assert_eq_int(pool2.total_pages, 6, "Total pages persisted on disk should be 6") == 0 return 0 @end

  b2 = buffer_pool_fetch_page(pool2, 2)
  c2 = page_find_leaf_cell(b2, "item_2")
  @if assert_eq_int(c2.found, 1, "Page 2 item_2 should be found") == 0 return 0 @end
  @if assert_eq_str(c2.value, "payload_2", "Page 2 item_2 payload") == 0 return 0 @end
  buffer_pool_unpin_page(pool2, 2, 0)

  b5 = buffer_pool_fetch_page(pool2, 5)
  c5 = page_find_leaf_cell(b5, "item_5")
  @if assert_eq_int(c5.found, 1, "Page 5 item_5 should be found") == 0 return 0 @end
  @if assert_eq_str(c5.value, "payload_5", "Page 5 item_5 payload") == 0 return 0 @end
  buffer_pool_unpin_page(pool2, 5, 0)

  buffer_pool_close(pool2)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 2: B+Tree Point Queries and Key Updates
@! ----------------------------------------------------------------------------
@fn test_btree_point_queries_and_updates()
  db_path = "/tmp/test_maya_btree_point.db"
  sys_unlink(db_path)

  pool = buffer_pool_open(db_path, 16)
  tree = btree_open(pool, 1)

  tree = btree_insert(tree, "alpha", "val_alpha")
  tree = btree_insert(tree, "beta", "val_beta")
  tree = btree_insert(tree, "gamma", "val_gamma")
  tree = btree_insert(tree, "delta", "val_delta")

  @if assert_eq_str(btree_get(tree, "alpha", "NONE"), "val_alpha", "Get alpha") == 0 return 0 @end
  @if assert_eq_str(btree_get(tree, "beta", "NONE"), "val_beta", "Get beta") == 0 return 0 @end
  @if assert_eq_str(btree_get(tree, "gamma", "NONE"), "val_gamma", "Get gamma") == 0 return 0 @end
  @if assert_eq_str(btree_get(tree, "delta", "NONE"), "val_delta", "Get delta") == 0 return 0 @end
  @if assert_eq_str(btree_get(tree, "zeta", "NONE"), "NONE", "Get missing zeta") == 0 return 0 @end

  @! Update existing key with new value
  tree = btree_insert(tree, "gamma", "val_gamma_updated")
  @if assert_eq_str(btree_get(tree, "gamma", "NONE"), "val_gamma_updated", "Updated gamma") == 0 return 0 @end

  @if assert_eq_int(btree_verify(tree), 1, "B+Tree invariants verify") == 0 return 0 @end

  buffer_pool_close(pool)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 3: B+Tree Leaf Splits, Promotion & Horizontal Sibling Navigation
@! ----------------------------------------------------------------------------
@fn test_btree_splits_and_horizontal_scan()
  db_path = "/tmp/test_maya_btree_splits.db"
  sys_unlink(db_path)

  pool = buffer_pool_open(db_path, 16)
  tree = btree_open(pool, 1)

  @! Insert 200 sequential items to force multiple leaf splits
  i = 0
  @while i < 200
    k = "order_" + (1000 + i).to_str()
    v = "status_active_" + i.to_str()
    tree = btree_insert(tree, k, v)
    i = i + 1
  @end

  @if assert_true(tree.root_page_id > 1, "Root page ID should have changed due to root split") == 0 return 0 @end
  @if assert_eq_int(tree.height, 2, "Tree height should be 2 after leaf splits") == 0 return 0 @end
  @if assert_eq_int(btree_verify(tree), 1, "B+Tree invariants across 200 keys") == 0 return 0 @end
  @if assert_eq_int(btree_count(tree), 200, "B+Tree count should be exactly 200") == 0 return 0 @end

  @! Range Scan across leaf page boundaries [order_1050 .. order_1079] (30 items)
  scan_res = btree_scan(tree, "order_1050", "order_1079", 50)
  @if assert_eq_int(scan_res.len(), 30, "Scan count between order_1050 and order_1079") == 0 return 0 @end
  @if assert_eq_str(scan_res[0].key, "order_1050", "Scan first key") == 0 return 0 @end
  @if assert_eq_str(scan_res[29].key, "order_1079", "Scan last key") == 0 return 0 @end

  buffer_pool_close(pool)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 4: Large Scale Ingestion (600 Keys) & Point Check Spectrum
@! ----------------------------------------------------------------------------
@fn test_btree_large_scale_ingestion()
  db_path = "/tmp/test_maya_btree_scale.db"
  sys_unlink(db_path)

  pool = buffer_pool_open(db_path, 32)
  tree = btree_open(pool, 1)

  i = 0
  @while i < 600
    k = "device_" + (10000 + i).to_str()
    v = "telemetry_metrics_data_payload_sensor_" + i.to_str()
    tree = btree_insert(tree, k, v)
    i = i + 1
  @end

  @if assert_eq_int(btree_verify(tree), 1, "Verify all 600 keys in sorted order") == 0 return 0 @end
  @if assert_eq_int(btree_count(tree), 600, "Total count is 600") == 0 return 0 @end

  @! Check boundaries and interior keys
  @if assert_eq_str(btree_get(tree, "device_10000", "ERR"), "telemetry_metrics_data_payload_sensor_0", "First key") == 0 return 0 @end
  @if assert_eq_str(btree_get(tree, "device_10250", "ERR"), "telemetry_metrics_data_payload_sensor_250", "Mid key") == 0 return 0 @end
  @if assert_eq_str(btree_get(tree, "device_10599", "ERR"), "telemetry_metrics_data_payload_sensor_599", "Last key") == 0 return 0 @end

  buffer_pool_close(pool)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 5: Key Deletions, Dead Space Compaction & Re-Verification
@! ----------------------------------------------------------------------------
@fn test_btree_deletions_and_compaction()
  db_path = "/tmp/test_maya_btree_del.db"
  sys_unlink(db_path)

  pool = buffer_pool_open(db_path, 32)
  tree = btree_open(pool, 1)

  i = 0
  @while i < 300
    k = "session_" + (1000 + i).to_str()
    v = "token_" + i.to_str()
    tree = btree_insert(tree, k, v)
    i = i + 1
  @end

  @! Delete every second item (150 deletions)
  i = 0
  @while i < 300
    k = "session_" + (1000 + i).to_str()
    tree = btree_delete(tree, k)
    i = i + 2
  @end

  @if assert_eq_int(btree_count(tree), 150, "Remaining count should be 150") == 0 return 0 @end
  @if assert_eq_int(btree_verify(tree), 1, "Tree remains valid after 150 deletions") == 0 return 0 @end

  @! Confirm deleted keys are gone and retained keys remain
  @if assert_eq_str(btree_get(tree, "session_1000", "GONE"), "GONE", "Deleted session_1000") == 0 return 0 @end
  @if assert_eq_str(btree_get(tree, "session_1001", "GONE"), "token_1", "Retained session_1001") == 0 return 0 @end
  @if assert_eq_str(btree_get(tree, "session_1002", "GONE"), "GONE", "Deleted session_1002") == 0 return 0 @end
  @if assert_eq_str(btree_get(tree, "session_1003", "GONE"), "token_3", "Retained session_1003") == 0 return 0 @end

  buffer_pool_close(pool)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 6: Full Disk Persistence, Pool Flush & Cold Reopen
@! ----------------------------------------------------------------------------
@fn test_btree_cold_reopen_persistence()
  db_path = "/tmp/test_maya_btree_cold_reopen.db"
  sys_unlink(db_path)

  pool = buffer_pool_open(db_path, 16)
  tree = btree_open(pool, 1)

  i = 0
  @while i < 120
    k = "prod_" + (100 + i).to_str()
    v = "sku_price_" + (i * 15).to_str()
    tree = btree_insert(tree, k, v)
    i = i + 1
  @end

  saved_root_id = tree.root_page_id
  buffer_pool_close(pool)

  @! Cold reopen with a brand new buffer pool instance
  reopened_pool = buffer_pool_open(db_path, 16)
  @if assert_eq_int(reopened_pool.root_page_id, saved_root_id, "Page 0 Root Page ID must match") == 0 return 0 @end

  reopened_tree = btree_open(reopened_pool, reopened_pool.root_page_id)
  @if assert_eq_int(btree_verify(reopened_tree), 1, "Reopened tree verification") == 0 return 0 @end
  @if assert_eq_int(btree_count(reopened_tree), 120, "Reopened tree count 120") == 0 return 0 @end

  @if assert_eq_str(btree_get(reopened_tree, "prod_100", "ERR"), "sku_price_0", "Cold get prod_100") == 0 return 0 @end
  @if assert_eq_str(btree_get(reopened_tree, "prod_150", "ERR"), "sku_price_750", "Cold get prod_150") == 0 return 0 @end
  @if assert_eq_str(btree_get(reopened_tree, "prod_219", "ERR"), "sku_price_1785", "Cold get prod_219") == 0 return 0 @end

  buffer_pool_close(reopened_pool)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 7: Open-Ended Range Scan (start_key = "" and end_key = "")
@! ----------------------------------------------------------------------------
@fn test_btree_open_ended_range_scan()
  db_path = "/tmp/test_maya_btree_open_scan.db"
  sys_unlink(db_path)

  pool = buffer_pool_open(db_path, 16)
  tree = btree_open(pool, 1)

  @! Insert 80 keys
  i = 0
  @while i < 80
    k = "key_" + (100 + i).to_str()
    v = "val_" + i.to_str()
    tree = btree_insert(tree, k, v)
    i = i + 1
  @end

  @! Full scan from start to end (limit 100)
  all_results = btree_scan(tree, "", "", 100)
  @if assert_eq_int(all_results.len(), 80, "Open-ended scan retrieves all 80 items") == 0 return 0 @end
  @if assert_eq_str(all_results[0].key, "key_100", "First scanned key") == 0 return 0 @end
  @if assert_eq_str(all_results[79].key, "key_179", "Last scanned key") == 0 return 0 @end

  @! Scan with limit smaller than total
  limited_results = btree_scan(tree, "", "", 25)
  @if assert_eq_int(limited_results.len(), 25, "Scan with limit 25") == 0 return 0 @end
  @if assert_eq_str(limited_results[24].key, "key_124", "25th key is key_124") == 0 return 0 @end

  buffer_pool_close(pool)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 8: Non-Existent Boundary Range Scans
@! ----------------------------------------------------------------------------
@fn test_btree_nonexistent_boundary_scans()
  db_path = "/tmp/test_maya_btree_boundary_scan.db"
  sys_unlink(db_path)

  pool = buffer_pool_open(db_path, 16)
  tree = btree_open(pool, 1)

  tree = btree_insert(tree, "b_item", "val_b")
  tree = btree_insert(tree, "d_item", "val_d")
  tree = btree_insert(tree, "f_item", "val_f")
  tree = btree_insert(tree, "h_item", "val_h")

  @! Scan starting at non-existent "c_item" up to "g_item" -> should return "d_item", "f_item"
  res1 = btree_scan(tree, "c_item", "g_item", 10)
  @if assert_eq_int(res1.len(), 2, "Scan c_item to g_item should return 2 entries") == 0 return 0 @end
  @if assert_eq_str(res1[0].key, "d_item", "First entry d_item") == 0 return 0 @end
  @if assert_eq_str(res1[1].key, "f_item", "Second entry f_item") == 0 return 0 @end

  @! Scan beyond all keys -> should return 0 entries
  res2 = btree_scan(tree, "z_item", "z_zz", 10)
  @if assert_eq_int(res2.len(), 0, "Scan past all keys returns empty") == 0 return 0 @end

  buffer_pool_close(pool)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 9: Interleaved Insertions, Updates, and Deletions
@! ----------------------------------------------------------------------------
@fn test_btree_interleaved_operations()
  db_path = "/tmp/test_maya_btree_interleaved.db"
  sys_unlink(db_path)

  pool = buffer_pool_open(db_path, 16)
  tree = btree_open(pool, 1)

  @! Batch 1: Insert 50 keys
  i = 0
  @while i < 50
    tree = btree_insert(tree, "k_" + (100 + i).to_str(), "initial_" + i.to_str())
    i = i + 1
  @end

  @! Batch 2: Update first 25 keys
  i = 0
  @while i < 25
    tree = btree_insert(tree, "k_" + (100 + i).to_str(), "updated_" + i.to_str())
    i = i + 1
  @end

  @! Batch 3: Delete keys from 10 to 19
  i = 10
  @while i < 20
    tree = btree_delete(tree, "k_" + (100 + i).to_str())
    i = i + 1
  @end

  @if assert_eq_int(btree_count(tree), 40, "Count after 50 inserts, 25 updates, 10 deletes should be 40") == 0 return 0 @end
  @if assert_eq_int(btree_verify(tree), 1, "Verify tree after interleaved operations") == 0 return 0 @end

  @! Verify updated key
  @if assert_eq_str(btree_get(tree, "k_100", "ERR"), "updated_0", "k_100 should be updated_0") == 0 return 0 @end
  @! Verify deleted key
  @if assert_eq_str(btree_get(tree, "k_115", "ERR"), "ERR", "k_115 should be deleted") == 0 return 0 @end
  @! Verify untouched key
  @if assert_eq_str(btree_get(tree, "k_130", "ERR"), "initial_30", "k_130 should be initial_30") == 0 return 0 @end

  buffer_pool_close(pool)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 10: Empty Leaf Unlinking & Post-Unlink Scan Continuity
@! ----------------------------------------------------------------------------
@fn test_btree_empty_leaf_unlinking()
  db_path = "/tmp/test_maya_btree_unlink.db"
  sys_unlink(db_path)

  pool = buffer_pool_open(db_path, 16)
  tree = btree_open(pool, 1)

  @! Insert 100 keys to establish several leaf nodes
  i = 0
  @while i < 100
    tree = btree_insert(tree, "rec_" + (1000 + i).to_str(), "val_" + i.to_str())
    i = i + 1
  @end

  @! Delete keys 10 to 40 (which will empty at least one middle leaf page)
  i = 10
  @while i <= 40
    tree = btree_delete(tree, "rec_" + (1000 + i).to_str())
    i = i + 1
  @end

  @if assert_eq_int(btree_count(tree), 69, "Remaining count is 69") == 0 return 0 @end
  @if assert_eq_int(btree_verify(tree), 1, "Tree remains valid after leaf unlinking") == 0 return 0 @end

  @! Scan the entire tree horizontally across leaf sibling pointers
  scan_all = btree_scan(tree, "", "", 100)
  @if assert_eq_int(scan_all.len(), 69, "Range scan across unlinked pages returns exactly 69 items") == 0 return 0 @end
  @if assert_eq_str(scan_all[0].key, "rec_1000", "First item rec_1000") == 0 return 0 @end
  @if assert_eq_str(scan_all[9].key, "rec_1009", "10th item rec_1009") == 0 return 0 @end
  @if assert_eq_str(scan_all[10].key, "rec_1041", "11th item skips directly to rec_1041") == 0 return 0 @end
  @if assert_eq_str(scan_all[68].key, "rec_1099", "Last item rec_1099") == 0 return 0 @end

  buffer_pool_close(pool)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Main Test Runner
@! ----------------------------------------------------------------------------
@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Module: universe/db/btree & buffer (B+Tree Engine)")
  println("=================================================================")

  passed = 0
  total = 10

  @if test_buffer_pool_eviction_and_persistence() == 1
    println("  [PASS] Test 1: Buffer pool frame allocation, LRU eviction & page 0 persistence")
    passed = passed + 1
  @else
    println("  [FAIL] Test 1: Buffer pool frame allocation, LRU eviction & page 0 persistence")
  @end

  @if test_btree_point_queries_and_updates() == 1
    println("  [PASS] Test 2: B+Tree point query lookups and in-place key updates")
    passed = passed + 1
  @else
    println("  [FAIL] Test 2: B+Tree point query lookups and in-place key updates")
  @end

  @if test_btree_splits_and_horizontal_scan() == 1
    println("  [PASS] Test 3: B+Tree leaf splits, separator promotion & horizontal sibling scans")
    passed = passed + 1
  @else
    println("  [FAIL] Test 3: B+Tree leaf splits, separator promotion & horizontal sibling scans")
  @end

  @if test_btree_large_scale_ingestion() == 1
    println("  [PASS] Test 4: Large scale ingestion (600 keys) and boundary verification")
    passed = passed + 1
  @else
    println("  [FAIL] Test 4: Large scale ingestion (600 keys) and boundary verification")
  @end

  @if test_btree_deletions_and_compaction() == 1
    println("  [PASS] Test 5: Key deletions, defragmentation compaction & continuity check")
    passed = passed + 1
  @else
    println("  [FAIL] Test 5: Key deletions, defragmentation compaction & continuity check")
  @end

  @if test_btree_cold_reopen_persistence() == 1
    println("  [PASS] Test 6: Database flush, file close, and cold restart verification")
    passed = passed + 1
  @else
    println("  [FAIL] Test 6: Database flush, file close, and cold restart verification")
  @end

  @if test_btree_open_ended_range_scan() == 1
    println("  [PASS] Test 7: Open-ended horizontal range scans (empty boundaries & limits)")
    passed = passed + 1
  @else
    println("  [FAIL] Test 7: Open-ended horizontal range scans (empty boundaries & limits)")
  @end

  @if test_btree_nonexistent_boundary_scans() == 1
    println("  [PASS] Test 8: Non-existent boundary range scans and empty match handling")
    passed = passed + 1
  @else
    println("  [FAIL] Test 8: Non-existent boundary range scans and empty match handling")
  @end

  @if test_btree_interleaved_operations() == 1
    println("  [PASS] Test 9: Interleaved insertions, updates, deletions and tree balance verification")
    passed = passed + 1
  @else
    println("  [FAIL] Test 9: Interleaved insertions, updates, deletions and tree balance verification")
  @end

  @if test_btree_empty_leaf_unlinking() == 1
    println("  [PASS] Test 10: Empty leaf unlinking and post-unlink range scan continuity")
    passed = passed + 1
  @else
    println("  [FAIL] Test 10: Empty leaf unlinking and post-unlink range scan continuity")
  @end

  println("-----------------------------------------------------------------")
  println("B+Tree Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if passed == total
    println("✓ universe/db/btree & buffer E2E Test Suite PASSED")
  @else
    println("✗ universe/db/btree & buffer E2E Test Suite FAILED")
  @end
@end
