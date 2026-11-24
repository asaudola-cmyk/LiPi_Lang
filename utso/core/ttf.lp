// ==============================================================================
// LIPI PURE-SILICON TRUETYPE (.TTF / SFNT) FONT ENGINE (utso/core/ttf.lp)
// 100% Pure Lipi | 0% FreeType / HarfBuzz / libc | Direct Binary SFNT + AA Raster
// ==============================================================================
//
// WHY THIS MODULE:
// Parses real TrueType (.ttf) SFNT tables (head, maxp, hhea, hmtx, cmap Format 4 & 12,
// loca 16/32-bit, glyf contours) directly from memory and rasterizes quadratic Bezier
// outlines into 8-bit anti-aliased coverage bitmaps via 4x4 supersampled non-zero
// winding scanlines — ready for utso/core/simd_raster.lp & utso/os/wayland.lp.
// ==============================================================================

include "utso/core/memory.lp"

struct TtfFont
    ttf_data
    ttf_len
    ttf_units_per_em
    ttf_loca_format
    ttf_num_glyphs
    ttf_ascent
    ttf_descent
    ttf_num_hmetrics
    ttf_hmtx_off
    ttf_cmap_off
    ttf_loca_off
    ttf_glyf_off
    ttf_valid
    ttf_gsub_off
    ttf_gpos_off
end

struct TtfGlyphBitmap
    ttf_bm_mask
    ttf_bm_w
    ttf_bm_h
    ttf_bm_xoff
    ttf_bm_yoff
    ttf_bm_advance
    ttf_bm_lsb
    ttf_bm_gid
end

fn _ttf_u16 ptr off
    b0 = mem_read_byte(ptr, off)
    b1 = mem_read_byte(ptr, off + 1)
    return (b0 << 8) | b1
end

fn _ttf_i16 ptr off
    v = _ttf_u16(ptr, off)
    if v >= 32768
        return v - 65536
    end
    return v
end

fn _ttf_u32 ptr off
    b0 = mem_read_byte(ptr, off)
    b1 = mem_read_byte(ptr, off + 1)
    b2 = mem_read_byte(ptr, off + 2)
    b3 = mem_read_byte(ptr, off + 3)
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
end

fn _ttf_tag ptr off c0 c1 c2 c3
    if mem_read_byte(ptr, off) == c0 and mem_read_byte(ptr, off + 1) == c1 and mem_read_byte(ptr, off + 2) == c2 and mem_read_byte(ptr, off + 3) == c3
        return 1
    end
    return 0
end

// ── 1. Load & Parse TrueType SFNT Font File ───────────────────────────────────

fn ttf_load_from_memory data_ptr data_len
    font = TtfFont(data_ptr, data_len, 1000, 0, 0, 800, 0 - 200, 0, 0, 0, 0, 0, 0, 0, 0)
    if data_ptr <= 0 or data_len < 64
        return font
    end
    num_tables = _ttf_u16(data_ptr, 4)
    if num_tables <= 0 or (12 + (num_tables * 16)) > data_len
        return font
    end
    head_off = 0
    maxp_off = 0
    hhea_off = 0
    ti = 0
    while ti < num_tables
        rec = 12 + (ti * 16)
        t_off = _ttf_u32(data_ptr, rec + 8)
        // 'head' = 104,101,97,100
        if _ttf_tag(data_ptr, rec, 104, 101, 97, 100) == 1
            head_off = t_off
        // 'maxp' = 109,97,120,112
        elif _ttf_tag(data_ptr, rec, 109, 97, 120, 112) == 1
            maxp_off = t_off
        // 'hhea' = 104,104,101,97
        elif _ttf_tag(data_ptr, rec, 104, 104, 101, 97) == 1
            hhea_off = t_off
        // 'hmtx' = 104,109,116,120
        elif _ttf_tag(data_ptr, rec, 104, 109, 116, 120) == 1
            font.ttf_hmtx_off = t_off
        // 'cmap' = 99,109,97,112
        elif _ttf_tag(data_ptr, rec, 99, 109, 97, 112) == 1
            font.ttf_cmap_off = t_off
        // 'loca' = 108,111,99,97
        elif _ttf_tag(data_ptr, rec, 108, 111, 99, 97) == 1
            font.ttf_loca_off = t_off
        // 'glyf' = 103,108,121,102
        elif _ttf_tag(data_ptr, rec, 103, 108, 121, 102) == 1
            font.ttf_glyf_off = t_off
        // 'GSUB' = 71,83,85,66
        elif _ttf_tag(data_ptr, rec, 71, 83, 85, 66) == 1
            font.ttf_gsub_off = t_off
        // 'GPOS' = 71,80,79,83
        elif _ttf_tag(data_ptr, rec, 71, 80, 79, 83) == 1
            font.ttf_gpos_off = t_off
        end
        ti = ti + 1
    end
    if head_off == 0 or maxp_off == 0 or font.ttf_cmap_off == 0
        return font
    end
    // Note: CFF/OTF fonts omit loca/glyf while still supporting cmap/hmtx/GSUB/GPOS shaping
    if head_off + 54 <= data_len
        font.ttf_units_per_em = _ttf_u16(data_ptr, head_off + 18)
        font.ttf_loca_format = _ttf_i16(data_ptr, head_off + 50)
    end
    if maxp_off + 6 <= data_len
        font.ttf_num_glyphs = _ttf_u16(data_ptr, maxp_off + 4)
    end
    if hhea_off > 0 and hhea_off + 36 <= data_len
        font.ttf_ascent = _ttf_i16(data_ptr, hhea_off + 4)
        font.ttf_descent = _ttf_i16(data_ptr, hhea_off + 6)
        font.ttf_num_hmetrics = _ttf_u16(data_ptr, hhea_off + 34)
    end
    if font.ttf_units_per_em > 0 and font.ttf_num_glyphs > 0
        font.ttf_valid = 1
    end
    return font
