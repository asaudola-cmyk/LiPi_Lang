// ==============================================================================
// 👑 LIPI WEBX SOVEREIGN PURE SVG & CANVAS CHART ENGINE (webx_charts.lp)
// Module: aati/lipi_web/webx_charts.lp
// Milestone: Sovereign Full-Stack Paradigm (Displacing Chart.js, D3.js & Recharts)
// 100% Pure LiPi Implementation — Zero External / NPM / C / Libc Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Chart.js, D3, and Recharts add 150KB - 500KB of client-side JavaScript bloat,
//    incurring heavy V8 compilation lag, hydration latency, and runtime memory churn.
// 2. Client-side chart libraries fail in Server-Side Rendering (SSR), air-gapped
//    environments, and headless scraping without a heavy headless browser.
//
// LIPI WEBX SOVEREIGN SOLUTION:
// - 100% Pure Silicon LiPi Math: Fixed-point decidegree trigonometry (0.1 degree resolution)
//   and deterministic scaling algorithms.
// - Pure SVG Chart Synthesis: Direct string generation of crisp, responsive, high-contrast
//   vector charts with interactive hover attributes, gradients, and semantic ARIA roles.
// - Pure Canvas 2D Engine: Standalone high-DPI Retina canvas generation using 0% external JS.
// - WCAG 2.2 Accessible Shadow Table: Guaranteed accessibility for screen readers.
// - Full WebX Virtual Node Compatibility: Seamless placement into WebX UI container trees.
// ==============================================================================

include "utso/string.lp"
include "utso/collections.lp"
include "utso/math.lp"
include "aati/lipi_web/webx_primitives.lp"

// ==============================================================================
// ── 1. Color Palette System & Theme Tokens ─────────────────────────────────────
// ==============================================================================

fn webx_chart_color_at idx
    // WHY: Returns vibrant, high-contrast sovereign colors tuned for dark & light UI themes
    m = idx % 10
    if m < 0
        m = m + 10
    end
    if m == 0 return "#38bdf8" end // Cyan Sky
    if m == 1 return "#818cf8" end // Indigo Aura
    if m == 2 return "#34d399" end // Emerald Green
    if m == 3 return "#fbbf24" end // Solar Amber
    if m == 4 return "#f43f5e" end // Crimson Rose
    if m == 5 return "#a855f7" end // Royal Purple
    if m == 6 return "#06b6d4" end // Teal Azure
    if m == 7 return "#fb923c" end // Tangerine Orange
    if m == 8 return "#e879f9" end // Fuchsia Pink
    if m == 9 return "#4ade80" end // Matrix Lime
    return "#38bdf8"

// ==============================================================================
// ── 2. Fixed-Point Trigonometry & Mathematical Scalers ────────────────────────
// ==============================================================================

fn webx_chart_sin_decideg ddeg scale
    // WHY: Integer Bhaskara I rational sine approximation operating on decidegrees (0.1 deg).
    // Avoids floating-point non-determinism across silicon architectures while maintaining 0.002 accuracy.
    d = ddeg % 3600
    if d < 0
        d = d + 3600
    end
    sign = 1
    if d > 1800
        sign = -1
        d = d - 1800
    end
    if d > 900
        d = 1800 - d
    end
    term = d * (1800 - d)
    denom = 4050000 - term
    if denom == 0
        return 0
    end
    res = (4 * term * scale) / denom
    return res * sign

fn webx_chart_cos_decideg ddeg scale
    // WHY: Phase-shifted cosine using decidegrees: cos(theta) = sin(theta + 90 deg = theta + 900 decidegrees)
    return webx_chart_sin_decideg(ddeg + 900, scale)

fn webx_chart_min values
    // WHY: Computes minimum value across dataset in O(N) time with zero allocations
    n = len(values)
    if n == 0 return 0 end
    m = get(values, 0)
    i = 1
    while i < n
        v = get(values, i)
        if v < m
            m = v
        end
        i = i + 1
    end
    return m

fn webx_chart_max values
    // WHY: Computes maximum value across dataset in O(N) time with zero allocations
    n = len(values)
    if n == 0 return 0 end
    m = get(values, 0)
    i = 1
    while i < n
        v = get(values, i)
        if v > m
            m = v
        end
        i = i + 1
    end
    return m

fn webx_chart_sum values
    // WHY: Computes total cumulative sum of data points for proportional slice calculations
    n = len(values)
    total = 0
    i = 0
    while i < n
        total = total + get(values, i)
        i = i + 1
    end
    return total

fn webx_chart_positive_sum values
    // WHY: Computes sum of strictly positive values to safeguard pie slices against negative distortions
    n = len(values)
    total = 0
    i = 0
    while i < n
        v = get(values, i)
        if v > 0
            total = total + v
        end
        i = i + 1
    end
    return total

fn webx_chart_escape_xml str_val
    // WHY: Sanitizes category labels and titles to prevent XML/SVG injection (all 5 W3C entities)
    res = replace(str_val, "&", "&amp;")
    res = replace(res, "<", "&lt;")
    res = replace(res, ">", "&gt;")
    res = replace(res, "\"", "&quot;")
    res = replace(res, "'", "&#39;")
    return res

fn webx_chart_escape_js str_val
    // WHY: Sanitizes strings interpolated into <script> JS literals to prevent syntax errors and XSS
    res = replace(str_val, "\\", "\\\\")
    res = replace(res, "'", "\\'")
    res = replace(res, "\"", "\\\"")
    res = replace(res, "\n", "\\n")
    res = replace(res, "\r", "\\r")
    res = replace(res, "</script", "<\\/script")
    return res

fn webx_chart_styles chart_id
    // WHY: Inlines responsive scoped styles for smooth hover transitions and GPU-accelerated glow
    s = "<style>\n"
    s = s + "#" + chart_id + " { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; user-select: none; }\n"
    s = s + "#" + chart_id + " .webx-bar { cursor: pointer; transition: opacity 0.2s, transform 0.2s; }\n"
    s = s + "#" + chart_id + " .webx-bar:hover { opacity: 0.82; filter: drop-shadow(0 0 8px rgba(56, 189, 248, 0.7)); }\n"
    s = s + "#" + chart_id + " .webx-point { cursor: pointer; transition: r 0.2s, stroke-width 0.2s; }\n"
    s = s + "#" + chart_id + " .webx-point:hover { r: 7; stroke-width: 3.5; }\n"
    s = s + "#" + chart_id + " .webx-slice { cursor: pointer; transition: opacity 0.2s, transform 0.2s; }\n"
    s = s + "#" + chart_id + " .webx-slice:hover { opacity: 0.88; filter: drop-shadow(0 0 10px rgba(255, 255, 255, 0.4)); }\n"
    s = s + "</style>\n"
    return s

// ==============================================================================
// ── 3. Pure SVG Bar Chart Engine (webx_chart_bar) ─────────────────────────────
// ==============================================================================

