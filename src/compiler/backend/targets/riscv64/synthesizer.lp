// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN RISC-V 64-BIT (RV64) MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/riscv64/synthesizer.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Direct Silicon RV64 Synthesis:
//    Compiles LiPi AST / token streams directly into native 64-bit RISC-V (RV64I/M)
//    machine instructions, bypassing GCC, Clang, LLVM, GNU as, or any external toolchain.
// 2. 100% Sovereign Invariant:
//    Zero C, Zero Libc, Zero External Toolchains. Pure LiPi First 1.0.0 implementation.
// 3. Implements Standard RISC-V LP64 ABI:
//    - Strict 16-byte stack frame alignment (sp mod 16 == 0 at all times).
//    - Preserved Frame Pointer (s0/fp = x8) and Return Address (ra = x1).
//    - Standard register parameter passing in a0..a7 (x10..x17).
//    - Scalar return values delivered in a0 (x10).
// 4. Built-in Sovereign Micro-Runtime Helpers:
//    - Pure RV64 assembly routine for integer-to-decimal ASCII conversion with trailing newline.
//    - Direct Linux RISC-V syscalls (a7=64 for SYS_write, a7=93 for SYS_exit, a7=222 for SYS_mmap).
//    - Pure RISC-V bump arena memory allocator (__alloc) with 1GB virtual memory arena.
// 5. Complete Sovereign Control Flow:
//    - Synthesizes hardware jumps for while/for loops, if/elif/else branching trees,
//      break/continue jump targets, struct field manipulation, and Linux system calls.
// 6. Direct ELF64 RISC-V Container Header Generation:
//    - Emits standalone Linux ELF64 binaries with 64KB page alignment, EM_RISCV (243 = 0x00F3),
//      and entry point at 0x400078 with executable permissions (0755).
// 7. Namespaced Structural Isolation:
//    - All struct fields use strict unique prefixes ('rv_*') to completely avoid
//      global struct field offset collisions with X86Synthesizer and Arm64Synthesizer.
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"

import "compiler/frontend/lexer/token_kind"
import "compiler/frontend/lexer/token"

include "src/compiler/backend/targets/riscv64/registers.lp"
include "src/compiler/backend/targets/riscv64/r_i_s_u_b_formats.lp"

// ── 1. Data Models ────────────────────────────────────────────────────────────

// WHY: Records a 64-bit virtual memory relocation for string constants
struct Riscv64StringReloc
    rv_sr_patch_offset     // Byte index in rv_code where the 2-instruction LUI/ADDI pair begins
    rv_sr_rodata_offset    // Byte index in rv_rodata where the UTF-8 string payload starts
    rv_sr_reg              // Target register index (10 for a0, 11 for a1, etc.)

// WHY: Maps a local variable identifier to an SP-relative positive stack byte offset
struct Riscv64LocalVar
    rv_lv_name             // Variable identifier string
    rv_lv_offset           // Positive stack offset in bytes: accessed as [sp + rv_lv_offset]

// WHY: Records a function definition entry point for inter-procedural call site resolution
struct Riscv64Function
    rv_fn_name             // Function identifier string
    rv_fn_entry_offset     // Byte offset in rv_code where the function prologue starts

// WHY: Records an unresolved 20-bit PC-relative subroutine call displacement
struct Riscv64CallReloc
    rv_cr_patch_offset     // Byte index in rv_code where the 4-byte JAL instruction is located
    rv_cr_target_name      // Target function identifier or "__print_int" / "__alloc"

// WHY: Models struct schema definitions and field member offsets
struct Riscv64StructDef
    rv_sd_name             // Struct type name string
    rv_sd_fields           // List of field name strings

// WHY: Return container for ELF64 container synthesis results
struct Riscv64ElfResult
    rv_ew_success          // 1 on success, 0 on failure
    rv_ew_out_path         // Destination binary path string
    rv_ew_file_size        // Total byte count written to disk
    rv_ew_entry_vaddr      // Absolute virtual memory entry address (0x400078 = 4194424)
    rv_ew_error_msg        // Human-readable error diagnostic

// WHY: Encapsulates mutable compilation state for RISC-V 64 silicon code generation
struct Riscv64Synthesizer
    rv_code                // List of machine code bytes (integers 0..255)
    rv_rodata              // List of read-only data bytes (.rodata segment)
    rv_str_relocs          // List of Riscv64StringReloc structs
    rv_call_relocs         // List of Riscv64CallReloc structs
    rv_locals              // List of Riscv64LocalVar structs for current function frame
    rv_functions           // List of Riscv64Function structs
    rv_stack_offset        // Next available local variable stack offset (16, 24, 32...)
    rv_needs_print_int     // Flag: 1 if integer printing helper must be emitted
    rv_print_int_off       // Byte offset where print_int helper starts
    rv_loop_starts         // Stack of loop header byte offsets for 'continue'
    rv_loop_breaks         // Stack of lists of break patch offsets
    rv_structs             // List of Riscv64StructDef structs
    rv_global_fields       // List of global field name strings
    rv_needs_alloc         // Flag: 1 if bump allocator helper must be emitted
    rv_alloc_off           // Byte offset where bump allocator starts
    rv_in_function         // 1 if currently synthesizing inside a function, 0 if top-level

// ── 2. Constructor & Emitter Primitives ───────────────────────────────────────

fn riscv64_synth_new
    // WHY: Allocates and initializes clean RISC-V 64 synthesizer state.
    s = Riscv64Synthesizer()
    s.rv_code = list()
    s.rv_rodata = list()
    s.rv_str_relocs = list()
    s.rv_call_relocs = list()
    s.rv_locals = list()
    s.rv_functions = list()
    s.rv_stack_offset = 16
    s.rv_needs_print_int = 0
    s.rv_print_int_off = 0
    s.rv_loop_starts = list()
    s.rv_loop_breaks = list()
    s.rv_structs = list()
    s.rv_global_fields = list()
    s.rv_needs_alloc = 0
    s.rv_alloc_off = 0
    s.rv_in_function = 0
    return s

fn riscv64_synth_emit_byte s byte_val
    // WHY: Emits a single raw machine instruction byte into rv_code.
    push(s.rv_code, (byte_val % 256 + 256) % 256)
    return s.rv_code.len()

fn riscv64_synth_emit_bytes s byte_list
    // WHY: Appends an array of byte values sequentially.
    i = 0
    n = byte_list.len()
    while i < n
        push(s.rv_code, (byte_list[i] % 256 + 256) % 256)
        i = i + 1
    return s.rv_code.len()

fn riscv64_synth_emit32 s inst_word
    // WHY: Emits 4 bytes in little-endian byte order for 32-bit fixed-width RISC-V instruction word.
    b0 = inst_word % 256
    if b0 < 0 b0 = b0 + 256
    w1 = inst_word / 256
    b1 = w1 % 256
    if b1 < 0 b1 = b1 + 256
    w2 = w1 / 256
    b2 = w2 % 256
    if b2 < 0 b2 = b2 + 256
    w3 = w2 / 256
    b3 = w3 % 256
    if b3 < 0 b3 = b3 + 256
    push(s.rv_code, b0)
    push(s.rv_code, b1)
    push(s.rv_code, b2)
    push(s.rv_code, b3)
    return s.rv_code.len()

fn riscv64_synth_patch_u32 s offset val
    // WHY: Backpatches 4 bytes at a predetermined byte offset in rv_code.
    b0 = val % 256
    if b0 < 0 b0 = b0 + 256
    w1 = val / 256
    b1 = w1 % 256
    if b1 < 0 b1 = b1 + 256
    w2 = w1 / 256
    b2 = w2 % 256
    if b2 < 0 b2 = b2 + 256
    w3 = w2 / 256
    b3 = w3 % 256
    if b3 < 0 b3 = b3 + 256
    list_set(s.rv_code, offset, b0)
    list_set(s.rv_code, offset + 1, b1)
    list_set(s.rv_code, offset + 2, b2)
    list_set(s.rv_code, offset + 3, b3)
    return 0

// ── 3. Read-Only Data (.rodata) Management ────────────────────────────────────

fn riscv64_synth_add_rodata_str s str_text with_newline
    // WHY: Stores UTF-8 string payload into rv_rodata and returns its starting offset.
    start_off = s.rv_rodata.len()
    slen = len(str_text)
    i = 0
    while i < slen
        c = char_at(str_text, i)
        push(s.rv_rodata, ord(c))
        i = i + 1
    if with_newline == 1
        push(s.rv_rodata, 10) // '\n' (ASCII 10)
    push(s.rv_rodata, 0)      // Null-terminator (ASCII 0)
    return start_off

// ── 4. RISC-V 64 Canonical Instruction Emitters ───────────────────────────────

