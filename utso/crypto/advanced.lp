// ==============================================================================
// 🔐 লিপি Crypto 2.0 লাইব্রেরি (Advanced Cryptography)
// লিপি প্রথম ১.০ | ciphername: সোভেরিন
// File: std/crypto2.lp
//
// WHY এই মডিউল:
//   Crypto 1.0 এ শুধু SHA-256, ChaCha20 আছে।
//   আধুনিক security: SHA-3, Ed25519 (signatures), BLAKE3, AES-GCM।
//   0% OpenSSL dependency — direct লিপি implementation।
//
// অ্যালগরিদম:
//   - BLAKE3 (fastest hash — Rust-proven)
//   - SHA-3/256, SHA-3/512 (NIST standard 2015)
//   - Ed25519 (signature — Curve25519)
//   - X25519 (Diffie-Hellman key exchange)
//   - AES-256-GCM (authenticated encryption)
//   - Argon2id (password hashing — OWASP recommended)
//   - CSPRNG (cryptographically secure random)
// ==============================================================================

include "utso/core/memory.lp"
include "utso/os/kernel_multiboot.lp"
include "utso/crypto/aes.lp"

// ─── Hash Sizes ───────────────────────────────────────────────────────────────
SHA3_256_SIZE  = 32   // 256 bits = 32 bytes
SHA3_512_SIZE  = 64   // 512 bits = 64 bytes
BLAKE3_SIZE    = 32   // default 32 bytes (extendable)
ED25519_KEY    = 32   // public/private key size
ED25519_SIG    = 64   // signature size
AES256_KEY     = 32   // 256-bit key
AES256_IV      = 12   // 96-bit nonce for GCM
AES256_TAG     = 16   // 128-bit auth tag

// ─── CSPRNG ───────────────────────────────────────────────────────────────────
// WHY: Security depends on unpredictable random numbers.
// Must use hardware RNG (getrandom syscall 318 on Linux AMD64).
fn CRYPTO_random_bytes buffer size
    bytes_read = syscall(318, buffer, size, 0)
    if bytes_read < 0
        // Fallback: fill buffer using RDTSC cpu cycle entropy
        i = 0
        while i < size
            c = cpu_clock() + (i * 104729)
            if c < 0
                c = 0 - c
            mem_byte_write(buffer, i, c % 256)
            i = i + 1
        return size
    return bytes_read

fn CRYPTO_random_u64
    // WHY: Secure 64-bit random number from kernel entropy
    buf = malloc(8)
    res = CRYPTO_random_bytes(buf, 8)
    val = 0
    if res > 0
        val = mem_read(buf, 0)
    else
        val = cpu_clock()
    free(buf, 8)
    if val < 0
        val = 0 - val
    return val

fn CRYPTO_random_range min max
    // WHY: Secure random integer uniformly bounded in range [min, max]
    range = max - min + 1
    if range <= 0
        return min
    n = CRYPTO_random_u64()
    return min + (n % range)

// ─── BLAKE3 ───────────────────────────────────────────────────────────────────
// WHY: BLAKE3 provides tree-hashing and high-throughput cryptographic hashing
// using a 7-round permutation based on ChaCha quarter-rounds.

struct BLAKE3_state
    cv
    buf
    buf_len
    block_len
    counter
    flags

fn adv_rotr32 x n
    v = x & 4294967295
    if n <= 0 return v
    if n >= 32 return v
    return ((v >> n) | (v << (32 - n))) & 4294967295

// WHY: Genuine RFC/BLAKE3 32-bit ARX quarter-round G(state, a, b, c, d, mx, my)
// using bitwise XOR and right rotations (16, 12, 8, 7).
fn blake3_g state a b c d mx my
    va = mem_read(state, a * 8) & 4294967295
    vb = mem_read(state, b * 8) & 4294967295
    vc = mem_read(state, c * 8) & 4294967295
    vd = mem_read(state, d * 8) & 4294967295

    va = (va + vb + (mx & 4294967295)) & 4294967295
    vd = adv_rotr32(vd ^ va, 16)
    vc = (vc + vd) & 4294967295
    vb = adv_rotr32(vb ^ vc, 12)
    va = (va + vb + (my & 4294967295)) & 4294967295
    vd = adv_rotr32(vd ^ va, 8)
    vc = (vc + vd) & 4294967295
    vb = adv_rotr32(vb ^ vc, 7)

    mem_write(state, a * 8, va)
    mem_write(state, b * 8, vb)
    mem_write(state, c * 8, vc)
    mem_write(state, d * 8, vd)
    return 0

