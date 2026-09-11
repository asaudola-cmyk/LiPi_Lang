// ==============================================================================
// 👑 LIPI SOVEREIGN AVX2 (256-BIT SIMD) SILICON MACHINE CODE ENGINE
// ⚡ 100% Pure Lipi | 0% C | 0% GCC | 0% LLVM | Zero External Dependencies
// 🏛️ File: src/compiler/backend/x86_64/avx2.lp
//
// WHY: Modern CPUs provide 256-bit vector registers (YMM0 - YMM15) capable of
//      executing 8x 32-bit integer or 4x 64-bit float operations per single
//      clock cycle. By synthesizing direct VEX-prefixed (0xC5 / 0xC4) machine code
//      at byte-level, Lipi achieves hyper-scale throughput in loops, matrix GEMM,
//      and cryptography without any external assembler or LLVM dependency.
// ==============================================================================

// ── VEX Constants ─────────────────────────────────────────────────────────────
VEX_L_128 = 0  // 128-bit vector length (XMM)
VEX_L_256 = 1  // 256-bit vector length (YMM)

VEX_PP_NONE = 0  // No prefix (None)
VEX_PP_66   = 1  // 0x66 prefix (Packed integer / double precision)
VEX_PP_F3   = 2  // 0xF3 prefix (Scalar / unaligned vector)
VEX_PP_F2   = 3  // 0xF2 prefix (Scalar double)

VEX_MAP_0F   = 1 // 0x0F opcode map
VEX_MAP_0F38 = 2 // 0x0F 0x38 opcode map
VEX_MAP_0F3A = 3 // 0x0F 0x3A opcode map

// ── 1. VEX 2-Byte Prefix Builder (0xC5) ────────────────────────────────────────
// WHY: When REX.X=0, REX.B=0, W=0 and map=0F, AMD64 encodes VEX in a compact 2-byte form.
// Format:
//   Byte 0: 0xC5 (197)
//   Byte 1: [R:1][vvvv:4][L:1][pp:2]
// Note: R and vvvv bits are inverted in Intel/AMD VEX specification.
fn avx2_build_vex2 r_inv vvvv_reg l_len pp_prefix
    b0 = 197 // 0xC5
    // Invert R bit (1 = R0-R7, 0 = R8-R15)
    r_bit = 1
    if r_inv == 0
        r_bit = 0
    // Invert vvvv (4 bits: 15 - reg)
    inv_v = 15 - (vvvv_reg % 16)
    // Assemble byte 1: [R * 128] + [inv_v * 8] + [L * 4] + pp
    b1 = (r_bit * 128) + (inv_v * 8) + ((l_len % 2) * 4) + (pp_prefix % 4)
    res = list()
    push(res, b0)
    push(res, b1)
    return res

// ── 2. VEX 3-Byte Prefix Builder (0xC4) ────────────────────────────────────────
// WHY: Used when W=1, REX.X/B are needed, or extended opcode maps (0F38/0F3A) are accessed.
// Format:
//   Byte 0: 0xC4 (196)
//   Byte 1: [R:1][X:1][B:1][map_select:5]
//   Byte 2: [W:1][vvvv:4][L:1][pp:2]
fn avx2_build_vex3 r_inv x_inv b_inv map_m w_bit vvvv_reg l_len pp_prefix
    b0 = 196 // 0xC4
    r_bit = 1
    if r_inv == 0 r_bit = 0
    x_bit = 1
    if x_inv == 0 x_bit = 0
    b_bit = 1
    if b_inv == 0 b_bit = 0
    b1 = (r_bit * 128) + (x_bit * 64) + (b_bit * 32) + (map_m % 32)

    inv_v = 15 - (vvvv_reg % 16)
    w_flag = 0
    if w_bit == 1 w_flag = 1
    b2 = (w_flag * 128) + (inv_v * 8) + ((l_len % 2) * 4) + (pp_prefix % 4)

    res = list()
    push(res, b0)
    push(res, b1)
    push(res, b2)
    return res

// ── 3. ModR/M & SIB Register-Direct Encoders ──────────────────────────────────
// WHY: Register-direct mode sets mod = 11b (192), reg = dst, r/m = src2.
fn avx2_encode_modrm_rr dst_reg src2_reg
    return 192 + ((dst_reg % 8) * 8) + (src2_reg % 8)

