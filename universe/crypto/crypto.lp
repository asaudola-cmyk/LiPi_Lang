@! ============================================================================
@! PURE MAYA CRYPTOGRAPHY STANDARD LIBRARY - UNIFIED FACADE
@! Module: universe/crypto/crypto
@! 100% Pure Maya Cryptography Standard Library
@! ============================================================================

import "universe/crypto/sha256"
import "universe/crypto/sha512"
import "universe/crypto/sha1"
import "universe/crypto/base64"
import "universe/crypto/aes"
import "universe/crypto/ed25519"
import "universe/crypto/rsa"

@! Re-export and high-level crypto conveniences
@fn crypto_sha256_hex(data)
  return sha256_hex(data)
@end

@fn crypto_sha256_bytes(data)
  return sha256_hash_bytes(data)
@end

@fn crypto_sha512_hex(data)
  return sha512_hex(data)
@end

@fn crypto_sha512_bytes(data)
  return sha512_hash_bytes(data)
@end

@fn crypto_sha1_hex(data)
  return sha1_hex(data)
@end

@fn crypto_sha1_bytes(data)
  return sha1_hash_bytes(data)
@end

@fn crypto_base64_encode(data)
  return base64_encode(data)
@end

@fn crypto_base64_decode(encoded_str)
  return base64_decode(encoded_str)
@end

@fn crypto_aes128_encrypt(key, iv, plaintext)
  return aes128_cbc_encrypt(key, iv, plaintext)
@end

@fn crypto_aes128_decrypt(key, iv, ciphertext)
  return aes128_cbc_decrypt(key, iv, ciphertext)
@end

@fn crypto_aes256_encrypt(key, iv, plaintext)
  return aes256_cbc_encrypt(key, iv, plaintext)
@end

@fn crypto_aes256_decrypt(key, iv, ciphertext)
  return aes256_cbc_decrypt(key, iv, ciphertext)
@end

@fn crypto_ed25519_keygen(seed)
  return ed25519_keygen(seed)
@end

@fn crypto_ed25519_sign(secret_key, msg)
  return ed25519_sign(secret_key, msg)
@end

@fn crypto_ed25519_verify(pub_key, msg, sig)
  return ed25519_verify(pub_key, msg, sig)
@end
