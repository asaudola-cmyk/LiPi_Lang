// ==============================================================================
// LIPI PURE-SILICON RFC 1951 DEFLATE / RFC 1950 ZLIB / RFC 1952 GZIP ENGINE
// Module: utso/core/deflate.lp
// 100% Pure Lipi | 0% C | 0% zlib | 0% libc | Sovereign Compression & Inflate
// ==============================================================================
//
// WHY THIS MODULE:
// Provides complete, zero-dependency HTTP/1.1, HTTP/2, and general-purpose
// RFC 1951 DEFLATE (Stored Type 0, Fixed Huffman Type 1, Dynamic Huffman Type 2,
// LZ77 sliding window), RFC 1950 ZLIB (Adler-32), and RFC 1952 GZIP (FEXTRA/
// FNAME/FCOMMENT/FHCRC + IEEE CRC-32 + ISIZE + multi-member streams) encoding
// and decoding in 100% Pure LiPi.
// ==============================================================================

import "utso/core/string"

struct DeflateResult
    dr_ok
    dr_data
    dr_err
end

// ── 1. IEEE 802.3 CRC-32 & RFC 1950 Adler-32 Checksums ───────────────────────

fn deflate_crc32_bytes ptr start_off length
    // WHY: Standard IEEE 802.3 CRC-32 (reflected polynomial 0xEDB88320 = 3988292384).
    crc = 4294967295
    i = 0
    while i < length
        b = mem_byte_read(ptr, start_off + i) & 255
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

fn deflate_crc32_str s
    return deflate_crc32_bytes(s, 0, len(s))
end

fn deflate_adler32_bytes ptr start_off length
    // WHY: RFC 1950 Adler-32 checksum modulo 65521.
    s1 = 1
    s2 = 0
    i = 0
    while i < length
        s1 = (s1 + (mem_byte_read(ptr, start_off + i) & 255)) % 65521
        s2 = (s2 + s1) % 65521
        i = i + 1
    end
    return ((s2 << 16) | s1) & 4294967295
end

fn deflate_adler32_str s
    return deflate_adler32_bytes(s, 0, len(s))
end

fn _def_u32_le ptr off
    b0 = mem_byte_read(ptr, off) & 255
    b1 = mem_byte_read(ptr, off + 1) & 255
    b2 = mem_byte_read(ptr, off + 2) & 255
    b3 = mem_byte_read(ptr, off + 3) & 255
    return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
end

fn _def_u32_be ptr off
    b0 = mem_byte_read(ptr, off) & 255
    b1 = mem_byte_read(ptr, off + 1) & 255
    b2 = mem_byte_read(ptr, off + 2) & 255
    b3 = mem_byte_read(ptr, off + 3) & 255
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
end

fn _def_buf_write_u32_le b val
    buf_write_byte(b, val & 255)
    buf_write_byte(b, (val >> 8) & 255)
    buf_write_byte(b, (val >> 16) & 255)
    buf_write_byte(b, (val >> 24) & 255)
    return 4
end

fn _def_buf_write_u32_be b val
    buf_write_byte(b, (val >> 24) & 255)
    buf_write_byte(b, (val >> 16) & 255)
    buf_write_byte(b, (val >> 8) & 255)
    buf_write_byte(b, val & 255)
    return 4
end

// ── 2. Full RFC 1951 DEFLATE Inflate (Stored + Fixed + Dynamic Huffman) ───────

fn _def_read_bits src src_len st nbits
    // st = [byte_pos, bit_buf, bit_cnt, eof_err]
    if nbits == 0 return 0 end
    bp = st[0]
    bb = st[1]
    bc = st[2]
    while bc < nbits
        if bp >= src_len
            list_set(st, 3, 1)
            return 0
        end
        b = mem_byte_read(src, bp) & 255
        bp = bp + 1
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

fn _def_build_huff lengths num_syms
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

fn _def_decode_sym src src_len st huff
    counts = huff[0]
    syms = huff[1]
    code = 0
    first = 0
    idx = 0
    blen = 1
    while blen < 16
        bit = _def_read_bits(src, src_len, st, 1)
        if st[3] != 0 return 0 - 1 end
        code = (code << 1) | bit
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

