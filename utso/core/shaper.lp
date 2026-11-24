// ==============================================================================
// LIPI PURE-SILICON OPENTYPE COMPLEX SCRIPT SHAPER (utso/core/shaper.lp)
// 100% Pure Lipi | 0% HarfBuzz / 0% ICU / 0% FreeType | Direct GSUB + GPOS Engine
// ==============================================================================
//
// WHY THIS MODULE:
// Implements ISO/IEC 14496-22 (OpenType 1.9) GSUB (Lookup Types 1/2/3/4/5/6/7)
// and GPOS (Lookup Types 1/2/4/6/9) directly on SFNT binary tables in pure Lipi.
// Provides authentic complex-script shaping for:
//   - Bengali (bng2 / beng): split vowel decomposition (ো -> ে+া, ৌ -> ে+ৗ),
//     Reph (র+্) formation & post-cluster reordering, pre-base matra (ি/ে/ৈ)
//     cluster reordering, akhn/cjct/blwf/half/pstf/vatu conjunct ligatures,
//     plus GPOS abvm/blwm/kern/mark/mkmk positioning.
//   - Arabic (arab): Unicode joining type classification (U/R/D/T/C), contextual
//     isol/init/medi/fina feature masking, mandatory rlig/liga ligatures (لا),
//     GPOS mark/mkmk/kern positioning, and RTL visual reordering.
//   - Latin & General (latn / DFLT): liga/clig/calt + GPOS kern/mark/mkmk.
// ==============================================================================

import "utso/core/ttf"

// Per-glyph OpenType feature masks (applied selectively during Indic & Arabic stages)
SHAPER_MASK_GLOBAL = 1
SHAPER_MASK_RPHF   = 2
SHAPER_MASK_INIT   = 4
SHAPER_MASK_ISOL   = 8
SHAPER_MASK_FINA   = 16
SHAPER_MASK_MEDI   = 32
SHAPER_MASK_AR_INI = 64

// Arabic Joining Classes (Unicode ArabicShaping.txt)
AR_JOIN_U = 0 // Non-joining
AR_JOIN_R = 1 // Right-joining only (Alef, Dal, Reh, Waw, Teh Marbuta, etc.)
AR_JOIN_D = 2 // Dual-joining (Beh, Teh, Seen, Lam, Meem, Yeh, etc.)
AR_JOIN_T = 3 // Transparent (combining diacritics / harakat)
AR_JOIN_C = 4 // Join-causing (Tatweel U+0640, ZWJ U+200D)

struct ShapedGlyph
    sg_gid
    sg_cluster
    sg_x_adv
    sg_y_adv
    sg_x_off
    sg_y_off
    sg_cp
    sg_mask
    sg_props // bit 0: pre-base matra, bit 1: reph, bit 2: mark/transparent
end

// ── 1. SFNT Big-Endian Readers & Tag Packing ─────────────────────────────────

fn ot_tag c0 c1 c2 c3
    return ((c0 & 255) << 24) | ((c1 & 255) << 16) | ((c2 & 255) << 8) | (c3 & 255)
end

fn ot_tag_from_str s
    if str_len(s) < 4 return 0 end
    return ot_tag(str_char_at(s, 0), str_char_at(s, 1), str_char_at(s, 2), str_char_at(s, 3))
end

fn _ot_u16 d dlen off
    if off < 0 or off + 2 > dlen return 0 end
    return ((mem_read_byte(d, off) & 255) << 8) | (mem_read_byte(d, off + 1) & 255)
end

fn _ot_i16 d dlen off
    v = _ot_u16(d, dlen, off)
    if v >= 32768 return v - 65536 end
    return v
end

fn _ot_u32 d dlen off
    if off < 0 or off + 4 > dlen return 0 end
    b0 = mem_read_byte(d, off) & 255
    b1 = mem_read_byte(d, off + 1) & 255
    b2 = mem_read_byte(d, off + 2) & 255
    b3 = mem_read_byte(d, off + 3) & 255
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
end

// ── 2. OpenType Coverage (Fmt 1 & 2) & ClassDef (Fmt 1 & 2) ──────────────────

fn ot_coverage_index d dlen cov_off gid
    if cov_off <= 0 or cov_off + 4 > dlen return 0 - 1 end
    fmt = _ot_u16(d, dlen, cov_off)
    if fmt == 1
        cnt = _ot_u16(d, dlen, cov_off + 2)
        lo = 0
        hi = cnt - 1
        while lo <= hi
            mid = (lo + hi) / 2
            g = _ot_u16(d, dlen, cov_off + 4 + (mid * 2))
            if gid < g
                hi = mid - 1
            elif gid > g
                lo = mid + 1
            else
                return mid
            end
        end
        return 0 - 1
    elif fmt == 2
        rcnt = _ot_u16(d, dlen, cov_off + 2)
        lo = 0
        hi = rcnt - 1
        while lo <= hi
            mid = (lo + hi) / 2
            ro = cov_off + 4 + (mid * 6)
            sg = _ot_u16(d, dlen, ro)
            eg = _ot_u16(d, dlen, ro + 2)
            if gid < sg
                hi = mid - 1
            elif gid > eg
                lo = mid + 1
            else
                sci = _ot_u16(d, dlen, ro + 4)
                return sci + (gid - sg)
            end
        end
        return 0 - 1
    end
    return 0 - 1
end

fn ot_class_def_get d dlen cd_off gid
    if cd_off <= 0 or cd_off + 4 > dlen return 0 end
    fmt = _ot_u16(d, dlen, cd_off)
    if fmt == 1
        sg = _ot_u16(d, dlen, cd_off + 2)
        cnt = _ot_u16(d, dlen, cd_off + 4)
        if gid >= sg and gid < sg + cnt
            return _ot_u16(d, dlen, cd_off + 6 + ((gid - sg) * 2))
        end
        return 0
    elif fmt == 2
        rcnt = _ot_u16(d, dlen, cd_off + 2)
        lo = 0
        hi = rcnt - 1
        while lo <= hi
            mid = (lo + hi) / 2
            ro = cd_off + 4 + (mid * 6)
            sg = _ot_u16(d, dlen, ro)
            eg = _ot_u16(d, dlen, ro + 2)
            if gid < sg
                hi = mid - 1
            elif gid > eg
                lo = mid + 1
            else
                return _ot_u16(d, dlen, ro + 4)
            end
        end
        return 0
    end
    return 0
