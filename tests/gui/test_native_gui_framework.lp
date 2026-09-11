@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — NATIVE GUI FRAMEWORK COMPREHENSIVE TEST SUITE
@! File: tests/gui/test_native_gui_framework.maya
@! Milestone: M1 / E2E Track (Native Desktop GUI Framework)
@! 100% Pure Maya Implementation (@struct, @fn) — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/gui/canvas"
import "universe/gui/font"
import "universe/gui/layout"
import "universe/gui/event"
import "universe/gui/widget"
import "universe/gui/compositor"

@! ============================================================================
@! 1. ASSERTION FRAMEWORK HELPERS
@! ============================================================================

@fn assert_true(cond, msg)
  @if cond == 0
    println("  [FAIL] Assertion failed (expected true): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_false(cond, msg)
  @if cond != 0
    println("  [FAIL] Assertion failed (expected false): " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
  return 1
@end

@fn assert_neq_int(actual, unexpected, msg)
  @if actual == unexpected
    println("  [FAIL] " + msg + " -> Expected value not to equal " + unexpected.to_str())
    return 0
  @end
  return 1
@end

@! ============================================================================
@! 2. TEST SUITE RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🎨 MAYA UNIVERSAL NATIVE GUI FRAMEWORK COMPREHENSIVE TEST SUITE 🎨")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! SECTION 1: Canvas & Pixel Buffer Software Rasterizer
  @! ----------------------------------------------------------------------------
  println("▶ Section 1: Canvas Allocation, Pixel Buffer & Bounds Safety...")
  
  c = canvas_new(400, 300)
  total_tests = total_tests + 1
  ok1 = assert_eq_int(c.width, 400, "Canvas width is 400")
  ok2 = assert_eq_int(c.height, 300, "Canvas height is 300")
  ok3 = assert_eq_int(c.pitch, 1600, "Canvas pitch is 1600 bytes (400 * 4)")
  ok4 = assert_eq_int(c.pixels.len(), 120000, "Canvas allocated 120,000 pixels")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Canvas 400x300 buffer allocation & structure verified")
  @end

  total_tests = total_tests + 1
  c = canvas_set_pixel(c, 50, 50, 0xFF00FF00)
  p1 = canvas_get_pixel(c, 50, 50)
  ok1 = assert_eq_int(p1, 0xFF00FF00, "Pixel write and read at (50, 50)")
  c = canvas_set_pixel(c, -10, 50, 0xFFFF0000)
  p_neg = canvas_get_pixel(c, -10, 50)
  ok2 = assert_eq_int(p_neg, 0, "Out-of-bounds negative X read returns 0 safely")
  c = canvas_set_pixel(c, 450, 50, 0xFFFF0000)
  p_oob = canvas_get_pixel(c, 450, 50)
  ok3 = assert_eq_int(p_oob, 0, "Out-of-bounds positive X read returns 0 safely")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Pixel read/write & memory boundary clamp safety verified")
  @end

  total_tests = total_tests + 1
  c = canvas_clear(c, 0xFF1E1E1E)
  c_p0 = canvas_get_pixel(c, 0, 0)
  c_p1 = canvas_get_pixel(c, 399, 299)
  c_p2 = canvas_get_pixel(c, 200, 150)
  ok1 = assert_eq_int(c_p0, 0xFF1E1E1E, "Canvas clear at (0,0)")
  ok2 = assert_eq_int(c_p1, 0xFF1E1E1E, "Canvas clear at (399,299)")
  ok3 = assert_eq_int(c_p2, 0xFF1E1E1E, "Canvas clear at (200,150)")
  ok4 = assert_eq_int(c.has_dirty, 1, "Clear marks canvas dirty")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Canvas clear color fill & dirty flag verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 2: 2D Geometry Drawing Primitives
  @! ----------------------------------------------------------------------------
  println("▶ Section 2: 2D Drawing Primitives (Bresenham Lines, Rects, Circles)...")

  total_tests = total_tests + 1
  c = canvas_clear(c, 0)
  c = canvas_draw_line(c, 10, 20, 30, 20, 0xFFFF0000) @! Horizontal line
  p_h1 = canvas_get_pixel(c, 10, 20)
  p_h2 = canvas_get_pixel(c, 20, 20)
  p_h3 = canvas_get_pixel(c, 30, 20)
  p_h_off = canvas_get_pixel(c, 20, 21)
  ok1 = assert_eq_int(p_h1, 0xFFFF0000, "Line start pixel (10,20)")
  ok2 = assert_eq_int(p_h2, 0xFFFF0000, "Line mid pixel (20,20)")
  ok3 = assert_eq_int(p_h3, 0xFFFF0000, "Line end pixel (30,20)")
  ok4 = assert_eq_int(p_h_off, 0, "Line adjacent pixel off line is 0")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Horizontal Bresenham line rasterization verified")
  @end

  total_tests = total_tests + 1
  c = canvas_draw_line(c, 0, 0, 10, 10, 0xFF0000FF) @! Diagonal line
  p_d0 = canvas_get_pixel(c, 0, 0)
  p_d5 = canvas_get_pixel(c, 5, 5)
  p_d10 = canvas_get_pixel(c, 10, 10)
  ok1 = assert_eq_int(p_d0, 0xFF0000FF, "Diagonal start (0,0)")
  ok2 = assert_eq_int(p_d5, 0xFF0000FF, "Diagonal mid (5,5)")
  ok3 = assert_eq_int(p_d10, 0xFF0000FF, "Diagonal end (10,10)")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Diagonal 45-degree Bresenham line rasterization verified")
  @end

  total_tests = total_tests + 1
  c = canvas_draw_rect(c, 100, 100, 50, 30, 0xFFFFFF00)
  p_tl = canvas_get_pixel(c, 100, 100)
  p_tr = canvas_get_pixel(c, 149, 100)
  p_bl = canvas_get_pixel(c, 100, 129)
  p_br = canvas_get_pixel(c, 149, 129)
  p_inside = canvas_get_pixel(c, 125, 115)
  ok1 = assert_eq_int(p_tl, 0xFFFFFF00, "Rect top-left corner")
  ok2 = assert_eq_int(p_tr, 0xFFFFFF00, "Rect top-right corner")
  ok3 = assert_eq_int(p_bl, 0xFFFFFF00, "Rect bottom-left corner")
  ok4 = assert_eq_int(p_br, 0xFFFFFF00, "Rect bottom-right corner")
  ok5 = assert_eq_int(p_inside, 0, "Rect interior hollow")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Hollow rectangle outline rasterization verified")
  @end

  total_tests = total_tests + 1
  c = canvas_fill_rect(c, 100, 100, 50, 30, 0xFF00FFFF)
  p_filled_in = canvas_get_pixel(c, 125, 115)
  ok1 = assert_eq_int(p_filled_in, 0xFF00FFFF, "Filled rect interior colored")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Filled rectangle solid area rasterization verified")
  @end

  total_tests = total_tests + 1
  c = canvas_draw_circle(c, 200, 150, 20, 0xFFFF00FF)
  p_c_r = canvas_get_pixel(c, 220, 150)
  p_c_l = canvas_get_pixel(c, 180, 150)
  p_c_t = canvas_get_pixel(c, 200, 130)
  p_c_b = canvas_get_pixel(c, 200, 170)
  p_c_center = canvas_get_pixel(c, 200, 150)
  ok1 = assert_eq_int(p_c_r, 0xFFFF00FF, "Circle right circumference point")
  ok2 = assert_eq_int(p_c_l, 0xFFFF00FF, "Circle left circumference point")
  ok3 = assert_eq_int(p_c_t, 0xFFFF00FF, "Circle top circumference point")
  ok4 = assert_eq_int(p_c_b, 0xFFFF00FF, "Circle bottom circumference point")
  ok5 = assert_eq_int(p_c_center, 0, "Circle center is untouched in outline mode")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Midpoint circle circumference rasterization verified")
  @end

  total_tests = total_tests + 1
  c = canvas_fill_circle(c, 200, 150, 20, 0xFFFF00FF)
  p_c_center_filled = canvas_get_pixel(c, 200, 150)
  ok1 = assert_eq_int(p_c_center_filled, 0xFFFF00FF, "Filled circle center is colored")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Filled circle disk rasterization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 3: ClipRect Stack & Bounding Enforcement
  @! ----------------------------------------------------------------------------
  println("▶ Section 3: ClipRect Stack & Bounding Enforcement...")

  total_tests = total_tests + 1
  c = canvas_clear(c, 0)
  c = canvas_push_clip(c, 50, 50, 100, 100) @! Clip window [50..150, 50..150]
  c = canvas_draw_line(c, 0, 75, 400, 75, 0xFFFFFFFF) @! Horizontal line across canvas
  
  p_outside_left = canvas_get_pixel(c, 25, 75)
  p_inside_clip  = canvas_get_pixel(c, 75, 75)
  p_outside_right= canvas_get_pixel(c, 175, 75)
  
  ok1 = assert_eq_int(p_outside_left, 0, "Pixel outside clip rect left is untouched")
  ok2 = assert_eq_int(p_inside_clip, 0xFFFFFFFF, "Pixel inside clip rect is rendered")
  ok3 = assert_eq_int(p_outside_right, 0, "Pixel outside clip rect right is untouched")
  
  c = canvas_pop_clip(c)
  ok4 = assert_eq_int(c.current_clip.min_x, 0, "Popped clip restores root min_x=0")
  ok5 = assert_eq_int(c.current_clip.max_x, 400, "Popped clip restores root max_x=400")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] ClipRect push/pop & drawing boundary restriction verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 4: Dirty Region Tracking & Bounding Box Merge
  @! ----------------------------------------------------------------------------
  println("▶ Section 4: Dirty Region Tracking & Bounding Box Merge...")

  total_tests = total_tests + 1
  c = canvas_clear_dirty_rects(c)
  c = canvas_add_dirty_rect(c, 10, 20, 30, 40)
  c = canvas_add_dirty_rect(c, 50, 60, 40, 30)
  
  merged_dirty = canvas_merge_dirty_rects(c)
  ok1 = assert_eq_int(merged_dirty.x, 10, "Merged dirty rect min X is 10")
  ok2 = assert_eq_int(merged_dirty.y, 20, "Merged dirty rect min Y is 20")
  ok3 = assert_eq_int(merged_dirty.width, 80, "Merged dirty rect width is 80 (10..90)")
  ok4 = assert_eq_int(merged_dirty.height, 70, "Merged dirty rect height is 70 (20..90)")
  
  c = canvas_clear_dirty_rects(c)
  ok5 = assert_eq_int(c.has_dirty, 0, "Dirty queue cleared, has_dirty is 0")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] DirtyRect queue and minimal bounding box union merge verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 5: Monospace Bitmap Font & Text Typography
  @! ----------------------------------------------------------------------------
  println("▶ Section 5: Monospace Bitmap Font & Text Typography...")

  total_tests = total_tests + 1
  f = font_default()
  m1 = font_measure_text(f, "Maya GUI")
  m_empty = font_measure_text(f, "")
  ok1 = assert_eq_int(m1.width, 64, "8-char string width is 64px (8 * 8)")
  ok2 = assert_eq_int(m1.height, 16, "Font height is 16px")
  ok3 = assert_eq_int(m_empty.width, 0, "Empty string width is 0px")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Font text metrics measurement verified")
  @end

  total_tests = total_tests + 1
  c = canvas_clear(c, 0)
  c = font_draw_text(c, f, 10, 10, "OK", 0xFFFFFFFF)
  p_f0 = canvas_get_pixel(c, 12, 11)
  p_f1 = canvas_get_pixel(c, 20, 11)
  ok1 = assert_eq_int(p_f0, 0xFFFFFFFF, "First glyph stroke pixel rendered at (12, 11)")
  ok2 = assert_eq_int(p_f1, 0xFFFFFFFF, "Second glyph stroke pixel offset rendered at (20, 11)")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Monospace bitmap font text rasterization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 6: Flexbox Layout Engine (Row, Column, Grid Solver)
  @! ----------------------------------------------------------------------------
  println("▶ Section 6: Flexbox Layout Solver (Row, Column, Grid)...")

  total_tests = total_tests + 1
  row_container = widget_container_new("row_cnt", "ROW", 0, 0, 400, 100)
  row_container.padding = 8
  row_container.gap = 10
  btn1 = widget_button_new("b1", "OK", 0, 0, 50, 30, "")
  btn2 = widget_button_new("b2", "Cancel", 0, 0, 60, 30, "")
  btn3 = widget_button_new("b3", "Help", 0, 0, 70, 30, "")
  row_container = widget_add_child(row_container, btn1)
  row_container = widget_add_child(row_container, btn2)
  row_container = widget_add_child(row_container, btn3)
  
  solved_row = layout_solve(row_container, 0, 0, 400, 100)
  c0 = solved_row.children[0]
  c1 = solved_row.children[1]
  c2 = solved_row.children[2]
  
  ok1 = assert_eq_int(c0.x, 8, "Row Child 0 X is origin + pad = 8")
  ok2 = assert_eq_int(c1.x, 68, "Row Child 1 X is 8 + 50 + 10 = 68")
  ok3 = assert_eq_int(c2.x, 138, "Row Child 2 X is 68 + 60 + 10 = 138")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Flexbox Row horizontal sequential layout solver verified")
  @end

  total_tests = total_tests + 1
  col_container = widget_container_new("col_cnt", "COLUMN", 0, 0, 200, 300)
  col_container.padding = 4
  col_container.gap = 6
  item1 = widget_label_new("l1", "Name:", 0, 0, 100, 20)
  item2 = widget_text_input_new("t1", "Enter name", 0, 0, 100, 30, "")
  item3 = widget_button_new("b_sub", "Submit", 0, 0, 100, 40, "")
  col_container = widget_add_child(col_container, item1)
  col_container = widget_add_child(col_container, item2)
  col_container = widget_add_child(col_container, item3)
  
  solved_col = layout_solve(col_container, 0, 0, 200, 300)
  col0 = solved_col.children[0]
  col1 = solved_col.children[1]
  col2 = solved_col.children[2]
  
  ok1 = assert_eq_int(col0.y, 4, "Column Child 0 Y is pad 4 = 4")
  ok2 = assert_eq_int(col1.y, 30, "Column Child 1 Y is 4 + 20 + 6 = 30")
  ok3 = assert_eq_int(col2.y, 66, "Column Child 2 Y is 30 + 30 + 6 = 66")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Flexbox Column vertical sequential layout solver verified")
  @end

  total_tests = total_tests + 1
  grid_container = widget_container_new("grid_cnt", "GRID", 0, 0, 300, 300)
  grid_container.columns = 3
  grid_container.gap = 8
  grid_container.padding = 4
  i = 0
  @while i < 6
    g_wgt = widget_button_new("g_" + i.to_str(), i.to_str(), 0, 0, 40, 40, "")
    grid_container = widget_add_child(grid_container, g_wgt)
    i = i + 1
  @end
  solved_grid = layout_solve(grid_container, 0, 0, 300, 300)
  g0 = solved_grid.children[0]
  g2 = solved_grid.children[2]
  g3 = solved_grid.children[3]
  g5 = solved_grid.children[5]
  
  ok1 = assert_eq_int(g0.x, 4, "Grid Item 0 X is col 0 pad 4 = 4")
  ok2 = assert_eq_int(g0.y, 4, "Grid Item 0 Y is row 0 pad 4 = 4")
  ok3 = assert_eq_int(g2.x, 204, "Grid Item 2 X is col 2 (4 + 2 * (92+8)) = 204")
  ok4 = assert_eq_int(g3.x, 4, "Grid Item 3 X is col 0 = 4")
  ok5 = assert_eq_int(g3.y, 52, "Grid Item 3 Y is row 1 (4 + 48) = 52")
  ok6 = assert_eq_int(g5.x, 204, "Grid Item 5 X is col 2 = 204")
  ok7 = assert_eq_int(g5.y, 52, "Grid Item 5 Y is row 1 = 52")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] 3-Column Grid cell positioning layout engine verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 7: Hit-Testing, Z-Ordering & Focus Management
  @! ----------------------------------------------------------------------------
  println("▶ Section 7: Hit-Testing, Z-Ordering & Focus Management...")

  total_tests = total_tests + 1
  win = widget_window_new("main_win", "App Window", 10, 10, 300, 200)
  btn_a = widget_button_new("btn_a", "A", 20, 30, 80, 40, "on_a")
  btn_b = widget_button_new("btn_b", "B", 120, 30, 80, 40, "on_b")
  win = widget_add_child(win, btn_a)
  win = widget_add_child(win, btn_b)
  
  hit_a = event_hit_test(win, 30, 40)
  hit_b = event_hit_test(win, 130, 40)
  hit_win = event_hit_test(win, 250, 40)
  hit_miss = event_hit_test(win, 5, 5)
  
  ok1 = assert_eq_str(hit_a.id, "btn_a", "Point (30,40) hits Button A")
  ok2 = assert_eq_str(hit_b.id, "btn_b", "Point (130,40) hits Button B")
  ok3 = assert_eq_str(hit_win.id, "main_win", "Point (250,40) hits Parent Window")
  ok4 = assert_true(hit_miss == none || hit_miss == 0, "Point (5,5) misses all widgets")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Recursive point-in-rect hit-testing & reverse z-order verified")
  @end

  total_tests = total_tests + 1
  w_tree = widget_container_new("root", "COLUMN", 0, 0, 400, 400)
  w_tree = widget_add_child(w_tree, widget_button_new("btn_a", "A", 0, 0, 50, 20, ""))
  w_tree = widget_add_child(w_tree, widget_button_new("btn_b", "B", 0, 0, 50, 20, ""))
  w_tree = widget_add_child(w_tree, widget_text_input_new("txt_input", "", 0, 0, 100, 20, ""))
  w_tree = widget_add_child(w_tree, widget_slider_new("slider_1", 0, 100, 50, 0, 0, 100, 20, ""))
  
  fm = focus_manager_new()
  fm = focus_manager_build_chain(fm, w_tree)
  ok1 = assert_eq_str(fm.focused_id, "btn_a", "Initial focus on btn_a")
  fm = focus_manager_tab_next(fm, w_tree)
  ok2 = assert_eq_str(fm.focused_id, "btn_b", "Tab next advances to btn_b")
  fm = focus_manager_tab_next(fm, w_tree)
  ok3 = assert_eq_str(fm.focused_id, "txt_input", "Tab next advances to txt_input")
  fm = focus_manager_tab_prev(fm, w_tree)
  ok4 = assert_eq_str(fm.focused_id, "btn_b", "Tab prev retreats to btn_b")
  fm = focus_manager_tab_prev(fm, w_tree)
  fm = focus_manager_tab_prev(fm, w_tree)
  ok5 = assert_eq_str(fm.focused_id, "slider_1", "Tab prev wraps around to slider_1")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Keyboard focus management & Tab navigation cycle verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 8: Standard Widget Suite Life-Cycle
  @! ----------------------------------------------------------------------------
  println("▶ Section 8: Standard Widget Suite Life-Cycle & Properties...")

  total_tests = total_tests + 1
  w_win = widget_window_new("w0", "Dashboard", 0, 0, 640, 480)
  w_btn = widget_button_new("b0", "Click Me", 10, 10, 100, 30, "do_click")
  w_lbl = widget_label_new("l0", "Status: Ready", 10, 50, 150, 20)
  w_inp = widget_text_input_new("i0", "Type here...", 10, 80, 200, 30, "on_type")
  w_scr = widget_scroll_view_new("s0", 10, 120, 200, 100, 400, 600)
  w_sld = widget_slider_new("sl0", 0, 100, 45, 10, 230, 200, 20, "on_slide")
  w_cnt = widget_container_new("c0", "COLUMN", 10, 260, 300, 150)
  
  ok1 = assert_eq_str(w_win.title, "Dashboard", "Window title set")
  ok2 = assert_eq_str(w_btn.text, "Click Me", "Button text set")
  ok3 = assert_eq_str(w_lbl.text, "Status: Ready", "Label text set")
  ok4 = assert_eq_str(w_inp.placeholder, "Type here...", "TextInput placeholder set")
  ok5 = assert_eq_int(w_scr.content_w, 400, "ScrollView content width set")
  ok6 = assert_eq_int(w_sld.value_num, 45, "Slider initial value set")
  ok7 = assert_eq_str(w_cnt.layout_type, "COLUMN", "Container layout type set")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1 && ok4 == 1 && ok5 == 1 && ok6 == 1 && ok7 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Standard Widget Suite (Window, Button, Label, TextInput, ScrollView, Slider, Container) verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 9: Multi-Window Compositor
  @! ----------------------------------------------------------------------------
  println("▶ Section 9: Multi-Window Compositor Layering & Ordering...")

  total_tests = total_tests + 1
  comp = compositor_new(800, 600)
  w1 = widget_window_new("win1", "Window 1", 50, 50, 300, 200)
  w2 = widget_window_new("win2", "Window 2", 150, 150, 300, 200)
  comp = compositor_add_window(comp, w1)
  comp = compositor_add_window(comp, w2)
  ok1 = assert_eq_str(comp.active_window_id, "win2", "Active window is top window (win2)")
  
  comp = compositor_bring_to_front(comp, "win1")
  ok2 = assert_eq_str(comp.active_window_id, "win1", "win1 brought to front becomes active")
  ok3 = assert_eq_str(comp.windows[1].id, "win1", "win1 moved to top of z-order stack")
  
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Multi-Window Compositor z-ordering & active window focus verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SUMMARY REPORT
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  println("📊 GUI FRAMEWORK TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL 20 NATIVE GUI FRAMEWORK TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME GUI FRAMEWORK TESTS FAILED")
    return 1
  @end
@end
