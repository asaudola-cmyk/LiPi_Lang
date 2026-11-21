// ==============================================================================
// 🛡️ LIPI SOVEREIGN DEEP AUDIT MASTER REGRESSION & CONCURRENCY STRESS SUITE
// File: tests/test_deep_audit_master.lp
// ⚡ Verifies M1–M6 End-to-End Hardening & Law 4 Concurrency Mandate:
//    1. Compiler String-Concat Type Propagation & Signed 64-bit Semantics
//    2. Slab 1-Arg Free Recycler + 8-Thread × 2,000-Op (16,000 Ops) Atomic Stress
//    3. Post-Quantum Cryptography: NIST ML-KEM-512 (FIPS 203) & ML-DSA-44 (FIPS 204)
//    4. LipiDB End-to-End SQL Engine (Floats, Escaped Quotes, !=, <>, WHERE, DELETE)
//    5. LipiWeb Onion Middleware, Multi-Set-Cookie, CRLF Strip, Static 403, JWT nbf/exp
//    6. LipiFS Multi-Block (>4KB) CoW, Binary SHA-256 Merkle Tree & Disk Sync/Load
// ==============================================================================

include "utso/os/thread.lp"
include "utso/crypto/crypto.lp"
include "utso/crypto/pqc.lp"
import "aati/lipidb/sql/executor"
import "aati/lipi_web/context"
import "aati/lipi_web/middleware"
import "aati/lipi_web/auth/jwt"
import "aati/lipi_fs/lipifs"

fn dam_assert cond label
    if cond == 0
        say "  ❌ [FAIL] " + label
        exit(1)
    end
    say "  ✔ [PASS] " + label
    return 1

// WHY: Law 4 thread-safe worker executing 2,000 hardware-atomic spinlock-guarded increments
// Contract: shared_state[0..7] = hardware spinlock (lock bts/btr), shared_state[8..15] = i64 counter.
// Proof of deadlock freedom: single global lock with strict acquire -> increment -> release ordering.
fn dam_conc_worker shared_state
    k = 0
    while k < 2000
        spinlock_lock(shared_state)
        cur = mem_read(shared_state, 8)
        mem_write(shared_state, 8, cur + 1)
        spinlock_unlock(shared_state)
        k = k + 1
    end
    return 0

@fn _dam_mw_outer(ctx)
    ctx_set(ctx, "order", "A")
    ctx_next(ctx)
    ctx_set(ctx, "order", ctx_get(ctx, "order", "") + "C")
    return 0
@end

@fn _dam_mw_inner(ctx)
    ctx_set(ctx, "order", ctx_get(ctx, "order", "") + "B")
    ctx_text(ctx, 200, "ok")
    return 0
@end

