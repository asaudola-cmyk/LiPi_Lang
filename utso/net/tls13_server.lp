// ==============================================================================
// 👑 LIPI SOVEREIGN PROTOCOL: EMBEDDED IN-PROCESS TLS 1.3 SERVER ENGINE
// Module: utso/net/tls13_server.lp
// Milestone: Sovereign Full-Stack Frontier 2 (0% NGINX, 0% OpenSSL, 0% C)
// 100% Pure LiPi Implementation — Genuine RFC 8446 X25519 + HKDF + AES-GCM/ChaCha20
// ==============================================================================
//
// WHY THIS MODULE:
// Replaces external TLS reverse proxies (NGINX, Caddy, OpenSSL) with a genuine
// in-process RFC 8446 TLS 1.3 server handshake and AEAD record layer built purely
// over Lipi's X25519, HKDF-SHA256/384, Ed25519, X.509, AES-GCM, and ChaCha20-Poly1305.

import "utso/net/tls/tls13"

// ── 1. TLS 1.3 Protocol Constants (RFC 8446) ──────────────────────────────────
TLS_CONTENT_CHANGE_CIPHER_SPEC = 20
TLS_CONTENT_ALERT              = 21
TLS_CONTENT_HANDSHAKE          = 22
TLS_CONTENT_APPLICATION_DATA   = 23

TLS_HANDSHAKE_CLIENT_HELLO     = 1
TLS_HANDSHAKE_SERVER_HELLO     = 2
TLS_HANDSHAKE_NEW_SESSION_TICKET = 4
TLS_HANDSHAKE_ENCRYPTED_EXT    = 8
TLS_HANDSHAKE_CERTIFICATE      = 11
TLS_HANDSHAKE_CERT_VERIFY      = 15
TLS_HANDSHAKE_FINISHED         = 20
TLS_HANDSHAKE_MESSAGE_HASH     = 254  // 0xFE synthetic HRR transcript hash

TLS_VERSION_TLS13              = 772 // 0x0304 (TLS 1.3)
TLS_VERSION_LEGACY_12          = 771 // 0x0303 (TLS 1.2 Legacy wire version)

TLS_CIPHER_AES_128_GCM_SHA256  = 4865 // 0x1301
TLS_CIPHER_AES_256_GCM_SHA384  = 4866 // 0x1302
TLS_CIPHER_CHACHA20_POLY1305   = 4867 // 0x1303

TLS_GROUP_X25519               = 29   // 0x001d (Curve25519 Key Share)
TLS_GROUP_SECP256R1            = 23   // 0x0017 (NIST P-256)

TLS_SIG_ECDSA_SECP256R1_SHA256 = 1027 // 0x0403 (Universal Chrome/Firefox/Safari/curl)
TLS_SIG_ECDSA_SECP384R1_SHA384 = 1283 // 0x0503 (NIST P-384 + SHA-384)
TLS_SIG_ED25519                = 2055 // 0x0807

TLS_EXT_SERVER_NAME            = 0    // SNI (0x0000)
TLS_EXT_SUPPORTED_GROUPS       = 10   // 0x000a
TLS_EXT_SIGNATURE_ALGORITHMS   = 13   // 0x000d
TLS_EXT_ALPN                   = 16   // 0x0010
TLS_EXT_PRE_SHARED_KEY         = 41   // 0x0029
TLS_EXT_SUPPORTED_VERSIONS     = 43   // 0x002b
TLS_EXT_PSK_KEY_EXCHANGE_MODES = 45   // 0x002d
TLS_EXT_KEY_SHARE              = 51   // 0x0033

TLS_STATE_START                = 0
TLS_STATE_CLIENT_HELLO_RECV    = 1
TLS_STATE_SERVER_HELLO_SENT    = 2
TLS_STATE_ESTABLISHED          = 3
TLS_STATE_CLOSED               = 4

// ── 2. Sovereign TLS 1.3 Server Models ────────────────────────────────────────

struct Tls13ClientHello
    ch_tag
    ch_version
    ch_session_id_len
    ch_cipher_suite
    ch_has_tls13
    ch_sni_hostname
    ch_key_share_group
    ch_session_id_bytes
    ch_client_pub_bytes
    ch_raw_hs_bytes
    ch_supports_x25519_group
    ch_has_alpn_http11
    ch_has_alpn_h2
    ch_has_psk
    ch_has_psk_dhe
    ch_psk_identity
    ch_psk_binder
    ch_psk_trunc_len

struct Tls13ServerHello
    sh_tag
    sh_version
    sh_cipher_suite
    sh_key_group
    sh_public_key_len
    sh_status
    sh_wire_bytes
    sh_raw_hs_bytes

struct Tls13Session
    ts_tag
    ts_state
    ts_cipher_suite
    ts_shared_secret
    ts_client_seq
    ts_server_seq
    ts_is_handshake_done
    ts_shared_secret_bytes
    ts_hs_client_key
    ts_hs_client_iv
    ts_hs_server_key
    ts_hs_server_iv
    ts_client_hs_secret
    ts_app_client_key
    ts_app_client_iv
    ts_app_server_key
    ts_app_server_iv
    ts_server_flight_wire
    ts_fin_transcript_hash
    ts_selected_sni
    ts_alpn
    ts_master_secret
    ts_resumption_master_secret
    ts_is_resumed
    ts_handshake_transcript
    ts_app_client_secret
    ts_app_server_secret

struct Tls13RecordEngine
    re_tag
    re_active_sessions
    re_total_handshakes
    re_total_records_rx
    re_total_records_tx
    re_is_listening
    re_cert_chain
    re_priv_key32
    re_pub_key32
    re_root_ca_der
    re_last_server_hello
    re_sig_alg
    re_sni_hosts
    re_sni_chains
    re_sni_privs
    re_sni_sig_algs
    re_enable_h2
    re_ticket_ids
    re_ticket_psks
    re_ticket_ciphers
    re_ticket_snis
    re_ticket_exp

// ── 3. Internal Byte & CSPRNG Utilities ───────────────────────────────────────

fn _tls13s_rand_bytes count
    // WHY: Loops SYS_getrandom (318) on EINTR (-4) and short reads, falling back ONLY
    // to kernel /dev/urandom with EINTR retry — NEVER predictable cpu_clock()!
    if count <= 0
        return list()
    end
    buf = malloc(count)
    if buf <= 0
        return list()
    end
    got = 0
    failed = 0
    while got < count
        r = syscall(318, buf + got, count - got, 0, 0, 0, 0)
        if r == (0 - 4)
            continue
        end
        if r <= 0
            ufd = syscall(2, "/dev/urandom", 0, 0, 0, 0, 0)
            if ufd < 0
                failed = 1
                break
            end
            while got < count
                ur = syscall(0, ufd, buf + got, count - got, 0, 0, 0)
                if ur == (0 - 4)
                    continue
                end
                if ur <= 0
                    failed = 1
                    break
                end
                got = got + ur
            end
            syscall(3, ufd, 0, 0, 0, 0, 0)
            break
        end
        got = got + r
    end
    out = list()
    if failed == 0 and got == count
        i = 0
        while i < count
            push(out, mem_byte_read(buf, i) & 255)
            i = i + 1
        end
    end
    free(buf, count)
    return out
end

fn _tls13s_append dst src
    i = 0
    while i < len(src)
        push(dst, get(src, i) & 255)
        i = i + 1
    end
    return dst

fn _tls13s_slice src start_pos end_pos
    out = list()
    i = start_pos
    while i < end_pos and i < len(src)
        push(out, get(src, i) & 255)
        i = i + 1
    end
    return out

fn _tls13s_is_all_zero32 raw_bytes
    // WHY: RFC 7748 §6.1 requires rejecting X25519 low-order points yielding an all-zero shared secret.
    if len(raw_bytes) != 32
        return 1
    end
    acc = 0
    i = 0
    while i < 32
        acc = acc | (get(raw_bytes, i) & 255)
        i = i + 1
    end
    if acc == 0
        return 1
    end
    return 0
end

fn _tls13s_make_nonce iv seq
    nonce = list()
    i = 0
    while i < 12
        push(nonce, get(iv, i) & 255)
        i = i + 1
    end
    i = 0
    while i < 8
        sb = (seq >> ((7 - i) * 8)) & 255
        list_set(nonce, 4 + i, (get(nonce, 4 + i) ^ sb) & 255)
        i = i + 1
    end
    return nonce

fn _tls13s_aead_wrap cipher key iv seq inner_type pt_bytes
    inner = _tls13s_append(list(), pt_bytes)
    push(inner, inner_type & 255)
    enc_len = len(inner) + 16
    hdr = [TLS_CONTENT_APPLICATION_DATA, 3, 3, (enc_len / 256) & 255, enc_len & 255]
    nonce = _tls13s_make_nonce(iv, seq)
    ct = list()
    if cipher == TLS_CIPHER_CHACHA20_POLY1305
        ct = tls_chacha20_poly1305_encrypt_raw(key, nonce, inner, hdr)
    else
        ct = tls_aes_gcm_encrypt_raw(key, nonce, inner, hdr)
    end
    wire = _tls13s_append(list(), hdr)
    return _tls13s_append(wire, ct)

