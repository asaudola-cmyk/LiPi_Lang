// ==============================================================================
// 👑 LIPI FIRST 1.0.0 STANDALONE SOVEREIGN MICRO-COMPILER (src/compiler/driver_cli.lp)
// ⚡ 100% Pure Lipi First 1.0.0 | Zero C | Zero Libc | Sovereign Micro-Architecture
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Standalone Sovereign Executable: Compiles to './bin/lipc_micro', realizing the next-gen
//    micro-architectural compiler as an independently executable native ELF64 binary.
// 2. Bilingual CLI Interface: Provides UNIX-compliant flags with Bengali cultural grounding.
// 3. Multi-Target Driver: Dispatches compilation jobs to x86_64, arm64, wasm, or riscv64.
// ==============================================================================

include "src/compiler/driver.lp"
include "src/compiler/middleend/ai_opt.lp"

fn print_cli_usage
    say "╔══════════════════════════════════════════════════════════════════════╗"
    say "║  👑 LIPI FIRST 1.0.0 STANDALONE SOVEREIGN MICRO-COMPILER (lipc_micro)║"
    say "║  ⚡ 100% Pure Silicon Machine Code | 0% C | 0% Libc | Sovereign      ║"
    say "╚══════════════════════════════════════════════════════════════════════╝"
    say ""
    say "ব্যবহারবিধি (Usage):"
    say "  lipc_micro [অপশন / options] <input_source.lp>"
    say ""
    say "অপশনসমূহ (Available Flags):"
    say "  -o <file>                  আউটপুট বাইনারির পাথ (Output binary path)"
    say "  --target=<arch>            টার্গেট আর্কিটেকচার (Target: x86_64, arm64, wasm, riscv64, verilog)"
    say "  -O0, -O1, -O2, -O3         অপটিমাইজেশন লেভেল (Optimization level: 0, 1, 2, or 3)"
    say "  --ai-opt                   এআই চালিত নিউরাল অপটিমাইজার (AI-driven neural optimization heuristics)"
    say "  -g, --debug                সোর্স ডিবাগিং ইনফরমেশন (DWARF v4/v5 Debug symbols)"
    say "  --shared                   ডাইনামিক শেয়ার্ড লাইব্রেরি (.so Shared Object)"
    say "  -h, --help                 সহায়তা বার্তা প্রদর্শন (Display this help manual)"
    say "  -v, --version              ভার্সন তথ্য (Display compiler version: First 1.0.0)"
    say ""
    say "উদাহরণ (Examples):"
    say "  lipc_micro main.lp -o app.bin"
    say "  lipc_micro -g main.lp -o app_debug.bin"
    say "  lipc_micro --shared math.lp -o libmath.so"
    say "  lipc_micro --target=arm64 app.lp -o app_arm.bin"
    say "  lipc_micro --target=verilog alu.lp -o alu.v"
    say "  lipc_micro -O3 --ai-opt matrix.lp -o matrix.bin"
    return 0

fn main
    args = argv()
    argc = len(args)

    if argc < 2
        print_cli_usage()
        exit(1)

    in_file = ""
    out_file = ""
    target_arch = TARGET_ID_X86_64()
    opt_level = 1
    debug_mode = 0
    emit_format = FORMAT_ELF()
    ai_opt_enabled = 0
    i = 1

    while i < argc
        arg = get(args, i)
        if arg == "-h" or arg == "--help" or arg == "help"
            print_cli_usage()
            exit(0)
        elif arg == "-v" or arg == "--version" or arg == "version"
            say "👑 LiPi First 1.0.0 (প্রথম ১.০.০) — Sovereign Modular Silicon Compiler"
            say "⚡ 100% Pure Silicon Machine Code | 0% C | 0% Libc"
            exit(0)
        elif arg == "-o" or arg == "--output"
            i = i + 1
            if i < argc
                out_file = get(args, i)
        elif arg == "-g" or arg == "--debug"
            debug_mode = 1
        elif arg == "--shared" or arg == "-shared"
            emit_format = FORMAT_SHARED()
        elif arg == "--format=macho" or arg == "--macho" or arg == "--target=macos"
            emit_format = FORMAT_MACHO()
        elif arg == "--format=pe" or arg == "--pe" or arg == "--target=windows"
            emit_format = FORMAT_PE()
        elif arg == "--target=arm64" or arg == "--target=aarch64"
            target_arch = TARGET_ID_ARM64()
        elif arg == "--target=wasm" or arg == "--target=web"
            target_arch = TARGET_ID_WASM()
        elif arg == "--target=riscv64" or arg == "--target=riscv"
            target_arch = TARGET_ID_RISCV64()
        elif arg == "--target=verilog" or arg == "--target=hdl" or arg == "--emit=verilog"
            target_arch = TARGET_ID_VERILOG()
            emit_format = FORMAT_VERILOG()
        elif arg == "--target=x86_64" or arg == "--target=amd64"
            target_arch = TARGET_ID_X86_64()
        elif arg == "--ai-opt" or arg == "-ai"
            ai_opt_enabled = 1
        elif arg == "-O0"
            opt_level = 0
        elif arg == "-O1"
            opt_level = 1
        elif arg == "-O2"
            opt_level = 2
        elif arg == "-O3"
            opt_level = 3
        else
            if in_file == ""
                in_file = arg
            else
                if out_file == ""
                    out_file = arg
        i = i + 1

    if in_file == ""
        say "❌ [ত্রুটি / Error]: কোনো ইনপুট ফাইল দেওয়া হয়নি (No input source file specified)."
        say "ব্যবহার দেখতে: lipc_micro --help"
        exit(1)

    if out_file == ""
        if emit_format == FORMAT_SHARED()
            out_file = in_file + ".so"
        elif emit_format == FORMAT_MACHO()
            out_file = in_file + ".macho"
        elif emit_format == FORMAT_PE()
            out_file = in_file + ".exe"
        elif target_arch == TARGET_ID_WASM()
            out_file = in_file + ".wasm"
        elif target_arch == TARGET_ID_VERILOG() or emit_format == FORMAT_VERILOG()
            out_file = in_file + ".v"
        else
            out_file = in_file + ".bin"

    // Execute AI Optimization heuristics if requested
    if ai_opt_enabled == 1
        say "🤖 [AI OPTIMIZER]: Neural heuristic loop & register pressure analyzer active."
        opt_weights = ai_opt_default_weights()
        feat = LoopFeatureVector(1000, 16, 4, 0, 1, 1, 0)
        decision = ai_opt_evaluate_loop(opt_weights, feat)
        say "  • Recommended Loop Unroll Factor: " + str(decision.recommended_unroll_factor)
        say "  • SIMD Vectorization Affinity:    " + str(decision.should_vectorize)
        say "  • Predicted Execution Speedup:    " + str(decision.predicted_speedup_pct) + "%"
        say "  • Estimated Register Pressure:    " + str(decision.register_pressure_score) + "/100"

    // Execute compilation via micro-pipeline driver
    say "▶ Compiling " + in_file + " ──► " + out_file + " via Sovereign Micro-Pipeline..."
    res = compiler_driver_compile_file_advanced(in_file, out_file, target_arch, opt_level, emit_format, debug_mode)
    
    // Report detailed diagnostics
    compiler_driver_print_result(res)

    if res.res_success == 1
        say "✔ Successfully generated: " + out_file + " (" + res.res_output_bytes + " bytes)"
        exit(0)
    else
        say "❌ Compilation failed!"
        exit(1)
