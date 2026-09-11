@! ============================================================================
@! MAYA NATIVE GUI FRAMEWORK — EVENT MODEL & DISPATCHER
@! Module: universe/gui/event.maya
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Features:
@! - Universal GuiEvent Data Model
@! - Reverse Z-Order Point-in-Rect Hit-Testing
@! - Event Bubbling & Handled Flag Propagation
@! - Focus Manager with Bidirectional Tab Navigation
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURE DEFINITIONS
@! ----------------------------------------------------------------------------

@struct GuiEvent
  kind: string
  x: i64
  y: i64
  button: i64
  wheel_delta: i64
  key_code: i64
  key_char: string
  modifiers: i64
  target_id: string
  handled: bool
@end

@struct FocusManager
  focused_id: string
  focus_chain: array
  tab_index: i64
@end

@! ----------------------------------------------------------------------------
@! 2. EVENT CONSTRUCTORS & FACTORIES
@! ----------------------------------------------------------------------------

@fn event_new(kind, x, y)
  return {
    kind: kind,
    x: x,
    y: y,
    button: 0,
    wheel_delta: 0,
    key_code: 0,
    key_char: "",
    modifiers: 0,
    target_id: "",
    handled: false
  }
@end

@fn event_mouse_new(kind, x, y, button)
  return {
    kind: kind,
    x: x,
    y: y,
    button: button,
    wheel_delta: 0,
    key_code: 0,
    key_char: "",
    modifiers: 0,
    target_id: "",
    handled: false
  }
@end

@fn event_key_new(kind, key_code, key_char, modifiers)
  return {
    kind: kind,
    x: 0,
    y: 0,
    button: 0,
    wheel_delta: 0,
    key_code: key_code,
    key_char: key_char,
    modifiers: modifiers,
    target_id: "",
    handled: false
  }
@end

@fn event_wheel_new(x, y, delta)
  return {
    kind: "MOUSE_WHEEL",
    x: x,
    y: y,
    button: 0,
    wheel_delta: delta,
    key_code: 0,
    key_char: "",
    modifiers: 0,
    target_id: "",
    handled: false
  }
@end

@! ----------------------------------------------------------------------------
@! 3. POINT-IN-RECT & HIT TESTING ENGINE
@! ----------------------------------------------------------------------------

@fn event_point_in_rect(px, py, rx, ry, rw, rh)
  @if px >= rx && px < (rx + rw) && py >= ry && py < (ry + rh)
    return true
  @end
  return false
@end

@fn event_hit_test(root_widget, click_x, click_y)
  @if root_widget == 0 || root_widget == none
    return 0
  @end
  @if root_widget.visible == false
    return 0
  @end
  
  inside = event_point_in_rect(click_x, click_y, root_widget.x, root_widget.y, root_widget.width, root_widget.height)
  @if inside == false
    return 0
  @end
  
  @! Search children in reverse z-order (topmost first)
  num_children = root_widget.children.len()
  i = num_children - 1
  @while i >= 0
    child = root_widget.children[i]
    @if child.visible != false
      hit = event_hit_test(child, click_x, click_y)
      @if hit != 0 && hit != none
        return hit
      @end
    @end
    i = i - 1
  @end
  
  return root_widget
@end

@! ----------------------------------------------------------------------------
@! 4. EVENT DISPATCH & BUBBLING
@! ----------------------------------------------------------------------------

@fn event_dispatch_bubble(root_widget, event)
  @if root_widget == 0 || root_widget == none
    return event
  @end
  
  @! Target identification: if target_id is specified, find node
  target = 0
  @if event.target_id != ""
    target = event_find_widget_by_id(root_widget, event.target_id)
  @elif event.kind == "MOUSE_DOWN" || event.kind == "MOUSE_UP" || event.kind == "MOUSE_CLICK" || event.kind == "MOUSE_MOVE"
    target = event_hit_test(root_widget, event.x, event.y)
  @end
  
  @if target == 0 || target == none
    target = root_widget
  @end
  
  event.target_id = target.id
  
  @! If target has click/change/submit action or is interactive, mark handled
  @if event.kind == "MOUSE_CLICK" || event.kind == "MOUSE_DOWN"
    @if target.kind == "Button" || target.kind == "button" || target.kind == "TextInput" || target.kind == "Slider"
      event.handled = true
      return event
    @end
  @end
  
  @if event.kind == "KEY_DOWN" || event.kind == "CHAR_INPUT"
    @if target.kind == "TextInput" || target.focused == true
      event.handled = true
      return event
    @end
  @end
  
  return event
