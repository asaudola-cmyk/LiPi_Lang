// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — AMD64 MODR/M AND SIB BUILDER (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/x86_64/modrm_sib.lp
//
// WHY THIS MODULE:
// 1. In the x86-64 CISC instruction encoding, the ModR/M byte is the primary mechanism
//    for specifying addressing modes, registers, and memory operands.
// 2. ModR/M Byte Format:
//    [mod: 2 bits] [reg/opcode: 3 bits] [r/m: 3 bits]
//    - mod = 00: Memory operand, no displacement (with RBP/R13 exception).
//    - mod = 01: Memory operand, 8-bit signed displacement follows.
//    - mod = 10: Memory operand, 32-bit signed displacement follows.
//    - mod = 11: Register-direct operand (both operands are physical registers).
// 3. SIB (Scale-Index-Base) Byte Format:
//    [scale: 2 bits] [index: 3 bits] [base: 3 bits]
//    - scale: 00 (*1), 01 (*2), 10 (*4), 11 (*8).
//    - index: register ID 0..7 (value 4 / RSP denotes NO index).
//    - base: register ID 0..7.
// 4. CRITICAL HARDWARE SILICON EDGE CASES:
//    - RSP / R12 Base Escape: Whenever the base register is RSP or R12 (reg % 8 == 4),
//      the hardware treats r/m = 4 as an escape code signaling that an SIB byte
//      MUST follow, even if no index register is used!
//    - RBP / R13 Displacement Exception: When mod = 00 and r/m = 5 (RBP or R13), the
//      CPU interprets this as RIP-relative disp32, NOT [RBP]! Therefore, [RBP + 0]
//      MUST be encoded as mod = 01 with an explicit 1-byte displacement of 0x00.
// ==============================================================================

// ── 1. ModR/M & SIB Result Descriptor ────────────────────────────────────────

struct ModRMSIBResult
    has_sib             // 1 if an SIB byte is required, 0 otherwise
    modrm_byte          // Assembled 8-bit ModR/M byte
    sib_byte            // Assembled 8-bit SIB byte (valid if has_sib == 1)
    disp_size           // Displacement length in bytes: 0, 1, or 4
    disp_val            // Integer displacement value

// ── 2. Primitive Byte Encoders ────────────────────────────────────────────────

fn modrm_build mod reg rm
    // WHY: Constructs single ModR/M byte from 2-bit mod, 3-bit reg, 3-bit rm.
    m = mod % 4
    r = reg % 8
    b = rm % 8
    return (m * 64) + (r * 8) + b

fn sib_build scale_pow index base
    // WHY: Constructs single SIB byte from 2-bit scale, 3-bit index, 3-bit base.
    //      scale_pow: 0 for *1, 1 for *2, 2 for *4, 3 for *8.
    s = scale_pow % 4
    i = index % 8
    b = base % 8
    return (s * 64) + (i * 8) + b

// ── 3. Register-to-Register Mode (mod = 11) ──────────────────────────────────

fn modrm_encode_reg_reg reg rm
    // WHY: Encodes direct register addressing. mod = 3 (11 binary).
    res = ModRMSIBResult()
    res.has_sib = 0
    res.modrm_byte = modrm_build(3, reg, rm)
    res.sib_byte = 0
    res.disp_size = 0
    res.disp_val = 0
    return res

// ── 4. Base + Displacement Addressing Mode ───────────────────────────────────

fn modrm_encode_base_disp reg base disp
    // WHY: Encodes [base + disp] addressing mode with all hardware edge cases handled.
    res = ModRMSIBResult()
    b_low = base % 8

    // Determine optimal mod and displacement size
    mod = 0
    d_size = 0

    if disp == 0
        if b_low == 5
            // HARDWARE TRAP: mod=0 with RBP/R13 encodes RIP-relative disp32.
            // To encode [RBP+0] or [R13+0], we MUST force mod=1 with disp8=0!
            mod = 1
            d_size = 1
        else
            mod = 0
            d_size = 0
    else
        if disp >= (0 - 128) and disp <= 127
            mod = 1
            d_size = 1
        else
            mod = 2
            d_size = 4

    // HARDWARE TRAP: Base RSP (4) or R12 (12) has b_low == 4.
    // r/m = 4 signals an SIB byte is present.
    if b_low == 4
        res.has_sib = 1
        res.modrm_byte = modrm_build(mod, reg, 4)
        // SIB: scale=0, index=4 (none), base=4 (RSP/R12) -> 0x24 = 36
        res.sib_byte = sib_build(0, 4, 4)
    else
        res.has_sib = 0
        res.modrm_byte = modrm_build(mod, reg, b_low)
        res.sib_byte = 0

    res.disp_size = d_size
    res.disp_val = disp
    return res

// ── 5. Full Scale-Index-Base (SIB) Addressing Mode ────────────────────────────

fn scale_to_power scale
    // WHY: Converts integer multiplier (1, 2, 4, 8) to 2-bit power (0, 1, 2, 3).
    if scale == 1 return 0
    if scale == 2 return 1
    if scale == 4 return 2
    if scale == 8 return 3
    return 0 // Default to *1

fn modrm_encode_sib reg base index scale disp
    // WHY: Encodes [base + index*scale + disp] memory addressing.
    res = ModRMSIBResult()
    res.has_sib = 1

    b_low = base % 8
    scale_pow = scale_to_power(scale)

    mod = 0
    d_size = 0

    if disp == 0
        if b_low == 5
            mod = 1
            d_size = 1
        else
            mod = 0
            d_size = 0
    else
        if disp >= (0 - 128) and disp <= 127
            mod = 1
            d_size = 1
        else
            mod = 2
            d_size = 4

    // r/m = 4 instructs CPU to read SIB byte
    res.modrm_byte = modrm_build(mod, reg, 4)
    res.sib_byte = sib_build(scale_pow, index, base)
    res.disp_size = d_size
    res.disp_val = disp
    return res

// ── 6. Verification Self-Test ────────────────────────────────────────────────

fn test_modrm_sib_subsystem
    // 1. Reg-to-reg RAX to RBX: mod=3, reg=0, rm=3 -> (3*64) + (0*8) + 3 = 195 (0xC3)
    r1 = modrm_encode_reg_reg(0, 3)
    if r1.modrm_byte != 195 or r1.has_sib != 0
        say "FAIL: Reg-to-reg RAX-RBX mismatch"
        return 0

    // 2. Base RSP with disp=8: Must require SIB byte 0x24 (36), mod=1, disp_size=1
    r2 = modrm_encode_base_disp(0, 4, 8)
    if r2.has_sib != 1 or r2.sib_byte != 36 or r2.disp_size != 1
        say "FAIL: RSP base SIB escape failed"
        return 0

    // 3. Base RBP with disp=0: Must NOT use mod=0; must force mod=1 with disp_size=1
    r3 = modrm_encode_base_disp(0, 5, 0)
    if r3.modrm_byte != 69 or r3.disp_size != 1
        say "FAIL: RBP disp=0 mod=1 override failed"
        return 0

    // 4. Base R12 (b_low=4) with disp=0: Must require SIB byte 0x24
    r4 = modrm_encode_base_disp(2, 12, 0)
    if r4.has_sib != 1 or r4.sib_byte != 36
        say "FAIL: R12 base SIB escape failed"
        return 0

    return 1

test_modrm_sib_subsystem()
