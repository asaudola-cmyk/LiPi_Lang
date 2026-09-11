@! ============================================================================
@! MAYA TIER 1 E2E TEST SUITE — FEATURE F09: SOVEREIGN MARKUP PARSER
@! Module: tests/e2e/tier1_features/web/test_f09_markup.maya
@! 100% Pure Maya Language — Zero External Dependencies
@! Coverage:
@! 1. Nested Tags AST Hierarchy
@! 2. Inline Style Parsing & Color Conversion
@! 3. Desugaring to LayoutNode Tree
@! 4. Self-Closing & Void Elements
@! 5. Text Node Extraction & Entity Decoding
@! 6. CSS Stylesheet Parsing & Selector Application
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/core/math"
import "universe/tools/maya_test"
import "universe/web/markup_parser"
import "universe/web/frontend/layout/layout_types"

@! ----------------------------------------------------------------------------
@! TEST 1: Nested Tags AST Hierarchy
@! ----------------------------------------------------------------------------
@fn test_f09_01_nested_tags_ast()
  source = "<div class=\"container\"><header id=\"head\"><h1>Maya Sovereign Engine</h1></header><main class=\"body\"><p>Paragraph 1</p><p>Paragraph 2</p></main></div>"
  
  root = parse_markup(source)
  assert_true(root.node_id > 0, "Root node ID should be positive")
  assert_str_eq(root.tag_name, "div", "Root element should be <div>")
  assert_eq(root.children.len(), 2, "Root <div> should have 2 children (<header> and <main>)")
  
  header_node = root.children[0]
  assert_str_eq(header_node.tag_name, "header", "First child should be <header>")
  assert_str_eq(header_node.id_name, "head", "Header should have id='head'")
  assert_eq(header_node.children.len(), 1, "Header should have 1 child (<h1>)")
  
  h1_node = header_node.children[0]
  assert_str_eq(h1_node.tag_name, "h1", "Child should be <h1>")
  assert_eq(h1_node.children.len(), 1, "<h1> should contain 1 text child")
  assert_str_eq(h1_node.children[0].text_content, "Maya Sovereign Engine", "<h1> text content match")
  
  main_node = root.children[1]
  assert_str_eq(main_node.tag_name, "main", "Second child should be <main>")
  assert_eq(main_node.children.len(), 2, "<main> should contain 2 <p> tags")
  assert_str_eq(main_node.children[0].tag_name, "p", "First paragraph tag")
  assert_str_eq(main_node.children[1].tag_name, "p", "Second paragraph tag")
  
  println("  [PASS] T1_F09_01: Nested Tags AST Hierarchy parsed correctly")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 2: Inline Style Parsing & Color Conversion
@! ----------------------------------------------------------------------------
@fn test_f09_02_inline_style_parsing()
  source = "<div style=\"display: flex; flex-direction: column; justify-content: center; align-items: stretch; width: 640px; height: 480px; padding: 15px; margin: 10px; gap: 8px; background: #1E1E2E; color: #CDD6F4; border: 2px solid #89B4FA;\"></div>"
  
  node = parse_markup(source)
  style = node.style
  
  assert_eq(style.style_flex_dir, 3, "flex-direction: column should decode to 3")
  assert_eq(style.style_justify, 1, "justify-content: center should decode to 1 (CENTER)")
  assert_eq(style.style_align_items, 3, "align-items: stretch should decode to 3 (STRETCH)")
  assert_eq(style.style_width, 640, "width should decode to 640")
  assert_eq(style.style_height, 480, "height should decode to 480")
  assert_eq(style.style_padding_top, 15, "padding-top should decode to 15")
  assert_eq(style.style_padding_left, 15, "padding-left should decode to 15")
  assert_eq(style.style_margin_top, 10, "margin-top should decode to 10")
  assert_eq(style.style_margin_left, 10, "margin-left should decode to 10")
  assert_eq(style.style_gap, 8, "gap should decode to 8")
  
  @! Background color #1E1E2E -> ARGB 0xFF1E1E2E
  assert_eq(style.style_bg_color, 0xFF1E1E2E, "background #1E1E2E matches 32-bit ARGB 0xFF1E1E2E")
  
  @! Text color #CDD6F4 -> ARGB 0xFFCDD6F4
  assert_eq(style.style_color, 0xFFCDD6F4, "color #CDD6F4 matches 32-bit ARGB 0xFFCDD6F4")
  
  @! Border color #89B4FA -> ARGB 0xFF89B4FA
  assert_eq(style.style_border_color, 0xFF89B4FA, "border #89B4FA matches 32-bit ARGB 0xFF89B4FA")
  assert_eq(style.style_border_width, 2, "border width should decode to 2")
  
  println("  [PASS] T1_F09_02: Inline Style Parsing & 32-bit ARGB color conversion")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 3: Desugaring to LayoutNode Tree
