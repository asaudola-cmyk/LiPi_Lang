@! ============================================================================
@! LIPI UNIVERSE CORE — SOVEREIGN O(1) KV ENGINE & CRASH-SAFE BINARY WAL DB
@! 100% Written in Pure Lipi Language — Zero External C / Zero SQLite Dependencies
@! Features:
@!   - O(1) StrDict Robin-Hood index (eliminating O(N^2) array copies)
@!   - Real disk-persisted crash-safe binary WAL (db_open / db_compact / db_close)
@!   - IEEE 802.3 CRC-32 per-frame integrity check + torn-tail auto-truncation
@!   - Exclusive advisory locking (SYS_flock) & durable commits (SYS_fsync)
@!   - ACID transactions (db_begin_tx / db_commit_tx / db_rollback_tx)
@!   - Lexicographic range scans (db_scan) + SQL-style parameterized queries
@! ============================================================================

import "utso/core/collections"
import "utso/core/string"
import "utso/core/io"
import "utso/core/hashmap"

@struct LipiDatabase
  keys: array
  values: array
  name: string
  order: i64
  wal: array
  in_tx: i64
  tx_wal: array
  index: i64
  wdb_fd: i64
  path: string
  sync_mode: i64
  wal_frames: i64
  recovered_truncated: i64
@end

@struct WALRecord
  op: string
  key: string
  val: string
  prev_had: i64
  prev_val: string
@end

@fn _db_wal_op(e: WALRecord) return e.op @end
@fn _db_wal_key(e: WALRecord) return e.key @end
@fn _db_wal_val(e: WALRecord) return e.val @end
@fn _db_wal_prev_had(e: WALRecord) return e.prev_had @end
@fn _db_wal_prev_val(e: WALRecord) return e.prev_val @end

@! Binary WAL Frame Format (17-byte header + key + val):
@!   [0..3]   MAGIC = 0x4C444231 ("1BDL" LE)
@!   [4]      OP    (1 = PUT, 2 = DELETE)
@!   [5..8]   CRC32 (IEEE 802.3 over [OP || KLEN || VLEN || KEY || VAL])
@!   [9..12]  KLEN  (uint32 LE)
@!   [13..16] VLEN  (uint32 LE)
@!   [17..]   KEY bytes followed by VAL bytes

@fn _db_crc32_update(crc, byte_val)
  c = (crc ^ (byte_val & 255)) & 4294967295
  b = 0
  @while b < 8
    @if (c & 1) == 1
      c = ((c >> 1) ^ 3988292384) & 4294967295
    @else
      c = (c >> 1) & 4294967295
    @end
    b = b + 1
  @end
  return c
@end

@fn _db_crc32_mem(crc, ptr, n)
  c = crc & 4294967295
  i = 0
  @while i < n
    c = _db_crc32_update(c, mem_byte_read(ptr, i))
    i = i + 1
  @end
  return c
@end

@fn _db_crc32_u32_le(crc, v)
  c = _db_crc32_update(crc, v & 255)
  c = _db_crc32_update(c, (v >> 8) & 255)
  c = _db_crc32_update(c, (v >> 16) & 255)
  c = _db_crc32_update(c, (v >> 24) & 255)
  return c
@end

@fn _db_frame_crc32(op_code, k_ptr, klen, v_ptr, vlen)
  c = 4294967295
  c = _db_crc32_update(c, op_code)
  c = _db_crc32_u32_le(c, klen)
  c = _db_crc32_u32_le(c, vlen)
  @if klen > 0
    c = _db_crc32_mem(c, k_ptr, klen)
  @end
  @if vlen > 0
    c = _db_crc32_mem(c, v_ptr, vlen)
  @end
  return (c ^ 4294967295) & 4294967295
@end

@fn _db_buf_write_u32_le(b, v)
  buf_write_byte(b, v & 255)
  buf_write_byte(b, (v >> 8) & 255)
  buf_write_byte(b, (v >> 16) & 255)
  buf_write_byte(b, (v >> 24) & 255)
  return 0
@end

@fn _db_read_u32_le(ptr, off)
  b0 = mem_byte_read(ptr, off) & 255
  b1 = mem_byte_read(ptr, off + 1) & 255
  b2 = mem_byte_read(ptr, off + 2) & 255
  b3 = mem_byte_read(ptr, off + 3) & 255
  return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
@end

