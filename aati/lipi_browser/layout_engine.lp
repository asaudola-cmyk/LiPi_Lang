// ==============================================================================
// 👑 LIPI SOVEREIGN WEB BROWSER: BOX MODEL & MULTI-MODE LAYOUT ENGINE
// ⚡ Module: aati/lipi_browser/layout_engine.lp
// 🏛️ Architecture: Block, Inline, and Flexbox Formatting Models
// 100% Pure LiPi Implementation — Zero External / Libc / Python Dependencies
// ==============================================================================

include "utso/memory.lp"
include "utso/string.lp"
include "aati/lipi_browser/html_parser.lp"
include "aati/lipi_browser/css_engine.lp"

// ── 1. Layout Box Representation ──────────────────────────────────────────────

struct LayoutBox
    lb_node
    lb_style
    lb_x
    lb_y
    lb_width
    lb_height
    lb_children

fn layout_box_new node style
    box = LayoutBox()
    box.lb_node = node
    box.lb_style = style
    box.lb_x = 0
    box.lb_y = 0
    box.lb_width = 0
    box.lb_height = 0
    box.lb_children = list()
    return box

// ── 2. Layout Tree Builder from Styled DOM ────────────────────────────────────

fn layout_build_tree dom_node stylesheet
    if dom_node == 0 return 0 end
    style = css_compute_style(dom_node, stylesheet)

    // Skip elements with display: none or script/head/style elements
    if style.cs_display == "none" or dom_node.dom_tag == "head" or dom_node.dom_tag == "style" or dom_node.dom_tag == "script"
        return 0
    end

    box = layout_box_new(dom_node, style)

    c_idx = 0
    while c_idx < len(dom_node.dom_children)
        child_dom = dom_node.dom_children[c_idx]
        child_box = layout_build_tree(child_dom, stylesheet)
        if child_box != 0
            push(box.lb_children, child_box)
        end
        c_idx = c_idx + 1
    end

    return box

// ── 3. Text Dimension Estimator ───────────────────────────────────────────────

fn layout_measure_text text_str font_size
    // WHY: Character cell geometry estimation for vector/bitmap typography.
    // ASCII glyphs are typically ~0.6x font_size wide and 1.2x font_size tall.
    t_len = len(text_str)
    char_w = (font_size * 6) / 10
    if char_w < 5 char_w = 5 end
    char_h = (font_size * 12) / 10
    if char_h < 10 char_h = 10 end

    w = t_len * char_w
    h = char_h
    res = list()
    push(res, w)
    push(res, h)
    return res

// ── 4. Formatting Solvers: Block, Flexbox, Inline ──────────────────────────────

fn layout_solve_box box cur_x cur_y container_w
    if box == 0 return 0 end
    st = box.lb_style

    // Compute effective box width
    eff_w = container_w - (st.cs_margin_left + st.cs_margin_right + st.cs_padding_left + st.cs_padding_right)
    if eff_w < 0 eff_w = 0 end
    if st.cs_width > 0
        eff_w = st.cs_width
    end

    box.lb_x = cur_x + st.cs_margin_left + st.cs_padding_left
    box.lb_y = cur_y + st.cs_margin_top + st.cs_padding_top
    box.lb_width = eff_w

    // If text node, calculate text dimensions directly
    if box.lb_node != 0 and box.lb_node.dom_node_type == DOM_NODE_TEXT
        dims = layout_measure_text(box.lb_node.dom_text_content, st.cs_font_size)
        t_w = dims[0]
        t_h = dims[1]
        if t_w > eff_w and eff_w > 0
            // Multiline text wrapping height estimation
            lines = (t_w / eff_w) + 1
            box.lb_width = eff_w
            box.lb_height = lines * t_h
        else
            box.lb_width = t_w
            box.lb_height = t_h
        end
        return box.lb_height + st.cs_margin_top + st.cs_margin_bottom + st.cs_padding_top + st.cs_padding_bottom
    end

    // Flexbox Layout Solver
    if st.cs_display == "flex"
        total_h = layout_solve_flexbox(box, box.lb_x, box.lb_y, eff_w)
        if st.cs_height > 0
            box.lb_height = st.cs_height
        else
            box.lb_height = total_h
        end
        return box.lb_height + st.cs_margin_top + st.cs_margin_bottom + st.cs_padding_top + st.cs_padding_bottom
    end

    // Standard Block Layout Solver (Vertical Stacking)
    child_y = box.lb_y
    max_child_w = 0
    c_idx = 0
    while c_idx < len(box.lb_children)
        child = box.lb_children[c_idx]
        consumed_h = layout_solve_box(child, box.lb_x, child_y, eff_w)
        child_y = child_y + consumed_h
        if child.lb_width > max_child_w
            max_child_w = child.lb_width
        end
        c_idx = c_idx + 1
    end

    total_children_h = child_y - box.lb_y
    if st.cs_height > 0
        box.lb_height = st.cs_height
    else
        box.lb_height = total_children_h
    end

    return box.lb_height + st.cs_margin_top + st.cs_margin_bottom + st.cs_padding_top + st.cs_padding_bottom

