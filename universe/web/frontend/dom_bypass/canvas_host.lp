@! ============================================================================
@! LIPI UNIVERSAL ARCHITECTURE — DOM-BYPASS WEB FRONTEND ENGINE
@! Module: universe/web/frontend/dom_bypass/canvas_host.maya
@! Milestone: M6 — DOM-Bypass Host Runtime & Full E2E Integration
@! 100% Pure Lipi Implementation — Zero External Dependencies
@! Features:
@! - <canvas> presentation target abstraction
@! - Device Pixel Ratio (DPR) HiDPI / Retina coordinate scaling
@! - Frame timing loop & smoothed FPS telemetry
@! - Dirty rect compositor & minimal damage bounding box calculation
@! - Unified renderer presentation pipeline & pixel readback
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/web/frontend/renderer/unified_renderer"

@! ============================================================================
@! 1. DIRTY RECT DATA STRUCTURES & COMPOSITOR
@! ============================================================================

@struct HostDirtyRect
  rect_min_x: i64
  rect_min_y: i64
  rect_max_x: i64
  rect_max_y: i64
  rect_is_empty: bool
@end

@fn host_dirty_rect_empty()
  return {
    rect_min_x: 0,
    rect_min_y: 0,
    rect_max_x: 0,
    rect_max_y: 0,
    rect_is_empty: true
  }
@end

@fn host_dirty_rect_new(x, y, w, h)
  @if w <= 0 || h <= 0
    return host_dirty_rect_empty()
  @end
  return {
    rect_min_x: x,
    rect_min_y: y,
    rect_max_x: x + w,
    rect_max_y: y + h,
    rect_is_empty: false
  }
@end

@fn host_dirty_rect_union(r1, r2)
  @if r1.rect_is_empty
    return r2
  @end
  @if r2.rect_is_empty
    return r1
  @end

  nx1 = r1.rect_min_x
  @if r2.rect_min_x < nx1 nx1 = r2.rect_min_x @end

  ny1 = r1.rect_min_y
  @if r2.rect_min_y < ny1 ny1 = r2.rect_min_y @end

  nx2 = r1.rect_max_x
  @if r2.rect_max_x > nx2 nx2 = r2.rect_max_x @end

  ny2 = r1.rect_max_y
  @if r2.rect_max_y > ny2 ny2 = r2.rect_max_y @end

  return {
    rect_min_x: nx1,
    rect_min_y: ny1,
    rect_max_x: nx2,
    rect_max_y: ny2,
    rect_is_empty: false
  }
@end

@fn host_dirty_rect_intersects(r1, r2)
  @if r1.rect_is_empty || r2.rect_is_empty
    return false
  @end
  @if r1.rect_max_x <= r2.rect_min_x || r2.rect_max_x <= r1.rect_min_x
    return false
  @end
  @if r1.rect_max_y <= r2.rect_min_y || r2.rect_max_y <= r1.rect_min_y
    return false
  @end
  return true
@end

@struct HostDirtyRectCompositor
  comp_rects: array
  comp_union_rect: HostDirtyRect
  comp_is_full_redraw: bool
  comp_total_damaged: i64
  comp_mutations: i64
@end

@fn dirty_rect_compositor_new()
  return {
    comp_rects: [],
    comp_union_rect: host_dirty_rect_empty(),
    comp_is_full_redraw: true,
    comp_total_damaged: 0,
    comp_mutations: 0
  }
@end

@fn dirty_rect_compositor_add_rect(comp, x, y, w, h)
  @if w <= 0 || h <= 0
    return comp
  @end

  r = host_dirty_rect_new(x, y, w, h)
  comp.comp_rects = comp.comp_rects.push(r)
  comp.comp_union_rect = host_dirty_rect_union(comp.comp_union_rect, r)
  comp.comp_total_damaged = comp.comp_total_damaged + (w * h)
  comp.comp_mutations = comp.comp_mutations + 1
  return comp
@end

@fn dirty_rect_compositor_mark_full(comp, width, height)
  comp.comp_is_full_redraw = true
  comp.comp_rects = [host_dirty_rect_new(0, 0, width, height)]
  comp.comp_union_rect = host_dirty_rect_new(0, 0, width, height)
  comp.comp_total_damaged = width * height
  comp.comp_mutations = comp.comp_mutations + 1
  return comp
