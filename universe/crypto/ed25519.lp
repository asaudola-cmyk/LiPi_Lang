@fn maya_pow2(n)
  @if n <= 0 return 1 @end
  res = 1
  i = 0
  @while i < n
    res = res * 2
    i = i + 1
  @end
  return res
@end

@! ============================================================================
@! PURE MAYA CRYPTOGRAPHIC STANDARD LIBRARY: RFC 8032 ED25519 SIGNATURES
@! Module: universe/crypto/ed25519
@! 100% Pure Lipi Implementation — Edwards25519 Curve Arithmetic & Digital Signatures
@! Curve Equation: -x^2 + y^2 = 1 + d * x^2 * y^2 over F(2^255 - 19)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/sha512"

@! ----------------------------------------------------------------------------
@! 1. DATA STRUCTURES
@! ----------------------------------------------------------------------------

@struct EdPoint
  x: array
  y: array
  z: array
  t: array
@end

@struct EdKeyPair
  secret_key: array
  public_key: array
@end

@! ----------------------------------------------------------------------------
@! 2. FIELD ARITHMETIC OVER F(2^255 - 19) (16-bit Limbs, Little-Endian)
@! ----------------------------------------------------------------------------

@fn fe_zero()
  return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
@end

@fn fe_one()
  return [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
@end

@fn fe_p()
  return [65517, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 32767]
@end

@fn fe_d()
  return [30883, 4953, 19914, 30187, 55467, 16705, 2637, 112, 59544, 30585, 16505, 36039, 65139, 11119, 27886, 20995]
@end

@fn fe_2d()
  return [61785, 9906, 39828, 60374, 45398, 33411, 5274, 224, 53552, 61171, 33010, 6542, 64743, 22239, 55772, 9222]
@end

@fn fe_sqrt_neg1()
  return [41136, 18958, 6951, 50414, 58488, 44335, 6150, 12099, 55207, 15867, 153, 11085, 57099, 20417, 9344, 11139]
@end

@fn fe_base_x()
  return [54554, 36645, 11616, 51542, 42930, 38181, 51040, 26924, 56412, 64982, 57905, 49316, 21502, 52590, 14035, 8553]
@end

@fn fe_base_y()
  return [26200, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214, 26214]
@end

@fn fe_from_bytes(bytes32)
  res = []
  i = 0
  @while i < 16
    idx = i * 2
    b0 = 0
    b1 = 0
    @if idx < bytes32.len()
      b0 = bytes32[idx] & 255
    @end
    @if idx + 1 < bytes32.len()
      b1 = bytes32[idx + 1] & 255
    @end
    t1 = b1 * 256
    val = b0 | t1
    limb = val % 65536
    res = res.push(limb)
    i = i + 1
  @end
  return res
@end

@fn fe_to_bytes(fe)
  res = []
  i = 0
  @while i < 16
    limb = fe[i] % 65536
    res = res.push(limb & 255)
    b_hi = (limb / 256) & 255
    res = res.push(b_hi)
    i = i + 1
  @end
  return res
@end

@fn fe_normalize(c)
  carry = 0
  i = 0
  @while i < 16
    sum = c[i] + carry
    c = list_set(c, i, sum % 65536)
    carry = sum / 65536
    i = i + 1
  @end

  top_bit = c[15] / 32768
  c = list_set(c, 15, c[15] % 32768)
  overflow = (carry * 38) + (top_bit * 19)

  carry = overflow
  i = 0
  @while i < 16
    sum = c[i] + carry
    c = list_set(c, i, sum % 65536)
    carry = sum / 65536
    i = i + 1
  @end

  top_bit2 = c[15] / 32768
  c = list_set(c, 15, c[15] % 32768)
  overflow2 = (carry * 38) + (top_bit2 * 19)

  @if overflow2 > 0
    c = list_set(c, 0, c[0] + overflow2)
    carry = 0
    i = 0
    @while i < 16
      sum = c[i] + carry
      c = list_set(c, i, sum % 65536)
      carry = sum / 65536
      i = i + 1
    @end
  @end

  @! Check if c >= p, if so subtract p
  p = fe_p()
  ge = 1
  i = 15
  @while i >= 0
    @if c[i] > p[i]
      ge = 1
      i = -1
    @elif c[i] < p[i]
      ge = 0
      i = -1
    @else
      i = i - 1
    @end
  @end

  @if ge == 1
    borrow = 0
    i = 0
    @while i < 16
      diff = c[i] - p[i] - borrow
      @if diff < 0
        diff = diff + 65536
        borrow = 1
      @else
        borrow = 0
      @end
      c = list_set(c, i, diff % 65536)
      i = i + 1
    @end
  @end

  return c
@end

@fn fe_add(a, b)
  c = []
  i = 0
  @while i < 16
    c = c.push(a[i] + b[i])
    i = i + 1
  @end
  return fe_normalize(c)
@end

@fn fe_sub(a, b)
  p = fe_p()
  c = []
  i = 0
  @while i < 16
    c = c.push(a[i] + (2 * p[i]) - b[i])
    i = i + 1
  @end
  return fe_normalize(c)
@end

@fn fe_neg(a)
  return fe_sub(fe_zero(), a)
@end

@fn fe_mul(a, b)
  prod = []
  i = 0
  @while i < 32
    prod = prod.push(0)
    i = i + 1
  @end

  i = 0
  @while i < 16
    ai = a[i]
    j = 0
    @while j < 16
      idx = i + j
      prod[idx] = prod[idx] + (ai * b[j])
      j = j + 1
    @end
    i = i + 1
  @end

  @! Carry propagate through 32 limbs
  carry = 0
  i = 0
  @while i < 32
    sum = prod[i] + carry
    prod[i] = sum % 65536
    carry = sum / 65536
    i = i + 1
  @end

  @! Fold upper 16 limbs into lower 16 limbs: 2^256 = 38 mod p
  res = []
  i = 0
  @while i < 16
    res = res.push(prod[i] + (prod[i + 16] * 38))
    i = i + 1
  @end

  @! Add high overflow carry * 1444 (since 2^512 = 38^2 = 1444 mod p)
  res = list_set(res, 0, res[0] + (carry * 1444))

  return fe_normalize(res)
@end

@fn fe_sqr(a)
  return fe_mul(a, a)
@end

@fn fe_eq(a, b)
  i = 0
  @while i < 16
    ai = a[i] % 65536
    bi = b[i] % 65536
    @if ai != bi
      return 0
    @end
    i = i + 1
  @end
  return 1
@end

@fn fe_is_zero(a)
  return fe_eq(a, fe_zero())
@end

@fn fe_pow(base, exp_limbs)
  res = fe_one()
  curr = base
  i = 0
  @while i < 16
    limb = exp_limbs[i]
    bit = 0
    @while bit < 16
      low_b = limb & 1
      @if low_b == 1
        res = fe_mul(res, curr)
      @end
      curr = fe_sqr(curr)
      limb = (limb / 2)
      bit = bit + 1
    @end
    i = i + 1
  @end
  return res
@end

@fn fe_inv(a)
  @! Invert mod 2^255 - 19: a^(2^255 - 21) mod p
  @! 2^255 - 21 limbs:
  exp = [65515, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 32767]
  return fe_pow(a, exp)
@end

@fn fe_sqrt_candidate(u, v)
  @! candidate x = u * v^3 * (u * v^7)^((p-5)/8) mod p
  @! (p-5)/8 = (2^255 - 24)/8 = 2^252 - 3
  @! 2^252 - 3 in limbs:
  exp_p_5_8 = [65533, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 65535, 4095]
  
  v2 = fe_sqr(v)
  v3 = fe_mul(v2, v)
  v7 = fe_mul(fe_sqr(v3), v)
  uv7 = fe_mul(u, v7)
  
  pwr = fe_pow(uv7, exp_p_5_8)
  x = fe_mul(fe_mul(u, v3), pwr)
  return x
@end

@! ----------------------------------------------------------------------------
@! 3. SCALAR ARITHMETIC OVER GROUP ORDER L (L = 2^252 + 27742317777372353535851937790883648493)
@! ----------------------------------------------------------------------------

@fn scalar_l_limbs()
  return [54253, 23797, 25370, 22546, 40150, 41719, 63966, 5342, 0, 0, 0, 0, 0, 0, 0, 4096]
@end

@fn scalar_is_less_than_l(bytes32)
  l = scalar_l_limbs()
  s = fe_from_bytes(bytes32)
  i = 15
  @while i >= 0
    @if s[i] < l[i]
      return 1
    @elif s[i] > l[i]
      return 0
    @end
    i = i - 1
  @end
  return 0 @! S == L is not allowed (< L strictly required)
@end

@fn scalar_mod_l(bytes_in)
  @! Binary shift-and-subtract reduction modulo L for up to 512-bit inputs
  l = scalar_l_limbs()
  rem = fe_zero()

  total_bytes = bytes_in.len()
  bit_idx = (total_bytes * 8) - 1

  @while bit_idx >= 0
    byte_pos = bit_idx / 8
    bit_pos = bit_idx % 8
    in_bit = 0
    @if byte_pos < bytes_in.len()
      in_bit = (bytes_in[byte_pos] / maya_pow2(bit_pos)) & 1
    @end

    @! Shift rem left by 1 and insert in_bit
    carry = in_bit
    i = 0
    @while i < 16
      shifted = (rem[i] * 2) | carry
      rem = list_set(rem, i, shifted % 65536)
      carry = (shifted / 65536) & 1
      i = i + 1
    @end

    @! Compare rem >= L
    ge = 0
    @if carry > 0
      ge = 1
    @else
      k = 15
      @while k >= 0
        @if rem[k] > l[k]
          ge = 1
          k = -1
        @elif rem[k] < l[k]
          ge = 0
          k = -1
        @else
          @if k == 0
            ge = 1
          @end
          k = k - 1
        @end
      @end
    @end

    @! If rem >= L, rem = rem - L
    @if ge == 1
      borrow = 0
      j = 0
      @while j < 16
        diff = rem[j] - l[j] - borrow
        @if diff < 0
          diff = diff + 65536
          borrow = 1
        @else
          borrow = 0
        @end
        rem[j] = diff % 65536
        j = j + 1
      @end
    @end

    bit_idx = bit_idx - 1
  @end

  return rem
@end

@fn scalar_add_l(a, b)
  l = scalar_l_limbs()
  res = []
  carry = 0
  i = 0
  @while i < 16
    sum = a[i] + b[i] + carry
    res = res.push(sum % 65536)
    carry = sum / 65536
    i = i + 1
  @end

  @! Check if res >= L
  ge = 0
  @if carry > 0
    ge = 1
  @else
    k = 15
    @while k >= 0
      @if res[k] > l[k]
        ge = 1
        k = -1
      @elif res[k] < l[k]
        ge = 0
        k = -1
      @else
        @if k == 0 ge = 1 @end
        k = k - 1
      @end
    @end
  @end

  @if ge == 1
    borrow = 0
    j = 0
    @while j < 16
      diff = res[j] - l[j] - borrow
      @if diff < 0
        diff = diff + 65536
        borrow = 1
      @else
        borrow = 0
      @end
      res[j] = diff % 65536
      j = j + 1
    @end
  @end

  return res
@end

@fn scalar_mul_l(a, b)
  @! Compute 32-limb product and reduce mod L
  prod = []
  i = 0
  @while i < 32
    prod = prod.push(0)
    i = i + 1
  @end

  i = 0
  @while i < 16
    ai = a[i]
    j = 0
    @while j < 16
      idx = i + j
      prod[idx] = prod[idx] + (ai * b[j])
      j = j + 1
    @end
    i = i + 1
  @end

  @! Carry propagate through 32 limbs
  carry = 0
  i = 0
  @while i < 32
    sum = prod[i] + carry
    prod[i] = sum % 65536
    carry = sum / 65536
    i = i + 1
  @end

  @! Convert prod to 64 bytes little-endian
  bytes64 = []
  i = 0
  @while i < 32
    limb = prod[i]
    bytes64 = bytes64.push(limb & 255)
    bytes64 = bytes64.push((limb / 256) & 255)
    i = i + 1
  @end

  return scalar_mod_l(bytes64)
@end

@! ----------------------------------------------------------------------------
@! 4. EDWARDS25519 POINT ARITHMETIC (Extended Homogeneous Coordinates X, Y, Z, T)
@! ----------------------------------------------------------------------------

@fn ed25519_base_point()
  return {
    x: fe_base_x(),
    y: fe_base_y(),
    z: fe_one(),
    t: fe_mul(fe_base_x(), fe_base_y())
  }
@end

@fn ed25519_point_infinity()
  return {
    x: fe_zero(),
    y: fe_one(),
    z: fe_one(),
    t: fe_zero()
  }
@end

@fn ed25519_point_add(p1, p2)
  @! Complete Twisted Edwards Addition Formula (RFC 8032 Section 5.1.4)
  @! A = (Y1 - X1) * (Y2 - X2)
  @! B = (Y1 + X1) * (Y2 + X2)
  @! C = 2d * T1 * T2
  @! D = 2 * Z1 * Z2
  @! E = B - A, F = D - C, G = D + C, H = B + A
  @! X3 = E * F, Y3 = G * H, T3 = E * H, Z3 = F * G

  a = fe_mul(fe_sub(p1.y, p1.x), fe_sub(p2.y, p2.x))
  b = fe_mul(fe_add(p1.y, p1.x), fe_add(p2.y, p2.x))
  c = fe_mul(fe_mul(fe_2d(), p1.t), p2.t)
  d = fe_mul(fe_mul([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], p1.z), p2.z)

  e = fe_sub(b, a)
  f = fe_sub(d, c)
  g = fe_add(d, c)
  h = fe_add(b, a)

  x3 = fe_mul(e, f)
  y3 = fe_mul(g, h)
  t3 = fe_mul(e, h)
  z3 = fe_mul(f, g)

  return { x: x3, y: y3, z: z3, t: t3 }
@end

@fn ed25519_point_double(p1)
  @! Dedicated Point Doubling (RFC 8032)
  @! A = X1^2, B = Y1^2, C = 2 * Z1^2, D = -A
  @! E = (X1 + Y1)^2 - A - B, G = D + B, F = G - C, H = D - B
  @! X3 = E * F, Y3 = G * H, T3 = E * H, Z3 = F * G

  a = fe_sqr(p1.x)
  b = fe_sqr(p1.y)
  c = fe_mul([2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], fe_sqr(p1.z))
  d = fe_neg(a)

  xy = fe_add(p1.x, p1.y)
  e = fe_sub(fe_sub(fe_sqr(xy), a), b)
  g = fe_add(d, b)
  f = fe_sub(g, c)
  h = fe_sub(d, b)

  x3 = fe_mul(e, f)
  y3 = fe_mul(g, h)
  t3 = fe_mul(e, h)
  z3 = fe_mul(f, g)

  return { x: x3, y: y3, z: z3, t: t3 }
@end

@fn ed25519_scalar_mult(scalar_limbs, pt)
  res = ed25519_point_infinity()
  curr = pt
  i = 0
  @while i < 16
    limb = scalar_limbs[i]
    bit = 0
    @while bit < 16
      low_b = limb & 1
      @if low_b == 1
        res = ed25519_point_add(res, curr)
      @end
      curr = ed25519_point_double(curr)
      limb = (limb / 2)
      bit = bit + 1
    @end
    i = i + 1
  @end
  return res
@end

@fn ed25519_point_compress(pt)
  z_inv = fe_inv(pt.z)
  x = fe_mul(pt.x, z_inv)
  y = fe_mul(pt.y, z_inv)

  bytes = fe_to_bytes(y)
  sign = x[0] & 1
  @if sign == 1
    bytes[31] = bytes[31] | 128
  @end
  return bytes
@end

@fn ed25519_point_decompress(bytes32)
  @if bytes32.len() != 32
    return { x: fe_zero(), y: fe_zero(), z: fe_zero(), t: fe_zero() }
  @end

  b = []
  i = 0
  @while i < 32
    b = b.push(bytes32[i] & 255)
    i = i + 1
  @end

  sign = (b[31] / 128) & 1
  b[31] = b[31] & 127

  y = fe_from_bytes(b)
  p = fe_p()

  @! Check y < p
  ge = 1
  i = 15
  @while i >= 0
    @if y[i] > p[i]
      return { x: fe_zero(), y: fe_zero(), z: fe_zero(), t: fe_zero() } @! Fail: y >= p
    @elif y[i] < p[i]
      ge = 0
      i = -1
    @else
      i = i - 1
    @end
  @end
  @if ge == 1
    return { x: fe_zero(), y: fe_zero(), z: fe_zero(), t: fe_zero() }
  @end

  @! u = y^2 - 1, v = d * y^2 + 1
  y2 = fe_sqr(y)
  u = fe_sub(y2, fe_one())
  v = fe_add(fe_mul(fe_d(), y2), fe_one())

  x = fe_sqrt_candidate(u, v)
  vxx = fe_mul(v, fe_sqr(x))

  valid = 0
  @if fe_eq(vxx, u) == 1
    valid = 1
  @else
    neg_u = fe_neg(u)
    @if fe_eq(vxx, neg_u) == 1
      x = fe_mul(x, fe_sqrt_neg1())
      valid = 1
    @end
  @end

  @if valid == 0
    return { x: fe_zero(), y: fe_zero(), z: fe_zero(), t: fe_zero() } @! Point not on curve
  @end

  x0_bit = x[0] & 1
  @if x0_bit != sign
    x = fe_neg(x)
  @end

  t = fe_mul(x, y)
  return { x: x, y: y, z: fe_one(), t: t }
@end

@fn ed25519_point_eq(p1, p2)
  @! Compare projective equality: X1 * Z2 == X2 * Z1 and Y1 * Z2 == Y2 * Z1
  x1z2 = fe_mul(p1.x, p2.z)
  x2z1 = fe_mul(p2.x, p1.z)
  @if fe_eq(x1z2, x2z1) == 0
    return 0
  @end

  y1z2 = fe_mul(p1.y, p2.z)
  y2z1 = fe_mul(p2.y, p1.z)
  @if fe_eq(y1z2, y2z1) == 0
    return 0
  @end

  return 1
@end

@! ----------------------------------------------------------------------------
@! 5. RFC 8032 KEY DERIVATION, SIGNING & VERIFICATION
@! ----------------------------------------------------------------------------

@fn ed25519_keygen(seed32)
  h = sha512_hash_bytes(seed32)
  
  @! Clamp secret scalar s
  s_bytes = []
  i = 0
  @while i < 32
    s_bytes = s_bytes.push(h[i])
    i = i + 1
  @end
  s_bytes = list_set(s_bytes, 0, s_bytes[0] % 248)
  s31 = s_bytes[31] & 127
  s_bytes = list_set(s_bytes, 31, s31 | 64)

  s_limbs = fe_from_bytes(s_bytes)
  pub_pt = ed25519_scalar_mult(s_limbs, ed25519_base_point())
  pub_bytes = ed25519_point_compress(pub_pt)

  return {
    secret_key: seed32,
    public_key: pub_bytes
  }
@end

@fn ed25519_sign(secret_seed, message)
  h = sha512_hash_bytes(secret_seed)

  @! 1. Clamp s
  s_bytes = []
  i = 0
  @while i < 32
    s_bytes = s_bytes.push(h[i])
    i = i + 1
  @end
  s_bytes = list_set(s_bytes, 0, s_bytes[0] % 248)
  s31 = s_bytes[31] & 127
  s_bytes = list_set(s_bytes, 31, s31 | 64)
  s_limbs = fe_from_bytes(s_bytes)

  pub_pt = ed25519_scalar_mult(s_limbs, ed25519_base_point())
  pub_bytes = ed25519_point_compress(pub_pt)

  @! 2. Compute ephemeral nonce r = SHA-512(h[32..63] || message) mod L
  r_input = []
  i = 32
  @while i < 64
    r_input = r_input.push(h[i])
    i = i + 1
  @end
  j = 0
  @while j < message.len()
    r_input = r_input.push(message[j])
    j = j + 1
  @end
  r_hash = sha512_hash_bytes(r_input)
  r_limbs = scalar_mod_l(r_hash)

  @! 3. Ephemeral point R = [r] B
  r_pt = ed25519_scalar_mult(r_limbs, ed25519_base_point())
  r_bytes = ed25519_point_compress(r_pt)

  @! 4. Challenge k = SHA-512(R || A || message) mod L
  k_input = []
  i = 0
  @while i < 32
    k_input = k_input.push(r_bytes[i])
    i = i + 1
  @end
  i = 0
  @while i < 32
    k_input = k_input.push(pub_bytes[i])
    i = i + 1
  @end
  j = 0
  @while j < message.len()
    k_input = k_input.push(message[j])
    j = j + 1
  @end
  k_hash = sha512_hash_bytes(k_input)
  k_limbs = scalar_mod_l(k_hash)

  @! 5. S = (r + k * s) mod L
  ks_limbs = scalar_mul_l(k_limbs, s_limbs)
  s_final_limbs = scalar_add_l(r_limbs, ks_limbs)
  s_final_bytes = fe_to_bytes(s_final_limbs)

  @! 6. Signature = R || S (64 bytes)
  signature = []
  i = 0
  @while i < 32
    signature = signature.push(r_bytes[i])
    i = i + 1
  @end
  i = 0
  @while i < 32
    signature = signature.push(s_final_bytes[i])
    i = i + 1
  @end

  return signature
@end

@fn ed25519_verify(pub_key, message, signature)
  @! RFC 8032 Verification: [S]B == R + [k]A
  @if signature.len() != 64 || pub_key.len() != 32
    return 0
  @end

  r_bytes = []
  i = 0
  @while i < 32
    r_bytes = r_bytes.push(signature[i])
    i = i + 1
  @end

  s_bytes = []
  @while i < 64
    s_bytes = s_bytes.push(signature[i])
    i = i + 1
  @end

  @! Check S < L strictly
  @if scalar_is_less_than_l(s_bytes) == 0
    return 0
  @end

  @! Decompress public key A
  a_pt = ed25519_point_decompress(pub_key)
  @if fe_is_zero(a_pt.z) == 1
    return 0 @! Invalid public key
  @end

  @! Decompress R
  r_pt = ed25519_point_decompress(r_bytes)
  @if fe_is_zero(r_pt.z) == 1
    return 0 @! Invalid signature point R
  @end

  @! Compute challenge k = SHA-512(R || A || message) mod L
  k_input = []
  i = 0
  @while i < 32
    k_input = k_input.push(r_bytes[i])
    i = i + 1
  @end
  i = 0
  @while i < 32
    k_input = k_input.push(pub_key[i])
    i = i + 1
  @end
  j = 0
  @while j < message.len()
    k_input = k_input.push(message[j])
    j = j + 1
  @end
  k_hash = sha512_hash_bytes(k_input)
  k_limbs = scalar_mod_l(k_hash)

  @! LHS = [S] B
  s_limbs = fe_from_bytes(s_bytes)
  lhs = ed25519_scalar_mult(s_limbs, ed25519_base_point())

  @! RHS = R + [k] A
  ka = ed25519_scalar_mult(k_limbs, a_pt)
  rhs = ed25519_point_add(r_pt, ka)

  return ed25519_point_eq(lhs, rhs)
@end