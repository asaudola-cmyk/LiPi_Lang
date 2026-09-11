@! ============================================================================
@! MAYA NATIVE GUI FRAMEWORK — FLEXBOX LAYOUT ENGINE
@! Module: universe/gui/layout.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - Multi-pass Flexbox layout engine
@! - ROW (horizontal flex) and COLUMN (vertical flex) solvers
@! - GRID and ABSOLUTE layout solvers
@! - Padding, margins, and gaps
@! - Cross-axis alignment: START, CENTER, END, STRETCH
@! - Main-axis justification: START, CENTER, END, SPACE_BETWEEN, SPACE_AROUND
@! - Proportional flex grow and flex shrink space distribution
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURE DEFINITIONS
@! ----------------------------------------------------------------------------

@struct LayoutBox
  x: i64
  y: i64
  width: i64
  height: i64
  padding: i64
  margin: i64
  gap: i64
  layout_type: string
  align: string
  justify: string
  flex_grow: i64
  flex_shrink: i64
  columns: i64
  min_w: i64
  min_h: i64
  pref_w: i64
  pref_h: i64
@end

@struct LayoutMeasure
  min_w: i64
  min_h: i64
  pref_w: i64
  pref_h: i64
@end

@! ----------------------------------------------------------------------------
@! 2. CONSTRUCTORS
@! ----------------------------------------------------------------------------

@fn layout_box_new(layout_type, align, justify, gap, padding, margin)
  lt = layout_type
  @if lt == "" || lt == none lt = "ABSOLUTE" @end
  
  al = align
  @if al == "" || al == none al = "START" @end
  
  ju = justify
  @if ju == "" || ju == none ju = "START" @end
  
  return {
    x: 0,
    y: 0,
    width: 0,
    height: 0,
    padding: padding,
    margin: margin,
    gap: gap,
    layout_type: lt,
    align: al,
    justify: ju,
    flex_grow: 0,
    flex_shrink: 1,
    columns: 2,
    min_w: 0,
    min_h: 0,
    pref_w: 0,
    pref_h: 0
  }
@end

@fn layout_measure_new(min_w, min_h, pref_w, pref_h)
  return {
    min_w: min_w,
    min_h: min_h,
    pref_w: pref_w,
    pref_h: pref_h
  }
@end

@! ----------------------------------------------------------------------------
@! 3. INTRINSIC CONTENT MEASUREMENT
@! ----------------------------------------------------------------------------

@fn layout_measure(widget, available_w, available_h)
  @if widget == 0 || widget == none
    return layout_measure_new(0, 0, 0, 0)
  @end
  
  k = widget.kind
  t_len = str_len(widget.text)
  
  @if k == "Button" || k == "button" || k == "IconButton"
    mw = (t_len * 8) + 16
    @if mw < 50 mw = 50 @end
    mh = 28
    return layout_measure_new(mw, mh, mw, mh)
  @elif k == "Label" || k == "label"
    mw = t_len * 8
    mh = 16
    return layout_measure_new(mw, mh, mw, mh)
  @elif k == "TextInput" || k == "input" || k == "TextArea"
    pl_len = str_len(widget.placeholder)
    base_len = t_len
    @if pl_len > base_len base_len = pl_len @end
    mw = (base_len * 8) + 16
    @if mw < 80 mw = 80 @end
    mh = 28
    return layout_measure_new(mw, mh, mw, mh)
  @elif k == "Slider" || k == "slider"
    return layout_measure_new(100, 24, 150, 24)
  @elif k == "ScrollView"
    return layout_measure_new(120, 100, available_w, available_h)
  @elif k == "Window"
    return layout_measure_new(200, 150, widget.width, widget.height)
  @end
  
  min_w = widget.min_w
  @if min_w <= 0 min_w = widget.width @end
  min_h = widget.min_h
  @if min_h <= 0 min_h = widget.height @end
  
  return layout_measure_new(min_w, min_h, min_w, min_h)
@end

@! ----------------------------------------------------------------------------
@! 4. FLEXBOX & MULTI-STRATEGY TOP-DOWN LAYOUT SOLVER
@! ----------------------------------------------------------------------------

