// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN ARM64 (AARCH64) MACHINE CODE SYNTHESIZER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Direct Silicon Binary Generation
// 🏛️ File: src/compiler/backend/targets/arm64/synthesizer.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Bridges the Abstract Syntax Tree / Token Stream directly to executable ARM64
//    (AArch64 / ARMv8-A+) silicon instructions, eliminating any dependence on external
//    assemblers or toolchains (as, gas, clang, gcc, llvm).
// 2. High-Throughput Direct Synthesis: Generates raw 32-bit fixed-width instruction words
//    in a single pass with deterministic backpatching for branch targets, string addresses,
//    loops, conditionals, structs, and inter-procedural call sites.
// 3. Implements Standard AAPCS64 (ARM 64-bit Architecture Procedure Call Standard):
//    - Strict 16-byte stack frame alignment (SP mod 16 == 0 at all times).
//    - FP (X29) / LR (X30) frame records.
//    - Fast register parameter passing in X0 through X7.
//    - Primary scalar return values delivered in X0.
// 4. Built-in Sovereign Micro-Runtime Helpers:
//    - Synthesizes high-performance integer-to-decimal ASCII conversion routines on the stack.
//    - Direct Linux AArch64 syscalls (X8=64 for SYS_write, X8=93 for SYS_exit, X8=222 for SYS_mmap).
//    - Pure ARM64 bump arena memory allocator (__alloc) with zero C runtime dependencies.
// 5. Complete Sovereign Control Flow:
//    - Synthesizes hardware jumps for while/for loops, if/elif/else branching trees,
//      break/continue jump targets, struct field manipulation, and Linux system calls.
// 6. Direct ELF64 AArch64 Container Header Generation:
//    - Emits standalone Linux ELF64 binaries with 64KB page alignment, EM_AARCH64 (183),
//      and entry point at 0x400078 with executable permissions (0755).
// ==============================================================================

import "universe/core/collections"
import "universe/core/string"

import "compiler/frontend/lexer/token_kind"
import "compiler/frontend/lexer/token"

// ── 1. Data Models ────────────────────────────────────────────────────────────

// WHY: Records a 64-bit virtual memory relocation for string constants
struct Arm64StringReloc
    sr_patch_offset     // Byte index in code_bytes where the 4-instruction MOVZ/MOVK quad begins
    sr_rodata_offset    // Byte index in rodata_bytes where the UTF-8 string payload starts
    sr_reg              // Target register index (0 for X0, 1 for X1, etc.)

// WHY: Maps a local variable identifier to an SP-relative positive stack byte offset
struct Arm64LocalVar
    lv_name             // Variable identifier string
    lv_offset           // Positive stack offset in bytes: accessed as [sp, #lv_offset]

// WHY: Records a function definition entry point for inter-procedural call site resolution
struct Arm64Function
    fn_name             // Function identifier string
    fn_entry_offset     // Byte offset in code_bytes where the function prologue starts

// WHY: Records an unresolved 26-bit PC-relative subroutine call displacement
struct Arm64CallReloc
    cr_patch_offset     // Byte index in code_bytes where the 4-byte BL instruction is located
    cr_target_name      // Target function identifier or "__print_int" / "__alloc"

// WHY: Models struct schema definitions and field member offsets
struct Arm64StructDef
    sd_name             // Struct type name string
    sd_fields           // List of field name strings

// WHY: Return container for ELF64 container synthesis results
struct Arm64ElfResult
    ew_success          // 1 on success, 0 on failure
    ew_out_path         // Destination binary path string
    ew_file_size        // Total byte count written to disk
    ew_entry_vaddr      // Absolute virtual memory entry address (0x400078 = 4194424)
    ew_error_msg        // Human-readable error diagnostic

