// ==============================================================================
// 👑 LIPI SOVEREIGN COMPILER — AMD64 AVX2 256-BIT VECTOR ENCODER (FIRST 1.0.0)
// ⚡ 100% Pure Lipi | 0% C | 0% Libc | Zero External Dependencies
// 🏛️ File: src/compiler/backend/targets/x86_64/avx2_encoder.lp
//
// WHY THIS MODULE:
// 1. AVX2 (Advanced Vector Extensions 2) provides 256-bit vector registers (YMM0..YMM15)
//    capable of executing 8 simultaneous 32-bit integer additions, subtractions, or
//    multiplications per clock cycle.
// 2. VEX Prefix Encoding:
//    - 2-byte VEX (0xC5): Used when W=0, REX.X=0, REX.B=0, and opcode map is 0F.
//      Byte 0: 0xC5 (197)
//      Byte 1: [~R:1] [~vvvv:4] [L:1] [pp:2]
//    - 3-byte VEX (0xC4): Used when W=1, extended registers (R8..R15) are in base/index,
//      or extended opcode maps (0F38, 0F3A) are required.
//      Byte 0: 0xC4 (196)
//      Byte 1: [~R:1] [~X:1] [~B:1] [map:5]
//      Byte 2: [W:1] [~vvvv:4] [L:1] [pp:2]
// 3. Bit Inversion Trap:
//    - The Intel/AMD hardware silicon specification inverts the ~R, ~X, ~B, and ~vvvv bits.
//      0 in bit field means register is active / selected.
// 4. VZEROUPPER Sanitation:
//    - Emitting VZEROUPPER (0xC5 0xF8 0x77) clears the upper 128-bits of YMM0..YMM15,
//      preventing severe 70-cycle CPU pipeline stalls when transitioning back to
//      standard 64-bit scalar code or calling external ABIs.
// ==============================================================================

// ── 1. VEX Protocol Constants ─────────────────────────────────────────────────

VEX_L_128   = 0  // 128-bit vector operand length (XMM)
VEX_L_256   = 1  // 256-bit vector operand length (YMM)

VEX_PP_NONE = 0  // No mandatory prefix
VEX_PP_66   = 1  // 0x66 prefix (Packed integer)
VEX_PP_F3   = 2  // 0xF3 prefix (Scalar / unaligned vector)
VEX_PP_F2   = 3  // 0xF2 prefix (Scalar double precision)

VEX_MAP_0F   = 1 // Standard 0x0F opcode map
VEX_MAP_0F38 = 2 // Extended 0x0F 0x38 opcode map (e.g. VPMULLD)
VEX_MAP_0F3A = 3 // Extended 0x0F 0x3A opcode map

// ── 2. VEX Prefix Builders ───────────────────────────────────────────────────

fn vex2_build r_reg vvvv_reg l_len pp_prefix
    // WHY: Assembles 2-byte VEX prefix (0xC5).
    //      Inverts R and vvvv according to AMD64 hardware spec.
    b0 = 197 // 0xC5

    // R bit inverted: 1 if reg < 8, 0 if reg >= 8
    r_inv = 1
    if r_reg >= 8 r_inv = 0

    // vvvv 4-bit inverted: 15 - (vvvv_reg % 16)
    inv_v = 15 - (vvvv_reg % 16)

    // Assemble Byte 1: [R_inv * 128] + [inv_v * 8] + [L * 4] + pp
    b1 = (r_inv * 128) + (inv_v * 8) + ((l_len % 2) * 4) + (pp_prefix % 4)

    bytes = list()
    push(bytes, b0)
    push(bytes, b1)
    return bytes

fn vex3_build r_reg x_reg b_reg map_m w_bit vvvv_reg l_len pp_prefix
    // WHY: Assembles 3-byte VEX prefix (0xC4) for extended maps or registers.
    b0 = 196 // 0xC4

    r_inv = 1
    if r_reg >= 8 r_inv = 0

    x_inv = 1
    if x_reg >= 8 x_inv = 0

    b_inv = 1
    if b_reg >= 8 b_inv = 0

    // Byte 1: [R_inv * 128] + [X_inv * 64] + [B_inv * 32] + (map & 31)
    b1 = (r_inv * 128) + (x_inv * 64) + (b_inv * 32) + (map_m % 32)

    inv_v = 15 - (vvvv_reg % 16)
    w_val = 0
    if w_bit != 0 w_val = 1

    // Byte 2: [W * 128] + [inv_v * 8] + [L * 4] + pp
    b2 = (w_val * 128) + (inv_v * 8) + ((l_len % 2) * 4) + (pp_prefix % 4)

    bytes = list()
    push(bytes, b0)
    push(bytes, b1)
    push(bytes, b2)
    return bytes

