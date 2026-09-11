@! ============================================================================
@! MAYA SOVEREIGN IDE — DOCKED MULTI-TAB OUTPUT CONSOLE PANE
@! Module: universe/ide/console.maya
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! 100% Pure Maya Implementation — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/gui/canvas"
import "universe/gui/font"

@! ----------------------------------------------------------------------------
@! 1. CONSOLE DATA STRUCTURES
@! ----------------------------------------------------------------------------

@struct ConsoleLine
  text: string
  color: i64
  stream_type: string   @! "STDOUT" | "STDERR" | "INFO" | "SUCCESS" | "ERROR" | "BUILD" | "DIAG"
  timestamp: string
@end

@struct StudioConsole
  lines: array
  active_tab: string     @! "OUTPUT" | "DIAGNOSTICS" | "BUILD"
  scroll_y: i64
  auto_scroll: bool
  max_lines: i64
  is_visible: bool
  height: i64
@end

@! ----------------------------------------------------------------------------
@! 2. CONSTRUCTORS & HELPERS
@! ----------------------------------------------------------------------------

@fn console_new(height)
  @if height <= 0 height = 160 @end
  return {
    lines: [],
    active_tab: "OUTPUT",
    scroll_y: 0,
    auto_scroll: true,
    max_lines: 1000,
    is_visible: true,
    height: height
  }
@end

@fn console_color_for_stream(stream_type)
  @if stream_type == "STDOUT"
    return 0xFFCCCCCC
  @elif stream_type == "STDERR" || stream_type == "ERROR"
    return 0xFFF44747
  @elif stream_type == "SUCCESS"
    return 0xFF4EC9B0
  @elif stream_type == "INFO"
    return 0xFF569CD6
  @elif stream_type == "WARNING"
    return 0xFFCCA700
  @elif stream_type == "BUILD"
    return 0xFFE5C07B
  @elif stream_type == "DIAG"
    return 0xFFD16969
  @end
  return 0xFFD4D4D4
@end

@! ----------------------------------------------------------------------------
@! 3. LINE BUFFERING & APPENDING
@! ----------------------------------------------------------------------------

@fn console_append(con, text, stream_type)
  col = console_color_for_stream(stream_type)
  return console_append_raw(con, text, col, stream_type)
@end

@fn console_append_raw(con, text, color, stream_type)
  lines = string_split(text, "\n")
  i = 0
  n_lines = lines.len()
  updated_lines = con.lines

  @while i < n_lines
    line_txt = lines[i]
    cl = {
      text: line_txt,
      color: color,
      stream_type: stream_type,
      timestamp: ""
    }
    updated_lines = updated_lines.push(cl)
    i = i + 1
  @end

  @! Trim if exceeding max_lines
  @if updated_lines.len() > con.max_lines
    excess = updated_lines.len() - con.max_lines
    trimmed = []
    k = excess
    @while k < updated_lines.len()
      trimmed = trimmed.push(updated_lines[k])
      k = k + 1
    @end
    updated_lines = trimmed
  @end

  con.lines = updated_lines

  @! Auto-scroll to bottom if enabled
  @if con.auto_scroll == true
    tab_lines = console_get_lines_for_tab(con, con.active_tab)
    v_lines = (con.height - 24) / 16
    @if tab_lines.len() > v_lines
      con.scroll_y = tab_lines.len() - v_lines
    @else
      con.scroll_y = 0
    @end
  @end

  return con
@end

@fn console_clear(con)
  con.lines = []
  con.scroll_y = 0
  return con
@end

@fn console_set_tab(con, tab_name)
  con.active_tab = tab_name
  con.scroll_y = 0
  return con
@end

@fn console_scroll(con, delta_y)
  tab_lines = console_get_lines_for_tab(con, con.active_tab)
  con.scroll_y = con.scroll_y + delta_y
  v_lines = (con.height - 24) / 16
  max_scroll = tab_lines.len() - v_lines
  @if max_scroll < 0 max_scroll = 0 @end
  @if con.scroll_y > max_scroll con.scroll_y = max_scroll @end
  @if con.scroll_y < 0 con.scroll_y = 0 @end
  return con
@end

@fn console_toggle_visible(con)
  con.is_visible = !con.is_visible
  return con
@end

@fn console_get_line_count(con)
  return con.lines.len()
@end

