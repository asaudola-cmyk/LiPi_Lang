// ==============================================================================
// 👑 LIPI SOVEREIGN GRAPHICS: DIRECT FRAMEBUFFER & DRM KMS (universe/gui/fbdev.lp)
// Standard: Linux Framebuffer (/dev/fb0) & FBIOGET_VSCREENINFO / FSCREENINFO ABI
// 100% Pure Lipi Implementation — Zero C | Zero Libc | Zero X11 | Zero Wayland
// ==============================================================================
//
// WHY: Bypasses X11/Wayland completely for zero-overhead sovereign GUI rendering.
// Directly interacts with the Linux kernel framebuffer driver (/dev/fb0) via native
// ioctl and mmap system calls. Pushes 32-bit ARGB pixels straight to video RAM.
// Includes seamless fallback to an in-memory Virtual Framebuffer (VFB) to guarantee
// 100% crash-free execution in headless CI, sandbox, or unprivileged environments.
// ==============================================================================

include "universe/core/memory.lp"

// ── 1. Linux Framebuffer IOCTL Constants ──────────────────────────────────────
FBIOGET_VSCREENINFO = 17920 // 0x4600: Variable screen info
FBIOPUT_VSCREENINFO = 17921 // 0x4601: Set variable screen info
FBIOGET_FSCREENINFO = 17922 // 0x4602: Fixed screen info

// ── 2. Framebuffer Device Initialization & Fallback ───────────────────────────
// WHY: Opens /dev/fb0, queries hardware screen dimensions via ioctl, and mmaps VRAM.
// In headless sandboxes or permission-restricted environments, gracefully falls back
// to a virtual in-memory framebuffer avoiding crashes or null pointer dereferences.
fn fbdev_open fb_path
    if fb_path == 0
        fb_path = "/dev/fb0"
    
    // O_RDWR = 2
    fd = syscall(2, fb_path, 2, 0, 0, 0, 0)
    
    // Default standard resolution (Full HD 1080p 32bpp)
    width = 1920
    height = 1080
    bpp = 32
    pitch = 1920 * 4
    size = pitch * 1080
    buf = 0
    is_virtual = 0
    
    if fd >= 0
        // Query variable screen parameters via FBIOGET_VSCREENINFO (160-byte struct)
        var_info = malloc(160)
        mem_zero(var_info, 160)
        res = syscall(16, fd, 17920, var_info, 0, 0, 0) // FBIOGET_VSCREENINFO
        
        if res == 0
            w_val = mem_read_u32(var_info, 0)
            h_val = mem_read_u32(var_info, 4)
            bpp_val = mem_read_u32(var_info, 24)
            if w_val > 0
                width = w_val
            if h_val > 0
                height = h_val
            if bpp_val > 0
                bpp = bpp_val
        free(var_info, 160)
        
        // Query fixed screen parameters via FBIOGET_FSCREENINFO (80-byte struct)
        fix_info = malloc(80)
        mem_zero(fix_info, 80)
        res_fix = syscall(16, fd, 17922, fix_info, 0, 0, 0) // FBIOGET_FSCREENINFO
        if res_fix == 0
            line_len = mem_read_u32(fix_info, 48) // Hardware pitch (line_length)
            smem_len = mem_read_u32(fix_info, 24) // smem_len in bytes
            if line_len > 0
                pitch = line_len
            else
                pitch = width * (bpp / 8)
            if smem_len > 0
                size = smem_len
            else
                size = pitch * height
        else
            pitch = width * (bpp / 8)
            size = pitch * height
        free(fix_info, 80)
        
        // Memory map hardware video RAM: PROT_READ|PROT_WRITE = 3, MAP_SHARED = 1
        buf = syscall(9, 0, size, 3, 1, fd, 0)
        if buf <= 0
            syscall(3, fd, 0, 0, 0, 0, 0)
            fd = 0 - 1
            buf = 0
    
    if buf <= 0
        // Graceful Virtual Framebuffer (VFB) Fallback
        // Allocates contiguous system memory ensuring zero downtime
        is_virtual = 1
        fd = 0 - 1
        pitch = width * (bpp / 8)
        size = pitch * height
        buf = malloc(size)
        mem_zero(buf, size)
    
    // Allocate back buffer for double buffering
    back_buf = malloc(size)
    mem_zero(back_buf, size)
    
    // Return structured list object (Indices 0..6 strictly backward compatible)
    fb = list()
    push(fb, fd)         // 0: File descriptor (-1 if virtual fallback)
    push(fb, width)      // 1: Display width in pixels
    push(fb, height)     // 2: Display height in pixels
    push(fb, bpp)        // 3: Bits per pixel (usually 32 for ARGB8888)
    push(fb, pitch)      // 4: Pitch / line stride in bytes
    push(fb, size)       // 5: Total buffer size in bytes
    push(fb, buf)        // 6: Front buffer / VRAM memory pointer
    push(fb, back_buf)   // 7: Back buffer pointer for tear-free rendering
    push(fb, is_virtual) // 8: 1 if virtual fallback, 0 if physical hardware
    
    return fb

