@! ============================================================================
@! MAYA UNIVERSE CORE — 2D SOFTWARE RENDERER
@! 100% Written in Pure Maya Language
@! Features: Bresenham Lines, Circles, Triangles, Bezier Curves, Bitmap ops
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/core/string"
import "universe/sys/syscalls"

@struct ClipRect
  min_x: i64
  min_y: i64
  max_x: i64
  max_y: i64
@end

@struct Canvas
  width: i64
  height: i64
  pixels: array
  clip: ClipRect
@end

@struct Framebuffer
  width: i64
  height: i64
  pitch: i64
  bpp: i64
  size: i64
  buffer: i64
@end

@fn canvas_new(width, height)
  @if width <= 0 width = 1 @end
  @if height <= 0 height = 1 @end
  buffer = []
  total_pixels = width * height
  i = 0
  @while i < total_pixels
    buffer = buffer.push(0x00000000) @! ARGB (Transparent Black)
    i = i + 1
  @end
  
  c_clip = {
    min_x: 0,
    min_y: 0,
    max_x: width,
    max_y: height
  }
  
  return {
    width: width,
    height: height,
    pixels: buffer,
    clip: c_clip
  }
@end

@fn canvas_set_clip(canvas, min_x, min_y, max_x, max_y)
  @if min_x < 0 min_x = 0 @end
  @if min_y < 0 min_y = 0 @end
  @if max_x > canvas.width max_x = canvas.width @end
  @if max_y > canvas.height max_y = canvas.height @end
  canvas.clip = {
    min_x: min_x,
    min_y: min_y,
    max_x: max_x,
    max_y: max_y
  }
  return canvas
@end

@fn canvas_reset_clip(canvas)
  canvas.clip = {
    min_x: 0,
    min_y: 0,
    max_x: canvas.width,
    max_y: canvas.height
  }
  return canvas
@end

@fn canvas_set_pixel(canvas, x, y, color)
  @if x >= 0 && x < canvas.width && y >= 0 && y < canvas.height
    c = canvas.clip
    @if x >= c.min_x && x < c.max_x && y >= c.min_y && y < c.max_y
      idx = (y * canvas.width) + x
      canvas.pixels[idx] = color
    @end
  @end
  return canvas
@end

@fn canvas_get_pixel(canvas, x, y)
  @if x >= 0 && x < canvas.width && y >= 0 && y < canvas.height
    idx = (y * canvas.width) + x
    return canvas.pixels[idx]
  @end
  return 0
@end

@fn canvas_clear(canvas, color)
  total = canvas.width * canvas.height
  i = 0
  @while i < total
    canvas.pixels[i] = color
    i = i + 1
  @end
  return canvas
@end

@! ----------------------------------------------------------------------------
@! 0. RAW MMAP FRAMEBUFFER OPERATIONS
@! ----------------------------------------------------------------------------

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
@! 1. BRESENHAM LINE ALGORITHM
@! ----------------------------------------------------------------------------

@fn abs(val)
  @if val < 0 return -val @end
  return val
@end

@fn canvas_draw_line(canvas, x0, y0, x1, y1, color)
  dx = abs(x1 - x0)
  sx = -1
  @if x0 < x1 sx = 1 @end
  
  dy = -abs(y1 - y0)
  sy = -1
  @if y0 < y1 sy = 1 @end
  
  err = dx + dy
  
  @while 1
    canvas = canvas_set_pixel(canvas, x0, y0, color)
    @if x0 == x1 && y0 == y1
      return canvas
    @end
    
    e2 = 2 * err
    @if e2 >= dy
      err = err + dy
      x0 = x0 + sx
    @end
    @if e2 <= dx
      err = err + dx
      y0 = y0 + sy
    @end
  @end
  
  return canvas
@end

@! ----------------------------------------------------------------------------
@! 2. BRESENHAM CIRCLE ALGORITHM
@! ----------------------------------------------------------------------------