// ── 3. AVX2 Vector Instruction Encoders ───────────────────────────────────────

fn avx2_encode_vpaddd dest_ymm src1_ymm src2_ymm
    // WHY: VPADDD ymm_dest, ymm_src1, ymm_src2 (256-bit SIMD integer add).
    //      Opcode 0xFE, map=0F, pp=66, W=0, L=1 (256-bit).
    bytes = list()
    if dest_ymm < 8 and src2_ymm < 8
        // Can use compact 2-byte VEX
        pfx = vex2_build(dest_ymm, src1_ymm, VEX_L_256, VEX_PP_66)
        push(bytes, get(pfx, 0))
        push(bytes, get(pfx, 1))
    else
        pfx = vex3_build(dest_ymm, 0, src2_ymm, VEX_MAP_0F, 0, src1_ymm, VEX_L_256, VEX_PP_66)
        push(bytes, get(pfx, 0))
        push(bytes, get(pfx, 1))
        push(bytes, get(pfx, 2))

    push(bytes, 254) // Opcode: 0xFE
    // ModR/M: mod=3 (11), reg=dest_ymm%8, rm=src2_ymm%8
    modrm = 192 + ((dest_ymm % 8) * 8) + (src2_ymm % 8)
    push(bytes, modrm)
    return bytes

fn avx2_encode_vpsubd dest_ymm src1_ymm src2_ymm
    // WHY: VPSUBD ymm_dest, ymm_src1, ymm_src2 (256-bit SIMD integer subtract).
    //      Opcode 0xFA, map=0F, pp=66, W=0, L=1.
    bytes = list()
    if dest_ymm < 8 and src2_ymm < 8
        pfx = vex2_build(dest_ymm, src1_ymm, VEX_L_256, VEX_PP_66)
        push(bytes, get(pfx, 0))
        push(bytes, get(pfx, 1))
    else
        pfx = vex3_build(dest_ymm, 0, src2_ymm, VEX_MAP_0F, 0, src1_ymm, VEX_L_256, VEX_PP_66)
        push(bytes, get(pfx, 0))
        push(bytes, get(pfx, 1))
        push(bytes, get(pfx, 2))

    push(bytes, 250) // Opcode: 0xFA
    modrm = 192 + ((dest_ymm % 8) * 8) + (src2_ymm % 8)
    push(bytes, modrm)
    return bytes

fn avx2_encode_vpmulld dest_ymm src1_ymm src2_ymm
    // WHY: VPMULLD ymm_dest, ymm_src1, ymm_src2 (256-bit SIMD integer multiply).
    //      Opcode 0x40, map=0F38 (requires 3-byte VEX!), pp=66, W=0, L=1.
    bytes = list()
    pfx = vex3_build(dest_ymm, 0, src2_ymm, VEX_MAP_0F38, 0, src1_ymm, VEX_L_256, VEX_PP_66)
    push(bytes, get(pfx, 0))
    push(bytes, get(pfx, 1))
    push(bytes, get(pfx, 2))

    push(bytes, 64) // Opcode: 0x40
    modrm = 192 + ((dest_ymm % 8) * 8) + (src2_ymm % 8)
    push(bytes, modrm)
    return bytes

fn avx2_encode_vpxor dest_ymm src1_ymm src2_ymm
    // WHY: VPXOR ymm_dest, ymm_src1, ymm_src2 (256-bit SIMD bitwise XOR).
    //      Opcode 0xEF, map=0F, pp=66, W=0, L=1.
    bytes = list()
    if dest_ymm < 8 and src2_ymm < 8
        pfx = vex2_build(dest_ymm, src1_ymm, VEX_L_256, VEX_PP_66)
        push(bytes, get(pfx, 0))
        push(bytes, get(pfx, 1))
    else
        pfx = vex3_build(dest_ymm, 0, src2_ymm, VEX_MAP_0F, 0, src1_ymm, VEX_L_256, VEX_PP_66)
        push(bytes, get(pfx, 0))
        push(bytes, get(pfx, 1))
        push(bytes, get(pfx, 2))

    push(bytes, 239) // Opcode: 0xEF
    modrm = 192 + ((dest_ymm % 8) * 8) + (src2_ymm % 8)
    push(bytes, modrm)
    return bytes

