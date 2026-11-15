// ==============================================================================
// 👑 LIPI WEBX SOVEREIGN WIDGET SUITE, VECTOR ICONS & PURE SVG CHART ENGINE
// Module: aati/lipi_web/webx_widgets.lp
// Milestone: Sovereign Full-Stack Paradigm (Eliminating Lucide, Chart.js, Radix & Headless UI)
// 100% Pure LiPi Implementation — Zero External / Node.js / C / Libc Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. React and Vue applications depend on hundreds of megabytes of npm dependencies
//    for simple icons (lucide-react, heroicons), charts (chart.js, recharts, d3),
//    and modern UI widgets (radix-ui, sonner, headlessui).
// 2. These packages cause massive bundle bloat, hydration lag, and supply-chain vulnerabilities.
//
// LIPI WEBX SOVEREIGN SOLUTION:
// - Sovereign Vector Icon Engine (webx_icon): Standard 24x24 SVG geometry for 20+ core UI icons.
// - Sovereign Pure SVG Chart Engine (webx_chart_bar, webx_chart_line, webx_chart_pie):
//   Mathematical coordinate projection & Bhaskara I trigonometric arc computation.
// - Sovereign Modern UI Widget Suite:
//   * webx_toast & webx_toast_container (Accessible notification alerts)
//   * webx_accordion (Collapsible region panels with aria-expanded states)
//   * webx_dropdown (Custom accessible select/combobox menus)
//   * webx_progress (Accessible progress bars with dynamic percentage scaling)
//   * webx_drawer (Sliding off-canvas dialog sheets with modal backdrop)
//   * webx_theme_toggle (Bi-directional Dark/Light mode theme switchers)
// ==============================================================================

include "utso/string.lp"
include "utso/collections.lp"
include "utso/core/math.lp"
include "aati/lipi_web/webx_primitives.lp"

// ==============================================================================
// ── 1. Sovereign Vector Icon Engine (Zero npm / Zero Network) ─────────────────
// ==============================================================================

fn webx_icon_path name
    // WHY: Maps standard icon identifier to exact 24x24 SVG geometry elements
    if name == "user"
        return "<path d=\"M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2\" /><circle cx=\"12\" cy=\"7\" r=\"4\" />"
    elif name == "check"
        return "<polyline points=\"20 6 9 17 4 12\" />"
    elif name == "alert"
        return "<path d=\"M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z\" /><line x1=\"12\" y1=\"9\" x2=\"12\" y2=\"13\" /><line x1=\"12\" y1=\"17\" x2=\"12.01\" y2=\"17\" />"
    elif name == "close"
        return "<line x1=\"18\" y1=\"6\" x2=\"6\" y2=\"18\" /><line x1=\"6\" y1=\"6\" x2=\"18\" y2=\"18\" />"
    elif name == "menu"
        return "<line x1=\"3\" y1=\"12\" x2=\"21\" y2=\"12\" /><line x1=\"3\" y1=\"6\" x2=\"21\" y2=\"6\" /><line x1=\"3\" y1=\"18\" x2=\"21\" y2=\"18\" />"
    elif name == "search"
        return "<circle cx=\"11\" cy=\"11\" r=\"8\" /><line x1=\"21\" y1=\"21\" x2=\"16.65\" y2=\"16.65\" />"
    elif name == "settings"
        return "<circle cx=\"12\" cy=\"12\" r=\"3\" /><path d=\"M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z\" />"
    elif name == "chevron" or name == "chevron-right"
        return "<polyline points=\"9 18 15 12 9 6\" />"
    elif name == "chevron-down"
        return "<polyline points=\"6 9 12 15 18 9\" />"
    elif name == "chevron-up"
        return "<polyline points=\"18 15 12 9 6 15\" />"
    elif name == "chevron-left"
        return "<polyline points=\"15 18 9 12 15 6\" />"
    elif name == "trash"
        return "<polyline points=\"3 6 5 6 21 6\" /><path d=\"M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2\" />"
    elif name == "edit"
        return "<path d=\"M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7\" /><path d=\"M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z\" />"
    elif name == "home"
        return "<path d=\"M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z\" /><polyline points=\"9 22 9 12 15 12 15 22\" />"
    elif name == "bell"
        return "<path d=\"M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9\" /><path d=\"M13.73 21a2 2 0 0 1-3.46 0\" />"
    elif name == "info"
        return "<circle cx=\"12\" cy=\"12\" r=\"10\" /><line x1=\"12\" y1=\"16\" x2=\"12\" y2=\"12\" /><line x1=\"12\" y1=\"8\" x2=\"12.01\" y2=\"8\" />"
    elif name == "lock"
        return "<rect x=\"3\" y=\"11\" width=\"18\" height=\"11\" rx=\"2\" ry=\"2\" /><path d=\"M7 11V7a5 5 0 0 1 10 0v4\" />"
    elif name == "sun"
        return "<circle cx=\"12\" cy=\"12\" r=\"5\" /><line x1=\"12\" y1=\"1\" x2=\"12\" y2=\"3\" /><line x1=\"12\" y1=\"21\" x2=\"12\" y2=\"23\" /><line x1=\"4.22\" y1=\"4.22\" x2=\"5.64\" y2=\"5.64\" /><line x1=\"18.36\" y1=\"18.36\" x2=\"19.78\" y2=\"19.78\" /><line x1=\"1\" y1=\"12\" x2=\"3\" y2=\"12\" /><line x1=\"21\" y1=\"12\" x2=\"23\" y2=\"12\" /><line x1=\"4.22\" y1=\"19.78\" x2=\"5.64\" y2=\"18.36\" /><line x1=\"18.36\" y1=\"5.64\" x2=\"19.78\" y2=\"4.22\" />"
    elif name == "moon"
        return "<path d=\"M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z\" />"
    elif name == "refresh"
        return "<polyline points=\"23 4 23 10 17 10\" /><polyline points=\"1 20 1 14 7 14\" /><path d=\"M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15\" />"
    elif name == "download"
        return "<path d=\"M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4\" /><polyline points=\"7 10 12 15 17 10\" /><line x1=\"12\" y1=\"15\" x2=\"12\" y2=\"3\" />"
    elif name == "filter"
        return "<polygon points=\"22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3\" />"
    end
    // Fallback circle dot
    return "<circle cx=\"12\" cy=\"12\" r=\"9\" /><circle cx=\"12\" cy=\"12\" r=\"3\" fill=\"currentColor\" />"

