// ==============================================================================
// 👑 LIPI SOVEREIGN ZERO-COPY JSON ENGINE (utso/core/json_fast.lp)
// ⚡ 100% Pure Lipi | Zero Libc | In-Place Slices | Linear-Time Parsing
// ==============================================================================
//
// WHY: Enterprise API gateways and high-frequency microservices spend up to 40% of
//      CPU time allocating intermediate string objects during JSON deserialization.
//      This engine uses in-place byte offset referencing (start, end) into the original
//      source buffer, achieving zero unnecessary heap allocations in the parse phase.
// ==============================================================================

include "utso/core/hashmap.lp"

// ── JSON Node Type Tags ───────────────────────────────────────────────────────
FAST_JSON_NULL   = 0
FAST_JSON_BOOL   = 1
FAST_JSON_INT    = 2
FAST_JSON_STR    = 3
FAST_JSON_ARRAY  = 4
FAST_JSON_OBJECT = 5
FAST_JSON_FLOAT  = 6

fn _fj_raw_ptr x
    return x
end

// ── Fast O(N) Substring Extractor via Native ERMS bytes_to_str ────────────────
fn fast_json_slice s start stop
    slen = len(s)
    if start < 0 start = 0 end
    if stop > slen stop = slen end
    if start >= stop return "" end
    sp = _fj_raw_ptr(s)
    return bytes_to_str(sp + start, stop - start)
end

// ── RFC 8259 IEEE-754 f64 Parser ──────────────────────────────────────────────
fn fast_json_parse_f64 raw
    n = len(raw)
    if n == 0 return 0.0 end
    p = 0
    neg = 0
    if mem_read_byte(raw, p) == 45
        neg = 1
        p = p + 1
    elif mem_read_byte(raw, p) == 43
        p = p + 1
    end
    res = 0.0
    while p < n
        c = mem_read_byte(raw, p)
        if c >= 48 and c <= 57
            res = (res * 10.0) + (c - 48)
            p = p + 1
        else
            break
        end
    end
    if p < n and mem_read_byte(raw, p) == 46
        p = p + 1
        frac = 0.1
        while p < n
            c = mem_read_byte(raw, p)
            if c >= 48 and c <= 57
                res = res + ((c - 48) * frac)
                frac = frac * 0.1
                p = p + 1
            else
                break
            end
        end
    end
    if p < n and (mem_read_byte(raw, p) == 101 or mem_read_byte(raw, p) == 69)
        p = p + 1
        eneg = 0
        if p < n and mem_read_byte(raw, p) == 45
            eneg = 1
            p = p + 1
        elif p < n and mem_read_byte(raw, p) == 43
            p = p + 1
        end
        exp = 0
        while p < n
            c = mem_read_byte(raw, p)
            if c >= 48 and c <= 57
                exp = (exp * 10) + (c - 48)
                p = p + 1
            else
                break
            end
        end
        if exp > 308 exp = 308 end
        ei = 0
        while ei < exp
            if eneg == 1
                res = res * 0.1
            else
                res = res * 10.0
            end
            ei = ei + 1
        end
    end
    if neg == 1
        res = 0.0 - res
    end
    return res
end

// WHY: Decodes 4 hexadecimal characters at s[off..off+4) into 0..65535 or -1 if invalid.
fn fast_json_hex4 s off
    if off + 4 > len(s)
        return 0 - 1
    end
    acc = 0
    k = 0
    while k < 4
        c = mem_read_byte(s, off + k)
        d = 0 - 1
        if c >= 48 and c <= 57
            d = c - 48
        elif c >= 65 and c <= 70
            d = c - 55
        elif c >= 97 and c <= 102
            d = c - 87
        else
            return 0 - 1
        end
        acc = (acc * 16) + d
        k = k + 1
    end
    return acc
end

