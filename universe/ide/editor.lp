@! ============================================================================
@! MAYA SOVEREIGN IDE — HIGH-PERFORMANCE MULTI-LINE CODE EDITOR COMPONENT
@! Module: universe/ide/editor.maya
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/gui/canvas"
import "universe/gui/font"
import "universe/gui/event"
import "compiler/frontend/lexer"
import "universe/tools/lsp/protocol"
import "universe/tools/lsp/server"
import "universe/ide/syntax"
import "universe/ide/lsp_client"
import "universe/ide/ui_popup"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURE DEFINITIONS
@! ----------------------------------------------------------------------------

@struct EditorSelection
  active: bool
  start_line: i64
  start_col: i64
  end_line: i64
  end_col: i64
@end

@struct StudioEditor
  lines: array
  cursor_line: i64
  cursor_col: i64
  preferred_col: i64
  scroll_top_line: i64
  scroll_left_col: i64
  tab_size: i64
  is_dirty: bool
  file_path: string
  file_name: string
  gutter_width: i64
  line_height: i64
  char_width: i64
  selection: EditorSelection
  theme: SyntaxTheme
  lsp: LSPClient
@end

@! ----------------------------------------------------------------------------
@! 2. CONSTRUCTOR & FACTORIES
@! ----------------------------------------------------------------------------

@fn editor_selection_new()
  return {
    active: false,
    start_line: 0,
    start_col: 0,
    end_line: 0,
    end_col: 0
  }
@end

@fn studio_editor_new(file_path, content, theme)
  lines = string_split(content, "\n")
  @if lines.len() == 0
    lines = [""]
  @end

  f_name = "untitled.maya"
  @if str_len(file_path) > 0
    f_name = file_path
    last_slash = -1
    k = 0
    flen = str_len(file_path)
    @while k < flen
      @if str_char_at(file_path, k) == 47 @! '/'
        last_slash = k
      @end
      k = k + 1
    @end
    @if last_slash >= 0 && last_slash + 1 < flen
      f_name = str_substr(file_path, last_slash + 1, flen)
    @end
  @end

  lsp = lsp_client_new()
  @if str_len(file_path) > 0
    lsp = lsp_client_open(lsp, file_path, content)
  @end

  return {
    lines: lines,
    cursor_line: 0,
    cursor_col: 0,
    preferred_col: 0,
    scroll_top_line: 0,
    scroll_left_col: 0,
    tab_size: 2,
    is_dirty: false,
    file_path: file_path,
    file_name: f_name,
    gutter_width: 48,
    line_height: 16,
    char_width: 8,
    selection: editor_selection_new(),
    theme: theme,
    lsp: lsp
  }
@end

@! ----------------------------------------------------------------------------
@! 3. BUFFER ACCESSORS & SYNC
@! ----------------------------------------------------------------------------

@fn studio_editor_get_text(ed)
  return string_join(ed.lines, "\n")
@end

@fn studio_editor_get_line_count(ed)
  return ed.lines.len()
@end

@fn studio_editor_set_text(ed, content)
  lines = string_split(content, "\n")
  @if lines.len() == 0
    lines = [""]
  @end
  ed.lines = lines
  ed.cursor_line = 0
  ed.cursor_col = 0
  ed.preferred_col = 0
  ed.selection = editor_selection_new()
  ed.scroll_top_line = 0
  ed.scroll_left_col = 0
  ed.is_dirty = false

  @if str_len(ed.file_path) > 0
    ed.lsp = lsp_client_change(ed.lsp, ed.file_path, content)
  @end
  return ed
@end

@! ----------------------------------------------------------------------------
@! 4. SELECTION NORMALIZATION & MANIPULATION
@! ----------------------------------------------------------------------------

@fn editor_normalize_selection(sel)
  @if sel.start_line < sel.end_line
    return sel
  @elif sel.start_line > sel.end_line
    return {
      active: true,
      start_line: sel.end_line,
      start_col: sel.end_col,
      end_line: sel.start_line,
      end_col: sel.start_col
    }
  @else
    @if sel.start_col <= sel.end_col
      return sel
    @else
      return {
        active: true,
        start_line: sel.start_line,
        start_col: sel.end_col,
        end_line: sel.start_line,
        end_col: sel.start_col
      }
    @end
  @end