fn _tls13s_aead_unwrap cipher key iv seq rec_bytes
    rlen = len(rec_bytes)
    if rlen < 22
        return [0, 0, list()]
    end
    if get(rec_bytes, 0) != TLS_CONTENT_APPLICATION_DATA
        return [0, 0, list()]
    end
    l0 = get(rec_bytes, 3) & 255
    l1 = get(rec_bytes, 4) & 255
    plen = (l0 * 256) | l1
    if plen < 17 or (5 + plen) > rlen
        return [0, 0, list()]
    end
    hdr = _tls13s_slice(rec_bytes, 0, 5)
    body = _tls13s_slice(rec_bytes, 5, 5 + plen)
    nonce = _tls13s_make_nonce(iv, seq)
    pt = list()
    if cipher == TLS_CIPHER_CHACHA20_POLY1305
        pt = tls_chacha20_poly1305_decrypt_raw(key, nonce, body, hdr)
    else
        pt = tls_aes_gcm_decrypt_raw(key, nonce, body, hdr)
    end
    if len(pt) == 0
        return [0, 0, list()]
    end
    end_idx = len(pt) - 1
    while end_idx >= 0 and get(pt, end_idx) == 0
        end_idx = end_idx - 1
    end
    if end_idx < 0
        return [0, 0, list()]
    end
    itype = get(pt, end_idx) & 255
    return [1, itype, _tls13s_slice(pt, 0, end_idx)]

// ── 4. Constructors & Sovereign Identity Initialization ─────────────────────

fn tls13_client_hello_new version sid_len cipher tls13_flag sni group
    ch = Tls13ClientHello()
    ch.ch_tag = 1
    ch.ch_version = version
    ch.ch_session_id_len = sid_len
    ch.ch_cipher_suite = cipher
    ch.ch_has_tls13 = tls13_flag
    ch.ch_sni_hostname = sni
    ch.ch_key_share_group = group
    ch.ch_session_id_bytes = list()
    ch.ch_client_pub_bytes = list()
    ch.ch_raw_hs_bytes = list()
    ch.ch_supports_x25519_group = 0
    ch.ch_has_alpn_http11 = 0
    ch.ch_has_alpn_h2 = 0
    ch.ch_has_psk = 0
    ch.ch_has_psk_dhe = 0
    ch.ch_psk_identity = list()
    ch.ch_psk_binder = list()
    ch.ch_psk_trunc_len = 0
    return ch

fn tls13_server_hello_new version cipher group key_len
    sh = Tls13ServerHello()
    sh.sh_tag = 1
    sh.sh_version = version
    sh.sh_cipher_suite = cipher
    sh.sh_key_group = group
    sh.sh_public_key_len = key_len
    sh.sh_status = 1
    sh.sh_wire_bytes = list()
    sh.sh_raw_hs_bytes = list()
    return sh

fn tls13_session_new cipher_suite secret
    s = Tls13Session()
    s.ts_tag = 1
    s.ts_state = TLS_STATE_ESTABLISHED
    s.ts_cipher_suite = cipher_suite
    s.ts_shared_secret = secret
    s.ts_client_seq = 0
    s.ts_server_seq = 0
    s.ts_is_handshake_done = 1
    s.ts_shared_secret_bytes = list()
    s.ts_hs_client_key = list()
    s.ts_hs_client_iv = list()
    s.ts_hs_server_key = list()
    s.ts_hs_server_iv = list()
    s.ts_client_hs_secret = list()
    s.ts_app_client_key = list()
    s.ts_app_client_iv = list()
    s.ts_app_server_key = list()
    s.ts_app_server_iv = list()
    s.ts_server_flight_wire = list()
    s.ts_fin_transcript_hash = list()
    s.ts_selected_sni = "localhost"
    s.ts_alpn = "http/1.1"
    s.ts_master_secret = list()
    s.ts_resumption_master_secret = list()
    s.ts_is_resumed = 0
    s.ts_handshake_transcript = list()
    s.ts_app_client_secret = list()
    s.ts_app_server_secret = list()
    return s

fn tls13_engine_set_identity engine cert_chain_ders ed25519_priv32
    kp = ed25519_keygen(ed25519_priv32)
    engine.re_cert_chain = cert_chain_ders
    engine.re_priv_key32 = kp.secret_key
    engine.re_pub_key32 = kp.public_key
    engine.re_sig_alg = TLS_SIG_ED25519
    return 1

fn tls13_engine_set_p256_identity engine cert_chain_ders p256_priv32
    engine.re_cert_chain = cert_chain_ders
    engine.re_priv_key32 = p256_priv32
    engine.re_pub_key32 = ecdsa_p256_keygen_from_scalar(p256_priv32)
    engine.re_sig_alg = TLS_SIG_ECDSA_SECP256R1_SHA256
    return 1

fn tls13_engine_set_p384_identity engine cert_chain_ders p384_priv48
    // WHY: Configures NIST P-384 (secp384r1) + SHA-384 (0x0503) signing identity.
    engine.re_cert_chain = cert_chain_ders
    engine.re_priv_key32 = p384_priv48
    engine.re_pub_key32 = ecdsa_p384_keygen_from_scalar(p384_priv48)
    engine.re_sig_alg = TLS_SIG_ECDSA_SECP384R1_SHA384
    return 1

fn tls13_engine_add_sni_identity engine hostname cert_chain_ders priv_key sig_alg
    // WHY: Registers a per-SNI virtual-host certificate chain + signing key on the engine.
    // Supports exact matches (e.g. "api.lipi.local") and RFC 6125 wildcards ("*.lipi.local").
    push(engine.re_sni_hosts, hostname)
    push(engine.re_sni_chains, cert_chain_ders)
    push(engine.re_sni_privs, priv_key)
    push(engine.re_sni_sig_algs, sig_alg)
    return len(engine.re_sni_hosts)

fn tls13_engine_enable_h2 engine enabled
    engine.re_enable_h2 = enabled
    return enabled

fn _tls13s_sni_matches pattern host
    if pattern == host
        return 1
    end
    plen = str_len(pattern)
    hlen = str_len(host)
    // RFC 6125 single-label wildcard: "*.example.com" (requires at least 2 dots in pattern)
    if plen >= 5 and str_char_at(pattern, 0) == 42 and str_char_at(pattern, 1) == 46
        suffix = str_sub(pattern, 1, plen)
        slen = str_len(suffix)
        // Reject TLD wildcards like "*.com" (suffix must contain another '.')
        dot_cnt = 0
        di = 0
        while di < slen
            if str_char_at(suffix, di) == 46
                dot_cnt = dot_cnt + 1
            end
            di = di + 1
        end
        if dot_cnt < 2
            return 0
        end
        if hlen <= slen
            return 0
        end
        prefix_len = hlen - slen
        // Single-label only: host prefix before suffix must not contain '.'
        pi = 0
        while pi < prefix_len
            if str_char_at(host, pi) == 46
                return 0
            end
            pi = pi + 1
        end
        if str_sub(host, prefix_len, hlen) == suffix
            return 1
        end
    end
    return 0

fn _tls13s_select_identity engine sni_host
    // First pass: exact hostname match
    cnt = len(engine.re_sni_hosts)
    i = 0
    while i < cnt
        pat = get(engine.re_sni_hosts, i)
        if pat == sni_host
            return [get(engine.re_sni_chains, i), get(engine.re_sni_privs, i), get(engine.re_sni_sig_algs, i), pat]
        end
        i = i + 1
    end
    // Second pass: wildcard match
    i = 0
    while i < cnt
        pat = get(engine.re_sni_hosts, i)
        if _tls13s_sni_matches(pat, sni_host) == 1
            return [get(engine.re_sni_chains, i), get(engine.re_sni_privs, i), get(engine.re_sni_sig_algs, i), pat]
        end
        i = i + 1
    end
    return [engine.re_cert_chain, engine.re_priv_key32, engine.re_sig_alg, "default"]

fn tls13_record_engine_new
    re = Tls13RecordEngine()
    re.re_tag = 1
    re.re_active_sessions = list()
    re.re_total_handshakes = 0
    re.re_total_records_rx = 0
    re.re_total_records_tx = 0
    re.re_is_listening = 1

    // Generate authentic sovereign NIST P-256 (0x0403) CA + localhost leaf certificate via SYS_getrandom
    // Compatible with Chrome (BoringSSL), Firefox (NSS), Safari, curl, and Pure-Lipi http.lp.
    ca_sk = _tls13s_rand_bytes(32)
    leaf_sk = _tls13s_rand_bytes(32)
    ca_nonce = _tls13s_rand_bytes(32)
    leaf_nonce = _tls13s_rand_bytes(32)
    ca_pk = ecdsa_p256_keygen_from_scalar(ca_sk)
    leaf_pk = ecdsa_p256_keygen_from_scalar(leaf_sk)
    ca_der = x509_build_signed_p256_cert("Lipi Sovereign Server CA", "Lipi Sovereign Server CA", "", "250101000000Z", "350101000000Z", 1, ca_pk, ca_sk, ca_nonce, 7001)
    leaf_der = x509_build_signed_p256_cert("Lipi Sovereign Server CA", "localhost", "localhost", "250101000000Z", "350101000000Z", 0, leaf_pk, ca_sk, leaf_nonce, 7002)

    re.re_root_ca_der = ca_der
    re.re_cert_chain = [leaf_der, ca_der]
    re.re_priv_key32 = leaf_sk
    re.re_pub_key32 = leaf_pk
    re.re_last_server_hello = list()
    re.re_sig_alg = TLS_SIG_ECDSA_SECP256R1_SHA256
    re.re_sni_hosts = list()
    re.re_sni_chains = list()
    re.re_sni_privs = list()
    re.re_sni_sig_algs = list()
    re.re_enable_h2 = 0
    re.re_ticket_ids = list()
    re.re_ticket_psks = list()
    re.re_ticket_ciphers = list()
    re.re_ticket_snis = list()
    re.re_ticket_exp = list()
    return re

// ── 5. Full ClientHello Parser (RFC 8446 Section 4.1.2) ──────────────────────