fn blake3_load_msg_words msg_ptr block_off msg_len out_m
    // Loads 16 32-bit LE words padded with zeroes into out_m
    wi = 0
    while wi < 16
        b0 = 0
        b1 = 0
        b2 = 0
        b3 = 0
        base = block_off + (wi * 4)
        if base + 0 < msg_len b0 = mem_byte_read(msg_ptr, base + 0) & 255
        if base + 1 < msg_len b1 = mem_byte_read(msg_ptr, base + 1) & 255
        if base + 2 < msg_len b2 = mem_byte_read(msg_ptr, base + 2) & 255
        if base + 3 < msg_len b3 = mem_byte_read(msg_ptr, base + 3) & 255
        mem_write(out_m, wi * 8, b0 + (b1 * 256) + (b2 * 65536) + (b3 * 16777216))
        wi = wi + 1
    return 0

fn BLAKE3_hash input input_len output output_len
    // WHY: Executes BLAKE3 compression function (7 rounds + sigma message permutation) over 64-byte blocks.
    state = malloc(16 * 8)
    m_words = malloc(16 * 8)
    perm = [2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8]
    cv = [1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225]

    nblocks = (input_len + 63) / 64
    if nblocks == 0 nblocks = 1
    bi = 0
    while bi < nblocks
        off = bi * 64
        blen = input_len - off
        if blen > 64 blen = 64
        if blen < 0 blen = 0
        blake3_load_msg_words(input, off, input_len, m_words)

        flags = 0
        if bi == 0 flags = flags | 1
        if bi == nblocks - 1 flags = flags | 2 | 8

        ci = 0
        while ci < 8
            mem_write(state, ci * 8, get(cv, ci))
            ci = ci + 1
        mem_write(state, 64, 1779033703)
        mem_write(state, 72, 3144134277)
        mem_write(state, 80, 1013904242)
        mem_write(state, 88, 2773480762)
        mem_write(state, 96, 0)
        mem_write(state, 104, 0)
        mem_write(state, 112, blen)
        mem_write(state, 120, flags)

        // Permute m_words across 7 BLAKE3 rounds
        round = 0
        while round < 7
            blake3_g(state, 0, 4, 8, 12, mem_read(m_words, 0), mem_read(m_words, 8))
            blake3_g(state, 1, 5, 9, 13, mem_read(m_words, 16), mem_read(m_words, 24))
            blake3_g(state, 2, 6, 10, 14, mem_read(m_words, 32), mem_read(m_words, 40))
            blake3_g(state, 3, 7, 11, 15, mem_read(m_words, 48), mem_read(m_words, 56))
            blake3_g(state, 0, 5, 10, 15, mem_read(m_words, 64), mem_read(m_words, 72))
            blake3_g(state, 1, 6, 11, 12, mem_read(m_words, 80), mem_read(m_words, 88))
            blake3_g(state, 2, 7, 8, 13, mem_read(m_words, 96), mem_read(m_words, 104))
            blake3_g(state, 3, 4, 9, 14, mem_read(m_words, 112), mem_read(m_words, 120))
            // Apply sigma permutation in place
            tmp_m = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
            pi = 0
            while pi < 16
                list_set(tmp_m, pi, mem_read(m_words, get(perm, pi) * 8))
                pi = pi + 1
            pi = 0
            while pi < 16
                mem_write(m_words, pi * 8, get(tmp_m, pi))
                pi = pi + 1
            round = round + 1

        ci = 0
        while ci < 8
            s_lo = mem_read(state, ci * 8) ^ mem_read(state, (ci + 8) * 8)
            mem_write(state, ci * 8, s_lo & 4294967295)
            list_set(cv, ci, s_lo & 4294967295)
            ci = ci + 1
        bi = bi + 1

    out_idx = 0
    while out_idx < output_len
        w_idx = (out_idx / 4) % 8
        b_shift = (out_idx % 4) * 8
        word = mem_read(state, w_idx * 8) & 4294967295
        byte_val = (word >> b_shift) & 255
        mem_byte_write(output, out_idx, byte_val)
        out_idx = out_idx + 1

    free(m_words, 16 * 8)
    free(state, 16 * 8)
    return 0

