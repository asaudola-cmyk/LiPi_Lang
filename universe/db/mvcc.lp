// ==============================================================================
// 👑 LIPI DATABASE: MULTI-VERSION CONCURRENCY CONTROL (MVCC) (universe/db/mvcc.lp)
// ⚡ 100% Pure Native Lipi Language | Snapshot Isolation | Lock-Free Reads
// Zero External C | Zero Libc | Zero Dependencies
// ==============================================================================
//
// WHY: Traditional database locking (2PL) forces readers to block writers and
// writers to block readers, crippling throughput in concurrent workloads.
// Lipi MVCC implements full Snapshot Isolation via linked tuple version chains.
//
// Key Invariants:
//   1. Readers NEVER block writers; writers NEVER block readers.
//   2. Monotonic Transaction IDs (TxID) provide total ordering.
//   3. Each update prepends a new (tx_id_created, tx_id_expired) version node.
//   4. Write-Conflict Detection (First-Committer-Wins) prevents lost updates.
//   5. Instant Rollback unlinks dirty version heads and unexpires prior records.
//   6. Non-blocking Vacuum reclaims tuple versions obscured past min_active_tx.
// ==============================================================================

include "universe/core/memory.lp"

// ── 1. Transaction States & Sentinels ─────────────────────────────────────────
MVCC_TX_ACTIVE    = 1
MVCC_TX_COMMITTED = 2
MVCC_TX_ABORTED   = 3

// ── 2. Utility List Helpers ───────────────────────────────────────────────────
fn mvcc_in_list lst val
    n = len(lst)
    i = 0
    while i < n
        if get(lst, i) == val
            return 1
        i = i + 1
    return 0

fn mvcc_copy_list src
    dst = list()
    n = len(src)
    i = 0
    while i < n
        push(dst, get(src, i))
        i = i + 1
    return dst

// ── 3. Tuple Version Allocator ────────────────────────────────────────────────
// Version structure:
//   v[0]: tx_id_created (TxID that wrote this record)
//   v[1]: tx_id_expired (TxID that deleted/updated this record, 0 if alive)
//   v[2]: key (string)
//   v[3]: value (string or integer)
//   v[4]: is_deleted (1 if tombstone, 0 if active data)
//   v[5]: prev_version (reference to older version node in chain, or 0)

fn mvcc_version_new tx_created key val is_deleted prev_ptr
    v = list()
    push(v, tx_created) // 0: tx_id_created
    push(v, 0)          // 1: tx_id_expired (initially 0)
    push(v, key)        // 2: key
    push(v, val)        // 3: value
    push(v, is_deleted) // 4: is_deleted
    push(v, prev_ptr)   // 5: prev_version
    return v

// ── 4. MVCC Storage Engine Structure ──────────────────────────────────────────
// Structure:
//   engine[0]: next_tx_id (monotonic counter, starts at 100)
//   engine[1]: active_txs (list of running TxIDs)
//   engine[2]: committed_txs (list of committed TxIDs)
//   engine[3]: aborted_txs (list of aborted TxIDs)
//   engine[4]: keys (list of string keys)
//   engine[5]: heads (list of head version nodes for each key)
//   engine[6]: stats (list: [tx_started, tx_committed, tx_aborted, versions_created])

fn mvcc_engine_new
    engine = list()
    push(engine, 100)     // 0: next_tx_id
    push(engine, list())  // 1: active_txs
    push(engine, list())  // 2: committed_txs
    push(engine, list())  // 3: aborted_txs
    push(engine, list())  // 4: keys
    push(engine, list())  // 5: heads
    stats = list()
    push(stats, 0)        // tx_started
    push(stats, 0)        // tx_committed
    push(stats, 0)        // tx_aborted
    push(stats, 0)        // versions_created
    push(engine, stats)   // 6: stats
    return engine

fn mvcc_find_key_idx engine key
    keys = get(engine, 4)
    n = len(keys)
    i = 0
    while i < n
        if get(keys, i) == key
            return i
        i = i + 1
    return -1

// ── 5. Transaction Lifecycle Management ───────────────────────────────────────
// Transaction structure:
//   tx[0]: tx_id (own unique transaction ID)
//   tx[1]: snapshot_tx_id (upper watermark for visible committed records)
//   tx[2]: active_snapshots (frozen snapshot of active TxIDs at begin)
//   tx[3]: state (1 = ACTIVE, 2 = COMMITTED, 3 = ABORTED)
//   tx[4]: write_set (list of keys modified in this transaction)