fn _def_inflate_raw_into src src_len start_off out_buf end_pos_box
    // WHY: Inflates a raw RFC 1951 DEFLATE stream from src[start_off..src_len] into out_buf.
    // Guards against decompression bombs (64 MiB safety ceiling) and truncated/corrupt bitstreams.
    max_out = 67108864
    st = [start_off, 0, 0, 0]

    len_base = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    len_ext  = [0, 0, 0, 0, 0, 0, 0,  0,  1,  1,  1,  1,  2,  2,  2,  2,  3,  3,  3,  3,  4,  4,  4,   4,   5,   5,   5,   5,   0]
    dst_base = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
    dst_ext  = [0, 0, 0, 0, 1, 1, 2,  2,  3,  3,  4,  4,  5,  5,   6,   6,   7,   7,   8,   8,    9,    9,   10,   10,   11,   11,   12,    12,    13,    13]
    cl_ord   = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

    out_start = buf_len(out_buf)
    bfinal = 0
    while bfinal == 0
        bfinal = _def_read_bits(src, src_len, st, 1)
        btype = _def_read_bits(src, src_len, st, 2)
        if st[3] != 0 return 0 - 1 end

        if btype == 0
            // Type 0: Stored uncompressed block — discard remaining bits to align to byte boundary
            // Note: bit_buf may hold whole unread bytes; rewind bp by floor(bit_cnt / 8)
            rewind_b = st[2] / 8
            bp = st[0] - rewind_b
            list_set(st, 1, 0)
            list_set(st, 2, 0)
            if bp + 4 > src_len return 0 - 1 end
            blen = (mem_byte_read(src, bp) & 255) | ((mem_byte_read(src, bp + 1) & 255) << 8)
            nlen = (mem_byte_read(src, bp + 2) & 255) | ((mem_byte_read(src, bp + 3) & 255) << 8)
            if (blen ^ 65535) != nlen return 0 - 1 end
            bp = bp + 4
            if bp + blen > src_len return 0 - 1 end
            if buf_len(out_buf) + blen > max_out return 0 - 2 end
            si = 0
            while si < blen
                buf_write_byte(out_buf, mem_byte_read(src, bp + si) & 255)
                si = si + 1
            end
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
                ll_huff = _def_build_huff(ll_lens, 288)
                d_huff = _def_build_huff(d_lens, 32)
            else
                hlit = _def_read_bits(src, src_len, st, 5) + 257
                hdist = _def_read_bits(src, src_len, st, 5) + 1
                hclen = _def_read_bits(src, src_len, st, 4) + 4
                if st[3] != 0 or hlit > 286 or hdist > 32 return 0 - 1 end
                cl_lens = list()
                i = 0
                while i < 19 push(cl_lens, 0) i = i + 1 end
                i = 0
                while i < hclen
                    list_set(cl_lens, cl_ord[i], _def_read_bits(src, src_len, st, 3))
                    i = i + 1
                end
                if st[3] != 0 return 0 - 1 end
                cl_huff = _def_build_huff(cl_lens, 19)
                all_lens = list()
                tot = hlit + hdist
                while len(all_lens) < tot
                    cs = _def_decode_sym(src, src_len, st, cl_huff)
                    if cs < 0 return 0 - 1 end
                    if cs < 16
                        push(all_lens, cs)
                    elif cs == 16
                        rep = _def_read_bits(src, src_len, st, 2) + 3
                        if st[3] != 0 or len(all_lens) == 0 or len(all_lens) + rep > tot return 0 - 1 end
                        prev = all_lens[len(all_lens) - 1]
                        ri = 0
                        while ri < rep
                            push(all_lens, prev)
                            ri = ri + 1
                        end
                    elif cs == 17
                        rep = _def_read_bits(src, src_len, st, 3) + 3
                        if st[3] != 0 or len(all_lens) + rep > tot return 0 - 1 end
                        ri = 0
                        while ri < rep
                            push(all_lens, 0)
                            ri = ri + 1
                        end
                    else
                        rep = _def_read_bits(src, src_len, st, 7) + 11
                        if st[3] != 0 or len(all_lens) + rep > tot return 0 - 1 end
                        ri = 0
                        while ri < rep
                            push(all_lens, 0)
                            ri = ri + 1
                        end
                    end
                end
                ll_lens = list()
                i = 0
                while i < hlit
                    push(ll_lens, all_lens[i])
                    i = i + 1
                end
                d_lens = list()
                while i < tot
                    push(d_lens, all_lens[i])
                    i = i + 1
                end
                ll_huff = _def_build_huff(ll_lens, hlit)
                d_huff = _def_build_huff(d_lens, hdist)
            end

            // Decode literals and LZ77 backreferences until End-Of-Block (256)
            while 1 == 1
                sym = _def_decode_sym(src, src_len, st, ll_huff)
                if sym < 0 return 0 - 1 end
                if sym < 256
                    if buf_len(out_buf) >= max_out return 0 - 2 end
                    buf_write_byte(out_buf, sym)
                elif sym == 256
                    break
                else
                    l_idx = sym - 257
                    if l_idx < 0 or l_idx >= 29 return 0 - 1 end
                    mlen = len_base[l_idx] + _def_read_bits(src, src_len, st, len_ext[l_idx])
                    if st[3] != 0 return 0 - 1 end
                    dsym = _def_decode_sym(src, src_len, st, d_huff)
                    if dsym < 0 or dsym >= 30 return 0 - 1 end
                    dist = dst_base[dsym] + _def_read_bits(src, src_len, st, dst_ext[dsym])
                    if st[3] != 0 return 0 - 1 end
                    cur_rel = buf_len(out_buf) - out_start
                    if dist <= 0 or dist > cur_rel return 0 - 1 end
                    if buf_len(out_buf) + mlen > max_out return 0 - 2 end
                    mi = 0
                    while mi < mlen
                        b_ref = buf_get_byte(out_buf, buf_len(out_buf) - dist) & 255
                        buf_write_byte(out_buf, b_ref)
                        mi = mi + 1
                    end
                end
            end
        else
            return 0 - 1
        end
    end

    // Rewind any whole unread bytes still sitting in bit_buf so trailer offset is exact
    final_bp = st[0] - (st[2] / 8)
    if end_pos_box != 0
        list_set(end_pos_box, 0, final_bp)
    end
    return buf_len(out_buf) - out_start