// ── 3. Pixel Rasterization & Readback ──────────────────────────────────────────
// WHY: Writes 32-bit ARGB pixel to back buffer (or front buffer if unbuffered).
// Full bounds checking protects memory against out-of-bounds corruption.
fn fbdev_draw_pixel fb x y color_argb
    if fb == 0
        return 0
    
    width = get(fb, 1)
    height = get(fb, 2)
    pitch = get(fb, 4)
    buf = get(fb, 6)
    
    // Target back buffer if double buffering is active
    if len(fb) > 7
        bb = get(fb, 7)
        if bb > 0
            buf = bb

    if x < 0 or x >= width or y < 0 or y >= height
        return 0
    
    offset = (y * pitch) + (x * 4)
    ptr = buf + offset
    mem_write_u32(ptr, 0, color_argb)
    return 1

fn fbdev_draw_pixel_direct fb x y color_argb
    // WHY: Bypasses back buffer and writes directly into hardware VRAM front buffer.
    if fb == 0
        return 0
    
    width = get(fb, 1)
    height = get(fb, 2)
    pitch = get(fb, 4)
    buf = get(fb, 6)
    
    if x < 0 or x >= width or y < 0 or y >= height
        return 0
    
    offset = (y * pitch) + (x * 4)
    ptr = buf + offset
    mem_write_u32(ptr, 0, color_argb)
    return 1

fn fbdev_read_pixel fb x y
    // WHY: Reads 32-bit ARGB pixel value at (x, y) for inspection and test verification.
    if fb == 0
        return 0
    
    width = get(fb, 1)
    height = get(fb, 2)
    pitch = get(fb, 4)
    buf = get(fb, 6)
    
    if len(fb) > 7
        bb = get(fb, 7)
        if bb > 0
            buf = bb
            
    if x < 0 or x >= width or y < 0 or y >= height
        return 0
        
    offset = (y * pitch) + (x * 4)
    ptr = buf + offset
    return mem_read_u32(ptr, 0)

// ── 4. Geometric Rasterization Primitives ──────────────────────────────────────
// WHY: Scanline-based rectangle fill with viewport clipping.
// Returns exact rendered pixel count for validation and test assert compatibility.
fn fbdev_fill_rect fb x y w h color_argb
    if fb == 0
        return 0
    
    width = get(fb, 1)
    height = get(fb, 2)
    pitch = get(fb, 4)
    buf = get(fb, 6)
    
    if len(fb) > 7
        bb = get(fb, 7)
        if bb > 0
            buf = bb
    
    x0 = x
    y0 = y
    x1 = x + w
    y1 = y + h
    
    if x0 < 0
        x0 = 0
    if y0 < 0
        y0 = 0
    if x1 > width
        x1 = width
    if y1 > height
        y1 = height
        
    if x1 <= x0 or y1 <= y0
        return 0
        
    row_pixels = x1 - x0
    c_low = color_argb & 4294967295
    color64 = c_low + (c_low * 4294967296)

    cy = y0
    while cy < y1
        row_ptr = buf + (cy * pitch) + (x0 * 4)
        chunks = row_pixels / 16
        c = 0
        while c < chunks
            off = c * 64
            mem_write(row_ptr, off, color64)
            mem_write(row_ptr, off + 8, color64)
            mem_write(row_ptr, off + 16, color64)
            mem_write(row_ptr, off + 24, color64)
            mem_write(row_ptr, off + 32, color64)
            mem_write(row_ptr, off + 40, color64)
            mem_write(row_ptr, off + 48, color64)
            mem_write(row_ptr, off + 56, color64)
            c = c + 1

        rem_start = chunks * 16
        rem_pairs = (row_pixels - rem_start) / 2
        p = 0
        while p < rem_pairs
            mem_write(row_ptr, (rem_start + (p * 2)) * 4, color64)
            p = p + 1

        if (row_pixels % 2) == 1
            mem_write_u32(row_ptr, (row_pixels - 1) * 4, color_argb)

        cy = cy + 1

    rendered_pixels = (x1 - x0) * (y1 - y0)
    return rendered_pixels

fn fbdev_draw_rect_outline fb x y w h color_argb
    // WHY: Draws 1-pixel hollow rectangle outline without filling interior.
    if fb == 0 or w <= 0 or h <= 0
        return 0
    x2 = x + w - 1
    y2 = y + h - 1
    
    cx = x
    while cx <= x2
        fbdev_draw_pixel(fb, cx, y, color_argb)
        fbdev_draw_pixel(fb, cx, y2, color_argb)
        cx = cx + 1
    
    cy = y + 1
    while cy < y2
        fbdev_draw_pixel(fb, x, cy, color_argb)
        fbdev_draw_pixel(fb, x2, cy, color_argb)
        cy = cy + 1
    return 1

fn fbdev_clear fb color_argb
    // WHY: Clears entire canvas to specified 32-bit ARGB background color.
    if fb == 0
        return 0
    width = get(fb, 1)
    height = get(fb, 2)
    return fbdev_fill_rect(fb, 0, 0, width, height, color_argb)

