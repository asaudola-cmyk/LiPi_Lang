// ==============================================================================
// 👑 Lipi Sovereign ARM64 (AArch64) Native Silicon ELF64 Machine Code Emitter
// ⚡ Written 100% in Pure Lipi (.lp) Indentation Syntax | 0% C | 0% GCC | 0% Libc
// 🏛️ File: src/compiler/arm64_emitter.lp
//
// WHY: This module equips the Lipi Sovereign Programming Language with direct
//      silicon machine code emission for the 64-bit ARM (AArch64 / ARMv8-A+)
//      architecture. It provides byte-level synthesis of Linux AArch64 ELF64
//      binaries, exact 32-bit fixed instruction encoding, register allocation
//      primitives, label relocation backpatching, and Linux AArch64 syscall ABI.
// ==============================================================================

// ── Architectural & ELF64 Constants ───────────────────────────────────────────
// WHY: In AArch64 Linux, ET_EXEC binaries are conventionally loaded at 0x400000
//      with 64KB page alignment (0x10000) for standard Linux kernel page sizes.
ARM64_ELF_BASE_VADDR    = 4194304  // 0x400000
ARM64_ELF_HDR_SIZE     = 64       // Size of ELF64 file header in bytes
ARM64_PROG_HDR_SIZE    = 56       // Size of Program Header table entry in bytes
ARM64_TOTAL_HDR_SIZE   = 120      // Combined header overhead: 64 + 56 = 120 bytes
ARM64_ENTRY_POINT      = 4194424  // 0x400078 = 0x400000 + 120 (immediate entry after headers)
ARM64_EM_AARCH64       = 183      // 0x00B7 = EM_AARCH64 (official ELF machine architecture ID)
ARM64_PAGE_SIZE        = 65536    // 64KB page size for modern AArch64 kernels

// ── Linux AArch64 Syscall Numbers ─────────────────────────────────────────────
// WHY: Linux AArch64 uses the unistd.h asm-generic syscall numbering table,
//      which differs significantly from legacy x86_64. Syscall number is loaded into X8.
ARM64_SYS_READ         = 63       // sys_read(fd, buf, count)
ARM64_SYS_WRITE        = 64       // sys_write(fd, buf, count)
ARM64_SYS_CLOSE        = 57       // sys_close(fd)
ARM64_SYS_EXIT         = 93       // sys_exit(status)
ARM64_SYS_EXIT_GROUP   = 94       // sys_exit_group(status)
ARM64_SYS_OPENAT       = 56       // sys_openat(dfd, filename, flags, mode)
ARM64_SYS_BRK          = 214      // sys_brk(brk)
ARM64_SYS_MUNMAP       = 215      // sys_munmap(addr, len)
ARM64_SYS_MMAP         = 222      // sys_mmap(addr, len, prot, flags, fd, off)

// ── General Purpose Register Constants ───────────────────────────────────────
// WHY: Symbolic names for the 31 AArch64 general-purpose registers (X0 - X30)
//      and special registers (XZR, SP) ensure clarity and prevent indexing bugs.
ARM64_REG_X0           = 0        // Arg 1 / Return value
ARM64_REG_X1           = 1        // Arg 2
ARM64_REG_X2           = 2        // Arg 3
ARM64_REG_X3           = 3        // Arg 4
ARM64_REG_X4           = 4        // Arg 5
ARM64_REG_X5           = 5        // Arg 6
ARM64_REG_X6           = 6        // Arg 7
ARM64_REG_X7           = 7        // Arg 8
ARM64_REG_X8           = 8        // Linux AArch64 syscall number register
ARM64_REG_X9           = 9        // Caller-saved temporary
ARM64_REG_X10          = 10
ARM64_REG_X11          = 11
ARM64_REG_X12          = 12
ARM64_REG_X13          = 13
ARM64_REG_X14          = 14
ARM64_REG_X15          = 15
ARM64_REG_X16          = 16       // IP0 (intra-procedure call temporary)
ARM64_REG_X17          = 17       // IP1 (intra-procedure call temporary)
ARM64_REG_X18          = 18       // Platform register (reserved on Linux)
ARM64_REG_X19          = 19       // Callee-saved register
ARM64_REG_X20          = 20
ARM64_REG_X21          = 21
ARM64_REG_X22          = 22
ARM64_REG_X23          = 23
ARM64_REG_X24          = 24
ARM64_REG_X25          = 25
ARM64_REG_X26          = 26
ARM64_REG_X27          = 27
ARM64_REG_X28          = 28
ARM64_REG_X29          = 29       // FP: Frame Pointer
ARM64_REG_X30          = 30       // LR: Link Register (subroutine return address)
ARM64_REG_XZR          = 31       // Zero Register
ARM64_REG_SP           = 31       // Stack Pointer (context dependent)

// ── Relocation Type Identifiers ───────────────────────────────────────────────
ARM64_RELOC_B          = 1        // 26-bit unconditional branch (B)
ARM64_RELOC_CBZ        = 2        // 19-bit conditional branch if zero (CBZ)
ARM64_RELOC_CBNZ       = 3        // 19-bit conditional branch if not zero (CBNZ)
ARM64_RELOC_ADR        = 4        // 21-bit PC-relative address formation (ADR)
ARM64_RELOC_BL         = 5        // 26-bit subroutine procedure call (BL)
ARM64_RELOC_B_COND     = 6        // 19-bit conditional branch (B.cond)

// ── Hardware Condition Codes (NZCV Condition Field) ──────────────────────────
ARM64_COND_EQ          = 0        // Equal (Z == 1)
ARM64_COND_NE          = 1        // Not equal (Z == 0)
ARM64_COND_GE          = 10       // Signed greater than or equal (N == V)
ARM64_COND_LT          = 11       // Signed less than (N != V)
ARM64_COND_GT          = 12       // Signed greater than (Z == 0 and N == V)
ARM64_COND_LE          = 13       // Signed less than or equal (not (Z == 0 and N == V))

// ── Emitter Context Container ────────────────────────────────────────────────
// WHY: Mutable list container enables state propagation across function boundaries
//      without global variables or side-effects.
// Fields:
//   0: bb (raw code byte buffer: list of ints 0..255)
//   1: lbl_names (list of string label names)
//   2: lbl_offsets (list of byte offsets corresponding to labels)
//   3: reloc_pos (list of patch positions in bb)
//   4: reloc_target (list of target label names)
//   5: reloc_type (list of relocation type IDs: B, CBZ, CBNZ, ADR)
//   6: reloc_reg (list of register operands associated with relocation)
//   7: str_texts (string literal contents)
//   8: str_labels (symbolic label names for strings)
//   9: anon_id (list with 1 integer for generating unique anonymous labels)
//  10: sc_names (list of local variable names in current scope)
//  11: sc_offs (list of stack byte offsets for local variables)
//  12: sc_stack (list with 1 int: current local stack byte watermark)
//  13: loop_start_stack (label stack for loop continue statements)
//  14: loop_end_stack (label stack for loop break statements)
//  15: glob_names (constant folded global identifiers)
//  16: glob_vals (constant folded integer values)
fn arm64_ctx_new
    c = list()
    push(c, list())     // 0: bb
    push(c, list())     // 1: lbl_names
    push(c, list())     // 2: lbl_offsets
    push(c, list())     // 3: reloc_pos
    push(c, list())     // 4: reloc_target
    push(c, list())     // 5: reloc_type
    push(c, list())     // 6: reloc_reg
    push(c, list())     // 7: str_texts
    push(c, list())     // 8: str_labels
    push(c, list(0))    // 9: anon_id
    push(c, list())     // 10: sc_names
    push(c, list())     // 11: sc_offs
    push(c, list(16))   // 12: sc_stack
    push(c, list())     // 13: loop_start_stack
    push(c, list())     // 14: loop_end_stack
    push(c, list())     // 15: glob_names
    push(c, list())     // 16: glob_vals
    push(c, list())     // 17: struct_names
    push(c, list())     // 18: struct_fields
    push(c, list(""))   // 19: current_impl
    return c

// ── Struct Definition & Field Offset Registry ─────────────────────────────────
// WHY: Enables native ARM64 object orientation and field access with zero libc dependencies
fn arm64_struct_add ctx name fields
    push(get(ctx, 17), name)
    push(get(ctx, 18), fields)
    return 0

fn arm64_struct_find ctx name
    snames = get(ctx, 17)
    i = 0
    while i < len(snames)
        if get(snames, i) == name
            return i
        i = i + 1
    return 0 - 1

fn arm64_struct_get_field_offset ctx sname fname
    snames = get(ctx, 17)
    sfields = get(ctx, 18)
    if sname != ""
        sidx = arm64_struct_find(ctx, sname)
        if sidx >= 0
            fnames = get(sfields, sidx)
            f = 0
            while f < len(fnames)
                if get(fnames, f) == fname
                    return f * 8
                f = f + 1
    // Fallback: search across all defined structs for matching field name
    s = 0
    while s < len(snames)
        fnames = get(sfields, s)
        f = 0
        while f < len(fnames)
            if get(fnames, f) == fname
                return f * 8
            f = f + 1
        s = s + 1
    return 0

fn arm64_ctx_bb ctx
    return get(ctx, 0)

fn arm64_ctx_len ctx
    return len(get(ctx, 0))

// ── Dynamic Byte Buffer Operations ───────────────────────────────────────────
// WHY: Machine code bytes must be appended and patched with exact two's complement
//      little-endian ordering. We use pure mathematical division/modulo to avoid
//      runtime bitwise dependencies.

fn arm64_bb_put8 ctx b
    bb = get(ctx, 0)
    val = floor(b) % 256
    if val < 0
        val = val + 256
    push(bb, val)

fn arm64_bb_put16 ctx val
    v = floor(val)
    if v < 0
        v = v + 65536
    arm64_bb_put8(ctx, v % 256)
    arm64_bb_put8(ctx, floor(v / 256) % 256)

fn arm64_bb_put32 ctx val
    v = floor(val)
    if v < 0
        v = v + 4294967296
    arm64_bb_put8(ctx, v % 256)
    arm64_bb_put8(ctx, floor(v / 256) % 256)
    arm64_bb_put8(ctx, floor(v / 65536) % 256)
    arm64_bb_put8(ctx, floor(v / 16777216) % 256)

fn arm64_bb_put64 ctx val
    v = floor(val)
    if v < 0
        lo = v + 4294967296
        hi = 4294967295
        arm64_bb_put32(ctx, lo)
        arm64_bb_put32(ctx, hi)
        return 0
    lo = v % 4294967296
    hi = floor(v / 4294967296) % 4294967296
    arm64_bb_put32(ctx, lo)
    arm64_bb_put32(ctx, hi)

fn arm64_bb_set8 ctx pos val
    bb = get(ctx, 0)
    v = floor(val) % 256
    if v < 0
        v = v + 256
    list_set(bb, pos, v)

fn arm64_bb_set32 ctx pos val
    v = floor(val)
    if v < 0
        v = v + 4294967296
    arm64_bb_set8(ctx, pos + 0, v % 256)
    arm64_bb_set8(ctx, pos + 1, floor(v / 256) % 256)
    arm64_bb_set8(ctx, pos + 2, floor(v / 65536) % 256)
    arm64_bb_set8(ctx, pos + 3, floor(v / 16777216) % 256)

fn arm64_bb_write ctx bytes_list
    bi = 0
    blen = len(bytes_list)
    while bi < blen
        arm64_bb_put8(ctx, get(bytes_list, bi))
        bi = bi + 1

// Emit an already-encoded 32-bit instruction word directly into the context byte buffer
fn arm64_emit ctx word32
    arm64_bb_put32(ctx, word32)

// ── ARM64 Instruction Encoders (Pure Mathematical Synthesis) ──────────────────
// WHY: All AArch64 machine instructions are strictly 32-bit (4-byte) aligned.
//      These pure functions return the exact 32-bit integer word representation.

// 1. MOVZ: Move wide with zero (64-bit variant, sf=1)
// WHY: Loads a 16-bit immediate into register Rd at shift position (0, 16, 32, 48),
//      zeroing all other bits in the 64-bit destination register.
// Format: sf(1)=1 | opc(2)=10 | 100101 | hw(2)=shift/16 | imm16(16) | Rd(5)
// Base: 0xD2800000 = 3531603968
fn arm64_movz rd imm16 shift
    hw = floor(shift / 16) % 4
    imm = floor(imm16) % 65536
    if imm < 0
        imm = imm + 65536
    r = floor(rd) % 32
    return 3531603968 + (hw * 2097152) + (imm * 32) + r

// 2. MOVK: Move wide with keep (64-bit variant, sf=1)
// WHY: Overwrites a 16-bit slice of register Rd at shift position (0, 16, 32, 48)
//      while preserving all other existing bits. Essential for 64-bit constant synthesis.
// Format: sf(1)=1 | opc(2)=11 | 100101 | hw(2)=shift/16 | imm16(16) | Rd(5)
// Base: 0xF2800000 = 4068474880
fn arm64_movk rd imm16 shift
    hw = floor(shift / 16) % 4
    imm = floor(imm16) % 65536
    if imm < 0
        imm = imm + 65536
    r = floor(rd) % 32
    return 4068474880 + (hw * 2097152) + (imm * 32) + r

// 3. ADD: Add register (64-bit shifted register variant, no shift)
// WHY: Performs Xd = Xn + Xm without updating condition flags.
// Format: sf(1)=1 | op(1)=0 | S(1)=0 | 01011 | shift(2)=00 | 0 | Rm(5) | imm6(6)=0 | Rn(5) | Rd(5)
// Base: 0x8B000000 = 2332033024
fn arm64_add rd rn rm
    d = floor(rd) % 32
    n = floor(rn) % 32
    m = floor(rm) % 32
    return 2332033024 + (m * 65536) + (n * 32) + d

// 4. SUB: Subtract register (64-bit shifted register variant, no shift)
// WHY: Performs Xd = Xn - Xm without updating condition flags.
// Format: sf(1)=1 | op(1)=1 | S(1)=0 | 01011 | shift(2)=00 | 0 | Rm(5) | imm6(6)=0 | Rn(5) | Rd(5)
// Base: 0xCB000000 = 3405774848
fn arm64_sub rd rn rm
    d = floor(rd) % 32
    n = floor(rn) % 32
    m = floor(rm) % 32
    return 3405774848 + (m * 65536) + (n * 32) + d

// 5. LDR: Load register with unsigned immediate (64-bit variant, size=11, opc=01)
// WHY: Loads 64-bit word from memory address [Xn + #imm12*8] into Xt.
//      Accepts either 12-bit scaled field or unscaled byte offset divisible by 8.
// Format: size(2)=11 | 111 | V(1)=0 | 01 | opc(2)=01 | imm12(12) | Rn(5) | Rt(5)
// Base: 0xF9400000 = 4181721088
fn arm64_ldr_imm rt rn imm12
    imm_field = floor(imm12)
    if imm_field > 4095 and (imm_field % 8) == 0
        imm_field = floor(imm_field / 8)
    imm_field = imm_field % 4096
    if imm_field < 0
        imm_field = imm_field + 4096
    n = floor(rn) % 32
    t = floor(rt) % 32
    return 4181721088 + (imm_field * 1024) + (n * 32) + t

// 6. STR: Store register with unsigned immediate (64-bit variant, size=11, opc=00)
// WHY: Stores 64-bit word from Xt into memory address [Xn + #imm12*8].
//      Accepts either 12-bit scaled field or unscaled byte offset divisible by 8.
// Format: size(2)=11 | 111 | V(1)=0 | 01 | opc(2)=00 | imm12(12) | Rn(5) | Rt(5)
// Base: 0xF9000000 = 4177526784
fn arm64_str_imm rt rn imm12
    imm_field = floor(imm12)
    if imm_field > 4095 and (imm_field % 8) == 0
        imm_field = floor(imm_field / 8)
    imm_field = imm_field % 4096
    if imm_field < 0
        imm_field = imm_field + 4096
    n = floor(rn) % 32
    t = floor(rt) % 32
    return 4177526784 + (imm_field * 1024) + (n * 32) + t

// 7. SVC: Supervisor Call (Syscall trap for Linux AArch64)
// WHY: Traps to kernel privilege mode to execute Linux syscalls.
//      Linux AArch64 requires SVC #0 (0xD4000001).
// Format: 11010100 | 000 | imm16(16) | 000 | 01
// Base: 0xD4000001 = 3556769793
fn arm64_svc imm16
    imm = floor(imm16) % 65536
    if imm < 0
        imm = imm + 65536
    return 3556769793 + (imm * 32)

// 8. RET: Return from subroutine (default X30 / LR)
// WHY: Subroutine return branching to link register (X30).
// Format: 1101011 | 0001 | 11111 | 000000 | Rn(5)=11110 | 00000
// Base: 0xD65F03C0 = 3596551104
fn arm64_ret
    return 3596551104