fn webx_icon_svg name size class_str
    // WHY: Returns raw self-contained SVG element markup string
    sz = 24
    if size > 0 sz = size end
    paths = webx_icon_path(name)

    svg = "<svg width=\"" + str(sz) + "\" height=\"" + str(sz) + "\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\""
    if len(class_str) > 0
        svg = svg + " class=\"" + class_str + "\""
    end
    svg = svg + " aria-hidden=\"true\">" + paths + "</svg>"
    return svg

fn webx_icon id name size class_str
    // WHY: Returns WebXNode containing sovereign SVG vector icon
    raw_svg = webx_icon_svg(name, size, class_str)
    return webx_raw(id, raw_svg)

// ==============================================================================
// ── 2. Sovereign Pure SVG & Canvas Chart Engine ───────────────────────────────
// ==============================================================================

fn webx_widget_chart_color_at idx
    // WHY: Consistent cycling 6-color categorical data palette
    m = idx % 6
    if m == 0 return "#3b82f6" end
    if m == 1 return "#10b981" end
    if m == 2 return "#f59e0b" end
    if m == 3 return "#8b5cf6" end
    if m == 4 return "#ec4899" end
    return "#06b6d4"

fn webx_widget_chart_bar id labels_list values_list width height class_str
    // WHY: Pure SVG Bar Chart with integer linear scaling and Y-axis gridlines
    n = len(values_list)
    if n == 0 or width <= 0 or height <= 0
        return webx_raw(id, "<svg id=\"" + id + "\" width=\"100\" height=\"50\"></svg>")
    end

    pad_l = 50
    pad_r = 20
    pad_t = 30
    pad_b = 40
    plot_w = width - pad_l - pad_r
    plot_h = height - pad_t - pad_b
    if plot_w <= 0 plot_w = 100 end
    if plot_h <= 0 plot_h = 100 end

    // Find maximum value
    max_val = 0
    vi = 0
    while vi < n
        v = get(values_list, vi)
        if v > max_val max_val = v end
        vi = vi + 1
    end
    if max_val <= 0 max_val = 100 end

    out = "<svg id=\"" + id + "\" width=\"" + str(width) + "\" height=\"" + str(height) + "\" viewBox=\"0 0 " + str(width) + " " + str(height) + "\""
    if len(class_str) > 0 out = out + " class=\"" + class_str + "\"" end
    out = out + " role=\"img\" aria-label=\"Bar Chart\">\n"

    // Background rect
    out = out + "  <rect width=\"" + str(width) + "\" height=\"" + str(height) + "\" fill=\"#0f172a\" rx=\"8\" />\n"

    // Y-axis gridlines & tick values (4 steps)
    step_i = 0
    while step_i <= 4
        y_pos = pad_t + (plot_h * step_i) / 4
        tick_val = max_val - (max_val * step_i) / 4
        out = out + "  <line x1=\"" + str(pad_l) + "\" y1=\"" + str(y_pos) + "\" x2=\"" + str(pad_l + plot_w) + "\" y2=\"" + str(y_pos) + "\" stroke=\"#334155\" stroke-dasharray=\"3 3\" />\n"
        out = out + "  <text x=\"" + str(pad_l - 8) + "\" y=\"" + str(y_pos + 4) + "\" fill=\"#64748b\" font-size=\"10\" text-anchor=\"end\">" + str(tick_val) + "</text>\n"
        step_i = step_i + 1
    end

    // X-axis baseline
    out = out + "  <line x1=\"" + str(pad_l) + "\" y1=\"" + str(pad_t + plot_h) + "\" x2=\"" + str(pad_l + plot_w) + "\" y2=\"" + str(pad_t + plot_h) + "\" stroke=\"#475569\" stroke-width=\"1.5\" />\n"

    // Bars
    slot_w = plot_w / n
    if slot_w < 1 slot_w = 1 end
    bar_w = (slot_w * 7) / 10
    if bar_w < 1 bar_w = 1 end
    if bar_w > slot_w bar_w = slot_w end
    bar_gap = (slot_w - bar_w) / 2
    if bar_gap < 0 bar_gap = 0 end

    bi = 0
    while bi < n
        v = get(values_list, bi)
        v_clamped = v
        if v_clamped < 0 v_clamped = 0 end
        bar_h = (v_clamped * plot_h) / max_val
        if bar_h < 0 bar_h = 0 end
        if bar_h > plot_h bar_h = plot_h end
        bx = pad_l + (bi * slot_w) + bar_gap
        by = pad_t + (plot_h - bar_h)
        bcol = webx_widget_chart_color_at(bi)

        out = out + "  <rect x=\"" + str(bx) + "\" y=\"" + str(by) + "\" width=\"" + str(bar_w) + "\" height=\"" + str(bar_h) + "\" rx=\"4\" fill=\"" + bcol + "\" />\n"
        // Value label above bar
        out = out + "  <text x=\"" + str(bx + bar_w / 2) + "\" y=\"" + str(by - 6) + "\" fill=\"#f8fafc\" font-size=\"11\" font-weight=\"600\" text-anchor=\"middle\">" + str(v) + "</text>\n"

        // X-axis label
        if bi < len(labels_list)
            lbl = get(labels_list, bi)
            out = out + "  <text x=\"" + str(bx + bar_w / 2) + "\" y=\"" + str(pad_t + plot_h + 18) + "\" fill=\"#94a3b8\" font-size=\"11\" text-anchor=\"middle\">" + lbl + "</text>\n"
        end
        bi = bi + 1
    end

    out = out + "</svg>"
    return webx_raw(id, out)

