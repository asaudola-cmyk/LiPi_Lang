@! ============================================================================
@! MAYA UNIVERSE DB — EMPIRICAL WAL & CRASH RECOVERY TEST SUITE
@! File: tests/universe/test_db_wal_crash.maya
@! 100% Pure Maya Native Implementation Verification — Zero External Mocks
@! ============================================================================

import "universe/os/syscalls"
import "universe/os/process"
import "universe/os/fs"
import "universe/core/collections"
import "universe/core/string"
import "universe/db/page"
import "universe/db/buffer"
import "universe/db/btree"
import "universe/db/wal"
import "universe/db/tx"
import "universe/db/recovery"
import "universe/db/engine"

@fn assert_true(cond, msg)
  @if cond == 0
    println("  [FAIL] Assertion failed: " + msg)
    return 0
  @end
  return 1
@end

@fn assert_eq_int(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected " + expected.to_str() + ", got " + actual.to_str())
    return 0
  @end
  return 1
@end

@fn assert_eq_str(actual, expected, msg)
  @if actual != expected
    println("  [FAIL] " + msg + " -> Expected '" + expected + "', got '" + actual + "'")
    return 0
  @end
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 1: Binary WAL Framing & CRC-32 Verification
@! ----------------------------------------------------------------------------
@fn test_wal_binary_encoding_and_crc()
  wal_path = "/tmp/test_maya_wal_crc.wal"
  sys_unlink(wal_path)

  wal = wal_open(wal_path)
  @if assert_true(wal.fd >= 0, "WAL open valid file descriptor") == 0 return 0 @end

  lsn1 = wal_append_put(wal, 1, "k1", "v1")
  lsn2 = wal_append_put(wal, 1, "k2", "v2")
  lsn3 = wal_append_commit(wal, 1)
  wal_sync(wal)
  wal_close(wal)

  @! Verify file size is 32*3 + (2+2) + (2+2) = 96 + 8 = 104 bytes
  fd = sys_open(wal_path, 66, 420)
  fsize = sys_lseek(fd, 0, 2)
  sys_close(fd)
  @if assert_eq_int(fsize, 104, "WAL file byte length") == 0 return 0 @end

  @! Scan and verify records
  scan_res = recovery_scan_wal(wal_path)
  @if assert_eq_int(scan_res.total_records, 3, "Total scanned records") == 0 return 0 @end
  @if assert_eq_int(scan_res.committed_txs.len(), 1, "Committed Tx count") == 0 return 0 @end
  @if assert_eq_int(scan_res.last_lsn, 3, "Highest LSN") == 0 return 0 @end
  @if assert_eq_int(scan_res.has_torn_write, 0, "No torn write detected") == 0 return 0 @end

  sys_unlink(wal_path)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 2: Auto-Commit Durability under Write-Ahead Invariant
@! ----------------------------------------------------------------------------
@fn test_engine_auto_commit_durability()
  db_path = "/tmp/test_maya_engine_autocommit.db"
  wal_path = db_path + ".wal"
  sys_unlink(db_path)
  sys_unlink(wal_path)

  db = db_open(db_path, 16)
  @if assert_eq_int(db.is_open, 1, "DB open status") == 0 return 0 @end

  @! Insert 20 keys
  i = 0
  @while i < 20
    k = "key_" + (100 + i).to_str()
    v = "val_" + i.to_str()
    db_put(db, k, v)
    i = i + 1
  @end

  @! Query point lookups
  @if assert_eq_str(db_get(db, "key_100"), "val_0", "Lookup key_100") == 0 return 0 @end
  @if assert_eq_str(db_get(db, "key_119"), "val_19", "Lookup key_119") == 0 return 0 @end
  @if assert_eq_str(db_get(db, "key_999"), "", "Lookup non-existent key") == 0 return 0 @end

  @! Delete 3 keys
  db_delete(db, "key_100")
  db_delete(db, "key_102")
  db_delete(db, "key_104")

  @if assert_eq_str(db_get(db, "key_100"), "", "Deleted key_100") == 0 return 0 @end
  @if assert_eq_str(db_get(db, "key_101"), "val_1", "Retained key_101") == 0 return 0 @end

  @! Range scan [key_105 .. key_110] (6 items)
  scan_res = db_scan(db, "key_105", "key_110", 10)
  @if assert_eq_int(scan_res.len(), 6, "Scan count [key_105..key_110]") == 0 return 0 @end
  @if assert_eq_str(scan_res[0].key, "key_105", "Scan first key") == 0 return 0 @end
  @if assert_eq_str(scan_res[5].key, "key_110", "Scan last key") == 0 return 0 @end

  db_close(db)

  @! Cold reopen and verify 17 remaining keys
  db2 = db_open(db_path, 16)
  @if assert_eq_int(db_count(db2), 17, "Count after reopen is 17") == 0
    db_close(db2)
    return 0
  @end
  @if assert_eq_int(db_verify(db2), 1, "Tree valid after reopen") == 0
    db_close(db2)
    return 0
  @end

  db_close(db2)
  sys_unlink(db_path)
  sys_unlink(wal_path)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 3: Multi-Statement ACID Transactions (Commit & Rollback)
@! ----------------------------------------------------------------------------
@fn test_acid_transactions_commit_rollback()
  db_path = "/tmp/test_maya_acid_tx.db"
  wal_path = db_path + ".wal"
  sys_unlink(db_path)
  sys_unlink(wal_path)

  db = db_open(db_path, 16)

  @! Transaction 1: Commit
  tx1 = db_begin(db)
  tx_put(tx1, "account:alice", "1000")
  tx_put(tx1, "account:bob", "500")
  tx_commit(tx1)

  @if assert_eq_str(db_get(db, "account:alice"), "1000", "Alice balance after Tx1 commit") == 0 return 0 @end
  @if assert_eq_str(db_get(db, "account:bob"), "500", "Bob balance after Tx1 commit") == 0 return 0 @end

  @! Transaction 2: Read-Your-Own-Writes & Rollback
  tx2 = db_begin(db)
  tx_put(tx2, "account:alice", "900")
  tx_put(tx2, "account:bob", "600")
  tx_put(tx2, "account:charlie", "100")

  @! Read-Your-Own-Writes check
  @if assert_eq_str(tx_get(tx2, "account:alice", ""), "900", "tx2 sees own write for Alice") == 0 return 0 @end
  @if assert_eq_str(tx_get(tx2, "account:charlie", ""), "100", "tx2 sees own write for Charlie") == 0 return 0 @end

  tx_rollback(tx2)

  @! Verify state is unchanged
  @if assert_eq_str(db_get(db, "account:alice"), "1000", "Alice balance after Tx2 rollback") == 0 return 0 @end
  @if assert_eq_str(db_get(db, "account:bob"), "500", "Bob balance after Tx2 rollback") == 0 return 0 @end
  @if assert_eq_str(db_get(db, "account:charlie"), "", "Charlie non-existent after Tx2 rollback") == 0 return 0 @end

  @! Interleaved concurrent transactions
  txA = db_begin(db)
  txB = db_begin(db)

  tx_put(txA, "alpha", "AAA")
  tx_put(txB, "beta", "BBB")

  tx_commit(txA)
  tx_rollback(txB)

  @if assert_eq_str(db_get(db, "alpha"), "AAA", "txA alpha committed") == 0 return 0 @end
  @if assert_eq_str(db_get(db, "beta"), "", "txB beta rolled back") == 0 return 0 @end

  db_close(db)
  sys_unlink(db_path)
  sys_unlink(wal_path)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 4: Real Crash Simulation via process_fork() and Redo Recovery
@! ----------------------------------------------------------------------------
@fn test_simulated_process_crash_recovery()
  db_path = "/tmp/test_maya_crash_proc.db"
  wal_path = db_path + ".wal"
  sys_unlink(db_path)
  sys_unlink(wal_path)

  child_pid = process_fork()
  @if child_pid == 0
    @! Child process branch: write 50 items and terminate abruptly
    db = db_open(db_path, 4)
    i = 0
    @while i < 50
      k = "crash_item_" + i.to_str()
      v = "payload_content_" + (i * 7).to_str()
      db_put(db, k, v)
      i = i + 1
    @end

    @! Simulate sudden ungraceful crash: exit immediately WITHOUT calling db_close()
    exit(0)
  @elif child_pid > 0
    @! Parent process branch: wait for child
    process_wait(child_pid)

    @! Reopen DB: startup redo recovery must parse WAL and restore all 50 items
    db2 = db_open(db_path, 16)
    @if assert_eq_int(db2.is_open, 1, "DB reopen status") == 0 return 0 @end

    i = 0
    all_ok = 1
    @while i < 50
      k = "crash_item_" + i.to_str()
      expected_v = "payload_content_" + (i * 7).to_str()
      v = db_get(db2, k)
      @if v != expected_v
        all_ok = 0
        println("  [FAIL] Redo recovery missing item: " + k + " (got '" + v + "', expected '" + expected_v + "')")
        break
      @end
      i = i + 1
    @end

    @if assert_eq_int(all_ok, 1, "All 50 committed items recovered from WAL after crash") == 0
      db_close(db2)
      return 0
    @end

    @if assert_eq_int(db_verify(db2), 1, "Tree invariant valid after recovery") == 0
      db_close(db2)
      return 0
    @end

    db_close(db2)
    sys_unlink(db_path)
    sys_unlink(wal_path)
    return 1
  @end

  return 0
@end

@! ----------------------------------------------------------------------------
@! Test 5: Uncommitted Transaction Rollback on Simulated Process Crash
@! ----------------------------------------------------------------------------
@fn test_uncommitted_crash_immunity()
  db_path = "/tmp/test_maya_uncommitted_crash.db"
  wal_path = db_path + ".wal"
  sys_unlink(db_path)
  sys_unlink(wal_path)

  child_pid = process_fork()
  @if child_pid == 0
    db = db_open(db_path, 8)
    @! Committed tx
    tx1 = db_begin(db)
    tx_put(tx1, "safe_key", "safe_val")
    tx_commit(tx1)

    @! Uncommitted tx: write directly to WAL then crash
    wal_append_put(db.wal, 999, "corrupt_key_1", "bad_val_1")
    wal_append_put(db.wal, 999, "corrupt_key_2", "bad_val_2")
    wal_sync(db.wal)

    @! Sudden exit without committing tx 999
    exit(0)
  @elif child_pid > 0
    process_wait(child_pid)

    db2 = db_open(db_path, 8)
    @if assert_eq_str(db_get(db2, "safe_key"), "safe_val", "Committed key recovered") == 0
      db_close(db2)
      return 0
    @end
    @if assert_eq_str(db_get(db2, "corrupt_key_1"), "", "Uncommitted key 1 discarded") == 0
      db_close(db2)
      return 0
    @end
    @if assert_eq_str(db_get(db2, "corrupt_key_2"), "", "Uncommitted key 2 discarded") == 0
      db_close(db2)
      return 0
    @end

    db_close(db2)
    sys_unlink(db_path)
    sys_unlink(wal_path)
    return 1
  @end

  return 0
@end

@! ----------------------------------------------------------------------------
@! Test 6: Checkpointing & Safe WAL Truncation
@! ----------------------------------------------------------------------------
@fn test_checkpoint_and_truncation()
  db_path = "/tmp/test_maya_chkpt_trunc.db"
  wal_path = db_path + ".wal"
  sys_unlink(db_path)
  sys_unlink(wal_path)

  db = db_open(db_path, 16)
  i = 0
  @while i < 100
    db_put(db, "item_" + i.to_str(), "data_" + i.to_str())
    i = i + 1
  @end

  @! Trigger checkpoint
  db_checkpoint(db)

  @! Verify WAL file is truncated (< 100 bytes)
  fd = sys_open(wal_path, 0, 0)
  wal_sz = sys_lseek(fd, 0, 2)
  sys_close(fd)
  @if assert_true(wal_sz < 100, "WAL truncated to compact size after checkpoint") == 0
    db_close(db)
    return 0
  @end

  @! Add 30 more items after checkpoint
  i = 100
  @while i < 130
    db_put(db, "item_" + i.to_str(), "data_" + i.to_str())
    i = i + 1
  @end

  db_close(db)

  @! Cold reopen and verify all 130 items exist
  db2 = db_open(db_path, 16)
  @if assert_eq_int(db_count(db2), 130, "Total count after checkpoint and post-checkpoint inserts") == 0
    db_close(db2)
    return 0
  @end

  db_close(db2)
  sys_unlink(db_path)
  sys_unlink(wal_path)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 7: Torn Write / Log File Tail Corruption Fault-Tolerance
@! ----------------------------------------------------------------------------
@fn test_torn_write_and_crc_corruption()
  db_path = "/tmp/test_maya_torn_write.db"
  wal_path = db_path + ".wal"
  sys_unlink(db_path)
  sys_unlink(wal_path)

  db = db_open(db_path, 8)
  db_put(db, "gold_1", "solid_gold_value_1")
  db_put(db, "gold_2", "solid_gold_value_2")
  db_close(db)

  @! Inject 15 bytes of trailing corrupted garbage into the WAL file
  fd = sys_open(wal_path, 66, 420)  @! O_RDWR | O_CREAT
  sys_lseek(fd, 0, 2)              @! SEEK_END
  garbage_buf = page_new()
  page_write_u32(garbage_buf, 0, 1463897170) @! "WALR"
  page_write_u32(garbage_buf, 4, 999)        @! Corrupted LSN
  sys_write(fd, page_data_ptr(garbage_buf), 15) @! Incomplete truncated header
  sys_fsync(fd)
  sys_close(fd)

  @! Reopen DB: recovery must detect CRC mismatch / truncated record and recover valid gold records
  db2 = db_open(db_path, 8)
  @if assert_eq_str(db_get(db2, "gold_1"), "solid_gold_value_1", "Gold 1 recovered despite trailing garbage") == 0
    db_close(db2)
    return 0
  @end
  @if assert_eq_str(db_get(db2, "gold_2"), "solid_gold_value_2", "Gold 2 recovered despite trailing garbage") == 0
    db_close(db2)
    return 0
  @end

  db_close(db2)
  sys_unlink(db_path)
  sys_unlink(wal_path)
  return 1
@end

@! ----------------------------------------------------------------------------
@! Test 8: Sequential Range Scans on Recovered Database
@! ----------------------------------------------------------------------------
@fn test_range_scans_on_recovered_database()
  db_path = "/tmp/test_maya_range_recovery.db"
  wal_path = db_path + ".wal"
  sys_unlink(db_path)
  sys_unlink(wal_path)

  child_pid = process_fork()
  @if child_pid == 0
    db = db_open(db_path, 8)
    i = 0
    @while i < 80
      db_put(db, "rec_" + (100 + i).to_str(), "val_" + i.to_str())
      i = i + 1
    @end
    exit(0)
  @elif child_pid > 0
    process_wait(child_pid)

    db2 = db_open(db_path, 16)
    @if assert_eq_int(db2.is_open, 1, "DB reopen status") == 0 return 0 @end

    @! Range scan [rec_120 .. rec_149] (30 items)
    scan_res = db_scan(db2, "rec_120", "rec_149", 50)
    @if assert_eq_int(scan_res.len(), 30, "Scan 30 items on recovered DB") == 0
      db_close(db2)
      return 0
    @end
    @if assert_eq_str(scan_res[0].key, "rec_120", "Scan first key") == 0
      db_close(db2)
      return 0
    @end
    @if assert_eq_str(scan_res[29].key, "rec_149", "Scan last key") == 0
      db_close(db2)
      return 0
    @end

    db_close(db2)
    sys_unlink(db_path)
    sys_unlink(wal_path)
    return 1
  @end

  return 0
@end

@! ----------------------------------------------------------------------------
@! Test 9: 1,000-Record High-Throughput Transactional Benchmark
@! ----------------------------------------------------------------------------
@fn test_high_density_crash_benchmark()
  db_path = "/tmp/test_maya_benchmark_1000.db"
  wal_path = db_path + ".wal"
  sys_unlink(db_path)
  sys_unlink(wal_path)

  child_pid = process_fork()
  @if child_pid == 0
    db = db_open(db_path, 32)
    i = 0
    @while i < 1000
      k = "sensor_" + (10000 + i).to_str()
      v = "payload_telemetry_reading_value_" + i.to_str()
      db_put(db, k, v)
      i = i + 1
    @end
    exit(0)
  @elif child_pid > 0
    process_wait(child_pid)

    db2 = db_open(db_path, 32)
    @if assert_eq_int(db_count(db2), 1000, "1000 keys recovered from crash replay") == 0
      db_close(db2)
      return 0
    @end
    @if assert_eq_int(db_verify(db2), 1, "B+Tree verified sorted order across 1000 keys") == 0
      db_close(db2)
      return 0
    @end

    @! Spot check boundaries
    @if assert_eq_str(db_get(db2, "sensor_10000"), "payload_telemetry_reading_value_0", "First key") == 0
      db_close(db2)
      return 0
    @end
    @if assert_eq_str(db_get(db2, "sensor_10500"), "payload_telemetry_reading_value_500", "Mid key") == 0
      db_close(db2)
      return 0
    @end
    @if assert_eq_str(db_get(db2, "sensor_10999"), "payload_telemetry_reading_value_999", "Last key") == 0
      db_close(db2)
      return 0
    @end

    db_close(db2)
    sys_unlink(db_path)
    sys_unlink(wal_path)
    return 1
  @end

  return 0
@end

@! ----------------------------------------------------------------------------
@! Test 10: Multi-Cycle Crash-and-Restart Durability Loop
@! ----------------------------------------------------------------------------
@fn test_multi_cycle_crash_restart_loop()
  db_path = "/tmp/test_maya_multicycle.db"
  wal_path = db_path + ".wal"
  sys_unlink(db_path)
  sys_unlink(wal_path)

  @! Cycle 1: Insert 40 keys & crash
  c1_pid = process_fork()
  @if c1_pid == 0
    db = db_open(db_path, 8)
    i = 0
    @while i < 40
      db_put(db, "cycle_k_" + i.to_str(), "val_c1_" + i.to_str())
      i = i + 1
    @end
    exit(0)
  @elif c1_pid > 0
    process_wait(c1_pid)

    @! Cycle 2: Recover, mutate, delete & crash
    c2_pid = process_fork()
    @if c2_pid == 0
      db = db_open(db_path, 8)
      @! Update 10 keys
      i = 0
      @while i < 10
        db_put(db, "cycle_k_" + i.to_str(), "val_c2_updated_" + i.to_str())
        i = i + 1
      @end
      @! Delete 10 keys
      i = 10
      @while i < 20
        db_delete(db, "cycle_k_" + i.to_str())
        i = i + 1
      @end
      @! Insert 20 new keys
      i = 40
      @while i < 60
        db_put(db, "cycle_k_" + i.to_str(), "val_c2_new_" + i.to_str())
        i = i + 1
      @end
      exit(0)
    @elif c2_pid > 0
      process_wait(c2_pid)

      @! Final Recovery & Verification
      db_final = db_open(db_path, 16)
      @if assert_eq_int(db_count(db_final), 50, "Final count is 50 (40 - 10 + 20)") == 0
        db_close(db_final)
        return 0
      @end
      @if assert_eq_str(db_get(db_final, "cycle_k_0"), "val_c2_updated_0", "Updated key 0") == 0
        db_close(db_final)
        return 0
      @end
      @if assert_eq_str(db_get(db_final, "cycle_k_15"), "", "Deleted key 15") == 0
        db_close(db_final)
        return 0
      @end
      @if assert_eq_str(db_get(db_final, "cycle_k_59"), "val_c2_new_59", "New key 59") == 0
        db_close(db_final)
        return 0
      @end
      @if assert_eq_int(db_verify(db_final), 1, "Final tree verification") == 0
        db_close(db_final)
        return 0
      @end

      db_close(db_final)
      sys_unlink(db_path)
      sys_unlink(wal_path)
      return 1
    @end
  @end

  return 0
@end

@! ----------------------------------------------------------------------------
@! Master Test Runner
@! ----------------------------------------------------------------------------
@fn main()
  println("=================================================================")
  println("▶ [UNIVERSE E2E] Module: universe/db/engine & WAL Crash Recovery")
  println("=================================================================")

  total = 10
  passed = 0
  failed = 0

  @if test_wal_binary_encoding_and_crc() == 1
    println("  [PASS] Test 1: Binary WAL Framing & CRC-32 Verification")
    passed = passed + 1
  @else
    println("  [FAIL] Test 1: Binary WAL Framing & CRC-32 Verification")
    failed = failed + 1
  @end

  @if test_engine_auto_commit_durability() == 1
    println("  [PASS] Test 2: Auto-Commit Durability under Write-Ahead Invariant")
    passed = passed + 1
  @else
    println("  [FAIL] Test 2: Auto-Commit Durability under Write-Ahead Invariant")
    failed = failed + 1
  @end

  @if test_acid_transactions_commit_rollback() == 1
    println("  [PASS] Test 3: Multi-Statement ACID Transactions (Commit & Rollback)")
    passed = passed + 1
  @else
    println("  [FAIL] Test 3: Multi-Statement ACID Transactions (Commit & Rollback)")
    failed = failed + 1
  @end

  @if test_simulated_process_crash_recovery() == 1
    println("  [PASS] Test 4: Real Crash Simulation via process_fork() and Redo Recovery")
    passed = passed + 1
  @else
    println("  [FAIL] Test 4: Real Crash Simulation via process_fork() and Redo Recovery")
    failed = failed + 1
  @end

  @if test_uncommitted_crash_immunity() == 1
    println("  [PASS] Test 5: Uncommitted Transaction Rollback on Simulated Process Crash")
    passed = passed + 1
  @else
    println("  [FAIL] Test 5: Uncommitted Transaction Rollback on Simulated Process Crash")
    failed = failed + 1
  @end

  @if test_checkpoint_and_truncation() == 1
    println("  [PASS] Test 6: Checkpointing & Safe WAL Truncation")
    passed = passed + 1
  @else
    println("  [FAIL] Test 6: Checkpointing & Safe WAL Truncation")
    failed = failed + 1
  @end

  @if test_torn_write_and_crc_corruption() == 1
    println("  [PASS] Test 7: Torn Write / Log File Tail Corruption Fault-Tolerance")
    passed = passed + 1
  @else
    println("  [FAIL] Test 7: Torn Write / Log File Tail Corruption Fault-Tolerance")
    failed = failed + 1
  @end

  @if test_range_scans_on_recovered_database() == 1
    println("  [PASS] Test 8: Sequential Range Scans on Recovered Database")
    passed = passed + 1
  @else
    println("  [FAIL] Test 8: Sequential Range Scans on Recovered Database")
    failed = failed + 1
  @end

  @if test_high_density_crash_benchmark() == 1
    println("  [PASS] Test 9: 1,000-Record High-Throughput Transactional Benchmark")
    passed = passed + 1
  @else
    println("  [FAIL] Test 9: 1,000-Record High-Throughput Transactional Benchmark")
    failed = failed + 1
  @end

  @if test_multi_cycle_crash_restart_loop() == 1
    println("  [PASS] Test 10: Multi-Cycle Crash-and-Restart Durability Loop")
    passed = passed + 1
  @else
    println("  [FAIL] Test 10: Multi-Cycle Crash-and-Restart Durability Loop")
    failed = failed + 1
  @end

  println("-----------------------------------------------------------------")
  println("WAL & Crash Recovery Summary: " + passed.to_str() + "/" + total.to_str() + " passed")
  @if failed == 0
    println("✓ universe/db/engine & WAL Crash Recovery E2E Test Suite PASSED")
    return 0
  @else
    println("✗ universe/db/engine & WAL Crash Recovery E2E Test Suite FAILED (" + failed.to_str() + " errors)")
    return 1
  @end
@end
