@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — NATIVE GUI ENGINE TEST SUITE
@! File: tests/gui/test_gui_engine.maya
@! Milestone: 4, 5, 6 — Native GUI Rasterizer & Verification
@! 100% Pure Maya Architecture — Zero External Dependencies
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/core/string"
import "universe/sys/syscalls"
import "universe/gui/canvas"
import "universe/gui/font"

@! ============================================================================
@! ASSERTION FRAMEWORK HELPERS
@! ============================================================================

@fn assert_true(cond: i64, msg: string) -> i64
  @if cond == 0
    println(str_concat("  [FAIL] Assertion failed (expected true): ", msg))
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual: i64, expected: i64, msg: string) -> i64
  @if actual != expected
    println(str_concat("  [FAIL] ", str_concat(msg, str_concat(" -> Expected ", str_concat(to_str(expected), str_concat(", got ", to_str(actual)))))))
    return 0
  @end
  return 1
@end

@! ============================================================================
@! TEST SUITE RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🎨 MAYA NATIVE GUI RASTERIZER & FRAMEBUFFER TEST SUITE 🎨")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! TEST 1: Framebuffer RGBA memory buffer allocation via raw syscall mmap
  @! ----------------------------------------------------------------------------
  println("▶ Test 1: Framebuffer RGBA Memory Buffer Allocation via raw syscall mmap...")
  
  @! WHY: 320x240 @ 32bpp requires pitch = 1280 bytes, total size = 307,200 bytes.
  @! Allocated directly from the Linux kernel using sys_mmap (Syscall 9).
  fb = framebuffer_new(320, 240)
  total_tests = total_tests + 1
  ok_w = assert_eq_int(fb.width, 320, "Framebuffer width == 320")
  ok_h = assert_eq_int(fb.height, 240, "Framebuffer height == 240")
  ok_p = assert_eq_int(fb.pitch, 1280, "Framebuffer pitch == 1280 (320 * 4)")
  ok_b = assert_eq_int(fb.bpp, 32, "Framebuffer bpp == 32")
  ok_s = assert_eq_int(fb.size, 307200, "Framebuffer byte size == 307200")
  ok_ptr = assert_true(fb.buffer > 0, "Framebuffer buffer pointer is valid virtual address")
  
  @if ok_w == 1 && ok_h == 1 && ok_p == 1 && ok_b == 1 && ok_s == 1 && ok_ptr == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Framebuffer 320x240x32bpp mmap allocation verified")
  @end

  @! Pixel read and write on raw mmap buffer
  total_tests = total_tests + 1
  w_ok = framebuffer_set_pixel(fb, 50, 60, 0x11223344)
  p_val = framebuffer_get_pixel(fb, 50, 60)
  ok_p1 = assert_eq_int(w_ok, 1, "Pixel write succeeded inside bounds")
  ok_p2 = assert_eq_int(p_val, 0x11223344, "Pixel read matches exact 32-bit RGBA value written")
  @if ok_p1 == 1 && ok_p2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Raw mmap pixel read/write roundtrip verified")
  @end

  @! Out of bounds boundary clamps on mmap buffer
  total_tests = total_tests + 1
  oob_neg_w = framebuffer_set_pixel(fb, 0 - 5, 60, 0xFFFFFFFF)
  oob_neg_r = framebuffer_get_pixel(fb, 0 - 5, 60)
  oob_pos_w = framebuffer_set_pixel(fb, 325, 60, 0xFFFFFFFF)
  oob_pos_r = framebuffer_get_pixel(fb, 325, 60)
  ok_oob1 = assert_eq_int(oob_neg_w, 0, "Negative X pixel write safely rejected")
  ok_oob2 = assert_eq_int(oob_neg_r, 0, "Negative X pixel read safely returns 0")
  ok_oob3 = assert_eq_int(oob_pos_w, 0, "Out-of-bounds X pixel write safely rejected")
  ok_oob4 = assert_eq_int(oob_pos_r, 0, "Out-of-bounds X pixel read safely returns 0")
  @if ok_oob1 == 1 && ok_oob2 == 1 && ok_oob3 == 1 && ok_oob4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Memory boundary safety clamps verified")
  @end

  @! Framebuffer clear and munmap release
  total_tests = total_tests + 1
  fb = framebuffer_clear(fb, 0x00AABBCC)
  p_c0 = framebuffer_get_pixel(fb, 0, 0)
  p_c1 = framebuffer_get_pixel(fb, 319, 239)
  p_c2 = framebuffer_get_pixel(fb, 160, 120)
  ok_clr0 = assert_eq_int(p_c0, 0x00AABBCC, "Top-left pixel cleared correctly")
  ok_clr1 = assert_eq_int(p_c1, 0x00AABBCC, "Bottom-right pixel cleared correctly")
  ok_clr2 = assert_eq_int(p_c2, 0x00AABBCC, "Center pixel cleared correctly")
  
  @! Unmap allocated pages via sys_munmap (Syscall 11)
  unmap_res = framebuffer_free(fb)
  ok_unmap = assert_eq_int(unmap_res, 0, "sys_munmap returned 0 (clean deallocation)")
  @if ok_clr0 == 1 && ok_clr1 == 1 && ok_clr2 == 1 && ok_unmap == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Framebuffer clear and kernel munmap deallocation verified")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 2: Bresenham 2D Line Drawing algorithm pixel rasterization
  @! ----------------------------------------------------------------------------
  println("▶ Test 2: Bresenham 2D Line Drawing Algorithm Pixel Rasterization...")
  
  c = canvas_new(100, 100)
  c = canvas_clear(c, 0)

  @! 2.1 Horizontal Bresenham Line (x0=10, y0=20) -> (x1=40, y1=20)
  total_tests = total_tests + 1
  c = canvas_draw_line(c, 10, 20, 40, 20, 0xFFFF0000)
  p_start = canvas_get_pixel(c, 10, 20)
  p_mid   = canvas_get_pixel(c, 25, 20)
  p_end   = canvas_get_pixel(c, 40, 20)
  p_above = canvas_get_pixel(c, 25, 19)
  p_below = canvas_get_pixel(c, 25, 21)
  ok_h1 = assert_eq_int(p_start, 0xFFFF0000, "Horizontal line start pixel colored")
  ok_h2 = assert_eq_int(p_mid, 0xFFFF0000, "Horizontal line midpoint pixel colored")
  ok_h3 = assert_eq_int(p_end, 0xFFFF0000, "Horizontal line end pixel colored")
  ok_h4 = assert_eq_int(p_above, 0, "Adjacent pixel above line is uncolored")
  ok_h5 = assert_eq_int(p_below, 0, "Adjacent pixel below line is uncolored")
  @if ok_h1 == 1 && ok_h2 == 1 && ok_h3 == 1 && ok_h4 == 1 && ok_h5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Horizontal Bresenham line rasterization verified")
  @end

  @! 2.2 Vertical Bresenham Line (x0=60, y0=10) -> (x1=60, y1=50)
  total_tests = total_tests + 1
  c = canvas_draw_line(c, 60, 10, 60, 50, 0xFF00FF00)
  p_v_start = canvas_get_pixel(c, 60, 10)
  p_v_mid   = canvas_get_pixel(c, 60, 30)
  p_v_end   = canvas_get_pixel(c, 60, 50)
  p_v_left  = canvas_get_pixel(c, 59, 30)
  p_v_right = canvas_get_pixel(c, 61, 30)
  ok_v1 = assert_eq_int(p_v_start, 0xFF00FF00, "Vertical line start pixel colored")
  ok_v2 = assert_eq_int(p_v_mid, 0xFF00FF00, "Vertical line midpoint pixel colored")
  ok_v3 = assert_eq_int(p_v_end, 0xFF00FF00, "Vertical line end pixel colored")
  ok_v4 = assert_eq_int(p_v_left, 0, "Adjacent pixel left of line is uncolored")
  ok_v5 = assert_eq_int(p_v_right, 0, "Adjacent pixel right of line is uncolored")
  @if ok_v1 == 1 && ok_v2 == 1 && ok_v3 == 1 && ok_v4 == 1 && ok_v5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Vertical Bresenham line rasterization verified")
  @end

  @! 2.3 Diagonal 45-degree Bresenham Line (x0=0, y0=0) -> (x1=30, y1=30)
  total_tests = total_tests + 1
  c = canvas_draw_line(c, 0, 0, 30, 30, 0xFF0000FF)
  p_d0  = canvas_get_pixel(c, 0, 0)
  p_d15 = canvas_get_pixel(c, 15, 15)
  p_d30 = canvas_get_pixel(c, 30, 30)
  p_d_off = canvas_get_pixel(c, 15, 16)
  ok_d1 = assert_eq_int(p_d0, 0xFF0000FF, "Diagonal line start (0,0) colored")
  ok_d2 = assert_eq_int(p_d15, 0xFF0000FF, "Diagonal line midpoint (15,15) colored")
  ok_d3 = assert_eq_int(p_d30, 0xFF0000FF, "Diagonal line end (30,30) colored")
  ok_d4 = assert_eq_int(p_d_off, 0, "Off-diagonal pixel (15,16) untouched")
  @if ok_d1 == 1 && ok_d2 == 1 && ok_d3 == 1 && ok_d4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Diagonal Bresenham line rasterization verified")
  @end

  @! 2.4 Arbitrary Octant Negative Slope Bresenham Line (x0=30, y0=0) -> (x1=0, y1=30)
  total_tests = total_tests + 1
  c = canvas_draw_line(c, 30, 0, 0, 30, 0xFFFFFF00)
  p_rev0  = canvas_get_pixel(c, 30, 0)
  p_rev15 = canvas_get_pixel(c, 15, 15)
  p_rev30 = canvas_get_pixel(c, 0, 30)
  ok_r1 = assert_eq_int(p_rev0, 0xFFFFFF00, "Negative slope start (30,0) colored")
  ok_r2 = assert_eq_int(p_rev15, 0xFFFFFF00, "Negative slope intersection (15,15) colored")
  ok_r3 = assert_eq_int(p_rev30, 0xFFFFFF00, "Negative slope end (0,30) colored")
  @if ok_r1 == 1 && ok_r2 == 1 && ok_r3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Negative slope Bresenham line rasterization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 3: Filled Rectangle and Box rendering with clipping bounds
  @! ----------------------------------------------------------------------------
  println("▶ Test 3: Filled Rectangle & Box Rendering with Clipping Bounds...")

  @! 3.1 Unclipped Hollow Box (x=10, y=10, w=30, h=20)
  c = canvas_clear(c, 0)
  total_tests = total_tests + 1
  c = canvas_draw_rect(c, 10, 10, 30, 20, 0xFFAABB00)
  b_tl = canvas_get_pixel(c, 10, 10)
  b_tr = canvas_get_pixel(c, 39, 10)
  b_bl = canvas_get_pixel(c, 10, 29)
  b_br = canvas_get_pixel(c, 39, 29)
  b_interior = canvas_get_pixel(c, 25, 20)
  ok_b1 = assert_eq_int(b_tl, 0xFFAABB00, "Box top-left border colored")
  ok_b2 = assert_eq_int(b_tr, 0xFFAABB00, "Box top-right border colored")
  ok_b3 = assert_eq_int(b_bl, 0xFFAABB00, "Box bottom-left border colored")
  ok_b4 = assert_eq_int(b_br, 0xFFAABB00, "Box bottom-right border colored")
  ok_b5 = assert_eq_int(b_interior, 0, "Box interior remains hollow (0)")
  @if ok_b1 == 1 && ok_b2 == 1 && ok_b3 == 1 && ok_b4 == 1 && ok_b5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Hollow rectangle box outline rendering verified")
  @end

  @! 3.2 Filled Rectangle with Clipping Window Enforced
  @! Canvas size 100x100. Push clip window: [20..60, 20..60] (x=20, y=20, w=40, h=40).
  @! Draw large filled rect: [0..90, 0..90] (x=0, y=0, w=90, h=90) with color 0xFF336699.
  total_tests = total_tests + 1
  c = canvas_clear(c, 0)
  c = canvas_push_clip(c, 20, 20, 40, 40)
  c = canvas_fill_rect(c, 0, 0, 90, 90, 0xFF336699)

  @! Pixels inside clip window [20..59, 20..59] must be filled
  p_in_tl = canvas_get_pixel(c, 20, 20)
  p_in_mid= canvas_get_pixel(c, 40, 40)
  p_in_br = canvas_get_pixel(c, 59, 59)
  ok_in1 = assert_eq_int(p_in_tl, 0xFF336699, "Inside clip window top-left (20,20) colored")
  ok_in2 = assert_eq_int(p_in_mid, 0xFF336699, "Inside clip window center (40,40) colored")
  ok_in3 = assert_eq_int(p_in_br, 0xFF336699, "Inside clip window bottom-right (59,59) colored")

  @! Pixels outside clip window must be completely untouched (0)
  p_out_tl = canvas_get_pixel(c, 10, 10)
  p_out_tr = canvas_get_pixel(c, 70, 10)
  p_out_bl = canvas_get_pixel(c, 10, 70)
  p_out_br = canvas_get_pixel(c, 70, 70)
  ok_out1 = assert_eq_int(p_out_tl, 0, "Outside clip window top-left (10,10) untouched")
  ok_out2 = assert_eq_int(p_out_tr, 0, "Outside clip window top-right (70,10) untouched")
  ok_out3 = assert_eq_int(p_out_bl, 0, "Outside clip window bottom-left (10,70) untouched")
  ok_out4 = assert_eq_int(p_out_br, 0, "Outside clip window bottom-right (70,70) untouched")

  @! Pop clip rect and verify root bounds restored
  c = canvas_pop_clip(c)
  ok_pop_min = assert_eq_int(c.current_clip.min_x, 0, "Popped clip restores root min_x == 0")
  ok_pop_max = assert_eq_int(c.current_clip.max_x, 100, "Popped clip restores root max_x == 100")

  @if ok_in1 == 1 && ok_in2 == 1 && ok_in3 == 1 && ok_out1 == 1 && ok_out2 == 1 && ok_out3 == 1 && ok_out4 == 1 && ok_pop_min == 1 && ok_pop_max == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Filled rectangle rendering with clipping bounds verified")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST 4: Bitmap Font glyph rasterization for pure Maya text rendering
  @! ----------------------------------------------------------------------------
  println("▶ Test 4: Bitmap Font Glyph Rasterization for Pure Maya Text Rendering...")

  f = font_default()
  total_tests = total_tests + 1
  ok_fw = assert_eq_int(f.char_width, 8, "Default font char_width == 8")
  ok_fh = assert_eq_int(f.char_height, 16, "Default font char_height == 16")
  ok_fb = assert_eq_int(f.baseline, 12, "Default font baseline == 12")

  @! Text measurement calculation
  sz_maya = font_measure_text(f, "MAYA")
  sz_empty = font_measure_text(f, "")
  ok_m1 = assert_eq_int(sz_maya.width, 32, "String 'MAYA' 4 chars width == 32 (4 * 8)")
  ok_m2 = assert_eq_int(sz_maya.height, 16, "String 'MAYA' height == 16")
  ok_m3 = assert_eq_int(sz_empty.width, 0, "Empty string width == 0")

  @if ok_fw == 1 && ok_fh == 1 && ok_fb == 1 && ok_m1 == 1 && ok_m2 == 1 && ok_m3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Bitmap font metrics & string measurement verified")
  @end

  @! Glyph bitmask pattern lookup for ASCII characters
  total_tests = total_tests + 1
  @! Character 'A' (ASCII 65): middle crossbar row has non-zero bitmask
  row_bits_a = font_get_glyph_row(65, 7)
  @! Character ' ' (ASCII 32): space has 0 bitmask on all rows
  row_bits_sp = font_get_glyph_row(32, 7)
  ok_bits_a = assert_true(row_bits_a > 0, "Glyph 'A' has valid stroke bitmask pattern")
  ok_bits_sp = assert_eq_int(row_bits_sp, 0, "Glyph ' ' space has empty bitmask")
  @if ok_bits_a == 1 && ok_bits_sp == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Monospace bitmap font glyph bitmask lookup verified")
  @end

  @! Glyph text rasterization on Canvas
  total_tests = total_tests + 1
  c = canvas_clear(c, 0)
  c = font_draw_text(c, f, 10, 10, "MAYA", 0xFFFFFFFF)

  @! First glyph 'M' starts at x=10..17, y=10..25.
  @! Ensure stroke pixels are drawn within bounding box and outside is 0.
  has_stroke = 0
  cy = 10
  @while cy < 26
    cx = 10
    @while cx < 42
      @if canvas_get_pixel(c, cx, cy) == 0xFFFFFFFF
        has_stroke = 1
      @end
      cx = cx + 1
    @end
    cy = cy + 1
  @end

  p_before_x = canvas_get_pixel(c, 5, 15)
  p_after_y  = canvas_get_pixel(c, 15, 30)

  ok_stroke = assert_eq_int(has_stroke, 1, "Rendered text contains valid glyph stroke pixels")
  ok_pad_x  = assert_eq_int(p_before_x, 0, "Pixel before text start is untouched")
  ok_pad_y  = assert_eq_int(p_after_y, 0, "Pixel below text baseline is untouched")

  @if ok_stroke == 1 && ok_pad_x == 1 && ok_pad_y == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Pure Maya bitmap font glyph rasterization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! TEST SUMMARY
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  @if passed_tests == total_tests
    println(str_concat("🎉 ALL GUI ENGINE TESTS PASSED: ", str_concat(to_str(passed_tests), str_concat("/", to_str(total_tests)))))
    println("=================================================================")
    return 0
  @else
    println(str_concat("❌ TESTS FAILED: ", str_concat(to_str(passed_tests), str_concat("/", to_str(total_tests)))))
    println("=================================================================")
    return 1
  @end
@end
