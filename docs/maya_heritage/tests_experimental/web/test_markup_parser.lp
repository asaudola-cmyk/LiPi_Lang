import "universe/core/string"
@! ============================================================================
@! MAYA SOVEREIGN TEST SUITE — MARKUP PARSER & CSS ENGINE (F09)
@! File: tests/web/test_markup_parser.maya
@! 100% Pure Maya Implementation — Zero External Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/math"
import "universe/core/string"
import "universe/web/markup_parser"
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

@fn main()
  println("=================================================================")
  println("▶ [SOVEREIGN TEST] Sovereign Markup Parser & CSS Engine (F09)")
  println("=================================================================")

  state = test_state_new()

  @! --------------------------------------------------------------------------
  @! 1. Color Parser (Hex, RGB/RGBA, CSS & Catppuccin Named Colors)
  @! --------------------------------------------------------------------------
  println("\n--- Tier 1: Color Space Resolution ---")
  
  c_hex3 = color_parse("#F80")
  assert_eq_int(state, c_hex3, 0xFFFF8800, "T1.1", "3-digit hex color #F80 -> 0xFFFF8800")

  c_hex6 = color_parse("#1E1E2E")
  assert_eq_int(state, c_hex6, 0xFF1E1E2E, "T1.2", "6-digit hex color #1E1E2E -> 0xFF1E1E2E")

  c_hex8 = color_parse("#18182580")
  assert_eq_int(state, c_hex8, 0x80181825, "T1.3", "8-digit hex color #18182580 -> 0x80181825")

  c_rgb = color_parse("rgb(255, 128, 0)")
  assert_eq_int(state, c_rgb, 0xFFFF8000, "T1.4", "rgb(255, 128, 0) -> 0xFFFF8000")

  c_rgba = color_parse("rgba(24, 24, 37, 255)")
  assert_eq_int(state, c_rgba, 0xFF181825, "T1.5", "rgba(24, 24, 37, 255) -> 0xFF181825")

  c_named_red = color_parse("red")
  assert_eq_int(state, c_named_red, 0xFFFF0000, "T1.6", "named CSS color 'red' -> 0xFFFF0000")

  c_cat_lavender = color_parse("lavender")
  assert_eq_int(state, c_cat_lavender, 0xFFB4BEFE, "T1.7", "Catppuccin color 'lavender' -> 0xFFB4BEFE")

  c_cat_base = color_parse("base")
  assert_eq_int(state, c_cat_base, 0xFF1E1E2E, "T1.8", "Catppuccin color 'base' -> 0xFF1E1E2E")

  c_cat_peach = color_parse("peach")
  assert_eq_int(state, c_cat_peach, 0xFFFAB387, "T1.9", "Catppuccin color 'peach' -> 0xFFFAB387")

  c_trans = color_parse("transparent")
  assert_eq_int(state, c_trans, 0, "T1.10", "color 'transparent' -> 0x00000000")

  @! --------------------------------------------------------------------------
  @! 2. CSS Declarations & Shorthand Expansions
  @! --------------------------------------------------------------------------
  println("\n--- Tier 2: CSS Declarations & Shorthands ---")

  style1 = css_parse_declarations("width: 250px; height: 120px; display: flex; flex-direction: column;")
  assert_eq_int(state, style1.style_width, 250, "T2.1", "width parsed as 250")
  assert_eq_int(state, style1.style_height, 120, "T2.2", "height parsed as 120")
  assert_eq_int(state, style1.style_display, 0, "T2.3", "display parsed as FLEX (0)")
  assert_eq_int(state, style1.style_flex_dir, 3, "T2.4", "flex-direction parsed as COLUMN (3)")

  style2 = css_parse_declarations("padding: 10px 20px; margin: 5px 15px 25px 35px; gap: 16px;")
  assert_eq_int(state, style2.style_padding_top, 10, "T2.5", "padding-top = 10 from 2-val shorthand")
  assert_eq_int(state, style2.style_padding_right, 20, "T2.6", "padding-right = 20 from 2-val shorthand")
  assert_eq_int(state, style2.style_margin_top, 5, "T2.7", "margin-top = 5 from 4-val shorthand")
  assert_eq_int(state, style2.style_margin_right, 15, "T2.8", "margin-right = 15 from 4-val shorthand")
  assert_eq_int(state, style2.style_margin_bottom, 25, "T2.9", "margin-bottom = 25 from 4-val shorthand")
  assert_eq_int(state, style2.style_margin_left, 35, "T2.10", "margin-left = 35 from 4-val shorthand")
  assert_eq_int(state, style2.style_gap, 16, "T2.11", "gap = 16")

  style3 = css_parse_declarations("border: 2px solid #89B4FA; background: #1E1E2E; color: white;")
  assert_eq_int(state, style3.style_border_width, 2, "T2.12", "border-width = 2 from shorthand")
  assert_eq_int(state, style3.style_border_color, 0xFF89B4FA, "T2.13", "border-color = 0xFF89B4FA from shorthand")
  assert_eq_int(state, style3.style_bg_color, 0xFF1E1E2E, "T2.14", "background = 0xFF1E1E2E")
  assert_eq_int(state, style3.style_color, 0xFFFFFFFF, "T2.15", "color = 0xFFFFFFFF (white)")

  style4 = css_parse_declarations("flex-grow: 2; flex-shrink: 0; justify-content: center; align-items: stretch;")
  assert_eq_int(state, style4.style_flex_grow, 2, "T2.16", "flex-grow = 2")
  assert_eq_int(state, style4.style_flex_shrink, 0, "T2.17", "flex-shrink = 0")
  assert_eq_int(state, style4.style_justify, 1, "T2.18", "justify-content = CENTER (1)")
  assert_eq_int(state, style4.style_align_items, 3, "T2.19", "align-items = STRETCH (3)")

  @! --------------------------------------------------------------------------
  @! 3. Markup Tokenization, Tag Hierarchy & Entity Decoding
  @! --------------------------------------------------------------------------
  println("\n--- Tier 3: Tokenizer, AST & Fault-Tolerant Tree Builder ---")

  src1 = "<div id=\"main\" class=\"container card\" style=\"width: 600px;\"><h1 class=\"title\">Hello &amp; Welcome &lt;Maya&gt;!</h1><button disabled class=\"btn\">Click &quot;Here&quot;</button></div>"
  ast1 = parse_markup(src1)

  assert_eq_str(state, ast1.tag_name, "div", "T3.1", "Root AST node tag is 'div'")
  assert_eq_str(state, ast1.id_name, "main", "T3.2", "Node id is 'main'")
  assert_eq_int(state, ast1.class_names.len(), 2, "T3.3", "Node has 2 class names")
  assert_eq_str(state, ast1.class_names[0], "container", "T3.4", "First class is 'container'")
  assert_eq_str(state, ast1.class_names[1], "card", "T3.5", "Second class is 'card'")
  assert_eq_int(state, ast1.style.style_width, 600, "T3.6", "Inline width style applied = 600")
  assert_eq_int(state, ast1.children.len(), 2, "T3.7", "Div has 2 children (h1 and button)")

  h1_node = ast1.children[0]
  assert_eq_str(state, h1_node.tag_name, "h1", "T3.8", "First child is 'h1'")
  assert_eq_int(state, h1_node.children.len(), 1, "T3.9", "H1 has 1 text child")
  assert_eq_str(state, h1_node.children[0].text_content, "Hello & Welcome <Maya>!", "T3.10", "HTML entities decoded (&amp; &lt; &gt;)")

  btn_node = ast1.children[1]
  assert_eq_str(state, btn_node.tag_name, "button", "T3.11", "Second child is 'button'")
  assert_eq_str(state, btn_node.children[0].text_content, "Click \"Here\"", "T3.12", "HTML entity &quot; decoded")

  @! --------------------------------------------------------------------------
  @! 4. Fault Tolerance: Unclosed Tags, Void Elements, Comments & Cascading Styles
  @! --------------------------------------------------------------------------
  println("\n--- Tier 4: Fault Tolerance, Comments & Stylesheets ---")

  src2 = "<style>.card { background: #1E1E2E; padding: 16px; border-radius: 8px; } button { color: yellow; }</style><!-- Hero section --><div class=\"card\"><img src=\"logo.png\"><p>Unclosed paragraph<span>Nested text<br><input type=\"text\" value=\"test\"></div>"
  ast2 = parse_markup(src2)

  assert_eq_str(state, ast2.tag_name, "div", "T4.1", "Root node is div with healed unclosed tags")
  assert_eq_int(state, ast2.style.style_bg_color, 0xFF1E1E2E, "T4.2", "Cascading class .card background applied")
  assert_eq_int(state, ast2.style.style_padding_top, 16, "T4.3", "Cascading padding applied")
  assert_eq_int(state, ast2.style.style_border_radius, 8, "T4.4", "Cascading border-radius applied")

  @! Check void elements (img, br, input) do not trap siblings
  img_nodes = markup_find_by_tag(ast2, "img")
  assert_eq_int(state, img_nodes.len(), 1, "T4.5", "Found 1 void <img> element")
  assert_eq_int(state, img_nodes[0].children.len(), 0, "T4.6", "Void <img> element has 0 children")

  input_nodes = markup_find_by_tag(ast2, "input")
  assert_eq_int(state, input_nodes.len(), 1, "T4.7", "Found 1 void <input> element")

  @! --------------------------------------------------------------------------
  @! 5. End-to-End Desugaring to LayoutNode & Flexbox Solver
  @! --------------------------------------------------------------------------
  println("\n--- Tier 5: Desugar to LayoutNode & Flexbox Solver ---")

  src3 = "<div style=\"width: 400px; height: 300px; padding: 20px; gap: 10px;\"><div class=\"item\" style=\"flex-grow: 1; height: 50px;\">Item 1</div><div class=\"item\" style=\"flex-grow: 2; height: 50px;\">Item 2</div></div>"
  layout_tree = markup_parse(src3)

  assert_eq_int(state, layout_tree.pref_width, 400, "T5.1", "Desugared LayoutNode pref_width = 400")
  assert_eq_int(state, layout_tree.pref_height, 300, "T5.2", "Desugared LayoutNode pref_height = 300")
  assert_eq_int(state, layout_tree.padding.top, 20, "T5.3", "Desugared LayoutNode padding = 20")
  assert_eq_int(state, layout_tree.children.len(), 2, "T5.4", "Desugared 2 children LayoutNodes")

  solved = flexbox_solve_tree(layout_tree, 400, 300)
  assert_eq_int(state, solved.width, 400, "T5.5", "Solved root width = 400")
  assert_eq_int(state, solved.height, 300, "T5.6", "Solved root height = 300")

  ch0 = solved.children[0]
  ch1 = solved.children[1]
  assert_true(state, ch0.width > 0, "T5.7", "Child 0 computed width > 0")
  assert_true(state, ch1.width > 0, "T5.8", "Child 1 computed width > 0")
  assert_eq_int(state, ch0.y, 20, "T5.9", "Child 0 y = 20 (padding offset)")

  println("=================================================================")
  println("Markup Parser Test Results: " + int_to_str(state.passed) + "/" + int_to_str(state.total) + " passed, " + int_to_str(state.failed) + " failed.")
  @if state.failed == 0
    println("Status: ALL MARKUP PARSER TESTS PASSED (100% SOVEREIGN PURITY)")
  @else
    println("Status: FAILURES DETECTED")
  @end
  println("=================================================================")
@end
