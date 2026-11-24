// ==============================================================================
// Wave D Regression Test:
//   D1: Pure-Lipi OpenType GSUB (Types 1/4) + GPOS (Types 2/4) Complex Script Shaper
//       - Bengali (bng2): conjunct ক্ষ (akhn), pre-base ি reordering, split vowel ো (ে+া + init),
//         Reph র+্ (rphf + post-base reordering)
//       - Arabic (arab): isol/init/medi/fina joining, mandatory rlig (لا), GPOS Mark-to-Base, RTL order
//       - Latin (latn): liga (fi) + GPOS Pair Kerning (AV) + live system OTF font check
//   D2: Pure-Lipi ELF64 Dynamic Linker (0% ld.so / 0% dlopen / 0% libc):
//       - Recursive BFS DT_NEEDED multi-.so graph + O(1) DT_GNU_HASH
//       - R_X86_64_JUMP_SLOT, R_X86_64_COPY, R_X86_64_IRELATIVE (IFUNC)
//       - PT_TLS + R_X86_64_TPOFF64 + SYS_arch_prctl(ARCH_SET_FS) %fs:tpoff read
//       - DT_INIT_ARRAY constructor execution
//       - Live system /lib/x86_64-linux-gnu/libz.so.1: zlibVersion(), crc32(), compress2()+uncompress()
// ==============================================================================

import "utso/core/shaper"
import "utso/core/ffi_sovereign"

// ── Binary Helper Writers for Synthetic SFNT & ELF64 Builders ────────────────

fn _wd_pu16 b v
    buf_write_byte(b, (v >> 8) & 255)
    buf_write_byte(b, v & 255)
    return 0
end

fn _wd_pu32 b v
    buf_write_byte(b, (v >> 24) & 255)
    buf_write_byte(b, (v >> 16) & 255)
    buf_write_byte(b, (v >> 8) & 255)
    buf_write_byte(b, v & 255)
    return 0
end

fn _wd_lu16 p off v
    mem_byte_write(p, off, v & 255)
    mem_byte_write(p, off + 1, (v >> 8) & 255)
    return 0
end

fn _wd_lu32 p off v
    mem_byte_write(p, off, v & 255)
    mem_byte_write(p, off + 1, (v >> 8) & 255)
    mem_byte_write(p, off + 2, (v >> 16) & 255)
    mem_byte_write(p, off + 3, (v >> 24) & 255)
    return 0
end

fn _wd_lu64 p off v
    mem_write(p, off, v)
    return 0
end

fn _wd_write_bytes p off arr
    i = 0
    while i < len(arr)
        mem_byte_write(p, off + i, get(arr, i) & 255)
        i = i + 1
    end
    return len(arr)
end

fn _wd_write_file path ptr sz
    fd = syscall(2, path, 577, 493, 0, 0, 0) // O_WRONLY|O_CREAT|O_TRUNC, 0755
    if fd < 0 return 0 end
    sent = 0
    while sent < sz
        w = syscall(1, fd, ptr + sent, sz - sent, 0, 0, 0)
        if w <= 0 break end
        sent = sent + w
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    if sent == sz return 1 end
    return 0
end

// ── D1: Build Real Binary SFNT Font with cmap + hmtx + GSUB + GPOS ───────────
// Glyph ID map:
//   1: ক (U+0995)  2: ষ (U+09B7)  3: র (U+09B0)  4: ্ (U+09CD)  5: ি (U+09BF)
//   6: ে (U+09C7)  7: া (U+09BE)  8: ৗ (U+09D7)  9: ম (U+09AE)
//  10: ب (U+0628) 11: ت (U+062A) 12: ل (U+0644) 13: ا (U+0627) 14: Fatha (U+064E)
//  20: 'A' (65)   21: 'V' (86)   22: 'f' (102)  23: 'i' (105)
// Shaped output GIDs (no direct cmap entry!):
//  30: ক্ষ (akhn: 1+4+2)   31: Reph (rphf: 3+4)  32: ে.init (init: 6->32)
//  40: ب.init  41: ت.medi  42: ب.fina  44: ل.init  45: ا.fina  46: لا (rlig: 44+45)
//  50: fi (liga: 22+23)

