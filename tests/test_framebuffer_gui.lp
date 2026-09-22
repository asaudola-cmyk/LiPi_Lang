// ==============================================================================
// 🧪 LIPI TEST SUITE: DIRECT LINUX FRAMEBUFFER ZERO-DEPENDENCY GUI ENGINE
// File: tests/test_framebuffer_gui.lp
// 100% Pure Lipi Implementation — Zero External / GUI Libraries
// ==============================================================================

import "universe/gui/framebuffer"
import "universe/core/string"

@fn assert_true(cond, msg)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn main()
  println("=================================================================")
  println("⚡ LIPI DIRECT FRAMEBUFFER GUI ENGINE TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: Framebuffer Initialization & Stride Invariants ─────────────
  println("▶ Section 1: Framebuffer Initialization & Hardware Stride...")
  total_tests = total_tests + 1

  fb = lipi_fb_open(800, 600)
  ok1 = assert_true(fb != 0, "Framebuffer structure allocated")
  ok2 = assert_eq_int(fb.width, 800, "Width is 800")
  ok3 = assert_eq_int(fb.height, 600, "Height is 600")
  ok4 = assert_true(fb.line_length >= 3200, "Hardware stride line_length >= 800 * 4")
  ok5 = assert_true(fb.back_ptr > 0, "Double-buffered backbuffer allocated")

  if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    println("  ✔ [PASS] Framebuffer opened (Virtual VFB: " + to_str(fb.is_virtual) + ", Stride: " + to_str(fb.line_length) + " bytes)")
    passed_tests = passed_tests + 1
  end

  // ── Section 2: Pixel Rasterization & Boundary Stride Verification ──────────
  println("▶ Section 2: Pixel Rasterization & Stride Math...")
  total_tests = total_tests + 1

  col_gold = 16766720 // 0x00FFD700 (Gold)
  fb_draw_pixel(fb, 120, 80, col_gold)
  read_col = fb_read_pixel(fb, 120, 80)
  ok_px = assert_eq_int(read_col, col_gold, "Pixel readback matches written color")

  // Test clipping bounds: drawing outside bounds returns 0 without crashing
  clip_res = fb_draw_pixel(fb, 9999, 9999, col_gold)
  ok_clip = assert_eq_int(clip_res, 0, "Out of bounds pixel drawing safely clipped")

  if ok_px == 1 && ok_clip == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Direct pixel rasterization and clipping verified")
  end

  // ── Section 3: Window Chrome & Widget Controls ────────────────────────────
  println("▶ Section 3: Window Chrome & Widget Construction...")
  total_tests = total_tests + 1

  // Draw modern window at (50, 50, 300, 200)
  win_res = fb_window_create(fb, 50, 50, 300, 200, "Lipi Sovereign Terminal")
  ok_win1 = assert_eq_int(win_res, 1, "Window creation succeeded")

  // Verify close button pixel color at (50 + 300 - 10, 50 + 10) is red
  close_col = fb_read_pixel(fb, 335, 58)
  ok_win2 = assert_eq_int(close_col, 15961000, "Close button red pixel rendered")

  // Draw button widget inside window
  btn_res = fb_button_create(fb, 80, 100, 120, 32, "Run Kernel", 0)
  ok_btn = assert_eq_int(btn_res, 1, "Button creation succeeded")

  if ok_win1 == 1 && ok_win2 == 1 && ok_btn == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Window chrome and button controls rasterized successfully")
  end

  // ── Section 4: Double-Buffer Page Flip & Clean Teardown ────────────────────
  println("▶ Section 4: Double-Buffer Page Flip & Clean Teardown...")
  total_tests = total_tests + 1

  flip_res = fb_flip(fb)
  ok_fl1 = assert_eq_int(flip_res, 1, "Page flip succeeded")

  // Read pixel from frontbuffer to verify blit transferred memory
  front_px_off = (80 * fb.line_length) + (120 * 4)
  front_col = mem_read_u32(fb.front_ptr, front_px_off)
  ok_fl2 = assert_eq_int(front_col, 2002734, "Frontbuffer received backbuffer window pixel via blit")

  cl_res = lipi_fb_close(fb)
  ok_fl3 = assert_eq_int(cl_res, 1, "Framebuffer closed cleanly")

  if ok_fl1 == 1 && ok_fl2 == 1 && ok_fl3 == 1
    passed_tests = passed_tests + 1
    println("  ✔ [PASS] Double-buffer page flip and resource teardown verified")
  end

  println("=================================================================")
  if passed_tests == total_tests
    println("🎉 ALL DIRECT FRAMEBUFFER GUI TESTS PASSED (4/4) ✔")
    return 0
  else
    println("❌ SOME FRAMEBUFFER TESTS FAILED!")
    return 1
  end
@end

main()
