@! ============================================================================
@! LIPI UNIVERSE DB - NATIVE OBJECT-GRAPH DATABASE ENGINE
@! Module: universe/db/object_graph.maya
@! 100% Written in Pure Lipi Language - Zero External C Dependencies
@! Bypasses traditional SQL parsing with high-performance in-memory graph
@! indexing, ACID transactions, graph traversals, and native Raft consensus.
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. Core Data Structures
@! ----------------------------------------------------------------------------

@! Multi-typed key-value property for nodes and edges
@struct GraphProperty
  key: string
  val_str: string
  val_num: i64
  is_num: bool
@end

@! Graph Node Entity
@struct GraphNode
  id: string
  label: string
  properties: array
  is_deleted: bool
@end

@! Graph Edge Entity (Directed / Undirected & Weighted)
@struct GraphEdge
  id: string
  from_id: string
  to_id: string
  label: string
  weight: i64
  is_directed: bool
  properties: array
  is_deleted: bool
@end

@! Inverted Label Index Bucket (label -> [node_ids])
@struct LabelIndexEntry
  idx_label: string
  idx_node_ids: array
@end

@! Inverted Property Index Bucket ((key, val) -> [node_ids])
@struct PropertyIndexEntry
  prop_key: string
  prop_val_str: string
  prop_val_num: i64
  prop_is_num: bool
  prop_node_ids: array
@end

@! Adjacency Mapping Bucket (node_id -> [edge_ids])
@struct AdjacencyEntry
  adj_node_id: string
  adj_edge_ids: array
@end

@! Transaction Mutation Journal Entry (for undo / rollback)
@struct TxJournalEntry
  op_type: string
  entity_id: string
  prev_payload: string
  new_payload: string
@end

@! Main In-Memory Object-Graph Database Engine
@struct ObjectGraphEngine
  nodes: array
  edges: array
  label_index: array
  prop_index: array
  outgoing_adj: array
  incoming_adj: array
  node_count: i64
  edge_count: i64
  in_tx: bool
  current_tx_id: i64
  tx_journal: array
  snapshot_stack: array
@end

@! Transaction Control Handle
@struct GraphTransaction
  tx_id: i64
  state: string
  engine: ObjectGraphEngine
  journal: array
  snapshot_data: string
@end

@! Raft Distributed Consensus Log Entry
@struct RaftLogEntry
  term: i64
  index: i64
  command_type: string
  payload: string
@end

@! Raft Consensus Node State Machine
@struct RaftConsensusNode
  node_id: string
  term: i64
  state: string
  voted_for: string
  log: array
  commit_index: i64
  last_applied: i64
  peers: array
  next_index: array
  match_index: array
  state_machine: ptr
  election_timer: i64
  election_timeout: i64
@end

@! Cypher-like Pattern Specification
@struct GraphPattern
  src_label: string
  edge_label: string
  tgt_label: string
  src_prop_key: string
  src_prop_val: string
  tgt_prop_key: string
  tgt_prop_val: string
  min_weight: i64
@end

@! Cypher-like Pattern Match Result
@struct PatternMatch
  src_id: string
  edge_id: string
  tgt_id: string
  src_label: string
  edge_label: string
  tgt_label: string
@end

@! Shortest Path Search Result
@struct PathResult
  path: array
  edge_ids: array
  total_weight: i64
  found: bool
@end

@! Dijkstra Distance Table Entry
@struct DistEntry
  dist_id: string
  dist_val: i64
  dist_prev: string
  dist_edge: string
  dist_visited: i64
@end

@! RequestVote RPC Structures
@struct RequestVoteArgs
  term: i64
  candidate_id: string
  last_log_index: i64
  last_log_term: i64
@end

@struct RequestVoteReply
  reply_term: i64
  vote_granted: bool
@end

@! AppendEntries RPC Structures
@struct AppendEntriesArgs
  term: i64
  leader_id: string
  prev_log_index: i64
  prev_log_term: i64
  entries: array
  leader_commit: i64
@end

@struct AppendEntriesReply
  reply_term: i64
  success: bool
  match_index: i64
@end

@! Raft Cluster Simulation Harness
@struct RaftCluster
  nodes: array
  total_nodes: i64
  network_drop: bool
@end

@! ----------------------------------------------------------------------------
@! 2. Array & String Helper Utilities
@! ----------------------------------------------------------------------------

@fn array_contains_str(arr: array, target: string) -> i64
  i = 0
  @while i < arr.len()
    @if arr[i] == target
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn array_remove_str(arr: array, target: string) -> array
  res = []
  i = 0
  @while i < arr.len()
    @if arr[i] != target
      res.push(arr[i])
    @end
    i = i + 1
  @end
  return res
@end

@fn array_slice(arr: array, start: i64, end_idx: i64) -> array
  res = []
  i = start
  @while i < end_idx && i < arr.len()
    res.push(arr[i])
    i = i + 1
  @end
  return res
@end

@fn array_reverse(arr: array) -> array
  res = []
  i = arr.len() - 1
  @while i >= 0
    res.push(arr[i])
    i = i - 1
  @end
  return res
@end

@fn og_node_empty() -> GraphNode
  return {
    id: "",
    label: "",
    properties: [],
    is_deleted: true
  }
@end

@fn og_node_is_valid(n: GraphNode) -> bool
  return str_len(n.id) > 0 && !n.is_deleted
@end

@fn og_edge_empty() -> GraphEdge
  return {
    id: "",
    from_id: "",
    to_id: "",
    label: "",
    weight: 0,
    is_directed: true,
    properties: [],
    is_deleted: true
  }
@end

@fn og_edge_is_valid(e: GraphEdge) -> bool
  return str_len(e.id) > 0 && !e.is_deleted
@end

@! ----------------------------------------------------------------------------
@! 3. Engine Initialization & Adjacency / Index Helpers
@! ----------------------------------------------------------------------------

@! Creates a new empty ObjectGraphEngine
@fn og_engine_new() -> ObjectGraphEngine
  return {
    nodes: [],
    edges: [],
    label_index: [],
    prop_index: [],
    outgoing_adj: [],
    incoming_adj: [],
    node_count: 0,
    edge_count: 0,
    in_tx: false,
    current_tx_id: 0,
    tx_journal: [],
    snapshot_stack: []
  }
@end

@! Helper: Register edge ID in an adjacency map
@fn og_adj_add(adj_list: array, node_id: string, edge_id: string) -> i64
  i = 0
  @while i < adj_list.len()
    entry = adj_list[i]
    @if entry.adj_node_id == node_id
      @if array_contains_str(entry.adj_edge_ids, edge_id) == 0
        entry.adj_edge_ids.push(edge_id)
      @end
      return 1
    @end
    i = i + 1
  @end
  adj_list.push({
    adj_node_id: node_id,
    adj_edge_ids: [edge_id]
  })
  return 1
