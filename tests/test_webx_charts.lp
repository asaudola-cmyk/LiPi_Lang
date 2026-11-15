// ==============================================================================
// 🧪 LIPI WEBX SOVEREIGN CHARTS TEST SUITE (tests/test_webx_charts.lp)
// ⚡ 100% Pure LiPi Implementation — Zero External / NPM / JS / Libc Dependencies
// ==============================================================================

include "aati/lipi_web/webx_charts.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    end
    say "  ✔ PASS: " + test_name
    return 1

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    end
    say "  ✔ PASS: " + test_name
    return 1

say "╔══════════════════════════════════════════════════════════════════════╗"
say "║  👑 LIPI WEBX SOVEREIGN PURE SVG & CANVAS CHART ENGINE SUITE         ║"
say "║  ⚡ 100% Pure LiPi | 0% Chart.js | 0% D3.js | 0% Libc | Sovereign    ║"
say "╚══════════════════════════════════════════════════════════════════════╝"

// ── 1. Mathematical & Trigonometric Scaler Tests ──────────────────────────────
say "\n── [Pillar 1]: Testing Fixed-Point Decidegree Trigonometry & Scalers ──"

assert_eq(webx_chart_sin_decideg(0, 1000), 0, "sin(0°) == 0")
assert_eq(webx_chart_sin_decideg(900, 1000), 1000, "sin(90°) == 1000")
assert_eq(webx_chart_sin_decideg(1800, 1000), 0, "sin(180°) == 0")
assert_eq(webx_chart_sin_decideg(2700, 1000), -1000, "sin(270°) == -1000")
assert_eq(webx_chart_sin_decideg(3600, 1000), 0, "sin(360°) == 0")

assert_eq(webx_chart_cos_decideg(0, 1000), 1000, "cos(0°) == 1000")
assert_eq(webx_chart_cos_decideg(900, 1000), 0, "cos(90°) == 0")
assert_eq(webx_chart_cos_decideg(1800, 1000), -1000, "cos(180°) == -1000")
assert_eq(webx_chart_cos_decideg(2700, 1000), 0, "cos(270°) == 0")
assert_eq(webx_chart_cos_decideg(3600, 1000), 1000, "cos(360°) == 1000")

// Negative decidegrees
assert_eq(webx_chart_sin_decideg(-900, 1000), -1000, "sin(-90°) == -1000")
assert_eq(webx_chart_cos_decideg(-900, 1000), 0, "cos(-90°) == 0")

t_vals = list()
push(t_vals, 45)
push(t_vals, -20)
push(t_vals, 180)
push(t_vals, 95)
assert_eq(webx_chart_min(t_vals), -20, "webx_chart_min handles negative values")
assert_eq(webx_chart_max(t_vals), 180, "webx_chart_max finds global maximum")
assert_eq(webx_chart_sum(t_vals), 300, "webx_chart_sum calculates correct sum")
assert_eq(webx_chart_positive_sum(t_vals), 320, "webx_chart_positive_sum filters out negative values")

// ── 2. String Escaping Tests ──────────────────────────────────────────────────
say "\n── [Pillar 2]: Testing XML and JS String Escaping Sanitizers ──"

xml_test = webx_chart_escape_xml("A & B <C> \"Quote\" 'Apos'")
assert_true(contains(xml_test, "&amp;"), "XML escape handles &")
assert_true(contains(xml_test, "&lt;C&gt;"), "XML escape handles < and >")
assert_true(contains(xml_test, "&quot;"), "XML escape handles \"")
assert_true(contains(xml_test, "&#39;"), "XML escape handles single quote '")

js_test = webx_chart_escape_js("User's \"Query\" \\ <script></script>")
assert_true(contains(js_test, "User\\'s"), "JS escape handles single quote")
assert_true(contains(js_test, "\\\"Query\\\""), "JS escape handles double quote")
assert_true(contains(js_test, "\\\\"), "JS escape handles backslash")
assert_true(contains(js_test, "<\\/script>"), "JS escape prevents premature script termination")

// ── 3. Pure SVG Bar Chart Tests ───────────────────────────────────────────────
say "\n── [Pillar 3]: Testing Pure SVG Bar Chart Engine (webx_chart_bar) ──"

bar_labels = list()
push(bar_labels, "Jan")
push(bar_labels, "Feb")
push(bar_labels, "Mar")
push(bar_labels, "Apr")
push(bar_labels, "May")

bar_values = list()
push(bar_values, 120)
push(bar_values, 340)
push(bar_values, 210)
push(bar_values, 480)
push(bar_values, 390)

svg_bar = webx_chart_bar("bar_sales", "Monthly Revenue & Sales", bar_labels, bar_values, 600, 400, "#38bdf8")

