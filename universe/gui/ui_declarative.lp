// ==============================================================================
// 👑 LIPI DECLARATIVE REACTIVE UI ENGINE (universe/gui/ui_declarative.lp)
// ⚡ 100% Pure Lipi | 0% HTML | 0% CSS | 0% JavaScript | Zero Web Dependencies
// ==============================================================================
//
// WHY: Modern web and application development is burdened by hundreds of megabytes
//      of browser engines, DOM trees, CSS reflow calculations, and JS runtimes.
//      Lipi achieves total UI sovereignty by defining declarative reactive component
//      trees in pure Lipi, computing layout constraints in pure integer arithmetic,
//      and rasterizing pixels directly into a 32-bit RGBA memory framebuffer.
// ==============================================================================

include "universe/core/memory.lp"

// ── Widget Type Constants ─────────────────────────────────────────────────────
UI_CONTAINER = 1
UI_ROW       = 2
UI_COLUMN    = 3
UI_TEXT      = 4
UI_BUTTON    = 5
UI_INPUT     = 6

// ── UI Event Type Constants ───────────────────────────────────────────────────
UI_EVENT_NONE       = 0
UI_EVENT_MOUSE_MOVE = 1
UI_EVENT_MOUSE_DOWN = 2
UI_EVENT_MOUSE_UP   = 3
UI_EVENT_KEY_DOWN   = 4

// ── 1. Reactive State Container ───────────────────────────────────────────────
// WHY: Reactive state allows automatic UI updates when underlying data changes.
// State container fields:
//   s[0]: current_value (int, string, or pointer)
//   s[1]: is_dirty (1 if modified, 0 if clean)
//   s[2]: listeners (list of widget references or actions)
fn ui_state_new initial_value
    s = list()
    push(s, initial_value) // 0: value
    push(s, 0)             // 1: is_dirty
    push(s, list())        // 2: listeners
    return s

fn ui_state_get state
    return get(state, 0)

fn ui_state_set state new_value
    list_set(state, 0, new_value)
    list_set(state, 1, 1) // Mark state dirty
    return new_value

fn ui_state_is_dirty state
    return get(state, 1)

fn ui_state_clean state
    list_set(state, 1, 0)
    return 0

// ── 2. Declarative Widget Node Structure ──────────────────────────────────────
// WHY: Using uniform array representation enables zero-overhead allocation and
//      fast indexed access across the recursive layout and rasterization tree.
// Node indices:
//   0: type (UI_CONTAINER..UI_INPUT)
//   1: id (string)
//   2: x (computed pixel x)
//   3: y (computed pixel y)
//   4: w (pixel width)
//   5: h (pixel height)
//   6: padding (int)
//   7: margin (int)
//   8: bg_color (0xRRGGBB)
//   9: text_color (0xRRGGBB)
//  10: text (string label or content)
//  11: children (list of child widgets)
//  12: on_click_action (integer action ID or callback identifier)
//  13: is_hovered (0 or 1)
//  14: is_pressed (0 or 1)
//  15: state_binding (UIState or 0)
//  16: flex_grow (int)

fn ui_node_new widget_type id
    w = list()
    push(w, widget_type) // 0: type
    push(w, id)          // 1: id
    push(w, 0)           // 2: x
    push(w, 0)           // 3: y
    push(w, 0)           // 4: w
    push(w, 0)           // 5: h
    push(w, 0)           // 6: padding
    push(w, 0)           // 7: margin
    push(w, 0)           // 8: bg_color
    push(w, 16777215)    // 9: text_color (default white: 0xFFFFFF)
    push(w, "")          // 10: text
    push(w, list())      // 11: children
    push(w, 0)           // 12: on_click_action
    push(w, 0)           // 13: is_hovered
    push(w, 0)           // 14: is_pressed
    push(w, 0)           // 15: state_binding
    push(w, 0)           // 16: flex_grow
    return w

// ── Declarative Component Builders ────────────────────────────────────────────

fn ui_container id bg_color padding margin children
    w = ui_node_new(UI_CONTAINER, id)
    list_set(w, 8, bg_color)
    list_set(w, 6, padding)
    list_set(w, 7, margin)
    list_set(w, 11, children)
    return w

fn ui_row id gap children
    w = ui_node_new(UI_ROW, id)
    list_set(w, 6, gap) // gap stored in padding slot
    list_set(w, 11, children)
    return w