fn webx_widget_chart_line id labels_list values_list width height class_str
    // WHY: Pure SVG Line & Area Chart with polygon coordinates and point indicators
    n = len(values_list)
    if n == 0 or width <= 0 or height <= 0
        return webx_raw(id, "<svg id=\"" + id + "\" width=\"100\" height=\"50\"></svg>")
    end

    pad_l = 50
    pad_r = 20
    pad_t = 30
    pad_b = 40
    plot_w = width - pad_l - pad_r
    plot_h = height - pad_t - pad_b
    if plot_w <= 0 plot_w = 100 end
    if plot_h <= 0 plot_h = 100 end

    max_val = 0
    vi = 0
    while vi < n
        v = get(values_list, vi)
        if v > max_val max_val = v end
        vi = vi + 1
    end
    if max_val <= 0 max_val = 100 end

    out = "<svg id=\"" + id + "\" width=\"" + str(width) + "\" height=\"" + str(height) + "\" viewBox=\"0 0 " + str(width) + " " + str(height) + "\""
    if len(class_str) > 0 out = out + " class=\"" + class_str + "\"" end
    out = out + " role=\"img\" aria-label=\"Line Chart\">\n"

    // Background rect
    out = out + "  <rect width=\"" + str(width) + "\" height=\"" + str(height) + "\" fill=\"#0f172a\" rx=\"8\" />\n"

    // Y-axis gridlines
    step_i = 0
    while step_i <= 4
        y_pos = pad_t + (plot_h * step_i) / 4
        tick_val = max_val - (max_val * step_i) / 4
        out = out + "  <line x1=\"" + str(pad_l) + "\" y1=\"" + str(y_pos) + "\" x2=\"" + str(pad_l + plot_w) + "\" y2=\"" + str(y_pos) + "\" stroke=\"#334155\" stroke-dasharray=\"3 3\" />\n"
        out = out + "  <text x=\"" + str(pad_l - 8) + "\" y=\"" + str(y_pos + 4) + "\" fill=\"#64748b\" font-size=\"10\" text-anchor=\"end\">" + str(tick_val) + "</text>\n"
        step_i = step_i + 1
    end

    // X-axis baseline
    out = out + "  <line x1=\"" + str(pad_l) + "\" y1=\"" + str(pad_t + plot_h) + "\" x2=\"" + str(pad_l + plot_w) + "\" y2=\"" + str(pad_t + plot_h) + "\" stroke=\"#475569\" stroke-width=\"1.5\" />\n"

    // Points calculation
    pts_str = ""
    first_x = 0
    last_x = 0
    pi = 0
    while pi < n
        v = get(values_list, pi)
        v_clamped = v
        if v_clamped < 0 v_clamped = 0 end
        if n > 1
            px = pad_l + (pi * plot_w) / (n - 1)
        else
            px = pad_l + plot_w / 2
        end
        py = pad_t + plot_h - ((v_clamped * plot_h) / max_val)
        if py < pad_t py = pad_t end
        if py > (pad_t + plot_h) py = pad_t + plot_h end

        if pi == 0 first_x = px end
        if pi == (n - 1) last_x = px end

        pts_str = pts_str + str(px) + "," + str(py) + " "
        pi = pi + 1
    end

    // Semi-transparent area polygon under line
    base_y = pad_t + plot_h
    area_pts = pts_str + str(last_x) + "," + str(base_y) + " " + str(first_x) + "," + str(base_y)
    out = out + "  <polygon points=\"" + area_pts + "\" fill=\"rgba(59, 130, 246, 0.15)\" />\n"

    // Line polyline
    out = out + "  <polyline points=\"" + pts_str + "\" fill=\"none\" stroke=\"#3b82f6\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\" />\n"

    // Point circles and labels
    pi = 0
    while pi < n
        v = get(values_list, pi)
        v_clamped = v
        if v_clamped < 0 v_clamped = 0 end
        if n > 1
            px = pad_l + (pi * plot_w) / (n - 1)
        else
            px = pad_l + plot_w / 2
        end
        py = pad_t + plot_h - ((v_clamped * plot_h) / max_val)
        if py < pad_t py = pad_t end
        if py > (pad_t + plot_h) py = pad_t + plot_h end

        out = out + "  <circle cx=\"" + str(px) + "\" cy=\"" + str(py) + "\" r=\"4\" fill=\"#3b82f6\" stroke=\"#0f172a\" stroke-width=\"2\" />\n"
        out = out + "  <text x=\"" + str(px) + "\" y=\"" + str(py - 8) + "\" fill=\"#93c5fd\" font-size=\"10\" font-weight=\"600\" text-anchor=\"middle\">" + str(v) + "</text>\n"

        if pi < len(labels_list)
            lbl = get(labels_list, pi)
            out = out + "  <text x=\"" + str(px) + "\" y=\"" + str(pad_t + plot_h + 18) + "\" fill=\"#94a3b8\" font-size=\"11\" text-anchor=\"middle\">" + lbl + "</text>\n"
        end
        pi = pi + 1
    end

    out = out + "</svg>"
    return webx_raw(id, out)

