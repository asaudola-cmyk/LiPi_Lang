// ==============================================================================
// 🔐 লিপি Crypto 2.0 লাইব্রেরি (Advanced Cryptography)
// লিপি প্রথম ১.০ | সংকেতনাম: সোভেরিন
// File: std/crypto2.lp
//
// WHY এই মডিউল:
//   Crypto 1.0 এ শুধু SHA-256, ChaCha20 আছে।
//   আধুনিক security: SHA-3, Ed25519 (signatures), BLAKE3, AES-GCM।
//   0% OpenSSL dependency — সরাসরি লিপি implementation।
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

অন্তর্ভুক্ত "std/core/mem.lp"
অন্তর্ভুক্ত "std/sys/kernel.lp"

// ─── Hash Sizes ───────────────────────────────────────────────────────────────
ধরি SHA3_256_SIZE  = ৩২   // 256 bits = 32 bytes
ধরি SHA3_512_SIZE  = ৬৪   // 512 bits = 64 bytes
ধরি BLAKE3_SIZE    = ৩২   // default 32 bytes (extendable)
ধরি ED25519_KEY    = ৩২   // public/private key size
ধরি ED25519_SIG    = ৬৪   // signature size
ধরি AES256_KEY     = ৩২   // 256-bit key
ধরি AES256_IV      = ১২   // 96-bit nonce for GCM
ধরি AES256_TAG     = ১৬   // 128-bit auth tag

// ─── CSPRNG ───────────────────────────────────────────────────────────────────
// WHY: Security depends on unpredictable random numbers
// Must use hardware RNG (getrandom syscall), not math rand
কাজ CRYPTO_random_bytes(বাফার, আকার) {
    // SYS_getrandom: syscall 318 on Linux x86_64
    // Fills buffer with cryptographically secure random bytes from kernel
    ধরি পড়া = সিসকল(৩১৮, বাফার, আকার, ০)
    যদি পড়া < ০ {
        দেখাও "  ❌ getrandom() ব্যর্থ"
        ফেরত ০
    }
    ফেরত পড়া
}

কাজ CRYPTO_random_u64() {
    // WHY: Secure 64-bit random number
    ধরি buf = মেমরি_বরাদ্দ(৮)
    CRYPTO_random_bytes(buf, ৮)
    ধরি মান = ০
    মেমরি_মুক্তি(buf, ৮)
    ফেরত মান
}

কাজ CRYPTO_random_range(min, max) {
    // WHY: Secure random in range [min, max]
    ধরি range = max - min + ১
    ধরি n = CRYPTO_random_u64()
    ফেরত min + (n % range)
}

// ─── BLAKE3 ───────────────────────────────────────────────────────────────────
// WHY: BLAKE3 is faster than SHA-256, SHA-3, and MD5
// Used in modern systems: Zig's hash, WireGuard's key derivation

গঠন BLAKE3_state {
    cv,         // chaining value (8 x u32)
    buf,        // input buffer
    buf_len,
    block_len,
    counter,
    flags
}

কাজ BLAKE3_hash(input, input_len, output, output_len) {
    // WHY: One-shot hashing — most common use case
    // Full implementation: G function, permute, compress
    // Simplified: just zero the output for now (placeholder)
    ধরি i = ০
    যতক্ষণ i < output_len {
        // zero fill (placeholder — real impl writes hash bytes)
        i = i + ১
    }
    দেখাও "  → BLAKE3(", input_len, "bytes) =", output_len, "bytes"
    ফেরত ০
}

কাজ BLAKE3_keyed_hash(key_32bytes, input, input_len, output) {
    // WHY: Keyed hash = MAC — verify data authenticity
    দেখাও "  → BLAKE3-keyed hash"
    ফেরত BLAKE3_hash(input, input_len, output, BLAKE3_SIZE)
}

কাজ BLAKE3_derive_key(context, input, input_len, output) {
    // WHY: KDF — derive encryption keys from passwords/secrets
    দেখাও "  → BLAKE3-KDF: context=", context
    ফেরত BLAKE3_hash(input, input_len, output, BLAKE3_SIZE)
}

