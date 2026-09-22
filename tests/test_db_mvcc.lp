// ==============================================================================
// 🧪 LIPI TEST SUITE: Multi-Version Concurrency Control (MVCC) Storage Engine
// ⚡ Tests Snapshot Isolation, Repeatable Reads, Dirty Read Prevention,
//    First-Committer-Wins Write Conflict Detection, Instant Rollback, and Vacuum.
// ==============================================================================

include "universe/db/mvcc.lp"

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
say "👑 LIPI DATABASE: MULTI-VERSION CONCURRENCY CONTROL (Frontier 7) 👑"
say "================================================================="

db = mvcc_engine_new()

// ── Section 1: Snapshot Isolation & Repeatable Reads ──────────────────────────
say "▶ Section 1: Snapshot Isolation & Repeatable Reads..."

// Tx1 creates initial state: balance:alice = 1000
tx1 = mvcc_begin(db)
mvcc_put(db, tx1, "balance:alice", "1000")
mvcc_commit(db, tx1)

// Tx2 starts reader snapshot at TxID 101
tx2 = mvcc_begin(db)
val2_first = mvcc_get(db, tx2, "balance:alice")
assert_eq(val2_first, "1000", "Tx2 initially reads 1000")

// Tx3 starts after Tx2, modifies balance to 2500, and COMMITS
tx3 = mvcc_begin(db)
mvcc_put(db, tx3, "balance:alice", "2500")
mvcc_commit(db, tx3)

// Tx2 reads balance again: MUST STILL SEE 1000 (Repeatable Read Guarantee)
val2_second = mvcc_get(db, tx2, "balance:alice")
assert_eq(val2_second, "1000", "Tx2 snapshot isolates against subsequent Tx3 commit (sees 1000)")
mvcc_commit(db, tx2)

// Tx4 starts now (after Tx3 committed): Sees 2500
tx4 = mvcc_begin(db)
val4 = mvcc_get(db, tx4, "balance:alice")
assert_eq(val4, "2500", "Tx4 started after Tx3 commit sees updated 2500")
mvcc_commit(db, tx4)

// ── Section 2: Dirty Read Prevention & Uncommitted Write Isolation ───────────
say ""
say "▶ Section 2: Dirty Read Prevention & Uncommitted Data Isolation..."

// Tx5 mutates record to uncommitted 9999
tx5 = mvcc_begin(db)
mvcc_put(db, tx5, "balance:alice", "9999")

// Tx6 starts while Tx5 is active
tx6 = mvcc_begin(db)
val6 = mvcc_get(db, tx6, "balance:alice")
assert_eq(val6, "2500", "Tx6 NEVER sees uncommitted dirty write of Tx5 (sees 2500)")

// Tx5 aborts and rolls back
mvcc_rollback(db, tx5)
mvcc_commit(db, tx6)

// Tx7 starts after rollback
tx7 = mvcc_begin(db)
val7 = mvcc_get(db, tx7, "balance:alice")
assert_eq(val7, "2500", "After Tx5 rollback, committed balance remains intact at 2500")
mvcc_commit(db, tx7)

// ── Section 3: First-Committer-Wins Write Conflict Detection ──────────────────
say ""
say "▶ Section 3: First-Committer-Wins Write Conflict Detection..."

// Setup inventory key
tx_setup = mvcc_begin(db)
mvcc_put(db, tx_setup, "inventory:gpu", "50")
mvcc_commit(db, tx_setup)

// Concurrent writers Tx8 and Tx9
tx8 = mvcc_begin(db)
tx9 = mvcc_begin(db)

// Tx8 writes first
res8 = mvcc_put(db, tx8, "inventory:gpu", "40")
assert_eq(res8, 1, "Tx8 acquires write to inventory:gpu successfully")

// Tx9 attempts concurrent conflicting write
res9 = mvcc_put(db, tx9, "inventory:gpu", "30")
assert_eq(res9, -1, "Tx9 write conflict detected (-1): uncommitted concurrent write blocked")

mvcc_commit(db, tx8)
mvcc_rollback(db, tx9)

// ── Section 4: Rollback Integrity & Non-Blocking Vacuum Pruning ───────────────
say ""
say "▶ Section 4: Rollback Integrity & Non-Blocking Vacuum Pruning..."

// Tx10 inserts a temporary key then aborts
tx10 = mvcc_begin(db)
mvcc_put(db, tx10, "temp:session", "token_abc")
mvcc_rollback(db, tx10)

tx11 = mvcc_begin(db)
v_temp = mvcc_get(db, tx11, "temp:session")
assert_eq(v_temp, "[NOT_FOUND]", "Aborted record completely unlinked from engine ([NOT_FOUND])")
mvcc_commit(db, tx11)

// Execute vacuum pruning older than current active horizon (horizon 105)
pruned = mvcc_vacuum(db, 105)
assert_true(pruned >= 1, "Vacuum pruned at least 1 obsolete version from chain")

// Verify final database stats
stats = get(db, 6)
tx_started = get(stats, 0)
tx_committed = get(stats, 1)
tx_aborted = get(stats, 2)
assert_true(tx_started >= 10, "At least 10 transactions initiated")
assert_true(tx_committed >= 7, "At least 7 transactions committed successfully")
assert_true(tx_aborted >= 2, "At least 2 transactions aborted & rolled back cleanly")

say ""
say "-----------------------------------------------------------------"
say "RESULTS: 4/4 sections passed."
say "🎉 ALL MVCC DATABASE STORAGE TESTS PASSED!"
say ""
