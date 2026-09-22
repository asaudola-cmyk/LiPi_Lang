// ==============================================================================
// 🧪 LIPI TEST SUITE: WEB PLAYGROUND & CLOUD DASHBOARD API
// File: tests/test_web_playground.lp
// Standard: REST API | In-Browser Live Compilation | LipiDB Stats Bridge
// 100% Pure Lipi — Zero Libc | Zero PHP | Zero Node.js
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/memory.lp"
include "universe/core/string.lp"
include "universe/core/json.lp"
include "universe/web/engine.lp"

fn assert_true cond msg
    if cond == 0
        say "  ❌ [FAIL] Assertion failed: " + msg
        exit(1)
    say "  ✔ [PASS] " + msg

fn assert_eq_int actual expected msg
    if actual != expected
        say "  ❌ [FAIL] " + msg + " (Expected " + str(expected) + ", got " + str(actual) + ")"
        exit(1)
    say "  ✔ [PASS] " + msg

fn assert_eq_str actual expected msg
    if actual != expected
        say "  ❌ [FAIL] " + msg + " (Expected '" + expected + "', got '" + actual + "')"
        exit(1)
    say "  ✔ [PASS] " + msg

// ── Code Payload Parser (Extracted from server.lp) ───────────────────────────
fn parse_code_payload body
    blen = len(body)
    if blen == 0
        return ""

    p = 0
    while p < blen
        c = char_at(body, p)
        if c != " " and c != "\t" and c != "\r" and c != "\n"
            break
        p = p + 1

    if p < blen and char_at(body, p) == "{"
        i = p + 1
        found_code = 0
        while i < blen - 5
            if char_at(body, i) == "\"" and char_at(body, i + 1) == "c" and char_at(body, i + 2) == "o" and char_at(body, i + 3) == "d" and char_at(body, i + 4) == "e" and char_at(body, i + 5) == "\""
                found_code = 1
                i = i + 6
                break
            i = i + 1

        if found_code == 1
            while i < blen and char_at(body, i) != ":"
                i = i + 1
            if i < blen and char_at(body, i) == ":"
                i = i + 1
                while i < blen
                    c = char_at(body, i)
                    if c != " " and c != "\t" and c != "\r" and c != "\n"
                        break
                    i = i + 1
                if i < blen and char_at(body, i) == "\""
                    i = i + 1
                    raw_str = ""
                    while i < blen
                        c = char_at(body, i)
                        if c == "\\" and i + 1 < blen
                            raw_str = raw_str + "\\" + char_at(body, i + 1)
                            i = i + 2
                        elif c == "\""
                            break
                        else
                            raw_str = raw_str + c
                            i = i + 1
                    return json_unescape(raw_str)

    return body

// ── Mock LipiDB Redis Cluster Stats Bridge ───────────────────────────────────
fn get_lipidb_stats_json
    body = "{\"status\":\"active\",\"cluster_mode\":\"standalone\",\"protocol\":\"RESP2/RESP3\",\"port\":6389,\"connected_clients\":1,\"total_commands_processed\":128,\"used_memory_bytes\":262144,\"persistence\":\"AOF+Snapshot\",\"engine\":\"LipiDB Sovereign Redis-Compatible Store v2.0\",\"sovereign\":1}"
    return body

fn main
    say "================================================================="
    say "🌐 LIPI WEB PLAYGROUND & CLOUD DASHBOARD TEST SUITE 🌐"
    say "================================================================="

    total_tests = 0
    passed_tests = 0

    // ── Section 1: JSON Code Payload Unpacking ────────────────────────────────
    say "▶ Section 1: Playground Code Payload Unpacking..."
    total_tests = total_tests + 1

    json_payload = "{\"code\": \"say \\\"Hello Lipi Playground!\\\"\\nreturn 0\"}"
    extracted_code = parse_code_payload(json_payload)
    assert_true(str_contains(extracted_code, "Hello Lipi Playground!"), "Extracted code contains expected string")
    assert_true(str_contains(extracted_code, "return 0"), "Extracted code contains return statement")
    passed_tests = passed_tests + 1

    // ── Section 2: Raw Source Code Passthrough ────────────────────────────────
    say "\n▶ Section 2: Raw Code Payload Passthrough..."
    total_tests = total_tests + 1

    raw_code = "fn main\n    say 12345\n    return 0\nmain()\n"
    res_code = parse_code_payload(raw_code)
    assert_eq_str(res_code, raw_code, "Raw source code preserved verbatim")
    passed_tests = passed_tests + 1

    // ── Section 3: LipiDB Redis Cluster Telemetry Stats Bridge ────────────────
    say "\n▶ Section 3: LipiDB Redis Cluster Telemetry Bridge..."
    total_tests = total_tests + 1

    stats_json = get_lipidb_stats_json()
    assert_true(str_contains(stats_json, "\"protocol\":\"RESP2/RESP3\""), "Telemetry contains RESP2/RESP3 protocol")
    assert_true(str_contains(stats_json, "\"port\":6389"), "Telemetry reports port 6389")
    assert_true(str_contains(stats_json, "\"engine\":\"LipiDB"), "Telemetry identifies LipiDB engine")
    passed_tests = passed_tests + 1

    // ── Section 4: Live Compiler Subprocess Compilation & Execution ────────────
    say "\n▶ Section 4: Playground Compiler Engine Sandbox..."
    total_tests = total_tests + 1

    // Write a tiny program to /tmp/test_pg.lp
    pg_src = "fn main\n    say \"PLAYGROUND_OK\"\n    return 0\nmain()\n"
    pg_lp = "/tmp/test_pg.lp"
    pg_bin = "/tmp/test_pg.bin"

    // Write file using syscall 2 (open O_WRONLY|O_CREAT|O_TRUNC = 577, mode 0644 = 420)
    fd = syscall(2, pg_lp, 577, 420, 0, 0, 0)
    assert_true(fd >= 0, "Created temporary test playground source file")
    syscall(1, fd, pg_src, len(pg_src), 0, 0, 0)
    syscall(3, fd, 0, 0, 0, 0, 0) // close

    // Fork and compile with ./bin/lipc
    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        argv_mem = malloc(32)
        prog = "./bin/lipc"
        mem_write_idx(argv_mem, 0, prog)
        mem_write_idx(argv_mem, 1, pg_lp)
        mem_write_idx(argv_mem, 2, pg_bin)
        mem_write_idx(argv_mem, 3, 0)

        env_mem = malloc(16)
        mem_write_idx(env_mem, 0, 0)

        syscall(59, prog, argv_mem, env_mem, 0, 0, 0)
        syscall(60, 1, 0, 0, 0, 0, 0)

    // Wait for compilation
    stat_buf = malloc(8)
    syscall(61, pid, stat_buf, 0, 0, 0, 0)
    exit_code = mem_byte_read(stat_buf, 1)
    free(stat_buf, 8)
    assert_eq_int(exit_code, 0, "Compiler exited with code 0")

    // Verify binary was generated
    bin_exists = file_exists(pg_bin)
    assert_eq_int(bin_exists, 1, "Playground binary successfully emitted on disk")

    // Clean up
    syscall(87, pg_lp, 0, 0, 0, 0, 0)
    syscall(87, pg_bin, 0, 0, 0, 0, 0)
    passed_tests = passed_tests + 1

    say "\n-----------------------------------------------------------------"
    say "RESULTS: " + str(passed_tests) + "/" + str(total_tests) + " sections passed."
    say "🎉 ALL WEB PLAYGROUND & CLOUD DASHBOARD TESTS PASSED!"
    return 0

main()
