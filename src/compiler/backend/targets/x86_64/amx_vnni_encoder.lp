// ==============================================================================
// 👑 LIPI INTEL AMX & AVX-512 VNNI MACHINE CODE EMITTER (amx_vnni_encoder.lp)
// ⚡ 100% Pure Lipi | AMD64 Tile & Vector Neural Network Instruction Synthesizer
// ==============================================================================
//
// WHY: Intel AMX (Advanced Matrix Extensions) and AVX-512 VNNI require specialized
// VEX and EVEX machine code prefix byte synthesis.
// LiPi emits raw machine instructions directly into output ELF binaries without
// relying on GNU as, LLVM MC, Clang, or C compiler assemblers.
//
// Opcodes Implemented:
//   1. LDTILECFG   [m512]         Load 64-byte palette config: VEX.LZ.0F38.W0 49 /0
//   2. STTILECFG   [m512]         Store 64-byte palette config: VEX.LZ.0F38.W0 49 /1
//   3. TILERELEASE                Release tile configuration: VEX.LZ.0F38.W0 49 C0
//   4. TDPBUSD     tmm1, tmm2, tmm3  Tile Int8 Matrix Multiply: VEX.128.66.0F38.W0 5C /r
//   5. VPDPBUSD    zmm1, zmm2, zmm3  Vector Neural Dot Product: EVEX.512.66.0F38.W0 50 /r
// ==============================================================================

// ── 1. AMX Tile Configuration Emitters ────────────────────────────────────────

fn x86_synth_emit_amx_tilerelease s
    // WHY: TILERELEASE invalidates all tile registers and returns the processor to
    // the INIT state, preventing OS context save overhead when AMX is inactive.
    // Encoding: VEX.LZ.0F38.W0 49 C0 -> C4 E2 79 49 C0
    bytes = list()
    push(bytes, 196) // 0xC4 (3-byte VEX prefix)
    push(bytes, 226) // 0xE2 (0F38 map)
    push(bytes, 121) // 0x79 (W0, vvvv=1111, L=0, pp=01)
    push(bytes, 73)  // 0x49 (Opcode)
    push(bytes, 192) // 0xC0 (ModR/M: 11 000 000)
    x86_synth_emit_bytes(s, bytes)
    return 5

fn x86_synth_emit_amx_ldtilecfg s base_reg offset
    // WHY: LDTILECFG loads 64-byte tile configuration from memory [base_reg + offset].
    // Encoding: C4 E2 79 49 /0 [ModR/M] [disp]
    bytes = list()
    push(bytes, 196) // 0xC4
    push(bytes, 226) // 0xE2
    push(bytes, 121) // 0x79
    push(bytes, 73)  // 0x49

    // ModR/M with reg=0 (opcode extension /0)
    rm = base_reg % 8
    if offset == 0
        modrm = rm // 00 000 rm
        push(bytes, modrm)
    elif offset >= -128 and offset <= 127
        modrm = 64 | rm // 01 000 rm (disp8)
        push(bytes, modrm)
        disp8 = offset
        if disp8 < 0 disp8 = disp8 + 256 end
        push(bytes, disp8)
    else
        modrm = 128 | rm // 10 000 rm (disp32)
        push(bytes, modrm)
        d = offset
        push(bytes, d % 256)
        push(bytes, (d / 256) % 256)
        push(bytes, (d / 65536) % 256)
        push(bytes, (d / 16777216) % 256)
    end
    x86_synth_emit_bytes(s, bytes)
    return len(bytes)

fn x86_synth_emit_amx_sttilecfg s base_reg offset
    // WHY: STTILECFG stores 64-byte active tile configuration to memory [base_reg + offset].
    // Encoding: C4 E2 79 49 /1 [ModR/M] [disp]
    bytes = list()
    push(bytes, 196) // 0xC4
    push(bytes, 226) // 0xE2
    push(bytes, 121) // 0x79
    push(bytes, 73)  // 0x49

    rm = base_reg % 8
    if offset == 0
        modrm = 8 | rm // 00 001 rm
        push(bytes, modrm)
    elif offset >= -128 and offset <= 127
        modrm = 72 | rm // 01 001 rm
        push(bytes, modrm)
        disp8 = offset
        if disp8 < 0 disp8 = disp8 + 256 end
        push(bytes, disp8)
    else
        modrm = 136 | rm // 10 001 rm
        push(bytes, modrm)
        d = offset
        push(bytes, d % 256)
        push(bytes, (d / 256) % 256)
        push(bytes, (d / 65536) % 256)
        push(bytes, (d / 16777216) % 256)
    end
    x86_synth_emit_bytes(s, bytes)
    return len(bytes)

// ── 2. AMX 2D Tile Matrix Multiplication Emitter (TDPBUSD) ────────────────────

fn x86_synth_emit_amx_tdpbusd s tmm_dst tmm_src1 tmm_src2
    // WHY: TDPBUSD multiplies unsigned byte matrix in tmm_src1 by signed byte matrix
    // in tmm_src2 and accumulates results into 32-bit dwords in tmm_dst.
    // Encoding: VEX.128.66.0F38.W0 5C /r
    // vvvv field in VEX byte 2 encodes ~tmm_src1
    td = tmm_dst % 8
    ts1 = tmm_src1 % 8
    ts2 = tmm_src2 % 8

    vvvv = (15 - ts1) & 15 // Inverted 4-bit register index

    vex2 = (vvvv * 8) | 1 // W=0, vvvv, L=0, pp=01 (66)
    modrm = 192 | (td * 8) | ts2 // 11 td ts2

    bytes = list()
    push(bytes, 196)  // 0xC4
    push(bytes, 226)  // 0xE2 (0F38)
    push(bytes, vex2) // VEX byte 2
    push(bytes, 92)   // 0x5C (TDPBUSD opcode)
    push(bytes, modrm)
    x86_synth_emit_bytes(s, bytes)
    return 5

// ── 3. AVX-512 VNNI Vector Dot Product Emitter (VPDPBUSD) ─────────────────────

fn x86_synth_emit_vnni_vpdpbusd s zmm_dst zmm_src1 zmm_src2
    // WHY: VPDPBUSD computes 4-lane saturated Int8 dot products across 512-bit ZMM registers.
    // Encoding: EVEX.512.66.0F38.W0 50 /r
    zd = zmm_dst % 32
    zs1 = zmm_src1 % 32
    zs2 = zmm_src2 % 32

    bytes = list()
    push(bytes, 98)   // 0x62 (EVEX prefix byte 0)

    // EVEX P1: [R X B R' 0 0 m m] -> ~R, ~X, ~B, ~R', 00, 01 (0F38)
    evex1 = 242 // 0xF2 (Default inverted high bits, 0F38)
    push(bytes, evex1)

    // EVEX P2: [W v v v v 1 p p] -> W=0, ~zs1 (4-bit), 1, pp=01 (66)
    vvvv = (15 - (zs1 % 16)) & 15
    evex2 = (vvvv * 8) | 5 // 0101
    push(bytes, evex2)

    // EVEX P3: [z L' L b V' a a a] -> z=0, L'L=10 (512-bit), b=0, V'=1, aaa=000
    evex3 = 72 // 0x48 (512-bit ZMM vector length)
    push(bytes, evex3)

    push(bytes, 80) // 0x50 (VPDPBUSD opcode)

    modrm = 192 | ((zd % 8) * 8) | (zs2 % 8) // 11 zd zs2
    push(bytes, modrm)

    x86_synth_emit_bytes(s, bytes)
    return 6