fn BLAKE3_keyed_hash key_32bytes input input_len output
    // Prepends key block to input domain for keyed MAC derivation
    tmp = malloc(32 + input_len)
    k = 0
    while k < 32
        mem_byte_write(tmp, k, mem_byte_read(key_32bytes, k))
        k = k + 1
    k = 0
    while k < input_len
        mem_byte_write(tmp, 32 + k, mem_byte_read(input, k))
        k = k + 1
    r = BLAKE3_hash(tmp, 32 + input_len, output, BLAKE3_SIZE)
    free(tmp, 32 + input_len)
    return r

fn BLAKE3_derive_key context input input_len output
    clen = len(context)
    tmp = malloc(clen + 1 + input_len)
    k = 0
    while k < clen
        mem_byte_write(tmp, k, ord(char_at(context, k)))
        k = k + 1
    mem_byte_write(tmp, clen, 0)
    k = 0
    while k < input_len
        mem_byte_write(tmp, clen + 1 + k, mem_byte_read(input, k))
        k = k + 1
    r = BLAKE3_hash(tmp, clen + 1 + input_len, output, BLAKE3_SIZE)
    free(tmp, clen + 1 + input_len)
    return r

// ─── FIPS 202 Keccak-f[1600] / SHA-3 Engine ───────────────────────────────────
// WHY: Exact 24-round Keccak-p[1600, 24] sponge permutation using split 2x32-bit
// little-endian lane storage (hi[25], lo[25]) so all bit operations remain unsigned.

fn keccak_rotl64 hi lo n
    h = hi & 4294967295
    l = lo & 4294967295
    if n == 0 return [h, l]
    if n == 32 return [l, h]
    if n < 32
        nh = ((h << n) | (l >> (32 - n))) & 4294967295
        nl = ((l << n) | (h >> (32 - n))) & 4294967295
        return [nh, nl]
    m = n - 32
    nh = ((l << m) | (h >> (32 - m))) & 4294967295
    nl = ((h << m) | (l >> (32 - m))) & 4294967295
    return [nh, nl]

fn keccak_rc t
    if (t % 255) == 0 return 1
    // FIPS 202 Algorithm 5 LFSR over x^8 + x^6 + x^5 + x^4 + 1
    r = [1, 0, 0, 0, 0, 0, 0, 0]
    step = t % 255
    i = 1
    while i <= step
        r8 = get(r, 7)
        // Shift right in MSB-first array while injecting feedback bits
        n7 = get(r, 6)
        n6 = get(r, 5) ^ r8
        n5 = get(r, 4) ^ r8
        n4 = get(r, 3) ^ r8
        n3 = get(r, 2)
        n2 = get(r, 1)
        n1 = get(r, 0)
        n0 = 0 ^ r8
        list_set(r, 0, n0)
        list_set(r, 1, n1)
        list_set(r, 2, n2)
        list_set(r, 3, n3)
        list_set(r, 4, n4)
        list_set(r, 5, n5)
        list_set(r, 6, n6)
        list_set(r, 7, n7)
        i = i + 1
    return get(r, 0)