fn webx_widget_chart_pie id labels_list values_list width height class_str
    // WHY: Pure SVG Pie Chart with exact fixed-point Bhaskara I trigonometric arc calculation
    n = len(values_list)
    if n == 0 or width <= 0 or height <= 0
        return webx_raw(id, "<svg id=\"" + id + "\" width=\"100\" height=\"50\"></svg>")
    end

    cx = width / 2 - 40
    cy = height / 2
    r = cy - 25
    if cx < r r = cx - 25 end
    if r < 30 r = 30 end

    // Compute total sum (ignoring non-positive degenerate slices)
    total = 0
    ti = 0
    while ti < n
        v = get(values_list, ti)
        if v > 0
            total = total + v
        end
        ti = ti + 1
    end
    if total <= 0 total = 1 end

    out = "<svg id=\"" + id + "\" width=\"" + str(width) + "\" height=\"" + str(height) + "\" viewBox=\"0 0 " + str(width) + " " + str(height) + "\""
    if len(class_str) > 0 out = out + " class=\"" + class_str + "\"" end
    out = out + " role=\"img\" aria-label=\"Pie Chart\">\n"
    out = out + "  <rect width=\"" + str(width) + "\" height=\"" + str(height) + "\" fill=\"#0f172a\" rx=\"8\" />\n"

    // Single item full circle edge case
    if n == 1
        col = webx_widget_chart_color_at(0)
        out = out + "  <circle cx=\"" + str(cx) + "\" cy=\"" + str(cy) + "\" r=\"" + str(r) + "\" fill=\"" + col + "\" />\n"
    else
        // Slices computation using Bhaskara I trigonometric formula
        cur_deg = 0
        si = 0
        while si < n
            v = get(values_list, si)
            v_clamped = v
            if v_clamped < 0 v_clamped = 0 end
            sweep_deg = (v_clamped * 360) / total
            if sweep_deg > 0
                start_deg = cur_deg
                end_deg = cur_deg + sweep_deg
                if si == (n - 1) end_deg = 360 end

                // SVG angles (0 deg = 12 o'clock, phase shift -90)
                a1 = start_deg - 90
                a2 = end_deg - 90

                // Trigonometric projection: cos = sin(angle + 90)
                cos1 = sin_fixed_deg(a1 + 90, 1000)
                sin1 = sin_fixed_deg(a1, 1000)
                cos2 = sin_fixed_deg(a2 + 90, 1000)
                sin2 = sin_fixed_deg(a2, 1000)

                x1 = cx + (r * cos1) / 1000
                y1 = cy + (r * sin1) / 1000
                x2 = cx + (r * cos2) / 1000
                y2 = cy + (r * sin2) / 1000

                large_arc = 0
                if sweep_deg > 180 large_arc = 1 end
                col = webx_widget_chart_color_at(si)

                path_d = "M " + str(cx) + " " + str(cy) + " L " + str(x1) + " " + str(y1) + " A " + str(r) + " " + str(r) + " 0 " + str(large_arc) + " 1 " + str(x2) + " " + str(y2) + " Z"
                out = out + "  <path d=\"" + path_d + "\" fill=\"" + col + "\" stroke=\"#0f172a\" stroke-width=\"1.5\" />\n"

                cur_deg = end_deg
            end
            si = si + 1
        end
    end

    // Legend on the right side
    leg_x = cx + r + 25
    leg_y = 35
    li = 0
    while li < n
        v = get(values_list, li)
        v_clamped = v
        if v_clamped < 0 v_clamped = 0 end
        pct = (v_clamped * 100) / total
        col = webx_widget_chart_color_at(li)
        item_y = leg_y + (li * 24)

        out = out + "  <rect x=\"" + str(leg_x) + "\" y=\"" + str(item_y) + "\" width=\"12\" height=\"12\" rx=\"2\" fill=\"" + col + "\" />\n"
        lbl = "Item " + str(li + 1)
        if li < len(labels_list) lbl = get(labels_list, li) end
        out = out + "  <text x=\"" + str(leg_x + 18) + "\" y=\"" + str(item_y + 10) + "\" fill=\"#cbd5e1\" font-size=\"11\">" + lbl + " (" + str(pct) + "%)</text>\n"
        li = li + 1
    end

    out = out + "</svg>"
    return webx_raw(id, out)

