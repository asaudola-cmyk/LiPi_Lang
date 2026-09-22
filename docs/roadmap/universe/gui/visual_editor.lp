@! ============================================================================
@! MAYA UNIVERSE GUI — VISUAL LAYOUT EDITOR & INTERACTIVE CANVAS
@! Module: universe/gui/visual_editor.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - Multi-viewport layout editor (Toolbar, Palette, Canvas, Property Inspector)
@! - 8-Handle selection bounding box calculation & hit-testing (NW, N, NE, E, SE, S, SW, W)
@! - 8px & configurable grid snapping algorithm
@! - Interactive mouse event processing (selection, drag-and-drop move, resize)
@! - Undo / Redo history state snapshots
@! - Direct rendering integration with universe/gui/framebuffer & compositor
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/gui/framebuffer"
import "universe/gui/font"
import "universe/gui/builder"

@! ----------------------------------------------------------------------------
@! 1. VISUAL EDITOR INSTANTIATION & STATE
@! ----------------------------------------------------------------------------

@fn visual_editor_new(width, height)
  root_win = gui_window_new("root_window", "Maya GUI Workspace", 20, 20, 560, 420)
  font = font_load_default()
  
  return {
    width: width,
    height: height,
    
    @! Viewport Rectangles
    toolbar_rect: { x: 0, y: 0, width: width, height: 40 },
    palette_rect: { x: 0, y: 40, width: 180, height: height - 40 },
    inspector_rect: { x: width - 220, y: 40, width: 220, height: height - 40 },
    canvas_rect: { x: 180, y: 40, width: width - 400, height: height - 40 },
    
    @! Component Hierarchy
    root_node: root_win,
    selected_id: "root_window",
    
    @! Editor Modes: "SELECT", "MOVE", "RESIZE", "INSERT", "PREVIEW"
    mode: "SELECT",
    
    @! Grid & Snapping
    grid_snap: 1,
    grid_size: 8,
    zoom: 100,
    
    @! Interactive Drag / Resize Tracking
    is_dragging: 0,
    active_handle: "",
    insert_widget_kind: "",
    drag_start_x: 0,
    drag_start_y: 0,
    orig_node_x: 0,
    orig_node_y: 0,
    orig_node_w: 0,
    orig_node_h: 0,
    
    @! History & Undo/Redo
    undo_stack: [],
    redo_stack: [],
    
    @! Font and State
    font: font,
    state_store: gui_state_store_new()
  }
@end

@fn editor_set_mode(editor, mode)
  editor.mode = mode
  @if mode != "RESIZE" editor.active_handle = "" @end
  @if mode != "INSERT" editor.insert_widget_kind = "" @end
  return editor
@end

@fn editor_select_node(editor, node_id)
  editor.selected_id = node_id
  return editor
@end

@! ----------------------------------------------------------------------------
@! 2. GRID SNAPPING & 8-HANDLE COMPUTATIONS
@! ----------------------------------------------------------------------------

@fn editor_snap_to_grid(val, grid_size)
  @if grid_size <= 1
    return val
  @end
  half = grid_size / 2
  rem = val % grid_size
  @if rem < 0 rem = rem + grid_size @end
  @if rem >= half
    return val + (grid_size - rem)
  @end
  return val - rem
@end

@fn editor_calc_handles(rect, handle_size)
  hs = handle_size
  half_hs = hs / 2
  
  rx = rect.x
  ry = rect.y
  rw = rect.width
  rh = rect.height
  
  mx = rx + (rw / 2)
  my = ry + (rh / 2)
  
  handles = [
    { name: "NW", x: rx - half_hs, y: ry - half_hs, w: hs, h: hs },
    { name: "N",  x: mx - half_hs, y: ry - half_hs, w: hs, h: hs },
    { name: "NE", x: rx + rw - half_hs, y: ry - half_hs, w: hs, h: hs },
    { name: "E",  x: rx + rw - half_hs, y: my - half_hs, w: hs, h: hs },
    { name: "SE", x: rx + rw - half_hs, y: ry + rh - half_hs, w: hs, h: hs },
    { name: "S",  x: mx - half_hs, y: ry + rh - half_hs, w: hs, h: hs },
    { name: "SW", x: rx - half_hs, y: ry + rh - half_hs, w: hs, h: hs },
    { name: "W",  x: rx - half_hs, y: my - half_hs, w: hs, h: hs }
  ]
  
  return handles
@end