end

fn ttf_load_file path
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        return TtfFont(0, 0, 1000, 0, 0, 800, 0 - 200, 0, 0, 0, 0, 0, 0, 0, 0)
    end
    sz = syscall(8, fd, 0, 2, 0, 0, 0)
    syscall(8, fd, 0, 0, 0, 0, 0)
    if sz <= 64 or sz > 67108864
        syscall(3, fd, 0, 0, 0, 0, 0)
        return TtfFont(0, 0, 1000, 0, 0, 800, 0 - 200, 0, 0, 0, 0, 0, 0, 0, 0)
    end
    buf = malloc(sz)
    got = 0
    while got < sz
        n = syscall(0, fd, buf + got, sz - got, 0, 0, 0)
        if n <= 0 break end
        got = got + n
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    return ttf_load_from_memory(buf, got)
end

fn ttf_free_font font
    if font.ttf_data > 0 and font.ttf_len > 0
        free(font.ttf_data, font.ttf_len)
        font.ttf_data = 0
        font.ttf_valid = 0
    end
    return 0
end

// ── 2. Unicode Codepoint -> Glyph Index (cmap Format 12 & Format 4) ───────────

fn ttf_find_glyph font codepoint
    if font.ttf_valid == 0
        return 0
    end
    d = font.ttf_data
    dlen = font.ttf_len
    cmap = font.ttf_cmap_off
    if cmap + 4 > dlen
        return 0
    end
    ntab = _ttf_u16(d, cmap + 2)
    fmt12_off = 0
    fmt4_off = 0
    i = 0
    while i < ntab
        rec = cmap + 4 + (i * 8)
        if rec + 8 > dlen break end
        plat = _ttf_u16(d, rec)
        enc = _ttf_u16(d, rec + 2)
        sub = cmap + _ttf_u32(d, rec + 4)
        if sub + 4 <= dlen
            fmt = _ttf_u16(d, sub)
            if fmt == 12 and (plat == 3 or plat == 0)
                fmt12_off = sub
            elif fmt == 4 and (plat == 3 or plat == 0)
                if fmt4_off == 0 or (plat == 3 and enc == 1)
                    fmt4_off = sub
                end
            end
        end
        i = i + 1
    end

    // Prefer Format 12 (Full Unicode, including Bengali & Supplementary planes)
    if fmt12_off > 0 and fmt12_off + 16 <= dlen
        ngroups = _ttf_u32(d, fmt12_off + 12)
        lo = 0
        hi = ngroups - 1
        while lo <= hi
            mid = (lo + hi) / 2
            grec = fmt12_off + 16 + (mid * 12)
            if grec + 12 > dlen break end
            sc = _ttf_u32(d, grec)
            ec = _ttf_u32(d, grec + 4)
            if codepoint < sc
                hi = mid - 1
            elif codepoint > ec
                lo = mid + 1
            else
                sg = _ttf_u32(d, grec + 8)
                return sg + (codepoint - sc)
            end
        end
    end

    // Format 4 (BMP Unicode)
    if fmt4_off > 0 and fmt4_off + 14 <= dlen and codepoint <= 65535
        seg2 = _ttf_u16(d, fmt4_off + 6)
        seg_cnt = seg2 / 2
        end_base = fmt4_off + 14
        start_base = end_base + seg2 + 2
        delta_base = start_base + seg2
        range_base = delta_base + seg2
        si = 0
        while si < seg_cnt
            ec = _ttf_u16(d, end_base + (si * 2))
            if codepoint <= ec
                sc = _ttf_u16(d, start_base + (si * 2))
                if codepoint >= sc
                    ro = _ttf_u16(d, range_base + (si * 2))
                    delta = _ttf_i16(d, delta_base + (si * 2))
                    if ro == 0
                        return (codepoint + delta) & 65535
                    else
                        gptr = range_base + (si * 2) + ro + ((codepoint - sc) * 2)
                        if gptr + 2 <= dlen
                            gid = _ttf_u16(d, gptr)
                            if gid == 0 return 0 end
                            return (gid + delta) & 65535
                        end
                    end
                end
                return 0
            end
            si = si + 1
        end
    end
    return 0
