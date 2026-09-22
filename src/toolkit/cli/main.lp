// ==============================================================================
// 👑 LIPI UNIFIED DEVELOPER TOOLKIT: MASTER CLI ENTRY POINT (src/toolkit/cli/main.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | Direct Silicon Developer Toolchain
// ==============================================================================
//
// WHY THIS MODULE:
// A complete programming language ecosystem requires an integrated, multi-command
// developer hub (like `cargo`, `go`, or `zig`).
// This master CLI entry point acts as the universal dispatch gateway for:
// 1. `lipi build`: Native standalone machine code compilation.
// 2. `lipi run`: Zero-overhead in-memory compilation and execution.
// 3. `lipi test`: Autonomous recursive test runner and report engine.
// 4. `lipi clean`: Safe workspace cache purger and scratch binary unlinker.
// 5. `lipi fmt`: Deterministic 4-space code indentation engine.
// 6. `lipi doc`: Automatic markdown documentation and WHY extractor.
// 7. `lipi lsp`: Language Server Protocol daemon for IDE integration.
// 8. `lipi dbg`: Native Linux ptrace CPU register and breakpoint debugger.
// 9. `lipi pkg`: Cryptographic package manifest and checksum validator.
// 10. `lipi graph`: Build dependency DAG analyzer and cycle detector.

include "src/toolkit/common/cli_parser.lp"
include "src/toolkit/common/terminal_ui.lp"
include "src/toolkit/common/fs_scanner.lp"
include "src/toolkit/common/process.lp"

include "src/toolkit/cli/cmd_build.lp"
include "src/toolkit/cli/cmd_run.lp"
include "src/toolkit/cli/cmd_test.lp"
include "src/toolkit/cli/cmd_clean.lp"

include "src/toolkit/lsp/transport.lp"
include "src/toolkit/lsp/protocol_json.lp"
include "src/toolkit/lsp/document_store.lp"

include "src/toolkit/dbg/ptrace_linux.lp"
include "src/toolkit/dbg/breakpoint_mgr.lp"

include "src/toolkit/pkg/manifest_parser.lp"
include "src/toolkit/pkg/checksum_sha256.lp"

include "src/toolkit/fmt/indent_engine.lp"
include "src/toolkit/doc/markdown_writer.lp"
include "src/toolkit/build/dep_graph.lp"

// ── 1. Auxiliary Subcommand Handlers ──────────────────────────────────────────

// WHY: Handles `lipi fmt <file.lp>` formatting workflow.
fn handle_fmt_command parser
    target_file = cli_get_arg(parser, 0)
    if len(target_file) == 0
        term_error("FMT", "Target file required: lipi fmt <file.lp> [--check]")
        return 1

    is_check = cli_get_flag(parser, "--check")
    if is_check == 1
        if fmt_check_file(target_file) == 1
            term_success("FMT", target_file + " is cleanly formatted.")
            return 0
        else
            term_warning("FMT", target_file + " requires formatting.")
            return 1

    changed = fmt_format_file(target_file)
    if changed == 1
        term_success("FMT", "Formatted: " + target_file)
    else
        term_info("FMT", "Already formatted: " + target_file)
    return 0

// WHY: Handles `lipi doc <file.lp> [-o out.md]` documentation extraction.
fn handle_doc_command parser
    source_file = cli_get_arg(parser, 0)
    if len(source_file) == 0
        term_error("DOC", "Source file required: lipi doc <file.lp> [-o <out.md>]")
        return 1

    out_md = cli_get_option(parser, "--output")
    if len(out_md) == 0 out_md = cli_get_option(parser, "-o")
    if len(out_md) == 0
        out_md = source_file + ".md"

    ok = doc_process_file(source_file, out_md)
    if ok == 1
        term_success("DOC", "Generated documentation: " + out_md)
        return 0
    else
        term_error("DOC", "Failed to document: " + source_file)
        return 1

// WHY: Handles `lipi pkg <subcmd>` package management commands.
fn handle_pkg_command parser
    action = cli_get_arg(parser, 0)
    if action == "init"
        m = pkg_manifest_new()
        m.name = "lipi_package"
        pkg_manifest_save(m, "lipi.pkg")
        term_success("PKG", "Created initial lipi.pkg manifest.")
        return 0
    elif action == "hash" or action == "checksum"
        target_file = cli_get_arg(parser, 1)
        if len(target_file) == 0
            term_error("PKG", "File path required: lipi pkg hash <file>")
            return 1
        h = pkg_sha256_file(target_file)
        say "SHA256 (" + target_file + ") = " + h
        return 0
    elif action == "verify"
        target_file = cli_get_arg(parser, 1)
        expected_hash = cli_get_arg(parser, 2)
        if len(target_file) == 0 or len(expected_hash) == 0
            term_error("PKG", "Usage: lipi pkg verify <file> <expected_sha256>")
            return 1
        if pkg_sha256_verify_file(target_file, expected_hash) == 1
            term_success("PKG", "Integrity verified: Checksum matches.")
            return 0
        else
            term_error("PKG", "Integrity check failed: Checksum mismatch!")
            return 1
    else
        say "Usage: lipi pkg [init | hash <file> | verify <file> <sha256>]"
        return 0

// WHY: Handles `lipi graph <root.lp>` dependency DAG analysis.
fn handle_graph_command parser
    root_file = cli_get_arg(parser, 0)
    if len(root_file) == 0
        if file_exists("src/main.lp") == 1 root_file = "src/main.lp"
        elif file_exists("main.lp") == 1 root_file = "main.lp"
        else
            term_error("GRAPH", "Entry file required: lipi graph <entry.lp>")
            return 1

    graph = dep_graph_new()
    dep_build_from_root(graph, root_file)

    term_banner("LIPI BUILD DEPENDENCY DAG ANALYZER", "Analyzed " + str(graph.node_count) + " module nodes")

    if dep_detect_cycles(graph) == 1
        term_error("GRAPH", graph.cycle_info)
        return 1

    term_success("GRAPH", "DAG is strictly acyclic (0 circular includes detected).")

    order = dep_topological_sort(graph)
    say "\n  Topological Build Ordering (" + str(len(order)) + " compilation stages):"
    i = 0
    while i < len(order)
        say "    [" + str(i + 1) + "] " + get(order, i)
        i = i + 1
    say ""
    return 0

