@! ============================================================================
@! LIPI SOVEREIGN CRYPTOGRAPHY: PURE LIPI NIST P-256 & P-384 ECDSA ENGINE
@! Module: utso/crypto/p256_ecdsa.lp
@! Standard: FIPS 186-5 / SEC 1 / RFC 8446 TLS 1.3 (secp256r1 & secp384r1)
@! 100% Pure Lipi Implementation — Zero OpenSSL / Zero Libc / Zero C
@! ============================================================================
@!
@! ARCHITECTURE:
@! - Uniform Base-2^24 (16777216) Mutable Limb Arithmetic (ecbi_*):
@!   24-bit limbs guarantee product sums fit strictly inside signed 64-bit i64
@!   (max sum <= 16 * 2^48 = 2^52 < 2^63 - 1) with zero heap allocations inside
@!   Montgomery CIOS reduction.
@! - Jacobian Projective Coordinates (a = -3 mod p) avoid modular inversions
@!   during scalar multiplication; Shamir's trick computes [u1]G + [u2]Q in a
@!   single bit pass with 1 final modular inverse.
@! ============================================================================

import "utso/core/collections"
import "utso/core/string"
import "utso/crypto/sha256"
import "utso/crypto/sha512"

@fn _ec_base() return 16777216 @end
@fn _ec_mask() return 16777215 @end

@struct EcMontCtx
  ecm_k: i64
  ecm_mod: array
  ecm_n0p: i64
  ecm_one: array
  ecm_r2: array
@end

@struct EcCurveParams
  ecv_bits: i64
  ecv_coord_len: i64
  ecv_k: i64
  ecv_p_ctx: EcMontCtx
  ecv_n_ctx: EcMontCtx
  ecv_p_limbs: array
  ecv_n_limbs: array
  ecv_b_mont: array
  ecv_gx_mont: array
  ecv_gy_mont: array
  ecv_sqrt_exp: array
@end

@struct EcJacPoint
  ecp_x: array
  ecp_y: array
  ecp_z: array
  ecp_inf: i64
@end

@! ----------------------------------------------------------------------------
@! 1. Base-2^24 Fixed-Width Limb Primitives (Little-Endian Limbs)
@! ----------------------------------------------------------------------------

@fn ecbi_zero(k)
  out = []
  i = 0
  @while i < k
    out = out.push(0)
    i = i + 1
  @end
  return out
@end

@fn ecbi_copy(a, k)
  out = []
  i = 0
  al = a.len()
  @while i < k
    v = 0
    @if i < al v = a[i] @end
    out = out.push(v)
    i = i + 1
  @end
  return out
@end

@fn ecbi_is_zero(a)
  i = 0
  @while i < a.len()
    @if a[i] != 0 return 0 @end
    i = i + 1
  @end
  return 1
@end

@fn ecbi_cmp(a, b, k)
  i = k - 1
  @while i >= 0
    av = 0
    bv = 0
    @if i < a.len() av = a[i] @end
    @if i < b.len() bv = b[i] @end
    @if av > bv return 1 @end
    @if av < bv return -1 @end
    i = i - 1
  @end
  return 0
@end

@fn ecbi_from_bytes(bytes, k)
  @! WHY: Converts big-endian byte slice into little-endian 24-bit limbs without division.
  limbs = ecbi_zero(k)
  n = bytes.len()
  li = 0
  pos = n
  @while pos > 0 && li < k
    b0 = bytes[pos - 1] & 255
    b1 = 0
    b2 = 0
    @if pos >= 2 b1 = bytes[pos - 2] & 255 @end
    @if pos >= 3 b2 = bytes[pos - 3] & 255 @end
    val = b0 | (b1 * 256) | (b2 * 65536)
    limbs[li] = val
    li = li + 1
    pos = pos - 3
  @end
  return limbs
@end

@fn ecbi_to_bytes(a, out_len)
  out = []
  i = out_len - 1
  @while i >= 0
    li = i / 3
    rem = i % 3
    lv = 0
    @if li < a.len() lv = a[li] @end
    bv = (lv >> (rem * 8)) & 255
    out = out.push(bv)
    i = i - 1
  @end
  return out
@end

@fn ecbi_get_bit(a, bit_idx)
  li = bit_idx / 24
  @if li >= a.len() return 0 @end
  return (a[li] >> (bit_idx % 24)) & 1
@end

@fn ecbi_sub_cond(a, m, k)
  @if ecbi_cmp(a, m, k) < 0
    return ecbi_copy(a, k)
  @end
  res = ecbi_zero(k)
  borrow = 0
  i = 0
  base = 16777216
  @while i < k
    d = a[i] - m[i] - borrow
    @if d < 0
      d = d + base
      borrow = 1
    @else
      borrow = 0
    @end
    res[i] = d
    i = i + 1
  @end
  return res
@end

@fn ecbi_mod_add(a, b, m, k)
  res = ecbi_zero(k)
  carry = 0
  i = 0
  @while i < k
    s = a[i] + b[i] + carry
    res[i] = s & 16777215
    carry = s >> 24
    i = i + 1
  @end
  @if carry > 0 || ecbi_cmp(res, m, k) >= 0
    borrow = 0
    j = 0
    @while j < k
      d = res[j] - m[j] - borrow
      @if d < 0
        d = d + 16777216
        borrow = 1
      @else
        borrow = 0
      @end
      res[j] = d
      j = j + 1
    @end
  @end
  return res