@fn canvas_draw_circle(canvas, xc, yc, r, color)
  x = 0
  y = r
  d = 3 - 2 * r
  
  @while y >= x
    canvas = canvas_set_pixel(canvas, xc+x, yc+y, color)
    canvas = canvas_set_pixel(canvas, xc-x, yc+y, color)
    canvas = canvas_set_pixel(canvas, xc+x, yc-y, color)
    canvas = canvas_set_pixel(canvas, xc-x, yc-y, color)
    canvas = canvas_set_pixel(canvas, xc+y, yc+x, color)
    canvas = canvas_set_pixel(canvas, xc-y, yc+x, color)
    canvas = canvas_set_pixel(canvas, xc+y, yc-x, color)
    canvas = canvas_set_pixel(canvas, xc-y, yc-x, color)
    
    x = x + 1
    @if d > 0
      y = y - 1
      d = d + 4 * (x - y) + 10
    @else
      d = d + 4 * x + 6
    @end
  @end
  
  return canvas
@end

@! ----------------------------------------------------------------------------
@! 3. RECTANGLES
@! ----------------------------------------------------------------------------

@fn canvas_draw_rect(canvas, x, y, w, h, color)
  @! WHY: Exact inclusive pixel bounds [x..x+w-1, y..y+h-1] for precise width w and height h
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
  return canvas
@end

@fn canvas_fill_rect(canvas, x, y, w, h, color)
  @! WHY: Pre-clips rectangle to bounds to eliminate per-pixel clip tests and accelerate fill
  @if w <= 0 || h <= 0 return canvas @end
  c = canvas.clip
  x0 = x
  @if c.min_x > x0 x0 = c.min_x @end
  y0 = y
  @if c.min_y > y0 y0 = c.min_y @end
  
  x1 = x + w
  @if c.max_x < x1 x1 = c.max_x @end
  y1 = y + h
  @if c.max_y < y1 y1 = c.max_y @end
  
  @if x0 >= x1 || y0 >= y1 return canvas @end
  
  cy = y0
  @while cy < y1
    cx = x0
    row_offset = cy * canvas.width
    @while cx < x1
      canvas.pixels[row_offset + cx] = color
      cx = cx + 1
    @end
    cy = cy + 1
  @end
  return canvas
@end

@! ----------------------------------------------------------------------------
@! 4. TRIANGLES & FILLING
@! ----------------------------------------------------------------------------

@fn canvas_draw_triangle(canvas, x0, y0, x1, y1, x2, y2, color)
  canvas = canvas_draw_line(canvas, x0, y0, x1, y1, color)
  canvas = canvas_draw_line(canvas, x1, y1, x2, y2, color)
  canvas = canvas_draw_line(canvas, x2, y2, x0, y0, color)
  return canvas
@end

@! Scanline triangle filling would go here...

@! ----------------------------------------------------------------------------
@! 5. BEZIER CURVES
@! ----------------------------------------------------------------------------

@fn canvas_draw_bezier_quad(canvas, x0, y0, x1, y1, x2, y2, color)
  @! t ranges from 0.0 to 1.0 in steps
  steps = 100
  i = 0
  
  last_x = x0
  last_y = y0
  
  @while i <= steps
    t = (i * 1.0) / steps
    inv_t = 1.0 - t
    
    @! B(t) = (1-t)^2*P0 + 2*(1-t)*t*P1 + t^2*P2
    @! But Maya doesn't fully support float math natively in all loops easily without scaling,
    @! so we simulate fixed point by scaling * 10000
    
    t_fixed = (i * 10000) / steps
    inv_t_fixed = 10000 - t_fixed
    
    term0_x = (inv_t_fixed * inv_t_fixed / 10000 * x0) / 10000
    term1_x = (2 * inv_t_fixed * t_fixed / 10000 * x1) / 10000
    term2_x = (t_fixed * t_fixed / 10000 * x2) / 10000
    px = term0_x + term1_x + term2_x
    
    term0_y = (inv_t_fixed * inv_t_fixed / 10000 * y0) / 10000
    term1_y = (2 * inv_t_fixed * t_fixed / 10000 * y1) / 10000
    term2_y = (t_fixed * t_fixed / 10000 * y2) / 10000
    py = term0_y + term1_y + term2_y
    
    canvas = canvas_draw_line(canvas, last_x, last_y, px, py, color)
    last_x = px
    last_y = py
    
    i = i + 1
  @end
  
  return canvas
@end
