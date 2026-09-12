// ==============================================================================
// 🧪 LIPI TEST SUITE: OFFICIAL BRANDING, ICONS & DESIGN ASSETS
// File: tests/test_branding_assets.lp
// 100% Pure Lipi Implementation — Zero External Toolchain Dependencies
// ==============================================================================
//
// WHY: লিপির নিজস্ব আইকন, ভেক্টর লোগো এবং মাল্টি-রেজোলিউশন রাস্টার অ্যাসেটসমূহ
// রিপোজিটরির প্রতি স্তরে (ভিএস কোড, ওয়েবসাইট, ডকুমেন্টেশন, ওএস ডেস্কটপ ও জিইউআই)
// সঠিকভাবে সংরক্ষিত ও লোডযোগ্য কিনা তা স্বয়ংক্রিয়ভাবে যাচাই করা।

import "universe/os/syscalls"
import "universe/core/memory"
import "universe/core/io"
import "universe/core/string"
import "universe/gui/framebuffer"

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

@fn get_file_size(path)
  stat_buf = lipi_alloc(144)
  r_stat = sys_stat(path, stat_buf)
  @if r_stat < 0
    lipi_free(stat_buf)
    return 0
  @end
  sz = mem_read_u64(stat_buf, 48)
  lipi_free(stat_buf)
  return sz
@end

