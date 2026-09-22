// ==============================================================================
// 🧪 LIPI REGRESSION TEST: Sovereign Video Canvas & 24-Bit BMP Frame Rasterizer
// File: tests/test_video_canvas.lp
// Milestone: First 1.0.0 (প্রথম ১.০.০) | Zero Libc | Zero External Graphics
// ==============================================================================

include "universe/media/video_canvas.lp"

fn assert_true cond msg
    if cond == 0
        say "  ❌ FAILED: " + msg
        exit(1)
    say "  ✔ [PASS] " + msg

fn main
    say "════════════════════════════════════════════════════════════════════════"
    say "  🎬 LIPI SOVEREIGN VIDEO CANVAS & 24-BIT BMP FRAME TEST"
    say "════════════════════════════════════════════════════════════════════════"

    test_bmp = "/tmp/test_video_frame.bmp"
    syscall(87, test_bmp, 0, 0, 0, 0, 0) // Clean prior

    say "\n[Phase 1]: Allocating 100x100 24-Bit Video Frame Canvas..."
    c = canvas_new(100, 100)
    assert_true(c.vc_width == 100, "Canvas width is 100 pixels")
    assert_true(c.vc_height == 100, "Canvas height is 100 pixels")
    assert_true(c.vc_total_pixels == 10000, "Total pixels is 10000")

    say "\n[Phase 2]: Rasterizing Solid Rectangles & Bresenham Diagonals..."
    // Draw red rectangle at (10, 10) size 30x20
    canvas_draw_rect(c, 10, 10, 30, 20, 255, 0, 0)
    assert_true(canvas_get_pixel_r(c, 15, 15) == 255, "Pixel (15,15) red component is 255")
    assert_true(canvas_get_pixel_g(c, 15, 15) == 0, "Pixel (15,15) green component is 0")
    assert_true(canvas_get_pixel_b(c, 15, 15) == 0, "Pixel (15,15) blue component is 0")

    // Draw green diagonal line from (0,0) to (99,99)
    canvas_draw_line(c, 0, 0, 99, 99, 0, 255, 0)
    assert_true(canvas_get_pixel_g(c, 50, 50) == 255, "Bresenham midpoint (50,50) green component is 255")

    say "\n[Phase 3]: Serializing 24-Bit Standard BMP Frame to Silicon Disk..."
    bytes_written = canvas_write_bmp(c, test_bmp)
    // 100 width * 3 = 300 bytes per row (300 % 4 == 0, no padding needed).
    // Total size = 54 + (300 * 100) = 30054 bytes.
    assert_true(bytes_written == 30054, "Output BMP frame size matches exact 30054 bytes calculation")

    say "\n[Phase 4]: Validating BMP Header & DIB Structure from Disk..."
    fd = syscall(2, test_bmp, 0, 0, 0, 0, 0) // O_RDONLY = 0
    assert_true(fd >= 0, "Test BMP frame file opened successfully")

    hdr_buf = malloc(64)
    n = syscall(0, fd, hdr_buf, 54, 0, 0, 0)
    assert_true(n == 54, "Read 54 header bytes from disk")

    // 'B' 'M' = 66, 77
    assert_true(mem_byte_read(hdr_buf, 0) == 66, "Magic byte 0 is 'B'")
    assert_true(mem_byte_read(hdr_buf, 1) == 77, "Magic byte 1 is 'M'")

    // Offset 10: pixel data offset == 54
    assert_true(mem_byte_read(hdr_buf, 10) == 54, "Pixel array starts at offset 54")

    // Offset 14: DIB header size == 40
    assert_true(mem_byte_read(hdr_buf, 14) == 40, "DIB header size is 40 bytes")

    // Offset 28: Bits per pixel == 24
    assert_true(mem_byte_read(hdr_buf, 28) == 24, "Color depth is 24-bit RGB")

    // Free resources
    free(hdr_buf, 64)
    syscall(3, fd, 0, 0, 0, 0, 0)
    canvas_free(c)
    syscall(87, test_bmp, 0, 0, 0, 0, 0)

    say "\n════════════════════════════════════════════════════════════════════════"
    say "🎉 SOVEREIGN VIDEO CANVAS & BMP RASTERIZER TEST PASSED (100% PURE)"
    say "════════════════════════════════════════════════════════════════════════\n"
    return 0

main()
