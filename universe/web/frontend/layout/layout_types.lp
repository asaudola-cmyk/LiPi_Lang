@! ============================================================================
@! LIPI WEB FRONTEND ENGINE — GPU COMPUTE LAYOUT ENGINE & FLEXBOX SOLVER
@! Module: universe/web/frontend/layout/layout_types.lp
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Features:
@! - Linear GpuLayoutNode structure for WebGPU storage buffers
@! - Complete styling enums & constants (FLEX_ROW, FLEX_ROW_REV, FLEX_COLUMN, FLEX_COLUMN_REV, GRID, etc.)
@! - 6 Justification modes, 5 Alignment modes, 3 Wrap modes, 3 Positioning modes
@! - Layout constraints, EdgeInsets, Rect, LayoutResult, and DirtyBounds
@! - Hierarchical LayoutNode tree representation for declarative UI construction
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"

@! ============================================================================
@! 1. CONSTANTS & ENUMS
@! ============================================================================

@! --- Layout Types ---
@fn LAYOUT_ABSOLUTE()        return 0 @end
@fn LAYOUT_FLEX_ROW()         return 1 @end
@fn LAYOUT_FLEX_ROW_REV()     return 2 @end
@fn LAYOUT_FLEX_COLUMN()      return 3 @end
@fn LAYOUT_FLEX_COLUMN_REV()  return 4 @end
@fn LAYOUT_GRID()             return 5 @end

@fn FLEX_ROW()                return 1 @end
@fn FLEX_ROW_REV()            return 2 @end
@fn FLEX_COLUMN()             return 3 @end
@fn FLEX_COLUMN_REV()         return 4 @end
@fn GRID()                    return 5 @end
@fn ABSOLUTE()                return 0 @end

@! --- Cross-Axis Alignment (align_items) ---
@fn ALIGN_START()             return 0 @end
@fn ALIGN_CENTER()            return 1 @end
@fn ALIGN_END()               return 2 @end
@fn ALIGN_STRETCH()           return 3 @end
@fn ALIGN_BASELINE()          return 4 @end

@! --- Self Alignment (align_self) ---
@fn ALIGN_SELF_AUTO()         return 255 @end
@fn ALIGN_SELF_START()        return 0 @end
@fn ALIGN_SELF_CENTER()       return 1 @end
@fn ALIGN_SELF_END()          return 2 @end
@fn ALIGN_SELF_STRETCH()      return 3 @end
@fn ALIGN_SELF_BASELINE()     return 4 @end

@! --- Main-Axis Justification (justify_content) ---
@fn JUSTIFY_START()           return 0 @end
@fn JUSTIFY_CENTER()          return 1 @end
@fn JUSTIFY_END()             return 2 @end
@fn JUSTIFY_SPACE_BETWEEN()   return 3 @end
@fn JUSTIFY_SPACE_AROUND()    return 4 @end
@fn JUSTIFY_SPACE_EVENLY()    return 5 @end

@! --- Flex Wrap ---
@fn WRAP_NO_WRAP()            return 0 @end
@fn WRAP_WRAP()               return 1 @end
@fn WRAP_WRAP_REVERSE()       return 2 @end

@! --- Positioning Types ---
@fn POSITION_STATIC()         return 0 @end
@fn POSITION_RELATIVE()       return 1 @end
@fn POSITION_ABSOLUTE()       return 2 @end

@! --- Box Sizing ---
@fn BOX_SIZING_CONTENT()      return 0 @end
@fn BOX_SIZING_BORDER()       return 1 @end

@! --- Display ---
@fn DISPLAY_FLEX()            return 0 @end
@fn DISPLAY_GRID()            return 1 @end
@fn DISPLAY_NONE()            return 2 @end

@! --- Overflow ---
@fn OVERFLOW_VISIBLE()        return 0 @end
@fn OVERFLOW_HIDDEN()         return 1 @end
@fn OVERFLOW_SCROLL()         return 2 @end

@! --- Constants for Unset / Root Indices ---
@fn NODE_INDEX_NONE()         return -1 @end
@fn ROOT_PARENT_INDEX()       return 0xFFFFFFFF @end

@! ============================================================================
@! 2. GEOMETRY & BOUNDS DATA STRUCTURES
@! ============================================================================

@struct Rect
  x: i64
  y: i64
  width: i64
  height: i64
@end

@fn rect_new(x, y, w, h)
  return {
    x: x,
    y: y,
    width: w,
    height: h
  }
@end

@struct EdgeInsets
  top: i64
  right: i64
  bottom: i64
  left: i64
@end

@fn edge_insets_all(val)
  return {
    top: val,
    right: val,
    bottom: val,
    left: val
  }
@end

