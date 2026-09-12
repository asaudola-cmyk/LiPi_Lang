import "universe/core/string"
@! ============================================================================
@! LIPI WEB ENGINE — SOVEREIGN MARKUP PARSER & TOKENIZER (F09)
@! Module: universe/web/markup_parser.lp
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Features:
@! - High-speed lexical tokenizer for HTML5/XML sovereign tags & attributes
@! - Cascading CSS declaration & embedded <style> stylesheet parser
@! - 32-bit ARGB hex, RGB/RGBA, and Catppuccin / CSS named color parser
@! - Fault-tolerant AST builder (void elements, unclosed tag healing, entity decoder)
@! - Native desugaring to LayoutNode (Flexbox layout) and UIElement (DOM bypass)
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"
import "universe/web/frontend/layout/layout_types"

@! ============================================================================
@! 1. DATA STRUCTURES
@! ============================================================================

@struct MarkupAttribute
  attr_name: string
  attr_value: string
@end

@fn markup_attribute_new(name, val)
  return {
    attr_name: name,
    attr_value: val
  }
@end

@struct MarkupStyle
  style_display: i64        @! 0
  style_flex_dir: i64       @! 1
  style_justify: i64        @! 0
  style_align_items: i64    @! 0
  style_align_self: i64     @! 255
  style_flex_wrap: i64      @! 0
  style_position: i64       @! 0
  style_flex_grow: i64
  style_flex_shrink: i64
  style_flex_basis: i64
  style_width: i64
  style_height: i64
  style_min_width: i64
  style_min_height: i64
  style_max_width: i64
  style_max_height: i64
  style_padding_top: i64
  style_padding_right: i64
  style_padding_bottom: i64
  style_padding_left: i64
  style_margin_top: i64
  style_margin_right: i64
  style_margin_bottom: i64
  style_margin_left: i64
  style_gap: i64
  style_row_gap: i64
  style_col_gap: i64
  style_bg_color: i64       @! 32-bit ARGB
  style_color: i64          @! 32-bit ARGB
  style_border_color: i64   @! 32-bit ARGB
  style_border_width: i64
  style_border_radius: i64
  style_font_size: i64
  style_font_family: string
  style_opacity: f64
  style_z_index: i64
  style_shadow_color: i64
  style_shadow_blur: i64
  style_shadow_ox: i64
  style_shadow_oy: i64
  style_is_remote: bool
  style_remote_session: string
@end

@fn markup_style_default()
  return {
    style_display: 0,
    style_flex_dir: 1,
    style_justify: 0,
    style_align_items: 0,
    style_align_self: 255,
    style_flex_wrap: 0,
    style_position: 0,
    style_flex_grow: 0,
    style_flex_shrink: 1,
    style_flex_basis: 0,
    style_width: 0,
    style_height: 0,
    style_min_width: 0,
    style_min_height: 0,
    style_max_width: 999999,
    style_max_height: 999999,
    style_padding_top: 0,
    style_padding_right: 0,
    style_padding_bottom: 0,
    style_padding_left: 0,
    style_margin_top: 0,
    style_margin_right: 0,
    style_margin_bottom: 0,
    style_margin_left: 0,
    style_gap: 0,
    style_row_gap: 0,
    style_col_gap: 0,
    style_bg_color: 0,
    style_color: 0xFFFFFFFF,
    style_border_color: 0,
    style_border_width: 0,
    style_border_radius: 0,
    style_font_size: 14,
    style_font_family: "sans-serif",
    style_opacity: 1.0,
    style_z_index: 0,
    style_shadow_color: 0,
    style_shadow_blur: 0,
    style_shadow_ox: 0,
    style_shadow_oy: 0,
    style_is_remote: false,
    style_remote_session: ""
  }
@end

@struct MarkupNode
  node_id: i64
  tag_name: string
  is_text: bool
  text_content: string
  attributes: array         @! Array of MarkupAttribute
  style: MarkupStyle
  children: array           @! Array of MarkupNode
  raw_style_str: string
  class_names: array        @! Array of string
  id_name: string
@end

@fn markup_node_new(node_id, tag_name)
  return {
    node_id: node_id,
    tag_name: tag_name,
    is_text: false,
    text_content: "",
    attributes: [],
    style: markup_style_default(),
    children: [],
    raw_style_str: "",
    class_names: [],
    id_name: ""
  }
@end

@fn markup_node_text(node_id, text)
  return {
    node_id: node_id,
    tag_name: "#text",
    is_text: true,
    text_content: text,
    attributes: [],
    style: markup_style_default(),
    children: [],
    raw_style_str: "",
    class_names: [],
    id_name: ""
  }
@end

@struct CssRule
  selector_type: i64        @! 0
  selector_name: string
  properties: array         @! Array of MarkupAttribute (key/value strings)
@end

@fn css_rule_new(sel_type, sel_name, props)
  return {
    selector_type: sel_type,
    selector_name: sel_name,
    properties: props
  }
@end

@struct CssStylesheet
  rules: array              @! Array of CssRule
@end

@fn css_stylesheet_new()
  return {
    rules: []
  }
@end

@struct MarkupToken
  tok_kind: i64             @! 1
  tok_text: string
  tok_line: i64
  tok_col: i64
@end

@fn markup_token_new(kind, text, line, col)
  return {
    tok_kind: kind,
    tok_text: text,
    tok_line: line,
    tok_col: col
  }
@end

@! ============================================================================
@! 2. COLOR PARSING (HEX, RGB/RGBA, NAMED & CATPPUCCIN PALETTES)
@! ============================================================================

@fn hex_char_to_val(c)
  @if c >= 48 && c <= 57 return c - 48 @end
  @if c >= 65 && c <= 70 return c - 55 @end
  @if c >= 97 && c <= 102 return c - 87 @end
  return 0