fn _wd_build_test_sfnt out_len_box
    // 1. head (54 bytes)
    t_head = buf_new(64)
    i = 0
    while i < 54 buf_write_byte(t_head, 0) i = i + 1 end
    hp = buf_ptr(t_head)
    mem_byte_write(hp, 18, 3) mem_byte_write(hp, 19, 232) // unitsPerEm = 1000

    // 2. maxp (6 bytes): version 1.0, numGlyphs = 64
    t_maxp = buf_new(16)
    _wd_pu32(t_maxp, 65536)
    _wd_pu16(t_maxp, 64)

    // 3. hhea (36 bytes): ascent=800, descent=-200, numHMetrics=64
    t_hhea = buf_new(40)
    i = 0
    while i < 36 buf_write_byte(t_hhea, 0) i = i + 1 end
    hhp = buf_ptr(t_hhea)
    mem_byte_write(hhp, 4, 3) mem_byte_write(hhp, 5, 32)   // ascent 800
    mem_byte_write(hhp, 6, 255) mem_byte_write(hhp, 7, 56) // descent -200
    mem_byte_write(hhp, 35, 64)                            // numHMetrics 64

    // 4. hmtx (64 * 4 = 256 bytes): default advance 600 (0 for mark gid 14)
    t_hmtx = buf_new(264)
    gi = 0
    while gi < 64
        adv = 600
        if gi == 14 adv = 0 end
        _wd_pu16(t_hmtx, adv)
        _wd_pu16(t_hmtx, 0)
        gi = gi + 1
    end

    // 5. cmap Format 12 (direct codepoint -> gid groups, sorted by startCharCode)
    // Entries: (65->20), (86->21), (102->22), (105->23),
    //   (1575->13), (1576->10), (1578->11), (1604->12), (1614->14),
    //   (2453->1), (2478->9), (2480->3), (2487->2), (2494->7), (2495->5), (2503->6), (2509->4), (2519->8)
    cps = [65, 86, 102, 105, 1575, 1576, 1578, 1604, 1614, 2453, 2478, 2480, 2487, 2494, 2495, 2503, 2509, 2519]
    gids = [20, 21, 22, 23, 13, 10, 11, 12, 14, 1, 9, 3, 2, 7, 5, 6, 4, 8]
    ng = len(cps)
    t_cmap = buf_new(300)
    _wd_pu16(t_cmap, 0)  // version
    _wd_pu16(t_cmap, 1)  // numTables
    _wd_pu16(t_cmap, 3)  // platform 3 (Windows)
    _wd_pu16(t_cmap, 10) // encoding 10 (Unicode full)
    _wd_pu32(t_cmap, 12) // offset to Format 12 subtable
    // Format 12 header (16 bytes) + ng * 12
    _wd_pu16(t_cmap, 12) // format
    _wd_pu16(t_cmap, 0)  // reserved
    _wd_pu32(t_cmap, 16 + (ng * 12))
    _wd_pu32(t_cmap, 0)  // language
    _wd_pu32(t_cmap, ng) // numGroups
    ci = 0
    while ci < ng
        _wd_pu32(t_cmap, get(cps, ci))
        _wd_pu32(t_cmap, get(cps, ci))
        _wd_pu32(t_cmap, get(gids, ci))
        ci = ci + 1
    end

    // 6. GSUB table (v1.0): 3 scripts (arab, bng2, latn), 8 features, 8 lookups (0..7)
    //   Lookup 0 (Type 4 Ligature, bng2 akhn): 1 + 4 + 2 -> 30 (ক্ষ)
    //   Lookup 1 (Type 4 Ligature, bng2 rphf): 3 + 4 -> 31 (Reph)
    //   Lookup 2 (Type 1 Single,   bng2 init): 6 -> 32 (ে.init)
    //   Lookup 3 (Type 1 Single,   arab init): 10 -> 40, 12 -> 44
    //   Lookup 4 (Type 1 Single,   arab medi): 11 -> 41
    //   Lookup 5 (Type 1 Single,   arab fina): 10 -> 42, 13 -> 45
    //   Lookup 6 (Type 4 Ligature, arab rlig): 44 + 45 -> 46 (لا)
    //   Lookup 7 (Type 4 Ligature, latn liga): 22 + 23 -> 50 (fi)
    gs = malloc(1024)
    zi = 0
    while zi < 1024 mem_byte_write(gs, zi, 0) zi = zi + 1 end
    // Header (10 bytes): v1.0, ScriptList@10, FeatureList@100, LookupList@260
    mem_byte_write(gs, 1, 1) // major=1
    mem_byte_write(gs, 5, 10)  // ScriptList = 10
    mem_byte_write(gs, 7, 100) // FeatureList = 100
    mem_byte_write(gs, 8, 1) mem_byte_write(gs, 9, 4) // LookupList = 260

    // ScriptList @ 10: 3 scripts (arab @+20, bng2 @+42, latn @+64)
    mem_byte_write(gs, 11, 3)
    // arab: features 3,4,5,6 (init, medi, fina, rlig)
    mem_byte_write(gs, 12, 97) mem_byte_write(gs, 13, 114) mem_byte_write(gs, 14, 97) mem_byte_write(gs, 15, 98)
    mem_byte_write(gs, 17, 20)
    // bng2: features 0,1,2 (akhn, rphf, init)
    mem_byte_write(gs, 18, 98) mem_byte_write(gs, 19, 110) mem_byte_write(gs, 20, 103) mem_byte_write(gs, 21, 50)
    mem_byte_write(gs, 23, 42)
    // latn: feature 7 (liga)
    mem_byte_write(gs, 24, 108) mem_byte_write(gs, 25, 97) mem_byte_write(gs, 26, 116) mem_byte_write(gs, 27, 110)
    mem_byte_write(gs, 29, 64)

    // ScriptTable arab @ 30 (rel 20): defaultLangSys @ +4 (abs 34)
    mem_byte_write(gs, 31, 4)
    // LangSys @ 34: lookupOrder=0, reqFeat=0xFFFF, count=4, [3,4,5,6]
    mem_byte_write(gs, 36, 255) mem_byte_write(gs, 37, 255)
    mem_byte_write(gs, 39, 4)
    mem_byte_write(gs, 41, 3) mem_byte_write(gs, 43, 4) mem_byte_write(gs, 45, 5) mem_byte_write(gs, 47, 6)

    // ScriptTable bng2 @ 52 (rel 42): defaultLangSys @ +4 (abs 56)
    mem_byte_write(gs, 53, 4)
    mem_byte_write(gs, 58, 255) mem_byte_write(gs, 59, 255)
    mem_byte_write(gs, 61, 3)
    mem_byte_write(gs, 63, 0) mem_byte_write(gs, 65, 1) mem_byte_write(gs, 67, 2)

    // ScriptTable latn @ 74 (rel 64): defaultLangSys @ +4 (abs 78)
    mem_byte_write(gs, 75, 4)
    mem_byte_write(gs, 80, 255) mem_byte_write(gs, 81, 255)
    mem_byte_write(gs, 83, 1)
    mem_byte_write(gs, 85, 7)

    // FeatureList @ 100: 8 features (tags at +2..+49, FeatureTables at +56, +62, ..., +98)
    mem_byte_write(gs, 101, 8)
    ftags = ["akhn", "rphf", "init", "init", "medi", "fina", "rlig", "liga"]
    fi = 0
    while fi < 8
        fo = 102 + (fi * 6)
        fs = get(ftags, fi)
        mem_byte_write(gs, fo, str_char_at(fs, 0))
        mem_byte_write(gs, fo + 1, str_char_at(fs, 1))
        mem_byte_write(gs, fo + 2, str_char_at(fs, 2))
        mem_byte_write(gs, fo + 3, str_char_at(fs, 3))
        ft_rel = 56 + (fi * 6)
        mem_byte_write(gs, fo + 4, (ft_rel >> 8) & 255)
        mem_byte_write(gs, fo + 5, ft_rel & 255)
        ft_abs = 100 + ft_rel
        mem_byte_write(gs, ft_abs + 3, 1)  // lookupCount = 1
        mem_byte_write(gs, ft_abs + 5, fi) // lookupListIndex = fi
        fi = fi + 1
    end

    // LookupList @ 260: 8 lookups at rel offsets [20, 68, 116, 152, 196, 232, 276, 324]
    mem_byte_write(gs, 261, 8)
    loffs = [20, 68, 116, 152, 196, 232, 276, 324]
    li = 0
    while li < 8
        lv = get(loffs, li)
        mem_byte_write(gs, 262 + (li * 2), (lv >> 8) & 255)
        mem_byte_write(gs, 263 + (li * 2), lv & 255)
        li = li + 1
    end

    // Lookup 0 @ 280 (Type 4 Ligature: 1+4+2 -> 30)
    // Lookup header (8B): type=4, flag=0, subCount=1, subOff=8
    mem_byte_write(gs, 281, 4) mem_byte_write(gs, 285, 1) mem_byte_write(gs, 287, 8)
    // Subtable @ 288: fmt=1, cov@8(296), ligSetCnt=1, ligSet@14(302)
    mem_byte_write(gs, 289, 1) mem_byte_write(gs, 291, 8) mem_byte_write(gs, 293, 1) mem_byte_write(gs, 295, 14)
    // Cov @ 296: fmt=1, cnt=1, gid=1
    mem_byte_write(gs, 297, 1) mem_byte_write(gs, 299, 1) mem_byte_write(gs, 301, 1)
    // LigSet @ 302: cnt=1, lig@4(306) -> ligGid=30, compCnt=3, [4, 2]
    mem_byte_write(gs, 303, 1) mem_byte_write(gs, 305, 4)
    mem_byte_write(gs, 307, 30) mem_byte_write(gs, 309, 3) mem_byte_write(gs, 311, 4) mem_byte_write(gs, 313, 2)

    // Lookup 1 @ 328 (Type 4 Ligature: 3+4 -> 31 Reph)
    mem_byte_write(gs, 329, 4) mem_byte_write(gs, 333, 1) mem_byte_write(gs, 335, 8)
    mem_byte_write(gs, 337, 1) mem_byte_write(gs, 339, 8) mem_byte_write(gs, 341, 1) mem_byte_write(gs, 343, 14)
    mem_byte_write(gs, 345, 1) mem_byte_write(gs, 347, 1) mem_byte_write(gs, 349, 3)
    mem_byte_write(gs, 351, 1) mem_byte_write(gs, 353, 4)
    mem_byte_write(gs, 355, 31) mem_byte_write(gs, 357, 2) mem_byte_write(gs, 359, 4)

    // Lookup 2 @ 376 (Type 1 Single Fmt 2: 6 -> 32)
    mem_byte_write(gs, 377, 1) mem_byte_write(gs, 381, 1) mem_byte_write(gs, 383, 8)
    // Subtable @ 384: fmt=2, cov@8(392), gcnt=1, subst=[32]
    mem_byte_write(gs, 385, 2) mem_byte_write(gs, 387, 8) mem_byte_write(gs, 389, 1) mem_byte_write(gs, 391, 32)
    mem_byte_write(gs, 393, 1) mem_byte_write(gs, 395, 1) mem_byte_write(gs, 397, 6)

    // Lookup 3 @ 412 (Type 1 Single Fmt 2, arab init: 10->40, 12->44)
    mem_byte_write(gs, 413, 1) mem_byte_write(gs, 417, 1) mem_byte_write(gs, 419, 8)
    // Subtable @ 420: fmt=2, cov@10(430), gcnt=2, subst=[40, 44]
    mem_byte_write(gs, 421, 2) mem_byte_write(gs, 423, 10) mem_byte_write(gs, 425, 2) mem_byte_write(gs, 427, 40) mem_byte_write(gs, 429, 44)
    mem_byte_write(gs, 431, 1) mem_byte_write(gs, 433, 2) mem_byte_write(gs, 435, 10) mem_byte_write(gs, 437, 12)

    // Lookup 4 @ 456 (Type 1 Single Fmt 2, arab medi: 11->41)
    mem_byte_write(gs, 457, 1) mem_byte_write(gs, 461, 1) mem_byte_write(gs, 463, 8)
    mem_byte_write(gs, 465, 2) mem_byte_write(gs, 467, 8) mem_byte_write(gs, 469, 1) mem_byte_write(gs, 471, 41)
    mem_byte_write(gs, 473, 1) mem_byte_write(gs, 475, 1) mem_byte_write(gs, 477, 11)

    // Lookup 5 @ 492 (Type 1 Single Fmt 2, arab fina: 10->42, 13->45)
    mem_byte_write(gs, 493, 1) mem_byte_write(gs, 497, 1) mem_byte_write(gs, 499, 8)
    mem_byte_write(gs, 501, 2) mem_byte_write(gs, 503, 10) mem_byte_write(gs, 505, 2) mem_byte_write(gs, 507, 42) mem_byte_write(gs, 509, 45)
    mem_byte_write(gs, 511, 1) mem_byte_write(gs, 513, 2) mem_byte_write(gs, 515, 10) mem_byte_write(gs, 517, 13)

    // Lookup 6 @ 536 (Type 4 Ligature, arab rlig, flag=IGNORE_MARKS(8): 44+45 -> 46 لا)
    mem_byte_write(gs, 537, 4) mem_byte_write(gs, 539, 8) mem_byte_write(gs, 541, 1) mem_byte_write(gs, 543, 8)
    mem_byte_write(gs, 545, 1) mem_byte_write(gs, 547, 8) mem_byte_write(gs, 549, 1) mem_byte_write(gs, 551, 14)
    mem_byte_write(gs, 553, 1) mem_byte_write(gs, 555, 1) mem_byte_write(gs, 557, 44)
    mem_byte_write(gs, 559, 1) mem_byte_write(gs, 561, 4)
    mem_byte_write(gs, 563, 46) mem_byte_write(gs, 565, 2) mem_byte_write(gs, 567, 45)

    // Lookup 7 @ 584 (Type 4 Ligature, latn liga: 22+23 -> 50 fi)
    mem_byte_write(gs, 585, 4) mem_byte_write(gs, 589, 1) mem_byte_write(gs, 591, 8)
    mem_byte_write(gs, 593, 1) mem_byte_write(gs, 595, 8) mem_byte_write(gs, 597, 1) mem_byte_write(gs, 599, 14)
    mem_byte_write(gs, 601, 1) mem_byte_write(gs, 603, 1) mem_byte_write(gs, 605, 22)
    mem_byte_write(gs, 607, 1) mem_byte_write(gs, 609, 4)
    mem_byte_write(gs, 611, 50) mem_byte_write(gs, 613, 2) mem_byte_write(gs, 615, 23)

    // 7. GPOS table (v1.0, 512 bytes):
    //   Script latn -> kern (Lookup 0: Pair Adjustment Fmt 1, (20, 21) -> XAdvance = -80)
    //   Script arab -> mark (Lookup 1: Mark-to-Base Fmt 1, mark=14 anchor(50,100) on base=40 anchor(250,600))
    gp = malloc(512)
    zi = 0
    while zi < 512 mem_byte_write(gp, zi, 0) zi = zi + 1 end
    mem_byte_write(gp, 1, 1)
    mem_byte_write(gp, 5, 10)  // ScriptList = 10
    mem_byte_write(gp, 7, 80)  // FeatureList = 80
    mem_byte_write(gp, 9, 140) // LookupList = 140

    // ScriptList @ 10: 2 scripts (arab @+14, latn @+32)
    mem_byte_write(gp, 11, 2)
    mem_byte_write(gp, 12, 97) mem_byte_write(gp, 13, 114) mem_byte_write(gp, 14, 97) mem_byte_write(gp, 15, 98)
    mem_byte_write(gp, 17, 14)
    mem_byte_write(gp, 18, 108) mem_byte_write(gp, 19, 97) mem_byte_write(gp, 20, 116) mem_byte_write(gp, 21, 110)
    mem_byte_write(gp, 23, 32)
    // arab @ 24 -> LangSys @ 28: feat [1]
    mem_byte_write(gp, 25, 4) mem_byte_write(gp, 30, 255) mem_byte_write(gp, 31, 255) mem_byte_write(gp, 33, 1) mem_byte_write(gp, 35, 1)
    // latn @ 42 -> LangSys @ 46: feat [0]
    mem_byte_write(gp, 43, 4) mem_byte_write(gp, 48, 255) mem_byte_write(gp, 49, 255) mem_byte_write(gp, 51, 1) mem_byte_write(gp, 53, 0)

    // FeatureList @ 80: 2 features (0=kern -> lkp 0, 1=mark -> lkp 1)
    mem_byte_write(gp, 81, 2)
    mem_byte_write(gp, 82, 107) mem_byte_write(gp, 83, 101) mem_byte_write(gp, 84, 114) mem_byte_write(gp, 85, 110)
    mem_byte_write(gp, 87, 16)
    mem_byte_write(gp, 88, 109) mem_byte_write(gp, 89, 97) mem_byte_write(gp, 90, 114) mem_byte_write(gp, 91, 107)
    mem_byte_write(gp, 93, 22)
    mem_byte_write(gp, 99, 1)  mem_byte_write(gp, 101, 0) // FeatureTable 0 @ 96 -> lookup 0
    mem_byte_write(gp, 105, 1) mem_byte_write(gp, 107, 1) // FeatureTable 1 @ 102 -> lookup 1

    // LookupList @ 140: 2 lookups at rel [10 (abs 150), 60 (abs 200)]
    mem_byte_write(gp, 141, 2)
    mem_byte_write(gp, 143, 10)
    mem_byte_write(gp, 145, 60)

    // GPOS Lookup 0 @ 150 (Type 2 Pair Adjustment Fmt 1: (20, 21) -> XAdvance = -80 = 0xFFB0)
    mem_byte_write(gp, 151, 2) mem_byte_write(gp, 155, 1) mem_byte_write(gp, 157, 8)
    // Subtable @ 158: fmt=1, cov@12(170), vf1=4(XAdvance), vf2=0, pairSetCnt=1, pairSet@18(176)
    mem_byte_write(gp, 159, 1) mem_byte_write(gp, 161, 12) mem_byte_write(gp, 163, 4) mem_byte_write(gp, 165, 0) mem_byte_write(gp, 167, 1) mem_byte_write(gp, 169, 18)
    // Cov @ 170: fmt=1, cnt=1, gid=20
    mem_byte_write(gp, 171, 1) mem_byte_write(gp, 173, 1) mem_byte_write(gp, 175, 20)
    // PairSet @ 176: cnt=1, secondGid=21, XAdv=-80 (0xFF, 0xB0 = 255, 176)
    mem_byte_write(gp, 177, 1) mem_byte_write(gp, 179, 21) mem_byte_write(gp, 180, 255) mem_byte_write(gp, 181, 176)

    // GPOS Lookup 1 @ 200 (Type 4 Mark-to-Base Fmt 1: mark=14 anchor(50,100) on base=40 anchor(250,600))
    mem_byte_write(gp, 201, 4) mem_byte_write(gp, 205, 1) mem_byte_write(gp, 207, 8)
    // Subtable @ 208: fmt=1, markCov@12(220), baseCov@18(226), classCnt=1, markArr@24(232), baseArr@40(248)
    mem_byte_write(gp, 209, 1) mem_byte_write(gp, 211, 12) mem_byte_write(gp, 213, 18) mem_byte_write(gp, 215, 1) mem_byte_write(gp, 217, 24) mem_byte_write(gp, 219, 40)
    // markCov @ 220: gid=14
    mem_byte_write(gp, 221, 1) mem_byte_write(gp, 223, 1) mem_byte_write(gp, 225, 14)
    // baseCov @ 226: gid=40
    mem_byte_write(gp, 227, 1) mem_byte_write(gp, 229, 1) mem_byte_write(gp, 231, 40)
    // markArr @ 232: cnt=1, rec0=(class=0, anchorOff=6 -> abs 238: fmt=1, x=50, y=100)
    mem_byte_write(gp, 233, 1) mem_byte_write(gp, 235, 0) mem_byte_write(gp, 237, 6)
    mem_byte_write(gp, 239, 1) mem_byte_write(gp, 241, 50) mem_byte_write(gp, 243, 100)
    // baseArr @ 248: cnt=1, base0 class0 anchorOff=4 -> abs 252: fmt=1, x=250, y=600 (0x0258)
    mem_byte_write(gp, 249, 1) mem_byte_write(gp, 251, 4)
    mem_byte_write(gp, 253, 1) mem_byte_write(gp, 255, 250) mem_byte_write(gp, 256, 2) mem_byte_write(gp, 257, 88)

    // Assemble complete SFNT container (7 tables: GPOS, GSUB, cmap, head, hhea, hmtx, maxp)
    // Header = 12 + 7*16 = 124 bytes -> pad to 128
    t_ptrs = [gp, gs, buf_ptr(t_cmap), buf_ptr(t_head), buf_ptr(t_hhea), buf_ptr(t_hmtx), buf_ptr(t_maxp)]
    t_lens = [512, 1024, buf_len(t_cmap), buf_len(t_head), buf_len(t_hhea), buf_len(t_hmtx), buf_len(t_maxp)]
    t_tags = ["GPOS", "GSUB", "cmap", "head", "hhea", "hmtx", "maxp"]
    total = 128
    ti = 0
    while ti < 7
        total = total + ((get(t_lens, ti) + 3) / 4) * 4
        ti = ti + 1
    end
    sfnt = malloc(total)
    zi = 0
    while zi < total mem_byte_write(sfnt, zi, 0) zi = zi + 1 end
    // SFNT magic 0x00010000, numTables=7
    mem_byte_write(sfnt, 1, 1)
    mem_byte_write(sfnt, 5, 7)
    cur_off = 128
    ti = 0
    while ti < 7
        rec = 12 + (ti * 16)
        ts = get(t_tags, ti)
        tl = get(t_lens, ti)
        mem_byte_write(sfnt, rec, str_char_at(ts, 0))
        mem_byte_write(sfnt, rec + 1, str_char_at(ts, 1))
        mem_byte_write(sfnt, rec + 2, str_char_at(ts, 2))
        mem_byte_write(sfnt, rec + 3, str_char_at(ts, 3))
        // offset BE
        mem_byte_write(sfnt, rec + 8, (cur_off >> 24) & 255)
        mem_byte_write(sfnt, rec + 9, (cur_off >> 16) & 255)
        mem_byte_write(sfnt, rec + 10, (cur_off >> 8) & 255)
        mem_byte_write(sfnt, rec + 11, cur_off & 255)
        // length BE
        mem_byte_write(sfnt, rec + 12, (tl >> 24) & 255)
        mem_byte_write(sfnt, rec + 13, (tl >> 16) & 255)
        mem_byte_write(sfnt, rec + 14, (tl >> 8) & 255)
        mem_byte_write(sfnt, rec + 15, tl & 255)
        mem_copy(sfnt + cur_off, get(t_ptrs, ti), tl)
        cur_off = cur_off + ((tl + 3) / 4) * 4
        ti = ti + 1
    end

    buf_free(t_head)
    buf_free(t_maxp)
    buf_free(t_hhea)
    buf_free(t_hmtx)
    buf_free(t_cmap)
    free(gs, 1024)
    free(gp, 512)
    list_set(out_len_box, 0, total)
    return sfnt