@end

@fn studio_editor_delete_selection(ed)
  @if ed.selection.active == false
    return ed
  @end

  sel = editor_normalize_selection(ed.selection)
  s_line = sel.start_line
  s_col = sel.start_col
  e_line = sel.end_line
  e_col = sel.end_col

  total_lines = ed.lines.len()
  @if s_line >= total_lines s_line = total_lines - 1 @end
  @if e_line >= total_lines e_line = total_lines - 1 @end
  @if s_line < 0 s_line = 0 @end
  @if e_line < 0 e_line = 0 @end

  start_str = ed.lines[s_line]
  end_str = ed.lines[e_line]

  s_len = str_len(start_str)
  @if s_col > s_len s_col = s_len @end
  @if s_col < 0 s_col = 0 @end

  e_len = str_len(end_str)
  @if e_col > e_len e_col = e_len @end
  @if e_col < 0 e_col = 0 @end

  head = str_substr(start_str, 0, s_col)
  tail = str_substr(end_str, e_col, e_len)
  merged_line = head + tail

  new_lines = []
  i = 0
  @while i < s_line
    new_lines = new_lines.push(ed.lines[i])
    i = i + 1
  @end

  new_lines = new_lines.push(merged_line)

  i = e_line + 1
  @while i < total_lines
    new_lines = new_lines.push(ed.lines[i])
    i = i + 1
  @end

  @if new_lines.len() == 0
    new_lines = [""]
  @end

  ed.lines = new_lines
  ed.cursor_line = s_line
  ed.cursor_col = s_col
  ed.preferred_col = s_col
  ed.selection = editor_selection_new()
  ed.is_dirty = true

  @if str_len(ed.file_path) > 0
    ed.lsp = lsp_client_change(ed.lsp, ed.file_path, studio_editor_get_text(ed))
  @end
  return ed
@end

@fn studio_editor_select_all(ed)
  last_line = ed.lines.len() - 1
  @if last_line < 0 last_line = 0 @end
  last_col = str_len(ed.lines[last_line])

  ed.selection = {
    active: true,
    start_line: 0,
    start_col: 0,
    end_line: last_line,
    end_col: last_col
  }
  ed.cursor_line = last_line
  ed.cursor_col = last_col
  ed.preferred_col = last_col
  return ed
@end

@! ----------------------------------------------------------------------------
@! 5. VIEWPORT SCROLLING ENGINE
@! ----------------------------------------------------------------------------

@fn studio_editor_ensure_cursor_visible(ed, view_h, view_w)
  v_lines = view_h / ed.line_height
  @if v_lines <= 0 v_lines = 10 @end

  v_cols = (view_w - ed.gutter_width - 16) / ed.char_width
  @if v_cols <= 0 v_cols = 40 @end

  @! Vertical scrolling boundary clamping
  @if ed.cursor_line < ed.scroll_top_line
    ed.scroll_top_line = ed.cursor_line
  @elif ed.cursor_line >= ed.scroll_top_line + v_lines
    ed.scroll_top_line = ed.cursor_line - v_lines + 1
  @end

  @! Horizontal scrolling boundary clamping
  @if ed.cursor_col < ed.scroll_left_col
    ed.scroll_left_col = ed.cursor_col
  @elif ed.cursor_col >= ed.scroll_left_col + v_cols
    ed.scroll_left_col = ed.cursor_col - v_cols + 1
  @end

  @if ed.scroll_top_line < 0 ed.scroll_top_line = 0 @end
  @if ed.scroll_left_col < 0 ed.scroll_left_col = 0 @end

  return ed
@end

@! ----------------------------------------------------------------------------
@! 6. EDITING MUTATIONS & TYPING
@! ----------------------------------------------------------------------------