@fn _db_fd_write_all(fd, ptr, total)
  sent = 0
  @while sent < total
    n = syscall(1, fd, ptr + sent, total - sent, 0, 0, 0)
    @if n == (0 - 4)
      continue
    @end
    @if n <= 0
      return 0 - 1
    @end
    sent = sent + n
  @end
  return sent
@end

@fn _db_append_frame_to_buf(b, op_code, key, val)
  ks = str(key)
  vs = str(val)
  kl = str_len(ks)
  vl = str_len(vs)
  crc = _db_frame_crc32(op_code, ks, kl, vs, vl)
  _db_buf_write_u32_le(b, 1279541809) @! 0x4C444231
  buf_write_byte(b, op_code)
  _db_buf_write_u32_le(b, crc)
  _db_buf_write_u32_le(b, kl)
  _db_buf_write_u32_le(b, vl)
  @if kl > 0
    buf_write_mem(b, ks, kl)
  @end
  @if vl > 0
    buf_write_mem(b, vs, vl)
  @end
  return 0
@end

@fn _db_wal_write_single(db: LipiDatabase, op_code, key, val)
  @if db.wdb_fd < 0
    return 0
  @end
  b = buf_new(64 + str_len(str(key)) + str_len(str(val)))
  _db_append_frame_to_buf(b, op_code, key, val)
  n = _db_fd_write_all(db.wdb_fd, buf_ptr(b), buf_len(b))
  buf_free(b)
  @if n < 0
    return 0 - 1
  @end
  db.wal_frames = db.wal_frames + 1
  @if db.sync_mode == 1
    syscall(74, db.wdb_fd, 0, 0, 0, 0, 0) @! SYS_fsync
  @end
  return n
@end

@fn db_new(name, order) -> LipiDatabase
  // WHY: Initializes O(1) StrDict-backed LipiDatabase keeping keys/values slots for ABI compatibility.
  return LipiDatabase([], [], name, order, [], 0, [], dict_new(64), 0 - 1, "", 1, 0, 0)
@end

@fn db_open(path) -> LipiDatabase
  // WHY: Opens or creates a crash-safe disk-persisted binary WAL database with SYS_flock
  // advisory locking, IEEE CRC-32 replay, and automatic torn-tail recovery via SYS_ftruncate.
  db = db_new(path, 64)
  db.path = str(path)
  @! O_RDWR (2) | O_CREAT (64) = 66, mode 0644 = 420
  fd = syscall(2, db.path, 66, 420, 0, 0, 0)
  @if fd < 0
    return db
  @end
  @! Exclusive advisory lock: SYS_flock(73, fd, LOCK_EX=2)
  syscall(73, fd, 2, 0, 0, 0, 0)
  db.wdb_fd = fd

  @! Determine file size via SYS_lseek(8, fd, 0, SEEK_END=2)
  fsize = syscall(8, fd, 0, 2, 0, 0, 0)
  @if fsize > 0
    syscall(8, fd, 0, 0, 0, 0, 0) @! SEEK_SET
    raw = alloc(fsize)
    @if raw > 0
      got = 0
      @while got < fsize
        nr = syscall(0, fd, raw + got, fsize - got, 0, 0, 0)
        @if nr == (0 - 4)
          continue
        @end
        @if nr <= 0
          break
        @end
        got = got + nr
      @end

      pos = 0
      @while pos + 17 <= got
        magic = _db_read_u32_le(raw, pos)
        @if magic != 1279541809
          break
        @end
        op_code = mem_byte_read(raw, pos + 4) & 255
        @if op_code != 1 && op_code != 2
          break
        @end
        stored_crc = _db_read_u32_le(raw, pos + 5)
        klen = _db_read_u32_le(raw, pos + 9)
        vlen = _db_read_u32_le(raw, pos + 13)
        frame_end = pos + 17 + klen + vlen
        @if frame_end > got || klen > 67108864 || vlen > 268435456
          break
        @end
        k_ptr = raw + pos + 17
        v_ptr = k_ptr + klen
        calc_crc = _db_frame_crc32(op_code, k_ptr, klen, v_ptr, vlen)
        @if calc_crc != stored_crc
          break
        @end
        k_str = ""
        @if klen > 0
          k_str = bytes_to_str(k_ptr, klen)
        @end
        @if op_code == 1
          v_str = ""
          @if vlen > 0
            v_str = bytes_to_str(v_ptr, vlen)
          @end
          dict_set(db.index, k_str, v_str)
        @else
          dict_delete(db.index, k_str)
        @end
        db.wal_frames = db.wal_frames + 1
        pos = frame_end
      @end

      free(raw)

      @! Heal any torn/corrupt tail left by an unclean crash
      @if pos < fsize
        db.recovered_truncated = fsize - pos
        syscall(77, fd, pos, 0, 0, 0, 0) @! SYS_ftruncate
        syscall(74, fd, 0, 0, 0, 0, 0) @! SYS_fsync
      @end
      syscall(8, fd, pos, 0, 0, 0, 0) @! Seek to exact valid end for subsequent appends
    @end
  @end
  return db