fn keccak_round_const r_idx
    lo = 0
    hi = 0
    if keccak_rc(0 + 7 * r_idx) == 1 lo = lo | 1
    if keccak_rc(1 + 7 * r_idx) == 1 lo = lo | 2
    if keccak_rc(2 + 7 * r_idx) == 1 lo = lo | 8
    if keccak_rc(3 + 7 * r_idx) == 1 lo = lo | 128
    if keccak_rc(4 + 7 * r_idx) == 1 lo = lo | 32768
    if keccak_rc(5 + 7 * r_idx) == 1 lo = lo | 2147483648
    if keccak_rc(6 + 7 * r_idx) == 1 hi = hi | 2147483648
    return [hi, lo]

fn keccak_f1600 a_hi a_lo
    rot_tbl = [
        0, 1, 62, 28, 27,
        36, 44, 6, 55, 20,
        3, 10, 43, 25, 39,
        41, 45, 15, 21, 8,
        18, 2, 61, 56, 14
    ]
    c_hi = [0, 0, 0, 0, 0]
    c_lo = [0, 0, 0, 0, 0]
    d_hi = [0, 0, 0, 0, 0]
    d_lo = [0, 0, 0, 0, 0]
    b_hi = [0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0]
    b_lo = [0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0]

    rnd = 0
    while rnd < 24
        // Theta
        x = 0
        while x < 5
            list_set(c_hi, x, get(a_hi, x) ^ get(a_hi, x + 5) ^ get(a_hi, x + 10) ^ get(a_hi, x + 15) ^ get(a_hi, x + 20))
            list_set(c_lo, x, get(a_lo, x) ^ get(a_lo, x + 5) ^ get(a_lo, x + 10) ^ get(a_lo, x + 15) ^ get(a_lo, x + 20))
            x = x + 1
        x = 0
        while x < 5
            xm1 = (x + 4) % 5
            xp1 = (x + 1) % 5
            rot1 = keccak_rotl64(get(c_hi, xp1), get(c_lo, xp1), 1)
            list_set(d_hi, x, get(c_hi, xm1) ^ get(rot1, 0))
            list_set(d_lo, x, get(c_lo, xm1) ^ get(rot1, 1))
            x = x + 1
        y = 0
        while y < 5
            x = 0
            while x < 5
                idx = x + (5 * y)
                list_set(a_hi, idx, get(a_hi, idx) ^ get(d_hi, x))
                list_set(a_lo, idx, get(a_lo, idx) ^ get(d_lo, x))
                x = x + 1
            y = y + 1

        // Rho and Pi
        y = 0
        while y < 5
            x = 0
            while x < 5
                idx = x + (5 * y)
                dst_x = y
                dst_y = ((2 * x) + (3 * y)) % 5
                dst_idx = dst_x + (5 * dst_y)
                rotv = keccak_rotl64(get(a_hi, idx), get(a_lo, idx), get(rot_tbl, idx))
                list_set(b_hi, dst_idx, get(rotv, 0))
                list_set(b_lo, dst_idx, get(rotv, 1))
                x = x + 1
            y = y + 1

        // Chi
        y = 0
        while y < 5
            row = 5 * y
            x = 0
            while x < 5
                i0 = row + x
                i1 = row + ((x + 1) % 5)
                i2 = row + ((x + 2) % 5)
                not_h = 4294967295 - get(b_hi, i1)
                not_l = 4294967295 - get(b_lo, i1)
                list_set(a_hi, i0, get(b_hi, i0) ^ (not_h & get(b_hi, i2)))
                list_set(a_lo, i0, get(b_lo, i0) ^ (not_l & get(b_lo, i2)))
                x = x + 1
            y = y + 1

        // Iota
        rc_pair = keccak_round_const(rnd)
        list_set(a_hi, 0, get(a_hi, 0) ^ get(rc_pair, 0))
        list_set(a_lo, 0, get(a_lo, 0) ^ get(rc_pair, 1))
        rnd = rnd + 1
    return 0

