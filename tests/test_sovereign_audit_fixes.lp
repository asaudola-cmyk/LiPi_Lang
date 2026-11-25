// ==============================================================================
// 🛡️ REGRESSION TEST: SOVEREIGN A-TO-Z AUDIT FIXES (M1-M6 END-TO-END SUITE)
// ==============================================================================
// Verifies every critical fix across compiler/Kavach, stdlib (Unicode RFC 3629,
// IEEE-754 f64 math, JSON \uXXXX + UTF-16 surrogates), TLS 1.3 HTTPS client
// handshake + tamper rejection, LipiFS content-SHA256 bit-rot detection,
// LipiDB WAL CRC-32 corruption rejection, Crypto KATs (SHA-512, Poly1305,
// SHA3-256, AES-256-GCM, Argon2id), JWT alg:none/expiry defense, and aati.lock.

import "utso/core/unicode"
import "utso/core/math"
import "utso/core/json"
import "utso/core/json_fast"
import "utso/net/http"
import "aati/lipi_fs/lipifs"
import "aati/lipidb/wal"

@fn audit_write_file(path, content)
  fd = syscall(2, path, 577, 420, 0, 0, 0)
  @if fd < 0 return -1 @end
  syscall(1, fd, content, len(content), 0, 0, 0)
  syscall(3, fd, 0, 0, 0, 0, 0)
  return 0
@end

@fn audit_exec(exe, a1, a2, a3, log_p)
  argv = malloc(64)
  env = malloc(32)
  st = malloc(8)
  i = 0
  @while i < 64
    mem_byte_write(argv, i, 0)
    i = i + 1
  @end
  mem_write(env, 0, "PATH=/usr/bin:/bin:/usr/local/bin")
  mem_write(env, 8, 0)
  mem_write(st, 0, 0)

  mem_write(argv, 0, exe)
  idx = 1
  @if len(a1) > 0 mem_write(argv, idx * 8, a1) idx = idx + 1 @end
  @if len(a2) > 0 mem_write(argv, idx * 8, a2) idx = idx + 1 @end
  @if len(a3) > 0 mem_write(argv, idx * 8, a3) idx = idx + 1 @end
  mem_write(argv, idx * 8, 0)

  pid = syscall(57, 0, 0, 0, 0, 0, 0)
  @if pid == 0
    cfd = syscall(2, log_p, 577, 420, 0, 0, 0)
    @if cfd >= 0
      syscall(33, cfd, 1, 0, 0, 0, 0)
      syscall(33, cfd, 2, 0, 0, 0, 0)
      syscall(3, cfd, 0, 0, 0, 0, 0)
    @end
    syscall(59, exe, argv, env, 0, 0, 0)
    syscall(60, 127, 0, 0, 0, 0, 0)
  @end

  syscall(61, pid, st, 0, 0, 0, 0)
  raw = mem_read(st, 0) & 65535
  code = (raw / 256) % 256
  @if (raw & 127) != 0
    code = 128 + (raw & 127)
  @end
  free(argv, 64)
  free(env, 32)
  free(st, 8)
  return code
@end

@fn build_audit_server_hello(s_priv)
  s_pub = x25519_public_key(s_priv)
  body = [3, 3]
  i = 0
  @while i < 32
    body = body.push((i * 5 + 3) & 255)
    i = i + 1
  @end
  body = body.push(32)
  i = 0
  @while i < 32
    body = body.push(i & 255)
    i = i + 1
  @end
  body = body.push(19)
  body = body.push(1)
  body = body.push(0)
  exts = [0, 43, 0, 2, 3, 4, 0, 51, 0, 36, 0, 29, 0, 32]
  exts = tls_append_bytes(exts, s_pub)
  elen = exts.len()
  body = body.push((elen / 256) & 255)
  body = body.push(elen & 255)
  body = tls_append_bytes(body, exts)
  bl = body.len()
  hs = [2, (bl / 65536) & 255, (bl / 256) & 255, bl & 255]
  return tls_append_bytes(hs, body)
@end

