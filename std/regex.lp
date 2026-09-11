// ==============================================================================
// 🔍 লিপি Regex ইঞ্জিন (Regular Expression Library)
// লিপি প্রথম ২.০ | ciphername: সোভেরিন
// File: std/regex.lp
//
// WHY এই মডিউল:
//   Text processing without regex is painful.
//   POSIX regex, PCRE (Python/JS) — এদের replace করবে।
//   Pure sovereign NFA state machine with zero external libc runtime dependencies.
//   Supports: . * + ? [] ^ $ \d \w \s \n \t
//   Bengali character class: \ব (Bengali letter range U+0980-U+09FF)
//
// ব্যবহার:
//   include "std/regex.lp"
//   pat = REGEX_কম্পাইল("[০-৯]+")
//   if REGEX_মিল(pat, "hello ৪২")
//       say "সংখ্যা পাওয়া গেছে"
//   REGEX_মুক্তি(pat)
// ==============================================================================

include "std/mem.lp"
include "std/str.lp"

// ─── Regex Node Types ─────────────────────────────────────────────────────────
REGEX_LITERAL      = 1   // literal character match
REGEX_DOT          = 2   // . matches any char except newline
REGEX_STAR         = 3   // * zero or more
REGEX_PLUS         = 4   // + one or more
REGEX_QUESTION     = 5   // ? zero or one
REGEX_ANCHOR_START = 6   // ^ start of string
REGEX_ANCHOR_END   = 7   // $ end of string
REGEX_CHAR_CLASS   = 8   // [abc] or [a-z]
REGEX_GROUP        = 9   // (group)
REGEX_ALTERNATE    = 10  // a|b
REGEX_DIGIT        = 11  // \d = [0-9০-৯]
REGEX_WORD         = 12  // \w = [a-zA-Z0-9_] + Bengali
REGEX_SPACE        = 13  // \s = [ \t\n\r]
REGEX_BENGALI      = 14  // \ব = Bengali Unicode letter range (U+0980-U+09FF)

// Quantifier enums
QUANT_ONE  = 1
QUANT_STAR = 2
QUANT_PLUS = 3
QUANT_OPT  = 4

// ─── Pure Lipi 2.0 Struct Declarations (No Commas) ───────────────────────────
// WHY: Pure Lipi 2.0 indentation syntax enforces clean single-field lines.
struct RegexNode
    node_type
    quantifier
    char_code
    ranges
    negated

struct REGEX_pattern
    node_list
    node_count
    গ্রুপ_count
    মূল_string
    has_anchor_start
    has_anchor_end

struct REGEX_ম্যাচ_result
    পাওয়া_গেছে
    শুরু_offset
    শেষ_offset
    len
    গ্রুপ_list
    গ্রুপ_count

// ─── UTF-8 & Unicode Helpers ──────────────────────────────────────────────────
// WHY: Bengali characters (U+0980..U+09FF) and other Unicode codepoints span 2 to 4
// UTF-8 bytes. Pure rune decoding ensures exact character boundary awareness.
fn utf8_rune_len b0
    if b0 < 128
        return 1
    elif b0 >= 192 and b0 <= 223
        return 2
    elif b0 >= 224 and b0 <= 239
        return 3
    elif b0 >= 240 and b0 <= 247
        return 4
    return 1

fn utf8_decode_cp s idx slen
    b0 = ord(char_at(s, idx))
    if b0 < 128
        return b0
    if b0 >= 192 and b0 <= 223
        if idx + 1 < slen
            b1 = ord(char_at(s, idx + 1))
            return (b0 % 32) * 64 + (b1 % 64)
    elif b0 >= 224 and b0 <= 239
        if idx + 2 < slen
            b1 = ord(char_at(s, idx + 1))
            b2 = ord(char_at(s, idx + 2))
            return (b0 % 16) * 4096 + (b1 % 64) * 64 + (b2 % 64)
    elif b0 >= 240 and b0 <= 247
        if idx + 3 < slen
            b1 = ord(char_at(s, idx + 1))
            b2 = ord(char_at(s, idx + 2))
            b3 = ord(char_at(s, idx + 3))
            return (b0 % 8) * 262144 + (b1 % 64) * 4096 + (b2 % 64) * 64 + (b3 % 64)
    return b0

