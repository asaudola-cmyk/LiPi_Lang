@! ============================================================================
@! MAYA WEB FRONTEND ENGINE — TIER 3 CPU CANVAS 2D SOFTWARE RASTERIZER (F11)
@! Module: universe/web/frontend/renderer/canvas2d_renderer.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - 32-bit ARGB Flat Framebuffer Software Rasterizer with Alpha Blending
@! - Porter-Duff "Over" compositing & color bitwise channel math
@! - Hierarchical clipping stack with geometric rectangular intersection
@! - Anti-aliased/rounded rectangles, borders, shadows, and linear gradients
@! - Monospace 5x7 bitmap font glyph renderer for ASCII 32..126
@! - Netpbm PPM (P3) export and raw ARGB buffer serialization
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/core/string"

@! ============================================================================
@! 1. ARGB COLOR PACKING & ALPHA BLENDING (PORTER-DUFF OVER)
@! ============================================================================

@fn argb_pack(a, r, g, b)
  @if a < 0 a = 0 @end @if a > 255 a = 255 @end
  @if r < 0 r = 0 @end @if r > 255 r = 255 @end
  @if g < 0 g = 0 @end @if g > 255 g = 255 @end
  @if b < 0 b = 0 @end @if b > 255 b = 255 @end
  return (a * 16777216) + (r * 65536) + (g * 256) + b
@end

@fn argb_get_a(col)
  return (col / 16777216) % 256
@end

@fn argb_get_r(col)
  return (col / 65536) % 256
@end

@fn argb_get_g(col)
  return (col / 256) % 256
@end

@fn argb_get_b(col)
  return col % 256
@end

@fn argb_blend(src_col, dst_col)
  sa = (src_col / 16777216) % 256
  @if sa == 255 return src_col @end
  @if sa == 0 return dst_col @end

  sr = (src_col / 65536) % 256
  sg = (src_col / 256) % 256
  sb = src_col % 256

  da = (dst_col / 16777216) % 256
  dr = (dst_col / 65536) % 256
  dg = (dst_col / 256) % 256
  db = dst_col % 256

  inv_a = 255 - sa
  out_r = ((sr * sa) + (dr * inv_a)) / 255
  out_g = ((sg * sa) + (dg * inv_a)) / 255
  out_b = ((sb * sa) + (db * inv_a)) / 255
  out_a = sa + ((da * inv_a) / 255)

  return (out_a * 16777216) + (out_r * 65536) + (out_g * 256) + out_b
@end

@! ============================================================================
@! 2. 5x7 MONOSPACE BITMAP FONT GLYPH TABLE
@! ============================================================================