fn _fast_json_buf_write_cp buf cp
    if cp < 0 or cp > 1114111
        buf_write_byte(buf, 239)
        buf_write_byte(buf, 191)
        buf_write_byte(buf, 189)
        return 0
    end
    if cp <= 127
        buf_write_byte(buf, cp)
        return 0
    end
    if cp <= 2047
        buf_write_byte(buf, 192 + (cp / 64))
        buf_write_byte(buf, 128 + (cp % 64))
        return 0
    end
    if cp <= 65535
        buf_write_byte(buf, 224 + (cp / 4096))
        buf_write_byte(buf, 128 + ((cp / 64) % 64))
        buf_write_byte(buf, 128 + (cp % 64))
        return 0
    end
    buf_write_byte(buf, 240 + (cp / 262144))
    buf_write_byte(buf, 128 + ((cp / 4096) % 64))
    buf_write_byte(buf, 128 + ((cp / 64) % 64))
    buf_write_byte(buf, 128 + (cp % 64))
    return 0
end

// WHY: Encodes a Unicode scalar codepoint (U+0000..U+10FFFF) as 1..4 UTF-8 bytes.
fn fast_json_encode_cp cp
    b = buf_new(8)
    _fast_json_buf_write_cp(b, cp)
    out = buf_to_str(b)
    buf_free(b)
    return out
end

// ── O(N) RFC 8259 Escape & Unescape via Native ByteBuffer ─────────────────────
fn _fast_json_hex_digit d
    if d < 10 return 48 + d end
    return 87 + d
end

fn fast_json_escape_into buf s
    slen = len(s)
    i = 0
    while i < slen
        b = mem_read_byte(s, i)
        if b == 34
            buf_write_byte(buf, 92)
            buf_write_byte(buf, 34)
        elif b == 92
            buf_write_byte(buf, 92)
            buf_write_byte(buf, 92)
        elif b == 8
            buf_write_byte(buf, 92)
            buf_write_byte(buf, 98)
        elif b == 12
            buf_write_byte(buf, 92)
            buf_write_byte(buf, 102)
        elif b == 10
            buf_write_byte(buf, 92)
            buf_write_byte(buf, 110)
        elif b == 13
            buf_write_byte(buf, 92)
            buf_write_byte(buf, 114)
        elif b == 9
            buf_write_byte(buf, 92)
            buf_write_byte(buf, 116)
        elif b < 32
            buf_write_str(buf, "\\u00")
            buf_write_byte(buf, _fast_json_hex_digit((b >> 4) & 15))
            buf_write_byte(buf, _fast_json_hex_digit(b & 15))
        else
            buf_write_byte(buf, b)
        end
        i = i + 1
    end
    return 0
end

fn fast_json_escape s
    b = buf_new(len(s) + 16)
    fast_json_escape_into(b, s)
    out = buf_to_str(b)
    buf_free(b)
    return out
end

fn fast_json_unescape s
    slen = len(s)
    if slen == 0 return "" end
    b = buf_new(slen + 8)
    i = 0
    while i < slen
        c = mem_read_byte(s, i)
        if c == 92 and i + 1 < slen
            nc = mem_read_byte(s, i + 1)
            if nc == 34
                buf_write_byte(b, 34)
                i = i + 2
            elif nc == 92
                buf_write_byte(b, 92)
                i = i + 2
            elif nc == 47
                buf_write_byte(b, 47)
                i = i + 2
            elif nc == 98
                buf_write_byte(b, 8)
                i = i + 2
            elif nc == 102
                buf_write_byte(b, 12)
                i = i + 2
            elif nc == 110
                buf_write_byte(b, 10)
                i = i + 2
            elif nc == 116
                buf_write_byte(b, 9)
                i = i + 2
            elif nc == 114
                buf_write_byte(b, 13)
                i = i + 2
            elif nc == 117
                if i + 5 < slen
                    u_val = fast_json_hex4(s, i + 2)
                    if u_val >= 0
                        if u_val >= 55296 and u_val <= 56319 and i + 11 < slen and mem_read_byte(s, i + 6) == 92 and mem_read_byte(s, i + 7) == 117
                            lo_val = fast_json_hex4(s, i + 8)
                            if lo_val >= 56320 and lo_val <= 57343
                                full_cp = 65536 + ((u_val - 55296) * 1024) + (lo_val - 56320)
                                _fast_json_buf_write_cp(b, full_cp)
                                i = i + 12
                                continue
                            end
                        end
                        _fast_json_buf_write_cp(b, u_val)
                        i = i + 6
                    else
                        // Invalid \uXXXX: emit Unicode replacement U+FFFD cleanly (never raw 'u')
                        _fast_json_buf_write_cp(b, 65533)
                        i = i + 2
                    end
                else
                    _fast_json_buf_write_cp(b, 65533)
                    i = i + 2
                end
            else
                buf_write_byte(b, nc)
                i = i + 2
            end
        else
            buf_write_byte(b, c)
            i = i + 1
        end
    end
    out = buf_to_str(b)
    buf_free(b)
    return out
