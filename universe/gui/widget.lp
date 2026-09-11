@! ============================================================================
@! MAYA NATIVE GUI FRAMEWORK — STANDARD WIDGET SUITE
@! Module: universe/gui/widget.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - Complete Widget data structure (Window, Button, Label, TextInput, ScrollView, Slider, Container)
@! - Lifecycle, tree hierarchy mutations, and state management
@! - Interactive event handling: typing, cursor nav, scroll, slider drag
@! - Canvas rasterization rendering engine
@! ============================================================================

import "universe/gui/canvas"
import "universe/gui/font"
import "universe/gui/layout"
import "universe/gui/event"
import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"

@! ----------------------------------------------------------------------------
@! 1. WIDGET DATA STRUCTURE (x, y, width, height aligned to indices 0, 1, 2, 3)
@! ----------------------------------------------------------------------------

@struct Widget
  x: i64
  y: i64
  width: i64
  height: i64
  id: string
  kind: string
  min_w: i64
  min_h: i64
  max_w: i64
  max_h: i64
  padding: i64
  margin: i64
  gap: i64
  layout_type: string
  align: string
  justify: string
  flex_grow: i64
  flex_shrink: i64
  columns: i64
  bg_color: i64
  border_color: i64
  border_width: i64
  text_color: i64
  font_size: i64
  corner_radius: i64
  visible: bool
  enabled: bool
  focused: bool
  hovered: bool
  pressed: bool
  checked: bool
  text: string
  title: string
  placeholder: string
  value_num: i64
  min_val: i64
  max_val: i64
  step_val: i64
  cursor_pos: i64
  sel_start: i64
  sel_end: i64
  scroll_x: i64
  scroll_y: i64
  content_w: i64
  content_h: i64
  children: array
  parent_id: string
  on_click: string
  on_change: string
  on_submit: string
  on_scroll: string
@end

@! ----------------------------------------------------------------------------
@! 2. BASE CONSTRUCTOR & FACTORIES
@! ----------------------------------------------------------------------------

@fn widget_new(id, kind, x, y, w, h)
  return {
    x: x,
    y: y,
    width: w,
    height: h,
    id: id,
    kind: kind,
    min_w: 0,
    min_h: 0,
    max_w: 0,
    max_h: 0,
    padding: 4,
    margin: 0,
    gap: 4,
    layout_type: "ABSOLUTE",
    align: "START",
    justify: "START",
    flex_grow: 0,
    flex_shrink: 1,
    columns: 2,
    bg_color: 0xFF2A2A2A,
    border_color: 0xFF444444,
    border_width: 1,
    text_color: 0xFFFFFFFF,
    font_size: 14,
    corner_radius: 0,
    visible: true,
    enabled: true,
    focused: false,
    hovered: false,
    pressed: false,
    checked: false,
    text: "",
    title: "",
    placeholder: "",
    value_num: 0,
    min_val: 0,
    max_val: 100,
    step_val: 1,
    cursor_pos: 0,
    sel_start: 0,
    sel_end: 0,
    scroll_x: 0,
    scroll_y: 0,
    content_w: w,
    content_h: h,
    children: [],
    parent_id: "",
    on_click: "",
    on_change: "",
    on_submit: "",
    on_scroll: ""
  }
@end

@fn widget_window_new(id, title, x, y, w, h)
  win = widget_new(id, "Window", x, y, w, h)
  win.title = title
  win.text = title
  win.bg_color = 0xFF2A2A2A
  win.border_color = 0xFF555555
  win.border_width = 1
  win.text_color = 0xFFFFFFFF
  win.padding = 6
  win.layout_type = "ABSOLUTE"
  return win
@end

@fn widget_button_new(id, text, x, y, w, h, on_click)
  btn = widget_new(id, "Button", x, y, w, h)
  btn.text = text
  btn.bg_color = 0xFF007ACC
  btn.border_color = 0xFF1C97EA
  btn.text_color = 0xFFFFFFFF
  btn.on_click = on_click
  btn.corner_radius = 2
  return btn