@end

@fn ecbi_mod_sub(a, b, m, k)
  res = ecbi_zero(k)
  borrow = 0
  i = 0
  @while i < k
    d = a[i] - b[i] - borrow
    @if d < 0
      d = d + 16777216
      borrow = 1
    @else
      borrow = 0
    @end
    res[i] = d
    i = i + 1
  @end
  @if borrow != 0
    carry = 0
    j = 0
    @while j < k
      s = res[j] + m[j] + carry
      res[j] = s & 16777215
      carry = s >> 24
      j = j + 1
    @end
  @end
  return res
@end

@fn ecbi_shr1(a, k)
  out = ecbi_zero(k)
  carry = 0
  i = k - 1
  @while i >= 0
    v = a[i]
    out[i] = (v >> 1) | (carry * 8388608)
    carry = v & 1
    i = i - 1
  @end
  return out
@end

@fn ecbi_add_one(a, k)
  out = ecbi_copy(a, k)
  carry = 1
  i = 0
  @while i < k && carry > 0
    s = out[i] + carry
    out[i] = s & 16777215
    carry = s >> 24
    i = i + 1
  @end
  return out
@end

@! ----------------------------------------------------------------------------
@! 2. Montgomery CIOS Domain & Modular Inversion
@! ----------------------------------------------------------------------------

@fn ec_mont_compute_n0p(m0)
  @! WHY: Newton iteration x <- x * (2 - m0 * x) mod 2^24 yields m0^-1 mod 2^24 in 5 steps.
  inv = 1
  step = 0
  @while step < 5
    t = (m0 * inv) & 16777215
    fac = (2 - t) & 16777215
    inv = (inv * fac) & 16777215
    step = step + 1
  @end
  return (16777216 - inv) & 16777215
@end

@fn ec_mont_ctx_new(mod_limbs, k)
  m = ecbi_copy(mod_limbs, k)
  n0p = ec_mont_compute_n0p(m[0])
  one = ecbi_zero(k)
  one[0] = 1

  @! Compute R = 2^(24*k) mod m and R^2 mod m via modular bit-doubling (zero divmod loops)
  cur = ecbi_copy(one, k)
  r_mod = []
  total_bits = k * 48
  half_bits = k * 24
  bit = 1
  @while bit <= total_bits
    carry = 0
    j = 0
    @while j < k
      s = (cur[j] << 1) + carry
      cur[j] = s & 16777215
      carry = s >> 24
      j = j + 1
    @end
    @if carry > 0 || ecbi_cmp(cur, m, k) >= 0
      borrow = 0
      j = 0
      @while j < k
        d = cur[j] - m[j] - borrow
        @if d < 0
          d = d + 16777216
          borrow = 1
        @else
          borrow = 0
        @end
        cur[j] = d
        j = j + 1
      @end
    @end
    @if bit == half_bits
      r_mod = ecbi_copy(cur, k)
    @end
    bit = bit + 1
  @end
  return {
    ecm_k: k,
    ecm_mod: m,
    ecm_n0p: n0p,
    ecm_one: r_mod,
    ecm_r2: cur
  }
@end

@fn ec_mont_mul(a, b, ctx)
  k = ctx.ecm_k
  m = ctx.ecm_mod
  n0p = ctx.ecm_n0p
  t = ecbi_zero(k + 2)

  i = 0
  @while i < k
    bi = b[i]
    carry = 0
    j = 0
    @while j < k
      s = t[j] + (a[j] * bi) + carry
      t[j] = s & 16777215
      carry = s >> 24
      j = j + 1
    @end
    sk = t[k] + carry
    t[k] = sk & 16777215
    t[k + 1] = sk >> 24

    u = (t[0] * n0p) & 16777215
    s0 = t[0] + (u * m[0])
    carry = s0 >> 24
    j = 1
    @while j < k
      s = t[j] + (u * m[j]) + carry
      t[j - 1] = s & 16777215
      carry = s >> 24
      j = j + 1
    @end
    sk2 = t[k] + carry
    t[k - 1] = sk2 & 16777215
    t[k] = t[k + 1] + (sk2 >> 24)
    t[k + 1] = 0
    i = i + 1
  @end

  need_sub = 0
  @if t[k] > 0
    need_sub = 1
  @elif ecbi_cmp(t, m, k) >= 0
    need_sub = 1
  @end

  res = ecbi_zero(k)
  @if need_sub == 1
    borrow = 0
    j = 0
    @while j < k
      d = t[j] - m[j] - borrow
      @if d < 0
        d = d + 16777216
        borrow = 1
      @else
        borrow = 0
      @end
      res[j] = d
      j = j + 1
    @end
  @else
    j = 0
    @while j < k
      res[j] = t[j]
      j = j + 1
    @end
  @end
  return res
@end

@fn ec_mont_sqr(a, ctx)
  return ec_mont_mul(a, a, ctx)
