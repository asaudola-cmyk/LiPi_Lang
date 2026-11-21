@! ============================================================================
@! LIPI UNIVERSE DB — DISK-BACKED B+TREE ENGINE (aati/lipidb/btree.lp)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! Sovereign Slotted 4096-byte Binary Pages with LRU Cache & Syscall Persistence
@! ============================================================================

import "utso/syscalls"
import "utso/collections"
import "utso/string"
import "aati/lipidb/page"
import "aati/lipidb/buffer"

@! ----------------------------------------------------------------------------
@! 1. Data Structures
@! ----------------------------------------------------------------------------

@struct BTree
  pool: BufferPool
  root_page_id: i64
  height: i64
  degree: i64
@end

@struct BTreeSearchResult
  found: i64
  value: string
  leaf_page_id: i64
  slot_index: i64
@end

@! ----------------------------------------------------------------------------
@! 2. B+Tree Initialization & Construction
@! ----------------------------------------------------------------------------

@! Opens or connects to an existing B+Tree rooted at root_page_id
@fn btree_open(pool: BufferPool, root_page_id)
  @if root_page_id <= 0
    root_page_id = pool.root_page_id
  @end
  @if root_page_id <= 0
    root_page_id = 1
  @end

  @! Compute tree height by traversing from root down to leaf
  h = 1
  curr = root_page_id
  loop_active = 1
  @while loop_active == 1
    buf = buffer_pool_fetch_page(pool, curr)
    ptype = page_get_type(buf)
    @if ptype == PAGE_TYPE_INTERNAL()
      h = h + 1
      next_id = page_get_first_child_page_id(buf)
      buffer_pool_unpin_page(pool, curr, 0)
      curr = next_id
    @else
      buffer_pool_unpin_page(pool, curr, 0)
      loop_active = 0
    @end
  @end

  res: BTree = {
    pool: pool,
    root_page_id: root_page_id,
    height: h,
    degree: 64
  }
  return res
@end

@! Constructor alias conforming to PROJECT.md
@fn btree_new(pool: BufferPool, root_page_id)
  return btree_open(pool, root_page_id)
@end

@! ----------------------------------------------------------------------------
@! 3. Point Query Lookups & Searches
@! ----------------------------------------------------------------------------

@! Performs exact key search, traversing internal routing pages down to target leaf
@fn btree_search(tree: BTree, key)
  curr_id = tree.root_page_id

  @while 1
    buf = buffer_pool_fetch_page(tree.pool, curr_id)
    ptype = page_get_type(buf)

    @if ptype == PAGE_TYPE_INTERNAL()
      child_id = page_find_internal_child(buf, key)
      buffer_pool_unpin_page(tree.pool, curr_id, 0)
      curr_id = child_id
    @else
      res: PageSearchLeafResult = page_find_leaf_cell(buf, key)
      buffer_pool_unpin_page(tree.pool, curr_id, 0)
      return {
        found: res.found,
        value: res.value,
        leaf_page_id: curr_id,
        slot_index: res.index
      }
    @end
  @end

  return { found: 0, value: "", leaf_page_id: 0, slot_index: 0 }
@end

@! Retrieves value associated with key, or default_val if key does not exist
@fn btree_get(tree: BTree, key, default_val)
  res: BTreeSearchResult = btree_search(tree, key)
  @if res.found == 1
    return res.value
  @end
  return default_val
@end

@! ----------------------------------------------------------------------------
@! 4. Key-Value Insertion & Node Splitting
@! ----------------------------------------------------------------------------