@end

@fn widget_label_new(id, text, x, y, w, h)
  lbl = widget_new(id, "Label", x, y, w, h)
  lbl.text = text
  lbl.bg_color = 0
  lbl.border_width = 0
  lbl.text_color = 0xFFFFFFFF
  return lbl
@end

@fn widget_text_input_new(id, placeholder, x, y, w, h, on_change)
  inp = widget_new(id, "TextInput", x, y, w, h)
  inp.placeholder = placeholder
  inp.text = ""
  inp.bg_color = 0xFF1E1E1E
  inp.border_color = 0xFF666666
  inp.text_color = 0xFFFFFFFF
  inp.on_change = on_change
  inp.corner_radius = 2
  return inp
@end

@fn widget_scroll_view_new(id, x, y, w, h, content_w, content_h)
  sv = widget_new(id, "ScrollView", x, y, w, h)
  sv.content_w = content_w
  sv.content_h = content_h
  sv.bg_color = 0xFF1E1E1E
  sv.border_color = 0xFF3E3E42
  sv.layout_type = "ABSOLUTE"
  return sv
@end

@fn widget_slider_new(id, min_val, max_val, current_val, x, y, w, h, on_change)
  sld = widget_new(id, "Slider", x, y, w, h)
  sld.min_val = min_val
  sld.max_val = max_val
  sld.value_num = current_val
  sld.on_change = on_change
  sld.bg_color = 0xFF333333
  sld.border_color = 0xFF555555
  return sld
@end

@fn widget_container_new(id, layout_type, x, y, w, h)
  cnt = widget_new(id, "Container", x, y, w, h)
  cnt.layout_type = layout_type
  cnt.bg_color = 0
  cnt.border_width = 0
  return cnt
@end

@! Compatibility helpers
@fn widget_button(text, x, y, w, h)
  return widget_button_new("btn", text, x, y, w, h, "")
@end

@fn widget_label(text, x, y)
  return widget_label_new("lbl", text, x, y, 100, 20)
@end

@fn widget_input(placeholder, x, y, w)
  return widget_text_input_new("inp", placeholder, x, y, w, 24, "")
@end

@fn widget_checkbox(label, x, y, checked)
  cb = widget_new("cb", "Checkbox", x, y, 20, 20)
  cb.text = label
  cb.checked = checked
  return cb
@end

@! ----------------------------------------------------------------------------
@! 3. TREE MUTATIONS & HIERARCHY
@! ----------------------------------------------------------------------------

@fn widget_add_child(parent, child)
  child.parent_id = parent.id
  parent.children = parent.children.push(child)
  return parent
@end

@fn widget_remove_child(parent, child_id)
  new_children = []
  i = 0
  num_items = parent.children.len()
  @while i < num_items
    ch = parent.children[i]
    @if ch.id != child_id
      ch = widget_remove_child(ch, child_id)
      new_children = new_children.push(ch)
    @end
    i = i + 1
  @end
  parent.children = new_children
  return parent
@end

@fn widget_find_by_id(root, target_id)
  @if root == 0 || root == none return 0 @end
  @if root.id == target_id return root @end
  
  i = 0
  num_items = root.children.len()
  @while i < num_items
    found = widget_find_by_id(root.children[i], target_id)
    @if found != 0 && found != none return found @end
    i = i + 1
  @end
  return 0
@end

@fn widget_update_node(root, updated_node)
  @if root == 0 || root == none return updated_node @end
  @if root.id == updated_node.id
    return updated_node
  @end
  
  i = 0
  num_items = root.children.len()
  @while i < num_items
    root.children[i] = widget_update_node(root.children[i], updated_node)
    i = i + 1
  @end
  return root
@end

@fn widget_count(root)
  @if root == 0 || root == none return 0 @end
  cnt = 1
  i = 0
  num_items = root.children.len()
  @while i < num_items
    cnt = cnt + widget_count(root.children[i])
    i = i + 1
  @end
  return cnt
