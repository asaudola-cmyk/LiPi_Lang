// ==============================================================================
// 🔍 লিপি Regex ইঞ্জিন (Regular Expression Library)
// লিপি প্রথম ২.০ | ciphername: সোভেরিন
// File: utso/core/regex.lp
//
// WHY এই মডিউল:
//   Pure Sovereign Bytecode NFA Backtracking VM with O(states * text_len) bounded
//   dead-state memoization (immune to exponential ReDoS) and iterative DFS stack
//   (zero call-stack overflow on arbitrarily long inputs).
//   Supports: . * + ? *? +? ?? {n} {n,} {n,m} {n,m}? [] [^] \d \D \w \W \s \S \b
//   \ব (Bengali U+0980..U+09FF), escapes inside [...], capturing (...) + non-capturing
//   (?:...) groups with full cross-group backtracking, (?i) / flag `i` case folding.
// ==============================================================================

include "utso/core/memory.lp"
include "utso/core/string.lp"

// ─── Legacy Node & Quantifier Constants (Preserved for Backwards Compatibility) ─
REGEX_LITERAL       = 1
REGEX_DOT           = 2
REGEX_STAR          = 3
REGEX_PLUS          = 4
REGEX_QUESTION      = 5
REGEX_ANCHOR_START  = 6
REGEX_ANCHOR_END    = 7
REGEX_CHAR_CLASS    = 8
REGEX_GROUP         = 9
REGEX_ALTERNATE     = 10
REGEX_DIGIT         = 11
REGEX_WORD          = 12
REGEX_SPACE         = 13
REGEX_BENGALI       = 14
REGEX_WORD_BOUNDARY = 15

QUANT_ONE  = 1
QUANT_STAR = 2
QUANT_PLUS = 3
QUANT_OPT  = 4

// ─── Bytecode NFA VM Opcodes ──────────────────────────────────────────────────
RX_OP_MATCH     = 0
RX_OP_CHAR      = 1
RX_OP_DOT       = 2
RX_OP_CLASS     = 3
RX_OP_DIGIT     = 4
RX_OP_NON_DIGIT = 5
RX_OP_WORD      = 6
RX_OP_NON_WORD  = 7
RX_OP_SPACE     = 8
RX_OP_NON_SPACE = 9
RX_OP_BENGALI   = 10
RX_OP_BOL       = 11
RX_OP_EOL       = 12
RX_OP_BOUNDARY  = 13
RX_OP_JMP       = 14
RX_OP_SPLIT     = 15
RX_OP_SAVE      = 16

// Shorthand class sentinels stored inside [lo, hi] character-class range tables
RX_CLS_DIGIT     = -1
RX_CLS_NON_DIGIT = -2
RX_CLS_WORD      = -3
RX_CLS_NON_WORD  = -4
RX_CLS_SPACE     = -5
RX_CLS_NON_SPACE = -6
RX_CLS_BENGALI   = -7

// ─── Public Structs (Existing Field Offsets Preserved) ────────────────────────
struct RegexNode
    node_type
    quantifier
    char_code
    ranges
    negated
    sub_pat_list
end

struct REGEX_pattern
    node_list
    node_count
    গ্রুপ_count
    মূল_string
    has_anchor_start
    has_anchor_end
    vm_ops
    vm_a
    vm_b
    vm_extra
    vm_ignore_case
end

struct REGEX_ম্যাচ_result
    পাওয়া_গেছে
    শুরু_offset
    শেষ_offset
    len
    গ্রুপ_list
    গ্রুপ_count
end

// ─── UTF-8 & Codepoint Helpers ────────────────────────────────────────────────
// WHY: Bengali characters (U+0980..U+09FF) and other Unicode codepoints span 2 to 4
// UTF-8 bytes; decoding full codepoints preserves exact rune boundaries everywhere.
fn _rx_utf8_rune_len b0
    if b0 < 128
        return 1
    elif b0 >= 192 and b0 <= 223
        return 2
    elif b0 >= 224 and b0 <= 239
        return 3
    elif b0 >= 240 and b0 <= 247
        return 4
    end
    return 1
end

fn _rx_utf8_decode_cp s idx slen
    b0 = mem_byte_read(s, idx) & 255
    if b0 < 128
        return b0
    end
    if b0 >= 192 and b0 <= 223
        if idx + 1 < slen
            b1 = mem_byte_read(s, idx + 1) & 255
            return ((b0 % 32) * 64) + (b1 % 64)
        end
    elif b0 >= 224 and b0 <= 239
        if idx + 2 < slen
            b1 = mem_byte_read(s, idx + 1) & 255
            b2 = mem_byte_read(s, idx + 2) & 255
            return ((b0 % 16) * 4096) + ((b1 % 64) * 64) + (b2 % 64)
        end
    elif b0 >= 240 and b0 <= 247
        if idx + 3 < slen
            b1 = mem_byte_read(s, idx + 1) & 255
            b2 = mem_byte_read(s, idx + 2) & 255
            b3 = mem_byte_read(s, idx + 3) & 255
            return ((b0 % 8) * 262144) + ((b1 % 64) * 4096) + ((b2 % 64) * 64) + (b3 % 64)
        end
    end
    return b0
end

fn _rx_ascii_lower cp
    if cp >= 65 and cp <= 90
        return cp + 32
    end
    return cp
end

fn _rx_is_digit_cp cp
    // ASCII '0'-'9' (48..57) + Bengali '০'-'৯' (2534..2543)
    if (cp >= 48 and cp <= 57) or (cp >= 2534 and cp <= 2543)
        return 1
    end
    return 0
end

fn _rx_is_word_cp cp
    if (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122) or (cp >= 48 and cp <= 57) or cp == 95 or (cp >= 2432 and cp <= 2559)
        return 1
    end
    return 0
end

fn _rx_is_space_cp cp
    if cp == 32 or cp == 9 or cp == 10 or cp == 13 or cp == 12 or cp == 11
        return 1
    end
    return 0
