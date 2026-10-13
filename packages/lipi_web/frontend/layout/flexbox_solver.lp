@! ============================================================================
@! LIPI WEB FRONTEND ENGINE — HIGH-PRECISION CPU FLEXBOX & GRID SOLVER (F10)
@! Module: universe/web/frontend/layout/flexbox_solver.lp
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Features:
@! - High-precision 7-pass integer-conserving flexbox and grid layout solver
@! - Multi-strategy solvers: ROW, ROW_REV, COLUMN, COLUMN_REV, GRID, ABSOLUTE
@! - 6 Justification modes with exact Bresenham integer gap distribution
@! - 5 Cross-axis alignment modes (START, CENTER, END, STRETCH, BASELINE) & ALIGN_SELF
@! - Dynamic flex grow & shrink distribution with min/max clamping & remainder conservation
@! - Multi-line flex wrapping (WRAP, WRAP_REVERSE) & intrinsic text measurement
@! - Static, Relative, and Absolute positioning with offset constraints
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"
import "universe/web/frontend/layout/layout_types"

@! ============================================================================
@! 1. INTRINSIC MEASUREMENT
@! ============================================================================

@fn flexbox_measure_node(node, available_w, available_h)
  pad_h = node.padding.left + node.padding.right
  pad_v = node.padding.top + node.padding.bottom
  
  w = node.pref_width
  h = node.pref_height
  
  @! Intrinsic text measurement
  @if str_len(node.text_content) > 0
    t_len = str_len(node.text_content)
    char_w = 7
    char_h = 14
    @if node.font_size > 0
      char_w = node.font_size * 7 / 10
      @if char_w < 4 char_w = 4 @end
      char_h = node.font_size * 12 / 10
    @end
    
    @if w <= 0 w = (t_len * char_w) + pad_h @end
    @if h <= 0 h = char_h + pad_v @end
  @end
  
  @if w <= 0 && node.children.len() == 0
    w = pad_h
  @end
  @if h <= 0 && node.children.len() == 0
    h = pad_v
  @end
  
  @if node.min_width > 0 && w < node.min_width w = node.min_width @end
  @if node.max_width > 0 && w > node.max_width w = node.max_width @end
  @if node.min_height > 0 && h < node.min_height h = node.min_height @end
  @if node.max_height > 0 && h > node.max_height h = node.max_height @end
  
  return rect_new(0, 0, w, h)
@end

@! ============================================================================
@! 2. ROW LAYOUT SOLVER (HORIZONTAL FLEX: ROW & ROW_REV)
@! ============================================================================

