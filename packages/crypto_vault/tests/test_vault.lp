import "packages/crypto_vault/src/lib"

@fn main()
  println("--- Crypto Vault Test ---")
  
  h = hash_password("secret")
  @if h == "hashed"
    println("PASS: hash_password")
  @else
    println("FAIL: hash_password")
  @end
  
  t = generate_token("user1")
  @if t.expiry == 9999
    println("PASS: generate_token")
  @else
    println("FAIL: generate_token")
  @end
  
  return 0
@end
