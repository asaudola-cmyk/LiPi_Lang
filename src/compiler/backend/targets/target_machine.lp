// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — GENERIC HARDWARE TARGET MACHINE (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/target_machine.lp
//
// WHY THIS MODULE:
// 1. Cross-compilation and multi-silicon support require a hardware target abstraction
//    that decouples higher-level intermediate representations (Lipi IR / SSA) from
//    underlying CPU architectures.
// 2. Hardware architectures diverge fundamentally in:
//    - Instruction width: x86_64 has variable-length instructions (1..15 bytes),
//      while ARM64 (A64) and RISC-V (RV64) use strictly fixed 32-bit (4-byte) words,
//      and WASM uses variable-length LEB128 bytecode.
//    - Silicon register counts: AMD64 provides 16 GPRs; AArch64 provides 31 GPRs;
//      RISC-V provides 32 GPRs; WebAssembly provides infinite local indices.
//    - Calling Conventions & Stack Alignments: 16-byte alignment is required by
//      AMD64, AAPCS64, and RISC-V LP64, but absent in WASM runtime stacks.
// 3. This module serves as the canonical factory and capability query interface for
//    all silicon emitters across the LiPi compiler backend.
// ==============================================================================

@fn TARGET_ID_X86_64()  return 1 @end
@fn TARGET_ID_ARM64()   return 2 @end
@fn TARGET_ID_WASM()    return 3 @end
@fn TARGET_ID_RISCV64() return 4 @end
@fn TARGET_ID_VERILOG() return 5 @end

// ── 2. Target Machine Descriptor ──────────────────────────────────────────────

struct TargetMachine
    arch_id                 // Unique numeric ID (TARGET_ID_*)
    arch_name               // Canonical string identifier ("x86_64", "arm64", "wasm", "riscv64")
    word_size               // Pointer and integer register width in bytes (8 or 4)
    stack_alignment         // Hardware stack alignment requirement in bytes (16 or 1)
    is_little_endian        // 1 for little-endian, 0 for big-endian
    fixed_inst_width        // 4 if fixed 32-bit (ARM64/RISC-V), 0 if variable (x86/WASM)
    num_int_registers       // General-purpose integer register count
    num_arg_registers       // Parameter-passing registers available in ABI
    has_vector_simd         // 1 if target supports hardware SIMD vectors
    vector_width_bits       // Native vector register width (128 or 256 bits)

// ── 3. Architecture Target Constructors ───────────────────────────────────────

fn target_x86_64_create
    // WHY: Intel/AMD64 x86-64 target architecture.
    //      Variable-length CISC machine code, 16 GPRs (%rax..%r15),
    //      System V ABI with 6 register parameters, 256-bit AVX2 SIMD.
    tm = TargetMachine()
    tm.arch_id = TARGET_ID_X86_64
    tm.arch_name = "x86_64"
    tm.word_size = 8
    tm.stack_alignment = 16
    tm.is_little_endian = 1
    tm.fixed_inst_width = 0
    tm.num_int_registers = 16
    tm.num_arg_registers = 6
    tm.has_vector_simd = 1
    tm.vector_width_bits = 256
    return tm

fn target_arm64_create
    // WHY: ARMv8-A / AArch64 target architecture.
    //      Fixed 32-bit RISC machine code, 31 GPRs (X0..X30),
    //      AAPCS64 ABI with 8 register parameters, 128-bit NEON SIMD.
    tm = TargetMachine()
    tm.arch_id = TARGET_ID_ARM64
    tm.arch_name = "arm64"
    tm.word_size = 8
    tm.stack_alignment = 16
    tm.is_little_endian = 1
    tm.fixed_inst_width = 4
    tm.num_int_registers = 31
    tm.num_arg_registers = 8
    tm.has_vector_simd = 1
    tm.vector_width_bits = 128
    return tm

