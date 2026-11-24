// ==============================================================================
// LIPI PURE-KERNEL HARDWARE & MEDIA CORE REGRESSION TEST
// 100% Pure Lipi | 0% C / libc / ld.so / libwayland / FreeType / libpng / zlib
// ==============================================================================
// Covers Pillar 4 end-to-end:
//   1. utso/os/wayland.lp     — SYS_memfd_create + SYS_socketpair(AF_UNIX) +
//                               SCM_RIGHTS FD handoff + zero-copy MAP_SHARED +
//                               xdg_wm_base ping/pong wire dispatch.
//   2. utso/core/simd_raster.lp — 64-bit clear, SDF AA rounded rect, Porter-Duff
//                               SRC_OVER blending, Xiaolin Wu AA line, 8-bit glyph blit.
//   3. utso/core/ttf.lp       — Self-contained spec-compliant SFNT .ttf (cmap fmt 4,
//                               32-bit loca, hmtx, glyf quadratic Bezier contour) +
//                               4x4 supersampled AA scanline rasterizer (+ optional system font).
//   4. utso/core/png.lp       — Pure-Lipi PNG encode + RFC 1950/1951 DEFLATE Inflate
//                               bit-exact roundtrip + real compressed icon.png decode.
// ==============================================================================

include "utso/os/wayland.lp"
include "utso/core/simd_raster.lp"
include "utso/core/ttf.lp"
include "utso/core/png.lp"

fn _sfnt_w16 ptr off val
    v = val & 65535
    mem_write_byte(ptr, off, (v >> 8) & 255)
    mem_write_byte(ptr, off + 1, v & 255)
    return 0
end

fn _sfnt_w32 ptr off val
    mem_write_byte(ptr, off, (val >> 24) & 255)
    mem_write_byte(ptr, off + 1, (val >> 16) & 255)
    mem_write_byte(ptr, off + 2, (val >> 8) & 255)
    mem_write_byte(ptr, off + 3, val & 255)
    return 0
end

fn _sfnt_wtag ptr off c0 c1 c2 c3
    mem_write_byte(ptr, off, c0)
    mem_write_byte(ptr, off + 1, c1)
    mem_write_byte(ptr, off + 2, c2)
    mem_write_byte(ptr, off + 3, c3)
    return 0
end

fn _sfnt_wrec ptr idx c0 c1 c2 c3 t_off t_len
    rec = 12 + (idx * 16)
    _sfnt_wtag(ptr, rec, c0, c1, c2, c3)
    _sfnt_w32(ptr, rec + 4, 0)
    _sfnt_w32(ptr, rec + 8, t_off)
    _sfnt_w32(ptr, rec + 12, t_len)
    return 0
end

