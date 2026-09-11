@! ============================================================================
@! MAYA WEB FRONTEND ENGINE — GPU COMPUTE LAYOUT ENGINE
@! Module: universe/web/frontend/layout/gpu_layout.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! Features:
@! - Flattens hierarchical widget trees into linear GPU storage buffers
@! - WGSL Compute Pipeline simulation (Pass 1: Measure, Pass 2: Layout, Pass 3: Dirty Bounds)
@! - Reading back bounding boxes (LayoutResult list for renderer draw calls)
@! - Incremental dirty rect caching and union bounds calculation
@! - Seamless GPU / CPU Flexbox fallback and parity validation
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/web/frontend/layout/layout_types"
import "universe/web/frontend/layout/flexbox_solver"

@! ============================================================================
@! 1. WGSL COMPUTE SHADER SOURCE CODE EMBEDDING
@! ============================================================================

@fn gpu_layout_get_wgsl_shader_source()
  s = "// MAYA WEB FRONTEND ENGINE — WGSL UI COMPUTE LAYOUT SHADER\n"
  s = s + "struct {\n"
  s = s + "    node_count: u32,\n"
  s = s + "    viewport_width: f32,\n"
  s = s + "    viewport_height: f32,\n"
  s = s + "    scale_factor: f32,\n"
  s = s + "};\n"
  s = s + "struct {\n"
  s = s + "    node_id: u32,\n"
  s = s + "    parent_idx: u32,\n"
  s = s + "    first_child_idx: u32,\n"
  s = s + "    next_sibling_idx: u32,\n"
  s = s + "    child_count: u32,\n"
  s = s + "    layout_type: u32,\n"
  s = s + "    align_items: u32,\n"
  s = s + "    justify_content: u32,\n"
  s = s + "    flex_grow: f32,\n"
  s = s + "    flex_shrink: f32,\n"
  s = s + "    min_width: f32,\n"
  s = s + "    min_height: f32,\n"
  s = s + "    pref_width: f32,\n"
  s = s + "    pref_height: f32,\n"
  s = s + "    padding: vec4<f32>,\n"
  s = s + "    margin: vec4<f32>,\n"
  s = s + "    gap: f32,\n"
  s = s + "    computed_x: f32,\n"
  s = s + "    computed_y: f32,\n"
  s = s + "    computed_w: f32,\n"
  s = s + "    computed_h: f32,\n"
  s = s + "    is_dirty: u32,\n"
  s = s + "    clip_id: u32,\n"
  s = s + "};\n"
  s = s + "struct {\n"
  s = s + "    min_x: f32,\n"
  s = s + "    min_y: f32,\n"
  s = s + "    max_x: f32,\n"
  s = s + "    max_y: f32,\n"
  s = s + "    has_dirty: u32,\n"
  s = s + "};\n"
  s = s + "@group(0) @binding(0) var<uniform> uniforms: LayoutUniforms;\n"
  s = s + "@group(0) @binding(1) var<storage, read_write> nodes: array<GpuLayoutNodeData>;\n"
  s = s + "@group(0) @binding(2) var<storage, read_write> dirty_output: DirtyBoundsResult;\n"
  s = s + "@compute @workgroup_size(64)\n"
  s = s + "fn cs_measure(@builtin(global_invocation_id) global_id: vec3<u32>) {\n"
  s = s + "    let idx = global_id.x;\n"
  s = s + "    if (idx >= uniforms.node_count) { return; }\n"
  s = s + "    var node = nodes[idx];\n"
  s = s + "    if (node.child_count == 0u) {\n"
  s = s + "        var base_w = node.pref_width;\n"
  s = s + "        var base_h = node.pref_height;\n"
  s = s + "        if (base_w < node.min_width) { base_w = node.min_width; }\n"
  s = s + "        if (base_h < node.min_height) { base_h = node.min_height; }\n"
  s = s + "        node.computed_w = base_w + node.padding.y + node.padding.w;\n"
  s = s + "        node.computed_h = base_h + node.padding.x + node.padding.z;\n"
  s = s + "        nodes[idx] = node;\n"
  s = s + "    }\n"
  s = s + "}\n"
  s = s + "@compute @workgroup_size(64)\n"
  s = s + "fn cs_layout(@builtin(global_invocation_id) global_id: vec3<u32>) {\n"
  s = s + "    let idx = global_id.x;\n"
  s = s + "    if (idx >= uniforms.node_count) { return; }\n"
  s = s + "    var node = nodes[idx];\n"
  s = s + "    if (node.parent_idx == 0xFFFFFFFFu || node.parent_idx == idx) {\n"
  s = s + "        node.computed_x = node.margin.w;\n"
  s = s + "        node.computed_y = node.margin.x;\n"
  s = s + "        if (node.pref_width <= 0.0) { node.computed_w = uniforms.viewport_width - (node.margin.y + node.margin.w); } else { node.computed_w = node.pref_width; }\n"
  s = s + "        if (node.pref_height <= 0.0) { node.computed_h = uniforms.viewport_height - (node.margin.x + node.margin.z); } else { node.computed_h = node.pref_height; }\n"
  s = s + "        nodes[idx] = node;\n"
  s = s + "        return;\n"
  s = s + "    }\n"
  s = s + "    let parent = nodes[node.parent_idx];\n"
  s = s + "    let content_x = parent.computed_x + parent.padding.w;\n"
  s = s + "    let content_y = parent.computed_y + parent.padding.x;\n"
  s = s + "    let avail_w = max(0.0, parent.computed_w - (parent.padding.y + parent.padding.w));\n"
  s = s + "    let avail_h = max(0.0, parent.computed_h - (parent.padding.x + parent.padding.z));\n"
  s = s + "    if (parent.layout_type == 1u) {\n"
  s = s + "        let share_w = (avail_w - (f32(max(1u, parent.child_count) - 1u) * parent.gap)) / f32(max(1u, parent.child_count));\n"
  s = s + "        var child_w = share_w;\n"
  s = s + "        if (node.pref_width > 0.0 && node.flex_grow <= 0.0) { child_w = node.pref_width; }\n"
  s = s + "        node.computed_w = child_w;\n"
  s = s + "        if (parent.align_items == 3u) {\n"
  s = s + "            node.computed_h = avail_h - (node.margin.x + node.margin.z);\n"
  s = s + "            node.computed_y = content_y + node.margin.x;\n"
  s = s + "        } else if (parent.align_items == 1u) {\n"
  s = s + "            node.computed_h = min(avail_h, node.pref_height);\n"
  s = s + "            node.computed_y = content_y + (avail_h - node.computed_h) * 0.5;\n"
  s = s + "        } else {\n"
  s = s + "            node.computed_h = min(avail_h, node.pref_height);\n"
  s = s + "            node.computed_y = content_y + node.margin.x;\n"
  s = s + "        }\n"
  s = s + "    }\n"
  s = s + "    nodes[idx] = node;\n"
  s = s + "}\n"
  s = s + "@compute @workgroup_size(64)\n"
  s = s + "fn cs_dirty_bounds(@builtin(global_invocation_id) global_id: vec3<u32>) {\n"
  s = s + "    let idx = global_id.x;\n"
  s = s + "    if (idx >= uniforms.node_count) { return; }\n"
  s = s + "    let node = nodes[idx];\n"
  s = s + "    if (node.is_dirty != 0u) {\n"
  s = s + "        let rx1 = node.computed_x;\n"
  s = s + "        let ry1 = node.computed_y;\n"
  s = s + "        let rx2 = node.computed_x + node.computed_w;\n"
  s = s + "        let ry2 = node.computed_y + node.computed_h;\n"
  s = s + "        if (dirty_output.has_dirty == 0u) {\n"
  s = s + "            dirty_output.min_x = rx1;\n"
  s = s + "            dirty_output.min_y = ry1;\n"
  s = s + "            dirty_output.max_x = rx2;\n"
  s = s + "            dirty_output.max_y = ry2;\n"
  s = s + "            dirty_output.has_dirty = 1u;\n"
  s = s + "        } else {\n"
  s = s + "            dirty_output.min_x = min(dirty_output.min_x, rx1);\n"
  s = s + "            dirty_output.min_y = min(dirty_output.min_y, ry1);\n"
  s = s + "            dirty_output.max_x = max(dirty_output.max_x, rx2);\n"
  s = s + "            dirty_output.max_y = max(dirty_output.max_y, ry2);\n"
  s = s + "        }\n"
  s = s + "    }\n"
  s = s + "}\n"
  return s
