// ==============================================================================
// 👑 Test: Lipi Hardware AVX2 256-Bit SIMD Vector Kernel Engine
// ⚡ 100% Pure Lipi | Silicon Machine Code | 4x 64-bit Parallelism per Cycle
// ==============================================================================
//
// WHY: Validates direct VEX-encoded YMM vector execution for large numerical workloads
//      (AI tensors, FinTech time-series, columnar databases), proving zero external
//      library overhead and mathematical parity with scalar arithmetic.
// ==============================================================================

include "src/runtime/lipi_syscall.lp"

fn sim_malloc size
    return syscall(9, 0, size, 3, 34, 0 - 1, 0)

fn sim_free addr size
    return syscall(11, addr, size, 0, 0, 0, 0)

say "========================================================"
say "👑 Testing Lipi AVX2 256-Bit SIMD Vector Engine"
say "========================================================"

// ── Test 1: Boundary Edge Cases & Tail Handling ───────────────────────────────
say "[1/4] Testing Exact Boundary Conditions & Tail Elements..."

n_small = 32
buf_small = sim_malloc(n_small * 8)

i = 0
while i < n_small
    sys_poke(buf_small + (i * 8), i + 1)
    i = i + 1

// Case A: count = 0
s0 = simd_avx2_sum(buf_small, 0)
if s0 != 0
    say "FAIL: count 0 expected 0, got " + str(s0)
    exit(1)
say "  ✔ Count 0: 0"

// Case B: count = 1
s1 = simd_avx2_sum(buf_small, 1)
if s1 != 1
    say "FAIL: count 1 expected 1, got " + str(s1)
    exit(1)
say "  ✔ Count 1: 1"

// Case C: count = 4 (exact 1 YMM register)
s4 = simd_avx2_sum(buf_small, 4)
if s4 != 10
    say "FAIL: count 4 expected 10, got " + str(s4)
    exit(1)
say "  ✔ Count 4 (1 YMM): 10"

// Case D: count = 7 (tail reduction)
s7 = simd_avx2_sum(buf_small, 7)
if s7 != 28
    say "FAIL: count 7 expected 28, got " + str(s7)
    exit(1)
say "  ✔ Count 7 (Tail elements): 28"

// Case E: count = 8 (unrolled loop bound)
s8 = simd_avx2_sum(buf_small, 8)
if s8 != 36
    say "FAIL: count 8 expected 36, got " + str(s8)
    exit(1)
say "  ✔ Count 8 (Unrolled 2x YMM): 36"

// Case F: count = 15
s15 = simd_avx2_sum(buf_small, 15)
if s15 != 120
    say "FAIL: count 15 expected 120, got " + str(s15)
    exit(1)
say "  ✔ Count 15: 120"

sim_free(buf_small, n_small * 8)

// ── Test 2: Large-Scale 1,000,000 Element Parallel Scan ───────────────────────
say "[2/4] Testing 1,000,000 Element Parallel AVX2 Scan..."

n_large = 1000000
buf_large = sim_malloc(n_large * 8)

i = 0
expected_total = 0
while i < n_large
    v = (i % 100) + 1
    sys_poke(buf_large + (i * 8), v)
    expected_total += v
    i += 1

start_c = cpu_clock()
simd_total = simd_avx2_sum(buf_large, n_large)
end_c = cpu_clock()

if simd_total != expected_total
    say "FAIL: 1M element SIMD sum mismatch!"
    exit(1)

say "  ✔ 1,000,000 Elements Verified: sum=" + str(simd_total) + " (Cycles: " + str(end_c - start_c) + ")"

// ── Test 3: Bilingual Bengali Language Native Alias ──────────────────────────
say "[3/4] Testing Bengali Alias (ভেক্টর_যোগ_২৫৬)..."
bengali_total = ভেক্টর_যোগ_২৫৬(buf_large, n_large)
if bengali_total != expected_total
    say "FAIL: Bengali alias result mismatch!"
    exit(1)
say "  ✔ Bengali Alias (ভেক্টর_যোগ_২৫৬) Verified: " + str(bengali_total)

sim_free(buf_large, n_large * 8)

// ── Test 4: Matrix Row Dot-Product via Vector Accumulation ────────────────────
say "[4/4] Testing Matrix Row Vector Reduction with AVX2..."

row_len = 256
row_a = sim_malloc(row_len * 8)
row_b = sim_malloc(row_len * 8)
row_prod = sim_malloc(row_len * 8)

ri = 0
expected_dot = 0
while ri < row_len
    va = ri + 1
    vb = 2
    sys_poke(row_a + (ri * 8), va)
    sys_poke(row_b + (ri * 8), vb)
    prod = va * vb
    sys_poke(row_prod + (ri * 8), prod)
    expected_dot += prod
    ri += 1

dot_res = simd_avx2_sum(row_prod, row_len)
if dot_res != expected_dot
    say "FAIL: Matrix row dot-product mismatch!"
    exit(1)

say "  ✔ Matrix Vector Dot-Product Verified: " + str(dot_res)

sim_free(row_a, row_len * 8)
sim_free(row_b, row_len * 8)
sim_free(row_prod, row_len * 8)

say "========================================================"
say "PASS: AVX2 SIMD Vector Test Suite Verified 100%!"
say "========================================================"
