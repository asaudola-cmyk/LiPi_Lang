@! ============================================================================
@! MAYA WEB FRONTEND ENGINE — GPU COMPUTE LAYOUT & FLEXBOX TEST SUITE
@! File: tests/web/frontend/test_gpu_layout.maya
@! Milestone: M2 — GPU Compute Layout Engine & Flexbox Solver
@! 100% Pure Maya Implementation — Zero External / C++ Dependencies
@! Features:
@! - Feature 5: GPU Compute Layout Engine & Linear Storage Buffer Packing
@! - Feature 6: High-Precision CPU Flexbox Layout Fallback
@! - Nested hierarchies, flex-grow/shrink distributions, wrapping, and dirty bounds
@! - Comprehensive coverage: Tier 1, Tier 2, Tier 3, and Tier 4 workloads
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/web/frontend/layout/layout_types"
import "universe/web/frontend/layout/flexbox_solver"
import "universe/web/frontend/layout/gpu_layout"
import "universe/web/frontend/layout/mod"

@! ============================================================================
@! 1. TEST HARNESS & ASSERTION FRAMEWORK
@! ============================================================================

@struct TestState
  total: i64
  passed: i64
  failed: i64
@end

@fn test_state_new()
  return { total: 0, passed: 0, failed: 0 }
@end

@fn assert_true(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == true || cond == 1
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected true, got false)")
    return 0
  @end
@end

@fn assert_false(state, cond, test_id, desc)
  state.total = state.total + 1
  @if cond == false || cond == 0
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected false, got true)")
    return 0
  @end
@end

@fn assert_eq_int(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected " + expected.to_str() + ", got " + actual.to_str() + ")")
    return 0
  @end
@end

@! ============================================================================
@! 2. TEST CATEGORY 1: LINEAR STORAGE BUFFER PACKING & UNPACKING
@! ============================================================================