assert_true(contains(svg_bar, "<svg id=\"bar_sales\""), "Bar chart contains SVG root with id")
assert_true(contains(svg_bar, "viewBox=\"0 0 600 400\""), "Bar chart has responsive viewBox")
assert_true(contains(svg_bar, "Monthly Revenue &amp; Sales"), "Bar chart escapes XML in title")
assert_true(contains(svg_bar, "class=\"webx-bar\""), "Bar chart renders webx-bar rect elements")
assert_true(contains(svg_bar, "data-value=\"480\""), "Bar chart includes data-value attribute")
assert_true(contains(svg_bar, "Jan"), "Bar chart includes X-axis category labels")
assert_true(contains(svg_bar, "<line x1="), "Bar chart renders gridlines & baseline")

// Bar chart with negative / mixed values
mixed_labels = list()
push(mixed_labels, "Q1")
push(mixed_labels, "Q2")
push(mixed_labels, "Q3")
push(mixed_labels, "Q4")

mixed_values = list()
push(mixed_values, 150)
push(mixed_values, -80)
push(mixed_values, 220)
push(mixed_values, -40)

svg_mixed = webx_chart_bar("bar_mixed", "Quarterly Net Flow", mixed_labels, mixed_values, 500, 350, "")
assert_true(contains(svg_mixed, "data-value=\"-80\""), "Bar chart handles negative value rendering")
assert_true(contains(svg_mixed, "<rect class=\"webx-bar\""), "Bar chart renders rects for negative series")
// Negative value bar spacing check: category label placed lower to avoid collision
assert_true(contains(svg_mixed, "y=\"324\""), "Bar chart repositions category labels lower (y=324) when negative values exist")

// ── 4. Pure SVG Line Chart Tests ──────────────────────────────────────────────
say "\n── [Pillar 4]: Testing Pure SVG Line Chart Engine (webx_chart_line) ──"

line_labels = list()
push(line_labels, "10:00")
push(line_labels, "11:00")
push(line_labels, "12:00")
push(line_labels, "13:00")
push(line_labels, "14:00")
push(line_labels, "15:00")

line_values = list()
push(line_values, 42)
push(line_values, 58)
push(line_values, 55)
push(line_values, 79)
push(line_values, 91)
push(line_values, 84)

svg_line = webx_chart_line("line_tps", "Throughput (TPS)", line_labels, line_values, 700, 400, "#818cf8", 1)

assert_true(contains(svg_line, "<svg id=\"line_tps\""), "Line chart contains SVG root with id")
assert_true(contains(svg_line, "<path d=\"M "), "Line chart generates smooth polyline path")
assert_true(contains(svg_line, "linearGradient id=\"line_tps_area_grad\""), "Line chart includes gradient area fill definition")
assert_true(contains(svg_line, "fill=\"url(#line_tps_area_grad)\""), "Line chart applies gradient to area path")
assert_true(contains(svg_line, "<circle class=\"webx-point\""), "Line chart renders circular data point markers")
assert_true(contains(svg_line, "data-value=\"79\""), "Line chart includes point data-value attributes")

// Single data point line chart robustness
single_line_lbl = list()
push(single_line_lbl, "Point 1")
single_line_val = list()
push(single_line_val, 100)
svg_single_line = webx_chart_line("line_single", "Single Data Point", single_line_lbl, single_line_val, 500, 300, "#38bdf8", 0)
assert_true(contains(svg_single_line, "M 267 147 L 267 147"), "Single-point line chart emits valid M x y L x y path for crisp round cap point")

// ── 5. Pure SVG Pie & Donut Chart Tests ────────────────────────────────────────
say "\n── [Pillar 5]: Testing Pure SVG Pie & Donut Chart Engine (webx_chart_pie) ──"

pie_labels = list()
push(pie_labels, "Frontend")
push(pie_labels, "Backend")
push(pie_labels, "Database")
push(pie_labels, "DevOps")

pie_values = list()
push(pie_values, 40)
push(pie_values, 30)
push(pie_values, 20)
push(pie_values, 10)

// Test Solid Pie Chart
svg_pie = webx_chart_pie("pie_stack", "Tech Stack Distribution", pie_labels, pie_values, 600, 400, 0)

assert_true(contains(svg_pie, "<svg id=\"pie_stack\""), "Pie chart contains SVG root with id")
assert_true(contains(svg_pie, "class=\"webx-slice\""), "Pie chart renders webx-slice arc paths")
assert_true(contains(svg_pie, "data-percentage=\"40%\""), "Pie chart calculates correct slice percentage (40%)")
assert_true(contains(svg_pie, "Frontend:"), "Pie chart renders side legend with category labels")
assert_true(contains(svg_pie, "A "), "Pie chart SVG path contains SVG arc (A) command")