end

fn test_d1_opentype_shaper()
    slen = [0]
    sfnt = _wd_build_test_sfnt(slen)
    font = ttf_load_from_memory(sfnt, slen[0])
    if font.ttf_valid != 1 or font.ttf_gsub_off == 0 or font.ttf_gpos_off == 0
        print("FAIL D1: synthetic SFNT font invalid")
        return 1
    end

    // 1. Bengali conjunct + pre-base matra: ক্ষি (ক + ্ + ষ + ি) -> [ি (5), ক্ষ (30)]
    g_bn1 = shape_bengali_codepoints(font, [2453, 2509, 2487, 2495])
    if len(g_bn1) != 2 or get(g_bn1, 0).sg_gid != 5 or get(g_bn1, 1).sg_gid != 30
        print("FAIL D1: Bengali ক্ষি expected gids [5,30] got len=" + str(len(g_bn1)))
        return 1
    end

    // 2. Bengali split vowel: কো (ক + ো) -> decompose to ে+া, reorder ে to start + init -> [32, 1, 7]
    g_bn2 = shape_bengali_codepoints(font, [2453, 2507])
    if len(g_bn2) != 3 or get(g_bn2, 0).sg_gid != 32 or get(g_bn2, 1).sg_gid != 1 or get(g_bn2, 2).sg_gid != 7
        print("FAIL D1: Bengali কো expected gids [32,1,7] got len=" + str(len(g_bn2)))
        return 1
    end

    // 3. Bengali Reph: র্ম (র + ্ + ম) -> rphf (31) reordered AFTER ম (9) -> [9, 31]
    g_bn3 = shape_bengali_codepoints(font, [2480, 2509, 2478])
    if len(g_bn3) != 2 or get(g_bn3, 0).sg_gid != 9 or get(g_bn3, 1).sg_gid != 31
        print("FAIL D1: Bengali র্ম Reph expected gids [9,31]")
        return 1
    end

    // 4. Arabic بتب + Fatha (U+0628, U+064E, U+062A, U+0628):
    //    Logical: [ب.init(40), Fatha(14, y_off=500, x_off=-400), ت.medi(41), ب.fina(42)]
    //    Visual RTL: [ب.fina(42), ت.medi(41), Fatha(14), ب.init(40)]
    g_ar1 = shape_arabic_codepoints(font, [1576, 1614, 1578, 1576])
    if len(g_ar1) != 4 or get(g_ar1, 0).sg_gid != 42 or get(g_ar1, 1).sg_gid != 41 or get(g_ar1, 2).sg_gid != 14 or get(g_ar1, 3).sg_gid != 40
        print("FAIL D1: Arabic بتب contextual+RTL gids mismatch")
        return 1
    end
    fatha_g = get(g_ar1, 2)
    // Base anchor (250,600) - Mark anchor (50,100) = (200, 500); minus base advance 600 => x_off=-400, y_off=500
    if fatha_g.sg_y_off != 500 or fatha_g.sg_x_off != (0 - 400)
        print("FAIL D1: Arabic GPOS Mark-to-Base anchor expected (-400,500) got (" + str(fatha_g.sg_x_off) + "," + str(fatha_g.sg_y_off) + ")")
        return 1
    end

    // 5. Arabic mandatory Lam-Alef ligature: لا (U+0644, U+0627) -> single gid 46!
    g_ar2 = shape_arabic_codepoints(font, [1604, 1575])
    if len(g_ar2) != 1 or get(g_ar2, 0).sg_gid != 46
        print("FAIL D1: Arabic لا rlig ligature expected [46]")
        return 1
    end

    // 6. Latin UTF-8 end-to-end shape_text: "AVfi" -> [A(20, adv=520), V(21, adv=600), fi(50, adv=600)]
    g_lat = shape_text(font, "AVfi")
    if len(g_lat) != 3 or get(g_lat, 0).sg_gid != 20 or get(g_lat, 0).sg_x_adv != 520 or get(g_lat, 1).sg_gid != 21 or get(g_lat, 2).sg_gid != 50
        print("FAIL D1: Latin AVfi kern+liga mismatch")
        return 1
    end

    // 7. Live real system OTF font smoke test (if installed on host)
    sys_otf = "/usr/share/fonts/opentype/urw-base35/NimbusRoman-Regular.otf"
    if syscall(21, sys_otf, 4, 0, 0, 0, 0) == 0
        sfont = ttf_load_file(sys_otf)
        if sfont.ttf_valid == 1
            sg_real = shape_text(sfont, "AVfi")
            if len(sg_real) < 2
                print("FAIL D1: system OTF shaper returned empty run")
                ttf_free_font(sfont)
                return 1
            end
            ttf_free_font(sfont)
        end
    end

    ttf_free_font(font)
    return 0