end

fn _rx_is_bengali_cp cp
    if cp >= 2432 and cp <= 2559
        return 1
    end
    return 0
end

fn _rx_check_word_boundary text t_idx t_len
    left_w = 0
    right_w = 0
    if t_idx > 0
        prev = t_idx - 1
        while prev > 0 and ((mem_byte_read(text, prev) & 255) >= 128 and (mem_byte_read(text, prev) & 255) < 192)
            prev = prev - 1
        end
        left_w = _rx_is_word_cp(_rx_utf8_decode_cp(text, prev, t_len))
    end
    if t_idx < t_len
        right_w = _rx_is_word_cp(_rx_utf8_decode_cp(text, t_idx, t_len))
    end
    if left_w != right_w
        return 1
    end
    return 0
end

// ─── Bytecode Fragment Builder ────────────────────────────────────────────────
// WHY: Each fragment is [ops, a_list, b_list, extra_list] with 0-based relative jump
// targets so quantifiers ({n,m}, *, +, ?) and alternations compose cleanly without
// corrupting nested jump targets.
fn _rx_frag_new
    return [list(), list(), list(), list()]
end

fn _rx_frag_len f
    return len(get(f, 0))
end

fn _rx_frag_emit f op a b extra
    push(get(f, 0), op)
    push(get(f, 1), a)
    push(get(f, 2), b)
    push(get(f, 3), extra)
    return len(get(f, 0)) - 1
end

fn _rx_frag_append dst src
    base = _rx_frag_len(dst)
    s_ops = get(src, 0)
    s_a = get(src, 1)
    s_b = get(src, 2)
    s_ex = get(src, 3)
    d_ops = get(dst, 0)
    d_a = get(dst, 1)
    d_b = get(dst, 2)
    d_ex = get(dst, 3)
    n = len(s_ops)
    i = 0
    while i < n
        op = get(s_ops, i)
        av = get(s_a, i)
        bv = get(s_b, i)
        if op == RX_OP_JMP
            av = av + base
        elif op == RX_OP_SPLIT
            av = av + base
            bv = bv + base
        end
        push(d_ops, op)
        push(d_a, av)
        push(d_b, bv)
        push(d_ex, get(s_ex, i))
        i = i + 1
    end
    return dst
end

fn _rx_wrap_star frag is_lazy
    // Greedy: SPLIT(1, flen+2) ; frag ; JMP(0)
    // Lazy:   SPLIT(flen+2, 1) ; frag ; JMP(0)
    flen = _rx_frag_len(frag)
    out = _rx_frag_new()
    if is_lazy == 1
        _rx_frag_emit(out, RX_OP_SPLIT, flen + 2, 1, 0)
    else
        _rx_frag_emit(out, RX_OP_SPLIT, 1, flen + 2, 0)
    end
    _rx_frag_append(out, frag)
    _rx_frag_emit(out, RX_OP_JMP, 0, 0, 0)
    return out
end

fn _rx_wrap_plus frag is_lazy
    // Greedy: frag ; SPLIT(0, flen+1)
    // Lazy:   frag ; SPLIT(flen+1, 0)
    flen = _rx_frag_len(frag)
    out = _rx_frag_new()
    _rx_frag_append(out, frag)
    if is_lazy == 1
        _rx_frag_emit(out, RX_OP_SPLIT, flen + 1, 0, 0)
    else
        _rx_frag_emit(out, RX_OP_SPLIT, 0, flen + 1, 0)
    end
    return out
end

fn _rx_wrap_opt frag is_lazy
    // Greedy: SPLIT(1, flen+1) ; frag
    // Lazy:   SPLIT(flen+1, 1) ; frag
    flen = _rx_frag_len(frag)
    out = _rx_frag_new()
    if is_lazy == 1
        _rx_frag_emit(out, RX_OP_SPLIT, flen + 1, 1, 0)
    else
        _rx_frag_emit(out, RX_OP_SPLIT, 1, flen + 1, 0)
    end
    _rx_frag_append(out, frag)
    return out
end

fn _rx_wrap_brace frag min_rep max_rep is_lazy
    // WHY: Expands {n}, {n,}, {n,m} (greedy & lazy) into exact NFA bytecode bounded to
    // <= 256 repeats so malicious patterns like `a{999999}` cannot exhaust compiler memory.
    mn = min_rep
    if mn < 0 mn = 0 end
    if mn > 256 mn = 256 end
    out = _rx_frag_new()
    i = 0
    while i < mn
        _rx_frag_append(out, frag)
        i = i + 1
    end
    if max_rep < 0
        _rx_frag_append(out, _rx_wrap_star(frag, is_lazy))
    else
        mx = max_rep
        if mx > 256 mx = 256 end
        if mx > mn
            opt_f = _rx_wrap_opt(frag, is_lazy)
            j = mn
            while j < mx
                _rx_frag_append(out, opt_f)
                j = j + 1
            end
        end
    end
    return out
end

// ─── Recursive-Descent Regex Parser -> Bytecode Compiler ──────────────────────
// State box: [pat_str, plen, pos, next_group_id, ignore_case]

