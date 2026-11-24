// ==============================================================================
// LIPI PURE-SILICON 2D COMPOSITOR & RASTERIZER (utso/core/simd_raster.lp)
// 100% Pure Lipi | 0% Cairo / Skia / OpenGL | Direct Raw ARGB8888 Pixel Engine
// ==============================================================================
//
// WHY THIS MODULE:
// Operates directly on raw kernel mmap / memfd 32-bit ARGB8888 pixel framebuffers
// (4 bytes/pixel, little-endian BGRA in memory -> 0xAARRGGBB as u32) using:
//  - 64-bit QWORD paired-pixel fills (2 pixels per store, 8 pixels per unrolled iter)
//  - Exact Porter-Duff SRC_OVER alpha compositing
//  - Anti-aliased SDF rounded rectangles
//  - Xiaolin Wu anti-aliased lines
//  - 8-bit coverage glyph mask & ARGB sprite blitting
// ==============================================================================

include "utso/core/memory.lp"

fn sr_pack_argb a r g b
    return ((a & 255) << 24) | ((r & 255) << 16) | ((g & 255) << 8) | (b & 255)
end

fn sr_blend_pixel dst_px src_px
    // WHY: Exact integer Porter-Duff SRC_OVER alpha blending with (x + 128) / 255 rounding.
    sa = (src_px >> 24) & 255
    if sa == 255
        return src_px
    end
    if sa == 0
        return dst_px
    end
    inv_a = 255 - sa
    sr = (src_px >> 16) & 255
    sg = (src_px >> 8) & 255
    sb = src_px & 255
    da = (dst_px >> 24) & 255
    dr = (dst_px >> 16) & 255
    dg = (dst_px >> 8) & 255
    db = dst_px & 255

    out_r = (sr * sa + dr * inv_a + 127) / 255
    out_g = (sg * sa + dg * inv_a + 127) / 255
    out_b = (sb * sa + db * inv_a + 127) / 255
    out_a = sa + ((da * inv_a + 127) / 255)
    return (out_a << 24) | (out_r << 16) | (out_g << 8) | out_b
end

fn sr_get_pixel buf w h x y
    if buf <= 0 or x < 0 or y < 0 or x >= w or y >= h
        return 0
    end
    return mem_read_u32(buf, ((y * w) + x) * 4)
end

fn sr_put_pixel_blend buf w h x y argb
    if buf <= 0 or x < 0 or y < 0 or x >= w or y >= h
        return 0
    end
    off = ((y * w) + x) * 4
    sa = (argb >> 24) & 255
    if sa == 255
        mem_write_u32(buf, off, argb)
        return 1
    end
    if sa == 0
        return 0
    end
    dst = mem_read_u32(buf, off)
    mem_write_u32(buf, off, sr_blend_pixel(dst, argb))
    return 1
end

fn raster_clear_argb buf w h argb
    // WHY: Unrolled 64-bit paired-pixel clear writing 8 pixels (32 bytes) per loop iteration.
    if buf <= 0 or w <= 0 or h <= 0
        return 0
    end
    total_px = w * h
    c32 = argb & 4294967295
    pair64 = c32 | (c32 << 32)
    quads = total_px / 8
    i = 0
    while i < quads
        off = i * 32
        mem_write(buf, off, pair64)
        mem_write(buf, off + 8, pair64)
        mem_write(buf, off + 16, pair64)
        mem_write(buf, off + 24, pair64)
        i = i + 1
    end
    rem_px = quads * 8
    while rem_px < total_px
        mem_write_u32(buf, rem_px * 4, c32)
        rem_px = rem_px + 1
    end
    return total_px
end

fn raster_fill_rect_blend buf w h x y rw rh argb
    // WHY: Pre-clipped rectangle fill using 64-bit QWORD spans when opaque, or Porter-Duff SRC_OVER when translucent.
    if buf <= 0 or rw <= 0 or rh <= 0
        return 0
    end
    x0 = x
    y0 = y
    x1 = x + rw
    y1 = y + rh
    if x0 < 0 x0 = 0 end
    if y0 < 0 y0 = 0 end
    if x1 > w x1 = w end
    if y1 > h y1 = h end
    if x0 >= x1 or y0 >= y1
        return 0
    end
    sa = (argb >> 24) & 255
    if sa == 0
        return 0
    end
    c32 = argb & 4294967295
    if sa == 255
        pair64 = c32 | (c32 << 32)
        cy = y0
        while cy < y1
            row_off = cy * w * 4
            cx = x0
            while cx + 2 <= x1
                mem_write(buf, row_off + (cx * 4), pair64)
                cx = cx + 2
            end
            if cx < x1
                mem_write_u32(buf, row_off + (cx * 4), c32)
            end
            cy = cy + 1
        end
        return (x1 - x0) * (y1 - y0)
    end
    cy = y0
    while cy < y1
        row_off = cy * w * 4
        cx = x0
        while cx < x1
            poff = row_off + (cx * 4)
            dst = mem_read_u32(buf, poff)
            mem_write_u32(buf, poff, sr_blend_pixel(dst, c32))
            cx = cx + 1
        end
        cy = cy + 1
    end
    return (x1 - x0) * (y1 - y0)
end

fn _sr_isqrt n
    if n <= 0
        return 0
    end
    x = n
    y = (x + 1) / 2
    while y < x
        x = y
        y = (x + (n / x)) / 2
    end
    return x
end

