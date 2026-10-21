// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN RISC-V RV64V VECTOR EXTENSION EMITTER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Sovereign Micro-Architecture
// 🏛️ File: src/compiler/backend/targets/riscv64/riscv64_vector.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Synthesizes standard RISC-V Vector ("V" Extension v1.0) machine instructions.
// 2. Operates natively with scalable vector lengths (VLEN), avoiding hardcoded lane traps.
// 3. Implements standard vector unit configuration (vsetvli), contiguous element loads/stores
//    (vle32.v, vse32.v), and vector-vector arithmetic (vadd.vv, vsub.vv, vmul.vv).
// ==============================================================================

// ── 1. Vector Configuration Emitter ──────────────────────────────────────────

fn riscv64_emit_vsetvli s rd rs1 vtypei
    // WHY: Sets vector length (vl) and vector type register (vtype).
    // Opcode pattern: 0x57 | (rd << 7) | (0x7 << 12) | (rs1 << 15) | (vtypei << 20)
    w = 28759 | ((rd & 31) * 128) | ((rs1 & 31) * 32768) | ((vtypei & 2047) * 1048576)
    return riscv64_synth_emit32(s, w)

// ── 2. Vector Memory Operations ──────────────────────────────────────────────

fn riscv64_emit_vle32_v s vd rs1
    // WHY: Emits 'vle32.v vd, (rs1)' (Vector unit-stride load of 32-bit elements).
    // Opcode pattern: 0x07 | (vd << 7) | (0x6 << 12) | (rs1 << 15)
    w = 24583 | ((vd & 31) * 128) | ((rs1 & 31) * 32768)
    return riscv64_synth_emit32(s, w)

fn riscv64_emit_vse32_v s vs3 rs1
    // WHY: Emits 'vse32.v vs3, (rs1)' (Vector unit-stride store of 32-bit elements).
    // Opcode pattern: 0x27 | (vs3 << 7) | (0x6 << 12) | (rs1 << 15)
    w = 24615 | ((vs3 & 31) * 128) | ((rs1 & 31) * 32768)
    return riscv64_synth_emit32(s, w)

// ── 3. Vector Arithmetic Operations ──────────────────────────────────────────

fn riscv64_emit_vadd_vv s vd vs2 vs1
    // WHY: Emits 'vadd.vv vd, vs2, vs1' (Vector-vector addition).
    // Opcode pattern: 0x57 | (vd << 7) | (0x0 << 12) | (vs1 << 15) | (vs2 << 20) | (0x00 << 26)
    w = 87 | ((vd & 31) * 128) | ((vs1 & 31) * 32768) | ((vs2 & 31) * 1048576)
    return riscv64_synth_emit32(s, w)

fn riscv64_emit_vsub_vv s vd vs2 vs1
    // WHY: Emits 'vsub.vv vd, vs2, vs1' (Vector-vector subtraction).
    // Opcode pattern: 0x57 | (vd << 7) | (0x0 << 12) | (vs1 << 15) | (vs2 << 20) | (0x02 << 26)
    w = 87 | ((vd & 31) * 128) | ((vs1 & 31) * 32768) | ((vs2 & 31) * 1048576) | 134217728
    return riscv64_synth_emit32(s, w)

fn riscv64_emit_vmul_vv s vd vs2 vs1
    // WHY: Emits 'vmul.vv vd, vs2, vs1' (Vector-vector multiplication).
    // Opcode pattern: 0x57 | (vd << 7) | (0x2 << 12) | (vs1 << 15) | (vs2 << 20) | (0x25 << 26)
    w = 8279 | ((vd & 31) * 128) | ((vs1 & 31) * 32768) | ((vs2 & 31) * 1048576) | 2483027968
    return riscv64_synth_emit32(s, w)