end

// ── 3. OpenType ScriptList / FeatureList / LookupList Resolver ───────────────

fn ot_collect_feature_lookups d dlen table_off script_tags feature_tag
    // WHY: Walks ScriptList -> first matching script_tag -> DefaultLangSys -> FeatureList
    // and returns all LookupList indices registered under `feature_tag`.
    out = list()
    if table_off <= 0 or table_off + 10 > dlen return out end
    sl_off = table_off + _ot_u16(d, dlen, table_off + 4)
    fl_off = table_off + _ot_u16(d, dlen, table_off + 6)
    if sl_off + 2 > dlen or fl_off + 2 > dlen return out end

    scount = _ot_u16(d, dlen, sl_off)
    chosen_script = 0
    sti = 0
    while sti < len(script_tags) and chosen_script == 0
        want_tag = get(script_tags, sti)
        si = 0
        while si < scount
            rec = sl_off + 2 + (si * 6)
            if _ot_u32(d, dlen, rec) == want_tag
                chosen_script = sl_off + _ot_u16(d, dlen, rec + 4)
                break
            end
            si = si + 1
        end
        sti = sti + 1
    end
    if chosen_script == 0 and scount > 0
        chosen_script = sl_off + _ot_u16(d, dlen, sl_off + 6)
    end
    if chosen_script == 0 or chosen_script + 4 > dlen return out end

    dls_rel = _ot_u16(d, dlen, chosen_script)
    lang_off = 0
    if dls_rel > 0
        lang_off = chosen_script + dls_rel
    else
        lcnt = _ot_u16(d, dlen, chosen_script + 2)
        if lcnt > 0
            lang_off = chosen_script + _ot_u16(d, dlen, chosen_script + 8)
        end
    end
    if lang_off == 0 or lang_off + 6 > dlen return out end

    req_feat = _ot_u16(d, dlen, lang_off + 2)
    f_idx_cnt = _ot_u16(d, dlen, lang_off + 4)
    f_total = _ot_u16(d, dlen, fl_off)

    // Collect matching feature indices (required + indexed)
    fi = 0
    while fi <= f_idx_cnt
        fidx = 65535
        if fi == 0
            fidx = req_feat
        else
            fidx = _ot_u16(d, dlen, lang_off + 6 + ((fi - 1) * 2))
        end
        if fidx < f_total
            frec = fl_off + 2 + (fidx * 6)
            if _ot_u32(d, dlen, frec) == feature_tag
                ftab = fl_off + _ot_u16(d, dlen, frec + 4)
                if ftab + 4 <= dlen
                    lcnt = _ot_u16(d, dlen, ftab + 2)
                    li = 0
                    while li < lcnt
                        push(out, _ot_u16(d, dlen, ftab + 4 + (li * 2)))
                        li = li + 1
                    end
                end
            end
        end
        fi = fi + 1
    end
    return out
end

// ── 4. GSUB Engine (Types 1, 2, 3, 4, 5, 6, 7) ───────────────────────────────

fn _ot_skip_ignored glyphs idx step lflag
    // Honors LookupFlag IGNORE_MARKS (bit 3 = 8) when scanning sequences
    n = len(glyphs)
    cur = idx + step
    if (lflag & 8) == 0 return cur end
    while cur >= 0 and cur < n
        g = get(glyphs, cur)
        if (g.sg_props & 4) == 0 return cur end
        cur = cur + step
    end
    return cur
end