end

// ── D2: Synthetic Multi-.so ELF64 Graph Builder (DT_NEEDED + GNU_HASH + IFUNC + COPY + PT_TLS + INIT_ARRAY) ──

fn _wd_build_dep_so path soname
    // 2 pages (8192 bytes):
    //   Page 0 (0x0000..0x0FFF, RX): ELF Header + 3 PHDRs (PT_LOAD RX, PT_LOAD RW, PT_DYNAMIC)
    //     0x200: .dynsym (3 entries: 0=NULL, 1=dep_mul_add@0x500, 2=dep_magic_val@0x1100 sz=8)
    //     0x280: .dynstr ("\0dep_mul_add\0dep_magic_val\0" + soname + "\0")
    //     0x380: .gnu.hash (nbuckets=1, symoffset=1, bloom_sz=1, bloom_shift=6, bloom=0xFFFFFFFFFFFFFFFF, bucket[0]=1, chains=[h1&~1, h2|1])
    //     0x500: dep_mul_add(a,b,c): imul rdi, rsi; lea rax, [rdi+rdx]; ret (48 0f af fe 48 8d 04 17 c3)
    //   Page 1 (0x1000..0x1FFF, RW):
    //     0x1000: .dynamic (DT_SONAME, DT_STRTAB=0x280, DT_SYMTAB=0x200, DT_GNU_HASH=0x380, DT_NULL)
    //     0x1100: dep_magic_val = 0x1122334455667788 (1234605616436508552)
    sz = 8192
    p = malloc(sz)
    i = 0
    while i < sz mem_byte_write(p, i, 0) i = i + 1 end

    // ELF64 Header (ET_DYN=3, EM_X86_64=62, phoff=64, phentsize=56, phnum=3)
    _wd_write_bytes(p, 0, [127, 69, 76, 70, 2, 1, 1, 0])
    _wd_lu16(p, 16, 3)  // ET_DYN
    _wd_lu16(p, 18, 62) // EM_X86_64
    _wd_lu32(p, 20, 1)
    _wd_lu64(p, 32, 64) // e_phoff
    _wd_lu16(p, 52, 64) // e_ehsize
    _wd_lu16(p, 54, 56) // e_phentsize
    _wd_lu16(p, 56, 3)  // e_phnum

    // PHDR 0: PT_LOAD RX (off=0, vaddr=0, sz=0x1000, flags=5)
    _wd_lu32(p, 64, 1) _wd_lu32(p, 68, 5)
    _wd_lu64(p, 72, 0) _wd_lu64(p, 80, 0) _wd_lu64(p, 88, 0) _wd_lu64(p, 96, 4096) _wd_lu64(p, 104, 4096) _wd_lu64(p, 112, 4096)
    // PHDR 1: PT_LOAD RW (off=0x1000, vaddr=0x1000, sz=0x1000, flags=6)
    _wd_lu32(p, 120, 1) _wd_lu32(p, 124, 6)
    _wd_lu64(p, 128, 4096) _wd_lu64(p, 136, 4096) _wd_lu64(p, 144, 4096) _wd_lu64(p, 152, 4096) _wd_lu64(p, 160, 4096) _wd_lu64(p, 168, 4096)
    // PHDR 2: PT_DYNAMIC (off=0x1000, vaddr=0x1000, sz=128, flags=6)
    _wd_lu32(p, 176, 2) _wd_lu32(p, 180, 6)
    _wd_lu64(p, 184, 4096) _wd_lu64(p, 192, 4096) _wd_lu64(p, 200, 4096) _wd_lu64(p, 208, 128) _wd_lu64(p, 216, 128) _wd_lu64(p, 224, 8)

    // .dynstr @ 0x280 (640)
    s1 = "dep_mul_add"
    s2 = "dep_magic_val"
    off_s1 = 1
    ci = 0
    while ci < str_len(s1) mem_byte_write(p, 640 + off_s1 + ci, str_char_at(s1, ci)) ci = ci + 1 end
    off_s2 = off_s1 + str_len(s1) + 1
    ci = 0
    while ci < str_len(s2) mem_byte_write(p, 640 + off_s2 + ci, str_char_at(s2, ci)) ci = ci + 1 end
    off_so = off_s2 + str_len(s2) + 1
    ci = 0
    while ci < str_len(soname) mem_byte_write(p, 640 + off_so + ci, str_char_at(soname, ci)) ci = ci + 1 end

    // .dynsym @ 0x200 (512): sym 1 = dep_mul_add (vaddr 0x500=1280), sym 2 = dep_magic_val (vaddr 0x1100=4352, sz=8)
    _wd_lu32(p, 512 + 24, off_s1) mem_byte_write(p, 512 + 28, 18) _wd_lu16(p, 512 + 30, 1) _wd_lu64(p, 512 + 32, 1280) _wd_lu64(p, 512 + 40, 16)
    _wd_lu32(p, 512 + 48, off_s2) mem_byte_write(p, 512 + 52, 17) _wd_lu16(p, 512 + 54, 2) _wd_lu64(p, 512 + 56, 4352) _wd_lu64(p, 512 + 64, 8)

    // .gnu.hash @ 0x380 (896)
    _wd_lu32(p, 896, 1)  // nbuckets = 1
    _wd_lu32(p, 900, 1)  // symoffset = 1
    _wd_lu32(p, 904, 1)  // bloom_sz = 1
    _wd_lu32(p, 908, 6)  // bloom_shift = 6
    _wd_lu64(p, 912, 0 - 1) // all bloom bits set
    _wd_lu32(p, 920, 1)  // bucket[0] = sym 1
    h1 = _ffi_gnu_hash_name(s1) & 4294967294
    h2 = (_ffi_gnu_hash_name(s2) & 4294967294) | 1
    _wd_lu32(p, 924, h1)
    _wd_lu32(p, 928, h2)

    // .text @ 0x500 (1280): dep_mul_add(a, b, c) -> a*b + c
    _wd_write_bytes(p, 1280, [72, 15, 175, 254, 72, 141, 4, 23, 195])

    // .dynamic @ 0x1000 (4096)
    dp = 4096
    _wd_lu64(p, dp, DT_SONAME)   _wd_lu64(p, dp + 8, off_so) dp = dp + 16
    _wd_lu64(p, dp, DT_STRTAB)   _wd_lu64(p, dp + 8, 640)    dp = dp + 16
    _wd_lu64(p, dp, DT_SYMTAB)   _wd_lu64(p, dp + 8, 512)    dp = dp + 16
    _wd_lu64(p, dp, DT_GNU_HASH) _wd_lu64(p, dp + 8, 896)    dp = dp + 16
    _wd_lu64(p, dp, DT_NULL)     _wd_lu64(p, dp + 8, 0)

    // .data @ 0x1100 (4352): dep_magic_val = 0x1122334455667788
    _wd_lu64(p, 4352, 1234605616436508552)

    ok = _wd_write_file(path, p, sz)
    free(p, sz)
    return ok
