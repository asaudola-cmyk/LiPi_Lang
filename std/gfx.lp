// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: SILICON 2D GRAPHICS & FRAMEBUFFER (std/gfx.lp)
// ⚡ Direct Silicon RGBA Canvas | Bresenham Line | Midpoint Circle | BMP Export | Blit
// ==============================================================================

// WHY: High-performance systems graphics must operate without external graphic
// libraries (X11, Wayland, Cairo, SDL). std/gfx.lp encapsulates a contiguous 32-bit
// RGBA framebuffer canvas with native rasterization primitives, 2D blitting, and
// 54-byte uncompressed BMP file serialization. Zero Libc, zero C dependencies.

include "std/mem.lp"

// ১. ৩২-বিট আরজিবিএ (RGBA) কালার কম্পোজিশন
// WHY: Packs 8-bit Red, Green, Blue, Alpha channels into a 32-bit color word.
// Uses base-256 integer arithmetic: (A * 2^24) + (R * 2^16) + (G * 2^8) + B.
fn color_rgba r g b a
    c = (a * 16777216) + (r * 65536) + (g * 256) + b
    return c

fn color_rgb r g b
    return color_rgba(r, g, b, 255)

fn color_create r g b a
    return color_rgba(r, g, b, a)

fn color_created r g b a
    return color_rgba(r, g, b, a)

fn কালার_তৈরি r g b a
    return color_rgba(r, g, b, a)

// ২. ইন-মেমরি ফ্রেমবাফার ক্যানভাস বরাদ্দকরণ (Allocate 2D Framebuffer Canvas)
// WHY: Header stores metadata: offset 0 = width, offset 8 = height, offset 16 = total_pixels.
// Pixel data immediately follows at offset 32. 4 bytes per pixel (BGRA 32-bit).
fn canvas_create width height
    total_pixel = width * height
    pixel_bytes = total_pixel * 4
    total_alloc = 32 + pixel_bytes
    buffer = malloc(total_alloc)

    mem_write(buffer, 0, width)
    mem_write(buffer, 8, height)
    mem_write(buffer, 16, total_pixel)
    return buffer

fn ক্যানভাস_তৈরি width height
    return canvas_create(width, height)

// ৩. ক্যানভাস মেমরি অবমুক্তি (Deallocate Framebuffer Memory)
// WHY: Returns allocated framebuffer memory pages to the Linux kernel via SYS_munmap.
fn canvas_destroy canvas
    width = mem_read(canvas, 0)
    height = mem_read(canvas, 8)
    total_alloc = 32 + (width * height * 4)
    res = free(canvas, total_alloc)
    return res

fn canvas_মুক্তি canvas
    return canvas_destroy(canvas)


// ৪. ক্যানভাস ব্যাকগ্রাউন্ড ভরাট বা ক্লিয়ার (Clear Canvas)
// WHY: Sets all pixels in the canvas to the specified 32-bit BGRA color.
fn canvas_clear canvas color
    total_pixel = mem_read(canvas, 16)
    b = color % 256
    g = (color / 256) % 256
    r = (color / 65536) % 256
    a = (color / 16777216) % 256

    i = 0
    while i < total_pixel
        off = 32 + (i * 4)
        mem_write_byte(canvas, off + 0, b)
        mem_write_byte(canvas, off + 1, g)
        mem_write_byte(canvas, off + 2, r)
        mem_write_byte(canvas, off + 3, a)
        i = i + 1
    return total_pixel

fn canvas_ক্লিয়ার canvas color
    return canvas_clear(canvas, color)


// ৫. বাউন্ডস-চেকড পিক্সেল অঙ্কন (Bounds-Checked Pixel Draw)
// WHY: Validates coordinate boundaries against width and height before writing pixel memory.
fn pixel_draw canvas x y color
    width = mem_read(canvas, 0)
    height = mem_read(canvas, 8)

    if x >= 0 and x < width and y >= 0 and y < height
        off = 32 + ((y * width + x) * 4)
        b = color % 256
        g = (color / 256) % 256
        r = (color / 65536) % 256
        a = (color / 16777216) % 256

        mem_write_byte(canvas, off + 0, b)
        mem_write_byte(canvas, off + 1, g)
        mem_write_byte(canvas, off + 2, r)
        mem_write_byte(canvas, off + 3, a)
        return 1
    return 0

fn pixel_আঁকো canvas x y color
    return pixel_draw(canvas, x, y, color)


