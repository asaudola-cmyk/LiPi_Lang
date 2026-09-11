@! ============================================================================
@! LIPI UNIVERSE DB — UNIFIED DATABASE ENGINE (universe/db/engine.maya)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! Unifies BufferPool, B+Tree, Write-Ahead Log (WAL), ACID Transactions,
@! Redo Crash Recovery, Auto-Commit Durability, and Checkpointing
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/fs"
import "universe/core/collections"
import "universe/core/string"
import "universe/db/page"
import "universe/db/buffer"
import "universe/db/btree"
import "universe/db/wal"
@! ----------------------------------------------------------------------------
@! 1. Data Structures
@! ----------------------------------------------------------------------------
@struct Database
  path: string
  wal_path: string
  pool: BufferPool
  tree: array
  wal: Wal
  next_tx_id: i64
  is_open: i64
  capacity: i64
  auto_checkpoint_ops: i64
  ops_since_checkpoint: i64
  stats_puts: i64
  stats_deletes: i64
  stats_gets: i64
  stats_scans: i64
@end

@struct DBStats
  puts: i64
  deletes: i64
  gets: i64
  scans: i64
  pool_hits: i64
  pool_misses: i64
  pool_flushes: i64
  pool_evictions: i64
  wal_last_lsn: i64
@end

import "universe/db/tx"
import "universe/db/recovery"

@! ----------------------------------------------------------------------------
@! 2. Database Lifecycle API
@! ----------------------------------------------------------------------------

@! Opens or creates a unified database engine with WAL and crash recovery
@fn db_open(path, capacity)
  @if capacity <= 0
    capacity = 64
  @end

  wal_path = str_concat(path, ".wal")

  @! Open Buffer Pool
  pool = buffer_pool_open(path, capacity)
  @if pool.fd < 0
    return {
      path: path,
      wal_path: wal_path,
      pool: pool,
      tree: [btree_open(pool, 1)],
      wal: wal_open(wal_path),
      next_tx_id: 1,
      is_open: 0,
      capacity: capacity,
      auto_checkpoint_ops: 500,
      ops_since_checkpoint: 0,
      stats_puts: 0,
      stats_deletes: 0,
      stats_gets: 0,
      stats_scans: 0
    }
  @end

  @! Open B+Tree
  tree = btree_open(pool, pool.root_page_id)
  tree_ref = [tree]

  @! Run Redo Crash Recovery if WAL exists
  rec_res = wal_recover(wal_path, tree_ref, pool)

  last_tx = 0
  last_lsn = 0
  @if rec_res.last_tx_id > 0
    last_tx = rec_res.last_tx_id
  @end
  @if rec_res.last_lsn > 0
    last_lsn = rec_res.last_lsn
  @end

  @! Open WAL for active transaction logging
  wal = wal_open(wal_path)
  @if last_lsn > 0 && wal.next_lsn <= last_lsn
    wal.next_lsn = last_lsn + 1
    wal.last_lsn = last_lsn
  @end

  next_tx_id = last_tx + 1
  @if next_tx_id <= 0
    next_tx_id = 1
  @end

  return {
    path: path,
    wal_path: wal_path,
    pool: pool,
    tree: tree_ref,
    wal: wal,
    next_tx_id: next_tx_id,
    is_open: 1,
    capacity: capacity,
    auto_checkpoint_ops: 500,
    ops_since_checkpoint: 0,
    stats_puts: 0,
    stats_deletes: 0,
    stats_gets: 0,
    stats_scans: 0
  }
@end

@! ----------------------------------------------------------------------------
@! 3. Auto-Commit Single Statement CRUD Operations
@! ----------------------------------------------------------------------------

@! Point query: retrieves value by key from in-memory pages
@fn maya_db_get(db, key)
  @if db.is_open == 0
    return ""
  @end
  db.stats_gets = db.stats_gets + 1
  return btree_get(db.tree[0], key, "")
@end

@fn db_get(db: Database, key)
  return maya_db_get(db, key)
@end