@fn audit_tls_serve_once(listener: TcpListener, tamper_fin)
  stream = tcp_listener_accept(listener)
  @if stream.tcp_fd < 0 return 1 @end
  rec = _http_tls_read_record(stream.tcp_fd)
  @if rec.tls_rec_ok != 1 tcp_stream_close(stream) return 1 @end
  ch_hs = rec.tls_rec_body
  sid_len = ch_hs[38] & 255
  p = 39 + sid_len
  cs_len = ((ch_hs[p] & 255) * 256) | (ch_hs[p + 1] & 255)
  p = p + 2 + cs_len
  cm_len = ch_hs[p] & 255
  p = p + 1 + cm_len
  ext_tot = ((ch_hs[p] & 255) * 256) | (ch_hs[p + 1] & 255)
  p = p + 2
  c_pub = []
  end_p = p + ext_tot
  @while p + 4 <= end_p
    et = ((ch_hs[p] & 255) * 256) | (ch_hs[p + 1] & 255)
    el = ((ch_hs[p + 2] & 255) * 256) | (ch_hs[p + 3] & 255)
    p = p + 4
    @if et == 51 && el >= 38
      c_pub = _http_tls_slice(ch_hs, p + 6, p + 38)
    @end
    p = p + el
  @end

  s_priv = _http_tls_rand32()
  sh_hs = build_audit_server_hello(s_priv)
  sh_len = sh_hs.len()
  sh_rec = tls_append_bytes([22, 3, 3, (sh_len / 256) & 255, sh_len & 255], sh_hs)
  _http_tls_write_exact(stream.tcp_fd, sh_rec)

  shared = x25519_shared_secret(s_priv, c_pub)
  hs_transcript = tls_append_bytes(tls_append_bytes([], ch_hs), sh_hs)
  hs_keys = tls13_derive_handshake_keys(shared, sha256_hash_bytes(hs_transcript))

  ee = [8, 0, 0, 2, 0, 0]
  hs_transcript = tls_append_bytes(hs_transcript, ee)
  ca_seed = [
    9, 19, 29, 39, 49, 59, 69, 79, 89, 99, 109, 119, 129, 139, 149, 159,
    169, 179, 189, 199, 209, 219, 229, 239, 249, 7, 17, 27, 37, 47, 57, 67
  ]
  ed_seed = [
    17, 34, 51, 68, 85, 102, 119, 136, 153, 170, 187, 204, 221, 238, 255, 1,
    18, 35, 52, 69, 86, 103, 120, 137, 154, 171, 188, 205, 222, 239, 2, 19
  ]
  ed_kp = ed25519_keygen(ed_seed)
  der = x509_build_signed_ed25519_cert("Audit Root CA", "localhost", "localhost", "250101000000Z", "350101000000Z", 0, ed_kp.public_key, ca_seed, 702)
  dl = der.len()
  cert_entry = tls_append_bytes([(dl / 65536) & 255, (dl / 256) & 255, dl & 255], der)
  cert_entry = tls_append_bytes(cert_entry, [0, 0])
  clist_len = cert_entry.len()
  cert_body = tls_append_bytes([0, (clist_len / 65536) & 255, (clist_len / 256) & 255, clist_len & 255], cert_entry)
  cbl = cert_body.len()
  cert_msg = tls_append_bytes([11, (cbl / 65536) & 255, (cbl / 256) & 255, cbl & 255], cert_body)
  hs_transcript = tls_append_bytes(hs_transcript, cert_msg)

  cv_hash = sha256_hash_bytes(hs_transcript)
  cv_signed = []
  ci = 0
  @while ci < 64
    cv_signed = cv_signed.push(32)
    ci = ci + 1
  @end
  cv_label = "TLS 1.3, server CertificateVerify"
  ci = 0
  @while ci < str_len(cv_label)
    cv_signed = cv_signed.push(str_char_at(cv_label, ci) & 255)
    ci = ci + 1
  @end
  cv_signed = cv_signed.push(0)
  cv_signed = tls_append_bytes(cv_signed, cv_hash)
  cv_sig = ed25519_sign(ed_kp.secret_key, cv_signed)
  cv_msg = tls_append_bytes([15, 0, 0, 68, 8, 7, 0, 64], cv_sig)
  hs_transcript = tls_append_bytes(hs_transcript, cv_msg)

  s_fin_key = tls13_hkdf_expand_label(hs_keys.server_handshake_traffic_secret, "finished", [], 32)
  fin_mac = tls13_hmac_sha256(s_fin_key, sha256_hash_bytes(hs_transcript))
  @if tamper_fin == 1
    fin_mac = list_set(fin_mac, 0, (fin_mac[0] ^ 1) & 255)
  @end
  s_fin = tls_append_bytes([20, 0, 0, 32], fin_mac)
  hs_transcript = tls_append_bytes(hs_transcript, s_fin)

  flight = tls_append_bytes(tls_append_bytes(tls_append_bytes(ee, cert_msg), cv_msg), s_fin)
  flight_rec = _http_tls_wrap_aead_record(hs_keys.server_write_key, hs_keys.server_write_iv, 0, 22, flight)
  _http_tls_write_exact(stream.tcp_fd, flight_rec)

  @if tamper_fin == 1
    tcp_stream_close(stream)
    return 0
  @end

  zero32 = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
  derived_hs = tls13_hkdf_expand_label(hs_keys.handshake_secret, "derived", sha256_hash_bytes([]), 32)
  master_secret = tls13_hkdf_extract(derived_hs, zero32)
  fin_hash = sha256_hash_bytes(hs_transcript)
  s_app_traffic = tls13_hkdf_expand_label(master_secret, "s ap traffic", fin_hash, 32)
  c_app_traffic = tls13_hkdf_expand_label(master_secret, "c ap traffic", fin_hash, 32)
  s_app_key = tls13_hkdf_expand_label(s_app_traffic, "key", [], 16)
  s_app_iv  = tls13_hkdf_expand_label(s_app_traffic, "iv", [], 12)
  c_app_key = tls13_hkdf_expand_label(c_app_traffic, "key", [], 16)
  c_app_iv  = tls13_hkdf_expand_label(c_app_traffic, "iv", [], 12)

  cfin_rec = _http_tls_read_record(stream.tcp_fd)
  @if cfin_rec.tls_rec_ok != 1 tcp_stream_close(stream) return 1 @end
  creq_rec = _http_tls_read_record(stream.tcp_fd)
  @if creq_rec.tls_rec_ok != 1 tcp_stream_close(stream) return 1 @end
  dec_req = _http_tls_unwrap_aead_record(c_app_key, c_app_iv, 0, creq_rec.tls_rec_hdr, creq_rec.tls_rec_body)
  @if dec_req.tls_pt_ok != 1 tcp_stream_close(stream) return 1 @end

  http_resp = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 14\r\nConnection: close\r\n\r\nTLS13_AUDIT_OK"
  resp_rec = _http_tls_wrap_aead_record(s_app_key, s_app_iv, 0, 23, tls_string_to_bytes(http_resp))
  _http_tls_write_exact(stream.tcp_fd, resp_rec)
  tcp_stream_close(stream)
  return 0
