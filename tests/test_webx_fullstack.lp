// ==============================================================================
// 🧪 LIPI WEBX SOVEREIGN FULL-STACK TEST SUITE (tests/test_webx_fullstack.lp)
// ⚡ 100% Pure LiPi Implementation — Zero External / Node.js / C / Shell Dependencies
// ==============================================================================
// Validates all core pillars of the LiPi WebX architecture:
// 1. Declarative Component & UIX syntax (bilingual: component / উপাদান)
// 2. O(1) 64-bit hardware bitmask dirty tracking
// 3. Direct WASM DOM mutation batch serialization
// 4. Headless accessible UI primitives & semantic HTML5 generation
// 5. Declarative 1-line form validation (email, phone, numeric, required, URL)
// 6. 4th-order Runge-Kutta (RK4) spring physics animation engine
// 7. Zero-CSS atomic class stylesheet compiler
// 8. Resumable binary state snapshot serialization & restoration
// 9. Parameterized App Router segment matching & parameter extraction
// 10. Universal ESM Assimilator import map & JS bridge generation
// ==============================================================================

include "aati/lipi_web/webx_primitives.lp"
include "aati/lipi_web/webx_resumable.lp"
include "aati/lipi_web/esm_assimilator.lp"
include "aati/lipi_web/webx_widgets.lp"
include "aati/lipi_web/webx_islands.lp"
include "src/compiler/backend/targets/wasm/codegen_core.lp"

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
say "║  👑 LIPI WEBX FULL-STACK SOVEREIGN SUITE (0% NODE / 0% REACT / 0% C) ║"
say "╚══════════════════════════════════════════════════════════════════════╝"

// ── [Pillar 1]: Declarative Component & Bilingual Syntax ───────────────────────
say "\n── [Pillar 1]: Testing Declarative Component Execution (Bilingual) ──"

component CounterComponent initial_val
    return initial_val + 10
end

উপাদান BengaliCard greeting
    return "স্বাগতম: " + greeting
end

c_res = CounterComponent(15)
assert_eq(c_res, 25, "English 'component CounterComponent' executed with return 25")

b_res = BengaliCard("লিপি ৩.০")
assert_eq(b_res, "স্বাগতম: লিপি ৩.০", "Bengali 'উপাদান BengaliCard' executed with correct string")

// ── [Pillar 2]: O(1) 64-Bit Bitmask Dirty Tracking & WASM DOM Batch ───────────
say "\n── [Pillar 2]: Testing O(1) Bitmask Dirty Tracking & DOM Mutation Batch ──"

mask = 0
assert_eq(webx_bitmask_is_dirty(mask, 0), 0, "Initial mask has slot 0 clean")
assert_eq(webx_bitmask_is_dirty(mask, 7), 0, "Initial mask has slot 7 clean")

// Mark slot 0 and slot 7 dirty in O(1)
mask = webx_bitmask_set(mask, 0)
mask = webx_bitmask_set(mask, 7)

assert_eq(webx_bitmask_is_dirty(mask, 0), 1, "Slot 0 marked dirty")
assert_eq(webx_bitmask_is_dirty(mask, 1), 0, "Slot 1 remains clean")
assert_eq(webx_bitmask_is_dirty(mask, 7), 1, "Slot 7 marked dirty")

// Clear slot 0
mask = webx_bitmask_clear(mask, 0)
assert_eq(webx_bitmask_is_dirty(mask, 0), 0, "Slot 0 cleared to clean")
assert_eq(webx_bitmask_is_dirty(mask, 7), 1, "Slot 7 remains dirty")

// Create and serialize DOM mutation batch
dom_cmds = list()
push(dom_cmds, webx_dom_cmd_new(WASM_DOM_OP_CREATE_ELEMENT, 1, 0, "div", "class", 0, 0))
push(dom_cmds, webx_dom_cmd_new(WASM_DOM_OP_SET_ATTR, 1, 0, "container", "id", 0, 0))
push(dom_cmds, webx_dom_cmd_new(WASM_DOM_OP_CREATE_TEXT, 2, 1, "Hello Sovereign WebX", "", 0, 0))
push(dom_cmds, webx_dom_cmd_new(WASM_DOM_OP_APPEND_CHILD, 2, 1, "", "", 0, 0))

serialized_dom = webx_dom_serialize_batch(dom_cmds)
if serialized_dom.len() > 30
    say "  ✔ PASS: Serialized 4 DOM mutation commands into binary buffer (" + str(serialized_dom.len()) + " bytes)"
else
    say "  ❌ FAILED: DOM mutation buffer too small"
    exit(1)
end

// ── [Pillar 3]: Headless UI Primitives & Semantic HTML5 ────────────────────────
say "\n── [Pillar 3]: Testing Headless Accessible UI Primitives ──"