fn mvcc_begin engine
    tid = get(engine, 0)
    list_set(engine, 0, tid + 1) // Increment global monotonic TxID

    active = get(engine, 1)
    frozen_active = mvcc_copy_list(active)
    push(active, tid) // Register this tx in active transactions

    tx = list()
    push(tx, tid)           // 0: tx_id
    push(tx, tid)           // 1: snapshot_tx_id
    push(tx, frozen_active) // 2: active_snapshots
    push(tx, MVCC_TX_ACTIVE)// 3: state
    push(tx, list())        // 4: write_set

    stats = get(engine, 6)
    list_set(stats, 0, get(stats, 0) + 1) // tx_started + 1
    return tx

// ── 6. Snapshot Isolation Read Engine ─────────────────────────────────────────
// WHY: Traverses the tuple version chain from newest to oldest. Determines visibility
// using Snapshot Isolation invariants without acquiring ANY shared or exclusive locks.

fn mvcc_get engine tx key
    k_idx = mvcc_find_key_idx(engine, key)
    if k_idx == -1
        return "[NOT_FOUND]"

    heads = get(engine, 5)
    cur_v = get(heads, k_idx)

    tx_id = get(tx, 0)
    snapshot_tx_id = get(tx, 1)
    active_snapshots = get(tx, 2)
    aborted_txs = get(engine, 3)

    while cur_v != 0
        c_by = get(cur_v, 0)
        e_by = get(cur_v, 1)

        is_visible = 0

        // Invariant A: Tuple created by this transaction itself
        if c_by == tx_id
            if e_by != tx_id
                is_visible = 1
        else
            // Invariant B: Tuple created by another transaction
            // Must have started before our snapshot AND not have been active at our start
            if c_by < snapshot_tx_id
                was_active = mvcc_in_list(active_snapshots, c_by)
                if was_active == 0
                    was_aborted = mvcc_in_list(aborted_txs, c_by)
                    if was_aborted == 0
                        // Creator committed before our snapshot! Check if it was expired:
                        if e_by == 0
                            is_visible = 1
                        else
                            if e_by == tx_id
                                is_visible = 0 // Expired by self
                            else
                                if e_by >= snapshot_tx_id
                                    // Expired in the future relative to our snapshot -> STILL VISIBLE!
                                    is_visible = 1
                                else
                                    // Expired by a tx that was active when our snapshot was taken
                                    del_active = mvcc_in_list(active_snapshots, e_by)
                                    if del_active == 1
                                        is_visible = 1
                                    else
                                        is_visible = 0

        if is_visible == 1
            is_del = get(cur_v, 4)
            if is_del == 1
                return "[NOT_FOUND]"
            return get(cur_v, 3) // Return visible value

        cur_v = get(cur_v, 5) // Inspect older version in chain

    return "[NOT_FOUND]"

// ── 7. Write Operations & Conflict Detection (First-Committer-Wins) ───────────
fn mvcc_put engine tx key val
    if get(tx, 3) != MVCC_TX_ACTIVE
        return 0 // Transaction not active

    tx_id = get(tx, 0)
    k_idx = mvcc_find_key_idx(engine, key)

    if k_idx != -1
        heads = get(engine, 5)
        v_head = get(heads, k_idx)
        c_by = get(v_head, 0)
        e_by = get(v_head, 1)
        active_txs = get(engine, 1)

        // Conflict check: Has another active transaction touched this head?
        if c_by != tx_id
            if c_by >= get(tx, 1) or mvcc_in_list(active_txs, c_by) == 1
                return -1 // WRITE CONFLICT: Concurrent uncommitted write detected!
            if e_by != 0 and e_by != tx_id
                if mvcc_in_list(active_txs, e_by) == 1
                    return -1 // WRITE CONFLICT: Concurrent uncommitted delete/update!

        // Mark old head expired by this transaction
        list_set(v_head, 1, tx_id)

        // Prepend new version node to chain
        v_new = mvcc_version_new(tx_id, key, val, 0, v_head)
        list_set(heads, k_idx, v_new)
    else
        // First version of this key
        v_new = mvcc_version_new(tx_id, key, val, 0, 0)
        push(get(engine, 4), key)
        push(get(engine, 5), v_new)

    // Append key to transaction write set
    push(get(tx, 4), key)

    stats = get(engine, 6)
    list_set(stats, 3, get(stats, 3) + 1) // versions_created + 1
    return 1

