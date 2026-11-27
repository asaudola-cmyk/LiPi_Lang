// ==============================================================================
// 🔢 LIPI ARBITRARY-PRECISION BIGINT & EXACT DECIMAL (utso/core/bigint.lp)
// ⚡ 100% Pure LiPi | 0% GMP | 0% libc | Base-10^9 Limb Arithmetic + Exact Base-10 Decimal
// ==============================================================================
//
// WHY THIS MODULE:
// Hardware 64-bit integers overflow past 2^63-1 and binary IEEE-754 floats cannot
// represent exact base-10 fractions like 0.1 + 0.2 == 0.3. Using base 10^9 limbs
// guarantees (10^9 - 1)^2 < 10^18 < INT64_MAX so limb multiplication and division
// never overflow signed 64-bit machine registers while making decimal I/O O(N).
// ==============================================================================

include "utso/core/memory.lp"
include "utso/core/string.lp"

BI_BASE = 1000000000

struct BigInt
    bi_sign
    bi_limbs
end

struct Decimal
    dec_coeff
    dec_scale
end

// ── 1. Internal Limb Normalization & Magnitude Primitives ─────────────────────

fn _bi_trim_limbs limbs
    while len(limbs) > 0 and get(limbs, len(limbs) - 1) == 0
        pop(limbs)
    end
    return limbs
end

fn _bi_make sign limbs
    _bi_trim_limbs(limbs)
    bi = BigInt()
    if len(limbs) == 0 or sign == 0
        bi.bi_sign = 0
        bi.bi_limbs = list()
    else
        if sign < 0
            bi.bi_sign = 0 - 1
        else
            bi.bi_sign = 1
        end
        bi.bi_limbs = limbs
    end
    return bi
end

fn _bi_clone_limbs src
    out = list()
    i = 0
    n = len(src)
    while i < n
        push(out, get(src, i))
        i = i + 1
    end
    return out
end

fn _bi_cmp_mag a_limbs b_limbs
    na = len(a_limbs)
    nb = len(b_limbs)
    if na < nb return 0 - 1 end
    if na > nb return 1 end
    i = na - 1
    while i >= 0
        av = get(a_limbs, i)
        bv = get(b_limbs, i)
        if av < bv return 0 - 1 end
        if av > bv return 1 end
        i = i - 1
    end
    return 0
end

fn _bi_add_mag a_limbs b_limbs
    na = len(a_limbs)
    nb = len(b_limbs)
    n = na
    if nb > n n = nb end
    out = list()
    carry = 0
    i = 0
    while i < n or carry > 0
        s = carry
        if i < na s = s + get(a_limbs, i) end
        if i < nb s = s + get(b_limbs, i) end
        if s >= BI_BASE
            push(out, s - BI_BASE)
            carry = 1
        else
            push(out, s)
            carry = 0
        end
        i = i + 1
    end
    return _bi_trim_limbs(out)
end

fn _bi_sub_mag a_limbs b_limbs
    // Precondition: |a_limbs| >= |b_limbs|
    na = len(a_limbs)
    nb = len(b_limbs)
    out = list()
    borrow = 0
    i = 0
    while i < na
        av = get(a_limbs, i) - borrow
        bv = 0
        if i < nb bv = get(b_limbs, i) end
        if av < bv
            push(out, (av + BI_BASE) - bv)
            borrow = 1
        else
            push(out, av - bv)
            borrow = 0
        end
        i = i + 1
    end
    return _bi_trim_limbs(out)
end

fn _bi_mul_scalar limbs k
    if k <= 0 or len(limbs) == 0
        return list()
    end
    if k == 1
        return _bi_clone_limbs(limbs)
    end
    out = list()
    carry = 0
    i = 0
    n = len(limbs)
    while i < n
        prod = (get(limbs, i) * k) + carry
        push(out, prod % BI_BASE)
        carry = prod / BI_BASE
        i = i + 1
    end
    while carry > 0
        push(out, carry % BI_BASE)
        carry = carry / BI_BASE
    end
    return _bi_trim_limbs(out)