fn _ot_gsub_apply_subtable d dlen ll_off ltype lflag sub_off glyphs pos req_mask depth
    // Returns [matched (0/1), next_pos, updated_glyphs]
    if sub_off <= 0 or sub_off + 6 > dlen or depth > 8
        return [0, pos, glyphs]
    end
    // Unwrap Extension Substitution (Lookup Type 7)
    if ltype == 7
        efmt = _ot_u16(d, dlen, sub_off)
        if efmt != 1 return [0, pos, glyphs] end
        real_type = _ot_u16(d, dlen, sub_off + 2)
        real_off = sub_off + _ot_u32(d, dlen, sub_off + 4)
        return _ot_gsub_apply_subtable(d, dlen, ll_off, real_type, lflag, real_off, glyphs, pos, req_mask, depth + 1)
    end

    g0 = get(glyphs, pos)
    if req_mask != 0 and (g0.sg_mask & req_mask) == 0
        return [0, pos, glyphs]
    end
    fmt = _ot_u16(d, dlen, sub_off)

    // Type 1: Single Substitution (1 -> 1)
    if ltype == 1
        cov = sub_off + _ot_u16(d, dlen, sub_off + 2)
        cidx = ot_coverage_index(d, dlen, cov, g0.sg_gid)
        if cidx < 0 return [0, pos, glyphs] end
        if fmt == 1
            delta = _ot_i16(d, dlen, sub_off + 4)
            g0.sg_gid = (g0.sg_gid + delta) & 65535
            return [1, pos + 1, glyphs]
        elif fmt == 2
            cnt = _ot_u16(d, dlen, sub_off + 4)
            if cidx < cnt
                g0.sg_gid = _ot_u16(d, dlen, sub_off + 6 + (cidx * 2))
                return [1, pos + 1, glyphs]
            end
        end
        return [0, pos, glyphs]
    end

    // Type 2: Multiple Substitution (1 -> N)
    if ltype == 2 and fmt == 1
        cov = sub_off + _ot_u16(d, dlen, sub_off + 2)
        cidx = ot_coverage_index(d, dlen, cov, g0.sg_gid)
        scnt = _ot_u16(d, dlen, sub_off + 4)
        if cidx < 0 or cidx >= scnt return [0, pos, glyphs] end
        seq_off = sub_off + _ot_u16(d, dlen, sub_off + 6 + (cidx * 2))
        gcnt = _ot_u16(d, dlen, seq_off)
        out = list()
        i = 0
        while i < pos
            push(out, get(glyphs, i))
            i = i + 1
        end
        k = 0
        while k < gcnt
            ngid = _ot_u16(d, dlen, seq_off + 2 + (k * 2))
            push(out, ShapedGlyph(ngid, g0.sg_cluster, 0, 0, 0, 0, g0.sg_cp, g0.sg_mask, g0.sg_props))
            k = k + 1
        end
        i = pos + 1
        while i < len(glyphs)
            push(out, get(glyphs, i))
            i = i + 1
        end
        return [1, pos + gcnt, out]
    end

    // Type 3: Alternate Substitution (1 -> alt[0])
    if ltype == 3 and fmt == 1
        cov = sub_off + _ot_u16(d, dlen, sub_off + 2)
        cidx = ot_coverage_index(d, dlen, cov, g0.sg_gid)
        acnt = _ot_u16(d, dlen, sub_off + 4)
        if cidx < 0 or cidx >= acnt return [0, pos, glyphs] end
        aset_off = sub_off + _ot_u16(d, dlen, sub_off + 6 + (cidx * 2))
        if _ot_u16(d, dlen, aset_off) > 0
            g0.sg_gid = _ot_u16(d, dlen, aset_off + 2)
            return [1, pos + 1, glyphs]
        end
        return [0, pos, glyphs]
    end

    // Type 4: Ligature Substitution (N -> 1, e.g. Bengali ক্ষ / Arabic لا / Latin fi)
    if ltype == 4 and fmt == 1
        cov = sub_off + _ot_u16(d, dlen, sub_off + 2)
        cidx = ot_coverage_index(d, dlen, cov, g0.sg_gid)
        lscnt = _ot_u16(d, dlen, sub_off + 4)
        if cidx < 0 or cidx >= lscnt return [0, pos, glyphs] end
        lset_off = sub_off + _ot_u16(d, dlen, sub_off + 6 + (cidx * 2))
        lcnt = _ot_u16(d, dlen, lset_off)
        li = 0
        while li < lcnt
            lig_off = lset_off + _ot_u16(d, dlen, lset_off + 2 + (li * 2))
            lig_gid = _ot_u16(d, dlen, lig_off)
            comp_cnt = _ot_u16(d, dlen, lig_off + 2)
            if comp_cnt >= 1
                matched_indices = [pos]
                ok = 1
                cur = pos
                ci = 0
                while ci < comp_cnt - 1
                    cur = _ot_skip_ignored(glyphs, cur, 1, lflag)
                    if cur >= len(glyphs)
                        ok = 0
                        break
                    end
                    want_g = _ot_u16(d, dlen, lig_off + 4 + (ci * 2))
                    if get(glyphs, cur).sg_gid != want_g
                        ok = 0
                        break
                    end
                    push(matched_indices, cur)
                    ci = ci + 1
                end
                if ok == 1
                    // Build output replacing first matched glyph with ligature, dropping consumed components
                    g0.sg_gid = lig_gid
                    out = list()
                    gi = 0
                    while gi < len(glyphs)
                        drop = 0
                        mi = 1
                        while mi < len(matched_indices)
                            if get(matched_indices, mi) == gi
                                drop = 1
                                break
                            end
                            mi = mi + 1
                        end
                        if drop == 0
                            push(out, get(glyphs, gi))
                        end
                        gi = gi + 1
                    end
                    return [1, pos + 1, out]
                end
            end
            li = li + 1
        end
        return [0, pos, glyphs]
    end

    // Type 5: Contextual Substitution (Format 3 Coverage-based)
    if ltype == 5 and fmt == 3
        gcnt = _ot_u16(d, dlen, sub_off + 2)
        scnt = _ot_u16(d, dlen, sub_off + 4)
        if gcnt <= 0 or pos + gcnt > len(glyphs) return [0, pos, glyphs] end
        matched_pos = list()
        cur = pos
        ok = 1
        gi = 0
        while gi < gcnt
            if cur >= len(glyphs)
                ok = 0
                break
            end
            cov_i = sub_off + _ot_u16(d, dlen, sub_off + 6 + (gi * 2))
            if ot_coverage_index(d, dlen, cov_i, get(glyphs, cur).sg_gid) < 0
                ok = 0
                break
            end
            push(matched_pos, cur)
            cur = _ot_skip_ignored(glyphs, cur, 1, lflag)
            gi = gi + 1
        end
        if ok == 1
            rec_base = sub_off + 6 + (gcnt * 2)
            si = 0
            while si < scnt
                seq_idx = _ot_u16(d, dlen, rec_base + (si * 4))
                lkp_idx = _ot_u16(d, dlen, rec_base + (si * 4) + 2)
                if seq_idx < len(matched_pos)
                    tpos = get(matched_pos, seq_idx)
                    if tpos < len(glyphs)
                        r_n = _ot_gsub_apply_lookup_at(d, dlen, ll_off, lkp_idx, glyphs, tpos, 0, depth + 1)
                        glyphs = r_n[2]
                    end
                end
                si = si + 1
            end
            return [1, pos + 1, glyphs]
        end
        return [0, pos, glyphs]
    end

    // Type 6: Chaining Contextual Substitution (Format 3: Backtrack + Input + Lookahead)
    if ltype == 6 and fmt == 3
        p = sub_off + 2
        bcnt = _ot_u16(d, dlen, p)
        p = p + 2
        b_covs = p
        p = p + (bcnt * 2)
        icnt = _ot_u16(d, dlen, p)
        p = p + 2
        i_covs = p
        p = p + (icnt * 2)
        lcnt = _ot_u16(d, dlen, p)
        p = p + 2
        l_covs = p
        p = p + (lcnt * 2)
        scnt = _ot_u16(d, dlen, p)
        rec_base = p + 2
        if icnt <= 0 return [0, pos, glyphs] end

        // 1. Verify backtrack sequence (stored in reverse order from pos-1 backwards)
        ok = 1
        bcur = pos
        bi = 0
        while bi < bcnt
            bcur = _ot_skip_ignored(glyphs, bcur, 0 - 1, lflag)
            if bcur < 0
                ok = 0
                break
            end
            cov_b = sub_off + _ot_u16(d, dlen, b_covs + (bi * 2))
            if ot_coverage_index(d, dlen, cov_b, get(glyphs, bcur).sg_gid) < 0
                ok = 0
                break
            end
            bi = bi + 1
        end
        if ok == 0 return [0, pos, glyphs] end

        // 2. Verify input sequence starting at pos
        matched_pos = list()
        icur = pos
        ii = 0
        while ii < icnt
            if icur >= len(glyphs)
                ok = 0
                break
            end
            cov_i = sub_off + _ot_u16(d, dlen, i_covs + (ii * 2))
            if ot_coverage_index(d, dlen, cov_i, get(glyphs, icur).sg_gid) < 0
                ok = 0
                break
            end
            push(matched_pos, icur)
            if ii + 1 < icnt
                icur = _ot_skip_ignored(glyphs, icur, 1, lflag)
            end
            ii = ii + 1
        end
        if ok == 0 return [0, pos, glyphs] end

        // 3. Verify lookahead sequence after last input glyph
        lcur = icur
        li = 0
        while li < lcnt
            lcur = _ot_skip_ignored(glyphs, lcur, 1, lflag)
            if lcur >= len(glyphs)
                ok = 0
                break
            end
            cov_l = sub_off + _ot_u16(d, dlen, l_covs + (li * 2))
            if ot_coverage_index(d, dlen, cov_l, get(glyphs, lcur).sg_gid) < 0
                ok = 0
                break
            end
            li = li + 1
        end
        if ok == 0 return [0, pos, glyphs] end

        // 4. Execute nested SequenceLookupRecords
        si = 0
        while si < scnt
            seq_idx = _ot_u16(d, dlen, rec_base + (si * 4))
            lkp_idx = _ot_u16(d, dlen, rec_base + (si * 4) + 2)
            if seq_idx < len(matched_pos)
                tpos = get(matched_pos, seq_idx)
                if tpos < len(glyphs)
                    r_n = _ot_gsub_apply_lookup_at(d, dlen, ll_off, lkp_idx, glyphs, tpos, 0, depth + 1)
                    glyphs = r_n[2]
                end
            end
            si = si + 1
        end
        return [1, pos + 1, glyphs]
    end

    return [0, pos, glyphs]
