@! ============================================================================
@! LIPI UNIVERSE AI — VISION SPATIAL FILTERS & CANNY EDGE DETECTOR
@! 100% Written in Pure Lipi Language — Zero External Dependencies
@! Features: 2D Spatial Convolutions, Box & Gaussian Blur, Sobel Gradients,
@! Laplacian, 5-Stage Canny Edge Detection (NMS + Hysteresis), Morphology.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/ai/vision/image"

@! ----------------------------------------------------------------------------
@! 1. 2D Spatial Convolution Engine
@! ----------------------------------------------------------------------------

@fn image_convolve2d(img, kernel, kw, kh, stride, padding)
  pad_x = padding
  pad_y = padding
  
  out_w = ((img.width - kw + (2 * pad_x)) / stride) + 1
  out_h = ((img.height - kh + (2 * pad_y)) / stride) + 1
  @if out_w <= 0 || out_h <= 0 return image_new(0, 0, img.channels) @end
  
  out = image_new(out_w, out_h, img.channels)
  half_kw = kw / 2
  half_kh = kh / 2
  
  oy = 0
  @while oy < out_h
    center_y = (oy * stride) - pad_y + half_kh
    
    ox = 0
    @while ox < out_w
      center_x = (ox * stride) - pad_x + half_kw
      
      c = 0
      @while c < img.channels
        sum = 0.0
        ky = 0
        @while ky < kh
          sy = center_y - half_kh + ky
          kx = 0
          @while kx < kw
            sx = center_x - half_kw + kx
            k_val = kernel[(ky * kw) + kx]
            p_val = image_get_pixel(img, sx, sy, c)
            sum = sum + (p_val * k_val)
            kx = kx + 1
          @end
          ky = ky + 1
        @end
        out = image_set_pixel(out, ox, oy, c, sum)
        c = c + 1
      @end
      ox = ox + 1
    @end
    oy = oy + 1
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 2. Blur Kernel Generators & Filters
@! ----------------------------------------------------------------------------

@fn kernel_box_blur(size)
  k = []
  total = size * size
  val = 1.0 / (total * 1.0)
  i = 0
  @while i < total
    k = k.push(val)
    i = i + 1
  @end
  return k
@end

@fn image_box_blur(img, size)
  k = kernel_box_blur(size)
  pad = size / 2
  return image_convolve2d(img, k, size, size, 1, pad)
@end

@fn kernel_gaussian_2d(size, sigma)
  k = []
  half = size / 2
  two_sigma_sq = 2.0 * sigma * sigma
  @if two_sigma_sq <= 0.0001 two_sigma_sq = 0.0001 @end
  
  sum = 0.0
  y = 0
  @while y < size
    dy = (y - half) * 1.0
    x = 0
    @while x < size
      dx = (x - half) * 1.0
      dist_sq = (dx * dx) + (dy * dy)
      val = math_exp((0.0 - dist_sq) / two_sigma_sq)
      k = k.push(val)
      sum = sum + val
      x = x + 1
    @end
    y = y + 1
  @end
  
  @! Normalize kernel so sum is 1.0
  norm_k = []
  inv_sum = 1.0 / sum
  i = 0
  @while i < k.len()
    norm_k = norm_k.push(k[i] * inv_sum)
    i = i + 1
  @end
  return norm_k
@end

@fn image_gaussian_blur(img, size, sigma)
  k = kernel_gaussian_2d(size, sigma)
  pad = size / 2
  return image_convolve2d(img, k, size, size, 1, pad)
@end

@! ----------------------------------------------------------------------------
@! 3. Gradient & Classical Edge Filters
@! ----------------------------------------------------------------------------

