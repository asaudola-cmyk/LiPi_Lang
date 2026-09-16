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
    // 10: movz x1, 0, 0; movk x1, 1024, 16 -> length = 67108864 (64MB)
    arm64_emit_movz_x(s, 1, 0, 0)
    arm64_emit_movk_x(s, 1, 1024, 16)
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

// ── 7. Recursive-Descent Expression Synthesizer ────────────────────────────────

fn arm64_synth_expr_primary s toks pos_box
    // WHY: Parses and synthesizes primary operands (integers, strings, identifiers, calls, grouping).
    // Result is always computed into X0.
    pos = get(pos_box, 0)
    if pos >= toks.len()
        arm64_emit_movz_x(s, 0, 0, 0)
        return 0

    t = toks[pos]
    k = t.tok_kind

    // 1. Integer Literal
    if k == TOK_INT()
        list_set(pos_box, 0, pos + 1)
        arm64_emit_mov_imm64(s, 0, t.tok_int_val)
        return 0

    // 2. String Literal
    if k == TOK_STR()
        list_set(pos_box, 0, pos + 1)
        ro_off = arm64_synth_add_rodata_str(s, t.tok_text, 0)
        patch_pos = s.synth_code.len()
        arm64_emit_movz_x(s, 0, 0, 0)
        arm64_emit_movk_x(s, 0, 0, 16)
        arm64_emit_movk_x(s, 0, 0, 32)
        arm64_emit_movk_x(s, 0, 0, 48)

        rel = Arm64StringReloc()
        rel.sr_patch_offset = patch_pos
        rel.sr_rodata_offset = ro_off
        rel.sr_reg = 0
        push(s.synth_str_relocs, rel)
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
                arm64_synth_compile_expr(s, toks, pos_box)
                arm64_push_reg(s, 0) // Push X0
                arg_count = arg_count + 1
                cur_pos = get(pos_box, 0)
                if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_COMMA()
                    list_set(pos_box, 0, cur_pos + 1)

            if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_RPAREN()
                list_set(pos_box, 0, get(pos_box, 0) + 1) // Consume ')'

            // ── Intrinsic 1: syscall / সিসকল ─────────────────────────────────
            // Linux AArch64: X8 = syscall number, X0..X5 = args 1..6
            if var_name == "syscall" or var_name == "সিসকল"
                if arg_count >= 7
                    arm64_pop_reg(s, 5) // arg 6 (X5)
                if arg_count >= 6
                    arm64_pop_reg(s, 4) // arg 5 (X4)
                if arg_count >= 5
                    arm64_pop_reg(s, 3) // arg 4 (X3)
                if arg_count >= 4
                    arm64_pop_reg(s, 2) // arg 3 (X2)
                if arg_count >= 3
                    arm64_pop_reg(s, 1) // arg 2 (X1)
                if arg_count >= 2
                    arm64_pop_reg(s, 0) // arg 1 (X0)
                if arg_count >= 1
                    arm64_pop_reg(s, 8) // syscall number (X8)
                arm64_emit_svc(s, 0)
                return 0

            // ── Intrinsic 2: malloc / mem_alloc / মেমরি_বরাদ্দ ──────────────
            if var_name == "malloc" or var_name == "mem_alloc" or var_name == "মেমরি_বরাদ্দ"
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // requested size in X0
                else
                    arm64_emit_mov_imm64(s, 0, 32)
                arm64_synth_emit_call_alloc(s)
                return 0

            // ── Intrinsic 3: mem_word_read / mem_read / মেমরি_পড়ো ──────────
            if var_name == "mem_word_read" or var_name == "mem_read" or var_name == "মেমরি_পড়ো"
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1) // X0 = addr + offset
                // ldr x0, [x0, #0] (0xF9400000 = 4181721088)
                arm64_synth_emit32(s, 4181721088)
                return 0

            // ── Intrinsic 4: mem_word_write / mem_write / মেমরি_লেখো ───────
            if var_name == "mem_word_write" or var_name == "mem_write" or var_name == "মেমরি_লেখো"
                if arg_count >= 3
                    arm64_pop_reg(s, 2) // value (X2)
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1) // X0 = addr + offset
                // str x2, [x0, #0] (0xF9000002 = 4177526786)
                arm64_synth_emit32(s, 4177526786)
                arm64_emit_mov_reg(s, 0, 2) // return val in X0
                return 0

            // ── Intrinsic 5: mem_byte_read / mem_read_byte / মেমরি_বাইট_পড়ো
            if var_name == "mem_byte_read" or var_name == "mem_read_byte" or var_name == "মেমরি_বাইট_পড়ো"
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1)
                // ldrb w0, [x0, #0] (0x39400000 = 960495616)
                arm64_synth_emit32(s, 960495616)
                return 0

            // ── Intrinsic 6: mem_byte_write / mem_write_byte / মেমরি_বাইট_লেখো
            if var_name == "mem_byte_write" or var_name == "mem_write_byte" or var_name == "মেমরি_বাইট_লেখো"
                if arg_count >= 3
                    arm64_pop_reg(s, 2) // value (X2)
                if arg_count >= 2
                    arm64_pop_reg(s, 1) // offset (X1)
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // base addr (X0)
                arm64_emit_add_x(s, 0, 0, 1)
                // strb w2, [x0, #0] (0x39000002 = 956301314)
                arm64_synth_emit32(s, 956301314)
                arm64_emit_mov_reg(s, 0, 2)
                return 0

            // ── Intrinsic 7: exit / বিদায় ─────────────────────────────────
            if var_name == "exit" or var_name == "বিদায়"
                if arg_count >= 1
                    arm64_pop_reg(s, 0) // status code
                else
                    arm64_emit_movz_x(s, 0, 0, 0)
                arm64_emit_movz_x(s, 8, 93, 0) // SYS_exit (93)
                arm64_emit_svc(s, 0)
                return 0

            // ── Struct Constructor: StructName(...) ─────────────────────────
            sdef = arm64_synth_find_struct(s, var_name)
            if sdef != 0
                fcount = sdef.sd_fields.len()
                alloc_sz = (fcount + 1) * 8
                if alloc_sz < 32
                    alloc_sz = 32
                arm64_emit_mov_imm64(s, 0, alloc_sz)
                arm64_synth_emit_call_alloc(s)
                // Struct pointer is now in X0
                if arg_count > 0
                    arm64_push_reg(s, 0) // preserve struct pointer on stack
                    ai = arg_count - 1
                    while ai >= 0
                        arm64_pop_reg(s, 1) // pop field value into X1
                        // ldr x2, [sp, #0] -> reload struct pointer into X2
                        arm64_emit_ldr_reg_sp(s, 2, 0)
                        // str x1, [x2, #ai*8] -> 0xF9000000 | (((ai*8)/8) << 10) | (2 << 5) | 1
                        scaled_ai = ai & 4095
                        st_word = 4177526784 | (scaled_ai << 10) | (2 << 5) | 1
                        arm64_synth_emit32(s, st_word)
                        ai = ai - 1
                    arm64_pop_reg(s, 0) // restore struct pointer into X0
                return 0

            // ── Normal Function Call: Pop arguments into AAPCS64 registers X0..X7
            if arg_count >= 8
                arm64_pop_reg(s, 7)
            if arg_count >= 7
                arm64_pop_reg(s, 6)
            if arg_count >= 6
                arm64_pop_reg(s, 5)
            if arg_count >= 5
                arm64_pop_reg(s, 4)
            if arg_count >= 4
                arm64_pop_reg(s, 3)
            if arg_count >= 3
                arm64_pop_reg(s, 2)
            if arg_count >= 2
                arm64_pop_reg(s, 1)
            if arg_count >= 1
                arm64_pop_reg(s, 0)

            // Emit BL instruction with relocation placeholder
            call_off = s.synth_code.len()
            arm64_emit_bl(s, 0)

            call_rel = Arm64CallReloc()
            call_rel.cr_patch_offset = call_off
            call_rel.cr_target_name = var_name
            push(s.synth_call_relocs, call_rel)
            return 0

        // ── Struct Field Access: obj.field ──────────────────────────────────
        if next_pos < toks.len() and (toks[next_pos].tok_kind == TOK_DOT() or toks[next_pos].tok_text == ".")
            // Load base object pointer from local stack into X0
            off = arm64_synth_lookup_var(s, var_name)
            if off > 0
                arm64_emit_ldr_reg_sp(s, 0, off)
            else
                arm64_emit_movz_x(s, 0, 0, 0)

            while get(pos_box, 0) < toks.len()
                cp = get(pos_box, 0)
                if toks[cp].tok_kind != TOK_DOT() and toks[cp].tok_text != "."
                    break
                list_set(pos_box, 0, cp + 1) // Consume '.'
                if get(pos_box, 0) < toks.len() and toks[get(pos_box, 0)].tok_kind == TOK_IDENT()
                    fn_tok = toks[get(pos_box, 0)]
                    list_set(pos_box, 0, get(pos_box, 0) + 1)
                    f_off = arm64_synth_get_field_offset(s, "", fn_tok.tok_text)
                    // ldr x0, [x0, #f_off]: 0xF9400000 | (((f_off/8) & 0xFFF) << 10) | (0 << 5) | 0
                    scaled_fo = (f_off / 8) & 4095
                    ldr_word = 4181721088 | (scaled_fo << 10)
                    arm64_synth_emit32(s, ldr_word)
            return 0

        // Variable load: ldr x0, [sp, #off]
        off = arm64_synth_lookup_var(s, var_name)
        if off > 0
            arm64_emit_ldr_reg_sp(s, 0, off)
        else
            arm64_emit_movz_x(s, 0, 0, 0)
        return 0

    // 4. Parenthesized expression: ( expr )
    if k == TOK_LPAREN()
        list_set(pos_box, 0, pos + 1)
        arm64_synth_compile_expr(s, toks, pos_box)
        cur_pos = get(pos_box, 0)
        if cur_pos < toks.len() and toks[cur_pos].tok_kind == TOK_RPAREN()
            list_set(pos_box, 0, cur_pos + 1)
        return 0

    // Fallback: advance and clear X0
    list_set(pos_box, 0, pos + 1)
    arm64_emit_movz_x(s, 0, 0, 0)
    return 0

