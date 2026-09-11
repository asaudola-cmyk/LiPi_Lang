@! ============================================================================
@! MAYA UNIVERSE AI — VISION IMAGE REPRESENTATION & COLOR CONVERSIONS
@! 100% Written in Pure Maya Language — Zero External Dependencies
@! Features: Multi-channel Image Struct (HWC), Coordinate Indexing, Color Spaces
@! (RGB, Grayscale, HSV, RGBA), Channel Slicing, Tensor & Framebuffer Interop.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/ai/tensor"

@! ----------------------------------------------------------------------------
@! 1. Core Image Data Structure
@! ----------------------------------------------------------------------------

@fn image_new(width, height, channels)
  total = width * height * channels
  data = []
  i = 0
  @while i < total
    data = data.push(0.0)
    i = i + 1
  @end
  return {
    width: width,
    height: height,
    channels: channels,
    data: data
  }
@end

@fn image_from_data(width, height, channels, data)
  return {
    width: width,
    height: height,
    channels: channels,
    data: data
  }
@end

@fn image_clone(img)
  new_data = []
  num_items = img.data.len()
  i = 0
  @while i < num_items
    new_data = new_data.push(img.data[i] + 0.0)
    i = i + 1
  @end
  return {
    width: img.width,
    height: img.height,
    channels: img.channels,
    data: new_data
  }
@end

@! ----------------------------------------------------------------------------
@! 2. Pixel Access & Coordinate Indexing (Row-Major HWC)
@! ----------------------------------------------------------------------------

@fn image_get_pixel(img, x, y, c)
  @if x < 0 || x >= img.width || y < 0 || y >= img.height || c < 0 || c >= img.channels
    return 0.0
  @end
  idx = ((y * img.width) + x) * img.channels + c
  return img.data[idx]
@end

@fn image_set_pixel(img, x, y, c, val)
  @if x >= 0 && x < img.width && y >= 0 && y < img.height && c >= 0 && c < img.channels
    idx = ((y * img.width) + x) * img.channels + c
    img.data = list_set(img.data, idx, val)
  @end
  return img
@end

@fn image_get_pixel_clamped(img, x, y, c)
  cx = x
  @if cx < 0 cx = 0 @end
  @if cx >= img.width cx = img.width - 1 @end
  
  cy = y
  @if cy < 0 cy = 0 @end
  @if cy >= img.height cy = img.height - 1 @end
  
  cc = c
  @if cc < 0 cc = 0 @end
  @if cc >= img.channels cc = img.channels - 1 @end
  
  idx = ((cy * img.width) + cx) * img.channels + cc
  return img.data[idx]
@end

@! ----------------------------------------------------------------------------
@! 3. Channel Slicing & Extraction
@! ----------------------------------------------------------------------------

@fn image_get_channel(img, c)
  out = image_new(img.width, img.height, 1)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      val = image_get_pixel(img, x, y, c) + 0.0
      out = image_set_pixel(out, x, y, 0, val)
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_set_channel(img, c, chan_img)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      val = image_get_pixel(chan_img, x, y, 0) + 0.0
      img = image_set_pixel(img, x, y, c, val)
      x = x + 1
    @end
    y = y + 1
  @end
  return img
@end

@! ----------------------------------------------------------------------------
@! 4. Color Space Conversions
@! ----------------------------------------------------------------------------

@! 4.1 RGB to Grayscale (ITU-R BT.601: Y = 0.299*R + 0.587*G + 0.114*B)
@fn image_rgb_to_grayscale(img)
  out = image_new(img.width, img.height, 1)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      r = image_get_pixel(img, x, y, 0)
      g = image_get_pixel(img, x, y, 1)
      b = image_get_pixel(img, x, y, 2)
      gray = (r * 0.299) + (g * 0.587) + (b * 0.114)
      out = image_set_pixel(out, x, y, 0, gray)
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@! 4.2 Grayscale to RGB (Replicate Channel 3x)
@fn image_grayscale_to_rgb(img)
  out = image_new(img.width, img.height, 3)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      g = image_get_pixel(img, x, y, 0) + 0.0
      out = image_set_pixel(out, x, y, 0, g)
      out = image_set_pixel(out, x, y, 1, g)
      out = image_set_pixel(out, x, y, 2, g)
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@! 4.3 RGB to HSV Conversion
@fn rgb_to_hsv_pixel(r, g, b)
  cmax = r
  @if g > cmax cmax = g @end
  @if b > cmax cmax = b @end
  cmin = r
  @if g < cmin cmin = g @end
  @if b < cmin cmin = b @end
  delta = cmax - cmin
  h = 0.0
  @if delta > 0.000001
    inv_d = 1.0 / delta
    @if cmax == r
      diff_gb = (g - b) * inv_d
      h = 60.0 * diff_gb
      @while h < 0.0
        h = h + 360.0
      @end
      @while h >= 360.0
        h = h - 360.0
      @end
    @elif cmax == g
      diff_br = ((b - r) * inv_d) + 2.0
      h = 60.0 * diff_br
    @else
      diff_rg = ((r - g) * inv_d) + 4.0
      h = 60.0 * diff_rg
    @end
  @end
  s = 0.0
  @if cmax > 0.000001
    inv_c = 1.0 / cmax
    s = delta * inv_c
  @end
  v = cmax
  h_norm = h * (1.0 / 360.0)
  return [h_norm, s, v]
@end