@end

@fn color_parse_hex(s)
  s_len = str_len(s)
  start = 0
  @if s_len > 0 && str_char_at(s, 0) == 35 @! '#'
    start = 1
  @elif s_len > 2 && str_char_at(s, 0) == 48 && (str_char_at(s, 1) == 120 || str_char_at(s, 1) == 88) @! '0x' or '0X'
    start = 2
  @end

  hex_len = s_len - start
  @if hex_len == 3
    @! #RGB -> 0xFFRRGGBB
    r = hex_char_to_val(str_char_at(s, start))
    g = hex_char_to_val(str_char_at(s, start + 1))
    b = hex_char_to_val(str_char_at(s, start + 2))
    rr = (r * 16) + r
    gg = (g * 16) + g
    bb = (b * 16) + b
    return (255 * 16777216) + (rr * 65536) + (gg * 256) + bb
  @elif hex_len == 4
    @! #RGBA -> 0xAARRGGBB
    r = hex_char_to_val(str_char_at(s, start))
    g = hex_char_to_val(str_char_at(s, start + 1))
    b = hex_char_to_val(str_char_at(s, start + 2))
    a = hex_char_to_val(str_char_at(s, start + 3))
    rr = (r * 16) + r
    gg = (g * 16) + g
    bb = (b * 16) + b
    aa = (a * 16) + a
    return (aa * 16777216) + (rr * 65536) + (gg * 256) + bb
  @elif hex_len == 6
    @! #RRGGBB -> 0xFFRRGGBB
    r1 = hex_char_to_val(str_char_at(s, start))
    r2 = hex_char_to_val(str_char_at(s, start + 1))
    g1 = hex_char_to_val(str_char_at(s, start + 2))
    g2 = hex_char_to_val(str_char_at(s, start + 3))
    b1 = hex_char_to_val(str_char_at(s, start + 4))
    b2 = hex_char_to_val(str_char_at(s, start + 5))
    rr = (r1 * 16) + r2
    gg = (g1 * 16) + g2
    bb = (b1 * 16) + b2
    return (255 * 16777216) + (rr * 65536) + (gg * 256) + bb
  @elif hex_len == 8
    @! #RRGGBBAA or 0xAARRGGBB
    c0 = hex_char_to_val(str_char_at(s, start))
    c1 = hex_char_to_val(str_char_at(s, start + 1))
    c2 = hex_char_to_val(str_char_at(s, start + 2))
    c3 = hex_char_to_val(str_char_at(s, start + 3))
    c4 = hex_char_to_val(str_char_at(s, start + 4))
    c5 = hex_char_to_val(str_char_at(s, start + 5))
    c6 = hex_char_to_val(str_char_at(s, start + 6))
    c7 = hex_char_to_val(str_char_at(s, start + 7))
    
    b0 = (c0 * 16) + c1
    b1 = (c2 * 16) + c3
    b2 = (c4 * 16) + c5
    b3 = (c6 * 16) + c7
    
    @if start == 2
      @! 0xAARRGGBB
      return (b0 * 16777216) + (b1 * 65536) + (b2 * 256) + b3
    @else
      @! #RRGGBBAA -> 0xAARRGGBB
      return (b3 * 16777216) + (b0 * 65536) + (b1 * 256) + b2
    @end
  @end

  return 0xFF000000
@end

@fn color_parse_named(name)
  n = string_to_lower(string_trim(name))
  @if n == "transparent" return 0 @end
  @if n == "black" return 0xFF000000 @end
  @if n == "white" return 0xFFFFFFFF @end
  @if n == "red" return 0xFFFF0000 @end
  @if n == "green" return 0xFF00FF00 @end
  @if n == "blue" return 0xFF0000FF @end
  @if n == "yellow" return 0xFFFFFF00 @end
  @if n == "cyan" return 0xFF00FFFF @end
  @if n == "magenta" return 0xFFFF00FF @end
  @if n == "gray" || n == "grey" return 0xFF808080 @end
  @if n == "lightgray" || n == "lightgrey" return 0xFFD3D3D3 @end
  @if n == "darkgray" || n == "darkgrey" return 0xFFA9A9A9 @end
  @if n == "orange" return 0xFFFFA500 @end
  @if n == "purple" return 0xFF800080 @end
  @if n == "navy" return 0xFF000080 @end
  @if n == "coral" return 0xFFFF7F50 @end
  @if n == "teal" return 0xFF008080 @end
  @if n == "pink" return 0xFFFFC0CB @end
  @if n == "brown" return 0xFFA52A2A @end
  @if n == "gold" return 0xFFFFD700 @end
  @if n == "silver" return 0xFFC0C0C0 @end
  @if n == "indigo" return 0xFF4B0082 @end
  @if n == "violet" return 0xFFEE82EE @end
  @if n == "maroon" return 0xFF800000 @end

  @! Sovereign Catppuccin Palette
  @if n == "base" return 0xFF1E1E2E @end
  @if n == "mantle" return 0xFF181825 @end
  @if n == "crust" return 0xFF11111B @end
  @if n == "surface0" return 0xFF313244 @end
  @if n == "surface1" return 0xFF45475A @end
  @if n == "surface2" return 0xFF585B70 @end
  @if n == "overlay0" return 0xFF6C7086 @end
  @if n == "overlay1" return 0xFF7F849C @end
  @if n == "subtext0" return 0xFFA6ADC8 @end
  @if n == "subtext1" return 0xFFBAC2DE @end
  @if n == "text" return 0xFFCDD6F4 @end
  @if n == "lavender" return 0xFFB4BEFE @end
  @if n == "blue" return 0xFF89B4FA @end
  @if n == "sapphire" return 0xFF74C7EC @end
  @if n == "sky" return 0xFF89DCEB @end
  @if n == "teal" return 0xFF94E2D5 @end
  @if n == "green" return 0xFFA6E3A1 @end
  @if n == "yellow" return 0xFFF9E2AF @end
  @if n == "peach" return 0xFFFAB387 @end
  @if n == "maroon" return 0xFFEBA0AC @end
  @if n == "red" return 0xFFF38BA8 @end
  @if n == "mauve" return 0xFFCBA6F7 @end
  @if n == "pink" return 0xFFF5C2E7 @end
  @if n == "flamingo" return 0xFFF2CDCD @end
  @if n == "rosewater" return 0xFFF5E0DC @end

  return 0
