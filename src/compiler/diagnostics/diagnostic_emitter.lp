// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER DIAGNOSTICS: UNIFIED DIAGNOSTIC EMITTER
// ⚡ 100% Pure Lipi First 1.0.0 | Zero Libc | Zero C | Direct Silicon
// 🏛️ File: src/compiler/diagnostics/diagnostic_emitter.lp
//
// WHY: A sovereign compiler requires a single unified emission pipeline capable
//      of streaming rich, TrueColor-formatted terminal messages to human developers
//      and machine-readable JSON documents to IDEs, LSP servers (lipilsp),
//      and automated test harnesses.
// ==============================================================================

include "src/compiler/diagnostics/error_codes.lp"
include "src/compiler/diagnostics/source_map.lp"
include "src/compiler/diagnostics/color_theme.lp"
include "src/compiler/diagnostics/snippet_renderer.lp"
include "src/compiler/diagnostics/suggestion.lp"

// ── Diagnostic Label (Span Annotation) ───────────────────────────────────────
// WHY: Multiple source spans can be associated with a single diagnostic
//      (e.g. primary error site + secondary original declaration site).
//      Field is named 'label_text' to prevent collision with primary diagnostic 'message'.
struct DiagnosticLabel
    span
    label_text
    is_primary

fn diagnostic_label_new span label_text is_primary
    dl = DiagnosticLabel()
    dl.span = span
    dl.label_text = label_text
    dl.is_primary = is_primary
    return dl

// ── Diagnostic Record ────────────────────────────────────────────────────────
// WHY: Complete structured payload for a compiler diagnostic event.
struct Diagnostic
    code
    severity
    message
    labels
    notes
    helps
    suggestions

// WHY: Allocates and initializes an empty Diagnostic struct.
fn diagnostic_new code severity message
    d = Diagnostic()
    d.code = code
    d.severity = severity
    d.message = message
    d.labels = list()
    d.notes = list()
    d.helps = list()
    d.suggestions = list()
    return d

// WHY: Convenience constructor with a single primary source span.
fn diagnostic_new_at_span code severity message span label_text
    d = diagnostic_new(code, severity, message)
    push(d.labels, diagnostic_label_new(span, label_text, 1))
    return d

// WHY: Adds an annotated source span to the diagnostic.
fn diagnostic_add_label d span label_text is_primary
    push(d.labels, diagnostic_label_new(span, label_text, is_primary))
    return d

// WHY: Adds an informational note line (e.g. "note: consider importing module").
fn diagnostic_add_note d note_msg
    push(d.notes, note_msg)
    return d

// WHY: Adds an actionable help line (e.g. "help: remove extraneous parameter").
fn diagnostic_add_help d help_msg
    push(d.helps, help_msg)
    return d

// WHY: Adds a spelling suggestion (e.g. "did you mean 'count'?").
fn diagnostic_add_suggestion d suggestion_msg
    push(d.suggestions, suggestion_msg)
    return d

// WHY: Retrieves the primary label from a diagnostic. If no label is explicitly
//      marked primary, falls back to the first available label. Returns 0 if none.
fn diagnostic_primary_label d
    n = len(d.labels)
    if n == 0
        return 0

    i = 0
    while i < n
        l = d.labels[i]
        if l.is_primary == 1
            return l
        i = i + 1

    return d.labels[0]

// ── JSON String Escaping Primitive ───────────────────────────────────────────
// WHY: 100% pure Lipi string escaper for generating valid RFC 8259 JSON output
//      without relying on external C or libc libraries.
fn json_escape_str s
    slen = len(s)
    if slen == 0
        return ""

    out = ""
    i = 0
    while i < slen
        ch = char_at(s, i)
        code = ord(ch)

        if code == 34
            out = out + "\\\""
        elif code == 92
            out = out + "\\\\"
        elif code == 10
            out = out + "\\n"
        elif code == 13
            out = out + "\\r"
        elif code == 9
            out = out + "\\t"
        elif code < 32
            // Control character
            out = out + " "
        else
            out = out + ch
        i = i + 1
    return out

// ── Unified Diagnostic Emitter Container ─────────────────────────────────────
// WHY: Tracks accumulated compilation errors, active source map, and output format.
struct DiagnosticEmitter
    source_map
    error_catalog
    theme
    output_format
    error_count
    warning_count
    note_count
    diagnostics
    rendered_outputs

// WHY: Allocates a new DiagnosticEmitter instance.
fn diagnostic_emitter_new source_map format color_enabled
    em = DiagnosticEmitter()
    em.source_map = source_map
    em.error_catalog = error_catalog_init()
    em.theme = color_theme_new(color_enabled, 1)
    em.output_format = format
    em.error_count = 0
    em.warning_count = 0
    em.note_count = 0
    em.diagnostics = list()
    em.rendered_outputs = list()
    return em

