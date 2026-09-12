@! ============================================================================
@! LIPI WEB FRONTEND ENGINE — UNIFIED AUTO-DOWNGRADING GPU RENDERER
@! Module: universe/web/frontend/renderer/unified_renderer.lp
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Features:
@! - Unified frontend rendering interface
@! - Auto-probing capability detection
@! - Dynamic 3-Tier downgrade state machine (WebGPU -> WebGL2 -> Canvas2D)
@! - State preservation across backend transitions
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"
import "universe/web/frontend/renderer/webgpu_renderer"
import "universe/web/frontend/renderer/webgl2_renderer"
import "universe/web/frontend/renderer/canvas2d_renderer"

@! ----------------------------------------------------------------------------
@! 1. CONSTANTS & ENUMS
@! ----------------------------------------------------------------------------

@! Renderer Backend Tiers:
@! 1 = WebGPU (Tier 1: WGSL, SDF, Compute)
@! 2 = WebGL2 (Tier 2: GLSL ES 3.00, Instanced VAO/VBO)
@! 3 = Canvas 2D (Tier 3: Pure Maya CPU ARGB Framebuffer)

@struct RendererCapabilities
  cap_has_webgpu: bool
  cap_has_webgl2: bool
  cap_has_canvas2d: bool
  cap_max_texture_size: i64
  cap_supports_compute: bool
  cap_supports_sdf_anti_aliasing: bool
  cap_supports_instancing: bool
  cap_vendor_string: string
@end

@struct UnifiedRenderer
  tier: i64
  target_tier: i64
  status: string
  width: i64
  height: i64
  scale_factor: f64
  capabilities: any
  webgpu_backend: any
  webgl2_backend: any
  canvas2d_backend: any
  frame_count: i64
  total_draw_ops: i64
  downgrade_log: array
  clip_stack: array
  current_clip: array
@end

@! ----------------------------------------------------------------------------
@! 2. CAPABILITY PROBING & CONSTRUCTOR
@! ----------------------------------------------------------------------------

@fn unified_renderer_probe_capabilities(mock_webgpu, mock_webgl2)
  webgpu_ok = true
  @if mock_webgpu == false
    webgpu_ok = false
  @end
  
  webgl2_ok = true
  @if mock_webgl2 == false
    webgl2_ok = false
  @end
  
  return {
    cap_has_webgpu: webgpu_ok,
    cap_has_webgl2: webgl2_ok,
    cap_has_canvas2d: true,
    cap_max_texture_size: 8192,
    cap_supports_compute: webgpu_ok,
    cap_supports_sdf_anti_aliasing: webgpu_ok || webgl2_ok,
    cap_supports_instancing: webgpu_ok || webgl2_ok,
    cap_vendor_string: "Lipi Universal Web Graphics Pipeline"
  }
@end

@fn unified_renderer_init_with_caps(preferred_tier, width, height, scale_factor, caps)
  @if width <= 0 width = 1 @end
  @if height <= 0 height = 1 @end
  @if scale_factor <= 0.0 scale_factor = 1.0 @end
  
  active_tier = preferred_tier
  downgrade_history = []
  
  @! Probe & Auto-Downgrade Decision Tree
  @if active_tier == 1 && caps.cap_has_webgpu == false
    active_tier = 2
    downgrade_history = downgrade_history.push("Auto-Probe: WebGPU unsupported, downgraded to Tier 2 (WebGL2)")
  @end
  
  @if active_tier == 2 && caps.cap_has_webgl2 == false
    active_tier = 3
    downgrade_history = downgrade_history.push("Auto-Probe: WebGL2 unsupported, downgraded to Tier 3 (Canvas2D)")
  @end
  
  @if active_tier < 1 || active_tier > 3
    active_tier = 3
  @end
  
  gpu_be = webgpu_renderer_new(width, height, scale_factor)
  gl_be = webgl2_renderer_new(width, height, scale_factor)
  c2d_be = canvas2d_renderer_new(width, height, scale_factor)
  
  status_str = "ACTIVE"
  @if active_tier != preferred_tier
    status_str = "DOWNGRADED"
  @end
  
  init_clip = [0, 0, width, height]
  
  return {
    tier: active_tier,
    target_tier: preferred_tier,
    status: status_str,
    width: width,
    height: height,
    scale_factor: scale_factor,
    capabilities: caps,
    webgpu_backend: gpu_be,
    webgl2_backend: gl_be,
    canvas2d_backend: c2d_be,
    frame_count: 0,
    total_draw_ops: 0,
    downgrade_log: downgrade_history,
    clip_stack: [],
    current_clip: init_clip
  }