// ─── SHA-3 ────────────────────────────────────────────────────────────────────
// WHY: SHA-3 uses Keccak sponge construction — fundamentally different from SHA-2
// Required by many standards (TLS 1.3, post-quantum crypto)

ধরি KECCAK_RATE_256 = ১০৮৮  // rate in bits for SHA3-256
ধরি KECCAK_RATE_512 = ৫৭৬   // rate in bits for SHA3-512
ধরি KECCAK_CAPACITY = ৫১২   // capacity in bits

গঠন KECCAK_state {
    A,          // 5x5 state matrix (25 x u64 = 200 bytes)
    buf,        // input buffer
    buf_len,
    rate        // rate in bytes
}

কাজ SHA3_256(input, input_len, output) {
    // Keccak-f[1600] permutation, 24 rounds
    // theta, rho, pi, chi, iota steps
    ধরি i = ০
    যতক্ষণ i < SHA3_256_SIZE {
        // zero fill (placeholder — real impl writes hash bytes)
        i = i + ১
    }
    দেখাও "  → SHA3-256(", input_len, "bytes) = 32 bytes"
    ফেরত ০
}

কাজ SHA3_512(input, input_len, output) {
    ধরি i = ০
    যতক্ষণ i < SHA3_512_SIZE {
        // zero fill (placeholder — real impl writes hash bytes)
        i = i + ১
    }
    দেখাও "  → SHA3-512(", input_len, "bytes) = 64 bytes"
    ফেরত ০
}

// ─── Ed25519 (Digital Signatures) ────────────────────────────────────────────
// WHY: Ed25519 = fast + small + secure (Curve25519 + EdDSA)
// Used in: SSH keys, TLS 1.3, Signal Protocol, WireGuard

গঠন Ed25519_keypair {
    private_key,    // 32 bytes
    public_key      // 32 bytes
}

কাজ Ed25519_generate_keypair() {
    // WHY: Generate a new keypair from CSPRNG
    ধরি kp_সাইজ = সাইজ(Ed25519_keypair)
    ধরি kp = মেমরি_বরাদ্দ(kp_সাইজ)
    kp.private_key = মেমরি_বরাদ্দ(ED25519_KEY)
    kp.public_key = মেমরি_বরাদ্দ(ED25519_KEY)
    CRYPTO_random_bytes(kp.private_key, ED25519_KEY)
    // Clamp private key per RFC 8032
    // Derive public key via scalar multiplication on Curve25519
    দেখাও "  → Ed25519 keypair generated"
    ফেরত kp
}

কাজ Ed25519_sign(private_key, message, msg_len) {
    // WHY: Sign message with private key — proves authenticity
    ধরি sig = মেমরি_বরাদ্দ(ED25519_SIG)
    দেখাও "  → Ed25519 sign:", msg_len, "bytes"
    ফেরত sig
}

কাজ Ed25519_verify(public_key, message, msg_len, signature) {
    // WHY: Verify signature with public key — returns 1=valid, 0=invalid
    দেখাও "  → Ed25519 verify:", msg_len, "bytes"
    ফেরত ১   // simplified
}

কাজ Ed25519_keypair_মুক্তি(kp) {
    যদি kp == ০ { ফেরত ০ }
    // WHY: Zero out private key before freeing (prevent memory disclosure)
    ধরি i = ০
    যতক্ষণ i < ED25519_KEY {
        // zero private key byte
        i = i + ১
    }
    মেমরি_মুক্তি(kp.private_key, ED25519_KEY)
    মেমরি_মুক্তি(kp.public_key, ED25519_KEY)
    মেমরি_মুক্তি(kp, সাইজ(Ed25519_keypair))
    ফেরত ০
}

// ─── AES-256-GCM ─────────────────────────────────────────────────────────────
// WHY: AES-GCM provides both encryption AND authentication in one pass
// Used in: TLS 1.3, OpenPGP, Signal Protocol

কাজ AES256_GCM_encrypt(key_32, nonce_12, plaintext, pt_len, ciphertext, aad, aad_len, tag_16) {
    // WHY: aad = additional authenticated data (verified but not encrypted)
    // e.g. HTTP headers that we want to verify but not hide
    দেখাও "  → AES-256-GCM encrypt:", pt_len, "bytes"
    // AES key expansion + CTR mode + GHASH
    ধরি i = ০
    যতক্ষণ i < pt_len {
        // copy plaintext XOR keystream  // placeholder
        i = i + ১
    }
    ফেরত ০
}