// 9. B: Unconditional branch (PC-relative 26-bit instruction displacement)
// WHY: Direct jump to target address within +/- 128MB of current PC.
//      Displacement is specified in bytes and scaled by 4 internally.
// Format: 000101 | imm26(26)
// Base: 0x14000000 = 335544320
fn arm64_b disp
    offset = floor(disp / 4)
    if offset < 0
        imm26 = offset + 67108864
    else
        imm26 = offset % 67108864
    return 335544320 + imm26

// 10. CBZ: Compare and branch if zero (64-bit variant, sf=1)
// WHY: Branches to PC + disp if register Rt contains zero.
//      Displacement is specified in bytes (+/- 1MB range) and scaled by 4.
// Format: sf(1)=1 | 011010 | op(1)=0 | imm19(19) | Rt(5)
// Base: 0xB4000000 = 3019898880
fn arm64_cbz rt disp
    offset = floor(disp / 4)
    if offset < 0
        imm19 = offset + 524288
    else
        imm19 = offset % 524288
    t = floor(rt) % 32
    return 3019898880 + (imm19 * 32) + t

// ── Extended High-Value Silicon Encoders ───────────────────────────────────────

// CBNZ: Compare and branch if not zero (64-bit variant, sf=1)
// Base: 0xB5000000 = 3036676096
fn arm64_cbnz rt disp
    offset = floor(disp / 4)
    if offset < 0
        imm19 = offset + 524288
    else
        imm19 = offset % 524288
    t = floor(rt) % 32
    return 3036676096 + (imm19 * 32) + t

// MOV Xd, Xm: Register-to-register move (alias for ORR Xd, XZR, Xm)
// Base: 0xAA0003E0 = 2852127712
fn arm64_mov_reg rd rm
    d = floor(rd) % 32
    m = floor(rm) % 32
    return 2852127712 + (m * 65536) + d

// ADR: Form PC-relative address (21-bit signed byte displacement, +/- 1MB)
// WHY: Loads the address of a string literal or data symbol relative to the PC.
// Format: 0 | immlo(2) | 10000 | immhi(19) | Rd(5)
// Base: 0x10000000 = 268435456
fn arm64_adr rd disp
    d = floor(disp)
    if d < 0
        d = d + 2097152
    immlo = d % 4
    immhi = floor(d / 4) % 524288
    r = floor(rd) % 32
    return 268435456 + (immlo * 536870912) + (immhi * 32) + r

// NOP: No Operation
// Opcode: 0xD503201F = 3573751839
fn arm64_nop
    return 3573751839

// B.cond: Conditional branch (+/- 1MB range, imm19 displacement)
// Format: 01010100 | imm19(19) | 0 | cond(4)
// Base: 0x54000000 = 1409286144
fn arm64_b_cond cond disp
    offset = floor(disp / 4)
    if offset < 0
        imm19 = offset + 524288
    else
        imm19 = offset % 524288
    c = floor(cond) % 16
    return 1409286144 + (imm19 * 32) + c


// BL: Branch with link (Procedure call, saves return address in X30 / LR)
// Base: 0x94000000 = 2483027968
fn arm64_bl disp
    offset = floor(disp / 4)
    if offset < 0
        imm26 = offset + 67108864
    else
        imm26 = offset % 67108864
    return 2483027968 + imm26

// RET to specific register Xn
fn arm64_ret_reg rn
    r = floor(rn) % 32
    return 3596551040 + (r * 32)

// ── Context Emission Primitives ───────────────────────────────────────────────
// WHY: These wrappers encode the instruction and append the resulting 4 bytes
//      directly into the compilation context byte stream.

fn arm64_emit_movz ctx rd imm16 shift
    arm64_emit(ctx, arm64_movz(rd, imm16, shift))

fn arm64_emit_movk ctx rd imm16 shift
    arm64_emit(ctx, arm64_movk(rd, imm16, shift))

fn arm64_emit_add ctx rd rn rm
    arm64_emit(ctx, arm64_add(rd, rn, rm))

fn arm64_emit_sub ctx rd rn rm
    arm64_emit(ctx, arm64_sub(rd, rn, rm))

fn arm64_emit_ldr_imm ctx rt rn imm12
    arm64_emit(ctx, arm64_ldr_imm(rt, rn, imm12))

fn arm64_emit_str_imm ctx rt rn imm12
    arm64_emit(ctx, arm64_str_imm(rt, rn, imm12))

fn arm64_emit_svc ctx imm16
    arm64_emit(ctx, arm64_svc(imm16))

fn arm64_emit_ret ctx
    arm64_emit(ctx, arm64_ret())

fn arm64_emit_b ctx disp
    arm64_emit(ctx, arm64_b(disp))

fn arm64_emit_cbz ctx rt disp
    arm64_emit(ctx, arm64_cbz(rt, disp))

fn arm64_emit_cbnz ctx rt disp
    arm64_emit(ctx, arm64_cbnz(rt, disp))

fn arm64_emit_mov_reg ctx rd rm
    arm64_emit(ctx, arm64_mov_reg(rd, rm))

fn arm64_emit_adr ctx rd disp
    arm64_emit(ctx, arm64_adr(rd, disp))

fn arm64_emit_bl ctx disp
    arm64_emit(ctx, arm64_bl(disp))

fn arm64_emit_nop ctx
    arm64_emit(ctx, arm64_nop())

// ── Arbitrary 64-Bit Immediate Loading Synthesis ─────────────────────────────
// WHY: In ARM64, instructions are fixed 32 bits, so 64-bit immediates cannot be
//      loaded in a single instruction. We decompose the 64-bit integer into 4
//      16-bit chunks and emit MOVZ for the first non-zero slice followed by MOVK
//      for subsequent non-zero slices, yielding optimal instruction sequences.
fn arm64_emit_mov_imm64 ctx rd val
    v = floor(val)
    if v == 0
        arm64_emit_movz(ctx, rd, 0, 0)
        return 0

    // Extract 4 16-bit chunks
    c0 = v % 65536
    c1 = floor(v / 65536) % 65536
    c2 = floor(v / 4294967296) % 65536
    c3 = floor(v / 281474976710656) % 65536

    initialized = 0
    if c0 != 0
        arm64_emit_movz(ctx, rd, c0, 0)
        initialized = 1

    if c1 != 0
        if initialized == 0
            arm64_emit_movz(ctx, rd, c1, 16)
            initialized = 1
        else
            arm64_emit_movk(ctx, rd, c1, 16)

    if c2 != 0
        if initialized == 0
            arm64_emit_movz(ctx, rd, c2, 32)
            initialized = 1
        else
            arm64_emit_movk(ctx, rd, c2, 32)

    if c3 != 0
        if initialized == 0
            arm64_emit_movz(ctx, rd, c3, 48)
            initialized = 1
        else
            arm64_emit_movk(ctx, rd, c3, 48)

    return 0

// ── Labels & Relocation Management ───────────────────────────────────────────
// WHY: Forward branches and data references cannot be resolved until total code size
//      is known. We emit zero placeholder words and record relocations for backpatching.

fn arm64_label_define ctx name
    bb = get(ctx, 0)
    offset = len(bb)
    push(get(ctx, 1), name)
    push(get(ctx, 2), offset)

fn arm64_label_find ctx name
    names = get(ctx, 1)
    offs  = get(ctx, 2)
    i = 0
    while i < len(names)
        if get(names, i) == name
            return get(offs, i)
        i = i + 1
    say "Undefined ARM64 label: " + name
    exit(1)
    return 0

fn arm64_reloc_add ctx patch_pos target_name reloc_type reg
    push(get(ctx, 3), patch_pos)
    push(get(ctx, 4), target_name)
    push(get(ctx, 5), reloc_type)
    push(get(ctx, 6), reg)

fn arm64_emit_b_label ctx target_name
    pos = arm64_ctx_len(ctx)
    arm64_emit(ctx, 0) // Placeholder
    arm64_reloc_add(ctx, pos, target_name, ARM64_RELOC_B, 0)

fn arm64_emit_cbz_label ctx rt target_name
    pos = arm64_ctx_len(ctx)
    arm64_emit(ctx, 0) // Placeholder
    arm64_reloc_add(ctx, pos, target_name, ARM64_RELOC_CBZ, rt)

fn arm64_emit_cbnz_label ctx rt target_name
    pos = arm64_ctx_len(ctx)
    arm64_emit(ctx, 0) // Placeholder
    arm64_reloc_add(ctx, pos, target_name, ARM64_RELOC_CBNZ, rt)

fn arm64_emit_adr_label ctx rd target_name
    pos = arm64_ctx_len(ctx)
    arm64_emit(ctx, 0) // Placeholder
    arm64_reloc_add(ctx, pos, target_name, ARM64_RELOC_ADR, rd)

// Resolves all recorded relocations by computing exact PC displacements and rewriting instruction words
fn arm64_backpatch_all ctx
    r_pos    = get(ctx, 3)
    r_target = get(ctx, 4)
    r_type   = get(ctx, 5)
    r_reg    = get(ctx, 6)

    i = 0
    while i < len(r_pos)
        patch_pos   = get(r_pos, i)
        target_name = get(r_target, i)
        reloc_type  = get(r_type, i)
        reg_op      = get(r_reg, i)

        target_pos  = arm64_label_find(ctx, target_name)
        disp        = target_pos - patch_pos

        if reloc_type == ARM64_RELOC_B
            word = arm64_b(disp)
            arm64_bb_set32(ctx, patch_pos, word)
        elif reloc_type == ARM64_RELOC_CBZ
            word = arm64_cbz(reg_op, disp)
            arm64_bb_set32(ctx, patch_pos, word)
        elif reloc_type == ARM64_RELOC_CBNZ
            word = arm64_cbnz(reg_op, disp)
            arm64_bb_set32(ctx, patch_pos, word)
        elif reloc_type == ARM64_RELOC_ADR
            word = arm64_adr(reg_op, disp)
            arm64_bb_set32(ctx, patch_pos, word)
        elif reloc_type == ARM64_RELOC_BL
            word = arm64_bl(disp)
            arm64_bb_set32(ctx, patch_pos, word)
        elif reloc_type == ARM64_RELOC_B_COND
            word = arm64_b_cond(reg_op, disp)
            arm64_bb_set32(ctx, patch_pos, word)

        i = i + 1

// ── String Literal Constant Pool ──────────────────────────────────────────────
fn arm64_string_add ctx text
    texts  = get(ctx, 7)
    labels = get(ctx, 8)
    i = 0
    while i < len(texts)
        if get(texts, i) == text
            return get(labels, i)
        i = i + 1
    lbl = "str_arm64_" + str(len(texts))
    push(texts, text)
    push(labels, lbl)
    return lbl

fn arm64_emit_strings ctx
    texts  = get(ctx, 7)
    labels = get(ctx, 8)
    i = 0
    while i < len(texts)
        lbl = get(labels, i)
        txt = get(texts, i)
        tlen = len(txt)

        // WHY: Prefix 8-byte STR0 tag: lower 32-bits = length, upper 32-bits = 0x53545230 ('STR0')
        // Provides deterministic O(1) string length and type tagging across ARM64 runtime.
        arm64_bb_put32(ctx, tlen)
        arm64_bb_put32(ctx, 1398034992) // 0x53545230 ('STR0')

        arm64_label_define(ctx, lbl)
        ti = 0
        while ti < tlen
            arm64_bb_put8(ctx, ord(char_at(txt, ti)))
            ti = ti + 1
        arm64_bb_put8(ctx, 0) // Null terminator

        // Pad to 8-byte boundary
        rem = arm64_ctx_len(ctx) % 8
        if rem != 0
            pad = 8 - rem
            pi = 0
            while pi < pad
                arm64_bb_put8(ctx, 0)
                pi = pi + 1
        i = i + 1

    // Global heap and process execution state variables
    arm64_label_define(ctx, "_lipi_heap_base")
    arm64_bb_put64(ctx, 0)
    arm64_label_define(ctx, "_lipi_heap_ptr")
    arm64_bb_put64(ctx, 0)
    arm64_label_define(ctx, "_lipi_initial_sp")
    arm64_bb_put64(ctx, 0)

// ── Linux AArch64 Syscall Convention Helpers ─────────────────────────────────
// WHY: Implements the Linux AArch64 ABI calling convention:
//      - X8: Syscall number (e.g. 64 for write, 93 for exit)
//      - X0: arg1
//      - X1: arg2
//      - X2: arg3
//      - X3: arg4
//      - X4: arg5
//      - X5: arg6
//      - Trapped via SVC #0 (0xD4000001)

fn arm64_emit_sys_exit ctx exit_code
    arm64_emit_mov_imm64(ctx, ARM64_REG_X0, exit_code)
    arm64_emit_movz(ctx, ARM64_REG_X8, ARM64_SYS_EXIT, 0)
    arm64_emit_svc(ctx, 0)

fn arm64_emit_sys_write ctx fd buf_label count
    arm64_emit_mov_imm64(ctx, ARM64_REG_X0, fd)
    arm64_emit_adr_label(ctx, ARM64_REG_X1, buf_label)
    arm64_emit_mov_imm64(ctx, ARM64_REG_X2, count)
    arm64_emit_movz(ctx, ARM64_REG_X8, ARM64_SYS_WRITE, 0)
    arm64_emit_svc(ctx, 0)