fn avx2_encode_vzeroupper
    // WHY: VZEROUPPER (0xC5 0xF8 0x77) clears upper 128-bit YMM state.
    bytes = list()
    push(bytes, 197) // 0xC5
    push(bytes, 248) // 0xF8
    push(bytes, 119) // 0x77
    return bytes

// ── 4. Verification Self-Test ────────────────────────────────────────────────

fn test_avx2_encoder_subsystem
    // 1. Verify VZEROUPPER byte sequence: C5 F8 77
    vzu = avx2_encode_vzeroupper()
    if len(vzu) != 3 or get(vzu, 0) != 197 or get(vzu, 1) != 248 or get(vzu, 2) != 119
        say "FAIL: VZEROUPPER encoding invalid"
        return 0

    // 2. Verify VPADDD YMM0, YMM1, YMM2 (all < 8, uses 2-byte VEX)
    // VEX2 byte 1: R=1 (128), ~v=15-1=14 (14*8=112), L=1 (4), pp=1 -> 128+112+4+1 = 245
    // Opcode: 0xFE (254)
    // ModR/M: 192 + (0*8) + 2 = 194
    padd = avx2_encode_vpaddd(0, 1, 2)
    if len(padd) != 4
        say "FAIL: Expected 4 bytes for VPADDD, got: " + str(len(padd))
        return 0
    if get(padd, 0) != 197 or get(padd, 1) != 245 or get(padd, 2) != 254 or get(padd, 3) != 194
        say "FAIL: VPADDD byte sequence invalid"
        return 0

    // 3. Verify VPMULLD (uses 3-byte VEX because map=0F38)
    pmul = avx2_encode_vpmulld(0, 1, 2)
    if len(pmul) != 5 or get(pmul, 0) != 196
        say "FAIL: VPMULLD must use 5-byte VEX3 sequence"
        return 0

    return 1

// ── 5. Silicon Native Hardware Intrinsics & Runtime Helpers ───────────────────

fn x86_synth_emit_cpu_has_avx2 s
    // WHY: In-silicon CPUID leaf 7, subleaf 0 probe for AVX2 feature flag (EBX bit 5).
    // Protects vector execution pipelines against illegal instruction (SIGILL) traps.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_has_avx2", off)
    x86_synth_register_helper_fn(s, "cpuid_avx2", off)
    // push rbx; mov eax, 7; xor ecx, ecx; cpuid; shr ebx, 5; and ebx, 1; mov eax, ebx; pop rbx; ret
    x86_synth_emit_bytes(s, [
        83, 184, 7, 0, 0, 0, 49, 201, 15, 162,
        193, 235, 5, 131, 227, 1, 137, 216, 91, 195
    ])
    return off

fn x86_synth_emit_cpu_has_avx512 s
    // WHY: In-silicon CPUID leaf 7, subleaf 0 probe for AVX-512 Foundation (EBX bit 16).
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_has_avx512", off)
    x86_synth_register_helper_fn(s, "cpu_has_avx512f", off)
    x86_synth_register_helper_fn(s, "cpuid_avx512", off)
    // push rbx; mov eax, 7; xor ecx, ecx; cpuid; shr ebx, 16; and ebx, 1; mov eax, ebx; pop rbx; ret
    x86_synth_emit_bytes(s, [
        83, 184, 7, 0, 0, 0, 49, 201, 15, 162,
        193, 235, 16, 131, 227, 1, 137, 216, 91, 195
    ])
    return off