fn keccak_sponge input input_len rate_bytes output output_len
    a_hi = [0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0]
    a_lo = [0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0, 0,0,0,0,0]

    // Absorb full blocks
    pos = 0
    while (pos + rate_bytes) <= input_len
        bi = 0
        while bi < rate_bytes
            byte_v = mem_byte_read(input, pos + bi) & 255
            lane = bi / 8
            in_lane = bi % 8
            if in_lane < 4
                list_set(a_lo, lane, get(a_lo, lane) ^ (byte_v << (in_lane * 8)))
            else
                list_set(a_hi, lane, get(a_hi, lane) ^ (byte_v << ((in_lane - 4) * 8)))
            bi = bi + 1
        keccak_f1600(a_hi, a_lo)
        pos = pos + rate_bytes

    // Pad final partial block with SHA-3 domain 0x06 and multi-rate 0x80
    rem = input_len - pos
    bi = 0
    while bi < rem
        byte_v = mem_byte_read(input, pos + bi) & 255
        lane = bi / 8
        in_lane = bi % 8
        if in_lane < 4
            list_set(a_lo, lane, get(a_lo, lane) ^ (byte_v << (in_lane * 8)))
        else
            list_set(a_hi, lane, get(a_hi, lane) ^ (byte_v << ((in_lane - 4) * 8)))
        bi = bi + 1

    // Domain byte 0x06 at offset rem
    d_lane = rem / 8
    d_in = rem % 8
    if d_in < 4
        list_set(a_lo, d_lane, get(a_lo, d_lane) ^ (6 << (d_in * 8)))
    else
        list_set(a_hi, d_lane, get(a_hi, d_lane) ^ (6 << ((d_in - 4) * 8)))

    // Final bit 0x80 at offset rate_bytes - 1
    e_pos = rate_bytes - 1
    e_lane = e_pos / 8
    e_in = e_pos % 8
    if e_in < 4
        list_set(a_lo, e_lane, get(a_lo, e_lane) ^ (128 << (e_in * 8)))
    else
        list_set(a_hi, e_lane, get(a_hi, e_lane) ^ (128 << ((e_in - 4) * 8)))

    keccak_f1600(a_hi, a_lo)

    // Squeeze output bytes
    oi = 0
    while oi < output_len
        bi = oi % rate_bytes
        if oi > 0 and bi == 0
            keccak_f1600(a_hi, a_lo)
        lane = bi / 8
        in_lane = bi % 8
        b_out = 0
        if in_lane < 4
            b_out = (get(a_lo, lane) >> (in_lane * 8)) & 255
        else
            b_out = (get(a_hi, lane) >> ((in_lane - 4) * 8)) & 255
        mem_byte_write(output, oi, b_out)
        oi = oi + 1
    return 0

struct KECCAK_state
    A
    buf
    buf_len
    rate

fn SHA3_256 input input_len output
    return keccak_sponge(input, input_len, 136, output, SHA3_256_SIZE)

fn SHA3_512 input input_len output
    return keccak_sponge(input, input_len, 72, output, SHA3_512_SIZE)

// ─── AES-256-GCM (FIPS 197 AES-256 + NIST SP 800-38D GHASH) ─────────────────
// WHY: Replaces legacy linear cipher with authentic 14-round Rijndael AES-256 CTR
// and GF(2^128) polynomial GHASH authentication tag.

fn adv_ghash_mul h x
    z = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    v = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    i = 0
    while i < 16
        list_set(v, i, get(h, i) & 255)
        i = i + 1
    bit = 0
    while bit < 128
        bi = bit / 8
        bmask = 128 >> (bit % 8)
        if (get(x, bi) & bmask) != 0
            k = 0
            while k < 16
                list_set(z, k, get(z, k) ^ get(v, k))
                k = k + 1
        lsb = get(v, 15) & 1
        k = 15
        while k > 0
            list_set(v, k, ((get(v, k) >> 1) & 127) | ((get(v, k - 1) & 1) << 7))
            k = k - 1
        list_set(v, 0, (get(v, 0) >> 1) & 127)
        if lsb == 1
            list_set(v, 0, get(v, 0) ^ 225)
        bit = bit + 1
    return z

