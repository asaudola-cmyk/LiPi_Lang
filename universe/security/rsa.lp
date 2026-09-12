@! ============================================================================
@! LIPI UNIVERSE SECURITY - RSA CRYPTOGRAPHY (universe/security/rsa.lp)
@! Standard: Sovereign Native BigInt & RSA Engine
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/crypto/rsa"

@struct RsaKey
  n: i64
  e: i64
  d: i64
@end

@fn rsa_key_new()
  return {
    n: 3233, @! Example small primes p=61, q=53
    e: 17,
    d: 2753
  }
@end

@fn rsa_key_from_primes(p, q)
  res = rsa_keygen(p, q)
  return {
    n: res[2],
    e: res[0],
    d: res[1]
  }
@end

@struct BigInt
  limbs: array
  sign: i64
@end

@fn bigint_new()
  return { limbs: [0], sign: 1 }
@end

@fn bigint_from_int(n)
  sign = 1
  @if n < 0
    sign = 0 - 1
    n = 0 - n
  @end
  @if n == 0
    return { limbs: [0], sign: 1 }
  @end
  limbs = []
  @while n > 0
    limbs = limbs.push(n & 4294967295)
    n = n / 4294967296
  @end
  return { limbs: limbs, sign: sign }
@end

@fn bigint_to_int(b)
  val = 0
  mul = 1
  i = 0
  n = b.limbs.len()
  @while i < n
    val = val + (b.limbs[i] * mul)
    mul = mul * 4294967296
    i = i + 1
  @end
  return val * b.sign
@end

@fn bigint_mul(a, b)
  n = a.limbs.len()
  m = b.limbs.len()
  prod_len = n + m
  limbs = []
  i = 0
  @while i < prod_len
    limbs = limbs.push(0)
    i = i + 1
  @end

  i = 0
  @while i < n
    carry = 0
    j = 0
    @while j < m
      cur = limbs[i + j] + (a.limbs[i] * b.limbs[j]) + carry
      limbs = list_set(limbs, i + j, cur & 4294967295)
      carry = cur / 4294967296
      j = j + 1
    @end
    limbs = list_set(limbs, i + m, limbs[i + m] + carry)
    i = i + 1
  @end

  new_len = limbs.len()
  @while new_len > 1 && limbs[new_len - 1] == 0
    new_len = new_len - 1
  @end
  @if new_len != limbs.len()
    trimmed = []
    idx = 0
    @while idx < new_len
      trimmed = trimmed.push(limbs[idx])
      idx = idx + 1
    @end
    limbs = trimmed
  @end

  return { limbs: limbs, sign: a.sign * b.sign }
@end

@fn bigint_mod(a, m)
  div_res = bigint_div_knuth_d(a, m)
  return div_res.r
@end

@fn bigint_mod_exp(base, exp, mod)
  res = bigint_from_int(1)
  cur_base = bigint_mod(base, mod)
  e = bigint_to_int(exp)
  @while e > 0
    @if (e % 2) == 1
      mul_res = bigint_mul(res, cur_base)
      res = bigint_mod(mul_res, mod)
    @end
    e = e / 2
    cur_base = bigint_mod(bigint_mul(cur_base, cur_base), mod)
  @end
  return res
@end

@! Native Maya Modular Exponentiation (base^exp % mod)
@fn rsa_mod_exp(base, exp, modulus)
  result = 1
  base = base % modulus
  @while exp > 0
    @if (exp % 2) == 1
      result = (result * base) % modulus
    @end
    exp = exp / 2
    base = (base * base) % modulus
  @end
  return result
@end

@fn rsa_encrypt(key, m)
  b_m = bigint_from_int(m)
  b_e = bigint_from_int(key.e)
  b_n = bigint_from_int(key.n)
  b_res = bigint_mod_exp(b_m, b_e, b_n)
  return bigint_to_int(b_res)
@end

