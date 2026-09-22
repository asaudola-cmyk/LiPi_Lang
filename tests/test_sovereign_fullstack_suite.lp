// ==============================================================================
// 🧪 LIPI SOVEREIGN FULL-STACK SUITE REGRESSION TEST
// Test Suite: tests/test_sovereign_fullstack_suite.lp
// Milestone: Sovereign Full-Stack Paradigm (Displacing Flutter, Swift, React, Next & Laravel)
// 100% Pure LiPi Implementation — Zero External / C / NPM Dependencies
// ==============================================================================

include "universe/gui/sovereign_ui.lp"
include "universe/web/sovereign_framework.lp"

fn assert_eq actual expected label
    if actual == expected
        say "  ✔ [PASS] " + label + ": " + actual
        return 1
    else
        say "  ❌ [FAIL] " + label + " -> Expected: " + expected + ", Got: " + actual
        return 0

fn assert_gt actual minimum label
    if actual > minimum
        say "  ✔ [PASS] " + label + ": " + actual + " > " + minimum
        return 1
    else
        say "  ❌ [FAIL] " + label + " -> Expected > " + minimum + ", Got: " + actual
        return 0

fn main
    say "================================================================="
    say "🧪 LIPI SOVEREIGN FULL-STACK ECOSYSTEM TEST SUITE 🧪"
    say "================================================================="

    total_tests = 0
    passed_tests = 0

    // ── Section 1: Reactive Signals & Dirty Tracking ──────────────────────────
    say "\n▶ Section 1: Reactive Signals Engine..."
    total_tests = total_tests + 1
    sig = ui_signal_new(10)
    ok_s1 = assert_eq(ui_signal_get(sig), 10, "Signal Initial Value")
    ui_signal_set(sig, 25)
    ok_s2 = assert_eq(ui_signal_get(sig), 25, "Signal Mutated Value")
    ok_s3 = assert_eq(sig.sig_is_dirty, 1, "Signal Dirty Bit")
    ui_signal_clean(sig)
    ok_s4 = assert_eq(sig.sig_is_dirty, 0, "Signal Clean Bit")
    if ok_s1 == 1 and ok_s2 == 1 and ok_s3 == 1 and ok_s4 == 1
        passed_tests = passed_tests + 1

    // ── Section 2: Declarative UI Node Graph ──────────────────────────────────
    say "\n▶ Section 2: Declarative UI Component Graph..."
    total_tests = total_tests + 1
    btn = ui_button("btn_buy", "Buy Now", 2060267, 16777215, 501)
    badge = ui_badge("badge_sale", "50% OFF", 2328118, 16777215)
    ok_u1 = assert_eq(btn.ui_type, UI_BUTTON, "Button Node Type")
    ok_u2 = assert_eq(ui_node_text(btn), "Buy Now", "Button Text Label")
    ok_u3 = assert_eq(badge.ui_type, UI_BADGE, "Badge Node Type")
    if ok_u1 == 1 and ok_u2 == 1 and ok_u3 == 1
        passed_tests = passed_tests + 1

    // ── Section 3: Integer Flexbox Layout Solver ──────────────────────────────
    say "\n▶ Section 3: Integer Flexbox Constraint Solver..."
    total_tests = total_tests + 1
    row_children = list()
    push(row_children, btn)
    push(row_children, badge)
    flex_row = ui_row("header_flex", 10, row_children)
    ui_layout_solve(flex_row, 10, 20, 800, 600)
    ok_l1 = assert_eq(flex_row.ui_x, 10, "Row Origin X")
    ok_l2 = assert_eq(flex_row.ui_y, 20, "Row Origin Y")
    ok_l3 = assert_gt(flex_row.ui_w, 100, "Row Computed Width")
    ok_l4 = assert_eq(flex_row.ui_h, 36, "Row Computed Height")
    if ok_l1 == 1 and ok_l2 == 1 and ok_l3 == 1 and ok_l4 == 1
        passed_tests = passed_tests + 1

    // ── Section 4: Native Linear Framebuffer Rasterizer ───────────────────────
    say "\n▶ Section 4: Native 32-bit Framebuffer Rasterizer..."
    total_tests = total_tests + 1
    fb = ui_framebuffer_new(800, 600)
    ui_render_framebuffer(flex_row, fb)
    ok_f1 = assert_gt(fb.fb_draw_calls, 0, "Framebuffer Draw Calls")
    ok_f2 = assert_gt(fb.fb_bytes_written, 1000, "Framebuffer Memory Bytes Written")
    if ok_f1 == 1 and ok_f2 == 1
        passed_tests = passed_tests + 1

    // ── Section 5: WebGPU Draw Command Stream ─────────────────────────────────
    say "\n▶ Section 5: WebGPU DOM-Bypass Command Stream..."
    total_tests = total_tests + 1
    gpu_cmds = ui_compile_draw_commands(flex_row)
    ok_g1 = assert_gt(len(gpu_cmds), 2, "WebGPU Commands Count")
    if ok_g1 == 1
        passed_tests = passed_tests + 1

    // ── Section 6: Silicon SSR Zero-JS HTML5/CSS Generator ────────────────────
    say "\n▶ Section 6: Silicon SSR Zero-JS HTML5/CSS..."
    total_tests = total_tests + 1
    ssr_markup = ui_render_silicon_ssr(flex_row)
    ok_m1 = assert_gt(len(ssr_markup), 50, "SSR HTML Length")
    ok_m2 = assert_eq(sf_str_has(ssr_markup, "Buy Now"), 1, "SSR Contains Button Text")
    if ok_m1 == 1 and ok_m2 == 1
        passed_tests = passed_tests + 1

    // ── Section 7: Radix Parameterized URL Router ─────────────────────────────
    say "\n▶ Section 7: Radix Parameterized URL Router..."
    total_tests = total_tests + 1
    router = router_new()
    router_add(router, "GET", "/api/items", 0, 10, 0)
    router_add(router, "GET", "/api/items/", 1, 11, 0)

    req_static = http_request_new("GET", "/api/items", "", "", "127.0.0.1")
    match_static = router_dispatch(router, req_static)
    ok_r1 = assert_eq(match_static.rt_handler_id, 10, "Static Route Match")

    req_param = http_request_new("GET", "/api/items/77", "", "", "127.0.0.1")
    match_param = router_dispatch(router, req_param)
    ok_r2 = assert_eq(match_param.rt_handler_id, 11, "Parameterized Route Match")
    ok_r3 = assert_eq(req_param.route_param_id, 77, "Extracted URL Parameter ID")
    if ok_r1 == 1 and ok_r2 == 1 and ok_r3 == 1
        passed_tests = passed_tests + 1

    // ── Section 8: Security Guard: Rate Limiter & Bearer JWT ──────────────────
    say "\n▶ Section 8: Security Middleware Guard..."
    total_tests = total_tests + 1
    limiter = rate_limiter_new(2)
    ok_sec1 = assert_eq(rate_limiter_acquire(limiter), 1, "Token 1 Allowed")
    ok_sec2 = assert_eq(rate_limiter_acquire(limiter), 1, "Token 2 Allowed")
    ok_sec3 = assert_eq(rate_limiter_acquire(limiter), 0, "Token 3 Blocked (429)")

    secret_key = "sovereign_key"
    token_valid = "Bearer head." + secret_key + ".sig"
    token_invalid = "Bearer head.forged_key.sig"
    ok_sec4 = assert_eq(jwt_auth_guard(token_valid, secret_key), 1001, "JWT Valid Signature")
    ok_sec5 = assert_eq(jwt_auth_guard(token_invalid, secret_key), 0, "JWT Rejection")
    if ok_sec1 == 1 and ok_sec2 == 1 and ok_sec3 == 1 and ok_sec4 == 1 and ok_sec5 == 1
        passed_tests = passed_tests + 1

    // ── Section 9: Embedded LipiKV In-Memory & WAL ORM ────────────────────────
    say "\n▶ Section 9: Embedded LipiKV ORM & WAL Durability..."
    total_tests = total_tests + 1
    tbl = orm_table_new("inventory")
    orm_insert(tbl, "Server Blade", 3500, "Compute")
    orm_insert(tbl, "NVMe Storage Pod", 1200, "Storage")
    orm_insert(tbl, "100GbE Switch", 2800, "Networking")

    ok_o1 = assert_eq(orm_count(tbl), 3, "ORM Active Table Count")
    item2 = orm_find_by_id(tbl, 2)
    ok_o2 = assert_eq(item2.rec_val1, "NVMe Storage Pod", "ORM Lookup by ID")

    orm_update(tbl, 2, 2, 1150)
    item2_up = orm_find_by_id(tbl, 2)
    ok_o3 = assert_eq(item2_up.rec_val2, 1150, "ORM Update Price")

    orm_delete(tbl, 1)
    ok_o4 = assert_eq(orm_count(tbl), 2, "ORM Count After Soft Delete")
    ok_o5 = assert_eq(tbl.tbl_wal_count, 5, "WAL Mutation Audit Log Count")
    if ok_o1 == 1 and ok_o2 == 1 and ok_o3 == 1 and ok_o4 == 1 and ok_o5 == 1
        passed_tests = passed_tests + 1

    // ── Section 10: End-to-End Commerce Integration ───────────────────────────
    say "\n▶ Section 10: End-to-End Sovereign Commerce Flow..."
    total_tests = total_tests + 1
    orders_tbl = orm_table_new("orders")
    order1 = orm_insert(orders_tbl, "Order-Customer-1", 4650, "PAID")
    ok_e1 = assert_eq(order1.rec_id, 1, "Order Generated ID")
    ok_e2 = assert_eq(order1.rec_val2, 4650, "Order Total Value")
    ok_e3 = assert_eq(orders_tbl.tbl_wal_count, 1, "Order WAL Written")
    if ok_e1 == 1 and ok_e2 == 1 and ok_e3 == 1
        passed_tests = passed_tests + 1

    say "\n================================================================="
    say "🎉 TEST RESULTS: " + passed_tests + "/" + total_tests + " SECTIONS PASSED"
    say "================================================================="

    if passed_tests == total_tests
        say "👑 100% PASS: SOVEREIGN FULL-STACK SUITE FULLY OPERATIONAL!"
        return 0
    else
        say "❌ SOME SECTIONS FAILED!"
        return 1

main()