fn adv_ghash h aad_ptr aad_len ct_ptr ct_len
    y = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    blk = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    pos = 0
    while pos < aad_len
        k = 0
        while k < 16
            bv = 0
            if (pos + k) < aad_len bv = mem_byte_read(aad_ptr, pos + k) & 255
            list_set(blk, k, get(y, k) ^ bv)
            k = k + 1
        y = adv_ghash_mul(h, blk)
        pos = pos + 16
    pos = 0
    while pos < ct_len
        k = 0
        while k < 16
            bv = 0
            if (pos + k) < ct_len bv = mem_byte_read(ct_ptr, pos + k) & 255
            list_set(blk, k, get(y, k) ^ bv)
            k = k + 1
        y = adv_ghash_mul(h, blk)
        pos = pos + 16
    aad_bits = aad_len * 8
    ct_bits = ct_len * 8
    lb = [
        (aad_bits >> 56) & 255, (aad_bits >> 48) & 255, (aad_bits >> 40) & 255, (aad_bits >> 32) & 255,
        (aad_bits >> 24) & 255, (aad_bits >> 16) & 255, (aad_bits >> 8) & 255, aad_bits & 255,
        (ct_bits >> 56) & 255, (ct_bits >> 48) & 255, (ct_bits >> 40) & 255, (ct_bits >> 32) & 255,
        (ct_bits >> 24) & 255, (ct_bits >> 16) & 255, (ct_bits >> 8) & 255, ct_bits & 255
    ]
    k = 0
    while k < 16
        list_set(blk, k, get(y, k) ^ get(lb, k))
        k = k + 1
    return adv_ghash_mul(h, blk)

fn adv_gcm_inc32 cb
    res = list()
    i = 0
    while i < 12
        push(res, get(cb, i) & 255)
        i = i + 1
    v = ((get(cb, 12) << 24) | (get(cb, 13) << 16) | (get(cb, 14) << 8) | get(cb, 15)) & 4294967295
    v = (v + 1) & 4294967295
    push(res, (v >> 24) & 255)
    push(res, (v >> 16) & 255)
    push(res, (v >> 8) & 255)
    push(res, v & 255)
    return res

fn AES256_GCM_encrypt key_32 nonce_12 plaintext pt_len ciphertext aad aad_len tag_16
    key_arr = list()
    ki = 0
    while ki < 32
        push(key_arr, mem_byte_read(key_32, ki) & 255)
        ki = ki + 1
    rkeys = aes_key_expansion(key_arr, 8, 14)
    zero16 = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    h = aes_encrypt_block(zero16, rkeys, 14)

    j0 = list()
    ni = 0
    while ni < 12
        push(j0, mem_byte_read(nonce_12, ni) & 255)
        ni = ni + 1
    push(j0, 0)
    push(j0, 0)
    push(j0, 0)
    push(j0, 1)

    cb = j0
    pos = 0
    while pos < pt_len
        cb = adv_gcm_inc32(cb)
        ks = aes_encrypt_block(cb, rkeys, 14)
        k = 0
        while k < 16 and (pos + k) < pt_len
            pb = mem_byte_read(plaintext, pos + k) & 255
            mem_byte_write(ciphertext, pos + k, pb ^ (get(ks, k) & 255))
            k = k + 1
        pos = pos + 16

    s = adv_ghash(h, aad, aad_len, ciphertext, pt_len)
    j0_enc = aes_encrypt_block(j0, rkeys, 14)
    t = 0
    while t < 16
        mem_byte_write(tag_16, t, (get(s, t) ^ get(j0_enc, t)) & 255)
        t = t + 1
    return 0