@end

@! ============================================================================
@! 2. GPU LAYOUT ENGINE STRUCTURE
@! ============================================================================

@struct GpuLayoutEngine
  is_gpu_active: bool
  viewport_width: i64
  viewport_height: i64
  scale_factor: f64
  nodes: array
  raw_storage_buffer: array
  dirty_output: DirtyBounds
  cached_results: array
  pass_count: i64
  stats_dispatches: i64
  stats_nodes_processed: i64
  wgsl_shader_source: string
@end

@fn gpu_layout_engine_new(is_gpu_active, viewport_w, viewport_h, scale_factor)
  @if viewport_w <= 0 viewport_w = 800 @end
  @if viewport_h <= 0 viewport_h = 600 @end
  @if scale_factor <= 0.0 scale_factor = 1.0 @end
  
  return {
    is_gpu_active: is_gpu_active,
    viewport_width: viewport_w,
    viewport_height: viewport_h,
    scale_factor: scale_factor,
    nodes: [],
    raw_storage_buffer: [],
    dirty_output: dirty_bounds_empty(),
    cached_results: [],
    pass_count: 0,
    stats_dispatches: 0,
    stats_nodes_processed: 0,
    wgsl_shader_source: gpu_layout_get_wgsl_shader_source()
  }
@end

@fn gpu_layout_set_gpu_active(engine, active_bool)
  engine.is_gpu_active = active_bool
  return engine