fn webx_chart_bar id title labels values width height color
    // WHY: Synthesizes high-performance, crisp SVG bar charts with zero external JS.
    // Handles positive, zero, and negative values with proper baseline alignment,
    // horizontal gridlines, Y-axis tick marks, and accessibility tags.
    w_str = str(width)
    h_str = str(height)

    pad_top = 55
    pad_bottom = 60
    pad_left = 65
    pad_right = 30
    plot_w = width - pad_left - pad_right
    plot_h = height - pad_top - pad_bottom
    if plot_w < 50 plot_w = 50 end
    if plot_h < 50 plot_h = 50 end

    escaped_title = webx_chart_escape_xml(title)

    // Opening SVG envelope
    svg = "<svg id=\"" + id + "\" viewBox=\"0 0 " + w_str + " " + h_str + "\" width=\"100%\" height=\"" + h_str + "\" "
    svg = svg + "xmlns=\"http://www.w3.org/2000/svg\" role=\"img\" aria-label=\"" + escaped_title + "\">\n"
    svg = svg + webx_chart_styles(id)

    // Dark canvas background
    svg = svg + "<rect width=\"" + w_str + "\" height=\"" + h_str + "\" fill=\"#0f172a\" rx=\"8\" />\n"

    // Chart Title Header
    svg = svg + "<text x=\"" + str(pad_left) + "\" y=\"" + str(pad_top - 22) + "\" fill=\"#f8fafc\" font-size=\"16\" font-weight=\"700\">" + escaped_title + "</text>\n"

    n = len(values)
    if n == 0
        svg = svg + "<text x=\"" + str(width / 2) + "\" y=\"" + str(height / 2) + "\" text-anchor=\"middle\" fill=\"#64748b\" font-size=\"14\">No Data Available</text>\n"
        svg = svg + "</svg>"
        return svg
    end

    raw_min = webx_chart_min(values)
    raw_max = webx_chart_max(values)

    // Check if any negative values exist to prevent label collision
    has_neg = 0
    if raw_min < 0
        has_neg = 1
    end

    // Standardize baseline ranges
    if raw_min >= 0
        min_val = 0
        max_val = raw_max
        if max_val <= 0 max_val = 10 end
    elif raw_max <= 0
        min_val = raw_min
        max_val = 0
    else
        min_val = raw_min
        max_val = raw_max
    end

    val_range = max_val - min_val
    if val_range <= 0 val_range = 1 end

    // Y-Axis Ticks & Horizontal Gridlines (5 ticks: 0%, 25%, 50%, 75%, 100%)
    step = 0
    while step < 5
        tick_val = min_val + (val_range * step) / 4
        tick_y = pad_top + plot_h - (plot_h * step) / 4
        // Gridline
        svg = svg + "<line x1=\"" + str(pad_left) + "\" y1=\"" + str(tick_y) + "\" x2=\"" + str(pad_left + plot_w) + "\" y2=\"" + str(tick_y) + "\" stroke=\"#334155\" stroke-dasharray=\"3,3\" opacity=\"0.6\" />\n"
        // Tick label
        svg = svg + "<text x=\"" + str(pad_left - 10) + "\" y=\"" + str(tick_y + 4) + "\" text-anchor=\"end\" fill=\"#94a3b8\" font-size=\"11\">" + str(tick_val) + "</text>\n"
        step = step + 1
    end

    // Zero Baseline Axis
    zero_y = pad_top + ((max_val) * plot_h) / val_range
    svg = svg + "<line x1=\"" + str(pad_left) + "\" y1=\"" + str(zero_y) + "\" x2=\"" + str(pad_left + plot_w) + "\" y2=\"" + str(zero_y) + "\" stroke=\"#64748b\" stroke-width=\"1.5\" />\n"

    // Bars Rendering
    slot_w = plot_w / n
    if slot_w < 1 slot_w = 1 end
    bar_w = (slot_w * 65) / 100
    if bar_w < 4 bar_w = 4 end
    if bar_w > (slot_w - 2) bar_w = slot_w - 2 end
    if bar_w < 1 bar_w = 1 end

    // Category label Y position: shifted lower if negative values exist to guarantee no collision
    cat_lbl_y = pad_top + plot_h + 20
    if has_neg == 1
        cat_lbl_y = pad_top + plot_h + 34
    end

    i = 0
    while i < n
        val = get(values, i)
        lbl = ""
        if i < len(labels)
            lbl = get(labels, i)
        end
        escaped_lbl = webx_chart_escape_xml(lbl)

        bar_col = color
        if len(bar_col) == 0 or bar_col == "auto"
            bar_col = webx_chart_color_at(i)
        end

        bar_x = pad_left + i * slot_w + (slot_w - bar_w) / 2
        y_val = pad_top + ((max_val - val) * plot_h) / val_range

        if val >= 0
            bar_y = y_val
            bar_h = zero_y - y_val
            val_lbl_y = bar_y - 6
        else
            bar_y = zero_y
            bar_h = y_val - zero_y
            val_lbl_y = bar_y + bar_h + 14
        end

        if bar_h < 1 and val != 0
            bar_h = 1
        end

        // Bar rect with hover tooltip data attributes
        svg = svg + "<rect class=\"webx-bar\" id=\"" + id + "_bar_" + str(i) + "\" "
        svg = svg + "x=\"" + str(bar_x) + "\" y=\"" + str(bar_y) + "\" width=\"" + str(bar_w) + "\" height=\"" + str(bar_h) + "\" "
        svg = svg + "rx=\"3\" fill=\"" + bar_col + "\" "
        svg = svg + "data-index=\"" + str(i) + "\" data-label=\"" + escaped_lbl + "\" data-value=\"" + str(val) + "\" "
        svg = svg + "tabindex=\"0\" role=\"graphics-symbol\">\n"
        svg = svg + "  <title>" + escaped_lbl + ": " + str(val) + "</title>\n"
        svg = svg + "</rect>\n"

        // Value text label above/below bar
        svg = svg + "<text x=\"" + str(bar_x + bar_w / 2) + "\" y=\"" + str(val_lbl_y) + "\" text-anchor=\"middle\" fill=\"#f1f5f9\" font-size=\"11\" font-weight=\"600\">" + str(val) + "</text>\n"

        // X-axis category label
        svg = svg + "<text x=\"" + str(bar_x + bar_w / 2) + "\" y=\"" + str(cat_lbl_y) + "\" text-anchor=\"middle\" fill=\"#94a3b8\" font-size=\"12\">" + escaped_lbl + "</text>\n"

        i = i + 1
    end

    svg = svg + "</svg>"
    return svg

// ==============================================================================
// ── 4. Pure SVG Line Chart Engine (webx_chart_line) ───────────────────────────
// ==============================================================================