end

fn _ot_gsub_apply_lookup_at d dlen ll_off lkp_idx glyphs pos req_mask depth
    lcnt = _ot_u16(d, dlen, ll_off)
    if lkp_idx < 0 or lkp_idx >= lcnt return [0, pos + 1, glyphs] end
    lkp_off = ll_off + _ot_u16(d, dlen, ll_off + 2 + (lkp_idx * 2))
    if lkp_off + 6 > dlen return [0, pos + 1, glyphs] end
    ltype = _ot_u16(d, dlen, lkp_off)
    lflag = _ot_u16(d, dlen, lkp_off + 2)
    scnt = _ot_u16(d, dlen, lkp_off + 4)
    si = 0
    while si < scnt
        sub_off = lkp_off + _ot_u16(d, dlen, lkp_off + 6 + (si * 2))
        res = _ot_gsub_apply_subtable(d, dlen, ll_off, ltype, lflag, sub_off, glyphs, pos, req_mask, depth)
        if res[0] == 1 return res end
        si = si + 1
    end
    return [0, pos + 1, glyphs]
end

fn ot_apply_gsub_feature font script_tags feat_str glyphs req_mask
    if font.ttf_gsub_off <= 0 return glyphs end
    d = font.ttf_data
    dlen = font.ttf_len
    gsub_off = font.ttf_gsub_off
    ll_off = gsub_off + _ot_u16(d, dlen, gsub_off + 8)
    lookups = ot_collect_feature_lookups(d, dlen, gsub_off, script_tags, ot_tag_from_str(feat_str))
    li = 0
    while li < len(lookups)
        lkp_idx = get(lookups, li)
        pos = 0
        while pos < len(glyphs)
            res = _ot_gsub_apply_lookup_at(d, dlen, ll_off, lkp_idx, glyphs, pos, req_mask, 0)
            glyphs = res[2]
            if res[0] == 1
                pos = res[1]
            else
                pos = pos + 1
            end
        end
        li = li + 1
    end
    return glyphs
end

// ── 5. GPOS Engine (Types 1, 2, 4, 6, 9) ─────────────────────────────────────

fn _ot_valrec_size vfmt
    sz = 0
    bit = 1
    i = 0
    while i < 8
        if (vfmt & bit) != 0 sz = sz + 2 end
        bit = bit * 2
        i = i + 1
    end
    return sz
end

fn _ot_apply_valrec d dlen off vfmt glyph
    cur = off
    if (vfmt & 1) != 0
        glyph.sg_x_off = glyph.sg_x_off + _ot_i16(d, dlen, cur)
        cur = cur + 2
    end
    if (vfmt & 2) != 0
        glyph.sg_y_off = glyph.sg_y_off + _ot_i16(d, dlen, cur)
        cur = cur + 2
    end
    if (vfmt & 4) != 0
        glyph.sg_x_adv = glyph.sg_x_adv + _ot_i16(d, dlen, cur)
        cur = cur + 2
    end
    if (vfmt & 8) != 0
        glyph.sg_y_adv = glyph.sg_y_adv + _ot_i16(d, dlen, cur)
        cur = cur + 2
    end
    if (vfmt & 16) != 0 cur = cur + 2 end
    if (vfmt & 32) != 0 cur = cur + 2 end
    if (vfmt & 64) != 0 cur = cur + 2 end
    if (vfmt & 128) != 0 cur = cur + 2 end
    return cur
end

fn _ot_read_anchor d dlen off
    if off <= 0 or off + 6 > dlen return [0, 0, 0] end
    // Formats 1, 2, 3 all place XCoordinate at +2 and YCoordinate at +4
    ax = _ot_i16(d, dlen, off + 2)
    ay = _ot_i16(d, dlen, off + 4)
    return [1, ax, ay]
end

