// ==============================================================================
// 🧪 LIPI PACKAGE TEST: Pure Relational SQL Engine Unit Test
// ==============================================================================

include "packages/lipi_sql/src/sql.lp"

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
say "👑 LIPI SQL: SOVEREIGN RELATIONAL QUERY TEST 👑"
say "================================================================="

engine = sql_engine_new()
assert_true(engine > 0, "SQL engine initialized")

// Create Table 101: Users (id, age, balance) - 3 columns, max 50 rows
tbl_users = sql_create_table(engine, 101, 3, 50)
assert_true(tbl_users > 0, "Users table created")

// Insert 4 rows
sql_insert_3(engine, 101, 1, 25, 5000)
sql_insert_3(engine, 101, 2, 30, 8000)
sql_insert_3(engine, 101, 3, 25, 12000)
sql_insert_3(engine, 101, 4, 40, 15000)

assert_eq(sql_count_active(engine, 101), 4, "4 active user rows inserted")

// Verify Cell values
assert_eq(sql_select_cell(engine, 101, 0, 0), 1, "User 0 ID is 1")
assert_eq(sql_select_cell(engine, 101, 0, 1), 25, "User 0 Age is 25")
assert_eq(sql_select_cell(engine, 101, 0, 2), 5000, "User 0 Balance is 5000")

assert_eq(sql_select_cell(engine, 101, 3, 1), 40, "User 3 Age is 40")
assert_eq(sql_select_cell(engine, 101, 3, 2), 15000, "User 3 Balance is 15000")

// WHERE query: Count users where Age == 25
count_age_25 = sql_select_where_eq(engine, 101, 1, 25)
assert_eq(count_age_25, 2, "Found 2 users with age 25")

// SELECT FIRST: Find balance of user with ID 2
bal_user_2 = sql_select_first_where_eq(engine, 101, 0, 2, 2)
assert_eq(bal_user_2, 8000, "User 2 balance is 8000")

// UPDATE: Set balance of user 2 to 9500
up_count = sql_update_where_eq(engine, 101, 0, 2, 2, 9500)
assert_eq(up_count, 1, "Updated 1 row")
bal_user_2_new = sql_select_first_where_eq(engine, 101, 0, 2, 2)
assert_eq(bal_user_2_new, 9500, "User 2 balance updated to 9500")

// DELETE: Remove user with ID 3
del_count = sql_delete_where_eq(engine, 101, 0, 3)
assert_eq(del_count, 1, "Deleted 1 row")
assert_eq(sql_count_active(engine, 101), 3, "Active count reduced to 3")

// Confirm user 3 is no longer matched
count_age_25_after = sql_select_where_eq(engine, 101, 1, 25)
assert_eq(count_age_25_after, 1, "Only 1 active user with age 25 remains")

sql_engine_free(engine)
say "🎉 ALL SOVEREIGN SQL ENGINE TESTS PASSED!"
