@! ============================================================================
@! ADVERSARIAL STRESS SUITE — CHALLENGER 2: DIRTY RECT COMPOSITOR (F12)
@! Module: tests/adversarial/test_adv_web_f12_compositor.maya
@! Target: universe/web/frontend/dom_bypass/canvas_host.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"
import "universe/web/frontend/dom_bypass/canvas_host"

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

@fn main()
  println("=================================================================")
  println("⚔️  ADVERSARIAL CHALLENGER 2: Feature F12 (Damage Compositor) ⚔️")
  println("=================================================================")

  state = test_state_new()

  @! --------------------------------------------------------------------------
  @! SECTION 1: Dirty Rect Geometry & Degenerate Boundaries
  @! --------------------------------------------------------------------------
  println("\n--- Section 1: Dirty Rect Geometry & Degenerate Bounds ---")

  @! Test 1.1: Empty dirty rect creation
  r_empty = host_dirty_rect_empty()
  assert_true(state, r_empty.rect_is_empty, "F12.1.1", "Empty rect has rect_is_empty == true")
  assert_eq_int(state, r_empty.rect_min_x, 0, "F12.1.2", "Empty rect min_x = 0")
  assert_eq_int(state, r_empty.rect_max_x, 0, "F12.1.3", "Empty rect max_x = 0")

  @! Test 1.2: Degenerate dimensions (0, negative) return empty rect
  r_zero_w = host_dirty_rect_new(10, 20, 0, 50)
  assert_true(state, r_zero_w.rect_is_empty, "F12.1.4", "Zero width returns empty rect")
  r_neg_h = host_dirty_rect_new(10, 20, 30, -10)
  assert_true(state, r_neg_h.rect_is_empty, "F12.1.5", "Negative height returns empty rect")

  @! Test 1.3: Valid rect creation
  r_valid = host_dirty_rect_new(15, 25, 100, 200)
  assert_false(state, r_valid.rect_is_empty, "F12.1.6", "Valid rect is not empty")
  assert_eq_int(state, r_valid.rect_min_x, 15, "F12.1.7", "Valid rect min_x = 15")
  assert_eq_int(state, r_valid.rect_min_y, 25, "F12.1.8", "Valid rect min_y = 25")
  assert_eq_int(state, r_valid.rect_max_x, 115, "F12.1.9", "Valid rect max_x = 115 (15+100)")
  assert_eq_int(state, r_valid.rect_max_y, 225, "F12.1.10", "Valid rect max_y = 225 (25+200)")

  @! --------------------------------------------------------------------------
  @! SECTION 2: Dirty Rect Union & Disjoint Accumulation
  @! --------------------------------------------------------------------------
  println("\n--- Section 2: Dirty Rect Union & Disjoint Accumulation ---")

  @! Test 2.1: Union with empty rect returns non-empty rect
  u_empty1 = host_dirty_rect_union(r_empty, r_valid)
  assert_eq_int(state, u_empty1.rect_min_x, 15, "F12.2.1", "Union(empty, valid) preserves min_x")
  assert_eq_int(state, u_empty1.rect_max_x, 115, "F12.2.2", "Union(empty, valid) preserves max_x")

  u_empty2 = host_dirty_rect_union(r_valid, r_empty)
  assert_eq_int(state, u_empty2.rect_min_x, 15, "F12.2.3", "Union(valid, empty) preserves min_x")

  @! Test 2.2: Union of completely disjoint rects in opposite quadrants
  r_quad1 = host_dirty_rect_new(0, 0, 10, 10)       @! [0,0] to [10,10]
  r_quad4 = host_dirty_rect_new(100, 100, 20, 30)   @! [100,100] to [120,130]
  u_disjoint = host_dirty_rect_union(r_quad1, r_quad4)
  assert_eq_int(state, u_disjoint.rect_min_x, 0, "F12.2.4", "Disjoint union min_x = 0")
  assert_eq_int(state, u_disjoint.rect_min_y, 0, "F12.2.5", "Disjoint union min_y = 0")
  assert_eq_int(state, u_disjoint.rect_max_x, 120, "F12.2.6", "Disjoint union max_x = 120")
  assert_eq_int(state, u_disjoint.rect_max_y, 130, "F12.2.7", "Disjoint union max_y = 130")

  @! Test 2.3: Union of subset / nested rect
  r_outer = host_dirty_rect_new(0, 0, 200, 200)
  r_inner = host_dirty_rect_new(50, 50, 50, 50)
  u_nested = host_dirty_rect_union(r_outer, r_inner)
  assert_eq_int(state, u_nested.rect_min_x, 0, "F12.2.8", "Nested union min_x = 0")
  assert_eq_int(state, u_nested.rect_max_x, 200, "F12.2.9", "Nested union max_x = 200")

  @! --------------------------------------------------------------------------
  @! SECTION 3: Intersection Predicate & Edge Contact
  @! --------------------------------------------------------------------------
  println("\n--- Section 3: Intersection Predicate & Boundary Contact ---")

  @! Test 3.1: Overlapping rects intersect
  r_a = host_dirty_rect_new(0, 0, 50, 50)
  r_b = host_dirty_rect_new(25, 25, 50, 50)
  assert_true(state, host_dirty_rect_intersects(r_a, r_b), "F12.3.1", "Overlapping rects return true")
  assert_true(state, host_dirty_rect_intersects(r_b, r_a), "F12.3.2", "Commutative intersection returns true")

  @! Test 3.2: Touching edges (non-overlapping boundary) return false
  r_touch_right = host_dirty_rect_new(50, 0, 50, 50)
  assert_false(state, host_dirty_rect_intersects(r_a, r_touch_right), "F12.3.3", "Touching right edge returns false")

  r_touch_bottom = host_dirty_rect_new(0, 50, 50, 50)
  assert_false(state, host_dirty_rect_intersects(r_a, r_touch_bottom), "F12.3.4", "Touching bottom edge returns false")

  @! Test 3.3: Empty rect intersection returns false
  assert_false(state, host_dirty_rect_intersects(r_a, r_empty), "F12.3.5", "Intersecting with empty rect returns false")

  @! --------------------------------------------------------------------------
  @! SECTION 4: Compositor Stress & 100-Rect Accumulation
  @! --------------------------------------------------------------------------
  println("\n--- Section 4: Compositor Mutation Stress ---")

  comp = dirty_rect_compositor_new()
  assert_true(state, dirty_rect_compositor_is_dirty(comp), "F12.4.1", "New compositor is dirty")

  comp = dirty_rect_compositor_reset(comp)
  assert_false(state, dirty_rect_compositor_is_dirty(comp), "F12.4.2", "Reset compositor is not dirty")
  assert_eq_int(state, dirty_rect_compositor_damaged_area(comp), 0, "F12.4.3", "Reset compositor damaged area is 0")

  @! Stress: add 100 staggered dirty rects
  ri = 0
  @while ri < 100
    comp = dirty_rect_compositor_add_rect(comp, ri * 2, ri * 3, 10, 10)
    ri = ri + 1
  @end
  assert_eq_int(state, comp.comp_rects.len(), 100, "F12.4.4", "Compositor holds 100 dirty rects")
  assert_eq_int(state, comp.comp_mutations, 100, "F12.4.5", "100 mutations recorded")

  b_100 = dirty_rect_compositor_get_bounds(comp)
  assert_eq_int(state, b_100.rect_min_x, 0, "F12.4.6", "100-rect bounds min_x = 0")
  assert_eq_int(state, b_100.rect_min_y, 0, "F12.4.7", "100-rect bounds min_y = 0")
  @! Last rect at index 99: x=198, w=10 -> max_x = 208; y=297, h=10 -> max_y = 307
  assert_eq_int(state, b_100.rect_max_x, 208, "F12.4.8", "100-rect bounds max_x = 208")
  assert_eq_int(state, b_100.rect_max_y, 307, "F12.4.9", "100-rect bounds max_y = 307")

  area = dirty_rect_compositor_damaged_area(comp)
  assert_eq_int(state, area, 208 * 307, "F12.4.10", "Damaged area matches bounding union")

  @! --------------------------------------------------------------------------
  @! SECTION 5: HiDPI / Retina Device Pixel Ratio (DPR) Scaling
  @! --------------------------------------------------------------------------
  println("\n--- Section 5: Device Pixel Ratio (DPR) Coordinate Scaling ---")

  @! Test 5.1: DPR = 1.0 (Standard)
  assert_eq_int(state, canvas_scale_css_to_physical(100, 1.0), 100, "F12.5.1", "DPR 1.0 CSS 100 -> Phys 100")

  @! Test 5.2: DPR = 2.0 (Retina 2x)
  assert_eq_int(state, canvas_scale_css_to_physical(100, 2.0), 200, "F12.5.2", "DPR 2.0 CSS 100 -> Phys 200")
  assert_eq_int(state, canvas_scale_physical_to_css(200, 2.0), 100, "F12.5.3", "DPR 2.0 Phys 200 -> CSS 100")

  @! Test 5.3: Canvas Host DPR dynamic switching
  host = canvas_host_new("test_canvas", 400, 300, 1.0, 3, 0xFF000000)
  assert_eq_int(state, host.physical_width, 400, "F12.5.4", "Host initial phys width = 400")

  host = canvas_host_set_dpr(host, 2.0)
  assert_eq_int(state, host.physical_width, 800, "F12.5.5", "Host dynamic DPR 2.0 phys width = 800")
  assert_eq_int(state, host.physical_height, 600, "F12.5.6", "Host dynamic DPR 2.0 phys height = 600")
  assert_true(state, dirty_rect_compositor_is_dirty(host.compositor), "F12.5.7", "DPR switch triggers full redraw dirty flag")

  @! --------------------------------------------------------------------------
  @! SECTION 6: Frame Timing Loop & FPS Telemetry Under Anomalous Ticks
  @! --------------------------------------------------------------------------
  println("\n--- Section 6: Frame Timing Loop & FPS Telemetry ---")

  loop = frame_timing_loop_new(60)
  assert_eq_int(state, loop.loop_target_fps, 60, "F12.6.1", "Timing loop target FPS = 60")

  @! First tick (timestamp = 1000)
  loop = frame_timing_loop_tick(loop, 1000)
  assert_eq_int(state, loop.loop_frame_count, 1, "F12.6.2", "First tick frame count = 1")

  @! Second tick at 16ms delta (timestamp = 1016)
  loop = frame_timing_loop_tick(loop, 1016)
  assert_eq_int(state, loop.loop_frame_count, 2, "F12.6.3", "Second tick frame count = 2")
  assert_true(state, loop.loop_fps_estimate > 40.0, "F12.6.4", "Smoothed FPS ~60 on 16ms delta")

  @! Anomalous tick: Zero delta clamp (timestamp = 1016 again)
  loop = frame_timing_loop_tick(loop, 1016)
  assert_true(state, loop.loop_delta_time_ms >= 1.0, "F12.6.5", "Zero delta clamped to >= 1ms")

  @! Stress tick: 100 consecutive frames to verify history window clamp at 60
  ti = 0
  t_cur = 2000
  @while ti < 100
    t_cur = t_cur + 16
    loop = frame_timing_loop_tick(loop, t_cur)
    ti = ti + 1
  @end
  assert_eq_int(state, loop.loop_frame_history.len(), 60, "F12.6.6", "Frame history window clamped at 60 entries")

  println("=================================================================")
  println("F12 Stress Results: " + int_to_str(state.passed) + "/" + int_to_str(state.total) + " passed, " + int_to_str(state.failed) + " failed.")
  @if state.failed == 0
    println("Verdict: F12 DAMAGE COMPOSITOR FULLY HARDENED")
  @else
    println("Verdict: F12 VULNERABILITIES DETECTED")
  @end
  println("=================================================================")
@end
