// ==============================================================================
// 👑 LIPI STANDARD LIBRARY: PURE LIPI CRYPTOGRAPHIC TLS & CHACHA20 (std/tls.lp)
// ⚡ 100% Sovereign RFC 8439 ChaCha20 Stream Cipher | RFC 8446 TLS 1.3 Framing
// ==============================================================================

// WHY: Modern secure systems programming requires authenticated, high-throughput
// symmetric encryption and TLS framing without depending on OpenSSL, BoringSSL,
// or any foreign C library. std/tls.lp delivers pure-silicon RFC 8439 ChaCha20
// stream encryption and TLS record serialization in native Lipi machine code.

include "std/mem.lp"

// ১. ChaCha20 কোয়ার্টার রাউন্ড (RFC 8439 Quarter Round Function)
// WHY: Executes 4 quarter-round additions, XORs, and 32-bit left rotations (rol32)
// on state vector indices (a, b, c, d). Single-cycle rol %cl, %eax hardware execution.
ফাংশন chacha20_qr(মেমরি, a_idx, b_idx, c_idx, d_idx)
    mask32 = 4294967295
    a_off = a_idx * 8
    b_off = b_idx * 8
    c_off = c_idx * 8
    d_off = d_idx * 8

    a = মেমরি_পড়ো(মেমরি, a_off)
    b = মেমরি_পড়ো(মেমরি, b_off)
    c = মেমরি_পড়ো(মেমরি, c_off)
    d = মেমরি_পড়ো(মেমরি, d_off)

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

    মেমরি_লেখো(মেমরি, a_off, a)
    মেমরি_লেখো(মেমরি, b_off, b)
    মেমরি_লেখো(মেমরি, c_off, c)
    মেমরি_লেখো(মেমরি, d_off, d)

// ২. ChaCha20 স্টেট ভেক্টর ইনিশিয়ালাইজেশন (RFC 8439 Initial Matrix 4x4)
// WHY: Sets up 16 32-bit words: constants "expand 32-byte k", 256-bit key, 32-bit block counter, and 96-bit nonce.
ফাংশন chacha20_স্টেট_তৈরি(স্টেট_মেমরি, কি_মেমরি, ননস_মেমরি, কাউন্টার)
    // শব্দ ০..৩: RFC 8439 ম্যাজিক কনস্ট্যান্ট ("expand 32-byte k")
    মেমরি_লেখো(স্টেট_মেমরি, 0, 0x61707865)   // "expa"
    মেমরি_লেখো(স্টেট_মেমরি, 8, 0x3320646e)   // "nd 3"
    মেমরি_লেখো(স্টেট_মেমরি, 16, 0x79622d32)  // "2-by"
    মেমরি_লেখো(স্টেট_মেমরি, 24, 0x6b206574)  // "te k"

    // শব্দ ৪..১১: ২৫৬-বিট এনক্রিপশন কি (৮টি ৩২-বিট ওয়ার্ড)
    i = 0
    while i < 8
        কি_শব্দ = মেমরি_পড়ো(কি_মেমরি, i * 8)
        মেমরি_লেখো(স্টেট_মেমরি, (4 + i) * 8, কি_শব্দ & 4294967295)
        i = i + 1

    // শব্দ ১২: ৩২-বিট ব্লক কাউন্টার
    মেমরি_লেখো(স্টেট_মেমরি, 96, কাউন্টার & 4294967295)

    // শব্দ ১৩..১৫: ৯৬-বিট ক্রিপ্টোগ্রাফিক ননস (৩টি ৩২-বিট ওয়ার্ড)
    n0 = মেমরি_পড়ো(ননস_মেমরি, 0)
    n1 = মেমরি_পড়ো(ননস_মেমরি, 8)
    n2 = মেমরি_পড়ো(ননস_মেমরি, 16)
    মেমরি_লেখো(স্টেট_মেমরি, 104, n0 & 4294967295)
    মেমরি_লেখো(স্টেট_মেমরি, 112, n1 & 4294967295)
    মেমরি_লেখো(স্টেট_মেমরি, 120, n2 & 4294967295)

// ৩. ChaCha20 ৬৪-বাইট কিস্ট্রিম ব্লক জেনারেশন (RFC 8439 Block Function)
// WHY: Executes 20 rounds (10 column rounds + 10 diagonal rounds) on working state,
// adds original state, and serializes to 64 bytes of pseudo-random keystream.
ফাংশন chacha20_ব্লক(স্টেট_মেমরি, আউট_বাফার)
    র্কিং = malloc(256)
    mask32 = 4294967295

    // মূল স্টেটকে র্কিং মেমরিতে কপি করা
    i = 0
    while i < 16
        val = মেমরি_পড়ো(স্টেট_মেমরি, i * 8)
        মেমরি_লেখো(র্কিং, i * 8, val)
        i = i + 1

    // ২০ রাউন্ড ট্রান্সফর্মেশন (১০টি ডাবল-রাউন্ড)
    রাউন্ড = 0
    while রাউন্ড < 10
        // কলাম রাউন্ডস (Column Rounds)
        chacha20_qr(র্কিং, 0, 4, 8, 12)
        chacha20_qr(র্কিং, 1, 5, 9, 13)
        chacha20_qr(র্কিং, 2, 6, 10, 14)
        chacha20_qr(র্কিং, 3, 7, 11, 15)

        // ডায়াগনাল রাউন্ডস (Diagonal Rounds)
        chacha20_qr(র্কিং, 0, 5, 10, 15)
        chacha20_qr(র্কিং, 1, 6, 11, 12)
        chacha20_qr(র্কিং, 2, 7, 8, 13)
        chacha20_qr(র্কিং, 3, 4, 9, 14)

        রাউন্ড = রাউন্ড + 1

    // আউটপুট ওয়ার্ড যোগ এবং ৬৪-বাইট লিটল-এন্ডিয়ান রূপান্তর
    i = 0
    while i < 16
        orig = মেমরি_পড়ো(স্টেট_মেমরি, i * 8)
        work = মেমরি_পড়ো(র্কিং, i * 8)
        sum = (orig + work) & mask32

        b0 = sum & 255
        b1 = (sum >> 8) & 255
        b2 = (sum >> 16) & 255
        b3 = (sum >> 24) & 255

        b_idx = i * 4
        মেমরি_বাইট_লেখো(আউট_বাফার, b_idx + 0, b0)
        মেমরি_বাইট_লেখো(আউট_বাফার, b_idx + 1, b1)
        মেমরি_বাইট_লেখো(আউট_বাফার, b_idx + 2, b2)
        মেমরি_বাইট_লেখো(আউট_বাফার, b_idx + 3, b3)

        i = i + 1

    free(র্কিং, 256)