@end

@fn db_set_sync(db: LipiDatabase, mode) -> LipiDatabase
  db.sync_mode = mode
  return db
@end

@fn db_sync(db: LipiDatabase)
  @if db.wdb_fd >= 0
    return syscall(74, db.wdb_fd, 0, 0, 0, 0, 0)
  @end
  return 0
@end

@fn db_compact(db: LipiDatabase)
  // WHY: Atomically rewrites WAL to minimal live snapshot via tmp + SYS_fsync + SYS_rename
  // so dead updates/deletes are reclaimed safely even under sudden power loss.
  @if db.wdb_fd < 0 || str_len(db.path) == 0
    return 0
  @end
  tmp_path = db.path + ".compact"
  @! O_WRONLY (1) | O_CREAT (64) | O_TRUNC (512) = 577, mode 0644 = 420
  tfd = syscall(2, tmp_path, 577, 420, 0, 0, 0)
  @if tfd < 0
    return 0 - 1
  @end

  all_keys = dict_keys(db.index)
  n = arr_len(all_keys)
  b = buf_new(4096)
  i = 0
  @while i < n
    k = all_keys[i]
    v = dict_get(db.index, k)
    _db_append_frame_to_buf(b, 1, k, v)
    @if buf_len(b) >= 65536
      @if _db_fd_write_all(tfd, buf_ptr(b), buf_len(b)) < 0
        buf_free(b)
        syscall(3, tfd, 0, 0, 0, 0, 0)
        syscall(87, tmp_path, 0, 0, 0, 0, 0)
        return 0 - 1
      @end
      buf_clear(b)
    @end
    i = i + 1
  @end
  @if buf_len(b) > 0
    @if _db_fd_write_all(tfd, buf_ptr(b), buf_len(b)) < 0
      buf_free(b)
      syscall(3, tfd, 0, 0, 0, 0, 0)
      syscall(87, tmp_path, 0, 0, 0, 0, 0)
      return 0 - 1
    @end
  @end
  buf_free(b)

  syscall(74, tfd, 0, 0, 0, 0, 0) @! SYS_fsync compacted snapshot
  syscall(3, tfd, 0, 0, 0, 0, 0)  @! SYS_close tmp

  rc = syscall(82, tmp_path, db.path, 0, 0, 0, 0) @! Atomic SYS_rename
  @if rc < 0
    syscall(87, tmp_path, 0, 0, 0, 0, 0)
    return 0 - 1
  @end

  new_fd = syscall(2, db.path, 66, 420, 0, 0, 0)
  @if new_fd < 0
    return 0 - 1
  @end
  syscall(73, new_fd, 2, 0, 0, 0, 0) @! LOCK_EX on compacted file
  syscall(8, new_fd, 0, 2, 0, 0, 0)  @! SEEK_END

  old_fd = db.wdb_fd
  db.wdb_fd = new_fd
  db.wal = []
  db.wal_frames = n
  syscall(73, old_fd, 8, 0, 0, 0, 0) @! LOCK_UN old inode
  syscall(3, old_fd, 0, 0, 0, 0, 0)
  return n
@end

@fn db_close(db: LipiDatabase)
  @if db.wdb_fd >= 0
    syscall(74, db.wdb_fd, 0, 0, 0, 0, 0) @! SYS_fsync
    syscall(73, db.wdb_fd, 8, 0, 0, 0, 0) @! LOCK_UN
    syscall(3, db.wdb_fd, 0, 0, 0, 0, 0)  @! SYS_close
    db.wdb_fd = 0 - 1
  @end
  return 0
@end

@fn _db_str_cmp(a, b)
  sa = str(a)
  sb = str(b)
  la = str_len(sa)
  lb = str_len(sb)
  m = la
  @if lb < m m = lb @end
  i = 0
  @while i < m
    ca = mem_byte_read(sa, i) & 255
    cb = mem_byte_read(sb, i) & 255
    @if ca < cb return 0 - 1 @end
    @if ca > cb return 1 @end
    i = i + 1
  @end
  @if la < lb return 0 - 1 @end
  @if la > lb return 1 @end
  return 0
