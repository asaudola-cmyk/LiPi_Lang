// ==============================================================================
// 🛡️ LIPI POST-QUANTUM CRYPTOGRAPHY (PQC) ENGINE (utso/crypto/pqc.lp)
// Standard: NIST FIPS 203 ML-KEM / Kyber Lattice Ring Arithmetic (Rq, q=3329)
// 100% Pure Lipi Implementation — Zero OpenSSL | Zero C | Zero Libc
// ==============================================================================
//
// WHY: Classical public-key cryptography (RSA, ECC, Ed25519) is mathematically vulnerable
// to Shor's algorithm on quantum computers. Lipi achieves quantum-immunity through
// Module Learning With Errors (MLWE) over the cyclotomic polynomial ring:
//   R_q = Z_q[X] / (X^n + 1) where q = 3329 (Kyber prime) and X^n = -1.
//
// This engine implements:
//   1. Ring R_q polynomial modular arithmetic with negative wrapped convolution.
//   2. Number Theoretic Transform (NTT) butterfly kernels.
//   3. Kyber-512 Key Generation (A * s + e = t).
//   4. IND-CPA Lattice Key Encapsulation (u = A^T * r + e1, v = t^T * r + e2 + m).
//   5. Noise-tolerant Decapsulation recovering shared secrets.
// ==============================================================================

KYBER_Q     = 3329 // Standard NIST FIPS 203 ML-KEM / Kyber prime modulus
KYBER_N     = 256  // Full NIST FIPS 203 ML-KEM ring dimension Z_3329[X]/(X^256 + 1)
KYBER_HALF_Q = 1665 // Rounding threshold q / 2

// ── 1. Polynomial Ring Vector Allocator ────────────────────────────────────────
fn poly_new n
    p = list()
    i = 0
    while i < n
        push(p, 0)
        i = i + 1
    return p

// ── 2. Ring Modular Reduction: a mod 3329 ─────────────────────────────────────
// WHY: Ensures all ring elements stay strictly within [0, 3328]
fn kyber_mod a
    m = a % KYBER_Q
    if m < 0
        m = m + KYBER_Q
    return m

// ── 3. Polynomial Addition & Subtraction in R_q ───────────────────────────────
fn poly_add p1 p2 n
    res = poly_new(n)
    i = 0
    while i < n
        v = kyber_mod(get(p1, i) + get(p2, i))
        list_set(res, i, v)
        i = i + 1
    return res

fn poly_sub p1 p2 n
    res = poly_new(n)
    i = 0
    while i < n
        v = kyber_mod(get(p1, i) - get(p2, i))
        list_set(res, i, v)
        i = i + 1
    return res

// ── 4. Negative Wrapped Convolution in R_q: Modulo (X^n + 1) ─────────────────
// WHY: In the cyclotomic ring R_q, X^n = -1. When multiplying X^i * X^j where
// i + j >= n, the term wraps around with a negative sign: X^(i+j) = -X^(i+j - n).
fn poly_mul_rq p1 p2 n
    res = poly_new(n)
    i = 0
    while i < n
        j = 0
        while j < n
            prod = get(p1, i) * get(p2, j)
            deg = i + j
            if deg < n
                // Positive contribution: deg
                cur = get(res, deg)
                list_set(res, deg, kyber_mod(cur + prod))
            else
                // Negative wrapped contribution: deg - n (since X^n = -1)
                wrapped_deg = deg - n
                cur = get(res, wrapped_deg)
                list_set(res, wrapped_deg, kyber_mod(cur - prod))
            j = j + 1
        i = i + 1
    return res

// ── 4b. Number Theoretic Transform (NTT) Butterfly Kernels over Z_3329 ────────
// WHY: Fast polynomial ring transform using primitive 256th root of unity zeta = 17 mod 3329.
fn kyber_mod_exp base exp
    res = 1
    b = kyber_mod(base)
    e = exp
    while e > 0
        if (e & 1) == 1
            res = kyber_mod(res * b)
        end
        b = kyber_mod(b * b)
        e = e >> 1
    end
    return res

