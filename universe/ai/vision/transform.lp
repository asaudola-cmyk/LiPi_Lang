@! ============================================================================
@! LIPI UNIVERSE AI — VISION SPATIAL & PHOTOMETRIC TRANSFORMS
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Features: Bilinear & Nearest Resizing, Crop, Pad (Constant, Reflect, Edge),
@! Flips, 90-Degree & Affine Rotations, Normalization, Brightness/Contrast/Gamma.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/ai/vision/image"

@! ----------------------------------------------------------------------------
@! 1. Spatial Resizing (Nearest Neighbor & Bilinear Interpolation)
@! ----------------------------------------------------------------------------

@fn image_resize_nearest(img, new_w, new_h)
  out = image_new(new_w, new_h, img.channels)
  y = 0
  @while y < new_h
    src_y = (y * img.height) / new_h
    @if src_y >= img.height src_y = img.height - 1 @end
    
    x = 0
    @while x < new_w
      src_x = (x * img.width) / new_w
      @if src_x >= img.width src_x = img.width - 1 @end
      
      c = 0
      @while c < img.channels
        val = image_get_pixel(img, src_x, src_y, c)
        out = image_set_pixel(out, x, y, c, val)
        c = c + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_resize_bilinear(img, new_w, new_h)
  out = image_new(new_w, new_h, img.channels)
  
  scale_x = (img.width * 1.0) / (new_w * 1.0)
  scale_y = (img.height * 1.0) / (new_h * 1.0)
  
  y = 0
  @while y < new_h
    src_y_f = (y * 1.0 + 0.5) * scale_y - 0.5
    @if src_y_f < 0.0 src_y_f = 0.0 @end
    y0 = src_y_f.to_int()
    y1 = y0 + 1
    @if y1 >= img.height y1 = img.height - 1 @end
    dy = src_y_f - (y0 * 1.0)
    
    x = 0
    @while x < new_w
      src_x_f = (x * 1.0 + 0.5) * scale_x - 0.5
      @if src_x_f < 0.0 src_x_f = 0.0 @end
      x0 = src_x_f.to_int()
      x1 = x0 + 1
      @if x1 >= img.width x1 = img.width - 1 @end
      dx = src_x_f - (x0 * 1.0)
      
      c = 0
      @while c < img.channels
        p00 = image_get_pixel(img, x0, y0, c)
        p10 = image_get_pixel(img, x1, y0, c)
        p01 = image_get_pixel(img, x0, y1, c)
        p11 = image_get_pixel(img, x1, y1, c)
        
        @! Bilinear interpolation formula
        val = (1.0 - dx) * (1.0 - dy) * p00 + dx * (1.0 - dy) * p10 + (1.0 - dx) * dy * p01 + dx * dy * p11
        out = image_set_pixel(out, x, y, c, val)
        c = c + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 2. Geometric Transformations (Crop, Pad, Flip, Rotate)
@! ----------------------------------------------------------------------------

@fn image_crop(img, start_x, start_y, crop_w, crop_h)
  out = image_new(crop_w, crop_h, img.channels)
  y = 0
  @while y < crop_h
    src_y = start_y + y
    x = 0
    @while x < crop_w
      src_x = start_x + x
      c = 0
      @while c < img.channels
        val = image_get_pixel(img, src_x, src_y, c)
        out = image_set_pixel(out, x, y, c, val)
        c = c + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_pad(img, pad_t, pad_b, pad_l, pad_r, mode, fill_val)
  new_w = img.width + pad_l + pad_r
  new_h = img.height + pad_t + pad_b
  out = image_new(new_w, new_h, img.channels)
  
  y = 0
  @while y < new_h
    x = 0
    @while x < new_w
      src_x = x - pad_l
      src_y = y - pad_t
      
      c = 0
      @while c < img.channels
        val = fill_val
        @if mode == "constant"
          @if src_x >= 0 && src_x < img.width && src_y >= 0 && src_y < img.height
            val = image_get_pixel(img, src_x, src_y, c)
          @end
        @elif mode == "edge"
          val = image_get_pixel_clamped(img, src_x, src_y, c)
        @elif mode == "reflect"
          rx = src_x
          @if rx < 0 rx = 0 - rx @end
          @if rx >= img.width rx = (2 * img.width) - 2 - rx @end
          @if rx < 0 rx = 0 @end
          @if rx >= img.width rx = img.width - 1 @end
          
          ry = src_y
          @if ry < 0 ry = 0 - ry @end
          @if ry >= img.height ry = (2 * img.height) - 2 - ry @end
          @if ry < 0 ry = 0 @end
          @if ry >= img.height ry = img.height - 1 @end
          
          val = image_get_pixel(img, rx, ry, c)
        @end
        out = image_set_pixel(out, x, y, c, val)
        c = c + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_flip_horizontal(img)
  out = image_new(img.width, img.height, img.channels)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      src_x = img.width - 1 - x
      c = 0
      @while c < img.channels
        val = image_get_pixel(img, src_x, y, c)
        out = image_set_pixel(out, x, y, c, val)
        c = c + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_flip_vertical(img)
  out = image_new(img.width, img.height, img.channels)
  y = 0
  @while y < img.height
    src_y = img.height - 1 - y
    x = 0
    @while x < img.width
      c = 0
      @while c < img.channels
        val = image_get_pixel(img, x, src_y, c)
        out = image_set_pixel(out, x, y, c, val)
        c = c + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_rotate_90(img, k)
  rot_k = k % 4
  @if rot_k < 0 rot_k = rot_k + 4 @end
  
  @if rot_k == 0
    return image_clone(img)
  @elif rot_k == 1
    @! 90 deg clockwise (new_w = H, new_h = W)
    out = image_new(img.height, img.width, img.channels)
    y = 0
    @while y < out.height
      x = 0
      @while x < out.width
        src_x = y
        src_y = img.height - 1 - x
        c = 0
        @while c < img.channels
          val = image_get_pixel(img, src_x, src_y, c)
          out = image_set_pixel(out, x, y, c, val)
          c = c + 1
        @end
        x = x + 1
      @end
      y = y + 1
    @end
    return out
  @elif rot_k == 2
    @! 180 deg
    return image_flip_vertical(image_flip_horizontal(img))
  @elif rot_k == 3
    @! 270 deg clockwise (new_w = H, new_h = W)
    out = image_new(img.height, img.width, img.channels)
    y = 0
    @while y < out.height
      x = 0
      @while x < out.width
        src_x = img.width - 1 - y
        src_y = x
        c = 0
        @while c < img.channels
          val = image_get_pixel(img, src_x, src_y, c)
          out = image_set_pixel(out, x, y, c, val)
          c = c + 1
        @end
        x = x + 1
      @end
      y = y + 1
    @end
    return out
  @end
  return image_clone(img)
