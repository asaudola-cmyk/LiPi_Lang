// ==============================================================================
// LIPI PURE-SILICON PNG & RFC 1951 DEFLATE CODEC (utso/core/png.lp)
// 100% Pure Lipi | 0% libpng / 0% zlib / 0% libc | Full Encode + Inflate Decode
// ==============================================================================
//
// WHY THIS MODULE:
// Implements RFC 2083 PNG encoding/decoding + RFC 1950 zlib + FULL RFC 1951
// DEFLATE inflate (Stored Type 0, Fixed Huffman Type 1, Dynamic Huffman Type 2,
// LZ77 sliding window), IEEE CRC-32, Adler-32, and all 5 PNG scanline filters
// (None, Sub, Up, Average, Paeth) directly on raw ARGB8888 pixel framebuffers.
// ==============================================================================

include "utso/core/memory.lp"

struct PngImage
    png_pixels
    png_width
    png_height
    png_valid
end

// ── 1. Big-Endian Byte Helpers, IEEE CRC-32 & Adler-32 ────────────────────────

fn _png_u32_be ptr off
    b0 = mem_read_byte(ptr, off)
    b1 = mem_read_byte(ptr, off + 1)
    b2 = mem_read_byte(ptr, off + 2)
    b3 = mem_read_byte(ptr, off + 3)
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
end

fn _png_write_u32_be ptr off val
    mem_write_byte(ptr, off, (val >> 24) & 255)
    mem_write_byte(ptr, off + 1, (val >> 16) & 255)
    mem_write_byte(ptr, off + 2, (val >> 8) & 255)
    mem_write_byte(ptr, off + 3, val & 255)
    return 4
end

fn png_crc32 ptr start_off length
    // WHY: Standard IEEE 802.3 CRC-32 (reflected polynomial 0xEDB88320 = 3988292384).
    crc = 4294967295
    i = 0
    while i < length
        b = mem_read_byte(ptr, start_off + i)
        crc = crc ^ b
        bit = 0
        while bit < 8
            if (crc & 1) != 0
                crc = (crc >> 1) ^ 3988292384
            else
                crc = crc >> 1
            end
            bit = bit + 1
        end
        i = i + 1
    end
    return (crc ^ 4294967295) & 4294967295
end

fn png_adler32 ptr start_off length
    // WHY: RFC 1950 Adler-32 rolling checksum modulo 65521.
    s1 = 1
    s2 = 0
    i = 0
    while i < length
        s1 = (s1 + mem_read_byte(ptr, start_off + i)) % 65521
        s2 = (s2 + s1) % 65521
        i = i + 1
    end
    return ((s2 << 16) | s1) & 4294967295
end

// ── 2. PNG Encoder (ARGB8888 -> RFC 2083 RGBA PNG File Buffer) ────────────────