fn arm64_synth_compile_expr s toks pos_box
    // WHY: Pratt / Precedence climbing binary expression evaluator for ARM64.
    // Handles arithmetic (+, -, *, /, %) and comparisons (==, !=, <, <=, >, >=).
    arm64_synth_expr_primary(s, toks, pos_box)

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

        // Push left operand (X0) to stack
        arm64_push_reg(s, 0)

        // Evaluate right operand into X0
        arm64_synth_expr_primary(s, toks, pos_box)

        // Move right operand to X1, pop left operand back into X0
        arm64_emit_mov_reg(s, 1, 0)
        arm64_pop_reg(s, 0)

        // Synthesize ALU operation
        if op_kind == TOK_PLUS()
            arm64_emit_add_x(s, 0, 0, 1)
        elif op_kind == TOK_MINUS()
            arm64_emit_sub_x(s, 0, 0, 1)
        elif op_kind == TOK_STAR()
            arm64_emit_mul_x(s, 0, 0, 1)
        elif op_kind == TOK_SLASH()
            arm64_emit_sdiv_x(s, 0, 0, 1)
        elif op_kind == TOK_PERCENT()
            // Remainder in AArch64: X2 = X0 / X1; X2 = X2 * X1; X0 = X0 - X2
            arm64_emit_sdiv_x(s, 2, 0, 1)
            arm64_emit_mul_x(s, 2, 2, 1)
            arm64_emit_sub_x(s, 0, 0, 2)
        elif op_kind == TOK_EQ()
            // cmp x0, x1; b.eq +2; mov x0, 0; b +2; mov x0, 1
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 0, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
        elif op_kind == TOK_NEQ()
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 1, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
        elif op_kind == TOK_LT()
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 11, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
        elif op_kind == TOK_LTE()
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 13, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
        elif op_kind == TOK_GT()
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 12, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)
        elif op_kind == TOK_GTE()
            arm64_emit_cmp_x(s, 0, 1)
            arm64_emit_b_cond(s, 10, 2)
            arm64_emit_movz_x(s, 0, 0, 0)
            arm64_emit_b(s, 2)
            arm64_emit_movz_x(s, 0, 1, 0)

    return 0