// WHY: Encapsulates mutable compilation state for ARM64 silicon code generation
struct Arm64Synthesizer
    synth_code          // List of machine code bytes (integers 0..255)
    synth_rodata        // List of read-only data bytes (.rodata segment)
    synth_str_relocs    // List of Arm64StringReloc structs
    synth_call_relocs   // List of Arm64CallReloc structs
    synth_locals        // List of Arm64LocalVar structs for current function frame
    synth_functions     // List of Arm64Function structs
    synth_stack_offset  // Next available local variable stack offset (16, 24, 32...)
    synth_needs_print_int // Flag: 1 if integer printing helper must be emitted
    synth_print_int_off // Byte offset where print_int helper starts
    synth_loop_starts   // Stack of loop header byte offsets for 'continue'
    synth_loop_breaks   // Stack of lists of break patch offsets
    synth_structs       // List of Arm64StructDef structs
    synth_global_fields // List of global field name strings
    synth_needs_alloc   // Flag: 1 if bump allocator helper must be emitted
    synth_alloc_off     // Byte offset where bump allocator starts
    synth_in_function   // 1 if currently synthesizing inside a function, 0 if top-level

// ── 2. Constructor & Emitter Primitives ───────────────────────────────────────

fn arm64_synth_new
    // WHY: Allocates and initializes clean ARM64 synthesizer state.
    s = Arm64Synthesizer()
    s.synth_code = list()
    s.synth_rodata = list()
    s.synth_str_relocs = list()
    s.synth_call_relocs = list()
    s.synth_locals = list()
    s.synth_functions = list()
    s.synth_stack_offset = 16
    s.synth_needs_print_int = 0
    s.synth_print_int_off = 0
    s.synth_loop_starts = list()
    s.synth_loop_breaks = list()
    s.synth_structs = list()
    s.synth_global_fields = list()
    s.synth_needs_alloc = 0
    s.synth_alloc_off = 0
    s.synth_in_function = 0
    return s

fn arm64_synth_emit_byte s byte_val
    // WHY: Emits a single raw machine instruction byte into code_bytes.
    push(s.synth_code, (byte_val % 256 + 256) % 256)
    return s.synth_code.len()

fn arm64_synth_emit_bytes s byte_list
    // WHY: Appends an array of byte values sequentially.
    i = 0
    n = byte_list.len()
    while i < n
        push(s.synth_code, (byte_list[i] % 256 + 256) % 256)
        i = i + 1
    return s.synth_code.len()

fn arm64_synth_emit32 s inst_word
    // WHY: Emits 4 bytes in little-endian byte order for 32-bit fixed-width AArch64 instruction word.
    // In AArch64 architecture, all machine instructions are strictly 4 bytes, aligned to 4-byte boundaries.
    b0 = inst_word & 255
    b1 = (inst_word >> 8) & 255
    b2 = (inst_word >> 16) & 255
    b3 = (inst_word >> 24) & 255
    push(s.synth_code, b0)
    push(s.synth_code, b1)
    push(s.synth_code, b2)
    push(s.synth_code, b3)
    return s.synth_code.len()

fn arm64_synth_patch_u32 s offset val
    // WHY: Backpatches 4 bytes at a predetermined location in code_bytes.
    v = val
    if v < 0
        v = v + 4294967296
    list_set(s.synth_code, offset, v & 255)
    list_set(s.synth_code, offset + 1, (v >> 8) & 255)
    list_set(s.synth_code, offset + 2, (v >> 16) & 255)
    list_set(s.synth_code, offset + 3, (v >> 24) & 255)
    return 0

fn arm64_synth_patch_mov_imm64 s offset reg val
    // WHY: Patches a 4-instruction (16-byte) MOVZ + 3x MOVK sequence to load any 64-bit absolute address.
    // Resolves virtual memory relocations for string literals and global addresses.
    c0 = val & 65535
    c1 = (val >> 16) & 65535
    c2 = (val >> 32) & 65535
    c3 = (val >> 48) & 65535
    r = reg & 31
    w0 = 3531603968 | (0 << 21) | (c0 << 5) | r  // movz x<r>, #c0, lsl #0
    w1 = 4068474880 | (1 << 21) | (c1 << 5) | r  // movk x<r>, #c1, lsl #16
    w2 = 4068474880 | (2 << 21) | (c2 << 5) | r  // movk x<r>, #c2, lsl #32
    w3 = 4068474880 | (3 << 21) | (c3 << 5) | r  // movk x<r>, #c3, lsl #48
    arm64_synth_patch_u32(s, offset, w0)
    arm64_synth_patch_u32(s, offset + 4, w1)
    arm64_synth_patch_u32(s, offset + 8, w2)
    arm64_synth_patch_u32(s, offset + 12, w3)
    return 0

// ── 3. Read-Only Data (.rodata) Management ────────────────────────────────────

