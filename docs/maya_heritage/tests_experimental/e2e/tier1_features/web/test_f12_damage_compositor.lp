@! ============================================================================
@! MAYA TIER 1 E2E TEST SUITE — FEATURE F12: DIRTY RECT DAMAGE COMPOSITOR
@! Module: tests/e2e/tier1_features/web/test_f12_damage_compositor.maya
@! 100% Pure Maya Language — Zero External Dependencies
@! Coverage:
@! 1. Adding Dirty Rectangles & Union Bounding Box Computation
@! 2. Mark Full Redraw Canvas Coverage
@! 3. Dirty State Lifecycle & Reset Mechanism
@! 4. DPR 2.0 / HiDPI Coordinate Scaling
@! 5. Damaged Pixel Area Computation & Intersection Tests
@! 6. Frame Timing Loop & Smoothed FPS Telemetry
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/tools/maya_test"
import "universe/web/frontend/dom_bypass/canvas_host"

@! ----------------------------------------------------------------------------
@! TEST 1: Adding Dirty Rectangles & Union Bounding Box Computation
@! ----------------------------------------------------------------------------
@fn test_f12_01_add_union_rect()
  comp = dirty_rect_compositor_new()
  comp = dirty_rect_compositor_reset(comp)
  
  @! Initially empty
  assert_false(dirty_rect_compositor_is_dirty(comp), "Reset compositor starts clean")
  
  @! Add rect A: (10, 20, width: 30, height: 40) -> bounds (10, 20) to (40, 60)
  comp = dirty_rect_compositor_add_rect(comp, 10, 20, 30, 40)
  assert_true(dirty_rect_compositor_is_dirty(comp), "Compositor becomes dirty after adding rect")
  
  b1 = dirty_rect_compositor_get_bounds(comp)
  assert_eq(b1.rect_min_x, 10, "Bounds min_x = 10")
  assert_eq(b1.rect_min_y, 20, "Bounds min_y = 20")
  assert_eq(b1.rect_max_x, 40, "Bounds max_x = 10 + 30 = 40")
  assert_eq(b1.rect_max_y, 60, "Bounds max_y = 20 + 40 = 60")
  
  @! Add rect B: (50, 10, width: 20, height: 80) -> bounds (50, 10) to (70, 90)
  @! Union bounds should be: min_x = 10, min_y = 10, max_x = 70, max_y = 90
  comp = dirty_rect_compositor_add_rect(comp, 50, 10, 20, 80)
  b2 = dirty_rect_compositor_get_bounds(comp)
  
  assert_eq(b2.rect_min_x, 10, "Union min_x preserved = 10")
  assert_eq(b2.rect_min_y, 10, "Union min_y expanded = 10")
  assert_eq(b2.rect_max_x, 70, "Union max_x expanded = 70 (50 + 20)")
  assert_eq(b2.rect_max_y, 90, "Union max_y expanded = 90 (10 + 80)")
  
  println("  [PASS] T1_F12_01: Adding Dirty Rectangles & Union Bounding Box Computation")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 2: Mark Full Redraw Canvas Coverage
@! ----------------------------------------------------------------------------
@fn test_f12_02_mark_full_redraw()
  comp = dirty_rect_compositor_new()
  comp = dirty_rect_compositor_reset(comp)
  
  @! Mark full redraw on 1920x1080 viewport
  comp = dirty_rect_compositor_mark_full(comp, 1920, 1080)
  
  assert_true(dirty_rect_compositor_is_dirty(comp), "Compositor is dirty after mark_full")
  assert_true(comp.comp_is_full_redraw, "comp_is_full_redraw flag is true")
  
  bounds = dirty_rect_compositor_get_bounds(comp)
  assert_eq(bounds.rect_min_x, 0, "Full redraw min_x = 0")
  assert_eq(bounds.rect_min_y, 0, "Full redraw min_y = 0")
  assert_eq(bounds.rect_max_x, 1920, "Full redraw max_x = 1920")
  assert_eq(bounds.rect_max_y, 1080, "Full redraw max_y = 1080")
  
  area = dirty_rect_compositor_damaged_area(comp)
  assert_eq(area, 1920 * 1080, "Damaged area equals full canvas pixel count (2073600)")
  
  println("  [PASS] T1_F12_02: Mark Full Redraw Canvas Coverage")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 3: Dirty State Lifecycle & Reset Mechanism