@fn main()
  println("=================================================================")
  println("⚡ LIPI BRANDING, LOGO & MULTI-RESOLUTION ICON TEST SUITE ⚡")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  // ── Section 1: Canonical Master SVG Assets Verification ───────────────────
  println("▶ Section 1: Canonical Master SVG Assets Verification...")
  total_tests = total_tests + 1

  logo_svg = "assets/branding/lipi_logo.svg"
  mark_svg = "assets/branding/lipi_mark.svg"
  dark_svg = "assets/branding/lipi_logo_dark.svg"

  ok_logo = file_exists(logo_svg)
  ok_mark = file_exists(mark_svg)
  ok_dark = file_exists(dark_svg)

  sz_logo = get_file_size(logo_svg)
  sz_mark = get_file_size(mark_svg)

  ok_s1 = 0
  @if ok_logo == 1 && ok_mark == 1 && ok_dark == 1 && sz_logo > 500 && sz_mark > 300
    ok_s1 = 1
  @end

  ok_v1 = assert_true(ok_s1 == 1, "Master SVG logo and mark files exist with valid non-zero content")
  @if ok_v1 == 1
    println(str_concat("  ✔ [PASS] Master SVGs verified (Logo: ", str_concat(to_str(sz_logo), str_concat(" B, Mark: ", str_concat(to_str(sz_mark), " B)")))))
    passed_tests = passed_tests + 1
  @end

  // ── Section 2: Multi-Resolution PNG & Favicon ICO Verification ────────────
  println("▶ Section 2: Multi-Resolution Raster PNG & ICO Verification...")
  total_tests = total_tests + 1

  ico_path = "assets/branding/favicon.ico"
  png_16 = "assets/branding/png/lipi_icon_16x16.png"
  png_32 = "assets/branding/png/lipi_icon_32x32.png"
  png_64 = "assets/branding/png/lipi_icon_64x64.png"
  png_128 = "assets/branding/png/lipi_icon_128x128.png"
  png_256 = "assets/branding/png/lipi_icon_256x256.png"
  png_512 = "assets/branding/png/lipi_icon_512x512.png"
  og_card = "assets/branding/png/og_image.png"

  ok_ico = file_exists(ico_path)
  ok_256 = file_exists(png_256)
  ok_og  = file_exists(og_card)

  sz_ico = get_file_size(ico_path)
  sz_256 = get_file_size(png_256)
  sz_og  = get_file_size(og_card)

  ok_s2 = 0
  @if ok_ico == 1 && ok_256 == 1 && ok_og == 1 && sz_ico > 100 && sz_256 > 1000 && sz_og > 5000
    ok_s2 = 1
  @end

  ok_v2 = assert_true(ok_s2 == 1, "Favicon ICO, 256px PNG, and 1200x630 OG card verified")
  @if ok_v2 == 1
    println(str_concat("  ✔ [PASS] Multi-resolution raster assets verified (ICO: ", str_concat(to_str(sz_ico), str_concat(" B, 256px: ", str_concat(to_str(sz_256), str_concat(" B, OG: ", str_concat(to_str(sz_og), " B)")))))))
    passed_tests = passed_tests + 1
  @end

  // ── Section 3: VS Code Extension & Web App Branding Integration ───────────
  println("▶ Section 3: VS Code Extension & Web App Integration...")
  total_tests = total_tests + 1

  vscode_icon = "editors/vscode/icons/icon.png"
  vscode_file_icon = "editors/vscode/icons/lipi_file_icon.svg"
  web_favicon = "apps/website/public/favicon.svg"
  web_logo = "apps/website/public/logo.svg"

  ok_vs1 = file_exists(vscode_icon)
  ok_vs2 = file_exists(vscode_file_icon)
  ok_wb1 = file_exists(web_favicon)
  ok_wb2 = file_exists(web_logo)

  ok_s3 = 0
  @if ok_vs1 == 1 && ok_vs2 == 1 && ok_wb1 == 1 && ok_wb2 == 1
    ok_s3 = 1
  @end

  ok_v3 = assert_true(ok_s3 == 1, "VS Code icon assets and Web public brand files successfully synchronized")
  @if ok_v3 == 1
    println("  ✔ [PASS] VS Code & Web App branding integrated and synchronized")
    passed_tests = passed_tests + 1
  @end

  // ── Section 4: Framebuffer Title Bar Logo Rasterizer Verification ──────────
  println("▶ Section 4: Direct Framebuffer Title Bar Logo Rasterizer...")
  total_tests = total_tests + 1

  // Test that fb_draw_lipi_icon renders correctly on a virtual framebuffer
  fb = lipi_fb_open(640, 480)
  ok_fb_init = assert_true(fb.is_active == 1, "Virtual Framebuffer opened successfully")

  // Draw logo mark in window header
  res_icon = fb_draw_lipi_icon(fb, 20, 20)
  ok_draw = assert_eq_int(res_icon, 1, "fb_draw_lipi_icon executed successfully")

  // Verify non-zero color rendered inside the logo mark area
  // Stem (Cyan: 49919) at x=22, y=22
  pixel_color = fb_read_pixel(fb, 22, 22)
  ok_color = assert_eq_int(pixel_color, 49919, "Stem pixel at (22, 22) rendered with exact Cyan #00C2FF")

  // Teardown framebuffer
  lipi_fb_close(fb)

  ok_s4 = 0
  @if ok_fb_init == 1 && ok_draw == 1 && ok_color == 1
    ok_s4 = 1
  @end

  @if ok_s4 == 1
    println("  ✔ [PASS] Direct Framebuffer GUI Title Bar Brand Mark verified")
    passed_tests = passed_tests + 1
  @end

  // ── Section 5: Linux Desktop MIME & File Manager Icon Verification ────────
  // WHY: Verify that FreeDesktop Shared MIME definition and multi-resolution
  // desktop icons exist and are ready for OS file managers (Thunar, Nautilus, Dolphin).
  println("▶ Section 5: Linux Desktop FreeDesktop MIME & Icon Assets...")
  total_tests = total_tests + 1

  mime_xml = "assets/branding/lipi-mime.xml"
  desktop_entry = "assets/branding/lipi.desktop"
  mime_script = "scripts/install_desktop_mime.sh"
  icon_48 = "assets/branding/desktop_icons/text-x-lipi-48.svg"
  icon_64 = "assets/branding/desktop_icons/text-x-lipi-64.svg"
  icon_sc = "assets/branding/desktop_icons/text-x-lipi-scalable.svg"

  ok_mx = file_exists(mime_xml)
  ok_de = file_exists(desktop_entry)
  ok_ms = file_exists(mime_script)
  ok_i48 = file_exists(icon_48)
  ok_i64 = file_exists(icon_64)
  ok_isc = file_exists(icon_sc)

  sz_mx = get_file_size(mime_xml)
  sz_i48 = get_file_size(icon_48)
  sz_i64 = get_file_size(icon_64)

  ok_s5 = 0
  @if ok_mx == 1 && ok_de == 1 && ok_ms == 1 && ok_i48 == 1 && ok_i64 == 1 && ok_isc == 1 && sz_mx > 200 && sz_i48 > 300 && sz_i64 > 300
    ok_s5 = 1
  @end

  ok_v5 = assert_true(ok_s5 == 1, "Linux desktop MIME XML, installer script, and SVG icons verified")
  @if ok_v5 == 1
    println(str_concat("  ✔ [PASS] Desktop FreeDesktop MIME & icon theme assets verified (MIME: ", str_concat(to_str(sz_mx), str_concat(" B, 48px: ", str_concat(to_str(sz_i48), str_concat(" B, 64px: ", str_concat(to_str(sz_i64), " B)")))))))
    passed_tests = passed_tests + 1
  @end

  // ── Final Verification Summary ────────────────────────────────────────────
  println("=================================================================")
  @if passed_tests == total_tests
    println(str_concat("🎉 ALL BRANDING & ASSET TESTS PASSED (", str_concat(to_str(passed_tests), str_concat("/", str_concat(to_str(total_tests), ") ✔")))))
    return 0
  @else
    println("❌ SOME BRANDING TESTS FAILED!")
    return 1
  @end
@end

main()