fn layout_solve_flexbox box start_x start_y avail_w
    // WHY: 1-dimensional flex container solver along main and cross axes.
    st = box.lb_style
    is_row = 1
    if st.cs_flex_direction == "column"
        is_row = 0
    end

    num_children = len(box.lb_children)
    if num_children == 0 return 0 end

    if is_row == 1
        // Horizontal Flex Row
        // Step 1: Pre-measure intrinsic child widths
        total_child_w = 0
        max_child_h = 0
        c_idx = 0
        while c_idx < num_children
            child = box.lb_children[c_idx]
            c_w = 80 // Default intrinsic flex item width
            if child.lb_style.cs_width > 0
                c_w = child.lb_style.cs_width
            elif child.lb_node != 0 and child.lb_node.dom_node_type == DOM_NODE_TEXT
                dims = layout_measure_text(child.lb_node.dom_text_content, child.lb_style.cs_font_size)
                c_w = dims[0]
            end
            child.lb_width = c_w
            total_child_w = total_child_w + c_w + child.lb_style.cs_margin_left + child.lb_style.cs_margin_right
            c_idx = c_idx + 1
        end

        // Step 2: Main Axis Distribution (justify-content)
        free_space = avail_w - total_child_w
        if free_space < 0 free_space = 0 end

        offset_x = start_x
        gap = 0
        if st.cs_justify_content == "center"
            offset_x = start_x + (free_space / 2)
        elif st.cs_justify_content == "flex-end"
            offset_x = start_x + free_space
        elif st.cs_justify_content == "space-between" and num_children > 1
            gap = free_space / (num_children - 1)
        end

        // Step 3: Layout and position flex items
        k_idx = 0
        while k_idx < num_children
            child = box.lb_children[k_idx]
            child.lb_x = offset_x + child.lb_style.cs_margin_left
            child.lb_y = start_y + child.lb_style.cs_margin_top
            // Recursive children layout within item
            consumed_h = layout_solve_box(child, child.lb_x, child.lb_y, child.lb_width)
            if child.lb_height > max_child_h
                max_child_h = child.lb_height
            end
            offset_x = offset_x + child.lb_width + child.lb_style.cs_margin_left + child.lb_style.cs_margin_right + gap
            k_idx = k_idx + 1
        end

        return max_child_h
    else
        // Vertical Flex Column
        child_y = start_y
        c_idx = 0
        while c_idx < num_children
            child = box.lb_children[c_idx]
            consumed_h = layout_solve_box(child, start_x, child_y, avail_w)
            child_y = child_y + consumed_h
            c_idx = c_idx + 1
        end
        return child_y - start_y
    end

fn layout_compute_document root_dom stylesheet viewport_w viewport_h
    // Master entry point: builds layout tree and solves global coordinates
    layout_root = layout_build_tree(root_dom, stylesheet)
    if layout_root == 0 return 0 end

    layout_solve_box(layout_root, 0, 0, viewport_w)
    return layout_root

fn layout_find_box_by_id box target_id
    if box == 0 return 0 end
    if box.lb_node != 0 and box.lb_node.dom_id == target_id
        return box
    end
    c_idx = 0
    while c_idx < len(box.lb_children)
        res = layout_find_box_by_id(box.lb_children[c_idx], target_id)
        if res != 0 return res end
        c_idx = c_idx + 1
    end
    return 0
