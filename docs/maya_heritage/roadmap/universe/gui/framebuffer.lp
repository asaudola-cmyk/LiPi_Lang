@! ============================================================================
@! MAYA NATIVE GUI — FRAMEBUFFER RENDERER
@! 100% Pure Maya — Direct Pixel Manipulation
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/memory"
import "universe/core/math"
import "universe/core/collections"


@fn framebuffer_new(width, height)
  @! 4 bytes per pixel (RGBA or ARGB)
  size = width * height * 4
  buffer_ptr = sys_mmap(0, size, 3, 34, -1, 0)
  pixels = []
  i = 0
  total = width * height
  @while i < total
    pixels = pixels.push(0)
    i = i + 1
  @end
  
  return {
    width: width,
    height: height,
    pitch: width * 4,
    buffer: buffer_ptr,
    pixels: pixels,
    size: size
  }
@end

@fn fb_draw_pixel(fb, x, y, color)
  @if x < 0 || x >= fb.width || y < 0 || y >= fb.height
    return 0
  @end
  
  idx = (y * fb.width) + x
  fb.pixels = list_set(fb.pixels, idx, color)
  return 1
@end

@fn fb_get_pixel(fb, x, y)
  @if x < 0 || x >= fb.width || y < 0 || y >= fb.height
    return 0
  @end
  idx = (y * fb.width) + x
  return fb.pixels[idx]
@end

@fn fb_clear(fb, color)
  new_pix = []
  total = fb.width * fb.height
  i = 0
  @while i < total
    new_pix = new_pix.push(color)
    i = i + 1
  @end
  fb.pixels = new_pix
  return 1
@end

@fn fb_draw_rect(fb, x, y, w, h, color)
  r = 0
  @while r < h
    c = 0
    @while c < w
      fb_draw_pixel(fb, x + c, y + r, color)
      c = c + 1
    @end
    r = r + 1
  @end
  return 1
@end

@fn fb_draw_line(fb, x0, y0, x1, y1, color)
  @! Bresenham's Line Algorithm
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
    fb_draw_pixel(fb, cx, cy, color)
    
    @if cx == x1 && cy == y1
      return 1
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
  return 1
@end
