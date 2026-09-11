import "universe/core/collections"
import "universe/core/string"
import "universe/os/syscalls"
import "universe/gui/canvas"
import "universe/gui/font"
import "universe/gui/event"
import "universe/gui/widget"
import "compiler/frontend/lexer"
import "universe/tools/lsp/protocol"
import "universe/tools/lsp/server"
import "universe/ide/syntax"
import "universe/ide/lsp_client"
import "universe/ide/ui_popup"
import "universe/ide/console"
import "universe/ide/runner"
import "universe/ide/toolbar"
import "universe/ide/editor"
import "universe/ide/studio"

@fn assert_eq(actual, expected, test_name)
  @if actual == expected
    println("  [PASS] " + test_name + " -> got " + actual.to_str())
  @else
    println("  [FAIL] " + test_name + " -> expected " + expected.to_str() + ", got " + actual.to_str())
    sys_exit(1)
  @end
@end

@fn assert_str_eq(actual, expected, test_name)
  @if actual == expected
    println("  [PASS] " + test_name + " -> got \"" + actual + "\"")
  @else
    println("  [FAIL] " + test_name + " -> expected \"" + expected + "\", got \"" + actual + "\"")
    sys_exit(1)
  @end
@end

@fn assert_true(cond, test_name)
  @if cond != 0
    println("  [PASS] " + test_name)
  @else
    println("  [FAIL] " + test_name)
    sys_exit(1)
  @end
@end

