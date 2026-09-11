@! ============================================================================
@! MAYA SOVEREIGN IDE — END-TO-END MASTER APPLICATION COMPREHENSIVE TEST SUITE
@! File: tests/ide/test_studio_e2e.maya
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/gui/canvas"
import "universe/gui/font"
import "universe/gui/event"
import "universe/ide/syntax"
import "universe/ide/lsp_client"
import "universe/ide/ui_popup"
import "universe/ide/console"
import "universe/ide/runner"
import "universe/ide/toolbar"
import "universe/ide/editor"
import "universe/ide/studio"

@fn assert_true(cond, msg)
  @if cond == 0
    println("  [FAIL] Assertion failed (expected true): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_false(cond, msg)
  @if cond != 0
    println("  [FAIL] Assertion failed (expected false): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("🌟 MAYA STUDIO MASTER APPLICATION E2E COMPREHENSIVE TEST SUITE 🌟")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! SECTION 1: Master Studio Initialization & Structural Geometry
  @! ----------------------------------------------------------------------------
  println("▶ Section 1: Studio App Initialization & Subsystems Setup...")
  total_tests = total_tests + 1

  app = studio_app_create(800, 600, "apps/physics.maya")

  ok1 = assert_eq_int(app.width, 800, "Window width is 800")
  ok2 = assert_eq_int(app.height, 600, "Window height is 600")
  ok3 = assert_eq_str(app.editor.file_path, "apps/physics.maya", "Editor path loaded")
  ok4 = assert_true(app.console.lines.len() >= 2, "Welcome and LSP banner messages initialized")
  ok5 = assert_true(app.toolbar.buttons.len() >= 6, "Toolbar initialized with 6 action buttons")
  ok6 = assert_true(app.editor.lsp.server.is_initialized, "LSP server active in Studio")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Master Studio initialization & subsystems verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 2: Interactive Typing & Dynamic Buffer Evolution
  @! ----------------------------------------------------------------------------
  println("▶ Section 2: Interactive Event Dispatch Typing...")
  total_tests = total_tests + 1

  @! Type "@fn simulate()\n  let dt = 0.016\n@end"
  code = "@fn simulate()\n  let dt = 0.016\n@end"
  app.editor = studio_editor_set_text(app.editor, code)

  ok1 = assert_eq_int(studio_editor_get_line_count(app.editor), 3, "Buffer loaded with 3 lines")
  ok2 = assert_eq_str(app.editor.lines[0], "@fn simulate()", "Line 0 matches function header")
  ok3 = assert_eq_str(app.editor.lines[1], "  let dt = 0.016", "Line 1 matches variable binding")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Interactive buffer editing verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 3: Autocompletion Trigger & Acceptance
  @! ----------------------------------------------------------------------------
  println("▶ Section 3: In-Studio Autocompletion Trigger & Acceptance...")
  total_tests = total_tests + 1

  @! Dispatch Ctrl+Space key event (key_code 32, modifiers 2)
  ev_comp = {
    kind: 3, @! KEY_DOWN
    x: 0,
    y: 0,
    button: 0,
    wheel_delta: 0,
    key_code: 32,
    key_char: " ",
    modifiers: 2, @! Ctrl
    target_id: "editor",
    handled: false
  }

  app = studio_app_dispatch_event(app, ev_comp)
  ok1 = assert_true(app.editor.lsp.completion_active, "Autocomplete overlay popup opened via Ctrl+Space")
  ok2 = assert_true(app.editor.lsp.completion_items.len() > 0, "Completions list populated")

  @! Accept first completion via Tab (key_code 9)
  ev_tab = {
    kind: 3,
    x: 0,
    y: 0,
    button: 0,
    wheel_delta: 0,
    key_code: 9,
    key_char: "\t",
    modifiers: 0,
    target_id: "editor",
    handled: false
  }
  app = studio_app_dispatch_event(app, ev_tab)
  ok3 = assert_false(app.editor.lsp.completion_active, "Autocomplete overlay dismissed after acceptance")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Autocompletion trigger, navigation & acceptance verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 4: Toolbar Action Button Clicks
  @! ----------------------------------------------------------------------------
  println("▶ Section 4: Toolbar Mouse Click Action Dispatch...")
  total_tests = total_tests + 1

  @! Click [Run] button (first button in toolbar, around x=20, y=35)
  ev_click_run = {
    kind: 1, @! MOUSE_DOWN
    x: 20,
    y: 35,
    button: 1,
    wheel_delta: 0,
    key_code: 0,
    key_char: "",
    modifiers: 0,
    target_id: "toolbar",
    handled: false
  }
  app = studio_app_dispatch_event(app, ev_click_run)
  ok1 = assert_eq_str(app.console.active_tab, "OUTPUT", "Switched console tab to OUTPUT")
  ok2 = assert_true(console_get_line_count(app.console) > 2, "Execution logged stdout into console")

  @! Click [Build] button
  btn_build_x = app.toolbar.buttons[1].x + 10
  ev_click_build = {
    kind: 1,
    x: btn_build_x,
    y: 35,
    button: 1,
    wheel_delta: 0,
    key_code: 0,
    key_char: "",
    modifiers: 0,
    target_id: "toolbar",
    handled: false
  }
  app = studio_app_dispatch_event(app, ev_click_build)
  ok3 = assert_eq_str(app.console.active_tab, "BUILD", "Switched console tab to BUILD")
  build_lines = console_get_lines_for_tab(app.console, "BUILD")
  ok4 = assert_true(build_lines.len() >= 3, "Build stages logged into BUILD tab")

  @! Click [Save] button (around x=300, y=35)
  btn_save_x = app.toolbar.buttons[4].x + 10
  ev_click_save = {
    kind: 1,
    x: btn_save_x,
    y: 35,
    button: 1,
    wheel_delta: 0,
    key_code: 0,
    key_char: "",
    modifiers: 0,
    target_id: "toolbar",
    handled: false
  }
  app = studio_app_dispatch_event(app, ev_click_save)
  ok5 = assert_false(app.editor.is_dirty, "Editor buffer marked clean after save")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Toolbar action triggers verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 5: Keyboard Shortcuts (F5, Ctrl+B, Ctrl+S)
  @! ----------------------------------------------------------------------------
  println("▶ Section 5: Global IDE Keyboard Shortcuts...")
  total_tests = total_tests + 1

  @! F5 (Run)
  ev_f5 = {
    kind: 3,
    x: 0,
    y: 0,
    button: 0,
    wheel_delta: 0,
    key_code: 116, @! F5
    key_char: "",
    modifiers: 0,
    target_id: "window",
    handled: false
  }
  app = studio_app_dispatch_event(app, ev_f5)
  ok1 = assert_eq_str(app.console.active_tab, "OUTPUT", "F5 triggered run action")

  @! Ctrl+B (Build)
  ev_ctrl_b = {
    kind: 3,
    x: 0,
    y: 0,
    button: 0,
    wheel_delta: 0,
    key_code: 66, @! 'B'
    key_char: "b",
    modifiers: 2, @! Ctrl
    target_id: "window",
    handled: false
  }
  app = studio_app_dispatch_event(app, ev_ctrl_b)
  ok2 = assert_eq_str(app.console.active_tab, "BUILD", "Ctrl+B triggered build action")

  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Global keyboard shortcuts verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 6: Full Master Framebuffer Rasterization & Pixel Verification
  @! ----------------------------------------------------------------------------
  println("▶ Section 6: Master Framebuffer Rasterization & Pixel Inspection...")
  total_tests = total_tests + 1

  c = studio_app_render_frame(app)

  @! Title Bar pixel (0xFF007ACC)
  px_title = canvas_get_pixel(c, 10, 10)
  ok1 = assert_eq_int(px_title, 0xFF007ACC, "Window title bar pixel (0xFF007ACC)")

  @! Close button red pixel (0xFFE81123)
  px_close = canvas_get_pixel(c, 785, 10)
  ok2 = assert_eq_int(px_close, 0xFFE81123, "Window close button pixel (0xFFE81123)")

  @! Toolbar background pixel (0xFF2D2D30)
  px_tb = canvas_get_pixel(c, 10, 26)
  ok3 = assert_eq_int(px_tb, 0xFF2D2D30, "Toolbar ribbon pixel (0xFF2D2D30)")

  @! Editor gutter pixel (0xFF252526)
  px_gut = canvas_get_pixel(c, 10, 100)
  ok4 = assert_eq_int(px_gut, 0xFF252526, "Editor gutter pixel (0xFF252526)")

  @! Editor active line highlight (0xFF282828)
  px_act = canvas_get_pixel(c, 200, 62)
  ok5 = assert_eq_int(px_act, 0xFF282828, "Editor active line highlight (0xFF282828)")

  @! Console header pixel (0xFF252526)
  px_con_hdr = canvas_get_pixel(c, 10, 422)
  ok6 = assert_eq_int(px_con_hdr, 0xFF252526, "Console header pixel (0xFF252526)")

  @! Console body background pixel (0xFF181818)
  px_con_body = canvas_get_pixel(c, 600, 500)
  ok7 = assert_eq_int(px_con_body, 0xFF181818, "Console body pixel (0xFF181818)")

  @! Status bar footer pixel (0xFF007ACC)
  px_status = canvas_get_pixel(c, 10, 590)
  ok8 = assert_eq_int(px_status, 0xFF007ACC, "Status bar footer pixel (0xFF007ACC)")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Full Master IDE frame rasterization & pixel coordinates verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SUMMARY REPORT
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  println("📊 MAYA STUDIO E2E TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL " + total_tests.to_str() + " MAYA STUDIO E2E TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME MAYA STUDIO E2E TESTS FAILED")
    return 1
  @end
@end