// WHY: Handles `lipi dbg <pid>` Linux ptrace debugger session.
fn handle_dbg_command parser
    raw_pid = cli_get_arg(parser, 0)
    if len(raw_pid) == 0
        term_error("DBG", "Target PID required: lipi dbg <pid>")
        return 1

    // Parse integer PID
    target_pid = 0
    p_i = 0
    while p_i < len(raw_pid)
        c = ord(char_at(raw_pid, p_i))
        if c >= 48 and c <= 57
            target_pid = (target_pid * 10) + (c - 48)
        p_i = p_i + 1

    term_banner("LIPI SOVEREIGN NATIVE DEBUGGER (LIPIDBG)", "Attaching to process " + str(target_pid))

    rc = ptrace_attach(target_pid)
    if rc < 0
        term_error("DBG", "Failed to attach to process " + str(target_pid))
        return 1

    term_success("DBG", "Attached to PID " + str(target_pid) + ". Process halted.")
    regs = ptrace_get_regs(target_pid)
    ptrace_dump_regs(regs)

    ptrace_detach(target_pid)
    term_info("DBG", "Detached from process " + str(target_pid) + ". Resuming normal execution.")
    return 0

// ── 2. Unified Master CLI Dispatcher ──────────────────────────────────────────

// WHY: Configures parser options, evaluates command line tokens, and dispatches to modules.
fn main
    raw_argv = argv()
    parser = cli_parser_new("lipi", "LiPi Sovereign Programming Language & Unified Developer Toolkit", "First 1.0.0 (প্রথম ১.০.০)")

    // Register Subcommands
    cli_add_subcommand(parser, "build", "Compile standalone native machine code binary (ELF64, WASM, ARM64)")
    cli_add_subcommand(parser, "run",   "Compile and execute program in-memory with zero disk overhead")
    cli_add_subcommand(parser, "test",  "Execute autonomous test suites (0% Shell)")
    cli_add_subcommand(parser, "clean", "Purge temporary build caches and scratch binaries")
    cli_add_subcommand(parser, "fmt",   "Deterministic 4-space code indentation formatter")
    cli_add_subcommand(parser, "doc",   "Automatic markdown documentation and WHY extractor")
    cli_add_subcommand(parser, "pkg",   "Cryptographic package manager and checksum validator")
    cli_add_subcommand(parser, "graph", "Build dependency DAG analyzer and cycle detector")
    cli_add_subcommand(parser, "dbg",   "Native Linux ptrace hardware register and breakpoint debugger")
    cli_add_subcommand(parser, "lsp",   "Launch Language Server Protocol daemon for IDE integration")
    cli_add_subcommand(parser, "help",  "Display command documentation")

    // Register Global Flags & Options
    cli_add_flag(parser, "--verbose", "-v", "Enable detailed diagnostic and debug output")
    cli_add_flag(parser, "--help",    "-h", "Display usage instructions and exit")
    cli_add_flag(parser, "--check",   "-c", "Dry-run check mode (e.g. for lipi fmt --check)")
    cli_add_flag(parser, "--release", "-r", "Optimize binary for release deployment")
    cli_add_option(parser, "--output", "-o", "Specify output file destination", "")
    cli_add_option(parser, "--target", "-t", "Set compilation target architecture (x86_64, arm64, wasm)", "")

    // Strip argv[0] (binary itself) to extract user arguments
    arg_count = len(raw_argv)
    user_args = list()
    idx = 1
    while idx < arg_count
        push(user_args, get(raw_argv, idx))
        idx = idx + 1

    if len(user_args) == 0
        term_banner("LIPI SOVEREIGN PROGRAMMING LANGUAGE & UNIVERSE", "Direct Silicon Machine Code | First 1.0.0 (প্রথম ১.০.০)")
        cli_print_help(parser)
        return 0

    // Parse arguments
    ok = cli_parse(parser, user_args)
    if ok == 0
        term_error("CLI", parser.error_message)
        return 1

    if cli_get_flag(parser, "--help") == 1 or cli_get_flag(parser, "-h") == 1
        cli_print_help(parser)
        return 0

    sub = cli_get_subcommand(parser)

    // Dispatch
    if sub == "build"
        return cmd_build_execute(parser)
    elif sub == "run"
        return cmd_run_execute(parser)
    elif sub == "test"
        return cmd_test_execute(parser)
    elif sub == "clean"
        return cmd_clean_execute(parser)
    elif sub == "fmt"
        return handle_fmt_command(parser)
    elif sub == "doc"
        return handle_doc_command(parser)
    elif sub == "pkg"
        return handle_pkg_command(parser)
    elif sub == "graph"
        return handle_graph_command(parser)
    elif sub == "dbg" or sub == "debug"
        return handle_dbg_command(parser)
    elif sub == "help"
        cli_print_help(parser)
        return 0
    else
        // If unknown subcommand or raw file passed, treat as `lipi run <file>`
        if len(sub) > 0 and file_exists(sub) == 1
            // Insert file as positional arg 0
            parser.positional_args = list()
            push(parser.positional_args, sub)
            return cmd_run_execute(parser)

        term_error("CLI", "Unknown command: " + sub)
        cli_print_help(parser)
        return 1

    return 0

main()