@fn edge_insets_symmetric(vertical, horizontal)
  return {
    top: vertical,
    right: horizontal,
    bottom: vertical,
    left: horizontal
  }
@end

@fn edge_insets_ltrb(left, top, right, bottom)
  return {
    top: top,
    right: right,
    bottom: bottom,
    left: left
  }
@end

@fn edge_insets_zero()
  return {
    top: 0,
    right: 0,
    bottom: 0,
    left: 0
  }
@end

@struct TextMetrics
  font_size: i64
  line_height: i64
  char_width: i64
  baseline_offset: i64
@end

@fn text_metrics_new(font_size, line_height, char_width)
  return {
    font_size: font_size,
    line_height: line_height,
    char_width: char_width,
    baseline_offset: font_size * 8 / 10
  }
@end

@struct LayoutConstraints
  min_width: i64
  max_width: i64
  min_height: i64
  max_height: i64
@end

@fn layout_constraints_new(min_w, max_w, min_h, max_h)
  return {
    min_width: min_w,
    max_width: max_w,
    min_height: min_h,
    max_height: max_h
  }
@end

@fn layout_constraints_loose(max_w, max_h)
  return {
    min_width: 0,
    max_width: max_w,
    min_height: 0,
    max_height: max_h
  }
@end

@fn layout_constraints_tight(w, h)
  return {
    min_width: w,
    max_width: w,
    min_height: h,
    max_height: h
  }
@end

@struct LayoutResult
  x: i64
  y: i64
  width: i64
  height: i64
  node_id: i64
  clip_id: i64
  is_dirty: bool
@end

@fn layout_result_new(node_id, x, y, w, h, clip_id, is_dirty)
  return {
    x: x,
    y: y,
    width: w,
    height: h,
    node_id: node_id,
    clip_id: clip_id,
    is_dirty: is_dirty
  }
@end

@struct DirtyBounds
  min_x: i64
  min_y: i64
  max_x: i64
  max_y: i64
  has_dirty: bool
@end

@fn dirty_bounds_empty()
  return {
    min_x: 0,
    min_y: 0,
    max_x: 0,
    max_y: 0,
    has_dirty: false
  }
@end

@fn dirty_bounds_from_rect(x, y, w, h)
  return {
    min_x: x,
    min_y: y,
    max_x: x + w,
    max_y: y + h,
    has_dirty: true
  }
@end

@fn dirty_bounds_union(b1, b2)
  @if b1.has_dirty == false
    return b2
  @end
  @if b2.has_dirty == false
    return b1
  @end
  
  nx1 = b1.min_x
  @if b2.min_x < nx1 nx1 = b2.min_x @end
  ny1 = b1.min_y
  @if b2.min_y < ny1 ny1 = b2.min_y @end
  nx2 = b1.max_x
  @if b2.max_x > nx2 nx2 = b2.max_x @end
  ny2 = b1.max_y
  @if b2.max_y > ny2 ny2 = b2.max_y @end
  
  return {
    min_x: nx1,
    min_y: ny1,
    max_x: nx2,
    max_y: ny2,
    has_dirty: true
  }
@end

@fn dirty_bounds_union_rect(bounds, x, y, w, h)
  @if bounds.has_dirty == false
    return dirty_bounds_from_rect(x, y, w, h)
  @end
  
  rx2 = x + w
  ry2 = y + h
  
  nx1 = bounds.min_x
  @if x < nx1 nx1 = x @end
  ny1 = bounds.min_y
  @if y < ny1 ny1 = y @end
  nx2 = bounds.max_x
  @if rx2 > nx2 nx2 = rx2 @end
  ny2 = bounds.max_y
  @if ry2 > ny2 ny2 = ry2 @end
  
  return {
    min_x: nx1,
    min_y: ny1,
    max_x: nx2,
    max_y: ny2,
    has_dirty: true
  }
@end

@! ============================================================================
@! 3. HIERARCHICAL LAYOUT NODE (DECLARATIVE TREE REPRESENTATION)
@! ============================================================================

@struct LayoutNode
  x: i64
  y: i64
  width: i64
  height: i64
  id: i64
  node_type: string
  children: array
  layout_type: i64
  position_type: i64
  box_sizing: i64
  align_items: i64
  justify_content: i64
  align_self: i64
  flex_wrap: i64
  flex_grow: i64
  flex_shrink: i64
  flex_basis: i64
  pref_width: i64
  pref_height: i64
  min_width: i64
  min_height: i64
  max_width: i64
  max_height: i64
  padding: i64
  margin: i64
  border_width: i64
  gap: i64
  row_gap: i64
  column_gap: i64
  pos_top: i64
  pos_right: i64
  pos_bottom: i64
  pos_left: i64
  has_pos_top: bool
  has_pos_right: bool
  has_pos_bottom: bool
  has_pos_left: bool
  grid_columns: i64
  grid_col_span: i64
  grid_row_span: i64
  text_content: string
  font_size: i64
  line_height: i64
  node_is_dirty: bool
  clip_id: i64