@fn flexbox_solve_row(node, origin_x, origin_y, max_w, max_h)
  pad_left = node.padding.left
  pad_right = node.padding.right
  pad_top = node.padding.top
  pad_bottom = node.padding.bottom
  
  mar_left = node.margin.left
  mar_right = node.margin.right
  mar_top = node.margin.top
  mar_bottom = node.margin.bottom
  
  gap = node.gap
  @if node.column_gap > 0 gap = node.column_gap @end
  row_gap = node.row_gap
  @if row_gap <= 0 row_gap = gap @end
  
  cur_x = origin_x + mar_left
  cur_y = origin_y + mar_top
  
  avail_w = node.pref_width
  @if avail_w <= 0 avail_w = max_w - (mar_left + mar_right) @end
  avail_h = node.pref_height
  @if avail_h <= 0 avail_h = max_h - (mar_top + mar_bottom) @end
  
  content_w = avail_w - (pad_left + pad_right)
  @if content_w < 0 content_w = 0 @end
  content_h = avail_h - (pad_top + pad_bottom)
  @if content_h < 0 content_h = 0 @end
  
  num_children = node.children.len()
  @if num_children == 0
    @if node.width <= 0 node.width = pad_left + pad_right @end
    @if node.height <= 0 node.height = pad_top + pad_bottom @end
    node.x = cur_x
    node.y = cur_y
    return node
  @end
  
  @! Separate normal flow children from absolute positioned children
  normal_children = []
  abs_children = []
  i = 0
  @while i < num_children
    ch = node.children[i]
    @if ch.position_type == POSITION_ABSOLUTE()
      abs_children = abs_children.push(ch)
    @else
      normal_children = normal_children.push(ch)
    @end
    i = i + 1
  @end
  
  @! Reverse order for ROW_REV
  @if node.layout_type == LAYOUT_FLEX_ROW_REV()
    rev_norm = []
    ri = normal_children.len() - 1
    @while ri >= 0
      rev_norm = rev_norm.push(normal_children[ri])
      ri = ri - 1
    @end
    normal_children = rev_norm
  @end
  
  norm_count = normal_children.len()
  
  @! Measure all normal children
  i = 0
  @while i < norm_count
    ch = normal_children[i]
    meas = flexbox_measure_node(ch, content_w, content_h)
    
    @if ch.pref_width > 0
      ch.width = ch.pref_width
    @else
      ch.width = meas.width
    @end
    @if ch.min_width > 0 && ch.width < ch.min_width ch.width = ch.min_width @end
    @if ch.max_width > 0 && ch.width > ch.max_width ch.width = ch.max_width @end
    
    @if ch.pref_height > 0
      ch.height = ch.pref_height
    @else
      ch.height = meas.height
    @end
    @if ch.min_height > 0 && ch.height < ch.min_height ch.height = ch.min_height @end
    @if ch.max_height > 0 && ch.height > ch.max_height ch.height = ch.max_height @end
    
    normal_children[i] = ch
    i = i + 1
  @end
  
  @! Partition into Flex Lines if wrapping is enabled
  lines = []
  @if (node.flex_wrap == WRAP_WRAP() || node.flex_wrap == WRAP_WRAP_REVERSE()) && norm_count > 0
    cur_line = []
    line_w = 0
    i = 0
    @while i < norm_count
      ch = normal_children[i]
      item_w = ch.width + ch.margin.left + ch.margin.right
      @if cur_line.len() > 0
        item_w = item_w + gap
      @end
      
      @if cur_line.len() > 0 && line_w + item_w > content_w
        lines = lines.push(cur_line)
        cur_line = [ch]
        line_w = ch.width + ch.margin.left + ch.margin.right
      @else
        cur_line = cur_line.push(ch)
        line_w = line_w + item_w
      @end
      i = i + 1
    @end
    @if cur_line.len() > 0
      lines = lines.push(cur_line)
    @end
  @else
    lines = [normal_children]
  @end
  
  @if node.flex_wrap == WRAP_WRAP_REVERSE()
    rev_lines = []
    li = lines.len() - 1
    @while li >= 0
      rev_lines = rev_lines.push(lines[li])
      li = li - 1
    @end
    lines = rev_lines
  @end
  
  @! Process each Flex Line
  line_y = cur_y + pad_top
  total_content_h = 0
  max_line_w = 0
  solved_children = []
  
  line_idx = 0
  num_lines = lines.len()
  @while line_idx < num_lines
    line_items = lines[line_idx]
    line_item_count = line_items.len()
    
    @if line_item_count > 0
      fixed_w = 0
      grow_sum = 0
      shrink_sum = 0
      line_max_h = 0
      
      i = 0
      @while i < line_item_count
        ch = line_items[i]
        item_outer_w = ch.width + ch.margin.left + ch.margin.right
        fixed_w = fixed_w + item_outer_w
        @if i + 1 < line_item_count
          fixed_w = fixed_w + gap
        @end
        
        grow_sum = grow_sum + ch.flex_grow
        shrink_sum = shrink_sum + ch.flex_shrink
        
        item_outer_h = ch.height + ch.margin.top + ch.margin.bottom
        @if item_outer_h > line_max_h
          line_max_h = item_outer_h
        @end
        i = i + 1
      @end
      
      @! Flex Grow Space Distribution (Integer exact remainder conservation)
      @if content_w > fixed_w && grow_sum > 0
        rem_free = content_w - fixed_w
        rem_grow = grow_sum
        i = 0
        @while i < line_item_count
          ch = line_items[i]
          @if ch.flex_grow > 0 && rem_grow > 0
            add_w = (rem_free * ch.flex_grow) / rem_grow
            rem_free = rem_free - add_w
            rem_grow = rem_grow - ch.flex_grow
            new_w = ch.width + add_w
            @if ch.max_width > 0 && new_w > ch.max_width new_w = ch.max_width @end
            ch.width = new_w
          @end
          line_items[i] = ch
          i = i + 1
        @end
        fixed_w = content_w
      @elif content_w < fixed_w && shrink_sum > 0
        @! Flex Shrink Space Distribution (Integer deficit conservation)
        rem_deficit = fixed_w - content_w
        rem_shrink = shrink_sum
        i = 0
        @while i < line_item_count
          ch = line_items[i]
          @if ch.flex_shrink > 0 && rem_shrink > 0
            sub_w = (rem_deficit * ch.flex_shrink) / rem_shrink
            rem_deficit = rem_deficit - sub_w
            rem_shrink = rem_shrink - ch.flex_shrink
            new_w = ch.width - sub_w
            @if new_w < ch.min_width new_w = ch.min_width @end
            ch.width = new_w
          @end
          line_items[i] = ch
          i = i + 1
        @end
      @end
      
      @! Main Axis Justification with Bresenham Gap Distribution
      start_x = cur_x + pad_left
      eff_gap = gap
      rem_w = content_w - fixed_w
      @if rem_w < 0 rem_w = 0 @end
      
      gap_extra = 0
      gap_rem = 0
      
      @if grow_sum <= 0 && rem_w > 0
        @if node.justify_content == JUSTIFY_CENTER()
          start_x = start_x + (rem_w / 2)
        @elif node.justify_content == JUSTIFY_END()
          start_x = start_x + rem_w
        @elif node.justify_content == JUSTIFY_SPACE_BETWEEN() && line_item_count > 1
          k = line_item_count - 1
          eff_gap = gap + (rem_w / k)
          gap_rem = rem_w % k
        @elif node.justify_content == JUSTIFY_SPACE_AROUND() && line_item_count > 0
          k = line_item_count
          half_unit = rem_w / (2 * k)
          start_x = start_x + half_unit
          eff_gap = gap + (2 * half_unit)
          gap_rem = rem_w % (2 * k)
        @elif node.justify_content == JUSTIFY_SPACE_EVENLY() && line_item_count > 0
          k = line_item_count + 1
          unit = rem_w / k
          start_x = start_x + unit
          eff_gap = gap + unit
          gap_rem = rem_w % k
        @end
      @end
      
      target_line_h = line_max_h
      @if num_lines == 1 && content_h > target_line_h
        target_line_h = content_h
      @end
      
      @! Position items along line
      item_x = start_x
      i = 0
      @while i < line_item_count
        ch = line_items[i]
        ch_item_x = item_x + ch.margin.left
        ch_item_y = line_y + ch.margin.top
        
        effective_align = node.align_items
        @if ch.align_self != ALIGN_SELF_AUTO()
          effective_align = ch.align_self
        @end
        
        @if effective_align == ALIGN_CENTER()
          ch_item_y = line_y + ((target_line_h - (ch.height + ch.margin.top + ch.margin.bottom)) / 2) + ch.margin.top
        @elif effective_align == ALIGN_END()
          ch_item_y = line_y + target_line_h - (ch.height + ch.margin.bottom)
        @elif effective_align == ALIGN_STRETCH()
          ch.height = target_line_h - (ch.margin.top + ch.margin.bottom)
          @if ch.height < ch.min_height ch.height = ch.min_height @end
          @if ch.height > ch.max_height ch.height = ch.max_height @end
        @end
        
        @! Relative positioning offsets
        @if ch.position_type == POSITION_RELATIVE()
          @if ch.has_pos_left ch_item_x = ch_item_x + ch.pos_left @end
          @if ch.has_pos_top ch_item_y = ch_item_y + ch.pos_top @end
        @end
        
        ch.x = ch_item_x
        ch.y = ch_item_y
        
        @! Recursively solve child subtree
        solve_w = ch.width
        @if solve_w <= 0 solve_w = ch.pref_width @end
        solve_h = ch.height
        @if solve_h <= 0 solve_h = target_line_h - (ch.margin.top + ch.margin.bottom) @end
        ch = flexbox_solve_node(ch, ch.x, ch.y, solve_w, solve_h)
        @if ch.width <= 0 ch.width = solve_w @end
        @if ch.height <= 0 ch.height = solve_h @end
        solved_children = solved_children.push(ch)
        
        cur_step_gap = eff_gap
        @if i < gap_rem
          cur_step_gap = cur_step_gap + 1
        @end
        
        item_x = item_x + ch.width + ch.margin.left + ch.margin.right + cur_step_gap
        i = i + 1
      @end
      
      line_y = line_y + target_line_h + row_gap
      total_content_h = total_content_h + target_line_h
      @if line_idx + 1 < num_lines
        total_content_h = total_content_h + row_gap
      @end
      
      @if fixed_w > max_line_w max_line_w = fixed_w @end
    @end
    line_idx = line_idx + 1
  @end
  
  @! Process Absolute Positioned Children
  i = 0
  abs_count = abs_children.len()
  @while i < abs_count
    ach = abs_children[i]
    ach_x = cur_x + pad_left + ach.margin.left
    ach_y = cur_y + pad_top + ach.margin.top
    
    @if ach.has_pos_left ach_x = cur_x + pad_left + ach.pos_left @end
    @if ach.has_pos_right ach_x = (cur_x + avail_w) - (pad_right + ach.pref_width + ach.pos_right) @end
    @if ach.has_pos_top ach_y = cur_y + pad_top + ach.pos_top @end
    @if ach.has_pos_bottom ach_y = (cur_y + avail_h) - (pad_bottom + ach.pref_height + ach.pos_bottom) @end
    
    meas = flexbox_measure_node(ach, content_w, content_h)
    @if ach.pref_width > 0 ach.width = ach.pref_width @else ach.width = meas.width @end
    @if ach.pref_height > 0 ach.height = ach.pref_height @else ach.height = meas.height @end
    
    ach.x = ach_x
    ach.y = ach_y
    ach = flexbox_solve_node(ach, ach.x, ach.y, ach.width, ach.height)
    solved_children = solved_children.push(ach)
    i = i + 1
  @end
  
  node.children = solved_children
  
  @if node.pref_width > 0
    node.width = node.pref_width
  @elif node.width <= 0
    @if max_w > 0
      node.width = max_w
    @else
      node.width = max_line_w + pad_left + pad_right
    @end
  @end
  @if node.pref_height > 0
    node.height = node.pref_height
  @elif node.height <= 0
    @if max_h > 0
      node.height = max_h
    @else
      node.height = total_content_h + pad_top + pad_bottom
    @end
  @end
  
  node.x = cur_x
  node.y = cur_y
  return node
