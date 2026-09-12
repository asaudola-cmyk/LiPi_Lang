@! ============================================================================
@! LIPI WEB FRONTEND ENGINE — TIER 2 WEBGL2 FALLBACK RENDERER
@! Module: universe/web/frontend/renderer/webgl2_renderer.lp
@! 100% Pure Lipi Architecture — Zero External Dependencies
@! Emits instanced GLSL ES 3.00 drawing commands, VBO/VAO attribute buffers,
@! Uniform Buffer Objects (UBOs), and scissor clipping commands.
@! ============================================================================

import "universe/core/math"
import "universe/core/collections"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURE DEFINITIONS
@! ----------------------------------------------------------------------------

@struct WebGL2VertexAttribute
  location: i64
  name: string
  size: i64
  attr_type: string
  normalized: bool
  stride: i64
  offset: i64
  divisor: i64
@end

@struct WebGL2Program
  program_id: i64
  name: string
  vert_src: string
  frag_src: string
  attributes: array
  is_linked: bool
@end

@struct WebGL2VBO
  buffer_id: i64
  target: string
  data_size: i64
  usage: string
  records: array
@end

@struct WebGL2VAO
  vao_id: i64
  quad_vbo: any
  instance_vbo: any
  attributes: array
  is_bound: bool
@end

@struct WebGL2DrawCommand
  cmd_type: string
  mode: string
  first: i64
  count: i64
  instance_count: i64
  scissor_rect: array
@end

@struct WebGL2Renderer
  gl_context_id: i64
  gl_width: i64
  gl_height: i64
  gl_scale_factor: f64
  gl_is_ready: bool
  gl_is_context_lost: bool
  gl_clear_color: i64
  gl_clip_stack: array
  gl_current_clip: array
  gl_instances: array
  gl_commands: array
  gl_draw_call_count: i64
  gl_total_quads: i64
  gl_ubo_data: array
  gl_programs: array
  gl_active_program: any
  gl_vao: any
@end

@! ----------------------------------------------------------------------------
@! 2. COLOR PARSING & HELPERS
@! ----------------------------------------------------------------------------

@fn webgl2_unpack_color(color)
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
@! 3. GLSL ES 3.00 SHADER SOURCE GENERATOR
@! ----------------------------------------------------------------------------

@fn webgl2_generate_vert_shader()
  s = "#version 300 es\n"
  s = s + "layout(location = 0) in vec2 a_quad_pos;\n"
  s = s + "layout(location = 1) in vec4 a_rect;\n"
  s = s + "layout(location = 2) in vec4 a_bg_color;\n"
  s = s + "layout(location = 3) in vec4 a_border_color;\n"
  s = s + "layout(location = 4) in vec4 a_radii;\n"
  s = s + "layout(location = 5) in vec4 a_clip_rect;\n"
  s = s + "layout(location = 6) in float a_border_width;\n"
  s = s + "layout(location = 7) in uint a_flags;\n"
  s = s + "layout(std140) uniform {\n"
  s = s + "    vec2 u_resolution;\n"
  s = s + "    float u_scale;\n"
  s = s + "    float u_time;\n"
  s = s + "};\n"
  s = s + "out vec2 v_uv;\n"
  s = s + "out vec2 v_local_pos;\n"
  s = s + "out vec2 v_screen_pos;\n"
  s = s + "flat out vec4 v_bg_color;\n"
  s = s + "flat out vec4 v_border_color;\n"
  s = s + "flat out vec4 v_radii;\n"
  s = s + "flat out vec4 v_clip_rect;\n"
  s = s + "flat out float v_border_width;\n"
  s = s + "flat out uint v_flags;\n"
  s = s + "flat out vec2 v_size;\n"
  s = s + "void main() {\n"
  s = s + "    v_uv = a_quad_pos;\n"
  s = s + "    vec2 pixel_pos = a_rect.xy + (a_quad_pos * a_rect.zw);\n"
  s = s + "    vec2 clip_pos = (pixel_pos / u_resolution) * 2.0 - 1.0;\n"
  s = s + "    clip_pos.y = -clip_pos.y;\n"
  s = s + "    gl_Position = vec4(clip_pos, 0.0, 1.0);\n"
  s = s + "    v_local_pos = a_quad_pos * a_rect.zw;\n"
  s = s + "    v_screen_pos = pixel_pos;\n"
  s = s + "    v_bg_color = a_bg_color;\n"
  s = s + "    v_border_color = a_border_color;\n"
  s = s + "    v_radii = a_radii;\n"
  s = s + "    v_clip_rect = a_clip_rect;\n"
  s = s + "    v_border_width = a_border_width;\n"
  s = s + "    v_flags = a_flags;\n"
  s = s + "    v_size = a_rect.zw;\n"
  s = s + "}\n"
  return s
