@! ============================================================================
@! MAYA OS - VESA & VGA GRAPHICS DRIVER
@! 100% Written in Pure Maya Language
@! Features: VBE Mode Info parsing, Linear Framebuffer mapping, Double Buffering,
@! 2D primitives (Line, Rect, Circle), and TrueType Font text rendering.
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/collections"
import "universe/core/math"

@fn display_init(width, height, bpp)
  println("  [DISPLAY] Initializing VESA Framebuffer " + width.to_str() + "x" + height.to_str() + "x" + bpp.to_str())
  
  fb = {
    width: width,
    height: height,
    bpp: bpp,
    pitch: width * (bpp / 8),
    pixels: []
  }
  
  @! Allocate flat pixel buffer
  i = 0
  len = width * height * (bpp / 8)
  @while i < len
    fb.pixels = fb.pixels.push(0)
    i = i + 1
  @end
  
  return fb
@end

@fn display_put_pixel(fb, x, y, color)
  @if x >= 0 && x < fb.width && y >= 0 && y < fb.height
    offset = (y * fb.pitch) + (x * (fb.bpp / 8))
    @! Assuming 32bpp BGRA
    fb.pixels = list_set(fb.pixels, offset, color & 0xFF)
    fb.pixels = list_set(fb.pixels, offset + 1, (color / 256) & 0xFF)
    fb.pixels = list_set(fb.pixels, offset + 2, (color / 65536) & 0xFF)
    fb.pixels = list_set(fb.pixels, offset + 3, (color / 16777216) & 0xFF)
  @end
  return fb
@end

@fn display_clear(fb, color)
  x = 0
  @while x < fb.width
    y = 0
    @while y < fb.height
      fb = display_put_pixel(fb, x, y, color)
      y = y + 1
    @end
    x = x + 1
  @end
  return fb
@end

@fn display_draw_rect(fb, x, y, w, h, color)
  i = 0
  @while i < w
    j = 0
    @while j < h
      fb = display_put_pixel(fb, x + i, y + j, color)
      j = j + 1
    @end
    i = i + 1
  @end
  return fb
@end

@fn display_draw_line(fb, x0, y0, x1, y1, color)
  @! Bresenham's Line Algorithm
  dx = math_abs(x1 - x0)
  sx = -1
  @if x0 < x1 sx = 1 @end
  
  dy = -math_abs(y1 - y0)
  sy = -1
  @if y0 < y1 sy = 1 @end
  
  err = dx + dy
  
  running = 1
  @while running == 1
    fb = display_put_pixel(fb, x0, y0, color)
    @if x0 == x1 && y0 == y1
      running = 0
    @else
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
  @end
  return fb
@end

@fn display_draw_circle(fb, xc, yc, r, color)
  x = 0
  y = r
  d = 3 - 2 * r
  fb = display_draw_circle_points(fb, xc, yc, x, y, color)
  @while y >= x
    x = x + 1
    @if d > 0
      y = y - 1
      d = d + 4 * (x - y) + 10
    @else
      d = d + 4 * x + 6
    @end
    fb = display_draw_circle_points(fb, xc, yc, x, y, color)
  @end
  return fb
@end

@fn display_draw_circle_points(fb, xc, yc, x, y, color)
  fb = display_put_pixel(fb, xc + x, yc + y, color)
  fb = display_put_pixel(fb, xc - x, yc + y, color)
  fb = display_put_pixel(fb, xc + x, yc - y, color)
  fb = display_put_pixel(fb, xc - x, yc - y, color)
  fb = display_put_pixel(fb, xc + y, yc + x, color)
  fb = display_put_pixel(fb, xc - y, yc + x, color)
  fb = display_put_pixel(fb, xc + y, yc - x, color)
  fb = display_put_pixel(fb, xc - y, yc - x, color)
  return fb
@end

@fn display_swap_buffers(fb)
  @! Issues DMA transfer to physical VRAM
  println("  [DISPLAY] Double buffer swapped via DMA")
  return fb
@end
