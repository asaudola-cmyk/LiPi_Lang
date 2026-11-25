@! ============================================================
@! LIPI UNIVERSE — Core Collections Library v2.0
@! Pure Lipi: Stack, Queue, Set, HashMap, list helpers
@! Interpreter-compatible — no sys_peek8/sys_mmap/sys_poke
@! ============================================================

@! ─── Array / List helpers ───────────────────────────────────

@fn c_len(arr)
  @! Character and buffer length alias
  @! WHY: Lowering of .c_len() method syntax in regex and tokenizer creates c_len(arr) calls.
  return len(arr)
@end

@fn exit(code)
  @! Freestanding Linux exit_group syscall (nr 231)
  @! WHY: Direct kernel invocation using compiler intrinsic sys_exit_group so all OS threads terminate cleanly.
  return sys_exit_group(code)
@end

@fn to_str(val)
  @! First-class integer to Lipi string conversion
  @! WHY: Uses native compiler built-in str(val) ensuring STR0 header tag and length prefix.
  return str(val)
@end

@fn print_int(val)
  println(to_str(val))
  return 0
@end

@fn str_eq(s1, s2)
  @! Canonical string equality comparison
  @! WHY: Directly uses native == which lowers to silicon _lipi_cmp_dynamic for zero-copy character comparison.
  return s1 == s2
@end

@fn pop(arr)
  @! WHY: O(1) in-place mutation popping the final element via native runtime _lipi_list_pop
  @! and returning the mutated list reference (preserves both `pop(arr)` and `arr = pop(arr)`).
  @if len(arr) > 0
    _lipi_list_pop(arr)
  @end
  return arr
@end

@fn list_drop_last(arr)
  @! WHY: Pure non-mutating copy returning a new list excluding the final item.
  n = len(arr)
  result = []
  i = 0
  @while i < n - 1
    result = push(result, arr[i])
    i = i + 1
  @end
  return result
@end

@fn pop_value(arr)
  @! WHY: O(1) in-place pop returning the removed element itself.
  return _lipi_list_pop(arr)
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
  @! Insertion sort (pure Lipi, interpreter-safe)
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

@struct LipiSet
  ms_data: array
  ms_size: i64
@end

// WHY: Canonical constructor for an empty array instance
@fn arr_new()
  return []
@end

// WHY: Canonical push function for array manipulation across universe modules
@fn array_push(arr, val)
  return arr.push(val)
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
  hm_buckets: array
  hm_cap: i64
@end

@fn _hm_hash_key(key)
  @if is_str(key) == 1
    h = 2166136261
    n = len(key)
    i = 0
    @while i < n
      b = ord(char_at(key, i))
      h = ((h ^ b) * 16777619) & 2147483647
      i = i + 1
    @end
    return h
  @end
  lo = key & 2147483647
  hi = (key >> 31) & 2147483647
  h = (((lo ^ (hi * 2654435761)) * 2246822519) & 2147483647)
  h = (h ^ (h >> 15)) & 2147483647
  return h
@end

@fn _hm_eq(k1, k2)
  @if is_str(k1) != is_str(k2)
    return 0
  @end
  return k1 == k2
@end

@fn _hm_make_buckets(cap)
  b = []
  i = 0
  @while i < cap
    b = b.push(0)
    i = i + 1
  @end
  return b
@end

@fn _hm_rehash(keys, new_cap)
  buckets = _hm_make_buckets(new_cap)
  mask = new_cap - 1
  n = keys.len()
  i = 0
  @while i < n
    h = _hm_hash_key(keys[i])
    slot = h & mask
    probes = 0
    @while probes < new_cap
      @if buckets[slot] == 0
        list_set(buckets, slot, i + 1)
        break
      @end
      slot = (slot + 1) & mask
      probes = probes + 1
    @end
    i = i + 1
  @end
  return buckets
@end

@fn _hm_ensure_buckets(map)
  @if map.hm_cap > 0 && map.hm_buckets != 0
    return map
  @end
  c = 16
  need = (map.keys.len() * 2) + 4
  @while c < need
    c = c * 2
  @end
  b = _hm_rehash(map.keys, c)
  return { keys: map.keys, vals: map.vals, hm_size: map.hm_size, hm_buckets: b, hm_cap: c }
@end

@fn _hm_find_slot(map, key)
  buckets = map.hm_buckets
  cap = map.hm_cap
  mask = cap - 1
  h = _hm_hash_key(key)
  slot = h & mask
  probes = 0
  @while probes < cap
    sv = buckets[slot]
    @if sv == 0
      return -1
    @end
    @if sv > 0
      @if _hm_eq(map.keys[sv - 1], key) == 1
        return slot
      @end
    @end
    slot = (slot + 1) & mask
    probes = probes + 1
  @end
  return -1
@end

@fn hashmap_new()
  return { keys: [], vals: [], hm_size: 0, hm_buckets: _hm_make_buckets(16), hm_cap: 16 }
@end

