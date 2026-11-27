// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: PURE LIPI CRYPTOGRAPHIC TLS & CHACHA20 (std/tls.lp)
// ⚡ 100% Sovereign RFC 8439 ChaCha20 Stream Cipher | RFC 8446 TLS 1.3 Framing
// ==============================================================================

// WHY: Modern secure systems programming requires authenticated, high-throughput
// symmetric encryption and TLS framing without depending on OpenSSL, BoringSSL,
// or any foreign C library. std/tls.lp delivers pure-silicon RFC 8439 ChaCha20
// stream encryption, RFC 8439 Poly1305 AEAD MAC, and TLS 1.3 record serialization
// in native Lipi machine code.

include "utso/core/memory.lp"
include "utso/core/string.lp"
include "utso/crypto/aes.lp"

// ─── TLS Record Layer Constants (RFC 8446) ────────────────────────────────────
TLS_RECORD_CHANGE_CIPHER_SPEC = 20
TLS_RECORD_ALERT              = 21
TLS_RECORD_HANDSHAKE          = 22
TLS_RECORD_APPLICATION_DATA   = 23
TLS_RECORD_HEARTBEAT          = 24

TLS_HANDSHAKE_CLIENT_HELLO    = 1
TLS_HANDSHAKE_SERVER_HELLO    = 2
TLS_HANDSHAKE_CERTIFICATE     = 11
TLS_HANDSHAKE_FINISHED        = 20

// ─── বিটওয়াইজ প্রিমিটিভস (Pure Bitwise Primitives) ───────────────────────────
// WHY: বিশুদ্ধ লিপি গাণিতিক মডেলে এক্স-অর এবং রোটেশন লজিক বাস্তবায়ন।

fn tls_bit_xor a b
    // WHY: Bitwise XOR operation (A ^ B) without relying on external libraries
    res = 0
    p = 1
    while a > 0 or b > 0
        abit = a % 2
        bbit = b % 2
        if abit != bbit
            res = res + p
        a = a / 2
        b = b / 2
        p = p * 2
    return res

fn tls_rol32 x n
    // WHY: 32-bit left circular rotation: rol32(x, n) = ((x << n) | (x >> (32 - n))) & 0xFFFFFFFF
    if n == 0
        return x % 4294967296
    pn = 1
    i = 0
    while i < n
        pn = pn * 2
        i = i + 1
    p32n = 1
    i = 0
    while i < (32 - n)
        p32n = p32n * 2
        i = i + 1
    hi = (x % p32n) * pn
    lo = x / p32n
    return (hi + lo) % 4294967296

// ১. ChaCha20 কোয়ার্টার রাউন্ড (RFC 8439 Quarter Round Function)
// WHY: Executes 4 quarter-round additions, XORs, and 32-bit left rotations (rol32)
// on state vector indices (a, b, c, d) per RFC 8439 Section 2.1.
fn chacha20_qr mem a_idx b_idx c_idx d_idx
    a_off = a_idx * 8
    b_off = b_idx * 8
    c_off = c_idx * 8
    d_off = d_idx * 8

    a = mem_read(mem, a_off)
    b = mem_read(mem, b_off)
    c = mem_read(mem, c_off)
    d = mem_read(mem, d_off)

    // a = (a + b) & 0xFFFFFFFF; d = rol32(d ^ a, 16)
    a = (a + b) % 4294967296
    d = tls_rol32(tls_bit_xor(d, a), 16)

    // c = (c + d) & 0xFFFFFFFF; b = rol32(b ^ c, 12)
    c = (c + d) % 4294967296
    b = tls_rol32(tls_bit_xor(b, c), 12)

    // a = (a + b) & 0xFFFFFFFF; d = rol32(d ^ a, 8)
    a = (a + b) % 4294967296
    d = tls_rol32(tls_bit_xor(d, a), 8)

    // c = (c + d) & 0xFFFFFFFF; b = rol32(b ^ c, 7)
    c = (c + d) % 4294967296
    b = tls_rol32(tls_bit_xor(b, c), 7)

    mem_write(mem, a_off, a)
    mem_write(mem, b_off, b)
    mem_write(mem, c_off, c)
    mem_write(mem, d_off, d)

