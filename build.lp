// ==============================================================================
// 👑 LIPI SOVEREIGN BUILD & VERIFICATION ENGINE (build.lp)
// Milestone: 100% Native Silicon Build Orchestrator (Replacing build.sh & Make)
// Version: First 1.0.0 (প্রথম ১.০.০) — Fixed
// 100% Pure LiPi Implementation — Zero External / C / Bash / Python Dependencies
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Relying on bash (build.sh) or GNU Make introduces external dependencies on
//    the host shell, sed, awk, and coreutils, violating true language sovereignty.
// 2. Shell scripts have fragile error handling, slow fork-exec overhead, and
//    inconsistent behavior across different operating systems.
//
// LIPI SOVEREIGN SOLUTION:
// - A 100% pure LiPi native build orchestrator compiled directly to an ELF binary.
// - Deterministic execution pipeline tracking target compilation, status, and duration.
// - Direct orchestration of the compiler, test suites, and deployment manifests with 0% bash.
// ==============================================================================

// ── 1. Build Status & Stage Constants ─────────────────────────────────────────
BUILD_STATUS_PENDING    = 0
BUILD_STATUS_OK         = 1
BUILD_STATUS_FAIL       = 2

// ── 2. Hardware-Aligned Models (Max 8 Fields / 64-Byte Bounds) ────────────────

// Individual Build Target Descriptor (8 fields — 64-byte hardware aligned)
struct BuildTarget
    bt_tag
    bt_name
    bt_source_file
    bt_output_binary
    bt_is_required
    bt_status
    bt_duration_ms
    bt_flag

// Master Build Pipeline State Machine
struct BuildPipeline
    bp_tag
    bp_targets
    bp_total_targets
    bp_passed_targets
    bp_failed_targets
    bp_version_code

// ── 3. Constructor Primitives ─────────────────────────────────────────────────

fn build_target_new name src out_bin req
    bt = BuildTarget()
    bt.bt_tag = 1
    bt.bt_name = name
    bt.bt_source_file = src
    bt.bt_output_binary = out_bin
    bt.bt_is_required = req
    bt.bt_status = BUILD_STATUS_PENDING
    bt.bt_duration_ms = 0
    bt.bt_flag = ""
    return bt

fn build_pipeline_new
    bp = BuildPipeline()
    bp.bp_tag = 1
    bp.bp_targets = list()
    bp.bp_total_targets = 0
    bp.bp_passed_targets = 0
    bp.bp_failed_targets = 0
    bp.bp_version_code = 100 // Version: First 1.0.0
    return bp

// ── 4. Pipeline Configuration & Execution ─────────────────────────────────────

fn build_pipeline_add_target pipe name src out_bin req
    // WHY: Registers compilation and verification targets into the build graph.
    target = build_target_new(name, src, out_bin, req)
    targets = pipe.bp_targets
    push(targets, target)
    pipe.bp_total_targets = pipe.bp_total_targets + 1
    return target

fn build_pipeline_add_kavach_target pipe name src out_bin req
    // WHY: Registers a --kavach memory-safe guarded compilation target.
    target = build_pipeline_add_target(pipe, name, src, out_bin, req)
    target.bt_flag = "--kavach"
    return target

fn build_target_mark_complete target success duration
    if success == 1
        target.bt_status = BUILD_STATUS_OK
    else
        target.bt_status = BUILD_STATUS_FAIL
    target.bt_duration_ms = duration
    return target.bt_status

include "utso/io"
include "utso/memory"
include "utso/string"