@fn editor_handle_hit_test(handles, click_x, click_y)
  i = 0
  len = handles.len()
  @while i < len
    h = handles[i]
    @if click_x >= h.x && click_x <= h.x + h.w
      @if click_y >= h.y && click_y <= h.y + h.h
        return h.name
      @end
    @end
    i = i + 1
  @end
  return ""
@end

@! ----------------------------------------------------------------------------
@! 3. MOUSE EVENT PROCESSING (SELECT, MOVE, RESIZE, DRAG-AND-DROP)
@! ----------------------------------------------------------------------------

@fn editor_push_undo(editor)
  snapshot = builder_clone_node(editor.root_node)
  editor.undo_stack = editor.undo_stack.push(snapshot)
  editor.redo_stack = []
  return editor
@end

@fn editor_undo(editor)
  len = editor.undo_stack.len()
  @if len == 0
    return editor
  @end
  
  @! Push current state to redo
  current_snap = builder_clone_node(editor.root_node)
  editor.redo_stack = editor.redo_stack.push(current_snap)
  
  @! Pop last undo state
  last_idx = len - 1
  editor.root_node = editor.undo_stack[last_idx]
  
  new_undo = []
  i = 0
  @while i < last_idx
    new_undo = new_undo.push(editor.undo_stack[i])
    i = i + 1
  @end
  editor.undo_stack = new_undo
  return editor
@end

@fn editor_redo(editor)
  len = editor.redo_stack.len()
  @if len == 0
    return editor
  @end
  
  @! Push current state to undo
  current_snap = builder_clone_node(editor.root_node)
  editor.undo_stack = editor.undo_stack.push(current_snap)
  
  @! Pop last redo state
  last_idx = len - 1
  editor.root_node = editor.redo_stack[last_idx]
  
  new_redo = []
  i = 0
  @while i < last_idx
    new_redo = new_redo.push(editor.redo_stack[i])
    i = i + 1
  @end
  editor.redo_stack = new_redo
  return editor
@end