fn png_encode_argb argb_buf width height out_len_box
    // WHY: Encodes raw ARGB8888 framebuffer into a standards-compliant RGBA PNG binary
    // with RFC 1950 zlib stored blocks, Adler-32, and IEEE CRC-32 chunk verification.
    if argb_buf <= 0 or width <= 0 or height <= 0
        if out_len_box != 0 list_set(out_len_box, 0, 0) end
        return 0
    end
    row_bytes = 1 + (width * 4)
    raw_len = row_bytes * height
    raw_scan = malloc(raw_len)
    y = 0
    while y < height
        ro = y * row_bytes
        mem_write_byte(raw_scan, ro, 0) // Filter 0 (None)
        x = 0
        while x < width
            px = mem_read_u32(argb_buf, ((y * width) + x) * 4)
            pa = (px >> 24) & 255
            pr = (px >> 16) & 255
            pg = (px >> 8) & 255
            pb = px & 255
            dst_o = ro + 1 + (x * 4)
            mem_write_byte(raw_scan, dst_o, pr)
            mem_write_byte(raw_scan, dst_o + 1, pg)
            mem_write_byte(raw_scan, dst_o + 2, pb)
            mem_write_byte(raw_scan, dst_o + 3, pa)
            x = x + 1
        end
        y = y + 1
    end

    // Compute RFC 1950 zlib stream size using 65535-byte stored DEFLATE blocks
    num_blocks = (raw_len + 65534) / 65535
    if num_blocks < 1 num_blocks = 1 end
    zlib_len = 2 + raw_len + (num_blocks * 5) + 4
    // Total PNG: 8(sig) + 25(IHDR) + (12 + zlib_len)(IDAT) + 12(IEND)
    total_len = 8 + 25 + 12 + zlib_len + 12
    out = malloc(total_len)

    // 1. PNG 8-byte signature
    mem_write_byte(out, 0, 137)
    mem_write_byte(out, 1, 80)
    mem_write_byte(out, 2, 78)
    mem_write_byte(out, 3, 71)
    mem_write_byte(out, 4, 13)
    mem_write_byte(out, 5, 10)
    mem_write_byte(out, 6, 26)
    mem_write_byte(out, 7, 10)

    // 2. IHDR chunk (13 bytes payload)
    pos = 8
    _png_write_u32_be(out, pos, 13)
    mem_write_byte(out, pos + 4, 73)  // 'I'
    mem_write_byte(out, pos + 5, 72)  // 'H'
    mem_write_byte(out, pos + 6, 68)  // 'D'
    mem_write_byte(out, pos + 7, 82)  // 'R'
    _png_write_u32_be(out, pos + 8, width)
    _png_write_u32_be(out, pos + 12, height)
    mem_write_byte(out, pos + 16, 8)  // 8-bit depth
    mem_write_byte(out, pos + 17, 6)  // Color type 6 = RGBA
    mem_write_byte(out, pos + 18, 0)  // DEFLATE
    mem_write_byte(out, pos + 19, 0)  // Adaptive filter
    mem_write_byte(out, pos + 20, 0)  // Non-interlaced
    ihdr_crc = png_crc32(out, pos + 4, 17)
    _png_write_u32_be(out, pos + 21, ihdr_crc)
    pos = pos + 25

    // 3. IDAT chunk
    idat_start = pos
    _png_write_u32_be(out, pos, zlib_len)
    mem_write_byte(out, pos + 4, 73)  // 'I'
    mem_write_byte(out, pos + 5, 68)  // 'D'
    mem_write_byte(out, pos + 6, 65)  // 'A'
    mem_write_byte(out, pos + 7, 84)  // 'T'
    zpos = pos + 8
    // Zlib header: CMF=0x78 (DEFLATE, 32K window), FLG=0x01 (check bits: 0x7801 % 31 == 0)
    mem_write_byte(out, zpos, 120)
    mem_write_byte(out, zpos + 1, 1)
    zpos = zpos + 2

    rem = raw_len
    src_off = 0
    while rem > 0
        blk = rem
        if blk > 65535 blk = 65535 end
        bfinal = 0
        if blk == rem bfinal = 1 end
        mem_write_byte(out, zpos, bfinal)
        mem_write_byte(out, zpos + 1, blk & 255)
        mem_write_byte(out, zpos + 2, (blk >> 8) & 255)
        nlen = blk ^ 65535
        mem_write_byte(out, zpos + 3, nlen & 255)
        mem_write_byte(out, zpos + 4, (nlen >> 8) & 255)
        zpos = zpos + 5
        mem_copy(out + zpos, raw_scan + src_off, blk)
        zpos = zpos + blk
        src_off = src_off + blk
        rem = rem - blk
    end
    adler = png_adler32(raw_scan, 0, raw_len)
    _png_write_u32_be(out, zpos, adler)
    zpos = zpos + 4
    idat_crc = png_crc32(out, idat_start + 4, 4 + zlib_len)
    _png_write_u32_be(out, zpos, idat_crc)
    pos = zpos + 4

    // 4. IEND chunk
    _png_write_u32_be(out, pos, 0)
    mem_write_byte(out, pos + 4, 73)  // 'I'
    mem_write_byte(out, pos + 5, 69)  // 'E'
    mem_write_byte(out, pos + 6, 78)  // 'N'
    mem_write_byte(out, pos + 7, 68)  // 'D'
    iend_crc = png_crc32(out, pos + 4, 4)
    _png_write_u32_be(out, pos + 8, iend_crc)

    free(raw_scan, raw_len)
    if out_len_box != 0 list_set(out_len_box, 0, total_len) end
    return out
end

// ── 3. Full RFC 1951 DEFLATE Inflate (Stored + Fixed + Dynamic Huffman) ───────

fn _inf_read_bits src src_len st nbits
    // st = [byte_pos, bit_buf, bit_cnt]
    if nbits == 0 return 0 end
    bp = st[0]
    bb = st[1]
    bc = st[2]
    while bc < nbits
        b = 0
        if bp < src_len
            b = mem_read_byte(src, bp)
            bp = bp + 1
        end
        bb = bb | (b << bc)
        bc = bc + 8
    end
    val = bb & ((1 << nbits) - 1)
    bb = bb >> nbits
    bc = bc - nbits
    list_set(st, 0, bp)
    list_set(st, 1, bb)
    list_set(st, 2, bc)
    return val