@end

@fn _db_qsort_keys(arr, lo, hi)
  @if lo >= hi
    return 0
  @end
  pivot = arr[(lo + hi) / 2]
  i = lo
  j = hi
  @while i <= j
    @while _db_str_cmp(arr[i], pivot) < 0
      i = i + 1
    @end
    @while _db_str_cmp(arr[j], pivot) > 0
      j = j - 1
    @end
    @if i <= j
      tmp = arr[i]
      list_set(arr, i, arr[j])
      list_set(arr, j, tmp)
      i = i + 1
      j = j - 1
    @end
  @end
  @if lo < j
    _db_qsort_keys(arr, lo, j)
  @end
  @if i < hi
    _db_qsort_keys(arr, i, hi)
  @end
  return 0
@end

@fn _db_apply_upsert(db: LipiDatabase, key, val) -> LipiDatabase
  dict_set(db.index, str(key), str(val))
  return db
@end

@fn _db_apply_remove(db: LipiDatabase, key) -> LipiDatabase
  dict_delete(db.index, str(key))
  return db
@end

@fn db_insert(db: LipiDatabase, key, val) -> LipiDatabase
  ks = str(key)
  vs = str(val)
  prev_had = dict_has(db.index, ks)
  prev_val = ""
  @if prev_had == 1
    prev_val = dict_get(db.index, ks)
  @end
  entry = WALRecord("INSERT", ks, vs, prev_had, prev_val)
  @if db.in_tx == 1
    db.tx_wal = arr_push(db.tx_wal, entry)
  @else
    @if db.wdb_fd >= 0
      _db_wal_write_single(db, 1, ks, vs)
    @else
      db.wal = arr_push(db.wal, entry)
    @end
  @end
  return _db_apply_upsert(db, ks, vs)
@end

@fn db_fetch(db: LipiDatabase, key)
  // WHY: O(1) Robin-Hood StrDict lookup returning "NULL" sentinel when absent (backwards compatible).
  ks = str(key)
  @if dict_has(db.index, ks) == 1
    return dict_get(db.index, ks)
  @end
  return "NULL"
@end

@fn db_get(db: LipiDatabase, key)
  return db_fetch(db, key)
@end

@fn db_get_opt(db: LipiDatabase, key)
  // WHY: Distinguishes missing keys from keys legitimately storing the literal string "NULL".
  ks = str(key)
  @if dict_has(db.index, ks) == 1
    return { found: 1, value: dict_get(db.index, ks) }
  @end
  return { found: 0, value: "" }
@end

@fn db_has(db: LipiDatabase, key)
  return dict_has(db.index, str(key))
@end

@fn db_count(db: LipiDatabase)
  return dict_len(db.index)
@end

@fn db_delete(db: LipiDatabase, key) -> LipiDatabase
  ks = str(key)
  prev_had = dict_has(db.index, ks)
  prev_val = ""
  @if prev_had == 1
    prev_val = dict_get(db.index, ks)
  @end
  entry = WALRecord("DELETE", ks, "", prev_had, prev_val)
  @if db.in_tx == 1
    db.tx_wal = arr_push(db.tx_wal, entry)
  @else
    @if db.wdb_fd >= 0
      _db_wal_write_single(db, 2, ks, "")
    @else
      db.wal = arr_push(db.wal, entry)
    @end
  @end
  return _db_apply_remove(db, ks)
@end

@fn db_scan(db: LipiDatabase, start_key, end_key)
  all_keys = dict_keys(db.index)
  n = arr_len(all_keys)
  @if n > 1
    _db_qsort_keys(all_keys, 0, n - 1)
  @end
  res = []
  i = 0
  @while i < n
    k = all_keys[i]
    @if (start_key == "" || _db_str_cmp(k, start_key) >= 0) && (end_key == "" || _db_str_cmp(k, end_key) <= 0)
      res = arr_push(res, WALRecord("KV", k, dict_get(db.index, k), 0, ""))
    @end
    i = i + 1
  @end
  return res
@end

@fn db_begin_tx(db: LipiDatabase) -> LipiDatabase
  db.in_tx = 1
  db.tx_wal = []
  return db
@end

