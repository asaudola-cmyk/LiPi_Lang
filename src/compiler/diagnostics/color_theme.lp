// ==============================================================================
// 👑 LIPI FIRST 1.0.0 COMPILER DIAGNOSTICS: ANSI TRUECOLOR 24-BIT STYLES
// ⚡ 100% Pure Lipi First 1.0.0 | Zero Libc | Zero C | Direct Silicon
// 🏛️ File: src/compiler/diagnostics/color_theme.lp
//
// WHY: Modern developer experience demands high-clarity visual cues in terminal
//      diagnostics. ANSI TrueColor (24-bit RGB) provides high aesthetic precision
//      (distinct bold red errors, warm amber warnings, mint cyan hints, slate gutters)
//      while supporting 16-color ANSI fallback and pure plain-text monochrome
//      for CI environments (NO_COLOR standard).
// ==============================================================================

// ── Color Theme Configuration Descriptor ─────────────────────────────────────
// WHY: Encapsulates terminal styling capabilities and active color mode.
struct ColorTheme
    enabled
    use_truecolor

// WHY: Allocates a new ColorTheme with specified color state and color depth.
fn color_theme_new enabled use_truecolor
    ct = ColorTheme()
    ct.enabled = enabled
    ct.use_truecolor = use_truecolor
    return ct

// WHY: Returns the default high-definition TrueColor theme for modern terminals.
fn color_theme_default
    return color_theme_new(1, 1)

// WHY: Returns monochrome plain-text theme (disables all ANSI escape sequences).
fn color_theme_plain
    return color_theme_new(0, 0)

// WHY: Toggles theme color output dynamically (e.g. when NO_COLOR env var is set).
fn color_theme_set_enabled ct enabled
    if ct != 0
        ct.enabled = enabled

// ── Low-Level ANSI Escape Sequence Synthesizers ──────────────────────────────
// WHY: Generates raw ANSI CSI escape sequences directly from byte codes.
fn color_theme_esc
    return chr(27)

fn color_theme_csi
    return chr(27) + "["

// WHY: Synthesizes a 24-bit TrueColor foreground escape code: ESC[38;2;R;G;Bm.
fn color_theme_rgb ct r g b
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 0
        // Fallback to basic foreground
        return chr(27) + "[37m"
    return chr(27) + "[38;2;" + str(r) + ";" + str(g) + ";" + str(b) + "m"

// WHY: Synthesizes a 24-bit TrueColor background escape code: ESC[48;2;R;G;Bm.
fn color_theme_bg_rgb ct r g b
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 0
        return ""
    return chr(27) + "[48;2;" + str(r) + ";" + str(g) + ";" + str(b) + "m"

// ── Text Attributes ──────────────────────────────────────────────────────────
// WHY: Controls font weight, intensity, and decoration.
fn color_theme_bold ct
    if ct == 0 or ct.enabled == 0
        return ""
    return chr(27) + "[1m"

fn color_theme_dim ct
    if ct == 0 or ct.enabled == 0
        return ""
    return chr(27) + "[2m"

fn color_theme_underline ct
    if ct == 0 or ct.enabled == 0
        return ""
    return chr(27) + "[4m"

fn color_theme_reset ct
    if ct == 0 or ct.enabled == 0
        return ""
    return chr(27) + "[0m"

// ── Semantic Diagnostic Color Palettes ───────────────────────────────────────
// WHY: Semantic color tokens ensure consistent branding across all compiler phases.

// 1. Error: Bold Vivid Red (RGB 255, 75, 75)
fn color_theme_error ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return chr(27) + "[1m" + color_theme_rgb(ct, 255, 75, 75)
    return chr(27) + "[1;31m"

// 2. Warning: Bold Warm Amber / Gold (RGB 255, 175, 0)
fn color_theme_warning ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return chr(27) + "[1m" + color_theme_rgb(ct, 255, 175, 0)
    return chr(27) + "[1;33m"

// 3. Note / Info: Bold Sky Blue (RGB 75, 150, 255)
fn color_theme_note ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return chr(27) + "[1m" + color_theme_rgb(ct, 75, 150, 255)
    return chr(27) + "[1;34m"

// 4. Hint / Help: Bold Mint Cyan (RGB 50, 215, 180)
fn color_theme_hint ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return chr(27) + "[1m" + color_theme_rgb(ct, 50, 215, 180)
    return chr(27) + "[1;36m"

// 5. Gutter Line Numbers: Dim Slate Gray (RGB 120, 130, 150)
fn color_theme_gutter ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return color_theme_rgb(ct, 120, 130, 150)
    return chr(27) + "[90m"

// 6. Gutter Separator Pipe ('|'): Dim Steel Blue (RGB 90, 100, 120)
fn color_theme_separator ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return color_theme_rgb(ct, 90, 100, 120)
    return chr(27) + "[90m"

// 7. Primary Caret ('^'): Bold Vivid Red (RGB 255, 80, 80)
fn color_theme_caret_primary ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return chr(27) + "[1m" + color_theme_rgb(ct, 255, 80, 80)
    return chr(27) + "[1;31m"

// 8. Secondary Caret / Underline ('-'): Bold Lavender (RGB 180, 140, 255)
fn color_theme_caret_secondary ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return chr(27) + "[1m" + color_theme_rgb(ct, 180, 140, 255)
    return chr(27) + "[1;35m"

// 9. Diagnostic Code Badge ([E0001]): Bold Amber (RGB 255, 210, 50)
fn color_theme_badge ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return chr(27) + "[1m" + color_theme_rgb(ct, 255, 210, 50)
    return chr(27) + "[1;33m"

// 10. File Location Arrow (-->): Bold Cyan (RGB 80, 200, 240)
fn color_theme_location ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return chr(27) + "[1m" + color_theme_rgb(ct, 80, 200, 240)
    return chr(27) + "[1;36m"

// 11. Code Highlight / Quoted Token: Bold Crisp White (RGB 255, 255, 255)
fn color_theme_highlight ct
    if ct == 0 or ct.enabled == 0
        return ""
    if ct.use_truecolor == 1
        return chr(27) + "[1m" + color_theme_rgb(ct, 255, 255, 255)
    return chr(27) + "[1;37m"

// ── Formatter Helpers ────────────────────────────────────────────────────────
// WHY: Wraps a string fragment in an active style and guarantees a trailing reset.
fn color_theme_format ct style_code text
    if ct == 0 or ct.enabled == 0
        return text
    return style_code + text + color_theme_reset(ct)

// WHY: Strips ANSI escape sequences from strings, converting styled output
//      into clean plain text for automated unit testing or file logging.
fn color_theme_strip_ansi text
    tlen = len(text)
    if tlen == 0
        return ""

    out_buf = list()
    p = 0
    while p < tlen
        ch = char_at(text, p)
        if ord(ch) == 27
            // Start of escape sequence, skip until 'm' or EOF
            p = p + 1
            if p < tlen and char_at(text, p) == "["
                p = p + 1
                while p < tlen and char_at(text, p) != "m"
                    p = p + 1
                if p < tlen and char_at(text, p) == "m"
                    p = p + 1
        else
            push(out_buf, ch)
            p = p + 1

    // Reconstruct clean string
    res = ""
    n = len(out_buf)
    i = 0
    while i < n
        res = res + out_buf[i]
        i = i + 1
    return res