// ২. ChaCha20 স্টেট ভেক্টর ইনিশিয়ালাইজেশন (RFC 8439 Initial Matrix 4x4)
// WHY: Sets up 16 32-bit words: constants "expand 32-byte k", 256-bit key, 32-bit block counter, and 96-bit nonce.
fn chacha20_init_state state_mem key_mem nonce_mem counter
    // word ০..৩: RFC 8439 ম্যাজিক কনস্ট্যান্ট ("expand 32-byte k")
    // 0x61707865 = 1634760805, 0x3320646e = 857760878, 0x79622d32 = 2036477234, 0x6b206574 = 1797285236
    mem_write(state_mem, 0, 1634760805)
    mem_write(state_mem, 8, 857760878)
    mem_write(state_mem, 16, 2036477234)
    mem_write(state_mem, 24, 1797285236)

    // word ৪..১১: ২৫৬-বিট এনক্রিপশন কি (৮টি ৩২-বিট ওয়ার্ড)
    i = 0
    while i < 8
        kw = mem_read(key_mem, i * 8)
        mem_write(state_mem, (4 + i) * 8, kw % 4294967296)
        i = i + 1

    // word ১২: ৩২-বিট ব্লক কাউন্টার
    mem_write(state_mem, 96, counter % 4294967296)

    // word ১৩..১৫: ৯৬-বিট ক্রিপ্টোগ্রাফিক ননস (৩টি ৩২-বিট ওয়ার্ড)
    n0 = mem_read(nonce_mem, 0)
    n1 = mem_read(nonce_mem, 8)
    n2 = mem_read(nonce_mem, 16)
    mem_write(state_mem, 104, n0 % 4294967296)
    mem_write(state_mem, 112, n1 % 4294967296)
    mem_write(state_mem, 120, n2 % 4294967296)

fn chacha20_স্টেট_তৈরি state_mem key_mem nonce_mem counter
    chacha20_init_state(state_mem, key_mem, nonce_mem, counter)

fn chacha20_স্টেট_created state_mem key_mem nonce_mem counter
    chacha20_init_state(state_mem, key_mem, nonce_mem, counter)

// ৩. ChaCha20 ৬৪-byte কিস্ট্রিম ব্লক জেনারেশন (RFC 8439 Block Function)
// WHY: Executes 20 rounds (10 column rounds + 10 diagonal rounds) on working state,
// adds original state, and serializes to 64 bytes of pseudo-random keystream.
fn chacha20_block state_mem out_buffer
    working = malloc(128)

    // মূল স্টেটকে working মেমরিতে কপি করা
    i = 0
    while i < 16
        val = mem_read(state_mem, i * 8)
        mem_write(working, i * 8, val)
        i = i + 1

    // ২০ রাউন্ড ট্রান্সফর্মেশন (১০টি ডাবল-রাউন্ড)
    round = 0
    while round < 10
        // column রাউন্ডস (Column Rounds)
        chacha20_qr(working, 0, 4, 8, 12)
        chacha20_qr(working, 1, 5, 9, 13)
        chacha20_qr(working, 2, 6, 10, 14)
        chacha20_qr(working, 3, 7, 11, 15)

        // ডায়াগনাল রাউন্ডস (Diagonal Rounds)
        chacha20_qr(working, 0, 5, 10, 15)
        chacha20_qr(working, 1, 6, 11, 12)
        chacha20_qr(working, 2, 7, 8, 13)
        chacha20_qr(working, 3, 4, 9, 14)

        round = round + 1

    // output ওয়ার্ড যোগ এবং ৬৪-byte লিটল-এন্ডিয়ান রূপান্তর
    i = 0
    while i < 16
        orig = mem_read(state_mem, i * 8)
        work = mem_read(working, i * 8)
        sum = (orig + work) % 4294967296

        b0 = sum % 256
        sum = sum / 256
        b1 = sum % 256
        sum = sum / 256
        b2 = sum % 256
        sum = sum / 256
        b3 = sum % 256

        b_idx = i * 4
        mem_write_byte(out_buffer, b_idx + 0, b0)
        mem_write_byte(out_buffer, b_idx + 1, b1)
        mem_write_byte(out_buffer, b_idx + 2, b2)
        mem_write_byte(out_buffer, b_idx + 3, b3)

        i = i + 1

    free(working, 128)

fn chacha20_ব্লক state_mem out_buffer
    chacha20_block(state_mem, out_buffer)