end

fn _inf_build_huff lengths num_syms
    // WHY: Canonical RFC 1951 Huffman table stored as [counts[16], syms[num_syms]].
    counts = list()
    i = 0
    while i < 16
        push(counts, 0)
        i = i + 1
    end
    i = 0
    while i < num_syms
        l = lengths[i]
        if l > 0 and l < 16
            list_set(counts, l, counts[l] + 1)
        end
        i = i + 1
    end
    offs = list()
    acc = 0
    i = 0
    while i < 16
        push(offs, acc)
        acc = acc + counts[i]
        i = i + 1
    end
    syms = list()
    i = 0
    while i < num_syms
        push(syms, 0)
        i = i + 1
    end
    i = 0
    while i < num_syms
        l = lengths[i]
        if l > 0 and l < 16
            o = offs[l]
            list_set(syms, o, i)
            list_set(offs, l, o + 1)
        end
        i = i + 1
    end
    return [counts, syms]
end

fn _inf_decode_sym src src_len st huff
    counts = huff[0]
    syms = huff[1]
    code = 0
    first = 0
    idx = 0
    blen = 1
    while blen < 16
        code = (code << 1) | _inf_read_bits(src, src_len, st, 1)
        cnt = counts[blen]
        if code - cnt < first
            return syms[idx + (code - first)]
        end
        idx = idx + cnt
        first = (first + cnt) << 1
        blen = blen + 1
    end
    return 0 - 1
end

