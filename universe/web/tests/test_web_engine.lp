@! ============================================================================
@! MAYA SOVEREIGN TEST SUITE — DOM-BYPASSING WEB ENGINE (F09-F13)
@! Module: universe/web/tests/test_web_engine.maya
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Comprehensive 4-Tier Test Suite Covering:
@! - Tier 1: Canvas2D 32-bit ARGB Software Rasterizer (F11)
@! - Tier 2: Dirty Rect Damage Compositor & HiDPI Scaling (F12)
@! - Tier 3: ANSI Terminal TrueColor Dual-Pixel Rasterizer (F13)
@! - Tier 4: End-to-End Integration Pipeline (Markup -> Layout -> Canvas/ANSI)
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"

@! Web Subsystems
import "universe/web/markup_parser"
import "universe/web/frontend/layout/layout_types"
import "universe/web/frontend/layout/flexbox_solver"
import "universe/web/frontend/renderer/canvas2d_renderer"
import "universe/web/frontend/renderer/terminal_renderer"
import "universe/web/frontend/dom_bypass/canvas_host"
import "universe/web/frontend/mod"

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

@fn assert_eq_str(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected '" + expected + "', got '" + actual + "')")
    return 0
  @end
@end

@fn main()
  println("=================================================================")
  println("▶ [SOVEREIGN TEST] DOM-Bypassing Web Engine Comprehensive Suite")
  println("=================================================================")

  state = test_state_new()

  @! ==========================================================================
  @! SUITE 1: Pure Maya Canvas2D Software Rasterizer (Feature F11)
  @! ==========================================================================
  println("\n--- Suite 1: Pure Maya Canvas2D Software Rasterizer (F11) ---")

  @! 1.1 ARGB Channel Packing & Unpacking
  c_packed = argb_pack(255, 137, 180, 250) @! #89B4FA
  assert_eq_int(state, argb_get_a(c_packed), 255, "S1.1", "ARGB Alpha extraction = 255")
  assert_eq_int(state, argb_get_r(c_packed), 137, "S1.2", "ARGB Red extraction = 137")
  assert_eq_int(state, argb_get_g(c_packed), 180, "S1.3", "ARGB Green extraction = 180")
  assert_eq_int(state, argb_get_b(c_packed), 250, "S1.4", "ARGB Blue extraction = 250")

  @! 1.2 Porter-Duff Alpha Blending
  opaque_red = argb_pack(255, 255, 0, 0)
  opaque_blue = argb_pack(255, 0, 0, 255)
  semi_white = argb_pack(128, 255, 255, 255)
  blended = argb_blend(semi_white, opaque_blue)
  assert_eq_int(state, argb_get_a(blended), 255, "S1.5", "Blended opaque destination stays alpha 255")
  assert_true(state, argb_get_r(blended) > 100 && argb_get_r(blended) < 150, "S1.6", "Blended red channel interpolated")
  assert_true(state, argb_get_b(blended) > 100 && argb_get_b(blended) < 200, "S1.7", "Blended blue channel interpolated")

  @! 1.3 Canvas Initialization & Clear Frame
  c2d = canvas2d_renderer_new(100, 100, 1.0)
  assert_eq_int(state, c2d.c2d_width, 100, "S1.8", "Canvas width = 100")
  assert_eq_int(state, c2d.c2d_height, 100, "S1.9", "Canvas height = 100")
  assert_eq_int(state, c2d.c2d_pixels.len(), 10000, "S1.10", "Canvas pixel buffer size = 10000")

  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF181825)
  p0 = canvas2d_renderer_get_pixel(c2d, 0, 0)
  assert_eq_int(state, p0, 0xFF181825, "S1.11", "Begin frame cleared pixel to clear_color 0xFF181825")

  @! 1.4 Rect Drawing with Border
  c2d = canvas2d_renderer_draw_rect(c2d, 10, 10, 40, 30, 0xFFFF0000, 0xFF00FF00, 1, 0)
  p_inside = canvas2d_renderer_get_pixel(c2d, 20, 20)
  assert_eq_int(state, p_inside, 0xFFFF0000, "S1.12", "Drawn rect body pixel is red 0xFFFF0000")
  p_border = canvas2d_renderer_get_pixel(c2d, 10, 10)
  assert_eq_int(state, p_border, 0xFF00FF00, "S1.13", "Drawn rect border pixel is green 0xFF00FF00")
  p_outside = canvas2d_renderer_get_pixel(c2d, 5, 5)
  assert_eq_int(state, p_outside, 0xFF181825, "S1.14", "Pixel outside rect remains clear_color")

  @! 1.5 Clipping Stack Geometric Intersection
  c2d = canvas2d_renderer_push_clip(c2d, 20, 20, 20, 20)
  assert_eq_int(state, c2d.c2d_current_clip[0], 20, "S1.15", "Clip min_x = 20")
  assert_eq_int(state, c2d.c2d_current_clip[2], 40, "S1.16", "Clip max_x = 40")
  c2d = canvas2d_renderer_draw_rect(c2d, 0, 0, 100, 100, 0xFF0000FF, 0, 0, 0)
  p_clipped_out = canvas2d_renderer_get_pixel(c2d, 10, 10)
  p_clipped_in = canvas2d_renderer_get_pixel(c2d, 25, 25)
  assert_eq_int(state, p_clipped_out, 0xFF00FF00, "S1.17", "Pixel outside clip region protected")
  assert_eq_int(state, p_clipped_in, 0xFF0000FF, "S1.18", "Pixel inside clip region drawn blue")
  c2d = canvas2d_renderer_pop_clip(c2d)
  assert_eq_int(state, c2d.c2d_current_clip[0], 0, "S1.19", "Popped clip restored min_x = 0")

  @! 1.6 Bresenham Line Drawing
  c2d = canvas2d_renderer_draw_line(c2d, 50, 50, 70, 50, 0xFFFFFFFF)
  p_line = canvas2d_renderer_get_pixel(c2d, 60, 50)
  assert_eq_int(state, p_line, 0xFFFFFFFF, "S1.20", "Bresenham line midpoint is white 0xFFFFFFFF")

  @! 1.7 Linear Gradient Fill
  c2d = canvas2d_renderer_fill_gradient(c2d, 0, 80, 50, 20, 0xFF000000, 0xFFFFFFFF, true)
  p_grad_top = canvas2d_renderer_get_pixel(c2d, 25, 80)
  p_grad_mid = canvas2d_renderer_get_pixel(c2d, 25, 90)
  assert_eq_int(state, argb_get_r(p_grad_top), 0, "S1.21", "Gradient top is black")
  assert_true(state, argb_get_r(p_grad_mid) > 100 && argb_get_r(p_grad_mid) < 150, "S1.22", "Gradient midpoint is gray")

  @! 1.8 Monospace 5x7 Text Rendering
  c2d = canvas2d_renderer_draw_text(c2d, "MAYA", 50, 10, 14, 0xFFFFFF00)
  p_text_area = canvas2d_renderer_get_pixel(c2d, 50, 10)
  assert_true(state, c2d.c2d_draw_call_count > 0, "S1.23", "Draw text recorded draw calls")

  @! 1.9 PPM Serialization
  ppm = canvas2d_renderer_to_ppm(c2d)
  assert_true(state, starts_with(ppm, "P3\n100 100\n255\n"), "S1.24", "PPM header formatted correctly as P3 ASCII")

  @! ==========================================================================
  @! SUITE 2: Dirty Rect Damage Compositor & Canvas Host (Feature F12)
  @! ==========================================================================
  println("\n--- Suite 2: Dirty Rect Damage Compositor & Canvas Host (F12) ---")

  comp = dirty_rect_compositor_new()
  assert_true(state, dirty_rect_compositor_is_dirty(comp), "S2.1", "New compositor starts marked dirty (full redraw)")

  comp = dirty_rect_compositor_reset(comp)
  assert_false(state, dirty_rect_compositor_is_dirty(comp), "S2.2", "Reset compositor is clean")

  comp = dirty_rect_compositor_add_rect(comp, 10, 20, 30, 40)
  assert_true(state, dirty_rect_compositor_is_dirty(comp), "S2.3", "Adding dirty rect marks compositor dirty")
  b1 = dirty_rect_compositor_get_bounds(comp)
  assert_eq_int(state, b1.rect_min_x, 10, "S2.4", "Damage bounds min_x = 10")
  assert_eq_int(state, b1.rect_min_y, 20, "S2.5", "Damage bounds min_y = 20")
  assert_eq_int(state, b1.rect_max_x, 40, "S2.6", "Damage bounds max_x = 40 (10+30)")
  assert_eq_int(state, b1.rect_max_y, 60, "S2.7", "Damage bounds max_y = 60 (20+40)")

  @! Add second rect to test union accumulation
  comp = dirty_rect_compositor_add_rect(comp, 50, 10, 20, 80)
  b2 = dirty_rect_compositor_get_bounds(comp)
  assert_eq_int(state, b2.rect_min_x, 10, "S2.8", "Union min_x preserved = 10")
  assert_eq_int(state, b2.rect_min_y, 10, "S2.9", "Union min_y expanded = 10")
  assert_eq_int(state, b2.rect_max_x, 70, "S2.10", "Union max_x expanded = 70 (50+20)")
  assert_eq_int(state, b2.rect_max_y, 90, "S2.11", "Union max_y expanded = 90 (10+80)")

  @! Canvas Host DPR scaling & frame lifecycle
  host = canvas_host_new("web_canvas", 400, 300, 2.0, 3, 0xFF181825)
  assert_eq_int(state, host.css_width, 400, "S2.12", "Host CSS width = 400")
  assert_eq_int(state, host.css_height, 300, "S2.13", "Host CSS height = 300")
  assert_eq_int(state, host.physical_width, 800, "S2.14", "Host physical width = 800 (DPR 2.0)")
  assert_eq_int(state, host.physical_height, 600, "S2.15", "Host physical height = 600 (DPR 2.0)")

  host = canvas_host_begin_frame(host, 1000)
  host = canvas_host_draw_rect(host, 10, 10, 50, 50, 0xFFFF8800, 0, 0, 0)
  host = canvas_host_present_frame(host)
  assert_eq_int(state, host.presented_frames, 1, "S2.16", "Presented frames count = 1")
  assert_false(state, dirty_rect_compositor_is_dirty(host.compositor), "S2.17", "Compositor reset after frame presentation")

  @! Frame timing loop & smoothed FPS
  host = canvas_host_begin_frame(host, 1016)
  assert_true(state, host.timing_loop.loop_fps_estimate > 40.0, "S2.18", "FPS estimate ~60 for 16ms tick")

  @! ==========================================================================
  @! SUITE 3: ANSI Terminal TrueColor Rasterizer (Feature F13)
  @! ==========================================================================
  println("\n--- Suite 3: ANSI Terminal TrueColor Rasterizer (F13) ---")

  term = terminal_renderer_new(40, 20)
  assert_eq_int(state, term.term_cols, 40, "S3.1", "Terminal cols = 40")
  assert_eq_int(state, term.term_rows, 20, "S3.2", "Terminal rows = 20")

  tc_sample = terminal_format_truecolor(255, 0, 0, 0, 0, 255, "X")
  assert_true(state, string_contains(tc_sample, "\x1b[38;2;255;0;0m"), "S3.3", "TrueColor FG escape sequence formatted")
  assert_true(state, string_contains(tc_sample, "\x1b[48;2;0;0;255m"), "S3.4", "TrueColor BG escape sequence formatted")
  assert_true(state, string_contains(tc_sample, "\x1b[0m"), "S3.5", "ANSI reset sequence appended")

  @! Dual-pixel half-block canvas rasterization
  small_c2d = canvas2d_renderer_new(4, 4, 1.0)
  small_c2d = canvas2d_renderer_begin_frame(small_c2d, 0xFF181825)
  small_c2d = canvas2d_renderer_draw_rect(small_c2d, 0, 0, 4, 2, 0xFFFF0000, 0, 0, 0) @! Top 2 rows red
  small_c2d = canvas2d_renderer_draw_rect(small_c2d, 0, 2, 4, 2, 0xFF0000FF, 0, 0, 0) @! Bottom 2 rows blue

  ansi_out = terminal_render_canvas(small_c2d)
  assert_true(state, string_contains(ansi_out, "▀"), "S3.6", "Dual-pixel rasterizer emitted '▀' character")
  assert_true(state, str_len(ansi_out) > 0, "S3.7", "ANSI raster generated non-empty output")

  @! Wireframe layout box-drawing renderer
  lnode = layout_node_new(1, LAYOUT_FLEX_COLUMN(), ALIGN_START(), JUSTIFY_START())
  lnode.width = 400
  lnode.height = 200
  lnode.text_content = "DASHBOARD"
  ansi_box = terminal_render_layout_tree(lnode, 40, 10)
  assert_true(state, string_contains(ansi_box, "┌") || string_contains(ansi_box, "─"), "S3.8", "Character layout renderer drew box borders")
  assert_true(state, string_contains(ansi_box, "DASHBOARD"), "S3.9", "Character layout renderer printed text content")

  @! ==========================================================================
  @! SUITE 4: End-to-End Sovereign Web Engine Integration Pipeline
  @! ==========================================================================
  println("\n--- Suite 4: End-to-End Sovereign Web Engine Integration ---")

  e2e_markup = "<div class=\"dashboard\" style=\"width: 600px; height: 400px; padding: 20px; gap: 15px; background: #1E1E2E;\"><header style=\"height: 60px; background: #313244; color: white;\"><h1>Lipi Sovereign Web Engine</h1></header><div style=\"display: flex; flex-direction: row; gap: 10px; height: 200px;\"><div class=\"card\" style=\"flex-grow: 1; background: #181825; border: 1px solid #89B4FA;\">Card A</div><div class=\"card\" style=\"flex-grow: 2; background: #181825; border: 1px solid #A6E3A1;\">Card B</div></div></div>"

  @! 4.1 Parse and Solve Layout
  solved_e2e = web_engine_solve_markup(e2e_markup, 600, 400)
  assert_eq_int(state, solved_e2e.width, 600, "S4.1", "E2E solved layout root width = 600")
  assert_eq_int(state, solved_e2e.height, 400, "S4.2", "E2E solved layout root height = 400")
  assert_eq_int(state, solved_e2e.children.len(), 2, "S4.3", "E2E layout root has 2 child sections")

  header_box = solved_e2e.children[0]
  assert_eq_int(state, header_box.height, 60, "S4.4", "Header section height = 60")

  body_box = solved_e2e.children[1]
  assert_eq_int(state, body_box.children.len(), 2, "S4.5", "Body section has 2 flex cards")
  card_a = body_box.children[0]
  card_b = body_box.children[1]
  assert_true(state, card_b.width > card_a.width, "S4.6", "Card B (flex-grow: 2) wider than Card A (flex-grow: 1)")

  @! 4.2 Rasterize to Canvas2D
  c2d_rendered = web_engine_render_markup_to_canvas(e2e_markup, 600, 400, 1.0)
  assert_eq_int(state, c2d_rendered.c2d_width, 600, "S4.7", "Rendered canvas width = 600")
  assert_eq_int(state, c2d_rendered.c2d_height, 400, "S4.8", "Rendered canvas height = 400")
  assert_true(state, c2d_rendered.c2d_draw_call_count > 0, "S4.9", "Rendered canvas executed draw calls")

  @! 4.3 Rasterize to ANSI Terminal
  ansi_e2e = web_engine_render_markup_to_ansi(e2e_markup, 60, 20)
  assert_true(state, str_len(ansi_e2e) > 0, "S4.10", "Rendered ANSI terminal output non-empty")

  println("=================================================================")
  println("Web Engine Test Results: " + int_to_str(state.passed) + "/" + int_to_str(state.total) + " passed, " + int_to_str(state.failed) + " failed.")
  @if state.failed == 0
    println("Status: UNIVERSAL HARMONY — 100% PASSING SOVEREIGN WEB ENGINE")
  @else
    println("Status: CHAOS DETECTED — TEST FAILURES OCCURRED")
  @end
  println("=================================================================")
@end
