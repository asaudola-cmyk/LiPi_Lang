@! ============================================================================
@! MAYA TIER 1 E2E TEST SUITE — FEATURE F13: ANSI TERMINAL TRUECOLOR RASTER
@! Module: tests/e2e/tier1_features/web/test_f13_terminal_raster.maya
@! 100% Pure Maya Language — Zero External Dependencies
@! Coverage:
@! 1. 24-bit TrueColor ANSI Escape Sequences (FG, BG, Reset)
@! 2. Dual-Pixel Upper-Half Block ('▀') Compression
@! 3. Solid Framebuffer Serialized Terminal Stream
@! 4. Character-Mode Wireframe Box-Drawing & Text Layout
@! 5. Terminal Renderer Struct & Buffer Dimensions
@! 6. End-to-End Markup to ANSI Terminal Pipeline
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/tools/maya_test"
import "universe/web/frontend/renderer/canvas2d_renderer"
import "universe/web/frontend/renderer/terminal_renderer"
import "universe/web/frontend/layout/layout_types"
import "universe/web/frontend/mod"

@! ----------------------------------------------------------------------------
@! TEST 1: 24-bit TrueColor ANSI Escape Sequences (FG, BG, Reset)
@! ----------------------------------------------------------------------------
@fn test_f13_01_ansi_escape_sequences()
  @! 1. Foreground 24-bit RGB escape
  fg_escape = ansi_escape_fg(255, 128, 0)
  assert_str_eq(fg_escape, "\x1b[38;2;255;128;0m", "Foreground RGB (255, 128, 0) escape format")
  
  @! 2. Background 24-bit RGB escape
  bg_escape = ansi_escape_bg(0, 64, 128)
  assert_str_eq(bg_escape, "\x1b[48;2;0;64;128m", "Background RGB (0, 64, 128) escape format")
  
  @! 3. ANSI reset
  rst = ansi_reset()
  assert_str_eq(rst, "\x1b[0m", "ANSI reset sequence format")
  
  @! 4. Full formatted truecolor character string
  formatted = terminal_format_truecolor(255, 0, 0, 0, 0, 255, "M")
  assert_true(string_contains(formatted, "\x1b[38;2;255;0;0m"), "Contains red FG escape")
  assert_true(string_contains(formatted, "\x1b[48;2;0;0;255m"), "Contains blue BG escape")
  assert_true(string_contains(formatted, "M"), "Contains text char 'M'")
  assert_true(string_contains(formatted, "\x1b[0m"), "Contains ANSI reset")
  
  println("  [PASS] T1_F13_01: 24-bit TrueColor ANSI Escape Sequences")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 2: Dual-Pixel Upper-Half Block ('▀') Compression
@! ----------------------------------------------------------------------------
@fn test_f13_02_dual_pixel_half_block()
  @! Canvas: 4 pixels wide, 2 pixels high
  @! Top row (y=0) = Red (0xFFFF0000)
  @! Bottom row (y=1) = Blue (0xFF0000FF)
  c2d = canvas2d_renderer_new(4, 2, 1.0)
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF000000)
  c2d = canvas2d_renderer_draw_rect(c2d, 0, 0, 4, 1, 0xFFFF0000, 0, 0, 0) @! Top row red
  c2d = canvas2d_renderer_draw_rect(c2d, 0, 1, 4, 1, 0xFF0000FF, 0, 0, 0) @! Bottom row blue
  
  ansi_output = terminal_render_canvas(c2d)
  
  @! Output should contain the half-block character "▀"
  assert_true(string_contains(ansi_output, "▀"), "Output contains half block '▀'")
  assert_true(string_contains(ansi_output, "\x1b[38;2;255;0;0m"), "Top pixel encoded as foreground red")
  assert_true(string_contains(ansi_output, "\x1b[48;2;0;0;255m"), "Bottom pixel encoded as background blue")
  assert_true(string_contains(ansi_output, "\x1b[0m"), "Line ends with ANSI reset")
  
  println("  [PASS] T1_F13_02: Dual-Pixel Upper-Half Block ('▀') Compression")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 3: Solid Framebuffer Serialized Terminal Stream
@! ----------------------------------------------------------------------------
@fn test_f13_03_solid_framebuffer_stream()
  @! Canvas: 8 pixels wide, 4 pixels high (produces 2 terminal rows)
  c2d = canvas2d_renderer_new(8, 4, 1.0)
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF313244) @! Catppuccin surface0
  
  term_stream = terminal_render_canvas(c2d)
  
  assert_true(str_len(term_stream) > 0, "Terminal stream is non-empty")
  assert_true(string_contains(term_stream, "▀"), "Contains half-block glyphs")
  assert_true(string_contains(term_stream, "\n"), "Contains newline character")
  
  @! Region rasterizer with clipping
  sub_stream = terminal_render_canvas_region(c2d, 2, 0, 4, 2)
  assert_true(str_len(sub_stream) > 0, "Subregion rasterizer generates valid stream")
  
  @! Empty bounds return empty string safely
  empty_stream = terminal_render_canvas_region(c2d, 0, 0, 0, 0)
  assert_str_eq(empty_stream, "", "0x0 region returns empty string")
  
  println("  [PASS] T1_F13_03: Solid Framebuffer Serialized Terminal Stream")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 4: Character-Mode Wireframe Box-Drawing & Text Layout
