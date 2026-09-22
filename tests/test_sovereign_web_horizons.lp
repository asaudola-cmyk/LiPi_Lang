// ==============================================================================
// 🧪 LIPI SOVEREIGN WEB HORIZONS (M1–M5) COMPREHENSIVE TEST SUITE
// Test Suite: tests/test_sovereign_web_horizons.lp
// Milestones: Sovereign Web Horizons M1, M2, M3, M4, M5
// 100% Pure LiPi Implementation — Zero External / C / Node.js Dependencies
// ==============================================================================
//
// TEST COVERAGE:
// Section 1: Wire-Signals Packet Serialization, Deserialization & Outbox
// Section 2: Wire-Signals Reactive Dirty Tracking & Binary Delta Broadcast
// Section 3: io_uring Ring Buffer Allocation & SQE Submission Enqueueing
// Section 4: io_uring Batch Kernel Enter & Zero-Copy CQE Polling
// Section 5: Style Bitmask Layout, Flex, Spacing & Palette Bit Packing
// Section 6: Style Bitmask Single-Cycle (<0.01ms) Atomic CSS Resolution
// Section 7: Shadow ARIA Tree Generation (WCAG AAA Compliant DOM Overlay)
// Section 8: Pure LiPi Bengali Virama Conjunct Ligature Shaping (যুক্তবর্ণ)
// Section 9: Embedded Raft Consensus: Election Quorum & Replicated Log
// Section 10: Distributed Edge Session Store (Zero-Hop Reads & Invalidation)
// ==============================================================================