@! Auto-commit PUT: enforces strict Write-Ahead Invariant
@fn db_put(db: Database, key, val)
  @if db.is_open == 0
    return 0
  @end

  tx_id = db.next_tx_id
  db.next_tx_id = db.next_tx_id + 1

  @! 1. Write-Ahead Invariant: log operation and commit to WAL, then fsync
  wal_append_put(db.wal, tx_id, key, val)
  wal_append_commit(db.wal, tx_id)
  wal_sync(db.wal)

  @! 2. Apply mutation to B+Tree
  db.tree[0] = btree_insert(db.tree[0], key, val)

  db.stats_puts = db.stats_puts + 1
  db.ops_since_checkpoint = db.ops_since_checkpoint + 1

  @if db.ops_since_checkpoint >= db.auto_checkpoint_ops
    db_checkpoint(db)
  @end

  return 1
@end

@! Auto-commit DELETE: enforces strict Write-Ahead Invariant
@fn db_delete(db: Database, key)
  @if db.is_open == 0
    return 0
  @end

  tx_id = db.next_tx_id
  db.next_tx_id = db.next_tx_id + 1

  @! 1. Write-Ahead Invariant: log delete and commit to WAL, then fsync
  wal_append_del(db.wal, tx_id, key)
  wal_append_commit(db.wal, tx_id)
  wal_sync(db.wal)

  @! 2. Apply deletion to B+Tree
  db.tree[0] = btree_delete(db.tree[0], key)

  db.stats_deletes = db.stats_deletes + 1
  db.ops_since_checkpoint = db.ops_since_checkpoint + 1

  @if db.ops_since_checkpoint >= db.auto_checkpoint_ops
    db_checkpoint(db)
  @end

  return 1
@end

@! Range scan: returns array of { key, value } records in [start_key, end_key]
@fn db_scan(db: Database, start_key, end_key, limit)
  @if db.is_open == 0
    return []
  @end
  db.stats_scans = db.stats_scans + 1
  return btree_scan(db.tree[0], start_key, end_key, limit)
@end

@! ----------------------------------------------------------------------------
@! 4. Multi-Statement ACID Transactions
@! ----------------------------------------------------------------------------

@! Begins an explicit multi-statement transaction
@fn db_begin(db: Database)
  return tx_begin(db)
@end

@! ----------------------------------------------------------------------------
@! 5. Checkpointing & Maintenance
@! ----------------------------------------------------------------------------

@! Flushes all dirty buffer pool frames, logs CHECKPOINT record, and truncates WAL
@fn db_checkpoint(db: Database)
  @if db.is_open == 0
    return 0
  @end

  @! 1. Flush all dirty pages to the database file
  buffer_pool_flush_all(db.pool)

  @! 2. Truncate WAL file
  wal_truncate(db.wal)

  @! 3. Append CHECKPOINT record to fresh WAL
  wal_append_checkpoint(db.wal, db.wal.last_lsn)
  wal_sync(db.wal)

  db.ops_since_checkpoint = 0
  return 1
@end

@! Verifies structural B+Tree invariants
@fn db_verify(db: Database)
  @if db.is_open == 0
    return 0
  @end
  return btree_verify(db.tree[0])
@end

@! Counts total active key-value pairs
@fn db_count(db: Database)
  @if db.is_open == 0
    return 0
  @end
  return btree_count(db.tree[0])
@end

@! Returns runtime telemetry metrics
@fn db_stats(db: Database)
  pool = db.pool
  wal = db.wal
  return {
    puts: db.stats_puts,
    deletes: db.stats_deletes,
    gets: db.stats_gets,
    scans: db.stats_scans,
    pool_hits: pool.stats_hits,
    pool_misses: pool.stats_misses,
    pool_flushes: pool.stats_flushes,
    pool_evictions: pool.stats_evictions,
    wal_last_lsn: wal.last_lsn
  }
@end

@! Closes database gracefully: flushes pages, truncates WAL, closes file descriptors
@fn db_close(db: Database)
  @if db.is_open == 0
    return 1
  @end

  db_checkpoint(db)
  wal_close(db.wal)
  buffer_pool_close(db.pool)

  db.is_open = 0
  return 1
@end
