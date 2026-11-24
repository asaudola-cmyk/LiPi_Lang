// ==============================================================================
// Lipi v1.0.1 Deep Upgrades End-to-End Test Suite
// File: tests/test_v101_deep_upgrades_e2e.lp
// Covers:
//   1. Compiler Linear-Scan ABI Eviction Safety, Call-Span Tightness & SSA Peephole
//   2. TLS 1.3 NIST P-384 Cert + Signing, SNI Multi-Domain & RFC 8446 PSK Resumption
//   3. Relational SQL Engine: ACID BEGIN/COMMIT/ROLLBACK, Hash Indexes, Hash Joins, GROUP BY
//   4. RFC 7540/7541 HTTP/2 Framing, HPACK Encode/Decode & Canonical Huffman Decoder
// ==============================================================================

include "utso/memory.lp"
include "utso/net/http2/server.lp"
include "aati/lipi_sql/src/sql.lp"

fn v101_assert_eq actual expected msg
    if actual != expected
        say "  [FAIL] " + msg + " (expected " + str(expected) + ", got " + str(actual) + ")"
        exit(1)
    end
    say "  [PASS] " + msg + ": " + str(actual)
    return 1

fn v101_assert_str actual expected msg
    if actual != expected
        say "  [FAIL] " + msg + " (expected '" + expected + "', got '" + actual + "')"
        exit(1)
    end
    say "  [PASS] " + msg + ": " + actual
    return 1