@end

@! ----------------------------------------------------------------------------
@! 4. INTERACTIVE EVENT HANDLERS
@! ----------------------------------------------------------------------------

@fn widget_handle_key(widget, key_code, key_char, modifiers)
  k = widget.kind
  @if k == "TextInput" || k == "input"
    t = widget.text
    t_len = str_len(t)
    pos = widget.cursor_pos
    @if pos < 0 pos = 0 @end
    @if pos > t_len pos = t_len @end
    
    @! Backspace (8)
    @if key_code == 8
      @if pos > 0
        left = str_substr(t, 0, pos - 1)
        right = str_substr(t, pos, t_len)
        widget.text = left + right
        widget.cursor_pos = pos - 1
      @end
      return widget
    @end
    
    @! Delete (46 / 127)
    @if key_code == 46 || key_code == 127
      @if pos < t_len
        left = str_substr(t, 0, pos)
        right = str_substr(t, pos + 1, t_len)
        widget.text = left + right
      @end
      return widget
    @end
    
    @! Left Arrow (37)
    @if key_code == 37
      @if pos > 0 widget.cursor_pos = pos - 1 @end
      return widget
    @end
    
    @! Right Arrow (39)
    @if key_code == 39
      @if pos < t_len widget.cursor_pos = pos + 1 @end
      return widget
    @end
    
    @! Home (36)
    @if key_code == 36
      widget.cursor_pos = 0
      return widget
    @end
    
    @! End (35)
    @if key_code == 35
      widget.cursor_pos = t_len
      return widget
    @end
    
    @! Character insertion
    @if key_char != "" && key_char != none
      left = str_substr(t, 0, pos)
      right = str_substr(t, pos, t_len)
      widget.text = left + key_char + right
      widget.cursor_pos = pos + str_len(key_char)
      return widget
    @end
  @end
  return widget
@end

@fn widget_handle_mouse_down(widget, mx, my, button)
  widget.pressed = true
  widget.focused = true
  
  k = widget.kind
  @if k == "Slider" || k == "slider"
    track_w = widget.width - 12
    @if track_w <= 0 track_w = 1 @end
    rel_x = mx - widget.x - 6
    @if rel_x < 0 rel_x = 0 @end
    @if rel_x > track_w rel_x = track_w @end
    val_range = widget.max_val - widget.min_val
    widget.value_num = widget.min_val + ((rel_x * val_range) / track_w)
  @elif k == "Checkbox" || k == "checkbox"
    widget.checked = !widget.checked
  @end
  return widget
@end

@fn widget_handle_mouse_up(widget, mx, my, button)
  widget.pressed = false
  return widget
@end

@fn widget_handle_mouse_move(widget, mx, my)
  inside = event_point_in_rect(mx, my, widget.x, widget.y, widget.width, widget.height)
  widget.hovered = inside
  
  @if widget.pressed == true && (widget.kind == "Slider" || widget.kind == "slider")
    track_w = widget.width - 12
    @if track_w <= 0 track_w = 1 @end
    rel_x = mx - widget.x - 6
    @if rel_x < 0 rel_x = 0 @end
    @if rel_x > track_w rel_x = track_w @end
    val_range = widget.max_val - widget.min_val
    widget.value_num = widget.min_val + ((rel_x * val_range) / track_w)
  @end
  return widget
@end

@fn widget_handle_wheel(widget, delta)
  @if widget.kind == "ScrollView"
    widget.scroll_y = widget.scroll_y - (delta * 20)
    max_scroll_y = widget.content_h - widget.height
    @if max_scroll_y < 0 max_scroll_y = 0 @end
    @if widget.scroll_y < 0 widget.scroll_y = 0 @end
    @if widget.scroll_y > max_scroll_y widget.scroll_y = max_scroll_y @end
  @end
  return widget
@end

