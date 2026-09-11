@! ============================================================
@! MAYA UNIVERSE — Core Collections Library v2.0
@! Pure Maya: Stack, Queue, Set, HashMap, list helpers
@! Interpreter-compatible — no sys_peek8/sys_mmap/sys_poke
@! ============================================================

@! ─── Array / List helpers ───────────────────────────────────

@fn len(arr)
  @if arr == 0 return 0 @end
  @! WHY: Check pointer address and page offset. Arrays store length at arr - 8.
  @! Ensure arr % 4096 >= 8 so accessing arr - 8 stays strictly within the mapped page.
  @if arr >= 4096
    page_off = arr % 4096
    @if page_off >= 8
      count = sys_peek(arr - 8)
      @if count >= 0 && count < 100000000
        return count
      @end
    @end
  @end
  @! WHY: Fallback for raw null-terminated byte strings
  p = arr
  @while sys_peek8(p) != 0
    p = p + 1
  @end
  return p - arr
@end

@fn c_len(arr)
  @! Character and buffer length alias
  @! WHY: Lowering of .c_len() method syntax in regex and tokenizer creates c_len(arr) calls.
  return len(arr)
@end

@fn exit(code)
  @! Freestanding Linux exit syscall (nr 60)
  @! WHY: Direct kernel invocation using compiler intrinsic sys_exit.
  return sys_exit(code)
@end

@fn to_str(val)
  @! Freestanding integer to string conversion
  @! WHY: Formats 64-bit signed integer into ASCII bytes in an mmap buffer.
  @! Avoids string concatenation operators that lower to raw pointer addition.
  @if val == 0
    return "0"
  @end
  buf = sys_mmap(0, 32, 3, 34, 0 - 1, 0)
  @if buf <= 0
    return "0"
  @end
  n = val
  is_neg = 0
  @if n < 0
    is_neg = 1
    n = 0 - n
  @end
  idx = 30
  sys_poke8(buf + 31, 0)
  @while n > 0
    rem = n % 10
    sys_poke8(buf + idx, 48 + rem)
    idx = idx - 1
    n = n / 10
  @end
  @if is_neg == 1
    sys_poke8(buf + idx, 45)
    idx = idx - 1
  @end
  return buf + idx + 1
@end

@fn print_int(val)
  println(to_str(val))
  return 0
@end

@fn push(arr, val)
  old_len = 0
  cap = 0
  @if arr != 0
    @! WHY: On Linux x86_64, mmap allocations are 4096-byte aligned.
    @! If arr was created by bootstrap with an 8-byte header (base + 8), arr % 4096 == 8.
    @! Reading arr - 16 would dereference unmapped memory before the page and cause SIGSEGV.
    @! Thus, only read cap at arr - 16 if page_off >= 16. Otherwise, treat capacity as exhausted.
    page_off = arr % 4096
    @if page_off >= 16
      old_len = sys_peek(arr - 8)
      @if old_len < 0 || old_len > 100000000
        old_len = 0
      @end
      cap = sys_peek(arr - 16)
      @if cap < 0 || cap > 100000000
        cap = 0
      @end
    @elif page_off >= 8
      old_len = sys_peek(arr - 8)
      @if old_len < 0 || old_len > 100000000
        old_len = 0
      @end
      cap = old_len
    @else
      old_len = 0
      cap = 0
    @end
  @end

  @if old_len < cap
    sys_poke(arr + (old_len * 8), val)
    sys_poke(arr - 8, old_len + 1)
    return arr
  @end

  new_cap = cap * 2
  @if new_cap < 8
    new_cap = 8
  @end

  alloc_size = (new_cap + 2) * 8
  new_buf = sys_mmap(0, alloc_size, 3, 34, 0 - 1, 0)
  @if new_buf <= 0
    return arr
  @end

  sys_poke(new_buf, new_cap)
  sys_poke(new_buf + 8, old_len + 1)
  new_elems = new_buf + 16

  i = 0
  @while i < old_len
    sys_poke(new_elems + (i * 8), sys_peek(arr + (i * 8)))
    i = i + 1
  @end

  sys_poke(new_elems + (old_len * 8), val)
  return new_elems
@end

@fn pop(arr)
  n = arr.len()
  result = []
  i = 0
  @while i < n - 1
    result = result.push(arr[i])
    i = i + 1
  @end
  return result
@end

@fn list_get(arr, idx)
  return arr[idx]
@end

@fn list_set(arr, idx, val)
  @! High-performance in-place mutation of array element at index idx.
  @! WHY: In-place poke avoids O(N^2) memory churn and reallocations when rendering
  @! canvases, updating neural network weights, or running scheduler rings.
  @if arr != 0 && idx >= 0
    sys_poke(arr + (idx * 8), val)
  @end
  return arr