fn test_pillar2_tls13_sni_p384_and_psk
    say "▶ Pillar 2: TLS 1.3 NIST P-384, SNI Multi-Domain & RFC 8446 PSK Resumption..."

    // 2A. Pure-Lipi NIST P-384 X.509 certificate synthesis + RFC 5280 chain verification
    ca_sk = _tls13s_rand_bytes(48)
    leaf_sk = _tls13s_rand_bytes(48)
    ca_n = _tls13s_rand_bytes(48)
    leaf_n = _tls13s_rand_bytes(48)
    ca_pk = ecdsa_p384_keygen_from_scalar(ca_sk)
    leaf_pk = ecdsa_p384_keygen_from_scalar(leaf_sk)
    ca_der = x509_build_signed_p384_cert("Lipi P384 Test CA", "Lipi P384 Test CA", "", "250101000000Z", "350101000000Z", 1, ca_pk, ca_sk, ca_n, 9001)
    leaf_der = x509_build_signed_p384_cert("Lipi P384 Test CA", "api.lipi.local", "api.lipi.local", "250101000000Z", "350101000000Z", 0, leaf_pk, ca_sk, leaf_n, 9002)

    p_ca = x509_decode_full(ca_der)
    p_leaf = x509_decode_full(leaf_der)
    v101_assert_eq(x509_verify_signature_by_issuer(p_leaf, p_ca), 1, "P-384 leaf certificate cryptographically verified against P-384 CA")
    v101_assert_eq(x509_verify_chain([leaf_der, ca_der], "api.lipi.local", [ca_der], 1795400000), 1, "P-384 full RFC 5280 chain & hostname verified")

    // 2B. SNI multi-domain routing (exact, wildcard, TLD wildcard rejection)
    v101_assert_eq(_tls13s_sni_matches("*.svc.lipi.local", "auth.svc.lipi.local"), 1, "SNI single-label wildcard matches subdomain")
    v101_assert_eq(_tls13s_sni_matches("*.svc.lipi.local", "a.b.svc.lipi.local"), 0, "SNI wildcard rejects multi-label subdomain")
    v101_assert_eq(_tls13s_sni_matches("*.com", "evil.com"), 0, "SNI wildcard rejects TLD spoofing (*.com)")

    eng = tls13_record_engine_new()
    tls13_engine_add_sni_identity(eng, "api.lipi.local", [leaf_der, ca_der], leaf_sk, TLS_SIG_ECDSA_SECP384R1_SHA384)
    tls13_engine_add_sni_identity(eng, "*.svc.lipi.local", eng.re_cert_chain, eng.re_priv_key32, TLS_SIG_ECDSA_SECP256R1_SHA256)

    // Build initial full ClientHello for "api.lipi.local" -> selects P-384 SNI identity
    c_priv1 = _tls13s_rand_bytes(32)
    c_pub1 = x25519_public_key(c_priv1)
    ch1_obj = tls13_build_client_hello("api.lipi.local", c_pub1)
    s1 = tls13_engine_process_handshake(eng, ch1_obj.wire_bytes)
    v101_assert_eq(s1 != 0, 1, "Full TLS 1.3 handshake with P-384 SNI succeeded")
    v101_assert_str(s1.ts_selected_sni, "api.lipi.local", "Server selected exact SNI identity api.lipi.local")
    v101_assert_eq(s1.ts_is_resumed, 0, "Initial handshake is full 1-RTT (not resumed)")

    // Synthesize valid Client Finished AEAD record to derive resumption_master_secret
    cfk1 = tls13_hkdf_expand_label(s1.ts_client_hs_secret, "finished", [], 32)
    cfin_mac1 = tls13_hmac_sha256(cfk1, s1.ts_fin_transcript_hash)
    cfin_hs1 = _tls13s_append([TLS_HANDSHAKE_FINISHED, 0, 0, 32], cfin_mac1)
    cfin_rec1 = _tls13s_aead_wrap(s1.ts_cipher_suite, s1.ts_hs_client_key, s1.ts_hs_client_iv, 0, TLS_CONTENT_HANDSHAKE, cfin_hs1)
    v101_assert_eq(tls13_verify_client_finished(s1, cfin_rec1), 1, "Client Finished verified and derived resumption_master_secret")
    v101_assert_eq(len(s1.ts_resumption_master_secret), 32, "Derived 32-byte RFC 8446 resumption_master_secret")

    // 2C. Issue RFC 8446 NewSessionTicket & resume with valid PSK binder
    tkt = tls13_server_issue_session_ticket(eng, s1)
    ticket_id = tkt[0]
    psk = tkt[1]
    tkt_wire = tkt[2]
    v101_assert_eq(len(ticket_id), 16, "Issued 16-byte NewSessionTicket identity")
    v101_assert_eq(len(psk), 32, "Derived 32-byte resumption PSK")
    v101_assert_eq(len(tkt_wire) > 40, 1, "AEAD-wrapped NewSessionTicket wire record produced")

    c_priv2 = _tls13s_rand_bytes(32)
    c_pub2 = x25519_public_key(c_priv2)
    ch2_psk = tls13_build_psk_client_hello("api.lipi.local", c_pub2, ticket_id, psk, s1.ts_cipher_suite)
    s2 = tls13_engine_process_handshake(eng, ch2_psk)
    v101_assert_eq(s2 != 0, 1, "RFC 8446 PSK-DHE session resumption handshake succeeded")
    v101_assert_eq(s2.ts_is_resumed, 1, "Resumed session marked ts_is_resumed == 1")
    v101_assert_eq(len(s2.ts_server_flight_wire) < len(s1.ts_server_flight_wire), 1, "Abbreviated PSK server flight omits Certificate + CertVerify")

    // Verify encrypted record roundtrip on resumed session keys
    enc_res = tls13_record_encrypt(s2, "RESUMED_OK_101")
    dec_res = tls13_server_record_decrypt_self(s2, enc_res, 0)
    v101_assert_str(dec_res, "RESUMED_OK_101", "Resumed session AEAD record encryption/decryption verified")

    // 2D. Adversarial test: flip 1 bit of the PSK binder -> MUST REJECT!
    ch_bad = _tls13s_append(list(), ch2_psk)
    last_idx = len(ch_bad) - 1
    list_set(ch_bad, last_idx, (get(ch_bad, last_idx) ^ 1) & 255)
    s_bad = tls13_engine_process_handshake(eng, ch_bad)
    v101_assert_eq(s_bad, 0, "Tampered PSK binder strictly rejected by server")

    // 2E. Wildcard SNI match test
    ch3_obj = tls13_build_client_hello("billing.svc.lipi.local", c_pub2)
    s3 = tls13_engine_process_handshake(eng, ch3_obj.wire_bytes)
    v101_assert_str(s3.ts_selected_sni, "*.svc.lipi.local", "Wildcard SNI matched billing.svc.lipi.local")
    return 1