end

fn ttf_get_hmetrics font gid
    if font.ttf_valid == 0 or font.ttf_hmtx_off == 0 or font.ttf_num_hmetrics <= 0
        return [font.ttf_units_per_em / 2, 0]
    end
    d = font.ttf_data
    hm = font.ttf_hmtx_off
    nhm = font.ttf_num_hmetrics
    if gid < nhm
        adv = _ttf_u16(d, hm + (gid * 4))
        lsb = _ttf_i16(d, hm + (gid * 4) + 2)
        return [adv, lsb]
    end
    adv = _ttf_u16(d, hm + ((nhm - 1) * 4))
    lsb = _ttf_i16(d, hm + (nhm * 4) + ((gid - nhm) * 2))
    return [adv, lsb]
end

// ── 3. Glyph Outline Extraction & 4x4 Anti-Aliased Scanline Rasterizer ────────

fn _ttf_add_quad_edges e_x0 e_y0 e_x1 e_y1 ax ay cx cy bx by
    // WHY: Flattens quadratic Bezier (A, C, B) into 8 exact segments in 4x subpixel coordinates.
    px = ax
    py = ay
    step = 1
    while step <= 8
        t = step
        u = 8 - step
        // (u^2 * A + 2*u*t * C + t^2 * B) / 64
        nx = ((u * u * ax) + (2 * u * t * cx) + (t * t * bx) + 32) / 64
        ny = ((u * u * ay) + (2 * u * t * cy) + (t * t * by) + 32) / 64
        if py != ny
            push(e_x0, px)
            push(e_y0, py)
            push(e_x1, nx)
            push(e_y1, ny)
        end
        px = nx
        py = ny
        step = step + 1
    end
    return 0
end

fn ttf_rasterize_glyph font codepoint px_height
    gid = ttf_find_glyph(font, codepoint)
    return ttf_rasterize_gid(font, gid, px_height)
end