fn ui_column id gap children
    w = ui_node_new(UI_COLUMN, id)
    list_set(w, 6, gap) // gap stored in padding slot
    list_set(w, 11, children)
    return w

fn ui_text id content color
    w = ui_node_new(UI_TEXT, id)
    list_set(w, 10, content)
    list_set(w, 9, color)
    // Approximate default text dimensions based on string length (8x16 font)
    list_set(w, 4, len(content) * 8)
    list_set(w, 5, 16)
    return w

fn ui_button id label bg_color text_color action_id
    w = ui_node_new(UI_BUTTON, id)
    list_set(w, 10, label)
    list_set(w, 8, bg_color)
    list_set(w, 9, text_color)
    list_set(w, 12, action_id)
    list_set(w, 6, 8) // default internal padding
    list_set(w, 4, (len(label) * 8) + 24)
    list_set(w, 5, 32)
    return w

fn ui_input id hint_text state_binding
    w = ui_node_new(UI_INPUT, id)
    list_set(w, 10, hint_text)
    list_set(w, 15, state_binding)
    list_set(w, 8, 2105376)  // 0x202020 dark background
    list_set(w, 9, 14474460) // 0xDCDCDC light text
    list_set(w, 4, 160)
    list_set(w, 5, 30)
    return w

// ── 3. Flexbox Constraint & Layout Solver ──────────────────────────────────────
// WHY: Resolves box-model geometry recursively from parent to children.
//      Computes exact bounding boxes without requiring CSS calc() or browser reflow.

fn ui_layout_resolve node origin_x origin_y avail_w avail_h
    wtype = get(node, 0)
    pad = get(node, 6)
    mar = get(node, 7)
    
    list_set(node, 2, origin_x + mar)
    list_set(node, 3, origin_y + mar)

    cur_x = origin_x + mar + pad
    cur_y = origin_y + mar + pad
    inner_w = avail_w - (mar * 2) - (pad * 2)
    inner_h = avail_h - (mar * 2) - (pad * 2)
    if inner_w < 0 inner_w = 0
    if inner_h < 0 inner_h = 0

    children = get(node, 11)
    ch_count = len(children)

    if wtype == UI_CONTAINER
        list_set(node, 4, avail_w)
        list_set(node, 5, avail_h)
        ci = 0
        while ci < ch_count
            child = get(children, ci)
            ui_layout_resolve(child, cur_x, cur_y, inner_w, inner_h)
            ci = ci + 1

    elif wtype == UI_COLUMN
        total_h = 0
        ci = 0
        while ci < ch_count
            child = get(children, ci)
            ui_layout_resolve(child, cur_x, cur_y, inner_w, 32)
            ch_h = get(child, 5)
            cur_y = cur_y + ch_h + pad
            total_h = total_h + ch_h + pad
            ci = ci + 1
        list_set(node, 4, inner_w)
        list_set(node, 5, total_h)

    elif wtype == UI_ROW
        total_w = 0
        max_ch_h = 0
        ci = 0
        while ci < ch_count
            child = get(children, ci)
            ui_layout_resolve(child, cur_x, cur_y, 100, inner_h)
            ch_w = get(child, 4)
            ch_h = get(child, 5)
            cur_x = cur_x + ch_w + pad
            total_w = total_w + ch_w + pad
            if ch_h > max_ch_h max_ch_h = ch_h
            ci = ci + 1
        list_set(node, 4, total_w)
        list_set(node, 5, max_ch_h)

    return 0

// ── 4. 2D Framebuffer Memory Rasterizer ────────────────────────────────────────
// WHY: Directly paints pixels into a linear 32-bit RGBA pixel buffer allocated via mmap.
//      Format: [R, G, B, A] per pixel at offset = ((y * buf_w) + x) * 4.

fn ui_draw_pixel buffer buf_w buf_h px py color_rgb
    if px < 0 or px >= buf_w or py < 0 or py >= buf_h
        return 0
    offset = ((py * buf_w) + px) * 4
    r = (color_rgb / 65536) % 256
    g = (color_rgb / 256) % 256
    b = color_rgb % 256
    mem_byte_write(buffer, offset, r)
    mem_byte_write(buffer, offset + 1, g)
    mem_byte_write(buffer, offset + 2, b)
    mem_byte_write(buffer, offset + 3, 255) // alpha = 255 (opaque)
    return 1