@end

@fn dirty_rect_compositor_reset(comp)
  comp.comp_rects = []
  comp.comp_union_rect = host_dirty_rect_empty()
  comp.comp_is_full_redraw = false
  comp.comp_total_damaged = 0
  return comp
@end

@fn dirty_rect_compositor_is_dirty(comp)
  return comp.comp_is_full_redraw || (comp.comp_union_rect.rect_is_empty == false)
@end

@fn dirty_rect_compositor_get_bounds(comp)
  return comp.comp_union_rect
@end

@fn dirty_rect_compositor_damaged_area(comp)
  @if comp.comp_union_rect.rect_is_empty
    return 0
  @end
  w = comp.comp_union_rect.rect_max_x - comp.comp_union_rect.rect_min_x
  h = comp.comp_union_rect.rect_max_y - comp.comp_union_rect.rect_min_y
  return w * h
@end

@! ============================================================================
@! 2. FRAME TIMING LOOP & FPS CALCULATOR
@! ============================================================================

@struct HostFrameTimingLoop
  loop_target_fps: i64
  loop_target_frame_time_ms: f64
  loop_last_timestamp: i64
  loop_delta_time_ms: f64
  loop_frame_count: i64
  loop_fps_estimate: f64
  loop_frame_history: array
  loop_is_active: bool
@end

@fn frame_timing_loop_new(target_fps)
  @if target_fps <= 0 target_fps = 60 @end
  frame_ms = 1000.0 / target_fps
  return {
    loop_target_fps: target_fps * 1.0,
    loop_target_frame_time_ms: frame_ms * 1.0,
    loop_last_timestamp: 0,
    loop_delta_time_ms: 0.0,
    loop_frame_count: 0,
    loop_fps_estimate: target_fps * 1.0,
    loop_frame_history: [],
    loop_is_active: true
  }
@end

@fn frame_timing_loop_tick(loop, timestamp_ms)
  @if loop.loop_last_timestamp > 0
    delta = timestamp_ms - loop.loop_last_timestamp
    @if delta <= 0 delta = 1.0 @end
    loop.loop_delta_time_ms = delta * 1.0
    
    @! Estimate FPS: 1000.0 / delta_ms smoothed with exponential filter
    instant_fps = 1000.0 / (delta * 1.0)
    @if instant_fps > 240.0 instant_fps = 240.0 @end
    
    loop.loop_fps_estimate = (loop.loop_fps_estimate * 0.9) + (instant_fps * 0.1)
    
    loop.loop_frame_history = loop.loop_frame_history.push(delta)
    @if loop.loop_frame_history.len() > 60
      new_hist = []
      start_i = loop.loop_frame_history.len() - 60
      i = start_i
      @while i < loop.loop_frame_history.len()
        new_hist = new_hist.push(loop.loop_frame_history[i])
        i = i + 1
      @end
      loop.loop_frame_history = new_hist
    @end
  @else
    loop.loop_delta_time_ms = loop.loop_target_frame_time_ms
    loop.loop_fps_estimate = loop.loop_target_fps
  @end

  loop.loop_last_timestamp = timestamp_ms
  loop.loop_frame_count = loop.loop_frame_count + 1
  return loop
@end

@fn frame_timing_loop_reset(loop)
  loop.loop_last_timestamp = 0
  loop.loop_delta_time_ms = 0.0
  loop.loop_frame_count = 0
  loop.loop_fps_estimate = loop.loop_target_fps
  loop.loop_frame_history = []
  return loop
@end

@! ============================================================================
@! 3. CANVAS PRESENTATION TARGET & HOST RUNTIME
@! ============================================================================

@struct CanvasPresentationTarget
  canvas_id: string
  css_width: i64
  css_height: i64
  dpr: f64
  physical_width: i64
  physical_height: i64
  renderer: UnifiedRenderer
  compositor: HostDirtyRectCompositor
  timing_loop: HostFrameTimingLoop
  clear_color: i64
  is_vsync_enabled: bool
  presented_frames: i64
  is_active: bool
@end

@fn canvas_scale_css_to_physical(css_val, dpr)
  return css_val * dpr
@end

@fn canvas_scale_physical_to_css(phys_val, dpr)
  @if dpr <= 0
    return phys_val
  @end
  return phys_val / dpr
@end