fn webx_chart_line id title labels values width height stroke_color fill_area
    // WHY: Synthesizes smooth, responsive SVG line & area charts with zero external JS.
    // Maps discrete data coordinates, renders connected polylines, circular point markers,
    // and optional gradient fills beneath the curve.
    w_str = str(width)
    h_str = str(height)

    pad_top = 55
    pad_bottom = 60
    pad_left = 65
    pad_right = 30
    plot_w = width - pad_left - pad_right
    plot_h = height - pad_top - pad_bottom
    if plot_w < 50 plot_w = 50 end
    if plot_h < 50 plot_h = 50 end

    escaped_title = webx_chart_escape_xml(title)

    str_col = stroke_color
    if len(str_col) == 0 or str_col == "auto"
        str_col = "#38bdf8"
    end

    // Opening SVG envelope
    svg = "<svg id=\"" + id + "\" viewBox=\"0 0 " + w_str + " " + h_str + "\" width=\"100%\" height=\"" + h_str + "\" "
    svg = svg + "xmlns=\"http://www.w3.org/2000/svg\" role=\"img\" aria-label=\"" + escaped_title + "\">\n"
    svg = svg + webx_chart_styles(id)

    // Optional Area Gradient Definition
    if fill_area == 1
        svg = svg + "<defs>\n"
        svg = svg + "  <linearGradient id=\"" + id + "_area_grad\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">\n"
        svg = svg + "    <stop offset=\"0%\" stop-color=\"" + str_col + "\" stop-opacity=\"0.42\" />\n"
        svg = svg + "    <stop offset=\"100%\" stop-color=\"" + str_col + "\" stop-opacity=\"0.02\" />\n"
        svg = svg + "  </linearGradient>\n"
        svg = svg + "</defs>\n"
    end

    // Dark canvas background
    svg = svg + "<rect width=\"" + w_str + "\" height=\"" + h_str + "\" fill=\"#0f172a\" rx=\"8\" />\n"

    // Chart Title Header
    svg = svg + "<text x=\"" + str(pad_left) + "\" y=\"" + str(pad_top - 22) + "\" fill=\"#f8fafc\" font-size=\"16\" font-weight=\"700\">" + escaped_title + "</text>\n"

    n = len(values)
    if n == 0
        svg = svg + "<text x=\"" + str(width / 2) + "\" y=\"" + str(height / 2) + "\" text-anchor=\"middle\" fill=\"#64748b\" font-size=\"14\">No Data Available</text>\n"
        svg = svg + "</svg>"
        return svg
    end

    min_val = webx_chart_min(values)
    max_val = webx_chart_max(values)
    if min_val == max_val
        max_val = min_val + 10
        if min_val >= 10
            min_val = min_val - 10
        else
            min_val = 0
        end
    end

    val_range = max_val - min_val
    if val_range <= 0 val_range = 1 end

    // Y-Axis Ticks & Horizontal Gridlines
    step = 0
    while step < 5
        tick_val = min_val + (val_range * step) / 4
        tick_y = pad_top + plot_h - (plot_h * step) / 4
        svg = svg + "<line x1=\"" + str(pad_left) + "\" y1=\"" + str(tick_y) + "\" x2=\"" + str(pad_left + plot_w) + "\" y2=\"" + str(tick_y) + "\" stroke=\"#334155\" stroke-dasharray=\"3,3\" opacity=\"0.6\" />\n"
        svg = svg + "<text x=\"" + str(pad_left - 10) + "\" y=\"" + str(tick_y + 4) + "\" text-anchor=\"end\" fill=\"#94a3b8\" font-size=\"11\">" + str(tick_val) + "</text>\n"
        step = step + 1
    end

    // Map point coordinates
    x_coords = list()
    y_coords = list()
    i = 0
    while i < n
        if n == 1
            px = pad_left + plot_w / 2
        else
            px = pad_left + (i * plot_w) / (n - 1)
        end
        v = get(values, i)
        py = pad_top + ((max_val - v) * plot_h) / val_range
        push(x_coords, px)
        push(y_coords, py)
        i = i + 1
    end

    // Build Polyline Path String (Handles n == 1 with explicit line segment for round cap rendering)
    first_x = get(x_coords, 0)
    first_y = get(y_coords, 0)
    if n == 1
        line_path = "M " + str(first_x) + " " + str(first_y) + " L " + str(first_x) + " " + str(first_y)
    else
        line_path = "M " + str(first_x) + " " + str(first_y)
        i = 1
        while i < n
            line_path = line_path + " L " + str(get(x_coords, i)) + " " + str(get(y_coords, i))
            i = i + 1
        end
    end

    // Area Fill Path beneath curve
    if fill_area == 1 and n > 1
        bottom_y = pad_top + plot_h
        last_x = get(x_coords, n - 1)
        area_path = line_path + " L " + str(last_x) + " " + str(bottom_y) + " L " + str(first_x) + " " + str(bottom_y) + " Z"
        svg = svg + "<path d=\"" + area_path + "\" fill=\"url(#" + id + "_area_grad)\" />\n"
    end

    // Line Path Stroke
    svg = svg + "<path d=\"" + line_path + "\" fill=\"none\" stroke=\"" + str_col + "\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\" />\n"

    // Circular Point Markers & Labels
    i = 0
    while i < n
        cx_val = get(x_coords, i)
        cy_val = get(y_coords, i)
        val = get(values, i)
        lbl = ""
        if i < len(labels)
            lbl = get(labels, i)
        end
        escaped_lbl = webx_chart_escape_xml(lbl)

        // Point circle
        svg = svg + "<circle class=\"webx-point\" id=\"" + id + "_pt_" + str(i) + "\" "
        svg = svg + "cx=\"" + str(cx_val) + "\" cy=\"" + str(cy_val) + "\" r=\"4.5\" "
        svg = svg + "fill=\"#0f172a\" stroke=\"" + str_col + "\" stroke-width=\"2.5\" "
        svg = svg + "data-index=\"" + str(i) + "\" data-label=\"" + escaped_lbl + "\" data-value=\"" + str(val) + "\">\n"
        svg = svg + "  <title>" + escaped_lbl + ": " + str(val) + "</title>\n"
        svg = svg + "</circle>\n"

        // Value text above point with generous 12px clearance
        svg = svg + "<text x=\"" + str(cx_val) + "\" y=\"" + str(cy_val - 12) + "\" text-anchor=\"middle\" fill=\"#cbd5e1\" font-size=\"11\" font-weight=\"600\">" + str(val) + "</text>\n"

        // X-axis category label
        svg = svg + "<text x=\"" + str(cx_val) + "\" y=\"" + str(pad_top + plot_h + 20) + "\" text-anchor=\"middle\" fill=\"#94a3b8\" font-size=\"12\">" + escaped_lbl + "</text>\n"

        i = i + 1
    end

    svg = svg + "</svg>"
    return svg

// ==============================================================================
// ── 4b. Pure SVG Sparkline Chart Engine (webx_chart_line_sparkline) ───────────
// ==============================================================================