fn webx_widget_chart_canvas_script canvas_id chart_type labels_list values_list
    // WHY: Pure HTML5 Canvas 2D script generator with 0% external Chart.js dependency
    n = len(values_list)
    script = "<script>\n"
    script = script + "(function() {\n"
    script = script + "  const c = document.getElementById('" + canvas_id + "');\n"
    script = script + "  if (!c) return;\n"
    script = script + "  const ctx = c.getContext('2d');\n"
    script = script + "  const w = c.width;\n"
    script = script + "  const h = c.height;\n"
    script = script + "  ctx.fillStyle = '#0f172a';\n"
    script = script + "  ctx.fillRect(0, 0, w, h);\n"
    script = script + "  const data = ["
    i = 0
    while i < n
        script = script + str(get(values_list, i))
        if (i + 1) < n script = script + ", " end
        i = i + 1
    end
    script = script + "];\n"
    script = script + "  const max = Math.max(...data, 1);\n"
    script = script + "  const barW = (w - 60) / data.length;\n"
    script = script + "  data.forEach((val, i) => {\n"
    script = script + "    const barH = (val / max) * (h - 60);\n"
    script = script + "    ctx.fillStyle = '#3b82f6';\n"
    script = script + "    ctx.fillRect(30 + i * barW + 4, h - 30 - barH, barW - 8, barH);\n"
    script = script + "  });\n"
    script = script + "})();\n"
    script = script + "</script>"
    return script

