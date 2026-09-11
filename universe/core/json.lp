// ==============================================================================
// 📜 লিপি ২.০ সার্বভৌমিক জেসন লাইব্রেরি (Pure Lipi 2.0 Sovereign JSON Engine)
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

// ── ১. স্ট্রিং এসকেপ হ্যান্ডলিং (String Escaping & Unescaping) ────────────────
// WHY: জেসন স্পেসিফিকেশন অনুযায়ী উদ্ধৃতি চিহ্ন এবং বিশেষ কন্ট্রোল ক্যারেক্টার
// এসকেপ না করলে পেলোড বিকৃত হয়।
fn json_escape s
    res = ""
    i = 0
    slen = len s
    while i < slen
        c = char_at(s, i)
        if c == "\\"
            res = res + "\\\\"
        else
            if c == "\""
                res = res + "\\\""
            else
                if c == "\n"
                    res = res + "\\n"
                else
                    if c == "\r"
                        res = res + "\\r"
                    else
                        if c == "\t"
                            res = res + "\\t"
                        else
                            res = res + c
        i = i + 1
    return res

fn জেসন_এসকেপ s
    return json_escape s

// WHY: এসকেপ সিকোয়েন্স বিশিষ্ট জেসন স্ট্রিংকে স্বাভাবিক মূল লিপিতে পুনরুদ্ধার করে।
fn json_unescape s
    res = ""
    i = 0
    slen = len s
    while i < slen
        c = char_at(s, i)
        if c == "\\" and i + 1 < slen
            next_c = char_at(s, i + 1)
            if next_c == "\""
                res = res + "\""
            else
                if next_c == "\\"
                    res = res + "\\"
                else
                    if next_c == "/"
                        res = res + "/"
                    else
                        if next_c == "n"
                            res = res + "\n"
                        else
                            if next_c == "r"
                                res = res + "\r"
                            else
                                if next_c == "t"
                                    res = res + "\t"
                                else
                                    if next_c == "b"
                                        res = res + chr(8)
                                    else
                                        if next_c == "f"
                                            res = res + chr(12)
                                        else
                                            res = res + next_c
            i = i + 2
        else
            res = res + c
            i = i + 1
    return res

fn জেসন_আনএসকেপ s
    return json_unescape s

// ── ২. সংখ্যা যাচাইকরণ (Validate Number Representation) ───────────────────────
// WHY: কঠোরভাবে যাচাই করে যে কোনো স্ট্রিং বৈধ জেসন সংখ্যা (চিহ্ন, দশমিক ও এক্সপোনেন্ট সহ) কিনা।
fn json_is_num s
    slen = len s
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
    return json_is_num s

// ── ৩. মান ফরম্যাটিং হেল্পার (Format Value for JSON Insertion) ─────────────────
// WHY: প্রি-ফরম্যাটেড জেসন অবজেক্ট/অ্যারে, সংখ্যা, বা র স্ট্রিংকে স্বয়ংক্রিয়ভাবে
// শনাক্ত করে সঠিক উদ্ধৃতি ও এস্কেপ প্রদান করে।
fn json_format_val val
    s = str val
    slen = len s
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
    return json_format_val val

// ── ৩.৫ ইউনিভার্সাল জেসন স্ট্রিং রূপান্তর (Universal Stringifier) ──────────────
// WHY: প্রিমিটিভ মানকে সরাসরি স্ট্রিং রিপ্রেজেন্টেশনে রূপান্তর করে যা ডকো বা টেস্টে ব্যবহৃত হয়।
fn json_stringify val
    return str val

fn জেসন_স্ট্রিংফাই val
    return json_stringify val

// ── ৪. সাধারণ প্রিমিটিভ সিরিয়ালাইজেশন (Primitive Serializers) ──────────────────
fn json_str s
    return "\"" + json_escape(s) + "\""

fn জেসন_স্ট্রিং s
    return json_str s

fn json_num n
    return str n