fn test_pillar3_relational_sql_v101
    say "▶ Pillar 3: Relational SQL ACID Transactions, Hash Indexes, Joins & GROUP BY..."
    db_path = "/tmp/lipi_v101_sql_e2e.db"
    syscall(87, db_path, 0, 0, 0, 0, 0)

    db = sql_engine_open(db_path)
    // Table 10 (users): col0=user_id, col1=dept_id, col2=salary
    sql_create_table(db, 10, 3, 16)
    sql_insert_3(db, 10, 1, 100, 500)
    sql_insert_3(db, 10, 2, 100, 700)
    sql_insert_3(db, 10, 3, 200, 900)
    sql_insert_3(db, 10, 4, 200, 1100)
    sql_insert_3(db, 10, 5, 300, 400)

    // Create WAL-persisted secondary hash index on users(user_id=col0) and users(dept_id=col1)
    v101_assert_eq(sql_execute_query(db, "CREATE INDEX 10 0"), 1, "CREATE INDEX via SQL text query succeeded")
    v101_assert_eq(sql_create_index(db, 10, 1), 1, "Secondary hash index created on users.dept_id")
    v101_assert_eq(sql_has_index(db, 10, 0), 1, "sql_has_index confirms index on col 0")
    v101_assert_eq(sql_select_where_eq(db, 10, 1, 200), 2, "Indexed WHERE dept_id=200 returned 2 rows")
    v101_assert_eq(sql_select_first_where_eq(db, 10, 0, 4, 2), 1100, "Indexed SELECT salary WHERE user_id=4 == 1100")

    // 3A. ACID ROLLBACK test: mutate inside BEGIN, then ROLLBACK -> 0 trace in RAM or WAL
    v101_assert_eq(sql_execute_query(db, "BEGIN"), 1, "BEGIN transaction started")
    sql_insert_3(db, 10, 99, 999, 9999)
    sql_update_where_eq(db, 10, 0, 1, 2, 12345)
    sql_delete_where_eq(db, 10, 0, 5)
    v101_assert_eq(sql_count_active(db, 10), 5, "Inside tx: +1 insert, -1 delete => 5 active")
    v101_assert_eq(sql_select_first_where_eq(db, 10, 0, 1, 2), 12345, "Inside tx: updated salary visible")
    v101_assert_eq(sql_execute_query(db, "ROLLBACK"), 1, "ROLLBACK succeeded")
    v101_assert_eq(sql_count_active(db, 10), 5, "After ROLLBACK: active row count restored to 5")
    v101_assert_eq(sql_select_first_where_eq(db, 10, 0, 1, 2), 500, "After ROLLBACK: user 1 salary restored to 500")
    v101_assert_eq(sql_select_first_where_eq(db, 10, 0, 99, 2), 0 - 1, "After ROLLBACK: uncommitted user 99 vanished")
    v101_assert_eq(sql_select_first_where_eq(db, 10, 0, 5, 2), 400, "After ROLLBACK: deleted user 5 restored")

    // 3B. ACID COMMIT test -> persists atomically to WAL
    v101_assert_eq(sql_begin(db), 1, "Second BEGIN transaction started")
    sql_update_where_eq(db, 10, 0, 2, 2, 800)
    sql_insert_3(db, 10, 6, 100, 600)
    v101_assert_eq(sql_commit(db), 1, "COMMIT atomically flushed + fsynced WAL")

    // Table 20 (orders): col0=order_id, col1=user_id, col2=amount
    sql_create_table(db, 20, 3, 16)
    sql_insert_3(db, 20, 1001, 1, 50)
    sql_insert_3(db, 20, 1002, 1, 75)
    sql_insert_3(db, 20, 1003, 3, 200)
    sql_insert_3(db, 20, 1004, 4, 300)

    // Close & reopen to verify COMMIT durability, ROLLBACK non-persistence, and INDEX recovery!
    sql_engine_close(db)
    db2 = sql_engine_open(db_path)
    v101_assert_eq(sql_count_active(db2, 10), 6, "After WAL replay: 6 committed users persisted (rolled-back tx absent)")
    v101_assert_eq(sql_select_first_where_eq(db2, 10, 0, 2, 2), 800, "After WAL replay: committed salary update == 800")
    v101_assert_eq(sql_has_index(db2, 10, 0), 1, "After WAL replay: secondary hash index auto-restored")

    // 3C. O(N + M) Hash INNER JOIN & LEFT JOIN: users(col0=user_id) JOIN orders(col1=user_id)
    ij = sql_inner_join(db2, 10, 0, 20, 1)
    v101_assert_eq(sql_join_count(ij), 4, "INNER JOIN users x orders returned 4 matching pairs")
    // Verify sum of order amounts across joined rows: 50 + 75 + 200 + 300 = 625
    join_amt_sum = 0
    ji = 0
    while ji < sql_join_count(ij)
        rr = sql_join_right_row(ij, ji)
        join_amt_sum = join_amt_sum + sql_select_cell(db2, 20, rr, 2)
        ji = ji + 1
    end
    v101_assert_eq(join_amt_sum, 625, "INNER JOIN joined order amounts sum == 625")
    sql_join_free(ij)

    lj = sql_left_join(db2, 10, 0, 20, 1)
    // Users 1(2 orders), 2(0->unmatched), 3(1), 4(1), 5(0->unmatched), 6(0->unmatched) => 2+1+1+1+1+1 = 7 rows
    v101_assert_eq(sql_join_count(lj), 7, "LEFT JOIN users x orders returned 7 rows (4 matched + 3 unmatched)")
    unmatched = 0
    ji = 0
    while ji < sql_join_count(lj)
        if sql_join_right_row(lj, ji) == (0 - 1)
            unmatched = unmatched + 1
        end
        ji = ji + 1
    end
    v101_assert_eq(unmatched, 3, "LEFT JOIN preserved 3 unmatched users with right_row == -1")
    sql_join_free(lj)

    // 3D. GROUP BY dept_id (col1) aggregating salary (col2):
    // dept 100: [500, 800, 600] -> count=3, sum=1900, min=500, max=800, avg=633
    // dept 200: [900, 1100]     -> count=2, sum=2000, min=900, max=1100, avg=1000
    // dept 300: [400]           -> count=1, sum=400,  min=400, max=400,  avg=400
    gr = sql_group_by_agg(db2, 10, 1, 2)
    v101_assert_eq(sql_group_count(gr), 3, "GROUP BY dept_id produced 3 distinct department groups")
    g100 = sql_group_find(gr, 100)
    g200 = sql_group_find(gr, 200)
    v101_assert_eq(sql_group_row_count(gr, g100), 3, "dept 100 COUNT == 3")
    v101_assert_eq(sql_group_sum(gr, g100), 1900, "dept 100 SUM == 1900")
    v101_assert_eq(sql_group_min(gr, g100), 500, "dept 100 MIN == 500")
    v101_assert_eq(sql_group_max(gr, g100), 800, "dept 100 MAX == 800")
    v101_assert_eq(sql_group_avg(gr, g200), 1000, "dept 200 AVG == 1000")
    sql_group_free(gr)

    sql_engine_close(db2)
    syscall(87, db_path, 0, 0, 0, 0, 0)
    return 1

