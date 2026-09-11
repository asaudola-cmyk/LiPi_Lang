@! ============================================================================
@! ADVERSARIAL STRESS TEST SUITE: MAYA STUDIO SOVEREIGN GRAPHICAL IDE
@! File: tests/adversarial/test_adv_toolchain_studio_stress.maya
@! Focus: Text buffer boundaries, preferred column persistence, selection range
@!        normalization, hostile token syntax highlighting, and console buffer overflow
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/gui/canvas"
import "universe/gui/event"
import "universe/ide/syntax"
import "universe/ide/editor"
import "universe/ide/console"
import "universe/ide/runner"
import "universe/ide/lsp_client"
import "universe/ide/studio"

@struct AdvStudioTestContext
  total: i64
  passed: i64
  failed: i64
@end

@fn assert_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got " + actual.to_str())
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
@end

@fn assert_str_eq(ctx, name, actual, expected)
  ctx.total = ctx.total + 1
  @if actual == expected
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name + " -> got \"" + actual + "\"")
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    return 0
  @end
@end

@fn assert_true(ctx, name, cond)
  ctx.total = ctx.total + 1
  @if cond != 0
    ctx.passed = ctx.passed + 1
    println("  [PASS] " + name)
    return 1
  @else
    ctx.failed = ctx.failed + 1
    println("  [FAIL] " + name + " -> condition was false")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("🔥 [ADVERSARIAL SUITE 3] STUDIO IDE BUFFER, CURSOR, SYNTAX & CONSOLE")
  println("=================================================================")

  ctx = { total: 0, passed: 0, failed: 0 }
  theme = syntax_theme_default()

  @! --------------------------------------------------------------------------
  @! SECTION 1: Text Buffer Boundaries & Empty State Navigation
  @! --------------------------------------------------------------------------
  println("\n▶ Section 1: Empty Buffer Boundaries & Degenerate Mutations")

  ed_empty = studio_editor_new("", "", theme)
  assert_eq(ctx, "ADV-ED-01: Empty editor has 1 empty line", studio_editor_get_line_count(ed_empty), 1)
  assert_eq(ctx, "ADV-ED-02: Initial cursor line is 0", ed_empty.cursor_line, 0)
  assert_eq(ctx, "ADV-ED-03: Initial cursor col is 0", ed_empty.cursor_col, 0)

  @! Backspace at (0, 0) on empty buffer must not crash or produce negative index
  ed_empty = studio_editor_backspace(ed_empty)
  assert_eq(ctx, "ADV-ED-04: Backspace at (0,0) safe", ed_empty.cursor_col, 0)
  assert_eq(ctx, "ADV-ED-05: Line count remains 1 after backspace at (0,0)", studio_editor_get_line_count(ed_empty), 1)

  @! Delete at (0, 0) on empty buffer
  ed_empty = studio_editor_delete(ed_empty)
  assert_eq(ctx, "ADV-ED-06: Delete at (0,0) safe", ed_empty.cursor_col, 0)

  @! Navigation at boundaries
  ed_empty = studio_editor_move_cursor(ed_empty, "UP", false, 600, 800)
  assert_eq(ctx, "ADV-ED-07: Move UP at (0,0) stays at 0", ed_empty.cursor_line, 0)

  ed_empty = studio_editor_move_cursor(ed_empty, "LEFT", false, 600, 800)
  assert_eq(ctx, "ADV-ED-08: Move LEFT at (0,0) stays at 0", ed_empty.cursor_col, 0)

  ed_empty = studio_editor_move_cursor(ed_empty, "DOWN", false, 600, 800)
  assert_eq(ctx, "ADV-ED-09: Move DOWN on single line stays at 0", ed_empty.cursor_line, 0)

  ed_empty = studio_editor_move_cursor(ed_empty, "RIGHT", false, 600, 800)
  assert_eq(ctx, "ADV-ED-10: Move RIGHT at EOL stays at 0", ed_empty.cursor_col, 0)

  @! --------------------------------------------------------------------------
  @! SECTION 2: Preferred Column Memory Across Short and Long Lines
  @! --------------------------------------------------------------------------
  println("\n▶ Section 2: Preferred Column Memory Across Heterogeneous Lines")

  sample_code = "This is a very long line of code with many characters\nShort\nAnother fairly long line of code for testing"
  ed = studio_editor_new("test.maya", sample_code, theme)
  assert_eq(ctx, "ADV-ED-11: 3 lines loaded in editor", studio_editor_get_line_count(ed), 3)

  @! Place cursor at col 30 on line 0
  ed.cursor_line = 0
  ed.cursor_col = 30
  ed.preferred_col = 30

  @! Move DOWN to line 1 (len = 5, "Short")
  ed = studio_editor_move_cursor(ed, "DOWN", false, 600, 800)
  assert_eq(ctx, "ADV-ED-12: Cursor moved to line 1", ed.cursor_line, 1)
  assert_eq(ctx, "ADV-ED-13: Cursor col clamped to 5 on short line", ed.cursor_col, 5)
  assert_eq(ctx, "ADV-ED-14: Preferred col persists as 30", ed.preferred_col, 30)

  @! Move DOWN to line 2 (len = 44, "Another fairly long...")
  ed = studio_editor_move_cursor(ed, "DOWN", false, 600, 800)
  assert_eq(ctx, "ADV-ED-15: Cursor moved to line 2", ed.cursor_line, 2)
  assert_eq(ctx, "ADV-ED-16: Cursor col restored to preferred col 30", ed.cursor_col, 30)

  @! Move UP back to line 1
  ed = studio_editor_move_cursor(ed, "UP", false, 600, 800)
  assert_eq(ctx, "ADV-ED-17: Cursor moved UP to line 1", ed.cursor_line, 1)
  assert_eq(ctx, "ADV-ED-18: Cursor col clamped again to 5", ed.cursor_col, 5)
  assert_eq(ctx, "ADV-ED-19: Preferred col still persists as 30", ed.preferred_col, 30)

  @! Move UP back to line 0
  ed = studio_editor_move_cursor(ed, "UP", false, 600, 800)
  assert_eq(ctx, "ADV-ED-20: Cursor moved UP to line 0", ed.cursor_line, 0)
  assert_eq(ctx, "ADV-ED-21: Cursor col restored to preferred col 30", ed.cursor_col, 30)

  @! --------------------------------------------------------------------------
  @! SECTION 3: Selection Range Normalization & Batch Replacements
  @! --------------------------------------------------------------------------
  println("\n▶ Section 3: Selection Normalization & Batch Operations")

  @! Backward selection (start line 2 col 10, end line 0 col 5)
  back_sel = {
    active: true,
    start_line: 2,
    start_col: 10,
    end_line: 0,
    end_col: 5
  }
  norm_sel = editor_normalize_selection(back_sel)
  assert_eq(ctx, "ADV-SEL-01: Normalized start_line is 0", norm_sel.start_line, 0)
  assert_eq(ctx, "ADV-SEL-02: Normalized start_col is 5", norm_sel.start_col, 5)
  assert_eq(ctx, "ADV-SEL-03: Normalized end_line is 2", norm_sel.end_line, 2)
  assert_eq(ctx, "ADV-SEL-04: Normalized end_col is 10", norm_sel.end_col, 10)

  @! Select all and replace
  ed = studio_editor_select_all(ed)
  assert_true(ctx, "ADV-SEL-05: Select all activated selection", ed.selection.active)
  ed = studio_editor_insert_text(ed, "@fn add(a, b)\n  return a + b\n@end")
  assert_eq(ctx, "ADV-SEL-06: Editor replaced with new 3-line function", studio_editor_get_line_count(ed), 3)
  assert_eq(ctx, "ADV-SEL-07: Selection cleared after insertion", ed.selection.active, false)

  @! --------------------------------------------------------------------------
  @! SECTION 4: Syntax Highlighting on Hostile Tokens & Themes
  @! --------------------------------------------------------------------------
  println("\n▶ Section 4: Syntax Highlighting on Hostile Tokens")

  @! Line with directive, keyword, hex number, and comment
  line_complex = "@fn compute_hash(seed: i64) -> i64 @! 0xDEADBEEF hash"
  spans = syntax_tokenize_line(line_complex, theme)
  assert_true(ctx, "ADV-SYN-01: Tokenizer generated syntax spans", spans.len() > 0)

  @! Check first span is directive (@fn)
  s0 = spans[0]
  assert_eq(ctx, "ADV-SYN-02: First span is directive color", s0.color, theme.col_directive)
  assert_str_eq(ctx, "ADV-SYN-03: First span token type is DIRECTIVE", s0.token_type, "DIRECTIVE")

  @! Unterminated string literal handling
  line_unterminated = "msg = \"unterminated string literal"
  spans_unterm = syntax_tokenize_line(line_unterminated, theme)
  assert_true(ctx, "ADV-SYN-04: Unterminated string parsed into spans without crashing", spans_unterm.len() > 0)

  @! Light theme color distinctness
  theme_l = syntax_theme_light()
  assert_true(ctx, "ADV-SYN-05: Light theme background is white (0xFFFFFFFF)", theme_l.bg_editor == 0xFFFFFFFF)
  assert_true(ctx, "ADV-SYN-06: Light theme directive color is non-zero", theme_l.col_directive != 0)
  assert_true(ctx, "ADV-SYN-07: Light theme comment color is distinct", theme_l.col_comment != theme_l.col_directive)

  @! --------------------------------------------------------------------------
  @! SECTION 5: Console Stream Buffering & Overflow Trimming
  @! --------------------------------------------------------------------------
  println("\n▶ Section 5: Console Stream Buffering & Trimming Stress")

  con = console_new(160)
  con.max_lines = 50

  @! Append 150 lines (exceeding max_lines of 50)
  c_idx = 1
  @while c_idx <= 150
    console_append(con, "Log line #" + c_idx.to_str(), "STDOUT")
    c_idx = c_idx + 1
  @end

  assert_eq(ctx, "ADV-CON-01: Console lines trimmed to exact max_lines capacity (50)", con.lines.len(), 50)
  assert_eq(ctx, "ADV-CON-02: Console line count helper matches 50", console_get_line_count(con), 50)

  @! Switch tabs
  con = console_set_tab(con, "DIAGNOSTICS")
  assert_str_eq(ctx, "ADV-CON-03: Active tab switched to DIAGNOSTICS", con.active_tab, "DIAGNOSTICS")

  @! Clear console
  con = console_clear(con)
  assert_eq(ctx, "ADV-CON-04: Console cleared to 0 lines", con.lines.len(), 0)

  @! --------------------------------------------------------------------------
  @! SECTION 6: Master Studio Event Loop & Frame Rasterization
  @! --------------------------------------------------------------------------
  println("\n▶ Section 6: Master Studio Event Loop & Rasterization")

  app = studio_app_create(800, 600, "demo.maya")
  assert_eq(ctx, "ADV-APP-01: Studio width is 800", app.width, 800)
  assert_eq(ctx, "ADV-APP-02: Studio height is 600", app.height, 600)
  assert_true(ctx, "ADV-APP-03: Studio is running", app.is_running)

  @! Rasterize master Framebuffer
  canvas_fb = studio_app_render_frame(app)
  px_title = canvas_get_pixel(canvas_fb, 10, 10)
  assert_eq(ctx, "ADV-APP-04: Window title bar pixel rasterized (0xFF007ACC)", px_title, 0xFF007ACC)

  px_status = canvas_get_pixel(canvas_fb, 10, 590)
  assert_eq(ctx, "ADV-APP-05: Status bar footer pixel rasterized (0xFF007ACC)", px_status, 0xFF007ACC)

  println("=================================================================")
  println("📊 ADVERSARIAL STUDIO IDE SUITE SUMMARY")
  println("=================================================================")
  println("Total Assertions: " + ctx.total.to_str())
  println("Passed          : " + ctx.passed.to_str())
  println("Failed          : " + ctx.failed.to_str())
  println("=================================================================")

  @if ctx.failed == 0
    println("🎉 ALL ADVERSARIAL STUDIO IDE TESTS PASSED! 🎉")
  @else
    println("❌ SOME ADVERSARIAL STUDIO IDE TESTS FAILED!")
  @end
@end
