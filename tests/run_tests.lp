// ==============================================================================
// 👑 LIPI NATIVE SOVEREIGN REGRESSION TEST ENGINE (tests/run_tests.lp)
// ⚡ 100% Pure LiPi Implementation | 0% Bash | 0% Libc | Direct Kernel Syscalls
// Version: First 1.0.0 (প্রথম ১.০.০) — Fixed
// ==============================================================================

include "universe/core/io.lp"
include "universe/core/memory.lp"
include "universe/core/string.lp"

// ── Process Execution Gateway ────────────────────────────────────────────────
// WHY: Freestanding execution without bash, using sys_mmap, sys_fork, sys_execve, sys_wait4
fn spawn_process cmd_path arg1 arg2
    argv = syscall(9, 0, 64, 3, 34, -1, 0)
    mem_word_write(argv, 0, cmd_path)
    idx = 1
    if len(arg1) > 0
        mem_word_write(argv, idx * 8, arg1)
        idx = idx + 1
    if len(arg2) > 0
        mem_word_write(argv, idx * 8, arg2)
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
        // Redirect stdout and stderr to /dev/null to keep test summary clean
        null_fd = syscall(2, "/dev/null", 2, 0, 0, 0, 0)
        if null_fd >= 0
            syscall(33, null_fd, 1, 0, 0, 0, 0) // dup2 stdout
            syscall(33, null_fd, 2, 0, 0, 0, 0) // dup2 stderr
            syscall(3, null_fd, 0, 0, 0, 0, 0)
        syscall(59, cmd_path, argv, env, 0, 0, 0)
        syscall(60, 127, 0, 0, 0, 0, 0)

    syscall(61, pid, st, 0, 0, 0, 0)
    raw_status = mem_word_read(st, 0)
    exit_code = (raw_status / 256) % 256

    syscall(11, argv, 64, 0, 0, 0, 0)
    syscall(11, env, 32, 0, 0, 0, 0)
    syscall(11, st, 8, 0, 0, 0, 0)
    return exit_code

// ── Single Test Case Execution ───────────────────────────────────────────────
fn run_single_test compiler test_path test_name
    out_bin = "/tmp/lipi_tst_" + test_name
    // Compile test source directly to native ELF64
    c_code = spawn_process(compiler, test_path, out_bin)
    if c_code != 0
        say "  • Testing " + test_name + "... [1;31mCOMPILE FAIL ✖[0m"
        return 0

    // Execute compiled test binary
    r_code = spawn_process(out_bin, "", "")
    // Clean up temporary test binary immediately
    syscall(87, out_bin, 0, 0, 0, 0, 0)

    if r_code == 0
        say "  • Testing " + test_name + "... [1;32mPASS ✔[0m"
        return 1
    else
        say "  • Testing " + test_name + "... [1;31mRUNTIME FAIL ✖[0m"
        return 0

