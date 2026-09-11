@! ============================================================================
@! LIPI UNIVERSE DB - KV NODE (universe/db/distributed/kv_node.maya)
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct KVNode
  node_id: "",
  term: 0,
  store: {},
  wal_log: []
@end

@fn new_kv_node(node_id)
  return {
    node_id: node_id,
    term: 1,
    store: {},
    wal_log: []
  }
@end

@fn kv_put(node, key, val)
  @if node == 0 || key == ""
    return 0
  @end

  @! 1. Append to Write-Ahead Log
  entry = {
    op: "PUT",
    key: key,
    val: val,
    term: node.term
  }
  node.wal_log = node.wal_log.push(entry)

  @! 2. Apply to state machine
  node.store[key] = val
  return 1
@end

@fn kv_get(node, key)
  @if node == 0 || key == ""
    return 0
  @end

  @if node.store.contains(key)
    return node.store[key]
  @end
  return 0
@end

@fn kv_delete(node, key)
  @if node == 0 || key == ""
    return 0
  @end

  @if node.store.contains(key)
    entry = {
      op: "DEL",
      key: key,
      term: node.term
    }
    node.wal_log = node.wal_log.push(entry)
    node.store.delete(key)
    return 1
  @end
  return 0
@end