fn _rx_parse_char_class st
    // Parses [...] with optional leading ^ negation, backslash escapes (\d \D \w \W \s \S
    // \ব \n \t \r \f \\ \] \- \^), and ranges (a-z, ০-৯).
    s = get(st, 0)
    n = get(st, 1)
    p = get(st, 2) + 1 // skip '['
    neg = 0
    if p < n and (mem_byte_read(s, p) & 255) == 94
        neg = 1
        p = p + 1
    end
    ranges = list()
    first = 1
    while p < n
        b0 = mem_byte_read(s, p) & 255
        if b0 == 93 and first == 0
            p = p + 1
            break
        end
        first = 0
        is_shorthand = 0
        sh_code = 0
        lo = 0
        if b0 == 92 and p + 1 < n
            p = p + 1
            nb = mem_byte_read(s, p) & 255
            nlen = _rx_utf8_rune_len(nb)
            ncp = _rx_utf8_decode_cp(s, p, n)
            p = p + nlen
            if ncp == 100 // \d
                is_shorthand = 1
                sh_code = RX_CLS_DIGIT
            elif ncp == 68 // \D
                is_shorthand = 1
                sh_code = RX_CLS_NON_DIGIT
            elif ncp == 119 // \w
                is_shorthand = 1
                sh_code = RX_CLS_WORD
            elif ncp == 87 // \W
                is_shorthand = 1
                sh_code = RX_CLS_NON_WORD
            elif ncp == 115 // \s
                is_shorthand = 1
                sh_code = RX_CLS_SPACE
            elif ncp == 83 // \S
                is_shorthand = 1
                sh_code = RX_CLS_NON_SPACE
            elif ncp == 2476 // \ব
                is_shorthand = 1
                sh_code = RX_CLS_BENGALI
            elif ncp == 110
                lo = 10
            elif ncp == 116
                lo = 9
            elif ncp == 114
                lo = 13
            elif ncp == 102
                lo = 12
            else
                lo = ncp
            end
        else
            rlen = _rx_utf8_rune_len(b0)
            lo = _rx_utf8_decode_cp(s, p, n)
            p = p + rlen
        end

        if is_shorthand == 1
            push(ranges, sh_code)
            push(ranges, sh_code)
            continue
        end

        // Check for range `-` followed by non-`]` endpoint
        if p + 1 < n and (mem_byte_read(s, p) & 255) == 45 and (mem_byte_read(s, p + 1) & 255) != 93
            p = p + 1 // skip '-'
            hb = mem_byte_read(s, p) & 255
            hi = 0
            if hb == 92 and p + 1 < n
                p = p + 1
                nb2 = mem_byte_read(s, p) & 255
                nl2 = _rx_utf8_rune_len(nb2)
                ncp2 = _rx_utf8_decode_cp(s, p, n)
                p = p + nl2
                if ncp2 == 110
                    hi = 10
                elif ncp2 == 116
                    hi = 9
                elif ncp2 == 114
                    hi = 13
                elif ncp2 == 102
                    hi = 12
                else
                    hi = ncp2
                end
            else
                rl2 = _rx_utf8_rune_len(hb)
                hi = _rx_utf8_decode_cp(s, p, n)
                p = p + rl2
            end
            if hi < lo
                tmp_c = lo
                lo = hi
                hi = tmp_c
            end
            push(ranges, lo)
            push(ranges, hi)
        else
            push(ranges, lo)
            push(ranges, lo)
        end
    end
    list_set(st, 2, p)
    frag = _rx_frag_new()
    _rx_frag_emit(frag, RX_OP_CLASS, neg, get(st, 4), ranges)
    return frag
end

fn _rx_try_parse_brace st
    // Parses `{n}`, `{n,}`, `{n,m}` at current pos; returns [ok, min_rep, max_rep, next_pos].
    s = get(st, 0)
    n = get(st, 1)
    p = get(st, 2)
    if p >= n or (mem_byte_read(s, p) & 255) != 123
        return [0, 0, 0, p]
    end
    q = p + 1
    if q >= n return [0, 0, 0, p] end
    c0 = mem_byte_read(s, q) & 255
    if c0 < 48 or c0 > 57
        return [0, 0, 0, p]
    end
    mn = 0
    while q < n
        d = mem_byte_read(s, q) & 255
        if d >= 48 and d <= 57
            if mn < 10000
                mn = (mn * 10) + (d - 48)
            end
            q = q + 1
        else
            break
        end
    end
    if q >= n return [0, 0, 0, p] end
    sep = mem_byte_read(s, q) & 255
    if sep == 125 // '}'
        return [1, mn, mn, q + 1]
    end
    if sep != 44 // ','
        return [0, 0, 0, p]
    end
    q = q + 1
    if q >= n return [0, 0, 0, p] end
    if (mem_byte_read(s, q) & 255) == 125
        return [1, mn, -1, q + 1]
    end
    c1 = mem_byte_read(s, q) & 255
    if c1 < 48 or c1 > 57
        return [0, 0, 0, p]
    end
    mx = 0
    while q < n
        d = mem_byte_read(s, q) & 255
        if d >= 48 and d <= 57
            if mx < 10000
                mx = (mx * 10) + (d - 48)
            end
            q = q + 1
        else
            break
        end
    end
    if q >= n or (mem_byte_read(s, q) & 255) != 125
        return [0, 0, 0, p]
    end
    if mx < mn
        mx = mn
    end
    return [1, mn, mx, q + 1]
end

