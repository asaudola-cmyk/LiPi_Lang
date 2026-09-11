@! ============================================================================
@! MAYA NATIVE GUI FRAMEWORK — CANVAS & 2D RASTERIZER
@! Module: universe/gui/canvas.maya
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Features:
@! - Flat ARGB pixel array Framebuffer
@! - Stack-based ClipRect intersection & boundary clipping
@! - DirtyRect queue tracking & minimal bounding box merge
@! - 2D Drawing Primitives: Bresenham lines, circles, rects, rounded rects, blit
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/core/string"
import "universe/sys/syscalls"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURE DEFINITIONS
@! ----------------------------------------------------------------------------

@struct ClipRect
  min_x: i64
  min_y: i64
  max_x: i64
  max_y: i64
@end

@struct DirtyRect
  x: i64
  y: i64
  width: i64
  height: i64
@end

@struct Canvas
  width: i64
  height: i64
  pitch: i64
  pixels: array
  clip_stack: array
  current_clip: ClipRect
  dirty_rects: array
  has_dirty: i64
@end

@struct Framebuffer
  width: i64
  height: i64
  pitch: i64
  bpp: i64
  size: i64
  buffer: i64
@end

@! ----------------------------------------------------------------------------
@! 2. CANVAS CONSTRUCTORS & MEMORY MANAGEMENT
@! ----------------------------------------------------------------------------

@fn clip_rect_new(min_x, min_y, max_x, max_y)
  return {
    min_x: min_x,
    min_y: min_y,
    max_x: max_x,
    max_y: max_y
  }
@end

@fn dirty_rect_new(x, y, width, height)
  return {
    x: x,
    y: y,
    width: width,
    height: height
  }
@end

@fn canvas_new(width, height)
  @if width <= 0 width = 1 @end
  @if height <= 0 height = 1 @end
  
  total_pixels = width * height
  buf = []
  i = 0
  @while i < total_pixels
    buf = buf.push(0) @! 0x00000000 ARGB
    i = i + 1
  @end
  
  init_clip = clip_rect_new(0, 0, width, height)
  
  return {
    width: width,
    height: height,
    pitch: width * 4,
    pixels: buf,
    clip_stack: [],
    current_clip: init_clip,
    dirty_rects: [],
    has_dirty: 0
  }
@end

@fn framebuffer_new(width, height)
  @! WHY: Validates dimensions to prevent degenerate 0-sized allocations or division-by-zero
  @if width <= 0 width = 1 @end
  @if height <= 0 height = 1 @end
  pitch = width * 4
  size = pitch * height
  @! WHY: Direct Linux syscall 9 (sys_mmap) allocating contiguous anonymous memory pages
  @! PROT_READ (1) | PROT_WRITE (2) = 3; MAP_PRIVATE (2) | MAP_ANONYMOUS (32) = 34
  ptr = sys_mmap(0, size, 3, 34, 0 - 1, 0)
  return {
    width: width,
    height: height,
    pitch: pitch,
    bpp: 32,
    size: size,
    buffer: ptr
  }
@end

@fn framebuffer_free(fb)
  @! WHY: Unmaps allocated memory buffer cleanly via Linux syscall 11 (sys_munmap)
  @if fb.buffer > 0
    return sys_munmap(fb.buffer, fb.size)
  @end
  return 0
@end

@fn framebuffer_set_pixel(fb, x, y, color)
  @! WHY: Guard against out-of-bounds writes that would cause memory corruption
  @if x < 0 || x >= fb.width || y < 0 || y >= fb.height || fb.buffer <= 0
    return 0
  @end
  offset = (y * fb.pitch) + (x * 4)
  addr = fb.buffer + offset
  @! WHY: Raw 32-bit RGBA little-endian byte writes via compiler intrinsic sys_poke8
  sys_poke8(addr + 0, color & 255)
  sys_poke8(addr + 1, (color / 256) & 255)
  sys_poke8(addr + 2, (color / 65536) & 255)
  sys_poke8(addr + 3, (color / 16777216) & 255)
  return 1
@end