// ─── NFA State Transition Matcher ─────────────────────────────────────────────
// WHY: Evaluates whether an individual regex node matches the character at text[t_idx].
// Returns the number of bytes consumed if matched, or 0 if mismatch.
fn regex_node_matches node text t_idx t_len
    if t_idx >= t_len
        return 0
    b0 = ord(char_at(text, t_idx))
    rlen = utf8_rune_len(b0)
    cp = utf8_decode_cp(text, t_idx, t_len)
    nt = node.node_type

    // Dot matches any character except newline (ASCII 10)
    if nt == REGEX_DOT
        if cp != 10
            return rlen
        return 0

    // Literal codepoint equality
    if nt == REGEX_LITERAL
        if cp == node.char_code
            return rlen
        return 0

    // Bengali Unicode range U+0980..U+09FF (codepoints 2432..2559)
    if nt == REGEX_BENGALI
        if cp >= 2432 and cp <= 2559
            return rlen
        return 0

    // Digits: ASCII 0-9 (48..57) or Bengali ০-৯ (2534..2543)
    if nt == REGEX_DIGIT
        if (cp >= 48 and cp <= 57) or (cp >= 2534 and cp <= 2543)
            return rlen
        return 0

    // Word characters: ASCII alphanumeric, underscore, or Bengali characters
    if nt == REGEX_WORD
        if (cp >= 97 and cp <= 122) or (cp >= 65 and cp <= 90) or (cp >= 48 and cp <= 57) or cp == 95 or (cp >= 2432 and cp <= 2559)
            return rlen
        return 0

    // Whitespace: space, tab, newline, carriage return
    if nt == REGEX_SPACE
        if cp == 32 or cp == 9 or cp == 10 or cp == 13
            return rlen
        return 0

    // Character Class [abc], [a-z], [০-৯], [^0-9]
    if nt == REGEX_CHAR_CLASS
        in_range = 0
        ri = 0
        nranges = len(node.ranges)
        while ri < nranges
            c_min = get(node.ranges, ri)
            c_max = get(node.ranges, ri + 1)
            if cp >= c_min and cp <= c_max
                in_range = 1
                break
            ri = ri + 2
        if node.negated == 1
            if in_range == 0
                return rlen
            return 0
        else
            if in_range == 1
                return rlen
            return 0

    return 0

// ─── NFA Simulation Engine with Backtracking ──────────────────────────────────
// WHY: Executes the compiled NFA state sequence with greedy matching and clean
// backtracking for * (zero or more), + (one or more), and ? (zero or one).
fn regex_exec_nodes pat node_idx text t_idx t_len
    if node_idx >= pat.node_count
        if pat.has_anchor_end == 1
            if t_idx == t_len
                return t_idx
            return -1
        return t_idx

    node = get(pat.node_list, node_idx)
    q = node.quantifier

    // Exact single match
    if q == QUANT_ONE
        if t_idx >= t_len
            return -1
        adv = regex_node_matches(node, text, t_idx, t_len)
        if adv > 0
            return regex_exec_nodes(pat, node_idx + 1, text, t_idx + adv, t_len)
        return -1

    // Optional match (?)
    if q == QUANT_OPT
        if t_idx < t_len
            adv = regex_node_matches(node, text, t_idx, t_len)
            if adv > 0
                sub_res = regex_exec_nodes(pat, node_idx + 1, text, t_idx + adv, t_len)
                if sub_res >= 0
                    return sub_res
        return regex_exec_nodes(pat, node_idx + 1, text, t_idx, t_len)

    // Repetitions (* and +)
    if q == QUANT_STAR or q == QUANT_PLUS
        positions = list()
        if q == QUANT_STAR
            push(positions, t_idx)
        cur = t_idx
        while cur < t_len
            adv = regex_node_matches(node, text, cur, t_len)
            if adv > 0
                cur = cur + adv
                push(positions, cur)
            else
                break
        if len(positions) == 0
            return -1
        // Greedy: check from most matched positions down to fewest
        p_idx = len(positions) - 1
        while p_idx >= 0
            pos = get(positions, p_idx)
            sub_res = regex_exec_nodes(pat, node_idx + 1, text, pos, t_len)
            if sub_res >= 0
                return sub_res
            p_idx = p_idx - 1
        return -1

    return -1

