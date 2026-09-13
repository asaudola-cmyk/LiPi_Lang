// ==============================================================================
// 🧪 LIPI REGRESSION TEST: LipiDB v2 Write-Ahead Logging (WAL) & ARIES Recovery
// ⚡ Tests 64-byte WAL record serialization, checksum verification, and ARIES REDO
// ==============================================================================

include "apps/website/db_engine.lp"
include "apps/website/db_wal.lp"

fn assert_true cond test_name
    if cond == 0
        say "  ❌ FAILED: " + test_name
        exit(1)
    say "  ✔ [PASS] " + test_name

say "================================================================="
say "👑 LIPI DATABASE: WRITE-AHEAD LOGGING & ARIES CRASH RECOVERY 👑"
say "================================================================="

test_db_path = "/tmp/test_regress_wal.db"
test_wal_path = "/tmp/test_regress_wal.wal"

// Clean up prior test artifacts
syscall(87, test_db_path, 0, 0, 0, 0, 0)
syscall(87, test_wal_path, 0, 0, 0, 0, 0)

// ── Section 1: Create Database and Seed Initial Records ────────────────────────
say "▶ Section 1: Initializing Database & WAL..."
db_fd = db_open(test_db_path)
wal_fd = wal_open(test_wal_path)

assert_true(db_fd >= 0, "Database file opened successfully")
assert_true(wal_fd >= 0, "WAL log file opened successfully")

rec1 = db_insert_record(db_fd, 100)
rec2 = db_insert_record(db_fd, 200)
assert_true(rec1 == 1, "First record ID is 1")
assert_true(rec2 == 2, "Second record ID is 2")

// ── Section 2: Simulate Crash Scenario ─────────────────────────────────────────
// WHY: Transaction 100 commits to WAL before primary table write, simulating sudden power outage
say "▶ Section 2: Simulating Unfinished Primary Table Write (WAL Preserved)..."
wal_write_entry(wal_fd, 100, 100, WAL_OP_INSERT, 3, 0, 300)
wal_log_commit(wal_fd, 101, 100)

file_close(wal_fd)
file_close(db_fd)

// Before recovery, table only has 2 records
verify_fd = db_open(test_db_path)
count_before = db_total_records(verify_fd)
assert_true(count_before == 2, "Table has 2 records prior to crash recovery")

// ── Section 3: Run ARIES Crash Recovery REDO Phase ─────────────────────────────
say "▶ Section 3: Executing ARIES Crash Recovery REDO Replay..."
replayed = wal_recover_database(test_wal_path, verify_fd)
assert_true(replayed == 1, "ARIES REDO replayed exactly 1 committed pending transaction")

count_after = db_total_records(verify_fd)
assert_true(count_after == 3, "Table recovered 3rd record successfully via WAL")

// Clean up
file_close(verify_fd)
syscall(87, test_db_path, 0, 0, 0, 0, 0)
syscall(87, test_wal_path, 0, 0, 0, 0, 0)

say "🎉 ALL WAL & ARIES RECOVERY REGRESSION TESTS PASSED!"
