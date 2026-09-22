// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: RUN SUB-COMMAND MODULE (src/toolkit/cli/cmd_run.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | Instant In-Memory Execution
// ==============================================================================
//
// WHY THIS MODULE:
// Rapid development and script-like workflows require a single `lipi run <file.lp>` command
// that feels like an interpreter while delivering 100% native CPU silicon machine performance.
// Architecture:
// 1. Compiles target source file directly to a PID-isolated temporary ELF binary in /tmp.
// 2. Transmits all trailing command-line arguments to the running program.
// 3. Reaps and guarantees immediate unlinking of the temporary binary to prevent disk bloat.
// 4. Zero libc, zero shell, zero intermediate files left behind.

include "src/toolkit/common/cli_parser.lp"
include "src/toolkit/common/terminal_ui.lp"
include "src/toolkit/common/process.lp"

// ── 1. Temporary Binary Path Generator ────────────────────────────────────────

// WHY: Synthesizes a unique, collision-free binary path in /tmp isolated by process PID.
fn cmd_run_make_temp_path
    // Linux SYS_getpid (syscall 39)
    pid = syscall(39, 0, 0, 0, 0, 0, 0)
    return "/tmp/lipi_run_proc_" + str(pid)

// ── 2. Run Sub-command Execution Entry Point ──────────────────────────────────

// WHY: Coordinates compilation, argument forwarding, process execution, and cleanup.
fn cmd_run_execute parser
    source_file = cli_get_arg(parser, 0)

    if len(source_file) == 0
        term_error("RUN", "Source file required. Usage: lipi run <file.lp> [args...]")
        return 1

    if file_exists(source_file) == 0
        term_error("RUN", "Source file not found: " + source_file)
        return 1

    compiler_bin = "bin/lipc"
    if file_exists(compiler_bin) == 0
        if file_exists("bin/lipc_bin") == 1
            compiler_bin = "bin/lipc_bin"
        elif file_exists("/usr/local/bin/lipc") == 1
            compiler_bin = "/usr/local/bin/lipc"

    tmp_bin = cmd_run_make_temp_path()

    // ── Phase 1: Compile to temporary native binary ──
    c_args = list()
    push(c_args, source_file)
    push(c_args, "-o")
    push(c_args, tmp_bin)

    comp_res = proc_spawn_capture(compiler_bin, c_args)
    if comp_res.is_success == 0
        term_error("RUN", "Compilation failed.")
        if len(comp_res.output) > 0
            say term_red(comp_res.output)
        // Ensure scratch cleanup if partial output exists
        syscall(87, tmp_bin, 0, 0, 0, 0, 0)
        return comp_res.exit_code

    // ── Phase 2: Assemble forwarded arguments ──
    total_args = cli_arg_count(parser)
    run_args = list()
    idx = 1
    while idx < total_args
        push(run_args, cli_get_arg(parser, idx))
        idx = idx + 1

    // ── Phase 3: Execute binary with direct terminal standard I/O ──
    exit_code = proc_spawn(tmp_bin, run_args)

    // ── Phase 4: Purge temporary binary via Linux SYS_unlink (syscall 87) ──
    syscall(87, tmp_bin, 0, 0, 0, 0, 0)

    return exit_code