@! ----------------------------------------------------------------------------
@! 5. CANVAS RASTERIZATION RENDERING ENGINE
@! ----------------------------------------------------------------------------

@fn widget_render(widget, canvas, font)
  @if widget == 0 || widget == none || widget.visible == false
    return canvas
  @end
  
  wx = widget.x
  wy = widget.y
  ww = widget.width
  wh = widget.height
  
  k = widget.kind
  
  @if k == "Window"
    @! Window Frame Background & Border
    canvas = canvas_fill_rect(canvas, wx, wy, ww, wh, widget.bg_color)
    @if widget.border_width > 0
      canvas = canvas_draw_rect(canvas, wx, wy, ww, wh, widget.border_color)
    @end
    
    @! Title Bar (24px height)
    title_h = 24
    canvas = canvas_fill_rect(canvas, wx + 1, wy + 1, ww - 2, title_h, 0xFF007ACC)
    @if widget.title != ""
      canvas = font_draw_text_clipped(canvas, font, wx + 8, wy + 4, widget.title, 0xFFFFFFFF, ww - 32)
    @end
    
    @! Close Button [X]
    cb_x = (wx + ww) - 20
    cb_y = wy + 3
    canvas = canvas_fill_rect(canvas, cb_x, cb_y, 16, 16, 0xFFE81123)
    canvas = font_draw_text(canvas, font, cb_x + 4, cb_y, "x", 0xFFFFFFFF)
    
  @elif k == "Button" || k == "button"
    bg = widget.bg_color
    @if widget.enabled == false
      bg = 0xFF555555
    @elif widget.pressed == true
      bg = 0xFF005A9E
    @elif widget.hovered == true
      bg = 0xFF1C97EA
    @end
    
    @if widget.corner_radius > 0
      canvas = canvas_fill_rounded_rect(canvas, wx, wy, ww, wh, widget.corner_radius, bg)
      @if widget.border_width > 0
        canvas = canvas_draw_rounded_rect(canvas, wx, wy, ww, wh, widget.corner_radius, widget.border_color)
      @end
    @else
      canvas = canvas_fill_rect(canvas, wx, wy, ww, wh, bg)
      @if widget.border_width > 0
        canvas = canvas_draw_rect(canvas, wx, wy, ww, wh, widget.border_color)
      @end
    @end
    
    @! Center button label
    t_sz = font_measure_text(font, widget.text)
    tx = wx + ((ww - t_sz.width) / 2)
    ty = wy + ((wh - t_sz.height) / 2)
    @if tx < wx + 4 tx = wx + 4 @end
    @if ty < wy + 2 ty = wy + 2 @end
    canvas = font_draw_text_clipped(canvas, font, tx, ty, widget.text, widget.text_color, ww - 8)
    
  @elif k == "Label" || k == "label"
    @if widget.bg_color != 0
      canvas = canvas_fill_rect(canvas, wx, wy, ww, wh, widget.bg_color)
    @end
    canvas = font_draw_text_clipped(canvas, font, wx, wy, widget.text, widget.text_color, ww)
    
  @elif k == "TextInput" || k == "input"
    canvas = canvas_fill_rect(canvas, wx, wy, ww, wh, widget.bg_color)
    
    border_col = widget.border_color
    @if widget.focused == true border_col = 0xFF007ACC @end
    canvas = canvas_draw_rect(canvas, wx, wy, ww, wh, border_col)
    
    pad = widget.padding
    @if pad <= 0 pad = 4 @end
    
    @! Draw text or placeholder
    disp_text = widget.text
    text_col = widget.text_color
    @if disp_text == "" && widget.placeholder != ""
      disp_text = widget.placeholder
      text_col = 0xFF888888
    @end
    
    canvas = font_draw_text_clipped(canvas, font, wx + pad, wy + ((wh - 16) / 2), disp_text, text_col, ww - (2 * pad))
    
    @! Draw blinking cursor if focused
    @if widget.focused == true
      cursor_x = wx + pad + (widget.cursor_pos * font.char_width)
      cursor_y = wy + 4
      @if cursor_x < wx + ww - pad
        canvas = canvas_draw_line(canvas, cursor_x, cursor_y, cursor_x, cursor_y + 16, 0xFFFFFFFF)
      @end
    @end
    
  @elif k == "Slider" || k == "slider"
    @if widget.bg_color != 0
      canvas = canvas_fill_rect(canvas, wx, wy, ww, wh, widget.bg_color)
    @end
    
    track_y = wy + ((wh - 4) / 2)
    canvas = canvas_fill_rect(canvas, wx + 6, track_y, ww - 12, 4, 0xFF555555)
    
    val_range = widget.max_val - widget.min_val
    @if val_range <= 0 val_range = 1 @end
    cur_offset = widget.value_num - widget.min_val
    track_w = ww - 12
    thumb_x_rel = (cur_offset * track_w) / val_range
    @if thumb_x_rel < 0 thumb_x_rel = 0 @end
    @if thumb_x_rel > track_w thumb_x_rel = track_w @end
    
    canvas = canvas_fill_rect(canvas, wx + 6, track_y, thumb_x_rel, 4, 0xFF007ACC)
    
    thumb_x = wx + thumb_x_rel
    thumb_y = wy + ((wh - 16) / 2)
    thumb_col = 0xFFDDDDDD
    @if widget.pressed == true thumb_col = 0xFF007ACC @end
    canvas = canvas_fill_rect(canvas, thumb_x, thumb_y, 12, 16, thumb_col)
    canvas = canvas_draw_rect(canvas, thumb_x, thumb_y, 12, 16, 0xFFFFFFFF)
    
  @elif k == "ScrollView"
    canvas = canvas_fill_rect(canvas, wx, wy, ww, wh, widget.bg_color)
    @if widget.border_width > 0
      canvas = canvas_draw_rect(canvas, wx, wy, ww, wh, widget.border_color)
    @end
    
    canvas = canvas_push_clip(canvas, wx, wy, ww, wh)
    num_ch = widget.children.len()
    i = 0
    @while i < num_ch
      ch = widget.children[i]
      orig_cx = ch.x
      orig_cy = ch.y
      ch.x = (wx + orig_cx) - widget.scroll_x
      ch.y = (wy + orig_cy) - widget.scroll_y
      canvas = widget_render(ch, canvas, font)
      ch.x = orig_cx
      ch.y = orig_cy
      i = i + 1
    @end
    canvas = canvas_pop_clip(canvas)
    
    @if widget.content_h > wh
      sb_w = 8
      sb_x = (wx + ww) - sb_w
      canvas = canvas_fill_rect(canvas, sb_x, wy, sb_w, wh, 0xFF2D2D30)
      
      thumb_h = (wh * wh) / widget.content_h
      @if thumb_h < 16 thumb_h = 16 @end
      thumb_y_rel = (widget.scroll_y * (wh - thumb_h)) / (widget.content_h - wh)
      canvas = canvas_fill_rect(canvas, sb_x + 1, wy + thumb_y_rel, sb_w - 2, thumb_h, 0xFF686868)
    @end
    return canvas
    
  @else
    @if widget.bg_color != 0
      canvas = canvas_fill_rect(canvas, wx, wy, ww, wh, widget.bg_color)
    @end
    @if widget.border_width > 0
      canvas = canvas_draw_rect(canvas, wx, wy, ww, wh, widget.border_color)
    @end
  @end
  
  num_ch = widget.children.len()
  i = 0
  @while i < num_ch
    ch = widget.children[i]
    orig_cx = ch.x
    orig_cy = ch.y
    ch.x = wx + orig_cx
    ch.y = wy + orig_cy
    canvas = widget_render(ch, canvas, font)
    ch.x = orig_cx
    ch.y = orig_cy
    i = i + 1
  @end
  
  return canvas
@end