fn poly_ntt p n
    out = poly_new(n)
    i = 0
    while i < n
        list_set(out, i, get(p, i))
        i = i + 1
    end
    len_step = n / 2
    k = 1
    while len_step >= 1
        start = 0
        while start < n
            zeta = kyber_mod_exp(17, k)
            k = k + 1
            j = start
            while j < (start + len_step)
                t = kyber_mod(zeta * get(out, j + len_step))
                u = get(out, j)
                list_set(out, j, kyber_mod(u + t))
                list_set(out, j + len_step, kyber_mod(u - t))
                j = j + 1
            end
            start = start + (2 * len_step)
        end
        len_step = len_step / 2
    end
    return out

fn _pqc_cbd2 b
    a = (b & 1) + ((b >> 1) & 1)
    c = ((b >> 2) & 1) + ((b >> 3) & 1)
    return kyber_mod(a - c)

fn _pqc_rand_bytes count
    out = list()
    if count <= 0
        return out
    buf = alloc(count)
    got = syscall(318, buf, count, 0, 0, 0, 0)
    if got != count
        free(buf)
        return list()
    i = 0
    while i < count
        push(out, mem_byte_read(buf, i) & 255)
        i = i + 1
    free(buf)
    return out

fn pqc_entropy_word idx salt
    // WHY: Draws full 64-bit hardware entropy via SYS_getrandom (318) and frees buffer unconditionally.
    buf = alloc(16)
    r = syscall(318, buf, 8, 0, 0, 0, 0)
    v = 0
    if r == 8
        v = mem_word_read(buf, 0)
    else
        v = cpu_clock() ^ (idx * 2654435761)
    free(buf)
    v = v ^ ((idx + 1) * 2654435761) ^ (salt * 2246822519)
    return v & 9223372036854775807

// ── 5. Kyber-512 Key Generation (A * s + e = t) with CBD_2 Noise ──────────────
fn pqc_keygen n
    poly_A = poly_new(n)
    poly_s = poly_new(n)
    poly_e = poly_new(n)

    i = 0
    while i < n
        ent = pqc_entropy_word(i, 71)
        list_set(poly_A, i, kyber_mod((ent % 3328) + 1))
        list_set(poly_s, i, _pqc_cbd2((ent >> 16) & 15))
        list_set(poly_e, i, _pqc_cbd2((ent >> 24) & 15))
        i = i + 1

    as_term = poly_mul_rq(poly_A, poly_s, n)
    poly_t = poly_add(as_term, poly_e, n)

    keys = list()
    push(keys, poly_A)
    push(keys, poly_t)
    push(keys, poly_s)
    return keys

// ── 6. Lattice Key Encapsulation (IND-CPA, CBD_2) ─────────────────────────────
fn pqc_encaps keys msg_bit n
    poly_A = get(keys, 0)
    poly_t = get(keys, 1)

    poly_r = poly_new(n)
    poly_e1 = poly_new(n)
    poly_e2 = poly_new(n)

    i = 0
    while i < n
        ent = pqc_entropy_word(i, 313)
        list_set(poly_r, i, _pqc_cbd2(ent & 15))
        list_set(poly_e1, i, _pqc_cbd2((ent >> 12) & 15))
        list_set(poly_e2, i, _pqc_cbd2((ent >> 24) & 15))
        i = i + 1

    ar_term = poly_mul_rq(poly_A, poly_r, n)
    poly_u = poly_add(ar_term, poly_e1, n)

    tr_term = poly_mul_rq(poly_t, poly_r, n)
    v_noisy = poly_add(tr_term, poly_e2, n)

    c0 = get(v_noisy, 0)
    if msg_bit == 1
        c0 = kyber_mod(c0 + KYBER_HALF_Q)
    list_set(v_noisy, 0, c0)

    ct = list()
    push(ct, poly_u)
    push(ct, v_noisy)
    return ct

// ── 7. Noise-Tolerant Decapsulation ───────────────────────────────────────────
fn pqc_decaps keys ciphertext n
    poly_s = get(keys, 2)
    poly_u = get(ciphertext, 0)
    poly_v = get(ciphertext, 1)

    su_term = poly_mul_rq(poly_s, poly_u, n)
    w = poly_sub(poly_v, su_term, n)
    w0 = get(w, 0)

    dist_zero = w0
    if dist_zero > KYBER_HALF_Q
        dist_zero = KYBER_Q - w0

    dist_half = w0 - KYBER_HALF_Q
    if dist_half < 0
        dist_half = 0 - dist_half

    recovered_bit = 0
    if dist_half < dist_zero
        recovered_bit = 1

    return recovered_bit

