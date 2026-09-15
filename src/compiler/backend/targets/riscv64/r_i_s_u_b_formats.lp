// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — RISC-V R/I/S/U/B FORMAT ENCODER (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/riscv64/r_i_s_u_b_formats.lp
//
// WHY THIS MODULE:
// 1. RISC-V instruction encoding uses strictly fixed 32-bit (4-byte) instruction words
//    engineered so register source fields (rs1, rs2) and destination (rd) remain at
//    identical bit positions across all 6 instruction formats:
//    - R-Type: Register-Register arithmetic (ADD, SUB, AND, OR, XOR)
//    - I-Type: Immediate arithmetic, loads, JALR, and system calls (ADDI, LD, ECALL)
//    - S-Type: Memory stores (SD, SW, SH, SB)
//    - B-Type: Conditional branches (BEQ, BNE, BLT, BGE)
//    - U-Type: Upper 20-bit immediates (LUI, AUIPC)
//    - J-Type: Unconditional jumps with link (JAL)
// 2. Hardware Silicon Decoding Efficiency:
//    - Bitfields are unpacked into 4 exact little-endian bytes without requiring any
//      external assembler, producing bare-metal machine code directly.
// ==============================================================================

// ── 1. Byte Stream Unpacker ───────────────────────────────────────────────────

fn rv64_word_to_bytes word
    // WHY: Unpacks 32-bit RISC-V instruction word into 4 little-endian bytes.
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

// ── 2. R-Type Format (Register-Register) ──────────────────────────────────────

fn rv64_encode_r opcode rd funct3 rs1 rs2 funct7
    // WHY: Format: [funct7:7][rs2:5][rs1:5][funct3:3][rd:5][opcode:7]
    op = opcode % 128
    d  = rd % 32
    f3 = funct3 % 8
    s1 = rs1 % 32
    s2 = rs2 % 32
    f7 = funct7 % 128

    word = op + (d * 128) + (f3 * 4096) + (s1 * 32768) + (s2 * 1048576) + (f7 * 33554432)
    return rv64_word_to_bytes(word)

// ── 3. I-Type Format (Immediate / Loads / JALR / ECALL) ──────────────────────

fn rv64_encode_i opcode rd funct3 rs1 imm
    // WHY: Format: [imm[11:0]:12][rs1:5][funct3:3][rd:5][opcode:7]
    op = opcode % 128
    d  = rd % 32
    f3 = funct3 % 8
    s1 = rs1 % 32
    im = imm % 4096
    if im < 0 im = im + 4096

    word = op + (d * 128) + (f3 * 4096) + (s1 * 32768) + (im * 1048576)
    return rv64_word_to_bytes(word)

// ── 4. S-Type Format (Memory Stores) ──────────────────────────────────────────

fn rv64_encode_s opcode funct3 rs1 rs2 imm
    // WHY: Format: [imm[11:5]:7][rs2:5][rs1:5][funct3:3][imm[4:0]:5][opcode:7]
    op = opcode % 128
    f3 = funct3 % 8
    s1 = rs1 % 32
    s2 = rs2 % 32
    im = imm % 4096
    if im < 0 im = im + 4096

    imm_low  = im % 32        // imm[4:0]
    imm_high = (im / 32) % 128 // imm[11:5]

    word = op + (imm_low * 128) + (f3 * 4096) + (s1 * 32768) + (s2 * 1048576) + (imm_high * 33554432)
    return rv64_word_to_bytes(word)

// ── 5. B-Type Format (Conditional Branches) ───────────────────────────────────

fn rv64_encode_b opcode funct3 rs1 rs2 imm
    // WHY: Format: [imm[12|10:5]:7][rs2:5][rs1:5][funct3:3][imm[4:1|11]:5][opcode:7]
    //      imm is multiple of 2 (branch target address displacement).
    op = opcode % 128
    f3 = funct3 % 8
    s1 = rs1 % 32
    s2 = rs2 % 32
    im = imm % 8192
    if im < 0 im = im + 8192

    b_1_4  = (im / 2) % 16      // imm[4:1]
    b_11   = (im / 2048) % 2    // imm[11]
    b_low5 = b_1_4 + (b_11 * 16)

    b_5_10 = (im / 32) % 64     // imm[10:5]
    b_12   = (im / 4096) % 2    // imm[12]
    b_hi7  = b_5_10 + (b_12 * 64)

    word = op + (b_low5 * 128) + (f3 * 4096) + (s1 * 32768) + (s2 * 1048576) + (b_hi7 * 33554432)
    return rv64_word_to_bytes(word)

// ── 6. U-Type Format (Upper Immediate: LUI / AUIPC) ───────────────────────────

