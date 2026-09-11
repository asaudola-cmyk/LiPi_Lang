@! ============================================================================
@! MAYA UNIVERSAL ARCHITECTURE — THE UNIVERSAL NUMBER GENERATOR (BIGINT)
@! Module: compiler/backend/universal_math.maya
@! Description: Converts Maya IR / Opcodes into a single massive Gödel Integer.
@! Architecture: Absolute Sovereign (Zero Binary)
@! ============================================================================

import "universe/core/collections"

@! ─── BigInt Core ────────────────────────────────────────────────────────────

@struct BigInt
  limbs: array 
  sign: i64    
@end

@fn bigint_new(val)
  limbs = []
  i_dummy = 0
  @if val == 0
    limbs = limbs.push(0)
    return { limbs: limbs, sign: 1 }
  @end
  
  sign = 1
  @if val < 0
    sign = 0 - 1
    val = 0 - val
  @end
  
  @while val > 0
    rem = val % 1000000000
    limbs = limbs.push(rem)
    val = val / 1000000000
  @end
  
  return { limbs: limbs, sign: sign }
@end

@fn bigint_mul(a, b)
  res_limbs = []
  total_len = a.limbs.len() + b.limbs.len()
  
  k = 0
  @while k < total_len
    res_limbs = res_limbs.push(0)
    k = k + 1
  @end
  
  i = 0
  @while i < a.limbs.len()
    carry = 0
    j = 0
    @while j < b.limbs.len()
      curr = res_limbs[i + j]
      prod = curr + (a.limbs[i] * b.limbs[j]) + carry
      res_limbs = list_set(res_limbs, i + j, prod % 1000000000)
      carry = prod / 1000000000
      j = j + 1
    @end
    @if carry > 0
      curr = res_limbs[i + j]
      res_limbs = list_set(res_limbs, i + j, curr + carry)
    @end
    i = i + 1
  @end
  
 
  @while res_limbs.len() > 1 && res_limbs[res_limbs.len() - 1] == 0
    res_limbs = pop(res_limbs)
  @end
  
  sign = 1
  @if a.sign != b.sign
    sign = 0 - 1
  @end
  
  return { limbs: res_limbs, sign: sign }
@end

@fn bigint_pow_u64(base, exp)
  res = bigint_new(1)
  curr_base = base
  
  @while exp > 0
    @if (exp % 2) == 1
      res = bigint_mul(res, curr_base)
    @end
    curr_base = bigint_mul(curr_base, curr_base)
    exp = exp / 2
  @end
  
  return res
@end

@! ─── Prime Generator ────────────────────────────────────────────────────────

@fn is_prime(n)
  @if n <= 1
    return 0
  @end
  @if n == 2
    return 1
  @end
  @if (n % 2) == 0
    return 0
  @end
  
  i = 3
  @while (i * i) <= n
    @if (n % i) == 0
      return 0
    @end
    i = i + 2
  @end
  
  return 1
@end

@fn get_nth_prime(n)
  @if n == 0
    return 2
  @end
  count = 0
  curr = 2
  @while count < n
    curr = curr + 1
    @if is_prime(curr) == 1
      count = count + 1
    @end
  @end
  return curr
@end

@! ─── Gödel Number Encoder ───────────────────────────────────────────────────

@fn generate_universal_number(byte_stream)
  // WHY: Maps instruction stream to Gödel integer using prime factorization: prod p_i^(b_i + 1)
  g = bigint_new(1)
  i = 0
  n = byte_stream.len()
  @while i < n
    p = get_nth_prime(i)
    p_big = bigint_new(p)
    exp = byte_stream[i] + 1
    k = 0
    @while k < exp
      g = bigint_mul(g, p_big)
      k = k + 1
    @end
    i = i + 1
  @end
  return g
@end

@fn bigint_to_string(a)
  // WHY: Converts arbitrary-precision BigInt to canonical decimal string representation.
  // Uses pure Lipi/Maya string concatenation to allocate on the runtime heap with valid STR0 tag headers,
  // preventing pointer-as-integer interpretation bugs in _lipi_is_str.
  @if a.limbs.len() == 0
    return "0"
  @end
  @if a.limbs.len() == 1 && a.limbs[0] == 0
    return "0"
  @end

  res = ""
  @if a.sign < 0
    res = "-"
  @end

  i = a.limbs.len() - 1
  res = str_concat(res, to_str(a.limbs[i]))

  i = i - 1
  @while i >= 0
    limb_val = a.limbs[i]
    limb_str = to_str(limb_val)
    len_str = c_len(limb_str)
    pad_len = 9 - len_str

    pad_idx = 0
    @while pad_idx < pad_len
      res = str_concat(res, "0")
      pad_idx = pad_idx + 1
    @end

    res = str_concat(res, limb_str)
    i = i - 1
  @end
  return res
@end

@! ─── Universal Number Decoder ───────────────────────────────────────────────

@struct DivModResult
  q: i64
  rem: i64
@end

@fn bigint_div_mod_u64(a, b_val)
  res_limbs = []
  rem = 0
  i = a.limbs.len() - 1
  @while i >= 0
    curr = (rem * 1000000000) + a.limbs[i]
    q = curr / b_val
    rem = curr % b_val
    res_limbs = res_limbs.push(q)
    i = i - 1
  @end
  
  res_limbs = list_reverse(res_limbs)
  
  @while res_limbs.len() > 1 && res_limbs[res_limbs.len() - 1] == 0
    res_limbs = pop(res_limbs)
  @end
  
  return { q: { limbs: res_limbs, sign: a.sign }, rem: rem }
@end

@fn bigint_is_zero(a)
  @if a.limbs.len() == 0 return 1 @end
  @if a.limbs.len() == 1 && a.limbs[0] == 0 return 1 @end
  return 0
@end

@fn bigint_is_one(a)
  @if a.limbs.len() == 1 && a.limbs[0] == 1 return 1 @end
  return 0
@end

@fn bigint_add_u64(a, b_val)
  res_limbs = []
  carry = b_val
  i = 0
  @while i < a.limbs.len()
    sum = a.limbs[i] + carry
    res_limbs = res_limbs.push(sum % 1000000000)
    carry = sum / 1000000000
    i = i + 1
  @end
  @while carry > 0
    res_limbs = res_limbs.push(carry % 1000000000)
    carry = carry / 1000000000
  @end
  return { limbs: res_limbs, sign: a.sign }
@end

@fn bigint_from_string(str)
  res = bigint_new(0)
  ten = bigint_new(10)
  
  i = 0
  n = c_len(str)
  @while i < n
    // WHY: Use direct string indexing s[i] to read character byte cleanly
    c = str[i]
    @if c >= 48 && c <= 57
      digit = c - 48
      res = bigint_mul(res, ten)
      res = bigint_add_u64(res, digit)
    @end
    i = i + 1
  @end
  return res
@end

@fn decode_universal_number(g_bigint, num_bytes)
  // WHY: Recovers original byte stream by factoring Gödel primes p_i until non-divisible
  bytes = []
  curr_g = g_bigint
  i = 0
  @while i < num_bytes
    p = get_nth_prime(i)
    exp = 0
    factoring = 1
    @while factoring == 1
      dm = bigint_div_mod_u64(curr_g, p)
      @if dm.rem == 0
        exp = exp + 1
        curr_g = dm.q
      @else
        factoring = 0
      @end
    @end
    byte_val = exp - 1
    @if byte_val < 0
      byte_val = 0
    @end
    bytes = bytes.push(byte_val)
    i = i + 1
  @end
  return bytes
@end