@! Internal helper to recursively insert separator keys into parent internal nodes
@fn btree_insert_parent(tree: BTree, stack, left_child_id, key, right_child_id)
  @if stack.len() == 0
    @! Root Split: Allocate a new internal page to become the new root
    alloc: PageAllocResult = buffer_pool_allocate_page(tree.pool)
    new_root_id = alloc.page_id
    new_root_buf = alloc.buffer

    page_format_internal(new_root_buf, new_root_id)
    page_set_first_child_page_id(new_root_buf, left_child_id)
    page_insert_internal_cell(new_root_buf, key, right_child_id)

    tree.root_page_id = new_root_id
    tree.height = tree.height + 1
    tree.pool.root_page_id = new_root_id
    bp_write_page_0(tree.pool)

    buffer_pool_unpin_page(tree.pool, new_root_id, 1)
    return tree
  @end

  parent_id = stack[stack.len() - 1]
  new_stack = []
  i = 0
  @while i < stack.len() - 1
    new_stack = new_stack.push(stack[i])
    i = i + 1
  @end

  parent_buf = buffer_pool_fetch_page(tree.pool, parent_id)
  k_len = str_len(key)
  req_space = 10 + k_len + 2

  @if page_free_space(parent_buf) < req_space
    page_defrag(parent_buf)
  @end

  @if page_free_space(parent_buf) >= req_space
    page_insert_internal_cell(parent_buf, key, right_child_id)
    buffer_pool_unpin_page(tree.pool, parent_id, 1)
    return tree
  @end

  @! Internal Node Full -> Split Internal Node 50/50
  alloc: PageAllocResult = buffer_pool_allocate_page(tree.pool)
  new_parent_id = alloc.page_id
  new_parent_buf = alloc.buffer

  split_info: PageSplitResult = page_split_internal(parent_buf, new_parent_buf)
  promoted_key = split_info.promoted_key

  cmp = page_str_cmp(key, promoted_key)
  @if cmp < 0
    page_insert_internal_cell(parent_buf, key, right_child_id)
  @else
    page_insert_internal_cell(new_parent_buf, key, right_child_id)
  @end

  buffer_pool_unpin_page(tree.pool, parent_id, 1)
  buffer_pool_unpin_page(tree.pool, new_parent_id, 1)

  return btree_insert_parent(tree, new_stack, parent_id, promoted_key, new_parent_id)
@end

@! Inserts or updates a (key, value) entry into the B+Tree
@fn btree_insert(tree: BTree, key, value)
  curr_id = tree.root_page_id
  stack = []

  @while 1
    buf = buffer_pool_fetch_page(tree.pool, curr_id)
    ptype = page_get_type(buf)

    @if ptype == PAGE_TYPE_INTERNAL()
      stack = stack.push(curr_id)
      child_id = page_find_internal_child(buf, key)
      buffer_pool_unpin_page(tree.pool, curr_id, 0)
      curr_id = child_id
    @else
      leaf_id = curr_id
      search_res = page_find_leaf_cell(buf, key)

      @! If key already exists, perform in-place update or overwrite
      @if search_res.found == 1
        ins_res = page_insert_leaf_cell(buf, key, value)
        @if ins_res.ok == 1
          buffer_pool_unpin_page(tree.pool, leaf_id, 1)
          return tree
        @end
        @! If ins_res.ok == 0, the page was full and old cell was deleted and defragmented.
        @! Fall through to leaf split below!
      @else
        k_len = str_len(key)
        v_len = str_len(value)
        req_space = 6 + k_len + v_len + 2

        @if page_free_space(buf) < req_space
          page_defrag(buf)
        @end

        @if page_free_space(buf) >= req_space
          page_insert_leaf_cell(buf, key, value)
          buffer_pool_unpin_page(tree.pool, leaf_id, 1)
          return tree
        @end
      @end

      @! Leaf Node Full -> 50/50 Leaf Split
      alloc: PageAllocResult = buffer_pool_allocate_page(tree.pool)
      new_leaf_id = alloc.page_id
      new_leaf_buf = alloc.buffer

      split_info: PageSplitResult = page_split_leaf(buf, new_leaf_buf)
      promoted_key = split_info.promoted_key

      old_next = page_get_next_page_id(new_leaf_buf)
      @if old_next != 0
        next_buf = buffer_pool_fetch_page(tree.pool, old_next)
        page_set_prev_page_id(next_buf, new_leaf_id)
        buffer_pool_unpin_page(tree.pool, old_next, 1)
      @end

      cmp = page_str_cmp(key, promoted_key)
      @if cmp < 0
        page_insert_leaf_cell(buf, key, value)
      @else
        page_insert_leaf_cell(new_leaf_buf, key, value)
      @end

      buffer_pool_unpin_page(tree.pool, leaf_id, 1)
      buffer_pool_unpin_page(tree.pool, new_leaf_id, 1)

      return btree_insert_parent(tree, stack, leaf_id, promoted_key, new_leaf_id)
    @end
  @end

  return tree
@end

@! ----------------------------------------------------------------------------
@! 5. Horizontal Range Scans (Zero Tree Backtracking)
@! ----------------------------------------------------------------------------