@end

@fn color_parse(s)
  s = string_trim(s)
  s_len = str_len(s)
  @if s_len == 0 return 0 @end

  @if str_char_at(s, 0) == 35 || (s_len > 2 && str_char_at(s, 0) == 48 && (str_char_at(s, 1) == 120 || str_char_at(s, 1) == 88))
    return color_parse_hex(s)
  @end

  @! Check rgb(r, g, b) or rgba(r, g, b, a)
  @if starts_with(s, "rgb(") || starts_with(s, "rgba(")
    st = str_index_of(s, "(")
    ed = str_index_of(s, ")")
    @if st >= 0 && ed > st
      inside = string_slice(s, st + 1, ed)
      parts = string_split(inside, ",")
      @if parts.len() >= 3
        r = str_to_int(string_trim(parts[0]))
        g = str_to_int(string_trim(parts[1]))
        b = str_to_int(string_trim(parts[2]))
        a = 255
        @if parts.len() >= 4
          a_str = string_trim(parts[3])
          @if string_contains(a_str, ".")
            f = float_from_str(a_str)
            a = (f * 255.0).to_int()
          @else
            a = str_to_int(a_str)
            @if a <= 1 && str_len(a_str) == 1 && a_str != "0"
              a = 255
            @elif a > 255
              a = 255
            @end
          @end
        @end
        @if r < 0 r = 0 @end @if r > 255 r = 255 @end
        @if g < 0 g = 0 @end @if g > 255 g = 255 @end
        @if b < 0 b = 0 @end @if b > 255 b = 255 @end
        @if a < 0 a = 0 @end @if a > 255 a = 255 @end
        return (a * 16777216) + (r * 65536) + (g * 256) + b
      @end
    @end
  @end

  named = color_parse_named(s)
  @if named != 0 return named @end
  @if string_to_lower(s) == "transparent" return 0 @end

  @! Fallback to int conversion or default black
  @if string_is_digit(string_slice(s, 0, 1))
    return str_to_int(s)
  @end

  return 0xFF000000
@end

@! ============================================================================
@! 3. DIMENSION & PROPERTY PARSING
@! ============================================================================

@fn parse_dimension(val_str)
  s = string_to_lower(string_trim(val_str))
  s_len = str_len(s)
  @if s_len == 0 || s == "auto" return 0 @end
  @if s == "none" return 0 @end

  @! Extract digits and optional sign
  num_s = ""
  i = 0
  @while i < s_len
    c = str_char_at(s, i)
    @if (c >= 48 && c <= 57) || c == 45 @! '0'-'9' or '-'
      num_s = num_s + str_from_char_code(c)
    @elif c == 46 @! '.' float dot -> break before decimals
      i = s_len
    @elif c == 112 && i + 1 < s_len && str_char_at(s, i + 1) == 120 @! px
      i = s_len
    @elif c == 112 && i + 1 < s_len && str_char_at(s, i + 1) == 116 @! pt
      i = s_len
    @elif c == 37 @! %
      i = s_len
    @else
      i = s_len
    @end
    i = i + 1
  @end

  @if str_len(num_s) > 0
    return str_to_int(num_s)
  @end
  return 0
@end

@fn parse_box_shorthand(val_str)
  parts = string_split(string_trim(val_str), " ")
  clean_parts = []
  i = 0
  @while i < parts.len()
    p = string_trim(parts[i])
    @if str_len(p) > 0
      clean_parts = clean_parts.push(parse_dimension(p))
    @end
    i = i + 1
  @end

  c_len = clean_parts.len()
  @if c_len == 1
    v = clean_parts[0]
    return [v, v, v, v] @! top, right, bottom, left
  @elif c_len == 2
    v = clean_parts[0]
    h = clean_parts[1]
    return [v, h, v, h]
  @elif c_len == 3
    t = clean_parts[0]
    h = clean_parts[1]
    b = clean_parts[2]
    return [t, h, b, h]
  @elif c_len >= 4
    return [clean_parts[0], clean_parts[1], clean_parts[2], clean_parts[3]]
  @end
  return [0, 0, 0, 0]
@end

@! ============================================================================
@! 4. CSS DECLARATIONS & STYLESHEET PARSER
@! ============================================================================

