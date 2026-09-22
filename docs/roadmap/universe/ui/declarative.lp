@! ============================================================================
@! MAYA UNIVERSE UI - DECLARATIVE ENGINE
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/ui/canvas" @! Assumes canvas.maya exists from earlier phase

@! UI Component Base
@fn ui_component_new(type, props, children)
  return {
    type: type,
    props: props,
    children: children,
    layout: { x: 0, y: 0, width: 0, height: 0 }
  }
@end

@! Specific Components
@fn ui_text(content, style)
  return ui_component_new("Text", { content: content, style: style }, [])
@end

@fn ui_button(label, on_click)
  return ui_component_new("Button", { label: label, on_click: on_click }, [])
@end

@fn ui_column(children)
  return ui_component_new("Column", { spacing: 10 }, children)
@end

@! Flexbox-style Layout Engine
@fn ui_calculate_layout(node, max_width, max_height)
  @if node.type == "Column"
    current_y = 0
    new_children = []
    
    @for child in node.children
      child = ui_calculate_layout(child, max_width, max_height)
      child.layout.y = current_y
      current_y = current_y + child.layout.height + node.props.spacing
      new_children = new_children.push(child)
    @end
    
    node.children = new_children
    node.layout.width = max_width
    node.layout.height = current_y
  @elif node.type == "Text" || node.type == "Button"
    @! Mock text measurement
    node.layout.width = 100
    node.layout.height = 30
  @end
  
  return node
@end

@! Render to Canvas
@fn ui_render(node, canvas_obj)
  @if node.type == "Text"
    @! Draw text using canvas API
    @! canvas_draw_text(canvas_obj, node.layout.x, node.layout.y, node.props.content)
  @elif node.type == "Button"
    @! canvas_draw_rect(...)
    @! canvas_draw_text(...)
  @elif node.type == "Column"
    @for child in node.children
      ui_render(child, canvas_obj)
    @end
  @end
@end