@end

@fn gpu_layout_set_viewport(engine, width, height)
  engine.viewport_width = width
  engine.viewport_height = height
  return engine
@end

@! ============================================================================
@! 3. TREE SERIALIZATION & LINEAR STORAGE BUFFER PACKING
@! ============================================================================

@fn gpu_layout_pack_node_recursive(tree_node, parent_idx, depth, linear_array)
  cur_idx = linear_array.len()
  
  gpu_node = gpu_layout_node_new(tree_node.id, tree_node.layout_type, tree_node.align_items, tree_node.justify_content)
  gpu_node.parent_idx = parent_idx
  gpu_node.align_self = tree_node.align_self
  gpu_node.flex_wrap = tree_node.flex_wrap
  gpu_node.position_type = tree_node.position_type
  gpu_node.flex_grow = tree_node.flex_grow
  gpu_node.flex_shrink = tree_node.flex_shrink
  gpu_node.flex_basis = tree_node.flex_basis
  gpu_node.min_width = tree_node.min_width
  gpu_node.min_height = tree_node.min_height
  gpu_node.max_width = tree_node.max_width
  gpu_node.max_height = tree_node.max_height
  gpu_node.pref_width = tree_node.pref_width
  gpu_node.pref_height = tree_node.pref_height
  gpu_node.padding_top = tree_node.padding.top
  gpu_node.padding_right = tree_node.padding.right
  gpu_node.padding_bottom = tree_node.padding.bottom
  gpu_node.padding_left = tree_node.padding.left
  gpu_node.margin_top = tree_node.margin.top
  gpu_node.margin_right = tree_node.margin.right
  gpu_node.margin_bottom = tree_node.margin.bottom
  gpu_node.margin_left = tree_node.margin.left
  gpu_node.gap = tree_node.gap
  gpu_node.row_gap = tree_node.row_gap
  gpu_node.column_gap = tree_node.column_gap
  gpu_node.clip_id = tree_node.clip_id
  gpu_node.depth = depth
  
  is_d = 0
  @if tree_node.node_is_dirty is_d = 1 @end
  gpu_node.gpu_is_dirty = is_d
  
  num_children = tree_node.children.len()
  gpu_node.child_count = num_children
  
  @! Push placeholder for current node
  linear_array = linear_array.push(gpu_node)
  
  @! Recursively pack children
  child_indices = []
  i = 0
  prev_child_idx = -1
  @while i < num_children
    c_node = tree_node.children[i]
    c_idx = linear_array.len()
    child_indices = child_indices.push(c_idx)
    
    @if i == 0
      gpu_node.first_child_idx = c_idx
    @end
    
    @if prev_child_idx >= 0
      prev_node = linear_array[prev_child_idx]
      prev_node.next_sibling_idx = c_idx
      linear_array[prev_child_idx] = prev_node
    @end
    
    prev_child_idx = c_idx
    linear_array = gpu_layout_pack_node_recursive(c_node, cur_idx, depth + 1, linear_array)
    i = i + 1
  @end
  
  gpu_node.children_indices = child_indices
  linear_array[cur_idx] = gpu_node
  
  return linear_array
