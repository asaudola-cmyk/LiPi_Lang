@! ============================================================================
@! MAYA UNIVERSE GUI — CODE GENERATOR & PROJECT SERIALIZER (.mayagui)
@! Module: universe/gui/codegen.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - Pure Maya GUI Code Generator (Transpiles declarative tree to native source)
@! - Emits standalone, runnable Pure Maya application files
@! - JSON Project Persistence (.mayagui format via universe/core/json.maya)
@! - Bidirectional serialization / deserialization roundtrip
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/json"
import "universe/gui/builder"

@! ----------------------------------------------------------------------------
@! 1. PURE MAYA CODE GENERATOR (TRANSPILER)
@! ----------------------------------------------------------------------------

@fn gui_codegen_emit_event_handlers(node)
  @if node == 0 || node == none
    return ""
  @end
  
  handlers = ""
  @if node.events.on_click != "" && node.events.on_click != "none"
    handlers = handlers + "@fn " + node.events.on_click + "()\n"
    handlers = handlers + "  println(\"⚡ Event Triggered: " + node.events.on_click + " on widget " + node.id + "\")\n"
    handlers = handlers + "  return 1\n"
    handlers = handlers + "@end\n\n"
  @end
  
  @if node.events.on_change != "" && node.events.on_change != "none"
    handlers = handlers + "@fn " + node.events.on_change + "(new_val)\n"
    handlers = handlers + "  println(\"🔄 Value Changed: " + node.events.on_change + " = \" + new_val.to_str())\n"
    handlers = handlers + "  return 1\n"
    handlers = handlers + "@end\n\n"
  @end
  
  i = 0
  len = node.children.len()
  @while i < len
    handlers = handlers + gui_codegen_emit_event_handlers(node.children[i])
    i = i + 1
  @end
  
  return handlers
@end

@fn gui_codegen_emit_children_code(node, parent_var)
  @if node == 0 || node == none
    return ""
  @end
  
  code = ""
  i = 0
  len = node.children.len()
  @while i < len
    ch = node.children[i]
    var_name = "widget_" + ch.id
    
    @if ch.kind == "Button"
      code = code + "  " + var_name + " = button_new(\"" + ch.id + "\", \"" + ch.props.text + "\", " + ch.rect.x.to_str() + ", " + ch.rect.y.to_str() + ", " + ch.rect.width.to_str() + ", " + ch.rect.height.to_str() + ")\n"
      code = code + "  " + parent_var + " = window_add_child(" + parent_var + ", " + var_name + ")\n"
    @elif ch.kind == "TextInput"
      code = code + "  " + var_name + " = { kind: \"TEXT_INPUT\", id: \"" + ch.id + "\", placeholder: \"" + ch.props.placeholder + "\", x: " + ch.rect.x.to_str() + ", y: " + ch.rect.y.to_str() + ", width: " + ch.rect.width.to_str() + ", height: " + ch.rect.height.to_str() + " }\n"
      code = code + "  " + parent_var + " = window_add_child(" + parent_var + ", " + var_name + ")\n"
    @elif ch.kind == "Label"
      code = code + "  " + var_name + " = { kind: \"LABEL\", id: \"" + ch.id + "\", text: \"" + ch.props.text + "\", x: " + ch.rect.x.to_str() + ", y: " + ch.rect.y.to_str() + ", width: " + ch.rect.width.to_str() + ", height: " + ch.rect.height.to_str() + " }\n"
      code = code + "  " + parent_var + " = window_add_child(" + parent_var + ", " + var_name + ")\n"
    @elif ch.kind == "Slider"
      code = code + "  " + var_name + " = { kind: \"SLIDER\", id: \"" + ch.id + "\", min: " + ch.props.min_val.to_str() + ", max: " + ch.props.max_val.to_str() + ", val: " + ch.props.value.to_str() + ", x: " + ch.rect.x.to_str() + ", y: " + ch.rect.y.to_str() + ", width: " + ch.rect.width.to_str() + ", height: " + ch.rect.height.to_str() + " }\n"
      code = code + "  " + parent_var + " = window_add_child(" + parent_var + ", " + var_name + ")\n"
    @elif ch.kind == "Checkbox"
      code = code + "  " + var_name + " = { kind: \"CHECKBOX\", id: \"" + ch.id + "\", text: \"" + ch.props.text + "\", checked: " + ch.props.checked.to_str() + ", x: " + ch.rect.x.to_str() + ", y: " + ch.rect.y.to_str() + ", width: " + ch.rect.width.to_str() + ", height: " + ch.rect.height.to_str() + " }\n"
      code = code + "  " + parent_var + " = window_add_child(" + parent_var + ", " + var_name + ")\n"
    @else
      code = code + "  " + var_name + " = { kind: \"" + ch.kind + "\", id: \"" + ch.id + "\", x: " + ch.rect.x.to_str() + ", y: " + ch.rect.y.to_str() + ", width: " + ch.rect.width.to_str() + ", height: " + ch.rect.height.to_str() + " }\n"
      code = code + "  " + parent_var + " = window_add_child(" + parent_var + ", " + var_name + ")\n"
    @end
    
    @! Recursively emit grandchildren
    @if ch.children.len() > 0
      code = code + gui_codegen_emit_children_code(ch, var_name)
    @end
    
    i = i + 1
  @end
  
  return code
