// ==============================================================================
// 🧪 LIPI TEST SUITE: TILING WINDOW MANAGER & COMPOSITOR
// File: tests/test_tiling_wm.lp
// Standard: Auto-Tiling Layouts & Damage Compositor Verification
// 100% Pure Lipi — Zero External GUI Libraries
// ==============================================================================

import "universe/gui/window_manager"
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

@fn main()
  println("=================================================================")
  println("🖥️ LIPI TILING WINDOW MANAGER & COMPOSITOR TEST SUITE 🖥️")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: Window Manager Canvas Setup ──────────────────────────────────
  println("▶ Section 1: WM Initialization & Canvas Binding...")
  total_tests = total_tests + 1

  fb = lipi_fb_open(1024, 768)
  wm = wm_init(fb, 1024, 768)

  ok_init = assert_true(wm != 0, "Window manager initialized")
  ok_sw = assert_eq_int(wm.screen_w, 1024, "Screen width is 1024")
  ok_sh = assert_eq_int(wm.screen_h, 768, "Screen height is 768")

  @if ok_init == 1 && ok_sw == 1 && ok_sh == 1
    println("  ✔ [PASS] Window Manager canvas bound.")
    passed_tests = passed_tests + 1
  @end

  // ── Section 2: Window Registration & Horizontal Auto-Tiling ─────────────────
  println("▶ Section 2: Dual Window Creation & Horizontal Auto-Tiling...")
  total_tests = total_tests + 1

  wm = wm_create_window(wm, 1, "Lipi Studio")
  wm = wm_create_window(wm, 2, "Lipi Shell")

  ok_wcount = assert_eq_int(wm.windows.len(), 2, "2 windows registered in tiling stack")

  win1 = wm.windows[0]
  win2 = wm.windows[1]

  // With 2 windows in 1024 width: win1 is at (0, 24, 512, 744), win2 is at (512, 24, 512, 744)
  ok_w1_x = assert_eq_int(win1.x, 0, "Win1 X offset is 0")
  ok_w1_w = assert_eq_int(win1.w, 512, "Win1 Width split to 512")
  ok_w2_x = assert_eq_int(win2.x, 512, "Win2 X offset is 512")
  ok_w2_w = assert_eq_int(win2.w, 512, "Win2 Width split to 512")

  @if ok_wcount == 1 && ok_w1_x == 1 && ok_w1_w == 1 && ok_w2_x == 1 && ok_w2_w == 1
    println("  ✔ [PASS] Horizontal auto-tiling calculated perfectly.")
    passed_tests = passed_tests + 1
  @end

  // ── Section 3: Vertical Split Layout Mode Switch ────────────────────────────
  println("▶ Section 3: Vertical Split Layout Switching...")
  total_tests = total_tests + 1

  wm.layout_mode = 2 // Switch to Vertical Split
  wm = wm_recalculate_tiling(wm)

  v_win1 = wm.windows[0]
  v_win2 = wm.windows[1]

  // Usable height = 768 - 24 = 744. Divided by 2 = 372 each.
  ok_v1_y = assert_eq_int(v_win1.y, 24, "V-Win1 Y starts below taskbar at 24")
  ok_v1_h = assert_eq_int(v_win1.h, 372, "V-Win1 Height is 372")
  ok_v2_y = assert_eq_int(v_win2.y, 24 + 372, "V-Win2 Y starts at 396")
  ok_v2_h = assert_eq_int(v_win2.h, 372, "V-Win2 Height is 372")

  @if ok_v1_y == 1 && ok_v1_h == 1 && ok_v2_y == 1 && ok_v2_h == 1
    println("  ✔ [PASS] Vertical tiling geometry verified.")
    passed_tests = passed_tests + 1
  @end

  // ── Section 4: Damage-Tracked Composition & Frame Flip ──────────────────────
  println("▶ Section 4: Damage-Tracked Composition & Tear-Free Flip...")
  total_tests = total_tests + 1

  // Both windows are currently dirty = 1
  rendered = wm_composite_frame(wm)
  ok_rend = assert_eq_int(rendered, 2, "2 dirty windows composited to framebuffer")

  // Windows should now be clean (dirty = 0)
  c_win1 = wm.windows[0]
  c_win2 = wm.windows[1]
  ok_clean1 = assert_eq_int(c_win1.dirty, 0, "Win1 marked clean after composite")
  ok_clean2 = assert_eq_int(c_win2.dirty, 0, "Win2 marked clean after composite")

  // Next composite should redraw 0 windows because nothing is dirty
  zero_rend = wm_composite_frame(wm)
  ok_zero = assert_eq_int(zero_rend, 0, "Zero-redraw achieved when damage buffer clean")

  @if ok_rend == 1 && ok_clean1 == 1 && ok_clean2 == 1 && ok_zero == 1
    println("  ✔ [PASS] Damage tracking & clean compositing verified.")
    passed_tests = passed_tests + 1
  @end

  // Cleanup
  lipi_fb_close(fb)

  println("-----------------------------------------------------------------")
  summary = str_concat("RESULTS: ", str_concat(to_str(passed_tests), str_concat("/", str_concat(to_str(total_tests), " sections passed."))))
  println(summary)
  @if passed_tests == total_tests
    println("🎉 ALL TILING WINDOW MANAGER TESTS PASSED!")
    return 0
  @end
  return 1
@end

main()
