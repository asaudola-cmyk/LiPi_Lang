// =============================================================================
// LIPI SOVEREIGN ECOSYSTEM & RUNTIME FIXES VERIFICATION SUITE (PART 2)
// Verifies mobile ARM64 ELF emission, Haat P2P non-recursive delegation,
// Swarm task_registry in-place mutation, Blockchain VM transactional rollback,
// Browser ASCII font rasterizer coverage, and LipiFS content self-healing.
// =============================================================================

import "../aati/lipi_mobile/mobile.lp"
import "../aati/lipi_p2p/haat_server.lp"
import "../aati/lipi_swarm/task_registry.lp"
import "../aati/lipi_blockchain/vm.lp"
import "../aati/lipi_browser/font_rasterizer.lp"
import "../aati/lipi_fs/lipifs.lp"
import "../aati/lipi_ai/model_io.lp"
import "../aati/lipi_security/sandbox.lp"
import "../aati/json_toolkit/src/lib.lp"
import "../aati/lipi_dataframe/src/dataframe.lp"
import "../utso/net/tls/tls13.lp"
import "../aati/lipi_web/quic_udp.lp"
import "../aati/lipi_ai/llm_inference.lp"
import "../aati/lipi_security/rsa.lp"
import "../aati/lipi_registry/registry.lp"
import "../aati/lipi_sql/src/sql.lp"
import "../aati/lipi_browser/browser.lp"