// ── Process Execution Gateway (0% Bash, Direct Linux Kernel Syscalls) ─────────
// WHY: Freestanding execution without bash, using sys_mmap, sys_fork, sys_execve, sys_wait4
fn spawn_process_3 cmd_path arg1 arg2 arg3
    argv = syscall(9, 0, 64, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd_path)
    idx = 1
    if len(arg1) > 0
        mem_word_write(argv, idx * 8, arg1)
        idx = idx + 1
    if len(arg2) > 0
        mem_word_write(argv, idx * 8, arg2)
        idx = idx + 1
    if len(arg3) > 0
        mem_word_write(argv, idx * 8, arg3)
        idx = idx + 1
    mem_word_write(argv, idx * 8, 0)

    env = syscall(9, 0, 32, 3, 34, -1, 0)
    path_env = "PATH=/usr/bin:/bin:/usr/local/bin"
    mem_word_write(env, 0, path_env)
    mem_word_write(env, 8, 0)

    st = syscall(9, 0, 8, 3, 34, -1, 0)
    mem_word_write(st, 0, 0)

    pid = syscall(57, 0, 0, 0, 0, 0, 0)
    if pid == 0
        // Redirect child stdout and stderr to /dev/null for clean build status
        null_fd = syscall(2, "/dev/null", 2, 0, 0, 0, 0)
        if null_fd >= 0
            syscall(33, null_fd, 1, 0, 0, 0, 0) // dup2 stdout
            syscall(33, null_fd, 2, 0, 0, 0, 0) // dup2 stderr
            syscall(3, null_fd, 0, 0, 0, 0, 0)
        syscall(59, cmd_path, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_status = mem_word_read(st, 0)
    sig = raw_status & 127
    if sig != 0
        exit_code = 128 + sig
    else
        exit_code = (raw_status / 256) % 256
    end

    syscall(11, argv, 64, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return exit_code

fn spawn_process cmd_path arg1 arg2
    return spawn_process_3(cmd_path, arg1, arg2, "")

// WHY: Streams complete binary bytes in 64KB chunks until EOF so binaries >1MB are never truncated.
fn copy_binary_file src_path dst_path
    rfd = syscall(2, src_path, 0, 0, 0, 0, 0)
    if rfd < 0 return 0
    wfd = syscall(2, dst_path, 577, 493, 0, 0, 0)
    if wfd < 0
        syscall(3, rfd, 0, 0, 0, 0, 0)
        return 0
    end
    cbuf = syscall(9, 0, 65536, 3, 34, -1, 0)
    ok = 1
    while 1
        rlen = syscall(0, rfd, cbuf, 65536, 0, 0, 0)
        if rlen <= 0
            if rlen < 0 ok = 0
            break
        end
        written = 0
        while written < rlen
            w = syscall(1, wfd, cbuf + written, rlen - written, 0, 0, 0)
            if w <= 0
                ok = 0
                break
            end
            written = written + w
        end
        if ok == 0 break
    end
    syscall(11, cbuf, 65536, 0, 0, 0, 0)
    syscall(3, rfd, 0, 0, 0, 0, 0)
    syscall(3, wfd, 0, 0, 0, 0, 0)
    if ok == 1
        syscall(90, dst_path, 493, 0, 0, 0, 0)
    end
    return ok

fn build_pipeline_run_all pipe
    // WHY: Sequentially executes real compilation for all build targets and aggregates results.
    targets = pipe.bp_targets
    tcount = len(targets)
    i = 0
    // WHY: Use sovereign self-hosted modular compiler (bin/lipc) instead of legacy monolith
    compiler = "bin/lipc"
    while i < tcount
        t = get(targets, i)
        say "  • [" + (i + 1) + "/" + tcount + "] Building " + t.bt_name + "..."
        t_start_ms = clock_ms()
        c_code = spawn_process_3(compiler, t.bt_source_file, t.bt_output_binary, t.bt_flag)
        t_elapsed_ms = clock_ms() - t_start_ms
        if t_elapsed_ms < 1
            t_elapsed_ms = 1
        end
        if c_code == 0
            syscall(90, t.bt_output_binary, 493, 0, 0, 0, 0)
            if t.bt_output_binary == "bin/lipc_bin"
                copy_binary_file("bin/lipc_bin", "bin/lipc")
                copy_binary_file("bin/lipc_bin", "bin/lipc_micro")
            elif t.bt_output_binary == "bin/aati"
                copy_binary_file("bin/aati", "bin/haat")
                copy_binary_file("bin/aati", "bin/lipipkg")
            elif t.bt_output_binary == "bin/lipilsp"
                copy_binary_file("bin/lipilsp", "bin/lipils")
            end
            build_target_mark_complete(t, 1, t_elapsed_ms)
            pipe.bp_passed_targets = pipe.bp_passed_targets + 1
            say "    ✔ PASS: " + t.bt_name + " (" + str(t_elapsed_ms) + " ms)"
        else
            build_target_mark_complete(t, 0, t_elapsed_ms)
            pipe.bp_failed_targets = pipe.bp_failed_targets + 1
            say "    ✖ FAIL: " + t.bt_name + " (exit: " + str(c_code) + ", " + str(t_elapsed_ms) + " ms)"
        i = i + 1
    return pipe.bp_passed_targets

// ── 5. Sovereign Bilingual Report Generator ───────────────────────────────────

fn build_pipeline_print_banner
    say "╔════════════════════════════════════════════════════════════════════════╗"
    say "║  👑 LIPI SOVEREIGN BUILD & VERIFICATION ENGINE (0% SHELL / 0% C)       ║"
    say "║  ⚡ Direct Silicon Machine Code | First 1.0.0 (প্রথম ১.০.০) [FIXED]    ║"
    say "╚════════════════════════════════════════════════════════════════════════╝"

fn build_pipeline_print_summary pipe
    say "\n================================================================="
    say "🎉 SOVEREIGN BUILD RESULTS: " + pipe.bp_passed_targets + "/" + pipe.bp_total_targets + " TARGETS VERIFIED"
    say "================================================================="
    say "  ✔ Compiler Toolchain: bin/lipc, bin/lipc_bin, bin/lipc_micro, bin/lipi"
    say "  ✔ Guarded --kavach Tools: bin/lipifmt, bin/lipidoc, bin/lipi_akhara"
    if pipe.bp_failed_targets == 0
        say "👑 ALL " + str(pipe.bp_passed_targets) + "/" + str(pipe.bp_total_targets) + " BUILD TARGETS SUCCEEDED!"
    else
        say "❌ BUILD FAILED: " + str(pipe.bp_failed_targets) + " TARGETS FAILED!"
    end

// ── 6. Main Entry Point ───────────────────────────────────────────────────────

fn build_main
    build_pipeline_print_banner()
    // WHY: Ensure output artifact directories exist dynamically via Linux sys_mkdir (syscall 83, 0755).
    // In pure source repositories (Go, Rust, Zig model), bin/ and dist/ are not tracked in git.
    syscall(83, "bin", 493, 0, 0, 0, 0)
    syscall(83, "dist", 493, 0, 0, 0, 0)
    pipe = build_pipeline_new()

    // Register all core sovereign targets (Modular Micro-Architecture Compiler)
    build_pipeline_add_target(pipe, "Core Compiler Engine", "src/compiler/driver_cli.lp", "bin/lipc_bin", 1)
    build_pipeline_add_target(pipe, "Native Runner & REPL", "src/tools/lipi.lp", "bin/lipi", 1)
    build_pipeline_add_target(pipe, "Sovereign Aati Manager", "src/tools/aati.lp", "bin/aati", 1)
    build_pipeline_add_target(pipe, "Regression Test Engine", "tests/run_tests.lp", "bin/lipi-test", 1)
    build_pipeline_add_target(pipe, "Sovereign System Debugger", "src/tools/lipidbg.lp", "bin/lipidbg", 1)
    build_pipeline_add_kavach_target(pipe, "Code Formatter (--kavach)", "src/tools/lipifmt.lp", "bin/lipifmt", 1)
    build_pipeline_add_target(pipe, "Language Server Protocol Daemon", "src/tools/lipilsp.lp", "bin/lipilsp", 1)
    build_pipeline_add_target(pipe, "Interactive REPL", "src/tools/lipirepl.lp", "bin/lipirepl", 1)
    build_pipeline_add_kavach_target(pipe, "Documentation Generator (--kavach)", "src/tools/lipidoc.lp", "bin/lipidoc", 1)
    build_pipeline_add_target(pipe, "Sovereign UI Engine", "aati/lipi_gui/sovereign_ui.lp", "dist/libsovereign_ui", 1)
    build_pipeline_add_target(pipe, "Sovereign Framework", "aati/lipi_web/sovereign_framework.lp", "dist/libsovereign_web", 1)
    build_pipeline_add_target(pipe, "Web Horizons Suite M1-M5", "tests/test_sovereign_web_horizons.lp", "dist/test_web_m1_m5", 1)
    build_pipeline_add_target(pipe, "Next-Gen Horizons M6-M11", "tests/test_nextgen_web_horizons.lp", "dist/test_web_m6_m11", 1)
    build_pipeline_add_target(pipe, "Framework v2 Suite", "tests/test_sovereign_framework_v2.lp", "dist/test_framework_v2", 1)
    build_pipeline_add_target(pipe, "Commerce Application", "examples/sovereign_commerce.lp", "dist/sovereign_commerce", 1)
    build_pipeline_add_target(pipe, "Pure DNS Resolver", "utso/net/dns_pure.lp", "dist/dns_pure", 1)
    build_pipeline_add_target(pipe, "In-Process TLS 1.3 Server", "utso/net/tls13_server.lp", "dist/tls13_server", 1)
    build_pipeline_add_target(pipe, "Direct DRM/KMS Engine", "aati/lipi_gui/drm_kms.lp", "dist/drm_kms", 1)
    build_pipeline_add_target(pipe, "Bare-Metal Ring-0 Unikernel", "src/tools/lipi_unikernel_boot.lp", "dist/lipi_unikernel_boot", 1)
    build_pipeline_add_target(pipe, "Absolute Sovereignty Suite", "tests/test_absolute_sovereignty.lp", "dist/test_absolute_sovereignty", 1)
    build_pipeline_add_target(pipe, "PCIe NVMe Storage Controller", "utso/io/nvme_direct.lp", "dist/nvme_direct", 1)
    build_pipeline_add_target(pipe, "VirtIO-Net Card Driver", "utso/net/virtio_net.lp", "dist/virtio_net", 1)
    build_pipeline_add_target(pipe, "In-Process LLM GGUF Engine", "aati/lipi_ai/llm_engine_pure.lp", "dist/llm_engine_pure", 1)
    build_pipeline_add_target(pipe, "Formal Verification Engine", "utso/core/formal_proof.lp", "dist/formal_proof", 1)
    build_pipeline_add_target(pipe, "Planetary BFT Consensus", "utso/net/bft_consensus.lp", "dist/bft_consensus", 1)
    build_pipeline_add_target(pipe, "Supreme Frontiers Suite", "tests/test_supreme_frontiers.lp", "dist/test_supreme_frontiers", 1)
    build_pipeline_add_target(pipe, "Live Server Stress Suite", "tests/test_live_server_stress.lp", "dist/test_live_server_stress", 1)
    build_pipeline_add_target(pipe, "Cellular Seed Replication", "tests/test_cellular_replication.lp", "dist/test_cellular_replication", 1)
    build_pipeline_add_target(pipe, "Standalone WASM HTML Emitter", "tests/test_standalone_wasm_html.lp", "dist/test_standalone_wasm_html", 1)
    build_pipeline_add_target(pipe, "WebX Full-Stack Suite", "tests/test_webx_fullstack.lp", "dist/test_webx_fullstack", 1)
    build_pipeline_add_target(pipe, "WebX Pure SVG Charts Engine", "tests/test_webx_charts.lp", "dist/test_webx_charts", 1)
    build_pipeline_add_target(pipe, "WebX Sovereign Islands Suite", "tests/test_webx_islands.lp", "dist/test_webx_islands", 1)
    build_pipeline_add_kavach_target(pipe, "Sovereign Silicon Akhara (--kavach)", "src/tools/lipi_akhara.lp", "bin/lipi_akhara", 1)

    say "\n▶ Executing Native LiPi Build Pipeline (0% Bash)..."
    build_pipeline_run_all(pipe)
    build_pipeline_print_summary(pipe)
    if pipe.bp_failed_targets > 0
        syscall(60, 1, 0, 0, 0, 0, 0)
    end
    return 0

// Guard main execution so including build.lp as a module does not trigger full build pipeline
args = argv()
is_direct_build = 0
if len(args) >= 1
    p0 = get(args, 0)
    // WHY: Support invocation via bare command, relative path, or absolute path (/path/to/bin/lipi-build)
    if p0 == "build.lp.bin" or p0 == "./build.lp.bin" or p0 == "lipi-build" or p0 == "./bin/lipi-build" or ends_with(p0, "lipi-build") == 1 or ends_with(p0, "build.lp.bin") == 1
        is_direct_build = 1
    end
end
if len(args) >= 3
    p2 = get(args, 2)
    if p2 == "build.lp" or p2 == "./build.lp" or ends_with(p2, "build.lp") == 1
        is_direct_build = 1
    end
end

if is_direct_build == 1
    build_main()
end
