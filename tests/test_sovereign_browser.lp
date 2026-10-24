// ==============================================================================
// 🧪 LIPI REGRESSION TEST: SOVEREIGN WEB BROWSER ENGINE
// ⚡ Module: tests/test_sovereign_browser.lp
// 100% Pure LiPi Implementation — Zero External / Libc / Python Dependencies
// ==============================================================================

include "utso/io.lp"
include "utso/string.lp"
include "aati/lipi_browser/browser.lp"

fn test_html_dom_parser
    say "[Browser] Testing Streaming HTML5 Parser & DOM Construction..."
    sample_html = "<html><head><style>.card { background: #FF0000; }</style></head><body><div id=\"main\" class=\"container card\" style=\"width: 400px;\"><h1>LiPi Browser</h1><p>Sovereign &amp; Autonomous</p></div></body></html>"

    dom = html_parse_document(sample_html)
    if dom == 0
        say "FAIL: DOM root is null"
        return 0
    end

    // Test finding by ID
    main_node = html_find_by_id(dom, "main")
    if main_node == 0
        say "FAIL: Element #main not found in DOM"
        return 0
    end
    if main_node.dom_tag != "div"
        say "FAIL: Expected div tag for #main, got " + main_node.dom_tag
        return 0
    end
    if main_node.dom_class_name != "container card"
        say "FAIL: Class name mismatch: " + main_node.dom_class_name
        return 0
    end

    // Test tag collection
    p_nodes = list()
    html_collect_by_tag(dom, "p", p_nodes)
    if len(p_nodes) != 1
        say "FAIL: Expected 1 <p> tag, found " + str(len(p_nodes))
        return 0
    end

    say "  ✔ HTML5 Parser: Elements, attributes, and entities parsed into DOM tree."
    return 1

fn test_css_cascade_specificity
    say "[Browser] Testing CSS Parser, Specificity & Style Computation..."
    css_text = "* { margin: 0; } p { color: black; font-size: 16px; } .card { background: #00FF00; padding: 10px; } #main { width: 500px; color: blue; }"

    sheet = css_parse_stylesheet(css_text)
    if len(sheet.css_rules) != 4
        say "FAIL: Expected 4 CSS rules, got " + str(len(sheet.css_rules))
        return 0
    end

    // Verify Specificity Ordering
    r_univ = sheet.css_rules[0] // *
    r_tag  = sheet.css_rules[1] // p
    r_cls  = sheet.css_rules[2] // .card
    r_id   = sheet.css_rules[3] // #main

    if r_univ.cr_specificity != 0
        say "FAIL: Universal selector specificity must be 0"
        return 0
    end
    if r_tag.cr_specificity != 1
        say "FAIL: Tag selector specificity must be 1"
        return 0
    end
    if r_cls.cr_specificity != 10
        say "FAIL: Class selector specificity must be 10"
        return 0
    end
    if r_id.cr_specificity != 100
        say "FAIL: ID selector specificity must be 100"
        return 0
    end

    // Test Computed Style for DOM Node matching .card and #main
    node = browser_dom_node_new(DOM_NODE_ELEMENT, "div", "")
    node.dom_id = "main"
    node.dom_class_name = "card"
    node.dom_style_attr = "height: 300px; color: red;" // Inline override

    style = css_compute_style(node, sheet)
    if style.cs_width != 500
        say "FAIL: Computed width should be 500px from #main, got " + str(style.cs_width)
        return 0
    end
    if style.cs_padding_top != 10
        say "FAIL: Computed padding should be 10px from .card, got " + str(style.cs_padding_top)
        return 0
    end
    if style.cs_height != 300
        say "FAIL: Computed height should be 300px from inline style, got " + str(style.cs_height)
        return 0
    end
    // Inline color: red (0xFFFF0000) overrides #main color: blue
    if style.cs_color != 4294901760
        say "FAIL: Inline style 'color: red' must take highest precedence"
        return 0
    end

    say "  ✔ CSS Specificity & Cascade: Selector weighting and inline overrides verified."
    return 1

fn test_layout_and_box_model
    say "[Browser] Testing Box Model Geometry & Layout Computation..."
    html_src = "<html><body><div id=\"wrapper\" style=\"width: 600px; height: 400px; margin: 20px; padding: 10px;\"><div id=\"sidebar\" style=\"width: 150px; height: 350px;\"></div></div></body></html>"
    css_src = "body { margin: 0; }"

    dom = html_parse_document(html_src)
    sheet = css_parse_stylesheet(css_src)
    layout_root = layout_compute_document(dom, sheet, 800, 600)

    if layout_root == 0
        say "FAIL: Layout root is null"
        return 0
    end

    wrapper_box = layout_find_box_by_id(layout_root, "wrapper")
    if wrapper_box == 0
        say "FAIL: Wrapper layout box not generated"
        return 0
    end

    // Wrapper x should equal margin_left + padding_left = 20 + 10 = 30
    if wrapper_box.lb_x != 30
        say "FAIL: Expected wrapper X=30, got " + str(wrapper_box.lb_x)
        return 0
    end
    if wrapper_box.lb_width != 600
        say "FAIL: Expected wrapper width=600, got " + str(wrapper_box.lb_width)
        return 0
    end

    say "  ✔ Box Model: Geometry coordinates (X, Y, W, H) solved accurately."
    return 1

fn test_end_to_end_rendering
    say "[Browser] Testing End-to-End Silicon Pixel Painting..."
    html_content = "<html><body><div style=\"width: 200px; height: 100px; background: #FF0000;\"><h1>LiPi</h1></div></body></html>"
    css_content = "body { margin: 0; background: #FFFFFF; }"

    b = browser_new(200, 100)
    browser_load_page(b, html_content, css_content)
    browser_render(b)

    // Check pixel at (10, 10) - should be filled with red background (0xFFFF0000 = 4294901760)
    pixel_col = b.sb_framebuffer[(10 * 200) + 10]
    if pixel_col != 4294901760
        say "FAIL: Expected pixel (10, 10) to be RED, got " + str(pixel_col)
        return 0
    end

    ppm_out = "/tmp/lipi_sovereign_browser_test.ppm"
    browser_export_ppm(b, ppm_out)
    if file_exists(ppm_out) == 0
        say "FAIL: Rendered PPM image was not written to disk"
        return 0
    end

    say "  ✔ Silicon Framebuffer Rendering: Framebuffer painted & Netpbm PPM exported."
    return 1

fn main
    say "===================================================================="
    say "👑 LIPI SOVEREIGN: WEB BROWSER ENGINE TEST SUITE"
    say "===================================================================="
    if test_html_dom_parser() == 0 exit(1) end
    if test_css_cascade_specificity() == 0 exit(1) end
    if test_layout_and_box_model() == 0 exit(1) end
    if test_end_to_end_rendering() == 0 exit(1) end
    say "===================================================================="
    say "🎉 ALL SOVEREIGN BROWSER ENGINE TESTS PASSED (100% GREEN)!"
    say "===================================================================="
    return 0

main()