fn main
    say "========================================================================"
    say "👑 LIPI SOVEREIGN DEEP AUDIT MASTER SUITE (M1–M6 + LAW 4 CONCURRENCY)"
    say "========================================================================"

    // ── Section 1: Compiler String-Concat Type Propagation & Signed 64-bit ───
    h_tag = sha256_hex("lipi") + ":ok"
    dam_assert(len(h_tag) == 67 and str_sub(h_tag, 64, 67) == ":ok", "1. sha256_hex string-concat type propagation (len == 67)")
    neg_v = 0 - 5
    dam_assert((neg_v >> 0) == (0 - 5) and ((0 - 100) / 4) == (0 - 25), "1b. Signed 64-bit negative arithmetic & shifts")

    // ── Section 2: Slab 1-Arg Free & Law 4 8-Thread × 2,000-Op Stress ────────
    si = 0
    while si < 200
        blk = alloc(64)
        mem_write(blk, 0, si * 7)
        if mem_read(blk, 0) != si * 7
            say "  ❌ [FAIL] slab read/write mismatch"
            exit(1)
        end
        free(blk)
        si = si + 1
    end
    dam_assert(1, "2a. 200-round 1-arg free() slab allocation & recycling")

    shared_state = malloc(16)
    mem_write(shared_state, 0, 0)
    mem_write(shared_state, 8, 0)
    handles = list()
    ti = 0
    while ti < 8
        h = thread_spawn_joinable(&dam_conc_worker, shared_state, 65536)
        if h == 0
            say "  ❌ [FAIL] thread_spawn_joinable returned 0"
            exit(1)
        end
        push(handles, h)
        ti = ti + 1
    end
    ti = 0
    while ti < 8
        if thread_join(handles[ti]) != 1
            say "  ❌ [FAIL] thread_join failed"
            exit(1)
        end
        ti = ti + 1
    end
    final_cnt = mem_read(shared_state, 8)
    free(shared_state, 16)
    dam_assert(final_cnt == 16000, "2b. Law 4 Concurrency Stress: 8 OS threads × 2,000 ops == 16,000 exact")

    // ── Section 3: Post-Quantum Cryptography (ML-KEM-512 & ML-DSA-44) ────────
    kem_kp = mlkem512_keygen()
    kem_pk = get(kem_kp, 0)
    kem_sk = get(kem_kp, 1)
    kem_enc = mlkem512_encaps(kem_pk)
    kem_ct = get(kem_enc, 0)
    kem_ss1 = get(kem_enc, 1)
    kem_ss2 = mlkem512_decaps(kem_sk, kem_ct)
    kem_match = 1
    if len(kem_ss1) != 32 or len(kem_ss2) != 32
        kem_match = 0
    else
        ki = 0
        while ki < 32
            if get(kem_ss1, ki) != get(kem_ss2, ki)
                kem_match = 0
            end
            ki = ki + 1
        end
    end
    dam_assert(kem_match == 1, "3a. NIST FIPS 203 ML-KEM-512 keygen/encaps/decaps 32-byte shared secret")

    dsa_kp = mldsa_keygen()
    dsa_pk = get(dsa_kp, 0)
    dsa_sk = get(dsa_kp, 1)
    dsa_msg = [76, 105, 80, 105, 45, 80, 81, 67]
    dsa_bad = [76, 105, 80, 105, 45, 66, 65, 68]
    dsa_sig = mldsa_sign(dsa_sk, dsa_msg)
    dsa_ok = mldsa_verify(dsa_pk, dsa_msg, dsa_sig)
    dsa_rej = mldsa_verify(dsa_pk, dsa_bad, dsa_sig)
    dam_assert(dsa_ok == 1 and dsa_rej == 0, "3b. NIST FIPS 204 ML-DSA-44 sign/verify & tamper rejection")

    // ── Section 4: LipiDB SQL Engine (Floats, Escapes, !=, <>, DELETE) ───────
    ectx = new_executor_context()
    sql_execute(ectx, "CREATE TABLE items (id INT, title TEXT, price FLOAT);")
    sql_execute(ectx, "INSERT INTO items VALUES (1, 'O''Reilly Lipi', 19.99);")
    sql_execute(ectx, "INSERT INTO items VALUES (2, 'Cheap', 4.50);")
    sql_execute(ectx, "INSERT INTO items VALUES (3, 'Premium', 49.95);")
    sel = sql_execute(ectx, "SELECT title, price FROM items WHERE price > 10.0 AND id != 3;")
    del = sql_execute(ectx, "DELETE FROM items WHERE id <> 1;")
    dam_assert(sel.sres_ok == 1 and sel.sres_rows.len() == 1 and sql_row_get(sel.sres_rows[0], "title") == "O'Reilly Lipi" and del.sres_affected == 2, "4. LipiDB SQL end-to-end CREATE/INSERT/SELECT WHERE/DELETE")

    // ── Section 5: LipiWeb Onion Middleware, Multi-Cookie, CRLF, Static, JWT ─
    wctx = http_context_new(req_new("GET", "/ok", [], "", "127.0.0.1"), res_new())
    pipeline_run([_dam_mw_outer, _dam_mw_inner], wctx)
    dam_assert(ctx_get(wctx, "order", "") == "ABC", "5a. LipiWeb onion middleware ctx_next progression (ABC)")

    wres = res_new()
    res_header(wres, "X-Test", "ok\r\nX-Injected: bad")
    res_cookie(wres, "sid", "111", 60, "/", 1, 1)
    res_cookie(wres, "pref", "dark", 60, "/", 0, 1)
    wwire = res_format_http(wres)
    dam_assert(contains(wwire, "\r\nX-Injected:") == 0 and contains(wwire, "Set-Cookie: sid=111") == 1 and contains(wwire, "Set-Cookie: pref=dark") == 1, "5b. LipiWeb CRLF stripping & RFC 6265 multi Set-Cookie headers")

    mw_st = middleware_static("/tmp", "/static")
    trav_ctx = http_context_new(req_new("GET", "/static/%2e%2e/etc/passwd", [], "", "127.0.0.1"), res_new())
    pipeline_run([mw_st], trav_ctx)
    dam_assert(trav_ctx.ctx_res.res_status_code == 403 and web_html_escape("<b>") == "&lt;b&gt;", "5c. LipiWeb encoded traversal 403 defense & HTML escaping")

    jtok = jwt_sign_payload("{\"alg\":\"HS256\",\"typ\":\"JWT\"}", "{\"sub\":\"u1\",\"nbf\":2000,\"exp\":3000}", "master_sec")
    dam_assert(jwt_verify_at(jtok, "master_sec", 1500) == 0 and jwt_verify_at(jtok, "master_sec", 2500) == 1 and jwt_verify_at(jtok, "master_sec", 3500) == 0, "5d. LipiWeb JWT nbf/exp temporal enforcement")

    // ── Section 6: LipiFS Multi-Block (>4KB) CoW, Merkle Tree & Disk Sync ────
    big_payload = ""
    bi = 0
    while bi < 1000
        big_payload = big_payload + "0123456789"
        bi = bi + 1
    end
    fs = lipifs_create(0 - 1, 256)
    fs = lipifs_write_file_cow(fs, "kernel.bin", big_payload)
    m_root1 = fs.merkle_tree_root
    fs = lipifs_write_file_cow(fs, "meta.txt", "sovereign_v1")
    m_root2 = fs.merkle_tree_root
    dam_assert(lipifs_read_file(fs, "kernel.bin") == big_payload and len(big_payload) == 10000 and m_root1 != m_root2, "6a. LipiFS 10KB multi-block (>4KB) CoW & Merkle root update")

    img_path = "/tmp/dam_lipifs_master.img"
    fd = sys_open(img_path, 578, 420)
    dam_assert(fd >= 0 and lipifs_sync(fs, fd) == 1, "6b. LipiFS persistent disk sync")
    fs_reloaded = lipifs_load(fd)
    sys_close(fd)
    syscall(87, img_path, 0, 0, 0, 0, 0)
    dam_assert(lipifs_read_file(fs_reloaded, "kernel.bin") == big_payload and lipifs_read_file(fs_reloaded, "meta.txt") == "sovereign_v1" and fs_reloaded.merkle_tree_root == m_root2, "6c. LipiFS disk reload & SHA-256 Merkle verification")

    say "========================================================================"
    say "🎉 ALL SOVEREIGN DEEP AUDIT MASTER CHECKS PASSED (100%)"
    say "========================================================================"
    return 0

main()
