// ==============================================================================
// 📜 লিপি ২.০ সার্বভৌমিক জেসন লাইব্রেরি (Pure Lipi First 1.0.0 Sovereign JSON Engine)
// 🏛️ Zero Libc | Zero External Dependencies | Complete Bilingual Support
// ==============================================================================
// WHY: আধুনিক ওয়েব এপিআই, মাইক্রোসার্ভিস ও এলএসপি প্রোটোকলের জন্য উচ্চগতির এবং
// সম্পূর্ণ সুরক্ষিত জেসন পার্সিং ও সিরিয়ালাইজেশন অত্যন্ত আবশ্যকীয়।

// ── জেসন ডেটা টাইপ ধ্রুবক (JSON Value Types) ─────────────────────────────────
JSON_NULL   = 0
JSON_BOOL   = 1
JSON_NUMBER = 2
JSON_STRING = 3
JSON_ARRAY  = 4
JSON_OBJECT = 5

fn json_hex_nibble n
    d = n % 16
    if d < 10 return chr(48 + d)
    return chr(87 + d)

fn json_hex4 s off
    if off + 4 > len(s) return 0 - 1
    acc = 0
    k = 0
    while k < 4
        uc = ord(char_at(s, off + k))
        ud = 0 - 1
        if uc >= 48 and uc <= 57
            ud = uc - 48
        elif uc >= 65 and uc <= 70
            ud = uc - 55
        elif uc >= 97 and uc <= 102
            ud = uc - 87
        else
            return 0 - 1
        acc = (acc * 16) + ud
        k = k + 1
    return acc

fn json_utf8_cp cp
    if cp < 0 or cp > 1114111
        return chr(239) + chr(191) + chr(189)
    if cp <= 127
        return chr(cp)
    if cp <= 2047
        return chr(192 + (cp / 64)) + chr(128 + (cp % 64))
    if cp <= 65535
        return chr(224 + (cp / 4096)) + chr(128 + ((cp / 64) % 64)) + chr(128 + (cp % 64))
    return chr(240 + (cp / 262144)) + chr(128 + ((cp / 4096) % 64)) + chr(128 + ((cp / 64) % 64)) + chr(128 + (cp % 64))

// ── ১. স্ট্রিং এসকেপ হ্যান্ডলিং (String Escaping & Unescaping) ────────────────
// WHY: RFC 8259 অনুযায়ী উদ্ধৃতি চিহ্ন, ব্যাকস্ল্যাশ ও < 0x20 কন্ট্রোল বাইট এসকেপ করে।
fn json_escape s
    res = ""
    i = 0
    slen = len(s)
    while i < slen
        c = char_at(s, i)
        code = ord(c)
        if c == "\\"
            res = res + "\\\\"
        elif c == "\""
            res = res + "\\\""
        elif code == 8
            res = res + "\\b"
        elif code == 12
            res = res + "\\f"
        elif c == "\n"
            res = res + "\\n"
        elif c == "\r"
            res = res + "\\r"
        elif c == "\t"
            res = res + "\\t"
        elif code >= 0 and code < 32
            res = res + "\\u00" + json_hex_nibble(code / 16) + json_hex_nibble(code % 16)
        else
            res = res + c
        i = i + 1
    return res

fn জেসন_এসকেপ s
    return json_escape(s)

// WHY: এসকেপ সিকোয়েন্স ও UTF-16 সারোগেট পেয়ার বিশিষ্ট জেসন স্ট্রিং মূল লিপিতে পুনরুদ্ধার করে।
fn json_unescape s
    res = ""
    i = 0
    slen = len(s)
    while i < slen
        c = char_at(s, i)
        if c == "\\" and i + 1 < slen
            next_c = char_at(s, i + 1)
            if next_c == "\""
                res = res + "\""
                i = i + 2
            elif next_c == "\\"
                res = res + "\\"
                i = i + 2
            elif next_c == "/"
                res = res + "/"
                i = i + 2
            elif next_c == "n"
                res = res + "\n"
                i = i + 2
            elif next_c == "r"
                res = res + "\r"
                i = i + 2
            elif next_c == "t"
                res = res + "\t"
                i = i + 2
            elif next_c == "b"
                res = res + chr(8)
                i = i + 2
            elif next_c == "f"
                res = res + chr(12)
                i = i + 2
            elif next_c == "u" and i + 5 < slen
                u_val = json_hex4(s, i + 2)
                if u_val >= 0
                    if u_val >= 55296 and u_val <= 56319 and i + 11 < slen and char_at(s, i + 6) == "\\" and char_at(s, i + 7) == "u"
                        lo_val = json_hex4(s, i + 8)
                        if lo_val >= 56320 and lo_val <= 57343
                            full_cp = 65536 + ((u_val - 55296) * 1024) + (lo_val - 56320)
                            res = res + json_utf8_cp(full_cp)
                            i = i + 12
                            continue
                    res = res + json_utf8_cp(u_val)
                    i = i + 6
                else
                    res = res + "u"
                    i = i + 2
            else
                res = res + next_c
                i = i + 2
        else
            res = res + c
            i = i + 1
    return res