fn _ot_gpos_apply_subtable d dlen ltype lflag sub_off glyphs pos depth
    if sub_off <= 0 or sub_off + 6 > dlen or depth > 8 return 0 end
    // Type 9: Extension Positioning
    if ltype == 9
        if _ot_u16(d, dlen, sub_off) != 1 return 0 end
        rt = _ot_u16(d, dlen, sub_off + 2)
        ro = sub_off + _ot_u32(d, dlen, sub_off + 4)
        return _ot_gpos_apply_subtable(d, dlen, rt, lflag, ro, glyphs, pos, depth + 1)
    end

    g0 = get(glyphs, pos)
    fmt = _ot_u16(d, dlen, sub_off)

    // Type 1: Single Adjustment
    if ltype == 1
        cov = sub_off + _ot_u16(d, dlen, sub_off + 2)
        cidx = ot_coverage_index(d, dlen, cov, g0.sg_gid)
        if cidx < 0 return 0 end
        vfmt = _ot_u16(d, dlen, sub_off + 4)
        if fmt == 1
            _ot_apply_valrec(d, dlen, sub_off + 6, vfmt, g0)
            return 1
        elif fmt == 2
            vcnt = _ot_u16(d, dlen, sub_off + 6)
            if cidx < vcnt
                vsz = _ot_valrec_size(vfmt)
                _ot_apply_valrec(d, dlen, sub_off + 8 + (cidx * vsz), vfmt, g0)
                return 1
            end
        end
        return 0
    end

    // Type 2: Pair Adjustment (Kerning — Fmt 1 Glyph Pairs & Fmt 2 Class Matrix)
    if ltype == 2
        nxt = _ot_skip_ignored(glyphs, pos, 1, lflag)
        if nxt >= len(glyphs) return 0 end
        g1 = get(glyphs, nxt)
        cov = sub_off + _ot_u16(d, dlen, sub_off + 2)
        cidx = ot_coverage_index(d, dlen, cov, g0.sg_gid)
        if cidx < 0 return 0 end
        vf1 = _ot_u16(d, dlen, sub_off + 4)
        vf2 = _ot_u16(d, dlen, sub_off + 6)
        sz1 = _ot_valrec_size(vf1)
        sz2 = _ot_valrec_size(vf2)
        if fmt == 1
            pscnt = _ot_u16(d, dlen, sub_off + 8)
            if cidx >= pscnt return 0 end
            ps_off = sub_off + _ot_u16(d, dlen, sub_off + 10 + (cidx * 2))
            pvcnt = _ot_u16(d, dlen, ps_off)
            rec_sz = 2 + sz1 + sz2
            lo = 0
            hi = pvcnt - 1
            while lo <= hi
                mid = (lo + hi) / 2
                ro = ps_off + 2 + (mid * rec_sz)
                sg = _ot_u16(d, dlen, ro)
                if g1.sg_gid < sg
                    hi = mid - 1
                elif g1.sg_gid > sg
                    lo = mid + 1
                else
                    _ot_apply_valrec(d, dlen, ro + 2, vf1, g0)
                    _ot_apply_valrec(d, dlen, ro + 2 + sz1, vf2, g1)
                    return 1
                end
            end
        elif fmt == 2
            cd1 = sub_off + _ot_u16(d, dlen, sub_off + 8)
            cd2 = sub_off + _ot_u16(d, dlen, sub_off + 10)
            c1cnt = _ot_u16(d, dlen, sub_off + 12)
            c2cnt = _ot_u16(d, dlen, sub_off + 14)
            cl1 = ot_class_def_get(d, dlen, cd1, g0.sg_gid)
            cl2 = ot_class_def_get(d, dlen, cd2, g1.sg_gid)
            if cl1 < c1cnt and cl2 < c2cnt
                cell_sz = sz1 + sz2
                cell_off = sub_off + 16 + (((cl1 * c2cnt) + cl2) * cell_sz)
                _ot_apply_valrec(d, dlen, cell_off, vf1, g0)
                _ot_apply_valrec(d, dlen, cell_off + sz1, vf2, g1)
                return 1
            end
        end
        return 0
    end

    // Type 4: Mark-to-Base Attachment (pos is mark glyph; attaches to nearest preceding base)
    if ltype == 4 and fmt == 1
        mcov = sub_off + _ot_u16(d, dlen, sub_off + 2)
        midx = ot_coverage_index(d, dlen, mcov, g0.sg_gid)
        if midx < 0 return 0 end
        bcov = sub_off + _ot_u16(d, dlen, sub_off + 4)
        // Find nearest preceding base glyph matching BaseCoverage
        bpos = pos - 1
        bidx = 0 - 1
        while bpos >= 0
            cand = get(glyphs, bpos)
            bi = ot_coverage_index(d, dlen, bcov, cand.sg_gid)
            if bi >= 0
                bidx = bi
                break
            end
            if (cand.sg_props & 4) == 0 break end
            bpos = bpos - 1
        end
        if bidx < 0 return 0 end
        class_cnt = _ot_u16(d, dlen, sub_off + 6)
        m_arr = sub_off + _ot_u16(d, dlen, sub_off + 8)
        b_arr = sub_off + _ot_u16(d, dlen, sub_off + 10)
        mcnt = _ot_u16(d, dlen, m_arr)
        bcnt = _ot_u16(d, dlen, b_arr)
        if midx >= mcnt or bidx >= bcnt return 0 end
        mrec = m_arr + 2 + (midx * 4)
        mclass = _ot_u16(d, dlen, mrec)
        manch_rel = _ot_u16(d, dlen, mrec + 2)
        if mclass >= class_cnt or manch_rel == 0 return 0 end
        brec = b_arr + 2 + (((bidx * class_cnt) + mclass) * 2)
        banch_rel = _ot_u16(d, dlen, brec)
        if banch_rel == 0 return 0 end
        ma = _ot_read_anchor(d, dlen, m_arr + manch_rel)
        ba = _ot_read_anchor(d, dlen, b_arr + banch_rel)
        if ma[0] == 1 and ba[0] == 1
            base_g = get(glyphs, bpos)
            // Position mark relative to base glyph origin minus intervening advances
            adv_between = 0
            ki = bpos
            while ki < pos
                adv_between = adv_between + get(glyphs, ki).sg_x_adv
                ki = ki + 1
            end
            g0.sg_x_off = base_g.sg_x_off + (ba[1] - ma[1]) - adv_between
            g0.sg_y_off = base_g.sg_y_off + (ba[2] - ma[2])
            return 1
        end
        return 0
    end

    // Type 6: Mark-to-Mark Attachment (pos is mark1; attaches to preceding mark2)
    if ltype == 6 and fmt == 1 and pos > 0
        m1cov = sub_off + _ot_u16(d, dlen, sub_off + 2)
        m1idx = ot_coverage_index(d, dlen, m1cov, g0.sg_gid)
        if m1idx < 0 return 0 end
        m2cov = sub_off + _ot_u16(d, dlen, sub_off + 4)
        prev_g = get(glyphs, pos - 1)
        m2idx = ot_coverage_index(d, dlen, m2cov, prev_g.sg_gid)
        if m2idx < 0 return 0 end
        class_cnt = _ot_u16(d, dlen, sub_off + 6)
        m1_arr = sub_off + _ot_u16(d, dlen, sub_off + 8)
        m2_arr = sub_off + _ot_u16(d, dlen, sub_off + 10)
        m1rec = m1_arr + 2 + (m1idx * 4)
        m1class = _ot_u16(d, dlen, m1rec)
        m1anch = _ot_u16(d, dlen, m1rec + 2)
        if m1class >= class_cnt or m1anch == 0 return 0 end
        m2anch = _ot_u16(d, dlen, m2_arr + 2 + (((m2idx * class_cnt) + m1class) * 2))
        if m2anch == 0 return 0 end
        a1 = _ot_read_anchor(d, dlen, m1_arr + m1anch)
        a2 = _ot_read_anchor(d, dlen, m2_arr + m2anch)
        if a1[0] == 1 and a2[0] == 1
            g0.sg_x_off = prev_g.sg_x_off + (a2[1] - a1[1]) - prev_g.sg_x_adv
            g0.sg_y_off = prev_g.sg_y_off + (a2[2] - a1[2])
            return 1
        end
    end
    return 0