// ── 8. Statement Synthesizer ──────────────────────────────────────────────────

fn arm64_synth_compile_statement s toks pos_box
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
                arm64_emit_print_string(s, next_tok.tok_text)
                return 0

        // General expression print (numbers, variables, calculations):
        arm64_synth_compile_expr(s, toks, pos_box)
        arm64_synth_emit_call_print_int(s)
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
            arm64_synth_compile_expr(s, toks, pos_box)
        else
            arm64_emit_movz_x(s, 0, 0, 0)

        if s.synth_in_function == 1
            arm64_emit_epilogue(s)
        else
            // Top-level return: exit with code in X0 via Linux SYS_exit (93)
            arm64_emit_movz_x(s, 8, 93, 0)
            arm64_emit_svc(s, 0)
        return 0

    // ── 3. Loop Control: break / থামো & continue / চলুক ───────────────────────
    if k == TOK_KW_BREAK() or (k == TOK_IDENT() and (txt == "break" or txt == "থামো"))
        list_set(pos_box, 0, pos + 1)
        if s.synth_loop_breaks.len() > 0
            p_off = s.synth_code.len()
            arm64_emit_b(s, 0) // Placeholder
            curr_brk_list = s.synth_loop_breaks[s.synth_loop_breaks.len() - 1]
            push(curr_brk_list, p_off)
        return 0

    if k == TOK_KW_CONTINUE() or (k == TOK_IDENT() and (txt == "continue" or txt == "চলুক" or txt == "চলো"))
        list_set(pos_box, 0, pos + 1)
        if s.synth_loop_starts.len() > 0
            loop_hdr = s.synth_loop_starts[s.synth_loop_starts.len() - 1]
            cur_off = s.synth_code.len()
            rel_words = (loop_hdr - cur_off) / 4
            arm64_emit_b(s, rel_words)
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
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
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

        sdef = Arm64StructDef()
        sdef.sd_name = sname
        sdef.sd_fields = fields
        push(s.synth_structs, sdef)
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

                // Evaluate expr into X0
                arm64_synth_compile_expr(s, toks, pos_box)

                // Save value: push X0
                arm64_push_reg(s, 0)

                // Load obj pointer into X1
                obj_off = arm64_synth_lookup_var(s, obj_name)
                if obj_off > 0
                    arm64_emit_ldr_reg_sp(s, 1, obj_off)
                else
                    arm64_emit_movz_x(s, 1, 0, 0)

                // Pop value into X0
                arm64_pop_reg(s, 0)

                // Store value to field: str X0, [X1, #f_off]
                f_off = arm64_synth_get_field_offset(s, "", field_name)
                scaled_fo = (f_off / 8) & 4095
                st_word = 4177526784 | (scaled_fo << 10) | (1 << 5) | 0
                arm64_synth_emit32(s, st_word)
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

        // Evaluate conditional expression into X0
        arm64_synth_compile_expr(s, toks, pos_box)

        // Compare X0 with XZR: cmp x0, xzr
        arm64_emit_cmp_x(s, 0, 31)

        // b.eq next_branch (branch if zero/false)
        patch_next_branch = s.synth_code.len()
        arm64_emit_b_cond(s, 0, 0) // Placeholder

        end_patches = list()
        arm64_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile then-block statements
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
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
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == before_stmt_p
                list_set(pos_box, 0, before_stmt_p + 1)

            if cur_t.tok_span.span_start_line == base_line
                break

        // Check if there is an elif or else coming next
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
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
            jmp_end = s.synth_code.len()
            arm64_emit_b(s, 0)
            push(end_patches, jmp_end)

            cur_off = s.synth_code.len()
            rel_words = (cur_off - patch_next_branch) / 4
            arm64_synth_patch_u32(s, patch_next_branch, 1409286144 | ((rel_words & 524287) << 5) | 0)
        else
            cur_off = s.synth_code.len()
            rel_words = (cur_off - patch_next_branch) / 4
            arm64_synth_patch_u32(s, patch_next_branch, 1409286144 | ((rel_words & 524287) << 5) | 0)

        // Loop over elif branches
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
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
            arm64_synth_compile_expr(s, toks, pos_box)

            arm64_emit_cmp_x(s, 0, 31)
            patch_next_branch = s.synth_code.len()
            arm64_emit_b_cond(s, 0, 0) // b.eq next_branch

            arm64_synth_skip_whitespace_tokens(toks, pos_box)

            while get(pos_box, 0) < toks.len()
                arm64_synth_skip_whitespace_tokens(toks, pos_box)
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
                arm64_synth_compile_statement(s, toks, pos_box)
                if get(pos_box, 0) == b_p2
                    list_set(pos_box, 0, b_p2 + 1)
                if ct2.tok_span.span_start_line == elif_line
                    break

            jmp_end = s.synth_code.len()
            arm64_emit_b(s, 0)
            push(end_patches, jmp_end)

            cur_off = s.synth_code.len()
            rel_words = (cur_off - patch_next_branch) / 4
            arm64_synth_patch_u32(s, patch_next_branch, 1409286144 | ((rel_words & 524287) << 5) | 0)

        // Check for else
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
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
                arm64_synth_skip_whitespace_tokens(toks, pos_box)
                while get(pos_box, 0) < toks.len()
                    arm64_synth_skip_whitespace_tokens(toks, pos_box)
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
                    arm64_synth_compile_statement(s, toks, pos_box)
                    if get(pos_box, 0) == b_p3
                        list_set(pos_box, 0, b_p3 + 1)
                    if ct3.tok_span.span_start_line == else_line
                        break

        // Consume optional end / @end / শেষ
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Backpatch all exit jumps to current offset
        cur_off = s.synth_code.len()
        ei = 0
        while ei < end_patches.len()
            p_end = end_patches[ei]
            rel_words = (cur_off - p_end) / 4
            b_word = 335544320 | (rel_words & 67108863)
            arm64_synth_patch_u32(s, p_end, b_word)
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

        loop_header = s.synth_code.len()
        push(s.synth_loop_starts, loop_header)
        loop_brks = list()
        push(s.synth_loop_breaks, loop_brks)

        // Evaluate condition into X0
        arm64_synth_compile_expr(s, toks, pos_box)

        // cmp x0, xzr; b.eq loop_exit
        arm64_emit_cmp_x(s, 0, 31)
        patch_loop_exit = s.synth_code.len()
        arm64_emit_b_cond(s, 0, 0) // Placeholder

        arm64_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile while body statements
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
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
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Backward jump to loop_header: b loop_header
        cur_off = s.synth_code.len()
        rel_words = (loop_header - cur_off) / 4
        arm64_emit_b(s, rel_words)

        // Backpatch loop_exit
        loop_exit_off = s.synth_code.len()
        exit_words = (loop_exit_off - patch_loop_exit) / 4
        arm64_synth_patch_u32(s, patch_loop_exit, 1409286144 | ((exit_words & 524287) << 5) | 0)

        // Backpatch all break jumps
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            b_words = (loop_exit_off - brk_patch) / 4
            arm64_synth_patch_u32(s, brk_patch, 335544320 | (b_words & 67108863))
            bi = bi + 1

        pop(s.synth_loop_starts)
        pop(s.synth_loop_breaks)
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

        // Compile start expression into X0
        arm64_synth_compile_expr(s, toks, pos_box)
        var_off = arm64_synth_alloc_var(s, var_name)
        arm64_emit_str_reg_sp(s, 0, var_off)

        // Consume '..' if present
        if get(pos_box, 0) < toks.len()
            dot_t = toks[get(pos_box, 0)]
            if dot_t.tok_kind == TOK_DOTDOT() or dot_t.tok_text == ".."
                list_set(pos_box, 0, get(pos_box, 0) + 1)

        // Compile end expression into X0
        arm64_synth_compile_expr(s, toks, pos_box)
        end_var_name = "__end_" + var_name
        end_off = arm64_synth_alloc_var(s, end_var_name)
        arm64_emit_str_reg_sp(s, 0, end_off)

        loop_header = s.synth_code.len()
        push(s.synth_loop_starts, loop_header)
        loop_brks = list()
        push(s.synth_loop_breaks, loop_brks)

        // Compare var and end: ldr x0, [sp, #var_off]; ldr x1, [sp, #end_off]; cmp x0, x1
        arm64_emit_ldr_reg_sp(s, 0, var_off)
        arm64_emit_ldr_reg_sp(s, 1, end_off)
        arm64_emit_cmp_x(s, 0, 1)

        // b.ge loop_exit (exit if var >= end)
        patch_loop_exit = s.synth_code.len()
        arm64_emit_b_cond(s, 10, 0)

        arm64_synth_skip_whitespace_tokens(toks, pos_box)

        // Compile for body statements
        while get(pos_box, 0) < toks.len()
            arm64_synth_skip_whitespace_tokens(toks, pos_box)
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
            arm64_synth_compile_statement(s, toks, pos_box)
            if get(pos_box, 0) == b_p
                list_set(pos_box, 0, b_p + 1)

            if cur_t.tok_span.span_start_line == base_line
                break

        // Consume optional end / @end / শেষ
        arm64_synth_skip_whitespace_tokens(toks, pos_box)
        cur_p = get(pos_box, 0)
        if cur_p < toks.len()
            cur_t = toks[cur_p]
            cur_k = cur_t.tok_kind
            cur_txt = cur_t.tok_text
            if cur_k == TOK_KW_END() or cur_k == TOK_DIR_END() or (cur_k == TOK_IDENT() and (cur_txt == "end" or cur_txt == "শেষ" or cur_txt == "@end"))
                list_set(pos_box, 0, cur_p + 1)

        // Increment var: ldr x0, [sp, #var_off]; mov x1, 1; add x0, x0, x1; str x0, [sp, #var_off]
        arm64_emit_ldr_reg_sp(s, 0, var_off)
        arm64_emit_movz_x(s, 1, 1, 0)
        arm64_emit_add_x(s, 0, 0, 1)
        arm64_emit_str_reg_sp(s, 0, var_off)

        // b loop_header
        cur_off = s.synth_code.len()
        rel_words = (loop_header - cur_off) / 4
        arm64_emit_b(s, rel_words)

        // Backpatch loop_exit
        loop_exit_off = s.synth_code.len()
        exit_words = (loop_exit_off - patch_loop_exit) / 4
        arm64_synth_patch_u32(s, patch_loop_exit, 1409286144 | ((exit_words & 524287) << 5) | 10)

        // Backpatch breaks
        bi = 0
        while bi < loop_brks.len()
            brk_patch = loop_brks[bi]
            b_words = (loop_exit_off - brk_patch) / 4
            arm64_synth_patch_u32(s, brk_patch, 335544320 | (b_words & 67108863))
            bi = bi + 1

        pop(s.synth_loop_starts)
        pop(s.synth_loop_breaks)
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
                arm64_synth_compile_expr(s, toks, pos_box)
                off = arm64_synth_alloc_var(s, var_name)
                arm64_emit_str_reg_sp(s, 0, off)
        return 0

    // ── 10. Assignment: <var> = <expr> ─────────────────────────────────────────
    if k == TOK_IDENT()
        next_pos = pos + 1
        if next_pos < toks.len() and toks[next_pos].tok_kind == TOK_ASSIGN()
            var_name = txt
            list_set(pos_box, 0, next_pos + 1) // Consume ident and '='
            arm64_synth_compile_expr(s, toks, pos_box)
            off = arm64_synth_alloc_var(s, var_name)
            arm64_emit_str_reg_sp(s, 0, off)
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
        fn_jmp_patch = s.synth_code.len()
        arm64_emit_b(s, 0) // Placeholder

        // Record function entry point (immediately after the skip jump)
        fn_entry = Arm64Function()
        fn_entry.fn_name = fn_name
        fn_entry.fn_entry_offset = s.synth_code.len()
        push(s.synth_functions, fn_entry)

        // Reset frame locals
        s.synth_locals = list()
        s.synth_stack_offset = 16
        s.synth_in_function = 1

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
        arm64_emit_prologue(s)

        // Save incoming argument registers (X0..X7) into local stack slots
        pi = 0
        while pi < params.len()
            pname = params[pi]
            off = arm64_synth_alloc_var(s, pname)
            if pi < 8
                arm64_emit_str_reg_sp(s, pi, off)
            pi = pi + 1

        // Parse function body statements until next function or EOF
        while get(pos_box, 0) < toks.len()
            cur_pos = get(pos_box, 0)
            ct = toks[cur_pos]
            if ct.tok_kind == TOK_KW_FN() or ct.tok_kind == TOK_DIR_FN()
                break
            if ct.tok_kind == TOK_IDENT() and (ct.tok_text == "fn" or ct.tok_text == "কাজ" or ct.tok_text == "@fn")
                break
            arm64_synth_compile_statement(s, toks, pos_box)

        // Default epilogue at end of function
        arm64_emit_movz_x(s, 0, 0, 0)
        arm64_emit_epilogue(s)
        s.synth_in_function = 0

        // Patch jump to bypass function body during top-level execution
        after_fn_offset = s.synth_code.len()
        rel_words = (after_fn_offset - fn_jmp_patch) / 4
        arm64_synth_patch_u32(s, fn_jmp_patch, 335544320 | (rel_words & 67108863))
        return 0

    // Default: evaluate expression or advance token
    arm64_synth_compile_expr(s, toks, pos_box)
    return 0

