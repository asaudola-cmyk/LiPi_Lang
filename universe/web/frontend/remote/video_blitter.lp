@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — DOM-BYPASS WEB FRONTEND ENGINE
@! Module: universe/web/frontend/remote/video_blitter.maya
@! Milestone: M5 — Adaptive WebRTC Hybrid Rendering
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features: WebRTC Video Stream Frame Decoder, Canvas Sub-Rect Placement,
@! Dirty-Rect Tracking & Framebuffer Compositing with Local WASM UI
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"

@! ============================================================================
@! 1. CONSTANTS & FORMATS
@! ============================================================================

@! Pixel Formats
@fn PIXEL_FMT_RGBA() return 0 @end
@fn PIXEL_FMT_ARGB() return 1 @end
@fn PIXEL_FMT_RGB() return 2 @end
@fn PIXEL_FMT_YUV420_SIM() return 3 @end

@! Scaling Modes
@fn SCALE_MODE_STRETCH() return 0 @end
@fn SCALE_MODE_FIT() return 1 @end
@fn SCALE_MODE_FILL() return 2 @end
@fn SCALE_MODE_CENTER() return 3 @end

@! ============================================================================
@! 2. DATA STRUCTURES
@! ============================================================================

@struct VideoFrame
  frame_id: i64
  width: i64
  height: i64
  format: i64
  timestamp_ms: i64
  pixels: array                @! ARGB 32-bit integer array
  stride: i64
  is_keyframe: bool
  quality_score: i64
@end

@struct BlitSubRect
  dest_x: i64
  dest_y: i64
  dest_w: i64
  dest_h: i64
  clip_x: i64
  clip_y: i64
  clip_w: i64
  clip_h: i64
  opacity_pct: i64             @! 0 to 100
  border_radius: i64
  border_color: i64
  border_width: i64
@end

@struct DirtyRect
  min_x: i64
  min_y: i64
  max_x: i64
  max_y: i64
  is_dirty: bool
@end

@struct VideoBlitter
  canvas_width: i64
  canvas_height: i64
  subrect: BlitSubRect
  scale_mode: i64
  dirty_rect: DirtyRect
  frames_blitted: i64
  total_pixels_copied: i64
  last_frame_id: i64
  last_timestamp: i64
  texture_id: i64
  is_active: bool
@end

@! ============================================================================
@! 3. CONSTRUCTOR & INITIALIZATION
@! ============================================================================

@fn video_blitter_new(canvas_w, canvas_h, dest_x, dest_y, dest_w, dest_h)
  @if canvas_w <= 0 canvas_w = 1 @end
  @if canvas_h <= 0 canvas_h = 1 @end
  @if dest_w <= 0 dest_w = 1 @end
  @if dest_h <= 0 dest_h = 1 @end

  sr = {
    dest_x: dest_x,
    dest_y: dest_y,
    dest_w: dest_w,
    dest_h: dest_h,
    clip_x: 0,
    clip_y: 0,
    clip_w: canvas_w,
    clip_h: canvas_h,
    opacity_pct: 100,
    border_radius: 0,
    border_color: 0,
    border_width: 0
  }

  dr = {
    min_x: 0,
    min_y: 0,
    max_x: 0,
    max_y: 0,
    is_dirty: false
  }

  return {
    canvas_width: canvas_w,
    canvas_height: canvas_h,
    subrect: sr,
    scale_mode: SCALE_MODE_STRETCH(),
    dirty_rect: dr,
    frames_blitted: 0,
    total_pixels_copied: 0,
    last_frame_id: 0,
    last_timestamp: 0,
    texture_id: 1001,
    is_active: true
  }
@end

@fn video_blitter_set_subrect(blitter, dest_x, dest_y, dest_w, dest_h)
  blitter.subrect.dest_x = dest_x
  blitter.subrect.dest_y = dest_y
  blitter.subrect.dest_w = dest_w
  blitter.subrect.dest_h = dest_h
  return blitter
@end

@fn video_blitter_set_clip(blitter, clip_x, clip_y, clip_w, clip_h)
  blitter.subrect.clip_x = clip_x
  blitter.subrect.clip_y = clip_y
  blitter.subrect.clip_w = clip_w
  blitter.subrect.clip_h = clip_h
  return blitter
@end

@fn video_blitter_set_scale_mode(blitter, scale_mode)
  blitter.scale_mode = scale_mode
  return blitter
@end

@fn video_blitter_set_border(blitter, border_w, border_color, border_radius)
  blitter.subrect.border_width = border_w
  blitter.subrect.border_color = border_color
  blitter.subrect.border_radius = border_radius
  return blitter