fn জেসন_আনএসকেপ s
    return json_unescape(s)

// ── ২. সংখ্যা যাচাইকরণ (Validate Number Representation) ───────────────────────
// WHY: কঠোরভাবে যাচাই করে যে কোনো স্ট্রিং বৈধ জেসন সংখ্যা (চিহ্ন, দশমিক ও এক্সপোনেন্ট সহ) কিনা।
fn json_is_num s
    slen = len(s)
    if slen == 0
        return 0
    start = 0
    first = char_at(s, 0)
    if first == "-"
        start = 1
    if start >= slen
        return 0
    has_digit = 0
    has_dot = 0
    has_exp = 0
    i = start
    while i < slen
        c = char_at(s, i)
        code = ord(c)
        if code >= 48 and code <= 57
            has_digit = 1
        else
            if c == "."
                if has_dot == 1 or has_exp == 1
                    return 0
                has_dot = 1
            else
                if c == "e" or c == "E"
                    if has_exp == 1 or has_digit == 0
                        return 0
                    has_exp = 1
                    if i + 1 < slen
                        next_c = char_at(s, i + 1)
                        if next_c == "+" or next_c == "-"
                            i = i + 1
                else
                    return 0
        i = i + 1
    return has_digit

fn জেসন_কি_সংখ্যা s
    return json_is_num(s)

// ── ৩. মান ফরম্যাটিং হেল্পার (Format Value for JSON Insertion) ─────────────────
// WHY: প্রি-ফরম্যাটেড জেসন অবজেক্ট/অ্যারে, সংখ্যা, বা র স্ট্রিংকে স্বয়ংক্রিয়ভাবে
// শনাক্ত করে সঠিক উদ্ধৃতি ও এস্কেপ প্রদান করে।
fn json_format_val val
    s = str(val)
    slen = len(s)
    if slen == 0
        return "\"\""
    first = char_at(s, 0)
    last = char_at(s, slen - 1)
    if first == "\"" and last == "\"" and slen >= 2
        return s
    if (first == "{" and last == "}") or (first == "[" and last == "]")
        return s
    if s == "true" or s == "false" or s == "null"
        return s
    if json_is_num(s) == 1
        return s
    return "\"" + json_escape(s) + "\""

fn জেসন_মান_ফরম্যাট val
    return json_format_val(val)

// ── ৩.৫ ইউনিভার্সাল জেসন স্ট্রিং রূপান্তর (Universal Stringifier) ──────────────
// WHY: প্রিমিটিভ মানকে সরাসরি স্ট্রিং রিপ্রেজেন্টেশনে রূপান্তর করে যা ডকো বা টেস্টে ব্যবহৃত হয়।
fn json_stringify val
    return str(val)

fn জেসন_স্ট্রিংফাই val
    return json_stringify(val)

// ── ৪. সাধারণ প্রিমিটিভ সিরিয়ালাইজেশন (Primitive Serializers) ──────────────────
fn json_str s
    return "\"" + json_escape(s) + "\""

fn জেসন_স্ট্রিং s
    return json_str(s)

fn json_num n
    return str(n)

fn জেসন_সংখ্যা n
    return json_num(n)

fn json_bool b
    if b
        return "true"
    return "false"

fn জেসন_বুলিয়ান b
    return json_bool(b)

fn json_null
    return "null"

fn জেসন_নাল
    return json_null()