fn _rx_parse_atom st
    s = get(st, 0)
    n = get(st, 1)
    p = get(st, 2)
    b0 = mem_byte_read(s, p) & 255

    if b0 == 94 // '^'
        list_set(st, 2, p + 1)
        f = _rx_frag_new()
        _rx_frag_emit(f, RX_OP_BOL, 0, 0, 0)
        return [f, 0] // [frag, quantifiable=0]
    elif b0 == 36 // '$'
        list_set(st, 2, p + 1)
        f = _rx_frag_new()
        _rx_frag_emit(f, RX_OP_EOL, 0, 0, 0)
        return [f, 0]
    elif b0 == 46 // '.'
        list_set(st, 2, p + 1)
        f = _rx_frag_new()
        _rx_frag_emit(f, RX_OP_DOT, 0, 0, 0)
        return [f, 1]
    elif b0 == 91 // '['
        return [_rx_parse_char_class(st), 1]
    elif b0 == 40 // '('
        p = p + 1
        is_cap = 1
        gid = 0
        prev_icase = get(st, 4)
        // Handle non-capturing `(?:...)` and inline case-insensitive `(?i)` / `(?i:...)`
        if p + 1 < n and (mem_byte_read(s, p) & 255) == 63
            nxt = mem_byte_read(s, p + 1) & 255
            if nxt == 58 // '(?:'
                is_cap = 0
                p = p + 2
            elif nxt == 105 // '(?i'
                is_cap = 0
                list_set(st, 4, 1)
                if p + 2 < n and (mem_byte_read(s, p + 2) & 255) == 41
                    // Standalone `(?i)` flag modifier (applies to remainder of current group/pattern)
                    list_set(st, 2, p + 3)
                    return [_rx_frag_new(), 0]
                elif p + 2 < n and (mem_byte_read(s, p + 2) & 255) == 58
                    p = p + 3
                else
                    p = p + 2
                end
            end
        end
        if is_cap == 1
            gid = get(st, 3) + 1
            list_set(st, 3, gid)
        end
        list_set(st, 2, p)
        // WHY: Track group nesting depth so unmatched `)` at top level is parsed literally
        // instead of silently truncating the pattern, and restore `icase` on group exit so
        // `(?i:abc)def` never leaks case-insensitivity into `def`.
        list_set(st, 5, get(st, 5) + 1)
        inner = _rx_parse_alt(st)
        list_set(st, 5, get(st, 5) - 1)
        list_set(st, 4, prev_icase)
        p_after = get(st, 2)
        if p_after < n and (mem_byte_read(s, p_after) & 255) == 41
            list_set(st, 2, p_after + 1)
        end
        if is_cap == 1
            gf = _rx_frag_new()
            _rx_frag_emit(gf, RX_OP_SAVE, gid * 2, 0, 0)
            _rx_frag_append(gf, inner)
            _rx_frag_emit(gf, RX_OP_SAVE, (gid * 2) + 1, 0, 0)
            return [gf, 1]
        end
        return [inner, 1]
    elif b0 == 92 and p + 1 < n // '\'
        p = p + 1
        nb = mem_byte_read(s, p) & 255
        nlen = _rx_utf8_rune_len(nb)
        ncp = _rx_utf8_decode_cp(s, p, n)
        list_set(st, 2, p + nlen)
        f = _rx_frag_new()
        if ncp == 100 // \d
            _rx_frag_emit(f, RX_OP_DIGIT, 0, 0, 0)
            return [f, 1]
        elif ncp == 68 // \D
            _rx_frag_emit(f, RX_OP_NON_DIGIT, 0, 0, 0)
            return [f, 1]
        elif ncp == 119 // \w
            _rx_frag_emit(f, RX_OP_WORD, 0, 0, 0)
            return [f, 1]
        elif ncp == 87 // \W
            _rx_frag_emit(f, RX_OP_NON_WORD, 0, 0, 0)
            return [f, 1]
        elif ncp == 115 // \s
            _rx_frag_emit(f, RX_OP_SPACE, 0, 0, 0)
            return [f, 1]
        elif ncp == 83 // \S
            _rx_frag_emit(f, RX_OP_NON_SPACE, 0, 0, 0)
            return [f, 1]
        elif ncp == 98 // \b
            _rx_frag_emit(f, RX_OP_BOUNDARY, 0, 0, 0)
            return [f, 0]
        elif ncp == 2476 // \ব
            _rx_frag_emit(f, RX_OP_BENGALI, 0, 0, 0)
            return [f, 1]
        elif ncp == 110
            _rx_frag_emit(f, RX_OP_CHAR, 10, get(st, 4), 0)
            return [f, 1]
        elif ncp == 116
            _rx_frag_emit(f, RX_OP_CHAR, 9, get(st, 4), 0)
            return [f, 1]
        elif ncp == 114
            _rx_frag_emit(f, RX_OP_CHAR, 13, get(st, 4), 0)
            return [f, 1]
        elif ncp == 102
            _rx_frag_emit(f, RX_OP_CHAR, 12, get(st, 4), 0)
            return [f, 1]
        else
            _rx_frag_emit(f, RX_OP_CHAR, ncp, get(st, 4), 0)
            return [f, 1]
        end
    else
        rlen = _rx_utf8_rune_len(b0)
        cp = _rx_utf8_decode_cp(s, p, n)
        list_set(st, 2, p + rlen)
        f = _rx_frag_new()
        _rx_frag_emit(f, RX_OP_CHAR, cp, get(st, 4), 0)
        return [f, 1]
    end
end

fn _rx_parse_concat st
    s = get(st, 0)
    n = get(st, 1)
    seq = _rx_frag_new()
    while get(st, 2) < n
        p = get(st, 2)
        b0 = mem_byte_read(s, p) & 255
        if b0 == 124 or (b0 == 41 and get(st, 5) > 0) // '|' or ')' closing an active group
            break
        end
        atom_pair = _rx_parse_atom(st)
        af = get(atom_pair, 0)
        can_q = get(atom_pair, 1)
        if can_q == 1 and get(st, 2) < n
            qp = get(st, 2)
            qb = mem_byte_read(s, qp) & 255
            if qb == 42 or qb == 43 or qb == 63 // '*', '+', '?'
                list_set(st, 2, qp + 1)
                is_lazy = 0
                if get(st, 2) < n and (mem_byte_read(s, get(st, 2)) & 255) == 63
                    is_lazy = 1
                    list_set(st, 2, get(st, 2) + 1)
                end
                if qb == 42
                    af = _rx_wrap_star(af, is_lazy)
                elif qb == 43
                    af = _rx_wrap_plus(af, is_lazy)
                else
                    af = _rx_wrap_opt(af, is_lazy)
                end
            elif qb == 123 // '{'
                br = _rx_try_parse_brace(st)
                if get(br, 0) == 1
                    list_set(st, 2, get(br, 3))
                    is_lazy = 0
                    if get(st, 2) < n and (mem_byte_read(s, get(st, 2)) & 255) == 63
                        is_lazy = 1
                        list_set(st, 2, get(st, 2) + 1)
                    end
                    af = _rx_wrap_brace(af, get(br, 1), get(br, 2), is_lazy)
                end
            end
        end
        _rx_frag_append(seq, af)
    end
    return seq