@! ----------------------------------------------------------------------------
@fn test_f13_04_wireframe_box_drawing()
  @! Create layout box: width 300, height 120, text "MAYA ENGINE"
  node = layout_node_new(1, LAYOUT_FLEX_COLUMN(), ALIGN_START(), JUSTIFY_START())
  node.x = 0
  node.y = 0
  node.width = 300
  node.height = 120
  node.text_content = "MAYA ENGINE"
  
  cols = 30
  rows = 6
  rendered_grid = terminal_render_layout_tree(node, cols, rows)
  
  assert_true(str_len(rendered_grid) > 0, "Grid output is non-empty")
  assert_true(string_contains(rendered_grid, "┌"), "Contains top-left box corner '┌'")
  assert_true(string_contains(rendered_grid, "─"), "Contains horizontal box border '─'")
  assert_true(string_contains(rendered_grid, "│"), "Contains vertical box border '│'")
  assert_true(string_contains(rendered_grid, "┘"), "Contains bottom-right box corner '┘'")
  assert_true(string_contains(rendered_grid, "MAYA ENGINE"), "Contains text label 'MAYA ENGINE'")
  
  println("  [PASS] T1_F13_04: Character-Mode Wireframe Box-Drawing & Text Layout")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 5: Terminal Renderer Struct & Buffer Dimensions
@! ----------------------------------------------------------------------------
@fn test_f13_05_renderer_struct_init()
  term = terminal_renderer_new(80, 24)
  
  assert_eq(term.term_cols, 80, "Terminal cols = 80")
  assert_eq(term.term_rows, 24, "Terminal rows = 24")
  assert_eq(term.term_char_buffer.len(), 1920, "Char buffer length = 80 * 24 = 1920")
  assert_eq(term.term_fg_buffer.len(), 1920, "FG buffer length = 1920")
  assert_eq(term.term_bg_buffer.len(), 1920, "BG buffer length = 1920")
  assert_eq(term.term_total_frames, 0, "Initial frame count = 0")
  
  @! Test default fallback for non-positive dimensions
  term_def = terminal_renderer_new(0, 0)
  assert_eq(term_def.term_cols, 80, "Default fallback cols = 80")
  assert_eq(term_def.term_rows, 24, "Default fallback rows = 24")
  
  println("  [PASS] T1_F13_05: Terminal Renderer Struct & Buffer Dimensions")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 6: End-to-End Markup to ANSI Terminal Pipeline
@! ----------------------------------------------------------------------------
@fn test_f13_06_e2e_markup_to_ansi()
  markup_source = "<div style=\"width: 400px; height: 160px; background: #1E1E2E;\"><header style=\"height: 40px;\"><h1>Terminal Header</h1></header><div style=\"height: 80px;\"><p>Status: OK</p></div></div>"
  
  ansi_result = web_engine_render_markup_to_ansi(markup_source, 40, 8)
  
  assert_true(str_len(ansi_result) > 0, "Rendered ANSI result is non-empty")
  assert_true(string_contains(ansi_result, "┌") || string_contains(ansi_result, "─"), "Contains wireframe box lines")
  assert_true(string_contains(ansi_result, "\n"), "Contains multiple output lines")
  
  println("  [PASS] T1_F13_06: End-to-End Markup to ANSI Terminal Pipeline")
  return 1
@end

@! ----------------------------------------------------------------------------
@! Runner Function
@! ----------------------------------------------------------------------------
@fn run_f13_terminal_raster_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F13: ANSI Terminal TrueColor Raster Suite")
  println("=================================================================")
  
  passed = 0
  passed = passed + test_f13_01_ansi_escape_sequences()
  passed = passed + test_f13_02_dual_pixel_half_block()
  passed = passed + test_f13_03_solid_framebuffer_stream()
  passed = passed + test_f13_04_wireframe_box_drawing()
  passed = passed + test_f13_05_renderer_struct_init()
  passed = passed + test_f13_06_e2e_markup_to_ansi()
  
  println("-----------------------------------------------------------------")
  println("Feature F13 Results: " + passed.to_str() + "/6 tests passed.")
  assert_eq(passed, 6, "All F13 tests must pass")
  return passed
@end

@fn main()
  run_f13_terminal_raster_tests()
@end
