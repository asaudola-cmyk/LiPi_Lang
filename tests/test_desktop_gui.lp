// ==============================================================================
// 🧪 LIPI TEST SUITE: SOVEREIGN DESKTOP GUI & FRAMEBUFFER SHELL
// File: tests/test_desktop_gui.lp
// Standard: Direct Linear Framebuffer (1024x768) Window Chrome & Compositor
// 100% Pure Lipi Implementation — Zero External / GUI Libraries
// ==============================================================================

import "universe/gui/framebuffer"
import "universe/core/string"

@fn assert_true(cond: i64, msg: string)
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed: ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string)
  @if actual != expected
    s_act = to_str(actual)
    s_exp = to_str(expected)
    err = str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(s_exp, str_concat(", got ", s_act)))))
    println(err)
    return 0
  @end
  return 1
@end

@fn color_rgb(r: i64, g: i64, b: i64)
  return ((r % 256) * 65536) + ((g % 256) * 256) + (b % 256)
@end

@fn draw_mouse_cursor(fb, cx: i64, cy: i64)
  white = color_rgb(255, 255, 255)
  black = color_rgb(0, 0, 0)
  
  i = 0
  @while i < 16
    j = 0
    @while j <= i && j < 12
      @if j == 0 || j == i || (i == 11 && j <= 8) || (j == 8 && i >= 11)
        fb_draw_pixel(fb, cx + j, cy + i, black)
      @else
        fb_draw_pixel(fb, cx + j, cy + i, white)
      @end
      j = j + 1
    @end
    i = i + 1
  @end
  return 0
@end

@fn main()
  println("=================================================================")
  println("🖥️ LIPI BARE-METAL DESKTOP GUI & SHELL TEST SUITE 🖥️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: 1024x768 Desktop Canvas & Stride Verification ────────────────
  println("▶ Section 1: Desktop Framebuffer Canvas (1024x768x32bpp)...")
  total_tests = total_tests + 1

  fb = lipi_fb_open(1024, 768)
  ok_alloc = assert_true(fb != 0, "Canvas allocation")
  ok_w = assert_eq_int(fb.width, 1024, "Desktop width 1024")
  ok_h = assert_eq_int(fb.height, 768, "Desktop height 768")
  ok_stride = assert_true(fb.line_length >= 4096, "Desktop pitch stride >= 4096 bytes")

  @if ok_alloc == 1 && ok_w == 1 && ok_h == 1 && ok_stride == 1
    println("  ✔ [PASS] 1024x768 Desktop Canvas initialized.")
    passed_tests = passed_tests + 1
  @end

  // ── Section 2: Window Chrome & Composite Controls ───────────────────────────
  println("▶ Section 2: Window Chrome & Header Close Button...")
  total_tests = total_tests + 1

  // Create Window at (100, 100), width 400, height 300
  win_ok = fb_window_create(fb, 100, 100, 400, 300, "Lipi Terminal")
  ok_win = assert_eq_int(win_ok, 1, "Window chrome created")

  // Verify Header color (Mantle: 1579045 = 0x00181825)
  hdr_col = fb_read_pixel(fb, 150, 110)
  ok_hdr = assert_eq_int(hdr_col, 1579045, "Window header background matches Mantle color")

  // Verify Close button at ((100+400)-18, 100+6) = (482, 106)
  // Close color: 15961000 = 0x00F38BA8
  close_col = fb_read_pixel(fb, 485, 110)
  ok_close = assert_eq_int(close_col, 15961000, "Close button matches Red accent")

  @if ok_win == 1 && ok_hdr == 1 && ok_close == 1
    println("  ✔ [PASS] Window chrome and controls verified.")
    passed_tests = passed_tests + 1
  @end

  // ── Section 3: Button Widget & Pressed State ────────────────────────────────
  println("▶ Section 3: Interactive Button Widget States...")
  total_tests = total_tests + 1

  btn_norm = fb_button_create(fb, 120, 340, 100, 30, "OK", 0)
  col_norm = fb_read_pixel(fb, 130, 350)
  ok_norm = assert_eq_int(col_norm, 3289650, "Normal button background color")

  btn_press = fb_button_create(fb, 240, 340, 100, 30, "Cancel", 1)
  col_press = fb_read_pixel(fb, 250, 350)
  ok_press = assert_eq_int(col_press, 5592405, "Pressed button background color")

  @if ok_norm == 1 && ok_press == 1
    println("  ✔ [PASS] UI Button states verified.")
    passed_tests = passed_tests + 1
  @end

  // ── Section 4: Mouse Cursor Rasterization & Page Flip ──────────────────────
  println("▶ Section 4: Hardware Cursor Rasterization & Tear-Free Flip...")
  total_tests = total_tests + 1

  // Draw cursor at (500, 400)
  draw_mouse_cursor(fb, 500, 400)
  col_cursor_edge = fb_read_pixel(fb, 500, 400) // (0,0) is black outline
  col_cursor_body = fb_read_pixel(fb, 501, 402) // interior is white
  
  black = color_rgb(0, 0, 0)
  white = color_rgb(255, 255, 255)
  ok_c_edge = assert_eq_int(col_cursor_edge, black, "Cursor edge is black outline")
  ok_c_body = assert_eq_int(col_cursor_body, white, "Cursor body is white fill")

  // Perform Double-Buffer Flip
  flip_ok = fb_flip(fb)
  ok_flip = assert_eq_int(flip_ok, 1, "Double-buffer page flip completed")

  @if ok_c_edge == 1 && ok_c_body == 1 && ok_flip == 1
    println("  ✔ [PASS] Cursor rasterization & page flip verified.")
    passed_tests = passed_tests + 1
  @end

  // Cleanup
  lipi_fb_close(fb)

  println("-----------------------------------------------------------------")
  summary = str_concat("RESULTS: ", str_concat(to_str(passed_tests), str_concat("/", str_concat(to_str(total_tests), " sections passed."))))
  println(summary)
  @if passed_tests == total_tests
    println("🎉 ALL DESKTOP GUI & SHELL TESTS PASSED!")
    return 0
  @end
  return 1
@end

main()
