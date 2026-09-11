@! ============================================================================
@! MAYA WEB FRONTEND ENGINE — ADVERSARIAL STRESS SUITE: GPU/CPU LAYOUT PARITY
@! File: tests/web/frontend/test_stress_gpu_layout.maya
@! Focus: GPU vs CPU Layout Parity, Deep Hierarchies, Proportional Flex Grow/Shrink,
@! Extreme Viewports, Multi-Line Wrapping, and Incremental Dirty Bounds.
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"

import "universe/web/frontend/layout/layout_types"
import "universe/web/frontend/layout/flexbox_solver"
import "universe/web/frontend/layout/gpu_layout"
import "universe/web/frontend/layout/mod"

@fn assert_true(cond, test_id, desc)
  @if cond == true || cond == 1
    println("  ✓ [PASS] " + test_id + ": " + desc)
    return 1
  @end
  println("  ❌ [FAIL] " + test_id + ": " + desc + " (expected true, got false)")
  return 0
@end

@fn assert_eq_int(actual, expected, test_id, desc)
  @if actual == expected
    println("  ✓ [PASS] " + test_id + ": " + desc + " (= " + actual.to_str() + ")")
    return 1
  @end
  println("  ❌ [FAIL] " + test_id + ": " + desc + " (expected " + expected.to_str() + ", got " + actual.to_str())
  return 0
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS 3: GPU vs CPU FLEXBOX LAYOUT PARITY 🔥")
  println("=================================================================")

  total = 18
  passed = 0

  @! 1. Deep Multi-Level Complex Window Hierarchy Parity
  win = layout_node_new(600, LAYOUT_FLEX_COLUMN(), ALIGN_STRETCH(), JUSTIFY_START())
  win = layout_node_set_size(win, 1000, 700)
  win = layout_node_set_padding(win, 10, 10, 10, 10)
  win = layout_node_set_gap(win, 10)
  
  tb = layout_node_new(601, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  tb = layout_node_set_size(tb, 980, 40)
  
  sp = layout_node_new(602, LAYOUT_FLEX_ROW(), ALIGN_STRETCH(), JUSTIFY_START())
  sp = layout_node_set_size(sp, 980, 630)
  sp = layout_node_set_gap(sp, 15)
  
  sb = layout_node_new(603, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  sb = layout_node_set_size(sb, 240, 630)
  
  mc = layout_node_new(604, LAYOUT_FLEX_COLUMN(), ALIGN_STRETCH(), JUSTIFY_START())
  mc = layout_node_set_size(mc, 725, 630)
  mc = layout_node_set_gap(mc, 10)
  
  t1 = layout_node_new(605, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  t1 = layout_node_set_size(t1, 725, 50)
  
  v3 = layout_node_new(606, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  v3 = layout_node_set_size(v3, 725, 570)
  
  mc = layout_node_add_child(mc, t1)
  mc = layout_node_add_child(mc, v3)
  
  sp = layout_node_add_child(sp, sb)
  sp = layout_node_add_child(sp, mc)
  
  win = layout_node_add_child(win, tb)
  win = layout_node_add_child(win, sp)

  eng_g = gpu_layout_engine_new(true, 1000, 700, 1.0)
  eng_g = gpu_layout_compute_tree(eng_g, win)
  res_g = gpu_layout_readback_results(eng_g)

  eng_c = gpu_layout_engine_new(false, 1000, 700, 1.0)
  eng_c = gpu_layout_compute_tree(eng_c, win)
  res_c = gpu_layout_readback_results(eng_c)

  parity1 = gpu_layout_verify_parity(res_g, res_c, 0)
  passed = passed + assert_true(parity1, "PARITY-STRESS-01", "Complex nested UI hierarchy achieves 100% exact GPU/CPU geometrical parity")
  passed = passed + assert_eq_int(res_g.len(), 7, "PARITY-STRESS-02", "All 7 hierarchy nodes resolved")

  @! 2. Flex-Grow Proportional Space Distribution (1:2:3:4 Ratio on 1000px container)
  root_grow = layout_node_new(2001, LAYOUT_FLEX_ROW(), ALIGN_CENTER(), JUSTIFY_START())
  root_grow = layout_node_set_size(root_grow, 1000, 100)

  g1 = layout_node_new(2002, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  g1 = layout_node_set_size(g1, 100, 50)
  g1 = layout_node_set_flex(g1, 1, 0)

  g2 = layout_node_new(2003, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  g2 = layout_node_set_size(g2, 100, 50)
  g2 = layout_node_set_flex(g2, 2, 0)

  g3 = layout_node_new(2004, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  g3 = layout_node_set_size(g3, 100, 50)
  g3 = layout_node_set_flex(g3, 3, 0)

  g4 = layout_node_new(2005, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  g4 = layout_node_set_size(g4, 100, 50)
  g4 = layout_node_set_flex(g4, 4, 0)

  root_grow = layout_node_add_child(root_grow, g1)
  root_grow = layout_node_add_child(root_grow, g2)
  root_grow = layout_node_add_child(root_grow, g3)
  root_grow = layout_node_add_child(root_grow, g4)

  solved_grow = flexbox_solve_tree(root_grow, 1000, 100)
  cg1 = solved_grow.children[0]
  cg2 = solved_grow.children[1]
  cg3 = solved_grow.children[2]
  cg4 = solved_grow.children[3]

  passed = passed + assert_eq_int(cg1.width, 160, "PARITY-STRESS-03", "Flex grow 1x child width is 160")
  passed = passed + assert_eq_int(cg2.width, 220, "PARITY-STRESS-04", "Flex grow 2x child width is 220")
  passed = passed + assert_eq_int(cg3.width, 280, "PARITY-STRESS-05", "Flex grow 3x child width is 280")
  passed = passed + assert_eq_int(cg4.width, 340, "PARITY-STRESS-06", "Flex grow 4x child width is 340")
  passed = passed + assert_eq_int(cg1.width + cg2.width + cg3.width + cg4.width, 1000, "PARITY-STRESS-07", "Sum of proportional flex-grown widths exactly matches container width 1000")

  @! 3. Flex-Shrink with Deficit (300px container, two 200px items with shrink 1:1)
  root_shrink = layout_node_new(2100, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  root_shrink = layout_node_set_size(root_shrink, 300, 100)

  sk1 = layout_node_new(2101, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  sk1 = layout_node_set_size(sk1, 200, 50)
  sk1 = layout_node_set_flex(sk1, 0, 1)

  sk2 = layout_node_new(2102, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  sk2 = layout_node_set_size(sk2, 200, 50)
  sk2 = layout_node_set_flex(sk2, 0, 1)

  root_shrink = layout_node_add_child(root_shrink, sk1)
  root_shrink = layout_node_add_child(root_shrink, sk2)

  solved_shrink = flexbox_solve_tree(root_shrink, 300, 100)
  passed = passed + assert_eq_int(solved_shrink.children[0].width, 150, "PARITY-STRESS-08", "Item 1 shrunken width is 150 (200 - 50)")
  passed = passed + assert_eq_int(solved_shrink.children[1].width, 150, "PARITY-STRESS-09", "Item 2 shrunken width is 150 (200 - 50)")

  @! 4. Extreme Viewport Boundaries (1x1 Pixel & 4K 3840x2160 Resolution)
  root_tiny = layout_node_new(3001, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  root_tiny = layout_node_set_size(root_tiny, 1, 1)
  t_child = layout_node_new(3002, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  t_child = layout_node_set_size(t_child, 10, 10)
  root_tiny = layout_node_add_child(root_tiny, t_child)

  eng_tiny = gpu_layout_engine_new(true, 1, 1, 1.0)
  eng_tiny = gpu_layout_compute_tree(eng_tiny, root_tiny)
  res_tiny = gpu_layout_readback_results(eng_tiny)
  passed = passed + assert_eq_int(res_tiny[0].width, 1, "PARITY-STRESS-10", "1x1 pixel viewport root resolved without underflow")

  root_4k = layout_node_new(4001, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  root_4k = layout_node_set_size(root_4k, 3840, 2160)
  k_child = layout_node_new(4002, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  k_child = layout_node_set_size(k_child, 1920, 1080)
  root_4k = layout_node_add_child(root_4k, k_child)

  eng_4k_gpu = gpu_layout_engine_new(true, 3840, 2160, 2.0)
  eng_4k_gpu = gpu_layout_compute_tree(eng_4k_gpu, root_4k)
  res_4k_gpu = gpu_layout_readback_results(eng_4k_gpu)

  eng_4k_cpu = gpu_layout_engine_new(false, 3840, 2160, 2.0)
  eng_4k_cpu = gpu_layout_compute_tree(eng_4k_cpu, root_4k)
  res_4k_cpu = gpu_layout_readback_results(eng_4k_cpu)

  parity_4k = gpu_layout_verify_parity(res_4k_gpu, res_4k_cpu, 0)
  passed = passed + assert_true(parity_4k, "PARITY-STRESS-11", "4K physical resolution produces identical GPU/CPU layouts")

  @! 5. Incremental Dirty Bounds Under Partial Node Updates
  eng_dirty = gpu_layout_engine_new(true, 1000, 800, 1.0)
  
  root_d = layout_node_new(5000, LAYOUT_FLEX_COLUMN(), ALIGN_START(), JUSTIFY_START())
  root_d = layout_node_set_size(root_d, 1000, 800)
  
  d1 = layout_node_new(5001, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  d1 = layout_node_set_size(d1, 200, 100)
  
  d2 = layout_node_new(5002, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  d2 = layout_node_set_size(d2, 300, 150)
  
  d3 = layout_node_new(5003, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  d3 = layout_node_set_size(d3, 400, 200)
  
  root_d = layout_node_add_child(root_d, d1)
  root_d = layout_node_add_child(root_d, d2)
  root_d = layout_node_add_child(root_d, d3)
  
  eng_dirty = gpu_layout_compute_tree(eng_dirty, root_d)
  eng_dirty = gpu_layout_mark_all_clean(eng_dirty)
  
  eng_dirty = gpu_layout_mark_dirty(eng_dirty, 5002)
  eng_dirty = gpu_layout_dispatch(eng_dirty)
  
  db_res = gpu_layout_get_dirty_bounds(eng_dirty)
  passed = passed + assert_true(db_res.has_dirty, "PARITY-STRESS-12", "Dirty bounds tracks updated child")
  passed = passed + assert_eq_int(db_res.min_y, 100, "PARITY-STRESS-13", "Dirty bounds min_y accurately starts at 100")
  passed = passed + assert_eq_int(db_res.max_y, 250, "PARITY-STRESS-14", "Dirty bounds max_y accurately ends at 250 (100+150)")

  @! 6. Multi-Line Flex Wrapping
  root_wrap = layout_node_new(6000, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  root_wrap = layout_node_set_size(root_wrap, 300, 200)
  root_wrap.flex_wrap = WRAP_WRAP()
  root_wrap = layout_node_set_gap(root_wrap, 10)
  
  w1 = layout_node_new(6001, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  w1 = layout_node_set_size(w1, 100, 40)
  w2 = layout_node_new(6002, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  w2 = layout_node_set_size(w2, 100, 40)
  w3 = layout_node_new(6003, LAYOUT_ABSOLUTE(), ALIGN_START(), JUSTIFY_START())
  w3 = layout_node_set_size(w3, 100, 50)
  
  root_wrap = layout_node_add_child(root_wrap, w1)
  root_wrap = layout_node_add_child(root_wrap, w2)
  root_wrap = layout_node_add_child(root_wrap, w3)
  
  sol_wrap = flexbox_solve_tree(root_wrap, 300, 200)
  passed = passed + assert_eq_int(sol_wrap.children[0].x, 0, "PARITY-STRESS-15", "Line 1 item 1 x is 0")
  passed = passed + assert_eq_int(sol_wrap.children[1].x, 110, "PARITY-STRESS-16", "Line 1 item 2 x is 110 (100+10)")
  passed = passed + assert_eq_int(sol_wrap.children[2].x, 0, "PARITY-STRESS-17", "Line 2 wrapped item 3 x wraps to 0")
  passed = passed + assert_eq_int(sol_wrap.children[2].y, 50, "PARITY-STRESS-18", "Line 2 wrapped item 3 y is 50 (40+10)")

  println("\n=================================================================")
  println("📊 GPU/CPU LAYOUT PARITY RESULTS: " + passed.to_str() + " / " + total.to_str() + " assertions passed")
  println("=================================================================")

  @if passed == total
    println("🎉 ALL 18 GPU/CPU LAYOUT PARITY & STRESS CHALLENGES PASSED! 🎉")
    return 0
  @else
    return 1
  @end
@end