btn = webx_button("btn_submit", "Save Record", 101, "bg-blue-600 text-white rounded-lg")
inp = webx_input("inp_name", "Enter your name", "Shafiullah", 102, "p-2 border")
f_kids = list()
push(f_kids, inp)
push(f_kids, btn)
form = webx_form("main_form", 201, f_kids, "flex flex-col gap-4")

card = webx_card("profile_card", "User Profile", "Administrator", form, "shadow-md p-4")
html_card = webx_render_node(card)

if str_contains(html_card, "User Profile") == 1
    say "  ✔ PASS: Card rendered title text"
else
    say "  ❌ FAILED: Card missing title"
    exit(1)
end

if str_contains(html_card, "data-action=\"101\"") == 1
    say "  ✔ PASS: Button rendered action dispatch attribute"
else
    say "  ❌ FAILED: Button missing data-action"
    exit(1)
end

// ── [Pillar 4]: 1-Line Declarative Form Validation ─────────────────────────────
say "\n── [Pillar 4]: Testing 1-Line Declarative Form Validation ──"

// 1. Required check
v_empty = webx_validate("", WEBX_VAL_REQUIRED, 0, 0)
assert_eq(v_empty.vr_is_valid, 0, "Empty string fails WEBX_VAL_REQUIRED")

// 2. Email format checks
v_bad_email = webx_validate("invalid-email-address", WEBX_VAL_EMAIL, 0, 0)
assert_eq(v_bad_email.vr_is_valid, 0, "Invalid email fails WEBX_VAL_EMAIL")

v_good_email = webx_validate("architect@lipi.dev", WEBX_VAL_EMAIL, 0, 0)
assert_eq(v_good_email.vr_is_valid, 1, "Valid email passes WEBX_VAL_EMAIL")

// 3. Bangladesh Phone checks
v_bd_phone1 = webx_validate("01711223344", WEBX_VAL_PHONE_BD, 0, 0)
assert_eq(v_bd_phone1.vr_is_valid, 1, "11-digit 017... BD phone passes")

v_bd_phone2 = webx_validate("+8801811223344", WEBX_VAL_PHONE_BD, 0, 0)
assert_eq(v_bd_phone2.vr_is_valid, 1, "14-digit +8801... BD phone passes")

v_bad_phone = webx_validate("02999999", WEBX_VAL_PHONE_BD, 0, 0)
assert_eq(v_bad_phone.vr_is_valid, 0, "Landline phone fails mobile check")

// 4. URL format check
v_url = webx_validate("https://lipi.org", WEBX_VAL_URL, 0, 0)
assert_eq(v_url.vr_is_valid, 1, "https:// URL passes WEBX_VAL_URL")

// ── [Pillar 5]: Deterministic Fixed-Point Spring Physics Animation ─────────────
say "\n── [Pillar 5]: Testing Deterministic Spring Physics Animation ──"

// Spring parameters: initial = 0, target = 100, stiffness = 180, damping = 12, mass = 1
spring = webx_spring_new(0, 100, 180, 12, 1)
assert_eq(spring.sp_settled, 0, "Spring starts in active animating state")

// Step simulation over 60 timesteps (dt = 16 ms = 60 FPS)
step_i = 0
while step_i < 60
    webx_spring_step(spring, 16)
    step_i = step_i + 1
end

// Position should have advanced significantly towards 100
curr_pos = spring.sp_current
if curr_pos > 50
    say "  ✔ PASS: Spring simulation progressed to target (pos = " + str(curr_pos) + ")"
else
    say "  ❌ FAILED: Spring simulation did not advance sufficiently (pos = " + str(curr_pos) + ")"
    exit(1)
end

// Run additional steps until settling occurs
while step_i < 200 and spring.sp_settled == 0
    webx_spring_step(spring, 16)
    step_i = step_i + 1
end

assert_eq(spring.sp_settled, 1, "Spring reached settled equilibrium at target")
assert_eq(spring.sp_current, 100, "Final settled position equals target (100)")

// ── [Pillar 6]: Zero-CSS Atomic Class Compiler ─────────────────────────────────
say "\n── [Pillar 6]: Testing Zero-CSS Atomic Utility Class Compiler ──"

classes_test = "p-4 flex items-center bg-blue-600 text-white rounded-lg shadow-md p-4"
compiled_css = webx_compile_classes(classes_test)

if str_contains(compiled_css, ".p-4 { padding: 1rem; }") == 1
    say "  ✔ PASS: Compiled .p-4 atomic rule"
else
    say "  ❌ FAILED: Missing .p-4 rule"
    exit(1)
end

if str_contains(compiled_css, ".bg-blue-600 { background-color: #2563eb; }") == 1
    say "  ✔ PASS: Compiled .bg-blue-600 atomic rule"
else
    say "  ❌ FAILED: Missing .bg-blue-600 rule"
    exit(1)
end