// ── 9. Master Program Synthesizer Entry Point ──────────────────────────────────

fn arm64_synth_compile_program tokens
    // WHY: Master orchestration entry point. Transforms complete token stream into
    // relocatable ARM64 machine code, sets up top-level stack frames, patches string relocations
    // against the Linux ELF virtual address space (0x400000+), and resolves call sites.
    s = arm64_synth_new()

    // 1. Emit top-level stack frame prologue at entry point (offset 0)
    arm64_emit_prologue(s)

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

        arm64_synth_compile_statement(s, tokens, pos_box)

    // 3. If there were NO top-level statements, but 'main' or 'মূল' exists, call main() automatically!
    has_main = 0
    main_name = ""
    if has_top_level == 0
        fi = 0
        while fi < s.synth_functions.len()
            fn_candidate = s.synth_functions[fi].fn_name
            if fn_candidate == "main" or fn_candidate == "মূল"
                has_main = 1
                main_name = fn_candidate
            fi = fi + 1
        if has_main == 1
            call_off = s.synth_code.len()
            arm64_emit_bl(s, 0) // Placeholder
            call_rel = Arm64CallReloc()
            call_rel.cr_patch_offset = call_off
            call_rel.cr_target_name = main_name
            push(s.synth_call_relocs, call_rel)

    // 4. Top-level exit epilogue
    if has_top_level == 1 or has_main == 0
        arm64_emit_movz_x(s, 0, 0, 0) // exit code 0
    // Exit via Linux sys_exit (syscall 93 on AArch64) with status code in X0
    arm64_emit_movz_x(s, 8, 93, 0)
    arm64_emit_svc(s, 0)

    // 5. Emit print_int helper if required
    if s.synth_needs_print_int == 1
        arm64_synth_emit_print_int_helper(s)

    // 5b. Emit sovereign alloc helper if required
    if s.synth_needs_alloc == 1
        arm64_synth_emit_alloc_helper(s)

    // 6. Resolve Inter-Procedural Call Relocations (BL disp26)
    ci = 0
    while ci < s.synth_call_relocs.len()
        cr = s.synth_call_relocs[ci]
        resolved_addr = 0
        if cr.cr_target_name == "__print_int"
            resolved_addr = s.synth_print_int_off
        elif cr.cr_target_name == "__alloc"
            resolved_addr = s.synth_alloc_off
        else
            k = 0
            while k < s.synth_functions.len()
                fn_item = s.synth_functions[k]
                if fn_item.fn_name == cr.cr_target_name
                    resolved_addr = fn_item.fn_entry_offset
                k = k + 1

        rel_words = (resolved_addr - cr.cr_patch_offset) / 4
        imm26 = rel_words & 67108863
        bl_word = 2483027968 | imm26
        arm64_synth_patch_u32(s, cr.cr_patch_offset, bl_word)
        ci = ci + 1

    // 7. Resolve 64-Bit Virtual Memory String Relocations
    total_code_size = s.synth_code.len()
    rodata_base_vaddr = 4194424 + total_code_size

    ri = 0
    while ri < s.synth_str_relocs.len()
        rel = s.synth_str_relocs[ri]
        target_vaddr = rodata_base_vaddr + rel.sr_rodata_offset
        arm64_synth_patch_mov_imm64(s, rel.sr_patch_offset, rel.sr_reg, target_vaddr)
        ri = ri + 1

    return s