@end

@! ============================================================================
@! 3. COLUMN LAYOUT SOLVER (VERTICAL FLEX: COLUMN & COLUMN_REV)
@! ============================================================================

@fn flexbox_solve_column(node, origin_x, origin_y, max_w, max_h)
  pad_left = node.padding.left
  pad_right = node.padding.right
  pad_top = node.padding.top
  pad_bottom = node.padding.bottom
  
  mar_left = node.margin.left
  mar_right = node.margin.right
  mar_top = node.margin.top
  mar_bottom = node.margin.bottom
  
  gap = node.gap
  @if node.row_gap > 0 gap = node.row_gap @end
  col_gap = node.column_gap
  @if col_gap <= 0 col_gap = gap @end
  
  cur_x = origin_x + mar_left
  cur_y = origin_y + mar_top
  
  avail_w = node.pref_width
  @if avail_w <= 0 avail_w = max_w - (mar_left + mar_right) @end
  avail_h = node.pref_height
  @if avail_h <= 0 avail_h = max_h - (mar_top + mar_bottom) @end
  
  content_w = avail_w - (pad_left + pad_right)
  @if content_w < 0 content_w = 0 @end
  content_h = avail_h - (pad_top + pad_bottom)
  @if content_h < 0 content_h = 0 @end
  
  num_children = node.children.len()
  @if num_children == 0
    @if node.width <= 0 node.width = pad_left + pad_right @end
    @if node.height <= 0 node.height = pad_top + pad_bottom @end
    node.x = cur_x
    node.y = cur_y
    return node
  @end
  
  @! Separate normal flow from absolute children
  normal_children = []
  abs_children = []
  i = 0
  @while i < num_children
    ch = node.children[i]
    @if ch.position_type == POSITION_ABSOLUTE()
      abs_children = abs_children.push(ch)
    @else
      normal_children = normal_children.push(ch)
    @end
    i = i + 1
  @end
  
  @! Reverse order for COLUMN_REV
  @if node.layout_type == LAYOUT_FLEX_COLUMN_REV()
    rev_norm = []
    ri = normal_children.len() - 1
    @while ri >= 0
      rev_norm = rev_norm.push(normal_children[ri])
      ri = ri - 1
    @end
    normal_children = rev_norm
  @end
  
  norm_count = normal_children.len()
  
  @! Measure all normal children
  i = 0
  @while i < norm_count
    ch = normal_children[i]
    meas = flexbox_measure_node(ch, content_w, content_h)
    
    @if ch.pref_width > 0
      ch.width = ch.pref_width
    @else
      ch.width = meas.width
    @end
    @if ch.width < ch.min_width ch.width = ch.min_width @end
    @if ch.width > ch.max_width ch.width = ch.max_width @end
    
    @if ch.pref_height > 0
      ch.height = ch.pref_height
    @else
      ch.height = meas.height
    @end
    @if ch.height < ch.min_height ch.height = ch.min_height @end
    @if ch.height > ch.max_height ch.height = ch.max_height @end
    
    normal_children[i] = ch
    i = i + 1
  @end
  
  @! Handle wrapping for columns
  lines = []
  @if (node.flex_wrap == WRAP_WRAP() || node.flex_wrap == WRAP_WRAP_REVERSE()) && norm_count > 0
    cur_col = []
    col_h = 0
    i = 0
    @while i < norm_count
      ch = normal_children[i]
      item_h = ch.height + ch.margin.top + ch.margin.bottom
      @if cur_col.len() > 0
        item_h = item_h + gap
      @end
      
      @if cur_col.len() > 0 && col_h + item_h > content_h
        lines = lines.push(cur_col)
        cur_col = [ch]
        col_h = ch.height + ch.margin.top + ch.margin.bottom
      @else
        cur_col = cur_col.push(ch)
        col_h = col_h + item_h
      @end
      i = i + 1
    @end
    @if cur_col.len() > 0
      lines = lines.push(cur_col)
    @end
  @else
    lines = [normal_children]
  @end
  
  @if node.flex_wrap == WRAP_WRAP_REVERSE()
    rev_lines = []
    li = lines.len() - 1
    @while li >= 0
      rev_lines = rev_lines.push(lines[li])
      li = li - 1
    @end
    lines = rev_lines
  @end
  
  line_x = cur_x + pad_left
  total_content_w = 0
  max_line_h = 0
  solved_children = []
  
  line_idx = 0
  num_lines = lines.len()
  @while line_idx < num_lines
    line_items = lines[line_idx]
    line_item_count = line_items.len()
    
    @if line_item_count > 0
      fixed_h = 0
      grow_sum = 0
      shrink_sum = 0
      line_max_w = 0
      
      i = 0
      @while i < line_item_count
        ch = line_items[i]
        item_outer_h = ch.height + ch.margin.top + ch.margin.bottom
        fixed_h = fixed_h + item_outer_h
        @if i + 1 < line_item_count
          fixed_h = fixed_h + gap
        @end
        
        grow_sum = grow_sum + ch.flex_grow
        shrink_sum = shrink_sum + ch.flex_shrink
        
        item_outer_w = ch.width + ch.margin.left + ch.margin.right
        @if item_outer_w > line_max_w
          line_max_w = item_outer_w
        @end
        i = i + 1
      @end
      
      @! Flex Grow Distribution along Main Axis (Y) with Integer Conservation
      @if content_h > fixed_h && grow_sum > 0
        rem_free = content_h - fixed_h
        rem_grow = grow_sum
        i = 0
        @while i < line_item_count
          ch = line_items[i]
          @if ch.flex_grow > 0 && rem_grow > 0
            add_h = (rem_free * ch.flex_grow) / rem_grow
            rem_free = rem_free - add_h
            rem_grow = rem_grow - ch.flex_grow
            new_h = ch.height + add_h
            @if new_h > ch.max_height new_h = ch.max_height @end
            ch.height = new_h
          @end
          line_items[i] = ch
          i = i + 1
        @end
        fixed_h = content_h
      @elif content_h < fixed_h && shrink_sum > 0
        @! Flex Shrink Distribution along Main Axis (Y)
        rem_deficit = fixed_h - content_h
        rem_shrink = shrink_sum
        i = 0
        @while i < line_item_count
          ch = line_items[i]
          @if ch.flex_shrink > 0 && rem_shrink > 0
            sub_h = (rem_deficit * ch.flex_shrink) / rem_shrink
            rem_deficit = rem_deficit - sub_h
            rem_shrink = rem_shrink - ch.flex_shrink
            new_h = ch.height - sub_h
            @if new_h < ch.min_height new_h = ch.min_height @end
            ch.height = new_h
          @end
          line_items[i] = ch
          i = i + 1
        @end
      @end
      
      @! Main Axis Justification (Y) with Bresenham Gap Distribution
      start_y = cur_y + pad_top
      eff_gap = gap
      rem_h = content_h - fixed_h
      @if rem_h < 0 rem_h = 0 @end
      
      gap_rem = 0
      
      @if grow_sum <= 0 && rem_h > 0
        @if node.justify_content == JUSTIFY_CENTER()
          start_y = start_y + (rem_h / 2)
        @elif node.justify_content == JUSTIFY_END()
          start_y = start_y + rem_h
        @elif node.justify_content == JUSTIFY_SPACE_BETWEEN() && line_item_count > 1
          k = line_item_count - 1
          eff_gap = gap + (rem_h / k)
          gap_rem = rem_h % k
        @elif node.justify_content == JUSTIFY_SPACE_AROUND() && line_item_count > 0
          k = line_item_count
          half_unit = rem_h / (2 * k)
          start_y = start_y + half_unit
          eff_gap = gap + (2 * half_unit)
          gap_rem = rem_h % (2 * k)
        @elif node.justify_content == JUSTIFY_SPACE_EVENLY() && line_item_count > 0
          k = line_item_count + 1
          unit = rem_h / k
          start_y = start_y + unit
          eff_gap = gap + unit
          gap_rem = rem_h % k
        @end
      @end
      
      target_line_w = line_max_w
      @if num_lines == 1 && content_w > target_line_w
        target_line_w = content_w
      @end
      
      @! Position items along column
      item_y = start_y
      i = 0
      @while i < line_item_count
        ch = line_items[i]
        ch_item_x = line_x + ch.margin.left
        ch_item_y = item_y + ch.margin.top
        
        effective_align = node.align_items
        @if ch.align_self != ALIGN_SELF_AUTO()
          effective_align = ch.align_self
        @end
        
        @if effective_align == ALIGN_CENTER()
          ch_item_x = line_x + ((target_line_w - (ch.width + ch.margin.left + ch.margin.right)) / 2) + ch.margin.left
        @elif effective_align == ALIGN_END()
          ch_item_x = line_x + target_line_w - (ch.width + ch.margin.right)
        @elif effective_align == ALIGN_STRETCH()
          ch.width = target_line_w - (ch.margin.left + ch.margin.right)
          @if ch.width < ch.min_width ch.width = ch.min_width @end
          @if ch.width > ch.max_width ch.width = ch.max_width @end
        @end
        
        @! Relative positioning offsets
        @if ch.position_type == POSITION_RELATIVE()
          @if ch.has_pos_left ch_item_x = ch_item_x + ch.pos_left @end
          @if ch.has_pos_top ch_item_y = ch_item_y + ch.pos_top @end
        @end
        
        ch.x = ch_item_x
        ch.y = ch_item_y
        
        @! Recursively solve child subtree
        solve_w = ch.width
        @if solve_w <= 0 solve_w = target_line_w - (ch.margin.left + ch.margin.right) @end
        solve_h = ch.height
        @if solve_h <= 0 solve_h = ch.pref_height @end
        ch = flexbox_solve_node(ch, ch.x, ch.y, solve_w, solve_h)
        @if ch.width <= 0 ch.width = solve_w @end
        solved_children = solved_children.push(ch)
        
        cur_step_gap = eff_gap
        @if i < gap_rem
          cur_step_gap = cur_step_gap + 1
        @end
        
        item_y = item_y + ch.height + ch.margin.top + ch.margin.bottom + cur_step_gap
        i = i + 1
      @end
      
      line_x = line_x + target_line_w + col_gap
      total_content_w = total_content_w + target_line_w
      @if line_idx + 1 < num_lines
        total_content_w = total_content_w + col_gap
      @end
      
      @if fixed_h > max_line_h max_line_h = fixed_h @end
    @end
    line_idx = line_idx + 1
  @end
  
  @! Process Absolute Children
  i = 0
  abs_count = abs_children.len()
  @while i < abs_count
    ach = abs_children[i]
    ach_x = cur_x + pad_left + ach.margin.left
    ach_y = cur_y + pad_top + ach.margin.top
    
    @if ach.has_pos_left ach_x = cur_x + pad_left + ach.pos_left @end
    @if ach.has_pos_right ach_x = (cur_x + avail_w) - (pad_right + ach.pref_width + ach.pos_right) @end
    @if ach.has_pos_top ach_y = cur_y + pad_top + ach.pos_top @end
    @if ach.has_pos_bottom ach_y = (cur_y + avail_h) - (pad_bottom + ach.pref_height + ach.pos_bottom) @end
    
    meas = flexbox_measure_node(ach, content_w, content_h)
    @if ach.pref_width > 0 ach.width = ach.pref_width @else ach.width = meas.width @end
    @if ach.pref_height > 0 ach.height = ach.pref_height @else ach.height = meas.height @end
    
    ach.x = ach_x
    ach.y = ach_y
    ach = flexbox_solve_node(ach, ach.x, ach.y, ach.width, ach.height)
    solved_children = solved_children.push(ach)
    i = i + 1
  @end
  
  node.children = solved_children
  
  @if node.pref_width > 0
    node.width = node.pref_width
  @elif node.width <= 0
    @if max_w > 0
      node.width = max_w
    @else
      node.width = total_content_w + pad_left + pad_right
    @end
  @end
  @if node.pref_height > 0
    node.height = node.pref_height
  @elif node.height <= 0
    @if max_h > 0
      node.height = max_h
    @else
      node.height = max_line_h + pad_top + pad_bottom
    @end
  @end
  
  node.x = cur_x
  node.y = cur_y
  return node