end

fn ot_apply_gpos_feature font script_tags feat_str glyphs
    if font.ttf_gpos_off <= 0 return glyphs end
    d = font.ttf_data
    dlen = font.ttf_len
    gpos_off = font.ttf_gpos_off
    ll_off = gpos_off + _ot_u16(d, dlen, gpos_off + 8)
    lcnt = _ot_u16(d, dlen, ll_off)
    lookups = ot_collect_feature_lookups(d, dlen, gpos_off, script_tags, ot_tag_from_str(feat_str))
    li = 0
    while li < len(lookups)
        lkp_idx = get(lookups, li)
        if lkp_idx >= 0 and lkp_idx < lcnt
            lkp_off = ll_off + _ot_u16(d, dlen, ll_off + 2 + (lkp_idx * 2))
            ltype = _ot_u16(d, dlen, lkp_off)
            lflag = _ot_u16(d, dlen, lkp_off + 2)
            scnt = _ot_u16(d, dlen, lkp_off + 4)
            pos = 0
            while pos < len(glyphs)
                si = 0
                while si < scnt
                    sub_off = lkp_off + _ot_u16(d, dlen, lkp_off + 6 + (si * 2))
                    if _ot_gpos_apply_subtable(d, dlen, ltype, lflag, sub_off, glyphs, pos, 0) == 1
                        break
                    end
                    si = si + 1
                end
                pos = pos + 1
            end
        end
        li = li + 1
    end
    return glyphs
end

// ── 6. UTF-8 Decoder & Complex Script Classifiers (Bengali + Arabic) ─────────

fn shaper_decode_utf8 s
    cps = list()
    n = str_len(s)
    i = 0
    while i < n
        b0 = str_char_at(s, i) & 255
        if b0 < 128
            push(cps, b0)
            i = i + 1
        elif b0 >= 194 and b0 < 224 and i + 1 < n
            b1 = str_char_at(s, i + 1) & 255
            push(cps, ((b0 - 192) << 6) | (b1 & 63))
            i = i + 2
        elif b0 >= 224 and b0 < 240 and i + 2 < n
            b1 = str_char_at(s, i + 1) & 255
            b2 = str_char_at(s, i + 2) & 255
            push(cps, ((b0 - 224) << 12) | ((b1 & 63) << 6) | (b2 & 63))
            i = i + 3
        elif b0 >= 240 and i + 3 < n
            b1 = str_char_at(s, i + 1) & 255
            b2 = str_char_at(s, i + 2) & 255
            b3 = str_char_at(s, i + 3) & 255
            push(cps, ((b0 - 240) << 18) | ((b1 & 63) << 12) | ((b2 & 63) << 6) | (b3 & 63))
            i = i + 4
        else
            push(cps, b0)
            i = i + 1
        end
    end
    return cps
end

fn _shaper_is_bengali cp
    if cp >= 2432 and cp <= 2559 return 1 end // U+0980..U+09FF
    return 0
end

fn _shaper_is_bn_consonant cp
    // U+0995 (ক) .. U+09B9 (হ), U+09DC (ড়) .. U+09DF (য়), U+09F0..U+09F1
    if (cp >= 2453 and cp <= 2489) or (cp >= 2524 and cp <= 2527) or cp == 2544 or cp == 2545
        return 1
    end
    return 0
end

fn _shaper_is_bn_pre_matra cp
    // U+09BF (ি), U+09C7 (ে), U+09C8 (ৈ)
    if cp == 2495 or cp == 2503 or cp == 2504 return 1 end
    return 0
end

fn _shaper_is_arabic cp
    if cp >= 1536 and cp <= 1791 return 1 end // U+0600..U+06FF
    return 0
end

fn _shaper_arabic_join_type cp
    // Transparent combining marks (harakat U+064B..U+065F, U+0670, U+0610..U+061A)
    if (cp >= 1611 and cp <= 1631) or cp == 1648 or (cp >= 1552 and cp <= 1562)
        return AR_JOIN_T
    end
    // Join-causing: Tatweel U+0640, ZWJ U+200D
    if cp == 1600 or cp == 8205 return AR_JOIN_C end
    // Non-joining: Hamza U+0621
    if cp == 1569 return AR_JOIN_U end
    // Right-joining only: Alef variants, Teh Marbuta, Dal/Thal, Reh/Zain, Waw, Alef Maksura
    if cp == 1570 or cp == 1571 or cp == 1572 or cp == 1573 or cp == 1575 or cp == 1577 or cp == 1583 or cp == 1584 or cp == 1585 or cp == 1586 or cp == 1608 or cp == 1609
        return AR_JOIN_R
    end
    // Dual-joining standard Arabic letters (Yeh with Hamza, Beh..Ghain, Feh..Heh, Yeh)
    if cp == 1574 or cp == 1576 or (cp >= 1578 and cp <= 1582) or (cp >= 1587 and cp <= 1594) or (cp >= 1601 and cp <= 1607) or cp == 1610
        return AR_JOIN_D
    end
    return AR_JOIN_U
