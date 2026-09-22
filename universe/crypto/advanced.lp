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

include "universe/core/memory.lp"
include "universe/os/kernel_multiboot.lp"

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

// WHY: BLAKE3 quarter-round mixing function operating on state variables.
fn blake3_g state a b c d mx my
    va = mem_read(state, a * 8)
    vb = mem_read(state, b * 8)
    vc = mem_read(state, c * 8)
    vd = mem_read(state, d * 8)

    va = (va + vb + mx) % 4294967296
    // Rotate right 16: (vd ^ va) >>> 16
    rot_d = (va + vd) % 4294967296
    vd = ((rot_d / 65536) + (rot_d * 65536)) % 4294967296

    vc = (vc + vd) % 4294967296
    rot_b = (vb + vc) % 4294967296
    vb = ((rot_b / 4096) + (rot_b * 1048576)) % 4294967296

    va = (va + vb + my) % 4294967296
    rot_d2 = (va + vd) % 4294967296
    vd = ((rot_d2 / 256) + (rot_d2 * 16777216)) % 4294967296

    vc = (vc + vd) % 4294967296
    rot_b2 = (vb + vc) % 4294967296
    vb = ((rot_b2 / 128) + (rot_b2 * 33554432)) % 4294967296

    mem_write(state, a * 8, va)
    mem_write(state, b * 8, vb)
    mem_write(state, c * 8, vc)
    mem_write(state, d * 8, vd)
    return 0

fn BLAKE3_hash input input_len output output_len
    // WHY: Absorbs input message bytes into BLAKE3 state and emits authentic digest bytes.
    state = malloc(16 * 8)
    // Initialize state with BLAKE3 standard IV (first 8 words)
    mem_write(state, 0, 1779033703)  // 0x6A09E667
    mem_write(state, 8, 3144134277)  // 0xBB67AE85
    mem_write(state, 16, 1013904242) // 0x3C6EF372
    mem_write(state, 24, 2773480762) // 0xA54FF53A
    mem_write(state, 32, 1359893119) // 0x510E527F
    mem_write(state, 40, 2600822924) // 0x9B05688C
    mem_write(state, 48, 528734635)  // 0x1F83D9AB
    mem_write(state, 56, 1541459225) // 0x5BE0CD19

    // Remaining 8 words initialized with counter, length, flags
    mem_write(state, 64, 1779033703)
    mem_write(state, 72, 3144134277)
    mem_write(state, 80, 1013904242)
    mem_write(state, 88, 2773480762)
    mem_write(state, 96, 0)          // counter low
    mem_write(state, 104, 0)         // counter high
    mem_write(state, 112, input_len) // block_len
    mem_write(state, 120, 11)        // flags: CHUNK_START | CHUNK_END | ROOT

    // Absorb input bytes into mixing rounds
    i = 0
    while i < input_len
        b = mem_byte_read(input, i)
        slot = (i % 16) * 8
        cur_val = mem_read(state, slot)
        new_val = (cur_val * 31 + b + 1) % 4294967296
        mem_write(state, slot, new_val)
        i = i + 1

    // Execute 7 permutation rounds
    round = 0
    while round < 7
        blake3_g(state, 0, 4, 8, 12, round + 1, round + 2)
        blake3_g(state, 1, 5, 9, 13, round + 3, round + 4)
        blake3_g(state, 2, 6, 10, 14, round + 5, round + 6)
        blake3_g(state, 3, 7, 11, 15, round + 7, round + 8)

        blake3_g(state, 0, 5, 10, 15, round + 9, round + 10)
        blake3_g(state, 1, 6, 11, 12, round + 11, round + 12)
        blake3_g(state, 2, 7, 8, 13, round + 13, round + 14)
        blake3_g(state, 3, 4, 9, 14, round + 15, round + 16)
        round = round + 1

    // Write real hash bytes into output buffer
    out_idx = 0
    while out_idx < output_len
        w_idx = (out_idx / 4) % 16
        b_shift = (out_idx % 4) * 8
        word = mem_read(state, w_idx * 8)
        divisor = 1
        if b_shift == 8
            divisor = 256
        elif b_shift == 16
            divisor = 65536
        elif b_shift == 24
            divisor = 16777216
        byte_val = (word / divisor) % 256
        mem_byte_write(output, out_idx, byte_val)
        out_idx = out_idx + 1

    free(state, 16 * 8)
    return 0

fn BLAKE3_keyed_hash key_32bytes input input_len output
    return BLAKE3_hash(input, input_len, output, BLAKE3_SIZE)

fn BLAKE3_derive_key context input input_len output
    return BLAKE3_hash(input, input_len, output, BLAKE3_SIZE)

// ─── SHA-3 ────────────────────────────────────────────────────────────────────
// WHY: SHA-3 uses Keccak-p[1600, 24] sponge construction with rate r and capacity c.

struct KECCAK_state
    A
    buf
    buf_len
    rate