end

fn _bi_mul_mag a_limbs b_limbs
    na = len(a_limbs)
    nb = len(b_limbs)
    if na == 0 or nb == 0
        return list()
    end
    out = list()
    i = 0
    while i < na + nb
        push(out, 0)
        i = i + 1
    end
    i = 0
    while i < na
        av = get(a_limbs, i)
        if av != 0
            carry = 0
            j = 0
            while j < nb
                idx = i + j
                // WHY: av <= 10^9-1, bv <= 10^9-1, out[idx] <= 10^9-1, carry <= 10^9 => acc < 10^18 < INT64_MAX!
                acc = get(out, idx) + (av * get(b_limbs, j)) + carry
                list_set(out, idx, acc % BI_BASE)
                carry = acc / BI_BASE
                j = j + 1
            end
            k = i + nb
            while carry > 0
                acc = get(out, k) + carry
                list_set(out, k, acc % BI_BASE)
                carry = acc / BI_BASE
                k = k + 1
            end
        end
        i = i + 1
    end
    return _bi_trim_limbs(out)
end

fn _bi_divmod_u32 limbs d
    // Fast O(N) division of magnitude by 1-limb positive integer 0 < d < BI_BASE
    n = len(limbs)
    if n == 0
        return [list(), 0]
    end
    q_rev = list()
    rem = 0
    i = n - 1
    while i >= 0
        cur = (rem * BI_BASE) + get(limbs, i)
        push(q_rev, cur / d)
        rem = cur % d
        i = i - 1
    end
    q = list()
    j = len(q_rev) - 1
    while j >= 0
        push(q, get(q_rev, j))
        j = j - 1
    end
    return [_bi_trim_limbs(q), rem]
end

fn _bi_divmod_mag u_limbs v_limbs
    // WHY: Exact arbitrary-precision base-10^9 long division returning [q_limbs, r_limbs].
    // Uses O(N) short division for 1-limb divisors and exact binary-searched quotient limbs
    // in [0, 10^9-1] for multi-limb divisors (30 iterations/limb, zero estimate edge bugs).
    cmp0 = _bi_cmp_mag(u_limbs, v_limbs)
    if cmp0 < 0
        return [list(), _bi_clone_limbs(u_limbs)]
    end
    if cmp0 == 0
        return [[1], list()]
    end
    if len(v_limbs) == 1
        sr = _bi_divmod_u32(u_limbs, get(v_limbs, 0))
        r_l = list()
        if get(sr, 1) > 0
            push(r_l, get(sr, 1))
        end
        return [get(sr, 0), r_l]
    end

    nu = len(u_limbs)
    q_rev = list()
    rem = list()
    i = nu - 1
    while i >= 0
        // Shift remainder left by 1 base-10^9 limb and bring down u_limbs[i]
        new_rem = list()
        push(new_rem, get(u_limbs, i))
        ri = 0
        while ri < len(rem)
            push(new_rem, get(rem, ri))
            ri = ri + 1
        end
        rem = _bi_trim_limbs(new_rem)

        if _bi_cmp_mag(rem, v_limbs) < 0
            push(q_rev, 0)
        else
            // Binary search exact quotient limb qd in [1, BI_BASE - 1]
            lo = 1
            hi = BI_BASE - 1
            best_q = 0
            while lo <= hi
                mid = lo + ((hi - lo) / 2)
                prod = _bi_mul_scalar(v_limbs, mid)
                c = _bi_cmp_mag(prod, rem)
                if c <= 0
                    best_q = mid
                    lo = mid + 1
                else
                    hi = mid - 1
                end
            end
            push(q_rev, best_q)
            if best_q > 0
                rem = _bi_sub_mag(rem, _bi_mul_scalar(v_limbs, best_q))
            end
        end
        i = i - 1
    end

    q = list()
    j = len(q_rev) - 1
    while j >= 0
        push(q, get(q_rev, j))
        j = j - 1
    end
    return [_bi_trim_limbs(q), _bi_trim_limbs(rem)]
end

