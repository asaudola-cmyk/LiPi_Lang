@! ============================================================================
@! MAYA WEB FRONTEND ENGINE — RENDERER & AUTO-DOWNGRADE TEST SUITE
@! File: tests/web/frontend/test_renderer_fallback.maya
@! Milestone 1: Tier 1 WebGPU / Tier 2 WebGL2 / Tier 3 Canvas 2D Fallback
@! 100% Pure Maya Architecture — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/web/frontend/renderer/unified_renderer"
import "universe/web/frontend/renderer/webgpu_renderer"
import "universe/web/frontend/renderer/webgl2_renderer"
import "universe/web/frontend/renderer/canvas2d_renderer"

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

@fn assert_eq_str(state, actual, expected, test_id, desc)
  state.total = state.total + 1
  @if actual == expected
    state.passed = state.passed + 1
    println("  [PASS] " + test_id + ": " + desc)
    return 1
  @else
    state.failed = state.failed + 1
    println("  [FAIL] " + test_id + ": " + desc + " (expected '" + expected + "', got '" + actual + "')")
    return 0
  @end
@end

@! ============================================================================
@! 2. FEATURE 1: WEBGPU TIER-1 BACKEND TESTS
@! ============================================================================

@fn test_webgpu_tier1(state)
  println("\n--- [Feature 1: Tier 1 WebGPU Renderer] ---")
  
  gpu = webgpu_renderer_new(1920, 1080, 2.0)
  assert_eq_int(state, gpu.gpu_width, 1920, "WG-01", "WebGPU initializes viewport width")
  assert_eq_int(state, gpu.gpu_height, 1080, "WG-02", "WebGPU initializes viewport height")
  assert_true(state, gpu.gpu_is_ready, "WG-03", "WebGPU renderer is marked ready")
  assert_eq_int(state, gpu.gpu_pipelines.len(), 4, "WG-04", "WebGPU compiles 4 shader pipelines (SDF rect, shadow, text, image)")
  
  gpu = webgpu_renderer_begin_frame(gpu, 0xFF1E1E2E)
  gpu = webgpu_renderer_push_clip(gpu, 50, 50, 800, 600)
  gpu = webgpu_renderer_draw_rect(gpu, 100, 100, 400, 300, 0xFF313244, 0xFF89B4FA, 2, 8)
  gpu = webgpu_renderer_draw_shadow_rect(gpu, 200, 200, 200, 150, 0xFF45475A, 4, 0x80000000, 16, 0, 8)
  gpu = webgpu_renderer_draw_text(gpu, "Maya Sovereign Engine", 120, 120, 16, 0xFFCDD6F4)
  gpu = webgpu_renderer_draw_image(gpu, 1001, 0, 0, 64, 64, 150, 150, 64, 64, 1.0)
  gpu = webgpu_renderer_pop_clip(gpu)
  gpu = webgpu_renderer_end_frame(gpu)
  
  assert_eq_int(state, gpu.gpu_instances.len(), 4, "WG-05", "WebGPU batches 4 quad instances")
  assert_eq_int(state, gpu.gpu_storage_buffer_bytes.len(), 4, "WG-06", "WebGPU emits structured storage buffer records")
  assert_true(state, gpu.gpu_commands.len() > 0, "WG-07", "WebGPU records GPU command buffer")
  assert_eq_int(state, gpu.gpu_draw_call_count, 1, "WG-08", "WebGPU combines quads into 1 instanced draw call")
  
  return state
@end

@! ============================================================================
@! 3. FEATURE 2: WEBGL2 TIER-2 BACKEND TESTS
@! ============================================================================

