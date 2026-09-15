// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — AARCH64 (ARM64) 32-BIT A64 ENCODER (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/arm64/a64_encoder.lp
//
// WHY THIS MODULE:
// 1. Unlike x86-64 CISC variable-length opcodes, AArch64 (A64) features a clean,
//    orthogonal, strictly fixed 32-bit (4-byte) instruction encoding.
// 2. Direct Silicon Machine Code Synthesis:
//    - Every instruction is constructed as a 32-bit little-endian integer word
//      and unpacked into 4 exact machine bytes [b0, b1, b2, b3].
//    - Zero assembler passes: Lipi directly emits machine code to ELF64 text sections.
// 3. Supported Silicon Instructions:
//    - ADD / SUB (register-to-register, 64-bit)
//    - ADD / SUB (immediate 12-bit, 64-bit)
//    - MOV (register copy via ORR with XZR)
//    - MOVZ / MOVK (wide 16-bit immediate synthesis with 0/16/32/48 bit shifts)
//    - LDR / STR (64-bit load/store with 12-bit unsigned scaled offset)
//    - STP / LDP (load/store register pair for stack frame prologue/epilogue)
//    - B / BL (26-bit PC-relative branches, +/- 128MB range)
//    - RET (subroutine return to LR / X30)
//    - SVC (Linux syscall trap: SVC #0)
//    - NOP (standard hardware no-op)
// ==============================================================================

// ── 1. Byte Stream Unpacker ───────────────────────────────────────────────────

fn a64_word_to_bytes word
    // WHY: Unpacks 32-bit instruction word into 4 little-endian bytes.
    b0 = word % 256
    w1 = word / 256
    b1 = w1 % 256
    w2 = w1 / 256
    b2 = w2 % 256
    w3 = w2 / 256
    b3 = w3 % 256

    res = list()
    push(res, b0)
    push(res, b1)
    push(res, b2)
    push(res, b3)
    return res

// ── 2. Data Processing & Arithmetic Encoders ─────────────────────────────────

fn a64_encode_add_reg rd rn rm
    // WHY: ADD Xd, Xn, Xm (64-bit integer addition).
    //      Base: 0x8B000000 (2332033024)
    d = rd % 32
    n = rn % 32
    m = rm % 32
    word = 2332033024 + (m * 65536) + (n * 32) + d
    return a64_word_to_bytes(word)

fn a64_encode_sub_reg rd rn rm
    // WHY: SUB Xd, Xn, Xm (64-bit integer subtraction).
    //      Base: 0xCB000000 (3405774848)
    d = rd % 32
    n = rn % 32
    m = rm % 32
    word = 3405774848 + (m * 65536) + (n * 32) + d
    return a64_word_to_bytes(word)

fn a64_encode_add_imm rd rn imm12
    // WHY: ADD Xd, Xn, #imm12 (64-bit add immediate 0..4095).
    //      Base: 0x91000000 (2432696320)
    d = rd % 32
    n = rn % 32
    imm = imm12 % 4096
    if imm < 0 imm = imm + 4096
    word = 2432696320 + (imm * 1024) + (n * 32) + d
    return a64_word_to_bytes(word)

fn a64_encode_sub_imm rd rn imm12
    // WHY: SUB Xd, Xn, #imm12 (64-bit subtract immediate 0..4095).
    //      Base: 0xD1000000 (3506438144)
    d = rd % 32
    n = rn % 32
    imm = imm12 % 4096
    if imm < 0 imm = imm + 4096
    word = 3506438144 + (imm * 1024) + (n * 32) + d
    return a64_word_to_bytes(word)

fn a64_encode_mov_reg rd rm
    // WHY: MOV Xd, Xm (Hardware alias for ORR Xd, XZR, Xm).
    //      Base: 0xAA0003E0 (2852127712)
    d = rd % 32
    m = rm % 32
    word = 2852127712 + (m * 65536) + d
    return a64_word_to_bytes(word)

// ── 3. Immediate Synthesis (MOVZ & MOVK) ───────────────────────────────────────

fn a64_encode_movz rd imm16 shift
    // WHY: MOVZ Xd, #imm16, LSL #shift (zeroes rest of register).
    //      Shift must be 0, 16, 32, or 48. hw = shift / 16.
    //      Base: 0xD2800000 (3531603968)
    d = rd % 32
    imm = imm16 % 65536
    if imm < 0 imm = imm + 65536
    hw = (shift / 16) % 4
    word = 3531603968 + (hw * 2097152) + (imm * 32) + d
    return a64_word_to_bytes(word)

fn a64_encode_movk rd imm16 shift
    // WHY: MOVK Xd, #imm16, LSL #shift (keeps existing bits, updates 16-bit lane).
    //      Base: 0xF2800000 (4068474880)
    d = rd % 32
    imm = imm16 % 65536
    if imm < 0 imm = imm + 65536
    hw = (shift / 16) % 4
    word = 4068474880 + (hw * 2097152) + (imm * 32) + d
    return a64_word_to_bytes(word)

// ── 4. Memory Load & Store Encoders ───────────────────────────────────────────