fn arm64_synth_add_rodata_str s str_text with_newline
    // WHY: Stores UTF-8 string payload into rodata_bytes and returns its starting offset.
    start_off = s.synth_rodata.len()
    slen = len(str_text)
    i = 0
    while i < slen
        c = char_at(str_text, i)
        push(s.synth_rodata, ord(c))
        i = i + 1
    if with_newline == 1
        push(s.synth_rodata, 10) // '\n' (ASCII 10)
    push(s.synth_rodata, 0)      // Null-terminator (ASCII 0)
    return start_off

// ── 4. ARM64 Instruction Encoders (Pure Mathematical Synthesis) ───────────────

fn arm64_emit_movz_x s reg imm16 shift
    // WHY: Emits `movz x<reg>, #<imm16>, lsl #<shift>` (0xD2800000 | (hw << 21) | (imm16 << 5) | reg).
    // Zeroes out all 64 bits of destination register and loads the 16-bit immediate into selected halfword lane.
    hw = (shift / 16) & 3
    imm = imm16 & 65535
    r = reg & 31
    word = 3531603968 | (hw << 21) | (imm << 5) | r
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_movk_x s reg imm16 shift
    // WHY: Emits `movk x<reg>, #<imm16>, lsl #<shift>` (0xF2800000 | (hw << 21) | (imm16 << 5) | reg).
    // Keeps existing register contents intact while modifying the targeted 16-bit halfword lane.
    hw = (shift / 16) & 3
    imm = imm16 & 65535
    r = reg & 31
    word = 4068474880 | (hw << 21) | (imm << 5) | r
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_mov_imm64 s reg val
    // WHY: Full 64-bit constant load using movz and movk chunks.
    // Deconstructs the 64-bit value into 4 16-bit halfwords (hw 0..3).
    // Uses MOVZ for chunk 0, and MOVK only for non-zero higher chunks to minimize code size.
    c0 = val & 65535
    c1 = (val >> 16) & 65535
    c2 = (val >> 32) & 65535
    c3 = (val >> 48) & 65535
    arm64_emit_movz_x(s, reg, c0, 0)
    if c1 != 0
        arm64_emit_movk_x(s, reg, c1, 16)
    if c2 != 0
        arm64_emit_movk_x(s, reg, c2, 32)
    if c3 != 0
        arm64_emit_movk_x(s, reg, c3, 48)
    return 0

fn arm64_emit_mov_reg s rd rm
    // WHY: MOV Xd, Xm (Hardware alias for ORR Xd, XZR, Xm: 0xAA0003E0 | (rm << 16) | rd).
    d = rd & 31
    m = rm & 31
    word = 2852127712 | (m << 16) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_add_x s rd rn rm
    // WHY: `add x<rd>, x<rn>, x<rm>` (0x8B000000 | (rm << 16) | (rn << 5) | rd).
    // Performs 64-bit integer addition without flags update.
    d = rd & 31
    n = rn & 31
    m = rm & 31
    word = 2332033024 | (m << 16) | (n << 5) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_sub_x s rd rn rm
    // WHY: `sub x<rd>, x<rn>, x<rm>` (0xCB000000 | (rm << 16) | (rn << 5) | rd).
    // Performs 64-bit integer subtraction without flags update.
    d = rd & 31
    n = rn & 31
    m = rm & 31
    word = 3405774848 | (m << 16) | (n << 5) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_mul_x s rd rn rm
    // WHY: `mul x<rd>, x<rn>, x<rm>` (0x9B007C00 | (rm << 16) | (rn << 5) | rd).
    // Hardware alias for MADD Xd, Xn, Xm, XZR. Multiplies two 64-bit integers.
    d = rd & 31
    n = rn & 31
    m = rm & 31
    word = 2600500224 | (m << 16) | (n << 5) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_sdiv_x s rd rn rm
    // WHY: `sdiv x<rd>, x<rn>, x<rm>` (0x9AC00C00 | (rm << 16) | (rn << 5) | rd).
    // Hardware signed 64-bit integer division. Truncates towards zero.
    d = rd & 31
    n = rn & 31
    m = rm & 31
    word = 2596277248 | (m << 16) | (n << 5) | d
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_cmp_x s rn rm
    // WHY: `subs xzr, x<rn>, x<rm>` (0xEB00001F | (rm << 16) | (rn << 5)).
    // Subtracts Rm from Rn, updates NZCV flags, and discards arithmetic result via XZR.
    n = rn & 31
    m = rm & 31
    word = 3942645791 | (m << 16) | (n << 5)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_b_cond s cond offset_words
    // WHY: `b.<cond>` (0x54000000 | ((offset_words & 0x7FFFF) << 5) | (cond & 0xF)).
    // Conditional branch with 19-bit signed word displacement (+/- 1MB range).
    // Conditions: EQ=0, NE=1, GE=10, LT=11, GT=12, LE=13.
    off = offset_words & 524287
    c = cond & 15
    word = 1409286144 | (off << 5) | c
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_b s offset_words
    // WHY: `b <imm26>` (0x14000000 | (offset_words & 0x3FFFFFF)).
    // Unconditional branch with 26-bit signed word displacement (+/- 128MB range).
    off = offset_words & 67108863
    word = 335544320 | off
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_bl s offset_words
    // WHY: `bl <imm26>` (0x94000000 | (offset_words & 0x3FFFFFF)).
    // Subroutine procedure call: branches and records next instruction address into Link Register (X30).
    off = offset_words & 67108863
    word = 2483027968 | off
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_ret s
    // WHY: `ret x30` (0xD65F03C0).
    // Returns control flow to subroutine caller using Link Register address in X30.
    arm64_synth_emit32(s, 3596551104)
    return 0