@end

@fn ec_mont_to(a, ctx)
  return ec_mont_mul(a, ctx.ecm_r2, ctx)
@end

@fn ec_mont_from(a_m, ctx)
  one = ecbi_zero(ctx.ecm_k)
  one[0] = 1
  return ec_mont_mul(a_m, one, ctx)
@end

@fn ec_mont_pow_norm(base_m, exp_limbs, ctx, total_bits)
  res = ecbi_copy(ctx.ecm_one, ctx.ecm_k)
  cur = ecbi_copy(base_m, ctx.ecm_k)
  bit = 0
  @while bit < total_bits
    @if ecbi_get_bit(exp_limbs, bit) == 1
      res = ec_mont_mul(res, cur, ctx)
    @end
    @if bit + 1 < total_bits
      cur = ec_mont_sqr(cur, ctx)
    @end
    bit = bit + 1
  @end
  return res
@end

@fn ecbi_mod_inv_binary(a_norm, p_limbs, k)
  @! WHY: Binary Extended Euclidean Algorithm mod prime p computes a^-1 mod p cleanly
  @! with zero multiplications or divisions for any bit width.
  @if ecbi_is_zero(a_norm) == 1 return ecbi_zero(k) @end
  u = ecbi_sub_cond(a_norm, p_limbs, k)
  v = ecbi_copy(p_limbs, k)
  x1 = ecbi_zero(k)
  x1[0] = 1
  x2 = ecbi_zero(k)
  p_plus_1 = ecbi_add_one(p_limbs, k)

  @while ecbi_is_zero(u) == 0 && ecbi_is_zero(v) == 0
    @while (u[0] & 1) == 0
      u = ecbi_shr1(u, k)
      @if (x1[0] & 1) == 0
        x1 = ecbi_shr1(x1, k)
      @else
        @! x1 = (x1 + p) / 2 without overflowing k limbs when computing bit carry
        carry = 0
        i = 0
        @while i < k
          s = x1[i] + p_limbs[i] + carry
          x1[i] = s & 16777215
          carry = s >> 24
          i = i + 1
        @end
        x1 = ecbi_shr1(x1, k)
        @if carry > 0
          x1[k - 1] = x1[k - 1] | (carry * 8388608)
        @end
      @end
    @end

    @while (v[0] & 1) == 0
      v = ecbi_shr1(v, k)
      @if (x2[0] & 1) == 0
        x2 = ecbi_shr1(x2, k)
      @else
        carry = 0
        i = 0
        @while i < k
          s = x2[i] + p_limbs[i] + carry
          x2[i] = s & 16777215
          carry = s >> 24
          i = i + 1
        @end
        x2 = ecbi_shr1(x2, k)
        @if carry > 0
          x2[k - 1] = x2[k - 1] | (carry * 8388608)
        @end
      @end
    @end

    @if ecbi_cmp(u, v, k) >= 0
      u = ecbi_mod_sub(u, v, p_limbs, k)
      x1 = ecbi_mod_sub(x1, x2, p_limbs, k)
    @else
      v = ecbi_mod_sub(v, u, p_limbs, k)
      x2 = ecbi_mod_sub(x2, x1, p_limbs, k)
    @end
  @end

  @if ecbi_is_zero(u) == 0
    return ecbi_sub_cond(x1, p_limbs, k)
  @end
  return ecbi_sub_cond(x2, p_limbs, k)
@end

@fn ecbi_reduce_mod_n(val_bytes, n_limbs, k, bits_max)
  @! Reduces a big-endian byte string whose bit length == bits_max (at most 1 subtraction if >= n)
  @if val_bytes.len() == k * 3 || val_bytes.len() == 32 || val_bytes.len() == 48
    @! Fast path for digest matching curve size
    v = ecbi_from_bytes(val_bytes, k)
    @while ecbi_cmp(v, n_limbs, k) >= 0
      v = ecbi_sub_cond(v, n_limbs, k)
    @end
    return v
  @end
  v = ecbi_from_bytes(val_bytes, k)
  @while ecbi_cmp(v, n_limbs, k) >= 0
    v = ecbi_sub_cond(v, n_limbs, k)
  @end
  return v
@end

@! ----------------------------------------------------------------------------
@! 3. FIPS 186-5 NIST P-256 (secp256r1) & P-384 (secp384r1) Parameters
@! ----------------------------------------------------------------------------