@! ----------------------------------------------------------------------------
@fn test_f12_03_lifecycle_and_reset()
  @! Create CanvasPresentationTarget host
  host = canvas_host_new("test_canvas", 400, 300, 1.0, 3, 0xFF181825)
  assert_true(dirty_rect_compositor_is_dirty(host.compositor), "New canvas host starts full dirty")
  
  @! Begin and present first frame -> compositor resets to clean
  host = canvas_host_begin_frame(host, 1000)
  host = canvas_host_draw_rect(host, 10, 10, 50, 50, 0xFFFF0000, 0, 0, 0)
  host = canvas_host_present_frame(host)
  
  assert_eq(host.presented_frames, 1, "Presented frames count = 1")
  assert_false(dirty_rect_compositor_is_dirty(host.compositor), "Compositor is clean after presentation")
  
  @! Record incremental damage
  host = canvas_host_record_damage(host, 100, 100, 50, 50)
  assert_true(dirty_rect_compositor_is_dirty(host.compositor), "Compositor dirty after record_damage")
  
  @! Present frame 2 -> compositor clean again
  host = canvas_host_begin_frame(host, 1016)
  host = canvas_host_present_frame(host)
  assert_eq(host.presented_frames, 2, "Presented frames count = 2")
  assert_false(dirty_rect_compositor_is_dirty(host.compositor), "Compositor is clean again after 2nd presentation")
  
  println("  [PASS] T1_F12_03: Dirty State Lifecycle & Reset Mechanism")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 4: DPR 2.0 / HiDPI Coordinate Scaling
@! ----------------------------------------------------------------------------
@fn test_f12_04_dpr_scaling()
  @! 1. Pure coordinate scaling helper functions
  css_val = 300
  dpr = 2.0
  phys_val = canvas_scale_css_to_physical(css_val, dpr)
  assert_eq(phys_val, 600, "CSS 300px * DPR 2.0 = 600 physical pixels")
  
  back_to_css = canvas_scale_physical_to_css(phys_val, dpr)
  assert_eq(back_to_css, 300, "Physical 600px / DPR 2.0 = 300 CSS pixels")
  
  @! 2. Canvas host at DPR 2.0
  host = canvas_host_new("retina_canvas", 500, 400, 2.0, 3, 0xFF181825)
  assert_eq(host.css_width, 500, "CSS width = 500")
  assert_eq(host.css_height, 400, "CSS height = 400")
  assert_eq(host.physical_width, 1000, "Physical width = 1000 at DPR 2.0")
  assert_eq(host.physical_height, 800, "Physical height = 800 at DPR 2.0")
  
  @! 3. Dynamic DPR resize (e.g. moved to 1.5x display)
  host = canvas_host_set_dpr(host, 1.5)
  assert_eq(host.physical_width, 750, "Physical width updated to 750 at DPR 1.5")
  assert_eq(host.physical_height, 600, "Physical height updated to 600 at DPR 1.5")
  assert_true(dirty_rect_compositor_is_dirty(host.compositor), "DPR change triggered full redraw")
  
  println("  [PASS] T1_F12_04: DPR 2.0 / HiDPI Coordinate Scaling")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 5: Damaged Pixel Area Computation & Intersection Tests