fn arm64_emit_stp_pre s rt1 rt2 rn imm7
    // WHY: `stp x<rt1>, x<rt2>, [x<rn>, #imm7]!` (0xA9800000 | (((imm7 / 8) & 0x7F) << 15) | (rt2 << 10) | (rn << 5) | rt1).
    // Pre-indexed store pair with writeback. Decrements base pointer and stores register pair.
    t1 = rt1 & 31
    t2 = rt2 & 31
    n = rn & 31
    scaled = (imm7 / 8) & 127
    word = 2843738112 | (scaled << 15) | (t2 << 10) | (n << 5) | t1
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_ldp_post s rt1 rt2 rn imm7
    // WHY: `ldp x<rt1>, x<rt2>, [x<rn>], #imm7` (0xA8C00000 | (((imm7 / 8) & 0x7F) << 15) | (rt2 << 10) | (rn << 5) | rt1).
    // Post-indexed load pair with writeback. Loads register pair and increments base pointer.
    t1 = rt1 & 31
    t2 = rt2 & 31
    n = rn & 31
    scaled = (imm7 / 8) & 127
    word = 2831155200 | (scaled << 15) | (t2 << 10) | (n << 5) | t1
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_str_reg_sp s rt sp_offset
    // WHY: `str x<rt>, [sp, #<sp_offset>]` (0xF9000000 | (((sp_offset / 8) & 0xFFF) << 10) | (31 << 5) | rt).
    // 64-bit store with 12-bit unsigned 8-byte scaled immediate displacement from Stack Pointer (SP=31).
    t = rt & 31
    scaled = (sp_offset / 8) & 4095
    word = 4177526784 | (scaled << 10) | (31 << 5) | t
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_ldr_reg_sp s rt sp_offset
    // WHY: `ldr x<rt>, [sp, #<sp_offset>]` (0xF9400000 | (((sp_offset / 8) & 0xFFF) << 10) | (31 << 5) | rt).
    // 64-bit load with 12-bit unsigned 8-byte scaled immediate displacement from Stack Pointer (SP=31).
    t = rt & 31
    scaled = (sp_offset / 8) & 4095
    word = 4181721088 | (scaled << 10) | (31 << 5) | t
    arm64_synth_emit32(s, word)
    return 0

fn arm64_emit_svc s imm16
    // WHY: `svc #<imm16>` (0xD4000001 | ((imm16 & 0xFFFF) << 5)).
    // Supervisor Call instruction triggering hardware exception to enter Linux kernel syscall handler.
    imm = imm16 & 65535
    word = 3556769793 | (imm << 5)
    arm64_synth_emit32(s, word)
    return 0