// ৬. বাউন্ডস-চেকড পিক্সেল রিড (Bounds-Checked Pixel Read)
// WHY: Reads raw 32-bit pixel value at (x, y) coordinates for testing and frame inspection.
fn pixel_read canvas x y
    width = mem_read(canvas, 0)
    height = mem_read(canvas, 8)

    if x >= 0 and x < width and y >= 0 and y < height
        off = 32 + ((y * width + x) * 4)
        b = mem_byte_পড়ো(canvas, off + 0)
        g = mem_byte_পড়ো(canvas, off + 1)
        r = mem_byte_পড়ো(canvas, off + 2)
        a = mem_byte_পড়ো(canvas, off + 3)
        val = (a * 16777216) + (r * 65536) + (g * 256) + b
        return val
    return 0

fn pixel_পড়ো canvas x y
    return pixel_read(canvas, x, y)

// ৭. আয়তক্ষেত্র ভরাট অঙ্কন (Filled Rectangle)
// WHY: Fills rectangular bounding box with solid color using horizontal scanlines.
fn rect_fill canvas rx ry rw rh color
    py = ry
    while py < (ry + rh)
        px = rx
        while px < (rx + rw)
            pixel_draw(canvas, px, py, color)
            px = px + 1
        py = py + 1
    return rw * rh

fn আয়তক্ষেত্র_আঁকো canvas rx ry rw rh color
    return rect_fill(canvas, rx, ry, rw, rh, color)


// ৭.১ আয়তক্ষেত্র বর্ডার অঙ্কন (Stroked Rectangle Outline)
// WHY: Draws hollow rectangular outline with 1-pixel border thickness.
fn rect_stroke canvas rx ry rw rh color
    line_horizontal(canvas, rx, ry, rx + rw - 1, color)
    line_horizontal(canvas, rx, ry + rh - 1, rx + rw - 1, color)
    line_vertical(canvas, rx, ry, ry + rh - 1, color)
    line_vertical(canvas, rx + rw - 1, ry, ry + rh - 1, color)
    return 1

fn আয়তক্ষেত্র_বর্ডার_আঁকো canvas rx ry rw rh color
    return rect_stroke(canvas, rx, ry, rw, rh, color)

// ৮.১ অনুভূমিক লাইন ড্রয়িং (Horizontal Line)
// WHY: Optimized single-axis scanline rasterization.
fn line_horizontal canvas x0 y x1 color
    start_x = x0
    end_x = x1
    if start_x > end_x
        start_x = x1
        end_x = x0
    cur = start_x
    while cur <= end_x
        pixel_draw(canvas, cur, y, color)
        cur = cur + 1
    return 1

fn রেখা_অনুভূমিক_আঁকো canvas x0 y x1 color
    return line_horizontal(canvas, x0, y, x1, color)


// ৮.২ উলম্ব লাইন ড্রয়িং (Vertical Line)
// WHY: Optimized single-axis vertical scanline rasterization.
fn line_vertical canvas x y0 y1 color
    start_y = y0
    end_y = y1
    if start_y > end_y
        start_y = y1
        end_y = y0
    cur = start_y
    while cur <= end_y
        pixel_draw(canvas, x, cur, color)
        cur = cur + 1
    return 1

fn রেখা_উলম্ব_আঁকো canvas x y0 y1 color
    return line_vertical(canvas, x, y0, y1, color)


// ৮.৩ ব্রেসেনহ্যাম লাইন ড্রয়িং (Bresenham 2D Line Algorithm)
// WHY: Interpolates pixels from (x0, y0) to (x1, y1) safely without division or branch divergence.
fn line_draw canvas x0 y0 x1 y1 color
    if y0 == y1
        line_horizontal(canvas, x0, y0, x1, color)
        return 0
    if x0 == x1
        line_vertical(canvas, x0, y0, y1, color)
        return 0

    cx = x0
    cy = y0
    sx = 1
    if x0 > x1
        sx = 0 - 1
    sy = 1
    if y0 > y1
        sy = 0 - 1

    running = 1
    while running == 1
        pixel_draw(canvas, cx, cy, color)
        if cx == x1 and cy == y1
            running = 0
        if cx != x1
            cx = cx + sx
        if cy != y1
            cy = cy + sy
    return 0

fn রেখা_আঁকো canvas x0 y0 x1 y1 color
    return line_draw(canvas, x0, y0, x1, y1, color)