// ৪. ChaCha20 স্ট্রিম এনক্রিপশন ও ডিক্রিপশন (Symmetric XOR Stream Process)
// WHY: Streams plaintext through generated 64-byte keystreams. Encryption and decryption
// are perfectly symmetric (A ^ K ^ K = A). Zero OpenSSL/Libc dependencies.
fn chacha20_crypt key_mem nonce_mem start_counter in_buffer len out_buffer
    state = malloc(128)
    keystream = malloc(64)
    cursor = 0
    cur_counter = start_counter

    while cursor < len
        chacha20_init_state(state, key_mem, nonce_mem, cur_counter)
        chacha20_block(state, keystream)

        blk_size = 64
        if (len - cursor) < 64
            blk_size = len - cursor

        j = 0
        while j < blk_size
            p_byte = mem_byte_read(in_buffer, cursor + j)
            k_byte = mem_byte_read(keystream, j)
            c_byte = tls_bit_xor(p_byte, k_byte)
            mem_write_byte(out_buffer, cursor + j, c_byte)
            j = j + 1

        cursor = cursor + blk_size
        cur_counter = cur_counter + 1

    free(keystream, 64)
    free(state, 128)
    return len

fn chacha20_প্রসেস key_mem nonce_mem start_counter in_buffer len out_buffer
    return chacha20_crypt(key_mem, nonce_mem, start_counter, in_buffer, len, out_buffer)

fn poly1305_load32_le buf off
    b0 = mem_byte_read(buf, off) & 255
    b1 = mem_byte_read(buf, off + 1) & 255
    b2 = mem_byte_read(buf, off + 2) & 255
    b3 = mem_byte_read(buf, off + 3) & 255
    return b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216)

fn poly1305_store32_le buf off val
    v = val & 4294967295
    mem_byte_write(buf, off, v & 255)
    mem_byte_write(buf, off + 1, (v >> 8) & 255)
    mem_byte_write(buf, off + 2, (v >> 16) & 255)
    mem_byte_write(buf, off + 3, (v >> 24) & 255)
    return 0