@end

@! ============================================================================
@! 4. GRID & ABSOLUTE LAYOUT SOLVERS
@! ============================================================================

@fn flexbox_solve_grid(node, origin_x, origin_y, max_w, max_h)
  pad_left = node.padding.left
  pad_right = node.padding.right
  pad_top = node.padding.top
  pad_bottom = node.padding.bottom
  
  mar_left = node.margin.left
  mar_right = node.margin.right
  mar_top = node.margin.top
  mar_bottom = node.margin.bottom
  
  gap = node.gap
  @if node.column_gap > 0 gap = node.column_gap @end
  row_gap = node.row_gap
  @if row_gap <= 0 row_gap = gap @end
  
  cur_x = origin_x + mar_left
  cur_y = origin_y + mar_top
  
  avail_w = node.pref_width
  @if avail_w <= 0 avail_w = max_w - (mar_left + mar_right) @end
  content_w = avail_w - (pad_left + pad_right)
  @if content_w < 0 content_w = 0 @end
  
  num_children = node.children.len()
  @if num_children == 0
    node.x = cur_x
    node.y = cur_y
    @if node.width <= 0 node.width = pad_left + pad_right @end
    @if node.height <= 0 node.height = pad_top + pad_bottom @end
    return node
  @end
  
  cols = node.grid_columns
  @if cols <= 0 cols = 2 @end
  
  col_w = (content_w - (gap * (cols - 1))) / cols
  @if col_w < 10 col_w = 10 @end
  
  solved_children = []
  i = 0
  max_bottom = 0
  
  @while i < num_children
    ch = node.children[i]
    r_idx = i / cols
    c_idx = i % cols
    
    c_span = ch.grid_col_span
    @if c_span <= 0 c_span = 1 @end
    
    item_w = (c_span * col_w) + ((c_span - 1) * gap)
    
    gx = cur_x + pad_left + (c_idx * (col_w + gap))
    gy = cur_y + pad_top + (r_idx * (ch.pref_height + row_gap))
    
    ch.x = gx
    ch.y = gy
    ch.width = item_w
    ch.height = ch.pref_height
    @if ch.height <= 0 ch.height = 40 @end
    
    ch = flexbox_solve_node(ch, ch.x, ch.y, ch.width, ch.height)
    solved_children = solved_children.push(ch)
    
    b = (r_idx + 1) * (ch.height + row_gap)
    @if b > max_bottom max_bottom = b @end
    i = i + 1
  @end
  
  node.children = solved_children
  node.x = cur_x
  node.y = cur_y
  @if node.width <= 0 node.width = avail_w @end
  @if node.height <= 0 node.height = max_bottom + pad_top + pad_bottom @end
  
  return node