fn main
    // WHY: 72 visual columns (70 chars interior + 2 border chars).
    // Leaves safe 8-column margin on standard 80-column Linux terminal windows.
    say "╔══════════════════════════════════════════════════════════════════════╗"
    say "║  🧪 LIPI SUITE REGRESSION TEST ENGINE (100% PURE SILICON / 0% SHELL) ║"
    say "╚══════════════════════════════════════════════════════════════════════╝"

    // WHY: Use sovereign self-hosted modular compiler (bin/lipc)
    compiler = "bin/lipc"
    passed = 0
    failed = 0

    if run_single_test(compiler, "tests/01_hello.lp", "01_hello") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/02_math_fibonacci.lp", "02_math_fibonacci") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/03_logic_and_arrays.lp", "03_logic_and_arrays") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/04_web_server.lp", "04_web_server") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/05_sovereign_dashboard.lp", "05_sovereign_dashboard") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/06_silicon_ai.lp", "06_silicon_ai") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/07_multi_file_import.lp", "07_multi_file_import") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/08_structs_and_exceptions.lp", "08_structs_and_exceptions") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/09_lipi_web_framework.lp", "09_lipi_web_framework") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/10_concurrency_and_channels.lp", "10_concurrency_and_channels") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/11_baremetal_hardware_control.lp", "11_baremetal_hardware_control") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/12_native_silicon_logic.lp", "12_native_silicon_logic") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/13_sovereign_cpu_arithmetic.lp", "13_sovereign_cpu_arithmetic") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/14_sovereign_loop_and_logic.lp", "14_sovereign_loop_and_logic") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/15_functions_and_recursion.lp", "15_functions_and_recursion") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/16_kernel_syscalls_file_io.lp", "16_kernel_syscalls_file_io") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/17_standard_library_import.lp", "17_standard_library_import") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/18_native_web_server.lp", "18_native_web_server") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/19_heap_memory_and_pointers.lp", "19_heap_memory_and_pointers") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/20_grand_stdlib_expansion.lp", "20_grand_stdlib_expansion") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/21_kernel_multithreading.lp", "21_kernel_multithreading") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/22_custom_structs_and_types.lp", "22_custom_structs_and_types") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/23_native_database_engine.lp", "23_native_database_engine") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/24_silicon_matrix_ai.lp", "24_silicon_matrix_ai") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/25_arena_memory_allocator.lp", "25_arena_memory_allocator") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/26_async_epoll_event_loop.lp", "26_async_epoll_event_loop") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/27_lipipkg_project_lifecycle.lp", "27_lipipkg_project_lifecycle") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/28_hardware_crypto_sha256.lp", "28_hardware_crypto_sha256") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/29_lipidbg_system_debugger.lp", "29_lipidbg_system_debugger") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/30_ast_optimizer_constant_folding.lp", "30_ast_optimizer_constant_folding") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/31_pure_lipi_tls_crypto_stream.lp", "31_pure_lipi_tls_crypto_stream") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/32_silicon_graphics_framebuffer.lp", "32_silicon_graphics_framebuffer") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/33_unum_shared_memory.lp", "33_unum_shared_memory") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/34_unum_ansi_tui.lp", "34_unum_ansi_tui") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/35_unum_columnstore_ai.lp", "35_unum_columnstore_ai") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/36_unum_robinhood_hashmap.lp", "36_unum_robinhood_hashmap") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/37_unum_websocket.lp", "37_unum_websocket") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/38_unum_x11_gui.lp", "38_unum_x11_gui") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/39_sovereign_production_app.lp", "39_sovereign_production_app") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/40_gguf_tensor_inference.lp", "40_gguf_tensor_inference") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/41_baremetal_multiboot_kernel.lp", "41_baremetal_multiboot_kernel") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/42_bilingual_english_syntax.lp", "42_bilingual_english_syntax") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/43_preprocessor_elif_chain.lp", "43_preprocessor_elif_chain") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/44_lipipkg_manifest.lp", "44_lipipkg_manifest") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/45_http_framework_demo.lp", "45_http_framework_demo") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/46_type_annotations.lp", "46_type_annotations") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/47_advanced_memory_patterns.lp", "47_advanced_memory_patterns") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/48_cli_argument_parser.lp", "48_cli_argument_parser") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/49_string_formatting.lp", "49_string_formatting") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/50_sovereign_os_components.lp", "50_sovereign_os_components") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/51_minimal_hello.lp", "51_minimal_hello") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/52_minimal_functions.lp", "52_minimal_functions") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/53_minimal_recursion.lp", "53_minimal_recursion") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/54_minimal_loops.lp", "54_minimal_loops") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/55_minimal_conditionals.lp", "55_minimal_conditionals") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/56_minimal_unicode.lp", "56_minimal_unicode") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/57_minimal_strings.lp", "57_minimal_strings") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/58_minimal_structs.lp", "58_minimal_structs") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/59_minimal_fibonacci.lp", "59_minimal_fibonacci") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/60_minimal_primes.lp", "60_minimal_primes") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/62_arm64_emitter.lp", "62_arm64_emitter") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/63_struct_methods.lp", "63_struct_methods") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/64_wasm_emitter.lp", "64_wasm_emitter") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/65_ssa_optimizer.lp", "65_ssa_optimizer") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/66_developer_toolchain.lp", "66_developer_toolchain") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/67_package_security_ed25519.lp", "67_package_security_ed25519") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/68_wasm_client_runner.lp", "68_wasm_client_runner") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/69_tri_syntax.lp", "69_tri_syntax") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/70_sovereign_advanced_features.lp", "70_sovereign_advanced_features") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/72_avx2_simd_vector.lp", "72_avx2_simd_vector") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/73_ssa_dominator_tree.lp", "73_ssa_dominator_tree") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/74_generic_monomorphize.lp", "74_generic_monomorphize") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/75_sovereign_arena_allocator.lp", "75_sovereign_arena_allocator") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/76_epoll_async_server.lp", "76_epoll_async_server") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/77_avx2_direct_emitter.lp", "77_avx2_direct_emitter") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/78_async_microservice_json.lp", "78_async_microservice_json") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/extension_test.lp", "extension_test") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_absolute_sovereignty.lp", "test_absolute_sovereignty") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_assimilate.lp", "test_assimilate") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_auto_register.lp", "test_auto_register") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_avx2_simd.lp", "test_avx2_simd") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_avx512_gemm.lp", "test_avx512_gemm") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_avx512_vector.lp", "test_avx512_vector") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_branding_assets.lp", "test_branding_assets") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_comptime_eval.lp", "test_comptime_eval") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_db_mvcc.lp", "test_db_mvcc") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_declarative_ui.lp", "test_declarative_ui") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_desktop_gui.lp", "test_desktop_gui") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_dwarf_debug.lp", "test_dwarf_debug") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_fast_json.lp", "test_fast_json") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_fiber_scheduler.lp", "test_fiber_scheduler") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_framebuffer_gui.lp", "test_framebuffer_gui") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_gauss_loop.lp", "test_gauss_loop") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_gguf_tensor_native.lp", "test_gguf_tensor_native") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_gpu_compute.lp", "test_gpu_compute") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_gpu_silicon.lp", "test_gpu_silicon") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_gpu_spirv.lp", "test_gpu_spirv") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_io_uring_high_throughput.lp", "test_io_uring_high_throughput") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_io_uring_reactor.lp", "test_io_uring_reactor") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_io_uring_ring.lp", "test_io_uring_ring") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_io_uring_stress.lp", "test_io_uring_stress") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_ir_peephole.lp", "test_ir_peephole") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_lipi_book_examples.lp", "test_lipi_book_examples") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_lipidb_redis.lp", "test_lipidb_redis") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_lipipkg_hub.lp", "test_lipipkg_hub") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_lipirpc_mesh.lp", "test_lipirpc_mesh") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_live_os_boot.lp", "test_live_os_boot") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_live_server_stress.lp", "test_live_server_stress") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_llm_inference.lp", "test_llm_inference") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_local_llm_runner.lp", "test_local_llm_runner") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_lsp_definition.lp", "test_lsp_definition") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_multi_target.lp", "test_multi_target") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_nextgen_web_horizons.lp", "test_nextgen_web_horizons") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_omni_targets.lp", "test_omni_targets") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_post_quantum_crypto.lp", "test_post_quantum_crypto") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_raft_cluster_net.lp", "test_raft_cluster_net") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_raft_distributed_kv.lp", "test_raft_distributed_kv") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_register_allocation.lp", "test_register_allocation") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_registry_server.lp", "test_registry_server") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_rfc6455_websockets.lp", "test_rfc6455_websockets") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_shared_object.lp", "test_shared_object") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_simd_gemm.lp", "test_simd_gemm") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_sovereign_ffi.lp", "test_sovereign_ffi") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_sovereign_framework_v2.lp", "test_sovereign_framework_v2") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_sovereign_fullstack_suite.lp", "test_sovereign_fullstack_suite") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_sovereign_web_horizons.lp", "test_sovereign_web_horizons") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_supreme_frontiers.lp", "test_supreme_frontiers") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_swarm_liprpc.lp", "test_swarm_liprpc") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_tiling_wm.lp", "test_tiling_wm") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_tls13_handshake.lp", "test_tls13_handshake") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_universal_synthesizer.lp", "test_universal_synthesizer") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_universe_flagship.lp", "test_universe_flagship") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_universe_full_stack.lp", "test_universe_full_stack") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_vector_hnsw_rag.lp", "test_vector_hnsw_rag") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_vsix_package.lp", "test_vsix_package") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_wal_crash_recovery.lp", "test_wal_crash_recovery") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_wasm_lipi_source.lp", "test_wasm_lipi_source") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_web_playground.lp", "test_web_playground") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_web_router.lp", "test_web_router") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_zero_shell_sovereignty.lp", "test_zero_shell_sovereignty") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_fiber_concurrency.lp", "test_fiber_concurrency") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_dynamic_c_abi.lp", "test_dynamic_c_abi") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_tensor_gemm.lp", "test_tensor_gemm") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_enterprise_packages.lp", "test_enterprise_packages") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_cellular_replication.lp", "test_cellular_replication") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_standalone_wasm_html.lp", "test_standalone_wasm_html") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // ── Super-Advanced Sovereign Frontiers (Tests 147-152) ───────────────────
    // WHY: Hardens ARM64 silicon parity, atomic concurrency, kernel epoll,
    // memory reclamation, zero-division guards, and Unicode Bengali runes.
    if run_single_test(compiler, "tests/test_arm64_parity.lp", "test_arm64_parity") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_atomic_concurrency.lp", "test_atomic_concurrency") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_div_by_zero_guard.lp", "test_div_by_zero_guard") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_io_and_epoll.lp", "test_io_and_epoll") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_slab_memory_reclaim.lp", "test_slab_memory_reclaim") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_unicode_bengali_runes.lp", "test_unicode_bengali_runes") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // ── Real-World Sovereign Flagship Showcases (Tests 153-154) ───────────────
    // WHY: Continuous end-to-end verification of standalone microservices and TUI engines.
    if run_single_test(compiler, "examples/cloudless_micro_universe.lp", "test_cloudless_micro_universe") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "examples/silicon_tui_dashboard.lp", "test_silicon_tui_dashboard") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // ── Pure Sovereign Media & Network Protocols (Tests 155-157) ─────────────────
    // WHY: Proves LiPi's complete autonomy from C/FFmpeg/ALSA/Libc resolvers:
    // synthesizes PCM 44.1kHz audio, rasterizes 24-bit BMP frames, and resolves DNS queries directly.
    if run_single_test(compiler, "tests/test_audio_wav.lp", "test_audio_wav") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_video_canvas.lp", "test_video_canvas") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_dns_resolver.lp", "test_dns_resolver") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // ── Enterprise Micro-Architectural Subsystem Suites (Tests 158-165) ───────────
    // WHY: Verifies all 110 modular micro-files across Core, Diagnostics, Lexer/AST,
    // Semantics, SSA IR & 12 Optimizers, RegAlloc & Targets, Formats, and Toolkit.
    if run_single_test(compiler, "tests/31_core_silicon_primitives.lp", "test_core_silicon_primitives") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_diagnostics.lp", "test_diagnostics_subsystem") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_micro_lexer_ast.lp", "test_micro_lexer_ast") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_semantics_engine.lp", "test_semantics_engine") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_middleend_ssa_opt.lp", "test_middleend_ssa_opt") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_silicon_regalloc_targets.lp", "test_silicon_regalloc_targets") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/52_binary_formats_subsystem.lp", "test_binary_formats_subsystem") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_toolkit_subsystem.lp", "test_toolkit_subsystem") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_compiler_micro_pipeline.lp", "test_compiler_micro_pipeline") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_micro_compiler_bootstrap.lp", "test_micro_compiler_bootstrap") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_micro_compiler_parity.lp", "test_micro_compiler_parity") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_micro_compiler_bootstrap_stage2.lp", "test_micro_compiler_bootstrap_stage2") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_micro_compiler_multi_target_parity.lp", "test_micro_compiler_multi_target_parity") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_micro_compiler_quad_target_parity.lp", "test_micro_compiler_quad_target_parity") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // ── Next-Gen Sovereign Compiler & Ecosystem Frontiers (Tests 172-178) ────────
    // WHY: Validates SSA lowering, DWARF debug, PIC shared objects, ARM64/WASM, Option/Result, and Package Hub.
    if run_single_test(compiler, "tests/test_ast_to_ssa_lowering.lp", "test_ast_to_ssa_lowering") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_dwarf_debug_emission.lp", "test_dwarf_debug_emission") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_micro_compiler_shared_so.lp", "test_micro_compiler_shared_so") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_arm64_synthesizer.lp", "test_arm64_synthesizer") == 1
        passed = passed + 1
    else
        failed = failed + 1
    if run_single_test(compiler, "tests/test_wasm_synthesizer.lp", "test_wasm_synthesizer") == 1
        passed = passed + 1
    else
        failed = failed + 1
    // 177: Algebraic Option & Monadic Result Zero-Cost Fault Handling.
    if run_single_test(compiler, "tests/test_algebraic_option_result.lp", "test_algebraic_option_result") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // 178: Sovereign Package Hub & SemVer 2.0.0 Lifecycle Engine
    if run_single_test(compiler, "tests/test_package_hub_lifecycle.lp", "test_package_hub_lifecycle") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // 179: Sovereign Blockchain & LipiVM Engine (MPT, State Trié, EVM Opcodes)
    if run_single_test(compiler, "tests/test_blockchain_evm.lp", "test_blockchain_evm") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // 180: Closures & Trait Polymorphism Systems Architecture
    if run_single_test(compiler, "tests/test_closure_and_traits.lp", "test_closure_and_traits") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // 181: Sovereign Linux KVM Virtualization & Hypervisor Engine
    if run_single_test(compiler, "tests/test_hypervisor_kvm.lp", "test_hypervisor_kvm") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // 182: Full Native Language Server Protocol (LSP 3.17) Engine
    if run_single_test(compiler, "tests/test_native_lsp_full.lp", "test_native_lsp_full") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // 183: Multi-Qubit Quantum State Vector & Gate Matrix Engine
    if run_single_test(compiler, "tests/test_quantum_state_vector.lp", "test_quantum_state_vector") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // 184: Scoped Region & Transient Arena Allocation Architecture
    if run_single_test(compiler, "tests/test_scoped_arena.lp", "test_scoped_arena") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // 185: Silicon Direct Store-to-Load Forwarding & Peephole Optimizer
    if run_single_test(compiler, "tests/test_silicon_optimizer.lp", "test_silicon_optimizer") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // 186: Sovereign ASN.1 DER Encoding & X.509 PKI Engine
    if run_single_test(compiler, "tests/test_x509_certificate.lp", "test_x509_certificate") == 1
        passed = passed + 1
    else
        failed = failed + 1

    // 187: Hardware HDL Synthesis & AI-Driven Neural Heuristic Optimization Parity
    if run_single_test(compiler, "tests/test_hdl_and_ai_opt.lp", "test_hdl_and_ai_opt") == 1
        passed = passed + 1
    else
        failed = failed + 1

    say "========================================================================"
    say "Total Tests: " + (passed + failed) + " | Passed: " + passed + " | Failed: " + failed
    say "========================================================================"
    if failed == 0
        say "🎉 ALL " + passed + " REGRESSION TESTS PASSED!"
        return 0
    else
        say "❌ SOME TESTS FAILED!"
        return 1

main()
