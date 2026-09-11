@! ============================================================================
@! MAYA NATIVE GUI — WINDOW MANAGER & UI ELEMENTS
@! ============================================================================

@fn window_new(id, title, x, y, width, height)
  return {
    id: id,
    title: title,
    x: x,
    y: y,
    width: width,
    height: height,
    visible: 1,
    z_index: 0,
    
    @! Styling
    bg_color: 0xFFFFFFFF,       @! White
    border_color: 0xFF000000,   @! Black
    title_bg_color: 0xFF336699, @! Blue
    title_text_color: 0xFFFFFFFF,
    
    @! UI Elements inside Window
    children: [],
    
    @! Events
    on_click: "none",
    on_close: "none"
  }
@end

@fn button_new(id, label, x, y, w, h)
  return {
    kind: "BUTTON",
    id: id,
    label: label,
    x: x,
    y: y,
    width: w,
    height: h,
    bg_color: 0xFFDDDDDD,
    text_color: 0xFF000000,
    is_pressed: 0
  }
@end

@fn window_add_child(win, child)
  win.children = win.children.push(child)
  return win
@end

@fn window_handle_click(win, click_x, click_y)
  @! Convert absolute click to window-local coords
  local_x = click_x - win.x
  local_y = click_y - win.y
  
  @! Check if Title bar clicked (Dragging)
  @if local_y >= 0 && local_y <= 20
    return "DRAG_START"
  @end
  
  @! Check children
  i = 0
  len = win.children.len()
  @while i < len
    c = win.children[i]
    @if c.kind == "BUTTON"
      @if local_x >= c.x && local_x <= c.x + c.width
        @if local_y >= c.y && local_y <= c.y + c.height
          c.is_pressed = 1
          return "BUTTON_CLICK_" + c.id
        @end
      @end
    @end
    i = i + 1
  @end
  
  return "NONE"
@end