fn riscv64_emit_lui s rd imm20
    // WHY: LUI rd, imm20 (opcode 0x37 = 55). Loads upper 20 bits into destination register.
    bytes = rv64_encode_u(55, rd, imm20)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_auipc s rd imm20
    // WHY: AUIPC rd, imm20 (opcode 0x17 = 23). Adds upper 20-bit imm to PC.
    bytes = rv64_encode_u(23, rd, imm20)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_jal s rd imm
    // WHY: JAL rd, imm (opcode 0x6F = 111). Jump and link with 20-bit relative byte displacement.
    bytes = rv64_encode_j(111, rd, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_jalr s rd rs1 imm12
    // WHY: JALR rd, rs1, imm12 (opcode 0x67 = 103, funct3=0). Indirect register jump and link.
    bytes = rv64_encode_i(103, rd, 0, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_beq s rs1 rs2 imm
    // WHY: BEQ rs1, rs2, imm (opcode 0x63 = 99, funct3=0). Branch if equal.
    bytes = rv64_encode_b(99, 0, rs1, rs2, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_bne s rs1 rs2 imm
    // WHY: BNE rs1, rs2, imm (opcode 0x63 = 99, funct3=1). Branch if not equal.
    bytes = rv64_encode_b(99, 1, rs1, rs2, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_blt s rs1 rs2 imm
    // WHY: BLT rs1, rs2, imm (opcode 0x63 = 99, funct3=4). Branch if signed less than.
    bytes = rv64_encode_b(99, 4, rs1, rs2, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_bge s rs1 rs2 imm
    // WHY: BGE rs1, rs2, imm (opcode 0x63 = 99, funct3=5). Branch if signed greater/equal.
    bytes = rv64_encode_b(99, 5, rs1, rs2, imm)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_add s rd rs1 rs2
    // WHY: ADD rd, rs1, rs2 (opcode 0x33 = 51, funct3=0, funct7=0). 64-bit integer addition.
    bytes = rv64_emit_add(rd, rs1, rs2)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sub s rd rs1 rs2
    // WHY: SUB rd, rs1, rs2 (opcode 0x33 = 51, funct3=0, funct7=32). 64-bit integer subtraction.
    bytes = rv64_emit_sub(rd, rs1, rs2)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_addi s rd rs1 imm12
    // WHY: ADDI rd, rs1, imm12 (opcode 0x13 = 19, funct3=0). 64-bit addition with 12-bit signed immediate.
    bytes = rv64_emit_addi(rd, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_mul s rd rs1 rs2
    // WHY: MUL rd, rs1, rs2 (RV64M extension: opcode 0x33 = 51, funct3=0, funct7=1). 64-bit signed multiplication.
    bytes = rv64_encode_r(51, rd, 0, rs1, rs2, 1)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_div s rd rs1 rs2
    // WHY: DIV rd, rs1, rs2 (RV64M extension: opcode 0x33 = 51, funct3=4, funct7=1). 64-bit signed integer division.
    bytes = rv64_encode_r(51, rd, 4, rs1, rs2, 1)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_rem s rd rs1 rs2
    // WHY: REM rd, rs1, rs2 (RV64M extension: opcode 0x33 = 51, funct3=6, funct7=1). 64-bit signed remainder.
    bytes = rv64_encode_r(51, rd, 6, rs1, rs2, 1)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_slt s rd rs1 rs2
    // WHY: SLT rd, rs1, rs2 (opcode 0x33 = 51, funct3=2, funct7=0). Signed set less than.
    bytes = rv64_encode_r(51, rd, 2, rs1, rs2, 0)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sltu s rd rs1 rs2
    // WHY: SLTU rd, rs1, rs2 (opcode 0x33 = 51, funct3=3, funct7=0). Unsigned set less than.
    bytes = rv64_encode_r(51, rd, 3, rs1, rs2, 0)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sltiu s rd rs1 imm12
    // WHY: SLTIU rd, rs1, imm12 (opcode 0x13 = 19, funct3=3). Unsigned set less than immediate.
    bytes = rv64_encode_i(19, rd, 3, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_xori s rd rs1 imm12
    // WHY: XORI rd, rs1, imm12 (opcode 0x13 = 19, funct3=4). Bitwise XOR immediate.
    bytes = rv64_encode_i(19, rd, 4, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_andi s rd rs1 imm12
    // WHY: ANDI rd, rs1, imm12 (opcode 0x13 = 19, funct3=7). Bitwise AND immediate.
    bytes = rv64_encode_i(19, rd, 7, rs1, imm12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_ld s rd rs1 offset12
    // WHY: LD rd, offset12(rs1) (opcode 0x03 = 3, funct3=3). 64-bit memory load.
    bytes = rv64_emit_ld(rd, rs1, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sd s rs2 rs1 offset12
    // WHY: SD rs2, offset12(rs1) (opcode 0x23 = 35, funct3=3). 64-bit memory store.
    bytes = rv64_emit_sd(rs2, rs1, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_lb s rd rs1 offset12
    // WHY: LB rd, offset12(rs1) (opcode 0x03 = 3, funct3=0). 8-bit signed memory load.
    bytes = rv64_encode_i(3, rd, 0, rs1, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_lbu s rd rs1 offset12
    // WHY: LBU rd, offset12(rs1) (opcode 0x03 = 3, funct3=4). 8-bit unsigned memory load.
    bytes = rv64_encode_i(3, rd, 4, rs1, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_sb s rs2 rs1 offset12
    // WHY: SB rs2, offset12(rs1) (opcode 0x23 = 35, funct3=0). 8-bit byte memory store.
    bytes = rv64_encode_s(35, 0, rs1, rs2, offset12)
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_ecall s
    // WHY: ECALL (opcode 0x73 = 115, funct3=0). Triggers hardware environment trap for Linux syscalls.
    bytes = rv64_emit_ecall()
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_ret s
    // WHY: RET pseudoinstruction (JALR x0, x1, 0: opcode 0x67, rd=0, rs1=1, funct3=0). Returns to caller.
    bytes = rv64_emit_ret()
    riscv64_synth_emit_bytes(s, bytes)
    return 0

fn riscv64_emit_mv s rd rs
    // WHY: MV rd, rs (Pseudoinstruction: ADDI rd, rs, 0). Copies register contents.
    riscv64_emit_addi(s, rd, rs, 0)
    return 0

fn riscv64_emit_li s rd val
    // WHY: LI rd, val. Loads arbitrary signed 32-bit constant into rd using minimal instructions.
    // Small values (-2048..2047) take 1 instruction (ADDI rd, x0, val).
    // Larger 32-bit constants take 2 instructions (LUI + ADDI).
    if val >= 0 - 2048 and val <= 2047
        riscv64_emit_addi(s, rd, 0, val)
        return 0
    v_adj = val + 2048
    hi = (v_adj / 4096) % 1048576
    lo = val - (hi * 4096)
    riscv64_emit_lui(s, rd, hi)
    riscv64_emit_addi(s, rd, rd, lo)
    return 0

// ── 5. Backpatching & Relocation Utilities ─────────────────────────────────────

fn riscv64_synth_patch_lui_addi s offset rd target_vaddr
    // WHY: Patches a 2-instruction (8-byte) LUI + ADDI sequence to load a 32-bit virtual memory address.
    v_adj = target_vaddr + 2048
    hi = (v_adj / 4096) % 1048576
    lo = target_vaddr - (hi * 4096)
    w_lui_bytes = rv64_encode_u(55, rd, hi)
    w_addi_bytes = rv64_encode_i(19, rd, 0, rd, lo)
    list_set(s.rv_code, offset, get(w_lui_bytes, 0))
    list_set(s.rv_code, offset + 1, get(w_lui_bytes, 1))
    list_set(s.rv_code, offset + 2, get(w_lui_bytes, 2))
    list_set(s.rv_code, offset + 3, get(w_lui_bytes, 3))
    list_set(s.rv_code, offset + 4, get(w_addi_bytes, 0))
    list_set(s.rv_code, offset + 5, get(w_addi_bytes, 1))
    list_set(s.rv_code, offset + 6, get(w_addi_bytes, 2))
    list_set(s.rv_code, offset + 7, get(w_addi_bytes, 3))
    return 0

fn riscv64_synth_patch_jal s patch_offset rd target_offset
    // WHY: Patches a 4-byte JAL instruction with 20-bit relative byte displacement.
    rel_bytes = target_offset - patch_offset
    j_bytes = rv64_encode_j(111, rd, rel_bytes)
    list_set(s.rv_code, patch_offset, get(j_bytes, 0))
    list_set(s.rv_code, patch_offset + 1, get(j_bytes, 1))
    list_set(s.rv_code, patch_offset + 2, get(j_bytes, 2))
    list_set(s.rv_code, patch_offset + 3, get(j_bytes, 3))
    return 0

fn riscv64_synth_patch_b s patch_offset funct3 rs1 rs2 target_offset
    // WHY: Patches a 4-byte B-type conditional branch instruction with 12-bit relative byte displacement.
    rel_bytes = target_offset - patch_offset
    b_bytes = rv64_encode_b(99, funct3, rs1, rs2, rel_bytes)
    list_set(s.rv_code, patch_offset, get(b_bytes, 0))
    list_set(s.rv_code, patch_offset + 1, get(b_bytes, 1))
    list_set(s.rv_code, patch_offset + 2, get(b_bytes, 2))
    list_set(s.rv_code, patch_offset + 3, get(b_bytes, 3))
    return 0

// ── 6. Stack Frame & Register Push/Pop Primitives ─────────────────────────────

fn riscv64_push_reg s reg
    // WHY: Pushes 64-bit register onto stack:
    //      addi sp, sp, -16
    //      sd reg, 0(sp)
    // Preserves mandatory LP64 16-byte stack alignment at all times.
    riscv64_emit_addi(s, 2, 2, 0 - 16)
    riscv64_emit_sd(s, reg, 2, 0)
    return 0

fn riscv64_pop_reg s reg
    // WHY: Pops 64-bit register from stack:
    //      ld reg, 0(sp)
    //      addi sp, sp, 16
    riscv64_emit_ld(s, reg, 2, 0)
    riscv64_emit_addi(s, 2, 2, 16)
    return 0

fn riscv64_emit_prologue s
    // WHY: Standard LP64 ABI procedure frame setup:
    // 1. addi sp, sp, -1024       (Allocates 1KB stack space, 16-byte aligned)
    // 2. sd ra, 1016(sp)          (Preserves Return Address x1)
    // 3. sd s0, 1008(sp)          (Preserves Frame Pointer x8)
    // 4. addi s0, sp, 1024        (Establishes new Frame Pointer at caller's SP)
    riscv64_emit_addi(s, 2, 2, 0 - 1024)
    riscv64_emit_sd(s, 1, 2, 1016)
    riscv64_emit_sd(s, 8, 2, 1008)
    riscv64_emit_addi(s, 8, 2, 1024)
    return 0

fn riscv64_emit_epilogue s
    // WHY: Standard LP64 ABI procedure frame teardown:
    // 1. ld ra, 1016(sp)          (Restores Return Address x1)
    // 2. ld s0, 1008(sp)          (Restores Frame Pointer x8)
    // 3. addi sp, sp, 1024        (Deallocates stack frame)
    // 4. ret                      (Returns to caller via x1)
    riscv64_emit_ld(s, 1, 2, 1016)
    riscv64_emit_ld(s, 8, 2, 1008)
    riscv64_emit_addi(s, 2, 2, 1024)
    riscv64_emit_ret(s)
    return 0

// ── 7. String Printing Primitive ──────────────────────────────────────────────

fn riscv64_emit_print_string s str_val
    // WHY: Emits Linux RISC-V SYS_write(1, &str, len) for string literals:
    //      - a0 = 1 (STDOUT_FILENO)
    //      - a1 = Virtual address of UTF-8 string payload in .rodata
    //      - a2 = Byte length including appended newline
    //      - a7 = 64 (Linux RISC-V SYS_write)
    //      - ECALL
    ro_off = riscv64_synth_add_rodata_str(s, str_val, 1)
    str_len = len(str_val) + 1 // Includes appended newline

    // a0 = 1 (STDOUT)
    riscv64_emit_li(s, 10, 1)

    // a1 = <rodata_vaddr> (8-byte LUI + ADDI pair, backpatched after code assembly)
    patch_pos = s.rv_code.len()
    riscv64_emit_lui(s, 11, 0)
    riscv64_emit_addi(s, 11, 11, 0)

    rel = Riscv64StringReloc()
    rel.rv_sr_patch_offset = patch_pos
    rel.rv_sr_rodata_offset = ro_off
    rel.rv_sr_reg = 11
    push(s.rv_str_relocs, rel)

    // a2 = str_len
    riscv64_emit_li(s, 12, str_len)

    // a7 = 64 (SYS_write on Linux RISC-V)
    riscv64_emit_li(s, 17, 64)

    // ecall
    riscv64_emit_ecall(s)
    return 0

// ── 8. Micro-Runtime Helpers ──────────────────────────────────────────────────

fn riscv64_synth_emit_call_print_int s
    // WHY: Emits subroutine call to native __print_int helper to display integer in a0 (x10).
    s.rv_needs_print_int = 1
    call_off = s.rv_code.len()
    riscv64_emit_jal(s, 1, 0) // Placeholder JAL ra, 0

    call_rel = Riscv64CallReloc()
    call_rel.rv_cr_patch_offset = call_off
    call_rel.rv_cr_target_name = "__print_int"
    push(s.rv_call_relocs, call_rel)
    return 0

fn riscv64_synth_emit_print_int_helper s
    // WHY: Pure RISC-V assembly routine converting 64-bit signed integer in a0 (x10)
    // to ASCII decimal string on the stack and writing to STDOUT with trailing newline.
    // Zero dependencies on external C printf/puts.
    s.rv_print_int_off = s.rv_code.len()

    // Stack setup: addi sp, sp, -64; sd ra, 56(sp); sd s0, 48(sp)
    riscv64_emit_addi(s, 2, 2, 0 - 64)
    riscv64_emit_sd(s, 1, 2, 56)
    riscv64_emit_sd(s, 8, 2, 48)

    // Buffer built backwards starting at [sp + 47]
    // Write trailing newline '\n' (10)
    // addi t0, sp, 47 (t0 = buffer pointer)
    riscv64_emit_addi(s, 5, 2, 47)
    // addi t1, x0, 10
    riscv64_emit_addi(s, 6, 0, 10)
    // sb t1, 0(t0)
    riscv64_emit_sb(s, 6, 5, 0)
    // t1 = 1 (current length = 1)
    riscv64_emit_addi(s, 6, 0, 1)

    // Check if a0 == 0
    // bne a0, x0, .check_neg (offset +16 bytes: 4 instructions forward)
    riscv64_emit_bne(s, 10, 0, 16)

    // Special case: a0 == 0
    // addi t0, t0, -1
    riscv64_emit_addi(s, 5, 5, 0 - 1)
    // addi t2, x0, 48 ('0')
    riscv64_emit_addi(s, 7, 0, 48)
    // sb t2, 0(t0)
    riscv64_emit_sb(s, 7, 5, 0)
    // addi t1, t1, 1
    riscv64_emit_addi(s, 6, 6, 1)
    // jal x0, .do_write (offset +76 bytes: 19 instructions forward)
    riscv64_emit_jal(s, 0, 76)

    // .check_neg:
    // addi t3, x0, 0 (negative flag = 0)
    riscv64_emit_addi(s, 28, 0, 0)
    // bge a0, x0, .loop_digits (offset +12 bytes: 3 instructions forward)
    riscv64_emit_bge(s, 10, 0, 12)
    // addi t3, x0, 1 (negative flag = 1)
    riscv64_emit_addi(s, 28, 0, 1)
    // sub a0, x0, a0 (a0 = -a0)
    riscv64_emit_sub(s, 10, 0, 10)

    // .loop_digits:
    // beq a0, x0, .finish_digits (offset +36 bytes: 9 instructions forward)
    riscv64_emit_beq(s, 10, 0, 36)
    // addi t4, x0, 10 (divisor = 10)
    riscv64_emit_addi(s, 29, 0, 10)
    // rem t5, a0, t4 (remainder = a0 % 10)
    riscv64_emit_rem(s, 30, 10, 29)
    // div a0, a0, t4 (quotient = a0 / 10)
    riscv64_emit_div(s, 10, 10, 29)
    // addi t5, t5, 48 (ASCII digit)
    riscv64_emit_addi(s, 30, 30, 48)
    // addi t0, t0, -1 (decrement buffer pointer)
    riscv64_emit_addi(s, 5, 5, 0 - 1)
    // sb t5, 0(t0)
    riscv64_emit_sb(s, 30, 5, 0)
    // addi t1, t1, 1 (increment length)
    riscv64_emit_addi(s, 6, 6, 1)
    // jal x0, .loop_digits (offset -32 bytes: 8 instructions backward)
    riscv64_emit_jal(s, 0, 0 - 32)

    // .finish_digits:
    // beq t3, x0, .do_write (offset +16 bytes: 4 instructions forward)
    riscv64_emit_beq(s, 28, 0, 16)
    // addi t0, t0, -1
    riscv64_emit_addi(s, 5, 5, 0 - 1)
    // addi t2, x0, 45 ('-')
    riscv64_emit_addi(s, 7, 0, 45)
    // sb t2, 0(t0)
    riscv64_emit_sb(s, 7, 5, 0)
    // addi t1, t1, 1
    riscv64_emit_addi(s, 6, 6, 1)

    // .do_write:
    // a0 = 1 (stdout)
    riscv64_emit_li(s, 10, 1)
    // a1 = t0 (buffer address)
    riscv64_emit_mv(s, 11, 5)
    // a2 = t1 (byte length)
    riscv64_emit_mv(s, 12, 6)
    // a7 = 64 (SYS_write on Linux RISC-V)
    riscv64_emit_li(s, 17, 64)
    // ecall
    riscv64_emit_ecall(s)

    // Epilogue:
    // ld ra, 56(sp)
    riscv64_emit_ld(s, 1, 2, 56)
    // ld s0, 48(sp)
    riscv64_emit_ld(s, 8, 2, 48)
    // addi sp, sp, 64
    riscv64_emit_addi(s, 2, 2, 64)
    // ret
    riscv64_emit_ret(s)
    return 0

fn riscv64_synth_emit_call_alloc s
    // WHY: Emits subroutine call to native __alloc bump allocator.
    s.rv_needs_alloc = 1
    call_off = s.rv_code.len()
    riscv64_emit_jal(s, 1, 0) // Placeholder JAL ra, 0

    call_rel = Riscv64CallReloc()
    call_rel.rv_cr_patch_offset = call_off
    call_rel.rv_cr_target_name = "__alloc"
    push(s.rv_call_relocs, call_rel)
    return 0

fn riscv64_synth_emit_alloc_helper s
    // WHY: Emits pure RISC-V silicon bump-arena memory allocator with zero libc dependency.
    // Inputs: a0 (x10) = requested byte size. Output: a0 (x10) = pointer to allocated memory.
    s.rv_alloc_off = s.rv_code.len()

    // 0: Round requested size up to 16 bytes:
    // addi a0, a0, 15
    riscv64_emit_addi(s, 10, 10, 15)
    // andi a0, a0, -16 (0xFF0 = 4080)
    riscv64_emit_andi(s, 10, 10, 0 - 16)

    // 1: Locate _heap_ptr storage at end of function via PC-relative AUIPC:
    // Inst 2: auipc t0, 0 (t0 = PC of inst 2)
    // _heap_ptr is located at Inst 27 (offset 25 instructions = 100 bytes forward from inst 2)
    riscv64_emit_auipc(s, 5, 0)
    // Inst 3: ld t1, 100(t0) -> load current heap pointer
    riscv64_emit_ld(s, 6, 5, 100)

    // Inst 4: bne t1, x0, .bump (offset +68 bytes: 17 instructions forward to inst 21)
    riscv64_emit_bne(s, 6, 0, 68)

    // ── Heap initialization via Linux sys_mmap(NULL, 1GB, PROT_READ|WRITE, MAP_ANON|PRIVATE, -1, 0) ──
    // Inst 5: addi sp, sp, -32 (preserve registers)
    riscv64_emit_addi(s, 2, 2, 0 - 32)
    // Inst 6: sd ra, 24(sp)
    riscv64_emit_sd(s, 1, 2, 24)
    // Inst 7: sd a0, 16(sp) (preserve requested size)
    riscv64_emit_sd(s, 10, 2, 16)
    // Inst 8: sd t0, 8(sp)  (preserve _heap_ptr address)
    riscv64_emit_sd(s, 5, 2, 8)

    // Inst 9: addi a0, x0, 0 (addr = NULL)
    riscv64_emit_addi(s, 10, 0, 0)
    // Inst 10: lui a1, 262144 (1GB virtual memory arena = 1073741824 bytes = 262144 * 4096)
    riscv64_emit_lui(s, 11, 262144)
    // Inst 11: addi a2, x0, 3 (PROT_READ | PROT_WRITE = 3)
    riscv64_emit_addi(s, 12, 0, 3)
    // Inst 12: addi a3, x0, 34 (MAP_PRIVATE | MAP_ANONYMOUS = 34)
    riscv64_emit_addi(s, 13, 0, 34)
    // Inst 13: addi a4, x0, -1 (fd = -1)
    riscv64_emit_addi(s, 14, 0, 0 - 1)
    // Inst 14: addi a5, x0, 0 (offset = 0)
    riscv64_emit_addi(s, 15, 0, 0)
    // Inst 15: addi a7, x0, 222 (SYS_mmap on Linux RISC-V = 222)
    riscv64_emit_li(s, 17, 222)
    // Inst 16: ecall -> a0 now holds allocated arena base address
    riscv64_emit_ecall(s)

    // Inst 17: ld ra, 24(sp)
    riscv64_emit_ld(s, 1, 2, 24)
    // Inst 18: ld a2, 16(sp) (restore requested size into a2)
    riscv64_emit_ld(s, 12, 2, 16)
    // Inst 19: ld t0, 8(sp)  (restore _heap_ptr address into t0)
    riscv64_emit_ld(s, 5, 2, 8)
    // Inst 20: addi sp, sp, 32
    riscv64_emit_addi(s, 2, 2, 32)

    // Inst 21: sd a0, 100(t0) (store arena base address into _heap_ptr)
    riscv64_emit_sd(s, 10, 5, 100)
    // Inst 22: mv t1, a0 (t1 = current heap pointer)
    riscv64_emit_mv(s, 6, 10)
    // Inst 23: mv a0, a2 (a0 = requested size)
    riscv64_emit_mv(s, 10, 12)

    // .bump (inst 24):
    // Inst 24: add t2, t1, a0 (compute next heap pointer: current + requested)
    riscv64_emit_add(s, 7, 6, 10)
    // Inst 25: sd t2, 100(t0) (update _heap_ptr)
    riscv64_emit_sd(s, 7, 5, 100)
    // Inst 26: mv a0, t1 (return previous heap pointer in a0)
    riscv64_emit_mv(s, 10, 6)
    // Inst 27: ret
    riscv64_emit_ret(s)

    // Inst 28..29: _heap_ptr storage (8 bytes initialized to 0, exactly 100 bytes from inst 2)
    riscv64_synth_emit32(s, 0)
    riscv64_synth_emit32(s, 0)
    return 0

// ── 9. Parser Utilities, Symbol Table & Scoping ───────────────────────────────

fn riscv64_synth_skip_whitespace_tokens toks pos_box
    // WHY: Advances token pointer past any empty newlines or comments.
    while get(pos_box, 0) < toks.len()
        k = toks[get(pos_box, 0)].tok_kind
        if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        else
            break
    return 0

fn riscv64_synth_find_struct s sname
    // WHY: Finds struct definition metadata by struct type name.
    i = 0
    while i < s.rv_structs.len()
        if s.rv_structs[i].rv_sd_name == sname
            return s.rv_structs[i]
        i = i + 1
    return 0

fn riscv64_synth_get_field_offset s sname fname
    // WHY: Resolves the 8-byte scaled offset of struct field fname.
    if sname != ""
        sdef = riscv64_synth_find_struct(s, sname)
        if sdef != 0
            f = 0
            while f < sdef.rv_sd_fields.len()
                if sdef.rv_sd_fields[f] == fname
                    return f * 8
                f = f + 1

    // Fallback 1: search across all defined structs
    i = 0
    while i < s.rv_structs.len()
        cur_def = s.rv_structs[i]
        f = 0
        while f < cur_def.rv_sd_fields.len()
            if cur_def.rv_sd_fields[f] == fname
                return f * 8
            f = f + 1
        i = i + 1

    // Fallback 2: search global fields registry
    gi = 0
    while gi < s.rv_global_fields.len()
        if s.rv_global_fields[gi] == fname
            return gi * 8
        gi = gi + 1
    push(s.rv_global_fields, fname)
    return (s.rv_global_fields.len() - 1) * 8

fn riscv64_synth_lookup_var s name
    // WHY: Finds SP-relative stack offset for variable identifier. Returns 0 if not found.
    i = 0
    while i < s.rv_locals.len()
        lv = s.rv_locals[i]
        if lv.rv_lv_name == name
            return lv.rv_lv_offset
        i = i + 1
    return 0

fn riscv64_synth_alloc_var s name
    // WHY: Allocates next 8-byte stack slot for variable name or returns existing offset.
    existing = riscv64_synth_lookup_var(s, name)
    if existing > 0
        return existing
    off = s.rv_stack_offset
    s.rv_stack_offset = s.rv_stack_offset + 8
    lv = Riscv64LocalVar()
    lv.rv_lv_name = name
    lv.rv_lv_offset = off
    push(s.rv_locals, lv)
    return off

// ── 10. Recursive-Descent Expression Synthesizer ───────────────────────────────

fn riscv64_synth_expr_primary s toks pos_box
    // WHY: Parses and synthesizes primary operands (integers, strings, identifiers, calls, grouping).
    // Result is always computed into primary register a0 (x10).
    pos = get(pos_box, 0)
    if pos >= toks.len()
        riscv64_emit_addi(s, 10, 0, 0)
        return 0

    t = toks[pos]
    k = t.tok_kind

    // 1. Integer Literal
    if k == TOK_INT()
        list_set(pos_box, 0, pos + 1)
        riscv64_emit_li(s, 10, t.tok_int_val)
        return 0

    // 2. String Literal
    if k == TOK_STR()
        list_set(pos_box, 0, pos + 1)
        ro_off = riscv64_synth_add_rodata_str(s, t.tok_text, 0)
        patch_pos = s.rv_code.len()
        riscv64_emit_lui(s, 10, 0)
        riscv64_emit_addi(s, 10, 10, 0)

        rel = Riscv64StringReloc()
        rel.rv_sr_patch_offset = patch_pos
        rel.rv_sr_rodata_offset = ro_off
        rel.rv_sr_reg = 10
        push(s.rv_str_relocs, rel)
        return 0

    // 3. Identifier or Call (Variable lookup, Field access, or Function Call)
    is_ident_or_call = 0
    if k == TOK_IDENT() or k == TOK_KW_SYSCALL() or k == TOK_KW_PRINT()
        is_ident_or_call = 1
    if is_ident_or_call == 1
        list_set(pos_box, 0, pos + 1)
        var_name = t.tok_text
        next_pos = get(pos_box, 0)

        // Function call: name(...)
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_LPAREN()
            list_set(pos_box, 0, next_pos + 1) // Consume '('
            // Parse arguments and push to stack in order
            arg_count = 0
            while get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind != TOK_RPAREN()
                riscv64_synth_compile_expr(s, toks, pos_box)
                riscv64_push_reg(s, 10) // Push a0
                arg_count = arg_count + 1
                cur_pos = get(pos_box, 0)
                if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, cur_pos + 1)

            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            // ── Intrinsic 1: syscall / সিসকল ─────────────────────────────────
            // Linux RISC-V 64: a7 = syscall number, a0..a5 = args 1..6
            if var_name == "syscall" or var_name == "সিসকল"
                if arg_count >= 7
                    riscv64_pop_reg(s, 15) // arg 6 (a5)
                if arg_count >= 6
                    riscv64_pop_reg(s, 14) // arg 5 (a4)
                if arg_count >= 5
                    riscv64_pop_reg(s, 13) // arg 4 (a3)
                if arg_count >= 4
                    riscv64_pop_reg(s, 12) // arg 3 (a2)
                if arg_count >= 3
                    riscv64_pop_reg(s, 11) // arg 2 (a1)
                if arg_count >= 2
                    riscv64_pop_reg(s, 10) // arg 1 (a0)
                if arg_count >= 1
                    riscv64_pop_reg(s, 17) // syscall number (a7)
                riscv64_emit_ecall(s)
                return 0

            // ── Intrinsic 2: malloc / mem_alloc / মেমরি_বরাদ্দ ──────────────
            if var_name == "malloc" or var_name == "mem_alloc" or var_name == "মেমরি_বরাদ্দ"
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // requested size in a0
                else
                    riscv64_emit_li(s, 10, 32)
                riscv64_synth_emit_call_alloc(s)
                return 0

            // ── Intrinsic 3: mem_word_read / mem_read / মেমরি_পড়ো ──────────
            if var_name == "mem_word_read" or var_name == "mem_read" or var_name == "মেমরি_পড়ো"
                if arg_count >= 2
                    riscv64_pop_reg(s, 11) // offset (a1)
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // base addr (a0)
                riscv64_emit_add(s, 10, 10, 11) // a0 = addr + offset
                riscv64_emit_ld(s, 10, 10, 0)   // ld a0, 0(a0)
                return 0

            // ── Intrinsic 4: mem_word_write / mem_write / মেমরি_লেখো ───────
            if var_name == "mem_word_write" or var_name == "mem_write" or var_name == "মেমরি_লেখো"
                if arg_count >= 3
                    riscv64_pop_reg(s, 12) // value (a2)
                if arg_count >= 2
                    riscv64_pop_reg(s, 11) // offset (a1)
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // base addr (a0)
                riscv64_emit_add(s, 10, 10, 11) // a0 = addr + offset
                riscv64_emit_sd(s, 12, 10, 0)   // sd a2, 0(a0)
                riscv64_emit_mv(s, 10, 12)      // return val in a0
                return 0

            // ── Intrinsic 5: mem_byte_read / mem_read_byte / মেমরি_বাইট_পড়ো
            if var_name == "mem_byte_read" or var_name == "mem_read_byte" or var_name == "মেমরি_বাইট_পড়ো"
                if arg_count >= 2
                    riscv64_pop_reg(s, 11) // offset (a1)
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // base addr (a0)
                riscv64_emit_add(s, 10, 10, 11)
                riscv64_emit_lbu(s, 10, 10, 0)  // lbu a0, 0(a0)
                return 0

            // ── Intrinsic 6: mem_byte_write / mem_write_byte / মেমরি_বাইট_লেখো
            if var_name == "mem_byte_write" or var_name == "mem_write_byte" or var_name == "মেমরি_বাইট_লেখো"
                if arg_count >= 3
                    riscv64_pop_reg(s, 12) // value (a2)
                if arg_count >= 2
                    riscv64_pop_reg(s, 11) // offset (a1)
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // base addr (a0)
                riscv64_emit_add(s, 10, 10, 11)
                riscv64_emit_sb(s, 12, 10, 0)   // sb a2, 0(a0)
                riscv64_emit_mv(s, 10, 12)
                return 0

            // ── Intrinsic 7: exit / বিদায় ─────────────────────────────────
            if var_name == "exit" or var_name == "বিদায়"
                if arg_count >= 1
                    riscv64_pop_reg(s, 10) // status code in a0
                else
                    riscv64_emit_addi(s, 10, 0, 0)
                riscv64_emit_li(s, 17, 93) // SYS_exit (93)
                riscv64_emit_ecall(s)
                return 0

            // ── Struct Constructor: StructName(...) ─────────────────────────
            sdef = riscv64_synth_find_struct(s, var_name)
            if sdef != 0
                fcount = sdef.rv_sd_fields.len()
                alloc_sz = (fcount + 1) * 8
                if alloc_sz < 32
                    alloc_sz = 32
                riscv64_emit_li(s, 10, alloc_sz)
                riscv64_synth_emit_call_alloc(s)
                // Struct pointer is now in a0
                if arg_count > 0
                    riscv64_push_reg(s, 10) // preserve struct pointer on stack
                    ai = arg_count - 1
                    while ai >= 0
                        riscv64_pop_reg(s, 11) // pop field value into a1
                        // ld a2, 0(sp) -> reload struct pointer into a2
                        riscv64_emit_ld(s, 12, 2, 0)
                        // sd a1, (ai*8)(a2)
                        riscv64_emit_sd(s, 11, 12, ai * 8)
                        ai = ai - 1
                    riscv64_pop_reg(s, 10) // restore struct pointer into a0
                return 0

            // ── Normal Function Call: Pop arguments into LP64 registers a0..a7
            if arg_count >= 8
                riscv64_pop_reg(s, 17)
            if arg_count >= 7
                riscv64_pop_reg(s, 16)
            if arg_count >= 6
                riscv64_pop_reg(s, 15)
            if arg_count >= 5
                riscv64_pop_reg(s, 14)
            if arg_count >= 4
                riscv64_pop_reg(s, 13)
            if arg_count >= 3
                riscv64_pop_reg(s, 12)
            if arg_count >= 2
                riscv64_pop_reg(s, 11)
            if arg_count >= 1
                riscv64_pop_reg(s, 10)

            // Emit JAL instruction with relocation placeholder
            call_off = s.rv_code.len()
            riscv64_emit_jal(s, 1, 0) // JAL ra, 0

            call_rel = Riscv64CallReloc()
            call_rel.rv_cr_patch_offset = call_off
            call_rel.rv_cr_target_name = var_name
            push(s.rv_call_relocs, call_rel)
            return 0

        // ── Struct Field Access: obj.field ──────────────────────────────────
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_DOT() or toks[next_pos].tok_text == ".")
            // Load base object pointer from local stack into a0
            off = riscv64_synth_lookup_var(s, var_name)
            if off > 0
                riscv64_emit_ld(s, 10, 2, off)
            else
                riscv64_emit_addi(s, 10, 0, 0)

            while get(pos_box, 0) < toks.len()
                cp = get(pos_box, 0)
                if toks[cp].tok_kind != TOK_DOT() and toks[cp].tok_text != "."
                    break
                list_set(pos_box, 0, cp + 1) // Consume '.'
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                    fn_tok = toks[get(pos_box, 0)]
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    f_off = riscv64_synth_get_field_offset(s, "", fn_tok.tok_text)
                    // ld a0, f_off(a0)
                    riscv64_emit_ld(s, 10, 10, f_off)
            return 0

        // Variable load: ld a0, off(sp)
        off = riscv64_synth_lookup_var(s, var_name)
        if off > 0
            riscv64_emit_ld(s, 10, 2, off)
        else
            riscv64_emit_addi(s, 10, 0, 0)
        return 0

    // 4. Parenthesized expression: ( expr )
    if k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1)
        riscv64_synth_compile_expr(s, toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_pos + 1)
        return 0

    // Fallback: advance and clear a0
    list_set(pos_box, 0, pos + 1)
    riscv64_emit_addi(s, 10, 0, 0)
    return 0

fn riscv64_synth_compile_expr s toks pos_box
    // WHY: Pratt / Precedence climbing binary expression evaluator for RISC-V 64.
    // Handles arithmetic (+, -, *, /, %) and branchless comparisons (==, !=, <, <=, >, >=).
    riscv64_synth_expr_primary(s, toks, pos_box)

    while get(pos_box, 0) < toks.len()
        pos = get(pos_box, 0)
        t = toks[pos]
        k = t.tok_kind

        is_op = 0
        if k == TOK_PLUS() or k == TOK_MINUS() or k == TOK_STAR() or k == TOK_SLASH() or k == TOK_PERCENT()
            is_op = 1
        if k == TOK_EQ() or k == TOK_NEQ() or k == TOK_LT() or k == TOK_LTE() or k == TOK_GT() or k == TOK_GTE()
            is_op = 1

        if is_op == 0
            break

        op_kind = k
        list_set(pos_box, 0, pos + 1) // Consume operator

        // Push left operand (a0) to stack
        riscv64_push_reg(s, 10)

        // Evaluate right operand into a0
        riscv64_synth_expr_primary(s, toks, pos_box)

        // Move right operand to a1, pop left operand back into a0
        riscv64_emit_mv(s, 11, 10)
        riscv64_pop_reg(s, 10)

        // Synthesize ALU operation
        if op_kind == TOK_PLUS()
            riscv64_emit_add(s, 10, 10, 11)
        elif op_kind == TOK_MINUS()
            riscv64_emit_sub(s, 10, 10, 11)
        elif op_kind == TOK_STAR()
            riscv64_emit_mul(s, 10, 10, 11)
        elif op_kind == TOK_SLASH()
            riscv64_emit_div(s, 10, 10, 11)
        elif op_kind == TOK_PERCENT()
            riscv64_emit_rem(s, 10, 10, 11)
        elif op_kind == TOK_EQ()
            // Branchless equality: sub a0, a0, a1; sltiu a0, a0, 1
            riscv64_emit_sub(s, 10, 10, 11)
            riscv64_emit_sltiu(s, 10, 10, 1)
        elif op_kind == TOK_NEQ()
            // Branchless inequality: sub a0, a0, a1; sltu a0, x0, a0
            riscv64_emit_sub(s, 10, 10, 11)
            riscv64_emit_sltu(s, 10, 0, 10)
        elif op_kind == TOK_LT()
            // Branchless signed less than: slt a0, a0, a1
            riscv64_emit_slt(s, 10, 10, 11)
        elif op_kind == TOK_LTE()
            // Branchless signed less/equal: slt a0, a1, a0; xori a0, a0, 1
            riscv64_emit_slt(s, 10, 11, 10)
            riscv64_emit_xori(s, 10, 10, 1)
        elif op_kind == TOK_GT()
            // Branchless signed greater than: slt a0, a1, a0
            riscv64_emit_slt(s, 10, 11, 10)
        elif op_kind == TOK_GTE()
            // Branchless signed greater/equal: slt a0, a0, a1; xori a0, a0, 1
            riscv64_emit_slt(s, 10, 10, 11)
            riscv64_emit_xori(s, 10, 10, 1)

    return 0

// ── 11. Statement Synthesizer ─────────────────────────────────────────────────

fn riscv64_synth_compile_statement s toks pos_box
    // WHY: Synthesizes execution bytes for statements (control flow, structs, loops, calls).
    pos = get(pos_box, 0)
    if pos >= toks.len()
        return 0

    t = toks[pos]
    k = t.tok_kind
    txt = t.tok_text

    // Skip redundant newlines, semicolons, comments
    if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
        list_set(pos_box, 0, pos + 1)
        return 0

    // Consume standalone block end markers (@end, end, শেষ)
    if k == TOK_KW_END() or k == TOK_DIR_END() or (k == TOK_IDENT() and (txt == "@end" or txt == "end" or txt == "শেষ"))
        list_set(pos_box, 0, pos + 1)
        return 0

    // ── 1. Output Statement: say / বলো / print / println / show / দেখাও ──────────
    is_print = 0
    if k == TOK_KW_PRINT()
        is_print = 1
    if k == TOK_IDENT() and (txt == "say" or txt == "বলো" or txt == "print" or txt == "println" or txt == "show" or txt == "দেখাও")
        is_print = 1

    if is_print == 1
        list_set(pos_box, 0, pos + 1) // Consume keyword
        next_pos = get(pos_box, 0)
        if next_pos < toks.len()
            next_tok = toks[next_pos]
            // Direct string constant print optimization:
            after_next = next_pos + 1
            is_simple_str = 0
            if next_tok.tok_kind == TOK_STR()
                if after_next >= toks.len() or toks[after_next].tok_kind == TOK_NEWLINE() or toks[after_next].tok_kind == TOK_SEMI() or toks[after_next].tok_kind == TOK_EOF()
                    is_simple_str = 1

            if is_simple_str == 1
                list_set(pos_box, 0, next_pos + 1)
                riscv64_emit_print_string(s, next_tok.tok_text)
                return 0

        // General expression print (numbers, variables, calculations):
        riscv64_synth_compile_expr(s, toks, pos_box)
        riscv64_synth_emit_call_print_int(s)
        return 0

    // ── 2. Control Flow: return / ফেরত ─────────────────────────────────────────
    if k == TOK_KW_RETURN() or (k == TOK_IDENT() and (txt == "return" or txt == "ফেরত"))
        list_set(pos_box, 0, pos + 1) // Consume keyword
        next_pos = get(pos_box, 0)
        has_expr = 0
        if next_pos < toks.len()
            nt = toks[next_pos]
            if nt.tok_kind != TOK_NEWLINE() and nt.tok_kind != TOK_SEMI() and nt.tok_kind != TOK_EOF()
                has_expr = 1

        if has_expr == 1
            riscv64_synth_compile_expr(s, toks, pos_box)
        else
            riscv64_emit_addi(s, 10, 0, 0)

        if s.rv_in_function == 1
            riscv64_emit_epilogue(s)
        else
            // Top-level return: exit with code in a0 via Linux SYS_exit (93)
            riscv64_emit_li(s, 17, 93)
            riscv64_emit_ecall(s)
        return 0

    // ── 3. Loop Control: break / থামো & continue / চলুক ───────────────────────
    if k == TOK_KW_BREAK() or (k == TOK_IDENT() and (txt == "break" or txt == "থামো"))
        list_set(pos_box, 0, pos + 1)
        if s.rv_loop_breaks.len() > 0
            p_off = s.rv_code.len()
            riscv64_emit_jal(s, 0, 0) // Placeholder JAL x0, 0
            curr_brk_list = s.rv_loop_breaks[s.rv_loop_breaks.len() - 1]
            push(curr_brk_list, p_off)
        return 0

    if k == TOK_KW_CONTINUE() or (k == TOK_IDENT() and (txt == "continue" or txt == "চলুক" or txt == "চলো"))
        list_set(pos_box, 0, pos + 1)
        if s.rv_loop_starts.len() > 0
            loop_hdr = s.rv_loop_starts[s.rv_loop_starts.len() - 1]
            cur_off = s.rv_code.len()
            rel_bytes = loop_hdr - cur_off
            riscv64_emit_jal(s, 0, rel_bytes)
        return 0

    // ── 4. Struct Definition: struct / গঠন / @struct ──────────────────────────
    is_struct = 0
    if k == TOK_KW_STRUCT() or k == TOK_DIR_STRUCT()
        is_struct = 1
    if k == TOK_IDENT() and (txt == "struct" or txt == "গঠন" or txt == "@struct")
        is_struct = 1

    if is_struct == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'struct'

        sname_tok = toks[get(pos_box, 0)]
        sname = sname_tok.tok_text
        list_set(pos_box, 0, get(pos_box, 0) + 1)

        fields = list()
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)
                break
            if cur_k == TOK_KW_FN() or cur_k == TOK_DIR_FN() or cur_k == TOK_KW_STRUCT() or cur_k == TOK_DIR_STRUCT()
                break
            if cur_k == TOK_IDENT() and (cur_txt == "fn" or cur_txt == "কাজ" or cur_txt == "struct" or cur_txt == "গঠন")
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            if cur_k == TOK_IDENT()
                push(fields, cur_txt)
                // Skip optional type annotation: : i64
                nxt = cur_p + 1
                if nxt < toks.len() and toks[nxt].tok_kind == TOK_COLON()
                    list_set(pos_box, 0, nxt + 1)
                    if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                        list_set(pos_box, 0, get(pos_box, 0) + 1)

            list_set(pos_box, 0, get(pos_box, 0) + 1)

        sdef = Riscv64StructDef()
        sdef.rv_sd_name = sname
        sdef.rv_sd_fields = fields
        push(s.rv_structs, sdef)
        return 0

    // ── 5. Struct Field Assignment: obj.field = expr ─────────────────────────────
    if k == TOK_IDENT()
        p1 = pos + 1
        p2 = pos + 2
        p3 = pos + 3
        if p3 < toks.len()
            t1 = toks[p1]
            t2 = toks[p2]
            t3 = toks[p3]
            is_dot = 0
            if t1.tok_kind == TOK_DOT() or t1.tok_text == "."
                is_dot = 1
            is_assign = 0
            if t3.tok_kind == TOK_ASSIGN() or t3.tok_text == "="
                is_assign = 1

            if is_dot == 1 and t2.tok_kind == TOK_IDENT() and is_assign == 1
                obj_name = txt
                field_name = t2.tok_text
                list_set(pos_box, 0, p3 + 1) // Consume obj, '.', field, '='

                // Evaluate expr into a0
                riscv64_synth_compile_expr(s, toks, pos_box)

                // Save value: push a0
                riscv64_push_reg(s, 10)

                // Load obj pointer into a1
                obj_off = riscv64_synth_lookup_var(s, obj_name)
                if obj_off > 0
                    riscv64_emit_ld(s, 11, 2, obj_off)
                else
                    riscv64_emit_addi(s, 11, 0, 0)

                // Pop value into a0
                riscv64_pop_reg(s, 10)

                // Store value to field: sd a0, f_off(a1)
                f_off = riscv64_synth_get_field_offset(s, "", field_name)
                riscv64_emit_sd(s, 10, 11, f_off)
                return 0

    // ── 6. Conditionals: if / elif / else (যদি / নাহলে_যদি / নাহলে / @if...) ──
    is_if = 0
    if k == TOK_KW_IF() or k == TOK_DIR_IF()
        is_if = 1
    if k == TOK_IDENT() and (txt == "if" or txt == "যদি" or txt == "@if")
        is_if = 1

    if is_if == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'if'

        // Evaluate conditional expression into a0
        riscv64_synth_compile_expr(s, toks, pos_box)

        // beq a0, x0, next_branch (branch if zero/false)
        patch_next_branch = s.rv_code.len()
        riscv64_emit_beq(s, 10, 0, 0) // Placeholder

        end_patches = list()
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile then-block statements
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE() or cur_k == TOK_KW_END() or cur_k == TOK_DIR_END()
                break
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else" or cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end")
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            before_stmt_p = get(pos_box, 0)
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == before_stmt_p
                list_set(pos_box, 0, before_stmt_p + 1)

            if cur_t.tok_span.span_start_line == base_line
                break

        // Check if there is an elif or else coming next
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        has_subsequent = 0
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF() or cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()
                has_subsequent = 1
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif" or cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else")
                has_subsequent = 1

        if has_subsequent == 1
            jmp_end = s.rv_code.len()
            riscv64_emit_jal(s, 0, 0) // Placeholder JAL x0, 0
            push(end_patches, jmp_end)

            cur_off = s.rv_code.len()
            riscv64_synth_patch_b(s, patch_next_branch, 0, 10, 0, cur_off)
        else
            cur_off = s.rv_code.len()
            riscv64_synth_patch_b(s, patch_next_branch, 0, 10, 0, cur_off)

        // Loop over elif branches
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            is_elif = 0
            if cur_k == TOK_KW_ELIF() or cur_k == TOK_DIR_ELIF()
                is_elif = 1
            if cur_k == TOK_IDENT() and (cur_txt == "elif" or cur_txt == "নাহলে_যদি" or cur_txt == "@elif")
                is_elif = 1
            if is_elif == 0
                break

            elif_line = cur_t.tok_span.span_start_line
            list_set(pos_box, 0, cur_p + 1) // Consume 'elif'
            riscv64_synth_compile_expr(s, toks, pos_box)

            patch_next_branch = s.rv_code.len()
            riscv64_emit_beq(s, 10, 0, 0) // beq a0, x0, next_branch

            riscv64_synth_skip_whitespace_tokens(toks, pos_box)

            while get(pos_box, 0) < toks.len()
                riscv64_synth_skip_whitespace_tokens(toks, pos_box)
                cur_p2 = get(pos_box, 0)
                if cur_p2 >= toks.len()
                    break
                ct2 = toks[cur_p2]
                ck2 = ct2.tok_kind
                cx2 = ct2.tok_text
                if ck2 == TOK_KW_ELIF() or ck2 == TOK_DIR_ELIF() or ck2 == TOK_KW_ELSE() or ck2 == TOK_DIR_ELSE() or ck2 == TOK_KW_END() or ck2 == TOK_DIR_END()
                    break
                if ck2 == TOK_IDENT() and (cx2 == "elif" or cx2 == "নাহলে_যদি" or cx2 == "@elif" or cx2 == "else" or cx2 == "নাহলে" or cx2 == "@else" or cx2 == "end" or cx2 == "শেষ" or cx2 == "@end")
                    break
                if ct2.tok_span.span_start_line > elif_line and ct2.tok_span.span_start_col <= base_col
                    break
                b_p2 = get(pos_box, 0)
                riscv64_synth_compile_statement(s, toks, pos_box)
                if get(pos_box, 0) == b_p2
                    list_set(pos_box, 0, b_p2 + 1)
                if ct2.tok_span.span_start_line == elif_line
                    break

            jmp_end = s.rv_code.len()
            riscv64_emit_jal(s, 0, 0)
            push(end_patches, jmp_end)

            cur_off = s.rv_code.len()
            riscv64_synth_patch_b(s, patch_next_branch, 0, 10, 0, cur_off)

        // Check for else
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            is_else = 0
            if cur_k == TOK_KW_ELSE() or cur_k == TOK_DIR_ELSE()
                is_else = 1
            if cur_k == TOK_IDENT() and (cur_txt == "else" or cur_txt == "নাহলে" or cur_txt == "@else")
                is_else = 1
            if is_else == 1
                else_line = cur_t.tok_span.span_start_line
                list_set(pos_box, 0, cur_p + 1) // Consume 'else'
                riscv64_synth_skip_whitespace_tokens(toks, pos_box)
                while get(pos_box, 0) < toks.len()
                    riscv64_synth_skip_whitespace_tokens(toks, pos_box)
                    cur_p3 = get(pos_box, 0)
                    if cur_p3 >= toks.len()
                        break
                    ct3 = toks[cur_p3]
                    ck3 = ct3.tok_kind
                    cx3 = ct3.tok_text
                    if ck3 == TOK_KW_END() or ck3 == TOK_DIR_END()
                        break
                    if ck3 == TOK_IDENT() and (cx3 == "end" or cx3 == "শেষ" or cx3 == "@end")
                        break
                    if ct3.tok_span.span_start_line > else_line and ct3.tok_span.span_start_col <= base_col
                        break
                    b_p3 = get(pos_box, 0)
                    riscv64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p3
                        list_set(pos_box, 0, b_p3 + 1)
                    if ct3.tok_span.span_start_line == else_line
                        break

        // Consume optional end / @end / শেষ
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Backpatch all exit jumps to current offset
        cur_off = s.rv_code.len()
        ei = 0
        while ei < end_patches.len()
            p_end = end_patches[ei]
            riscv64_synth_patch_jal(s, p_end, 0, cur_off)
            ei = ei + 1
        return 0

    // ── 7. Loops: while / যতক্ষণ / @while ─────────────────────────────────────
    is_while = 0
    if k == TOK_KW_WHILE() or k == TOK_DIR_WHILE()
        is_while = 1
    if k == TOK_IDENT() and (txt == "while" or txt == "যতক্ষণ" or txt == "@while")
        is_while = 1

    if is_while == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'while'

        loop_header = s.rv_code.len()
        push(s.rv_loop_starts, loop_header)
        loop_brks = list()
        push(s.rv_loop_breaks, loop_brks)

        // Evaluate condition into a0
        riscv64_synth_compile_expr(s, toks, pos_box)

        // beq a0, x0, loop_exit
        patch_loop_exit = s.rv_code.len()
        riscv64_emit_beq(s, 10, 0, 0) // Placeholder

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile while body statements
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            b_p = get(pos_box, 0)
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Backward jump to loop_header: jal x0, loop_header
        cur_off = s.rv_code.len()
        rel_bytes = loop_header - cur_off
        riscv64_emit_jal(s, 0, rel_bytes)

        // Backpatch loop_exit
        loop_exit_off = s.rv_code.len()
        riscv64_synth_patch_b(s, patch_loop_exit, 0, 10, 0, loop_exit_off)

        // Backpatch all break jumps
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            riscv64_synth_patch_jal(s, brk_patch, 0, loop_exit_off)
            bi = bi + 1

        pop(s.rv_loop_starts)
        pop(s.rv_loop_breaks)
        return 0

    // ── 8. Loops: for / প্রতিটি / @for ───────────────────────────────────────
    is_for = 0
    if k == TOK_KW_FOR() or k == TOK_DIR_FOR()
        is_for = 1
    if k == TOK_IDENT() and (txt == "for" or txt == "প্রতিটি" or txt == "@for")
        is_for = 1

    if is_for == 1
        base_col = t.tok_span.span_start_col
        base_line = t.tok_span.span_start_line
        list_set(pos_box, 0, pos + 1) // Consume 'for'

        var_tok = toks[get(pos_box, 0)]
        var_name = var_tok.tok_text
        list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume var_name

        // Consume 'in' or 'মধ্যে' if present
        if get(pos_box, 0) < toks.len()
            in_t = toks[get(pos_box, 0)]
            if in_t.tok_kind == TOK_KW_IN() or (in_t.tok_kind == TOK_IDENT() and (in_t.tok_text == "in" or in_t.tok_text == "মধ্যে"))
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile start expression into a0
        riscv64_synth_compile_expr(s, toks, pos_box)
        var_off = riscv64_synth_alloc_var(s, var_name)
        riscv64_emit_sd(s, 10, 2, var_off)

        // Consume '..' if present
        if get(pos_box, 0) < toks.len()
            dot_t = toks[get(pos_box, 0)]
            if dot_t.tok_kind == TOK_DOTDOT() or dot_t.tok_text == ".."
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile end expression into a0
        riscv64_synth_compile_expr(s, toks, pos_box)
        end_var_name = "__end_" + var_name
        end_off = riscv64_synth_alloc_var(s, end_var_name)
        riscv64_emit_sd(s, 10, 2, end_off)

        loop_header = s.rv_code.len()
        push(s.rv_loop_starts, loop_header)
        loop_brks = list()
        push(s.rv_loop_breaks, loop_brks)

        // Compare var and end: ld a0, var_off(sp); ld a1, end_off(sp); bge a0, a1, loop_exit
        riscv64_emit_ld(s, 10, 2, var_off)
        riscv64_emit_ld(s, 11, 2, end_off)

        // bge a0, a1, loop_exit (exit if var >= end)
        patch_loop_exit = s.rv_code.len()
        riscv64_emit_bge(s, 10, 11, 0)

        riscv64_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile for body statements
        while get(pos_box, 0) < toks.len()
            riscv64_synth_skip_whitespace_tokens(toks, pos_box)
            cur_p = get(pos_box, 0)
            if cur_p >= toks.len()
                break
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text

            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                break
            if cur_t.tok_span.span_start_line > base_line and cur_t.tok_span.span_start_col <= base_col
                break

            b_p = get(pos_box, 0)
            riscv64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        riscv64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Increment var: ld a0, var_off(sp); addi a0, a0, 1; sd a0, var_off(sp)
        riscv64_emit_ld(s, 10, 2, var_off)
        riscv64_emit_addi(s, 10, 10, 1)
        riscv64_emit_sd(s, 10, 2, var_off)

        // jal x0, loop_header
        cur_off = s.rv_code.len()
        rel_bytes = loop_header - cur_off
        riscv64_emit_jal(s, 0, rel_bytes)

        // Backpatch loop_exit
        loop_exit_off = s.rv_code.len()
        riscv64_synth_patch_b(s, patch_loop_exit, 5, 10, 11, loop_exit_off)

        // Backpatch breaks
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            riscv64_synth_patch_jal(s, brk_patch, 0, loop_exit_off)
            bi = bi + 1

        pop(s.rv_loop_starts)
        pop(s.rv_loop_breaks)
        return 0

    // ── 9. Variable Declaration: let / চলক / ধরি / var ─────────────────────────
    is_let = 0
    if k == TOK_KW_LET()
        is_let = 1
    if k == TOK_IDENT() and (txt == "let" or txt == "চলক" or txt == "ধরি" or txt == "var")
        is_let = 1

    if is_let == 1
        list_set(pos_box, 0, pos + 1) // Consume let
        var_pos = get(pos_box, 0)
        if var_pos < toks.len() and toks[var_pos].tok_kind == TOK_IDENT()
            var_name = toks[var_pos].tok_text
            list_set(pos_box, 0, var_pos + 1)
            eq_pos = get(pos_box, 0)
            if eq_pos < toks.len() and toks[eq_pos].tok_kind == TOK_ASSIGN()
                list_set(pos_box, 0, eq_pos + 1)
                riscv64_synth_compile_expr(s, toks, pos_box)
                off = riscv64_synth_alloc_var(s, var_name)
                riscv64_emit_sd(s, 10, 2, off)
        return 0

    // ── 10. Assignment: <var> = <expr> ─────────────────────────────────────────
    if k == TOK_IDENT()
        next_pos = pos + 1
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_ASSIGN()
            var_name = txt
            list_set(pos_box, 0, next_pos + 1) // Consume ident and '='
            riscv64_synth_compile_expr(s, toks, pos_box)
            off = riscv64_synth_alloc_var(s, var_name)
            riscv64_emit_sd(s, 10, 2, off)
            return 0

    // ── 11. Function Definition: fn / কাজ / @fn ────────────────────────────────
    is_fn = 0
    if k == TOK_KW_FN() or k == TOK_DIR_FN()
        is_fn = 1
    if k == TOK_IDENT() and (txt == "fn" or txt == "কাজ" or txt == "@fn")
        is_fn = 1

    if is_fn == 1
        list_set(pos_box, 0, pos + 1) // Consume fn
        name_pos = get(pos_box, 0)
        fn_name = ""
        if name_pos < toks.len() and toks[name_pos].tok_kind == TOK_IDENT()
            fn_name = toks[name_pos].tok_text
            list_set(pos_box, 0, name_pos + 1)

        // Jump over function so top-level execution doesn't fall through into function body
        fn_jmp_patch = s.rv_code.len()
        riscv64_emit_jal(s, 0, 0) // Placeholder JAL x0, 0

        // Record function entry point (immediately after the skip jump)
        fn_entry = Riscv64Function()
        fn_entry.rv_fn_name = fn_name
        fn_entry.rv_fn_entry_offset = s.rv_code.len()
        push(s.rv_functions, fn_entry)

        // Reset frame locals
        s.rv_locals = list()
        s.rv_stack_offset = 16
        s.rv_in_function = 1

        // Parse parameter names until newline
        params = list()
        while get(pos_box, 0) < toks.len()
            p_tok = toks[get(pos_box, 0)]
            if p_tok.tok_kind == TOK_NEWLINE() or p_tok.tok_kind == TOK_SEMI()
                list_set(pos_box, 0, get(pos_box, 0) + 1)
                break
            if p_tok.tok_kind == TOK_IDENT()
                push(params, p_tok.tok_text)
            list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Emit function prologue
        riscv64_emit_prologue(s)

        // Save incoming argument registers (a0..a7 = x10..x17) into local stack slots
        pi = 0
        while pi < params.len()
            pname = params[pi]
            off = riscv64_synth_alloc_var(s, pname)
            if pi < 8
                arg_reg = 10 + pi
                riscv64_emit_sd(s, arg_reg, 2, off)
            pi = pi + 1

        // Parse function body statements until next function or EOF
        while get(pos_box, 0) < toks.len()
            cur_pos = get(pos_box, 0)
            ct = toks[cur_pos]
            if ct.tok_kind == TOK_KW_FN() or ct.tok_kind == TOK_DIR_FN()
                break
            if ct.tok_kind == TOK_IDENT() and (ct.tok_text == "fn" or ct.tok_text == "কাজ" or ct.tok_text == "@fn")
                break
            riscv64_synth_compile_statement(s, toks, pos_box)

        // Default epilogue at end of function
        riscv64_emit_addi(s, 10, 0, 0)
        riscv64_emit_epilogue(s)
        s.rv_in_function = 0

        // Patch jump to bypass function body during top-level execution
        after_fn_offset = s.rv_code.len()
        riscv64_synth_patch_jal(s, fn_jmp_patch, 0, after_fn_offset)
        return 0

    // Default: evaluate expression or advance token
    riscv64_synth_compile_expr(s, toks, pos_box)
    return 0

// ── 12. Master Program Synthesizer Entry Point ─────────────────────────────────

fn riscv64_synth_compile_program tokens
    // WHY: Master orchestration entry point. Transforms complete token stream into
    // relocatable RISC-V 64 machine code, sets up top-level stack frames, patches string relocations
    // against the Linux ELF virtual address space (0x400000+), and resolves call sites.
    s = riscv64_synth_new()

    // 1. Emit top-level stack frame prologue at entry point (offset 0)
    riscv64_emit_prologue(s)

    // 2. Synthesize all functions, structs, and statements
    pos_box = [0]
    has_top_level = 0
    while get(pos_box, 0) < tokens.len()
        cur_pos = get(pos_box, 0)
        cur_k = tokens[cur_pos].tok_kind
        if cur_k == TOK_EOF()
            break

        tok_item = tokens[cur_pos]
        is_fn_tok = 0
        if tok_item.tok_kind == TOK_KW_FN() or tok_item.tok_kind == TOK_DIR_FN()
            is_fn_tok = 1
        if tok_item.tok_kind == TOK_IDENT() and (tok_item.tok_text == "fn" or tok_item.tok_text == "কাজ" or tok_item.tok_text == "@fn")
            is_fn_tok = 1
        if tok_item.tok_kind == TOK_KW_STRUCT() or tok_item.tok_kind == TOK_DIR_STRUCT()
            is_fn_tok = 1
        if tok_item.tok_kind == TOK_IDENT() and (tok_item.tok_text == "struct" or tok_item.tok_text == "গঠন" or tok_item.tok_text == "@struct")
            is_fn_tok = 1

        if is_fn_tok == 0 and tok_item.tok_kind != TOK_NEWLINE() and tok_item.tok_kind != TOK_SEMI()
            has_top_level = 1

        riscv64_synth_compile_statement(s, tokens, pos_box)

    // 3. If there were NO top-level statements, but 'main' or 'মূল' exists, call main() automatically!
    has_main = 0
    main_name = ""
    if has_top_level == 0
        fi = 0
        while fi < s.rv_functions.len()
            fn_candidate = s.rv_functions[fi].rv_fn_name
            if fn_candidate == "main" or fn_candidate == "মূল"
                has_main = 1
                main_name = fn_candidate
            fi = fi + 1
        if has_main == 1
            call_off = s.rv_code.len()
            riscv64_emit_jal(s, 1, 0) // Placeholder JAL ra, 0
            call_rel = Riscv64CallReloc()
            call_rel.rv_cr_patch_offset = call_off
            call_rel.rv_cr_target_name = main_name
            push(s.rv_call_relocs, call_rel)

    // 4. Top-level exit epilogue
    if has_top_level == 1 or has_main == 0
        riscv64_emit_addi(s, 10, 0, 0) // exit code 0 in a0
    // Exit via Linux sys_exit (syscall 93 on RISC-V) with status code in a0
    riscv64_emit_li(s, 17, 93)
    riscv64_emit_ecall(s)

    // 5. Emit print_int helper if required
    if s.rv_needs_print_int == 1
        riscv64_synth_emit_print_int_helper(s)

    // 5b. Emit sovereign alloc helper if required
    if s.rv_needs_alloc == 1
        riscv64_synth_emit_alloc_helper(s)

    // 6. Resolve Inter-Procedural Call Relocations (JAL ra, disp20)
    ci = 0
    while ci < s.rv_call_relocs.len()
        cr = s.rv_call_relocs[ci]
        resolved_addr = 0
        if cr.rv_cr_target_name == "__print_int"
            resolved_addr = s.rv_print_int_off
        elif cr.rv_cr_target_name == "__alloc"
            resolved_addr = s.rv_alloc_off
        else
            k = 0
            while k < s.rv_functions.len()
                fn_item = s.rv_functions[k]
                if fn_item.rv_fn_name == cr.rv_cr_target_name
                    resolved_addr = fn_item.rv_fn_entry_offset
                k = k + 1

        riscv64_synth_patch_jal(s, cr.rv_cr_patch_offset, 1, resolved_addr)
        ci = ci + 1

    // 7. Resolve 64-Bit Virtual Memory String Relocations
    total_code_size = s.rv_code.len()
    rodata_base_vaddr = 4194424 + total_code_size // 0x400078 + total_code_size

    ri = 0
    while ri < s.rv_str_relocs.len()
        rel = s.rv_str_relocs[ri]
        target_vaddr = rodata_base_vaddr + rel.rv_sr_rodata_offset
        riscv64_synth_patch_lui_addi(s, rel.rv_sr_patch_offset, rel.rv_sr_reg, target_vaddr)
        ri = ri + 1

    return s

// ── 13. ELF64 RISC-V Container Header Generator ───────────────────────────────

fn riscv64_elf_emit_executable code_bytes rodata_bytes out_path
    // WHY: Packages the compiled RISC-V 64 machine instructions and read-only constants into a
    // bit-perfect Linux ELF64 standalone executable container and persists it to disk with 0755 permissions.
    //
    // Binary Layout:
    //   - Base Virtual Address: 0x400000 (4194304)
    //   - ELF64 Header: 64 bytes (0x00 - 0x3F)
    //   - PT_LOAD Program Header: 56 bytes (0x40 - 0x77)
    //   - Total Header Overhead: 120 bytes (0x78)
    //   - Entry Point: 0x400078 (4194424) -> code_bytes starts immediately at offset 120
    //   - Machine: EM_RISCV = 243 (0x00F3)
    //   - Single PT_LOAD segment encompassing header, code, and rodata.
    total_hdr_size = 120 // 64 (ELF Header) + 56 (PT_LOAD Program Header)
    code_size = code_bytes.len()
    rodata_size = rodata_bytes.len()
    total_size = total_hdr_size + code_size + rodata_size
    base_vaddr = 4194304  // 0x400000
    entry_vaddr = 4194424 // 0x400078 (0x400000 + 120)

    elf = list()

    // ── 1. ELF64 Header (64 bytes) ──────────────────────────────────────────
    // e_ident: Magic \x7FELF, Class 2 (64-bit), Data 1 (Little-Endian), Version 1, OS/ABI 0 (System V), 8 padding zeroes
    push(elf, 127) // 0x7F
    push(elf, 69)  // 'E'
    push(elf, 76)  // 'L'
    push(elf, 70)  // 'F'
    push(elf, 2)   // ELFCLASS64 (64-bit)
    push(elf, 1)   // ELFDATA2LSB (Little-Endian)
    push(elf, 1)   // EV_CURRENT (1)
    push(elf, 0)   // ELFOSABI_NONE / System V
    push(elf, 0)   // ABI Version (0)
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad
    push(elf, 0)   // Pad (total 16 bytes e_ident)

    // e_type: ET_EXEC (2) (2 bytes)
    push(elf, 2)
    push(elf, 0)

    // e_machine: EM_RISCV (243 = 0x00F3) (2 bytes)
    push(elf, 243)
    push(elf, 0)

    // e_version: EV_CURRENT (1) (4 bytes)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_entry: 0x400078 (4194424) (8 bytes)
    push(elf, 120)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_phoff: 64 (0x40) (8 bytes) -> Program header table follows immediately
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_shoff: 0 (8 bytes) -> No section headers in raw sovereign binary
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_flags: 0 (4 bytes) -> LP64 base ABI
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_ehsize: 64 (2 bytes)
    push(elf, 64)
    push(elf, 0)

    // e_phentsize: 56 (2 bytes)
    push(elf, 56)
    push(elf, 0)

    // e_phnum: 1 (2 bytes) -> Single PT_LOAD segment
    push(elf, 1)
    push(elf, 0)

    // e_shentsize: 0 (2 bytes)
    push(elf, 0)
    push(elf, 0)

    // e_shnum: 0 (2 bytes)
    push(elf, 0)
    push(elf, 0)

    // e_shstrndx: 0 (2 bytes)
    push(elf, 0)
    push(elf, 0)

    // ── 2. Program Header Table (56 bytes, PT_LOAD) ─────────────────────────
    // p_type: PT_LOAD (1) (4 bytes)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_flags: PF_R | PF_W | PF_X = 7 (Read, Write, Execute) (4 bytes)
    push(elf, 7)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_offset: 0 (8 bytes)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_vaddr: 0x400000 (4194304) (8 bytes)
    push(elf, 0)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_paddr: 0x400000 (4194304) (8 bytes)
    push(elf, 0)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_filesz: total_size (8 bytes)
    push(elf, total_size % 256)
    push(elf, (total_size / 256) % 256)
    push(elf, (total_size / 65536) % 256)
    push(elf, (total_size / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_memsz: total_size (8 bytes)
    push(elf, total_size % 256)
    push(elf, (total_size / 256) % 256)
    push(elf, (total_size / 65536) % 256)
    push(elf, (total_size / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_align: 65536 (0x10000 = 64KB) (8 bytes)
    push(elf, 0)
    push(elf, 0)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // ── 3. Append Executable Machine Code ───────────────────────────────────
    ci = 0
    while ci < code_size
        push(elf, code_bytes[ci])
        ci = ci + 1

    // ── 4. Append Read-Only Data (.rodata) ───────────────────────────────────
    di = 0
    while di < rodata_size
        push(elf, rodata_bytes[di])
        di = di + 1

    // ── 5. Direct Binary Persistence to Filesystem ─────────────────────────
    w_res = file_write_bytes(out_path, elf)
    res = Riscv64ElfResult()
    if w_res < 0
        res.rv_ew_success = 0
        res.rv_ew_error_msg = "Failed to write ELF64 RISC-V executable to " + out_path
        return res

    // ── 6. Grant Executable Permissions via Linux sys_chmod (syscall 90) ────
    // 493 decimal = 0755 octal (rwxr-xr-x)
    syscall(90, out_path, 493, 0, 0, 0, 0)

    res.rv_ew_success = 1
    res.rv_ew_out_path = out_path
    res.rv_ew_file_size = elf.len()
    res.rv_ew_entry_vaddr = entry_vaddr
    res.rv_ew_error_msg = ""
    return res
