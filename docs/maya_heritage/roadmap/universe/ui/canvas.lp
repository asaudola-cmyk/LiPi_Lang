@! ============================================================================
@! MAYA UNIVERSE UI - NATIVE WIDGET SYSTEM (CANVAS)
@! 100% Written in Pure Maya Language
@! ============================================================================

import "universe/core/collections"
import "universe/ui/framebuffer"

@! Base Window System
@fn ui_window_new(title, width, height)
  return {
    title: title,
    width: width,
    height: height,
    fb: fb_new(width, height),
    children: []
  }
@end

@fn ui_window_add(window, widget)
  window.children = window.children.push(widget)
  return window
@end

@! Widgets
@fn widget_button(id, label, x, y, w, h, on_click)
  return {
    id: id,
    type: "Button",
    label: label,
    x: x, y: y, w: w, h: h,
    on_click: on_click
  }
@end

@fn widget_text_input(id, x, y, w, h)
  return {
    id: id,
    type: "TextInput",
    text: "",
    x: x, y: y, w: w, h: h
  }
@end

@! Event Loop
@fn ui_process_events(window)
  @! Poll for keyboard/mouse events
  @! Dispatch to children
  return window
@end

@! Render Loop
@fn ui_render(window)
  @! Clear background
  window.fb = fb_draw_rect(window.fb, 0, 0, window.width, window.height, 0xFFFFFFFF)
  
  @! Draw children
  @for child in window.children
    @if child.type == "Button"
      window.fb = fb_draw_rect(window.fb, child.x, child.y, child.w, child.h, 0xFFDDDDDD)
    @elif child.type == "TextInput"
      window.fb = fb_draw_rect(window.fb, child.x, child.y, child.w, child.h, 0xFFEEEEEE)
    @end
  @end
  
  fb_present(window.fb)
@end