@fn studio_editor_insert_text(ed, text)
  @if ed.selection.active == true
    ed = studio_editor_delete_selection(ed)
  @end

  @if str_len(text) == 0 return ed @end

  @! If multiline text
  @if str_index_of(text, "\n") >= 0
    sub_lines = string_split(text, "\n")
    k = 0
    @while k < sub_lines.len()
      @if k > 0 ed = studio_editor_insert_newline(ed) @end
      ed = studio_editor_insert_text(ed, sub_lines[k])
      k = k + 1
    @end
    return ed
  @end

  cur_l = ed.cursor_line
  cur_c = ed.cursor_col
  @if cur_l >= ed.lines.len() cur_l = ed.lines.len() - 1 @end
  @if cur_l < 0 cur_l = 0 @end

  line_str = ed.lines[cur_l]
  l_len = str_len(line_str)
  @if cur_c > l_len cur_c = l_len @end
  @if cur_c < 0 cur_c = 0 @end

  left = str_substr(line_str, 0, cur_c)
  right = str_substr(line_str, cur_c, l_len)
  ed.lines[cur_l] = left + text + right
  ed.cursor_col = cur_c + str_len(text)
  ed.preferred_col = ed.cursor_col
  ed.is_dirty = true

  @! Synchronize with LSP server
  @if str_len(ed.file_path) > 0
    full_text = studio_editor_get_text(ed)
    ed.lsp = lsp_client_change(ed.lsp, ed.file_path, full_text)
  @end
  return ed
@end

@fn studio_editor_insert_char(ed, ch)
  ed = studio_editor_insert_text(ed, ch)
  @! Trigger LSP autocompletion on trigger characters (@, ., :)
  @if ch == "@" || ch == "." || ch == ":"
    @if str_len(ed.file_path) > 0
      ed.lsp = lsp_client_request_completions(ed.lsp, ed.file_path, ed.cursor_line, ed.cursor_col)
    @end
  @end
  return ed
@end

@fn studio_editor_insert_newline(ed)
  @if ed.selection.active == true
    ed = studio_editor_delete_selection(ed)
  @end

  cur_l = ed.cursor_line
  cur_c = ed.cursor_col
  @if cur_l >= ed.lines.len() cur_l = ed.lines.len() - 1 @end
  @if cur_l < 0 cur_l = 0 @end

  line_str = ed.lines[cur_l]
  l_len = str_len(line_str)
  @if cur_c > l_len cur_c = l_len @end
  @if cur_c < 0 cur_c = 0 @end

  left = str_substr(line_str, 0, cur_c)
  right = str_substr(line_str, cur_c, l_len)

  new_lines = []
  i = 0
  @while i < cur_l
    new_lines = new_lines.push(ed.lines[i])
    i = i + 1
  @end
  new_lines = new_lines.push(left)
  new_lines = new_lines.push(right)
  i = cur_l + 1
  num_items = ed.lines.len()
  @while i < num_items
    new_lines = new_lines.push(ed.lines[i])
    i = i + 1
  @end

  ed.lines = new_lines
  ed.cursor_line = cur_l + 1
  ed.cursor_col = 0
  ed.preferred_col = 0
  ed.is_dirty = true

  @if str_len(ed.file_path) > 0
    full_text = studio_editor_get_text(ed)
    ed.lsp = lsp_client_change(ed.lsp, ed.file_path, full_text)
  @end
  return ed
@end

@fn studio_editor_backspace(ed)
  @if ed.selection.active == true
    return studio_editor_delete_selection(ed)
  @end

  cur_l = ed.cursor_line
  cur_c = ed.cursor_col

  @if cur_c > 0
    line_str = ed.lines[cur_l]
    l_len = str_len(line_str)
    left = str_substr(line_str, 0, cur_c - 1)
    right = str_substr(line_str, cur_c, l_len)
    ed.lines[cur_l] = left + right
    ed.cursor_col = cur_c - 1
    ed.preferred_col = ed.cursor_col
    ed.is_dirty = true
    
    @if str_len(ed.file_path) > 0
      ed.lsp = lsp_client_change(ed.lsp, ed.file_path, studio_editor_get_text(ed))
    @end
    return ed
  @elif cur_l > 0
    @! Merge with previous line
    prev_str = ed.lines[cur_l - 1]
    cur_str = ed.lines[cur_l]
    prev_len = str_len(prev_str)
    merged = prev_str + cur_str

    new_lines = []
    i = 0
    @while i < cur_l - 1
      new_lines = new_lines.push(ed.lines[i])
      i = i + 1
    @end
    new_lines = new_lines.push(merged)
    i = cur_l + 1
    num_items = ed.lines.len()
    @while i < num_items
      new_lines = new_lines.push(ed.lines[i])
      i = i + 1
    @end

    ed.lines = new_lines
    ed.cursor_line = cur_l - 1
    ed.cursor_col = prev_len
    ed.preferred_col = prev_len
    ed.is_dirty = true

    @if str_len(ed.file_path) > 0
      ed.lsp = lsp_client_change(ed.lsp, ed.file_path, studio_editor_get_text(ed))
    @end
    return ed
  @end
  return ed