fn webx_chart_line_sparkline id values width height stroke_color fill_area
    // WHY: Emits lightweight, zero-dependency sovereign SVG sparkline trendlines for high-density
    // telemetry ribbons, latency monitors, and KPI metrics. Renders zero client JS and zero external CSS.
    w_str = str(width)
    h_str = str(height)

    str_col = stroke_color
    if len(str_col) == 0 or str_col == "auto"
        str_col = "#38bdf8"
    end

    svg = "<svg id=\"" + id + "\" viewBox=\"0 0 " + w_str + " " + h_str + "\" width=\"100%\" height=\"" + h_str + "\" "
    svg = svg + "xmlns=\"http://www.w3.org/2000/svg\" role=\"img\" aria-label=\"Sparkline Trend\">\n"

    // Optional subtle gradient definition for area fill
    if fill_area == 1
        svg = svg + "  <defs>\n"
        svg = svg + "    <linearGradient id=\"" + id + "_spark_grad\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">\n"
        svg = svg + "      <stop offset=\"0%\" stop-color=\"" + str_col + "\" stop-opacity=\"0.35\" />\n"
        svg = svg + "      <stop offset=\"100%\" stop-color=\"" + str_col + "\" stop-opacity=\"0.0\" />\n"
        svg = svg + "    </linearGradient>\n"
        svg = svg + "  </defs>\n"
    end

    n = len(values)
    if n == 0
        // Baseline dashed rule when dataset is empty
        mid_y = height / 2
        svg = svg + "  <line x1=\"0\" y1=\"" + str(mid_y) + "\" x2=\"" + w_str + "\" y2=\"" + str(mid_y) + "\" stroke=\"#334155\" stroke-dasharray=\"2,2\" />\n"
        svg = svg + "</svg>"
        return svg
    end

    pad_y = 3
    if pad_y * 2 >= height
        pad_y = 1
    end
    plot_h = height - (pad_y * 2)
    if plot_h < 2
        plot_h = 2
    end

    min_val = webx_chart_min(values)
    max_val = webx_chart_max(values)

    val_range = max_val - min_val
    if val_range <= 0
        val_range = 1
    end

    x_coords = list()
    y_coords = list()
    i = 0
    while i < n
        if n == 1
            px = width / 2
        else
            px = (i * width) / (n - 1)
        end
        v = get(values, i)
        if max_val == min_val
            if max_val == 0
                py = height - pad_y
            else
                py = height / 2
            end
        else
            py = pad_y + ((max_val - v) * plot_h) / val_range
        end
        push(x_coords, px)
        push(y_coords, py)
        i = i + 1
    end

    first_x = get(x_coords, 0)
    first_y = get(y_coords, 0)
    if n == 1
        line_path = "M " + str(first_x) + " " + str(first_y) + " L " + str(first_x) + " " + str(first_y)
    else
        line_path = "M " + str(first_x) + " " + str(first_y)
        i = 1
        while i < n
            line_path = line_path + " L " + str(get(x_coords, i)) + " " + str(get(y_coords, i))
            i = i + 1
        end
    end

    if fill_area == 1 and n > 1
        last_x = get(x_coords, n - 1)
        bottom_y = height
        area_path = line_path + " L " + str(last_x) + " " + str(bottom_y) + " L " + str(first_x) + " " + str(bottom_y) + " Z"
        svg = svg + "  <path d=\"" + area_path + "\" fill=\"url(#" + id + "_spark_grad)\" />\n"
    end

    svg = svg + "  <path d=\"" + line_path + "\" fill=\"none\" stroke=\"" + str_col + "\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\" />\n"

    // Latest endpoint marker for real-time beacon pulse
    if n > 0
        last_px = get(x_coords, n - 1)
        last_py = get(y_coords, n - 1)
        svg = svg + "  <circle cx=\"" + str(last_px) + "\" cy=\"" + str(last_py) + "\" r=\"3\" fill=\"" + str_col + "\" />\n"
    end

    svg = svg + "</svg>"
    return svg

// ==============================================================================
// ── 5. Pure SVG Pie & Donut Chart Engine (webx_chart_pie) ─────────────────────
// ==============================================================================