// ── [Pillar 7]: Resumable Binary State Serialization & Restoration ─────────────
say "\n── [Pillar 7]: Testing Resumable State Snapshot Engine ──"

signals = list()
push(signals, webx_signal_new(1, "counter", 42, ""))
push(signals, webx_signal_new(2, "user_name", 0, "Shafiullah"))
push(signals, webx_signal_new(3, "theme_mode", 1, "dark"))

serialized_state = webx_resumable_serialize(signals)
say "  • Serialized State Snapshot: " + serialized_state

restored_signals = webx_resumable_deserialize(serialized_state)
assert_eq(len(restored_signals), 3, "Restored exact count of 3 signals")

s1 = get(restored_signals, 0)
assert_eq(s1.sig_id, 1, "Signal 1 ID matches (1)")
assert_eq(s1.sig_name, "counter", "Signal 1 name matches ('counter')")
assert_eq(s1.sig_int_val, 42, "Signal 1 int value matches (42)")

s2 = get(restored_signals, 1)
assert_eq(s2.sig_id, 2, "Signal 2 ID matches (2)")
assert_eq(s2.sig_str_val, "Shafiullah", "Signal 2 str value matches ('Shafiullah')")

// ── [Pillar 8]: Parameterized App Router ───────────────────────────────────────
say "\n── [Pillar 8]: Testing Parameterized App Router ──"

// Pattern: /users/:id/profile/:section
params = webx_match_pattern("/users/:id/profile/:section", "/users/105/profile/security")
assert_eq(len(params), 3, "Extracted 2 route parameters + match sentinel")
assert_eq(get(params, 0), "105", "Param 1 (:id) matches '105'")
assert_eq(get(params, 1), "security", "Param 2 (:section) matches 'security'")
assert_eq(get(params, 2), "__MATCHED__", "Route match sentinel verified")

mismatch_params = webx_match_pattern("/users/:id", "/products/42")
assert_eq(len(mismatch_params), 0, "Mismatched path returns empty param list")

// ── [Pillar 9]: Universal ESM Assimilator (Zero Node.js) ───────────────────────
say "\n── [Pillar 9]: Testing Universal ESM Assimilator (Zero Node.js) ──"

esm_mods = list()
m1 = esm_module_new("canvas-confetti", "https://esm.sh/canvas-confetti@1.9.3", "1.9.3")
esm_module_add_export(m1, "confetti")
push(esm_mods, m1)

m2 = esm_module_new("chart.js", "https://esm.sh/chart.js@4.4.0", "4.4.0")
esm_module_add_export(m2, "Chart")
push(esm_mods, m2)

import_map = esm_generate_importmap(esm_mods)
if str_contains(import_map, "\"canvas-confetti\": \"https://esm.sh/canvas-confetti@1.9.3\"") == 1
    say "  ✔ PASS: W3C Import Map JSON generated successfully"
else
    say "  ❌ FAILED: Import map missing canvas-confetti"
    exit(1)
end

bridge_js = esm_generate_bridge_script(esm_mods)
if str_contains(bridge_js, "window.webx_call_esm") == 1
    say "  ✔ PASS: Sovereign ESM JS FFI Bridge generated successfully"
else
    say "  ❌ FAILED: Missing ESM JS bridge"
    exit(1)
end

// ── [Pillar 10]: Full HTML5 Shell Integration ──────────────────────────────────
say "\n── [Pillar 10]: Testing Complete HTML5 Shell Integration ──"

full_page_html = webx_render_full_page("LiPi WebX App", card, classes_test, serialized_state, "/app.wasm")
if str_contains(full_page_html, "<!DOCTYPE html>") == 1 and str_contains(full_page_html, "<title>LiPi WebX App</title>") == 1
    say "  ✔ PASS: Complete HTML5 shell synthesized with inlined atomic CSS and embedded state"
else
    say "  ❌ FAILED: Full page HTML structure invalid"
    exit(1)
end

say "\n======================================================================"
say "🎉 ALL 10 BASE PILLARS OF LIPI WEBX SOVEREIGN FULL-STACK VERIFIED 100%!"
say "======================================================================"

// ── [Pillar 11]: Sovereign Vector Icon Engine (Zero npm / Zero Network) ─────────
say "\n── [Pillar 11]: Testing Sovereign Vector Icon Engine ──"

// 1. User avatar icon
svg_user = webx_icon_svg("user", 24, "text-blue-500")
assert_eq(str_contains(svg_user, "M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"), 1, "User icon contains body path")
assert_eq(str_contains(svg_user, "circle cx=\"12\" cy=\"7\" r=\"4\""), 1, "User icon contains head circle")

// 2. Check icon
svg_check = webx_icon_svg("check", 20, "text-emerald-400")
assert_eq(str_contains(svg_check, "points=\"20 6 9 17 4 12\""), 1, "Check icon contains polyline checkmark")

