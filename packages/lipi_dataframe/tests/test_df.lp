// ==============================================================================
// 🧪 LIPI PACKAGE TEST: Columnar DataFrame Engine Unit Test
// ==============================================================================

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
say "👑 LIPI DATAFRAME: COLUMNAR ANALYTICS PACKAGE TEST 👑"
say "================================================================="

df = df_new()
assert_true(df > 0, "DataFrame allocated")

c0 = df_add_column(df, "id", COL_TYPE_INT, 100)
c1 = df_add_column(df, "revenue", COL_TYPE_INT, 100)
assert_eq(c0, 0, "First column index is 0")
assert_eq(c1, 1, "Second column index is 1")

// Append 5 rows of transactional data
df_append_row_2(df, 1, 1500)
df_append_row_2(df, 2, 2500)
df_append_row_2(df, 3, 3500)
df_append_row_2(df, 4, 4500)
df_append_row_2(df, 5, 5500)

assert_eq(df_row_count(df), 5, "Row count is 5")

// Test cell lookup
assert_eq(df_get(df, 0, 0), 1, "Row 0 ID is 1")
assert_eq(df_get(df, 0, 1), 1500, "Row 0 revenue is 1500")
assert_eq(df_get(df, 4, 1), 5500, "Row 4 revenue is 5500")

// Test analytical aggregations
rev_sum = df_sum(df, 1)
assert_eq(rev_sum, 17500, "Sum of revenue is 17500 (1.5k + 2.5k + 3.5k + 4.5k + 5.5k)")

rev_mean = df_mean(df, 1)
assert_eq(rev_mean, 3500, "Mean revenue is 3500 (17500 / 5)")

rev_min = df_min(df, 1)
assert_eq(rev_min, 1500, "Min revenue is 1500")

rev_max = df_max(df, 1)
assert_eq(rev_max, 5500, "Max revenue is 5500")

// Test filtering: WHERE revenue > 3000
filtered_df = df_filter_gt(df, 1, 3000)
assert_eq(df_row_count(filtered_df), 3, "Filtered row count is 3 (3.5k, 4.5k, 5.5k)")
assert_eq(df_get(filtered_df, 0, 1), 3500, "First filtered row is 3500")
assert_eq(df_get(filtered_df, 2, 1), 5500, "Last filtered row is 5500")

df_free(filtered_df, 10)
df_free(df, 100)

say "🎉 ALL COLUMNAR DATAFRAME TESTS PASSED!"