@end

@! Helper: Remove edge ID from an adjacency map
@fn og_adj_remove(adj_list: array, node_id: string, edge_id: string) -> i64
  i = 0
  @while i < adj_list.len()
    entry = adj_list[i]
    @if entry.adj_node_id == node_id
      entry.adj_edge_ids = array_remove_str(entry.adj_edge_ids, edge_id)
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@! Helper: Add node ID to label index
@fn og_index_add_label(engine: ObjectGraphEngine, label: string, node_id: string) -> i64
  @if str_len(label) == 0
    return 0
  @end
  i = 0
  @while i < engine.label_index.len()
    entry = engine.label_index[i]
    @if entry.idx_label == label
      @if array_contains_str(entry.idx_node_ids, node_id) == 0
        entry.idx_node_ids.push(node_id)
      @end
      return 1
    @end
    i = i + 1
  @end
  engine.label_index.push({
    idx_label: label,
    idx_node_ids: [node_id]
  })
  return 1
@end

@! Helper: Remove node ID from label index
@fn og_index_remove_label(engine: ObjectGraphEngine, label: string, node_id: string) -> i64
  i = 0
  @while i < engine.label_index.len()
    entry = engine.label_index[i]
    @if entry.idx_label == label
      entry.idx_node_ids = array_remove_str(entry.idx_node_ids, node_id)
      return 1
    @end
    i = i + 1
  @end
  return 0
@end

@! Helper: Add node ID to property index
@fn og_index_add_prop(engine: ObjectGraphEngine, key: string, val_str: string, val_num: i64, is_num: bool, node_id: string) -> i64
  i = 0
  @while i < engine.prop_index.len()
    entry = engine.prop_index[i]
    @if entry.prop_key == key && entry.prop_is_num == is_num
      is_matched = 0
      @if is_num
        @if entry.prop_val_num == val_num
          is_matched = 1
        @end
      @else
        @if entry.prop_val_str == val_str
          is_matched = 1
        @end
      @end
      @if is_matched == 1
        @if array_contains_str(entry.prop_node_ids, node_id) == 0
          entry.prop_node_ids.push(node_id)
        @end
        return 1
      @end
    @end
    i = i + 1
  @end
  engine.prop_index.push({
    prop_key: key,
    prop_val_str: val_str,
    prop_val_num: val_num,
    prop_is_num: is_num,
    prop_node_ids: [node_id]
  })
  return 1
@end

@! Helper: Remove node ID from property index
@fn og_index_remove_prop(engine: ObjectGraphEngine, key: string, val_str: string, val_num: i64, is_num: bool, node_id: string) -> i64
  i = 0
  @while i < engine.prop_index.len()
    entry = engine.prop_index[i]
    @if entry.prop_key == key && entry.prop_is_num == is_num
      is_matched = 0
      @if is_num
        @if entry.prop_val_num == val_num
          is_matched = 1
        @end
      @else
        @if entry.prop_val_str == val_str
          is_matched = 1
        @end
      @end
      @if is_matched == 1
        entry.prop_node_ids = array_remove_str(entry.prop_node_ids, node_id)
        return 1
      @end
    @end
    i = i + 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 4. Entity CRUD Operations
@! ----------------------------------------------------------------------------

@! Look up node by ID
@fn og_get_node(engine: ObjectGraphEngine, id: string) -> GraphNode
  i = 0
  @while i < engine.nodes.len()
    n = engine.nodes[i]
    @if n.id == id && !n.is_deleted
      return n
    @end
    i = i + 1
  @end
  return og_node_empty()
@end

@! Look up edge by ID
@fn og_get_edge(engine: ObjectGraphEngine, id: string) -> GraphEdge
  i = 0
  @while i < engine.edges.len()
    e = engine.edges[i]
    @if e.id == id && !e.is_deleted
      return e
    @end
    i = i + 1
  @end
  return og_edge_empty()
@end

@! Add or reactivate a node
@fn og_add_node(engine: ObjectGraphEngine, id: string, label: string) -> GraphNode
  @if str_len(id) == 0
    return og_node_empty()
  @end
  
  existing = og_get_node(engine, id)
  @if og_node_is_valid(existing)
    return existing
  @end

  node = {
    id: id,
    label: label,
    properties: [],
    is_deleted: false
  }
  engine.nodes.push(node)
  engine.node_count = engine.node_count + 1
  og_index_add_label(engine, label, id)

  @if engine.in_tx
    engine.tx_journal.push({
      op_type: "ADD_NODE",
      entity_id: id,
      prev_payload: "",
      new_payload: id + ":" + label
    })
  @end

  return node
@end

@! Add directed weighted edge
@fn og_add_edge(engine: ObjectGraphEngine, id: string, from_id: string, to_id: string, label: string, weight: i64) -> GraphEdge
  @if str_len(id) == 0
    return og_edge_empty()
  @end
  
  from_node = og_get_node(engine, from_id)
  to_node = og_get_node(engine, to_id)
  @if !og_node_is_valid(from_node) || !og_node_is_valid(to_node)
    return og_edge_empty()
  @end

  existing = og_get_edge(engine, id)
  @if og_edge_is_valid(existing)
    return og_edge_empty()
  @end

  edge = {
    id: id,
    from_id: from_id,
    to_id: to_id,
    label: label,
    weight: weight,
    is_directed: true,
    properties: [],
    is_deleted: false
  }
  engine.edges.push(edge)
  engine.edge_count = engine.edge_count + 1

  og_adj_add(engine.outgoing_adj, from_id, id)
  og_adj_add(engine.incoming_adj, to_id, id)

  @if engine.in_tx
    engine.tx_journal.push({
      op_type: "ADD_EDGE",
      entity_id: id,
      prev_payload: "",
      new_payload: id + ":" + from_id + ":" + to_id + ":" + label + ":" + int_to_str(weight) + ":1"
    })
  @end

  return edge
@end