@end

@fn unified_renderer_new(preferred_tier, width, height, scale_factor)
  caps = unified_renderer_probe_capabilities(true, true)
  return unified_renderer_init_with_caps(preferred_tier, width, height, scale_factor, caps)
@end

@! ----------------------------------------------------------------------------
@! 3. DYNAMIC AUTO-DOWNGRADE STATE MACHINE
@! ----------------------------------------------------------------------------

@fn unified_renderer_downgrade(renderer, reason)
  @if renderer.tier == 1
    @! Downgrade from Tier 1 (WebGPU) to Tier 2 (WebGL2) or Tier 3
    caps = renderer.capabilities
    @if caps.cap_has_webgl2
      renderer.tier = 2
      renderer.status = "DOWNGRADED"
      msg = string_concat("Runtime Downgrade: WebGPU -> WebGL2 (Reason: ", string_concat(reason, ")"))
      renderer.downgrade_log = renderer.downgrade_log.push(msg)
      renderer.webgl2_backend = webgl2_renderer_new(renderer.width, renderer.height, renderer.scale_factor)
    @else
      renderer.tier = 3
      renderer.status = "DOWNGRADED"
      msg = string_concat("Runtime Downgrade: WebGPU -> Canvas2D (Reason: ", string_concat(reason, ")"))
      renderer.downgrade_log = renderer.downgrade_log.push(msg)
      renderer.canvas2d_backend = canvas2d_renderer_new(renderer.width, renderer.height, renderer.scale_factor)
    @end
  @else
    @if renderer.tier == 2
      @! Downgrade from Tier 2 (WebGL2) to Tier 3 (Canvas2D)
      renderer.tier = 3
      renderer.status = "DOWNGRADED"
      msg = string_concat("Runtime Downgrade: WebGL2 -> Canvas2D (Reason: ", string_concat(reason, ")"))
      renderer.downgrade_log = renderer.downgrade_log.push(msg)
      renderer.canvas2d_backend = canvas2d_renderer_new(renderer.width, renderer.height, renderer.scale_factor)
    @else
      @! Already Tier 3 (Canvas2D) — Terminal Failure
      renderer.status = "FAILED"
      msg = string_concat("Fatal Error: Canvas2D is lowest tier, cannot downgrade further (Reason: ", string_concat(reason, ")"))
      renderer.downgrade_log = renderer.downgrade_log.push(msg)
    @end
  @end
  
  return renderer
@end

@! ----------------------------------------------------------------------------
@! 4. UNIFIED FRAME LIFECYCLE & SCISSORING
@! ----------------------------------------------------------------------------

@fn unified_renderer_begin_frame(renderer, clear_color)
  renderer.clip_stack = []
  renderer.current_clip = [0, 0, renderer.width, renderer.height]
  
  @if renderer.tier == 1
    renderer.webgpu_backend = webgpu_renderer_begin_frame(renderer.webgpu_backend, clear_color)
  @else
    @if renderer.tier == 2
      renderer.webgl2_backend = webgl2_renderer_begin_frame(renderer.webgl2_backend, clear_color)
    @else
      renderer.canvas2d_backend = canvas2d_renderer_begin_frame(renderer.canvas2d_backend, clear_color)
    @end
  @end
  
  return renderer
@end