end

// ── 3. RFC 1951 Fixed-Huffman + LZ77 DEFLATE Compressor ──────────────────────

fn _def_rev_bits val nbits
    out = 0
    i = 0
    while i < nbits
        out = (out << 1) | ((val >> i) & 1)
        i = i + 1
    end
    return out
end

fn _def_write_bits out_buf wst val nbits
    // wst = [bit_buf, bit_cnt]
    bb = wst[0] | ((val & ((1 << nbits) - 1)) << wst[1])
    bc = wst[1] + nbits
    while bc >= 8
        buf_write_byte(out_buf, bb & 255)
        bb = bb >> 8
        bc = bc - 8
    end
    list_set(wst, 0, bb)
    list_set(wst, 1, bc)
    return 0
end

fn _def_flush_bits out_buf wst
    if wst[1] > 0
        buf_write_byte(out_buf, wst[0] & 255)
        list_set(wst, 0, 0)
        list_set(wst, 1, 0)
    end
    return 0
end

fn _def_emit_fixed_lit out_buf wst sym
    if sym <= 143
        _def_write_bits(out_buf, wst, _def_rev_bits(48 + sym, 8), 8)
    elif sym <= 255
        _def_write_bits(out_buf, wst, _def_rev_bits(400 + (sym - 144), 9), 9)
    elif sym <= 279
        _def_write_bits(out_buf, wst, _def_rev_bits(sym - 256, 7), 7)
    else
        _def_write_bits(out_buf, wst, _def_rev_bits(192 + (sym - 280), 8), 8)
    end
    return 0
end