fn tls13_parse_client_hello bytes
    // WHY: Parses RFC 8446 ClientHello wire record preserving exact session_id, SNI, cipher,
    // X25519 key_share public key, and raw handshake bytes for transcript hashing.
    b_len = len(bytes)
    if b_len < 48
        return 0
    end

    ct = get(bytes, 0) & 255
    if ct != TLS_CONTENT_HANDSHAKE
        return 0
    end
    rec_version = ((get(bytes, 1) & 255) << 8) | (get(bytes, 2) & 255)
    if rec_version != TLS_VERSION_LEGACY_12 and rec_version != 769
        return 0
    end
    rec_len = ((get(bytes, 3) & 255) << 8) | (get(bytes, 4) & 255)
    if (5 + rec_len) > b_len or rec_len < 40
        return 0
    end

    ht = get(bytes, 5) & 255
    if ht != TLS_HANDSHAKE_CLIENT_HELLO
        return 0
    end
    hs_len = ((get(bytes, 6) & 255) << 16) | ((get(bytes, 7) & 255) << 8) | (get(bytes, 8) & 255)
    if (9 + hs_len) > b_len
        return 0
    end
    raw_hs = _tls13s_slice(bytes, 5, 9 + hs_len)

    client_version = ((get(bytes, 9) & 255) << 8) | (get(bytes, 10) & 255)
    sid_len = get(bytes, 43) & 255
    if sid_len > 32 or (44 + sid_len + 2) > b_len
        return 0
    end
    sid_bytes = _tls13s_slice(bytes, 44, 44 + sid_len)
    offset = 44 + sid_len

    cs_len = ((get(bytes, offset) & 255) << 8) | (get(bytes, offset + 1) & 255)
    offset = offset + 2
    if offset + cs_len >= b_len
        return 0
    end

    // Negotiate TLS 1.3 AEAD cipher suite (prefer AES-128-GCM, ChaCha20-Poly1305, AES-256-GCM)
    has_aes128 = 0
    has_chacha = 0
    has_aes256 = 0
    cs_end = offset + cs_len
    while offset + 2 <= cs_end
        suite = ((get(bytes, offset) & 255) << 8) | (get(bytes, offset + 1) & 255)
        if suite == TLS_CIPHER_AES_128_GCM_SHA256
            has_aes128 = 1
        elif suite == TLS_CIPHER_CHACHA20_POLY1305
            has_chacha = 1
        elif suite == TLS_CIPHER_AES_256_GCM_SHA384
            has_aes256 = 1
        end
        offset = offset + 2
    end
    selected_cipher = 0
    if has_aes128 == 1
        selected_cipher = TLS_CIPHER_AES_128_GCM_SHA256
    elif has_chacha == 1
        selected_cipher = TLS_CIPHER_CHACHA20_POLY1305
    elif has_aes256 == 1
        selected_cipher = TLS_CIPHER_AES_256_GCM_SHA384
    end

    offset = cs_end
    if offset >= b_len return 0 end
    comp_len = get(bytes, offset) & 255
    offset = offset + 1 + comp_len
    if offset + 2 > b_len return 0 end

    ext_len = ((get(bytes, offset) & 255) << 8) | (get(bytes, offset + 1) & 255)
    offset = offset + 2
    ext_end = offset + ext_len
    if ext_end > b_len
        ext_end = b_len
    end

    has_tls13 = 0
    key_group = 0
    client_pub = list()
    sni_name = "localhost"
    supports_x25519 = 0
    has_alpn_h1 = 0
    has_alpn_h2 = 0
    has_psk = 0
    has_psk_dhe = 0
    psk_id = list()
    psk_binder = list()
    psk_trunc_len = 0

    while offset + 4 <= ext_end
        ext_type = ((get(bytes, offset) & 255) << 8) | (get(bytes, offset + 1) & 255)
        data_len = ((get(bytes, offset + 2) & 255) << 8) | (get(bytes, offset + 3) & 255)
        offset = offset + 4
        if offset + data_len > ext_end
            break
        end

        if ext_type == TLS_EXT_SUPPORTED_VERSIONS
            k = 1
            while k + 1 < data_len
                ver = ((get(bytes, offset + k) & 255) << 8) | (get(bytes, offset + k + 1) & 255)
                if ver == TLS_VERSION_TLS13
                    has_tls13 = 1
                end
                k = k + 2
            end
        elif ext_type == TLS_EXT_SUPPORTED_GROUPS and data_len >= 4
            glist_len = ((get(bytes, offset) & 255) << 8) | (get(bytes, offset + 1) & 255)
            gpos = offset + 2
            glim = offset + data_len
            if offset + 2 + glist_len < glim
                glim = offset + 2 + glist_len
            end
            while gpos + 2 <= glim
                sg = ((get(bytes, gpos) & 255) << 8) | (get(bytes, gpos + 1) & 255)
                if sg == TLS_GROUP_X25519
                    supports_x25519 = 1
                end
                gpos = gpos + 2
            end
        elif ext_type == TLS_EXT_ALPN and data_len >= 4
            alist_len = ((get(bytes, offset) & 255) << 8) | (get(bytes, offset + 1) & 255)
            apos = offset + 2
            alim = offset + data_len
            if offset + 2 + alist_len < alim
                alim = offset + 2 + alist_len
            end
            while apos < alim
                plen = get(bytes, apos) & 255
                apos = apos + 1
                if plen == 0 or apos + plen > alim
                    break
                end
                if plen == 2
                    if get(bytes, apos) == 104 and get(bytes, apos + 1) == 50
                        has_alpn_h2 = 1
                    end
                elif plen == 8
                    if get(bytes, apos) == 104 and get(bytes, apos + 1) == 116 and get(bytes, apos + 2) == 116 and get(bytes, apos + 3) == 112 and get(bytes, apos + 4) == 47 and get(bytes, apos + 5) == 49 and get(bytes, apos + 6) == 46 and get(bytes, apos + 7) == 49
                        has_alpn_h1 = 1
                    end
                end
                apos = apos + plen
            end
        elif ext_type == TLS_EXT_PSK_KEY_EXCHANGE_MODES and data_len >= 2
            mlen = get(bytes, offset) & 255
            mi = 0
            while mi < mlen and (offset + 1 + mi) < (offset + data_len)
                if (get(bytes, offset + 1 + mi) & 255) == 1
                    has_psk_dhe = 1
                end
                mi = mi + 1
            end
        elif ext_type == TLS_EXT_PRE_SHARED_KEY and data_len >= 10
            ids_len = ((get(bytes, offset) & 255) << 8) | (get(bytes, offset + 1) & 255)
            binders_off = offset + 2 + ids_len
            if ids_len >= 6 and binders_off + 3 <= offset + data_len
                id0_len = ((get(bytes, offset + 2) & 255) << 8) | (get(bytes, offset + 3) & 255)
                if id0_len > 0 and (offset + 4 + id0_len + 4) <= binders_off
                    binders_len = ((get(bytes, binders_off) & 255) << 8) | (get(bytes, binders_off + 1) & 255)
                    b0_len = get(bytes, binders_off + 2) & 255
                    if b0_len >= 32 and (binders_off + 3 + b0_len) <= (offset + data_len) and binders_len >= (1 + b0_len)
                        psk_id = _tls13s_slice(bytes, offset + 4, offset + 4 + id0_len)
                        psk_binder = _tls13s_slice(bytes, binders_off + 3, binders_off + 3 + b0_len)
                        psk_trunc_len = binders_off - 5
                        has_psk = 1
                    end
                end
            end
        elif ext_type == TLS_EXT_SERVER_NAME and data_len >= 5
            spos = offset + 2
            if spos + 3 <= offset + data_len and (get(bytes, spos) & 255) == 0
                nlen = ((get(bytes, spos + 1) & 255) << 8) | (get(bytes, spos + 2) & 255)
                if nlen > 0 and spos + 3 + nlen <= offset + data_len
                    parsed_sni = ""
                    si = 0
                    while si < nlen
                        parsed_sni = parsed_sni + chr(get(bytes, spos + 3 + si) & 255)
                        si = si + 1
                    end
                    sni_name = parsed_sni
                end
            end
        elif ext_type == TLS_EXT_KEY_SHARE and data_len >= 2
            shares_len = ((get(bytes, offset) & 255) << 8) | (get(bytes, offset + 1) & 255)
            ks_pos = offset + 2
            ks_lim = offset + data_len
            if shares_len + 2 != data_len
                ks_pos = offset
            end
            while ks_pos + 4 <= ks_lim
                grp = ((get(bytes, ks_pos) & 255) << 8) | (get(bytes, ks_pos + 1) & 255)
                klen = ((get(bytes, ks_pos + 2) & 255) << 8) | (get(bytes, ks_pos + 3) & 255)
                ks_pos = ks_pos + 4
                if ks_pos + klen > ks_lim
                    break
                end
                if grp == TLS_GROUP_X25519
                    key_group = grp
                    client_pub = _tls13s_slice(bytes, ks_pos, ks_pos + klen)
                    supports_x25519 = 1
                    break
                end
                ks_pos = ks_pos + klen
            end
        end
        offset = offset + data_len
    end

    ch = tls13_client_hello_new(client_version, sid_len, selected_cipher, has_tls13, sni_name, key_group)
    ch.ch_session_id_bytes = sid_bytes
    ch.ch_client_pub_bytes = client_pub
    ch.ch_raw_hs_bytes = raw_hs
    ch.ch_supports_x25519_group = supports_x25519
    ch.ch_has_alpn_http11 = has_alpn_h1
    ch.ch_has_alpn_h2 = has_alpn_h2
    ch.ch_has_psk = has_psk
    ch.ch_has_psk_dhe = has_psk_dhe
    ch.ch_psk_identity = psk_id
    ch.ch_psk_binder = psk_binder
    ch.ch_psk_trunc_len = psk_trunc_len
    return ch

// ── 6. Authentic RFC 8446 ServerHello Construction (Real Curve25519 Key Share) ─

