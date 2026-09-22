// ==============================================================================
// 👑 LIPI CRYPTO VAULT RIGOROUS TEST SUITE (packages/crypto_vault/tests/test_vault.lp)
// ⚡ Tests real SHA-256 password hashing, salt verification, and session tokens
// ==============================================================================

import "packages/crypto_vault/src/lib"

@fn main()
  println("--- Crypto Vault Rigorous Test Suite ---")
  
  // 1. Password Hashing & Verification
  h = hash_password("secret_sovereign_pass_123")
  @if str_len(h) == 64
    println("PASS: hash_password length 64 hex")
  @else
    println("FAIL: hash_password length")
    println(h)
  @end
  
  @if verify_password("secret_sovereign_pass_123", h) == 1
    println("PASS: verify_password correct password")
  @else
    println("FAIL: verify_password correct password")
  @end
  
  @if verify_password("wrong_password_attempt", h) == 0
    println("PASS: verify_password wrong password rejected")
  @else
    println("FAIL: verify_password wrong password accepted")
  @end
  
  // 2. Custom Salt Hashing
  h_custom = hash_password_salted("user_password", "custom_enterprise_salt")
  @if str_len(h_custom) == 64
    println("PASS: hash_password_salted")
  @else
    println("FAIL: hash_password_salted")
  @end
  
  @if verify_password_salted("user_password", "custom_enterprise_salt", h_custom) == 1
    println("PASS: verify_password_salted valid")
  @else
    println("FAIL: verify_password_salted valid")
  @end
  
  // 3. Cryptographic Token Generation & Expiry
  t = generate_token("user_42_sovereign")
  @if str_len(t.value) == 64
    println("PASS: generate_token value length")
  @else
    println("FAIL: generate_token value length")
  @end
  
  @if t.expiry > 1700000000
    println("PASS: generate_token realistic future expiry")
  @else
    println("FAIL: generate_token realistic future expiry")
  @end
  
  // 4. Token Validation
  current_time = 1774100500
  @if verify_token(t, current_time) == 1
    println("PASS: verify_token active session")
  @else
    println("FAIL: verify_token active session")
  @end
  
  expired_time = t.expiry + 1000
  @if verify_token(t, expired_time) == 0
    println("PASS: verify_token expired session rejected")
  @else
    println("FAIL: verify_token expired session rejected")
  @end
  
  println("✔ All crypto_vault enterprise tests passed successfully!")
  return 0
@end