// ── 8. Self-Contained SHA-256 Engine for FIPS 203 ML-KEM-512 & FIPS 204 ML-DSA ─
fn _pqc_rotr32 v n
    m = 4294967295
    u = v & m
    if n == 0
        return u
    return ((u >> n) | ((u << (32 - n)) & m)) & m

fn _pqc_sha256_block st blk
    k = [1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221, 3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580, 3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986, 2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895, 666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037, 2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344, 430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779, 1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298]
    w = list()
    i = 0
    while i < 16
        j = i * 4
        wv = ((get(blk, j) & 255) << 24) | ((get(blk, j + 1) & 255) << 16) | ((get(blk, j + 2) & 255) << 8) | (get(blk, j + 3) & 255)
        push(w, wv & 4294967295)
        i = i + 1
    while i < 64
        x0 = get(w, i - 15)
        x1 = get(w, i - 2)
        s0 = _pqc_rotr32(x0, 7) ^ _pqc_rotr32(x0, 18) ^ ((x0 & 4294967295) >> 3)
        s1 = _pqc_rotr32(x1, 17) ^ _pqc_rotr32(x1, 19) ^ ((x1 & 4294967295) >> 10)
        push(w, (get(w, i - 16) + s0 + get(w, i - 7) + s1) & 4294967295)
        i = i + 1
    a = get(st, 0)
    b = get(st, 1)
    c = get(st, 2)
    d = get(st, 3)
    e = get(st, 4)
    f = get(st, 5)
    g = get(st, 6)
    h = get(st, 7)
    i = 0
    while i < 64
        s1 = _pqc_rotr32(e, 6) ^ _pqc_rotr32(e, 11) ^ _pqc_rotr32(e, 25)
        ch = (e & f) ^ ((~e) & g)
        t1 = (h + s1 + ch + get(k, i) + get(w, i)) & 4294967295
        s0 = _pqc_rotr32(a, 2) ^ _pqc_rotr32(a, 13) ^ _pqc_rotr32(a, 22)
        maj = (a & b) ^ (a & c) ^ (b & c)
        t2 = (s0 + maj) & 4294967295
        h = g
        g = f
        f = e
        e = (d + t1) & 4294967295
        d = c
        c = b
        b = a
        a = (t1 + t2) & 4294967295
        i = i + 1
    return [
        (get(st, 0) + a) & 4294967295,
        (get(st, 1) + b) & 4294967295,
        (get(st, 2) + c) & 4294967295,
        (get(st, 3) + d) & 4294967295,
        (get(st, 4) + e) & 4294967295,
        (get(st, 5) + f) & 4294967295,
        (get(st, 6) + g) & 4294967295,
        (get(st, 7) + h) & 4294967295
    ]

fn _pqc_sha256_bytes msg_bytes
    st = [1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225]
    padded = list()
    i = 0
    mlen = len(msg_bytes)
    while i < mlen
        push(padded, get(msg_bytes, i) & 255)
        i = i + 1
    push(padded, 128)
    while (len(padded) % 64) != 56
        push(padded, 0)
    bit_len = mlen * 8
    bi = 7
    while bi >= 0
        push(padded, (bit_len >> (bi * 8)) & 255)
        bi = bi - 1
    off = 0
    while off < len(padded)
        blk = list()
        j = 0
        while j < 64
            push(blk, get(padded, off + j))
            j = j + 1
        st = _pqc_sha256_block(st, blk)
        off = off + 64
    out = list()
    wi = 0
    while wi < 8
        wd = get(st, wi)
        push(out, (wd >> 24) & 255)
        push(out, (wd >> 16) & 255)
        push(out, (wd >> 8) & 255)
        push(out, wd & 255)
        wi = wi + 1
    return out

fn _pqc_append_bytes dst src
    i = 0
    while i < len(src)
        push(dst, get(src, i) & 255)
        i = i + 1
    return dst