// ── 10. ELF64 AArch64 Container Header Generator ──────────────────────────────

fn arm64_elf_emit_executable code_bytes rodata_bytes out_path
    // WHY: Packages the compiled AArch64 machine instructions and read-only constants into a
    // bit-perfect Linux ELF64 standalone executable container and persists it to disk with 0755 permissions.
    //
    // Binary Layout:
    //   - Base Virtual Address: 0x400000 (4194304)
    //   - ELF64 Header: 64 bytes (0x00 - 0x3F)
    //   - PT_LOAD Program Header: 56 bytes (0x40 - 0x77)
    //   - Total Header Overhead: 120 bytes (0x78)
    //   - Entry Point: 0x400078 (4194424) -> code_bytes starts immediately at offset 120
    //   - Machine: EM_AARCH64 = 183 (0x00B7)
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

    // e_machine: EM_AARCH64 (183 = 0x00B7) (2 bytes)
    push(elf, 183)
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

    // e_flags: 0 (4 bytes)
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

    // p_align: 64KB (65536 = 0x10000) (8 bytes)
    push(elf, 0)
    push(elf, 0)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // ── 3. Append Code Bytes ────────────────────────────────────────────────
    ci = 0
    while ci < code_size
        push(elf, code_bytes[ci])
        ci = ci + 1

    // ── 4. Append Rodata Bytes ──────────────────────────────────────────────
    ri = 0
    while ri < rodata_size
        push(elf, rodata_bytes[ri])
        ri = ri + 1

    // ── 5. Write Full Executable to Disk with 0755 Permissions ──────────────
    w_res = file_write_bytes(out_path, elf)
    if w_res < 0
        err_res = Arm64ElfResult()
        err_res.ew_success = 0
        err_res.ew_out_path = out_path
        err_res.ew_file_size = 0
        err_res.ew_entry_vaddr = entry_vaddr
        err_res.ew_error_msg = "Failed to write ARM64 ELF64 binary"
        return err_res

    res = Arm64ElfResult()
    res.ew_success = 1
    res.ew_out_path = out_path
    res.ew_file_size = elf.len()
    res.ew_entry_vaddr = entry_vaddr
    res.ew_error_msg = ""
    return res
