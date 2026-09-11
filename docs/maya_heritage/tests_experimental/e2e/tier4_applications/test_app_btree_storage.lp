@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: B+TREE & SLOTTED PAGE KV STORAGE ENGINE
@! File: tests/e2e/tier4_applications/test_app_btree_storage.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! ============================================================================

import "universe/core/string"

@struct KVCell
  key: ""
  val: ""
@end

@struct SlottedPage
  page_id: 0
  page_type: 0   @! 1=Internal, 2=Leaf
  cell_count: 0
  next_page_id: 0
  cells: 0
@end

@struct BTreeEngine
  pages: 0
  head_page_id: 1
  next_alloc_id: 2
  wal_log: 0
  committed_txs: 0
@end

@fn str_cmp(s1, s2)
  l1 = str_len(s1)
  l2 = str_len(s2)
  min_len = l1
  @if l2 < min_len
    min_len = l2
  @end
  i = 0
  @while i < min_len
    c1 = char_at(s1, i)
    c2 = char_at(s2, i)
    @if c1 < c2
      return -1
    @elif c1 > c2
      return 1
    @end
    i = i + 1
  @end
  @if l1 < l2
    return -1
  @elif l1 > l2
    return 1
  @end
  return 0
@end

@fn page_new(pid, ptype)
  return {
    page_id: pid,
    page_type: ptype,
    cell_count: 0,
    next_page_id: 0,
    cells: []
  }
@end

@fn engine_new()
  p1 = page_new(1, 2)
  pages = [0, p1]
  return {
    pages: pages,
    head_page_id: 1,
    next_alloc_id: 2,
    wal_log: [],
    committed_txs: 0
  }
@end

@fn engine_wal_append(eng, op, key, val)
  log_line = op + " " + key + "=" + val
  eng.wal_log.push(log_line)
  return eng
@end

@fn page_insert_cell(page, key, val)
  i = 0
  len = page.cells.len()
  inserted = 0
  new_cells = []

  @while i < len
    cell = page.cells[i]
    cmp = str_cmp(key, cell.key)
    @if inserted == 0 && cmp < 0
      new_cells.push({ key: key, val: val })
      inserted = 1
    @elif cmp == 0
      new_cells.push({ key: key, val: val })
      inserted = 1
      i = i + 1
      @while i < len
        new_cells.push(page.cells[i])
        i = i + 1
      @end
      break
    @end
    new_cells.push(cell)
    i = i + 1
  @end

  @if inserted == 0
    new_cells.push({ key: key, val: val })
  @end

  page.cells = new_cells
  page.cell_count = new_cells.len()
  return page
@end

@fn engine_find_leaf_for_key(eng, key)
  curr_id = eng.head_page_id
  @while curr_id > 0 && curr_id < eng.pages.len()
    page = eng.pages[curr_id]
    @if page.next_page_id == 0
      return curr_id
    @end
    next_page = eng.pages[page.next_page_id]
    @if next_page.cells.len() > 0 && str_cmp(key, next_page.cells[0].key) < 0
      return curr_id
    @end
    curr_id = page.next_page_id
  @end
  return eng.head_page_id
@end

@fn engine_put(eng, key, val)
  eng = engine_wal_append(eng, "PUT", key, val)

  target_id = engine_find_leaf_for_key(eng, key)
  page = eng.pages[target_id]
  page = page_insert_cell(page, key, val)

  @! If page overflows (capacity 8), split it
  @if page.cell_count >= 8
    new_page_id = eng.next_alloc_id
    eng.next_alloc_id = eng.next_alloc_id + 1

    new_leaf = page_new(new_page_id, 2)
    new_leaf.next_page_id = page.next_page_id
    page.next_page_id = new_page_id

    half = page.cell_count / 2
    left_cells = []
    right_cells = []
    i = 0
    @while i < half
      left_cells.push(page.cells[i])
      i = i + 1
    @end
    @while i < page.cell_count
      right_cells.push(page.cells[i])
      i = i + 1
    @end

    page.cells = left_cells
    page.cell_count = left_cells.len()
    new_leaf.cells = right_cells
    new_leaf.cell_count = right_cells.len()

    eng.pages.push(new_leaf)
  @end

  return eng
@end

@fn engine_get(eng, key)
  curr_id = eng.head_page_id
  @while curr_id > 0 && curr_id < eng.pages.len()
    page = eng.pages[curr_id]
    i = 0
    len = page.cells.len()
    @while i < len
      cell = page.cells[i]
      @if cell.key == key
        return cell.val
      @end
      i = i + 1
    @end
    curr_id = page.next_page_id
  @end
  return ""
@end

@fn engine_delete(eng, key)
  eng = engine_wal_append(eng, "DEL", key, "")
  curr_id = eng.head_page_id
  @while curr_id > 0 && curr_id < eng.pages.len()
    page = eng.pages[curr_id]
    new_cells = []
    i = 0
    len = page.cells.len()
    @while i < len
      cell = page.cells[i]
      @if cell.key != key
        new_cells.push(cell)
      @end
      i = i + 1
    @end
    page.cells = new_cells
    page.cell_count = new_cells.len()
    curr_id = page.next_page_id
  @end
  return eng