@fn ec_curve_p256()
  p_bytes = [
    255,255,255,255, 0,0,0,1, 0,0,0,0, 0,0,0,0,
    0,0,0,0, 255,255,255,255, 255,255,255,255, 255,255,255,255
  ]
  b_bytes = [
    90,198,53,216, 170,58,147,231, 179,235,189,85, 118,152,134,188,
    101,29,6,176, 204,83,176,246, 59,206,60,62, 39,210,96,75
  ]
  gx_bytes = [
    107,23,209,242, 225,44,66,71, 248,188,230,229, 99,164,64,242,
    119,3,125,129, 45,235,51,160, 244,161,57,69, 216,152,194,150
  ]
  gy_bytes = [
    79,227,66,226, 254,26,127,155, 142,231,235,74, 124,15,158,22,
    43,206,51,87, 107,49,94,206, 203,182,64,104, 55,191,81,245
  ]
  n_bytes = [
    255,255,255,255, 0,0,0,0, 255,255,255,255, 255,255,255,255,
    188,230,250,173, 167,23,158,132, 243,185,202,194, 252,99,37,81
  ]
  k = 11
  p_l = ecbi_from_bytes(p_bytes, k)
  n_l = ecbi_from_bytes(n_bytes, k)
  p_ctx = ec_mont_ctx_new(p_l, k)
  n_ctx = ec_mont_ctx_new(n_l, k)
  sqrt_exp = ecbi_shr1(ecbi_shr1(ecbi_add_one(p_l, k), k), k)
  return {
    ecv_bits: 256,
    ecv_coord_len: 32,
    ecv_k: k,
    ecv_p_ctx: p_ctx,
    ecv_n_ctx: n_ctx,
    ecv_p_limbs: p_l,
    ecv_n_limbs: n_l,
    ecv_b_mont: ec_mont_to(ecbi_from_bytes(b_bytes, k), p_ctx),
    ecv_gx_mont: ec_mont_to(ecbi_from_bytes(gx_bytes, k), p_ctx),
    ecv_gy_mont: ec_mont_to(ecbi_from_bytes(gy_bytes, k), p_ctx),
    ecv_sqrt_exp: sqrt_exp
  }
@end

@fn ec_curve_p384()
  p_bytes = [
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,254,
    255,255,255,255, 0,0,0,0, 0,0,0,0, 255,255,255,255
  ]
  b_bytes = [
    179,49,47,167, 226,62,231,228, 152,142,5,107, 227,248,45,25,
    24,29,156,110, 254,129,65,18, 3,20,8,143, 80,19,135,90,
    198,86,57,141, 138,46,209,157, 42,133,200,237, 211,236,42,239
  ]
  gx_bytes = [
    170,135,202,34, 190,139,5,55, 142,177,199,30, 243,32,173,116,
    110,29,59,98, 139,167,155,152, 89,247,65,224, 130,84,42,56,
    85,2,242,93, 191,85,41,108, 58,84,94,56, 114,118,10,183
  ]
  gy_bytes = [
    54,23,222,74, 150,38,44,111, 93,158,152,191, 146,146,220,41,
    248,244,29,189, 40,154,20,124, 233,218,49,19, 181,240,184,192,
    10,96,177,206, 29,126,129,157, 122,67,29,124, 144,234,14,95
  ]
  n_bytes = [
    255,255,255,255, 255,255,255,255, 255,255,255,255, 255,255,255,255,
    255,255,255,255, 255,255,255,255, 199,99,77,129, 244,55,45,223,
    88,26,13,178, 72,176,167,122, 236,236,25,106, 204,197,41,115
  ]
  k = 16
  p_l = ecbi_from_bytes(p_bytes, k)
  n_l = ecbi_from_bytes(n_bytes, k)
  p_ctx = ec_mont_ctx_new(p_l, k)
  n_ctx = ec_mont_ctx_new(n_l, k)
  sqrt_exp = ecbi_shr1(ecbi_shr1(ecbi_add_one(p_l, k), k), k)
  return {
    ecv_bits: 384,
    ecv_coord_len: 48,
    ecv_k: k,
    ecv_p_ctx: p_ctx,
    ecv_n_ctx: n_ctx,
    ecv_p_limbs: p_l,
    ecv_n_limbs: n_l,
    ecv_b_mont: ec_mont_to(ecbi_from_bytes(b_bytes, k), p_ctx),
    ecv_gx_mont: ec_mont_to(ecbi_from_bytes(gx_bytes, k), p_ctx),
    ecv_gy_mont: ec_mont_to(ecbi_from_bytes(gy_bytes, k), p_ctx),
    ecv_sqrt_exp: sqrt_exp
  }
@end

@! ----------------------------------------------------------------------------
@! 4. Jacobian Projective Curve Arithmetic (a = -3 mod p)
@! ----------------------------------------------------------------------------

@fn ec_jac_inf(curve)
  k = curve.ecv_k
  z = ecbi_zero(k)
  return {
    ecp_x: z,
    ecp_y: z,
    ecp_z: z,
    ecp_inf: 1
  }
@end