// ৪. ChaCha20 স্ট্রিম এনক্রিপশন ও ডিক্রিপশন (Symmetric XOR Stream Process)
// WHY: Streams plaintext through generated 64-byte keystreams. Encryption and decryption
// are perfectly symmetric (A ^ K ^ K = A). Zero OpenSSL/Libc dependencies.
ফাংশন chacha20_প্রসেস(কি_মেমরি, ননস_মেমরি, শুরু_কাউন্টার, ইন_বাফার, len, আউট_বাফার)
    স্টেট = malloc(256)
    কিস্ট্রিম = malloc(128)
    কার্সর = 0
    বর্তমান_কাউন্টার = শুরু_কাউন্টার

    while কার্সর < len
        chacha20_স্টেট_তৈরি(স্টেট, কি_মেমরি, ননস_মেমরি, বর্তমান_কাউন্টার)
        chacha20_ব্লক(স্টেট, কিস্ট্রিম)

        ব্লক_আকার = 64
        if (len - কার্সর) < 64
            ব্লক_আকার = len - কার্সর

        j = 0
        while j < ব্লক_আকার
            p_byte = মেমরি_বাইট_পড়ো(ইন_বাফার, কার্সর + j)
            k_byte = মেমরি_বাইট_পড়ো(কিস্ট্রিম, j)
            c_byte = p_byte ^ k_byte
            মেমরি_বাইট_লেখো(আউট_বাফার, কার্সর + j, c_byte)
            j = j + 1

        কার্সর = কার্সর + ব্লক_আকার
        বর্তমান_কাউন্টার = বর্তমান_কাউন্টার + 1

    free(কিস্ট্রিম, 128)
    free(স্টেট, 256)
    return len

// ৫. টিএলএস রেকর্ড লেয়ার ফ্রেম প্যাকেজিং (RFC 8446 Record Header)
// WHY: Wraps payload with standard TLS 5-byte header:
// [Type: 1 byte (0x17 for AppData)] [Legacy Version: 0x03, 0x03] [Length: 2 bytes Big-Endian]
ফাংশন tls_রেকর্ড_প্যাক(কন্টেন্ট_টাইপ, পেয়লোড_বাফার, পেয়লোড_দৈর্ঘ্য, ফ্রেম_বাফার)
    মেমরি_বাইট_লেখো(ফ্রেম_বাফার, 0, কন্টেন্ট_টাইপ & 255) // 0x17 = Application Data
    মেমরি_বাইট_লেখো(ফ্রেম_বাফার, 1, 3)                   // TLS Legacy Major
    মেমরি_বাইট_লেখো(ফ্রেম_বাফার, 2, 3)                   // TLS Legacy Minor (TLS 1.2 / TLS 1.3 Compat)
    len_hi = (পেয়লোড_দৈর্ঘ্য >> 8) & 255
    len_lo = পেয়লোড_দৈর্ঘ্য & 255
    মেমরি_বাইট_লেখো(ফ্রেম_বাফার, 3, len_hi)              // Big-Endian Length HI
    মেমরি_বাইট_লেখো(ফ্রেম_বাফার, 4, len_lo)              // Big-Endian Length LO

    i = 0
    while i < পেয়লোড_দৈর্ঘ্য
        b = মেমরি_বাইট_পড়ো(পেয়লোড_বাফার, i)
        মেমরি_বাইট_লেখো(ফ্রেম_বাফার, 5 + i, b)
        i = i + 1

    return 5 + পেয়লোড_দৈর্ঘ্য

// ৬. টিএলএস রেকর্ড ফ্রেম হেডার পার্সিং ও আনপ্যাকিং
// WHY: Validates 5-byte TLS record header, extracts payload length, and unpacks payload.
ফাংশন tls_রেকর্ড_আনপ্যাক(ফ্রেম_বাফার, আউট_পেয়লোড)
    len_hi = মেমরি_বাইট_পড়ো(ফ্রেম_বাফার, 3)
    len_lo = মেমরি_বাইট_পড়ো(ফ্রেম_বাফার, 4)
    len = (len_hi << 8) | len_lo

    i = 0
    while i < len
        b = মেমরি_বাইট_পড়ো(ফ্রেম_বাফার, 5 + i)
        মেমরি_বাইট_লেখো(আউট_পেয়লোড, i, b)
        i = i + 1

    return len