@fn canvas_host_new(canvas_id, css_width, css_height, dpr, preferred_tier, clear_color)
  @if css_width <= 0 css_width = 800 @end
  @if css_height <= 0 css_height = 600 @end
  @if dpr <= 0 dpr = 1 @end

  phys_w = canvas_scale_css_to_physical(css_width, dpr)
  phys_h = canvas_scale_css_to_physical(css_height, dpr)

  rend = unified_renderer_new(preferred_tier, phys_w, phys_h, dpr)
  comp = dirty_rect_compositor_new()
  comp = dirty_rect_compositor_mark_full(comp, phys_w, phys_h)
  loop = frame_timing_loop_new(60)

  return {
    canvas_id: canvas_id,
    css_width: css_width,
    css_height: css_height,
    dpr: dpr,
    physical_width: phys_w,
    physical_height: phys_h,
    renderer: rend,
    compositor: comp,
    timing_loop: loop,
    clear_color: clear_color,
    is_vsync_enabled: true,
    presented_frames: 0,
    is_active: true
  }
@end

@fn canvas_host_set_dpr(host, new_dpr)
  @if new_dpr <= 0 new_dpr = 1 @end
  host.dpr = new_dpr
  host.physical_width = canvas_scale_css_to_physical(host.css_width, new_dpr)
  host.physical_height = canvas_scale_css_to_physical(host.css_height, new_dpr)

  host.renderer = unified_renderer_new(host.renderer.target_tier, host.physical_width, host.physical_height, new_dpr)
  host.compositor = dirty_rect_compositor_mark_full(host.compositor, host.physical_width, host.physical_height)
  return host
@end

@fn canvas_host_resize(host, new_css_w, new_css_h)
  @if new_css_w <= 0 new_css_w = 1 @end
  @if new_css_h <= 0 new_css_h = 1 @end

  host.css_width = new_css_w
  host.css_height = new_css_h
  host.physical_width = canvas_scale_css_to_physical(new_css_w, host.dpr)
  host.physical_height = canvas_scale_css_to_physical(new_css_h, host.dpr)

  host.renderer = unified_renderer_new(host.renderer.target_tier, host.physical_width, host.physical_height, host.dpr)
  host.compositor = dirty_rect_compositor_mark_full(host.compositor, host.physical_width, host.physical_height)
  return host
@end

@fn canvas_host_record_damage(host, css_x, css_y, css_w, css_h)
  phys_x = canvas_scale_css_to_physical(css_x, host.dpr)
  phys_y = canvas_scale_css_to_physical(css_y, host.dpr)
  phys_w = canvas_scale_css_to_physical(css_w, host.dpr)
  phys_h = canvas_scale_css_to_physical(css_h, host.dpr)

  host.compositor = dirty_rect_compositor_add_rect(host.compositor, phys_x, phys_y, phys_w, phys_h)
  return host
@end

@fn canvas_host_begin_frame(host, timestamp_ms)
  host.timing_loop = frame_timing_loop_tick(host.timing_loop, timestamp_ms)
  host.renderer = unified_renderer_begin_frame(host.renderer, host.clear_color)
  return host
@end

@fn canvas_host_push_clip(host, css_x, css_y, css_w, css_h)
  phys_x = canvas_scale_css_to_physical(css_x, host.dpr)
  phys_y = canvas_scale_css_to_physical(css_y, host.dpr)
  phys_w = canvas_scale_css_to_physical(css_w, host.dpr)
  phys_h = canvas_scale_css_to_physical(css_h, host.dpr)

  host.renderer = unified_renderer_push_clip(host.renderer, phys_x, phys_y, phys_w, phys_h)
  return host
@end

@fn canvas_host_pop_clip(host)
  host.renderer = unified_renderer_pop_clip(host.renderer)
  return host
@end

@fn canvas_host_draw_rect(host, css_x, css_y, css_w, css_h, bg_col, border_col, border_w, radius)
  phys_x = canvas_scale_css_to_physical(css_x, host.dpr)
  phys_y = canvas_scale_css_to_physical(css_y, host.dpr)
  phys_w = canvas_scale_css_to_physical(css_w, host.dpr)
  phys_h = canvas_scale_css_to_physical(css_h, host.dpr)
  phys_bw = canvas_scale_css_to_physical(border_w, host.dpr)
  phys_r = canvas_scale_css_to_physical(radius, host.dpr)

  host.renderer = unified_renderer_draw_rect(host.renderer, phys_x, phys_y, phys_w, phys_h, bg_col, border_col, phys_bw, phys_r)
  host.compositor = dirty_rect_compositor_add_rect(host.compositor, phys_x, phys_y, phys_w, phys_h)
  return host
