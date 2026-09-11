@! ============================================================================
@! MAYA WEB FRONTEND ENGINE — ANSI TERMINAL TRUECOLOR RASTERIZER (F13)
@! Module: universe/web/frontend/renderer/terminal_renderer.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - Direct 24-bit TrueColor ANSI escape sequence generator
@! - Dual-pixel Unicode upper-half block ('▀') terminal rasterizer
@! - Run-length ANSI color state caching & escape compaction
@! - Direct LayoutNode wireframe box-drawing & character-mode renderer
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"
import "universe/web/frontend/renderer/canvas2d_renderer"
import "universe/web/frontend/layout/layout_types"

@! ============================================================================
@! 1. DATA STRUCTURES & INITIALIZATION
@! ============================================================================

@struct TerminalRenderer
  term_cols: i64
  term_rows: i64
  term_char_buffer: array
  term_fg_buffer: array
  term_bg_buffer: array
  term_total_frames: i64
@end

@fn terminal_renderer_new(cols, rows)
  @if cols <= 0 cols = 80 @end
  @if rows <= 0 rows = 24 @end
  
  total_cells = cols * rows
  chars = []
  fg = []
  bg = []
  
  i = 0
  @while i < total_cells
    chars = chars.push(" ")
    fg = fg.push(0xFFFFFFFF)
    bg = bg.push(0xFF000000)
    i = i + 1
  @end
  
  return {
    term_cols: cols,
    term_rows: rows,
    term_char_buffer: chars,
    term_fg_buffer: fg,
    term_bg_buffer: bg,
    term_total_frames: 0
  }
@end

@! ============================================================================
@! 2. ANSI ESCAPE CODE FORMATTING & COMPACTION
@! ============================================================================

@fn ansi_escape_fg(r, g, b)
  return "[38;2;" + int_to_str(r) + ";" + int_to_str(g) + ";" + int_to_str(b) + "m"
@end

@fn ansi_escape_bg(r, g, b)
  return "[48;2;" + int_to_str(r) + ";" + int_to_str(g) + ";" + int_to_str(b) + "m"
@end

@fn ansi_reset()
  return "[0m"
@end

@fn terminal_format_truecolor(fg_r, fg_g, fg_b, bg_r, bg_g, bg_b, char_str)
  return ansi_escape_fg(fg_r, fg_g, fg_b) + ansi_escape_bg(bg_r, bg_g, bg_b) + char_str + ansi_reset()
@end

@! ============================================================================
@! 3. DUAL-PIXEL HALF-BLOCK CANVAS2D RASTERIZER
@! ============================================================================

@fn terminal_render_canvas_region(canvas, rx, ry, rw, rh)
  c_w = canvas.c2d_width
  c_h = canvas.c2d_height
  
  @if rx < 0 rx = 0 @end
  @if ry < 0 ry = 0 @end
  @if rx + rw > c_w rw = c_w - rx @end
  @if ry + rh > c_h rh = c_h - ry @end
  @if rw <= 0 || rh <= 0 return "" @end
  
  term_rows = (rh + 1) / 2
  out_str = ""
  
  half_block = "▀"
  
  prev_fg = -1
  prev_bg = -1
  
  row = 0
  @while row < term_rows
    y_top = ry + (row * 2)
    y_bot = y_top + 1
    
    col = 0
    @while col < rw
      x = rx + col
      
      top_col = canvas2d_renderer_get_pixel(canvas, x, y_top)
      bot_col = 0
      @if y_bot < c_h
        bot_col = canvas2d_renderer_get_pixel(canvas, x, y_bot)
      @end
      
      top_rgb = top_col & 16777215 @! 0x00FFFFFF
      bot_rgb = bot_col & 16777215
      
      @if top_rgb != prev_fg
        tr = argb_get_r(top_col)
        tg = argb_get_g(top_col)
        tb = argb_get_b(top_col)
        out_str = out_str + ansi_escape_fg(tr, tg, tb)
        prev_fg = top_rgb
      @end
      
      @if bot_rgb != prev_bg
        br = argb_get_r(bot_col)
        bg = argb_get_g(bot_col)
        bb = argb_get_b(bot_col)
        out_str = out_str + ansi_escape_bg(br, bg, bb)
        prev_bg = bot_rgb
      @end
      
      out_str = out_str + half_block
      col = col + 1
    @end
    
    out_str = out_str + ansi_reset() + "\n"
    prev_fg = -1
    prev_bg = -1
    row = row + 1
  @end
  
  return out_str