fn a64_encode_ldr_imm rt rn byte_offset
    // WHY: LDR Xt, [Xn, #imm12*8] (64-bit load with scaled 8-byte displacement).
    //      Base: 0xF9400000 (4181721088)
    t = rt % 32
    n = rn % 32
    imm_scaled = (byte_offset / 8) % 4096
    if imm_scaled < 0 imm_scaled = imm_scaled + 4096
    word = 4181721088 + (imm_scaled * 1024) + (n * 32) + t
    return a64_word_to_bytes(word)

fn a64_encode_str_imm rt rn byte_offset
    // WHY: STR Xt, [Xn, #imm12*8] (64-bit store with scaled 8-byte displacement).
    //      Base: 0xF9000000 (4177526784)
    t = rt % 32
    n = rn % 32
    imm_scaled = (byte_offset / 8) % 4096
    if imm_scaled < 0 imm_scaled = imm_scaled + 4096
    word = 4177526784 + (imm_scaled * 1024) + (n * 32) + t
    return a64_word_to_bytes(word)

fn a64_encode_stp_pre rt1 rt2 rn byte_disp
    // WHY: STP Xt1, Xt2, [Xn, #byte_disp]! (Pre-index store pair).
    //      Used in prologue to save FP(X29) & LR(X30): STP X29, X30, [SP, #-16]!
    //      Base: 0xA9800000 (2843738112)
    t1 = rt1 % 32
    t2 = rt2 % 32
    n = rn % 32
    imm7 = (byte_disp / 8) % 128
    if imm7 < 0 imm7 = imm7 + 128
    word = 2843738112 + (imm7 * 32768) + (t2 * 1024) + (n * 32) + t1
    return a64_word_to_bytes(word)

fn a64_encode_ldp_post rt1 rt2 rn byte_disp
    // WHY: LDP Xt1, Xt2, [Xn], #byte_disp (Post-index load pair).
    //      Used in epilogue: LDP X29, X30, [SP], #16
    //      Base: 0xA8C00000 (2831155200)
    t1 = rt1 % 32
    t2 = rt2 % 32
    n = rn % 32
    imm7 = (byte_disp / 8) % 128
    if imm7 < 0 imm7 = imm7 + 128
    word = 2831155200 + (imm7 * 32768) + (t2 * 1024) + (n * 32) + t1
    return a64_word_to_bytes(word)

// ── 5. Control Flow & System Calls ────────────────────────────────────────────

fn a64_encode_b byte_disp
    // WHY: B disp26 (Unconditional branch, +/- 128MB range, 4-byte instruction scaled).
    //      Base: 0x14000000 (335544320)
    imm26 = (byte_disp / 4) % 67108864
    if imm26 < 0 imm26 = imm26 + 67108864
    word = 335544320 + imm26
    return a64_word_to_bytes(word)

fn a64_encode_bl byte_disp
    // WHY: BL disp26 (Branch with link: saves return address in X30).
    //      Base: 0x94000000 (2483027968)
    imm26 = (byte_disp / 4) % 67108864
    if imm26 < 0 imm26 = imm26 + 67108864
    word = 2483027968 + imm26
    return a64_word_to_bytes(word)

fn a64_encode_ret
    // WHY: RET (subroutine return using Link Register X30).
    //      Opcode: 0xD65F03C0 (3596551104)
    return a64_word_to_bytes(3596551104)

fn a64_encode_svc imm16
    // WHY: SVC #imm16 (Supervisor Call / Syscall trap: SVC #0 for Linux AArch64).
    //      Base: 0xD4000001 (3556769793)
    imm = imm16 % 65536
    if imm < 0 imm = imm + 65536
    word = 3556769793 + (imm * 32)
    return a64_word_to_bytes(word)

fn a64_encode_nop
    // WHY: NOP (No operation).
    //      Opcode: 0xD503201F (3573751839)
    return a64_word_to_bytes(3573751839)

// ── 6. Verification Self-Test ────────────────────────────────────────────────

fn test_a64_encoder_subsystem
    // 1. RET instruction: 0xD65F03C0 -> [0xC0, 0x03, 0x5F, 0xD6]
    ret_b = a64_encode_ret()
    if len(ret_b) != 4 or get(ret_b, 0) != 192 or get(ret_b, 1) != 3 or get(ret_b, 2) != 95 or get(ret_b, 3) != 214
        say "FAIL: RET encoding mismatch"
        return 0

    // 2. NOP instruction: 0xD503201F -> [0x1F, 0x20, 0x03, 0xD5]
    nop_b = a64_encode_nop()
    if len(nop_b) != 4 or get(nop_b, 0) != 31 or get(nop_b, 1) != 32 or get(nop_b, 2) != 3 or get(nop_b, 3) != 213
        say "FAIL: NOP encoding mismatch"
        return 0

    // 3. SVC #0 instruction: 0xD4000001 -> [0x01, 0x00, 0x00, 0xD4]
    svc_b = a64_encode_svc(0)
    if len(svc_b) != 4 or get(svc_b, 0) != 1 or get(svc_b, 1) != 0 or get(svc_b, 2) != 0 or get(svc_b, 3) != 212
        say "FAIL: SVC #0 encoding mismatch"
        return 0

    // 4. ADD X0, X1, X2
    add_b = a64_encode_add_reg(0, 1, 2)
    if len(add_b) != 4
        say "FAIL: ADD instruction length must be 4"
        return 0

    return 1

// test_a64_encoder_subsystem()