// ৯. মিডপয়েন্ট সার্কেল অ্যালগরিদম (Midpoint Integer Circle Algorithm)
// WHY: 8-way symmetric circular rasterization around center (cx, cy) with radius r.
fn circle_draw canvas cx cy r color
    x = 0
    y = r
    d = 3 - (2 * r)

    while y >= x
        pixel_draw(canvas, cx + x, cy + y, color)
        pixel_draw(canvas, cx - x, cy + y, color)
        pixel_draw(canvas, cx + x, cy - y, color)
        pixel_draw(canvas, cx - x, cy - y, color)
        pixel_draw(canvas, cx + y, cy + x, color)
        pixel_draw(canvas, cx - y, cy + x, color)
        pixel_draw(canvas, cx + y, cy - x, color)
        pixel_draw(canvas, cx - y, cy - x, color)

        if d < 0
            d = d + (4 * x) + 6
        else
            d = d + (4 * (x - y)) + 10
            y = y - 1
        x = x + 1
    return 1

fn বৃত্ত_আঁকো canvas cx cy r color
    return circle_draw(canvas, cx, cy, r, color)


// ৯.১ ভরাট বৃত্ত অঙ্কন (Filled Circle)
// WHY: Rasterizes horizontal chords inside circle for solid disc rendering.
fn circle_fill canvas cx cy r color
    x = 0
    y = r
    d = 3 - (2 * r)

    while y >= x
        line_horizontal(canvas, cx - x, cy + y, cx + x, color)
        line_horizontal(canvas, cx - x, cy - y, cx + x, color)
        line_horizontal(canvas, cx - y, cy + x, cx + y, color)
        line_horizontal(canvas, cx - y, cy - x, cx + y, color)

        if d < 0
            d = d + (4 * x) + 6
        else
            d = d + (4 * (x - y)) + 10
            y = y - 1
        x = x + 1
    return 1

fn বৃত্ত_ভরাট_আঁকো canvas cx cy r color
    return circle_fill(canvas, cx, cy, r, color)

// ১০. ক্যানভাস বা ফ্রেমবাফার ব্লটিং (Linear Framebuffer Blit / Bit Block Transfer)
// WHY: High-performance 2D sub-region pixel transfer between framebuffers with clipping.
// Essential for sprite rendering, GUI windows, and composite graphics.
fn canvas_blit dst_canvas src_canvas dst_x dst_y src_x src_y blit_w blit_h
    dst_w = mem_read(dst_canvas, 0)
    dst_h = mem_read(dst_canvas, 8)
    src_w = mem_read(src_canvas, 0)
    src_h = mem_read(src_canvas, 8)

    row = 0
    while row < blit_h
        sy = src_y + row
        dy = dst_y + row
        if sy >= 0 and sy < src_h and dy >= 0 and dy < dst_h
            col = 0
            while col < blit_w
                sx = src_x + col
                dx = dst_x + col
                if sx >= 0 and sx < src_w and dx >= 0 and dx < dst_w
                    src_off = 32 + ((sy * src_w + sx) * 4)
                    dst_off = 32 + ((dy * dst_w + dx) * 4)
                    b = mem_byte_পড়ো(src_canvas, src_off + 0)
                    g = mem_byte_পড়ো(src_canvas, src_off + 1)
                    r = mem_byte_পড়ো(src_canvas, src_off + 2)
                    a = mem_byte_পড়ো(src_canvas, src_off + 3)
                    mem_write_byte(dst_canvas, dst_off + 0, b)
                    mem_write_byte(dst_canvas, dst_off + 1, g)
                    mem_write_byte(dst_canvas, dst_off + 2, r)
                    mem_write_byte(dst_canvas, dst_off + 3, a)
                col = col + 1
        row = row + 1
    return blit_w * blit_h

fn ক্যানভাস_ব্লট dst_canvas src_canvas dst_x dst_y src_x src_y blit_w blit_h
    return canvas_blit(dst_canvas, src_canvas, dst_x, dst_y, src_x, src_y, blit_w, blit_h)

// ১০.১ সম্পূর্ণ ক্যানভাস দ্রুত ব্লট (Full Canvas Fast Blit)
fn canvas_blit_fast dst_canvas src_canvas dst_x dst_y
    src_w = mem_read(src_canvas, 0)
    src_h = mem_read(src_canvas, 8)
    return canvas_blit(dst_canvas, src_canvas, dst_x, dst_y, 0, 0, src_w, src_h)

