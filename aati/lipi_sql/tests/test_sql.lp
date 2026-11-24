// ==============================================================================
// 🧪 LIPI PACKAGE TEST: Pure Relational SQL Engine Unit Test
// ==============================================================================

include "aati/lipi_sql/src/sql.lp"

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

// ── Dynamic >20 Tables & Auto-Row Growth ─────────────────────────────────────
dyn = sql_engine_new()
ti = 1
while ti <= 24
    tp = sql_create_table(dyn, 500 + ti, 2, 2)
    assert_true(tp > 0, "Created dynamic table #" + to_str(ti) + " (> old 16-table cap)")
    ti = ti + 1
ri = 1
while ri <= 35
    sql_insert_2(dyn, 524, ri, ri * 100)
    ri = ri + 1
assert_eq(sql_count_active(dyn, 524), 35, "Auto-grew row capacity from 2 to 35 rows")
assert_eq(sql_select_first_where_eq(dyn, 524, 0, 35, 1), 3500, "Row 35 cell accurately stored after realloc")
sql_engine_free(dyn)

// ── Disk Persistence, TEXT Interning, UPDATE SQL, & Torn-WAL Crash Recovery ──
wal_path = "/tmp/lipi_sql_pkg_wal_test.db"
syscall(87, wal_path, 0, 0, 0, 0, 0) // unlink if leftover
p1 = sql_engine_open(wal_path)
sql_execute_query(p1, "CREATE TABLE 10 (2, 4)")
sql_execute_query(p1, "INSERT INTO 10 VALUES (1, 100)")
sql_execute_query(p1, "INSERT INTO 10 VALUES (2, 200)")
sql_execute_query(p1, "INSERT INTO 10 VALUES (3, 300)")
sql_execute_query(p1, "UPDATE 10 SET 1 = 999 WHERE 0 = 2")
sql_execute_query(p1, "DELETE FROM 10 WHERE 0 = 3")
sql_create_table(p1, 20, 2, 4)
sql_insert_text_2(p1, 20, 42, "Sovereign Dhaka Text")
sql_engine_close(p1)

// Append 11 torn garbage bytes simulating power failure mid-WAL write
tfd = syscall(2, wal_path, 1089, 420, 0, 0, 0) // O_WRONLY | O_APPEND
gbuf = sys_alloc(12)
mem_write_byte(gbuf, 0, 83)
mem_write_byte(gbuf, 1, 81)
mem_write_byte(gbuf, 2, 76)
mem_write_byte(gbuf, 3, 82)
mem_write_byte(gbuf, 4, 255)
syscall(1, tfd, gbuf, 11, 0, 0, 0)
syscall(3, tfd, 0, 0, 0, 0, 0)
sys_free(gbuf)

// Reopen: must truncate torn tail & preserve all committed writes
p2 = sql_engine_open(wal_path)
assert_eq(sql_select_first_where_eq(p2, 10, 0, 2, 1), 999, "WAL persisted UPDATE after close/reopen + torn-tail recovery")
assert_eq(sql_count_active(p2, 10), 2, "WAL persisted DELETE count == 2")
assert_true(sql_select_text_cell(p2, 20, 0, 1) == "Sovereign Dhaka Text", "WAL persisted TEXT interned string")
assert_eq(sql_engine_checkpoint(p2, wal_path), 1, "WAL checkpoint compaction succeeded")
sql_engine_close(p2)

p3 = sql_engine_open(wal_path)
assert_eq(sql_select_first_where_eq(p3, 10, 0, 1, 1), 100, "Compacted checkpoint reload preserved row 1")
assert_true(sql_select_text_cell(p3, 20, 0, 1) == "Sovereign Dhaka Text", "Compacted checkpoint reload preserved TEXT")
sql_engine_close(p3)
syscall(87, wal_path, 0, 0, 0, 0, 0)

say "🎉 ALL SOVEREIGN SQL ENGINE TESTS PASSED!"