@fn ec_jac_double(pt, curve)
  @if pt.ecp_inf == 1 || ecbi_is_zero(pt.ecp_y) == 1
    return ec_jac_inf(curve)
  @end
  k = curve.ecv_k
  p = curve.ecv_p_limbs
  ctx = curve.ecv_p_ctx

  x1 = pt.ecp_x
  y1 = pt.ecp_y
  z1 = pt.ecp_z

  z1z1 = ec_mont_sqr(z1, ctx)
  xpz = ecbi_mod_add(x1, z1z1, p, k)
  xmz = ecbi_mod_sub(x1, z1z1, p, k)
  t = ec_mont_mul(xpz, xmz, ctx)
  m = ecbi_mod_add(ecbi_mod_add(t, t, p, k), t, p, k)

  y1sq = ec_mont_sqr(y1, ctx)
  xy1sq = ec_mont_mul(x1, y1sq, ctx)
  xy2 = ecbi_mod_add(xy1sq, xy1sq, p, k)
  s = ecbi_mod_add(xy2, xy2, p, k)

  m2 = ec_mont_sqr(m, ctx)
  two_s = ecbi_mod_add(s, s, p, k)
  x3 = ecbi_mod_sub(m2, two_s, p, k)

  y1_4 = ec_mont_sqr(y1sq, ctx)
  y1_4_2 = ecbi_mod_add(y1_4, y1_4, p, k)
  y1_4_4 = ecbi_mod_add(y1_4_2, y1_4_2, p, k)
  y1_4_8 = ecbi_mod_add(y1_4_4, y1_4_4, p, k)

  s_mx3 = ecbi_mod_sub(s, x3, p, k)
  y3 = ecbi_mod_sub(ec_mont_mul(m, s_mx3, ctx), y1_4_8, p, k)

  yz = ec_mont_mul(y1, z1, ctx)
  z3 = ecbi_mod_add(yz, yz, p, k)
  @if ecbi_is_zero(z3) == 1
    return ec_jac_inf(curve)
  @end

  return {
    ecp_x: x3,
    ecp_y: y3,
    ecp_z: z3,
    ecp_inf: 0
  }
@end

@fn ec_jac_add(p1, p2, curve)
  @if p1.ecp_inf == 1 return p2 @end
  @if p2.ecp_inf == 1 return p1 @end
  k = curve.ecv_k
  p = curve.ecv_p_limbs
  ctx = curve.ecv_p_ctx

  z1z1 = ec_mont_sqr(p1.ecp_z, ctx)
  z2z2 = ec_mont_sqr(p2.ecp_z, ctx)
  u1 = ec_mont_mul(p1.ecp_x, z2z2, ctx)
  u2 = ec_mont_mul(p2.ecp_x, z1z1, ctx)

  s1 = ec_mont_mul(p1.ecp_y, ec_mont_mul(p2.ecp_z, z2z2, ctx), ctx)
  s2 = ec_mont_mul(p2.ecp_y, ec_mont_mul(p1.ecp_z, z1z1, ctx), ctx)

  h = ecbi_mod_sub(u2, u1, p, k)
  r = ecbi_mod_sub(s2, s1, p, k)
  @if ecbi_is_zero(h) == 1
    @if ecbi_is_zero(r) == 1
      return ec_jac_double(p1, curve)
    @end
    return ec_jac_inf(curve)
  @end

  hh = ec_mont_sqr(h, ctx)
  hhh = ec_mont_mul(h, hh, ctx)
  v = ec_mont_mul(u1, hh, ctx)

  r2 = ec_mont_sqr(r, ctx)
  two_v = ecbi_mod_add(v, v, p, k)
  x3 = ecbi_mod_sub(ecbi_mod_sub(r2, hhh, p, k), two_v, p, k)

  v_mx3 = ecbi_mod_sub(v, x3, p, k)
  y3 = ecbi_mod_sub(ec_mont_mul(r, v_mx3, ctx), ec_mont_mul(s1, hhh, ctx), p, k)
  z3 = ec_mont_mul(h, ec_mont_mul(p1.ecp_z, p2.ecp_z, ctx), ctx)
  @if ecbi_is_zero(z3) == 1
    return ec_jac_inf(curve)
  @end

  return {
    ecp_x: x3,
    ecp_y: y3,
    ecp_z: z3,
    ecp_inf: 0
  }
@end

@fn ec_jac_to_affine_norm(pt, curve)
  @if pt.ecp_inf == 1
    return [0, ecbi_zero(curve.ecv_k), ecbi_zero(curve.ecv_k)]
  @end
  k = curve.ecv_k
  ctx = curve.ecv_p_ctx
  z_norm = ec_mont_from(pt.ecp_z, ctx)
  @if ecbi_is_zero(z_norm) == 1
    return [0, ecbi_zero(k), ecbi_zero(k)]
  @end
  z_inv_norm = ecbi_mod_inv_binary(z_norm, curve.ecv_p_limbs, k)
  z_inv_m = ec_mont_to(z_inv_norm, ctx)
  z_inv2 = ec_mont_sqr(z_inv_m, ctx)
  z_inv3 = ec_mont_mul(z_inv2, z_inv_m, ctx)
  ax = ec_mont_from(ec_mont_mul(pt.ecp_x, z_inv2, ctx), ctx)
  ay = ec_mont_from(ec_mont_mul(pt.ecp_y, z_inv3, ctx), ctx)
  return [1, ax, ay]
@end

@fn ec_scalar_mul(scalar_limbs, pt, curve)
  res = ec_jac_inf(curve)
  i = curve.ecv_bits - 1
  @while i >= 0
    res = ec_jac_double(res, curve)
    @if ecbi_get_bit(scalar_limbs, i) == 1
      res = ec_jac_add(res, pt, curve)
    @end
    i = i - 1
  @end
  return res
@end