// 3. Alert icon
svg_alert = webx_icon_svg("alert", 24, "text-amber-400")
assert_eq(str_contains(svg_alert, "M10.29 3.86L1.82 18"), 1, "Alert icon contains triangle path")

// 4. Close icon
svg_close = webx_icon_svg("close", 18, "")
assert_eq(str_contains(svg_close, "x1=\"18\" y1=\"6\" x2=\"6\" y2=\"18\""), 1, "Close icon contains X stroke")

// 5. Menu icon
svg_menu = webx_icon_svg("menu", 24, "")
assert_eq(str_contains(svg_menu, "x1=\"3\" y1=\"12\" x2=\"21\" y2=\"12\""), 1, "Menu icon contains hamburger bars")

// 6. Search icon
svg_search = webx_icon_svg("search", 20, "")
assert_eq(str_contains(svg_search, "circle cx=\"11\" cy=\"11\" r=\"8\""), 1, "Search icon contains magnifying glass")

// 7. Settings icon
svg_settings = webx_icon_svg("settings", 24, "")
assert_eq(str_contains(svg_settings, "circle cx=\"12\" cy=\"12\" r=\"3\""), 1, "Settings icon contains center circle")

// 8. Chevron icon
svg_chev = webx_icon_svg("chevron-down", 16, "")
assert_eq(str_contains(svg_chev, "points=\"6 9 12 15 18 9\""), 1, "Chevron-down icon contains down arrow")

// 9. Trash & Edit icons
svg_trash = webx_icon_svg("trash", 20, "")
assert_eq(str_contains(svg_trash, "points=\"3 6 5 6 21 6\""), 1, "Trash icon contains can rim")

svg_edit = webx_icon_svg("edit", 20, "")
assert_eq(str_contains(svg_edit, "M18.5 2.5a2.121 2.121"), 1, "Edit icon contains pencil tip")

// 10. WebXNode wrapping
icon_node = webx_icon("my_settings_icon", "settings", 24, "text-slate-400")
icon_html = webx_render_node(icon_node)
assert_eq(str_contains(icon_html, "<svg width=\"24\" height=\"24\""), 1, "Icon renders as semantic SVG element")

// ── [Pillar 12]: Sovereign Pure SVG & Canvas Chart Engine ───────────────────────
say "\n── [Pillar 12]: Testing Sovereign Pure SVG & Canvas Chart Engine ──"

// 1. Bar Chart
bar_labels = list()
push(bar_labels, "Q1")
push(bar_labels, "Q2")
push(bar_labels, "Q3")
push(bar_labels, "Q4")

bar_vals = list()
push(bar_vals, 150)
push(bar_vals, 320)
push(bar_vals, 280)
push(bar_vals, 450)

chart_bar_node = webx_widget_chart_bar("quarterly_sales", bar_labels, bar_vals, 500, 300, "rounded-lg shadow-lg")
bar_svg = webx_render_node(chart_bar_node)

assert_eq(str_contains(bar_svg, "<svg id=\"quarterly_sales\" width=\"500\" height=\"300\""), 1, "Bar chart dimensions 500x300 verified")
assert_eq(str_contains(bar_svg, "role=\"img\" aria-label=\"Bar Chart\""), 1, "Bar chart accessibility ARIA role verified")
assert_eq(str_contains(bar_svg, "stroke-dasharray=\"3 3\""), 1, "Bar chart rendered horizontal gridlines")
assert_eq(str_contains(bar_svg, "450"), 1, "Bar chart rendered peak value label 450")
assert_eq(str_contains(bar_svg, "Q4"), 1, "Bar chart rendered category label Q4")

// 2. Line Chart
line_labels = list()
push(line_labels, "Mon")
push(line_labels, "Tue")
push(line_labels, "Wed")
push(line_labels, "Thu")
push(line_labels, "Fri")

line_vals = list()
push(line_vals, 20)
push(line_vals, 55)
push(line_vals, 40)
push(line_vals, 85)
push(line_vals, 70)

chart_line_node = webx_widget_chart_line("weekly_traffic", line_labels, line_vals, 500, 250, "rounded-lg")
line_svg = webx_render_node(chart_line_node)

assert_eq(str_contains(line_svg, "<svg id=\"weekly_traffic\" width=\"500\" height=\"250\""), 1, "Line chart dimensions 500x250 verified")
assert_eq(str_contains(line_svg, "<polyline points="), 1, "Line chart rendered polyline path")
assert_eq(str_contains(line_svg, "<polygon points="), 1, "Line chart rendered area gradient fill")
assert_eq(str_contains(line_svg, "<circle cx="), 1, "Line chart rendered data point markers")

// 3. Pie Chart
pie_labels = list()
push(pie_labels, "Direct")
push(pie_labels, "Organic")
push(pie_labels, "Referral")

pie_vals = list()
push(pie_vals, 50)
push(pie_vals, 30)
push(pie_vals, 20)