@fn test_webgl2_tier2(state)
  println("\n--- [Feature 2: Tier 2 WebGL2 Fallback Renderer] ---")
  
  gl = webgl2_renderer_new(1280, 720, 1.0)
  assert_eq_int(state, gl.gl_width, 1280, "GL-01", "WebGL2 initializes width")
  assert_true(state, gl.gl_programs.len() > 0, "GL-02", "WebGL2 instanced shader program is linked")
  assert_true(state, gl.gl_is_ready, "GL-03", "WebGL2 VAO/VBO pipeline is initialized and ready")
  
  gl = webgl2_renderer_begin_frame(gl, 0xFF000000)
  gl = webgl2_renderer_push_clip(gl, 10, 10, 500, 400)
  gl = webgl2_renderer_draw_rect(gl, 20, 20, 200, 100, 0xFFFF0000, 0xFFFFFFFF, 1, 0)
  gl = webgl2_renderer_draw_text(gl, "WebGL2 Active", 30, 30, 14, 0xFFFFFFFF)
  gl = webgl2_renderer_pop_clip(gl)
  gl = webgl2_renderer_end_frame(gl)
  
  assert_eq_int(state, gl.gl_instances.len(), 2, "GL-04", "WebGL2 batches 2 instances")
  assert_eq_int(state, gl.gl_draw_call_count, 1, "GL-05", "WebGL2 issues instanced draw call")
  assert_true(state, gl.gl_commands.len() >= 4, "GL-06", "WebGL2 records clear, scissor, buffer upload, and draw commands")
  
  return state
@end

@! ============================================================================
@! 4. FEATURE 3: CANVAS 2D TIER-3 CPU FALLBACK TESTS
@! ============================================================================

@fn test_canvas2d_tier3(state)
  println("\n--- [Feature 3: Tier 3 Canvas 2D CPU Rasterizer Fallback] ---")
  
  c2d = canvas2d_renderer_new(320, 240, 1.0)
  assert_eq_int(state, c2d.c2d_width, 320, "C2D-01", "Canvas2D initializes ARGB framebuffer width")
  assert_eq_int(state, c2d.c2d_height, 240, "C2D-02", "Canvas2D initializes ARGB framebuffer height")
  
  c2d = canvas2d_renderer_begin_frame(c2d, 0xFF112233)
  bg_px = canvas2d_renderer_get_pixel(c2d, 10, 10)
  assert_eq_int(state, bg_px, 0xFF112233, "C2D-03", "Canvas2D clear frame populates background ARGB")
  
  @! Draw red filled rect at (50, 50, 100, 80)
  c2d = canvas2d_renderer_draw_rect(c2d, 50, 50, 100, 80, 0xFFFF0000, 0, 0, 0)
  rect_px = canvas2d_renderer_get_pixel(c2d, 60, 60)
  assert_eq_int(state, rect_px, 0xFFFF0000, "C2D-04", "Canvas2D rasterizes filled rectangle to pixels")
  
  @! Scissoring boundary test: Push clip [0, 0, 40, 40], draw at (200, 200) -> should be clipped
  c2d = canvas2d_renderer_push_clip(c2d, 0, 0, 40, 40)
  c2d = canvas2d_renderer_draw_rect(c2d, 200, 200, 50, 50, 0xFF00FF00, 0, 0, 0)
  c2d = canvas2d_renderer_pop_clip(c2d)
  clipped_px = canvas2d_renderer_get_pixel(c2d, 210, 210)
  assert_eq_int(state, clipped_px, 0xFF112233, "C2D-05", "Canvas2D clipping scissoring discards out-of-bounds rect")
  
  c2d = canvas2d_renderer_end_frame(c2d)
  assert_true(state, c2d.c2d_draw_call_count > 0, "C2D-06", "Canvas2D tracks completed draw operations")
  
  return state
@end

@! ============================================================================
@! 5. FEATURE 4: AUTO-DOWNGRADE PROBE & RUNTIME STATE MACHINE TESTS
@! ============================================================================