@fn ec_shamir_mul(u1_limbs, g_pt, u2_limbs, q_pt, curve)
  @! WHY: Computes [u1]G + [u2]Q in a single MSB-to-LSB loop using precomputed G + Q.
  gpq = ec_jac_add(g_pt, q_pt, curve)
  res = ec_jac_inf(curve)
  i = curve.ecv_bits - 1
  @while i >= 0
    res = ec_jac_double(res, curve)
    b1 = ecbi_get_bit(u1_limbs, i)
    b2 = ecbi_get_bit(u2_limbs, i)
    @if b1 == 1 && b2 == 1
      res = ec_jac_add(res, gpq, curve)
    @elif b1 == 1
      res = ec_jac_add(res, g_pt, curve)
    @elif b2 == 1
      res = ec_jac_add(res, q_pt, curve)
    @end
    i = i - 1
  @end
  return res
@end

@! ----------------------------------------------------------------------------
@! 5. SEC1 Public Key Decoding & Strict Curve Equation Validation
@! ----------------------------------------------------------------------------

@fn ec_decode_public_key(pub_bytes, curve)
  clen = curve.ecv_coord_len
  plen = pub_bytes.len()
  k = curve.ecv_k
  ctx = curve.ecv_p_ctx
  p = curve.ecv_p_limbs

  @if plen < 1 + clen
    return ec_jac_inf(curve)
  @end
  tag = pub_bytes[0] & 255
  x_bytes = []
  i = 0
  @while i < clen
    x_bytes = x_bytes.push(pub_bytes[1 + i] & 255)
    i = i + 1
  @end
  x_norm = ecbi_from_bytes(x_bytes, k)
  @if ecbi_cmp(x_norm, p, k) >= 0
    return ec_jac_inf(curve)
  @end
  x_m = ec_mont_to(x_norm, ctx)
  x2_m = ec_mont_sqr(x_m, ctx)
  x3_m = ec_mont_mul(x2_m, x_m, ctx)
  three_x_m = ecbi_mod_add(ecbi_mod_add(x_m, x_m, p, k), x_m, p, k)
  rhs_m = ecbi_mod_add(ecbi_mod_sub(x3_m, three_x_m, p, k), curve.ecv_b_mont, p, k)

  y_norm = ecbi_zero(k)
  y_m = ecbi_zero(k)
  @if tag == 4
    @if plen != 1 + (2 * clen)
      return ec_jac_inf(curve)
    @end
    y_bytes = []
    i = 0
    @while i < clen
      y_bytes = y_bytes.push(pub_bytes[1 + clen + i] & 255)
      i = i + 1
    @end
    y_norm = ecbi_from_bytes(y_bytes, k)
    @if ecbi_cmp(y_norm, p, k) >= 0
      return ec_jac_inf(curve)
    @end
    y_m = ec_mont_to(y_norm, ctx)
  @elif tag == 2 || tag == 3
    @if plen != 1 + clen
      return ec_jac_inf(curve)
    @end
    @! Both NIST P-256 and P-384 satisfy p == 3 (mod 4), so sqrt = rhs^((p+1)/4) mod p
    y_m = ec_mont_pow_norm(rhs_m, curve.ecv_sqrt_exp, ctx, curve.ecv_bits)
    y_norm = ec_mont_from(y_m, ctx)
    want_odd = tag & 1
    @if (y_norm[0] & 1) != want_odd
      y_norm = ecbi_mod_sub(p, y_norm, p, k)
      y_m = ec_mont_to(y_norm, ctx)
    @end
  @else
    return ec_jac_inf(curve)
  @end

  @! MANDATORY: Confirm y^2 == x^3 - 3x + b (mod p) so off-curve invalid points fail closed
  lhs_m = ec_mont_sqr(y_m, ctx)
  @if ecbi_cmp(lhs_m, rhs_m, k) != 0
    return ec_jac_inf(curve)
  @end

  return {
    ecp_x: x_m,
    ecp_y: y_m,
    ecp_z: ecbi_copy(ctx.ecm_one, k),
    ecp_inf: 0
  }
@end

@! ----------------------------------------------------------------------------
@! 6. Canonical DER ECDSA Signature Codec & Core Verify / Sign
@! ----------------------------------------------------------------------------

@fn _ec_read_der_int(sig, off, max_end, coord_len)
  @if off + 2 > max_end return [0, [], off] @end
  @if (sig[off] & 255) != 2 return [0, [], off] @end
  lb = sig[off + 1] & 255
  pos = off + 2
  vlen = lb
  @if lb >= 128
    nb = lb & 127
    @if nb == 0 || nb > 2 || pos + nb > max_end
      return [0, [], off]
    @end
    vlen = 0
    k = 0
    @while k < nb
      vlen = (vlen * 256) + (sig[pos + k] & 255)
      k = k + 1
    @end
    pos = pos + nb
  @end
  @if vlen <= 0 || pos + vlen > max_end
    return [0, [], off]
  @end
  @! Reject negative ASN.1 INTEGERs and non-canonical leading zero octets
  first = sig[pos] & 255
  @if (first & 128) != 0 return [0, [], off] @end
  @if vlen > 1 && first == 0 && ((sig[pos + 1] & 255) & 128) == 0
    return [0, [], off]
  @end
  @if first == 0
    pos = pos + 1
    vlen = vlen - 1
  @end
  @if vlen <= 0 || vlen > coord_len
    return [0, [], off]
  @end
  raw = []
  i = 0
  @while i < vlen
    raw = raw.push(sig[pos + i] & 255)
    i = i + 1
  @end
  return [1, raw, pos + vlen]