@end

@fn studio_editor_delete(ed)
  @if ed.selection.active == true
    return studio_editor_delete_selection(ed)
  @end

  cur_l = ed.cursor_line
  cur_c = ed.cursor_col
  line_str = ed.lines[cur_l]
  l_len = str_len(line_str)

  @if cur_c < l_len
    left = str_substr(line_str, 0, cur_c)
    right = str_substr(line_str, cur_c + 1, l_len)
    ed.lines[cur_l] = left + right
    ed.is_dirty = true

    @if str_len(ed.file_path) > 0
      ed.lsp = lsp_client_change(ed.lsp, ed.file_path, studio_editor_get_text(ed))
    @end
    return ed
  @elif cur_l + 1 < ed.lines.len()
    @! Merge next line into current line
    next_str = ed.lines[cur_l + 1]
    merged = line_str + next_str

    new_lines = []
    i = 0
    @while i < cur_l
      new_lines = new_lines.push(ed.lines[i])
      i = i + 1
    @end
    new_lines = new_lines.push(merged)
    i = cur_l + 2
    num_items = ed.lines.len()
    @while i < num_items
      new_lines = new_lines.push(ed.lines[i])
      i = i + 1
    @end

    ed.lines = new_lines
    ed.is_dirty = true

    @if str_len(ed.file_path) > 0
      ed.lsp = lsp_client_change(ed.lsp, ed.file_path, studio_editor_get_text(ed))
    @end
    return ed
  @end
  return ed
@end

@! ----------------------------------------------------------------------------
@! 7. CURSOR NAVIGATION & SELECTION
@! ----------------------------------------------------------------------------

@fn studio_editor_move_cursor(ed, dir, select_mode, view_h, view_w)
  old_l = ed.cursor_line
  old_c = ed.cursor_col

  @if select_mode == true
    @if ed.selection.active == false
      ed.selection.active = true
      ed.selection.start_line = old_l
      ed.selection.start_col = old_c
    @end
  @else
    ed.selection.active = false
  @end

  cur_l = ed.cursor_line
  cur_c = ed.cursor_col
  pref_c = ed.preferred_col
  num_lines = ed.lines.len()
  cur_len = str_len(ed.lines[cur_l])

  @if dir == "LEFT"
    @if cur_c > 0
      cur_c = cur_c - 1
      pref_c = cur_c
    @elif cur_l > 0
      cur_l = cur_l - 1
      cur_c = str_len(ed.lines[cur_l])
      pref_c = cur_c
    @end
  @elif dir == "RIGHT"
    @if cur_c < cur_len
      cur_c = cur_c + 1
      pref_c = cur_c
    @elif cur_l + 1 < num_lines
      cur_l = cur_l + 1
      cur_c = 0
      pref_c = 0
    @end
  @elif dir == "UP"
    @if cur_l > 0
      cur_l = cur_l - 1
      l_len = str_len(ed.lines[cur_l])
      @if pref_c <= l_len
        cur_c = pref_c
      @else
        cur_c = l_len
      @end
    @else
      cur_c = 0
      pref_c = 0
    @end
  @elif dir == "DOWN"
    @if cur_l + 1 < num_lines
      cur_l = cur_l + 1
      l_len = str_len(ed.lines[cur_l])
      @if pref_c <= l_len
        cur_c = pref_c
      @else
        cur_c = l_len
      @end
    @else
      cur_c = cur_len
      pref_c = cur_c
    @end
  @elif dir == "HOME"
    cur_c = 0
    pref_c = 0
  @elif dir == "END"
    cur_c = cur_len
    pref_c = cur_c
  @elif dir == "PAGE_UP"
    v_lines = view_h / ed.line_height
    @if v_lines <= 0 v_lines = 10 @end
    cur_l = cur_l - v_lines
    @if cur_l < 0 cur_l = 0 @end
    l_len = str_len(ed.lines[cur_l])
    @if pref_c <= l_len cur_c = pref_c @else cur_c = l_len @end
  @elif dir == "PAGE_DOWN"
    v_lines = view_h / ed.line_height
    @if v_lines <= 0 v_lines = 10 @end
    cur_l = cur_l + v_lines
    @if cur_l >= num_lines cur_l = num_lines - 1 @end
    l_len = str_len(ed.lines[cur_l])
    @if pref_c <= l_len cur_c = pref_c @else cur_c = l_len @end
  @end

  ed.cursor_line = cur_l
  ed.cursor_col = cur_c
  ed.preferred_col = pref_c

  @if select_mode == true
    ed.selection.end_line = cur_l
    ed.selection.end_col = cur_c
  @end

  ed = studio_editor_ensure_cursor_visible(ed, view_h, view_w)
  return ed