@fn unified_renderer_push_clip(renderer, x, y, w, h)
  cur = renderer.current_clip
  req_min_x = x
  req_min_y = y
  req_max_x = x + w
  req_max_y = y + h
  
  new_min_x = cur[0]
  @if req_min_x > new_min_x new_min_x = req_min_x @end
  new_min_y = cur[1]
  @if req_min_y > new_min_y new_min_y = req_min_y @end
  new_max_x = cur[2]
  @if req_max_x < new_max_x new_max_x = req_max_x @end
  new_max_y = cur[3]
  @if req_max_y < new_max_y new_max_y = req_max_y @end
  
  @if new_min_x > new_max_x new_min_x = new_max_x @end
  @if new_min_y > new_max_y new_min_y = new_max_y @end
  
  renderer.clip_stack = renderer.clip_stack.push(cur)
  renderer.current_clip = [new_min_x, new_min_y, new_max_x, new_max_y]
  
  @if renderer.tier == 1
    renderer.webgpu_backend = webgpu_renderer_push_clip(renderer.webgpu_backend, x, y, w, h)
  @else
    @if renderer.tier == 2
      renderer.webgl2_backend = webgl2_renderer_push_clip(renderer.webgl2_backend, x, y, w, h)
    @else
      renderer.canvas2d_backend = canvas2d_renderer_push_clip(renderer.canvas2d_backend, x, y, w, h)
    @end
  @end
  
  return renderer
@end

@fn unified_renderer_pop_clip(renderer)
  stack_len = renderer.clip_stack.len()
  @if stack_len > 0
    top_idx = stack_len - 1
    renderer.current_clip = renderer.clip_stack[top_idx]
    
    new_stack = []
    i = 0
    @while i < top_idx
      new_stack = new_stack.push(renderer.clip_stack[i])
      i = i + 1
    @end
    renderer.clip_stack = new_stack
  @else
    renderer.current_clip = [0, 0, renderer.width, renderer.height]
  @end
  
  @if renderer.tier == 1
    renderer.webgpu_backend = webgpu_renderer_pop_clip(renderer.webgpu_backend)
  @else
    @if renderer.tier == 2
      renderer.webgl2_backend = webgl2_renderer_pop_clip(renderer.webgl2_backend)
    @else
      renderer.canvas2d_backend = canvas2d_renderer_pop_clip(renderer.canvas2d_backend)
    @end
  @end
  
  return renderer
@end

@! ----------------------------------------------------------------------------
@! 5. DRAWING PRIMITIVES DISPATCH
@! ----------------------------------------------------------------------------

@fn unified_renderer_draw_rect(renderer, x, y, w, h, bg_col, border_col, border_w, radius)
  renderer.total_draw_ops = renderer.total_draw_ops + 1
  
  @if renderer.tier == 1
    renderer.webgpu_backend = webgpu_renderer_draw_rect(renderer.webgpu_backend, x, y, w, h, bg_col, border_col, border_w, radius)
  @else
    @if renderer.tier == 2
      renderer.webgl2_backend = webgl2_renderer_draw_rect(renderer.webgl2_backend, x, y, w, h, bg_col, border_col, border_w, radius)
    @else
      renderer.canvas2d_backend = canvas2d_renderer_draw_rect(renderer.canvas2d_backend, x, y, w, h, bg_col, border_col, border_w, radius)
    @end
  @end
  
  return renderer
@end

@fn unified_renderer_draw_shadow_rect(renderer, x, y, w, h, bg_col, radius, shadow_col, shadow_blur, off_x, off_y)
  renderer.total_draw_ops = renderer.total_draw_ops + 1
  
  @if renderer.tier == 1
    renderer.webgpu_backend = webgpu_renderer_draw_shadow_rect(renderer.webgpu_backend, x, y, w, h, bg_col, radius, shadow_col, shadow_blur, off_x, off_y)
  @else
    @if renderer.tier == 2
      renderer.webgl2_backend = webgl2_renderer_draw_rect(renderer.webgl2_backend, x, y, w, h, bg_col, 0, 0, radius)
    @else
      renderer.canvas2d_backend = canvas2d_renderer_draw_shadow_rect(renderer.canvas2d_backend, x, y, w, h, bg_col, radius, shadow_col, shadow_blur, off_x, off_y)
    @end
  @end
  
  return renderer