@end

@fn flexbox_solve_absolute(node, origin_x, origin_y, max_w, max_h)
  mar_left = node.margin.left
  mar_top = node.margin.top
  
  cur_x = origin_x + mar_left
  cur_y = origin_y + mar_top
  
  num_children = node.children.len()
  solved_children = []
  i = 0
  @while i < num_children
    ch = node.children[i]
    ch_x = cur_x + ch.margin.left
    ch_y = cur_y + ch.margin.top
    
    w = ch.pref_width
    @if w <= 0 w = ch.width @end
    @if w <= 0 w = 50 @end
    
    h = ch.pref_height
    @if h <= 0 h = ch.height @end
    @if h <= 0 h = 30 @end
    
    @if ch.has_pos_left ch_x = cur_x + ch.pos_left @end
    @if ch.has_pos_top ch_y = cur_y + ch.pos_top @end
    
    ch.x = ch_x
    ch.y = ch_y
    ch.width = w
    ch.height = h
    
    ch = flexbox_solve_node(ch, ch.x, ch.y, ch.width, ch.height)
    solved_children = solved_children.push(ch)
    i = i + 1
  @end
  
  node.children = solved_children
  node.x = cur_x
  node.y = cur_y
  @if max_w > 0
    node.width = max_w
  @elif node.width <= 0
    node.width = max_w
  @end
  @if max_h > 0
    node.height = max_h
  @elif node.height <= 0
    node.height = max_h
  @end
  
  return node