@fn hashmap_set(map, key, val)
  m = map
  @if m == 0
    m = hashmap_new()
  @else
    m = _hm_ensure_buckets(m)
  @end
  buckets = m.hm_buckets
  cap = m.hm_cap
  mask = cap - 1
  h = _hm_hash_key(key)
  slot = h & mask
  first_tomb = -1
  first_empty = -1
  probes = 0
  @while probes < cap
    sv = buckets[slot]
    @if sv == 0
      first_empty = slot
      break
    @elif sv == -1
      @if first_tomb < 0
        first_tomb = slot
      @end
    @else
      kidx = sv - 1
      @if _hm_eq(m.keys[kidx], key) == 1
        new_vals = list_set(m.vals, kidx, val)
        return { keys: m.keys, vals: new_vals, hm_size: m.hm_size, hm_buckets: buckets, hm_cap: cap }
      @end
    @end
    slot = (slot + 1) & mask
    probes = probes + 1
  @end

  new_keys = m.keys.push(key)
  new_vals = m.vals.push(val)
  new_sz = m.hm_size + 1
  @if ((new_keys.len() * 4) >= (cap * 3)) || first_empty < 0 || probes > (cap / 2)
    new_cap = cap
    @if ((new_keys.len() * 4) >= (new_cap * 3)) || first_empty < 0
      new_cap = cap * 2
    @end
    new_b = _hm_rehash(new_keys, new_cap)
    return { keys: new_keys, vals: new_vals, hm_size: new_sz, hm_buckets: new_b, hm_cap: new_cap }
  @end
  target = first_empty
  @if first_tomb >= 0
    target = first_tomb
  @end
  list_set(buckets, target, new_keys.len())
  return { keys: new_keys, vals: new_vals, hm_size: new_sz, hm_buckets: buckets, hm_cap: cap }
@end

@fn hashmap_get(map, key)
  @if map == 0 || map.keys == 0 || map.hm_size == 0
    return 0
  @end
  m = _hm_ensure_buckets(map)
  slot = _hm_find_slot(m, key)
  @if slot < 0
    return 0
  @end
  return m.vals[m.hm_buckets[slot] - 1]
@end

@fn hashmap_has(map, key)
  @if map == 0 || map.keys == 0 || map.hm_size == 0
    return 0
  @end
  m = _hm_ensure_buckets(map)
  slot = _hm_find_slot(m, key)
  @if slot >= 0
    return 1
  @end
  return 0
@end

@fn hashmap_delete(map, key)
  @if map == 0 || map.keys == 0 || map.keys.len() == 0
    return map
  @end
  m = _hm_ensure_buckets(map)
  slot = _hm_find_slot(m, key)
  @if slot < 0
    return m
  @end
  buckets = m.hm_buckets
  idx = buckets[slot] - 1
  list_set(buckets, slot, -1)
  last = m.keys.len() - 1
  @if idx < last
    last_k = m.keys[last]
    last_v = m.vals[last]
    lslot = _hm_find_slot(m, last_k)
    list_set(m.keys, idx, last_k)
    list_set(m.vals, idx, last_v)
    @if lslot >= 0
      list_set(buckets, lslot, idx + 1)
    @end
  @end
  new_keys = list_slice(m.keys, 0, last)
  new_vals = list_slice(m.vals, 0, last)
  return { keys: new_keys, vals: new_vals, hm_size: m.hm_size - 1, hm_buckets: buckets, hm_cap: m.hm_cap }
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
  return { keys: [], vals: [], hm_size: 0, hm_buckets: [], hm_cap: 0 }
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
  return { keys: new_keys, vals: new_vals, hm_size: new_keys.len(), hm_buckets: [], hm_cap: 0 }
@end

@fn pq_pop(pq)
  @if pq.keys.len() == 0
    return pq
  @end
  new_keys = list_slice(pq.keys, 1, pq.keys.len())
  new_vals = list_slice(pq.vals, 1, pq.vals.len())
  return { keys: new_keys, vals: new_vals, hm_size: new_keys.len(), hm_buckets: [], hm_cap: 0 }
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

@fn array_len(arr)
  return arr.len()
@end

@fn array_get(arr, idx)
  @if arr == 0 || idx < 0 || idx >= arr.len()
    return 0
  @end
  return arr[idx]
@end

@fn delete(m, key)
  // WHY: Removes key from map collection safely using hashmap_delete while guarding null maps.
  @if m == 0
    return 0
  @end
  return hashmap_delete(m, key)
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

@fn str_contains(haystack, needle)
  // WHY: Substring check in pure Lipi with zero external runtime dependencies
  hlen = len(haystack)
  nlen = len(needle)
  @if nlen == 0
    return 1
  @end
  @if hlen < nlen
    return 0
  @end
  i = 0
  @while i <= hlen - nlen
    match = 1
    j = 0
    @while j < nlen
      @if char_at(haystack, i + j) != char_at(needle, j)
        match = 0
        break
      @end
      j = j + 1
    @end
    @if match == 1
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn contains(m, k)
  // WHY: Polymorphic contains: checks if string contains substring, or if map/collection contains key
  @if is_str(m) == 1
    return str_contains(m, k)
  @end
  return hashmap_has(m, k)
@end

@fn open_hashmap_new(capacity)
  @! Real O(1) open addressing hashmap initialized with power-of-2 bucket capacity
  c = 16
  need = capacity * 2
  @while c < need
    c = c * 2
  @end
  return { keys: [], vals: [], hm_size: 0, hm_buckets: _hm_make_buckets(c), hm_cap: c }
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
