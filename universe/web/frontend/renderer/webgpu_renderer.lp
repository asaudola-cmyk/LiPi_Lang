@! ============================================================================
@! LIPI WEB FRONTEND ENGINE — TIER 1 WEBGPU RENDERER
@! Module: universe/web/frontend/renderer/webgpu_renderer.lp
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Emits WGSL draw commands, vertex/index buffers, uniform bind groups,
@! SDF rounded rectangles, drop shadows, gradients, and glyph pipelines.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURE DEFINITIONS
@! ----------------------------------------------------------------------------

@struct WebGpuQuadInstance
  x: f64
  y: f64
  width: f64
  height: f64
  bg_r: f64
  bg_g: f64
  bg_b: f64
  bg_a: f64
  border_r: f64
  border_g: f64
  border_b: f64
  border_a: f64
  border_width: f64
  radius_tl: f64
  radius_tr: f64
  radius_br: f64
  radius_bl: f64
  flags: i64
  clip_min_x: f64
  clip_min_y: f64
  clip_max_x: f64
  clip_max_y: f64
  shadow_r: f64
  shadow_g: f64
  shadow_b: f64
  shadow_a: f64
  shadow_blur: f64
  shadow_off_x: f64
  shadow_off_y: f64
  shadow_spread: f64
  grad_r: f64
  grad_g: f64
  grad_b: f64
  grad_a: f64
  texture_id: i64
  text_content: string
  font_size: f64
@end

@struct WebGpuPipeline
  pipe_name: string
  shader_code: string
  vertex_entry: string
  fragment_entry: string
  bind_group_layout: array
  pipe_is_compiled: bool
@end

@struct WebGpuCommandBuffer
  cb_commands: array
  cb_draw_call_count: i64
  cb_instance_count: i64
  cb_byte_size: i64
@end

@struct WebGpuRenderer
  gpu_width: i64
  gpu_height: i64
  gpu_scale_factor: f64
  gpu_is_ready: bool
  gpu_is_device_lost: bool
  gpu_clear_color: i64
  gpu_clip_stack: array
  gpu_current_clip: array
  gpu_instances: array
  gpu_pipelines: array
  gpu_commands: array
  gpu_command_buffer: any
  gpu_draw_call_count: i64
  gpu_total_quads: i64
  gpu_uniform_bind_group: array
  gpu_storage_buffer_bytes: array
  gpu_wgsl_shader_source: string
@end

@! ----------------------------------------------------------------------------
@! 2. COLOR PARSING & MATH HELPERS
@! ----------------------------------------------------------------------------

@fn webgpu_unpack_color(color)
  a_byte = (color / 16777216) & 255
  r_byte = (color / 65536) & 255
  g_byte = (color / 256) & 255
  b_byte = color & 255
  
  @if a_byte == 0 && color != 0
    a_byte = 255
  @end
  
  return [r_byte / 255.0, g_byte / 255.0, b_byte / 255.0, a_byte / 255.0]
@end

@! ----------------------------------------------------------------------------
@! 3. CONSTRUCTOR & PIPELINE INITIALIZATION
@! ----------------------------------------------------------------------------

@fn webgpu_renderer_new(width, height, scale_factor)
  @if width <= 0 width = 1 @end
  @if height <= 0 height = 1 @end
  @if scale_factor <= 0.0 scale_factor = 1.0 @end
  
  init_clip = [0.0, 0.0, width * 1.0, height * 1.0]
  
  cmd_buf = {
    cb_commands: [],
    cb_draw_call_count: 0,
    cb_instance_count: 0,
    cb_byte_size: 0
  }
  
  renderer = {
    gpu_width: width,
    gpu_height: height,
    gpu_scale_factor: scale_factor,
    gpu_is_ready: true,
    gpu_is_device_lost: false,
    gpu_clear_color: 0xFF000000,
    gpu_clip_stack: [],
    gpu_current_clip: init_clip,
    gpu_instances: [],
    gpu_pipelines: [],
    gpu_commands: [],
    gpu_command_buffer: cmd_buf,
    gpu_draw_call_count: 0,
    gpu_total_quads: 0,
    gpu_uniform_bind_group: [],
    gpu_storage_buffer_bytes: [],
    gpu_wgsl_shader_source: ""
  }
  
  renderer = webgpu_renderer_init_pipelines(renderer)
  return renderer