chart_pie_node = webx_widget_chart_pie("traffic_sources", pie_labels, pie_vals, 400, 260, "")
pie_svg = webx_render_node(chart_pie_node)

assert_eq(str_contains(pie_svg, "<svg id=\"traffic_sources\" width=\"400\" height=\"260\""), 1, "Pie chart dimensions 400x260 verified")
assert_eq(str_contains(pie_svg, "<path d=\"M "), 1, "Pie chart rendered trigonometric arc slice paths")
assert_eq(str_contains(pie_svg, "Direct (50%)"), 1, "Pie chart legend contains 50% slice label")
assert_eq(str_contains(pie_svg, "Organic (30%)"), 1, "Pie chart legend contains 30% slice label")

// 4. Canvas Script Generation
canvas_js = webx_widget_chart_canvas_script("canvas_chart_1", "bar", bar_labels, bar_vals)
assert_eq(str_contains(canvas_js, "getContext('2d')"), 1, "Canvas script acquires 2D rendering context")
assert_eq(str_contains(canvas_js, "fillRect("), 1, "Canvas script executes native fillRect drawing")

// 5. Robustness: Bar chart with negative values & zero-bounding
neg_bar_labels = list()
push(neg_bar_labels, "Loss")
push(neg_bar_labels, "Flat")
push(neg_bar_labels, "Profit")
neg_bar_vals = list()
push(neg_bar_vals, -50)
push(neg_bar_vals, 0)
push(neg_bar_vals, 120)
neg_bar_node = webx_widget_chart_bar("neg_chart", neg_bar_labels, neg_bar_vals, 400, 200, "")
neg_bar_svg = webx_render_node(neg_bar_node)
assert_eq(str_contains(neg_bar_svg, "height=\"-"), 0, "Bar chart never emits negative height rects")

// 6. Robustness: Pie chart with negative & zero values
neg_pie_labels = list()
push(neg_pie_labels, "Deficit")
push(neg_pie_labels, "Zero")
push(neg_pie_labels, "Surplus")
neg_pie_vals = list()
push(neg_pie_vals, -30)
push(neg_pie_vals, 0)
push(neg_pie_vals, 100)
neg_pie_node = webx_widget_chart_pie("neg_pie", neg_pie_labels, neg_pie_vals, 350, 220, "")
neg_pie_svg = webx_render_node(neg_pie_node)
assert_eq(str_contains(neg_pie_svg, "Surplus (100%)"), 1, "Pie chart gracefully skips negative and zero slices")

// ── [Pillar 13]: Sovereign Modern UI Widget Suite ──────────────────────────────
say "\n── [Pillar 13]: Testing Sovereign Modern UI Widget Suite ──"

// 1. Toast Notification
t_ok = webx_toast("t_ok", "Build Successful", "Artifact compiled in 0.42ms", WEBX_TOAST_SUCCESS, 601, "")
t_ok_html = webx_render_node(t_ok)
assert_eq(str_contains(t_ok_html, "border-emerald-500"), 1, "Success toast has emerald border")
assert_eq(str_contains(t_ok_html, "Build Successful"), 1, "Success toast renders title")
assert_eq(str_contains(t_ok_html, "Artifact compiled in 0.42ms"), 1, "Success toast renders message body")
assert_eq(str_contains(t_ok_html, "data-action=\"601\""), 1, "Toast dismiss button has action id 601")

t_err = webx_toast("t_err", "Memory Limit", "Heap allocation exceeded threshold", WEBX_TOAST_ERROR, 602, "")
t_err_html = webx_render_node(t_err)
assert_eq(str_contains(t_err_html, "border-rose-500"), 1, "Error toast has rose border")

toasts_list = list()
push(toasts_list, t_ok)
push(toasts_list, t_err)
toast_ctr = webx_toast_container("app_toasts", toasts_list, "")
ctr_html = webx_render_node(toast_ctr)
assert_eq(str_contains(ctr_html, "fixed bottom-4 right-4 z-50"), 1, "Toast container has fixed viewport positioning")

// 2. Accordion Widget
acc_titles = list()
push(acc_titles, "Micro-Pipeline Architecture")
push(acc_titles, "Sovereign Memory Model")

acc_contents = list()
push(acc_contents, webx_text("c1", "Single-pass compiler emitting direct x86_64 ELF machine code.", ""))
push(acc_contents, webx_text("c2", "Deterministic slab allocator with zero libc runtime overhead.", ""))

acc_node = webx_accordion("acc_faq", acc_titles, acc_contents, 0, 701, "")
acc_html = webx_render_node(acc_node)
assert_eq(str_contains(acc_html, "Micro-Pipeline Architecture"), 1, "Accordion renders section 0 header")
assert_eq(str_contains(acc_html, "Single-pass compiler emitting"), 1, "Accordion renders open section 0 panel")
assert_eq(str_contains(acc_html, "Sovereign Memory Model"), 1, "Accordion renders section 1 header")