@end

@fn video_blitter_set_opacity(blitter, opacity_pct)
  @if opacity_pct < 0 opacity_pct = 0 @end
  @if opacity_pct > 100 opacity_pct = 100 @end
  blitter.subrect.opacity_pct = opacity_pct
  return blitter
@end

@! ============================================================================
@! 4. FRAME GENERATION & DECODING
@! ============================================================================

@fn video_blitter_create_frame(frame_id, width, height, pixels, timestamp_ms, format)
  return {
    frame_id: frame_id,
    width: width,
    height: height,
    format: format,
    timestamp_ms: timestamp_ms,
    pixels: pixels,
    stride: width,
    is_keyframe: true,
    quality_score: 100
  }
@end

@fn video_blitter_create_solid_frame(frame_id, width, height, color, timestamp_ms)
  total = width * height
  buf = []
  i = 0
  @while i < total
    buf = buf.push(color)
    i = i + 1
  @end

  return {
    frame_id: frame_id,
    width: width,
    height: height,
    format: PIXEL_FMT_ARGB(),
    timestamp_ms: timestamp_ms,
    pixels: buf,
    stride: width,
    is_keyframe: true,
    quality_score: 100
  }
@end

@fn video_blitter_create_pattern_frame(frame_id, width, height, base_color, pattern_mode, timestamp_ms)
  total = width * height
  buf = []
  
  r = width / 3
  @if height < width
    r = height / 3
  @end
  r_sq = r * r

  center_x = width / 2
  center_y = height / 2

  y = 0
  @while y < height
    x = 0
    @while x < width
      px = base_color
      
      @if pattern_mode == 1
        @! Checkerboard pattern (e.g. 3D grid ground)
        cx = (x / 16) % 2
        cy = (y / 16) % 2
        @if cx == cy
          px = base_color + 2105376
        @end
      @elif pattern_mode == 2
        @! Radial sphere / 3D viewport test sphere
        dx = x - center_x
        dy = y - center_y
        dist_sq = (dx * dx) + (dy * dy)
        @if dist_sq <= r_sq
          safe_r_sq = r_sq
        @if safe_r_sq <= 0 safe_r_sq = 1 @end
        ratio = (dist_sq * 200) / safe_r_sq
          shade = 255 - ratio
          @if shade < 0 shade = 0 @end
          @if shade > 255 shade = 255 @end
          px = 4278190080 + (shade * 65536) + (shade * 256) + shade
        @else
          px = 4279308312
        @end
      @end

      buf = buf.push(px)
      x = x + 1
    @end
    y = y + 1
  @end

  return {
    frame_id: frame_id,
    width: width,
    height: height,
    format: PIXEL_FMT_ARGB(),
    timestamp_ms: timestamp_ms,
    pixels: buf,
    stride: width,
    is_keyframe: true,
    quality_score: 95
  }
@end

@fn video_blitter_decode_raw_packet(packet_id, width, height, raw_bytes, format, timestamp_ms)
  @! Converts packet bytes to ARGB color buffer
  total = width * height
  buf = []
  i = 0
  @while i < total
    @if i < raw_bytes.len()
      buf = buf.push(raw_bytes[i])
    @else
      buf = buf.push(4278190080)
    @end
    i = i + 1
  @end

  return {
    frame_id: packet_id,
    width: width,
    height: height,
    format: format,
    timestamp_ms: timestamp_ms,
    pixels: buf,
    stride: width,
    is_keyframe: true,
    quality_score: 90
  }
@end

@! ============================================================================
@! 5. PIXEL BLENDING & DIRTY RECT TRACKING
@! ============================================================================

@fn video_blitter_pixel_blend(dst_pixel, src_pixel, opacity_pct)
  @if opacity_pct >= 100
    return src_pixel
  @end
  @if opacity_pct <= 0
    return dst_pixel
  @end

  @! Unpack ARGB
  src_a = (src_pixel / 16777216) % 256
  src_r = (src_pixel / 65536) % 256
  src_g = (src_pixel / 256) % 256
  src_b = src_pixel % 256

  dst_a = (dst_pixel / 16777216) % 256
  dst_r = (dst_pixel / 65536) % 256
  dst_g = (dst_pixel / 256) % 256
  dst_b = dst_pixel % 256

  eff_alpha = (src_a * opacity_pct) / 100
  inv_alpha = 255 - eff_alpha

  out_a = eff_alpha + ((dst_a * inv_alpha) / 255)
  out_r = ((src_r * eff_alpha) + (dst_r * inv_alpha)) / 255
  out_g = ((src_g * eff_alpha) + (dst_g * inv_alpha)) / 255
  out_b = ((src_b * eff_alpha) + (dst_b * inv_alpha)) / 255

  return (out_a * 16777216) + (out_r * 65536) + (out_g * 256) + out_b
