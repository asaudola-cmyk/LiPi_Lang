@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — LRU CACHE
@! Module: universe/db/lru.maya
@! Features: Least Recently Used (LRU) In-Memory Cache for DB & Web
@! ============================================================================

import "universe/core/string"

@struct LRUNode
  key: string
  val: string
  prev: i64
  next: i64
@end

@struct LRUCache
  capacity: i64
  size: i64
  nodes: array
  head: i64
  tail: i64
@end

@fn lru_cache_new(capacity: i64) -> LRUCache
  return {
    capacity: capacity,
    size: 0,
    nodes: [],
    head: -1,
    tail: -1
  }
@end

@fn _lru_find_node(cache: LRUCache, key: string) -> i64
  i = 0
  n = cache.nodes.len()
  @while i < n
    @if cache.nodes[i].key == key
      return i
    @end
    i = i + 1
  @end
  return -1
@end

@fn lru_cache_get(cache: LRUCache, key: string) -> string
  idx = _lru_find_node(cache, key)
  @if idx == -1
    return ""
  @end
  
  @! Move node to head (most recently used)
  cache = _lru_move_to_head(cache, idx)
  return cache.nodes[idx].val
@end

@fn lru_cache_put(cache: LRUCache, key: string, val: string) -> LRUCache
  idx = _lru_find_node(cache, key)
  @if idx != -1
    @! Update existing
    cache.nodes[idx].val = val
    cache = _lru_move_to_head(cache, idx)
    return cache
  @end
  
  @! Insert new
  new_idx = cache.nodes.len()
  new_node = {
    key: key,
    val: val,
    prev: -1,
    next: cache.head
  }
  cache.nodes = cache.nodes.push(new_node)
  
  @if cache.head != -1
    cache.nodes[cache.head].prev = new_idx
  @end
  
  cache.head = new_idx
  
  @if cache.tail == -1
    cache.tail = new_idx
  @end
  
  cache.size = cache.size + 1
  
  @! Evict if over capacity
  @if cache.size > cache.capacity
    cache = _lru_evict_tail(cache)
  @end
  
  return cache
@end

@fn _lru_move_to_head(cache: LRUCache, idx: i64) -> LRUCache
  @if cache.head == idx
    return cache
  @end
  
  node = cache.nodes[idx]
  prev_idx = node.prev
  next_idx = node.next
  
  @! Unlink from current position
  @if prev_idx != -1
    cache.nodes[prev_idx].next = next_idx
  @end
  @if next_idx != -1
    cache.nodes[next_idx].prev = prev_idx
  @else
    @! Was tail
    cache.tail = prev_idx
  @end
  
  @! Move to head
  cache.nodes[idx].prev = -1
  cache.nodes[idx].next = cache.head
  
  @if cache.head != -1
    cache.nodes[cache.head].prev = idx
  @end
  
  cache.head = idx
  
  return cache
@end

@fn _lru_evict_tail(cache: LRUCache) -> LRUCache
  @if cache.tail == -1
    return cache
  @end
  
  tail_idx = cache.tail
  prev_idx = cache.nodes[tail_idx].prev
  
  @if prev_idx != -1
    cache.nodes[prev_idx].next = -1
  @end
  
  cache.tail = prev_idx
  cache.size = cache.size - 1
  
  @! Node memory is leaked in this simple array implementation,
  @! in a real Maya system, GC or free-list would reclaim `cache.nodes[tail_idx]`
  cache.nodes[tail_idx].key = ""
  cache.nodes[tail_idx].val = ""
  
  return cache
@end
