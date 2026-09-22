// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER DIAGNOSTICS: TERMINAL SNIPPET RENDERER
// ⚡ 100% Pure Lipi First 1.0.0 | Zero Libc | Zero C | Direct Silicon
// 🏛️ File: src/compiler/diagnostics/snippet_renderer.lp
//
// WHY: High-quality compiler error reporting requires crystal-clear visual context.
//      This module renders Rustc/Clang-grade terminal snippets with:
//      - Right-aligned line number gutters
//      - TrueColor color highlights
//      - Carets ('^^^^') pointing directly to offending tokens
//      - Multi-line span folding and annotations
//      - Automatic tab expansion for pixel-perfect column alignment
// ==============================================================================

include "src/compiler/diagnostics/source_map.lp"
include "src/compiler/diagnostics/color_theme.lp"

// ── Snippet Formatting Configuration ─────────────────────────────────────────
struct SnippetOptions
    context_before
    context_after
    show_gutter
    tab_width
    max_multiline

fn snippet_options_default
    opt = SnippetOptions()
    opt.context_before = 0
    opt.context_after = 0
    opt.show_gutter = 1
    opt.tab_width = 4
    opt.max_multiline = 6
    return opt

// ── Text Alignment & Padding Primitives ──────────────────────────────────────
// WHY: Computes base-10 digit count for gutter line alignment.
fn num_digits n
    if n <= 0
        return 1
    c = 0
    tmp = n
    while tmp > 0
        c = c + 1
        tmp = tmp / 10
    return c

// WHY: Repeats a single character string N times.
fn repeat_char ch count
    if count <= 0
        return ""
    res = ""
    i = 0
    while i < count
        res = res + ch
        i = i + 1
    return res

// WHY: Left-pads a string with spaces until it reaches total_width.
fn pad_left s total_width
    slen = len(s)
    if slen >= total_width
        return s
    return repeat_char(" ", total_width - slen) + s

// WHY: Expands tab characters ('\t') into spaces so terminal carets match visual columns.
fn expand_tabs text tab_width
    tlen = len(text)
    if tlen == 0
        return ""
    if tab_width <= 0
        tab_width = 4

    out = ""
    col = 1
    i = 0
    while i < tlen
        ch = char_at(text, i)
        if ch == "\t"
            rem = (col - 1) % tab_width
            spaces_to_add = tab_width - rem
            out = out + repeat_char(" ", spaces_to_add)
            col = col + spaces_to_add
        else
            out = out + ch
            col = col + 1
        i = i + 1
    return out

// ── Diagnostic Header Renderer ───────────────────────────────────────────────
// WHY: Renders standard header:
//      error[E0001]: unexpected token '+'
//        --> src/main.lp:14:5
fn snippet_render_header severity code_str message file_path line col ct
    gutter_pad = "  "
    loc_arrow = "--> "

    // Apply color styling
    sev_text = severity
    if severity == "error"
        sev_text = color_theme_error(ct) + severity
    elif severity == "warning"
        sev_text = color_theme_warning(ct) + severity
    elif severity == "note"
        sev_text = color_theme_note(ct) + severity
    elif severity == "hint"
        sev_text = color_theme_hint(ct) + severity

    badge_text = ""
    if len(code_str) > 0
        badge_text = color_theme_badge(ct) + "[" + code_str + "]"

    reset_str = color_theme_reset(ct)
    bold_str = color_theme_bold(ct)
    loc_color = color_theme_location(ct)

    header_line = sev_text + badge_text + reset_str + bold_str + ": " + message + reset_str
    arrow_line = gutter_pad + loc_color + loc_arrow + reset_str + file_path + ":" + str(line) + ":" + str(col)

    return header_line + "\n" + arrow_line

// ── Gutter Separator Line ────────────────────────────────────────────────────
// WHY: Renders empty gutter line: "   |"
fn snippet_render_empty_gutter gutter_w ct
    gutter_sp = repeat_char(" ", gutter_w)
    sep = color_theme_separator(ct) + "|" + color_theme_reset(ct)
    return gutter_sp + " " + sep

// ── Single-Line Snippet Renderer ─────────────────────────────────────────────
// WHY: Renders a source line and underlines the exact span with carets ('^^^^').
fn snippet_render_single_line sf span label_msg is_primary ct opt gutter_w
    line_num = span.start_line
    raw_text = line_index_get_line_text(sf.line_index, sf.content, line_num)
    disp_text = expand_tabs(raw_text, opt.tab_width)

    sep = color_theme_separator(ct) + "|" + color_theme_reset(ct)
    gutter_num = color_theme_gutter(ct) + pad_left(str(line_num), gutter_w) + color_theme_reset(ct)

    // Source code line
    line_str = gutter_num + " " + sep + " " + disp_text

    // Visual column calculation
    v_start = line_index_visual_column(raw_text, span.start_col, opt.tab_width)
    v_end = line_index_visual_column(raw_text, span.end_col, opt.tab_width)

    caret_count = v_end - v_start
    if caret_count < 1
        caret_count = 1

    space_count = v_start - 1
    if space_count < 0
        space_count = 0

    // Caret style
    ch_caret = "^"
    caret_color = color_theme_caret_primary(ct)
    if is_primary == 0
        ch_caret = "-"
        caret_color = color_theme_caret_secondary(ct)

    empty_gutter = repeat_char(" ", gutter_w) + " " + sep + " "
    carets = caret_color + repeat_char(ch_caret, caret_count) + color_theme_reset(ct)

    annotation = ""
    if len(label_msg) > 0
        annotation = " " + caret_color + label_msg + color_theme_reset(ct)

    underline_str = empty_gutter + repeat_char(" ", space_count) + carets + annotation

    return line_str + "\n" + underline_str