// Test Donut Chart
svg_donut = webx_chart_pie("donut_budget", "Resource Allocation", pie_labels, pie_values, 600, 400, 1)

assert_true(contains(svg_donut, "<svg id=\"donut_budget\""), "Donut chart contains SVG root")
assert_true(contains(svg_donut, "100"), "Donut chart displays center total statistic text (100)")
assert_true(contains(svg_donut, "Total"), "Donut chart displays 'Total' sub-label")
assert_true(contains(svg_donut, "class=\"webx-slice\""), "Donut chart renders dual-arc sector paths")

// Test Trailing Zero Slice: Zero slice must NOT absorb remainder angle!
zero_pie_lbls = list()
push(zero_pie_lbls, "Core")
push(zero_pie_lbls, "Ext")
push(zero_pie_lbls, "Unused")
zero_pie_vals = list()
push(zero_pie_vals, 10)
push(zero_pie_vals, 11)
push(zero_pie_vals, 0)
svg_zero_pie = webx_chart_pie("zero_pie", "Trailing Zero Test", zero_pie_lbls, zero_pie_vals, 400, 300, 0)
assert_true(contains(svg_zero_pie, "Unused: <tspan fill=\"#94a3b8\">0 (0%)</tspan>"), "Pie legend displays 0 (0%) for zero slice")
assert_true(!contains(svg_zero_pie, "id=\"zero_pie_slice_2\""), "Zero value slice is NOT rendered as a visible arc path")

// Test 99.8% Slice: Must render as an arc, not a full circle
near_full_lbls = list()
push(near_full_lbls, "Dominant")
push(near_full_lbls, "Minor")
near_full_vals = list()
push(near_full_vals, 998)
push(near_full_vals, 2)
svg_near_full = webx_chart_pie("near_full", "Near Full Test", near_full_lbls, near_full_vals, 500, 350, 0)
assert_true(contains(svg_near_full, "id=\"near_full_slice_0\""), "Dominant slice 0 exists")
assert_true(contains(svg_near_full, "id=\"near_full_slice_1\""), "Minor slice 1 exists and is not wiped out by slice 0")

// ── 6. Robustness & Boundary Value Tests ───────────────────────────────────────
say "\n── [Pillar 6]: Testing Robustness & Boundary Edge Cases ──"

// Edge Case 1: Empty dataset
empty_lbls = list()
empty_vals = list()
svg_empty_bar = webx_chart_bar("empty_bar", "Empty Bar", empty_lbls, empty_vals, 400, 300, "#38bdf8")
assert_true(contains(svg_empty_bar, "No Data Available"), "Empty bar chart displays graceful 'No Data Available' state")

svg_empty_line = webx_chart_line("empty_line", "Empty Line", empty_lbls, empty_vals, 400, 300, "#38bdf8", 0)
assert_true(contains(svg_empty_line, "No Data Available"), "Empty line chart displays graceful 'No Data Available' state")

svg_empty_pie = webx_chart_pie("empty_pie", "Empty Pie", empty_lbls, empty_vals, 400, 300, 0)
assert_true(contains(svg_empty_pie, "No Data Available"), "Empty pie chart displays graceful 'No Data Available' state")

// Edge Case 2: Single 100% slice
single_lbl = list()
push(single_lbl, "Sole Category")
single_val = list()
push(single_val, 500)
svg_single_pie = webx_chart_pie("single_pie", "Single Category", single_lbl, single_val, 400, 300, 0)
assert_true(contains(svg_single_pie, "<circle class=\"webx-slice\""), "Single 100% pie slice renders full circle cleanly")

svg_single_donut = webx_chart_pie("single_donut", "Single Donut", single_lbl, single_val, 400, 300, 1)
assert_true(contains(svg_single_donut, "<circle class=\"webx-slice\""), "Single 100% donut slice renders stroked ring cleanly")

// Edge Case 3: XML & Single Quote Escaping
xss_lbl = list()
push(xss_lbl, "<script>alert('xss')</script>")
push(xss_lbl, "Engineer's \"Metrics\" & Values")
xss_val = list()
push(xss_val, 50)
push(xss_val, 50)
svg_xss = webx_chart_bar("xss_bar", "Security <Test> & \"Verify\" 'Apos'", xss_lbl, xss_val, 500, 350, "")
assert_true(contains(svg_xss, "&lt;script&gt;"), "Script tags in labels properly escaped to &lt;script&gt;")
assert_true(contains(svg_xss, "&amp;"), "Ampersands properly escaped to &amp;")
assert_true(contains(svg_xss, "&quot;"), "Quotes properly escaped to &quot;")
assert_true(contains(svg_xss, "&#39;"), "Single quotes properly escaped to &#39;")

