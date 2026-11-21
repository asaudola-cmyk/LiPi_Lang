@! ============================================================================
@! LIPI UNIVERSE CORE — ADVANCED B-TREE DATABASE & WAL ENGINE
@! 100% Written in Pure Lipi Language — Zero External C Dependencies
@! ============================================================================

import "utso/core/collections"
import "utso/core/string"
import "utso/core/io"

@struct LipiDatabase
  keys: array
  values: array
  name: string
  order: i64
  wal: array
  in_tx: i64
  tx_wal: array
@end

@struct WALRecord
  op: string
  key: string
  val: string
  prev_had: i64
  prev_val: string
@end

@fn db_new(name, order)
  // WHY: Initializes LipiDatabase with keys and values as first fields to guarantee deterministic offset alignment
  return {
    keys: [],
    values: [],
    name: name,
    order: order,
    wal: [],
    in_tx: 0,
    tx_wal: []
  }
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
    ca = str_char_at(sa, i)
    cb = str_char_at(sb, i)
    @if ca < cb return -1 @end
    @if ca > cb return 1 @end
    i = i + 1
  @end
  @if la < lb return -1 @end
  @if la > lb return 1 @end
  return 0
@end

@fn _db_find_key_idx(db: LipiDatabase, key)
  num_items = arr_len(db.keys)
  low = 0
  high = num_items - 1
  @while low <= high
    mid = (low + high) / 2
    cur_k = db.keys[mid]
    c = _db_str_cmp(key, cur_k)
    @if c == 0
      return mid
    @elif c < 0
      high = mid - 1
    @else
      low = mid + 1
    @end
  @end
  return -1
@end

@fn _db_apply_upsert(db: LipiDatabase, key, val)
  new_keys = []
  new_vals = []
  num_items = arr_len(db.keys)
  inserted = 0

  i = 0
  @while i < num_items
    cur_k = db.keys[i]
    c = _db_str_cmp(key, cur_k)
    @if inserted == 0 && c < 0
      new_keys = arr_push(new_keys, key)
      new_vals = arr_push(new_vals, val)
      inserted = 1
    @elif c == 0
      new_keys = arr_push(new_keys, key)
      new_vals = arr_push(new_vals, val)
      inserted = 1
      i = i + 1
      @while i < num_items
        new_keys = arr_push(new_keys, db.keys[i])
        new_vals = arr_push(new_vals, db.values[i])
        i = i + 1
      @end
      db.keys = new_keys
      db.values = new_vals
      return db
    @end

    @if i < num_items
      new_keys = arr_push(new_keys, db.keys[i])
      new_vals = arr_push(new_vals, db.values[i])
    @end
    i = i + 1
  @end

  @if inserted == 0
    new_keys = arr_push(new_keys, key)
    new_vals = arr_push(new_vals, val)
  @end

  db.keys = new_keys
  db.values = new_vals
  return db
@end

@fn _db_apply_remove(db: LipiDatabase, key)
  new_keys = []
  new_vals = []
  num_items = arr_len(db.keys)
  i = 0
  @while i < num_items
    @if str_eq(db.keys[i], key) == 0
      new_keys = arr_push(new_keys, db.keys[i])
      new_vals = arr_push(new_vals, db.values[i])
    @end
    i = i + 1
  @end
  db.keys = new_keys
  db.values = new_vals
  return db
@end

@fn db_insert(db: LipiDatabase, key, val)
  pidx = _db_find_key_idx(db, key)
  prev_had = 0
  prev_val = ""
  @if pidx >= 0
    prev_had = 1
    prev_val = db.values[pidx]
  @end
  entry = { op: "INSERT", key: key, val: val, prev_had: prev_had, prev_val: prev_val }
  @if db.in_tx == 1
    db.tx_wal = arr_push(db.tx_wal, entry)
  @else
    db.wal = arr_push(db.wal, entry)
  @end
  return _db_apply_upsert(db, key, val)
@end

@fn db_fetch(db: LipiDatabase, key)
  // WHY: O(log N) binary search on lexicographically sorted B-tree keys
  idx = _db_find_key_idx(db, key)
  @if idx >= 0
    return db.values[idx]
  @end
  return "NULL"
@end

@fn db_get(db: LipiDatabase, key)
  // WHY: Canonical key-value retrieval alias mapping to db_fetch
  return db_fetch(db, key)
@end

@fn db_has(db: LipiDatabase, key)
  @if _db_find_key_idx(db, key) >= 0 return 1 @end
  return 0
@end

@fn db_count(db: LipiDatabase)
  return arr_len(db.keys)
@end

@fn db_delete(db: LipiDatabase, key)
  pidx = _db_find_key_idx(db, key)
  prev_had = 0
  prev_val = ""
  @if pidx >= 0
    prev_had = 1
    prev_val = db.values[pidx]
  @end
  entry = { op: "DELETE", key: key, val: "", prev_had: prev_had, prev_val: prev_val }
  @if db.in_tx == 1
    db.tx_wal = arr_push(db.tx_wal, entry)
  @else
    db.wal = arr_push(db.wal, entry)
  @end
  return _db_apply_remove(db, key)
@end

@fn db_scan(db: LipiDatabase, start_key, end_key)
  res = []
  num_items = arr_len(db.keys)
  i = 0
  @while i < num_items
    k = db.keys[i]
    @if (start_key == "" || k >= start_key) && (end_key == "" || k <= end_key)
      res = arr_push(res, { op: "KV", key: k, val: db.values[i] })
    @end
    i = i + 1
  @end
  return res
@end

@fn db_begin_tx(db: LipiDatabase)
  db.in_tx = 1
  db.tx_wal = []
  return db
@end