fn arm64_push_reg s reg
    // WHY: Pushes 64-bit register Xt onto stack (pre-index: str Xt, [sp, #-16]!).
    // Maintains mandatory AAPCS64 16-byte stack alignment during expression evaluation.
    r = reg & 31
    arm64_synth_emit32(s, 4162785248 | r)
    return 0

fn arm64_pop_reg s reg
    // WHY: Pops 64-bit register Xt from stack (post-index: ldr Xt, [sp], #16).
    // Restores register operand and pops 16 bytes while preserving alignment.
    r = reg & 31
    arm64_synth_emit32(s, 4165011424 | r)
    return 0

fn arm64_emit_prologue s
    // WHY: Standard AAPCS64 Procedure Call Standard stack frame setup:
    // 1. stp x29, x30, [sp, #-16]!  (0xA9BF7BFD = 2847898621) - Saves FP & LR on stack
    // 2. mov x29, sp                (0x910003FD = 2432697341) - Establishes new Frame Pointer
    // 3. sub sp, sp, #2048          (0xD12003FF = 3508536319) - Allocates 2KB local stack space
    arm64_synth_emit32(s, 2847898621)
    arm64_synth_emit32(s, 2432697341)
    arm64_synth_emit32(s, 3508536319)
    return 0

fn arm64_emit_epilogue s
    // WHY: Standard AAPCS64 stack frame teardown:
    // 1. mov sp, x29                (0x910003BF = 2432697279) - Collapses local variable frame
    // 2. ldp x29, x30, [sp], #16    (0xA8C17BFD = 2831252477) - Restores Frame Pointer and Link Register
    // 3. ret                        (0xD65F03C0 = 3596551104) - Returns to caller via Link Register X30
    arm64_synth_emit32(s, 2432697279)
    arm64_emit_ldp_post(s, 29, 30, 31, 16)
    arm64_emit_ret(s)
    return 0

fn arm64_emit_print_string s str_val
    // WHY: Emits Linux AArch64 SYS_write(1, &str, len) for string literals:
    //      - X0 = 1 (STDOUT_FILENO)
    //      - X1 = Virtual address of UTF-8 string payload in .rodata
    //      - X2 = Byte length including appended newline
    //      - X8 = 64 (Linux AArch64 SYS_write)
    //      - SVC #0
    ro_off = arm64_synth_add_rodata_str(s, str_val, 1)
    str_len = len(str_val) + 1 // Includes appended newline

    // mov x0, 1 (STDOUT)
    arm64_emit_movz_x(s, 0, 1, 0)

    // mov x1, <rodata_vaddr> (16-byte MOVZ/MOVK quad, backpatched after code assembly)
    patch_pos = s.synth_code.len()
    arm64_emit_movz_x(s, 1, 0, 0)
    arm64_emit_movk_x(s, 1, 0, 16)
    arm64_emit_movk_x(s, 1, 0, 32)
    arm64_emit_movk_x(s, 1, 0, 48)

    rel = Arm64StringReloc()
    rel.sr_patch_offset = patch_pos
    rel.sr_rodata_offset = ro_off
    rel.sr_reg = 1
    push(s.synth_str_relocs, rel)

    // mov x2, str_len
    arm64_emit_mov_imm64(s, 2, str_len)

    // mov x8, 64 (SYS_write on Linux AArch64)
    arm64_emit_movz_x(s, 8, 64, 0)

    // svc #0
    arm64_emit_svc(s, 0)
    return 0

// ── 5. Micro-Runtime Helpers ──────────────────────────────────────────────────

fn arm64_synth_emit_call_print_int s
    // WHY: Emits subroutine call to the centralized __print_int helper to display integer in X0.
    s.synth_needs_print_int = 1
    call_off = s.synth_code.len()
    arm64_emit_bl(s, 0) // Placeholder 26-bit call displacement

    call_rel = Arm64CallReloc()
    call_rel.cr_patch_offset = call_off
    call_rel.cr_target_name = "__print_int"
    push(s.synth_call_relocs, call_rel)
    return 0

