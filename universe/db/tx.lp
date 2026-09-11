@! ============================================================================
@! LIPI UNIVERSE DB — ACID TRANSACTION ENGINE (universe/db/tx.maya)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! Staged Write-Set, Read-Your-Own-Writes, Atomic Commit & Instant Rollback
@! Enforces Strict Write-Ahead Invariant (WAL fsync before in-memory tree mutation)
@! ============================================================================

import "universe/core/collections"
import "universe/core/string"
import "universe/db/btree"
import "universe/db/wal"

@! ----------------------------------------------------------------------------
@! 1. Constants & Transaction States
@! ----------------------------------------------------------------------------
@fn TX_STATE_ACTIVE() return 1 @end
@fn TX_STATE_COMMITTED() return 2 @end
@fn TX_STATE_ABORTED() return 3 @end

@fn TX_OP_PUT() return 1 @end
@fn TX_OP_DEL() return 2 @end
@fn TX_OP_COMMIT() return 3 @end
@fn TX_OP_CHECKPOINT() return 4 @end
@fn TX_OP_ROLLBACK() return 5 @end

@! ----------------------------------------------------------------------------
@! 2. Data Structures
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

@struct TxOp
  key: string
  value: string
  op_type: i64
  tx_id: i64
  lsn: i64
@end

@struct Transaction
  tx_id: i64
  db: Database
  state: array
  operations: array
  start_time: i64
@end

@! ----------------------------------------------------------------------------
@! 3. Transaction Lifecycle API
@! ----------------------------------------------------------------------------

@! Begins a new ACID transaction with unique monotonic TxID
@fn tx_begin(db: Database)
  tid = db.next_tx_id
  db.next_tx_id = db.next_tx_id + 1
  ops = []
  st = [TX_STATE_ACTIVE()]
  return {
    tx_id: tid,
    db: db,
    state: st,
    operations: ops,
    start_time: clock_ms()
  }
@end

@! Stages a PUT operation within the active transaction write set
@fn tx_put(tx: Transaction, key, value)
  @if tx.state[0] != TX_STATE_ACTIVE()
    return 0
  @end
  op = { key: key, value: value, op_type: TX_OP_PUT(), tx_id: tx.tx_id, lsn: 0 }
  tx.operations = tx.operations.push(op)
  return 1
@end

@! Stages a DELETE operation within the active transaction write set
@fn tx_delete(tx: Transaction, key)
  @if tx.state[0] != TX_STATE_ACTIVE()
    return 0
  @end
  op = { key: key, value: "", op_type: TX_OP_DEL(), tx_id: tx.tx_id, lsn: 0 }
  tx.operations = tx.operations.push(op)
  return 1
@end

@! Point query respecting Read-Your-Own-Writes within transaction
@fn tx_get(tx: Transaction, key, default_val)
  num_items = tx.operations.len()
  i = num_items - 1
  @while i >= 0
    op: TxOp = tx.operations[i]
    @if str_eq(op.key, key) == 1
      @if op.op_type == TX_OP_PUT()
        return op.value
      @elif op.op_type == TX_OP_DEL()
        return default_val
      @end
    @end
    i = i - 1
  @end
  db: Database = tx.db
  return btree_get(db.tree[0], key, default_val)
@end

@! Commits transaction with Write-Ahead Log durability guarantee
@fn tx_commit(tx: Transaction)
  @if tx.state[0] != TX_STATE_ACTIVE()
    return 0
  @end

  num_items = tx.operations.len()
  @if num_items == 0
    tx.state[0] = TX_STATE_COMMITTED()
    return 1
  @end

  db: Database = tx.db
  wal: Wal = db.wal

  @! 1. Append staged operations to WAL
  i = 0
  @while i < num_items
    op: TxOp = tx.operations[i]
    @if op.op_type == TX_OP_PUT()
      wal_append_put(wal, tx.tx_id, op.key, op.value)
    @elif op.op_type == TX_OP_DEL()
      wal_append_del(wal, tx.tx_id, op.key)
    @end
    i = i + 1
  @end

  @! 2. Append Commit record to WAL
  wal_append_commit(wal, tx.tx_id)

  @! 3. Fsync WAL to stable storage (Write-Ahead Invariant)
  wal_sync(wal)

  @! 4. Apply operations to in-memory B+Tree pages
  i = 0
  @while i < num_items
    op: TxOp = tx.operations[i]
    @if op.op_type == TX_OP_PUT()
      db.tree[0] = btree_insert(db.tree[0], op.key, op.value)
    @elif op.op_type == TX_OP_DEL()
      db.tree[0] = btree_delete(db.tree[0], op.key)
    @end
    i = i + 1
  @end

  tx.state[0] = TX_STATE_COMMITTED()
  return 1
@end

@! Rolls back and aborts active transaction without writing to WAL or modifying B+Tree
@fn tx_rollback(tx: Transaction)
  @if tx.state[0] != TX_STATE_ACTIVE()
    return 0
  @end
  tx.operations = []
  tx.state[0] = TX_STATE_ABORTED()
  return 1
@end

@! ----------------------------------------------------------------------------
@! 4. Transaction State Query Helpers
@! ----------------------------------------------------------------------------
@fn tx_is_active(tx: Transaction) return tx.state[0] == TX_STATE_ACTIVE() @end
@fn tx_is_committed(tx: Transaction) return tx.state[0] == TX_STATE_COMMITTED() @end
@fn tx_is_aborted(tx: Transaction) return tx.state[0] == TX_STATE_ABORTED() @end
@fn tx_id(tx: Transaction) return tx.tx_id @end