// ── Complete Linux AArch64 ELF64 Binary Synthesis ─────────────────────────────
// WHY: Assembles the valid 64-byte ELF64 file header and 56-byte PT_LOAD program
//      header followed by the raw ARM64 machine code and data.
fn arm64_build_elf ctx
    code_bb = arm64_ctx_bb(ctx)
    total_size = ARM64_TOTAL_HDR_SIZE + len(code_bb)
    elf = list()

    // 1. ELF64 Header (64 bytes)
    // Magic: 0x7F, 'E', 'L', 'F', 2 (64-bit), 1 (little-endian), 1 (version 1), 0 (System V), 8 zeroes
    ident = list(127, 69, 76, 70, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    ii = 0
    while ii < len(ident)
        push(elf, get(ident, ii))
        ii = ii + 1

    // e_type: ET_EXEC (0x0002) - Executable file
    push(elf, 2)
    push(elf, 0)

    // e_machine: EM_AARCH64 (183 = 0x00B7)
    push(elf, 183)
    push(elf, 0)

    // e_version: EV_CURRENT (1)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_entry: 0x400078 (4194424) -> 0x400000 + 120 bytes
    push(elf, 120)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_phoff: 64 (0x00000040) -> Program header immediately follows ELF header
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_shoff: 0 (No section headers in raw sovereign binary)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_flags: 0
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // e_ehsize: 64 bytes (ELF header size)
    push(elf, 64)
    push(elf, 0)

    // e_phentsize: 56 bytes (Program header entry size)
    push(elf, 56)
    push(elf, 0)

    // e_phnum: 1 (Single monolithic PT_LOAD segment)
    push(elf, 1)
    push(elf, 0)

    // e_shentsize: 0
    push(elf, 0)
    push(elf, 0)

    // e_shnum: 0
    push(elf, 0)
    push(elf, 0)

    // e_shstrndx: 0
    push(elf, 0)
    push(elf, 0)

    // 2. Program Header Table (56 bytes, PT_LOAD)
    // p_type: PT_LOAD (1)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_flags: PF_R | PF_W | PF_X = 7 (Read, Write, Execute permissions)
    push(elf, 7)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_offset: 0 (Segment starts at beginning of file)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_vaddr: 0x400000 (Base virtual address)
    push(elf, 0)
    push(elf, 0)
    push(elf, 64)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_paddr: 0x400000 (Physical address)
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
    push(elf, floor(total_size / 256) % 256)
    push(elf, floor(total_size / 65536) % 256)
    push(elf, floor(total_size / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_memsz: total_size (8 bytes)
    push(elf, total_size % 256)
    push(elf, floor(total_size / 256) % 256)
    push(elf, floor(total_size / 65536) % 256)
    push(elf, floor(total_size / 16777216) % 256)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // p_align: 64KB (0x10000 = 65536) for AArch64 kernel memory mapping
    push(elf, 0)
    push(elf, 0)
    push(elf, 1)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)
    push(elf, 0)

    // 3. User Code & Data bytes
    ci = 0
    clen = len(code_bb)
    while ci < clen
        push(elf, get(code_bb, ci))
        ci = ci + 1

    return elf

// ── Write Executable ELF Binary to Disk ───────────────────────────────────────
// WHY: Commits the generated Linux AArch64 executable directly to the filesystem
//      with executable permissions (0755) via pure Lipi file primitives.
fn arm64_write_elf ctx out_path
    arm64_emit_strings(ctx)
    arm64_backpatch_all(ctx)
    elf = arm64_build_elf(ctx)
    res = file_write_bytes(out_path, elf)
    return res

// ==============================================================================
// 🏛️ PART II: ARM64 Silicon Arithmetic, Control Flow & Instruction Synthesis
// ==============================================================================

// MUL: Multiply register (64-bit variant, alias for MADD Xd, Xn, Xm, XZR)
// WHY: In ARM64, 64-bit integer multiplication is synthesized via MADD with accumulator Ra = XZR (31).
// Format: sf(1)=1 | op54(2)=00 | 11011 | op31(3)=000 | Rm(5) | 0 | Ra(5)=11111 | Rn(5) | Rd(5)
// Base: 0x9B007C00 = 2600498176
fn arm64_mul rd rn rm
    d = floor(rd) % 32
    n = floor(rn) % 32
    m = floor(rm) % 32
    return 2600498176 + (m * 65536) + (n * 32) + d

// SDIV: Signed divide register (64-bit variant)
// WHY: Hardware integer division truncating toward zero according to standard language semantics.
// Format: sf(1)=1 | 00 | 11010 | 110 | Rm(5) | 000011 | Rn(5) | Rd(5)
// Base: 0x9AC00C00 = 2596342784
fn arm64_sdiv rd rn rm
    d = floor(rd) % 32
    n = floor(rn) % 32
    m = floor(rm) % 32
    return 2596342784 + (m * 65536) + (n * 32) + d

// UDIV: Unsigned divide register (64-bit variant)
// Base: 0x9AC00800 = 2596341760
fn arm64_udiv rd rn rm
    d = floor(rd) % 32
    n = floor(rn) % 32
    m = floor(rm) % 32
    return 2596341760 + (m * 65536) + (n * 32) + d

// MSUB: Multiply-subtract (Xd = Xa - Xn * Xm)
// WHY: Used for single-instruction remainder computation: rem = Xa - (Xa / Xm) * Xm.
// Base: 0x9B008000 = 2600501248
fn arm64_msub rd rn rm ra
    d = floor(rd) % 32
    n = floor(rn) % 32
    m = floor(rm) % 32
    a = floor(ra) % 32
    return 2600501248 + (m * 65536) + (a * 1024) + (n * 32) + d

// CMP: Compare registers (alias for SUBS XZR, Xn, Xm)
// WHY: Updates hardware condition flags NZCV based on Xn - Xm without saving result.
// Base: 0xEB00001F = 3942645791
fn arm64_cmp rn rm
    n = floor(rn) % 32
    m = floor(rm) % 32
    return 3942645760 + (m * 65536) + (n * 32) + 31

// CMP immediate: Compare register with 12-bit unsigned immediate (alias for SUBS XZR, Xn, #imm12)
// Base: 0xF100001F = 4043309087
fn arm64_cmp_imm rn imm12
    n = floor(rn) % 32
    imm = floor(imm12) % 4096
    if imm < 0
        imm = imm + 4096
    return 4043309087 + (imm * 1024) + (n * 32)

// CSET: Conditional set (sets Rd = 1 if condition true, 0 if false)
// WHY: Synthesizes branchless comparison expressions using CSINC Xd, XZR, XZR, invert(cond).
// Base: 0x9A9F07E0 = 2594113504
fn arm64_cset rd cond
    d = floor(rd) % 32
    c = floor(cond)
    cond_field = 0
    if c == ARM64_COND_EQ
        cond_field = 1
    elif c == ARM64_COND_NE
        cond_field = 0
    elif c == ARM64_COND_GE
        cond_field = 11
    elif c == ARM64_COND_LT
        cond_field = 10
    elif c == ARM64_COND_GT
        cond_field = 13
    elif c == ARM64_COND_LE
        cond_field = 12
    return 2594113504 + (cond_field * 4096) + d

// B.cond: Conditional branch with signed 19-bit displacement (+/- 1MB)
// Base: 0x54000000 = 1409286144
fn arm64_b_cond cond disp
    offset = floor(disp / 4)
    if offset < 0
        imm19 = offset + 524288
    else
        imm19 = offset % 524288
    c = floor(cond) % 16
    return 1409286144 + (imm19 * 32) + c

// Push 64-bit register Xt onto stack (pre-index: str Xt, [sp, #-16]!)
// WHY: AArch64 hardware requires the Stack Pointer (SP) to remain strictly 16-byte
//      aligned during all memory transactions. Pushing with #-16 maintains alignment.
// Opcode base: 0xF81F0FE0 = 4162785248
fn arm64_push_reg ctx reg
    r = floor(reg) % 32
    arm64_emit(ctx, 4162785248 + r)

// Pop 64-bit register Xt from stack (post-index: ldr Xt, [sp], #16)
// Opcode base: 0xF84107E0 = 4165011424
fn arm64_pop_reg ctx reg
    r = floor(reg) % 32
    arm64_emit(ctx, 4165011424 + r)

// Standard AArch64 Procedure Call Standard (AAPCS64) Frame Setup:
//   1. stp x29, x30, [sp, #-16]!  (Save frame pointer and link register)
//   2. mov x29, sp                (Establish frame pointer)
//   3. sub sp, sp, #2048          (Allocate 2KB local stack frame)
fn arm64_emit_prologue ctx
    arm64_emit(ctx, 2847898621) // stp x29, x30, [sp, #-16]! (0xA9BF7BFD)
    arm64_emit(ctx, 2432697341) // mov x29, sp               (0x910003FD)
    arm64_emit(ctx, 3508536319) // sub sp, sp, #2048         (0xD12003FF)

// Standard AAPCS64 Frame Teardown:
//   1. mov sp, x29                (Collapse local stack frame)
//   2. ldp x29, x30, [sp], #16    (Restore frame pointer and link register)
//   3. ret                        (Return to caller via x30)
fn arm64_emit_epilogue ctx
    arm64_emit(ctx, 2432697279) // mov sp, x29               (0x910003BF)
    arm64_emit(ctx, 2831244285) // ldp x29, x30, [sp], #16   (0xA8C17BFD)
    arm64_emit(ctx, 3596551104) // ret                       (0xD65F03C0)

fn arm64_emit_bl_label ctx target_name
    pos = arm64_ctx_len(ctx)
    arm64_emit(ctx, 0)
    arm64_reloc_add(ctx, pos, target_name, ARM64_RELOC_BL, 0)

fn arm64_emit_b_cond_label ctx cond target_name
    pos = arm64_ctx_len(ctx)
    arm64_emit(ctx, 0)
    arm64_reloc_add(ctx, pos, target_name, ARM64_RELOC_B_COND, cond)

// ── Context Scope & Loop Primitives ──────────────────────────────────────────
fn arm64_make_anon_label ctx prefix
    id_ref = get(ctx, 9)
    id = get(id_ref, 0)
    list_set(id_ref, 0, id + 1)
    return "__arm64_" + prefix + "_" + str(id)

fn arm64_scope_get ctx name
    names = get(ctx, 10)
    offs  = get(ctx, 11)
    i = len(names) - 1
    while i >= 0
        if get(names, i) == name
            return get(offs, i)
        i = i - 1
    return 0

fn arm64_scope_add ctx name
    off = arm64_scope_get(ctx, name)
    if off > 0
        return off
    stk_ref = get(ctx, 12)
    cur = get(stk_ref, 0) + 8
    list_set(stk_ref, 0, cur)
    push(get(ctx, 10), name)
    push(get(ctx, 11), cur)
    return cur

fn arm64_loop_push ctx start_lbl end_lbl
    push(get(ctx, 13), start_lbl)
    push(get(ctx, 14), end_lbl)

fn arm64_loop_pop ctx
    pop(get(ctx, 13))
    pop(get(ctx, 14))

// ==============================================================================
// 🏛️ PART III: In-Memory Pure Lipi Tokenizer & Parser for ARM64 Emitter
// ==============================================================================
ARM64_TOK_INT    = 1
ARM64_TOK_STR    = 2
ARM64_TOK_IDENT  = 3
ARM64_TOK_OP     = 4
ARM64_TOK_LPAREN = 5
ARM64_TOK_RPAREN = 6
ARM64_TOK_COMMA  = 7
ARM64_TOK_NL     = 8
ARM64_TOK_INDENT = 9
ARM64_TOK_DEDENT = 10
ARM64_TOK_EOF    = 11

fn arm64_tok_new tt txt int_val
    t = list()
    push(t, tt)
    push(t, txt)
    push(t, int_val)
    return t

fn arm64_tok_t t = get(t, 0)
fn arm64_tok_s t = get(t, 1)
fn arm64_tok_i t = get(t, 2)

fn arm64_tokenize src
    tokens = list()
    p = 0
    slen = len(src)
    indent_stk = list(0)

    while p < slen
        c = char_at(src, p)
        code = ord(c)

        if code == 13 // \r
            p = p + 1
            continue

        // Comments //
        if c == "/" and p + 1 < slen and char_at(src, p + 1) == "/"
            while p < slen and char_at(src, p) != "\n"
                p = p + 1
            continue

        // Comments #
        if c == "#"
            while p < slen and char_at(src, p) != "\n"
                p = p + 1
            continue

        // Comments /* */
        if c == "/" and p + 1 < slen and char_at(src, p + 1) == "*"
            p = p + 2
            while p < slen
                if char_at(src, p) == "*" and p + 1 < slen and char_at(src, p + 1) == "/"
                    p = p + 2
                    break
                p = p + 1
            continue

        // Newline & Indentation
        if c == "\n"
            p = p + 1
            if len(tokens) > 0 and arm64_tok_t(get(tokens, len(tokens) - 1)) != ARM64_TOK_NL
                push(tokens, arm64_tok_new(ARM64_TOK_NL, "\n", 0))

            spaces = 0
            while p < slen
                sc = char_at(src, p)
                if sc == " "
                    spaces = spaces + 1
                    p = p + 1
                elif sc == "\t"
                    spaces = spaces + 4
                    p = p + 1
                else
                    break

            if p < slen
                next_c = char_at(src, p)
                if next_c == "\n" or next_c == "#" or (next_c == "/" and p + 1 < slen and char_at(src, p + 1) == "/")
                    continue

            cur_indent = get(indent_stk, len(indent_stk) - 1)
            if spaces > cur_indent
                push(indent_stk, spaces)
                push(tokens, arm64_tok_new(ARM64_TOK_INDENT, "", spaces))
            elif spaces < cur_indent
                while len(indent_stk) > 1 and get(indent_stk, len(indent_stk) - 1) > spaces
                    pop(indent_stk)
                    push(tokens, arm64_tok_new(ARM64_TOK_DEDENT, "", spaces))
            continue

        if c == " " or c == "\t"
            p = p + 1
            continue

        // Strings
        if c == "\"" or c == "'"
            quote = c
            p = p + 1
            str_acc = ""
            while p < slen and char_at(src, p) != quote
                sc = char_at(src, p)
                if sc == "\\" and p + 1 < slen
                    p = p + 1
                    esc = char_at(src, p)
                    if esc == "n"
                        str_acc = str_acc + "\n"
                    elif esc == "t"
                        str_acc = str_acc + "\t"
                    else
                        str_acc = str_acc + esc
                    p = p + 1
                else
                    str_acc = str_acc + sc
                    p = p + 1
            if p < slen and char_at(src, p) == quote
                p = p + 1
            push(tokens, arm64_tok_new(ARM64_TOK_STR, str_acc, 0))
            continue

        // Bengali digits (০-৯: ord 2534..2543)
        if code >= 2534 and code <= 2543
            val = 0
            while p < slen
                dc = char_at(src, p)
                dcode = ord(dc)
                if dcode >= 2534 and dcode <= 2543
                    val = (val * 10) + (dcode - 2534)
                    p = p + 1
                else
                    break
            push(tokens, arm64_tok_new(ARM64_TOK_INT, str(val), val))
            continue

        // ASCII digits
        if code >= 48 and code <= 57
            val = 0
            while p < slen
                dc = char_at(src, p)
                dcode = ord(dc)
                if dcode >= 48 and dcode <= 57
                    val = (val * 10) + (dcode - 48)
                    p = p + 1
                else
                    break
            push(tokens, arm64_tok_new(ARM64_TOK_INT, str(val), val))
            continue

        if c == "("
            push(tokens, arm64_tok_new(ARM64_TOK_LPAREN, "(", 0))
            p = p + 1
            continue
        if c == ")"
            push(tokens, arm64_tok_new(ARM64_TOK_RPAREN, ")", 0))
            p = p + 1
            continue
        if c == ","
            push(tokens, arm64_tok_new(ARM64_TOK_COMMA, ",", 0))
            p = p + 1
            continue

        // 2-char operators
        if p + 1 < slen
            two = c + char_at(src, p + 1)
            if two == "==" or two == "!=" or two == "<=" or two == ">=" or two == "+=" or two == "-=" or two == "*=" or two == "/=" or two == "&&" or two == "||" or two == ".."
                push(tokens, arm64_tok_new(ARM64_TOK_OP, two, 0))
                p = p + 2
                continue

        // 1-char operators
        if c == "+" or c == "-" or c == "*" or c == "/" or c == "%" or c == "=" or c == "<" or c == ">" or c == "!" or c == "." or c == ":"
            push(tokens, arm64_tok_new(ARM64_TOK_OP, c, 0))
            p = p + 1
            continue

        // Identifiers and Keywords
        is_ident_char = 0
        if (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or c == "_" or code > 127
            is_ident_char = 1

        if is_ident_char == 1
            id_acc = ""
            while p < slen
                ic = char_at(src, p)
                icode = ord(ic)
                if (icode >= 65 and icode <= 90) or (icode >= 97 and icode <= 122) or (icode >= 48 and icode <= 57) or ic == "_" or icode > 127
                    id_acc = id_acc + ic
                    p = p + 1
                else
                    break
            push(tokens, arm64_tok_new(ARM64_TOK_IDENT, id_acc, 0))
            continue

        p = p + 1

    while len(indent_stk) > 1
        pop(indent_stk)
        push(tokens, arm64_tok_new(ARM64_TOK_DEDENT, "", 0))

    push(tokens, arm64_tok_new(ARM64_TOK_EOF, "", 0))
    return tokens

// ── Parser State Primitives ──────────────────────────────────────────────────
fn arm64_ps_new tokens
    s = list()
    push(s, tokens)
    push(s, list(0))
    return s

fn arm64_ps_pos s = get(get(s, 1), 0)

fn arm64_ps_cur s
    tokens = get(s, 0)
    idx = get(get(s, 1), 0)
    if idx < len(tokens) return get(tokens, idx)
    return arm64_tok_new(ARM64_TOK_EOF, "", 0)

fn arm64_ps_cur_type s
    t = arm64_ps_cur(s)
    return arm64_tok_t(t)

fn arm64_ps_cur_text s
    t = arm64_ps_cur(s)
    return arm64_tok_s(t)

fn arm64_ps_cur_int s
    t = arm64_ps_cur(s)
    return arm64_tok_i(t)

fn arm64_ps_peek_tok s offset
    tokens = get(s, 0)
    idx = get(get(s, 1), 0) + offset
    if idx < len(tokens) return get(tokens, idx)
    return arm64_tok_new(ARM64_TOK_EOF, "", 0)

fn arm64_ps_adv s
    tokens = get(s, 0)
    idx_ref = get(s, 1)
    cur = get(idx_ref, 0)
    if cur < len(tokens) - 1
        list_set(idx_ref, 0, cur + 1)

fn arm64_ps_skip_nl s
    while arm64_ps_cur_type(s) == ARM64_TOK_NL
        arm64_ps_adv(s)

fn arm64_is_arg_start ps
    tt = arm64_ps_cur_type(ps)
    if tt == ARM64_TOK_INT or tt == ARM64_TOK_STR return 1
    if tt == ARM64_TOK_IDENT
        txt = arm64_ps_cur_text(ps)
        if txt == "if" or txt == "যদি" or txt == "while" or txt == "যতক্ষণ" return 0
        if txt == "for" or txt == "প্রতিটি" or txt == "return" or txt == "ফেরত" return 0
        if txt == "say" or txt == "বলো" or txt == "show" or txt == "দেখাও" or txt == "print" or txt == "println" return 0
        if txt == "fn" or txt == "কাজ" or txt == "struct" or txt == "গঠন" or txt == "repeat" or txt == "বার" return 0
        if txt == "else" or txt == "নাহলে" or txt == "elif" or txt == "নাহলে_যদি" return 0
        if txt == "and" or txt == "এবং" or txt == "or" or txt == "অথবা" or txt == "not" or txt == "না" return 0
        if txt == "let" or txt == "চলক" or txt == "ধরি" return 0
        return 1
    if tt == ARM64_TOK_OP and arm64_ps_cur_text(ps) == "(" return 1
    return 0

// ==============================================================================
// 🏛️ PART IV: Baremetal Linux AArch64 Runtime Syscall Stubs (0% Libc)
// ==============================================================================
fn arm64_emit_runtime_stubs ctx
    // ──────────────────────────────────────────────────────────────────────────
    // 1. _lipi_print_str: Print null-terminated string at X0
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "_lipi_print_str")
    arm64_emit(ctx, 2847898621) // stp x29, x30, [sp, #-16]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit_mov_reg(ctx, ARM64_REG_X1, ARM64_REG_X0) // X1 = str ptr
    arm64_emit_movz(ctx, ARM64_REG_X2, 0, 0)            // X2 = len = 0
    lbl_ps_loop = arm64_make_anon_label(ctx, "ps_loop")
    lbl_ps_done = arm64_make_anon_label(ctx, "ps_done")
    arm64_label_define(ctx, lbl_ps_loop)
    arm64_emit(ctx, 945973283) // ldrb w3, [x1, x2] (0x38626823)
    arm64_emit_cbz_label(ctx, 3, lbl_ps_done)
    arm64_emit(ctx, 2432697410) // add x2, x2, #1 (0x91000442)
    arm64_emit_b_label(ctx, lbl_ps_loop)
    arm64_label_define(ctx, lbl_ps_done)
    arm64_emit_movz(ctx, ARM64_REG_X0, 1, 0)               // stdout fd = 1
    arm64_emit_movz(ctx, ARM64_REG_X8, ARM64_SYS_WRITE, 0) // sys_write = 64
    arm64_emit_svc(ctx, 0)                                 // SVC #0
    arm64_emit(ctx, 2831244285) // ldp x29, x30, [sp], #16
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 2. _lipi_print_nl: Print newline '\n' (ASCII 10)
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "_lipi_print_nl")
    arm64_emit(ctx, 2847898621) // stp x29, x30, [sp, #-16]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 3508536319) // sub sp, sp, #16
    arm64_emit(ctx, 1375732032) // movz w0, #10 (0x52000140)
    arm64_emit(ctx, 956301312)  // strb w0, [sp] (0x39000000)
    arm64_emit_movz(ctx, ARM64_REG_X0, 1, 0)               // stdout = 1
    arm64_emit(ctx, 2432697569) // mov x1, sp (0x910003E1)
    arm64_emit_movz(ctx, ARM64_REG_X2, 1, 0)               // len = 1
    arm64_emit_movz(ctx, ARM64_REG_X8, ARM64_SYS_WRITE, 0) // sys_write = 64
    arm64_emit_svc(ctx, 0)
    arm64_emit(ctx, 2434794495) // add sp, sp, #16 (0x910043FF)
    arm64_emit(ctx, 2831244285) // ldp x29, x30, [sp], #16
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 3. _lipi_print_int: Print 64-bit integer at X0 in ASCII decimal
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "_lipi_print_int")
    arm64_emit(ctx, 2847898237) // stp x29, x30, [sp, #-32]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 2432697825) // add x1, sp, #31
    arm64_emit_movz(ctx, ARM64_REG_X2, 0, 0)            // digit count = 0
    arm64_emit_mov_reg(ctx, ARM64_REG_X3, ARM64_REG_X0) // X3 = number

    lbl_pi_non_zero = arm64_make_anon_label(ctx, "pi_nz")
    lbl_pi_div_loop = arm64_make_anon_label(ctx, "pi_div")
    lbl_pi_div_done = arm64_make_anon_label(ctx, "pi_done")
    lbl_pi_write    = arm64_make_anon_label(ctx, "pi_wr")
    lbl_pi_pos      = arm64_make_anon_label(ctx, "pi_pos")

    arm64_emit_cbnz_label(ctx, 3, lbl_pi_non_zero)
    // Handle 0
    arm64_emit(ctx, 3508536353) // sub x1, x1, #1
    arm64_emit(ctx, 1375733828) // movz w4, #48 ('0')
    arm64_emit(ctx, 956301348)  // strb w4, [x1]
    arm64_emit_movz(ctx, ARM64_REG_X2, 1, 0)
    arm64_emit_b_label(ctx, lbl_pi_write)

    arm64_label_define(ctx, lbl_pi_non_zero)
    arm64_emit_movz(ctx, ARM64_REG_X5, 0, 0) // is_neg = 0
    arm64_emit(ctx, 4043309119) // cmp x3, #0
    arm64_emit_b_cond_label(ctx, ARM64_COND_GE, lbl_pi_pos)
    arm64_emit_movz(ctx, ARM64_REG_X5, 1, 0) // is_neg = 1
    arm64_emit(ctx, 3406037027) // sub x3, xzr, x3 (neg x3)

    arm64_label_define(ctx, lbl_pi_pos)
    arm64_label_define(ctx, lbl_pi_div_loop)
    arm64_emit_cbz_label(ctx, 3, lbl_pi_div_done)
    arm64_emit_movz(ctx, ARM64_REG_X6, 10, 0) // divisor = 10
    arm64_emit(ctx, 2596735079) // udiv x7, x3, x6
    arm64_emit(ctx, 2600963240) // msub x8, x7, x6, x3
    arm64_emit(ctx, 2432709640) // add x8, x8, #48
    arm64_emit(ctx, 3508536353) // sub x1, x1, #1
    arm64_emit(ctx, 956301352)  // strb w8, [x1]
    arm64_emit(ctx, 2432697410) // add x2, x2, #1
    arm64_emit_mov_reg(ctx, ARM64_REG_X3, ARM64_REG_X7)
    arm64_emit_b_label(ctx, lbl_pi_div_loop)

    arm64_label_define(ctx, lbl_pi_div_done)
    arm64_emit_cbz_label(ctx, 5, lbl_pi_write)
    arm64_emit(ctx, 3508536353) // sub x1, x1, #1
    arm64_emit(ctx, 1375733732) // movz w4, #45 ('-')
    arm64_emit(ctx, 956301348)  // strb w4, [x1]
    arm64_emit(ctx, 2432697410) // add x2, x2, #1

    arm64_label_define(ctx, lbl_pi_write)
    arm64_emit_movz(ctx, ARM64_REG_X0, 1, 0)               // stdout
    arm64_emit_movz(ctx, ARM64_REG_X8, ARM64_SYS_WRITE, 0) // sys_write
    arm64_emit_svc(ctx, 0)
    arm64_emit(ctx, 2831244477) // ldp x29, x30, [sp], #32
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 4. _lipi_print_dynamic: Dispatches between string pointer and integer
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "_lipi_print_dynamic")
    arm64_emit(ctx, 2847898621) // stp x29, x30, [sp, #-16]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 3533701153) // movz x1, #64, lsl #16 (0x400000 = 4194304)
    arm64_emit(ctx, 3942711327) // cmp x0, x1
    lbl_pd_int = arm64_make_anon_label(ctx, "pd_int")
    arm64_emit_b_cond_label(ctx, ARM64_COND_LT, lbl_pd_int)
    arm64_emit_bl_label(ctx, "_lipi_print_str")
    arm64_emit(ctx, 2831244285) // ldp x29, x30, [sp], #16
    arm64_emit_ret(ctx)
    arm64_label_define(ctx, lbl_pd_int)
    arm64_emit_bl_label(ctx, "_lipi_print_int")
    arm64_emit(ctx, 2831244285) // ldp x29, x30, [sp], #16
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 5. lipi_fn_syscall / lipi_fn_sys_call / lipi_fn_সিসকল: Linux AArch64 Syscall ABI
    // WHY: Calling convention for Linux AArch64 syscalls:
    //      - X8 = syscall ID (passed in X0 from Lipi caller)
    //      - X0 = arg 1 (passed in X1)
    //      - X1 = arg 2 (passed in X2)
    //      - X2 = arg 3 (passed in X3)
    //      - X3 = arg 4 (passed in X4)
    //      - X4 = arg 5 (passed in X5)
    //      - X5 = arg 6 (passed in X6)
    //      - Executed via SVC #0 (0xD4000001)
    //      - Returns kernel result/status directly in X0
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_syscall")
    arm64_label_define(ctx, "lipi_fn_sys_call")
    arm64_label_define(ctx, "lipi_fn_সিসকল")
    arm64_emit_mov_reg(ctx, ARM64_REG_X8, ARM64_REG_X0) // X8 = syscall_id
    arm64_emit_mov_reg(ctx, ARM64_REG_X0, ARM64_REG_X1) // X0 = arg 1
    arm64_emit_mov_reg(ctx, ARM64_REG_X1, ARM64_REG_X2) // X1 = arg 2
    arm64_emit_mov_reg(ctx, ARM64_REG_X2, ARM64_REG_X3) // X2 = arg 3
    arm64_emit_mov_reg(ctx, ARM64_REG_X3, ARM64_REG_X4) // X3 = arg 4
    arm64_emit_mov_reg(ctx, ARM64_REG_X4, ARM64_REG_X5) // X4 = arg 5
    arm64_emit_mov_reg(ctx, ARM64_REG_X5, ARM64_REG_X6) // X5 = arg 6
    arm64_emit_svc(ctx, 0)                              // SVC #0
    arm64_emit_ret(ctx)                                 // Return (result in X0)

    // ──────────────────────────────────────────────────────────────────────────
    // 6. lipi_fn_exit: Terminate process with exit code in X0
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_exit")
    arm64_emit_movz(ctx, ARM64_REG_X8, ARM64_SYS_EXIT, 0) // sys_exit = 93
    arm64_emit_svc(ctx, 0)

    // ──────────────────────────────────────────────────────────────────────────
    // 7. lipi_fn_len / lipi_fn_length / lipi_fn_দৈর্ঘ্য: String or list length
    // WHY: Inspects pointer tag: if STR0 header at [x0-8], returns string length;
    //      if list struct, returns count at [x0]; else returns 0.
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_len")
    arm64_label_define(ctx, "lipi_fn_length")
    arm64_label_define(ctx, "lipi_fn_দৈর্ঘ্য")
    lbl_len_zero = arm64_make_anon_label(ctx, "len_zero")
    lbl_len_list = arm64_make_anon_label(ctx, "len_list")

    arm64_emit_cbz_label(ctx, ARM64_REG_X0, lbl_len_zero)
    arm64_emit(ctx, 3533703169) // movz x1, #64, lsl #16 (0x400000)
    arm64_emit(ctx, arm64_cmp(0, 1))
    arm64_emit_b_cond_label(ctx, ARM64_COND_LT, lbl_len_zero)

    // Check STR0 tag at [x0 - 8]
    arm64_emit(ctx, 4167008258) // ldur x2, [x0, #-8]
    arm64_emit(ctx, 3546348611) // lsr x3, x2, #32
    arm64_emit(ctx, 3532286596) // movz x4, #21332 (0x5354)
    arm64_emit(ctx, 4071254532) // movk x4, #21328, lsl #16 (0x53545230)
    arm64_emit(ctx, arm64_cmp(3, 4))
    arm64_emit_b_cond_label(ctx, ARM64_COND_NE, lbl_len_list)
    arm64_emit(ctx, 704775136)  // mov w0, w2 (lower 32-bit length)
    arm64_emit_ret(ctx)

    arm64_label_define(ctx, lbl_len_list)
    // For lists, count is at [x0 + 0]
    arm64_emit(ctx, 4181721088) // ldr x0, [x0]
    arm64_emit_ret(ctx)

    arm64_label_define(ctx, lbl_len_zero)
    arm64_emit_movz(ctx, ARM64_REG_X0, 0, 0)
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 8. _lipi_init_heap: 1GB anonymous virtual memory via sys_mmap (syscall 222)
    // WHY: Maps zero-overhead virtual address space for dynamic heap allocations.
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "_lipi_init_heap")
    arm64_emit(ctx, 2847898621) // stp x29, x30, [sp, #-16]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit_movz(ctx, ARM64_REG_X0, 0, 0)
    arm64_emit_movz(ctx, ARM64_REG_X1, 16384, 16) // 1GB (0x40000000)
    arm64_emit_movz(ctx, ARM64_REG_X2, 3, 0)     // PROT_READ | PROT_WRITE
    arm64_emit_movz(ctx, ARM64_REG_X3, 34, 0)    // MAP_PRIVATE | MAP_ANONYMOUS
    arm64_emit(ctx, 2856256484)                  // mvn x4, xzr (-1)
    arm64_emit_movz(ctx, ARM64_REG_X5, 0, 0)
    arm64_emit_movz(ctx, ARM64_REG_X8, 222, 0)   // sys_mmap = 222
    arm64_emit_svc(ctx, 0)
    arm64_emit_adr_label(ctx, ARM64_REG_X1, "_lipi_heap_base")
    arm64_emit(ctx, 4177526816) // str x0, [x1]
    arm64_emit_adr_label(ctx, ARM64_REG_X2, "_lipi_heap_ptr")
    arm64_emit(ctx, 4177526848) // str x0, [x2]
    arm64_emit(ctx, 2831244285) // ldp x29, x30, [sp], #16
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 9. _lipi_alloc: Bump pointer heap allocator with 16-byte alignment
    // WHY: Returns payload pointer with 8 bytes reserved before it for STR0 tag/length.
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "_lipi_alloc")
    arm64_emit(ctx, 2847898621) // stp x29, x30, [sp, #-16]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 2432711680) // add x0, x0, #15
    arm64_emit(ctx, 2457660416) // and x0, x0, #-16
    arm64_emit(ctx, 2432712704) // add x0, x0, #16
    arm64_emit_adr_label(ctx, ARM64_REG_X1, "_lipi_heap_ptr")
    arm64_emit(ctx, 4181721122) // ldr x2, [x1]

    lbl_alc_init = arm64_make_anon_label(ctx, "alc_init")
    lbl_alc_cont = arm64_make_anon_label(ctx, "alc_cont")
    arm64_emit_cbz_label(ctx, ARM64_REG_X2, lbl_alc_init)
    arm64_emit_b_label(ctx, lbl_alc_cont)
    arm64_label_define(ctx, lbl_alc_init)
    arm64_push_reg(ctx, ARM64_REG_X0)
    arm64_emit_bl_label(ctx, "_lipi_init_heap")
    arm64_pop_reg(ctx, ARM64_REG_X0)
    arm64_emit_adr_label(ctx, ARM64_REG_X1, "_lipi_heap_ptr")
    arm64_emit(ctx, 4181721122) // ldr x2, [x1]
    arm64_label_define(ctx, lbl_alc_cont)

    arm64_emit(ctx, 2332033091) // add x3, x2, x0
    arm64_emit(ctx, 4177526819) // str x3, [x1]
    arm64_emit(ctx, 2432704576) // add x0, x2, #8
    arm64_emit(ctx, 2831244285) // ldp x29, x30, [sp], #16
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 10. lipi_fn_list / lipi_fn_তালিকা: Dynamic list object allocation
    // WHY: Allocates 24-byte list descriptor struct [count, cap, data_ptr]
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_list")
    arm64_label_define(ctx, "lipi_fn_তালিকা")
    arm64_emit(ctx, 2847833085) // stp x29, x30, [sp, #-32]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 4177529843) // str x19, [sp, #16]
    arm64_emit_movz(ctx, ARM64_REG_X0, 24, 0) // 24 bytes
    arm64_emit_bl_label(ctx, "_lipi_alloc")
    arm64_emit(ctx, 2852127731) // mov x19, x0
    arm64_emit_movz(ctx, ARM64_REG_X0, 128, 0) // 16 * 8 = 128 bytes initial cap
    arm64_emit_bl_label(ctx, "_lipi_alloc")
    arm64_emit(ctx, 4177527423) // str xzr, [x19] (count = 0)
    arm64_emit_movz(ctx, ARM64_REG_X1, 16, 0)
    arm64_emit(ctx, 4177528417) // str x1, [x19, #8] (cap = 16)
    arm64_emit(ctx, 4177529440) // str x0, [x19, #16] (data_ptr = buffer)
    arm64_emit(ctx, 2853372896) // mov x0, x19
    arm64_emit(ctx, 4181724147) // ldr x19, [sp, #16]
    arm64_emit(ctx, 2831318013) // ldp x29, x30, [sp], #32
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 11. lipi_fn_push / lipi_fn_যুক্ত: Append item to dynamic list
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_push")
    arm64_label_define(ctx, "lipi_fn_যুক্ত")
    arm64_emit(ctx, 2847767549) // stp x29, x30, [sp, #-48]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 2837332979) // stp x19, x20, [sp, #16]
    arm64_emit(ctx, 2837464565) // stp x21, x22, [sp, #32]
    arm64_emit(ctx, 2852127731) // mov x19, x0 (list)
    arm64_emit(ctx, 2852193268) // mov x20, x1 (val)
    arm64_emit(ctx, 4181721717) // ldr x21, [x19] (count)
    arm64_emit(ctx, 4181722742) // ldr x22, [x19, #8] (cap)

    lbl_pu_store = arm64_make_anon_label(ctx, "pu_store")
    lbl_pu_capok = arm64_make_anon_label(ctx, "pu_capok")
    lbl_pu_cploop = arm64_make_anon_label(ctx, "pu_cploop")
    lbl_pu_cpdone = arm64_make_anon_label(ctx, "pu_cpdone")

    arm64_emit(ctx, arm64_cmp(21, 22)) // cmp x21, x22
    arm64_emit_b_cond_label(ctx, ARM64_COND_LT, lbl_pu_store)

    // Double cap: new_cap = cap * 2
    arm64_emit(ctx, 3548379840) // lsl x0, x22, #1
    arm64_emit(ctx, 4043325471) // cmp x0, #16
    arm64_emit_b_cond_label(ctx, ARM64_COND_GE, lbl_pu_capok)
    arm64_emit_movz(ctx, ARM64_REG_X0, 16, 0)
    arm64_label_define(ctx, lbl_pu_capok)
    arm64_emit(ctx, 2852127734) // mov x22, x0
    arm64_emit(ctx, 4177528438) // str x22, [x19, #8]
    arm64_emit(ctx, 3548246720) // lsl x0, x22, #3 (new_cap * 8 bytes)
    arm64_emit_bl_label(ctx, "_lipi_alloc")
    // X0 = new data_ptr
    arm64_emit(ctx, 4181723746) // ldr x2, [x19, #16] (old buffer)
    arm64_emit_movz(ctx, ARM64_REG_X3, 0, 0) // i = 0

    arm64_label_define(ctx, lbl_pu_cploop)
    arm64_emit(ctx, arm64_cmp(3, 21)) // cmp x3, x21
    arm64_emit_b_cond_label(ctx, ARM64_COND_GE, lbl_pu_cpdone)
    arm64_emit(ctx, 4167268420) // ldr x4, [x2, x3, lsl #3]
    arm64_emit(ctx, 4163074052) // str x4, [x0, x3, lsl #3]
    arm64_emit(ctx, 2432697443) // add x3, x3, #1
    arm64_emit_b_label(ctx, lbl_pu_cploop)
    arm64_label_define(ctx, lbl_pu_cpdone)
    arm64_emit(ctx, 4177529440) // str x0, [x19, #16]

    arm64_label_define(ctx, lbl_pu_store)
    arm64_emit(ctx, 4181723746) // ldr x2, [x19, #16] (data_ptr)
    arm64_emit(ctx, 4164253780) // str x20, [x2, x21, lsl #3]
    arm64_emit(ctx, 2432698037) // add x21, x21, #1
    arm64_emit(ctx, 4177527413) // str x21, [x19] (count = count + 1)
    arm64_emit(ctx, 2853372896) // mov x0, x19 (return list)
    arm64_emit(ctx, 2833270421) // ldp x21, x22, [sp, #32]
    arm64_emit(ctx, 2833138835) // ldp x19, x20, [sp, #16]
    arm64_emit(ctx, 2831383549) // ldp x29, x30, [sp], #48
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 12. lipi_fn_get / lipi_fn_পাও: Retrieve element at index
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_get")
    arm64_label_define(ctx, "lipi_fn_পাও")
    arm64_emit(ctx, 4181723138) // ldr x2, [x0, #16]
    arm64_emit(ctx, 4167137344) // ldr x0, [x2, x1, lsl #3]
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 13. lipi_fn_list_set: Store element at index
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_list_set")
    arm64_emit(ctx, 4181723139) // ldr x3, [x0, #16]
    arm64_emit(ctx, 4162943074) // str x2, [x3, x1, lsl #3]
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 14. lipi_fn_pop: Pop and return last element
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_pop")
    arm64_emit(ctx, 4181721089) // ldr x1, [x0]
    lbl_pop_empty = arm64_make_anon_label(ctx, "pop_empty")
    arm64_emit_cbz_label(ctx, 1, lbl_pop_empty)
    arm64_emit(ctx, 3506439201) // sub x1, x1, #1
    arm64_emit(ctx, 4177526785) // str x1, [x0]
    arm64_emit(ctx, 4181723138) // ldr x2, [x0, #16]
    arm64_emit(ctx, 4167137344) // ldr x0, [x2, x1, lsl #3]
    arm64_emit_ret(ctx)
    arm64_label_define(ctx, lbl_pop_empty)
    arm64_emit_movz(ctx, ARM64_REG_X0, 0, 0)
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 15. lipi_fn_ord: ASCII / UTF-8 code of first character
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_ord")
    lbl_ord_z = arm64_make_anon_label(ctx, "ord_zero")
    arm64_emit_cbz_label(ctx, ARM64_REG_X0, lbl_ord_z)
    arm64_emit(ctx, 960495616) // ldrb w0, [x0]
    arm64_emit_ret(ctx)
    arm64_label_define(ctx, lbl_ord_z)
    arm64_emit_movz(ctx, ARM64_REG_X0, 0, 0)
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 16. lipi_fn_chr: Construct 1-character string from integer code
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_chr")
    arm64_emit(ctx, 2847833085) // stp x29, x30, [sp, #-32]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 4177529843) // str x19, [sp, #16]
    arm64_emit(ctx, 2852127731) // mov x19, x0
    arm64_emit_movz(ctx, ARM64_REG_X0, 2, 0)
    arm64_emit_bl_label(ctx, "_lipi_alloc")
    arm64_emit(ctx, 3531603969) // movz x1, #1
    arm64_emit(ctx, 4078832641) // movk x1, #21332, lsl #32
    arm64_emit(ctx, 4095609857) // movk x1, #21328, lsl #48
    arm64_emit(ctx, 4162813953) // stur x1, [x0, #-8]
    arm64_emit(ctx, 956301331)  // strb w19, [x0]
    arm64_emit(ctx, 956302367)  // strb wzr, [x0, #1]
    arm64_emit(ctx, 4181724147) // ldr x19, [sp, #16]
    arm64_emit(ctx, 2831318013) // ldp x29, x30, [sp], #32
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 17. lipi_fn_char_at: Return 1-character string at index
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_char_at")
    arm64_emit(ctx, 2847833085) // stp x29, x30, [sp, #-32]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 4177529843) // str x19, [sp, #16]
    arm64_emit(ctx, 945907731)  // ldrb w19, [x0, x1]
    arm64_emit_movz(ctx, ARM64_REG_X0, 2, 0)
    arm64_emit_bl_label(ctx, "_lipi_alloc")
    arm64_emit(ctx, 3531603969) // movz x1, #1
    arm64_emit(ctx, 4078832641) // movk x1, #21332, lsl #32
    arm64_emit(ctx, 4095609857) // movk x1, #21328, lsl #48
    arm64_emit(ctx, 4162813953) // stur x1, [x0, #-8]
    arm64_emit(ctx, 956301331)  // strb w19, [x0]
    arm64_emit(ctx, 956302367)  // strb wzr, [x0, #1]
    arm64_emit(ctx, 4181724147) // ldr x19, [sp, #16]
    arm64_emit(ctx, 2831318013) // ldp x29, x30, [sp], #32
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 18. lipi_fn_str: Convert integer to heap-allocated ASCII string
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_str")
    arm64_emit(ctx, 2847767549) // stp x29, x30, [sp, #-48]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 2837332979) // stp x19, x20, [sp, #16]
    arm64_emit(ctx, 2837464565) // stp x21, x22, [sp, #32]
    arm64_emit(ctx, 2852127731) // mov x19, x0 (number)
    arm64_emit_movz(ctx, ARM64_REG_X0, 32, 0)
    arm64_emit_bl_label(ctx, "_lipi_alloc")
    arm64_emit(ctx, 2852127732) // mov x20, x0 (dest buffer)

    lbl_str_nz = arm64_make_anon_label(ctx, "str_nz")
    lbl_str_done = arm64_make_anon_label(ctx, "str_done")
    lbl_str_pos = arm64_make_anon_label(ctx, "str_pos")
    lbl_str_dloop = arm64_make_anon_label(ctx, "str_dloop")
    lbl_str_ddone = arm64_make_anon_label(ctx, "str_ddone")
    lbl_str_cpsetup = arm64_make_anon_label(ctx, "str_cpsetup")
    lbl_str_cploop = arm64_make_anon_label(ctx, "str_cploop")
    lbl_str_cpdone = arm64_make_anon_label(ctx, "str_cpdone")

    arm64_emit_cbnz_label(ctx, 19, lbl_str_nz)
    arm64_emit_movz(ctx, ARM64_REG_X1, 48, 0) // '0'
    arm64_emit(ctx, 956301953)  // strb w1, [x20]
    arm64_emit(ctx, 956303007)  // strb wzr, [x20, #1]
    arm64_emit(ctx, 3531603970) // movz x2, #1
    arm64_emit(ctx, 4078832642) // movk x2, #21332, lsl #32
    arm64_emit(ctx, 4095609858) // movk x2, #21328, lsl #48
    arm64_emit(ctx, 4162814594) // stur x2, [x20, #-8]
    arm64_emit(ctx, 2853438432) // mov x0, x20
    arm64_emit_b_label(ctx, lbl_str_done)

    arm64_label_define(ctx, lbl_str_nz)
    arm64_emit_movz(ctx, 21, 0, 0) // is_neg = 0
    arm64_emit(ctx, arm64_cmp_imm(19, 0))
    arm64_emit_b_cond_label(ctx, ARM64_COND_GE, lbl_str_pos)
    arm64_emit_movz(ctx, 21, 1, 0) // is_neg = 1
    arm64_emit(ctx, 3407021043)   // neg x19, x19

    arm64_label_define(ctx, lbl_str_pos)
    arm64_emit(ctx, 2432745442) // add x2, sp, #47
    arm64_emit(ctx, 956301407)  // strb wzr, [x2]
    arm64_emit_movz(ctx, 3, 0, 0) // digit count = 0

    arm64_label_define(ctx, lbl_str_dloop)
    arm64_emit_cbz_label(ctx, 19, lbl_str_ddone)
    arm64_emit_movz(ctx, 4, 10, 0)
    arm64_emit(ctx, 2596538981) // udiv x5, x19, x4
    arm64_emit(ctx, 2600783014) // msub x6, x5, x4, x19
    arm64_emit(ctx, 285262022)  // add w6, w6, #48
    arm64_emit(ctx, 3506439234) // sub x2, x2, #1
    arm64_emit(ctx, 956301382)  // strb w6, [x2]
    arm64_emit(ctx, 2432697443) // add x3, x3, #1
    arm64_emit(ctx, 2852127731) // mov x19, x5
    arm64_emit_b_label(ctx, lbl_str_dloop)

    arm64_label_define(ctx, lbl_str_ddone)
    arm64_emit_cbz_label(ctx, 21, lbl_str_cpsetup)
    arm64_emit(ctx, 3506439234) // sub x2, x2, #1
    arm64_emit_movz(ctx, 6, 45, 0) // '-'
    arm64_emit(ctx, 956301382)  // strb w6, [x2]
    arm64_emit(ctx, 2432697443) // add x3, x3, #1

    arm64_label_define(ctx, lbl_str_cpsetup)
    arm64_emit_movz(ctx, 4, 0, 0) // i = 0

    arm64_label_define(ctx, lbl_str_cploop)
    arm64_emit(ctx, arm64_cmp(4, 3))
    arm64_emit_b_cond_label(ctx, ARM64_COND_GE, lbl_str_cpdone)
    arm64_emit(ctx, 946104389)  // ldrb w5, [x2, x4]
    arm64_emit(ctx, 941910661)  // strb w5, [x20, x4]
    arm64_emit(ctx, 2432697476) // add x4, x4, #1
    arm64_emit_b_label(ctx, lbl_str_cploop)

    arm64_label_define(ctx, lbl_str_cpdone)
    arm64_emit(ctx, 941845151)  // strb wzr, [x20, x3]
    arm64_emit(ctx, 2852324322) // mov x2, x3
    arm64_emit(ctx, 4078832642) // movk x2, #21332, lsl #32
    arm64_emit(ctx, 4095609858) // movk x2, #21328, lsl #48
    arm64_emit(ctx, 4162814594) // stur x2, [x20, #-8]
    arm64_emit(ctx, 2853438432) // mov x0, x20

    arm64_label_define(ctx, lbl_str_done)
    arm64_emit(ctx, 2833270421) // ldp x21, x22, [sp, #32]
    arm64_emit(ctx, 2833138835) // ldp x19, x20, [sp, #16]
    arm64_emit(ctx, 2831383549) // ldp x29, x30, [sp], #48
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 19. _lipi_str_concat: Concatenate two strings into new heap buffer
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "_lipi_str_concat")
    arm64_emit(ctx, 2847767549) // stp x29, x30, [sp, #-48]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 2837332979) // stp x19, x20, [sp, #16]
    arm64_emit(ctx, 2837464565) // stp x21, x22, [sp, #32]
    arm64_emit(ctx, 2852127731) // mov x19, x0 (str1)
    arm64_emit(ctx, 2852193268) // mov x20, x1 (str2)

    arm64_emit_bl_label(ctx, "lipi_fn_len")
    arm64_emit(ctx, 2852127733) // mov x21, x0 (len1)
    arm64_emit(ctx, 2853438432) // mov x0, x20
    arm64_emit_bl_label(ctx, "lipi_fn_len")
    arm64_emit(ctx, 2852127734) // mov x22, x0 (len2)

    // total_len = len1 + len2 + 1
    arm64_emit(ctx, 2333475488) // add x0, x21, x22
    arm64_emit(ctx, 2432697344) // add x0, x0, #1
    arm64_emit_bl_label(ctx, "_lipi_alloc")
    // X0 is new string buffer

    // Copy str1
    arm64_emit_movz(ctx, 1, 0, 0) // i = 0
    lbl_cat_c1 = arm64_make_anon_label(ctx, "cat_c1")
    lbl_cat_c2_setup = arm64_make_anon_label(ctx, "cat_c2_setup")
    lbl_cat_c2 = arm64_make_anon_label(ctx, "cat_c2")
    lbl_cat_done = arm64_make_anon_label(ctx, "cat_done")

    arm64_label_define(ctx, lbl_cat_c1)
    arm64_emit(ctx, arm64_cmp(1, 21))
    arm64_emit_b_cond_label(ctx, ARM64_COND_GE, lbl_cat_c2_setup)
    arm64_emit(ctx, 945908322)  // ldrb w2, [x19, x1]
    arm64_emit(ctx, 941713410)  // strb w2, [x0, x1]
    arm64_emit(ctx, 2432697377) // add x1, x1, #1
    arm64_emit_b_label(ctx, lbl_cat_c1)

    arm64_label_define(ctx, lbl_cat_c2_setup)
    arm64_emit_movz(ctx, 2, 0, 0) // j = 0
    arm64_label_define(ctx, lbl_cat_c2)
    arm64_emit(ctx, arm64_cmp(2, 22))
    arm64_emit_b_cond_label(ctx, ARM64_COND_GE, lbl_cat_done)
    arm64_emit(ctx, 945973891)  // ldrb w3, [x20, x2]
    arm64_emit(ctx, 2332164772) // add x4, x21, x2
    arm64_emit(ctx, 941910019)  // strb w3, [x0, x4]
    arm64_emit(ctx, 2432697410) // add x2, x2, #1
    arm64_emit_b_label(ctx, lbl_cat_c2)

    arm64_label_define(ctx, lbl_cat_done)
    arm64_emit(ctx, 2333475492) // add x4, x21, x22 (total_len)
    arm64_emit(ctx, 941910047)  // strb wzr, [x0, x4]
    arm64_emit(ctx, 2852389857) // mov x1, x4
    arm64_emit(ctx, 4078832641) // movk x1, #21332, lsl #32
    arm64_emit(ctx, 4095609857) // movk x1, #21328, lsl #48
    arm64_emit(ctx, 4162813953) // stur x1, [x0, #-8]

    arm64_emit(ctx, 2833270421) // ldp x21, x22, [sp, #32]
    arm64_emit(ctx, 2833138835) // ldp x19, x20, [sp, #16]
    arm64_emit(ctx, 2831383549) // ldp x29, x30, [sp], #48
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 20. _lipi_add_or_concat: Polymorphic '+' operator (String concat vs Integer add)
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "_lipi_add_or_concat")
    lbl_aoc_int = arm64_make_anon_label(ctx, "aoc_int")
    arm64_emit(ctx, 3533703170) // movz x2, #64, lsl #16 (0x400000)
    arm64_emit(ctx, arm64_cmp(ARM64_REG_X0, 2))
    arm64_emit_b_cond_label(ctx, ARM64_COND_LT, lbl_aoc_int)
    arm64_emit(ctx, arm64_cmp(ARM64_REG_X1, 2))
    arm64_emit_b_cond_label(ctx, ARM64_COND_LT, lbl_aoc_int)

    // Check STR0 tag on lhs: ldur x3, [x0, #-8]
    arm64_emit(ctx, 4167008259)
    arm64_emit(ctx, 3546348643) // lsr x3, x3, #32
    arm64_emit(ctx, 3532286596) // movz x4, #21332 (0x5354)
    arm64_emit(ctx, 4071254532) // movk x4, #21328, lsl #16 (0x53545230)
    arm64_emit(ctx, arm64_cmp(3, 4))
    arm64_emit_b_cond_label(ctx, ARM64_COND_NE, lbl_aoc_int)
    arm64_emit_b_label(ctx, "_lipi_str_concat")

    arm64_label_define(ctx, lbl_aoc_int)
    arm64_emit_add(ctx, ARM64_REG_X0, ARM64_REG_X0, ARM64_REG_X1)
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 21. lipi_fn_floor: Truncate integer/float to integer
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_floor")
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 22. lipi_fn_file_exists: Check file existence via sys_faccessat (48)
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_file_exists")
    arm64_emit(ctx, 2847898621) // stp x29, x30, [sp, #-16]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit_mov_reg(ctx, ARM64_REG_X1, ARM64_REG_X0) // path
    arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 0 - 100)    // AT_FDCWD = -100
    arm64_emit_movz(ctx, ARM64_REG_X2, 0, 0)            // F_OK = 0
    arm64_emit_movz(ctx, ARM64_REG_X3, 0, 0)            // flags = 0
    arm64_emit_movz(ctx, ARM64_REG_X8, 48, 0)           // sys_faccessat = 48
    arm64_emit_svc(ctx, 0)
    arm64_emit(ctx, arm64_cmp_imm(ARM64_REG_X0, 0))
    arm64_emit(ctx, arm64_cset(ARM64_REG_X0, ARM64_COND_EQ)) // 1 if exists, 0 otherwise
    arm64_emit(ctx, 2831244285) // ldp x29, x30, [sp], #16
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 23. lipi_fn_file_read: Read entire file into heap string via sys_openat/sys_read/sys_close
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_file_read")
    arm64_emit(ctx, 2847767549) // stp x29, x30, [sp, #-48]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 2837332979) // stp x19, x20, [sp, #16]
    arm64_emit(ctx, 2837464565) // stp x21, x22, [sp, #32]
    arm64_emit(ctx, 2852127731) // mov x19, x0 (path)

    // openat(AT_FDCWD, path, O_RDONLY, 0)
    arm64_emit_movz(ctx, ARM64_REG_X8, 56, 0)        // sys_openat = 56
    arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 0 - 100) // AT_FDCWD = -100
    arm64_emit(ctx, 2853372897)                      // mov x1, x19
    arm64_emit_movz(ctx, ARM64_REG_X2, 0, 0)         // O_RDONLY = 0
    arm64_emit_movz(ctx, ARM64_REG_X3, 0, 0)
    arm64_emit_svc(ctx, 0)
    arm64_emit(ctx, 2852193268)                      // mov x20, x0 (fd)

    lbl_fr_fail = arm64_make_anon_label(ctx, "fr_fail")
    lbl_fr_done = arm64_make_anon_label(ctx, "fr_done")
    arm64_emit(ctx, arm64_cmp_imm(20, 0))
    arm64_emit_b_cond_label(ctx, ARM64_COND_LT, lbl_fr_fail)

    // Alloc 1MB buffer (1048576)
    arm64_emit_movz(ctx, ARM64_REG_X0, 16, 16)       // 1048576 bytes (1MB)
    arm64_emit_bl_label(ctx, "_lipi_alloc")
    arm64_emit(ctx, 2852127733)                      // mov x21, x0 (buf)

    // read(fd, buf, 1048576)
    arm64_emit_movz(ctx, ARM64_REG_X8, 63, 0)        // sys_read = 63
    arm64_emit(ctx, 2853438432)                      // mov x0, x20
    arm64_emit(ctx, 2853503969)                      // mov x1, x21
    arm64_emit_movz(ctx, ARM64_REG_X2, 16, 16)       // 1048576
    arm64_emit_svc(ctx, 0)
    arm64_emit(ctx, 2852127734)                      // mov x22, x0 (bytes_read)

    // close(fd)
    arm64_emit_movz(ctx, ARM64_REG_X8, 57, 0)        // sys_close = 57
    arm64_emit(ctx, 2853438432)                      // mov x0, x20
    arm64_emit_svc(ctx, 0)

    arm64_emit(ctx, arm64_cmp_imm(22, 0))
    lbl_fr_clamp = arm64_make_anon_label(ctx, "fr_clamp")
    arm64_emit_b_cond_label(ctx, ARM64_COND_GE, lbl_fr_clamp)
    arm64_emit_movz(ctx, 22, 0, 0)
    arm64_label_define(ctx, lbl_fr_clamp)

    // Null terminate and STR0 tag
    arm64_emit(ctx, 941910751)  // strb wzr, [x21, x22]
    arm64_emit(ctx, 2852258786) // mov x2, x22
    arm64_emit(ctx, 4078832642) // movk x2, #21332, lsl #32
    arm64_emit(ctx, 4095609858) // movk x2, #21328, lsl #48
    arm64_emit(ctx, 4162814626) // stur x2, [x21, #-8]
    arm64_emit(ctx, 2853503968) // mov x0, x21
    arm64_emit_b_label(ctx, lbl_fr_done)

    arm64_label_define(ctx, lbl_fr_fail)
    arm64_emit_movz(ctx, ARM64_REG_X0, 1, 0)
    arm64_emit_bl_label(ctx, "_lipi_alloc")
    arm64_emit(ctx, 956301343)  // strb wzr, [x0]
    arm64_emit_movz(ctx, 2, 0, 0)
    arm64_emit(ctx, 4078832642) // movk x2, #21332, lsl #32
    arm64_emit(ctx, 4095609858) // movk x2, #21328, lsl #48
    arm64_emit(ctx, 4162813954) // stur x2, [x0, #-8]

    arm64_label_define(ctx, lbl_fr_done)
    arm64_emit(ctx, 2833270421) // ldp x21, x22, [sp, #32]
    arm64_emit(ctx, 2833138835) // ldp x19, x20, [sp, #16]
    arm64_emit(ctx, 2831383549) // ldp x29, x30, [sp], #48
    arm64_emit_ret(ctx)

    // ──────────────────────────────────────────────────────────────────────────
    // 24. lipi_fn_file_write_bytes: Write binary bytes list directly to disk
    // ──────────────────────────────────────────────────────────────────────────
    arm64_label_define(ctx, "lipi_fn_file_write_bytes")
    arm64_emit(ctx, 2847701981) // stp x29, x30, [sp, #-64]!
    arm64_emit(ctx, 2432697341) // mov x29, sp
    arm64_emit(ctx, 2837332979) // stp x19, x20, [sp, #16]
    arm64_emit(ctx, 2837464565) // stp x21, x22, [sp, #32]
    arm64_emit(ctx, 2837596151) // stp x23, x24, [sp, #48]
    arm64_emit(ctx, 2852127731) // mov x19, x0 (path)
    arm64_emit(ctx, 2852193268) // mov x20, x1 (bytes_list)
    arm64_emit(ctx, 4181721717) // ldr x21, [x20] (count)
    arm64_emit(ctx, 4181723734) // ldr x22, [x20, #16] (data_ptr)

    // openat(AT_FDCWD, path, O_WRONLY|O_CREAT|O_TRUNC (577), 0755 (493))
    arm64_emit_movz(ctx, ARM64_REG_X8, 56, 0)        // sys_openat = 56
    arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 0 - 100) // AT_FDCWD = -100
    arm64_emit(ctx, 2853372897)                      // mov x1, x19
    arm64_emit_movz(ctx, ARM64_REG_X2, 577, 0)       // 577
    arm64_emit_movz(ctx, ARM64_REG_X3, 493, 0)       // 493 (0755)
    arm64_emit_svc(ctx, 0)
    arm64_emit(ctx, 2852390391)                      // mov x23, x0 (fd)

    lbl_fw_fail = arm64_make_anon_label(ctx, "fw_fail")
    lbl_fw_done = arm64_make_anon_label(ctx, "fw_done")
    arm64_emit(ctx, arm64_cmp_imm(23, 0))
    arm64_emit_b_cond_label(ctx, ARM64_COND_LT, lbl_fw_fail)

    // Allocate count bytes for raw byte buffer
    arm64_emit(ctx, 2853503968)                      // mov x0, x21
    arm64_emit_bl_label(ctx, "_lipi_alloc")
    arm64_emit(ctx, 2852455928)                      // mov x24, x0 (byte_buf)

    // Copy 64-bit int list elements into 8-bit bytes
    arm64_emit_movz(ctx, 1, 0, 0)                    // i = 0
    lbl_fw_cploop = arm64_make_anon_label(ctx, "fw_cploop")
    lbl_fw_cpdone = arm64_make_anon_label(ctx, "fw_cpdone")
    arm64_label_define(ctx, lbl_fw_cploop)
    arm64_emit(ctx, arm64_cmp(1, 21))
    arm64_emit_b_cond_label(ctx, ARM64_COND_GE, lbl_fw_cpdone)
    arm64_emit(ctx, 4167137986)                      // ldr x2, [x22, x1, lsl #3]
    arm64_emit(ctx, 941714178)                       // strb w2, [x24, x1]
    arm64_emit(ctx, 2432697377)                      // add x1, x1, #1
    arm64_emit_b_label(ctx, lbl_fw_cploop)
    arm64_label_define(ctx, lbl_fw_cpdone)

    // write(fd, byte_buf, count)
    arm64_emit_movz(ctx, ARM64_REG_X8, 64, 0)        // sys_write = 64
    arm64_emit(ctx, 2853635040)                      // mov x0, x23
    arm64_emit(ctx, 2853700577)                      // mov x1, x24
    arm64_emit(ctx, 2853503970)                      // mov x2, x21
    arm64_emit_svc(ctx, 0)

    // close(fd)
    arm64_emit_movz(ctx, ARM64_REG_X8, 57, 0)        // sys_close = 57
    arm64_emit(ctx, 2853635040)                      // mov x0, x23
    arm64_emit_svc(ctx, 0)

    arm64_emit_movz(ctx, ARM64_REG_X0, 0, 0)
    arm64_emit_b_label(ctx, lbl_fw_done)

    arm64_label_define(ctx, lbl_fw_fail)
    arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 0 - 1)

    arm64_label_define(ctx, lbl_fw_done)
    arm64_emit(ctx, 2833402007)                      // ldp x23, x24, [sp, #48]
    arm64_emit(ctx, 2833270421)                      // ldp x21, x22, [sp, #32]
    arm64_emit(ctx, 2833138835)                      // ldp x19, x20, [sp, #16]
    arm64_emit(ctx, 2831449085)                      // ldp x29, x30, [sp], #64
    arm64_emit_ret(ctx)