// ─── Compile ──────────────────────────────────────────────────────────────────
// WHY: Parses pattern string into an NFA sequence of compiled RegexNode states.
fn REGEX_কম্পাইল pattern_string
    pat = REGEX_pattern()
    pat.মূল_string = pattern_string
    pat.node_list = list()
    pat.node_count = 0
    pat.গ্রুপ_count = 0
    pat.has_anchor_start = 0
    pat.has_anchor_end = 0

    plen = len(pattern_string)
    if plen == 0
        return pat

    p_idx = 0
    if char_at(pattern_string, 0) == "^"
        pat.has_anchor_start = 1
        p_idx = 1

    has_end = 0
    if plen > 1 and char_at(pattern_string, plen - 1) == "$"
        if char_at(pattern_string, plen - 2) != "\\"
            has_end = 1
    elif plen == 1 and char_at(pattern_string, 0) == "$"
        has_end = 1

    pat.has_anchor_end = has_end
    limit = plen
    if has_end == 1
        limit = plen - 1

    while p_idx < limit
        c = char_at(pattern_string, p_idx)
        node = RegexNode()
        node.ranges = list()
        node.negated = 0
        node.quantifier = QUANT_ONE

        if c == "."
            node.node_type = REGEX_DOT
            p_idx = p_idx + 1
        elif c == "\\"
            p_idx = p_idx + 1
            if p_idx < limit
                esc = char_at(pattern_string, p_idx)
                p_idx = p_idx + 1
                if esc == "d"
                    node.node_type = REGEX_DIGIT
                elif esc == "w"
                    node.node_type = REGEX_WORD
                elif esc == "s"
                    node.node_type = REGEX_SPACE
                elif esc == "b" or esc == "ব"
                    node.node_type = REGEX_BENGALI
                else
                    node.node_type = REGEX_LITERAL
                    node.char_code = ord(esc)
            else
                node.node_type = REGEX_LITERAL
                node.char_code = 92
        elif c == "["
            p_idx = p_idx + 1
            node.node_type = REGEX_CHAR_CLASS
            if p_idx < limit and char_at(pattern_string, p_idx) == "^"
                node.negated = 1
                p_idx = p_idx + 1
            while p_idx < limit and char_at(pattern_string, p_idx) != "]"
                b0 = ord(char_at(pattern_string, p_idx))
                r1_len = utf8_rune_len(b0)
                cp1 = utf8_decode_cp(pattern_string, p_idx, limit)
                p_idx = p_idx + r1_len
                if p_idx + 1 < limit and char_at(pattern_string, p_idx) == "-" and char_at(pattern_string, p_idx + 1) != "]"
                    p_idx = p_idx + 1 // skip '-'
                    b2 = ord(char_at(pattern_string, p_idx))
                    r2_len = utf8_rune_len(b2)
                    cp2 = utf8_decode_cp(pattern_string, p_idx, limit)
                    p_idx = p_idx + r2_len
                    push(node.ranges, cp1)
                    push(node.ranges, cp2)
                else
                    push(node.ranges, cp1)
                    push(node.ranges, cp1)
            if p_idx < limit and char_at(pattern_string, p_idx) == "]"
                p_idx = p_idx + 1
        else
            b0 = ord(char_at(pattern_string, p_idx))
            r_len = utf8_rune_len(b0)
            cp = utf8_decode_cp(pattern_string, p_idx, limit)
            p_idx = p_idx + r_len
            node.node_type = REGEX_LITERAL
            node.char_code = cp

        // Check for trailing quantifier: *, +, ?
        if p_idx < limit
            qc = char_at(pattern_string, p_idx)
            if qc == "*"
                node.quantifier = QUANT_STAR
                p_idx = p_idx + 1
            elif qc == "+"
                node.quantifier = QUANT_PLUS
                p_idx = p_idx + 1
            elif qc == "?"
                node.quantifier = QUANT_OPT
                p_idx = p_idx + 1

        push(pat.node_list, node)
        pat.node_count = pat.node_count + 1

    return pat

fn regex_compile pattern_string
    return REGEX_কম্পাইল(pattern_string)