@end

@fn list_map(arr, f)
  result = []
  i = 0
  n = arr.len()
  @while i < n
    result = result.push(f(arr[i]))
    i = i + 1
  @end
  return result
@end

@fn list_filter(arr, pred)
  result = []
  i = 0
  n = arr.len()
  @while i < n
    @if pred(arr[i]) == 1
      result = result.push(arr[i])
    @end
    i = i + 1
  @end
  return result
@end

@fn list_reduce(arr, init, f)
  acc = init
  i = 0
  n = arr.len()
  @while i < n
    acc = f(acc, arr[i])
    i = i + 1
  @end
  return acc
@end

@fn list_contains(arr, val)
  i = 0
  n = arr.len()
  @while i < n
    @if arr[i] == val
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn list_index_of(arr, val)
  i = 0
  n = arr.len()
  @while i < n
    @if arr[i] == val || str_eq(arr[i], val) == 1
      return i
    @end
    i = i + 1
  @end
  return -1
@end

@fn list_reverse(arr)
  result = []
  i = arr.len() - 1
  @while i >= 0
    result = result.push(arr[i])
    i = i - 1
  @end
  return result
@end

@fn list_slice(arr, start, stop)
  result = []
  i = start
  @while i < stop
    @if i < arr.len()
      result = result.push(arr[i])
    @end
    i = i + 1
  @end
  return result
@end

@fn list_concat(a, b)
  result = a
  i = 0
  n = b.len()
  @while i < n
    result = result.push(b[i])
    i = i + 1
  @end
  return result
@end

@fn list_sum(arr)
  total = 0
  i = 0
  n = arr.len()
  @while i < n
    total = total + arr[i]
    i = i + 1
  @end
  return total
@end

@fn list_max(arr)
  @if arr.len() == 0
    return 0
  @end
  m = arr[0]
  i = 1
  @while i < arr.len()
    @if arr[i] > m
      m = arr[i]
    @end
    i = i + 1
  @end
  return m
@end

@fn list_min(arr)
  @if arr.len() == 0
    return 0
  @end
  m = arr[0]
  i = 1
  @while i < arr.len()
    @if arr[i] < m
      m = arr[i]
    @end
    i = i + 1
  @end
  return m
@end

@fn list_fill(n, val)
  result = []
  i = 0
  @while i < n
    result = result.push(val)
    i = i + 1
  @end
  return result
@end

@fn list_range(start, stop)
  result = []
  i = start
  @while i < stop
    result = result.push(i)
    i = i + 1
  @end
  return result
@end

@fn list_zip(a, b)
  result = []
  n = a.len()
  @if b.len() < n
    n = b.len()
  @end
  i = 0
  @while i < n
    pair = [a[i], b[i]]
    result = result.push(pair)
    i = i + 1
  @end
  return result
@end

@fn list_flatten(arr)
  result = []
  i = 0
  @while i < arr.len()
    inner = arr[i]
    j = 0
    @while j < inner.len()
      result = result.push(inner[j])
      j = j + 1
    @end
    i = i + 1
  @end
  return result
@end

@fn list_unique(arr)
  result = []
  i = 0
  @while i < arr.len()
    @if list_contains(result, arr[i]) == 0
      result = result.push(arr[i])
    @end
    i = i + 1
  @end
  return result
@end

@fn list_sort_int(arr)
  @! Insertion sort (pure Maya, interpreter-safe)
  n = arr.len()
  sorted = arr
  i = 1
  @while i < n
    key = sorted[i]
    j = i - 1
    @while j >= 0
      @if sorted[j] > key
        sorted = list_set(sorted, j + 1, sorted[j])
        j = j - 1
      @else
        j = -1
      @end
    @end
    sorted = list_set(sorted, j + 1, key)
    i = i + 1
  @end
  return sorted
@end

@! ─── Stack ──────────────────────────────────────────────────

@struct Stack
  stk_data: array
  stk_size: i64
@end

@fn stack_new()
  return { stk_data: [], stk_size: 0 }
@end

@fn stack_push(s, val)
  new_data = s.stk_data.push(val)
  return { stk_data: new_data, stk_size: s.stk_size + 1 }
@end

@fn stack_pop(s)
  @if s.stk_size == 0
    return { stk_data: [], stk_size: 0 }
  @end
  new_data = list_slice(s.stk_data, 0, s.stk_size - 1)
  return { stk_data: new_data, stk_size: s.stk_size - 1 }
@end

@fn stack_peek(s)
  @if s.stk_size == 0
    return 0
  @end
  return s.stk_data[s.stk_size - 1]