// ── ৫. পার্সার ফাংশনসমূহ (JSON Parser Primitives) ─────────────────────────────
// WHY: জেসন স্ট্রিং লিটারাল থেকে বাইরের কোট ও অভ্যন্তরীণ এসকেপ সিকোয়েন্স নিষ্কাশন করে।
fn json_parse_str s
    slen = len(s)
    if slen == 0
        return ""
    // হোয়াইটস্পেস এড়ানো
    p = 0
    while p < slen
        c = char_at(s, p)
        if c == " " or c == "\t" or c == "\n" or c == "\r"
            p = p + 1
        else
            break
    if p >= slen
        return ""

    quote_char = char_at(s, p)
    is_quoted = 0
    if quote_char == "\"" or quote_char == "'"
        is_quoted = 1
        p = p + 1

    res = ""
    while p < slen
        c = char_at(s, p)
        if is_quoted == 1 and c == quote_char
            return res
        if c == "\\" and p + 1 < slen
            next_c = char_at(s, p + 1)
            if next_c == "\""
                res = res + "\""
                p = p + 2
            elif next_c == "\\"
                res = res + "\\"
                p = p + 2
            elif next_c == "/"
                res = res + "/"
                p = p + 2
            elif next_c == "n"
                res = res + "\n"
                p = p + 2
            elif next_c == "r"
                res = res + "\r"
                p = p + 2
            elif next_c == "t"
                res = res + "\t"
                p = p + 2
            elif next_c == "b"
                res = res + chr(8)
                p = p + 2
            elif next_c == "f"
                res = res + chr(12)
                p = p + 2
            elif next_c == "u" and p + 5 < slen
                u_val = json_hex4(s, p + 2)
                if u_val >= 0
                    if u_val >= 55296 and u_val <= 56319 and p + 11 < slen and char_at(s, p + 6) == "\\" and char_at(s, p + 7) == "u"
                        lo_val = json_hex4(s, p + 8)
                        if lo_val >= 56320 and lo_val <= 57343
                            full_cp = 65536 + ((u_val - 55296) * 1024) + (lo_val - 56320)
                            res = res + json_utf8_cp(full_cp)
                            p = p + 12
                            continue
                    res = res + json_utf8_cp(u_val)
                    p = p + 6
                else
                    res = res + "u"
                    p = p + 2
            else
                res = res + next_c
                p = p + 2
        else
            if is_quoted == 0 and (c == " " or c == "\t" or c == "\n" or c == "\r" or c == "," or c == "]" or c == "}")
                return res
            else
                res = res + c
                p = p + 1
    return res

fn জেসন_স্ট্রিং_পার্স s
    return json_parse_str(s)

// WHY: স্ট্রিং থেকে চিহ্নযুক্ত ৬৪-বিট পূর্ণসংখ্যা (Signed 64-bit Integer) তৈরি করে।
fn json_parse_num s
    slen = len(s)
    if slen == 0
        return 0
    p = 0
    while p < slen
        c = char_at(s, p)
        if c == " " or c == "\t" or c == "\n" or c == "\r"
            p = p + 1
        else
            break
    if p >= slen
        return 0

    sign = 1
    first_c = char_at(s, p)
    if first_c == "-"
        sign = -1
        p = p + 1
    else
        if first_c == "+"
            p = p + 1

    val = 0
    has_digits = 0
    while p < slen
        c = char_at(s, p)
        code = ord(c)
        if code >= 48 and code <= 57
            val = (val * 10) + (code - 48)
            has_digits = 1
            p = p + 1
        else
            break

    if has_digits == 0
        return 0
    return val * sign

fn জেসন_সংখ্যা_পার্স s
    return json_parse_num(s)

// ── ৬. কালেকশন সিরিয়ালাইজারসমূহ (Collection Serializers) ──────────────────────
// WHY: ডায়নামিক লিপি তালিকা (List) কে স্ট্যান্ডার্ড জেসন অ্যারেতে রূপান্তর করে।
fn json_stringify_list items
    count = len(items)
    if count == 0
        return "[]"
    res = "["
    i = 0
    while i < count
        val = get(items, i)
        formatted = json_format_val val
        if i > 0
            res = res + ", " + formatted
        else
            res = res + formatted
        i = i + 1
    res = res + "]"
    return res

fn জেসন_তালিকা_রূপান্তর items
    return json_stringify_list(items)

