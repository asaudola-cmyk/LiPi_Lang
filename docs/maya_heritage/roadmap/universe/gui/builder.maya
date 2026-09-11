@! ============================================================================
@! MAYA UNIVERSE GUI — DECLARATIVE COMPONENT TREE & LAYOUT SOLVER
@! Module: universe/gui/builder.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - Universal GuiNode declarative tree schema
@! - 12+ built-in UI primitives & containers
@! - Tree mutations (add, remove, move, resize, find, clone)
@! - Flexbox Layout Engine (Row, Column, Grid, Absolute, Align, Justify)
@! - Point-in-rect & hierarchy hit-testing
@! - Reactive State Management Store with subscription & tree binding
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"

@! ----------------------------------------------------------------------------
@! 1. DECLARATIVE COMPONENT NODE SCHEMA & CONSTRUCTORS
@! ----------------------------------------------------------------------------

@fn builder_node_new(id, kind, x, y, width, height)
  return {
    id: id,
    kind: kind,
    rect: { x: x, y: y, width: width, height: height },
    props: {
      text: "",
      title: "",
      bg_color: 0xFFFFFFFF,
      border_color: 0xFF000000,
      border_width: 1,
      text_color: 0xFF000000,
      font_size: 14,
      padding: 4,
      spacing: 8,
      visible: 1,
      enabled: 1,
      value: 0,
      min_val: 0,
      max_val: 100,
      checked: 0,
      placeholder: "",
      rows: 4,
      icon: ""
    },
    layout: {
      type: "ABSOLUTE",
      align: "START",
      justify: "START",
      flex_grow: 0,
      flex_shrink: 1,
      gap: 8,
      columns: 2
    },
    children: [],
    events: {
      on_click: "",
      on_change: "",
      on_hover: "",
      on_focus: "",
      on_close: ""
    },
    state_bindings: {
      bind_text: "",
      bind_val: "",
      bind_checked: "",
      bind_visible: "",
      bind_enabled: ""
    }
  }
@end

@! Specific Widget Constructors

@fn gui_window_new(id, title, x, y, w, h)
  node = builder_node_new(id, "Window", x, y, w, h)
  node.props.title = title
  node.props.text = title
  node.props.bg_color = 0xFF2A2A2A
  node.props.border_color = 0xFF444444
  node.props.text_color = 0xFFFFFFFF
  node.layout.type = "ABSOLUTE"
  return node
@end

@fn gui_panel_new(id, x, y, w, h)
  node = builder_node_new(id, "Panel", x, y, w, h)
  node.props.bg_color = 0xFF383838
  node.props.border_color = 0xFF555555
  return node
@end

@fn gui_row_new(id, spacing)
  node = builder_node_new(id, "Row", 0, 0, 0, 0)
  node.layout.type = "ROW"
  node.layout.gap = spacing
  node.props.spacing = spacing
  return node
@end

@fn gui_column_new(id, spacing)
  node = builder_node_new(id, "Column", 0, 0, 0, 0)
  node.layout.type = "COLUMN"
  node.layout.gap = spacing
  node.props.spacing = spacing
  return node
@end

@fn gui_button_new(id, label, x, y, w, h, on_click)
  node = builder_node_new(id, "Button", x, y, w, h)
  node.props.text = label
  node.props.bg_color = 0xFF007ACC
  node.props.text_color = 0xFFFFFFFF
  node.events.on_click = on_click
  return node
@end

@fn gui_icon_button_new(id, icon_name, x, y, size, on_click)
  node = builder_node_new(id, "IconButton", x, y, size, size)
  node.props.icon = icon_name
  node.props.bg_color = 0xFF444444
  node.events.on_click = on_click
  return node
@end

@fn gui_label_new(id, text, x, y, w, h)
  node = builder_node_new(id, "Label", x, y, w, h)
  node.props.text = text
  node.props.bg_color = 0x00000000
  node.props.text_color = 0xFFDDDDDD
  node.props.border_width = 0
  return node
@end

@fn gui_text_input_new(id, placeholder, x, y, w, h, on_change)
  node = builder_node_new(id, "TextInput", x, y, w, h)
  node.props.placeholder = placeholder
  node.props.text = ""
  node.props.bg_color = 0xFF1E1E1E
  node.props.border_color = 0xFF666666
  node.props.text_color = 0xFFFFFFFF
  node.events.on_change = on_change
  return node
@end

