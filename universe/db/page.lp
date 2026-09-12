@! ============================================================================
@! LIPI UNIVERSE DB — SLOTTED BINARY DATABASE PAGE LAYOUT (universe/db/page.lp)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! Fixed 4096-Byte Page Frame, 32-Byte Header, Lexicographically Sorted Slots,
@! Variable-Length Leaf & Internal Cell Heaps, Zero-Fragmentation Defragmentation
@! ============================================================================

import "universe/core/string"
import "universe/core/collections"
import "universe/os/syscalls"

@fn PAGE_SIZE() return 4096 @end
@fn PAGE_HEADER_SIZE() return 32 @end

@fn PAGE_TYPE_FREE() return 0 @end
@fn PAGE_TYPE_LEAF() return 1 @end
@fn PAGE_TYPE_INTERNAL() return 2 @end

@struct NativeArray
  length: i64
  capacity: i64
  element_size: i64
  data_ptr: i64
@end

@struct PageSearchLeafResult
  found: i64
  index: i64
  offset: i64
  value: string
@end

@struct PageSearchInternalResult
  found: i64
  index: i64
  offset: i64
  child_page_id: i64
@end

@struct PageLeafCell
  key: string
  value: string
  cell_size: i64
  k_len: i64
  v_len: i64
@end

@struct PageOpResult
  ok: i64
  buf: array
@end

@struct PageInsertResult
  ok: i64
  offset: i64
  buf: array
@end

@fn page_new()
  arr = []
  i = 0
  @while i < 4096
    arr = arr.push(0)
    i = i + 1
  @end
  return arr
@end

@fn page_data_ptr(buf)
  // WHY: Safely serializes 4096-element page array to contiguous raw byte buffer for native syscalls
  raw_mem = alloc(4096)
  i = 0
  @while i < 4096
    sys_poke8(raw_mem + i, buf[i] & 255)
    i = i + 1
  @end
  return raw_mem
@end

@fn page_write_to_fd(fd, buf)
  // WHY: Writes 4096-element page array to file descriptor via contiguous serialized buffer
  ptr = page_data_ptr(buf)
  return sys_write(fd, ptr, 4096)
@end

@fn page_read_from_fd(fd, buf)
  // WHY: Reads 4096 bytes from file descriptor directly into 4096-element page array
  raw_mem = alloc(4096)
  n = sys_read(fd, raw_mem, 4096)
  @if n < 4096 return n @end
  i = 0
  @while i < 4096
    val = sys_peek8(raw_mem + i) & 255
    buf = list_set(buf, i, val)
    i = i + 1
  @end
  return n
@end

@fn page_read_u8(buf, offset)
  return buf[offset] & 255
@end

@fn page_write_u8(buf, offset, val)
  v0 = val & 255
  return list_set(buf, offset, v0)
@end

@fn page_read_u16(buf, offset)
  b0 = buf[offset] & 255
  b1 = buf[offset + 1] & 255
  t1 = b1 * 256
  res = b0 | t1
  return res & 65535
@end

@fn page_write_u16(buf, offset, val)
  b0 = val & 255
  b1 = (val / 256) & 255
  buf = list_set(buf, offset, b0)
  buf = list_set(buf, offset + 1, b1)
  return buf
@end

@fn page_read_u32(buf, offset)
  b0 = buf[offset] & 255
  b1 = buf[offset + 1] & 255
  b2 = buf[offset + 2] & 255
  b3 = buf[offset + 3] & 255
  w0 = b0
  w1 = b1 * 256
  w2 = b2 * 65536
  w3 = b3 * 16777216
  r01 = w0 | w1
  r23 = w2 | w3
  res = r01 | r23
  return res & 4294967295
@end

@fn page_write_u32(buf, offset, val)
  b0 = val & 255
  b1 = (val / 256) & 255
  b2 = (val / 65536) & 255
  b3 = (val / 16777216) & 255
  buf = list_set(buf, offset, b0)
  buf = list_set(buf, offset + 1, b1)
  buf = list_set(buf, offset + 2, b2)
  buf = list_set(buf, offset + 3, b3)
  return buf