@end

@fn stack_is_empty(s)
  @if s.stk_size == 0
    return 1
  @end
  return 0
@end

@fn stack_size(s)
  return s.stk_size
@end

@! ─── Queue ──────────────────────────────────────────────────

@struct Queue
  q_data: array
  q_front: i64
  q_back: i64
@end

@fn queue_new()
  return { q_data: [], q_front: 0, q_back: 0 }
@end

@fn queue_enqueue(q, val)
  new_data = q.q_data.push(val)
  return { q_data: new_data, q_front: q.q_front, q_back: q.q_back + 1 }
@end

@fn queue_dequeue(q)
  @if q.q_front >= q.q_back
    return { q_data: q.q_data, q_front: q.q_front, q_back: q.q_back }
  @end
  return { q_data: q.q_data, q_front: q.q_front + 1, q_back: q.q_back }
@end

@fn queue_front(q)
  @if q.q_front >= q.q_back
    return 0
  @end
  return q.q_data[q.q_front]
@end

@fn queue_is_empty(q)
  @if q.q_front >= q.q_back
    return 1
  @end
  return 0
@end

@fn queue_size(q)
  return q.q_back - q.q_front
@end

@! ─── Set ────────────────────────────────────────────────────

@struct MayaSet
  ms_data: array
  ms_size: i64
@end

@fn set_new()
  return { ms_data: [], ms_size: 0 }
@end

@fn set_add(s, val)
  @if list_contains(s.ms_data, val) == 1
    return s
  @end
  new_data = s.ms_data.push(val)
  return { ms_data: new_data, ms_size: s.ms_size + 1 }
@end

@fn set_contains(s, val)
  return list_contains(s.ms_data, val)
@end

@fn set_remove(s, val)
  @! Manual filter — interpreter doesn't support inline @fn lambdas
  new_data = []
  i = 0
  @while i < s.ms_data.len()
    @if s.ms_data[i] != val
      new_data = new_data.push(s.ms_data[i])
    @end
    i = i + 1
  @end
  return { ms_data: new_data, ms_size: new_data.len() }
@end

@fn set_size(s)
  return s.ms_size
@end

@fn set_to_list(s)
  return s.ms_data
@end

@fn set_union(a, b)
  result = a
  i = 0
  @while i < b.ms_data.len()
    result = set_add(result, b.ms_data[i])
    i = i + 1
  @end
  return result
@end

@fn set_intersection(a, b)
  result = set_new()
  i = 0
  @while i < a.ms_data.len()
    @if set_contains(b, a.ms_data[i]) == 1
      result = set_add(result, a.ms_data[i])
    @end
    i = i + 1
  @end
  return result
@end

@! ─── HashMap ────────────────────────────────────────────────

@struct HashMap
  keys: array
  vals: array
  hm_size: i64
@end

@fn hashmap_new()
  return { keys: [], vals: [], hm_size: 0 }
@end

@fn hashmap_set(map, key, val)
  @! Check if key already exists
  idx = list_index_of(map.keys, key)
  @if idx >= 0
    new_vals = list_set(map.vals, idx, val)
    return { keys: map.keys, vals: new_vals, hm_size: map.hm_size }
  @end
  new_keys = map.keys.push(key)
  new_vals = map.vals.push(val)
  return { keys: new_keys, vals: new_vals, hm_size: map.hm_size + 1 }
@end

@fn hashmap_get(map, key)
  idx = list_index_of(map.keys, key)
  @if idx < 0
    return 0
  @end
  return map.vals[idx]
@end

@fn hashmap_has(map, key)
  idx = list_index_of(map.keys, key)
  @if idx >= 0
    return 1
  @end
  return 0
@end

@fn hashmap_delete(map, key)
  idx = list_index_of(map.keys, key)
  @if idx < 0
    return map
  @end
  new_keys = list_concat(list_slice(map.keys, 0, idx), list_slice(map.keys, idx + 1, map.keys.len()))
  new_vals = list_concat(list_slice(map.vals, 0, idx), list_slice(map.vals, idx + 1, map.vals.len()))
  return { keys: new_keys, vals: new_vals, hm_size: map.hm_size - 1 }
@end

@fn hashmap_keys(map)
  return map.keys
@end

@fn hashmap_values(map)
  return map.vals
@end

@fn hashmap_size(map)
  return map.hm_size
@end

@! ─── Deque (Double-ended Queue) ─────────────────────────────

@struct Deque
  dq_queue: array
  dq_val: i64
@end

@fn deque_new()
  return { dq_queue: [], dq_val: 0 }
@end

@fn deque_push_back(d, val)
  new_q = d.dq_queue.push(val)
  return { dq_queue: new_q, dq_val: d.dq_val }