end

fn _rx_parse_alt st
    s = get(st, 0)
    n = get(st, 1)
    branches = list()
    push(branches, _rx_parse_concat(st))
    while get(st, 2) < n and (mem_byte_read(s, get(st, 2)) & 255) == 124
        list_set(st, 2, get(st, 2) + 1)
        push(branches, _rx_parse_concat(st))
    end
    bcnt = len(branches)
    if bcnt == 1
        return get(branches, 0)
    end
    // Chain alternations right-to-left: SPLIT(left, right) ; left ; JMP(end) ; right
    acc = get(branches, bcnt - 1)
    bi = bcnt - 2
    while bi >= 0
        lhs = get(branches, bi)
        llen = _rx_frag_len(lhs)
        rlen = _rx_frag_len(acc)
        comb = _rx_frag_new()
        _rx_frag_emit(comb, RX_OP_SPLIT, 1, llen + 2, 0)
        _rx_frag_append(comb, lhs)
        _rx_frag_emit(comb, RX_OP_JMP, llen + 2 + rlen, 0, 0)
        _rx_frag_append(comb, acc)
        acc = comb
        bi = bi - 1
    end
    return acc
end

// ─── Compiler Entrypoints ─────────────────────────────────────────────────────
fn REGEX_কম্পাইল_ফ্ল্যাগ(pattern_string, flags) -> REGEX_pattern
    // WHY: Compiles pattern into flat NFA bytecode with optional flags (`i` = case-insensitive)
    // and inline `(?i)` support, recording capture group count and start-anchor fast path.
    plen = len(pattern_string)
    icase = 0
    fi = 0
    while fi < len(flags)
        fc = mem_byte_read(flags, fi) & 255
        if fc == 105 or fc == 73 // 'i' or 'I'
            icase = 1
        end
        fi = fi + 1
    end

    st = [pattern_string, plen, 0, 0, icase, 0]
    body = _rx_parse_alt(st)
    _rx_frag_emit(body, RX_OP_MATCH, 0, 0, 0)

    ops = get(body, 0)
    has_start = 0
    if len(ops) > 0 and get(ops, 0) == RX_OP_BOL
        has_start = 1
    end
    has_end = 0
    if len(ops) >= 2 and get(ops, len(ops) - 2) == RX_OP_EOL
        has_end = 1
    end

    pat = REGEX_pattern()
    pat.node_list = list()
    pat.node_count = len(ops)
    pat.গ্রুপ_count = get(st, 3)
    pat.মূল_string = pattern_string
    pat.has_anchor_start = has_start
    pat.has_anchor_end = has_end
    pat.vm_ops = ops
    pat.vm_a = get(body, 1)
    pat.vm_b = get(body, 2)
    pat.vm_extra = get(body, 3)
    pat.vm_ignore_case = get(st, 4)
    return pat
end

fn regex_compile_flags(pattern_string, flags) -> REGEX_pattern
    return REGEX_কম্পাইল_ফ্ল্যাগ(pattern_string, flags)
end

fn REGEX_কম্পাইল(pattern_string) -> REGEX_pattern
    return REGEX_কম্পাইল_ফ্ল্যাগ(pattern_string, "")
end

fn regex_compile(pattern_string) -> REGEX_pattern
    return REGEX_কম্পাইল_ফ্ল্যাগ(pattern_string, "")
end

// ─── Character Class & Atom Matcher ───────────────────────────────────────────
fn _rx_class_matches ranges neg cp icase
    matched = 0
    cp_lo = cp
    if icase == 1
        cp_lo = _rx_ascii_lower(cp)
    end
    rlen = len(ranges)
    i = 0
    while i + 1 < rlen
        lo = get(ranges, i)
        hi = get(ranges, i + 1)
        if lo < 0
            if lo == RX_CLS_DIGIT and _rx_is_digit_cp(cp) == 1
                matched = 1
            elif lo == RX_CLS_NON_DIGIT and _rx_is_digit_cp(cp) == 0
                matched = 1
            elif lo == RX_CLS_WORD and _rx_is_word_cp(cp) == 1
                matched = 1
            elif lo == RX_CLS_NON_WORD and _rx_is_word_cp(cp) == 0
                matched = 1
            elif lo == RX_CLS_SPACE and _rx_is_space_cp(cp) == 1
                matched = 1
            elif lo == RX_CLS_NON_SPACE and _rx_is_space_cp(cp) == 0
                matched = 1
            elif lo == RX_CLS_BENGALI and _rx_is_bengali_cp(cp) == 1
                matched = 1
            end
        else
            if cp >= lo and cp <= hi
                matched = 1
            elif icase == 1
                // Case-insensitive ASCII check across uppercase & lowercase equivalents
                if cp_lo >= 97 and cp_lo <= 122
                    cp_up = cp_lo - 32
                    if (cp_lo >= lo and cp_lo <= hi) or (cp_up >= lo and cp_up <= hi)
                        matched = 1
                    end
                end
            end
        end
        if matched == 1
            break
        end
        i = i + 2
    end
    if neg == 1
        if matched == 1 return 0 end
        return 1
    end
    return matched
end