// ── 2. Public Signed BigInt API ───────────────────────────────────────────────

fn bigint_zero
    return _bi_make(0, list())
end

fn bigint_one
    return _bi_make(1, [1])
end

fn bigint_from_i64 n
    // WHY: Handles INT64_MIN (-9223372036854775808) without signed negation overflow by
    // dividing negative values BEFORE negating quotient and remainder!
    if n == 0
        return bigint_zero()
    end
    limbs = list()
    if n > 0
        cur = n
        while cur > 0
            push(limbs, cur % BI_BASE)
            cur = cur / BI_BASE
        end
        return _bi_make(1, limbs)
    end
    cur = n
    while cur < 0
        q = cur / BI_BASE
        r = cur % BI_BASE
        if r < 0
            r = 0 - r
        end
        push(limbs, r)
        cur = q
    end
    return _bi_make(0 - 1, limbs)
end

fn bigint_from_str s
    // WHY: Parses arbitrary-length signed decimal strings in 9-digit chunks right-to-left.
    n = len(s)
    st = 0
    while st < n
        c = mem_byte_read(s, st) & 255
        if c == 32 or c == 9 or c == 10 or c == 13
            st = st + 1
        else
            break
        end
    end
    en = n
    while en > st
        c = mem_byte_read(s, en - 1) & 255
        if c == 32 or c == 9 or c == 10 or c == 13
            en = en - 1
        else
            break
        end
    end
    if st >= en
        return bigint_zero()
    end
    sign = 1
    c0 = mem_byte_read(s, st) & 255
    if c0 == 45
        sign = 0 - 1
        st = st + 1
    elif c0 == 43
        st = st + 1
    end
    // Strip leading zeros and validate digits
    while st < en and (mem_byte_read(s, st) & 255) == 48
        st = st + 1
    end
    if st >= en
        return bigint_zero()
    end
    // Stop at first non-digit if any trailing garbage
    dig_end = st
    while dig_end < en
        d = mem_byte_read(s, dig_end) & 255
        if d < 48 or d > 57
            break
        end
        dig_end = dig_end + 1
    end
    if dig_end <= st
        return bigint_zero()
    end
    limbs = list()
    pos = dig_end
    while pos > st
        chunk_st = pos - 9
        if chunk_st < st chunk_st = st end
        val = 0
        k = chunk_st
        while k < pos
            val = (val * 10) + ((mem_byte_read(s, k) & 255) - 48)
            k = k + 1
        end
        push(limbs, val)
        pos = chunk_st
    end
    return _bi_make(sign, limbs)
end

fn bigint_to_str a: BigInt
    if a == 0 or a.bi_sign == 0 or len(a.bi_limbs) == 0
        return "0"
    end
    n = len(a.bi_limbs)
    bb = buf_new((n * 9) + 4)
    if a.bi_sign < 0
        buf_write_byte(bb, 45)
    end
    top = get(a.bi_limbs, n - 1)
    buf_write_str(bb, str(top))
    i = n - 2
    while i >= 0
        lv = get(a.bi_limbs, i)
        ls = str(lv)
        pad = 9 - len(ls)
        while pad > 0
            buf_write_byte(bb, 48)
            pad = pad - 1
        end
        buf_write_str(bb, ls)
        i = i - 1
    end
    out = buf_to_str(bb)
    buf_free(bb)
    return out
end

fn bigint_abs a: BigInt
    if a == 0 or a.bi_sign == 0 return bigint_zero() end
    return _bi_make(1, _bi_clone_limbs(a.bi_limbs))
end

fn bigint_neg a: BigInt
    if a == 0 or a.bi_sign == 0 return bigint_zero() end
    return _bi_make(0 - a.bi_sign, _bi_clone_limbs(a.bi_limbs))
end

fn bigint_cmp a: BigInt b: BigInt
    if a.bi_sign < b.bi_sign return 0 - 1 end
    if a.bi_sign > b.bi_sign return 1 end
    if a.bi_sign == 0 return 0 end
    mc = _bi_cmp_mag(a.bi_limbs, b.bi_limbs)
    if a.bi_sign < 0
        return 0 - mc
    end
    return mc