@fn db_commit_tx(db: LipiDatabase) -> LipiDatabase
  @if db.in_tx == 1
    ntx = arr_len(db.tx_wal)
    @if db.wdb_fd >= 0 && ntx > 0
      b = buf_new(256)
      i = 0
      @while i < ntx
        e = db.tx_wal[i]
        e_op = _db_wal_op(e)
        e_k = _db_wal_key(e)
        e_v = _db_wal_val(e)
        @if str_eq(e_op, "INSERT") == 1
          _db_append_frame_to_buf(b, 1, e_k, e_v)
        @elif str_eq(e_op, "DELETE") == 1
          _db_append_frame_to_buf(b, 2, e_k, "")
        @end
        i = i + 1
      @end
      _db_fd_write_all(db.wdb_fd, buf_ptr(b), buf_len(b))
      buf_free(b)
      db.wal_frames = db.wal_frames + ntx
      @if db.sync_mode == 1
        syscall(74, db.wdb_fd, 0, 0, 0, 0, 0) @! Single atomic SYS_fsync for whole tx
      @end
    @else
      i = 0
      @while i < ntx
        db.wal = arr_push(db.wal, db.tx_wal[i])
        i = i + 1
      @end
    @end
    db.in_tx = 0
    db.tx_wal = []
  @end
  return db
@end

@fn db_rollback_tx(db: LipiDatabase) -> LipiDatabase
  @if db.in_tx == 1
    db.in_tx = 0
    i = arr_len(db.tx_wal) - 1
    @while i >= 0
      entry = db.tx_wal[i]
      e_op = _db_wal_op(entry)
      e_k = _db_wal_key(entry)
      e_ph = _db_wal_prev_had(entry)
      e_pv = _db_wal_prev_val(entry)
      @if str_eq(e_op, "INSERT") == 1
        @if e_ph == 1
          db = _db_apply_upsert(db, e_k, e_pv)
        @else
          db = _db_apply_remove(db, e_k)
        @end
      @elif str_eq(e_op, "DELETE") == 1 && e_ph == 1
        db = _db_apply_upsert(db, e_k, e_pv)
      @end
      i = i - 1
    @end
    db.tx_wal = []
  @end
  return db
@end

@fn db_flush_wal(db: LipiDatabase) -> LipiDatabase
  @if db.wdb_fd >= 0
    db_compact(db)
  @else
    db.wal = []
  @end
  return db
@end

@fn db_recover_from_wal(name, order, wal_entries) -> LipiDatabase
  database = db_new(name, order)
  i = 0
  num_items = arr_len(wal_entries)
  @while i < num_items
    e = wal_entries[i]
    e_op = _db_wal_op(e)
    e_k = _db_wal_key(e)
    e_v = _db_wal_val(e)
    @if str_eq(e_op, "INSERT") == 1
      database = db_insert(database, e_k, e_v)
    @elif str_eq(e_op, "DELETE") == 1
      database = db_delete(database, e_k)
    @end
    i = i + 1
  @end
  return database
@end

// WHY: O(N) ByteBuffer SQL string escaper stripping NUL bytes and doubling single quotes.
@fn db_escape_sql(val)
  s = str(val)
  n = str_len(s)
  b = buf_new(n + 16)
  i = 0
  @while i < n
    ch = mem_byte_read(s, i) & 255
    @if ch == 39
      buf_write_byte(b, 39)
      buf_write_byte(b, 39)
    @elif ch != 0
      buf_write_byte(b, ch)
    @end
    i = i + 1
  @end
  out = buf_to_str(b)
  buf_free(b)
  return out
@end

// WHY: O(N) ByteBuffer unquoter and doubled single-quote unescaper ('a''b' -> a'b).
@fn db_unquote_sql(val)
  s = str(val)
  n = str_len(s)
  st = 0
  en = n
  @if n >= 2
    c0 = mem_byte_read(s, 0) & 255
    cn = mem_byte_read(s, n - 1) & 255
    @if (c0 == 39 && cn == 39) || (c0 == 34 && cn == 34)
      st = 1
      en = n - 1
    @end
  @end
  b = buf_new(en - st + 8)
  i = st
  @while i < en
    ch = mem_byte_read(s, i) & 255
    @if ch == 39 && i + 1 < en && (mem_byte_read(s, i + 1) & 255) == 39
      buf_write_byte(b, 39)
      i = i + 2
    @else
      buf_write_byte(b, ch)
      i = i + 1
    @end
  @end
  out = buf_to_str(b)
  buf_free(b)
  return out
@end

