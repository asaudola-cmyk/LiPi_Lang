// ==============================================================================
// 🧪 LIPI TEST SUITE: COMPILER DIAGNOSTICS & SOURCE SPAN SUBSYSTEM
// ⚡ 100% Pure Lipi First 1.0.0 | Zero Libc | Zero C | Direct Silicon
// 🏛️ File: tests/test_diagnostics.lp
//
// WHY: Validates all 7 modular components of the enterprise diagnostics engine:
//      1. Error Code Catalog (E0001..E0903)
//      2. Source Map & Multi-File Registry
//      3. Line Index & Binary Search
//      4. ANSI TrueColor 24-bit Theme Engine
//      5. Terminal Snippet Renderer with Carets ('^^^')
//      6. Levenshtein Spelling Suggester ("Did you mean '...'?")
//      7. Unified Diagnostic Emitter (Terminal + JSON)
// ==============================================================================

include "src/compiler/frontend/lexer/token.lp"
include "src/compiler/diagnostics/mod.lp"

// ── Test Assertion Helpers ───────────────────────────────────────────────────
fn assert_true val name
    if val != 1
        say "  ❌ FAILED: " + name + " (expected 1, got " + str(val) + ")"
        exit(1)
    say "  ✔ PASS: " + name

fn assert_eq_int actual expected name
    if actual != expected
        say "  ❌ FAILED: " + name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ PASS: " + name

fn assert_eq_str actual expected name
    if actual != expected
        say "  ❌ FAILED: " + name
        say "     Expected: '" + expected + "'"
        say "     Actual:   '" + actual + "'"
        exit(1)
    say "  ✔ PASS: " + name

// ── Test 1: Error Codes Catalog ──────────────────────────────────────────────
fn test_error_codes
    say "--- 1. Testing Error Codes Catalog ---"
    cat = error_catalog_init()
    assert_true(cat.count >= 30, "Catalog has >= 30 registered error codes")

    // E0001 lookup
    e1 = error_catalog_find(cat, "E0001")
    assert_true(e1 != 0, "Found E0001 in catalog")
    assert_eq_str(e1.name, "UnexpectedToken", "E0001 name is UnexpectedToken")
    assert_eq_str(e1.category, "Syntax", "E0001 category is Syntax")
    assert_eq_str(e1.default_severity, "error", "E0001 severity is error")
    assert_eq_str(error_code_format_badge(e1), "error[E0001]", "E0001 badge format")
    assert_eq_str(error_code_format_title(e1), "E0001: UnexpectedToken", "E0001 title format")

    // E0101 lookup
    e101 = error_catalog_find(cat, "E0101")
    assert_true(e101 != 0, "Found E0101 in catalog")
    assert_eq_str(e101.name, "TypeMismatch", "E0101 name is TypeMismatch")

    // E0201 lookup
    e201 = error_catalog_find(cat, "E0201")
    assert_true(e201 != 0, "Found E0201 in catalog")
    assert_eq_str(e201.name, "UndefinedSymbol", "E0201 name is UndefinedSymbol")

    // Unknown code lookup returns 0
    e_unknown = error_catalog_find(cat, "E9999")
    assert_true(e_unknown == 0, "Unknown code returns 0")
    return 0