fn build_synthetic_sfnt_ttf()
    // WHY: Guarantees deterministic TrueType parsing & quadratic Bezier AA rasterization
    // even on minimal container CI runners that ship with zero system fonts.
    sz = 512
    buf = malloc(sz)
    zi = 0
    while zi < sz
        mem_write_byte(buf, zi, 0)
        zi = zi + 1
    end

    // SFNT Offset Table (12 bytes): TrueType sfntVersion 0x00010000, 7 tables
    _sfnt_w32(buf, 0, 65536)
    _sfnt_w16(buf, 4, 7)
    _sfnt_w16(buf, 6, 64)
    _sfnt_w16(buf, 8, 2)
    _sfnt_w16(buf, 10, 48)

    // Table Directory (7 entries at 12..123)
    _sfnt_wrec(buf, 0, 99, 109, 97, 112, 272, 64)    // 'cmap'
    _sfnt_wrec(buf, 1, 103, 108, 121, 102, 352, 48)  // 'glyf'
    _sfnt_wrec(buf, 2, 104, 101, 97, 100, 128, 54)   // 'head'
    _sfnt_wrec(buf, 3, 104, 104, 101, 97, 208, 36)   // 'hhea'
    _sfnt_wrec(buf, 4, 104, 109, 116, 120, 256, 8)   // 'hmtx'
    _sfnt_wrec(buf, 5, 108, 111, 99, 97, 336, 12)    // 'loca'
    _sfnt_wrec(buf, 6, 109, 97, 120, 112, 192, 6)    // 'maxp'

    // 'head' at 128: unitsPerEm=1000 (+18), indexToLocFormat=1 (+50, 32-bit loca)
    _sfnt_w16(buf, 128 + 18, 1000)
    _sfnt_w16(buf, 128 + 50, 1)

    // 'maxp' at 192: numGlyphs=2 (+4)
    _sfnt_w32(buf, 192, 65536)
    _sfnt_w16(buf, 192 + 4, 2)

    // 'hhea' at 208: ascent=800 (+4), descent=-200 (+6), numberOfHMetrics=2 (+34)
    _sfnt_w16(buf, 208 + 4, 800)
    _sfnt_w16(buf, 208 + 6, 65336)
    _sfnt_w16(buf, 208 + 34, 2)

    // 'hmtx' at 256: gid0=(500, 0), gid1=(700, 50)
    _sfnt_w16(buf, 256, 500)
    _sfnt_w16(buf, 256 + 2, 0)
    _sfnt_w16(buf, 256 + 4, 700)
    _sfnt_w16(buf, 256 + 6, 50)

    // 'cmap' at 272: 1 subtable (Platform 3, Encoding 1, Format 4 at cmap+12)
    _sfnt_w16(buf, 272, 0)
    _sfnt_w16(buf, 272 + 2, 1)
    _sfnt_w16(buf, 272 + 4, 3)
    _sfnt_w16(buf, 272 + 6, 1)
    _sfnt_w32(buf, 272 + 8, 12)
    sub = 272 + 12
    _sfnt_w16(buf, sub, 4)         // format = 4
    _sfnt_w16(buf, sub + 2, 32)    // length
    _sfnt_w16(buf, sub + 4, 0)     // language
    _sfnt_w16(buf, sub + 6, 4)     // segCountX2 = 4 (2 segments)
    // endCount = [65 ('A'), 65535]
    _sfnt_w16(buf, sub + 14, 65)
    _sfnt_w16(buf, sub + 16, 65535)
    // reservedPad = 0 at +18
    // startCount = [65 ('A'), 65535]
    _sfnt_w16(buf, sub + 20, 65)
    _sfnt_w16(buf, sub + 22, 65535)
    // idDelta = [-64 (65472), 1] -> (65 + (-64)) & 65535 = 1
    _sfnt_w16(buf, sub + 24, 65472)
    _sfnt_w16(buf, sub + 26, 1)
    // idRangeOffset = [0, 0]
    _sfnt_w16(buf, sub + 28, 0)
    _sfnt_w16(buf, sub + 30, 0)

    // 'loca' at 336 (32-bit offsets): gid0=[0..0], gid1=[0..48]
    _sfnt_w32(buf, 336, 0)
    _sfnt_w32(buf, 336 + 4, 0)
    _sfnt_w32(buf, 336 + 8, 48)

    // 'glyf' at 352: simple glyph (1 contour, 4 pts with off-curve quadratic Bezier apex)
    g = 352
    _sfnt_w16(buf, g, 1)           // numberOfContours = 1
    _sfnt_w16(buf, g + 2, 100)     // xMin
    _sfnt_w16(buf, g + 4, 0)       // yMin
    _sfnt_w16(buf, g + 6, 600)     // xMax
    _sfnt_w16(buf, g + 8, 700)     // yMax
    _sfnt_w16(buf, g + 10, 3)      // endPtsOfContours[0] = 3 (4 points)
    _sfnt_w16(buf, g + 12, 0)      // instructionLength = 0
    // Flags: pt0 on-curve(1), pt1 on-curve(1), pt2 off-curve(0), pt3 on-curve(1)
    mem_write_byte(buf, g + 14, 1)
    mem_write_byte(buf, g + 15, 1)
    mem_write_byte(buf, g + 16, 0)
    mem_write_byte(buf, g + 17, 1)
    // X deltas (i16): +100, +500, -250, -250 -> x = 100, 600, 350, 100
    _sfnt_w16(buf, g + 18, 100)
    _sfnt_w16(buf, g + 20, 500)
    _sfnt_w16(buf, g + 22, 65286)  // -250
    _sfnt_w16(buf, g + 24, 65286)  // -250
    // Y deltas (i16): 0, 0, +700, -350 -> y = 0, 0, 700, 350
    _sfnt_w16(buf, g + 26, 0)
    _sfnt_w16(buf, g + 28, 0)
    _sfnt_w16(buf, g + 30, 700)
    _sfnt_w16(buf, g + 32, 65186)  // -350

    return buf
end