// ==============================================================================
// ── 3. Sovereign Modern UI Widget Suite ───────────────────────────────────────
// ==============================================================================

WEBX_TOAST_INFO    = 1
WEBX_TOAST_SUCCESS = 2
WEBX_TOAST_WARNING = 3
WEBX_TOAST_ERROR   = 4

fn webx_toast id title message variant dismiss_action_id class_str
    // WHY: Headless accessible notification toast with ARIA roles and built-in iconography
    border_col = "border-blue-500"
    icon_name = "info"
    icon_col = "text-blue-400"
    aria_role = "status"

    if variant == WEBX_TOAST_SUCCESS
        border_col = "border-emerald-500"
        icon_name = "check"
        icon_col = "text-emerald-400"
    elif variant == WEBX_TOAST_WARNING
        border_col = "border-amber-500"
        icon_name = "alert"
        icon_col = "text-amber-400"
        aria_role = "alert"
    elif variant == WEBX_TOAST_ERROR
        border_col = "border-rose-500"
        icon_name = "alert"
        icon_col = "text-rose-400"
        aria_role = "alert"
    end

    cls = "flex items-center justify-between p-4 bg-slate-800 border " + border_col + " rounded-lg shadow-lg text-white " + class_str

    left_kids = list()
    push(left_kids, webx_icon(id + "_icon", icon_name, 20, icon_col))
    msg_box = webx_container(id + "_text", "flex flex-col gap-1", list())
    push(msg_box.node_children, webx_node_new(WEBX_NODE_TEXT, id + "_title", "span", title, "font-bold text-sm", 0))
    if len(message) > 0
        push(msg_box.node_children, webx_node_new(WEBX_NODE_TEXT, id + "_msg", "span", message, "text-xs text-slate-400", 0))
    end
    push(left_kids, msg_box)

    main_left = webx_container(id + "_left", "flex items-center gap-3", left_kids)

    // Dismiss close button
    close_btn = webx_button(id + "_dismiss", "×", dismiss_action_id, "text-slate-400 font-bold text-lg cursor-pointer")

    all_kids = list()
    push(all_kids, main_left)
    push(all_kids, close_btn)

    toast_node = webx_container(id, cls, all_kids)
    return toast_node

fn webx_toast_container id toasts_list position_class
    // WHY: Fixed viewport container for stacked toast notifications
    pos = "fixed bottom-4 right-4 z-50 flex flex-col gap-2"
    if len(position_class) > 0 pos = position_class end
    return webx_container(id, pos, toasts_list)

fn webx_accordion id titles_list contents_list open_idx toggle_action_id class_str
    // WHY: Accessible collapsible panel region with WAI-ARIA aria-expanded states
    tcount = len(titles_list)
    items = list()
    i = 0
    while i < tcount
        title_txt = get(titles_list, i)
        is_open = 0
        if i == open_idx is_open = 1 end

        item_kids = list()

        // Accordion Trigger Header
        h_kids = list()
        push(h_kids, webx_node_new(WEBX_NODE_TEXT, id + "_t_" + str(i), "span", title_txt, "font-semibold text-sm", 0))

        chevron_name = "chevron-down"
        if is_open == 1 chevron_name = "chevron-up" end
        push(h_kids, webx_icon(id + "_chev_" + str(i), chevron_name, 16, "text-slate-400"))

        trigger_cls = "w-full flex justify-between items-center p-4 bg-slate-800 text-white cursor-pointer"
        if is_open == 0 trigger_cls = trigger_cls + " rounded-lg" end
        trigger_btn = webx_node_new(WEBX_NODE_BUTTON, id + "_hdr_" + str(i), "button", "", trigger_cls, toggle_action_id)
        trigger_btn.node_children = h_kids
        push(item_kids, trigger_btn)

        // Accordion Body Panel
        if is_open == 1 and i < len(contents_list)
            body_content = get(contents_list, i)
            body_container = webx_container(id + "_panel_" + str(i), "p-4 bg-slate-900 border-x border-b border-slate-700 text-slate-300 rounded-b-lg", list())
            push(body_container.node_children, body_content)
            push(item_kids, body_container)
        end

        item_wrapper = webx_container(id + "_item_" + str(i), "flex flex-col border border-slate-700 rounded-lg overflow-hidden", item_kids)
        push(items, item_wrapper)
        i = i + 1
    end

    cls = "flex flex-col gap-2 " + class_str
    return webx_container(id, cls, items)