end

fn _shaper_fill_hmtx font glyphs
    i = 0
    while i < len(glyphs)
        g = get(glyphs, i)
        hm = ttf_get_hmetrics(font, g.sg_gid)
        g.sg_x_adv = hm[0]
        g.sg_y_adv = 0
        g.sg_x_off = 0
        g.sg_y_off = 0
        i = i + 1
    end
    return glyphs
end

// ── 7. Bengali (bng2 / beng) Indic Shaping Pipeline ──────────────────────────

fn shape_bengali_codepoints font cps
    // Step 1: Canonical Bengali split-vowel decomposition (ো -> ে+া, ৌ -> ে+ৗ)
    ecps = list()
    eclus = list()
    i = 0
    while i < len(cps)
        cp = get(cps, i)
        if cp == 2507 // U+09CB ো -> U+09C7 ে + U+09BE া
            push(ecps, 2503) push(eclus, i)
            push(ecps, 2494) push(eclus, i)
        elif cp == 2508 // U+09CC ৌ -> U+09C7 ে + U+09D7 ৗ
            push(ecps, 2503) push(eclus, i)
            push(ecps, 2519) push(eclus, i)
        else
            push(ecps, cp) push(eclus, i)
        end
        i = i + 1
    end

    // Step 2: Map codepoints -> ShapedGlyphs + mark Reph (র+্ before consonant) & pre-base matras
    glyphs = list()
    n = len(ecps)
    i = 0
    while i < n
        cp = get(ecps, i)
        gid = ttf_find_glyph(font, cp)
        mask = SHAPER_MASK_GLOBAL
        props = 0
        if _shaper_is_bn_pre_matra(cp) == 1
            props = props | 1
            if i == 0 or (i > 0 and get(ecps, i - 1) == 32)
                mask = mask | SHAPER_MASK_INIT
            end
        end
        // Detect Reph: র (U+09B0 = 2480) + ্ (U+09CD = 2509) followed by a consonant
        if cp == 2480 and i + 2 < n and get(ecps, i + 1) == 2509 and _shaper_is_bn_consonant(get(ecps, i + 2)) == 1
            mask = mask | SHAPER_MASK_RPHF
            props = props | 2
        end
        if cp == 2509 and i > 0 and get(ecps, i - 1) == 2480 and i + 1 < n and _shaper_is_bn_consonant(get(ecps, i + 1)) == 1
            mask = mask | SHAPER_MASK_RPHF
            props = props | 2
        end
        // Bengali combining signs (virama, nukta, candrabindu, matras) marked as props bit 2 if non-base
        if cp == 2492 or cp == 2433 or cp == 2497 or cp == 2498 or cp == 2499
            props = props | 4
        end
        push(glyphs, ShapedGlyph(gid, get(eclus, i), 0, 0, 0, 0, cp, mask, props))
        i = i + 1
    end

    stags = [ot_tag_from_str("bng2"), ot_tag_from_str("beng"), ot_tag_from_str("DFLT")]

    // Step 3: Basic Indic GSUB stage (locl, nukt, akhn, rphf, rkrf, blwf, half, pstf, vatu, cjct)
    glyphs = ot_apply_gsub_feature(font, stags, "locl", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "nukt", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "akhn", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "rphf", glyphs, SHAPER_MASK_RPHF)
    glyphs = ot_apply_gsub_feature(font, stags, "rkrf", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "blwf", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "half", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "pstf", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "vatu", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "cjct", glyphs, SHAPER_MASK_GLOBAL)

    // Step 4: Visual Reordering
    // 4a. Move formed Reph (props & 2) after its following base consonant cluster
    ri = 0
    while ri + 1 < len(glyphs)
        g = get(glyphs, ri)
        if (g.sg_props & 2) != 0
            // Advance past base consonant (+ virama + consonant chains)
            dst = ri + 1
            while dst + 2 < len(glyphs) and get(glyphs, dst + 1).sg_cp == 2509
                dst = dst + 2
            end
            // Shift elements [ri+1 .. dst] left by 1 and place Reph at dst
            k = ri
            while k < dst
                list_set(glyphs, k, get(glyphs, k + 1))
                k = k + 1
            end
            g.sg_props = g.sg_props & (0 - 3) // clear reph move bit once placed
            list_set(glyphs, dst, g)
            ri = dst + 1
        else
            ri = ri + 1
        end
    end

    // 4b. Move pre-base matra (ি/ে/ৈ, props & 1) visually BEFORE its consonant cluster!
    mi = 1
    while mi < len(glyphs)
        gm = get(glyphs, mi)
        if (gm.sg_props & 1) != 0
            // Walk left to start of the consonant cluster (skipping base + virama-joined consonants)
            start = mi - 1
            while start > 0 and get(glyphs, start - 1).sg_cp == 2509
                start = start - 2
                if start < 0 start = 0 end
            end
            if start < mi
                if start == 0 or get(glyphs, start - 1).sg_cp == 32
                    gm.sg_mask = gm.sg_mask | SHAPER_MASK_INIT
                end
                k = mi
                while k > start
                    list_set(glyphs, k, get(glyphs, k - 1))
                    k = k - 1
                end
                list_set(glyphs, start, gm)
            end
        end
        mi = mi + 1
    end

    // Step 5: Presentation GSUB stage (init, pres, abvs, blws, psts, haln, calt, clig)
    glyphs = ot_apply_gsub_feature(font, stags, "init", glyphs, SHAPER_MASK_INIT)
    glyphs = ot_apply_gsub_feature(font, stags, "pres", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "abvs", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "blws", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "psts", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "haln", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "calt", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "clig", glyphs, SHAPER_MASK_GLOBAL)

    // Step 6: Default hmtx advances + GPOS positioning (abvm, blwm, dist, kern, mark, mkmk)
    glyphs = _shaper_fill_hmtx(font, glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "dist", glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "abvm", glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "blwm", glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "kern", glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "mark", glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "mkmk", glyphs)
    return glyphs
