// ============================================================================
// MAYA WEB FRONTEND ENGINE — WGSL UI COMPUTE LAYOUT SHADER
// File: universe/web/frontend/renderer/shaders/ui_layout.wgsl
// 100% Pure WGSL Compute Pipeline for GPU-Accelerated Flexbox & Grid Layout
// ============================================================================

struct LayoutUniforms {
    node_count: u32,
    viewport_width: f32,
    viewport_height: f32,
    scale_factor: f32,
};

// Layout types: 0 = ABSOLUTE, 1 = ROW, 2 = COLUMN, 3 = GRID
// Alignment: 0 = START, 1 = CENTER, 2 = END, 3 = STRETCH
// Justify: 0 = START, 1 = CENTER, 2 = END, 3 = SPACE_BETWEEN, 4 = SPACE_AROUND, 5 = SPACE_EVENLY

struct GpuLayoutNodeData {
    node_id: u32,
    parent_idx: u32,
    first_child_idx: u32,
    next_sibling_idx: u32,
    child_count: u32,
    layout_type: u32,
    align_items: u32,
    justify_content: u32,
    flex_grow: f32,
    flex_shrink: f32,
    min_width: f32,
    min_height: f32,
    pref_width: f32,
    pref_height: f32,
    padding: vec4<f32>,     // top, right, bottom, left
    margin: vec4<f32>,      // top, right, bottom, left
    gap: f32,
    computed_x: f32,
    computed_y: f32,
    computed_w: f32,
    computed_h: f32,
    is_dirty: u32,
    clip_id: u32,
};

struct DirtyBoundsResult {
    min_x: f32,
    min_y: f32,
    max_x: f32,
    max_y: f32,
    has_dirty: u32,
    pad0: u32,
    pad1: u32,
    pad2: u32,
};

@group(0) @binding(0) var<uniform> uniforms: LayoutUniforms;
@group(0) @binding(1) var<storage, read_write> nodes: array<GpuLayoutNodeData>;
@group(0) @binding(2) var<storage, read_write> dirty_output: DirtyBoundsResult;

// PASS 1: Intrinsic Measurement & Content Bounds
@compute @workgroup_size(64)
fn cs_measure(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let idx = global_id.x;
    if (idx >= uniforms.node_count) {
        return;
    }
    
    var node = nodes[idx];
    
    // Leaf node intrinsic evaluation
    if (node.child_count == 0u) {
        var base_w = node.pref_width;
        var base_h = node.pref_height;
        if (base_w < node.min_width) { base_w = node.min_width; }
        if (base_h < node.min_height) { base_h = node.min_height; }
        
        node.computed_w = base_w + node.padding.y + node.padding.w;
        node.computed_h = base_h + node.padding.x + node.padding.z;
        nodes[idx] = node;
    }
}

// PASS 2: Flex Space Distribution & Coordinate Assignment
@compute @workgroup_size(64)
fn cs_layout(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let idx = global_id.x;
    if (idx >= uniforms.node_count) {
        return;
    }
    
    var node = nodes[idx];
    
    // Root container initializes from viewport if dimensions not explicit
    if (node.parent_idx == 0xFFFFFFFFu || node.parent_idx == idx) {
        node.computed_x = node.margin.w;
        node.computed_y = node.margin.x;
        if (node.pref_width <= 0.0) {
            node.computed_w = uniforms.viewport_width - (node.margin.y + node.margin.w);
        } else {
            node.computed_w = node.pref_width;
        }
        if (node.pref_height <= 0.0) {
            node.computed_h = uniforms.viewport_height - (node.margin.x + node.margin.z);
        } else {
            node.computed_h = node.pref_height;
        }
        nodes[idx] = node;
        return;
    }
    
    // Child nodes inherit bounds and offsets computed by container walk
    let parent = nodes[node.parent_idx];
    let content_x = parent.computed_x + parent.padding.w;
    let content_y = parent.computed_y + parent.padding.x;
    let avail_w = max(0.0, parent.computed_w - (parent.padding.y + parent.padding.w));
    let avail_h = max(0.0, parent.computed_h - (parent.padding.x + parent.padding.z));
    
    if (parent.layout_type == 0u) {
        // Absolute positioning
        node.computed_x = content_x + node.margin.w;
        node.computed_y = content_y + node.margin.x;
        node.computed_w = min(avail_w, node.pref_width);
        node.computed_h = min(avail_h, node.pref_height);
    } else if (parent.layout_type == 1u) {
        // ROW layout
        let share_w = (avail_w - (f32(max(1u, parent.child_count) - 1u) * parent.gap)) / f32(max(1u, parent.child_count));
        var child_w = share_w;
        if (node.pref_width > 0.0 && node.flex_grow <= 0.0) {
            child_w = node.pref_width;
        }
        node.computed_w = child_w;
        
        if (parent.align_items == 3u) {
            // STRETCH
            node.computed_h = avail_h - (node.margin.x + node.margin.z);
            node.computed_y = content_y + node.margin.x;
        } else if (parent.align_items == 1u) {
            // CENTER
            node.computed_h = min(avail_h, node.pref_height);
            node.computed_y = content_y + (avail_h - node.computed_h) * 0.5;
        } else {
            node.computed_h = min(avail_h, node.pref_height);
            node.computed_y = content_y + node.margin.x;
        }
    } else if (parent.layout_type == 2u) {
        // COLUMN layout
        let share_h = (avail_h - (f32(max(1u, parent.child_count) - 1u) * parent.gap)) / f32(max(1u, parent.child_count));
        var child_h = share_h;
        if (node.pref_height > 0.0 && node.flex_grow <= 0.0) {
            child_h = node.pref_height;
        }
        node.computed_h = child_h;
        
        if (parent.align_items == 3u) {
            // STRETCH
            node.computed_w = avail_w - (node.margin.y + node.margin.w);
            node.computed_x = content_x + node.margin.w;
        } else if (parent.align_items == 1u) {
            // CENTER
            node.computed_w = min(avail_w, node.pref_width);
            node.computed_x = content_x + (avail_w - node.computed_w) * 0.5;
        } else {
            node.computed_w = min(avail_w, node.pref_width);
            node.computed_x = content_x + node.margin.w;
        }
    }
    
    nodes[idx] = node;
}

// PASS 3: Dirty Subtree & Bounding Box Aggregation
@compute @workgroup_size(64)
fn cs_dirty_bounds(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let idx = global_id.x;
    if (idx >= uniforms.node_count) {
        return;
    }
    
    let node = nodes[idx];
    if (node.is_dirty != 0u) {
        let rx1 = node.computed_x;
        let ry1 = node.computed_y;
        let rx2 = node.computed_x + node.computed_w;
        let ry2 = node.computed_y + node.computed_h;
        
        // Atomic or workgroup reduce simulation
        if (dirty_output.has_dirty == 0u) {
            dirty_output.min_x = rx1;
            dirty_output.min_y = ry1;
            dirty_output.max_x = rx2;
            dirty_output.max_y = ry2;
            dirty_output.has_dirty = 1u;
        } else {
            dirty_output.min_x = min(dirty_output.min_x, rx1);
            dirty_output.min_y = min(dirty_output.min_y, ry1);
            dirty_output.max_x = max(dirty_output.max_x, rx2);
            dirty_output.max_y = max(dirty_output.max_y, ry2);
        }
    }
}
