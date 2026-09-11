@! ============================================================================
@! ADVERSARIAL STRESS SUITE — CHALLENGER 2: ANSI TERMINAL RASTERIZER (F13)
@! Module: tests/adversarial/test_adv_web_f13_ansi_rasterizer.maya
@! Target: universe/web/frontend/renderer/terminal_renderer.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"
import "universe/web/frontend/renderer/canvas2d_renderer"
import "universe/web/frontend/renderer/terminal_renderer"
import "universe/web/frontend/layout/layout_types"

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@fn test_state_new()
  return { total: 0, passed: 0, failed: 0 }
@end

@fn assert_true(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == true || cond == 1
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected true, got false)")
    return 0
  @end
@end

@fn assert_false(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == false || cond == 0
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected false, got true)")
    return 0
  @end
@end

@fn assert_eq_int(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected " + int_to_str(expected) + ", got " + int_to_str(actual) + ")")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("⚔️  ADVERSARIAL CHALLENGER 2: Feature F13 (ANSI Rasterizer) ⚔️")
  println("=================================================================")

  state = test_state_new()

  @! --------------------------------------------------------------------------
  @! SECTION 1: TrueColor 24-bit Escape Code Formatting & Reset Invariants
  @! --------------------------------------------------------------------------
  println("\n--- Section 1: TrueColor 24-bit Escape Formatting ---")

  @! Test 1.1: FG escape formatting
  fg_code = ansi_escape_fg(255, 128, 64)
  assert_true(state, string_contains(fg_code, "\x1b[38;2;255;128;64m"), "F13.1.1", "FG TrueColor escape formatted correctly")

  @! Test 1.2: BG escape formatting
  bg_code = ansi_escape_bg(10, 20, 30)
  assert_true(state, string_contains(bg_code, "\x1b[48;2;10;20;30m"), "F13.1.2", "BG TrueColor escape formatted correctly")

  @! Test 1.3: Reset escape code
  reset_code = ansi_reset()
  assert_true(state, string_contains(reset_code, "\x1b[0m"), "F13.1.3", "ANSI Reset escape matches \\x1b[0m")

  @! Test 1.4: Combined format truecolor string
  combo = terminal_format_truecolor(255, 255, 255, 0, 0, 0, "A")
  assert_true(state, string_contains(combo, "\x1b[38;2;255;255;255m"), "F13.1.4", "Combined string contains FG escape")
  assert_true(state, string_contains(combo, "\x1b[48;2;0;0;0m"), "F13.1.5", "Combined string contains BG escape")
  assert_true(state, string_contains(combo, "A"), "F13.1.6", "Combined string contains target character")
  assert_true(state, string_contains(combo, "\x1b[0m"), "F13.1.7", "Combined string contains trailing reset")

  @! --------------------------------------------------------------------------
  @! SECTION 2: Dual-Pixel Half-Block ('▀') Terminal Rasterizer (Even vs Odd Heights)
  @! --------------------------------------------------------------------------
  println("\n--- Section 2: Dual-Pixel Half-Block Rasterization ---")

  @! Test 2.1: Even height canvas (4x4 -> 2 terminal rows)
  c2d_even = canvas2d_renderer_new(4, 4, 1.0)
  c2d_even = canvas2d_renderer_begin_frame(c2d_even, 0xFF181825)
  c2d_even = canvas2d_renderer_draw_rect(c2d_even, 0, 0, 4, 2, 0xFFFF0000, 0, 0, 0) @! Top 2 rows red
  c2d_even = canvas2d_renderer_draw_rect(c2d_even, 0, 2, 4, 2, 0xFF00FF00, 0, 0, 0) @! Bottom 2 rows green

  ansi_even = terminal_render_canvas(c2d_even)
  assert_true(state, string_contains(ansi_even, "▀"), "F13.2.1", "Even canvas emitted upper half-block characters")
  assert_true(state, string_contains(ansi_even, "\x1b[38;2;255;0;0m"), "F13.2.2", "Top row rendered red FG")

  @! Test 2.2: Odd height canvas (4x3 -> 2 terminal rows with row 2 bottom pixel virtual/0)
  c2d_odd = canvas2d_renderer_new(4, 3, 1.0)
  c2d_odd = canvas2d_renderer_begin_frame(c2d_odd, 0xFFFF0000)
  ansi_odd = terminal_render_canvas(c2d_odd)
  assert_true(state, str_len(ansi_odd) > 0, "F13.2.3", "Odd height canvas rasterized without crash")
  assert_true(state, string_contains(ansi_odd, "▀"), "F13.2.4", "Odd height canvas emitted '▀'")

  @! Test 2.3: 1x1 Degenerate Canvas
  c2d_1x1 = canvas2d_renderer_new(1, 1, 1.0)
  c2d_1x1 = canvas2d_renderer_begin_frame(c2d_1x1, 0xFF0000FF)
  ansi_1x1 = terminal_render_canvas(c2d_1x1)
  assert_true(state, string_contains(ansi_1x1, "▀"), "F13.2.5", "1x1 Canvas emitted 1 '▀' block")
  assert_true(state, string_contains(ansi_1x1, "\x1b[38;2;0;0;255m"), "F13.2.6", "1x1 Canvas FG is blue")

  @! --------------------------------------------------------------------------
  @! SECTION 3: Run-Length ANSI Escape Sequence Compaction Stress
  @! --------------------------------------------------------------------------
  println("\n--- Section 3: Run-Length ANSI Escape Compaction ---")

  @! Test 3.1: Flat uniform color canvas (10x2 all red)
  @! With run-length compaction, the entire row of 10 blocks should only emit ONE FG code and ONE BG code!
  c2d_flat = canvas2d_renderer_new(10, 2, 1.0)
  c2d_flat = canvas2d_renderer_begin_frame(c2d_flat, 0xFFFF0000)
  ansi_flat = terminal_render_canvas(c2d_flat)
  @! Count how many times "\x1b[38;2;" appears in ansi_flat
  @! In a 1-row terminal output (since 2 pixel rows = 1 terminal row), it should appear exactly ONCE
  assert_true(state, str_len(ansi_flat) < 100, "F13.3.1", "Uniform color row compacted into compact payload (<100 chars)")

  @! Test 3.2: Alternating checkerboard pixels (high escape throughput)
  c2d_check = canvas2d_renderer_new(6, 2, 1.0)
  c2d_check = canvas2d_renderer_begin_frame(c2d_check, 0xFF000000)
  ci = 0
  @while ci < 6
    @if ci % 2 == 0
      c2d_check = canvas2d_renderer_set_pixel(c2d_check, ci, 0, 0xFFFF0000)
      c2d_check = canvas2d_renderer_set_pixel(c2d_check, ci, 1, 0xFF0000FF)
    @else
      c2d_check = canvas2d_renderer_set_pixel(c2d_check, ci, 0, 0xFF00FF00)
      c2d_check = canvas2d_renderer_set_pixel(c2d_check, ci, 1, 0xFFFFFF00)
    @end
    ci = ci + 1
  @end
  ansi_check = terminal_render_canvas(c2d_check)
  assert_true(state, str_len(ansi_check) > 100, "F13.3.2", "High-throughput checkerboard emits detailed escape sequence")

  @! --------------------------------------------------------------------------
  @! SECTION 4: Canvas Subregion Scissoring & Coordinate Out-of-Bounds
  @! --------------------------------------------------------------------------
  println("\n--- Section 4: Canvas Subregion Scissoring ---")

  c2d_sub = canvas2d_renderer_new(20, 20, 1.0)
  c2d_sub = canvas2d_renderer_begin_frame(c2d_sub, 0xFF123456)

  @! Valid subregion (5, 5, 10, 10)
  ansi_sub_valid = terminal_render_canvas_region(c2d_sub, 5, 5, 10, 10)
  assert_true(state, str_len(ansi_sub_valid) > 0, "F13.4.1", "Valid subregion rendered")

  @! Degenerate subregions (negative coords, out of bounds, zero width/height)
  ansi_sub_zero_w = terminal_render_canvas_region(c2d_sub, 5, 5, 0, 10)
  assert_eq_int(state, str_len(ansi_sub_zero_w), 0, "F13.4.2", "Zero width subregion returns empty string")

  ansi_sub_neg_w = terminal_render_canvas_region(c2d_sub, 5, 5, -5, 10)
  assert_eq_int(state, str_len(ansi_sub_neg_w), 0, "F13.4.3", "Negative width subregion returns empty string")

  ansi_sub_oob = terminal_render_canvas_region(c2d_sub, 100, 100, 10, 10)
  assert_eq_int(state, str_len(ansi_sub_oob), 0, "F13.4.4", "Out-of-bounds subregion returns empty string")

  @! --------------------------------------------------------------------------
  @! SECTION 5: Layout Node Wireframe Character-Mode Renderer
  @! --------------------------------------------------------------------------
  println("\n--- Section 5: Layout Node Wireframe Character Renderer ---")

  @! Root box with nested child
  root_node = layout_node_new(1, LAYOUT_FLEX_COLUMN(), ALIGN_START(), JUSTIFY_START())
  root_node.x = 0
  root_node.y = 0
  root_node.width = 300
  root_node.height = 100
  root_node.text_content = "ROOT"

  child_node = layout_node_new(2, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  child_node.x = 20
  child_node.y = 20
  child_node.width = 100
  child_node.height = 40
  child_node.text_content = "CHILD"

  root_node.children = root_node.children.push(child_node)

  char_grid_out = terminal_render_layout_tree(root_node, 40, 10)
  assert_true(state, string_contains(char_grid_out, "┌"), "F13.5.1", "Top-left corner ┌ rendered")
  assert_true(state, string_contains(char_grid_out, "┐"), "F13.5.2", "Top-right corner ┐ rendered")
  assert_true(state, string_contains(char_grid_out, "└"), "F13.5.3", "Bottom-left corner └ rendered")
  assert_true(state, string_contains(char_grid_out, "┘"), "F13.5.4", "Bottom-right corner ┘ rendered")
  assert_true(state, string_contains(char_grid_out, "ROOT"), "F13.5.5", "Root text content embedded in character grid")
  assert_true(state, string_contains(char_grid_out, "CHILD"), "F13.5.6", "Child text content embedded in character grid")

  println("=================================================================")
  println("F13 Stress Results: " + int_to_str(state.passed) + "/" + int_to_str(state.total) + " passed, " + int_to_str(state.failed) + " failed.")
  @if state.failed == 0
    println("Verdict: F13 ANSI TERMINAL TRUECOLOR RASTERIZER FULLY HARDENED")
  @else
    println("Verdict: F13 VULNERABILITIES DETECTED")
  @end
  println("=================================================================")
@end