@! ----------------------------------------------------------------------------
@fn test_f12_05_damaged_area_and_intersection()
  comp = dirty_rect_compositor_new()
  comp = dirty_rect_compositor_reset(comp)
  
  @! Empty damage area is 0
  assert_eq(dirty_rect_compositor_damaged_area(comp), 0, "Empty compositor damaged area = 0")
  
  @! Add 50x50 rect -> area = 2500
  comp = dirty_rect_compositor_add_rect(comp, 10, 10, 50, 50)
  assert_eq(dirty_rect_compositor_damaged_area(comp), 2500, "50x50 damage area = 2500")
  
  @! Rect intersection helpers
  r1 = host_dirty_rect_new(10, 10, 40, 40) @! (10, 10) to (50, 50)
  r2 = host_dirty_rect_new(30, 30, 40, 40) @! (30, 30) to (70, 70) - overlapping!
  r3 = host_dirty_rect_new(100, 100, 20, 20) @! Disjoint!
  
  assert_true(host_dirty_rect_intersects(r1, r2), "Overlapping rects return true")
  assert_false(host_dirty_rect_intersects(r1, r3), "Disjoint rects return false")
  
  @! Empty rect does not intersect anything
  r_empty = host_dirty_rect_empty()
  assert_false(host_dirty_rect_intersects(r1, r_empty), "Empty rect returns false for intersection")
  
  println("  [PASS] T1_F12_05: Damaged Pixel Area Computation & Intersection Tests")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 6: Frame Timing Loop & Smoothed FPS Telemetry
@! ----------------------------------------------------------------------------
@fn test_f12_06_timing_loop_and_fps()
  loop = frame_timing_loop_new(60)
  assert_eq(loop.loop_target_fps, 60, "Target FPS is 60")
  assert_true(loop.loop_is_active, "Timing loop is active")
  assert_eq(loop.loop_frame_count, 0, "Initial frame count is 0")
  
  @! Simulate 3 consecutive 16ms frames
  loop = frame_timing_loop_tick(loop, 1000)
  assert_eq(loop.loop_frame_count, 1, "Frame count = 1")
  
  loop = frame_timing_loop_tick(loop, 1016)
  assert_eq(loop.loop_frame_count, 2, "Frame count = 2")
  assert_eq(loop.loop_delta_time_ms, 16.0, "Delta time is 16ms")
  assert_true(loop.loop_fps_estimate > 50.0 && loop.loop_fps_estimate < 70.0, "FPS estimate is ~60")
  
  loop = frame_timing_loop_tick(loop, 1032)
  assert_eq(loop.loop_frame_count, 3, "Frame count = 3")
  assert_eq(loop.loop_delta_time_ms, 16.0, "Delta time is 16ms")
  assert_true(loop.loop_fps_estimate > 55.0 && loop.loop_fps_estimate < 65.0, "Smoothed FPS converges to 60")
  
  @! Reset timing loop
  loop = frame_timing_loop_reset(loop)
  assert_eq(loop.loop_frame_count, 0, "Reset frame count is 0")
  assert_eq(loop.loop_last_timestamp, 0, "Reset last timestamp is 0")
  
  println("  [PASS] T1_F12_06: Frame Timing Loop & Smoothed FPS Telemetry")
  return 1
@end

@! ----------------------------------------------------------------------------
@! Runner Function
@! ----------------------------------------------------------------------------
@fn run_f12_damage_compositor_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F12: Dirty Rect Damage Compositor Suite")
  println("=================================================================")
  
  passed = 0
  passed = passed + test_f12_01_add_union_rect()
  passed = passed + test_f12_02_mark_full_redraw()
  passed = passed + test_f12_03_lifecycle_and_reset()
  passed = passed + test_f12_04_dpr_scaling()
  passed = passed + test_f12_05_damaged_area_and_intersection()
  passed = passed + test_f12_06_timing_loop_and_fps()
  
  println("-----------------------------------------------------------------")
  println("Feature F12 Results: " + passed.to_str() + "/6 tests passed.")
  assert_eq(passed, 6, "All F12 tests must pass")
  return passed
@end

@fn main()
  run_f12_damage_compositor_tests()
@end