@end

@fn gpu_layout_pack_tree(root_tree_node)
  return gpu_layout_pack_node_recursive(root_tree_node, -1, 0, [])
@end

@! Packs linear GpuLayoutNode array into raw float array (28 floats per node)
@fn gpu_layout_pack_to_float_buffer(nodes_array)
  buffer = []
  i = 0
  count = nodes_array.len()
  @while i < count
    n = nodes_array[i]
    buffer = buffer.push(n.node_id)
    buffer = buffer.push(n.parent_idx)
    buffer = buffer.push(n.first_child_idx)
    buffer = buffer.push(n.next_sibling_idx)
    buffer = buffer.push(n.child_count)
    buffer = buffer.push(n.layout_type)
    buffer = buffer.push(n.align_items)
    buffer = buffer.push(n.justify_content)
    buffer = buffer.push(n.flex_grow)
    buffer = buffer.push(n.flex_shrink)
    buffer = buffer.push(n.min_width)
    buffer = buffer.push(n.min_height)
    buffer = buffer.push(n.pref_width)
    buffer = buffer.push(n.pref_height)
    buffer = buffer.push(n.padding_top)
    buffer = buffer.push(n.padding_right)
    buffer = buffer.push(n.padding_bottom)
    buffer = buffer.push(n.padding_left)
    buffer = buffer.push(n.margin_top)
    buffer = buffer.push(n.margin_right)
    buffer = buffer.push(n.margin_bottom)
    buffer = buffer.push(n.margin_left)
    buffer = buffer.push(n.gap)
    buffer = buffer.push(n.computed_x)
    buffer = buffer.push(n.computed_y)
    buffer = buffer.push(n.computed_width)
    buffer = buffer.push(n.computed_height)
    buffer = buffer.push(n.gpu_is_dirty)
    i = i + 1
  @end
  return buffer
@end