@end

@fn video_blitter_get_dirty_rect(blitter)
  return blitter.dirty_rect
@end

@fn video_blitter_reset_dirty_rect(blitter)
  blitter.dirty_rect.is_dirty = false
  blitter.dirty_rect.min_x = 0
  blitter.dirty_rect.min_y = 0
  blitter.dirty_rect.max_x = 0
  blitter.dirty_rect.max_y = 0
  return blitter
@end

@! ============================================================================
@! 6. CANVAS SUB-RECT BLITTING
@! ============================================================================

@fn video_blitter_blit_frame(blitter, frame, canvas_framebuffer)
  @if blitter.is_active == false || frame.pixels.len() == 0
    return canvas_framebuffer
  @end

  dest_x = blitter.subrect.dest_x
  dest_y = blitter.subrect.dest_y
  dest_w = blitter.subrect.dest_w
  dest_h = blitter.subrect.dest_h

  @! Effective clipping bounds
  clip_min_x = blitter.subrect.clip_x
  @if clip_min_x < 0 clip_min_x = 0 @end
  clip_min_y = blitter.subrect.clip_y
  @if clip_min_y < 0 clip_min_y = 0 @end
  
  clip_max_x = blitter.subrect.clip_x + blitter.subrect.clip_w
  @if clip_max_x > blitter.canvas_width clip_max_x = blitter.canvas_width @end
  
  clip_max_y = blitter.subrect.clip_y + blitter.subrect.clip_h
  @if clip_max_y > blitter.canvas_height clip_max_y = blitter.canvas_height @end

  @! Subrect bounds
  target_min_x = dest_x
  @if target_min_x < clip_min_x target_min_x = clip_min_x @end
  
  target_min_y = dest_y
  @if target_min_y < clip_min_y target_min_y = clip_min_y @end
  
  target_max_x = dest_x + dest_w
  @if target_max_x > clip_max_x target_max_x = clip_max_x @end
  
  target_max_y = dest_y + dest_h
  @if target_max_y > clip_max_y target_max_y = clip_max_y @end

  @if target_min_x >= target_max_x || target_min_y >= target_max_y
    @! Completely clipped out
    return canvas_framebuffer
  @end

  opacity = blitter.subrect.opacity_pct
  pixels_copied = 0

  cy = target_min_y
  @while cy < target_max_y
    @! Source Y mapping
    rel_y = cy - dest_y
    src_y = (rel_y * frame.height) / dest_h
    @if src_y >= frame.height src_y = frame.height - 1 @end
    @if src_y < 0 src_y = 0 @end

    cx = target_min_x
    @while cx < target_max_x
      @! Source X mapping
      rel_x = cx - dest_x
      src_x = (rel_x * frame.width) / dest_w
      @if src_x >= frame.width src_x = frame.width - 1 @end
      @if src_x < 0 src_x = 0 @end

      src_idx = (src_y * frame.width) + src_x
      src_pixel = 0
      @if src_idx >= 0 && src_idx < frame.pixels.len()
        src_pixel = frame.pixels[src_idx]
      @end

      canvas_idx = (cy * blitter.canvas_width) + cx
      @if canvas_idx >= 0 && canvas_idx < canvas_framebuffer.len()
        dst_pixel = canvas_framebuffer[canvas_idx]
        blended = video_blitter_pixel_blend(dst_pixel, src_pixel, opacity)
        canvas_framebuffer[canvas_idx] = blended
        pixels_copied = pixels_copied + 1
      @end

      cx = cx + 1
    @end
    cy = cy + 1
  @end

  @! Update Blitter State & Dirty Rect
  blitter.frames_blitted = blitter.frames_blitted + 1
  blitter.total_pixels_copied = blitter.total_pixels_copied + pixels_copied
  blitter.last_frame_id = frame.frame_id
  blitter.last_timestamp = frame.timestamp_ms

  blitter.dirty_rect.min_x = target_min_x
  blitter.dirty_rect.min_y = target_min_y
  blitter.dirty_rect.max_x = target_max_x
  blitter.dirty_rect.max_y = target_max_y
  blitter.dirty_rect.is_dirty = true

  return canvas_framebuffer
@end