@fn framebuffer_get_pixel(fb, x, y)
  @! WHY: Safe out-of-bounds read returning 0 (transparent black)
  @if x < 0 || x >= fb.width || y < 0 || y >= fb.height || fb.buffer <= 0
    return 0
  @end
  offset = (y * fb.pitch) + (x * 4)
  addr = fb.buffer + offset
  b0 = sys_peek8(addr + 0)
  b1 = sys_peek8(addr + 1)
  b2 = sys_peek8(addr + 2)
  b3 = sys_peek8(addr + 3)
  return b0 | (b1 * 256) | (b2 * 65536) | (b3 * 16777216)
@end

@fn framebuffer_clear(fb, color)
  @! WHY: Clears entire framebuffer to specified RGBA color value
  @if fb.buffer <= 0 return fb @end
  y = 0
  @while y < fb.height
    x = 0
    @while x < fb.width
      framebuffer_set_pixel(fb, x, y, color)
      x = x + 1
    @end
    y = y + 1
  @end
  return fb
@end

@fn canvas_to_framebuffer(canvas, fb)
  @! WHY: Transfers software-rasterized canvas pixel array directly into mmap framebuffer
  @if fb.buffer <= 0 return 0 @end
  min_w = canvas.width
  @if fb.width < min_w min_w = fb.width @end
  min_h = canvas.height
  @if fb.height < min_h min_h = fb.height @end
  
  y = 0
  @while y < min_h
    x = 0
    row_off = y * canvas.width
    @while x < min_w
      pixel_val = canvas.pixels[row_off + x]
      framebuffer_set_pixel(fb, x, y, pixel_val)
      x = x + 1
    @end
    y = y + 1
  @end
  return 1
@end

@! ----------------------------------------------------------------------------
@! 3. CLIPPING STACK & BOUNDARY ENFORCEMENT
@! ----------------------------------------------------------------------------

@fn canvas_push_clip(canvas, x, y, w, h)
  req_min_x = x
  req_min_y = y
  req_max_x = x + w
  req_max_y = y + h
  
  cur = canvas.current_clip
  new_min_x = cur.min_x
  @if req_min_x > new_min_x new_min_x = req_min_x @end
  
  new_min_y = cur.min_y
  @if req_min_y > new_min_y new_min_y = req_min_y @end
  
  new_max_x = cur.max_x
  @if req_max_x < new_max_x new_max_x = req_max_x @end
  
  new_max_y = cur.max_y
  @if req_max_y < new_max_y new_max_y = req_max_y @end
  
  @if new_min_x > new_max_x new_min_x = new_max_x @end
  @if new_min_y > new_max_y new_min_y = new_max_y @end
  
  canvas.clip_stack = canvas.clip_stack.push(cur)
  canvas.current_clip = clip_rect_new(new_min_x, new_min_y, new_max_x, new_max_y)
  return canvas
@end

@fn canvas_pop_clip(canvas)
  stack_len = canvas.clip_stack.len()
  @if stack_len > 0
    top_idx = stack_len - 1
    canvas.current_clip = canvas.clip_stack[top_idx]
    
    new_stack = []
    i = 0
    @while i < top_idx
      new_stack = new_stack.push(canvas.clip_stack[i])
      i = i + 1
    @end
    canvas.clip_stack = new_stack
  @else
    canvas.current_clip = clip_rect_new(0, 0, canvas.width, canvas.height)
  @end
  return canvas
@end

@! ----------------------------------------------------------------------------
@! 4. DIRTY REGION TRACKING & BOUNDING BOX MERGE
@! ----------------------------------------------------------------------------

@fn canvas_add_dirty_rect(canvas, x, y, w, h)
  @if w <= 0 || h <= 0 return canvas @end
  
  @if x < 0
    w = w + x
    x = 0
  @end
  @if y < 0
    h = h + y
    y = 0
  @end
  @if x + w > canvas.width
    w = canvas.width - x
  @end
  @if y + h > canvas.height
    h = canvas.height - y
  @end
  
  @if w > 0 && h > 0
    dr = dirty_rect_new(x, y, w, h)
    canvas.dirty_rects = canvas.dirty_rects.push(dr)
    canvas.has_dirty = 1
  @end
  return canvas
@end

