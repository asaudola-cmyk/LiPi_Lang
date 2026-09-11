// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: SILICON 2D GRAPHICS & FRAMEBUFFER (std/gfx.lp)
// ⚡ Direct Silicon RGBA Canvas | Bresenham Line | Midpoint Circle | BMP Export
// ==============================================================================

// WHY: High-performance systems graphics must operate without external graphic
// libraries (X11, Wayland, Cairo, SDL). std/gfx.lp encapsulates a contiguous 32-bit
// RGBA framebuffer canvas with native rasterization primitives and 54-byte BMP serialization.
// All functions strictly adhere to System V AMD64 6-register calling convention.

include "std/mem.lp"

// ১. ৩২-বিট আরজিবিএ (RGBA) color less্পোজিশন
// WHY: Packs 8-bit Red, Green, Blue, Alpha channels into a 32-bit color word.
fn color_created(r, g, b, a)
    c = (a << 24) | (r << 16) | (g << 8) | b
    return c

// ২. ইন-mem ফ্রেমbuffer canvas বরাদ্দaরণ
// WHY: Header stores metadata: offset 0 = width, offset 8 = height, offset 16 = total_pixels.
// Pixel data immediately follows at offset 32. 4 bytes per pixel (BGRA 32-bit).
fn canvas_create(width, height)
    total_pixel = width * height
    pixel_byte = total_pixel * 4
    total_বরাদ্দ = 32 + pixel_byte
    buffer = malloc(total_বরাদ্দ)

    mem_write(buffer, 0, width)
    mem_write(buffer, 8, height)
    mem_write(buffer, 16, total_pixel)
    return buffer

// ৩. canvas memory অবমুa্তি
// WHY: Returns allocated framebuffer memory pages to the Linux kernel via SYS_munmap.
fn canvas_মুa্তি(canvas)
    width = mem_পড়ো(canvas, 0)
    height = mem_পড়ো(canvas, 8)
    total_বরাদ্দ = 32 + (width * height * 4)
    res = free(canvas, total_বরাদ্দ)
    return res

// ৪. canvas ব্যাaগ্রাউন্ড ভরাট বা a্লিয়ার
// WHY: Sets all pixels in the canvas to the specified 32-bit color.
fn canvas_a্লিয়ার(canvas, color)
    total_pixel = mem_পড়ো(canvas, 16)
    b = color & 255
    g = (color >> 8) & 255
    r = (color >> 16) & 255
    a = (color >> 24) & 255

    i = 0
    while i < total_pixel
        off = 32 + (i * 4)
        mem_write_byte(canvas, off + 0, b)
        mem_write_byte(canvas, off + 1, g)
        mem_write_byte(canvas, off + 2, r)
        mem_write_byte(canvas, off + 3, a)
        i = i + 1

// ৫. বাউন্ডস-চেaড pixel অঙ্aন
// WHY: Validates coordinate boundaries against width and height before writing pixel memory.
fn pixel_আঁaো(canvas, x, y, color)
    width = mem_পড়ো(canvas, 0)
    height = mem_পড়ো(canvas, 8)

    if x >= 0
        if x < width
            if y >= 0
                if y < height
                    off = 32 + ((y * width + x) * 4)
                    b = color & 255
                    g = (color >> 8) & 255
                    r = (color >> 16) & 255
                    a = (color >> 24) & 255

                    mem_write_byte(canvas, off + 0, b)
                    mem_write_byte(canvas, off + 1, g)
                    mem_write_byte(canvas, off + 2, r)
                    mem_write_byte(canvas, off + 3, a)

// ৬. বাউন্ডস-চেaড pixel রিড
// WHY: Reads raw 32-bit pixel value at (x, y) coordinates for testing and frame inspection.
fn pixel_পড়ো(canvas, x, y)
    width = mem_পড়ো(canvas, 0)
    height = mem_পড়ো(canvas, 8)

    if x >= 0
        if x < width
            if y >= 0
                if y < height
                    off = 32 + ((y * width + x) * 4)
                    b = mem_byte_পড়ো(canvas, off + 0)
                    g = mem_byte_পড়ো(canvas, off + 1)
                    r = mem_byte_পড়ো(canvas, off + 2)
                    a = mem_byte_পড়ো(canvas, off + 3)
                    val = (a << 24) | (r << 16) | (g << 8) | b
                    return val
    return 0