// ── Test 2: Line Index & Binary Search ───────────────────────────────────────
fn test_line_index
    say "--- 2. Testing Line Index & Binary Search ---"
    src = "fn main\n    x = 10\n    say x\n"
    li = line_index_build(src)

    // Total lines: line 1 ("fn main"), line 2 ("    x = 10"), line 3 ("    say x"), line 4 ("")
    assert_eq_int(li.line_count, 4, "Line count is 4")

    // Check line 1 start (offset 0)
    pos0 = line_index_lookup(li, 0)
    assert_eq_int(pos0.line, 1, "Offset 0 is line 1")
    assert_eq_int(pos0.col, 1, "Offset 0 is col 1")

    // Check line 2: offset 8 is ' ' in "    x = 10"
    pos8 = line_index_lookup(li, 8)
    assert_eq_int(pos8.line, 2, "Offset 8 is line 2")
    assert_eq_int(pos8.col, 1, "Offset 8 is col 1")

    // Check offset 12 is 'x' in line 2
    pos12 = line_index_lookup(li, 12)
    assert_eq_int(pos12.line, 2, "Offset 12 is line 2")
    assert_eq_int(pos12.col, 5, "Offset 12 is col 5")

    // Line text extraction
    line1_txt = line_index_get_line_text(li, src, 1)
    assert_eq_str(line1_txt, "fn main", "Line 1 text")

    line2_txt = line_index_get_line_text(li, src, 2)
    assert_eq_str(line2_txt, "    x = 10", "Line 2 text")

    line3_txt = line_index_get_line_text(li, src, 3)
    assert_eq_str(line3_txt, "    say x", "Line 3 text")

    // Tab expansion
    tab_line = "\tx = 1"
    vcol = line_index_visual_column(tab_line, 2, 4)
    assert_eq_int(vcol, 5, "Visual column after 1 tab is 5")

    return 0

// ── Test 3: Source Map & Multi-File Registry ─────────────────────────────────
fn test_source_map
    say "--- 3. Testing Source Map & Multi-File Registry ---"
    sm = source_map_new()

    file_a = "fn add a b\n    return a + b\n"
    file_b = "fn mul a b\n    return a * b\n"

    id_a = source_map_add_file(sm, "src/math/add.lp", file_a)
    id_b = source_map_add_file(sm, "src/math/mul.lp", file_b)

    assert_eq_int(id_a, 0, "File A id is 0")
    assert_eq_int(id_b, 1, "File B id is 1")
    assert_eq_int(source_map_file_count(sm), 2, "SourceMap has 2 files")

    // Deduplication test
    id_a_dup = source_map_add_file(sm, "src/math/add.lp", file_a)
    assert_eq_int(id_a_dup, 0, "Duplicate add returns existing ID 0")
    assert_eq_int(source_map_file_count(sm), 2, "Count remains 2 after duplicate")

    // Span from offsets
    // In file_a, "add" is at offsets 3..6
    span_add = source_span_from_offsets(sm, id_a, 3, 6)
    assert_eq_int(span_add.start_line, 1, "span_add start line is 1")
    assert_eq_int(span_add.start_col, 4, "span_add start col is 4")
    assert_eq_int(span_add.end_line, 1, "span_add end line is 1")
    assert_eq_int(span_add.end_col, 7, "span_add end col is 7")

    // Span text extraction
    span_txt = source_map_get_span_text(sm, span_add)
    assert_eq_str(span_txt, "add", "Extracted span text is 'add'")

    // Span location formatting
    loc_str = source_span_format_location(sm, span_add)
    assert_eq_str(loc_str, "src/math/add.lp:1:4", "Location string format")

    // Combining spans
    span1 = source_span_new(id_a, 0, 2, 1, 1, 1, 3)
    span2 = source_span_new(id_a, 7, 10, 1, 8, 1, 11)
    comb = source_span_combine(span1, span2)
    assert_eq_int(comb.start_byte, 0, "Combined start byte is 0")
    assert_eq_int(comb.end_byte, 10, "Combined end byte is 10")

    return 0

// ── Test 4: ANSI TrueColor Theme Engine ──────────────────────────────────────
fn test_color_theme
    say "--- 4. Testing ANSI TrueColor Theme Engine ---"
    ct_color = color_theme_new(1, 1)
    ct_plain = color_theme_plain()

    // Color theme active produces ANSI codes
    err_code = color_theme_error(ct_color)
    assert_true(len(err_code) > 0, "Error code sequence non-empty when enabled")

    // Plain theme produces empty string
    err_plain = color_theme_error(ct_plain)
    assert_eq_str(err_plain, "", "Error code sequence empty when disabled")

    // Format helper
    styled = color_theme_format(ct_color, color_theme_error(ct_color), "test")
    assert_true(len(styled) > 4, "Styled text has escape codes")

    // Strip ANSI escape sequences
    clean = color_theme_strip_ansi(styled)
    assert_eq_str(clean, "test", "Stripped ANSI recovers original plain text")

    return 0

