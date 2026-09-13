// ==============================================================================
// 🧪 LIPI SOVEREIGN FRAMEWORK V2 COMPREHENSIVE TEST SUITE
// Test Suite: tests/test_sovereign_framework_v2.lp
// Modules: schema_validator, job_queue, edge_cache, llm_stream, app_router
// Version: 1.0.0 (Fixed)
// 100% Pure LiPi Implementation — Zero External / C / Node.js Dependencies
// ==============================================================================
//
// TEST COVERAGE:
// Section 1: Schema Validator: Integer Range & Required Field Constraints
// Section 2: Schema Validator: String Length & Deterministic Email Format
// Section 3: Background Job Queue: Enqueueing, Timestamp Polling & Commit
// Section 4: Background Job Queue: Exponential Backoff & Dead-Letter Queue
// Section 5: Background Job Queue: Declarative Periodic Cron Scheduling
// Section 6: Edge Cache: In-Memory Storage & Sub-Millisecond Fresh Hit
// Section 7: Edge Cache: Stale-While-Revalidate & Tag-Based Invalidation
// Section 8: LLM Token Streaming: Channel Opening & Token Push Sequencer
// Section 9: LLM Token Streaming: Stream Finalization & Buffer Audit
// Section 10: Nested App Router: Persistent Layout Shell & Error Boundary
// ==============================================================================

include "universe/web/schema_validator.lp"
include "universe/web/job_queue.lp"
include "universe/web/edge_cache.lp"
include "universe/web/llm_stream.lp"
include "universe/web/app_router.lp"

// ── Test Assertion Utilities ──────────────────────────────────────────────────

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

fn str_find s sub
    slen = len(s)
    plen = len(sub)
    if plen > slen return -1
    i = 0
    while i <= (slen - plen)
        match = 1
        j = 0
        while j < plen
            if char_at(s, i + j) != char_at(sub, j)
                match = 0
                j = plen
            j = j + 1
        if match == 1 return i
        i = i + 1
    return -1

fn str_has s sub
    if str_find(s, sub) >= 0 return 1
    return 0

// ── Main Test Runner ──────────────────────────────────────────────────────────