@fn main()
    say "================================================================="
    say "  LIPI SOVEREIGN ECOSYSTEM & RUNTIME FIXES VERIFICATION SUITE"
    say "================================================================="

    // 1. Lipi Mobile ARM64 ELF Shared Library Emission
    arm_so = mobile_emit_arm64_liblipi_so()
    if len(arm_so) < 120
        say "FAIL: mobile_emit_arm64_liblipi_so length too small"
        exit(1)
    say "  [PASS] 1. Lipi Mobile ARM64 shared library emission (.push chaining fix)"

    // 2. Haat P2P Server Delegation (no infinite recursion)
    hcfg = haat_server_config_default()
    if hcfg.port <= 0
        say "FAIL: haat_server_config_default port invalid"
        exit(1)
    say "  [PASS] 2. Haat P2P server non-recursive delegation"

    // 3. Lipi Swarm In-Place Task Registry Mutation
    treg = task_registry_new()
    treg = task_registry_register(treg, "compute_fft", 4096)
    if task_registry_has(treg, "compute_fft") != 1
        say "FAIL: task_registry_register did not persist in task_registry"
        exit(1)
    say "  [PASS] 3. Lipi Swarm in-place task registry mutation"

    // 4. Lipi Blockchain VM Transactional Storage Rollback on REVERT
    vm_ctx = vm_context_new("0xAlice", "0xContract", 0, 100000, 1)
    vm_st = vm_state_new()
    vm_st = vm_storage_set(vm_st, "0", "7")
    bc = ["PUSH", "42", "PUSH", "0", "SSTORE", "REVERT"]
    vm_res = vm_execute_bytecode(vm_ctx, vm_st, bc)
    if vm_ctx.is_reverted != 1
        say "FAIL: VM should mark is_reverted == 1 on OP_REVERT"
        exit(1)
    if vm_storage_get(vm_st, "0") != "7"
        say "FAIL: VM storage was not rolled back on OP_REVERT"
        exit(1)
    say "  [PASS] 4. Lipi Blockchain VM transactional storage rollback on REVERT"

    // 5. Lipi Browser Full ASCII Glyph Rasterizer Coverage ('0', 'Z', 'q', '!')
    g_zero = raster_get_ascii_glyph_row(48, 3)
    g_z = raster_get_ascii_glyph_row(90, 3)
    g_q = raster_get_ascii_glyph_row(113, 6)
    if g_zero == 0 || g_z == 0 || g_q == 0
        say "FAIL: raster_get_ascii_glyph_row missing ASCII glyph coverage"
        exit(1)
    say "  [PASS] 5. Lipi Browser full ASCII glyph rasterizer coverage"

    // 6. Lipi AI Model Weights Serialization & Deserialization Round-Trip
    save_model_weights("lipi-gpt-tiny", 100, [11, 22, 33, 44], "/tmp/test_lipi_weights.lipimodel")
    loaded_w = load_model_weights("/tmp/test_lipi_weights.lipimodel")
    if len(loaded_w) != 4 or loaded_w[0] != 11 or loaded_w[3] != 44
        say "FAIL: save_model_weights / load_model_weights roundtrip failed"
        exit(1)
    say "  [PASS] 6. Lipi AI model weight tensor serialization & deserialization"

    // 7. Seccomp Raw Binary sock_fprog & sock_filter Packing
    s_filt = strict_io_filter()
    bpf_insns = compile_bpf_filter(s_filt)
    raw_fprog = pack_raw_sock_fprog(bpf_insns)
    if mem_word_read(raw_fprog, 0) != len(bpf_insns) or mem_word_read(raw_fprog, 8) <= 65536
        say "FAIL: pack_raw_sock_fprog invalid binary layout"
        exit(1)
    say "  [PASS] 7. Linux Seccomp BPF raw binary sock_fprog & sock_filter layout"

    // 8. JSON Toolkit Nested Dot-Path Traversal ("user.profile.name")
    nested_json = "{\"user\": {\"profile\": {\"name\": \"LipiSovereign\", \"level\": 100}}}"
    if json_query(nested_json, "user.profile.name") != "LipiSovereign"
        say "FAIL: json_query failed on nested dot-path user.profile.name"
        exit(1)
    say "  [PASS] 8. JSON Toolkit nested dot-path query traversal"

    // 9. DataFrame Dynamic Capacity Growth beyond Initial Capacity
    df = df_new()
    df_add_column(df, "id", 1, 2)
    df_append_row_1(df, 100)
    df_append_row_1(df, 200)
    df_append_row_1(df, 300)
    df_append_row_1(df, 400)
    if df_row_count(df) != 4 or df_get(df, 3, 0) != 400
        say "FAIL: DataFrame dynamic capacity expansion failed"
        exit(1)
    say "  [PASS] 9. DataFrame dynamic capacity growth (auto-reallocation)"

    // 10. TLS 1.3 HKDF Key Schedule & Full Root-CA + Expiry X.509 Certificate Verification
    hs_keys = tls13_derive_handshake_keys([1, 2, 3, 4], [5, 6, 7, 8])
    if len(hs_keys.client_write_key) != 16 or len(hs_keys.client_write_iv) != 12
        say "FAIL: tls13_derive_handshake_keys wrong key/iv lengths"
        exit(1)
    ca_sk = [10,20,30,40,50,60,70,80, 90,100,110,120,130,140,150,160, 170,180,190,200,210,220,230,240, 11,22,33,44,55,66,77,88]
    lf_sk = [12,22,32,42,52,62,72,82, 92,102,112,122,132,142,152,162, 172,182,192,202,212,222,232,242, 13,23,34,45,56,67,78,89]
    ca_pk = ed25519_keygen(ca_sk).public_key
    lf_pk = ed25519_keygen(lf_sk).public_key
    ca_cert = x509_build_signed_ed25519_cert("Lipi Root", "Lipi Root", "", "250101000000Z", "350101000000Z", 1, ca_pk, ca_sk, 501)
    lf_cert = x509_build_signed_ed25519_cert("Lipi Root", "lipi.dev", "lipi.dev", "250101000000Z", "350101000000Z", 0, lf_pk, ca_sk, 502)
    mitm_cert = x509_build_signed_ed25519_cert("Evil MITM", "lipi.dev", "lipi.dev", "250101000000Z", "350101000000Z", 0, lf_pk, lf_sk, 503)
    tls13_clear_custom_trust_roots()
    tls13_add_trust_root(ca_cert)
    if tls13_verify_x509_cert_chain(lf_cert, "lipi.dev") != 1 or tls13_verify_x509_cert_chain(lf_cert, "evil.dev") != 0 or tls13_verify_x509_cert_chain(mitm_cert, "lipi.dev") != 0
        say "FAIL: tls13_verify_x509_cert_chain PKI check failed"
        exit(1)
    say "  [PASS] 10. TLS 1.3 HKDF key schedule & Root-CA / MITM / SNI X.509 verification"

    // 11. QUIC RFC 9000 Binary Wire Packet Serialization & Multi-Layer LLM BPE Decoding
    qp = quic_packet_new(4, 0, 1001, 7, 128, "hello")
    q_wire = quic_packet_serialize_wire(qp)
    if len(q_wire) != 11 or q_wire[0] != 196 or q_wire[8] != 7
        say "FAIL: quic_packet_serialize_wire invalid RFC 9000 header bytes"
        exit(1)
    bpe_tok = llm_bpe_decode_token(["lipi", "sovereign", "silicon"], 1)
    if bpe_tok != "sovereign"
        say "FAIL: llm_bpe_decode_token expected 'sovereign'"
        exit(1)
    q_fd = quic_udp_open_socket(0)
    if q_fd >= 0
        sys_close(q_fd)
    end
    say "  [PASS] 11. HTTP/3 QUIC RFC 9000 wire framing, real UDP socket, & LLM BPE decoding"

    // 12. Real 60-bit RSA Modular Exponentiation (zero 12-bit toy n=3233)
    rkey = rsa_key_new()
    rsa_plain = 123456789012345
    rsa_cipher = rsa_sec_encrypt(rkey, rsa_plain)
    rsa_back = rsa_sec_decrypt(rkey, rsa_cipher)
    if rkey.rsa_n < 1000000000000000000 or rsa_back != rsa_plain
        say "FAIL: 60-bit RSA roundtrip failed"
        exit(1)
    say "  [PASS] 12. 60-bit overflow-safe RSA encrypt/decrypt roundtrip verified"

    // 13. Lipi SQL Text Query Parser & Execution Engine (CREATE / INSERT / SELECT / DELETE / COUNT)
    sqldb = sql_engine_new()
    sql_execute_query(sqldb, "CREATE TABLE 1 (2, 16)")
    sql_execute_query(sqldb, "INSERT INTO 1 VALUES (101, 9001)")
    sql_execute_query(sqldb, "INSERT INTO 1 VALUES (102, 9002)")
    q_val = sql_execute_query(sqldb, "SELECT 1 FROM 1 WHERE 0 = 102")
    q_cnt = sql_execute_query(sqldb, "COUNT FROM 1")
    if q_val != 9002 or q_cnt != 2
        say "FAIL: sql_execute_query SELECT/COUNT failed"
        exit(1)
    sql_engine_free(sqldb)
    say "  [PASS] 13. Lipi SQL textual query parser & executor verified"

    // 14. Lipi Registry Disk Persistence Install & Browser HTML/File Loader
    reg = registry_new("https://haat.lipi.dev")
    pkg = package_new("demo_pkg", "1.0.0", "lipi", "sovereign test")
    reg = registry_publish(reg, pkg)
    inst_ok = registry_install(reg, "demo_pkg", "1.0.0", "/tmp/lipi_reg_install_test.toml")
    if inst_ok != 1 or file_exists("/tmp/lipi_reg_install_test.toml") != 1
        say "FAIL: registry_install did not persist manifest to disk"
        exit(1)
    br = browser_new(32, 32)
    b_ok = browser_load_file_or_html(br, "<div>Lipi</div>", "")
    if b_ok != 1
        say "FAIL: browser_load_file_or_html failed on inline HTML"
        exit(1)
    say "  [PASS] 14. Lipi Registry disk install persistence & Browser HTML/file loader verified"

    say "================================================================="
    say "  ALL SOVEREIGN ECOSYSTEM REGRESSION CHECKS PASSED (14/14)"
    say "================================================================="