@end

@fn event_find_widget_by_id(root, target_id)
  @if root == 0 || root == none
    return 0
  @end
  @if root.id == target_id
    return root
  @end
  
  num_children = root.children.len()
  i = 0
  @while i < num_children
    found = event_find_widget_by_id(root.children[i], target_id)
    @if found != 0 && found != none
      return found
    @end
    i = i + 1
  @end
  
  return 0
@end

@! ----------------------------------------------------------------------------
@! 5. FOCUS MANAGER & TAB TRAVERSAL
@! ----------------------------------------------------------------------------

@fn focus_manager_new()
  return {
    focused_id: "",
    focus_chain: [],
    tab_index: 0
  }
@end

@fn focus_manager_collect_focusable(widget)
  res = []
  @if widget == 0 || widget == none
    return res
  @end
  @if widget.visible == false || widget.enabled == false
    return res
  @end
  
  k = widget.kind
  @if k == "Button" || k == "button" || k == "TextInput" || k == "input" || k == "Slider" || k == "slider" || k == "Checkbox" || k == "checkbox"
    @if widget.id != ""
      res = res.push(widget.id)
    @end
  @end
  
  num_children = widget.children.len()
  i = 0
  @while i < num_children
    child_ids = focus_manager_collect_focusable(widget.children[i])
    j = 0
    clen = child_ids.len()
    @while j < clen
      res = res.push(child_ids[j])
      j = j + 1
    @end
    i = i + 1
  @end
  
  return res
@end

@fn focus_manager_build_chain(fm, root_widget)
  chain = focus_manager_collect_focusable(root_widget)
  fm.focus_chain = chain
  
  @! Find current tab_index
  fm.tab_index = 0
  i = 0
  num_items = chain.len()
  @while i < num_items
    @if chain[i] == fm.focused_id
      fm.tab_index = i
      return fm
    @end
    i = i + 1
  @end
  
  @if num_items > 0 && fm.focused_id == ""
    fm.focused_id = chain[0]
  @end
  
  return fm
@end

@fn focus_manager_set_focus(fm, root_widget, widget_id)
  old_id = fm.focused_id
  fm.focused_id = widget_id
  
  @! Sync tab_index
  i = 0
  num_items = fm.focus_chain.len()
  @while i < num_items
    @if fm.focus_chain[i] == widget_id
      fm.tab_index = i
    @end
    i = i + 1
  @end
  
  return fm
@end

@fn focus_manager_tab_next(fm, root_widget)
  num_items = fm.focus_chain.len()
  @if num_items == 0
    fm = focus_manager_build_chain(fm, root_widget)
    num_items = fm.focus_chain.len()
  @end
  
  @if num_items == 0
    return fm
  @end
  
  next_idx = (fm.tab_index + 1) % num_items
  fm.tab_index = next_idx
  fm.focused_id = fm.focus_chain[next_idx]
  return fm
@end

@fn focus_manager_tab_prev(fm, root_widget)
  num_items = fm.focus_chain.len()
  @if num_items == 0
    fm = focus_manager_build_chain(fm, root_widget)
    num_items = fm.focus_chain.len()
  @end
  
  @if num_items == 0
    return fm
  @end
  
  prev_idx = (fm.tab_index - 1 + num_items) % num_items
  fm.tab_index = prev_idx
  fm.focused_id = fm.focus_chain[prev_idx]
  return fm
@end