// ==============================================================================
// 🏛️ PART V: ARM64 AST Code Generator (Expressions & Statements)
// ==============================================================================

fn arm64_compile_primary ctx ps
    arm64_ps_skip_nl(ps)
    tt  = arm64_ps_cur_type(ps)
    txt = arm64_ps_cur_text(ps)

    if tt == ARM64_TOK_INT
        val = arm64_ps_cur_int(ps)
        arm64_ps_adv(ps)
        arm64_emit_mov_imm64(ctx, ARM64_REG_X0, val)
        return 0

    if tt == ARM64_TOK_STR
        lbl = arm64_string_add(ctx, txt)
        arm64_ps_adv(ps)
        arm64_emit_adr_label(ctx, ARM64_REG_X0, lbl)
        return 0

    if tt == ARM64_TOK_LPAREN
        arm64_ps_adv(ps)
        arm64_compile_expr(ctx, ps)
        if arm64_ps_cur_type(ps) == ARM64_TOK_RPAREN
            arm64_ps_adv(ps)
        return 0

    if tt == ARM64_TOK_IDENT
        name = txt
        arm64_ps_adv(ps)

        if name == "true" or name == "সত্য"
            arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 1)
            return 0
        if name == "false" or name == "মিথ্যা" or name == "null" or name == "nil" or name == "শূন্য"
            arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 0)
            return 0

        // Function call: name(...)
        if arm64_ps_cur_type(ps) == ARM64_TOK_LPAREN
            arm64_ps_adv(ps)
            arg_count = 0
            while arm64_ps_cur_type(ps) != ARM64_TOK_RPAREN and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                arm64_compile_expr(ctx, ps)
                arm64_push_reg(ctx, ARM64_REG_X0)
                arg_count = arg_count + 1
                if arm64_ps_cur_type(ps) == ARM64_TOK_COMMA
                    arm64_ps_adv(ps)
            if arm64_ps_cur_type(ps) == ARM64_TOK_RPAREN
                arm64_ps_adv(ps)

            // Pop args into X0..X7 in reverse
            ai = arg_count - 1
            while ai >= 0
                if ai < 8
                    arm64_pop_reg(ctx, ai)
                else
                    arm64_pop_reg(ctx, ARM64_REG_X0)
                ai = ai - 1

            if name == "len" or name == "length" or name == "দৈর্ঘ্য"
                arm64_emit_bl_label(ctx, "lipi_fn_len")
                return 0
            if name == "syscall" or name == "sys_call" or name == "সিসকল"
                arm64_emit_bl_label(ctx, "lipi_fn_syscall")
                return 0
            if name == "exit"
                arm64_emit_bl_label(ctx, "lipi_fn_exit")
                return 0

            arm64_emit_bl_label(ctx, "lipi_fn_" + name)
            return 0

        // Local variable lookup
        off = arm64_scope_get(ctx, name)
        if off > 0
            arm64_emit_ldr_imm(ctx, ARM64_REG_X0, ARM64_REG_SP, floor(off / 8))
            while arm64_ps_cur_type(ps) == ARM64_TOK_OP and arm64_ps_cur_text(ps) == "."
                arm64_ps_adv(ps)
                fname = arm64_ps_cur_text(ps)
                arm64_ps_adv(ps)
                foff = arm64_struct_get_field_offset(ctx, "", fname)
                arm64_emit_ldr_imm(ctx, ARM64_REG_X0, ARM64_REG_X0, floor(foff / 8))
            return 0

        // Global constant lookup
        gi = 0
        gnames = get(ctx, 15)
        gvals  = get(ctx, 16)
        while gi < len(gnames)
            if get(gnames, gi) == name
                arm64_emit_mov_imm64(ctx, ARM64_REG_X0, get(gvals, gi))
                return 0
            gi = gi + 1

        // Bare function call: name arg1 arg2 ...
        if arm64_is_arg_start(ps) == 1
            arg_count = 0
            while arm64_is_arg_start(ps) == 1 and arm64_ps_cur_type(ps) != ARM64_TOK_NL and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                arm64_compile_primary(ctx, ps)
                arm64_push_reg(ctx, ARM64_REG_X0)
                arg_count = arg_count + 1

            ai = arg_count - 1
            while ai >= 0
                if ai < 8
                    arm64_pop_reg(ctx, ai)
                else
                    arm64_pop_reg(ctx, ARM64_REG_X0)
                ai = ai - 1

            if name == "len" or name == "length" or name == "দৈর্ঘ্য"
                arm64_emit_bl_label(ctx, "lipi_fn_len")
                return 0
            if name == "syscall" or name == "sys_call" or name == "সিসকল"
                arm64_emit_bl_label(ctx, "lipi_fn_syscall")
                return 0
            if name == "exit"
                arm64_emit_bl_label(ctx, "lipi_fn_exit")
                return 0

            arm64_emit_bl_label(ctx, "lipi_fn_" + name)
            return 0

        arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 0)
        return 0

    return 0