fn main()
    // ── 1. Wayland memfd MAP_SHARED Framebuffer (320x120) ─────────────────────
    shm = wl_shm_alloc_buffer(320, 120)
    if shm.wl_fd < 0 or shm.wl_pixels <= 0
        say "FAIL 1: wl_shm_alloc_buffer"
        return 1
    end

    // ── 2. Pure-Lipi 2D Software Rasterizer & Compositor ──────────────────────
    bg = sr_pack_argb(255, 18, 22, 34)
    raster_clear_argb(shm.wl_pixels, 320, 120, bg)
    card_col = sr_pack_argb(255, 40, 88, 180)
    raster_fill_rounded_rect(shm.wl_pixels, 320, 120, 16, 16, 288, 88, 14, card_col)
    overlay_col = sr_pack_argb(128, 255, 255, 255)
    raster_fill_rect_blend(shm.wl_pixels, 320, 120, 24, 24, 100, 32, overlay_col)
    line_col = sr_pack_argb(255, 255, 190, 60)
    raster_draw_line_aa(shm.wl_pixels, 320, 120, 20, 96, 295, 28, line_col)

    // Verify Porter-Duff SRC_OVER alpha blend at (40, 40)
    blended = sr_get_pixel(shm.wl_pixels, 320, 120, 40, 40)
    br = (blended >> 16) & 255
    if br < 140 or br > 155
        say "FAIL 2: Porter-Duff SRC_OVER R=" + str(br)
        wl_shm_free_buffer(shm)
        return 2
    end

    // ── 3. Pure-Lipi TrueType Font Engine (Self-Contained SFNT + AA Bezier) ───
    sfnt_buf = build_synthetic_sfnt_ttf()
    sfont = ttf_load_from_memory(sfnt_buf, 512)
    if sfont.ttf_valid != 1 or sfont.ttf_units_per_em != 1000 or sfont.ttf_num_glyphs != 2
        say "FAIL 3a: synthetic SFNT font parse"
        ttf_free_font(sfont)
        wl_shm_free_buffer(shm)
        return 3
    end
    gid_a = ttf_find_glyph(sfont, 65)
    if gid_a != 1
        say "FAIL 3b: cmap Format 4 lookup gid=" + str(gid_a)
        ttf_free_font(sfont)
        wl_shm_free_buffer(shm)
        return 3
    end
    sbm = ttf_rasterize_glyph(sfont, 65, 48)
    s_ink = 0
    s_aa = 0
    if sbm.ttf_bm_mask > 0 and sbm.ttf_bm_w > 0 and sbm.ttf_bm_h > 0
        bi = 0
        bn = sbm.ttf_bm_w * sbm.ttf_bm_h
        while bi < bn
            cov = mem_read_byte(sbm.ttf_bm_mask, bi)
            if cov > 0 s_ink = s_ink + 1 end
            if cov > 0 and cov < 255 s_aa = s_aa + 1 end
            bi = bi + 1
        end
        raster_blit_glyph_mask(shm.wl_pixels, 320, 120, sbm.ttf_bm_mask, sbm.ttf_bm_w, sbm.ttf_bm_h, 150 + sbm.ttf_bm_xoff, 78 + sbm.ttf_bm_yoff, sr_pack_argb(255, 255, 255, 255))
        ttf_free_bitmap(sbm)
    end
    ttf_free_font(sfont)
    if s_ink < 50 or s_aa < 10
        say "FAIL 3c: TTF quadratic Bezier AA coverage ink=" + str(s_ink) + " aa=" + str(s_aa)
        wl_shm_free_buffer(shm)
        return 3
    end
    say "TTF Engine (SFNT cmap4 + 32b loca + Bezier 4x4 AA): ink=" + str(s_ink) + " aa_edges=" + str(s_aa) + " PASS"

    // ── 4. Wayland AF_UNIX + SCM_RIGHTS FD Handoff + Zero-Copy Verify ─────────
    sv = malloc(16)
    rc_sp = syscall(53, WL_AF_UNIX, WL_SOCK_STREAM, 0, sv, 0, 0)
    if rc_sp < 0
        say "FAIL 4a: SYS_socketpair"
        free(sv, 16)
        wl_shm_free_buffer(shm)
        return 4
    end
    fd_cli = _wl_read_u32(sv, 0)
    fd_srv = _wl_read_u32(sv, 4)
    free(sv, 16)

    cli = wl_client_new(fd_cli)
    cli.wl_shm_id = 4
    cli.wl_compositor_id = 3
    cli.wl_xdg_base_id = 5
    pool_id = wl_req_shm_create_pool(cli, shm)
    if pool_id <= 0
        say "FAIL 4b: wl_req_shm_create_pool"
        return 4
    end

    rx_buf = malloc(256)
    rx_fd_box = [0 - 1]
    got_wl = wl_recv_raw(fd_srv, rx_buf, 256, rx_fd_box)
    rx_fd = rx_fd_box[0]
    if got_wl != 16 or rx_fd < 0
        say "FAIL 4c: SCM_RIGHTS recv got=" + str(got_wl) + " rx_fd=" + str(rx_fd)
        return 4
    end
    srv_px = syscall(9, 0, shm.wl_size, WL_PROT_RW, WL_MAP_SHARED, rx_fd, 0)
    if srv_px <= 0 or mem_read_u32(srv_px, ((40 * 320) + 40) * 4) != blended
        say "FAIL 4d: zero-copy memfd pixel mismatch across SCM_RIGHTS"
        return 4
    end
    syscall(11, srv_px, shm.wl_size, 0, 0, 0, 0)
    syscall(3, rx_fd, 0, 0, 0, 0, 0)

    ev = malloc(16)
    _wl_write_u32(ev, 0, cli.wl_xdg_base_id)
    _wl_write_u32(ev, 4, (12 << 16) | 0)
    _wl_write_u32(ev, 8, 42)
    wl_dispatch_events(cli, ev, 12)
    free(ev, 16)
    got_pong = wl_recv_raw(fd_srv, rx_buf, 256, 0)
    pong_op = _wl_read_u32(rx_buf, 4) & 65535
    pong_ser = _wl_read_u32(rx_buf, 8)
    free(rx_buf, 256)
    syscall(3, fd_cli, 0, 0, 0, 0, 0)
    syscall(3, fd_srv, 0, 0, 0, 0, 0)
    if got_pong != 12 or pong_op != XDG_WM_BASE_PONG or pong_ser != 42
        say "FAIL 4e: xdg_wm_base pong mismatch"
        wl_shm_free_buffer(shm)
        return 4
    end
    say "Wayland Wire + SCM_RIGHTS Zero-Copy + xdg_wm_base Ping/Pong: PASS"

    // ── 5. Pure-Lipi PNG Encode + RFC 1950/1951 Inflate Decode Roundtrip ──────
    plen_box = [0]
    png_ptr = png_encode_argb(shm.wl_pixels, 320, 120, plen_box)
    png_len = plen_box[0]
    if png_ptr <= 0 or png_len < 100
        say "FAIL 5a: png_encode_argb"
        wl_shm_free_buffer(shm)
        return 5
    end
    dec = png_decode_to_argb(png_ptr, png_len)
    free(png_ptr, png_len)
    if dec.png_valid != 1 or dec.png_width != 320 or dec.png_height != 120
        say "FAIL 5b: png_decode_to_argb roundtrip"
        wl_shm_free_buffer(shm)
        return 5
    end
    mismatches = 0
    pi = 0
    while pi < 320 * 120
        if mem_read_u32(dec.png_pixels, pi * 4) != mem_read_u32(shm.wl_pixels, pi * 4)
            mismatches = mismatches + 1
        end
        pi = pi + 1
    end
    png_free_image(dec)
    wl_shm_free_buffer(shm)
    if mismatches != 0
        say "FAIL 5c: PNG roundtrip pixel mismatches=" + str(mismatches)
        return 5
    end
    say "PNG Encode+Decode 320x120 Bit-Exact Roundtrip (38400/38400 px): PASS"

    // ── 6. Real Compressed PNG Decode (Dynamic/Fixed Huffman + LZ77 + Filters) ─
    ifd = syscall(2, "editors/vscode/icons/icon.png", 0, 0, 0, 0, 0)
    if ifd < 0
        say "FAIL 6a: could not open editors/vscode/icons/icon.png"
        return 6
    end
    isz = syscall(8, ifd, 0, 2, 0, 0, 0)
    syscall(8, ifd, 0, 0, 0, 0, 0)
    ibuf = malloc(isz)
    ig = 0
    while ig < isz
        n = syscall(0, ifd, ibuf + ig, isz - ig, 0, 0, 0)
        if n <= 0 break end
        ig = ig + n
    end
    syscall(3, ifd, 0, 0, 0, 0, 0)
    icon = png_decode_to_argb(ibuf, ig)
    free(ibuf, isz)
    if icon.png_valid != 1 or icon.png_width != 128 or icon.png_height != 128
        say "FAIL 6b: real compressed icon.png inflate decode"
        return 6
    end
    png_free_image(icon)
    say "PNG Real Compressed Inflate (editors/vscode/icons/icon.png 128x128): PASS"

    say "PURE-KERNEL HARDWARE & MEDIA CORE REGRESSION PASSED!"
    return 0
end