// ── 5. Bresenham Line & Midpoint Circle Primitives ─────────────────────────────
fn fbdev_draw_line fb x0 y0 x1 y1 color_argb
    // WHY: Bresenham's integer-only 2D line algorithm avoiding floating point.
    if fb == 0
        return 0
    
    dx = x1 - x0
    if dx < 0
        dx = 0 - dx
    sx = 1
    if x0 > x1
        sx = 0 - 1
        
    dy = y1 - y0
    if dy < 0
        dy = 0 - dy
    dy = 0 - dy
    sy = 1
    if y0 > y1
        sy = 0 - 1
        
    err = dx + dy
    cx = x0
    cy = y0
    
    while 1 == 1
        fbdev_draw_pixel(fb, cx, cy, color_argb)
        if cx == x1 and cy == y1
            break
        e2 = 2 * err
        if e2 >= dy
            err = err + dy
            cx = cx + sx
        if e2 <= dx
            err = err + dx
            cy = cy + sy
    return 1

fn fbdev_draw_circle fb xc yc r color_argb
    // WHY: Midpoint circle algorithm with 8-way symmetry rasterization.
    if fb == 0 or r <= 0
        return fbdev_draw_pixel(fb, xc, yc, color_argb)
    
    x = 0
    y = r
    d = 3 - (2 * r)
    
    while y >= x
        fbdev_draw_pixel(fb, xc + x, yc + y, color_argb)
        fbdev_draw_pixel(fb, xc - x, yc + y, color_argb)
        fbdev_draw_pixel(fb, xc + x, yc - y, color_argb)
        fbdev_draw_pixel(fb, xc - x, yc - y, color_argb)
        fbdev_draw_pixel(fb, xc + y, yc + x, color_argb)
        fbdev_draw_pixel(fb, xc - y, yc + x, color_argb)
        fbdev_draw_pixel(fb, xc + y, yc - x, color_argb)
        fbdev_draw_pixel(fb, xc - y, yc - x, color_argb)
        
        x = x + 1
        if d > 0
            y = y - 1
            d = d + (4 * (x - y)) + 10
        else
            d = d + (4 * x) + 6
    return 1

// ── 6. Hardware Double-Buffering Page Flip & Blit ──────────────────────────────
// WHY: Transfers back buffer memory to physical video RAM front buffer for tear-free display.
fn fbdev_flip fb
    if fb == 0
        return 0
    if len(fb) <= 7
        return 0
    
    front_buf = get(fb, 6)
    back_buf = get(fb, 7)
    size = get(fb, 5)
    
    if front_buf > 0 and back_buf > 0 and size > 0
        mem_copy(front_buf, back_buf, size)
        return 1
    return 0

// ── 7. Resource Teardown & Cleanup ────────────────────────────────────────────
// WHY: Unmaps hardware video memory via SYS_munmap (11) and closes device handle (SYS_close 3).
// If running on virtual fallback, frees allocated heap pages without touching kernel descriptors.
fn fbdev_close fb
    if fb == 0
        return 0
    
    fd = get(fb, 0)
    size = get(fb, 5)
    buf = get(fb, 6)
    back_buf = 0
    is_virtual = 0
    
    if len(fb) > 7
        back_buf = get(fb, 7)
    if len(fb) > 8
        is_virtual = get(fb, 8)
    
    // Release back buffer
    if back_buf > 0
        free(back_buf, size)
        list_set(fb, 7, 0)
        
    // Release front buffer
    if is_virtual == 1
        if buf > 0
            free(buf, size)
            list_set(fb, 6, 0)
    else
        if buf > 0
            syscall(11, buf, size, 0, 0, 0, 0) // munmap
            list_set(fb, 6, 0)
        if fd >= 0
            syscall(3, fd, 0, 0, 0, 0, 0) // close
            list_set(fb, 0, 0 - 1)
            
    return 1

// ── 8. Bilingual Bengali Canonical Standard Aliases ───────────────────────────
fn এফবি_ওপেন পথ
    return fbdev_open(পথ)

fn এফবি_পিক্সেল_আঁকো এফবি x y রঙ
    return fbdev_draw_pixel(এফবি, x, y, রঙ)

fn এফবি_পিক্সেল_পড়ো এফবি x y
    return fbdev_read_pixel(এফবি, x, y)

fn এফবি_আয়তক্ষেত্র_ভরাট এফবি x y w h রঙ
    return fbdev_fill_rect(এফবি, x, y, w, h, রঙ)

fn এফবি_রেখা_আঁকো এফবি x0 y0 x1 y1 রঙ
    return fbdev_draw_line(এফবি, x0, y0, x1, y1, রঙ)

fn এফবি_বৃত্ত_আঁকো এফবি xc yc r রঙ
    return fbdev_draw_circle(এফবি, xc, yc, r, রঙ)

fn এফবি_ক্লিয়ার এফবি রঙ
    return fbdev_clear(এফবি, রঙ)

fn এফবি_পেজ_ফ্লিপ এফবি
    return fbdev_flip(এফবি)

fn এফবি_বন্ধ এফবি
    return fbdev_close(এফবি)