fn webx_dropdown id label options_list selected_idx is_open select_action_id class_str
    // WHY: Headless accessible custom dropdown select menu (role="combobox" & role="listbox")
    selected_label = label
    if selected_idx >= 0 and selected_idx < len(options_list)
        selected_label = get(options_list, selected_idx)
    end

    // Trigger button
    btn_kids = list()
    push(btn_kids, webx_node_new(WEBX_NODE_TEXT, id + "_label", "span", selected_label, "text-sm font-medium", 0))
    push(btn_kids, webx_icon(id + "_icon", "chevron-down", 16, "text-slate-400"))

    trigger = webx_node_new(WEBX_NODE_BUTTON, id + "_btn", "button", "", "flex justify-between items-center px-4 py-2 bg-slate-800 border border-slate-700 rounded-lg text-white w-full cursor-pointer", select_action_id)
    push(trigger.node_props, "aria-haspopup=\"listbox\"")
    if is_open == 1
        push(trigger.node_props, "aria-expanded=\"true\"")
    else
        push(trigger.node_props, "aria-expanded=\"false\"")
    end
    trigger.node_children = btn_kids

    root_kids = list()
    push(root_kids, trigger)

    // Dropdown popover list
    if is_open == 1
        opt_kids = list()
        oi = 0
        ocount = len(options_list)
        while oi < ocount
            opt_txt = get(options_list, oi)
            is_sel = 0
            if oi == selected_idx is_sel = 1 end

            row_kids = list()
            push(row_kids, webx_node_new(WEBX_NODE_TEXT, id + "_opt_txt_" + str(oi), "span", opt_txt, "text-sm", 0))
            if is_sel == 1
                push(row_kids, webx_icon(id + "_chk_" + str(oi), "check", 14, "text-emerald-400"))
            end

            opt_cls = "flex items-center justify-between px-4 py-2 hover:bg-slate-700 cursor-pointer text-slate-200"
            if is_sel == 1 opt_cls = opt_cls + " bg-slate-700 font-semibold" end

            opt_item = webx_node_new(WEBX_NODE_OPTION, id + "_opt_" + str(oi), "button", "", opt_cls, select_action_id)
            if is_sel == 1
                push(opt_item.node_props, "aria-selected=\"true\"")
            else
                push(opt_item.node_props, "aria-selected=\"false\"")
            end
            opt_item.node_children = row_kids
            push(opt_kids, opt_item)
            oi = oi + 1
        end

        menu_container = webx_node_new(WEBX_NODE_LISTBOX, id + "_menu", "div", "", "absolute mt-2 w-full bg-slate-800 border border-slate-700 rounded-lg shadow-lg z-50 overflow-hidden flex flex-col", 0)
        menu_container.node_children = opt_kids
        push(root_kids, menu_container)
    end

    cls = "relative w-64 " + class_str
    return webx_container(id, cls, root_kids)