@fn test_auto_downgrade_probing(state)
  println("\n--- [Feature 4A: Capability Probing & Initial Downgrade] ---")
  
  @! 1. All available -> Tier 1 WebGPU
  caps_all = unified_renderer_probe_capabilities(true, true)
  r1 = unified_renderer_init_with_caps(1, 800, 600, 1.0, caps_all)
  assert_eq_int(state, r1.tier, 1, "PROBE-01", "Preferred Tier 1 with WebGPU support selects WebGPU")
  assert_eq_str(state, r1.status, "ACTIVE", "PROBE-02", "Tier 1 status is ACTIVE")
  
  @! 2. WebGPU unsupported -> auto-downgrade to Tier 2 WebGL2
  caps_no_gpu = unified_renderer_probe_capabilities(false, true)
  r2 = unified_renderer_init_with_caps(1, 800, 600, 1.0, caps_no_gpu)
  assert_eq_int(state, r2.tier, 2, "PROBE-03", "Auto-probe downgrades WebGPU unavailable to Tier 2 WebGL2")
  assert_eq_str(state, r2.status, "DOWNGRADED", "PROBE-04", "Status reflects DOWNGRADED")
  
  @! 3. WebGPU & WebGL2 unsupported -> auto-downgrade to Tier 3 Canvas2D
  caps_no_hw = unified_renderer_probe_capabilities(false, false)
  r3 = unified_renderer_init_with_caps(1, 800, 600, 1.0, caps_no_hw)
  assert_eq_int(state, r3.tier, 3, "PROBE-05", "Auto-probe downgrades missing WebGPU/WebGL2 to Tier 3 Canvas2D")
  assert_eq_str(state, r3.status, "DOWNGRADED", "PROBE-06", "Tier 3 status reflects DOWNGRADED")
  
  return state
@end

@fn test_runtime_downgrade_state_machine(state)
  println("\n--- [Feature 4B: Dynamic Runtime Downgrade State Machine] ---")
  
  r = unified_renderer_new(1, 1024, 768, 1.0)
  assert_eq_int(state, unified_renderer_get_tier(r), 1, "STATE-01", "Starts at Tier 1 WebGPU")
  
  @! Frame 1 on Tier 1
  r = unified_renderer_begin_frame(r, 0xFF000000)
  r = unified_renderer_draw_rect(r, 10, 10, 100, 100, 0xFFFFFFFF, 0, 0, 0)
  r = unified_renderer_end_frame(r)
  
  @! Simulate GPU device lost / out of memory error
  r = unified_renderer_downgrade(r, "WebGPU Device Lost (0x80004005)")
  assert_eq_int(state, unified_renderer_get_tier(r), 2, "STATE-02", "Downgrades Tier 1 -> Tier 2 (WebGL2)")
  assert_eq_str(state, unified_renderer_get_status(r), "DOWNGRADED", "STATE-03", "Status is DOWNGRADED")
  
  @! Frame 2 on Tier 2
  r = unified_renderer_begin_frame(r, 0xFF000000)
  r = unified_renderer_draw_rect(r, 20, 20, 100, 100, 0xFF0000FF, 0, 0, 0)
  r = unified_renderer_end_frame(r)
  assert_eq_int(state, r.frame_count, 2, "STATE-04", "Frame counter increments across tier transitions")
  
  @! Simulate WebGL context lost error
  r = unified_renderer_downgrade(r, "WebGL2 Context Lost (CONTEXT_LOST_WEBGL)")
  assert_eq_int(state, unified_renderer_get_tier(r), 3, "STATE-05", "Downgrades Tier 2 -> Tier 3 (Canvas2D)")
  
  @! Frame 3 on Tier 3
  r = unified_renderer_begin_frame(r, 0xFF000000)
  r = unified_renderer_draw_rect(r, 30, 30, 50, 50, 0xFF00FF00, 0, 0, 0)
  r = unified_renderer_end_frame(r)
  assert_eq_int(state, r.frame_count, 3, "STATE-06", "Draws correctly on Tier 3 CPU fallback")
  
  @! Attempt downgrade beyond Tier 3 -> Terminal failure state
  r = unified_renderer_downgrade(r, "Software Canvas Out of Memory")
  assert_eq_str(state, unified_renderer_get_status(r), "FAILED", "STATE-07", "Tier 3 downgrade yields FAILED status")
  assert_true(state, r.downgrade_log.len() >= 3, "STATE-08", "Downgrade log records complete audit trail")
  
  return state
