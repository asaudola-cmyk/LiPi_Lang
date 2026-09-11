@! ============================================================================
@! MAYA TIER 1 E2E TEST SUITE — FEATURE F10: FLEXBOX LAYOUT ENGINE
@! Module: tests/e2e/tier1_features/web/test_f10_flexbox.maya
@! 100% Pure Maya Language — Zero External Dependencies
@! Coverage:
@! 1. Row Flex Grow Proportional Distribution
@! 2. Column Justify Content Space-Between & Center
@! 3. Cross-Axis Alignment (Center, Stretch, Start, End)
@! 4. Padding, Margin & Gap Bounding Box Computation
@! 5. Multi-line Wrapping (WRAP_WRAP)
@! 6. Grid Layout Solver
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/tools/maya_test"
import "universe/web/frontend/layout/layout_types"
import "universe/web/frontend/layout/flexbox_solver"

@! ----------------------------------------------------------------------------
@! TEST 1: Row Flex Grow Proportional Distribution
@! ----------------------------------------------------------------------------
@fn test_f10_01_row_flex_grow()
  @! Container: Row 600px width, 200px height, 0 padding, 0 gap
  root = layout_node_new(1, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  root = layout_node_set_size(root, 600, 200)
  
  @! Child 1: flex_grow = 1 -> 100px (1/6 of 600)
  c1 = layout_node_new(2, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  c1 = layout_node_set_flex(c1, 1, 1)
  c1.pref_height = 200
  root = layout_node_add_child(root, c1)
  
  @! Child 2: flex_grow = 2 -> 200px (2/6 of 600)
  c2 = layout_node_new(3, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  c2 = layout_node_set_flex(c2, 2, 1)
  c2.pref_height = 200
  root = layout_node_add_child(root, c2)
  
  @! Child 3: flex_grow = 3 -> 300px (3/6 of 600)
  c3 = layout_node_new(4, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  c3 = layout_node_set_flex(c3, 3, 1)
  c3.pref_height = 200
  root = layout_node_add_child(root, c3)
  
  solved = flexbox_solve_tree(root, 600, 200)
  
  res_c1 = solved.children[0]
  res_c2 = solved.children[1]
  res_c3 = solved.children[2]
  
  assert_eq(res_c1.width, 100, "Child 1 (flex_grow:1) width is 100")
  assert_eq(res_c1.x, 0, "Child 1 x offset is 0")
  
  assert_eq(res_c2.width, 200, "Child 2 (flex_grow:2) width is 200")
  assert_eq(res_c2.x, 100, "Child 2 x offset is 100")
  
  assert_eq(res_c3.width, 300, "Child 3 (flex_grow:3) width is 300")
  assert_eq(res_c3.x, 300, "Child 3 x offset is 300")
  
  total_w = res_c1.width + res_c2.width + res_c3.width
  assert_eq(total_w, 600, "Total child widths conserve container width (600px)")
  
  println("  [PASS] T1_F10_01: Row Flex Grow Proportional Distribution")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 2: Column Justify Content Space-Between & Center
@! ----------------------------------------------------------------------------
@fn test_f10_02_column_justify_space_between()
  @! Container: Column 300px width, 500px height, justify = SPACE_BETWEEN
  root = layout_node_new(1, LAYOUT_FLEX_COLUMN(), ALIGN_START(), JUSTIFY_SPACE_BETWEEN())
  root = layout_node_set_size(root, 300, 500)
  
  @! 3 items of 50px height each -> total item height = 150px
  @! Remaining space = 500 - 150 = 350px. 2 gaps of 175px each
  c1 = layout_node_new(2, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  c1 = layout_node_set_size(c1, 300, 500)
  c1.pref_height = 50
  root = layout_node_add_child(root, c1)
  
  c2 = layout_node_new(3, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  c2 = layout_node_set_size(c2, 300, 500)
  c2.pref_height = 50
  root = layout_node_add_child(root, c2)
  
  c3 = layout_node_new(4, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  c3 = layout_node_set_size(c3, 300, 500)
  c3.pref_height = 50
  root = layout_node_add_child(root, c3)
  
  solved = flexbox_solve_tree(root, 300, 500)
  
  res_c1 = solved.children[0]
  res_c2 = solved.children[1]
  res_c3 = solved.children[2]
  
  assert_eq(res_c1.y, 0, "First item positioned at top (y=0)")
  assert_eq(res_c1.height, 50, "First item height is 50")
  
  assert_eq(res_c2.y, 225, "Second item positioned at y = 0 + 50 + 175 = 225")
  assert_eq(res_c2.height, 50, "Second item height is 50")
  
  assert_eq(res_c3.y, 450, "Third item positioned at y = 225 + 50 + 175 = 450")
  assert_eq(res_c3.height, 50, "Third item height is 50")
  
  println("  [PASS] T1_F10_02: Column Justify Content Space-Between")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 3: Cross-Axis Alignment (Center, Stretch, Start, End)
@! ----------------------------------------------------------------------------
@fn test_f10_03_cross_alignment()
  @! Container: Row 400px width, 200px height, align_items = START
  root = layout_node_new(1, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  root = layout_node_set_size(root, 400, 200)
  
  @! Item A: align_self = START, height = 40
  item_a = layout_node_new(2, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  item_a.align_self = ALIGN_SELF_START()
  item_a.pref_width = 80
  item_a.pref_height = 40
  root = layout_node_add_child(root, item_a)
  
  @! Item B: align_self = CENTER, height = 60 -> y = (200 - 60) / 2 = 70
  item_b = layout_node_new(3, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  item_b.align_self = ALIGN_SELF_CENTER()
  item_b.pref_width = 80
  item_b.pref_height = 60
  root = layout_node_add_child(root, item_b)
  
  @! Item C: align_self = END, height = 50 -> y = 200 - 50 = 150
  item_c = layout_node_new(4, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  item_c.align_self = ALIGN_SELF_END()
  item_c.pref_width = 80
  item_c.pref_height = 50
  root = layout_node_add_child(root, item_c)
  
  @! Item D: align_self = STRETCH, pref_height = 0 -> height = 200, y = 0
  item_d = layout_node_new(5, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  item_d.align_self = ALIGN_SELF_STRETCH()
  item_d.pref_width = 80
  item_d.pref_height = 0
  root = layout_node_add_child(root, item_d)
  
  solved = flexbox_solve_tree(root, 400, 200)
  
  res_a = solved.children[0]
  res_b = solved.children[1]
  res_c = solved.children[2]
  res_d = solved.children[3]
  
  assert_eq(res_a.y, 0, "Item A (ALIGN_START) y offset is 0")
  assert_eq(res_a.height, 40, "Item A height is 40")
  
  assert_eq(res_b.y, 70, "Item B (ALIGN_CENTER) y offset is (200 - 60) / 2 = 70")
  assert_eq(res_b.height, 60, "Item B height is 60")
  
  assert_eq(res_c.y, 150, "Item C (ALIGN_END) y offset is 200 - 50 = 150")
  assert_eq(res_c.height, 50, "Item C height is 50")
  
  assert_eq(res_d.y, 0, "Item D (ALIGN_STRETCH) y offset is 0")
  assert_eq(res_d.height, 200, "Item D stretched to container height (200)")
  
  println("  [PASS] T1_F10_03: Cross-Axis Alignment (Center, Stretch, Start, End)")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 4: Padding, Margin & Gap Bounding Box Computation
@! ----------------------------------------------------------------------------
@fn test_f10_04_padding_margin_gap()
  @! Container: Row 500px width, 300px height
  @! Padding: 20px all sides -> Content width = 500 - 40 = 460px
  @! Gap: 10px
  root = layout_node_new(1, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  root = layout_node_set_size(root, 500, 300)
  root = layout_node_set_padding(root, 20, 20, 20, 20)
  root = layout_node_set_gap(root, 10)
  
  @! Two children with flex_grow: 1
  @! Available for 2 children = 460 - 10 (gap) = 450px -> each child is 225px
  c1 = layout_node_new(2, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  c1 = layout_node_set_flex(c1, 1, 1)
  c1.pref_height = 100
  root = layout_node_add_child(root, c1)
  
  c2 = layout_node_new(3, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  c2 = layout_node_set_flex(c2, 1, 1)
  c2.pref_height = 100
  root = layout_node_add_child(root, c2)
  
  solved = flexbox_solve_tree(root, 500, 300)
  
  res_c1 = solved.children[0]
  res_c2 = solved.children[1]
  
  @! Child 1 starts at padding.left (20)
  assert_eq(res_c1.x, 20, "Child 1 x offset = padding.left (20)")
  assert_eq(res_c1.y, 20, "Child 1 y offset = padding.top (20)")
  assert_eq(res_c1.width, 225, "Child 1 width = (460 - 10) / 2 = 225")
  
  @! Child 2 starts at 20 + 225 + 10 (gap) = 255
  assert_eq(res_c2.x, 255, "Child 2 x offset = 20 + 225 + 10 = 255")
  assert_eq(res_c2.y, 20, "Child 2 y offset = padding.top (20)")
  assert_eq(res_c2.width, 225, "Child 2 width = 225")
  
  println("  [PASS] T1_F10_04: Padding, Margin & Gap Bounding Box Computation")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 5: Multi-line Flex Wrapping (WRAP_WRAP)
@! ----------------------------------------------------------------------------
@fn test_f10_05_multiline_wrap()
  @! Container: Row 300px width, 200px height, flex_wrap = WRAP_WRAP, gap = 10
  root = layout_node_new(1, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
  root = layout_node_set_size(root, 300, 200)
  root.flex_wrap = WRAP_WRAP()
  root = layout_node_set_gap(root, 10)
  
  @! 4 items each of 120px width and 40px height
  @! Row 1: Item 1 (120) + gap (10) + Item 2 (120) = 250px <= 300px (fits)
  @! Row 2: Item 3 (120) + gap (10) + Item 4 (120) = 250px <= 300px (wraps to next line)
  i = 0
  @while i < 4
    item = layout_node_new(i + 2, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
    item.pref_width = 120
    item.pref_height = 40
    root = layout_node_add_child(root, item)
    i = i + 1
  @end
  
  solved = flexbox_solve_tree(root, 300, 200)
  
  res1 = solved.children[0]
  res2 = solved.children[1]
  res3 = solved.children[2]
  res4 = solved.children[3]
  
  @! Line 1:
  assert_eq(res1.x, 0, "Item 1 at (0, 0)")
  assert_eq(res1.y, 0, "Item 1 at (0, 0)")
  assert_eq(res2.x, 130, "Item 2 at (130, 0)")
  assert_eq(res2.y, 0, "Item 2 at (130, 0)")
  
  @! Line 2 (wrapped below line 1 height 40 + row_gap 10 = 50):
  assert_eq(res3.x, 0, "Item 3 wrapped to (0, 50)")
  assert_eq(res3.y, 50, "Item 3 y offset = 50")
  assert_eq(res4.x, 130, "Item 4 wrapped to (130, 50)")
  assert_eq(res4.y, 50, "Item 4 y offset = 50")
  
  println("  [PASS] T1_F10_05: Multi-line Flex Wrapping (WRAP_WRAP)")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 6: Grid Layout Solver
@! ----------------------------------------------------------------------------
@fn test_f10_06_grid_layout()
  @! Container: Grid with 2 columns, width 400px, height 300px, gap 20px
  root = layout_node_new(1, LAYOUT_GRID(), ALIGN_START(), JUSTIFY_START())
  root = layout_node_set_size(root, 400, 300)
  root.grid_columns = 2
  root = layout_node_set_gap(root, 20)
  
  @! 4 grid items: cell_width = (400 - 20) / 2 = 190px
  i = 0
  @while i < 4
    item = layout_node_new(i + 2, LAYOUT_FLEX_ROW(), ALIGN_START(), JUSTIFY_START())
    item.pref_height = 60
    root = layout_node_add_child(root, item)
    i = i + 1
  @end
  
  solved = flexbox_solve_tree(root, 400, 300)
  
  g0 = solved.children[0]
  g1 = solved.children[1]
  g2 = solved.children[2]
  g3 = solved.children[3]
  
  @! Col 0, Row 0
  assert_eq(g0.x, 0, "Grid (0,0) x is 0")
  assert_eq(g0.y, 0, "Grid (0,0) y is 0")
  assert_eq(g0.width, 190, "Grid cell width is 190")
  
  @! Col 1, Row 0
  assert_eq(g1.x, 210, "Grid (1,0) x is 190 + 20 = 210")
  assert_eq(g1.y, 0, "Grid (1,0) y is 0")
  assert_eq(g1.width, 190, "Grid cell width is 190")
  
  @! Col 0, Row 1 (y = 60 + 20 = 80)
  assert_eq(g2.x, 0, "Grid (0,1) x is 0")
  assert_eq(g2.y, 80, "Grid (0,1) y is 80")
  
  @! Col 1, Row 1
  assert_eq(g3.x, 210, "Grid (1,1) x is 210")
  assert_eq(g3.y, 80, "Grid (1,1) y is 80")
  
  println("  [PASS] T1_F10_06: Grid Layout Solver (2-Column 2x2 Matrix)")
  return 1
@end

@! ----------------------------------------------------------------------------
@! Runner Function
@! ----------------------------------------------------------------------------
@fn run_f10_flexbox_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F10: Flexbox Layout Engine Suite")
  println("=================================================================")
  
  passed = 0
  passed = passed + test_f10_01_row_flex_grow()
  passed = passed + test_f10_02_column_justify_space_between()
  passed = passed + test_f10_03_cross_alignment()
  passed = passed + test_f10_04_padding_margin_gap()
  passed = passed + test_f10_05_multiline_wrap()
  passed = passed + test_f10_06_grid_layout()
  
  println("-----------------------------------------------------------------")
  println("Feature F10 Results: " + passed.to_str() + "/6 tests passed.")
  assert_eq(passed, 6, "All F10 tests must pass")
  return passed
@end

@fn main()
  run_f10_flexbox_tests()
@end