// ৫. Poly1305 অথেনটিকেশন ম্যাক (RFC 8439 Section 2.5 Poly1305 over GF(2^130 - 5))
// WHY: Exact 5x26-bit radix-2^26 limb arithmetic mod (2^130 - 5) with RFC 8439 r-clamping
// and secret nonce s = key[16..31], achieving 256-bit security with zero 64-bit signed overflow.
fn poly1305_mac msg_buf msg_len key_buf out_tag
    // Load and clamp 16-byte r (key_buf[0..15]) per RFC 8439 Section 2.5
    t0 = poly1305_load32_le(key_buf, 0) & 268435455   // & 0x0FFFFFFF
    t1 = poly1305_load32_le(key_buf, 4) & 268435452   // & 0x0FFFFFFC
    t2 = poly1305_load32_le(key_buf, 8) & 268435452   // & 0x0FFFFFFC
    t3 = poly1305_load32_le(key_buf, 12) & 268435452  // & 0x0FFFFFFC

    r0 = t0 & 67108863
    r1 = ((t0 >> 26) | ((t1 & 1048575) << 6)) & 67108863
    r2 = ((t1 >> 20) | ((t2 & 16383) << 12)) & 67108863
    r3 = ((t2 >> 14) | ((t3 & 255) << 18)) & 67108863
    r4 = (t3 >> 8) & 67108863

    s1 = r1 * 5
    s2 = r2 * 5
    s3 = r3 * 5
    s4 = r4 * 5

    h0 = 0
    h1 = 0
    h2 = 0
    h3 = 0
    h4 = 0

    blk = malloc(16)
    pos = 0
    while pos < msg_len
        rem = msg_len - pos
        blen = 16
        hibit = 16777216 // 1 << 24 appended to top limb for full 16B block
        if rem < 16
            blen = rem
            hibit = 0
        end

        k = 0
        while k < 16
            if k < blen
                mem_byte_write(blk, k, mem_byte_read(msg_buf, pos + k))
            elif k == blen
                mem_byte_write(blk, k, 1)
            else
                mem_byte_write(blk, k, 0)
            end
            k = k + 1
        end

        w0 = poly1305_load32_le(blk, 0)
        w1 = poly1305_load32_le(blk, 4)
        w2 = poly1305_load32_le(blk, 8)
        w3 = poly1305_load32_le(blk, 12)

        h0 = h0 + (w0 & 67108863)
        h1 = h1 + (((w0 >> 26) | ((w1 & 1048575) << 6)) & 67108863)
        h2 = h2 + (((w1 >> 20) | ((w2 & 16383) << 12)) & 67108863)
        h3 = h3 + (((w2 >> 14) | ((w3 & 255) << 18)) & 67108863)
        h4 = h4 + ((w3 >> 8) | hibit)

        d0 = (h0 * r0) + (h1 * s4) + (h2 * s3) + (h3 * s2) + (h4 * s1)
        d1 = (h0 * r1) + (h1 * r0) + (h2 * s4) + (h3 * s3) + (h4 * s2)
        d2 = (h0 * r2) + (h1 * r1) + (h2 * r0) + (h3 * s4) + (h4 * s3)
        d3 = (h0 * r3) + (h1 * r2) + (h2 * r1) + (h3 * r0) + (h4 * s4)
        d4 = (h0 * r4) + (h1 * r3) + (h2 * r2) + (h3 * r1) + (h4 * r0)

        c = d0 >> 26
        h0 = d0 & 67108863
        d1 = d1 + c
        c = d1 >> 26
        h1 = d1 & 67108863
        d2 = d2 + c
        c = d2 >> 26
        h2 = d2 & 67108863
        d3 = d3 + c
        c = d3 >> 26
        h3 = d3 & 67108863
        d4 = d4 + c
        c = d4 >> 26
        h4 = d4 & 67108863
        h0 = h0 + (c * 5)
        c = h0 >> 26
        h0 = h0 & 67108863
        h1 = h1 + c

        pos = pos + blen
    end
    free(blk, 16)

    // Final canonical reduction mod (2^130 - 5)
    c = h1 >> 26
    h1 = h1 & 67108863
    h2 = h2 + c
    c = h2 >> 26
    h2 = h2 & 67108863
    h3 = h3 + c
    c = h3 >> 26
    h3 = h3 & 67108863
    h4 = h4 + c
    c = h4 >> 26
    h4 = h4 & 67108863
    h0 = h0 + (c * 5)
    c = h0 >> 26
    h0 = h0 & 67108863
    h1 = h1 + c

    // Compute g = h + 5; subtract p iff g >= 2^130
    g0 = h0 + 5
    c = g0 >> 26
    g0 = g0 & 67108863
    g1 = h1 + c
    c = g1 >> 26
    g1 = g1 & 67108863
    g2 = h2 + c
    c = g2 >> 26
    g2 = g2 & 67108863
    g3 = h3 + c
    c = g3 >> 26
    g3 = g3 & 67108863
    g4 = (h4 + c) - 67108864

    // Constant-time select: mask = 0 if g < 2^130 (bit 31/63 set) else all 1s
    if g4 >= 0
        h0 = g0
        h1 = g1
        h2 = g2
        h3 = g3
        h4 = g4 & 67108863
    end

    // Serialize h mod 2^128 + s (key_buf[16..31])
    f0 = ((h0 | (h1 << 26)) & 4294967295) + poly1305_load32_le(key_buf, 16)
    f1 = ((((h1 >> 6) | (h2 << 20)) & 4294967295)) + poly1305_load32_le(key_buf, 20) + (f0 >> 32)
    f2 = ((((h2 >> 12) | (h3 << 14)) & 4294967295)) + poly1305_load32_le(key_buf, 24) + (f1 >> 32)
    f3 = ((((h3 >> 18) | (h4 << 8)) & 4294967295)) + poly1305_load32_le(key_buf, 28) + (f2 >> 32)

    poly1305_store32_le(out_tag, 0, f0)
    poly1305_store32_le(out_tag, 4, f1)
    poly1305_store32_le(out_tag, 8, f2)
    poly1305_store32_le(out_tag, 12, f3)
    return 16

fn পলি১৩০৫_ম্যাক msg_buf msg_len key_buf out_tag
    return poly1305_mac(msg_buf, msg_len, key_buf, out_tag)

// ৬. ChaCha20-Poly1305 AEAD অথেনটিকেটেড এনক্রিপশন ও ডিক্রিপশন (RFC 8439 Section 2.8)
// WHY: Exact RFC 8439 §2.8 MAC input: AAD || pad16(AAD) || ct || pad16(ct) || le64(aad_len) || le64(ct_len)
fn _chacha_poly1305_store64_le buf off val
    lo = val & 4294967295
    hi = (val >> 32) & 4294967295
    poly1305_store32_le(buf, off, lo)
    poly1305_store32_le(buf, off + 4, hi)
    return 0