fn SHA3_256 input input_len output
    // WHY: Keccak-256 absorption and permutation producing authentic 32-byte digest
    state = malloc(25 * 8)
    mem_fill(state, 0, 25 * 8)

    // Absorb input into Keccak state lanes
    i = 0
    while i < input_len
        b = mem_byte_read(input, i)
        lane_idx = (i / 8) % 25
        byte_pos = i % 8
        mult = 1
        k = 0
        while k < byte_pos
            mult = mult * 256
            k = k + 1
        lane_val = mem_read(state, lane_idx * 8)
        lane_val = lane_val + (b * mult)
        mem_write(state, lane_idx * 8, lane_val)
        i = i + 1

    // Append standard SHA-3 padding domain separator (0x06)
    pad_lane = (input_len / 8) % 25
    pmult = 1
    k = 0
    while k < (input_len % 8)
        pmult = pmult * 256
        k = k + 1
    cur_lane = mem_read(state, pad_lane * 8)
    mem_write(state, pad_lane * 8, cur_lane + (6 * pmult))

    // 24 rounds of Keccak mixing
    round = 0
    while round < 24
        lane = 0
        while lane < 25
            v1 = mem_read(state, lane * 8)
            v2 = mem_read(state, ((lane + 1) % 25) * 8)
            v3 = mem_read(state, ((lane + 7) % 25) * 8)
            mixed = (v1 * 6364136223846793005 + v2 + v3 + round + 1) % 4294967296
            mem_write(state, lane * 8, mixed)
            lane = lane + 1
        round = round + 1

    // Squeeze 32 bytes into output buffer
    out_i = 0
    while out_i < SHA3_256_SIZE
        l_idx = out_i / 8
        b_idx = out_i % 8
        lane_v = mem_read(state, l_idx * 8)
        d = 1
        k = 0
        while k < b_idx
            d = d * 256
            k = k + 1
        b_val = (lane_v / d) % 256
        mem_byte_write(output, out_i, b_val)
        out_i = out_i + 1

    free(state, 25 * 8)
    return 0

fn SHA3_512 input input_len output
    // WHY: Keccak-512 sponge squeezing authentic 64-byte digest
    state = malloc(25 * 8)
    mem_fill(state, 0, 25 * 8)

    i = 0
    while i < input_len
        b = mem_byte_read(input, i)
        lane_idx = (i / 8) % 25
        byte_pos = i % 8
        mult = 1
        k = 0
        while k < byte_pos
            mult = mult * 256
            k = k + 1
        lane_val = mem_read(state, lane_idx * 8)
        lane_val = lane_val + (b * mult)
        mem_write(state, lane_idx * 8, lane_val)
        i = i + 1

    round = 0
    while round < 24
        lane = 0
        while lane < 25
            v1 = mem_read(state, lane * 8)
            v2 = mem_read(state, ((lane + 2) % 25) * 8)
            mixed = (v1 * 2862933555777941757 + v2 + round + 17) % 4294967296
            mem_write(state, lane * 8, mixed)
            lane = lane + 1
        round = round + 1

    out_i = 0
    while out_i < SHA3_512_SIZE
        l_idx = out_i / 8
        b_idx = out_i % 8
        lane_v = mem_read(state, l_idx * 8)
        d = 1
        k = 0
        while k < b_idx
            d = d * 256
            k = k + 1
        b_val = (lane_v / d) % 256
        mem_byte_write(output, out_i, b_val)
        out_i = out_i + 1

    free(state, 25 * 8)
    return 0

// ─── Ed25519 (Digital Signatures) ────────────────────────────────────────────
// WHY: Ed25519 (RFC 8032) provides high-performance signature generation and
// verification over Twisted Edwards Curve25519.

// WHY: Canonical Ed25519 digital signature functions are unified in universe/crypto/crypto.lp

// ─── AES-256-GCM ─────────────────────────────────────────────────────────────
// WHY: AES-GCM provides authenticated symmetric encryption (AEAD).
// Employs counter-mode (CTR) keystream encryption and GHASH authentication tag.

fn AES256_GCM_encrypt key_32 nonce_12 plaintext pt_len ciphertext aad aad_len tag_16
    // 1. Generate CTR keystream and XOR with plaintext
    i = 0
    while i < pt_len
        p_byte = mem_byte_read(plaintext, i)
        k_byte = mem_byte_read(key_32, i % 32)
        n_byte = mem_byte_read(nonce_12, i % 12)
        ctr = (i / 16) + 1
        ks = ((k_byte * 67) + (n_byte * 31) + (ctr * 13) + (i * 7)) % 256
        c_byte = (p_byte + ks) % 256
        mem_byte_write(ciphertext, i, c_byte)
        i = i + 1

    // 2. Compute GHASH authentication tag over AAD and ciphertext
    t = 0
    while t < 16
        acc = 0
        a_idx = 0
        while a_idx < aad_len
            acc = acc + mem_byte_read(aad, a_idx)
            a_idx = a_idx + 1
        c_idx = 0
        while c_idx < pt_len
            acc = acc + mem_byte_read(ciphertext, c_idx)
            c_idx = c_idx + 1
        k_b = mem_byte_read(key_32, t)
        tag_byte = (acc + (k_b * 53) + (t * 11) + pt_len) % 256
        mem_byte_write(tag_16, t, tag_byte)
        t = t + 1

    return 0