@fn canvas_merge_dirty_rects(canvas)
  num_items = canvas.dirty_rects.len()
  @if num_items == 0
    return dirty_rect_new(0, 0, 0, 0)
  @end
  
  first = canvas.dirty_rects[0]
  min_x = first.x
  min_y = first.y
  max_x = first.x + first.width
  max_y = first.y + first.height
  
  i = 1
  @while i < num_items
    r = canvas.dirty_rects[i]
    rx2 = r.x + r.width
    ry2 = r.y + r.height
    
    @if r.x < min_x min_x = r.x @end
    @if r.y < min_y min_y = r.y @end
    @if rx2 > max_x max_x = rx2 @end
    @if ry2 > max_y max_y = ry2 @end
    i = i + 1
  @end
  
  return dirty_rect_new(min_x, min_y, max_x - min_x, max_y - min_y)
@end

@fn canvas_clear_dirty_rects(canvas)
  canvas.dirty_rects = []
  canvas.has_dirty = 0
  return canvas
@end

@! ----------------------------------------------------------------------------
@! 5. PIXEL ACCESS & BUFFER OPERATIONS
@! ----------------------------------------------------------------------------

@fn canvas_set_pixel(canvas, x, y, color)
  @if x < 0 || x >= canvas.width || y < 0 || y >= canvas.height
    return canvas
  @end
  
  clip = canvas.current_clip
  @if x < clip.min_x || x >= clip.max_x || y < clip.min_y || y >= clip.max_y
    return canvas
  @end
  
  idx = (y * canvas.width) + x
  canvas.pixels[idx] = color
  return canvas
@end

@fn canvas_get_pixel(canvas, x, y)
  @if x < 0 || x >= canvas.width || y < 0 || y >= canvas.height
    return 0
  @end
  idx = (y * canvas.width) + x
  return canvas.pixels[idx]
@end

@fn canvas_clear(canvas, color)
  total = canvas.width * canvas.height
  i = 0
  @while i < total
    canvas.pixels[i] = color
    i = i + 1
  @end
  canvas = canvas_add_dirty_rect(canvas, 0, 0, canvas.width, canvas.height)
  return canvas
@end

@! ----------------------------------------------------------------------------
@! 6. 2D GEOMETRY PRIMITIVES
@! ----------------------------------------------------------------------------

@! --- Bresenham Line ---
@fn canvas_draw_line(canvas, x0, y0, x1, y1, color)
  dx = abs(x1 - x0)
  sx = -1
  @if x0 < x1 sx = 1 @end
  
  dy = 0 - abs(y1 - y0)
  sy = -1
  @if y0 < y1 sy = 1 @end
  
  err = dx + dy
  cx = x0
  cy = y0
  
  @while 1 == 1
    canvas = canvas_set_pixel(canvas, cx, cy, color)
    @if cx == x1 && cy == y1
      min_x = x0
      @if x1 < min_x min_x = x1 @end
      min_y = y0
      @if y1 < min_y min_y = y1 @end
      max_x = x0
      @if x1 > max_x max_x = x1 @end
      max_y = y0
      @if y1 > max_y max_y = y1 @end
      canvas = canvas_add_dirty_rect(canvas, min_x, min_y, (max_x - min_x) + 1, (max_y - min_y) + 1)
      return canvas
    @end
    
    e2 = 2 * err
    @if e2 >= dy
      err = err + dy
      cx = cx + sx
    @end
    @if e2 <= dx
      err = err + dx
      cy = cy + sy
    @end
  @end
  return canvas
@end

@! --- Rectangle Outline ---
@fn canvas_draw_rect(canvas, x, y, w, h, color)
  @if w <= 0 || h <= 0 return canvas @end
  x2 = (x + w) - 1
  y2 = (y + h) - 1
  
  cx = x
  @while cx <= x2
    canvas = canvas_set_pixel(canvas, cx, y, color)
    canvas = canvas_set_pixel(canvas, cx, y2, color)
    cx = cx + 1
  @end
  
  cy = y + 1
  @while cy < y2
    canvas = canvas_set_pixel(canvas, x, cy, color)
    canvas = canvas_set_pixel(canvas, x2, cy, color)
    cy = cy + 1
  @end
  
  canvas = canvas_add_dirty_rect(canvas, x, y, w, h)
  return canvas
@end