// WHY: ফ্ল্যাট কী-ভ্যালু জোড়া [k1, v1, k2, v2, ...] কে স্ট্যান্ডার্ড জেসন অবজেক্টে রূপান্তর করে।
fn json_stringify_map pairs
    count = len(pairs)
    if count == 0
        return "{}"
    res = "{"
    i = 0
    while i < count
        k = str(get(pairs, i))
        v = get(pairs, i + 1)
        formatted_v = json_format_val v
        item_str = "\"" + json_escape(k) + "\": " + formatted_v
        if i > 0
            res = res + ", " + item_str
        else
            res = res + item_str
        i = i + 2
    res = res + "}"
    return res

fn জেসন_ম্যাপ_রূপান্তর pairs
    return json_stringify_map(pairs)

// WHY: নেস্টেড সাব-লিস্ট জোড়া [[k1, v1], [k2, v2], ...] সিরিয়ালাইজ করার জন্য।
fn json_stringify_nested pair_list
    count = len(pair_list)
    if count == 0
        return "{}"
    res = "{"
    i = 0
    while i < count
        p = get(pair_list, i)
        k = str(get(p, 0))
        v = get(p, 1)
        formatted_v = json_format_val v
        item_str = "\"" + json_escape(k) + "\": " + formatted_v
        if i > 0
            res = res + ", " + item_str
        else
            res = res + item_str
        i = i + 1
    res = res + "}"
    return res

fn জেসন_নেস্টেড_রূপান্তর pair_list
    return json_stringify_nested(pair_list)

// WHY: দুটি পৃথক কী এবং মান তালিকা থেকে সরাসরি জেসন অবজেক্ট প্রস্তুত করে।
fn json_stringify_keys_values keys values
    kcount = len(keys)
    vcount = len(values)
    limit = kcount
    if vcount < limit
        limit = vcount
    if limit == 0
        return "{}"
    res = "{"
    i = 0
    while i < limit
        k = str(get(keys, i))
        v = get(values, i)
        formatted_v = json_format_val v
        item_str = "\"" + json_escape(k) + "\": " + formatted_v
        if i > 0
            res = res + ", " + item_str
        else
            res = res + item_str
        i = i + 1
    res = res + "}"
    return res

fn জেসন_কি_ভ্যালু_রূপান্তর keys values
    return json_stringify_keys_values(keys, values)

// ── ৭. সুবিধাজনক শর্টকাট অবজেক্ট মেকার (Convenience Builders) ──────────────────
fn json_obj2 k1 v1 k2 v2
    return "{\"" + k1 + "\": " + json_format_val(v1) + ", \"" + k2 + "\": " + json_format_val(v2) + "}"

fn জেসন_অবজেক্ট২ k1 v1 k2 v2
    return json_obj2(k1, v1, k2, v2)

fn json_arr2 a b
    return "[" + json_format_val(a) + ", " + json_format_val(b) + "]"

fn জেসন_অ্যারে২ a b
    return json_arr2(a, b)

// ── ৮. এইচটিটিপি ও আরপিসি রেসপন্স (HTTP / RPC Standard Responses) ───────────────
fn json_response_ok data
    return "{\"status\": \"ok\", \"data\": " + json_format_val(data) + "}"

fn জেসন_রেসপন্স_সফল data
    return json_response_ok(data)

fn json_response_err msg
    return "{\"status\": \"error\", \"message\": " + json_str(msg) + "}"

fn জেসন_রেসপন্স_ব্যর্থ msg
    return json_response_err(msg)

// ── ৯. ডিসপ্লে, পার্সিং ও প্রিটি প্রিন্ট (JSON Pretty & Recursive Parser) ──────
struct JsonEntry
    key
    value

fn json_indent_str depth indent
    out = ""
    total = depth * indent
    i = 0
    while i < total
        out = out + " "
        i = i + 1
    return out

