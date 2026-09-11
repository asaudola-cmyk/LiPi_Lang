@fn maya_pow2(n)
  @if n <= 0 return 1 @end
  res = 1
  i = 0
  @while i < n
    res = res * 2
    i = i + 1
  @end
  return res
@end

@! ============================================================================
@! MAYA NATIVE GUI FRAMEWORK — BITMAP FONT & TEXT RENDERER
@! Module: universe/gui/font.maya
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Features:
@! - Monospace 8x16 ASCII Bitmap Font Table (ASCII 32..126)
@! - Fast bitmask glyph row lookup
@! - Text bounding box measurement
@! - Clipped and Ellipsis text rasterization
@! ============================================================================

import "universe/gui/canvas"
import "universe/core/string"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURE DEFINITIONS
@! ----------------------------------------------------------------------------

@struct BitmapFont
  char_width: i64
  char_height: i64
  baseline: i64
  glyph_table: array
@end

@struct TextSize
  width: i64
  height: i64
@end

@! ----------------------------------------------------------------------------
@! 2. FONT CONSTRUCTOR
@! ----------------------------------------------------------------------------

@fn text_size_new(w, h)
  return {
    width: w,
    height: h
  }
@end

@fn font_default()
  return {
    char_width: 8,
    char_height: 16,
    baseline: 12,
    glyph_table: []
  }
@end

@! ----------------------------------------------------------------------------
@! 3. BITMAP GLYPH BITMASK PATTERNS (8x16 MONOSPACE)
@! ----------------------------------------------------------------------------