// ── 7. Sovereign Pure Canvas 2D Engine Tests ──────────────────────────────────
say "\n── [Pillar 7]: Testing Sovereign Pure Canvas 2D Engine (0% External JS) ──"

c_bar = webx_chart_canvas_bar("canvas_bar", "Developer's Dashboard", bar_labels, bar_values, 600, 400, "auto")
assert_true(contains(c_bar, "<canvas id=\"canvas_bar\""), "Canvas bar emits <canvas> element")
assert_true(contains(c_bar, "getContext('2d')"), "Canvas bar initializes 2D rendering context")
assert_true(contains(c_bar, "devicePixelRatio"), "Canvas bar implements Retina DPR scaling")
assert_true(contains(c_bar, "ctx.fillRect"), "Canvas bar uses native ctx.fillRect")
assert_true(contains(c_bar, "setLineDash([3, 3])"), "Canvas bar renders dashed gridlines")
assert_true(contains(c_bar, "Developer\\'s Dashboard"), "Canvas bar safely escapes single quotes in JS")

c_line = webx_chart_canvas_line("canvas_line", "Network's Bandwidth", line_labels, line_values, 600, 400, "#818cf8", 1)
assert_true(contains(c_line, "<canvas id=\"canvas_line\""), "Canvas line emits <canvas> element")
assert_true(contains(c_line, "createLinearGradient"), "Canvas line generates linear gradient for area fill")
assert_true(contains(c_line, "ctx.stroke()"), "Canvas line strokes polyline path")
assert_true(contains(c_line, "Network\\'s Bandwidth"), "Canvas line safely escapes title string")
assert_true(contains(c_line, "lbls[idx]"), "Canvas line uses and renders X-axis category labels")

c_pie = webx_chart_canvas_pie("canvas_pie", "Company's Revenue", pie_labels, pie_values, 600, 400, 1)
assert_true(contains(c_pie, "<canvas id=\"canvas_pie\""), "Canvas pie emits <canvas> element")
assert_true(contains(c_pie, "ctx.arc("), "Canvas pie draws native arc sectors")
assert_true(contains(c_pie, "Company\\'s Revenue"), "Canvas pie safely escapes title string")
assert_true(contains(c_pie, "legX"), "Canvas pie renders responsive right-hand legend")

// ── 8. WCAG 2.2 Accessible Data Table Tests ───────────────────────────────────
say "\n── [Pillar 8]: Testing WCAG 2.2 Accessible Data Table Generation ──"

aria_table = webx_chart_aria_table("Quarterly Performance", bar_labels, bar_values)
assert_true(contains(aria_table, "<table class=\"sr-only\""), "ARIA table includes sr-only semantic table")
assert_true(contains(aria_table, "<caption>Quarterly Performance</caption>"), "ARIA table includes table caption")
assert_true(contains(aria_table, "<th scope=\"col\">Category</th>"), "ARIA table includes column headers")
assert_true(contains(aria_table, "<td>Jan</td><td>120</td>"), "ARIA table includes row entries")

// ── 9. WebX Virtual Node Wrappers Tests ───────────────────────────────────────
say "\n── [Pillar 9]: Testing WebX Virtual Node Wrappers (UIX Node Tree) ──"

bar_node = webx_chart_bar_node("ui_bar", "V-Node Bar", bar_labels, bar_values, 500, 300, "#38bdf8")
assert_eq(bar_node.node_type, WEBX_NODE_RAW, "webx_chart_bar_node returns WEBX_NODE_RAW virtual node")
assert_eq(bar_node.node_id, "ui_bar", "webx_chart_bar_node assigns correct DOM ID")

line_node = webx_chart_line_node("ui_line", "V-Node Line", line_labels, line_values, 500, 250, "#818cf8", 1)
assert_eq(line_node.node_type, WEBX_NODE_RAW, "webx_chart_line_node returns WEBX_NODE_RAW virtual node")

pie_node = webx_chart_pie_node("ui_pie", "V-Node Pie", pie_labels, pie_values, 400, 260, 1)
assert_eq(pie_node.node_type, WEBX_NODE_RAW, "webx_chart_pie_node returns WEBX_NODE_RAW virtual node")

rendered_node_svg = webx_render_node(bar_node)
assert_true(contains(rendered_node_svg, "<svg id=\"ui_bar\""), "Rendered WebXNode produces valid SVG markup")

say "\n======================================================================"
say "🎉 ALL 9 PILLARS OF SOVEREIGN CHART ENGINE VERIFIED SUCCESSFULLY!"
say "======================================================================"
