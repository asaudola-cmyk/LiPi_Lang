// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — AMD64 REX PREFIX CALCULATOR (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/x86_64/rex_prefix.lp
//
// WHY THIS MODULE:
// 1. AMD64 architecture preserves x86 32-bit legacy opcodes by using the previously
//    illegal 0x40-0x4F opcode range as instruction prefix bytes called "REX prefixes".
// 2. REX Byte Structure (Bits 7..0):
//    [0 1 0 0] [W] [R] [X] [B]
//    - High nibble is fixed 0100 (0x40 = 64 decimal).
//    - Bit 3 (W): 64-bit operand size override (0 = default 32/8-bit, 1 = 64-bit).
//    - Bit 2 (R): Extension bit for ModR/M 'reg' field (1 selects R8..R15).
//    - Bit 1 (X): Extension bit for SIB 'index' field (1 selects R8..R15).
//    - Bit 0 (B): Extension bit for ModR/M 'r/m', SIB 'base', or Opcode 'reg' field.
// 3. Byte Register Re-Addressing Edge Case:
//    - Without REX: registers 4..7 refer to high-byte registers AH, CH, DH, BH.
//    - With ANY REX prefix (even 0x40): registers 4..7 refer to SPL, BPL, SIL, DIL.
// 4. Precise computation ensures minimal instruction size and prevents hardware #UD
//    (undefined instruction) faults.
// ==============================================================================

// ── 1. Direct REX Byte Construction ──────────────────────────────────────────

fn rex_build w r x b
    // WHY: Assembles the raw REX byte from 4 individual binary flags (0 or 1).
    //      Base: 0x40 = 64
    w_bit = 0
    if w != 0 w_bit = 1

    r_bit = 0
    if r != 0 r_bit = 1

    x_bit = 0
    if x != 0 x_bit = 1

    b_bit = 0
    if b != 0 b_bit = 1

    return 64 + (w_bit * 8) + (r_bit * 4) + (x_bit * 2) + b_bit

fn rex_is_required w r x b
    // WHY: Returns 1 if any extension flag is set, necessitating emission of REX byte.
    if w != 0 or r != 0 or x != 0 or b != 0
        return 1
    return 0

// ── 2. Register-to-Register / ModR/M REX Calculator ──────────────────────────

fn rex_calc_rr is_64bit reg rm
    // WHY: Computes REX prefix for two-operand instructions (e.g. MOV, ADD, SUB, CMP).
    //      'reg' maps to ModR/M.reg (REX.R bit).
    //      'rm' maps to ModR/M.r/m (REX.B bit).
    w = 0
    if is_64bit != 0 w = 1

    r = 0
    if reg >= 8 r = 1

    b = 0
    if rm >= 8 b = 1

    return rex_build(w, r, 0, b)

// ── 3. SIB Memory Addressing REX Calculator ──────────────────────────────────

fn rex_calc_sib is_64bit reg base index
    // WHY: Computes REX prefix for memory operand addressing with scale-index-base.
    //      'reg' maps to ModR/M.reg (REX.R bit).
    //      'index' maps to SIB.index (REX.X bit).
    //      'base' maps to SIB.base (REX.B bit).
    w = 0
    if is_64bit != 0 w = 1

    r = 0
    if reg >= 8 r = 1

    x = 0
    if index >= 8 x = 1

    b = 0
    if base >= 8 b = 1

    return rex_build(w, r, x, b)

// ── 4. Opcode-Embedded Register REX Calculator ────────────────────────────────

fn rex_calc_opcode_reg is_64bit reg
    // WHY: Instructions like PUSH r64 (0x50+rd), POP r64 (0x58+rd), or MOV reg, imm64
    //      (0xB8+rd) encode the destination register in the lowest 3 bits of the opcode.
    //      Registers R8..R15 need REX.B=1 to extend the opcode register field.
    w = 0
    if is_64bit != 0 w = 1

    b = 0
    if reg >= 8 b = 1

    return rex_build(w, 0, 0, b)

// ── 5. Byte Register Access Special Case ──────────────────────────────────────

fn rex_calc_byte_reg reg
    // WHY: Accessing 8-bit registers SPL(4), BPL(5), SIL(6), DIL(7) strictly requires
    //      a REX prefix (0x40) to disambiguate from AH, CH, DH, BH.
    //      Registers R8B..R15B require REX.B = 1 (0x41).
    if reg >= 8 and reg <= 15
        return rex_build(0, 0, 0, 1) // REX.B = 0x41
    if reg >= 4 and reg <= 7
        return rex_build(0, 0, 0, 0) // REX = 0x40 (uniform low-byte selection)
    return 0 // No REX required for AL, CL, DL, BL (regs 0..3)

// ── 6. Verification Self-Test ────────────────────────────────────────────────

fn test_rex_prefix_subsystem
    // 1. Standard 64-bit RAX to RCX (no extended regs): W=1, R=0, X=0, B=0 -> 0x48 (72)
    rex1 = rex_calc_rr(1, 0, 1)
    if rex1 != 72
        say "FAIL: Expected REX 0x48 (72) for 64-bit RAX->RCX, got: " + str(rex1)
        return 0

    // 2. 64-bit R12 to R15 (both extended): W=1, R=1, X=0, B=1 -> 0x4D (77)
    rex2 = rex_calc_rr(1, 12, 15)
    if rex2 != 77
        say "FAIL: Expected REX 0x4D (77) for R12->R15, got: " + str(rex2)
        return 0

    // 3. 32-bit R8 to RAX: W=0, R=1, X=0, B=0 -> 0x44 (68)
    rex3 = rex_calc_rr(0, 8, 0)
    if rex3 != 68
        say "FAIL: Expected REX 0x44 (68) for 32-bit R8->RAX, got: " + str(rex3)
        return 0

    // 4. SIB with R10(base), R11(index), R9(reg): W=1, R=1, X=1, B=1 -> 0x4F (79)
    rex4 = rex_calc_sib(1, 9, 10, 11)
    if rex4 != 79
        say "FAIL: Expected REX 0x4F (79) for full extension SIB, got: " + str(rex4)
        return 0

    // 5. Opcode reg PUSH R14: W=0, B=1 -> 0x41 (65)
    rex5 = rex_calc_opcode_reg(0, 14)
    if rex5 != 65
        say "FAIL: Expected REX 0x41 (65) for PUSH R14, got: " + str(rex5)
        return 0

    // 6. Byte register SIL (6) requires REX 0x40 (64)
    rex6 = rex_calc_byte_reg(6)
    if rex6 != 64
        say "FAIL: Expected REX 0x40 (64) for SIL byte register, got: " + str(rex6)
        return 0

    return 1

test_rex_prefix_subsystem()