@! Add undirected weighted edge (traversable symmetrically)
@fn og_add_edge_undirected(engine: ObjectGraphEngine, id: string, from_id: string, to_id: string, label: string, weight: i64) -> GraphEdge
  @if str_len(id) == 0
    return og_edge_empty()
  @end
  
  from_node = og_get_node(engine, from_id)
  to_node = og_get_node(engine, to_id)
  @if !og_node_is_valid(from_node) || !og_node_is_valid(to_node)
    return og_edge_empty()
  @end

  existing = og_get_edge(engine, id)
  @if og_edge_is_valid(existing)
    return og_edge_empty()
  @end

  edge = {
    id: id,
    from_id: from_id,
    to_id: to_id,
    label: label,
    weight: weight,
    is_directed: false,
    properties: [],
    is_deleted: false
  }
  engine.edges.push(edge)
  engine.edge_count = engine.edge_count + 1

  og_adj_add(engine.outgoing_adj, from_id, id)
  og_adj_add(engine.incoming_adj, to_id, id)
  og_adj_add(engine.outgoing_adj, to_id, id)
  og_adj_add(engine.incoming_adj, from_id, id)

  @if engine.in_tx
    engine.tx_journal.push({
      op_type: "ADD_EDGE",
      entity_id: id,
      prev_payload: "",
      new_payload: id + ":" + from_id + ":" + to_id + ":" + label + ":" + int_to_str(weight) + ":0"
    })
  @end

  return edge
@end

@! Delete edge and update adjacency
@fn og_delete_edge(engine: ObjectGraphEngine, edge_id: string) -> bool
  i = 0
  @while i < engine.edges.len()
    e = engine.edges[i]
    @if e.id == edge_id && !e.is_deleted
      e.is_deleted = true
      engine.edge_count = engine.edge_count - 1

      og_adj_remove(engine.outgoing_adj, e.from_id, edge_id)
      og_adj_remove(engine.incoming_adj, e.to_id, edge_id)
      @if !e.is_directed
        og_adj_remove(engine.outgoing_adj, e.to_id, edge_id)
        og_adj_remove(engine.incoming_adj, e.from_id, edge_id)
      @end

      @if engine.in_tx
        engine.tx_journal.push({
          op_type: "DEL_EDGE",
          entity_id: edge_id,
          prev_payload: e.id + ":" + e.from_id + ":" + e.to_id + ":" + e.label + ":" + int_to_str(e.weight),
          new_payload: ""
        })
      @end

      return true
    @end
    i = i + 1
  @end
  return false
@end

@! Delete node and cascade delete incident edges
@fn og_delete_node(engine: ObjectGraphEngine, node_id: string) -> bool
  node = og_get_node(engine, node_id)
  @if !og_node_is_valid(node)
    return false
  @end

  n = node
  n.is_deleted = true
  engine.node_count = engine.node_count - 1

  og_index_remove_label(engine, n.label, node_id)

  p_idx = 0
  @while p_idx < n.properties.len()
    p = n.properties[p_idx]
    og_index_remove_prop(engine, p.key, p.val_str, p.val_num, p.is_num, node_id)
    p_idx = p_idx + 1
  @end

  @! Cascade delete all outgoing and incoming incident edges
  e_idx = 0
  @while e_idx < engine.edges.len()
    e = engine.edges[e_idx]
    @if !e.is_deleted && (e.from_id == node_id || e.to_id == node_id)
      og_delete_edge(engine, e.id)
    @end
    e_idx = e_idx + 1
  @end

  @if engine.in_tx
    engine.tx_journal.push({
      op_type: "DEL_NODE",
      entity_id: node_id,
      prev_payload: n.id + ":" + n.label,
      new_payload: ""
    })
  @end

  return true
@end

@! Set property on node
@fn og_set_node_prop(engine: ObjectGraphEngine, node_id: string, key: string, val_str: string, val_num: i64, is_num: bool) -> bool
  node = og_get_node(engine, node_id)
  @if !og_node_is_valid(node)
    return false
  @end

  n = node
  found = 0
  i = 0
  @while i < n.properties.len()
    p = n.properties[i]
    @if p.key == key
      og_index_remove_prop(engine, p.key, p.val_str, p.val_num, p.is_num, node_id)
      p.val_str = val_str
      p.val_num = val_num
      p.is_num = is_num
      found = 1
      break
    @end
    i = i + 1
  @end

  @if found == 0
    n.properties.push({
      key: key,
      val_str: val_str,
      val_num: val_num,
      is_num: is_num
    })
  @end

  og_index_add_prop(engine, key, val_str, val_num, is_num, node_id)

  @if engine.in_tx
    is_num_s = "0"
    @if is_num
      is_num_s = "1"
    @end
    engine.tx_journal.push({
      op_type: "SET_NODE_PROP",
      entity_id: node_id,
      prev_payload: "",
      new_payload: key + ":" + val_str + ":" + int_to_str(val_num) + ":" + is_num_s
    })
  @end

  return true
@end

@! Set property on edge
@fn og_set_edge_prop(engine: ObjectGraphEngine, edge_id: string, key: string, val_str: string, val_num: i64, is_num: bool) -> bool
  edge = og_get_edge(engine, edge_id)
  @if !og_edge_is_valid(edge)
    return false
  @end

  e = edge
  found = 0
  i = 0
  @while i < e.properties.len()
    p = e.properties[i]
    @if p.key == key
      p.val_str = val_str
      p.val_num = val_num
      p.is_num = is_num
      found = 1
      break
    @end
    i = i + 1
  @end

  @if found == 0
    e.properties.push({
      key: key,
      val_str: val_str,
      val_num: val_num,
      is_num: is_num
    })
  @end

  return true
@end

@! Get string property value from node
@fn og_get_node_prop_str(engine: ObjectGraphEngine, node_id: string, key: string) -> string
  node = og_get_node(engine, node_id)
  @if !og_node_is_valid(node)
    return ""
  @end
  n = node
  i = 0
  @while i < n.properties.len()
    p = n.properties[i]
    @if p.key == key
      return p.val_str
    @end
    i = i + 1
  @end
  return ""
@end

@! Get numeric property value from node
@fn og_get_node_prop_num(engine: ObjectGraphEngine, node_id: string, key: string) -> i64
  node = og_get_node(engine, node_id)
  @if !og_node_is_valid(node)
    return 0
  @end
  n = node
  i = 0
  @while i < n.properties.len()
    p = n.properties[i]
    @if p.key == key
      return p.val_num
    @end
    i = i + 1
  @end
  return 0
@end

@! ----------------------------------------------------------------------------
@! 5. Inverted Index Lookups & Neighborhood Queries
@! ----------------------------------------------------------------------------

@! Find node IDs matching label
@fn og_find_nodes_by_label(engine: ObjectGraphEngine, label: string) -> array
  i = 0
  @while i < engine.label_index.len()
    entry = engine.label_index[i]
    @if entry.idx_label == label
      return entry.idx_node_ids
    @end
    i = i + 1
  @end
  return []
@end

@! Find node IDs matching string property
@fn og_find_nodes_by_prop_str(engine: ObjectGraphEngine, key: string, val_str: string) -> array
  i = 0
  @while i < engine.prop_index.len()
    entry = engine.prop_index[i]
    @if entry.prop_key == key && !entry.prop_is_num && entry.prop_val_str == val_str
      return entry.prop_node_ids
    @end
    i = i + 1
  @end
  return []
