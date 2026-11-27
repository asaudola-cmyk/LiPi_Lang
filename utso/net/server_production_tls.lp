// ==============================================================================
// 👑 LIPI PRODUCTION SERVER + IN-PROCESS TLS 1.3 WIRING (utso/net/server_production_tls.lp)
// ⚡ 100% Pure Lipi | Zero OpenSSL | Zero NGINX | RFC 8446 X25519 + AEAD on Epoll
// ==============================================================================
//
// WHY THIS MODULE:
// Connects `utso/net/server_production.lp` directly to `utso/net/tls13_server.lp`
// in one call (`prod_server_enable_tls13(srv, tls_engine)`) without bloating
// plain-HTTP callers that only import `server_production.lp`.

include "utso/net/server_production.lp"
include "utso/net/tls13_server.lp"

fn prod_server_enable_tls13 srv tls_engine
    // WHY: Attaches real RFC 8446 TLS 1.3 handshake + status-aware AEAD decrypt (closes on
    // AEAD failure & close_notify, supports post-handshake KeyUpdate) + AEAD encrypt.
    return prod_server_attach_tls_driver(srv, tls_engine, tls13_server_handshake_fd, tls13_record_decrypt_prod, tls13_record_encrypt)
end