@! Unpacks linear GpuLayoutNode array back into hierarchical LayoutNode tree
@fn gpu_layout_unpack_node_recursive(linear_nodes, idx)
  @if idx < 0 || idx >= linear_nodes.len()
    return layout_node_new(0, 0, 0, 0)
  @end
  
  gn = linear_nodes[idx]
  tn = layout_node_new(gn.node_id, gn.layout_type, gn.align_items, gn.justify_content)
  tn.align_self = gn.align_self
  tn.flex_wrap = gn.flex_wrap
  tn.position_type = gn.position_type
  tn.flex_grow = gn.flex_grow
  tn.flex_shrink = gn.flex_shrink
  tn.flex_basis = gn.flex_basis
  tn.min_width = gn.min_width
  tn.min_height = gn.min_height
  tn.max_width = gn.max_width
  tn.max_height = gn.max_height
  tn.pref_width = gn.pref_width
  tn.pref_height = gn.pref_height
  tn.padding = edge_insets_ltrb(gn.padding_left, gn.padding_top, gn.padding_right, gn.padding_bottom)
  tn.margin = edge_insets_ltrb(gn.margin_left, gn.margin_top, gn.margin_right, gn.margin_bottom)
  tn.gap = gn.gap
  tn.row_gap = gn.row_gap
  tn.column_gap = gn.column_gap
  tn.node_is_dirty = (gn.gpu_is_dirty != 0)
  tn.clip_id = gn.clip_id
  tn.x = gn.computed_x
  tn.y = gn.computed_y
  tn.width = gn.computed_width
  tn.height = gn.computed_height
  
  c_idx = gn.first_child_idx
  children = []
  @while c_idx >= 0 && c_idx < linear_nodes.len()
    ch_tree = gpu_layout_unpack_node_recursive(linear_nodes, c_idx)
    children = children.push(ch_tree)
    c_idx = linear_nodes[c_idx].next_sibling_idx
  @end
  
  tn.children = children
  return tn
@end

@fn gpu_layout_unpack_tree(linear_nodes)
  @if linear_nodes.len() == 0
    return layout_node_new(0, 0, 0, 0)
  @end
  return gpu_layout_unpack_node_recursive(linear_nodes, 0)
@end

@! ============================================================================
@! 4. WGSL COMPUTE SHADER PASSES EMULATION
@! ============================================================================

@! Pass 1: Intrinsic Measurement (cs_measure)
@fn gpu_layout_pass_measure(engine)
  i = 0
  num = engine.nodes.len()
  @while i < num
    n = engine.nodes[i]
    @if n.child_count == 0
      bw = n.pref_width
      bh = n.pref_height
      @if bw < n.min_width bw = n.min_width @end
      @if bh < n.min_height bh = n.min_height @end
      
      n.computed_width = bw + n.padding_left + n.padding_right
      n.computed_height = bh + n.padding_top + n.padding_bottom
      engine.nodes[i] = n
    @end
    i = i + 1
  @end
  engine.pass_count = engine.pass_count + 1
  return engine
@end

