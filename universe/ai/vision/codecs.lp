@! ============================================================================
@! LIPI UNIVERSE AI — VISION CODECS (universe/ai/vision/codecs.maya)
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Features: Pure Maya PPM (P2/P3/P5/P6) & BMP (24-bit/32-bit) Encoders & Decoders,
@! Synthetic Test Pattern Generators (Checkerboard, Gradients, Color Bars, Circles).
@! ============================================================================

import "universe/core/math"
import "universe/core/string"
import "universe/core/collections"
import "universe/ai/vision/image"

@! ----------------------------------------------------------------------------
@! 1. ASCII Tokenizer for Netpbm Decoders
@! ----------------------------------------------------------------------------

@fn netpbm_tokenize(content_str)
  tokens = []
  cur = ""
  i = 0
  num_items = str_len(content_str)
  in_comment = 0
  
  @while i < num_items
    code = str_byte_at(content_str, i)
    ch = str_substr(content_str, i, 1)
    
    @if in_comment == 1
      @if code == 10 || code == 13
        in_comment = 0
      @end
    @elif code == 35 @! #
      in_comment = 1
      @if str_len(cur) > 0
        tokens = tokens.push(cur)
        cur = ""
      @end
    @elif code == 32 || code == 9 || code == 10 || code == 13
      @if str_len(cur) > 0
        tokens = tokens.push(cur)
        cur = ""
      @end
    @else
      cur = string_concat(cur, ch)
    @end
    i = i + 1
  @end
  
  @if str_len(cur) > 0
    tokens = tokens.push(cur)
  @end
  return tokens
@end

@fn ppm_encode_p3(img)
  header = "P3\n" + img.width.to_str() + " " + img.height.to_str() + "\n255\n"
  body = ""
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      r = (math_clamp(image_get_pixel(img, x, y, 0) * 255.0, 0.0, 255.0)).to_int()
      g = (math_clamp(image_get_pixel(img, x, y, 1) * 255.0, 0.0, 255.0)).to_int()
      b = (math_clamp(image_get_pixel(img, x, y, 2) * 255.0, 0.0, 255.0)).to_int()
      body = body + r.to_str() + " " + g.to_str() + " " + b.to_str() + "\n"
      x = x + 1
    @end
    y = y + 1
  @end
  return header + body
@end

@fn ppm_decode_p3(content_str)
  tokens = netpbm_tokenize(content_str)
  @if tokens.len() < 4
    return image_new(0, 0, 3)
  @end
  
  @if tokens[0] != "P3"
    return image_new(0, 0, 3)
  @end
  
  w = string_to_int(tokens[1])
  h = string_to_int(tokens[2])
  max_val = string_to_int(tokens[3])
  @if max_val <= 0 max_val = 255 @end
  scale = 1.0 / (max_val * 1.0)
  
  out = image_new(w, h, 3)
  t_idx = 4
  y = 0
  @while y < h && t_idx + 2 < tokens.len()
    x = 0
    @while x < w && t_idx + 2 < tokens.len()
      r = string_to_int(tokens[t_idx]) * scale
      g = string_to_int(tokens[t_idx + 1]) * scale
      b = string_to_int(tokens[t_idx + 2]) * scale
      out = image_set_pixel(out, x, y, 0, r)
      out = image_set_pixel(out, x, y, 1, g)
      out = image_set_pixel(out, x, y, 2, b)
      t_idx = t_idx + 3
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn pgm_encode_p2(img)
  header = "P2\n" + img.width.to_str() + " " + img.height.to_str() + "\n255\n"
  body = ""
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      val = (math_clamp(image_get_pixel(img, x, y, 0) * 255.0, 0.0, 255.0)).to_int()
      body = body + val.to_str() + " "
      x = x + 1
    @end
    body = body + "\n"
    y = y + 1
  @end
  return header + body
@end