@end

@fn unified_renderer_draw_text(renderer, text, x, y, font_size, color)
  renderer.total_draw_ops = renderer.total_draw_ops + 1
  
  @if renderer.tier == 1
    renderer.webgpu_backend = webgpu_renderer_draw_text(renderer.webgpu_backend, text, x, y, font_size, color)
  @else
    @if renderer.tier == 2
      renderer.webgl2_backend = webgl2_renderer_draw_text(renderer.webgl2_backend, text, x, y, font_size, color)
    @else
      renderer.canvas2d_backend = canvas2d_renderer_draw_text(renderer.canvas2d_backend, text, x, y, font_size, color)
    @end
  @end
  
  return renderer
@end

@fn unified_renderer_draw_image(renderer, texture_id, sx, sy, sw, sh, dx, dy, dw, dh, opacity)
  renderer.total_draw_ops = renderer.total_draw_ops + 1
  
  @if renderer.tier == 1
    renderer.webgpu_backend = webgpu_renderer_draw_image(renderer.webgpu_backend, texture_id, sx, sy, sw, sh, dx, dy, dw, dh, opacity)
  @else
    @if renderer.tier == 2
      renderer.webgl2_backend = webgl2_renderer_draw_image(renderer.webgl2_backend, texture_id, sx, sy, sw, sh, dx, dy, dw, dh, opacity)
    @else
      renderer.canvas2d_backend = canvas2d_renderer_draw_image(renderer.canvas2d_backend, texture_id, sx, sy, sw, sh, dx, dy, dw, dh, opacity)
    @end
  @end
  
  return renderer
@end

@! ----------------------------------------------------------------------------
@! 6. FRAME COMPLETION & QUERY HELPERS
@! ----------------------------------------------------------------------------

@fn unified_renderer_end_frame(renderer)
  @if renderer.tier == 1
    renderer.webgpu_backend = webgpu_renderer_end_frame(renderer.webgpu_backend)
  @else
    @if renderer.tier == 2
      renderer.webgl2_backend = webgl2_renderer_end_frame(renderer.webgl2_backend)
    @else
      renderer.canvas2d_backend = canvas2d_renderer_end_frame(renderer.canvas2d_backend)
    @end
  @end
  
  renderer.frame_count = renderer.frame_count + 1
  return renderer
@end

@fn unified_renderer_get_tier(renderer)
  return renderer.tier
@end

@fn unified_renderer_get_status(renderer)
  return renderer.status
@end

@fn unified_renderer_get_stats(renderer)
  draw_calls = 0
  quads = 0
  
  @if renderer.tier == 1
    gpu_be = renderer.webgpu_backend
    draw_calls = gpu_be.gpu_draw_call_count
    quads = gpu_be.gpu_total_quads
  @else
    @if renderer.tier == 2
      gl_be = renderer.webgl2_backend
      draw_calls = gl_be.gl_draw_call_count
      quads = gl_be.gl_total_quads
    @else
      c2d_be = renderer.canvas2d_backend
      draw_calls = c2d_be.c2d_draw_call_count
      quads = c2d_be.c2d_total_quads
    @end
  @end
  
  return {
    tier: renderer.tier,
    status: renderer.status,
    frames: renderer.frame_count,
    draw_calls: draw_calls,
    total_quads: quads,
    downgrade_count: renderer.downgrade_log.len()
  }
@end

@fn unified_renderer_get_pixel(renderer, x, y)
  @if renderer.tier == 3
    return canvas2d_renderer_get_pixel(renderer.canvas2d_backend, x, y)
  @end
  return 0
@end
