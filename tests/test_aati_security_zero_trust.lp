// ==============================================================================
// REGRESSION TEST: AATI SECURITY ZERO-TRUST SUITE (JWT, ZKP, RSA, SANDBOX BPF)
// ==============================================================================
// Covers all 4 modules in `aati/lipi_security/` via isolated pure-Lipi
// sub-compiles & execution without touching signed `aati/*/` files:
//   1. `jwt.lp`: HMAC-SHA256 JWT sign + valid verify + wrong-secret rejection
//   2. `zkp.lp`: Schnorr Zero-Knowledge Proof prove + verify + tamper rejection
//   3. `rsa.lp`: 60-bit modular exponentiation encryption/decryption round-trip
//   4. `sandbox.lp`: Linux Seccomp-BPF filter compilation & validation

include "utso/io"
include "utso/string"

fn sec_resolve_compiler
    if syscall(21, "bin/lipc", 0, 0, 0, 0, 0) == 0
        return "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        return "bin/lipc_bin"
    return "bin/lipc"

fn sec_write_file path content
    fd = syscall(2, path, 577, 420, 0, 0, 0)
    if fd < 0
        return 0 - 1
    syscall(1, fd, content, len(content), 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 0

fn sec_read_file path
    fd = syscall(2, path, 0, 0, 0, 0, 0)
    if fd < 0
        return ""
    rbuf = malloc(16384)
    total = 0
    while total < 16383
        n = syscall(0, fd, rbuf + total, 16383 - total, 0, 0, 0)
        if n <= 0
            break
        total = total + n
    syscall(3, fd, 0, 0, 0, 0, 0)
    out = ""
    i = 0
    while i < total
        out = out + chr(mem_byte_read(rbuf, i))
        i = i + 1
    syscall(11, rbuf, 16384, 0, 0, 0, 0)
    return out

fn sec_exec exe a1 a2 log_p
    argv = malloc(64)
    env = malloc(16)
    st = malloc(8)
    i = 0
    while i < 64
        mem_byte_write(argv, i, 0)
        i = i + 1
    mem_write(env, 0, 0)
    mem_write(env, 8, 0)
    mem_write(st, 0, 0)

    mem_write(argv, 0, exe)
    idx = 1
    if len(a1) > 0
        mem_write(argv, idx * 8, a1)
        idx = idx + 1
    if len(a2) > 0
        mem_write(argv, idx * 8, a2)
        idx = idx + 1
    mem_write(argv, idx * 8, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        cfd = syscall(2, log_p, 577, 420, 0, 0, 0)
        if cfd >= 0
            syscall(33, cfd, 1, 0, 0, 0, 0)
            syscall(33, cfd, 2, 0, 0, 0, 0)
            syscall(3, cfd, 0, 0, 0, 0, 0)
        syscall(59, exe, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw = mem_read(st, 0) & 65535
    code = (raw / 256) % 256
    if (raw & 127) != 0
        code = 128 + (raw & 127)
    syscall(11, argv, 64, 0, 0, 0, 0)
    syscall(11, env, 16, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return code

fn main
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    comp = sec_resolve_compiler()
    jwt_src = "/tmp/sec_jwt_" + str(pid) + ".lp"
    jwt_bin = "/tmp/sec_jwt_" + str(pid)
    zkp_bin = "/tmp/sec_zkp_" + str(pid)
    rsa_src = "/tmp/sec_rsa_" + str(pid) + ".lp"
    rsa_bin = "/tmp/sec_rsa_" + str(pid)
    sbx_bin = "/tmp/sec_sbx_" + str(pid)
    log_p = "/tmp/sec_log_" + str(pid) + ".txt"

    // 1. JWT HS256 (RFC 2104 HMAC-SHA256 + RFC 4648 Base64URL + constant-shape compare)
    jwt_code = "import \"aati/lipi_security/jwt\"\n\n@fn main()\n  hdr_b = [123, 34, 97, 108, 103, 34, 58, 34, 72, 83, 50, 53, 54, 34, 125]\n  pay_b = [123, 34, 115, 117, 98, 34, 58, 34, 108, 105, 112, 105, 34, 125]\n  sec_b = [115, 111, 118, 101, 114, 101, 105, 103, 110]\n  bad_b = [116, 97, 109, 112, 101, 114, 101, 100]\n  inp = []\n  h_e = base64url_encode(hdr_b)\n  p_e = base64url_encode(pay_b)\n  i = 0\n  @while i < hdr_b.len() inp = inp.push(hdr_b[i]) i = i + 1 @end\n  inp = inp.push(46)\n  i = 0\n  @while i < pay_b.len() inp = inp.push(pay_b[i]) i = i + 1 @end\n  mac1 = hmac_sha256_bytes(sec_b, inp)\n  mac2 = hmac_sha256_bytes(sec_b, inp)\n  mac_bad = hmac_sha256_bytes(bad_b, inp)\n  @if mac1.len() != 32 return 1 @end\n  sig1 = base64url_encode(mac1)\n  sig2 = base64url_encode(mac2)\n  sig_bad = base64url_encode(mac_bad)\n  @if jwt_compare_sig(sig1, sig2) != 1 return 2 @end\n  @if jwt_compare_sig(sig1, sig_bad) != 0 return 3 @end\n  @if str_len(h_e) == 0 || str_len(p_e) == 0 return 4 @end\n  say \"SEC_JWT_OK\"\n  return 0\n@end\n\nmain()\n"
    sec_write_file(jwt_src, jwt_code)
    if sec_exec(comp, jwt_src, jwt_bin, log_p) != 0
        say "[ERR] aati/lipi_security/jwt compile failed"
        return 1
    if sec_exec(jwt_bin, "", "", log_p) != 0
        say "[ERR] aati/lipi_security/jwt verify failed"
        return 1
    if str_contains(sec_read_file(log_p), "SEC_JWT_OK") != 1
        say "[ERR] aati/lipi_security/jwt output mismatch"
        return 1
    say "[PASS] aati/lipi_security/jwt verified (HMAC-SHA256 + Base64URL + tamper reject)"

    // 2. Schnorr ZKP (module includes built-in @fn main() self-test)
    if sec_exec(comp, "aati/lipi_security/zkp.lp", zkp_bin, log_p) != 0
        say "[ERR] aati/lipi_security/zkp compile failed"
        return 1
    if sec_exec(zkp_bin, "", "", log_p) != 0
        say "[ERR] aati/lipi_security/zkp self-test exited non-zero"
        return 1
    zkp_out = sec_read_file(log_p)
    if str_contains(zkp_out, "PASS: valid Schnorr proof accepted") != 1 or str_contains(zkp_out, "PASS: tampered proof correctly rejected") != 1
        say "[ERR] aati/lipi_security/zkp assertion mismatch"
        return 1
    say "[PASS] aati/lipi_security/zkp verified (Schnorr accept + tamper reject)"

    // 3. RSA 60-bit modular exponentiation
    rsa_code = "import \"aati/lipi_security/rsa\"\n\n@fn main()\n  k = rsa_key_new()\n  msg = 123456789\n  ct = rsa_sec_encrypt(k, msg)\n  pt = rsa_sec_decrypt(k, ct)\n  @if pt != msg return 1 @end\n  say \"SEC_RSA_OK\"\n  return 0\n@end\n\nmain()\n"
    sec_write_file(rsa_src, rsa_code)
    if sec_exec(comp, rsa_src, rsa_bin, log_p) != 0
        say "[ERR] aati/lipi_security/rsa compile failed"
        return 1
    if sec_exec(rsa_bin, "", "", log_p) != 0
        say "[ERR] aati/lipi_security/rsa runtime failed"
        return 1
    if str_contains(sec_read_file(log_p), "SEC_RSA_OK") != 1
        say "[ERR] aati/lipi_security/rsa output mismatch"
        return 1
    say "[PASS] aati/lipi_security/rsa verified (60-bit round-trip)"

    // 4. Seccomp-BPF Sandbox filter builder & validator
    if sec_exec(comp, "aati/lipi_security/sandbox.lp", sbx_bin, log_p) != 0
        say "[ERR] aati/lipi_security/sandbox compile failed"
        return 1
    if sec_exec(sbx_bin, "", "", log_p) != 0
        say "[ERR] aati/lipi_security/sandbox validation failed"
        return 1
    say "[PASS] aati/lipi_security/sandbox verified (Seccomp-BPF compile + validate)"

    syscall(87, jwt_src, 0, 0, 0, 0, 0)
    syscall(87, jwt_bin, 0, 0, 0, 0, 0)
    syscall(87, zkp_bin, 0, 0, 0, 0, 0)
    syscall(87, rsa_src, 0, 0, 0, 0, 0)
    syscall(87, rsa_bin, 0, 0, 0, 0, 0)
    syscall(87, sbx_bin, 0, 0, 0, 0, 0)
    syscall(87, log_p, 0, 0, 0, 0, 0)

    say "✅ TEST_AATI_SECURITY_ZERO_TRUST_COMPLETE"
    return 0

main()