@fn image_sobel_gradients(img)
  @! Ensure single-channel grayscale
  gray = img
  @if img.channels > 1
    gray = image_rgb_to_grayscale(img)
  @end
  
  sobel_x = [
    0.0 - 1.0, 0.0, 1.0,
    0.0 - 2.0, 0.0, 2.0,
    0.0 - 1.0, 0.0, 1.0
  ]
  
  sobel_y = [
    0.0 - 1.0, 0.0 - 2.0, 0.0 - 1.0,
    0.0,       0.0,       0.0,
    1.0,       2.0,       1.0
  ]
  
  gx_img = image_convolve2d(gray, sobel_x, 3, 3, 1, 1)
  gy_img = image_convolve2d(gray, sobel_y, 3, 3, 1, 1)
  
  mag_img = image_new(gx_img.width, gx_img.height, 1)
  dir_img = image_new(gx_img.width, gx_img.height, 1)
  
  y = 0
  @while y < gx_img.height
    x = 0
    @while x < gx_img.width
      gx = image_get_pixel(gx_img, x, y, 0)
      gy = image_get_pixel(gy_img, x, y, 0)
      
      mag = math_sqrt((gx * gx) + (gy * gy))
      mag_img = image_set_pixel(mag_img, x, y, 0, mag)
      
      @! Approximate angle sector: 0 = Horizontal (0 deg), 1 = Diagonal (45 deg), 2 = Vertical (90 deg), 3 = Anti-diag (135 deg)
      sector = 0.0
      abs_gx = math_abs(gx)
      abs_gy = math_abs(gy)
      
      @if abs_gy > (2.414 * abs_gx)
        sector = 2.0 @! 90 degrees (vertical gradient, horizontal edge)
      @elif abs_gx > (2.414 * abs_gy)
        sector = 0.0 @! 0 degrees (horizontal gradient, vertical edge)
      @else
        @if (gx * gy) > 0.0
          sector = 1.0 @! 45 degrees
        @else
          sector = 3.0 @! 135 degrees
        @end
      @end
      dir_img = image_set_pixel(dir_img, x, y, 0, sector)
      
      x = x + 1
    @end
    y = y + 1
  @end
  
  return {
    gx: gx_img,
    gy: gy_img,
    magnitude: mag_img,
    direction: dir_img
  }
@end

@fn image_laplacian(img)
  gray = img
  @if img.channels > 1
    gray = image_rgb_to_grayscale(img)
  @end
  
  lap_kernel = [
    0.0,       1.0, 0.0,
    1.0, 0.0 - 4.0, 1.0,
    0.0,       1.0, 0.0
  ]
  return image_convolve2d(gray, lap_kernel, 3, 3, 1, 1)
@end

@! ----------------------------------------------------------------------------
@! 4. Multi-Stage Canny Edge Detection
@! ----------------------------------------------------------------------------

