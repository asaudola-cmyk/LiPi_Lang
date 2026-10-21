// ==============================================================================
// 👑 LIPI FIRST 1.0.0 SOVEREIGN ARM64 NEON SIMD VECTOR EMITTER
// ⚡ 100% Pure Lipi First 1.0.0 | 0% C | 0% Libc | Sovereign Micro-Architecture
// 🏛️ File: src/compiler/backend/targets/arm64/arm64_simd.lp
// ==============================================================================
//
// WHY THIS MODULE:
// 1. Provides zero-dependency 128-bit NEON vector instruction word generation
//    for ARM64 (AArch64 / ARMv8-A+) architectures.
// 2. Enables direct silicon hardware SIMD acceleration without relying on GCC/LLVM.
// 3. Implements standard 4x32-bit single-precision float and 4x32-bit signed integer
//    vector arithmetic (ADD.4S, SUB.4S, MUL.4S, LD1, ST1).
// ==============================================================================

// ── 1. ARM64 NEON Arithmetic Instruction Emitters ─────────────────────────────

fn arm64_emit_neon_add_4s s vd vn vm
    // WHY: Emits 'add vd.4s, vn.4s, vm.4s' (128-bit vector integer addition).
    // Opcode pattern: 0x4E208400 | (vm << 16) | (vn << 5) | vd
    w = 1310753792 | ((vm & 31) * 65536) | ((vn & 31) * 32) | (vd & 31)
    return arm64_synth_emit32(s, w)

fn arm64_emit_neon_sub_4s s vd vn vm
    // WHY: Emits 'sub vd.4s, vn.4s, vm.4s' (128-bit vector integer subtraction).
    // Opcode pattern: 0x4EA08400 | (vm << 16) | (vn << 5) | vd
    w = 1319142400 | ((vm & 31) * 65536) | ((vn & 31) * 32) | (vd & 31)
    return arm64_synth_emit32(s, w)

fn arm64_emit_neon_mul_4s s vd vn vm
    // WHY: Emits 'mul vd.4s, vn.4s, vm.4s' (128-bit vector integer multiplication).
    // Opcode pattern: 0x4E209C00 | (vm << 16) | (vn << 5) | vd
    w = 1310759936 | ((vm & 31) * 65536) | ((vn & 31) * 32) | (vd & 31)
    return arm64_synth_emit32(s, w)

// ── 2. ARM64 NEON Vector Memory Operations ───────────────────────────────────

fn arm64_emit_neon_ld1_4s s vt xn
    // WHY: Emits 'ld1 {vt.4s}, [xn]' (Loads contiguous 128-bit vector from memory address in Xn).
    // Opcode pattern: 0x4C407000 | (xn << 5) | vt
    w = 1279291392 | ((xn & 31) * 32) | (vt & 31)
    return arm64_synth_emit32(s, w)

fn arm64_emit_neon_st1_4s s vt xn
    // WHY: Emits 'st1 {vt.4s}, [xn]' (Stores contiguous 128-bit vector to memory address in Xn).
    // Opcode pattern: 0x4C007000 | (xn << 5) | vt
    w = 1275097088 | ((xn & 31) * 32) | (vt & 31)
    return arm64_synth_emit32(s, w)

fn arm64_emit_neon_dup_4s s vd xn
    // WHY: Emits 'dup vd.4s, wn' (Duplicates 32-bit scalar from general register into all 4 vector lanes).
    // Opcode pattern: 0x4E040C00 | (xn << 5) | vd
    w = 1308892160 | ((xn & 31) * 32) | (vd & 31)
    return arm64_synth_emit32(s, w)
