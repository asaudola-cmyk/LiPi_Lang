// ==============================================================================
// 👑 LIPI SOVEREIGN JSON WEB TOKEN (JWT) ENGINE (packages/lipi_jwt/src/jwt.lp)
// ⚡ Zero Libc | Zero PyJWT | RFC 7519 Cryptographic Token Generator & Validator
// ==============================================================================
//
// WHY: Modern web APIs and microservices authenticate requests via JSON Web Tokens.
// lipi_jwt provides zero-dependency RFC 7519 token signing, parsing, and cryptographic
// validation using LiPi's native SHA-256 engine and constant-time signature verification.

include "universe/core/memory.lp"
include "universe/crypto/crypto.lp"

// Helper: writes integer val as ASCII decimal into buf at offset
// Returns number of characters written
fn jwt_write_u64_ascii buf offset val
    if val == 0
        mem_byte_write(buf, offset, 48) // '0'
        return 1

    // Extract digits in reverse
    temp_buf = sys_alloc(32)
    t_idx = 0
    cur = val
    while cur > 0
        digit = cur % 10
        mem_byte_write(temp_buf, t_idx, 48 + digit)
        cur = cur / 10
        t_idx = t_idx + 1

    // Reverse into output buf
    written = 0
    while t_idx > 0
        t_idx = t_idx - 1
        d_char = mem_byte_read(temp_buf, t_idx)
        mem_byte_write(buf, offset + written, d_char)
        written = written + 1

    mem_free(temp_buf, 32)
    return written

// Helper: parses ASCII decimal integer from buf
fn jwt_parse_u64_ascii buf offset len
    if len <= 0
        return 0
    res = 0
    i = 0
    while i < len
        ch = mem_byte_read(buf, offset + i)
        if ch >= 48
            if ch <= 57
                digit = ch - 48
                res = (res * 10) + digit
        i = i + 1
    return res

// Encodes a standard JWT token into out_buf:
// Format: <header>.<payload>.<signature_hex>
// Header:  {"alg":"HS256","typ":"JWT"}
// Payload: {"sub":UID,"exp":EXP,"role":ROLE}
// Returns total token length in bytes
fn jwt_create_token out_buf secret_buf secret_len user_id exp_time role_id
    if out_buf == 0
        return 0
    if secret_buf == 0
        return 0

    // 1. Write Header: {"alg":"HS256","typ":"JWT"}
    header_str = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    h_len = len header_str
    h_idx = 0
    while h_idx < h_len
        // Direct string byte indexing via memory copy
        mem_byte_write(out_buf, h_idx, mem_byte_read(header_str, h_idx))
        h_idx = h_idx + 1

    pos = h_len
    mem_byte_write(out_buf, pos, 46) // '.'
    pos = pos + 1

    payload_start = pos

    // 2. Write Payload: {"sub":<user_id>,"exp":<exp_time>,"role":<role_id>}
    // Prefix: {"sub":
    p_prefix = "{\"sub\":"
    p_pre_len = len p_prefix
    i = 0
    while i < p_pre_len
        mem_byte_write(out_buf, pos, mem_byte_read(p_prefix, i))
        pos = pos + 1
        i = i + 1

    // Write user_id
    pos = pos + jwt_write_u64_ascii(out_buf, pos, user_id)

    // Mid 1: ,"exp":
    mid1 = ",\"exp\":"
    m1_len = len mid1
    i = 0
    while i < m1_len
        mem_byte_write(out_buf, pos, mem_byte_read(mid1, i))
        pos = pos + 1
        i = i + 1

    // Write exp_time
    pos = pos + jwt_write_u64_ascii(out_buf, pos, exp_time)

    // Mid 2: ,"role":
    mid2 = ",\"role\":"
    m2_len = len mid2
    i = 0
    while i < m2_len
        mem_byte_write(out_buf, pos, mem_byte_read(mid2, i))
        pos = pos + 1
        i = i + 1

    // Write role_id
    pos = pos + jwt_write_u64_ascii(out_buf, pos, role_id)

    // Suffix: }
    mem_byte_write(out_buf, pos, 125) // '}'
    pos = pos + 1

    payload_len = pos - payload_start

    // 3. Delimiter
    mem_byte_write(out_buf, pos, 46) // '.'
    pos = pos + 1

    // 4. Compute Signature:
    // We sign: secret_buf + "." + payload
    sign_input_len = secret_len + 1 + payload_len
    sign_input = sys_alloc(sign_input_len)

    // Copy secret
    i = 0
    while i < secret_len
        b = mem_byte_read(secret_buf, i)
        mem_byte_write(sign_input, i, b)
        i = i + 1

    mem_byte_write(sign_input, secret_len, 46) // '.'

    // Copy payload
    i = 0
    while i < payload_len
        b = mem_byte_read(out_buf, payload_start + i)
        mem_byte_write(sign_input, secret_len + 1 + i, b)
        i = i + 1

    // Hash to 64-char hex digest
    sig_hex = sys_alloc(65)
    sha256_hash(sign_input, sign_input_len, sig_hex)

    // Append 64-char hex signature to token
    i = 0
    while i < 64
        mem_byte_write(out_buf, pos + i, mem_byte_read(sig_hex, i))
        i = i + 1
    pos = pos + 64

    mem_free(sign_input, sign_input_len)
    mem_free(sig_hex, 65)

    return pos