end

// ── Fast JSON Document Constructor ────────────────────────────────────────────
// Document Structure:
//   [0]: src        (original string/buffer)
//   [1]: nodes      (list of node tuples)
//   [2]: root_idx   (integer index of root node)
fn fast_json_doc_new src
    doc = list()
    push(doc, src)
    push(doc, list())
    push(doc, 0 - 1)
    return doc

// Node Tuple Layout:
//   [0]: type        (FAST_JSON_*)
//   [1]: start_idx   (integer byte start in src)
//   [2]: end_idx     (integer byte end in src)
//   [3]: int_val     (integer value for INT and BOOL)
//   [4]: payload     (list for ARRAY, list(keys, vals) for OBJECT)
fn fast_json_add_node doc ty start_idx end_idx int_val payload
    nodes = get(doc, 1)
    node = list()
    push(node, ty)
    push(node, start_idx)
    push(node, end_idx)
    push(node, int_val)
    push(node, payload)
    idx = len(nodes)
    push(nodes, node)
    return idx

// ── In-Place Parser Helpers ───────────────────────────────────────────────────
fn fast_json_skip_ws src p slen
    while p < slen
        c = char_at(src, p)
        if c == " " or c == "\t" or c == "\n" or c == "\r"
            p = p + 1
        else
            return p
    return slen