@fn image_rgb_to_hsv(img)
  out = image_new(img.width, img.height, 3)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      r = image_get_pixel(img, x, y, 0)
      g = image_get_pixel(img, x, y, 1)
      b = image_get_pixel(img, x, y, 2)
      hsv = rgb_to_hsv_pixel(r, g, b)
      h0 = hsv[0]
      h1 = hsv[1]
      h2 = hsv[2]
      out = image_set_pixel(out, x, y, 0, h0)
      out = image_set_pixel(out, x, y, 1, h1)
      out = image_set_pixel(out, x, y, 2, h2)
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@! 4.4 HSV to RGB Conversion
@fn hsv_to_rgb_pixel(h_norm, s, v)
  h = h_norm * 360.0
  @if s <= 0.000001
    return [v, v, v]
  @end
  
  sector = 0
  @if h >= 300.0
    sector = 5
  @elif h >= 240.0
    sector = 4
  @elif h >= 180.0
    sector = 3
  @elif h >= 120.0
    sector = 2
  @elif h >= 60.0
    sector = 1
  @end

  sec_f = sector * 60.0
  f = (h - sec_f) * (1.0 / 60.0)
  p = v * (1.0 - s)
  q = v * (1.0 - (s * f))
  t = v * (1.0 - (s * (1.0 - f)))
  
  res = [v, p, q]
  @if sector == 0
    res = [v, t, p]
  @elif sector == 1
    res = [q, v, p]
  @elif sector == 2
    res = [p, v, t]
  @elif sector == 3
    res = [p, q, v]
  @elif sector == 4
    res = [t, p, v]
  @end
  return res
@end

@fn image_hsv_to_rgb(img)
  out = image_new(img.width, img.height, 3)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      h = image_get_pixel(img, x, y, 0) + 0.0
      s = image_get_pixel(img, x, y, 1) + 0.0
      v = image_get_pixel(img, x, y, 2) + 0.0
      rgb = hsv_to_rgb_pixel(h, s, v)
      rgb0 = rgb[0] + 0.0
      rgb1 = rgb[1] + 0.0
      rgb2 = rgb[2] + 0.0
      out = image_set_pixel(out, x, y, 0, rgb0)
      out = image_set_pixel(out, x, y, 1, rgb1)
      out = image_set_pixel(out, x, y, 2, rgb2)
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_rgb_to_rgba(img, alpha_val)
  out = image_new(img.width, img.height, 4)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      p0 = image_get_pixel(img, x, y, 0) + 0.0
      p1 = image_get_pixel(img, x, y, 1) + 0.0
      p2 = image_get_pixel(img, x, y, 2) + 0.0
      a_val = alpha_val + 0.0
      out = image_set_pixel(out, x, y, 0, p0)
      out = image_set_pixel(out, x, y, 1, p1)
      out = image_set_pixel(out, x, y, 2, p2)
      out = image_set_pixel(out, x, y, 3, a_val)
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_rgba_to_rgb(img)
  out = image_new(img.width, img.height, 3)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      p0 = image_get_pixel(img, x, y, 0) + 0.0
      p1 = image_get_pixel(img, x, y, 1) + 0.0
      p2 = image_get_pixel(img, x, y, 2) + 0.0
      out = image_set_pixel(out, x, y, 0, p0)
      out = image_set_pixel(out, x, y, 1, p1)
      out = image_set_pixel(out, x, y, 2, p2)
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 5. Tensor Layout Bridge (HWC <-> CHW)
@! ----------------------------------------------------------------------------

@fn image_to_tensor_chw(img)
  t_data = []
  c = 0
  @while c < img.channels
    y = 0
    @while y < img.height
      x = 0
      @while x < img.width
        val = image_get_pixel(img, x, y, c) + 0.0
        t_data = t_data.push(val)
        x = x + 1
      @end
      y = y + 1
    @end
    c = c + 1
  @end
  return tensor_new(t_data, [img.channels, img.height, img.width])
@end

@fn tensor_to_image_chw(tensor_node, width, height, channels)
  out = image_new(width, height, channels)
  c = 0
  @while c < channels
    y = 0
    @while y < height
      x = 0
      @while x < width
        t_idx = (c * height * width) + (y * width) + x
        val = tensor_node.data[t_idx] + 0.0
        out = image_set_pixel(out, x, y, c, val)
        x = x + 1
      @end
      y = y + 1
    @end
    c = c + 1
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 6. Element-wise Image Arithmetic & Utilities
@! ----------------------------------------------------------------------------

@fn image_fill(img, val)
  new_data = []
  total = img.width * img.height * img.channels
  i = 0
  @while i < total
    new_data = new_data.push(val + 0.0)
    i = i + 1
  @end
  img.data = new_data
  return img
@end

@fn image_scale(img, factor)
  out = image_clone(img)
  i = 0
  num_items = out.data.len()
  @while i < num_items
    out.data = list_set(out.data, i, out.data[i] * factor)
    i = i + 1
  @end
  return out
@end

@fn image_add(img1, img2)
  out = image_new(img1.width, img1.height, img1.channels)
  i = 0
  num_items = img1.data.len()
  @while i < num_items
    out.data = list_set(out.data, i, img1.data[i] + img2.data[i])
    i = i + 1
  @end
  return out
@end

@fn image_subtract(img1, img2)
  out = image_new(img1.width, img1.height, img1.channels)
  i = 0
  num_items = img1.data.len()
  @while i < num_items
    out.data = list_set(out.data, i, img1.data[i] - img2.data[i])
    i = i + 1
  @end
  return out
@end

@fn image_multiply(img1, img2)
  out = image_new(img1.width, img1.height, img1.channels)
  i = 0
  num_items = img1.data.len()
  @while i < num_items
    out.data = list_set(out.data, i, img1.data[i] * img2.data[i])
    i = i + 1
  @end
  return out
@end