// 3. Dropdown Menu Widget
dd_opts = list()
push(dd_opts, "x86_64 Direct Silicon")
push(dd_opts, "AArch64 Apple Silicon")
push(dd_opts, "WebAssembly Pure MVP")

dd_node = webx_dropdown("target_selector", "Select Target", dd_opts, 2, 1, 801, "")
dd_html = webx_render_node(dd_node)
assert_eq(str_contains(dd_html, "WebAssembly Pure MVP"), 1, "Dropdown renders selected value label")
assert_eq(str_contains(dd_html, "role=\"listbox\""), 1, "Dropdown popup menu has listbox role")
assert_eq(str_contains(dd_html, "AArch64 Apple Silicon"), 1, "Dropdown renders menu options")

// 4. Progress Bar Widget
prog_node = webx_progress("p_dl", 78, 100, "Compiling Stage-3 Binary", 1, 2, "")
prog_html = webx_render_node(prog_node)
assert_eq(str_contains(prog_html, "role=\"progressbar\" aria-valuenow=\"78\" aria-valuemin=\"0\" aria-valuemax=\"100\""), 1, "Progress bar has correct ARIA attributes")
assert_eq(str_contains(prog_html, "78%"), 1, "Progress bar renders 78% readout")
assert_eq(str_contains(prog_html, "Compiling Stage-3 Binary"), 1, "Progress bar renders label")
assert_eq(str_contains(prog_html, "style=\"width: 78%; height: 100%;\""), 1, "Progress bar has exact inline width percentage")
assert_eq(str_contains(prog_html, "bg-emerald-500"), 1, "Progress bar has emerald success variant")

// 5. Drawer Sheet Widget
drawer_content = webx_text("d_txt", "Configure sovereign cluster node telemetry parameters.", "")
drawer_open = webx_drawer("settings_drawer", 1, "right", "Node Configuration", drawer_content, 901, "")
drw_html = webx_render_node(drawer_open)
assert_eq(str_contains(drw_html, "role=\"dialog\" aria-modal=\"true\""), 1, "Drawer has modal dialog accessibility role")
assert_eq(str_contains(drw_html, "Node Configuration"), 1, "Drawer header renders title")
assert_eq(str_contains(drw_html, "data-action=\"901\""), 1, "Drawer close button has action id 901")
assert_eq(str_contains(drw_html, "fixed top-0 bottom-0 right-0 w-80"), 1, "Drawer positioned on right viewport edge")

drawer_closed = webx_drawer("closed_drawer", 0, "right", "Title", 0, 902, "")
assert_eq(str_contains(webx_render_node(drawer_closed), "style=\"display: none;\""), 1, "Closed drawer rendered in dormant state")

// Nested Accordion inside Drawer Sheet (Deep layout tree composition)
drawer_with_acc = webx_drawer("acc_drawer", 1, "left", "Advanced Settings", acc_node, 903, "")
drw_acc_html = webx_render_node(drawer_with_acc)
assert_eq(str_contains(drw_acc_html, "Micro-Pipeline Architecture"), 1, "Drawer embeds nested accordion header")
assert_eq(str_contains(drw_acc_html, "fixed top-0 bottom-0 left-0 w-80"), 1, "Left sliding drawer sheet positioning verified")

// 6. Theme Toggle Widget
theme_dark_btn = webx_theme_toggle("theme_tgl", "dark", 950, "")
tgl_dark_html = webx_render_node(theme_dark_btn)
assert_eq(str_contains(tgl_dark_html, "Light Mode"), 1, "Dark theme toggle offers switch to Light Mode")
assert_eq(str_contains(tgl_dark_html, "data-action=\"950\""), 1, "Theme toggle has action id 950")

theme_light_btn = webx_theme_toggle("theme_tgl2", "light", 951, "")
tgl_light_html = webx_render_node(theme_light_btn)
assert_eq(str_contains(tgl_light_html, "Dark Mode"), 1, "Light theme toggle offers switch to Dark Mode")

// ── [Pillar 14]: Sovereign Local Offline Asset Assimilator & Bundle Cacher ──────
say "\n── [Pillar 14]: Testing Sovereign Local Offline Asset Assimilator & Bundle Cacher ──"

cache = esm_cache_new("./vendor")

// Register local sovereign modules into in-memory offline cacher
m_crypto = esm_cache_register(cache, "sovereign-crypto", "2.1.0", "vendor/crypto.js", "export function sha256(msg) { return 'hash'; }")
m_charts = esm_cache_register(cache, "sovereign-charts", "1.4.0", "vendor/charts.js", "export function renderSvg() { return true; }")

assert_eq(len(cache.cache_entries), 2, "Assimilated 2 local packages into offline cache")