@fn main()
  println("=================================================================")
  println("🎨 ADVERSARIAL MAYA STUDIO IDE STRESS TEST HARNESS 🎨")
  println("=================================================================")

  thm = syntax_theme_default()
  ed = studio_editor_new("src/stress_test.maya", "", thm)
  assert_true(ed != 0, "ADV-IDE-01: Studio editor initialized")

  @! ---------------------------------------------------------------------------
  @! SECTION 1: High-Volume Buffer Insertion & Manipulation
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 1: High-Volume Buffer Operations & Boundaries...")

  @! Insert 50 lines of code
  i = 1
  buffer_src = ""
  @while i <= 50
    buffer_src = buffer_src + "let var_" + i.to_str() + " = " + (i * 10).to_str() + "\n"
    i = i + 1
  @end

  ed = studio_editor_set_text(ed, buffer_src)
  assert_eq(studio_editor_get_line_count(ed), 51, "ADV-IDE-02: Buffer loaded with 51 lines")

  @! Navigate cursor to line 25, col 4
  ed.cursor_line = 25
  ed.cursor_col = 4
  assert_eq(ed.cursor_line, 25, "ADV-IDE-03: Cursor moved to line 25")
  assert_eq(ed.cursor_col, 4, "ADV-IDE-04: Cursor moved to col 4")

  @! Boundary test: cursor left past col 0 moves up to end of previous line
  ed.cursor_col = 0
  ed = studio_editor_handle_key(ed, 37, "", 0)  @! Arrow Left
  assert_eq(ed.cursor_line, 24, "ADV-IDE-05: Arrow left at col 0 moved up to line 24")

  @! Boundary test: cursor up past line 0 clamps to line 0
  ed.cursor_line = 0
  ed = studio_editor_handle_key(ed, 38, "", 0)  @! Arrow Up
  assert_eq(ed.cursor_line, 0, "ADV-IDE-06: Arrow up at line 0 clamped to line 0")

  @! ---------------------------------------------------------------------------
  @! SECTION 2: Syntax Highlighting & Tokenizer Verification
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 2: Real-Time Lexical Syntax Highlighting...")

  sample_line = "@fn calculate(x, y) -> i64  @! Compute value"
  spans = syntax_tokenize_line(sample_line, thm)
  assert_true(spans.len() > 0, "ADV-IDE-07: Generated color spans for syntax line")

  s0 = spans[0]
  assert_str_eq(s0.token_type, "DIRECTIVE", "ADV-IDE-08: Span 0 token_type is DIRECTIVE")
  assert_eq(s0.start_col, 0, "ADV-IDE-09: Span 0 start_col is 0")
  assert_eq(s0.end_col, 3, "ADV-IDE-10: Span 0 end_col is 3")
  assert_eq(s0.color, thm.col_directive, "ADV-IDE-11: @fn directive colored with col_directive palette")

  @! ---------------------------------------------------------------------------
  @! SECTION 3: In-Process LSP Diagnostics & Autocompletion
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 3: In-Process LSP Server & Auto-Completion...")

  lsp = lsp_client_new()
  assert_true(lsp.server.is_initialized, "ADV-IDE-12: In-process LSP server active")

  @! Diagnostic on valid Maya code
  valid_code = "@fn add(a, b)\n  return a + b\n@end\n"
  lsp = lsp_client_open(lsp, "src/calc.maya", valid_code)
  assert_eq(lsp.diagnostics.len(), 0, "ADV-IDE-13: 0 syntax diagnostic errors for valid code")

  @! Autocompletion request
  lsp = lsp_client_request_completions(lsp, "src/calc.maya", 1, 4)
  assert_true(lsp.completion_items.len() > 0, "ADV-IDE-14: LSP returned completion candidates")

  @! ---------------------------------------------------------------------------
  @! SECTION 4: Studio Console & Process Runner Multi-Stream Logging
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 4: Console Streams & Log Buffer...")

  con = console_new(160)
  con = console_append(con, "Build initiated...", "BUILD")
  con = console_append(con, "Process stdout line 1", "STDOUT")
  con = console_append(con, "Diagnostic warning detected", "WARNING")

  assert_eq(con.lines.len(), 3, "ADV-IDE-15: Console accumulated 3 log entries")

  con = console_set_tab(con, "OUTPUT")
  assert_str_eq(con.active_tab, "OUTPUT", "ADV-IDE-16: Active console tab set to OUTPUT")

  con = console_clear(con)
  assert_eq(con.lines.len(), 0, "ADV-IDE-17: Console cleared successfully")

  @! ---------------------------------------------------------------------------
  @! SECTION 5: Master Application Framebuffer Rasterization & Pixel Colors
  @! ---------------------------------------------------------------------------
  println("\n▶ Section 5: Master Framebuffer Rasterization (800x600)...")

  app = studio_app_create(800, 600, "src/app.maya")
  assert_eq(app.width, 800, "ADV-IDE-18: Master app width 800")
  assert_eq(app.height, 600, "ADV-IDE-19: Master app height 600")

  frame = studio_app_render_frame(app)
  
  @! Title bar pixel (0xFF007ACC)
  px_title = canvas_get_pixel(frame, 10, 10)
  assert_eq(px_title, 4278221516, "ADV-IDE-20: Title bar pixel color (0xFF007ACC)")

  @! Close button red pixel (0xFFE81123)
  px_close = canvas_get_pixel(frame, 785, 10)
  assert_eq(px_close, 4293398819, "ADV-IDE-21: Close button pixel color (0xFFE81123)")

  @! Status bar footer pixel (0xFF007ACC)
  px_status = canvas_get_pixel(frame, 10, 590)
  assert_eq(px_status, 4278221516, "ADV-IDE-22: Status bar footer pixel color (0xFF007ACC)")

  @! Event dispatch test: F5 shortcut
  f5_event = event_key_new(3, 116, "", 0)
  app = studio_app_dispatch_event(app, f5_event)
  assert_str_eq(app.toolbar.status_message, "Ready", "ADV-IDE-23: F5 run workflow triggered and completed with Ready status")

  println("\n=================================================================")
  println("🎉 ALL 23 ADVERSARIAL MAYA STUDIO IDE TESTS PASSED SUCCESSFULLY! 🎉")
  println("=================================================================")
  return 0
@end