fn arm64_compile_unary ctx ps
    arm64_ps_skip_nl(ps)
    if arm64_ps_cur_type(ps) == ARM64_TOK_OP and arm64_ps_cur_text(ps) == "-"
        arm64_ps_adv(ps)
        arm64_compile_unary(ctx, ps)
        arm64_emit_sub(ctx, ARM64_REG_X0, 31, ARM64_REG_X0) // sub x0, xzr, x0
        return 0
    arm64_compile_primary(ctx, ps)

fn arm64_compile_mul ctx ps
    arm64_compile_unary(ctx, ps)
    while arm64_ps_cur_type(ps) == ARM64_TOK_OP and (arm64_ps_cur_text(ps) == "*" or arm64_ps_cur_text(ps) == "/" or arm64_ps_cur_text(ps) == "%")
        op = arm64_ps_cur_text(ps)
        arm64_ps_adv(ps)
        arm64_push_reg(ctx, ARM64_REG_X0)
        arm64_compile_unary(ctx, ps)
        arm64_emit_mov_reg(ctx, ARM64_REG_X1, ARM64_REG_X0) // X1 = rhs
        arm64_pop_reg(ctx, ARM64_REG_X0)                    // X0 = lhs
        if op == "*"
            arm64_emit(ctx, arm64_mul(ARM64_REG_X0, ARM64_REG_X0, ARM64_REG_X1))
        elif op == "/"
            arm64_emit(ctx, arm64_sdiv(ARM64_REG_X0, ARM64_REG_X0, ARM64_REG_X1))
        elif op == "%"
            arm64_emit(ctx, arm64_sdiv(ARM64_REG_X2, ARM64_REG_X0, ARM64_REG_X1))
            arm64_emit(ctx, arm64_msub(ARM64_REG_X0, ARM64_REG_X2, ARM64_REG_X1, ARM64_REG_X0))