@fn test_buffer_packing(state)
  println("\n--- [Category 1: Linear GPU Storage Buffer Packing & Unpacking] ---")
  
  @! Create a 3-node hierarchy: Root Container (Column) -> Row -> 2 Buttons
  root = layout_node_new(1, LAYOUT_FLEX_COLUMN(), ALIGN_STRETCH(), JUSTIFY_START())
  root = layout_node_set_size(root, 800, 600)
  root = layout_node_set_padding(root, 10, 10, 10, 10)
  
  row = layout_node_new(2, LAYOUT_FLEX_ROW(), ALIGN_CENTER(), JUSTIFY_SPACE_BETWEEN())
  row = layout_node_set_size(row, 780, 100)
  row = layout_node_set_gap(row, 20)
  
  btn1 = layout_node_new(3, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  btn1 = layout_node_set_size(btn1, 200, 40)
  
  btn2 = layout_node_new(4, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  btn2 = layout_node_set_size(btn2, 200, 40)
  
  row = layout_node_add_child(row, btn1)
  row = layout_node_add_child(row, btn2)
  root = layout_node_add_child(root, row)
  
  linear_nodes = gpu_layout_pack_tree(root)
  
  assert_eq_int(state, linear_nodes.len(), 4, "PACK-01", "Tree flattens into 4 linear GpuLayoutNode entries")
  
  n0 = linear_nodes[0]
  assert_eq_int(state, n0.node_id, 1, "PACK-02", "Root node has id 1 and parent_idx -1")
  assert_eq_int(state, n0.parent_idx, -1, "PACK-03", "Root parent_idx is -1")
  assert_eq_int(state, n0.first_child_idx, 1, "PACK-04", "Root first_child_idx points to Row at index 1")
  assert_eq_int(state, n0.child_count, 1, "PACK-05", "Root child_count is 1")
  
  n1 = linear_nodes[1]
  assert_eq_int(state, n1.node_id, 2, "PACK-06", "Row node has id 2 and parent_idx 0")
  assert_eq_int(state, n1.parent_idx, 0, "PACK-07", "Row parent_idx points to Root at index 0")
  assert_eq_int(state, n1.first_child_idx, 2, "PACK-08", "Row first_child_idx points to btn1 at index 2")
  assert_eq_int(state, n1.child_count, 2, "PACK-09", "Row child_count is 2")
  
  n2 = linear_nodes[2]
  assert_eq_int(state, n2.node_id, 3, "PACK-10", "Btn1 node has next_sibling_idx pointing to Btn2 at index 3")
  assert_eq_int(state, n2.next_sibling_idx, 3, "PACK-11", "Btn1 next_sibling_idx is 3")
  
  @! Float Buffer serialization test
  float_buf = gpu_layout_pack_to_float_buffer(linear_nodes)
  assert_eq_int(state, float_buf.len(), 4 * 28, "PACK-12", "Float buffer contains exactly 112 integers (28 per node)")
  assert_eq_int(state, float_buf[0], 1, "PACK-13", "Float buffer index 0 contains root node_id 1")
  assert_eq_int(state, float_buf[14], 10, "PACK-14", "Float buffer contains correct padding top 10")
  
  @! Unpack test
  unpacked = gpu_layout_unpack_tree(linear_nodes)
  assert_eq_int(state, unpacked.id, 1, "PACK-15", "Unpacked tree root id matches original")
  assert_eq_int(state, unpacked.children.len(), 1, "PACK-16", "Unpacked tree retains children hierarchy")
  assert_eq_int(state, unpacked.children[0].children.len(), 2, "PACK-17", "Unpacked row contains 2 button children")
@end

@! ============================================================================
@! 3. TEST CATEGORY 2: WGSL COMPUTE LAYOUT PASSES
@! ============================================================================

@fn test_wgsl_compute_passes(state)
  println("\n--- [Category 2: WGSL Compute Layout Passes] ---")
  
  engine = gpu_layout_engine_new(true, 1024, 768, 1.0)
  assert_true(state, engine.is_gpu_active, "WGSL-01", "GPU Layout engine initialized in active GPU mode")
  assert_true(state, engine.wgsl_shader_source.len() > 100, "WGSL-02", "WGSL compute shader source is embedded")
  
  @! Build container with 3 equal children in a Row
  root = layout_node_new(10, LAYOUT_FLEX_ROW(), ALIGN_STRETCH(), JUSTIFY_START())
  root = layout_node_set_size(root, 900, 300)
  root = layout_node_set_gap(root, 30)
  root = layout_node_set_padding(root, 15, 15, 15, 15)
  
  c1 = layout_node_new(11, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  c1 = layout_node_set_flex(c1, 1, 1)
  
  c2 = layout_node_new(12, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  c2 = layout_node_set_flex(c2, 1, 1)
  
  c3 = layout_node_new(13, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  c3 = layout_node_set_flex(c3, 1, 1)
  
  root = layout_node_add_child(root, c1)
  root = layout_node_add_child(root, c2)
  root = layout_node_add_child(root, c3)
  
  engine = gpu_layout_compute_tree(engine, root)
  
  assert_eq_int(state, engine.pass_count, 3, "WGSL-03", "GPU Dispatch executed all 3 compute passes (Measure, Layout, DirtyBounds)")
  assert_eq_int(state, engine.stats_dispatches, 1, "WGSL-04", "Dispatch counter incremented to 1")
  
  results = gpu_layout_readback_results(engine)
  assert_eq_int(state, results.len(), 4, "WGSL-05", "Readback returns 4 LayoutResult bounding boxes")
  
  @! Content width = 900 - 30 = 870. Gaps = 2 * 30 = 60. Net width = 810. Share per child = 270.
  r0 = results[0]
  assert_eq_int(state, r0.width, 900, "WGSL-06", "Root container computed width is 900")
  assert_eq_int(state, r0.height, 300, "WGSL-07", "Root container computed height is 300")
  
  r1 = results[1]
  assert_eq_int(state, r1.x, 15, "WGSL-08", "Child 1 x position is 15 (left padding)")
  assert_eq_int(state, r1.width, 270, "WGSL-09", "Child 1 computed share width is 270")
  assert_eq_int(state, r1.height, 270, "WGSL-10", "Child 1 stretched height is 270 (300 - 30 padding)")
  
  r2 = results[2]
  assert_eq_int(state, r2.x, 315, "WGSL-11", "Child 2 x position is 315 (15 + 270 + 30)")
  assert_eq_int(state, r2.width, 270, "WGSL-12", "Child 2 computed share width is 270")
  
  r3 = results[3]
  assert_eq_int(state, r3.x, 615, "WGSL-13", "Child 3 x position is 615 (315 + 270 + 30)")
  assert_eq_int(state, r3.width, 270, "WGSL-14", "Child 3 computed share width is 270")
@end

@! ============================================================================
@! 4. TEST CATEGORY 3: CPU FLEXBOX SOLVER & PROPORTIONAL DISTRIBUTIONS
@! ============================================================================

@fn test_cpu_flexbox_solver(state)
  println("\n--- [Category 3: CPU Flexbox Solver & Proportional Distributions] ---")
  
  @! Flex Grow 1:2:1 on 500px container (content = 500, fixed items = 150, free space = 350)
  root = layout_node_new(100, LAYOUT_FLEX_ROW(), ALIGN_CENTER(), JUSTIFY_START())
  root = layout_node_set_size(root, 500, 200)
  
  item1 = layout_node_new(101, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  item1 = layout_node_set_size(item1, 50, 50)
  item1 = layout_node_set_flex(item1, 1, 1)
  
  item2 = layout_node_new(102, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  item2 = layout_node_set_size(item2, 50, 50)
  item2 = layout_node_set_flex(item2, 2, 1)
  
  item3 = layout_node_new(103, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  item3 = layout_node_set_size(item3, 50, 50)
  item3 = layout_node_set_flex(item3, 1, 1)
  
  root = layout_node_add_child(root, item1)
  root = layout_node_add_child(root, item2)
  root = layout_node_add_child(root, item3)
  
  solved = flexbox_solve_tree(root, 500, 200)
  
  @! Free space = 350.
  @! Item 1: 50 + (350 * 1 / 4) = 50 + 87 = 137. rem_free = 263.
  @! Item 2: 50 + (263 * 2 / 3) = 50 + 175 = 225. rem_free = 88.
  @! Item 3: 50 + (88 * 1 / 1) = 50 + 88 = 138.
  @! Total = 137 + 225 + 138 = 500.
  
  c1 = solved.children[0]
  c2 = solved.children[1]
  c3 = solved.children[2]
  
  assert_eq_int(state, c1.width, 137, "FLEX-01", "Item 1 flex-grow 1x width is 137")
  assert_eq_int(state, c2.width, 225, "FLEX-02", "Item 2 flex-grow 2x width is 225")
  assert_eq_int(state, c3.width, 138, "FLEX-03", "Item 3 flex-grow 1x width is 138 (with remainder conservation)")
  assert_eq_int(state, c1.width + c2.width + c3.width, 500, "FLEX-04", "Sum of flex-grown children exactly equals container width 500")
  
  @! Check Vertical Alignment ALIGN_CENTER (container h=200, item h=50 -> y = 75)
  assert_eq_int(state, c1.y, 75, "FLEX-05", "Centered item y coordinate is 75 ((200 - 50) / 2)")
@end

@! ============================================================================
@! 5. TEST CATEGORY 4: JUSTIFICATION & ALIGN_SELF
@! ============================================================================

@fn test_justification_and_align_self(state)
  println("\n--- [Category 4: Justification & Align-Self] ---")
  
  @! Justify SPACE_BETWEEN on 600px row with two 100px items (gap = 400)
  root = layout_node_new(200, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_SPACE_BETWEEN())
  root = layout_node_set_size(root, 600, 100)
  
  it1 = layout_node_new(201, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  it1 = layout_node_set_size(it1, 100, 40)
  it1.align_self = ALIGN_SELF_END() @! Overrides container ALIGN_START -> y = 60
  
  it2 = layout_node_new(202, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  it2 = layout_node_set_size(it2, 100, 40)
  
  root = layout_node_add_child(root, it1)
  root = layout_node_add_child(root, it2)
  
  solved = flexbox_solve_tree(root, 600, 100)
  
  ch1 = solved.children[0]
  ch2 = solved.children[1]
  
  assert_eq_int(state, ch1.x, 0, "JUST-01", "Space-between first child starts at x=0")
  assert_eq_int(state, ch2.x, 500, "JUST-02", "Space-between second child ends at x=500 (600 - 100)")
  assert_eq_int(state, ch1.y, 60, "JUST-03", "Align-Self END places child 1 at y=60 (100 - 40)")
  assert_eq_int(state, ch2.y, 0, "JUST-04", "Container Align-Start places child 2 at y=0")
@end

@! ============================================================================
@! 6. TEST CATEGORY 5: MULTI-LINE FLEX WRAPPING
@! ============================================================================

@fn test_flex_wrapping(state)
  println("\n--- [Category 5: Multi-Line Flex Wrapping] ---")
  
  @! Container width = 300px, 4 items of width 100px with gap 10px -> Lines: [it1, it2] (210px), [it3, it4] (210px)
  root = layout_node_new(300, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  root = layout_node_set_size(root, 300, 200)
  root.flex_wrap = WRAP_WRAP()
  root = layout_node_set_gap(root, 10)
  
  i1 = layout_node_new(301, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  i1 = layout_node_set_size(i1, 100, 40)
  
  i2 = layout_node_new(302, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  i2 = layout_node_set_size(i2, 100, 40)
  
  i3 = layout_node_new(303, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  i3 = layout_node_set_size(i3, 100, 50)
  
  i4 = layout_node_new(304, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  i4 = layout_node_set_size(i4, 100, 50)
  
  root = layout_node_add_child(root, i1)
  root = layout_node_add_child(root, i2)
  root = layout_node_add_child(root, i3)
  root = layout_node_add_child(root, i4)
  
  solved = flexbox_solve_tree(root, 300, 200)
  
  c1 = solved.children[0]
  c2 = solved.children[1]
  c3 = solved.children[2]
  c4 = solved.children[3]
  
  assert_eq_int(state, c1.x, 0, "WRAP-01", "Line 1 item 1 at x=0, y=0")
  assert_eq_int(state, c1.y, 0, "WRAP-02", "Line 1 item 1 y is 0")
  assert_eq_int(state, c2.x, 110, "WRAP-03", "Line 1 item 2 at x=110 (100 + 10 gap)")
  assert_eq_int(state, c2.y, 0, "WRAP-04", "Line 1 item 2 y is 0")
  
  assert_eq_int(state, c3.x, 0, "WRAP-05", "Line 2 item 3 wraps to next line at x=0")
  assert_eq_int(state, c3.y, 50, "WRAP-06", "Line 2 item 3 y is 50 (line 1 height 40 + gap 10)")
  assert_eq_int(state, c4.x, 110, "WRAP-07", "Line 2 item 4 at x=110, y=50")
  assert_eq_int(state, c4.y, 50, "WRAP-08", "Line 2 item 4 y is 50")
@end

@! ============================================================================
@! 7. TEST CATEGORY 6: DIRTY BOUNDS CACHING & INCREMENTAL UPDATES
@! ============================================================================

@fn test_dirty_bounds_caching(state)
  println("\n--- [Category 6: Dirty Bounds Caching & Incremental Updates] ---")
  
  engine = gpu_layout_engine_new(true, 800, 600, 1.0)
  
  root = layout_node_new(400, LAYOUT_FLEX_COLUMN(), ALIGN_STRETCH(), JUSTIFY_START())
  root = layout_node_set_size(root, 800, 600)
  
  header = layout_node_new(401, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  header = layout_node_set_size(header, 800, 80)
  
  body = layout_node_new(402, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  body = layout_node_set_size(body, 800, 520)
  
  root = layout_node_add_child(root, header)
  root = layout_node_add_child(root, body)
  
  engine = gpu_layout_compute_tree(engine, root)
  
  db = gpu_layout_get_dirty_bounds(engine)
  assert_true(state, db.has_dirty, "DIRTY-01", "Initial full layout marks dirty bounds active")
  assert_eq_int(state, db.min_x, 0, "DIRTY-02", "Dirty bounds min_x covers root 0")
  assert_eq_int(state, db.max_x, 800, "DIRTY-03", "Dirty bounds max_x covers 800")
  assert_eq_int(state, db.max_y, 600, "DIRTY-04", "Dirty bounds max_y covers 600")
  
  @! Mark clean and then mark only header dirty
  engine = gpu_layout_mark_all_clean(engine)
  db_clean = gpu_layout_get_dirty_bounds(engine)
  assert_false(state, db_clean.has_dirty, "DIRTY-05", "Dirty bounds are empty after mark_all_clean")
  
  engine = gpu_layout_mark_dirty(engine, 401)
  engine = gpu_layout_dispatch(engine)
  
  db_inc = gpu_layout_get_dirty_bounds(engine)
  assert_true(state, db_inc.has_dirty, "DIRTY-06", "Incremental dirty bounds active after header mark_dirty")
  assert_eq_int(state, db_inc.max_y, 80, "DIRTY-07", "Dirty bounds max_y accurately localized to header height 80")
@end

@! ============================================================================
@! 8. TEST CATEGORY 7: GPU / CPU FALLBACK & PARITY
@! ============================================================================

@fn test_gpu_cpu_parity(state)
  println("\n--- [Category 7: GPU / CPU Fallback & Parity] ---")
  
  root = layout_node_new(500, LAYOUT_FLEX_ROW(), ALIGN_CENTER(), JUSTIFY_START())
  root = layout_node_set_size(root, 1000, 400)
  root = layout_node_set_padding(root, 20, 20, 20, 20)
  root = layout_node_set_gap(root, 10)
  
  c1 = layout_node_new(501, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  c1 = layout_node_set_size(c1, 300, 150)
  
  c2 = layout_node_new(502, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  c2 = layout_node_set_size(c2, 300, 150)
  
  c3 = layout_node_new(503, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  c3 = layout_node_set_size(c3, 300, 150)
  
  root = layout_node_add_child(root, c1)
  root = layout_node_add_child(root, c2)
  root = layout_node_add_child(root, c3)
  
  @! 1. Run GPU compute
  engine_gpu = gpu_layout_engine_new(true, 1000, 400, 1.0)
  engine_gpu = gpu_layout_compute_tree(engine_gpu, root)
  res_gpu = gpu_layout_readback_results(engine_gpu)
  
  @! 2. Run CPU fallback
  engine_cpu = gpu_layout_engine_new(false, 1000, 400, 1.0)
  engine_cpu = gpu_layout_compute_tree(engine_cpu, root)
  res_cpu = gpu_layout_readback_results(engine_cpu)
  
  is_equal = gpu_layout_verify_parity(res_gpu, res_cpu, 0)
  assert_true(state, is_equal, "PARITY-01", "GPU compute and CPU fallback produce 100% geometrically identical layouts")
  assert_eq_int(state, res_gpu.len(), res_cpu.len(), "PARITY-02", "Node counts match between GPU and CPU backends")
@end

@! ============================================================================
@! 9. TEST CATEGORY 8: DEEP NESTED HIERARCHIES (3-LEVEL COMPLEX WORKLOAD)
@! ============================================================================

@fn test_deep_nested_hierarchy(state)
  println("\n--- [Category 8: Deep Nested Hierarchies (3-Level Layouts)] ---")
  
  @! Window (Column: 800x600) -> Split View (Row: 780x540) -> Left Sidebar (200x540) & Right Content (Column: 560x540) -> Toolbar & Grid
  win = layout_node_new(600, LAYOUT_FLEX_COLUMN(), ALIGN_STRETCH(), JUSTIFY_START())
  win = layout_node_set_size(win, 800, 600)
  win = layout_node_set_padding(win, 10, 10, 10, 10)
  win = layout_node_set_gap(win, 10)
  
  titlebar = layout_node_new(601, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  titlebar = layout_node_set_size(titlebar, 780, 30)
  
  split = layout_node_new(602, LAYOUT_FLEX_ROW(), ALIGN_STRETCH(), JUSTIFY_START())
  split = layout_node_set_size(split, 780, 540)
  split = layout_node_set_gap(split, 20)
  
  sidebar = layout_node_new(603, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  sidebar = layout_node_set_size(sidebar, 200, 540)
  
  main_content = layout_node_new(604, LAYOUT_FLEX_COLUMN(), ALIGN_STRETCH(), JUSTIFY_START())
  main_content = layout_node_set_size(main_content, 560, 540)
  main_content = layout_node_set_gap(main_content, 15)
  
  tool1 = layout_node_new(605, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  tool1 = layout_node_set_size(tool1, 560, 45)
  
  view3d = layout_node_new(606, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  view3d = layout_node_set_size(view3d, 560, 480)
  
  main_content = layout_node_add_child(main_content, tool1)
  main_content = layout_node_add_child(main_content, view3d)
  
  split = layout_node_add_child(split, sidebar)
  split = layout_node_add_child(split, main_content)
  
  win = layout_node_add_child(win, titlebar)
  win = layout_node_add_child(win, split)
  
  solved = flexbox_solve_tree(win, 800, 600)
  
  tb = solved.children[0]
  sp = solved.children[1]
  sb = sp.children[0]
  mc = sp.children[1]
  t1 = mc.children[0]
  v3 = mc.children[1]
  
  assert_eq_int(state, tb.x, 10, "NEST-01", "Titlebar x is 10 (window left padding)")
  assert_eq_int(state, tb.y, 10, "NEST-02", "Titlebar y is 10 (window top padding)")
  assert_eq_int(state, sp.x, 10, "NEST-03", "Split view x is 10")
  assert_eq_int(state, sp.y, 50, "NEST-04", "Split view y is 50 (10 + 30 titlebar + 10 gap)")
  assert_eq_int(state, sb.x, 10, "NEST-05", "Sidebar x is 10 (split origin)")
  assert_eq_int(state, mc.x, 230, "NEST-06", "Main content x is 230 (10 + 200 sidebar + 20 gap)")
  assert_eq_int(state, t1.y, 50, "NEST-07", "Toolbar y is 50 (main content origin)")
  assert_eq_int(state, v3.y, 110, "NEST-08", "3D Viewport y is 110 (50 + 45 toolbar + 15 gap)")
@end

@! ============================================================================
@! 10. TEST CATEGORY 9: PROPORTIONAL FLEX SHRINK WITH DEFICIT
@! ============================================================================

@fn test_flex_shrink(state)
  println("\n--- [Category 9: Proportional Flex Shrink with Deficit] ---")
  
  @! Row width = 300px. Two items of width 200px each (total 400px, deficit 100px).
  @! Item 1 shrink = 1, Item 2 shrink = 1.
  @! Each shrinks by (100 * 1 / 2) = 50px -> Both end at 150px.
  root = layout_node_new(700, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  root = layout_node_set_size(root, 300, 100)
  
  s1 = layout_node_new(701, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  s1 = layout_node_set_size(s1, 200, 50)
  s1 = layout_node_set_flex(s1, 0, 1)
  
  s2 = layout_node_new(702, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  s2 = layout_node_set_size(s2, 200, 50)
  s2 = layout_node_set_flex(s2, 0, 1)
  
  root = layout_node_add_child(root, s1)
  root = layout_node_add_child(root, s2)
  
  solved = flexbox_solve_tree(root, 300, 100)
  
  ch1 = solved.children[0]
  ch2 = solved.children[1]
  
  assert_eq_int(state, ch1.width, 150, "SHRINK-01", "Item 1 shrunken width is 150 (200 - 50)")
  assert_eq_int(state, ch2.width, 150, "SHRINK-02", "Item 2 shrunken width is 150 (200 - 50)")
  assert_eq_int(state, ch1.width + ch2.width, 300, "SHRINK-03", "Sum of shrunken widths exactly equals container width 300")
@end

@! ============================================================================
@! 11. TEST CATEGORY 10: JUSTIFY MODES (SPACE_AROUND & SPACE_EVENLY)
@! ============================================================================

@fn test_justify_around_evenly(state)
  println("\n--- [Category 10: Justification (SPACE_AROUND & SPACE_EVENLY)] ---")
  
  @! 1. SPACE_AROUND on 400px container with two 100px items.
  @! Remaining = 200. unit = 200 / (2 * 2) = 50.
  @! Item 1: x = 50. Item 2: x = 50 + 100 + 100 = 250.
  r_around = layout_node_new(800, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_SPACE_AROUND())
  r_around = layout_node_set_size(r_around, 400, 100)
  
  a1 = layout_node_new(801, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  a1 = layout_node_set_size(a1, 100, 50)
  a2 = layout_node_new(802, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  a2 = layout_node_set_size(a2, 100, 50)
  
  r_around = layout_node_add_child(r_around, a1)
  r_around = layout_node_add_child(r_around, a2)
  
  sol_around = flexbox_solve_tree(r_around, 400, 100)
  assert_eq_int(state, sol_around.children[0].x, 50, "JUST-05", "SPACE_AROUND first item starts at x=50")
  assert_eq_int(state, sol_around.children[1].x, 250, "JUST-06", "SPACE_AROUND second item starts at x=250")
  
  @! 2. SPACE_EVENLY on 500px container with two 100px items.
  @! Remaining = 300. unit = 300 / (2 + 1) = 100.
  @! Item 1: x = 100. Item 2: x = 100 + 100 + 100 = 300.
  r_even = layout_node_new(810, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_SPACE_EVENLY())
  r_even = layout_node_set_size(r_even, 500, 100)
  
  e1 = layout_node_new(811, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  e1 = layout_node_set_size(e1, 100, 50)
  e2 = layout_node_new(812, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  e2 = layout_node_set_size(e2, 100, 50)
  
  r_even = layout_node_add_child(r_even, e1)
  r_even = layout_node_add_child(r_even, e2)
  
  sol_even = flexbox_solve_tree(r_even, 500, 100)
  assert_eq_int(state, sol_even.children[0].x, 100, "JUST-07", "SPACE_EVENLY first item starts at x=100")
  assert_eq_int(state, sol_even.children[1].x, 300, "JUST-08", "SPACE_EVENLY second item starts at x=300")
@end

@! ============================================================================
@! 12. TEST CATEGORY 11: GRID LAYOUT SOLVER
@! ============================================================================

@fn test_grid_layout(state)
  println("\n--- [Category 11: Grid Layout Solver] ---")
  
  @! 2-Column Grid on 420px container with gap 20px. Each col = (420 - 20) / 2 = 200px.
  grid = layout_node_new(900, LAYOUT_GRID(), ALIGN_START(), JUSTIFY_START())
  grid = layout_node_set_size(grid, 420, 300)
  grid = layout_node_set_gap(grid, 20)
  
  g1 = layout_node_new(901, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  g1 = layout_node_set_size(g1, 0, 80)
  g2 = layout_node_new(902, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  g2 = layout_node_set_size(g2, 0, 80)
  g3 = layout_node_new(903, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  g3 = layout_node_set_size(g3, 0, 80)
  g4 = layout_node_new(904, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  g4 = layout_node_set_size(g4, 0, 80)
  
  grid = layout_node_add_child(grid, g1)
  grid = layout_node_add_child(grid, g2)
  grid = layout_node_add_child(grid, g3)
  grid = layout_node_add_child(grid, g4)
  
  sol_grid = flexbox_solve_tree(grid, 420, 300)
  
  cg1 = sol_grid.children[0]
  cg2 = sol_grid.children[1]
  cg3 = sol_grid.children[2]
  cg4 = sol_grid.children[3]
  
  assert_eq_int(state, cg1.x, 0, "GRID-01", "Cell (0,0) at x=0")
  assert_eq_int(state, cg1.y, 0, "GRID-02", "Cell (0,0) at y=0")
  assert_eq_int(state, cg1.width, 200, "GRID-03", "Cell (0,0) width is 200")
  
  assert_eq_int(state, cg2.x, 220, "GRID-04", "Cell (0,1) at x=220 (200 + 20 gap)")
  assert_eq_int(state, cg2.y, 0, "GRID-05", "Cell (0,1) at y=0")
  
  assert_eq_int(state, cg3.x, 0, "GRID-06", "Cell (1,0) at x=0")
  assert_eq_int(state, cg3.y, 100, "GRID-07", "Cell (1,0) at y=100 (80 + 20 gap)")
  
  assert_eq_int(state, cg4.x, 220, "GRID-08", "Cell (1,1) at x=220")
  assert_eq_int(state, cg4.y, 100, "GRID-09", "Cell (1,1) at y=100")
@end

@! ============================================================================
@! 13. MAIN TEST RUNNER
@! ============================================================================

@fn main()
  println("================================================================================")
  println("MAYA WEB FRONTEND ENGINE — GPU COMPUTE LAYOUT & FLEXBOX TEST RUNNER")
  println("================================================================================")
  
  state = test_state_new()
  
  test_buffer_packing(state)
  test_wgsl_compute_passes(state)
  test_cpu_flexbox_solver(state)
  test_justification_and_align_self(state)
  test_flex_wrapping(state)
  test_dirty_bounds_caching(state)
  test_gpu_cpu_parity(state)
  test_deep_nested_hierarchy(state)
  test_flex_shrink(state)
  test_justify_around_evenly(state)
  test_grid_layout(state)
  
  println("\n================================================================================")
  println("TEST SUMMARY")
  println("================================================================================")
  println("Total Assertions: " + state.total.to_str())
  println("Passed:           " + state.passed.to_str())
  println("Failed:           " + state.failed.to_str())
  println("================================================================================")
  
  @if state.failed == 0
    println("✓ ALL GPU LAYOUT ENGINE & FLEXBOX TESTS PASSED (100% SUCCESS)")
    return 0
  @else
    println("✗ TEST FAILURES DETECTED: " + state.failed.to_str() + " assertions failed.")
    return 1
  @end
@end