@end

@fn page_read_u64(buf, offset)
  low = page_read_u32(buf, offset)
  high = page_read_u32(buf, offset + 4)
  t_hi = high * 4294967296
  return t_hi + low
@end

@fn page_write_u64(buf, offset, val)
  low = val & 4294967295
  high = (val / 4294967296) & 4294967295
  buf = page_write_u32(buf, offset, low)
  buf = page_write_u32(buf, offset + 4, high)
  return buf
@end

@fn page_write_str(buf, offset, s)
  num_items = str_len(s)
  i = 0
  @while i < num_items
    ch = str_char_at(s, i) & 255
    buf = list_set(buf, offset + i, ch)
    i = i + 1
  @end
  return buf
@end

@fn page_read_str(buf, offset, num_items)
  res = ""
  i = 0
  @while i < num_items
    ch = buf[offset + i] & 255
    res = string_concat(res, str_from_char_code(ch))
    i = i + 1
  @end
  return res
@end

@fn page_write_bytes(buf, offset, s)
  return page_write_str(buf, offset, s)
@end

@fn page_read_bytes(buf, offset, num_items)
  return page_read_str(buf, offset, num_items)
@end

@fn page_str_cmp(a, b)
  len_a = str_len(a)
  len_b = str_len(b)
  min_len = len_a
  @if len_b < min_len
    min_len = len_b
  @end

  i = 0
  @while i < min_len
    ca = str_char_at(a, i) & 255
    cb = str_char_at(b, i) & 255
    @if ca < cb
      return -1
    @elif ca > cb
      return 1
    @end
    i = i + 1
  @end

  @if len_a < len_b
    return -1
  @elif len_a > len_b
    return 1
  @end
  return 0
@end

@fn page_get_id(buf) return page_read_u64(buf, 0) @end
@fn page_set_id(buf, id) return page_write_u64(buf, 0, id) @end

@fn page_get_type(buf) return page_read_u16(buf, 8) @end
@fn page_set_type(buf, t) return page_write_u16(buf, 8, t) @end

@fn page_get_cell_count(buf) return page_read_u16(buf, 10) @end
@fn page_set_cell_count(buf, cnt) return page_write_u16(buf, 10, cnt) @end

@fn page_get_free_lower(buf) return page_read_u16(buf, 12) @end
@fn page_set_free_lower(buf, offset) return page_write_u16(buf, 12, offset) @end

@fn page_get_free_upper(buf) return page_read_u16(buf, 14) @end
@fn page_set_free_upper(buf, offset) return page_write_u16(buf, 14, offset) @end

@fn page_get_next_page_id(buf) return page_read_u64(buf, 16) @end
@fn page_set_next_page_id(buf, id) return page_write_u64(buf, 16, id) @end

@fn page_get_prev_page_id(buf) return page_read_u64(buf, 24) @end
@fn page_set_prev_page_id(buf, id) return page_write_u64(buf, 24, id) @end

@fn page_get_first_child_page_id(buf) return page_read_u64(buf, 16) @end
@fn page_set_first_child_page_id(buf, id) return page_write_u64(buf, 16, id) @end

@fn page_get_slot(buf, idx) return page_read_u16(buf, 32 + (idx * 2)) @end
@fn page_set_slot(buf, idx, off) return page_write_u16(buf, 32 + (idx * 2), off) @end

@fn page_free_space(buf)
  lower = page_get_free_lower(buf)
  upper = page_get_free_upper(buf)
  @if upper < lower return 0 @end
  return upper - lower
@end

@fn page_format_leaf(buf, page_id, prev_page_id, next_page_id)
  buf = page_set_id(buf, page_id)
  buf = page_set_type(buf, PAGE_TYPE_LEAF())
  buf = page_set_cell_count(buf, 0)
  buf = page_set_free_lower(buf, 32)
  buf = page_set_free_upper(buf, 4096)
  buf = page_set_next_page_id(buf, next_page_id)
  buf = page_set_prev_page_id(buf, prev_page_id)
  return buf