@end

@fn ecdsa_parse_der_sig(sig_bytes, coord_len)
  slen = sig_bytes.len()
  @if slen < 8 || (sig_bytes[0] & 255) != 48
    return [0, [], []]
  @end
  lb = sig_bytes[1] & 255
  off = 2
  seq_len = lb
  @if lb >= 128
    nb = lb & 127
    @if nb == 0 || nb > 2 || 2 + nb > slen
      return [0, [], []]
    @end
    seq_len = 0
    k = 0
    @while k < nb
      seq_len = (seq_len * 256) + (sig_bytes[2 + k] & 255)
      k = k + 1
    @end
    off = 2 + nb
  @end
  @if off + seq_len != slen
    return [0, [], []]
  @end

  r_res = _ec_read_der_int(sig_bytes, off, slen, coord_len)
  @if r_res[0] != 1 return [0, [], []] @end
  s_res = _ec_read_der_int(sig_bytes, r_res[2], slen, coord_len)
  @if s_res[0] != 1 || s_res[2] != slen
    return [0, [], []]
  @end
  return [1, r_res[1], s_res[1]]
@end

@fn _ec_encode_der_int(val_bytes)
  start = 0
  @while start < val_bytes.len() - 1 && (val_bytes[start] & 255) == 0
    start = start + 1
  @end
  body = []
  @if (val_bytes[start] & 255) >= 128
    body = body.push(0)
  @end
  i = start
  @while i < val_bytes.len()
    body = body.push(val_bytes[i] & 255)
    i = i + 1
  @end
  out = [2, body.len() & 255]
  i = 0
  @while i < body.len()
    out = out.push(body[i])
    i = i + 1
  @end
  return out
@end

@fn ecdsa_encode_der_sig(r_bytes, s_bytes)
  r_tlv = _ec_encode_der_int(r_bytes)
  s_tlv = _ec_encode_der_int(s_bytes)
  tot = r_tlv.len() + s_tlv.len()
  out = [48]
  @if tot < 128
    out = out.push(tot)
  @else
    out = out.push(129)
    out = out.push(tot & 255)
  @end
  i = 0
  @while i < r_tlv.len()
    out = out.push(r_tlv[i])
    i = i + 1
  @end
  i = 0
  @while i < s_tlv.len()
    out = out.push(s_tlv[i])
    i = i + 1
  @end
  return out
@end

@fn ecdsa_verify_hash_raw(curve, pub_bytes, hash_bytes, r_bytes, s_bytes)
  k = curve.ecv_k
  n = curve.ecv_n_limbs
  n_ctx = curve.ecv_n_ctx

  r_l = ecbi_from_bytes(r_bytes, k)
  s_l = ecbi_from_bytes(s_bytes, k)
  @if ecbi_is_zero(r_l) == 1 || ecbi_cmp(r_l, n, k) >= 0
    return 0
  @end
  @if ecbi_is_zero(s_l) == 1 || ecbi_cmp(s_l, n, k) >= 0
    return 0
  @end

  q_pt = ec_decode_public_key(pub_bytes, curve)
  @if q_pt.ecp_inf == 1
    return 0
  @end

  @! Leftmost coord_len bytes of hash truncated mod n
  z_slice = []
  i = 0
  lim = curve.ecv_coord_len
  @while i < lim && i < hash_bytes.len()
    z_slice = z_slice.push(hash_bytes[i] & 255)
    i = i + 1
  @end
  z_l = ecbi_reduce_mod_n(z_slice, n, k, curve.ecv_bits)

  w_norm = ecbi_mod_inv_binary(s_l, n, k)
  @if ecbi_is_zero(w_norm) == 1
    return 0
  @end

  w_m = ec_mont_to(w_norm, n_ctx)
  z_m = ec_mont_to(z_l, n_ctx)
  r_m = ec_mont_to(r_l, n_ctx)
  u1 = ec_mont_from(ec_mont_mul(z_m, w_m, n_ctx), n_ctx)
  u2 = ec_mont_from(ec_mont_mul(r_m, w_m, n_ctx), n_ctx)

  g_pt = {
    ecp_x: curve.ecv_gx_mont,
    ecp_y: curve.ecv_gy_mont,
    ecp_z: ecbi_copy(curve.ecv_p_ctx.ecm_one, k),
    ecp_inf: 0
  }
  r_pt = ec_shamir_mul(u1, g_pt, u2, q_pt, curve)
  aff = ec_jac_to_affine_norm(r_pt, curve)
  @if aff[0] != 1
    return 0
  @end

  xr = aff[1]
  @while ecbi_cmp(xr, n, k) >= 0
    xr = ecbi_sub_cond(xr, n, k)
  @end
  @if ecbi_cmp(xr, r_l, k) == 0
    return 1
  @end
  return 0