@end

@! ============================================================================
@! 5. GENERIC NODE DISPATCH & TREE SOLVE ENTRYPOINT
@! ============================================================================

@fn flexbox_solve_node(node, origin_x, origin_y, max_w, max_h)
  @if node.layout_type == LAYOUT_FLEX_ROW() || node.layout_type == LAYOUT_FLEX_ROW_REV()
    return flexbox_solve_row(node, origin_x, origin_y, max_w, max_h)
  @elif node.layout_type == LAYOUT_FLEX_COLUMN() || node.layout_type == LAYOUT_FLEX_COLUMN_REV()
    return flexbox_solve_column(node, origin_x, origin_y, max_w, max_h)
  @elif node.layout_type == LAYOUT_GRID()
    return flexbox_solve_grid(node, origin_x, origin_y, max_w, max_h)
  @else
    return flexbox_solve_absolute(node, origin_x, origin_y, max_w, max_h)
  @end
@end

@fn flexbox_solve_tree(root_node, viewport_w, viewport_h)
  return flexbox_solve_node(root_node, 0, 0, viewport_w, viewport_h)
@end

@fn layout_solve(root_node, container_width, container_height)
  return flexbox_solve_node(root_node, 0, 0, container_width, container_height)
@end

@fn compute_layout(root_node, container_width, container_height)
  return flexbox_solve_node(root_node, 0, 0, container_width, container_height)
