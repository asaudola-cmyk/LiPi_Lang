// ==============================================================================
// 🧪 LIPI TEST SUITE: DIRECT DRM/KMS HARDWARE GRAPHICS & MODESETTING
// File: tests/test_drm_kms_direct.lp
// Standard: Linux DRM / KMS Subsystem & Dumb Buffer Modesetting ABI
// 100% Pure Lipi — Zero External / C / Libc / X11 / Wayland Dependencies
// ==============================================================================

include "universe/gui/drm_kms.lp"
include "universe/gui/fbdev.lp"

fn assert_true cond msg
    if cond == 0
        say "  ❌ [FAIL] Assertion failed: " + msg
        exit(1)
    say "  ✔ [PASS] " + msg

fn assert_eq_int actual expected msg
    if actual != expected
        say "  ❌ [FAIL] " + msg + " (Expected " + str(expected) + ", got " + str(actual) + ")"
        exit(1)
    say "  ✔ [PASS] " + msg

fn main
    say "================================================================="
    say "⚡ LIPI DIRECT DRM/KMS & FRAMEBUFFER HARDWARE GRAPHICS SUITE ⚡"
    say "================================================================="

    total_tests = 0
    passed_tests = 0

    // ── Section 1: Direct DRM/KMS Device Controller & Modesetting Probe ───────
    say "▶ Section 1: Direct DRM/KMS Controller & Modesetting Discovery..."
    total_tests = total_tests + 1

    dev = drm_kms_device_new(3, 34, 42)
    assert_true(dev != 0, "DrmKmsDevice allocated")
    assert_eq_int(dev.kd_fd, 3, "Device file descriptor bound")
    assert_eq_int(dev.kd_crtc_id, 34, "CRTC ID bound")
    assert_eq_int(dev.kd_connector_id, 42, "Connector ID bound")

    mode = drm_kms_probe_display(dev)
    assert_true(mode != 0, "DrmModeInfo probed successfully")
    assert_eq_int(mode.mi_width, 1920, "1080p horizontal resolution (1920)")
    assert_eq_int(mode.mi_height, 1080, "1080p vertical resolution (1080)")
    assert_eq_int(mode.mi_refresh_hz, 60, "VESA 60Hz refresh rate")
    passed_tests = passed_tests + 1

    // ── Section 2: VRAM Dumb Buffer Memory Layout & Pitch Alignment ───────────
    say "\n▶ Section 2: Dumb Buffer Hardware Allocation & Memory Pitch..."
    total_tests = total_tests + 1

    front = dev.kd_front_buffer
    back = dev.kd_back_buffer
    assert_true(front != 0, "Front dumb buffer created")
    assert_true(back != 0, "Back dumb buffer created")
    assert_eq_int(front.db_pitch, 1920 * 4, "Front buffer 32-bit ARGB pitch (7680 bytes/row)")
    assert_eq_int(back.db_pitch, 1920 * 4, "Back buffer 32-bit ARGB pitch (7680 bytes/row)")
    assert_eq_int(front.db_handle, 1001, "Front buffer GPU handle (1001)")
    assert_eq_int(back.db_handle, 1002, "Back buffer GPU handle (1002)")
    assert_true(front.db_mmap_ptr > 0, "Front buffer memory pointer mapped")
    assert_true(back.db_mmap_ptr > 0, "Back buffer memory pointer mapped")
    passed_tests = passed_tests + 1

    // ── Section 3: Damage Rect Rasterization & Pixel Clipping ─────────────────
    say "\n▶ Section 3: Damage Rect Rasterization & Viewport Bounds Clipping..."
    total_tests = total_tests + 1

    raster = drm_pixel_raster_new(1920, 1080, front.db_pitch)
    raster.pr_buffer_ptr = back.db_mmap_ptr

    // Render 100x50 rectangle inside bounds
    col_cyan = 4278255615 // 0xFF00FFFF (Cyan)
    rendered = drm_fill_rect(raster, 100, 100, 100, 50, col_cyan)
    assert_eq_int(rendered, 5000, "Inside bounds: rendered 5,000 pixels")
    assert_eq_int(raster.pr_damage_rect_count, 1, "Damage rectangle count incremented")

    // Test clipping: partial rectangle crossing right screen boundary
    // Start at x=1900, w=50 -> inside is 20 pixels wide, h=10 -> 200 pixels rendered
    clipped = drm_fill_rect(raster, 1900, 50, 50, 10, col_cyan)
    assert_eq_int(clipped, 200, "Boundary clipping: rendered 200 visible pixels")

    // Test out of bounds: entirely outside viewport
    oob = drm_fill_rect(raster, 2000, 2000, 100, 100, col_cyan)
    assert_eq_int(oob, 0, "Out-of-bounds fill cleanly clipped (0 pixels)")
    passed_tests = passed_tests + 1

    // ── Section 4: Hardware Double Buffering & Tear-Free Page Flipping ────────
    say "\n▶ Section 4: Hardware Double Buffering & Atomic Page Flip..."
    total_tests = total_tests + 1

    // Initial front is handle 1001, back is handle 1002
    assert_eq_int(dev.kd_front_buffer.db_handle, 1001, "Pre-flip front handle is 1001")
    assert_eq_int(dev.kd_back_buffer.db_handle, 1002, "Pre-flip back handle is 1002")

    // Flip 1
    flip_res = drm_kms_page_flip(dev)
    assert_eq_int(flip_res, 1, "Page flip 1 succeeded")
    assert_eq_int(dev.kd_front_buffer.db_handle, 1002, "Post-flip front handle swapped to 1002")
    assert_eq_int(dev.kd_back_buffer.db_handle, 1001, "Post-flip back handle swapped to 1001")

    // Flip 2 (swap back)
    flip_res2 = drm_kms_page_flip(dev)
    assert_eq_int(flip_res2, 1, "Page flip 2 succeeded")
    assert_eq_int(dev.kd_front_buffer.db_handle, 1001, "Flip 2 front handle restored to 1001")
    assert_eq_int(dev.kd_back_buffer.db_handle, 1002, "Flip 2 back handle restored to 1002")
    passed_tests = passed_tests + 1

    // ── Section 5: Unified drm_open() Lifecycle & Graceful fbdev Fallback ─────
    say "\n▶ Section 5: Top-Level drm_open() Lifecycle & Hardware Fallback..."
    total_tests = total_tests + 1

    // drm_open attempts /dev/dri/card0 and /dev/dri/card1, falling back to /dev/fb0 if unavailable
    fb = drm_open()
    assert_true(fb != 0, "Display initialized (DRM KMS or fbdev fallback)")
    fb_w = get(fb, 1)
    fb_h = get(fb, 2)
    assert_eq_int(fb_w, 1920, "Display width is 1920")
    assert_eq_int(fb_h, 1080, "Display height is 1080")

    // Draw pixel and fill rect through unified top-level API
    col_magenta = 4294902015 // 0xFFFF00FF
    p_ok = drm_draw_pixel(fb, 250, 250, col_magenta)
    assert_eq_int(p_ok, 1, "Unified drm_draw_pixel succeeded")

    r_ok = drm_fb_fill_rect(fb, 300, 300, 50, 40, col_magenta)
    assert_eq_int(r_ok, 2000, "Unified drm_fb_fill_rect rendered 2,000 pixels")

    // Unified page flip
    fl_ok = drm_page_flip(fb)
    assert_eq_int(fl_ok, 1, "Unified drm_page_flip completed")

    // Cleanup
    cl_ok = drm_close(fb)
    assert_eq_int(cl_ok, 1, "Unified drm_close completed cleanly")
    passed_tests = passed_tests + 1

    // Teardown dev
    drm_kms_device_close(dev)

    say "\n-----------------------------------------------------------------"
    say "RESULTS: " + str(passed_tests) + "/" + str(total_tests) + " sections passed."
    say "🎉 ALL DIRECT DRM/KMS HARDWARE GRAPHICS TESTS PASSED!"
    return 0

main()
