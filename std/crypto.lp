// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: HARDWARE CRYPTOGRAPHY & SHA-256 (std/crypto.lp)
// ⚡ 100% Sovereign NIST FIPS 180-4 Engine | Hardware CPU Entropy | Zero Libc
// ==============================================================================

// WHY: Cryptographic hashing and entropy generation must be entirely sovereign.
// This library implements the full NIST SHA-256 algorithm with single-cycle
// ror32 CPU instructions, bitwise logic, and RDRAND hardware entropy.

include "std/mem.lp"

// ১. a্রিপ্টোগ্রাফিa rate্ডওয়্যার সিলিaন র‍্যান্ডম ইন্টিজার জেনারেটর
fn silicon_random_int()
    r = সিলিaন_র্যান্ডম()
    return r

// ২. হেa্সাডেসিমেল a্যারেa্টার ম্যাপার (০-১৫ nibble থেaে ASCII code)
fn nibble_to_hex(nibble)
    n = nibble & 15
    if n < 10
        return 48 + n // ASCII "0" - "9"
    return 97 + (n - 10) // ASCII "a" - "f"

// ৩. SHA-256 রাউন্ড aনস্ট্যান্ট ইনিশিয়ালাইজার (K[0..63])
fn sha256_const_init(k_memory)
    mem_write(k_memory, 0, 0x428a2f98)
    mem_write(k_memory, 8, 0x71374491)
    mem_write(k_memory, 16, 0xb5c0fbcf)
    mem_write(k_memory, 24, 0xe9b5dba5)
    mem_write(k_memory, 32, 0x3956c25b)
    mem_write(k_memory, 40, 0x59f111f1)
    mem_write(k_memory, 48, 0x923f82a4)
    mem_write(k_memory, 56, 0xab1c5ed5)
    mem_write(k_memory, 64, 0xd807aa98)
    mem_write(k_memory, 72, 0x12835b01)
    mem_write(k_memory, 80, 0x243185be)
    mem_write(k_memory, 88, 0x550c7dc3)
    mem_write(k_memory, 96, 0x72be5d74)
    mem_write(k_memory, 104, 0x80deb1fe)
    mem_write(k_memory, 112, 0x9bdc06a7)
    mem_write(k_memory, 120, 0xc19bf174)
    mem_write(k_memory, 128, 0xe49b69c1)
    mem_write(k_memory, 136, 0xefbe4786)
    mem_write(k_memory, 144, 0xfc19dc6)
    mem_write(k_memory, 152, 0x240ca1cc)
    mem_write(k_memory, 160, 0x2de92c6f)
    mem_write(k_memory, 168, 0x4a7484aa)
    mem_write(k_memory, 176, 0x5cb0a9dc)
    mem_write(k_memory, 184, 0x76f988da)
    mem_write(k_memory, 192, 0x983e5152)
    mem_write(k_memory, 200, 0xa831c66d)
    mem_write(k_memory, 208, 0xb00327c8)
    mem_write(k_memory, 216, 0xbf597fc7)
    mem_write(k_memory, 224, 0xc6e00bf3)
    mem_write(k_memory, 232, 0xd5a79147)
    mem_write(k_memory, 240, 0x6ca6351)
    mem_write(k_memory, 248, 0x14292967)
    mem_write(k_memory, 256, 0x27b70a85)
    mem_write(k_memory, 264, 0x2e1b2138)
    mem_write(k_memory, 272, 0x4d2c6dfc)
    mem_write(k_memory, 280, 0x53380d13)
    mem_write(k_memory, 288, 0x650a7354)
    mem_write(k_memory, 296, 0x766a0abb)
    mem_write(k_memory, 304, 0x81c2c92e)
    mem_write(k_memory, 312, 0x92722c85)
    mem_write(k_memory, 320, 0xa2bfe8a1)
    mem_write(k_memory, 328, 0xa81a664b)
    mem_write(k_memory, 336, 0xc24b8b70)
    mem_write(k_memory, 344, 0xc76c51a3)
    mem_write(k_memory, 352, 0xd192e819)
    mem_write(k_memory, 360, 0xd6990624)
    mem_write(k_memory, 368, 0xf40e3585)
    mem_write(k_memory, 376, 0x106aa070)
    mem_write(k_memory, 384, 0x19a4c116)
    mem_write(k_memory, 392, 0x1e376c08)
    mem_write(k_memory, 400, 0x2748774c)
    mem_write(k_memory, 408, 0x34b0bcb5)
    mem_write(k_memory, 416, 0x391c0cb3)
    mem_write(k_memory, 424, 0x4ed8aa4a)
    mem_write(k_memory, 432, 0x5b9cca4f)
    mem_write(k_memory, 440, 0x682e6ff3)
    mem_write(k_memory, 448, 0x748f82ee)
    mem_write(k_memory, 456, 0x78a5636f)
    mem_write(k_memory, 464, 0x84c87814)
    mem_write(k_memory, 472, 0x8cc70208)
    mem_write(k_memory, 480, 0x90befffa)
    mem_write(k_memory, 488, 0xa4506ceb)
    mem_write(k_memory, 496, 0xbef9a3f7)
    mem_write(k_memory, 504, 0xc67178f2)
    return k_memory

