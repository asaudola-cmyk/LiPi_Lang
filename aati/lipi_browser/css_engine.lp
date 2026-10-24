// ==============================================================================
// 👑 LIPI SOVEREIGN WEB BROWSER: CSS CASCADING STYLE & SPECIFICITY ENGINE
// ⚡ Module: aati/lipi_browser/css_engine.lp
// 🏛️ Architecture: Zero-WebKit CSS3 Cascading & Style Computation
// 100% Pure LiPi Implementation — Zero External / Libc / Python Dependencies
// ==============================================================================

include "utso/memory.lp"
include "utso/string.lp"
include "aati/lipi_browser/html_parser.lp"

// ── 1. Color Parser & ARGB32 Silicon Formatter ────────────────────────────────

fn css_parse_color color_str
    s = str_to_lower(str_trim(color_str))
    if s == "transparent" return 0 end
    if s == "black" return 4278190080 end        // 0xFF000000
    if s == "white" return 4294967295 end        // 0xFFFFFFFF
    if s == "red" return 4294901760 end          // 0xFFFF0000
    if s == "green" return 4278255360 end        // 0xFF00FF00
    if s == "blue" return 4278190335 end         // 0xFF0000FF
    if s == "yellow" return 4294967040 end       // 0xFFFFFF00
    if s == "gray" or s == "grey" return 4286611584 end // 0xFF808080
    if s == "cyan" return 4278255615 end         // 0xFF00FFFF
    if s == "magenta" return 4294902015 end      // 0xFFFF00FF
    if s == "orange" return 4294944000 end       // 0xFFFFA500
    if s == "darkgray" return 4281545523 end     // 0xFF333333

    // Hex Color Parsing: #RGB or #RRGGBB
    if len(s) >= 4 and char_at(s, 0) == "#"
        if len(s) == 4
            // #RGB -> expand to #RRGGBB
            r_hex = char_at(s, 1) + char_at(s, 1)
            g_hex = char_at(s, 2) + char_at(s, 2)
            b_hex = char_at(s, 3) + char_at(s, 3)
            r = str_hex_to_int(r_hex)
            g = str_hex_to_int(g_hex)
            b = str_hex_to_int(b_hex)
            return (255 * 16777216) + (r * 65536) + (g * 256) + b
        elif len(s) >= 7
            r = str_hex_to_int(str_slice(s, 1, 3))
            g = str_hex_to_int(str_slice(s, 3, 5))
            b = str_hex_to_int(str_slice(s, 5, 7))
            return (255 * 16777216) + (r * 65536) + (g * 256) + b
        end
    end
    return 4278190080 // Default opaque black

fn str_hex_to_int hex_str
    val = 0
    i = 0
    while i < len(hex_str)
        ch = char_at(hex_str, i)
        code = ord(ch)
        digit = 0
        if code >= 48 and code <= 57
            digit = code - 48
        elif code >= 97 and code <= 102
            digit = 10 + (code - 97)
        elif code >= 65 and code <= 70
            digit = 10 + (code - 65)
        end
        val = (val * 16) + digit
        i = i + 1
    end
    return val

fn css_parse_pixels pixel_str
    // Extracts numeric pixel value from e.g. "20px", "100", "50%"
    s = str_trim(pixel_str)
    num_str = ""
    i = 0
    is_neg = 0
    if len(s) > 0 and char_at(s, 0) == "-"
        is_neg = 1
        i = 1
    end
    while i < len(s)
        ch = char_at(s, i)
        code = ord(ch)
        if code >= 48 and code <= 57
            num_str = num_str + ch
        else
            break
        end
        i = i + 1
    end
    if len(num_str) == 0 return 0 end
    val = str_to_int(num_str)
    if is_neg == 1 return 0 - val end
    return val

// ── 2. CSS Rule & Declaration Models ──────────────────────────────────────────

SELECTOR_TYPE_TAG       = 1
SELECTOR_TYPE_CLASS     = 2
SELECTOR_TYPE_ID        = 3
SELECTOR_TYPE_UNIVERSAL = 4

struct CSSDeclaration
    cd_prop_name
    cd_prop_value

struct CSSRule
    cr_selector
    cr_selector_type
    cr_specificity
    cr_declarations