@end

@fn canvas_host_draw_shadow_rect(host, css_x, css_y, css_w, css_h, bg_col, radius, shadow_col, shadow_blur, off_x, off_y)
  phys_x = canvas_scale_css_to_physical(css_x, host.dpr)
  phys_y = canvas_scale_css_to_physical(css_y, host.dpr)
  phys_w = canvas_scale_css_to_physical(css_w, host.dpr)
  phys_h = canvas_scale_css_to_physical(css_h, host.dpr)
  phys_r = canvas_scale_css_to_physical(radius, host.dpr)
  phys_blur = canvas_scale_css_to_physical(shadow_blur, host.dpr)
  phys_ox = canvas_scale_css_to_physical(off_x, host.dpr)
  phys_oy = canvas_scale_css_to_physical(off_y, host.dpr)

  host.renderer = unified_renderer_draw_shadow_rect(host.renderer, phys_x, phys_y, phys_w, phys_h, bg_col, phys_r, shadow_col, phys_blur, phys_ox, phys_oy)
  host.compositor = dirty_rect_compositor_add_rect(host.compositor, phys_x, phys_y, phys_w, phys_h)
  return host
@end

@fn canvas_host_draw_text(host, text, css_x, css_y, font_size, color)
  phys_x = canvas_scale_css_to_physical(css_x, host.dpr)
  phys_y = canvas_scale_css_to_physical(css_y, host.dpr)
  phys_fs = canvas_scale_css_to_physical(font_size, host.dpr)

  host.renderer = unified_renderer_draw_text(host.renderer, text, phys_x, phys_y, phys_fs, color)
  
  approx_w = text.len() * (font_size * 7 / 10)
  approx_phys_w = canvas_scale_css_to_physical(approx_w, host.dpr)
  host.compositor = dirty_rect_compositor_add_rect(host.compositor, phys_x, phys_y, approx_phys_w, phys_fs)
  return host
@end

@fn canvas_host_draw_image(host, tex_id, sx, sy, sw, sh, css_dx, css_dy, css_dw, css_dh, opacity)
  phys_dx = canvas_scale_css_to_physical(css_dx, host.dpr)
  phys_dy = canvas_scale_css_to_physical(css_dy, host.dpr)
  phys_dw = canvas_scale_css_to_physical(css_dw, host.dpr)
  phys_dh = canvas_scale_css_to_physical(css_dh, host.dpr)

  host.renderer = unified_renderer_draw_image(host.renderer, tex_id, sx, sy, sw, sh, phys_dx, phys_dy, phys_dw, phys_dh, opacity)
  host.compositor = dirty_rect_compositor_add_rect(host.compositor, phys_dx, phys_dy, phys_dw, phys_dh)
  return host
@end

@fn canvas_host_present_frame(host)
  host.renderer = unified_renderer_end_frame(host.renderer)
  host.presented_frames = host.presented_frames + 1
  host.compositor = dirty_rect_compositor_reset(host.compositor)
  return host
@end

@fn canvas_host_get_pixel(host, phys_x, phys_y)
  return unified_renderer_get_pixel(host.renderer, phys_x, phys_y)
@end

@fn canvas_host_get_telemetry(host)
  r_stats = unified_renderer_get_stats(host.renderer)
  return {
    canvas_id: host.canvas_id,
    css_width: host.css_width,
    css_height: host.css_height,
    dpr: host.dpr,
    physical_width: host.physical_width,
    physical_height: host.physical_height,
    tier: host.renderer.tier,
    status: host.renderer.status,
    presented_frames: host.presented_frames,
    timing_frame_count: host.timing_loop.loop_frame_count,
    fps_estimate: host.timing_loop.loop_fps_estimate,
    delta_time_ms: host.timing_loop.loop_delta_time_ms,
    draw_calls: r_stats.draw_calls,
    total_quads: r_stats.total_quads,
    downgrade_count: r_stats.downgrade_count
  }
@end