@end

@! Find node IDs matching numeric property
@fn og_find_nodes_by_prop_num(engine: ObjectGraphEngine, key: string, val_num: i64) -> array
  i = 0
  @while i < engine.prop_index.len()
    entry = engine.prop_index[i]
    @if entry.prop_key == key && entry.prop_is_num && entry.prop_val_num == val_num
      return entry.prop_node_ids
    @end
    i = i + 1
  @end
  return []
@end

@! Get outgoing edges from node
@fn og_get_out_edges(engine: ObjectGraphEngine, node_id: string) -> array
  res = []
  i = 0
  @while i < engine.outgoing_adj.len()
    entry = engine.outgoing_adj[i]
    @if entry.adj_node_id == node_id
      j = 0
      @while j < entry.adj_edge_ids.len()
        eid = entry.adj_edge_ids[j]
        e = og_get_edge(engine, eid)
        @if og_edge_is_valid(e)
          res.push(e)
        @end
        j = j + 1
      @end
      return res
    @end
    i = i + 1
  @end
  return res
@end

@! Get incoming edges to node
@fn og_get_in_edges(engine: ObjectGraphEngine, node_id: string) -> array
  res = []
  i = 0
  @while i < engine.incoming_adj.len()
    entry = engine.incoming_adj[i]
    @if entry.adj_node_id == node_id
      j = 0
      @while j < entry.adj_edge_ids.len()
        eid = entry.adj_edge_ids[j]
        e = og_get_edge(engine, eid)
        @if og_edge_is_valid(e)
          res.push(e)
        @end
        j = j + 1
      @end
      return res
    @end
    i = i + 1
  @end
  return res
@end

@! Get neighbors filtered by direction ("OUT", "IN", "BOTH") and optional label filter
@fn og_get_neighbors(engine: ObjectGraphEngine, node_id: string, direction: string, label_filter: string) -> array
  res = []
  
  @if direction == "OUT" || direction == "BOTH"
    out_edges = og_get_out_edges(engine, node_id)
    i = 0
    @while i < out_edges.len()
      e = out_edges[i]
      is_matched = 1
      @if str_len(label_filter) > 0 && e.label != label_filter
        is_matched = 0
      @end
      @if is_matched == 1
        tgt = e.to_id
        @if !e.is_directed && e.to_id == node_id
          tgt = e.from_id
        @end
        @if array_contains_str(res, tgt) == 0
          res.push(tgt)
        @end
      @end
      i = i + 1
    @end
  @end

  @if direction == "IN" || direction == "BOTH"
    in_edges = og_get_in_edges(engine, node_id)
    i = 0
    @while i < in_edges.len()
      e = in_edges[i]
      is_matched = 1
      @if str_len(label_filter) > 0 && e.label != label_filter
        is_matched = 0
      @end
      @if is_matched == 1
        src = e.from_id
        @if !e.is_directed && e.from_id == node_id
          src = e.to_id
        @end
        @if array_contains_str(res, src) == 0
          res.push(src)
        @end
      @end
      i = i + 1
    @end
  @end

  return res
@end

@! Get node degree in given direction
@fn og_get_degree(engine: ObjectGraphEngine, node_id: string, direction: string) -> i64
  nbrs = og_get_neighbors(engine, node_id, direction, "")
  return nbrs.len()
@end

@! ----------------------------------------------------------------------------
@! 6. Graph Algorithms: BFS, DFS, Dijkstra, Subgraph & Pattern Matching
@! ----------------------------------------------------------------------------

@! Breadth-First Search traversal
@fn og_bfs_traverse(engine: ObjectGraphEngine, start_id: string) -> array
  start_node = og_get_node(engine, start_id)
  @if !og_node_is_valid(start_node)
    return []
  @end

  visited = [start_id]
  queue = [start_id]
  result = []

  head = 0
  @while head < queue.len()
    curr_id = queue[head]
    head = head + 1
    result.push(curr_id)

    out_edges = og_get_out_edges(engine, curr_id)
    i = 0
    @while i < out_edges.len()
      e = out_edges[i]
      next_id = e.to_id
      @if !e.is_directed && e.to_id == curr_id
        next_id = e.from_id
      @end
      @if array_contains_str(visited, next_id) == 0
        visited.push(next_id)
        queue.push(next_id)
      @end
      i = i + 1
    @end
  @end

  return result
@end

@! Extended BFS with depth limit, direction, and relation filter
@fn og_bfs_traverse_ext(engine: ObjectGraphEngine, start_id: string, max_depth: i64, direction: string, label_filter: string) -> array
  start_node = og_get_node(engine, start_id)
  @if !og_node_is_valid(start_node)
    return []
  @end

  visited = [start_id]
  queue_nodes = [start_id]
  queue_depths = [0]
  result = []

  head = 0
  @while head < queue_nodes.len()
    curr_id = queue_nodes[head]
    curr_depth = queue_depths[head]
    head = head + 1
    result.push(curr_id)

    @if max_depth <= 0 || curr_depth < max_depth
      nbrs = og_get_neighbors(engine, curr_id, direction, label_filter)
      i = 0
      @while i < nbrs.len()
        nid = nbrs[i]
        @if array_contains_str(visited, nid) == 0
          visited.push(nid)
          queue_nodes.push(nid)
          queue_depths.push(curr_depth + 1)
        @end
        i = i + 1
      @end
    @end
  @end

  return result
@end

@! Unweighted shortest path using BFS
@fn og_shortest_path_bfs(engine: ObjectGraphEngine, start_id: string, target_id: string) -> array
  @if start_id == target_id
    s_node = og_get_node(engine, start_id)
    @if og_node_is_valid(s_node)
      return [start_id]
    @end
    return []
  @end

  start_node = og_get_node(engine, start_id)
  target_node = og_get_node(engine, target_id)
  @if !og_node_is_valid(start_node) || !og_node_is_valid(target_node)
    return []
  @end

  visited = [start_id]
  queue = [start_id]
  prev_map_keys = [start_id]
  prev_map_vals = [""]

  found = 0
  head = 0
  @while head < queue.len()
    curr_id = queue[head]
    head = head + 1

    @if curr_id == target_id
      found = 1
      break
    @end

    out_edges = og_get_out_edges(engine, curr_id)
    i = 0
    @while i < out_edges.len()
      e = out_edges[i]
      next_id = e.to_id
      @if !e.is_directed && e.to_id == curr_id
        next_id = e.from_id
      @end
      @if array_contains_str(visited, next_id) == 0
        visited.push(next_id)
        queue.push(next_id)
        prev_map_keys.push(next_id)
        prev_map_vals.push(curr_id)
      @end
      i = i + 1
    @end
  @end

  @if found == 0
    return []
  @end

  path = []
  curr = target_id
  @while str_len(curr) > 0
    path.push(curr)
    @if curr == start_id
      break
    @end
    p_idx = 0
    next_curr = ""
    @while p_idx < prev_map_keys.len()
      @if prev_map_keys[p_idx] == curr
        next_curr = prev_map_vals[p_idx]
        break
      @end
      p_idx = p_idx + 1
    @end
    curr = next_curr
  @end

  return array_reverse(path)