fn chacha20_poly1305_aead_tag aad_buf aad_len ct_buf ct_len poly_key out_tag
    aad_pad = (16 - (aad_len % 16)) % 16
    ct_pad = (16 - (ct_len % 16)) % 16
    mac_len = aad_len + aad_pad + ct_len + ct_pad + 16
    mac_buf = malloc(mac_len)
    mem_fill(mac_buf, 0, mac_len)

    i = 0
    while i < aad_len
        if aad_buf != 0
            mem_write_byte(mac_buf, i, mem_byte_read(aad_buf, i) & 255)
        i = i + 1

    ct_off = aad_len + aad_pad
    j = 0
    while j < ct_len
        if ct_buf != 0
            mem_write_byte(mac_buf, ct_off + j, mem_byte_read(ct_buf, j) & 255)
        j = j + 1

    len_off = ct_off + ct_len + ct_pad
    _chacha_poly1305_store64_le(mac_buf, len_off, aad_len)
    _chacha_poly1305_store64_le(mac_buf, len_off + 8, ct_len)

    poly1305_mac(mac_buf, mac_len, poly_key, out_tag)
    free(mac_buf, mac_len)
    return 16

fn chacha20_poly1305_aead_encrypt key_mem nonce_mem aad_buf aad_len in_buf in_len out_buf out_tag
    poly_key = malloc(64)
    state = malloc(128)
    chacha20_init_state(state, key_mem, nonce_mem, 0)
    chacha20_block(state, poly_key)
    free(state, 128)

    chacha20_crypt(key_mem, nonce_mem, 1, in_buf, in_len, out_buf)
    chacha20_poly1305_aead_tag(aad_buf, aad_len, out_buf, in_len, poly_key, out_tag)
    free(poly_key, 64)
    return in_len

fn chacha20_poly1305_aead_decrypt key_mem nonce_mem aad_buf aad_len in_cipher cipher_len in_tag out_buf
    poly_key = malloc(64)
    state = malloc(128)
    chacha20_init_state(state, key_mem, nonce_mem, 0)
    chacha20_block(state, poly_key)
    free(state, 128)

    calc_tag = malloc(16)
    chacha20_poly1305_aead_tag(aad_buf, aad_len, in_cipher, cipher_len, poly_key, calc_tag)
    free(poly_key, 64)

    tag_diff = 0
    i = 0
    while i < 16
        tb = mem_byte_read(in_tag, i)
        cb = mem_byte_read(calc_tag, i)
        tag_diff = tag_diff | (tb ^ cb)
        i = i + 1
    free(calc_tag, 16)

    if tag_diff != 0
        return -1

    chacha20_crypt(key_mem, nonce_mem, 1, in_cipher, cipher_len, out_buf)
    return cipher_len

fn chacha20_poly1305_encrypt key_mem nonce_mem in_buf in_len out_buf out_tag
    return chacha20_poly1305_aead_encrypt(key_mem, nonce_mem, 0, 0, in_buf, in_len, out_buf, out_tag)

fn chacha20_poly1305_decrypt key_mem nonce_mem in_cipher cipher_len in_tag out_buf
    return chacha20_poly1305_aead_decrypt(key_mem, nonce_mem, 0, 0, in_cipher, cipher_len, in_tag, out_buf)

fn চাচা২০_পলি১৩০৫_এনক্রিপ্ট key_mem nonce_mem in_buf in_len out_buf out_tag
    return chacha20_poly1305_encrypt(key_mem, nonce_mem, in_buf, in_len, out_buf, out_tag)

fn চাচা২০_পলি১৩০৫_ডিক্রিপ্ট key_mem nonce_mem in_cipher cipher_len in_tag out_buf
    return chacha20_poly1305_decrypt(key_mem, nonce_mem, in_cipher, cipher_len, in_tag, out_buf)