end

// ── 8. Arabic (arab) Joining + RTL Shaping Pipeline ──────────────────────────

fn shape_arabic_codepoints font cps
    n = len(cps)
    jtypes = list()
    i = 0
    while i < n
        push(jtypes, _shaper_arabic_join_type(get(cps, i)))
        i = i + 1
    end

    // Compute per-glyph isol/init/medi/fina masks skipping transparent marks (AR_JOIN_T)
    glyphs = list()
    i = 0
    while i < n
        cp = get(cps, i)
        jt = get(jtypes, i)
        mask = SHAPER_MASK_GLOBAL
        props = 0
        if jt == AR_JOIN_T
            props = props | 4
        elif jt == AR_JOIN_R or jt == AR_JOIN_D
            // Find previous non-transparent character
            p = i - 1
            prev_jt = AR_JOIN_U
            while p >= 0
                pt = get(jtypes, p)
                if pt != AR_JOIN_T
                    prev_jt = pt
                    break
                end
                p = p - 1
            end
            // Find next non-transparent character
            q = i + 1
            next_jt = AR_JOIN_U
            while q < n
                nt = get(jtypes, q)
                if nt != AR_JOIN_T
                    next_jt = nt
                    break
                end
                q = q + 1
            end
            joins_prev = 0
            if prev_jt == AR_JOIN_D or prev_jt == AR_JOIN_C joins_prev = 1 end
            joins_next = 0
            if jt == AR_JOIN_D and (next_jt == AR_JOIN_R or next_jt == AR_JOIN_D or next_jt == AR_JOIN_C)
                joins_next = 1
            end
            if joins_prev == 1 and joins_next == 1
                mask = mask | SHAPER_MASK_MEDI
            elif joins_prev == 1
                mask = mask | SHAPER_MASK_FINA
            elif joins_next == 1
                mask = mask | SHAPER_MASK_AR_INI
            else
                mask = mask | SHAPER_MASK_ISOL
            end
        end
        gid = ttf_find_glyph(font, cp)
        push(glyphs, ShapedGlyph(gid, i, 0, 0, 0, 0, cp, mask, props))
        i = i + 1
    end

    stags = [ot_tag_from_str("arab"), ot_tag_from_str("DFLT")]
    glyphs = ot_apply_gsub_feature(font, stags, "ccmp", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "locl", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "isol", glyphs, SHAPER_MASK_ISOL)
    glyphs = ot_apply_gsub_feature(font, stags, "fina", glyphs, SHAPER_MASK_FINA)
    glyphs = ot_apply_gsub_feature(font, stags, "medi", glyphs, SHAPER_MASK_MEDI)
    glyphs = ot_apply_gsub_feature(font, stags, "init", glyphs, SHAPER_MASK_AR_INI)
    glyphs = ot_apply_gsub_feature(font, stags, "rlig", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "calt", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "liga", glyphs, SHAPER_MASK_GLOBAL)

    glyphs = _shaper_fill_hmtx(font, glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "kern", glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "mark", glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "mkmk", glyphs)

    // Reverse to visual RTL order (left-to-right display array)
    vis = list()
    k = len(glyphs) - 1
    while k >= 0
        push(vis, get(glyphs, k))
        k = k - 1
    end
    return vis
end

// ── 9. Latin / Default Pipeline & Top-Level UTF-8 Entry Point ────────────────

fn shape_latin_codepoints font cps
    glyphs = list()
    i = 0
    while i < len(cps)
        cp = get(cps, i)
        gid = ttf_find_glyph(font, cp)
        props = 0
        if cp >= 768 and cp <= 879 props = 4 end // Combining diacritical marks
        push(glyphs, ShapedGlyph(gid, i, 0, 0, 0, 0, cp, SHAPER_MASK_GLOBAL, props))
        i = i + 1
    end
    stags = [ot_tag_from_str("latn"), ot_tag_from_str("DFLT")]
    glyphs = ot_apply_gsub_feature(font, stags, "ccmp", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "liga", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "clig", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = ot_apply_gsub_feature(font, stags, "calt", glyphs, SHAPER_MASK_GLOBAL)
    glyphs = _shaper_fill_hmtx(font, glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "kern", glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "mark", glyphs)
    glyphs = ot_apply_gpos_feature(font, stags, "mkmk", glyphs)
    return glyphs
end

fn shape_text font utf8_str
    // WHY: Automatic multi-script run segmentation dispatching Bengali, Arabic, and Latin/Default
    // through full Pure-Lipi OpenType GSUB+GPOS shaping with zero HarfBuzz/ICU dependency.
    cps = shaper_decode_utf8(utf8_str)
    if len(cps) == 0 return list() end
    out = list()
    pos = 0
    n = len(cps)
    while pos < n
        c0 = get(cps, pos)
        scr = 0 // 0=latin/default, 1=bengali, 2=arabic
        if _shaper_is_bengali(c0) == 1
            scr = 1
        elif _shaper_is_arabic(c0) == 1
            scr = 2
        end
        run = list()
        while pos < n
            c = get(cps, pos)
            cs = 0
            if _shaper_is_bengali(c) == 1
                cs = 1
            elif _shaper_is_arabic(c) == 1
                cs = 2
            elif c == 32
                cs = scr // keep spaces inside current run
            end
            if cs != scr break end
            push(run, c)
            pos = pos + 1
        end
        shaped = list()
        if scr == 1
            shaped = shape_bengali_codepoints(font, run)
        elif scr == 2
            shaped = shape_arabic_codepoints(font, run)
        else
            shaped = shape_latin_codepoints(font, run)
        end
        si = 0
        while si < len(shaped)
            push(out, get(shaped, si))
            si = si + 1
        end
    end
    return out
end