fn arm64_compile_add ctx ps
    arm64_compile_mul(ctx, ps)
    while arm64_ps_cur_type(ps) == ARM64_TOK_OP and (arm64_ps_cur_text(ps) == "+" or arm64_ps_cur_text(ps) == "-")
        op = arm64_ps_cur_text(ps)
        arm64_ps_adv(ps)
        arm64_push_reg(ctx, ARM64_REG_X0)
        arm64_compile_mul(ctx, ps)
        arm64_emit_mov_reg(ctx, ARM64_REG_X1, ARM64_REG_X0) // X1 = rhs
        arm64_pop_reg(ctx, ARM64_REG_X0)                    // X0 = lhs
        if op == "+"
            arm64_emit_bl_label(ctx, "_lipi_add_or_concat")
        else
            arm64_emit_sub(ctx, ARM64_REG_X0, ARM64_REG_X0, ARM64_REG_X1)

fn arm64_compile_cmp ctx ps
    arm64_compile_add(ctx, ps)
    while arm64_ps_cur_type(ps) == ARM64_TOK_OP and (arm64_ps_cur_text(ps) == "==" or arm64_ps_cur_text(ps) == "!=" or arm64_ps_cur_text(ps) == "<" or arm64_ps_cur_text(ps) == "<=" or arm64_ps_cur_text(ps) == ">" or arm64_ps_cur_text(ps) == ">=")
        op = arm64_ps_cur_text(ps)
        arm64_ps_adv(ps)
        arm64_push_reg(ctx, ARM64_REG_X0)
        arm64_compile_add(ctx, ps)
        arm64_emit_mov_reg(ctx, ARM64_REG_X1, ARM64_REG_X0) // X1 = rhs
        arm64_pop_reg(ctx, ARM64_REG_X0)                    // X0 = lhs
        arm64_emit(ctx, arm64_cmp(ARM64_REG_X0, ARM64_REG_X1))
        if op == "=="
            arm64_emit(ctx, arm64_cset(ARM64_REG_X0, ARM64_COND_EQ))
        elif op == "!="
            arm64_emit(ctx, arm64_cset(ARM64_REG_X0, ARM64_COND_NE))
        elif op == "<"
            arm64_emit(ctx, arm64_cset(ARM64_REG_X0, ARM64_COND_LT))
        elif op == "<="
            arm64_emit(ctx, arm64_cset(ARM64_REG_X0, ARM64_COND_LE))
        elif op == ">"
            arm64_emit(ctx, arm64_cset(ARM64_REG_X0, ARM64_COND_GT))
        elif op == ">="
            arm64_emit(ctx, arm64_cset(ARM64_REG_X0, ARM64_COND_GE))