// WHY: ModR/M with displacement for memory operands [base + disp32]
fn avx2_encode_modrm_mem reg_id base_reg disp
    mod = 128 // 10b for 32-bit displacement
    if disp == 0 and (base_reg % 8) != 5
        mod = 0   // 00b for no displacement
    elif disp >= -128 and disp <= 127
        mod = 64  // 01b for 8-bit displacement
    return mod + ((reg_id % 8) * 8) + (base_reg % 8)

// ── 4. Generic 3-Operand Register-to-Register Instruction Emitter ──────────────
// WHY: Emits: mnemonic dst_ymm, src1_ymm, src2_ymm
// Automatically selects 2-byte VEX when possible, else 3-byte VEX.
fn avx2_emit_rr mnemonic opcode pp map_m w_bit dst_ymm src1_ymm src2_ymm
    bytes = list()
    r_inv = 1
    if dst_ymm >= 8 r_inv = 0
    b_inv = 1
    if src2_ymm >= 8 b_inv = 0

    // Can use 2-byte VEX if map=0F, w=0, and b_inv=1
    if map_m == VEX_MAP_0F and w_bit == 0 and b_inv == 1
        p = avx2_build_vex2(r_inv, src1_ymm, VEX_L_256, pp)
        push(bytes, get(p, 0))
        push(bytes, get(p, 1))
    else
        p = avx2_build_vex3(r_inv, 1, b_inv, map_m, w_bit, src1_ymm, VEX_L_256, pp)
        push(bytes, get(p, 0))
        push(bytes, get(p, 1))
        push(bytes, get(p, 2))

    push(bytes, opcode)
    modrm = avx2_encode_modrm_rr(dst_ymm, src2_ymm)
    push(bytes, modrm)
    return bytes

// ── 5. Concrete AVX2 256-Bit Vector Instructions ──────────────────────────────

// VPADDD: 256-bit Vector Addition of 8x 32-bit Integers (VEX.256.66.0F.WIG FE /r)
// WHY: Computes 8 integer additions in parallel in 1 CPU cycle
fn avx2_vpaddd dst_ymm src1_ymm src2_ymm
    return avx2_emit_rr("vpaddd", 254, VEX_PP_66, VEX_MAP_0F, 0, dst_ymm, src1_ymm, src2_ymm)

// VPADDQ: 256-bit Vector Addition of 4x 64-bit Integers (VEX.256.66.0F.WIG D4 /r)
// WHY: Computes 4 64-bit pointer/integer additions in parallel
fn avx2_vpaddq dst_ymm src1_ymm src2_ymm
    return avx2_emit_rr("vpaddq", 212, VEX_PP_66, VEX_MAP_0F, 0, dst_ymm, src1_ymm, src2_ymm)

// VPSUBD: 256-bit Vector Subtraction of 8x 32-bit Integers (VEX.256.66.0F.WIG FA /r)
fn avx2_vpsubd dst_ymm src1_ymm src2_ymm
    return avx2_emit_rr("vpsubd", 250, VEX_PP_66, VEX_MAP_0F, 0, dst_ymm, src1_ymm, src2_ymm)

// VPSUBQ: 256-bit Vector Subtraction of 4x 64-bit Integers (VEX.256.66.0F.WIG FB /r)
fn avx2_vpsubq dst_ymm src1_ymm src2_ymm
    return avx2_emit_rr("vpsubq", 251, VEX_PP_66, VEX_MAP_0F, 0, dst_ymm, src1_ymm, src2_ymm)

// VPMULLD: 256-bit Vector Multiplication of 8x 32-bit Integers (VEX.256.66.0F38.WIG 40 /r)
// WHY: High-throughput element-wise integer multiplication for tensor GEMM
fn avx2_vpmulld dst_ymm src1_ymm src2_ymm
    return avx2_emit_rr("vpmulld", 64, VEX_PP_66, VEX_MAP_0F38, 0, dst_ymm, src1_ymm, src2_ymm)

// VADDPD: 256-bit Vector Addition of 4x 64-bit Float Doubles (VEX.256.66.0F.WIG 58 /r)
fn avx2_vaddpd dst_ymm src1_ymm src2_ymm
    return avx2_emit_rr("vaddpd", 88, VEX_PP_66, VEX_MAP_0F, 0, dst_ymm, src1_ymm, src2_ymm)