@fn pgm_decode_p2(content_str)
  tokens = netpbm_tokenize(content_str)
  @if tokens.len() < 4
    return image_new(0, 0, 1)
  @end
  
  @if tokens[0] != "P2"
    return image_new(0, 0, 1)
  @end
  
  w = string_to_int(tokens[1])
  h = string_to_int(tokens[2])
  max_val = string_to_int(tokens[3])
  @if max_val <= 0 max_val = 255 @end
  scale = 1.0 / (max_val * 1.0)
  
  out = image_new(w, h, 1)
  t_idx = 4
  y = 0
  @while y < h && t_idx < tokens.len()
    x = 0
    @while x < w && t_idx < tokens.len()
      val = string_to_int(tokens[t_idx]) * scale
      out = image_set_pixel(out, x, y, 0, val)
      t_idx = t_idx + 1
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 3. Netpbm Binary Formats (P6 RGB & P5 Grayscale)
@! ----------------------------------------------------------------------------

@fn ppm_encode_p6(img)
  w_str = int_to_str(img.width)
  h_str = int_to_str(img.height)
  header_str = string_concat("P6\n", string_concat(w_str, string_concat(" ", string_concat(h_str, "\n255\n"))))
  bytes = []
  i = 0
  hlen = str_len(header_str)
  @while i < hlen
    b_val = str_byte_at(header_str, i)
    bytes = bytes.push(b_val)
    i = i + 1
  @end
  
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      p0 = image_get_pixel(img, x, y, 0) * 255.0
      p1 = image_get_pixel(img, x, y, 1) * 255.0
      p2 = image_get_pixel(img, x, y, 2) * 255.0
      r = (math_clamp(p0, 0.0, 255.0)).to_int()
      g = (math_clamp(p1, 0.0, 255.0)).to_int()
      b = (math_clamp(p2, 0.0, 255.0)).to_int()
      bytes = bytes.push(r)
      bytes = bytes.push(g)
      bytes = bytes.push(b)
      x = x + 1
    @end
    y = y + 1
  @end
  return bytes
@end

@fn ppm_decode_p6(bytes)
  header_str = ""
  pos = 0
  num_items = bytes.len()
  newlines = 0
  
  @while pos < num_items && newlines < 3
    b = bytes[pos]
    @if b == 10 || b == 13
      newlines = newlines + 1
      header_str = header_str + "\n"
    @else
      @if b == 32
        header_str = header_str + " "
      @elif b >= 48 && b <= 57
        header_str = header_str + (b - 48).to_str()
      @elif b == 80
        header_str = header_str + "P"
      @elif b == 54
        header_str = header_str + "6"
      @end
    @end
    pos = pos + 1
  @end
  
  tokens = netpbm_tokenize(header_str)
  @if tokens.len() < 4 return image_new(0, 0, 3) @end
  
  w = string_to_int(tokens[1])
  h = string_to_int(tokens[2])
  out = image_new(w, h, 3)
  
  y = 0
  @while y < h && pos + 2 < num_items
    x = 0
    @while x < w && pos + 2 < num_items
      r = (bytes[pos] * 1.0) / 255.0
      g = (bytes[pos + 1] * 1.0) / 255.0
      b = (bytes[pos + 2] * 1.0) / 255.0
      out = image_set_pixel(out, x, y, 0, r)
      out = image_set_pixel(out, x, y, 1, g)
      out = image_set_pixel(out, x, y, 2, b)
      pos = pos + 3
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn pgm_encode_p5(img)
  w_str = int_to_str(img.width)
  h_str = int_to_str(img.height)
  header_str = string_concat("P5\n", string_concat(w_str, string_concat(" ", string_concat(h_str, "\n255\n"))))
  bytes = []
  i = 0
  hlen = str_len(header_str)
  @while i < hlen
    b_val = str_byte_at(header_str, i)
    bytes = bytes.push(b_val)
    i = i + 1
  @end
  
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      p0 = image_get_pixel(img, x, y, 0) * 255.0
      val = (math_clamp(p0, 0.0, 255.0)).to_int()
      bytes = bytes.push(val)
      x = x + 1
    @end
    y = y + 1
  @end
  return bytes
@end