@fn css_apply_property(style, key, val)
  k = string_to_lower(string_trim(key))
  v = string_trim(val)
  vl = string_to_lower(v)

  @if k == "display"
    @if vl == "flex"
      style.style_display = 0
    @elif vl == "none"
      style.style_display = 1
    @elif vl == "block"
      style.style_display = 2
    @elif vl == "grid"
      style.style_display = 3
    @elif vl == "absolute"
      style.style_display = 4
    @end
  @elif k == "flex-direction" || k == "flex-dir"
    @if vl == "row"
      style.style_flex_dir = 1
    @elif vl == "row-reverse"
      style.style_flex_dir = 2
    @elif vl == "column" || vl == "col"
      style.style_flex_dir = 3
    @elif vl == "column-reverse" || vl == "col-reverse"
      style.style_flex_dir = 4
    @end
  @elif k == "justify-content" || k == "justify"
    @if vl == "flex-start" || vl == "start"
      style.style_justify = 0
    @elif vl == "center"
      style.style_justify = 1
    @elif vl == "flex-end" || vl == "end"
      style.style_justify = 2
    @elif vl == "space-between"
      style.style_justify = 3
    @elif vl == "space-around"
      style.style_justify = 4
    @elif vl == "space-evenly"
      style.style_justify = 5
    @end
  @elif k == "align-items" || k == "align"
    @if vl == "flex-start" || vl == "start"
      style.style_align_items = 0
    @elif vl == "center"
      style.style_align_items = 1
    @elif vl == "flex-end" || vl == "end"
      style.style_align_items = 2
    @elif vl == "stretch"
      style.style_align_items = 3
    @elif vl == "baseline"
      style.style_align_items = 4
    @end
  @elif k == "align-self"
    @if vl == "auto"
      style.style_align_self = 255
    @elif vl == "flex-start" || vl == "start"
      style.style_align_self = 0
    @elif vl == "center"
      style.style_align_self = 1
    @elif vl == "flex-end" || vl == "end"
      style.style_align_self = 2
    @elif vl == "stretch"
      style.style_align_self = 3
    @end
  @elif k == "flex-wrap"
    @if vl == "nowrap"
      style.style_flex_wrap = 0
    @elif vl == "wrap"
      style.style_flex_wrap = 1
    @elif vl == "wrap-reverse"
      style.style_flex_wrap = 2
    @end
  @elif k == "position"
    @if vl == "static" || vl == "relative"
      style.style_position = 0
    @elif vl == "absolute"
      style.style_position = 2
    @end
  @elif k == "flex-grow"
    style.style_flex_grow = parse_dimension(v)
  @elif k == "flex-shrink"
    style.style_flex_shrink = parse_dimension(v)
  @elif k == "flex-basis"
    style.style_flex_basis = parse_dimension(v)
  @elif k == "flex"
    f_parts = string_split(v, " ")
    @if f_parts.len() == 1
      style.style_flex_grow = parse_dimension(f_parts[0])
    @elif f_parts.len() >= 2
      style.style_flex_grow = parse_dimension(f_parts[0])
      style.style_flex_shrink = parse_dimension(f_parts[1])
      @if f_parts.len() >= 3
        style.style_flex_basis = parse_dimension(f_parts[2])
      @end
    @end
  @elif k == "width"
    style.style_width = parse_dimension(v)
  @elif k == "height"
    style.style_height = parse_dimension(v)
  @elif k == "min-width"
    style.style_min_width = parse_dimension(v)
  @elif k == "min-height"
    style.style_min_height = parse_dimension(v)
  @elif k == "max-width"
    style.style_max_width = parse_dimension(v)
  @elif k == "max-height"
    style.style_max_height = parse_dimension(v)
  @elif k == "padding"
    box = parse_box_shorthand(v)
    style.style_padding_top = box[0]
    style.style_padding_right = box[1]
    style.style_padding_bottom = box[2]
    style.style_padding_left = box[3]
  @elif k == "padding-top"
    style.style_padding_top = parse_dimension(v)
  @elif k == "padding-right"
    style.style_padding_right = parse_dimension(v)
  @elif k == "padding-bottom"
    style.style_padding_bottom = parse_dimension(v)
  @elif k == "padding-left"
    style.style_padding_left = parse_dimension(v)
  @elif k == "margin"
    box = parse_box_shorthand(v)
    style.style_margin_top = box[0]
    style.style_margin_right = box[1]
    style.style_margin_bottom = box[2]
    style.style_margin_left = box[3]
  @elif k == "margin-top"
    style.style_margin_top = parse_dimension(v)
  @elif k == "margin-right"
    style.style_margin_right = parse_dimension(v)
  @elif k == "margin-bottom"
    style.style_margin_bottom = parse_dimension(v)
  @elif k == "margin-left"
    style.style_margin_left = parse_dimension(v)
  @elif k == "gap"
    g = parse_dimension(v)
    style.style_gap = g
    style.style_row_gap = g
    style.style_col_gap = g
  @elif k == "row-gap"
    style.style_row_gap = parse_dimension(v)
  @elif k == "column-gap" || k == "col-gap"
    style.style_col_gap = parse_dimension(v)
  @elif k == "background-color" || k == "bg-color" || k == "background" || k == "bg"
    style.style_bg_color = color_parse(v)
  @elif k == "color"
    style.style_color = color_parse(v)
  @elif k == "border-color"
    style.style_border_color = color_parse(v)
  @elif k == "border-width"
    style.style_border_width = parse_dimension(v)
  @elif k == "border-radius" || k == "radius"
    style.style_border_radius = parse_dimension(v)
  @elif k == "border"
    @! Shorthand border: 2px solid #89B4FA
    b_parts = string_split(v, " ")
    b_i = 0
    @while b_i < b_parts.len()
      bp = string_trim(b_parts[b_i])
      @if str_len(bp) > 0
        @if string_is_digit(string_slice(bp, 0, 1)) && style.style_border_width == 0
          style.style_border_width = parse_dimension(bp)
        @elif bp != "solid" && bp != "dashed" && bp != "dotted" && bp != "none"
          col = color_parse(bp)
          @if col != 0
            style.style_border_color = col
          @end
        @end
      @end
      b_i = b_i + 1
    @end
  @elif k == "box-shadow" || k == "shadow"
    @! Shorthand: 0 4px 8px #000000
    s_parts = string_split(v, " ")
    clean_s = []
    s_i = 0
    @while s_i < s_parts.len()
      sp = string_trim(s_parts[s_i])
      @if str_len(sp) > 0 clean_s = clean_s.push(sp) @end
      s_i = s_i + 1
    @end
    @if clean_s.len() >= 4
      style.style_shadow_ox = parse_dimension(clean_s[0])
      style.style_shadow_oy = parse_dimension(clean_s[1])
      style.style_shadow_blur = parse_dimension(clean_s[2])
      style.style_shadow_color = color_parse(clean_s[3])
    @elif clean_s.len() == 3
      style.style_shadow_ox = parse_dimension(clean_s[0])
      style.style_shadow_oy = parse_dimension(clean_s[1])
      style.style_shadow_blur = parse_dimension(clean_s[2])
      style.style_shadow_color = 0xFF000000
    @end
  @elif k == "font-size"
    style.style_font_size = parse_dimension(v)
  @elif k == "font-family"
    style.style_font_family = v
  @elif k == "opacity"
    style.style_opacity = float_from_str(v)
  @elif k == "z-index"
    style.style_z_index = str_to_int(v)
  @elif k == "is-remote"
    style.style_is_remote = (vl == "true" || vl == "1")
  @elif k == "remote-session" || k == "session"
    style.style_remote_session = v
  @end

  return style
