@! ============================================================================
@! MAYA NATIVE GUI — BITMAP FONT RENDERER
@! ============================================================================

import "universe/gui/framebuffer"

@fn font_load_default()
  return {
    char_width: 8,
    char_height: 16,
    bitmaps: []
  }
@end

@fn font_get_glyph_row(ascii_code, row)
  @! Basic 8x8 font pattern bitmasks for ASCII characters
  @if ascii_code >= 48 && ascii_code <= 57 @! Digits 0-9
    @if row == 0 || row == 6 return 60 @! 00111100
    @if row == 3 return 102            @! 01100110
    return 102
  @elif (ascii_code >= 65 && ascii_code <= 90) || (ascii_code >= 97 && ascii_code <= 122) @! Letters A-Z, a-z
    @if row == 0 return 60
    @if row == 3 return 126
    return 102
  @elif ascii_code == 32 @! Space
    return 0
  @end
  @! Default glyph border
  @if row == 0 || row == 7 return 255 @end
  return 129
@end

@fn font_draw_char(fb, font, x, y, ch, color)
  code = 65
  @if ch != "" && ch != none
    code = ch.to_str()[0]
  @end
  
  r = 0
  @while r < 8
    row_bits = font_get_glyph_row(code, r)
    c = 0
    @while c < 8
      bit = (row_bits >> (7 - c)) & 1
      @if bit == 1
        fb_draw_pixel(fb, x + c, y + r, color)
      @end
      c = c + 1
    @end
    r = r + 1
  @end
  return 1
@end

@fn font_draw_text(fb, font, x, y, text, color)
  i = 0
  len = text.len()
  current_x = x
  
  @while i < len
    ch = text[i]
    font_draw_char(fb, font, current_x, y, ch, color)
    current_x = current_x + font.char_width
    i = i + 1
  @end
  
  return 1
@end
