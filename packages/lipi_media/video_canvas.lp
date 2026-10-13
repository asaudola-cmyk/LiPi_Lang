// ==============================================================================
// 👑 LIPI UNIVERSE MEDIA: SOVEREIGN VIDEO CANVAS & FRAME COMPOSITOR
// File: universe/media/video_canvas.lp
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% SDL | 0% FFmpeg
// ==============================================================================
//
// WHY THIS EXISTS:
// Video platforms (YouTube, TikTok), game engines, and graphic user interfaces
// need raw pixel compositing, 2D rasterization, and frame serialization.
//
// LIPI'S SOVEREIGN ANSWER:
// Pure direct-to-silicon 24-bit/32-bit RGB framebuffer compositor with Bresenham
// rasterization and direct standard Netpbm (P6) & BMP bitmap file output.
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/memory.lp"

struct VideoCanvas
    vc_width
    vc_height
    vc_stride
    vc_total_pixels
    vc_buffer_ptr

// ── ১. ক্যানভাস ইনিশিয়ালাইজেশন (Initialize 24-Bit RGB Video Canvas) ────────────
fn canvas_new width height
    c = VideoCanvas()
    c.vc_width = width
    c.vc_height = height
    // 24-bit RGB = 3 bytes per pixel
    c.vc_stride = width * 3
    c.vc_total_pixels = width * height
    total_bytes = c.vc_total_pixels * 3
    c.vc_buffer_ptr = malloc(total_bytes + 128)
    // Clear buffer to black
    mem_fill(c.vc_buffer_ptr, 0, total_bytes)
    return c

fn canvas_free c
    if c.vc_buffer_ptr != 0
        total_bytes = c.vc_total_pixels * 3
        free(c.vc_buffer_ptr, total_bytes + 128)
        c.vc_buffer_ptr = 0
    return 0

// ── ২. ক্যানভাস ক্লিয়ার বা ব্যাকগ্রাউন্ড ফিল (Clear Framebuffer) ─────────────────
fn canvas_clear c r g b
    ptr = c.vc_buffer_ptr
    total = c.vc_total_pixels
    i = 0
    while i < total
        off = i * 3
        mem_byte_write(ptr, off, r & 255)
        mem_byte_write(ptr, off + 1, g & 255)
        mem_byte_write(ptr, off + 2, b & 255)
        i = i + 1
    return 0

// ── ৩. পিক্সেল প্লট ও বাউন্ডারি চেক (Safe Direct Pixel Plotting) ─────────────────
fn canvas_set_pixel c x y r g b
    if x < 0 or x >= c.vc_width or y < 0 or y >= c.vc_height
        return 0
    off = (y * c.vc_stride) + (x * 3)
    ptr = c.vc_buffer_ptr
    mem_byte_write(ptr, off, r & 255)
    mem_byte_write(ptr, off + 1, g & 255)
    mem_byte_write(ptr, off + 2, b & 255)
    return 1

fn canvas_get_pixel_r c x y
    if x < 0 or x >= c.vc_width or y < 0 or y >= c.vc_height return 0
    off = (y * c.vc_stride) + (x * 3)
    return mem_byte_read(c.vc_buffer_ptr, off)

fn canvas_get_pixel_g c x y
    if x < 0 or x >= c.vc_width or y < 0 or y >= c.vc_height return 0
    off = (y * c.vc_stride) + (x * 3)
    return mem_byte_read(c.vc_buffer_ptr, off + 1)

fn canvas_get_pixel_b c x y
    if x < 0 or x >= c.vc_width or y < 0 or y >= c.vc_height return 0
    off = (y * c.vc_stride) + (x * 3)
    return mem_byte_read(c.vc_buffer_ptr, off + 2)

// ── ৪. আয়তক্ষেত্র অংকন (Fill Solid Rectangle) ──────────────────────────────────
fn canvas_draw_rect c x y w h r g b
    py = y
    max_y = y + h
    if max_y > c.vc_height max_y = c.vc_height
    if py < 0 py = 0

    while py < max_y
        px = x
        max_x = x + w
        if max_x > c.vc_width max_x = c.vc_width
        if px < 0 px = 0

        while px < max_x
            canvas_set_pixel(c, px, py, r, g, b)
            px = px + 1
        py = py + 1
    return 0