// ── Multi-Line Snippet Renderer ──────────────────────────────────────────────
// WHY: Renders multi-line spans with start pointer, body lines, and closing caret.
fn snippet_render_multi_line sf span label_msg is_primary ct opt gutter_w
    sep = color_theme_separator(ct) + "|" + color_theme_reset(ct)
    out = ""

    caret_color = color_theme_caret_primary(ct)
    if is_primary == 0
        caret_color = color_theme_caret_secondary(ct)

    // 1. First line
    s_line = span.start_line
    raw_start = line_index_get_line_text(sf.line_index, sf.content, s_line)
    disp_start = expand_tabs(raw_start, opt.tab_width)
    gutter_s = color_theme_gutter(ct) + pad_left(str(s_line), gutter_w) + color_theme_reset(ct)

    out = out + gutter_s + " " + sep + " " + disp_start + "\n"

    v_start = line_index_visual_column(raw_start, span.start_col, opt.tab_width)
    sp_count = v_start - 1
    if sp_count < 0
        sp_count = 0

    empty_gutter = repeat_char(" ", gutter_w) + " " + sep + " "
    start_pointer = caret_color + "^--- starting here" + color_theme_reset(ct)
    out = out + empty_gutter + repeat_char(" ", sp_count) + start_pointer + "\n"

    // 2. Middle lines (folding if exceeds max_multiline)
    total_lines = (span.end_line - span.start_line) + 1
    if total_lines <= opt.max_multiline
        cur_l = s_line + 1
        while cur_l < span.end_line
            raw_mid = line_index_get_line_text(sf.line_index, sf.content, cur_l)
            disp_mid = expand_tabs(raw_mid, opt.tab_width)
            gutter_m = color_theme_gutter(ct) + pad_left(str(cur_l), gutter_w) + color_theme_reset(ct)
            out = out + gutter_m + " " + sep + " " + disp_mid + "\n"
            cur_l = cur_l + 1
    else
        // Render second line
        raw_l2 = line_index_get_line_text(sf.line_index, sf.content, s_line + 1)
        gutter_l2 = color_theme_gutter(ct) + pad_left(str(s_line + 1), gutter_w) + color_theme_reset(ct)
        out = out + gutter_l2 + " " + sep + " " + expand_tabs(raw_l2, opt.tab_width) + "\n"

        // Ellipsis line
        gutter_dots = color_theme_dim(ct) + pad_left("...", gutter_w) + color_theme_reset(ct)
        out = out + gutter_dots + " " + sep + " ...\n"

    // 3. End line
    e_line = span.end_line
    raw_end = line_index_get_line_text(sf.line_index, sf.content, e_line)
    disp_end = expand_tabs(raw_end, opt.tab_width)
    gutter_e = color_theme_gutter(ct) + pad_left(str(e_line), gutter_w) + color_theme_reset(ct)

    out = out + gutter_e + " " + sep + " " + disp_end + "\n"

    v_end = line_index_visual_column(raw_end, span.end_col, opt.tab_width)
    c_end_count = v_end
    if c_end_count < 1
        c_end_count = 1

    end_carets = caret_color + repeat_char("-", c_end_count - 1) + "^" + color_theme_reset(ct)
    annotation = ""
    if len(label_msg) > 0
        annotation = " " + caret_color + label_msg + color_theme_reset(ct)
    else
        annotation = " " + caret_color + "...ending here" + color_theme_reset(ct)

    out = out + empty_gutter + end_carets + annotation
    return out

// ── Complete Source Snippet Generator ────────────────────────────────────────
// WHY: Assembles full visual diagnostic snippet with gutter framing and carets.
fn snippet_render sm span label_msg is_primary ct opt
    if sm == 0 or span == 0
        return ""
    sf = source_map_get_file(sm, span.file_id)
    if sf == 0
        return ""

    if opt == 0
        opt = snippet_options_default()

    max_l = span.end_line
    gutter_w = num_digits(max_l)
    if gutter_w < 2
        gutter_w = 2

    empty_g = snippet_render_empty_gutter(gutter_w, ct)

    res = empty_g + "\n"
    if source_span_is_multiline(span) == 1
        res = res + snippet_render_multi_line(sf, span, label_msg, is_primary, ct, opt, gutter_w) + "\n"
    else
        res = res + snippet_render_single_line(sf, span, label_msg, is_primary, ct, opt, gutter_w) + "\n"
    res = res + empty_g

    return res