@end

@fn webgpu_renderer_init_pipelines(renderer)
  sdf_pipe = {
    pipe_name: "sdf_rounded_rect",
    shader_code: "universe/web/frontend/renderer/shaders/ui_draw.wgsl",
    vertex_entry: "vs_main",
    fragment_entry: "fs_main",
    bind_group_layout: ["uniforms", "instances", "font_texture", "font_sampler"],
    pipe_is_compiled: true
  }
  
  shadow_pipe = {
    pipe_name: "sdf_drop_shadow",
    shader_code: "universe/web/frontend/renderer/shaders/ui_draw.wgsl",
    vertex_entry: "vs_main",
    fragment_entry: "fs_main",
    bind_group_layout: ["uniforms", "instances"],
    pipe_is_compiled: true
  }
  
  text_pipe = {
    pipe_name: "text_glyph_mask",
    shader_code: "universe/web/frontend/renderer/shaders/ui_draw.wgsl",
    vertex_entry: "vs_main",
    fragment_entry: "fs_main",
    bind_group_layout: ["uniforms", "instances", "font_texture", "font_sampler"],
    pipe_is_compiled: true
  }
  
  image_pipe = {
    pipe_name: "image_blit",
    shader_code: "universe/web/frontend/renderer/shaders/ui_draw.wgsl",
    vertex_entry: "vs_main",
    fragment_entry: "fs_main",
    bind_group_layout: ["uniforms", "instances", "image_texture", "image_sampler"],
    pipe_is_compiled: true
  }
  
  pipes = [sdf_pipe, shadow_pipe, text_pipe, image_pipe]
  renderer.gpu_pipelines = pipes
  renderer.gpu_wgsl_shader_source = "universe/web/frontend/renderer/shaders/ui_draw.wgsl"
  return renderer
@end

@! ----------------------------------------------------------------------------
@! 4. FRAME LIFECYCLE & VIEWPORT MANAGEMENT
@! ----------------------------------------------------------------------------

@fn webgpu_renderer_begin_frame(renderer, clear_color)
  renderer.gpu_instances = []
  renderer.gpu_commands = []
  renderer.gpu_clear_color = clear_color
  renderer.gpu_clip_stack = []
  renderer.gpu_current_clip = [0.0, 0.0, renderer.gpu_width * 1.0, renderer.gpu_height * 1.0]
  
  clear_rgba = webgpu_unpack_color(clear_color)
  begin_cmd = {
    type: "BEGIN_RENDER_PASS",
    clear_r: clear_rgba[0],
    clear_g: clear_rgba[1],
    clear_b: clear_rgba[2],
    clear_a: clear_rgba[3],
    viewport_w: renderer.gpu_width,
    viewport_h: renderer.gpu_height
  }
  renderer.gpu_commands = renderer.gpu_commands.push(begin_cmd)
  return renderer
@end

@fn webgpu_renderer_push_clip(renderer, x, y, w, h)
  cur = renderer.gpu_current_clip
  req_min_x = x * 1.0
  req_min_y = y * 1.0
  req_max_x = (x + w) * 1.0
  req_max_y = (y + h) * 1.0
  
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
  
  renderer.gpu_clip_stack = renderer.gpu_clip_stack.push(cur)
  renderer.gpu_current_clip = [new_min_x, new_min_y, new_max_x, new_max_y]
  
  clip_cmd = {
    type: "SET_SCISSOR_RECT",
    x: new_min_x,
    y: new_min_y,
    width: new_max_x - new_min_x,
    height: new_max_y - new_min_y
  }
  renderer.gpu_commands = renderer.gpu_commands.push(clip_cmd)
  return renderer
@end