@end

@fn gui_codegen_generate(root_node)
  return gui_codegen_generate_app(root_node)
@end

@fn gui_codegen_generate_app(root_node)
  @if root_node == 0 || root_node == none
    return "@fn main() return 0 @end"
  @end
  
  title = root_node.props.title
  @if title == "" title = root_node.props.text @end
  @if title == "" title = "Maya Application" @end
  
  win_w = root_node.rect.width
  @if win_w <= 0 win_w = 640 @end
  win_h = root_node.rect.height
  @if win_h <= 0 win_h = 480 @end
  win_x = root_node.rect.x
  win_y = root_node.rect.y
  
  code = "@! ============================================================================\n"
  code = code + "@! AUTO-GENERATED MAYA NATIVE GUI APPLICATION\n"
  code = code + "@! Generated by Maya Native Visual GUI Builder Codegen Engine\n"
  code = code + "@! 100% Pure Maya Language — Zero External Dependencies\n"
  code = code + "@! ============================================================================\n\n"
  
  code = code + "import \"universe/gui/window\"\n"
  code = code + "import \"universe/gui/framebuffer\"\n"
  code = code + "import \"universe/gui/compositor\"\n"
  code = code + "import \"universe/gui/font\"\n\n"
  
  @! 1. Emit Main Function (Entry Point)
  code = code + "@fn main()\n"
  code = code + "  println(\"🚀 Initializing Native Maya GUI Application: " + title + "\")\n"
  code = code + "  fb = framebuffer_new(" + win_w.to_str() + ", " + win_h.to_str() + ")\n"
  code = code + "  comp = compositor_init(fb)\n"
  code = code + "  win = window_new(\"" + root_node.id + "\", \"" + title + "\", " + win_x.to_str() + ", " + win_y.to_str() + ", " + win_w.to_str() + ", " + win_h.to_str() + ")\n\n"
  
  @! 2. Emit Child Widgets
  code = code + "  @! UI Components Initialization\n"
  code = code + gui_codegen_emit_children_code(root_node, "win")
  
  code = code + "\n  @! Compositor Layering & Rendering\n"
  code = code + "  comp = compositor_add_window(comp, win)\n"
  code = code + "  compositor_render(comp)\n"
  code = code + "  println(\"✅ GUI Render Loop Initialized Successfully.\")\n"
  code = code + "  return 0\n"
  code = code + "@end\n\n"
  
  @! 3. Emit Event Handler Callback Stubs
  code = code + "@! ----------------------------------------------------------------------------\n"
  code = code + "@! EVENT HANDLERS & CALLBACKS\n"
  code = code + "@! ----------------------------------------------------------------------------\n"
  code = code + gui_codegen_emit_event_handlers(root_node)
  
  return code
@end

@! ----------------------------------------------------------------------------
@! 2. JSON PROJECT SERIALIZATION (.mayagui FORMAT)
@! ----------------------------------------------------------------------------