fn জেসন_সংখ্যা n
    return json_num n

fn json_bool b
    if b
        return "true"
    return "false"

fn জেসন_বুলিয়ান b
    return json_bool b

fn json_null
    return "null"

fn জেসন_নাল
    return json_null()

// ── ৫. পার্সার ফাংশনসমূহ (JSON Parser Primitives) ─────────────────────────────
// WHY: জেসন স্ট্রিং লিটারাল থেকে বাইরের কোট ও অভ্যন্তরীণ এসকেপ সিকোয়েন্স নিষ্কাশন করে।
fn json_parse_str s
    slen = len s
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
            else
                if next_c == "\\"
                    res = res + "\\"
                else
                    if next_c == "/"
                        res = res + "/"
                    else
                        if next_c == "n"
                            res = res + "\n"
                        else
                            if next_c == "r"
                                res = res + "\r"
                            else
                                if next_c == "t"
                                    res = res + "\t"
                                else
                                    if next_c == "b"
                                        res = res + chr(8)
                                    else
                                        if next_c == "f"
                                            res = res + chr(12)
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
    return json_parse_str s

// WHY: স্ট্রিং থেকে চিহ্নযুক্ত ৬৪-বিট পূর্ণসংখ্যা (Signed 64-bit Integer) তৈরি করে।
fn json_parse_num s
    slen = len s
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
    return json_parse_num s

// ── ৬. কালেকশন সিরিয়ালাইজারসমূহ (Collection Serializers) ──────────────────────
// WHY: ডায়নামিক লিপি তালিকা (List) কে স্ট্যান্ডার্ড জেসন অ্যারেতে রূপান্তর করে।
fn json_stringify_list items
    count = len items
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
    return json_stringify_list items

// WHY: ফ্ল্যাট কী-ভ্যালু জোড়া [k1, v1, k2, v2, ...] কে স্ট্যান্ডার্ড জেসন অবজেক্টে রূপান্তর করে।
fn json_stringify_map pairs
    count = len pairs
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
    return json_stringify_map pairs

// WHY: নেস্টেড সাব-লিস্ট জোড়া [[k1, v1], [k2, v2], ...] সিরিয়ালাইজ করার জন্য।
fn json_stringify_nested pair_list
    count = len pair_list
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
    return json_stringify_nested pair_list

// WHY: দুটি পৃথক কী এবং মান তালিকা থেকে সরাসরি জেসন অবজেক্ট প্রস্তুত করে।
fn json_stringify_keys_values keys values
    kcount = len keys
    vcount = len values
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
    return json_stringify_keys_values keys values

// ── ৭. সুবিধাজনক শর্টকাট অবজেক্ট মেকার (Convenience Builders) ──────────────────
fn json_obj2 k1 v1 k2 v2
    return "{\"" + k1 + "\": " + json_format_val(v1) + ", \"" + k2 + "\": " + json_format_val(v2) + "}"

fn জেসন_অবজেক্ট২ k1 v1 k2 v2
    return json_obj2 k1 v1 k2 v2

fn json_arr2 a b
    return "[" + json_format_val(a) + ", " + json_format_val(b) + "]"

fn জেসন_অ্যারে২ a b
    return json_arr2 a b

// ── ৮. এইচটিটিপি ও আরপিসি রেসপন্স (HTTP / RPC Standard Responses) ───────────────
fn json_response_ok data
    return "{\"status\": \"ok\", \"data\": " + json_format_val(data) + "}"

fn জেসন_রেসপন্স_সফল data
    return json_response_ok data

fn json_response_err msg
    return "{\"status\": \"error\", \"message\": " + json_str(msg) + "}"

fn জেসন_রেসপন্স_ব্যর্থ msg
    return json_response_err msg

// ── ৯. ডিসপ্লে ও লগিং (Pretty Print & Output) ─────────────────────────────────
fn json_pretty obj indent
    say obj
    return 0

fn জেসন_প্রিন্ট obj indent
    return json_pretty obj indent