fn webx_chart_pie id title labels values width height is_donut
    // WHY: Synthesizes high-performance, crisp SVG pie & donut charts with zero external JS.
    // Uses integer decidegree trigonometry (3600 decidegrees = 360 deg) for arc math,
    // computes SVG arc paths ("M cx cy L ... A r r ... Z"), renders center statistics,
    // and outputs a responsive legend layout.
    w_str = str(width)
    h_str = str(height)

    escaped_title = webx_chart_escape_xml(title)

    // Opening SVG envelope
    svg = "<svg id=\"" + id + "\" viewBox=\"0 0 " + w_str + " " + h_str + "\" width=\"100%\" height=\"" + h_str + "\" "
    svg = svg + "xmlns=\"http://www.w3.org/2000/svg\" role=\"img\" aria-label=\"" + escaped_title + "\">\n"
    svg = svg + webx_chart_styles(id)

    // Dark canvas background
    svg = svg + "<rect width=\"" + w_str + "\" height=\"" + h_str + "\" fill=\"#0f172a\" rx=\"8\" />\n"

    // Chart Title Header
    svg = svg + "<text x=\"30\" y=\"35\" fill=\"#f8fafc\" font-size=\"16\" font-weight=\"700\">" + escaped_title + "</text>\n"

    n = len(values)
    if n == 0
        svg = svg + "<text x=\"" + str(width / 2) + "\" y=\"" + str(height / 2) + "\" text-anchor=\"middle\" fill=\"#64748b\" font-size=\"14\">No Data Available</text>\n"
        svg = svg + "</svg>"
        return svg
    end

    total = webx_chart_positive_sum(values)
    if total <= 0
        svg = svg + "<text x=\"" + str(width / 2) + "\" y=\"" + str(height / 2) + "\" text-anchor=\"middle\" fill=\"#64748b\" font-size=\"14\">Total is Zero</text>\n"
        svg = svg + "</svg>"
        return svg
    end

    // Layout configuration (Side-by-side: Pie on left, Legend on right)
    center_x = (width * 35) / 100
    center_y = height / 2 + 10
    avail_w = center_x - 30
    avail_h = height / 2 - 40
    outer_r = min(avail_w, avail_h)
    if outer_r < 30 outer_r = 30 end

    if is_donut == 1
        inner_r = (outer_r * 58) / 100
    else
        inner_r = 0
    end

    // Find the last index that contains a positive non-zero value
    last_pos_idx = -1
    chk_i = 0
    while chk_i < n
        if get(values, chk_i) > 0
            last_pos_idx = chk_i
        end
        chk_i = chk_i + 1
    end

    curr_decideg = 0
    i = 0
    while i < n
        val = get(values, i)
        lbl = ""
        if i < len(labels)
            lbl = get(labels, i)
        end
        escaped_lbl = webx_chart_escape_xml(lbl)
        col = webx_chart_color_at(i)
        
        pct = 0
        if val > 0
            pct = (val * 100) / total
        end

        // Slices with val <= 0 get 0 decidegrees strictly
        if val <= 0
            slice_span = 0
        else
            slice_span = (val * 3600) / total
            // Only the last positive slice absorbs the closing rounding difference
            if i == last_pos_idx
                slice_span = 3600 - curr_decideg
            end
        end
        if slice_span < 0 slice_span = 0 end

        start_ddeg = curr_decideg
        end_ddeg = curr_decideg + slice_span
        curr_decideg = end_ddeg

        // Handle full circle (Only if single slice or span >= 3600)
        if n == 1 or slice_span >= 3600
            if is_donut == 1
                mid_r = (outer_r + inner_r) / 2
                stroke_w = outer_r - inner_r
                svg = svg + "<circle class=\"webx-slice\" id=\"" + id + "_slice_" + str(i) + "\" "
                svg = svg + "cx=\"" + str(center_x) + "\" cy=\"" + str(center_y) + "\" r=\"" + str(mid_r) + "\" "
                svg = svg + "fill=\"none\" stroke=\"" + col + "\" stroke-width=\"" + str(stroke_w) + "\" "
                svg = svg + "data-index=\"" + str(i) + "\" data-label=\"" + escaped_lbl + "\" data-value=\"" + str(val) + "\" data-percentage=\"" + str(pct) + "%\" "
                svg = svg + "tabindex=\"0\" role=\"graphics-symbol\">\n"
                svg = svg + "  <title>" + escaped_lbl + ": " + str(val) + " (" + str(pct) + "%)</title>\n"
                svg = svg + "</circle>\n"
            else
                svg = svg + "<circle class=\"webx-slice\" id=\"" + id + "_slice_" + str(i) + "\" "
                svg = svg + "cx=\"" + str(center_x) + "\" cy=\"" + str(center_y) + "\" r=\"" + str(outer_r) + "\" "
                svg = svg + "fill=\"" + col + "\" "
                svg = svg + "data-index=\"" + str(i) + "\" data-label=\"" + escaped_lbl + "\" data-value=\"" + str(val) + "\" data-percentage=\"" + str(pct) + "%\" "
                svg = svg + "tabindex=\"0\" role=\"graphics-symbol\">\n"
                svg = svg + "  <title>" + escaped_lbl + ": " + str(val) + " (" + str(pct) + "%)</title>\n"
                svg = svg + "</circle>\n"
            end
        elif slice_span > 0
            // Cartesian angles (Clockwise from 12 o'clock: phi = decideg - 900)
            phi1 = start_ddeg - 900
            phi2 = end_ddeg - 900

            x_out1 = center_x + (outer_r * webx_chart_cos_decideg(phi1, 1000)) / 1000
            y_out1 = center_y + (outer_r * webx_chart_sin_decideg(phi1, 1000)) / 1000
            x_out2 = center_x + (outer_r * webx_chart_cos_decideg(phi2, 1000)) / 1000
            y_out2 = center_y + (outer_r * webx_chart_sin_decideg(phi2, 1000)) / 1000

            // If start and end points round to identical pixel coordinates on near-complete arcs, offset by 1
            if x_out1 == x_out2 and y_out1 == y_out2
                x_out2 = x_out2 - 1
            end

            large_arc = 0
            if slice_span > 1800
                large_arc = 1
            end

            if is_donut == 0
                // Solid pie wedge: center -> outer_start -> arc to outer_end -> close
                path_d = "M " + str(center_x) + " " + str(center_y) + " L " + str(x_out1) + " " + str(y_out1) + " "
                path_d = path_d + "A " + str(outer_r) + " " + str(outer_r) + " 0 " + str(large_arc) + " 1 " + str(x_out2) + " " + str(y_out2) + " Z"
            else
                // Donut arc sector: outer_start -> arc to outer_end -> line to inner_end -> reverse arc to inner_start -> close
                x_in1 = center_x + (inner_r * webx_chart_cos_decideg(phi1, 1000)) / 1000
                y_in1 = center_y + (inner_r * webx_chart_sin_decideg(phi1, 1000)) / 1000
                x_in2 = center_x + (inner_r * webx_chart_cos_decideg(phi2, 1000)) / 1000
                y_in2 = center_y + (inner_r * webx_chart_sin_decideg(phi2, 1000)) / 1000

                if x_in1 == x_in2 and y_in1 == y_in2
                    x_in2 = x_in2 - 1
                end

                path_d = "M " + str(x_out1) + " " + str(y_out1) + " "
                path_d = path_d + "A " + str(outer_r) + " " + str(outer_r) + " 0 " + str(large_arc) + " 1 " + str(x_out2) + " " + str(y_out2) + " "
                path_d = path_d + "L " + str(x_in2) + " " + str(y_in2) + " "
                path_d = path_d + "A " + str(inner_r) + " " + str(inner_r) + " 0 " + str(large_arc) + " 0 " + str(x_in1) + " " + str(y_in1) + " Z"
            end

            svg = svg + "<path class=\"webx-slice\" id=\"" + id + "_slice_" + str(i) + "\" "
            svg = svg + "d=\"" + path_d + "\" fill=\"" + col + "\" "
            svg = svg + "data-index=\"" + str(i) + "\" data-label=\"" + escaped_lbl + "\" data-value=\"" + str(val) + "\" data-percentage=\"" + str(pct) + "%\" "
            svg = svg + "tabindex=\"0\" role=\"graphics-symbol\">\n"
            svg = svg + "  <title>" + escaped_lbl + ": " + str(val) + " (" + str(pct) + "%)</title>\n"
            svg = svg + "</path>\n"
        end

        i = i + 1
    end

    // Donut Center Statistic Text
    if is_donut == 1
        svg = svg + "<text x=\"" + str(center_x) + "\" y=\"" + str(center_y - 2) + "\" text-anchor=\"middle\" fill=\"#f8fafc\" font-size=\"18\" font-weight=\"700\">" + str(total) + "</text>\n"
        svg = svg + "<text x=\"" + str(center_x) + "\" y=\"" + str(center_y + 16) + "\" text-anchor=\"middle\" fill=\"#94a3b8\" font-size=\"11\">Total</text>\n"
    end

    // Right-Hand Responsive Legend
    legend_x = (width * 63) / 100
    legend_start_y = center_y - (n * 24) / 2
    if legend_start_y < 50 legend_start_y = 50 end

    i = 0
    while i < n
        val = get(values, i)
        lbl = ""
        if i < len(labels)
            lbl = get(labels, i)
        end
        escaped_lbl = webx_chart_escape_xml(lbl)
        col = webx_chart_color_at(i)
        
        pct = 0
        if val > 0
            pct = (val * 100) / total
        end

        item_y = legend_start_y + i * 26

        // Color indicator pill
        svg = svg + "<rect x=\"" + str(legend_x) + "\" y=\"" + str(item_y - 10) + "\" width=\"12\" height=\"12\" rx=\"3\" fill=\"" + col + "\" />\n"
        // Label and percentage text
        svg = svg + "<text x=\"" + str(legend_x + 20) + "\" y=\"" + str(item_y) + "\" fill=\"#e2e8f0\" font-size=\"12\" font-weight=\"500\">" + escaped_lbl + ": <tspan fill=\"#94a3b8\">" + str(val) + " (" + str(pct) + "%)</tspan></text>\n"

        i = i + 1
    end

    svg = svg + "</svg>"
    return svg

// ==============================================================================
// ── 6. Sovereign Pure Canvas 2D Engine (0% External JS / 0% Libs) ─────────────
// ==============================================================================