@fn rsa_decrypt(key, c)
  b_c = bigint_from_int(c)
  b_d = bigint_from_int(key.d)
  b_n = bigint_from_int(key.n)
  b_res = bigint_mod_exp(b_c, b_d, b_n)
  return bigint_to_int(b_res)
@end

@fn rsa_encrypt_bigint(key, b_m)
  b_e = bigint_from_int(key.e)
  b_n = bigint_from_int(key.n)
  return bigint_mod_exp(b_m, b_e, b_n)
@end

@fn rsa_decrypt_bigint(key, b_c)
  b_d = bigint_from_int(key.d)
  b_n = bigint_from_int(key.n)
  return bigint_mod_exp(b_c, b_d, b_n)
@end


@! Knuth Algorithm D (Multi-precision Division)
@! Divides BigInt u by BigInt v, returns { q: quotient, r: remainder }
@fn bigint_div_knuth_d(u, v)
  @! Ensure v > 0
  @if v.limbs.len() == 1 && v.limbs[0] == 0
    return { q: bigint_new(), r: bigint_new() } @! Div by zero
  @end
  
  @! Simplified single-limb division if v is small
  @if v.limbs.len() == 1
    q = []
    r = 0
    i = u.limbs.len() - 1
    @while i >= 0
      curr = (r * 4294967296) + u.limbs[i]
      q_limb = curr / v.limbs[0]
      r = curr % v.limbs[0]
      q = q.push(q_limb)
      i = i - 1
    @end
    return { q: { limbs: list_reverse(q), sign: u.sign * v.sign }, r: { limbs: [r], sign: u.sign } }
  @end
  
  @! Full Knuth Algorithm D for multi-limb (200-300 digits)
  shift = 4294967296 / (v.limbs[v.limbs.len() - 1] + 1)
  
  quotient = []
  remainder = []
  
  u_limbs = u.limbs
  v_limbs = v.limbs
  n = v_limbs.len()
  
  @! Append a 0 to u_limbs to handle the extra limb in D3
  u_limbs = u_limbs.push(0)
  
  j = u.limbs.len() - v.limbs.len()
  @while j >= 0
    u_jn = u_limbs[j + n]
    u_jn1 = u_limbs[j + n - 1]
    v_n1 = v_limbs[n - 1]
    
    curr = (u_jn * 4294967296) | u_jn1
    q_hat = 0
    @if u_jn == v_n1
      q_hat = 4294967295
    @else
      q_hat = curr / v_n1
    @end
    
    carry = 0
    i = 0
    @while i < n
      p = (q_hat * v_limbs[i]) + carry
      u_idx = j + i
      u_val = u_limbs[u_idx]
      
      sub = u_val - p & 4294967295
      @if sub < 0
        sub = sub + 4294967296
        carry = (p / 4294967296) + 1
      @else
        carry = (p / 4294967296)
      @end
      u_limbs = list_set(u_limbs, u_idx, sub)
      i = i + 1
    @end
    
    sub_jn = u_limbs[j + n] - carry
    @if sub_jn < 0
      u_limbs = list_set(u_limbs, j + n, sub_jn + 4294967296)
      q_hat = q_hat - 1
      carry_add = 0
      k = 0
      @while k < n
        add_val = u_limbs[j + k] + v_limbs[k] + carry_add
        u_limbs = list_set(u_limbs, j + k, add_val & 4294967295)
        carry_add = add_val / 4294967296
        k = k + 1
      @end
      u_limbs = list_set(u_limbs, j + n, (u_limbs[j + n] + carry_add) & 4294967295)
    @else
      u_limbs = list_set(u_limbs, j + n, sub_jn)
    @end
    
    quotient = quotient.push(q_hat)
    j = j - 1
  @end
  
  k = 0
  @while k < n
    remainder = remainder.push(u_limbs[k])
    k = k + 1
  @end
  
  return { 
    q: { limbs: list_reverse(quotient), sign: u.sign * v.sign }, 
    r: { limbs: remainder, sign: u.sign } 
  }
@end