// ৪. SHA-256 less্প্রেশন ফাংশন উপাদানসমূহ
fn sha256_ch(x, y, z)
    return z ^ (x & (y ^ z))

fn sha256_maj(x, y, z)
    return (x & y) ^ ((x ^ y) & z)

fn sha256_sigma0(x)
    return ror32(x, 2) ^ ror32(x, 13) ^ ror32(x, 22)

fn sha256_sigma1(x)
    return ror32(x, 6) ^ ror32(x, 11) ^ ror32(x, 25)

fn sha256_gamma0(x)
    return ror32(x, 7) ^ ror32(x, 18) ^ (x >> 3)

fn sha256_gamma1(x)
    return ror32(x, 17) ^ ror32(x, 19) ^ (x >> 10)

// ৫. পূর্ণাঙ্গ SHA-256 hashিং ইঞ্জিন
// মেসেজ পয়েন্টার এবং len নিয়ে ৬৪-a্যারেa্টার হেa্স ডাইজেস্ট output bufferে লেbে
fn sha256_hash(মেসেজ_পয়েন্টার, len, output_buffer)
    // aে aনস্ট্যান্ট memory pool allocation (৬৪ x ৮ = ৫১২ byte)
    aে_pool = malloc(512)
    sha256_const_init(aে_pool)

    // প্যাডিং size নির্ধারণ: len + ১ (0x80) + ৮ (len বিট)
    // ৬৪ byteের ব্লaে রাউন্ড-আপ
    প্যাডেড_length = ((len + 9 + 63) / 64) * 64
    padded_buffer = malloc(প্যাডেড_length + 64)
    mem_fill(padded_buffer, 0, প্যাডেড_length + 64)

    // মেসেজ byte অনুলিপি
    i = 0
    while i < len
        b = mem_byte_পড়ো(মেসেজ_পয়েন্টার, i)
        mem_write_byte(padded_buffer, i, b)
        i = i + 1

    // 0x80 byte অ্যাপেন্ড
    mem_write_byte(padded_buffer, len, 128)

    // total len বিটে হিসাব (Big-Endian 64-bit integer at the end of block)
    total_bit = len * 8
    len_offset = প্যাডেড_length - 8
    mem_write_byte(padded_buffer, len_offset + 7, total_bit & 255)
    mem_write_byte(padded_buffer, len_offset + 6, (total_bit >> 8) & 255)
    mem_write_byte(padded_buffer, len_offset + 5, (total_bit >> 16) & 255)
    mem_write_byte(padded_buffer, len_offset + 4, (total_bit >> 24) & 255)
    mem_write_byte(padded_buffer, len_offset + 3, (total_bit >> 32) & 255)
    mem_write_byte(padded_buffer, len_offset + 2, (total_bit >> 40) & 255)
    mem_write_byte(padded_buffer, len_offset + 1, (total_bit >> 48) & 255)
    mem_write_byte(padded_buffer, len_offset + 0, (total_bit >> 56) & 255)

    // প্রাথমিa hash স্টেট (H0 .. H7)
    h0 = 0x6a09e667
    h1 = 0xbb67ae85
    h2 = 0x3c6ef372
    h3 = 0xa54ff53a
    h4 = 0x510e527f
    h5 = 0x9b05688c
    h6 = 0x1f83d9ab
    h7 = 0x5be0cd19

    // মেসেজ শিডিউল buffer W (৬৪টি ৩২-বিট word = ৫১২ byte)
    w_buffer = malloc(512)

    // each ৫১২-বিট (৬৪ byte) ব্লaে প্রসেসিং
    ব্লa_offset = 0
    while ব্লa_offset < প্যাডেড_length
        // ১. প্রথম ১৬টি word W[0..15] struct (Big-endian unpacking)
        t = 0
        while t < 16
            বো = ব্লa_offset + (t * 4)
            b0 = mem_byte_পড়ো(padded_buffer, বো)
            b1 = mem_byte_পড়ো(padded_buffer, বো + 1)
            b2 = mem_byte_পড়ো(padded_buffer, বো + 2)
            b3 = mem_byte_পড়ো(padded_buffer, বো + 3)
            শব্দ = (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
            mem_write(w_buffer, t * 8, শব্দ)
            t = t + 1

        // ২. W[16..63] শিডিউল এa্সপ্যানশন
        while t < 64
            w_t2 = mem_পড়ো(w_buffer, (t - 2) * 8)
            w_t7 = mem_পড়ো(w_buffer, (t - 7) * 8)
            w_t15 = mem_পড়ো(w_buffer, (t - 15) * 8)
            w_t16 = mem_পড়ো(w_buffer, (t - 16) * 8)

            s1 = sha256_gamma1(w_t2)
            s0 = sha256_gamma0(w_t15)
            w_নতুন = (s1 + w_t7 + s0 + w_t16) & 0xffffffff
            mem_write(w_buffer, t * 8, w_নতুন)
            t = t + 1

        // ৩. ওয়ার্aিং ভ্যারিয়েবল ইনিশিয়ালাইজেশন
        a = h0
        b = h1
        c = h2
        d = h3
        e = h4
        f = h5
        g = h6
        h = h7

        // ৪. ৬৪ রাউন্ড মিa্সিং ও less্প্রেশন
        t = 0
        while t < 64
            s1 = sha256_sigma1(e)
            ch = sha256_ch(e, f, g)
            kt = mem_পড়ো(aে_pool, t * 8)
            wt = mem_পড়ো(w_buffer, t * 8)
            temp1 = (h + s1 + ch + kt + wt) & 0xffffffff

            s0 = sha256_sigma0(a)
            maj = sha256_maj(a, b, c)
            temp2 = (s0 + maj) & 0xffffffff

            h = g
            g = f
            f = e
            e = (d + temp1) & 0xffffffff
            d = c
            c = b
            b = a
            a = (temp1 + temp2) & 0xffffffff

            t = t + 1

        // ৫. ইন্টারমিডিয়েট hash value আপডেট
        h0 = (h0 + a) & 0xffffffff
        h1 = (h1 + b) & 0xffffffff
        h2 = (h2 + c) & 0xffffffff
        h3 = (h3 + d) & 0xffffffff
        h4 = (h4 + e) & 0xffffffff
        h5 = (h5 + f) & 0xffffffff
        h6 = (h6 + g) & 0xffffffff
        h7 = (h7 + h) & 0xffffffff

        ব্লa_offset = ব্লa_offset + 64

    // ৬. ৬৪-a্যারেa্টার হেa্স ফরম্যাটিং (H0 .. H7)
    h_array = malloc(64)
    mem_write(h_array, 0, h0)
    mem_write(h_array, 8, h1)
    mem_write(h_array, 16, h2)
    mem_write(h_array, 24, h3)
    mem_write(h_array, 32, h4)
    mem_write(h_array, 40, h5)
    mem_write(h_array, 48, h6)
    mem_write(h_array, 56, h7)

    out_পজ = 0
    k = 0
    while k < 8
        val = mem_পড়ো(h_array, k * 8)
        nib = 7
        while nib >= 0
            shift = nib * 4
            ch = nibble_to_hex(val >> shift)
            mem_write_byte(output_buffer, out_পজ, ch)
            out_পজ = out_পজ + 1
            nib = nib - 1
        k = k + 1
    mem_write_byte(output_buffer, 64, 0) // Null terminator

    return output_buffer