fn arm64_synth_emit_print_int_helper s
    // WHY: Pure ARM64 assembly routine converting 64-bit signed integer in X0
    // to ASCII decimal string on the stack and writing to STDOUT with trailing newline.
    // Zero dependencies on external C printf/puts.
    s.synth_print_int_off = s.synth_code.len()

    // 0: stp x29, x30, [sp, #-48]!
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 48)
    // 1: mov x29, sp
    arm64_synth_emit32(s, 2432697341)

    // Buffer is built backwards starting at [sp + 47]
    // 2: movz x1, 10, 0 ('\n')
    arm64_emit_movz_x(s, 1, 10, 0)
    // 3: add x2, sp, 47 (2432745442) -> pointer to last byte
    arm64_synth_emit32(s, 2432745442)
    // 4: strb w1, [x2, 0] (956301377) -> write newline
    arm64_synth_emit32(s, 956301377)
    // 5: mov x1, x2 (current buffer pointer)
    arm64_emit_mov_reg(s, 1, 2)
    // 6: movz x2, 1, 0 (current length = 1)
    arm64_emit_movz_x(s, 2, 1, 0)

    // 7: cmp x0, xzr
    arm64_emit_cmp_x(s, 0, 31)
    // 8: b.ne +6 words -> jump to .check_neg (instruction 14)
    arm64_emit_b_cond(s, 1, 6)

    // Special case: X0 == 0
    // 9: sub x1, x1, 1
    arm64_synth_emit32(s, 3506439201)
    // 10: movz x3, 48, 0 ('0')
    arm64_emit_movz_x(s, 3, 48, 0)
    // 11: strb w3, [x1, 0]
    arm64_synth_emit32(s, 956301347)
    // 12: add x2, x2, 1
    arm64_synth_emit32(s, 2432697410)
    // 13: b +26 words -> jump to .do_write (instruction 39)
    arm64_emit_b(s, 26)

    // .check_neg (instruction 14):
    // 14: movz x9, 0, 0 (negative flag = 0)
    arm64_emit_movz_x(s, 9, 0, 0)
    // 15: cmp x0, xzr
    arm64_emit_cmp_x(s, 0, 31)
    // 16: b.ge +3 words -> jump to .loop_digits (instruction 19)
    arm64_emit_b_cond(s, 10, 3)
    // 17: movz x9, 1, 0 (negative flag = 1)
    arm64_emit_movz_x(s, 9, 1, 0)
    // 18: sub x0, xzr, x0 (negate X0: 0xCB0003E0 = 3405775840)
    arm64_synth_emit32(s, 3405775840)

    // .loop_digits (instruction 19):
    // 19: cmp x0, xzr
    arm64_emit_cmp_x(s, 0, 31)
    // 20: b.eq +11 words -> jump to .finish_digits (instruction 31)
    arm64_emit_b_cond(s, 0, 11)
    // 21: movz x10, 10, 0 (divisor)
    arm64_emit_movz_x(s, 10, 10, 0)
    // 22: sdiv x11, x0, x10 (quotient)
    arm64_emit_sdiv_x(s, 11, 0, 10)
    // 23: mul x12, x11, x10
    arm64_emit_mul_x(s, 12, 11, 10)
    // 24: sub x12, x0, x12 (remainder = X0 % 10)
    arm64_emit_sub_x(s, 12, 0, 12)
    // 25: add x12, x12, 48 (ASCII digit: 0x9100C18C = 2432745868)
    arm64_synth_emit32(s, 2432745868)
    // 26: sub x1, x1, 1 (decrement buffer pointer)
    arm64_synth_emit32(s, 3506439201)
    // 27: strb w12, [x1, 0]
    arm64_synth_emit32(s, 956301356)
    // 28: add x2, x2, 1 (increment byte count)
    arm64_synth_emit32(s, 2432697410)
    // 29: mov x0, x11 (X0 = quotient)
    arm64_emit_mov_reg(s, 0, 11)
    // 30: b -11 words -> jump back to .loop_digits (instruction 19)
    arm64_emit_b(s, 0 - 11)

    // .finish_digits (instruction 31):
    // 31: movz x3, 1, 0
    arm64_emit_movz_x(s, 3, 1, 0)
    // 32: cmp x9, x3
    arm64_emit_cmp_x(s, 9, 3)
    // 33: b.ne +6 words -> jump to .do_write (instruction 39)
    arm64_emit_b_cond(s, 1, 6)
    // 34: sub x1, x1, 1
    arm64_synth_emit32(s, 3506439201)
    // 35: movz x3, 45, 0 ('-')
    arm64_emit_movz_x(s, 3, 45, 0)
    // 36: strb w3, [x1, 0]
    arm64_synth_emit32(s, 956301347)
    // 37: add x2, x2, 1
    arm64_synth_emit32(s, 2432697410)
    // 38: fallthrough to .do_write

    // .do_write (instruction 39):
    // 39: movz x0, 1, 0 (STDOUT_FILENO = 1)
    arm64_emit_movz_x(s, 0, 1, 0)
    // X1 already points to start of formatted ASCII string in stack buffer
    // X2 already holds exact byte count
    // 40: movz x8, 64, 0 (SYS_write on Linux AArch64)
    arm64_emit_movz_x(s, 8, 64, 0)
    // 41: svc #0
    arm64_emit_svc(s, 0)

    // Epilogue:
    // 42: mov sp, x29
    arm64_synth_emit32(s, 2432697279)
    // 43: ldp x29, x30, [sp], #48
    arm64_emit_ldp_post(s, 29, 30, 31, 48)
    // 44: ret
    arm64_emit_ret(s)
    return 0