fn raster_fill_rounded_rect buf w h x y rw rh radius argb
    // WHY: Signed-distance rounded rectangle with integer subpixel anti-aliasing on corners.
    if buf <= 0 or rw <= 0 or rh <= 0
        return 0
    end
    r = radius
    if r < 0 r = 0 end
    if r * 2 > rw r = rw / 2 end
    if r * 2 > rh r = rh / 2 end
    if r == 0
        return raster_fill_rect_blend(buf, w, h, x, y, rw, rh, argb)
    end
    // Fast interior horizontal middle band (zero SDF cost)
    raster_fill_rect_blend(buf, w, h, x, y + r, rw, rh - (2 * r), argb)
    // Fast top & bottom inner strips between corners
    raster_fill_rect_blend(buf, w, h, x + r, y, rw - (2 * r), r, argb)
    raster_fill_rect_blend(buf, w, h, x + r, y + rh - r, rw - (2 * r), r, argb)

    base_a = (argb >> 24) & 255
    rgb_mask = argb & 16777215
    // Evaluate 4 rounded corner quadrants via fixed-point (x16) SDF distance
    r16 = r * 16
    cy = 0
    while cy < r
        cx = 0
        while cx < r
            dx16 = ((r - 1 - cx) * 16) + 8
            dy16 = ((r - 1 - cy) * 16) + 8
            dist16 = _sr_isqrt((dx16 * dx16) + (dy16 * dy16))
            cov = 0
            if dist16 <= r16 - 8
                cov = 255
            elif dist16 < r16 + 8
                cov = ((r16 + 8 - dist16) * 255) / 16
            end
            if cov > 0
                eff_a = (base_a * cov + 127) / 255
                col = (eff_a << 24) | rgb_mask
                sr_put_pixel_blend(buf, w, h, x + cx, y + cy, col)
                sr_put_pixel_blend(buf, w, h, x + rw - 1 - cx, y + cy, col)
                sr_put_pixel_blend(buf, w, h, x + cx, y + rh - 1 - cy, col)
                sr_put_pixel_blend(buf, w, h, x + rw - 1 - cx, y + rh - 1 - cy, col)
            end
            cx = cx + 1
        end
        cy = cy + 1
    end
    return 1
end

fn raster_draw_line_aa buf w h x0 y0 x1 y1 argb
    // WHY: Integer fixed-point Xiaolin Wu anti-aliased line rasterizer (zero float division traps).
    if buf <= 0
        return 0
    end
    dx = x1 - x0
    if dx < 0 dx = 0 - dx end
    dy = y1 - y0
    if dy < 0 dy = 0 - dy end
    steep = 0
    if dy > dx
        steep = 1
        t = x0
        x0 = y0
        y0 = t
        t = x1
        x1 = y1
        y1 = t
    end
    if x0 > x1
        t = x0
        x0 = x1
        x1 = t
        t = y0
        y0 = y1
        y1 = t
    end
    dx2 = x1 - x0
    dy2 = y1 - y0
    base_a = (argb >> 24) & 255
    rgb_mask = argb & 16777215
    if dx2 == 0
        if steep == 1
            sr_put_pixel_blend(buf, w, h, y0, x0, argb)
        else
            sr_put_pixel_blend(buf, w, h, x0, y0, argb)
        end
        return 1
    end
    // Fixed-point 16-bit fractional slope
    grad = (dy2 * 65536) / dx2
    intery = y0 * 65536
    x = x0
    while x <= x1
        iy = intery / 65536
        if intery < 0 and (intery % 65536) != 0
            iy = iy - 1
        end
        frac = (intery - (iy * 65536)) / 256
        if frac < 0 frac = 0 end
        if frac > 255 frac = 255 end
        a0 = (base_a * (255 - frac) + 127) / 255
        a1 = (base_a * frac + 127) / 255
        if steep == 1
            sr_put_pixel_blend(buf, w, h, iy, x, (a0 << 24) | rgb_mask)
            sr_put_pixel_blend(buf, w, h, iy + 1, x, (a1 << 24) | rgb_mask)
        else
            sr_put_pixel_blend(buf, w, h, x, iy, (a0 << 24) | rgb_mask)
            sr_put_pixel_blend(buf, w, h, x, iy + 1, (a1 << 24) | rgb_mask)
        end
        intery = intery + grad
        x = x + 1
    end
    return dx2 + 1
end

fn raster_blit_alpha dst dw dh src sw sh dx dy
    if dst <= 0 or src <= 0 or sw <= 0 or sh <= 0
        return 0
    end
    sy = 0
    while sy < sh
        ty = dy + sy
        if ty >= 0 and ty < dh
            sx = 0
            while sx < sw
                tx = dx + sx
                if tx >= 0 and tx < dw
                    px = mem_read_u32(src, ((sy * sw) + sx) * 4)
                    sr_put_pixel_blend(dst, dw, dh, tx, ty, px)
                end
                sx = sx + 1
            end
        end
        sy = sy + 1
    end
    return 1
end

fn raster_blit_glyph_mask dst dw dh mask_buf gw gh dx dy argb
    // WHY: Composites an 8-bit anti-aliased glyph coverage bitmap directly into an ARGB8888 surface.
    if dst <= 0 or mask_buf <= 0 or gw <= 0 or gh <= 0
        return 0
    end
    base_a = (argb >> 24) & 255
    rgb_mask = argb & 16777215
    gy = 0
    while gy < gh
        ty = dy + gy
        if ty >= 0 and ty < dh
            gx = 0
            while gx < gw
                tx = dx + gx
                if tx >= 0 and tx < dw
                    cov = mem_read_byte(mask_buf, (gy * gw) + gx)
                    if cov > 0
                        eff_a = (base_a * cov + 127) / 255
                        sr_put_pixel_blend(dst, dw, dh, tx, ty, (eff_a << 24) | rgb_mask)
                    end
                end
                gx = gx + 1
            end
        end
        gy = gy + 1
    end
    return 1
end