// WHY: Renders raw JSON string with configurable indentation while preserving string literals intact.
fn json_pretty obj indent
    src = str(obj)
    slen = len(src)
    if slen == 0
        return ""
    step = indent
    if step <= 0
        step = 2
    res = ""
    depth = 0
    in_str = 0
    i = 0
    while i < slen
        c = char_at(src, i)
        if in_str == 1
            res = res + c
            if c == "\\" and i + 1 < slen
                res = res + char_at(src, i + 1)
                i = i + 2
                continue
            if c == "\""
                in_str = 0
            i = i + 1
            continue
        if c == " " or c == "\t" or c == "\n" or c == "\r"
            i = i + 1
            continue
        if c == "\""
            in_str = 1
            res = res + c
            i = i + 1
        elif c == "{" or c == "["
            depth = depth + 1
            // Check empty container {} or []
            peek = i + 1
            while peek < slen and (char_at(src, peek) == " " or char_at(src, peek) == "\t" or char_at(src, peek) == "\n" or char_at(src, peek) == "\r")
                peek = peek + 1
            if peek < slen and ((c == "{" and char_at(src, peek) == "}") or (c == "[" and char_at(src, peek) == "]"))
                res = res + c + char_at(src, peek)
                depth = depth - 1
                i = peek + 1
            else
                res = res + c + "\n" + json_indent_str(depth, step)
                i = i + 1
        elif c == "}" or c == "]"
            depth = depth - 1
            if depth < 0
                depth = 0
            res = res + "\n" + json_indent_str(depth, step) + c
            i = i + 1
        elif c == ","
            res = res + ",\n" + json_indent_str(depth, step)
            i = i + 1
        elif c == ":"
            res = res + ": "
            i = i + 1
        else
            res = res + c
            i = i + 1
    return res

fn জেসন_প্রিন্ট obj indent
    say json_pretty(obj, indent)
    return 0

// WHY: Recursive-descent JSON DOM parser returning list of {key, value} for JSON Objects,
// arrays for JSON Arrays, unescaped strings, integers, 1/0 booleans, and 0 for null.
fn json_parse_skip_ws s p slen
    while p < slen
        c = char_at(s, p)
        if c == " " or c == "\t" or c == "\n" or c == "\r"
            p = p + 1
        else
            return p
    return slen

fn json_parse_str_token s pos_ref
    slen = len(s)
    p = get(pos_ref, 0) + 1 // skip opening '"'
    start_p = p
    while p < slen
        c = char_at(s, p)
        if c == "\\" and p + 1 < slen
            p = p + 2
        elif c == "\""
            break
        else
            p = p + 1
    raw = ""
    k = start_p
    while k < p
        raw = raw + char_at(s, k)
        k = k + 1
    if p < slen and char_at(s, p) == "\""
        p = p + 1
    list_set(pos_ref, 0, p)
    return json_unescape(raw)