fn ttf_rasterize_gid font gid px_height
    hm = ttf_get_hmetrics(font, gid)
    upem = font.ttf_units_per_em
    if upem <= 0 upem = 1000 end
    adv_px = (hm[0] * px_height + (upem / 2)) / upem
    lsb_px = (hm[1] * px_height) / upem
    empty_bm = TtfGlyphBitmap(0, 0, 0, lsb_px, 0, adv_px, lsb_px, gid)
    if font.ttf_valid == 0 or font.ttf_loca_off == 0 or font.ttf_glyf_off == 0 or gid < 0 or gid >= font.ttf_num_glyphs
        return empty_bm
    end

    d = font.ttf_data
    dlen = font.ttf_len
    loca = font.ttf_loca_off
    g0 = 0
    g1 = 0
    if font.ttf_loca_format == 0
        g0 = _ttf_u16(d, loca + (gid * 2)) * 2
        g1 = _ttf_u16(d, loca + ((gid + 1) * 2)) * 2
    else
        g0 = _ttf_u32(d, loca + (gid * 4))
        g1 = _ttf_u32(d, loca + ((gid + 1) * 4))
    end
    if g1 <= g0
        return empty_bm
    end
    goff = font.ttf_glyf_off + g0
    if goff + 10 > dlen
        return empty_bm
    end
    n_contours = _ttf_i16(d, goff)
    if n_contours <= 0
        // Compound or empty glyph
        return empty_bm
    end
    gx_min = _ttf_i16(d, goff + 2)
    gy_min = _ttf_i16(d, goff + 4)
    gx_max = _ttf_i16(d, goff + 6)
    gy_max = _ttf_i16(d, goff + 8)

    // Parse contour end indices
    end_pts = list()
    ci = 0
    while ci < n_contours
        push(end_pts, _ttf_u16(d, goff + 10 + (ci * 2)))
        ci = ci + 1
    end
    num_pts = end_pts[n_contours - 1] + 1
    inst_len = _ttf_u16(d, goff + 10 + (n_contours * 2))
    cur = goff + 12 + (n_contours * 2) + inst_len

    // Parse point flags (with RLE repeat bit 0x08)
    flags = list()
    while len(flags) < num_pts and cur < dlen
        fl = mem_read_byte(d, cur)
        cur = cur + 1
        push(flags, fl)
        if (fl & 8) != 0 and cur < dlen
            rep = mem_read_byte(d, cur)
            cur = cur + 1
            ri = 0
            while ri < rep and len(flags) < num_pts
                push(flags, fl)
                ri = ri + 1
            end
        end
    end

    // Parse X coordinates
    xs = list()
    x_acc = 0
    pi = 0
    while pi < num_pts
        fl = flags[pi]
        if (fl & 2) != 0
            dx = mem_read_byte(d, cur)
            cur = cur + 1
            if (fl & 16) != 0
                x_acc = x_acc + dx
            else
                x_acc = x_acc - dx
            end
        else
            if (fl & 16) == 0
                x_acc = x_acc + _ttf_i16(d, cur)
                cur = cur + 2
            end
        end
        push(xs, x_acc)
        pi = pi + 1
    end

    // Parse Y coordinates
    ys = list()
    y_acc = 0
    pi = 0
    while pi < num_pts
        fl = flags[pi]
        if (fl & 4) != 0
            dy = mem_read_byte(d, cur)
            cur = cur + 1
            if (fl & 32) != 0
                y_acc = y_acc + dy
            else
                y_acc = y_acc - dy
            end
        else
            if (fl & 32) == 0
                y_acc = y_acc + _ttf_i16(d, cur)
                cur = cur + 2
            end
        end
        push(ys, y_acc)
        pi = pi + 1
    end

    // Compute pixel bounding box (with 1px AA margin)
    scale4 = px_height * 4
    px_min = (gx_min * px_height) / upem - 1
    px_max = ((gx_max * px_height) + upem - 1) / upem + 1
    py_min = (gy_min * px_height) / upem - 1
    py_max = ((gy_max * px_height) + upem - 1) / upem + 1
    gw = px_max - px_min + 1
    gh = py_max - py_min + 1
    if gw <= 0 or gh <= 0 or gw > 512 or gh > 512
        return empty_bm
    end

    // Scale coordinates into 4x subpixel space (Y flipped so top = 0)
    sxs = list()
    sys = list()
    pi = 0
    while pi < num_pts
        sx4 = ((xs[pi] * scale4) / upem) - (px_min * 4)
        sy4 = (py_max * 4) - ((ys[pi] * scale4) / upem)
        push(sxs, sx4)
        push(sys, sy4)
        pi = pi + 1
    end

    // Extract flattened line edges from all contours (handling implicit on-curve midpoints)
    e_x0 = list()
    e_y0 = list()
    e_x1 = list()
    e_y1 = list()
    c_start = 0
    ci = 0
    while ci < n_contours
        c_end = end_pts[ci]
        c_len = c_end - c_start + 1
        if c_len >= 2
            // Expand contour points with explicit on-curve anchors
            c_px = list()
            c_py = list()
            c_on = list()
            // Determine starting on-curve point
            f0 = flags[c_start] & 1
            flast = flags[c_end] & 1
            idx_k = 0
            if f0 == 1
                push(c_px, sxs[c_start])
                push(c_py, sys[c_start])
                push(c_on, 1)
                idx_k = 1
            elif flast == 1
                push(c_px, sxs[c_end])
                push(c_py, sys[c_end])
                push(c_on, 1)
                idx_k = 0
            else
                push(c_px, (sxs[c_start] + sxs[c_end]) / 2)
                push(c_py, (sys[c_start] + sys[c_end]) / 2)
                push(c_on, 1)
                idx_k = 0
            end
            limit_k = c_len
            if f0 == 0 and flast == 1
                limit_k = c_len - 1
            end
            while idx_k < limit_k
                pt_i = c_start + idx_k
                cur_on = flags[pt_i] & 1
                prev_on = c_on[len(c_on) - 1]
                if cur_on == 0 and prev_on == 0
                    // Implicit on-curve midpoint between two consecutive off-curve points
                    mx = (c_px[len(c_px) - 1] + sxs[pt_i]) / 2
                    my = (c_py[len(c_py) - 1] + sys[pt_i]) / 2
                    push(c_px, mx)
                    push(c_py, my)
                    push(c_on, 1)
                end
                push(c_px, sxs[pt_i])
                push(c_py, sys[pt_i])
                push(c_on, cur_on)
                idx_k = idx_k + 1
            end
            // Close contour back to first on-curve anchor
            if c_on[len(c_on) - 1] == 0
                push(c_px, c_px[0])
                push(c_py, c_py[0])
                push(c_on, 1)
            else
                push(c_px, c_px[0])
                push(c_py, c_py[0])
                push(c_on, 1)
            end
            // Emit line or quadratic Bezier edges
            ei = 0
            cn = len(c_px)
            while ei + 1 < cn
                if c_on[ei + 1] == 1
                    if c_py[ei] != c_py[ei + 1]
                        push(e_x0, c_px[ei])
                        push(e_y0, c_py[ei])
                        push(e_x1, c_px[ei + 1])
                        push(e_y1, c_py[ei + 1])
                    end
                    ei = ei + 1
                elif ei + 2 < cn
                    _ttf_add_quad_edges(e_x0, e_y0, e_x1, e_y1, c_px[ei], c_py[ei], c_px[ei + 1], c_py[ei + 1], c_px[ei + 2], c_py[ei + 2])
                    ei = ei + 2
                else
                    ei = ei + 1
                end
            end
        end
        c_start = c_end + 1
        ci = ci + 1
    end

    // 4x4 supersampled non-zero winding scanline rasterizer
    mask = malloc(gw * gh)
    mem_zero(mask, gw * gh)
    n_edges = len(e_x0)
    sub_h = gh * 4
    sub_w = gw * 4
    // Scratch coverage row (gw bytes per scanline)
    row_cov = malloc(gw)

    py = 0
    while py < gh
        mem_zero(row_cov, gw)
        sub_y = 0
        while sub_y < 4
            scan_y = (py * 4) + sub_y
            ixs = list()
            idirs = list()
            ei = 0
            while ei < n_edges
                y0 = e_y0[ei]
                y1 = e_y1[ei]
                if (y0 <= scan_y and y1 > scan_y) or (y1 <= scan_y and y0 > scan_y)
                    x0 = e_x0[ei]
                    x1 = e_x1[ei]
                    ix = x0 + (((scan_y - y0) * (x1 - x0)) / (y1 - y0))
                    dir = 1
                    if y1 < y0 dir = 0 - 1 end
                    push(ixs, ix)
                    push(idirs, dir)
                end
                ei = ei + 1
            end
            // Insertion sort X intersections
            ni = len(ixs)
            si = 1
            while si < ni
                kx = ixs[si]
                kd = idirs[si]
                sj = si - 1
                while sj >= 0 and ixs[sj] > kx
                    list_set(ixs, sj + 1, ixs[sj])
                    list_set(idirs, sj + 1, idirs[sj])
                    sj = sj - 1
                end
                list_set(ixs, sj + 1, kx)
                list_set(idirs, sj + 1, kd)
                si = si + 1
            end
            // Fill spans where winding != 0
            wind = 0
            si = 0
            while si < ni
                wind = wind + idirs[si]
                if wind != 0 and si + 1 < ni
                    sx_a = ixs[si]
                    sx_b = ixs[si + 1]
                    if sx_a < 0 sx_a = 0 end
                    if sx_b > sub_w sx_b = sub_w end
                    sx = sx_a
                    while sx < sx_b
                        px_i = sx / 4
                        if px_i >= 0 and px_i < gw
                            mem_write_byte(row_cov, px_i, mem_read_byte(row_cov, px_i) + 1)
                        end
                        sx = sx + 1
                    end
                end
                si = si + 1
            end
            sub_y = sub_y + 1
        end
        // Convert 0..16 supersample hit counts into 0..255 alpha coverage
        px = 0
        while px < gw
            hits = mem_read_byte(row_cov, px)
            if hits > 16 hits = 16 end
            if hits > 0
                mem_write_byte(mask, (py * gw) + px, (hits * 255) / 16)
            end
            px = px + 1
        end
        py = py + 1
    end
    free(row_cov, gw)
    return TtfGlyphBitmap(mask, gw, gh, px_min, 0 - py_max, adv_px, lsb_px, gid)
end

fn ttf_free_bitmap bm
    if bm.ttf_bm_mask > 0 and bm.ttf_bm_w > 0 and bm.ttf_bm_h > 0
        free(bm.ttf_bm_mask, bm.ttf_bm_w * bm.ttf_bm_h)
        bm.ttf_bm_mask = 0
    end
    return 0
end