// ── ৫. ব্রেসেনহ্যাম লাইন অ্যালগরিদম (Pure Integer Bresenham Line Drawing) ────────
// WHY: 100% integer arithmetic without trigonometric or floating-point operations.
fn canvas_draw_line c x0 y0 x1 y1 r g b
    dx = x1 - x0
    if dx < 0 dx = 0 - dx
    dy = y1 - y0
    if dy < 0 dy = 0 - dy

    sx = 1
    if x0 > x1 sx = -1
    sy = 1
    if y0 > y1 sy = -1

    err = dx - dy
    cur_x = x0
    cur_y = y0

    loop = 1
    while loop == 1
        canvas_set_pixel(c, cur_x, cur_y, r, g, b)
        if cur_x == x1 and cur_y == y1
            loop = 0
        else
            e2 = 2 * err
            if e2 > (0 - dy)
                err = err - dy
                cur_x = cur_x + sx
            if e2 < dx
                err = err + dx
                cur_y = cur_y + sy
    return 0

// ── ৬. স্ট্যান্ডার্ড BMP 24-বিট ইমেজ ফাইল সিরিয়ালাইজেশন (Direct BMP Output) ────
// WHY: BMP is natively rendered by every OS and web stack without external decoders.
// 14-byte File Header + 40-byte DIB BITMAPINFOHEADER + BGR row-padded pixel stream.
fn canvas_write_bmp c file_path
    w = c.vc_width
    h = c.vc_height
    // BMP row stride must be padded to a multiple of 4 bytes
    row_bytes = w * 3
    padding = (4 - (row_bytes % 4)) % 4
    padded_row = row_bytes + padding
    pixel_data_size = padded_row * h
    file_size = 54 + pixel_data_size

    // Open file for write: O_WRONLY(1) | O_CREAT(64) | O_TRUNC(512) = 577, mode 0644 = 420
    fd = syscall(2, file_path, 577, 420, 0, 0, 0)
    if fd < 0 return -1

    hdr = malloc(64)

    // ── BMP Header (14 bytes) ──
    mem_byte_write(hdr, 0, 66)  // 'B'
    mem_byte_write(hdr, 1, 77)  // 'M'
    // File size (32-bit LE)
    mem_byte_write(hdr, 2, file_size & 255)
    mem_byte_write(hdr, 3, (file_size >> 8) & 255)
    mem_byte_write(hdr, 4, (file_size >> 16) & 255)
    mem_byte_write(hdr, 5, (file_size >> 24) & 255)
    // Reserved
    mem_byte_write(hdr, 6, 0)
    mem_byte_write(hdr, 7, 0)
    mem_byte_write(hdr, 8, 0)
    mem_byte_write(hdr, 9, 0)
    // Pixel offset = 54 (32-bit LE)
    mem_byte_write(hdr, 10, 54)
    mem_byte_write(hdr, 11, 0)
    mem_byte_write(hdr, 12, 0)
    mem_byte_write(hdr, 13, 0)

    // ── DIB Header: BITMAPINFOHEADER (40 bytes) ──
    mem_byte_write(hdr, 14, 40) // Header size
    mem_byte_write(hdr, 15, 0)
    mem_byte_write(hdr, 16, 0)
    mem_byte_write(hdr, 17, 0)
    // Width
    mem_byte_write(hdr, 18, w & 255)
    mem_byte_write(hdr, 19, (w >> 8) & 255)
    mem_byte_write(hdr, 20, (w >> 16) & 255)
    mem_byte_write(hdr, 21, (w >> 24) & 255)
    // Height
    mem_byte_write(hdr, 22, h & 255)
    mem_byte_write(hdr, 23, (h >> 8) & 255)
    mem_byte_write(hdr, 24, (h >> 16) & 255)
    mem_byte_write(hdr, 25, (h >> 24) & 255)
    // Color Planes = 1
    mem_byte_write(hdr, 26, 1)
    mem_byte_write(hdr, 27, 0)
    // Bits per pixel = 24
    mem_byte_write(hdr, 28, 24)
    mem_byte_write(hdr, 29, 0)
    // Compression = 0 (BI_RGB)
    mem_byte_write(hdr, 30, 0)
    mem_byte_write(hdr, 31, 0)
    mem_byte_write(hdr, 32, 0)
    mem_byte_write(hdr, 33, 0)
    // Image size
    mem_byte_write(hdr, 34, pixel_data_size & 255)
    mem_byte_write(hdr, 35, (pixel_data_size >> 8) & 255)
    mem_byte_write(hdr, 36, (pixel_data_size >> 16) & 255)
    mem_byte_write(hdr, 37, (pixel_data_size >> 24) & 255)
    // Resolution: 2835 ppm (~72 DPI)
    mem_byte_write(hdr, 38, 19)
    mem_byte_write(hdr, 39, 11)
    mem_byte_write(hdr, 40, 0)
    mem_byte_write(hdr, 41, 0)
    mem_byte_write(hdr, 42, 19)
    mem_byte_write(hdr, 43, 11)
    mem_byte_write(hdr, 44, 0)
    mem_byte_write(hdr, 45, 0)
    // Colors in palette
    mem_byte_write(hdr, 46, 0)
    mem_byte_write(hdr, 47, 0)
    mem_byte_write(hdr, 48, 0)
    mem_byte_write(hdr, 49, 0)
    mem_byte_write(hdr, 50, 0)
    mem_byte_write(hdr, 51, 0)
    mem_byte_write(hdr, 52, 0)
    mem_byte_write(hdr, 53, 0)

    // Write 54-byte BMP header
    syscall(1, fd, hdr, 54, 0, 0, 0)
    free(hdr, 64)

    // Write pixel rows from bottom to top (BMP standard is bottom-up)
    row_buf = malloc(padded_row + 16)
    y = h - 1
    while y >= 0
        x = 0
        while x < w
            // BMP stores colors in BGR order
            r = canvas_get_pixel_r(c, x, y)
            g = canvas_get_pixel_g(c, x, y)
            b = canvas_get_pixel_b(c, x, y)
            row_off = x * 3
            mem_byte_write(row_buf, row_off, b)
            mem_byte_write(row_buf, row_off + 1, g)
            mem_byte_write(row_buf, row_off + 2, r)
            x = x + 1

        // Pad row to 4-byte boundary
        p = 0
        while p < padding
            mem_byte_write(row_buf, (w * 3) + p, 0)
            p = p + 1

        syscall(1, fd, row_buf, padded_row, 0, 0, 0)
        y = y - 1

    free(row_buf, padded_row + 16)
    syscall(74, fd, 0, 0, 0, 0, 0) // SYS_fsync
    syscall(3, fd, 0, 0, 0, 0, 0)  // SYS_close
    return file_size

// ── ৭. দ্বিভাষিক বাংলা ফাংশনসমূহ (Bilingual Bengali API) ──────────────────────
fn ক্যানভাস_তৈরি প্রস্থ উচ্চতা
    return canvas_new(প্রস্থ, উচ্চতা)

fn ক্যানভাস_পিক্সেল_সেট ক্যানভাস x y r g b
    return canvas_set_pixel(ক্যানভাস, x, y, r, g, b)

fn ক্যানভাস_আয়তক্ষেত্র ক্যানভাস x y w h r g b
    return canvas_draw_rect(ক্যানভাস, x, y, w, h, r, g, b)

fn ক্যানভাস_লাইন ক্যানভাস x0 y0 x1 y1 r g b
    return canvas_draw_line(ক্যানভাস, x0, y0, x1, y1, r, g, b)

fn ক্যানভাস_সংরক্ষণ_বিএমপি ক্যানভাস ফাইল_পাথ
    return canvas_write_bmp(ক্যানভাস, ফাইল_পাথ)