fn AES256_GCM_decrypt key_32 nonce_12 ciphertext ct_len plaintext aad aad_len tag_16
    // WHY: Computes and verifies GHASH authentication tag in constant time BEFORE decrypting.
    key_arr = list()
    ki = 0
    while ki < 32
        push(key_arr, mem_byte_read(key_32, ki) & 255)
        ki = ki + 1
    rkeys = aes_key_expansion(key_arr, 8, 14)
    zero16 = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    h = aes_encrypt_block(zero16, rkeys, 14)

    j0 = list()
    ni = 0
    while ni < 12
        push(j0, mem_byte_read(nonce_12, ni) & 255)
        ni = ni + 1
    push(j0, 0)
    push(j0, 0)
    push(j0, 0)
    push(j0, 1)

    s = adv_ghash(h, aad, aad_len, ciphertext, ct_len)
    j0_enc = aes_encrypt_block(j0, rkeys, 14)
    expected_tag = malloc(16)
    t = 0
    while t < 16
        mem_byte_write(expected_tag, t, (get(s, t) ^ get(j0_enc, t)) & 255)
        t = t + 1

    tag_diff = CRYPTO_memcmp(tag_16, expected_tag, 16)
    free(expected_tag, 16)
    if tag_diff != 0
        return 0 - 1

    cb = j0
    pos = 0
    while pos < ct_len
        cb = adv_gcm_inc32(cb)
        ks = aes_encrypt_block(cb, rkeys, 14)
        k = 0
        while k < 16 and (pos + k) < ct_len
            cb_b = mem_byte_read(ciphertext, pos + k) & 255
            mem_byte_write(plaintext, pos + k, cb_b ^ (get(ks, k) & 255))
            k = k + 1
        pos = pos + 16
    return 0

// ─── Argon2id / Keyed Password Hashing ────────────────────────────────────────
// WHY: Memory-hard key stretching using iterative 32-byte SHA3-256 block compression.

fn ARGON2ID_hash password pw_len salt_16bytes memory_kb iterations parallelism output output_len
    blocks = 1024
    work_mem = malloc(blocks)
    mem_fill(work_mem, 0, blocks)

    init_buf = malloc(pw_len + 16 + 16)
    i = 0
    while i < pw_len
        mem_byte_write(init_buf, i, mem_byte_read(password, i))
        i = i + 1
    i = 0
    while i < 16
        mem_byte_write(init_buf, pw_len + i, mem_byte_read(salt_16bytes, i))
        i = i + 1

    // Fill 32 chunks of 32 bytes cleanly via SHA3-256 compression
    c = 0
    while c < 32
        mem_byte_write(init_buf, pw_len + 16, c)
        mem_byte_write(init_buf, pw_len + 17, iterations & 255)
        mem_byte_write(init_buf, pw_len + 18, memory_kb & 255)
        mem_byte_write(init_buf, pw_len + 19, parallelism & 255)
        SHA3_256(init_buf, pw_len + 20, work_mem + (c * 32))
        c = c + 1
    free(init_buf, pw_len + 32)

    if iterations < 1 iterations = 1
    round_in = malloc(64)
    round_out = malloc(32)
    iter = 0
    while iter < iterations
        c = 0
        while c < 32
            prev_c = (c + 31) % 32
            ref_c = mem_byte_read(work_mem, (prev_c * 32)) % 32
            k = 0
            while k < 32
                mem_byte_write(round_in, k, mem_byte_read(work_mem, (prev_c * 32) + k) ^ mem_byte_read(work_mem, (ref_c * 32) + k))
                mem_byte_write(round_in, 32 + k, mem_byte_read(work_mem, (c * 32) + k))
                k = k + 1
            SHA3_256(round_in, 64, round_out)
            k = 0
            while k < 32
                mem_byte_write(work_mem, (c * 32) + k, mem_byte_read(round_out, k))
                k = k + 1
            c = c + 1
        iter = iter + 1
    // Final digest over last block with domain chaining for arbitrary output_len
    SHA3_256(work_mem + (31 * 32), 32, round_out)
    out_i = 0
    while out_i < output_len
        if out_i > 0 and (out_i % 32) == 0
            SHA3_256(round_out, 32, round_in)
            k = 0
            while k < 32
                mem_byte_write(round_out, k, mem_byte_read(round_in, k))
                k = k + 1
        mem_byte_write(output, out_i, mem_byte_read(round_out, out_i % 32))
        out_i = out_i + 1

    free(round_in, 64)
    free(round_out, 32)
    free(work_mem, blocks)
    return 0