// ৭. আয়তa্ষেত্র ভরাট অঙ্aন (Filled Rectangle)
// WHY: Fills rectangular bounding box with solid color using scanlines. Exactly 6 parameters.
fn আয়তa্ষেত্র_আঁaো(canvas, rx, ry, rw, rh, color)
    py = ry
    while py < (ry + rh)
        px = rx
        while px < (rx + rw)
            pixel_আঁaো(canvas, px, py, color)
            px = px + 1
        py = py + 1

// ৮.১ অনুভূমিa লাইন ড্রয়িং (Horizontal Line)
// WHY: Optimized single-axis scanline rasterization. Exactly 5 parameters.
fn রেbা_অনুভূমিa_আঁaো(canvas, x0, y, x1, color)
    start_x = x0
    end_x = x1
    if start_x > end_x
        start_x = x1
        end_x = x0
    cur = start_x
    while cur <= end_x
        pixel_আঁaো(canvas, cur, y, color)
        cur = cur + 1

// ৮.২ উলম্ব লাইন ড্রয়িং (Vertical Line)
// WHY: Optimized single-axis vertical scanline rasterization. Exactly 5 parameters.
fn রেbা_উলম্ব_আঁaো(canvas, x, y0, y1, color)
    start_y = y0
    end_y = y1
    if start_y > end_y
        start_y = y1
        end_y = y0
    cur = start_y
    while cur <= end_y
        pixel_আঁaো(canvas, x, cur, color)
        cur = cur + 1

// ৮.৩ ডায়াগনাল ও সাধারণ লাইন ড্রয়িং (Diagonal & General Raycast Line)
// WHY: Interpolates pixels from (x0, y0) to (x1, y1) safely without division or branch divergence.
fn রেbা_আঁaো(canvas, x0, y0, x1, y1, color)
    if y0 == y1
        রেbা_অনুভূমিa_আঁaো(canvas, x0, y0, x1, color)
        return 0
    if x0 == x1
        রেbা_উলম্ব_আঁaো(canvas, x0, y0, x1, color)
        return 0

    cx = x0
    cy = y0
    sx = 1
    if x0 > x1
        sx = 0 - 1
    sy = 1
    if y0 > y1
        sy = 0 - 1

    চলvalue = 1
    while চলvalue == 1
        pixel_আঁaো(canvas, cx, cy, color)
        if cx == x1
            চলvalue = 0
        if cy == y1
            চলvalue = 0
        cx = cx + sx
        cy = cy + sy
    return 0

// ৯. মিডপয়েন্ট সার্aেল অ্যালগরিদম (Midpoint Integer Circle Algorithm)
// WHY: 8-way symmetric circular rasterization around center (cx, cy) with radius r. Exactly 5 parameters.
fn বৃত্ত_আঁaো(canvas, cx, cy, r, color)
    x = 0
    y = r
    d = 3 - (2 * r)

    while y >= x
        pixel_আঁaো(canvas, cx + x, cy + y, color)
        pixel_আঁaো(canvas, cx - x, cy + y, color)
        pixel_আঁaো(canvas, cx + x, cy - y, color)
        pixel_আঁaো(canvas, cx - x, cy - y, color)
        pixel_আঁaো(canvas, cx + y, cy + x, color)
        pixel_আঁaো(canvas, cx - y, cy + x, color)
        pixel_আঁaো(canvas, cx + y, cy - x, color)
        pixel_আঁaো(canvas, cx - y, cy - x, color)

        if d < 0
            d = d + (4 * x) + 6
        else
            d = d + (4 * (x - y)) + 10
            y = y - 1
        x = x + 1

