@! ============================================================================
@! MAYA TIER 1 E2E TEST SUITE — FEATURE F11: PURE MAYA CANVAS2D
@! Module: tests/e2e/tier1_features/web/test_f11_canvas2d.maya
@! 100% Pure Maya Language — Zero External Dependencies
@! Coverage:
@! 1. Clear & Get Pixel ARGB Channel Math
@! 2. Solid Filled Rectangles
@! 3. Border Rectangles with Configurable Width
@! 4. Push / Pop Rectangular Clipping Stack
@! 5. Monospace Glyph Text Rasterization
@! 6. Lines, Gradients & Porter-Duff Alpha Blending
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/tools/maya_test"
import "universe/web/frontend/renderer/canvas2d_renderer"

@! ----------------------------------------------------------------------------
@! TEST 1: Clear & Get Pixel ARGB Channel Math
@! ----------------------------------------------------------------------------
@fn test_f11_01_clear_and_get_pixel()
  @! 1. Packing & Unpacking ARGB 32-bit channels
  packed = argb_pack(255, 128, 64, 32)
  assert_eq(argb_get_a(packed), 255, "Alpha channel extraction = 255")
  assert_eq(argb_get_r(packed), 128, "Red channel extraction = 128")
  assert_eq(argb_get_g(packed), 64, "Green channel extraction = 64")
  assert_eq(argb_get_b(packed), 32, "Blue channel extraction = 32")
  
  @! 2. Canvas creation and clearing
  c2d = canvas2d_renderer_new(80, 60, 1.0)
  assert_eq(c2d.c2d_width, 80, "Canvas width = 80")
  assert_eq(c2d.c2d_height, 60, "Canvas height = 60")
  assert_eq(c2d.c2d_pixels.len(), 4800, "Pixel buffer length = 80 * 60 = 4800")
  
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF181825)
  assert_eq(canvas2d_renderer_get_pixel(c2d, 0, 0), 0xFF181825, "Top-left pixel cleared to 0xFF181825")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 79, 59), 0xFF181825, "Bottom-right pixel cleared to 0xFF181825")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 40, 30), 0xFF181825, "Center pixel cleared to 0xFF181825")
  
  @! Out of bounds safely returns 0
  assert_eq(canvas2d_renderer_get_pixel(c2d, -1, 0), 0, "Out of bounds (-1, 0) returns 0")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 80, 60), 0, "Out of bounds (80, 60) returns 0")
  
  println("  [PASS] T1_F11_01: Clear & Get Pixel ARGB Channel Math")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 2: Solid Filled Rectangles
@! ----------------------------------------------------------------------------
@fn test_f11_02_filled_rect()
  c2d = canvas2d_renderer_new(100, 100, 1.0)
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF000000) @! Solid black background
  
  @! Draw 40x30 red rect at (20, 30)
  c2d = canvas2d_renderer_draw_rect(c2d, 20, 30, 40, 30, 0xFFFF0000, 0, 0, 0)
  
  @! Inside rect pixels
  assert_eq(canvas2d_renderer_get_pixel(c2d, 20, 30), 0xFFFF0000, "Top-left of drawn rect is red")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 40, 45), 0xFFFF0000, "Interior of drawn rect is red")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 59, 59), 0xFFFF0000, "Bottom-right of drawn rect is red")
  
  @! Outside rect pixels (untouched black)
  assert_eq(canvas2d_renderer_get_pixel(c2d, 19, 30), 0xFF000000, "Pixel left of rect remains black")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 60, 30), 0xFF000000, "Pixel right of rect remains black")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 20, 29), 0xFF000000, "Pixel above rect remains black")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 20, 60), 0xFF000000, "Pixel below rect remains black")
  
  println("  [PASS] T1_F11_02: Solid Filled Rectangles")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 3: Border Rectangles with Configurable Width
@! ----------------------------------------------------------------------------
@fn test_f11_03_border_rect()
  c2d = canvas2d_renderer_new(100, 100, 1.0)
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF000000)
  
  @! Draw 50x50 rect at (10, 10) with green body (0xFF00FF00) and blue border (0xFF0000FF), border_width = 2
  c2d = canvas2d_renderer_draw_rect(c2d, 10, 10, 50, 50, 0xFF00FF00, 0xFF0000FF, 2, 0)
  
  @! Border pixels (outer 2px ring)
  assert_eq(canvas2d_renderer_get_pixel(c2d, 10, 10), 0xFF0000FF, "Corner border is blue")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 11, 11), 0xFF0000FF, "2nd pixel border is blue")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 59, 59), 0xFF0000FF, "Bottom-right border is blue")
  
  @! Interior pixels (inside 2px border)
  assert_eq(canvas2d_renderer_get_pixel(c2d, 12, 12), 0xFF00FF00, "Interior at (12, 12) is green body")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 35, 35), 0xFF00FF00, "Center at (35, 35) is green body")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 57, 57), 0xFF00FF00, "Interior at (57, 57) is green body")
  
  println("  [PASS] T1_F11_03: Border Rectangles with Configurable Width")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 4: Push / Pop Rectangular Clipping Stack