fn _tls13s_build_server_hello_with_psk client_hello server_priv32 include_psk_ext
    // Generates real ephemeral Curve25519 public key: s_pub = X25519(server_priv32, 9)
    s_pub = x25519_public_key(server_priv32)
    s_rand = _tls13s_rand_bytes(32)

    body = list()
    // Server legacy version 0x0303
    push(body, 3)
    push(body, 3)
    // Server Random (32 bytes via CSPRNG SYS_getrandom)
    _tls13s_append(body, s_rand)

    // Echo exact legacy_session_id from ClientHello (0..32 bytes per RFC 8446 §4.1.3)
    sid = client_hello.ch_session_id_bytes
    push(body, len(sid) & 255)
    _tls13s_append(body, sid)

    // Selected Cipher Suite
    cipher = client_hello.ch_cipher_suite
    if cipher == 0
        cipher = TLS_CIPHER_AES_128_GCM_SHA256
    end
    push(body, (cipher >> 8) & 255)
    push(body, cipher & 255)

    // Legacy Compression Method = 0x00
    push(body, 0)

    // Extensions: supported_versions (6) + key_share (40) [+ pre_shared_key (6)]
    ext_total = 46
    if include_psk_ext == 1
        ext_total = 52
    end
    push(body, (ext_total >> 8) & 255)
    push(body, ext_total & 255)

    // Extension: supported_versions (0x002B) -> TLS 1.3 (0x0304)
    push(body, 0)
    push(body, TLS_EXT_SUPPORTED_VERSIONS)
    push(body, 0)
    push(body, 2)
    push(body, 3)
    push(body, 4)

    // Extension: key_share (0x0033) -> X25519 (0x001D), length 32, real Curve25519 public key
    push(body, 0)
    push(body, TLS_EXT_KEY_SHARE)
    push(body, 0)
    push(body, 36)
    push(body, 0)
    push(body, TLS_GROUP_X25519)
    push(body, 0)
    push(body, 32)
    _tls13s_append(body, s_pub)

    if include_psk_ext == 1
        // Extension: pre_shared_key (0x0029), len=2, selected_identity=0
        push(body, 0)
        push(body, TLS_EXT_PRE_SHARED_KEY)
        push(body, 0)
        push(body, 2)
        push(body, 0)
        push(body, 0)
    end

    blen = len(body)
    hs = [TLS_HANDSHAKE_SERVER_HELLO, (blen >> 16) & 255, (blen >> 8) & 255, blen & 255]
    hs = _tls13s_append(hs, body)
    hlen = len(hs)

    wire = [TLS_CONTENT_HANDSHAKE, 3, 3, (hlen >> 8) & 255, hlen & 255]
    wire = _tls13s_append(wire, hs)
    return [wire, hs]

fn _tls13s_build_server_hello_internal client_hello server_priv32
    return _tls13s_build_server_hello_with_psk(client_hello, server_priv32, 0)

fn tls13_build_server_hello client_hello
    s_priv = _tls13s_rand_bytes(32)
    res = _tls13s_build_server_hello_internal(client_hello, s_priv)
    return res[0]

// ── 7. Genuine RFC 8446 AEAD Record Layer (AES-GCM / ChaCha20-Poly1305) ─────

fn tls13_record_encrypt_raw session pt_bytes
    // WHY: Binary-safe RFC 8446 AEAD record encryption for arbitrary binary protocols (e.g. HTTP/2 frames)
    // with RFC 8446 §5.1 16,384-byte record fragmentation.
    cipher = session.ts_cipher_suite
    seq = session.ts_server_seq
    plen = len(pt_bytes)
    if plen <= 16384
        rec = _tls13s_aead_wrap(cipher, session.ts_app_server_key, session.ts_app_server_iv, seq, TLS_CONTENT_APPLICATION_DATA, pt_bytes)
        session.ts_server_seq = seq + 1
        return rec
    end
    out = list()
    off = 0
    while off < plen
        stop = off + 16384
        if stop > plen
            stop = plen
        end
        chunk = _tls13s_slice(pt_bytes, off, stop)
        rec = _tls13s_aead_wrap(cipher, session.ts_app_server_key, session.ts_app_server_iv, seq, TLS_CONTENT_APPLICATION_DATA, chunk)
        _tls13s_append(out, rec)
        seq = seq + 1
        off = stop
    end
    session.ts_server_seq = seq
    return out

fn tls13_record_decrypt_raw session record_bytes
    // WHY: Binary-safe AEAD decrypt returning [ok, inner_type, payload_bytes].
    // Closes session state on AEAD failure or TLS Alert/close_notify, and rotates client
    // application traffic secrets on RFC 8446 §4.6.3 post-handshake KeyUpdate (type 24).
    if session == 0 or session.ts_state == TLS_STATE_CLOSED
        return [0, 0, list()]
    end
    cipher = session.ts_cipher_suite
    seq = session.ts_client_seq
    unw = _tls13s_aead_unwrap(cipher, session.ts_app_client_key, session.ts_app_client_iv, seq, record_bytes)
    if unw[0] != 1
        session.ts_state = TLS_STATE_CLOSED
        return [0, 0, list()]
    end
    session.ts_client_seq = seq + 1
    if unw[1] == TLS_CONTENT_ALERT
        session.ts_state = TLS_STATE_CLOSED
        return unw
    end
    if unw[1] == TLS_CONTENT_HANDSHAKE
        hs = unw[2]
        if len(hs) >= 5 and (get(hs, 0) & 255) == 24
            ku_req = tls13_parse_key_update_msg(hs)
            if ku_req < 0 or len(session.ts_app_client_secret) == 0
                session.ts_state = TLS_STATE_CLOSED
                return [0, 0, list()]
            end
            c_ku = tls13_key_update_next(cipher, session.ts_app_client_secret)
            session.ts_app_client_secret = c_ku.tku_secret
            session.ts_app_client_key = c_ku.tku_key
            session.ts_app_client_iv = c_ku.tku_iv
            session.ts_client_seq = 0
        end
    end
    return unw
end

fn tls13_server_initiate_key_update session request_update
    // WHY: Emits an RFC 8446 §4.6.3 KeyUpdate record encrypted under the CURRENT server
    // traffic key, then advances ts_app_server_secret/key/iv and resets ts_server_seq to 0.
    if session == 0 or len(session.ts_app_server_secret) == 0
        return list()
    end
    cipher = session.ts_cipher_suite
    ku_hs = tls13_build_key_update_msg(request_update)
    wire = _tls13s_aead_wrap(cipher, session.ts_app_server_key, session.ts_app_server_iv, session.ts_server_seq, TLS_CONTENT_HANDSHAKE, ku_hs)
    s_ku = tls13_key_update_next(cipher, session.ts_app_server_secret)
    session.ts_app_server_secret = s_ku.tku_secret
    session.ts_app_server_key = s_ku.tku_key
    session.ts_app_server_iv = s_ku.tku_iv
    session.ts_server_seq = 0
    return wire
end

fn tls13_record_encrypt session plaintext_str
    return tls13_record_encrypt_raw(session, tls_string_to_bytes(plaintext_str))
end

fn tls13_record_decrypt_prod session record_bytes
    // WHY: Production reactor decryptor returning [status, payload]:
    // status=1 app data string, status=0 benign post-handshake (e.g. KeyUpdate(0)),
    // status=2 client-initiated KeyUpdate(1) reply wire bytes to enqueue directly, status=-1 fatal/close_notify.
    unw = tls13_record_decrypt_raw(session, record_bytes)
    if unw[0] != 1
        return [-1, ""]
    end
    if unw[1] == TLS_CONTENT_ALERT
        return [-1, ""]
    end
    if unw[1] == TLS_CONTENT_APPLICATION_DATA
        return [1, tls_bytes_to_string(unw[2])]
    end
    if unw[1] == TLS_CONTENT_HANDSHAKE
        hs = unw[2]
        if len(hs) == 5 and (get(hs, 0) & 255) == 24 and (get(hs, 4) & 255) == 1
            ku_rep = tls13_server_initiate_key_update(session, 0)
            if len(ku_rep) > 0
                return [2, ku_rep]
            end
        end
    end
    return [0, ""]
end

fn tls13_record_decrypt session record_bytes
    // WHY: Decrypts & authenticates client->server application record using client app key/iv and client seq.
    unw = tls13_record_decrypt_raw(session, record_bytes)
    if unw[0] != 1 or unw[1] != TLS_CONTENT_APPLICATION_DATA
        return ""
    end
    return tls_bytes_to_string(unw[2])
end

fn tls13_server_record_decrypt_self session record_bytes seq
    unw = _tls13s_aead_unwrap(session.ts_cipher_suite, session.ts_app_server_key, session.ts_app_server_iv, seq, record_bytes)
    if unw[0] != 1 or unw[1] != TLS_CONTENT_APPLICATION_DATA
        return ""
    end
    return tls_bytes_to_string(unw[2])

// ── 8. Full Server Handshake Engine & Client Finished Verification ────────────

fn _tls13s_build_certificate_msg cert_chain
    entries = list()
    i = 0
    while i < len(cert_chain)
        der = get(cert_chain, i)
        clen = len(der)
        push(entries, (clen >> 16) & 255)
        push(entries, (clen >> 8) & 255)
        push(entries, clen & 255)
        _tls13s_append(entries, der)
        push(entries, 0)
        push(entries, 0)
        i = i + 1
    end
    elen = len(entries)
    body = [0, (elen >> 16) & 255, (elen >> 8) & 255, elen & 255]
    _tls13s_append(body, entries)
    blen = len(body)
    hs = [TLS_HANDSHAKE_CERTIFICATE, (blen >> 16) & 255, (blen >> 8) & 255, blen & 255]
    return _tls13s_append(hs, body)