fn arm64_compile_not ctx ps
    arm64_ps_skip_nl(ps)
    tt = arm64_ps_cur_type(ps)
    txt = arm64_ps_cur_text(ps)
    if (tt == ARM64_TOK_IDENT and (txt == "not" or txt == "না")) or (tt == ARM64_TOK_OP and txt == "!")
        arm64_ps_adv(ps)
        arm64_compile_not(ctx, ps)
        arm64_emit(ctx, arm64_cmp(ARM64_REG_X0, 31)) // CMP X0, XZR
        arm64_emit(ctx, arm64_cset(ARM64_REG_X0, ARM64_COND_EQ))
        return 0
    arm64_compile_cmp(ctx, ps)
    return 0

fn arm64_compile_and ctx ps
    arm64_compile_not(ctx, ps)
    while (arm64_ps_cur_type(ps) == ARM64_TOK_IDENT and (arm64_ps_cur_text(ps) == "and" or arm64_ps_cur_text(ps) == "এবং")) or (arm64_ps_cur_type(ps) == ARM64_TOK_OP and arm64_ps_cur_text(ps) == "&&")
        arm64_ps_adv(ps)
        lbl_sc = arm64_make_anon_label(ctx, "and_sc")
        arm64_emit_cbz_label(ctx, ARM64_REG_X0, lbl_sc)
        arm64_compile_not(ctx, ps)
        arm64_emit(ctx, arm64_cmp(ARM64_REG_X0, 31))
        arm64_emit(ctx, arm64_cset(ARM64_REG_X0, ARM64_COND_NE))
        arm64_label_define(ctx, lbl_sc)

fn arm64_compile_or ctx ps
    arm64_compile_and(ctx, ps)
    while (arm64_ps_cur_type(ps) == ARM64_TOK_IDENT and (arm64_ps_cur_text(ps) == "or" or arm64_ps_cur_text(ps) == "অথবা")) or (arm64_ps_cur_type(ps) == ARM64_TOK_OP and arm64_ps_cur_text(ps) == "||")
        arm64_ps_adv(ps)
        lbl_sc   = arm64_make_anon_label(ctx, "or_sc")
        lbl_done = arm64_make_anon_label(ctx, "or_done")
        arm64_emit_cbnz_label(ctx, ARM64_REG_X0, lbl_sc)
        arm64_compile_and(ctx, ps)
        arm64_emit(ctx, arm64_cmp(ARM64_REG_X0, 31))
        arm64_emit(ctx, arm64_cset(ARM64_REG_X0, ARM64_COND_NE))
        arm64_emit_b_label(ctx, lbl_done)
        arm64_label_define(ctx, lbl_sc)
        arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 1)
        arm64_label_define(ctx, lbl_done)

fn arm64_compile_expr ctx ps
    arm64_compile_or(ctx, ps)

fn arm64_compile_stmt ctx ps
    arm64_ps_skip_nl(ps)
    tt  = arm64_ps_cur_type(ps)
    txt = arm64_ps_cur_text(ps)

    if tt == ARM64_TOK_EOF or tt == ARM64_TOK_DEDENT
        return 0

    // include / অন্তর্ভুক্ত -- skip line (handled by pre-pass bundler)
    if tt == ARM64_TOK_IDENT and (txt == "include" or txt == "অন্তর্ভুক্ত")
        while arm64_ps_cur_type(ps) != ARM64_TOK_NL and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
            arm64_ps_adv(ps)
        return 0

    // struct / গঠন / @struct
    // WHY: Support defining structured data types with 8-byte field offsets on ARM64
    if tt == ARM64_TOK_IDENT and (txt == "struct" or txt == "গঠন" or txt == "@struct")
        is_meta_struct = (txt == "@struct")
        arm64_ps_adv(ps)
        sname = arm64_ps_cur_text(ps)
        arm64_ps_adv(ps)
        fields = list()
        arm64_ps_skip_nl(ps)
        if is_meta_struct == 1
            while arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                arm64_ps_skip_nl(ps)
                if arm64_ps_cur_type(ps) == ARM64_TOK_IDENT and arm64_ps_cur_text(ps) == "@end"
                    arm64_ps_adv(ps)
                    break
                if arm64_ps_cur_type(ps) == ARM64_TOK_IDENT
                    push(fields, arm64_ps_cur_text(ps))
                    arm64_ps_adv(ps)
                    while arm64_ps_cur_type(ps) != ARM64_TOK_NL and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                        arm64_ps_adv(ps)
                else
                    arm64_ps_adv(ps)
                arm64_ps_skip_nl(ps)
        elif arm64_ps_cur_type(ps) == ARM64_TOK_INDENT
            arm64_ps_adv(ps)
            while arm64_ps_cur_type(ps) != ARM64_TOK_DEDENT and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                if arm64_ps_cur_type(ps) == ARM64_TOK_IDENT
                    push(fields, arm64_ps_cur_text(ps))
                    arm64_ps_adv(ps)
                    while arm64_ps_cur_type(ps) != ARM64_TOK_NL and arm64_ps_cur_type(ps) != ARM64_TOK_DEDENT and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                        arm64_ps_adv(ps)
                else
                    arm64_ps_adv(ps)
                arm64_ps_skip_nl(ps)
            if arm64_ps_cur_type(ps) == ARM64_TOK_DEDENT
                arm64_ps_adv(ps)
        arm64_struct_add(ctx, sname, fields)
        return 0

    // impl / @impl
    // WHY: Support struct method blocks and contextual method namespacing
    if tt == ARM64_TOK_IDENT and (txt == "impl" or txt == "@impl")
        arm64_ps_adv(ps)
        sname = arm64_ps_cur_text(ps)
        arm64_ps_adv(ps)
        list_set(get(ctx, 19), 0, sname)
        return 0

    // let / চলক / ধরি -- variable declaration binding
    // WHY: Support 'let x = expr', 'let x: int = expr', and Bengali 'চলক x = expr' / 'ধরি x = expr'
    if tt == ARM64_TOK_IDENT and (txt == "let" or txt == "চলক" or txt == "ধরি")
        arm64_ps_adv(ps)
        var_name = arm64_ps_cur_text(ps)
        arm64_ps_adv(ps)
        // Check for optional type annotation ': type'
        if arm64_ps_cur_type(ps) == ARM64_TOK_OP and arm64_ps_cur_text(ps) == ":"
            arm64_ps_adv(ps)
            if arm64_ps_cur_type(ps) == ARM64_TOK_IDENT
                arm64_ps_adv(ps)
        if arm64_ps_cur_type(ps) == ARM64_TOK_OP and arm64_ps_cur_text(ps) == "="
            arm64_ps_adv(ps)
            is_int_c = (arm64_ps_cur_type(ps) == ARM64_TOK_INT)
            int_c_val = arm64_ps_cur_int(ps)
            arm64_compile_expr(ctx, ps)
            off = arm64_scope_add(ctx, var_name)
            arm64_emit_str_imm(ctx, ARM64_REG_X0, ARM64_REG_SP, floor(off / 8))
            if is_int_c == 1
                push(get(ctx, 15), var_name)
                push(get(ctx, 16), int_c_val)
        return 0

    // break / থামো
    if tt == ARM64_TOK_IDENT and (txt == "break" or txt == "থামো")
        arm64_ps_adv(ps)
        estk = get(ctx, 14)
        if len(estk) > 0
            arm64_emit_b_label(ctx, get(estk, len(estk) - 1))
        return 0

    // continue / চলুক
    if tt == ARM64_TOK_IDENT and (txt == "continue" or txt == "চলুক")
        arm64_ps_adv(ps)
        sstk = get(ctx, 13)
        if len(sstk) > 0
            arm64_emit_b_label(ctx, get(sstk, len(sstk) - 1))
        return 0

    // say / বলো / show / দেখাও / print / println
    if tt == ARM64_TOK_IDENT and (txt == "say" or txt == "বলো" or txt == "show" or txt == "দেখাও" or txt == "print" or txt == "println")
        is_say = (txt == "say" or txt == "বলো" or txt == "println")
        arm64_ps_adv(ps)
        arm64_compile_expr(ctx, ps)
        arm64_emit_bl_label(ctx, "_lipi_print_dynamic")
        if is_say == 1
            arm64_emit_bl_label(ctx, "_lipi_print_nl")
        return 0

    // if / elif / else (যদি / নাহলে_যদি / নাহলে)
    if tt == ARM64_TOK_IDENT and (txt == "if" or txt == "যদি")
        arm64_ps_adv(ps)
        arm64_compile_expr(ctx, ps)
        lbl_end  = arm64_make_anon_label(ctx, "if_end")
        lbl_next = arm64_make_anon_label(ctx, "if_next")
        arm64_emit_cbz_label(ctx, ARM64_REG_X0, lbl_next)

        arm64_ps_skip_nl(ps)
        if arm64_ps_cur_type(ps) == ARM64_TOK_INDENT
            arm64_ps_adv(ps)
            while arm64_ps_cur_type(ps) != ARM64_TOK_DEDENT and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                prev_if_p = arm64_ps_pos(ps)
                arm64_compile_stmt(ctx, ps)
                if arm64_ps_pos(ps) == prev_if_p
                    arm64_ps_adv(ps)
                arm64_ps_skip_nl(ps)
            if arm64_ps_cur_type(ps) == ARM64_TOK_DEDENT
                arm64_ps_adv(ps)
        else
            arm64_compile_stmt(ctx, ps)

        arm64_emit_b_label(ctx, lbl_end)
        arm64_label_define(ctx, lbl_next)

        arm64_ps_skip_nl(ps)
        while arm64_ps_cur_type(ps) == ARM64_TOK_IDENT and (arm64_ps_cur_text(ps) == "elif" or arm64_ps_cur_text(ps) == "নাহলে_যদি")
            arm64_ps_adv(ps)
            arm64_compile_expr(ctx, ps)
            lbl_next = arm64_make_anon_label(ctx, "elif_next")
            arm64_emit_cbz_label(ctx, ARM64_REG_X0, lbl_next)

            arm64_ps_skip_nl(ps)
            if arm64_ps_cur_type(ps) == ARM64_TOK_INDENT
                arm64_ps_adv(ps)
                while arm64_ps_cur_type(ps) != ARM64_TOK_DEDENT and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                    prev_elif_p = arm64_ps_pos(ps)
                    arm64_compile_stmt(ctx, ps)
                    if arm64_ps_pos(ps) == prev_elif_p
                        arm64_ps_adv(ps)
                    arm64_ps_skip_nl(ps)
                if arm64_ps_cur_type(ps) == ARM64_TOK_DEDENT
                    arm64_ps_adv(ps)
            else
                arm64_compile_stmt(ctx, ps)

            arm64_emit_b_label(ctx, lbl_end)
            arm64_label_define(ctx, lbl_next)
            arm64_ps_skip_nl(ps)

        if arm64_ps_cur_type(ps) == ARM64_TOK_IDENT and (arm64_ps_cur_text(ps) == "else" or arm64_ps_cur_text(ps) == "নাহলে")
            arm64_ps_adv(ps)
            arm64_ps_skip_nl(ps)
            if arm64_ps_cur_type(ps) == ARM64_TOK_INDENT
                arm64_ps_adv(ps)
                while arm64_ps_cur_type(ps) != ARM64_TOK_DEDENT and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                    prev_else_p = arm64_ps_pos(ps)
                    arm64_compile_stmt(ctx, ps)
                    if arm64_ps_pos(ps) == prev_else_p
                        arm64_ps_adv(ps)
                    arm64_ps_skip_nl(ps)
                if arm64_ps_cur_type(ps) == ARM64_TOK_DEDENT
                    arm64_ps_adv(ps)
            else
                arm64_compile_stmt(ctx, ps)

        arm64_label_define(ctx, lbl_end)
        return 0

    // while / যতক্ষণ
    if tt == ARM64_TOK_IDENT and (txt == "while" or txt == "যতক্ষণ")
        arm64_ps_adv(ps)
        lbl_loop = arm64_make_anon_label(ctx, "while_loop")
        lbl_end  = arm64_make_anon_label(ctx, "while_end")
        arm64_label_define(ctx, lbl_loop)
        arm64_compile_expr(ctx, ps)
        arm64_emit_cbz_label(ctx, ARM64_REG_X0, lbl_end)

        arm64_loop_push(ctx, lbl_loop, lbl_end)
        arm64_ps_skip_nl(ps)
        if arm64_ps_cur_type(ps) == ARM64_TOK_INDENT
            arm64_ps_adv(ps)
            while arm64_ps_cur_type(ps) != ARM64_TOK_DEDENT and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                prev_while_p = arm64_ps_pos(ps)
                arm64_compile_stmt(ctx, ps)
                if arm64_ps_pos(ps) == prev_while_p
                    arm64_ps_adv(ps)
                arm64_ps_skip_nl(ps)
            if arm64_ps_cur_type(ps) == ARM64_TOK_DEDENT
                arm64_ps_adv(ps)
        else
            arm64_compile_stmt(ctx, ps)
        arm64_loop_pop(ctx)

        arm64_emit_b_label(ctx, lbl_loop)
        arm64_label_define(ctx, lbl_end)
        return 0

    // return / ফেরত
    if tt == ARM64_TOK_IDENT and (txt == "return" or txt == "ফেরত")
        arm64_ps_adv(ps)
        if arm64_ps_cur_type(ps) != ARM64_TOK_NL and arm64_ps_cur_type(ps) != ARM64_TOK_DEDENT and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
            arm64_compile_expr(ctx, ps)
        else
            arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 0)
        arm64_emit_epilogue(ctx)
        return 0

    // fn / কাজ (Function Definition)
    if tt == ARM64_TOK_IDENT and (txt == "fn" or txt == "কাজ")
        arm64_ps_adv(ps)
        fn_name = arm64_ps_cur_text(ps)
        arm64_ps_adv(ps)

        // Support struct methods: fn Point.distance self other
        if arm64_ps_cur_type(ps) == ARM64_TOK_OP and arm64_ps_cur_text(ps) == "."
            arm64_ps_adv(ps)
            method_name = arm64_ps_cur_text(ps)
            arm64_ps_adv(ps)
            fn_name = fn_name + "_" + method_name

        params = list()
        if arm64_ps_cur_type(ps) == ARM64_TOK_LPAREN
            arm64_ps_adv(ps)
            while arm64_ps_cur_type(ps) != ARM64_TOK_RPAREN and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                if arm64_ps_cur_type(ps) == ARM64_TOK_IDENT and len(params) < 8
                    push(params, arm64_ps_cur_text(ps))
                    arm64_ps_adv(ps)
                if arm64_ps_cur_type(ps) == ARM64_TOK_COMMA
                    arm64_ps_adv(ps)
            if arm64_ps_cur_type(ps) == ARM64_TOK_RPAREN
                arm64_ps_adv(ps)
        else
            while arm64_ps_cur_type(ps) == ARM64_TOK_IDENT and len(params) < 8
                if arm64_is_arg_start(ps) == 0
                    break
                push(params, arm64_ps_cur_text(ps))
                arm64_ps_adv(ps)

        lbl_skip = arm64_make_anon_label(ctx, "skip_fn")
        arm64_emit_b_label(ctx, lbl_skip)

        arm64_label_define(ctx, "lipi_fn_" + fn_name)

        // Save parent scope
        saved_names = get(ctx, 10)
        saved_offs  = get(ctx, 11)
        saved_stack = get(get(ctx, 12), 0)

        list_set(ctx, 10, list())
        list_set(ctx, 11, list())
        list_set(get(ctx, 12), 0, 16)

        arm64_emit_prologue(ctx)

        // Store incoming parameter registers (X0..X7) into stack frame
        pi = 0
        while pi < len(params)
            off = arm64_scope_add(ctx, get(params, pi))
            if pi < 8
                arm64_emit_str_imm(ctx, pi, ARM64_REG_SP, floor(off / 8))
            pi = pi + 1

        // One-liner functions: fn double n = n * 2
        if arm64_ps_cur_type(ps) == ARM64_TOK_OP and arm64_ps_cur_text(ps) == "="
            arm64_ps_adv(ps)
            arm64_compile_expr(ctx, ps)
            arm64_emit_epilogue(ctx)
            list_set(ctx, 10, saved_names)
            list_set(ctx, 11, saved_offs)
            list_set(get(ctx, 12), 0, saved_stack)
            arm64_label_define(ctx, lbl_skip)
            return 0

        arm64_ps_skip_nl(ps)
        if arm64_ps_cur_type(ps) == ARM64_TOK_INDENT
            arm64_ps_adv(ps)
            while arm64_ps_cur_type(ps) != ARM64_TOK_DEDENT and arm64_ps_cur_type(ps) != ARM64_TOK_EOF
                prev_fn_p = arm64_ps_pos(ps)
                arm64_compile_stmt(ctx, ps)
                if arm64_ps_pos(ps) == prev_fn_p
                    arm64_ps_adv(ps)
                arm64_ps_skip_nl(ps)
            if arm64_ps_cur_type(ps) == ARM64_TOK_DEDENT
                arm64_ps_adv(ps)
        else
            arm64_compile_stmt(ctx, ps)

        arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 0)
        arm64_emit_epilogue(ctx)

        // Restore parent scope
        list_set(ctx, 10, saved_names)
        list_set(ctx, 11, saved_offs)
        list_set(get(ctx, 12), 0, saved_stack)

        arm64_label_define(ctx, lbl_skip)
        return 0

    // Variable assignment: name = expr
    next_tok = arm64_ps_peek_tok(ps, 1)
    if tt == ARM64_TOK_IDENT and arm64_tok_t(next_tok) == ARM64_TOK_OP and arm64_tok_s(next_tok) == "="
        name = txt
        arm64_ps_adv(ps) // ident
        arm64_ps_adv(ps) // '='
        is_int_c = (arm64_ps_cur_type(ps) == ARM64_TOK_INT)
        int_c_val = arm64_ps_cur_int(ps)
        arm64_compile_expr(ctx, ps)
        off = arm64_scope_add(ctx, name)
        arm64_emit_str_imm(ctx, ARM64_REG_X0, ARM64_REG_SP, floor(off / 8))
        if is_int_c == 1
            push(get(ctx, 15), name)
            push(get(ctx, 16), int_c_val)
        return 0

    // Compound assignment: name += expr, -=
    if tt == ARM64_TOK_IDENT and arm64_tok_t(next_tok) == ARM64_TOK_OP and (arm64_tok_s(next_tok) == "+=" or arm64_tok_s(next_tok) == "-=")
        name = txt
        cop = arm64_tok_s(next_tok)
        arm64_ps_adv(ps) // ident
        arm64_ps_adv(ps) // op
        arm64_compile_expr(ctx, ps)
        off = arm64_scope_add(ctx, name)
        arm64_emit_mov_reg(ctx, ARM64_REG_X1, ARM64_REG_X0) // X1 = rhs
        arm64_emit_ldr_imm(ctx, ARM64_REG_X0, ARM64_REG_SP, floor(off / 8)) // X0 = lhs
        if char_at(cop, 0) == "+"
            arm64_emit_add(ctx, ARM64_REG_X0, ARM64_REG_X0, ARM64_REG_X1)
        else
            arm64_emit_sub(ctx, ARM64_REG_X0, ARM64_REG_X0, ARM64_REG_X1)
        arm64_emit_str_imm(ctx, ARM64_REG_X0, ARM64_REG_SP, floor(off / 8))
        return 0

    // Standalone expression (function calls, etc.)
    arm64_compile_expr(ctx, ps)
    return 0