@fn layout_solve(widget, origin_x, origin_y, max_w, max_h)
  @if widget == 0 || widget == none
    return widget
  @end
  
  lt = widget.layout_type
  @if lt == "" || lt == none
    lt = "ABSOLUTE"
  @end
  
  @if lt == "ROW"
    return layout_solve_row(widget, origin_x, origin_y, max_w, max_h)
  @elif lt == "COLUMN"
    return layout_solve_column(widget, origin_x, origin_y, max_w, max_h)
  @elif lt == "GRID"
    return layout_solve_grid(widget, origin_x, origin_y, max_w, max_h)
  @else
    return layout_solve_absolute(widget, origin_x, origin_y, max_w, max_h)
  @end
@end

@! --- ROW Layout Solver (Horizontal Flex) ---
@fn layout_solve_row(widget, origin_x, origin_y, max_w, max_h)
  cur_x = origin_x + widget.x
  cur_y = origin_y + widget.y
  
  padding = widget.padding
  margin = widget.margin
  gap = widget.gap
  
  avail_w = widget.width
  @if avail_w <= 0 avail_w = max_w @end
  avail_h = widget.height
  @if avail_h <= 0 avail_h = max_h @end
  
  content_w = avail_w - (2 * (padding + margin))
  @if content_w < 0 content_w = 0 @end
  content_h = avail_h - (2 * (padding + margin))
  @if content_h < 0 content_h = 0 @end
  
  num_children = widget.children.len()
  @if num_children == 0
    @if widget.width <= 0 widget.width = (2 * (padding + margin)) @end
    @if widget.height <= 0 widget.height = (2 * (padding + margin)) @end
    return widget
  @end
  
  fixed_total_w = 0
  flex_grow_sum = 0
  flex_shrink_sum = 0
  max_child_h = 0
  
  i = 0
  @while i < num_children
    ch = widget.children[i]
    meas = layout_measure(ch, content_w, content_h)
    
    ch_w = ch.width
    @if ch_w <= 0
      ch_w = meas.pref_w
      ch.width = ch_w
    @end
    ch_h = ch.height
    @if ch_h <= 0
      ch_h = meas.pref_h
      ch.height = ch_h
    @end
    
    fixed_total_w = fixed_total_w + ch_w
    @if i + 1 < num_children
      fixed_total_w = fixed_total_w + gap
    @end
    
    flex_grow_sum = flex_grow_sum + ch.flex_grow
    flex_shrink_sum = flex_shrink_sum + ch.flex_shrink
    
    @if ch.height > max_child_h
      max_child_h = ch.height
    @end
    
    widget.children[i] = ch
    i = i + 1
  @end
  
  @if content_w > fixed_total_w && flex_grow_sum > 0
    free_w = content_w - fixed_total_w
    i = 0
    @while i < num_children
      ch = widget.children[i]
      @if ch.flex_grow > 0
        extra = (free_w * ch.flex_grow) / flex_grow_sum
        ch.width = ch.width + extra
      @end
      widget.children[i] = ch
      i = i + 1
    @end
    fixed_total_w = content_w
  @elif content_w < fixed_total_w && flex_shrink_sum > 0
    deficit = fixed_total_w - content_w
    i = 0
    @while i < num_children
      ch = widget.children[i]
      @if ch.flex_shrink > 0
        shrink_amt = (deficit * ch.flex_shrink) / flex_shrink_sum
        new_w = ch.width - shrink_amt
        @if new_w < ch.min_w new_w = ch.min_w @end
        ch.width = new_w
      @end
      widget.children[i] = ch
      i = i + 1
    @end
  @end
  
  offset_x = cur_x + padding + margin
  effective_gap = gap
  
  @if flex_grow_sum == 0 && content_w > fixed_total_w
    rem_w = content_w - fixed_total_w
    @if widget.justify == "CENTER"
      offset_x = offset_x + (rem_w / 2)
    @elif widget.justify == "END"
      offset_x = offset_x + rem_w
    @elif widget.justify == "SPACE_BETWEEN" && num_children > 1
      effective_gap = gap + (rem_w / (num_children - 1))
    @elif widget.justify == "SPACE_AROUND" && num_children > 0
      unit = rem_w / (2 * num_children)
      offset_x = offset_x + unit
      effective_gap = gap + (2 * unit)
    @end
  @end
  
  target_h = content_h
  @if max_child_h > target_h target_h = max_child_h @end
  
  new_children = []
  i = 0
  @while i < num_children
    ch = widget.children[i]
    ch_y = cur_y + padding + margin
    
    @if widget.align == "CENTER" && target_h > ch.height
      ch_y = ch_y + ((target_h - ch.height) / 2)
    @elif widget.align == "END" && target_h > ch.height
      ch_y = ch_y + (target_h - ch.height)
    @elif widget.align == "STRETCH"
      ch.height = target_h
    @end
    
    ch.x = offset_x
    ch.y = ch_y
    
    ch = layout_solve(ch, 0, 0, ch.width, ch.height)
    new_children = new_children.push(ch)
    
    offset_x = offset_x + ch.width + effective_gap
    i = i + 1
  @end
  widget.children = new_children
  
  @if widget.width <= 0
    widget.width = fixed_total_w + (2 * (padding + margin))
  @end
  @if widget.height <= 0
    widget.height = target_h + (2 * (padding + margin))
  @end
  
  return widget
