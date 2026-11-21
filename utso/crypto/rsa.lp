@! ============================================================================
@! PURE LIPI CRYPTOGRAPHIC STANDARD LIBRARY: RSA PUBLIC KEY CRYPTOGRAPHY
@! Module: utso/crypto/rsa
@! 100% Pure Lipi Implementation — O(log phi) Extended Euclidean Algorithm (ext_gcd)
@! ============================================================================

@fn rsa_gcd(a, b)
  @while b != 0
    temp = b
    b = a % b
    a = temp
  @end
  return a
@end

@fn ext_gcd(a, b)
  @! Extended Euclidean Algorithm: returns [gcd, x, y] such that a*x + b*y = gcd
  @if b == 0
    return [a, 1, 0]
  @end
  x0 = 1
  y0 = 0
  x1 = 0
  y1 = 1
  @while b != 0
    q = a / b
    r = a % b
    a = b
    b = r

    tx = x0 - q * x1
    x0 = x1
    x1 = tx

    ty = y0 - q * y1
    y0 = y1
    y1 = ty
  @end
  return [a, x0, y0]
@end

@fn rsa_mod_inverse(e, phi)
  @! Authentic O(log phi) modular inverse computation via Extended Euclidean Algorithm
  res = ext_gcd(e, phi)
  g = res[0]
  x = res[1]
  @if g != 1
    return 0 @! Inverse does not exist if e and phi are not coprime
  @end
  inv = x % phi
  @if inv < 0
    inv = inv + phi
  @end
  return inv
@end

@fn rsa_mul_mod_64(a, b, mod)
  // WHY: Overflow-safe 64-bit modular multiplication (a * b) % mod via binary doubling,
  // supporting full 62-bit RSA moduli without signed i64 overflow.
  res = 0
  x = a % mod
  @if x < 0 x = x + mod @end
  y = b
  @while y > 0
    @if (y & 1) == 1
      res = res + x
      @if res >= mod res = res - mod @end
    @end
    x = x + x
    @if x >= mod x = x - mod @end
    y = y >> 1
  @end
  return res
@end

@fn rsa_mod_pow(base, exp, mod)
  result = 1
  b = base % mod
  @if b < 0 b = b + mod @end
  e = exp
  @while e > 0
    @if (e & 1) == 1
      result = rsa_mul_mod_64(result, b, mod)
    @end
    e = e >> 1
    b = rsa_mul_mod_64(b, b, mod)
  @end
  return result
@end