fn webx_chart_canvas_bar id title labels values width height color
    // WHY: Emits standalone HTML5 Canvas + inline zero-dependency native JS routine.
    // Handles high-DPI Retina scaling, dark mode backgrounds, horizontal gridlines,
    // sovereign 10-color categorical palette cycling, and responsive bar rendering.
    escaped_title_js = webx_chart_escape_js(title)
    w_str = str(width)
    h_str = str(height)

    html = "<div class=\"webx-canvas-container\" style=\"display:inline-block; border-radius:8px; overflow:hidden;\">\n"
    html = html + "  <canvas id=\"" + id + "\" width=\"" + w_str + "\" height=\"" + h_str + "\" style=\"width:" + w_str + "px; height:" + h_str + "px; display:block;\"></canvas>\n"
    html = html + "  <script>\n"
    html = html + "  (() => {\n"
    html = html + "    const c = document.getElementById('" + id + "');\n"
    html = html + "    if (!c) return;\n"
    html = html + "    const dpr = window.devicePixelRatio || 1;\n"
    html = html + "    c.width = " + w_str + " * dpr;\n"
    html = html + "    c.height = " + h_str + " * dpr;\n"
    html = html + "    const ctx = c.getContext('2d');\n"
    html = html + "    ctx.scale(dpr, dpr);\n"

    // Background
    html = html + "    ctx.fillStyle = '#0f172a';\n"
    html = html + "    ctx.fillRect(0, 0, " + w_str + ", " + h_str + ");\n"

    // Title
    html = html + "    ctx.fillStyle = '#f8fafc';\n"
    html = html + "    ctx.font = 'bold 16px sans-serif';\n"
    html = html + "    ctx.fillText('" + escaped_title_js + "', 65, 35);\n"

    // Data arrays
    n = len(values)
    html = html + "    const vals = ["
    i = 0
    while i < n
        html = html + str(get(values, i))
        if i + 1 < n html = html + ", " end
        i = i + 1
    end
    html = html + "];\n"

    html = html + "    const lbls = ["
    i = 0
    while i < len(labels)
        html = html + "'" + webx_chart_escape_js(get(labels, i)) + "'"
        if i + 1 < len(labels) html = html + ", " end
        i = i + 1
    end
    html = html + "];\n"

    // Colors and geometry setup
    custom_col = color
    if custom_col == "auto" custom_col = "" end

    html = html + "    const palette = ['#38bdf8', '#818cf8', '#34d399', '#fbbf24', '#f43f5e', '#a855f7', '#06b6d4', '#fb923c', '#e879f9', '#4ade80'];\n"
    html = html + "    const customCol = '" + custom_col + "';\n"
    html = html + "    const maxVal = Math.max(...vals, 1);\n"
    html = html + "    const minVal = Math.min(0, ...vals);\n"
    html = html + "    const range = maxVal - minVal || 1;\n"
    html = html + "    const padL = 65, padT = 55, padB = 60, padR = 30;\n"
    html = html + "    const pW = " + w_str + " - padL - padR, pH = " + h_str + " - padT - padB;\n"
    html = html + "    const zeroY = padT + (maxVal * pH) / range;\n"
    html = html + "    const slotW = pW / (vals.length || 1);\n"
    html = html + "    const barW = Math.max(4, Math.min(slotW * 0.65, slotW - 2));\n"
    html = html + "    const hasNeg = minVal < 0;\n"

    // Horizontal gridlines & Y-axis ticks in Canvas
    html = html + "    ctx.strokeStyle = '#334155';\n"
    html = html + "    ctx.lineWidth = 1;\n"
    html = html + "    ctx.setLineDash([3, 3]);\n"
    html = html + "    ctx.fillStyle = '#94a3b8';\n"
    html = html + "    ctx.font = '11px sans-serif';\n"
    html = html + "    ctx.textAlign = 'right';\n"
    html = html + "    for (let s = 0; s < 5; s++) {\n"
    html = html + "      const tVal = Math.round(minVal + (range * s) / 4);\n"
    html = html + "      const tY = padT + pH - (pH * s) / 4;\n"
    html = html + "      ctx.beginPath();\n"
    html = html + "      ctx.moveTo(padL, tY);\n"
    html = html + "      ctx.lineTo(padL + pW, tY);\n"
    html = html + "      ctx.stroke();\n"
    html = html + "      ctx.fillText(tVal, padL - 10, tY + 4);\n"
    html = html + "    }\n"
    html = html + "    ctx.setLineDash([]);\n"

    // Zero baseline
    html = html + "    ctx.strokeStyle = '#64748b';\n"
    html = html + "    ctx.lineWidth = 1.5;\n"
    html = html + "    ctx.beginPath();\n"
    html = html + "    ctx.moveTo(padL, zeroY);\n"
    html = html + "    ctx.lineTo(padL + pW, zeroY);\n"
    html = html + "    ctx.stroke();\n"

    // Bars rendering
    html = html + "    vals.forEach((v, idx) => {\n"
    html = html + "      const x = padL + idx * slotW + (slotW - barW) / 2;\n"
    html = html + "      const yVal = padT + ((maxVal - v) * pH) / range;\n"
    html = html + "      const barY = v >= 0 ? yVal : zeroY;\n"
    html = html + "      const barH = Math.max(1, Math.abs(zeroY - yVal));\n"
    html = html + "      ctx.fillStyle = customCol ? customCol : palette[idx % palette.length];\n"
    html = html + "      ctx.fillRect(x, barY, barW, barH);\n"
    html = html + "      ctx.fillStyle = '#94a3b8';\n"
    html = html + "      ctx.font = '12px sans-serif';\n"
    html = html + "      ctx.textAlign = 'center';\n"
    html = html + "      const catY = hasNeg ? padT + pH + 34 : padT + pH + 20;\n"
    html = html + "      if (lbls[idx]) ctx.fillText(lbls[idx], x + barW / 2, catY);\n"
    html = html + "      ctx.fillStyle = '#f1f5f9';\n"
    html = html + "      ctx.font = '600 11px sans-serif';\n"
    html = html + "      ctx.fillText(v, x + barW / 2, v >= 0 ? barY - 6 : barY + barH + 14);\n"
    html = html + "    });\n"
    html = html + "  })();\n"
    html = html + "  </script>\n"
    html = html + "</div>"
    return html