@fn console_get_lines_for_tab(con, tab_name)
  @if tab_name == "OUTPUT"
    return con.lines
  @end

  filtered = []
  i = 0
  @while i < con.lines.len()
    l = con.lines[i]
    @if tab_name == "DIAGNOSTICS" && (l.stream_type == "DIAG" || l.stream_type == "ERROR" || l.stream_type == "WARNING")
      filtered = filtered.push(l)
    @elif tab_name == "BUILD" && (l.stream_type == "BUILD" || l.stream_type == "SUCCESS")
      filtered = filtered.push(l)
    @end
    i = i + 1
  @end
  return filtered
@end

@! ----------------------------------------------------------------------------
@! 4. CANVAS RASTERIZATION RENDERING
@! ----------------------------------------------------------------------------

@fn console_render(con, canvas, font, x, y, w, h)
  @if con.is_visible == false || h <= 0 || w <= 0
    return canvas
  @end

  hdr_h = 24
  body_h = h - hdr_h
  line_h = 16

  @! 1. Header Ribbon Background
  canvas = canvas_fill_rect(canvas, x, y, w, hdr_h, 0xFF252526)
  canvas = canvas_draw_line(canvas, x, y + hdr_h, x + w, y + hdr_h, 0xFF333333)

  @! 2. Tab Buttons: [OUTPUT], [DIAGNOSTICS], [BUILD]
  tabs = ["OUTPUT", "DIAGNOSTICS", "BUILD"]
  tab_x = x + 8
  t_idx = 0
  @while t_idx < 3
    t_name = tabs[t_idx]
    t_w = 90
    @if t_name == "DIAGNOSTICS" t_w = 110 @end
    @if t_name == "BUILD" t_w = 70 @end

    is_active = (con.active_tab == t_name)
    @if is_active == true
      canvas = canvas_fill_rect(canvas, tab_x, y, t_w, hdr_h, 0xFF1E1E1E)
      canvas = canvas_fill_rect(canvas, tab_x, y + hdr_h - 2, t_w, 2, 0xFF007ACC)
      canvas = font_draw_text(canvas, font, tab_x + 8, y + 4, t_name, 0xFFFFFFFF)
    @else
      canvas = font_draw_text(canvas, font, tab_x + 8, y + 4, t_name, 0xFF858585)
    @end

    tab_x = tab_x + t_w + 4
    t_idx = t_idx + 1
  @end

  @! 3. Clear Button on Right Header
  clr_w = 64
  clr_x = x + w - clr_w - 8
  canvas = canvas_fill_rect(canvas, clr_x, y + 2, clr_w, 20, 0xFF333337)
  canvas = font_draw_text(canvas, font, clr_x + 8, y + 4, "Clear", 0xFFCCCCCC)

  @! 4. Console Body Viewport
  body_y = y + hdr_h
  canvas = canvas_fill_rect(canvas, x, body_y, w, body_h, 0xFF181818)

  tab_lines = console_get_lines_for_tab(con, con.active_tab)
  n_tab_lines = tab_lines.len()
  v_lines = body_h / line_h

  canvas = canvas_push_clip(canvas, x, body_y, w - 10, body_h)

  i = 0
  @while i < v_lines
    line_idx = con.scroll_y + i
    @if line_idx < n_tab_lines
      cl = tab_lines[line_idx]
      draw_y = body_y + (i * line_h) + 2

      @! Prefix prompt
      prompt_str = "> "
      prompt_col = 0xFF555555
      @if cl.stream_type == "ERROR" || cl.stream_type == "STDERR"
        prompt_str = "x "
        prompt_col = 0xFFF44747
      @elif cl.stream_type == "SUCCESS"
        prompt_str = "v "
        prompt_col = 0xFF4EC9B0
      @elif cl.stream_type == "BUILD"
        prompt_str = "* "
        prompt_col = 0xFFE5C07B
      @end

      canvas = font_draw_text(canvas, font, x + 8, draw_y, prompt_str, prompt_col)
      canvas = font_draw_text_clipped(canvas, font, x + 24, draw_y, cl.text, cl.color, w - 40)
    @end
    i = i + 1
  @end

  canvas = canvas_pop_clip(canvas)

  @! 5. Vertical Scrollbar
  sb_w = 8
  sb_x = x + w - sb_w - 1
  canvas = canvas_fill_rect(canvas, sb_x, body_y, sb_w, body_h, 0xFF252526)
  @if n_tab_lines > v_lines && n_tab_lines > 0
    thumb_h = (body_h * v_lines) / n_tab_lines
    @if thumb_h < 12 thumb_h = 12 @end
    thumb_y = body_y + (con.scroll_y * (body_h - thumb_h)) / (n_tab_lines - v_lines)
    canvas = canvas_fill_rect(canvas, sb_x + 1, thumb_y, sb_w - 2, thumb_h, 0xFF555555)
  @end

  return canvas
@end