fn arm64_synth_emit_call_alloc s
    // WHY: Emits subroutine call to the native __alloc bump allocator.
    s.synth_needs_alloc = 1
    call_off = s.synth_code.len()
    arm64_emit_bl(s, 0) // Placeholder

    call_rel = Arm64CallReloc()
    call_rel.cr_patch_offset = call_off
    call_rel.cr_target_name = "__alloc"
    push(s.synth_call_relocs, call_rel)
    return 0

fn arm64_synth_emit_alloc_helper s
    // WHY: Emits pure ARM64 silicon bump-arena memory allocator with zero libc dependency.
    // Inputs: X0 = requested byte size. Output: X0 = pointer to allocated memory.
    s.synth_alloc_off = s.synth_code.len()

    // 0: add x0, x0, 15 (0x91003C00 = 2432699392) -> round up
    arm64_synth_emit32(s, 2432699392)
    // 1: movz x1, 15, 0
    arm64_emit_movz_x(s, 1, 15, 0)
    // 2: bic x0, x0, x1 (0x8A210000 = 2317484032) -> align to 16 bytes
    arm64_synth_emit32(s, 2317484032)
    // 3: adr x1, 96 (0x10000301 = 2684360449) -> points to _heap_ptr at instruction 27
    arm64_synth_emit32(s, 2684360449)
    // 4: ldr x2, [x1, #0] (0xF9400022 = 4181721122) -> load current heap pointer
    arm64_synth_emit32(s, 4181721122)
    // 5: cmp x2, xzr
    arm64_emit_cmp_x(s, 2, 31)
    // 6: b.ne +16 words -> jump to .bump (instruction 22)
    arm64_emit_b_cond(s, 1, 16)

    // Heap initialization via Linux sys_mmap(NULL, 64MB, PROT_READ|WRITE, MAP_ANON|PRIVATE, -1, 0)
    // 7: stp x0, x1, [sp, #-16]! (preserve size and _heap_ptr pointer)
    arm64_emit_stp_pre(s, 0, 1, 31, 0 - 16)
    // 8: stp x29, x30, [sp, #-16]!
    arm64_emit_stp_pre(s, 29, 30, 31, 0 - 16)
    // 9: movz x0, 0, 0 (addr = NULL)
    arm64_emit_movz_x(s, 0, 0, 0)
    // 10: movz x1, 0, 0; movk x1, 16384, 16 -> length = 1073741824 (1GB virtual memory arena)
    arm64_emit_movz_x(s, 1, 0, 0)
    arm64_emit_movk_x(s, 1, 16384, 16)
    // 11: movz x2, 3, 0 (PROT_READ | PROT_WRITE = 3)
    arm64_emit_movz_x(s, 2, 3, 0)
    // 12: movz x3, 34, 0 (MAP_PRIVATE | MAP_ANONYMOUS = 34)
    arm64_emit_movz_x(s, 3, 34, 0)
    // 13: mov x4, -1 (fd = -1)
    arm64_emit_mov_imm64(s, 4, 0 - 1)
    // 14: movz x5, 0, 0 (offset = 0)
    arm64_emit_movz_x(s, 5, 0, 0)
    // 15: movz x8, 222, 0 (Linux AArch64 SYS_mmap = 222)
    arm64_emit_movz_x(s, 8, 222, 0)
    // 16: svc #0 -> X0 now holds allocated arena base pointer
    arm64_emit_svc(s, 0)
    // 17: ldp x29, x30, [sp], #16
    arm64_emit_ldp_post(s, 29, 30, 31, 16)
    // 18: ldp x3, x1, [sp], #16 -> X3 = requested size, X1 = _heap_ptr address
    arm64_emit_ldp_post(s, 3, 1, 31, 16)
    // 19: str x0, [x1, #0] (0xF9000020 = 4177526816) -> store arena base into _heap_ptr
    arm64_synth_emit32(s, 4177526816)
    // 20: mov x2, x0
    arm64_emit_mov_reg(s, 2, 0)
    // 21: mov x0, x3
    arm64_emit_mov_reg(s, 0, 3)

    // .bump (instruction 22):
    // 22: ldr x2, [x1, #0] (0xF9400022 = 4181721122) -> load current heap pointer
    arm64_synth_emit32(s, 4181721122)
    // 23: add x3, x2, x0 -> compute next heap pointer
    arm64_emit_add_x(s, 3, 2, 0)
    // 24: str x3, [x1, #0] (0xF9000023 = 4177526819) -> update _heap_ptr
    arm64_synth_emit32(s, 4177526819)
    // 25: mov x0, x2 -> return previous heap pointer in X0
    arm64_emit_mov_reg(s, 0, 2)
    // 26: ret
    arm64_emit_ret(s)

    // 27..28: _heap_ptr storage (8 bytes initialized to 0)
    arm64_synth_emit32(s, 0)
    arm64_synth_emit32(s, 0)
    return 0