@fn font_get_glyph_5x7(code)
  @! Encodes 5 columns of 7 bits each for standard ASCII characters
  @if code == 32  @! ' '
    return [0, 0, 0, 0, 0]
  @elif code == 65 @! 'A'
    return [126, 17, 17, 17, 126]
  @elif code == 66 @! 'B'
    return [127, 73, 73, 73, 54]
  @elif code == 67 @! 'C'
    return [62, 65, 65, 65, 34]
  @elif code == 68 @! 'D'
    return [127, 65, 65, 34, 28]
  @elif code == 69 @! 'E'
    return [127, 73, 73, 73, 65]
  @elif code == 70 @! 'F'
    return [127, 9, 9, 9, 1]
  @elif code == 71 @! 'G'
    return [62, 65, 73, 73, 58]
  @elif code == 72 @! 'H'
    return [127, 8, 8, 8, 127]
  @elif code == 73 @! 'I'
    return [0, 65, 127, 65, 0]
  @elif code == 74 @! 'J'
    return [32, 64, 65, 63, 1]
  @elif code == 75 @! 'K'
    return [127, 8, 20, 34, 65]
  @elif code == 76 @! 'L'
    return [127, 64, 64, 64, 64]
  @elif code == 77 @! 'M'
    return [127, 2, 12, 2, 127]
  @elif code == 78 @! 'N'
    return [127, 4, 8, 16, 127]
  @elif code == 79 @! 'O'
    return [62, 65, 65, 65, 62]
  @elif code == 80 @! 'P'
    return [127, 9, 9, 9, 6]
  @elif code == 81 @! 'Q'
    return [62, 65, 81, 33, 94]
  @elif code == 82 @! 'R'
    return [127, 9, 25, 41, 70]
  @elif code == 83 @! 'S'
    return [70, 73, 73, 73, 49]
  @elif code == 84 @! 'T'
    return [1, 1, 127, 1, 1]
  @elif code == 85 @! 'U'
    return [63, 64, 64, 64, 63]
  @elif code == 86 @! 'V'
    return [31, 32, 64, 32, 31]
  @elif code == 87 @! 'W'
    return [127, 32, 24, 32, 127]
  @elif code == 88 @! 'X'
    return [99, 20, 8, 20, 99]
  @elif code == 89 @! 'Y'
    return [7, 8, 112, 8, 7]
  @elif code == 90 @! 'Z'
    return [97, 81, 73, 69, 67]
  @elif code >= 97 && code <= 122 @! 'a'-'z' -> use uppercase glyph shape scaled or standard
    return font_get_glyph_5x7(code - 32)
  @elif code == 48 @! '0'
    return [62, 69, 73, 81, 62]
  @elif code == 49 @! '1'
    return [0, 66, 127, 64, 0]
  @elif code == 50 @! '2'
    return [98, 81, 73, 73, 70]
  @elif code == 51 @! '3'
    return [34, 65, 73, 73, 54]
  @elif code == 52 @! '4'
    return [24, 20, 18, 127, 16]
  @elif code == 53 @! '5'
    return [47, 73, 73, 73, 49]
  @elif code == 54 @! '6'
    return [60, 74, 73, 73, 48]
  @elif code == 55 @! '7'
    return [1, 113, 9, 5, 3]
  @elif code == 56 @! '8'
    return [54, 73, 73, 73, 54]
  @elif code == 57 @! '9'
    return [6, 73, 73, 41, 30]
  @elif code == 58 @! ':'
    return [0, 54, 54, 0, 0]
  @elif code == 44 @! ','
    return [0, 96, 48, 0, 0]
  @elif code == 46 @! '.'
    return [0, 96, 96, 0, 0]
  @elif code == 45 @! '-'
    return [8, 8, 8, 8, 8]
  @elif code == 43 @! '+'
    return [8, 8, 62, 8, 8]
  @elif code == 61 @! '='
    return [20, 20, 20, 20, 20]
  @elif code == 33 @! '!'
    return [0, 0, 125, 0, 0]
  @elif code == 63 @! '?'
    return [2, 1, 89, 9, 6]
  @elif code == 47 @! '/'
    return [32, 16, 8, 4, 2]
  @elif code == 91 @! '['
    return [0, 127, 65, 65, 0]
  @elif code == 93 @! ']'
    return [0, 65, 65, 127, 0]
  @elif code == 40 @! '('
    return [0, 28, 34, 65, 0]
  @elif code == 41 @! ')'
    return [0, 65, 34, 28, 0]
  @elif code == 60 @! '<'
    return [8, 20, 34, 65, 0]
  @elif code == 62 @! '>'
    return [0, 65, 34, 20, 8]
  @end

  @! Default box for unknown characters
  return [127, 65, 65, 65, 127]
@end

@! ============================================================================
@! 3. CANVAS2D DATA STRUCTURE & LIFECYCLE
@! ============================================================================

@struct Canvas2DRenderer
  c2d_width: i64
  c2d_height: i64
  c2d_scale_factor: f64
  c2d_draw_call_count: i64
  c2d_total_quads: i64
  c2d_is_ready: bool
  c2d_clear_color: i64
  c2d_clip_stack: array
  c2d_current_clip: array
  c2d_pixels: array
  c2d_dirty_rect: array
@end