fn webx_chart_canvas_line id title labels values width height stroke_color fill_area
    // WHY: Emits standalone HTML5 Canvas line/area chart with 0% external JS.
    // Handles Retina DPR scaling, gridlines, axis ticks, gradient area fill, and point markers.
    escaped_title_js = webx_chart_escape_js(title)
    w_str = str(width)
    h_str = str(height)

    str_col = stroke_color
    if len(str_col) == 0 or str_col == "auto" str_col = "#38bdf8" end

    html = "<div class=\"webx-canvas-container\" style=\"display:inline-block; border-radius:8px; overflow:hidden;\">\n"
    html = html + "  <canvas id=\"" + id + "\" width=\"" + w_str + "\" height=\"" + h_str + "\" style=\"width:" + w_str + "px; height:" + h_str + "px; display:block;\"></canvas>\n"
    html = html + "  <script>\n"
    html = html + "  (() => {\n"
    html = html + "    const c = document.getElementById('" + id + "');\n"
    html = html + "    if (!c) return;\n"
    html = html + "    const dpr = window.devicePixelRatio || 1;\n"
    html = html + "    c.width = " + w_str + " * dpr;\n"
    html = html + "    c.height = " + h_str + " * dpr;\n"
    html = html + "    const ctx = c.getContext('2d');\n"
    html = html + "    ctx.scale(dpr, dpr);\n"

    // Background
    html = html + "    ctx.fillStyle = '#0f172a';\n"
    html = html + "    ctx.fillRect(0, 0, " + w_str + ", " + h_str + ");\n"

    // Title
    html = html + "    ctx.fillStyle = '#f8fafc';\n"
    html = html + "    ctx.font = 'bold 16px sans-serif';\n"
    html = html + "    ctx.fillText('" + escaped_title_js + "', 65, 35);\n"

    n = len(values)
    html = html + "    const vals = ["
    i = 0
    while i < n
        html = html + str(get(values, i))
        if i + 1 < n html = html + ", " end
        i = i + 1
    end
    html = html + "];\n"

    html = html + "    const lbls = ["
    i = 0
    while i < len(labels)
        html = html + "'" + webx_chart_escape_js(get(labels, i)) + "'"
        if i + 1 < len(labels) html = html + ", " end
        i = i + 1
    end
    html = html + "];\n"

    html = html + "    let maxVal = Math.max(...vals, 1);\n"
    html = html + "    let minVal = Math.min(...vals);\n"
    html = html + "    if (maxVal === minVal) { maxVal += 10; minVal -= 10; }\n"
    html = html + "    const range = maxVal - minVal || 1;\n"
    html = html + "    const padL = 65, padT = 55, padB = 60, padR = 30;\n"
    html = html + "    const pW = " + w_str + " - padL - padR, pH = " + h_str + " - padT - padB;\n"

    // Gridlines & Ticks in pure Canvas
    html = html + "    ctx.strokeStyle = '#334155';\n"
    html = html + "    ctx.lineWidth = 1;\n"
    html = html + "    ctx.setLineDash([3, 3]);\n"
    html = html + "    ctx.fillStyle = '#94a3b8';\n"
    html = html + "    ctx.font = '11px sans-serif';\n"
    html = html + "    ctx.textAlign = 'right';\n"
    html = html + "    for (let s = 0; s < 5; s++) {\n"
    html = html + "      const tVal = Math.round(minVal + (range * s) / 4);\n"
    html = html + "      const tY = padT + pH - (pH * s) / 4;\n"
    html = html + "      ctx.beginPath();\n"
    html = html + "      ctx.moveTo(padL, tY);\n"
    html = html + "      ctx.lineTo(padL + pW, tY);\n"
    html = html + "      ctx.stroke();\n"
    html = html + "      ctx.fillText(tVal, padL - 10, tY + 4);\n"
    html = html + "    }\n"
    html = html + "    ctx.setLineDash([]);\n"

    html = html + "    const pts = vals.map((v, i) => ({\n"
    html = html + "      x: padL + (vals.length > 1 ? (i * pW) / (vals.length - 1) : pW / 2),\n"
    html = html + "      y: padT + ((maxVal - v) * pH) / range\n"
    html = html + "    }));\n"

    // Area Fill
    if fill_area == 1
        html = html + "    if (pts.length > 1) {\n"
        html = html + "      const grad = ctx.createLinearGradient(0, padT, 0, padT + pH);\n"
        html = html + "      grad.addColorStop(0, '" + str_col + "66');\n"
        html = html + "      grad.addColorStop(1, '" + str_col + "05');\n"
        html = html + "      ctx.beginPath();\n"
        html = html + "      ctx.moveTo(pts[0].x, pts[0].y);\n"
        html = html + "      pts.forEach(p => ctx.lineTo(p.x, p.y));\n"
        html = html + "      ctx.lineTo(pts[pts.length - 1].x, padT + pH);\n"
        html = html + "      ctx.lineTo(pts[0].x, padT + pH);\n"
        html = html + "      ctx.closePath();\n"
        html = html + "      ctx.fillStyle = grad;\n"
        html = html + "      ctx.fill();\n"
        html = html + "    }\n"
    end

    // Line Path
    html = html + "    ctx.beginPath();\n"
    html = html + "    ctx.strokeStyle = '" + str_col + "';\n"
    html = html + "    ctx.lineWidth = 3;\n"
    html = html + "    ctx.lineJoin = 'round';\n"
    html = html + "    pts.forEach((p, i) => i === 0 ? ctx.moveTo(p.x, p.y) : ctx.lineTo(p.x, p.y));\n"
    html = html + "    ctx.stroke();\n"

    // Markers and Labels
    html = html + "    pts.forEach((p, idx) => {\n"
    html = html + "      ctx.beginPath();\n"
    html = html + "      ctx.arc(p.x, p.y, 4.5, 0, Math.PI * 2);\n"
    html = html + "      ctx.fillStyle = '#0f172a';\n"
    html = html + "      ctx.fill();\n"
    html = html + "      ctx.strokeStyle = '" + str_col + "';\n"
    html = html + "      ctx.lineWidth = 2.5;\n"
    html = html + "      ctx.stroke();\n"
    html = html + "      ctx.fillStyle = '#cbd5e1';\n"
    html = html + "      ctx.font = '600 11px sans-serif';\n"
    html = html + "      ctx.textAlign = 'center';\n"
    html = html + "      ctx.fillText(vals[idx], p.x, p.y - 12);\n"
    html = html + "      ctx.fillStyle = '#94a3b8';\n"
    html = html + "      ctx.font = '12px sans-serif';\n"
    html = html + "      if (lbls[idx]) ctx.fillText(lbls[idx], p.x, padT + pH + 20);\n"
    html = html + "    });\n"
    html = html + "  })();\n"
    html = html + "  </script>\n"
    html = html + "</div>"
    return html