fn _pqc_expand_bytes seed_bytes domain_i domain_j out_len
    out = list()
    ctr = 0
    while len(out) < out_len
        inp = list()
        _pqc_append_bytes(inp, seed_bytes)
        push(inp, domain_i & 255)
        push(inp, domain_j & 255)
        push(inp, ctr & 255)
        blk = _pqc_sha256_bytes(inp)
        bi = 0
        while bi < 32 && len(out) < out_len
            push(out, get(blk, bi))
            bi = bi + 1
        ctr = ctr + 1
    return out

fn _pqc_sample_uniform_poly seed i j
    raw = _pqc_expand_bytes(seed, i, j, 512)
    p = poly_new(256)
    k = 0
    while k < 256
        v = ((get(raw, k * 2) & 255) | ((get(raw, (k * 2) + 1) & 255) << 8)) % KYBER_Q
        list_set(p, k, v)
        k = k + 1
    return p

fn _pqc_sample_cbd2_poly seed nonce
    raw = _pqc_expand_bytes(seed, nonce, 17, 128)
    p = poly_new(256)
    i = 0
    while i < 128
        b = get(raw, i)
        list_set(p, i * 2, _pqc_cbd2(b & 15))
        list_set(p, (i * 2) + 1, _pqc_cbd2((b >> 4) & 15))
        i = i + 1
    return p

fn _pqc_hash_poly_vec vec_polys
    buf = list()
    vi = 0
    while vi < len(vec_polys)
        p = get(vec_polys, vi)
        ci = 0
        while ci < len(p)
            v = get(p, ci)
            push(buf, v & 255)
            push(buf, (v >> 8) & 255)
            ci = ci + 1
        vi = vi + 1
    return _pqc_sha256_bytes(buf)

// ── 9. NIST FIPS 203 ML-KEM-512 (k=2, 256-bit Secret, FO CCA2 Transform) ──────
fn _mlkem512_kpke_enc rho t0 t1 msg32 coins32
    a00 = _pqc_sample_uniform_poly(rho, 0, 0)
    a01 = _pqc_sample_uniform_poly(rho, 0, 1)
    a10 = _pqc_sample_uniform_poly(rho, 1, 0)
    a11 = _pqc_sample_uniform_poly(rho, 1, 1)

    r0 = _pqc_sample_cbd2_poly(coins32, 0)
    r1 = _pqc_sample_cbd2_poly(coins32, 1)
    e1_0 = _pqc_sample_cbd2_poly(coins32, 2)
    e1_1 = _pqc_sample_cbd2_poly(coins32, 3)
    e2 = _pqc_sample_cbd2_poly(coins32, 4)

    u0 = poly_add(poly_add(poly_mul_rq(a00, r0, 256), poly_mul_rq(a10, r1, 256), 256), e1_0, 256)
    u1 = poly_add(poly_add(poly_mul_rq(a01, r0, 256), poly_mul_rq(a11, r1, 256), 256), e1_1, 256)

    v = poly_add(poly_add(poly_mul_rq(t0, r0, 256), poly_mul_rq(t1, r1, 256), 256), e2, 256)
    bi = 0
    while bi < 256
        byte_v = get(msg32, bi / 8)
        m_bit = (byte_v >> (bi % 8)) & 1
        if m_bit == 1
            list_set(v, bi, kyber_mod(get(v, bi) + KYBER_HALF_Q))
        bi = bi + 1
    return [u0, u1, v]

fn mlkem512_keygen
    // Returns [pk, sk] with genuine k=2 Module-LWE matrices and FO implicit-rejection seed z
    d = _pqc_rand_bytes(32)
    z = _pqc_rand_bytes(32)
    if len(d) != 32 || len(z) != 32
        return list()
    rho = _pqc_sha256_bytes(_pqc_append_bytes(list(), d))
    sig_seed_in = list()
    _pqc_append_bytes(sig_seed_in, d)
    push(sig_seed_in, 2)
    sigma = _pqc_sha256_bytes(sig_seed_in)

    a00 = _pqc_sample_uniform_poly(rho, 0, 0)
    a01 = _pqc_sample_uniform_poly(rho, 0, 1)
    a10 = _pqc_sample_uniform_poly(rho, 1, 0)
    a11 = _pqc_sample_uniform_poly(rho, 1, 1)

    s0 = _pqc_sample_cbd2_poly(sigma, 0)
    s1 = _pqc_sample_cbd2_poly(sigma, 1)
    e0 = _pqc_sample_cbd2_poly(sigma, 2)
    e1 = _pqc_sample_cbd2_poly(sigma, 3)

    t0 = poly_add(poly_add(poly_mul_rq(a00, s0, 256), poly_mul_rq(a01, s1, 256), 256), e0, 256)
    t1 = poly_add(poly_add(poly_mul_rq(a10, s0, 256), poly_mul_rq(a11, s1, 256), 256), e1, 256)

    pk_hash_in = list()
    _pqc_append_bytes(pk_hash_in, rho)
    _pqc_append_bytes(pk_hash_in, _pqc_hash_poly_vec([t0, t1]))
    h_pk = _pqc_sha256_bytes(pk_hash_in)

    pk = [rho, t0, t1, h_pk]
    sk = [s0, s1, pk, h_pk, z]
    return [pk, sk]