end

fn bigint_add a: BigInt b: BigInt
    if a.bi_sign == 0 return _bi_make(b.bi_sign, _bi_clone_limbs(b.bi_limbs)) end
    if b.bi_sign == 0 return _bi_make(a.bi_sign, _bi_clone_limbs(a.bi_limbs)) end
    if a.bi_sign == b.bi_sign
        return _bi_make(a.bi_sign, _bi_add_mag(a.bi_limbs, b.bi_limbs))
    end
    mc = _bi_cmp_mag(a.bi_limbs, b.bi_limbs)
    if mc == 0
        return bigint_zero()
    elif mc > 0
        return _bi_make(a.bi_sign, _bi_sub_mag(a.bi_limbs, b.bi_limbs))
    end
    return _bi_make(b.bi_sign, _bi_sub_mag(b.bi_limbs, a.bi_limbs))
end

fn bigint_sub a: BigInt b: BigInt
    return bigint_add(a, bigint_neg(b))
end

fn bigint_mul a: BigInt b: BigInt
    if a.bi_sign == 0 or b.bi_sign == 0
        return bigint_zero()
    end
    return _bi_make(a.bi_sign * b.bi_sign, _bi_mul_mag(a.bi_limbs, b.bi_limbs))
end

fn bigint_divmod a: BigInt b: BigInt
    // WHY: Truncated-toward-zero division satisfying a == q*b + r and |r| < |b|.
    if b == 0 or b.bi_sign == 0
        return [bigint_zero(), bigint_zero()]
    end
    if a == 0 or a.bi_sign == 0
        return [bigint_zero(), bigint_zero()]
    end
    dm = _bi_divmod_mag(a.bi_limbs, b.bi_limbs)
    q = _bi_make(a.bi_sign * b.bi_sign, get(dm, 0))
    r = _bi_make(a.bi_sign, get(dm, 1))
    return [q, r]
end

fn bigint_pow_mod base: BigInt exp: BigInt modulus: BigInt
    // WHY: Arbitrary-precision square-and-multiply modular exponentiation (base^exp mod modulus)
    // supporting 256-bit+ cryptographic moduli with canonical non-negative residue in [0, m-1].
    if modulus == 0 or modulus.bi_sign <= 0
        return bigint_zero()
    end
    one = bigint_one()
    if bigint_cmp(modulus, one) == 0
        return bigint_zero()
    end
    if exp == 0 or exp.bi_sign < 0
        return bigint_zero()
    end
    if exp.bi_sign == 0
        return one
    end

    // Reduce base into [0, modulus - 1]
    dm0 = bigint_divmod(base, modulus)
    cur_b = get(dm0, 1)
    if cur_b.bi_sign < 0
        cur_b = bigint_add(cur_b, modulus)
    end

    res = one
    e_limbs = _bi_clone_limbs(exp.bi_limbs)
    while len(e_limbs) > 0
        if (get(e_limbs, 0) & 1) == 1
            prod = bigint_mul(res, cur_b)
            res = get(bigint_divmod(prod, modulus), 1)
        end
        // Right-shift exponent by 1 bit via exact short division by 2
        e_limbs = get(_bi_divmod_u32(e_limbs, 2), 0)
        if len(e_limbs) > 0
            sq = bigint_mul(cur_b, cur_b)
            cur_b = get(bigint_divmod(sq, modulus), 1)
        end
    end
    return res
end

// ── 3. Exact Arbitrary-Precision Base-10 Decimal API ──────────────────────────

fn _bi_pow10 k
    if k <= 0 return bigint_one() end
    zero_limbs = k / 9
    rem_d = k % 9
    p = 1
    i = 0
    while i < rem_d
        p = p * 10
        i = i + 1
    end
    limbs = list()
    z = 0
    while z < zero_limbs
        push(limbs, 0)
        z = z + 1
    end
    push(limbs, p)
    return _bi_make(1, limbs)
end

