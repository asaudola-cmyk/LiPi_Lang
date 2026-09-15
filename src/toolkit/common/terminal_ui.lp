// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: TERMINAL UI & TRUECOLOR ENGINE (src/toolkit/common/terminal_ui.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | ANSI 24-bit TrueColor | Zero C / Zero Libc
// ==============================================================================
//
// WHY THIS MODULE:
// High-grade developer ergonomics require terminal feedback with clean visual hierarchy,
// distinct progress indicators, step banners, and rich 24-bit TrueColor styling.
// By implementing direct ECMA-48 / ANSI escape sequences in pure Lipi:
// 1. Zero dependencies on ncurses, terminfo, or external terminal crates.
// 2. Exact 72-column double-line box layouts matching modern high-DPI consoles.
// 3. Status spinners and dynamic inline progress bars for long-running builds.

include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/io.lp"

// ── 1. TrueColor & Style Primitives ───────────────────────────────────────────

// WHY: Applies 24-bit TrueColor RGB foreground to arbitrary string content.
fn term_color r g b text
    return "\033[38;2;" + str(r) + ";" + str(g) + ";" + str(b) + "m" + text + "\033[0m"

// WHY: Applies 24-bit TrueColor RGB background to arbitrary string content.
fn term_bg_color r g b text
    return "\033[48;2;" + str(r) + ";" + str(g) + ";" + str(b) + "m" + text + "\033[0m"

// WHY: High-intensity bold text rendering.
fn term_bold text
    return "\033[1m" + text + "\033[0m"

// WHY: Muted/dim text rendering for auxiliary details and secondary paths.
fn term_dim text
    return "\033[2m" + text + "\033[0m"

// WHY: Underlined text rendering for URIs and terminal hyperlinks.
fn term_underline text
    return "\033[4m" + text + "\033[0m"

// WHY: Raw reset sequence to restore terminal to standard state.
fn term_reset
    return "\033[0m"

// ── 2. Standard Sovereign Palette ─────────────────────────────────────────────

// WHY: Canonical brand colors of the LiPi Sovereign Universe.
fn term_cyan text
    return term_color(0, 255, 204, text)

fn term_gold text
    return term_color(255, 215, 0, text)

fn term_purple text
    return term_color(180, 100, 255, text)

fn term_green text
    return term_color(46, 204, 113, text)

fn term_red text
    return term_color(231, 76, 60, text)

fn term_blue text
    return term_color(52, 152, 219, text)

fn term_gray text
    return term_color(140, 150, 160, text)

// ── 3. Status Notifiers & Badges ──────────────────────────────────────────────

// WHY: Standardized success badge with Unicode checkmark.
fn term_success tag message
    badge = term_color(46, 204, 113, "✔ [" + tag + "]")
    say "  " + badge + " " + message
    return 0

// WHY: Standardized error badge with Unicode heavy multiplication X.
fn term_error tag message
    badge = term_color(231, 76, 60, "✖ [" + tag + "]")
    say "  " + badge + " " + message
    return 0

// WHY: Standardized warning badge with Unicode triangle alert.
fn term_warning tag message
    badge = term_color(255, 215, 0, "▲ [" + tag + "]")
    say "  " + badge + " " + message
    return 0

// WHY: Standardized informational badge with Unicode info glyph.
fn term_info tag message
    badge = term_color(0, 255, 204, "ℹ [" + tag + "]")
    say "  " + badge + " " + message
    return 0

// ── 4. Formatted Step Banners & Decorative Boxes ──────────────────────────────

// WHY: Visual divider line for modular diagnostic separation.
fn term_separator
    say term_color(100, 110, 130, "  ──────────────────────────────────────────────────────────────────────")
    return 0

// WHY: Renders exact 72-column TrueColor bordered header banner.
// Double-border characters '╔', '╗', '║', '╚', '╝' and horizontal '═' are exactly budgeted.
fn term_banner title subtitle
    border_color_r = 0
    border_color_g = 255
    border_color_b = 204

    top_line = "╔══════════════════════════════════════════════════════════════════════╗"
    bot_line = "╚══════════════════════════════════════════════════════════════════════╝"

    say term_color(border_color_r, border_color_g, border_color_b, top_line)

    // Title line (68 interior characters)
    t_content = "  👑 " + title
    t_len = len(t_content)
    while t_len < 68
        t_content = t_content + " "
        t_len = t_len + 1
    say term_color(border_color_r, border_color_g, border_color_b, "║") + term_bold(t_content) + term_color(border_color_r, border_color_g, border_color_b, "║")

    // Subtitle line (68 interior characters)
    if len(subtitle) > 0
        s_content = "  ⚡ " + subtitle
        s_len = len(s_content)
        while s_len < 68
            s_content = s_content + " "
            s_len = s_len + 1
        say term_color(border_color_r, border_color_g, border_color_b, "║") + term_dim(s_content) + term_color(border_color_r, border_color_g, border_color_b, "║")

    say term_color(border_color_r, border_color_g, border_color_b, bot_line)
    say ""
    return 0

// WHY: Renders numbered step banner for multi-stage pipeline visibility.
fn term_step_banner current total title detail
    step_tag = "[" + str(current) + "/" + str(total) + "]"
    colored_tag = term_color(0, 255, 204, term_bold(step_tag))
    colored_title = term_bold(title)
    say "\n▶ " + colored_tag + " " + colored_title
    if len(detail) > 0
        say "    " + term_dim("↳ " + detail)
    return 0

// ── 5. Dynamic Progress Bars & Animation Frames ───────────────────────────────

// WHY: Smooth block-rendered progress indicator for compilation and testing phases.
fn term_progress_bar current total width label
    if total <= 0
        total = 1
    if current > total
        current = total
    pct = (current * 100) / total
    filled_cells = (current * width) / total
    empty_cells = width - filled_cells

    bar_str = ""
    i = 0
    while i < filled_cells
        bar_str = bar_str + "█"
        i = i + 1
    while i < width
        bar_str = bar_str + "░"
        i = i + 1

    pct_str = str(pct) + "%"
    while len(pct_str) < 4
        pct_str = " " + pct_str

    count_str = "[" + str(current) + "/" + str(total) + "]"
    colored_bar = term_color(0, 255, 204, bar_str)
    line = "  " + colored_bar + " " + term_bold(pct_str) + " " + term_dim(count_str) + " " + label
    say line
    return 0

// WHY: Cyclical Braille animation glyph generator for interactive status displays.
fn term_spinner_char frame_index
    idx = frame_index % 10
    if idx == 0 return "⠋"
    if idx == 1 return "⠙"
    if idx == 2 return "⠹"
    if idx == 3 return "⠸"
    if idx == 4 return "⠼"
    if idx == 5 return "⠴"
    if idx == 6 return "⠦"
    if idx == 7 return "⠧"
    if idx == 8 return "⠇"
    return "⠏"
