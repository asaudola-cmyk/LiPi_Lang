@! ============================================================================
@! MAYA WEB FRONTEND ENGINE — ADVERSARIAL STRESS SUITE: RENDERER FALLBACK
@! File: tests/web/frontend/test_stress_renderer_fallback.maya
@! Focus: Dynamic 3-Tier Cascading Fallbacks, Device Lost Error Injection,
@! State Invariant Preservation, Direct-Jump Degradation, Scissoring Stack Invariants.
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"

import "universe/web/frontend/renderer/unified_renderer"
import "universe/web/frontend/renderer/webgpu_renderer"
import "universe/web/frontend/renderer/webgl2_renderer"
import "universe/web/frontend/renderer/canvas2d_renderer"

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

@fn assert_eq_str(actual, expected, test_id, desc)
  @if actual == expected
    println("  ✓ [PASS] " + test_id + ": " + desc + " (= '" + actual + "')")
    return 1
  @end
  println("  ❌ [FAIL] " + test_id + ": " + desc + " (expected '" + expected + "', got '" + actual + "')")
  return 0
@end

@fn main()
  println("=================================================================")
  println("🔥 ADVERSARIAL STRESS 2: RENDERER AUTO-DOWNGRADING STATE MACHINE 🔥")
  println("=================================================================")

  total = 29
  passed = 0

  @! 1. Full 3-Tier Cascading Fallback & Invariant Integrity
  r = unified_renderer_new(1, 400, 300, 1.0)
  passed = passed + assert_eq_int(unified_renderer_get_tier(r), 1, "DOWNGRADE-01", "Initial tier is 1 (WebGPU)")
  passed = passed + assert_eq_str(unified_renderer_get_status(r), "ACTIVE", "DOWNGRADE-02", "Initial status is ACTIVE")

  r = unified_renderer_begin_frame(r, 0xFF1E1E2E)
  r = unified_renderer_draw_rect(r, 10, 10, 100, 80, 0xFF313244, 0xFF89B4FA, 2, 8)
  r = unified_renderer_draw_text(r, "Frame 1 WebGPU", 20, 20, 14, 0xFFCDD6F4)
  r = unified_renderer_end_frame(r)
  passed = passed + assert_eq_int(r.frame_count, 1, "DOWNGRADE-03", "Frame count is 1 after Tier 1 render")
  passed = passed + assert_eq_int(r.total_draw_ops, 2, "DOWNGRADE-04", "Total draw ops is 2")

  r = unified_renderer_downgrade(r, "DEVICE_LOST_REASON_GPU_HANG_0xDEADBEEF")
  passed = passed + assert_eq_int(unified_renderer_get_tier(r), 2, "DOWNGRADE-05", "Downgraded to Tier 2 (WebGL2)")
  passed = passed + assert_eq_str(unified_renderer_get_status(r), "DOWNGRADED", "DOWNGRADE-06", "Status is DOWNGRADED")
  passed = passed + assert_eq_int(r.width, 400, "DOWNGRADE-07", "Width preserved across Tier 1 -> Tier 2 transition")
  passed = passed + assert_eq_int(r.height, 300, "DOWNGRADE-08", "Height preserved across Tier 1 -> Tier 2 transition")

  r = unified_renderer_begin_frame(r, 0xFF1E1E2E)
  r = unified_renderer_draw_rect(r, 10, 10, 100, 80, 0xFF313244, 0xFF89B4FA, 2, 8)
  r = unified_renderer_draw_text(r, "Frame 2 WebGL2", 20, 20, 14, 0xFFCDD6F4)
  r = unified_renderer_end_frame(r)
  passed = passed + assert_eq_int(r.frame_count, 2, "DOWNGRADE-09", "Frame count increments to 2 across downgrade")
  passed = passed + assert_eq_int(r.total_draw_ops, 4, "DOWNGRADE-10", "Total draw ops accumulates to 4")

  r = unified_renderer_downgrade(r, "CONTEXT_LOST_WEBGL_OUT_OF_VRAM")
  passed = passed + assert_eq_int(unified_renderer_get_tier(r), 3, "DOWNGRADE-11", "Downgraded to Tier 3 (Canvas2D CPU)")
  passed = passed + assert_eq_str(unified_renderer_get_status(r), "DOWNGRADED", "DOWNGRADE-12", "Status is DOWNGRADED")

  r = unified_renderer_begin_frame(r, 0xFF1E1E2E)
  r = unified_renderer_draw_rect(r, 10, 10, 100, 80, 0xFF313244, 0xFF89B4FA, 2, 8)
  r = unified_renderer_draw_text(r, "Frame 3 Canvas2D", 20, 20, 14, 0xFFCDD6F4)
  r = unified_renderer_end_frame(r)
  passed = passed + assert_eq_int(r.frame_count, 3, "DOWNGRADE-13", "Frame count increments to 3 on Tier 3")
  passed = passed + assert_eq_int(r.total_draw_ops, 6, "DOWNGRADE-14", "Total draw ops accumulates to 6")

  r = unified_renderer_downgrade(r, "CANVAS2D_FATAL_MEMORY_EXHAUSTION")
  passed = passed + assert_eq_int(unified_renderer_get_tier(r), 3, "DOWNGRADE-15", "Tier remains 3 (cannot downgrade further)")
  passed = passed + assert_eq_str(unified_renderer_get_status(r), "FAILED", "DOWNGRADE-16", "Status transitions to terminal FAILED")

  r = unified_renderer_downgrade(r, "SUBSEQUENT_FAILURE_AFTER_TERMINAL")
  passed = passed + assert_eq_str(unified_renderer_get_status(r), "FAILED", "DOWNGRADE-17", "Terminal state remains FAILED without exception")
  passed = passed + assert_eq_int(r.downgrade_log.len(), 4, "DOWNGRADE-18", "Downgrade log contains all 4 audit messages")

  @! 2. Direct-Jump Fallback when WebGL2 is unsupported
  caps_no_gl = {
    cap_has_webgpu: true,
    cap_has_webgl2: false,
    cap_has_canvas2d: true,
    cap_max_texture_size: 4096,
    cap_supports_compute: true,
    cap_supports_sdf_anti_aliasing: true,
    cap_supports_instancing: true,
    cap_vendor_string: "Maya Direct Jump Test"
  }
  r_jump = unified_renderer_init_with_caps(1, 300, 200, 1.0, caps_no_gl)
  passed = passed + assert_eq_int(r_jump.tier, 1, "DOWNGRADE-19", "Direct-jump renderer starts at Tier 1")
  r_jump = unified_renderer_downgrade(r_jump, "WebGPU Device Lost (WebGL2 disabled in caps)")
  passed = passed + assert_eq_int(r_jump.tier, 3, "DOWNGRADE-20", "Direct jump bypasses Tier 2 and transitions directly to Tier 3")

  @! 3. Clipping Stack Invariants across Downgrade
  r_clip = unified_renderer_new(1, 400, 300, 1.0)
  r_clip = unified_renderer_begin_frame(r_clip, 0xFF000000)
  r_clip = unified_renderer_push_clip(r_clip, 0, 0, 300, 250)
  r_clip = unified_renderer_push_clip(r_clip, 20, 20, 200, 150)
  r_clip = unified_renderer_push_clip(r_clip, 40, 40, 100, 80)
  passed = passed + assert_eq_int(r_clip.clip_stack.len(), 3, "DOWNGRADE-21", "Clip stack depth is 3")
  passed = passed + assert_eq_int(r_clip.current_clip[0], 40, "DOWNGRADE-22", "Current clip min_x is 40")
  passed = passed + assert_eq_int(r_clip.current_clip[2], 140, "DOWNGRADE-23", "Current clip max_x is 140 (40+100)")

  r_clip = unified_renderer_downgrade(r_clip, "Device lost mid-clip")
  passed = passed + assert_eq_int(r_clip.tier, 2, "DOWNGRADE-24", "Tier downgraded to 2 mid-clip")
  passed = passed + assert_eq_int(r_clip.clip_stack.len(), 3, "DOWNGRADE-25", "Clip stack preserved across mid-clip downgrade")

  r_clip = unified_renderer_pop_clip(r_clip)
  passed = passed + assert_eq_int(r_clip.current_clip[0], 20, "DOWNGRADE-26", "Popped clip restores min_x to 20")
  passed = passed + assert_eq_int(r_clip.current_clip[2], 220, "DOWNGRADE-27", "Popped clip restores max_x to 220 (20+200)")

  r_clip = unified_renderer_pop_clip(r_clip)
  r_clip = unified_renderer_pop_clip(r_clip)
  passed = passed + assert_eq_int(r_clip.clip_stack.len(), 0, "DOWNGRADE-28", "Clip stack fully restored to root")
  passed = passed + assert_eq_int(r_clip.current_clip[2], 400, "DOWNGRADE-29", "Root clip boundary matches viewport width 400")

  println("\n=================================================================")
  println("📊 RENDERER DOWNGRADE RESULTS: " + passed.to_str() + " / " + total.to_str() + " assertions passed")
  println("=================================================================")

  @if passed == total
    println("🎉 ALL 29 RENDERER AUTO-DOWNGRADE STRESS CHALLENGES PASSED! 🎉")
    return 0
  @else
    return 1
  @end
@end