@end

@fn css_parse_declarations(style_str)
  style = markup_style_default()
  decls = string_split(style_str, ";")
  i = 0
  @while i < decls.len()
    d = string_trim(decls[i])
    @if str_len(d) > 0
      colon_idx = str_index_of(d, ":")
      @if colon_idx > 0
        k = string_slice(d, 0, colon_idx)
        v = string_slice(d, colon_idx + 1, str_len(d))
        style = css_apply_property(style, k, v)
      @end
    @end
    i = i + 1
  @end
  return style
@end

@fn css_parse_stylesheet(css_text)
  sheet = css_stylesheet_new()
  s_len = str_len(css_text)
  pos = 0

  @while pos < s_len
    @! Skip whitespace
    @while pos < s_len && (str_char_at(css_text, pos) == 32 || str_char_at(css_text, pos) == 9 || str_char_at(css_text, pos) == 10 || str_char_at(css_text, pos) == 13)
      pos = pos + 1
    @end
    @if pos >= s_len pos = s_len @else
      @! Read selector until '{'
      sel_start = pos
      @while pos < s_len && str_char_at(css_text, pos) != 123 @! '{'
        pos = pos + 1
      @end
      
      @if pos < s_len && str_char_at(css_text, pos) == 123
        sel = string_trim(string_slice(css_text, sel_start, pos))
        pos = pos + 1 @! skip '{'
        
        body_start = pos
        @while pos < s_len && str_char_at(css_text, pos) != 125 @! '}'
          pos = pos + 1
        @end
        body = string_trim(string_slice(css_text, body_start, pos))
        @if pos < s_len && str_char_at(css_text, pos) == 125 pos = pos + 1 @end
        
        @! Parse properties
        props = []
        p_decls = string_split(body, ";")
        pi = 0
        @while pi < p_decls.len()
          pd = string_trim(p_decls[pi])
          @if str_len(pd) > 0
            c_idx = str_index_of(pd, ":")
            @if c_idx > 0
              pk = string_trim(string_slice(pd, 0, c_idx))
              pv = string_trim(string_slice(pd, c_idx + 1, str_len(pd)))
              props = props.push(markup_attribute_new(pk, pv))
            @end
          @end
          pi = pi + 1
        @end
        
        @! Determine selector type
        sel_type = 0 @! TAG
        sel_name = sel
        @if starts_with(sel, ".")
          sel_type = 1 @! CLASS
          sel_name = string_slice(sel, 1, str_len(sel))
        @elif starts_with(sel, "#")
          sel_type = 2 @! ID
          sel_name = string_slice(sel, 1, str_len(sel))
        @elif sel == "*"
          sel_type = 3 @! UNIVERSAL
          sel_name = "*"
        @end
        
        rule = css_rule_new(sel_type, sel_name, props)
        sheet.rules = sheet.rules.push(rule)
      @end
    @end
  @end

  return sheet
@end

@! ============================================================================
@! 5. HTML ENTITY DECODER
@! ============================================================================

@fn markup_decode_entities(s)
  @if string_contains(s, "&") == false
    return s
  @end
  
  res = ""
  s_len = str_len(s)
  i = 0
  @while i < s_len
    c = str_char_at(s, i)
    @if c == 38 @! '&'
      semi = -1
      k = i + 1
      @while k < s_len && k < i + 10
        @if str_char_at(s, k) == 59 @! ';'
          semi = k
          k = i + 10
        @end
        k = k + 1
      @end
      
      @if semi > i
        entity = string_slice(s, i, semi + 1)
        @if entity == "&lt;" res = res + "<"
        @elif entity == "&gt;" res = res + ">"
        @elif entity == "&amp;" res = res + "&"
        @elif entity == "&quot;" res = res + "\""
        @elif entity == "&apos;" res = res + "'"
        @elif entity == "&nbsp;" res = res + " "
        @elif starts_with(entity, "&#")
          num_s = string_slice(entity, 2, str_len(entity) - 1)
          code = str_to_int(num_s)
          @if code > 0
            res = res + str_from_char_code(code)
          @else
            res = res + entity
          @end
        @else
          res = res + entity
        @end
        i = semi + 1
      @else
        res = res + str_from_char_code(c)
        i = i + 1
      @end
    @else
      res = res + str_from_char_code(c)
      i = i + 1
    @end
  @end
  return res
@end

@! ============================================================================
@! 6. MARKUP TOKENIZER & AST BUILDER
@! ============================================================================

@fn is_void_element(tag)
  t = string_to_lower(tag)
  return t == "img" || t == "br" || t == "hr" || t == "input" || t == "meta" || t == "link"
@end

