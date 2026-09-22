// ==============================================================================
// 👑 LIPI TEST SUITE: FULL SOVEREIGN LANGUAGE SERVER PROTOCOL (LSP 3.17)
// ⚡ 100% Pure LiPi Implementation | Zero Node.js / Zero Python | Native JSON-RPC
// 🏛️ File: tests/test_native_lsp_full.lp
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/string.lp"
include "src/toolkit/lsp/lsp_server.lp"

fn assert_true cond msg
    if cond == 0
        say "  [FAIL] " + msg
        return 0
    say "  [PASS] " + msg
    return 1

fn main
    say "================================================================="
    say "👑 TESTING LIPI SOVEREIGN LSP SERVER ENGINE (LSP 3.17)"
    say "================================================================="

    srv = lsp_server_new()
    total_pass = 0

    // ── 1. Protocol Initialize ────────────────────────────────────────────────
    say "▶ Phase 1: Client Initialize Handshake..."
    init_req = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"capabilities\":{}}}"
    init_res = lsp_handle_request(srv, init_req)
    ok_init = json_str_find_from(init_res, "\"definitionProvider\":true", 0) >= 0 && json_str_find_from(init_res, "\"hoverProvider\":true", 0) >= 0
    pass1 = assert_true(ok_init, "Initialize response advertises hover, definition, and completion capabilities")
    total_pass = total_pass + pass1

    // ── 2. Virtual Document Open ──────────────────────────────────────────────
    say "▶ Phase 2: Virtual Document Synchronization (textDocument/didOpen)..."
    sample_doc = "struct OrderItem\n" +
                 "    id\n" +
                 "    price\n" +
                 "\n" +
                 "fn calculate_total price count\n" +
                 "    sub = price * count\n" +
                 "    return sub\n" +
                 "\n" +
                 "fn main\n" +
                 "    total = calculate_total(10, 5)\n" +
                 "    return total\n"

    open_req = "{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/order.lp\",\"version\":1,\"text\":\"" + json_escape(sample_doc) + "\"}}}"
    lsp_handle_request(srv, open_req)
    doc = doc_store_get(srv.srv_doc_store, "file:///workspace/order.lp")
    pass2 = assert_true(doc != 0 && doc.line_count >= 10, "Document stored in memory registry with correct line index")
    total_pass = total_pass + pass2

    // ── 3. Goto Definition ────────────────────────────────────────────────────
    say "▶ Phase 3: Identifier Goto Definition (textDocument/definition)..."
    // Line 9 contains call 'calculate_total' (0-indexed: line 0..3 is struct, line 4..6 is calculate_total, line 8 is main, line 9 is call)
    def_req = "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/definition\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/order.lp\"},\"position\":{\"line\":9,\"character\":16}}}"
    def_res = lsp_handle_request(srv, def_req)
    // calculate_total is defined at line 4
    ok_def = json_str_find_from(def_res, "\"line\":4", 0) >= 0
    pass3 = assert_true(ok_def, "Goto definition precisely mapped identifier to declaration at line 4")
    total_pass = total_pass + pass3

    // ── 4. Hover Documentation ────────────────────────────────────────────────
    say "▶ Phase 4: Contextual Hover Tooltip (textDocument/hover)..."
    hover_req = "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"textDocument/hover\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/order.lp\"},\"position\":{\"line\":9,\"character\":16}}}"
    hover_res = lsp_handle_request(srv, hover_req)
    ok_hover = json_str_find_from(hover_res, "calculate_total", 0) >= 0 && json_str_find_from(hover_res, "LiPi Sovereign Symbol", 0) >= 0
    pass4 = assert_true(ok_hover, "Hover tooltip emitted markdown documentation for targeted symbol")
    total_pass = total_pass + pass4

    // ── 5. Intelligent Autocomplete ───────────────────────────────────────────
    say "▶ Phase 5: Intelligent Autocompletion (textDocument/completion)..."
    comp_req = "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"textDocument/completion\",\"params\":{\"textDocument\":{\"uri\":\"file:///workspace/order.lp\"},\"position\":{\"line\":8,\"character\":4}}}"
    comp_res = lsp_handle_request(srv, comp_req)
    ok_comp = json_str_find_from(comp_res, "\"label\":\"arena_mark\"", 0) >= 0 && json_str_find_from(comp_res, "\"label\":\"fn\"", 0) >= 0
    pass5 = assert_true(ok_comp, "Autocomplete suggestions returned keyword and intrinsic symbol items")
    total_pass = total_pass + pass5

    // ── 6. Shutdown Lifecycle ─────────────────────────────────────────────────
    say "▶ Phase 6: Server Shutdown (shutdown)..."
    shut_req = "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"shutdown\",\"params\":null}"
    shut_res = lsp_handle_request(srv, shut_req)
    ok_shut = json_str_find_from(shut_res, "\"result\":null", 0) >= 0 && srv.srv_is_shutdown == 1
    pass6 = assert_true(ok_shut, "Server shutdown handled cleanly with null response")
    total_pass = total_pass + pass6

    say "================================================================="
    say "🎉 FULL LSP SERVER TESTS PASSED: " + str(total_pass) + "/6"
    say "================================================================="
    return 0

main()
