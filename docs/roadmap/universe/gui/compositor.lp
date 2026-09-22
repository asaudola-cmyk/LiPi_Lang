@! ============================================================================
@! MAYA NATIVE GUI — WINDOW COMPOSITOR
@! Handles Window Layering, Z-Index, and Alpha Blending
@! ============================================================================

import "universe/gui/framebuffer"

@fn compositor_init(fb)
  return {
    main_fb: fb,
    windows: [],
    dirty_rects: [],
    background_color: 0xFF202020 @! Dark Gray
  }
@end

@fn compositor_add_window(comp, win)
  comp.windows = comp.windows.push(win)
  return comp
@end

@fn compositor_render(comp)
  @! 1. Clear Screen
  fb_clear(comp.main_fb, comp.background_color)
  
  @! 2. Render Windows from bottom to top (Painters Algorithm)
  i = 0
  len = comp.windows.len()
  @while i < len
    win = comp.windows[i]
    
    @if win.visible == 1
      @! Draw Window Shadow
      fb_draw_rect(comp.main_fb, win.x + 5, win.y + 5, win.width, win.height, 0x88000000)
      
      @! Draw Window Border & Background
      fb_draw_rect(comp.main_fb, win.x, win.y, win.width, win.height, win.border_color)
      fb_draw_rect(comp.main_fb, win.x + 1, win.y + 1, win.width - 2, win.height - 2, win.bg_color)
      
      @! Draw Title Bar
      fb_draw_rect(comp.main_fb, win.x + 1, win.y + 1, win.width - 2, 20, win.title_bg_color)
      
      @! Render Window Children (Buttons)
      ci = 0
      clen = win.children.len()
      @while ci < clen
        child = win.children[ci]
        @if child.kind == "BUTTON"
          fb_draw_rect(comp.main_fb, win.x + child.x, win.y + child.y, child.width, child.height, child.bg_color)
        @end
        ci = ci + 1
      @end
      
      @! Blit Window's internal Backbuffer onto the Main Framebuffer
      blit_window_buffer(comp.main_fb, win)
    @end
    i = i + 1
  @end
  
  return 1
@end

@fn blit_window_buffer(main_fb, win)
  @! Copy win.buffer pixels to main_fb at (win.x, win.y)
  @if win.buffer == 0 || win.buffer == none return 1 @end
  
  r = 22 @! Skip title bar
  @while r < win.height - 1
    c = 1
    @while c < win.width - 1
      @if win.buffer.pixels != 0 && win.buffer.pixels != none
        px = fb_get_pixel(win.buffer, c, r)
        @if px != 0
          fb_draw_pixel(main_fb, win.x + c, win.y + r, px)
        @end
      @end
      c = c + 1
    @end
    r = r + 1
  @end
  return 1
@end
