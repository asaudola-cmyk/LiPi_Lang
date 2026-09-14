// ==============================================================================
// 👑 LIPI SOVEREIGN WEBSOCKET REAL-TIME ENGINE: RFC 6455
// File: universe/net/ws_engine.lp
// ⚡ 100% Pure Native Lipi First 1.0.0 | Zero Libc | Pure Silicon Machine Code
//
// WHY: Enables full-duplex, bi-directional real-time communication between browser
// clients and the Lipi web server for live CPU telemetry and collaborative coding.
// Implements FIPS 180-1 SHA-1, RFC 4648 Base64, and RFC 6455 framing from scratch.
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/memory.lp"
include "universe/core/string.lp"

// ── 32-Bit Bitwise Left Rotation ──────────────────────────────────────────────
// WHY: Fundamental primitive for SHA-1 cryptographic compression
fn rotl32 x n
    x32 = x & 4294967295
    p1 = (x32 << n) & 4294967295
    p2 = (x32 >> (32 - n)) & 4294967295
    return (p1 | p2) & 4294967295

// ── Base64 Character Lookup Table ─────────────────────────────────────────────
fn b64_char val
    if val < 26
        return chr(65 + val)
    if val < 52
        return chr(97 + (val - 26))
    if val < 62
        return chr(48 + (val - 52))
    if val == 62
        return "+"
    if val == 63
        return "/"
    return "="

// ── 20-Byte SHA-1 to 28-Character Base64 Encoder ─────────────────────────────
// WHY: Converts binary 160-bit SHA-1 hash into RFC 6455 Sec-WebSocket-Accept token
fn base64_encode_20bytes b_addr
    res = ""
    i = 0
    while i < 18
        b0 = mem_byte_read(b_addr, i)
        b1 = mem_byte_read(b_addr, i + 1)
        b2 = mem_byte_read(b_addr, i + 2)

        c0 = (b0 >> 2) & 63
        c1 = (((b0 & 3) << 4) | ((b1 >> 4) & 15)) & 63
        c2 = (((b1 & 15) << 2) | ((b2 >> 6) & 3)) & 63
        c3 = b2 & 63

        res = res + b64_char(c0) + b64_char(c1) + b64_char(c2) + b64_char(c3)
        i = i + 3

    // Process remaining 2 bytes (bytes 18 and 19) with '=' padding
    b0 = mem_byte_read(b_addr, 18)
    b1 = mem_byte_read(b_addr, 19)
    c0 = (b0 >> 2) & 63
    c1 = (((b0 & 3) << 4) | ((b1 >> 4) & 15)) & 63
    c2 = ((b1 & 15) << 2) & 63
    res = res + b64_char(c0) + b64_char(c1) + b64_char(c2) + "="
    return res

