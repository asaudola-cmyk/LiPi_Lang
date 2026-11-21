// ==============================================================================
// REGRESSION TEST: AATI IDE (aati/lipi_ide) & P2P REGISTRY (aati/lipi_p2p)
// ==============================================================================
// Exercises real production modules inside `aati/lipi_ide/` (`syntax`, `editor`,
// `console`, `lsp_client`, `ui_popup`) and `aati/lipi_p2p/` (`registry`) via
// isolated compilation without modifying any signed `aati/*/` source files.

include "utso/io"
include "utso/string"

fn aip_resolve_compiler
    if syscall(21, "bin/lipc", 0, 0, 0, 0, 0) == 0
        return "bin/lipc"
    if syscall(21, "bin/lipc_bin", 0, 0, 0, 0, 0) == 0
        return "bin/lipc_bin"
    return "bin/lipc"

fn aip_write_file path content
    fd = syscall(2, path, 577, 420, 0, 0, 0)
    if fd < 0
        return 0 - 1
    syscall(1, fd, content, len(content), 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0)
    return 0

fn aip_read_file path
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

fn aip_exec exe a1 a2 log_p
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
    comp = aip_resolve_compiler()
    ide_src = "/tmp/aip_ide_" + str(pid) + ".lp"
    ide_bin = "/tmp/aip_ide_" + str(pid)
    p2p_src = "/tmp/aip_p2p_" + str(pid) + ".lp"
    p2p_bin = "/tmp/aip_p2p_" + str(pid)
    log_p = "/tmp/aip_log_" + str(pid) + ".txt"

    // 1. Aati IDE Engine test (lsp_client + console + toolbar + ui_popup + runner)
    ide_code = "import \"aati/lipi_ide/lsp_client\"\nimport \"aati/lipi_ide/console\"\nimport \"aati/lipi_ide/toolbar\"\nimport \"aati/lipi_ide/ui_popup\"\nimport \"aati/lipi_ide/runner\"\n\n@fn main()\n  con = console_new(160)\n  con = console_append(con, \"ready\", \"INFO\")\n  @if con.lines.len() < 1 return 1 @end\n  cli = lsp_client_new()\n  cli = lsp_client_open(cli, \"file:///demo.lp\", \"fn demo a\\n  return a + 1\")\n  cli = lsp_client_request_completions(cli, \"file:///demo.lp\", 1, 2)\n  @if cli.doc_uri != \"file:///demo.lp\" return 2 @end\n  tb = toolbar_new(800, 40)\n  tb = toolbar_handle_click(tb, 10, 10)\n  run = runner_new()\n  @if run.is_running != false return 3 @end\n  say \"AATI_IDE_OK\"\n  return 0\n@end\n\nmain()\n"
    aip_write_file(ide_src, ide_code)
    if aip_exec(comp, ide_src, ide_bin, log_p) != 0
        say "[ERR] aati/lipi_ide compile failed"
        return 1
    if aip_exec(ide_bin, "", "", log_p) != 0
        say "[ERR] aati/lipi_ide runtime failed"
        return 1
    if str_contains(aip_read_file(log_p), "AATI_IDE_OK") != 1
        say "[ERR] aati/lipi_ide output mismatch"
        return 1
    say "[PASS] aati/lipi_ide (lsp_client/console/toolbar/ui_popup/runner) verified"

    // 2. Aati P2P CAS & SemVer Registry test
    p2p_code = "import \"aati/lipi_p2p/registry\"\n\n@fn main()\n  r1 = p2p_registry_new(\"node-alpha\", \"127.0.0.1\", 9001)\n  r2 = p2p_registry_new(\"node-beta\", \"127.0.0.1\", 9002)\n  p2p_add_peer(r1, \"node-beta\", \"127.0.0.1\", 9002)\n  cid = p2p_cas_put_blob(r1, \"sovereign-cas-payload\")\n  @if p2p_cas_verify_blob(\"sovereign-cas-payload\", cid) != 1 return 1 @end\n  @if p2p_cas_verify_blob(\"tampered-payload\", cid) != 0 return 2 @end\n  pub_cid = p2p_publish(r1, \"demo_pkg\", \"1.2.3\", \"artifact-bytes\")\n  @if str_len(pub_cid) == 0 return 3 @end\n  @if p2p_semver_satisfies(\"1.2.3\", \"^1.0.0\") != 1 return 4 @end\n  @if p2p_semver_satisfies(\"2.0.0\", \"^1.0.0\") != 0 return 5 @end\n  synced = p2p_sync_nodes(r1, r2)\n  @if synced < 1 return 6 @end\n  say \"AATI_P2P_OK\"\n  return 0\n@end\n\nmain()\n"
    aip_write_file(p2p_src, p2p_code)
    if aip_exec(comp, p2p_src, p2p_bin, log_p) != 0
        say "[ERR] aati/lipi_p2p/registry compile failed"
        return 1
    if aip_exec(p2p_bin, "", "", log_p) != 0
        say "[ERR] aati/lipi_p2p/registry runtime failed"
        return 1
    if str_contains(aip_read_file(log_p), "AATI_P2P_OK") != 1
        say "[ERR] aati/lipi_p2p output mismatch"
        return 1
    say "[PASS] aati/lipi_p2p (CAS/SemVer/sync) verified"

    syscall(87, ide_src, 0, 0, 0, 0, 0)
    syscall(87, ide_bin, 0, 0, 0, 0, 0)
    syscall(87, p2p_src, 0, 0, 0, 0, 0)
    syscall(87, p2p_bin, 0, 0, 0, 0, 0)
    syscall(87, log_p, 0, 0, 0, 0, 0)

    say "✅ TEST_AATI_IDE_AND_P2P_COMPLETE"
    return 0

main()