@end

@! DFS Traversal Helper
@fn og_dfs_helper(engine: ObjectGraphEngine, curr_id: string, visited: array, result: array)
  visited.push(curr_id)
  result.push(curr_id)

  out_edges = og_get_out_edges(engine, curr_id)
  i = 0
  @while i < out_edges.len()
    e = out_edges[i]
    next_id = e.to_id
    @if !e.is_directed && e.to_id == curr_id
      next_id = e.from_id
    @end
    @if array_contains_str(visited, next_id) == 0
      og_dfs_helper(engine, next_id, visited, result)
    @end
    i = i + 1
  @end
@end

@! Depth-First Search traversal
@fn og_dfs_traverse(engine: ObjectGraphEngine, start_id: string) -> array
  start_node = og_get_node(engine, start_id)
  @if !og_node_is_valid(start_node)
    return []
  @end

  visited = []
  result = []
  og_dfs_helper(engine, start_id, visited, result)
  return result
@end

@! DFS Cycle Detection Helper
@fn og_dfs_cycle_helper(engine: ObjectGraphEngine, curr_id: string, visiting: array, visited: array, cycles: array)
  visiting.push(curr_id)

  out_edges = og_get_out_edges(engine, curr_id)
  i = 0
  @while i < out_edges.len()
    e = out_edges[i]
    next_id = e.to_id
    @if !e.is_directed && e.to_id == curr_id
      next_id = e.from_id
    @end

    @if array_contains_str(visiting, next_id) == 1
      @! Cycle detected!
      cyc_str = ""
      in_cycle = 0
      k = 0
      @while k < visiting.len()
        @if visiting[k] == next_id
          in_cycle = 1
        @end
        @if in_cycle == 1
          @if str_len(cyc_str) > 0
            cyc_str = cyc_str + " -> "
          @end
          cyc_str = cyc_str + visiting[k]
        @end
        k = k + 1
      @end
      cyc_str = cyc_str + " -> " + next_id
      @if array_contains_str(cycles, cyc_str) == 0
        cycles.push(cyc_str)
      @end
    @elif array_contains_str(visited, next_id) == 0
      og_dfs_cycle_helper(engine, next_id, visiting, visited, cycles)
    @end
    i = i + 1
  @end

  visited.push(curr_id)
@end

@! DFS Cycle Detection
@fn og_dfs_detect_cycles(engine: ObjectGraphEngine, start_id: string) -> array
  start_node = og_get_node(engine, start_id)
  @if !og_node_is_valid(start_node)
    return []
  @end

  visiting = []
  visited = []
  cycles = []
  og_dfs_cycle_helper(engine, start_id, visiting, visited, cycles)
  return cycles
@end

@! Dijkstra Weighted Shortest Path Algorithm
@fn og_dijkstra_shortest_path(engine: ObjectGraphEngine, start_id: string, target_id: string) -> array
  @if start_id == target_id
    s_node = og_get_node(engine, start_id)
    @if og_node_is_valid(s_node)
      return [start_id]
    @end
    return []
  @end

  start_node = og_get_node(engine, start_id)
  target_node = og_get_node(engine, target_id)
  @if !og_node_is_valid(start_node) || !og_node_is_valid(target_node)
    return []
  @end

  @! Build distance table for all active nodes
  dist_table = []
  n_idx = 0
  @while n_idx < engine.nodes.len()
    n = engine.nodes[n_idx]
    @if !n.is_deleted
      init_val = 999999999
      @if n.id == start_id
        init_val = 0
      @end
      dist_table.push({
        dist_id: n.id,
        dist_val: init_val,
        dist_prev: "",
        dist_edge: "",
        dist_visited: 0
      })
    @end
    n_idx = n_idx + 1
  @end

  step = 0
  @while step < dist_table.len()
    @! Find unvisited node with minimum distance
    min_idx = -1
    min_val = 999999999
    j = 0
    @while j < dist_table.len()
      entry = dist_table[j]
      @if entry.dist_visited == 0 && entry.dist_val < min_val
        min_val = entry.dist_val
        min_idx = j
      @end
      j = j + 1
    @end

    @if min_idx == -1 || min_val >= 999999999
      break
    @end

    curr = dist_table[min_idx]
    curr.dist_visited = 1

    @if curr.dist_id == target_id
      break
    @end

    @! Relax outgoing edges
    out_edges = og_get_out_edges(engine, curr.dist_id)
    k = 0
    @while k < out_edges.len()
      e = out_edges[k]
      nbr_id = e.to_id
      @if !e.is_directed && e.to_id == curr.dist_id
        nbr_id = e.from_id
      @end

      w = e.weight
      @if w < 0
        w = 0
      @end

      alt = curr.dist_val + w
      t_idx = 0
      @while t_idx < dist_table.len()
        tgt_entry = dist_table[t_idx]
        @if tgt_entry.dist_id == nbr_id && tgt_entry.dist_visited == 0
          @if alt < tgt_entry.dist_val
            tgt_entry.dist_val = alt
            tgt_entry.dist_prev = curr.dist_id
            tgt_entry.dist_edge = e.id
          @end
        @end
        t_idx = t_idx + 1
      @end
      k = k + 1
    @end

    step = step + 1
  @end

  @! Check if target was reached
  target_reached = 0
  d_idx = 0
  @while d_idx < dist_table.len()
    d = dist_table[d_idx]
    @if d.dist_id == target_id && d.dist_val < 999999999
      target_reached = 1
      break
    @end
    d_idx = d_idx + 1
  @end

  @if target_reached == 0
    return []
  @end

  @! Reconstruct path backwards from target_id to start_id
  path = []
  curr_trace = target_id
  @while str_len(curr_trace) > 0
    path.push(curr_trace)
    @if curr_trace == start_id
      break
    @end

    prev_found = ""
    p_search = 0
    @while p_search < dist_table.len()
      entry = dist_table[p_search]
      @if entry.dist_id == curr_trace
        prev_found = entry.dist_prev
        break
      @end
      p_search = p_search + 1
    @end
    curr_trace = prev_found
  @end

  return array_reverse(path)
@end