@end

@fn webgl2_generate_frag_shader()
  s = "#version 300 es\n"
  s = s + "precision highp float;\n"
  s = s + "in vec2 v_uv;\n"
  s = s + "in vec2 v_local_pos;\n"
  s = s + "in vec2 v_screen_pos;\n"
  s = s + "flat in vec4 v_bg_color;\n"
  s = s + "flat in vec4 v_border_color;\n"
  s = s + "flat in vec4 v_radii;\n"
  s = s + "flat in vec4 v_clip_rect;\n"
  s = s + "flat in float v_border_width;\n"
  s = s + "flat in uint v_flags;\n"
  s = s + "flat in vec2 v_size;\n"
  s = s + "out vec4 fragColor;\n"
  s = s + "float sdf_box(vec2 p, vec2 b, float r) {\n"
  s = s + "    vec2 q = abs(p - b * 0.5) - (b * 0.5 - vec2(r));\n"
  s = s + "    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;\n"
  s = s + "}\n"
  s = s + "void main() {\n"
  s = s + "    if (v_screen_pos.x < v_clip_rect.x || v_screen_pos.x > v_clip_rect.z ||\n"
  s = s + "        v_screen_pos.y < v_clip_rect.y || v_screen_pos.y > v_clip_rect.w) {\n"
  s = s + "        discard;\n"
  s = s + "    }\n"
  s = s + "    float r = v_radii.x;\n"
  s = s + "    float d = sdf_box(v_local_pos, v_size, r);\n"
  s = s + "    float aa = fwidth(d);\n"
  s = s + "    float alpha = clamp(0.5 - (d / max(aa, 0.5)), 0.0, 1.0);\n"
  s = s + "    if (alpha <= 0.0) discard;\n"
  s = s + "    vec4 col = v_bg_color;\n"
  s = s + "    if (v_border_width > 0.0 && (v_flags & 2u) != 0u) {\n"
  s = s + "        float inner_d = d + v_border_width;\n"
  s = s + "        float border_a = clamp(0.5 - (inner_d / max(aa, 0.5)), 0.0, 1.0);\n"
  s = s + "        col = mix(v_border_color, col, border_a);\n"
  s = s + "    }\n"
  s = s + "    fragColor = col * vec4(1.0, 1.0, 1.0, alpha);\n"
  s = s + "}\n"
  return s
@end

@! ----------------------------------------------------------------------------
@! 4. CONSTRUCTOR & INITIALIZATION
@! ----------------------------------------------------------------------------

@fn webgl2_renderer_new(width, height, scale_factor)
  @if width <= 0 width = 1 @end
  @if height <= 0 height = 1 @end
  @if scale_factor <= 0.0 scale_factor = 1.0 @end
  
  init_clip = [0.0, 0.0, width * 1.0, height * 1.0]
  
  dummy_prog = {
    program_id: 0,
    name: "",
    vert_src: "",
    frag_src: "",
    attributes: [],
    is_linked: false
  }
  
  dummy_vbo1 = { buffer_id: 0, target: "ARRAY_BUFFER", data_size: 0, usage: "STATIC_DRAW", records: [] }
  dummy_vbo2 = { buffer_id: 0, target: "ARRAY_BUFFER", data_size: 0, usage: "DYNAMIC_DRAW", records: [] }
  
  dummy_vao = {
    vao_id: 0,
    quad_vbo: dummy_vbo1,
    instance_vbo: dummy_vbo2,
    attributes: [],
    is_bound: false
  }
  
  renderer = {
    gl_context_id: 1,
    gl_width: width,
    gl_height: height,
    gl_scale_factor: scale_factor,
    gl_is_ready: true,
    gl_is_context_lost: false,
    gl_clear_color: 0xFF000000,
    gl_clip_stack: [],
    gl_current_clip: init_clip,
    gl_instances: [],
    gl_commands: [],
    gl_draw_call_count: 0,
    gl_total_quads: 0,
    gl_ubo_data: [],
    gl_programs: [],
    gl_active_program: dummy_prog,
    gl_vao: dummy_vao
  }
  
  renderer = webgl2_renderer_init_shaders(renderer)
  return renderer
@end

