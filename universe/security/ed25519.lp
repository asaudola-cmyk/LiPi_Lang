@! ============================================================================
@! LIPI UNIVERSE SECURITY: RFC 8032 ED25519 DIGITAL SIGNATURES
@! Module: universe/security/ed25519
@! 100% Pure Lipi Implementation — Zero External / C Dependencies
@! ============================================================================

import "universe/crypto/ed25519"

@struct KeyPair
  secret_key: array
  public_key: array
@end

@fn ed25519_keygen_sec(seed)
  kp = ed25519_keygen(seed)
  return {
    secret_key: kp.secret_key,
    public_key: kp.public_key
  }
@end

@fn ed25519_sign_sec(secret_key, message)
  return ed25519_sign(secret_key, message)
@end

@fn ed25519_verify_sec(public_key, message, signature)
  return ed25519_verify(public_key, message, signature)
@end