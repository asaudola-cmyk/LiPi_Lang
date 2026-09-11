@! ============================================================================
@! MAYA UNIVERSE DB — CRASH RECOVERY & REDO SCANNER (universe/db/recovery.maya)
@! 100% Written in Pure Maya Language — Zero External C Dependencies
@! 5-Phase Durability Protocol: Scan, Header Verify, CRC Check, Extract Committed,
@! Redo Replay Mutations into B+Tree Pages, and Buffer Pool Sync
@! Robust to Incomplete Logs, Process Crashes, and Torn Writes
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

@! Helper struct for zero-copy memory address extraction
@struct NativeArray
  length: 0
  capacity: 0
  element_size: 0
  data_ptr: 0
@end

@struct WalLogEntry
  key: ""
  value: ""
  op_type: 0
  tx_id: 0
  lsn: 0
@end

@struct RecoveryScanResult
  valid_records: 0
  committed_txs: 0
  last_checkpoint_lsn: 0
  last_lsn: 0
  last_tx_id: 0
  has_torn_write: 0
  total_records: 0
@end

@struct RecoveryResult
  replayed_txs: 0
  replayed_ops: 0
  last_lsn: 0
  last_tx_id: 0
@end

@! ----------------------------------------------------------------------------
@! 2. WAL Scanner & Validation Engine
@! ----------------------------------------------------------------------------

@! Scans a WAL file, validates 32-byte header magic and CRC-32 checksums,
@! and isolates committed transactions while tolerating torn crash boundaries
@fn recovery_scan_wal(wal_path)
  fd = sys_open(wal_path, 2, 420)  @! O_RDWR = 2
  @if fd < 0
    return {
      valid_records: [],
      committed_txs: [],
      last_checkpoint_lsn: 0,
      last_lsn: 0,
      last_tx_id: 0,
      has_torn_write: 0,
      total_records: 0
    }
  @end

  file_len = sys_lseek(fd, 0, 2)  @! SEEK_END = 2
  @if file_len < 32
    sys_close(fd)
    return {
      valid_records: [],
      committed_txs: [],
      last_checkpoint_lsn: 0,
      last_lsn: 0,
      last_tx_id: 0,
      has_torn_write: 0,
      total_records: 0
    }
  @end

  @! Read the entire file into memory via mmap
  raw_mmap = sys_mmap(0, file_len, 3, 34, 0 - 1, 0)
  sys_lseek(fd, 0, 0)
  nread = sys_read(fd, raw_mmap, file_len)
  sys_close(fd)

  buf = []
  b_i = 0
  @while b_i < file_len
    buf = buf.push(sys_peek8(raw_mmap + b_i) & 255)
    b_i = b_i + 1
  @end

  crc_table = crc32_table_init()

  valid_records = []
  committed_txs = []
  last_checkpoint_lsn = 0
  highest_lsn = 0
  highest_tx_id = 0
  has_torn = 0
  total_cnt = 0
  scan_active = 1

  @while pos + 32 <= file_len && scan_active == 1
    magic = page_read_u32(buf, pos)
    @if magic != WAL_MAGIC()
      has_torn = 1
      scan_active = 0
    @else
      lsn = page_read_u64(buf, pos + 4)
      tx_id = page_read_u64(buf, pos + 12)
      op_type = page_read_u8(buf, pos + 20)
      reserved = page_read_u8(buf, pos + 21)
      k_len = page_read_u16(buf, pos + 22)
      v_len = page_read_u32(buf, pos + 24)
      expected_crc = page_read_u32(buf, pos + 28)

      rec_total_len = 32 + k_len + v_len
      @if pos + rec_total_len > file_len
        @! Incomplete torn record at end of file (power cut / crash mid-write)
        has_torn = 1
        scan_active = 0
      @else
        @! Extract payload
        rec_buf = wal_buffer_new(rec_total_len)
        b_idx = 0
        @while b_idx < rec_total_len
          byte_val = page_read_u8(buf, pos + b_idx)
          page_write_u8(rec_buf, b_idx, byte_val)
          b_idx = b_idx + 1
        @end

        @! Checksum validation
        computed_crc = wal_compute_record_crc(crc_table, rec_buf, rec_total_len)
        @if computed_crc != expected_crc
          @! Corrupted record detected — stop log scan cleanly at first bad boundary
          has_torn = 1
          scan_active = 0
        @else
          k = ""
          @if k_len > 0
            k = page_read_str(buf, pos + 32, k_len)
          @end

          v = ""
          @if v_len > 0
            v = page_read_str(buf, pos + 32 + k_len, v_len)
          @end

          entry = {
            key: k,
            value: v,
            op_type: op_type,
            tx_id: tx_id,
            lsn: lsn
          }

          valid_records = valid_records.push(entry)
          total_cnt = total_cnt + 1

          @if lsn > highest_lsn
            highest_lsn = lsn
          @end
          @if tx_id > highest_tx_id
            highest_tx_id = tx_id
          @end

          @if op_type == OP_COMMIT()
            committed_txs = committed_txs.push(tx_id)
          @elif op_type == OP_CHECKPOINT()
            last_checkpoint_lsn = lsn
          @end

          pos = pos + rec_total_len
        @end
      @end
    @end
  @end

  return {
    valid_records: valid_records,
    committed_txs: committed_txs,
    last_checkpoint_lsn: last_checkpoint_lsn,
    last_lsn: highest_lsn,
    last_tx_id: highest_tx_id,
    has_torn_write: has_torn,
    total_records: total_cnt
  }