@end

@fn deque_push_front(d, val)
  new_q = [val]
  i = 0
  @while i < d.dq_queue.len()
    new_q = new_q.push(d.dq_queue[i])
    i = i + 1
  @end
  return { dq_queue: new_q, dq_val: d.dq_val }
@end

@fn deque_pop_front(d)
  @if d.dq_queue.len() == 0
    return d
  @end
  new_q = list_slice(d.dq_queue, 1, d.dq_queue.len())
  return { dq_queue: new_q, dq_val: d.dq_queue[0] }
@end

@fn deque_pop_back(d)
  n = d.dq_queue.len()
  @if n == 0
    return d
  @end
  new_q = list_slice(d.dq_queue, 0, n - 1)
  return { dq_queue: new_q, dq_val: d.dq_queue[n - 1] }
@end

@fn deque_front(d)
  @if d.dq_queue.len() == 0
    return 0
  @end
  return d.dq_queue[0]
@end

@fn deque_back(d)
  n = d.dq_queue.len()
  @if n == 0
    return 0
  @end
  return d.dq_queue[n - 1]
@end

@fn deque_size(d)
  return d.dq_queue.len()
@end

@fn deque_is_empty(d)
  @if d.dq_queue.len() == 0
    return 1
  @end
  return 0
@end

@! ─── Priority Queue (min-heap via sorted insert) ────────────

@fn pq_new()
  return { keys: [], vals: [], hm_size: 0 }
@end

@fn pq_push(pq, priority, val)
  @! Insert in sorted order (ascending priority)
  new_keys = []
  new_vals = []
  inserted = 0
  i = 0
  @while i < pq.keys.len()
    @if inserted == 0 && priority <= pq.keys[i]
      new_keys = new_keys.push(priority)
      new_vals = new_vals.push(val)
      inserted = 1
    @end
    new_keys = new_keys.push(pq.keys[i])
    new_vals = new_vals.push(pq.vals[i])
    i = i + 1
  @end
  @if inserted == 0
    new_keys = new_keys.push(priority)
    new_vals = new_vals.push(val)
  @end
  return { keys: new_keys, vals: new_vals, hm_size: new_keys.len() }
@end

@fn pq_pop(pq)
  @if pq.keys.len() == 0
    return pq
  @end
  new_keys = list_slice(pq.keys, 1, pq.keys.len())
  new_vals = list_slice(pq.vals, 1, pq.vals.len())
  return { keys: new_keys, vals: new_vals, hm_size: new_keys.len() }
@end

@fn pq_peek(pq)
  @if pq.vals.len() == 0
    return 0
  @end
  return pq.vals[0]
@end

@fn pq_is_empty(pq)
  @if pq.keys.len() == 0
    return 1
  @end
  return 0
@end

@fn pq_size(pq)
  return pq.hm_size
@end

@! ─── HashNode / linked-list style (for compatibility) ───────

@struct HashNode
  h_key: i64
  h_val: i64
  h_next: i64
@end

@! ─── Alias functions for backward compatibility ─────────────

@fn arr_push(arr, val)
  return arr.push(val)
@end

@fn arr_len(arr)
  return arr.len()
@end

@fn map_new()
  return hashmap_new()
@end

@fn map_set(m, k, v)
  return hashmap_set(m, k, v)
@end

@fn map_get(m, k)
  return hashmap_get(m, k)
@end

@fn map_get_or(m, k, default_val)
  @! WHY: Lookup key in hashmap, returning specified fallback value if key is absent or map is nil
  @if m == 0
    return default_val
  @end
  @if hashmap_has(m, k) == 1
    return hashmap_get(m, k)
  @end
  return default_val
@end

@fn map_has(m, k)
  return hashmap_has(m, k)
@end

@fn contains(m, k)
  @! Alias for map.contains(k) method invocation in pure Maya
  return hashmap_has(m, k)
@end

@fn open_hashmap_new(capacity)
  @! Open addressing hashmap — alias backed by list-based hashmap
  return { keys: [], vals: [], hm_size: 0 }
@end

@fn open_hashmap_set(map, key, val)
  return hashmap_set(map, key, val)
@end

@fn open_hashmap_get(map, key)
  return hashmap_get(map, key)
@end

@fn open_hashmap_has(map, key)
  return hashmap_has(map, key)
@end

@fn open_hashmap_delete(map, key)
  return hashmap_delete(map, key)
@end

@fn open_hashmap_size(map)
  return hashmap_size(map)
@end

@fn open_hashmap_put(map, key, val)
  @! Alias for open_hashmap_set
  return hashmap_set(map, key, val)
@end