fn css_rule_new selector
    rule = CSSRule()
    s = str_trim(selector)
    rule.cr_selector = s
    rule.cr_declarations = list()

    // Determine selector type and specificity
    if s == "*"
        rule.cr_selector_type = SELECTOR_TYPE_UNIVERSAL
        rule.cr_specificity = 0
    elif len(s) > 0 and char_at(s, 0) == "#"
        rule.cr_selector_type = SELECTOR_TYPE_ID
        rule.cr_specificity = 100
    elif len(s) > 0 and char_at(s, 0) == "."
        rule.cr_selector_type = SELECTOR_TYPE_CLASS
        rule.cr_specificity = 10
    else
        rule.cr_selector_type = SELECTOR_TYPE_TAG
        rule.cr_specificity = 1
    end
    return rule

fn css_rule_add_decl rule prop val
    decl = CSSDeclaration()
    decl.cd_prop_name = str_to_lower(str_trim(prop))
    decl.cd_prop_value = str_trim(val)
    push(rule.cr_declarations, decl)
    return 1

// ── 3. Stylesheet Parser ──────────────────────────────────────────────────────

struct CSSStylesheet
    css_rules

fn css_stylesheet_new
    sheet = CSSStylesheet()
    sheet.css_rules = list()
    return sheet

fn css_parse_stylesheet css_str
    sheet = css_stylesheet_new()
    s_len = len(css_str)
    i = 0

    while i < s_len
        // Skip whitespace
        while i < s_len and (char_at(css_str, i) == " " or char_at(css_str, i) == "\t" or char_at(css_str, i) == "\n" or char_at(css_str, i) == "\r")
            i = i + 1
        end
        if i >= s_len break end

        // Skip comments /* ... */
        if i + 1 < s_len and char_at(css_str, i) == "/" and char_at(css_str, i + 1) == "*"
            i = i + 2
            while i + 1 < s_len and not (char_at(css_str, i) == "*" and char_at(css_str, i + 1) == "/")
                i = i + 1
            end
            i = i + 2
            continue
        end

        // Read selector until '{'
        selector_str = ""
        while i < s_len and char_at(css_str, i) != "{"
            selector_str = selector_str + char_at(css_str, i)
            i = i + 1
        end
        if i < s_len i = i + 1 end // Skip '{'

        rule = css_rule_new(selector_str)

        // Read declarations until '}'
        body_str = ""
        while i < s_len and char_at(css_str, i) != "}"
            body_str = body_str + char_at(css_str, i)
            i = i + 1
        end
        if i < s_len i = i + 1 end // Skip '}'

        // Parse declarations separated by ';'
        decl_tokens = str_split(body_str, ";")
        d_idx = 0
        while d_idx < len(decl_tokens)
            d_str = str_trim(decl_tokens[d_idx])
            if len(d_str) > 0 and str_contains(d_str, ":") == 1
                parts = str_split(d_str, ":")
                if len(parts) >= 2
                    css_rule_add_decl(rule, parts[0], parts[1])
                end
            end
            d_idx = d_idx + 1
        end

        push(sheet.css_rules, rule)
    end

    return sheet

// ── 4. Selector Matching & Specificity Cascade ────────────────────────────────

fn css_selector_matches rule dom_node
    if dom_node == 0 return 0 end
    sel = rule.cr_selector

    if rule.cr_selector_type == SELECTOR_TYPE_UNIVERSAL
        return 1
    elif rule.cr_selector_type == SELECTOR_TYPE_ID
        // Match #id
        target = str_slice(sel, 1, len(sel))
        if dom_node.dom_id == target return 1 end
    elif rule.cr_selector_type == SELECTOR_TYPE_CLASS
        // Match .class
        target = str_slice(sel, 1, len(sel))
        if str_contains(" " + dom_node.dom_class_name + " ", " " + target + " ") == 1
            return 1
        end
    elif rule.cr_selector_type == SELECTOR_TYPE_TAG
        if str_to_lower(dom_node.dom_tag) == str_to_lower(sel)
            return 1
        end
    end
    return 0

// ── 5. Computed Style Computation ─────────────────────────────────────────────

struct ComputedStyle
    cs_display
    cs_color
    cs_bg_color
    cs_width
    cs_height
    cs_margin_top
    cs_margin_right
    cs_margin_bottom
    cs_margin_left
    cs_padding_top
    cs_padding_right
    cs_padding_bottom
    cs_padding_left
    cs_font_size
    cs_flex_direction
    cs_justify_content
    cs_align_items