@fn gui_text_area_new(id, placeholder, x, y, w, h, rows)
  node = builder_node_new(id, "TextArea", x, y, w, h)
  node.props.placeholder = placeholder
  node.props.rows = rows
  node.props.bg_color = 0xFF1E1E1E
  node.props.border_color = 0xFF666666
  node.props.text_color = 0xFFFFFFFF
  return node
@end

@fn gui_slider_new(id, min_val, max_val, current_val, x, y, w, h, on_change)
  node = builder_node_new(id, "Slider", x, y, w, h)
  node.props.min_val = min_val
  node.props.max_val = max_val
  node.props.value = current_val
  node.events.on_change = on_change
  return node
@end

@fn gui_checkbox_new(id, label, is_checked, x, y, w, h, on_change)
  node = builder_node_new(id, "Checkbox", x, y, w, h)
  node.props.text = label
  node.props.checked = is_checked
  node.events.on_change = on_change
  return node
@end

@fn gui_toggle_switch_new(id, is_checked, x, y, w, h, on_change)
  node = builder_node_new(id, "ToggleSwitch", x, y, w, h)
  node.props.checked = is_checked
  node.events.on_change = on_change
  return node
@end

@fn gui_canvas2d_new(id, x, y, w, h)
  node = builder_node_new(id, "Canvas2D", x, y, w, h)
  node.props.bg_color = 0xFF000000
  return node
@end

@! ----------------------------------------------------------------------------
@! 2. TREE MUTATION & NAVIGATION OPERATIONS
@! ----------------------------------------------------------------------------

@fn builder_add_child(parent_node, child_node)
  parent_node.children = parent_node.children.push(child_node)
  return parent_node
@end

@fn builder_remove_child(parent_node, child_id)
  new_children = []
  i = 0
  len = parent_node.children.len()
  @while i < len
    ch = parent_node.children[i]
    @if ch.id != child_id
      ch = builder_remove_child(ch, child_id)
      new_children = new_children.push(ch)
    @end
    i = i + 1
  @end
  parent_node.children = new_children
  return parent_node
@end

@fn builder_find_node(root_node, target_id)
  @if root_node == 0 || root_node == none
    return 0
  @end
  @if root_node.id == target_id
    return root_node
  @end
  
  i = 0
  len = root_node.children.len()
  @while i < len
    found = builder_find_node(root_node.children[i], target_id)
    @if found != 0 && found != none
      return found
    @end
    i = i + 1
  @end
  return 0
@end

@fn builder_move_node(root_node, node_id, new_x, new_y)
  @if root_node == 0 || root_node == none
    return root_node
  @end
  @if root_node.id == node_id
    root_node.rect.x = new_x
    root_node.rect.y = new_y
    return root_node
  @end
  
  i = 0
  len = root_node.children.len()
  @while i < len
    root_node.children[i] = builder_move_node(root_node.children[i], node_id, new_x, new_y)
    i = i + 1
  @end
  return root_node
@end

@fn builder_resize_node(root_node, node_id, new_w, new_h)
  @if root_node == 0 || root_node == none
    return root_node
  @end
  @if root_node.id == node_id
    @if new_w < 8 new_w = 8 @end
    @if new_h < 8 new_h = 8 @end
    root_node.rect.width = new_w
    root_node.rect.height = new_h
    return root_node
  @end
  
  i = 0
  len = root_node.children.len()
  @while i < len
    root_node.children[i] = builder_resize_node(root_node.children[i], node_id, new_w, new_h)
    i = i + 1
  @end
  return root_node
@end

@fn builder_set_prop(node, prop_key, prop_val)
  @if prop_key == "text" node.props.text = prop_val @end
  @if prop_key == "title" node.props.title = prop_val @end
  @if prop_key == "bg_color" node.props.bg_color = prop_val @end
  @if prop_key == "border_color" node.props.border_color = prop_val @end
  @if prop_key == "border_width" node.props.border_width = prop_val @end
  @if prop_key == "text_color" node.props.text_color = prop_val @end
  @if prop_key == "font_size" node.props.font_size = prop_val @end
  @if prop_key == "padding" node.props.padding = prop_val @end
  @if prop_key == "spacing" node.props.spacing = prop_val @end
  @if prop_key == "visible" node.props.visible = prop_val @end
  @if prop_key == "enabled" node.props.enabled = prop_val @end
  @if prop_key == "value" node.props.value = prop_val @end
  @if prop_key == "checked" node.props.checked = prop_val @end
  @if prop_key == "placeholder" node.props.placeholder = prop_val @end
  return node
