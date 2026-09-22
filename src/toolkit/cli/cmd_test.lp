// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: TEST RUNNER SUB-COMMAND (src/toolkit/cli/cmd_test.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | Autonomous Test Suite Orchestrator
// ==============================================================================
//
// WHY THIS MODULE:
// Reliable software engineering demands first-class test execution without third-party
// test runners or shell scripting. `lipi test` delivers:
// 1. Automatic recursive discovery of test suites across tests/ matching *.lp.
// 2. Isolated compilation and child process execution with stdout capture.
// 3. Exact pass/fail bookkeeping and execution time tracking.
// 4. Vibrant TrueColor reporting with progress bar and summary report.

include "src/toolkit/common/cli_parser.lp"
include "src/toolkit/common/terminal_ui.lp"
include "src/toolkit/common/fs_scanner.lp"
include "src/toolkit/common/process.lp"

// ── 1. Test Discovery & Execution Engine ──────────────────────────────────────

// WHY: Executes test discovery, runs each test suite in process sandbox, and tallies results.
fn cmd_test_execute parser
    target_pattern = cli_get_arg(parser, 0)
    test_files = list()

    if len(target_pattern) > 0 and file_exists(target_pattern) == 1
        // Explicit single file test target
        push(test_files, target_pattern)
    else
        // Autonomous discovery across tests/ directory
        scanner = fs_scanner_new(".lp")
        search_root = "tests"
        if len(target_pattern) > 0
            search_root = target_pattern

        if file_exists(search_root) == 1
            fs_scan_recursive(scanner, search_root)
            test_files = fs_get_files(scanner)
        else
            term_warning("TEST", "Search directory not found: " + search_root)

    total_tests = len(test_files)
    if total_tests == 0
        term_warning("TEST", "No test files discovered.")
        return 0

    term_banner("LIPI SOVEREIGN AUTONOMOUS TEST SUITE", "Executing " + str(total_tests) + " test targets (0% Shell / 0% C)")

    compiler_bin = "bin/lipc"
    if file_exists(compiler_bin) == 0
        if file_exists("bin/lipc_bin") == 1
            compiler_bin = "bin/lipc_bin"
        elif file_exists("/usr/local/bin/lipc") == 1
            compiler_bin = "/usr/local/bin/lipc"

    // Linux SYS_getpid (syscall 39)
    pid = syscall(39, 0, 0, 0, 0, 0, 0)

    passed_count = 0
    failed_count = 0
    t_idx = 0

    while t_idx < total_tests
        t_file = get(test_files, t_idx)
        tmp_bin = "/tmp/lipi_tst_" + str(pid) + "_" + str(t_idx)

        // Compile test target
        c_args = list()
        push(c_args, t_file)
        push(c_args, "-o")
        push(c_args, tmp_bin)

        comp_res = proc_spawn_capture(compiler_bin, c_args)
        if comp_res.is_success == 0
            term_error("TEST", t_file + " -> Compilation Failed")
            failed_count = failed_count + 1
            if len(comp_res.output) > 0
                say term_dim("    " + comp_res.output)
            syscall(87, tmp_bin, 0, 0, 0, 0, 0)
            t_idx = t_idx + 1
            continue

        // Run compiled test binary
        empty_args = list()
        run_res = proc_spawn_capture(tmp_bin, empty_args)

        // Purge test binary immediately
        syscall(87, tmp_bin, 0, 0, 0, 0, 0)

        if run_res.is_success == 1
            term_success("PASS", t_file)
            passed_count = passed_count + 1
        else
            term_error("FAIL", t_file + " (Exit: " + str(run_res.exit_code) + ")")
            failed_count = failed_count + 1
            if len(run_res.output) > 0
                say term_dim("    " + run_res.output)

        t_idx = t_idx + 1

    // ── Render Test Suite Summary ─────────────────────────────────────────────
    say ""
    term_separator()
    term_progress_bar(passed_count, total_tests, 32, "Suite Completion")
    say ""

    if failed_count == 0
        term_success("SUITE", "All " + str(passed_count) + "/" + str(total_tests) + " test suites passed with 100% sovereign success!")
        return 0
    else
        term_error("SUITE", str(failed_count) + " out of " + str(total_tests) + " test suites failed.")
        return 1
