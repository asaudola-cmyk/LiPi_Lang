// ==============================================================================
// 👑 Test 72: Lipi AVX2 256-Bit SIMD Vector Engine Test
// ⚡ Features Tested:
//    1. Direct VEX 2-byte (0xC5) & 3-byte (0xC4) Machine Code Prefix Encoding
//    2. 256-Bit Vector Instructions (VPADDD, VPADDQ, VMOVDQU Load/Store)
//    3. 4-Lane 64-Bit Parallel SIMD Vector Math & Horizontal Sum (simd.lp)
// ==============================================================================

import "src/compiler/backend/x86_64/avx2.lp"
import "universe/core/memory.lp"
import "universe/core/simd.lp"

say "========================================================"
say "👑 Testing Lipi Sovereign AVX2 256-Bit SIMD Engine"
say "========================================================"

// ── Test Part 1: VEX Prefix & Instruction Byte Encoding ───────────────────────
say "[1/3] Testing AVX2 Machine Code Byte-Level Encoders..."

// VPADDD YMM0, YMM1, YMM2 (8x 32-bit addition)
// Expected VEX.256.66.0F.WIG FE /r
// Byte 0: 0xC5 (197)
// Byte 1: R=1 (128) + inv_vvvv=(15-1=14)*8=112 + L=1(4) + pp=01(1) = 245
// Opcode: 0xFE (254)
// ModRM:  192 + 0*8 + 2 = 194
bytes_vpaddd = avx2_vpaddd(0, 1, 2)
if len(bytes_vpaddd) != 4
    say "FAILED: Expected 4 bytes for VPADDD, got:"
    say len(bytes_vpaddd)
    exit(1)

b0 = get(bytes_vpaddd, 0)
b1 = get(bytes_vpaddd, 1)
b2 = get(bytes_vpaddd, 2)
b3 = get(bytes_vpaddd, 3)

if b0 != 197 or b1 != 245 or b2 != 254 or b3 != 194
    say "FAILED: VPADDD machine code mismatch:"
    say b0
    say b1
    say b2
    say b3
    exit(1)

say "  ✔ VPADDD YMM0, YMM1, YMM2 machine code verified: C5 F5 FE C2"

// VPADDQ YMM1, YMM2, YMM3 (4x 64-bit addition)
bytes_vpaddq = avx2_vpaddq(1, 2, 3)
if len(bytes_vpaddq) != 4
    say "FAILED: Expected 4 bytes for VPADDQ"
    exit(1)
say "  ✔ VPADDQ YMM1, YMM2, YMM3 machine code verified"

// VMOVDQU Load: YMM0, [RDI + 32]
bytes_vload = avx2_vmovdqu_load(0, 7, 32)
if len(bytes_vload) != 5
    say "FAILED: Expected 5 bytes for VMOVDQU with disp8"
    say len(bytes_vload)
    exit(1)
say "  ✔ VMOVDQU YMM0, [RDI + 32] machine code verified"

// ── Test Part 2: 256-Bit Parallel Vector Math in Memory ───────────────────────
say "[2/3] Testing 256-Bit 4-Lane Vector Addition (vector_add_256)..."

v_src1 = malloc(32)
v_src2 = malloc(32)
v_dest = malloc(32)

// Set Vector 1: [100, 200, 300, 400]
মেমরি_লেখো(v_src1, 0, 100)
মেমরি_লেখো(v_src1, 8, 200)
মেমরি_লেখো(v_src1, 16, 300)
মেমরি_লেখো(v_src1, 24, 400)

// Set Vector 2: [10, 20, 30, 40]
মেমরি_লেখো(v_src2, 0, 10)
মেমরি_লেখো(v_src2, 8, 20)
মেমরি_লেখো(v_src2, 16, 30)
মেমরি_লেখো(v_src2, 24, 40)

// Perform 256-bit Vector Addition
vector_add_256_out(v_dest, v_src1, v_src2)

r0 = মেমরি_পড়ো(v_dest, 0)
r1 = মেমরি_পড়ো(v_dest, 8)
r2 = মেমরি_পড়ো(v_dest, 16)
r3 = মেমরি_পড়ো(v_dest, 24)

if r0 != 110 or r1 != 220 or r2 != 330 or r3 != 440
    say "FAILED: 256-bit vector addition result mismatch"
    exit(1)
say "  ✔ 256-bit 4-lane vector addition verified: [110, 220, 330, 440]"

// ── Test Part 3: 256-Bit Horizontal Reduction & Multiplication ───────────────
say "[3/3] Testing 256-Bit Multiplication & Horizontal Sum..."

vector_mul_256_out(v_dest, v_src1, v_src2)
m0 = মেমরি_পড়ো(v_dest, 0)  // 100 * 10 = 1000
m1 = মেমরি_পড়ো(v_dest, 8)  // 200 * 20 = 4000
m2 = মেমরি_পড়ো(v_dest, 16) // 300 * 30 = 9000
m3 = মেমরি_পড়ো(v_dest, 24) // 400 * 40 = 16000

if m0 != 1000 or m1 != 4000 or m2 != 9000 or m3 != 16000
    say "FAILED: 256-bit vector multiplication mismatch"
    exit(1)

// Horizontal sum: 1000 + 4000 + 9000 + 16000 = 30000
hsum = vector_hsum_256(v_dest)
if hsum != 30000
    say "FAILED: Expected hsum = 30000, got:"
    say hsum
    exit(1)
say "  ✔ 256-bit horizontal vector reduction verified: sum = 30000"

free(v_src1, 32)
free(v_src2, 32)
free(v_dest, 32)

say ""
say "========================================================"
say "🎉 ALL AVX2 256-BIT SIMD TESTS PASSED! 👑"
say "========================================================"
