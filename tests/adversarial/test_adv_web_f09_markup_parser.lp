@! ============================================================================
@! ADVERSARIAL STRESS SUITE — CHALLENGER 1: MARKUP PARSER & TOKENIZER (F09)
@! Module: tests/adversarial/test_adv_web_f09_markup_parser.maya
@! Target: universe/web/markup_parser.maya
@! 100% Pure Maya Architecture — Zero External Dependencies
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
  println("⚔️  ADVERSARIAL CHALLENGER 1: Feature F09 (Markup Parser & Tokenizer) ⚔️")
  println("=================================================================")

  state = test_state_new()

  @! --------------------------------------------------------------------------
  @! SECTION 1: Color Parsing Boundaries (Hex, RGB/RGBA, CSS & Catppuccin)
  @! --------------------------------------------------------------------------
  println("\n--- Section 1: Color Parsing Edge Cases & Palettes ---")

  @! 1.1 Hex Colors with various lengths and casings
  assert_eq_int(state, color_parse("#000"), 0xFF000000, "F09.1.1", "#000 (black 3-hex)")
  assert_eq_int(state, color_parse("#fff"), 0xFFFFFFFF, "F09.1.2", "#fff (white lowercase 3-hex)")
  assert_eq_int(state, color_parse("#F0A"), 0xFFFF00AA, "F09.1.3", "#F0A (3-hex with alpha expansion)")
  assert_eq_int(state, color_parse("#1234"), 0x44112233, "F09.1.4", "#1234 (4-hex #RGBA -> 0xAARRGGBB)")
  assert_eq_int(state, color_parse("#000000"), 0xFF000000, "F09.1.5", "#000000 (6-hex black)")
  assert_eq_int(state, color_parse("#FFFFFF"), 0xFFFFFFFF, "F09.1.6", "#FFFFFF (6-hex white)")
  assert_eq_int(state, color_parse("#18182580"), 0x80181825, "F09.1.7", "#18182580 (8-hex #RRGGBBAA -> 0xAARRGGBB)")
  assert_eq_int(state, color_parse("0x80181825"), 0x80181825, "F09.1.8", "0x80181825 (0x hex prefix format)")

  @! 1.2 Functional rgb() and rgba() with boundary values and floats
  assert_eq_int(state, color_parse("rgb(0, 0, 0)"), 0xFF000000, "F09.1.9", "rgb(0,0,0) black")
  assert_eq_int(state, color_parse("rgb(255, 255, 255)"), 0xFFFFFFFF, "F09.1.10", "rgb(255,255,255) white")
  assert_eq_int(state, color_parse("rgba(255, 0, 0, 0)"), 0x00FF0000, "F09.1.11", "rgba transparent red (alpha=0)")
  assert_eq_int(state, color_parse("rgba(0, 255, 0, 128)"), 0x8000FF00, "F09.1.12", "rgba semi-transparent green (alpha=128)")
  assert_eq_int(state, color_parse("rgba(0, 0, 255, 1.0)"), 0xFF0000FF, "F09.1.13", "rgba blue with float alpha 1.0")

  @! 1.3 Catppuccin Full Palette Verification
  assert_eq_int(state, color_parse("crust"), 0xFF11111B, "F09.1.14", "Catppuccin crust")
  assert_eq_int(state, color_parse("mantle"), 0xFF181825, "F09.1.15", "Catppuccin mantle")
  assert_eq_int(state, color_parse("base"), 0xFF1E1E2E, "F09.1.16", "Catppuccin base")
  assert_eq_int(state, color_parse("surface0"), 0xFF313244, "F09.1.17", "Catppuccin surface0")
  assert_eq_int(state, color_parse("surface1"), 0xFF45475A, "F09.1.18", "Catppuccin surface1")
  assert_eq_int(state, color_parse("surface2"), 0xFF585B70, "F09.1.19", "Catppuccin surface2")
  assert_eq_int(state, color_parse("overlay0"), 0xFF6C7086, "F09.1.20", "Catppuccin overlay0")
  assert_eq_int(state, color_parse("overlay1"), 0xFF7F849C, "F09.1.21", "Catppuccin overlay1")
  assert_eq_int(state, color_parse("subtext0"), 0xFFA6ADC8, "F09.1.22", "Catppuccin subtext0")
  assert_eq_int(state, color_parse("subtext1"), 0xFFBAC2DE, "F09.1.23", "Catppuccin subtext1")
  assert_eq_int(state, color_parse("text"), 0xFFCDD6F4, "F09.1.24", "Catppuccin text")
  assert_eq_int(state, color_parse("lavender"), 0xFFB4BEFE, "F09.1.25", "Catppuccin lavender")
  assert_eq_int(state, color_parse("sapphire"), 0xFF74C7EC, "F09.1.26", "Catppuccin sapphire")
  assert_eq_int(state, color_parse("sky"), 0xFF89DCEB, "F09.1.27", "Catppuccin sky")
  assert_eq_int(state, color_parse("mauve"), 0xFFCBA6F7, "F09.1.28", "Catppuccin mauve")
  assert_eq_int(state, color_parse("flamingo"), 0xFFF2CDCD, "F09.1.29", "Catppuccin flamingo")
  assert_eq_int(state, color_parse("rosewater"), 0xFFF5E0DC, "F09.1.30", "Catppuccin rosewater")
  assert_eq_int(state, color_parse("transparent"), 0, "F09.1.31", "named color transparent = 0")

  @! --------------------------------------------------------------------------
  @! SECTION 2: HTML Entity Decoder Adversarial Stress
  @! --------------------------------------------------------------------------
  println("\n--- Section 2: HTML Entity Decoding Stress ---")

  @! Standard 5 XML/HTML entities
  assert_eq_str(state, markup_decode_entities("&lt;&gt;&amp;&quot;&apos;"), "<>&\"'", "F09.2.1", "Standard entities decoded in sequence")
  assert_eq_str(state, markup_decode_entities("Hello &nbsp; World"), "Hello   World", "F09.2.2", "&nbsp; converted to space")
  assert_eq_str(state, markup_decode_entities("&#65;&#66;&#67;"), "ABC", "F09.2.3", "Decimal numeric entities &#65;&#66;&#67; -> ABC")
  assert_eq_str(state, markup_decode_entities("&#97;&#98;&#99;"), "abc", "F09.2.4", "Decimal numeric entities &#97;&#98;&#99; -> abc")

  @! Unresolved and malformed entity strings (must not loop or corrupt)
  assert_eq_str(state, markup_decode_entities("&&&"), "&&&", "F09.2.5", "Raw ampersands without semicolons preserved")
  assert_eq_str(state, markup_decode_entities("&unknown_custom_entity;"), "&unknown_custom_entity;", "F09.2.6", "Unknown entity preserved verbatim")
  assert_eq_str(state, markup_decode_entities("No entities here!"), "No entities here!", "F09.2.7", "Plain text without ampersand fast path")

  @! --------------------------------------------------------------------------
  @! SECTION 3: Dimension & Box Shorthand Parsing
  @! --------------------------------------------------------------------------
  println("\n--- Section 3: Dimension & Box Shorthand Parsing ---")

  assert_eq_int(state, parse_dimension("0px"), 0, "F09.3.1", "0px -> 0")
  assert_eq_int(state, parse_dimension("42px"), 42, "F09.3.2", "42px -> 42")
  assert_eq_int(state, parse_dimension("-15px"), -15, "F09.3.3", "-15px -> -15 (negative dimension)")
  assert_eq_int(state, parse_dimension("100%"), 100, "F09.3.4", "100% -> 100")
  assert_eq_int(state, parse_dimension("auto"), 0, "F09.3.5", "'auto' -> 0")
  assert_eq_int(state, parse_dimension("none"), 0, "F09.3.6", "'none' -> 0")

  b1 = parse_box_shorthand("10px")
  assert_eq_int(state, b1[0], 10, "F09.3.7", "1-value shorthand top=10")
  assert_eq_int(state, b1[1], 10, "F09.3.8", "1-value shorthand right=10")
  assert_eq_int(state, b1[2], 10, "F09.3.9", "1-value shorthand bottom=10")
  assert_eq_int(state, b1[3], 10, "F09.3.10", "1-value shorthand left=10")

  b2 = parse_box_shorthand("10px 20px")
  assert_eq_int(state, b2[0], 10, "F09.3.11", "2-value shorthand top=10")
  assert_eq_int(state, b2[1], 20, "F09.3.12", "2-value shorthand right=20")
  assert_eq_int(state, b2[2], 10, "F09.3.13", "2-value shorthand bottom=10")
  assert_eq_int(state, b2[3], 20, "F09.3.14", "2-value shorthand left=20")

  b3 = parse_box_shorthand("10px 20px 30px")
  assert_eq_int(state, b3[0], 10, "F09.3.15", "3-value shorthand top=10")
  assert_eq_int(state, b3[1], 20, "F09.3.16", "3-value shorthand right=20")
  assert_eq_int(state, b3[2], 30, "F09.3.17", "3-value shorthand bottom=30")
  assert_eq_int(state, b3[3], 20, "F09.3.18", "3-value shorthand left=20")

  b4 = parse_box_shorthand("5px 10px 15px 20px")
  assert_eq_int(state, b4[0], 5, "F09.3.19", "4-value shorthand top=5")
  assert_eq_int(state, b4[1], 10, "F09.3.20", "4-value shorthand right=10")
  assert_eq_int(state, b4[2], 15, "F09.3.21", "4-value shorthand bottom=15")
  assert_eq_int(state, b4[3], 20, "F09.3.22", "4-value shorthand left=20")

  @! --------------------------------------------------------------------------
  @! SECTION 4: CSS Declarations & Stylesheet Cascade Stress
  @! --------------------------------------------------------------------------
  println("\n--- Section 4: CSS Cascade & Specificity Resolution ---")

  css_text = "* { color: white; } div { width: 500px; padding: 10px; } .card { background-color: #1E1E2E; border-radius: 12px; } #main-hero { height: 350px; justify: space-between; }"
  sheet = css_parse_stylesheet(css_text)
  assert_eq_int(state, sheet.rules.len(), 4, "F09.4.1", "Stylesheet parsed 4 rules")

  @! Universal rule
  r0 = sheet.rules[0]
  assert_eq_int(state, r0.selector_type, 3, "F09.4.2", "Rule 0 is universal selector (*)")
  assert_eq_str(state, r0.selector_name, "*", "F09.4.3", "Rule 0 selector name is '*'")

  @! Tag rule
  r1 = sheet.rules[1]
  assert_eq_int(state, r1.selector_type, 0, "F09.4.4", "Rule 1 is tag selector (div)")
  assert_eq_str(state, r1.selector_name, "div", "F09.4.5", "Rule 1 selector name is 'div'")

  @! Class rule
  r2 = sheet.rules[2]
  assert_eq_int(state, r2.selector_type, 1, "F09.4.6", "Rule 2 is class selector (.card)")
  assert_eq_str(state, r2.selector_name, "card", "F09.4.7", "Rule 2 selector name is 'card'")

  @! ID rule
  r3 = sheet.rules[3]
  assert_eq_int(state, r3.selector_type, 2, "F09.4.8", "Rule 3 is ID selector (#main-hero)")
  assert_eq_str(state, r3.selector_name, "main-hero", "F09.4.9", "Rule 3 selector name is 'main-hero'")

  @! Inline style override test
  st_decl = css_parse_declarations("width: 800px; height: 400px; display: flex; flex-direction: row-reverse; justify-content: center; align-items: stretch; gap: 15px; margin: 10px 20px; border: 2px solid #FAB387; opacity: 0.85;")
  assert_eq_int(state, st_decl.style_width, 800, "F09.4.10", "Inline width = 800")
  assert_eq_int(state, st_decl.style_height, 400, "F09.4.11", "Inline height = 400")
  assert_eq_int(state, st_decl.style_display, 0, "F09.4.12", "Inline display = flex (0)")
  assert_eq_int(state, st_decl.style_flex_dir, 2, "F09.4.13", "Inline flex-direction = row-reverse (2)")
  assert_eq_int(state, st_decl.style_justify, 1, "F09.4.14", "Inline justify = center (1)")
  assert_eq_int(state, st_decl.style_align_items, 3, "F09.4.15", "Inline align-items = stretch (3)")
  assert_eq_int(state, st_decl.style_gap, 15, "F09.4.16", "Inline gap = 15")
  assert_eq_int(state, st_decl.style_margin_top, 10, "F09.4.17", "Inline margin-top = 10")
  assert_eq_int(state, st_decl.style_margin_right, 20, "F09.4.18", "Inline margin-right = 20")
  assert_eq_int(state, st_decl.style_border_width, 2, "F09.4.19", "Inline border-width = 2")
  assert_eq_int(state, st_decl.style_border_color, 0xFFFAB387, "F09.4.20", "Inline border-color = Catppuccin Peach")

  @! --------------------------------------------------------------------------
  @! SECTION 5: Malformed Markup, Unclosed Tags, Deep Nesting & Void Elements
  @! --------------------------------------------------------------------------
  println("\n--- Section 5: Malformed Markup & Fault Tolerance ---")

  @! 5.1 Deeply nested markup (16 levels deep)
  deep_src = "<div><div><div><div><div><div><div><div><div><div><div><div><div><div><div><span>Deeply Nested Sovereign Node</span></div></div></div></div></div></div></div></div></div></div></div></div></div></div></div>"
  deep_ast = parse_markup(deep_src)
  assert_eq_str(state, deep_ast.tag_name, "div", "F09.5.1", "Deep nesting root is div")
  curr = deep_ast
  lvl = 1
  @while curr.children.len() > 0 && curr.children[0].is_text == false
    curr = curr.children[0]
    lvl = lvl + 1
  @end
  assert_eq_int(state, lvl, 16, "F09.5.2", "Traversed exactly 16 levels down to span")
  assert_eq_str(state, curr.tag_name, "span", "F09.5.3", "Innermost node is span")
  assert_eq_str(state, curr.children[0].text_content, "Deeply Nested Sovereign Node", "F09.5.4", "Innermost text content intact")

  @! 5.2 Unclosed tags with stack unwinding
  unclosed_src = "<section class=\"container\"><header><h1>Title</h1><nav><a>Link 1</a><a>Link 2</a><main><article><p>Unclosed paragraph text"
  unclosed_ast = parse_markup(unclosed_src)
  assert_eq_str(state, unclosed_ast.tag_name, "section", "F09.5.5", "Unclosed tags unwind to root section")
  
  @! 5.3 Void elements (img, br, hr, input) mixed with siblings
  void_src = "<div><img src=\"avatar.png\"><br><input type=\"text\" value=\"sovereign\"><hr><p>Paragraph after void elements</p></div>"
  void_ast = parse_markup(void_src)
  assert_eq_str(state, void_ast.tag_name, "div", "F09.5.6", "Void elements container is div")
  assert_eq_int(state, void_ast.children.len(), 5, "F09.5.7", "Div contains 5 direct child siblings (img, br, input, hr, p)")
  assert_eq_str(state, void_ast.children[0].tag_name, "img", "F09.5.8", "First child is img")
  assert_eq_int(state, void_ast.children[0].children.len(), 0, "F09.5.9", "img has 0 children (does not trap br)")
  assert_eq_str(state, void_ast.children[1].tag_name, "br", "F09.5.10", "Second child is br")
  assert_eq_str(state, void_ast.children[2].tag_name, "input", "F09.5.11", "Third child is input")
  assert_eq_str(state, void_ast.children[3].tag_name, "hr", "F09.5.12", "Fourth child is hr")
  assert_eq_str(state, void_ast.children[4].tag_name, "p", "F09.5.13", "Fifth child is p")

  @! 5.4 Comments with special characters & nested fake tags
  comment_src = "<div><!-- <fake><tag> inside comment &amp; not parsed </fake> --><span>Real Content</span><!-- Another comment --></div>"
  comment_ast = parse_markup(comment_src)
  assert_eq_int(state, comment_ast.children.len(), 1, "F09.5.14", "Comments stripped; div contains only 1 child (span)")
  assert_eq_str(state, comment_ast.children[0].tag_name, "span", "F09.5.15", "Child is span")
  assert_eq_str(state, comment_ast.children[0].children[0].text_content, "Real Content", "F09.5.16", "Span content is 'Real Content'")

  @! --------------------------------------------------------------------------
  @! SECTION 6: AST Query Utilities (find_by_id, find_by_class, find_by_tag)
  @! --------------------------------------------------------------------------
  println("\n--- Section 6: AST Query Utilities Stress ---")

  query_src = "<div id=\"app\"><header class=\"header-bar\"><h1 class=\"title\">App Title</h1></header><div class=\"content\"><button id=\"submit-btn\" class=\"btn btn-primary\">Submit</button><button class=\"btn btn-secondary\">Cancel</button></div></div>"
  q_ast = parse_markup(query_src)

  @! Find by ID
  btn_node = markup_find_by_id(q_ast, "submit-btn")
  assert_true(state, btn_node != 0, "F09.6.1", "Found node with id 'submit-btn'")
  assert_eq_str(state, btn_node.tag_name, "button", "F09.6.2", "Node with id 'submit-btn' is button")
  assert_eq_str(state, btn_node.id_name, "submit-btn", "F09.6.3", "Node id_name is 'submit-btn'")

  missing_node = markup_find_by_id(q_ast, "non-existent-id")
  assert_eq_int(state, missing_node, 0, "F09.6.4", "Missing ID returns 0")

  @! Find by Class
  btns = markup_find_by_class(q_ast, "btn")
  assert_eq_int(state, btns.len(), 2, "F09.6.5", "Found 2 elements with class 'btn'")

  @! Find by Tag
  all_buttons = markup_find_by_tag(q_ast, "button")
  assert_eq_int(state, all_buttons.len(), 2, "F09.6.6", "Found 2 'button' tags")

  println("=================================================================")
  println("Adversarial F09 Test Results: " + int_to_str(state.passed) + "/" + int_to_str(state.total) + " passed, " + int_to_str(state.failed) + " failed.")
  @if state.failed == 0
    println("Verdict: FEATURE F09 RESILIENT & FULLY VERIFIED")
  @else
    println("Verdict: FAILURES DETECTED IN FEATURE F09")
  @end
  println("=================================================================")
@end