@! ----------------------------------------------------------------------------
@fn test_f09_03_desugar_to_layout_node()
  source = "<div style=\"display: flex; flex-direction: row; width: 800px; height: 600px; gap: 12px; padding: 24px;\"><div class=\"card-a\" style=\"flex-grow: 1; height: 200px;\">Left Card</div><div class=\"card-b\" style=\"flex-grow: 2; height: 200px;\">Right Card</div></div>"
  
  layout_root = markup_parse(source)
  
  assert_eq(layout_root.layout_type, 1, "Root layout type should be LAYOUT_FLEX_ROW (1)")
  assert_eq(layout_root.pref_width, 800, "Root pref_width should be 800")
  assert_eq(layout_root.pref_height, 600, "Root pref_height should be 600")
  assert_eq(layout_root.gap, 12, "Root gap should be 12")
  assert_eq(layout_root.padding.left, 24, "Root padding.left should be 24")
  assert_eq(layout_root.padding.top, 24, "Root padding.top should be 24")
  assert_eq(layout_root.children.len(), 2, "Layout root should have 2 children")
  
  card_a = layout_root.children[0]
  assert_eq(card_a.flex_grow, 1, "Card A flex-grow should be 1")
  assert_eq(card_a.pref_height, 200, "Card A pref_height should be 200")
  
  card_b = layout_root.children[1]
  assert_eq(card_b.flex_grow, 2, "Card B flex-grow should be 2")
  assert_eq(card_b.pref_height, 200, "Card B pref_height should be 200")
  
  println("  [PASS] T1_F09_03: Desugaring Markup AST to LayoutNode Tree")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 4: Self-Closing & Void Elements
@! ----------------------------------------------------------------------------
@fn test_f09_04_self_closing_and_void_elements()
  source = "<div class=\"gallery\"><img src=\"avatar.png\" width=\"120\" height=\"120\" /><input type=\"text\" value=\"search query\" /><hr /><br /><span>Label Text</span></div>"
  
  root = parse_markup(source)
  assert_str_eq(root.tag_name, "div", "Gallery root is <div>")
  assert_eq(root.children.len(), 5, "Gallery should contain 5 children (<img/>, <input/>, <hr/>, <br/>, <span>)")
  
  img_node = root.children[0]
  assert_str_eq(img_node.tag_name, "img", "First child is <img>")
  assert_eq(img_node.children.len(), 0, "<img> is self-closing leaf node")
  
  @! Verify attribute parsing
  attrs = img_node.attributes
  assert_true(attrs.len() >= 3, "<img> has src, width, height attributes")
  
  found_src = ""
  ai = 0
  @while ai < attrs.len()
    @if attrs[ai].attr_name == "src" found_src = attrs[ai].attr_value @end
    ai = ai + 1
  @end
  assert_str_eq(found_src, "avatar.png", "<img> src attribute value matches")
  
  span_node = root.children[4]
  assert_str_eq(span_node.tag_name, "span", "Last child is <span>")
  assert_eq(span_node.children.len(), 1, "<span> has 1 text child")
  assert_str_eq(span_node.children[0].text_content, "Label Text", "<span> text content matches")
  
  println("  [PASS] T1_F09_04: Self-Closing & Void Elements parsed with attribute fidelity")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 5: Text Node Extraction & Entity Decoding