@end

@! ----------------------------------------------------------------------------
@! 8. AUTOCOMPLETE ACCEPTANCE & EVENT DISPATCH
@! ----------------------------------------------------------------------------

@fn studio_editor_accept_completion(ed)
  @if ed.lsp.completion_active == true
    lbl = lsp_client_get_selected_label(ed.lsp)
    ed.lsp = lsp_client_dismiss_popups(ed.lsp)
    @if str_len(lbl) > 0
      ed = studio_editor_insert_text(ed, lbl)
    @end
  @end
  return ed
@end

@fn studio_editor_handle_key(ed, key_code, key_char, modifiers)
  shift_down = modifiers & 1 != 0
  ctrl_down = modifiers & 2 != 0

  @! 1. Handle Active Autocomplete Popup Navigation
  @if ed.lsp.completion_active == true
    @if key_code == 27 @! Escape
      ed.lsp = lsp_client_dismiss_popups(ed.lsp)
      return ed
    @elif key_code == 38 @! Up
      ed.lsp = lsp_client_prev_completion(ed.lsp)
      return ed
    @elif key_code == 40 @! Down
      ed.lsp = lsp_client_next_completion(ed.lsp)
      return ed
    @elif key_code == 9 || key_code == 13 || key_code == 10 @! Tab or Enter
      return studio_editor_accept_completion(ed)
    @end
  @end

  @! 2. Shortcuts
  @! Ctrl + Space: Trigger Autocomplete
  @if ctrl_down == true && key_code == 32
    @if str_len(ed.file_path) > 0
      ed.lsp = lsp_client_request_completions(ed.lsp, ed.file_path, ed.cursor_line, ed.cursor_col)
    @end
    return ed
  @end

  @! Ctrl + A: Select All
  @if ctrl_down == true && (key_code == 65 || key_code == 97 || key_char == "a" || key_char == "A")
    return studio_editor_select_all(ed)
  @end

  @! Escape: Dismiss Popups
  @if key_code == 27
    ed.lsp = lsp_client_dismiss_popups(ed.lsp)
    return ed
  @end

  @! 3. Standard Editor Keys
  @if key_code == 8 @! Backspace
    return studio_editor_backspace(ed)
  @elif key_code == 9 @! Tab
    return studio_editor_insert_text(ed, "  ")
  @elif key_code == 13 || key_code == 10 @! Enter
    return studio_editor_insert_newline(ed)
  @elif key_code == 46 || key_code == 127 @! Delete
    return studio_editor_delete(ed)
  @elif key_code == 37 @! Left
    return studio_editor_move_cursor(ed, "LEFT", shift_down, 400, 600)
  @elif key_code == 38 @! Up
    return studio_editor_move_cursor(ed, "UP", shift_down, 400, 600)
  @elif key_code == 39 @! Right
    return studio_editor_move_cursor(ed, "RIGHT", shift_down, 400, 600)
  @elif key_code == 40 @! Down
    return studio_editor_move_cursor(ed, "DOWN", shift_down, 400, 600)
  @elif key_code == 36 @! Home
    return studio_editor_move_cursor(ed, "HOME", shift_down, 400, 600)
  @elif key_code == 35 @! End
    return studio_editor_move_cursor(ed, "END", shift_down, 400, 600)
  @elif key_code == 33 @! Page Up
    return studio_editor_move_cursor(ed, "PAGE_UP", shift_down, 400, 600)
  @elif key_code == 34 @! Page Down
    return studio_editor_move_cursor(ed, "PAGE_DOWN", shift_down, 400, 600)
  @end

  @! 4. Printable Characters
  @if key_char != "" && key_char != none
    return studio_editor_insert_char(ed, key_char)
  @end

  return ed
