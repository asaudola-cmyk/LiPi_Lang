@! ============================================================================
@! ADVERSARIAL STRESS SUITE — CHALLENGER 2: CANVAS2D SOFTWARE RASTERIZER (F11)
@! Module: tests/adversarial/test_adv_web_f11_canvas2d.maya
@! Target: universe/web/frontend/renderer/canvas2d_renderer.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"
import "universe/web/frontend/renderer/canvas2d_renderer"

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
  println("⚔️  ADVERSARIAL CHALLENGER 2: Feature F11 (Canvas2D Rasterizer) ⚔️")
  println("=================================================================")

  state = test_state_new()

  @! --------------------------------------------------------------------------
  @! SECTION 1: ARGB Clamping, Unpacking & Bitwise Arithmetic Boundaries
  @! --------------------------------------------------------------------------
  println("\n--- Section 1: ARGB Packing & Clamping Boundaries ---")

  @! Test 1.1: Negative channel values clamp to 0
  c_neg = argb_pack(-50, -100, -200, -999)
  assert_eq_int(state, argb_get_a(c_neg), 0, "F11.1.1", "Negative Alpha clamps to 0")
  assert_eq_int(state, argb_get_r(c_neg), 0, "F11.1.2", "Negative Red clamps to 0")
  assert_eq_int(state, argb_get_g(c_neg), 0, "F11.1.3", "Negative Green clamps to 0")
  assert_eq_int(state, argb_get_b(c_neg), 0, "F11.1.4", "Negative Blue clamps to 0")
  assert_eq_int(state, c_neg, 0, "F11.1.5", "All-negative packed integer is 0")

  @! Test 1.2: Overflow channel values clamp to 255
  c_over = argb_pack(300, 512, 1000, 65536)
  assert_eq_int(state, argb_get_a(c_over), 255, "F11.1.6", "Overflow Alpha clamps to 255")
  assert_eq_int(state, argb_get_r(c_over), 255, "F11.1.7", "Overflow Red clamps to 255")
  assert_eq_int(state, argb_get_g(c_over), 255, "F11.1.8", "Overflow Green clamps to 255")
  assert_eq_int(state, argb_get_b(c_over), 255, "F11.1.9", "Overflow Blue clamps to 255")
  assert_eq_int(state, c_over, 4294967295, "F11.1.10", "All-overflow packed integer is 0xFFFFFFFF (4294967295)")

  @! Test 1.3: Boundary channel extraction
  c_boundary = argb_pack(1, 2, 4, 8)
  assert_eq_int(state, argb_get_a(c_boundary), 1, "F11.1.11", "Alpha = 1 extracted")
  assert_eq_int(state, argb_get_r(c_boundary), 2, "F11.1.12", "Red = 2 extracted")
  assert_eq_int(state, argb_get_g(c_boundary), 4, "F11.1.13", "Green = 4 extracted")
  assert_eq_int(state, argb_get_b(c_boundary), 8, "F11.1.14", "Blue = 8 extracted")

  @! --------------------------------------------------------------------------
  @! SECTION 2: Porter-Duff Over Alpha Blend Saturation & Convergence
  @! --------------------------------------------------------------------------
  println("\n--- Section 2: Alpha Blending Saturation & Convergence ---")

  @! Test 2.1: Pure transparent source leaves destination unchanged
  trans_src = argb_pack(0, 255, 0, 0)
  opaque_dst = argb_pack(255, 0, 128, 64)
  res_trans = argb_blend(trans_src, opaque_dst)
  assert_eq_int(state, res_trans, opaque_dst, "F11.2.1", "Alpha=0 src leaves dst identical")

  @! Test 2.2: Pure opaque source completely overrides destination
  opaque_src = argb_pack(255, 200, 100, 50)
  res_opaque = argb_blend(opaque_src, opaque_dst)
  assert_eq_int(state, res_opaque, opaque_src, "F11.2.2", "Alpha=255 src completely overrides dst")

  @! Test 2.3: 100-Pass fractional alpha blend saturation (stressing arithmetic stability)
  current_dst = argb_pack(255, 0, 0, 0) @! Start black
  tint_src = argb_pack(25, 255, 255, 255) @! ~10% white
  pass_i = 0
  @while pass_i < 100
    current_dst = argb_blend(tint_src, current_dst)
    pass_i = pass_i + 1
  @end
  @! After 100 passes of 10% white, red/green/blue channels must saturate near 255 without overflow
  assert_eq_int(state, argb_get_a(current_dst), 255, "F11.2.3", "100-pass blended alpha remains 255")
  assert_true(state, argb_get_r(current_dst) >= 250, "F11.2.4", "100-pass blended red saturates >= 250")
  assert_true(state, argb_get_g(current_dst) >= 250, "F11.2.5", "100-pass blended green saturates >= 250")
  assert_true(state, argb_get_b(current_dst) >= 250, "F11.2.6", "100-pass blended blue saturates >= 250")
  assert_true(state, argb_get_r(current_dst) <= 255, "F11.2.7", "100-pass blended red does not exceed 255")

  @! Test 2.4: Semi-transparent source over semi-transparent destination
  semi_src = argb_pack(128, 255, 0, 0)
  semi_dst = argb_pack(128, 0, 0, 255)
  semi_out = argb_blend(semi_src, semi_dst)
  out_a = argb_get_a(semi_out)
  @! Expected alpha: 128 + (128 * 127)/255 = 191
  assert_true(state, out_a >= 190 && out_a <= 192, "F11.2.8", "Semi over semi alpha composite ~191")

  @! --------------------------------------------------------------------------
  @! SECTION 3: Clipping Stack Invariants, Underflow & Out-of-Bounds Protection
  @! --------------------------------------------------------------------------
  println("\n--- Section 3: Clipping Stack Invariants & Boundary Stress ---")

  c2d = canvas2d_renderer_new(50, 50, 1.0)
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF000000)

  @! Test 3.1: Popping from empty clip stack does not crash and restores full viewport
  c2d = canvas2d_renderer_pop_clip(c2d)
  assert_eq_int(state, c2d.c2d_current_clip[0], 0, "F11.3.1", "Empty pop preserves min_x = 0")
  assert_eq_int(state, c2d.c2d_current_clip[1], 0, "F11.3.2", "Empty pop preserves min_y = 0")
  assert_eq_int(state, c2d.c2d_current_clip[2], 50, "F11.3.3", "Empty pop preserves max_x = width")
  assert_eq_int(state, c2d.c2d_current_clip[3], 50, "F11.3.4", "Empty pop preserves max_y = height")

  @! Test 3.2: 10-Level Deep Nested Clip Stack with shrinking bounds
  depth = 0
  @while depth < 10
    c2d = canvas2d_renderer_push_clip(c2d, depth * 2, depth * 2, 50 - (depth * 4), 50 - (depth * 4))
    depth = depth + 1
  @end
  assert_eq_int(state, c2d.c2d_clip_stack.len(), 10, "F11.3.5", "Clip stack holds 10 frames")
  assert_eq_int(state, c2d.c2d_current_clip[0], 18, "F11.3.6", "Innermost clip min_x = 18")
  assert_eq_int(state, c2d.c2d_current_clip[2], 32, "F11.3.7", "Innermost clip max_x = 32")

  @! Unwind stack completely
  pop_i = 0
  @while pop_i < 10
    c2d = canvas2d_renderer_pop_clip(c2d)
    pop_i = pop_i + 1
  @end
  assert_eq_int(state, c2d.c2d_clip_stack.len(), 0, "F11.3.8", "Clip stack fully unwound to 0")
  assert_eq_int(state, c2d.c2d_current_clip[2], 50, "F11.3.9", "Unwound clip max_x restored to 50")

  @! Test 3.3: Disjoint / Inverted Clip Region Rejection
  @! Push clip completely outside canvas viewport
  c2d = canvas2d_renderer_push_clip(c2d, 100, 100, 50, 50)
  c2d = canvas2d_renderer_draw_rect(c2d, 0, 0, 50, 50, 0xFFFF0000, 0, 0, 0)
  p_center = canvas2d_renderer_get_pixel(c2d, 25, 25)
  assert_eq_int(state, p_center, 0xFF000000, "F11.3.10", "Disjoint clip region blocks all rasterization")
  c2d = canvas2d_renderer_pop_clip(c2d)

  @! --------------------------------------------------------------------------
  @! SECTION 4: 2D Primitives Geometry & Extreme Edge Cases
  @! --------------------------------------------------------------------------
  println("\n--- Section 4: 2D Primitives Geometry Edge Cases ---")

  @! Test 4.1: Degenerate width/height in draw_rect
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF111111)
  c2d = canvas2d_renderer_draw_rect(c2d, 10, 10, 0, 20, 0xFFFFFFFF, 0, 0, 0)
  c2d = canvas2d_renderer_draw_rect(c2d, 10, 10, 20, 0, 0xFFFFFFFF, 0, 0, 0)
  c2d = canvas2d_renderer_draw_rect(c2d, 10, 10, -5, -5, 0xFFFFFFFF, 0, 0, 0)
  p_10 = canvas2d_renderer_get_pixel(c2d, 10, 10)
  assert_eq_int(state, p_10, 0xFF111111, "F11.4.1", "Zero/negative dimensions do not mutate pixels")

  @! Test 4.2: Out-of-bounds pixel drawing (does not crash or corrupt memory)
  c2d = canvas2d_renderer_set_pixel(c2d, -100, 25, 0xFFFFFFFF)
  c2d = canvas2d_renderer_set_pixel(c2d, 25, -100, 0xFFFFFFFF)
  c2d = canvas2d_renderer_set_pixel(c2d, 500, 25, 0xFFFFFFFF)
  c2d = canvas2d_renderer_set_pixel(c2d, 25, 500, 0xFFFFFFFF)
  c2d = canvas2d_renderer_blend_pixel(c2d, -1, -1, 0xFFFFFFFF)
  c2d = canvas2d_renderer_blend_pixel(c2d, 50, 50, 0xFFFFFFFF)
  assert_eq_int(state, canvas2d_renderer_get_pixel(c2d, -1, -1), 0, "F11.4.2", "Get pixel on negative coords returns 0")
  assert_eq_int(state, canvas2d_renderer_get_pixel(c2d, 50, 50), 0, "F11.4.3", "Get pixel on overflow coords returns 0")

  @! Test 4.3: Rounded Rect quadrant corner arithmetic
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF000000)
  @! Draw 20x20 rect at (10,10) with radius 10 (circle inscribed)
  c2d = canvas2d_renderer_draw_rect(c2d, 10, 10, 20, 20, 0xFF00FF00, 0, 0, 10)
  @! Center (20, 20) must be filled
  assert_eq_int(state, canvas2d_renderer_get_pixel(c2d, 20, 20), 0xFF00FF00, "F11.4.4", "Rounded rect center is filled")
  @! Top-left corner (10, 10) should be outside radius 10 circle
  assert_eq_int(state, canvas2d_renderer_get_pixel(c2d, 10, 10), 0xFF000000, "F11.4.5", "Rounded rect top-left corner is clipped")
  @! Top-right corner (29, 10) should be outside
  assert_eq_int(state, canvas2d_renderer_get_pixel(c2d, 29, 10), 0xFF000000, "F11.4.6", "Rounded rect top-right corner is clipped")

  @! Test 4.4: Bresenham Line degenerate cases (single point, reverse slope, vertical, horizontal)
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF000000)
  c2d = canvas2d_renderer_draw_line(c2d, 5, 5, 5, 5, 0xFFFFFFFF) @! Single point
  assert_eq_int(state, canvas2d_renderer_get_pixel(c2d, 5, 5), 0xFFFFFFFF, "F11.4.7", "Single point line drawn")

  c2d = canvas2d_renderer_draw_line(c2d, 40, 40, 10, 10, 0xFFFF0000) @! Reverse diagonal
  assert_eq_int(state, canvas2d_renderer_get_pixel(c2d, 25, 25), 0xFFFF0000, "F11.4.8", "Reverse diagonal midpoint drawn")

  @! Test 4.5: Linear Gradient with edge dimensions
  c2d = canvas2d_renderer_fill_gradient(c2d, 0, 0, 1, 50, 0xFF000000, 0xFFFFFFFF, true)
  assert_eq_int(state, canvas2d_renderer_get_pixel(c2d, 0, 0), 0xFF000000, "F11.4.9", "Vertical 1-width gradient top is black")
  assert_true(state, argb_get_r(canvas2d_renderer_get_pixel(c2d, 0, 25)) > 100, "F11.4.10", "Vertical 1-width gradient mid is gray")

  @! --------------------------------------------------------------------------
  @! SECTION 5: Bitmap Glyph Renderer & Monospace Font Table
  @! --------------------------------------------------------------------------
  println("\n--- Section 5: Monospace Glyph Renderer Stress ---")

  @! Test 5.1: Glyph encoding for unmapped / control characters returns fallback box
  g_ctrl = font_get_glyph_5x7(0) @! NUL
  assert_eq_int(state, g_ctrl[0], 127, "F11.5.1", "Unmapped char returns fallback box [127,...]")
  assert_eq_int(state, g_ctrl[1], 65, "F11.5.2", "Unmapped char returns fallback box column 1")

  @! Test 5.2: Glyph encoding for Space (ASCII 32) is empty
  g_space = font_get_glyph_5x7(32)
  assert_eq_int(state, g_space[0] + g_space[1] + g_space[2] + g_space[3] + g_space[4], 0, "F11.5.3", "Space glyph has 0 bits set")

  @! Test 5.3: Draw text with scale 1 and scale > 1
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF000000)
  c2d = canvas2d_renderer_draw_text(c2d, "X", 10, 10, 7, 0xFFFFFF00) @! scale 1
  assert_true(state, c2d.c2d_draw_call_count > 0, "F11.5.4", "Draw text scale 1 succeeded")

  c2d = canvas2d_renderer_draw_text(c2d, "Z", 20, 20, 14, 0xFFFFFF00) @! scale 2
  assert_true(state, c2d.c2d_draw_call_count > 1, "F11.5.5", "Draw text scale 2 succeeded")

  @! Empty text string does not crash
  c2d = canvas2d_renderer_draw_text(c2d, "", 0, 0, 14, 0xFFFFFFFF)
  assert_true(state, true, "F11.5.6", "Empty text string handled gracefully")

  @! --------------------------------------------------------------------------
  @! SECTION 6: PPM Serialization
  @! --------------------------------------------------------------------------
  println("\n--- Section 6: Netpbm PPM Serializer ---")

  tiny_c2d = canvas2d_renderer_new(2, 2, 1.0)
  tiny_c2d = canvas2d_renderer_begin_frame(tiny_c2d, 0xFFFF0000)
  ppm_out = canvas2d_renderer_to_ppm(tiny_c2d)
  assert_true(state, starts_with(ppm_out, "P3\n2 2\n255\n"), "F11.6.1", "PPM P3 header matches dimensions 2 2")
  assert_true(state, string_contains(ppm_out, "255 0 0"), "F11.6.2", "PPM contains red pixel channel strings")

  println("=================================================================")
  println("F11 Stress Results: " + int_to_str(state.passed) + "/" + int_to_str(state.total) + " passed, " + int_to_str(state.failed) + " failed.")
  @if state.failed == 0
    println("Verdict: F11 CANVAS2D SOFTWARE RASTERIZER FULLY HARDENED")
  @else
    println("Verdict: F11 VULNERABILITIES DETECTED")
  @end
  println("=================================================================")
@end