// WHY: Switches output format between "terminal" and "json".
fn diagnostic_emitter_set_format em format
    if em != 0
        em.output_format = format

// WHY: Dynamically enables or disables TrueColor terminal styling.
fn diagnostic_emitter_set_color em enabled
    if em != 0 and em.theme != 0
        color_theme_set_enabled(em.theme, enabled)

// ── Terminal Output Serializer ───────────────────────────────────────────────
// WHY: Formats a complete diagnostic into terminal-ready human-readable text.
fn diagnostic_emit_terminal em d
    ct = em.theme
    sm = em.source_map
    opt = snippet_options_default()

    // Determine primary location
    file_path = "<unknown>"
    line = 1
    col = 1
    p_label = diagnostic_primary_label(d)
    if p_label != 0 and p_label.span != 0
        span = p_label.span
        sf = source_map_get_file(sm, span.file_id)
        if sf != 0
            file_path = sf.path
        line = span.start_line
        col = span.start_col

    // 1. Render Header
    out = snippet_render_header(d.severity, d.code, d.message, file_path, line, col, ct) + "\n"

    // 2. Render Snippets for each associated label
    n_labels = len(d.labels)
    li = 0
    while li < n_labels
        lbl = d.labels[li]
        snippet_text = snippet_render(sm, lbl.span, lbl.label_text, lbl.is_primary, ct, opt)
        if len(snippet_text) > 0
            out = out + snippet_text + "\n"
        li = li + 1

    gutter_indent = "   = "

    // 3. Render Notes
    n_notes = len(d.notes)
    ni = 0
    while ni < n_notes
        note_str = d.notes[ni]
        note_badge = color_theme_note(ct) + "note: " + color_theme_reset(ct)
        out = out + gutter_indent + note_badge + note_str + "\n"
        ni = ni + 1

    // 4. Render Helps
    n_helps = len(d.helps)
    hi = 0
    while hi < n_helps
        help_str = d.helps[hi]
        help_badge = color_theme_hint(ct) + "help: " + color_theme_reset(ct)
        out = out + gutter_indent + help_badge + help_str + "\n"
        hi = hi + 1

    // 5. Render Suggestions
    n_suggs = len(d.suggestions)
    si = 0
    while si < n_suggs
        sugg_str = d.suggestions[si]
        sugg_badge = color_theme_hint(ct) + "suggestion: " + color_theme_reset(ct)
        out = out + gutter_indent + sugg_badge + sugg_str + "\n"
        si = si + 1

    return out

// ── JSON Output Serializer ───────────────────────────────────────────────────
// WHY: Formats a diagnostic into standard machine-readable JSON for tooling / LSP.
fn diagnostic_emit_json em d
    sm = em.source_map

    out = "{\n"
    out = out + "  \"code\": \"" + json_escape_str(d.code) + "\",\n"
    out = out + "  \"severity\": \"" + json_escape_str(d.severity) + "\",\n"
    out = out + "  \"message\": \"" + json_escape_str(d.message) + "\",\n"

    // Primary location
    p_label = diagnostic_primary_label(d)
    file_path = "<unknown>"
    line = 1
    col = 1
    s_byte = 0
    e_byte = 0

    if p_label != 0 and p_label.span != 0
        sp = p_label.span
        sf = source_map_get_file(sm, sp.file_id)
        if sf != 0
            file_path = sf.path
        line = sp.start_line
        col = sp.start_col
        s_byte = sp.start_byte
        e_byte = sp.end_byte

    out = out + "  \"primary_location\": {\n"
    out = out + "    \"file\": \"" + json_escape_str(file_path) + "\",\n"
    out = out + "    \"line\": " + str(line) + ",\n"
    out = out + "    \"column\": " + str(col) + ",\n"
    out = out + "    \"start_byte\": " + str(s_byte) + ",\n"
    out = out + "    \"end_byte\": " + str(e_byte) + "\n"
    out = out + "  },\n"

    // Labels array
    out = out + "  \"labels\": ["
    n_labels = len(d.labels)
    li = 0
    while li < n_labels
        lbl = d.labels[li]
        l_sp = lbl.span
        l_file = file_path
        l_sline = 1
        l_scol = 1
        l_eline = 1
        l_ecol = 1
        l_sbyte = 0
        l_ebyte = 0

        if l_sp != 0
            l_sf = source_map_get_file(sm, l_sp.file_id)
            if l_sf != 0
                l_file = l_sf.path
            l_sline = l_sp.start_line
            l_scol = l_sp.start_col
            l_eline = l_sp.end_line
            l_ecol = l_sp.end_col
            l_sbyte = l_sp.start_byte
            l_ebyte = l_sp.end_byte

        is_prim_str = "false"
        if lbl.is_primary == 1
            is_prim_str = "true"

        out = out + "\n    {\n"
        out = out + "      \"file\": \"" + json_escape_str(l_file) + "\",\n"
        out = out + "      \"line_start\": " + str(l_sline) + ",\n"
        out = out + "      \"col_start\": " + str(l_scol) + ",\n"
        out = out + "      \"line_end\": " + str(l_eline) + ",\n"
        out = out + "      \"col_end\": " + str(l_ecol) + ",\n"
        out = out + "      \"start_byte\": " + str(l_sbyte) + ",\n"
        out = out + "      \"end_byte\": " + str(l_ebyte) + ",\n"
        out = out + "      \"is_primary\": " + is_prim_str + ",\n"
        out = out + "      \"message\": \"" + json_escape_str(lbl.label_text) + "\"\n"
        out = out + "    }"

        if li < n_labels - 1
            out = out + ","
        li = li + 1

    if n_labels > 0
        out = out + "\n  "
    out = out + "],\n"

    // Notes array
    out = out + "  \"notes\": ["
    n_notes = len(d.notes)
    ni = 0
    while ni < n_notes
        out = out + "\"" + json_escape_str(d.notes[ni]) + "\""
        if ni < n_notes - 1
            out = out + ", "
        ni = ni + 1
    out = out + "],\n"

    // Helps array
    out = out + "  \"helps\": ["
    n_helps = len(d.helps)
    hi = 0
    while hi < n_helps
        out = out + "\"" + json_escape_str(d.helps[hi]) + "\""
        if hi < n_helps - 1
            out = out + ", "
        hi = hi + 1
    out = out + "],\n"

    // Suggestions array
    out = out + "  \"suggestions\": ["
    n_suggs = len(d.suggestions)
    si = 0
    while si < n_suggs
        out = out + "\"" + json_escape_str(d.suggestions[si]) + "\""
        if si < n_suggs - 1
            out = out + ", "
        si = si + 1
    out = out + "]\n"

    out = out + "}"
    return out

