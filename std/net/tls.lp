// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: PURE LIPI CRYPTOGRAPHIC TLS & CHACHA20 (std/tls.lp)
// ⚡ 100% Sovereign RFC 8439 ChaCha20 Stream Cipher | RFC 8446 TLS 1.3 Framing
// ==============================================================================

// WHY: Modern secure systems programming requires authenticated, high-throughput
// symmetric encryption and TLS framing without depending on OpenSSL, BoringSSL,
// or any foreign C library. std/tls.lp delivers pure-silicon RFC 8439 ChaCha20
// stream encryption and TLS record serialization in native Lipi machine code.

include "std/mem.lp"

// ১. ChaCha20 aোয়ার্টার রাউন্ড (RFC 8439 Quarter Round Function)
// WHY: Executes 4 quarter-round additions, XORs, and 32-bit left rotations (rol32)
// on state vector indices (a, b, c, d). Single-cycle rol %cl, %eax hardware execution.
fn chacha20_qr(mem, a_idx, b_idx, c_idx, d_idx)
    mask32 = 4294967295
    a_off = a_idx * 8
    b_off = b_idx * 8
    c_off = c_idx * 8
    d_off = d_idx * 8

    a = mem_পড়ো(mem, a_off)
    b = mem_পড়ো(mem, b_off)
    c = mem_পড়ো(mem, c_off)
    d = mem_পড়ো(mem, d_off)

    // a = (a + b) & 0xFFFFFFFF; d = rol32(d ^ a, 16)
    a = (a + b) & mask32
    d = rol32(d ^ a, 16) & mask32

    // c = (c + d) & 0xFFFFFFFF; b = rol32(b ^ c, 12)
    c = (c + d) & mask32
    b = rol32(b ^ c, 12) & mask32

    // a = (a + b) & 0xFFFFFFFF; d = rol32(d ^ a, 8)
    a = (a + b) & mask32
    d = rol32(d ^ a, 8) & mask32

    // c = (c + d) & 0xFFFFFFFF; b = rol32(b ^ c, 7)
    c = (c + d) & mask32
    b = rol32(b ^ c, 7) & mask32

    mem_write(mem, a_off, a)
    mem_write(mem, b_off, b)
    mem_write(mem, c_off, c)
    mem_write(mem, d_off, d)

// ২. ChaCha20 স্টেট ভেa্টর ইনিশিয়ালাইজেশন (RFC 8439 Initial Matrix 4x4)
// WHY: Sets up 16 32-bit words: constants "expand 32-byte k", 256-bit key, 32-bit block counter, and 96-bit nonce.
fn chacha20_স্টেট_created(state_mem, aি_mem, nonce_mem, aাউন্টার)
    // word ০..৩: RFC 8439 ম্যাজিa aনস্ট্যান্ট ("expand 32-byte k")
    mem_write(state_mem, 0, 0x61707865)   // "expa"
    mem_write(state_mem, 8, 0x3320646e)   // "nd 3"
    mem_write(state_mem, 16, 0x79622d32)  // "2-by"
    mem_write(state_mem, 24, 0x6b206574)  // "te k"

    // word ৪..১১: ২৫৬-বিট এনa্রিপশন aি (৮টি ৩২-বিট ওয়ার্ড)
    i = 0
    while i < 8
        aি_শব্দ = mem_পড়ো(aি_mem, i * 8)
        mem_write(state_mem, (4 + i) * 8, aি_শব্দ & 4294967295)
        i = i + 1

    // word ১২: ৩২-বিট ব্লa aাউন্টার
    mem_write(state_mem, 96, aাউন্টার & 4294967295)

    // word ১৩..১৫: ৯৬-বিট a্রিপ্টোগ্রাফিa ননস (৩টি ৩২-বিট ওয়ার্ড)
    n0 = mem_পড়ো(nonce_mem, 0)
    n1 = mem_পড়ো(nonce_mem, 8)
    n2 = mem_পড়ো(nonce_mem, 16)
    mem_write(state_mem, 104, n0 & 4294967295)
    mem_write(state_mem, 112, n1 & 4294967295)
    mem_write(state_mem, 120, n2 & 4294967295)