@end

@fn studio_editor_handle_mouse_click(ed, click_x, click_y, view_x, view_y)
  ed.lsp = lsp_client_dismiss_popups(ed.lsp)

  rel_x = click_x - view_x - ed.gutter_width - 4
  rel_y = click_y - view_y

  target_line = ed.scroll_top_line + (rel_y / ed.line_height)
  @if target_line >= ed.lines.len() target_line = ed.lines.len() - 1 @end
  @if target_line < 0 target_line = 0 @end

  target_col = ed.scroll_left_col + (rel_x / ed.char_width)
  l_len = str_len(ed.lines[target_line])
  @if target_col > l_len target_col = l_len @end
  @if target_col < 0 target_col = 0 @end

  ed.cursor_line = target_line
  ed.cursor_col = target_col
  ed.preferred_col = target_col
  ed.selection = editor_selection_new()
  return ed
@end

@! ----------------------------------------------------------------------------
@! 9. CANVAS RASTERIZATION RENDERING PASS
@! ----------------------------------------------------------------------------

@fn studio_editor_render(ed, canvas, font, x, y, w, h)
  @if w <= 0 || h <= 0 return canvas @end

  gutter_w = ed.gutter_width
  line_h = ed.line_height
  char_w = ed.char_width
  thm = ed.theme

  @! 1. Editor Background
  canvas = canvas_fill_rect(canvas, x, y, w, h, thm.bg_editor)

  @! 2. Line Number Gutter
  canvas = canvas_fill_rect(canvas, x, y, gutter_w, h, thm.bg_gutter)
  canvas = canvas_draw_line(canvas, x + gutter_w, y, x + gutter_w, y + h, 0xFF3E3E42)

  @! 3. Text Viewport & Body
  vp_x = x + gutter_w + 4
  vp_y = y
  vp_w = w - gutter_w - 14
  vp_h = h

  v_lines = vp_h / line_h
  total_lines = ed.lines.len()

  canvas = canvas_push_clip(canvas, x, vp_y, w - 10, vp_h)

  @! Active Line Highlight
  cur_screen_y = vp_y + ((ed.cursor_line - ed.scroll_top_line) * line_h)
  @if cur_screen_y >= vp_y && cur_screen_y < vp_y + vp_h
    canvas = canvas_fill_rect(canvas, x + gutter_w + 1, cur_screen_y, w - gutter_w - 11, line_h, thm.active_line)
  @end

  sel = editor_normalize_selection(ed.selection)

  l_idx = 0
  @while l_idx < v_lines
    file_l = ed.scroll_top_line + l_idx
    @if file_l < total_lines
      draw_y = vp_y + (l_idx * line_h)

      @! Gutter line number
      num_str = (file_l + 1).to_str()
      num_len = str_len(num_str)
      pad_chars = 4 - num_len
      @if pad_chars < 0 pad_chars = 0 @end
      gutter_text = string_repeat(" ", pad_chars) + num_str
      gutter_col = 0xFF858585
      @if file_l == ed.cursor_line gutter_col = 0xFFC6C6C6 @end
      canvas = font_draw_text(canvas, font, x + 6, draw_y, gutter_text, gutter_col)

      line_content = ed.lines[file_l]
      line_len = str_len(line_content)

      @! Selection band for this line
      @if sel.active == true && file_l >= sel.start_line && file_l <= sel.end_line
        sel_s_col = 0
        sel_e_col = line_len
        @if file_l == sel.start_line sel_s_col = sel.start_col @end
        @if file_l == sel.end_line sel_e_col = sel.end_col @end
        @if sel_e_col > sel_s_col
          sel_x = vp_x + ((sel_s_col - ed.scroll_left_col) * char_w)
          sel_w = (sel_e_col - sel_s_col) * char_w
          canvas = canvas_fill_rect(canvas, sel_x, draw_y, sel_w, line_h, thm.selection)
        @end
      @end

      @! Syntax Tokenized Highlighting
      spans = syntax_tokenize_line(line_content, thm)
      @if spans.len() > 0
        sp_i = 0
        @while sp_i < spans.len()
          sp = spans[sp_i]
          @if sp.end_col > ed.scroll_left_col
            sp_s = sp.start_col
            @if sp_s < ed.scroll_left_col sp_s = ed.scroll_left_col @end
            sp_e = sp.end_col
            @if sp_e > line_len sp_e = line_len @end
            
            @if sp_e > sp_s
              span_txt = str_substr(line_content, sp_s, sp_e)
              span_x = vp_x + ((sp_s - ed.scroll_left_col) * char_w)
              canvas = font_draw_text(canvas, font, span_x, draw_y, span_txt, sp.color)
            @end
          @end
          sp_i = sp_i + 1
        @end
      @else
        @! Plain text fallback
        @if ed.scroll_left_col < line_len
          visible_sub = str_substr(line_content, ed.scroll_left_col, line_len)
          canvas = font_draw_text(canvas, font, vp_x, draw_y, visible_sub, 0xFFD4D4D4)
        @end
      @end

      @! LSP Error Diagnostic Underlines
      d_i = 0
      n_diags = ed.lsp.diagnostics.len()
      @while d_i < n_diags
        diag = ed.lsp.diagnostics[d_i]
        @if diag.range.start_pos.line == file_l
          d_sc = diag.range.start_pos.character
          d_ec = diag.range.end_pos.character
          @if d_ec <= d_sc d_ec = d_sc + 1 @end
          err_x = vp_x + ((d_sc - ed.scroll_left_col) * char_w)
          err_w = (d_ec - d_sc) * char_w
          canvas = popup_render_diagnostics_wave(canvas, err_x, draw_y + line_h - 2, err_w, 0xFFF44747)
        @end
        d_i = d_i + 1
      @end

      @! Cursor Rendering
      @if file_l == ed.cursor_line
        c_x = vp_x + ((ed.cursor_col - ed.scroll_left_col) * char_w)
        canvas = canvas_fill_rect(canvas, c_x, draw_y, 2, line_h - 2, thm.cursor)
      @end
    @end
    l_idx = l_idx + 1
  @end

  canvas = canvas_pop_clip(canvas)

  @! 4. Vertical Scrollbar
  sb_w = 8
  sb_x = x + w - sb_w - 1
  canvas = canvas_fill_rect(canvas, sb_x, y, sb_w, h, 0xFF2D2D30)
  @if total_lines > v_lines && total_lines > 0
    thumb_h = (h * v_lines) / total_lines
    @if thumb_h < 16 thumb_h = 16 @end
    thumb_y_rel = (ed.scroll_top_line * (h - thumb_h)) / (total_lines - v_lines)
    canvas = canvas_fill_rect(canvas, sb_x + 1, y + thumb_y_rel, sb_w - 2, thumb_h, 0xFF686868)
  @end

  @! 5. Overlays (Autocomplete dropdown & Hover cards)
  @if ed.lsp.completion_active == true
    cur_screen_x = vp_x + ((ed.cursor_col - ed.scroll_left_col) * char_w)
    cur_screen_y = vp_y + ((ed.cursor_line - ed.scroll_top_line) * line_h)
    canvas = popup_render_completions(ed.lsp, canvas, font, cur_screen_x, cur_screen_y, 260, 200)
  @end

  @if ed.lsp.hover_active == true
    hov_screen_x = vp_x + ((ed.lsp.hover_col - ed.scroll_left_col) * char_w)
    hov_screen_y = vp_y + ((ed.lsp.hover_line - ed.scroll_top_line) * line_h)
    canvas = popup_render_hover(ed.lsp, canvas, font, hov_screen_x, hov_screen_y, 340, 200)
  @end

  return canvas
@end