fn _tls13s_build_cert_verify_msg_for sig_alg priv_key thash
    // RFC 8446 §4.4.3 signature over 64 * 0x20 || "TLS 1.3, server CertificateVerify\0" || H(transcript)
    cv_msg = list()
    i = 0
    while i < 64
        push(cv_msg, 32)
        i = i + 1
    end
    ctx = "TLS 1.3, server CertificateVerify"
    i = 0
    while i < str_len(ctx)
        push(cv_msg, str_char_at(ctx, i) & 255)
        i = i + 1
    end
    push(cv_msg, 0)
    _tls13s_append(cv_msg, thash)

    if sig_alg == TLS_SIG_ECDSA_SECP256R1_SHA256
        m_hash = sha256_hash_bytes(cv_msg)
        sig_der = list()
        attempt = 0
        while len(sig_der) == 0 and attempt < 8
            k_nonce = _tls13s_rand_bytes(32)
            sig_der = ecdsa_p256_sign_der(priv_key, m_hash, k_nonce)
            attempt = attempt + 1
        end
        slen = len(sig_der)
        blen = 4 + slen
        // sig_alg = 0x0403 (ecdsa_secp256r1_sha256 = 4, 3)
        hs = [TLS_HANDSHAKE_CERT_VERIFY, (blen >> 16) & 255, (blen >> 8) & 255, blen & 255, 4, 3, (slen >> 8) & 255, slen & 255]
        return _tls13s_append(hs, sig_der)
    end

    if sig_alg == TLS_SIG_ECDSA_SECP384R1_SHA384
        m_hash384 = sha384_hash_bytes(cv_msg)
        sig_der384 = list()
        attempt = 0
        while len(sig_der384) == 0 and attempt < 8
            k_nonce48 = _tls13s_rand_bytes(48)
            sig_der384 = ecdsa_p384_sign_der(priv_key, m_hash384, k_nonce48)
            attempt = attempt + 1
        end
        slen384 = len(sig_der384)
        blen384 = 4 + slen384
        // sig_alg = 0x0503 (ecdsa_secp384r1_sha384 = 5, 3)
        hs384 = [TLS_HANDSHAKE_CERT_VERIFY, (blen384 >> 16) & 255, (blen384 >> 8) & 255, blen384 & 255, 5, 3, (slen384 >> 8) & 255, slen384 & 255]
        return _tls13s_append(hs384, sig_der384)
    end

    sig64 = ed25519_sign(priv_key, cv_msg)
    // sig_alg = 0x0807 (Ed25519 = 8, 7), sig_len = 64 (0, 64), body_len = 68
    hs = [TLS_HANDSHAKE_CERT_VERIFY, 0, 0, 68, 8, 7, 0, 64]
    return _tls13s_append(hs, sig64)

fn _tls13s_build_cert_verify_msg engine thash
    return _tls13s_build_cert_verify_msg_for(engine.re_sig_alg, engine.re_priv_key32, thash)

fn _tls13s_bytes_eq_ct a b
    if len(a) != len(b)
        return 0
    end
    diff = 0
    i = 0
    while i < len(a)
        diff = diff | ((get(a, i) & 255) ^ (get(b, i) & 255))
        i = i + 1
    end
    if diff == 0
        return 1
    end
    return 0

fn _tls13s_zero_bytes n
    z = list()
    i = 0
    while i < n
        push(z, 0)
        i = i + 1
    end
    return z

fn _tls13s_compute_psk_binder psk cipher trunc_ch_bytes
    // WHY: RFC 8446 §4.2.11.2 cryptographic PSK binder calculation.
    if cipher == TLS_CIPHER_AES_256_GCM_SHA384
        z48 = _tls13s_zero_bytes(48)
        early = tls13_hkdf_extract_384(z48, psk)
        bkey = tls13_hkdf_expand_label_384(early, "res binder", sha384_hash_bytes([]), 48)
        fkey = tls13_hkdf_expand_label_384(bkey, "finished", [], 48)
        return tls13_hmac_sha384(fkey, sha384_hash_bytes(trunc_ch_bytes))
    end
    z32 = _tls13s_zero_bytes(32)
    early = tls13_hkdf_extract(z32, psk)
    bkey = tls13_hkdf_expand_label(early, "res binder", sha256_hash_bytes([]), 32)
    fkey = tls13_hkdf_expand_label(bkey, "finished", [], 32)
    return tls13_hmac_sha256(fkey, sha256_hash_bytes(trunc_ch_bytes))

fn _tls13s_evict_tickets engine max_cap
    // WHY: Bounds ticket cache memory and removes expired RFC 8446 session tickets.
    now_ms = clock_ms()
    n_ids = list()
    n_psks = list()
    n_ciphers = list()
    n_snis = list()
    n_exp = list()
    tcnt = len(engine.re_ticket_ids)
    ecnt = len(engine.re_ticket_exp)
    i = 0
    while i < tcnt
        exp_t = 0
        if i < ecnt
            exp_t = get(engine.re_ticket_exp, i)
        end
        if exp_t == 0 or now_ms < exp_t
            push(n_ids, get(engine.re_ticket_ids, i))
            push(n_psks, get(engine.re_ticket_psks, i))
            push(n_ciphers, get(engine.re_ticket_ciphers, i))
            push(n_snis, get(engine.re_ticket_snis, i))
            push(n_exp, exp_t)
        end
        i = i + 1
    end
    // Evict oldest entries if cache exceeds max_cap
    keep_from = 0
    if len(n_ids) > max_cap
        keep_from = len(n_ids) - max_cap
    end
    if keep_from > 0
        k_ids = list()
        k_psks = list()
        k_ciphers = list()
        k_snis = list()
        k_exp = list()
        ki = keep_from
        while ki < len(n_ids)
            push(k_ids, get(n_ids, ki))
            push(k_psks, get(n_psks, ki))
            push(k_ciphers, get(n_ciphers, ki))
            push(k_snis, get(n_snis, ki))
            push(k_exp, get(n_exp, ki))
            ki = ki + 1
        end
        engine.re_ticket_ids = k_ids
        engine.re_ticket_psks = k_psks
        engine.re_ticket_ciphers = k_ciphers
        engine.re_ticket_snis = k_snis
        engine.re_ticket_exp = k_exp
    else
        engine.re_ticket_ids = n_ids
        engine.re_ticket_psks = n_psks
        engine.re_ticket_ciphers = n_ciphers
        engine.re_ticket_snis = n_snis
        engine.re_ticket_exp = n_exp
    end
    return len(engine.re_ticket_ids)
end

fn _tls13s_verify_psk_ticket engine ch cipher
    // Returns [status, psk_bytes, ticket_sni]: status=1 valid PSK, 0 not found, -1 bad binder (reject!)
    if ch.ch_has_psk != 1 or ch.ch_has_psk_dhe != 1 or ch.ch_psk_trunc_len <= 0
        return [0, list(), ""]
    end
    _tls13s_evict_tickets(engine, 256)
    tcnt = len(engine.re_ticket_ids)
    i = 0
    while i < tcnt
        tid = get(engine.re_ticket_ids, i)
        if _tls13s_bytes_eq_ct(tid, ch.ch_psk_identity) == 1
            if get(engine.re_ticket_ciphers, i) != cipher
                return [0, list(), ""]
            end
            psk = get(engine.re_ticket_psks, i)
            trunc_ch = _tls13s_slice(ch.ch_raw_hs_bytes, 0, ch.ch_psk_trunc_len)
            exp_binder = _tls13s_compute_psk_binder(psk, cipher, trunc_ch)
            if _tls13s_bytes_eq_ct(exp_binder, ch.ch_psk_binder) != 1
                // RFC 8446 §4.2.11.2: known ticket with invalid binder MUST fail with decrypt_error
                return [-1, list(), ""]
            end
            return [1, psk, get(engine.re_ticket_snis, i)]
        end
        i = i + 1
    end
    return [0, list(), ""]
end

fn _tls13s_derive_psk_hs_keys psk shared_bytes thash1 cipher
    // WHY: RFC 8446 §7.1 PSK-DHE key schedule starting from early_secret = HKDF-Extract(0, PSK).
    if cipher == TLS_CIPHER_AES_256_GCM_SHA384
        z48 = _tls13s_zero_bytes(48)
        early = tls13_hkdf_extract_384(z48, psk)
        d_early = tls13_hkdf_expand_label_384(early, "derived", sha384_hash_bytes([]), 48)
        hs_sec = tls13_hkdf_extract_384(d_early, shared_bytes)
        c_hts = tls13_hkdf_expand_label_384(hs_sec, "c hs traffic", thash1, 48)
        s_hts = tls13_hkdf_expand_label_384(hs_sec, "s hs traffic", thash1, 48)
        return {
            handshake_secret: hs_sec,
            client_handshake_traffic_secret: c_hts,
            server_handshake_traffic_secret: s_hts,
            client_write_key: tls13_hkdf_expand_label_384(c_hts, "key", [], 32),
            client_write_iv: tls13_hkdf_expand_label_384(c_hts, "iv", [], 12),
            server_write_key: tls13_hkdf_expand_label_384(s_hts, "key", [], 32),
            server_write_iv: tls13_hkdf_expand_label_384(s_hts, "iv", [], 12)
        }
    end
    z32 = _tls13s_zero_bytes(32)
    early = tls13_hkdf_extract(z32, psk)
    d_early = tls13_hkdf_expand_label(early, "derived", sha256_hash_bytes([]), 32)
    hs_sec = tls13_hkdf_extract(d_early, shared_bytes)
    c_hts = tls13_hkdf_expand_label(hs_sec, "c hs traffic", thash1, 32)
    s_hts = tls13_hkdf_expand_label(hs_sec, "s hs traffic", thash1, 32)
    kl = 16
    if cipher == TLS_CIPHER_CHACHA20_POLY1305
        kl = 32
    end
    return {
        handshake_secret: hs_sec,
        client_handshake_traffic_secret: c_hts,
        server_handshake_traffic_secret: s_hts,
        client_write_key: tls13_hkdf_expand_label(c_hts, "key", [], kl),
        client_write_iv: tls13_hkdf_expand_label(c_hts, "iv", [], 12),
        server_write_key: tls13_hkdf_expand_label(s_hts, "key", [], kl),
        server_write_iv: tls13_hkdf_expand_label(s_hts, "iv", [], 12)
    }