@! ----------------------------------------------------------------------------
@fn test_f11_04_clip_stack()
  c2d = canvas2d_renderer_new(100, 100, 1.0)
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF000000)
  
  @! Push clip: restricted to (25, 25, 50, 50)
  c2d = canvas2d_renderer_push_clip(c2d, 25, 25, 50, 50)
  assert_eq(c2d.c2d_current_clip[0], 25, "Clip min_x = 25")
  assert_eq(c2d.c2d_current_clip[1], 25, "Clip min_y = 25")
  assert_eq(c2d.c2d_current_clip[2], 75, "Clip max_x = 75")
  assert_eq(c2d.c2d_current_clip[3], 75, "Clip max_y = 75")
  
  @! Draw full canvas rect with yellow (0xFFFFFF00)
  c2d = canvas2d_renderer_draw_rect(c2d, 0, 0, 100, 100, 0xFFFFFF00, 0, 0, 0)
  
  @! Pixels inside clip region must be yellow
  assert_eq(canvas2d_renderer_get_pixel(c2d, 30, 30), 0xFFFFFF00, "Pixel inside clip is drawn yellow")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 50, 50), 0xFFFFFF00, "Center pixel inside clip is drawn yellow")
  
  @! Pixels outside clip region must be protected (black)
  assert_eq(canvas2d_renderer_get_pixel(c2d, 10, 10), 0xFF000000, "Pixel outside clip (10, 10) protected")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 80, 80), 0xFF000000, "Pixel outside clip (80, 80) protected")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 24, 50), 0xFF000000, "Pixel left of clip boundary protected")
  
  @! Pop clip and verify full bounds restored
  c2d = canvas2d_renderer_pop_clip(c2d)
  assert_eq(c2d.c2d_current_clip[0], 0, "Popped clip restored min_x = 0")
  assert_eq(c2d.c2d_current_clip[2], 100, "Popped clip restored max_x = 100")
  
  println("  [PASS] T1_F11_04: Push / Pop Rectangular Clipping Stack")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 5: Monospace Glyph Text Rasterization
@! ----------------------------------------------------------------------------
@fn test_f11_05_glyph_text_rendering()
  c2d = canvas2d_renderer_new(120, 40, 1.0)
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF000000)
  
  initial_draw_calls = c2d.c2d_draw_call_count
  c2d = canvas2d_renderer_draw_text(c2d, "MAYA", 10, 10, 14, 0xFFFFFFFF)
  
  assert_true(c2d.c2d_draw_call_count > initial_draw_calls, "Text draw call count incremented")
  
  @! Verify that non-zero pixels were drawn in text area (10..60, 10..24)
  drawn_pixels = 0
  y = 10
  @while y < 24
    x = 10
    @while x < 60
      @if canvas2d_renderer_get_pixel(c2d, x, y) != 0xFF000000
        drawn_pixels = drawn_pixels + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  
  assert_true(drawn_pixels > 20, "At least 20 glyph pixels rendered for 'MAYA'")
  
  println("  [PASS] T1_F11_05: Monospace Glyph Text Rasterization")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 6: Lines, Gradients & Porter-Duff Alpha Blending
@! ----------------------------------------------------------------------------
@fn test_f11_06_lines_gradients_alpha_blend()
  c2d = canvas2d_renderer_new(60, 60, 1.0)
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF0000FF) @! Blue background
  
  @! 1. Porter-Duff Alpha blend semi-transparent white (50% alpha = 128) over blue
  semi_white = argb_pack(128, 255, 255, 255)
  opaque_blue = 0xFF0000FF
  blended = argb_blend(semi_white, opaque_blue)
  assert_eq(argb_get_a(blended), 255, "Blended alpha over opaque remains 255")
  assert_true(argb_get_r(blended) > 100 && argb_get_r(blended) < 150, "Blended red channel ~128")
  assert_true(argb_get_g(blended) > 100 && argb_get_g(blended) < 150, "Blended green channel ~128")
  
  @! 2. Bresenham Line Drawing
  c2d = canvas2d_renderer_draw_line(c2d, 10, 10, 50, 10, 0xFFFFFFFF)
  assert_eq(canvas2d_renderer_get_pixel(c2d, 10, 10), 0xFFFFFFFF, "Line start pixel is white")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 30, 10), 0xFFFFFFFF, "Line midpoint pixel is white")
  assert_eq(canvas2d_renderer_get_pixel(c2d, 50, 10), 0xFFFFFFFF, "Line end pixel is white")
  
  @! 3. Vertical Linear Gradient
  c2d = canvas2d_renderer_fill_gradient(c2d, 0, 30, 60, 30, 0xFF000000, 0xFFFFFFFF, true)
  p_top = canvas2d_renderer_get_pixel(c2d, 30, 30)
  p_mid = canvas2d_renderer_get_pixel(c2d, 30, 45)
  p_bot = canvas2d_renderer_get_pixel(c2d, 30, 59)
  
  assert_eq(argb_get_r(p_top), 0, "Gradient top is black (0)")
  assert_true(argb_get_r(p_mid) > 100 && argb_get_r(p_mid) < 150, "Gradient midpoint is mid-gray")
  assert_true(argb_get_r(p_bot) > 230, "Gradient bottom is near white")
  
  println("  [PASS] T1_F11_06: Lines, Gradients & Porter-Duff Alpha Blending")
  return 1
@end

@! ----------------------------------------------------------------------------
@! Runner Function
@! ----------------------------------------------------------------------------
@fn run_f11_canvas2d_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F11: Pure Maya Canvas2D Software Rasterizer")
  println("=================================================================")
  
  passed = 0
  passed = passed + test_f11_01_clear_and_get_pixel()
  passed = passed + test_f11_02_filled_rect()
  passed = passed + test_f11_03_border_rect()
  passed = passed + test_f11_04_clip_stack()
  passed = passed + test_f11_05_glyph_text_rendering()
  passed = passed + test_f11_06_lines_gradients_alpha_blend()
  
  println("-----------------------------------------------------------------")
  println("Feature F11 Results: " + passed.to_str() + "/6 tests passed.")
  assert_eq(passed, 6, "All F11 tests must pass")
  return passed
@end

@fn main()
  run_f11_canvas2d_tests()
@end