@fn editor_mouse_down(editor, x, y, button)
  @! 1. Toolbar Click Check
  @if y < editor.toolbar_rect.height
    @if x >= 10 && x <= 70 editor_set_mode(editor, "SELECT") @end
    @if x >= 75 && x <= 135 editor_set_mode(editor, "MOVE") @end
    @if x >= 140 && x <= 200 editor_set_mode(editor, "PREVIEW") @end
    @if x >= 205 && x <= 265
      @if editor.grid_snap == 1 editor.grid_snap = 0
      @else editor.grid_snap = 1 @end
    @end
    @if x >= 270 && x <= 320 editor_undo(editor) @end
    @if x >= 325 && x <= 375 editor_redo(editor) @end
    return editor
  @end
  
  @! 2. Left Component Palette Click Check
  @if x < editor.palette_rect.width
    @if y >= 50 && y <= 75 editor.insert_widget_kind = "Button" editor.mode = "INSERT" @end
    @if y >= 80 && y <= 105 editor.insert_widget_kind = "TextInput" editor.mode = "INSERT" @end
    @if y >= 110 && y <= 135 editor.insert_widget_kind = "Label" editor.mode = "INSERT" @end
    @if y >= 140 && y <= 165 editor.insert_widget_kind = "Slider" editor.mode = "INSERT" @end
    @if y >= 170 && y <= 195 editor.insert_widget_kind = "Checkbox" editor.mode = "INSERT" @end
    @if y >= 200 && y <= 225 editor.insert_widget_kind = "Panel" editor.mode = "INSERT" @end
    @if y >= 230 && y <= 255 editor.insert_widget_kind = "Row" editor.mode = "INSERT" @end
    @if y >= 260 && y <= 285 editor.insert_widget_kind = "Column" editor.mode = "INSERT" @end
    return editor
  @end
  
  @! 3. Interactive Canvas Click Handling
  @if x >= editor.canvas_rect.x && x <= editor.canvas_rect.x + editor.canvas_rect.width
    canvas_local_x = x - editor.canvas_rect.x
    canvas_local_y = y - editor.canvas_rect.y
    
    @! If in INSERT mode: drop the new widget
    @if editor.mode == "INSERT" && editor.insert_widget_kind != ""
      editor_push_undo(editor)
      
      drop_x = canvas_local_x
      drop_y = canvas_local_y
      @if editor.grid_snap == 1
        drop_x = editor_snap_to_grid(drop_x, editor.grid_size)
        drop_y = editor_snap_to_grid(drop_y, editor.grid_size)
      @end
      
      new_id = editor.insert_widget_kind.to_str() + "_" + builder_count_nodes(editor.root_node).to_str()
      new_node = builder_node_new(new_id, editor.insert_widget_kind, drop_x, drop_y, 100, 32)
      
      @if editor.insert_widget_kind == "Button"
        new_node = gui_button_new(new_id, "Button", drop_x, drop_y, 100, 32, "on_click")
      @elif editor.insert_widget_kind == "TextInput"
        new_node = gui_text_input_new(new_id, "Enter text...", drop_x, drop_y, 140, 30, "on_change")
      @elif editor.insert_widget_kind == "Label"
        new_node = gui_label_new(new_id, "Label Text", drop_x, drop_y, 100, 24)
      @elif editor.insert_widget_kind == "Slider"
        new_node = gui_slider_new(new_id, 0, 100, 50, drop_x, drop_y, 140, 24, "on_change")
      @elif editor.insert_widget_kind == "Checkbox"
        new_node = gui_checkbox_new(new_id, "Option", 0, drop_x, drop_y, 120, 24, "on_change")
      @elif editor.insert_widget_kind == "Panel"
        new_node = gui_panel_new(new_id, drop_x, drop_y, 160, 100)
      @end
      
      editor.root_node = builder_add_child(editor.root_node, new_node)
      editor.selected_id = new_id
      editor.mode = "SELECT"
      editor.insert_widget_kind = ""
      return editor
    @end
    
    @! Check if clicked on selection handles of active node
    @if editor.selected_id != "" && editor.mode != "PREVIEW"
      sel_node = builder_find_node(editor.root_node, editor.selected_id)
      @if sel_node != 0 && sel_node != none
        handles = editor_calc_handles(sel_node.rect, 8)
        clicked_handle = editor_handle_hit_test(handles, canvas_local_x, canvas_local_y)
        @if clicked_handle != ""
          editor_push_undo(editor)
          editor.mode = "RESIZE"
          editor.active_handle = clicked_handle
          editor.is_dragging = 1
          editor.drag_start_x = canvas_local_x
          editor.drag_start_y = canvas_local_y
          editor.orig_node_x = sel_node.rect.x
          editor.orig_node_y = sel_node.rect.y
          editor.orig_node_w = sel_node.rect.width
          editor.orig_node_h = sel_node.rect.height
          return editor
        @end
      @end
    @end
    
    @! Hit-test component hierarchy
    hit_node = gui_hit_test(editor.root_node, canvas_local_x, canvas_local_y)
    @if hit_node != 0 && hit_node != none
      editor.selected_id = hit_node.id
      @if editor.mode != "PREVIEW"
        editor_push_undo(editor)
        editor.mode = "MOVE"
        editor.is_dragging = 1
        editor.drag_start_x = canvas_local_x
        editor.drag_start_y = canvas_local_y
        editor.orig_node_x = hit_node.rect.x
        editor.orig_node_y = hit_node.rect.y
        editor.orig_node_w = hit_node.rect.width
        editor.orig_node_h = hit_node.rect.height
      @end
    @else
      editor.selected_id = ""
    @end
  @end
  
  return editor
@end

@fn editor_mouse_move(editor, x, y)
  @if editor.is_dragging == 0 || editor.selected_id == ""
    return editor
  @end
  
  canvas_local_x = x - editor.canvas_rect.x
  canvas_local_y = y - editor.canvas_rect.y
  
  delta_x = canvas_local_x - editor.drag_start_x
  delta_y = canvas_local_y - editor.drag_start_y
  
  @if editor.mode == "MOVE"
    new_x = editor.orig_node_x + delta_x
    new_y = editor.orig_node_y + delta_y
    
    @if editor.grid_snap == 1
      new_x = editor_snap_to_grid(new_x, editor.grid_size)
      new_y = editor_snap_to_grid(new_y, editor.grid_size)
    @end
    
    editor.root_node = builder_move_node(editor.root_node, editor.selected_id, new_x, new_y)
  @elif editor.mode == "RESIZE"
    new_x = editor.orig_node_x
    new_y = editor.orig_node_y
    new_w = editor.orig_node_w
    new_h = editor.orig_node_h
    handle = editor.active_handle
    
    @if handle == "SE"
      new_w = editor.orig_node_w + delta_x
      new_h = editor.orig_node_h + delta_y
    @elif handle == "E"
      new_w = editor.orig_node_w + delta_x
    @elif handle == "S"
      new_h = editor.orig_node_h + delta_y
    @elif handle == "NE"
      new_w = editor.orig_node_w + delta_x
      new_y = editor.orig_node_y + delta_y
      new_h = editor.orig_node_h - delta_y
    @elif handle == "NW"
      new_x = editor.orig_node_x + delta_x
      new_y = editor.orig_node_y + delta_y
      new_w = editor.orig_node_w - delta_x
      new_h = editor.orig_node_h - delta_y
    @elif handle == "SW"
      new_x = editor.orig_node_x + delta_x
      new_w = editor.orig_node_w - delta_x
      new_h = editor.orig_node_h + delta_y
    @elif handle == "W"
      new_x = editor.orig_node_x + delta_x
      new_w = editor.orig_node_w - delta_x
    @elif handle == "N"
      new_y = editor.orig_node_y + delta_y
      new_h = editor.orig_node_h - delta_y
    @end
    
    @if editor.grid_snap == 1
      new_w = editor_snap_to_grid(new_w, editor.grid_size)
      new_h = editor_snap_to_grid(new_h, editor.grid_size)
      new_x = editor_snap_to_grid(new_x, editor.grid_size)
      new_y = editor_snap_to_grid(new_y, editor.grid_size)
    @end
    
    @if new_w < 16 new_w = 16 @end
    @if new_h < 16 new_h = 16 @end
    
    editor.root_node = builder_move_node(editor.root_node, editor.selected_id, new_x, new_y)
    editor.root_node = builder_resize_node(editor.root_node, editor.selected_id, new_w, new_h)
  @end
  
  return editor