@end

@! ============================================================================
@! 6. UNIFIED RENDERER DRAWING & CLIPPING EDGE CASES
@! ============================================================================

@fn test_unified_drawing_and_edges(state)
  println("\n--- [Feature 5: Unified Drawing Primitives & Edge Cases] ---")
  
  r = unified_renderer_new(1, 800, 600, 1.0)
  
  @! Test nested clipping stack
  r = unified_renderer_begin_frame(r, 0xFF000000)
  r = unified_renderer_push_clip(r, 0, 0, 400, 400)
  r = unified_renderer_push_clip(r, 50, 50, 200, 200)
  r = unified_renderer_push_clip(r, 100, 100, 100, 100)
  assert_eq_int(state, r.clip_stack.len(), 3, "EDGE-01", "Nested push_clip records 3 stack frames")
  
  r = unified_renderer_pop_clip(r)
  r = unified_renderer_pop_clip(r)
  r = unified_renderer_pop_clip(r)
  assert_eq_int(state, r.clip_stack.len(), 0, "EDGE-02", "Pop_clip restores root clipping boundaries")
  
  @! Zero-sized and negative-sized primitive boundary handling
  r = unified_renderer_draw_rect(r, 0, 0, 0, 100, 0xFFFFFFFF, 0, 0, 0)
  r = unified_renderer_draw_rect(r, 0, 0, 100, -10, 0xFFFFFFFF, 0, 0, 0)
  
  gpu_be = r.webgpu_backend
  assert_eq_int(state, gpu_be.gpu_instances.len(), 0, "EDGE-03", "Zero/negative width rects are safely rejected")
  
  @! Valid shadow rect and text rendering
  r = unified_renderer_draw_shadow_rect(r, 50, 50, 200, 100, 0xFF333333, 8, 0x88000000, 10, 2, 4)
  r = unified_renderer_draw_text(r, "Unified Draw", 60, 60, 12, 0xFFFFFFFF)
  r = unified_renderer_draw_image(r, 505, 0, 0, 32, 32, 70, 70, 32, 32, 0.8)
  r = unified_renderer_end_frame(r)
  
  stats = unified_renderer_get_stats(r)
  assert_true(state, stats.draw_calls >= 1, "EDGE-04", "Renderer stats reports active draw calls")
  assert_eq_int(state, stats.total_quads, 3, "EDGE-05", "Renderer stats accurately reports batched quad count")
  
  return state
@end

@! ============================================================================
@! 7. MAIN TEST ENTRY POINT
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🧪 MAYA WEB FRONTEND ENGINE: RENDERER & FALLBACK TEST SUITE 🧪")
  println("=================================================================")
  
  state = test_state_new()
  
  state = test_webgpu_tier1(state)
  state = test_webgl2_tier2(state)
  state = test_canvas2d_tier3(state)
  state = test_auto_downgrade_probing(state)
  state = test_runtime_downgrade_state_machine(state)
  state = test_unified_drawing_and_edges(state)
  
  println("\n=================================================================")
  println("📊 TEST SUMMARY: " + state.passed.to_str() + " / " + state.total.to_str() + " assertions passed (" + state.failed.to_str() + " failed)")
  println("=================================================================")
  
  @if state.failed > 0
    println("❌ TEST SUITE FAILED")
    return 1
  @end
  
  println("✅ ALL RENDERER & FALLBACK TESTS PASSED SUCCESSFULLY")
  return 0
@end