@end

@fn ecdsa_p256_verify_der(pub_bytes, msg_sha256_bytes, der_sig_bytes)
  @if msg_sha256_bytes.len() < 32 return 0 @end
  parsed = ecdsa_parse_der_sig(der_sig_bytes, 32)
  @if parsed[0] != 1 return 0 @end
  curve = ec_curve_p256()
  return ecdsa_verify_hash_raw(curve, pub_bytes, msg_sha256_bytes, parsed[1], parsed[2])
@end

@fn ecdsa_p384_verify_der(pub_bytes, msg_sha384_bytes, der_sig_bytes)
  @if msg_sha384_bytes.len() < 48 return 0 @end
  parsed = ecdsa_parse_der_sig(der_sig_bytes, 48)
  @if parsed[0] != 1 return 0 @end
  curve = ec_curve_p384()
  return ecdsa_verify_hash_raw(curve, pub_bytes, msg_sha384_bytes, parsed[1], parsed[2])
@end

@fn _ec_keygen_curve(curve, scalar_bytes)
  k = curve.ecv_k
  n = curve.ecv_n_limbs
  d = ecbi_reduce_mod_n(scalar_bytes, n, k, curve.ecv_bits)
  @if ecbi_is_zero(d) == 1
    d[0] = 1
  @end
  g_pt = {
    ecp_x: curve.ecv_gx_mont,
    ecp_y: curve.ecv_gy_mont,
    ecp_z: ecbi_copy(curve.ecv_p_ctx.ecm_one, k),
    ecp_inf: 0
  }
  q_pt = ec_scalar_mul(d, g_pt, curve)
  aff = ec_jac_to_affine_norm(q_pt, curve)
  xb = ecbi_to_bytes(aff[1], curve.ecv_coord_len)
  yb = ecbi_to_bytes(aff[2], curve.ecv_coord_len)
  pub = [4]
  i = 0
  @while i < xb.len()
    pub = pub.push(xb[i])
    i = i + 1
  @end
  i = 0
  @while i < yb.len()
    pub = pub.push(yb[i])
    i = i + 1
  @end
  return pub
@end

@fn _ec_sign_curve_der(curve, priv_bytes, hash_bytes, nonce_bytes)
  k = curve.ecv_k
  n = curve.ecv_n_limbs
  n_ctx = curve.ecv_n_ctx

  d = ecbi_reduce_mod_n(priv_bytes, n, k, curve.ecv_bits)
  k_nonce = ecbi_reduce_mod_n(nonce_bytes, n, k, curve.ecv_bits)
  @if ecbi_is_zero(k_nonce) == 1
    k_nonce[0] = 1
  @end
  g_pt = {
    ecp_x: curve.ecv_gx_mont,
    ecp_y: curve.ecv_gy_mont,
    ecp_z: ecbi_copy(curve.ecv_p_ctx.ecm_one, k),
    ecp_inf: 0
  }
  r_pt = ec_scalar_mul(k_nonce, g_pt, curve)
  aff = ec_jac_to_affine_norm(r_pt, curve)
  @if aff[0] != 1 return [] @end
  r_l = aff[1]
  @while ecbi_cmp(r_l, n, k) >= 0
    r_l = ecbi_sub_cond(r_l, n, k)
  @end
  @if ecbi_is_zero(r_l) == 1 return [] @end

  z_l = ecbi_reduce_mod_n(hash_bytes, n, k, curve.ecv_bits)
  kinv = ecbi_mod_inv_binary(k_nonce, n, k)
  rd = ec_mont_from(ec_mont_mul(ec_mont_to(r_l, n_ctx), ec_mont_to(d, n_ctx), n_ctx), n_ctx)
  z_plus_rd = ecbi_mod_add(z_l, rd, n, k)
  s_l = ec_mont_from(ec_mont_mul(ec_mont_to(kinv, n_ctx), ec_mont_to(z_plus_rd, n_ctx), n_ctx), n_ctx)
  @if ecbi_is_zero(s_l) == 1 return [] @end

  r_bytes = ecbi_to_bytes(r_l, curve.ecv_coord_len)
  s_bytes = ecbi_to_bytes(s_l, curve.ecv_coord_len)
  return ecdsa_encode_der_sig(r_bytes, s_bytes)
@end

@fn ecdsa_p256_keygen_from_scalar(priv32_bytes)
  return _ec_keygen_curve(ec_curve_p256(), priv32_bytes)
@end

@fn ecdsa_p384_keygen_from_scalar(priv48_bytes)
  return _ec_keygen_curve(ec_curve_p384(), priv48_bytes)
@end

@fn ecdsa_p256_sign_der(priv32_bytes, msg_sha256_bytes, nonce32_bytes)
  return _ec_sign_curve_der(ec_curve_p256(), priv32_bytes, msg_sha256_bytes, nonce32_bytes)
@end

@fn ecdsa_p384_sign_der(priv48_bytes, msg_sha384_bytes, nonce48_bytes)
  return _ec_sign_curve_der(ec_curve_p384(), priv48_bytes, msg_sha384_bytes, nonce48_bytes)
@end
