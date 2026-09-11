@! ============================================================================
@! MAYA SOVEREIGN IDE — CONSOLE & BACKGROUND RUNNER COMPREHENSIVE TEST SUITE
@! File: tests/ide/test_studio_console_runner.maya
@! Milestone: M3 (Maya Studio Sovereign IDE)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/gui/canvas"
import "universe/gui/font"
import "universe/ide/console"
import "universe/ide/runner"

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
  println("🖥️ MAYA STUDIO CONSOLE & PROCESS RUNNER TEST SUITE 🖥️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! SECTION 1: Console Initialization & Default Properties
  @! ----------------------------------------------------------------------------
  println("▶ Section 1: Console Pane Initialization...")
  total_tests = total_tests + 1

  con = console_new(160)
  ok1 = assert_eq_int(console_get_line_count(con), 0, "Initial console lines is 0")
  ok2 = assert_eq_str(con.active_tab, "OUTPUT", "Initial active tab is OUTPUT")
  ok3 = assert_true(con.is_visible, "Console is visible")
  ok4 = assert_eq_int(con.height, 160, "Console height is 160")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Console pane initialization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 2: Multi-Stream Line Buffering & Color Mapping
  @! ----------------------------------------------------------------------------
  println("▶ Section 2: Multi-Stream Line Buffering...")
  total_tests = total_tests + 1

  con = console_append(con, "Standard output message", "STDOUT")
  con = console_append(con, "Error diagnostics alert", "ERROR")
  con = console_append(con, "Build artifact compiled", "BUILD")
  con = console_append(con, "Compilation successful", "SUCCESS")

  ok1 = assert_eq_int(console_get_line_count(con), 4, "4 lines appended across streams")
  
  l0 = con.lines[0]
  l1 = con.lines[1]
  l2 = con.lines[2]
  l3 = con.lines[3]

  ok2 = assert_eq_str(l0.stream_type, "STDOUT", "Line 0 is STDOUT")
  ok3 = assert_eq_int(l0.color, 0xFFCCCCCC, "Line 0 color is standard gray")
  ok4 = assert_eq_str(l1.stream_type, "ERROR", "Line 1 is ERROR")
  ok5 = assert_eq_int(l1.color, 0xFFF44747, "Line 1 color is red")
  ok6 = assert_eq_str(l2.stream_type, "BUILD", "Line 2 is BUILD")
  ok7 = assert_eq_int(l2.color, 0xFFE5C07B, "Line 2 color is gold")
  ok8 = assert_eq_str(l3.stream_type, "SUCCESS", "Line 3 is SUCCESS")
  ok9 = assert_eq_int(l3.color, 0xFF4EC9B0, "Line 3 color is green")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1 && ok8 == 1 && ok9 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Multi-stream line buffering and color mapping verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 3: Tab Filtering & Clear Actions
  @! ----------------------------------------------------------------------------
  println("▶ Section 3: Tab Filtering & Clear Operations...")
  total_tests = total_tests + 1

  all_lines = console_get_lines_for_tab(con, "OUTPUT")
  diag_lines = console_get_lines_for_tab(con, "DIAGNOSTICS")
  build_lines = console_get_lines_for_tab(con, "BUILD")

  ok1 = assert_eq_int(all_lines.len(), 4, "OUTPUT tab contains all 4 lines")
  ok2 = assert_eq_int(diag_lines.len(), 1, "DIAGNOSTICS tab filters 1 error line")
  ok3 = assert_eq_int(build_lines.len(), 2, "BUILD tab filters 2 build/success lines")

  con = console_clear(con)
  ok4 = assert_eq_int(console_get_line_count(con), 0, "Console flushed cleanly on clear")

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Tab filtering and console clear verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 4: Background Process Runner (Execute & Build)
  @! ----------------------------------------------------------------------------
  println("▶ Section 4: Background Process Execution & Output Streaming...")
  total_tests = total_tests + 1

  runner = runner_new()
  ok1 = assert_false(runner.is_running, "Initial runner is not running")

  @! Execute file
  runner = runner_execute_file(runner, "examples/hello.maya", con)
  ok2 = assert_true(console_get_line_count(con) > 0, "Execution streamed output to console")
  ok3 = assert_eq_str(runner.command_kind, "RUN", "Runner command kind is RUN")

  @! Build binary
  runner = runner_build_binary(runner, "examples/hello.maya", "bin/hello.elf", con)
  ok4 = assert_eq_str(runner.command_kind, "BUILD", "Runner command kind is BUILD")
  build_tab_lines = console_get_lines_for_tab(con, "BUILD")
  ok5 = assert_true(build_tab_lines.len() >= 3, "Build pipeline stages logged to BUILD tab")

  @! Terminate
  runner = runner_terminate(runner, con)

  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Process runner execution and streaming verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 5: Visual Console Canvas Rasterization
  @! ----------------------------------------------------------------------------
  println("▶ Section 5: Console Framebuffer Rasterization...")
  total_tests = total_tests + 1

  c = canvas_new(640, 160)
  f = font_default()
  c = console_render(con, c, f, 0, 0, 640, 160)

  @! Inspect header pixel (0xFF252526) and body background pixel (0xFF181818 at x=500, y=50)
  px_hdr = canvas_get_pixel(c, 10, 5)
  px_body = canvas_get_pixel(c, 500, 50)
  ok1 = assert_eq_int(px_hdr, 0xFF252526, "Console header background pixel verified")
  ok2 = assert_eq_int(px_body, 0xFF181818, "Console body background pixel verified")

  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Console canvas rasterization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SUMMARY REPORT
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  println("📊 CONSOLE & RUNNER TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL " + total_tests.to_str() + " CONSOLE & RUNNER TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME CONSOLE & RUNNER TESTS FAILED")
    return 1
  @end
@end
