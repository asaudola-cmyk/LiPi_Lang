// Test 38: Sovereign 32-Bit ARGB Framebuffer GUI Rasterizer (Zero Stubs)
// Allocates real linear RGBA/ARGB pixel memory, performs bounds-clipped rectangle
// rasterization, and verifies exact rendered pixels directly from memory.

fn fb_create w h
    // Descriptor: [0]=w, [8]=h, [16]=pixel_buffer_ptr (w * h * 4 bytes)
    fb = alloc(32)
    pixels = alloc(w * h * 4)
    mem_word_write(fb, 0, w)
    mem_word_write(fb, 8, h)
    mem_word_write(fb, 16, pixels)
    return fb

fn fb_set_pixel fb x y argb
    w = mem_word_read(fb, 0)
    h = mem_word_read(fb, 8)
    if x < 0 or y < 0 or x >= w or y >= h
        return 0
    pixels = mem_word_read(fb, 16)
    off = ((y * w) + x) * 4
    mem_byte_write(pixels, off + 0, argb & 255)
    mem_byte_write(pixels, off + 1, (argb >> 8) & 255)
    mem_byte_write(pixels, off + 2, (argb >> 16) & 255)
    mem_byte_write(pixels, off + 3, (argb >> 24) & 255)
    return 1

fn fb_get_pixel fb x y
    w = mem_word_read(fb, 0)
    h = mem_word_read(fb, 8)
    if x < 0 or y < 0 or x >= w or y >= h
        return 0
    pixels = mem_word_read(fb, 16)
    off = ((y * w) + x) * 4
    b0 = mem_byte_read(pixels, off + 0) & 255
    b1 = mem_byte_read(pixels, off + 1) & 255
    b2 = mem_byte_read(pixels, off + 2) & 255
    b3 = mem_byte_read(pixels, off + 3) & 255
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)

fn fb_fill_rect fb rx ry rw rh argb
    drawn = 0
    y = ry
    while y < ry + rh
        x = rx
        while x < rx + rw
            drawn = drawn + fb_set_pixel(fb, x, y, argb)
            x = x + 1
        y = y + 1
    return drawn

fn main
    say "=== Sovereign ARGB Framebuffer GUI ==="
    fb = fb_create(64, 48)
    // Clear background to opaque dark slate (0xFF102030 = 4279246896)
    bg = 4279246896
    bg_cnt = fb_fill_rect(fb, 0, 0, 64, 48, bg)
    if bg_cnt != 3072
        say "FAIL: expected 3072 cleared background pixels, got " + str(bg_cnt)
        exit(1)

    // Draw clipped red button (0xFFFF0000 = 4294901760) overlapping right edge (x=54..74 clipped at 64)
    red = 4294901760
    rect_cnt = fb_fill_rect(fb, 54, 10, 20, 12, red)
    if rect_cnt != 120
        say "FAIL: bounds-clipped rectangle expected 120 pixels (10x12), got " + str(rect_cnt)
        exit(1)

    // Verify exact pixel readbacks inside button and outside button
    if fb_get_pixel(fb, 58, 15) != red
        say "FAIL: pixel (58, 15) inside button did not match red ARGB"
        exit(1)
    if fb_get_pixel(fb, 5, 5) != bg
        say "FAIL: pixel (5, 5) background did not match slate ARGB"
        exit(1)

    say "Framebuffer 64x48 rasterized: bg=" + str(bg_cnt) + "px, clipped_rect=" + str(rect_cnt) + "px"
    say "PASS: Test 38 X11 GUI"
    return 0