@fn webgl2_renderer_init_shaders(renderer)
  vert_code = webgl2_generate_vert_shader()
  frag_code = webgl2_generate_frag_shader()
  
  attrs = [
    { location: 0, name: "a_quad_pos", size: 2, attr_type: "FLOAT", normalized: false, stride: 8, offset: 0, divisor: 0 },
    { location: 1, name: "a_rect", size: 4, attr_type: "FLOAT", normalized: false, stride: 96, offset: 0, divisor: 1 },
    { location: 2, name: "a_bg_color", size: 4, attr_type: "FLOAT", normalized: false, stride: 96, offset: 16, divisor: 1 },
    { location: 3, name: "a_border_color", size: 4, attr_type: "FLOAT", normalized: false, stride: 96, offset: 32, divisor: 1 },
    { location: 4, name: "a_radii", size: 4, attr_type: "FLOAT", normalized: false, stride: 96, offset: 48, divisor: 1 },
    { location: 5, name: "a_clip_rect", size: 4, attr_type: "FLOAT", normalized: false, stride: 96, offset: 64, divisor: 1 },
    { location: 6, name: "a_border_width", size: 1, attr_type: "FLOAT", normalized: false, stride: 96, offset: 80, divisor: 1 },
    { location: 7, name: "a_flags", size: 1, attr_type: "UNSIGNED_INT", normalized: false, stride: 96, offset: 84, divisor: 1 }
  ]
  
  prog = {
    program_id: 101,
    name: "ui_instanced_program",
    vert_src: vert_code,
    frag_src: frag_code,
    attributes: attrs,
    is_linked: true
  }
  
  renderer.gl_programs = [prog]
  renderer.gl_active_program = prog
  
  quad_vbo = {
    buffer_id: 201,
    target: "ARRAY_BUFFER",
    data_size: 48,
    usage: "STATIC_DRAW",
    records: [0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 1.0]
  }
  
  inst_vbo = {
    buffer_id: 202,
    target: "ARRAY_BUFFER",
    data_size: 0,
    usage: "DYNAMIC_DRAW",
    records: []
  }
  
  renderer.gl_vao = {
    vao_id: 301,
    quad_vbo: quad_vbo,
    instance_vbo: inst_vbo,
    attributes: attrs,
    is_bound: true
  }
  
  return renderer
@end

@! ----------------------------------------------------------------------------
@! 5. FRAME LIFECYCLE & DRAWING EMITTERS
@! ----------------------------------------------------------------------------

@fn webgl2_renderer_begin_frame(renderer, clear_color)
  renderer.gl_instances = []
  renderer.gl_commands = []
  renderer.gl_clear_color = clear_color
  renderer.gl_clip_stack = []
  renderer.gl_current_clip = [0.0, 0.0, renderer.gl_width * 1.0, renderer.gl_height * 1.0]
  
  clear_rgba = webgl2_unpack_color(clear_color)
  clear_cmd = {
    type: "GL_CLEAR",
    r: clear_rgba[0],
    g: clear_rgba[1],
    b: clear_rgba[2],
    a: clear_rgba[3],
    bits: "COLOR_BUFFER_BIT"
  }
  renderer.gl_commands = renderer.gl_commands.push(clear_cmd)
  return renderer
@end

@fn webgl2_renderer_push_clip(renderer, x, y, w, h)
  cur = renderer.gl_current_clip
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
  
  renderer.gl_clip_stack = renderer.gl_clip_stack.push(cur)
  renderer.gl_current_clip = [new_min_x, new_min_y, new_max_x, new_max_y]
  
  scissor_cmd = {
    type: "GL_SCISSOR",
    x: new_min_x,
    y: renderer.gl_height * 1.0 - new_max_y,
    width: new_max_x - new_min_x,
    height: new_max_y - new_min_y
  }
  renderer.gl_commands = renderer.gl_commands.push(scissor_cmd)
  return renderer
@end

@fn webgl2_renderer_pop_clip(renderer)
  stack_len = renderer.gl_clip_stack.len()
  @if stack_len > 0
    top_idx = stack_len - 1
    renderer.gl_current_clip = renderer.gl_clip_stack[top_idx]
    
    new_stack = []
    i = 0
    @while i < top_idx
      new_stack = new_stack.push(renderer.gl_clip_stack[i])
      i = i + 1
    @end
    renderer.gl_clip_stack = new_stack
  @else
    renderer.gl_current_clip = [0.0, 0.0, renderer.gl_width * 1.0, renderer.gl_height * 1.0]
  @end
  
  cur = renderer.gl_current_clip
  scissor_cmd = {
    type: "GL_SCISSOR",
    x: cur[0],
    y: renderer.gl_height * 1.0 - cur[3],
    width: cur[2] - cur[0],
    height: cur[3] - cur[1]
  }
  renderer.gl_commands = renderer.gl_commands.push(scissor_cmd)
  return renderer