end

fn _wd_build_app_so path dep_soname
    // 2 pages (8192 bytes) with 4 PHDRs: PT_LOAD RX, PT_LOAD RW, PT_DYNAMIC, PT_TLS!
    //   Page 0 (RX):
    //     0x200: .dynsym (9 entries):
    //       1=dep_mul_add (UND)          2=dep_magic_val (UND, sz=8)
    //       3=app_call_dep (0x600)       4=app_call_ifunc (0x620)
    //       5=app_read_tls (0x640)       6=app_read_copy (0x660)
    //       7=app_read_init_flag (0x680) 8=tls_seed (shndx=2, val=0)
    //     0x300: .dynstr
    //     0x400: DT_HASH (nbuckets=1, nchain=9)
    //     0x440: .rela.dyn (6 entries * 24 = 144 bytes):
    //       [0] R_X86_64_JUMP_SLOT @ 0x1200 -> sym 1 (dep_mul_add from dep.so!)
    //       [1] R_X86_64_IRELATIVE @ 0x1208 -> addend 0x6A0 (IFUNC resolver -> returns 0x6C0!)
    //       [2] R_X86_64_TPOFF64   @ 0x1210 -> sym 8 (tls_seed offset in %fs!)
    //       [3] R_X86_64_COPY      @ 0x1220 -> sym 2 (copies 8B dep_magic_val from dep.so!)
    //       [4] R_X86_64_RELATIVE  @ 0x1180 -> addend 0x6E0 (DT_INIT_ARRAY[0] -> ctor!)
    //     0x600: app_call_dep:       jmp qword ptr [rip + (0x1200 - 0x606)]  -> FF 25 FA 0B 00 00
    //     0x620: app_call_ifunc:     jmp qword ptr [rip + (0x1208 - 0x626)]  -> FF 25 E2 0B 00 00
    //     0x640: app_read_tls:       mov rax, [rip + (0x1210 - 0x647)]; mov rax, fs:[rax]; ret
    //                                -> 48 8B 05 C9 0B 00 00 | 64 48 8B 00 | C3
    //     0x660: app_read_copy:      mov rax, [rip + (0x1220 - 0x667)]; ret -> 48 8B 05 B9 0B 00 00 C3
    //     0x680: app_read_init_flag: mov rax, [rip + (0x1228 - 0x687)]; ret -> 48 8B 05 A1 0B 00 00 C3
    //     0x6A0: ifunc_resolver:     lea rax, [rip + (0x6C0 - 0x6A7)]; ret  -> 48 8D 05 19 00 00 00 C3
    //     0x6C0: ifunc_impl(x):      lea rax, [rdi + 4200]; ret             -> 48 8D 87 68 10 00 00 C3
    //     0x6E0: init_ctor():        mov qword ptr [rip + (0x1228 - 0x6EB)], 9001; ret
    //                                -> 48 C7 05 3D 0B 00 00 29 23 00 00 C3
    //     0x700: PT_TLS initial image (8 bytes): 777
    //   Page 1 (RW):
    //     0x1000: .dynamic
    //     0x1180: .init_array (8 bytes)
    //     0x1200: GOT / data slots
    sz = 8192
    p = malloc(sz)
    i = 0
    while i < sz mem_byte_write(p, i, 0) i = i + 1 end

    _wd_write_bytes(p, 0, [127, 69, 76, 70, 2, 1, 1, 0])
    _wd_lu16(p, 16, 3)
    _wd_lu16(p, 18, 62)
    _wd_lu32(p, 20, 1)
    _wd_lu64(p, 32, 64)
    _wd_lu16(p, 52, 64)
    _wd_lu16(p, 54, 56)
    _wd_lu16(p, 56, 4) // 4 PHDRs

    // PHDR 0: PT_LOAD RX
    _wd_lu32(p, 64, 1) _wd_lu32(p, 68, 5)
    _wd_lu64(p, 72, 0) _wd_lu64(p, 80, 0) _wd_lu64(p, 88, 0) _wd_lu64(p, 96, 4096) _wd_lu64(p, 104, 4096) _wd_lu64(p, 112, 4096)
    // PHDR 1: PT_LOAD RW
    _wd_lu32(p, 120, 1) _wd_lu32(p, 124, 6)
    _wd_lu64(p, 128, 4096) _wd_lu64(p, 136, 4096) _wd_lu64(p, 144, 4096) _wd_lu64(p, 152, 4096) _wd_lu64(p, 160, 4096) _wd_lu64(p, 168, 4096)
    // PHDR 2: PT_DYNAMIC (0x1000, sz=256)
    _wd_lu32(p, 176, 2) _wd_lu32(p, 180, 6)
    _wd_lu64(p, 184, 4096) _wd_lu64(p, 192, 4096) _wd_lu64(p, 200, 4096) _wd_lu64(p, 208, 256) _wd_lu64(p, 216, 256) _wd_lu64(p, 224, 8)
    // PHDR 3: PT_TLS (foff=0x700=1792, filesz=8, memsz=16, align=16)
    _wd_lu32(p, 232, PT_TLS) _wd_lu32(p, 236, 4)
    _wd_lu64(p, 240, 1792) _wd_lu64(p, 248, 1792) _wd_lu64(p, 256, 1792) _wd_lu64(p, 264, 8) _wd_lu64(p, 272, 16) _wd_lu64(p, 280, 16)

    // .dynstr @ 0x300 (768)
    snames = [dep_soname, "dep_mul_add", "dep_magic_val", "app_call_dep", "app_call_ifunc", "app_read_tls", "app_read_copy", "app_read_init_flag", "tls_seed", "app_gnu_ifunc"]
    soffs = list()
    cur_s = 1
    si = 0
    while si < len(snames)
        push(soffs, cur_s)
        ss = get(snames, si)
        ci = 0
        while ci < str_len(ss)
            mem_byte_write(p, 768 + cur_s + ci, str_char_at(ss, ci))
            ci = ci + 1
        end
        cur_s = cur_s + str_len(ss) + 1
        si = si + 1
    end

    // .dynsym @ 0x200 (512)
    // sym 1: dep_mul_add (UND)
    _wd_lu32(p, 512 + 24, get(soffs, 1)) mem_byte_write(p, 512 + 28, 18) _wd_lu16(p, 512 + 30, 0)
    // sym 2: dep_magic_val (UND, st_size=8 for R_X86_64_COPY)
    _wd_lu32(p, 512 + 48, get(soffs, 2)) mem_byte_write(p, 512 + 52, 17) _wd_lu16(p, 512 + 54, 0) _wd_lu64(p, 512 + 64, 8)
    // sym 3..7: exported functions @ 0x600, 0x620, 0x640, 0x660, 0x680
    fn_addrs = [1536, 1568, 1600, 1632, 1664]
    fi = 0
    while fi < 5
        se = 512 + ((3 + fi) * 24)
        _wd_lu32(p, se, get(soffs, 3 + fi))
        mem_byte_write(p, se + 4, 18)
        _wd_lu16(p, se + 6, 1)
        _wd_lu64(p, se + 8, get(fn_addrs, fi))
        _wd_lu64(p, se + 16, 16)
        fi = fi + 1
    end
    // sym 8: tls_seed (st_shndx=2, st_value=0)
    _wd_lu32(p, 512 + (8 * 24), get(soffs, 8)) mem_byte_write(p, 512 + (8 * 24) + 4, 22) _wd_lu16(p, 512 + (8 * 24) + 6, 2) _wd_lu64(p, 512 + (8 * 24) + 8, 0)
    // sym 9: app_gnu_ifunc (STB_GLOBAL|STT_GNU_IFUNC = 26, resolver @ 0x6A0 = 1696!)
    _wd_lu32(p, 512 + (9 * 24), get(soffs, 9)) mem_byte_write(p, 512 + (9 * 24) + 4, 26) _wd_lu16(p, 512 + (9 * 24) + 6, 1) _wd_lu64(p, 512 + (9 * 24) + 8, 1696) _wd_lu64(p, 512 + (9 * 24) + 16, 16)

    // DT_HASH @ 0x400 (1024): nbuckets=1, nchain=10
    _wd_lu32(p, 1024, 1) _wd_lu32(p, 1028, 10)

    // .rela.dyn @ 0x440 (1088): 5 relocations (120 bytes)
    ro = 1088
    // [0] JUMP_SLOT @ 0x1200 (4608) -> sym 1 (dep_mul_add)
    _wd_lu64(p, ro, 4608) _wd_lu64(p, ro + 8, (1 << 32) | R_X86_64_JUMP_SLOT) _wd_lu64(p, ro + 16, 0) ro = ro + 24
    // [1] IRELATIVE @ 0x1208 (4616) -> resolver @ 0x6A0 (1696)
    _wd_lu64(p, ro, 4616) _wd_lu64(p, ro + 8, R_X86_64_IRELATIVE) _wd_lu64(p, ro + 16, 1696) ro = ro + 24
    // [2] TPOFF64 @ 0x1210 (4624) -> sym 8 (tls_seed)
    _wd_lu64(p, ro, 4624) _wd_lu64(p, ro + 8, (8 << 32) | R_X86_64_TPOFF64) _wd_lu64(p, ro + 16, 0) ro = ro + 24
    // [3] COPY @ 0x1220 (4640) -> sym 2 (dep_magic_val)
    _wd_lu64(p, ro, 4640) _wd_lu64(p, ro + 8, (2 << 32) | R_X86_64_COPY) _wd_lu64(p, ro + 16, 0) ro = ro + 24
    // [4] RELATIVE @ 0x1180 (4480 = DT_INIT_ARRAY[0]) -> ctor @ 0x6E0 (1760)
    _wd_lu64(p, ro, 4480) _wd_lu64(p, ro + 8, R_X86_64_RELATIVE) _wd_lu64(p, ro + 16, 1760)

    // Machine code functions in .text
    _wd_write_bytes(p, 1536, [255, 37, 250, 11, 0, 0])                             // 0x600: jmp [rip+0xBFA] -> 0x1200
    _wd_write_bytes(p, 1568, [255, 37, 226, 11, 0, 0])                             // 0x620: jmp [rip+0xBE2] -> 0x1208
    _wd_write_bytes(p, 1600, [72, 139, 5, 201, 11, 0, 0, 100, 72, 139, 0, 195])    // 0x640: mov rax,[rip+0xBC9]; mov rax,fs:[rax]; ret
    _wd_write_bytes(p, 1632, [72, 139, 5, 185, 11, 0, 0, 195])                     // 0x660: mov rax,[rip+0xBB9]; ret -> 0x1220
    _wd_write_bytes(p, 1664, [72, 139, 5, 161, 11, 0, 0, 195])                     // 0x680: mov rax,[rip+0xBA1]; ret -> 0x1228
    _wd_write_bytes(p, 1696, [72, 141, 5, 25, 0, 0, 0, 195])                       // 0x6A0: lea rax,[rip+0x19] (0x6C0); ret
    _wd_write_bytes(p, 1728, [72, 141, 135, 104, 16, 0, 0, 195])                   // 0x6C0: lea rax,[rdi+4200]; ret
    _wd_write_bytes(p, 1760, [72, 199, 5, 61, 11, 0, 0, 41, 35, 0, 0, 195])        // 0x6E0: mov qword [rip+0xB3D] (0x1228), 9001; ret

    // PT_TLS initial data @ 0x700 (1792): tls_seed = 777
    _wd_lu64(p, 1792, 777)

    // .dynamic @ 0x1000 (4096)
    dp = 4096
    _wd_lu64(p, dp, DT_NEEDED)       _wd_lu64(p, dp + 8, get(soffs, 0)) dp = dp + 16
    _wd_lu64(p, dp, DT_STRTAB)       _wd_lu64(p, dp + 8, 768)           dp = dp + 16
    _wd_lu64(p, dp, DT_SYMTAB)       _wd_lu64(p, dp + 8, 512)           dp = dp + 16
    _wd_lu64(p, dp, DT_HASH)         _wd_lu64(p, dp + 8, 1024)          dp = dp + 16
    _wd_lu64(p, dp, DT_RELA)         _wd_lu64(p, dp + 8, 1088)          dp = dp + 16
    _wd_lu64(p, dp, DT_RELASZ)       _wd_lu64(p, dp + 8, 120)           dp = dp + 16
    _wd_lu64(p, dp, DT_INIT_ARRAY)   _wd_lu64(p, dp + 8, 4480)          dp = dp + 16
    _wd_lu64(p, dp, DT_INIT_ARRAYSZ) _wd_lu64(p, dp + 8, 8)             dp = dp + 16
    _wd_lu64(p, dp, DT_NULL)         _wd_lu64(p, dp + 8, 0)

    ok = _wd_write_file(path, p, sz)
    free(p, sz)
    return ok