@end

@fn terminal_render_canvas(canvas)
  return terminal_render_canvas_region(canvas, 0, 0, canvas.c2d_width, canvas.c2d_height)
@end

@! ============================================================================
@! 4. DIRECT LAYOUT TREE CHARACTER-MODE RASTERIZER
@! ============================================================================

@fn layout_draw_to_grid(node, grid_chars, grid_cols, grid_rows, scale_x, scale_y)
  @if node == 0 return grid_chars @end
  
  gx = node.x / scale_x
  gy = node.y / scale_y
  gw = node.width / scale_x
  gh = node.height / scale_y
  
  @if gw < 2 gw = 2 @end
  @if gh < 2 gh = 2 @end
  
  @if gx < grid_cols && gy < grid_rows
    x1 = gx + gw - 1
    @if x1 >= grid_cols x1 = grid_cols - 1 @end
    y1 = gy + gh - 1
    @if y1 >= grid_rows y1 = grid_rows - 1 @end
    
    @! Draw top & bottom borders
    cx = gx
    @while cx <= x1
      @if gy >= 0 && gy < grid_rows
        grid_chars[(gy * grid_cols) + cx] = "─"
      @end
      @if y1 >= 0 && y1 < grid_rows
        grid_chars[(y1 * grid_cols) + cx] = "─"
      @end
      cx = cx + 1
    @end
    
    @! Draw left & right borders
    cy = gy
    @while cy <= y1
      @if gx >= 0 && gx < grid_cols
        grid_chars[(cy * grid_cols) + gx] = "│"
      @end
      @if x1 >= 0 && x1 < grid_cols
        grid_chars[(cy * grid_cols) + x1] = "│"
      @end
      cy = cy + 1
    @end
    
    @! Corners
    @if gy >= 0 && gx >= 0 && gy < grid_rows && gx < grid_cols
      grid_chars[(gy * grid_cols) + gx] = "┌"
    @end
    @if gy >= 0 && x1 >= 0 && gy < grid_rows && x1 < grid_cols
      grid_chars[(gy * grid_cols) + x1] = "┐"
    @end
    @if y1 >= 0 && gx >= 0 && y1 < grid_rows && gx < grid_cols
      grid_chars[(y1 * grid_cols) + gx] = "└"
    @end
    @if y1 >= 0 && x1 >= 0 && y1 < grid_rows && x1 < grid_cols
      grid_chars[(y1 * grid_cols) + x1] = "┘"
    @end
    
    @! Draw text if present
    @if str_len(node.text_content) > 0 && gy + 1 < y1
      ty = gy + 1
      tx = gx + 1
      t_len = str_len(node.text_content)
      ti = 0
      @while ti < t_len && tx + ti < x1
        c = str_from_char_code(str_char_at(node.text_content, ti))
        grid_chars[(ty * grid_cols) + (tx + ti)] = c
        ti = ti + 1
      @end
    @end
  @end
  
  @! Children
  ci = 0
  @while ci < node.children.len()
    grid_chars = layout_draw_to_grid(node.children[ci], grid_chars, grid_cols, grid_rows, scale_x, scale_y)
    ci = ci + 1
  @end
  
  return grid_chars
@end

@fn terminal_render_layout_tree(node, cols, rows)
  @if cols <= 0 cols = 80 @end
  @if rows <= 0 rows = 24 @end
  
  total = cols * rows
  grid = []
  i = 0
  @while i < total
    grid = grid.push(" ")
    i = i + 1
  @end
  
  scale_x = 10
  scale_y = 20
  
  grid = layout_draw_to_grid(node, grid, cols, rows, scale_x, scale_y)
  
  res = ""
  r = 0
  @while r < rows
    offset = r * cols
    c = 0
    @while c < cols
      res = res + grid[offset + c]
      c = c + 1
    @end
    res = res + "\n"
    r = r + 1
  @end
  
  return res
@end

@fn terminal_render_element(elem, cols, rows)
  @if cols <= 0 cols = 80 @end
  @if rows <= 0 rows = 24 @end
  
  total = cols * rows
  grid = []
  i = 0
  @while i < total
    grid = grid.push(" ")
    i = i + 1
  @end
  
  res = ""
  r = 0
  @while r < rows
    c = 0
    @while c < cols
      res = res + " "
      c = c + 1
    @end
    res = res + "\n"
    r = r + 1
  @end
  return res
@end