// ── Zero-Copy In-Place JSON Recursive Descent Parser ─────────────────────────
// WHY: Pos is stored in a 1-element list to allow in-place mutable cursor advancement
fn fast_json_parse_val doc pos_ref
    src = get(doc, 0)
    slen = len(src)
    p = fast_json_skip_ws(src, get(pos_ref, 0), slen)
    if p >= slen
        list_set(pos_ref, 0, p)
        return 0 - 1

    c = char_at(src, p)

    // Case 1: String
    if c == "\""
        p = p + 1
        start_p = p
        while p < slen
            sc = mem_read_byte(src, p)
            if sc == 92
                if p + 1 < slen
                    p = p + 2
                else
                    p = p + 1
                end
            elif sc == 34
                break
            else
                p = p + 1
            end
        end
        end_p = p
        if p < slen and mem_read_byte(src, p) == 34
            p = p + 1
        end
        list_set(pos_ref, 0, p)
        return fast_json_add_node(doc, FAST_JSON_STR, start_p, end_p, 0, "")

    // Case 2: Object '{'
    if c == "{"
        p = p + 1
        keys = list()
        vals = list()
        while p < slen
            p = fast_json_skip_ws(src, p, slen)
            if p >= slen break end
            if mem_read_byte(src, p) == 125
                p = p + 1
                break
            end

            // Parse Key (must be string)
            if mem_read_byte(src, p) != 34
                // Syntax error or malformed object
                break
            end
            p = p + 1
            k_start = p
            k_has_esc = 0
            while p < slen
                sc = mem_read_byte(src, p)
                if sc == 92
                    k_has_esc = 1
                    if p + 1 < slen
                        p = p + 2
                    else
                        p = p + 1
                    end
                elif sc == 34
                    break
                else
                    p = p + 1
                end
            end
            k_end = p
            if p < slen and mem_read_byte(src, p) == 34
                p = p + 1
            end
            key_str = fast_json_slice(src, k_start, k_end)
            if k_has_esc == 1
                key_str = fast_json_unescape(key_str)
            end
            push(keys, key_str)

            // Expect ':'
            p = fast_json_skip_ws(src, p, slen)
            if p < slen and char_at(src, p) == ":"
                p = p + 1

            // Parse Value
            list_set(pos_ref, 0, p)
            val_idx = fast_json_parse_val(doc, pos_ref)
            push(vals, val_idx)
            p = get(pos_ref, 0)

            p = fast_json_skip_ws(src, p, slen)
            if p < slen and char_at(src, p) == ","
                p = p + 1
            elif p < slen and char_at(src, p) == "}"
                p = p + 1
                break
            else
                break

        list_set(pos_ref, 0, p)
        idx_map = 0
        if len(keys) >= 8
            idx_map = dict_new(len(keys) * 2)
            ki_m = 0
            while ki_m < len(keys)
                dict_set(idx_map, get(keys, ki_m), get(vals, ki_m) + 1)
                ki_m = ki_m + 1
            end
        end
        payload = list(keys, vals, idx_map)
        return fast_json_add_node(doc, FAST_JSON_OBJECT, 0, 0, 0, payload)

    // Case 3: Array '['
    if c == "["
        p = p + 1
        items = list()
        while p < slen
            p = fast_json_skip_ws(src, p, slen)
            if p >= slen break
            if char_at(src, p) == "]"
                p = p + 1
                break

            list_set(pos_ref, 0, p)
            item_idx = fast_json_parse_val(doc, pos_ref)
            push(items, item_idx)
            p = get(pos_ref, 0)

            p = fast_json_skip_ws(src, p, slen)
            if p < slen and char_at(src, p) == ","
                p = p + 1
            elif p < slen and char_at(src, p) == "]"
                p = p + 1
                break
            else
                break

        list_set(pos_ref, 0, p)
        return fast_json_add_node(doc, FAST_JSON_ARRAY, 0, 0, 0, items)

    // Case 4: Boolean true / false
    if c == "t" and p + 4 <= slen and fast_json_slice(src, p, p + 4) == "true"
        list_set(pos_ref, 0, p + 4)
        return fast_json_add_node(doc, FAST_JSON_BOOL, p, p + 4, 1, "")
    if c == "f" and p + 5 <= slen and fast_json_slice(src, p, p + 5) == "false"
        list_set(pos_ref, 0, p + 5)
        return fast_json_add_node(doc, FAST_JSON_BOOL, p, p + 5, 0, "")

    // Case 5: Null
    if c == "n" and p + 4 <= slen and fast_json_slice(src, p, p + 4) == "null"
        list_set(pos_ref, 0, p + 4)
        return fast_json_add_node(doc, FAST_JSON_NULL, p, p + 4, 0, "")

    // Case 6: Number (Integer, Fractional, or Scientific Notation)
    num_start = p
    is_neg = 0
    if c == "-"
        is_neg = 1
        p = p + 1

    if p < slen
        code = ord(char_at(src, p))
        if code >= 48 and code <= 57
            num_val = 0
            while p < slen
                nc = ord(char_at(src, p))
                if nc >= 48 and nc <= 57
                    num_val = (num_val * 10) - (nc - 48)
                    p = p + 1
                else
                    break
            if is_neg == 0
                num_val = 0 - num_val
            // Consume optional fractional component (.digits) per RFC 8259
            is_flt = 0
            if p < slen and mem_read_byte(src, p) == 46
                is_flt = 1
                p = p + 1
                while p < slen
                    fc = mem_read_byte(src, p)
                    if fc >= 48 and fc <= 57
                        p = p + 1
                    else
                        break
                    end
                end
            end
            // Consume optional exponent ([eE][+-]?digits) per RFC 8259
            if p < slen and (mem_read_byte(src, p) == 101 or mem_read_byte(src, p) == 69)
                is_flt = 1
                p = p + 1
                if p < slen and (mem_read_byte(src, p) == 43 or mem_read_byte(src, p) == 45)
                    p = p + 1
                end
                while p < slen
                    ec = mem_read_byte(src, p)
                    if ec >= 48 and ec <= 57
                        p = p + 1
                    else
                        break
                    end
                end
            end
            list_set(pos_ref, 0, p)
            raw_num = fast_json_slice(src, num_start, p)
            if is_flt == 1
                f_val = fast_json_parse_f64(raw_num)
                return fast_json_add_node(doc, FAST_JSON_FLOAT, num_start, p, f_val, raw_num)
            end
            return fast_json_add_node(doc, FAST_JSON_INT, num_start, p, num_val, raw_num)

    // Fallback: Skip 1 char on malformed input
    list_set(pos_ref, 0, p + 1)
    return 0 - 1