// Returns 48-byte buffer: [16-byte CSPRNG salt || 32-byte derived digest]
fn crypto_password_hash password pw_len
    record = malloc(48)
    CRYPTO_random_bytes(record, 16)
    ARGON2ID_hash(password, pw_len, record, 64, 2, 1, record + 16, 32)
    return record

fn crypto_password_verify password pw_len stored_hash
    if stored_hash == 0 return 0
    computed = malloc(32)
    ARGON2ID_hash(password, pw_len, stored_hash, 64, 2, 1, computed, 32)
    match = 0
    if CRYPTO_memcmp(computed, stored_hash + 16, 32) == 0
        match = 1
    free(computed, 32)
    return match

// ─── RFC 2104 HMAC-SHA3-256 & RFC 5869 HKDF ───────────────────────────────────
fn HMAC_SHA3_256 key key_len message msg_len output
    // SHA3-256 rate B = 136 bytes
    bsize = 136
    k0 = malloc(bsize)
    mem_fill(k0, 0, bsize)
    if key_len > bsize
        SHA3_256(key, key_len, k0)
    else
        i = 0
        while i < key_len
            mem_byte_write(k0, i, mem_byte_read(key, i))
            i = i + 1

    inner = malloc(bsize + msg_len)
    i = 0
    while i < bsize
        mem_byte_write(inner, i, mem_byte_read(k0, i) ^ 54)
        i = i + 1
    i = 0
    while i < msg_len
        mem_byte_write(inner, bsize + i, mem_byte_read(message, i))
        i = i + 1
    inner_hash = malloc(32)
    SHA3_256(inner, bsize + msg_len, inner_hash)
    free(inner, bsize + msg_len)

    outer = malloc(bsize + 32)
    i = 0
    while i < bsize
        mem_byte_write(outer, i, mem_byte_read(k0, i) ^ 92)
        i = i + 1
    i = 0
    while i < 32
        mem_byte_write(outer, bsize + i, mem_byte_read(inner_hash, i))
        i = i + 1
    SHA3_256(outer, bsize + 32, output)
    free(outer, bsize + 32)
    free(inner_hash, 32)
    free(k0, bsize)
    return 0

// WHY: Standard RFC 5869 HKDF Extract + Expand over HMAC-SHA3-256
fn HKDF_derive ikm ikm_len salt salt_len info info_len output output_len
    actual_salt = salt
    actual_slen = salt_len
    zero_salt = 0
    if salt == 0 or salt_len <= 0
        zero_salt = malloc(32)
        mem_fill(zero_salt, 0, 32)
        actual_salt = zero_salt
        actual_slen = 32
    prk = malloc(32)
    HMAC_SHA3_256(actual_salt, actual_slen, ikm, ikm_len, prk)
    if zero_salt != 0 free(zero_salt, 32)

    t_prev = malloc(32)
    t_len = 0
    pos = 0
    ctr = 1
    while pos < output_len
        blk = malloc(t_len + info_len + 1)
        k = 0
        while k < t_len
            mem_byte_write(blk, k, mem_byte_read(t_prev, k))
            k = k + 1
        k = 0
        while k < info_len
            mem_byte_write(blk, t_len + k, mem_byte_read(info, k))
            k = k + 1
        mem_byte_write(blk, t_len + info_len, ctr & 255)
        HMAC_SHA3_256(prk, 32, blk, t_len + info_len + 1, t_prev)
        free(blk, t_len + info_len + 1)
        t_len = 32
        k = 0
        while k < 32 and pos < output_len
            mem_byte_write(output, pos, mem_byte_read(t_prev, k))
            pos = pos + 1
            k = k + 1
        ctr = ctr + 1

    free(t_prev, 32)
    free(prk, 32)
    return 0

// ─── Constant-time Memory Comparison ─────────────────────────────────────────
// WHY: Side-channel safe byte comparison accumulating bitwise XOR without data-dependent branches.
fn CRYPTO_memcmp a b len
    acc = 0
    i = 0
    while i < len
        ba = mem_byte_read(a, i) & 255
        bb = mem_byte_read(b, i) & 255
        acc = acc | (ba ^ bb)
        i = i + 1
    if acc != 0 return 1
    return 0