@fn _db_split_sql_args(args)
  s = str(args)
  parts = []
  b = buf_new(64)
  in_sq = 0
  in_dq = 0
  n = str_len(s)
  i = 0
  @while i < n
    ch = mem_byte_read(s, i) & 255
    @if in_sq == 1
      buf_write_byte(b, ch)
      @if ch == 39
        @if i + 1 < n && (mem_byte_read(s, i + 1) & 255) == 39
          buf_write_byte(b, 39)
          i = i + 2
          continue
        @else
          in_sq = 0
        @end
      @end
    @elif in_dq == 1
      buf_write_byte(b, ch)
      @if ch == 34
        in_dq = 0
      @end
    @else
      @if ch == 39
        in_sq = 1
        buf_write_byte(b, ch)
      @elif ch == 34
        in_dq = 1
        buf_write_byte(b, ch)
      @elif ch == 44
        parts = arr_push(parts, buf_to_str(b))
        buf_clear(b)
      @else
        buf_write_byte(b, ch)
      @end
    @end
    i = i + 1
  @end
  parts = arr_push(parts, buf_to_str(b))
  buf_free(b)
  return parts
@end

@fn db_query(db: LipiDatabase, sql_query)
  @if starts_with(sql_query, "SELECT * WHERE key = ")
    key = db_unquote_sql(str_trim(str_substr(sql_query, 21, str_len(sql_query))))
    return db_fetch(db, key)
  @end

  @if str_eq(sql_query, "SELECT COUNT(*)") == 1
    return int_to_str(db_count(db))
  @end

  @if starts_with(sql_query, "INSERT INTO kv VALUES (")
    args = str_substr(sql_query, 23, str_len(sql_query) - 1)
    parts = _db_split_sql_args(args)
    @if arr_len(parts) >= 2
      k = db_unquote_sql(str_trim(parts[0]))
      v = db_unquote_sql(str_trim(parts[1]))
      db = db_insert(db, k, v)
      return "OK: INSERTED"
    @end
  @end

  @if starts_with(sql_query, "DELETE FROM kv WHERE key = ")
    key = db_unquote_sql(str_trim(str_substr(sql_query, 27, str_len(sql_query))))
    db = db_delete(db, key)
    return "OK: DELETED"
  @end

  return "ERROR: INVALID_QUERY"
@end

// WHY: Parameterized SQL execution binding '?' placeholders safely outside string literals.
@fn db_query_params(db: LipiDatabase, sql_tpl, params)
  tpl = str(sql_tpl)
  n = str_len(tpl)
  b = buf_new(n + 64)
  pidx = 0
  plen = arr_len(params)
  in_quote = 0
  i = 0
  @while i < n
    ch = mem_byte_read(tpl, i) & 255
    @if ch == 39
      @if in_quote == 1
        in_quote = 0
      @else
        in_quote = 1
      @end
      buf_write_byte(b, 39)
    @elif ch == 63 && in_quote == 0 && pidx < plen
      buf_write_byte(b, 39)
      buf_write_str(b, db_escape_sql(params[pidx]))
      buf_write_byte(b, 39)
      pidx = pidx + 1
    @else
      buf_write_byte(b, ch)
    @end
    i = i + 1
  @end
  bound = buf_to_str(b)
  buf_free(b)
  return db_query(db, bound)
@end

@fn wal_flush(db: LipiDatabase)
  @if db.wdb_fd >= 0
    db_compact(db)
  @else
    db.wal = []
  @end
  return 1
@end

@fn db_wal_sanitize_field(s)
  ss = str(s)
  n = str_len(ss)
  b = buf_new(n + 8)
  i = 0
  @while i < n
    ch = mem_byte_read(ss, i) & 255
    @if ch == 9 || ch == 10 || ch == 13
      buf_write_byte(b, 32)
    @else
      buf_write_byte(b, ch)
    @end
    i = i + 1
  @end
  out = buf_to_str(b)
  buf_free(b)
  return out
@end

@fn db_wal_persist_to_file(db: LipiDatabase, wal_file_path: string)
  // WHY: Writes sanitized text WAL transaction operations to persistent disk storage via file_append.
  i = 0
  num_wal = arr_len(db.wal)
  @while i < num_wal
    entry = db.wal[i]
    line = _db_wal_op(entry) + "\t" + db_wal_sanitize_field(_db_wal_key(entry)) + "\t" + db_wal_sanitize_field(_db_wal_val(entry)) + "\n"
    file_append(wal_file_path, line)
    i = i + 1
  @end
  db.wal = []
  return num_wal
@end