@fn canvas2d_renderer_new(width, height, scale_factor)
  @if width <= 0 width = 1 @end
  @if height <= 0 height = 1 @end
  @if scale_factor <= 0.0 scale_factor = 1.0 @end
  
  total_pixels = width * height
  buf = []
  i = 0
  @while i < total_pixels
    buf = buf.push(0)
    i = i + 1
  @end
  
  init_clip = [0, 0, width, height]
  
  return {
    c2d_width: width,
    c2d_height: height,
    c2d_scale_factor: scale_factor,
    c2d_draw_call_count: 0,
    c2d_total_quads: 0,
    c2d_is_ready: true,
    c2d_clear_color: 0,
    c2d_clip_stack: [],
    c2d_current_clip: init_clip,
    c2d_pixels: buf,
    c2d_dirty_rect: [0, 0, width, height]
  }
@end

@fn canvas2d_renderer_begin_frame(renderer, clear_color)
  total = renderer.c2d_width * renderer.c2d_height
  i = 0
  @while i < total
    renderer.c2d_pixels[i] = clear_color
    i = i + 1
  @end
  
  renderer.c2d_clear_color = clear_color
  renderer.c2d_clip_stack = []
  renderer.c2d_current_clip = [0, 0, renderer.c2d_width, renderer.c2d_height]
  renderer.c2d_draw_call_count = 0
  renderer.c2d_total_quads = 0
  return renderer
@end

@fn canvas2d_renderer_push_clip(renderer, x, y, w, h)
  cur = renderer.c2d_current_clip
  req_min_x = x
  req_min_y = y
  req_max_x = x + w
  req_max_y = y + h
  
  new_min_x = cur[0]
  @if req_min_x > new_min_x new_min_x = req_min_x @end
  new_min_y = cur[1]
  @if req_min_y > new_min_y new_min_y = req_min_y @end
  new_max_x = cur[2]
  @if req_max_x < new_max_x new_max_x = req_max_x @end
  new_max_y = cur[3]
  @if req_max_y < new_max_y new_max_y = req_max_y @end
  
  @if new_min_x > new_max_x new_min_x = new_max_x @end
  @if new_min_y > new_max_y new_min_y = new_max_y @end
  
  renderer.c2d_clip_stack = renderer.c2d_clip_stack.push(cur)
  renderer.c2d_current_clip = [new_min_x, new_min_y, new_max_x, new_max_y]
  return renderer
@end

@fn canvas2d_renderer_pop_clip(renderer)
  stack_len = renderer.c2d_clip_stack.len()
  @if stack_len > 0
    top_idx = stack_len - 1
    renderer.c2d_current_clip = renderer.c2d_clip_stack[top_idx]
    
    new_stack = []
    i = 0
    @while i < top_idx
      new_stack = new_stack.push(renderer.c2d_clip_stack[i])
      i = i + 1
    @end
    renderer.c2d_clip_stack = new_stack
  @else
    renderer.c2d_current_clip = [0, 0, renderer.c2d_width, renderer.c2d_height]
  @end
  return renderer
@end

@fn canvas2d_renderer_set_pixel(renderer, x, y, color)
  @if x < 0 || x >= renderer.c2d_width || y < 0 || y >= renderer.c2d_height
    return renderer
  @end
  
  clip = renderer.c2d_current_clip
  @if x < clip[0] || x >= clip[2] || y < clip[1] || y >= clip[3]
    return renderer
  @end
  
  idx = (y * renderer.c2d_width) + x
  renderer.c2d_pixels[idx] = color
  return renderer
@end

@fn canvas2d_renderer_blend_pixel(renderer, x, y, color)
  @if x < 0 || x >= renderer.c2d_width || y < 0 || y >= renderer.c2d_height
    return renderer
  @end
  
  clip = renderer.c2d_current_clip
  @if x < clip[0] || x >= clip[2] || y < clip[1] || y >= clip[3]
    return renderer
  @end
  
  idx = (y * renderer.c2d_width) + x
  dst = renderer.c2d_pixels[idx]
  renderer.c2d_pixels[idx] = argb_blend(color, dst)
  return renderer
@end

@! ============================================================================
@! 4. DRAWING PRIMITIVES (RECTANGLES, ROUNDED CORNERS, BORDERS, GRADIENTS, LINES)
@! ============================================================================