fn main
    say "================================================================="
    say "👑 LIPI SOVEREIGN FRAMEWORK V2 (VERSION: 1.0.0) TEST SUITE 👑"
    say "================================================================="

    total_tests = 0
    passed_tests = 0

    // ─────────────────────────────────────────────────────────────────────────
    // PILLAR 1: ZERO-REFLECTION SCHEMA & RPC VALIDATOR
    // ─────────────────────────────────────────────────────────────────────────

    // ── Section 1: Schema Validator: Integer Range & Required Fields ─────────
    say "\n▶ Section 1: Schema Validator: Integer Range & Required..."
    total_tests = total_tests + 1
    val = schema_validator_new("checkout_form")
    schema_validator_add_rule(val, "quantity", RULE_TYPE_INT, 1, 100, 1)

    // Valid integer inside bounds [1, 100]
    r1 = schema_validate_int(val, "quantity", 5, 1)
    ok_v1 = assert_eq(r1.sr_is_valid, 1, "Integer (5) Inside Bounds [1, 100]")

    // Out of bounds: 150 > 100
    r2 = schema_validate_int(val, "quantity", 150, 1)
    ok_v2 = assert_eq(r2.sr_is_valid, 0, "Integer (150) Out of Range Rejected")
    ok_v3 = assert_eq(r2.sr_error_code, VAL_ERR_RANGE, "Error Code Matches VAL_ERR_RANGE")

    // Missing required field
    r3 = schema_validate_int(val, "quantity", 0, 0)
    ok_v4 = assert_eq(r3.sr_is_valid, 0, "Missing Required Field Rejected")
    ok_v5 = assert_eq(r3.sr_error_code, VAL_ERR_MISSING, "Error Code Matches VAL_ERR_MISSING")

    if ok_v1 == 1 and ok_v2 == 1 and ok_v3 == 1 and ok_v4 == 1 and ok_v5 == 1
        passed_tests = passed_tests + 1

    // ── Section 2: Schema Validator: String Length & Email Format ─────────────
    say "\n▶ Section 2: Schema Validator: String Length & Email..."
    total_tests = total_tests + 1
    schema_validator_add_rule(val, "username", RULE_TYPE_STR, 3, 20, 1)
    schema_validator_add_rule(val, "email", RULE_TYPE_EMAIL, 5, 50, 1)

    // Valid string
    r_str1 = schema_validate_str(val, "username", "alice_dev")
    ok_s1 = assert_eq(r_str1.sr_is_valid, 1, "Username 'alice_dev' Length Valid")

    // Too short string
    r_str2 = schema_validate_str(val, "username", "al")
    ok_s2 = assert_eq(r_str2.sr_is_valid, 0, "Username 'al' (Length 2 < 3) Rejected")
    ok_s3 = assert_eq(r_str2.sr_error_code, VAL_ERR_TOO_SHORT, "Error Code Matches VAL_ERR_TOO_SHORT")

    // Valid Email
    r_em1 = schema_validate_email(val, "email", "alice@sovereign.lipi")
    ok_s4 = assert_eq(r_em1.sr_is_valid, 1, "Valid Email 'alice@sovereign.lipi' Accepted")

    // Malformed Email (no dot)
    r_em2 = schema_validate_email(val, "email", "alice@sovereign")
    ok_s5 = assert_eq(r_em2.sr_is_valid, 0, "Malformed Email 'alice@sovereign' Rejected")

    if ok_s1 == 1 and ok_s2 == 1 and ok_s3 == 1 and ok_s4 == 1 and ok_s5 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // PILLAR 2: DISTRIBUTED BACKGROUND JOB QUEUE & CRON WORKER
    // ─────────────────────────────────────────────────────────────────────────

    // ── Section 3: Background Job Queue: Enqueueing & Commit ──────────────────
    say "\n▶ Section 3: Background Job Queue: Enqueue & Execution..."
    total_tests = total_tests + 1
    jq = job_queue_engine_new()
    job_queue_enqueue(jq, 1001, "send_welcome_email", "user_id=45", 1000, 3)

    // Poll at time 950 (Too early)
    job_early = job_queue_poll_ready(jq, 950)
    ok_j1 = assert_eq(job_early, 0, "Job Not Ready Before Scheduled Time (950 < 1000)")

    // Poll at time 1005 (Ready)
    job_ready = job_queue_poll_ready(jq, 1005)
    ok_j2 = assert_eq(job_ready.bj_id, 1001, "Polled Ready Job ID 1001")
    ok_j3 = assert_eq(job_ready.bj_status, JOB_STATUS_RUNNING, "Job Status Transitioned to RUNNING")

    // Complete job
    job_queue_complete(jq, 1001)
    ok_j4 = assert_eq(job_ready.bj_status, JOB_STATUS_COMPLETED, "Job Status Committed to COMPLETED")
    ok_j5 = assert_eq(jq.jqe_total_processed, 1, "Engine Processed Counter Incremented")

    if ok_j1 == 1 and ok_j2 == 1 and ok_j3 == 1 and ok_j4 == 1 and ok_j5 == 1
        passed_tests = passed_tests + 1

    // ── Section 4: Background Job Queue: Retry & Dead-Letter Queue ────────────
    say "\n▶ Section 4: Job Queue: Exponential Backoff & DLQ..."
    total_tests = total_tests + 1
    // Job with max 2 retries
    job_queue_enqueue(jq, 1002, "sync_external_inventory", "supplier_id=9", 1000, 2)
    j2 = job_queue_find_job(jq, 1002)

    // Failure 1: Rescheduled with backoff
    res1 = job_queue_fail_retry(jq, 1002, 1010, 10)
    ok_r1 = assert_eq(res1, JOB_STATUS_PENDING, "Retry 1: Rescheduled to PENDING")
    ok_r2 = assert_eq(j2.bj_run_at, 1020, "Exponential Run-At Backoff (1010 + 10 = 1020)")

    // Failure 2: Exceeded max retries -> DEAD
    res2 = job_queue_fail_retry(jq, 1002, 1025, 10)
    ok_r3 = assert_eq(res2, JOB_STATUS_DEAD, "Retry 2: Moved to Dead-Letter Queue (DLQ)")
    ok_r4 = assert_eq(jq.jqe_dead_letter_count, 1, "Dead-Letter Queue Count Incremented")

    if ok_r1 == 1 and ok_r2 == 1 and ok_r3 == 1 and ok_r4 == 1
        passed_tests = passed_tests + 1

    // ── Section 5: Background Job Queue: Declarative Cron Scheduling ─────────
    say "\n▶ Section 5: Job Queue: Declarative Cron Scheduling..."
    total_tests = total_tests + 1
    // Task recurring every 3600 seconds (1 hour)
    job_queue_register_cron(jq, "hourly_analytics_rollup", 3600)

    // Tick at t = 3600 (First trigger)
    enq1 = job_queue_tick_cron(jq, 3600, 2000)
    ok_cr1 = assert_eq(enq1, 1, "Cron Fired 1 Ready Task at t=3600")

    // Tick at t = 4000 (Not yet elapsed)
    enq2 = job_queue_tick_cron(jq, 4000, 2010)
    ok_cr2 = assert_eq(enq2, 0, "Cron Did Not Fire (Only 400s elapsed < 3600s)")

    if ok_cr1 == 1 and ok_cr2 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // PILLAR 3: INCREMENTAL STATIC REGENERATION (ISR) & EDGE CACHING
    // ─────────────────────────────────────────────────────────────────────────

    // ── Section 6: Edge Cache: In-Memory Storage & Fresh Hits ─────────────────
    say "\n▶ Section 6: Edge Cache: In-Memory Storage & Fresh Hits..."
    total_tests = total_tests + 1
    ec = edge_cache_engine_new()
    page_html = "<html><body><h1>Sovereign Store Products</h1></body></html>"
    
    // Store with TTL 60 seconds at t = 1000
    edge_cache_put(ec, "/products", page_html, "products_group", 1000, 60)

    // Lookup at t = 1010 (10s elapsed < 60s) -> FRESH HIT
    st_fresh = edge_cache_get_status(ec, "/products", 1010)
    ok_ec1 = assert_eq(st_fresh, CACHE_HIT, "Cache Hit Status for Fresh Page")
    content = edge_cache_get_content(ec, "/products")
    ok_ec2 = assert_eq(str_has(content, "Sovereign Store Products"), 1, "Cached Content Recovered")
    ok_ec3 = assert_eq(ec.ece_hits, 1, "Engine Cache Hits Incremented")

    if ok_ec1 == 1 and ok_ec2 == 1 and ok_ec3 == 1
        passed_tests = passed_tests + 1

    // ── Section 7: Edge Cache: Stale-While-Revalidate & Tag Invalidation ──────
    say "\n▶ Section 7: Edge Cache: Stale-While-Revalidate & Tag Invalidation..."
    total_tests = total_tests + 1

    // Lookup at t = 1070 (70s elapsed > 60s) -> STALE HIT
    st_stale = edge_cache_get_status(ec, "/products", 1070)
    ok_es1 = assert_eq(st_stale, CACHE_STALE, "Cache Stale Status (Stale-While-Revalidate Triggered)")
    ok_es2 = assert_eq(ec.ece_stale_hits, 1, "Engine Stale Hits Incremented")

    // On-demand tag invalidation
    edge_cache_put(ec, "/products/1", "Item 1 HTML", "products_group", 1000, 600)
    edge_cache_put(ec, "/pricing", "Pricing HTML", "pricing_group", 1000, 600)

    // Invalidate all "products_group"
    purged = edge_cache_invalidate_tag(ec, "products_group")
    ok_es3 = assert_eq(purged, 2, "Invalidated 2 Pages in 'products_group'")

    // Purged page lookup -> MISS
    st_purged = edge_cache_get_status(ec, "/products", 1070)
    ok_es4 = assert_eq(st_purged, CACHE_MISS, "Purged Page Returns CACHE_MISS")

    // Unrelated tag remains active
    st_pricing = edge_cache_get_status(ec, "/pricing", 1010)
    ok_es5 = assert_eq(st_pricing, CACHE_HIT, "Unrelated 'pricing_group' Remained Intact")

    if ok_es1 == 1 and ok_es2 == 1 and ok_es3 == 1 and ok_es4 == 1 and ok_es5 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // PILLAR 4: AI LLM TOKEN STREAMING ADAPTER
    // ─────────────────────────────────────────────────────────────────────────

    // ── Section 8: LLM Token Streaming: Channel Opening & Token Push ─────────
    say "\n▶ Section 8: LLM Streaming: Channel Opening & Push..."
    total_tests = total_tests + 1
    llm_eng = llm_stream_engine_new()
    ch = llm_stream_open_channel(llm_eng, 5001, 77)

    ok_ls1 = assert_eq(ch.lsc_stream_id, 5001, "Stream Channel ID Initialized")
    ok_ls2 = assert_eq(ch.lsc_is_active, 1, "Channel is Active")

    // Stream 3 consecutive token chunks
    t1 = llm_stream_push_token(llm_eng, 5001, "Sovereign ")
    t2 = llm_stream_push_token(llm_eng, 5001, "Full-Stack ")
    t3 = llm_stream_push_token(llm_eng, 5001, "AI")

    ok_ls3 = assert_eq(t1, 1, "Token 1 Sequence Number")
    ok_ls4 = assert_eq(t3, 3, "Token 3 Sequence Number")
    ok_ls5 = assert_eq(llm_eng.lse_total_tokens, 3, "Engine Total Tokens Counter")

    if ok_ls1 == 1 and ok_ls2 == 1 and ok_ls3 == 1 and ok_ls4 == 1 and ok_ls5 == 1
        passed_tests = passed_tests + 1

    // ── Section 9: LLM Token Streaming: Finalization & Buffer Audit ───────────
    say "\n▶ Section 9: LLM Streaming: Finalization & Buffer Audit..."
    total_tests = total_tests + 1
    full_text = llm_stream_get_full_text(llm_eng, 5001)
    ok_lf1 = assert_eq(full_text, "Sovereign Full-Stack AI", "Accumulated Server Buffer Matches Full Stream")

    // Close channel
    ok_close = llm_stream_close_channel(llm_eng, 5001)
    ok_lf2 = assert_eq(ok_close, 1, "Stream Closed Gracefully")
    ok_lf3 = assert_eq(ch.lsc_is_active, 0, "Channel Marked Inactive")

    // Post-close token push rejected
    rej_t4 = llm_stream_push_token(llm_eng, 5001, " Extra")
    ok_lf4 = assert_eq(rej_t4, 0, "Push to Inactive Stream Safely Rejected")

    if ok_lf1 == 1 and ok_lf2 == 1 and ok_lf3 == 1 and ok_lf4 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // PILLAR 5: NESTED APP ROUTER & LAYOUT ENGINE
    // ─────────────────────────────────────────────────────────────────────────

    // ── Section 10: Nested App Router: Shell Synthesis & Error Boundary ───────
    say "\n▶ Section 10: Nested App Router: Shell Synthesis & Error Boundary..."
    total_tests = total_tests + 1
    ar = app_router_engine_new()
    
    // Define route with persistent layout shell (nav header + sidebar + footer)
    layout_nav = "<header><nav>Home | Products | Admin</nav></header><main>"
    layout_footer = "</main><footer>Copyright 2026 LiPi Sovereign</footer>"
    page_dashboard = "<section><h1>User Dashboard Analytics</h1></section>"
    error_fallback = "<section class=\"error\"><h1>500: Server Error Boundary</h1></section>"

    seg = route_segment_new("/dashboard", layout_nav, layout_footer, page_dashboard, error_fallback)
    app_router_register(ar, seg)

    // Normal View Synthesis (0.02ms)
    view_normal = app_router_render_view(ar, "/dashboard", 0)
    ok_ar1 = assert_eq(str_has(view_normal, "Home | Products"), 1, "View Contains Persistent Nav Header")
    ok_ar2 = assert_eq(str_has(view_normal, "User Dashboard Analytics"), 1, "View Injected Child Page Content")
    ok_ar3 = assert_eq(str_has(view_normal, "Copyright 2026"), 1, "View Contains Persistent Footer")

    // Error Boundary Fallback Synthesis
    view_error = app_router_render_view(ar, "/dashboard", 1)
    ok_ar4 = assert_eq(str_has(view_error, "500: Server Error Boundary"), 1, "Injected Error Boundary Content")
    ok_ar5 = assert_eq(str_has(view_error, "Home | Products"), 1, "Nav Shell Remains Intact During Error")

    if ok_ar1 == 1 and ok_ar2 == 1 and ok_ar3 == 1 and ok_ar4 == 1 and ok_ar5 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // FINAL SUITE VERIFICATION REPORT
    // ─────────────────────────────────────────────────────────────────────────
    say "\n================================================================="
    say "🎉 FRAMEWORK V2 RESULTS: " + passed_tests + "/" + total_tests + " SECTIONS PASSED"
    say "================================================================="

    if passed_tests == total_tests
        say "👑 100% PASS: SOVEREIGN FRAMEWORK V2 FULLY OPERATIONAL!"
        return 0
    else
        say "❌ SOME SECTIONS FAILED!"
        return 1

main()
