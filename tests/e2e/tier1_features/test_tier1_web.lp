@! ============================================================================
@! MAYA TIER 1 E2E MASTER TEST SUITE — WEB ENGINE (FEATURES F09 - F13)
@! File: tests/e2e/tier1_features/test_tier1_web.maya
@! 100% Pure Maya Language — Zero Foreign Code (.c/.py/.sh) — Zero External Libs
@! 
@! Sub-Suites Covered:
@! - F09: Sovereign Markup Parser (AST hierarchy, inline styles, desugaring, void tags, text/entities)
@! - F10: Flexbox Layout Engine (row flex grow, col justify, cross alignment, box model, wrap, grid)
@! - F11: Pure Maya Canvas2D (ARGB channels, filled rect, border rect, clip stack, glyph text, gradients)
@! - F12: Dirty Rect Damage Compositor (union rects, full redraw, lifecycle reset, DPR scaling, telemetry)
@! - F13: ANSI Terminal TrueColor Raster (24-bit escapes, dual-pixel half-block, buffer stream, box layout)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/tools/maya_test"

@! Web Subsystems & Test Suites
import "universe/web/markup_parser"
import "universe/web/frontend/layout/layout_types"
import "universe/web/frontend/layout/flexbox_solver"
import "universe/web/frontend/renderer/canvas2d_renderer"
import "universe/web/frontend/renderer/terminal_renderer"
import "universe/web/frontend/dom_bypass/canvas_host"
import "universe/web/frontend/mod"

@! Include Web Feature Suites
import "tests/e2e/tier1_features/web/test_f09_markup"
import "tests/e2e/tier1_features/web/test_f10_flexbox"
import "tests/e2e/tier1_features/web/test_f11_canvas2d"
import "tests/e2e/tier1_features/web/test_f12_damage_compositor"
import "tests/e2e/tier1_features/web/test_f13_terminal_raster"

@fn main()
  println("=================================================================")
  println("▶ MAYA SOVEREIGN TIER 1 E2E TEST SUITE — WEB ENGINE (F09–F13)")
  println("=================================================================")

  total_passed = 0
  total_tests = 30

  @! 1. Feature F09: Sovereign Markup Parser
  f09_passed = run_f09_markup_tests()
  total_passed = total_passed + f09_passed
  println("")

  @! 2. Feature F10: Flexbox Layout Engine
  f10_passed = run_f10_flexbox_tests()
  total_passed = total_passed + f10_passed
  println("")

  @! 3. Feature F11: Pure Maya Canvas2D Software Rasterizer
  f11_passed = run_f11_canvas2d_tests()
  total_passed = total_passed + f11_passed
  println("")

  @! 4. Feature F12: Dirty Rect Damage Compositor
  f12_passed = run_f12_damage_compositor_tests()
  total_passed = total_passed + f12_passed
  println("")

  @! 5. Feature F13: ANSI Terminal TrueColor Raster
  f13_passed = run_f13_terminal_raster_tests()
  total_passed = total_passed + f13_passed
  println("")

  println("=================================================================")
  println("MAYA WEB ENGINE TIER 1 SUMMARY:")
  println("  F09 Sovereign Markup Parser:           " + f09_passed.to_str() + "/6 passed")
  println("  F10 Flexbox Layout Engine:             " + f10_passed.to_str() + "/6 passed")
  println("  F11 Pure Maya Canvas2D:                " + f11_passed.to_str() + "/6 passed")
  println("  F12 Dirty Rect Damage Compositor:      " + f12_passed.to_str() + "/6 passed")
  println("  F13 ANSI Terminal TrueColor Raster:    " + f13_passed.to_str() + "/6 passed")
  println("-----------------------------------------------------------------")
  println("  GRAND TOTAL: " + total_passed.to_str() + "/" + total_tests.to_str() + " TESTS PASSED")
  println("=================================================================")

  assert_eq(total_passed, total_tests, "All 30 Tier 1 Web Engine tests must pass")

  @if total_passed == total_tests
    println("Status: 100% SOVEREIGN WEB ENGINE PASS (ZERO REGRESSIONS)")
    return 0
  @else
    println("Status: FAILURES DETECTED")
    return 1
  @end
@end