@fn font_get_glyph_row(ascii_code, row)
  @if row < 0 || row >= 16
    return 0
  @end
  
  @! Map 16 rows to 7-row core pattern (rows 1..13)
  r = (row - 1) / 2
  @if r < 0 r = 0 @end
  @if r > 6 r = 6 @end
  
  @! Space (32)
  @if ascii_code == 32
    return 0
  @end
  
  @if row == 0
    return 255
  @end
  
  @! Digits 0-9 (48..57)
  @if ascii_code == 48 @! '0'
    @if r == 0 || r == 6 return 60 @end
    @if r == 1 || r == 5 return 102 @end
    @if r == 2 return 110 @end
    @if r == 3 return 102 @end
    @if r == 4 return 118 @end
    return 102
  @elif ascii_code == 49 @! '1'
    @if r == 0 return 24 @end
    @if r == 1 return 56 @end
    @if r == 6 return 126 @end
    return 24
  @elif ascii_code == 50 @! '2'
    @if r == 0 return 60 @end
    @if r == 1 return 102 @end
    @if r == 2 return 12 @end
    @if r == 3 return 24 @end
    @if r == 4 return 48 @end
    @if r == 5 return 96 @end
    return 126
  @elif ascii_code == 51 @! '3'
    @if r == 0 || r == 6 return 60 @end
    @if r == 1 || r == 5 return 102 @end
    @if r == 3 return 56 @end
    return 12
  @elif ascii_code == 52 @! '4'
    @if r == 0 || r == 1 || r == 2 return 102 @end
    @if r == 3 return 126 @end
    return 12
  @elif ascii_code == 53 @! '5'
    @if r == 0 return 126 @end
    @if r == 1 return 96 @end
    @if r == 2 return 124 @end
    @if r == 3 return 6 @end
    @if r == 4 || r == 5 return 102 @end
    return 60
  @elif ascii_code == 54 @! '6'
    @if r == 0 return 60 @end
    @if r == 1 return 96 @end
    @if r == 2 return 124 @end
    @if r == 3 || r == 4 || r == 5 return 102 @end
    return 60
  @elif ascii_code == 55 @! '7'
    @if r == 0 return 126 @end
    @if r == 1 return 12 @end
    @if r == 2 return 24 @end
    @if r == 3 return 48 @end
    return 48
  @elif ascii_code == 56 @! '8'
    @if r == 0 || r == 3 || r == 6 return 60 @end
    return 102
  @elif ascii_code == 57 @! '9'
    @if r == 0 return 60 @end
    @if r == 1 || r == 2 return 102 @end
    @if r == 3 return 62 @end
    @if r == 4 return 6 @end
    @if r == 5 return 12 @end
    return 56
  @end
  
  @! Uppercase Letters A-Z (65..90)
  @if ascii_code == 65 @! 'A'
    @if r == 0 return 60 @end
    @if r == 3 return 126 @end
    return 102
  @elif ascii_code == 66 @! 'B'
    @if r == 0 || r == 3 || r == 6 return 124 @end
    return 102
  @elif ascii_code == 67 @! 'C'
    @if r == 0 || r == 6 return 60 @end
    return 96
  @elif ascii_code == 68 @! 'D'
    @if r == 0 || r == 6 return 120 @end
    return 102
  @elif ascii_code == 69 @! 'E'
    @if r == 0 || r == 6 return 126 @end
    @if r == 3 return 120 @end
    return 96
  @elif ascii_code == 70 @! 'F'
    @if r == 0 return 126 @end
    @if r == 3 return 120 @end
    return 96
  @elif ascii_code == 71 @! 'G'
    @if r == 0 || r == 6 return 60 @end
    @if r == 3 return 110 @end
    @if r == 4 || r == 5 return 102 @end
    return 96
  @elif ascii_code == 72 @! 'H'
    @if r == 3 return 126 @end
    return 102
  @elif ascii_code == 73 @! 'I'
    @if r == 0 || r == 6 return 60 @end
    return 24
  @elif ascii_code == 74 @! 'J'
    @if r == 0 return 30 @end
    @if r == 5 return 102 @end
    @if r == 6 return 60 @end
    return 12
  @elif ascii_code == 75 @! 'K'
    @if r == 0 || r == 6 return 102 @end
    @if r == 1 || r == 5 return 108 @end
    @if r == 2 || r == 4 return 120 @end
    return 112
  @elif ascii_code == 76 @! 'L'
    @if r == 6 return 126 @end
    return 96
  @elif ascii_code == 77 @! 'M'
    @if r == 0 return 99 @end
    @if r == 1 return 119 @end
    @if r == 2 return 91 @end
    return 99
  @elif ascii_code == 78 @! 'N'
    @if r == 1 return 118 @end
    @if r == 2 return 126 @end
    @if r == 3 return 110 @end
    return 102
  @elif ascii_code == 79 @! 'O'
    @if r == 0 || r == 6 return 60 @end
    return 102
  @elif ascii_code == 80 @! 'P'
    @if r == 0 || r == 3 return 124 @end
    @if r == 1 || r == 2 return 102 @end
    return 96
  @elif ascii_code == 81 @! 'Q'
    @if r == 0 return 60 @end
    @if r == 5 return 110 @end
    @if r == 6 return 59 @end
    return 102
  @elif ascii_code == 82 @! 'R'
    @if r == 0 || r == 3 return 124 @end
    @if r == 1 || r == 2 return 102 @end
    @if r == 4 return 108 @end
    @if r == 5 || r == 6 return 102 @end
    return 96
  @elif ascii_code == 83 @! 'S'
    @if r == 0 || r == 3 || r == 6 return 60 @end
    @if r == 1 || r == 2 return 96 @end
    return 6
  @elif ascii_code == 84 @! 'T'
    @if r == 0 return 126 @end
    return 24
  @elif ascii_code == 85 @! 'U'
    @if r == 6 return 60 @end
    return 102
  @elif ascii_code == 86 @! 'V'
    @if r == 4 || r == 5 return 60 @end
    @if r == 6 return 24 @end
    return 102
  @elif ascii_code == 87 @! 'W'
    @if r == 4 return 91 @end
    @if r == 5 return 119 @end
    @if r == 6 return 99 @end
    return 99
  @elif ascii_code == 88 @! 'X'
    @if r == 0 || r == 6 return 102 @end
    @if r == 1 || r == 5 return 60 @end
    @if r == 2 || r == 4 return 24 @end
    return 24
  @elif ascii_code == 89 @! 'Y'
    @if r == 0 || r == 1 return 102 @end
    @if r == 2 return 60 @end
    return 24
  @elif ascii_code == 90 @! 'Z'
    @if r == 0 || r == 6 return 126 @end
    @if r == 1 return 12 @end
    @if r == 2 return 24 @end
    @if r == 3 return 48 @end
    @if r == 4 return 96 @end
    return 96
  @end
  
  @! Lowercase Letters a-z (97..122)
  @if ascii_code == 97 @! 'a'
    @if r == 2 return 60 @end
    @if r == 3 return 6 @end
    @if r == 4 return 62 @end
    @if r == 5 return 102 @end
    @if r == 6 return 59 @end
    return 0
  @elif ascii_code == 98 @! 'b'
    @if r == 0 || r == 1 return 96 @end
    @if r == 2 || r == 6 return 124 @end
    return 102
  @elif ascii_code == 99 @! 'c'
    @if r == 2 || r == 6 return 60 @end
    @if r == 3 || r == 4 || r == 5 return 96 @end
    return 0
  @elif ascii_code == 100 @! 'd'
    @if r == 0 || r == 1 return 6 @end
    @if r == 2 || r == 6 return 62 @end
    return 102
  @elif ascii_code == 101 @! 'e'
    @if r == 2 || r == 6 return 60 @end
    @if r == 3 return 102 @end
    @if r == 4 return 126 @end
    @if r == 5 return 96 @end
    return 0
  @elif ascii_code == 102 @! 'f'
    @if r == 0 return 28 @end
    @if r == 1 return 48 @end
    @if r == 2 return 120 @end
    return 48
  @elif ascii_code == 103 @! 'g'
    @if r == 2 || r == 5 return 62 @end
    @if r == 3 || r == 4 return 102 @end
    @if r == 6 return 60 @end
    return 0
  @elif ascii_code == 104 @! 'h'
    @if r == 0 || r == 1 return 96 @end
    @if r == 2 return 124 @end
    return 102
  @elif ascii_code == 105 @! 'i'
    @if r == 0 return 24 @end
    @if r == 1 return 0 @end
    @if r == 6 return 60 @end
    return 24
  @elif ascii_code == 106 @! 'j'
    @if r == 0 return 12 @end
    @if r == 1 return 0 @end
    @if r == 6 return 56 @end
    return 12
  @elif ascii_code == 107 @! 'k'
    @if r == 0 || r == 1 return 96 @end
    @if r == 2 || r == 6 return 102 @end
    @if r == 3 || r == 5 return 108 @end
    return 120
  @elif ascii_code == 108 @! 'l'
    @if r == 6 return 60 @end
    return 24
  @elif ascii_code == 109 @! 'm'
    @if r == 2 return 110 @end
    @if r == 3 return 127 @end
    @if r == 4 return 107 @end
    return 99
  @elif ascii_code == 110 @! 'n'
    @if r == 2 return 124 @end
    return 102
  @elif ascii_code == 111 @! 'o'
    @if r == 2 || r == 6 return 60 @end
    return 102
  @elif ascii_code == 112 @! 'p'
    @if r == 2 || r == 4 return 124 @end
    @if r == 3 return 102 @end
    return 96
  @elif ascii_code == 113 @! 'q'
    @if r == 2 || r == 4 return 62 @end
    @if r == 3 return 102 @end
    return 6
  @elif ascii_code == 114 @! 'r'
    @if r == 2 return 92 @end
    @if r == 3 return 102 @end
    return 96
  @elif ascii_code == 115 @! 's'
    @if r == 2 || r == 4 || r == 6 return 60 @end
    @if r == 3 return 96 @end
    return 6
  @elif ascii_code == 116 @! 't'
    @if r == 0 || r == 1 return 48 @end
    @if r == 2 return 120 @end
    @if r == 6 return 28 @end
    return 48
  @elif ascii_code == 117 @! 'u'
    @if r == 6 return 62 @end
    return 102
  @elif ascii_code == 118 @! 'v'
    @if r == 5 return 60 @end
    @if r == 6 return 24 @end
    return 102
  @elif ascii_code == 119 @! 'w'
    @if r == 5 return 107 @end
    @if r == 6 return 54 @end
    return 99
  @elif ascii_code == 120 @! 'x'
    @if r == 2 || r == 6 return 102 @end
    @if r == 3 || r == 5 return 60 @end
    return 24
  @elif ascii_code == 121 @! 'y'
    @if r == 2 || r == 3 return 102 @end
    @if r == 4 return 62 @end
    @if r == 5 return 6 @end
    return 60
  @elif ascii_code == 122 @! 'z'
    @if r == 2 || r == 6 return 126 @end
    @if r == 3 return 12 @end
    @if r == 4 return 24 @end
    return 48
  @end
  
  @! Symbols and Punctuation
  @if ascii_code == 43 @! '+'
    @if r == 3 return 126 @end
    @if r == 1 || r == 2 || r == 4 || r == 5 return 24 @end
    return 0
  @elif ascii_code == 45 @! '-'
    @if r == 3 return 126 @end
    return 0
  @elif ascii_code == 42 @! '*'
    @if r == 1 || r == 5 return 102 @end
    @if r == 2 || r == 4 return 60 @end
    @if r == 3 return 126 @end
    return 0
  @elif ascii_code == 47 @! '/'
    @if r == 0 return 6 @end
    @if r == 1 return 12 @end
    @if r == 2 return 24 @end
    @if r == 3 return 48 @end
    @if r == 4 return 96 @end
    return 96
  @elif ascii_code == 61 @! '='
    @if r == 2 || r == 4 return 126 @end
    return 0
  @elif ascii_code == 46 @! '.'
    @if r == 6 return 24 @end
    return 0
  @elif ascii_code == 58 @! ':'
    @if r == 2 || r == 5 return 24 @end
    return 0
  @elif ascii_code == 59 @! ';'
    @if r == 2 return 24 @end
    @if r == 5 return 24 @end
    @if r == 6 return 48 @end
    return 0
  @elif ascii_code == 44 @! ','
    @if r == 5 return 24 @end
    @if r == 6 return 48 @end
    return 0
  @elif ascii_code == 33 @! '!'
    @if r == 5 return 0 @end
    @if r == 6 return 24 @end
    return 24
  @elif ascii_code == 63 @! '?'
    @if r == 0 return 60 @end
    @if r == 1 return 102 @end
    @if r == 2 return 12 @end
    @if r == 3 return 24 @end
    @if r == 4 return 0 @end
    @if r == 6 return 24 @end
    return 0
  @elif ascii_code == 37 @! '%'
    @if r == 0 return 98 @end
    @if r == 1 return 100 @end
    @if r == 2 return 8 @end
    @if r == 3 return 16 @end
    @if r == 4 return 38 @end
    @if r == 5 return 70 @end
    return 0
  @elif ascii_code == 40 @! '('
    @if r == 0 || r == 6 return 12 @end
    @if r == 1 || r == 5 return 24 @end
    return 48
  @elif ascii_code == 41 @! ')'
    @if r == 0 || r == 6 return 48 @end
    @if r == 1 || r == 5 return 24 @end
    return 12
  @elif ascii_code == 91 @! '['
    @if r == 0 || r == 6 return 60 @end
    return 48
  @elif ascii_code == 93 @! ']'
    @if r == 0 || r == 6 return 60 @end
    return 12
  @elif ascii_code == 123 @! '{'
    @if r == 0 || r == 6 return 14 @end
    @if r == 1 || r == 5 return 24 @end
    @if r == 3 return 48 @end
    return 24
  @elif ascii_code == 125 @! '}'
    @if r == 0 || r == 6 return 112 @end
    @if r == 1 || r == 5 return 24 @end
    @if r == 3 return 12 @end
    return 24
  @elif ascii_code == 60 @! '<'
    @if r == 1 || r == 5 return 12 @end
    @if r == 2 || r == 4 return 24 @end
    @if r == 3 return 48 @end
    return 0
  @elif ascii_code == 62 @! '>'
    @if r == 1 || r == 5 return 48 @end
    @if r == 2 || r == 4 return 24 @end
    @if r == 3 return 12 @end
    return 0
  @elif ascii_code == 95 @! '_'
    @if r == 6 return 255 @end
    return 0
  @elif ascii_code == 124 @! '|'
    return 24
  @elif ascii_code == 34 @! '"'
    @if r == 0 || r == 1 return 102 @end
    return 0
  @elif ascii_code == 39 @! '\''
    @if r == 0 return 24 @end
    @if r == 1 return 48 @end
    return 0
  @elif ascii_code == 94 @! '^'
    @if r == 0 return 24 @end
    @if r == 1 return 60 @end
    @if r == 2 return 102 @end
    return 0
  @elif ascii_code == 126 @! '~'
    @if r == 1 return 54 @end
    @if r == 2 return 92 @end
    return 0
  @elif ascii_code == 64 @! '@'
    @if r == 0 || r == 6 return 60 @end
    @if r == 1 return 66 @end
    @if r == 2 return 153 @end
    @if r == 3 return 165 @end
    return 66
  @elif ascii_code == 35 @! '#'
    @if r == 1 || r == 4 return 126 @end
    return 36
  @elif ascii_code == 36 @! '$'
    @if r == 0 || r == 6 return 24 @end
    @if r == 1 || r == 3 || r == 5 return 60 @end
    @if r == 2 return 96 @end
    return 6
  @end
  
  @! Default box border for any other unmapped characters
  @if r == 0 || r == 6 return 255 @end
  return 129