@end

@fn page_format_internal(buf, page_id)
  buf = page_set_id(buf, page_id)
  buf = page_set_type(buf, PAGE_TYPE_INTERNAL())
  buf = page_set_cell_count(buf, 0)
  buf = page_set_free_lower(buf, 32)
  buf = page_set_free_upper(buf, 4096)
  buf = page_set_first_child_page_id(buf, 0)
  buf = page_set_prev_page_id(buf, 0)
  return buf
@end

@fn page_read_leaf_cell(buf, offset)
  k_len = page_read_u16(buf, offset)
  v_len = page_read_u32(buf, offset + 2)
  k = page_read_str(buf, offset + 6, k_len)
  v = page_read_str(buf, offset + 6 + k_len, v_len)
  return {
    key: k,
    value: v,
    cell_size: 6 + k_len + v_len,
    k_len: k_len,
    v_len: v_len
  }
@end

@fn page_read_internal_cell(buf, offset)
  child_id = page_read_u64(buf, offset)
  k_len = page_read_u16(buf, offset + 8)
  k = page_read_str(buf, offset + 10, k_len)
  return {
    child_page_id: child_id,
    key: k,
    cell_size: 10 + k_len,
    k_len: k_len
  }
@end

@fn page_get_leaf_key(buf, slot_idx)
  off = page_get_slot(buf, slot_idx)
  k_len = page_read_u16(buf, off)
  return page_read_str(buf, off + 6, k_len)
@end

@fn page_get_leaf_val(buf, slot_idx)
  off = page_get_slot(buf, slot_idx)
  k_len = page_read_u16(buf, off)
  v_len = page_read_u32(buf, off + 2)
  return page_read_str(buf, off + 6 + k_len, v_len)
@end

@fn page_get_internal_key(buf, slot_idx)
  off = page_get_slot(buf, slot_idx)
  k_len = page_read_u16(buf, off + 8)
  return page_read_str(buf, off + 10, k_len)
@end

@fn page_get_internal_child_page_id(buf, slot_idx)
  off = page_get_slot(buf, slot_idx)
  return page_read_u64(buf, off)
@end

@fn page_binary_search_leaf(buf, key)
  // WHY: Direct binary search on slot array reading keys directly from buffer avoiding intermediate map allocations
  cnt = page_get_cell_count(buf)
  low = 0
  high = cnt - 1
  @while low <= high
    mid = (low + high) / 2
    offset = page_get_slot(buf, mid)
    k = page_get_leaf_key(buf, mid)
    cmp = page_str_cmp(key, k)
    @if cmp == 0
      val = page_get_leaf_val(buf, mid)
      return { found: 1, index: mid, offset: offset, value: val }
    @elif cmp > 0
      low = mid + 1
    @else
      high = mid - 1
    @end
  @end
  return { found: 0, index: low, offset: 0, value: "" }
@end

@fn page_find_leaf_cell(buf, key)
  return page_binary_search_leaf(buf, key)
@end

@fn page_binary_search_internal(buf, key)
  // WHY: Direct binary search on internal routing node reading keys and child page IDs directly
  cnt = page_get_cell_count(buf)
  low = 0
  high = cnt - 1
  @while low <= high
    mid = (low + high) / 2
    offset = page_get_slot(buf, mid)
    k = page_get_internal_key(buf, mid)
    cmp = page_str_cmp(key, k)
    @if cmp == 0
      child_id = page_get_internal_child_page_id(buf, mid)
      return { found: 1, index: mid, offset: offset, child_page_id: child_id }
    @elif cmp > 0
      low = mid + 1
    @else
      high = mid - 1
    @end
  @end
  return { found: 0, index: low, offset: 0, child_page_id: 0 }
@end