// ── Test 5: Terminal Snippet Renderer ────────────────────────────────────────
fn test_snippet_renderer
    say "--- 5. Testing Terminal Snippet Renderer ---"
    sm = source_map_new()
    code = "fn calculate a b\n    val = a + * b\n    return val\n"
    fid = source_map_add_file(sm, "test_calc.lp", code)

    // Offending token is '*' at line 2, col 15 in "    val = a + * b"
    // Line 1 is 0..16 ("fn calculate a b\n")
    // Line 2 starts at offset 17:
    // ' ' is 17, ' ' is 18, ' ' is 19, ' ' is 20
    // 'v' is 21, 'a' is 22, 'l' is 23, ' ' is 24, '=' is 25, ' ' is 26, 'a' is 27, ' ' is 28, '+' is 29, ' ' is 30
    // '*' is 31, ' ' is 32, 'b' is 33
    span_star = source_span_from_offsets(sm, fid, 31, 32)
    assert_eq_int(span_star.start_line, 2, "span_star line is 2")
    assert_eq_int(span_star.start_col, 15, "span_star col is 15")

    ct_plain = color_theme_plain()
    opt = snippet_options_default()

    header = snippet_render_header("error", "E0001", "unexpected token '*'", "test_calc.lp", 2, 15, ct_plain)
    assert_true(len(header) > 0, "Rendered header is non-empty")

    snippet = snippet_render(sm, span_star, "unexpected operator", 1, ct_plain, opt)
    assert_true(len(snippet) > 0, "Rendered snippet is non-empty")
    say "Sample Rendered Terminal Output (Plain):"
    say header
    say snippet

    return 0

// ── Test 6: Levenshtein Spelling Suggester ────────────────────────────────────
fn test_suggestion
    say "--- 6. Testing Levenshtein Spelling Suggester ---"

    // Exact match
    assert_eq_int(levenshtein_distance("hello", "hello"), 0, "Distance('hello', 'hello') == 0")

    // 1 deletion: "helo" -> "hello"
    assert_eq_int(levenshtein_distance("helo", "hello"), 1, "Distance('helo', 'hello') == 1")

    // 1 substitution: "kat" -> "cat"
    assert_eq_int(levenshtein_distance("kat", "cat"), 1, "Distance('kat', 'cat') == 1")

    // 2 edits: "kitten" -> "sitting" (k->s, e->i, +g = 3)
    assert_eq_int(levenshtein_distance("kitten", "sitting"), 3, "Distance('kitten', 'sitting') == 3")

    // Case-insensitive distance: "Point" vs "point"
    assert_eq_int(levenshtein_distance_ci("Point", "point"), 0, "DistanceCI('Point', 'point') == 0")

    // Candidate lookup
    keywords = list()
    push(keywords, "struct")
    push(keywords, "function")
    push(keywords, "return")
    push(keywords, "import")
    push(keywords, "while")

    best1 = suggestion_find_best("retrun", keywords)
    assert_eq_str(best1, "return", "Suggests 'return' for 'retrun'")

    best2 = suggestion_find_best("strut", keywords)
    assert_eq_str(best2, "struct", "Suggests 'struct' for 'strut'")

    // Format "did you mean"
    dym = suggestion_format_did_you_mean(best1)
    assert_eq_str(dym, "did you mean 'return'?", "Formatted did you mean message")

    return 0