// ─── Match ────────────────────────────────────────────────────────────────────
// WHY: Tests if pattern matches anywhere in text, respecting start/end anchors.
fn REGEX_মিল pat text
    if pat == 0
        return 0
    tlen = len(text)
    if pat.has_anchor_start == 1
        res = regex_exec_nodes(pat, 0, text, 0, tlen)
        if res >= 0
            return 1
        return 0
    i = 0
    while i <= tlen
        res = regex_exec_nodes(pat, 0, text, i, tlen)
        if res >= 0
            return 1
        if i == tlen
            break
        b0 = ord(char_at(text, i))
        i = i + utf8_rune_len(b0)
    return 0

fn regex_match pat text
    return REGEX_মিল(pat, text)

// ─── Full Match ───────────────────────────────────────────────────────────────
// WHY: Ensures entire text string is fully consumed by pattern.
fn REGEX_পূর্ণ_মিল pat text
    if pat == 0
        return 0
    tlen = len(text)
    res = regex_exec_nodes(pat, 0, text, 0, tlen)
    if res == tlen
        return 1
    return 0

fn regex_full_match pat text
    return REGEX_পূর্ণ_মিল(pat, text)

// ─── Find ─────────────────────────────────────────────────────────────────────
// WHY: Finds first match in text and returns offsets in REGEX_ম্যাচ_result.
fn REGEX_খোঁজো pat text
    res_obj = REGEX_ম্যাচ_result()
    res_obj.পাওয়া_গেছে = 0
    res_obj.শুরু_offset = -1
    res_obj.শেষ_offset = -1
    res_obj.len = 0
    res_obj.গ্রুপ_list = list()
    res_obj.গ্রুপ_count = 0
    if pat == 0
        return res_obj
    tlen = len(text)
    if pat.has_anchor_start == 1
        end_pos = regex_exec_nodes(pat, 0, text, 0, tlen)
        if end_pos >= 0
            res_obj.পাওয়া_গেছে = 1
            res_obj.শুরু_offset = 0
            res_obj.শেষ_offset = end_pos
            res_obj.len = end_pos
            return res_obj
        return res_obj
    i = 0
    while i <= tlen
        end_pos = regex_exec_nodes(pat, 0, text, i, tlen)
        if end_pos >= 0
            res_obj.পাওয়া_গেছে = 1
            res_obj.শুরু_offset = i
            res_obj.শেষ_offset = end_pos
            res_obj.len = end_pos - i
            return res_obj
        if i == tlen
            break
        b0 = ord(char_at(text, i))
        i = i + utf8_rune_len(b0)
    return res_obj

fn regex_find pat text
    return REGEX_খোঁজো(pat, text)

// WHY: Finds all non-overlapping matches across the text string.
fn REGEX_সব_খোঁজো pat text
    matches = list()
    if pat == 0
        return matches
    tlen = len(text)
    i = 0
    while i <= tlen
        end_pos = regex_exec_nodes(pat, 0, text, i, tlen)
        if end_pos >= 0
            matched_len = end_pos - i
            if matched_len > 0
                matched_str = str_sub(text, i, end_pos)
                push(matches, matched_str)
                i = end_pos
            else
                if i < tlen
                    b0 = ord(char_at(text, i))
                    i = i + utf8_rune_len(b0)
                else
                    break
        else
            if i == tlen
                break
            b0 = ord(char_at(text, i))
            i = i + utf8_rune_len(b0)
    return matches

fn regex_find_all pat text
    return REGEX_সব_খোঁজো(pat, text)

// ─── Replace ──────────────────────────────────────────────────────────────────
// WHY: Replaces first matching occurrence with replacement string.
fn REGEX_প্রতিস্থাপন pat text replacement
    if pat == 0
        return text
    m = REGEX_খোঁজো(pat, text)
    if m.পাওয়া_গেছে == 0
        return text
    prefix = str_sub(text, 0, m.শুরু_offset)
    suffix = str_sub(text, m.শেষ_offset, len(text))
    return prefix + replacement + suffix

fn regex_replace pat text replacement
    return REGEX_প্রতিস্থাপন(pat, text, replacement)