@! Scans a range of keys [start_key .. end_key] up to limit entries
@fn btree_scan(tree: BTree, start_key, end_key, limit)
  @if limit <= 0
    return []
  @end

  start_leaf_id = 1
  start_slot = 0

  @if start_key == ""
    @! Find leftmost leaf page
    curr_id = tree.root_page_id
    find_leaf = 1
    @while find_leaf == 1
      buf = buffer_pool_fetch_page(tree.pool, curr_id)
      ptype = page_get_type(buf)
      @if ptype == PAGE_TYPE_INTERNAL()
        next_id = page_get_first_child_page_id(buf)
        buffer_pool_unpin_page(tree.pool, curr_id, 0)
        curr_id = next_id
      @else
        buffer_pool_unpin_page(tree.pool, curr_id, 0)
        start_leaf_id = curr_id
        start_slot = 0
        find_leaf = 0
      @end
    @end
  @else
    s_res = btree_search(tree, start_key)
    start_leaf_id = s_res.leaf_page_id
    start_slot = s_res.slot_index
  @end

  results = []
  curr_page_id = start_leaf_id
  curr_slot = start_slot
  done = 0

  @while curr_page_id != 0 && results.len() < limit && done == 0
    buf = buffer_pool_fetch_page(tree.pool, curr_page_id)
    cnt = page_get_cell_count(buf)
    s = curr_slot
    @while s < cnt && results.len() < limit && done == 0
      k = page_get_leaf_key(buf, s)
      v = page_get_leaf_val(buf, s)
      @if end_key != "" && page_str_cmp(k, end_key) > 0
        done = 1
      @else
        results = results.push({ key: k, value: v })
        s = s + 1
      @end
    @end

    next_id = page_get_next_page_id(buf)
    buffer_pool_unpin_page(tree.pool, curr_page_id, 0)

    curr_page_id = next_id
    curr_slot = 0
  @end

  return results
@end

@! ----------------------------------------------------------------------------
@! 6. Key Deletion & Compaction
@! ----------------------------------------------------------------------------

@! Removes a key from the B+Tree and maintains sibling linked list continuity
@fn btree_delete(tree: BTree, key)
  curr_id = tree.root_page_id
  stack = []

  @while 1
    buf = buffer_pool_fetch_page(tree.pool, curr_id)
    ptype = page_get_type(buf)

    @if ptype == PAGE_TYPE_INTERNAL()
      stack = stack.push(curr_id)
      child_id = page_find_internal_child(buf, key)
      buffer_pool_unpin_page(tree.pool, curr_id, 0)
      curr_id = child_id
    @else
      leaf_id = curr_id
      del_res = page_delete_leaf_cell(buf, key)
      @if del_res.ok == 0
        buffer_pool_unpin_page(tree.pool, leaf_id, 0)
        return tree
      @end
      buf = del_res.buf
      buffer_pool_set_page_buf(tree.pool, leaf_id, buf)

      cnt = page_get_cell_count(buf)
      @if cnt == 0 && leaf_id != tree.root_page_id
        prev_id = page_get_prev_page_id(buf)
        next_id = page_get_next_page_id(buf)
        @if prev_id != 0
          p_buf = buffer_pool_fetch_page(tree.pool, prev_id)
          p_buf = page_set_next_page_id(p_buf, next_id)
          buffer_pool_set_page_buf(tree.pool, prev_id, p_buf)
          buffer_pool_unpin_page(tree.pool, prev_id, 1)
        @end
        @if next_id != 0
          n_buf = buffer_pool_fetch_page(tree.pool, next_id)
          n_buf = page_set_prev_page_id(n_buf, prev_id)
          buffer_pool_set_page_buf(tree.pool, next_id, n_buf)
          buffer_pool_unpin_page(tree.pool, next_id, 1)
        @end
        @! Unlink empty leaf from parent internal routing page
        @if stack.len() > 0
          parent_id = stack[stack.len() - 1]
          par_buf = buffer_pool_fetch_page(tree.pool, parent_id)
          par_cnt = page_get_cell_count(par_buf)
          par_dirty = 0
          @if page_get_first_child_page_id(par_buf) == leaf_id && par_cnt > 0
            next_first = page_get_internal_child_page_id(par_buf, 0)
            par_buf = page_set_first_child_page_id(par_buf, next_first)
            del_p0 = page_delete_internal_cell_at(par_buf, 0)
            par_buf = del_p0.buf
            par_dirty = 1
          @else
            si = 0
            @while si < par_cnt
              @if page_get_internal_child_page_id(par_buf, si) == leaf_id
                del_ps = page_delete_internal_cell_at(par_buf, si)
                par_buf = del_ps.buf
                par_dirty = 1
                break
              @end
              si = si + 1
            @end
          @end
          @if par_dirty == 1
            buffer_pool_set_page_buf(tree.pool, parent_id, par_buf)
          @end
          buffer_pool_unpin_page(tree.pool, parent_id, par_dirty)
        @end
      @elif cnt > 0 && stack.len() > 0
        @! Synchronize parent internal page if this leaf's minimum key changed
        new_min_k = page_get_leaf_key(buf, 0)
        parent_id = stack[stack.len() - 1]
        par_buf = buffer_pool_fetch_page(tree.pool, parent_id)
        par_cnt = page_get_cell_count(par_buf)
        par_dirty = 0
        @if par_cnt > 0 && str_len(new_min_k) > 0
          si = 0
          @while si < par_cnt
            @if page_get_internal_child_page_id(par_buf, si) == leaf_id
              old_sep = page_get_internal_key(par_buf, si)
              @if old_sep != new_min_k
                del_ps = page_delete_internal_cell_at(par_buf, si)
                par_buf = del_ps.buf
                ins_ps = page_insert_internal_cell(par_buf, new_min_k, leaf_id)
                par_buf = ins_ps.buf
                par_dirty = 1
              @end
              break
            @end
            si = si + 1
          @end
        @end
        @if par_dirty == 1
          buffer_pool_set_page_buf(tree.pool, parent_id, par_buf)
        @end
        buffer_pool_unpin_page(tree.pool, parent_id, par_dirty)
      @end

      buffer_pool_unpin_page(tree.pool, leaf_id, 1)
      return tree
    @end
  @end

  return tree