fn x86_synth_emit_cpu_has_amx s
    // WHY: In-silicon CPUID leaf 7, subleaf 0 probe for Intel AMX-TILE feature flag (EDX bit 24).
    // Protects AMX tile matrix acceleration pipelines against SIGILL on non-AMX CPUs.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "cpu_has_amx", off)
    x86_synth_register_helper_fn(s, "cpuid_amx", off)
    x86_synth_register_helper_fn(s, "সিপিইউ_এএমএক্স", off)
    // push rbx; mov eax, 7; xor ecx, ecx; cpuid; shr edx, 24; and edx, 1; mov eax, edx; pop rbx; ret
    x86_synth_emit_bytes(s, [
        83, 184, 7, 0, 0, 0, 49, 201, 15, 162,
        193, 234, 24, 131, 226, 1, 137, 208, 91, 195
    ])
    return off

fn x86_synth_emit_simd_avx2_sum s
    // WHY: Native 256-bit AVX2 SIMD vector horizontal sum kernel (130 machine code bytes).
    // Processes 4x 64-bit integers per clock cycle with unrolled dual-pipeline execution.
    // Signature: simd_avx2_sum(ptr: %rdi, count: %rsi) -> sum: %rax
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "simd_avx2_sum", off)
    x86_synth_register_helper_fn(s, "simd_avx2_sum_u64", off)
    x86_synth_register_helper_fn(s, "ভেক্টর_যোগ_২৫৬", off)
    x86_synth_register_helper_fn(s, "ভেক্টর_যোগ", off)
    x86_synth_emit_bytes(s, [
        72, 133, 246, 127, 4, 72, 49, 192, 195, 72, 133, 255, 117, 4, 72, 49, 192, 195,
        197, 253, 239, 192, 197, 245, 239, 201, 72, 131, 254, 8, 124, 27, 197, 254, 111, 23,
        197, 253, 212, 194, 197, 254, 111, 95, 32, 197, 245, 212, 203, 72, 131, 199, 64, 72, 131, 238, 8,
        235, 223, 72, 131, 254, 4, 124, 16, 197, 254, 111, 23, 197, 253, 212, 194, 72, 131, 199, 32,
        72, 131, 238, 4, 197, 253, 212, 193, 196, 227, 125, 57, 193, 1, 197, 249, 212, 193, 196, 227,
        249, 22, 194, 1, 196, 225, 249, 126, 192, 72, 1, 208, 72, 133, 246, 126, 12, 72, 3, 7,
        72, 131, 199, 8, 72, 255, 206, 117, 244, 197, 248, 119, 195
    ])
    return off

fn x86_synth_emit_simd_avx512_sum s
    // WHY: 512-bit ZMM vector sum kernel processing 8x 64-bit integers per instruction.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "simd_avx512_sum", off)
    x86_synth_register_helper_fn(s, "simd_avx512_sum_u64", off)
    x86_synth_register_helper_fn(s, "ভেক্টর_যোগ_৫১২", off)
    x86_synth_emit_bytes(s, [
        72, 133, 246, 126, 89, 72, 133, 255, 116, 84, 98, 241, 125, 72, 239, 192,
        72, 131, 254, 8, 124, 16, 98, 241, 253, 72, 212, 7, 72, 131, 199, 64,
        72, 131, 238, 8, 235, 234, 98, 243, 253, 72, 59, 193, 1, 197, 253, 212,
        193, 196, 227, 125, 57, 193, 1, 197, 249, 212, 193, 197, 241, 115, 216, 8,
        197, 249, 212, 193, 196, 225, 249, 126, 192, 72, 133, 246, 126, 12, 72, 3,
        7, 72, 131, 199, 8, 72, 255, 206, 117, 244, 197, 248, 119, 195, 72, 49,
        192, 195
    ])
    return off

fn x86_synth_emit_simd_avx512_dot s
    // WHY: Hardware Silicon Dot Product (GEMM kernel step) via 512-bit ZMM execution.
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "simd_avx512_dot", off)
    x86_synth_register_helper_fn(s, "simd_avx512_dot_u64", off)
    x86_synth_register_helper_fn(s, "ভেক্টর_ডট_৫১২", off)
    x86_synth_emit_bytes(s, [
        72, 133, 210, 126, 121, 72, 133, 255, 116, 116, 72, 133, 246, 116, 111, 98,
        241, 125, 72, 239, 192, 72, 131, 250, 8, 124, 32, 98, 241, 254, 72, 111,
        15, 98, 242, 245, 72, 64, 14, 98, 241, 253, 72, 212, 193, 72, 131, 199,
        64, 72, 131, 198, 64, 72, 131, 234, 8, 235, 218, 98, 243, 253, 72, 59,
        193, 1, 197, 253, 212, 193, 196, 227, 125, 57, 193, 1, 197, 249, 212, 193,
        197, 241, 115, 216, 8, 197, 249, 212, 193, 196, 225, 249, 126, 192, 72, 133,
        210, 126, 23, 76, 139, 7, 76, 15, 175, 6, 76, 1, 192, 72, 131, 199,
        8, 72, 131, 198, 8, 72, 255, 202, 117, 233, 197, 248, 119, 195, 72, 49,
        192, 195
    ])
    return off