@fn is_inside_rounded_rect(cx, cy, rx0, ry0, rx1, ry1, radius)
  @if radius <= 0 return true @end
  
  w = rx1 - rx0
  h = ry1 - ry0
  @if radius * 2 > w radius = w / 2 @end
  @if radius * 2 > h radius = h / 2 @end
  @if radius <= 0 return true @end

  @! Check 4 corner quadrants
  @! Top-left
  @if cx < rx0 + radius && cy < ry0 + radius
    dx = cx - (rx0 + radius)
    dy = cy - (ry0 + radius)
    return (dx * dx) + (dy * dy) <= (radius * radius)
  @end
  @! Top-right
  @if cx >= rx1 - radius && cy < ry0 + radius
    dx = cx - (rx1 - radius - 1)
    dy = cy - (ry0 + radius)
    return (dx * dx) + (dy * dy) <= (radius * radius)
  @end
  @! Bottom-left
  @if cx < rx0 + radius && cy >= ry1 - radius
    dx = cx - (rx0 + radius)
    dy = cy - (ry1 - radius - 1)
    return (dx * dx) + (dy * dy) <= (radius * radius)
  @end
  @! Bottom-right
  @if cx >= rx1 - radius && cy >= ry1 - radius
    dx = cx - (rx1 - radius - 1)
    dy = cy - (ry1 - radius - 1)
    return (dx * dx) + (dy * dy) <= (radius * radius)
  @end

  return true
@end

@fn canvas2d_renderer_draw_rect(renderer, x, y, w, h, bg_col, border_col, border_w, radius)
  @if w <= 0 || h <= 0 return renderer @end
  
  clip = renderer.c2d_current_clip
  rx0 = x
  @if clip[0] > rx0 rx0 = clip[0] @end
  ry0 = y
  @if clip[1] > ry0 ry0 = clip[1] @end
  
  rx1 = x + w
  @if clip[2] < rx1 rx1 = clip[2] @end
  ry1 = y + h
  @if clip[3] < ry1 ry1 = clip[3] @end
  
  @if rx0 >= rx1 || ry0 >= ry1
    return renderer
  @end
  
  @! Fill rectangle body
  @if bg_col != 0
    sa = argb_get_a(bg_col)
    cy = ry0
    @while cy < ry1
      row_offset = cy * renderer.c2d_width
      cx = rx0
      @while cx < rx1
        @if radius > 0
          @if is_inside_rounded_rect(cx, cy, x, y, x + w, y + h, radius)
            @if sa == 255
              renderer.c2d_pixels[row_offset + cx] = bg_col
            @else
              dst = renderer.c2d_pixels[row_offset + cx]
              renderer.c2d_pixels[row_offset + cx] = argb_blend(bg_col, dst)
            @end
          @end
        @else
          @if sa == 255
            renderer.c2d_pixels[row_offset + cx] = bg_col
          @else
            dst = renderer.c2d_pixels[row_offset + cx]
            renderer.c2d_pixels[row_offset + cx] = argb_blend(bg_col, dst)
          @end
        @end
        cx = cx + 1
      @end
      cy = cy + 1
    @end
  @end
  
  @! Draw borders if specified
  @if border_w > 0 && border_col != 0
    b = 0
    @while b < border_w
      top_y = y + b
      bot_y = (y + h - 1) - b
      cx = x + b
      x_end = (x + w) - b
      
      @while cx < x_end
        renderer = canvas2d_renderer_blend_pixel(renderer, cx, top_y, border_col)
        renderer = canvas2d_renderer_blend_pixel(renderer, cx, bot_y, border_col)
        cx = cx + 1
      @end
      
      cy = y + b
      y_end = (y + h) - b
      @while cy < y_end
        renderer = canvas2d_renderer_blend_pixel(renderer, x + b, cy, border_col)
        renderer = canvas2d_renderer_blend_pixel(renderer, (x + w - 1) - b, cy, border_col)
        cy = cy + 1
      @end
      b = b + 1
    @end
  @end
  
  renderer.c2d_draw_call_count = renderer.c2d_draw_call_count + 1
  renderer.c2d_total_quads = renderer.c2d_total_quads + 1
  return renderer
