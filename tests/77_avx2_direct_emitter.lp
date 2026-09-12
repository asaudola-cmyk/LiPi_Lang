// ==============================================================================
// 👑 Test 77: Direct AVX2 256-Bit SIMD Vector Kernel Emitter
// ⚡ Features Tested:
//    1. Direct CPU AVX2 VEX-encoded YMM Vector Instruction Execution
//    2. Hyper-throughput parallel 4x 64-bit integer sum per clock cycle
//    3. Unrolled 8x 64-bit vector pipeline with horizontal reduction
//    4. Tail handling for non-multiple-of-8 array bounds
// ==============================================================================

include "src/runtime/lipi_syscall.lp"

fn malloc size
    return syscall(9, 0, size, 3, 34, 0 - 1, 0)

fn free addr size
    return syscall(11, addr, size, 0, 0, 0, 0)

say "========================================================"
say "👑 Testing Lipi Native AVX2 256-Bit SIMD Vector Kernel"
say "========================================================"

// ── Test Part 1: Small Scale & Boundary Edge Cases ────────────────────────────
say "[1/3] Testing Small Array Bounds & Edge Cases..."

n_small = 16
buf_small = malloc(n_small * 8)

i = 0
while i < n_small
    val = i + 1
    sys_poke(buf_small + (i * 8), val)
    i = i + 1

// Case A: count = 0
s0 = simd_avx2_sum(buf_small, 0)
if s0 != 0
    say "FAIL: count 0 expected 0, got " + str(s0)
    exit(1)
say "  ✔ Count 0 returned 0"

// Case B: count = 1
s1 = simd_avx2_sum(buf_small, 1)
if s1 != 1
    say "FAIL: count 1 expected 1, got " + str(s1)
    exit(1)
say "  ✔ Count 1 returned 1"

// Case C: count = 4 (exact 1 YMM register)
s4 = simd_avx2_sum(buf_small, 4)
if s4 != 10
    say "FAIL: count 4 expected 10, got " + str(s4)
    exit(1)
say "  ✔ Count 4 returned 10 (1+2+3+4)"

// Case D: count = 7 (tail elements)
s7 = simd_avx2_sum(buf_small, 7)
if s7 != 28
    say "FAIL: count 7 expected 28, got " + str(s7)
    exit(1)
say "  ✔ Count 7 returned 28 (1..7 sum)"

// Case E: count = 10 (1 unrolled 8-vector + 2 tail)
s10 = simd_avx2_sum(buf_small, 10)
if s10 != 55
    say "FAIL: count 10 expected 55, got " + str(s10)
    exit(1)
say "  ✔ Count 10 returned 55 (1..10 sum)"

free(buf_small, n_small * 8)

// ── Test Part 2: Large Scale (1,000,000 Elements) High-Throughput Test ────────
say "[2/3] Testing 1,000,000 Element AVX2 Parallel Scan..."

n_large = 1000000
buf_large = malloc(n_large * 8)

i = 0
expected_sum = 0
while i < n_large
    v = i % 100
    sys_poke(buf_large + (i * 8), v)
    expected_sum = expected_sum + v
    i = i + 1

start_c = cpu_clock()
actual_sum = simd_avx2_sum(buf_large, n_large)
end_c = cpu_clock()

say "  Total Elements: " + str(n_large)
say "  Expected Sum:   " + str(expected_sum)
say "  Actual AVX2 Sum: " + str(actual_sum)
say "  AVX2 Cycles:     " + str(end_c - start_c)

if actual_sum != expected_sum
    say "FAIL: Large array sum mismatch!"
    exit(1)

say "  ✔ 1,000,000 Element AVX2 SIMD Sum Verified 100% Accurate!"

// ── Test Part 3: Bengali Language Syntax Alias ───────────────────────────────
say "[3/3] Testing Bengali Syntax Alias (ভেক্টর_যোগ_২৫৬)..."
bengali_sum = ভেক্টর_যোগ_২৫৬(buf_large, n_large)
if bengali_sum != expected_sum
    say "FAIL: Bengali syntax alias mismatch!"
    exit(1)

say "  ✔ Bengali Alias (ভেক্টর_যোগ_২৫৬) Verified!"

free(buf_large, n_large * 8)

say "========================================================"
say "PASS: Test 77 AVX2 Direct Emitter"
say "========================================================"