// ── Public API: Parse JSON Document ───────────────────────────────────────────
fn fast_json_parse src
    doc = fast_json_doc_new(src)
    pos_ref = list(0)
    root_idx = fast_json_parse_val(doc, pos_ref)
    list_set(doc, 2, root_idx)
    return doc

fn fast_json_root doc
    return get(doc, 2)

// ── Public API: Field & Value Accessors ────────────────────────────────────────
fn fast_json_node_type doc idx
    if idx < 0 return 0 - 1
    nodes = get(doc, 1)
    if idx >= len(nodes) return 0 - 1
    node = get(nodes, idx)
    return get(node, 0)

fn fast_json_get doc obj_idx key
    if obj_idx < 0 return 0 - 1
    nodes = get(doc, 1)
    if obj_idx >= len(nodes) return 0 - 1
    node = get(nodes, obj_idx)
    if get(node, 0) != FAST_JSON_OBJECT return 0 - 1

    payload = get(node, 4)
    if len(payload) >= 3
        idx_map = get(payload, 2)
        if idx_map != 0
            hit = dict_get(idx_map, key)
            if hit > 0
                return hit - 1
            end
            return 0 - 1
        end
    end
    keys = get(payload, 0)
    vals = get(payload, 1)

    i = 0
    klen = len(keys)
    while i < klen
        if get(keys, i) == key
            return get(vals, i)
        i = i + 1
    return 0 - 1

fn fast_json_get_str doc idx
    if idx < 0 return ""
    nodes = get(doc, 1)
    if idx >= len(nodes) return ""
    node = get(nodes, idx)
    if get(node, 0) != FAST_JSON_STR return ""
    src = get(doc, 0)
    raw = fast_json_slice(src, get(node, 1), get(node, 2))
    return fast_json_unescape(raw)

fn fast_json_get_int doc idx
    if idx < 0 return 0
    nodes = get(doc, 1)
    if idx >= len(nodes) return 0
    node = get(nodes, idx)
    if get(node, 0) != FAST_JSON_INT return 0
    return get(node, 3)

fn fast_json_get_bool doc idx
    if idx < 0 return 0
    nodes = get(doc, 1)
    if idx >= len(nodes) return 0
    node = get(nodes, idx)
    if get(node, 0) != FAST_JSON_BOOL return 0
    return get(node, 3)

fn fast_json_is_null doc idx
    if idx < 0 return 1
    nodes = get(doc, 1)
    if idx >= len(nodes) return 1
    node = get(nodes, idx)
    if get(node, 0) == FAST_JSON_NULL return 1
    return 0

fn fast_json_arr_len doc idx
    if idx < 0 return 0
    nodes = get(doc, 1)
    if idx >= len(nodes) return 0
    node = get(nodes, idx)
    if get(node, 0) != FAST_JSON_ARRAY return 0
    items = get(node, 4)
    return len(items)

fn fast_json_arr_get doc idx arr_i
    if idx < 0 return 0 - 1
    nodes = get(doc, 1)
    if idx >= len(nodes) return 0 - 1
    node = get(nodes, idx)
    if get(node, 0) != FAST_JSON_ARRAY return 0 - 1
    items = get(node, 4)
    if arr_i < 0 or arr_i >= len(items) return 0 - 1
    return get(items, arr_i)

