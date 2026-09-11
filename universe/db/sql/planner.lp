@! ============================================================================
@! LIPI UNIVERSE DB - SQL PLANNER (universe/db/sql/planner.maya)
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@struct PlanNode
  node_type: "",
  table: "",
  filter_expr: 0,
  projections: [],
  cost: 0.0,
  left_child: 0,
  right_child: 0
@end

@struct Planner
  table_stats: {}
@end

@fn new_planner()
  return {
    table_stats: {}
  }
@end

@fn create_logical_plan(ast)
  @if ast == 0
    return 0
  @end

  @if ast.type == "SelectStmt"
    scan_node = {
      node_type: "SCAN",
      table: ast.from_table,
      filter_expr: ast.where_clause,
      projections: [],
      cost: 10.0,
      left_child: 0,
      right_child: 0
    }
    
    @if ast.where_clause != 0
      filter_node = {
        node_type: "FILTER",
        table: ast.from_table,
        filter_expr: ast.where_clause,
        projections: [],
        cost: 15.0,
        left_child: scan_node,
        right_child: 0
      }
      proj_node = {
        node_type: "PROJECT",
        table: ast.from_table,
        filter_expr: 0,
        projections: ast.columns,
        cost: 20.0,
        left_child: filter_node,
        right_child: 0
      }
      return proj_node
    @end

    proj_node = {
      node_type: "PROJECT",
      table: ast.from_table,
      filter_expr: 0,
      projections: ast.columns,
      cost: 12.0,
      left_child: scan_node,
      right_child: 0
    }
    return proj_node
  @end

  return {
    node_type: ast.type,
    table: "",
    filter_expr: 0,
    projections: [],
    cost: 5.0,
    left_child: 0,
    right_child: 0
  }
@end

@fn estimate_cost(plan_node)
  @if plan_node == 0
    return 0.0
  @end

  base_cost = plan_node.cost
  left_cost = 0.0
  right_cost = 0.0

  @if plan_node.left_child != 0
    left_cost = estimate_cost(plan_node.left_child)
  @end
  @if plan_node.right_child != 0
    right_cost = estimate_cost(plan_node.right_child)
  @end

  return base_cost + left_cost + right_cost
@end

@fn optimize_join_order(relations, stats)
  @if relations.len() <= 1
    return relations
  @end

  ordered = []
  i = 0
  @while i < relations.len()
    ordered = ordered.push(relations[i])
    i = i + 1
  @end

  n = ordered.len()
  i = 0
  @while i < n - 1
    j = 0
    @while j < n - i - 1
      r1 = ordered[j]
      r2 = ordered[j + 1]
      c1 = 100
      c2 = 100
      @if stats != 0
        @if stats.contains(r1) c1 = stats[r1] @end
        @if stats.contains(r2) c2 = stats[r2] @end
      @end
      @if c1 > c2
        tmp = ordered[j]
        ordered[j] = ordered[j + 1]
        ordered[j + 1] = tmp
      @end
      j = j + 1
    @end
    i = i + 1
  @end

  return ordered
@end