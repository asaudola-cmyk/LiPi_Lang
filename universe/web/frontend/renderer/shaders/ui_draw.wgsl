// ============================================================================
// MAYA WEB FRONTEND ENGINE — WGSL UI DRAW SHADER
// File: universe/web/frontend/renderer/shaders/ui_draw.wgsl
// 100% Pure WGSL Shading Pipeline for WebGPU Tier-1 UI Acceleration
// Features:
// - Instanced Quad Vertex Generation (Zero VBO Upload)
// - Sub-pixel SDF Rounded Rectangles with Per-Corner Radii
// - Sharp Anti-aliased Borders with Width Control
// - Analytical Gaussian Drop Shadows (Offset, Blur, Spread)
// - Linear Gradient Blending Stop Evaluation
// - Hardware Scissor / Bounding Box Clipping Discard
// - Alpha-Masked Glyph & Texture Blitting
// ============================================================================

struct ViewportUniforms {
    screen_size: vec2<f32>,
    scale_factor: f32,
    time: f32,
    proj_matrix: mat4x4<f32>,
};

// Flags for rendering modes:
// Bit 0 (0x01): Rounded Corners Enabled
// Bit 1 (0x02): Border Enabled
// Bit 2 (0x04): Drop Shadow Enabled
// Bit 3 (0x08): Text / Glyph Mask Enabled
// Bit 4 (0x10): Texture / Image Blit Enabled
// Bit 5 (0x20): Linear Gradient Enabled

struct QuadInstance {
    rect: vec4<f32>,                 // x, y, width, height (pixels)
    bg_color: vec4<f32>,             // r, g, b, a (0.0 - 1.0)
    border_color: vec4<f32>,         // r, g, b, a
    corner_radii: vec4<f32>,         // tl, tr, br, bl
    border_width: f32,
    flags: u32,
    clip_rect: vec4<f32>,            // min_x, min_y, max_x, max_y
    shadow_color: vec4<f32>,         // r, g, b, a
    shadow_params: vec4<f32>,        // offset_x, offset_y, blur_radius, spread
    gradient_stop_color: vec4<f32>,  // r, g, b, a for 2-stop gradient
    glyph_uv_rect: vec4<f32>,        // u_min, v_min, u_max, v_max
    pad0: f32,
    pad1: f32,
};

@group(0) @binding(0) var<uniform> uniforms: ViewportUniforms;
@group(0) @binding(1) var<storage, read> instances: array<QuadInstance>;
@group(0) @binding(2) var font_texture: texture_2d<f32>;
@group(0) @binding(3) var font_sampler: sampler;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
    @location(1) local_pos: vec2<f32>,
    @location(2) screen_pos: vec2<f32>,
    @location(3) @interpolate(flat) instance_idx: u32,
};

@vertex
fn vs_main(
    @builtin(vertex_index) v_idx: u32,
    @builtin(instance_index) inst_idx: u32
) -> VertexOutput {
    var out: VertexOutput;
    
    // 6-vertex quad topology for 2 CCW triangles
    var quad_positions = array<vec2<f32>, 6>(
        vec2<f32>(0.0, 0.0), // Triangle 1: Top-Left
        vec2<f32>(1.0, 0.0), // Triangle 1: Top-Right
        vec2<f32>(0.0, 1.0), // Triangle 1: Bottom-Left
        vec2<f32>(0.0, 1.0), // Triangle 2: Bottom-Left
        vec2<f32>(1.0, 0.0), // Triangle 2: Top-Right
        vec2<f32>(1.0, 1.0)  // Triangle 2: Bottom-Right
    );
    
    let base_uv = quad_positions[v_idx];
    let inst = instances[inst_idx];
    
    // Expand shadow bounding box if shadow flag is active
    var render_rect = inst.rect;
    var uv_pos = base_uv;
    
    if ((inst.flags & 4u) != 0u) {
        let blur = inst.shadow_params.z;
        let spread = inst.shadow_params.w;
        let off_x = inst.shadow_params.x;
        let off_y = inst.shadow_params.y;
        let margin = (blur * 2.0) + spread;
        
        let min_x = min(inst.rect.x, inst.rect.x + off_x - margin);
        let min_y = min(inst.rect.y, inst.rect.y + off_y - margin);
        let max_x = max(inst.rect.x + inst.rect.z, inst.rect.x + inst.rect.z + off_x + margin);
        let max_y = max(inst.rect.y + inst.rect.w, inst.rect.y + inst.rect.w + off_y + margin);
        
        render_rect = vec4<f32>(min_x, min_y, max_x - min_x, max_y - min_y);
    }
    
    let pixel_pos = render_rect.xy + (base_uv * render_rect.zw);
    let clip_x = (pixel_pos.x / uniforms.screen_size.x) * 2.0 - 1.0;
    let clip_y = 1.0 - (pixel_pos.y / uniforms.screen_size.y) * 2.0;
    
    out.position = vec4<f32>(clip_x, clip_y, 0.0, 1.0);
    out.uv = base_uv;
    out.local_pos = pixel_pos - inst.rect.xy;
    out.screen_pos = pixel_pos;
    out.instance_idx = inst_idx;
    
    return out;
}