fn webx_chart_canvas_pie id title labels values width height is_donut
    // WHY: Emits standalone HTML5 Canvas pie/donut chart with 0% external JS.
    // Renders high-contrast slices, responsive side legend, and donut center statistic.
    escaped_title_js = webx_chart_escape_js(title)
    w_str = str(width)
    h_str = str(height)

    html = "<div class=\"webx-canvas-container\" style=\"display:inline-block; border-radius:8px; overflow:hidden;\">\n"
    html = html + "  <canvas id=\"" + id + "\" width=\"" + w_str + "\" height=\"" + h_str + "\" style=\"width:" + w_str + "px; height:" + h_str + "px; display:block;\"></canvas>\n"
    html = html + "  <script>\n"
    html = html + "  (() => {\n"
    html = html + "    const c = document.getElementById('" + id + "');\n"
    html = html + "    if (!c) return;\n"
    html = html + "    const dpr = window.devicePixelRatio || 1;\n"
    html = html + "    c.width = " + w_str + " * dpr;\n"
    html = html + "    c.height = " + h_str + " * dpr;\n"
    html = html + "    const ctx = c.getContext('2d');\n"
    html = html + "    ctx.scale(dpr, dpr);\n"

    // Background
    html = html + "    ctx.fillStyle = '#0f172a';\n"
    html = html + "    ctx.fillRect(0, 0, " + w_str + ", " + h_str + ");\n"

    // Title
    html = html + "    ctx.fillStyle = '#f8fafc';\n"
    html = html + "    ctx.font = 'bold 16px sans-serif';\n"
    html = html + "    ctx.fillText('" + escaped_title_js + "', 30, 35);\n"

    n = len(values)
    html = html + "    const vals = ["
    i = 0
    while i < n
        html = html + str(get(values, i))
        if i + 1 < n html = html + ", " end
        i = i + 1
    end
    html = html + "];\n"

    html = html + "    const lbls = ["
    i = 0
    while i < len(labels)
        html = html + "'" + webx_chart_escape_js(get(labels, i)) + "'"
        if i + 1 < len(labels) html = html + ", " end
        i = i + 1
    end
    html = html + "];\n"

    html = html + "    const total = vals.reduce((a, b) => a + (b > 0 ? b : 0), 0) || 1;\n"
    html = html + "    const cx = " + w_str + " * 0.35, cy = " + h_str + " / 2 + 10;\n"
    html = html + "    const r = Math.min(cx - 30, " + h_str + " / 2 - 40);\n"
    html = html + "    const colors = ['#38bdf8', '#818cf8', '#34d399', '#fbbf24', '#f43f5e', '#a855f7', '#06b6d4', '#fb923c', '#e879f9', '#4ade80'];\n"
    html = html + "    let startAngle = -Math.PI / 2;\n"

    // Slices rendering
    html = html + "    vals.forEach((v, i) => {\n"
    html = html + "      if (v <= 0) return;\n"
    html = html + "      const slice = (v / total) * Math.PI * 2;\n"
    html = html + "      ctx.beginPath();\n"
    html = html + "      ctx.moveTo(cx, cy);\n"
    html = html + "      ctx.arc(cx, cy, r, startAngle, startAngle + slice);\n"
    html = html + "      ctx.closePath();\n"
    html = html + "      ctx.fillStyle = colors[i % colors.length];\n"
    html = html + "      ctx.fill();\n"
    html = html + "      startAngle += slice;\n"
    html = html + "    });\n"

    // Donut hole
    if is_donut == 1
        html = html + "    ctx.beginPath();\n"
        html = html + "    ctx.arc(cx, cy, r * 0.58, 0, Math.PI * 2);\n"
        html = html + "    ctx.fillStyle = '#0f172a';\n"
        html = html + "    ctx.fill();\n"
        html = html + "    ctx.fillStyle = '#f8fafc';\n"
        html = html + "    ctx.font = 'bold 18px sans-serif';\n"
        html = html + "    ctx.textAlign = 'center';\n"
        html = html + "    ctx.textBaseline = 'middle';\n"
        html = html + "    ctx.fillText(total, cx, cy - 4);\n"
        html = html + "    ctx.font = '11px sans-serif';\n"
        html = html + "    ctx.fillStyle = '#94a3b8';\n"
        html = html + "    ctx.fillText('Total', cx, cy + 14);\n"
    end

    // Side Legend on the right in Canvas
    html = html + "    const legX = " + w_str + " * 0.63;\n"
    html = html + "    const legStartY = Math.max(50, cy - (vals.length * 24) / 2);\n"
    html = html + "    ctx.textBaseline = 'middle';\n"
    html = html + "    vals.forEach((v, i) => {\n"
    html = html + "      const itemY = legStartY + i * 26;\n"
    html = html + "      ctx.fillStyle = colors[i % colors.length];\n"
    html = html + "      ctx.fillRect(legX, itemY - 6, 12, 12);\n"
    html = html + "      ctx.fillStyle = '#e2e8f0';\n"
    html = html + "      ctx.font = '500 12px sans-serif';\n"
    html = html + "      ctx.textAlign = 'left';\n"
    html = html + "      const pct = Math.round((v * 100) / total);\n"
    html = html + "      const labelTxt = (lbls[i] || 'Item ' + (i + 1)) + ': ' + v + ' (' + pct + '%)';\n"
    html = html + "      ctx.fillText(labelTxt, legX + 20, itemY);\n"
    html = html + "    });\n"

    html = html + "  })();\n"
    html = html + "  </script>\n"
    html = html + "</div>"
    return html

// ==============================================================================
// ── 7. WCAG 2.2 Accessible Shadow ARIA Data Table Generator ───────────────────
// ==============================================================================

fn webx_chart_canvas_script id chart_type labels_list values_list
    // WHY: Returns raw executable Canvas 2D JavaScript routine for dynamic browser mounting
    if chart_type == "bar"
        return webx_chart_canvas_bar(id, "Bar Chart", labels_list, values_list, 500, 300, "#38bdf8")
    elif chart_type == "line"
        return webx_chart_canvas_line(id, "Line Chart", labels_list, values_list, 500, 250, "#818cf8", 1)
    elif chart_type == "pie"
        return webx_chart_canvas_pie(id, "Pie Chart", labels_list, values_list, 400, 260, 0)
    elif chart_type == "donut"
        return webx_chart_canvas_pie(id, "Donut Chart", labels_list, values_list, 400, 260, 1)
    end
    return ""

fn webx_chart_aria_table title labels values
    // WHY: Emits semantic HTML5 <table> accompanying charts for 100% WCAG 2.2 accessibility
    escaped_title = webx_chart_escape_xml(title)
    tbl = "<table class=\"sr-only\" aria-label=\"" + escaped_title + "\">\n"
    tbl = tbl + "  <caption>" + escaped_title + "</caption>\n"
    tbl = tbl + "  <thead>\n    <tr><th scope=\"col\">Category</th><th scope=\"col\">Value</th></tr>\n  </thead>\n"
    tbl = tbl + "  <tbody>\n"

    n = len(values)
    i = 0
    while i < n
        v = get(values, i)
        lbl = ""
        if i < len(labels)
            lbl = get(labels, i)
        end
        tbl = tbl + "    <tr><td>" + webx_chart_escape_xml(lbl) + "</td><td>" + str(v) + "</td></tr>\n"
        i = i + 1
    end

    tbl = tbl + "  </tbody>\n</table>\n"
    return tbl

// ==============================================================================
// ── 8. WebX Virtual Node Wrappers for UIX Layout Composition ──────────────────
// ==============================================================================

fn webx_chart_bar_node id title labels values width height color
    // WHY: Wraps SVG bar chart markup into a WebX virtual DOM node (UIX node tree)
    return webx_raw(id, webx_chart_bar(id, title, labels, values, width, height, color))

fn webx_chart_line_node id title labels values width height stroke_color fill_area
    // WHY: Wraps SVG line chart markup into a WebX virtual DOM node (UIX node tree)
    return webx_raw(id, webx_chart_line(id, title, labels, values, width, height, stroke_color, fill_area))

fn webx_chart_pie_node id title labels values width height is_donut
    // WHY: Wraps SVG pie/donut chart markup into a WebX virtual DOM node (UIX node tree)
    return webx_raw(id, webx_chart_pie(id, title, labels, values, width, height, is_donut))

fn webx_chart_line_sparkline_node id values width height stroke_color fill_area
    // WHY: Wraps SVG sparkline markup into a WebX virtual DOM node (UIX node tree)
    return webx_raw(id, webx_chart_line_sparkline(id, values, width, height, stroke_color, fill_area))