fn computed_style_default
    style = ComputedStyle()
    style.cs_display = "block"
    style.cs_color = 4278190080    // Black (0xFF000000)
    style.cs_bg_color = 0          // Transparent (0x00000000)
    style.cs_width = -1            // -1 = auto
    style.cs_height = -1           // -1 = auto
    style.cs_margin_top = 0
    style.cs_margin_right = 0
    style.cs_margin_bottom = 0
    style.cs_margin_left = 0
    style.cs_padding_top = 0
    style.cs_padding_right = 0
    style.cs_padding_bottom = 0
    style.cs_padding_left = 0
    style.cs_font_size = 14
    style.cs_flex_direction = "row"
    style.cs_justify_content = "flex-start"
    style.cs_align_items = "stretch"
    return style

fn css_apply_declaration style prop val
    p = str_to_lower(str_trim(prop))
    v = str_to_lower(str_trim(val))

    if p == "display"
        style.cs_display = v
    elif p == "color"
        style.cs_color = css_parse_color(val)
    elif p == "background-color" or p == "background" or p == "bg"
        style.cs_bg_color = css_parse_color(val)
    elif p == "width"
        style.cs_width = css_parse_pixels(v)
    elif p == "height"
        style.cs_height = css_parse_pixels(v)
    elif p == "font-size"
        style.cs_font_size = css_parse_pixels(v)
    elif p == "margin"
        m = css_parse_pixels(v)
        style.cs_margin_top = m
        style.cs_margin_right = m
        style.cs_margin_bottom = m
        style.cs_margin_left = m
    elif p == "margin-top"
        style.cs_margin_top = css_parse_pixels(v)
    elif p == "margin-right"
        style.cs_margin_right = css_parse_pixels(v)
    elif p == "margin-bottom"
        style.cs_margin_bottom = css_parse_pixels(v)
    elif p == "margin-left"
        style.cs_margin_left = css_parse_pixels(v)
    elif p == "padding"
        pad = css_parse_pixels(v)
        style.cs_padding_top = pad
        style.cs_padding_right = pad
        style.cs_padding_bottom = pad
        style.cs_padding_left = pad
    elif p == "padding-top"
        style.cs_padding_top = css_parse_pixels(v)
    elif p == "padding-right"
        style.cs_padding_right = css_parse_pixels(v)
    elif p == "padding-bottom"
        style.cs_padding_bottom = css_parse_pixels(v)
    elif p == "padding-left"
        style.cs_padding_left = css_parse_pixels(v)
    elif p == "flex-direction"
        style.cs_flex_direction = v
    elif p == "justify-content"
        style.cs_justify_content = v
    elif p == "align-items"
        style.cs_align_items = v
    end
    return 1

fn css_compute_style dom_node stylesheet
    style = computed_style_default()
    if dom_node == 0 return style end

    // Default element displays
    t = str_to_lower(dom_node.dom_tag)
    if t == "span" or t == "a" or t == "b" or t == "i" or t == "text"
        style.cs_display = "inline"
    elif t == "h1"
        style.cs_font_size = 28
        style.cs_margin_top = 10
        style.cs_margin_bottom = 10
    elif t == "h2"
        style.cs_font_size = 22
        style.cs_margin_top = 8
        style.cs_margin_bottom = 8
    elif t == "p"
        style.cs_margin_top = 6
        style.cs_margin_bottom = 6
    end

    // Apply matching CSS rules from stylesheet
    if stylesheet != 0
        r_idx = 0
        while r_idx < len(stylesheet.css_rules)
            rule = stylesheet.css_rules[r_idx]
            if css_selector_matches(rule, dom_node) == 1
                d_idx = 0
                while d_idx < len(rule.cr_declarations)
                    decl = rule.cr_declarations[d_idx]
                    css_apply_declaration(style, decl.cd_prop_name, decl.cd_prop_value)
                    d_idx = d_idx + 1
                end
            end
            r_idx = r_idx + 1
        end
    end

    // Apply inline style attribute (Highest specificity: style="...")
    if len(dom_node.dom_style_attr) > 0
        inlines = str_split(dom_node.dom_style_attr, ";")
        i_idx = 0
        while i_idx < len(inlines)
            item = str_trim(inlines[i_idx])
            if len(item) > 0 and str_contains(item, ":") == 1
                parts = str_split(item, ":")
                if len(parts) >= 2
                    css_apply_declaration(style, parts[0], parts[1])
                end
            end
            i_idx = i_idx + 1
        end
    end

    return style