fn _inf_inflate_zlib zptr zlen out_buf out_cap
    if zlen < 6 return 0 - 1 end
    cmf = mem_read_byte(zptr, 0)
    flg = mem_read_byte(zptr, 1)
    if (cmf & 15) != 8 or (((cmf * 256) + flg) % 31) != 0
        return 0 - 1
    end
    st = [2, 0, 0]
    if (flg & 32) != 0
        list_set(st, 0, 6)
    end

    len_base = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    len_ext  = [0, 0, 0, 0, 0, 0, 0,  0,  1,  1,  1,  1,  2,  2,  2,  2,  3,  3,  3,  3,  4,  4,  4,   4,   5,   5,   5,   5,   0]
    dst_base = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
    dst_ext  = [0, 0, 0, 0, 1, 1, 2,  2,  3,  3,  4,  4,  5,  5,   6,   6,   7,   7,   8,   8,    9,    9,   10,   10,   11,   11,   12,    12,    13,    13]
    cl_ord   = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

    out_pos = 0
    bfinal = 0
    while bfinal == 0
        bfinal = _inf_read_bits(zptr, zlen, st, 1)
        btype = _inf_read_bits(zptr, zlen, st, 2)
        if btype == 0
            // Uncompressed stored block: align to byte boundary
            list_set(st, 1, 0)
            list_set(st, 2, 0)
            bp = st[0]
            if bp + 4 > zlen return 0 - 1 end
            blen = mem_read_byte(zptr, bp) | (mem_read_byte(zptr, bp + 1) << 8)
            nlen = mem_read_byte(zptr, bp + 2) | (mem_read_byte(zptr, bp + 3) << 8)
            if (blen ^ 65535) != nlen return 0 - 1 end
            bp = bp + 4
            if bp + blen > zlen or out_pos + blen > out_cap return 0 - 1 end
            mem_copy(out_buf + out_pos, zptr + bp, blen)
            out_pos = out_pos + blen
            list_set(st, 0, bp + blen)
        elif btype == 1 or btype == 2
            ll_huff = 0
            d_huff = 0
            if btype == 1
                ll_lens = list()
                i = 0
                while i < 144 push(ll_lens, 8) i = i + 1 end
                while i < 256 push(ll_lens, 9) i = i + 1 end
                while i < 280 push(ll_lens, 7) i = i + 1 end
                while i < 288 push(ll_lens, 8) i = i + 1 end
                d_lens = list()
                i = 0
                while i < 32 push(d_lens, 5) i = i + 1 end
                ll_huff = _inf_build_huff(ll_lens, 288)
                d_huff = _inf_build_huff(d_lens, 32)
            else
                hlit = _inf_read_bits(zptr, zlen, st, 5) + 257
                hdist = _inf_read_bits(zptr, zlen, st, 5) + 1
                hclen = _inf_read_bits(zptr, zlen, st, 4) + 4
                cl_lens = list()
                i = 0
                while i < 19 push(cl_lens, 0) i = i + 1 end
                i = 0
                while i < hclen
                    list_set(cl_lens, cl_ord[i], _inf_read_bits(zptr, zlen, st, 3))
                    i = i + 1
                end
                cl_huff = _inf_build_huff(cl_lens, 19)
                all_lens = list()
                tot = hlit + hdist
                while len(all_lens) < tot
                    cs = _inf_decode_sym(zptr, zlen, st, cl_huff)
                    if cs < 0 return 0 - 1 end
                    if cs < 16
                        push(all_lens, cs)
                    elif cs == 16
                        rep = _inf_read_bits(zptr, zlen, st, 2) + 3
                        prev = 0
                        if len(all_lens) > 0 prev = all_lens[len(all_lens) - 1] end
                        ri = 0
                        while ri < rep and len(all_lens) < tot
                            push(all_lens, prev)
                            ri = ri + 1
                        end
                    elif cs == 17
                        rep = _inf_read_bits(zptr, zlen, st, 3) + 3
                        ri = 0
                        while ri < rep and len(all_lens) < tot
                            push(all_lens, 0)
                            ri = ri + 1
                        end
                    else
                        rep = _inf_read_bits(zptr, zlen, st, 7) + 11
                        ri = 0
                        while ri < rep and len(all_lens) < tot
                            push(all_lens, 0)
                            ri = ri + 1
                        end
                    end
                end
                ll_lens = list()
                i = 0
                while i < hlit push(ll_lens, all_lens[i]) i = i + 1 end
                d_lens = list()
                while i < tot push(d_lens, all_lens[i]) i = i + 1 end
                ll_huff = _inf_build_huff(ll_lens, hlit)
                d_huff = _inf_build_huff(d_lens, hdist)
            end
            // Decode literals & LZ77 backreferences until End-Of-Block (256)
            while 1
                sym = _inf_decode_sym(zptr, zlen, st, ll_huff)
                if sym < 0 return 0 - 1 end
                if sym < 256
                    if out_pos >= out_cap return 0 - 1 end
                    mem_write_byte(out_buf, out_pos, sym)
                    out_pos = out_pos + 1
                elif sym == 256
                    break
                else
                    l_idx = sym - 257
                    if l_idx < 0 or l_idx >= 29 return 0 - 1 end
                    mlen = len_base[l_idx] + _inf_read_bits(zptr, zlen, st, len_ext[l_idx])
                    dsym = _inf_decode_sym(zptr, zlen, st, d_huff)
                    if dsym < 0 or dsym >= 30 return 0 - 1 end
                    dist = dst_base[dsym] + _inf_read_bits(zptr, zlen, st, dst_ext[dsym])
                    if dist <= 0 or dist > out_pos or out_pos + mlen > out_cap return 0 - 1 end
                    mi = 0
                    while mi < mlen
                        mem_write_byte(out_buf, out_pos, mem_read_byte(out_buf, out_pos - dist))
                        out_pos = out_pos + 1
                        mi = mi + 1
                    end
                end
            end
        else
            return 0 - 1
        end
    end
    // Verify Adler-32 checksum in last 4 bytes of zlib stream
    expected_adler = _png_u32_be(zptr, zlen - 4)
    actual_adler = png_adler32(out_buf, 0, out_pos)
    if expected_adler != actual_adler
        return 0 - 2
    end
    return out_pos
end

// ── 4. PNG Decoder (All 5 Scanline Filters + RGB/RGBA -> ARGB8888) ────────────

fn _png_paeth a b c
    p = a + b - c
    pa = p - a
    if pa < 0 pa = 0 - pa end
    pb = p - b
    if pb < 0 pb = 0 - pb end
    pc = p - c
    if pc < 0 pc = 0 - pc end
    if pa <= pb and pa <= pc return a end
    if pb <= pc return b end
    return c
end