@end

@! --- COLUMN Layout Solver (Vertical Flex) ---
@fn layout_solve_column(widget, origin_x, origin_y, max_w, max_h)
  cur_x = origin_x + widget.x
  cur_y = origin_y + widget.y
  
  padding = widget.padding
  margin = widget.margin
  gap = widget.gap
  
  avail_w = widget.width
  @if avail_w <= 0 avail_w = max_w @end
  avail_h = widget.height
  @if avail_h <= 0 avail_h = max_h @end
  
  content_w = avail_w - (2 * (padding + margin))
  @if content_w < 0 content_w = 0 @end
  content_h = avail_h - (2 * (padding + margin))
  @if content_h < 0 content_h = 0 @end
  
  num_children = widget.children.len()
  @if num_children == 0
    @if widget.width <= 0 widget.width = (2 * (padding + margin)) @end
    @if widget.height <= 0 widget.height = (2 * (padding + margin)) @end
    return widget
  @end
  
  fixed_total_h = 0
  flex_grow_sum = 0
  flex_shrink_sum = 0
  max_child_w = 0
  
  i = 0
  @while i < num_children
    ch = widget.children[i]
    meas = layout_measure(ch, content_w, content_h)
    
    ch_w = ch.width
    @if ch_w <= 0
      ch_w = meas.pref_w
      ch.width = ch_w
    @end
    ch_h = ch.height
    @if ch_h <= 0
      ch_h = meas.pref_h
      ch.height = ch_h
    @end
    
    fixed_total_h = fixed_total_h + ch_h
    @if i + 1 < num_children
      fixed_total_h = fixed_total_h + gap
    @end
    
    flex_grow_sum = flex_grow_sum + ch.flex_grow
    flex_shrink_sum = flex_shrink_sum + ch.flex_shrink
    
    @if ch.width > max_child_w
      max_child_w = ch.width
    @end
    
    widget.children[i] = ch
    i = i + 1
  @end
  
  @if content_h > fixed_total_h && flex_grow_sum > 0
    free_h = content_h - fixed_total_h
    i = 0
    @while i < num_children
      ch = widget.children[i]
      @if ch.flex_grow > 0
        extra = (free_h * ch.flex_grow) / flex_grow_sum
        ch.height = ch.height + extra
      @end
      widget.children[i] = ch
      i = i + 1
    @end
    fixed_total_h = content_h
  @elif content_h < fixed_total_h && flex_shrink_sum > 0
    deficit = fixed_total_h - content_h
    i = 0
    @while i < num_children
      ch = widget.children[i]
      @if ch.flex_shrink > 0
        shrink_amt = (deficit * ch.flex_shrink) / flex_shrink_sum
        new_h = ch.height - shrink_amt
        @if new_h < ch.min_h new_h = ch.min_h @end
        ch.height = new_h
      @end
      widget.children[i] = ch
      i = i + 1
    @end
  @end
  
  offset_y = cur_y + padding + margin
  effective_gap = gap
  
  @if flex_grow_sum == 0 && content_h > fixed_total_h
    rem_h = content_h - fixed_total_h
    @if widget.justify == "CENTER"
      offset_y = offset_y + (rem_h / 2)
    @elif widget.justify == "END"
      offset_y = offset_y + rem_h
    @elif widget.justify == "SPACE_BETWEEN" && num_children > 1
      effective_gap = gap + (rem_h / (num_children - 1))
    @elif widget.justify == "SPACE_AROUND" && num_children > 0
      unit = rem_h / (2 * num_children)
      offset_y = offset_y + unit
      effective_gap = gap + (2 * unit)
    @end
  @end
  
  target_w = content_w
  @if max_child_w > target_w target_w = max_child_w @end
  
  new_children = []
  i = 0
  @while i < num_children
    ch = widget.children[i]
    ch_x = cur_x + padding + margin
    
    @if widget.align == "CENTER" && target_w > ch.width
      ch_x = ch_x + ((target_w - ch.width) / 2)
    @elif widget.align == "END" && target_w > ch.width
      ch_x = ch_x + (target_w - ch.width)
    @elif widget.align == "STRETCH"
      ch.width = target_w
    @end
    
    ch.x = ch_x
    ch.y = offset_y
    
    ch = layout_solve(ch, 0, 0, ch.width, ch.height)
    new_children = new_children.push(ch)
    
    offset_y = offset_y + ch.height + effective_gap
    i = i + 1
  @end
  widget.children = new_children
  
  @if widget.width <= 0
    widget.width = fixed_total_h + (2 * (padding + margin))
  @end
  @if widget.height <= 0
    widget.height = target_w + (2 * (padding + margin))
  @end
  
  return widget