@! Extract induced subgraph containing only specified node IDs
@fn og_extract_subgraph(engine: ObjectGraphEngine, node_ids: array) -> ObjectGraphEngine
  sub = og_engine_new()
  
  i = 0
  @while i < node_ids.len()
    nid = node_ids[i]
    orig = og_get_node(engine, nid)
    @if og_node_is_valid(orig)
      on = orig
      sub_node = og_add_node(sub, on.id, on.label)
      p_idx = 0
      @while p_idx < on.properties.len()
        p = on.properties[p_idx]
        og_set_node_prop(sub, on.id, p.key, p.val_str, p.val_num, p.is_num)
        p_idx = p_idx + 1
      @end
    @end
    i = i + 1
  @end

  e_idx = 0
  @while e_idx < engine.edges.len()
    e = engine.edges[e_idx]
    @if !e.is_deleted
      @if array_contains_str(node_ids, e.from_id) == 1 && array_contains_str(node_ids, e.to_id) == 1
        @if e.is_directed
          og_add_edge(sub, e.id, e.from_id, e.to_id, e.label, e.weight)
        @else
          og_add_edge_undirected(sub, e.id, e.from_id, e.to_id, e.label, e.weight)
        @end
        ep_idx = 0
        @while ep_idx < e.properties.len()
          ep = e.properties[ep_idx]
          og_set_edge_prop(sub, e.id, ep.key, ep.val_str, ep.val_num, ep.is_num)
          ep_idx = ep_idx + 1
        @end
      @end
    @end
    e_idx = e_idx + 1
  @end

  return sub
@end

@! Cypher-like declarative pattern matcher
@fn og_match_pattern(engine: ObjectGraphEngine, pattern: GraphPattern) -> array
  matches = []
  
  candidate_ids = []
  @if str_len(pattern.src_label) > 0
    candidate_ids = og_find_nodes_by_label(engine, pattern.src_label)
  @else
    n_idx = 0
    @while n_idx < engine.nodes.len()
      n = engine.nodes[n_idx]
      @if !n.is_deleted
        candidate_ids.push(n.id)
      @end
      n_idx = n_idx + 1
    @end
  @end

  c_idx = 0
  @while c_idx < candidate_ids.len()
    src_id = candidate_ids[c_idx]
    src_node = og_get_node(engine, src_id)
    @if og_node_is_valid(src_node)
      sn = src_node
      
      @! Verify source node property filter
      src_prop_ok = 1
      @if str_len(pattern.src_prop_key) > 0
        val = og_get_node_prop_str(engine, src_id, pattern.src_prop_key)
        @if val != pattern.src_prop_val
          src_prop_ok = 0
        @end
      @end

      @if src_prop_ok == 1
        out_edges = og_get_out_edges(engine, src_id)
        e_idx = 0
        @while e_idx < out_edges.len()
          e = out_edges[e_idx]
          edge_ok = 1
          @if str_len(pattern.edge_label) > 0 && e.label != pattern.edge_label
            edge_ok = 0
          @end
          @if pattern.min_weight > 0 && e.weight < pattern.min_weight
            edge_ok = 0
          @end

          @if edge_ok == 1
            tgt_id = e.to_id
            @if !e.is_directed && e.to_id == src_id
              tgt_id = e.from_id
            @end
            tgt_node = og_get_node(engine, tgt_id)
            @if og_node_is_valid(tgt_node)
              tn = tgt_node
              tgt_ok = 1
              @if str_len(pattern.tgt_label) > 0 && tn.label != pattern.tgt_label
                tgt_ok = 0
              @end
              @if str_len(pattern.tgt_prop_key) > 0
                t_val = og_get_node_prop_str(engine, tgt_id, pattern.tgt_prop_key)
                @if t_val != pattern.tgt_prop_val
                  tgt_ok = 0
                @end
              @end

              @if tgt_ok == 1
                matches.push({
                  src_id: src_id,
                  edge_id: e.id,
                  tgt_id: tgt_id,
                  src_label: sn.label,
                  edge_label: e.label,
                  tgt_label: tn.label
                })
              @end
            @end
          @end
          e_idx = e_idx + 1
        @end
      @end
    @end
    c_idx = c_idx + 1
  @end

  return matches
@end

@! Query triples helper
@fn og_query_triples(engine: ObjectGraphEngine, src_label: string, rel_label: string, tgt_label: string) -> array
  pattern = {
    src_label: src_label,
    edge_label: rel_label,
    tgt_label: tgt_label,
    src_prop_key: "",
    src_prop_val: "",
    tgt_prop_key: "",
    tgt_prop_val: "",
    min_weight: 0
  }
  return og_match_pattern(engine, pattern)
@end

@! ----------------------------------------------------------------------------
@! 7. Snapshot Serialization & ACID Transactions
@! ----------------------------------------------------------------------------

@! Serializes the entire engine state to deterministic snapshot string
@fn og_export_snapshot(engine: ObjectGraphEngine) -> string
  res = "OG_SNAPSHOT_V1|NODES:"
  
  first_node = 1
  i = 0
  @while i < engine.nodes.len()
    n = engine.nodes[i]
    @if !n.is_deleted
      @if first_node == 0
        res = res + ";"
      @end
      first_node = 0
      res = res + n.id + "," + n.label
      
      @if n.properties.len() > 0
        res = res + ","
        p_idx = 0
        @while p_idx < n.properties.len()
          p = n.properties[p_idx]
          @if p_idx > 0
            res = res + "&"
          @end
          p_num_s = "0"
          @if p.is_num
            p_num_s = "1"
          @end
          res = res + p.key + "=" + p.val_str + "=" + int_to_str(p.val_num) + "=" + p_num_s
          p_idx = p_idx + 1
        @end
      @end
    @end
    i = i + 1
  @end

  res = res + "|EDGES:"
  first_edge = 1
  j = 0
  @while j < engine.edges.len()
    e = engine.edges[j]
    @if !e.is_deleted
      @if first_edge == 0
        res = res + ";"
      @end
      first_edge = 0
      dir_s = "0"
      @if e.is_directed
        dir_s = "1"
      @end
      res = res + e.id + "," + e.from_id + "," + e.to_id + "," + e.label + "," + int_to_str(e.weight) + "," + dir_s
      
      @if e.properties.len() > 0
        res = res + ","
        ep_idx = 0
        @while ep_idx < e.properties.len()
          ep = e.properties[ep_idx]
          @if ep_idx > 0
            res = res + "&"
          @end
          ep_num_s = "0"
          @if ep.is_num
            ep_num_s = "1"
          @end
          res = res + ep.key + "=" + ep.val_str + "=" + int_to_str(ep.val_num) + "=" + ep_num_s
          ep_idx = ep_idx + 1
        @end
      @end
    @end
    j = j + 1
  @end

  return res
@end