@fn pgm_decode_p5(bytes)
  header_str = ""
  pos = 0
  num_items = bytes.len()
  newlines = 0
  
  @while pos < num_items && newlines < 3
    b = bytes[pos]
    @if b == 10 || b == 13
      newlines = newlines + 1
      header_str = header_str + "\n"
    @else
      @if b == 32
        header_str = header_str + " "
      @elif b >= 48 && b <= 57
        header_str = header_str + (b - 48).to_str()
      @elif b == 80
        header_str = header_str + "P"
      @elif b == 53
        header_str = header_str + "5"
      @end
    @end
    pos = pos + 1
  @end
  
  tokens = netpbm_tokenize(header_str)
  @if tokens.len() < 4 return image_new(0, 0, 1) @end
  
  w = string_to_int(tokens[1])
  h = string_to_int(tokens[2])
  out = image_new(w, h, 1)
  
  y = 0
  @while y < h && pos < num_items
    x = 0
    @while x < w && pos < num_items
      val = (bytes[pos] * 1.0) / 255.0
      out = image_set_pixel(out, x, y, 0, val)
      pos = pos + 1
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 4. Pure Maya BMP Codec (24-bit RGB & 32-bit RGBA)
@! ----------------------------------------------------------------------------

@fn u16_to_le_bytes(val)
  return [val % 256, (val / 256) % 256]
@end

@fn u32_to_le_bytes(val)
  b0 = val % 256
  b1 = (val / 256) % 256
  b2 = (val / 65536) % 256
  b3 = (val / 16777216) % 256
  return [b0, b1, b2, b3]
@end

@fn le_bytes_to_u32(bytes, offset)
  b0 = bytes[offset]
  b1 = bytes[offset + 1]
  b2 = bytes[offset + 2]
  b3 = bytes[offset + 3]
  return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)
@end

@fn le_bytes_to_u16(bytes, offset)
  b0 = bytes[offset]
  b1 = bytes[offset + 1]
  return b0 + (b1 * 256)
@end

@fn bmp_encode_24(img)
  w = img.width
  h = img.height
  row_stride = ((w * 3) + 3) / 4 * 4
  padding = row_stride - (w * 3)
  image_size = row_stride * h
  file_size = 54 + image_size
  
  bytes = []
  
  @! 1. BITMAPFILEHEADER (14 bytes)
  bytes = bytes.push(0x42) @! 'B'
  bytes = bytes.push(0x4D) @! 'M'
  bytes = list_concat(bytes, u32_to_le_bytes(file_size))
  bytes = bytes.push(0) bytes = bytes.push(0) @! Reserved 1
  bytes = bytes.push(0) bytes = bytes.push(0) @! Reserved 2
  bytes = list_concat(bytes, u32_to_le_bytes(54)) @! Pixel data offset
  
  @! 2. BITMAPINFOHEADER (40 bytes)
  bytes = list_concat(bytes, u32_to_le_bytes(40)) @! Header size
  bytes = list_concat(bytes, u32_to_le_bytes(w))  @! Width
  bytes = list_concat(bytes, u32_to_le_bytes(h))  @! Height
  bytes = list_concat(bytes, u16_to_le_bytes(1))   @! Planes
  bytes = list_concat(bytes, u16_to_le_bytes(24))  @! Bits per pixel
  bytes = list_concat(bytes, u32_to_le_bytes(0))   @! BI_RGB (uncompressed)
  bytes = list_concat(bytes, u32_to_le_bytes(image_size))
  bytes = list_concat(bytes, u32_to_le_bytes(2835)) @! 72 DPI
  bytes = list_concat(bytes, u32_to_le_bytes(2835))
  bytes = list_concat(bytes, u32_to_le_bytes(0))   @! Colors in table
  bytes = list_concat(bytes, u32_to_le_bytes(0))   @! Important colors
  
  @! 3. Pixel Data (Bottom-Up Scanlines, BGR format)
  y = h - 1
  @while y >= 0
    x = 0
    @while x < w
      r = (math_clamp(image_get_pixel(img, x, y, 0) * 255.0, 0.0, 255.0)).to_int()
      g = (math_clamp(image_get_pixel(img, x, y, 1) * 255.0, 0.0, 255.0)).to_int()
      b = (math_clamp(image_get_pixel(img, x, y, 2) * 255.0, 0.0, 255.0)).to_int()
      bytes = bytes.push(b)
      bytes = bytes.push(g)
      bytes = bytes.push(r)
      x = x + 1
    @end
    p = 0
    @while p < padding
      bytes = bytes.push(0)
      p = p + 1
    @end
    y = y - 1
  @end
  
  return bytes