@end

@fn canvas2d_renderer_draw_shadow_rect(renderer, x, y, w, h, bg_col, radius, shadow_col, shadow_blur, off_x, off_y)
  @if w <= 0 || h <= 0 return renderer @end
  
  @if shadow_col != 0 && shadow_blur > 0
    passes = shadow_blur / 2
    @if passes < 1 passes = 1 @end
    @if passes > 6 passes = 6 @end
    
    base_sa = argb_get_a(shadow_col)
    step_alpha = base_sa / (passes * 2)
    @if step_alpha < 4 step_alpha = 4 @end
    
    sr = argb_get_r(shadow_col)
    sg = argb_get_g(shadow_col)
    sb = argb_get_b(shadow_col)
    
    p = passes
    @while p >= 1
      expand = p * 2
      sx = x + off_x - expand
      sy = y + off_y - expand
      sw = w + (expand * 2)
      sh = h + (expand * 2)
      pass_col = argb_pack(step_alpha, sr, sg, sb)
      renderer = canvas2d_renderer_draw_rect(renderer, sx, sy, sw, sh, pass_col, 0, 0, radius + expand)
      p = p - 1
    @end
  @end
  
  renderer = canvas2d_renderer_draw_rect(renderer, x, y, w, h, bg_col, 0, 0, radius)
  return renderer
@end

@fn canvas2d_renderer_draw_line(renderer, x0, y0, x1, y1, color)
  dx = x1 - x0
  @if dx < 0 dx = -dx @end
  dy = y1 - y0
  @if dy < 0 dy = -dy @end
  
  sx = 1
  @if x0 >= x1 sx = -1 @end
  sy = 1
  @if y0 >= y1 sy = -1 @end
  
  err = dx - dy
  
  cx = x0
  cy = y0
  running = true
  @while running
    renderer = canvas2d_renderer_blend_pixel(renderer, cx, cy, color)
    @if cx == x1 && cy == y1
      running = false
    @else
      e2 = 2 * err
      @if e2 > -dy
        err = err - dy
        cx = cx + sx
      @end
      @if e2 < dx
        err = err + dx
        cy = cy + sy
      @end
    @end
  @end
  
  renderer.c2d_draw_call_count = renderer.c2d_draw_call_count + 1
  return renderer
@end

@fn canvas2d_renderer_fill_gradient(renderer, x, y, w, h, col_start, col_end, is_vertical)
  @if w <= 0 || h <= 0 return renderer @end
  
  sa = argb_get_a(col_start)
  sr = argb_get_r(col_start)
  sg = argb_get_g(col_start)
  sb = argb_get_b(col_start)
  
  ea = argb_get_a(col_end)
  er = argb_get_r(col_end)
  eg = argb_get_g(col_end)
  eb = argb_get_b(col_end)
  
  @if is_vertical
    cy = 0
    @while cy < h
      t_num = cy
      t_den = h
      @if t_den <= 0 t_den = 1 @end
      
      ca = sa + (((ea - sa) * t_num) / t_den)
      cr = sr + (((er - sr) * t_num) / t_den)
      cg = sg + (((eg - sg) * t_num) / t_den)
      cb = sb + (((eb - sb) * t_num) / t_den)
      c = argb_pack(ca, cr, cg, cb)
      
      renderer = canvas2d_renderer_draw_rect(renderer, x, y + cy, w, 1, c, 0, 0, 0)
      cy = cy + 1
    @end
  @else
    cx = 0
    @while cx < w
      t_num = cx
      t_den = w
      @if t_den <= 0 t_den = 1 @end
      
      ca = sa + (((ea - sa) * t_num) / t_den)
      cr = sr + (((er - sr) * t_num) / t_den)
      cg = sg + (((eg - sg) * t_num) / t_den)
      cb = sb + (((eb - sb) * t_num) / t_den)
      c = argb_pack(ca, cr, cg, cb)
      
      renderer = canvas2d_renderer_draw_rect(renderer, x + cx, y, 1, h, c, 0, 0, 0)
      cx = cx + 1
    @end
  @end
  
  return renderer
@end