fn _tls13s_hash_transcript cipher tr
    if cipher == TLS_CIPHER_AES_256_GCM_SHA384
        return sha384_hash_bytes(tr)
    end
    return sha256_hash_bytes(tr)

fn _tls13s_build_hrr ch
    // RFC 8446 §4.1.4 HelloRetryRequest (special SHA-256("HelloRetryRequest") random)
    hrr_rand = [207, 33, 173, 116, 229, 154, 97, 17, 190, 29, 140, 2, 30, 101, 184, 145, 194, 162, 17, 22, 122, 187, 140, 94, 7, 158, 9, 226, 200, 168, 51, 156]
    body = [3, 3]
    _tls13s_append(body, hrr_rand)
    sid = ch.ch_session_id_bytes
    push(body, len(sid) & 255)
    _tls13s_append(body, sid)
    cipher = ch.ch_cipher_suite
    if cipher == 0
        cipher = TLS_CIPHER_AES_128_GCM_SHA256
    end
    push(body, (cipher >> 8) & 255)
    push(body, cipher & 255)
    push(body, 0)
    // Extensions (12 bytes): supported_versions (0x0304) + key_share selected_group X25519 (0x001D)
    _tls13s_append(body, [0, 12, 0, 43, 0, 2, 3, 4, 0, 51, 0, 2, 0, 29])

    blen = len(body)
    hs = [TLS_HANDSHAKE_SERVER_HELLO, (blen >> 16) & 255, (blen >> 8) & 255, blen & 255]
    _tls13s_append(hs, body)
    hlen = len(hs)
    wire = [TLS_CONTENT_HANDSHAKE, 3, 3, (hlen >> 8) & 255, hlen & 255]
    _tls13s_append(wire, hs)
    return [wire, hs]

fn tls13_engine_process_handshake_with_prefix engine client_hello_bytes transcript_prefix
    // WHY: Executes full cryptographic X25519 ECDHE, HKDF-SHA256/384 key schedule,
    // optional ALPN negotiation, and authenticated EncryptedExtensions + Certificate +
    // ECDSA P-256 (0x0403) / Ed25519 (0x0807) CertificateVerify + Finished flight.
    ch = tls13_parse_client_hello(client_hello_bytes)
    if ch == 0
        return 0
    end
    if ch.ch_has_tls13 == 0 or ch.ch_key_share_group != TLS_GROUP_X25519
        return 0
    end
    if ch.ch_cipher_suite == 0
        ch.ch_cipher_suite = TLS_CIPHER_AES_128_GCM_SHA256
    end
    cipher = ch.ch_cipher_suite

    // Check optional RFC 8446 PSK Session Resumption (psk_dhe_ke)
    psk_check = _tls13s_verify_psk_ticket(engine, ch, cipher)
    psk_status = psk_check[0]
    if psk_status < 0
        // Tampered PSK binder for a known ticket -> abort handshake immediately
        return 0
    end
    use_psk = 0
    psk_bytes = list()
    if psk_status == 1
        use_psk = 1
        psk_bytes = psk_check[1]
    end

    // Select SNI-matched certificate chain & signing key (exact -> wildcard -> default)
    ident = _tls13s_select_identity(engine, ch.ch_sni_hostname)
    sel_chain = ident[0]
    sel_priv = ident[1]
    sel_sig_alg = ident[2]
    sel_sni_label = ident[3]

    s_priv = _tls13s_rand_bytes(32)
    if len(s_priv) != 32
        return 0
    end
    c_pub = ch.ch_client_pub_bytes
    // WHY: RFC 8446 §4.2.8.2 + RFC 7748 strictly mandate exact 32-byte X25519 key shares
    // and non-zero ECDHE shared secrets (ZERO padding or fallback to c_pub!).
    if len(c_pub) != 32
        return 0
    end
    shared_bytes = x25519_shared_secret(s_priv, c_pub)
    if len(shared_bytes) != 32 or _tls13s_is_all_zero32(shared_bytes) == 1
        return 0
    end

    sh_pair = _tls13s_build_server_hello_with_psk(ch, s_priv, use_psk)
    sh_wire = sh_pair[0]
    sh_hs = sh_pair[1]
    engine.re_last_server_hello = sh_wire

    // Compact nonzero scalar summary for backwards telemetry while keeping full 32-byte key in ts_shared_secret_bytes
    sec_tag = (get(shared_bytes, 0) * 16777216) | (get(shared_bytes, 1) * 65536) | (get(shared_bytes, 2) * 256) | get(shared_bytes, 3)
    if sec_tag == 0
        sec_tag = 1
    end

    transcript = _tls13s_append(list(), transcript_prefix)
    _tls13s_append(transcript, ch.ch_raw_hs_bytes)
    _tls13s_append(transcript, sh_hs)
    thash1 = _tls13s_hash_transcript(cipher, transcript)

    hs_keys = 0
    if use_psk == 1
        hs_keys = _tls13s_derive_psk_hs_keys(psk_bytes, shared_bytes, thash1, cipher)
    elif cipher == TLS_CIPHER_AES_256_GCM_SHA384
        hs_keys = tls13_derive_handshake_keys_384(shared_bytes, thash1)
    else
        hs_keys = tls13_derive_handshake_keys(shared_bytes, thash1)
        if cipher == TLS_CIPHER_CHACHA20_POLY1305
            hs_keys.client_write_key = tls13_hkdf_expand_label(hs_keys.client_handshake_traffic_secret, "key", [], 32)
            hs_keys.server_write_key = tls13_hkdf_expand_label(hs_keys.server_handshake_traffic_secret, "key", [], 32)
        end
    end

    // Assemble Server Flight wire: ServerHello + middlebox CCS + AEAD(EE, [Certificate, CertVerify,] Finished)
    flight = _tls13s_append(list(), sh_wire)
    if len(transcript_prefix) == 0
        _tls13s_append(flight, [TLS_CONTENT_CHANGE_CIPHER_SPEC, 3, 3, 0, 1, 1])
    end

    // 1. EncryptedExtensions (seq 0), negotiating ALPN "h2" (if enabled + offered) or "http/1.1"
    ee_hs = [TLS_HANDSHAKE_ENCRYPTED_EXT, 0, 0, 2, 0, 0]
    neg_alpn = "http/1.1"
    if engine.re_enable_h2 == 1 and ch.ch_has_alpn_h2 == 1
        // ALPN extension (0x0010): len=5, list_len=3, proto_len=2, "h2" (104, 50)
        ee_hs = [TLS_HANDSHAKE_ENCRYPTED_EXT, 0, 0, 11, 0, 9, 0, 16, 0, 5, 0, 3, 2, 104, 50]
        neg_alpn = "h2"
    elif ch.ch_has_alpn_http11 == 1
        ee_hs = [TLS_HANDSHAKE_ENCRYPTED_EXT, 0, 0, 17, 0, 15, 0, 16, 0, 11, 0, 9, 8, 104, 116, 116, 112, 47, 49, 46, 49]
        neg_alpn = "http/1.1"
    end
    _tls13s_append(transcript, ee_hs)
    _tls13s_append(flight, _tls13s_aead_wrap(cipher, hs_keys.server_write_key, hs_keys.server_write_iv, 0, TLS_CONTENT_HANDSHAKE, ee_hs))
    s_hs_seq = 1

    if use_psk == 0
        // 2. Certificate (seq 1)
        cert_hs = _tls13s_build_certificate_msg(sel_chain)
        _tls13s_append(transcript, cert_hs)
        _tls13s_append(flight, _tls13s_aead_wrap(cipher, hs_keys.server_write_key, hs_keys.server_write_iv, s_hs_seq, TLS_CONTENT_HANDSHAKE, cert_hs))
        s_hs_seq = s_hs_seq + 1

        // 3. CertificateVerify (seq 2) signed over H(transcript..Cert)
        cv_thash = _tls13s_hash_transcript(cipher, transcript)
        cv_hs = _tls13s_build_cert_verify_msg_for(sel_sig_alg, sel_priv, cv_thash)
        _tls13s_append(transcript, cv_hs)
        _tls13s_append(flight, _tls13s_aead_wrap(cipher, hs_keys.server_write_key, hs_keys.server_write_iv, s_hs_seq, TLS_CONTENT_HANDSHAKE, cv_hs))
        s_hs_seq = s_hs_seq + 1
    end

    // 4. Server Finished (seq 1 for PSK resumption, seq 3 for full handshake)
    fin_pre_hash = _tls13s_hash_transcript(cipher, transcript)
    s_fin_mac = list()
    fin_hlen = 32
    if cipher == TLS_CIPHER_AES_256_GCM_SHA384
        fin_hlen = 48
        s_fin_key = tls13_hkdf_expand_label_384(hs_keys.server_handshake_traffic_secret, "finished", [], 48)
        s_fin_mac = tls13_hmac_sha384(s_fin_key, fin_pre_hash)
    else
        s_fin_key = tls13_hkdf_expand_label(hs_keys.server_handshake_traffic_secret, "finished", [], 32)
        s_fin_mac = tls13_hmac_sha256(s_fin_key, fin_pre_hash)
    end
    s_fin_hs = [TLS_HANDSHAKE_FINISHED, 0, 0, fin_hlen & 255]
    _tls13s_append(s_fin_hs, s_fin_mac)
    _tls13s_append(transcript, s_fin_hs)
    _tls13s_append(flight, _tls13s_aead_wrap(cipher, hs_keys.server_write_key, hs_keys.server_write_iv, s_hs_seq, TLS_CONTENT_HANDSHAKE, s_fin_hs))

    // 5. Derive Master Secret & Application Traffic Keys from H(CH..ServerFinished)
    app_thash = _tls13s_hash_transcript(cipher, transcript)
    master = list()
    c_app = list()
    s_app = list()
    c_app_key = list()
    c_app_iv = list()
    s_app_key = list()
    s_app_iv = list()
    if cipher == TLS_CIPHER_AES_256_GCM_SHA384
        z48 = _tls13s_zero_bytes(48)
        d_hs = tls13_hkdf_expand_label_384(hs_keys.handshake_secret, "derived", sha384_hash_bytes([]), 48)
        master = tls13_hkdf_extract_384(d_hs, z48)
        c_app = tls13_hkdf_expand_label_384(master, "c ap traffic", app_thash, 48)
        s_app = tls13_hkdf_expand_label_384(master, "s ap traffic", app_thash, 48)
        c_app_key = tls13_hkdf_expand_label_384(c_app, "key", [], 32)
        c_app_iv = tls13_hkdf_expand_label_384(c_app, "iv", [], 12)
        s_app_key = tls13_hkdf_expand_label_384(s_app, "key", [], 32)
        s_app_iv = tls13_hkdf_expand_label_384(s_app, "iv", [], 12)
    else
        z32 = _tls13s_zero_bytes(32)
        d_hs = tls13_hkdf_expand_label(hs_keys.handshake_secret, "derived", sha256_hash_bytes([]), 32)
        master = tls13_hkdf_extract(d_hs, z32)
        c_app = tls13_hkdf_expand_label(master, "c ap traffic", app_thash, 32)
        s_app = tls13_hkdf_expand_label(master, "s ap traffic", app_thash, 32)
        kl = 16
        if cipher == TLS_CIPHER_CHACHA20_POLY1305
            kl = 32
        end
        c_app_key = tls13_hkdf_expand_label(c_app, "key", [], kl)
        c_app_iv = tls13_hkdf_expand_label(c_app, "iv", [], 12)
        s_app_key = tls13_hkdf_expand_label(s_app, "key", [], kl)
        s_app_iv = tls13_hkdf_expand_label(s_app, "iv", [], 12)
    end

    session = tls13_session_new(cipher, sec_tag)
    session.ts_shared_secret_bytes = shared_bytes
    session.ts_hs_client_key = hs_keys.client_write_key
    session.ts_hs_client_iv = hs_keys.client_write_iv
    session.ts_hs_server_key = hs_keys.server_write_key
    session.ts_hs_server_iv = hs_keys.server_write_iv
    session.ts_client_hs_secret = hs_keys.client_handshake_traffic_secret
    session.ts_app_client_key = c_app_key
    session.ts_app_client_iv = c_app_iv
    session.ts_app_server_key = s_app_key
    session.ts_app_server_iv = s_app_iv
    session.ts_server_flight_wire = flight
    session.ts_fin_transcript_hash = app_thash
    session.ts_selected_sni = sel_sni_label
    session.ts_alpn = neg_alpn
    session.ts_master_secret = master
    session.ts_is_resumed = use_psk
    session.ts_handshake_transcript = transcript
    session.ts_app_client_secret = c_app
    session.ts_app_server_secret = s_app

    // WHY: Cap re_active_sessions to 256 entries (FIFO eviction) so long-running servers never leak memory.
    sessions = engine.re_active_sessions
    if len(sessions) >= 256
        trimmed_s = list()
        si_t = len(sessions) - 255
        while si_t < len(sessions)
            push(trimmed_s, get(sessions, si_t))
            si_t = si_t + 1
        end
        sessions = trimmed_s
        engine.re_active_sessions = sessions
    end
    push(sessions, session)
    engine.re_total_handshakes = engine.re_total_handshakes + 1
    return session