// ── Pure Lipi SHA-1 Digest Engine (FIPS 180-1) ────────────────────────────────
// WHY: 100% self-contained hashing algorithm with zero libc or OpenSSL dependencies
fn sha1_hash_msg msg out_digest
    mlen = len(msg)
    bit_len = mlen * 8

    // Padded length is a multiple of 64 bytes (512 bits)
    pad_len = ((mlen + 8) / 64 + 1) * 64
    buf = malloc(pad_len)
    mem_zero(buf, pad_len)

    // Copy message bytes
    i = 0
    while i < mlen
        mem_byte_write(buf, i, ord(char_at(msg, i)))
        i = i + 1

    // Append 0x80 (single '1' bit followed by zeros)
    mem_byte_write(buf, mlen, 128)

    // Append 64-bit big-endian length at end of buffer
    mem_byte_write(buf, pad_len - 4, (bit_len >> 24) & 255)
    mem_byte_write(buf, pad_len - 3, (bit_len >> 16) & 255)
    mem_byte_write(buf, pad_len - 2, (bit_len >> 8) & 255)
    mem_byte_write(buf, pad_len - 1, bit_len & 255)

    // Initial SHA-1 state constants (FIPS 180-1)
    h0 = 1732584193
    h1 = 4023233417
    h2 = 2562383102
    h3 = 271733878
    h4 = 3285377520

    w = malloc(320) // 80 words * 4 bytes
    block_offset = 0
    while block_offset < pad_len
        t = 0
        while t < 16
            boff = block_offset + (t * 4)
            b0 = mem_byte_read(buf, boff)
            b1 = mem_byte_read(buf, boff + 1)
            b2 = mem_byte_read(buf, boff + 2)
            b3 = mem_byte_read(buf, boff + 3)
            w_val = ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) & 4294967295
            mem_write(w, t * 4, w_val)
            t = t + 1

        while t < 80
            v1 = mem_read(w, (t - 3) * 4) & 4294967295
            v2 = mem_read(w, (t - 8) * 4) & 4294967295
            v3 = mem_read(w, (t - 14) * 4) & 4294967295
            v4 = mem_read(w, (t - 16) * 4) & 4294967295
            w_val = rotl32(v1 ^ v2 ^ v3 ^ v4, 1)
            mem_write(w, t * 4, w_val)
            t = t + 1

        a = h0
        b = h1
        c = h2
        d = h3
        e = h4

        i = 0
        while i < 80
            if i < 20
                f = (b & c) | ((~b) & d)
                k = 1518500249
            elif i < 40
                f = b ^ c ^ d
                k = 1859775393
            elif i < 60
                f = (b & c) | (b & d) | (c & d)
                k = 2400959708
            else
                f = b ^ c ^ d
                k = 3395469782

            temp = (rotl32(a, 5) + f + e + k + (mem_read(w, i * 4) & 4294967295)) & 4294967295
            e = d
            d = c
            c = rotl32(b, 30)
            b = a
            a = temp
            i = i + 1

        h0 = (h0 + a) & 4294967295
        h1 = (h1 + b) & 4294967295
        h2 = (h2 + c) & 4294967295
        h3 = (h3 + d) & 4294967295
        h4 = (h4 + e) & 4294967295

        block_offset = block_offset + 64

    free(w, 320)
    free(buf, pad_len)

    // Emit 20-byte big-endian digest
    mem_byte_write(out_digest, 0, (h0 >> 24) & 255)
    mem_byte_write(out_digest, 1, (h0 >> 16) & 255)
    mem_byte_write(out_digest, 2, (h0 >> 8) & 255)
    mem_byte_write(out_digest, 3, h0 & 255)

    mem_byte_write(out_digest, 4, (h1 >> 24) & 255)
    mem_byte_write(out_digest, 5, (h1 >> 16) & 255)
    mem_byte_write(out_digest, 6, (h1 >> 8) & 255)
    mem_byte_write(out_digest, 7, h1 & 255)

    mem_byte_write(out_digest, 8, (h2 >> 24) & 255)
    mem_byte_write(out_digest, 9, (h2 >> 16) & 255)
    mem_byte_write(out_digest, 10, (h2 >> 8) & 255)
    mem_byte_write(out_digest, 11, h2 & 255)

    mem_byte_write(out_digest, 12, (h3 >> 24) & 255)
    mem_byte_write(out_digest, 13, (h3 >> 16) & 255)
    mem_byte_write(out_digest, 14, (h3 >> 8) & 255)
    mem_byte_write(out_digest, 15, h3 & 255)

    mem_byte_write(out_digest, 16, (h4 >> 24) & 255)
    mem_byte_write(out_digest, 17, (h4 >> 16) & 255)
    mem_byte_write(out_digest, 18, (h4 >> 8) & 255)
    mem_byte_write(out_digest, 19, h4 & 255)
    return 20

// ── RFC 6455 Sec-WebSocket-Key Parser ─────────────────────────────────────────
// WHY: Locates the client's 24-character Base64 nonce from incoming HTTP headers
fn ws_extract_key req_str
    key_tag = "Sec-WebSocket-Key: "
    klen = len(key_tag)
    rlen = len(req_str)
    i = 0
    limit = rlen - klen
    while i < limit
        if str_sub(req_str, i, i + klen) == key_tag
            p = i + klen
            k_end = p
            while k_end < rlen and char_at(req_str, k_end) != "\r" and char_at(req_str, k_end) != "\n"
                k_end = k_end + 1
            return str_sub(req_str, p, k_end)
        i = i + 1
    return ""

// ── RFC 6455 Accept Key Calculation ───────────────────────────────────────────
// WHY: Concatenates client key with standard RFC GUID and computes SHA-1 + Base64
fn ws_compute_accept_key client_key
    guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    full_str = client_key + guid
    digest_buf = malloc(20)
    sha1_hash_msg(full_str, digest_buf)
    accept_key = base64_encode_20bytes(digest_buf)
    free(digest_buf, 20)
    return accept_key