@end

@! ============================================================================
@! 6. RESULTS COLLECTION & DIRTY BOUNDS AGGREGATION
@! ============================================================================

@fn flexbox_collect_results_recursive(node, results_list)
  res = layout_result_new(node.id, node.x, node.y, node.width, node.height, node.clip_id, node.node_is_dirty)
  results_list = results_list.push(res)
  
  i = 0
  num = node.children.len()
  @while i < num
    results_list = flexbox_collect_results_recursive(node.children[i], results_list)
    i = i + 1
  @end
  
  return results_list
@end

@fn flexbox_collect_results(root_node)
  return flexbox_collect_results_recursive(root_node, [])
@end

@fn flexbox_compute_dirty_bounds_recursive(node, current_bounds)
  @if node.node_is_dirty
    current_bounds = dirty_bounds_union_rect(current_bounds, node.x, node.y, node.width, node.height)
  @end
  
  i = 0
  num = node.children.len()
  @while i < num
    current_bounds = flexbox_compute_dirty_bounds_recursive(node.children[i], current_bounds)
    i = i + 1
  @end
  
  return current_bounds
@end

@fn flexbox_compute_dirty_bounds(root_node)
  return flexbox_compute_dirty_bounds_recursive(root_node, dirty_bounds_empty())
@end

@! ============================================================================
@! 7. LINEAR NODE ARRAY SOLVER (GPU BUFFER CPU EQUIVALENCE)
@! ============================================================================