@end

@fn image_rotate_affine(img, angle_rad, center_x, center_y)
  out = image_new(img.width, img.height, img.channels)
  cos_a = math_cos(angle_rad)
  sin_a = math_sin(angle_rad)
  
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      dx = (x * 1.0) - center_x
      dy = (y * 1.0) - center_y
      
      @! Inverse rotation
      src_x_f = (cos_a * dx) + (sin_a * dy) + center_x
      src_y_f = ((0.0 - sin_a) * dx) + (cos_a * dy) + center_y
      
      x0 = src_x_f.to_int()
      y0 = src_y_f.to_int()
      
      @if x0 >= 0 && x0 < img.width && y0 >= 0 && y0 < img.height
        c = 0
        @while c < img.channels
          val = image_get_pixel(img, x0, y0, c)
          out = image_set_pixel(out, x, y, c, val)
          c = c + 1
        @end
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 3. Photometric Transforms & Normalization
@! ----------------------------------------------------------------------------

@fn image_normalize(img, mean_list, std_list)
  out = image_clone(img)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      c = 0
      @while c < img.channels
        m = 0.0
        s = 1.0
        @if c < mean_list.len() m = mean_list[c] @end
        @if c < std_list.len() s = std_list[c] @end
        @if s == 0.0 s = 0.00001 @end
        
        val = image_get_pixel(img, x, y, c)
        norm_val = (val - m) / s
        out = image_set_pixel(out, x, y, c, norm_val)
        c = c + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_denormalize(img, mean_list, std_list)
  out = image_clone(img)
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      c = 0
      @while c < img.channels
        m = 0.0
        s = 1.0
        @if c < mean_list.len() m = mean_list[c] @end
        @if c < std_list.len() s = std_list[c] @end
        
        val = image_get_pixel(img, x, y, c)
        denorm_val = math_clamp((val * s) + m, 0.0, 1.0)
        out = image_set_pixel(out, x, y, c, denorm_val)
        c = c + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_adjust_brightness(img, delta)
  out = image_clone(img)
  i = 0
  num_items = out.data.len()
  @while i < num_items
    clamped_val = math_clamp(out.data[i] + delta, 0.0, 1.0)
    out.data = list_set(out.data, i, clamped_val)
    i = i + 1
  @end
  return out
@end

@fn image_adjust_contrast(img, factor)
  out = image_clone(img)
  i = 0
  num_items = out.data.len()
  @while i < num_items
    val = ((out.data[i] - 0.5) * factor) + 0.5
    clamped_val = math_clamp(val, 0.0, 1.0)
    out.data = list_set(out.data, i, clamped_val)
    i = i + 1
  @end
  return out
@end

@fn image_adjust_gamma(img, gamma)
  out = image_clone(img)
  i = 0
  num_items = out.data.len()
  @while i < num_items
    val = math_pow(out.data[i], gamma)
    clamped_val = math_clamp(val, 0.0, 1.0)
    out.data = list_set(out.data, i, clamped_val)
    i = i + 1
  @end
  return out
@end