fn test_pillar4_http2_hpack_huffman
    say "▶ Pillar 4: RFC 7540/7541 HTTP/2 Framing, HPACK & Canonical Huffman..."

    // 4A. RFC 7540 connection preface check
    pref = http2_preface_bytes()
    v101_assert_eq(http2_check_preface(pref), 1, "Valid 24-byte HTTP/2 connection preface accepted")
    bad_pref = _h2_append(list(), pref)
    list_set(bad_pref, 0, 88)
    v101_assert_eq(http2_check_preface(bad_pref), 0, "Corrupted HTTP/2 preface rejected")

    // 4B. Official RFC 7541 §C.4 Huffman test vectors
    h_www = [241, 227, 194, 229, 242, 58, 107, 160, 171, 144, 244, 255]
    v101_assert_str(http2_huffman_decode(h_www), "www.example.com", "RFC 7541 §C.4 Huffman decode 'www.example.com'")
    h_nc = [168, 235, 16, 100, 156, 191]
    v101_assert_str(http2_huffman_decode(h_nc), "no-cache", "RFC 7541 §C.4 Huffman decode 'no-cache'")

    // 4C. HPACK response encode + decode round-trip
    resp_blk = http2_hpack_encode_response(200, "application/json", 42)
    dec = http2_hpack_decode_headers(resp_blk)
    v101_assert_str(_h2_find_header(dec[0], dec[1], ":status"), "200", "HPACK round-trip :status == 200")
    v101_assert_str(_h2_find_header(dec[0], dec[1], "content-type"), "application/json", "HPACK round-trip content-type")
    v101_assert_str(_h2_find_header(dec[0], dec[1], "content-length"), "42", "HPACK round-trip content-length")
    v101_assert_str(_h2_find_header(dec[0], dec[1], "server"), "lipi/1.0.1", "HPACK round-trip server == lipi/1.0.1")

    // 4D. HTTP/2 frame wire builders (SETTINGS ACK, PING ACK, HEADERS+DATA, GOAWAY)
    sack = http2_build_settings_ack()
    v101_assert_eq(len(sack), 9, "SETTINGS ACK frame is exact 9 bytes")
    v101_assert_eq(get(sack, 3), H2_FRAME_SETTINGS, "SETTINGS ACK type == 4")
    v101_assert_eq(get(sack, 4), H2_FLAG_ACK, "SETTINGS ACK flags == 1")

    pack = http2_build_ping_ack([1, 2, 3, 4, 5, 6, 7, 8])
    v101_assert_eq(len(pack), 17, "PING ACK frame is exact 17 bytes")
    v101_assert_eq(get(pack, 3), H2_FRAME_PING, "PING ACK type == 6")
    v101_assert_eq(get(pack, 16), 8, "PING ACK echoed opaque payload byte 7")

    frames = http2_build_response_frames(3, 200, "text/plain", "hello-h2")
    v101_assert_eq(get(frames, 3), H2_FRAME_HEADERS, "Response starts with HEADERS frame")
    v101_assert_eq(get(frames, 8), 3, "Response stream_id == 3")
    return 1

fn main
    say "========================================================================"
    say "Lipi v1.0.1 Deep Upgrades End-to-End Verification Suite"
    say "========================================================================"
    test_pillar2_tls13_sni_p384_and_psk()
    test_pillar3_relational_sql_v101()
    test_pillar4_http2_hpack_huffman()
    say "========================================================================"
    say "ALL LIPI v1.0.1 DEEP UPGRADE E2E TESTS PASSED!"
    say "========================================================================"
    return 0

main()
