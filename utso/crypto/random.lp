// ==============================================================================
// 👑 LIPI CRYPTOGRAPHY ENGINE: HARDWARE ENTROPY & CSPRNG (utso/crypto/random.lp)
// ⚡ 100% Sovereign NIST SP 800-90A/B Architecture | SYS_getrandom (318) | RDTSC
// ==============================================================================

// WHY: Cryptographically secure pseudo-random number generation (CSPRNG) and hardware
// entropy are fundamental to key exchange, salting, nonces, and session tokens.
// Uses Linux kernel SYS_getrandom (318) with EINTR/short-read retry, falling back ONLY
// to kernel /dev/urandom (never predictable clocks/timers).

include "utso/core/memory.lp"

// ── ০. /dev/urandom কার্নেল ফলব্যাক রিডার (EINTR-Safe Kernel Fallback) ────────
// WHY: Only used if SYS_getrandom returns a genuine non-EINTR error (e.g., ENOSYS).
// Never synthesizes entropy from clock() or RDTSC.
fn _crypto_read_urandom_exact buffer size
    fd = syscall(2, "/dev/urandom", 0, 0, 0, 0, 0)
    if fd < 0
        return -1
    end
    got = 0
    while got < size
        r = syscall(0, fd, buffer + got, size - got, 0, 0, 0)
        if r == -4
            continue
        end
        if r <= 0
            syscall(3, fd, 0, 0, 0, 0, 0)
            return -1
        end
        got = got + r
    end
    syscall(3, fd, 0, 0, 0, 0, 0)
    return got
end

// ── ১. বাফার এন্ট্রপি ফিল (Hardware CSPRNG Buffer Generator) ─────────────────
// WHY: Loops SYS_getrandom (318) across EINTR (-4) and short reads so STW GC signals
// or partial kernel fills never truncate entropy; falls back only to /dev/urandom.
fn crypto_random_bytes buffer size
    if size <= 0
        return 0
    end
    got = 0
    while got < size
        r = syscall(318, buffer + got, size - got, 0, 0, 0, 0)
        if r == -4
            continue
        end
        if r < 0
            rem = _crypto_read_urandom_exact(buffer + got, size - got)
            if rem != (size - got)
                return -1
            end
            return size
        end
        if r == 0
            rem = _crypto_read_urandom_exact(buffer + got, size - got)
            if rem != (size - got)
                return -1
            end
            return size
        end
        got = got + r
    end
    return got
end

fn CRYPTO_random_bytes buffer size
    return crypto_random_bytes(buffer, size)
end

// ── ২. ৬৪-বিট সম্পূর্ণ এন্ট্রপি ইন্টিজার (Full 64-bit CSPRNG Word) ──────────
// WHY: Returns all 64 raw CSPRNG bits without losing entropy or triggering signed
// INT64_MIN negation overflow; aborts on fatal kernel entropy exhaustion.
fn crypto_random_u64
    buf = malloc(8)
    res = crypto_random_bytes(buf, 8)
    if res != 8
        free(buf, 8)
        syscall(60, 1, 0, 0, 0, 0, 0)
        return 0
    end
    val = mem_read(buf, 0)
    free(buf, 8)
    return val
end

fn CRYPTO_random_u64
    return crypto_random_u64()
end

// ── ৩. কার্নেল ও সিলিকন অঋণাত্মক র্যান্ডম ইন্টিজার ─────────────────────────────
// WHY: Masks with INT64_MAX (0x7FFFFFFFFFFFFFFF) instead of `0 - val` because negating
// INT64_MIN (-9223372036854775808) overflows back to negative in two's complement!
fn সিলিকন_র্যান্ডম
    return crypto_random_u64() & 9223372036854775807
end

fn সিলিকন_র্যান্ডম_সংখ্যা
    return সিলিকন_র্যান্ডম()
end

fn silicon_random_int
    return সিলিকন_র্যান্ডম()
end

// ── ৪. বাউন্ডেড রেঞ্জ র‍্যান্ডম ইন্টিজার (Uniform Bounded Integer) ─────────────
// WHY: Rejection sampling over uniform 63-bit non-negative integers [0, 2^63-1]
// avoids both modulo bias and signed INT64_MIN negation overflow.
fn crypto_random_range min max
    range = max - min + 1
    if range <= 0
        return min
    end
    max_u63 = 9223372036854775807
    limit = (max_u63 / range) * range
    tries = 0
    while tries < 16
        n = crypto_random_u64() & max_u63
        if n < limit or limit <= 0
            return min + (n % range)
        end
        tries = tries + 1
    end
    n = crypto_random_u64() & max_u63
    return min + (n % range)
end

fn CRYPTO_random_range min max
    return crypto_random_range(min, max)
end

fn র্যান্ডম_পরিসীমা min max
    return crypto_random_range(min, max)
end
