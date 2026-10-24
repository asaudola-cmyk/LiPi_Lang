// ==============================================================================
// 👑 LIPI SOVEREIGN WEB BROWSER: TOP-LEVEL ENGINE ORCHESTRATOR
// ⚡ Module: aati/lipi_browser/browser.lp
// 🏛️ Architecture: 100% Freestanding Web Browser Rendering directly to Silicon Pixels
// 100% Pure LiPi Implementation — Zero External / WebKit / Blink / Cairo Dependencies
// ==============================================================================

include "utso/io.lp"
include "utso/memory.lp"
include "utso/string.lp"
include "aati/lipi_browser/html_parser.lp"
include "aati/lipi_browser/css_engine.lp"
include "aati/lipi_browser/layout_engine.lp"
include "aati/lipi_browser/font_rasterizer.lp"

// ── 1. Sovereign Browser Architecture Model ───────────────────────────────────

struct SovereignBrowser
    sb_viewport_width
    sb_viewport_height
    sb_framebuffer
    sb_dom_root
    sb_stylesheet
    sb_layout_root

fn browser_new width height
    b = SovereignBrowser()
    b.sb_viewport_width = width
    b.sb_viewport_height = height
    b.sb_dom_root = 0
    b.sb_stylesheet = 0
    b.sb_layout_root = 0

    // Allocate 32-bit ARGB Framebuffer (default white background 0xFFFFFFFF)
    total_pixels = width * height
    buf = list()
    i = 0
    while i < total_pixels
        push(buf, 4294967295) // 0xFFFFFFFF
        i = i + 1
    end
    b.sb_framebuffer = buf
    return b

// ── 2. Loading HTML & Cascading CSS ───────────────────────────────────────────

fn browser_load_page browser html_str user_css
    if browser == 0 return 0 end

    // Step 1: Parse HTML DOM Tree
    browser.sb_dom_root = html_parse_document(html_str)

    // Step 2: Extract embedded <style> tags
    embedded_css = ""
    style_nodes = list()
    html_collect_by_tag(browser.sb_dom_root, "style", style_nodes)
    s_idx = 0
    while s_idx < len(style_nodes)
        st_node = style_nodes[s_idx]
        embedded_css = embedded_css + "\n" + st_node.dom_text_content
        s_idx = s_idx + 1
    end

    // Combine user stylesheet with embedded CSS
    full_css = user_css + "\n" + embedded_css
    browser.sb_stylesheet = css_parse_stylesheet(full_css)

    // Step 3: Compute Box Model & Geometry Coordinates
    browser.sb_layout_root = layout_compute_document(browser.sb_dom_root, browser.sb_stylesheet, browser.sb_viewport_width, browser.sb_viewport_height)
    return 1

// ── 3. Silicon Framebuffer Paint Engine ───────────────────────────────────────

fn browser_paint_box browser box
    if browser == 0 or box == 0 return 0 end
    buf = browser.sb_framebuffer
    bw = browser.sb_viewport_width
    bh = browser.sb_viewport_height
    st = box.lb_style

    // 1. Paint background fill (if specified and non-transparent)
    if st.cs_bg_color != 0
        raster_fill_rect(buf, bw, bh, box.lb_x, box.lb_y, box.lb_width, box.lb_height, st.cs_bg_color)
    end

    // 2. Paint text content (if text node or has text)
    if box.lb_node != 0 and box.lb_node.dom_node_type == DOM_NODE_TEXT and len(box.lb_node.dom_text_content) > 0
        raster_draw_text(buf, bw, bh, box.lb_node.dom_text_content, box.lb_x, box.lb_y, st.cs_font_size, st.cs_color)
    end

    // 3. Recursively paint all children in stacking order
    c_idx = 0
    while c_idx < len(box.lb_children)
        browser_paint_box(browser, box.lb_children[c_idx])
        c_idx = c_idx + 1
    end
    return 1

fn browser_render browser
    if browser == 0 or browser.sb_layout_root == 0 return 0 end
    // Clear viewport with white (0xFFFFFFFF)
    total_pixels = browser.sb_viewport_width * browser.sb_viewport_height
    p = 0
    while p < total_pixels
        browser.sb_framebuffer[p] = 4294967295
        p = p + 1
    end

    // Traverse and paint layout tree
    browser_paint_box(browser, browser.sb_layout_root)
    return 1

// ── 4. Standard Netpbm PPM Image Exporter ──────────────────────────────────────

fn browser_export_ppm browser filepath
    // WHY: Netpbm binary P6 format is universally supported and allows instant zero-copy
    // dumping of framebuffers without expensive string formatting.
    if browser == 0 or len(filepath) == 0 return 0 end

    w = browser.sb_viewport_width
    h = browser.sb_viewport_height
    buf = browser.sb_framebuffer

    header_str = "P6\n" + str(w) + " " + str(h) + "\n255\n"
    bytes = list()
    h_idx = 0
    h_len = len(header_str)
    while h_idx < h_len
        push(bytes, ord(char_at(header_str, h_idx)))
        h_idx = h_idx + 1
    end

    total_pixels = w * h
    p_idx = 0
    while p_idx < total_pixels
        pixel = buf[p_idx]
        push(bytes, raster_get_red(pixel))
        push(bytes, raster_get_green(pixel))
        push(bytes, raster_get_blue(pixel))
        p_idx = p_idx + 1
    end

    file_write_bytes(filepath, bytes)
    return 1

// ── 5. Sovereign High-Level Render API ────────────────────────────────────────

fn browser_render_page_to_ppm html_str css_str out_ppm_path width height
    b = browser_new(width, height)
    browser_load_page(b, html_str, css_str)
    browser_render(b)
    browser_export_ppm(b, out_ppm_path)
    return b