@fn gui_node_to_json_str(node, indent)
  @if node == 0 || node == none
    return "{}"
  @end
  
  ind = indent + "  "
  
  res = "{\n"
  res = res + ind + "\"id\": \"" + node.id + "\",\n"
  res = res + ind + "\"kind\": \"" + node.kind + "\",\n"
  res = res + ind + "\"rect\": { \"x\": " + node.rect.x.to_str() + ", \"y\": " + node.rect.y.to_str() + ", \"width\": " + node.rect.width.to_str() + ", \"height\": " + node.rect.height.to_str() + " },\n"
  res = res + ind + "\"props\": { "
  res = res + "\"text\": \"" + node.props.text + "\", "
  res = res + "\"title\": \"" + node.props.title + "\", "
  res = res + "\"bg_color\": " + node.props.bg_color.to_str() + ", "
  res = res + "\"border_color\": " + node.props.border_color.to_str() + ", "
  res = res + "\"border_width\": " + node.props.border_width.to_str() + ", "
  res = res + "\"text_color\": " + node.props.text_color.to_str() + ", "
  res = res + "\"font_size\": " + node.props.font_size.to_str() + ", "
  res = res + "\"padding\": " + node.props.padding.to_str() + ", "
  res = res + "\"spacing\": " + node.props.spacing.to_str() + ", "
  res = res + "\"visible\": " + node.props.visible.to_str() + ", "
  res = res + "\"enabled\": " + node.props.enabled.to_str() + ", "
  res = res + "\"value\": " + node.props.value.to_str() + ", "
  res = res + "\"checked\": " + node.props.checked.to_str() + ", "
  res = res + "\"placeholder\": \"" + node.props.placeholder + "\" },\n"
  
  res = res + ind + "\"layout\": { \"type\": \"" + node.layout.type + "\", \"align\": \"" + node.layout.align + "\", \"justify\": \"" + node.layout.justify + "\", \"gap\": " + node.layout.gap.to_str() + " },\n"
  res = res + ind + "\"events\": { \"on_click\": \"" + node.events.on_click + "\", \"on_change\": \"" + node.events.on_change + "\" },\n"
  res = res + ind + "\"state_bindings\": { \"bind_text\": \"" + node.state_bindings.bind_text + "\", \"bind_val\": \"" + node.state_bindings.bind_val + "\" },\n"
  
  res = res + ind + "\"children\": [\n"
  i = 0
  len = node.children.len()
  @while i < len
    res = res + ind + "  " + gui_node_to_json_str(node.children[i], ind + "  ")
    @if i + 1 < len
      res = res + ",\n"
    @else
      res = res + "\n"
    @end
    i = i + 1
  @end
  res = res + ind + "]\n"
  res = res + indent + "}"
  
  return res
@end

@fn gui_builder_export_json(root_node, project_name)
  json_res = "{\n"
  json_res = json_res + "  \"version\": \"1.0.0\",\n"
  json_res = json_res + "  \"project_name\": \"" + project_name + "\",\n"
  json_res = json_res + "  \"root\": " + gui_node_to_json_str(root_node, "  ") + "\n"
  json_res = json_res + "}\n"
  return json_res
@end