@fn page_find_internal_child(buf, key)
  // WHY: Finds routing child page pointer directly via internal keys without object allocation
  cnt = page_get_cell_count(buf)
  @if cnt == 0
    return page_get_first_child_page_id(buf)
  @end

  k0 = page_get_internal_key(buf, 0)
  @if page_str_cmp(key, k0) < 0
    return page_get_first_child_page_id(buf)
  @end

  low = 0
  high = cnt - 1
  best_idx = 0
  @while low <= high
    mid = (low + high) / 2
    k = page_get_internal_key(buf, mid)
    cmp = page_str_cmp(key, k)
    @if cmp >= 0
      best_idx = mid
      low = mid + 1
    @else
      high = mid - 1
    @end
  @end

  return page_get_internal_child_page_id(buf, best_idx)
@end

@fn page_defrag(buf)
  cnt = page_get_cell_count(buf)
  ptype = page_get_type(buf)
  @if cnt == 0
    buf = page_set_free_lower(buf, 32)
    buf = page_set_free_upper(buf, 4096)
    return { ok: 1, buf: buf }
  @end

  @if ptype == PAGE_TYPE_LEAF()
    keys = []
    vals = []
    i = 0
    @while i < cnt
      k = page_get_leaf_key(buf, i)
      v = page_get_leaf_val(buf, i)
      keys = keys.push(k)
      vals = vals.push(v)
      i = i + 1
    @end

    curr_upper = 4096
    i = 0
    @while i < cnt
      k = keys[i]
      v = vals[i]
      k_len = str_len(k)
      v_len = str_len(v)
      c_size = 6 + k_len + v_len
      curr_upper = curr_upper - c_size
      buf = page_write_u16(buf, curr_upper, k_len)
      buf = page_write_u32(buf, curr_upper + 2, v_len)
      buf = page_write_str(buf, curr_upper + 6, k)
      buf = page_write_str(buf, curr_upper + 6 + k_len, v)
      buf = page_set_slot(buf, i, curr_upper)
      i = i + 1
    @end
    buf = page_set_free_lower(buf, 32 + (cnt * 2))
    buf = page_set_free_upper(buf, curr_upper)
  @else
    keys = []
    children = []
    i = 0
    @while i < cnt
      k = page_get_internal_key(buf, i)
      ch_id = page_get_internal_child_page_id(buf, i)
      keys = keys.push(k)
      children = children.push(ch_id)
      i = i + 1
    @end

    curr_upper = 4096
    i = 0
    @while i < cnt
      k = keys[i]
      ch_id = children[i]
      k_len = str_len(k)
      c_size = 10 + k_len
      curr_upper = curr_upper - c_size
      buf = page_write_u64(buf, curr_upper, ch_id)
      buf = page_write_u16(buf, curr_upper + 8, k_len)
      buf = page_write_str(buf, curr_upper + 10, k)
      buf = page_set_slot(buf, i, curr_upper)
      i = i + 1
    @end
    buf = page_set_free_lower(buf, 32 + (cnt * 2))
    buf = page_set_free_upper(buf, curr_upper)
  @end
  return { ok: 1, buf: buf }
@end

@fn page_defragment(buf)
  return page_defrag(buf)
@end