@end

@fn main()
  say "================================================================="
  say "🛡️ SOVEREIGN A-TO-Z AUDIT FIXES END-TO-END REGRESSION SUITE"
  say "================================================================="

  // 1. Unicode RFC 3629 Overlong/Surrogate Rejection + Multi-digit Bengali Numerals
  @if utf8_byte_len(128) != 1 || utf8_byte_len(193) != 1 || utf8_byte_len(245) != 1
    say "FAIL: RFC 3629 utf8_byte_len invalid lead byte check"
    return 1
  @end
  overlong_s = chr(192) + chr(175)
  @if utf8_decode_codepoint(overlong_s, 0) != 65533 || utf8_is_valid(overlong_s) != 0
    say "FAIL: RFC 3629 overlong C0 AF must decode to U+FFFD (65533)"
    return 1
  @end
  surr_s = chr(237) + chr(160) + chr(128)
  @if utf8_decode_codepoint(surr_s, 0) != 65533 || utf8_is_valid(surr_s) != 0
    say "FAIL: RFC 3629 surrogate ED A0 80 must be rejected"
    return 1
  @end
  @if utf8_is_valid("লিপি") != 1 || bengali_num_to_int("২০২৬") != 2026
    say "FAIL: valid Bengali UTF-8 or multi-digit numeral decoding"
    return 1
  @end
  say "  [PASS] 1. Unicode RFC 3629 & multi-digit Bengali numerals (২০২৬ == 2026)"

  // 2. IEEE-754 f64 Real Mathematical Accuracy
  sq2 = math_sqrt(2.0)
  @if sq2 < 1.414210 || sq2 > 1.414220
    say "FAIL: math_sqrt(2.0) out of bounds"
    return 1
  @end
  sn5 = math_sin(0.5)
  @if sn5 < 0.479400 || sn5 > 0.479450
    say "FAIL: math_sin(0.5) out of bounds"
    return 1
  @end
  ex1 = math_exp(1.0)
  @if ex1 < 2.718270 || ex1 > 2.718290
    say "FAIL: math_exp(1.0) out of bounds"
    return 1
  @end
  lne = math_ln(math_e())
  @if lne < 0.999900 || lne > 1.000100
    say "FAIL: math_ln(e) out of bounds"
    return 1
  @end
  say "  [PASS] 2. IEEE-754 f64 transcendental math verified"

  // 3. JSON \uXXXX + UTF-16 Surrogate Pair Decoding (json & json_fast)
  em_slow = json_unescape("\\uD83D\\uDE00")
  em_fast = fast_json_unescape("\\uD83D\\uDE00")
  @if str_len(em_slow) != 4 || str_len(em_fast) != 4
    say "FAIL: UTF-16 surrogate pair did not decode to 4-byte UTF-8"
    return 1
  @end
  @if (str_char_at(em_slow, 0) & 255) != 240 || (str_char_at(em_fast, 0) & 255) != 240
    say "FAIL: U+1F600 leading byte expected 0xF0 (240)"
    return 1
  @end
  say "  [PASS] 3. JSON \\uXXXX + UTF-16 surrogate pair decoding verified"

  // 4. Live Loopback HTTPS TLS 1.3 Client Roundtrip + ServerFinished Tamper Rejection
  port = 18449
  listener = tcp_listener_bind("127.0.0.1", port)
  @if listener.tcpl_fd < 0
    say "FAIL: loopback bind failed"
    return 1
  @end
  ca_seed = [
    9, 19, 29, 39, 49, 59, 69, 79, 89, 99, 109, 119, 129, 139, 149, 159,
    169, 179, 189, 199, 209, 219, 229, 239, 249, 7, 17, 27, 37, 47, 57, 67
  ]
  ca_kp = ed25519_keygen(ca_seed)
  ca_cert = x509_build_signed_ed25519_cert("Audit Root CA", "Audit Root CA", "", "250101000000Z", "350101000000Z", 1, ca_kp.public_key, ca_seed, 701)
  tls13_clear_custom_trust_roots()
  tls13_add_trust_root(ca_cert)
  st = malloc(8)
  p1 = syscall(57, 0, 0, 0, 0, 0, 0)
  @if p1 == 0
    audit_tls_serve_once(listener, 0)
    syscall(60, 0, 0, 0, 0, 0, 0)
  @end
  resp = http_get("https://localhost:18449/audit")
  syscall(61, p1, st, 0, 0, 0, 0)
  @if resp.status_code != 200 || resp.body != "TLS13_AUDIT_OK"
    tls13_clear_custom_trust_roots()
    tcp_close(listener.tcpl_fd)
    free(st, 8)
    say "FAIL: HTTPS TLS 1.3 loopback roundtrip failed"
    return 1
  @end
  p2 = syscall(57, 0, 0, 0, 0, 0, 0)
  @if p2 == 0
    audit_tls_serve_once(listener, 1)
    syscall(60, 0, 0, 0, 0, 0, 0)
  @end
  bad_resp = http_get("https://localhost:18449/audit")
  syscall(61, p2, st, 0, 0, 0, 0)
  tls13_clear_custom_trust_roots()
  tcp_close(listener.tcpl_fd)
  free(st, 8)
  @if bad_resp.status_code != 0
    say "FAIL: tampered TLS 1.3 ServerFinished was accepted"
    return 1
  @end
  say "  [PASS] 4. HTTPS TLS 1.3 loopback handshake & MAC tamper rejection verified"

  // 5. LipiFS Real Content SHA-256 Bit-Rot Detection & Self-Healing
  fs = lipifs_create(0 - 1, 64)
  fs = lipifs_write_file_cow(fs, "secret.txt", "sovereign_payload")
  @if lipifs_verify_and_heal_block(fs, 1, "") != 1
    say "FAIL: clean block failed integrity check"
    return 1
  @end
  blk = fs.allocated_blocks[0]
  blk.data_bytes = "tampered_payload!"
  @if lipifs_verify_and_heal_block(fs, 1, "") != 0
    say "FAIL: LipiFS did not detect unhealed content bit-rot"
    return 1
  @end
  @if lipifs_verify_and_heal_block(fs, 1, "sovereign_payload") != 1
    say "FAIL: LipiFS failed to heal block from mirror"
    return 1
  @end
  @if lipifs_verify_and_heal_block(fs, 1, "") != 1
    say "FAIL: LipiFS post-heal verification failed"
    return 1
  @end
  say "  [PASS] 5. LipiFS SHA-256 content bit-rot detection & mirror heal verified"

  // 6. LipiDB WAL CRC-32 Verification & Corruption Rejection
  wal_p = "/tmp/audit_fixes_" + to_str(syscall(39, 0, 0, 0, 0, 0, 0)) + ".wal"
  sys_unlink(wal_p)
  w = wal_open(wal_p)
  wal_append_put(w, 1, "alpha", "one")
  wal_append_put(w, 2, "beta", "two")
  wal_sync(w)
  wal_close(w)
  recs_ok = wal_replay_all(wal_p)
  @if recs_ok.len() != 2
    sys_unlink(wal_p)
    say "FAIL: WAL replay expected 2 valid records"
    return 1
  @end
  @! Flip last byte of record 2 (payload byte) to corrupt record 2 CRC-32
  wfd = syscall(2, wal_p, 2, 0, 0, 0, 0)
  fsz = syscall(8, wfd, 0, 2, 0, 0, 0)
  @if wfd >= 0 && fsz > 10
    syscall(8, wfd, fsz - 1, 0, 0, 0, 0)
    bpatch = malloc(4)
    syscall(0, wfd, bpatch, 1, 0, 0, 0)
    mem_byte_write(bpatch, 0, (mem_byte_read(bpatch, 0) ^ 255) & 255)
    syscall(8, wfd, fsz - 1, 0, 0, 0, 0)
    syscall(1, wfd, bpatch, 1, 0, 0, 0)
    syscall(3, wfd, 0, 0, 0, 0, 0)
    free(bpatch, 4)
  @end
  recs_corrupt = wal_replay_all(wal_p)
  sys_unlink(wal_p)
  @if recs_corrupt.len() != 1
    say "FAIL: WAL replay failed to reject CRC-32 corrupted record"
    return 1
  @end
  say "  [PASS] 6. LipiDB WAL CRC-32 corruption rejection verified"

  // 7. Subprocess Verification: Crypto KATs + JWT alg:none/exp + --kavach + aati verify-lock
  pid = syscall(39, 0, 0, 0, 0, 0, 0)
  log_p = "/tmp/audit_sub_" + to_str(pid) + ".log"

  // 7a. Crypto KATs (SHA-512, Poly1305 RFC 8439, SHA3-256 FIPS 202, AES-256-GCM, Argon2id)
  c_src = "/tmp/audit_crypto_" + to_str(pid) + ".lp"
  c_bin = "/tmp/audit_crypto_" + to_str(pid)
  c_code = "include \"utso/crypto/crypto.lp\"\nfn hex_arr buf n\n    hx = \"0123456789abcdef\"\n    out = \"\"\n    i = 0\n    while i < n\n        b = mem_byte_read(buf, i) & 255\n        out = out + char_at(hx, (b / 16) & 15) + char_at(hx, b & 15)\n        i = i + 1\n    return out\nfn main\n    @! SHA-512(\"abc\")\n    s5 = sha512_hex_string(\"abc\")\n    if str_sub(s5, 0, 16) != \"ddaf35a193617aba\" return 1\n    @! FIPS 202 SHA3-256(\"abc\")\n    s3out = alloc(32)\n    SHA3_256(\"abc\", 3, s3out)\n    if str_sub(hex_arr(s3out, 32), 0, 16) != \"3a985da74fe225b2\" return 2\n    @! RFC 8439 Poly1305 KAT\n    msg = \"Cryptographic Forum Research Group\"\n    pk = [133,214,190,120,87,85,109,51,127,68,82,254,66,213,6,168,1,3,128,138,251,13,178,253,74,191,246,175,65,73,245,27]\n    pkbuf = alloc(32)\n    i = 0\n    while i < 32\n        mem_byte_write(pkbuf, i, pk[i])\n        i = i + 1\n    tag = alloc(16)\n    poly1305_mac(msg, len(msg), pkbuf, tag)\n    if hex_arr(tag, 16) != \"a8061dc1305136c6c22b8baf0c0127a9\" return 3\n    @! AES-256-GCM + 1-bit tamper rejection + Argon2id\n    key = alloc(32)\n    iv = alloc(12)\n    pt = \"SovereignGCM256\"\n    ct = alloc(32)\n    g_tag = alloc(16)\n    dec = alloc(32)\n    i = 0\n    while i < 32\n        mem_byte_write(key, i, (i * 7 + 1) & 255)\n        i = i + 1\n    i = 0\n    while i < 12\n        mem_byte_write(iv, i, (i + 9) & 255)\n        i = i + 1\n    AES256_GCM_encrypt(key, iv, pt, len(pt), ct, \"hdr\", 3, g_tag)\n    if AES256_GCM_decrypt(key, iv, ct, len(pt), dec, \"hdr\", 3, g_tag) != 0 return 4\n    mem_byte_write(ct, 0, (mem_byte_read(ct, 0) ^ 1) & 255)\n    if AES256_GCM_decrypt(key, iv, ct, len(pt), dec, \"hdr\", 3, g_tag) == 0 return 5\n    ah = crypto_password_hash(\"lipi_pass\", 9)\n    if crypto_password_verify(\"lipi_pass\", 9, ah) != 1 return 6\n    if crypto_password_verify(\"wrong_pass\", 10, ah) != 0 return 7\n    return 0\nmain()\n"
  audit_write_file(c_src, c_code)
  @if audit_exec("bin/lipc", c_src, "-o", c_bin, log_p) != 0
    sys_unlink(c_src)
    sys_unlink(log_p)
    say "FAIL: crypto KAT sub-compile failed"
    return 1
  @end
  c_rc = audit_exec(c_bin, "", "", "", log_p)
  sys_unlink(c_src)
  sys_unlink(c_bin)
  @if c_rc != 0
    sys_unlink(log_p)
    say "FAIL: crypto KAT sub-test failed with code " + to_str(c_rc)
    return 1
  @end
  say "  [PASS] 7a. Crypto KATs (SHA-512, SHA3-256, Poly1305, AES-256-GCM, Argon2id)"

  // 7b. JWT alg:none & expiry rejection (lipi_security/jwt & lipi_web/auth/jwt)
  j_src = "/tmp/audit_jwt_" + to_str(pid) + ".lp"
  j_bin = "/tmp/audit_jwt_" + to_str(pid)
  j_code = "import \"aati/lipi_web/auth/jwt\"\n@fn main()\n  tok = jwt_create_token(\"alice\", \"lipi\", 2000, \"secret123\")\n  @if jwt_verify_at(tok, \"secret123\", 1500) != 1 return 1 @end\n  @if jwt_verify_at(tok, \"secret123\", 2500) != 0 return 2 @end\n  none_tok = jwt_sign_payload(\"{\\\"alg\\\":\\\"none\\\",\\\"typ\\\":\\\"JWT\\\"}\", \"{\\\"sub\\\":\\\"admin\\\"}\", \"secret123\")\n  @if jwt_verify(none_tok, \"secret123\") != 0 return 3 @end\n  return 0\n@end\nmain()\n"
  audit_write_file(j_src, j_code)
  @if audit_exec("bin/lipc", j_src, "-o", j_bin, log_p) != 0
    sys_unlink(j_src)
    sys_unlink(log_p)
    say "FAIL: JWT security sub-compile failed"
    return 1
  @end
  j_rc = audit_exec(j_bin, "", "", "", log_p)
  sys_unlink(j_src)
  sys_unlink(j_bin)
  @if j_rc != 0
    sys_unlink(log_p)
    say "FAIL: JWT alg:none or exp enforcement failed"
    return 1
  @end
  say "  [PASS] 7b. JWT alg:none & exp enforcement verified"

  // 7c. --kavach policy gate & aati verify-lock gate
  k_src = "/tmp/audit_kav_" + to_str(pid) + ".lp"
  k_bin = "/tmp/audit_kav_" + to_str(pid)
  audit_write_file(k_src, "fn main\n  return syscall(39, 0, 0, 0, 0, 0, 0)\nmain()\n")
  k_rc = audit_exec("bin/lipc", k_src, k_bin, "--kavach", log_p)
  sys_unlink(k_src)
  sys_unlink(k_bin)
  @if k_rc == 0
    sys_unlink(log_p)
    say "FAIL: --kavach allowed unguarded raw syscall"
    return 1
  @end
  v_rc = audit_exec("bin/aati", "verify-lock", "aati.lock", "", log_p)
  sys_unlink(log_p)
  @if v_rc != 0
    say "FAIL: aati verify-lock aati.lock failed"
    return 1
  @end
  say "  [PASS] 7c. --kavach unsafe syscall rejection & aati verify-lock verified"

  say "================================================================="
  say "🎉 ALL SOVEREIGN A-TO-Z AUDIT FIXES VERIFIED (100%)"
  say "================================================================="
  return 0
@end

main()