// ── Public API: Dotted Path Traverser ──────────────────────────────────────────
// Example: fast_json_path(doc, root, "user.profile.age")
fn fast_json_path doc root_idx path_str
    cur_idx = root_idx
    p = 0
    plen = len(path_str)
    while p < plen and cur_idx >= 0
        seg_start = p
        while p < plen and char_at(path_str, p) != "."
            p = p + 1
        seg = fast_json_slice(path_str, seg_start, p)
        if p < plen and char_at(path_str, p) == "."
            p = p + 1

        ty = fast_json_node_type(doc, cur_idx)
        if ty == FAST_JSON_OBJECT
            cur_idx = fast_json_get(doc, cur_idx, seg)
        elif ty == FAST_JSON_ARRAY
            // Try array index parse
            arr_i = 0
            si = 0
            while si < len(seg)
                sc = ord(char_at(seg, si))
                if sc >= 48 and sc <= 57
                    arr_i = (arr_i * 10) + (sc - 48)
                si = si + 1
            cur_idx = fast_json_arr_get(doc, cur_idx, arr_i)
        else
            return 0 - 1
    return cur_idx

// ── Public API: Float Accessor & O(N) ByteBuffer JSON Serializer ──────────────
fn fast_json_as_float doc idx
    if idx < 0 return 0.0 end
    nodes = get(doc, 1)
    if idx >= len(nodes) return 0.0 end
    node = get(nodes, idx)
    ty = get(node, 0)
    if ty == FAST_JSON_FLOAT
        return get(node, 3)
    end
    if ty == FAST_JSON_INT
        return fast_json_parse_f64(str(get(node, 3)))
    end
    return 0.0
end

fn _fast_json_stringify_into doc idx buf
    if idx < 0
        buf_write_str(buf, "null")
        return 0
    end
    nodes = get(doc, 1)
    if idx >= len(nodes)
        buf_write_str(buf, "null")
        return 0
    end
    node = get(nodes, idx)
    ty = get(node, 0)

    if ty == FAST_JSON_NULL
        buf_write_str(buf, "null")
        return 0
    end
    if ty == FAST_JSON_BOOL
        if get(node, 3) == 1
            buf_write_str(buf, "true")
        else
            buf_write_str(buf, "false")
        end
        return 0
    end
    if ty == FAST_JSON_INT
        buf_write_str(buf, str(get(node, 3)))
        return 0
    end
    if ty == FAST_JSON_FLOAT
        raw_f = get(node, 4)
        if len(raw_f) > 0
            buf_write_str(buf, raw_f)
        else
            buf_write_str(buf, float_to_str(get(node, 3)))
        end
        return 0
    end
    if ty == FAST_JSON_STR
        src = get(doc, 0)
        raw_s = fast_json_slice(src, get(node, 1), get(node, 2))
        un = fast_json_unescape(raw_s)
        buf_write_byte(buf, 34)
        fast_json_escape_into(buf, un)
        buf_write_byte(buf, 34)
        return 0
    end
    if ty == FAST_JSON_ARRAY
        items = get(node, 4)
        buf_write_byte(buf, 91)
        i = 0
        ilen = len(items)
        while i < ilen
            if i > 0 buf_write_byte(buf, 44) end
            _fast_json_stringify_into(doc, get(items, i), buf)
            i = i + 1
        end
        buf_write_byte(buf, 93)
        return 0
    end
    if ty == FAST_JSON_OBJECT
        payload = get(node, 4)
        keys = get(payload, 0)
        vals = get(payload, 1)
        buf_write_byte(buf, 123)
        i = 0
        klen = len(keys)
        while i < klen
            if i > 0 buf_write_byte(buf, 44) end
            buf_write_byte(buf, 34)
            fast_json_escape_into(buf, get(keys, i))
            buf_write_str(buf, "\":")
            _fast_json_stringify_into(doc, get(vals, i), buf)
            i = i + 1
        end
        buf_write_byte(buf, 125)
        return 0
    end
    buf_write_str(buf, "null")
    return 0
end

fn fast_json_stringify doc idx
    b = buf_new(128)
    _fast_json_stringify_into(doc, idx, b)
    out = buf_to_str(b)
    buf_free(b)
    return out
end