@end

@fn layout_node_new(id, layout_type, align_items, justify_content)
  return {
    x: 0,
    y: 0,
    width: 0,
    height: 0,
    id: id,
    node_type: "div",
    children: [],
    layout_type: layout_type,
    position_type: POSITION_STATIC(),
    box_sizing: BOX_SIZING_CONTENT(),
    align_items: align_items,
    justify_content: justify_content,
    align_self: ALIGN_SELF_AUTO(),
    flex_wrap: WRAP_NO_WRAP(),
    flex_grow: 0,
    flex_shrink: 1,
    flex_basis: 0,
    pref_width: 0,
    pref_height: 0,
    min_width: 0,
    min_height: 0,
    max_width: 999999,
    max_height: 999999,
    padding: edge_insets_zero(),
    margin: edge_insets_zero(),
    border_width: edge_insets_zero(),
    gap: 0,
    row_gap: 0,
    column_gap: 0,
    pos_top: 0,
    pos_right: 0,
    pos_bottom: 0,
    pos_left: 0,
    has_pos_top: false,
    has_pos_right: false,
    has_pos_bottom: false,
    has_pos_left: false,
    grid_columns: 1,
    grid_col_span: 1,
    grid_row_span: 1,
    text_content: "",
    font_size: 14,
    line_height: 18,
    node_is_dirty: true,
    clip_id: 0
  }
@end

@fn layout_node_add_child(parent, child)
  parent.children = parent.children.push(child)
  return parent
@end

@fn layout_node_set_size(node, w, h)
  node.pref_width = w
  node.pref_height = h
  node.width = w
  node.height = h
  return node
@end

@fn layout_node_set_flex(node, grow, shrink)
  node.flex_grow = grow
  node.flex_shrink = shrink
  return node
@end

@fn layout_node_set_padding(node, top, right, bottom, left)
  node.padding = edge_insets_ltrb(left, top, right, bottom)
  return node
@end

@fn layout_node_set_margin(node, top, right, bottom, left)
  node.margin = edge_insets_ltrb(left, top, right, bottom)
  return node
@end

@fn layout_node_set_gap(node, gap)
  node.gap = gap
  node.row_gap = gap
  node.column_gap = gap
  return node
@end

@! ============================================================================
@! 4. LINEAR GPU LAYOUT NODE DATA STRUCTURE
@! ============================================================================

@struct GpuLayoutNode
  node_id: i64
  parent_idx: i64
  first_child_idx: i64
  next_sibling_idx: i64
  child_count: i64
  layout_type: i64
  align_items: i64
  justify_content: i64
  align_self: i64
  flex_wrap: i64
  position_type: i64
  flex_grow: i64
  flex_shrink: i64
  flex_basis: i64
  min_width: i64
  min_height: i64
  max_width: i64
  max_height: i64
  pref_width: i64
  pref_height: i64
  padding_top: i64
  padding_right: i64
  padding_bottom: i64
  padding_left: i64
  margin_top: i64
  margin_right: i64
  margin_bottom: i64
  margin_left: i64
  gap: i64
  row_gap: i64
  column_gap: i64
  gpu_is_dirty: i64
  clip_id: i64
  depth: i64
  order: i64
  computed_x: i64
  computed_y: i64
  computed_width: i64
  computed_height: i64
  children_indices: array
@end

@fn gpu_layout_node_new(node_id, layout_type, align_items, justify_content)
  return {
    node_id: node_id,
    parent_idx: -1,
    first_child_idx: -1,
    next_sibling_idx: -1,
    child_count: 0,
    layout_type: layout_type,
    align_items: align_items,
    justify_content: justify_content,
    align_self: ALIGN_SELF_AUTO(),
    flex_wrap: WRAP_NO_WRAP(),
    position_type: POSITION_STATIC(),
    flex_grow: 0,
    flex_shrink: 1,
    flex_basis: 0,
    min_width: 0,
    min_height: 0,
    max_width: 999999,
    max_height: 999999,
    pref_width: 0,
    pref_height: 0,
    padding_top: 0,
    padding_right: 0,
    padding_bottom: 0,
    padding_left: 0,
    margin_top: 0,
    margin_right: 0,
    margin_bottom: 0,
    margin_left: 0,
    gap: 0,
    row_gap: 0,
    column_gap: 0,
    gpu_is_dirty: 1,
    clip_id: 0,
    depth: 0,
    order: 0,
    computed_x: 0,
    computed_y: 0,
    computed_width: 0,
    computed_height: 0,
    children_indices: []
  }
@end
