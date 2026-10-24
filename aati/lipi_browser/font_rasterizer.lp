// ==============================================================================
// 👑 LIPI SOVEREIGN WEB BROWSER: EMBEDDED BITMAP/VECTOR FONT RASTERIZER
// ⚡ Module: aati/lipi_browser/font_rasterizer.lp
// 🏛️ Architecture: Zero-FreeType, Zero-Cairo Pure Silicon Pixel Typography
// 100% Pure LiPi Implementation — Zero External / Libc / Python Dependencies
// ==============================================================================

include "utso/memory.lp"
include "utso/string.lp"

// ── 1. Color Extraction & Alpha Blending ───────────────────────────────────────

fn raster_get_alpha c
    return (c / 16777216) & 255

fn raster_get_red c
    return (c / 65536) & 255

fn raster_get_green c
    return (c / 256) & 255

fn raster_get_blue c
    return c & 255

fn raster_pack_argb a r g b
    return ((a & 255) * 16777216) + ((r & 255) * 65536) + ((g & 255) * 256) + (b & 255)

fn raster_blend_pixel buffer buf_w buf_h px py color_argb
    if px < 0 or px >= buf_w or py < 0 or py >= buf_h
        return 0
    end
    src_a = raster_get_alpha(color_argb)
    if src_a == 0 return 0 end

    idx = (py * buf_w) + px
    if src_a == 255
        buffer[idx] = color_argb
        return 1
    end

    // Alpha blending: dst = (src * a + dst * (255 - a)) / 255
    dst_col = buffer[idx]
    src_r = raster_get_red(color_argb)
    src_g = raster_get_green(color_argb)
    src_b = raster_get_blue(color_argb)

    dst_r = raster_get_red(dst_col)
    dst_g = raster_get_green(dst_col)
    dst_b = raster_get_blue(dst_col)

    inv_a = 255 - src_a
    out_r = ((src_r * src_a) + (dst_r * inv_a)) / 255
    out_g = ((src_g * src_a) + (dst_g * inv_a)) / 255
    out_b = ((src_b * src_a) + (dst_b * inv_a)) / 255

    buffer[idx] = raster_pack_argb(255, out_r, out_g, out_b)
    return 1

// ── 2. Geometric Primitive Rasterization ───────────────────────────────────────

fn raster_fill_rect buffer buf_w buf_h rx ry rw rh color_argb
    if rw <= 0 or rh <= 0 return 0 end
    y = ry
    y_end = ry + rh
    if y < 0 y = 0 end
    if y_end > buf_h y_end = buf_h end

    x_start = rx
    x_end = rx + rw
    if x_start < 0 x_start = 0 end
    if x_end > buf_w x_end = buf_w end

    while y < y_end
        x = x_start
        while x < x_end
            raster_blend_pixel(buffer, buf_w, buf_h, x, y, color_argb)
            x = x + 1
        end
        y = y + 1
    end
    return 1

fn raster_draw_rect_outline buffer buf_w buf_h rx ry rw rh border_w color_argb
    if rw <= 0 or rh <= 0 or border_w <= 0 return 0 end
    // Top border
    raster_fill_rect(buffer, buf_w, buf_h, rx, ry, rw, border_w, color_argb)
    // Bottom border
    raster_fill_rect(buffer, buf_w, buf_h, rx, ry + rh - border_w, rw, border_w, color_argb)
    // Left border
    raster_fill_rect(buffer, buf_w, buf_h, rx, ry, border_w, rh, color_argb)
    // Right border
    raster_fill_rect(buffer, buf_w, buf_h, rx + rw - border_w, ry, border_w, rh, color_argb)
    return 1

// ── 3. 8x16 Hardware Bitmap Font Glyph Engine ─────────────────────────────────
//
// WHY: Zero-dependency embedded glyph patterns for typography.
// Encodes 8 horizontal bit pixels per row across 16 vertical scanlines.

fn raster_get_ascii_glyph_row ascii_code row
    // Space (32)
    if ascii_code == 32 return 0 end

    // Digit '0' (48)
    if ascii_code == 48
        if row == 2 or row == 13 return 60 end
        if row >= 3 and row <= 12 return 102 end
        return 0
    end
    // Digit '1' (49)
    if ascii_code == 49
        if row == 2 return 24 end
        if row == 3 return 56 end
        if row >= 4 and row <= 12 return 24 end
        if row == 13 return 126 end
        return 0
    end

    // Letter 'A' (65)
    if ascii_code == 65
        if row == 2 return 24 end
        if row == 3 or row == 4 return 60 end
        if row >= 5 and row <= 7 return 102 end
        if row == 8 return 126 end
        if row >= 9 and row <= 13 return 102 end
        return 0
    end
    // Letter 'B' (66)
    if ascii_code == 66
        if row == 2 or row == 7 or row == 13 return 124 end
        if (row >= 3 and row <= 6) or (row >= 8 and row <= 12) return 102 end
        return 0
    end
    // Letter 'C' (67)
    if ascii_code == 67
        if row == 2 or row == 13 return 60 end
        if row == 3 or row == 12 return 102 end
        if row >= 4 and row <= 11 return 96 end
        return 0
    end
    // Letter 'L' (76)
    if ascii_code == 76
        if row >= 2 and row <= 12 return 96 end
        if row == 13 return 126 end
        return 0
    end
    // Letter 'P' (80)
    if ascii_code == 80
        if row == 2 or row == 7 return 124 end
        if row >= 3 and row <= 6 return 102 end
        if row >= 8 and row <= 13 return 96 end
        return 0
    end
    // Letter 'i' (105)
    if ascii_code == 105
        if row == 4 or row == 5 return 24 end
        if row >= 8 and row <= 13 return 24 end
        return 0
    end

    // Default procedural block glyph for all printable ASCII characters
    if ascii_code >= 33 and ascii_code <= 126
        if row >= 4 and row <= 12
            if row == 4 or row == 12 return 126 end
            return 66
        end
    end

    return 0

fn raster_draw_char buffer buf_w buf_h ascii_code start_x start_y scale color_argb
    if scale < 1 scale = 1 end
    row = 0
    while row < 16
        bits = raster_get_ascii_glyph_row(ascii_code, row)
        if bits > 0
            col = 0
            while col < 8
                bit_active = (bits / (1 << (7 - col))) & 1
                if bit_active == 1
                    // Paint scaled pixel block (scale x scale)
                    sy = 0
                    while sy < scale
                        sx = 0
                        while sx < scale
                            raster_blend_pixel(buffer, buf_w, buf_h, start_x + (col * scale) + sx, start_y + (row * scale) + sy, color_argb)
                            sx = sx + 1
                        end
                        sy = sy + 1
                    end
                end
                col = col + 1
            end
        end
        row = row + 1
    end
    return 8 * scale

fn raster_draw_text buffer buf_w buf_h text_str start_x start_y font_size color_argb
    scale = font_size / 14
    if scale < 1 scale = 1 end

    cur_x = start_x
    cur_y = start_y
    i = 0
    t_len = len(text_str)

    while i < t_len
        ch = char_at(text_str, i)
        if ch == "\n"
            cur_x = start_x
            cur_y = cur_y + (16 * scale) + 2
        else
            code = ord(ch)
            adv = raster_draw_char(buffer, buf_w, buf_h, code, cur_x, cur_y, scale, color_argb)
            cur_x = cur_x + adv
        end
        i = i + 1
    end

    return cur_x - start_x