fn _def_compress_raw_into src src_len out_buf
    // WHY: Real RFC 1951 Type 1 Fixed Huffman + LZ77 sliding-window compressor (window 4096,
    // match length 3..258). Achieves genuine compression while remaining O(N) via 4096-entry
    // 3-byte hash head table and 100% compatible with every RFC 1951/1950/1952 decoder.
    len_base = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    len_ext  = [0, 0, 0, 0, 0, 0, 0,  0,  1,  1,  1,  1,  2,  2,  2,  2,  3,  3,  3,  3,  4,  4,  4,   4,   5,   5,   5,   5,   0]
    dst_base = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
    dst_ext  = [0, 0, 0, 0, 1, 1, 2,  2,  3,  3,  4,  4,  5,  5,   6,   6,   7,   7,   8,   8,    9,    9,   10,   10,   11,   11,   12,    12,    13,    13]

    wst = [0, 0]
    // BFINAL = 1 (1 bit), BTYPE = 01 Fixed Huffman (2 bits)
    _def_write_bits(out_buf, wst, 1, 1)
    _def_write_bits(out_buf, wst, 1, 2)

    // 4096-slot LZ77 3-byte hash table storing last seen index + 1 (0 = empty)
    htab = list()
    hi = 0
    while hi < 4096
        push(htab, 0)
        hi = hi + 1
    end

    pos = 0
    while pos < src_len
        best_len = 0
        best_dist = 0
        if pos + 3 <= src_len
            b0 = mem_byte_read(src, pos) & 255
            b1 = mem_byte_read(src, pos + 1) & 255
            b2 = mem_byte_read(src, pos + 2) & 255
            h = ((b0 * 257) ^ (b1 * 131) ^ (b2 * 17)) & 4095
            cand_p1 = htab[h]
            list_set(htab, h, pos + 1)
            if cand_p1 > 0
                cand = cand_p1 - 1
                dist = pos - cand
                if dist > 0 and dist <= 32768
                    ml = 0
                    max_l = src_len - pos
                    if max_l > 258 max_l = 258 end
                    while ml < max_l and (mem_byte_read(src, cand + ml) & 255) == (mem_byte_read(src, pos + ml) & 255)
                        ml = ml + 1
                    end
                    if ml >= 3
                        best_len = ml
                        best_dist = dist
                    end
                end
            end
        end

        if best_len >= 3
            // Encode length symbol 257..285 + extra bits
            li = 28
            while li > 0 and len_base[li] > best_len
                li = li - 1
            end
            _def_emit_fixed_lit(out_buf, wst, 257 + li)
            if len_ext[li] > 0
                _def_write_bits(out_buf, wst, best_len - len_base[li], len_ext[li])
            end
            // Encode distance symbol 0..29 (5-bit MSB-first) + extra bits
            di = 29
            while di > 0 and dst_base[di] > best_dist
                di = di - 1
            end
            _def_write_bits(out_buf, wst, _def_rev_bits(di, 5), 5)
            if dst_ext[di] > 0
                _def_write_bits(out_buf, wst, best_dist - dst_base[di], dst_ext[di])
            end
            // Update hash slots along matched span for better subsequent matches
            step = 1
            while step < best_len and pos + step + 3 <= src_len
                mb0 = mem_byte_read(src, pos + step) & 255
                mb1 = mem_byte_read(src, pos + step + 1) & 255
                mb2 = mem_byte_read(src, pos + step + 2) & 255
                mh = ((mb0 * 257) ^ (mb1 * 131) ^ (mb2 * 17)) & 4095
                list_set(htab, mh, pos + step + 1)
                step = step + 1
            end
            pos = pos + best_len
        else
            lit = mem_byte_read(src, pos) & 255
            _def_emit_fixed_lit(out_buf, wst, lit)
            pos = pos + 1
        end
    end

    // End-Of-Block symbol 256
    _def_emit_fixed_lit(out_buf, wst, 256)
    _def_flush_bits(out_buf, wst)
    return 0
end

// ── 4. Public Raw DEFLATE, RFC 1950 ZLIB & RFC 1952 GZIP APIs ─────────────────

fn deflate_raw_compress raw_str
    n = len(raw_str)
    bb = buf_new(n + 64)
    _def_compress_raw_into(raw_str, n, bb)
    out = buf_to_str(bb)
    buf_free(bb)
    return out
end

fn deflate_raw_decompress comp_str
    n = len(comp_str)
    bb = buf_new(n * 2 + 64)
    ep = [0]
    rc = _def_inflate_raw_into(comp_str, n, 0, bb, ep)
    if rc < 0
        buf_free(bb)
        return DeflateResult(0, "", "Invalid RFC 1951 DEFLATE stream")
    end
    out = buf_to_str(bb)
    buf_free(bb)
    return DeflateResult(1, out, "")
end

fn zlib_compress raw_str
    // WHY: RFC 1950 ZLIB wrapper: CMF=0x78, FLG=0x9C (0x789C % 31 == 0) + DEFLATE + Adler-32 BE.
    n = len(raw_str)
    bb = buf_new(n + 64)
    buf_write_byte(bb, 120)
    buf_write_byte(bb, 156)
    _def_compress_raw_into(raw_str, n, bb)
    adler = deflate_adler32_bytes(raw_str, 0, n)
    _def_buf_write_u32_be(bb, adler)
    out = buf_to_str(bb)
    buf_free(bb)
    return out
end