@fn webgpu_renderer_pop_clip(renderer)
  stack_len = renderer.gpu_clip_stack.len()
  @if stack_len > 0
    top_idx = stack_len - 1
    renderer.gpu_current_clip = renderer.gpu_clip_stack[top_idx]
    
    new_stack = []
    i = 0
    @while i < top_idx
      new_stack = new_stack.push(renderer.gpu_clip_stack[i])
      i = i + 1
    @end
    renderer.gpu_clip_stack = new_stack
  @else
    renderer.gpu_current_clip = [0.0, 0.0, renderer.gpu_width * 1.0, renderer.gpu_height * 1.0]
  @end
  
  cur = renderer.gpu_current_clip
  clip_cmd = {
    type: "SET_SCISSOR_RECT",
    x: cur[0],
    y: cur[1],
    width: cur[2] - cur[0],
    height: cur[3] - cur[1]
  }
  renderer.gpu_commands = renderer.gpu_commands.push(clip_cmd)
  return renderer
@end

@! ----------------------------------------------------------------------------
@! 5. DRAWING COMMAND EMITTERS
@! ----------------------------------------------------------------------------

@fn webgpu_renderer_draw_rect(renderer, x, y, w, h, bg_col, border_col, border_w, radius)
  @if w <= 0 || h <= 0 return renderer @end
  
  bg_rgba = webgpu_unpack_color(bg_col)
  b_rgba = webgpu_unpack_color(border_col)
  clip = renderer.gpu_current_clip
  
  flags = 0
  @if radius > 0 flags = flags | 1 @end
  @if border_w > 0 flags = flags | 2 @end
  
  inst = {
    x: x * 1.0,
    y: y * 1.0,
    width: w * 1.0,
    height: h * 1.0,
    bg_r: bg_rgba[0],
    bg_g: bg_rgba[1],
    bg_b: bg_rgba[2],
    bg_a: bg_rgba[3],
    border_r: b_rgba[0],
    border_g: b_rgba[1],
    border_b: b_rgba[2],
    border_a: b_rgba[3],
    border_width: border_w * 1.0,
    radius_tl: radius * 1.0,
    radius_tr: radius * 1.0,
    radius_br: radius * 1.0,
    radius_bl: radius * 1.0,
    flags: flags,
    clip_min_x: clip[0],
    clip_min_y: clip[1],
    clip_max_x: clip[2],
    clip_max_y: clip[3],
    shadow_r: 0.0,
    shadow_g: 0.0,
    shadow_b: 0.0,
    shadow_a: 0.0,
    shadow_blur: 0.0,
    shadow_off_x: 0.0,
    shadow_off_y: 0.0,
    shadow_spread: 0.0,
    grad_r: 0.0,
    grad_g: 0.0,
    grad_b: 0.0,
    grad_a: 0.0,
    texture_id: 0,
    text_content: "",
    font_size: 0.0
  }
  
  renderer.gpu_instances = renderer.gpu_instances.push(inst)
  renderer.gpu_total_quads = renderer.gpu_total_quads + 1
  return renderer
@end

@fn webgpu_renderer_draw_shadow_rect(renderer, x, y, w, h, bg_col, radius, shadow_col, shadow_blur, off_x, off_y)
  @if w <= 0 || h <= 0 return renderer @end
  
  bg_rgba = webgpu_unpack_color(bg_col)
  s_rgba = webgpu_unpack_color(shadow_col)
  clip = renderer.gpu_current_clip
  
  flags = 4 @! Bit 2: Shadow Enabled
  @if radius > 0 flags = flags | 1 @end
  
  inst = {
    x: x * 1.0,
    y: y * 1.0,
    width: w * 1.0,
    height: h * 1.0,
    bg_r: bg_rgba[0],
    bg_g: bg_rgba[1],
    bg_b: bg_rgba[2],
    bg_a: bg_rgba[3],
    border_r: 0.0,
    border_g: 0.0,
    border_b: 0.0,
    border_a: 0.0,
    border_width: 0.0,
    radius_tl: radius * 1.0,
    radius_tr: radius * 1.0,
    radius_br: radius * 1.0,
    radius_bl: radius * 1.0,
    flags: flags,
    clip_min_x: clip[0],
    clip_min_y: clip[1],
    clip_max_x: clip[2],
    clip_max_y: clip[3],
    shadow_r: s_rgba[0],
    shadow_g: s_rgba[1],
    shadow_b: s_rgba[2],
    shadow_a: s_rgba[3],
    shadow_blur: shadow_blur * 1.0,
    shadow_off_x: off_x * 1.0,
    shadow_off_y: off_y * 1.0,
    shadow_spread: 0.0,
    grad_r: 0.0,
    grad_g: 0.0,
    grad_b: 0.0,
    grad_a: 0.0,
    texture_id: 0,
    text_content: "",
    font_size: 0.0
  }
  
  renderer.gpu_instances = renderer.gpu_instances.push(inst)
  renderer.gpu_total_quads = renderer.gpu_total_quads + 1
  return renderer