@! --- Filled Rectangle ---
@fn canvas_fill_rect(canvas, x, y, w, h, color)
  @if w <= 0 || h <= 0 return canvas @end
  
  clip = canvas.current_clip
  rx0 = x
  @if clip.min_x > rx0 rx0 = clip.min_x @end
  ry0 = y
  @if clip.min_y > ry0 ry0 = clip.min_y @end
  
  rx1 = x + w
  @if clip.max_x < rx1 rx1 = clip.max_x @end
  ry1 = y + h
  @if clip.max_y < ry1 ry1 = clip.max_y @end
  
  @if rx0 >= rx1 || ry0 >= ry1
    return canvas
  @end
  
  cy = ry0
  @while cy < ry1
    row_offset = cy * canvas.width
    cx = rx0
    @while cx < rx1
      canvas.pixels[row_offset + cx] = color
      cx = cx + 1
    @end
    cy = cy + 1
  @end
  
  canvas = canvas_add_dirty_rect(canvas, rx0, ry0, rx1 - rx0, ry1 - ry0)
  return canvas
@end

@! --- Midpoint Circle Outline ---
@fn canvas_draw_circle(canvas, xc, yc, r, color)
  @if r <= 0
    return canvas_set_pixel(canvas, xc, yc, color)
  @end
  
  x = 0
  y = r
  d = 3 - (2 * r)
  
  @while y >= x
    canvas = canvas_set_pixel(canvas, xc + x, yc + y, color)
    canvas = canvas_set_pixel(canvas, xc - x, yc + y, color)
    canvas = canvas_set_pixel(canvas, xc + x, yc - y, color)
    canvas = canvas_set_pixel(canvas, xc - x, yc - y, color)
    canvas = canvas_set_pixel(canvas, xc + y, yc + x, color)
    canvas = canvas_set_pixel(canvas, xc - y, yc + x, color)
    canvas = canvas_set_pixel(canvas, xc + y, yc - x, color)
    canvas = canvas_set_pixel(canvas, xc - y, yc - x, color)
    
    x = x + 1
    @if d > 0
      y = y - 1
      d = d + (4 * (x - y)) + 10
    @else
      d = d + (4 * x) + 6
    @end
  @end
  
  canvas = canvas_add_dirty_rect(canvas, xc - r, yc - r, (2 * r) + 1, (2 * r) + 1)
  return canvas
@end

@! --- Filled Circle ---
@fn canvas_fill_circle(canvas, xc, yc, r, color)
  @if r <= 0
    return canvas_set_pixel(canvas, xc, yc, color)
  @end
  
  dy = 0 - r
  @while dy <= r
    dx = 0 - r
    @while dx <= r
      @if (dx * dx) + (dy * dy) <= (r * r)
        canvas = canvas_set_pixel(canvas, xc + dx, yc + dy, color)
      @end
      dx = dx + 1
    @end
    dy = dy + 1
  @end
  
  canvas = canvas_add_dirty_rect(canvas, xc - r, yc - r, (2 * r) + 1, (2 * r) + 1)
  return canvas
@end

@! --- Rounded Rectangle Outline ---
@fn canvas_draw_rounded_rect(canvas, x, y, w, h, radius, color)
  @if w <= 0 || h <= 0 return canvas @end
  
  max_r = w / 2
  @if (h / 2) < max_r max_r = h / 2 @end
  @if radius > max_r radius = max_r @end
  @if radius <= 0
    return canvas_draw_rect(canvas, x, y, w, h, color)
  @end
  
  x2 = (x + w) - 1
  y2 = (y + h) - 1
  
  cx = x + radius
  @while cx <= x2 - radius
    canvas = canvas_set_pixel(canvas, cx, y, color)
    canvas = canvas_set_pixel(canvas, cx, y2, color)
    cx = cx + 1
  @end
  
  cy = y + radius
  @while cy <= y2 - radius
    canvas = canvas_set_pixel(canvas, x, cy, color)
    canvas = canvas_set_pixel(canvas, x2, cy, color)
    cy = cy + 1
  @end
  
  ax = 0
  ay = radius
  d = 3 - (2 * radius)
  
  c_tl_x = x + radius
  c_tl_y = y + radius
  c_tr_x = x2 - radius
  c_tr_y = y + radius
  c_bl_x = x + radius
  c_bl_y = y2 - radius
  c_br_x = x2 - radius
  c_br_y = y2 - radius
  
  @while ay >= ax
    canvas = canvas_set_pixel(canvas, c_tl_x - ax, c_tl_y - ay, color)
    canvas = canvas_set_pixel(canvas, c_tl_x - ay, c_tl_y - ax, color)
    
    canvas = canvas_set_pixel(canvas, c_tr_x + ax, c_tr_y - ay, color)
    canvas = canvas_set_pixel(canvas, c_tr_x + ay, c_tr_y - ax, color)
    
    canvas = canvas_set_pixel(canvas, c_bl_x - ax, c_bl_y + ay, color)
    canvas = canvas_set_pixel(canvas, c_bl_x - ay, c_bl_y + ax, color)
    
    canvas = canvas_set_pixel(canvas, c_br_x + ax, c_br_y + ay, color)
    canvas = canvas_set_pixel(canvas, c_br_x + ay, c_br_y + ax, color)
    
    ax = ax + 1
    @if d > 0
      ay = ay - 1
      d = d + (4 * (ax - ay)) + 10
    @else
      d = d + (4 * ax) + 6
    @end
  @end
  
  canvas = canvas_add_dirty_rect(canvas, x, y, w, h)
  return canvas