end

fn test_d2_sovereign_elf64_linker()
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    dep_so = "lib_wd_dep_" + str(pid) + ".so"
    dep_path = "/tmp/" + dep_so
    app_path = "/tmp/lib_wd_app_" + str(pid) + ".so"

    if _wd_build_dep_so(dep_path, dep_so) != 1 or _wd_build_app_so(app_path, dep_so) != 1
        print("FAIL D2a: failed to write synthetic ELF64 .so graph")
        return 1
    end

    // Load ONLY app.so — linker must recursively BFS-load dep.so via DT_NEEDED, resolve via DT_GNU_HASH,
    // patch JUMP_SLOT + COPY + TPOFF64 + IRELATIVE IFUNC, set %fs TCB, and execute DT_INIT_ARRAY!
    app_lib = ffi_load_so(app_path)
    syscall(87, dep_path, 0, 0, 0, 0, 0)
    syscall(87, app_path, 0, 0, 0, 0, 0)

    if get(app_lib, 6) != 1
        print("FAIL D2a: ffi_load_so(app_path) failed")
        return 1
    end

    f_dep   = ffi_find_symbol(app_lib, "app_call_dep")
    f_ifunc = ffi_find_symbol(app_lib, "app_call_ifunc")
    f_gif   = ffi_find_symbol(app_lib, "app_gnu_ifunc")
    f_tls   = ffi_find_symbol(app_lib, "app_read_tls")
    f_copy  = ffi_find_symbol(app_lib, "app_read_copy")
    f_init  = ffi_find_symbol(app_lib, "app_read_init_flag")
    if f_dep == 0 or f_ifunc == 0 or f_gif == 0 or f_tls == 0 or f_copy == 0 or f_init == 0
        print("FAIL D2a: missing exported symbols from app_lib")
        return 1
    end

    r_dep   = ffi_call_native(f_dep, 6, 7, 100, 0, 0)
    r_ifunc = ffi_call_native(f_ifunc, 88, 0, 0, 0, 0)
    r_gif   = ffi_call_native(f_gif, 77, 0, 0, 0, 0)
    r_tls   = ffi_call_native(f_tls, 0, 0, 0, 0, 0)
    r_copy  = ffi_call_native(f_copy, 0, 0, 0, 0, 0)
    r_init  = ffi_call_native(f_init, 0, 0, 0, 0, 0)

    if r_dep != 142
        print("FAIL D2a: DT_NEEDED + DT_GNU_HASH + JUMP_SLOT expected 142 got " + str(r_dep))
        return 1
    end
    if r_ifunc != 4288 or r_gif != 4277
        print("FAIL D2a: IFUNC (IRELATIVE + STT_GNU_IFUNC) expected 4288,4277 got " + str(r_ifunc) + "," + str(r_gif))
        return 1
    end
    if r_tls != 777
        print("FAIL D2a: PT_TLS + TPOFF64 + ARCH_SET_FS expected 777 got " + str(r_tls))
        return 1
    end
    if r_copy != 1234605616436508552
        print("FAIL D2a: R_X86_64_COPY expected 0x1122334455667788 got " + str(r_copy))
        return 1
    end
    if r_init != 9001
        print("FAIL D2a: DT_INIT_ARRAY constructor expected 9001 got " + str(r_init))
        return 1
    end

    // Part B: LIVE REAL SYSTEM C LIBRARY /lib/x86_64-linux-gnu/libz.so.1 (0% ld.so, 0% dlopen, 0% libc!)
    libz_path = ""
    if syscall(21, "/lib/x86_64-linux-gnu/libz.so.1", 4, 0, 0, 0, 0) == 0
        libz_path = "/lib/x86_64-linux-gnu/libz.so.1"
    elif syscall(21, "/usr/lib/x86_64-linux-gnu/libz.so.1", 4, 0, 0, 0, 0) == 0
        libz_path = "/usr/lib/x86_64-linux-gnu/libz.so.1"
    end
    if len(libz_path) > 0
        z_lib = ffi_load_so(libz_path)
        if get(z_lib, 6) != 1
            print("FAIL D2b: ffi_load_so(" + libz_path + ") failed")
            return 1
        end
        fn_ver  = ffi_find_symbol(z_lib, "zlibVersion")
        fn_crc  = ffi_find_symbol(z_lib, "crc32")
        fn_comp = ffi_find_symbol(z_lib, "compress2")
        fn_unc  = ffi_find_symbol(z_lib, "uncompress")
        if fn_ver == 0 or fn_crc == 0 or fn_comp == 0 or fn_unc == 0
            print("FAIL D2b: failed to resolve libz.so.1 symbols via DT_GNU_HASH")
            return 1
        end

        // 1. zlibVersion() -> real C string starting with '1'
        vptr = ffi_call_native(fn_ver, 0, 0, 0, 0, 0)
        if vptr <= 4096 or (mem_byte_read(vptr, 0) & 255) != 49
            print("FAIL D2b: zlibVersion() returned invalid string")
            return 1
        end

        // 2. crc32(0, "123456789", 9) == 0xCBF43926 (3421780262)
        check_s = "123456789"
        crc_got = ffi_call_native(fn_crc, 0, check_s, 9, 0, 0) & 4294967295
        if crc_got != 3421780262
            print("FAIL D2b: libz crc32 expected 3421780262 got " + str(crc_got))
            return 1
        end

        // 3. compress2 + uncompress (invokes Lipi's C-ABI malloc/free/memcpy/memset & FS:0x28 canary!)
        src_msg = "Lipi Sovereign Pure-Silicon ELF64 Dynamic Linker running real libz.so.1 with ZERO ld.so and ZERO libc! Lipi is Lipi! Lipi is Lipi!"
        src_len = str_len(src_msg)
        comp_buf = malloc(512)
        comp_len_box = malloc(8)
        mem_write(comp_len_box, 0, 512)
        rc_c = ffi_call_native(fn_comp, comp_buf, comp_len_box, src_msg, src_len, 6)
        comp_sz = mem_read(comp_len_box, 0)
        if rc_c != 0 or comp_sz <= 0 or comp_sz >= src_len
            print("FAIL D2b: libz compress2 failed rc=" + str(rc_c) + " sz=" + str(comp_sz))
            free(comp_buf, 512)
            free(comp_len_box, 8)
            return 1
        end

        dec_buf = malloc(512)
        dec_len_box = malloc(8)
        mem_write(dec_len_box, 0, 512)
        rc_u = ffi_call_native(fn_unc, dec_buf, dec_len_box, comp_buf, comp_sz, 0)
        dec_sz = mem_read(dec_len_box, 0)
        ok_eq = 1
        if rc_u != 0 or dec_sz != src_len
            ok_eq = 0
        else
            k = 0
            while k < src_len
                if (mem_byte_read(dec_buf, k) & 255) != (str_char_at(src_msg, k) & 255)
                    ok_eq = 0
                    break
                end
                k = k + 1
            end
        end
        free(comp_buf, 512)
        free(comp_len_box, 8)
        free(dec_buf, 512)
        free(dec_len_box, 8)
        if ok_eq != 1
            print("FAIL D2b: libz uncompress round-trip mismatch rc=" + str(rc_u))
            return 1
        end
    end

    return 0
end

fn main()
    if test_d1_opentype_shaper() != 0 return 1 end
    if test_d2_sovereign_elf64_linker() != 0 return 2 end
    print("PASS: test_wave_d_shaper_ffi (OpenType GSUB/GPOS Bengali+Arabic+Latin shaper + ELF64 DT_NEEDED/IFUNC/TLS/COPY/INIT_ARRAY + live libz.so.1)")
    return 0
end