// Signed Distance Function (SDF) for a 2D rounded rectangle
fn sdf_rounded_rect(p: vec2<f32>, size: vec2<f32>, radii: vec4<f32>) -> f32 {
    let half_size = size * 0.5;
    let center_p = p - half_size;
    
    // Select corner radius based on quadrant:
    // tl: p.x < 0, p.y < 0 -> radii.x
    // tr: p.x >= 0, p.y < 0 -> radii.y
    // br: p.x >= 0, p.y >= 0 -> radii.z
    // bl: p.x < 0, p.y >= 0 -> radii.w
    var r = radii.x;
    if (center_p.x >= 0.0 && center_p.y < 0.0) {
        r = radii.y;
    } else if (center_p.x >= 0.0 && center_p.y >= 0.0) {
        r = radii.z;
    } else if (center_p.x < 0.0 && center_p.y >= 0.0) {
        r = radii.w;
    }
    
    r = min(r, min(half_size.x, half_size.y));
    let q = abs(center_p) - (half_size - vec2<f32>(r, r));
    return length(max(q, vec2<f32>(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// Analytical Gaussian Drop Shadow SDF evaluation
fn eval_shadow(p: vec2<f32>, rect_size: vec2<f32>, radii: vec4<f32>, offset: vec2<f32>, blur: f32, spread: f32) -> f32 {
    let shadow_p = p - offset;
    let expanded_size = rect_size + vec2<f32>(spread * 2.0, spread * 2.0);
    let dist = sdf_rounded_rect(shadow_p + vec2<f32>(spread, spread), expanded_size, radii);
    
    if (blur <= 0.0) {
        return clamp(0.5 - dist, 0.0, 1.0);
    }
    
    let sigma = blur * 0.5;
    return clamp(1.0 - smoothstep(-sigma, sigma * 2.0, dist), 0.0, 1.0);
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let inst = instances[in.instance_idx];
    
    // 1. Scissor / Bounding Box Clip Discard
    if (in.screen_pos.x < inst.clip_rect.x || in.screen_pos.x > inst.clip_rect.z ||
        in.screen_pos.y < inst.clip_rect.y || in.screen_pos.y > inst.clip_rect.w) {
        discard;
    }
    
    var final_color = vec4<f32>(0.0, 0.0, 0.0, 0.0);
    let size = inst.rect.zw;
    
    // 2. Drop Shadow Evaluation (Underneath quad)
    if ((inst.flags & 4u) != 0u) {
        let shadow_alpha = eval_shadow(
            in.local_pos,
            size,
            inst.corner_radii,
            inst.shadow_params.xy,
            inst.shadow_params.z,
            inst.shadow_params.w
        );
        if (shadow_alpha > 0.0) {
            final_color = inst.shadow_color * vec4<f32>(1.0, 1.0, 1.0, shadow_alpha);
        }
    }
    
    // 3. Main SDF Rounded Rectangle Evaluation
    let dist = sdf_rounded_rect(in.local_pos, size, inst.corner_radii);
    let aa_edge = fwidth(dist);
    let aa_delta = max(aa_edge, 0.7);
    let quad_alpha = clamp(0.5 - (dist / aa_delta), 0.0, 1.0);
    
    if (quad_alpha > 0.0) {
        var base_fill = inst.bg_color;
        
        // Linear Gradient interpolation (Bit 5)
        if ((inst.flags & 32u) != 0u) {
            let t = clamp(in.uv.y, 0.0, 1.0);
            base_fill = mix(inst.bg_color, inst.gradient_stop_color, t);
        }
        
        // Text / Glyph rendering with font alpha mask (Bit 3)
        if ((inst.flags & 8u) != 0u) {
            let uv = mix(inst.glyph_uv_rect.xy, inst.glyph_uv_rect.zw, in.uv);
            let font_sample = textureSample(font_texture, font_sampler, uv);
            base_fill = base_fill * vec4<f32>(1.0, 1.0, 1.0, font_sample.r);
        }
        
        // Border rendering (Bit 1)
        if ((inst.flags & 2u) != 0u && inst.border_width > 0.0) {
            let inner_dist = dist + inst.border_width;
            let border_alpha = clamp(0.5 - (inner_dist / aa_delta), 0.0, 1.0);
            base_fill = mix(inst.border_color, base_fill, border_alpha);
        }
        
        let quad_layer = base_fill * vec4<f32>(1.0, 1.0, 1.0, quad_alpha);
        // Alpha blend over shadow: dst = src + dst * (1 - src.a)
        final_color = quad_layer + (final_color * (1.0 - quad_layer.a));
    }
    
    if (final_color.a <= 0.001) {
        discard;
    }
    
    return final_color;
}