fn _dec_make coeff: BigInt scale
    d = Decimal()
    if coeff == 0 or coeff.bi_sign == 0
        d.dec_coeff = bigint_zero()
        d.dec_scale = 0
    else
        d.dec_coeff = coeff
        d.dec_scale = scale
    end
    return d
end

fn decimal_normalize d: Decimal
    // WHY: Strips redundant trailing fractional zeros (`0.2500` -> `0.25`, `3.00` -> `3`)
    // while keeping exact numerical value unchanged.
    if d == 0 or d.dec_coeff.bi_sign == 0
        return _dec_make(bigint_zero(), 0)
    end
    c = d.dec_coeff
    sc = d.dec_scale
    while sc > 0 and c.bi_sign != 0
        if (get(c.bi_limbs, 0) % 10) != 0
            break
        end
        q_l = get(_bi_divmod_u32(c.bi_limbs, 10), 0)
        c = _bi_make(c.bi_sign, q_l)
        sc = sc - 1
    end
    return _dec_make(c, sc)
end

fn decimal_from_str s
    // WHY: Parses exact base-10 decimals with optional sign, decimal point, and `e`/`E` exponent.
    n = len(s)
    st = 0
    while st < n
        c = mem_byte_read(s, st) & 255
        if c == 32 or c == 9 or c == 10 or c == 13
            st = st + 1
        else
            break
        end
    end
    en = n
    while en > st
        c = mem_byte_read(s, en - 1) & 255
        if c == 32 or c == 9 or c == 10 or c == 13
            en = en - 1
        else
            break
        end
    end
    if st >= en
        return _dec_make(bigint_zero(), 0)
    end
    sign_str = ""
    c0 = mem_byte_read(s, st) & 255
    if c0 == 45
        sign_str = "-"
        st = st + 1
    elif c0 == 43
        st = st + 1
    end

    bb = buf_new((en - st) + 4)
    if len(sign_str) > 0
        buf_write_byte(bb, 45)
    end
    seen_dot = 0
    frac_digits = 0
    exp_val = 0
    i = st
    while i < en
        ch = mem_byte_read(s, i) & 255
        if ch >= 48 and ch <= 57
            buf_write_byte(bb, ch)
            if seen_dot == 1
                frac_digits = frac_digits + 1
            end
        elif ch == 46 and seen_dot == 0
            seen_dot = 1
        elif ch == 101 or ch == 69 // 'e' or 'E'
            ei = i + 1
            esign = 1
            if ei < en
                ec = mem_byte_read(s, ei) & 255
                if ec == 45
                    esign = 0 - 1
                    ei = ei + 1
                elif ec == 43
                    ei = ei + 1
                end
            end
            ev = 0
            while ei < en
                ed = mem_byte_read(s, ei) & 255
                if ed >= 48 and ed <= 57
                    ev = (ev * 10) + (ed - 48)
                    ei = ei + 1
                else
                    break
                end
            end
            exp_val = esign * ev
            break
        else
            break
        end
        i = i + 1
    end
    dig_s = buf_to_str(bb)
    buf_free(bb)

    coeff = bigint_from_str(dig_s)
    if coeff.bi_sign == 0
        return _dec_make(bigint_zero(), 0)
    end
    scale = frac_digits - exp_val
    if scale < 0
        coeff = bigint_mul(coeff, _bi_pow10(0 - scale))
        scale = 0
    end
    return _dec_make(coeff, scale)
end

fn decimal_to_str d: Decimal
    if d == 0 or d.dec_coeff == 0 or d.dec_coeff.bi_sign == 0
        return "0"
    end
    neg = 0
    if d.dec_coeff.bi_sign < 0
        neg = 1
    end
    mag_s = bigint_to_str(bigint_abs(d.dec_coeff))
    sc = d.dec_scale
    if sc <= 0
        if neg == 1
            return "-" + mag_s
        end
        return mag_s
    end
    mlen = len(mag_s)
    bb = buf_new(mlen + sc + 8)
    if neg == 1
        buf_write_byte(bb, 45)
    end
    if mlen <= sc
        buf_write_str(bb, "0.")
        z = sc - mlen
        while z > 0
            buf_write_byte(bb, 48)
            z = z - 1
        end
        buf_write_str(bb, mag_s)
    else
        int_len = mlen - sc
        buf_write_str(bb, str_sub(mag_s, 0, int_len))
        buf_write_byte(bb, 46)
        buf_write_str(bb, str_sub(mag_s, int_len, mlen))
    end
    out = buf_to_str(bb)
    buf_free(bb)
    return out