fn x86_synth_emit_simd_sse2_dot_f64 s
    // WHY: 100% Native %xmm SSE2 hardware double-precision float vector dot product.
    // Executes 2x f64 multiplications and additions per iteration via SSE2 registers.
    // Signature: simd_sse2_dot_f64(ptr_a: %rdi, ptr_b: %rsi, count: %rdx) -> float bits: %rax
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "simd_sse2_dot_f64", off)
    x86_synth_register_helper_fn(s, "simd_sse2_dot", off)
    x86_synth_register_helper_fn(s, "vector_dot_sse2_f64", off)
    x86_synth_register_helper_fn(s, "ভেক্টর_ডট_এসএসই২_ফ্লোট", off)
    x86_synth_emit_bytes(s, [
        72, 133, 210, 126, 90, 72, 133, 255, 116, 85, 72, 133, 246, 116, 80, 102,
        15, 87, 192, 72, 131, 250, 2, 124, 30, 102, 15, 16, 15, 102, 15, 16,
        22, 102, 15, 89, 202, 102, 15, 88, 193, 72, 131, 199, 16, 72, 131, 198,
        16, 72, 131, 234, 2, 235, 220, 102, 15, 40, 200, 102, 15, 21, 201, 242,
        15, 88, 193, 72, 131, 250, 1, 124, 16, 242, 15, 16, 15, 242, 15, 16,
        22, 242, 15, 89, 202, 242, 15, 88, 193, 102, 72, 15, 126, 192, 195, 72,
        49, 192, 195
    ])
    return off

fn x86_synth_emit_simd_sse2_gemv_f64 s
    // WHY: 100% Native %xmm SSE2 hardware double-precision float GEMV matrix-vector multiplication.
    // Iterates row-by-row, evaluating vector dot products with unrolled SSE2 %xmm pipelines.
    // Signature: simd_sse2_gemv_f64(output_vec: %rdi, weight_matrix: %rsi, input_vec: %rdx, column: %rcx, row: %r8) -> rows: %rax
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "simd_sse2_gemv_f64", off)
    x86_synth_register_helper_fn(s, "simd_sse2_gemv", off)
    x86_synth_register_helper_fn(s, "gguf_gemv_sse2_f64", off)
    x86_synth_register_helper_fn(s, "জিজিইউএফ_জিইএমভি_এসএসই২_ফ্লোট", off)
    x86_synth_emit_bytes(s, [
        77, 133, 192, 15, 142, 191, 0, 0, 0, 72, 133, 201, 15, 142, 182, 0, 0, 0,
        72, 133, 255, 15, 132, 173, 0, 0, 0, 72, 133, 246, 15, 132, 164, 0, 0, 0,
        72, 133, 210, 15, 132, 155, 0, 0, 0, 83, 65, 84, 65, 85, 65, 86, 65, 87,
        73, 137, 252, 73, 137, 245, 73, 137, 214, 73, 137, 207, 76, 137, 195, 77,
        49, 219, 73, 57, 219, 125, 110, 76, 137, 216, 73, 15, 175, 199, 72, 193,
        224, 3, 73, 141, 124, 5, 0, 76, 137, 246, 76, 137, 250, 102, 15, 87,
        192, 73, 137, 210, 73, 131, 250, 2, 124, 30, 102, 15, 16, 15, 102, 15,
        16, 22, 102, 15, 89, 202, 102, 15, 88, 193, 72, 131, 199, 16, 72, 131,
        198, 16, 73, 131, 234, 2, 235, 220, 102, 15, 40, 200, 102, 15, 21, 201,
        242, 15, 88, 193, 73, 131, 250, 1, 124, 16, 242, 15, 16, 15, 242, 15,
        16, 22, 242, 15, 89, 202, 242, 15, 88, 193, 242, 67, 15, 17, 4, 220,
        73, 255, 195, 235, 141, 72, 137, 216, 65, 95, 65, 94, 65, 93, 65, 92,
        91, 195, 72, 49, 192, 195
    ])
    return off