fn ui_draw_rect buffer buf_w buf_h rx ry rw rh color_rgb
    y = ry
    end_y = ry + rh
    if end_y > buf_h end_y = buf_h
    while y < end_y
        x = rx
        end_x = rx + rw
        if end_x > buf_w end_x = buf_w
        while x < end_x
            ui_draw_pixel(buffer, buf_w, buf_h, x, y, color_rgb)
            x = x + 1
        y = y + 1
    return rw * rh

// Simple 8x16 font glyph simulator: fills horizontal line segments for text visibility
fn ui_draw_text_sim buffer buf_w buf_h tx ty text color_rgb
    tlen = len(text)
    ti = 0
    while ti < tlen
        char_x = tx + (ti * 8)
        // Draw top, middle, and bottom accent lines for glyph silhouette
        ui_draw_rect(buffer, buf_w, buf_h, char_x + 1, ty + 2, 6, 2, color_rgb)
        ui_draw_rect(buffer, buf_w, buf_h, char_x + 1, ty + 7, 6, 2, color_rgb)
        ui_draw_rect(buffer, buf_w, buf_h, char_x + 1, ty + 12, 6, 2, color_rgb)
        ti = ti + 1
    return tlen

// Recursive tree rasterizer
fn ui_render_to_buffer node buffer buf_w buf_h
    wtype = get(node, 0)
    nx = get(node, 2)
    ny = get(node, 3)
    nw = get(node, 4)
    nh = get(node, 5)
    bg = get(node, 8)
    fg = get(node, 9)
    txt = get(node, 10)

    // Render background if set
    if bg > 0
        ui_draw_rect(buffer, buf_w, buf_h, nx, ny, nw, nh, bg)

    // Render widget content
    if wtype == UI_BUTTON
        // If hovered or pressed, alter background tint
        draw_bg = bg
        if get(node, 14) == 1
            draw_bg = bg + 2039583 // brighten on press
        ui_draw_rect(buffer, buf_w, buf_h, nx, ny, nw, nh, draw_bg)
        ui_draw_text_sim(buffer, buf_w, buf_h, nx + 10, ny + 8, txt, fg)

    elif wtype == UI_TEXT
        ui_draw_text_sim(buffer, buf_w, buf_h, nx, ny, txt, fg)

    elif wtype == UI_INPUT
        ui_draw_rect(buffer, buf_w, buf_h, nx, ny, nw, nh, bg)
        // Input border
        ui_draw_rect(buffer, buf_w, buf_h, nx, ny, nw, 1, 5592405) // top border
        ui_draw_rect(buffer, buf_w, buf_h, nx, ny + nh - 1, nw, 1, 5592405) // bottom border
        ui_draw_text_sim(buffer, buf_w, buf_h, nx + 6, ny + 7, txt, fg)

    // Recursively render all children
    children = get(node, 11)
    ch_count = len(children)
    ci = 0
    while ci < ch_count
        child = get(children, ci)
        ui_render_to_buffer(child, buffer, buf_w, buf_h)
        ci = ci + 1

    return 0

// ── 5. Event Dispatcher & Hit-Testing ─────────────────────────────────────────
// WHY: Dispatches input events (clicks, motion) through the tree, executes actions,
//      and updates reactive states without foreign event loop runtimes.

fn ui_dispatch_event node event_type mx my key_code
    nx = get(node, 2)
    ny = get(node, 3)
    nw = get(node, 4)
    nh = get(node, 5)

    hit = 0
    if mx >= nx and mx < (nx + nw) and my >= ny and my < (ny + nh)
        hit = 1

    wtype = get(node, 0)
    triggered_action = 0

    if hit == 1
        if event_type == UI_EVENT_MOUSE_MOVE
            list_set(node, 13, 1) // hovered
        elif event_type == UI_EVENT_MOUSE_DOWN
            list_set(node, 14, 1) // pressed
            if wtype == UI_BUTTON
                triggered_action = get(node, 12)
                // If button has a state binding, toggle or increment it
                st = get(node, 15)
                if st != 0
                    old_v = ui_state_get(st)
                    ui_state_set(st, old_v + 1)
        elif event_type == UI_EVENT_MOUSE_UP
            list_set(node, 14, 0) // unpressed
    else
        list_set(node, 13, 0) // not hovered
        list_set(node, 14, 0) // not pressed

    // Dispatch recursively to children
    children = get(node, 11)
    ci = 0
    while ci < len(children)
        child = get(children, ci)
        act = ui_dispatch_event(child, event_type, mx, my, key_code)
        if act > 0
            triggered_action = act
        ci = ci + 1

    return triggered_action