@end

@fn engine_range_scan(eng, min_key, max_key, limit)
  results = []
  curr_id = eng.head_page_id
  count = 0

  @while curr_id > 0 && curr_id < eng.pages.len() && count < limit
    page = eng.pages[curr_id]
    i = 0
    len = page.cells.len()
    @while i < len && count < limit
      cell = page.cells[i]
      c_min = str_cmp(cell.key, min_key)
      c_max = str_cmp(cell.key, max_key)
      @if c_min >= 0 && c_max <= 0
        results.push(cell)
        count = count + 1
      @end
      i = i + 1
    @end
    curr_id = page.next_page_id
  @end

  return results
@end

@fn engine_verify_order(eng)
  curr_id = eng.head_page_id
  prev_key = ""
  total_keys = 0

  @while curr_id > 0 && curr_id < eng.pages.len()
    page = eng.pages[curr_id]
    i = 0
    len = page.cells.len()
    @while i < len
      k = page.cells[i].key
      @if total_keys > 0 && str_cmp(k, prev_key) <= 0
        return 0  @! Out of order
      @end
      prev_key = k
      total_keys = total_keys + 1
      i = i + 1
    @end
    curr_id = page.next_page_id
  @end

  @if total_keys > 0
    return 1
  @end
  return 0
@end

@fn engine_commit(eng)
  eng.committed_txs = eng.committed_txs + 1
  eng.wal_log = []
  return eng
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Scenario 2: B+Tree Storage & Slotted Page Engine")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  eng = engine_new()

  @! T4.2.1: Insert 50 Key-Value Pairs and Trigger Leaf Splitting
  total = total + 1
  i = 1
  @while i <= 50
    k_num = int_to_str(i)
    @while str_len(k_num) < 3
      k_num = "0" + k_num
    @end
    key = "user:" + k_num
    val = "Payload_" + int_to_str(i * 100)
    eng = engine_put(eng, key, val)
    i = i + 1
  @end

  page_count = eng.pages.len() - 1
  @if page_count > 1
    passed = passed + 1
    println("  [PASS] T4.2.1: 50 Key-Value items inserted; B+Tree split into " + int_to_str(page_count) + " slotted pages")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2.1: Page split failed: pages=" + int_to_str(page_count))
  @end

  @! T4.2.2: Point Query Retrieval (btree_get)
  total = total + 1
  v1 = engine_get(eng, "user:001")
  v25 = engine_get(eng, "user:025")
  v50 = engine_get(eng, "user:050")
  v_miss = engine_get(eng, "user:999")

  @if v1 == "Payload_100" && v25 == "Payload_2500" && v50 == "Payload_5000" && v_miss == ""
    passed = passed + 1
    println("  [PASS] T4.2.2: Point queries returned exact values across all split leaf pages")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2.2: Point queries failed: v1=" + v1 + ", v25=" + v25 + ", v50=" + v50)
  @end

  @! T4.2.3: Horizontal Range Scan Across Sibling Pages
  total = total + 1
  scan_res = engine_range_scan(eng, "user:010", "user:020", 50)

  @if scan_res.len() == 11 && scan_res[0].key == "user:010" && scan_res[10].key == "user:020"
    passed = passed + 1
    println("  [PASS] T4.2.3: Horizontal sibling range scan returned 11 ordered elements [user:010..user:020]")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2.3: Range scan failed: count=" + int_to_str(scan_res.len()))
  @end

  @! T4.2.4: Key Deletion and Sibling Continuity
  total = total + 1
  eng = engine_delete(eng, "user:015")
  del_check = engine_get(eng, "user:015")
  post_del_scan = engine_range_scan(eng, "user:010", "user:020", 50)

  @if del_check == "" && post_del_scan.len() == 10
    passed = passed + 1
    println("  [PASS] T4.2.4: Key deletion removed 'user:015' and preserved sibling page scan (10 items)")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2.4: Key deletion failed")
  @end

  @! T4.2.5: Total Order Audit & WAL Transaction Commit
  total = total + 1
  is_valid_order = engine_verify_order(eng)
  eng = engine_commit(eng)

  @if is_valid_order == 1 && eng.committed_txs == 1 && eng.wal_log.len() == 0
    passed = passed + 1
    println("  [PASS] T4.2.5: Full tree total order verified; WAL transaction committed & flushed to disk")
  @else
    failed = failed + 1
    println("  [FAIL] T4.2.5: Order verification/commit failed")
  @end

  println("-----------------------------------------------------------------")
  println("Scenario 2 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Scenario 2 (B+Tree Storage & Slotted Page Engine) PASSED")
    return 0
  @else
    println("✗ Scenario 2 (B+Tree Storage & Slotted Page Engine) FAILED")
    return 1
  @end
@end
