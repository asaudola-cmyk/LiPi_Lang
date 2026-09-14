// ==============================================================================
// 🧪 LIPI PACKAGE TEST: Sovereign JSON Web Token (JWT) Engine Unit Test
// ==============================================================================

include "packages/lipi_jwt/src/jwt.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    say "  ✔ [PASS] " + test_name

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ [PASS] " + test_name

say "================================================================="
say "👑 LIPI JWT: RFC 7519 CRYPTOGRAPHIC TOKEN TEST 👑"
say "================================================================="

// Secret Key setup
secret = "sovereign_secret_key_888"
sec_len = len secret

// Token buffer allocation (256 bytes)
token_buf = sys_alloc(256)
mem_zero(token_buf, 256)

// 1. Issue Token: sub=1337, exp=2000000000, role=42
tok_len = jwt_create_token(token_buf, secret, sec_len, 1337, 2000000000, 42)
assert_true(tok_len > 70, "JWT token created with valid length")

// 2. Validate Token at current_time = 1700000000 (Before expiration)
valid_status = jwt_validate_token(token_buf, tok_len, secret, sec_len, 1700000000)
assert_eq(valid_status, 1, "Token cryptographic signature and validity confirmed")

// 3. Extract Claims from Token
sub = jwt_extract_sub(token_buf, tok_len)
assert_eq(sub, 1337, "Extracted User ID (sub) is 1337")

exp = jwt_extract_exp(token_buf, tok_len)
assert_eq(exp, 2000000000, "Extracted Expiration timestamp (exp) is 2000000000")

role = jwt_extract_role(token_buf, tok_len)
assert_eq(role, 42, "Extracted Role ID (role) is 42")

// 4. Test Expiration Detection (current_time = 2000000005)
expired_status = jwt_validate_token(token_buf, tok_len, secret, sec_len, 2000000005)
assert_eq(expired_status, 0, "Expired token correctly rejected with code 0")

// 5. Test Tamper Detection (Modify 1 character of signature)
sig_tamper_char = mem_byte_read(token_buf, tok_len - 1)
mem_byte_write(token_buf, tok_len - 1, sig_tamper_char + 1)
tamper_status = jwt_validate_token(token_buf, tok_len, secret, sec_len, 1700000000)
assert_eq(tamper_status, 0 - 1, "Tampered signature immediately rejected with code -1")

// Restore signature character
mem_byte_write(token_buf, tok_len - 1, sig_tamper_char)

// 6. Test Wrong Secret Key Rejection
wrong_secret = "attacker_imposter_key_111"
wrong_sec_len = len wrong_secret
wrong_key_status = jwt_validate_token(token_buf, tok_len, wrong_secret, wrong_sec_len, 1700000000)
assert_eq(wrong_key_status, 0 - 1, "Forged token with wrong key rejected with code -1")

mem_free(token_buf, 256)

say "🎉 ALL SOVEREIGN JWT TESTS PASSED!"