@! Pass 2: Flex Space Distribution & Coordinate Assignment (cs_layout)
@fn gpu_layout_pass_layout(engine)
  i = 0
  num = engine.nodes.len()
  @while i < num
    n = engine.nodes[i]
    
    @! Root container initialization
    @if n.parent_idx == -1 || n.parent_idx == 0xFFFFFFFF || n.parent_idx == i
      n.computed_x = n.margin_left
      n.computed_y = n.margin_top
      @if n.pref_width <= 0
        n.computed_width = engine.viewport_width - (n.margin_left + n.margin_right)
      @else
        n.computed_width = n.pref_width
      @end
      @if n.pref_height <= 0
        n.computed_height = engine.viewport_height - (n.margin_top + n.margin_bottom)
      @else
        n.computed_height = n.pref_height
      @end
      engine.nodes[i] = n
    @else
      @! Child nodes calculation from parent container
      parent = engine.nodes[n.parent_idx]
      content_x = parent.computed_x + parent.padding_left
      content_y = parent.computed_y + parent.padding_top
      avail_w = parent.computed_width - (parent.padding_left + parent.padding_right)
      @if avail_w < 0 avail_w = 0 @end
      avail_h = parent.computed_height - (parent.padding_top + parent.padding_bottom)
      @if avail_h < 0 avail_h = 0 @end
      
      c_count = parent.child_count
      @if c_count < 1 c_count = 1 @end
      
      child_pos = 0
      running_offset_x = 0
      running_offset_y = 0
      gap = parent.gap
      
      c_i = 0
      @while c_i < parent.children_indices.len()
        sib_idx = parent.children_indices[c_i]
        @if sib_idx == i
          child_pos = c_i
          c_i = parent.children_indices.len()
        @else
          sib_node = engine.nodes[sib_idx]
          running_offset_x = running_offset_x + sib_node.computed_width + gap
          running_offset_y = running_offset_y + sib_node.computed_height + gap
          c_i = c_i + 1
        @end
      @end
      
      @if parent.layout_type == LAYOUT_ABSOLUTE()
        n.computed_x = content_x + n.margin_left
        n.computed_y = content_y + n.margin_top
        n.computed_width = n.pref_width
        @if n.computed_width > avail_w && avail_w > 0 n.computed_width = avail_w @end
        n.computed_height = n.pref_height
        @if n.computed_height > avail_h && avail_h > 0 n.computed_height = avail_h @end
      @elif parent.layout_type == LAYOUT_FLEX_ROW()
        total_gaps = (c_count - 1) * gap
        share_w = (avail_w - total_gaps) / c_count
        @if share_w < 0 share_w = 0 @end
        
        child_w = share_w
        @if n.pref_width > 0 && n.flex_grow <= 0
          child_w = n.pref_width
        @end
        n.computed_width = child_w
        
        @if parent.align_items == ALIGN_STRETCH()
          n.computed_height = avail_h - (n.margin_top + n.margin_bottom)
          n.computed_y = content_y + n.margin_top
        @elif parent.align_items == ALIGN_CENTER()
          n.computed_height = n.pref_height
          @if n.computed_height > avail_h n.computed_height = avail_h @end
          n.computed_y = content_y + ((avail_h - n.computed_height) / 2)
        @else
          n.computed_height = n.pref_height
          @if n.computed_height > avail_h n.computed_height = avail_h @end
          n.computed_y = content_y + n.margin_top
        @end
        
        @if n.pref_width > 0 && n.flex_grow <= 0
          n.computed_x = content_x + running_offset_x + n.margin_left
        @else
          n.computed_x = content_x + (child_pos * (share_w + gap)) + n.margin_left
        @end
      @elif parent.layout_type == LAYOUT_FLEX_COLUMN()
        total_gaps = (c_count - 1) * gap
        share_h = (avail_h - total_gaps) / c_count
        @if share_h < 0 share_h = 0 @end
        
        child_h = share_h
        @if n.pref_height > 0 && n.flex_grow <= 0
          child_h = n.pref_height
        @end
        n.computed_height = child_h
        
        @if parent.align_items == ALIGN_STRETCH()
          n.computed_width = avail_w - (n.margin_left + n.margin_right)
          n.computed_x = content_x + n.margin_left
        @elif parent.align_items == ALIGN_CENTER()
          n.computed_width = n.pref_width
          @if n.computed_width > avail_w n.computed_width = avail_w @end
          n.computed_x = content_x + ((avail_w - n.computed_width) / 2)
        @else
          n.computed_width = n.pref_width
          @if n.computed_width > avail_w n.computed_width = avail_w @end
          n.computed_x = content_x + n.margin_left
        @end
        
        @if n.pref_height > 0 && n.flex_grow <= 0
          n.computed_y = content_y + running_offset_y + n.margin_top
        @else
          n.computed_y = content_y + (child_pos * (share_h + gap)) + n.margin_top
        @end
      @end
      
      engine.nodes[i] = n
    @end
    i = i + 1
  @end
  engine.pass_count = engine.pass_count + 1
  return engine
@end

@! Pass 3: Dirty Subtree & Bounding Box Aggregation (cs_dirty_bounds)
@fn gpu_layout_pass_dirty_bounds(engine)
  bounds = dirty_bounds_empty()
  i = 0
  num = engine.nodes.len()
  @while i < num
    n = engine.nodes[i]
    @if n.gpu_is_dirty != 0
      bounds = dirty_bounds_union_rect(bounds, n.computed_x, n.computed_y, n.computed_width, n.computed_height)
    @end
    i = i + 1
  @end
  engine.dirty_output = bounds
  engine.pass_count = engine.pass_count + 1
  return engine
@end

@! ============================================================================
@! 5. ENGINE DISPATCH & RESULTS READBACK
@! ============================================================================

