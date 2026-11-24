// ==============================================================================
// 🧪 LIPI SOVEREIGN FIVE-PILLARS END-TO-END REGRESSION SUITE
// File: tests/test_sovereign_five_pillars_e2e.lp
// 100% Pure Lipi — Zero OpenSSL / Zero Libc / Zero External Runtime Dependencies
//
// PILLAR 1: Live Loopback TLS 1.3 Server <-> Client + 3-Tier X.509 PKI + System CA
// PILLAR 2: Cryptographic CertificateVerify (Ed25519, P-256, P-384, RSA-PSS) + Rejections
// PILLAR 3: KavachCapsule Signed W^X Native Code + W^X FFI + 8-Thread & Fork KavachRing
// PILLAR 4: Persistent Disk-Backed Lipi SQL CRC-32 WAL + Torn-Tail Crash Recovery
// PILLAR 5: Crash-Safe Job Queue CRC-32 WAL + Running->Pending Auto-Recovery + Compact
// ==============================================================================

import "utso/net/http"
include "utso/net/tls13_server.lp"
include "utso/core/kavach_capsule.lp"
include "utso/core/ffi_sovereign.lp"
include "utso/os/thread.lp"
import "aati/lipi_sql/src/sql"
include "aati/lipi_web/job_queue.lp"

// ── Test Assertion & Low-Level Utilities ──────────────────────────────────────

fn e2e_assert_eq actual expected label
    if actual != expected
        say "  ❌ [FAIL] " + label + " -> Expected: " + str(expected) + ", Got: " + str(actual)
        exit(1)
    end
    say "  ✔ [PASS] " + label + ": " + str(actual)
    return 1

fn e2e_assert_str actual expected label
    if actual != expected
        say "  ❌ [FAIL] " + label + " -> Expected: '" + expected + "', Got: '" + actual + "'"
        exit(1)
    end
    say "  ✔ [PASS] " + label + ": " + actual
    return 1

fn e2e_assert_true cond label
    if cond == 0
        say "  ❌ [FAIL] " + label
        exit(1)
    end
    say "  ✔ [PASS] " + label
    return 1

fn e2e_copy_bytes src
    out = list()
    i = 0
    n = len(src)
    while i < n
        push(out, get(src, i))
        i = i + 1
    end
    return out

fn e2e_bytes_append_ascii dst s
    i = 0
    n = len(s)
    while i < n
        push(dst, ord(char_at(s, i)))
        i = i + 1
    end
    return dst

fn e2e_bytes_append_list dst src
    i = 0
    n = len(src)
    while i < n
        push(dst, get(src, i))
        i = i + 1
    end
    return dst

fn e2e_unlink path
    slen = len(path)
    buf = malloc(slen + 1)
    i = 0
    while i < slen
        mem_byte_write(buf, i, ord(char_at(path, i)))
        i = i + 1
    end
    mem_byte_write(buf, slen, 0)
    syscall(87, buf, 0, 0, 0, 0, 0)
    free(buf, slen + 1)
    return 0