@! ----------------------------------------------------------------------------
@fn test_f09_05_text_extraction_and_entity_decoding()
  source = "<div class=\"content\"><p>Maya &amp; Sovereign &lt;Web Engine&gt; &quot;Native&quot; &#39;Fast&#39; &copy;</p></div>"
  
  root = parse_markup(source)
  assert_eq(root.children.len(), 1, "Root has 1 <p> child")
  
  p_node = root.children[0]
  assert_eq(p_node.children.len(), 1, "<p> has 1 text child")
  
  text_node = p_node.children[0]
  assert_true(text_node.is_text, "Node is text node")
  
  @! Verify entity decoding: &amp; -> &, &lt; -> <, &gt; -> >, &quot; -> ", &#39; -> '
  decoded = text_node.text_content
  assert_true(string_contains(decoded, "&"), "Decoded & from &amp;")
  assert_true(string_contains(decoded, "<"), "Decoded < from &lt;")
  assert_true(string_contains(decoded, ">"), "Decoded > from &gt;")
  assert_true(string_contains(decoded, "\""), "Decoded \" from &quot;")
  assert_true(string_contains(decoded, "'"), "Decoded ' from &#39;")
  
  println("  [PASS] T1_F09_05: Text Node Extraction & Entity Decoding")
  return 1
@end

@! ----------------------------------------------------------------------------
@! TEST 6: CSS Stylesheet Parsing & Query Utilities
@! ----------------------------------------------------------------------------
@fn test_f09_06_css_stylesheet_and_queries()
  source = "<style>.card { width: 320px; background: #313244; } #hero { height: 180px; } span { color: #A6E3A1; }</style><div class=\"card\" id=\"hero\"><span>Card Content</span></div>"
  
  root = parse_markup(source)
  
  @! Query utilities
  by_id = markup_find_by_id(root, "hero")
  assert_true(by_id != 0, "Found node by ID 'hero'")
  assert_str_eq(by_id.id_name, "hero", "ID matches 'hero'")
  
  by_class = markup_find_by_class(root, "card")
  assert_eq(by_class.len(), 1, "Found 1 node with class 'card'")
  
  by_tag = markup_find_by_tag(root, "span")
  assert_eq(by_tag.len(), 1, "Found 1 node with tag 'span'")
  
  @! Verify stylesheet applied properties
  assert_eq(by_id.style.style_width, 320, "Class .card applied width: 320")
  assert_eq(by_id.style.style_height, 180, "ID #hero applied height: 180")
  assert_eq(by_id.style.style_bg_color, 0xFF313244, "Class .card applied background: #313244")
  
  span_node = by_tag[0]
  assert_eq(span_node.style.style_color, 0xFFA6E3A1, "Tag span applied color: #A6E3A1")
  
  println("  [PASS] T1_F09_06: CSS Stylesheet Parsing, Selector Application & AST Queries")
  return 1
@end

@! ----------------------------------------------------------------------------
@! Runner Function
@! ----------------------------------------------------------------------------
@fn run_f09_markup_tests()
  println("=================================================================")
  println("▶ [TIER 1] Feature F09: Sovereign Markup Parser Suite")
  println("=================================================================")
  
  passed = 0
  passed = passed + test_f09_01_nested_tags_ast()
  passed = passed + test_f09_02_inline_style_parsing()
  passed = passed + test_f09_03_desugar_to_layout_node()
  passed = passed + test_f09_04_self_closing_and_void_elements()
  passed = passed + test_f09_05_text_extraction_and_entity_decoding()
  passed = passed + test_f09_06_css_stylesheet_and_queries()
  
  println("-----------------------------------------------------------------")
  println("Feature F09 Results: " + passed.to_str() + "/6 tests passed.")
  assert_eq(passed, 6, "All F09 tests must pass")
  return passed
@end

@fn main()
  run_f09_markup_tests()
@end