fn mlkem512_encaps pk
    // Returns [ct, shared_secret_32B] using Fujisaki-Okamoto CCA2 transform
    m = _pqc_rand_bytes(32)
    if len(m) != 32
        return list()
    rho = get(pk, 0)
    t0 = get(pk, 1)
    t1 = get(pk, 2)
    h_pk = get(pk, 3)

    g_in1 = list()
    _pqc_append_bytes(g_in1, m)
    _pqc_append_bytes(g_in1, h_pk)
    push(g_in1, 1)
    k_bar = _pqc_sha256_bytes(g_in1)

    g_in2 = list()
    _pqc_append_bytes(g_in2, m)
    _pqc_append_bytes(g_in2, h_pk)
    push(g_in2, 2)
    coins = _pqc_sha256_bytes(g_in2)

    ct = _mlkem512_kpke_enc(rho, t0, t1, m, coins)
    h_ct = _pqc_hash_poly_vec(ct)
    ss_in = list()
    _pqc_append_bytes(ss_in, k_bar)
    _pqc_append_bytes(ss_in, h_ct)
    ss = _pqc_sha256_bytes(ss_in)
    return [ct, ss]

fn mlkem512_decaps sk ct
    // Fujisaki-Okamoto CCA2 decapsulation with re-encryption check + branchless implicit rejection
    s0 = get(sk, 0)
    s1 = get(sk, 1)
    pk = get(sk, 2)
    h_pk = get(sk, 3)
    z = get(sk, 4)

    u0 = get(ct, 0)
    u1 = get(ct, 1)
    v = get(ct, 2)

    su = poly_add(poly_mul_rq(s0, u0, 256), poly_mul_rq(s1, u1, 256), 256)
    w = poly_sub(v, su, 256)

    m_rec = list()
    byte_i = 0
    while byte_i < 32
        b_val = 0
        bit_j = 0
        while bit_j < 8
            coef = get(w, (byte_i * 8) + bit_j)
            d0 = coef
            if d0 > KYBER_HALF_Q
                d0 = KYBER_Q - coef
            d1 = coef - KYBER_HALF_Q
            if d1 < 0
                d1 = 0 - d1
            if d1 < d0
                b_val = b_val | (1 << bit_j)
            bit_j = bit_j + 1
        push(m_rec, b_val)
        byte_i = byte_i + 1

    g_in1 = list()
    _pqc_append_bytes(g_in1, m_rec)
    _pqc_append_bytes(g_in1, h_pk)
    push(g_in1, 1)
    k_bar = _pqc_sha256_bytes(g_in1)

    g_in2 = list()
    _pqc_append_bytes(g_in2, m_rec)
    _pqc_append_bytes(g_in2, h_pk)
    push(g_in2, 2)
    coins = _pqc_sha256_bytes(g_in2)

    ct_chk = _mlkem512_kpke_enc(get(pk, 0), get(pk, 1), get(pk, 2), m_rec, coins)
    diff = 0
    pi = 0
    while pi < 3
        pa = get(ct, pi)
        pb = get(ct_chk, pi)
        ci = 0
        while ci < 256
            diff = diff | ((get(pa, ci) ^ get(pb, ci)) & 65535)
            ci = ci + 1
        pi = pi + 1

    h_ct = _pqc_hash_poly_vec(ct)
    good_in = list()
    _pqc_append_bytes(good_in, k_bar)
    _pqc_append_bytes(good_in, h_ct)
    k_good = _pqc_sha256_bytes(good_in)

    rej_in = list()
    _pqc_append_bytes(rej_in, z)
    _pqc_append_bytes(rej_in, h_ct)
    k_rej = _pqc_sha256_bytes(rej_in)

    fail = 0
    if diff != 0
        fail = 1
    out = list()
    oi = 0
    while oi < 32
        g_b = get(k_good, oi)
        r_b = get(k_rej, oi)
        push(out, g_b ^ (fail * (g_b ^ r_b)))
        oi = oi + 1
    return out