@fn flexbox_solve_linear_nodes(linear_nodes, viewport_w, viewport_h)
  n_count = linear_nodes.len()
  @if n_count == 0
    return linear_nodes
  @end
  
  @! Top-down solve over linear nodes array
  idx = 0
  @while idx < n_count
    node = linear_nodes[idx]
    
    @! Root container initialization
    @if node.parent_idx == -1 || node.parent_idx == 0xFFFFFFFF || node.parent_idx == idx
      node.computed_x = node.margin_left
      node.computed_y = node.margin_top
      @if node.pref_width <= 0
        node.computed_width = viewport_w - (node.margin_left + node.margin_right)
      @else
        node.computed_width = node.pref_width
      @end
      @if node.pref_height <= 0
        node.computed_height = viewport_h - (node.margin_top + node.margin_bottom)
      @else
        node.computed_height = node.pref_height
      @end
      linear_nodes[idx] = node
    @else
      @! Child nodes inherit from parent
      parent = linear_nodes[node.parent_idx]
      content_x = parent.computed_x + parent.padding_left
      content_y = parent.computed_y + parent.padding_top
      avail_w = parent.computed_width - (parent.padding_left + parent.padding_right)
      @if avail_w < 0 avail_w = 0 @end
      avail_h = parent.computed_height - (parent.padding_top + parent.padding_bottom)
      @if avail_h < 0 avail_h = 0 @end
      
      gap = parent.gap
      effective_count = parent.child_count
      @if effective_count < 1 effective_count = 1 @end
      
      @! Calculate running main-axis offset across previous siblings
      child_pos = 0
      running_offset_x = 0
      running_offset_y = 0
      c_i = 0
      @while c_i < parent.children_indices.len()
        sib_idx = parent.children_indices[c_i]
        @if sib_idx == idx
          child_pos = c_i
          c_i = parent.children_indices.len()
        @else
          sib_node = linear_nodes[sib_idx]
          running_offset_x = running_offset_x + sib_node.computed_width + gap
          running_offset_y = running_offset_y + sib_node.computed_height + gap
          c_i = c_i + 1
        @end
      @end
      
      @if parent.layout_type == LAYOUT_ABSOLUTE()
        node.computed_x = content_x + node.margin_left
        node.computed_y = content_y + node.margin_top
        node.computed_width = node.pref_width
        @if node.computed_width > avail_w && avail_w > 0 node.computed_width = avail_w @end
        node.computed_height = node.pref_height
        @if node.computed_height > avail_h && avail_h > 0 node.computed_height = avail_h @end
      @elif parent.layout_type == LAYOUT_FLEX_ROW()
        total_gaps = (effective_count - 1) * gap
        share_w = (avail_w - total_gaps) / effective_count
        @if share_w < 0 share_w = 0 @end
        
        child_w = share_w
        @if node.pref_width > 0 && node.flex_grow <= 0
          child_w = node.pref_width
        @end
        node.computed_width = child_w
        
        @if parent.align_items == ALIGN_STRETCH()
          node.computed_height = avail_h - (node.margin_top + node.margin_bottom)
          node.computed_y = content_y + node.margin_top
        @elif parent.align_items == ALIGN_CENTER()
          node.computed_height = node.pref_height
          @if node.computed_height > avail_h node.computed_height = avail_h @end
          node.computed_y = content_y + ((avail_h - node.computed_height) / 2)
        @else
          node.computed_height = node.pref_height
          @if node.computed_height > avail_h node.computed_height = avail_h @end
          node.computed_y = content_y + node.margin_top
        @end
        
        @if node.pref_width > 0 && node.flex_grow <= 0
          node.computed_x = content_x + running_offset_x + node.margin_left
        @else
          node.computed_x = content_x + (child_pos * (share_w + gap)) + node.margin_left
        @end
      @elif parent.layout_type == LAYOUT_FLEX_COLUMN()
        total_gaps = (effective_count - 1) * gap
        share_h = (avail_h - total_gaps) / effective_count
        @if share_h < 0 share_h = 0 @end
        
        child_h = share_h
        @if node.pref_height > 0 && node.flex_grow <= 0
          child_h = node.pref_height
        @end
        node.computed_height = child_h
        
        @if parent.align_items == ALIGN_STRETCH()
          node.computed_width = avail_w - (node.margin_left + node.margin_right)
          node.computed_x = content_x + node.margin_left
        @elif parent.align_items == ALIGN_CENTER()
          node.computed_width = node.pref_width
          @if node.computed_width > avail_w node.computed_width = avail_w @end
          node.computed_x = content_x + ((avail_w - node.computed_width) / 2)
        @else
          node.computed_width = node.pref_width
          @if node.computed_width > avail_w node.computed_width = avail_w @end
          node.computed_x = content_x + node.margin_left
        @end
        
        @if node.pref_height > 0 && node.flex_grow <= 0
          node.computed_y = content_y + running_offset_y + node.margin_top
        @else
          node.computed_y = content_y + (child_pos * (share_h + gap)) + node.margin_top
        @end
      @end
      
      linear_nodes[idx] = node
    @end
    idx = idx + 1
  @end
  
  return linear_nodes
@end