@! Rebuilds an ObjectGraphEngine from snapshot string
@fn og_import_snapshot(snapshot: string) -> ObjectGraphEngine
  engine = og_engine_new()
  @if str_len(snapshot) == 0
    return engine
  @end

  sections = string_split(snapshot, "|")
  @if sections.len() < 3
    return engine
  @end

  @! Section 1: NODES
  node_sec = sections[1]
  node_prefix = string_split(node_sec, ":")
  @if node_prefix.len() >= 2 && str_len(node_prefix[1]) > 0
    node_records = string_split(node_prefix[1], ";")
    i = 0
    @while i < node_records.len()
      rec = node_records[i]
      @if str_len(rec) > 0
        fields = string_split(rec, ",")
        @if fields.len() >= 2
          nid = fields[0]
          nlabel = fields[1]
          og_add_node(engine, nid, nlabel)
          
          @if fields.len() >= 3 && str_len(fields[2]) > 0
            prop_entries = string_split(fields[2], "&")
            p_idx = 0
            @while p_idx < prop_entries.len()
              pe = prop_entries[p_idx]
              @if str_len(pe) > 0
                p_parts = string_split(pe, "=")
                @if p_parts.len() >= 4
                  p_key = p_parts[0]
                  p_val_str = p_parts[1]
                  p_val_num = string_to_int(p_parts[2])
                  p_is_num = (p_parts[3] == "1")
                  og_set_node_prop(engine, nid, p_key, p_val_str, p_val_num, p_is_num)
                @end
              @end
              p_idx = p_idx + 1
            @end
          @end
        @end
      @end
      i = i + 1
    @end
  @end

  @! Section 2: EDGES
  edge_sec = sections[2]
  edge_prefix = string_split(edge_sec, ":")
  @if edge_prefix.len() >= 2 && str_len(edge_prefix[1]) > 0
    edge_records = string_split(edge_prefix[1], ";")
    j = 0
    @while j < edge_records.len()
      rec = edge_records[j]
      @if str_len(rec) > 0
        fields = string_split(rec, ",")
        @if fields.len() >= 6
          eid = fields[0]
          from_id = fields[1]
          to_id = fields[2]
          elabel = fields[3]
          weight = string_to_int(fields[4])
          is_directed = (fields[5] == "1")
          
          @if is_directed
            og_add_edge(engine, eid, from_id, to_id, elabel, weight)
          @else
            og_add_edge_undirected(engine, eid, from_id, to_id, elabel, weight)
          @end

          @if fields.len() >= 7 && str_len(fields[6]) > 0
            prop_entries = string_split(fields[6], "&")
            ep_idx = 0
            @while ep_idx < prop_entries.len()
              pe = prop_entries[ep_idx]
              @if str_len(pe) > 0
                p_parts = string_split(pe, "=")
                @if p_parts.len() >= 4
                  p_key = p_parts[0]
                  p_val_str = p_parts[1]
                  p_val_num = string_to_int(p_parts[2])
                  p_is_num = (p_parts[3] == "1")
                  og_set_edge_prop(engine, eid, p_key, p_val_str, p_val_num, p_is_num)
                @end
              @end
              ep_idx = ep_idx + 1
            @end
          @end
        @end
      @end
      j = j + 1
    @end
  @end

  return engine
@end

@! Begin ACID Transaction
@fn og_begin_tx(engine: ObjectGraphEngine) -> GraphTransaction
  @if engine.in_tx
    return {
      tx_id: 0,
      state: "ABORTED",
      engine: engine,
      journal: [],
      snapshot_data: ""
    }
  @end

  snap = og_export_snapshot(engine)
  engine.snapshot_stack.push(snap)
  engine.in_tx = true
  engine.current_tx_id = engine.current_tx_id + 1
  engine.tx_journal = []

  return {
    tx_id: engine.current_tx_id,
    state: "ACTIVE",
    engine: engine,
    journal: [],
    snapshot_data: snap
  }
@end

@fn og_begin_transaction(engine: ObjectGraphEngine) -> GraphTransaction
  return og_begin_tx(engine)
@end

@! Commit ACID Transaction
@fn og_commit_tx(engine: ObjectGraphEngine) -> bool
  @if !engine.in_tx
    return false
  @end

  engine.in_tx = false
  engine.tx_journal = []
  @if engine.snapshot_stack.len() > 0
    last_idx = engine.snapshot_stack.len() - 1
    engine.snapshot_stack = array_slice(engine.snapshot_stack, 0, last_idx)
  @end
  return true
@end

@fn og_commit_transaction(tx: GraphTransaction) -> bool
  @if tx.state != "ACTIVE"
    return false
  @end
  tx.state = "COMMITTED"
  eng = tx.engine
  return og_commit_tx(eng)
@end

@! Rollback ACID Transaction
@fn og_rollback_tx(engine: ObjectGraphEngine) -> bool
  @if !engine.in_tx || engine.snapshot_stack.len() == 0
    return false
  @end

  last_idx = engine.snapshot_stack.len() - 1
  snap = engine.snapshot_stack[last_idx]
  restored = og_import_snapshot(snap)

  re = restored
  engine.nodes = re.nodes
  engine.edges = re.edges
  engine.label_index = re.label_index
  engine.prop_index = re.prop_index
  engine.outgoing_adj = re.outgoing_adj
  engine.incoming_adj = re.incoming_adj
  engine.node_count = re.node_count
  engine.edge_count = re.edge_count

  engine.snapshot_stack = array_slice(engine.snapshot_stack, 0, last_idx)
  engine.in_tx = false
  engine.tx_journal = []
  return true
@end

@fn og_rollback_transaction(tx: GraphTransaction) -> bool
  @if tx.state != "ACTIVE"
    return false
  @end
  tx.state = "ABORTED"
  eng = tx.engine
  return og_rollback_tx(eng)
@end

@! ----------------------------------------------------------------------------
@! 8. Distributed Raft Consensus Engine
@! ----------------------------------------------------------------------------

@! Initializes a new Raft consensus node
@fn raft_node_new(node_id: string, peers: array) -> RaftConsensusNode
  return {
    node_id: node_id,
    term: 0,
    state: "FOLLOWER",
    voted_for: "",
    log: [],
    commit_index: 0,
    last_applied: 0,
    peers: peers,
    next_index: [],
    match_index: [],
    state_machine: 0,
    election_timer: 0,
    election_timeout: 150
  }
@end