// ── Complete JSON Batch Serializer ───────────────────────────────────────────
// WHY: Wraps all emitted diagnostics into a top-level compilation report.
fn diagnostic_emitter_render_all_json em
    out = "{\n"
    out = out + "  \"summary\": {\n"
    out = out + "    \"error_count\": " + str(em.error_count) + ",\n"
    out = out + "    \"warning_count\": " + str(em.warning_count) + ",\n"
    out = out + "    \"note_count\": " + str(em.note_count) + ",\n"

    has_err_str = "false"
    if em.error_count > 0
        has_err_str = "true"
    out = out + "    \"has_errors\": " + has_err_str + "\n"
    out = out + "  },\n"

    out = out + "  \"diagnostics\": [\n"
    n_diags = len(em.diagnostics)
    di = 0
    while di < n_diags
        d = em.diagnostics[di]
        d_json = diagnostic_emit_json(em, d)
        out = out + d_json
        if di < n_diags - 1
            out = out + ",\n"
        else
            out = out + "\n"
        di = di + 1
    out = out + "  ]\n"
    out = out + "}"
    return out

// ── Primary Emission Pipeline ────────────────────────────────────────────────
// WHY: Ingests a Diagnostic, updates compiler issue statistics, serializes output,
//      and caches rendered output strings.
fn diagnostic_emitter_emit em d
    if em == 0 or d == 0
        return ""

    // Update severity metrics
    if d.severity == "error"
        em.error_count = em.error_count + 1
    elif d.severity == "warning"
        em.warning_count = em.warning_count + 1
    elif d.severity == "note"
        em.note_count = em.note_count + 1

    push(em.diagnostics, d)

    rendered = ""
    if em.output_format == "json"
        rendered = diagnostic_emit_json(em, d)
    else
        rendered = diagnostic_emit_terminal(em, d)

    push(em.rendered_outputs, rendered)
    return rendered

// ── Query Emitter State ──────────────────────────────────────────────────────
// WHY: Informs compiler driver whether compilation must abort due to errors.
fn diagnostic_emitter_has_errors em
    if em == 0
        return 0
    if em.error_count > 0
        return 1
    return 0

// WHY: Generates final summary line for compiler terminal banner.
fn diagnostic_emitter_summary em
    if em == 0
        return "compilation completed with 0 errors"

    if em.error_count == 0
        if em.warning_count == 0
            return "compilation completed successfully with 0 errors"
        if em.warning_count == 1
            return "compilation completed with 1 warning"
        return "compilation completed with " + str(em.warning_count) + " warnings"

    err_str = "error"
    if em.error_count > 1
        err_str = "errors"

    warn_part = ""
    if em.warning_count > 0
        warn_str = "warning"
        if em.warning_count > 1
            warn_str = "warnings"
        warn_part = " (" + str(em.warning_count) + " " + warn_str + ")"

    return "error: could not compile due to " + str(em.error_count) + " previous " + err_str + warn_part
