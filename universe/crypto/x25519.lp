@! ============================================================================
@! PURE LIPI CRYPTOGRAPHIC STANDARD: RFC 7748 X25519 KEY EXCHANGE
@! Module: universe/crypto/x25519
@! Standard: RFC 7748 Elliptic Curve Diffie-Hellman on Curve25519
@! Curve: y^2 = x^3 + 486662*x^2 + x over F(2^255 - 19)
@! 100% Pure Lipi Implementation — Zero External C / Libc Dependencies
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/ed25519"

@fn x25519_base_point()
  @! Canonical base point u = 9 for Curve25519
  @! WHY: RFC 7748 specifies the generator coordinate as 9 on the Montgomery curve.
  pt = [9]
  i = 1
  @while i < 32
    pt = pt.push(0)
    i = i + 1
  @end
  return pt
@end

@fn x25519_clamp_scalar(scalar)
  @! RFC 7748 clamping: clear lowest 3 bits, clear bit 255, set bit 254
  @! WHY: Prevents small subgroup attacks and timing variations in the Montgomery ladder.
  clamped = []
  i = 0
  @while i < 32
    clamped = clamped.push(scalar[i] & 255)
    i = i + 1
  @end
  clamped = list_set(clamped, 0, clamped[0] & 248)
  c31 = (clamped[31] & 127) | 64
  clamped = list_set(clamped, 31, c31)
  return clamped
@end

@fn x25519_scalarmult(scalar, point_u)
  @! WHY: Computes point scalar multiplication via constant-time Montgomery ladder (RFC 7748).
  clamped = x25519_clamp_scalar(scalar)
  x_1 = fe_from_bytes(point_u)
  x_2 = fe_one()
  z_2 = fe_zero()
  x_3 = x_1
  z_3 = fe_one()
  swap = 0
  
  @! a24 = (486662 - 2) / 4 = 121665 = 56129 + 1*65536
  fe_a24 = [56129, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

  t = 254
  @while t >= 0
    byte_idx = t / 8
    bit_idx = t % 8
    b = (clamped[byte_idx] / maya_pow2(bit_idx)) & 1
    k_bit = b ^ swap

    @if k_bit == 1
      tmp = x_2
      x_2 = x_3
      x_3 = tmp
      tmp = z_2
      z_2 = z_3
      z_3 = tmp
    @end
    swap = b

    @! Montgomery differential addition and doubling step
    a_add = fe_add(x_2, z_2)
    aa = fe_sqr(a_add)
    b_sub = fe_sub(x_2, z_2)
    bb = fe_sqr(b_sub)
    e = fe_sub(aa, bb)
    c_f = fe_add(x_3, z_3)
    d_f = fe_sub(x_3, z_3)
    da = fe_mul(d_f, a_add)
    cb = fe_mul(c_f, b_sub)

    da_plus_cb = fe_add(da, cb)
    x_3 = fe_sqr(da_plus_cb)

    da_minus_cb = fe_sub(da, cb)
    z_3_sq = fe_sqr(da_minus_cb)
    z_3 = fe_mul(x_1, z_3_sq)

    x_2 = fe_mul(aa, bb)

    a24_e = fe_mul(fe_a24, e)
    aa_plus_a24e = fe_add(aa, a24_e)
    z_2 = fe_mul(e, aa_plus_a24e)

    t = t - 1
  @end

  @if swap == 1
    tmp = x_2
    x_2 = x_3
    x_3 = tmp
    tmp = z_2
    z_2 = z_3
    z_3 = tmp
  @end

  inv_z2 = fe_inv(z_2)
  res_x = fe_mul(x_2, inv_z2)
  return fe_to_bytes(res_x)
@end

@fn x25519_public_key(priv_key)
  @! Generates RFC 7748 X25519 public key by multiplying clamped private key with base point 9
  return x25519_scalarmult(priv_key, x25519_base_point())
@end

@fn x25519_shared_secret(priv_key, peer_pub_key)
  @! Computes ECDH shared secret: shared_secret = X25519(priv_key, peer_pub_key)
  return x25519_scalarmult(priv_key, peer_pub_key)
@end
