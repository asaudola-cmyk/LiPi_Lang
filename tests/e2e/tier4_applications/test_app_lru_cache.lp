@! ============================================================================
@! MAYA E2E TIER 4 — REAL-WORLD APP: SOVEREIGN IN-MEMORY LRU CACHE WITH TTL
@! File: tests/e2e/tier4_applications/test_app_lru_cache.maya
@! RUN: %maya %file
@! EXPECT_EXIT: 0
@! TIER: 4
@! ============================================================================

import "universe/core/string"

@struct LRUNode
  key: ""
  val: ""
  expires_at: 0
  prev_id: 0
  next_id: 0
@end

@struct LRUCache
  capacity: 0
  count: 0
  head_id: 0    @! MRU (Most Recently Used)
  tail_id: 0    @! LRU (Least Recently Used)
  nodes: 0       @! Pool of nodes (1-indexed)
@end

@fn lru_new(cap)
  return {
    capacity: cap,
    count: 0,
    head_id: 0,
    tail_id: 0,
    nodes: [0]   @! 1-indexed
  }
@end

@fn lru_alloc_node(cache, key, val, expires_at)
  nid = cache.nodes.len()
  cache.nodes.push({ key: key, val: val, expires_at: expires_at, prev_id: 0, next_id: 0 })
  return nid
@end

@fn lru_remove_node(cache, nid)
  node = cache.nodes[nid]
  p = node.prev_id
  n = node.next_id

  @if p != 0
    cache.nodes[p].next_id = n
  @else
    cache.head_id = n
  @end

  @if n != 0
    cache.nodes[n].prev_id = p
  @else
    cache.tail_id = p
  @end

  node.prev_id = 0
  node.next_id = 0
  return cache
@end

@fn lru_push_front(cache, nid)
  @if cache.head_id == 0
    cache.head_id = nid
    cache.tail_id = nid
    cache.nodes[nid].prev_id = 0
    cache.nodes[nid].next_id = 0
  @else
    cache.nodes[nid].prev_id = 0
    cache.nodes[nid].next_id = cache.head_id
    cache.nodes[cache.head_id].prev_id = nid
    cache.head_id = nid
  @end
  return cache
@end

@fn lru_find_node_id(cache, key)
  curr = cache.head_id
  @while curr != 0
    node = cache.nodes[curr]
    @if node.key == key
      return curr
    @end
    curr = node.next_id
  @end
  return 0
@end

@fn lru_put(cache, key, val, ttl_sec, now_sec)
  exp = 0
  @if ttl_sec > 0
    exp = now_sec + ttl_sec
  @end

  existing_id = lru_find_node_id(cache, key)
  @if existing_id != 0
    cache = lru_remove_node(cache, existing_id)
    cache.nodes[existing_id].val = val
    cache.nodes[existing_id].expires_at = exp
    cache = lru_push_front(cache, existing_id)
    return cache
  @end

  @! If capacity reached, evict LRU tail
  @if cache.count >= cache.capacity
    evict_id = cache.tail_id
    cache = lru_remove_node(cache, evict_id)
    cache.count = cache.count - 1
  @end

  nid = lru_alloc_node(cache, key, val, exp)
  cache = lru_push_front(cache, nid)
  cache.count = cache.count + 1
  return cache
@end

@fn lru_get(cache, key, now_sec)
  nid = lru_find_node_id(cache, key)
  @if nid == 0
    return ""
  @end

  node = cache.nodes[nid]
  @! Check TTL expiration
  @if node.expires_at > 0 && node.expires_at <= now_sec
    cache = lru_remove_node(cache, nid)
    cache.count = cache.count - 1
    return ""
  @end

  @! Promote to MRU head
  cache = lru_remove_node(cache, nid)
  cache = lru_push_front(cache, nid)

  return node.val
@end

@fn lru_cleanup_expired(cache, now_sec)
  curr = cache.head_id
  evicted_count = 0

  @while curr != 0
    node = cache.nodes[curr]
    next_curr = node.next_id
    @if node.expires_at > 0 && node.expires_at <= now_sec
      cache = lru_remove_node(cache, curr)
      cache.count = cache.count - 1
      evicted_count = evicted_count + 1
    @end
    curr = next_curr
  @end

  return evicted_count
@end

@fn lru_get_keys_order(cache)
  keys = []
  curr = cache.head_id
  @while curr != 0
    node = cache.nodes[curr]
    keys.push(node.key)
    curr = node.next_id
  @end
  return keys
@end