@! RequestVote RPC Handler
@fn raft_request_vote(node: RaftConsensusNode, term: i64, candidate_id: string, last_log_idx: i64, last_log_term: i64) -> i64
  @if term < node.term
    return 0
  @end

  @if term > node.term
    node.term = term
    node.state = "FOLLOWER"
    node.voted_for = ""
  @end

  can_vote = (node.voted_for == "" || node.voted_for == candidate_id)

  local_last_idx = node.log.len()
  local_last_term = 0
  @if local_last_idx > 0
    last_entry = node.log[local_last_idx - 1]
    local_last_term = last_entry.term
  @end

  log_ok = 0
  @if last_log_term > local_last_term
    log_ok = 1
  @elif last_log_term == local_last_term && last_log_idx >= local_last_idx
    log_ok = 1
  @end

  @if can_vote && log_ok == 1
    node.voted_for = candidate_id
    node.election_timer = 0
    return 1
  @end

  return 0
@end

@! AppendEntries RPC Handler (Log Replication & Heartbeat)
@fn raft_append_entries(node: RaftConsensusNode, term: i64, leader_id: string, prev_log_idx: i64, prev_log_term: i64, entries: array, leader_commit: i64) -> i64
  @if term < node.term
    return 0
  @end

  @if term > node.term || node.state == "CANDIDATE"
    node.term = term
    node.state = "FOLLOWER"
    node.voted_for = ""
  @end
  node.election_timer = 0

  @! Verify log consistency prefix
  @if prev_log_idx > 0
    @if node.log.len() < prev_log_idx
      return 0
    @end
    prev_entry = node.log[prev_log_idx - 1]
    @if prev_entry.term != prev_log_term
      return 0
    @end
  @end

  @! Append / overwrite entries
  i = 0
  @while i < entries.len()
    entry = entries[i]
    target_idx = entry.index
    @if target_idx <= node.log.len()
      existing = node.log[target_idx - 1]
      @if existing.term != entry.term
        node.log = array_slice(node.log, 0, target_idx - 1)
        node.log.push(entry)
      @end
    @else
      node.log.push(entry)
    @end
    i = i + 1
  @end

  @! Update commit index
  @if leader_commit > node.commit_index
    new_commit = leader_commit
    @if node.log.len() < new_commit
      new_commit = node.log.len()
    @end
    node.commit_index = new_commit
  @end

  return 1
@end

@! Elect leader for a node (transition to candidate, vote self)
@fn raft_elect_leader(raft_node: RaftConsensusNode) -> bool
  raft_node.term = raft_node.term + 1
  raft_node.state = "LEADER"
  raft_node.voted_for = raft_node.node_id
  return true
@end

@! Leader replicates command to local log and advances commit
@fn raft_replicate_command(raft_node: RaftConsensusNode, command: string, payload: string) -> bool
  @if raft_node.state != "LEADER"
    return false
  @end

  entry = {
    term: raft_node.term,
    index: raft_node.log.len() + 1,
    command_type: command,
    payload: payload
  }
  raft_node.log.push(entry)
  raft_node.commit_index = entry.index
  return true
@end

@! Apply committed log entries to the ObjectGraphEngine state machine
@fn raft_apply_to_graph(raft_node: RaftConsensusNode, engine: ObjectGraphEngine) -> i64
  applied_count = 0
  @while raft_node.last_applied < raft_node.commit_index
    raft_node.last_applied = raft_node.last_applied + 1
    entry = raft_node.log[raft_node.last_applied - 1]

    @if entry.command_type == "ADD_NODE"
      parts = string_split(entry.payload, ":")
      @if parts.len() >= 2
        og_add_node(engine, parts[0], parts[1])
      @end
    @elif entry.command_type == "ADD_EDGE"
      parts = string_split(entry.payload, ":")
      @if parts.len() >= 5
        w = string_to_int(parts[4])
        og_add_edge(engine, parts[0], parts[1], parts[2], parts[3], w)
      @end
    @elif entry.command_type == "ADD_EDGE_UNDIRECTED"
      parts = string_split(entry.payload, ":")
      @if parts.len() >= 5
        w = string_to_int(parts[4])
        og_add_edge_undirected(engine, parts[0], parts[1], parts[2], parts[3], w)
      @end
    @elif entry.command_type == "SET_PROP"
      parts = string_split(entry.payload, ":")
      @if parts.len() >= 6
        is_num = (parts[5] == "1" || parts[5] == "true")
        val_num = string_to_int(parts[4])
        @if parts[0] == "NODE"
          og_set_node_prop(engine, parts[1], parts[2], parts[3], val_num, is_num)
        @else
          og_set_edge_prop(engine, parts[1], parts[2], parts[3], val_num, is_num)
        @end
      @end
    @elif entry.command_type == "DEL_NODE"
      og_delete_node(engine, entry.payload)
    @elif entry.command_type == "DEL_EDGE"
      og_delete_edge(engine, entry.payload)
    @end

    applied_count = applied_count + 1
  @end

  return applied_count
@end

@! Cluster Simulation: simulate leader election among cluster nodes
@fn raft_simulate_election(nodes: array) -> string
  @if nodes.len() == 0
    return ""
  @end

  candidate = nodes[0]
  candidate.term = candidate.term + 1
  candidate.state = "CANDIDATE"
  candidate.voted_for = candidate.node_id
  votes = 1

  last_idx = candidate.log.len()
  last_term = 0
  @if last_idx > 0
    le = candidate.log[last_idx - 1]
    last_term = le.term
  @end

  i = 1
  @while i < nodes.len()
    peer = nodes[i]
    vote_res = raft_request_vote(peer, candidate.term, candidate.node_id, last_idx, last_term)
    @if vote_res == 1
      votes = votes + 1
    @end
    i = i + 1
  @end

  quorum = (nodes.len() / 2) + 1
  @if votes >= quorum
    candidate.state = "LEADER"
    return candidate.node_id
  @end

  return ""
@end

@! Cluster Simulation: simulate split vote and subsequent recovery with higher term
@fn raft_simulate_split_vote(nodes: array) -> string
  @if nodes.len() < 3
    return ""
  @end

  @! Term 1: Nodes 0 and 1 become candidates simultaneously
  n0 = nodes[0]
  n1 = nodes[1]
  n0.term = 1
  n0.state = "CANDIDATE"
  n0.voted_for = n0.node_id
  
  n1.term = 1
  n1.state = "CANDIDATE"
  n1.voted_for = n1.node_id

  @! Recovery in Term 2: Node 0 times out first and requests votes at term 2
  n0.term = 2
  n0.state = "CANDIDATE"
  n0.voted_for = n0.node_id
  votes = 1

  i = 1
  @while i < nodes.len()
    peer = nodes[i]
    granted = raft_request_vote(peer, 2, n0.node_id, n0.log.len(), 0)
    @if granted == 1
      votes = votes + 1
    @end
    i = i + 1
  @end

  quorum = (nodes.len() / 2) + 1
  @if votes >= quorum
    n0.state = "LEADER"
    return n0.node_id
  @end

  return ""
@end
