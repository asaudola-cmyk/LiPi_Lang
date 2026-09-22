// ==============================================================================
// 👑 LIPI FIRST 1.0.0 FREESTANDING CORE SILICON PRIMITIVES: SPAN (src/core/span.lp)
// ⚡ 100% Pure Lipi Sovereign Implementation | Zero C | Zero Libc | Zero Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. High-precision diagnostic reporting, DWARF debug information, and IDE Language
//    Server Protocol (LSP) capabilities require tracking exact source coordinates.
// 2. Maintaining both byte offsets (start_byte, end_byte) and human-readable coordinates
//    (line, col) allows:
//    - O(1) zero-copy source text slicing directly from in-memory file buffers.
//    - Zero-overhead error formatting without rescanning file newlines during compilation.
// 3. Spans are lightweight 40-byte structs that seamlessly attach to AST nodes, tokens,
//    and IR instructions for end-to-end provenance tracking.
// ==============================================================================

struct Span
    file_id
    line
    col
    start_byte
    end_byte

// ── 1. Span Constructors & Factories ──────────────────────────────────────────

// WHY: Creates a canonical source span with full coordinates and boundary validation.
fn span_new(file_id, line, col, start_byte, end_byte)
    s = Span()
    s.file_id = file_id
    if line <= 0
        s.line = 1
    else
        s.line = line

    if col <= 0
        s.col = 1
    else
        s.col = col

    if start_byte < 0
        s.start_byte = 0
    else
        s.start_byte = start_byte

    // Enforce invariant: end_byte >= start_byte
    if end_byte < s.start_byte
        s.end_byte = s.start_byte
    else
        s.end_byte = end_byte

    return s

// WHY: Creates a zero-width point span representing an exact cursor position or insertion point.
fn span_point(file_id, line, col, byte_offset)
    return span_new(file_id, line, col, byte_offset, byte_offset)

// WHY: Creates an empty/dummy synthetic span for compiler-generated AST nodes and built-in intrinsics.
fn span_dummy()
    return span_new(0, 0, 0, 0, 0)

// WHY: Duplicates an existing span safely without pointer aliasing.
fn span_clone(s)
    if s == 0 return span_dummy()
    return span_new(s.file_id, s.line, s.col, s.start_byte, s.end_byte)

// ── 2. Span Validation & Introspection ────────────────────────────────────────

// WHY: Checks if the span represents a valid, non-dummy source location.
fn span_is_valid(s)
    if s == 0 return 0
    if s.file_id <= 0 return 0
    if s.line <= 0 or s.col <= 0 return 0
    if s.start_byte < 0 or s.end_byte < s.start_byte return 0
    return 1

// WHY: Checks whether the span has zero length (e.g. an insertion marker or empty token).
fn span_is_empty(s)
    if s == 0 return 1
    if s.end_byte <= s.start_byte return 1
    return 0

// WHY: Returns the byte length of the span (end_byte - start_byte).
fn span_len(s)
    if s == 0 return 0
    return s.end_byte - s.start_byte

// ── 3. Geometric Spatial Operations ───────────────────────────────────────────

// WHY: Combines two spans into a single enclosing span spanning from the earliest start
//      to the latest end. Essential for compound AST expressions (e.g. binary operators
//      where span(a + b) must encompass span(a) through span(b)).
fn span_combine(s1, s2)
    if s1 == 0 and s2 == 0 return span_dummy()
    if s1 == 0 return span_clone(s2)
    if s2 == 0 return span_clone(s1)

    // If one is a dummy span, prefer the valid one
    if s1.file_id == 0 return span_clone(s2)
    if s2.file_id == 0 return span_clone(s1)

    // Cannot combine spans across different physical source files
    if s1.file_id != s2.file_id
        return span_clone(s1)

    // Determine earliest start and corresponding line/col coordinates
    min_start = s1.start_byte
    earliest_line = s1.line
    earliest_col = s1.col

    if s2.start_byte < min_start
        min_start = s2.start_byte
        earliest_line = s2.line
        earliest_col = s2.col
    else
        if s2.start_byte == min_start
            if s2.line < earliest_line
                earliest_line = s2.line
                earliest_col = s2.col
            else
                if s2.line == earliest_line and s2.col < earliest_col
                    earliest_col = s2.col

    // Determine latest end
    max_end = s1.end_byte
    if s2.end_byte > max_end
        max_end = s2.end_byte

    return span_new(s1.file_id, earliest_line, earliest_col, min_start, max_end)

// WHY: Tests whether a given byte offset is strictly enclosed inside `[start_byte, end_byte)`.
fn span_contains_offset(s, byte_offset)
    if s == 0 return 0
    if byte_offset >= s.start_byte and byte_offset < s.end_byte
        return 1
    return 0

// WHY: Tests whether the child span is completely enclosed inside the parent span.
fn span_contains_span(parent, child)
    if parent == 0 or child == 0 return 0
    if parent.file_id != child.file_id return 0
    if child.start_byte >= parent.start_byte and child.end_byte <= parent.end_byte
        return 1
    return 0

// WHY: Tests whether two spans in the same source file overlap by at least 1 byte.
fn span_overlaps(s1, s2)
    if s1 == 0 or s2 == 0 return 0
    if s1.file_id != s2.file_id return 0
    if s1.start_byte < s2.end_byte and s2.start_byte < s1.end_byte
        return 1
    return 0

// ── 4. Formatting & Diagnostics ───────────────────────────────────────────────

// WHY: Generates a deterministic string representation for diagnostic logs.
//      Format: "file:<id>:<line>:<col> [<start>..<end>]"
fn span_format(s)
    if s == 0
        return "<null_span>"
    if s.file_id == 0
        return "<compiler_synthetic>"
    result = "file#" + str(s.file_id) + ":" + str(s.line) + ":" + str(s.col)
    result = result + " [" + str(s.start_byte) + ".." + str(s.end_byte) + "]"
    return result