fn target_wasm_create
    // WHY: W3C WebAssembly (WASM) 32-bit/64-bit target architecture.
    //      Bytecode stack machine with LEB128 encoding, infinite virtual locals,
    //      128-bit WASM SIMD proposal support.
    tm = TargetMachine()
    tm.arch_id = TARGET_ID_WASM
    tm.arch_name = "wasm"
    tm.word_size = 4
    tm.stack_alignment = 1
    tm.is_little_endian = 1
    tm.fixed_inst_width = 0
    tm.num_int_registers = 256
    tm.num_arg_registers = 256
    tm.has_vector_simd = 1
    tm.vector_width_bits = 128
    return tm

fn target_riscv64_create
    // WHY: RISC-V 64-bit (RV64GC) open ISA target architecture.
    //      Fixed 32-bit RISC machine code, 32 GPRs (x0..x31),
    //      Standard LP64 ABI with 8 argument registers (a0..a7).
    tm = TargetMachine()
    tm.arch_id = TARGET_ID_RISCV64
    tm.arch_name = "riscv64"
    tm.word_size = 8
    tm.stack_alignment = 16
    tm.is_little_endian = 1
    tm.fixed_inst_width = 4
    tm.num_int_registers = 32
    tm.num_arg_registers = 8
    tm.has_vector_simd = 1
    tm.vector_width_bits = 128
    return tm

fn target_verilog_create
    // WHY: Verilog IEEE 1364-2001 hardware description target architecture.
    //      Synthesizes digital circuits, registers, ALUs, and FSMs for FPGA and ASIC tapeouts.
    tm = TargetMachine()
    tm.arch_id = TARGET_ID_VERILOG
    tm.arch_name = "verilog"
    tm.word_size = 8
    tm.stack_alignment = 1
    tm.is_little_endian = 1
    tm.fixed_inst_width = 0
    tm.num_int_registers = 64
    tm.num_arg_registers = 8
    tm.has_vector_simd = 0
    tm.vector_width_bits = 0
    return tm

fn target_machine_from_name name
    // WHY: Dynamic target dispatcher selecting appropriate hardware profile by name.
    if name == "x86_64" or name == "amd64" or name == "x86-64"
        return target_x86_64_create()
    if name == "arm64" or name == "aarch64"
        return target_arm64_create()
    if name == "wasm" or name == "wasm32" or name == "wasm64"
        return target_wasm_create()
    if name == "riscv64" or name == "rv64" or name == "riscv"
        return target_riscv64_create()
    if name == "verilog" or name == "hdl" or name == "fpga"
        return target_verilog_create()
    // Default fallback to host x86_64
    return target_x86_64_create()

// ── 4. Target Query Methods ───────────────────────────────────────────────────

fn target_is_64bit tm
    // WHY: Returns 1 if hardware word size is 64-bit (8 bytes).
    if tm.word_size == 8
        return 1
    return 0

fn target_is_fixed_instruction_width tm
    // WHY: Returns 1 if instructions are fixed-width (e.g. 4 bytes for ARM64/RISC-V).
    if tm.fixed_inst_width > 0
        return 1
    return 0

// ── 5. Verification Self-Test ────────────────────────────────────────────────

fn test_target_machine_subsystem
    t_x86 = target_machine_from_name("x86_64")
    if t_x86.arch_id != TARGET_ID_X86_64 or t_x86.word_size != 8 or t_x86.vector_width_bits != 256
        say "FAIL: x86_64 target configuration invalid"
        return 0

    t_arm = target_machine_from_name("arm64")
    if t_arm.arch_id != TARGET_ID_ARM64 or t_arm.fixed_inst_width != 4 or t_arm.num_arg_registers != 8
        say "FAIL: arm64 target configuration invalid"
        return 0

    t_wasm = target_machine_from_name("wasm")
    if t_wasm.arch_id != TARGET_ID_WASM or t_wasm.stack_alignment != 1
        say "FAIL: wasm target configuration invalid"
        return 0

    t_rv = target_machine_from_name("riscv64")
    if t_rv.arch_id != TARGET_ID_RISCV64 or t_rv.num_int_registers != 32
        say "FAIL: riscv64 target configuration invalid"
        return 0

    return 1

// test_target_machine_subsystem()