end

fn decimal_cmp a: Decimal b: Decimal
    ca = a.dec_coeff
    cb = b.dec_coeff
    if a.dec_scale < b.dec_scale
        ca = bigint_mul(ca, _bi_pow10(b.dec_scale - a.dec_scale))
    elif b.dec_scale < a.dec_scale
        cb = bigint_mul(cb, _bi_pow10(a.dec_scale - b.dec_scale))
    end
    return bigint_cmp(ca, cb)
end

fn decimal_add a: Decimal b: Decimal
    ca = a.dec_coeff
    cb = b.dec_coeff
    sc = a.dec_scale
    if a.dec_scale < b.dec_scale
        ca = bigint_mul(ca, _bi_pow10(b.dec_scale - a.dec_scale))
        sc = b.dec_scale
    elif b.dec_scale < a.dec_scale
        cb = bigint_mul(cb, _bi_pow10(a.dec_scale - b.dec_scale))
        sc = a.dec_scale
    end
    return _dec_make(bigint_add(ca, cb), sc)
end

fn decimal_sub a: Decimal b: Decimal
    ca = a.dec_coeff
    cb = b.dec_coeff
    sc = a.dec_scale
    if a.dec_scale < b.dec_scale
        ca = bigint_mul(ca, _bi_pow10(b.dec_scale - a.dec_scale))
        sc = b.dec_scale
    elif b.dec_scale < a.dec_scale
        cb = bigint_mul(cb, _bi_pow10(a.dec_scale - b.dec_scale))
        sc = a.dec_scale
    end
    return _dec_make(bigint_sub(ca, cb), sc)
end

fn decimal_mul a: Decimal b: Decimal
    return _dec_make(bigint_mul(a.dec_coeff, b.dec_coeff), a.dec_scale + b.dec_scale)
end

fn decimal_div(a: Decimal, b: Decimal, prec: i64 = 18) -> Decimal
    // WHY: Exact base-10 decimal division scaled to `prec` fractional digits (default 18)
    // with half-up rounding and trailing fractional zero normalization.
    if b == 0 or b.dec_coeff == 0 or b.dec_coeff.bi_sign == 0
        return _dec_make(bigint_zero(), 0)
    end
    if a == 0 or a.dec_coeff == 0 or a.dec_coeff.bi_sign == 0
        return _dec_make(bigint_zero(), 0)
    end
    p = prec
    if p < 0 p = 0 end
    // Value = (a_coeff / b_coeff) * 10^(b_scale - a_scale).
    // Multiply numerator by 10^(p + b_scale - a_scale) (or denominator if negative)
    shift = p + b.dec_scale - a.dec_scale
    num = bigint_abs(a.dec_coeff)
    den = bigint_abs(b.dec_coeff)
    if shift > 0
        num = bigint_mul(num, _bi_pow10(shift))
    elif shift < 0
        den = bigint_mul(den, _bi_pow10(0 - shift))
    end
    dm = bigint_divmod(num, den)
    q = get(dm, 0)
    r = get(dm, 1)
    // Half-up rounding: if 2 * r >= den, increment quotient by 1
    if r.bi_sign > 0
        r2 = bigint_add(r, r)
        if bigint_cmp(r2, den) >= 0
            q = bigint_add(q, bigint_one())
        end
    end
    res_sign = a.dec_coeff.bi_sign * b.dec_coeff.bi_sign
    q_signed = _bi_make(res_sign, q.bi_limbs)
    return decimal_normalize(_dec_make(q_signed, p))
end