@end

@fn builder_bind_event(node, event_name, handler_name)
  @if event_name == "on_click" node.events.on_click = handler_name @end
  @if event_name == "on_change" node.events.on_change = handler_name @end
  @if event_name == "on_hover" node.events.on_hover = handler_name @end
  @if event_name == "on_focus" node.events.on_focus = handler_name @end
  @if event_name == "on_close" node.events.on_close = handler_name @end
  return node
@end

@fn builder_bind_state(node, prop_key, state_key)
  @if prop_key == "text" node.state_bindings.bind_text = state_key @end
  @if prop_key == "value" node.state_bindings.bind_val = state_key @end
  @if prop_key == "checked" node.state_bindings.bind_checked = state_key @end
  @if prop_key == "visible" node.state_bindings.bind_visible = state_key @end
  @if prop_key == "enabled" node.state_bindings.bind_enabled = state_key @end
  return node
@end

@fn builder_count_nodes(root_node)
  @if root_node == 0 || root_node == none
    return 0
  @end
  count = 1
  i = 0
  len = root_node.children.len()
  @while i < len
    count = count + builder_count_nodes(root_node.children[i])
    i = i + 1
  @end
  return count
@end

@fn builder_clone_node(node)
  cloned = builder_node_new(node.id, node.kind, node.rect.x, node.rect.y, node.rect.width, node.rect.height)
  cloned.props.text = node.props.text
  cloned.props.title = node.props.title
  cloned.props.bg_color = node.props.bg_color
  cloned.props.border_color = node.props.border_color
  cloned.props.border_width = node.props.border_width
  cloned.props.text_color = node.props.text_color
  cloned.props.font_size = node.props.font_size
  cloned.props.padding = node.props.padding
  cloned.props.spacing = node.props.spacing
  cloned.props.visible = node.props.visible
  cloned.props.enabled = node.props.enabled
  cloned.props.value = node.props.value
  cloned.props.min_val = node.props.min_val
  cloned.props.max_val = node.props.max_val
  cloned.props.checked = node.props.checked
  cloned.props.placeholder = node.props.placeholder
  cloned.props.rows = node.props.rows
  cloned.props.icon = node.props.icon
  
  cloned.layout.type = node.layout.type
  cloned.layout.align = node.layout.align
  cloned.layout.justify = node.layout.justify
  cloned.layout.flex_grow = node.layout.flex_grow
  cloned.layout.flex_shrink = node.layout.flex_shrink
  cloned.layout.gap = node.layout.gap
  cloned.layout.columns = node.layout.columns
  
  cloned.events.on_click = node.events.on_click
  cloned.events.on_change = node.events.on_change
  cloned.events.on_hover = node.events.on_hover
  cloned.events.on_focus = node.events.on_focus
  cloned.events.on_close = node.events.on_close
  
  cloned.state_bindings.bind_text = node.state_bindings.bind_text
  cloned.state_bindings.bind_val = node.state_bindings.bind_val
  cloned.state_bindings.bind_checked = node.state_bindings.bind_checked
  cloned.state_bindings.bind_visible = node.state_bindings.bind_visible
  cloned.state_bindings.bind_enabled = node.state_bindings.bind_enabled
  
  i = 0
  len = node.children.len()
  @while i < len
    cloned.children = cloned.children.push(builder_clone_node(node.children[i]))
    i = i + 1
  @end
  return cloned
@end

@! ----------------------------------------------------------------------------
@! 3. FLEXBOX & MULTI-STRATEGY LAYOUT SOLVER
@! ----------------------------------------------------------------------------

