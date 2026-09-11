@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — NATIVE GUI CALCULATOR APP TEST SUITE
@! File: tests/gui/test_gui_calculator_app.maya
@! Milestone: M2 / E2E Track (Native GUI Applications)
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
import "apps/gui_calculator"

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

@! ============================================================================
@! 2. TEST SUITE RUNNER
@! ============================================================================

@fn main()
  println("=================================================================")
  println("🧮 MAYA GUI CALCULATOR APPLICATION COMPREHENSIVE TEST SUITE 🧮")
  println("=================================================================")

  total_tests = 0
  passed_tests = 0

  @! ----------------------------------------------------------------------------
  @! SECTION 1: Calculator Initialization & Layout
  @! ----------------------------------------------------------------------------
  println("▶ Section 1: Calculator App Initialization & Component Tree...")
  
  app = calc_app_create()
  total_tests = total_tests + 1
  ok1 = assert_eq_str(calc_app_get_display(app), "0", "Initial display shows 0")
  ok2 = assert_eq_str(calc_app_get_expression(app), "", "Initial expression is empty")
  ok3 = assert_eq_int(app.grid_container.children.len(), 20, "20 calculator buttons created")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Calculator app initialization & 4x5 button matrix verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 2: Single & Multi-Digit Entry
  @! ----------------------------------------------------------------------------
  println("▶ Section 2: Number Entry, Leading Zeroes & Decimal Precision...")

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "7")
  app = calc_app_press_button(app, "8")
  app = calc_app_press_button(app, "9")
  ok1 = assert_eq_str(calc_app_get_display(app), "789", "Sequential typing 7,8,9 produces 789")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Multi-digit sequential entry verified")
  @end

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "0")
  app = calc_app_press_button(app, "0")
  app = calc_app_press_button(app, "5")
  ok1 = assert_eq_str(calc_app_get_display(app), "5", "Leading zeros suppressed on new digit entry (0,0,5 -> 5)")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Leading zero suppression verified")
  @end

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "3")
  app = calc_app_press_button(app, ".")
  app = calc_app_press_button(app, ".") @! duplicate dot ignored
  app = calc_app_press_button(app, "1")
  app = calc_app_press_button(app, "4")
  ok1 = assert_eq_str(calc_app_get_display(app), "3.14", "Decimal entry and duplicate dot rejection (3.14)")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Decimal point formatting & duplicate dot suppression verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 3: Basic Arithmetic Operations
  @! ----------------------------------------------------------------------------
  println("▶ Section 3: Basic Arithmetic Operations (+, -, *, /, %)...")

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "1")
  app = calc_app_press_button(app, "5")
  app = calc_app_press_button(app, "+")
  app = calc_app_press_button(app, "2")
  app = calc_app_press_button(app, "7")
  app = calc_app_press_button(app, "=")
  ok1 = assert_eq_str(calc_app_get_display(app), "42", "Addition: 15 + 27 = 42")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Addition arithmetic verified (15 + 27 = 42)")
  @end

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "1")
  app = calc_app_press_button(app, "0")
  app = calc_app_press_button(app, "0")
  app = calc_app_press_button(app, "-")
  app = calc_app_press_button(app, "3")
  app = calc_app_press_button(app, "7")
  app = calc_app_press_button(app, "=")
  ok1 = assert_eq_str(calc_app_get_display(app), "63", "Subtraction: 100 - 37 = 63")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Subtraction arithmetic verified (100 - 37 = 63)")
  @end

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "1")
  app = calc_app_press_button(app, "2")
  app = calc_app_press_button(app, "*")
  app = calc_app_press_button(app, "1")
  app = calc_app_press_button(app, "2")
  app = calc_app_press_button(app, "=")
  ok1 = assert_eq_str(calc_app_get_display(app), "144", "Multiplication: 12 * 12 = 144")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Multiplication arithmetic verified (12 * 12 = 144)")
  @end

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "8")
  app = calc_app_press_button(app, "4")
  app = calc_app_press_button(app, "/")
  app = calc_app_press_button(app, "4")
  app = calc_app_press_button(app, "=")
  ok1 = assert_eq_str(calc_app_get_display(app), "21", "Division: 84 / 4 = 21")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Division arithmetic verified (84 / 4 = 21)")
  @end

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "2")
  app = calc_app_press_button(app, "9")
  app = calc_app_press_button(app, "%")
  app = calc_app_press_button(app, "5")
  app = calc_app_press_button(app, "=")
  ok1 = assert_eq_str(calc_app_get_display(app), "4", "Modulo: 29 % 5 = 4")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Modulo arithmetic verified (29 % 5 = 4)")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 4: Operator Precedence (Shunting-Yard Direct Evaluation)
  @! ----------------------------------------------------------------------------
  println("▶ Section 4: Operator Precedence (Multiplication/Division before Addition/Subtraction)...")

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "2")
  app = calc_app_press_button(app, "+")
  app = calc_app_press_button(app, "3")
  app = calc_app_press_button(app, "*")
  app = calc_app_press_button(app, "4")
  app = calc_app_press_button(app, "=")
  ok1 = assert_eq_str(calc_app_get_display(app), "14", "Precedence: 2 + 3 * 4 = 14 (not 20)")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Operator precedence (* before +) verified (2 + 3 * 4 = 14)")
  @end

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "5")
  app = calc_app_press_button(app, "0")
  app = calc_app_press_button(app, "-")
  app = calc_app_press_button(app, "1")
  app = calc_app_press_button(app, "0")
  app = calc_app_press_button(app, "/")
  app = calc_app_press_button(app, "2")
  app = calc_app_press_button(app, "=")
  ok1 = assert_eq_str(calc_app_get_display(app), "45", "Precedence: 50 - 10 / 2 = 45 (not 20)")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Operator precedence (/ before -) verified (50 - 10 / 2 = 45)")
  @end

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "4")
  app = calc_app_press_button(app, "*")
  app = calc_app_press_button(app, "5")
  app = calc_app_press_button(app, "+")
  app = calc_app_press_button(app, "6")
  app = calc_app_press_button(app, "*")
  app = calc_app_press_button(app, "7")
  app = calc_app_press_button(app, "=")
  ok1 = assert_eq_str(calc_app_get_display(app), "62", "Precedence: 4 * 5 + 6 * 7 = 62 (20 + 42)")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Multiple high-precedence pairs verified (4 * 5 + 6 * 7 = 62)")
  @end

  @! Direct String Expression Evaluator Shunting-Yard
  total_tests = total_tests + 1
  str_eval_res1 = calc_app_eval_string("2 + 3 * 4")
  str_eval_res2 = calc_app_eval_string("( 10 + 20 ) * 3")
  ok_s1 = assert_eq_str(str_eval_res1, "14", "calc_app_eval_string('2 + 3 * 4') == 14")
  ok_s2 = assert_eq_str(str_eval_res2, "90", "calc_app_eval_string('( 10 + 20 ) * 3') == 90")
  @if ok_s1 == 1 && ok_s2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Full Shunting-Yard string evaluator verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 5: Unary Negation & Deletion
  @! ----------------------------------------------------------------------------
  println("▶ Section 5: Unary Negation (+/-) & Backspace (DEL)...")

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "4")
  app = calc_app_press_button(app, "2")
  app = calc_app_press_button(app, "+/-")
  ok1 = assert_eq_str(calc_app_get_display(app), "-42", "Negation: 42 +/- becomes -42")
  app = calc_app_press_button(app, "*")
  app = calc_app_press_button(app, "2")
  app = calc_app_press_button(app, "=")
  ok2 = assert_eq_str(calc_app_get_display(app), "-84", "-42 * 2 = -84")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Unary negation and negative multiplication verified (-42 * 2 = -84)")
  @end

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "1")
  app = calc_app_press_button(app, "2")
  app = calc_app_press_button(app, "3")
  app = calc_app_press_button(app, "4")
  app = calc_app_press_button(app, "5")
  app = calc_app_press_button(app, "DEL")
  ok1 = assert_eq_str(calc_app_get_display(app), "1234", "Backspace: 12345 DEL becomes 1234")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Backspace digit removal verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 6: Error Handling (Division by Zero)
  @! ----------------------------------------------------------------------------
  println("▶ Section 6: Division by Zero Error Handling & Recovery...")

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_button(app, "5")
  app = calc_app_press_button(app, "0")
  app = calc_app_press_button(app, "/")
  app = calc_app_press_button(app, "0")
  app = calc_app_press_button(app, "=")
  ok1 = assert_eq_str(calc_app_get_display(app), "Error", "Division by zero produces Error")
  app = calc_app_press_button(app, "8") @! Ignored in error state
  ok2 = assert_eq_str(calc_app_get_display(app), "Error", "Typing in error state ignored")
  app = calc_app_press_button(app, "C")
  ok3 = assert_eq_str(calc_app_get_display(app), "0", "Clear restores 0 and resets error state")
  @if ok1 == 1 && ok2 == 1 && ok3 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Division by zero emission and Clear recovery verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 7: Coordinate Mouse Click Simulation & Key Simulation
  @! ----------------------------------------------------------------------------
  println("▶ Section 7: Button Coordinate Click Hit-Testing Simulation...")

  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  
  @! Find buttons 7, +, 5, = in grid hierarchy and retrieve their center coordinates
  btn_7 = widget_find_by_id(app.window, "btn_7")
  btn_plus = widget_find_by_id(app.window, "btn_+")
  btn_5 = widget_find_by_id(app.window, "btn_5")
  btn_eq = widget_find_by_id(app.window, "btn_=")
  
  app = calc_app_click_at(app, btn_7.x + 10, btn_7.y + 10)
  app = calc_app_click_at(app, btn_plus.x + 10, btn_plus.y + 10)
  app = calc_app_click_at(app, btn_5.x + 10, btn_5.y + 10)
  app = calc_app_click_at(app, btn_eq.x + 10, btn_eq.y + 10)
  
  ok1 = assert_eq_str(calc_app_get_display(app), "12", "Coordinate simulated clicks (7 + 5 =) yields 12")
  @if ok1 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Direct 2D canvas coordinate mouse click simulation verified (7 + 5 = 12)")
  @end

  @! Keyboard event simulation test
  total_tests = total_tests + 1
  app = calc_app_press_button(app, "C")
  app = calc_app_press_key(app, 0, "9")
  app = calc_app_press_key(app, 0, "*")
  app = calc_app_press_key(app, 0, "9")
  app = calc_app_press_key(app, 13, "=")
  ok_k = assert_eq_str(calc_app_get_display(app), "81", "Keyboard simulation 9 * 9 = 81")
  @if ok_k == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Keyboard simulation API verified (9 * 9 = 81)")
  @end

  @! ----------------------------------------------------------------------------
  @! SECTION 8: Visual Canvas Rasterization
  @! ----------------------------------------------------------------------------
  println("▶ Section 8: Visual Canvas Rendering...")

  total_tests = total_tests + 1
  app = calc_app_render(app)
  title_bg = canvas_get_pixel(app.canvas, 15, 15)
  win_bg = canvas_get_pixel(app.canvas, 15, 45)
  ok1 = assert_eq_int(title_bg, 0xFF007ACC, "Window title bar rendered color")
  ok2 = assert_eq_int(win_bg, 0xFF2A2A2A, "Window body background color")
  @if ok1 == 1 && ok2 == 1
    passed_tests = passed_tests + 1
    println("  [PASS] Complete Calculator App canvas rasterization verified")
  @end

  @! ----------------------------------------------------------------------------
  @! SUMMARY REPORT
  @! ----------------------------------------------------------------------------
  println("=================================================================")
  println("📊 CALCULATOR APP TEST RESULTS: " + passed_tests.to_str() + " / " + total_tests.to_str() + " passed")
  println("=================================================================")

  @if passed_tests == total_tests
    println("🎉 ALL " + total_tests.to_str() + " GUI CALCULATOR APP TESTS PASSED! 🎉")
    return 0
  @else
    println("❌ SOME GUI CALCULATOR APP TESTS FAILED")
    return 1
  @end
@end
