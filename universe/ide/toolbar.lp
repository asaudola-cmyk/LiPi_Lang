@! ============================================================================
@! LIPI SOVEREIGN IDE — SOVEREIGN ACTION TOOLBAR RIBBON
@! Module: universe/ide/toolbar.lp
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/gui/canvas"
import "universe/gui/font"

@! ----------------------------------------------------------------------------
@! 1. TOOLBAR DATA STRUCTURES
@! ----------------------------------------------------------------------------

@struct ToolbarButton
  x: i64
  y: i64
  width: i64
  height: i64
  id: string
  label: string
  shortcut: string
  action: string
  bg_color: i64
  text_color: i64
  is_hovered: bool
  is_pressed: bool
@end

@struct StudioToolbar
  buttons: array
  height: i64
  status_message: string
  status_color: i64
@end

@! ----------------------------------------------------------------------------
@! 2. CONSTRUCTOR & INITIALIZATION
@! ----------------------------------------------------------------------------

@fn toolbar_new(w, h)
  @if h <= 0 h = 36 @end

  btn_defs = [
    ["run", "▶ Run", "F5", "RUN", 0xFF0E639C, 0xFFFFFFFF],
    ["build", "🔨 Build", "Ctrl+B", "BUILD", 0xFF388A34, 0xFFFFFFFF],
    ["format", "✨ Format", "Ctrl+Shift+F", "FORMAT", 0xFF2D2D30, 0xFFE0E0E0],
    ["stop", "⏹ Stop", "Shift+F5", "STOP", 0xFFDA3633, 0xFFFFFFFF],
    ["save", "💾 Save", "Ctrl+S", "SAVE", 0xFF2EA043, 0xFFFFFFFF],
    ["clear_console", "🗑 Clear", "", "CLEAR", 0xFF333337, 0xFFCCCCCC]
  ]

  buttons = []
  cur_x = 8
  btn_y = 5
  btn_h = 26

  i = 0
  @while i < btn_defs.len()
    d = btn_defs[i]
    b_id = d[0]
    b_label = d[1]
    b_short = d[2]
    b_act = d[3]
    b_bg = d[4]
    b_fg = d[5]

    txt_len = str_len(b_label)
    @if str_len(b_short) > 0
      txt_len = txt_len + str_len(b_short) + 3
    @end
    b_w = (txt_len * 8) + 16
    @if b_w < 60 b_w = 60 @end

    btn = {
      x: cur_x,
      y: btn_y,
      width: b_w,
      height: btn_h,
      id: b_id,
      label: b_label,
      shortcut: b_short,
      action: b_act,
      bg_color: b_bg,
      text_color: b_fg,
      is_hovered: false,
      is_pressed: false
    }

    buttons = buttons.push(btn)
    cur_x = cur_x + b_w + 6
    i = i + 1
  @end

  return {
    buttons: buttons,
    height: h,
    status_message: "Ready",
    status_color: 0xFF4EC9B0
  }
@end

@! ----------------------------------------------------------------------------
@! 3. EVENT HANDLING & STATUS
@! ----------------------------------------------------------------------------

@fn toolbar_handle_click(tb, click_x, click_y)
  i = 0
  n_btns = tb.buttons.len()
  @while i < n_btns
    b = tb.buttons[i]
    @if click_x >= b.x && click_x < b.x + b.width && click_y >= b.y && click_y < b.y + b.height
      return b.id
    @end
    i = i + 1
  @end
  return ""
@end

@fn toolbar_set_status(tb, msg, color)
  tb.status_message = msg
  tb.status_color = color
  return tb
@end

@! ----------------------------------------------------------------------------
@! 4. CANVAS RASTERIZATION
@! ----------------------------------------------------------------------------

@fn toolbar_render(tb, canvas, font, w)
  h = tb.height

  @! 1. Toolbar Background & Divider
  canvas = canvas_fill_rect(canvas, 0, 0, w, h, 0xFF2D2D30)
  canvas = canvas_draw_line(canvas, 0, h - 1, w, h - 1, 0xFF3E3E42)

  @! 2. Render Buttons
  i = 0
  n_btns = tb.buttons.len()
  @while i < n_btns
    b = tb.buttons[i]
    bg = b.bg_color
    @if b.is_hovered == true bg = 0xFF505054 @end
    @if b.is_pressed == true bg = 0xFF007ACC @end

    canvas = canvas_fill_rect(canvas, b.x, b.y, b.width, b.height, bg)
    canvas = canvas_draw_rect(canvas, b.x, b.y, b.width, b.height, 0xFF3E3E42)

    @! Label text
    canvas = font_draw_text(canvas, font, b.x + 8, b.y + 5, b.label, b.text_color)

    @! Shortcut badge
    @if str_len(b.shortcut) > 0
      badge_x = b.x + (str_len(b.label) * 8) + 12
      canvas = font_draw_text(canvas, font, badge_x, b.y + 5, "(" + b.shortcut + ")", 0xFF9E9E9E)
    @end

    i = i + 1
  @end

  @! 3. Status Indicator (Right aligned)
  @if str_len(tb.status_message) > 0
    stat_str = "● " + tb.status_message
    stat_len = str_len(stat_str) * 8
    stat_x = w - stat_len - 16
    @if stat_x > 0
      canvas = font_draw_text(canvas, font, stat_x, 10, stat_str, tb.status_color)
    @end
  @end

  return canvas
@end