// ১১. স্ট্যান্ডার্ড ৫৪-বাইট বিএমপি (BMP) ইমেজ এক্সপোর্ট
// WHY: Serializes canvas into Windows Bitmap (BMP 32-bit BGRA uncompressed) file
// using direct Linux SYS_open, SYS_write, SYS_close. Zero external dependencies.
fn bmp_save canvas filepath
    width = mem_read(canvas, 0)
    height = mem_read(canvas, 8)

    // file open: O_WRONLY(1) | O_CREAT(64) | O_TRUNC(512) = 577, Mode: 0644 = 420
    fd = syscall(2, filepath, 577, 420, 0, 0, 0)
    if fd < 0
        return -1

    header = malloc(64)
    pixel_size = width * height * 4
    total_file_size = 54 + pixel_size

    // [1] BMP Header (14 bytes)
    mem_write_byte(header, 0, 66)  // 'B'
    mem_write_byte(header, 1, 77)  // 'M'

    // total file size (bytes 2..5 little-endian)
    mem_write_byte(header, 2, total_file_size % 256)
    mem_write_byte(header, 3, (total_file_size / 256) % 256)
    mem_write_byte(header, 4, (total_file_size / 65536) % 256)
    mem_write_byte(header, 5, (total_file_size / 16777216) % 256)

    // reserved (bytes 6..9: 0)
    mem_write_byte(header, 6, 0)
    mem_write_byte(header, 7, 0)
    mem_write_byte(header, 8, 0)
    mem_write_byte(header, 9, 0)

    // pixel offset (bytes 10..13: 54)
    mem_write_byte(header, 10, 54)
    mem_write_byte(header, 11, 0)
    mem_write_byte(header, 12, 0)
    mem_write_byte(header, 13, 0)

    // [2] DIB Header (BITMAPINFOHEADER: 40 bytes)
    mem_write_byte(header, 14, 40) // header size
    mem_write_byte(header, 15, 0)
    mem_write_byte(header, 16, 0)
    mem_write_byte(header, 17, 0)

    // width (bytes 18..21)
    mem_write_byte(header, 18, width % 256)
    mem_write_byte(header, 19, (width / 256) % 256)
    mem_write_byte(header, 20, (width / 65536) % 256)
    mem_write_byte(header, 21, (width / 16777216) % 256)

    // height (bytes 22..25)
    mem_write_byte(header, 22, height % 256)
    mem_write_byte(header, 23, (height / 256) % 256)
    mem_write_byte(header, 24, (height / 65536) % 256)
    mem_write_byte(header, 25, (height / 16777216) % 256)

    // color planes (bytes 26..27: 1)
    mem_write_byte(header, 26, 1)
    mem_write_byte(header, 27, 0)

    // bits per pixel (bytes 28..29: 32 bpp)
    mem_write_byte(header, 28, 32)
    mem_write_byte(header, 29, 0)

    // compression method (bytes 30..33: 0 = BI_RGB uncompressed)
    mem_write_byte(header, 30, 0)
    mem_write_byte(header, 31, 0)
    mem_write_byte(header, 32, 0)
    mem_write_byte(header, 33, 0)

    // image data size (bytes 34..37)
    mem_write_byte(header, 34, pixel_size % 256)
    mem_write_byte(header, 35, (pixel_size / 256) % 256)
    mem_write_byte(header, 36, (pixel_size / 65536) % 256)
    mem_write_byte(header, 37, (pixel_size / 16777216) % 256)

    // horizontal resolution (bytes 38..41: 2835 ppm)
    mem_write_byte(header, 38, 19)
    mem_write_byte(header, 39, 11)
    mem_write_byte(header, 40, 0)
    mem_write_byte(header, 41, 0)

    // vertical resolution (bytes 42..45: 2835 ppm)
    mem_write_byte(header, 42, 19)
    mem_write_byte(header, 43, 11)
    mem_write_byte(header, 44, 0)
    mem_write_byte(header, 45, 0)

    // palette colors (bytes 46..53: 0)
    mem_write_byte(header, 46, 0)
    mem_write_byte(header, 47, 0)
    mem_write_byte(header, 48, 0)
    mem_write_byte(header, 49, 0)
    mem_write_byte(header, 50, 0)
    mem_write_byte(header, 51, 0)
    mem_write_byte(header, 52, 0)
    mem_write_byte(header, 53, 0)

    // write 54-byte BMP header
    syscall(1, fd, header, 54, 0, 0, 0)

    // write pixel rows bottom-up (Windows BMP scanline order)
    row = height - 1
    row_bytes = width * 4
    while row >= 0
        row_offset = 32 + (row * row_bytes)
        row_ptr = canvas + row_offset
        syscall(1, fd, row_ptr, row_bytes, 0, 0, 0)
        row = row - 1

    syscall(3, fd, 0, 0, 0, 0, 0)
    free(header, 64)
    return total_file_size

fn bmp_সংরক্ষণ canvas filepath
    return bmp_save(canvas, filepath)


