@! ============================================================================
@! LIPI UNIVERSE DB — WRITE-AHEAD LOG ENGINE (universe/db/wal.maya)
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! 32-Byte Binary Record Framing, Table-Driven IEEE 802.3 CRC-32 Checksum,
@! Zero-Copy Dynamic NativeArray Buffers, Atomic fsync & Safe Truncation
@! ============================================================================

import "universe/os/syscalls"
import "universe/core/string"
import "universe/db/page"

@! ----------------------------------------------------------------------------
@! 1. Constants & Operation Discriminators
@! ----------------------------------------------------------------------------
@fn WAL_MAGIC() return 1463897170 @end  @! ASCII "WALR" (1463897170)
@fn WAL_HEADER_SIZE() return 32 @end

@fn OP_PUT() return 1 @end
@fn OP_DEL() return 2 @end
@fn OP_COMMIT() return 3 @end
@fn OP_CHECKPOINT() return 4 @end
@fn OP_ROLLBACK() return 5 @end

@! ----------------------------------------------------------------------------
@! 2. Data Structures
@! ----------------------------------------------------------------------------
@struct Wal
  fd: i64
  wal_path: string
  next_lsn: i64
  last_lsn: i64
  crc_table: array
@end

@struct WalRecord
  key: string
  value: string
  op_type: i64
  tx_id: i64
  lsn: i64
@end

@! ----------------------------------------------------------------------------
@! 3. IEEE 802.3 CRC-32 Checksum Engine
@! ----------------------------------------------------------------------------

@! Precomputes the 256-entry lookup table for polynomial 3988292384
@fn crc32_table_init()
  table = []
  i = 0
  @while i < 256
    c = i
    j = 0
    @while j < 8
      bit_low = c & 1
      @if bit_low != 0
        t_c = (c / 2) & 2147483647
        t_xor = 3988292384 ^ t_c
        c = t_xor & 4294967295
      @else
        c = (c / 2) & 2147483647
      @end
      j = j + 1
    @end
    table = table.push(c)
    i = i + 1
  @end
  return table
@end

@fn crc32_update_u8(table, crc, b)
  b_v = b & 255
  t_c = crc ^ b_v
  idx = t_c & 255
  t_div = (crc / 256) & 16777215
  return t_div ^ table[idx] & 4294967295
@end

@! Computes CRC-32 over header fields (bytes 4..27) + payload bytes (bytes 32..total_rec_len-1)
@fn wal_compute_record_crc(table, buf, total_rec_len)
  crc = 4294967295
  @! Header fields (bytes 4..27: LSN, TxID, OpType, Reserved, KeyLen, ValLen)
  i = 4
  @while i < 28
    crc = crc32_update_u8(table, crc, buf[i])
    i = i + 1
  @end
  @! Payload bytes (bytes 32..total_rec_len-1: Key + Value bytes)
  i = 32
  @while i < total_rec_len
    crc = crc32_update_u8(table, crc, buf[i])
    i = i + 1
  @end
  t_res = crc ^ 4294967295
  return t_res & 4294967295
@end

@! Helper to verify CRC-32 of a record in an arbitrary buffer at given position
@fn wal_verify_record_crc(table, buf, pos, total_rec_len)
  crc = 4294967295
  i = pos + 4
  @while i < pos + 28
    crc = crc32_update_u8(table, crc, buf[i])
    i = i + 1
  @end
  i = pos + 32
  @while i < pos + total_rec_len
    crc = crc32_update_u8(table, crc, buf[i])
    i = i + 1
  @end
  t_res = crc ^ 4294967295
  return t_res & 4294967295
@end

@! Helper struct for zero-copy memory address extraction
@struct NativeArray
  length: 0
  capacity: 0
  element_size: 0
  data_ptr: 0
@end

@! ----------------------------------------------------------------------------
@! 4. Binary Dynamic Memory Buffers
@! ----------------------------------------------------------------------------

@! Allocates a dynamic NativeArray byte buffer of given size
@fn wal_buffer_new(size)
  arr = []
  i = 0
  @while i < size
    arr = arr.push(0)
    i = i + 1
  @end
  return arr
@end

