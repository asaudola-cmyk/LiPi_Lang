// ==============================================================================
// 🧪 LIPI WEBX SOVEREIGN ISLANDS & OFFLINE ASSIMILATOR TEST SUITE
// File: tests/test_webx_islands.lp
// 100% Pure LiPi Implementation — Zero External / Node.js / C Dependencies
// ==============================================================================

include "aati/lipi_web/webx_islands.lp"
include "aati/lipi_web/webx_primitives.lp"

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
say "║  🏝️ LIPI WEBX SOVEREIGN ISLANDS & OFFLINE ESM ASSIMILATOR SUITE     ║"
say "╚══════════════════════════════════════════════════════════════════════╝"

// ── Test Section 1: Attribute Escaping ─────────────────────────────────────────
say "\n── [Section 1]: HTML Attribute & Props Escaping ──"

raw_json = "{\"title\": \"Island & Co.\", \"count\": 42, \"tags\": [\"<webx>\", \"sovereign\"]}"
esc_json = webx_escape_attr(raw_json)

assert_eq(str_contains(esc_json, "&quot;title&quot;"), 1, "Double quotes escaped as &quot;")
assert_eq(str_contains(esc_json, "&amp;"), 1, "Ampersands escaped as &amp;")
assert_eq(str_contains(esc_json, "&lt;webx&gt;"), 1, "Angle brackets escaped as &lt; and &gt;")
assert_eq(str_contains(esc_json, "\""), 0, "No raw unescaped double quotes remain")

// ── Test Section 2: Sovereign Offline ESM Asset Assimilator ────────────────────
say "\n── [Section 2]: Offline Asset Assimilator (webx_assimilate_offline) ──"

// 1. Standard package in dist/assets/esm/
m_confetti = webx_assimilate_offline("canvas-confetti", "1.9.3", "dist/assets/esm/")
assert_eq(m_confetti.esm_name, "canvas-confetti", "Package name matches")
assert_eq(m_confetti.esm_version, "1.9.3", "Package version matches")
assert_eq(m_confetti.esm_is_offline, 1, "Flagged as offline sovereign asset")
assert_eq(m_confetti.esm_local_path, "dist/assets/esm/canvas-confetti.js", "Local disk path matches")
assert_eq(m_confetti.esm_url, "/assets/esm/canvas-confetti.js", "Relative URL is /assets/esm/...")

// 2. Package already ending with .js in .lipi/cache
m_chart = webx_assimilate_offline("chart.js", "4.4.0", ".lipi/cache")
assert_eq(m_chart.esm_name, "chart.js", "Package name matches chart.js")
assert_eq(m_chart.esm_local_path, ".lipi/cache/chart.js", "Disk path does not double .js extension")
assert_eq(m_chart.esm_url, "/assets/esm/chart.js", "Relative URL maps to /assets/esm/chart.js")

// 3. Package with root relative dir
m_three = webx_assimilate_offline("three", "0.160.0", "/assets/esm")
assert_eq(m_three.esm_local_path, "/assets/esm/three.js", "Root relative disk path matches")
assert_eq(m_three.esm_url, "/assets/esm/three.js", "Relative URL matches /assets/esm/three.js")

// 4. Default directory fallback
m_alpine = webx_assimilate_offline("alpinejs", "3.13.0", "")
assert_eq(m_alpine.esm_local_path, "dist/assets/esm/alpinejs.js", "Empty local dir defaults to dist/assets/esm")
assert_eq(m_alpine.esm_url, "/assets/esm/alpinejs.js", "Relative URL defaults to /assets/esm/alpinejs.js")

// ── Test Section 3: Offline W3C Import Map Generation ─────────────────────────
say "\n── [Section 3]: Offline W3C <script type=\"importmap\"> Generation ──"

mods_list = list()
push(mods_list, m_confetti)
push(mods_list, m_chart)
push(mods_list, m_three)
push(mods_list, m_alpine)

offline_map = webx_generate_offline_importmap(mods_list)
assert_eq(str_contains(offline_map, "<script type=\"importmap\">"), 1, "Contains W3C importmap script tag")
assert_eq(str_contains(offline_map, "\"canvas-confetti\": \"/assets/esm/canvas-confetti.js\""), 1, "Maps canvas-confetti to local URL")
assert_eq(str_contains(offline_map, "\"chart.js\": \"/assets/esm/chart.js\""), 1, "Maps chart.js to local URL")
assert_eq(str_contains(offline_map, "\"three\": \"/assets/esm/three.js\""), 1, "Maps three to local URL")
assert_eq(str_contains(offline_map, "\"alpinejs\": \"/assets/esm/alpinejs.js\""), 1, "Maps alpinejs to local URL")
assert_eq(str_contains(offline_map, "https://"), 0, "Contains zero external CDN URLs (100% sovereign)")

// Also test converting a remote module automatically in offline import map
m_remote = esm_module_new("lodash-es", "https://esm.sh/lodash-es@4.17.21", "4.17.21")
remote_list = list()
push(remote_list, m_remote)
converted_map = webx_generate_offline_importmap(remote_list)
assert_eq(str_contains(converted_map, "\"lodash-es\": \"/assets/esm/lodash-es.js\""), 1, "Converted remote module to local relative URL")
assert_eq(str_contains(converted_map, "https://"), 0, "Converted map contains zero https://")