@end

@fn webgpu_renderer_draw_text(renderer, text, x, y, font_size, color)
  @if text == "" || font_size <= 0 return renderer @end
  
  c_rgba = webgpu_unpack_color(color)
  clip = renderer.gpu_current_clip
  
  text_w = text.len() * font_size * 0.6
  text_h = font_size * 1.2
  
  inst = {
    x: x * 1.0,
    y: y * 1.0,
    width: text_w,
    height: text_h,
    bg_r: c_rgba[0],
    bg_g: c_rgba[1],
    bg_b: c_rgba[2],
    bg_a: c_rgba[3],
    border_r: 0.0,
    border_g: 0.0,
    border_b: 0.0,
    border_a: 0.0,
    border_width: 0.0,
    radius_tl: 0.0,
    radius_tr: 0.0,
    radius_br: 0.0,
    radius_bl: 0.0,
    flags: 8, @! Bit 3: Glyph / Text
    clip_min_x: clip[0],
    clip_min_y: clip[1],
    clip_max_x: clip[2],
    clip_max_y: clip[3],
    shadow_r: 0.0,
    shadow_g: 0.0,
    shadow_b: 0.0,
    shadow_a: 0.0,
    shadow_blur: 0.0,
    shadow_off_x: 0.0,
    shadow_off_y: 0.0,
    shadow_spread: 0.0,
    grad_r: 0.0,
    grad_g: 0.0,
    grad_b: 0.0,
    grad_a: 0.0,
    texture_id: 0,
    text_content: text,
    font_size: font_size * 1.0
  }
  
  renderer.gpu_instances = renderer.gpu_instances.push(inst)
  renderer.gpu_total_quads = renderer.gpu_total_quads + 1
  return renderer
@end

@fn webgpu_renderer_draw_image(renderer, texture_id, sx, sy, sw, sh, dx, dy, dw, dh, opacity)
  @if dw <= 0 || dh <= 0 return renderer @end
  
  clip = renderer.gpu_current_clip
  @if opacity <= 0.0 opacity = 1.0 @end
  
  inst = {
    x: dx * 1.0,
    y: dy * 1.0,
    width: dw * 1.0,
    height: dh * 1.0,
    bg_r: 1.0,
    bg_g: 1.0,
    bg_b: 1.0,
    bg_a: opacity,
    border_r: 0.0,
    border_g: 0.0,
    border_b: 0.0,
    border_a: 0.0,
    border_width: 0.0,
    radius_tl: 0.0,
    radius_tr: 0.0,
    radius_br: 0.0,
    radius_bl: 0.0,
    flags: 16, @! Bit 4: Image Texture
    clip_min_x: clip[0],
    clip_min_y: clip[1],
    clip_max_x: clip[2],
    clip_max_y: clip[3],
    shadow_r: 0.0,
    shadow_g: 0.0,
    shadow_b: 0.0,
    shadow_a: 0.0,
    shadow_blur: 0.0,
    shadow_off_x: 0.0,
    shadow_off_y: 0.0,
    shadow_spread: 0.0,
    grad_r: 0.0,
    grad_g: 0.0,
    grad_b: 0.0,
    grad_a: 0.0,
    texture_id: texture_id,
    text_content: "",
    font_size: 0.0
  }
  
  renderer.gpu_instances = renderer.gpu_instances.push(inst)
  renderer.gpu_total_quads = renderer.gpu_total_quads + 1
  return renderer
@end