// ==============================================================================
// 🏛️ PART VI: Pure Lipi ARM64 Multi-File Bundler & Compiler Pipeline Entry Point
// ==============================================================================

fn arm64_str_sub s start end
    slen = len(s)
    if start < 0
        start = 0
    if end > slen
        end = slen
    if start >= end
        return ""
    span = end - start
    if span == 1
        return char_at(s, start)
    if span == 2
        return char_at(s, start) + char_at(s, start + 1)
    if span == 3
        return char_at(s, start) + char_at(s, start + 1) + char_at(s, start + 2)
    if span == 4
        return char_at(s, start) + char_at(s, start + 1) + char_at(s, start + 2) + char_at(s, start + 3)
    mid = start + (span / 2)
    return arm64_str_sub(s, start, mid) + arm64_str_sub(s, mid, end)

fn arm64_path_dirname p
    last_slash = -1
    i = 0
    plen = len(p)
    while i < plen
        if char_at(p, i) == "/"
            last_slash = i
        i = i + 1
    if last_slash < 0
        return "."
    if last_slash == 0
        return "/"
    return arm64_str_sub(p, 0, last_slash)

fn arm64_list_has lst item
    i = 0
    llen = len(lst)
    while i < llen
        if get(lst, i) == item
            return 1
        i = i + 1
    return 0

// WHY: Transparent backward compatibility mapping for legacy std/* includes
// on ARM64 emitter to ensure identical behavior with x86-64 elf_emitter.
fn arm64_map_legacy_stdlib inc_name
    if inc_name == "std/crypto.lp" or inc_name == "std/crypto"
        return "universe/crypto/crypto.lp"
    if inc_name == "std/crypto2.lp" or inc_name == "std/crypto2"
        return "universe/crypto/advanced.lp"
    if inc_name == "std/tls.lp" or inc_name == "std/tls"
        return "universe/crypto/tls.lp"
    if inc_name == "std/mem.lp" or inc_name == "std/mem"
        return "universe/core/memory.lp"
    if inc_name == "std/io.lp" or inc_name == "std/io"
        return "universe/core/io.lp"
    if inc_name == "std/str.lp" or inc_name == "std/str"
        return "universe/core/string.lp"
    if inc_name == "std/math.lp" or inc_name == "std/math"
        return "universe/core/math.lp"
    if inc_name == "std/arena.lp" or inc_name == "std/arena"
        return "universe/core/arena.lp"
    if inc_name == "std/hashmap.lp" or inc_name == "std/hashmap"
        return "universe/core/hashmap.lp"
    if inc_name == "std/fmt.lp" or inc_name == "std/fmt"
        return "universe/core/fmt.lp"
    if inc_name == "std/time.lp" or inc_name == "std/time"
        return "universe/core/time.lp"
    if inc_name == "std/json.lp" or inc_name == "std/json"
        return "universe/core/json.lp"
    if inc_name == "std/regex.lp" or inc_name == "std/regex"
        return "universe/core/regex.lp"
    if inc_name == "std/simd.lp" or inc_name == "std/simd"
        return "universe/core/simd.lp"
    if inc_name == "std/multilang.lp" or inc_name == "std/multilang"
        return "universe/core/multilang.lp"
    if inc_name == "std/version.lp" or inc_name == "std/version"
        return "universe/core/version.lp"
    if inc_name == "std/web.lp" or inc_name == "std/web"
        return "universe/web/engine.lp"
    if inc_name == "std/http.lp" or inc_name == "std/http"
        return "universe/web/http.lp"
    if inc_name == "std/net.lp" or inc_name == "std/net"
        return "universe/net/socket.lp"
    if inc_name == "std/websocket.lp" or inc_name == "std/websocket"
        return "universe/net/ws_wire.lp"
    if inc_name == "std/grpc.lp" or inc_name == "std/grpc"
        return "universe/net/grpc_server.lp"
    if inc_name == "std/db.lp" or inc_name == "std/db"
        return "universe/db/engine.lp"
    if inc_name == "std/kv.lp" or inc_name == "std/kv"
        return "universe/db/kv.lp"
    if inc_name == "std/orm.lp" or inc_name == "std/orm"
        return "universe/db/orm.lp"
    if inc_name == "std/columnstore.lp" or inc_name == "std/columnstore"
        return "universe/db/column/columnstore.lp"
    if inc_name == "std/kernel.lp" or inc_name == "std/kernel"
        return "universe/os/kernel_multiboot.lp"
    if inc_name == "std/thread.lp" or inc_name == "std/thread"
        return "universe/os/thread.lp"
    if inc_name == "std/shm.lp" or inc_name == "std/shm"
        return "universe/os/shm.lp"
    if inc_name == "std/event.lp" or inc_name == "std/event"
        return "universe/os/event.lp"
    if inc_name == "std/cli.lp" or inc_name == "std/cli"
        return "universe/tools/cli.lp"
    if inc_name == "std/debug.lp" or inc_name == "std/debug"
        return "universe/tools/debug.lp"
    if inc_name == "std/test.lp" or inc_name == "std/test"
        return "universe/tools/test_runner.lp"
    if inc_name == "std/ai.lp" or inc_name == "std/ai"
        return "universe/ai/tensor_engine.lp"
    if inc_name == "std/gguf.lp" or inc_name == "std/gguf"
        return "universe/ai/gguf.lp"
    if inc_name == "std/gfx.lp" or inc_name == "std/gfx"
        return "universe/gui/gfx.lp"
    if inc_name == "std/x11.lp" or inc_name == "std/x11"
        return "universe/gui/x11/x11.lp"
    if inc_name == "std/tui.lp" or inc_name == "std/tui"
        return "universe/gui/tui.lp"
    return ""

fn arm64_resolve_inc_path cur_dir inc_name
    legacy = arm64_map_legacy_stdlib(inc_name)
    if len(legacy) > 0
        return legacy
    if file_exists(inc_name) == 1
        return inc_name
    cand1 = cur_dir + "/" + inc_name
    if file_exists(cand1) == 1
        return cand1
    cand_uni = "universe/" + inc_name
    if file_exists(cand_uni) == 1
        return cand_uni
    cand3 = "../" + inc_name
    if file_exists(cand3) == 1
        return cand3
    return cand1

fn arm64_has_include content
    p = 0
    clen = len(content)
    while p < clen
        while p < clen and (char_at(content, p) == " " or char_at(content, p) == "\t")
            p = p + 1
        if p + 9 < clen
            if char_at(content, p) == "i" and char_at(content, p+1) == "n" and char_at(content, p+2) == "c" and char_at(content, p+3) == "l" and char_at(content, p+4) == "u" and char_at(content, p+5) == "d" and char_at(content, p+6) == "e" and char_at(content, p+7) == " "
                q = char_at(content, p+8)
                if q == "\"" or q == "'"
                    return 1
        if p + 35 < clen
            if ord(char_at(content, p)) == 224
                if arm64_str_sub(content, p, p + 34) == "অন্তর্ভুক্ত "
                    q = char_at(content, p+34)
                    if q == "\"" or q == "'"
                        return 1
        while p < clen and char_at(content, p) != "\n"
            p = p + 1
        if p < clen and char_at(content, p) == "\n"
            p = p + 1
    return 0

fn arm64_bundle_source file_path visited
    if arm64_list_has(visited, file_path) == 1
        return ""
    push(visited, file_path)
    if file_exists(file_path) == 0
        say "Warning: Included file not found: " + file_path
        return ""
    content = file_read(file_path)
    if arm64_has_include(content) == 0
        return content

    cur_dir = arm64_path_dirname(file_path)
    out = ""
    chunk_start = 0
    p = 0
    clen = len(content)
    while p < clen
        line_start = p
        while p < clen and (char_at(content, p) == " " or char_at(content, p) == "\t")
            p = p + 1

        is_inc = 0
        inc_target = ""
        if p + 9 < clen
            if char_at(content, p) == "i" and char_at(content, p+1) == "n" and char_at(content, p+2) == "c" and char_at(content, p+3) == "l" and char_at(content, p+4) == "u" and char_at(content, p+5) == "d" and char_at(content, p+6) == "e" and char_at(content, p+7) == " "
                q = char_at(content, p+8)
                if q == "\"" or q == "'"
                    p_tstart = p + 9
                    p_tend = p_tstart
                    while p_tend < clen and char_at(content, p_tend) != q and char_at(content, p_tend) != "\n"
                        p_tend = p_tend + 1
                    if p_tend < clen and char_at(content, p_tend) == q
                        is_inc = 1
                        inc_target = arm64_str_sub(content, p_tstart, p_tend)

        if is_inc == 0 and p + 35 < clen
            if ord(char_at(content, p)) == 224
                if arm64_str_sub(content, p, p + 34) == "অন্তর্ভুক্ত "
                    q = char_at(content, p+34)
                    if q == "\"" or q == "'"
                        p_tstart = p + 35
                        p_tend = p_tstart
                        while p_tend < clen and char_at(content, p_tend) != q and char_at(content, p_tend) != "\n"
                            p_tend = p_tend + 1
                        if p_tend < clen and char_at(content, p_tend) == q
                            is_inc = 1
                            inc_target = arm64_str_sub(content, p_tstart, p_tend)

        while p < clen and char_at(content, p) != "\n"
            p = p + 1
        if p < clen and char_at(content, p) == "\n"
            p = p + 1

        if is_inc == 1
            if line_start > chunk_start
                out = out + arm64_str_sub(content, chunk_start, line_start)
            resolved = arm64_resolve_inc_path(cur_dir, inc_target)
            bundled = arm64_bundle_source(resolved, visited)
            if len(bundled) > 0
                out = out + bundled + "\n"
            chunk_start = p

    if chunk_start < clen
        out = out + arm64_str_sub(content, chunk_start, clen)

    return out

// ── Pure Lipi Linux AArch64 (ARM64) ELF Compiler Pipeline Entry Point ─────────
// WHY: Translates Lipi source programs into standalone AArch64 Linux ELF64 binaries
//      with zero C, zero GCC, zero Libc, and zero Python dependencies.
fn arm64_compile_source_to_elf in_path out_path
    if file_exists(in_path) == 0
        say "Error: Input source file not found: " + in_path
        return 1

    visited = list()
    src = arm64_bundle_source(in_path, visited)
    tokens = arm64_tokenize(src)
    ps = arm64_ps_new(tokens)
    ctx = arm64_ctx_new()

    // Step 1: Entry Point _start at ELF base (0x400078)
    arm64_label_define(ctx, "_start")
    arm64_emit(ctx, 2432697312) // mov x0, sp (0x910003E0)
    arm64_emit_adr_label(ctx, 1, "_lipi_initial_sp")
    arm64_emit(ctx, 4177526816) // str x0, [x1] (0xF9000020)
    arm64_emit_bl_label(ctx, "_lipi_init_heap")
    arm64_emit_bl_label(ctx, "lipi_main")
    arm64_emit_movz(ctx, ARM64_REG_X8, ARM64_SYS_EXIT, 0) // X8 = 93 (sys_exit)
    arm64_emit_svc(ctx, 0)

    // Step 2: Emit baremetal runtime syscall stubs
    arm64_emit_runtime_stubs(ctx)

    // Step 3: Main program routine
    arm64_label_define(ctx, "lipi_main")
    arm64_emit_prologue(ctx)

    arm64_ps_skip_nl(ps)
    while arm64_ps_cur_type(ps) != ARM64_TOK_EOF
        prev_p = arm64_ps_pos(ps)
        arm64_compile_stmt(ctx, ps)
        if arm64_ps_pos(ps) == prev_p
            arm64_ps_adv(ps)
        arm64_ps_skip_nl(ps)

    arm64_emit_mov_imm64(ctx, ARM64_REG_X0, 0) // exit status 0
    arm64_emit_epilogue(ctx)

    // Step 4: String literals, backpatching, and ELF assembly
    arm64_emit_strings(ctx)
    arm64_backpatch_all(ctx)
    elf = arm64_build_elf(ctx)
    res = file_write_bytes(out_path, elf)
    return res