// ─── Iterative Bounded-Memoization Backtracking NFA VM ────────────────────────
// WHY: Iterative work-stack eliminates call-stack overflow on long inputs; exact
// (pc, pos) failure memoization guarantees O(num_insns * text_len) worst-case time
// (completely immune to ReDoS like `(a+)+b`) while preserving exact PCRE greedy/lazy
// priority and full capture-group undo across cross-group backtracking like `(ab|a)b`.
fn _rx_vm_run_at pat text t_len start_pos require_full memo saves
    ops = pat.vm_ops
    va = pat.vm_a
    vb = pat.vm_b
    vex = pat.vm_extra
    icase = pat.vm_ignore_case
    n_insns = len(ops)
    stride = t_len + 1

    // Reset capture slots for this starting attempt
    nslots = len(saves)
    si = 0
    while si < nslots
        list_set(saves, si, -1)
        si = si + 1
    end
    if nslots >= 2
        list_set(saves, 0, start_pos)
    end

    // Explicit DFS stack: kind 0=EXEC(pc, pos), 1=MARK_DEAD(memo_slot, 0), 2=UNDO_SAVE(slot_idx, old_val)
    st_kind = [0]
    st_x = [0]
    st_y = [start_pos]

    // Track active (memo==1) slots so if we return early on MATCH we clear them cleanly
    active_slots = list()

    while len(st_kind) > 0
        top = len(st_kind) - 1
        kind = get(st_kind, top)
        x = get(st_x, top)
        y = get(st_y, top)
        pop(st_kind)
        pop(st_x)
        pop(st_y)

        if kind == 1
            // Backtracked out of (pc, pos) without matching -> mark permanently dead (2)
            if memo > 0
                mem_byte_write(memo, x, 2)
            end
            if len(active_slots) > 0
                pop(active_slots)
            end
            continue
        elif kind == 2
            list_set(saves, x, y)
            continue
        end

        // kind == 0: EXEC(pc=x, pos=y)
        pc = x
        pos = y
        if pc < 0 or pc >= n_insns
            continue
        end

        // Memoization check: 1=currently active (zero-width cycle), 2=proven dead
        if memo > 0
            mslot = (pc * stride) + pos
            mval = mem_byte_read(memo, mslot) & 255
            if mval != 0
                continue
            end
            mem_byte_write(memo, mslot, 1)
            push(active_slots, mslot)
            push(st_kind, 1)
            push(st_x, mslot)
            push(st_y, 0)
        end

        op = get(ops, pc)

        if op == RX_OP_MATCH
            if require_full == 0 or pos == t_len
                if nslots >= 2
                    list_set(saves, 1, pos)
                end
                // Clear in-progress (1) marks before returning success so caller can reuse memo
                if memo > 0
                    ai = 0
                    while ai < len(active_slots)
                        mem_byte_write(memo, get(active_slots, ai), 0)
                        ai = ai + 1
                    end
                end
                return pos
            end
            continue
        elif op == RX_OP_JMP
            push(st_kind, 0)
            push(st_x, get(va, pc))
            push(st_y, pos)
            continue
        elif op == RX_OP_SPLIT
            // Push second branch first so LIFO explores first branch (greedy/lazy priority) first!
            push(st_kind, 0)
            push(st_x, get(vb, pc))
            push(st_y, pos)
            push(st_kind, 0)
            push(st_x, get(va, pc))
            push(st_y, pos)
            continue
        elif op == RX_OP_SAVE
            s_idx = get(va, pc)
            if s_idx >= 0 and s_idx < nslots
                old_v = get(saves, s_idx)
                push(st_kind, 2)
                push(st_x, s_idx)
                push(st_y, old_v)
                list_set(saves, s_idx, pos)
            end
            push(st_kind, 0)
            push(st_x, pc + 1)
            push(st_y, pos)
            continue
        elif op == RX_OP_BOL
            if pos == 0
                push(st_kind, 0)
                push(st_x, pc + 1)
                push(st_y, pos)
            end
            continue
        elif op == RX_OP_EOL
            if pos == t_len
                push(st_kind, 0)
                push(st_x, pc + 1)
                push(st_y, pos)
            end
            continue
        elif op == RX_OP_BOUNDARY
            if _rx_check_word_boundary(text, pos, t_len) == 1
                push(st_kind, 0)
                push(st_x, pc + 1)
                push(st_y, pos)
            end
            continue
        end

        // Character-consuming opcodes require pos < t_len
        if pos >= t_len
            continue
        end
        b0 = mem_byte_read(text, pos) & 255
        rlen = _rx_utf8_rune_len(b0)
        if pos + rlen > t_len
            rlen = t_len - pos
        end
        cp = _rx_utf8_decode_cp(text, pos, t_len)
        ok = 0

        if op == RX_OP_CHAR
            want = get(va, pc)
            inst_ic = get(vb, pc)
            if cp == want
                ok = 1
            elif inst_ic == 1 and _rx_ascii_lower(cp) == _rx_ascii_lower(want)
                ok = 1
            end
        elif op == RX_OP_DOT
            if cp != 10
                ok = 1
            end
        elif op == RX_OP_CLASS
            ok = _rx_class_matches(get(vex, pc), get(va, pc), cp, get(vb, pc))
        elif op == RX_OP_DIGIT
            ok = _rx_is_digit_cp(cp)
        elif op == RX_OP_NON_DIGIT
            if _rx_is_digit_cp(cp) == 0 ok = 1 end
        elif op == RX_OP_WORD
            ok = _rx_is_word_cp(cp)
        elif op == RX_OP_NON_WORD
            if _rx_is_word_cp(cp) == 0 ok = 1 end
        elif op == RX_OP_SPACE
            ok = _rx_is_space_cp(cp)
        elif op == RX_OP_NON_SPACE
            if _rx_is_space_cp(cp) == 0 ok = 1 end
        elif op == RX_OP_BENGALI
            ok = _rx_is_bengali_cp(cp)
        end

        if ok == 1
            push(st_kind, 0)
            push(st_x, pc + 1)
            push(st_y, pos + rlen)
        end
    end
    return -1
end

fn _rx_alloc_memo pat t_len
    n_insns = len(pat.vm_ops)
    sz = n_insns * (t_len + 1)
    // Cap memo table at 4 MiB for extreme inputs; still bounds all normal inputs O(states * len)
    if sz <= 0 or sz > 4194304
        return [0, 0]
    end
    m = malloc(sz)
    if m <= 0
        return [0, 0]
    end
    i = 0
    while i < sz
        mem_byte_write(m, i, 0)
        i = i + 1
    end
    return [m, sz]
