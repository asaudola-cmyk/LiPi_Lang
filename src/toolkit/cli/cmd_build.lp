// ==============================================================================
// 👑 LIPI UNIFIED TOOLKIT: BUILD SUB-COMMAND MODULE (src/toolkit/cli/cmd_build.lp)
// ⚡ 100% Pure Sovereign Lipi First 1.0.0 | Native Silicon Compiler Dispatcher
// ==============================================================================
//
// WHY THIS MODULE:
// The `lipi build` sub-command orchestrates the compilation of Lipi source files
// (.lp) into standalone native machine code binaries (ELF64, ARM64, WASM).
// By integrating directly with the sovereign compiler `lipc`:
// 1. Eliminates reliance on external Makefiles, shell build scripts, or GCC.
// 2. Automates target binary naming and output directory scaffolding.
// 3. Delivers rich TrueColor terminal feedback with exact build metrics.
// 4. Validates source integrity before dispatching compiler processes.

include "src/toolkit/common/cli_parser.lp"
include "src/toolkit/common/terminal_ui.lp"
include "src/toolkit/common/process.lp"

// ── 1. Compiler Binary Resolver ───────────────────────────────────────────────

// WHY: Dynamically detects the canonical sovereign compiler binary across standard locations.
fn cmd_build_resolve_compiler
    if file_exists("bin/lipc") == 1
        return "bin/lipc"
    if file_exists("bin/lipc_bin") == 1
        return "bin/lipc_bin"
    if file_exists("/usr/local/bin/lipc") == 1
        return "/usr/local/bin/lipc"
    if file_exists("../bin/lipc") == 1
        return "../bin/lipc"
    return "bin/lipc"

// ── 2. Output Path Normalizer ─────────────────────────────────────────────────

// WHY: Strips directory path and .lp extension from source path to synthesize default binary name.
fn cmd_build_default_output source_path
    slen = len(source_path)
    last_slash = -1
    i = 0
    while i < slen
        if char_at(source_path, i) == "/"
            last_slash = i
        i = i + 1

    base_name = source_path
    if last_slash >= 0
        base_name = str_sub(source_path, last_slash + 1, slen)

    blen = len(base_name)
    if blen > 3 and str_sub(base_name, blen - 3, blen) == ".lp"
        base_name = str_sub(base_name, 0, blen - 3)

    return "bin/" + base_name

// ── 3. Build Sub-command Execution Entry Point ────────────────────────────────

// WHY: Executes end-to-end `lipi build` compilation workflow.
fn cmd_build_execute parser
    source_file = cli_get_arg(parser, 0)

    // Fallback: detect main.lp or src/main.lp if no positional file was passed
    if len(source_file) == 0
        if file_exists("src/main.lp") == 1
            source_file = "src/main.lp"
        elif file_exists("main.lp") == 1
            source_file = "main.lp"
        else
            term_error("BUILD", "Missing input source file. Usage: lipi build <source.lp> [-o <out>]")
            return 1

    // Verify source file exists
    if file_exists(source_file) == 0
        term_error("BUILD", "Source file not found: " + source_file)
        return 1

    // Parse output binary destination
    output_bin = cli_get_option(parser, "--output")
    if len(output_bin) == 0
        output_bin = cli_get_option(parser, "-o")
    if len(output_bin) == 0
        output_bin = cmd_build_default_output(source_file)

    target_arch = cli_get_option(parser, "--target")
    is_verbose = cli_get_flag(parser, "--verbose")
    if is_verbose == 0
        is_verbose = cli_get_flag(parser, "-v")

    term_step_banner(1, 2, "Configuring Build Target", source_file + " -> " + output_bin)

    // Locate compiler binary
    compiler_bin = cmd_build_resolve_compiler()
    if file_exists(compiler_bin) == 0
        term_error("BUILD", "Sovereign compiler binary not found: " + compiler_bin)
        return 1

    // Assemble compiler invocation argument vector
    c_args = list()

    if len(target_arch) > 0
        push(c_args, "--target=" + target_arch)

    push(c_args, source_file)
    push(c_args, "-o")
    push(c_args, output_bin)

    term_step_banner(2, 2, "Compiling Pure Native Machine Code", "Invoking " + compiler_bin)

    // Execute compiler process via kernel pipe IPC
    res = proc_spawn_capture(compiler_bin, c_args)

    if res.is_success == 1
        term_success("BUILD", "Successfully compiled: " + term_bold(output_bin))
        if is_verbose == 1 and len(res.output) > 0
            say term_dim(res.output)
        return 0
    else
        term_error("BUILD", "Compilation failed with exit code " + str(res.exit_code))
        if len(res.output) > 0
            say term_red(res.output)
        return res.exit_code