// ── Test 7: Unified Diagnostic Emitter (Terminal + JSON) ─────────────────────
fn test_diagnostic_emitter
    say "--- 7. Testing Unified Diagnostic Emitter ---"
    sm = source_map_new()
    code = "fn run\n    x = foo_bar\n"
    fid = source_map_add_file(sm, "app.lp", code)

    // Span for "foo_bar" at line 2 col 9..16
    // Line 1 is "fn run\n" (7 bytes, 0..6)
    // Line 2 starts at 7: "    x = foo_bar\n"
    // "    x = " is 8 chars (7..14), "foo_bar" is 15..22
    span_sym = source_span_from_offsets(sm, fid, 15, 22)

    // Create emitter in terminal mode
    em_term = diagnostic_emitter_new(sm, "terminal", 1)

    diag = diagnostic_new("E0201", "error", "cannot find symbol 'foo_bar' in this scope")
    diagnostic_add_label(diag, span_sym, "not found in current scope", 1)
    diagnostic_add_note(diag, "available symbols in scope: 'foo_baz', 'bar_qux'")
    diagnostic_add_help(diag, "check if the symbol was imported from another module")
    diagnostic_add_suggestion(diag, "did you mean 'foo_baz'?")

    term_out = diagnostic_emitter_emit(em_term, diag)
    assert_true(len(term_out) > 0, "Terminal output non-empty")
    assert_eq_int(em_term.error_count, 1, "Emitter error count is 1")
    assert_true(diagnostic_emitter_has_errors(em_term), "Emitter reports errors")

    summary_str = diagnostic_emitter_summary(em_term)
    say "Summary: " + summary_str

    // Create emitter in JSON mode
    em_json = diagnostic_emitter_new(sm, "json", 0)
    json_out = diagnostic_emitter_emit(em_json, diag)
    assert_true(len(json_out) > 0, "JSON output non-empty")

    say "Sample Rendered JSON Output:"
    say json_out

    // Verify batch JSON rendering
    all_json = diagnostic_emitter_render_all_json(em_json)
    assert_true(len(all_json) > 0, "Batch JSON document non-empty")

    return 0

// ── Test 8: Multi-Line Snippet Rendering ─────────────────────────────────────
fn test_multiline_snippet
    say "--- 8. Testing Multi-Line Snippet Rendering ---"
    sm = source_map_new()
    multiline_code = "fn outer\n    if cond == 1\n        x = 100\n        y = 200\n        z = 300\n    return 0\n"
    fid = source_map_add_file(sm, "multiline_sample.lp", multiline_code)

    // Span across lines 2..5 (if block)
    // Line 1: "fn outer\n" (0..8)
    // Line 2 starts at 9: "    if cond == 1\n"
    // Line 5: "        z = 300\n"
    span_multi = source_span_new(fid, 13, 64, 2, 5, 5, 16)
    assert_true(source_span_is_multiline(span_multi), "Span is multi-line")

    ct_plain = color_theme_plain()
    opt = snippet_options_default()

    rendered = snippet_render(sm, span_multi, "unclosed block construct", 1, ct_plain, opt)
    assert_true(len(rendered) > 0, "Multi-line snippet non-empty")
    say "Sample Rendered Multi-line Snippet:"
    say rendered
    return 0

// ── Main Test Runner ─────────────────────────────────────────────────────────
fn main
    say "=================================================================="
    say "👑 LIPI FIRST 1.0.0 COMPILER DIAGNOSTICS SUBSYSTEM VERIFICATION"
    say "=================================================================="

    test_error_codes()
    test_line_index()
    test_source_map()
    test_color_theme()
    test_snippet_renderer()
    test_suggestion()
    test_diagnostic_emitter()
    test_multiline_snippet()

    say "=================================================================="
    say "🎉 ALL 8 DIAGNOSTIC SUBSYSTEM TESTS PASSED WITH 100% SUCCESS!"
    say "=================================================================="
    return 0

main()