@fn gpu_layout_dispatch(engine)
  engine.stats_dispatches = engine.stats_dispatches + 1
  engine.stats_nodes_processed = engine.stats_nodes_processed + engine.nodes.len()
  
  @if engine.is_gpu_active
    @! WGSL GPU Compute Multi-Pass Dispatch
    engine = gpu_layout_pass_measure(engine)
    engine = gpu_layout_pass_layout(engine)
    engine = gpu_layout_pass_dirty_bounds(engine)
    engine.raw_storage_buffer = gpu_layout_pack_to_float_buffer(engine.nodes)
  @else
    @! CPU Flexbox Fallback Solver
    engine.nodes = flexbox_solve_linear_nodes(engine.nodes, engine.viewport_width, engine.viewport_height)
    engine = gpu_layout_pass_dirty_bounds(engine)
  @end
  
  @! Cache results list
  results = []
  i = 0
  num = engine.nodes.len()
  @while i < num
    n = engine.nodes[i]
    res = layout_result_new(n.node_id, n.computed_x, n.computed_y, n.computed_width, n.computed_height, n.clip_id, (n.gpu_is_dirty != 0))
    results = results.push(res)
    i = i + 1
  @end
  engine.cached_results = results
  
  return engine
@end

@fn gpu_layout_load_tree(engine, root_tree_node)
  engine.nodes = gpu_layout_pack_tree(root_tree_node)
  return engine
@end

@fn gpu_layout_compute_tree(engine, root_tree_node)
  engine = gpu_layout_load_tree(engine, root_tree_node)
  engine = gpu_layout_dispatch(engine)
  return engine
@end

@fn gpu_layout_readback_results(engine)
  return engine.cached_results
@end

@fn gpu_layout_get_dirty_bounds(engine)
  return engine.dirty_output
@end

@! ============================================================================
@! 6. DIRTY RECT CACHING & INCREMENTAL UPDATE
@! ============================================================================

@fn gpu_layout_mark_dirty(engine, node_id)
  i = 0
  num = engine.nodes.len()
  @while i < num
    n = engine.nodes[i]
    @if n.node_id == node_id
      n.gpu_is_dirty = 1
      engine.nodes[i] = n
    @end
    i = i + 1
  @end
  return engine
@end

@fn gpu_layout_mark_all_clean(engine)
  i = 0
  num = engine.nodes.len()
  @while i < num
    n = engine.nodes[i]
    n.gpu_is_dirty = 0
    engine.nodes[i] = n
    i = i + 1
  @end
  engine.dirty_output = dirty_bounds_empty()
  return engine
@end

@fn gpu_layout_update_node_size(engine, node_id, new_w, new_h)
  i = 0
  num = engine.nodes.len()
  @while i < num
    n = engine.nodes[i]
    @if n.node_id == node_id
      n.pref_width = new_w
      n.pref_height = new_h
      n.gpu_is_dirty = 1
      engine.nodes[i] = n
    @end
    i = i + 1
  @end
  return engine
@end

@! ============================================================================
@! 7. PARITY VERIFICATION (GPU COMPUTE vs CPU FLEXBOX)
@! ============================================================================

@fn gpu_layout_verify_parity(gpu_results, cpu_results, tolerance)
  @if gpu_results.len() != cpu_results.len()
    return false
  @end
  
  i = 0
  num = gpu_results.len()
  @while i < num
    g = gpu_results[i]
    c = cpu_results[i]
    
    diff_x = g.x - c.x
    @if diff_x < 0 diff_x = -diff_x @end
    @if diff_x > tolerance return false @end
    
    diff_y = g.y - c.y
    @if diff_y < 0 diff_y = -diff_y @end
    @if diff_y > tolerance return false @end
    
    diff_w = g.width - c.width
    @if diff_w < 0 diff_w = -diff_w @end
    @if diff_w > tolerance return false @end
    
    diff_h = g.height - c.height
    @if diff_h < 0 diff_h = -diff_h @end
    @if diff_h > tolerance return false @end
    
    i = i + 1
  @end
  
  return true
@end