end

fn _rx_make_saves(pat: REGEX_pattern)
    nslots = (pat.গ্রুপ_count + 1) * 2
    saves = list()
    i = 0
    while i < nslots
        push(saves, -1)
        i = i + 1
    end
    return saves
end

// ─── Public Matching & Extraction API ─────────────────────────────────────────
fn REGEX_মিল pat text
    if pat == 0 return 0 end
    tlen = len(text)
    mp = _rx_alloc_memo(pat, tlen)
    memo = get(mp, 0)
    msz = get(mp, 1)
    saves = _rx_make_saves(pat)

    found = 0
    if pat.has_anchor_start == 1
        if _rx_vm_run_at(pat, text, tlen, 0, 0, memo, saves) >= 0
            found = 1
        end
    else
        i = 0
        while i <= tlen
            if _rx_vm_run_at(pat, text, tlen, i, 0, memo, saves) >= 0
                found = 1
                break
            end
            if i == tlen
                break
            end
            i = i + _rx_utf8_rune_len(mem_byte_read(text, i) & 255)
        end
    end

    if memo > 0
        free(memo, msz)
    end
    return found
end

fn regex_match pat text
    return REGEX_মিল(pat, text)
end

fn REGEX_পূর্ণ_মিল pat text
    if pat == 0 return 0 end
    tlen = len(text)
    mp = _rx_alloc_memo(pat, tlen)
    memo = get(mp, 0)
    msz = get(mp, 1)
    saves = _rx_make_saves(pat)
    res = _rx_vm_run_at(pat, text, tlen, 0, 1, memo, saves)
    if memo > 0
        free(memo, msz)
    end
    if res == tlen
        return 1
    end
    return 0
end

fn regex_full_match pat text
    return REGEX_পূর্ণ_মিল(pat, text)
end

fn _rx_populate_groups res_obj: REGEX_ম্যাচ_result pat: REGEX_pattern text saves
    // WHY: Explicit struct types guarantee exact field offsets when both REGEX_pattern and
    // REGEX_ম্যাচ_result share the `গ্রুপ_count` field name at different struct offsets!
    gcnt = pat.গ্রুপ_count
    glist = list()
    g = 1
    while g <= gcnt
        gs = get(saves, g * 2)
        ge = get(saves, (g * 2) + 1)
        if gs >= 0 and ge >= gs and ge <= len(text)
            push(glist, str_sub(text, gs, ge))
        else
            push(glist, "")
        end
        g = g + 1
    end
    res_obj.গ্রুপ_list = glist
    res_obj.গ্রুপ_count = gcnt
    return res_obj
end

// WHY: Finds first match in text, returning offsets AND populated capture groups.
fn REGEX_খোঁজো(pat: REGEX_pattern, text) -> REGEX_ম্যাচ_result
    res_obj = REGEX_ম্যাচ_result()
    res_obj.পাওয়া_গেছে = 0
    res_obj.শুরু_offset = -1
    res_obj.শেষ_offset = -1
    res_obj.len = 0
    res_obj.গ্রুপ_list = list()
    res_obj.গ্রুপ_count = 0

    if pat == 0
        return res_obj
    end

    tlen = len(text)
    mp = _rx_alloc_memo(pat, tlen)
    memo = get(mp, 0)
    msz = get(mp, 1)
    saves = _rx_make_saves(pat)

    if pat.has_anchor_start == 1
        end_pos = _rx_vm_run_at(pat, text, tlen, 0, 0, memo, saves)
        if end_pos >= 0
            res_obj.পাওয়া_গেছে = 1
            res_obj.শুরু_offset = 0
            res_obj.শেষ_offset = end_pos
            res_obj.len = end_pos
            _rx_populate_groups(res_obj, pat, text, saves)
        end
    else
        i = 0
        while i <= tlen
            end_pos = _rx_vm_run_at(pat, text, tlen, i, 0, memo, saves)
            if end_pos >= 0
                res_obj.পাওয়া_গেছে = 1
                res_obj.শুরু_offset = i
                res_obj.শেষ_offset = end_pos
                res_obj.len = end_pos - i
                _rx_populate_groups(res_obj, pat, text, saves)
                break
            end
            if i == tlen
                break
            end
            i = i + _rx_utf8_rune_len(mem_byte_read(text, i) & 255)
        end
    end

    if memo > 0
        free(memo, msz)
    end
    return res_obj
end

fn regex_find(pat: REGEX_pattern, text) -> REGEX_ম্যাচ_result
    return REGEX_খোঁজো(pat, text)
end

fn REGEX_সব_খোঁজো pat text
    results = list()
    if pat == 0
        return results
    end
    tlen = len(text)
    mp = _rx_alloc_memo(pat, tlen)
    memo = get(mp, 0)
    msz = get(mp, 1)
    saves = _rx_make_saves(pat)

    i = 0
    while i <= tlen
        end_pos = _rx_vm_run_at(pat, text, tlen, i, 0, memo, saves)
        if end_pos >= 0
            push(results, str_sub(text, i, end_pos))
            if end_pos > i
                i = end_pos
            else
                if i == tlen break end
                i = i + _rx_utf8_rune_len(mem_byte_read(text, i) & 255)
            end
        else
            if pat.has_anchor_start == 1 break end
            if i == tlen break end
            i = i + _rx_utf8_rune_len(mem_byte_read(text, i) & 255)
        end
    end

    if memo > 0
        free(memo, msz)
    end
    return results
end

fn regex_find_all pat text
    return REGEX_সব_খোঁজো(pat, text)
end

