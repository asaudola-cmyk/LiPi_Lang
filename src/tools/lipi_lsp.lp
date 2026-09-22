// ==============================================================================
// 🧠 LIPI SOVEREIGN LANGUAGE SERVER PROTOCOL CLI (src/tools/lipi_lsp.lp)
// ⚡ 100% Pure LiPi First 1.0.0 | LSP 3.17 Compliant | 0% Node.js / 0% Python
// ==============================================================================

include "src/toolkit/lsp/lsp_server.lp"

fn main
    srv = lsp_server_new()

    // Process JSON-RPC messages from STDIN in event loop until client sends exit/shutdown
    running = 1
    while running == 1
        msg_str = lsp_transport_read_frame()
        if len(msg_str) == 0
            // Stream EOF or termination
            break

        reply = lsp_handle_request(srv, msg_str)
        if len(reply) > 0
            lsp_transport_send_frame(reply)

        if srv.srv_is_shutdown == 1
            running = 0

    return 0

main()
