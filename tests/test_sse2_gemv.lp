include "universe/core/io.lp"
include "universe/core/memory.lp"

fn main
    say "=== Testing Native %xmm SSE2 Float Dot Product & GEMV ==="

    // Test 1: simd_sse2_dot_f64
    // Vector A: [1.0, 2.0, 3.0, 4.0] -> IEEE-754 bit representations:
    // 1.0 = 4607182418800017408
    // 2.0 = 4611686018427387904
    // 3.0 = 4613937818241073152
    // 4.0 = 4616189618054758400
    // Vector B: [2.0, 2.0, 2.0, 2.0]
    // Dot product = 1*2 + 2*2 + 3*2 + 4*2 = 2 + 4 + 6 + 8 = 20.0
    // 20.0 IEEE-754 = 4626322717216342016

    a_buf = malloc(32)
    b_buf = malloc(32)

    mem_write_idx(a_buf, 0, 4607182418800017408) // 1.0
    mem_write_idx(a_buf, 1, 4611686018427387904) // 2.0
    mem_write_idx(a_buf, 2, 4613937818241073152) // 3.0
    mem_write_idx(a_buf, 3, 4616189618054758400) // 4.0

    mem_write_idx(b_buf, 0, 4611686018427387904) // 2.0
    mem_write_idx(b_buf, 1, 4611686018427387904) // 2.0
    mem_write_idx(b_buf, 2, 4611686018427387904) // 2.0
    mem_write_idx(b_buf, 3, 4611686018427387904) // 2.0

    dot_res = simd_sse2_dot_f64(a_buf, b_buf, 4)
    say "  • simd_sse2_dot_f64 result bitpattern: " + str(dot_res)
    if dot_res == 4626322717216342016
        say "  ✔ SSE2 Dot Product Verified: Exactly 20.0 (Bit-exact match)!"
    else
        say "  ❌ SSE2 Dot Product Mismatch!"
        return 1

    // Test 2: simd_sse2_gemv_f64
    // 2 rows, 4 columns
    // Row 0 = [1.0, 2.0, 3.0, 4.0] -> dot with [2.0, 2.0, 2.0, 2.0] = 20.0
    // Row 1 = [2.0, 2.0, 2.0, 2.0] -> dot with [2.0, 2.0, 2.0, 2.0] = 16.0
    // 16.0 IEEE-754 = 4625196817309499392
    w_mat = malloc(64)
    mem_write_idx(w_mat, 0, 4607182418800017408) // 1.0
    mem_write_idx(w_mat, 1, 4611686018427387904) // 2.0
    mem_write_idx(w_mat, 2, 4613937818241073152) // 3.0
    mem_write_idx(w_mat, 3, 4616189618054758400) // 4.0

    mem_write_idx(w_mat, 4, 4611686018427387904) // 2.0
    mem_write_idx(w_mat, 5, 4611686018427387904) // 2.0
    mem_write_idx(w_mat, 6, 4611686018427387904) // 2.0
    mem_write_idx(w_mat, 7, 4611686018427387904) // 2.0

    out_vec = malloc(16)
    mem_write_idx(out_vec, 0, 0)
    mem_write_idx(out_vec, 1, 0)

    rows = simd_sse2_gemv_f64(out_vec, w_mat, b_buf, 4, 2)
    say "  • simd_sse2_gemv_f64 rows returned: " + str(rows)
    r0 = mem_read_idx(out_vec, 0)
    r1 = mem_read_idx(out_vec, 1)
    say "  • Row 0 output: " + str(r0) + " (Expected: 4626322717216342016 for 20.0)"
    say "  • Row 1 output: " + str(r1) + " (Expected: 4625196817309499392 for 16.0)"

    if rows == 2 and r0 == 4626322717216342016 and r1 == 4625196817309499392
        say "  ✔ SSE2 GEMV Verified: Exact hardware %xmm matrix-vector product!"
    else
        say "  ❌ SSE2 GEMV Mismatch!"
        return 1

    free(a_buf, 32)
    free(b_buf, 32)
    free(w_mat, 64)
    free(out_vec, 16)

    say "🎉 ALL %xmm SSE2 HARDWARE FLOAT MATH TESTS PASSED!"
    return 0

main()