@! ----------------------------------------------------------------------------
@! 6. WGSL MEMORY BUFFER & COMMAND BUFFER EMISSION
@! ----------------------------------------------------------------------------

@fn webgpu_renderer_emit_wgsl_buffers(renderer)
  inst_count = renderer.gpu_instances.len()
  
  @! Uniform Bind Group #0 (ViewportUniforms)
  uniform_data = {
    screen_width: renderer.gpu_width * 1.0,
    screen_height: renderer.gpu_height * 1.0,
    scale_factor: renderer.gpu_scale_factor,
    time: 0.0,
    proj_matrix: [
      2.0 / renderer.gpu_width, 0.0, 0.0, 0.0,
      0.0, -2.0 / renderer.gpu_height, 0.0, 0.0,
      0.0, 0.0, 1.0, 0.0,
      -1.0, 1.0, 0.0, 1.0
    ]
  }
  renderer.gpu_uniform_bind_group = [uniform_data]
  
  @! Storage Buffer #1 (QuadInstance array)
  raw_bytes = []
  i = 0
  @while i < inst_count
    inst = renderer.gpu_instances[i]
    record = {
      index: i,
      rect: [inst.x, inst.y, inst.width, inst.height],
      bg_color: [inst.bg_r, inst.bg_g, inst.bg_b, inst.bg_a],
      border_color: [inst.border_r, inst.border_g, inst.border_b, inst.border_a],
      radii: [inst.radius_tl, inst.radius_tr, inst.radius_br, inst.radius_bl],
      border_w: inst.border_width,
      flags: inst.flags,
      clip: [inst.clip_min_x, inst.clip_min_y, inst.clip_max_x, inst.clip_max_y],
      shadow_color: [inst.shadow_r, inst.shadow_g, inst.shadow_b, inst.shadow_a],
      shadow_params: [inst.shadow_off_x, inst.shadow_off_y, inst.shadow_blur, inst.shadow_spread],
      texture_id: inst.texture_id
    }
    raw_bytes = raw_bytes.push(record)
    i = i + 1
  @end
  renderer.gpu_storage_buffer_bytes = raw_bytes
  return renderer
@end

@fn webgpu_renderer_end_frame(renderer)
  @if renderer.gpu_is_device_lost
    return renderer
  @end
  
  renderer = webgpu_renderer_emit_wgsl_buffers(renderer)
  inst_count = renderer.gpu_instances.len()
  
  @if inst_count > 0
    @! Bind SDF Pipeline
    bind_pipe_cmd = {
      type: "SET_PIPELINE",
      pipeline: "sdf_rounded_rect"
    }
    renderer.gpu_commands = renderer.gpu_commands.push(bind_pipe_cmd)
    
    @! Set Bind Group 0
    bind_group_cmd = {
      type: "SET_BIND_GROUP",
      group_idx: 0,
      entries_count: 2
    }
    renderer.gpu_commands = renderer.gpu_commands.push(bind_group_cmd)
    
    @! Draw Instanced (6 vertices per quad * inst_count)
    draw_cmd = {
      type: "DRAW",
      vertex_count: 6,
      instance_count: inst_count,
      first_vertex: 0,
      first_instance: 0
    }
    renderer.gpu_commands = renderer.gpu_commands.push(draw_cmd)
    renderer.gpu_draw_call_count = renderer.gpu_draw_call_count + 1
  @end
  
  end_pass_cmd = {
    type: "END_RENDER_PASS"
  }
  renderer.gpu_commands = renderer.gpu_commands.push(end_pass_cmd)
  
  submit_cmd = {
    type: "QUEUE_SUBMIT",
    command_count: renderer.gpu_commands.len()
  }
  renderer.gpu_commands = renderer.gpu_commands.push(submit_cmd)
  
  renderer.gpu_command_buffer = {
    cb_commands: renderer.gpu_commands,
    cb_draw_call_count: renderer.gpu_draw_call_count,
    cb_instance_count: inst_count,
    cb_byte_size: inst_count * 80
  }
  
  return renderer
@end

@fn webgpu_renderer_simulate_device_loss(renderer)
  renderer.gpu_is_device_lost = true
  renderer.gpu_is_ready = false
  return renderer
@end
