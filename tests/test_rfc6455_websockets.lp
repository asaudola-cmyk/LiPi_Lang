// ==============================================================================
// 🧪 LIPI REGRESSION TEST: RFC 6455 Real-Time WebSockets Engine
// ⚡ Tests FIPS 180-1 SHA-1, RFC 4648 Base64, Handshake Derivation, and Frame Masking
// ==============================================================================

include "apps/website/ws_engine.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    say "  ✔ [PASS] " + test_name

fn assert_str_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: [" + expected + "]"
        say "     Actual:   [" + actual + "]"
        exit(1)
    say "  ✔ [PASS] " + test_name

say "================================================================="
say "👑 LIPI WEB: RFC 6455 WEBSOCKET ENGINE SPECIFICATION TEST 👑"
say "================================================================="

// ── Section 1: RFC 6455 Handshake Acceptance Key Test Vector ─────────────────
// WHY: RFC 6455 Section 4.2.2 defines the normative test vector:
// Input Nonce Key: "dGhlIHNhbXBsZSBub25jZQ=="
// Expected Accept: "s3pPLMBiTxaQ9kYGzzhZRbK+xOo="
say "▶ Section 1: Testing RFC 6455 Section 4.2.2 Normative Test Vector..."
test_nonce = "dGhlIHNhbXBsZSBub25jZQ=="
accept_val = ws_compute_accept_key(test_nonce)
assert_str_eq(accept_val, "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "RFC 6455 SHA-1 + Base64 Accept Key Generation")

// ── Section 2: Header Extraction ──────────────────────────────────────────────
say "▶ Section 2: Testing Sec-WebSocket-Key Extraction from HTTP Headers..."
raw_http = "GET /ws/telemetry HTTP/1.1\r\nHost: 127.0.0.1:8088\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13\r\n\r\n"
extracted_key = ws_extract_key(raw_http)
assert_str_eq(extracted_key, "dGhlIHNhbXBsZSBub25jZQ==", "Extract Sec-WebSocket-Key from header block")

// ── Section 3: Client Frame Masking / Unmasking ────────────────────────────────
say "▶ Section 3: Testing RFC 6455 Masked Client Frame Decoding..."
// Construct a masked frame with payload "HELLO" (48 45 4c 4c 4f)
// Mask Key: 0x37 0xfa 0x21 0x3d
// Masked payload:
// 'H' (72) ^ 0x37 (55)  = 127
// 'E' (69) ^ 0xfa (250) = 191
// 'L' (76) ^ 0x21 (33)  = 109
// 'L' (76) ^ 0x3d (61)  = 113
// 'O' (79) ^ 0x37 (55)  = 120
frame_buf = malloc(32)
mem_write_byte(frame_buf, 0, 129) // FIN + text opcode
mem_write_byte(frame_buf, 1, 133) // MASK bit (128) + length 5
// 4-byte mask key
mem_write_byte(frame_buf, 2, 55)
mem_write_byte(frame_buf, 3, 250)
mem_write_byte(frame_buf, 4, 33)
mem_write_byte(frame_buf, 5, 61)
// Masked payload
mem_write_byte(frame_buf, 6, 127)
mem_write_byte(frame_buf, 7, 191)
mem_write_byte(frame_buf, 8, 109)
mem_write_byte(frame_buf, 9, 113)
mem_write_byte(frame_buf, 10, 120)

decoded_str = ws_decode_client_frame(frame_buf, 11)
free(frame_buf, 32)

assert_str_eq(decoded_str, "HELLO", "XOR unmasking decoded 'HELLO' correctly from client wire bytes")

say "🎉 ALL RFC 6455 WEBSOCKET REGRESSION TESTS PASSED!"