fn mvcc_delete engine tx key
    if get(tx, 3) != MVCC_TX_ACTIVE
        return 0

    tx_id = get(tx, 0)
    k_idx = mvcc_find_key_idx(engine, key)
    if k_idx == -1
        return 0 // Key doesn't exist

    heads = get(engine, 5)
    v_head = get(heads, k_idx)
    c_by = get(v_head, 0)
    e_by = get(v_head, 1)
    active_txs = get(engine, 1)

    // Conflict check
    if c_by != tx_id
        if c_by >= get(tx, 1) or mvcc_in_list(active_txs, c_by) == 1
            return -1 // WRITE CONFLICT
        if e_by != 0 and e_by != tx_id
            if mvcc_in_list(active_txs, e_by) == 1
                return -1 // WRITE CONFLICT

    list_set(v_head, 1, tx_id)
    v_del = mvcc_version_new(tx_id, key, "[DELETED]", 1, v_head)
    list_set(heads, k_idx, v_del)
    push(get(tx, 4), key)

    stats = get(engine, 6)
    list_set(stats, 3, get(stats, 3) + 1)
    return 1

// ── 8. Atomic Commit & Instant Rollback ───────────────────────────────────────
fn mvcc_commit engine tx
    if get(tx, 3) != MVCC_TX_ACTIVE
        return 0

    tx_id = get(tx, 0)
    list_set(tx, 3, MVCC_TX_COMMITTED)

    // Remove from active transactions
    active = get(engine, 1)
    new_active = list()
    i = 0
    while i < len(active)
        tid = get(active, i)
        if tid != tx_id
            push(new_active, tid)
        i = i + 1
    list_set(engine, 1, new_active)

    push(get(engine, 2), tx_id) // Add to committed_txs

    stats = get(engine, 6)
    list_set(stats, 1, get(stats, 1) + 1) // tx_committed + 1
    return 1

fn mvcc_rollback engine tx
    if get(tx, 3) != MVCC_TX_ACTIVE
        return 0

    tx_id = get(tx, 0)
    list_set(tx, 3, MVCC_TX_ABORTED)

    // Revert all uncommitted mutations in write set
    w_set = get(tx, 4)
    heads = get(engine, 5)
    i = 0
    while i < len(w_set)
        k = get(w_set, i)
        k_idx = mvcc_find_key_idx(engine, k)
        if k_idx != -1
            v_cur = get(heads, k_idx)
            // If current head was created by aborted tx, unlink it
            if get(v_cur, 0) == tx_id
                v_prev = get(v_cur, 5)
                list_set(heads, k_idx, v_prev)
                // If previous version was marked expired by this tx, unexpire it!
                if v_prev != 0
                    if get(v_prev, 1) == tx_id
                        list_set(v_prev, 1, 0)
            else
                // Check if any version in chain was marked expired by this tx
                while v_cur != 0
                    if get(v_cur, 1) == tx_id
                        list_set(v_cur, 1, 0)
                    v_cur = get(v_cur, 5)
        i = i + 1

    // Remove from active transactions
    active = get(engine, 1)
    new_active = list()
    j = 0
    while j < len(active)
        tid = get(active, j)
        if tid != tx_id
            push(new_active, tid)
        j = j + 1
    list_set(engine, 1, new_active)

    push(get(engine, 3), tx_id) // Add to aborted_txs

    stats = get(engine, 6)
    list_set(stats, 2, get(stats, 2) + 1) // tx_aborted + 1
    return 1

// ── 9. Non-Blocking Vacuum / Garbage Collector ────────────────────────────────
// WHY: Prunes old versions no longer visible to any currently active transaction.
fn mvcc_vacuum engine min_active_tx
    heads = get(engine, 5)
    pruned_count = 0
    i = 0
    while i < len(heads)
        v = get(heads, i)
        while v != 0
            prev_v = get(v, 5)
            if prev_v != 0
                exp = get(prev_v, 1)
                // If previous version was expired before the oldest active transaction,
                // no transaction will ever read it. Sever the chain safely!
                if exp > 0 and exp < min_active_tx
                    list_set(v, 5, 0)
                    pruned_count = pruned_count + 1
                    v = 0 // Terminate traversal for this key
                else
                    v = prev_v
            else
                v = 0
        i = i + 1
    return pruned_count
