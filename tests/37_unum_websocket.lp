// Test 37: WebSocket Protocol — Lipi 2.0 Global Standard

fn ws_opcode byte0 = byte0 % 16
fn ws_is_fin byte0
    if byte0 >= 128
        return 1
    return 0
fn ws_masked byte1
    if byte1 >= 128
        return 1
    return 0
fn ws_payload_len byte1
    if byte1 >= 128
        return byte1 - 128
    return byte1

fn ws_build_frame opcode length
    byte0 = 128 + opcode
    return byte0 * 256 + length

fn ws_xor_mask data key
    return (data + key) % 256

say "=== WebSocket Protocol ==="
frame1 = ws_build_frame(1, 11)
frame2 = ws_build_frame(2, 5)
frame3 = ws_build_frame(8, 0)

say "Text frame:   " + frame1
say "Binary frame: " + frame2
say "Close frame:  " + frame3

// Parse
say "Opcode: " + ws_opcode(129)
say "FIN:    " + ws_is_fin(129)
say "Masked: " + ws_masked(140)
say "Len:    " + ws_payload_len(11)

// Masking
encoded = ws_xor_mask(65, 42)
say "Masked char: " + encoded

say "PASS: Test 37 WebSocket"
