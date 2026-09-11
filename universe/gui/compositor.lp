@! ============================================================================
@! MAYA NATIVE GUI FRAMEWORK — WINDOW COMPOSITOR & DESKTOP MANAGER
@! Module: universe/gui/compositor.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - Multi-Window Layering & Z-Index Management
@! - Painter's Algorithm rendering with Drop Shadows
@! - Active window focus switching & bringing to front
@! - Compositor-level event routing & dispatching
@! ============================================================================

import "universe/gui/canvas"
import "universe/gui/font"
import "universe/gui/widget"
import "universe/gui/event"
import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURE DEFINITIONS
@! ----------------------------------------------------------------------------

@struct Compositor
  width: i64
  height: i64
  windows: array
  active_window_id: string
  background_color: i64
  dirty_rects: array
  main_canvas: Canvas
@end

@! ----------------------------------------------------------------------------
@! 2. COMPOSITOR CONSTRUCTOR
@! ----------------------------------------------------------------------------

@fn compositor_new(width, height)
  @if width <= 0 width = 640 @end
  @if height <= 0 height = 480 @end
  
  c = canvas_new(width, height)
  c = canvas_clear(c, 0xFF202020)
  
  return {
    width: width,
    height: height,
    windows: [],
    active_window_id: "",
    background_color: 0xFF202020,
    dirty_rects: [],
    main_canvas: c
  }
@end

@! ----------------------------------------------------------------------------
@! 3. WINDOW MANAGEMENT & Z-ORDER
@! ----------------------------------------------------------------------------

@fn compositor_add_window(comp, win)
  comp.windows = comp.windows.push(win)
  comp.active_window_id = win.id
  return comp
@end

@fn compositor_remove_window(comp, win_id)
  new_wins = []
  i = 0
  num_items = comp.windows.len()
  @while i < num_items
    w = comp.windows[i]
    @if w.id != win_id
      new_wins = new_wins.push(w)
    @end
    i = i + 1
  @end
  comp.windows = new_wins
  
  @if comp.active_window_id == win_id
    new_len = new_wins.len()
    @if new_len > 0
      top_win = new_wins[new_len - 1]
      comp.active_window_id = top_win.id
    @else
      comp.active_window_id = ""
    @end
  @end
  return comp
@end

@fn compositor_get_window(comp, win_id)
  i = 0
  num_items = comp.windows.len()
  @while i < num_items
    w = comp.windows[i]
    @if w.id == win_id return w @end
    i = i + 1
  @end
  return 0
@end

@fn compositor_update_window(comp, win)
  i = 0
  num_items = comp.windows.len()
  @while i < num_items
    w = comp.windows[i]
    @if w.id == win.id
      comp.windows[i] = win
      return comp
    @end
    i = i + 1
  @end
  return comp
@end

@fn compositor_bring_to_front(comp, win_id)
  target_win = 0
  new_wins = []
  i = 0
  num_items = comp.windows.len()
  @while i < num_items
    w = comp.windows[i]
    @if w.id == win_id
      target_win = w
    @else
      new_wins = new_wins.push(w)
    @end
    i = i + 1
  @end
  
  @if target_win != 0 && target_win != none
    new_wins = new_wins.push(target_win)
    comp.active_window_id = win_id
  @end
  comp.windows = new_wins
  return comp
@end

@! ----------------------------------------------------------------------------
@! 4. COMPOSITOR EVENT DISPATCHING
@! ----------------------------------------------------------------------------

@fn compositor_dispatch_event(comp, event)
  @if comp == 0 || comp == none
    return comp
  @end
  
  num_wins = comp.windows.len()
  @if num_wins == 0
    return comp
  @end
  
  @! Mouse events: search windows from top to bottom
  @if event.kind == "MOUSE_DOWN" || event.kind == "MOUSE_UP" || event.kind == "MOUSE_CLICK"
    i = num_wins - 1
    @while i >= 0
      win = comp.windows[i]
      @if win.visible != false
        inside_win = event_point_in_rect(event.x, event.y, win.x, win.y, win.width, win.height)
        @if inside_win == true
          @! Bring window to front
          comp = compositor_bring_to_front(comp, win.id)
          
          @! Check close button [X]
          cb_x = (win.x + win.width) - 20
          cb_y = win.y + 3
          @if event.x >= cb_x && event.x <= (cb_x + 16) && event.y >= cb_y && event.y <= (cb_y + 16)
            @if event.kind == "MOUSE_CLICK" || event.kind == "MOUSE_DOWN"
              win.visible = false
              comp = compositor_update_window(comp, win)
              event.handled = true
              return comp
            @end
          @end
          
          @! Dispatch inside window
          target = event_hit_test(win, event.x, event.y)
          @if target != 0 && target != none
            event.target_id = target.id
            event.handled = true
            
            @if event.kind == "MOUSE_DOWN"
              target = widget_handle_mouse_down(target, event.x, event.y, event.button)
              win = widget_update_node(win, target)
              comp = compositor_update_window(comp, win)
            @elif event.kind == "MOUSE_UP"
              target = widget_handle_mouse_up(target, event.x, event.y, event.button)
              win = widget_update_node(win, target)
              comp = compositor_update_window(comp, win)
            @end
          @end
          
          return comp
        @end
      @end
      i = i - 1
    @end
  @end
  
  @! Key events: dispatch to active window
  @if event.kind == "KEY_DOWN" || event.kind == "CHAR_INPUT"
    @if comp.active_window_id != ""
      active_win = compositor_get_window(comp, comp.active_window_id)
      @if active_win != 0 && active_win != none
        @! Find focused child or default to window
        active_win = widget_handle_key(active_win, event.key_code, event.key_char, event.modifiers)
        comp = compositor_update_window(comp, active_win)
      @end
    @end
  @end
  
  return comp
@end

@! ----------------------------------------------------------------------------
@! 5. COMPOSITOR RENDERING (PAINTER'S ALGORITHM)
@! ----------------------------------------------------------------------------

@fn compositor_render(comp, font)
  @! 1. Clear desktop wallpaper
  comp.main_canvas = canvas_clear(comp.main_canvas, comp.background_color)
  
  @! 2. Render subtle desktop grid pattern
  grid_step = 32
  gx = 0
  @while gx < comp.width
    comp.main_canvas = canvas_draw_line(comp.main_canvas, gx, 0, gx, comp.height, 0xFF282828)
    gx = gx + grid_step
  @end
  gy = 0
  @while gy < comp.height
    comp.main_canvas = canvas_draw_line(comp.main_canvas, 0, gy, comp.width, gy, 0xFF282828)
    gy = gy + grid_step
  @end
  
  @! 3. Render Windows from bottom to top (z-order)
  i = 0
  num_items = comp.windows.len()
  @while i < num_items
    win = comp.windows[i]
    @if win.visible != false
      @! Render drop shadow
      shadow_offset = 6
      comp.main_canvas = canvas_fill_rect(comp.main_canvas, win.x + shadow_offset, win.y + shadow_offset, win.width, win.height, 0xFF101010)
      
      @! Render window contents
      comp.main_canvas = widget_render(win, comp.main_canvas, font)
    @end
    i = i + 1
  @end
  
  return comp.main_canvas
@end
