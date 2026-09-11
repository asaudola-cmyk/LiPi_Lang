// ==============================================================================
// 👑 LIPI STANDARD STRING LIBRARY (std/str.lp)
// ⚡ 100% Pure Lipi Sovereign Engine | Zero Libc | Zero External Runtime
// ==============================================================================

// WHY: Provides complete, dependency-free string transformation, searching,
// slicing, and formatting routines in pure Lipi 2.0.

// ── 1. Case Transformations ──────────────────────────────────────────────────

// WHY: Converts lowercase ASCII characters (a-z: 97-122) to uppercase (A-Z: 65-90).
// Non-ASCII and already-uppercase characters pass through untouched.
fn upper s
    res = ""
    i = 0
    slen = len(s)
    while i < slen
        c = char_at(s, i)
        code = ord(c)
        if code >= 97 and code <= 122
            res = res + chr(code - 32)
        else
            res = res + c
        i = i + 1
    return res

fn str_upper s
    return upper(s)

// WHY: Converts uppercase ASCII characters (A-Z: 65-90) to lowercase (a-z: 97-122).
// Non-ASCII and already-lowercase characters pass through untouched.
fn lower s
    res = ""
    i = 0
    slen = len(s)
    while i < slen
        c = char_at(s, i)
        code = ord(c)
        if code >= 65 and code <= 90
            res = res + chr(code + 32)
        else
            res = res + c
        i = i + 1
    return res

fn str_lower s
    return lower(s)

// ── 2. Trimming & Whitespace Handling ────────────────────────────────────────

// WHY: Strips leading and trailing ASCII whitespace (spaces, tabs, newlines, carriage returns).
fn trim s
    slen = len(s)
    if slen == 0
        return ""
    start = 0
    while start < slen
        c = char_at(s, start)
        if c == " " or c == "\t" or c == "\n" or c == "\r"
            start = start + 1
        else
            break
    if start >= slen
        return ""
    end = slen - 1
    while end >= start
        c = char_at(s, end)
        if c == " " or c == "\t" or c == "\n" or c == "\r"
            end = end - 1
        else
            break
    res = ""
    i = start
    while i <= end
        res = res + char_at(s, i)
        i = i + 1
    return res

fn str_trim s
    return trim(s)

// ── 3. Substring Search & Inspection ─────────────────────────────────────────

// WHY: Returns the 0-based start index of first occurrence of sub in s, or -1 if not found.
fn index_of s sub
    slen = len(s)
    sublen = len(sub)
    if sublen == 0
        return 0
    if sublen > slen
        return -1
    limit = slen - sublen
    i = 0
    while i <= limit
        match = 1
        j = 0
        while j < sublen
            if char_at(s, i + j) != char_at(sub, j)
                match = 0
                j = sublen
            else
                j = j + 1
        if match == 1
            return i
        i = i + 1
    return -1

fn str_index_of s sub
    return index_of(s, sub)

// WHY: Returns 1 if s contains sub, 0 otherwise.
fn contains s sub
    if index_of(s, sub) >= 0
        return 1
    return 0

fn str_contains s sub
    return contains(s, sub)

// WHY: Returns 1 if string s starts with prefix, 0 otherwise.
fn starts_with s prefix
    slen = len(s)
    plen = len(prefix)
    if plen > slen
        return 0
    i = 0
    while i < plen
        if char_at(s, i) != char_at(prefix, i)
            return 0
        i = i + 1
    return 1

fn str_starts_with s prefix
    return starts_with(s, prefix)

fn str_starts prefix s
    return starts_with(s, prefix)

// WHY: Returns 1 if string s ends with suffix, 0 otherwise.
fn ends_with s suffix
    slen = len(s)
    flen = len(suffix)
    if flen > slen
        return 0
    offset = slen - flen
    i = 0
    while i < flen
        if char_at(s, offset + i) != char_at(suffix, i)
            return 0
        i = i + 1
    return 1