fn tls13_engine_process_handshake engine client_hello_bytes
    // WHY: Standard 1-RTT entrypoint delegating to prefix-aware handshake engine with empty HRR prefix.
    return tls13_engine_process_handshake_with_prefix(engine, client_hello_bytes, list())

fn tls13_verify_client_finished session fin_record_bytes
    unw = _tls13s_aead_unwrap(session.ts_cipher_suite, session.ts_hs_client_key, session.ts_hs_client_iv, 0, fin_record_bytes)
    if unw[0] != 1 or unw[1] != TLS_CONTENT_HANDSHAKE
        return 0
    end
    hs = unw[2]
    exp_len = 32
    if session.ts_cipher_suite == TLS_CIPHER_AES_256_GCM_SHA384
        exp_len = 48
    end
    if len(hs) != 4 + exp_len or get(hs, 0) != TLS_HANDSHAKE_FINISHED
        return 0
    end
    exp_mac = list()
    if session.ts_cipher_suite == TLS_CIPHER_AES_256_GCM_SHA384
        cfk = tls13_hkdf_expand_label_384(session.ts_client_hs_secret, "finished", [], 48)
        exp_mac = tls13_hmac_sha384(cfk, session.ts_fin_transcript_hash)
    else
        cfk = tls13_hkdf_expand_label(session.ts_client_hs_secret, "finished", [], 32)
        exp_mac = tls13_hmac_sha256(cfk, session.ts_fin_transcript_hash)
    end
    if _tls13s_bytes_eq_ct(_tls13s_slice(hs, 4, 4 + exp_len), exp_mac) != 1
        return 0
    end
    // Derive RFC 8446 §7.1 resumption_master_secret over H(ClientHello..ClientFinished)
    full_tr = _tls13s_append(list(), session.ts_handshake_transcript)
    _tls13s_append(full_tr, hs)
    res_thash = _tls13s_hash_transcript(session.ts_cipher_suite, full_tr)
    if len(session.ts_master_secret) > 0
        if session.ts_cipher_suite == TLS_CIPHER_AES_256_GCM_SHA384
            session.ts_resumption_master_secret = tls13_hkdf_expand_label_384(session.ts_master_secret, "res master", res_thash, 48)
        else
            session.ts_resumption_master_secret = tls13_hkdf_expand_label(session.ts_master_secret, "res master", res_thash, 32)
        end
    end
    return 1

fn tls13_server_issue_session_ticket engine session
    // WHY: Issues an RFC 8446 §4.6.1 NewSessionTicket bound to this session's
    // resumption_master_secret and caches the derived PSK on the engine for 1-RTT resumption.
    if len(session.ts_resumption_master_secret) == 0
        return [list(), list(), list()]
    end
    ticket_id = _tls13s_rand_bytes(16)
    ticket_nonce = _tls13s_rand_bytes(8)
    age_add = _tls13s_rand_bytes(4)
    psk = list()
    if session.ts_cipher_suite == TLS_CIPHER_AES_256_GCM_SHA384
        psk = tls13_hkdf_expand_label_384(session.ts_resumption_master_secret, "resumption", ticket_nonce, 48)
    else
        psk = tls13_hkdf_expand_label(session.ts_resumption_master_secret, "resumption", ticket_nonce, 32)
    end
    _tls13s_evict_tickets(engine, 255)
    push(engine.re_ticket_ids, ticket_id)
    push(engine.re_ticket_psks, psk)
    push(engine.re_ticket_ciphers, session.ts_cipher_suite)
    push(engine.re_ticket_snis, session.ts_selected_sni)
    push(engine.re_ticket_exp, clock_ms() + 3600000)

    // Wire NewSessionTicket: lifetime(4=3600) || age_add(4) || nonce_len(1) || nonce(8) || ticket_len(2) || ticket(16) || ext_len(2=0)
    body = [0, 0, 14, 16]
    _tls13s_append(body, age_add)
    push(body, 8)
    _tls13s_append(body, ticket_nonce)
    push(body, 0)
    push(body, 16)
    _tls13s_append(body, ticket_id)
    push(body, 0)
    push(body, 0)
    blen = len(body)
    hs = [TLS_HANDSHAKE_NEW_SESSION_TICKET, (blen >> 16) & 255, (blen >> 8) & 255, blen & 255]
    _tls13s_append(hs, body)
    wire = _tls13s_aead_wrap(session.ts_cipher_suite, session.ts_app_server_key, session.ts_app_server_iv, session.ts_server_seq, TLS_CONTENT_HANDSHAKE, hs)
    session.ts_server_seq = session.ts_server_seq + 1
    return [ticket_id, psk, wire]

