@! ============================================================================
@! MAYA UNIVERSE - NATIVE OBJECT-GRAPH DATABASE ENGINE
@! Bypasses traditional SQL for a direct memory-mapped graph relationship
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct GraphNode
  id: i64
  label: string
@end

@struct GraphEdge
  source_id: i64
  target_id: i64
  relation: string
@end

@struct GraphEngine
  nodes: array
  edges: array
  next_id: i64
@end

@fn graph_engine_new()
  return { nodes: [], edges: [], next_id: 1 }
@end

@fn graph_add_node(engine, label)
  node = { id: engine.next_id, label: label }
  engine.next_id = engine.next_id + 1
  array_push(engine.nodes, node)
  return node.id
@end

@fn graph_link(engine, src_id, tgt_id, relation)
  edge = { source_id: src_id, target_id: tgt_id, relation: relation }
  array_push(engine.edges, edge)
  return 1
@end

@fn graph_query_neighbors(engine, node_id, relation_filter)
  results = []
  i = 0
  n = array_len(engine.edges)
  @while i < n
    edge = array_get(engine.edges, i)
    @if edge.source_id == node_id
      @if relation_filter == "" || edge.relation == relation_filter
        array_push(results, edge.target_id)
      @end
    @end
    i = i + 1
  @end
  return results
@end