// ১০. স্ট্যান্ডার্ড ৫৪-byte বিএমপি (BMP) ইমেজ এa্সport
// WHY: Serializes canvas into Windows Bitmap (BMP 32-bit BGRA uncompressed) file
// using direct Linux SYS_open, SYS_write, SYS_close. Zero dependencies. Exactly 2 parameters.
fn বিএমপি_সংরa্ষণ(canvas, fileপাথ)
    width = mem_পড়ো(canvas, 0)
    height = mem_পড়ো(canvas, 8)

    // file ওপেন: O_WRONLY(1) | O_CREAT(64) | O_TRUNC(512) = 577, Mode: 0644 = 420
    fd = syscall(2, fileপাথ, 577, 420, 0, 0, 0)
    if fd < 0
        return -1

    header = malloc(64)
    pixel_size = width * height * 4
    total_file_size = 54 + pixel_size

    // [1] BMP Header (14 bytes)
    mem_write_byte(header, 0, 66)  // 'B'
    mem_write_byte(header, 1, 77)  // 'M'

    // total file size (byte ২..৫ লিটল-এন্ডিয়ান)
    mem_write_byte(header, 2, total_file_size & 255)
    mem_write_byte(header, 3, (total_file_size >> 8) & 255)
    mem_write_byte(header, 4, (total_file_size >> 16) & 255)
    mem_write_byte(header, 5, (total_file_size >> 24) & 255)

    // রিজার্ভড (byte ৬..৯: ০)
    mem_write_byte(header, 6, 0)
    mem_write_byte(header, 7, 0)
    mem_write_byte(header, 8, 0)
    mem_write_byte(header, 9, 0)

    // pixel offset (byte ১০..১৩: ৫৪)
    mem_write_byte(header, 10, 54)
    mem_write_byte(header, 11, 0)
    mem_write_byte(header, 12, 0)
    mem_write_byte(header, 13, 0)

    // [2] DIB Header (BITMAPINFOHEADER: 40 bytes)
    mem_write_byte(header, 14, 40) // header size_of
    mem_write_byte(header, 15, 0)
    mem_write_byte(header, 16, 0)
    mem_write_byte(header, 17, 0)

    // width (byte ১৮..২১)
    mem_write_byte(header, 18, width & 255)
    mem_write_byte(header, 19, (width >> 8) & 255)
    mem_write_byte(header, 20, (width >> 16) & 255)
    mem_write_byte(header, 21, (width >> 24) & 255)

    // height (byte ২২..২৫)
    mem_write_byte(header, 22, height & 255)
    mem_write_byte(header, 23, (height >> 8) & 255)
    mem_write_byte(header, 24, (height >> 16) & 255)
    mem_write_byte(header, 25, (height >> 24) & 255)

    // aালার প্লেন (byte ২৬..২৭: ১)
    mem_write_byte(header, 26, 1)
    mem_write_byte(header, 27, 0)

    // bit পার pixel (byte ২৮..২৯: ৩২ bpp)
    mem_write_byte(header, 28, 32)
    mem_write_byte(header, 29, 0)

    // less্প্রেশন মেথড (byte ৩০..৩৩: ০ = BI_RGB)
    mem_write_byte(header, 30, 0)
    mem_write_byte(header, 31, 0)
    mem_write_byte(header, 32, 0)
    mem_write_byte(header, 33, 0)

    // ইমেজ data size (byte ৩৪..৩৭)
    mem_write_byte(header, 34, pixel_size & 255)
    mem_write_byte(header, 35, (pixel_size >> 8) & 255)
    mem_write_byte(header, 36, (pixel_size >> 16) & 255)
    mem_write_byte(header, 37, (pixel_size >> 24) & 255)

    // অনুভূমিa রেজোলিউশন (byte ৩৮..৪১: ২৮৩৫ ppm)
    mem_write_byte(header, 38, 0x13)
    mem_write_byte(header, 39, 0x0b)
    mem_write_byte(header, 40, 0)
    mem_write_byte(header, 41, 0)

    // উলম্ব রেজোলিউশন (byte ৪২..৪৫: ২৮৩৫ ppm)
    mem_write_byte(header, 42, 0x13)
    mem_write_byte(header, 43, 0x0b)
    mem_write_byte(header, 44, 0)
    mem_write_byte(header, 45, 0)

    // প্যালেট ও aালারস (byte ৪৬..৫৩: ০)
    mem_write_byte(header, 46, 0)
    mem_write_byte(header, 47, 0)
    mem_write_byte(header, 48, 0)
    mem_write_byte(header, 49, 0)
    mem_write_byte(header, 50, 0)
    mem_write_byte(header, 51, 0)
    mem_write_byte(header, 52, 0)
    mem_write_byte(header, 53, 0)

    // header রাইট aরা (৫৪ byte)
    syscall(1, fd, header, 54, 0, 0, 0)

    // pixel rowগুলো নিচ থেaে উপরে (Bottom-up scanlines) রাইট aরা
    রো = height - 1
    রো_byte = width * 4
    while রো >= 0
        রো_offset = 32 + (রো * রো_byte)
        রো_পয়েন্টার = canvas + রো_offset
        syscall(1, fd, রো_পয়েন্টার, রো_byte, 0, 0, 0)
        রো = রো - 1

    // file ও memory a্লোজ aরা
    syscall(3, fd, 0, 0, 0, 0, 0)
    free(header, 64)
    return total_file_size