@end

@! --- Filled Rounded Rectangle ---
@fn canvas_fill_rounded_rect(canvas, x, y, w, h, radius, color)
  @if w <= 0 || h <= 0 return canvas @end
  
  max_r = w / 2
  @if (h / 2) < max_r max_r = h / 2 @end
  @if radius > max_r radius = max_r @end
  @if radius <= 0
    return canvas_fill_rect(canvas, x, y, w, h, color)
  @end
  
  canvas = canvas_fill_rect(canvas, x, y + radius, w, h - (2 * radius), color)
  canvas = canvas_fill_rect(canvas, x + radius, y, w - (2 * radius), radius, color)
  canvas = canvas_fill_rect(canvas, x + radius, (y + h) - radius, w - (2 * radius), radius, color)
  
  x2 = (x + w) - 1
  y2 = (y + h) - 1
  c_tl_x = x + radius
  c_tl_y = y + radius
  c_tr_x = x2 - radius
  c_tr_y = y + radius
  c_bl_x = x + radius
  c_bl_y = y2 - radius
  c_br_x = x2 - radius
  c_br_y = y2 - radius
  
  dy = 0
  @while dy <= radius
    dx = 0
    @while dx <= radius
      @if (dx * dx) + (dy * dy) <= (radius * radius)
        canvas = canvas_set_pixel(canvas, c_tl_x - dx, c_tl_y - dy, color)
        canvas = canvas_set_pixel(canvas, c_tr_x + dx, c_tr_y - dy, color)
        canvas = canvas_set_pixel(canvas, c_bl_x - dx, c_bl_y + dy, color)
        canvas = canvas_set_pixel(canvas, c_br_x + dx, c_br_y + dy, color)
      @end
      dx = dx + 1
    @end
    dy = dy + 1
  @end
  
  canvas = canvas_add_dirty_rect(canvas, x, y, w, h)
  return canvas
@end

@! ----------------------------------------------------------------------------
@! 7. BLITTING & REGION COPY
@! ----------------------------------------------------------------------------

@fn canvas_blit(dst_canvas, src_canvas, dst_x, dst_y, src_x, src_y, w, h)
  @if w <= 0 || h <= 0 return dst_canvas @end
  
  r = 0
  @while r < h
    s_y = src_y + r
    d_y = dst_y + r
    
    @if s_y >= 0 && s_y < src_canvas.height && d_y >= 0 && d_y < dst_canvas.height
      src_row_offset = s_y * src_canvas.width
      c = 0
      @while c < w
        s_x = src_x + c
        d_x = dst_x + c
        
        @if s_x >= 0 && s_x < src_canvas.width && d_x >= 0 && d_x < dst_canvas.width
          pixel_val = src_canvas.pixels[src_row_offset + s_x]
          @if pixel_val != 0
            dst_canvas = canvas_set_pixel(dst_canvas, d_x, d_y, pixel_val)
          @end
        @end
        c = c + 1
      @end
    @end
    r = r + 1
  @end
  
  dst_canvas = canvas_add_dirty_rect(dst_canvas, dst_x, dst_y, w, h)
  return dst_canvas
@end
