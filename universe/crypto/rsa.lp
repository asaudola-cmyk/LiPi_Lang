@! ============================================================================
@! PURE MAYA CRYPTOGRAPHIC STANDARD LIBRARY: RSA PUBLIC KEY CRYPTOGRAPHY
@! Module: universe/crypto/rsa
@! 100% Pure Maya Implementation — O(log phi) Extended Euclidean Algorithm (ext_gcd)
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

@fn rsa_mod_pow(base, exp, mod)
  result = 1
  base = base % mod
  @while exp > 0
    @if (exp % 2) == 1
      result = (result * base) % mod
    @end
    exp = exp / 2
    base = (base * base) % mod
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
  i = 5
  @while (i * i) <= n
    @if (n % i) == 0 || (n % (i + 2)) == 0
      return 0
    @end
    i = i + 6
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