fn zlib_decompress z_str
    n = len(z_str)
    if n < 6
        return DeflateResult(0, "", "Truncated RFC 1950 ZLIB stream")
    end
    cmf = mem_byte_read(z_str, 0) & 255
    flg = mem_byte_read(z_str, 1) & 255
    if (cmf & 15) != 8 or (((cmf * 256) + flg) % 31) != 0
        return DeflateResult(0, "", "Invalid ZLIB header")
    end
    start_off = 2
    if (flg & 32) != 0
        return DeflateResult(0, "", "Unsupported ZLIB preset dictionary (FDICT)")
    end
    if start_off + 4 > n
        return DeflateResult(0, "", "Truncated ZLIB payload")
    end
    bb = buf_new(n * 2 + 64)
    ep = [0]
    rc = _def_inflate_raw_into(z_str, n - 4, start_off, bb, ep)
    if rc < 0
        buf_free(bb)
        return DeflateResult(0, "", "ZLIB DEFLATE inflate failed")
    end
    out = buf_to_str(bb)
    buf_free(bb)
    // Verify 4-byte big-endian Adler-32 trailer (at ep[0] or end-4)
    tr_off = ep[0]
    if tr_off + 4 > n
        tr_off = n - 4
    end
    exp_adler = _def_u32_be(z_str, tr_off)
    act_adler = deflate_adler32_str(out)
    if exp_adler != act_adler
        return DeflateResult(0, "", "ZLIB Adler-32 checksum mismatch")
    end
    return DeflateResult(1, out, "")
end

fn gzip_compress raw_str
    // WHY: RFC 1952 GZIP format: 10-byte header + RFC 1951 DEFLATE + CRC-32 LE + ISIZE LE.
    n = len(raw_str)
    bb = buf_new(n + 64)
    buf_write_byte(bb, 31)  // ID1 = 0x1F
    buf_write_byte(bb, 139) // ID2 = 0x8B
    buf_write_byte(bb, 8)   // CM = 8 (DEFLATE)
    buf_write_byte(bb, 0)   // FLG = 0
    buf_write_byte(bb, 0)   // MTIME[0..3] = 0
    buf_write_byte(bb, 0)
    buf_write_byte(bb, 0)
    buf_write_byte(bb, 0)
    buf_write_byte(bb, 0)   // XFL = 0
    buf_write_byte(bb, 255) // OS = 255 (unknown/sovereign)
    _def_compress_raw_into(raw_str, n, bb)
    crc = deflate_crc32_bytes(raw_str, 0, n)
    _def_buf_write_u32_le(bb, crc)
    _def_buf_write_u32_le(bb, n & 4294967295)
    out = buf_to_str(bb)
    buf_free(bb)
    return out
end

