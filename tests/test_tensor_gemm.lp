// ==============================================================================
// 🧪 LIPI REGRESSION TEST: Native 2D GEMM & Columnar DataFrame Fusion (Pillar 3)
// ⚡ 100% Pure LiPi Implementation — Zero External Python/NumPy/C Dependencies
//    Verifies General Matrix Multiplication (GEMM) & Columnar Feature Projection
// ==============================================================================

include "universe/core/memory.lp"
include "universe/ai/tensor_engine.lp"
include "packages/lipi_dataframe/src/dataframe.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    say "  ✔ [PASS] " + test_name

fn assert_eq actual expected test_name
    if actual != expected
        say "  ❌ FAILED: " + test_name
        say "     Expected: " + str(expected)
        say "     Actual:   " + str(actual)
        exit(1)
    say "  ✔ [PASS] " + test_name

say "================================================================="
say "👑 LIPI TENSOR & GEMM COMPUTE ENGINE TEST (Pillar 3) 👑"
say "================================================================="

// ── ১. ডিরেক্ট ২ডি GEMM যাচাইকরণ: A (2x3) x B (3x2) -> C (2x2) ────────────
// Matrix A:
// [ 1, 2, 3 ]
// [ 4, 5, 6 ]
mat_a = sys_alloc(6 * 8)
mem_write_idx(mat_a, 0, 1)
mem_write_idx(mat_a, 1, 2)
mem_write_idx(mat_a, 2, 3)
mem_write_idx(mat_a, 3, 4)
mem_write_idx(mat_a, 4, 5)
mem_write_idx(mat_a, 5, 6)

// Matrix B:
// [ 7, 8 ]
// [ 9, 1 ]
// [ 2, 3 ]
mat_b = sys_alloc(6 * 8)
mem_write_idx(mat_b, 0, 7)
mem_write_idx(mat_b, 1, 8)
mem_write_idx(mat_b, 2, 9)
mem_write_idx(mat_b, 3, 1)
mem_write_idx(mat_b, 4, 2)
mem_write_idx(mat_b, 5, 3)

mat_c = sys_alloc(4 * 8)
count = ai_gemm_2d(mat_c, mat_a, mat_b, 2, 3, 2)
assert_eq(count, 4, "2D GEMM executed 4 output elements")

// C[0, 0] = 1*7 + 2*9 + 3*2 = 7 + 18 + 6 = 31
c00 = mem_read_idx(mat_c, 0)
assert_eq(c00, 31, "C[0, 0] == 31")

// C[0, 1] = 1*8 + 2*1 + 3*3 = 8 + 2 + 9 = 19
c01 = mem_read_idx(mat_c, 1)
assert_eq(c01, 19, "C[0, 1] == 19")

// C[1, 0] = 4*7 + 5*9 + 6*2 = 28 + 45 + 12 = 85
c10 = mem_read_idx(mat_c, 2)
assert_eq(c10, 85, "C[1, 0] == 85")

// C[1, 1] = 4*8 + 5*1 + 6*3 = 32 + 5 + 18 = 55
c11 = mem_read_idx(mat_c, 3)
assert_eq(c11, 55, "C[1, 1] == 55")

// Bangla Alias Test
mat_c_bn = sys_alloc(4 * 8)
count_bn = এআই_ম্যাট্রিক্স_ম্যাট্রিক্স_গুণন(mat_c_bn, mat_a, mat_b, 2, 3, 2)
assert_eq(count_bn, 4, "Bangla alias এআই_ম্যাট্রিক্স_ম্যাট্রিক্স_গুণন executed")
assert_eq(mem_read_idx(mat_c_bn, 0), 31, "Bangla alias result C[0,0] == 31")

// ── ২. DataFrame কলামার ফিচার থেকে টেনসর প্রজেকশন ───────────────────────────
df = df_new()
c_area = df_add_column(df, "area", COL_TYPE_INT, 10)
c_rooms = df_add_column(df, "rooms", COL_TYPE_INT, 10)

df_append_row_2(df, 10, 2)
df_append_row_2(df, 20, 3)
df_append_row_2(df, 30, 4)

assert_eq(df_row_count(df), 3, "DataFrame contains 3 observations")

// Feature Matrix X (3x2)
mat_x = sys_alloc(3 * 2 * 8)
mem_write_idx(mat_x, 0, df_get(df, 0, 0))
mem_write_idx(mat_x, 1, df_get(df, 0, 1))
mem_write_idx(mat_x, 2, df_get(df, 1, 0))
mem_write_idx(mat_x, 3, df_get(df, 1, 1))
mem_write_idx(mat_x, 4, df_get(df, 2, 0))
mem_write_idx(mat_x, 5, df_get(df, 2, 1))

// Weights Vector W (2x1): [5, 100]
mat_w = sys_alloc(2 * 1 * 8)
mem_write_idx(mat_w, 0, 5)
mem_write_idx(mat_w, 1, 100)

// Prediction Matrix Y (3x1)
mat_y = sys_alloc(3 * 1 * 8)
ai_gemm_2d(mat_y, mat_x, mat_w, 3, 2, 1)

// Y[0] = 10*5 + 2*100 = 250
// Y[1] = 20*5 + 3*100 = 400
// Y[2] = 30*5 + 4*100 = 550
assert_eq(mem_read_idx(mat_y, 0), 250, "Predicted Y[0] == 250")
assert_eq(mem_read_idx(mat_y, 1), 400, "Predicted Y[1] == 400")
assert_eq(mem_read_idx(mat_y, 2), 550, "Predicted Y[2] == 550")

df_free(df)
mem_free(mat_a, 48)
mem_free(mat_b, 48)
mem_free(mat_c, 32)
mem_free(mat_c_bn, 32)
mem_free(mat_x, 48)
mem_free(mat_w, 16)
mem_free(mat_y, 24)

say "🎉 ALL TENSOR GEMM AND DATAFRAME PROJECTION TESTS PASSED!"