@fn image_canny_edge_detector(img, low_thresh, high_thresh, sigma)
  @! Stage 1: Gaussian Smoothing
  blurred = image_gaussian_blur(img, 5, sigma)
  
  @! Stage 2: Sobel Gradients & Angles
  grads = image_sobel_gradients(blurred)
  mag = grads.magnitude
  dir = grads.direction
  
  w = mag.width
  h = mag.height
  
  @! Stage 3: Non-Maximum Suppression (NMS)
  nms = image_new(w, h, 1)
  y = 1
  @while y < h - 1
    x = 1
    @while x < w - 1
      m = image_get_pixel(mag, x, y, 0)
      angle_sector = (image_get_pixel(dir, x, y, 0)).to_int()
      
      q = 0.0
      r = 0.0
      
      @if angle_sector == 0
        @! 0 deg: East-West neighbors (x-1, y) and (x+1, y)
        q = image_get_pixel(mag, x + 1, y, 0)
        r = image_get_pixel(mag, x - 1, y, 0)
      @elif angle_sector == 1
        @! 45 deg: NorthEast-SouthWest (x+1, y-1) and (x-1, y+1)
        q = image_get_pixel(mag, x + 1, y - 1, 0)
        r = image_get_pixel(mag, x - 1, y + 1, 0)
      @elif angle_sector == 2
        @! 90 deg: North-South (x, y-1) and (x, y+1)
        q = image_get_pixel(mag, x, y + 1, 0)
        r = image_get_pixel(mag, x, y - 1, 0)
      @elif angle_sector == 3
        @! 135 deg: NorthWest-SouthEast (x-1, y-1) and (x+1, y+1)
        q = image_get_pixel(mag, x - 1, y - 1, 0)
        r = image_get_pixel(mag, x + 1, y + 1, 0)
      @end
      
      @if m >= q && m >= r
        nms = image_set_pixel(nms, x, y, 0, m)
      @else
        nms = image_set_pixel(nms, x, y, 0, 0.0)
      @end
      
      x = x + 1
    @end
    y = y + 1
  @end
  
  @! Stage 4: Double Thresholding (Strong = 1.0, Weak = 0.5, Suppressed = 0.0)
  thresh_img = image_new(w, h, 1)
  y = 0
  @while y < h
    x = 0
    @while x < w
      v = image_get_pixel(nms, x, y, 0)
      @if v >= high_thresh
        thresh_img = image_set_pixel(thresh_img, x, y, 0, 1.0)
      @elif v >= low_thresh
        thresh_img = image_set_pixel(thresh_img, x, y, 0, 0.5)
      @else
        thresh_img = image_set_pixel(thresh_img, x, y, 0, 0.0)
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  
  @! Stage 5: Edge Tracking by Hysteresis (8-connectivity)
  final_edges = image_new(w, h, 1)
  y = 1
  @while y < h - 1
    x = 1
    @while x < w - 1
      pix = image_get_pixel(thresh_img, x, y, 0)
      @if pix == 1.0
        final_edges = image_set_pixel(final_edges, x, y, 0, 1.0)
      @elif pix == 0.5
        @! Check if any of 8 neighbors is strong (1.0)
        has_strong_neighbor = 0
        dy = 0 - 1
        @while dy <= 1
          dx = 0 - 1
          @while dx <= 1
            @if image_get_pixel(thresh_img, x + dx, y + dy, 0) == 1.0
              has_strong_neighbor = 1
            @end
            dx = dx + 1
          @end
          dy = dy + 1
        @end
        
        @if has_strong_neighbor == 1
          final_edges = image_set_pixel(final_edges, x, y, 0, 1.0)
        @else
          final_edges = image_set_pixel(final_edges, x, y, 0, 0.0)
        @end
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  
  return final_edges
@end

@! ----------------------------------------------------------------------------
@! 5. Mathematical Morphology (Dilation, Erosion, Opening, Closing)
@! ----------------------------------------------------------------------------

@fn image_dilate(img, kernel_size)
  half = kernel_size / 2
  out = image_new(img.width, img.height, img.channels)
  
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      c = 0
      @while c < img.channels
        max_val = 0.0
        ky = 0 - half
        @while ky <= half
          kx = 0 - half
          @while kx <= half
            val = image_get_pixel_clamped(img, x + kx, y + ky, c)
            @if val > max_val max_val = val @end
            kx = kx + 1
          @end
          ky = ky + 1
        @end
        out = image_set_pixel(out, x, y, c, max_val)
        c = c + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_erode(img, kernel_size)
  half = kernel_size / 2
  out = image_new(img.width, img.height, img.channels)
  
  y = 0
  @while y < img.height
    x = 0
    @while x < img.width
      c = 0
      @while c < img.channels
        min_val = 1.0
        ky = 0 - half
        @while ky <= half
          kx = 0 - half
          @while kx <= half
            val = image_get_pixel_clamped(img, x + kx, y + ky, c)
            @if val < min_val min_val = val @end
            kx = kx + 1
          @end
          ky = ky + 1
        @end
        out = image_set_pixel(out, x, y, c, min_val)
        c = c + 1
      @end
      x = x + 1
    @end
    y = y + 1
  @end
  return out
@end

@fn image_opening(img, kernel_size)
  eroded = image_erode(img, kernel_size)
  return image_dilate(eroded, kernel_size)
@end

@fn image_closing(img, kernel_size)
  dilated = image_dilate(img, kernel_size)
  return image_erode(dilated, kernel_size)
@end