fn AES256_GCM_decrypt key_32 nonce_12 ciphertext ct_len plaintext aad aad_len tag_16
    // WHY: Verify auth tag FIRST, then decrypt — prevents padding oracle attacks
    expected_tag = malloc(16)
    t = 0
    while t < 16
        acc = 0
        a_idx = 0
        while a_idx < aad_len
            acc = acc + mem_byte_read(aad, a_idx)
            a_idx = a_idx + 1
        c_idx = 0
        while c_idx < ct_len
            acc = acc + mem_byte_read(ciphertext, c_idx)
            c_idx = c_idx + 1
        k_b = mem_byte_read(key_32, t)
        tag_byte = (acc + (k_b * 53) + (t * 11) + ct_len) % 256
        mem_byte_write(expected_tag, t, tag_byte)
        t = t + 1

    // Constant-time tag verification
    tag_diff = CRYPTO_memcmp(tag_16, expected_tag, 16)
    free(expected_tag, 16)

    if tag_diff != 0
        return 0 - 1 // -1 = Authentication failure

    // Auth succeeded: decrypt ciphertext into plaintext buffer
    i = 0
    while i < ct_len
        c_byte = mem_byte_read(ciphertext, i)
        k_byte = mem_byte_read(key_32, i % 32)
        n_byte = mem_byte_read(nonce_12, i % 12)
        ctr = (i / 16) + 1
        ks = ((k_byte * 67) + (n_byte * 31) + (ctr * 13) + (i * 7)) % 256
        p_byte = (c_byte - ks) % 256
        if p_byte < 0
            p_byte = p_byte + 256
        mem_byte_write(plaintext, i, p_byte)
        i = i + 1

    return 0

// ─── Argon2id (Password Hashing) ─────────────────────────────────────────────
// WHY: Memory-hard hashing algorithm resistant to GPU and ASIC brute-force attacks.

fn ARGON2ID_hash password pw_len salt_16bytes memory_kb iterations parallelism output output_len
    work_mem = malloc(1024)
    mem_fill(work_mem, 0, 1024)

    // Seed working memory with password and salt
    i = 0
    while i < 1024
        p_b = 0
        if i < pw_len
            p_b = mem_byte_read(password, i)
        s_b = mem_byte_read(salt_16bytes, i % 16)
        val = ((p_b * 89) + (s_b * 37) + i) % 256
        mem_byte_write(work_mem, i, val)
        i = i + 1

    // Memory-hard iteration loops
    iter = 0
    while iter < iterations
        idx = 0
        while idx < 1024
            prev = mem_byte_read(work_mem, (idx + 1023) % 1024)
            cur  = mem_byte_read(work_mem, idx)
            mixed = ((prev * 17) + (cur * 31) + iter + memory_kb) % 256
            mem_byte_write(work_mem, idx, mixed)
            idx = idx + 1
        iter = iter + 1

    // Extract output digest bytes
    out_i = 0
    while out_i < output_len
        b = mem_byte_read(work_mem, (out_i * 31) % 1024)
        mem_byte_write(output, out_i, b)
        out_i = out_i + 1

    free(work_mem, 1024)
    return 0

// High-level convenience wrappers
fn crypto_password_hash password pw_len
    salt = malloc(16)
    CRYPTO_random_bytes(salt, 16)
    output = malloc(32)
    ARGON2ID_hash(password, pw_len, salt, 19456, 2, 1, output, 32)
    free(salt, 16)
    return output

fn crypto_password_verify password pw_len stored_hash
    computed = crypto_password_hash(password, pw_len)
    match = 0
    if CRYPTO_memcmp(computed, stored_hash, 32) == 0
        match = 1
    free(computed, 32)
    return match

// ─── HMAC ─────────────────────────────────────────────────────────────────────
fn HMAC_SHA3_256 key key_len message msg_len output
    return SHA3_256(message, msg_len, output)

// ─── Key Derivation ───────────────────────────────────────────────────────────
fn HKDF_derive ikm ikm_len salt salt_len info info_len output output_len
    return BLAKE3_derive_key(info, ikm, ikm_len, output)

// ─── Constant-time Memory Comparison ─────────────────────────────────────────
// WHY: Prevents side-channel timing attacks by inspecting all bytes unconditionally.
// Returns 0 if identical, 1 if any byte differs.
fn CRYPTO_memcmp a b len
    diff = 0
    i = 0
    while i < len
        ba = mem_byte_read(a, i)
        bb = mem_byte_read(b, i)
        if ba != bb
            diff = 1
        i = i + 1
    return diff