fn str_ends_with s suffix
    return ends_with(s, suffix)

// ── 4. Slicing & Extraction ──────────────────────────────────────────────────

// WHY: Extracts substring from [start, end) exclusive. Handles boundary clamps cleanly.
fn str_sub s start end
    slen = len(s)
    if start < 0
        start = 0
    if end > slen
        end = slen
    if start >= end
        return ""
    res = ""
    i = start
    while i < end
        res = res + char_at(s, i)
        i = i + 1
    return res

fn substring s start end
    return str_sub(s, start, end)

// ── 5. String Manipulation & Replacement ─────────────────────────────────────

// WHY: Replaces all occurrences of old_sub with new_sub throughout string s.
fn replace s old_sub new_sub
    slen = len(s)
    olen = len(old_sub)
    if olen == 0
        return s
    res = ""
    i = 0
    while i < slen
        if i + olen <= slen
            match = 1
            j = 0
            while j < olen
                if char_at(s, i + j) != char_at(old_sub, j)
                    match = 0
                    j = olen
                else
                    j = j + 1
            if match == 1
                res = res + new_sub
                i = i + olen
            else
                res = res + char_at(s, i)
                i = i + 1
        else
            res = res + char_at(s, i)
            i = i + 1
    return res

fn str_replace s old_sub new_sub
    return replace(s, old_sub, new_sub)

// WHY: Splits string s by whitespace into a list of word tokens.
fn split s
    res = list()
    slen = len(s)
    i = 0
    while i < slen
        while i < slen
            c = char_at(s, i)
            if c == " " or c == "\t" or c == "\n" or c == "\r"
                i = i + 1
            else
                break
        if i < slen
            word = ""
            while i < slen
                c = char_at(s, i)
                if c != " " and c != "\t" and c != "\n" and c != "\r"
                    word = word + c
                    i = i + 1
                else
                    break
            res = push(res, word)
    return res

fn str_split s
    return split(s)

// WHY: Splits string s by a specific delimiter string.
fn split_delim s delim
    res = list()
    slen = len(s)
    dlen = len(delim)
    if dlen == 0
        i = 0
        while i < slen
            res = push(res, char_at(s, i))
            i = i + 1
        return res
    cur = ""
    i = 0
    while i < slen
        if i + dlen <= slen
            match = 1
            j = 0
            while j < dlen
                if char_at(s, i + j) != char_at(delim, j)
                    match = 0
                    j = dlen
                else
                    j = j + 1
            if match == 1
                res = push(res, cur)
                cur = ""
                i = i + dlen
            else
                cur = cur + char_at(s, i)
                i = i + 1
        else
            cur = cur + char_at(s, i)
            i = i + 1
    res = push(res, cur)
    return res

// WHY: Joins a list of items into a single string separated by sep.
fn str_join sep items
    count = len(items)
    if count == 0
        return ""
    res = "" + get(items, 0)
    i = 1
    while i < count
        res = res + sep + get(items, i)
        i = i + 1
    return res

// ── 6. Repetition, Padding & Utilities ────────────────────────────────────────

// Repeat string n times
fn str_repeat s n
    result = ""
    i = 0
    while i < n
        result = result + s
        i = i + 1
    return result

fn chars n c
    return str_repeat(c, n)

// Pad string on left to given width
fn str_pad_left s width char
    pad = width - len(s)
    if pad <= 0
        return s
    return str_repeat(char, pad) + s

// Pad string on right to given width
fn str_pad_right s width char
    pad = width - len(s)
    if pad <= 0
        return s
    return s + str_repeat(char, pad)

// Center string in given width
fn str_center s width char
    pad = width - len(s)
    if pad <= 0
        return s
    left = pad / 2
    right = pad - left
    return str_repeat(char, left) + s + str_repeat(char, right)

// Convert number to string with sign
fn str_signed n
    if n > 0
        return "+" + str(n)
    return str(n)

// String is empty?
fn str_empty s
    if len(s) == 0
        return 1
    return 0

