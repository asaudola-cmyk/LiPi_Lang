// ==============================================================================
// 👑 LIPI UNIVERSE CRYPTO — GRAND UMBRELLA PRELUDE (universe/crypto.lp)
// ⚡ 100% Pure Sovereign Lipi Machine Code Engine | Zero OpenSSL | Zero C
// ==============================================================================
//
// WHY: Provides a unified gateway for all cryptography, hashing, encryption,
// and digital signature algorithms in pure Lipi.
// Developers can simply write:
//     import "universe/crypto"
// to access FIPS SHA-256 / SHA-512 hashing, AES-128 / AES-256 GCM encryption,
// Ed25519 digital signatures, and cryptographically secure random bytes.
// ==============================================================================

import "universe/crypto/sha256"
import "universe/crypto/sha512"
import "universe/crypto/aes"
import "universe/crypto/ed25519"
import "universe/crypto/random"
import "universe/crypto/base64"

// ── Quick SHA-256 Hash Helper ─────────────────────────────────────────────────
// WHY: Computes a 64-character lowercase hexadecimal SHA-256 digest of any string.
@fn lipi_sha256(s)
    return sha256_hex_string(s)
@end

@fn লিপি_শা২৫৬(লেখা)
    return lipi_sha256(লেখা)
@end

// ── Secure Random Integer Helper ──────────────────────────────────────────────
// WHY: Reads high-entropy true random integer directly from Linux SYS_getrandom (318).
@fn lipi_random_int()
    return silicon_random_int()
@end

@fn লিপি_র‍্যান্ডম_সংখ্যা()
    return lipi_random_int()
@end

// ── Secure Random Buffer Factory ──────────────────────────────────────────────
// WHY: Allocates and populates an aligned buffer with high-entropy cryptographic bytes.
@fn lipi_random_bytes(count)
    if count <= 0
        count = 16
    end
    buf = malloc(count)
    crypto_random_bytes(buf, count)
    return buf
@end

@fn random_bytes(count)
    return lipi_random_bytes(count)
@end

@fn লিপি_র‍্যান্ডম_বাইট(সংখ্যা)
    return lipi_random_bytes(সংখ্যা)
@end