fn e2e_append_garbage path nbytes
    slen = len(path)
    pbuf = malloc(slen + 1)
    i = 0
    while i < slen
        mem_byte_write(pbuf, i, ord(char_at(path, i)))
        i = i + 1
    end
    mem_byte_write(pbuf, slen, 0)
    // O_WRONLY (1) | O_APPEND (1024) = 1025
    fd = syscall(2, pbuf, 1025, 0, 0, 0, 0)
    free(pbuf, slen + 1)
    if fd < 0
        return -1
    end
    gbuf = malloc(nbytes)
    k = 0
    while k < nbytes
        mem_byte_write(gbuf, k, (173 + k * 29) & 255)
        k = k + 1
    end
    syscall(1, fd, gbuf, nbytes, 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    free(gbuf, nbytes)
    return 0

fn e2e_ffi_compute a b c
    return (a * b) + c

fn e2e_write_reloc_so path
    // WHY: Synthesizes a spec-compliant 2-PT_LOAD (RX=5 at 0x0, RW=6 at 0x1000) ELF64 ET_DYN
    // shared object on disk with a real R_X86_64_RELATIVE (.rela.dyn) relocation patching
    // .data[0] (0x1000) -> base + 0x0240 (.rodata constant 777), proving W^X + relocation on silicon.
    sz = 4736
    fbuf = malloc(sz)
    mem_fill(fbuf, 0, sz)

    // ELF64 Header (64 bytes)
    mem_byte_write(fbuf, 0, 127)
    mem_byte_write(fbuf, 1, 69)
    mem_byte_write(fbuf, 2, 76)
    mem_byte_write(fbuf, 3, 70)
    mem_byte_write(fbuf, 4, 2)
    mem_byte_write(fbuf, 5, 1)
    mem_byte_write(fbuf, 6, 1)
    mem_byte_write(fbuf, 16, 3)  // ET_DYN
    mem_byte_write(fbuf, 18, 62) // EM_X86_64
    mem_write_u32(fbuf, 20, 1)
    mem_write(fbuf, 32, 64)      // e_phoff
    mem_write(fbuf, 40, 4352)    // e_shoff
    mem_byte_write(fbuf, 52, 64) // e_ehsize
    mem_byte_write(fbuf, 54, 56) // e_phentsize
    mem_byte_write(fbuf, 56, 2)  // e_phnum
    mem_byte_write(fbuf, 58, 64) // e_shentsize
    mem_byte_write(fbuf, 60, 6)  // e_shnum
    mem_byte_write(fbuf, 62, 5)  // e_shstrndx

    // PHDR[0]: PT_LOAD RX (flags=5), vaddr=0, filesz=1024, memsz=1024
    mem_write_u32(fbuf, 64, 1)
    mem_write_u32(fbuf, 68, 5)
    mem_write(fbuf, 96, 1024)
    mem_write(fbuf, 104, 1024)
    mem_write(fbuf, 112, 4096)

    // PHDR[1]: PT_LOAD RW (flags=6), offset=4096, vaddr=4096, filesz=128, memsz=128
    mem_write_u32(fbuf, 120, 1)
    mem_write_u32(fbuf, 124, 6)
    mem_write(fbuf, 128, 4096)
    mem_write(fbuf, 136, 4096)
    mem_write(fbuf, 144, 4096)
    mem_write(fbuf, 152, 128)
    mem_write(fbuf, 160, 128)
    mem_write(fbuf, 168, 4096)

    // .text at 512 (0x0200): imul rax, rdi, 10; mov rcx, [rip + 0x0df5]; add rax, [rcx]; ret
    ops = [72, 107, 199, 10, 72, 139, 13, 245, 13, 0, 0, 72, 3, 1, 195]
    oi = 0
    while oi < len(ops)
        mem_byte_write(fbuf, 512 + oi, get(ops, oi))
        oi = oi + 1
    end

    // .rodata at 576 (0x0240): u64(777)
    mem_write(fbuf, 576, 777)

    // .dynstr at 640 (0x0280): "\0so_reloc_compute\0"
    sname = "so_reloc_compute"
    mem_byte_write(fbuf, 640, 0)
    si = 0
    while si < len(sname)
        mem_byte_write(fbuf, 641 + si, ord(char_at(sname, si)))
        si = si + 1
    end
    mem_byte_write(fbuf, 641 + len(sname), 0)

    // .dynsym at 704 (0x02C0): Sym[0] null, Sym[1] at 728 -> so_reloc_compute @ 0x0200
    mem_write_u32(fbuf, 728, 1)
    mem_byte_write(fbuf, 732, 18)
    mem_byte_write(fbuf, 734, 1)
    mem_write(fbuf, 736, 512)
    mem_write(fbuf, 744, 15)

    // .rela.dyn at 4224 (0x1080): R_X86_64_RELATIVE (8) patching 0x1000 -> base + 576
    mem_write(fbuf, 4224, 4096)
    mem_write(fbuf, 4232, 8)
    mem_write(fbuf, 4240, 576)

    // Section Headers at 4352 (6 * 64B)
    // Shdr[1] .text
    mem_write_u32(fbuf, 4416 + 4, 1)
    mem_write(fbuf, 4416 + 8, 6)
    mem_write(fbuf, 4416 + 16, 512)
    mem_write(fbuf, 4416 + 24, 512)
    mem_write(fbuf, 4416 + 32, 15)
    // Shdr[2] .dynsym (sh_link = 3 -> .dynstr)
    mem_write_u32(fbuf, 4480 + 4, 11)
    mem_write(fbuf, 4480 + 8, 2)
    mem_write(fbuf, 4480 + 16, 704)
    mem_write(fbuf, 4480 + 24, 704)
    mem_write(fbuf, 4480 + 32, 48)
    mem_write_u32(fbuf, 4480 + 40, 3)
    mem_write(fbuf, 4480 + 56, 24)
    // Shdr[3] .dynstr
    mem_write_u32(fbuf, 4544 + 4, 3)
    mem_write(fbuf, 4544 + 8, 2)
    mem_write(fbuf, 4544 + 16, 640)
    mem_write(fbuf, 4544 + 24, 640)
    mem_write(fbuf, 4544 + 32, 18)
    // Shdr[4] .rela.dyn
    mem_write_u32(fbuf, 4608 + 4, 4)
    mem_write(fbuf, 4608 + 24, 4224)
    mem_write(fbuf, 4608 + 32, 24)
    mem_write_u32(fbuf, 4608 + 40, 2)
    mem_write(fbuf, 4608 + 56, 24)
    // Shdr[5] .shstrtab
    mem_write_u32(fbuf, 4672 + 4, 3)
    mem_write(fbuf, 4672 + 24, 768)
    mem_write(fbuf, 4672 + 32, 8)

    slen = len(path)
    pbuf = malloc(slen + 1)
    pi = 0
    while pi < slen
        mem_byte_write(pbuf, pi, ord(char_at(path, pi)))
        pi = pi + 1
    end
    mem_byte_write(pbuf, slen, 0)
    fd = syscall(2, pbuf, 577, 493, 0, 0, 0)
    free(pbuf, slen + 1)
    if fd >= 0
        syscall(1, fd, fbuf, sz, 0, 0, 0)
        syscall(3, fd, 0, 0, 0, 0, 0)
    end
    free(fbuf, sz)
    return fd

// ── Thread Worker For 8-Thread x 2,000-Op KavachRing Stress ───────────────────
// ctx layout (16 bytes):
//   [0] = ring pointer
//   [8] = thread_idx (1..8)
fn e2e_ring_worker ctx_ptr
    ring = mem_read(ctx_ptr, 0)
    tid = mem_read(ctx_ptr, 8)
    k = 0
    while k < 2000
        sent = kavach_ring_try_send_i64(ring, tid, k, 1, tid * 10000 + k)
        if sent == 0
            thread_yield()
        else
            k = k + 1
        end
    end
    thread_exit(0)
    return 0

fn e2e_build_cv_msg transcript_hash
    msg = list()
    i = 0
    while i < 64
        push(msg, 32)
        i = i + 1
    end
    e2e_bytes_append_ascii(msg, "TLS 1.3, server CertificateVerify")
    push(msg, 0)
    e2e_bytes_append_list(msg, transcript_hash)
    return msg

fn e2e_build_rsa1024_cert ca_sk n_bytes
    // AlgorithmIdentifier: rsaEncryption (1.2.840.113549.1.1.1) + NULL
    alg_id = [48, 13, 6, 9, 42, 134, 72, 134, 247, 13, 1, 1, 1, 5, 0]
    // Unsigned ASN.1 INTEGER for n (prepend 0x00 if MSB >= 128)
    n_int_body = list()
    if get(n_bytes, 0) >= 128
        push(n_int_body, 0)
    end
    e2e_bytes_append_list(n_int_body, n_bytes)
    n_tlv = _x509_der_tlv_wrap(2, n_int_body)
    e_tlv = _x509_der_tlv_wrap(2, [1, 0, 1])
    rsa_pk = _x509_der_tlv_wrap(48, _x509_der_append(n_tlv, e_tlv))
    bitstr = _x509_der_tlv_wrap(3, _x509_der_append([0], rsa_pk))
    spki = _x509_der_tlv_wrap(48, _x509_der_append(alg_id, bitstr))
    ed_alg = [48, 5, 6, 3, 43, 101, 112]
    tbs = _x509_build_tbs_common("Lipi Root CA", "rsa-leaf.lipi.dev", "rsa-leaf.lipi.dev", "250101000000Z", "350101000000Z", 0, ed_alg, spki, 901)
    sig = ed25519_sign(ca_sk, tbs)
    sig_bs = _x509_der_tlv_wrap(3, _x509_der_append([0], sig))
    cert_body = _x509_der_append(_x509_der_append(tbs, ed_alg), sig_bs)
    return _x509_der_tlv_wrap(48, cert_body)

fn e2e_build_p384_cert ca_sk pub97
    // AlgorithmIdentifier: id-ecPublicKey (1.2.840.10045.2.1) + secp384r1 (1.3.132.0.34)
    ec_oid = [6, 7, 42, 134, 72, 206, 61, 2, 1]
    p384_oid = [6, 5, 43, 129, 4, 0, 34]
    alg_id = _x509_der_tlv_wrap(48, _x509_der_append(ec_oid, p384_oid))
    bitstr = _x509_der_tlv_wrap(3, _x509_der_append([0], pub97))
    spki = _x509_der_tlv_wrap(48, _x509_der_append(alg_id, bitstr))
    ed_alg = [48, 5, 6, 3, 43, 101, 112]
    tbs = _x509_build_tbs_common("Lipi Root CA", "p384-leaf.lipi.dev", "p384-leaf.lipi.dev", "250101000000Z", "350101000000Z", 0, ed_alg, spki, 902)
    sig = ed25519_sign(ca_sk, tbs)
    sig_bs = _x509_der_tlv_wrap(3, _x509_der_append([0], sig))
    cert_body = _x509_der_append(_x509_der_append(tbs, ed_alg), sig_bs)
    return _x509_der_tlv_wrap(48, cert_body)

fn main
    say "========================================================================"
    say "👑 LIPI SOVEREIGN FIVE-PILLARS END-TO-END REGRESSION SUITE 👑"
    say "   0% OpenSSL | 0% Libc | 0% SQLite | 0% Redis | 0% RWX mmap"
    say "========================================================================"

    // =========================================================================
    // PILLAR 1: Live Loopback TLS 1.3 Server <-> Client & 3-Tier PKI + System CA
    // =========================================================================
    say "\n▶ Pillar 1: Live Loopback TLS 1.3 Server <-> Client + 3-Tier PKI..."

    root_sk = [11,21,31,41,51,61,71,81, 91,101,111,121,131,141,151,161, 171,181,191,201,211,221,231,241, 14,24,34,44,54,64,74,84]
    inter_sk = [12,22,32,42,52,62,72,82, 92,102,112,122,132,142,152,162, 172,182,192,202,212,222,232,242, 15,25,35,45,55,65,75,85]
    leaf_sk = [13,23,33,43,53,63,73,83, 93,103,113,123,133,143,153,163, 173,183,193,203,213,223,233,243, 16,26,36,46,56,66,76,86]

    root_pk = ed25519_keygen(root_sk).public_key
    inter_pk = ed25519_keygen(inter_sk).public_key
    leaf_pk = ed25519_keygen(leaf_sk).public_key

    root_cert = x509_build_signed_ed25519_cert("Lipi Root CA", "Lipi Root CA", "", "250101000000Z", "350101000000Z", 1, root_pk, root_sk, 101)
    inter_cert = x509_build_signed_ed25519_cert("Lipi Root CA", "Lipi Intermediate CA", "", "250101000000Z", "350101000000Z", 1, inter_pk, root_sk, 102)
    leaf_cert = x509_build_signed_ed25519_cert("Lipi Intermediate CA", "localhost", "localhost", "250101000000Z", "350101000000Z", 0, leaf_pk, inter_sk, 103)

    // Bind ephemeral IPv4 127.0.0.1:0 loopback listening socket before fork
    lfd = syscall(41, 2, 1, 0, 0, 0, 0)
    e2e_assert_true(lfd >= 0, "TCP socket created")

    opt = malloc(8)
    mem_write(opt, 0, 1)
    syscall(54, lfd, 1, 2, opt, 4, 0)
    free(opt, 8)

    sa = malloc(16)
    mem_fill(sa, 0, 16)
    mem_byte_write(sa, 0, 2)   // AF_INET
    mem_byte_write(sa, 2, 0)   // ephemeral port 0
    mem_byte_write(sa, 3, 0)
    mem_byte_write(sa, 4, 127) // 127.0.0.1
    mem_byte_write(sa, 5, 0)
    mem_byte_write(sa, 6, 0)
    mem_byte_write(sa, 7, 1)

    bind_rc = syscall(49, lfd, sa, 16, 0, 0, 0)
    e2e_assert_eq(bind_rc, 0, "Bind 127.0.0.1:0 succeeded")
    listen_rc = syscall(50, lfd, 8, 0, 0, 0, 0)
    e2e_assert_eq(listen_rc, 0, "Listen backlog active")

    alen_ptr = malloc(8)
    mem_write(alen_ptr, 0, 16)
    gsn_rc = syscall(51, lfd, sa, alen_ptr, 0, 0, 0)
    e2e_assert_eq(gsn_rc, 0, "getsockname succeeded")
    port = (mem_byte_read(sa, 2) << 8) + mem_byte_read(sa, 3)
    e2e_assert_true(port > 0, "Ephemeral loopback port assigned: " + str(port))
    free(sa, 16)
    free(alen_ptr, 8)

    srv_engine = tls13_record_engine_new()
    tls13_engine_set_identity(srv_engine, [leaf_cert, inter_cert], leaf_sk)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        // Child serves 2 connections: 1 trusted, 1 rejected by client PKI check
        rc1 = tls13_server_accept_and_serve_once(lfd, srv_engine, "{\"sovereign\":true}")
        rc2 = tls13_server_accept_and_serve_once(lfd, srv_engine, "{\"sovereign\":true}")
        syscall(3, lfd, 0, 0, 0, 0, 0)
        if rc1 < 0
            syscall(60, 1, 0, 0, 0, 0, 0)
        end
        syscall(60, 0, 0, 0, 0, 0, 0)
    end
    e2e_assert_true(pid > 0, "Forked Pure-Lipi TLS 1.3 server child")

    url = "https://localhost:" + str(port) + "/sovereign"
    tls13_clear_custom_trust_roots()
    tls13_set_system_roots_enabled(0)
    tls13_add_trust_root(root_cert)

    resp_ok = http_get(url)
    e2e_assert_eq(resp_ok.status_code, 200, "Live TLS 1.3 loopback HTTPS GET status == 200")
    e2e_assert_str(resp_ok.body, "{\"sovereign\":true}", "Live TLS 1.3 encrypted HTTP body verified")

    // Untrusted connection: clear custom roots with system roots disabled -> MUST fail
    tls13_clear_custom_trust_roots()
    resp_untrusted = http_get(url)
    e2e_assert_eq(resp_untrusted.status_code, 0, "Untrusted self/custom CA rejected before HTTP status")

    st_ptr = malloc(8)
    mem_write(st_ptr, 0, 0)
    syscall(61, pid, st_ptr, 0, 0, 0, 0)
    child_status = mem_read(st_ptr, 0)
    free(st_ptr, 8)
    syscall(3, lfd, 0, 0, 0, 0, 0)
    e2e_assert_eq((child_status >> 8) & 255, 0, "TLS 1.3 server child exited cleanly")

    tls13_set_system_roots_enabled(1)
    sys_roots = x509_load_pem_bundle_file("/etc/ssl/certs/ca-certificates.crt")
    e2e_assert_true(len(sys_roots) >= 100, "Loaded >= 100 system Root CAs from /etc/ssl/certs/ca-certificates.crt")

    // Browser-Grade Universal NIST P-256 (0x0403) Live Loopback Server <-> Client + ALPN + HRR
    p256_srv = tls13_record_engine_new()
    e2e_assert_eq(p256_srv.re_sig_alg, 1027, "Default TLS 1.3 server identity uses universal ECDSA P-256 (0x0403)")

    lfd2 = syscall(41, 2, 1, 0, 0, 0, 0)
    sa2 = malloc(16)
    mem_fill(sa2, 0, 16)
    mem_byte_write(sa2, 0, 2)
    mem_byte_write(sa2, 4, 127)
    mem_byte_write(sa2, 7, 1)
    syscall(49, lfd2, sa2, 16, 0, 0, 0)
    syscall(50, lfd2, 8, 0, 0, 0, 0)
    alen2 = malloc(8)
    mem_write(alen2, 0, 16)
    syscall(51, lfd2, sa2, alen2, 0, 0, 0)
    port2 = (mem_byte_read(sa2, 2) << 8) + mem_byte_read(sa2, 3)
    free(sa2, 16)
    free(alen2, 8)

    // Build 24,576-byte payload (> 16,384B RFC 8446 §5.1 single-record ceiling)
    big_chunk = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"
    big_body = ""
    bi_k = 0
    while bi_k < 384
        big_body = big_body + big_chunk
        bi_k = bi_k + 1
    end

    pid2 = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid2 == 0
        rc_b = tls13_server_accept_and_serve_once(lfd2, p256_srv, big_body)
        syscall(3, lfd2, 0, 0, 0, 0, 0)
        if rc_b < 0
            syscall(60, 1, 0, 0, 0, 0, 0)
        end
        syscall(60, 0, 0, 0, 0, 0, 0)
    end
    tls13_clear_custom_trust_roots()
    tls13_set_system_roots_enabled(0)
    tls13_add_trust_root(p256_srv.re_root_ca_der)
    resp_p256 = http_get("https://localhost:" + str(port2) + "/browser")
    e2e_assert_eq(resp_p256.status_code, 200, "Live ECDSA P-256 (0x0403) browser-compatible HTTPS GET == 200")
    e2e_assert_eq(len(resp_p256.body), 24576, "Multi-record >16KB TLS 1.3 payload (24,576 bytes) received intact")
    e2e_assert_eq(ord(char_at(resp_p256.body, 24575)), 70, "Final byte of 24,576-byte multi-record stream == 'F'")
    st2 = malloc(8)
    syscall(61, pid2, st2, 0, 0, 0, 0)
    free(st2, 8)
    syscall(3, lfd2, 0, 0, 0, 0, 0)
    tls13_clear_custom_trust_roots()
    tls13_set_system_roots_enabled(1)

    // Verify RFC 8446 §4.1.4 HelloRetryRequest + ALPN "http/1.1" negotiation wire framing
    ch1_wire = [22, 3, 3, 0, 93, 1, 0, 0, 89, 3, 3]
    ri_c = 0
    while ri_c < 32
        push(ch1_wire, ri_c + 1)
        ri_c = ri_c + 1
    end
    e2e_bytes_append_list(ch1_wire, [0, 0, 2, 19, 1, 1, 0, 0, 46])
    e2e_bytes_append_list(ch1_wire, [0, 43, 0, 3, 2, 3, 4])
    e2e_bytes_append_list(ch1_wire, [0, 10, 0, 6, 0, 4, 0, 23, 0, 29])
    e2e_bytes_append_list(ch1_wire, [0, 16, 0, 11, 0, 9, 8, 104, 116, 116, 112, 47, 49, 46, 49])
    e2e_bytes_append_list(ch1_wire, [0, 51, 0, 10, 0, 8, 0, 23, 0, 4, 1, 2, 3, 4])
    ch_hrr = tls13_parse_client_hello(ch1_wire)
    e2e_assert_eq(ch_hrr.ch_has_alpn_http11, 1, "Parsed ALPN 'http/1.1' from ClientHello")
    e2e_assert_eq(ch_hrr.ch_supports_x25519_group, 1, "Parsed X25519 in supported_groups")
    e2e_assert_eq(ch_hrr.ch_key_share_group, 0, "Detected non-X25519 initial key_share requiring HRR")
    hrr_pair = _tls13s_build_hrr(ch_hrr)
    hrr_hs = hrr_pair[1]
    e2e_assert_eq(get(hrr_hs, 6), 207, "RFC 8446 HelloRetryRequest SHA-256 magic byte 0 == 0xCF")
    e2e_assert_eq(get(hrr_hs, len(hrr_hs) - 1), 29, "HelloRetryRequest selects NamedGroup X25519 (0x001D)")

    // =========================================================================
    // PILLAR 2: CertificateVerify Crypto Across All 4 Algorithms & Chain Checks
    // =========================================================================
    say "\n▶ Pillar 2: Cryptographic CertificateVerify & X.509 Chain Rejections..."

    thash32 = sha256_hash_bytes([1, 2, 3, 4, 5, 6, 7, 8])
    cv_msg256 = e2e_build_cv_msg(thash32)
    cv_hash256 = sha256_hash_bytes(cv_msg256)

    // 2.1 Ed25519 (sig_alg = 2055)
    sig_ed = ed25519_sign(leaf_sk, cv_msg256)
    e2e_assert_eq(tls13_verify_certificate_verify(leaf_cert, thash32, 2055, sig_ed), 1, "CertificateVerify Ed25519 (2055) accepted")
    bad_ed = e2e_copy_bytes(sig_ed)
    list_set(bad_ed, len(bad_ed) - 1, get(bad_ed, len(bad_ed) - 1) ^ 1)
    e2e_assert_eq(tls13_verify_certificate_verify(leaf_cert, thash32, 2055, bad_ed), 0, "CertificateVerify Ed25519 1-bit flip rejected")

    // 2.2 NIST P-256 (sig_alg = 1027)
    p256_sk = [91,12,44,88, 17,203,65,99, 134,52,211,76, 39,145,28,187, 63,110,192,41, 84,22,155,73, 198,31,117,240, 12,87,143,66]
    p256_k = [33,77,111,222, 45,67,89,123, 210,198,144,55, 88,99,11,22, 133,144,155,166, 177,188,199,200, 19,29,39,49, 59,69,79,89]
    p256_kp = ecdsa_p256_keygen_from_scalar(p256_sk)
    p256_cert = x509_build_signed_p256_cert("Lipi Root CA", "p256.lipi.dev", "p256.lipi.dev", "250101000000Z", "350101000000Z", 0, p256_kp, p256_sk, p256_k, 201)
    sig_p256 = ecdsa_p256_sign_der(p256_sk, cv_hash256, p256_k)
    e2e_assert_eq(tls13_verify_certificate_verify(p256_cert, thash32, 1027, sig_p256), 1, "CertificateVerify NIST P-256 (1027) accepted")
    bad_p256 = e2e_copy_bytes(sig_p256)
    list_set(bad_p256, len(bad_p256) - 1, get(bad_p256, len(bad_p256) - 1) ^ 1)
    e2e_assert_eq(tls13_verify_certificate_verify(p256_cert, thash32, 1027, bad_p256), 0, "CertificateVerify NIST P-256 1-bit flip rejected")

    // 2.3 NIST P-384 (sig_alg = 1283)
    p384_sk = [14,28,42,56,70,84,98,112, 126,140,154,168,182,196,210,224, 17,34,51,68,85,102,119,136, 153,170,187,204,221,238,15,31, 47,63,79,95,111,127,143,159, 175,191,207,223,239,25,50,75]
    p384_k = [23,46,69,92,115,138,161,184, 207,230,11,35,59,83,107,131, 155,179,203,227,13,37,61,85, 109,133,157,181,205,229,18,41, 64,87,110,133,156,179,202,225, 29,52,75,98,121,144,167,190]
    p384_kp = ecdsa_p384_keygen_from_scalar(p384_sk)
    p384_cert = e2e_build_p384_cert(root_sk, p384_kp)
    thash48 = sha384_hash_bytes([9, 8, 7, 6, 5, 4, 3, 2])
    cv_msg384 = e2e_build_cv_msg(thash48)
    cv_hash384 = sha384_hash_bytes(cv_msg384)
    sig_p384 = ecdsa_p384_sign_der(p384_sk, cv_hash384, p384_k)
    e2e_assert_eq(tls13_verify_certificate_verify(p384_cert, thash48, 1283, sig_p384), 1, "CertificateVerify NIST P-384 (1283) accepted")
    bad_p384 = e2e_copy_bytes(sig_p384)
    list_set(bad_p384, len(bad_p384) - 1, get(bad_p384, len(bad_p384) - 1) ^ 1)
    e2e_assert_eq(tls13_verify_certificate_verify(p384_cert, thash48, 1283, bad_p384), 0, "CertificateVerify NIST P-384 1-bit flip rejected")

    // 2.4 1024-bit RSA-PSS SHA-256 (sig_alg = 2052)
    rsa_n = [166, 89, 147, 180, 53, 9, 165, 12, 121, 128, 209, 93, 61, 126, 50, 78, 228, 89, 254, 125, 68, 19, 92, 11, 240, 254, 94, 195, 254, 24, 126, 207, 27, 255, 10, 163, 112, 223, 126, 8, 31, 118, 101, 211, 254, 82, 79, 80, 96, 172, 233, 192, 35, 196, 219, 87, 122, 221, 26, 107, 99, 208, 222, 104, 243, 107, 31, 61, 217, 238, 94, 22, 132, 107, 190, 73, 121, 92, 10, 127, 135, 19, 49, 140, 199, 133, 231, 122, 127, 32, 25, 252, 114, 14, 188, 74, 182, 249, 0, 233, 229, 29, 71, 116, 245, 92, 183, 173, 65, 42, 198, 235, 190, 153, 153, 133, 168, 25, 13, 137, 166, 215, 35, 96, 251, 72, 81, 237]
    rsa_d = [132, 203, 75, 114, 247, 71, 252, 190, 233, 155, 225, 6, 122, 217, 108, 21, 184, 138, 242, 242, 82, 206, 213, 147, 30, 206, 33, 30, 122, 144, 89, 98, 194, 41, 165, 247, 117, 90, 164, 68, 157, 193, 41, 102, 195, 70, 55, 212, 165, 104, 67, 173, 195, 160, 25, 173, 75, 2, 136, 93, 164, 48, 15, 235, 20, 38, 153, 209, 81, 116, 129, 90, 222, 132, 206, 26, 31, 244, 95, 176, 207, 85, 41, 102, 252, 89, 16, 71, 243, 143, 196, 131, 115, 91, 104, 82, 94, 187, 221, 177, 109, 129, 5, 151, 44, 5, 245, 214, 48, 130, 78, 116, 52, 70, 68, 214, 96, 19, 177, 228, 77, 81, 56, 250, 171, 59, 11, 97]
    rsa_salt = [1,2,3,4,5,6,7,8, 9,10,11,12,13,14,15,16, 17,18,19,20,21,22,23,24, 25,26,27,28,29,30,31,32]
    rsa_cert = e2e_build_rsa1024_cert(root_sk, rsa_n)
    sig_rsa = rsa_pss_sign_bytes(rsa_n, rsa_d, 1024, cv_hash256, rsa_salt, 256)
    e2e_assert_eq(tls13_verify_certificate_verify(rsa_cert, thash32, 2052, sig_rsa), 1, "CertificateVerify RSA-PSS SHA-256 (2052) accepted")
    bad_rsa = e2e_copy_bytes(sig_rsa)
    list_set(bad_rsa, len(bad_rsa) - 1, get(bad_rsa, len(bad_rsa) - 1) ^ 1)
    e2e_assert_eq(tls13_verify_certificate_verify(rsa_cert, thash32, 2052, bad_rsa), 0, "CertificateVerify RSA-PSS SHA-256 1-bit flip rejected")

    // 2.5 Expired, Not-Yet-Valid, and Leaf-As-CA chain rejections
    tls13_clear_custom_trust_roots()
    tls13_set_system_roots_enabled(0)
    tls13_add_trust_root(root_cert)
    exp_cert = x509_build_signed_ed25519_cert("Lipi Root CA", "exp.lipi.dev", "exp.lipi.dev", "190101000000Z", "200101000000Z", 0, leaf_pk, root_sk, 301)
    fut_cert = x509_build_signed_ed25519_cert("Lipi Root CA", "fut.lipi.dev", "fut.lipi.dev", "980101000000Z", "990101000000Z", 0, leaf_pk, root_sk, 302)
    not_ca = x509_build_signed_ed25519_cert("Lipi Root CA", "fake-ca.lipi.dev", "", "250101000000Z", "350101000000Z", 0, inter_pk, root_sk, 303)
    leaf_under_non_ca = x509_build_signed_ed25519_cert("fake-ca.lipi.dev", "localhost", "localhost", "250101000000Z", "350101000000Z", 0, leaf_pk, inter_sk, 304)

    e2e_assert_eq(tls13_verify_x509_cert_chain(exp_cert, "exp.lipi.dev"), 0, "Expired 2020 cert rejected")
    e2e_assert_eq(tls13_verify_x509_cert_chain(fut_cert, "fut.lipi.dev"), 0, "Not-yet-valid 2098 cert rejected")
    e2e_assert_eq(tls13_verify_x509_cert_chain_list([leaf_under_non_ca, not_ca], "localhost"), 0, "Leaf-as-CA (cA=FALSE) rejected")

    // 2.6 RFC 6125 Wildcard SAN Matching & Top-Level TLD Wildcard (*.com) Rejection
    wc_cert = x509_build_signed_ed25519_cert("Lipi Root CA", "*.lipi.dev", "*.lipi.dev", "250101000000Z", "350101000000Z", 0, leaf_pk, root_sk, 305)
    tld_wc_cert = x509_build_signed_ed25519_cert("Lipi Root CA", "*.com", "*.com", "250101000000Z", "350101000000Z", 0, leaf_pk, root_sk, 306)
    e2e_assert_eq(tls13_verify_x509_cert_chain(wc_cert, "api.lipi.dev"), 1, "Valid wildcard *.lipi.dev matches api.lipi.dev")
    e2e_assert_eq(tls13_verify_x509_cert_chain(wc_cert, "lipi.dev"), 0, "Wildcard *.lipi.dev rejects bare apex lipi.dev")
    e2e_assert_eq(tls13_verify_x509_cert_chain(wc_cert, "a.b.lipi.dev"), 0, "Wildcard *.lipi.dev rejects multi-level a.b.lipi.dev")
    e2e_assert_eq(tls13_verify_x509_cert_chain(tld_wc_cert, "stripe.com"), 0, "Malicious TLD wildcard *.com rejected per RFC 6125")
    tls13_set_system_roots_enabled(1)

    // =========================================================================
    // PILLAR 3: KavachCapsule W^X + W^X FFI + 8-Thread & Fork KavachRing IPC
    // =========================================================================
    say "\n▶ Pillar 3: KavachCapsule W^X Native Code, W^X FFI & Concurrent KavachRing..."

    pub_kp = ed25519_keygen(root_sk)
    // Native x86-64 calc_fma(rdi=a0, rsi=a1) = a0 * a1 + [rip + disp32]
    // 48 89 f8         mov rax, rdi
    // 48 0f af c6      imul rax, rsi
    // 48 03 05 0000000 add rax, [rip + disp32]  (patch_off = 10)
    // c3               ret
    fma_code = [72, 137, 248, 72, 15, 175, 198, 72, 3, 5, 0, 0, 0, 0, 195]
    fma_rodata = [135, 0, 0, 0, 0, 0, 0, 0] // u64(135)
    exp_list = [kavach_export_new("calc_fma", 0, KAVACH_CAP_PURE_COMPUTE | KAVACH_CAP_MEMORY_ARENA)]
    rel_list = [kavach_reloc_new(10, KAVACH_TARGET_RODATA, KAVACH_RELOC_REL32, 0)]

    cap_bytes = kavach_capsule_pack(KAVACH_CAP_PURE_COMPUTE | KAVACH_CAP_MEMORY_ARENA, exp_list, rel_list, fma_code, fma_rodata, root_sk)
    cap_h = kavach_capsule_load_bytes(cap_bytes, pub_kp.public_key, KAVACH_CAP_PURE_COMPUTE | KAVACH_CAP_MEMORY_ARENA)
    e2e_assert_eq(cap_h.kcap_valid, 1, "LPKC capsule signature verified & loaded W^X")
    e2e_assert_eq(kavach_capsule_invoke(cap_h, "calc_fma", KAVACH_CAP_PURE_COMPUTE | KAVACH_CAP_MEMORY_ARENA, 10, 100, 0, 0, 0), 1135, "Native LPKC calc_fma(10, 100) + .rodata(135) == 1135")
    e2e_assert_eq(kavach_capsule_invoke(cap_h, "calc_fma", KAVACH_CAP_PURE_COMPUTE, 10, 100, 0, 0, 0), -3, "Missing KAVACH_CAP_MEMORY_ARENA blocked (-3)")
    kavach_capsule_unload(cap_h)

    // Capability denial on load
    cap_denied = kavach_capsule_load_bytes(cap_bytes, pub_kp.public_key, KAVACH_CAP_PURE_COMPUTE)
    e2e_assert_eq(cap_denied.kcap_valid, -3, "Over-privileged capsule rejected at load (-3)")

    // Signature tamper rejection
    bad_cap = e2e_copy_bytes(cap_bytes)
    list_set(bad_cap, len(bad_cap) - 1, get(bad_cap, len(bad_cap) - 1) ^ 1)
    cap_tampered = kavach_capsule_load_bytes(bad_cap, pub_kp.public_key, KAVACH_CAP_PURE_COMPUTE | KAVACH_CAP_MEMORY_ARENA)
    e2e_assert_eq(cap_tampered.kcap_valid, -2, "Tampered LPKC payload rejected (-2)")

    // Out-of-bounds >2GiB REL32 displacement rejection (-1)
    ovf_rels = [kavach_reloc_new(10, KAVACH_TARGET_RODATA, KAVACH_RELOC_REL32, 8589934592)]
    ovf_bytes = kavach_capsule_pack(KAVACH_CAP_PURE_COMPUTE | KAVACH_CAP_MEMORY_ARENA, exp_list, ovf_rels, fma_code, fma_rodata, root_sk)
    cap_ovf = kavach_capsule_load_bytes(ovf_bytes, pub_kp.public_key, KAVACH_CAP_PURE_COMPUTE | KAVACH_CAP_MEMORY_ARENA)
    e2e_assert_eq(cap_ovf.kcap_valid, -1, "Out-of-range >2GiB REL32 relocation safely rejected (-1)")

    // W^X FFI trampoline call
    ffi_val = ffi_call_native(&e2e_ffi_compute, 7, 11, 23, 0, 0)
    e2e_assert_eq(ffi_val, 100, "W^X FFI trampoline e2e_ffi_compute(7, 11, 23) == 100")

    // On-disk multi-segment ELF64 ET_DYN .so load + R_X86_64_RELATIVE (.rela.dyn) + W^X execution
    so_path = "/tmp/lipi_e2e_reloc.so"
    e2e_unlink(so_path)
    e2e_assert_true(e2e_write_reloc_so(so_path) >= 0, "Emitted 2-PT_LOAD ELF64 .so with .rela.dyn R_X86_64_RELATIVE")
    so_lib = ffi_load_so(so_path)
    e2e_assert_eq(get(so_lib, 6), 1, "ffi_load_so mapped PT_LOAD segments, relocated .rela.dyn & applied W^X")
    so_fn = ffi_find_symbol(so_lib, "so_reloc_compute")
    e2e_assert_true(so_fn > 65536, "ffi_find_symbol resolved 'so_reloc_compute' via sh_link .dynstr")
    so_res = ffi_call_native(so_fn, 12, 0, 0, 0, 0)
    e2e_assert_eq(so_res, 897, "Executed relocated W^X .so function (12 * 10 + 777 == 897)")
    ffi_close_so(so_lib)
    e2e_unlink(so_path)

    // 8-Thread x 2,000-Op Concurrent KavachRing Stress (16,000 messages across cap=512 wraparound)
    ring = kavach_ring_create(512, 64)
    e2e_assert_true(ring > 0, "KavachRing MAP_SHARED ring created")

    handles = list()
    ctxs = list()
    t = 1
    while t <= 8
        ctx = malloc(16)
        mem_write(ctx, 0, ring)
        mem_write(ctx, 8, t)
        push(ctxs, ctx)
        th = thread_spawn_joinable(&e2e_ring_worker, ctx, 65536)
        e2e_assert_true(th != 0, "Spawned KavachRing producer OS thread #" + str(t))
        push(handles, th)
        t = t + 1
    end

    out_slot = malloc(64)
    recvd = 0
    total_ones = 0
    total_tids = 0
    while recvd < 16000
        if kavach_ring_try_recv_i64(ring, out_slot) == 1
            v_tid = mem_read(out_slot, 0)
            v_one = mem_read(out_slot, 16)
            total_tids = total_tids + v_tid
            total_ones = total_ones + v_one
            recvd = recvd + 1
        else
            thread_yield()
        end
    end

    j = 0
    while j < 8
        thread_join(get(handles, j))
        free(get(ctxs, j), 16)
        j = j + 1
    end
    free(out_slot, 64)

    e2e_assert_eq(total_ones, 16000, "8-thread x 2,000-op KavachRing received all 16,000 messages")
    // Sum of thread IDs 1..8 = 36; 36 * 2000 = 72000
    e2e_assert_eq(total_tids, 72000, "KavachRing thread ID checksum == 72,000 (zero corruption)")
    e2e_assert_eq(kavach_ring_count(ring), 0, "KavachRing drained to 0")

    // Cross-process SYS_fork byte-slice IPC over MAP_SHARED KavachRing
    ipc_pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if ipc_pid == 0
        s_msg = "KAVACH_FORK_IPC_OK"
        s_len = len(s_msg)
        s_buf = malloc(32)
        si = 0
        while si < s_len
            mem_byte_write(s_buf, si, ord(char_at(s_msg, si)))
            si = si + 1
        end
        while kavach_ring_send_bytes(ring, s_buf, s_len) == 0
            thread_yield()
        end
        free(s_buf, 32)
        syscall(60, 0, 0, 0, 0, 0, 0)
    end
    r_buf = malloc(64)
    got_ipc = 0
    while got_ipc <= 0
        got_ipc = kavach_ring_recv_bytes(ring, r_buf, 64)
        if got_ipc <= 0
            thread_yield()
        end
    end
    ipc_str = ""
    ri = 0
    while ri < got_ipc
        ipc_str = ipc_str + chr(mem_byte_read(r_buf, ri))
        ri = ri + 1
    end
    free(r_buf, 64)
    ipc_st = malloc(8)
    syscall(61, ipc_pid, ipc_st, 0, 0, 0, 0)
    free(ipc_st, 8)
    e2e_assert_str(ipc_str, "KAVACH_FORK_IPC_OK", "Cross-process SYS_fork KavachRing bytes IPC verified")
    kavach_ring_destroy(ring)

    // =========================================================================
    // PILLAR 4: Persistent Disk-Backed Lipi SQL CRC-32 WAL + Crash Recovery
    // =========================================================================
    say "\n▶ Pillar 4: Persistent Lipi SQL CRC-32 WAL & Torn-Tail Recovery..."

    sql_wal = "/tmp/lipi_e2e_sql.wal"
    e2e_unlink(sql_wal)
    e2e_unlink(sql_wal + ".tmp")

    db1 = sql_engine_open(sql_wal)
    e2e_assert_true(db1 != 0, "Opened persistent SQL engine")

    ti = 1
    while ti <= 24
        sql_create_table(db1, ti, 2, 8)
        ti = ti + 1
    end
    e2e_assert_true(mem_read(db1, 0) >= 24, "Created 24 SQL tables beyond old 16-table limit")

    ri = 1
    while ri <= 40
        sql_insert_2(db1, 24, ri, ri * 100)
        ri = ri + 1
    end
    sql_execute_query(db1, "UPDATE 24 SET 1 = 99999 WHERE 0 = 40")
    sql_create_table(db1, 25, 2, 4)
    sql_insert_text_2(db1, 25, 7, "sovereign-wal-text")
    sql_create_table(db1, 26, 1, 4)
    sql_insert_1(db1, 26, 77777)
    sql_create_table(db1, 27, 4, 4)
    sql_execute_query(db1, "INSERT INTO 27 VALUES (10, 20, 30, 4444)")
    sql_engine_close(db1)

    // Inject 11-byte torn tail simulating mid-write power loss
    e2e_append_garbage(sql_wal, 11)

    db2 = sql_engine_open(sql_wal)
    e2e_assert_eq(sql_count_active(db2, 24), 40, "Recovered all 40 auto-grown rows after torn-tail WAL replay")
    e2e_assert_eq(sql_select_first_where_eq(db2, 24, 0, 40, 1), 99999, "Recovered UPDATE (row 40 -> 99999) from WAL")
    e2e_assert_str(sql_select_text_cell(db2, 25, 0, 1), "sovereign-wal-text", "Recovered interned TEXT string across reopen")
    e2e_assert_eq(sql_select_cell(db2, 26, 0, 0), 77777, "Recovered 1-column table row across WAL replay")
    e2e_assert_eq(sql_select_cell(db2, 27, 0, 3), 4444, "Recovered 4th column (col 3 == 4444) across WAL replay")

    sql_engine_checkpoint(db2, sql_wal)
    sql_engine_close(db2)

    db3 = sql_engine_open(sql_wal)
    e2e_assert_eq(sql_count_active(db3, 24), 40, "Post-checkpoint SQL WAL reload intact (40 rows)")
    e2e_assert_eq(sql_select_first_where_eq(db3, 24, 0, 1, 1), 100, "Post-checkpoint row 1 value == 100")
    e2e_assert_eq(sql_select_cell(db3, 26, 0, 0), 77777, "Post-checkpoint 1-column row intact (77777)")
    e2e_assert_eq(sql_select_cell(db3, 27, 0, 3), 4444, "Post-checkpoint 4th column intact (4444)")
    sql_engine_close(db3)
    e2e_unlink(sql_wal)
    e2e_unlink(sql_wal + ".tmp")

    // =========================================================================
    // PILLAR 5: Crash-Safe Job Queue CRC-32 WAL + Recovery & Compaction
    // =========================================================================
    say "\n▶ Pillar 5: Crash-Safe Job Queue CRC-32 WAL & Auto-Recovery..."

    jq_wal = "/tmp/lipi_e2e_jq.wal"
    e2e_unlink(jq_wal)
    e2e_unlink(jq_wal + ".tmp")

    jq1 = job_queue_engine_open(jq_wal)
    job_queue_enqueue(jq1, 101, "invoice_paid", "acct=1", 1000, 3)
    job_queue_enqueue(jq1, 102, "deploy_edge", "region=dhk", 1000, 3)
    job_queue_enqueue(jq1, 103, "webhook_retry", "hook=9", 1000, 1)

    j101 = job_queue_poll_ready(jq1, 1005)
    e2e_assert_eq(j101.bj_id, 101, "Polled job 101")
    job_queue_complete(jq1, 101)

    // Poll 102 -> RUNNING, then simulate process crash BEFORE completion
    j102 = job_queue_poll_ready(jq1, 1005)
    e2e_assert_eq(j102.bj_id, 102, "Polled job 102 -> RUNNING before crash")
    job_queue_fail_retry(jq1, 103, 1006, 5)
    job_queue_close(jq1)

    // Inject 7-byte torn tail corruption
    e2e_append_garbage(jq_wal, 7)

    jq2 = job_queue_engine_open(jq_wal)
    r101 = job_queue_find_job(jq2, 101)
    r102 = job_queue_find_job(jq2, 102)
    r103 = job_queue_find_job(jq2, 103)
    e2e_assert_eq(r101.bj_status, JOB_STATUS_COMPLETED, "Job 101 remained COMPLETED across WAL recovery")
    e2e_assert_eq(r103.bj_status, JOB_STATUS_DEAD, "Job 103 remained DEAD (DLQ) across WAL recovery")
    e2e_assert_eq(r102.bj_status, JOB_STATUS_PENDING, "Crashed RUNNING job 102 auto-recovered to PENDING")

    polled_again = job_queue_poll_ready(jq2, 1050)
    e2e_assert_eq(polled_again.bj_id, 102, "Re-polled recovered job 102 cleanly")
    job_queue_complete(jq2, 102)
    job_queue_checkpoint(jq2)
    job_queue_close(jq2)

    jq3 = job_queue_engine_open(jq_wal)
    c102 = job_queue_find_job(jq3, 102)
    e2e_assert_eq(c102.bj_status, JOB_STATUS_COMPLETED, "Compacted checkpoint persisted job 102 == COMPLETED")
    job_queue_close(jq3)
    e2e_unlink(jq_wal)
    e2e_unlink(jq_wal + ".tmp")

    say "\n========================================================================"
    say "🎉 ALL FIVE SOVEREIGN PILLARS END-TO-END TESTS PASSED! 🎉"
    say "========================================================================"
    return 0

main()