// ── Test Section 4: Sovereign Islands Runtime Script Budget ───────────────────
say "\n── [Section 4]: Lightweight Client-Side Islands Runtime (webx_island_script) ──"

runtime_code = webx_island_script()
rlen = len(runtime_code)
say "  • Islands Runtime Script Size: " + str(rlen) + " bytes"

if rlen < 1024
    say "  ✔ PASS: Islands runtime strictly under 1 KB limit (" + str(rlen) + " < 1024 bytes)"
else
    say "  ❌ FAILED: Islands runtime exceeded 1 KB budget"
    exit(1)
end

assert_eq(str_contains(runtime_code, "<script type=\"module\">"), 1, "Runtime emits modern ES module script")
assert_eq(str_contains(runtime_code, "data-webx-island"), 1, "Runtime targets [data-webx-island=\"true\"]")
assert_eq(str_contains(runtime_code, "IntersectionObserver"), 1, "Runtime utilizes IntersectionObserver for visibility")
assert_eq(str_contains(runtime_code, "requestIdleCallback"), 1, "Runtime utilizes requestIdleCallback for idle activation")
assert_eq(str_contains(runtime_code, "window.__webx_hydrate_islands"), 1, "Exposes global programmatic hydration hook")
assert_eq(str_contains(runtime_code, "data-webx-hydrated"), 1, "Tracks hydration state preventing duplicate execution")

// ── Test Section 5: Sovereign Island Container & Autonomous Activation ────────
say "\n── [Section 5]: Island Container & Autonomous Activation (webx_island) ──"

fb_html = "<div class=\"p-4 text-center text-slate-400\">Initializing confetti...</div>"
props_json = "{\"particleCount\": 100, \"spread\": 70}"
island_output = webx_island("confetti_island", "canvas-confetti", "#confetti_mount", props_json, fb_html)

// 1. Container verification
assert_eq(str_contains(island_output, "<div id=\"confetti_island\""), 1, "Island container has exact ID")
assert_eq(str_contains(island_output, "class=\"webx-island\""), 1, "Island container has webx-island class")
assert_eq(str_contains(island_output, "data-webx-island=\"true\""), 1, "Island marked with data-webx-island")
assert_eq(str_contains(island_output, "data-module=\"canvas-confetti\""), 1, "Island marked with target module")
assert_eq(str_contains(island_output, "data-mount=\"#confetti_mount\""), 1, "Island specifies mount selector")
assert_eq(str_contains(island_output, "&quot;particleCount&quot;: 100"), 1, "Island embeds safely escaped initial props")
assert_eq(str_contains(island_output, "Initializing confetti..."), 1, "Island contains SSR fallback markup")

// 2. Autonomous Activation script verification
assert_eq(str_contains(island_output, "<script type=\"module\">"), 1, "Emits autonomous ES module activation script")
assert_eq(str_contains(island_output, "document.getElementById(\"confetti_island\")"), 1, "Script targets specific island ID")
assert_eq(str_contains(island_output, "import(\"canvas-confetti\")"), 1, "Script performs dynamic import of client module")
assert_eq(str_contains(island_output, "rootMargin: \"200px\""), 1, "Pre-hydrates with 200px viewport margin")
assert_eq(str_contains(island_output, "mod.mount"), 1, "Dispatches to module mount lifecycle")

// ── Test Section 6: Island Hydration Strategies ───────────────────────────────
say "\n── [Section 6]: Activation Strategies (visible, idle, media, load) ──"

// 1. Idle Strategy
idle_island = webx_island_with_strategy("stats_idle", "chart.js", "", "{}", "<p>Loading chart</p>", "idle")
assert_eq(str_contains(idle_island, "requestIdleCallback"), 1, "Idle strategy schedules on idle")
assert_eq(str_contains(idle_island, "data-module=\"chart.js\""), 1, "Idle island specifies module")
assert_eq(str_contains(idle_island, "data-strategy=\"idle\""), 1, "Idle island container sets data-strategy attribute")

// 2. Media Query Strategy
media_island = webx_island_with_strategy("desktop_island", "three", "", "{}", "<p>3D Scene</p>", "media:(min-width: 1024px)")
assert_eq(str_contains(media_island, "window.matchMedia(\"(min-width: 1024px)\")"), 1, "Media query strategy configures matchMedia")
assert_eq(str_contains(media_island, "data-module=\"three\""), 1, "Media island specifies module")
assert_eq(str_contains(media_island, "data-strategy=\"media:(min-width: 1024px)\""), 1, "Media island container sets data-strategy attribute")

// 3. Load Strategy
load_island = webx_island_with_strategy("instant_island", "alpinejs", "", "{}", "<p>Alpine</p>", "load")
assert_eq(str_contains(load_island, "window.addEventListener(\"load\""), 1, "Load strategy hooks window load")
assert_eq(str_contains(load_island, "data-strategy=\"load\""), 1, "Load island container sets data-strategy attribute")