@fn parse_attributes(raw_attrs)
  attrs = []
  s_len = str_len(raw_attrs)
  pos = 0
  
  @while pos < s_len
    @! Skip whitespace
    @while pos < s_len && (str_char_at(raw_attrs, pos) == 32 || str_char_at(raw_attrs, pos) == 9 || str_char_at(raw_attrs, pos) == 10 || str_char_at(raw_attrs, pos) == 13)
      pos = pos + 1
    @end
    @if pos >= s_len pos = s_len @else
      @! Read attribute name
      k_start = pos
      @while pos < s_len && str_char_at(raw_attrs, pos) != 61 && str_char_at(raw_attrs, pos) != 32 && str_char_at(raw_attrs, pos) != 9 && str_char_at(raw_attrs, pos) != 47 && str_char_at(raw_attrs, pos) != 62
        pos = pos + 1
      @end
      key = string_slice(raw_attrs, k_start, pos)
      
      @! Skip whitespace
      @while pos < s_len && (str_char_at(raw_attrs, pos) == 32 || str_char_at(raw_attrs, pos) == 9)
        pos = pos + 1
      @end
      
      val = "true" @! default boolean attribute
      @if pos < s_len && str_char_at(raw_attrs, pos) == 61 @! '='
        pos = pos + 1 @! skip '='
        @while pos < s_len && (str_char_at(raw_attrs, pos) == 32 || str_char_at(raw_attrs, pos) == 9)
          pos = pos + 1
        @end
        
        @if pos < s_len
          quote = str_char_at(raw_attrs, pos)
          @if quote == 34 || quote == 39 @! '"' or '\''
            pos = pos + 1
            v_start = pos
            @while pos < s_len && str_char_at(raw_attrs, pos) != quote
              pos = pos + 1
            @end
            val = string_slice(raw_attrs, v_start, pos)
            @if pos < s_len pos = pos + 1 @end @! skip quote
          @else
            v_start = pos
            @while pos < s_len && str_char_at(raw_attrs, pos) != 32 && str_char_at(raw_attrs, pos) != 9 && str_char_at(raw_attrs, pos) != 62 && str_char_at(raw_attrs, pos) != 47
              pos = pos + 1
            @end
            val = string_slice(raw_attrs, v_start, pos)
          @end
        @end
      @end
      
      @if str_len(key) > 0
        attrs = attrs.push(markup_attribute_new(key, markup_decode_entities(val)))
      @end
    @end
  @end
  return attrs
@end

@fn parse_markup(source)
  root = markup_node_new(1, "root")
  stack = [root]
  next_id = 2
  
  stylesheets = []
  
  s_len = str_len(source)
  pos = 0
  
  @while pos < s_len
    c = str_char_at(source, pos)
    
    @if c == 60 @! '<'
      @! Check if comment <!-- ... --> or @!
      @if pos + 3 < s_len && str_char_at(source, pos + 1) == 33 && str_char_at(source, pos + 2) == 45 && str_char_at(source, pos + 3) == 45
        pos = pos + 4
        @while pos + 2 < s_len && (str_char_at(source, pos) != 45 || str_char_at(source, pos + 1) != 45 || str_char_at(source, pos + 2) != 62)
          pos = pos + 1
        @end
        pos = pos + 3
      @elif pos + 1 < s_len && str_char_at(source, pos + 1) == 47 @! Closing tag </tag>
        pos = pos + 2
        close_start = pos
        @while pos < s_len && str_char_at(source, pos) != 62
          pos = pos + 1
        @end
        close_tag = string_to_lower(string_trim(string_slice(source, close_start, pos)))
        @if pos < s_len pos = pos + 1 @end
        
        @! Stack unwinding to matching opening tag
        @if stack.len() > 1
          match_idx = -1
          si = stack.len() - 1
          @while si > 0
            n = stack[si]
            @if string_to_lower(n.tag_name) == close_tag
              match_idx = si
              si = 0
            @end
            si = si - 1
          @end
          
          @if match_idx > 0
            @! Pop down to match_idx - 1
            @while stack.len() > match_idx
              closed = stack[stack.len() - 1]
              new_st = []
              st_i = 0
              @while st_i < stack.len() - 1
                new_st = new_st.push(stack[st_i])
                st_i = st_i + 1
              @end
              stack = new_st
              parent = stack[stack.len() - 1]
              parent.children = parent.children.push(closed)
              stack[stack.len() - 1] = parent
            @end
          @end
        @end
      @else
        @! Opening tag or self-closing tag
        pos = pos + 1 @! skip '<'
        tag_start = pos
        @while pos < s_len && str_char_at(source, pos) != 32 && str_char_at(source, pos) != 9 && str_char_at(source, pos) != 10 && str_char_at(source, pos) != 13 && str_char_at(source, pos) != 62 && str_char_at(source, pos) != 47
          pos = pos + 1
        @end
        tag_name = string_slice(source, tag_start, pos)
        
        @! Read raw attributes until '>' or '/>'
        attr_start = pos
        is_self_close = false
        @while pos < s_len && str_char_at(source, pos) != 62
          @if str_char_at(source, pos) == 47 && pos + 1 < s_len && str_char_at(source, pos + 1) == 62
            is_self_close = true
            pos = pos + 1
          @end
          pos = pos + 1
        @end
        raw_attrs = string_slice(source, attr_start, pos)
        @if pos < s_len && str_char_at(source, pos) == 62 pos = pos + 1 @end
        
        @if is_void_element(tag_name) is_self_close = true @end
        
        @! Check if <style> block
        @if string_to_lower(tag_name) == "style"
          css_start = pos
          @while pos + 7 < s_len && (str_char_at(source, pos) != 60 || str_char_at(source, pos + 1) != 47 || str_char_at(source, pos + 2) != 115 || str_char_at(source, pos + 3) != 116 || str_char_at(source, pos + 4) != 121 || str_char_at(source, pos + 5) != 108 || str_char_at(source, pos + 6) != 101 || str_char_at(source, pos + 7) != 62)
            pos = pos + 1
          @end
          css_content = string_slice(source, css_start, pos)
          pos = pos + 8 @! skip </style>
          
          sheet = css_parse_stylesheet(css_content)
          stylesheets = stylesheets.push(sheet)
        @else
          node = markup_node_new(next_id, tag_name)
          next_id = next_id + 1
          
          attrs = parse_attributes(raw_attrs)
          node.attributes = attrs
          
          @! Extract class, id, style
          ai = 0
          @while ai < attrs.len()
            attr = attrs[ai]
            ak = string_to_lower(attr.attr_name)
            @if ak == "class"
              node.class_names = string_split(attr.attr_value, " ")
            @elif ak == "id"
              node.id_name = attr.attr_value
            @elif ak == "style"
              node.raw_style_str = attr.attr_value
            @end
            ai = ai + 1
          @end
          
          @if is_self_close
            parent = stack[stack.len() - 1]
            parent.children = parent.children.push(node)
            stack[stack.len() - 1] = parent
          @else
            stack = stack.push(node)
          @end
        @end
      @end
    @else
      @! Text node accumulation
      text_start = pos
      @while pos < s_len && str_char_at(source, pos) != 60
        pos = pos + 1
      @end
      raw_text = string_slice(source, text_start, pos)
      decoded_text = markup_decode_entities(raw_text)
      trimmed_text = string_trim(decoded_text)
      
      @if str_len(trimmed_text) > 0
        tnode = markup_node_text(next_id, decoded_text)
        next_id = next_id + 1
        parent = stack[stack.len() - 1]
        parent.children = parent.children.push(tnode)
        stack[stack.len() - 1] = parent
      @end
    @end
  @end
  
  @! Unwind any remaining open nodes in stack
  @while stack.len() > 1
    closed = stack[stack.len() - 1]
    new_st = []
    st_i = 0
    @while st_i < stack.len() - 1
      new_st = new_st.push(stack[st_i])
      st_i = st_i + 1
    @end
    stack = new_st
    parent = stack[stack.len() - 1]
    parent.children = parent.children.push(closed)
    stack[stack.len() - 1] = parent
  @end
  
  root = stack[0]
  
  @! Apply stylesheets across AST tree
  si = 0
  @while si < stylesheets.len()
    sheet = stylesheets[si]
    root = apply_stylesheet_recursive(root, sheet)
    si = si + 1
  @end
  
  @! Apply inline style="..." attribute (overriding stylesheet rules)
  root = apply_inline_styles_recursive(root)
  
  @! If root only has 1 main child, return that child; otherwise return root
  @if root.children.len() == 1
    return root.children[0]
  @end
  return root