// Resolution
url_crypto = esm_cache_resolve(cache, "sovereign-crypto")
assert_eq(url_crypto, "./vendor/sovereign-crypto.js", "Resolved sovereign-crypto to local path")

url_unknown = esm_cache_resolve(cache, "non-existent")
assert_eq(url_unknown, "", "Unknown package resolves to empty string")

// Checksum / integrity hash
assert_eq(str_contains(m_crypto.entry_hash, "lp-"), 1, "Sovereign FNV-1a integrity hash generated")

// Offline Import Map (0% External CDN)
offline_importmap = esm_generate_offline_importmap(cache)
assert_eq(str_contains(offline_importmap, "\"sovereign-crypto\": \"./vendor/sovereign-crypto.js\""), 1, "Offline import map maps to local vendor asset")
assert_eq(str_contains(offline_importmap, "https://"), 0, "Offline import map contains ZERO https:// CDN URLs")

// Air-Gapped Inlined Bundle
inline_bundle = esm_generate_inline_bundle(cache)
assert_eq(str_contains(inline_bundle, "window['__esm_sovereign-crypto']"), 1, "Inline bundle registers sovereign-crypto into window scope")
assert_eq(str_contains(inline_bundle, "window['__esm_sovereign-charts']"), 1, "Inline bundle registers sovereign-charts into window scope")

// Sovereign Offline Manifest
manifest_json = esm_generate_offline_manifest(cache)
assert_eq(str_contains(manifest_json, "\"sovereign_offline\": true"), 1, "Manifest asserts sovereign offline operation")
assert_eq(str_contains(manifest_json, "\"module_count\": 2"), 1, "Manifest counts 2 cached modules")

// ── [Pillar 15]: Sovereign End-to-End Dashboard Synthesis ───────────────────────
say "\n── [Pillar 15]: Testing Sovereign End-to-End Dashboard Synthesis ──"

// Build unified layout with navbar, icons, charts, widgets, and theme toggle
nav_kids = list()
push(nav_kids, webx_icon("logo_icon", "settings", 24, "text-blue-500"))
push(nav_kids, webx_node_new(WEBX_NODE_TEXT, "nav_title", "h1", "LiPi WebX Sovereign Ops Console", "font-bold text-xl text-white", 0))
push(nav_kids, theme_dark_btn)
navbar = webx_container("top_nav", "w-full flex justify-between items-center p-4 bg-slate-900 border-b border-slate-700", nav_kids)

main_grid_kids = list()
push(main_grid_kids, chart_bar_node)
push(main_grid_kids, chart_line_node)
push(main_grid_kids, chart_pie_node)
push(main_grid_kids, prog_node)
push(main_grid_kids, acc_node)
push(main_grid_kids, dd_node)
push(main_grid_kids, t_ok)

dashboard_body = webx_container("dash_body", "p-6 flex flex-col gap-6", main_grid_kids)

dash_root_kids = list()
push(dash_root_kids, navbar)
push(dash_root_kids, dashboard_body)
dash_root = webx_container("dashboard_app", "w-full min-h-screen bg-slate-950 text-slate-100", dash_root_kids)

all_class_tokens = "w-full p-4 p-6 bg-slate-900 bg-slate-950 border-b border-slate-700 flex justify-between items-center flex-col gap-6 font-bold text-xl text-white rounded-lg shadow-lg relative z-50 overflow-hidden cursor-pointer"
dashboard_html = webx_render_full_page("LiPi Sovereign Ops", dash_root, all_class_tokens, serialized_state, "/app.wasm")

assert_eq(str_contains(dashboard_html, "<!DOCTYPE html>"), 1, "Complete dashboard starts with valid DOCTYPE")
assert_eq(str_contains(dashboard_html, "<title>LiPi Sovereign Ops</title>"), 1, "Dashboard title rendered")
assert_eq(str_contains(dashboard_html, "LiPi WebX Sovereign Ops Console"), 1, "Dashboard navbar header rendered")
assert_eq(str_contains(dashboard_html, "<svg id=\"quarterly_sales\""), 1, "Dashboard contains bar chart")
assert_eq(str_contains(dashboard_html, "<svg id=\"weekly_traffic\""), 1, "Dashboard contains line chart")
assert_eq(str_contains(dashboard_html, "<svg id=\"traffic_sources\""), 1, "Dashboard contains pie chart")
assert_eq(str_contains(dashboard_html, "Compiling Stage-3 Binary"), 1, "Dashboard contains progress widget")
assert_eq(str_contains(dashboard_html, "Build Successful"), 1, "Dashboard contains toast widget")
assert_eq(str_contains(dashboard_html, "__WEBX_STATE__"), 1, "Dashboard contains embedded resumable state snapshot")
assert_eq(str_contains(dashboard_html, "https://"), 0, "Dashboard contains ZERO external CDN or script dependencies (100% sovereign)!")

