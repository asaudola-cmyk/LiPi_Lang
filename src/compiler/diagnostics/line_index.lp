// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER DIAGNOSTICS: SOURCE LINE INDEX & BINARY SEARCH
// ⚡ 100% Pure Lipi First 1.0.0 | Zero Libc | Zero C | Direct Silicon
// 🏛️ File: src/compiler/diagnostics/line_index.lp
//
// WHY: Source positions during lexing/parsing are tracked as absolute 0-indexed
//      byte offsets. Displaying compiler diagnostics requires converting byte
//      offsets into 1-indexed (line, column) tuples and slicing line snippets.
//      A precomputed line index enables fast O(log N) binary search lookup
//      without rescanning the source buffer.
// ==============================================================================

// ── Line & Column Position Descriptor ────────────────────────────────────────
// WHY: Encapsulates human-readable 1-indexed line and column coordinates.
struct LineCol
    line
    col

fn line_col_new line col
    lc = LineCol()
    lc.line = line
    lc.col = col
    return lc

// ── Line Byte Span Descriptor ────────────────────────────────────────────────
// WHY: Identifies the byte boundaries [start_byte, end_byte) of a line in the buffer.
struct LineSpan
    line
    start_byte
    end_byte

fn line_span_new line start_byte end_byte
    ls = LineSpan()
    ls.line = line
    ls.start_byte = start_byte
    ls.end_byte = end_byte
    return ls

// ── Line Index Container ─────────────────────────────────────────────────────
// WHY: Stores sequential starting byte offsets for every line in the source file.
//      Memory footprint is exactly 1 integer per line.
struct LineIndex
    line_starts
    line_count
    source_len

// WHY: Creates an empty LineIndex struct.
fn line_index_create
    li = LineIndex()
    li.line_starts = list()
    li.line_count = 0
    li.source_len = 0
    return li

// ── Line Index Builder ───────────────────────────────────────────────────────
// WHY: Single-pass linear scan O(N) records the start offset of every newline.
//      Handles Unix LF (\n), Windows CRLF (\r\n), empty buffers, and trailing newlines.
fn line_index_build source_text
    li = line_index_create()
    slen = len(source_text)
    li.source_len = slen

    // WHY: Line 1 always begins at byte offset 0, even in an empty file.
    push(li.line_starts, 0)
    li.line_count = 1

    if slen == 0
        return li

    p = 0
    while p < slen
        ch = char_at(source_text, p)
        if ch == "\n"
            // Next line starts immediately after the LF byte
            push(li.line_starts, p + 1)
            li.line_count = li.line_count + 1
        p = p + 1

    return li

// ── Binary Search Byte Offset -> (Line, Col) ─────────────────────────────────
// WHY: O(log L) binary search finds the greatest line start offset <= target byte offset.
//      Col is computed in O(1) via (byte_offset - line_start) + 1.
fn line_index_lookup li byte_offset
    if li == 0
        return line_col_new(1, 1)

    // WHY: Clamp byte offset to valid range [0, source_len] to prevent negative or OOB indexing
    target = byte_offset
    if target < 0
        target = 0
    if target > li.source_len
        target = li.source_len

    // Binary search across line_starts array
    low = 0
    high = li.line_count - 1
    best_idx = 0

    while low <= high
        mid = (low + high) / 2
        start_off = li.line_starts[mid]

        if start_off <= target
            best_idx = mid
            low = mid + 1
        else
            high = mid - 1

    line_num = best_idx + 1
    line_start = li.line_starts[best_idx]
    col_num = (target - line_start) + 1

    return line_col_new(line_num, col_num)

// ── Extract Line Byte Span ───────────────────────────────────────────────────
// WHY: Returns start and end byte offsets of the given 1-indexed line number,
//      stripping trailing \r and \n characters so only printable line text remains.
fn line_index_get_line_span li source_text line_num
    if li == 0 or line_num < 1 or line_num > li.line_count
        return line_span_new(0, 0, 0)

    idx = line_num - 1
    start_byte = li.line_starts[idx]

    // Determine end byte offset
    if line_num < li.line_count
        raw_end = li.line_starts[line_num]
    else
        raw_end = li.source_len

    end_byte = raw_end

    // Strip trailing \n
    if end_byte > start_byte and char_at(source_text, end_byte - 1) == "\n"
        end_byte = end_byte - 1

    // Strip trailing \r (CRLF normalization)
    if end_byte > start_byte and char_at(source_text, end_byte - 1) == "\r"
        end_byte = end_byte - 1

    return line_span_new(line_num, start_byte, end_byte)

// ── Extract Line String Snippet ──────────────────────────────────────────────
// WHY: Returns the raw text string of the line, guaranteed free of trailing newlines.
fn line_index_get_line_text li source_text line_num
    if li == 0 or line_num < 1 or line_num > li.line_count
        return ""

    span = line_index_get_line_span(li, source_text, line_num)
    if span.end_byte <= span.start_byte
        return ""

    return str_slice(source_text, span.start_byte, span.end_byte)

// ── Query Total Line Count ───────────────────────────────────────────────────
// WHY: Returns total lines recorded for the indexed source file.
fn line_index_line_count li
    if li == 0
        return 0
    return li.line_count

// ── Visual Column Expansion (Tab Alignment) ──────────────────────────────────
// WHY: Tab characters ('\t') occupy 1 byte in source files but expand to multiple
//      spaces in terminal output. This function translates byte column to visual
//      screen column for pixel-perfect caret ('^') positioning.
fn line_index_visual_column line_text byte_col tab_width
    if tab_width <= 0
        tab_width = 4

    visual_col = 1
    limit = byte_col - 1
    tlen = len(line_text)
    if limit > tlen
        limit = tlen

    i = 0
    while i < limit
        ch = char_at(line_text, i)
        if ch == "\t"
            rem = (visual_col - 1) % tab_width
            visual_col = visual_col + (tab_width - rem)
        else
            visual_col = visual_col + 1
        i = i + 1

    return visual_col