fn gzip_decompress gz_str
    // WHY: Full RFC 1952 GZIP decoder supporting FEXTRA, FNAME, FCOMMENT, FHCRC,
    // concatenated multi-member streams, IEEE CRC-32 verification, and ISIZE verification.
    n = len(gz_str)
    if n < 18
        return DeflateResult(0, "", "Truncated GZIP stream")
    end
    out_buf = buf_new(n * 2 + 64)
    pos = 0
    members = 0
    while pos < n
        if pos + 18 > n
            buf_free(out_buf)
            return DeflateResult(0, "", "Truncated GZIP member header")
        end
        hdr_start = pos
        id1 = mem_byte_read(gz_str, pos) & 255
        id2 = mem_byte_read(gz_str, pos + 1) & 255
        cm = mem_byte_read(gz_str, pos + 2) & 255
        flg = mem_byte_read(gz_str, pos + 3) & 255
        if id1 != 31 or id2 != 139 or cm != 8
            buf_free(out_buf)
            return DeflateResult(0, "", "Invalid GZIP magic/method")
        end
        pos = pos + 10
        // FEXTRA (bit 2 = 4)
        if (flg & 4) != 0
            if pos + 2 > n
                buf_free(out_buf)
                return DeflateResult(0, "", "Truncated GZIP FEXTRA")
            end
            xlen = (mem_byte_read(gz_str, pos) & 255) | ((mem_byte_read(gz_str, pos + 1) & 255) << 8)
            pos = pos + 2 + xlen
            if pos > n
                buf_free(out_buf)
                return DeflateResult(0, "", "GZIP FEXTRA overflow")
            end
        end
        // FNAME (bit 3 = 8): zero-terminated original file name
        if (flg & 8) != 0
            while pos < n and (mem_byte_read(gz_str, pos) & 255) != 0
                pos = pos + 1
            end
            if pos >= n
                buf_free(out_buf)
                return DeflateResult(0, "", "Unterminated GZIP FNAME")
            end
            pos = pos + 1
        end
        // FCOMMENT (bit 4 = 16): zero-terminated comment
        if (flg & 16) != 0
            while pos < n and (mem_byte_read(gz_str, pos) & 255) != 0
                pos = pos + 1
            end
            if pos >= n
                buf_free(out_buf)
                return DeflateResult(0, "", "Unterminated GZIP FCOMMENT")
            end
            pos = pos + 1
        end
        // FHCRC (bit 1 = 2): 2-byte header CRC16 (low 16 bits of IEEE CRC-32 of header bytes)
        if (flg & 2) != 0
            if pos + 2 > n
                buf_free(out_buf)
                return DeflateResult(0, "", "Truncated GZIP FHCRC")
            end
            exp_hcrc = (mem_byte_read(gz_str, pos) & 255) | ((mem_byte_read(gz_str, pos + 1) & 255) << 8)
            act_hcrc = deflate_crc32_bytes(gz_str, hdr_start, pos - hdr_start) & 65535
            if act_hcrc != exp_hcrc
                buf_free(out_buf)
                return DeflateResult(0, "", "GZIP FHCRC header checksum mismatch")
            end
            pos = pos + 2
        end

        mem_out_start = buf_len(out_buf)
        ep = [0]
        rc = _def_inflate_raw_into(gz_str, n, pos, out_buf, ep)
        if rc < 0
            buf_free(out_buf)
            return DeflateResult(0, "", "GZIP DEFLATE inflate failed")
        end
        tr_pos = ep[0]
        if tr_pos + 8 > n
            buf_free(out_buf)
            return DeflateResult(0, "", "Truncated GZIP trailer")
        end
        exp_crc = _def_u32_le(gz_str, tr_pos)
        exp_isize = _def_u32_le(gz_str, tr_pos + 4)
        act_isize = rc & 4294967295
        if act_isize != exp_isize
            buf_free(out_buf)
            return DeflateResult(0, "", "GZIP ISIZE mismatch")
        end
        act_crc = deflate_crc32_bytes(buf_ptr(out_buf), mem_out_start, rc)
        if act_crc != exp_crc
            buf_free(out_buf)
            return DeflateResult(0, "", "GZIP CRC-32 checksum mismatch")
        end
        pos = tr_pos + 8
        members = members + 1
    end
    if members == 0
        buf_free(out_buf)
        return DeflateResult(0, "", "Empty GZIP stream")
    end
    out = buf_to_str(out_buf)
    buf_free(out_buf)
    return DeflateResult(1, out, "")
end

fn _def_decompress_single enc_tok data_str
    if len(data_str) == 0 or enc_tok == "" or enc_tok == "identity"
        return DeflateResult(1, data_str, "")
    end
    if enc_tok == "gzip" or enc_tok == "x-gzip"
        return gzip_decompress(data_str)
    end
    if enc_tok == "deflate"
        zr = zlib_decompress(data_str)
        if zr.dr_ok == 1
            return zr
        end
        return deflate_raw_decompress(data_str)
    end
    return DeflateResult(0, data_str, "Unsupported Content-Encoding: " + enc_tok)
end

fn deflate_decompress_http enc_str body_str
    // WHY: Handles single & RFC 9110 §8.4 chained HTTP Content-Encoding headers (e.g. "gzip",
    // "x-gzip", "deflate", "gzip, deflate") case-insensitively in reverse encoding order.
    if len(body_str) == 0 or len(enc_str) == 0
        return DeflateResult(1, body_str, "")
    end
    // Split comma-separated encodings
    encs = list()
    el = len(enc_str)
    sp = 0
    while sp <= el
        cp = sp
        while cp < el and (mem_byte_read(enc_str, cp) & 255) != 44
            cp = cp + 1
        end
        tok = str_to_lower(str_trim(str_sub(enc_str, sp, cp)))
        if len(tok) > 0
            push(encs, tok)
        end
        sp = cp + 1
    end
    if encs.len() == 0
        return DeflateResult(1, body_str, "")
    end
    // Decode in reverse order (last applied encoding unwrapped first)
    cur = body_str
    ei = encs.len() - 1
    while ei >= 0
        step = _def_decompress_single(encs[ei], cur)
        if step.dr_ok != 1
            return step
        end
        cur = step.dr_data
        ei = ei - 1
    end
    return DeflateResult(1, cur, "")
end