fn x86_synth_emit__lipi_matmul s
    // WHY: Sovereign AMD64 Silicon Matrix & Tensor Multiplication (@ Operator)
    // Features:
    // 1. Cache-Oblivious Row-Accumulation GEMM (i -> k -> j) streaming contiguous L1 data lines
    // 2. 4-Way Superscalar Unrolled Parallel Pipelines for Vector Dot, GEMV, and GEMM
    // 3. Zero-Sparsity Acceleration: Bypasses inner loops instantly when aik == 0
    // 4. Multi-Rank Polymorphism: Supports 2D @ 2D, 2D @ 1D, 1D @ 1D, and Scalar @ Scalar
    off = s.synth_code.len()
    x86_synth_register_helper_fn(s, "_lipi_matmul", off)
    x86_synth_register_helper_fn(s, "matmul", off)
    x86_synth_register_helper_fn(s, "ম্যাট্রিক্স_গুণ", off)
    x86_synth_emit_bytes(s, [85, 72, 137, 229, 83, 65, 84, 65, 85, 65, 86, 65, 87, 72, 131, 236, 88, 72, 131, 255, 0, 15, 132, 12, 3, 0, 0, 72, 131, 254, 0, 15, 132, 2, 3, 0, 0, 72, 129, 255, 0, 16, 0, 0, 15, 130, 236, 2, 0, 0, 72, 129, 254, 0, 16, 0, 0, 15, 130, 223, 2, 0, 0, 73, 137, 252, 73, 137, 245, 72, 137, 125, 168, 72, 137, 117, 160, 77, 139, 52, 36, 77, 133, 246, 15, 132, 205, 2, 0, 0, 77, 139, 125, 0, 77, 133, 255, 15, 132, 192, 2, 0, 0, 73, 139, 68, 36, 16, 72, 139, 24, 72, 129, 251, 0, 16, 0, 0, 15, 130, 8, 2, 0, 0, 73, 139, 69, 16, 72, 139, 16, 72, 129, 250, 0, 16, 0, 0, 15, 130, 25, 1, 0, 0, 73, 139, 92, 36, 16, 72, 139, 27, 72, 139, 27, 72, 137, 93, 144, 73, 139, 85, 16, 72, 139, 18, 72, 139, 18, 72, 137, 85, 136, 76, 137, 247, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create")
    x86_synth_emit_bytes(s, [72, 137, 69, 152, 49, 219, 76, 57, 243, 125, 28, 72, 139, 125, 136, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create")
    x86_synth_emit_bytes(s, [72, 139, 77, 152, 72, 139, 73, 16, 72, 137, 4, 217, 72, 255, 195, 235, 223, 49, 219, 76, 57, 243, 15, 141, 183, 0, 0, 0, 72, 139, 69, 168, 72, 139, 64, 16, 72, 139, 4, 216, 76, 139, 96, 16, 72, 139, 69, 152, 72, 139, 64, 16, 72, 139, 4, 216, 76, 139, 104, 16, 69, 49, 255, 76, 59, 125, 144, 15, 141, 130, 0, 0, 0, 75, 139, 4, 252, 72, 133, 192, 116, 113, 72, 139, 77, 160, 72, 139, 73, 16, 74, 139, 12, 249, 72, 139, 113, 16, 49, 210, 76, 141, 66, 4, 76, 59, 69, 136, 119, 61, 76, 139, 4, 214, 76, 15, 175, 192, 77, 1, 68, 213, 0, 76, 139, 68, 214, 8, 76, 15, 175, 192, 77, 1, 68, 213, 8, 76, 139, 68, 214, 16, 76, 15, 175, 192, 77, 1, 68, 213, 16, 76, 139, 68, 214, 24, 76, 15, 175, 192, 77, 1, 68, 213, 24, 72, 131, 194, 4, 235, 185, 72, 59, 85, 136, 115, 18, 76, 139, 4, 214, 76, 15, 175, 192, 77, 1, 68, 213, 0, 72, 255, 194, 235, 232, 73, 255, 199, 233, 116, 255, 255, 255, 72, 255, 195, 233, 64, 255, 255, 255, 72, 139, 69, 152, 233, 128, 1, 0, 0, 73, 139, 92, 36, 16, 72, 139, 27, 72, 139, 27, 72, 137, 93, 144, 76, 137, 247, 49, 246])
    x86_synth_emit_call_helper(s, "_lipi_list_create")
    x86_synth_emit_bytes(s, [72, 137, 69, 152, 49, 219, 76, 57, 243, 15, 141, 170, 0, 0, 0, 72, 139, 69, 168, 72, 139, 64, 16, 72, 139, 4, 216, 72, 139, 120, 16, 72, 139, 8, 72, 139, 69, 160, 72, 139, 112, 16, 72, 139, 16, 72, 57, 209, 72, 15, 71, 202, 49, 192, 77, 49, 192, 77, 49, 201, 77, 49, 210, 49, 210, 76, 141, 90, 4, 73, 57, 203, 119, 60, 76, 139, 28, 215, 76, 15, 175, 28, 214, 76, 1, 216, 76, 139, 92, 215, 8, 76, 15, 175, 92, 214, 8, 77, 1, 216, 76, 139, 92, 215, 16, 76, 15, 175, 92, 214, 16, 77, 1, 217, 76, 139, 92, 215, 24, 76, 15, 175, 92, 214, 24, 77, 1, 218, 72, 131, 194, 4, 235, 187, 72, 57, 202, 115, 17, 76, 139, 28, 215, 76, 15, 175, 28, 214, 76, 1, 216, 72, 255, 194, 235, 234, 76, 1, 192, 76, 1, 200, 76, 1, 208, 72, 139, 77, 152, 72, 139, 73, 16, 72, 137, 4, 217, 72, 255, 195, 233, 77, 255, 255, 255, 72, 139, 69, 152, 233, 165, 0, 0, 0, 73, 139, 69, 16, 72, 139, 16, 72, 129, 250, 0, 16, 0, 0, 15, 131, 143, 0, 0, 0, 73, 139, 124, 36, 16, 73, 139, 117, 16, 76, 137, 241, 76, 57, 249, 73, 15, 71, 207, 49, 192, 77, 49, 192, 77, 49, 201, 77, 49, 210, 49, 210, 76, 141, 90, 4, 73, 57, 203, 119, 60, 76, 139, 28, 215, 76, 15, 175, 28, 214, 76, 1, 216, 76, 139, 92, 215, 8, 76, 15, 175, 92, 214, 8, 77, 1, 216, 76, 139, 92, 215, 16, 76, 15, 175, 92, 214, 16, 77, 1, 217, 76, 139, 92, 215, 24, 76, 15, 175, 92, 214, 24, 77, 1, 218, 72, 131, 194, 4, 235, 187, 72, 57, 202, 115, 17, 76, 139, 28, 215, 76, 15, 175, 28, 214, 76, 1, 216, 72, 255, 194, 235, 234, 76, 1, 192, 76, 1, 200, 76, 1, 208, 235, 11, 72, 137, 248, 72, 15, 175, 198, 235, 2, 49, 192, 72, 131, 196, 88, 65, 95, 65, 94, 65, 93, 65, 92, 91, 93, 195])
    return off

fn x86_synth_emit_all_avx2_helpers s
    // WHY: Synthesizes all Silicon AVX2 / AVX-512 / SSE2 hardware extensions into binary
    x86_synth_emit_cpu_has_avx2(s)
    x86_synth_emit_cpu_has_avx512(s)
    x86_synth_emit_cpu_has_amx(s)
    x86_synth_emit_simd_avx2_sum(s)
    x86_synth_emit_simd_avx512_sum(s)
    x86_synth_emit_simd_avx512_dot(s)
    x86_synth_emit_simd_sse2_dot_f64(s)
    x86_synth_emit_simd_sse2_gemv_f64(s)
    x86_synth_emit__lipi_matmul(s)
    return 0