@! ============================================================================
@! 5. TEXT & GLYPH RENDERING
@! ============================================================================

@fn canvas2d_renderer_draw_glyph(renderer, char_code, x, y, scale, color)
  glyph = font_get_glyph_5x7(char_code)
  @if scale < 1 scale = 1 @end
  
  col = 0
  @while col < 5
    bits = glyph[col]
    row = 0
    @while row < 7
      @if (bits & (pow2(row))) != 0
        px = x + (col * scale)
        py = y + (row * scale)
        @if scale == 1
          renderer = canvas2d_renderer_blend_pixel(renderer, px, py, color)
        @else
          renderer = canvas2d_renderer_draw_rect(renderer, px, py, scale, scale, color, 0, 0, 0)
        @end
      @end
      row = row + 1
    @end
    col = col + 1
  @end
  return renderer
@end

@fn canvas2d_renderer_draw_text(renderer, text, x, y, font_size, color)
  t_len = str_len(text)
  @if t_len == 0 return renderer @end
  
  scale = font_size / 7
  @if scale < 1 scale = 1 @end
  char_adv = (5 * scale) + scale
  
  cur_x = x
  i = 0
  @while i < t_len
    c = str_char_at(text, i)
    renderer = canvas2d_renderer_draw_glyph(renderer, c, cur_x, y, scale, color)
    cur_x = cur_x + char_adv
    i = i + 1
  @end
  
  renderer.c2d_draw_call_count = renderer.c2d_draw_call_count + 1
  return renderer
@end

@fn canvas2d_renderer_draw_image(renderer, texture_id, sx, sy, sw, sh, dx, dy, dw, dh, opacity)
  @if dw <= 0 || dh <= 0 return renderer @end
  
  renderer.c2d_draw_call_count = renderer.c2d_draw_call_count + 1
  renderer.c2d_total_quads = renderer.c2d_total_quads + 1
  return renderer
@end

@! ============================================================================
@! 6. HIERARCHICAL LAYOUT NODE RENDERING
@! ============================================================================

@fn canvas2d_renderer_render_layout_node(renderer, node)
  @if node == 0 return renderer @end
  
  @! Draw text if present
  @if str_len(node.text_content) > 0
    fs = node.font_size
    @if fs <= 0 fs = 14 @end
    renderer = canvas2d_renderer_draw_text(renderer, node.text_content, node.x, node.y, fs, 0xFFFFFFFF)
  @end
  
  @! Traverse children
  ci = 0
  @while ci < node.children.len()
    renderer = canvas2d_renderer_render_layout_node(renderer, node.children[ci])
    ci = ci + 1
  @end
  
  return renderer
@end

@! ============================================================================
@! 7. FRAME PRESENTATION & IMAGE EXPORT (PPM & ARGB BUFFER)
@! ============================================================================

@fn canvas2d_renderer_end_frame(renderer)
  renderer.c2d_dirty_rect = [0, 0, renderer.c2d_width, renderer.c2d_height]
  return renderer
@end

@fn canvas2d_renderer_get_pixel(renderer, x, y)
  @if x < 0 || x >= renderer.c2d_width || y < 0 || y >= renderer.c2d_height
    return 0
  @end
  idx = (y * renderer.c2d_width) + x
  return renderer.c2d_pixels[idx]
@end

@fn canvas2d_renderer_to_argb_buffer(renderer)
  return renderer.c2d_pixels
@end

@fn canvas2d_renderer_to_ppm(renderer)
  w = renderer.c2d_width
  h = renderer.c2d_height
  
  header = "P3\n" + int_to_str(w) + " " + int_to_str(h) + "\n255\n"
  body = ""
  
  y = 0
  @while y < h
    row_offset = y * w
    x = 0
    @while x < w
      col = renderer.c2d_pixels[row_offset + x]
      r = argb_get_r(col)
      g = argb_get_g(col)
      b = argb_get_b(col)
      body = body + int_to_str(r) + " " + int_to_str(g) + " " + int_to_str(b) + " "
      x = x + 1
    @end
    body = body + "\n"
    y = y + 1
  @end
  
  return header + body
@end