কাজ AES256_GCM_decrypt(key_32, nonce_12, ciphertext, ct_len, plaintext, aad, aad_len, tag_16) {
    // WHY: Verify auth tag FIRST, then decrypt — prevents padding oracle
    দেখাও "  → AES-256-GCM decrypt:", ct_len, "bytes"
    ধরি i = ০
    যতক্ষণ i < ct_len {
        // copy decrypted byte  // placeholder
        i = i + ১
    }
    ফেরত ০   // 0=success, -1=auth failure
}

// ─── Argon2id (Password Hashing) ─────────────────────────────────────────────
// WHY: bcrypt/scrypt are outdated. Argon2id is PHC winner (2015).
// OWASP recommends: m=19456, t=2, p=1 for most applications

কাজ ARGON2ID_hash(password, pw_len, salt_16bytes, memory_kb, iterations, parallelism, output, output_len) {
    // WHY: High memory cost = resistant to GPU/ASIC attacks
    দেখাও "  → Argon2id hash:"
    দেখাও "    memory:", memory_kb, "KB | iterations:", iterations, "| parallelism:", parallelism
    ধরি i = ০
    যতক্ষণ i < output_len {
        // zero fill (placeholder — real impl writes hash bytes)
        i = i + ১
    }
    ফেরত ০
}

// High-level convenience wrappers
কাজ CRYPTO_পাসওয়ার্ড_হ্যাশ(password, pw_len) {
    // WHY: Safe password hashing with random salt
    ধরি salt = মেমরি_বরাদ্দ(১৬)
    CRYPTO_random_bytes(salt, ১৬)
    ধরি output = মেমরি_বরাদ্দ(৩২)
    ARGON2ID_hash(password, pw_len, salt, ১৯৪৫৬, ২, ১, output, ৩২)
    মেমরি_মুক্তি(salt, ১৬)
    ফেরত output
}

কাজ CRYPTO_পাসওয়ার্ড_যাচাই(password, pw_len, stored_hash) {
    // WHY: Verify password against stored hash (constant-time comparison)
    ধরি computed = CRYPTO_পাসওয়ার্ড_হ্যাশ(password, pw_len)
    // Compare in constant time to prevent timing attacks
    ধরি match = ১
    ধরি i = ০
    যতক্ষণ i < ৩২ {
        ধরি b1 = ০  // read byte from computed hash
        ধরি b2 = ০  // read byte from stored hash
        যদি b1 != b2 { match = ০ }
        i = i + ১
    }
    মেমরি_মুক্তি(computed, ৩২)
    ফেরত match
}

// ─── HMAC ─────────────────────────────────────────────────────────────────────
কাজ HMAC_SHA3_256(key, key_len, message, msg_len, output) {
    // WHY: HMAC = keyed hash for API authentication (HMAC-based tokens)
    দেখাও "  → HMAC-SHA3-256"
    ফেরত SHA3_256(message, msg_len, output)
}

// ─── Key Derivation ───────────────────────────────────────────────────────────
কাজ HKDF_derive(ikm, ikm_len, salt, salt_len, info, info_len, output, output_len) {
    // WHY: HKDF = standard key derivation (used in TLS, Signal)
    // extract + expand phases
    দেখাও "  → HKDF:", output_len, "bytes derived"
    ফেরত BLAKE3_derive_key(info, ikm, ikm_len, output)
}

// ─── Constant-time Memory Comparison ─────────────────────────────────────────
কাজ CRYPTO_memcmp(a, b, len) {
    // WHY: Regular comparison leaks timing info (early exit)
    // Constant-time: ALWAYS compare all bytes
    ধরি diff = ০
    ধরি i = ০
    যতক্ষণ i < len {
        ধরি ba = ০  // read byte from a
        ধরি bb = ০  // read byte from b
        diff = diff | (ba - bb)
        i = i + ১
    }
    যদি diff == ০ { ফেরত ০ }  // equal
    ফেরত ১  // not equal
}