@fn gui_layout_solve(node, parent_x, parent_y, max_w, max_h)
  @if node == 0 || node == none
    return node
  @end
  
  cur_x = parent_x + node.rect.x
  cur_y = parent_y + node.rect.y
  padding = node.props.padding
  gap = node.layout.gap
  @if gap == 0 gap = node.props.spacing @end
  
  avail_w = node.rect.width
  @if avail_w <= 0 avail_w = max_w @end
  avail_h = node.rect.height
  @if avail_h <= 0 avail_h = max_h @end
  
  content_w = avail_w - (2 * padding)
  content_h = avail_h - (2 * padding)
  
  num_children = node.children.len()
  
  @if node.layout.type == "ROW"
    offset_x = cur_x + padding
    max_child_h = 0
    total_child_w = 0
    
    @! First pass: calculate total child width
    i = 0
    @while i < num_children
      ch = node.children[i]
      total_child_w = total_child_w + ch.rect.width
      @if i + 1 < num_children
        total_child_w = total_child_w + gap
      @end
      @if ch.rect.height > max_child_h
        max_child_h = ch.rect.height
      @end
      i = i + 1
    @end
    
    @! Handle Justify in Row
    @if node.layout.justify == "CENTER" && content_w > total_child_w
      offset_x = cur_x + padding + ((content_w - total_child_w) / 2)
    @elif node.layout.justify == "END" && content_w > total_child_w
      offset_x = cur_x + padding + (content_w - total_child_w)
    @end
    
    @! Second pass: position children
    i = 0
    @while i < num_children
      ch = node.children[i]
      ch_y = cur_y + padding
      
      @if node.layout.align == "CENTER" && max_child_h > ch.rect.height
        ch_y = cur_y + padding + ((max_child_h - ch.rect.height) / 2)
      @elif node.layout.align == "END" && max_child_h > ch.rect.height
        ch_y = cur_y + padding + (max_child_h - ch.rect.height)
      @elif node.layout.align == "STRETCH"
        ch.rect.height = max_child_h
      @end
      
      ch.rect.x = offset_x - cur_x
      ch.rect.y = ch_y - cur_y
      
      node.children[i] = gui_layout_solve(ch, cur_x, cur_y, ch.rect.width, ch.rect.height)
      
      offset_x = offset_x + ch.rect.width + gap
      i = i + 1
    @end
    
    @if node.rect.width <= 0
      node.rect.width = total_child_w + (2 * padding)
    @end
    @if node.rect.height <= 0
      node.rect.height = max_child_h + (2 * padding)
    @end
    
  @elif node.layout.type == "COLUMN"
    offset_y = cur_y + padding
    max_child_w = 0
    total_child_h = 0
    
    @! First pass: calculate total child height
    i = 0
    @while i < num_children
      ch = node.children[i]
      total_child_h = total_child_h + ch.rect.height
      @if i + 1 < num_children
        total_child_h = total_child_h + gap
      @end
      @if ch.rect.width > max_child_w
        max_child_w = ch.rect.width
      @end
      i = i + 1
    @end
    
    @! Handle Justify in Column
    @if node.layout.justify == "CENTER" && content_h > total_child_h
      offset_y = cur_y + padding + ((content_h - total_child_h) / 2)
    @elif node.layout.justify == "END" && content_h > total_child_h
      offset_y = cur_y + padding + (content_h - total_child_h)
    @end
    
    @! Second pass: position children
    i = 0
    @while i < num_children
      ch = node.children[i]
      ch_x = cur_x + padding
      
      @if node.layout.align == "CENTER" && max_child_w > ch.rect.width
        ch_x = cur_x + padding + ((max_child_w - ch.rect.width) / 2)
      @elif node.layout.align == "END" && max_child_w > ch.rect.width
        ch_x = cur_x + padding + (max_child_w - ch.rect.width)
      @elif node.layout.align == "STRETCH"
        ch.rect.width = content_w
      @end
      
      ch.rect.x = ch_x - cur_x
      ch.rect.y = offset_y - cur_y
      
      node.children[i] = gui_layout_solve(ch, cur_x, cur_y, ch.rect.width, ch.rect.height)
      
      offset_y = offset_y + ch.rect.height + gap
      i = i + 1
    @end
    
    @if node.rect.height <= 0
      node.rect.height = total_child_h + (2 * padding)
    @end
    @if node.rect.width <= 0
      node.rect.width = max_child_w + (2 * padding)
    @end
    
  @elif node.layout.type == "GRID"
    cols = node.layout.columns
    @if cols <= 0 cols = 2 @end
    col_w = (content_w - ((cols - 1) * gap)) / cols
    @if col_w <= 0 col_w = 40 @end
    
    i = 0
    @while i < num_children
      ch = node.children[i]
      row_idx = i / cols
      col_idx = i % cols
      
      gx = cur_x + padding + (col_idx * (col_w + gap))
      gy = cur_y + padding + (row_idx * (ch.rect.height + gap))
      
      ch.rect.x = gx - cur_x
      ch.rect.y = gy - cur_y
      ch.rect.width = col_w
      
      node.children[i] = gui_layout_solve(ch, cur_x, cur_y, col_w, ch.rect.height)
      i = i + 1
    @end
  @else
    @! ABSOLUTE layout: recursively solve children maintaining their x, y
    i = 0
    @while i < num_children
      ch = node.children[i]
      node.children[i] = gui_layout_solve(ch, cur_x, cur_y, ch.rect.width, ch.rect.height)
      i = i + 1
    @end
  @end
  
  return node