@end

@fn node_matches_rule(node, rule)
  @if node.is_text return false @end
  
  @if rule.selector_type == 3 @! Universal '*'
    return true
  @elif rule.selector_type == 0 @! Tag name
    return string_to_lower(node.tag_name) == string_to_lower(rule.selector_name)
  @elif rule.selector_type == 1 @! Class
    ci = 0
    @while ci < node.class_names.len()
      @if node.class_names[ci] == rule.selector_name return true @end
      ci = ci + 1
    @end
    return false
  @elif rule.selector_type == 2 @! ID
    return node.id_name == rule.selector_name
  @end
  return false
@end

@fn apply_stylesheet_recursive(node, sheet)
  ri = 0
  @while ri < sheet.rules.len()
    rule = sheet.rules[ri]
    @if node_matches_rule(node, rule)
      pi = 0
      @while pi < rule.properties.len()
        prop = rule.properties[pi]
        node.style = css_apply_property(node.style, prop.attr_name, prop.attr_value)
        pi = pi + 1
      @end
    @end
    ri = ri + 1
  @end
  
  ci = 0
  @while ci < node.children.len()
    node.children[ci] = apply_stylesheet_recursive(node.children[ci], sheet)
    ci = ci + 1
  @end
  return node
@end

@fn apply_inline_styles_recursive(node)
  @if str_len(node.raw_style_str) > 0
    inline_style = css_parse_declarations(node.raw_style_str)
    @! Merge inline style over node.style
    decls = string_split(node.raw_style_str, ";")
    di = 0
    @while di < decls.len()
      d = string_trim(decls[di])
      @if str_len(d) > 0
        c_idx = str_index_of(d, ":")
        @if c_idx > 0
          k = string_slice(d, 0, c_idx)
          v = string_slice(d, c_idx + 1, str_len(d))
          node.style = css_apply_property(node.style, k, v)
        @end
      @end
      di = di + 1
    @end
  @end
  
  ci = 0
  @while ci < node.children.len()
    node.children[ci] = apply_inline_styles_recursive(node.children[ci])
    ci = ci + 1
  @end
  return node
@end

@! ============================================================================
@! 7. DESUGARING TO LAYOUT TREE & UI ELEMENT
@! ============================================================================