fn rv64_encode_u opcode rd imm20
    // WHY: Format: [imm[31:12]:20][rd:5][opcode:7]
    op = opcode % 128
    d  = rd % 32
    im = imm20 % 1048576
    if im < 0 im = im + 1048576

    word = op + (d * 128) + (im * 4096)
    return rv64_word_to_bytes(word)

// ── 7. J-Type Format (Unconditional Jump: JAL) ────────────────────────────────

fn rv64_encode_j opcode rd imm
    // WHY: Format: [imm[20|10:1|11|19:12]:20][rd:5][opcode:7]
    op = opcode % 128
    d  = rd % 32
    im = imm % 2097152
    if im < 0 im = im + 2097152

    j_12_19 = (im / 4096) % 256  // imm[19:12]
    j_11    = (im / 2048) % 2    // imm[11]
    j_1_10  = (im / 2) % 1024    // imm[10:1]
    j_20    = (im / 1048576) % 2 // imm[20]

    scrambled = j_12_19 + (j_11 * 256) + (j_1_10 * 512) + (j_20 * 524288)
    word = op + (d * 128) + (scrambled * 4096)
    return rv64_word_to_bytes(word)

// ── 8. High-Level Canonical Instruction Emitters ──────────────────────────────

fn rv64_emit_add rd rs1 rs2
    // WHY: ADD rd, rs1, rs2 (opcode 0x33, funct3=0, funct7=0)
    return rv64_encode_r(51, rd, 0, rs1, rs2, 0)

fn rv64_emit_sub rd rs1 rs2
    // WHY: SUB rd, rs1, rs2 (opcode 0x33, funct3=0, funct7=0x20 = 32)
    return rv64_encode_r(51, rd, 0, rs1, rs2, 32)

fn rv64_emit_addi rd rs1 imm12
    // WHY: ADDI rd, rs1, imm (opcode 0x13, funct3=0)
    return rv64_encode_i(19, rd, 0, rs1, imm12)

fn rv64_emit_ld rd rs1 offset12
    // WHY: LD rd, offset(rs1) (64-bit load, opcode 0x03, funct3=3)
    return rv64_encode_i(3, rd, 3, rs1, offset12)

fn rv64_emit_sd rs2 rs1 offset12
    // WHY: SD rs2, offset(rs1) (64-bit store, opcode 0x23, funct3=3)
    return rv64_encode_s(35, 3, rs1, rs2, offset12)

fn rv64_emit_ecall
    // WHY: ECALL (Environment Call / Syscall trap: opcode 0x73, funct3=0, imm=0)
    //      Raw word: 0x00000073 -> [0x73, 0x00, 0x00, 0x00]
    return rv64_encode_i(115, 0, 0, 0, 0)

fn rv64_emit_ret
    // WHY: RET (Pseudoinstruction for JALR x0, x1, 0: opcode 0x67, rd=0, rs1=1, funct3=0)
    //      Raw word: 0x00008067 -> [0x67, 0x80, 0x00, 0x00]
    return rv64_encode_i(103, 0, 0, 1, 0)

// ── 9. Verification Self-Test ────────────────────────────────────────────────

fn test_rv64_formats_subsystem
    // 1. Verify ECALL: 0x00000073 -> [0x73, 0x00, 0x00, 0x00] (115, 0, 0, 0)
    ecall_b = rv64_emit_ecall()
    if len(ecall_b) != 4 or get(ecall_b, 0) != 115 or get(ecall_b, 1) != 0 or get(ecall_b, 2) != 0 or get(ecall_b, 3) != 0
        say "FAIL: ECALL encoding mismatch"
        return 0

    // 2. Verify RET: 0x00008067 -> [0x67, 0x80, 0x00, 0x00] (103, 128, 0, 0)
    ret_b = rv64_emit_ret()
    if len(ret_b) != 4 or get(ret_b, 0) != 103 or get(ret_b, 1) != 128 or get(ret_b, 2) != 0 or get(ret_b, 3) != 0
        say "FAIL: RET encoding mismatch"
        return 0

    // 3. Verify ADDI x10, x0, 42 (LI a0, 42)
    // opcode: 0x13(19), rd: 10, rs1: 0, funct3: 0, imm: 42
    // word = 19 + (10 * 128) + (0) + (0) + (42 * 1048576) = 19 + 1280 + 44040192 = 44041491 (0x02A00513)
    // bytes: [0x13, 0x05, 0xA0, 0x02] (19, 5, 160, 2)
    li_b = rv64_emit_addi(10, 0, 42)
    if len(li_b) != 4 or get(li_b, 0) != 19 or get(li_b, 1) != 5 or get(li_b, 2) != 160 or get(li_b, 3) != 2
        say "FAIL: ADDI encoding mismatch"
        return 0

    return 1

// test_rv64_formats_subsystem()