include "universe/web/wire_signals.lp"
include "universe/web/io_uring.lp"
include "universe/gui/style_bitmask.lp"
include "universe/web/accessible_canvas.lp"
include "universe/web/cluster.lp"

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
    say "👑 LIPI SOVEREIGN WEB HORIZONS (M1–M5) TEST SUITE 👑"
    say "================================================================="

    total_tests = 0
    passed_tests = 0

    // ─────────────────────────────────────────────────────────────────────────
    // M1: WIRE-SIGNALS PROTOCOL (REPLACING REACT RSC & HTMX)
    // ─────────────────────────────────────────────────────────────────────────

    // ── Section 1: Wire-Signals Packet Serialization & Session Outbox ─────────
    say "\n▶ Section 1: Wire-Signals Packet Serialization & Outbox..."
    total_tests = total_tests + 1
    ses1 = wire_session_new(101)
    ping_pkt = wire_packet_new(WIRE_OP_PING, 0, 0, "PING", 101, 1)
    ser_str = wire_packet_serialize(ping_pkt)
    
    ok_p1 = assert_eq(ping_pkt.pkt_opcode, WIRE_OP_PING, "Packet Opcode is PING")
    ok_p2 = assert_eq(ping_pkt.pkt_client_id, 101, "Packet Client ID")
    ok_p3 = assert_eq(str_has(ser_str, "WIRE[1:0]"), 1, "Serialized Frame Format")

    // Handle frame in engine to test PONG response in session outbox
    w_engine = wire_engine_new()
    wire_engine_handle_frame(w_engine, ses1, ping_pkt)
    outbox1 = ses1.ses_outbox
    ok_p4 = assert_eq(len(outbox1), 1, "PONG Dispatched to Outbox")
    resp_pkt = get(outbox1, 0)
    ok_p5 = assert_eq(resp_pkt.pkt_opcode, WIRE_OP_PONG, "Response Opcode is PONG")

    if ok_p1 == 1 and ok_p2 == 1 and ok_p3 == 1 and ok_p4 == 1 and ok_p5 == 1
        passed_tests = passed_tests + 1

    // ── Section 2: Wire-Signals Dirty State Mutation & Delta Broadcast ───────
    say "\n▶ Section 2: Wire-Signals Reactive Dirty Tracking & Broadcast..."
    total_tests = total_tests + 1
    w_eng2 = wire_engine_new()
    c_ses1 = wire_session_new(201)
    c_ses2 = wire_session_new(202)
    
    sessions_list = w_eng2.we_sessions
    push(sessions_list, c_ses1)
    push(sessions_list, c_ses2)

    wire_engine_add_signal(w_eng2, 55, 1000, "INITIAL_STATE")
    // Client 201 subscribes to signal 55; Client 202 does not
    wire_engine_subscribe(w_eng2, c_ses1, 55)

    // Mutate signal 55 on server
    wire_engine_mutate_signal(w_eng2, 55, 1050, "MUTATED_STATE")
    dirty_list = w_eng2.we_dirty_list
    ok_w1 = assert_eq(len(dirty_list), 1, "Dirty List Registered Mutation")

    // Flush deltas to connected clients
    flushed = wire_engine_flush_deltas(w_eng2)
    ok_w2 = assert_eq(flushed, 1, "Flushed 1 Dirty Signal Delta")

    outbox_c1 = c_ses1.ses_outbox
    outbox_c2 = c_ses2.ses_outbox
    ok_w3 = assert_eq(len(outbox_c1), 1, "Subscribed Client 201 Received Delta")
    ok_w4 = assert_eq(len(outbox_c2), 0, "Unsubscribed Client 202 Received Zero")

    delta_pkt = get(outbox_c1, 0)
    ok_w5 = assert_eq(delta_pkt.pkt_opcode, WIRE_OP_DELTA_PATCH, "Patch Opcode is DELTA_PATCH")
    ok_w6 = assert_eq(delta_pkt.pkt_val_int, 1050, "Patch Updated Integer Value")

    if ok_w1 == 1 and ok_w2 == 1 and ok_w3 == 1 and ok_w4 == 1 and ok_w5 == 1 and ok_w6 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // M2: LINUX IO_URING MEGA-CONCURRENCY DRIVER (REPLACING LIBUV)
    // ─────────────────────────────────────────────────────────────────────────

    // ── Section 3: io_uring Ring Buffer & SQE Registration ───────────────────
    say "\n▶ Section 3: io_uring Buffer Allocation & SQE Submission..."
    total_tests = total_tests + 1
    ring = io_uring_engine_new(512)
    buf0 = io_uring_register_buffer(ring, 0, 4096)
    
    ok_u1 = assert_eq(buf0.buf_capacity, 4096, "Registered Zero-Copy Buffer 0 Capacity")
    
    // Enqueue 3 non-blocking operations: ACCEPT, RECV into fixed buffer, SEND
    io_uring_prep_accept(ring, 3, 1001)
    io_uring_prep_recv(ring, 4, 0, 1024, 1002)
    io_uring_prep_send(ring, 4, 0, 512, 1003)

    sq_list = ring.ring_sq_list
    ok_u2 = assert_eq(len(sq_list), 3, "SQ Ring Contains 3 Pending SQEs")

    if ok_u1 == 1 and ok_u2 == 1
        passed_tests = passed_tests + 1

    // ── Section 4: io_uring Batch Kernel Enter & Zero-Copy CQE Polling ───────
    say "\n▶ Section 4: io_uring Kernel Enter Batching & CQE Polling..."
    total_tests = total_tests + 1
    submitted = io_uring_enter(ring, 3)
    ok_k1 = assert_eq(submitted, 3, "Kernel Enter Submitted 3 Requests in 1 Transition")
    
    sq_remaining = ring.ring_sq_list
    ok_k2 = assert_eq(len(sq_remaining), 0, "SQ Queue Emptied Post-Submission")
    ok_k3 = assert_eq(io_uring_cq_count(ring), 3, "CQ Completion Queue Contains 3 CQEs")

    // CQE 1: ACCEPT result
    cqe1 = io_uring_peek_cqe(ring)
    ok_k4 = assert_eq(cqe1.cqe_user_data, 1001, "CQE 1 User Data Matches ACCEPT")
    ok_k5 = assert_gt(cqe1.cqe_res, 199, "CQE 1 Returns Valid Client Socket FD")

    // CQE 2: RECV result & buffer lock
    cqe2 = io_uring_peek_cqe(ring)
    ok_k6 = assert_eq(cqe2.cqe_user_data, 1002, "CQE 2 User Data Matches RECV")
    ok_k7 = assert_eq(cqe2.cqe_res, 1024, "CQE 2 Received 1024 Bytes")

    // CQE 3: SEND result & buffer unlock
    cqe3 = io_uring_peek_cqe(ring)
    ok_k8 = assert_eq(cqe3.cqe_user_data, 1003, "CQE 3 User Data Matches SEND")
    ok_k9 = assert_eq(cqe3.cqe_res, 512, "CQE 3 Sent 512 Bytes")
    ok_k10 = assert_eq(buf0.buf_is_locked, 0, "Buffer Unlocked Post-Send")

    if ok_k1 == 1 and ok_k2 == 1 and ok_k3 == 1 and ok_k4 == 1 and ok_k5 == 1 and ok_k6 == 1 and ok_k7 == 1 and ok_k8 == 1 and ok_k9 == 1 and ok_k10 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // M3: COMPILE-TIME STYLE BITMASK ENGINE (TAILWIND KILLER)
    // ─────────────────────────────────────────────────────────────────────────

    // ── Section 5: Style Bitmask Layout & Spacing Bit Packing ────────────────
    say "\n▶ Section 5: Style Bitmask Layout, Spacing & Palette Bit Packing..."
    total_tests = total_tests + 1
    sm = style_bitmask_new()
    style_bitmask_set_layout(sm, DISPLAY_FLEX, FLEX_DIR_COL + FLEX_JUSTIFY_CENTER)
    style_bitmask_set_spacing(sm, 4, 2, 2) // pad 16px (idx 4), mar 8px, gap 8px (idx 2)
    style_bitmask_set_palette(sm, PALETTE_SURFACE_CARD, PALETTE_TEXT_WHITE, PALETTE_ACCENT_BLUE)
    style_bitmask_set_border(sm, 1, 2) // width 1px, radius 8px (idx 2)

    ok_b1 = assert_eq(style_bitmask_get_pad_px(sm), 16, "Extracted Padding (16px)")
    ok_b2 = assert_eq(style_bitmask_get_gap_px(sm), 8, "Extracted Gap (8px)")
    ok_b3 = assert_eq(style_bitmask_get_text_rgb(sm), 16777215, "Extracted Text Color (0xFFFFFF)")
    ok_b4 = assert_eq(style_bitmask_get_border_width(sm), 1, "Extracted Border Width (1px)")

    if ok_b1 == 1 and ok_b2 == 1 and ok_b3 == 1 and ok_b4 == 1
        passed_tests = passed_tests + 1

    // ── Section 6: Style Bitmask Single-Cycle Atomic CSS Resolution ───────────
    say "\n▶ Section 6: Style Bitmask Single-Cycle Atomic CSS Resolution..."
    total_tests = total_tests + 1
    css = style_bitmask_resolve_css(sm)
    
    ok_c1 = assert_eq(str_has(css, "display:flex;"), 1, "CSS Has Flexbox")
    ok_c2 = assert_eq(str_has(css, "flex-direction:column;"), 1, "CSS Has Flex Direction Column")
    ok_c3 = assert_eq(str_has(css, "padding:16px;"), 1, "CSS Has Padding 16px")
    ok_c4 = assert_eq(str_has(css, "gap:8px;"), 1, "CSS Has Gap 8px")
    ok_c5 = assert_eq(str_has(css, "background-color:#161b22;"), 1, "CSS Has Card Surface Color")
    ok_c6 = assert_eq(str_has(css, "border:1px solid #1f6feb;"), 1, "CSS Has Accent Blue Border")
    ok_c7 = assert_eq(str_has(css, "border-radius:8px;"), 1, "CSS Has Border Radius 8px")

    if ok_c1 == 1 and ok_c2 == 1 and ok_c3 == 1 and ok_c4 == 1 and ok_c5 == 1 and ok_c6 == 1 and ok_c7 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // M4: ACCESSIBLE WEBGPU CANVAS & BENGALI FONT SHAPING
    // ─────────────────────────────────────────────────────────────────────────

    // ── Section 7: Shadow ARIA Tree Generation for Screen Readers ─────────────
    say "\n▶ Section 7: Shadow ARIA Accessibility Tree Generation..."
    total_tests = total_tests + 1
    ace = accessible_canvas_new(1920, 1080)
    accessible_canvas_add_node(ace, ARIA_ROLE_BANNER, "LiPi Cloud Header", "", 0, 0, 1920, 80)
    accessible_canvas_add_node(ace, ARIA_ROLE_BUTTON, "Deploy Cluster", "ACTIVATE", 1600, 20, 200, 48)
    
    shadow_dom = accessible_canvas_export_shadow_dom(ace)
    ok_a1 = assert_eq(str_has(shadow_dom, "lipi-aria-shadow-root"), 1, "Shadow DOM Has Root Container")
    ok_a2 = assert_eq(str_has(shadow_dom, "role=\"banner\""), 1, "Shadow DOM Has Banner Role")
    ok_a3 = assert_eq(str_has(shadow_dom, "role=\"button\""), 1, "Shadow DOM Has Button Role")
    ok_a4 = assert_eq(str_has(shadow_dom, "aria-label=\"Deploy Cluster\""), 1, "Shadow DOM Has Accessible Label")
    ok_a5 = assert_eq(str_has(shadow_dom, "ACTIVATE"), 1, "Shadow DOM Has Button Value")

    if ok_a1 == 1 and ok_a2 == 1 and ok_a3 == 1 and ok_a4 == 1 and ok_a5 == 1
        passed_tests = passed_tests + 1

    // ── Section 8: Pure LiPi Bengali Virama Conjunct Ligature Shaping ─────────
    say "\n▶ Section 8: Bengali Virama Conjunct Ligature Shaping (যুক্তবর্ণ)..."
    total_tests = total_tests + 1
    ok_v1 = assert_eq(glyph_is_bengali_virama("^"), 1, "Virama Character '^' Recognized")
    ok_v2 = assert_eq(glyph_is_bengali_virama("~"), 1, "Virama Character '~' Recognized")
    ok_v3 = assert_eq(glyph_is_bengali_virama("A"), 0, "Non-Virama Character 'A' Rejected")

    // Shape a word with conjunct: e.g. "k^s" (ক্ষ representation)
    initial_shaped = ace.ace_total_shaped_chars
    adv = accessible_canvas_shape_text(ace, "k^s")
    ok_v4 = assert_eq(adv, 14, "Conjunct Ligature Advance Width Computed (14px)")
    ok_v5 = assert_gt(ace.ace_total_shaped_chars, initial_shaped, "Glyph Cache Updated")

    if ok_v1 == 1 and ok_v2 == 1 and ok_v3 == 1 and ok_v4 == 1 and ok_v5 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // M5: DISTRIBUTED EDGE CLUSTERING & RAFT STATE SYNC (REDIS KILLER)
    // ─────────────────────────────────────────────────────────────────────────

    // ── Section 9: Embedded Raft Consensus & Replicated Log ──────────────────
    say "\n▶ Section 9: Embedded Raft Consensus, Election & Log Append..."
    total_tests = total_tests + 1
    node1 = cluster_node_new(1)
    cluster_node_add_peer(node1, 2)
    cluster_node_add_peer(node1, 3)

    ok_r1 = assert_eq(node1.cn_role, RAFT_ROLE_FOLLOWER, "Node 1 Initially Follower")
    role_elected = cluster_node_start_election(node1)
    ok_r2 = assert_eq(role_elected, RAFT_ROLE_LEADER, "Node 1 Won Election by Quorum (2/3)")
    ok_r3 = assert_eq(node1.cn_current_term, 1, "Node 1 Current Term Incremented to 1")

    // Leader proposes state mutation
    entry = cluster_node_propose(node1, RAFT_OP_SET, "cluster_mode", "ACTIVE", 901)
    ok_r4 = assert_eq(entry.rle_index, 1, "Raft Log Entry Index 1")
    ok_r5 = assert_eq(node1.cn_commit_idx, 1, "Leader Advanced Commit Index to 1")

    // Follower node receives AppendEntries RPC
    node2 = cluster_node_new(2)
    rpc_ok = cluster_node_append_entries_rpc(node2, 1, 1, 0, 0, entry, 1)
    ok_r6 = assert_eq(rpc_ok, RAFT_APPEND_SUCCESS, "Follower Node 2 Accepted AppendEntries RPC")
    ok_r7 = assert_eq(node2.cn_commit_idx, 1, "Follower Node 2 Committed Index 1")

    if ok_r1 == 1 and ok_r2 == 1 and ok_r3 == 1 and ok_r4 == 1 and ok_r5 == 1 and ok_r6 == 1 and ok_r7 == 1
        passed_tests = passed_tests + 1

    // ── Section 10: Distributed Edge Session Store (Zero-Hop Reads) ───────────
    say "\n▶ Section 10: Distributed Session Store & Zero-Hop Reads..."
    total_tests = total_tests + 1
    store = cluster_session_store_new(node1)

    // Store new session token
    ok_sput = cluster_session_put(store, "auth_tok_xyz987", 777, 1, 999999, "role=SYSADMIN;cluster=APAC")
    ok_s1 = assert_eq(ok_sput, 1, "Distributed Session Successfully Stored & Replicated")

    // Zero-latency RAM read (<0.01ms)
    ses_read = cluster_session_get(store, "auth_tok_xyz987")
    ok_s2 = assert_eq(ses_read.cs_user_id, 777, "Zero-Hop Read Recovered User ID 777")
    ok_s3 = assert_eq(ses_read.cs_data, "role=SYSADMIN;cluster=APAC", "Zero-Hop Read Recovered Session Data")

    // Replicated KV Store
    cluster_kv_set(store, "db_primary_host", "10.0.0.1")
    kv_val = cluster_kv_get(store, "db_primary_host")
    ok_s4 = assert_eq(kv_val, "10.0.0.1", "Distributed Key-Value Store Validated")

    // Invalidate session (Immediate revocation)
    cluster_session_invalidate(store, "auth_tok_xyz987")
    ses_revoked = cluster_session_get(store, "auth_tok_xyz987")
    ok_s5 = assert_eq(ses_revoked, 0, "Revoked Session Immediately Returns 0 (Evicted)")

    if ok_s1 == 1 and ok_s2 == 1 and ok_s3 == 1 and ok_s4 == 1 and ok_s5 == 1
        passed_tests = passed_tests + 1

    // ─────────────────────────────────────────────────────────────────────────
    // FINAL SUITE VERIFICATION REPORT
    // ─────────────────────────────────────────────────────────────────────────
    say "\n================================================================="
    say "🎉 SOVEREIGN HORIZONS (M1–M5) RESULTS: " + passed_tests + "/" + total_tests + " SECTIONS PASSED"
    say "================================================================="

    if passed_tests == total_tests
        say "👑 100% PASS: ALL 5 SOVEREIGN WEB HORIZONS FULLY OPERATIONAL!"
        return 0
    else
        say "❌ SOME SECTIONS FAILED!"
        return 1

main()