fn webx_progress id current_val max_val label show_pct variant class_str
    // WHY: Accessible progress bar primitive (WAI-ARIA role="progressbar")
    if max_val <= 0 max_val = 100 end
    cur = current_val
    if cur < 0 cur = 0 end
    if cur > max_val cur = max_val end
    pct = (cur * 100) / max_val

    fill_color = "bg-blue-600"
    if variant == 2 fill_color = "bg-emerald-500" end
    if variant == 3 fill_color = "bg-amber-500" end
    if variant == 4 fill_color = "bg-rose-500" end

    root_kids = list()

    // Header label & percentage readout
    if len(label) > 0 or show_pct == 1
        hdr_kids = list()
        if len(label) > 0
            push(hdr_kids, webx_node_new(WEBX_NODE_TEXT, id + "_lbl", "span", label, "text-xs font-semibold text-slate-300", 0))
        end
        if show_pct == 1
            push(hdr_kids, webx_node_new(WEBX_NODE_TEXT, id + "_pct", "span", str(pct) + "%", "text-xs font-bold text-slate-400", 0))
        end
        hdr_row = webx_container(id + "_hdr", "flex justify-between items-center mb-1", hdr_kids)
        push(root_kids, hdr_row)
    end

    // Visual Track & Fill (rendered as raw inline HTML for exact percentage width)
    track_html = "<div role=\"progressbar\" aria-valuenow=\"" + str(cur) + "\" aria-valuemin=\"0\" aria-valuemax=\"" + str(max_val) + "\" class=\"w-full bg-slate-700 rounded-full h-3 overflow-hidden\"><div style=\"width: " + str(pct) + "%; height: 100%;\" class=\"" + fill_color + " rounded-full transition-all\"></div></div>"
    push(root_kids, webx_raw(id + "_track", track_html))

    cls = "w-full " + class_str
    return webx_container(id, cls, root_kids)

fn webx_drawer id is_open side title content_node close_action_id class_str
    // WHY: Accessible modal drawer sheet sliding from left, right, or bottom
    if is_open == 0
        // Dormant hidden sheet
        return webx_raw(id, "<aside id=\"" + id + "\" role=\"dialog\" aria-modal=\"true\" style=\"display: none;\"></aside>")
    end

    pos_cls = "fixed top-0 bottom-0 right-0 w-80"
    if side == "left" pos_cls = "fixed top-0 bottom-0 left-0 w-80" end
    if side == "bottom" pos_cls = "fixed bottom-0 left-0 right-0 max-h-96" end

    backdrop = webx_raw(id + "_backdrop", "<div class=\"fixed inset-0 bg-black bg-opacity-50 z-40 transition-all\"></div>")

    // Header with Title & Close Icon Button
    hdr_kids = list()
    push(hdr_kids, webx_node_new(WEBX_NODE_TEXT, id + "_title", "h3", title, "font-bold text-lg text-white", 0))
    close_btn = webx_button(id + "_close", "×", close_action_id, "text-slate-400 font-bold text-xl cursor-pointer")
    push(hdr_kids, close_btn)
    drawer_hdr = webx_container(id + "_hdr", "flex justify-between items-center mb-4 pb-2 border-b border-slate-700", hdr_kids)

    panel_kids = list()
    push(panel_kids, drawer_hdr)
    if content_node != 0
        push(panel_kids, content_node)
    end

    drawer_panel = webx_node_new(WEBX_NODE_DRAWER, id + "_panel", "aside", "", pos_cls + " z-50 bg-slate-900 border-slate-700 shadow-xl p-6 flex flex-col " + class_str, 0)
    push(drawer_panel.node_props, 1)
    drawer_panel.node_children = panel_kids

    root_kids = list()
    push(root_kids, backdrop)
    push(root_kids, drawer_panel)

    return webx_container(id, "drawer-wrapper", root_kids)

fn webx_theme_toggle id current_theme toggle_action_id class_str
    // WHY: Smooth theme switcher toggling dark/light states with SVG sun/moon icons
    is_dark = 1
    if current_theme == "light" is_dark = 0 end

    btn_kids = list()
    if is_dark == 1
        push(btn_kids, webx_icon(id + "_icon", "sun", 18, "text-amber-400"))
        push(btn_kids, webx_node_new(WEBX_NODE_TEXT, id + "_txt", "span", "Light Mode", "text-sm text-slate-300 font-medium", 0))
    else
        push(btn_kids, webx_icon(id + "_icon", "moon", 18, "text-slate-600"))
        push(btn_kids, webx_node_new(WEBX_NODE_TEXT, id + "_txt", "span", "Dark Mode", "text-sm text-slate-700 font-medium", 0))
    end

    btn_cls = "flex items-center gap-2 px-3 py-2 rounded-lg border border-slate-700 bg-slate-800 text-white cursor-pointer " + class_str
    if is_dark == 0
        btn_cls = "flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-200 bg-white text-gray-900 cursor-pointer " + class_str
    end

    toggle_btn = webx_node_new(WEBX_NODE_BUTTON, id, "button", "", btn_cls, toggle_action_id)
    toggle_btn.node_children = btn_kids
    return toggle_btn