@fn desugar_to_layout_tree(node)
  lt = 1 @! LAYOUT_FLEX_ROW
  tag = string_to_lower(node.tag_name)
  
  @if tag == "div" || tag == "section" || tag == "main" || tag == "article" || tag == "header" || tag == "footer" || tag == "nav" || tag == "form" || tag == "root" || tag == "flex-col" || tag == "col" || tag == "column"
    lt = 2 @! LAYOUT_FLEX_COLUMN
  @elif tag == "flex-row" || tag == "row"
    lt = 1 @! LAYOUT_FLEX_ROW
  @elif tag == "grid"
    lt = 3 @! LAYOUT_GRID
  @elif tag == "button" || tag == "span" || tag == "p" || tag == "h1" || tag == "h2" || tag == "h3" || tag == "label" || tag == "a" || tag == "b" || tag == "i"
    lt = 1 @! LAYOUT_FLEX_ROW
  @end
  
  @if node.style.style_flex_dir == 1 lt = 1
  @elif node.style.style_flex_dir == 2 lt = 1 @! ROW_REV
  @elif node.style.style_flex_dir == 3 lt = 2 @! COLUMN
  @elif node.style.style_flex_dir == 4 lt = 2 @! COLUMN_REV
  @end
  
  @if node.style.style_display == 3 lt = 3 @! GRID
  @elif node.style.style_display == 4 lt = 0 @! ABSOLUTE
  @end
  
  lnode = layout_node_new(node.node_id, lt, node.style.style_align_items, node.style.style_justify)
  lnode.align_self = node.style.style_align_self
  lnode.flex_wrap = node.style.style_flex_wrap
  lnode.flex_grow = node.style.style_flex_grow
  lnode.flex_shrink = node.style.style_flex_shrink
  lnode.flex_basis = node.style.style_flex_basis
  
  lnode.pref_width = node.style.style_width
  lnode.pref_height = node.style.style_height
  lnode.min_width = node.style.style_min_width
  lnode.min_height = node.style.style_min_height
  lnode.max_width = node.style.style_max_width
  lnode.max_height = node.style.style_max_height
  
  lnode.padding = edge_insets_ltrb(node.style.style_padding_left, node.style.style_padding_top, node.style.style_padding_right, node.style.style_padding_bottom)
  lnode.margin = edge_insets_ltrb(node.style.style_margin_left, node.style.style_margin_top, node.style.style_margin_right, node.style.style_margin_bottom)
  
  lnode.gap = node.style.style_gap
  lnode.row_gap = node.style.style_row_gap
  lnode.column_gap = node.style.style_col_gap
  
  @if node.style.style_position == 2
    lnode.position_type = POSITION_ABSOLUTE()
  @end
  
  @if node.is_text
    @! Intrinsic measurement for text
    t_len = str_len(node.text_content)
    char_w = 7
    char_h = 14
    @if lnode.pref_width <= 0 lnode.pref_width = t_len * char_w @end
    @if lnode.pref_height <= 0 lnode.pref_height = char_h @end
  @end
  
  @! Button default padding and size
  @if tag == "button" && lnode.pref_height <= 0
    @if lnode.padding.top == 0 && lnode.padding.bottom == 0
      lnode.padding = edge_insets_symmetric(8, 16)
    @end
  @end
  
  ci = 0
  @while ci < node.children.len()
    ch_lay = desugar_to_layout_tree(node.children[ci])
    lnode.children = lnode.children.push(ch_lay)
    ci = ci + 1
  @end
  
  return lnode
@end

@fn desugar_to_ui_element(node)
  @! Create UIElement matching struct in universe/web/frontend/mod.lp
  elem_text = ""
  @if node.is_text
    elem_text = node.text_content
  @elif node.children.len() == 1 && node.children[0].is_text
    elem_text = node.children[0].text_content
  @end
  
  elem_children = []
  ci = 0
  @while ci < node.children.len()
    ch = node.children[ci]
    @if ch.is_text == false
      elem_children = elem_children.push(desugar_to_ui_element(ch))
    @end
    ci = ci + 1
  @end
  
  return {
    elem_id: node.node_id,
    elem_x: 0,
    elem_y: 0,
    elem_width: node.style.style_width,
    elem_height: node.style.style_height,
    elem_bg_color: node.style.style_bg_color,
    elem_border_color: node.style.style_border_color,
    elem_border_width: node.style.style_border_width,
    elem_border_radius: node.style.style_border_radius,
    elem_text: elem_text,
    elem_text_size: node.style.style_font_size,
    elem_text_color: node.style.style_color,
    elem_shadow_color: node.style.style_shadow_color,
    elem_shadow_blur: node.style.style_shadow_blur,
    elem_shadow_ox: node.style.style_shadow_ox,
    elem_shadow_oy: node.style.style_shadow_oy,
    elem_is_remote: node.style.style_is_remote,
    elem_remote_session: node.style.style_remote_session,
    elem_is_clickable: true,
    elem_z_index: node.style.style_z_index,
    elem_clip_bounds: [],
    elem_children: elem_children
  }
@end

@fn markup_parse(source)
  ast = parse_markup(source)
  return desugar_to_layout_tree(ast)
@end

@! ============================================================================
@! 8. AST QUERY & HELPER UTILITIES
@! ============================================================================

@fn markup_find_by_id_recursive(node, id_name)
  @if node.id_name == id_name return node @end
  
  ci = 0
  @while ci < node.children.len()
    res = markup_find_by_id_recursive(node.children[ci], id_name)
    @if res != 0 return res @end
    ci = ci + 1
  @end
  return 0
@end

@fn markup_find_by_id(root, id_name)
  return markup_find_by_id_recursive(root, id_name)
@end

@fn markup_find_by_tag_recursive(node, tag_name, acc)
  @if string_to_lower(node.tag_name) == string_to_lower(tag_name)
    acc = acc.push(node)
  @end
  
  ci = 0
  @while ci < node.children.len()
    acc = markup_find_by_tag_recursive(node.children[ci], tag_name, acc)
    ci = ci + 1
  @end
  return acc
@end

@fn markup_find_by_tag(root, tag_name)
  return markup_find_by_tag_recursive(root, tag_name, [])
@end

@fn markup_find_by_class_recursive(node, class_name, acc)
  ci = 0
  has_class = false
  @while ci < node.class_names.len()
    @if node.class_names[ci] == class_name
      has_class = true
      ci = node.class_names.len()
    @end
    ci = ci + 1
  @end
  
  @if has_class
    acc = acc.push(node)
  @end
  
  i = 0
  @while i < node.children.len()
    acc = markup_find_by_class_recursive(node.children[i], class_name, acc)
    i = i + 1
  @end
  return acc
@end

@fn markup_find_by_class(root, class_name)
  return markup_find_by_class_recursive(root, class_name, [])
@end