@fn rsa_is_prime(n)
  @if n <= 1
    return 0
  @end
  @if n <= 3
    return 1
  @end
  @if (n % 2) == 0 || (n % 3) == 0
    return 0
  @end
  @if n < 25
    return 1
  @end
  @! WHY: Deterministic Miller-Rabin witness set [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
  @! is mathematically exact for all integers < 2^64 in O(k log^3 n).
  d = n - 1
  s = 0
  @while (d & 1) == 0
    d = d >> 1
    s = s + 1
  @end
  bases = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
  bi = 0
  @while bi < bases.len()
    a = bases[bi]
    @if a >= n
      bi = bi + 1
      continue
    @end
    x = rsa_mod_pow(a, d, n)
    @if x == 1 || x == n - 1
      bi = bi + 1
      continue
    @end
    comp = 1
    r = 1
    @while r < s
      x = rsa_mul_mod_64(x, x, n)
      @if x == n - 1
        comp = 0
        break
      @end
      r = r + 1
    @end
    @if comp == 1
      return 0
    @end
    bi = bi + 1
  @end
  return 1
@end

@fn rsa_keygen(p, q)
  n = p * q
  phi = (p - 1) * (q - 1)
  
  @! Check standard international public exponent e = 65537 first
  @if phi > 65537 && rsa_gcd(65537, phi) == 1
    d = rsa_mod_inverse(65537, phi)
    return [65537, d, n]
  @end

  @! Fallback to odd candidate exponents starting from e = 3
  e = 3
  @while e < phi
    @if rsa_gcd(e, phi) == 1
      d = rsa_mod_inverse(e, phi)
      return [e, d, n]
    @end
    e = e + 2
  @end
  return [0, 0, 0]
@end

@fn rsa_raw_encrypt(msg, e, n)
  return rsa_mod_pow(msg, e, n)
@end

@fn rsa_raw_decrypt(cipher, d, n)
  return rsa_mod_pow(cipher, d, n)
@end

@fn rsa_encrypt(key, msg)
  return rsa_mod_pow(msg, key.e, key.n)
@end

@fn rsa_decrypt(key, cipher)
  return rsa_mod_pow(cipher, key.d, key.n)
@end

@! ============================================================================
@! ARBITRARY-PRECISION MULTI-LIMB BIGINT & RSA-OAEP (>= 2048-BIT SAFE)
@! Base = 2^30 (1073741824), little-endian limbs so limb * limb <= 2^60 < 2^63.
@! ============================================================================

@fn bigint_zero()
  return [0]
@end

@fn bigint_one()
  return [1]
@end

@fn bigint_trim(a)
  res = []
  i = 0
  n = a.len()
  @while i < n
    res = res.push(a[i])
    i = i + 1
  @end
  @while res.len() > 1 && res[res.len() - 1] == 0
    out = []
    j = 0
    @while j < res.len() - 1
      out = out.push(res[j])
      j = j + 1
    @end
    res = out
  @end
  @if res.len() == 0
    return [0]
  @end
  return res
@end

@fn bigint_from_int(v)
  @if v <= 0 return [0] @end
  base = 1073741824
  limbs = []
  x = v
  @while x > 0
    limbs = limbs.push(x % base)
    x = x / base
  @end
  return limbs
@end

@fn bigint_cmp(a, b)
  ta = bigint_trim(a)
  tb = bigint_trim(b)
  @if ta.len() > tb.len() return 1 @end
  @if ta.len() < tb.len() return -1 @end
  i = ta.len() - 1
  @while i >= 0
    @if ta[i] > tb[i] return 1 @end
    @if ta[i] < tb[i] return -1 @end
    i = i - 1
  @end
  return 0
@end

@fn bigint_is_zero(a)
  ta = bigint_trim(a)
  @if ta.len() == 1 && ta[0] == 0 return 1 @end
  return 0
@end

@fn bigint_is_even(a)
  @if a.len() == 0 return 1 @end
  @if (a[0] & 1) == 0 return 1 @end
  return 0
@end

@fn bigint_add(a, b)
  base = 1073741824
  na = a.len()
  nb = b.len()
  n = na
  @if nb > n n = nb @end
  out = []
  carry = 0
  i = 0
  @while i < n || carry > 0
    av = 0
    bv = 0
    @if i < na av = a[i] @end
    @if i < nb bv = b[i] @end
    s = av + bv + carry
    out = out.push(s % base)
    carry = s / base
    i = i + 1
  @end
  return bigint_trim(out)
@end

@fn bigint_sub(a, b)
  @! Assumes a >= b; clamps to 0 if a < b.
  @if bigint_cmp(a, b) < 0 return [0] @end
  base = 1073741824
  na = a.len()
  nb = b.len()
  out = []
  borrow = 0
  i = 0
  @while i < na
    bv = 0
    @if i < nb bv = b[i] @end
    d = a[i] - bv - borrow
    @if d < 0
      d = d + base
      borrow = 1
    @else
      borrow = 0
    @end
    out = out.push(d)
    i = i + 1
  @end
  return bigint_trim(out)
@end

@fn bigint_mul(a, b)
  base = 1073741824
  na = a.len()
  nb = b.len()
  out = []
  i = 0
  @while i < na + nb + 1
    out = out.push(0)
    i = i + 1
  @end
  i = 0
  @while i < na
    ai = a[i]
    @if ai != 0
      carry = 0
      j = 0
      @while j < nb
        cur = out[i + j] + (ai * b[j]) + carry
        out[i + j] = cur % base
        carry = cur / base
        j = j + 1
      @end
      out[i + nb] = out[i + nb] + carry
    @end
    i = i + 1
  @end
  return bigint_trim(out)
@end

@fn bigint_bit_len(a)
  ta = bigint_trim(a)
  @if ta.len() == 1 && ta[0] == 0 return 0 @end
  top = ta[ta.len() - 1]
  bits = (ta.len() - 1) * 30
  @while top > 0
    bits = bits + 1
    top = top >> 1
  @end
  return bits
@end

@fn bigint_get_bit(a, bit_idx)
  limb_idx = bit_idx / 30
  @if limb_idx >= a.len() return 0 @end
  return (a[limb_idx] >> (bit_idx % 30)) & 1
@end

@fn bigint_shl1_with_bit(a, low_bit)
  base = 1073741824
  out = []
  carry = low_bit & 1
  i = 0
  @while i < a.len()
    v = ((a[i] << 1) | carry)
    out = out.push(v % base)
    carry = v / base
    i = i + 1
  @end
  @if carry > 0
    out = out.push(carry)
  @end
  return bigint_trim(out)
@end

@fn bigint_shr1(a)
  @if a.len() == 0 return [0] @end
  half_base = 536870912
  out = []
  i = 0
  @while i < a.len()
    out = out.push(0)
    i = i + 1
  @end
  carry = 0
  i = a.len() - 1
  @while i >= 0
    v = a[i]
    out[i] = (v >> 1) + (carry * half_base)
    carry = v & 1
    i = i - 1
  @end
  return bigint_trim(out)
@end

@fn bigint_set_bit(a, bit_idx)
  limb_idx = bit_idx / 30
  out = []
  i = 0
  @while i < a.len()
    out = out.push(a[i])
    i = i + 1
  @end
  @while out.len() <= limb_idx
    out = out.push(0)
  @end
  bit_mask = 1 << (bit_idx % 30)
  out[limb_idx] = out[limb_idx] | bit_mask
  return out
@end

@fn bigint_divmod(a, b)
  @if bigint_is_zero(b) == 1
    return [[0], [0]]
  @end
  @if bigint_cmp(a, b) < 0
    return [[0], bigint_trim(a)]
  @end
  blen = bigint_bit_len(a)
  q = [0]
  r = [0]
  i = blen - 1
  @while i >= 0
    r = bigint_shl1_with_bit(r, bigint_get_bit(a, i))
    @if bigint_cmp(r, b) >= 0
      r = bigint_sub(r, b)
      q = bigint_set_bit(q, i)
    @end
    i = i - 1
  @end
  return [bigint_trim(q), bigint_trim(r)]
@end

@fn bigint_mod(a, m)
  qr = bigint_divmod(a, m)
  return qr[1]
@end

@fn bigint_mod_mul(a, b, m)
  prod = bigint_mul(a, b)
  return bigint_mod(prod, m)
@end

@fn bigint_mod_pow(base_v, exp_v, mod_v)
  @if bigint_is_zero(mod_v) == 1 return [0] @end
  @if mod_v.len() == 1 && mod_v[0] == 1 return [0] @end
  res = [1]
  b = bigint_mod(base_v, mod_v)
  nb = bigint_bit_len(exp_v)
  i = 0
  @while i < nb
    @if bigint_get_bit(exp_v, i) == 1
      res = bigint_mod_mul(res, b, mod_v)
    @end
    @if i + 1 < nb
      b = bigint_mod_mul(b, b, mod_v)
    @end
    i = i + 1
  @end
  return res
@end

@fn bigint_gcd(a, b)
  x = bigint_trim(a)
  y = bigint_trim(b)
  @while bigint_is_zero(y) == 0
    rem = bigint_mod(x, y)
    x = y
    y = rem
  @end
  return x
@end

@fn bigint_mod_inverse(e, phi)
  @! Extended Euclidean algorithm over signed-pair representations [val, is_neg]
  r0 = bigint_trim(phi)
  r1 = bigint_trim(e)
  t0 = [0]
  t0_neg = 0
  t1 = [1]
  t1_neg = 0

  @while bigint_is_zero(r1) == 0
    qr = bigint_divmod(r0, r1)
    q = qr[0]
    next_r = qr[1]
    qt1 = bigint_mul(q, t1)

    @! Compute new_t = t0 - q * t1 cleanly with sign tracking
    new_t = [0]
    new_neg = 0
    @if t0_neg == t1_neg
      @if bigint_cmp(t0, qt1) >= 0
        new_t = bigint_sub(t0, qt1)
        new_neg = t0_neg
      @else
        new_t = bigint_sub(qt1, t0)
        new_neg = 1 - t0_neg
      @end
    @else
      new_t = bigint_add(t0, qt1)
      new_neg = t0_neg
    @end
    @if bigint_is_zero(new_t) == 1 new_neg = 0 @end

    r0 = r1
    r1 = next_r
    t0 = t1
    t0_neg = t1_neg
    t1 = new_t
    t1_neg = new_neg
  @end

  @if r0.len() != 1 || r0[0] != 1
    return [0]
  @end
  t0 = bigint_mod(t0, phi)
  @if t0_neg == 1 && bigint_is_zero(t0) == 0
    return bigint_sub(phi, t0)
  @end
  return t0
@end

@fn bigint_is_probable_prime(n, rounds)
  @if bigint_cmp(n, [2]) < 0 return 0 @end
  @if n.len() == 1 && (n[0] == 2 || n[0] == 3) return 1 @end
  @if bigint_is_even(n) == 1 return 0 @end

  small_primes = [3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
  si = 0
  @while si < small_primes.len()
    sp = [small_primes[si]]
    @if bigint_cmp(n, sp) == 0 return 1 @end
    @if bigint_is_zero(bigint_mod(n, sp)) == 1 return 0 @end
    si = si + 1
  @end

  n_minus_1 = bigint_sub(n, [1])
  d = n_minus_1
  s = 0
  @while bigint_is_even(d) == 1
    d = bigint_shr1(d)
    s = s + 1
  @end

  witnesses = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37]
  lim = rounds
  @if lim <= 0 || lim > witnesses.len() lim = witnesses.len() @end
  wi = 0
  @while wi < lim
    a = [witnesses[wi]]
    @if bigint_cmp(a, n) >= 0 break @end
    x = bigint_mod_pow(a, d, n)
    @if (x.len() == 1 && x[0] == 1) || bigint_cmp(x, n_minus_1) == 0
      wi = wi + 1
      continue
    @end
    comp = 1
    r = 1
    @while r < s
      x = bigint_mod_mul(x, x, n)
      @if bigint_cmp(x, n_minus_1) == 0
        comp = 0
        break
      @end
      r = r + 1
    @end
    @if comp == 1
      return 0
    @end
    wi = wi + 1
  @end
  return 1
@end

@fn bigint_from_bytes(bytes)
  res = [0]
  b256 = [256]
  i = 0
  @while i < bytes.len()
    res = bigint_add(bigint_mul(res, b256), [bytes[i] & 255])
    i = i + 1
  @end
  return res
@end

@fn bigint_to_bytes(a, out_len)
  tmp = bigint_trim(a)
  rev = []
  b256 = [256]
  @while rev.len() < out_len
    qr = bigint_divmod(tmp, b256)
    tmp = qr[0]
    rem = qr[1]
    rev = rev.push(rem[0] & 255)
  @end
  @if bigint_is_zero(tmp) == 0
    return []
  @end
  out = []
  i = rev.len() - 1
  @while i >= 0
    out = out.push(rev[i])
    i = i - 1
  @end
  return out
@end

@fn _rsa_rotr32(v, n)
  m = 4294967295
  u = v & m
  @if n == 0 return u @end
  return ((u >> n) | ((u << (32 - n)) & m)) & m
@end

@fn _rsa_sha256_bytes(msg_bytes)
  k = [
    1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993, 2453635748, 2870763221,
    3624381080, 310598401, 607225278, 1426881987, 1925078388, 2162078206, 2614888103, 3248222580,
    3835390401, 4022224774, 264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
    2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711, 113926993, 338241895,
    666307205, 773529912, 1294757372, 1396182291, 1695183700, 1986661051, 2177026350, 2456956037,
    2730485921, 2820302411, 3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
    430227734, 506948616, 659060556, 883997877, 958139571, 1322822218, 1537002063, 1747873779,
    1955562222, 2024104815, 2227730452, 2361852424, 2428436474, 2756734187, 3204031479, 3329325298
  ]
  st = [1779033703, 3144134277, 1013904242, 2773480762, 1359893119, 2600822924, 528734635, 1541459225]
  padded = []
  i = 0
  mlen = msg_bytes.len()
  @while i < mlen
    padded = padded.push(msg_bytes[i] & 255)
    i = i + 1
  @end
  padded = padded.push(128)
  @while (padded.len() % 64) != 56
    padded = padded.push(0)
  @end
  bit_len = mlen * 8
  bi = 7
  @while bi >= 0
    padded = padded.push((bit_len >> (bi * 8)) & 255)
    bi = bi - 1
  @end
  off = 0
  @while off < padded.len()
    w = []
    wi = 0
    @while wi < 16
      j = off + (wi * 4)
      wv = ((padded[j] & 255) << 24) | ((padded[j + 1] & 255) << 16) | ((padded[j + 2] & 255) << 8) | (padded[j + 3] & 255)
      w = w.push(wv & 4294967295)
      wi = wi + 1
    @end
    @while wi < 64
      x0 = w[wi - 15]
      x1 = w[wi - 2]
      s0 = _rsa_rotr32(x0, 7) ^ _rsa_rotr32(x0, 18) ^ ((x0 & 4294967295) >> 3)
      s1 = _rsa_rotr32(x1, 17) ^ _rsa_rotr32(x1, 19) ^ ((x1 & 4294967295) >> 10)
      w = w.push((w[wi - 16] + s0 + w[wi - 7] + s1) & 4294967295)
      wi = wi + 1
    @end
    a = st[0]
    b = st[1]
    c = st[2]
    d = st[3]
    e = st[4]
    f = st[5]
    g = st[6]
    h = st[7]
    ri = 0
    @while ri < 64
      s1 = _rsa_rotr32(e, 6) ^ _rsa_rotr32(e, 11) ^ _rsa_rotr32(e, 25)
      ch = (e & f) ^ ((~e) & g)
      t1 = (h + s1 + ch + k[ri] + w[ri]) & 4294967295
      s0 = _rsa_rotr32(a, 2) ^ _rsa_rotr32(a, 13) ^ _rsa_rotr32(a, 22)
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
      ri = ri + 1
    @end
    st[0] = (st[0] + a) & 4294967295
    st[1] = (st[1] + b) & 4294967295
    st[2] = (st[2] + c) & 4294967295
    st[3] = (st[3] + d) & 4294967295
    st[4] = (st[4] + e) & 4294967295
    st[5] = (st[5] + f) & 4294967295
    st[6] = (st[6] + g) & 4294967295
    st[7] = (st[7] + h) & 4294967295
    off = off + 64
  @end
  digest = []
  di = 0
  @while di < 8
    wd = st[di]
    digest = digest.push((wd >> 24) & 255)
    digest = digest.push((wd >> 16) & 255)
    digest = digest.push((wd >> 8) & 255)
    digest = digest.push(wd & 255)
    di = di + 1
  @end
  return digest
@end

@fn rsa_mgf1_sha256(seed, mask_len)
  out = []
  counter = 0
  @while out.len() < mask_len
    inp = []
    i = 0
    @while i < seed.len()
      inp = inp.push(seed[i] & 255)
      i = i + 1
    @end
    inp = inp.push((counter >> 24) & 255)
    inp = inp.push((counter >> 16) & 255)
    inp = inp.push((counter >> 8) & 255)
    inp = inp.push(counter & 255)
    blk = _rsa_sha256_bytes(inp)
    bi = 0
    @while bi < blk.len() && out.len() < mask_len
      out = out.push(blk[bi])
      bi = bi + 1
    @end
    counter = counter + 1
  @end
  return out
@end

@fn rsa_oaep_encode(msg_bytes, label_bytes, k_len, seed32)
  hlen = 32
  mlen = msg_bytes.len()
  @if k_len < (2 * hlen) + 2 + mlen || seed32.len() != hlen
    return []
  @end
  lhash = _rsa_sha256_bytes(label_bytes)
  ps_len = k_len - mlen - (2 * hlen) - 2
  db = []
  i = 0
  @while i < hlen
    db = db.push(lhash[i])
    i = i + 1
  @end
  i = 0
  @while i < ps_len
    db = db.push(0)
    i = i + 1
  @end
  db = db.push(1)
  i = 0
  @while i < mlen
    db = db.push(msg_bytes[i] & 255)
    i = i + 1
  @end

  db_mask = rsa_mgf1_sha256(seed32, db.len())
  masked_db = []
  i = 0
  @while i < db.len()
    masked_db = masked_db.push((db[i] ^ db_mask[i]) & 255)
    i = i + 1
  @end
  seed_mask = rsa_mgf1_sha256(masked_db, hlen)
  masked_seed = []
  i = 0
  @while i < hlen
    masked_seed = masked_seed.push((seed32[i] ^ seed_mask[i]) & 255)
    i = i + 1
  @end

  em = [0]
  i = 0
  @while i < hlen
    em = em.push(masked_seed[i])
    i = i + 1
  @end
  i = 0
  @while i < masked_db.len()
    em = em.push(masked_db[i])
    i = i + 1
  @end
  return em
@end

@fn rsa_oaep_decode(em_bytes, label_bytes)
  hlen = 32
  k_len = em_bytes.len()
  @if k_len < (2 * hlen) + 2 return [] @end
  lhash = _rsa_sha256_bytes(label_bytes)
  y_nonzero = em_bytes[0] & 255
  masked_seed = []
  i = 0
  @while i < hlen
    masked_seed = masked_seed.push(em_bytes[1 + i] & 255)
    i = i + 1
  @end
  masked_db = []
  i = 1 + hlen
  @while i < k_len
    masked_db = masked_db.push(em_bytes[i] & 255)
    i = i + 1
  @end
  seed_mask = rsa_mgf1_sha256(masked_db, hlen)
  seed = []
  i = 0
  @while i < hlen
    seed = seed.push((masked_seed[i] ^ seed_mask[i]) & 255)
    i = i + 1
  @end
  db_mask = rsa_mgf1_sha256(seed, masked_db.len())
  db = []
  i = 0
  @while i < masked_db.len()
    db = db.push((masked_db[i] ^ db_mask[i]) & 255)
    i = i + 1
  @end

  lhash_bad = 0
  i = 0
  @while i < hlen
    lhash_bad = lhash_bad | ((db[i] ^ lhash[i]) & 255)
    i = i + 1
  @end

  @! Constant-time delimiter search across PS || 0x01 || M after lHash'
  found_one = 0
  delim_idx = 0
  bad_ps = 0
  i = hlen
  @while i < db.len()
    b = db[i]
    is_one = 0
    @if b == 1 is_one = 1 @end
    first_one = is_one & (1 - found_one)
    @if first_one == 1
      found_one = 1
      delim_idx = i
    @elif found_one == 0 && b != 0
      bad_ps = 1
    @end
    i = i + 1
  @end

  @if y_nonzero != 0 || lhash_bad != 0 || found_one != 1 || bad_ps != 0
    return []
  @end
  out = []
  i = delim_idx + 1
  @while i < db.len()
    out = out.push(db[i])
    i = i + 1
  @end
  return out
@end

@fn rsa_bigint_encrypt_oaep(msg_bytes, e_bi, n_bi, k_len, seed32)
  em = rsa_oaep_encode(msg_bytes, [], k_len, seed32)
  @if em.len() != k_len return [] @end
  m_int = bigint_from_bytes(em)
  @if bigint_cmp(m_int, n_bi) >= 0 return [] @end
  c_int = bigint_mod_pow(m_int, e_bi, n_bi)
  return bigint_to_bytes(c_int, k_len)
@end

@fn rsa_bigint_decrypt_oaep(ct_bytes, d_bi, n_bi, k_len)
  @if ct_bytes.len() != k_len return [] @end
  c_int = bigint_from_bytes(ct_bytes)
  @if bigint_cmp(c_int, n_bi) >= 0 return [] @end
  m_int = bigint_mod_pow(c_int, d_bi, n_bi)
  em = bigint_to_bytes(m_int, k_len)
  return rsa_oaep_decode(em, [])
@end