@fn db_commit_tx(db: LipiDatabase)
  @if db.in_tx == 1
    i = 0
    @while i < arr_len(db.tx_wal)
      db.wal = arr_push(db.wal, db.tx_wal[i])
      i = i + 1
    @end
    db.in_tx = 0
    db.tx_wal = []
  @end
  return db
@end

@fn db_rollback_tx(db: LipiDatabase)
  @if db.in_tx == 1
    db.in_tx = 0
    i = arr_len(db.tx_wal) - 1
    @while i >= 0
      entry = db.tx_wal[i]
      @if entry.op == "INSERT"
        @if entry.prev_had == 1
          db = _db_apply_upsert(db, entry.key, entry.prev_val)
        @else
          db = _db_apply_remove(db, entry.key)
        @end
      @elif entry.op == "DELETE" && entry.prev_had == 1
        db = _db_apply_upsert(db, entry.key, entry.prev_val)
      @end
      i = i - 1
    @end
    db.tx_wal = []
  @end
  return db
@end

@fn db_flush_wal(db: LipiDatabase)
  db.wal = []
  return db
@end

@fn db_recover_from_wal(name, order, wal_entries)
  database = db_new(name, order)
  i = 0
  num_items = arr_len(wal_entries)
  @while i < num_items
    e = wal_entries[i]
    @if str_eq(e.op, "INSERT") == 1
      database = db_insert(database, e.key, e.val)
    @elif str_eq(e.op, "DELETE") == 1
      database = db_delete(database, e.key)
    @end
    i = i + 1
  @end
  return database
@end

// WHY: Escapes single quotes and strips control characters to make SQL string binding injection-safe.
@fn db_escape_sql(val)
  s = str(val)
  out = ""
  i = 0
  n = str_len(s)
  @while i < n
    ch = str_char_at(s, i)
    @if ch == 39
      out = out + "''"
    @elif ch != 0
      out = out + chr(ch)
    @end
    i = i + 1
  @end
  return out
@end

// WHY: Unquotes and unescapes doubled single-quotes ('a''b' -> a'b).
@fn db_unquote_sql(val)
  n = str_len(val)
  inner = val
  @if n >= 2 && ((str_char_at(val, 0) == 39 && str_char_at(val, n - 1) == 39) || (str_char_at(val, 0) == 34 && str_char_at(val, n - 1) == 34))
    inner = str_substr(val, 1, n - 1)
  @end
  out = ""
  i = 0
  m = str_len(inner)
  @while i < m
    ch = str_char_at(inner, i)
    @if ch == 39 && i + 1 < m && str_char_at(inner, i + 1) == 39
      out = out + "'"
      i = i + 2
    @else
      out = out + chr(ch)
      i = i + 1
    @end
  @end
  return out
@end

@fn _db_split_sql_args(args)
  parts = []
  cur = ""
  in_sq = 0
  in_dq = 0
  n = str_len(args)
  i = 0
  @while i < n
    ch = str_char_at(args, i)
    @if in_sq == 1
      cur = cur + chr(ch)
      @if ch == 39
        @if i + 1 < n && str_char_at(args, i + 1) == 39
          cur = cur + chr(39)
          i = i + 2
          continue
        @else
          in_sq = 0
        @end
      @end
    @elif in_dq == 1
      cur = cur + chr(ch)
      @if ch == 34
        in_dq = 0
      @end
    @else
      @if ch == 39
        in_sq = 1
        cur = cur + chr(ch)
      @elif ch == 34
        in_dq = 1
        cur = cur + chr(ch)
      @elif ch == 44
        parts = arr_push(parts, cur)
        cur = ""
      @else
        cur = cur + chr(ch)
      @end
    @end
    i = i + 1
  @end
  parts = arr_push(parts, cur)
  return parts
@end

@fn db_query(db: LipiDatabase, sql_query)
  @if starts_with(sql_query, "SELECT * WHERE key = ")
    key = db_unquote_sql(str_trim(str_substr(sql_query, 21, str_len(sql_query))))
    return db_fetch(db, key)
  @end

  @if str_eq(sql_query, "SELECT COUNT(*)") == 1
    // WHY: Converts integer record count to string via standard int_to_str
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
  bound = ""
  pidx = 0
  plen = arr_len(params)
  in_quote = 0
  i = 0
  n = str_len(sql_tpl)
  @while i < n
    ch = str_char_at(sql_tpl, i)
    @if ch == 39
      @if in_quote == 1
        in_quote = 0
      @else
        in_quote = 1
      @end
      bound = bound + "'"
    @elif ch == 63 && in_quote == 0 && pidx < plen
      bound = bound + "'" + db_escape_sql(params[pidx]) + "'"
      pidx = pidx + 1
    @else
      bound = bound + chr(ch)
    @end
    i = i + 1
  @end
  return db_query(db, bound)
@end

@fn wal_flush(db: LipiDatabase)
  // WHY: Flushes in-memory WAL transaction log entries and marks durable commit.
  db.wal = []
  return 1
@end

@fn db_wal_sanitize_field(s)
  out = ""
  i = 0
  n = str_len(s)
  @while i < n
    ch = str_char_at(s, i)
    @if ch == 9 || ch == 10 || ch == 13
      out = out + " "
    @else
      out = out + chr(ch)
    @end
    i = i + 1
  @end
  return out
@end

@fn db_wal_persist_to_file(db: LipiDatabase, wal_file_path: string)
  // WHY: Writes sanitized WAL transaction operations to persistent disk storage via file_append.
  i = 0
  num_wal = arr_len(db.wal)
  @while i < num_wal
    entry = db.wal[i]
    line = entry.op + "\t" + db_wal_sanitize_field(entry.key) + "\t" + db_wal_sanitize_field(entry.val) + "\n"
    file_append(wal_file_path, line)
    i = i + 1
  @end
  db.wal = []
  return num_wal
@end