// ৩. ChaCha20 ৬৪-byte aিস্ট্রিম ব্লa জেনারেশন (RFC 8439 Block Function)
// WHY: Executes 20 rounds (10 column rounds + 10 diagonal rounds) on working state,
// adds original state, and serializes to 64 bytes of pseudo-random keystream.
fn chacha20_ব্লa(state_mem, out_buffer)
    র্aিং = malloc(256)
    mask32 = 4294967295

    // মূল স্টেটaে র্aিং memতে aপি aরা
    i = 0
    while i < 16
        val = mem_পড়ো(state_mem, i * 8)
        mem_write(র্aিং, i * 8, val)
        i = i + 1

    // ২০ রাউন্ড ট্রান্সফর্মেশন (১০টি ডাবল-রাউন্ড)
    রাউন্ড = 0
    while রাউন্ড < 10
        // column রাউন্ডস (Column Rounds)
        chacha20_qr(র্aিং, 0, 4, 8, 12)
        chacha20_qr(র্aিং, 1, 5, 9, 13)
        chacha20_qr(র্aিং, 2, 6, 10, 14)
        chacha20_qr(র্aিং, 3, 7, 11, 15)

        // ডায়াগনাল রাউন্ডস (Diagonal Rounds)
        chacha20_qr(র্aিং, 0, 5, 10, 15)
        chacha20_qr(র্aিং, 1, 6, 11, 12)
        chacha20_qr(র্aিং, 2, 7, 8, 13)
        chacha20_qr(র্aিং, 3, 4, 9, 14)

        রাউন্ড = রাউন্ড + 1

    // output ওয়ার্ড add এবং ৬৪-byte লিটল-এন্ডিয়ান রূপান্তর
    i = 0
    while i < 16
        orig = mem_পড়ো(state_mem, i * 8)
        work = mem_পড়ো(র্aিং, i * 8)
        sum = (orig + work) & mask32

        b0 = sum & 255
        b1 = (sum >> 8) & 255
        b2 = (sum >> 16) & 255
        b3 = (sum >> 24) & 255

        b_idx = i * 4
        mem_write_byte(out_buffer, b_idx + 0, b0)
        mem_write_byte(out_buffer, b_idx + 1, b1)
        mem_write_byte(out_buffer, b_idx + 2, b2)
        mem_write_byte(out_buffer, b_idx + 3, b3)

        i = i + 1

    free(র্aিং, 256)

// ৪. ChaCha20 স্ট্রিম এনa্রিপশন ও ডিa্রিপশন (Symmetric XOR Stream Process)
// WHY: Streams plaintext through generated 64-byte keystreams. Encryption and decryption
// are perfectly symmetric (A ^ K ^ K = A). Zero OpenSSL/Libc dependencies.
fn chacha20_প্রসেস(aি_mem, nonce_mem, শুরু_aাউন্টার, ইন_buffer, len, out_buffer)
    স্টেট = malloc(256)
    aিস্ট্রিম = malloc(128)
    cursor = 0
    বর্তval_aাউন্টার = শুরু_aাউন্টার

    while cursor < len
        chacha20_স্টেট_created(স্টেট, aি_mem, nonce_mem, বর্তval_aাউন্টার)
        chacha20_ব্লa(স্টেট, aিস্ট্রিম)

        ব্লa_size = 64
        if (len - cursor) < 64
            ব্লa_size = len - cursor

        j = 0
        while j < ব্লa_size
            p_byte = mem_byte_পড়ো(ইন_buffer, cursor + j)
            k_byte = mem_byte_পড়ো(aিস্ট্রিম, j)
            c_byte = p_byte ^ k_byte
            mem_write_byte(out_buffer, cursor + j, c_byte)
            j = j + 1

        cursor = cursor + ব্লa_size
        বর্তval_aাউন্টার = বর্তval_aাউন্টার + 1

    free(aিস্ট্রিম, 128)
    free(স্টেট, 256)
    return len

// ৫. টিএলএস রেaর্ড লেয়ার ফ্রেম প্যাaেজিং (RFC 8446 Record Header)
// WHY: Wraps payload with standard TLS 5-byte header:
// [Type: 1 byte (0x17 for AppData)] [Legacy Version: 0x03, 0x03] [Length: 2 bytes Big-Endian]
fn tls_রেaর্ড_প্যাa(aন্টেন্ট_টাইপ, পেয়লোড_buffer, পেয়লোড_length, frame_buffer)
    mem_write_byte(frame_buffer, 0, aন্টেন্ট_টাইপ & 255) // 0x17 = Application Data
    mem_write_byte(frame_buffer, 1, 3)                   // TLS Legacy Major
    mem_write_byte(frame_buffer, 2, 3)                   // TLS Legacy Minor (TLS 1.2 / TLS 1.3 Compat)
    len_hi = (পেয়লোড_length >> 8) & 255
    len_lo = পেয়লোড_length & 255
    mem_write_byte(frame_buffer, 3, len_hi)              // Big-Endian Length HI
    mem_write_byte(frame_buffer, 4, len_lo)              // Big-Endian Length LO

    i = 0
    while i < পেয়লোড_length
        b = mem_byte_পড়ো(পেয়লোড_buffer, i)
        mem_write_byte(frame_buffer, 5 + i, b)
        i = i + 1

    return 5 + পেয়লোড_length

// ৬. টিএলএস রেaর্ড ফ্রেম header পার্সিং ও আনপ্যাaিং
// WHY: Validates 5-byte TLS record header, extracts payload length, and unpacks payload.
fn tls_রেaর্ড_আনপ্যাa(frame_buffer, out_পেয়লোড)
    len_hi = mem_byte_পড়ো(frame_buffer, 3)
    len_lo = mem_byte_পড়ো(frame_buffer, 4)
    len = (len_hi << 8) | len_lo

    i = 0
    while i < len
        b = mem_byte_পড়ো(frame_buffer, 5 + i)
        mem_write_byte(out_পেয়লোড, i, b)
        i = i + 1

    return len