fn json_parse_val_at s pos_ref
    slen = len(s)
    p = json_parse_skip_ws(s, get(pos_ref, 0), slen)
    list_set(pos_ref, 0, p)
    if p >= slen
        return 0
    c = char_at(s, p)
    if c == "\""
        return json_parse_str_token(s, pos_ref)
    if c == "{"
        list_set(pos_ref, 0, p + 1)
        entries = list()
        while get(pos_ref, 0) < slen
            np = json_parse_skip_ws(s, get(pos_ref, 0), slen)
            list_set(pos_ref, 0, np)
            if np >= slen
                break
            if char_at(s, np) == "}"
                list_set(pos_ref, 0, np + 1)
                break
            if char_at(s, np) != "\""
                break
            k_str = json_parse_str_token(s, pos_ref)
            cp = json_parse_skip_ws(s, get(pos_ref, 0), slen)
            if cp < slen and char_at(s, cp) == ":"
                cp = cp + 1
            list_set(pos_ref, 0, cp)
            v_val = json_parse_val_at(s, pos_ref)
            e = JsonEntry()
            e.key = k_str
            e.value = v_val
            push(entries, e)
            sp = json_parse_skip_ws(s, get(pos_ref, 0), slen)
            if sp < slen and char_at(s, sp) == ","
                list_set(pos_ref, 0, sp + 1)
            elif sp < slen and char_at(s, sp) == "}"
                list_set(pos_ref, 0, sp + 1)
                break
            else
                list_set(pos_ref, 0, sp)
                break
        return entries
    if c == "["
        list_set(pos_ref, 0, p + 1)
        arr = list()
        while get(pos_ref, 0) < slen
            np = json_parse_skip_ws(s, get(pos_ref, 0), slen)
            list_set(pos_ref, 0, np)
            if np >= slen
                break
            if char_at(s, np) == "]"
                list_set(pos_ref, 0, np + 1)
                break
            elem = json_parse_val_at(s, pos_ref)
            push(arr, elem)
            sp = json_parse_skip_ws(s, get(pos_ref, 0), slen)
            if sp < slen and char_at(s, sp) == ","
                list_set(pos_ref, 0, sp + 1)
            elif sp < slen and char_at(s, sp) == "]"
                list_set(pos_ref, 0, sp + 1)
                break
            else
                list_set(pos_ref, 0, sp)
                break
        return arr
    if c == "t" and p + 4 <= slen and char_at(s, p + 1) == "r" and char_at(s, p + 2) == "u" and char_at(s, p + 3) == "e"
        list_set(pos_ref, 0, p + 4)
        return 1
    if c == "f" and p + 5 <= slen and char_at(s, p + 1) == "a" and char_at(s, p + 2) == "l" and char_at(s, p + 3) == "s" and char_at(s, p + 4) == "e"
        list_set(pos_ref, 0, p + 5)
        return 0
    if c == "n" and p + 4 <= slen and char_at(s, p + 1) == "u" and char_at(s, p + 2) == "l" and char_at(s, p + 3) == "l"
        list_set(pos_ref, 0, p + 4)
        return 0
    neg = 0
    num_start = p
    if c == "-"
        neg = 1
        p = p + 1
    acc = 0
    while p < slen
        nc = ord(char_at(s, p))
        if nc >= 48 and nc <= 57
            acc = (acc * 10) - (nc - 48)
            p = p + 1
        else
            break
    if neg == 0
        acc = 0 - acc
    // Parse fractional/exponent IEEE-754 f64 when '.' or 'e'/'E' is present (RFC 8259)
    is_flt = 0
    if p < slen and char_at(s, p) == "."
        is_flt = 1
        p = p + 1
        while p < slen and ord(char_at(s, p)) >= 48 and ord(char_at(s, p)) <= 57
            p = p + 1
    if p < slen and (char_at(s, p) == "e" or char_at(s, p) == "E")
        is_flt = 1
        p = p + 1
        if p < slen and (char_at(s, p) == "+" or char_at(s, p) == "-")
            p = p + 1
        while p < slen and ord(char_at(s, p)) >= 48 and ord(char_at(s, p)) <= 57
            p = p + 1
    list_set(pos_ref, 0, p)
    if is_flt == 1
        // Compute exact f64 from s[num_start..p)
        fp = num_start
        fneg = 0
        if fp < p and mem_read_byte(s, fp) == 45
            fneg = 1
            fp = fp + 1
        end
        fval = 0.0
        while fp < p
            fc = mem_read_byte(s, fp)
            if fc >= 48 and fc <= 57
                fval = (fval * 10.0) + (fc - 48)
                fp = fp + 1
            else
                break
            end
        end
        if fp < p and mem_read_byte(s, fp) == 46
            fp = fp + 1
            frac = 0.1
            while fp < p
                fc = mem_read_byte(s, fp)
                if fc >= 48 and fc <= 57
                    fval = fval + ((fc - 48) * frac)
                    frac = frac * 0.1
                    fp = fp + 1
                else
                    break
                end
            end
        end
        if fp < p and (mem_read_byte(s, fp) == 101 or mem_read_byte(s, fp) == 69)
            fp = fp + 1
            eneg = 0
            if fp < p and mem_read_byte(s, fp) == 45
                eneg = 1
                fp = fp + 1
            elif fp < p and mem_read_byte(s, fp) == 43
                fp = fp + 1
            end
            exp = 0
            while fp < p
                fc = mem_read_byte(s, fp)
                if fc >= 48 and fc <= 57
                    exp = (exp * 10) + (fc - 48)
                    fp = fp + 1
                else
                    break
                end
            end
            if exp > 308 exp = 308 end
            ei = 0
            while ei < exp
                if eneg == 1 fval = fval * 0.1 else fval = fval * 10.0 end
                ei = ei + 1
            end
        end
        if fneg == 1 fval = 0.0 - fval end
        return fval
    end
    return acc

fn json_parse src
    if len(src) == 0
        return 0
    pos_ref = list(0)
    return json_parse_val_at(src, pos_ref)