@end

@! ----------------------------------------------------------------------------
@! 3. Redo Mutation Replay Engine
@! ----------------------------------------------------------------------------

@! Replays committed PUT/DEL operations into B+Tree pages
@fn recovery_apply_redo(tree_ref, valid_records, committed_txs)
  replayed_txs = 0
  replayed_ops = 0
  last_lsn = 0
  last_tx_id = 0

  tx_count = committed_txs.len()
  rec_count = valid_records.len()

  i = 0
  @while i < rec_count
    rec = valid_records[i]

    @if rec.lsn > last_lsn
      last_lsn = rec.lsn
    @end
    @if rec.tx_id > last_tx_id
      last_tx_id = rec.tx_id
    @end

    @! Check if this record belongs to a committed transaction
    is_committed = 0
    t_idx = 0
    @while t_idx < tx_count && is_committed == 0
      @if committed_txs[t_idx] == rec.tx_id
        is_committed = 1
      @end
      t_idx = t_idx + 1
    @end

    @if is_committed == 1
      @if rec.op_type == OP_PUT()
        tree_ref[0] = btree_insert(tree_ref[0], rec.key, rec.value)
        replayed_ops = replayed_ops + 1
      @elif rec.op_type == OP_DEL()
        tree_ref[0] = btree_delete(tree_ref[0], rec.key)
        replayed_ops = replayed_ops + 1
      @end
    @end

    i = i + 1
  @end

  return {
    replayed_txs: tx_count,
    replayed_ops: replayed_ops,
    last_lsn: last_lsn,
    last_tx_id: last_tx_id
  }
@end

@! ----------------------------------------------------------------------------
@! 4. Master Recovery Entrypoint
@! ----------------------------------------------------------------------------

@! Coordinates WAL scan, committed transaction extraction, redo replay, and buffer flush
@fn wal_recover(wal_path, tree_ref, pool)
  scan_res = recovery_scan_wal(wal_path)
  @if scan_res.total_records == 0
    return {
      replayed_txs: 0,
      replayed_ops: 0,
      last_lsn: 0,
      last_tx_id: 0
    }
  @end

  redo_res = recovery_apply_redo(tree_ref, scan_res.valid_records, scan_res.committed_txs)
  @if redo_res.replayed_ops > 0
    buffer_pool_flush_all(pool)
  @end

  return redo_res
@end