@fn page_insert_leaf_cell(buf, key, value)
  k_len = str_len(key)
  v_len = str_len(value)
  cell_size = 6 + k_len + v_len
  req_space = cell_size + 2

  search_res: PageSearchLeafResult = page_binary_search_leaf(buf, key)
  cnt = page_get_cell_count(buf)

  @if search_res.found == 1
    old_offset = search_res.offset
    old_vlen = page_read_u32(buf, old_offset + 2)
    @if old_vlen == v_len
      buf = page_write_str(buf, old_offset + 6 + k_len, value)
      return { ok: 1, offset: old_offset, buf: buf }
    @else
      del_res: PageOpResult = page_delete_leaf_cell(buf, key)
      buf = del_res.buf
      df_res: PageOpResult = page_defrag(buf)
      buf = df_res.buf
      avail = page_free_space(buf)
      @if avail < req_space
        return { ok: 0, offset: 0, buf: buf }
      @end
      return page_insert_leaf_cell(buf, key, value)
    @end
  @end

  avail = page_free_space(buf)
  @if avail < req_space
    df_res2: PageOpResult = page_defrag(buf)
    buf = df_res2.buf
    avail = page_free_space(buf)
    @if avail < req_space
      return { ok: 0, offset: 0, buf: buf }
    @end
  @end

  ins_idx = search_res.index
  upper = page_get_free_upper(buf)
  new_upper = upper - cell_size

  buf = page_write_u16(buf, new_upper, k_len)
  buf = page_write_u32(buf, new_upper + 2, v_len)
  buf = page_write_str(buf, new_upper + 6, key)
  buf = page_write_str(buf, new_upper + 6 + k_len, value)

  i = cnt
  @while i > ins_idx
    old_slot = page_get_slot(buf, i - 1)
    buf = page_set_slot(buf, i, old_slot)
    i = i - 1
  @end

  buf = page_set_slot(buf, ins_idx, new_upper)
  buf = page_set_cell_count(buf, cnt + 1)
  buf = page_set_free_lower(buf, 32 + ((cnt + 1) * 2))
  buf = page_set_free_upper(buf, new_upper)

  return { ok: 1, offset: new_upper, buf: buf }
@end

@fn page_delete_leaf_cell(buf, key)
  search_res = page_binary_search_leaf(buf, key)
  @if search_res.found == 0 return { ok: 0, buf: buf } @end

  del_idx = search_res.index
  cnt = page_get_cell_count(buf)

  i = del_idx
  @while i < cnt - 1
    next_slot = page_get_slot(buf, i + 1)
    buf = page_set_slot(buf, i, next_slot)
    i = i + 1
  @end

  buf = page_set_cell_count(buf, cnt - 1)
  buf = page_set_free_lower(buf, 32 + ((cnt - 1) * 2))
  return { ok: 1, buf: buf }
@end

@fn page_delete_leaf_cell_at(buf, slot_idx)
  cnt = page_get_cell_count(buf)
  @if slot_idx < 0 || slot_idx >= cnt return { ok: 0, buf: buf } @end

  i = slot_idx
  @while i < cnt - 1
    next_slot = page_get_slot(buf, i + 1)
    buf = page_set_slot(buf, i, next_slot)
    i = i + 1
  @end

  buf = page_set_cell_count(buf, cnt - 1)
  buf = page_set_free_lower(buf, 32 + ((cnt - 1) * 2))
  return { ok: 1, buf: buf }
@end

@fn page_insert_internal_cell(buf, key, child_page_id)
  k_len = str_len(key)
  cell_size = 10 + k_len
  req_space = cell_size + 2

  avail = page_free_space(buf)
  @if avail < req_space
    df_res = page_defrag(buf)
    buf = df_res.buf
    avail = page_free_space(buf)
    @if avail < req_space
      return { ok: 0, offset: 0, buf: buf }
    @end
  @end

  search_res = page_binary_search_internal(buf, key)
  cnt = page_get_cell_count(buf)
  ins_idx = search_res.index

  upper = page_get_free_upper(buf)
  new_upper = upper - cell_size

  buf = page_write_u64(buf, new_upper, child_page_id)
  buf = page_write_u16(buf, new_upper + 8, k_len)
  buf = page_write_str(buf, new_upper + 10, key)

  i = cnt
  @while i > ins_idx
    old_slot = page_get_slot(buf, i - 1)
    buf = page_set_slot(buf, i, old_slot)
    i = i - 1
  @end

  buf = page_set_slot(buf, ins_idx, new_upper)
  buf = page_set_cell_count(buf, cnt + 1)
  buf = page_set_free_lower(buf, 32 + ((cnt + 1) * 2))
  buf = page_set_free_upper(buf, new_upper)

  return { ok: 1, offset: new_upper, buf: buf }
@end

