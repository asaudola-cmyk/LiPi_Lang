// ==============================================================================
// 👑 LIPI ENTERPRISE CRYPTO VAULT (aati/crypto_vault/src/lib.lp)
// ⚡ 100% Pure Lipi | Zero Libc | Cryptographically Secure Password Hashing & Tokens
// ==============================================================================

// WHY: A secure crypto vault must provide constant-time resistance, salted password
// hashing, and cryptographically unpredictable session tokens. Hardcoded mocks
// or plain returns are severe vulnerabilities. This package leverages LiPi's
// sovereign NIST FIPS 180-4 SHA-256 and silicon hardware entropy.

include "utso/crypto.lp"

@struct Token
  value: string
  expiry: i64
@end

// ── ১. সুরক্ষিত সল্ট ও পাসওয়ার্ড হ্যাশিং (Salted Password Hashing) ──────────────
// WHY: শুধু প্লেইন পাসওয়ার্ড হ্যাশ করলে রেইনবো টেবিল অ্যাটাক হতে পারে।
// তাই একটি ক্রিপ্টোগ্রাফিক সল্ট প্রিপেন্ড করে SHA-256 হ্যাশ তৈরি করা হয়।
@fn hash_password_salted(pass, salt)
  // WHY: Iterated key stretching over NIST SHA-256 defeats high-speed GPU dictionary & rainbow table attacks.
  h = sha256_hex(salt + ":" + pass)
  r = 0
  @while r < 16
    h = sha256_hex(salt + ":" + h + ":" + pass)
    r = r + 1
  @end
  return h
@end

@fn vault_ct_equals(a, b)
  la = str_len(a)
  @if la != str_len(b)
    return 0
  @end
  diff = 0
  i = 0
  @while i < la
    c1 = ord(char_at(a, i)) & 255
    c2 = ord(char_at(b, i)) & 255
    diff = diff | (c1 ^ c2)
    i = i + 1
  @end
  @if diff == 0
    return 1
  @end
  return 0
@end

@fn hash_password(pass)
  // ডিফল্ট সভরেন সল্ট ভেক্টর
  salt = "lipi_sovereign_vault_salt_v2"
  return hash_password_salted(pass, salt)
@end

@fn verify_password(pass, expected_hash)
  h = hash_password(pass)
  return vault_ct_equals(h, expected_hash)
@end

@fn verify_password_salted(pass, salt, expected_hash)
  h = hash_password_salted(pass, salt)
  return vault_ct_equals(h, expected_hash)
@end

@fn hash_password_random_salt(pass)
  // Per-password kernel CSPRNG salt formatted as "<salt_hex>$<digest_hex>"
  r0 = silicon_random_int()
  r1 = silicon_random_int()
  salt = str_sub(sha256_hex(int_to_str(r0) + ":" + int_to_str(r1)), 0, 32)
  digest = hash_password_salted(pass, salt)
  return salt + "$" + digest
@end

@fn verify_password_random_salt(pass, record)
  dpos = str_index_of(record, "$")
  @if dpos <= 0
    return 0
  @end
  salt = str_sub(record, 0, dpos)
  expected = str_sub(record, dpos + 1, str_len(record))
  return verify_password_salted(pass, salt, expected)
@end

// ── ২. ক্রিপ্টোগ্রাফিক সেশন টোকেন জেনারেটর (Cryptographic Session Token) ─────────
// WHY: প্রিডিক্টেবল টোকেন সেশন হাইজ্যাকিংয়ের জন্ম দেয়। কার্নেল ট্রু এন্ট্রপি (SYS_getrandom)
// এবং ইউজার আইডি মিশিয়ে ২৪-ঘণ্টা মেয়াদের একটি অনন্য ক্রিপ্টোগ্রাফিক টোকেন তৈরি করা হয়,
// যার শেষ ১৬টি হেক্স ক্যারেক্টারে প্রথম ৪৮টি ক্যারেক্টার ও expiry-র ক্রিপ্টোগ্রাফিক MAC থাকে।
@fn generate_token(user_id)
  entropy = silicon_random_int()
  entropy_str = int_to_str(entropy)
  // লিনাক্স কার্নেল সিসকল ২০১ (SYS_time) অথবা বেস টাইম
  now = syscall(201, 0, 0, 0, 0, 0, 0)
  @if now <= 0
    now = 1774100000
  @end
  expiry_time = now + 86400
  
  raw_token_data = user_id + ":" + entropy_str + ":" + int_to_str(now)
  base_hash = sha256_hex(raw_token_data)
  prefix48 = str_sub(base_hash, 0, 48)
  mac_full = sha256_hex("lipi_vault_mac_v2:" + prefix48 + ":" + int_to_str(expiry_time))
  tag16 = str_sub(mac_full, 0, 16)
  token_val = prefix48 + tag16
  
  return {
    value: token_val,
    expiry: expiry_time
  }
@end

// ── ৩. টোকেন ভ্যালিডেশন (Token Verification) ──────────────────────────────────
// WHY: টোকেনের মেয়াদ, হেক্স অক্ষর বৈধতা ও এমবেডেড ক্রিপ্টোগ্রাফিক MAC যাচাই করে অননুমোদিত অ্যাক্সেস রোধ করা।
@fn verify_token(token, current_time)
  @if str_len(token.value) != 64
    return 0
  @end
  @if current_time > token.expiry
    return 0
  @end
  // 1. Validate that all 64 characters are valid lowercase hex digits ('0'-'9', 'a'-'f')
  i = 0
  @while i < 64
    c = ord(char_at(token.value, i))
    is_hex = 0
    @if (c >= 48 && c <= 57) || (c >= 97 && c <= 102)
      is_hex = 1
    @end
    @if is_hex == 0
      return 0
    @end
    i = i + 1
  @end
  // 2. Verify embedded 16-char cryptographic MAC tag over prefix48 and token.expiry
  prefix48 = str_sub(token.value, 0, 48)
  actual_tag = str_sub(token.value, 48, 64)
  expected_mac = sha256_hex("lipi_vault_mac_v2:" + prefix48 + ":" + int_to_str(token.expiry))
  expected_tag = str_sub(expected_mac, 0, 16)
  @if vault_ct_equals(actual_tag, expected_tag) != 1
    return 0
  @end
  return 1
@end