// ── Test Section 7: WebXNode Tree Integration ─────────────────────────────────
say "\n── [Section 7]: WebXNode Layout Composition (webx_island_node) ──"

i_node = webx_island_node("tree_island", "canvas-confetti", "", "{}", "<p>Node Fallback</p>")
node_rendered = webx_render_node(i_node)

assert_eq(str_contains(node_rendered, "<div id=\"tree_island\""), 1, "WebXNode renders island container HTML")
assert_eq(str_contains(node_rendered, "data-webx-island=\"true\""), 1, "WebXNode retains data-webx-island attribute")
assert_eq(str_contains(node_rendered, "<script type=\"module\">"), 1, "WebXNode includes autonomous activation script")

// ── Test Section 8: Full Sovereign Page Assembly ──────────────────────────────
say "\n── [Section 8]: Full-Page Sovereign Assembly (webx_render_island_page) ──"

full_page = webx_render_island_page("Sovereign Islands Portal", node_rendered, mods_list, "p-4 text-center font-bold")
assert_eq(str_contains(full_page, "<!DOCTYPE html>"), 1, "Page has valid HTML5 DOCTYPE")
assert_eq(str_contains(full_page, "<title>Sovereign Islands Portal</title>"), 1, "Page has custom title")
assert_eq(str_contains(full_page, "<script type=\"importmap\">"), 1, "Page embeds W3C offline import map")
assert_eq(str_contains(full_page, "\"canvas-confetti\": \"/assets/esm/canvas-confetti.js\""), 1, "Import map contains offline assets")
assert_eq(str_contains(full_page, "<div id=\"tree_island\""), 1, "Page contains island container")
assert_eq(str_contains(full_page, "window.__webx_hydrate_islands"), 1, "Page embeds centralized islands runtime")
assert_eq(str_contains(full_page, "https://"), 0, "Complete page contains ZERO external network URLs (100% sovereign)")

// ── Test Section 9: Cross-Platform Windows Paths & Multiline Escaping ─────────
say "\n── [Section 9]: Cross-Platform Windows Paths & Multiline Escaping ──"

// 1. Windows backslash path normalization
m_win = webx_assimilate_offline("win-module", "1.0.0", "dist\\assets\\esm\\")
assert_eq(m_win.esm_local_path, "dist/assets/esm/win-module.js", "Windows backslash normalized to forward slash in local path")
assert_eq(m_win.esm_url, "/assets/esm/win-module.js", "Windows path normalized in browser relative URL")

// 2. Multiline props escaping (ASCII 10 / 13)
multiline_raw = "line1\nline2\r\nline3"
multiline_esc = webx_escape_attr(multiline_raw)
assert_eq(str_contains(multiline_esc, "&#10;"), 1, "Newline ord 10 escaped as &#10;")
assert_eq(str_contains(multiline_esc, "&#13;"), 1, "Carriage return ord 13 escaped as &#13;")

// ── Test Section 10: Import Map & Bridge Script Specifier Deduplication ────────
say "\n── [Section 10]: Specifier Deduplication & Concurrency Race Guards ──"

// 1. Duplicate packages in import map
dup_mods = list()
push(dup_mods, m_confetti)
push(dup_mods, m_confetti) // Duplicate
push(dup_mods, m_chart)
push(dup_mods, m_chart)    // Duplicate
dedup_map = webx_generate_offline_importmap(dup_mods)

// Verify single occurrence of each specifier key in the import map
first_idx = str_index_of(dedup_map, "\"canvas-confetti\":")
assert_eq(first_idx > 0, 1, "First occurrence of canvas-confetti exists")
rem_str = str_slice(dedup_map, first_idx + 18, len(dedup_map))
assert_eq(str_contains(rem_str, "\"canvas-confetti\":"), 0, "No duplicate key for canvas-confetti in import map")

// 2. Duplicate packages in ESM Bridge script
bridge_dup = esm_generate_bridge_script(dup_mods)
b_idx = str_index_of(bridge_dup, "import * as canvas_confetti_pkg")
assert_eq(b_idx > 0, 1, "First occurrence of bridge import exists")
b_rem = str_slice(bridge_dup, b_idx + 32, len(bridge_dup))
assert_eq(str_contains(b_rem, "import * as canvas_confetti_pkg"), 0, "No duplicate declaration in bridge script scope")

// 3. Synchronous Hydration Guard Verification
act_script = webx_island_activation_script("test_isl", "canvas-confetti", "", "visible")
assert_eq(str_contains(act_script, "el.setAttribute(\"data-webx-hydrated\", \"true\");"), 1, "Activation script sets hydration lock synchronously")
assert_eq(str_contains(act_script, "el.hasAttribute(\"data-webx-hydrated\")"), 1, "Activation script checks hydration existence guard")

say "\n======================================================================"
say "🎉 ALL 10 TESTS IN SOVEREIGN ISLANDS & OFFLINE ESM SUITE PASSED 100%!"
say "======================================================================"