@fn gui_node_from_json_dict(dict_val)
  @if dict_val == 0 || dict_val == none
    return gui_window_new("default_win", "Window", 0, 0, 400, 300)
  @end
  
  id = "node"
  kind = "Panel"
  x = 0
  y = 0
  w = 100
  h = 30
  text = ""
  title = ""
  bg_color = 0xFFFFFFFF
  border_color = 0xFF000000
  border_width = 1
  text_color = 0xFF000000
  font_size = 14
  padding = 4
  spacing = 8
  visible = 1
  enabled = 1
  value = 0
  checked = 0
  placeholder = ""
  
  l_type = "ABSOLUTE"
  l_align = "START"
  l_justify = "START"
  l_gap = 8
  
  ev_click = ""
  ev_change = ""
  
  bind_text = ""
  bind_val = ""
  
  children_raw = []
  
  @! Parse JSON fields from dictionary representation
  i = 0
  len = dict_val.len()
  @while i < len
    item = dict_val[i]
    k = item.key
    v = item.value
    
    @if k == "id" id = v.to_str() @end
    @if k == "kind" kind = v.to_str() @end
    @if k == "rect"
      @! Rect object
      ri = 0
      rlen = v.len()
      @while ri < rlen
        re = v[ri]
        @if re.key == "x" x = re.value @end
        @if re.key == "y" y = re.value @end
        @if re.key == "width" w = re.value @end
        @if re.key == "height" h = re.value @end
        ri = ri + 1
      @end
    @end
    @if k == "props"
      pi = 0
      plen = v.len()
      @while pi < plen
        pe = v[pi]
        @if pe.key == "text" text = pe.value.to_str() @end
        @if pe.key == "title" title = pe.value.to_str() @end
        @if pe.key == "bg_color" bg_color = pe.value @end
        @if pe.key == "border_color" border_color = pe.value @end
        @if pe.key == "border_width" border_width = pe.value @end
        @if pe.key == "text_color" text_color = pe.value @end
        @if pe.key == "font_size" font_size = pe.value @end
        @if pe.key == "padding" padding = pe.value @end
        @if pe.key == "spacing" spacing = pe.value @end
        @if pe.key == "visible" visible = pe.value @end
        @if pe.key == "enabled" enabled = pe.value @end
        @if pe.key == "value" value = pe.value @end
        @if pe.key == "checked" checked = pe.value @end
        @if pe.key == "placeholder" placeholder = pe.value.to_str() @end
        pi = pi + 1
      @end
    @end
    @if k == "layout"
      li = 0
      llen = v.len()
      @while li < llen
        le = v[li]
        @if le.key == "type" l_type = le.value.to_str() @end
        @if le.key == "align" l_align = le.value.to_str() @end
        @if le.key == "justify" l_justify = le.value.to_str() @end
        @if le.key == "gap" l_gap = le.value @end
        li = li + 1
      @end
    @end
    @if k == "events"
      ei = 0
      elen = v.len()
      @while ei < elen
        ee = v[ei]
        @if ee.key == "on_click" ev_click = ee.value.to_str() @end
        @if ee.key == "on_change" ev_change = ee.value.to_str() @end
        ei = ei + 1
      @end
    @end
    @if k == "state_bindings"
      si = 0
      slen = v.len()
      @while si < slen
        se = v[si]
        @if se.key == "bind_text" bind_text = se.value.to_str() @end
        @if se.key == "bind_val" bind_val = se.value.to_str() @end
        si = si + 1
      @end
    @end
    @if k == "children"
      children_raw = v
    @end
    
    i = i + 1
  @end
  
  node = builder_node_new(id, kind, x, y, w, h)
  node.props.text = text
  node.props.title = title
  node.props.bg_color = bg_color
  node.props.border_color = border_color
  node.props.border_width = border_width
  node.props.text_color = text_color
  node.props.font_size = font_size
  node.props.padding = padding
  node.props.spacing = spacing
  node.props.visible = visible
  node.props.enabled = enabled
  node.props.value = value
  node.props.checked = checked
  node.props.placeholder = placeholder
  
  node.layout.type = l_type
  node.layout.align = l_align
  node.layout.justify = l_justify
  node.layout.gap = l_gap
  
  node.events.on_click = ev_click
  node.events.on_change = ev_change
  
  node.state_bindings.bind_text = bind_text
  node.state_bindings.bind_val = bind_val
  
  ci = 0
  clen = children_raw.len()
  @while ci < clen
    ch_dict = children_raw[ci]
    ch_node = gui_node_from_json_dict(ch_dict)
    node.children = node.children.push(ch_node)
    ci = ci + 1
  @end
  
  return node
@end

@fn gui_builder_import_json(json_string)
  parsed_obj = json_parse(json_string)
  @if parsed_obj == 0 || parsed_obj == none
    return gui_window_new("default_win", "Default Window", 0, 0, 640, 480)
  @end
  
  root_dict = 0
  i = 0
  len = parsed_obj.len()
  @while i < len
    item = parsed_obj[i]
    @if item.key == "root"
      root_dict = item.value
    @end
    i = i + 1
  @end
  
  @if root_dict != 0
    return gui_node_from_json_dict(root_dict)
  @end
  
  return gui_node_from_json_dict(parsed_obj)
@end