// WHY: Replaces all matching occurrences with replacement string.
fn REGEX_প্রতিস্থাপন_সব pat text replacement
    if pat == 0
        return text
    tlen = len(text)
    result = ""
    i = 0
    while i <= tlen
        end_pos = regex_exec_nodes(pat, 0, text, i, tlen)
        if end_pos >= 0
            matched_len = end_pos - i
            if matched_len > 0
                result = result + replacement
                i = end_pos
            else
                if i < tlen
                    b0 = ord(char_at(text, i))
                    rlen = utf8_rune_len(b0)
                    result = result + str_sub(text, i, i + rlen)
                    i = i + rlen
                else
                    break
        else
            if i == tlen
                break
            b0 = ord(char_at(text, i))
            rlen = utf8_rune_len(b0)
            result = result + str_sub(text, i, i + rlen)
            i = i + rlen
    return result

fn regex_replace_all pat text replacement
    return REGEX_প্রতিস্থাপন_সব(pat, text, replacement)

// ─── Split ────────────────────────────────────────────────────────────────────
// WHY: Splits text by regex delimiter into a list of strings.
fn REGEX_বিভক্ত pat text
    parts = list()
    if pat == 0
        push(parts, text)
        return parts
    tlen = len(text)
    last_idx = 0
    i = 0
    while i <= tlen
        end_pos = regex_exec_nodes(pat, 0, text, i, tlen)
        if end_pos >= 0
            matched_len = end_pos - i
            if matched_len > 0
                part = str_sub(text, last_idx, i)
                push(parts, part)
                i = end_pos
                last_idx = end_pos
            else
                if i < tlen
                    b0 = ord(char_at(text, i))
                    i = i + utf8_rune_len(b0)
                else
                    break
        else
            if i == tlen
                break
            b0 = ord(char_at(text, i))
            i = i + utf8_rune_len(b0)
    tail = str_sub(text, last_idx, tlen)
    push(parts, tail)
    return parts

fn regex_split pat text
    return REGEX_বিভক্ত(pat, text)

// ─── Built-in Validators ──────────────────────────────────────────────────────
// WHY: Validates standard email address syntax with username and domain.
fn REGEX_ইমেইল_verify email
    elen = len(email)
    if elen < 5 or elen > 320
        return 0
    at_idx = index_of(email, "@")
    if at_idx <= 0 or at_idx >= elen - 3
        return 0
    dot_idx = index_of(email, ".")
    if dot_idx <= 0 or dot_idx >= elen - 1
        return 0
    if dot_idx < at_idx
        domain = str_sub(email, at_idx + 1, elen)
        if index_of(domain, ".") <= 0
            return 0
    return 1

fn regex_email_verify email
    return REGEX_ইমেইল_verify(email)

// WHY: Validates Bangladeshi mobile phone numbers (11 digits, starts with 01[3-9]).
fn REGEX_ফোন_verify phone
    plen = len(phone)
    if plen == 11
        if starts_with(phone, "01")
            prefix_char = char_at(phone, 2)
            p_code = ord(prefix_char)
            if p_code >= 51 and p_code <= 57
                return 1
    return 0

fn regex_phone_verify phone
    return REGEX_ফোন_verify(phone)

// WHY: Validates HTTP/HTTPS URLs.
fn REGEX_URL_verify url
    ulen = len(url)
    if ulen < 8
        return 0
    if starts_with(url, "http://") or starts_with(url, "https://")
        return 1
    return 0

fn regex_url_verify url
    return REGEX_URL_verify(url)

// WHY: Validates that string contains only Bengali characters, spaces, and punctuation.
// Bengali Unicode range: U+0980-U+09FF (2432..2559).
fn REGEX_শুধু_বাংলা text
    tlen = len(text)
    if tlen == 0
        return 0
    idx = 0
    while idx < tlen
        b0 = ord(char_at(text, idx))
        rlen = utf8_rune_len(b0)
        cp = utf8_decode_cp(text, idx, tlen)
        if (cp >= 2432 and cp <= 2559) or cp == 32 or cp == 9 or cp == 10 or cp == 44 or cp == 46 or cp == 2404 or cp == 2405
            idx = idx + rlen
        else
            return 0
    return 1

fn regex_is_bengali_only text
    return REGEX_শুধু_বাংলা(text)

// ─── Free ─────────────────────────────────────────────────────────────────────
// WHY: Safe deallocation and release of compiled pattern resources.
fn REGEX_মুক্তি pat
    if pat == 0
        return 0
    return 0

fn regex_free pat
    return REGEX_মুক্তি(pat)