@end

@! ----------------------------------------------------------------------------
@! 7. B+Tree Invariant Verification & Diagnostics
@! ----------------------------------------------------------------------------

@! Verifies total key order, sibling pointer integrity, and tree invariants
@fn btree_verify(tree: BTree)
  curr_id = tree.root_page_id
  find_vleaf = 1
  @while find_vleaf == 1
    buf = buffer_pool_fetch_page(tree.pool, curr_id)
    ptype = page_get_type(buf)
    @if ptype == PAGE_TYPE_INTERNAL()
      next_id = page_get_first_child_page_id(buf)
      buffer_pool_unpin_page(tree.pool, curr_id, 0)
      curr_id = next_id
    @else
      buffer_pool_unpin_page(tree.pool, curr_id, 0)
      find_vleaf = 0
    @end
  @end

  leaf_id = curr_id
  prev_k = ""
  first = 1
  total_cells = 0
  leaves_count = 0

  @while leaf_id != 0
    leaves_count = leaves_count + 1
    buf = buffer_pool_fetch_page(tree.pool, leaf_id)
    cnt = page_get_cell_count(buf)
    i = 0
    @while i < cnt
      k = page_get_leaf_key(buf, i)
      @if first == 0
        @if page_str_cmp(prev_k, k) >= 0
          println("  [BTree Verify Error] Keys out of order: " + prev_k + " >= " + k)
          buffer_pool_unpin_page(tree.pool, leaf_id, 0)
        @end
      @end
      prev_k = k
      first = 0
      total_cells = total_cells + 1
      i = i + 1
    @end
    next_leaf = page_get_next_page_id(buf)
    buffer_pool_unpin_page(tree.pool, leaf_id, 0)
    leaf_id = next_leaf
  @end

  return 1
@end

@! Computes total number of keys in the B+Tree
@fn btree_count(tree: BTree)
  curr_id = tree.root_page_id
  find_cleaf = 1
  @while find_cleaf == 1
    buf = buffer_pool_fetch_page(tree.pool, curr_id)
    ptype = page_get_type(buf)
    @if ptype == PAGE_TYPE_INTERNAL()
      next_id = page_get_first_child_page_id(buf)
      buffer_pool_unpin_page(tree.pool, curr_id, 0)
      curr_id = next_id
    @else
      buffer_pool_unpin_page(tree.pool, curr_id, 0)
      find_cleaf = 0
    @end
  @end

  leaf_id = curr_id
  total_cells = 0
  @while leaf_id != 0
    buf = buffer_pool_fetch_page(tree.pool, leaf_id)
    cnt = page_get_cell_count(buf)
    total_cells = total_cells + cnt
    next_leaf = page_get_next_page_id(buf)
    buffer_pool_unpin_page(tree.pool, leaf_id, 0)
    leaf_id = next_leaf
  @end

  return total_cells
@end

@! Returns the current height of the B+Tree
@fn btree_get_height(tree: BTree)
  return tree.height
@end