@end

@fn editor_mouse_up(editor, x, y)
  @if editor.is_dragging == 1
    editor.is_dragging = 0
    editor.active_handle = ""
    @if editor.mode == "RESIZE" || editor.mode == "MOVE"
      editor.mode = "SELECT"
    @end
  @end
  return editor
@end

@! ----------------------------------------------------------------------------
@! 4. RENDERING INTEGRATION WITH FRAMEBUFFER & FONT
@! ----------------------------------------------------------------------------

@fn editor_render_node(fb, font, node, offset_x, offset_y, selected_id)
  @if node == 0 || node == none || node.props.visible == 0
    return 1
  @end
  
  abs_x = offset_x + node.rect.x
  abs_y = offset_y + node.rect.y
  w = node.rect.width
  h = node.rect.height
  
  @! Draw Component Background
  @if node.props.bg_color != 0x00000000
    fb_draw_rect(fb, abs_x, abs_y, w, h, node.props.bg_color)
  @end
  
  @! Draw Component Border
  @if node.props.border_width > 0
    fb_draw_rect(fb, abs_x, abs_y, w, 1, node.props.border_color)
    fb_draw_rect(fb, abs_x, abs_y + h - 1, w, 1, node.props.border_color)
    fb_draw_rect(fb, abs_x, abs_y, 1, h, node.props.border_color)
    fb_draw_rect(fb, abs_x + w - 1, abs_y, 1, h, node.props.border_color)
  @end
  
  @! Draw Title / Text Label
  @if node.props.text != ""
    font_draw_text(fb, font, abs_x + 6, abs_y + 6, node.props.text, node.props.text_color)
  @elif node.props.placeholder != ""
    font_draw_text(fb, font, abs_x + 6, abs_y + 6, node.props.placeholder, 0xFF888888)
  @end
  
  @! Render Children Recursively
  i = 0
  len = node.children.len()
  @while i < len
    editor_render_node(fb, font, node.children[i], abs_x, abs_y, selected_id)
    i = i + 1
  @end
  
  return 1
@end