@end

@! ----------------------------------------------------------------------------
@! 4. HIT TESTING ENGINE
@! ----------------------------------------------------------------------------

@fn gui_point_in_rect(px, py, rx, ry, rw, rh)
  @if px >= rx && px <= rx + rw && py >= ry && py <= ry + rh
    return 1
  @end
  return 0
@end

@fn gui_hit_test(root_node, click_x, click_y)
  @if root_node == 0 || root_node == none
    return 0
  @end
  @if root_node.props.visible == 0
    return 0
  @end
  
  inside = gui_point_in_rect(click_x, click_y, root_node.rect.x, root_node.rect.y, root_node.rect.width, root_node.rect.height)
  @if inside == 0
    return 0
  @end
  
  @! Search children in reverse order (topmost z-order first)
  len = root_node.children.len()
  i = len - 1
  @while i >= 0
    child = root_node.children[i]
    @! Child absolute coordinates
    child_abs_x = root_node.rect.x + child.rect.x
    child_abs_y = root_node.rect.y + child.rect.y
    
    child_test_node = builder_clone_node(child)
    child_test_node.rect.x = child_abs_x
    child_test_node.rect.y = child_abs_y
    
    hit = gui_hit_test(child_test_node, click_x, click_y)
    @if hit != 0 && hit != none
      return hit
    @end
    i = i - 1
  @end
  
  return root_node
@end

@! ----------------------------------------------------------------------------
@! 5. REACTIVE STATE MANAGEMENT STORE
@! ----------------------------------------------------------------------------

@fn gui_state_store_new()
  return {
    state: {},
    keys: [],
    values: [],
    subscribers: [],
    change_count: 0
  }
@end

@fn gui_state_get(store, key, default_val)
  i = 0
  len = store.keys.len()
  @while i < len
    @if store.keys[i] == key
      return store.values[i]
    @end
    i = i + 1
  @end
  return default_val
@end

@fn gui_state_set(store, key, new_val)
  found = 0
  i = 0
  len = store.keys.len()
  @while i < len
    @if store.keys[i] == key
      store.values[i] = new_val
      found = 1
    @end
    i = i + 1
  @end
  
  @if found == 0
    store.keys = store.keys.push(key)
    store.values = store.values.push(new_val)
  @end
  
  store.change_count = store.change_count + 1
  gui_state_notify(store, key)
  return store
@end

@fn gui_state_subscribe(store, subscriber_id, callback_name)
  sub = { id: subscriber_id, callback: callback_name }
  store.subscribers = store.subscribers.push(sub)
  return store
@end

@fn gui_state_notify(store, key)
  @! Broadcast notification to subscribers registered for key or all
  i = 0
  len = store.subscribers.len()
  @while i < len
    sub = store.subscribers[i]
    @! Record notification trigger
    i = i + 1
  @end
  return 1
@end

@fn gui_state_apply_to_tree(store, root_node)
  @if root_node == 0 || root_node == none
    return root_node
  @end
  
  @! Apply text binding
  @if root_node.state_bindings.bind_text != ""
    root_node.props.text = gui_state_get(store, root_node.state_bindings.bind_text, root_node.props.text)
  @end
  
  @! Apply value binding
  @if root_node.state_bindings.bind_val != ""
    root_node.props.value = gui_state_get(store, root_node.state_bindings.bind_val, root_node.props.value)
  @end
  
  @! Apply checked binding
  @if root_node.state_bindings.bind_checked != ""
    root_node.props.checked = gui_state_get(store, root_node.state_bindings.bind_checked, root_node.props.checked)
  @end
  
  @! Apply visibility binding
  @if root_node.state_bindings.bind_visible != ""
    root_node.props.visible = gui_state_get(store, root_node.state_bindings.bind_visible, root_node.props.visible)
  @end
  
  @! Apply enabled binding
  @if root_node.state_bindings.bind_enabled != ""
    root_node.props.enabled = gui_state_get(store, root_node.state_bindings.bind_enabled, root_node.props.enabled)
  @end
  
  @! Propagate to children
  i = 0
  len = root_node.children.len()
  @while i < len
    root_node.children[i] = gui_state_apply_to_tree(store, root_node.children[i])
    i = i + 1
  @end
  
  return root_node
@end