@end

@fn bmp_decode_24(bytes)
  @if bytes.len() < 54 return image_new(0, 0, 3) @end
  @if bytes[0] != 0x42 || bytes[1] != 0x4D return image_new(0, 0, 3) @end
  
  offset = le_bytes_to_u32(bytes, 10)
  w = le_bytes_to_u32(bytes, 18)
  h = le_bytes_to_u32(bytes, 22)
  bpp = le_bytes_to_u16(bytes, 28)
  
  @if bpp != 24 return image_new(0, 0, 3) @end
  
  row_stride = ((w * 3) + 3) / 4 * 4
  padding = row_stride - (w * 3)
  
  out = image_new(w, h, 3)
  pos = offset
  
  y = h - 1
  @while y >= 0
    x = 0
    @while x < w
      @if pos + 2 < bytes.len()
        b = (bytes[pos] * 1.0) / 255.0
        g = (bytes[pos + 1] * 1.0) / 255.0
        r = (bytes[pos + 2] * 1.0) / 255.0
        out = image_set_pixel(out, x, y, 0, r)
        out = image_set_pixel(out, x, y, 1, g)
        out = image_set_pixel(out, x, y, 2, b)
      @end
      pos = pos + 3
      x = x + 1
    @end
    pos = pos + padding
    y = y - 1
  @end
  
  return out
@end

@fn bmp_encode_32(img)
  w = img.width
  h = img.height
  row_stride = w * 4
  image_size = row_stride * h
  file_size = 54 + image_size
  
  bytes = []
  bytes = bytes.push(0x42) bytes = bytes.push(0x4D)
  bytes = list_concat(bytes, u32_to_le_bytes(file_size))
  bytes = bytes.push(0) bytes = bytes.push(0)
  bytes = bytes.push(0) bytes = bytes.push(0)
  bytes = list_concat(bytes, u32_to_le_bytes(54))
  
  bytes = list_concat(bytes, u32_to_le_bytes(40))
  bytes = list_concat(bytes, u32_to_le_bytes(w))
  bytes = list_concat(bytes, u32_to_le_bytes(h))
  bytes = list_concat(bytes, u16_to_le_bytes(1))
  bytes = list_concat(bytes, u16_to_le_bytes(32))
  bytes = list_concat(bytes, u32_to_le_bytes(0))
  bytes = list_concat(bytes, u32_to_le_bytes(image_size))
  bytes = list_concat(bytes, u32_to_le_bytes(2835))
  bytes = list_concat(bytes, u32_to_le_bytes(2835))
  bytes = list_concat(bytes, u32_to_le_bytes(0))
  bytes = list_concat(bytes, u32_to_le_bytes(0))
  
  y = h - 1
  @while y >= 0
    x = 0
    @while x < w
      r = (math_clamp(image_get_pixel(img, x, y, 0) * 255.0, 0.0, 255.0)).to_int()
      g = (math_clamp(image_get_pixel(img, x, y, 1) * 255.0, 0.0, 255.0)).to_int()
      b = (math_clamp(image_get_pixel(img, x, y, 2) * 255.0, 0.0, 255.0)).to_int()
      a = 255
      @if img.channels >= 4
        a = (math_clamp(image_get_pixel(img, x, y, 3) * 255.0, 0.0, 255.0)).to_int()
      @end
      bytes = bytes.push(b)
      bytes = bytes.push(g)
      bytes = bytes.push(r)
      bytes = bytes.push(a)
      x = x + 1
    @end
    y = y - 1
  @end
  return bytes
