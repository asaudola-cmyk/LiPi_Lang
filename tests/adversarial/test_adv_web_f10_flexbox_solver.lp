@! ============================================================================
@! ADVERSARIAL STRESS SUITE — CHALLENGER 1: FLEXBOX & GRID LAYOUT SOLVER (F10)
@! Module: tests/adversarial/test_adv_web_f10_flexbox_solver.maya
@! Target: universe/web/frontend/layout/flexbox_solver.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"
import "universe/web/frontend/layout/layout_types"
import "universe/web/frontend/layout/flexbox_solver"

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
    println("  [FAIL] " + test_id + ": " + desc + " (expected " + int_to_str(expected) + ", got " + int_to_str(actual) + ")")
    return 0
  @end
@end

@fn make_box(id, w, h)
  node = layout_node_new(id, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  node.pref_width = w
  node.pref_height = h
  return node
@end

@fn main()
  println("=================================================================")
  println("⚔️  ADVERSARIAL CHALLENGER 1: Feature F10 (Flexbox & Grid Solver) ⚔️")
  println("=================================================================")

  state = test_state_new()

  @! ==========================================================================
  @! SECTION 1: All 6 Justification Modes with Non-Divisible Remainder Distribution
  @! ==========================================================================
  println("\n--- Section 1: 6 Justification Modes & Bresenham Integer Gap Distribution ---")

  @! 1.1 JUSTIFY_START (Mode 0)
  parent0 = layout_node_new(100, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  parent0.pref_width = 500
  parent0.pref_height = 100
  parent0.gap = 10
  parent0.children = [make_box(101, 80, 50), make_box(102, 80, 50), make_box(103, 80, 50)]
  s0 = flexbox_solve_tree(parent0, 500, 100)
  assert_eq_int(state, s0.children[0].x, 0, "F10.1.1", "JUSTIFY_START: child 0 at x=0")
  assert_eq_int(state, s0.children[1].x, 90, "F10.1.2", "JUSTIFY_START: child 1 at x=90 (80+10)")
  assert_eq_int(state, s0.children[2].x, 180, "F10.1.3", "JUSTIFY_START: child 2 at x=180 (90+80+10)")

  @! 1.2 JUSTIFY_CENTER (Mode 1): Container 500px, content = 80*3 + 20 = 260px. Remainder = 240px. Offset = 120px.
  parent1 = layout_node_new(110, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_CENTER())
  parent1.pref_width = 500
  parent1.pref_height = 100
  parent1.gap = 10
  parent1.children = [make_box(111, 80, 50), make_box(112, 80, 50), make_box(113, 80, 50)]
  s1 = flexbox_solve_tree(parent1, 500, 100)
  assert_eq_int(state, s1.children[0].x, 120, "F10.1.4", "JUSTIFY_CENTER: child 0 at x=120")
  assert_eq_int(state, s1.children[1].x, 210, "F10.1.5", "JUSTIFY_CENTER: child 1 at x=210")
  assert_eq_int(state, s1.children[2].x, 300, "F10.1.6", "JUSTIFY_CENTER: child 2 at x=300")

  @! 1.3 JUSTIFY_END (Mode 2): Container 500px, content = 260px. Remainder = 240px. Offset = 240px.
  parent2 = layout_node_new(120, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_END())
  parent2.pref_width = 500
  parent2.pref_height = 100
  parent2.gap = 10
  parent2.children = [make_box(121, 80, 50), make_box(122, 80, 50), make_box(123, 80, 50)]
  s2 = flexbox_solve_tree(parent2, 500, 100)
  assert_eq_int(state, s2.children[0].x, 240, "F10.1.7", "JUSTIFY_END: child 0 at x=240")
  assert_eq_int(state, s2.children[1].x, 330, "F10.1.8", "JUSTIFY_END: child 1 at x=330")
  assert_eq_int(state, s2.children[2].x, 420, "F10.1.9", "JUSTIFY_END: child 2 at x=420 (last ends at 420+80=500)")

  @! 1.4 JUSTIFY_SPACE_BETWEEN (Mode 3) with Odd Non-Divisible Remainder:
  @! Container 503px, 3 items of 100px with gap=0. fixed_w = 300px. rem_w = 203px across 2 intervals (k=2).
  @! eff_gap = 203 / 2 = 101, gap_rem = 203 % 2 = 1.
  @! Interval 0 = 101 + 1 = 102px. Interval 1 = 101px.
  @! Positions: ch0 = 0, ch1 = 0 + 100 + 102 = 202, ch2 = 202 + 100 + 101 = 403. Last ends at 403 + 100 = 503!
  parent3 = layout_node_new(130, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_SPACE_BETWEEN())
  parent3.pref_width = 503
  parent3.pref_height = 100
  parent3.gap = 0
  parent3.children = [make_box(131, 100, 50), make_box(132, 100, 50), make_box(133, 100, 50)]
  s3 = flexbox_solve_tree(parent3, 503, 100)
  assert_eq_int(state, s3.children[0].x, 0, "F10.1.10", "SPACE_BETWEEN: ch0 at x=0")
  assert_eq_int(state, s3.children[1].x, 202, "F10.1.11", "SPACE_BETWEEN: ch1 at x=202 (102px gap)")
  assert_eq_int(state, s3.children[2].x, 403, "F10.1.12", "SPACE_BETWEEN: ch2 at x=403 (101px gap)")
  assert_eq_int(state, s3.children[2].x + s3.children[2].width, 503, "F10.1.13", "SPACE_BETWEEN: right edge perfectly hits container 503px")

  @! 1.5 JUSTIFY_SPACE_AROUND (Mode 4):
  @! Container 500px, 2 items of 100px with gap=0. fixed_w = 200px. rem_w = 300px. k = 2.
  @! half_unit = 300 / 4 = 75px. start_x = 75px. eff_gap = 2 * 75 = 150px.
  @! ch0 at 75, ch1 at 75 + 100 + 150 = 325. ch1 right edge = 325 + 100 = 425 (leaving 75px at end = 500).
  parent4 = layout_node_new(140, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_SPACE_AROUND())
  parent4.pref_width = 500
  parent4.pref_height = 100
  parent4.gap = 0
  parent4.children = [make_box(141, 100, 50), make_box(142, 100, 50)]
  s4 = flexbox_solve_tree(parent4, 500, 100)
  assert_eq_int(state, s4.children[0].x, 75, "F10.1.14", "SPACE_AROUND: ch0 at x=75")
  assert_eq_int(state, s4.children[1].x, 325, "F10.1.15", "SPACE_AROUND: ch1 at x=325")

  @! 1.6 JUSTIFY_SPACE_EVENLY (Mode 5):
  @! Container 500px, 3 items of 80px with gap=0. fixed_w = 240px. rem_w = 260px. k = 4 (3+1).
  @! unit = 260 / 4 = 65px. gap_rem = 260 % 4 = 0.
  @! start_x = 65. ch0 at 65, ch1 at 65 + 80 + 65 = 210, ch2 at 210 + 80 + 65 = 355.
  @! ch2 right edge = 355 + 80 = 435. Remaining trailing space = 500 - 435 = 65px!
  parent5 = layout_node_new(150, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_SPACE_EVENLY())
  parent5.pref_width = 500
  parent5.pref_height = 100
  parent5.gap = 0
  parent5.children = [make_box(151, 80, 50), make_box(152, 80, 50), make_box(153, 80, 50)]
  s5 = flexbox_solve_tree(parent5, 500, 100)
  assert_eq_int(state, s5.children[0].x, 65, "F10.1.16", "SPACE_EVENLY: ch0 at x=65")
  assert_eq_int(state, s5.children[1].x, 210, "F10.1.17", "SPACE_EVENLY: ch1 at x=210")
  assert_eq_int(state, s5.children[2].x, 355, "F10.1.18", "SPACE_EVENLY: ch2 at x=355")
  assert_eq_int(state, 500 - (s5.children[2].x + s5.children[2].width), 65, "F10.1.19", "SPACE_EVENLY: trailing margin = 65px")

  @! ==========================================================================
  @! SECTION 2: Dynamic Flex Grow & Shrink with Conservation & Clamping
  @! ==========================================================================
  println("\n--- Section 2: Flex Grow & Shrink Clamping ---")

  @! 2.1 Flex Grow with weighted proportions (1 : 2 : 3)
  @! Container 600px, 3 items of initial 100px (fixed_w = 300), free space = 300px.
  @! ch0 (grow=1) gets (300*1)/6 = 50 -> 150px.
  @! ch1 (grow=2) gets (250*2)/5 = 100 -> 200px.
  @! ch2 (grow=3) gets (150*3)/3 = 150 -> 250px.
  parent_grow = layout_node_new(200, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  parent_grow.pref_width = 600
  parent_grow.pref_height = 100
  g0 = make_box(201, 100, 50)
  g0.flex_grow = 1
  g1 = make_box(202, 100, 50)
  g1.flex_grow = 2
  g2 = make_box(203, 100, 50)
  g2.flex_grow = 3
  parent_grow.children = [g0, g1, g2]
  sg = flexbox_solve_tree(parent_grow, 600, 100)
  assert_eq_int(state, sg.children[0].width, 150, "F10.2.1", "Flex grow ratio 1: width 150")
  assert_eq_int(state, sg.children[1].width, 200, "F10.2.2", "Flex grow ratio 2: width 200")
  assert_eq_int(state, sg.children[2].width, 250, "F10.2.3", "Flex grow ratio 3: width 250")
  assert_eq_int(state, sg.children[0].width + sg.children[1].width + sg.children[2].width, 600, "F10.2.4", "Flex grow exact 600px space conservation")

  @! 2.2 Flex Shrink with Deficit Proportions (1 : 3)
  @! Container 200px, 2 items of initial 150px (fixed_w = 300), deficit = 100px.
  @! ch0 (shrink=1) loses (100*1)/4 = 25 -> 125px.
  @! ch1 (shrink=3) loses (75*3)/3 = 75 -> 75px.
  parent_shrink = layout_node_new(210, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  parent_shrink.pref_width = 200
  parent_shrink.pref_height = 100
  sk0 = make_box(211, 150, 50)
  sk0.flex_shrink = 1
  sk1 = make_box(212, 150, 50)
  sk1.flex_shrink = 3
  parent_shrink.children = [sk0, sk1]
  ssk = flexbox_solve_tree(parent_shrink, 200, 100)
  assert_eq_int(state, ssk.children[0].width, 125, "F10.2.5", "Flex shrink ratio 1: width 125")
  assert_eq_int(state, ssk.children[1].width, 75, "F10.2.6", "Flex shrink ratio 3: width 75")
  assert_eq_int(state, ssk.children[0].width + ssk.children[1].width, 200, "F10.2.7", "Flex shrink exact 200px space conservation")

  @! 2.3 Max-Width Clamping during Flex Grow
  parent_clamp = layout_node_new(220, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  parent_clamp.pref_width = 600
  parent_clamp.pref_height = 100
  cg0 = make_box(221, 100, 50)
  cg0.flex_grow = 1
  cg0.max_width = 120 @! clamped below theoretical 250
  cg1 = make_box(222, 100, 50)
  cg1.flex_grow = 1
  parent_clamp.children = [cg0, cg1]
  scg = flexbox_solve_tree(parent_clamp, 600, 100)
  assert_eq_int(state, scg.children[0].width, 120, "F10.2.8", "Flex grow clamped to max_width = 120")

  @! ==========================================================================
  @! SECTION 3: Cross-Axis Alignment & Per-Child Align-Self
  @! ==========================================================================
  println("\n--- Section 3: Cross-Axis Alignment & Align-Self ---")

  parent_align = layout_node_new(300, LAYOUT_FLEX_ROW(), ALIGN_CENTER(), JUSTIFY_START())
  parent_align.pref_width = 400
  parent_align.pref_height = 200
  
  a_def = make_box(301, 80, 60) @! Inherits ALIGN_CENTER: y = (200 - 60)/2 = 70
  a_start = make_box(302, 80, 60)
  a_start.align_self = ALIGN_SELF_START() @! y = 0
  a_end = make_box(303, 80, 60)
  a_end.align_self = ALIGN_SELF_END() @! y = 200 - 60 = 140
  a_stretch = make_box(304, 80, 60)
  a_stretch.align_self = ALIGN_SELF_STRETCH() @! height stretched to 200
  
  parent_align.children = [a_def, a_start, a_end, a_stretch]
  sa = flexbox_solve_tree(parent_align, 400, 200)
  
  assert_eq_int(state, sa.children[0].y, 70, "F10.3.1", "Default ALIGN_CENTER y = 70")
  assert_eq_int(state, sa.children[1].y, 0, "F10.3.2", "ALIGN_SELF_START y = 0")
  assert_eq_int(state, sa.children[2].y, 140, "F10.3.3", "ALIGN_SELF_END y = 140")
  assert_eq_int(state, sa.children[3].height, 200, "F10.3.4", "ALIGN_SELF_STRETCH height = 200")

  @! ==========================================================================
  @! SECTION 4: Multi-Line Flex Wrapping (Row & Reverse)
  @! ==========================================================================
  println("\n--- Section 4: Multi-Line Flex Wrapping ---")

  @! Container 300px, 4 items of 120px with gap 10px -> 2 items per line
  parent_wrap = layout_node_new(400, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  parent_wrap.pref_width = 300
  parent_wrap.pref_height = 200
  parent_wrap.flex_wrap = WRAP_WRAP()
  parent_wrap.gap = 10
  parent_wrap.children = [make_box(401, 120, 40), make_box(402, 120, 40), make_box(403, 120, 40), make_box(404, 120, 40)]
  
  sw = flexbox_solve_tree(parent_wrap, 300, 200)
  assert_eq_int(state, sw.children[0].x, 0, "F10.4.1", "Line 0 item 0 at x=0")
  assert_eq_int(state, sw.children[0].y, 0, "F10.4.2", "Line 0 item 0 at y=0")
  assert_eq_int(state, sw.children[1].x, 130, "F10.4.3", "Line 0 item 1 at x=130")
  assert_eq_int(state, sw.children[2].x, 0, "F10.4.4", "Line 1 item 0 wrapped to x=0")
  assert_eq_int(state, sw.children[2].y, 50, "F10.4.5", "Line 1 item 0 at y=50 (40+10)")
  assert_eq_int(state, sw.children[3].x, 130, "F10.4.6", "Line 1 item 1 wrapped to x=130")

  @! ==========================================================================
  @! SECTION 5: Grid Layout Solver & Column Spanning
  @! ==========================================================================
  println("\n--- Section 5: Grid Layout Solver & Column Spans ---")

  @! Grid Container 410px, 3 columns, gap 10px.
  @! Content = 410, total gaps = 20. col_w = (410 - 20) / 3 = 130px.
  parent_grid = layout_node_new(500, LAYOUT_GRID(), ALIGN_START(), JUSTIFY_START())
  parent_grid.pref_width = 410
  parent_grid.pref_height = 300
  parent_grid.grid_columns = 3
  parent_grid.gap = 10
  
  g_item0 = make_box(501, 0, 50)
  g_item1 = make_box(502, 0, 50)
  g_item2 = make_box(503, 0, 50)
  g_item3 = make_box(504, 0, 50)
  g_item3.grid_col_span = 2 @! spans 2 columns = 2*130 + 10 = 270px
  
  parent_grid.children = [g_item0, g_item1, g_item2, g_item3]
  sgrid = flexbox_solve_tree(parent_grid, 410, 300)
  
  assert_eq_int(state, sgrid.children[0].width, 130, "F10.5.1", "Grid item 0 width = 130 (1 column)")
  assert_eq_int(state, sgrid.children[0].x, 0, "F10.5.2", "Grid item 0 at col 0 (x=0)")
  assert_eq_int(state, sgrid.children[1].x, 140, "F10.5.3", "Grid item 1 at col 1 (x=140)")
  assert_eq_int(state, sgrid.children[2].x, 280, "F10.5.4", "Grid item 2 at col 2 (x=280)")
  assert_eq_int(state, sgrid.children[3].x, 0, "F10.5.5", "Grid item 3 (row 1, col 0) at x=0")
  assert_eq_int(state, sgrid.children[3].width, 270, "F10.5.6", "Grid item 3 (span=2) width = 270px (130*2+10)")

  @! ==========================================================================
  @! SECTION 6: Absolute Positioning Bounds & Edge Bounds
  @! ==========================================================================
  println("\n--- Section 6: Absolute Positioning & Boundary Edge Cases ---")

  parent_abs = layout_node_new(600, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  parent_abs.pref_width = 500
  parent_abs.pref_height = 300
  parent_abs.padding = edge_insets_all(20)
  
  abs_item = make_box(601, 100, 80)
  abs_item.position_type = POSITION_ABSOLUTE()
  abs_item.has_pos_right = true
  abs_item.pos_right = 15
  abs_item.has_pos_bottom = true
  abs_item.pos_bottom = 25
  
  normal_item = make_box(602, 120, 50)
  
  parent_abs.children = [normal_item, abs_item]
  sabs = flexbox_solve_tree(parent_abs, 500, 300)
  
  @! Normal item sits at padding box (20, 20)
  assert_eq_int(state, sabs.children[0].x, 20, "F10.6.1", "Normal child at x=20")
  assert_eq_int(state, sabs.children[0].y, 20, "F10.6.2", "Normal child at y=20")
  
  @! Absolute item: x = (0 + 500) - (20 + 100 + 15) = 365
  @! y = (0 + 300) - (20 + 80 + 25) = 175
  assert_eq_int(state, sabs.children[1].x, 365, "F10.6.3", "Absolute item x anchored to right bounds = 365")
  assert_eq_int(state, sabs.children[1].y, 175, "F10.6.4", "Absolute item y anchored to bottom bounds = 175")

  @! 6.2 Zero & Extreme Dimension Boundaries
  zero_parent = layout_node_new(610, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  zero_parent.pref_width = 0
  zero_parent.pref_height = 0
  szero = flexbox_solve_tree(zero_parent, 0, 0)
  assert_eq_int(state, szero.width, 0, "F10.6.5", "0x0 container safely solved")
  assert_eq_int(state, szero.height, 0, "F10.6.6", "0x0 container height is 0")

  println("=================================================================")
  println("Adversarial F10 Test Results: " + int_to_str(state.passed) + "/" + int_to_str(state.total) + " passed, " + int_to_str(state.failed) + " failed.")
  @if state.failed == 0
    println("Verdict: FEATURE F10 RESILIENT & FULLY VERIFIED")
  @else
    println("Verdict: FAILURES DETECTED IN FEATURE F10")
  @end
  println("=================================================================")
@end