// ── 6. Parser Utilities, Symbol Table & Scoping ───────────────────────────────

fn arm64_synth_skip_whitespace_tokens toks pos_box
    // WHY: Advances token pointer past any empty newlines or comments.
    while get(pos_box, 0) < toks.len()
        k = toks[get(pos_box, 0)].tok_kind
        if k == TOK_NEWLINE() or k == TOK_SEMI() or k == TOK_COMMENT_DOC() or k == TOK_COMMENT_LINE() or k == TOK_COMMENT_BLOCK()
            list_set(pos_box, 0, get(pos_box, 0) + 1)
        else
            break
    return 0

fn arm64_synth_find_struct s sname
    // WHY: Finds struct definition metadata by struct type name.
    i = 0
    while i < s.synth_structs.len()
        if s.synth_structs[i].sd_name == sname
            return s.synth_structs[i]
        i = i + 1
    return 0

fn arm64_synth_get_field_offset s sname fname
    // WHY: Resolves the 8-byte scaled offset of struct field fname.
    if sname != ""
        sdef = arm64_synth_find_struct(s, sname)
        if sdef != 0
            f = 0
            while f < sdef.sd_fields.len()
                if sdef.sd_fields[f] == fname
                    return f * 8
                f = f + 1

    // Fallback: search across all defined structs
    i = 0
    while i < s.synth_structs.len()
        cur_def = s.synth_structs[i]
        f = 0
        while f < cur_def.sd_fields.len()
            if cur_def.sd_fields[f] == fname
                return f * 8
            f = f + 1
        i = i + 1

    // Fallback 2: search global fields registry
    gi = 0
    while gi < s.synth_global_fields.len()
        if s.synth_global_fields[gi] == fname
            return gi * 8
        gi = gi + 1
    push(s.synth_global_fields, fname)
    return (s.synth_global_fields.len() - 1) * 8

fn arm64_synth_lookup_var s name
    // WHY: Finds SP-relative stack offset for variable identifier. Returns 0 if not found.
    i = 0
    while i < s.synth_locals.len()
        lv = s.synth_locals[i]
        if lv.lv_name == name
            return lv.lv_offset
        i = i + 1
    return 0

fn arm64_synth_alloc_var s name
    // WHY: Allocates next 8-byte stack slot for variable name or returns existing offset.
    existing = arm64_synth_lookup_var(s, name)
    if existing > 0
        return existing
    off = s.synth_stack_offset
    s.synth_stack_offset = s.synth_stack_offset + 8
    lv = Arm64LocalVar()
    lv.lv_name = name
    lv.lv_offset = off
    push(s.synth_locals, lv)
    return off

