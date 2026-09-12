@! ============================================================================
@! LIPI SOVEREIGN IDE — UI POPUP & TOOLTIP OVERLAY RENDERING
@! Module: universe/ide/ui_popup.lp
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/gui/canvas"
import "universe/gui/font"
import "universe/tools/lsp/protocol"
import "universe/ide/lsp_client"

@! ----------------------------------------------------------------------------
@! 1. AUTOCOMPLETE COMPLETION DROPDOWN POPUP
@! ----------------------------------------------------------------------------

@fn popup_render_completions(lsp, canvas, font, anchor_x, anchor_y, max_w, max_h)
  @if lsp.completion_active == false || lsp.completion_items.len() == 0
    return canvas
  @end

  items = lsp.completion_items
  n_items = items.len()
  sel_idx = lsp.completion_selected_idx

  item_h = 18
  visible_count = n_items
  @if visible_count > 7 visible_count = 7 @end

  pop_w = 260
  @if pop_w > max_w pop_w = max_w @end
  @if pop_w < 160 pop_w = 160 @end

  pop_h = visible_count * item_h + 4

  @! Viewport boundary clamping
  pop_x = anchor_x
  pop_y = anchor_y + 18
  @if pop_x + pop_w > canvas.width
    pop_x = canvas.width - pop_w - 4
  @end
  @if pop_x < 0 pop_x = 0 @end

  @if pop_y + pop_h > canvas.height - 20
    @! Flip above anchor line if overflowing bottom
    pop_y = anchor_y - pop_h - 2
    @if pop_y < 0 pop_y = 0 @end
  @end

  @! Background shadow & container fill
  canvas = canvas_fill_rect(canvas, pop_x + 2, pop_y + 2, pop_w, pop_h, 0x88000000)
  canvas = canvas_fill_rect(canvas, pop_x, pop_y, pop_w, pop_h, 0xFF252526)
  canvas = canvas_draw_rect(canvas, pop_x, pop_y, pop_w, pop_h, 0xFF007ACC)

  @! Calculate visible scroll window
  start_idx = 0
  @if sel_idx >= visible_count
    start_idx = sel_idx - visible_count + 1
  @end

  i = 0
  @while i < visible_count && (start_idx + i) < n_items
    item_idx = start_idx + i
    item = items[item_idx]
    row_y = pop_y + 2 + (i * item_h)

    @! Row background (selected highlight vs normal)
    @if item_idx == sel_idx
      canvas = canvas_fill_rect(canvas, pop_x + 1, row_y, pop_w - 2, item_h, 0xFF094771)
      canvas = canvas_draw_rect(canvas, pop_x + 1, row_y, pop_w - 2, item_h, 0xFF1C97EA)
    @end

    @! Kind badge icon & color
    badge = "[•]"
    badge_col = 0xFF9CDCFE
    @if item.kind == 14 @! Keyword
      badge = "[K]"
      badge_col = 0xFF569CD6
    @elif item.kind == 3 || item.kind == 2 @! Function/Method
      badge = "[F]"
      badge_col = 0xFFDCDCAA
    @elif item.kind == 7 || item.kind == 23 @! Struct/Class
      badge = "[S]"
      badge_col = 0xFF4EC9B0
    @end

    canvas = font_draw_text(canvas, font, pop_x + 4, row_y + 1, badge, badge_col)

    @! Item label
    label_col = 0xFFD4D4D4
    @if item_idx == sel_idx label_col = 0xFFFFFFFF @end
    canvas = font_draw_text_clipped(canvas, font, pop_x + 32, row_y + 1, item.label, label_col, pop_w - 38)

    i = i + 1
  @end

  @! Scrollbar for popup if total items > visible
  @if n_items > visible_count
    sb_w = 4
    sb_x = pop_x + pop_w - sb_w - 1
    sb_h = pop_h - 4
    canvas = canvas_fill_rect(canvas, sb_x, pop_y + 2, sb_w, sb_h, 0xFF1E1E1E)
    thumb_h = (sb_h * visible_count) / n_items
    @if thumb_h < 8 thumb_h = 8 @end
    thumb_y = pop_y + 2 + (start_idx * (sb_h - thumb_h)) / (n_items - visible_count)
    canvas = canvas_fill_rect(canvas, sb_x, thumb_y, sb_w, thumb_h, 0xFF686868)
  @end

  return canvas
@end

@! ----------------------------------------------------------------------------
@! 2. HOVER DOCUMENTATION CARD TOOLTIP
@! ----------------------------------------------------------------------------

@fn popup_render_hover(lsp, canvas, font, anchor_x, anchor_y, max_w, max_h)
  @if lsp.hover_active == false || str_len(lsp.hover_text) == 0
    return canvas
  @end

  raw_doc = lsp.hover_text
  lines = string_split(raw_doc, "\n")
  n_lines = lines.len()
  @if n_lines == 0 return canvas @end

  card_w = 340
  @if card_w > max_w card_w = max_w @end
  @if card_w < 200 card_w = 200 @end

  line_h = 16
  card_h = (n_lines * line_h) + 16

  card_x = anchor_x
  card_y = anchor_y + 20
  @if card_x + card_w > canvas.width
    card_x = canvas.width - card_w - 4
  @end
  @if card_x < 0 card_x = 0 @end

  @if card_y + card_h > canvas.height - 20
    card_y = anchor_y - card_h - 4
    @if card_y < 0 card_y = 0 @end
  @end

  @! Background shadow & card fill
  canvas = canvas_fill_rect(canvas, card_x + 2, card_y + 2, card_w, card_h, 0x88000000)
  canvas = canvas_fill_rect(canvas, card_x, card_y, card_w, card_h, 0xFF2D2D30)
  canvas = canvas_draw_rect(canvas, card_x, card_y, card_w, card_h, 0xFF007ACC)

  @! Top accent header bar
  canvas = canvas_fill_rect(canvas, card_x + 1, card_y + 1, card_w - 2, 4, 0xFF007ACC)

  i = 0
  @while i < n_lines
    l_text = lines[i]
    draw_y = card_y + 8 + (i * line_h)
    
    @! Clean markdown code fence formatting
    col = 0xFFCCCCCC
    @if str_starts_with(l_text, "```")
      l_text = "────"
      col = 0xFF555555
    @elif str_starts_with(l_text, "@fn") || str_starts_with(l_text, "@struct") || str_starts_with(l_text, "fn ") || str_starts_with(l_text, "struct ")
      col = 0xFFDCDCAA
    @end

    canvas = font_draw_text_clipped(canvas, font, card_x + 8, draw_y, l_text, col, card_w - 16)
    i = i + 1
  @end

  return canvas
@end

@! ----------------------------------------------------------------------------
@! 3. DIAGNOSTIC ERROR WAVY / SQUIGGLY UNDERLINE
@! ----------------------------------------------------------------------------

@fn popup_render_diagnostics_wave(canvas, x, y, width, color)
  @if width <= 0 return canvas @end
  
  i = 0
  @while i < width
    offset_y = 0
    mod4 = i % 4
    @if mod4 == 1 || mod4 == 2
      offset_y = 1
    @end

    canvas = canvas_set_pixel(canvas, x + i, y + offset_y, color)
    i = i + 1
  @end
  return canvas
@end