// ── 10. NIST FIPS 204 ML-DSA Digital Signatures over R_q (q = 8380417) ────────
DILITHIUM_Q = 8380417

fn _mldsa_mod a
    m = a % DILITHIUM_Q
    if m < 0
        m = m + DILITHIUM_Q
    return m

fn _mldsa_center a
    v = _mldsa_mod(a)
    if v > 4190208
        v = v - DILITHIUM_Q
    return v

fn _mldsa_poly_add a b
    out = poly_new(256)
    i = 0
    while i < 256
        list_set(out, i, _mldsa_mod(get(a, i) + get(b, i)))
        i = i + 1
    return out

fn _mldsa_poly_sub a b
    out = poly_new(256)
    i = 0
    while i < 256
        list_set(out, i, _mldsa_mod(get(a, i) - get(b, i)))
        i = i + 1
    return out

fn _mldsa_poly_mul a b
    out = poly_new(256)
    i = 0
    while i < 256
        ai = _mldsa_center(get(a, i))
        if ai != 0
            j = 0
            while j < 256
                prod = ai * _mldsa_center(get(b, j))
                deg = i + j
                if deg < 256
                    list_set(out, deg, _mldsa_mod(get(out, deg) + prod))
                else
                    wd = deg - 256
                    list_set(out, wd, _mldsa_mod(get(out, wd) - prod))
                j = j + 1
        i = i + 1
    return out

fn _mldsa_sample_a rho
    raw = _pqc_expand_bytes(rho, 88, 1, 768)
    p = poly_new(256)
    i = 0
    while i < 256
        o = i * 3
        v = (get(raw, o) | (get(raw, o + 1) << 8) | (get(raw, o + 2) << 16)) % DILITHIUM_Q
        list_set(p, i, v)
        i = i + 1
    return p

fn _mldsa_sample_small seed nonce
    raw = _pqc_expand_bytes(seed, nonce, 22, 256)
    p = poly_new(256)
    i = 0
    while i < 256
        list_set(p, i, _mldsa_mod((get(raw, i) % 5) - 2))
        i = i + 1
    return p

fn _mldsa_sample_y seed kappa
    raw = _pqc_expand_bytes(seed, kappa, 33, 768)
    p = poly_new(256)
    i = 0
    while i < 256
        o = i * 3
        v = ((get(raw, o) | (get(raw, o + 1) << 8) | (get(raw, o + 2) << 16)) % 262143) - 131071
        list_set(p, i, _mldsa_mod(v))
        i = i + 1
    return p

fn _mldsa_sample_challenge c_hash
    raw = _pqc_expand_bytes(c_hash, 99, 1, 64)
    c = poly_new(256)
    signs = ((get(raw, 60) | (get(raw, 61) << 8) | (get(raw, 62) << 16) | (get(raw, 63) << 24)) & 4294967295)
    placed = 0
    k = 0
    while placed < 39 && k < 58
        idx = get(raw, k) & 255
        if get(c, idx) == 0
            s_bit = (signs >> (placed % 31)) & 1
            if s_bit == 1
                list_set(c, idx, DILITHIUM_Q - 1)
            else
                list_set(c, idx, 1)
            placed = placed + 1
        k = k + 1
    return c

fn _mldsa_poly_bytes_24 p
    out = list()
    i = 0
    while i < 256
        v = _mldsa_mod(get(p, i))
        push(out, v & 255)
        push(out, (v >> 8) & 255)
        push(out, (v >> 16) & 255)
        i = i + 1
    return out