@end

@! --- GRID Layout Solver ---
@fn layout_solve_grid(widget, origin_x, origin_y, max_w, max_h)
  cur_x = origin_x + widget.x
  cur_y = origin_y + widget.y
  
  padding = widget.padding
  margin = widget.margin
  gap = widget.gap
  
  avail_w = widget.width
  @if avail_w <= 0 avail_w = max_w @end
  avail_h = widget.height
  @if avail_h <= 0 avail_h = max_h @end
  
  content_w = avail_w - (2 * (padding + margin))
  @if content_w < 0 content_w = 0 @end
  
  cols = widget.columns
  @if cols <= 0 cols = 2 @end
  
  num_children = widget.children.len()
  fixed_w = 0
  @if num_children > 0
    first_c = widget.children[0]
    @if first_c.width > 0
      fixed_w = first_c.width
    @end
  @end
  
  col_w = (content_w - ((cols - 1) * gap)) / cols
  @if fixed_w > 0
    col_w = fixed_w
  @elif col_w <= 0
    col_w = 40
  @end
  
  new_children = []
  i = 0
  max_total_h = 0
  
  @while i < num_children
    ch = widget.children[i]
    row_idx = i / cols
    col_idx = i % cols
    
    gx = cur_x + padding + margin + (col_idx * (col_w + gap))
    gy = cur_y + padding + margin + (row_idx * (ch.height + gap))
    
    ch.x = gx
    ch.y = gy
    ch.width = col_w
    
    ch = layout_solve(ch, 0, 0, col_w, ch.height)
    new_children = new_children.push(ch)
    
    cell_bottom = (row_idx + 1) * (ch.height + gap)
    @if cell_bottom > max_total_h max_total_h = cell_bottom @end
    
    i = i + 1
  @end
  widget.children = new_children
  
  @if widget.width <= 0
    widget.width = avail_w
  @end
  @if widget.height <= 0
    widget.height = max_total_h + (2 * (padding + margin))
  @end
  
  return widget
@end

@! --- ABSOLUTE Layout Solver ---
@fn layout_solve_absolute(widget, origin_x, origin_y, max_w, max_h)
  cur_x = origin_x + widget.x
  cur_y = origin_y + widget.y
  
  num_children = widget.children.len()
  new_children = []
  i = 0
  @while i < num_children
    ch = widget.children[i]
    ch = layout_solve(ch, cur_x, cur_y, ch.width, ch.height)
    new_children = new_children.push(ch)
    i = i + 1
  @end
  widget.children = new_children
  
  return widget
@end