@end

@fn bmp_decode_32(bytes)
  @if bytes.len() < 54 return image_new(0, 0, 4) @end
  offset = le_bytes_to_u32(bytes, 10)
  w = le_bytes_to_u32(bytes, 18)
  h = le_bytes_to_u32(bytes, 22)
  
  out = image_new(w, h, 4)
  pos = offset
  y = h - 1
  @while y >= 0
    x = 0
    @while x < w
      @if pos + 3 < bytes.len()
        b = (bytes[pos] * 1.0) / 255.0
        g = (bytes[pos + 1] * 1.0) / 255.0
        r = (bytes[pos + 2] * 1.0) / 255.0
        a = (bytes[pos + 3] * 1.0) / 255.0
        out = image_set_pixel(out, x, y, 0, r)
        out = image_set_pixel(out, x, y, 1, g)
        out = image_set_pixel(out, x, y, 2, b)
        out = image_set_pixel(out, x, y, 3, a)
      @end
      pos = pos + 4
      x = x + 1
    @end
    y = y - 1
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 5. Synthetic Test Generators
@! ----------------------------------------------------------------------------

@fn image_create_checkerboard(width, height, tile_size)
  img = image_new(width, height, 3)
  y = 0
  @while y < height
    x = 0
    @while x < width
      tile_x = x / tile_size
      tile_y = y / tile_size
      is_white = (tile_x + tile_y) % 2
      val = 0.0
      @if is_white == 0 val = 1.0 @end
      img = image_set_pixel(img, x, y, 0, val)
      img = image_set_pixel(img, x, y, 1, val)
      img = image_set_pixel(img, x, y, 2, val)
      x = x + 1
    @end
    y = y + 1
  @end
  return img
@end

@fn image_create_gradient(width, height, direction)
  img = image_new(width, height, 1)
  y = 0
  @while y < height
    x = 0
    @while x < width
      val = 0.0
      @if direction == 0
        @! Horizontal
        val = (x * 1.0) / (width * 1.0)
      @elif direction == 1
        @! Vertical
        val = (y * 1.0) / (height * 1.0)
      @else
        @! Diagonal
        val = ((x + y) * 1.0) / ((width + height) * 1.0)
      @end
      img = image_set_pixel(img, x, y, 0, val)
      x = x + 1
    @end
    y = y + 1
  @end
  return img
@end

@fn image_create_color_bars(width, height)
  img = image_new(width, height, 3)
  @! 8 bars: White, Yellow, Cyan, Green, Magenta, Red, Blue, Black
  bar_colors = [
    [1.0, 1.0, 1.0], @! White
    [1.0, 1.0, 0.0], @! Yellow
    [0.0, 1.0, 1.0], @! Cyan
    [0.0, 1.0, 0.0], @! Green
    [1.0, 0.0, 1.0], @! Magenta
    [1.0, 0.0, 0.0], @! Red
    [0.0, 0.0, 1.0], @! Blue
    [0.0, 0.0, 0.0]  @! Black
  ]
  
  bar_width = width / 8
  @if bar_width <= 0 bar_width = 1 @end
  
  y = 0
  @while y < height
    x = 0
    @while x < width
      bar_idx = x / bar_width
      @if bar_idx >= 8 bar_idx = 7 @end
      col = bar_colors[bar_idx]
      img = image_set_pixel(img, x, y, 0, col[0])
      img = image_set_pixel(img, x, y, 1, col[1])
      img = image_set_pixel(img, x, y, 2, col[2])
      x = x + 1
    @end
    y = y + 1
  @end
  return img
@end

@fn image_create_circle(width, height, cx, cy, radius)
  img = image_new(width, height, 1)
  r2 = radius * radius
  y = 0
  @while y < height
    x = 0
    @while x < width
      dx = (x - cx) * 1.0
      dy = (y - cy) * 1.0
      dist2 = (dx * dx) + (dy * dy)
      @if dist2 <= r2
        img = image_set_pixel(img, x, y, 0, 1.0)
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return img
@end