fn tls13_build_psk_client_hello sni_host c_pub32 ticket_id psk cipher
    // WHY: Constructs an RFC 8446 ClientHello with X25519 key_share, psk_key_exchange_modes (psk_dhe_ke),
    // and pre_shared_key carrying a genuine HMAC-SHA256/384 PSK binder over the truncated ClientHello.
    hlen = 32
    if cipher == TLS_CIPHER_AES_256_GCM_SHA384
        hlen = 48
    end
    c_rand = _tls13s_rand_bytes(32)
    sid = _tls13s_rand_bytes(32)
    body = [3, 3]
    _tls13s_append(body, c_rand)
    push(body, 32)
    _tls13s_append(body, sid)
    // Cipher suites (2 bytes)
    push(body, 0)
    push(body, 2)
    push(body, (cipher >> 8) & 255)
    push(body, cipher & 255)
    // Compression methods: 1 byte [0x00]
    push(body, 1)
    push(body, 0)

    // Extensions before pre_shared_key
    exts = list()
    // 1. SNI (0x0000)
    sni_b = tls_string_to_bytes(sni_host)
    sn_len = len(sni_b)
    if sn_len > 0
        sni_list_len = 3 + sn_len
        sni_ext_len = 2 + sni_list_len
        _tls13s_append(exts, [0, 0, (sni_ext_len >> 8) & 255, sni_ext_len & 255, (sni_list_len >> 8) & 255, sni_list_len & 255, 0, (sn_len >> 8) & 255, sn_len & 255])
        _tls13s_append(exts, sni_b)
    end
    // 2. supported_versions (0x002B): TLS 1.3
    _tls13s_append(exts, [0, 43, 0, 3, 2, 3, 4])
    // 3. supported_groups (0x000A): X25519
    _tls13s_append(exts, [0, 10, 0, 4, 0, 2, 0, 29])
    // 4. key_share (0x0033): X25519 c_pub32
    _tls13s_append(exts, [0, 51, 0, 38, 0, 36, 0, 29, 0, 32])
    _tls13s_append(exts, c_pub32)
    // 5. psk_key_exchange_modes (0x002D): psk_dhe_ke (1)
    _tls13s_append(exts, [0, 45, 0, 2, 1, 1])

    // 6. pre_shared_key (0x0029) MUST be last extension
    tid_len = len(ticket_id)
    ids_len = 2 + tid_len + 4
    binders_len = 1 + hlen
    psk_ext_len = 2 + ids_len + 2 + binders_len
    psk_prefix = [0, 41, (psk_ext_len >> 8) & 255, psk_ext_len & 255, (ids_len >> 8) & 255, ids_len & 255, (tid_len >> 8) & 255, tid_len & 255]
    _tls13s_append(psk_prefix, ticket_id)
    _tls13s_append(psk_prefix, [0, 0, 0, 1]) // obfuscated_ticket_age

    total_ext_len = len(exts) + len(psk_prefix) + 2 + binders_len
    push(body, (total_ext_len >> 8) & 255)
    push(body, total_ext_len & 255)
    _tls13s_append(body, exts)
    _tls13s_append(body, psk_prefix)

    // Handshake total body length includes binders (2 + binders_len)
    full_blen = len(body) + 2 + binders_len
    trunc_hs = [TLS_HANDSHAKE_CLIENT_HELLO, (full_blen >> 16) & 255, (full_blen >> 8) & 255, full_blen & 255]
    _tls13s_append(trunc_hs, body)

    binder = _tls13s_compute_psk_binder(psk, cipher, trunc_hs)
    full_hs = _tls13s_append(list(), trunc_hs)
    push(full_hs, (binders_len >> 8) & 255)
    push(full_hs, binders_len & 255)
    push(full_hs, hlen & 255)
    _tls13s_append(full_hs, binder)

    fl = len(full_hs)
    wire = [TLS_CONTENT_HANDSHAKE, 3, 1, (fl >> 8) & 255, fl & 255]
    return _tls13s_append(wire, full_hs)

// ── 9. Direct Kernel Socket Live TLS 1.3 Server Loop Driver ──────────────────

fn _tls13s_set_fd_timeout fd sec
    // WHY: Configures SO_RCVTIMEO (20) and SO_SNDTIMEO (21) so a stalled TLS client
    // during handshake can never freeze the epoll reactor thread indefinitely.
    if fd < 0 or sec <= 0 return 0 end
    tv = malloc(16)
    if tv <= 0 return 0 end
    mem_write(tv, 0, sec)
    mem_write(tv, 8, 0)
    syscall(54, fd, 1, 20, tv, 16, 0)
    syscall(54, fd, 1, 21, tv, 16, 0)
    free(tv, 16)
    return 1
end

fn _tls13s_read_exact_fd fd ptr need
    // WHY: Retries SYS_read on EINTR (-4) so STW GC SIGURG signals never abort live TLS handshakes.
    got = 0
    while got < need
        n = syscall(0, fd, ptr + got, need - got, 0, 0, 0)
        if n == (0 - 4)
            continue
        end
        if n <= 0 return -1 end
        got = got + n
    end
    return got
end

fn _tls13s_write_list_fd fd arr
    n = len(arr)
    if n == 0 return 0 end
    buf = malloc(n)
    if buf <= 0 return -1 end
    i = 0
    while i < n
        mem_byte_write(buf, i, get(arr, i) & 255)
        i = i + 1
    end
    sent = 0
    while sent < n
        w = syscall(44, fd, buf + sent, n - sent, 16384, 0, 0)
        if w == (0 - 4) continue end
        if w == (0 - 88)
            w = syscall(1, fd, buf + sent, n - sent, 0, 0, 0)
        end
        if w <= 0
            free(buf, n)
            return -1
        end
        sent = sent + w
    end
    free(buf, n)
    return sent

fn _tls13s_read_wire_record fd
    hdr = malloc(8)
    if _tls13s_read_exact_fd(fd, hdr, 5) != 5
        free(hdr, 8)
        return list()
    end
    out = [
        mem_byte_read(hdr, 0) & 255,
        mem_byte_read(hdr, 1) & 255,
        mem_byte_read(hdr, 2) & 255,
        mem_byte_read(hdr, 3) & 255,
        mem_byte_read(hdr, 4) & 255
    ]
    free(hdr, 8)
    rlen = (get(out, 3) * 256) | get(out, 4)
    if rlen > 32768
        return list()
    end
    if rlen > 0
        rb = malloc(rlen)
        if _tls13s_read_exact_fd(fd, rb, rlen) != rlen
            free(rb, rlen)
            return list()
        end
        i = 0
        while i < rlen
            push(out, mem_byte_read(rb, i) & 255)
            i = i + 1
        end
        free(rb, rlen)
    end
    return out

fn tls13_server_handshake_fd conn_fd engine
    // WHY: Enforces a 5-second SO_RCVTIMEO/SO_SNDTIMEO handshake deadline before reading
    // ClientHello so stalled peers never freeze the accept loop; handles HRR + Client Finished.
    _tls13s_set_fd_timeout(conn_fd, 5)
    ch_rec = _tls13s_read_wire_record(conn_fd)
    if len(ch_rec) < 45
        return 0
    end
    ch1 = tls13_parse_client_hello(ch_rec)
    if ch1 == 0
        return 0
    end

    session = 0
    if ch1.ch_has_tls13 == 1 and ch1.ch_key_share_group != TLS_GROUP_X25519 and ch1.ch_supports_x25519_group == 1
        cipher1 = ch1.ch_cipher_suite
        if cipher1 == 0
            cipher1 = TLS_CIPHER_AES_128_GCM_SHA256
        end
        ch1_hash = _tls13s_hash_transcript(cipher1, ch1.ch_raw_hs_bytes)
        hrr = _tls13s_build_hrr(ch1)
        hrr_pkt = _tls13s_append(list(), hrr[0])
        if len(ch1.ch_session_id_bytes) > 0
            _tls13s_append(hrr_pkt, [TLS_CONTENT_CHANGE_CIPHER_SPEC, 3, 3, 0, 1, 1])
        end
        if _tls13s_write_list_fd(conn_fd, hrr_pkt) <= 0
            return 0
        end
        ch2_rec = _tls13s_read_wire_record(conn_fd)
        while len(ch2_rec) > 0 and get(ch2_rec, 0) == TLS_CONTENT_CHANGE_CIPHER_SPEC
            ch2_rec = _tls13s_read_wire_record(conn_fd)
        end
        if len(ch2_rec) < 45
            return 0
        end
        tr_prefix = [TLS_HANDSHAKE_MESSAGE_HASH, 0, 0, len(ch1_hash) & 255]
        _tls13s_append(tr_prefix, ch1_hash)
        _tls13s_append(tr_prefix, hrr[1])
        session = tls13_engine_process_handshake_with_prefix(engine, ch2_rec, tr_prefix)
    else
        session = tls13_engine_process_handshake(engine, ch_rec)
    end
    if session == 0
        return 0
    end
    if _tls13s_write_list_fd(conn_fd, session.ts_server_flight_wire) <= 0
        return 0
    end
    fin_rec = _tls13s_read_wire_record(conn_fd)
    while len(fin_rec) > 0 and get(fin_rec, 0) == TLS_CONTENT_CHANGE_CIPHER_SPEC
        fin_rec = _tls13s_read_wire_record(conn_fd)
    end
    if len(fin_rec) < 22
        return 0
    end
    if tls13_verify_client_finished(session, fin_rec) != 1
        return 0
    end
    return session

fn tls13_server_accept_and_serve_once listen_fd engine response_body
    // Accepts 1 TLS 1.3 connection, completes real handshake, reads encrypted HTTP request,
    // sends encrypted HTTP/1.1 200 OK response + TLS 1.3 close_notify, and closes conn_fd.
    cfd = syscall(43, listen_fd, 0, 0, 0, 0, 0)
    if cfd < 0
        return -1
    end
    session = tls13_server_handshake_fd(cfd, engine)
    if session == 0
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return -2
    end
    req_rec = _tls13s_read_wire_record(cfd)
    if len(req_rec) < 22
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return -3
    end
    req_pt = tls13_record_decrypt(session, req_rec)
    if str_len(req_pt) == 0
        syscall(3, cfd, 0, 0, 0, 0, 0)
        return -4
    end
    blen = str_len(response_body)
    http_resp = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " + to_str(blen) + "\r\nConnection: close\r\n\r\n" + response_body
    enc_resp = tls13_record_encrypt(session, http_resp)
    _tls13s_write_list_fd(cfd, enc_resp)
    close_alert = _tls13s_aead_wrap(session.ts_cipher_suite, session.ts_app_server_key, session.ts_app_server_iv, session.ts_server_seq, TLS_CONTENT_ALERT, [1, 0])
    session.ts_server_seq = session.ts_server_seq + 1
    _tls13s_write_list_fd(cfd, close_alert)
    syscall(3, cfd, 0, 0, 0, 0, 0)
    return 1