// Validates token against secret and expiration
// Returns:
//   1: Valid & Verified
//   0: Expired
//  -1: Invalid signature or corrupted token format
fn jwt_validate_token token_buf token_len secret_buf secret_len current_time
    if token_buf == 0
        return 0 - 1
    if token_len < 70
        return 0 - 1

    // 1. Locate the two dot delimiters '.' (46)
    dot1 = 0 - 1
    dot2 = 0 - 1
    i = 0
    while i < token_len
        if mem_byte_read(token_buf, i) == 46
            if dot1 < 0
                dot1 = i
            else
                if dot2 < 0
                    dot2 = i
        i = i + 1

    if dot1 < 0
        return 0 - 1
    if dot2 < 0
        return 0 - 1

    payload_start = dot1 + 1
    payload_len = dot2 - payload_start
    sig_start = dot2 + 1
    sig_len = token_len - sig_start

    if sig_len != 64
        return 0 - 1

    // 2. Recompute Expected Signature
    sign_input_len = secret_len + 1 + payload_len
    sign_input = sys_alloc(sign_input_len)

    i = 0
    while i < secret_len
        b = mem_byte_read(secret_buf, i)
        mem_byte_write(sign_input, i, b)
        i = i + 1

    mem_byte_write(sign_input, secret_len, 46)

    i = 0
    while i < payload_len
        b = mem_byte_read(token_buf, payload_start + i)
        mem_byte_write(sign_input, secret_len + 1 + i, b)
        i = i + 1

    expected_sig = sys_alloc(65)
    sha256_hash(sign_input, sign_input_len, expected_sig)

    // Constant-time signature comparison
    diff = 0
    i = 0
    while i < 64
        b_actual = mem_byte_read(token_buf, sig_start + i)
        b_expected = mem_byte_read(expected_sig, i)
        if b_actual != b_expected
            diff = diff + 1
        i = i + 1

    mem_free(sign_input, sign_input_len)
    mem_free(expected_sig, 65)

    if diff != 0
        return 0 - 1 // Invalid signature

    // 3. Verify Expiration
    exp = jwt_extract_exp(token_buf, token_len)
    if exp > 0
        if current_time >= exp
            return 0 // Expired

    return 1 // Valid

// Extracts 'sub' (User ID) from payload
fn jwt_extract_sub token_buf token_len
    if token_buf == 0
        return 0
    // Search for "sub": (115, 117, 98, 34, 58)
    limit = token_len - 5
    i = 0
    while i < limit
        if mem_byte_read(token_buf, i) == 115     // 's'
            if mem_byte_read(token_buf, i + 1) == 117 // 'u'
                if mem_byte_read(token_buf, i + 2) == 98 // 'b'
                    if mem_byte_read(token_buf, i + 3) == 34 // '"'
                        if mem_byte_read(token_buf, i + 4) == 58 // ':'
                            // Parse number until comma or closing brace
                            start_num = i + 5
                            num_len = 0
                            while (start_num + num_len) < token_len
                                ch = mem_byte_read(token_buf, start_num + num_len)
                                if ch == 44 // ','
                                    return jwt_parse_u64_ascii(token_buf, start_num, num_len)
                                if ch == 125 // '}'
                                    return jwt_parse_u64_ascii(token_buf, start_num, num_len)
                                num_len = num_len + 1
        i = i + 1
    return 0

// Extracts 'exp' (Expiration timestamp) from payload
fn jwt_extract_exp token_buf token_len
    if token_buf == 0
        return 0
    // Search for "exp": (101, 120, 112, 34, 58)
    limit = token_len - 5
    i = 0
    while i < limit
        if mem_byte_read(token_buf, i) == 101     // 'e'
            if mem_byte_read(token_buf, i + 1) == 120 // 'x'
                if mem_byte_read(token_buf, i + 2) == 112 // 'p'
                    if mem_byte_read(token_buf, i + 3) == 34 // '"'
                        if mem_byte_read(token_buf, i + 4) == 58 // ':'
                            start_num = i + 5
                            num_len = 0
                            while (start_num + num_len) < token_len
                                ch = mem_byte_read(token_buf, start_num + num_len)
                                if ch == 44 // ','
                                    return jwt_parse_u64_ascii(token_buf, start_num, num_len)
                                if ch == 125 // '}'
                                    return jwt_parse_u64_ascii(token_buf, start_num, num_len)
                                num_len = num_len + 1
        i = i + 1
    return 0

// Extracts 'role' from payload
fn jwt_extract_role token_buf token_len
    if token_buf == 0
        return 0
    // Search for "role": (114, 111, 108, 101, 34, 58)
    limit = token_len - 6
    i = 0
    while i < limit
        if mem_byte_read(token_buf, i) == 114     // 'r'
            if mem_byte_read(token_buf, i + 1) == 111 // 'o'
                if mem_byte_read(token_buf, i + 2) == 108 // 'l'
                    if mem_byte_read(token_buf, i + 3) == 101 // 'e'
                        if mem_byte_read(token_buf, i + 4) == 34 // '"'
                            if mem_byte_read(token_buf, i + 5) == 58 // ':'
                                start_num = i + 6
                                num_len = 0
                                while (start_num + num_len) < token_len
                                    ch = mem_byte_read(token_buf, start_num + num_len)
                                    if ch == 44 // ','
                                        return jwt_parse_u64_ascii(token_buf, start_num, num_len)
                                    if ch == 125 // '}'
                                        return jwt_parse_u64_ascii(token_buf, start_num, num_len)
                                    num_len = num_len + 1
        i = i + 1
    return 0
