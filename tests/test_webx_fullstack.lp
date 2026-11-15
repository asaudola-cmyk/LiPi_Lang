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
say "🎉 ALL 10 PILLARS OF LIPI WEBX SOVEREIGN FULL-STACK VERIFIED 100%!"
say "======================================================================"