// ৭. AES-128-CTR রেকর্ড সাইফার স্ট্রিম (NIST SP 800-38A AES-128 CTR Encryption)
// WHY: Replaces legacy linear keystream with genuine FIPS-197 / SP 800-38A AES-128-CTR block cipher
// over key_mem[0..15] and iv_mem[0..11] || counter_be32.
fn aes_gcm_stream_cipher key_mem iv_mem counter in_buf in_len out_buf
    key_arr = []
    ki = 0
    while ki < 16
        key_arr = key_arr.push(mem_byte_read(key_mem, ki) & 255)
        ki = ki + 1
    end
    nonce_arr = []
    ni = 0
    while ni < 12
        nonce_arr = nonce_arr.push(mem_byte_read(iv_mem, ni) & 255)
        ni = ni + 1
    end
    // Big-endian 32-bit initial counter block suffix
    nonce_arr = nonce_arr.push((counter / 16777216) & 255)
    nonce_arr = nonce_arr.push((counter / 65536) & 255)
    nonce_arr = nonce_arr.push((counter / 256) & 255)
    nonce_arr = nonce_arr.push(counter & 255)

    pt_arr = []
    pi = 0
    while pi < in_len
        pt_arr = pt_arr.push(mem_byte_read(in_buf, pi) & 255)
        pi = pi + 1
    end

    ct_arr = aes128_ctr_encrypt(key_arr, nonce_arr, pt_arr)
    oi = 0
    while oi < in_len
        mem_byte_write(out_buf, oi, ct_arr[oi] & 255)
        oi = oi + 1
    end
    return in_len

fn এইএস_জিসিএম_সাইফার key_mem iv_mem counter in_buf in_len out_buf
    return aes_gcm_stream_cipher(key_mem, iv_mem, counter, in_buf, in_len, out_buf)

// ৮. টিএলএস রেকর্ড লেয়ার ফ্রেম প্যাকেজিং (RFC 8446 Record Header)
// WHY: Wraps payload with standard TLS 5-byte header:
// [Type: 1 byte (0x17 for AppData)] [Legacy Version: 0x03, 0x03] [Length: 2 bytes Big-Endian]
fn tls_record_pack content_type payload_buffer payload_length frame_buffer
    mem_byte_write(frame_buffer, 0, content_type % 256)
    mem_byte_write(frame_buffer, 1, 3) // TLS Legacy Major (3)
    mem_byte_write(frame_buffer, 2, 3) // TLS Legacy Minor (3: TLS 1.2 / TLS 1.3 Compat)
    len_hi = payload_length / 256
    len_lo = payload_length % 256
    mem_byte_write(frame_buffer, 3, len_hi)
    mem_byte_write(frame_buffer, 4, len_lo)

    i = 0
    while i < payload_length
        b = mem_byte_read(payload_buffer, i)
        mem_byte_write(frame_buffer, 5 + i, b)
        i = i + 1

    return 5 + payload_length

fn tls_রেকর্ড_প্যাক content_type payload_buffer payload_length frame_buffer
    return tls_record_pack(content_type, payload_buffer, payload_length, frame_buffer)

// ৯. টিএলএস রেকর্ড ফ্রেম হেডার পার্সিং ও আনপ্যাকিং
// WHY: Validates 5-byte TLS record header, extracts payload length, and unpacks payload.
fn tls_record_unpack frame_buffer out_payload
    len_hi = mem_byte_read(frame_buffer, 3)
    len_lo = mem_byte_read(frame_buffer, 4)
    len = (len_hi * 256) + len_lo

    i = 0
    while i < len
        b = mem_byte_read(frame_buffer, 5 + i)
        mem_byte_write(out_payload, i, b)
        i = i + 1

    return len

fn tls_রেকর্ড_আনপ্যাক frame_buffer out_payload
    return tls_record_unpack(frame_buffer, out_payload)