@fn main()
  println("=================================================================")
  println("▶ [TIER 4] Scenario 9: In-Memory LRU Cache with TTL Expiration")
  println("=================================================================")

  total = 0
  passed = 0
  failed = 0

  @! Initialize LRU Cache with capacity 4
  cache = lru_new(4)
  now = 1000

  @! T4.9.1: Populate Cache up to Capacity
  total = total + 1
  cache = lru_put(cache, "k1", "val_1", 0, now)
  cache = lru_put(cache, "k2", "val_2", 0, now)
  cache = lru_put(cache, "k3", "val_3", 0, now)
  cache = lru_put(cache, "k4", "val_4", 0, now)

  k_order1 = lru_get_keys_order(cache)

  @! Expected MRU to LRU order: ["k4", "k3", "k2", "k1"]
  @if cache.count == 4 && k_order1.len() == 4 && k_order1[0] == "k4" && k_order1[3] == "k1"
    passed = passed + 1
    println("  [PASS] T4.9.1: Cache filled to capacity (4 items), MRU order: [k4, k3, k2, k1]")
  @else
    failed = failed + 1
    println("  [FAIL] T4.9.1: Initial cache population failed")
  @end

  @! T4.9.2: Recency Promotion on Access
  total = total + 1
  @! Access k1 (was LRU at tail) -> must become MRU at head
  v1 = lru_get(cache, "k1", now)
  k_order2 = lru_get_keys_order(cache)

  @! Expected order: ["k1", "k4", "k3", "k2"]
  @if v1 == "val_1" && k_order2[0] == "k1" && k_order2[3] == "k2"
    passed = passed + 1
    println("  [PASS] T4.9.2: Accessing 'k1' promoted it from tail to MRU head [k1, k4, k3, k2]")
  @else
    failed = failed + 1
    println("  [FAIL] T4.9.2: Recency promotion failed")
  @end

  @! T4.9.3: Eviction of Least Recently Used Element on Overflow
  total = total + 1
  @! Insert 'k5' -> cache is at capacity 4, so tail 'k2' must be evicted!
  cache = lru_put(cache, "k5", "val_5", 0, now)
  v2_miss = lru_get(cache, "k2", now)
  k_order3 = lru_get_keys_order(cache)

  @! Expected order: ["k5", "k1", "k4", "k3"]
  @if v2_miss == "" && cache.count == 4 && k_order3[0] == "k5" && k_order3[3] == "k3"
    passed = passed + 1
    println("  [PASS] T4.9.3: Inserting 'k5' evicted LRU item 'k2' [k5, k1, k4, k3]")
  @else
    failed = failed + 1
    println("  [FAIL] T4.9.3: LRU eviction failed: v2=" + v2_miss)
  @end

  @! T4.9.4: Time-To-Live (TTL) Passive Expiration on Get
  total = total + 1
  @! Insert 'k_temp' with TTL = 10 seconds (expires at now + 10 = 1010)
  cache = lru_put(cache, "k_temp", "temp_val", 10, now)

  @! Query before expiration (now = 1005) -> hit
  v_active = lru_get(cache, "k_temp", 1005)

  @! Query after expiration (now = 1015) -> miss & auto-eviction
  v_expired = lru_get(cache, "k_temp", 1015)

  @if v_active == "temp_val" && v_expired == ""
    passed = passed + 1
    println("  [PASS] T4.9.4: TTL active hit at t=1005 (\"temp_val\") and expired miss at t=1015 (\"\")")
  @else
    failed = failed + 1
    println("  [FAIL] T4.9.4: TTL get failed: v_active=" + v_active + ", v_expired=" + v_expired)
  @end

  @! T4.9.5: Batch Sweeper Expiration of Expired Keys
  total = total + 1
  cache = lru_put(cache, "exp_a", "val_a", 5, now)   @! expires 1005
  cache = lru_put(cache, "exp_b", "val_b", 5, now)   @! expires 1005
  cache = lru_put(cache, "exp_c", "val_c", 60, now)  @! expires 1060

  @! Sweep at t = 1010 -> sweeps exp_a and exp_b
  swept_count = lru_cleanup_expired(cache, 1010)
  v_c = lru_get(cache, "exp_c", 1010)

  @if swept_count == 2 && v_c == "val_c"
    passed = passed + 1
    println("  [PASS] T4.9.5: Batch sweep pruned 2 expired keys while keeping active key 'exp_c'")
  @else
    failed = failed + 1
    println("  [FAIL] T4.9.5: Batch sweeper failed: count=" + int_to_str(swept_count))
  @end

  println("-----------------------------------------------------------------")
  println("Scenario 9 Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ Scenario 9 (LRU Cache with TTL) PASSED")
    return 0
  @else
    println("✗ Scenario 9 (LRU Cache with TTL) FAILED")
    return 1
  @end
@end