// ── Perform WebSocket Handshake Upgrade ───────────────────────────────────────
// WHY: Responds with HTTP 101 Switching Protocols to establish persistent socket
fn ws_perform_handshake client_fd req_str
    key = ws_extract_key(req_str)
    if len(key) == 0
        return 0

    accept_key = ws_compute_accept_key(key)
    resp = "HTTP/1.1 101 Switching Protocols\r\n"
    resp = resp + "Upgrade: websocket\r\n"
    resp = resp + "Connection: Upgrade\r\n"
    resp = resp + "Sec-WebSocket-Accept: " + accept_key + "\r\n\r\n"

    syscall(1, client_fd, resp, len(resp), 0, 0, 0)
    return 1

// ── Send Unmasked WebSocket Text Frame (Server -> Client) ─────────────────────
// WHY: Server sends unmasked frames according to RFC 6455 Section 5.1
fn ws_send_text_frame client_fd msg
    mlen = len(msg)
    hdr_buf = malloc(16)
    mem_write_byte(hdr_buf, 0, 129) // 0x81: FIN bit (0x80) | Text opcode (0x01)

    if mlen <= 125
        mem_write_byte(hdr_buf, 1, mlen)
        syscall(1, client_fd, hdr_buf, 2, 0, 0, 0)
    elif mlen <= 65535
        mem_write_byte(hdr_buf, 1, 126)
        mem_write_byte(hdr_buf, 2, (mlen >> 8) & 255)
        mem_write_byte(hdr_buf, 3, mlen & 255)
        syscall(1, client_fd, hdr_buf, 4, 0, 0, 0)
    else
        mem_write_byte(hdr_buf, 1, 127)
        mem_write_byte(hdr_buf, 2, 0)
        mem_write_byte(hdr_buf, 3, 0)
        mem_write_byte(hdr_buf, 4, 0)
        mem_write_byte(hdr_buf, 5, 0)
        mem_write_byte(hdr_buf, 6, (mlen >> 24) & 255)
        mem_write_byte(hdr_buf, 7, (mlen >> 16) & 255)
        mem_write_byte(hdr_buf, 8, (mlen >> 8) & 255)
        mem_write_byte(hdr_buf, 9, mlen & 255)
        syscall(1, client_fd, hdr_buf, 10, 0, 0, 0)

    free(hdr_buf, 16)
    syscall(1, client_fd, msg, mlen, 0, 0, 0)
    return 1

// ── Decode Client Masked WebSocket Frame (Client -> Server) ───────────────────
// WHY: Decodes XOR-masked incoming frame payload per RFC 6455 Section 5.3
fn ws_decode_client_frame in_buf nread
    if nread < 6
        return ""

    b0 = mem_byte_read(in_buf, 0)
    b1 = mem_byte_read(in_buf, 1)

    opcode = b0 & 15
    // Opcode 8: Connection Close Frame
    if opcode == 8
        return ""

    is_masked = (b1 >> 7) & 1
    len_code = b1 & 127

    header_offset = 2
    actual_len = len_code
    if len_code == 126
        b2 = mem_byte_read(in_buf, 2)
        b3 = mem_byte_read(in_buf, 3)
        actual_len = (b2 << 8) | b3
        header_offset = 4
    elif len_code == 127
        header_offset = 10

    if is_masked == 0
        // Client frames MUST be masked; reject if unmasked
        return ""

    // Read 4-byte masking key
    m0 = mem_byte_read(in_buf, header_offset)
    m1 = mem_byte_read(in_buf, header_offset + 1)
    m2 = mem_byte_read(in_buf, header_offset + 2)
    m3 = mem_byte_read(in_buf, header_offset + 3)

    payload_start = header_offset + 4
    res = ""
    i = 0
    while i < actual_len and (payload_start + i) < nread
        masked_byte = mem_byte_read(in_buf, payload_start + i)
        mod4 = i % 4
        unmasked = 0
        if mod4 == 0
            unmasked = masked_byte ^ m0
        elif mod4 == 1
            unmasked = masked_byte ^ m1
        elif mod4 == 2
            unmasked = masked_byte ^ m2
        else
            unmasked = masked_byte ^ m3
        res = res + chr(unmasked)
        i = i + 1

    return res