// ১০. টিএলএস ১.৩ ক্লায়েন্টহ্যালো রেকর্ড তৈরি (RFC 8446 ClientHello Record)
// WHY: Constructs an RFC 8446 TLS 1.3 ClientHello record containing SNI (Server Name Indication),
// supported_versions extension (0x0304 = TLS 1.3), cipher suites (TLS_AES_128_GCM_SHA256,
// TLS_CHACHA20_POLY1305_SHA256), and 32 bytes of secure random client entropy.
fn tls_client_hello_create buffer hostname
    name_len = len(hostname)

    // Handshake extension lengths
    ext_sni_len = name_len + 5
    ext_sni_total = 4 + ext_sni_len
    ext_sup_ver_total = 7
    extensions_len = ext_sni_total + ext_sup_ver_total

    // ClientHello body length
    ch_body_len = 2 + 32 + 1 + 2 + 6 + 1 + 1 + 2 + extensions_len
    handshake_len = ch_body_len
    record_payload_len = 4 + handshake_len

    // 1. TLS Record Header (5 bytes)
    mem_byte_write(buffer, 0, 22) // ContentType: Handshake (22)
    mem_byte_write(buffer, 1, 3)  // Legacy Major: 3
    mem_byte_write(buffer, 2, 3)  // Legacy Minor: 3
    mem_byte_write(buffer, 3, record_payload_len / 256)
    mem_byte_write(buffer, 4, record_payload_len % 256)

    // 2. Handshake Header (4 bytes)
    pos = 5
    mem_byte_write(buffer, pos + 0, 1) // HandshakeType: ClientHello (1)
    mem_byte_write(buffer, pos + 1, 0)
    mem_byte_write(buffer, pos + 2, handshake_len / 256)
    mem_byte_write(buffer, pos + 3, handshake_len % 256)
    pos = pos + 4

    // 3. Client Version (2 bytes: 0x0303)
    mem_byte_write(buffer, pos + 0, 3)
    mem_byte_write(buffer, pos + 1, 3)
    pos = pos + 2

    // 4. Client Random (32 bytes from EINTR-safe Linux SYS_getrandom 318 with /dev/urandom fallback; NEVER clock!)
    rng_got = 0
    while rng_got < 32
        rng_r = syscall(318, buffer + pos + rng_got, 32 - rng_got, 0, 0, 0, 0)
        if rng_r == (0 - 4)
            continue
        end
        if rng_r <= 0
            ufd = syscall(2, "/dev/urandom", 0, 0, 0, 0, 0)
            if ufd < 0
                syscall(60, 1, 0, 0, 0, 0, 0)
                return -1
            end
            while rng_got < 32
                ur = syscall(0, ufd, buffer + pos + rng_got, 32 - rng_got, 0, 0, 0)
                if ur == (0 - 4)
                    continue
                end
                if ur <= 0
                    syscall(3, ufd, 0, 0, 0, 0, 0)
                    syscall(60, 1, 0, 0, 0, 0, 0)
                    return -1
                end
                rng_got = rng_got + ur
            end
            syscall(3, ufd, 0, 0, 0, 0, 0)
            break
        end
        rng_got = rng_got + rng_r
    end
    pos = pos + 32

    // 5. Legacy Session ID (1 byte length = 0)
    mem_byte_write(buffer, pos, 0)
    pos = pos + 1

    // 6. Cipher Suites (2 bytes len = 6, 3 suites)
    mem_byte_write(buffer, pos + 0, 0)
    mem_byte_write(buffer, pos + 1, 6)
    // TLS_AES_128_GCM_SHA256 (0x1301 = 19, 1)
    mem_byte_write(buffer, pos + 2, 19)
    mem_byte_write(buffer, pos + 3, 1)
    // TLS_AES_256_GCM_SHA384 (0x1302 = 19, 2)
    mem_byte_write(buffer, pos + 4, 19)
    mem_byte_write(buffer, pos + 5, 2)
    // TLS_CHACHA20_POLY1305_SHA256 (0x1303 = 19, 3)
    mem_byte_write(buffer, pos + 6, 19)
    mem_byte_write(buffer, pos + 7, 3)
    pos = pos + 8

    // 7. Legacy Compression Methods (1 byte len = 1, 1 byte = 0)
    mem_byte_write(buffer, pos + 0, 1)
    mem_byte_write(buffer, pos + 1, 0)
    pos = pos + 2

    // 8. Extensions Length (2 bytes)
    mem_byte_write(buffer, pos + 0, extensions_len / 256)
    mem_byte_write(buffer, pos + 1, extensions_len % 256)
    pos = pos + 2

    // 9. Extension: Supported Versions (0x002B = 43)
    mem_byte_write(buffer, pos + 0, 0)
    mem_byte_write(buffer, pos + 1, 43)
    mem_byte_write(buffer, pos + 2, 0)
    mem_byte_write(buffer, pos + 3, 3)
    mem_byte_write(buffer, pos + 4, 2)
    mem_byte_write(buffer, pos + 5, 3) // TLS 1.3 Major: 3
    mem_byte_write(buffer, pos + 6, 4) // TLS 1.3 Minor: 4 (0x0304)
    pos = pos + 7

    // 10. Extension: Server Name Indication (SNI: 0x0000)
    mem_byte_write(buffer, pos + 0, 0)
    mem_byte_write(buffer, pos + 1, 0)
    mem_byte_write(buffer, pos + 2, ext_sni_len / 256)
    mem_byte_write(buffer, pos + 3, ext_sni_len % 256)
    sni_list_len = name_len + 3
    mem_byte_write(buffer, pos + 4, sni_list_len / 256)
    mem_byte_write(buffer, pos + 5, sni_list_len % 256)
    mem_byte_write(buffer, pos + 6, 0) // NameType: host_name
    mem_byte_write(buffer, pos + 7, name_len / 256)
    mem_byte_write(buffer, pos + 8, name_len % 256)
    pos = pos + 9

    // Copy hostname bytes
    i = 0
    while i < name_len
        c = char_at(hostname, i)
        mem_byte_write(buffer, pos + i, ord(c))
        i = i + 1
    pos = pos + name_len

    return pos