// VMULPD: 256-bit Vector Multiplication of 4x 64-bit Float Doubles (VEX.256.66.0F.WIG 59 /r)
fn avx2_vmulpd dst_ymm src1_ymm src2_ymm
    return avx2_emit_rr("vmulpd", 89, VEX_PP_66, VEX_MAP_0F, 0, dst_ymm, src1_ymm, src2_ymm)

// VPXOR: 256-bit Vector Bitwise XOR (VEX.256.66.0F.WIG EF /r)
// WHY: Used to zero out YMM registers: vpxor ymm0, ymm0, ymm0
fn avx2_vpxor dst_ymm src1_ymm src2_ymm
    return avx2_emit_rr("vpxor", 239, VEX_PP_66, VEX_MAP_0F, 0, dst_ymm, src1_ymm, src2_ymm)

// ── 6. Memory Load and Store Operations (VMOVDQU) ─────────────────────────────

// VMOVDQU Load: 256-bit Unaligned Memory Load into YMM (VEX.256.F3.0F.WIG 6F /r)
// Syntax: vmovdqu ymm_dst, [base_reg + disp]
fn avx2_vmovdqu_load dst_ymm base_reg disp
    bytes = list()
    r_inv = 1
    if dst_ymm >= 8 r_inv = 0
    b_inv = 1
    if base_reg >= 8 b_inv = 0

    if b_inv == 1
        p = avx2_build_vex2(r_inv, 0, VEX_L_256, VEX_PP_F3)
        push(bytes, get(p, 0))
        push(bytes, get(p, 1))
    else
        p = avx2_build_vex3(r_inv, 1, b_inv, VEX_MAP_0F, 0, 0, VEX_L_256, VEX_PP_F3)
        push(bytes, get(p, 0))
        push(bytes, get(p, 1))
        push(bytes, get(p, 2))

    push(bytes, 111) // 0x6F
    modrm = avx2_encode_modrm_mem(dst_ymm, base_reg, disp)
    push(bytes, modrm)

    // Append displacement bytes
    if disp >= -128 and disp <= 127 and disp != 0
        push(bytes, disp % 256)
    elif disp != 0
        push(bytes, disp % 256)
        push(bytes, (disp / 256) % 256)
        push(bytes, (disp / 65536) % 256)
        push(bytes, (disp / 16777216) % 256)

    return bytes

// VMOVDQU Store: 256-bit Unaligned Store from YMM to Memory (VEX.256.F3.0F.WIG 7F /r)
// Syntax: vmovdqu [base_reg + disp], ymm_src
fn avx2_vmovdqu_store base_reg disp src_ymm
    bytes = list()
    r_inv = 1
    if src_ymm >= 8 r_inv = 0
    b_inv = 1
    if base_reg >= 8 b_inv = 0

    if b_inv == 1
        p = avx2_build_vex2(r_inv, 0, VEX_L_256, VEX_PP_F3)
        push(bytes, get(p, 0))
        push(bytes, get(p, 1))
    else
        p = avx2_build_vex3(r_inv, 1, b_inv, VEX_MAP_0F, 0, 0, VEX_L_256, VEX_PP_F3)
        push(bytes, get(p, 0))
        push(bytes, get(p, 1))
        push(bytes, get(p, 2))

    push(bytes, 127) // 0x7F
    modrm = avx2_encode_modrm_mem(src_ymm, base_reg, disp)
    push(bytes, modrm)

    if disp >= -128 and disp <= 127 and disp != 0
        push(bytes, disp % 256)
    elif disp != 0
        push(bytes, disp % 256)
        push(bytes, (disp / 256) % 256)
        push(bytes, (disp / 65536) % 256)
        push(bytes, (disp / 16777216) % 256)

    return bytes

// ── 7. Disassembly & Verification Helper ──────────────────────────────────────
fn avx2_bytes_to_hex byte_list
    hex_chars = "0123456789abcdef"
    out = ""
    i = 0
    blen = len(byte_list)
    while i < blen
        b = get(byte_list, i)
        hi = char_at(hex_chars, (b / 16) % 16)
        lo = char_at(hex_chars, b % 16)
        out = out + hi + lo + " "
        i = i + 1
    return out