@fn page_delete_internal_cell(buf, key)
  search_res = page_binary_search_internal(buf, key)
  @if search_res.found == 0 return { ok: 0, buf: buf } @end

  del_idx = search_res.index
  cnt = page_get_cell_count(buf)

  i = del_idx
  @while i < cnt - 1
    next_slot = page_get_slot(buf, i + 1)
    buf = page_set_slot(buf, i, next_slot)
    i = i + 1
  @end

  buf = page_set_cell_count(buf, cnt - 1)
  buf = page_set_free_lower(buf, 32 + ((cnt - 1) * 2))
  return { ok: 1, buf: buf }
@end

@fn page_delete_internal_cell_at(buf, slot_idx)
  cnt = page_get_cell_count(buf)
  @if slot_idx < 0 || slot_idx >= cnt return { ok: 0, buf: buf } @end

  i = slot_idx
  @while i < cnt - 1
    next_slot = page_get_slot(buf, i + 1)
    buf = page_set_slot(buf, i, next_slot)
    i = i + 1
  @end

  buf = page_set_cell_count(buf, cnt - 1)
  buf = page_set_free_lower(buf, 32 + ((cnt - 1) * 2))
  return { ok: 1, buf: buf }
@end

@fn page_split_leaf(src_buf, dst_buf)
  cnt = page_get_cell_count(src_buf)
  split_idx = cnt / 2

  split_offset = page_get_slot(src_buf, split_idx)
  split_cell = page_read_leaf_cell(src_buf, split_offset)
  promoted_key = split_cell.key

  dst_id = page_get_id(dst_buf)
  src_id = page_get_id(src_buf)
  old_next = page_get_next_page_id(src_buf)

  dst_buf = page_format_leaf(dst_buf, dst_id, src_id, old_next)
  src_buf = page_set_next_page_id(src_buf, dst_id)

  move_keys = []
  move_vals = []
  i = split_idx
  @while i < cnt
    off = page_get_slot(src_buf, i)
    c = page_read_leaf_cell(src_buf, off)
    move_keys = move_keys.push(c.key)
    move_vals = move_vals.push(c.value)
    i = i + 1
  @end

  i = 0
  @while i < move_keys.len()
    ins_res = page_insert_leaf_cell(dst_buf, move_keys[i], move_vals[i])
    dst_buf = ins_res.buf
    i = i + 1
  @end

  src_buf = page_set_cell_count(src_buf, split_idx)
  src_buf = page_set_free_lower(src_buf, 32 + (split_idx * 2))
  df_res = page_defrag(src_buf)
  src_buf = df_res.buf

  return {
    promoted_key: promoted_key,
    split_page_id: dst_id,
    src_buf: src_buf,
    dst_buf: dst_buf
  }
@end

@fn page_split_internal(src_buf, dst_buf)
  cnt = page_get_cell_count(src_buf)
  split_idx = cnt / 2

  split_offset = page_get_slot(src_buf, split_idx)
  split_cell = page_read_internal_cell(src_buf, split_offset)
  promoted_key = split_cell.key

  dst_id = page_get_id(dst_buf)
  dst_buf = page_format_internal(dst_buf, dst_id)

  dst_buf = page_set_first_child_page_id(dst_buf, split_cell.child_page_id)

  move_keys = []
  move_children = []
  i = split_idx + 1
  @while i < cnt
    off = page_get_slot(src_buf, i)
    c = page_read_internal_cell(src_buf, off)
    move_keys = move_keys.push(c.key)
    move_children = move_children.push(c.child_page_id)
    i = i + 1
  @end

  i = 0
  @while i < move_keys.len()
    ins_res = page_insert_internal_cell(dst_buf, move_keys[i], move_children[i])
    dst_buf = ins_res.buf
    i = i + 1
  @end

  src_buf = page_set_cell_count(src_buf, split_idx)
  src_buf = page_set_free_lower(src_buf, 32 + (split_idx * 2))
  df_res = page_defrag(src_buf)
  src_buf = df_res.buf

  return {
    promoted_key: promoted_key,
    split_page_id: dst_id,
    src_buf: src_buf,
    dst_buf: dst_buf
  }
@end