fn png_decode_to_argb png_ptr png_len
    bad = PngImage(0, 0, 0, 0)
    if png_ptr <= 0 or png_len < 33
        return bad
    end
    // Verify 8-byte PNG magic signature
    if mem_read_byte(png_ptr, 0) != 137 or mem_read_byte(png_ptr, 1) != 80 or mem_read_byte(png_ptr, 2) != 78 or mem_read_byte(png_ptr, 3) != 71
        return bad
    end
    width = 0
    height = 0
    bit_depth = 0
    color_type = 0
    // Gather IDAT payloads into contiguous zlib buffer
    zbuf = malloc(png_len)
    zlen = 0
    pos = 8
    while pos + 12 <= png_len
        clen = _png_u32_be(png_ptr, pos)
        if pos + 12 + clen > png_len break end
        c0 = mem_read_byte(png_ptr, pos + 4)
        c1 = mem_read_byte(png_ptr, pos + 5)
        c2 = mem_read_byte(png_ptr, pos + 6)
        c3 = mem_read_byte(png_ptr, pos + 7)
        // Verify chunk CRC-32
        want_crc = _png_u32_be(png_ptr, pos + 8 + clen)
        got_crc = png_crc32(png_ptr, pos + 4, 4 + clen)
        if want_crc != got_crc
            free(zbuf, png_len)
            return bad
        end
        // IHDR
        if c0 == 73 and c1 == 72 and c2 == 68 and c3 == 82 and clen == 13
            width = _png_u32_be(png_ptr, pos + 8)
            height = _png_u32_be(png_ptr, pos + 12)
            bit_depth = mem_read_byte(png_ptr, pos + 16)
            color_type = mem_read_byte(png_ptr, pos + 17)
        // IDAT
        elif c0 == 73 and c1 == 68 and c2 == 65 and c3 == 84 and clen > 0
            mem_copy(zbuf + zlen, png_ptr + pos + 8, clen)
            zlen = zlen + clen
        // IEND
        elif c0 == 73 and c1 == 69 and c2 == 78 and c3 == 68
            break
        end
        pos = pos + 12 + clen
    end

    if width <= 0 or height <= 0 or bit_depth != 8 or (color_type != 2 and color_type != 6) or zlen < 6
        free(zbuf, png_len)
        return bad
    end
    bpp = 4
    if color_type == 2 bpp = 3 end
    stride = width * bpp
    raw_cap = (1 + stride) * height
    raw = malloc(raw_cap)
    inf_len = _inf_inflate_zlib(zbuf, zlen, raw, raw_cap)
    free(zbuf, png_len)
    if inf_len != raw_cap
        free(raw, raw_cap)
        return bad
    end

    // Unfilter all 5 PNG scanline filters in-place per row into `recon`
    recon = malloc(stride * height)
    y = 0
    while y < height
        src_row = y * (1 + stride)
        ftype = mem_read_byte(raw, src_row)
        dst_row = y * stride
        x = 0
        while x < stride
            fv = mem_read_byte(raw, src_row + 1 + x)
            a = 0
            b = 0
            c = 0
            if x >= bpp a = mem_read_byte(recon, dst_row + x - bpp) end
            if y > 0 b = mem_read_byte(recon, dst_row - stride + x) end
            if x >= bpp and y > 0 c = mem_read_byte(recon, dst_row - stride + x - bpp) end
            out_b = fv
            if ftype == 1
                out_b = (fv + a) & 255
            elif ftype == 2
                out_b = (fv + b) & 255
            elif ftype == 3
                out_b = (fv + ((a + b) / 2)) & 255
            elif ftype == 4
                out_b = (fv + _png_paeth(a, b, c)) & 255
            end
            mem_write_byte(recon, dst_row + x, out_b)
            x = x + 1
        end
        y = y + 1
    end
    free(raw, raw_cap)

    // Convert RGB / RGBA into ARGB8888 pixel buffer
    argb = malloc(width * height * 4)
    y = 0
    while y < height
        x = 0
        while x < width
            so = (y * stride) + (x * bpp)
            r = mem_read_byte(recon, so)
            g = mem_read_byte(recon, so + 1)
            b = mem_read_byte(recon, so + 2)
            a = 255
            if bpp == 4 a = mem_read_byte(recon, so + 3) end
            px = (a << 24) | (r << 16) | (g << 8) | b
            mem_write_u32(argb, ((y * width) + x) * 4, px)
            x = x + 1
        end
        y = y + 1
    end
    free(recon, stride * height)
    return PngImage(argb, width, height, 1)
end

fn png_free_image img
    if img.png_pixels > 0 and img.png_width > 0 and img.png_height > 0
        free(img.png_pixels, img.png_width * img.png_height * 4)
        img.png_pixels = 0
        img.png_valid = 0
    end
    return 0
end