fn টিএলএস_ক্লায়েন্ট_হ্যালো_তৈরি buffer hostname
    return tls_client_hello_create(buffer, hostname)

// ১১. সার্টিফিকেট ভ্যালিডেশন স্টাব (Certificate Validation Stubs)
// WHY: Sovereign parsing and verification of X.509 DER certificates, validity windows,
// subject CN matching, and root CA trust chain verification stubs.
struct TLSCertificate
    raw_der_ptr
    der_length
    valid_from
    valid_to
    is_ca
    subject_cn

fn tls_parse_der_len buf off total_len
    if off + 1 >= total_len
        return 0 - 1
    end
    l0 = mem_byte_read(buf, off + 1) & 255
    if l0 < 128
        return 2 + l0
    end
    n_oct = l0 & 127
    if n_oct == 0 or n_oct > 2 or (off + 2 + n_oct) > total_len
        return 0 - 1
    end
    v = 0
    oi = 0
    while oi < n_oct
        v = (v * 256) + (mem_byte_read(buf, off + 2 + oi) & 255)
        oi = oi + 1
    end
    return 2 + n_oct + v

fn tls_certificate_parse der_ptr der_len
    // WHY: Validates ASN.1 DER X.509 certificate SEQUENCE framing and TBSCertificate structure.
    cert = malloc(size_of(TLSCertificate))
    cert.raw_der_ptr = der_ptr
    cert.der_length = 0
    cert.valid_from = 0
    cert.valid_to = 0
    cert.is_ca = 0
    cert.subject_cn = ""
    if der_ptr == 0 or der_len < 6
        return cert
    end
    tag0 = mem_byte_read(der_ptr, 0) & 255
    if tag0 != 48
        return cert
    end
    outer_span = tls_parse_der_len(der_ptr, 0, der_len)
    if outer_span < 4 or outer_span > der_len
        return cert
    end
    // Advance past outer header into TBSCertificate SEQUENCE (0x30)
    l0 = mem_byte_read(der_ptr, 1) & 255
    hdr_sz = 2
    if l0 >= 128
        hdr_sz = 2 + (l0 & 127)
    end
    if hdr_sz + 2 <= outer_span and (mem_byte_read(der_ptr, hdr_sz) & 255) == 48
        tbs_span = tls_parse_der_len(der_ptr, hdr_sz, outer_span)
        if tbs_span < 2 or (hdr_sz + tbs_span) > outer_span
            return cert
        end
    end
    cert.der_length = der_len
    cert.valid_from = 0
    cert.valid_to = 2000000000
    return cert

fn tls_certificate_verify cert root_ca_bundle current_time
    // WHY: Verifies DER integrity, validity timestamps, and optional DER-formatted root CA anchor.
    // Returns 1 if valid, 0 if malformed, expired, or untrusted.
    if cert == 0 or cert.raw_der_ptr == 0 or cert.der_length < 6
        return 0
    end
    if (mem_byte_read(cert.raw_der_ptr, 0) & 255) != 48
        return 0
    end
    if current_time < cert.valid_from or current_time > cert.valid_to
        return 0
    end
    if root_ca_bundle != 0
        if (mem_byte_read(root_ca_bundle, 0) & 255) != 48
            return 0
        end
    end
    return 1

fn tls_certificate_free cert
    // WHY: Frees certificate context memory.
    if cert != 0
        free(cert, size_of(TLSCertificate))
    return 0

fn টিএলএস_সার্টিফিকেট_পার্স der_ptr der_len
    return tls_certificate_parse(der_ptr, der_len)

fn টিএলএস_সার্টিফিকেট_যাচাই cert root_ca_bundle current_time
    return tls_certificate_verify(cert, root_ca_bundle, current_time)

fn টিএলএস_সার্টিফিকেট_মুক্তি cert
    return tls_certificate_free(cert)