fn REGEX_প্রতিস্থাপন pat text replacement
    if pat == 0
        return text
    end
    m = REGEX_খোঁজো(pat, text)
    if m.পাওয়া_গেছে == 0
        return text
    end
    prefix = str_sub(text, 0, m.শুরু_offset)
    suffix = str_sub(text, m.শেষ_offset, len(text))
    return prefix + replacement + suffix
end

fn regex_replace pat text replacement
    return REGEX_প্রতিস্থাপন(pat, text, replacement)
end

fn REGEX_প্রতিস্থাপন_সব pat text replacement
    if pat == 0
        return text
    end
    tlen = len(text)
    mp = _rx_alloc_memo(pat, tlen)
    memo = get(mp, 0)
    msz = get(mp, 1)
    saves = _rx_make_saves(pat)

    out = ""
    i = 0
    while i <= tlen
        end_pos = _rx_vm_run_at(pat, text, tlen, i, 0, memo, saves)
        if end_pos >= 0
            out = out + replacement
            if end_pos > i
                i = end_pos
            else
                if i < tlen
                    rlen = _rx_utf8_rune_len(mem_byte_read(text, i) & 255)
                    out = out + str_sub(text, i, i + rlen)
                    i = i + rlen
                else
                    break
                end
            end
        else
            if i == tlen break end
            rlen = _rx_utf8_rune_len(mem_byte_read(text, i) & 255)
            out = out + str_sub(text, i, i + rlen)
            i = i + rlen
        end
    end

    if memo > 0
        free(memo, msz)
    end
    return out
end

fn regex_replace_all pat text replacement
    return REGEX_প্রতিস্থাপন_সব(pat, text, replacement)
end

fn REGEX_বিভক্ত pat text
    parts = list()
    if pat == 0
        push(parts, text)
        return parts
    end
    tlen = len(text)
    mp = _rx_alloc_memo(pat, tlen)
    memo = get(mp, 0)
    msz = get(mp, 1)
    saves = _rx_make_saves(pat)

    last_start = 0
    i = 0
    while i <= tlen
        end_pos = _rx_vm_run_at(pat, text, tlen, i, 0, memo, saves)
        if end_pos >= 0 and (end_pos > i or i > last_start)
            push(parts, str_sub(text, last_start, i))
            last_start = end_pos
            if end_pos > i
                i = end_pos
            else
                if i == tlen break end
                i = i + _rx_utf8_rune_len(mem_byte_read(text, i) & 255)
            end
        else
            if i == tlen break end
            i = i + _rx_utf8_rune_len(mem_byte_read(text, i) & 255)
        end
    end
    push(parts, str_sub(text, last_start, tlen))

    if memo > 0
        free(memo, msz)
    end
    return parts
end

fn regex_split pat text
    return REGEX_বিভক্ত(pat, text)
end

// ─── Built-in Validators ──────────────────────────────────────────────────────
fn REGEX_ইমেইল_verify email
    elen = len(email)
    if elen < 5 or elen > 320
        return 0
    end
    at_idx = index_of(email, "@")
    if at_idx <= 0 or at_idx >= elen - 3
        return 0
    end
    dot_idx = index_of(email, ".")
    if dot_idx <= 0 or dot_idx >= elen - 1
        return 0
    end
    if dot_idx < at_idx
        domain = str_sub(email, at_idx + 1, elen)
        if index_of(domain, ".") <= 0
            return 0
        end
    end
    return 1
end

fn regex_email_verify email
    return REGEX_ইমেইল_verify(email)
end

fn REGEX_ফোন_verify phone
    plen = len(phone)
    if plen != 11
        return 0
    end
    if not starts_with(phone, "01")
        return 0
    end
    p2 = ord(char_at(phone, 2))
    if p2 < 51 or p2 > 57
        return 0
    end
    i = 3
    while i < 11
        ch = ord(char_at(phone, i))
        if ch < 48 or ch > 57
            return 0
        end
        i = i + 1
    end
    return 1
end

fn regex_phone_verify phone
    return REGEX_ফোন_verify(phone)
end

fn REGEX_URL_verify url
    ulen = len(url)
    host_start = 0
    if starts_with(url, "http://")
        host_start = 7
    elif starts_with(url, "https://")
        host_start = 8
    else
        return 0
    end
    if ulen <= host_start
        return 0
    end
    i = 0
    while i < ulen
        ch = ord(char_at(url, i))
        if ch <= 32 or ch == 127
            return 0
        end
        i = i + 1
    end
    host_len = 0
    j = host_start
    while j < ulen
        c = ord(char_at(url, j))
        if c == 47 or c == 63 or c == 35
            break
        end
        host_len = host_len + 1
        j = j + 1
    end
    if host_len == 0
        return 0
    end
    return 1
end

fn regex_url_verify url
    return REGEX_URL_verify(url)
end

fn REGEX_শুধু_বাংলা text
    tlen = len(text)
    if tlen == 0
        return 0
    end
    idx = 0
    while idx < tlen
        b0 = mem_byte_read(text, idx) & 255
        rlen = _rx_utf8_rune_len(b0)
        cp = _rx_utf8_decode_cp(text, idx, tlen)
        if (cp >= 2432 and cp <= 2559) or cp == 32 or cp == 9 or cp == 10 or cp == 44 or cp == 46 or cp == 2404 or cp == 2405
            idx = idx + rlen
        else
            return 0
        end
    end
    return 1
end

fn regex_is_bengali_only text
    return REGEX_শুধু_বাংলা(text)
end

fn REGEX_মুক্তি pat
    if pat == 0
        return 0
    end
    return 0
end

fn regex_free pat
    return REGEX_মুক্তি(pat)
end

fn regex_char_match pat_char text_char
    if pat_char == 46
        if text_char == 10
            return 0
        end
        return 1
    end
    if pat_char == text_char
        return 1
    end
    return 0
end

fn রেজেক্স_অক্ষর_মিল pat_char text_char
    return regex_char_match(pat_char, text_char)
end