// ── [Pillar 16]: Sovereign Islands Architecture & Client-Side Runtime ─────────
say "\n── [Pillar 16]: Testing Sovereign Islands Architecture & Offline Import Maps ──"

// 1. Offline package assimilation & import map
m_confetti_offline = webx_assimilate_offline("canvas-confetti", "1.9.3", "dist/assets/esm")
assert_eq(m_confetti_offline.esm_is_offline, 1, "Module flagged as sovereign offline asset")
assert_eq(m_confetti_offline.esm_url, "/assets/esm/canvas-confetti.js", "Relative URL is /assets/esm/canvas-confetti.js")
assert_eq(m_confetti_offline.esm_local_path, "dist/assets/esm/canvas-confetti.js", "Local path is dist/assets/esm/canvas-confetti.js")

offline_mods = list()
push(offline_mods, m_confetti_offline)
push(offline_mods, webx_assimilate_offline("chart.js", "4.4.0", ".lipi/cache"))

island_import_map = webx_generate_offline_importmap(offline_mods)
assert_eq(str_contains(island_import_map, "<script type=\"importmap\">"), 1, "W3C importmap script emitted")
assert_eq(str_contains(island_import_map, "\"canvas-confetti\": \"/assets/esm/canvas-confetti.js\""), 1, "Import map maps specifier to /assets/esm/...")
assert_eq(str_contains(island_import_map, "https://"), 0, "Import map contains zero external CDN links")

// 2. Client-side Island runtime (< 1 KB)
isl_runtime = webx_island_script()
isl_len = len(isl_runtime)
say "  • Client-Side Island Runtime Size: " + str(isl_len) + " bytes"
if isl_len < 1024
    say "  ✔ PASS: Sovereign islands loader runtime strictly under 1 KB (" + str(isl_len) + " < 1024 bytes)"
else
    say "  ❌ FAILED: Islands loader runtime exceeded 1 KB budget"
    exit(1)
end
assert_eq(str_contains(isl_runtime, "IntersectionObserver"), 1, "Runtime incorporates IntersectionObserver visibility scheduling")
assert_eq(str_contains(isl_runtime, "requestIdleCallback"), 1, "Runtime incorporates requestIdleCallback idle scheduling")
assert_eq(str_contains(isl_runtime, "window.__webx_hydrate_islands"), 1, "Runtime exposes window.__webx_hydrate_islands hook")

// 3. Isolated Island Container with autonomous activation
isl_props = "{\"particleCount\": 150, \"origin\": {\"y\": 0.6}}"
isl_html = webx_island("celebrate_island", "canvas-confetti", "#confetti_canvas", isl_props, "<canvas id=\"confetti_canvas\"></canvas>")

assert_eq(str_contains(isl_html, "id=\"celebrate_island\""), 1, "Island container rendered unique DOM ID")
assert_eq(str_contains(isl_html, "data-webx-island=\"true\""), 1, "Island marked with data-webx-island")
assert_eq(str_contains(isl_html, "data-module=\"canvas-confetti\""), 1, "Island specifies target client module")
assert_eq(str_contains(isl_html, "data-mount=\"#confetti_canvas\""), 1, "Island specifies mount target selector")
assert_eq(str_contains(isl_html, "&quot;particleCount&quot;: 150"), 1, "Island embeds attribute-safe escaped initial props")
assert_eq(str_contains(isl_html, "<canvas id=\"confetti_canvas\"></canvas>"), 1, "Island embeds pre-rendered fallback markup")
assert_eq(str_contains(isl_html, "<script type=\"module\">"), 1, "Island emits autonomous activation script")
assert_eq(str_contains(isl_html, "import(\"canvas-confetti\")"), 1, "Island activation script dynamically imports module")

// 4. WebXNode Layout Composition & Full Page Assembly
isl_node = webx_island_node("layout_island", "canvas-confetti", "", "{}", "<p>Island in Tree</p>")
isl_node_rendered = webx_render_node(isl_node)
assert_eq(str_contains(isl_node_rendered, "data-webx-island=\"true\""), 1, "Island integrates into WebXNode tree seamlessly")

full_island_page = webx_render_island_page("LiPi Sovereign Islands", isl_node_rendered, offline_mods, "p-4 text-white")
assert_eq(str_contains(full_island_page, "<!DOCTYPE html>"), 1, "Full island page has valid DOCTYPE")
assert_eq(str_contains(full_island_page, "<title>LiPi Sovereign Islands</title>"), 1, "Full island page renders title")
assert_eq(str_contains(full_island_page, "<script type=\"importmap\">"), 1, "Full island page embeds W3C offline import map")
assert_eq(str_contains(full_island_page, "window.__webx_hydrate_islands"), 1, "Full island page embeds sovereign islands runtime")

say "\n======================================================================"
say "🎉 ALL 16 PILLARS OF LIPI WEBX SOVEREIGN FULL-STACK VERIFIED 100%!"
say "======================================================================"
