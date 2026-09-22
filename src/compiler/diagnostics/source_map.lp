// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER DIAGNOSTICS: SOURCE MAP & MULTI-FILE REGISTRY
// ⚡ 100% Pure Lipi First 1.0.0 | Zero Libc | Zero C | Direct Silicon
// 🏛️ File: src/compiler/diagnostics/source_map.lp
//
// WHY: Modern multi-file compilation pipelines (modules, imports, macros) need
//      a centralized registry that assigns compact integer file IDs to source files,
//      caches in-memory buffers to avoid re-reading disk on every diagnostic,
//      and maps byte-spans to exact source locations.
// ==============================================================================

include "src/compiler/diagnostics/line_index.lp"

// ── Source File Representation ───────────────────────────────────────────────
// WHY: Encapsulates file identity, storage buffer, and its cached line index.
struct SourceFile
    file_id
    path
    content
    length
    line_index

// WHY: Allocates a new SourceFile and immediately pre-indexes its newline offsets.
fn source_file_new file_id path content
    sf = SourceFile()
    sf.file_id = file_id
    sf.path = path
    sf.content = content
    sf.length = len(content)
    sf.line_index = line_index_build(content)
    return sf

// ── Source Span Representation ───────────────────────────────────────────────
// WHY: Fully describes a half-open byte range [start_byte, end_byte) in a specific
//      source file, accompanied by cached 1-indexed (line, col) coordinates.
//      Renamed to SourceMapSpan to eliminate symbol collision with frontend Token SourceSpan.
struct SourceMapSpan
    file_id
    start_byte
    end_byte
    start_line
    start_col
    end_line
    end_col

// WHY: Explicit constructor for fully-populated SourceMapSpan.
fn source_map_span_new file_id start_byte end_byte start_line start_col end_line end_col
    sp = SourceMapSpan()
    sp.file_id = file_id
    sp.start_byte = start_byte
    sp.end_byte = end_byte
    sp.start_line = start_line
    sp.start_col = start_col
    sp.end_line = end_line
    sp.end_col = end_col
    return sp

// ── Source Map Multi-File Registry ───────────────────────────────────────────
// WHY: Dynamic registry holding all active compilation source buffers in memory.
struct SourceMap
    files
    count

// WHY: Creates an empty SourceMap registry.
fn source_map_new
    sm = SourceMap()
    sm.files = list()
    sm.count = 0
    return sm

// WHY: Finds an existing file by exact file path string. Returns file_id or -1.
fn source_map_find_by_path sm path
    if sm == 0
        return -1
    n = sm.count
    i = 0
    while i < n
        f = sm.files[i]
        if f.path == path
            return f.file_id
        i = i + 1
    return -1

// WHY: Registers a file buffer into the registry. If the path was already registered,
//      returns existing file_id without duplicate allocation.
fn source_map_add_file sm path content
    existing_id = source_map_find_by_path(sm, path)
    if existing_id >= 0
        return existing_id

    file_id = sm.count
    sf = source_file_new(file_id, path, content)
    push(sm.files, sf)
    sm.count = sm.count + 1
    return file_id

// WHY: Loads a source file directly from the filesystem using sovereign file_read intrinsic.
//      Returns file_id on success, or -1 if the file does not exist.
fn source_map_load_file sm path
    if file_exists(path) == 0
        return -1
    content = file_read(path)
    return source_map_add_file(sm, path, content)

// WHY: Retrieves SourceFile descriptor by integer file ID. Returns 0 if invalid ID.
fn source_map_get_file sm file_id
    if sm == 0 or file_id < 0 or file_id >= sm.count
        return 0
    return sm.files[file_id]

// WHY: Returns number of registered source files.
fn source_map_file_count sm
    if sm == 0
        return 0
    return sm.count

// ── Span Constructors with Automatic Coordinate Computation ──────────────────
// WHY: Automatically derives 1-indexed (line, col) from raw byte offsets using
//      the precomputed LineIndex binary search.
fn source_span_from_offsets sm file_id start_byte end_byte
    sf = source_map_get_file(sm, file_id)
    if sf == 0
        return source_map_span_new(file_id, start_byte, end_byte, 1, 1, 1, 1)

    // WHY: Ensure start_byte <= end_byte
    s_byte = start_byte
    e_byte = end_byte
    if s_byte > e_byte
        tmp = s_byte
        s_byte = e_byte
        e_byte = tmp

    // Clamp to valid buffer boundaries
    if s_byte < 0
        s_byte = 0
    if e_byte > sf.length
        e_byte = sf.length

    start_pos = line_index_lookup(sf.line_index, s_byte)
    end_pos = line_index_lookup(sf.line_index, e_byte)

    return source_map_span_new(
        file_id,
        s_byte,
        e_byte,
        start_pos.line,
        start_pos.col,
        end_pos.line,
        end_pos.col
    )

// WHY: Constructs a zero-width point span at a single byte offset in a SourceMap.
fn source_map_span_point sm file_id byte_offset
    return source_span_from_offsets(sm, file_id, byte_offset, byte_offset)

// WHY: Combines two spans into their minimal enclosing bounding span.
//      Used when uniting sub-expressions into a parent AST node span.
fn source_span_combine span_a span_b
    if span_a == 0
        return span_b
    if span_b == 0
        return span_a
    if span_a.file_id != span_b.file_id
        return span_a

    s_byte = span_a.start_byte
    if span_b.start_byte < s_byte
        s_byte = span_b.start_byte

    e_byte = span_a.end_byte
    if span_b.end_byte > e_byte
        e_byte = span_b.end_byte

    s_line = span_a.start_line
    s_col = span_a.start_col
    if span_b.start_line < s_line or (span_b.start_line == s_line and span_b.start_col < s_col)
        s_line = span_b.start_line
        s_col = span_b.start_col

    e_line = span_a.end_line
    e_col = span_a.end_col
    if span_b.end_line > e_line or (span_b.end_line == e_line and span_b.end_col > e_col)
        e_line = span_b.end_line
        e_col = span_b.end_col

    return source_map_span_new(
        span_a.file_id,
        s_byte,
        e_byte,
        s_line,
        s_col,
        e_line,
        e_col
    )

// ── Text Extraction & Location Formatting ────────────────────────────────────
// WHY: Extracts the exact raw substring of code corresponding to the given span.
fn source_map_get_span_text sm span
    if sm == 0 or span == 0
        return ""

    sf = source_map_get_file(sm, span.file_id)
    if sf == 0
        return ""

    s_byte = span.start_byte
    e_byte = span.end_byte
    if s_byte < 0
        s_byte = 0
    if e_byte > sf.length
        e_byte = sf.length
    if s_byte >= e_byte
        return ""

    return str_slice(sf.content, s_byte, e_byte)

// WHY: Formats canonical location reference string: "path/to/file.lp:line:col".
fn source_span_format_location sm span
    if sm == 0 or span == 0
        return "<unknown>:1:1"

    sf = source_map_get_file(sm, span.file_id)
    file_path = "<unknown>"
    if sf != 0
        file_path = sf.path

    return file_path + ":" + str(span.start_line) + ":" + str(span.start_col)

// WHY: Checks whether a span covers more than one line.
fn source_span_is_multiline span
    if span == 0
        return 0
    if span.start_line != span.end_line
        return 1
    return 0

// WHY: Checks whether a span has zero length.
fn source_span_is_empty span
    if span == 0
        return 1
    if span.start_byte == span.end_byte
        return 1
    return 0
