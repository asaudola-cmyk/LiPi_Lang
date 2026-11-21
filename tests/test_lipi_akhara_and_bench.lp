// ==============================================================================
// REGRESSION TEST: LIPI AKHARA HTTP/ELF STUDIO, LSP DIAGNOSTICS, & TRUTH BENCH
// ==============================================================================
// Verifies end-to-end:
//   1. `bin/lipi_akhara --selftest` passes.
//   2. `bin/lipi_akhara --oneshot-http <port> 2` serves GET /health and POST /api/run
//      via direct Linux TCP sockets with live bare-silicon compilation + ELF audit.
//   3. `bin/lipilsp` JSON-RPC handles initialize (documentSymbolProvider), live
//      unterminated-string diagnostic -> clean diagnostic clear, & documentSymbol.
//   4. `benchmarks/sovereign_truth_bench.lp --quick` passes cleanly with 0 heap leak.

include "utso/io"
include "utso/string"

fn ab_resolve_bin name
    p = "bin/" + name
    if syscall(21, p, 0, 0, 0, 0, 0) == 0
        return p
    return name

fn ab_write_file path content
    fd = syscall(2, path, 577, 420, 0, 0, 0)
    if fd < 0
        return 0 - 1
    syscall(1, fd, content, len(content), 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 0

fn ab_sleep_20ms
    ts = malloc(16)
    mem_write(ts, 0, 0)
    mem_write(ts, 8, 20000000)
    syscall(35, ts, 0, 0, 0, 0, 0)
    syscall(11, ts, 16, 0, 0, 0, 0)

fn ab_exec_sync exe a1 a2 a3 log_path
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
    if len(a3) > 0
        mem_write(argv, idx * 8, a3)
        idx = idx + 1
    mem_write(argv, idx * 8, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        cfd = syscall(2, log_path, 577, 420, 0, 0, 0)
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

fn ab_http_roundtrip port payload retry_connect
    sa = malloc(16)
    i = 0
    while i < 16
        mem_byte_write(sa, i, 0)
        i = i + 1
    mem_byte_write(sa, 0, 2)
    mem_byte_write(sa, 1, 0)
    mem_byte_write(sa, 2, (port / 256) % 256)
    mem_byte_write(sa, 3, port % 256)
    mem_byte_write(sa, 4, 127)
    mem_byte_write(sa, 5, 0)
    mem_byte_write(sa, 6, 0)
    mem_byte_write(sa, 7, 1)

    cfd = 0 - 1
    tries = 0
    max_tries = 1
    if retry_connect == 1
        max_tries = 150
    while tries < max_tries
        sock = syscall(41, 2, 1, 0, 0, 0, 0)
        if sock >= 0
            rc = syscall(42, sock, sa, 16, 0, 0, 0)
            if rc == 0
                cfd = sock
                break
            syscall(3, sock, 0, 0, 0, 0, 0)
        ab_sleep_20ms()
        tries = tries + 1

    syscall(11, sa, 16, 0, 0, 0, 0)
    if cfd < 0
        return ""

    syscall(1, cfd, payload, len(payload), 0, 0, 0)

    rbuf = malloc(16384)
    total = 0
    while total < 16383
        n = syscall(0, cfd, rbuf + total, 16383 - total, 0, 0, 0)
        if n <= 0
            break
        total = total + n
    syscall(3, cfd, 0, 0, 0, 0, 0)

    out = ""
    k = 0
    while k < total
        out = out + chr(mem_byte_read(rbuf, k))
        k = k + 1
    syscall(11, rbuf, 16384, 0, 0, 0, 0)
    return out

fn ab_rpc_frame body_str
    return "Content-Length: " + str(len(body_str)) + "\r\n\r\n" + body_str

fn main
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    akh_bin = ab_resolve_bin("lipi_akhara")
    lsp_bin = ab_resolve_bin("lipilsp")
    comp_bin = ab_resolve_bin("lipc")
    if syscall(21, comp_bin, 0, 0, 0, 0, 0) != 0
        comp_bin = ab_resolve_bin("lipc_bin")

    // 1. Akhara internal selftest
    sel_log = "/tmp/ab_sel_" + str(pid) + ".log"
    c1 = ab_exec_sync(akh_bin, "--selftest", "", "", sel_log)
    out1 = file_read(sel_log)
    syscall(87, sel_log, 0, 0, 0, 0, 0)
    if c1 != 0 or str_contains(out1, "AKHARA_SELFTEST_COMPLETE") != 1
        say "[ERR] lipi_akhara --selftest did not succeed"
        return 1
    say "[PASS] lipi_akhara --selftest verified"

    // 2. Akhara live HTTP server (--oneshot-http <port> 2)
    port = 18300 + (pid % 1000)
    srv_log = "/tmp/ab_srv_" + str(pid) + ".log"
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
    mem_write(argv, 0, akh_bin)
    mem_write(argv, 8, "--oneshot-http")
    mem_write(argv, 16, str(port))
    mem_write(argv, 24, "2")
    mem_write(argv, 32, 0)

    srv_pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if srv_pid == 0
        sfd = syscall(2, srv_log, 577, 420, 0, 0, 0)
        if sfd >= 0
            syscall(33, sfd, 1, 0, 0, 0, 0)
            syscall(33, sfd, 2, 0, 0, 0, 0)
            syscall(3, sfd, 0, 0, 0, 0, 0)
        syscall(59, akh_bin, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    r_health = ab_http_roundtrip(port, "GET /health HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n", 1)
    if str_contains(r_health, "200 OK") != 1 or str_contains(r_health, "lipi_akhara") != 1
        say "[ERR] Akhara /health unexpected response"
        syscall(61, srv_pid, st, 0, 0, 0, 0)
        syscall(87, srv_log, 0, 0, 0, 0, 0)
        return 1

    json_body = "{\"code\":\"fn main\\n  say \\\"HTTP_SILICON_WIN\\\"\\n  return 0\\n\\nmain()\",\"kavach\":true}"
    post_req = "POST /api/run HTTP/1.1\r\nHost: localhost\r\nContent-Type: application/json\r\nContent-Length: " + str(len(json_body)) + "\r\nConnection: close\r\n\r\n" + json_body
    r_run = ab_http_roundtrip(port, post_req, 1)
    syscall(61, srv_pid, st, 0, 0, 0, 0)
    syscall(11, argv, 64, 0, 0, 0, 0)
    syscall(11, env, 16, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    syscall(87, srv_log, 0, 0, 0, 0, 0)

    if str_contains(r_run, "HTTP_SILICON_WIN") != 1 or str_contains(r_run, "ET_DYN") != 1
        say "[ERR] Akhara POST /api/run did not execute or return ELF telemetry"
        return 1
    say "[PASS] lipi_akhara HTTP /health + /api/run socket & ELF audit verified"

    // 3. lipilsp JSON-RPC diagnostics & documentSymbol verification (file-backed zero-deadlock pipe)
    lsp_in = "/tmp/ab_lsp_in_" + str(pid) + ".rpc"
    lsp_out = "/tmp/ab_lsp_out_" + str(pid) + ".rpc"
    rpc = ab_rpc_frame("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{}}")
    rpc = rpc + ab_rpc_frame("{\"jsonrpc\":\"2.0\",\"method\":\"initialized\",\"params\":{}}")
    rpc = rpc + ab_rpc_frame("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didOpen\",\"params\":{\"textDocument\":{\"uri\":\"file:///t.lp\",\"text\":\"fn broken_fn\\n  s = \\\"hello\\n  return 0\"}}}")
    rpc = rpc + ab_rpc_frame("{\"jsonrpc\":\"2.0\",\"method\":\"textDocument/didChange\",\"params\":{\"textDocument\":{\"uri\":\"file:///t.lp\"},\"contentChanges\":[{\"text\":\"fn sym_alpha\\n  return 1\"}]}}")
    rpc = rpc + ab_rpc_frame("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"textDocument/documentSymbol\",\"params\":{\"textDocument\":{\"uri\":\"file:///t.lp\"}}}")
    rpc = rpc + ab_rpc_frame("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"shutdown\",\"params\":null}")
    rpc = rpc + ab_rpc_frame("{\"jsonrpc\":\"2.0\",\"method\":\"exit\",\"params\":null}")
    ab_write_file(lsp_in, rpc)

    l_argv = malloc(32)
    l_env = malloc(16)
    l_st = malloc(8)
    mem_write(l_argv, 0, lsp_bin)
    mem_write(l_argv, 8, 0)
    mem_write(l_env, 0, 0)
    mem_write(l_env, 8, 0)
    mem_write(l_st, 0, 0)

    lpid = syscall(57, 0, 0, 0, 0, 0, 0)
    if lpid == 0
        ifd = syscall(2, lsp_in, 0, 0, 0, 0, 0)
        ofd = syscall(2, lsp_out, 577, 420, 0, 0, 0)
        if ifd >= 0
            syscall(33, ifd, 0, 0, 0, 0, 0)
            syscall(3, ifd, 0, 0, 0, 0, 0)
        if ofd >= 0
            syscall(33, ofd, 1, 0, 0, 0, 0)
            syscall(33, ofd, 2, 0, 0, 0, 0)
            syscall(3, ofd, 0, 0, 0, 0, 0)
        syscall(59, lsp_bin, l_argv, l_env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(61, lpid, l_st, 0, 0, 0, 0)
    syscall(11, l_argv, 32, 0, 0, 0, 0)
    syscall(11, l_env, 16, 0, 0, 0, 0)
    syscall(11, l_st, 8, 0, 0, 0, 0)
    lsp_resp = file_read(lsp_out)
    syscall(87, lsp_in, 0, 0, 0, 0, 0)
    syscall(87, lsp_out, 0, 0, 0, 0, 0)

    if str_contains(lsp_resp, "\"documentSymbolProvider\":true") != 1 or str_contains(lsp_resp, "Unterminated string literal") != 1 or str_contains(lsp_resp, "\"diagnostics\":[]") != 1 or str_contains(lsp_resp, "sym_alpha") != 1
        say "[ERR] lipilsp diagnostics or documentSymbol unexpected output"
        return 1
    say "[PASS] lipilsp diagnostics + documentSymbolProvider verified"

    // 4. sovereign_truth_bench.lp --quick verification
    b_bin = "/tmp/ab_bench_" + str(pid) + ".elf"
    b_clog = "/tmp/ab_bclog_" + str(pid) + ".log"
    b_rlog = "/tmp/ab_brlog_" + str(pid) + ".log"
    bc = ab_exec_sync(comp_bin, "benchmarks/sovereign_truth_bench.lp", b_bin, "", b_clog)
    syscall(87, b_clog, 0, 0, 0, 0, 0)
    if bc != 0
        syscall(87, b_bin, 0, 0, 0, 0, 0)
        say "[ERR] sovereign_truth_bench compilation issue"
        return 1
    br = ab_exec_sync(b_bin, "--quick", "", "", b_rlog)
    bout = file_read(b_rlog)
    syscall(87, b_bin, 0, 0, 0, 0, 0)
    syscall(87, b_rlog, 0, 0, 0, 0, 0)
    if br != 0 or str_contains(bout, "SOVEREIGN_TRUTH_BENCH_OK") != 1
        say "[ERR] sovereign_truth_bench --quick execution issue"
        return 1
    say "[PASS] benchmarks/sovereign_truth_bench.lp --quick verified (Tier I + Tier II + 0 heap delta)"
    say "✅ TEST_LIPI_AKHARA_AND_BENCH_COMPLETE"
    return 0

main()