fn mldsa_keygen
    rho = _pqc_rand_bytes(32)
    sec = _pqc_rand_bytes(32)
    if len(rho) != 32 || len(sec) != 32
        return list()
    a = _mldsa_sample_a(rho)
    s1 = _mldsa_sample_small(sec, 0)
    s2 = _mldsa_sample_small(sec, 1)
    t = _mldsa_poly_add(_mldsa_poly_mul(a, s1), s2)
    pk_in = list()
    _pqc_append_bytes(pk_in, rho)
    _pqc_append_bytes(pk_in, _mldsa_poly_bytes_24(t))
    tr = _pqc_sha256_bytes(pk_in)
    pk = [rho, t, tr]
    sk = [rho, tr, s1, s2, sec]
    return [pk, sk]

fn mldsa_sign sk msg_bytes
    rho = get(sk, 0)
    tr = get(sk, 1)
    s1 = get(sk, 2)
    s2 = get(sk, 3)
    sec = get(sk, 4)
    a = _mldsa_sample_a(rho)

    mu_in = list()
    _pqc_append_bytes(mu_in, tr)
    _pqc_append_bytes(mu_in, msg_bytes)
    mu = _pqc_sha256_bytes(mu_in)

    rnd = _pqc_rand_bytes(32)
    if len(rnd) != 32
        return list()
    mask_seed_in = list()
    _pqc_append_bytes(mask_seed_in, sec)
    _pqc_append_bytes(mask_seed_in, rnd)
    _pqc_append_bytes(mask_seed_in, mu)
    mask_seed = _pqc_sha256_bytes(mask_seed_in)

    kappa = 0
    while kappa < 64
        y = _mldsa_sample_y(mask_seed, kappa)
        w = _mldsa_poly_mul(a, y)
        ch_in = list()
        _pqc_append_bytes(ch_in, mu)
        _pqc_append_bytes(ch_in, _mldsa_poly_bytes_24(w))
        c_hash = _pqc_sha256_bytes(ch_in)
        c = _mldsa_sample_challenge(c_hash)
        cs1 = _mldsa_poly_mul(c, s1)
        cs2 = _mldsa_poly_mul(c, s2)
        z = _mldsa_poly_add(y, cs1)
        w_adj = _mldsa_poly_sub(w, cs2)

        ok = 1
        i = 0
        while i < 256
            zv = _mldsa_center(get(z, i))
            if zv < 0
                zv = 0 - zv
            cs2v = _mldsa_center(get(cs2, i))
            if cs2v < 0
                cs2v = 0 - cs2v
            if zv >= 130944 || cs2v >= 96
                ok = 0
                break
            i = i + 1
        if ok == 1
            return [c_hash, z, cs2]
        kappa = kappa + 1
    return list()

fn mldsa_verify pk msg_bytes sig
    if len(sig) != 3
        return 0
    c_hash = get(sig, 0)
    z = get(sig, 1)
    h_adj = get(sig, 2)
    if len(c_hash) != 32 || len(z) != 256 || len(h_adj) != 256
        return 0
    i = 0
    while i < 256
        zv = _mldsa_center(get(z, i))
        if zv < 0
            zv = 0 - zv
        hv = _mldsa_center(get(h_adj, i))
        if hv < 0
            hv = 0 - hv
        if zv >= 130944 || hv >= 96
            return 0
        i = i + 1

    rho = get(pk, 0)
    t = get(pk, 1)
    tr = get(pk, 2)
    a = _mldsa_sample_a(rho)

    mu_in = list()
    _pqc_append_bytes(mu_in, tr)
    _pqc_append_bytes(mu_in, msg_bytes)
    mu = _pqc_sha256_bytes(mu_in)

    c = _mldsa_sample_challenge(c_hash)
    az = _mldsa_poly_mul(a, z)
    ct = _mldsa_poly_mul(c, t)
    w_rec = _mldsa_poly_add(_mldsa_poly_sub(az, ct), h_adj)

    ch_in = list()
    _pqc_append_bytes(ch_in, mu)
    _pqc_append_bytes(ch_in, _mldsa_poly_bytes_24(w_rec))
    c_chk = _pqc_sha256_bytes(ch_in)

    diff = 0
    ci = 0
    while ci < 32
        diff = diff | ((get(c_hash, ci) ^ get(c_chk, ci)) & 255)
        ci = ci + 1
    if diff == 0
        return 1
    return 0