@fn gui_builder_render(editor, fb)
  font = editor.font
  
  @! 1. Clear Workspace
  fb_clear(fb, 0xFF181818)
  
  @! 2. Draw Center Canvas Background & Grid Snapping Dots
  cx = editor.canvas_rect.x
  cy = editor.canvas_rect.y
  cw = editor.canvas_rect.width
  ch = editor.canvas_rect.height
  fb_draw_rect(fb, cx, cy, cw, ch, 0xFF222222)
  
  @! Dotted Grid (every 16px)
  gy = cy + 8
  @while gy < cy + ch
    gx = cx + 8
    @while gx < cx + cw
      fb_draw_pixel(fb, gx, gy, 0xFF383838)
      gx = gx + 16
    @end
    gy = gy + 16
  @end
  
  @! 3. Render Node Hierarchy onto Canvas
  editor_render_node(fb, font, editor.root_node, cx, cy, editor.selected_id)
  
  @! 4. Render Active Selection Bounding Box & 8 Handles
  @if editor.selected_id != "" && editor.mode != "PREVIEW"
    sel = builder_find_node(editor.root_node, editor.selected_id)
    @if sel != 0 && sel != none
      bx = cx + sel.rect.x
      by = cy + sel.rect.y
      bw = sel.rect.width
      bh = sel.rect.height
      
      @! Outline
      fb_draw_rect(fb, bx, by, bw, 1, 0xFF00AAFF)
      fb_draw_rect(fb, bx, by + bh - 1, bw, 1, 0xFF00AAFF)
      fb_draw_rect(fb, bx, by, 1, bh, 0xFF00AAFF)
      fb_draw_rect(fb, bx + bw - 1, by, 1, bh, 0xFF00AAFF)
      
      @! Handles
      handles = editor_calc_handles({ x: bx, y: by, width: bw, height: bh }, 6)
      hi = 0
      hlen = handles.len()
      @while hi < hlen
        h = handles[hi]
        fb_draw_rect(fb, h.x, h.y, h.w, h.h, 0xFFFFFFFF)
        hi = hi + 1
      @end
    @end
  @end
  
  @! 5. Render Top Toolbar
  fb_draw_rect(fb, 0, 0, editor.width, 40, 0xFF2D2D2D)
  fb_draw_rect(fb, 0, 39, editor.width, 1, 0xFF444444)
  font_draw_text(fb, font, 12, 12, "[SELECT]", 0xFF00AAFF)
  font_draw_text(fb, font, 80, 12, "[MOVE]", 0xFFFFFFFF)
  font_draw_text(fb, font, 145, 12, "[PREVIEW]", 0xFFFFFFFF)
  font_draw_text(fb, font, 220, 12, "[SNAP 8px]", 0xFF00FF00)
  font_draw_text(fb, font, 300, 12, "[UNDO]", 0xFFDDDDDD)
  font_draw_text(fb, font, 360, 12, "[REDO]", 0xFFDDDDDD)
  
  @! 6. Render Left Component Palette
  fb_draw_rect(fb, 0, 40, editor.palette_rect.width, editor.palette_rect.height, 0xFF252525)
  fb_draw_rect(fb, editor.palette_rect.width - 1, 40, 1, editor.palette_rect.height, 0xFF444444)
  font_draw_text(fb, font, 12, 50, "WIDGET PALETTE", 0xFF888888)
  font_draw_text(fb, font, 12, 70, "+ Button", 0xFFFFFFFF)
  font_draw_text(fb, font, 12, 95, "+ TextInput", 0xFFFFFFFF)
  font_draw_text(fb, font, 12, 120, "+ Label", 0xFFFFFFFF)
  font_draw_text(fb, font, 12, 145, "+ Slider", 0xFFFFFFFF)
  font_draw_text(fb, font, 12, 170, "+ Checkbox", 0xFFFFFFFF)
  font_draw_text(fb, font, 12, 195, "+ Panel", 0xFFFFFFFF)
  font_draw_text(fb, font, 12, 220, "+ Row (Flex)", 0xFFFFFFFF)
  font_draw_text(fb, font, 12, 245, "+ Column (Flex)", 0xFFFFFFFF)
  
  @! 7. Render Right Property Inspector
  ix = editor.inspector_rect.x
  iw = editor.inspector_rect.width
  ih = editor.inspector_rect.height
  fb_draw_rect(fb, ix, 40, iw, ih, 0xFF252525)
  fb_draw_rect(fb, ix, 40, 1, ih, 0xFF444444)
  font_draw_text(fb, font, ix + 12, 50, "PROPERTIES", 0xFF888888)
  
  @if editor.selected_id != ""
    sel = builder_find_node(editor.root_node, editor.selected_id)
    @if sel != 0 && sel != none
      font_draw_text(fb, font, ix + 12, 75, "ID: " + sel.id, 0xFFFFFFFF)
      font_draw_text(fb, font, ix + 12, 95, "Kind: " + sel.kind, 0xFFFFFFFF)
      font_draw_text(fb, font, ix + 12, 115, "X: " + sel.rect.x.to_str() + " Y: " + sel.rect.y.to_str(), 0xFFDDDDDD)
      font_draw_text(fb, font, ix + 12, 135, "W: " + sel.rect.width.to_str() + " H: " + sel.rect.height.to_str(), 0xFFDDDDDD)
      font_draw_text(fb, font, ix + 12, 155, "Text: " + sel.props.text, 0xFFDDDDDD)
      font_draw_text(fb, font, ix + 12, 175, "Click: " + sel.events.on_click, 0xFF00AAFF)
    @end
  @end
  
  return 1
@end