@end

@fn webgl2_renderer_draw_rect(renderer, x, y, w, h, bg_col, border_col, border_w, radius)
  @if w <= 0 || h <= 0 return renderer @end
  
  bg_rgba = webgl2_unpack_color(bg_col)
  b_rgba = webgl2_unpack_color(border_col)
  clip = renderer.gl_current_clip
  
  flags = 0
  @if radius > 0 flags = flags | 1 @end
  @if border_w > 0 flags = flags | 2 @end
  
  inst = {
    rect: [x * 1.0, y * 1.0, w * 1.0, h * 1.0],
    bg_color: bg_rgba,
    border_color: b_rgba,
    radii: [radius * 1.0, radius * 1.0, radius * 1.0, radius * 1.0],
    clip_rect: clip,
    border_width: border_w * 1.0,
    flags: flags
  }
  
  renderer.gl_instances = renderer.gl_instances.push(inst)
  renderer.gl_total_quads = renderer.gl_total_quads + 1
  return renderer
@end

@fn webgl2_renderer_draw_text(renderer, text, x, y, font_size, color)
  @if text == "" || font_size <= 0 return renderer @end
  
  c_rgba = webgl2_unpack_color(color)
  clip = renderer.gl_current_clip
  text_w = text.len() * font_size * 0.6
  text_h = font_size * 1.2
  
  inst = {
    rect: [x * 1.0, y * 1.0, text_w, text_h],
    bg_color: c_rgba,
    border_color: [0.0, 0.0, 0.0, 0.0],
    radii: [0.0, 0.0, 0.0, 0.0],
    clip_rect: clip,
    border_width: 0.0,
    flags: 8
  }
  
  renderer.gl_instances = renderer.gl_instances.push(inst)
  renderer.gl_total_quads = renderer.gl_total_quads + 1
  return renderer
@end

@fn webgl2_renderer_draw_image(renderer, texture_id, sx, sy, sw, sh, dx, dy, dw, dh, opacity)
  @if dw <= 0 || dh <= 0 return renderer @end
  
  clip = renderer.gl_current_clip
  @if opacity <= 0.0 opacity = 1.0 @end
  
  inst = {
    rect: [dx * 1.0, dy * 1.0, dw * 1.0, dh * 1.0],
    bg_color: [1.0, 1.0, 1.0, opacity],
    border_color: [0.0, 0.0, 0.0, 0.0],
    radii: [0.0, 0.0, 0.0, 0.0],
    clip_rect: clip,
    border_width: 0.0,
    flags: 16
  }
  
  renderer.gl_instances = renderer.gl_instances.push(inst)
  renderer.gl_total_quads = renderer.gl_total_quads + 1
  return renderer
@end

@! ----------------------------------------------------------------------------
@! 6. WEBGL2 COMMAND BUFFER EMISSION & EXECUTION
@! ----------------------------------------------------------------------------

@fn webgl2_renderer_emit_gl_commands(renderer)
  inst_count = renderer.gl_instances.len()
  @if inst_count == 0 return renderer @end
  
  @! Upload Instance VBO
  upload_cmd = {
    type: "GL_BUFFER_SUB_DATA",
    target: "ARRAY_BUFFER",
    offset: 0,
    size: inst_count * 96,
    instance_count: inst_count
  }
  renderer.gl_commands = renderer.gl_commands.push(upload_cmd)
  
  @! Bind VAO
  bind_vao_cmd = {
    type: "GL_BIND_VERTEX_ARRAY",
    vao_id: renderer.gl_vao.vao_id
  }
  renderer.gl_commands = renderer.gl_commands.push(bind_vao_cmd)
  
  @! Instanced Draw Call
  draw_cmd = {
    type: "GL_DRAW_ARRAYS_INSTANCED",
    mode: "TRIANGLES",
    first: 0,
    count: 6,
    instance_count: inst_count
  }
  renderer.gl_commands = renderer.gl_commands.push(draw_cmd)
  renderer.gl_draw_call_count = renderer.gl_draw_call_count + 1
  return renderer
@end

@fn webgl2_renderer_end_frame(renderer)
  @if renderer.gl_is_context_lost
    return renderer
  @end
  
  renderer = webgl2_renderer_emit_gl_commands(renderer)
  return renderer
@end

@fn webgl2_renderer_simulate_context_loss(renderer)
  renderer.gl_is_context_lost = true
  renderer.gl_is_ready = false
  return renderer
@end