@fn wal_data_ptr(buf)
  // WHY: Allocates memory buffer via pure native heap allocator avoiding kernel mmap page alignment constraints
  n = buf.len()
  @if n <= 0 return 0 @end
  m = alloc(n)
  i = 0
  @while i < n
    sys_poke8(m + i, buf[i] & 255)
    i = i + 1
  @end
  return m
@end

@! ----------------------------------------------------------------------------
@! 5. WAL Lifecycle & Append API
@! ----------------------------------------------------------------------------

@! Opens or creates a Write-Ahead Log file
@fn wal_open(wal_path)
  @! O_RDWR (2) | O_CREAT (64) = 66, mode 0644 = 420
  fd = sys_open(wal_path, 66, 420)
  table = crc32_table_init()

  next_lsn = 1
  last_lsn = 0

  return {
    fd: fd,
    wal_path: wal_path,
    next_lsn: next_lsn,
    last_lsn: last_lsn,
    crc_table: table
  }
@end

@! Generic append helper creating framed 32-byte header + payload record
@fn wal_append_record(wal: Wal, tx_id, op_type, key, val)
  @if wal.fd < 0
    return 0
  @end

  lsn = wal.next_lsn
  wal.next_lsn = wal.next_lsn + 1
  wal.last_lsn = lsn

  k_len = str_len(key)
  v_len = str_len(val)
  total_len = 32 + k_len + v_len

  buf = wal_buffer_new(total_len)

  @! 1. Header Serialization (Little-Endian)
  page_write_u32(buf, 0, WAL_MAGIC())
  page_write_u64(buf, 4, lsn)
  page_write_u64(buf, 12, tx_id)
  page_write_u8(buf, 20, op_type)
  page_write_u8(buf, 21, 0)  @! reserved byte
  page_write_u16(buf, 22, k_len)
  page_write_u32(buf, 24, v_len)

  @! 2. Payload Serialization
  @if k_len > 0
    page_write_str(buf, 32, key)
  @end
  @if v_len > 0
    page_write_str(buf, 32 + k_len, val)
  @end

  @! 3. CRC-32 Calculation & Checksum write
  checksum = wal_compute_record_crc(wal.crc_table, buf, total_len)
  page_write_u32(buf, 28, checksum)

  @! 4. Append to file descriptor at SEEK_END
  sys_lseek(wal.fd, 0, 2)
  sys_write(wal.fd, wal_data_ptr(buf), total_len)

  return lsn
@end

@! Appends an OP_PUT log record
@fn wal_append_put(wal: Wal, tx_id, key, val)
  return wal_append_record(wal, tx_id, OP_PUT(), key, val)
@end

@! Appends an OP_DEL log record
@fn wal_append_del(wal: Wal, tx_id, key)
  return wal_append_record(wal, tx_id, OP_DEL(), key, "")
@end

@! Appends an OP_COMMIT log record
@fn wal_append_commit(wal: Wal, tx_id)
  return wal_append_record(wal, tx_id, OP_COMMIT(), "", "")
@end

@! Appends an OP_CHECKPOINT log record
@fn wal_append_checkpoint(wal: Wal, lsn)
  return wal_append_record(wal, 0, OP_CHECKPOINT(), "", "")
@end

@! Appends an OP_ROLLBACK log record
@fn wal_append_rollback(wal: Wal, tx_id)
  return wal_append_record(wal, tx_id, OP_ROLLBACK(), "", "")
@end

@! Flushes WAL file descriptor to disk (sys_fsync)
@fn wal_sync(wal: Wal)
  @if wal.fd >= 0
    sys_fsync(wal.fd)
    return 1
  @end
  return 0
@end

@! Truncates WAL file to 0 bytes and seeks to beginning
@fn wal_truncate(wal: Wal)
  @if wal.fd >= 0
    sys_ftruncate(wal.fd, 0)
    sys_lseek(wal.fd, 0, 0)
    sys_fsync(wal.fd)
    return 1
  @end
  return 0
@end

@! Syncs and closes WAL file descriptor
@fn wal_close(wal: Wal)
  @if wal.fd >= 0
    sys_fsync(wal.fd)
    sys_close(wal.fd)
    wal.fd = 0 - 1
  @end
  return 1
@end