@end

@! ----------------------------------------------------------------------------
@! 4. TEXT MEASUREMENT & RASTERIZATION
@! ----------------------------------------------------------------------------

@fn font_measure_text(font, text)
  num_items = str_len(text)
  w = num_items * font.char_width
  h = font.char_height
  return text_size_new(w, h)
@end

@fn font_draw_char(canvas, font, x, y, ch, color)
  code = 32
  @if ch != "" && ch != none
    code = str_char_at(ch, 0)
  @end
  
  row = 0
  @while row < font.char_height
    row_bits = font_get_glyph_row(code, row)
    col = 0
    @while col < font.char_width
      p = maya_pow2(7 - col)
      d = row_bits / p
      bit = d & 1
      @if bit == 1
        canvas = canvas_set_pixel(canvas, x + col, y + row, color)
      @end
      col = col + 1
    @end
    row = row + 1
  @end
  
  canvas = canvas_add_dirty_rect(canvas, x, y, font.char_width, font.char_height)
  return canvas
@end

@fn font_draw_text(canvas, font, x, y, text, color)
  num_items = str_len(text)
  i = 0
  cur_x = x
  @while i < num_items
    ch = str_substr(text, i, i + 1)
    canvas = font_draw_char(canvas, font, cur_x, y, ch, color)
    cur_x = cur_x + font.char_width
    i = i + 1
  @end
  
  canvas = canvas_add_dirty_rect(canvas, x, y, cur_x - x, font.char_height)
  return canvas
@end

@fn font_draw_text_clipped(canvas, font, x, y, text, color, max_w)
  num_items = str_len(text)
  total_w = num_items * font.char_width
  
  @if total_w <= max_w
    return font_draw_text(canvas, font, x, y, text, color)
  @end
  
  @! Truncate with ellipsis ("...")
  ellipsis_w = 3 * font.char_width
  avail_w = max_w - ellipsis_w
  @if avail_w <= 0
    max_chars = max_w / font.char_width
    @if max_chars <= 0 return canvas @end
    sub = str_substr(text, 0, max_chars)
    return font_draw_text(canvas, font, x, y, sub, color)
  @end
  
  max_chars = avail_w / font.char_width
  sub = str_substr(text, 0, max_chars) + "..."
  return font_draw_text(canvas, font, x, y, sub, color)
@end
