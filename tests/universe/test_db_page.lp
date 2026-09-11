@! ============================================================================
@! MAYA UNIVERSE DB TEST SUITE: SLOTTED BINARY PAGE (universe/db/page.maya)
@! File: tests/universe/test_db_page.maya
@! ============================================================================

import "universe/db/page"
import "universe/core/string"

@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Module: universe/db/page (Slotted Binary Page)")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! --------------------------------------------------------------------------
  @! Test 1: Page Allocation & Binary Primitives (8/16/32/64-bit Little Endian)
  @! --------------------------------------------------------------------------
  total = total + 1
  p = page_new()
  page_write_u8(p, 0, 255)
  page_write_u16(p, 1, 65535)
  page_write_u32(p, 3, 305419896)      @! 0x12345678
  page_write_u64(p, 7, 81985529216486895) @! 0x0123456789ABCDEF
  page_write_str(p, 15, "MayaDB")

  v8 = page_read_u8(p, 0)
  v16 = page_read_u16(p, 1)
  v32 = page_read_u32(p, 3)
  v64 = page_read_u64(p, 7)
  vstr = page_read_str(p, 15, 6)

  @if v8 == 255 && v16 == 65535 && v32 == 305419896 && v64 == 81985529216486895 && vstr == "MayaDB"
    passed = passed + 1
    println("  [PASS] Test 1: Page allocation and binary integer/string primitives")
  @else
    failed = failed + 1
    println("  [FAIL] Test 1: Binary primitives mismatch")
  @end

  @! --------------------------------------------------------------------------
  @! Test 2: Leaf & Internal Header Formatting & Accessors
  @! --------------------------------------------------------------------------
  total = total + 1
  p_leaf = page_new()
  page_format_leaf(p_leaf, 42, 10, 20)
  
  l_id = page_get_id(p_leaf)
  l_type = page_get_type(p_leaf)
  l_cnt = page_get_cell_count(p_leaf)
  l_lower = page_get_free_lower(p_leaf)
  l_upper = page_get_free_upper(p_leaf)
  l_prev = page_get_prev_page_id(p_leaf)
  l_next = page_get_next_page_id(p_leaf)
  l_free = page_free_space(p_leaf)

  p_int = page_new()
  page_format_internal(p_int, 99)
  page_set_first_child_page_id(p_int, 101)
  i_id = page_get_id(p_int)
  i_type = page_get_type(p_int)
  i_first = page_get_first_child_page_id(p_int)

  @if l_id == 42 && l_type == 1 && l_cnt == 0 && l_lower == 32 && l_upper == 4096 && l_prev == 10 && l_next == 20 && l_free == 4064 && i_id == 99 && i_type == 2 && i_first == 101
    passed = passed + 1
    println("  [PASS] Test 2: Leaf & Internal page header formatting and field accessors")
  @else
    failed = failed + 1
    println("  [FAIL] Test 2: Page header formatting failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 3: Lexicographical Key Comparison (page_str_cmp)
  @! --------------------------------------------------------------------------
  total = total + 1
  cmp1 = page_str_cmp("apple", "banana")
  cmp2 = page_str_cmp("banana", "banana")
  cmp3 = page_str_cmp("orange", "banana")
  cmp4 = page_str_cmp("apple", "apple_pie")
  cmp5 = page_str_cmp("apple_pie", "apple")

  @if cmp1 == (0 - 1) && cmp2 == 0 && cmp3 == 1 && cmp4 == (0 - 1) && cmp5 == 1
    passed = passed + 1
    println("  [PASS] Test 3: Deterministic lexicographical string comparison (page_str_cmp)")
  @else
    failed = failed + 1
    println("  [FAIL] Test 3: String comparison returned incorrect ordering")
  @end

  @! --------------------------------------------------------------------------
  @! Test 4: Unordered Multi-Key Insertion & Sorted Slot Array
  @! --------------------------------------------------------------------------
  total = total + 1
  p_data = page_new()
  page_format_leaf(p_data, 1, 0, 0)

  @! Insert keys in random order
  page_insert_leaf_cell(p_data, "echo", "val_echo")
  page_insert_leaf_cell(p_data, "bravo", "val_bravo")
  page_insert_leaf_cell(p_data, "alpha", "val_alpha")
  page_insert_leaf_cell(p_data, "delta", "val_delta")
  page_insert_leaf_cell(p_data, "charlie", "val_charlie")

  cnt = page_get_cell_count(p_data)
  k0 = page_get_leaf_key(p_data, 0)
  k1 = page_get_leaf_key(p_data, 1)
  k2 = page_get_leaf_key(p_data, 2)
  k3 = page_get_leaf_key(p_data, 3)
  k4 = page_get_leaf_key(p_data, 4)

  v0 = page_get_leaf_val(p_data, 0)
  v1 = page_get_leaf_val(p_data, 1)
  v2 = page_get_leaf_val(p_data, 2)
  v3 = page_get_leaf_val(p_data, 3)
  v4 = page_get_leaf_val(p_data, 4)

  sorted_ok = 1
  @if cnt != 5 || k0 != "alpha" || k1 != "bravo" || k2 != "charlie" || k3 != "delta" || k4 != "echo"
    sorted_ok = 0
  @end
  @if v0 != "val_alpha" || v1 != "val_bravo" || v2 != "val_charlie" || v3 != "val_delta" || v4 != "val_echo"
    sorted_ok = 0
  @end

  @if sorted_ok == 1
    passed = passed + 1
    println("  [PASS] Test 4: Multi-key insertions strictly maintain sorted slot array order")
  @else
    failed = failed + 1
    println("  [FAIL] Test 4: Insertion sorting invariant violated")
  @end

  @! --------------------------------------------------------------------------
  @! Test 5: O(log N) Binary Search Lookups
  @! --------------------------------------------------------------------------
  total = total + 1
  s_alpha = page_find_leaf_cell(p_data, "alpha")
  s_charlie = page_find_leaf_cell(p_data, "charlie")
  s_echo = page_find_leaf_cell(p_data, "echo")
  s_missing = page_find_leaf_cell(p_data, "foxtrot")
  s_before = page_find_leaf_cell(p_data, "aaa")

  lookup_ok = 1
  @if s_alpha.found != 1 || s_alpha.value != "val_alpha" || s_alpha.index != 0
    lookup_ok = 0
  @end
  @if s_charlie.found != 1 || s_charlie.value != "val_charlie" || s_charlie.index != 2
    lookup_ok = 0
  @end
  @if s_echo.found != 1 || s_echo.value != "val_echo" || s_echo.index != 4
    lookup_ok = 0
  @end
  @if s_missing.found != 0 || s_missing.index != 5
    lookup_ok = 0
  @end
  @if s_before.found != 0 || s_before.index != 0
    lookup_ok = 0
  @end

  @if lookup_ok == 1
    passed = passed + 1
    println("  [PASS] Test 5: Binary search leaf cell retrieval and insertion index calculation")
  @else
    failed = failed + 1
    println("  [FAIL] Test 5: Binary search lookups failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 6: In-Place Key-Value Update (Same & Different Length)
  @! --------------------------------------------------------------------------
  total = total + 1
  @! Same length update
  page_insert_leaf_cell(p_data, "bravo", "val_BRAVO")
  up1 = page_find_leaf_cell(p_data, "bravo")

  @! Different length update
  page_insert_leaf_cell(p_data, "alpha", "val_alpha_extended_payload_2026")
  up2 = page_find_leaf_cell(p_data, "alpha")

  @if up1.found == 1 && up1.value == "val_BRAVO" && up2.found == 1 && up2.value == "val_alpha_extended_payload_2026" && page_get_cell_count(p_data) == 5
    passed = passed + 1
    println("  [PASS] Test 6: In-place key-value updates with length variation")
  @else
    failed = failed + 1
    println("  [FAIL] Test 6: Key-value update failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 7: Key Deletion & Zero-Fragmentation Defragmentation
  @! --------------------------------------------------------------------------
  total = total + 1
  del_res = page_delete_leaf_cell(p_data, "charlie")
  cnt_after_del = page_get_cell_count(p_data)
  del_search = page_find_leaf_cell(p_data, "charlie")

  free_before_defrag = page_free_space(p_data)
  page_defrag(p_data)
  free_after_defrag = page_free_space(p_data)

  @if del_res == 1 && cnt_after_del == 4 && del_search.found == 0 && free_after_defrag >= free_before_defrag
    passed = passed + 1
    println("  [PASS] Test 7: Key deletion and compaction/defragmentation dead space recovery")
  @else
    failed = failed + 1
    println("  [FAIL] Test 7: Deletion or compaction failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 8: 50/50 Leaf Node Splitting & Sibling Linkage
  @! --------------------------------------------------------------------------
  total = total + 1
  src_leaf = page_new()
  page_format_leaf(src_leaf, 100, 0, 0)
  dst_leaf = page_new()
  page_set_id(dst_leaf, 101)

  @! Populate src_leaf with 6 keys
  page_insert_leaf_cell(src_leaf, "k10", "v10")
  page_insert_leaf_cell(src_leaf, "k20", "v20")
  page_insert_leaf_cell(src_leaf, "k30", "v30")
  page_insert_leaf_cell(src_leaf, "k40", "v40")
  page_insert_leaf_cell(src_leaf, "k50", "v50")
  page_insert_leaf_cell(src_leaf, "k60", "v60")

  split_res = page_split_leaf(src_leaf, dst_leaf)
  src_cnt = page_get_cell_count(src_leaf)
  dst_cnt = page_get_cell_count(dst_leaf)
  src_next = page_get_next_page_id(src_leaf)
  dst_prev = page_get_prev_page_id(dst_leaf)

  split_ok = 1
  @if split_res.promoted_key != "k40" || split_res.split_page_id != 101
    split_ok = 0
  @end
  @if src_cnt != 3 || dst_cnt != 3
    split_ok = 0
  @end
  @if src_next != 101 || dst_prev != 100
    split_ok = 0
  @end
  @if page_get_leaf_key(src_leaf, 0) != "k10" || page_get_leaf_key(src_leaf, 2) != "k30"
    split_ok = 0
  @end
  @if page_get_leaf_key(dst_leaf, 0) != "k40" || page_get_leaf_key(dst_leaf, 2) != "k60"
    split_ok = 0
  @end

  @if split_ok == 1
    passed = passed + 1
    println("  [PASS] Test 8: Leaf 50/50 splitting, separator promotion, and sibling links")
  @else
    failed = failed + 1
    println("  [FAIL] Test 8: Leaf splitting failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 9: Internal Node Cell Insertion, Splitting, & Routing
  @! --------------------------------------------------------------------------
  total = total + 1
  p_router = page_new()
  page_format_internal(p_router, 200)
  page_set_first_child_page_id(p_router, 10)  @! C_0 for keys < "mango"

  page_insert_internal_cell(p_router, "mango", 20)  @! C_1 for "mango" <= key < "zebra"
  page_insert_internal_cell(p_router, "zebra", 30)  @! C_2 for key >= "zebra"

  r_ant = page_find_internal_child(p_router, "ant")
  r_lemon = page_find_internal_child(p_router, "lemon")
  r_mango = page_find_internal_child(p_router, "mango")
  r_walnut = page_find_internal_child(p_router, "walnut")
  r_zebra = page_find_internal_child(p_router, "zebra")
  r_zoo = page_find_internal_child(p_router, "zoo")

  routing_ok = 1
  @if r_ant != 10 || r_lemon != 10
    routing_ok = 0
  @end
  @if r_mango != 20 || r_walnut != 20
    routing_ok = 0
  @end
  @if r_zebra != 30 || r_zoo != 30
    routing_ok = 0
  @end

  @if routing_ok == 1
    passed = passed + 1
    println("  [PASS] Test 9: Internal node separator key routing and child navigation")
  @else
    failed = failed + 1
    println("  [FAIL] Test 9: Internal routing failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 10: page_write_bytes / page_read_bytes Helper Functions
  @! --------------------------------------------------------------------------
  total = total + 1
  p_bytes = page_new()
  page_write_bytes(p_bytes, 100, "SovereignMayaDB")
  read_str_res = page_read_bytes(p_bytes, 100, 15)
  @if read_str_res == "SovereignMayaDB"
    passed = passed + 1
    println("  [PASS] Test 10: page_write_bytes and page_read_bytes helpers")
  @else
    failed = failed + 1
    println("  [FAIL] Test 10: page_write_bytes / page_read_bytes failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 11: 50/50 Internal Node Splitting (page_split_internal)
  @! --------------------------------------------------------------------------
  total = total + 1
  src_int = page_new()
  page_format_internal(src_int, 300)
  page_set_first_child_page_id(src_int, 1000)

  page_insert_internal_cell(src_int, "cat", 1001)
  page_insert_internal_cell(src_int, "dog", 1002)
  page_insert_internal_cell(src_int, "fox", 1003)
  page_insert_internal_cell(src_int, "horse", 1004)
  page_insert_internal_cell(src_int, "lion", 1005)

  dst_int = page_new()
  page_set_id(dst_int, 301)

  int_split_res = page_split_internal(src_int, dst_int)
  int_promoted = int_split_res.promoted_key
  int_dst_id = int_split_res.split_page_id

  src_int_cnt = page_get_cell_count(src_int)
  dst_int_cnt = page_get_cell_count(dst_int)
  dst_first_child = page_get_first_child_page_id(dst_int)

  int_split_ok = 1
  @if int_promoted != "fox" || int_dst_id != 301
    int_split_ok = 0
  @end
  @if src_int_cnt != 2 || dst_int_cnt != 2
    int_split_ok = 0
  @end
  @if dst_first_child != 1003
    int_split_ok = 0
  @end
  @if page_get_internal_key(src_int, 0) != "cat" || page_get_internal_key(src_int, 1) != "dog"
    int_split_ok = 0
  @end
  @if page_get_internal_key(dst_int, 0) != "horse" || page_get_internal_key(dst_int, 1) != "lion"
    int_split_ok = 0
  @end

  @if int_split_ok == 1
    passed = passed + 1
    println("  [PASS] Test 11: Internal node 50/50 split and first_child_page_id propagation")
  @else
    failed = failed + 1
    println("  [FAIL] Test 11: Internal node split failed")
  @end

  @! --------------------------------------------------------------------------
  @! Test 12: Scattered Multiple Deletions & Full Compaction Stress
  @! --------------------------------------------------------------------------
  total = total + 1
  p_stress = page_new()
  page_format_leaf(p_stress, 400, 0, 0)

  @! Insert 15 items
  i = 0
  @while i < 15
    k = "key_" + (100 + i).to_str()
    v = "value_payload_" + (i * 7).to_str()
    page_insert_leaf_cell(p_stress, k, v)
    i = i + 1
  @end

  initial_free = page_free_space(p_stress)

  @! Delete every third item
  page_delete_leaf_cell(p_stress, "key_102")
  page_delete_leaf_cell(p_stress, "key_105")
  page_delete_leaf_cell(p_stress, "key_108")
  page_delete_leaf_cell(p_stress, "key_111")
  page_delete_leaf_cell(p_stress, "key_114")

  cnt_after_del = page_get_cell_count(p_stress)
  page_defrag(p_stress)
  compacted_free = page_free_space(p_stress)

  defrag_stress_ok = 1
  @if cnt_after_del != 10
    defrag_stress_ok = 0
  @end
  @if compacted_free <= initial_free
    defrag_stress_ok = 0
  @end

  @! Verify all 10 remaining items can be retrieved
  @if page_find_leaf_cell(p_stress, "key_100").found != 1 || page_find_leaf_cell(p_stress, "key_101").found != 1
    defrag_stress_ok = 0
  @end
  @if page_find_leaf_cell(p_stress, "key_102").found != 0
    defrag_stress_ok = 0
  @end
  @if page_find_leaf_cell(p_stress, "key_103").found != 1 || page_find_leaf_cell(p_stress, "key_104").found != 1
    defrag_stress_ok = 0
  @end
  @if page_find_leaf_cell(p_stress, "key_105").found != 0
    defrag_stress_ok = 0
  @end

  @if defrag_stress_ok == 1
    passed = passed + 1
    println("  [PASS] Test 12: Scattered multiple deletions and defragmentation compaction stress")
  @else
    failed = failed + 1
    println("  [FAIL] Test 12: Defragmentation stress test failed")
  @end

  println("-----------------------------------------------------------------")
  println("Slotted Page Test Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ universe/db/page E2E Test Suite PASSED")
  @else
    println("✗ universe/db/page Test Suite FAILED")
  @end
@end
